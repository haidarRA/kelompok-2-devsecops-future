#!/usr/bin/env bash
# ============================================================
# run-runtime-tests.sh
# Menjalankan skenario RT-01 (shell spawn attack) 5x berturut-turut,
# mengukur MTTD (deteksi) dan MTTR (remediasi/pod terhapus),
# mencatat hasil ke evaluation/test-log-runtime.csv
#
# PRASYARAT:
#   - Falco, Falcosidekick, Kyverno, dan webhook SUDAH terdeploy
#     dan berjalan normal di cluster (lihat AGENT_PROMPT.md langkah 1-4)
#   - kubectl context mengarah ke cluster yang benar
#
# CARA PAKAI:
#   chmod +x scripts/run-runtime-tests.sh
#   ./scripts/run-runtime-tests.sh 5     # jalankan 5 run
# ============================================================

set -uo pipefail

RUNS="${1:-5}"
OUTPUT_CSV="evaluation/test-log-runtime.csv"
ATTACKER_MANIFEST="evaluation/test-manifests/runtime/ubuntu-attacker.yaml"
NAMESPACE="default"

echo "run,t0_attack,t1_detected,t2_deleted,mttd_sec,mttr_sec,total_sec" > "$OUTPUT_CSV"

for i in $(seq 1 "$RUNS"); do
    echo "=== RUN $i / $RUNS ==="

    # Bersihkan attacker pod lama jika masih ada
    kubectl delete pod ubuntu-attacker -n "$NAMESPACE" --ignore-not-found=true --wait=true > /dev/null 2>&1

    # Deploy attacker pod baru, tunggu sampai Running
    kubectl apply -f "$ATTACKER_MANIFEST" > /dev/null
    kubectl wait --for=condition=Ready pod/ubuntu-attacker -n "$NAMESPACE" --timeout=60s > /dev/null

    T0=$(date +%s.%3N)
    echo "T0 (attack start): $(date -d @"$T0" +%T.%3N 2>/dev/null || date +%T)"

    # Trigger serangan: spawn shell di dalam container (background, auto-exit)
    kubectl exec ubuntu-attacker -n "$NAMESPACE" -- bash -c "echo simulated-attack" > /dev/null 2>&1 &

    # Poll Falco log untuk waktu deteksi (T1)
    T1=""
    for attempt in $(seq 1 60); do
        DETECT_LINE=$(kubectl logs -n falco daemonset/falco --since=10s 2>/dev/null | grep "Shell spawned" | grep "ubuntu-attacker" | tail -n1)
        if [ -n "$DETECT_LINE" ]; then
            T1=$(date +%s.%3N)
            echo "T1 (Falco detected): $(date -d @"$T1" +%T.%3N 2>/dev/null || date +%T)"
            break
        fi
        sleep 0.5
    done

    if [ -z "$T1" ]; then
        echo "WARNING: Falco tidak mendeteksi dalam batas waktu 30s. Cek konfigurasi."
        T1="$T0"
    fi

    # Poll status pod untuk waktu penghapusan (T2)
    T2=""
    for attempt in $(seq 1 60); do
        if ! kubectl get pod ubuntu-attacker -n "$NAMESPACE" > /dev/null 2>&1; then
            T2=$(date +%s.%3N)
            echo "T2 (pod deleted): $(date -d @"$T2" +%T.%3N 2>/dev/null || date +%T)"
            break
        fi
        sleep 0.5
    done

    if [ -z "$T2" ]; then
        echo "WARNING: Pod belum terhapus dalam batas waktu 30s. Cek Kyverno policy."
        T2="$T1"
    fi

    MTTD=$(echo "$T1 - $T0" | bc)
    MTTR=$(echo "$T2 - $T1" | bc)
    TOTAL=$(echo "$T2 - $T0" | bc)

    echo "$i,$T0,$T1,$T2,$MTTD,$MTTR,$TOTAL" >> "$OUTPUT_CSV"
    echo "MTTD=${MTTD}s | MTTR=${MTTR}s | Total=${TOTAL}s"
    echo ""

    sleep 3
done

echo "============================================"
echo "Selesai $RUNS run. Hasil tersimpan di: $OUTPUT_CSV"
echo "Hitung rata-rata MTTD/MTTR dari kolom mttd_sec dan mttr_sec."
echo "============================================"
