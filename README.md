# week12-devops-kelompok2
Tugas Week 12 DevOps Kelompok 12

| Nama | NRP |
| -------- | -------- |
| Haidar Rafi Aqyla | 5027231029 | 
| Furqon Aryadana | 5027231024 |
| Abid Ubaidillah A. | 5027231089 |
| Muhammad Hildan Adiwena| 5027231077 |
| Muhammad Kenas Galeno Putra | 	5027231069 |
| Benjamin Khawarizmi Habibi | 5027231078 |
| Arsyad Rizantha Maulana Salim | 5027221049 |

## 📌 Pengenalan

Modul ini mengajarkan cara menjalankan aplikasi dalam Kubernetes cluster. Topik:
- Objek dasar Kubernetes (Pod, Deployment, Service, Namespace)
- Mengelola container di production
- Rolling update dan rollback
- Pengenalan microservices

## 🛠️ Tech Stack & Prerequisite

**Tools yang harus dipasang:**
- **kubectl** — command line untuk cluster Kubernetes
- **minikube** — Kubernetes mini di laptop (atau Docker Desktop dengan Kubernetes enabled)
- **Docker** — untuk build & push image (dari modul sebelumnya)

**Instalasi:**
```bash
# macOS
brew install minikube kubectl

# Windows
# Download dari: https://minikube.sigs.k8s.io/docs/start/
# Dan: https://kubernetes.io/docs/tasks/tools/

# Verifikasi
minikube version
kubectl version --client
```

---

# Tugas 1 — Namespace Setup

## Tujuan
Memisahkan environment development dan production menggunakan Kubernetes Namespace.

## File
- `kubernetes/namespace-dev.yaml` — Namespace untuk environment development
- `kubernetes/namespace-prod.yaml` — Namespace untuk environment production

## Cara Menjalankan

### Prasyarat
- Kubernetes cluster berjalan (Docker Desktop / Minikube)
- `kubectl` terinstall

### Apply Namespace
```bash
kubectl apply -f kubernetes/namespace-dev.yaml
kubectl apply -f kubernetes/namespace-prod.yaml
```

### Verifikasi
```bash
kubectl get namespaces
```

Output yang diharapkan:
NAME            STATUS   AGE
taskflow-dev    Active   Xs
taskflow-prod   Active   Xs

## Penjelasan
Namespace digunakan untuk memisahkan resource Kubernetes agar environment dev dan prod tidak saling mengganggu. Jika terjadi kekacauan di `taskflow-dev`, maka `taskflow-prod` tetap berjalan normal.
EOF

<img width="1170" height="659" alt="IMG_1455" src="https://github.com/user-attachments/assets/0ce8f8a9-5618-4282-b233-62129acc7d4a" />


Cara Kerja
```
Control Plane (Otak)
    ↓
Worker Nodes (Server yang jalankan app)
    ↓
Pods (Container di dalam node)
```
Kubernetes memantau cluster dan membuat keputusan agar state sesuai dengan yang kamu definisikan di file YAML.

---

## Check Bagian 2

Jangan Lupa ->
```
minikube start --cpus=2 --memory=4096
```

Validate YAML → 
``` 
kubectl apply -f <file> --dry-run=client 
```
(preview tanpa apply)

Deploy → 
``` 
kubectl apply -f deployment-dev.yaml & kubectl apply -f service-dev.yaml 
```
Check Pod → 
```
kubectl get pods -n taskflow-dev 
```
(pastikan status Running)

Check Service → 
```
kubectl get svc -n taskflow-dev 
```
(pastikan punya IP & port)

Test akses → 
```
kubectl port-forward svc/taskflow-api 8080:80 -n taskflow-dev 
```
lalu akses http://localhost:8080

---

## **Dokumentasi**

**Validate YAML**

![alt text](<Screenshot/Screenshot 2026-05-26 165925.png>)


**Check Pod & Check Service**

![alt text](<Screenshot/Screenshot 2026-05-26 165708.png>)

**Test Akses**

![alt text](<Screenshot/Screenshot 2026-05-26 165755.png>)

**Deploy**

![alt text](<Screenshot/Screenshot 2026-05-26 165849.png>)


## Bagian 3
### Laporan Pengujian Insiden 1 — Self-Healing

