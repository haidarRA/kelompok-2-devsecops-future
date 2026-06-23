# Analysis — Apakah Berhasil? Seberapa?

## 1. Apakah hasil sesuai dengan klaim paper?

| Metrik | Klaim Paper | Hasil Kelompok | Sesuai? |
|--------|-------------|------------------|---------|
| Paper A — Detection rate | 92% | 100% (15/15) | **Melebihi** |
| Paper A — Pipeline overhead | +3.5% | +1.2% (+2 detik) | **Lebih baik** |
| Paper B — MTTD | "near real-time" | 0.67 detik | **Sesuai** |
| Paper B — MTTR | "near real-time" | 2.03 detik | **Sesuai** |

**Penjelasan selisih:**
- Detection rate kelompok (100%) lebih tinggi dari Paper A (92%) karena jumlah skenario lebih kecil (20 vs 50) dan skenario dipilih agar fully testable.
- Pipeline overhead lebih rendah karena conftest execution time dominan oleh startup time (fixed cost), yang relatif konstan terlepas dari jumlah manifest.

## 2. Skenario mana yang tidak sesuai ekspektasi?

**Semua skenario sesuai ekspektasi (20/20 PASS).** Tidak ada kasus di mana `actual != expected`.

Namun, ada beberapa catatan:
- **S1-01 (361 ms):** Response time lebih tinggi dari rata-rata (54 ms) karena ini adalah skenario pertama yang dieksekusi — cold start conftest memuat policy engine dari disk.
- **S4 series:** Semua manifest compliant lulus dengan benar (ALLOW), membuktikan bahwa policy tidak over-restrictive.

## 3. False positive — apakah mengganggu developer?

**Hasil OPA:** False positive rate = 0%. Kelima manifest compliant (S4-01 sampai S4-05) lulus tanpa ditolak. Policy dirancang dengan batasan yang masuk akal: hanya memblokir registry yang tidak dikenal, tag `:latest`, privilege escalation, root user, dan resource tanpa batas. Developer yang mengikuti praktik baik (registry resmi, non-root, resource wajar) tidak akan terganggu.

**Hasil Falco:** False positive pada operasi normal tidak terjadi. Operasi seperti `kubectl logs`, `kubectl exec -- ls`, dan `kubectl exec -- ps aux` tidak memicu aturan `Terminal shell in container` karena aturan dikustomisasi untuk hanya memicu pada spawn shell interaktif (`bash -c "..."`). Satu-satunya operasi yang memicu adalah kontrol positif (`bash -c "echo simulated-attack"`).

**Dampak ke developer:** Dalam skenario nyata, developer mungkin terganggu jika Falco terlalu sensitif terhadap skrip CI/CD yang legitimate. Namun, custom rules kami hanya mendeteksi spawn shell dari interaksi pengguna (`proc.name in [bash, sh, zsh]` dengan `proc.tty=0`), sehingga build pipeline (yang biasanya menggunakan `docker exec` atau `kubectl exec` non-interaktif) tidak terdeteksi.

## 4. Trade-off yang ditemukan

**Pipeline overhead vs keamanan:**
Overhead +2 detik (+1.2%) sangat kecil dibandingkan manfaat keamanan. Sebagai perbandingan, unit test stage biasanya memakan waktu 30-60 detik. OPA check adalah investasi yang sangat efisien.

**Detection delay vs production requirements:**
MTTD rata-rata 0.67 detik dan MTTR 2.03 detik. Untuk skenario production dengan replika tinggi (3+ pod), downtime aplikasi kurang dari 2 detik karena pod lain tetap melayani traffic. Delay ini acceptable untuk大多数 use case.

**Webhook single point of failure:**
Webhook adalah komponen kritis dalam pipeline remediasi. Jika webhook down, remediasi hanya bergantung pada Kyverno ClusterCleanupPolicy yang berjalan setiap 1 menit. Untuk production, disarankan menambahkan replica webhook (saat ini hanya 1 replica).

## 5. Batasan implementasi kelompok dibanding paper asli

1. **Skala testbed:** Paper A diuji dengan 50 manifest dan aplikasi EHR sungguhan; kelompok menggunakan 20 manifest sintetis pada taskflow-api. Jumlah skenario yang lebih kecil membatasi generalisability hasil.

2. **Cakupan serangan:** Paper B mengasumsikan Falco mendeteksi HANYA shell spawning; serangan lain (file tampering, network anomaly, crypto mining) tidak tercakup. Implementasi kami juga hanya mencakup shell spawning.

3. **Cluster production vs Minikube:** Pengujian dilakukan di Minikube dengan resource terbatas (4 CPU, 8 GB RAM). Hasil latency mungkin berbeda di cluster production dengan beban tinggi.

4. **Pod availability:** Falco dan webhook berjalan di namespace yang sama (`falco`), sehingga kegagalan namespace dapat mempengaruhi kedua komponen. Paper B tidak membahas disaster recovery untuk komponen keamanan itu sendiri.

5. **MTTR variance:** Pada beberapa run, MTTR mencapai 3+ detik karena variasi latensi jaringan antara webhook dan API server. Paper B tidak memberikan distribusi MTTR, hanya rata-rata.

6. **Falco rule coverage:** Custom rules kami hanya mendeteksi `Terminal shell in container`. Paper A mencakup spektrum kebijakan yang lebih luas (image trust, resource, security context) tetapi hanya pada CI time, bukan runtime.
