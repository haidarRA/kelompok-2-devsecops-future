# Analysis - Apakah Berhasil? Seberapa?

## 1. Apakah hasil sesuai dengan klaim paper?

| Metrik | Klaim Paper | Hasil Kelompok | Sesuai? |
|--------|-------------|----------------|---------|
| Paper A - Detection rate | 92% | 100% pada 12 skenario DENY | Ya, lebih tinggi pada sampel ini |
| Paper A - Pipeline overhead | +3.5% | n/a, belum ada data pipeline GitLab setelah merge | Belum bisa dibandingkan |
| Paper B - MTTD/MTTR | near real-time | MTTD 0.667 s, MTTR 55.881 s | Sebagian ya; deteksi cepat, remediasi dibatasi jadwal cleanup |

Interpretasi singkat:
- OPA cocok dengan klaim paper dari sisi efektivitas, bahkan di sampel kecil ini tidak ada false positive.
- Runtime chain Falco -> webhook -> Kyverno mendeteksi sangat cepat, tetapi MTTR lebih lama karena cleanup policy berjalan berbasis jadwal, bukan delete instan.
- Karena environment lokal Minikube dan test set hanya 20 manifest, hasil ini belum bisa disamakan mentah-mentah dengan skala paper.

## 2. Skenario mana yang tidak sesuai ekspektasi?

- Tidak ada mismatch pada 20 skenario OPA; actual selalu sama dengan expected.
- Untuk runtime, false positive test RT-03 juga aman: operasi baca biasa tidak memicu alert atau delete.
- Satu hal yang tidak sesuai ekspektasi adalah availability test ke `taskflow-api`: image aplikasi ternyata tidak memiliki `sh` atau `/bin/sh`, jadi attack via `kubectl exec` tidak bisa dipakai untuk memicu Falco langsung di pod aplikasi.
- Karena itu saya pakai fallback manual delete satu pod untuk membuktikan deployment recovery. Ini valid untuk availability, tetapi bukan bukti end-to-end remediation pada pod aplikasi.

## 3. False positive - apakah mengganggu developer?

- OPA: tidak ada false positive pada sampel ini.
- Falco/Kyverno: ada noise dari pod monitoring sendiri, terutama alert `Contact K8S API Server From Container` pada webhook pod ketika webhook melabeli pod via kubectl.
- Noise itu tidak menghapus workload aplikasi karena policy cleanup saya batasi ke namespace `default` dan `taskflow-prod`, tetapi tetap perlu dicatat sebagai biaya operasional.

## 4. Trade-off yang ditemukan

- Tambahan stage OPA secara konsep sangat layak karena semua skenario berbahaya terblok dan waktu evaluasi rata-rata hanya 158.7 ms per manifest.
- Runtime remediation memberi deteksi cepat, tetapi cleanup scheduled membuat MTTR lebih besar daripada MTTD. Jadi bottleneck-nya ada di mekanisme cleanup, bukan di Falco.
- Kalau target produksi butuh pemulihan lebih cepat dari sekitar satu menit, pendekatan cleanup berbasis jadwal perlu dioptimalkan lagi.

## 5. Batasan implementasi kelompok dibanding paper asli

- Paper A diuji dengan 50 manifest; kelompok ini memakai 20 manifest sintetis.
- Paper B di sini hanya menguji shell spawning, bukan seluruh kelas ancaman runtime.
- Policy cleanup Kyverno perlu tambahan RBAC kecil agar controller bisa menghapus Pod.
- Policy runtime juga perlu scope namespace agar stack observability sendiri tidak ikut tersapu oleh alert yang mereka hasilkan.
- Pipeline overhead GitLab belum bisa dilaporkan karena belum ada pipeline run pasca perubahan yang bisa diambil dari history GitLab di sesi ini.
