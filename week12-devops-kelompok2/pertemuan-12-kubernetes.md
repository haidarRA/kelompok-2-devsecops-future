# Week 12 — Kubernetes & Microservices

**Mata Kuliah**: Operasional Pengembang (DevOps)
**Mode Belajar**: Mandiri (asinkronus)
**Durasi**: 2 minggu

## Sebelum Mulai

Modul ini adalah lanjutan dari apa yang sudah kamu pelajari:

- **Modul 6** → kamu bisa buat Docker image
- **Modul 9** → kamu bisa push image itu ke registry via CI/CD
- **Modul ini** → kamu akan belajar cara *menjalankan* image itu di Kubernetes

Bayangkan begini: Docker itu seperti kamu punya satu mobil. Kubernetes itu seperti perusahaan transportasi yang mengelola ribuan mobil — tahu mana yang mogok, mana yang perlu ditambah, dan memastikan penumpang selalu bisa naik.

### Tools yang Perlu Dipasang

**Minikube** — Kubernetes mini yang bisa jalan di laptopmu sendiri.

```bash
# Install di Mac
brew install minikube

# Install di Linux
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Cek instalasi
minikube version
kubectl version --client
```

Setelah terpasang, jalankan cluster:

```bash
minikube start --cpus=2 --memory=4096

# Kalau berhasil, kamu akan lihat:
# ✅  Done! kubectl is now configured to use "minikube" cluster
```

---

## Bagian 1 — Kenapa Kubernetes Ada?

### Cerita yang Familiar

Kamu sudah bisa jalankan aplikasi dengan `docker run`. Lalu apa masalahnya?

Bayangkan aplikasi TaskFlow sudah punya ribuan pengguna. Kamu jalankan di satu server dengan satu container. Suatu malam, container itu crash karena kehabisan memory. Tidak ada yang tahu. Pengguna dapat error selama 6 jam sampai kamu masuk kerja pagi dan menemukannya.

Atau, tiba-tiba ada kampanye marketing dan traffic naik 10× dalam 30 menit. Kamu harus buru-buru SSH ke server, jalankan beberapa `docker run`, update nginx. Semua manual, semua panik.

Atau saat deploy versi baru, aplikasi harus mati dulu beberapa menit. Pengguna kamu tahu dan tidak senang.

Kubernetes hadir untuk menyelesaikan masalah-masalah ini. Secara singkat, Kubernetes bisa:

- **Otomatis restart** container yang crash, tanpa perlu intervensi manusia
- **Scale up/down** jumlah container dengan satu perintah, atau bahkan otomatis
- **Update aplikasi** tanpa ada downtime sama sekali
- **Rollback** ke versi sebelumnya dalam hitungan detik jika ada masalah

### Bagaimana Cara Kerjanya?

Kubernetes mengelola sekumpulan server yang disebut **cluster**. Cluster terdiri dari dua jenis mesin:

**Control Plane** adalah "otak". Di sinilah semua keputusan dibuat. Kamu tidak perlu tahu detailnya untuk mulai, yang penting tahu bahwa setiap perintah `kubectl` yang kamu ketik dikirim ke Control Plane, dan Control Plane yang mengatur seterusnya.

**Worker Node** adalah server-server yang benar-benar menjalankan aplikasimu. Setiap Worker Node diawasi oleh Control Plane.

Untuk belajar, kita pakai **Minikube** — sebuah cluster kecil yang menggabungkan semuanya dalam satu mesin virtual di laptopmu.

---

## Bagian 2 — Objek-Objek Dasar Kubernetes

Kubernetes menggunakan konsep "objek" untuk merepresentasikan segala sesuatu. Kamu mendefinisikan objek lewat file YAML, lalu Kubernetes berusaha membuat keadaan cluster sesuai dengan yang kamu definisikan.

Ada empat objek yang paling sering dipakai dan wajib kamu kuasai dulu.

### Pod — Tempat Container Berjalan