### Analisis Masalah Lama (Insiden 1)
Pada arsitektur monolitik lama, aplikasi TaskFlow dijalankan secara manual di satu container server tunggal. Ketika container mengalami crash pada pukul 02.15 malam, sistem tidak memiliki kecerdasan untuk mendeteksi maupun memulihkan diri, sehingga mengakibatkan downtime fatal selama lebih dari 6 jam hingga tim operasional masuk kerja di pagi hari.

### Solusi Kubernetes: Self-Healing via ReplicaSet
Melalui objek **Deployment** yang dikonfigurasi dengan `replicas: 2` di namespace `taskflow-prod`, Kubernetes Control Plane secara konstan menjalankan siklus rekonsiliasi (*reconciliation loop*). Jika salah satu Pod terdeteksi mati atau dihapus, Kubernetes akan mendeteksi ketidaksesuaian jumlah *state* saat itu dengan manifes, lalu secara instan menjadwalkan pembuatan Pod baru untuk mempertahankan ketersediaan layanan.

### Hasil Pengujian Simulasi
<img width="772" height="108" alt="image" src="https://github.com/user-attachments/assets/27a37c5a-57e4-4cd3-a000-b47115fe5d69" />


### 1. Eksekusi Penghapusan Pod (Simulasi Container Crash)
```bash
kubectl delete pod taskflow-api-5c8ccc8c55-95rjv -n taskflow-prod
```
<img width="1026" height="137" alt="image" src="https://github.com/user-attachments/assets/6031468e-c505-4f73-9439-88b703c99507" />
<img width="797" height="307" alt="image" src="https://github.com/user-attachments/assets/f6942780-8b38-4ab5-a6bd-8d8a57250e6d" />



## Bagian 4
### Analisis Masalah Lama (Insiden 2)

Pada arsitektur lama, TaskFlow Inc. melakukan deployment secara manual menggunakan perintah Docker langsung di server produksi. Ketika versi baru perlu di-deploy, seluruh container harus dihentikan terlebih dahulu sebelum image baru dapat dijalankan.

### Solusi Kubernetes: Rolling Update Strategy
Kubernetes menyediakan mekanisme **Rolling Update** yang memungkinkan pembaruan aplikasi berjalan secara bertahap tanpa downtime. Kunci konfigurasinya adalah `maxUnavailable: 0` yang memastikan Pod lama tidak dimatikan sebelum Pod baru benar-benar siap melayani traffic.

### Konfigurasi Strategy pada `deployment-prod.yaml`

```yaml
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1        # Boleh buat 1 Pod ekstra sementara
      maxUnavailable: 0  # Jangan matikan Pod lama sebelum yang baru siap
  selector:
    matchLabels:
      app: taskflow-api
  template:
    metadata:
      labels:
        app: taskflow-api
    spec:
      containers:
        - name: taskflow-api
          image: hashicorp/http-echo:latest
          args:
            - "-text=Halo dari TaskFlow API (PROD) v2! Fitur Baru!"
            - "-listen=:8080"
          ports:
            - containerPort: 8080
```

### Alur Proses Rolling Update

```
Awal:    [Pod v1] [Pod v1] [Pod v1]
Step 1:  [Pod v1] [Pod v1] [Pod v1] [Pod v2]  <- buat Pod baru dulu
Step 2:  [Pod v1] [Pod v1] [Pod v2]           <- Pod v2 siap, matikan Pod v1
Step 3:  [Pod v1] [Pod v2] [Pod v2] [Pod v2]  <- lanjut ke Pod v1 berikutnya
Selesai: [Pod v2] [Pod v2] [Pod v2]           <- semua sudah versi baru
```

Traffic tidak pernah terhenti karena selalu ada minimal 3 Pod aktif yang melayani request selama proses update berlangsung.

### Langkah-Langkah Pengujian

#### 1. Persiapan Cluster

```powershell
# Start minikube
minikube start --cpus=2 --memory=4096 --driver=docker

# Validate YAML sebelum apply
kubectl apply -f deployment-prod.yaml --dry-run=client

# Deploy namespace, deployment, dan service
kubectl apply -f namespace-prod.yaml
kubectl apply -f deployment-prod.yaml
kubectl apply -f service-prod.yaml

# Verifikasi semua pod Running
kubectl get pods -n taskflow-prod
```

