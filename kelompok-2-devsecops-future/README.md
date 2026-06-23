# Week 16 — DevSecOps Enhancement Scaffold

Paket ini berisi implementasi siap-pakai untuk dua enhancement keamanan
pada pipeline `week12-devops-kelompok2`, berdasarkan dua paper IEEE:

- **Paper A** — OPA Policy-as-Code untuk admission control (Stanišić et al., 2026)
- **Paper B** — Falco + Kyverno untuk runtime threat detection & auto-remediation
  (Shenoy et al., 2025)

## Mulai dari Sini

**Kalau kalian punya AI coding agent** (Claude Code, Cursor, dll.) yang berjalan
di mesin lokal dengan akses ke repo Git dan Minikube kalian:

→ Buka **`AGENT_PROMPT.md`**, copy bagian "PROMPT MULAI DI SINI" sampai
"PROMPT SELESAI DI SINI", tempel ke agent kalian bersama folder ini.

**Kalau mau jalankan manual:**

→ Ikuti langkah yang sama persis seperti di `AGENT_PROMPT.md`, tapi
dieksekusi sendiri satu per satu.

## Isi Paket

```
week16-enhancement/
├── AGENT_PROMPT.md                          <- prompt siap pakai untuk AI agent
├── policies/opa/                            <- 3 Rego policy (Paper A)
│   ├── image-policy.rego
│   ├── security-context-policy.rego
│   └── resource-policy.rego
├── implementation/
│   ├── falco/custom-rules.yaml              <- rule deteksi shell spawn (Paper B)
│   ├── kyverno/delete-suspicious-pods.yaml  <- auto-delete policy (Paper B)
│   └── webhook/                             <- Flask webhook + Dockerfile + manifest
│       ├── app.py
│       ├── Dockerfile
│       ├── requirements.txt
│       └── webhook-manifests.yaml           <- termasuk RBAC least-privilege
├── ci/gitlab-ci-additions.yml               <- job baru untuk .gitlab-ci.yml
├── evaluation/
│   ├── test-manifests/opa/                  <- 20 skenario uji (S1-01 s/d S4-05)
│   ├── test-manifests/runtime/              <- pod simulasi attacker
│   ├── metrics-before.md                    <- template baseline
│   ├── metrics-after.md                     <- template hasil lengkap
│   └── analysis.md                          <- template analisis jujur
└── scripts/
    ├── run-opa-tests.sh                     <- otomatis test 20 skenario -> CSV
    └── run-runtime-tests.sh                 <- otomatis ukur MTTD/MTTR 5x -> CSV
```

## Catatan Penting

1. **Status paper**: Paper A diterbitkan Maret 2026 — di luar range
   "2021-2025" yang diminta modul. Sudah dikonfirmasi ke dosen, tapi
   sebutkan ini secara eksplisit di `papers/paper-1-*.md` agar tidak jadi
   pertanyaan dadakan saat presentasi.

2. **File yang BELUM dibuatkan** (sengaja, karena ini bagian penilaian kritis
   yang harus kalian tulis sendiri, bukan di-generate):
   - `papers/paper-1-*.md`, `papers/paper-2-*.md` — reading notes
   - `research/01-gap-analysis.md`, `02-state-of-the-art.md`,
     `03-design-decisions.md`
   - `docs/refleksi-kelompok.md`

   Modul secara eksplisit menilai "kedalaman baca, kemampuan berpikir kritis"
   (20% bobot) — ini harus mencerminkan pemahaman kalian sendiri terhadap
   kedua paper, bukan hasil generate AI.

3. **Sebelum jalankan di environment nyata**, baca ulang bagian "Batasan
   Penting" di akhir `AGENT_PROMPT.md` — terutama soal jangan langsung push
   ke `main` dan jangan melemahkan policy supaya test lolos.
