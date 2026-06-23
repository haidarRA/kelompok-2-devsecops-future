# Reading Notes — Stanišić et al. (2026)

**Judul:** Automated Security Validation in Healthcare DevSecOps: A Policy-as-Code Implementation for Kubernetes Environments  
**Penulis:** Sava Stanišić, Željko Jovanović, Borislav Đorđević  
**Venue:** 25th International Symposium INFOTEH-JAHORINA, 18–20 March 2026  
**DOI:** 10.1109/INFOTEH68759.2026.11477587  
**Dibaca:** 23 Juni 2026

---

## 1. Klaim Utama dan Cara Membuktikannya

**Klaim inti:** Policy-as-Code menggunakan OPA (Open Policy Agent) dapat memblokir 92% misconfigurasi kritis di lingkungan Kubernetes *sebelum* mencapai produksi, dengan overhead pipeline yang dapat diabaikan.

**Cara pembuktian:**

Paper menggunakan pendekatan eksperimen terkontrol. Mereka membangun kluster Kubernetes 3-node yang mensimulasikan lingkungan DMZ rumah sakit, lalu menjalankan 50 skenario deployment yang sengaja mengandung pelanggaran keamanan di tiga kategori:

| Kategori | Jumlah Kasus | Terblokir | False Positive | Detection Rate |
|---|---|---|---|---|
| Data Encryption | 15 | 15 | 0 | 100% |
| Network Exposure | 20 | 18 | 1 | 90% |
| Secrets Management | 15 | 13 | 0 | 87% |
| **Total** | **50** | **46** | **1** | **92%** |

Bukti implementasi disajikan secara konkret: mereka menampilkan kode Rego aktual (`encryption.rego`, `network.rego`, `secrets.rego`), bukan pseudocode semata. Validasi error message juga ditunjukkan verbatim — misalnya denial message `"FAIL: Resource patient-records-db handles high-sensitivity data without encryption-at-rest label"`. Ini menunjukkan sistem benar-benar berjalan, bukan sekadar simulasi.

Overhead performa diukur secara langsung (Tabel 2): deployment time naik dari 45,2s menjadi 46,8s (+3,5%), CPU +3%, memori +11%.

---

## 2. Temuan Kunci yang Langsung Relevan untuk Implementasi Saya

**a. Arsitektur tiga-lapisan sebagai referensi desain**  
Paper mendefinisikan tiga komponen yang bisa langsung dipetakan ke implementasi saya:
- *Policy Definition Layer* → file Rego (`image-policy.rego`, `security-context.rego`, `resource-policy.rego`)
- *Admission Control Layer* → OPA webhook yang sudah berjalan di kluster
- *Audit and Monitoring Layer* → logging ke CSV (`test-log-opa.csv`, `test-log-runtime.csv`)

Ini mengkonfirmasi bahwa pemisahan tiga lapisan ini bukan over-engineering, melainkan *best practice* yang memungkinkan kebijakan diperbarui tanpa menyentuh pipeline deployment.

**b. Pola sequential fail-fast**  
Algorithm `validateDeployment()` mengevaluasi kebijakan secara urut dan berhenti di kegagalan pertama. Ini relevan untuk menjelaskan *mengapa* urutan policy di pipeline saya dipilih demikian: image policy dievaluasi sebelum security context, karena image yang tidak valid tidak perlu dicek konteks keamanannya.

**c. Overhead pipeline sebagai angka pembanding**  
Paper melaporkan +3,5% overhead waktu deployment. Hasil eksperimen saya menunjukkan +2 detik (+1,2%) dari baseline ~2m 42s. Angka overhead saya lebih kecil, kemungkinan karena cakupan kebijakan yang lebih sempit (3 policy domain vs. 3 domain paper yang mencakup WAF annotation). Ini bisa menjadi poin komparasi eksplisit di bagian analisis.

**d. Modularitas sebagai argumen teknis**  
Paper secara eksplisit memotivasi desain modular (3 file Rego terpisah, bukan monolitik) dengan alasan *selective enforcement*: lingkungan berbeda membutuhkan subset kebijakan berbeda. Ini justifikasi yang kuat untuk diangkat di bagian metodologi implementasi saya.