Pod adalah wadah untuk container. Satu Pod biasanya berisi satu container (meskipun bisa lebih). Setiap Pod punya IP sendiri di dalam cluster.

Yang penting dipahami: **Pod itu fana**. Pod bisa mati kapan saja karena berbagai alasan. Ketika Pod mati dan dibuat ulang, IP-nya berubah. Itulah kenapa kita tidak boleh mengandalkan IP Pod secara langsung.

Dalam praktik, kamu hampir tidak pernah membuat Pod langsung. Kamu membuat Deployment yang kemudian membuat Pod secara otomatis.

### Deployment — Cara yang Benar Menjalankan Aplikasi

Deployment adalah objek yang bertugas menjaga agar selalu ada sejumlah Pod yang berjalan. Kalau ada Pod yang mati, Deployment langsung membuat Pod baru untuk menggantikannya.

Deployment juga yang mengurus rolling update dan rollback.

Berikut contoh file Deployment paling sederhana:

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: taskflow-api          # Nama Deployment
  namespace: default          # Namespace (seperti folder)
spec:
  replicas: 2                 # Selalu jaga agar ada 2 Pod

  selector:
    matchLabels:
      app: taskflow-api       # Kelola Pod yang punya label ini

  template:                   # Cetakan untuk membuat Pod
    metadata:
      labels:
        app: taskflow-api     # Label yang ditempel di setiap Pod
    spec:
      containers:
        - name: taskflow-api
          image: hashicorp/http-echo:latest
          args:
            - "-text=Halo dari TaskFlow!"
            - "-listen=:8080"
          ports:
            - containerPort: 8080
```

Perhatikan bagian `selector` dan `labels` — keduanya harus sama (`app: taskflow-api`). Ini yang menghubungkan Deployment dengan Pod-podnya.

### Service — Pintu Masuk yang Stabil

Karena IP Pod berubah-ubah, kita butuh sesuatu yang stabil. Service menyediakan satu "alamat" tetap yang selalu mengarah ke Pod-pod yang sehat, sekaligus membagi traffic di antara mereka (load balancing).

Ada tiga jenis Service:

- **ClusterIP**: hanya bisa diakses dari dalam cluster. Dipakai untuk komunikasi antar-service.
- **NodePort**: bisa diakses dari luar cluster melalui port tertentu. Cocok untuk development.
- **LoadBalancer**: untuk production di cloud (GKE, EKS, dll.).

```yaml
# service.yaml
apiVersion: v1
kind: Service
metadata:
  name: taskflow-api
  namespace: default
spec:
  type: NodePort
  selector:
    app: taskflow-api         # Arahkan ke Pod berlabel ini
  ports:
    - port: 80                # Port Service
      targetPort: 8080        # Port di dalam container
      nodePort: 30080         # Port yang diakses dari luar
```

Keuntungan lain Service: setiap Service otomatis punya nama DNS di dalam cluster. Artinya, service lain bisa memanggil `http://taskflow-api:80` tanpa perlu tahu IP-nya. Ini sangat berguna untuk microservices.

### Namespace — Cara Memisahkan Lingkungan

Namespace adalah cara membagi satu cluster menjadi beberapa "ruang" yang terisolasi. Bayangkan seperti folder di komputer — resource di namespace berbeda tidak saling mengganggu.

Paling umum digunakan untuk memisahkan environment:

```bash
kubectl create namespace taskflow-dev
kubectl create namespace taskflow-prod
```

Setelah itu, kamu bisa deploy ke namespace tertentu:

```bash
kubectl apply -f deployment.yaml -n taskflow-prod
kubectl get pods -n taskflow-prod
```

---

## Bagian 3 — kubectl, Alat Utamamu

`kubectl` adalah perintah untuk berkomunikasi dengan cluster Kubernetes. Berikut perintah-perintah yang paling sering kamu pakai:

