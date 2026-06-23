# Metrics Before — Baseline Tanpa Enhancement

> Isi file ini SEBELUM OPA, Falco, dan Kyverno dipasang.
> Tujuannya membuktikan kondisi awal pipeline benar-benar tidak punya
> proteksi ini, sebagai pembanding untuk evaluation/metrics-after.md

## 1. Baseline OPA — Manifest Berbahaya Tanpa Policy Enforcement

Deploy kelima manifest ini ke cluster TANPA OPA terpasang, catat hasilnya:

| ID | Manifest | Pelanggaran | Hasil (sebelum OPA) |
|----|----------|-------------|----------------------|
| B-01 | image dari docker.io | image tidak resmi | |
| B-02 | runAsUser: 0 | jalan sebagai root | |
| B-03 | tanpa resources.limits | tidak ada batas CPU/RAM | |
| B-04 | port 5432 type LoadBalancer | database expose publik | |
| B-05 | privileged: true | container privileged | |

**Kesimpulan baseline**: ___ dari 5 manifest berbahaya berhasil masuk ke cluster
(idealnya: 5 dari 5 / 100%, karena belum ada proteksi).

## 2. Baseline Runtime Security — Shell Access Tanpa Falco/Kyverno

```bash
kubectl apply -f evaluation/test-manifests/runtime/ubuntu-attacker.yaml
kubectl exec -it ubuntu-attacker -- bash
# Di dalam container, jalankan:
whoami
cat /etc/passwd
```

Catat:
- Apakah ada alert yang muncul di mana pun? ___
- Berapa lama proses bash bisa tetap berjalan tanpa terganggu? ___
- Apakah pod terhapus otomatis? ___

**Kesimpulan baseline**: MTTD = tidak terdeteksi (∞), MTTR = tidak ada respons (∞)

## 3. Baseline Pipeline Performance

Catat waktu pipeline GitLab CI berjalan dari commit sampai selesai,
SEBELUM stage `validate-k8s-manifest` ditambahkan:

| Run | Waktu total pipeline |
|-----|----------------------|
| 1 | |
| 2 | |
| 3 | |
| Rata-rata | |
