# Metrics After — Hasil Setelah Enhancement

> Isi file ini SETELAH menjalankan scripts/run-opa-tests.sh dan
> scripts/run-runtime-tests.sh. Salin angka dari CSV hasil run,
> jangan ditulis manual.

## 1. Hasil OPA Policy Enforcement (20 Skenario)

Sumber data: `evaluation/test-log-opa.csv` (hasil `scripts/run-opa-tests.sh`)

| ID | Deskripsi | Policy | Expected | Actual | Waktu Respons | Status |
|----|-----------|--------|----------|--------|----------------|--------|
| S1-01 | Image dari docker.io | image-policy | DENY | | | |
| S1-02 | Tag :latest | image-policy | DENY | | | |
| S1-03 | Image + SHA tag | image-policy | ALLOW | | | |
| S1-04 | Registry tidak dikenal | image-policy | DENY | | | |
| S1-05 | Tanpa tag | image-policy | DENY | | | |
| S2-01 | runAsUser: 0 | security-context | DENY | | | |
| S2-02 | Tanpa securityContext | security-context | DENY | | | |
| S2-03 | runAsNonRoot valid | security-context | ALLOW | | | |
| S2-04 | privileged: true | security-context | DENY | | | |
| S2-05 | allowPrivilegeEscalation | security-context | DENY | | | |
| S3-01 | Tanpa resources | resource-policy | DENY | | | |
| S3-02 | requests only | resource-policy | DENY | | | |
| S3-03 | limits only | resource-policy | DENY | | | |
| S3-04 | requests+limits valid | resource-policy | ALLOW | | | |
| S3-05 | CPU limit berlebihan | resource-policy | DENY | | | |
| S4-01 | Manifest compliant #1 | semua | ALLOW | | | |
| S4-02 | Manifest compliant #2 | semua | ALLOW | | | |
| S4-03 | Manifest compliant #3 | semua | ALLOW | | | |
| S4-04 | Manifest compliant #4 | semua | ALLOW | | | |
| S4-05 | Manifest compliant #5 | semua | ALLOW | | | |

### Metrik Agregat OPA

```
Total manifest uji              : 20
Manifest yang harusnya DENY     : 15 (S1-S3)
Manifest yang harusnya ALLOW    : 5  (S4)

True Positive  (DENY tepat)     : ___ dari 15
False Negative (lolos padahal harus DENY) : ___ dari 15
True Negative  (ALLOW tepat)    : ___ dari 5
False Positive (ditolak padahal harus ALLOW) : ___ dari 5

Detection Rate       = TP / 15 × 100%  = ___%
False Positive Rate  = FP / 5  × 100%  = ___%
Rata-rata waktu respons OPA            = ___ ms
```

### Pipeline Overhead

| | Sebelum (tanpa stage OPA) | Sesudah (dengan stage OPA) | Selisih |
|---|---|---|---|
| Waktu total pipeline | | | |

## 2. Hasil Runtime Threat Detection (5 Run)

Sumber data: `evaluation/test-log-runtime.csv` (hasil `scripts/run-runtime-tests.sh`)

| Run | T0 (attack) | T1 (detected) | T2 (deleted) | MTTD | MTTR | Total |
|-----|-------------|----------------|----------------|------|------|-------|
| 1 | | | | | | |
| 2 | | | | | | |
| 3 | | | | | | |
| 4 | | | | | | |
| 5 | | | | | | |
| **AVG** | | | | | | |
| **MIN** | | | | | | |
| **MAX** | | | | | | |

## 3. False Positive Test (Skenario RT-03)

Operasi normal yang TIDAK BOLEH memicu Falco/Kyverno:

| Operasi | Alert Muncul? | Pod Terhapus? | False Positive? |
|---------|----------------|----------------|-------------------|
| `kubectl logs ubuntu-attacker` | | | |
| `kubectl exec ubuntu-attacker -- ls /` | | | |
| `kubectl exec ubuntu-attacker -- ps aux` | | | |
| `kubectl exec ubuntu-attacker -- cat /etc/hostname` | | | |
| `curl http://$(minikube ip):30081/health` | | | |
| `kubectl exec -it ubuntu-attacker -- bash` (kontrol positif) | | | |

## 4. Availability Test (Skenario RT-04)

Mengukur downtime aplikasi `taskflow-api` setelah pod dihapus otomatis:

| Run | T_attack | T_down | T_recovery | Downtime |
|-----|----------|--------|------------|----------|
| 1 | | | | |
| 2 | | | | |
| 3 | | | | |
| **AVG** | | | | |

## 5. Ringkasan Before vs After

| Metrik | Sebelum | Sesudah |
|--------|---------|---------|
| Manifest berbahaya terblok | 0% (lihat metrics-before.md) | ___% |
| False positive OPA | N/A | ___% |
| Runtime attack terdeteksi (MTTD) | Tidak pernah (∞) | ___ detik |
| Respons otomatis (MTTR) | Tidak ada (∞) | ___ detik |
| Overhead tambahan di pipeline | 0 detik | ___ detik (+___%) |