```bash
# Lihat semua Pod
kubectl get pods

# Lihat Pod di namespace tertentu
kubectl get pods -n taskflow-prod

# Lihat Pod + info tambahan (node, IP)
kubectl get pods -o wide

# Lihat semua resource sekaligus
kubectl get all

# Detail sebuah Pod (sangat berguna untuk debug!)
kubectl describe pod <nama-pod>

# Buat atau update resource dari file
kubectl apply -f deployment.yaml

# Hapus resource
kubectl delete -f deployment.yaml
kubectl delete pod <nama-pod>

# Lihat log output container
kubectl logs <nama-pod>
kubectl logs <nama-pod> -f          # terus mengalir, seperti tail -f

# Masuk ke dalam container
kubectl exec -it <nama-pod> -- sh

# Scale jumlah Pod
kubectl scale deployment taskflow-api --replicas=4

# Lihat status update/rollout
kubectl rollout status deployment/taskflow-api
kubectl rollout history deployment/taskflow-api

# Rollback ke versi sebelumnya
kubectl rollout undo deployment/taskflow-api
```

> **Tips debug**: Kalau Pod tidak mau jalan, langkah pertama selalu `kubectl describe pod <nama-pod>` dan cari bagian **Events** di paling bawah output. Di situlah biasanya ada pesan error yang menjelaskan apa yang salah.

---

## Bagian 4 — Rolling Update & Rollback

### Update Tanpa Downtime

Salah satu fitur paling berguna Kubernetes adalah kemampuan memperbarui aplikasi tanpa pengguna merasakan gangguan.

Caranya: tambahkan `strategy` di Deployment:

```yaml
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1        # Boleh buat 1 Pod ekstra sementara
      maxUnavailable: 0  # Jangan matikan Pod lama sebelum yang baru siap
```

Dengan konfigurasi ini, proses update berjalan seperti ini:

```
Awal:   [Pod v1] [Pod v1]
Step 1: [Pod v1] [Pod v1] [Pod v2]  ← buat Pod baru dulu
Step 2: [Pod v1] [Pod v2]           ← matikan 1 Pod lama
Step 3: [Pod v2] [Pod v2] [Pod v2]  → tunggu v2 siap
Step 4: [Pod v2] [Pod v2]           ← matikan Pod lama terakhir
Selesai!
```

Traffic tidak pernah terhenti karena selalu ada Pod yang melayani.

Untuk memulai update, cukup ganti tag image lalu apply ulang:

```bash
# Edit deployment.yaml: ubah image ke versi baru
# Lalu:
kubectl apply -f deployment.yaml

# Pantau prosesnya
kubectl rollout status deployment/taskflow-api
```

### Rollback Jika Ada Masalah

Kubernetes menyimpan riwayat setiap update. Kalau versi baru ternyata bermasalah:

```bash
# Lihat riwayat
kubectl rollout history deployment/taskflow-api

# Kembali ke versi sebelumnya (hanya 1 perintah!)
kubectl rollout undo deployment/taskflow-api
```

Proses rollback biasanya selesai dalam 30–60 detik. Jauh lebih cepat dari cara manual.

---

## Bagian 5 — Pengantar Microservices

### Apa itu Microservices?

Selama ini aplikasi TaskFlow mungkin ditulis sebagai satu program besar yang mengurus semua hal: login pengguna, manajemen task, notifikasi email, laporan statistik. Ini disebut **monolith**.

Microservices adalah pendekatan di mana kita memecah aplikasi besar itu menjadi beberapa layanan kecil yang masing-masing berdiri sendiri. Misalnya:

- `auth-service` — khusus menangani login dan verifikasi
- `task-service` — khusus menangani CRUD task
- `notif-service` — khusus mengirim notifikasi email
- `report-service` — khusus menghasilkan laporan

Setiap service punya Deployment dan Service Kubernetes sendiri, bisa di-update sendiri, dan bisa di-scale sendiri.

### Keuntungan Utama

