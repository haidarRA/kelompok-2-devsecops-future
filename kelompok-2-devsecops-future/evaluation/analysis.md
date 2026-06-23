# Analysis — Apakah Berhasil? Seberapa?

## 1. Apakah hasil sesuai dengan klaim paper?

| Metrik | Klaim Paper | Hasil Kelompok | Sesuai? |
|--------|-------------|------------------|---------|
| Paper A — Detection rate | 92% | 100% (12/12 DENY tepat) | **Melebihi** |
| Paper A — Pipeline overhead | +3.5% | +0.45% (+2 detik) | **Lebih baik** |
| Paper B — MTTD | "near real-time" | 0.60 detik (rata-rata) | **Sesuai** |
| Paper B — MTTR | "near real-time" | 0.24 detik (rata-rata) | **Sesuai** |

**Penjelasan selisih:**
- **Detection rate** kelompok mencapai 100% (berhasil memblokir seluruh 12 manifest bermasalah tanpa meloloskan *False Negative*). Hal ini dikarenakan cakupan kebijakan OPA (*image-policy*, *security-context*, dan *resource-policy*) telah dipetakan secara presisi dan diuji menggunakan 20 skenario terukur.
- **Pipeline overhead** kelompok (+0.45%) jauh lebih rendah daripada klaim Paper A (+3.5%). Hal ini terjadi karena proses pemindaian OPA CLI (`conftest`) dilakukan secara lokal di dalam *runner stage* secara sekuensial setelah *image building*, sehingga *fixed cost* (seperti *startup time* engine) tidak memberikan beban komputasi yang berarti pada total durasi pipeline yang berbasis 7 menit.

---

## 2. Skenario mana yang tidak sesuai ekspektasi?

**Semua skenario pengujian sukses 100% sesuai ekspektasi (20/20 PASS).** Tidak ditemukan deviasi di mana `actual != expected`.

Namun, terdapat beberapa catatan teknis terkait karakteristik data:
- **S1-01 (270 ms):** Mengalami lonjakan waktu respons dibandingkan rata-rata keseluruhan skenario (52.15 ms). Hal ini merupakan dampak wajar dari *cold start* pada eksekusi perintah OPA/conftest pertama untuk memuat (*loading*) seluruh berkas kebijakan (`.rego`) dari disk ke dalam memori. Eksekusi skenario berikutnya (S1-02 hingga S4-05) berjalan stabil di kisaran puluhan milidetik berkat mekanisme *caching* internal runtime engine.
- **S4 Series (S4-01 s.d S4-05):** Seluruh manifest yang *compliant* (aman) berhasil mendapatkan status **ALLOW** secara konsisten. Ini membuktikan bahwa aturan kebijakan yang diimplementasikan tidak bersifat *over-restrictive* (terlalu mengekang) yang berpotensi merusak kelancaran deployment normal.

---

## 3. False positive — apakah mengganggu developer?

**Hasil OPA:** *False positive rate* sebesar **0%**. Kedelapan manifest yang valid dan lolos sensor (*S4 series* dan *S1-03/S2-03/S3-04*) berhasil masuk cluster tanpa mengalami penolakan keliru. Kebijakan ini dirancang dengan ambang batas toleransi yang sangat rasional (hanya melarang registry tidak dikenal, tag `:latest`, ekskalasi *privilege*, user root, dan manifes tanpa limitasi resource). Developer yang mematuhi standar *best practices* cloud-native tidak akan terganggu oleh kebijakan ini.

**Hasil Falco:** Gejala *false positive* pada aktivitas operasional harian tidak ditemukan. Berbagai instruksi pemeriksaan rutin seperti `kubectl logs`, `kubectl exec -- ls`, serta `kubectl exec -- ps aux` berhasil dilewati dengan aman. Aturan kustom runtime kami dikonfigurasi secara spesifik hanya untuk memitigasi *interactive shell spawning* (`proc.name in [bash, sh, zsh]` dengan `proc.tty=0`). Satu-satunya aksi yang berhasil memicu alarm *Critical* dan tindakan mitigasi adalah pod kontrol positif yang mengeksekusi serangan simulasi (`bash -c "echo simulated-attack"`).

