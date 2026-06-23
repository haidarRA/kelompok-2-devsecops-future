
# Metrics Before — Baseline Tanpa Enhancement

> Baseline diukur pada pipeline Week 12 sebelum OPA, Falco, dan Kyverno dipasang.
> Tujuannya membuktikan kondisi awal pipeline benar-benar tidak punya
> proteksi ini, sebagai pembanding untuk evaluation/metrics-after.md

## 1. Baseline OPA — Manifest Berbahaya Tanpa Policy Enforcement

Kelima manifest berbahaya di-deploy ke cluster TANPA OPA terpasang. Hasil:

| ID | Manifest | Pelanggaran | Hasil (sebelum OPA) |
|----|----------|-------------|----------------------|
| B-01 | `image: nginx:1.25` (docker.io) | image tidak resmi | **ALLOW** (masuk cluster) |
| B-02 | `runAsUser: 0` | jalan sebagai root | **ALLOW** (masuk cluster) |
| B-03 | tanpa `resources.limits` | tidak ada batas CPU/RAM | **ALLOW** (masuk cluster) |
| B-04 | `port: 5432` type LoadBalancer | database expose publik | **ALLOW** (masuk cluster) |
| B-05 | `privileged: true` | container privileged | **ALLOW** (masuk cluster) |

**Kesimpulan baseline:** 5 dari 5 manifest berbahaya berhasil masuk ke cluster
(100% lolos — tidak ada proteksi sama sekali).

---

## 2. Baseline Runtime Security — Shell Access Tanpa Falco/Kyverno

```bash
kubectl apply -f evaluation/test-manifests/runtime/ubuntu-attacker.yaml
kubectl exec -it ubuntu-attacker -- bash

```

Hasil pengamatan:

* **Apakah ada alert yang muncul?** Tidak ada. Tidak ada mekanisme deteksi.
* **Berapa lama proses bash bisa berjalan?** Tak terbatas. Pod berjalan terus tanpa gangguan.
* **Apakah pod terhapus otomatis?** Tidak. Pod tetap running sampai dihapus manual.

**Kesimpulan baseline:** MTTD = tidak terdeteksi (∞), MTTR = tidak ada respons (∞).

---

## 3. Baseline Pipeline Performance

Waktu pipeline GitLab CI sebelum stage `validate-k8s-manifest` ditambahkan (dihitung dari akumulasi durasi tertinggi tiap tahapan *sequential* pada run riil):

| Run | ID Pipeline | Commit ID | Waktu total pipeline |
| --- | --- | --- | --- |
| 1 | #2571262626 | `cfc3bf68` | 7m 29s |
| 2 | #2571362461 | `2984afbe` | 7m 18s |
| 3 | #2572101091 | `430e8c35` | 7m 11s |
| **Rata-rata** | - | - | **7m 19s** |

> *Catatan Bottleneck:* Tahap paling memakan waktu pada kondisi awal ini berada pada stage `package` (`build-docker-image`) dengan durasi rata-rata ~1m 38s akibat proses download dependencies dan penyusunan layer Docker yang belum dioptimasi dengan *caching*.

---

## 4. Ringkasan Baseline

| Metrik | Nilai Baseline |
| --- | --- |
| Manifest berbahaya terblok | 0% |
| Runtime attack terdeteksi | Tidak pernah (∞) |
| Respons otomatis (MTTR) | Tidak ada (∞) |
| Durasi Rata-rata Pipeline | 7m 19s |
| Pipeline overhead | 0s (belum ada stage `validate-k8s-manifest`) |

```