#### 2. Terminal 1 — Port-Forward

Port-forward dijalankan agar aplikasi dapat diakses melalui `localhost:8080`.

![alt text](<Screenshot/Screenshot 2026-05-28 202627.png>)

#### 3. Terminal 2 — Loop Request (Monitor Uptime)

Loop request dikirim setiap 500ms untuk memantau apakah ada downtime selama update berlangsung.

```powershell
while ($true) {
  try {
    $status = (Invoke-WebRequest -Uri "http://localhost:8080" -UseBasicParsing).StatusCode
    Write-Host "$(Get-Date -Format 'HH:mm:ss') — HTTP $status"
  } catch {
    Write-Host "$(Get-Date -Format 'HH:mm:ss') — ERROR: $_"
  }
  Start-Sleep -Milliseconds 500
}
```

#### 4. Terminal 3 — Eksekusi Rolling Update

File `deployment-prod.yaml` diedit untuk mengubah teks response dari `v1` ke `v2`, kemudian di-apply ke cluster.

```powershell
# Apply deployment versi baru
kubectl apply -f deployment-prod.yaml

# Pantau proses rollout
kubectl rollout status deployment/taskflow-api -n taskflow-prod

# Verifikasi pod setelah selesai
kubectl get pods -n taskflow-prod
```

### Hasil Pengujian

#### 1. Loop Request HTTP 200 — Selama Rolling Update (Terminal 2)

Selama proses rolling update berlangsung (20:07:14 — 20:07:29), seluruh request mendapat respons **HTTP 200** tanpa satu pun error. Ini membuktikan tidak ada downtime sama sekali.

![alt text](<Screenshot/Screenshot 2026-05-28 201020.png>)

#### 2. Proses Rollout Berhasil (Terminal 3)

Output `kubectl rollout status` menunjukkan proses update berjalan bertahap: replica lama di-terminate satu per satu setelah replica baru siap. Rollout selesai dalam **1–2 menit** dengan status `successfully rolled out`.

![alt text](<Screenshot/Screenshot 2026-05-28 201048.png>)

#### 3. Verifikasi Pod Setelah Update

Setelah rollout selesai, `kubectl get pods` menunjukkan 3 Pod baru (hash `86c88dbf65`) dengan status `Running` dan umur 2–3 menit. Pod lama sudah tergantikan sepenuhnya oleh versi baru.

![alt text](<Screenshot/Screenshot 2026-05-28 201143.png>)

---

## Bagian 5
### Laporan Pengujian Insiden 3 — Rollback Cepat

### Analisis Masalah Lama (Insiden 3)

Pada arsitektur lama, ketika versi baru TaskFlow memiliki bug kritis, rollback dilakukan secara manual. Tim harus SSH ke server production, menghentikan container bermasalah, menarik image versi lama, menjalankan ulang container, lalu memastikan konfigurasi port dan environment tetap sesuai. Proses ini memakan waktu sekitar **25 menit** dan memiliki risiko human error yang tinggi.

### Solusi Kubernetes: Rollback via Deployment Revision

Kubernetes menyimpan revision history pada Deployment. Setelah rolling update selesai, versi sebelumnya dapat dikembalikan dengan satu perintah:

```bash
kubectl rollout undo deployment/taskflow-api -n taskflow-prod
```

Pada `kubernetes/deployment-prod.yaml`, Deployment production menyimpan beberapa revisi terakhir:

```yaml
spec:
  replicas: 3
  revisionHistoryLimit: 5
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
```

Dengan konfigurasi ini, Kubernetes tetap mempertahankan ReplicaSet lama yang diperlukan untuk rollback. Karena strategy masih menggunakan `maxUnavailable: 0`, proses rollback juga dilakukan bertahap agar service tetap tersedia.

### Langkah-Langkah Pengujian

#### 1. Cek Riwayat Deployment

```bash
kubectl rollout history deployment/taskflow-api -n taskflow-prod
kubectl get pods -n taskflow-prod
```

Perintah ini memastikan Deployment sudah memiliki lebih dari satu revisi setelah proses rolling update pada Bagian 4.

#### 2. Eksekusi Rollback

