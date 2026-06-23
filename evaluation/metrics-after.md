# Metrics After - Hasil Setelah Enhancement

## 1. Hasil OPA Policy Enforcement (20 Skenario)

Sumber data: `evaluation/test-log-opa.csv`

| ID | Deskripsi | Policy | Expected | Actual | Waktu Respons | Status |
|----|-----------|--------|----------|--------|----------------|--------|
| S1-01 | Image dari docker.io | image-policy | DENY | DENY | 179 ms | PASS |
| S1-02 | Tag :latest | image-policy | DENY | DENY | 157 ms | PASS |
| S1-03 | Image + SHA tag | image-policy | ALLOW | ALLOW | 159 ms | PASS |
| S1-04 | Registry tidak dikenal | image-policy | DENY | DENY | 168 ms | PASS |
| S1-05 | Tanpa tag | image-policy | DENY | DENY | 176 ms | PASS |
| S2-01 | runAsUser: 0 | security-context | DENY | DENY | 152 ms | PASS |
| S2-02 | Tanpa securityContext | security-context | DENY | DENY | 170 ms | PASS |
| S2-03 | runAsNonRoot valid | security-context | ALLOW | ALLOW | 166 ms | PASS |
| S2-04 | privileged: true | security-context | DENY | DENY | 171 ms | PASS |
| S2-05 | allowPrivilegeEscalation | security-context | DENY | DENY | 136 ms | PASS |
| S3-01 | Tanpa resources | resource-policy | DENY | DENY | 181 ms | PASS |
| S3-02 | requests only | resource-policy | DENY | DENY | 153 ms | PASS |
| S3-03 | limits only | resource-policy | DENY | DENY | 147 ms | PASS |
| S3-04 | requests+limits valid | resource-policy | ALLOW | ALLOW | 156 ms | PASS |
| S3-05 | CPU limit berlebihan | resource-policy | DENY | DENY | 155 ms | PASS |
| S4-01 | Manifest compliant #1 | semua | ALLOW | ALLOW | 143 ms | PASS |
| S4-02 | Manifest compliant #2 | semua | ALLOW | ALLOW | 148 ms | PASS |
| S4-03 | Manifest compliant #3 | semua | ALLOW | ALLOW | 153 ms | PASS |
| S4-04 | Manifest compliant #4 | semua | ALLOW | ALLOW | 154 ms | PASS |
| S4-05 | Manifest compliant #5 | semua | ALLOW | ALLOW | 150 ms | PASS |

### Metrik Agregat OPA

```
Total manifest uji                       : 20
Manifest yang harusnya DENY              : 12
Manifest yang harusnya ALLOW             : 8

True Positive  (DENY tepat)              : 12 dari 12
False Negative (lolos padahal harus DENY): 0 dari 12
True Negative  (ALLOW tepat)             : 8 dari 8
False Positive (ditolak padahal harus ALLOW): 0 dari 8

Detection Rate      = 100%
False Positive Rate = 0%
Rata-rata waktu respons OPA = 158.7 ms
```

### Pipeline Overhead

| | Sebelum (tanpa stage OPA) | Sesudah (dengan stage OPA) | Selisih |
|---|---|---|---|
| Waktu total pipeline | n/a | n/a | n/a |

Catatan: overhead pipeline GitLab belum bisa diukur dari history GitLab pada sesi ini karena tidak ada pipeline run setelah perubahan yang bisa diakses dari environment lokal.

## 2. Hasil Runtime Threat Detection (5 Run)

Sumber data: `evaluation/test-log-runtime.csv`

| Run | T0 (attack) | T1 (detected) | T2 (deleted) | MTTD | MTTR | Total |
|-----|-------------|---------------|--------------|------|------|-------|
| 1 | 1782150383.005 | 1782150383.773 | 1782150453.053 | 0.768 s | 69.280 s | 70.048 s |
| 2 | 1782150458.930 | 1782150459.486 | 1782150512.849 | 0.556 s | 53.363 s | 53.919 s |
| 3 | 1782150519.782 | 1782150520.408 | 1782150571.495 | 0.626 s | 51.087 s | 51.713 s |
| 4 | 1782150578.737 | 1782150579.450 | 1782150632.859 | 0.713 s | 53.409 s | 54.122 s |
| 5 | 1782150639.502 | 1782150640.173 | 1782150692.437 | 0.671 s | 52.264 s | 52.935 s |
| **AVG** |  |  |  | **0.667 s** | **55.881 s** | **56.547 s** |
| **MIN** |  |  |  | **0.556 s** | **51.087 s** | **51.713 s** |
| **MAX** |  |  |  | **0.768 s** | **69.280 s** | **70.048 s** |

## 3. False Positive Test (Skenario RT-03)

Operasi normal yang TIDAK BOLEH memicu Falco/Kyverno:

| Operasi | Alert Muncul? | Pod Terhapus? | False Positive? |
|---------|---------------|--------------|-----------------|
| `kubectl logs ubuntu-attacker` | Tidak | Tidak | Tidak |
| `kubectl exec ubuntu-attacker -- ls /` | Tidak | Tidak | Tidak |
| `kubectl exec ubuntu-attacker -- ps aux` | Tidak | Tidak | Tidak |
| `kubectl exec ubuntu-attacker -- cat /etc/hostname` | Tidak | Tidak | Tidak |
| `curl http://$(minikube ip):30081/health` | Tidak | Tidak | Tidak |
| `kubectl exec -it ubuntu-attacker -- bash` (kontrol positif) | Ya | Ya | Tidak, ini kontrol positif |

## 4. Availability Test (Skenario RT-04)

Catatan: image `taskflow-api` tidak memiliki `sh` atau `/bin/sh`, jadi trigger runtime via `kubectl exec` ke pod aplikasi tidak bisa dipakai. Untuk membuktikan recovery deployment, saya gunakan fallback manual delete satu pod dan memonitor health endpoint.

| Run | T_attack | T_down | T_recovery | Downtime |
|-----|----------|--------|------------|----------|
| 1 | 00:59:40.219 | tidak terobservasi | 00:59:44.842 | 4.643 s (recovery window) |
| 2 | 01:00:51.456 | tidak terobservasi | 01:00:54.761 | 3.315 s (recovery window) |
| 3 | 01:01:00.142 | tidak terobservasi | 01:01:03.227 | 3.085 s (recovery window) |
| **AVG** |  |  |  | 3.681 s |

Selama pengamatan, endpoint health tetap HTTP 200, jadi tidak ada outage yang terlihat oleh client.

## 5. Ringkasan Before vs After

| Metrik | Sebelum | Sesudah |
|--------|---------|---------|
| Manifest berbahaya terblok | n/a pada baseline sesi ini | 100% pada 12 skenario DENY |
| False positive OPA | n/a pada baseline sesi ini | 0% |
| Runtime attack terdeteksi (MTTD) | Tidak terukur | 0.667 detik |
| Respons otomatis (MTTR) | Tidak terukur | 55.881 detik |
| Overhead tambahan di pipeline | n/a | n/a (belum ada data GitLab run setelah perubahan) |