---

## 3. Asumsi dan Keterbatasan yang Disebutkan Paper

**Asumsi yang disebutkan eksplisit:**
- Environment menggunakan standar Kubernetes native (tidak ada custom CRD exotis)
- Semua resource menggunakan label konvensi yang sudah ditentukan (`data-sensitivity`, `encryption-at-rest`) — sistem bergantung pada kepatuhan developer terhadap labeling convention
- "Hospital DMZ" yang disimulasikan diasumsikan representatif, padahal ini lingkungan lab, bukan sistem EHR produksi nyata

**Keterbatasan yang diakui penulis:**
- Hanya *static manifest validation* (statis, pre-deployment). Sistem tidak mendeteksi ancaman *runtime* — Falco dan runtime security sama sekali tidak disebut
- Paper ini disebut sebagai "*foundational pillar*"; arsitektur penuh dengan ML untuk risk-based scoring dan konteks klinis real-time akan diterbitkan di makalah berikutnya. Artinya, evaluasi ini belum lengkap
- 50 skenario uji adalah angka yang relatif kecil dan kemungkinan besar dikurasi manual, bukan diambil dari log insiden nyata

**Keterbatasan yang *tidak* diakui tapi tersirat:**
- False positive di kategori Network Exposure (1 dari 20 kasus) tidak dianalisis. Apa penyebabnya? Manifest edge case? Regex terlalu agresif? Paper tidak menjelaskan
- Tool stack yang digunakan cukup baru (Kubernetes v1.33.5, OPA v1.9.0) — reproducibility di versi lebih lama tidak dijamin

---

## 4. Satu Hal yang Saya Ragukan dari Paper Ini

**Kerepresentatifan 50 skenario uji.**

Paper mengklaim detection rate 92% dan menyimpulkan sistem "dapat mencegah misconfigurasi kritis sebelum produksi." Tapi 50 skenario yang dipilih terasa seperti *cherry-picked* — dibuat untuk membuktikan kebijakan yang sudah ditulis, bukan untuk mencari celah kebijakan tersebut.

Bukti skeptisisme saya: kategori Data Encryption mencapai 100% detection, tapi ini hanya berarti 15 skenario yang dibuat persis sesuai dengan apa yang `encryption.rego` rancang untuk ditangkap. Tidak ada pengujian *adversarial* — misalnya, apakah kebijakan bisa dibypass dengan label `encryption-at-rest: "TRUE"` (kapitalisasi berbeda) vs `"true"`? Atau dengan menempatkan secret di field yang tidak di-scan regex `secrets.rego`?

Angka 92% terasa lebih seperti *coverage metric* (berapa banyak skenario yang dibuat cocok dengan rule yang ada) daripada *detection rate* sejati (berapa persen dari semua cara nyata orang bisa melakukan misconfigurasi yang berhasil terdeteksi). Ini perbedaan fundamental yang tidak dibahas paper.

Implikasinya untuk implementasi saya: sebaiknya saya menambahkan *adversarial test cases* di luar yang sudah ada di `evaluation/` — misalnya skenario yang secara intuitif berbahaya tapi *tidak* terdeteksi oleh policy saat ini, untuk mengukur batas sebenarnya dari sistem.

---

## Koneksi ke Implementasi Saya

Hasil eksperimen saya (lihat `evaluation/`) menunjukkan 100% detection rate dan 0% false positive pada 20 skenario — lebih baik dari paper pada metrik OPA. Hal ini bukan berarti implementasi saya lebih superior; kemungkinan besar mencerminkan cakupan skenario yang lebih sempit dan terkontrol. Paper ini berguna sebagai *upper bound* komparasi dan sebagai justifikasi pendekatan arsitektur, bukan sebagai baseline angka yang perlu dikalahkan.

Yang lebih signifikan: implementasi saya menambahkan dimensi *runtime detection* (Falco + Kyverno, MTTD 0,60 detik) yang sama sekali tidak ada di paper ini. Ini adalah kontribusi nyata yang membedakan scope kedua karya.