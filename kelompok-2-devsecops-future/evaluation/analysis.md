# Analysis — Apakah Berhasil? Seberapa?

> Diisi setelah evaluation/metrics-after.md lengkap. Dosen secara eksplisit
> meminta analisis jujur, bukan hanya angka berhasil/gagal.

## 1. Apakah hasil sesuai dengan klaim paper?

Bandingkan angka kalian dengan klaim asli paper:

| Metrik | Klaim Paper | Hasil Kelompok | Sesuai? |
|--------|-------------|------------------|---------|
| Paper A — Detection rate (Tabel 1 paper) | 92% | | |
| Paper A — Pipeline overhead | +3.5% | | |
| Paper B — MTTD/MTTR | "near real-time" (tidak ada angka eksak di paper) | | |

Kalau ada selisih signifikan, jelaskan kemungkinan penyebabnya:
- Skala testbed berbeda (paper pakai cluster lebih besar / EHR app sungguhan)
- Kondisi resource Minikube lokal (CPU/RAM terbatas) vs cluster paper
- Jumlah skenario uji berbeda (paper A: 50 manifest, kelompok: 20 manifest)
- ...

## 2. Skenario mana yang tidak sesuai ekspektasi?

Tulis SEMUA kasus dimana `actual != expected`, bukan hanya yang sukses:

- Skenario apa yang gagal?
- Apa hipotesis penyebabnya? (policy rego salah, kondisi race, dsb.)
- Apakah ini bug di policy kalian, atau memang batasan pendekatan ini?

## 3. False positive — apakah mengganggu developer?

Dari hasil S4 (OPA) dan RT-03 (Falco), apakah ada false positive?
Kalau ada, apa dampaknya ke workflow developer dalam skenario nyata?

## 4. Trade-off yang ditemukan

- Apakah overhead pipeline (waktu tambahan dari OPA check) sepadan dengan
  manfaat keamanan yang didapat?
- Apakah delay MTTD/MTTR Falco (kalau lebih lambat dari klaim paper)
  cukup cepat untuk skenario produksi nyata?

## 5. Batasan implementasi kelompok dibanding paper asli

- Paper A diuji dengan 50 manifest dan aplikasi EHR sungguhan;
  kelompok menggunakan 20 manifest sintetis pada taskflow-api.
- Paper B mengasumsikan Falco mendeteksi HANYA shell spawning;
  serangan lain (file tampering, network anomaly) tidak tercakup.
- Sebutkan batasan lain yang kelompok temukan selama implementasi.