```bash
START=$(date +%s)
kubectl rollout undo deployment/taskflow-api -n taskflow-prod
```

#### 3. Pantau Proses Rollback

```bash
kubectl rollout status deployment/taskflow-api -n taskflow-prod
END=$(date +%s)
echo "Durasi rollback: $((END-START)) detik"
```

#### 4. Verifikasi Setelah Rollback

```bash
kubectl get pods -n taskflow-prod
kubectl rollout history deployment/taskflow-api -n taskflow-prod
```

Jika menggunakan port-forward seperti Bagian 4:

```bash
kubectl port-forward svc/taskflow-api 8080:80 -n taskflow-prod
curl http://localhost:8080
```

### Hasil yang Diharapkan

Rollback selesai dengan status `deployment "taskflow-api" successfully rolled out`. Pod versi baru diganti oleh Pod dari revisi sebelumnya secara bertahap, sehingga aplikasi tetap dapat diakses selama proses rollback.

### Hasil Pengujian Rollback

Rollback diuji dengan membuat revisi sementara `v3! BUG KRITIS!`, lalu menjalankan `kubectl rollout undo`. Proses rollback selesai dalam **10 detik** dan Deployment kembali ke response versi stabil:

```text
-text=Halo dari TaskFlow API (PROD) v2! Fitur Baru!
```

Command yang dijalankan:

![Command Rollback Bagian 5](<Screenshot/rollback-bagian-5-warp-command.png>)

Output pengujian rollback:

![Output Rollback Bagian 5](<Screenshot/rollback-bagian-5-warp-output.png>)

Status Pod setelah rollback menunjukkan 3 Pod versi stabil sudah `Running`, sementara 1 Pod dari revisi sebelumnya sedang `Terminating`:

```text
NAME                            READY   STATUS        RESTARTS   AGE
taskflow-api-654f7d847c-bp5ll   1/1     Terminating   0          16s
taskflow-api-89c95fd7b-c29qr    1/1     Running       0          10s
taskflow-api-89c95fd7b-c2yqy    1/1     Running       0          4s
taskflow-api-89c95fd7b-hbnkn    1/1     Running       0          7s
```

| Bukti | Hasil |
| --- | --- |
| Durasi rollback | 10 detik |
| Status rollout | `deployment "taskflow-api" successfully rolled out` |
| Status Pod | 3 Pod stabil `Running`, 1 Pod lama `Terminating` |

### Tabel Perbandingan Rollback

| Aspek | Cara Lama | Dengan Kubernetes |
| --- | --- | --- |
| Langkah | SSH → stop container → pull image lama → run ulang → config ulang | Satu perintah `kubectl rollout undo` |
| Waktu | ~25 menit | < 60 detik |
| Risiko | Tinggi karena banyak langkah manual | Rendah karena dikontrol Deployment |
| Dampak layanan | Berpotensi downtime | Tetap tersedia melalui rolling rollback |

### Kesimpulan

Insiden 3 dapat dicegah karena Kubernetes menyediakan mekanisme rollback cepat berbasis revision history. Tim tidak perlu lagi melakukan pemulihan manual di server production; cukup menjalankan `kubectl rollout undo`, lalu Kubernetes mengembalikan Deployment ke revisi sebelumnya sambil menjaga jumlah Pod tetap tersedia.

Dokumentasi detail bagian ini juga tersedia di [`docs/insiden-3-rollback.md`](docs/insiden-3-rollback.md).

---

## Bagian 6
### Laporan Pengujian Isolasi Namespace (Dev vs Prod)

### Analisis Skenario
Lingkungan *development* (`dev`) dan *production* (`prod`) harus terpisah secara komprehensif. Jika terjadi insiden atau kesalahan eksekusi perintah (seperti penghapusan *resource* massal) di *environment* `dev`, hal tersebut tidak boleh berdampak sedikit pun pada ketersediaan layanan di *environment* `prod`.

### Solusi Kubernetes: Isolasi via Namespace
Kubernetes menggunakan **Namespace** untuk membagi satu klaster fisik menjadi beberapa klaster virtual. Dengan mendeploy aplikasi ke namespace `taskflow-dev` dan `taskflow-prod`, *resource* (seperti Pod, Deployment, dan Service) akan sepenuhnya terisolasi secara logis.

