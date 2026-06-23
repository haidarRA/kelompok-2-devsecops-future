# Gap Analysis — Dari Baseline Menuju Enhancement Berbasis Riset

## 1. Pendahuluan

Dokumen ini mengidentifikasi celah keamanan yang ada pada pipeline DevSecOps baseline (Week 12) dan memetakan setiap celah ke enhancement berbasis riset yang bersumber dari Paper A dan Paper B. Analisis mengikuti struktur: **kondisi saat ini → gap → solusi yang diusulkan → peningkatan yang diharapkan**.

**Paper A:** Stanišić et al., *"Automated Security Validation in Healthcare DevSecOps: A Policy-as-Code Implementation for Kubernetes Environments"*, INFOTEH-JAHORINA 2026 (IEEE).

**Paper B:** Shenoy et al., *"Runtime Threat Mitigation in Kubernetes Using Falco, Falcosidekick, and Kyverno: An Automated Pod Deletion Approach"*, ICCCA 2025 (IEEE).

---

## 2. Gap 1: Tidak Ada Policy Enforcement Otomatis di Tahap CI

**Kondisi Saat Ini (Baseline):** Pipeline GitLab CI pada Week 12 melakukan build, packaging, dan deployment aplikasi `taskflow-api`. Tidak ada validasi otomatis terhadap Kubernetes manifest sebelum deployment dijalankan. Developer dapat secara tidak sengaja men-deploy pod dengan privilege root, mengekspos port database secara publik, atau mendeploy container tanpa label keamanan yang dipersyaratkan. Pelanggaran semacam ini hanya akan terdeteksi — kalau pun terdeteksi — melalui review manual.

**Gap yang Diidentifikasi:** Pipeline tidak memiliki security gate "shift-left". Konfigurasi yang rentan dapat masuk ke cluster sebelum siapapun menyadarinya. Paper A mendemonstrasikan bahwa validasi Policy-as-Code berbasis OPA/Rego mampu memblokir 92% misconfiguration kritis Kubernetes sebelum masuk ke cluster — mencakup domain enkripsi data, network exposure, dan secrets management — sementara pipeline baseline saat ini memblokir 0%. Paper A juga menegaskan bahwa ketiadaan security gate ini adalah celah sistemik yang umum dijumpai di sebagian besar pipeline DevSecOps, termasuk di domain yang diregulasi ketat.

**Solusi yang Diusulkan (dari Paper A):** Menambahkan stage `validate-k8s-manifest` ke dalam pipeline CI menggunakan OPA dengan policy Rego yang menargetkan minimal tiga domain keamanan: (1) pengecekan label `encryption-at-rest` untuk workload sensitif, (2) aturan network exposure untuk mencegah service database terekspos secara publik melalui tipe `LoadBalancer`, dan (3) pemeriksaan secrets management untuk mendeteksi kredensial plaintext di dalam deployment manifest. Policy check dijalankan sebelum image apapun dibangun atau dideploy, sehingga pipeline langsung gagal pada pelanggaran pertama dengan pesan penolakan yang deskriptif.

**Peningkatan yang Diharapkan:** Deteksi misconfiguration kritis bergeser dari 0% (baseline) menjadi ≥92% sebelum workload apapun masuk ke cluster, mengacu pada tingkat deteksi yang dicapai Paper A. Overhead pipeline diperkirakan minimal mengingat Paper A melaporkan dampak performa hanya +3.5% pada deployment time dan +3% CPU usage saat OPA diaktifkan.

---

## 3. Gap 2: Tidak Ada Deteksi Ancaman Runtime

**Kondisi Saat Ini (Baseline):** Setelah pod berjalan di dalam cluster, tidak ada mekanisme untuk mendeteksi perilaku mencurigakan seperti eksekusi shell tidak sah, privilege escalation, atau file tampering. Seorang penyerang yang berhasil mendapatkan akses `exec` ke dalam container dapat menjalankan perintah semena-mena tanpa alert apapun yang terpicu.

**Gap yang Diidentifikasi:** Baseline memiliki zero visibility di level runtime. Paper B mendemonstrasikan bahwa Falco yang berjalan sebagai DaemonSet di seluruh node mampu mendeteksi aktivitas shell spawning di dalam container dalam hitungan detik melalui pemantauan system call di level kernel. Namun tanpa deployment Falco, pipeline baseline sepenuhnya buta terhadap ancaman yang terjadi setelah deployment — fase yang justru paling rawan dieksploitasi oleh penyerang.

