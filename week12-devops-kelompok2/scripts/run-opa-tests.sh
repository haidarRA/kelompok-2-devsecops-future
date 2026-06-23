#!/usr/bin/env bash
# ============================================================
# run-opa-tests.sh (Fix Cepat + Deteksi Pesan Error Akurat)
# ============================================================

set -uo pipefail

MANIFEST_DIR="evaluation/test-manifests/opa"
POLICY_DIR="policies/opa"
OUTPUT_CSV="evaluation/test-log-opa.csv"

if ! command -v conftest &> /dev/null; then
    echo "ERROR: conftest tidak ditemukan."
    exit 1
fi

mkdir -p "$(dirname "$OUTPUT_CSV")"
echo "id,deskripsi,expected,actual,waktu_ms,status,pesan_error" > "$OUTPUT_CSV"

get_expected_value() {
    local target_id="$1"
    case "$target_id" in
        S1-01|S1-02|S1-04|S1-05) echo "DENY" ;;
        S1-03)                   echo "ALLOW" ;;
        S2-01|S2-02|S2-04|S2-05) echo "DENY" ;;
        S2-03)                   echo "ALLOW" ;;
        S3-01|S3-02|S3-03|S3-05) echo "DENY" ;;
        S3-04)                   echo "ALLOW" ;;
        S4-01|S4-02|S4-03|S4-04|S4-05) echo "ALLOW" ;;
        *)                       echo "ALLOW" ;;
    esac
}

TOTAL=0
CORRECT=0

while IFS= read -r filepath; do
    [ -z "$filepath" ] && continue
    [ -e "$filepath" ] || continue

    filename=$(basename "$filepath")
    id=$(echo "$filename" | grep -oE '^S[0-9]-[0-9]+')
    [ -z "$id" ] && continue
    
    deskripsi=$(head -n1 "$filepath" | sed 's/^# *//')
    expected=$(get_expected_value "$id")

    start_ms=$(perl -MTime::HiRes=time -e 'printf "%.0f\n", time * 1000')
    
    result=$(conftest test "$filepath" --policy "$POLICY_DIR" --all-namespaces --output json 2>&1)
    exit_code=$?
    
    end_ms=$(perl -MTime::HiRes=time -e 'printf "%.0f\n", time * 1000')
    elapsed=$((end_ms - start_ms))

    if [ $exit_code -ne 0 ]; then
        actual="DENY"
        # PERBAIKAN: Menggunakan regex yang toleran terhadap spasi json ("msg": "...") agar pesan asli dari Rego tertangkap
        error_msg=$(echo "$result" | grep -o '"msg"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n1 | sed -E 's/"msg"[[:space:]]*:[[:space:]]*"//;s/"$//')
        [ -z "$error_msg" ] && error_msg="Policy Violation"
    else
        actual="ALLOW"
        error_msg="-"
    fi

    if [ "$actual" == "$expected" ]; then
        status="PASS"
        CORRECT=$((CORRECT + 1))
    else
        status="FAIL_MISMATCH"
    fi

    TOTAL=$((TOTAL + 1))
    echo "${id},\"${deskripsi}\",${expected},${actual},${elapsed},${status},\"${error_msg}\"" >> "$OUTPUT_CSV"
    echo "[$id] expected=$expected actual=$actual (${elapsed}ms) -> $status"

done < <(find "$MANIFEST_DIR" -maxdepth 1 -name "*.yaml" -o -name "*.yml" 2>/dev/null | sort)

echo ""
echo "============================================"
echo "Selesai. $CORRECT dari $TOTAL skenario sesuai prediksi."
echo "Hasil lengkap tersimpan di: $OUTPUT_CSV"
echo "============================================"