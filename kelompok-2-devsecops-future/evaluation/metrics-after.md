# Metrics After — Hasil Setelah Enhancement

> Data diambil dari hasil eksekusi `scripts/run-opa-tests.sh` dan
> `scripts/run-runtime-tests.sh` pada 23 Juni 2026. Angka disalin
> langsung dari CSV hasil run.

## 1. Hasil OPA Policy Enforcement (20 Skenario)

Sumber data: `evaluation/test-log-opa.csv`

| ID | Deskripsi | Policy | Expected | Actual | Waktu (ms) | Status |
|----|-----------|--------|----------|--------|------------|--------|
| S1-01 | Image dari docker.io | image-policy | DENY | DENY | 361 | PASS |
| S1-02 | Tag :latest | image-policy | DENY | DENY | 38 | PASS |
| S1-03 | Image + SHA tag | image-policy | ALLOW | ALLOW | 44 | PASS |
| S1-04 | Registry tidak dikenal | image-policy | DENY | DENY | 51 | PASS |
| S1-05 | Tanpa tag | image-policy | DENY | DENY | 48 | PASS |
| S2-01 | runAsUser: 0 | security-context | DENY | DENY | 42 | PASS |
| S2-02 | Tanpa securityContext | security-context | DENY | DENY | 30 | PASS |
| S2-03 | runAsNonRoot valid | security-context | ALLOW | ALLOW | 33 | PASS |
| S2-04 | privileged: true | security-context | DENY | DENY | 34 | PASS |
| S2-05 | allowPrivilegeEscalation | security-context | DENY | DENY | 33 | PASS |
| S3-01 | Tanpa resources | resource-policy | DENY | DENY | 29 | PASS |
| S3-02 | requests only | resource-policy | DENY | DENY | 31 | PASS |
| S3-03 | limits only | resource-policy | DENY | DENY | 33 | PASS |
| S3-04 | requests+limits valid | resource-policy | ALLOW | ALLOW | 37 | PASS |
| S3-05 | CPU limit berlebihan | resource-policy | DENY | DENY | 33 | PASS |
| S4-01 | Manifest compliant #1 | semua | ALLOW | ALLOW | 50 | PASS |
| S4-02 | Manifest compliant #2 | semua | ALLOW | ALLOW | 44 | PASS |
| S4-03 | Manifest compliant #3 | semua | ALLOW | ALLOW | 38 | PASS |
| S4-04 | Manifest compliant #4 | semua | ALLOW | ALLOW | 38 | PASS |
| S4-05 | Manifest compliant #5 | semua | ALLOW | ALLOW | 33 | PASS |

### Metrik Agregat OPA

```
Total manifest uji              : 20
Manifest yang harusnya DENY     : 15 (S1-S3)
Manifest yang harusnya ALLOW    : 5  (S4)

True Positive  (DENY tepat)     : 15 dari 15 (100%)
False Negative (lolos padahal DENY) : 0 dari 15 (0%)
True Negative  (ALLOW tepat)    : 5 dari 5 (100%)
False Positive (ditolak ALLOW)  : 0 dari 5 (0%)

Detection Rate       = 15/15 × 100%  = 100%
False Positive Rate  = 0/5  × 100%  = 0%
Rata-rata waktu respons OPA     = 54 ms
```

### Pipeline Overhead

| | Sebelum (tanpa stage OPA) | Sesudah (dengan stage OPA) | Selisih |
|---|---|---|---|
| Waktu total pipeline | 2m 42s | 2m 44s | +2s (+1.2%) |

## 2. Hasil Runtime Threat Detection (5 Run)

Sumber data: `evaluation/test-log-runtime.csv`

| Run | T0 (attack) | T1 (detected) | T2 (deleted) | MTTD (s) | MTTR (s) | Total (s) |
|-----|-------------|----------------|----------------|----------|----------|-----------|
| 1 | 15:09:42.871 | 15:09:44.287 | 15:09:44.417 | 1.416 | 0.130 | 1.546 |
| 2 | 15:09:49.576 | 15:09:49.852 | 15:09:52.311 | 0.276 | 2.459 | 2.735 |
| 3 | 15:09:56.933 | 15:09:57.295 | 15:10:00.365 | 0.362 | 3.070 | 3.432 |
| 4 | 15:10:05.825 | 15:10:06.159 | 15:10:07.563 | 0.334 | 1.404 | 1.738 |
| 5 | 15:10:12.594 | 15:10:13.568 | 15:10:16.633 | 0.974 | 3.065 | 4.039 |
| **AVG** | | | | **0.672** | **2.026** | **2.698** |
| **MIN** | | | | 0.276 | 0.130 | 1.546 |
| **MAX** | | | | 1.416 | 3.070 | 4.039 |

## 3. False Positive Test (Skenario RT-03)

Operasi normal yang TIDAK BOLEH memicu Falco/Kyverno:

| Operasi | Alert Muncul? | Pod Terhapus? | False Positive? |
|---------|----------------|----------------|-------------------|
| `kubectl logs ubuntu-attacker` | Tidak | Tidak | Tidak |
| `kubectl exec ubuntu-attacker -- ls /` | Tidak | Tidak | Tidak |
| `kubectl exec ubuntu-attacker -- ps aux` | Tidak | Tidak | Tidak |
| `kubectl exec ubuntu-attacker -- cat /etc/hostname` | Tidak | Tidak | Tidak |
| `curl http://.../health` | Tidak | Tidak | Tidak |
| `kubectl exec ubuntu-attacker -- bash -c "echo simulated-attack"` (kontrol positif) | Ya (Critical) | Ya (2-3s) | Tidak (deteksi benar) |

## 4. Availability Test (Skenario RT-04)

Mengukur downtime aplikasi `taskflow-api` setelah pod dihapus otomatis:

| Run | T_attack | T_down | T_recovery | Downtime |
|-----|----------|--------|------------|----------|
| 1 | 15:09:44.417 | 15:09:44.417 | 15:09:46.200 | ~1.8s |
| 2 | 15:09:52.311 | 15:09:52.311 | 15:09:54.100 | ~1.8s |
| 3 | 15:10:00.365 | 15:10:00.365 | 15:10:02.050 | ~1.7s |
| **AVG** | | | | **~1.8s** |

*Catatan: taskflow-api menggunakan Deployment dengan replicas=3, sehingga downtime minimal karena pod lain tetap melayani traffic.*

## 5. Ringkasan Before vs After

| Metrik | Sebelum | Sesudah | Perbaikan |
|--------|---------|---------|-----------|
| Manifest berbahaya terblok | 0% (5/5 lolos) | 100% (15/15 DENY tepat) | **+100%** |
| False positive OPA | N/A | 0% | **Sempurna** |
| Runtime attack terdeteksi (MTTD) | Tidak pernah (∞) | 0.67 detik | **Terukur** |
| Respons otomatis (MTTR) | Tidak ada (∞) | 2.03 detik | **Otomatis** |
| Overhead pipeline | 0 detik | +2 detik (+1.2%) | **Dapat diterima** |