**Solusi yang Diusulkan (dari Paper B):** Deploy Falco sebagai DaemonSet dengan custom rule untuk mendeteksi event `Terminal shell in container` — yakni setiap kali proses `bash`, `sh`, atau `zsh` dieksekusi di dalam container. Alert yang dihasilkan Falco diteruskan secara real-time melalui Falcosidekick ke endpoint yang telah dikonfigurasi (webhook atau logging system).

**Peningkatan yang Diharapkan:** MTTD (Mean Time to Detect) untuk serangan shell spawning turun dari tidak terdefinisi (baseline tidak dapat mendeteksi sama sekali) menjadi di bawah 2 detik, sesuai dengan hasil eksperimental yang ditunjukkan Paper B di lingkungan Minikube.

---

## 4. Gap 3: Tidak Ada Remediasi Otomatis

**Kondisi Saat Ini (Baseline):** Bahkan jika ancaman runtime berhasil dideteksi (yang tidak mungkin terjadi di baseline), tidak ada mekanisme untuk merespons secara otomatis. Pod yang telah dikompromis dapat terus berjalan tanpa batas waktu, memberikan penyerang akses persisten ke dalam cluster.

**Gap yang Diidentifikasi:** Jarak antara deteksi dan respons bersifat tak terbatas di baseline. Paper B mengusulkan dan mengimplementasikan pipeline remediasi otomatis: Falco mendeteksi ancaman → Falcosidekick meneruskan alert → Webhook Server memberi label `suspicious=true` pada pod → Kyverno ClusterPolicy menghapus pod secara otomatis. Tanpa komponen-komponen ini, cluster tetap terekspos selama penyerang masih aktif.

**Solusi yang Diusulkan (dari Paper B):** Deploy Flask webhook server yang menerima alert JSON dari Falcosidekick, mengekstrak nama pod dan namespace, lalu menerapkan label `suspicious=true` menggunakan `kubectl`. Deploy Kyverno dengan ClusterPolicy yang secara otomatis menghapus setiap pod berlabel `suspicious=true` segera setelah label tersebut terdeteksi, tanpa memerlukan intervensi manusia.

**Peningkatan yang Diharapkan:** MTTR (Mean Time to Remediate) turun dari tidak terdefinisi (baseline tidak dapat merespons sama sekali) menjadi di bawah 3 detik untuk serangan yang terdeteksi, mengacu pada hasil eksperimental Paper B yang membuktikan pod dikompromis berhasil dihapus secara otomatis segera setelah shell spawning terjadi.

---

## 5. Gap 4: Tidak Ada Pengumpulan Metrik Keamanan

**Kondisi Saat Ini (Baseline):** Tidak ada pengumpulan metrik keamanan secara sistematis — tidak ada detection rate, tidak ada false positive rate, tidak ada response time. Tanpa metrik, tidak mungkin untuk mengevaluasi apakah suatu investasi keamanan benar-benar efektif atau tidak.

**Gap yang Diidentifikasi:** Pipeline tidak dapat membuktikan adanya peningkatan tanpa pengukuran before/after yang terstruktur. Baik Paper A maupun Paper B menggunakan metrik kuantitatif untuk memvalidasi pendekatan mereka: Paper A mengukur detection rate (92%), false positive rate, dan overhead performa; Paper B mengukur MTTD dan MTTR dari pipeline deteksi-remediasi. Tanpa instrumen pengukuran serupa, klaim "pipeline lebih aman" hanya bersifat anekdotal.

**Solusi yang Diusulkan:** Mengimplementasikan test script otomatis — `run-opa-tests.sh` untuk menguji sejumlah skenario manifest validation, dan `run-runtime-tests.sh` untuk mensimulasikan siklus serangan runtime — yang menghasilkan output terstruktur (CSV atau log) sebagai data evaluasi. Metrik yang dikumpulkan mencakup: detection rate, false positive rate, MTTD, MTTR, dan overhead pipeline.

**Peningkatan yang Diharapkan:** Tersedianya data baseline (before) dan data pasca-enhancement (after) yang dapat dibandingkan secara kuantitatif di seluruh dimensi keamanan yang diukur.

---

## 6. Tabel Ringkasan Gap

| # | Gap | Tingkat Kritis | Paper | Solusi | Metrik Utama |
|---|-----|----------------|-------|--------|--------------|
| 1 | Tidak ada CI policy gate | Tinggi | A | OPA/Rego admission stage | Detection Rate → ≥92% |
| 2 | Tidak ada deteksi runtime | Kritis | B | Falco + Falcosidekick | MTTD → < 2 detik |
| 3 | Tidak ada remediasi otomatis | Kritis | B | Webhook + Kyverno ClusterPolicy | MTTR → < 3 detik |
| 4 | Tidak ada metrik keamanan | Sedang | A & B | Test script + output CSV | Perbandingan Before/After |