**Tidak saling mempengaruhi saat ada masalah.** Kalau `report-service` crash atau perlu di-restart, `auth-service` dan `task-service` tetap berjalan normal. Pengguna masih bisa login dan membuat task — hanya fitur laporan yang terganggu sementara.

**Scale sesuai kebutuhan.** Kalau hanya `task-service` yang ramai, kamu hanya perlu tambah replika `task-service`, bukan semua service.

**Tim bisa kerja lebih mandiri.** Tim yang mengerjakan `report-service` bisa deploy kapan saja tanpa koordinasi dengan tim `auth-service`.

### Microservices dan Kubernetes Cocok Sekali

Kubernetes menyediakan semua yang dibutuhkan microservices:

| Kebutuhan                | Solusi Kubernetes                |
| ------------------------ | -------------------------------- |
| Jalankan banyak service  | Banyak Deployment                |
| Service saling menemukan | DNS otomatis lewat Service       |
| Scale service tertentu   | `kubectl scale` per Deployment |
| Update satu service saja | Rolling update per Deployment    |
| Pisahkan environment     | Namespace                        |

---

## Bagian 6 — Lab Mandiri

Kerjakan tiga lab ini secara berurutan. Setiap lab butuh sekitar 30–45 menit.

### Lab 1 — Deploy Aplikasi Pertama

**Tujuan**: jalankan aplikasi di Kubernetes dan pahami cara Kubernetes menjaga Pod tetap berjalan.

**Langkah 1 — Buat namespace**

```bash
kubectl create namespace taskflow-dev
kubectl config set-context --current --namespace=taskflow-dev
```

Perintah kedua membuat `taskflow-dev` jadi namespace default sementara, jadi kamu tidak perlu terus menulis `-n taskflow-dev`.

**Langkah 2 — Buat file Deployment**

Buat file `deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: taskflow-api
  namespace: taskflow-dev
spec:
  replicas: 2
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
            - "-text=Halo dari TaskFlow v1!"
            - "-listen=:8080"
          ports:
            - containerPort: 8080
```

Apply ke cluster:

```bash
kubectl apply -f deployment.yaml
```

**Langkah 3 — Amati apa yang terjadi**

```bash
# Lihat Deployment
kubectl get deployment taskflow-api

# Lihat Pod yang dibuat
kubectl get pods

# Detail salah satu Pod (ganti nama Pod dengan yang muncul di get pods)
kubectl describe pod <nama-pod>
```

**Langkah 4 — Coba self-healing**

Buka dua terminal berdampingan.

Terminal 1 (pantau Pod secara real-time):

```bash
kubectl get pods -w
```

Terminal 2 (hapus salah satu Pod):

```bash
kubectl delete pod <nama-pod-pertama>
```

Amati di Terminal 1 — Pod baru akan dibuat secara otomatis dalam beberapa detik!

---

### Lab 2 — Buat Service dan Akses Aplikasi

**Tujuan**: buat Service agar aplikasi bisa diakses dari luar cluster.

**Langkah 1 — Buat file Service**

Buat file `service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: taskflow-api
  namespace: taskflow-dev
spec:
  type: NodePort
  selector:
    app: taskflow-api
  ports:
    - port: 80
      targetPort: 8080
      nodePort: 30080
```

```bash
kubectl apply -f service.yaml
kubectl get service taskflow-api
```

**Langkah 2 — Akses aplikasi**

```bash
# Dapatkan URL akses
minikube service taskflow-api -n taskflow-dev --url

# Akses pakai curl (gunakan URL dari perintah di atas)
curl http://$(minikube ip):30080
# Harusnya muncul: Halo dari TaskFlow v1!
```

**Langkah 3 — Lihat load balancing**

Karena ada 2 Pod, traffic dibagi rata. Kirim beberapa request:

```bash
for i in {1..6}; do
  curl -s http://$(minikube ip):30080
  echo ""
done
```

---

### Lab 3 — Rolling Update dan Rollback

**Tujuan**: update aplikasi tanpa downtime, lalu rollback.

