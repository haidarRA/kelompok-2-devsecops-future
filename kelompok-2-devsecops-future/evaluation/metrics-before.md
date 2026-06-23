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

## 2. Baseline Runtime Security — Shell Access Tanpa Falco/Kyverno

```bash
kubectl apply -f evaluation/test-manifests/runtime/ubuntu-attacker.yaml
kubectl exec -it ubuntu-attacker -- bash
```

Hasil pengamatan:

- **Apakah ada alert yang muncul?** Tidak ada. Tidak ada mekanisme deteksi.
- **Berapa lama proses bash bisa berjalan?** Tak terbatas. Pod berjalan terus tanpa gangguan.
- **Apakah pod terhapus otomatis?** Tidak. Pod tetap running sampai dihapus manual.

**Kesimpulan baseline:** MTTD = tidak terdeteksi (∞), MTTR = tidak ada respons (∞).

## 3. Baseline Pipeline Performance

Waktu pipeline GitLab CI sebelum stage `validate-k8s-manifest` ditambahkan:

| Run | Waktu total pipeline |
|-----|----------------------|
| 1 | 2m 45s |
| 2 | 2m 38s |
| 3 | 2m 42s |
| **Rata-rata** | **2m 42s** |

## 4. Ringkasan Baseline

| Metrik | Nilai Baseline |
|--------|---------------|
| Manifest berbahaya terblok | 0% |
| Runtime attack terdeteksi | Tidak pernah (∞) |
| Respons otomatis (MTTR) | Tidak ada (∞) |
| Pipeline overhead | 0 (belum ada stage security) |
