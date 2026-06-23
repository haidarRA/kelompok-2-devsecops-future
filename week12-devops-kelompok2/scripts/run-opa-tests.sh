#!/usr/bin/env bash
# ============================================================
# run-opa-tests.sh
# Menjalankan 20 skenario uji OPA (S1-S4) terhadap conftest,
# mencatat hasil + waktu respons ke evaluation/test-log-opa.csv
#
# PRASYARAT:
#   - conftest sudah terinstall (https://www.conftest.dev/install/)
#   - dijalankan dari root folder week16-enhancement/
#
# CARA PAKAI:
#   chmod +x scripts/run-opa-tests.sh
#   ./scripts/run-opa-tests.sh
# ============================================================

set -uo pipefail

MANIFEST_DIR="evaluation/test-manifests/opa"
POLICY_DIR="policies/opa"
OUTPUT_CSV="evaluation/test-log-opa.csv"

if ! command -v conftest &> /dev/null; then
    echo "ERROR: conftest tidak ditemukan. Install dulu:"
    echo "  https://www.conftest.dev/install/"
    exit 1
fi

echo "id,deskripsi,expected,actual,waktu_ms,status,pesan_error" > "$OUTPUT_CSV"

declare -A EXPECTED=(
    [S1-01]="DENY" [S1-02]="DENY" [S1-03]="ALLOW" [S1-04]="DENY" [S1-05]="DENY"
    [S2-01]="DENY" [S2-02]="DENY" [S2-03]="ALLOW" [S2-04]="DENY" [S2-05]="DENY"
    [S3-01]="DENY" [S3-02]="DENY" [S3-03]="DENY" [S3-04]="ALLOW" [S3-05]="DENY"
    [S4-01]="ALLOW" [S4-02]="ALLOW" [S4-03]="ALLOW" [S4-04]="ALLOW" [S4-05]="ALLOW"
)

TOTAL=0
CORRECT=0

for filepath in "$MANIFEST_DIR"/*.yaml; do
    filename=$(basename "$filepath")
    id=$(echo "$filename" | grep -oE '^S[0-9]-[0-9]+')
    deskripsi=$(head -n1 "$filepath" | sed 's/^# *//')
    expected="${EXPECTED[$id]}"

    start_ms=$(date +%s%3N)
    result=$(conftest test "$filepath" --policy "$POLICY_DIR" --output json 2>&1)
    end_ms=$(date +%s%3N)
    elapsed=$((end_ms - start_ms))

    failures=$(echo "$result" | grep -o '"failures":\[[^]]*\]' | grep -o '"msg"' | wc -l)

    if [ "$failures" -gt 0 ]; then
        actual="DENY"
        error_msg=$(echo "$result" | grep -o '"msg":"[^"]*"' | head -n1 | sed 's/"msg":"//;s/"$//')
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
done

echo ""
echo "============================================"
echo "Selesai. $CORRECT dari $TOTAL skenario sesuai prediksi."
echo "Hasil lengkap tersimpan di: $OUTPUT_CSV"
echo "============================================"
echo ""
echo "Buka file CSV ini untuk menghitung:"
echo "  - Detection Rate (dari skenario yang expected=DENY)"
echo "  - False Positive Rate (dari skenario yang expected=ALLOW)"
echo "  - Rata-rata waktu respons (kolom waktu_ms)"
