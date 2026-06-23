# Metrics Before - Baseline Tanpa Enhancement

Catatan: sesi ini tidak menjalankan rerun baseline dengan OPA/Falco/Kyverno dimatikan, jadi angka di bawah dipakai sebagai pembanding konseptual dan catatan kondisi awal yang belum dilindungi.

## 1. Baseline OPA - Manifest Berbahaya Tanpa Policy Enforcement

| ID | Manifest | Pelanggaran | Hasil (sebelum OPA) |
|----|----------|-------------|----------------------|
| B-01 | image dari docker.io | image tidak resmi | n/a |
| B-02 | runAsUser: 0 | jalan sebagai root | n/a |
| B-03 | tanpa resources.limits | tidak ada batas CPU/RAM | n/a |
| B-04 | port 5432 type LoadBalancer | database expose publik | n/a |
| B-05 | privileged: true | container privileged | n/a |

Kesimpulan baseline: 5 dari 5 manifest berbahaya diperkirakan lolos ketika policy enforcement belum aktif; pada sesi ini tidak ada rerun terpisah dengan OPA dimatikan.

## 2. Baseline Runtime Security - Shell Access Tanpa Falco/Kyverno

```bash
kubectl apply -f evaluation/test-manifests/runtime/ubuntu-attacker.yaml
kubectl exec -it ubuntu-attacker -- bash
# Di dalam container, jalankan:
whoami
cat /etc/passwd
```

Catat:
- Apakah ada alert yang muncul di mana pun? n/a pada baseline sesi ini
- Berapa lama proses bash bisa tetap berjalan tanpa terganggu? n/a pada baseline sesi ini
- Apakah pod terhapus otomatis? n/a pada baseline sesi ini

Kesimpulan baseline: MTTD dan MTTR tidak terukur pada sesi ini karena baseline tidak diulang tanpa stack runtime security.

## 3. Baseline Pipeline Performance

| Run | Waktu total pipeline |
|-----|----------------------|
| 1 | n/a |
| 2 | n/a |
| 3 | n/a |
| Rata-rata | n/a |