**Langkah 1 — Update Deployment dengan strategy rolling update**

Edit `deployment.yaml`, tambahkan bagian `strategy` dan ubah teks response:

```yaml
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
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
            - "-text=Halo dari TaskFlow v2! Fitur baru!"  # ← ubah ini
            - "-listen=:8080"
          ports:
            - containerPort: 8080
```

**Langkah 2 — Update sambil pantau**

Buka dua terminal.

Terminal 1 (kirim request terus-menerus):

```bash
while true; do
  curl -s http://$(minikube ip):30080
  sleep 0.5
  echo ""
done
```

Terminal 2 (lakukan update):

```bash
kubectl apply -f deployment.yaml
kubectl rollout status deployment/taskflow-api
```

Amati Terminal 1 — lama-lama responsnya berubah dari "v1" ke "v2", tapi tidak ada error di antaranya!

**Langkah 3 — Rollback**

```bash
# Lihat riwayat
kubectl rollout history deployment/taskflow-api

# Rollback ke versi sebelumnya
kubectl rollout undo deployment/taskflow-api

# Verifikasi
curl http://$(minikube ip):30080
# Harusnya kembali ke "Halo dari TaskFlow v1!"
```

**Langkah 4 — Bersihkan**

```bash
kubectl delete namespace taskflow-dev
kubectl config set-context --current --namespace=default
```

---

## Bagian 7 — Tugas Kelompok 

**Sifat**: Kelompok (seperti minggu sebelumnya)
**Deadline**: Pertemuan Selanjutnya (estimasi 2 minggu)
**Pengumpulan**: Link repository GitHub 

### Konteks

TaskFlow Inc. masih menjalankan semua container secara manual di satu server. CTO menceritakan tiga insiden yang terjadi bulan lalu:

> **Insiden 1** — Container crash jam 02.15 malam. Tidak ada yang tahu sampai klien komplain jam 08.30 pagi. Downtime 6 jam lebih.

> **Insiden 2** — Saat deploy fitur baru, aplikasi mati 8 menit. Terjadi pas jam sibuk. Klien tidak senang.

> **Insiden 3** — Versi baru punya bug kritis. Rollback manual memakan 25 menit: SSH ke server, stop container, pull image lama, jalankan ulang.

Tugas kelompok kalian: **pindahkan TaskFlow ke Kubernetes dan buktikan bahwa ketiga insiden itu tidak akan terjadi lagi**.

---


**Tugas 1 — Siapkan Namespace**

Buat dua namespace untuk memisahkan environment:

```bash
kubectl create namespace taskflow-dev
kubectl create namespace taskflow-prod
```

Simpan juga sebagai file YAML agar bisa dibuat ulang dari Git:

```yaml
# namespace-dev.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: taskflow-dev
```

**Tugas 2 — Deploy ke Production**

Buat `deployment.yaml` dengan ketentuan:

- `replicas: 2` di namespace `prod`
- Rolling update strategy dengan `maxUnavailable: 0`
- Gunakan image dari hasil CI/CD pipeline modul 9, atau gunakan `hashicorp/http-echo` sebagai placeholder

Buat `service.yaml` dengan tipe NodePort.

Deploy ke namespace prod:

```bash
kubectl apply -f deployment.yaml -n taskflow-prod
kubectl apply -f service.yaml -n taskflow-prod

# Verifikasi semua berjalan
kubectl get all -n taskflow-prod
```

**Tugas 3 — Jawaban untuk Insiden 1 (Self-Healing)**

Demonstrasikan self-healing. Lakukan dan dokumentasikan langkah berikut:

1. Buka dua terminal
2. Terminal 1: `kubectl get pods -n taskflow-prod -w`
3. Terminal 2: hapus salah satu Pod
4. Ukur waktu dari Pod dihapus hingga Pod baru `Running`