### Langkah-Langkah Pengujian
Kami mendemonstrasikan isolasi ini dengan cara melakukan "kekacauan" yang disengaja di namespace `dev`, lalu memantau dampaknya di `prod`.

#### 1. Eksekusi Penghapusan Total di Dev
Menghapus seluruh Pod secara paksa di lingkungan *development*:
```bash
kubectl delete pods --all -n taskflow-dev
```
#### 2. Memantau Lingkungan Prod
Pada saat yang bersamaan, kami memantau ketersediaan Pod di production secara real-time:
```bash
kubectl get pods -n taskflow-prod -w
```
### Hasil Pengujian dan Bukti
Tepat saat perintah penghapusan dieksekusi di taskflow-dev (terminal bawah), Pod di taskflow-prod (terminal atas) sama sekali tidak mengalami gangguan, restart, atau berstatus Terminating. Semua Pod production tetap stabil berstatus Running.

<img width="949" height="1150" alt="Screenshot 2026-05-29 140648" src="https://github.com/user-attachments/assets/11778662-63cb-4e1e-9b22-59020ccb0b76" />

#### 3. Verifikasi Ketersediaan Layanan
Layanan production juga dibuktikan tetap dapat diakses dengan respons HTTP 200 pasca-insiden di dev:
```bash
# Verifikasi akses aplikasi (via Port-Forward / Minikube IP)
curl http://localhost:8080
# Output: Halo dari TaskFlow API v2! Fitur Baru!
```

<img width="703" height="123" alt="Screenshot 2026-05-29 141055" src="https://github.com/user-attachments/assets/4f172747-dd60-4bcf-ab5a-0a0130bd2cf1" />

#### Kesimpulan
Fitur Namespace di Kubernetes terbukti ampuh sebagai batas isolasi. Tim developer dapat melakukan eksperimen, merusak, atau menghapus resource dengan aman di namespace taskflow-dev tanpa risiko menyebabkan downtime pada sistem taskflow-prod yang sedang diakses pengguna.

## Bagian 7

### Integrasi CI/CD Pipeline (GitLab)

### Screenshot Pipeline CI/CD GitLab
![Pipeline CI/CD sampai deploy](./Screenshot/cicd-ke-kubernetes/cicd-job-pipeline.png)

Semua job (mulai dari init sampai deploy) sudah berjalan dengan lancar.

### Hasil Image Baru

Cara menjalankan image terbaru di GitHub:
1. Pull repository dengan command `git pull origin main`.
2. Apply pod baru dengan image yang baru dengan menjalankan `./deploy.sh`.
3. Cek pod yang menggunakan image baru dengan command `kubectl get pods -n taskflow-prod`.
4. Cek image yang digunakan oleh pod menggunakan command berikut.

    ```
    kubectl get deployment taskflow-api -n taskflow-prod -o jsonpath='{.spec.template.spec.containers[0].image}'
    ```

#### Hasil:

![Hasil Run Pod dan Image yang Digunakan Pod](./Screenshot/cicd-ke-kubernetes/get-pods.png)

### Diagram Alur

![Flowchart CI/CD sampai Kubernetes](./Screenshot/cicd-ke-kubernetes/flowchart-cicd.png)

Alur CI/CD sampai Kubernetes adalah sebagai berikut.
1. Developer push code ke GitLab.
2. GitLab menjalankan proses (job) mulai dari `init` sampai `deploy`.
3. GitLab push image tag baru ke GitHub.
4. Developer pull repository GitHub dengan image tag terbaru dan menjalankan proses deployment dengan menjalankan `deploy.sh`.
5. Kubernetes membaca `deployment.yaml`, kemudian pull image baru dari GitLab registry dan membuat serta menjalankan pod baru dengan image terbaru.

### Hasil Kubernetes Sebelum & Sesudah Pull Image Baru

Sebelum:

![Health Endpoint Sebelum Pull Image Baru](./Screenshot/bagian-7-health-before.png)

Sesudah:

![Health Endpoint Setelah Pull Image Baru](./Screenshot/bagian-7-health-after.png)

# Week 16 — DevSecOps Enhancement Scaffold



```
week16-enhancement/
│
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

