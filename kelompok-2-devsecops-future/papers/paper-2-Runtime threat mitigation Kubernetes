# Reading Notes — Paper 2

**Judul:** Runtime Threat Mitigation in Kubernetes Using Falco, Falcosidekick, and Kyverno: An Automated Pod Deletion Approach

**Penulis:** Aditya Mohan Shenoy, Dr. Swetha P, Prasad B Honnavali

**Tahun:** 2025

**Venue:** 2025 IEEE 7th International Conference on Computing, Communication and Automation (ICCCA)
DOI: 10.1109/ICCCA66364.2025.11325363

---

## 1. Klaim Utama Paper dan Cara Membuktikannya

Paper ini mengklaim bahwa kombinasi tiga tool open-source — **Falco** (runtime threat detection), **Falcosidekick** (alert forwarding), dan **Kyverno** (policy-based automated remediation) — dapat membentuk pipeline yang sepenuhnya otomatis untuk mendeteksi dan merespons ancaman runtime di Kubernetes, khususnya *unauthorized shell spawning* di dalam container, **tanpa intervensi manusia**.

### Cara Pembuktian

Penulis menggunakan pendekatan **proof-of-concept eksperimental** di lingkungan lokal:

- **Environment:** Minikube di mesin lokal (bukan production cluster)
- **Skenario serangan simulasi:** Membuat pod `ubuntu-attacker`, lalu mengeksekusi `kubectl exec -it ubuntu-attacker -- bash` untuk men-trigger shell spawning
- **Pipeline yang diverifikasi:**
  1. Falco mendeteksi syscall `bash/sh/zsh` di dalam container
  2. Falcosidekick meneruskan alert JSON ke webhook Flask
  3. Webhook Flask melabeli pod dengan `suspicious=true` via `kubectl label`
  4. Kyverno ClusterPolicy mendeteksi label tersebut dan menghapus pod secara otomatis
- **Bukti keberhasilan:** Screenshot Falco logs (Fig. 11), screenshot pod terhapus (Fig. 13), dan process flow diagram (Fig. 14)

**Catatan kritis:** Paper tidak menyajikan data kuantitatif yang sistematis (misalnya MTTD/MTTR yang diukur secara eksplisit dengan angka). Klaim "reducing dwell time" disebutkan di kesimpulan tetapi tidak didukung tabel perbandingan metrik before/after yang terukur.

---

## 2. Temuan Kunci yang Langsung Relevan untuk Implementasi

### 2.1 Arsitektur Pipeline (Langsung Dapat Diimplementasikan)

Paper menyajikan arsitektur modular 4-komponen yang dapat direproduksi:

| Komponen | Peran | Teknologi |
|---|---|---|
| Falco (DaemonSet) | Kernel-level syscall monitoring | eBPF/kernel module |
| Falcosidekick | Alert routing & forwarding | Helm chart |
| Custom Webhook (Flask) | Label application via kubectl | Python + Docker |
| Kyverno ClusterPolicy | Automated pod deletion | Policy-as-code |

### 2.2 Custom Falco Rule yang Actionable

Paper memberikan rule YAML yang siap pakai untuk mendeteksi shell spawning:

```yaml
- rule: Terminal shell in container
  condition: container.id != host and proc.name in (bash, sh, zsh)
  priority: CRITICAL
```

Rule ini di-inject melalui Kubernetes ConfigMap (bukan memodifikasi `rules.yaml` inti) — pendekatan yang aman dan dapat direproduksi.

### 2.3 Kyverno ClusterPolicy untuk Auto-Deletion

Policy `delete-suspicious-pods` bekerja berdasarkan label selector `suspicious: "true"`, memisahkan logika *detection* dari *remediation* — desain yang bersih dan extensible.

### 2.4 Gap yang Diisi Paper Ini

Paper secara eksplisit mengidentifikasi bahwa **tidak ada penelitian peer-reviewed sebelumnya** yang mengevaluasi kombinasi Falco + Falcosidekick + Kyverno sebagai pipeline terintegrasi untuk automated pod deletion. Penelitian sebelumnya hanya mengkaji komponen secara terpisah.

### 2.5 Relevansi untuk Pipeline DevSecOps

Paper menunjukkan cara mengintegrasikan runtime security ke dalam cluster Kubernetes yang sudah ada tanpa vendor lock-in, menggunakan semua CNCF tools — relevan langsung dengan prinsip DevSecOps modern.

---

## 3. Asumsi dan Keterbatasan yang Disebutkan Paper

### Asumsi Eksplisit

1. **Asumsi lingkungan lokal:** Seluruh implementasi dijalankan di **Minikube** (single-node), bukan production cluster multi-node. Penulis sendiri tidak mengklaim validitas penuh di environment produksi.