Simpan screenshot dan catat waktunya. Insiden 1 tidak akan terjadi lagi karena Kubernetes langsung membuat Pod baru tanpa menunggu ada orang yang datang ke kantor.

---

### Minggu Kedua — Operasional

**Tugas 4 — Jawaban untuk Insiden 2 (Rolling Update Tanpa Downtime)**

Demonstrasikan update tanpa downtime:

1. Terminal 1 — jalankan loop request:

```bash
while true; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://$(minikube ip):30080)
  echo "$(date +%H:%M:%S) — HTTP $STATUS"
  sleep 0.5
done
```

2. Terminal 2 — lakukan update (ganti teks atau tag image di deployment.yaml):

```bash
kubectl apply -f deployment.yaml -n taskflow-prod
```

3. Pastikan di Terminal 1 **tidak ada baris selain `HTTP 200`** selama proses update berlangsung

Simpan screenshot Terminal 1 yang membuktikan tidak ada error.

**Tugas 5 — Jawaban untuk Insiden 3 (Rollback Cepat)**

Setelah update di Tugas 4 selesai:

1. Jalankan rollback: `kubectl rollout undo deployment/taskflow-api -n taskflow-prod`
2. Catat berapa lama prosesnya selesai
3. Buat tabel perbandingan singkat:

|         | Cara Lama                                  | Dengan Kubernetes |
| ------- | ------------------------------------------ | ----------------- |
| Langkah | SSH → stop → pull → run → config ulang | Satu perintah     |
| Waktu   | ~25 menit                                  | < 60 detik        |
| Risiko  | Tinggi (banyak langkah manual)             | Rendah            |

**Tugas 6 — Isolasi Namespace**

Demonstrasikan bahwa namespace `dev` dan `prod` benar-benar terpisah:

```bash
# Lakukan "kekacauan" di dev
kubectl delete pods --all -n taskflow-dev

# Tunjukkan prod tidak terpengaruh
kubectl get pods -n taskflow-prod   # Semua masih Running
curl http://$(minikube ip):30080    # Masih bisa diakses
```

---

**Tugas 7 — Integrasi CI/CD Pipeline (Lanjutan Modul 9)**

Ini adalah inti dari modul ini: menghubungkan pipeline CI/CD yang sudah dibuat di Modul 9 dengan cluster Kubernetes, sehingga setiap kali ada push ke branch `main`, aplikasi di Kubernetes otomatis ter-update dengan image baru — tanpa ada yang harus menjalankan `kubectl` secara manual.

Alur yang akan dibangun:

```
Developer push kode
        │
        ▼
GitHub Actions (pipeline Modul 9)
  ├─ go vet + unit test
  ├─ build Docker image
  ├─ push ke GHCR: ghcr.io/<user>/taskflow-api:sha-<commit>
  │
  └─ [BARU] Deploy ke Kubernetes  ← yang kita tambahkan di sini
              │
              ▼
        kubectl set image ...
              │
              ▼
        Rolling update otomatis
        tanpa downtime ✅
```

**Langkah 7.1 — Siapkan kubeconfig sebagai GitHub Secret**

Agar GitHub Actions bisa mengirim perintah `kubectl` ke cluster, Actions perlu memiliki kredensial cluster. Untuk Minikube, caranya:

```bash
# Export kubeconfig Minikube ke format base64
cat ~/.kube/config | base64
```

Salin output tersebut, lalu simpan di GitHub:

- Buka repository GitHub kelompok
- Pilih **Settings → Secrets and variables → Actions → New repository secret**
- Nama: `KUBECONFIG_BASE64`
- Nilai: hasil base64 di atas

> **Catatan**: Di production nyata, kita tidak menggunakan kubeconfig personal. Melainkan membuat ServiceAccount khusus dengan hak terbatas hanya untuk deploy. Untuk keperluan lab ini, cara di atas sudah cukup.

**Langkah 7.2 — Tambahkan Job Deploy ke Workflow**