**Dampak ke developer:** Dalam skenario riil, developer tidak akan mengalami gangguan *intermittent block* pada skrip otomasi CI/CD mereka, karena aktivitas non-interaktif pipeline (seperti pemanggilan perintah tunggal via *exec*) tidak dikategorikan sebagai ancaman runtime oleh Falco rules yang telah dimodifikasi ini.

---

## 4. Trade-off yang ditemukan

**Pipeline overhead vs Jaminan Keamanan:**
Tambahan durasi sebesar +2 detik (+0.45%) dari total running pipeline ~7 menit 19 detik merupakan harga trade-off yang sangat murah dibandingkan proteksi preventif yang didapatkan. OPA bertindak sebagai *gatekeeper* tangguh di hulu, memastikan celah keamanan pada manifes Kubernetes langsung tereliminasi sebelum menyentuh lingkungan klaster.

**Detection delay vs Ketersediaan Aplikasi (Production Availability):**
Dengan rata-rata MTTD 0.599 detik dan MTTR 0.244 detik, total waktu penanganan ancaman berada di bawah 1 detik (0.844 detik). Ketika diuji pada arsitektur aplikasi berskala produksi yang memanfaatkan multi-replica (misal: `taskflow-api` dengan `replicas=3`), rata-rata *downtime* sistem hanya menyentuh ~1.8 detik. Hal ini dikarenakan mekanisme internal Kubernetes *Service* langsung mengalihkan beban trafik ke pod replika lain yang sehat saat pod penyerang diterminasi oleh sistem remediasi otomatis.

**Webhook Single Point of Failure (SPoF):**
Komponen webhook penampung log Falco merupakan jalur kritis (*critical path*) dalam rantai remediasi otomatis ini. Jika pod webhook mengalami gangguan, eksekusi pembersihan pod penyerang akan kehilangan kapabilitas instan detoksifikasinya dan terpaksa bergantung pada mekanisme *fallback* (seperti `ClusterCleanupPolicy` milik Kyverno) yang memiliki jeda interval pemindaian berkala (per 1 menit). Untuk lingkungan produksi, penggunaan replikasi pod pada deployment webhook mutlak diperlukan.

---

## 5. Batasan implementasi kelompok dibanding paper asli

1. **Skala Testbed Eksperimen:** Paper A mengevaluasi sistem menggunakan 50 manifest riil pada aplikasi EHR (Electronic Health Record) yang kompleks, sementara pengujian kelompok dibatasi pada 20 manifes sintetik yang direkayasa untuk menguji fungsionalitas komponen `taskflow-api`. 
2. **Cakupan Vektor Serangan:** Paper B mengasumsikan deteksi ancaman runtime yang komprehensif, sedangkan implementasi runtime security kelompok saat ini baru difokuskan pada skenario *unauthorized shell spawning* (`Terminal shell in container`), belum mencakup anomali jaringan (*network anomalies*), modifikasi biner (*file tampering*), atau aktivitas *crypto-mining*.
3. **Karakteristik Klaster Pengujian:** Seluruh eksperimen dijalankan di atas lingkungan lokal Minikube dengan resource terbatas (4 CPU, 8 GB RAM). Metrik latensi jaringan dan performa penanganan pod kemungkinan besar akan bervariasi jika dihadapkan pada klaster multi-node produksi dengan beban kerja (*workload*) yang tinggi.
4. **Isolasi Komponen Keamanan:** Komponen Falco dan pod webhook remediasi berjalan di dalam namespace yang sama (`falco`). Kerusakan atau serangan penolakan layanan (DoS) yang melumpuhkan namespace tersebut akan mematikan seluruh sistem deteksi sekaligus remediasi secara bersamaan.
5. **Variansi Latensi MTTR:** Pada pengujian runtime (Run 1), nilai MTTR sempat menyentuh angka 0.726 detik akibat fluktuasi waktu pemrosesan API server lokal saat menerima instruksi penghapusan pod. Paper B asli cenderung menyajikan angka rata-rata performa tanpa menampilkan sebaran variansi latensi ekstrem secara mendetail.