2. **Asumsi threat model yang sempit:** Pipeline hanya dirancang untuk mendeteksi **satu vektor ancaman** — unauthorized shell spawning (`bash`, `sh`, `zsh`). Ancaman lain seperti lateral movement, file system tampering, atau network-based anomalies belum dicakup.

3. **Asumsi webhook Flask yang sederhana:** Webhook menggunakan `subprocess.call(["kubectl", "label", ...])` — artinya webhook harus memiliki akses kubectl ke cluster. Ini adalah asumsi privilege yang cukup besar dan berpotensi menjadi attack surface baru.

4. **Asumsi response yang binary:** Remediation hanya satu pilihan — **delete pod**. Tidak ada gradasi respons (isolate, quarantine, alert-only).

### Keterbatasan yang Disebutkan (Future Work)

- Belum mencakup lateral movement, privilege escalation, file system tampering
- Belum ada integrasi SIEM/SOAR (Splunk, ELK, Wazuh)
- Belum ada policy granularity (isolate vs delete vs notify)
- Belum ada AI-driven policy tuning untuk mengurangi false positives
- Belum diuji di production cluster dengan high-throughput workloads

### Keterbatasan yang *Tidak* Disebutkan (Analisis Kritis)

- **False positive risk:** Rule yang mendeteksi semua `bash/sh/zsh` di container akan sangat agresif — banyak legitimate operations (debugging, init containers, health check scripts) menggunakan shell. Paper tidak mendiskusikan dampak false positive deletion terhadap availability.
- **Race condition:** Ada jeda waktu antara Falco deteksi → Falcosidekick forward → Webhook labeling → Kyverno deletion. Pada serangan cepat, attacker mungkin sudah sempat mengeksekusi payload sebelum pod dihapus.
- **Evaluasi metrik tidak sistematis:** Paper tidak menyajikan pengukuran MTTD/MTTR secara numerik yang bisa dibandingkan dengan baseline tanpa sistem ini.

---

## 4. Satu Hal yang Saya Ragukan atau Pertanyakan

### Pertanyaan Kritis: Apakah "Pod Deletion" adalah Respons yang Tepat?

Saya mempertanyakan apakah **menghapus pod secara otomatis** adalah strategi yang tepat sebagai default response, bukan hanya pada skenario tertentu.

**Alasan keraguan:**

1. **Kehilangan forensic evidence:** Ketika pod dihapus, semua data dalam container (memory dumps, process trees, network connections) hilang. Dalam incident response yang sesungguhnya, preservasi evidence adalah prioritas — bukan destruksi cepat.

2. **Availability impact yang underestimated:** Di production cluster, pod deletion bisa memicu cascading failures jika pod tersebut adalah bagian dari stateful workload atau jika Kubernetes restart policy membuat pod terus di-recreate (jika attacker sudah ada di image, pod baru yang di-spawn juga akan vulnerable).

3. **False positive consequence yang serius:** Jika sebuah container menjalankan legitimate shell untuk health check atau init script, auto-deletion bisa menyebabkan outage yang lebih parah daripada ancaman yang coba dicegah.

**Referensi untuk perbandingan:** Pendekatan alternatif yang lebih konservatif — seperti *pod isolation* (mencabut network policy tapi tidak menghapus) atau *container pause* — akan mempertahankan forensic evidence sekaligus menghentikan serangan. Paper tidak membahas tradeoff ini secara mendalam.

**Implikasi untuk implementasi kelompok kami:** Kami perlu mempertimbangkan apakah default response yang tepat adalah deletion, atau apakah ada pendekatan yang lebih graduated (misalnya: alert → isolate → delete) yang lebih sesuai untuk production use case.

---

## Ringkasan Relevansi untuk Implementasi Kelompok

Paper ini memberikan **blueprint implementasi yang konkret dan reproducible** untuk runtime security di Kubernetes menggunakan Falco + Falcosidekick + Kyverno. Seluruh konfigurasi (Helm commands, YAML manifests, Flask code, Kyverno ClusterPolicy) disajikan secara eksplisit dan dapat langsung diadaptasi.

Gap utama yang diidentifikasi paper — tidak adanya studi end-to-end terintegrasi untuk automated pod deletion — adalah justifikasi ilmiah yang kuat mengapa topik ini layak diimplementasikan sebagai enhancement DevSecOps pipeline. Implementasi kelompok kami dapat memperluas paper ini dengan menambahkan metrik kuantitatif yang lebih sistematis (MTTD/MTTR) dan/atau response yang lebih graduated untuk mengatasi keterbatasan false positive yang diidentifikasi di atas.