Buka file workflow CI/CD dari Modul 9 (biasanya `.github/workflows/ci.yml`). Tambahkan job baru `deploy` di bawah job `build` yang sudah ada:

```yaml
# Tambahkan di akhir file .github/workflows/ci.yml

  deploy:
    name: Deploy ke Kubernetes
    runs-on: ubuntu-latest
    needs: build        # Hanya jalan setelah job build berhasil
    if: github.ref == 'refs/heads/main'  # Hanya untuk push ke main

    steps:
      - name: Checkout kode
        uses: actions/checkout@v4

      - name: Setup kubectl
        uses: azure/setup-kubectl@v3
        with:
          version: 'latest'

      - name: Konfigurasi kubeconfig
        run: |
          mkdir -p ~/.kube
          echo "${{ secrets.KUBECONFIG_BASE64 }}" | base64 -d > ~/.kube/config
          chmod 600 ~/.kube/config

      - name: Update image di Deployment
        run: |
          IMAGE="ghcr.io/${{ github.repository_owner }}/taskflow-api:sha-${GITHUB_SHA::7}"
          echo "→ Deploy image: $IMAGE"

          kubectl set image deployment/taskflow-api \
            taskflow-api=$IMAGE \
            -n taskflow-prod

      - name: Tunggu rollout selesai
        run: |
          kubectl rollout status deployment/taskflow-api \
            -n taskflow-prod \
            --timeout=120s

      - name: Verifikasi deployment
        run: |
          echo "→ Status Pod setelah deploy:"
          kubectl get pods -n taskflow-prod
          echo "→ Image yang berjalan:"
          kubectl get deployment taskflow-api -n taskflow-prod \
            -o jsonpath='{.spec.template.spec.containers[0].image}'
          echo ""
          echo "✅ Deploy berhasil!"
```

**Langkah 7.3 — Pastikan Image Bisa Di-pull**

GHCR (GitHub Container Registry) defaultnya privat. Agar Kubernetes bisa pull image dari GHCR, ada dua opsi:

**Opsi A — Jadikan image publik** (lebih mudah untuk lab):

- Buka `github.com/<username>` → **Packages** → pilih package `taskflow-api`
- **Package settings → Change visibility → Public**

**Opsi B — Buat imagePullSecret** (lebih aman, mendekati production):

```bash
# Buat Personal Access Token di GitHub dengan scope: read:packages
# Lalu buat Secret di Kubernetes:

kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=<username-github> \
  --docker-password=<personal-access-token> \
  -n taskflow-prod
```

Tambahkan referensi secret ke Deployment:

```yaml
spec:
  template:
    spec:
      imagePullSecrets:
        - name: ghcr-secret    # ← tambahkan ini
      containers:
        - name: taskflow-api
          image: ghcr.io/<username>/taskflow-api:sha-abc123
```

**Langkah 7.4 — Coba End-to-End**

Setelah semua konfigurasi selesai, lakukan pengujian penuh:

1. Buat perubahan kecil di kode (misal: ubah pesan di endpoint `/health`)
2. Commit dan push ke branch `main`:
   ```bash
   git add .
   git commit -m "feat: update pesan health endpoint"
   git push origin main
   ```
3. Buka tab **Actions** di GitHub — pantau pipeline berjalan
4. Setelah job `deploy` selesai (centang hijau), verifikasi di cluster:
   ```bash
   kubectl get pods -n taskflow-prod
   # Kamu akan lihat Pod lama Terminating dan Pod baru Creating

   kubectl get deployment taskflow-api -n taskflow-prod \
     -o jsonpath='{.spec.template.spec.containers[0].image}'
   # Harus menampilkan tag image dengan SHA commit terbaru
   ```

**Langkah 7.5 — Dokumentasikan Alur Lengkap**

Buat file `docs/cicd-ke-kubernetes.md` yang berisi:

1. Screenshot pipeline GitHub Actions yang berhasil (semua job hijau)
2. Screenshot `kubectl get pods` yang menunjukkan image baru berjalan
3. Diagram alur sederhana: *push kode → CI/CD → Kubernetes*
4. Jawab pertanyaan ini secara singkat:
   - Apa yang terjadi di Kubernetes jika job `build` di pipeline **gagal**? Apakah deployment tetap berjalan?
   - Mengapa kita pakai `needs: build` di job `deploy`?
   - Apa bedanya pendekatan ini dengan cara deploy manual yang lama?

---

### Struktur Repository yang Dikumpulkan

```
nama-repo-kelompok/
├── README.md                        ← Cara menjalankan dari awal
├── .github/
│   └── workflows/
│       └── ci.yml                   ← Pipeline Modul 9 + job deploy baru
├── kubernetes/
│   ├── namespace-dev.yaml
│   ├── namespace-prod.yaml
│   ├── deployment.yaml
│   └── service.yaml
├── deploy.sh                        ← Script setup satu kali
└── docs/
    ├── insiden-1-selfhealing.md         ← Screenshot + waktu recovery
    ├── insiden-2-rolling-update.md      ← Screenshot loop request tanpa error
    ├── insiden-3-rollback.md            ← Tabel perbandingan + screenshot
    └── cicd-ke-kubernetes.md            ← Screenshot pipeline + diagram alur
```

Isi `deploy.sh`:

```bash
#!/bin/bash
set -e

echo "→ Membuat namespace..."
kubectl apply -f kubernetes/namespace-dev.yaml
kubectl apply -f kubernetes/namespace-prod.yaml

echo "→ Deploy ke production..."
kubectl apply -f kubernetes/deployment.yaml -n taskflow-prod
kubectl apply -f kubernetes/service.yaml -n taskflow-prod

echo "→ Menunggu deployment selesai..."
kubectl rollout status deployment/taskflow-api -n taskflow-prod

echo "✅ Selesai! Akses di: http://$(minikube ip):30080"
```

---

### Penilaian

| #               | Yang Dinilai                                                   | Bobot         |
| --------------- | -------------------------------------------------------------- | ------------- |
| 1               | Deployment & Service berjalan di namespace `prod`            | 15%           |
| 2               | Self-healing terdokumentasi (Insiden 1)                        | 15%           |
| 3               | Rolling update tanpa error (Insiden 2)                         | 15%           |
| 4               | Rollback dengan tabel perbandingan (Insiden 3)                 | 15%           |
| 5               | Isolasi namespace dev vs prod                                  | 10%           |
| 6               | **Integrasi CI/CD → Kubernetes** (pipeline auto-deploy) | **25%** |
| 7               | README jelas, deploy.sh berfungsi                              | 5%            |
| **Bonus** | 2 service saling berkomunikasi via DNS internal                | +10%          |

### Format Pengumpulan

Yang dikumpulkan ke LMS:

1. **Link repository GitHub** — harus *public*, berisi file `.github/workflows/ci.yml` yang sudah dimodifikasi
2. **Link video demo** (YouTube unlisted atau Google Drive), maks 10 menit, yang menampilkan:
   - `kubectl get all -n taskflow-prod` — semua Running
   - Demo self-healing (delete pod → pod baru muncul otomatis)
   - Demo rolling update (loop request tetap 200 selama update)
   - Demo rollback
   - **Demo push kode → pipeline jalan → Kubernetes ter-update otomatis** (rekam layar dari push hingga `kubectl get pods` menunjukkan image baru)

---

## Referensi

Bagi yang ingin belajar lebih jauh (tidak wajib):

- [Kubernetes Basics — tutorial interaktif resmi](https://kubernetes.io/docs/tutorials/kubernetes-basics/)
- [kubectl cheat sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Minikube handbook](https://minikube.sigs.k8s.io/docs/)
- [Pengantar microservices (microservices.io)](https://microservices.io/patterns/)

---

*Selamat belajar! Kalau ada yang bingung, tanyakan di forum diskusi kelas atau grup komunikasi tim.*
