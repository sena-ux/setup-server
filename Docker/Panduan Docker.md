# Panduan Ultimate Docker: Dari Nol hingga Production-Ready & Securing Containers

> **Ditulis oleh:** Senior DevOps Architect & Core Security Engineer  
> **Level:** Beginner → Production-Ready  
> **Stack:** Docker Engine, Docker Compose, Linux (Ubuntu/Debian)

---

## Daftar Isi

- [BAB 1: Arsitektur & Cara Kerja Docker](#bab-1-arsitektur--cara-kerja-docker)
- [BAB 2: Panduan Instalasi & Setup Awal (Production Standards)](#bab-2-panduan-instalasi--setup-awal-production-standards)
- [BAB 3: Bedah Anatomi Komponen Docker](#bab-3-bedah-anatomi-komponen-docker)
- [BAB 4: Mastery Docker Compose (Multi-Container Management)](#bab-4-mastery-docker-compose-multi-container-management)
- [BAB 5: Panduan Keamanan Docker Tingkat Lanjut (Docker Hardening)](#bab-5-panduan-keamanan-docker-tingkat-lanjut-docker-hardening)
- [BAB 6: Management & Maintenance (Tips DevOps)](#bab-6-management--maintenance-tips-devops)

---

## BAB 1: Arsitektur & Cara Kerja Docker

### 1.1 Apa Itu Docker? (Analogi Kontainer Pelayaran)

Bayangkan sebuah **pelabuhan ekspor-impor internasional** di era sebelum kontainer standar. Setiap barang dikirim dalam berbagai ukuran, bentuk, dan kemasan — karung goni, peti kayu, drum logam. Crane khusus dibutuhkan untuk setiap jenis barang. Kapal dari Amerika tidak bisa langsung bongkar muat di pelabuhan Jepang karena mekanismenya berbeda. Hasilnya? Kacau, lambat, dan mahal.

Lalu lahirlah **kontainer pengiriman (shipping container)** standar ISO. Setiap barang dimasukkan ke dalam kotak baja berukuran standar yang sama. Crane yang sama bisa mengangkat semua kontainer. Kapal yang sama bisa membawa ribuan kontainer dari pabrik mana pun. Truk yang sama bisa mengangkutnya ke gudang mana pun. Barang di dalamnya tidak peduli apakah mereka sedang di Rotterdam, Shanghai, atau Jakarta — kontainernya selalu bisa diproses.

**Docker adalah "kontainer pengiriman" untuk software.**

Sebuah aplikasi beserta semua dependensinya (runtime, library, konfigurasi, file sistem) dikemas ke dalam satu unit standar yang disebut **container**. Container ini bisa berjalan identik di laptop developer, server staging, maupun cloud production. Tidak ada lagi masalah *"works on my machine!"*

---

### 1.2 Arsitektur Docker: Bedah Komponen Intinya

Arsitektur Docker menggunakan model **client-server**. Berikut adalah seluruh komponen yang membentuk ekosistem Docker:

```
┌─────────────────────────────────────────────────────────┐
│                     Docker Host                          │
│                                                         │
│  ┌──────────────────────────────────────────────────┐   │
│  │              Docker Daemon (dockerd)              │   │
│  │                                                  │   │
│  │  ┌──────────┐  ┌──────────┐  ┌───────────────┐  │   │
│  │  │  Images  │  │Containers│  │    Volumes    │  │   │
│  │  └──────────┘  └──────────┘  └───────────────┘  │   │
│  │  ┌──────────────────────────────────────────┐    │   │
│  │  │              Networks                    │    │   │
│  │  └──────────────────────────────────────────┘    │   │
│  └──────────────────────────────────────────────────┘   │
│                        ▲                                │
│                        │ REST API / Unix Socket          │
│                        ▼                                │
│  ┌──────────────────────────────────────────────────┐   │
│  │           Docker Client (docker CLI)              │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
              ▲
              │ Push / Pull
              ▼
┌─────────────────────────────────────────────────────────┐
│              Docker Registry (Docker Hub / GHCR / ECR)  │
└─────────────────────────────────────────────────────────┘
```

#### **Docker Daemon (`dockerd`)**
Ini adalah "otak" dari Docker — sebuah background service yang berjalan di host OS. Tugasnya adalah membangun image, menjalankan container, mengelola jaringan dan volume. Daemon berkomunikasi dengan Docker Client melalui REST API yang ter-ekspos via **Unix socket** (`/var/run/docker.sock`) atau TCP port (untuk remote management).

#### **Docker Client (`docker` CLI)**
Ini adalah antarmuka baris perintah yang kita gunakan sehari-hari. Saat kita mengetik `docker run nginx`, client menerjemahkan perintah itu menjadi API call ke Docker Daemon. Client bisa terhubung ke daemon lokal maupun remote.

#### **Docker Registry**
Gudang penyimpanan **Docker Images**. Analoginya seperti GitHub, tapi untuk image container. Yang paling terkenal adalah **Docker Hub** (hub.docker.com). Perusahaan umumnya juga menjalankan **private registry** seperti:
- **GitHub Container Registry (GHCR)**
- **Amazon ECR (Elastic Container Registry)**
- **Google Artifact Registry**
- **Self-hosted Harbor**

#### **Docker Image**
Blueprint atau "cetakan" yang digunakan untuk membuat container. Image bersifat **immutable (tidak bisa diubah)** dan terdiri dari beberapa **layer** yang ditumpuk satu sama lain. Analoginya seperti resep masakan lengkap beserta semua bahan-bahannya yang sudah disiapkan — tinggal dieksekusi.

#### **Docker Container**
Sebuah **instance yang sedang berjalan** dari sebuah image. Jika image adalah resep, container adalah masakan yang sudah jadi dan sedang disajikan di meja. Anda bisa membuat banyak container dari satu image yang sama. Container berjalan dalam **isolasi** dari host dan container lainnya.

#### **Docker Volume**
Mekanisme untuk **persistensi data** yang dihasilkan atau digunakan oleh container. Data di dalam container bersifat ephemeral (hilang saat container dihapus). Volume memisahkan data dari lifecycle container. Bayangkan ini seperti hard disk eksternal yang bisa dipasang dan dilepas dari komputer.

#### **Docker Network**
Lapisan jaringan virtual yang menghubungkan container-container. Secara default, container yang berbeda tidak bisa saling berkomunikasi kecuali dihubungkan ke network yang sama. Docker menyediakan driver network yang berbeda untuk kebutuhan berbeda.

---

### 1.3 Docker vs Virtual Machine: Perbedaan Mendasar

Inilah pertanyaan yang sering ditanyakan: *"Bukankah kita sudah punya VM? Kenapa butuh Docker?"*

#### Cara Kerja Virtual Machine (VM)

Setiap VM berjalan di atas sebuah **Hypervisor** (VMware, VirtualBox, KVM). Hypervisor mensimulasikan hardware komputer secara penuh. Di atas hardware virtual tersebut, diinstal **full Guest OS** (misalnya Ubuntu 22.04 dengan kernel-nya sendiri). Baru di atas Guest OS itulah aplikasi berjalan.

```
┌─────────────────────────────────────────────────┐
│           Virtual Machine Architecture           │
│                                                 │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐   │
│  │   App A   │  │   App B   │  │   App C   │   │
│  ├───────────┤  ├───────────┤  ├───────────┤   │
│  │ Guest OS  │  │ Guest OS  │  │ Guest OS  │   │
│  │ (500MB+)  │  │ (500MB+)  │  │ (500MB+)  │   │
│  └───────────┘  └───────────┘  └───────────┘   │
│  ┌─────────────────────────────────────────┐    │
│  │         Hypervisor (Type 1 or 2)        │    │
│  └─────────────────────────────────────────┘    │
│  ┌─────────────────────────────────────────┐    │
│  │         Host OS (Host Kernel)           │    │
│  └─────────────────────────────────────────┘    │
│  ┌─────────────────────────────────────────┐    │
│  │              Physical Hardware          │    │
│  └─────────────────────────────────────────┘    │
└─────────────────────────────────────────────────┘
```

#### Cara Kerja Docker (Containerization)

Docker menggunakan dua fitur kernel Linux yang sudah ada:
- **Namespaces**: Mengisolasi "tampilan" container dari proses, jaringan, filesystem, dan user ID (PID, NET, MNT, UTS, IPC, User namespace).
- **Control Groups (cgroups)**: Membatasi penggunaan resource (CPU, RAM, I/O) oleh proses-proses di dalam container.

Container **berbagi kernel yang sama** dengan host OS. Tidak ada Guest OS, tidak ada hypervisor overhead.

```
┌─────────────────────────────────────────────────┐
│             Docker Architecture                  │
│                                                 │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐   │
│  │   App A   │  │   App B   │  │   App C   │   │
│  ├───────────┤  ├───────────┤  ├───────────┤   │
│  │Container A│  │Container B│  │Container C│   │
│  │ (MBs)    │  │ (MBs)    │  │ (MBs)    │   │
│  └───────────┘  └───────────┘  └───────────┘   │
│  ┌─────────────────────────────────────────┐    │
│  │         Docker Engine (dockerd)         │    │
│  └─────────────────────────────────────────┘    │
│  ┌─────────────────────────────────────────┐    │
│  │    Host OS (Shared Linux Kernel)        │    │
│  └─────────────────────────────────────────┘    │
│  ┌─────────────────────────────────────────┐    │
│  │              Physical Hardware          │    │
│  └─────────────────────────────────────────┘    │
└─────────────────────────────────────────────────┘
```

#### Tabel Perbandingan Komprehensif

| Aspek | Virtual Machine (VM) | Docker Container |
|---|---|---|
| **Unit Abstraksi** | Virtualisasi Hardware | Virtualisasi OS Process |
| **Kernel** | Setiap VM punya kernel sendiri | Berbagi kernel host |
| **Startup Time** | Menit (booting full OS) | Detik (bahkan milidetik) |
| **Ukuran** | GBs (karena full OS) | MBs (hanya app + deps) |
| **Isolasi** | Sangat kuat (hardware level) | Kuat (kernel namespace) |
| **Resource Overhead** | Tinggi (full OS overhead) | Sangat rendah |
| **Portabilitas** | Terbatas (format proprietary) | Sangat tinggi (OCI standard) |
| **Density per Host** | Rendah (puluhan VM) | Tinggi (ratusan container) |
| **Persistensi Data** | Virtual Disk (VMDK, QCOW2) | Volumes / Bind Mounts |
| **Security Boundary** | Hypervisor (sangat kuat) | Kernel namespaces (kuat) |
| **Use Case Utama** | Isolasi OS penuh, legacy apps | Microservices, CI/CD, packaging |

> **Kesimpulan:** VM dan Container bukan saingan — mereka saling melengkapi. Di production, container sering berjalan **di dalam** VM untuk mendapatkan dua lapis isolasi (VM isolation + container isolation).

---

## BAB 2: Panduan Instalasi & Setup Awal (Production Standards)

### 2.1 Instalasi Docker Engine di Ubuntu/Debian

> ⚠️ **PENTING:** Jangan gunakan `apt install docker.io` (paket dari Ubuntu repo yang sudah outdated) dan jangan gunakan `snap install docker`. Selalu gunakan **repositori resmi Docker** untuk mendapatkan versi terbaru dan dukungan resmi.

#### Langkah 1: Hapus Versi Lama (Jika Ada)

```bash
# Hapus paket-paket lama yang mungkin konflik
sudo apt-get remove -y docker docker-engine docker.io containerd runc

# Hapus semua data lama (HATI-HATI: ini menghapus semua container dan image lama!)
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd
```

#### Langkah 2: Setup Repository Resmi Docker

```bash
# Update package index
sudo apt-get update

# Install paket dependency untuk HTTPS repository
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Buat direktori untuk keyring
sudo install -m 0755 -d /etc/apt/keyrings

# Download dan tambahkan GPG key resmi Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set permission yang benar
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Tambahkan repository Docker ke sources.list
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

> **Untuk Debian:** Ganti `ubuntu` dengan `debian` di URL dan perintah GPG di atas.

#### Langkah 3: Install Docker Engine, CLI, dan Compose Plugin

```bash
# Update index dengan repository baru
sudo apt-get update

# Install Docker Engine, containerd, dan Docker Compose plugin
sudo apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

# Verifikasi instalasi berhasil
sudo docker run hello-world
```

Output yang diharapkan dari `hello-world` mengindikasikan Docker berhasil diinstal dan daemon berjalan dengan benar.

#### Langkah 4: Verifikasi Versi

```bash
docker --version
# Output: Docker version 26.x.x, build xxxxxxx

docker compose version
# Output: Docker Compose version v2.x.x

sudo systemctl status docker
# Output: ● docker.service - Docker Application Container Engine
#         Loaded: loaded (/lib/systemd/system/docker.service; enabled)
#         Active: active (running)
```

---

### 2.2 Konfigurasi Post-Installation

#### Menjalankan Docker Tanpa `sudo`

Secara default, socket Docker (`/var/run/docker.sock`) hanya bisa diakses oleh user `root` dan member grup `docker`. Tambahkan user Anda ke grup `docker`:

```bash
# Tambahkan user ke grup docker
sudo usermod -aG docker $USER

# Aktifkan perubahan grup TANPA logout (untuk sesi saat ini)
newgrp docker

# Verifikasi tanpa sudo
docker ps
```

> **Catatan:** Untuk perubahan permanen, lakukan **logout dan login kembali** atau gunakan `newgrp docker` untuk sesi aktif.

#### ⚠️ RISIKO KEAMANAN: Menjalankan Docker Tanpa sudo

Menambahkan user ke grup `docker` **setara dengan memberikan akses root** ke sistem. Ini bukan hiperbola. Contoh eksploitasi:

```bash
# Siapapun dalam grup docker bisa menjadi root dengan cara ini:
docker run --rm -v /:/host -it alpine chroot /host sh
# Perintah di atas me-mount seluruh filesystem root ke dalam container
# dan memberikan shell sebagai root di host!
```

**Konsekuensi:**
- User dalam grup `docker` bisa me-mount direktori sensitif (`/etc`, `/root`)
- User bisa membaca atau memodifikasi file konfigurasi sistem
- User bisa menjalankan container sebagai root dan mengakses semua data di host

**Mitigasi untuk Production Server:**
- Di server production, **jangan tambahkan user regular ke grup docker**
- Gunakan `sudo docker` atau konfigurasikan **Rootless Docker** (lihat BAB 5)
- Gunakan **Docker socket proxy** (seperti Tecnativa/docker-socket-proxy) untuk membatasi akses

#### Konfigurasi Docker untuk Auto-Start

```bash
# Enable Docker untuk start otomatis saat boot
sudo systemctl enable docker

# Enable containerd juga
sudo systemctl enable containerd

# Start sekarang jika belum running
sudo systemctl start docker
```

---

### 2.3 Konfigurasi Docker Daemon (`daemon.json`)

File konfigurasi daemon Docker berada di `/etc/docker/daemon.json`. Jika belum ada, buat baru.

#### Konfigurasi Lengkap untuk Production (dengan Log Rotation)

```bash
sudo nano /etc/docker/daemon.json
```

Isi dengan konfigurasi berikut:

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3",
    "compress": "true"
  },
  "storage-driver": "overlay2",
  "live-restore": true,
  "userland-proxy": false,
  "no-new-privileges": true,
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 64000,
      "Soft": 64000
    }
  },
  "metrics-addr": "127.0.0.1:9323",
  "experimental": false
}
```

#### Penjelasan Setiap Parameter

| Parameter | Nilai | Penjelasan |
|---|---|---|
| `log-driver` | `json-file` | Driver log default. Alternatif: `journald`, `syslog`, `fluentd` |
| `log-opts.max-size` | `10m` | Batas maksimum ukuran satu file log (10 Megabyte) |
| `log-opts.max-file` | `3` | Jumlah file log yang disimpan (rotasi). Total max = 10m × 3 = 30MB per container |
| `log-opts.compress` | `true` | Kompres file log lama dengan gzip |
| `storage-driver` | `overlay2` | Driver storage terbaik untuk kernel Linux modern |
| `live-restore` | `true` | Container tetap running saat Docker Daemon restart/upgrade |
| `userland-proxy` | `false` | Matikan userland proxy untuk performa port forwarding yang lebih baik |
| `no-new-privileges` | `true` | Cegah proses di container mendapatkan privilege tambahan via setuid/setgid |
| `default-ulimits.nofile` | `64000` | Batas jumlah file descriptor per container (penting untuk app high-connection) |

#### Apply Konfigurasi

```bash
# Validasi syntax JSON
sudo python3 -c "import json; json.load(open('/etc/docker/daemon.json')); print('JSON valid!')"

# Restart Docker Daemon untuk menerapkan konfigurasi
sudo systemctl restart docker

# Verifikasi daemon berjalan dengan baik
sudo systemctl status docker
```

> **Penting:** Konfigurasi `log-driver` di `daemon.json` hanya berlaku untuk container yang dibuat **setelah** daemon di-restart. Container yang sudah ada perlu direcreate.

---

## BAB 3: Bedah Anatomi Komponen Docker

### 3.1 Docker Image: Blueprint yang Immutable

#### Konsep Layer (Read-Only)

Docker Image dibangun dari lapisan-lapisan (**layers**) yang bersifat **read-only**. Setiap instruksi `RUN`, `COPY`, atau `ADD` dalam Dockerfile menciptakan layer baru.

```
┌─────────────────────────────────────┐
│   Layer 5: COPY ./app /app (4MB)   │  ← Top Layer (paling baru)
├─────────────────────────────────────┤
│   Layer 4: RUN npm install (45MB)  │
├─────────────────────────────────────┤
│   Layer 3: RUN apt-get update (8MB)│
├─────────────────────────────────────┤
│   Layer 2: FROM node:18-alpine     │
│            RUN commands... (50MB)   │
├─────────────────────────────────────┤
│   Layer 1: FROM alpine:3.18 (7MB)  │  ← Base Layer
└─────────────────────────────────────┘
         Read-Only Image Layers
```

Saat container dijalankan, Docker menambahkan satu layer tipis yang bersifat **read-write** di atas image layers. Ini disebut **container layer**. Semua perubahan yang dilakukan di dalam container (membuat file, modifikasi konfigurasi) hanya tersimpan di layer ini dan **hilang** saat container dihapus — kecuali menggunakan Volume.

#### Build Cache: Akselerasi Pembangunan Image

Docker menyimpan cache untuk setiap layer. Jika instruksi dan konteksnya tidak berubah dari build sebelumnya, Docker menggunakan cache tersebut (ditandai `---> Using cache`). Ini membuat proses build berikutnya jauh lebih cepat.

**Best Practice: Susun Dockerfile dari yang jarang berubah ke yang sering berubah:**

```dockerfile
# ✅ BAIK: Dependency diinstall dulu, baru copy kode
FROM node:18-alpine
WORKDIR /app
COPY package.json package-lock.json ./   # Jarang berubah → cache stabil
RUN npm ci --only=production             # Cache valid selama package.json tidak berubah
COPY . .                                  # Sering berubah → di bagian bawah
CMD ["node", "server.js"]

# ❌ BURUK: Kode dicopy dulu, sehingga npm install selalu diulang
FROM node:18-alpine
WORKDIR /app
COPY . .           # Setiap kode berubah → cache miss
RUN npm install    # Selalu dijalankan ulang = lambat!
CMD ["node", "server.js"]
```

#### Anatomi Dockerfile: Setiap Instruksi Dijelaskan

```dockerfile
# =====================================================
# Contoh Dockerfile Production-Ready untuk Aplikasi Node.js
# =====================================================

# FROM: Menentukan base image. Selalu pin versi spesifik di production!
# Gunakan varian -alpine untuk ukuran yang jauh lebih kecil.
# JANGAN gunakan: FROM node:latest (tidak deterministik!)
FROM node:18-alpine AS builder

# LABEL: Metadata untuk image (opsional tapi direkomendasikan)
LABEL maintainer="devops@company.com"
LABEL version="1.0.0"
LABEL description="API Server for Product Service"

# ARG: Build-time variable. Tidak tersedia saat container runtime.
# Gunakan untuk versi app, environment saat build, dll.
ARG APP_ENV=production
ARG BUILD_VERSION=unknown

# ENV: Environment variable yang tersedia saat runtime.
# Bisa digunakan oleh aplikasi di dalam container.
ENV NODE_ENV=${APP_ENV}
ENV APP_VERSION=${BUILD_VERSION}
ENV PORT=3000

# WORKDIR: Set direktori kerja. Semua perintah selanjutnya berjalan di sini.
# Selalu gunakan ini daripada 'RUN cd /app'.
# Docker akan membuat direktori ini jika belum ada.
WORKDIR /app

# COPY: Salin file dari build context (host) ke dalam image.
# Gunakan .dockerignore untuk mengecualikan file yang tidak perlu (node_modules, .git).
# Format: COPY <src-host> <dst-container>
COPY package.json package-lock.json ./

# RUN: Jalankan perintah shell saat BUILD time.
# Setiap RUN menciptakan layer baru. Gabungkan perintah terkait dengan && \
# untuk mengurangi jumlah layer dan ukuran image.
# 'npm ci' lebih deterministic daripada 'npm install' untuk production.
# '--only=production' mengecualikan devDependencies.
RUN npm ci --only=production && \
    npm cache clean --force

# Copy sisa kode aplikasi
COPY . .

# =====================================================
# Multi-Stage Build: Stage Production (image final)
# =====================================================
# Dengan multi-stage build, stage 'builder' digunakan hanya untuk
# kompilasi/install. Image final hanya berisi yang diperlukan untuk runtime.
FROM node:18-alpine AS production

WORKDIR /app

# Copy hanya hasil build dari stage sebelumnya
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./
COPY --from=builder /app/src ./src

# EXPOSE: Mendokumentasikan port yang didengarkan oleh container.
# EXPOSE TIDAK membuka port ke host secara otomatis!
# Port mapping tetap dilakukan via 'docker run -p' atau docker-compose 'ports'.
EXPOSE 3000

# Buat user non-root untuk menjalankan aplikasi (SECURITY BEST PRACTICE)
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

# ENTRYPOINT: Perintah utama yang selalu dieksekusi.
# Tidak bisa di-override dengan argumen 'docker run' biasa.
# Gunakan format exec (JSON array) untuk signal handling yang benar.
ENTRYPOINT ["node"]

# CMD: Argumen default untuk ENTRYPOINT, atau perintah default jika tidak ada ENTRYPOINT.
# Bisa di-override dengan argumen 'docker run <image> <override>'.
CMD ["src/server.js"]
```

#### Perbedaan ENTRYPOINT vs CMD

| Aspek | `ENTRYPOINT` | `CMD` |
|---|---|---|
| **Fungsi** | Perintah utama yang selalu berjalan | Argumen default / perintah default |
| **Override** | Hanya dengan `--entrypoint` flag | Langsung di akhir `docker run` |
| **Penggunaan Umum** | Binary utama aplikasi | Argumen yang mungkin berubah |
| **Contoh** | `ENTRYPOINT ["nginx"]` | `CMD ["-g", "daemon off;"]` |

#### Perintah CLI: Build, Push, Pull

```bash
# === BUILD IMAGE ===

# Build image dari Dockerfile di direktori saat ini
docker build -t my-app:1.0.0 .

# Build dengan nama/tag dan target stage (multi-stage build)
docker build -t my-app:1.0.0 --target production .

# Build dengan build argument
docker build -t my-app:1.0.0 --build-arg APP_ENV=staging --build-arg BUILD_VERSION=abc123 .

# Build tanpa cache (paksa rebuild semua layer)
docker build --no-cache -t my-app:1.0.0 .

# Build dengan platform spesifik (penting untuk Apple Silicon / ARM)
docker buildx build --platform linux/amd64,linux/arm64 -t my-app:1.0.0 .

# === MELIHAT IMAGE ===

# List semua image di lokal
docker images
docker image ls

# Lihat layer dan history sebuah image
docker image history my-app:1.0.0

# Inspect detail metadata image (format JSON)
docker image inspect my-app:1.0.0

# === REGISTRY: PUSH & PULL ===

# Login ke Docker Hub
docker login

# Login ke private registry (contoh: GitHub Container Registry)
docker login ghcr.io -u USERNAME --password-stdin

# Tag image sebelum push (format: registry/username/repo:tag)
docker tag my-app:1.0.0 docker.io/myusername/my-app:1.0.0
docker tag my-app:1.0.0 ghcr.io/myorg/my-app:1.0.0

# Push image ke registry
docker push docker.io/myusername/my-app:1.0.0

# Pull image dari registry
docker pull nginx:1.25-alpine

# Pull dengan digest spesifik (paling aman untuk production — immutable!)
docker pull nginx@sha256:abc123...

# === HAPUS IMAGE ===

# Hapus image tertentu
docker image rm my-app:1.0.0
docker rmi my-app:1.0.0

# Hapus semua image yang tidak digunakan (dangling images)
docker image prune

# Hapus semua image yang tidak digunakan oleh container manapun
docker image prune -a
```

---

### 3.2 Docker Container: Siklus Hidup Penuh

#### Siklus Hidup Container

```
        docker create
            │
            ▼
┌─────────────────────┐
│      CREATED        │  ← Container dibuat tapi belum running
└─────────────────────┘
            │ docker start / docker run
            ▼
┌─────────────────────┐     docker pause
│      RUNNING        │ ─────────────────► PAUSED
│   (Proses berjalan) │ ◄───────────────── (Proses di-freeze)
└─────────────────────┘     docker unpause
            │
     ┌──────┴──────┐
     │             │
docker stop    docker kill
(SIGTERM +     (SIGKILL
  timeout)     langsung)
     │             │
     ▼             ▼
┌─────────────────────┐
│      STOPPED /      │
│      EXITED         │  ← Container berhenti, filesystem masih ada
└─────────────────────┘
            │ docker rm
            ▼
         (DELETED)       ← Container dan container layer dihapus permanen
```

#### Perintah CLI Container yang Wajib Dikuasai

```bash
# === MENJALANKAN CONTAINER ===

# Run dasar: jalankan container dari image, hapus otomatis saat selesai
docker run --rm hello-world

# Run interaktif dengan terminal (untuk debugging)
docker run --rm -it ubuntu:22.04 bash

# Run sebagai daemon (background process)
docker run -d --name my-nginx nginx:alpine

# Run dengan port mapping: -p <host-port>:<container-port>
docker run -d --name web -p 8080:80 nginx:alpine

# Run dengan environment variable
docker run -d --name my-app \
  -e DATABASE_URL="postgresql://user:pass@db:5432/mydb" \
  -e NODE_ENV=production \
  my-app:1.0.0

# Run dengan volume mount
docker run -d --name my-db \
  -v pgdata:/var/lib/postgresql/data \
  -e POSTGRES_PASSWORD=secretpass \
  postgres:15-alpine

# Run dengan restart policy (production standard)
# always: selalu restart (termasuk saat Docker daemon restart)
# unless-stopped: restart kecuali saat di-stop secara manual
# on-failure: restart hanya saat exit code non-zero
docker run -d --name my-app \
  --restart unless-stopped \
  my-app:1.0.0

# Run dengan resource limit (penting untuk production!)
docker run -d --name my-app \
  --memory="512m" \
  --cpus="0.5" \
  my-app:1.0.0

# === MANAJEMEN CONTAINER ===

# Lihat container yang sedang running
docker ps

# Lihat semua container (termasuk yang stopped)
docker ps -a

# Lihat dengan format custom
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Stop container (kirim SIGTERM, tunggu 10 detik, lalu SIGKILL)
docker stop my-nginx

# Stop dengan timeout custom (detik)
docker stop --time 30 my-nginx

# Start container yang sudah stopped
docker start my-nginx

# Restart container
docker restart my-nginx

# Kill container (kirim SIGKILL langsung, tidak menunggu graceful shutdown)
docker kill my-nginx

# Hapus container (harus dalam state stopped)
docker rm my-nginx

# Paksa hapus container yang sedang running (= kill + rm)
docker rm -f my-nginx

# === MONITORING & DEBUGGING ===

# Lihat log container
docker logs my-nginx

# Follow log secara real-time (seperti tail -f)
docker logs -f my-nginx

# Tampilkan N baris log terakhir
docker logs --tail 100 my-nginx

# Log dengan timestamp
docker logs -f --timestamps my-nginx

# Masuk ke dalam container yang sedang running
# SELALU gunakan nama user yang tepat!
docker exec -it my-nginx sh         # Shell standar (Alpine/minimal images)
docker exec -it my-nginx bash       # Bash (Debian/Ubuntu-based images)

# Jalankan perintah spesifik tanpa masuk shell
docker exec my-nginx nginx -t        # Test konfigurasi Nginx
docker exec my-app cat /etc/hosts

# Lihat resource usage container secara real-time
docker stats
docker stats my-nginx

# Lihat metadata lengkap container (JSON)
docker inspect my-nginx

# Lihat hanya IP address container
docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' my-nginx

# Copy file dari host ke container dan sebaliknya
docker cp ./config.conf my-nginx:/etc/nginx/conf.d/
docker cp my-nginx:/var/log/nginx/error.log ./nginx-error.log

# Lihat perbedaan filesystem container dari image aslinya
docker diff my-nginx
```

---

### 3.3 Docker Volume & Bind Mounts: Persistensi Data

#### Mengapa Volume Diperlukan?

Filesystem container bersifat **ephemeral** — ketika container dihapus, semua data di dalamnya ikut hilang. Untuk data yang harus persisten (database, file upload, konfigurasi), kita butuh mekanisme penyimpanan yang terpisah dari lifecycle container.

Docker menyediakan dua pendekatan utama:

#### Named Volume vs Bind Mount

```
┌────────────────────────────────────────────────────────┐
│                        HOST                            │
│                                                        │
│  /home/user/myapp/      /var/lib/docker/volumes/       │
│  ├── src/               └── myapp_data/               │
│  ├── config/                └── _data/                │
│  └── logs/                      └── (data here)       │
│        │                               │              │
│        │ Bind Mount                    │ Named Volume  │
│        │ (direktori host)              │ (Docker mgmt) │
│        ▼                               ▼              │
│  ┌───────────────────────────────────────────────┐    │
│  │              Docker Container                 │    │
│  │   /app/src/    /app/config/   /data/          │    │
│  └───────────────────────────────────────────────┘    │
└────────────────────────────────────────────────────────┘
```

| Aspek | Named Volume | Bind Mount |
|---|---|---|
| **Definisi** | Dikelola penuh oleh Docker | Direktori/file dari host di-mount langsung |
| **Lokasi Data** | `/var/lib/docker/volumes/<name>/_data` | Di mana saja di filesystem host |
| **Portabilitas** | Tinggi (bisa di-backup, migrate) | Rendah (path tergantung host) |
| **Performa** | Optimal (terutama di non-Linux) | Tergantung OS dan filesystem |
| **Cocok Untuk** | Database, data persistence production | Development (live code reload), konfigurasi |
| **Keamanan** | Docker mengatur permission | Bergantung permission file host |
| **Syntax `-v`** | `-v volume_name:/path/in/container` | `-v /host/path:/container/path` |

#### Perintah CLI Volume

```bash
# === NAMED VOLUMES ===

# Buat volume secara eksplisit
docker volume create pgdata

# List semua volume
docker volume ls

# Inspect detail volume (lokasi di host, driver, dll)
docker volume inspect pgdata

# Gunakan named volume saat menjalankan container
docker run -d \
  --name postgres-db \
  -v pgdata:/var/lib/postgresql/data \
  -e POSTGRES_PASSWORD=secretpass \
  postgres:15-alpine

# Hapus volume (gagal jika masih digunakan container)
docker volume rm pgdata

# Hapus semua volume yang tidak digunakan
docker volume prune

# === BIND MOUNTS ===

# Mount direktori kode untuk development (perubahan kode langsung terefleksi)
docker run -d \
  --name dev-app \
  -v $(pwd)/src:/app/src \
  -v $(pwd)/config:/app/config:ro \  # :ro = read-only (keamanan!)
  my-app:dev

# Mount file tunggal (untuk konfigurasi)
docker run -d \
  --name nginx \
  -v $(pwd)/nginx.conf:/etc/nginx/nginx.conf:ro \
  -p 80:80 \
  nginx:alpine

# === TMPFS MOUNT (Data in Memory, tidak persisten) ===
# Berguna untuk data sensitif sementara (token, session) yang tidak boleh ke disk

docker run -d \
  --name my-app \
  --tmpfs /tmp:rw,noexec,nosuid,size=100m \
  my-app:1.0.0
```

---

### 3.4 Docker Network: Komunikasi Antar Container

#### Jenis Network Bawaan Docker

```bash
# Lihat semua network yang ada
docker network ls
# NETWORK ID   NAME      DRIVER    SCOPE
# abc123       bridge    bridge    local
# def456       host      host      local
# ghi789       none      null      local
```

| Driver Network | Deskripsi | Kapan Digunakan |
|---|---|---|
| **bridge** | Network virtual terisolasi. Container berkomunikasi via IP atau nama container. | Default untuk container di host yang sama. Cocok untuk multi-container apps |
| **host** | Container langsung menggunakan network stack host. Tidak ada isolasi jaringan. | Kasus khusus yang butuh performa network tertinggi. Hindari untuk security |
| **none** | Tidak ada network interface (kecuali loopback). Isolasi penuh. | Container yang tidak boleh akses jaringan sama sekali (batch jobs, dsb) |
| **overlay** | Menghubungkan container di beberapa Docker host berbeda. | Docker Swarm, multi-host networking |
| **macvlan** | Container mendapat MAC address sendiri di jaringan fisik. | Legacy apps yang butuh IP di LAN langsung |

#### Komunikasi Antar Container via Nama

Dalam **custom bridge network** (yang dibuat manual atau via Docker Compose), container bisa saling berkomunikasi menggunakan **nama container/service sebagai hostname**. Ini memanfaatkan DNS resolver internal Docker.

> ⚠️ **Perhatian:** Fitur DNS resolving berdasarkan nama ini hanya bekerja di **custom bridge network**, TIDAK di default `bridge` network bawaan Docker!

```bash
# === MEMBUAT DAN MENGGUNAKAN CUSTOM NETWORK ===

# Buat custom bridge network
docker network create my-app-network

# Buat custom network dengan subnet spesifik
docker network create \
  --driver bridge \
  --subnet 172.20.0.0/16 \
  --gateway 172.20.0.1 \
  my-app-network

# Jalankan database dalam network tersebut
docker run -d \
  --name postgres-db \
  --network my-app-network \
  -e POSTGRES_PASSWORD=secret \
  postgres:15-alpine

# Jalankan aplikasi dalam network yang sama
# Aplikasi bisa mencapai database via hostname "postgres-db"
docker run -d \
  --name my-app \
  --network my-app-network \
  -e DATABASE_HOST=postgres-db \
  -e DATABASE_PORT=5432 \
  my-app:1.0.0

# Verifikasi: test koneksi dari dalam container app ke database
docker exec my-app ping postgres-db
docker exec my-app nslookup postgres-db

# Hubungkan container yang sudah running ke network baru
docker network connect my-app-network existing-container

# Putuskan container dari network
docker network disconnect my-app-network existing-container

# Inspect network (lihat container yang terhubung)
docker network inspect my-app-network

# Hapus network yang tidak digunakan
docker network rm my-app-network
docker network prune
```

---

## BAB 4: Mastery Docker Compose (Multi-Container Management)

### 4.1 Mengapa Docker Compose?

Bayangkan Anda memiliki stack aplikasi modern:
- **Aplikasi web** (Node.js API)
- **Reverse proxy** (Nginx)
- **Database** (PostgreSQL)
- **Cache** (Redis)

Untuk menjalankan semuanya secara manual dengan `docker run`, Anda harus mengetik perintah panjang seperti:

```bash
# Ini sangat merepotkan dan error-prone!
docker network create app-network

docker run -d --name postgres \
  --network app-network \
  -v pgdata:/var/lib/postgresql/data \
  -e POSTGRES_DB=mydb \
  -e POSTGRES_USER=user \
  -e POSTGRES_PASSWORD=secret \
  --restart unless-stopped \
  postgres:15-alpine

docker run -d --name redis \
  --network app-network \
  -v redisdata:/data \
  --restart unless-stopped \
  redis:7-alpine

docker run -d --name api \
  --network app-network \
  -e DATABASE_URL=postgresql://user:secret@postgres:5432/mydb \
  -e REDIS_URL=redis://redis:6379 \
  --restart unless-stopped \
  my-api:1.0.0

docker run -d --name nginx \
  --network app-network \
  -p 80:80 -p 443:443 \
  -v ./nginx.conf:/etc/nginx/nginx.conf:ro \
  --restart unless-stopped \
  nginx:alpine
# ... dan seterusnya
```

**Docker Compose** memungkinkan seluruh definisi stack di atas ditulis dalam satu file YAML deklaratif (`docker-compose.yml`). Jalankan semuanya cukup dengan `docker compose up -d`.

---

### 4.2 Contoh `docker-compose.yml` Production-Ready

Contoh di bawah adalah stack lengkap: **Nginx (reverse proxy) + Node.js App + PostgreSQL + Redis**.

```yaml
# docker-compose.yml
# Stack: Nginx Reverse Proxy + Node.js API + PostgreSQL + Redis
# Production-Ready Configuration

# =====================================================
# EXTENSION FIELDS (YAML Anchors untuk DRY)
# Didefinisikan sekali, digunakan berkali-kali
# =====================================================
x-logging: &default-logging
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"

x-restart-policy: &restart-policy
  restart: unless-stopped

# =====================================================
# SERVICES: Definisi setiap container/service
# =====================================================
services:

  # ─── REVERSE PROXY: Nginx ───────────────────────
  nginx:
    image: nginx:1.25-alpine
    container_name: nginx_proxy
    <<: *restart-policy
    ports:
      # Format: "<HOST_PORT>:<CONTAINER_PORT>"
      # Hanya service ini yang membuka port ke dunia luar!
      - "80:80"
      - "443:443"
    volumes:
      # Bind mount untuk konfigurasi (read-only = keamanan)
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
      # Volume untuk SSL certificates
      - certbot-data:/etc/letsencrypt:ro
      # Volume untuk nginx logs
      - nginx-logs:/var/log/nginx
    networks:
      - frontend
    depends_on:
      api:
        condition: service_healthy
    logging: *default-logging
    healthcheck:
      test: ["CMD", "nginx", "-t"]
      interval: 30s
      timeout: 10s
      retries: 3

  # ─── APPLICATION SERVER: Node.js API ─────────────
  api:
    # Build dari Dockerfile lokal
    build:
      context: ./api
      dockerfile: Dockerfile
      target: production       # Target stage (multi-stage build)
      args:
        BUILD_VERSION: "${APP_VERSION:-latest}"
    image: my-api:${APP_VERSION:-latest}   # Tag image setelah build
    container_name: nodejs_api
    <<: *restart-policy
    # 'expose' hanya mendokumentasikan port INTERNAL.
    # Berbeda dengan 'ports', 'expose' TIDAK membuka port ke host!
    # Container lain di network yang sama bisa mengaksesnya via port ini.
    expose:
      - "3000"
    environment:
      # Selalu gunakan variable substitution dari file .env
      # Jangan pernah hardcode secrets di docker-compose.yml!
      - NODE_ENV=production
      - PORT=3000
      - DATABASE_URL=postgresql://${DB_USER}:${DB_PASSWORD}@postgres:5432/${DB_NAME}
      - REDIS_URL=redis://:${REDIS_PASSWORD}@redis:6379
      - JWT_SECRET=${JWT_SECRET}
    volumes:
      # Persistent storage untuk uploads
      - uploads-data:/app/uploads
    networks:
      - frontend   # Bisa diakses Nginx
      - backend    # Bisa akses Postgres dan Redis
    depends_on:
      postgres:
        condition: service_healthy  # Tunggu Postgres benar-benar ready
      redis:
        condition: service_healthy
    logging: *default-logging
    healthcheck:
      test: ["CMD", "node", "-e", "require('http').get('http://localhost:3000/health', (r) => r.statusCode === 200 ? process.exit(0) : process.exit(1))"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 30s   # Beri waktu app untuk startup sebelum mulai health check
    # Resource limits (penting untuk production!)
    deploy:
      resources:
        limits:
          cpus: "1.0"
          memory: 512M
        reservations:
          cpus: "0.25"
          memory: 128M

  # ─── DATABASE: PostgreSQL ────────────────────────
  postgres:
    image: postgres:15-alpine
    container_name: postgres_db
    <<: *restart-policy
    expose:
      - "5432"
    environment:
      - POSTGRES_DB=${DB_NAME}
      - POSTGRES_USER=${DB_USER}
      - POSTGRES_PASSWORD=${DB_PASSWORD}
      - PGDATA=/var/lib/postgresql/data/pgdata
    volumes:
      # Named volume untuk data persistence database
      - pgdata:/var/lib/postgresql/data
      # Mount SQL init scripts (hanya dijalankan saat database pertama kali dibuat)
      - ./postgres/init:/docker-entrypoint-initdb.d:ro
    networks:
      - backend   # HANYA di backend network! Tidak bisa diakses dari frontend
    logging: *default-logging
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER} -d ${DB_NAME}"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
    deploy:
      resources:
        limits:
          cpus: "1.0"
          memory: 1G

  # ─── CACHE: Redis ────────────────────────────────
  redis:
    image: redis:7-alpine
    container_name: redis_cache
    <<: *restart-policy
    expose:
      - "6379"
    command: >
      redis-server
      --requirepass ${REDIS_PASSWORD}
      --appendonly yes
      --appendfsync everysec
      --maxmemory 256mb
      --maxmemory-policy allkeys-lru
    volumes:
      - redisdata:/data
    networks:
      - backend
    logging: *default-logging
    healthcheck:
      test: ["CMD", "redis-cli", "--no-auth-warning", "-a", "${REDIS_PASSWORD}", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

# =====================================================
# VOLUMES: Definisi Named Volumes
# =====================================================
volumes:
  pgdata:
    driver: local
  redisdata:
    driver: local
  uploads-data:
    driver: local
  nginx-logs:
    driver: local
  certbot-data:
    driver: local

# =====================================================
# NETWORKS: Definisi Custom Networks (Isolasi!)
# =====================================================
networks:
  frontend:
    # Network untuk komunikasi Nginx ↔ App
    driver: bridge
    name: app_frontend
  backend:
    # Network untuk komunikasi App ↔ DB ↔ Redis
    # Nginx TIDAK terhubung ke network ini = isolasi!
    driver: bridge
    name: app_backend
    internal: false   # Set 'true' jika container di sini tidak boleh akses internet
```

#### File `.env` yang Diperlukan

```bash
# .env (JANGAN commit file ini ke Git! Tambahkan ke .gitignore)

APP_VERSION=1.5.2

# Database
DB_NAME=myappdb
DB_USER=appuser
DB_PASSWORD=super_secret_password_change_this!

# Redis
REDIS_PASSWORD=redis_secret_password_change_this!

# Application
JWT_SECRET=your_very_long_random_jwt_secret_key_here
```

---

### 4.3 Penjelasan Parameter Krusial Docker Compose

| Parameter | Penjelasan Mendalam |
|---|---|
| **`services`** | Blok utama yang mendefinisikan setiap container/service dalam stack |
| **`build`** | Meminta Docker Compose untuk build image dari Dockerfile lokal. Bisa spesifikasi `context`, `dockerfile`, `target`, dan `args` |
| **`image`** | Nama image yang digunakan (jika tanpa `build`) atau nama yang diberikan ke image hasil build |
| **`ports`** | Mapping port `HOST:CONTAINER`. Membuka port ke luar host. Hanya service "edge" (reverse proxy) yang sebaiknya punya ini |
| **`expose`** | Mendokumentasikan port internal yang tersedia untuk container lain di network yang sama. TIDAK membuka ke host |
| **`environment`** | Set environment variables di dalam container. Bisa pakai format `KEY=VALUE` atau `KEY` (ambil dari environment host) |
| **`volumes`** | Mount volumes atau bind mounts ke dalam container |
| **`networks`** | Daftar network yang diikuti oleh service ini |
| **`depends_on`** | Mendefinisikan urutan startup antar service. Dengan `condition: service_healthy`, menunggu health check service lain lulus |
| **`restart`** | Policy restart container: `no`, `always`, `on-failure`, `unless-stopped` |
| **`extra_hosts`** | Menambahkan entri ke `/etc/hosts` container. `host-gateway` memetakan ke IP gateway (berguna untuk akses service di host dari dalam container) |
| **`healthcheck`** | Mendefinisikan cara Docker memeriksa apakah service berjalan dengan benar |
| **`deploy.resources`** | Membatasi CPU dan RAM yang bisa digunakan service |

```yaml
# Contoh extra_hosts (akses service di host dari container)
extra_hosts:
  - "host.docker.internal:host-gateway"
  # Container sekarang bisa akses host via 'host.docker.internal'
```

---

### 4.4 Perintah CLI Docker Compose yang Wajib Dikuasai

```bash
# === LIFECYCLE STACK ===

# Jalankan seluruh stack (build jika perlu, detached/background)
docker compose up -d

# Jalankan dengan force rebuild image
docker compose up -d --build

# Jalankan dan tampilkan log di foreground (bagus untuk debugging)
docker compose up

# Jalankan service tertentu saja
docker compose up -d nginx postgres

# Hentikan dan hapus semua container, network (tapi TIDAK volume)
docker compose down

# Hentikan dan hapus semua + VOLUME (HATI-HATI! Data hilang!)
docker compose down -v

# Hentikan tanpa menghapus container (container masih ada, hanya stopped)
docker compose stop

# Start container yang sudah stopped
docker compose start

# === MONITORING ===

# Lihat status semua service dalam stack
docker compose ps

# Follow log semua service secara real-time
docker compose logs -f

# Follow log service tertentu dengan N baris terakhir
docker compose logs -f --tail=100 api

# Lihat statistik resource usage
docker compose stats

# === EKSEKUSI & DEBUGGING ===

# Masuk ke shell dalam service yang berjalan
docker compose exec api bash
docker compose exec postgres psql -U appuser -d myappdb

# Jalankan perintah one-off (container baru, tidak pakai yang running)
docker compose run --rm api npm run migrate

# === BUILD ===

# Build semua image yang didefinisikan dengan 'build' di compose file
docker compose build

# Build image tertentu tanpa cache
docker compose build --no-cache api

# === SCALING ===

# Scale service ke beberapa instance (hati-hati dengan port conflicts!)
docker compose up -d --scale api=3

# === KONFIGURASI ===

# Validasi dan tampilkan konfigurasi compose yang sudah di-resolve (variabel .env)
docker compose config

# Lihat list images yang digunakan/dibangun
docker compose images
```

---

## BAB 5: Panduan Keamanan Docker Tingkat Lanjut (Docker Hardening)

> *"A container is only as secure as the configuration that runs it."*

### 5.1 Rootless Container: Jangan Jalankan Aplikasi sebagai Root

#### Mengapa Ini Berbahaya?

Secara default, proses di dalam container berjalan sebagai **root (UID 0)**. Jika terjadi kerentanan yang memungkinkan *container escape* (keluar dari isolasi container), penyerang akan langsung mendapatkan akses **root** di host server.

Bahkan tanpa container escape, menjalankan sebagai root meningkatkan risiko:
- Aplikasi yang dikompromisi bisa memodifikasi file sistem di dalam container
- Jika ada bug di Docker atau kernel yang membolehkan namespace escape
- Proses bisa membaca file sensitif (key, credential) yang seharusnya tidak bisa diakses

#### Cara Implementasi Non-Root User di Dockerfile

```dockerfile
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

# === SECURITY: Buat user non-root ===
# Metode 1: Gunakan user yang sudah ada di base image
# Node.js official image sudah menyediakan user 'node' (UID 1000)
# Ganti ownership direktori kerja ke user tersebut
RUN chown -R node:node /app

# Switch ke user non-root sebelum running aplikasi
USER node

EXPOSE 3000
CMD ["node", "server.js"]
```

```dockerfile
# Metode 2: Buat user dan group baru (untuk Alpine-based images)
FROM python:3.11-alpine

WORKDIR /app

# Buat group dan user dengan UID/GID spesifik
# UID/GID di atas 1000 untuk menghindari konflik dengan system users
RUN addgroup --system --gid 1001 appgroup && \
    adduser --system --uid 1001 --ingroup appgroup --no-create-home appuser

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Beri ownership ke appuser
RUN chown -R appuser:appgroup /app

USER appuser

EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

```yaml
# Cara override user di docker-compose.yml
services:
  api:
    image: my-api:1.0.0
    user: "1001:1001"   # Format: "UID:GID"
```

#### Verifikasi Container Tidak Berjalan sebagai Root

```bash
# Cek user yang menjalankan proses utama container
docker exec my-container id
# Output yang diharapkan: uid=1001(appuser) gid=1001(appgroup) groups=1001(appgroup)
# Bukan: uid=0(root) gid=0(root)

# Cek lebih detail
docker inspect my-container | grep -i user
```

---

### 5.2 Read-Only Filesystem: Cegah Modifikasi Runtime

Dengan menjadikan filesystem container **read-only**, kita mencegah:
- Injeksi malware atau backdoor ke dalam container
- Modifikasi binary aplikasi oleh attacker yang sudah masuk container
- Penulisan data ke path yang tidak seharusnya

```bash
# Jalankan container dengan filesystem read-only
docker run -d \
  --name my-secure-app \
  --read-only \
  # Berikan tmpfs untuk direktori yang MEMANG butuh write (tmp, cache)
  --tmpfs /tmp:rw,noexec,nosuid,size=100m \
  --tmpfs /app/cache:rw,noexec,nosuid,size=50m \
  my-app:1.0.0
```

```yaml
# Dalam docker-compose.yml
services:
  api:
    image: my-api:1.0.0
    read_only: true
    tmpfs:
      - /tmp:rw,noexec,nosuid,size=100m
      - /app/cache:rw,noexec,nosuid,size=50m
    volumes:
      # Volume untuk data yang perlu persisten
      - uploads-data:/app/uploads
```

```bash
# Test bahwa filesystem benar-benar read-only
docker exec my-secure-app touch /app/test.txt
# Output: touch: /app/test.txt: Read-only file system ✓
```

---

### 5.3 Resource Limiting: Cegah DoS Antar Container

Tanpa resource limit, satu container yang bermasalah (memory leak, infinite loop, traffic spike) bisa menghabiskan seluruh resource host dan membuat semua container lain mati. Ini disebut **"noisy neighbor" problem**.

```bash
# === LIMIT VIA docker run ===

# Batasi CPU: 0.5 = 50% dari satu core CPU
docker run -d \
  --name my-app \
  --cpus="0.5" \
  my-app:1.0.0

# Batasi CPU dengan cpu-period dan cpu-quota (lebih granular)
# cpu-quota / cpu-period = persentase CPU
# Contoh: 50000 / 100000 = 50% dari satu core
docker run -d \
  --name my-app \
  --cpu-period=100000 \
  --cpu-quota=50000 \
  my-app:1.0.0

# Batasi RAM: Hard limit
# Jika container melebihi limit ini, prosesnya akan di-kill (OOMKilled)
docker run -d \
  --name my-app \
  --memory="512m" \
  my-app:1.0.0

# Batasi RAM dengan swap
# --memory-swap = total (memory + swap). Jika sama dengan --memory, tidak ada swap
docker run -d \
  --name my-app \
  --memory="512m" \
  --memory-swap="512m" \  # Nonaktifkan swap untuk container ini
  my-app:1.0.0

# Batasi I/O (bps = bytes per second)
docker run -d \
  --name my-app \
  --device-read-bps /dev/sda:1mb \
  --device-write-bps /dev/sda:1mb \
  my-app:1.0.0
```

```yaml
# === LIMIT VIA docker-compose.yml ===
services:
  api:
    image: my-api:1.0.0
    deploy:
      resources:
        limits:
          cpus: "0.50"     # Max 50% dari 1 CPU core
          memory: 512M     # Max 512 Megabytes RAM
        reservations:
          cpus: "0.10"     # Minimum yang dijamin (untuk scheduler)
          memory: 128M     # Minimum RAM yang dijamin
```

```bash
# Monitor penggunaan resource container secara real-time
docker stats

# Monitor container spesifik
docker stats my-app

# Output contoh:
# CONTAINER ID   NAME     CPU %   MEM USAGE / LIMIT    MEM %    NET I/O
# a1b2c3d4e5f6   my-app   23.5%   234MiB / 512MiB     45.7%    1.2MB / 800KB

# Cek jika container pernah OOMKilled (mati karena kehabisan RAM)
docker inspect my-app | grep -i oomkilled
# "OOMKilled": true   ← berarti container perlu lebih banyak RAM atau ada memory leak!
```

---

### 5.4 Docker Socket Security: Risiko `/var/run/docker.sock`

**Docker socket** (`/var/run/docker.sock`) adalah Unix socket yang digunakan Docker Client untuk berkomunikasi dengan Docker Daemon. Siapapun yang bisa mengakses socket ini memiliki **kendali penuh atas Docker Engine**, yang secara efektif berarti akses root ke host.

#### Mengapa Mount Docker Socket ke Container Sangat Berbahaya?

```yaml
# ❌ PATTERN BERBAHAYA yang sering terlihat di tutorial lama
services:
  portainer:
    image: portainer/portainer-ce
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock  # BAHAYA!
```

Jika container yang menggunakan mount ini dikompromisi, attacker bisa:

```bash
# Dari dalam container yang punya akses docker.sock,
# attacker bisa run container baru dan escape ke host:
docker run --rm -v /:/host -it alpine chroot /host sh
# Sekarang attacker punya shell sebagai ROOT di host!
```

#### Solusi: Docker Socket Proxy

Gunakan **[Tecnativa/docker-socket-proxy](https://github.com/Tecnativa/docker-socket-proxy)** sebagai middleware yang hanya mengekspos endpoint Docker API yang benar-benar diperlukan:

```yaml
services:
  # Socket proxy: filter API calls ke Docker
  socket-proxy:
    image: tecnativa/docker-socket-proxy:latest
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro  # Akses readonly ke socket asli
    environment:
      # Set ke 1 untuk IZINKAN, 0 untuk BLOKIR
      - CONTAINERS=1    # Izinkan list/inspect containers
      - SERVICES=0      # Blokir Docker Swarm services
      - TASKS=0         # Blokir Docker Swarm tasks
      - SECRETS=0       # BLOKIR SECRETS! Sangat sensitif
      - NETWORKS=1      # Izinkan list networks
      - IMAGES=0        # Blokir akses images
      - INFO=1          # Izinkan docker info
      - POST=0          # Blokir semua POST (write operations!)
      - BUILD=0         # Blokir build image
      - EXEC=0          # Blokir docker exec!
    networks:
      - socket-network  # Network terisolasi khusus untuk proxy ini

  # Portainer hanya komunikasi via socket proxy, bukan langsung
  portainer:
    image: portainer/portainer-ce
    environment:
      - DOCKER_HOST=tcp://socket-proxy:2375  # Gunakan proxy, bukan socket langsung
    networks:
      - socket-network  # Hanya bisa akses socket proxy
      - frontend

networks:
  socket-network:
    internal: true  # Network ini tidak bisa akses internet
```

---

### 5.5 Network Isolation: Konsep DMZ dalam Docker

Konsep **DMZ (Demilitarized Zone)** dalam networking tradisional adalah zona jaringan terpisah antara internet (untrusted) dan jaringan internal (trusted). Di Docker, kita bisa menerapkan konsep serupa dengan multiple networks.

**Prinsip:** Container frontend (Nginx) tidak boleh bisa langsung berkomunikasi ke container database. Harus melalui lapisan aplikasi (API).

```
INTERNET
    │
    ▼
┌──────────────────────────────────────────────────────┐
│                  FRONTEND NETWORK                    │
│  ┌─────────┐                                        │
│  │  Nginx  │ ← Hanya ini yang terhubung ke internet  │
│  └────┬────┘                                        │
│       │ HTTP Proxy                                  │
└───────┼──────────────────────────────────────────────┘
        │ (Nginx terhubung ke KEDUA network)
┌───────┼──────────────────────────────────────────────┐
│  ┌────┴────┐       BACKEND NETWORK                   │
│  │   API   │                                        │
│  └────┬────┘                                        │
│       │                                             │
│  ┌────┴────┐  ┌─────────┐                           │
│  │ PostgreSQL │  │  Redis  │                          │
│  └──────────┘  └─────────┘                          │
│                                                     │
│  (Database tidak terhubung ke Frontend Network!)    │
└──────────────────────────────────────────────────────┘
```

Implementasi ini sudah tercakup dalam contoh `docker-compose.yml` di BAB 4 dengan dua network terpisah (`frontend` dan `backend`). Berikut verifikasi isolasinya:

```bash
# Verifikasi: Nginx TIDAK bisa langsung ping database
docker exec nginx_proxy ping postgres_db
# Output: ping: bad address 'postgres_db' (tidak ditemukan di DNS!)
# Ini benar! Nginx tidak tahu keberadaan postgres_db

# Verifikasi: API bisa akses database (berada di network yang sama)
docker exec nodejs_api ping postgres_db
# Output: PING postgres_db (172.20.0.3): 56 data bytes ...
# Ini benar! API bisa berkomunikasi dengan database

# Verifikasi: API bisa akses Nginx (berada di frontend network juga)
docker exec nodejs_api ping nginx_proxy
# Ini juga benar karena API terhubung ke frontend network

# Lihat network setiap container
docker inspect nginx_proxy | jq '.[0].NetworkSettings.Networks | keys'
# Output: ["app_frontend"]

docker inspect nodejs_api | jq '.[0].NetworkSettings.Networks | keys'
# Output: ["app_backend", "app_frontend"]

docker inspect postgres_db | jq '.[0].NetworkSettings.Networks | keys'
# Output: ["app_backend"]   ← Hanya di backend! Aman!
```

#### Tips Hardening Tambahan

```bash
# 1. Scan image untuk kerentanan sebelum deploy
docker scout cves my-api:1.0.0          # Jika menggunakan Docker Scout
# Atau gunakan Trivy (open source):
trivy image my-api:1.0.0

# 2. Jalankan dengan security options tambahan
docker run -d \
  --name my-app \
  --security-opt no-new-privileges:true \  # Cegah privilege escalation
  --security-opt seccomp=default \         # Gunakan seccomp profile default
  --cap-drop ALL \                          # Hapus semua Linux capabilities
  --cap-add NET_BIND_SERVICE \             # Tambah hanya capability yang diperlukan
  my-app:1.0.0

# 3. Gunakan content trust untuk verifikasi image
export DOCKER_CONTENT_TRUST=1
docker pull nginx:alpine  # Akan gagal jika image tidak di-sign
```

---

## BAB 6: Management & Maintenance (Tips DevOps)

### 6.1 Membersihkan Docker: Cegah Disk Penuh

Disk server yang penuh akibat Docker adalah masalah umum yang menyebabkan downtime. Berikut strategi pembersihan yang komprehensif.

#### Audit: Cek Penggunaan Disk Docker

```bash
# Lihat ringkasan penggunaan disk oleh Docker
docker system df

# Output:
# TYPE            TOTAL   ACTIVE   SIZE       RECLAIMABLE
# Images          25      8        12.54GB    8.23GB (65%)
# Containers      15      3        245.8MB    198.4MB (80%)
# Local Volumes   12      4        34.21GB    28.1GB (82%)
# Build Cache     156     0        3.21GB     3.21GB

# Lihat detail per komponen
docker system df -v
```

#### Perintah Pembersihan

```bash
# =====================================================
# PALING AMAN: Hanya hapus resource yang tidak digunakan
# =====================================================

# Hapus SEMUA resource yang tidak digunakan dalam satu perintah
# (stopped containers, dangling images, unused networks, unused volumes)
# ⚠️ Hapus juga VOLUME yang tidak digunakan! Hati-hati!
docker system prune -a --volumes

# Tanpa hapus volume (lebih aman):
docker system prune -a

# Dengan konfirmasi otomatis (untuk scripts/cron):
docker system prune -af

# =====================================================
# SELECTIVE: Hapus komponen spesifik
# =====================================================

# Hapus container yang sudah stopped
docker container prune
docker container prune -f  # Tanpa konfirmasi

# Hapus HANYA "dangling" images (image tanpa tag, sisa dari build)
docker image prune
docker image prune -f

# Hapus SEMUA image yang tidak digunakan oleh container manapun
docker image prune -a

# Hapus network yang tidak digunakan
docker network prune

# Hapus volume yang tidak digunakan (HATI-HATI! DATA HILANG PERMANEN!)
docker volume prune

# =====================================================
# MANUAL: Hapus dengan filter
# =====================================================

# Hapus container yang exited lebih dari 24 jam lalu
docker container prune --filter "until=24h"

# Hapus image yang dibuat lebih dari 7 hari lalu
docker image prune -a --filter "until=168h"

# Hapus container berdasarkan label tertentu
docker container prune --filter "label=environment=staging"
```

#### Otomasi: Setup Cron Job Pembersihan

```bash
# Edit crontab
sudo crontab -e

# Tambahkan job pembersihan mingguan (setiap Minggu jam 3 pagi)
# Hanya hapus stopped containers dan dangling images (AMAN)
0 3 * * 0 docker system prune -f --filter "until=168h" >> /var/log/docker-cleanup.log 2>&1

# Atau dengan notifikasi ke log yang lebih verbose
0 3 * * 0 /bin/bash -c 'echo "=== Docker Cleanup $(date) ===" && docker system df && docker system prune -f && echo "=== After Cleanup ===" && docker system df' >> /var/log/docker-cleanup.log 2>&1
```

---

### 6.2 Backup & Restore Docker Volume

Data di Docker Volume adalah aset kritikal (database, file upload, dsb). Berikut strategi backup yang proven.

#### Metode 1: Backup Volume Menggunakan Container Helper

Ini adalah metode paling portable — menggunakan container Alpine sementara untuk mengakses volume dan membuat arsip.

```bash
# =====================================================
# BACKUP VOLUME
# =====================================================

# Format perintah:
# docker run --rm \
#   -v <NAMA_VOLUME>:/data:ro \          ← Mount volume yang di-backup (read-only!)
#   -v $(pwd):/backup \                  ← Mount direktori backup di host
#   alpine \
#   tar czvf /backup/<NAMA_FILE>.tar.gz -C /data .

# Contoh: Backup volume database PostgreSQL
docker run --rm \
  -v pgdata:/data:ro \
  -v /backup/volumes:/backup \
  alpine \
  tar czvf /backup/pgdata-$(date +%Y%m%d-%H%M%S).tar.gz -C /data .

# Verifikasi backup
ls -lh /backup/volumes/
# -rw-r--r-- 1 root root 45M Jun 15 03:00 pgdata-20250615-030000.tar.gz

# Cek isi backup
tar tzvf /backup/volumes/pgdata-20250615-030000.tar.gz | head -20
```

#### Metode 2: Backup dengan Stop Container (Cold Backup - Paling Aman untuk Database)

```bash
# Stop container database untuk memastikan data consistency
docker compose stop postgres

# Backup volume
docker run --rm \
  -v pgdata:/data:ro \
  -v /backup/volumes:/backup \
  alpine \
  tar czvf /backup/pgdata-cold-$(date +%Y%m%d-%H%M%S).tar.gz -C /data .

# Start kembali container
docker compose start postgres
```

#### Metode 3: Backup PostgreSQL dengan `pg_dump` (Logical Backup)

```bash
# Hot backup: Database tetap running, gunakan pg_dump untuk konsistensi
docker exec postgres_db pg_dump \
  -U $DB_USER \
  -d $DB_NAME \
  --format=custom \          # Format custom lebih kompak dan fleksibel
  --compress=9 \             # Kompresi maksimal
  > /backup/db/myapp-$(date +%Y%m%d-%H%M%S).pgdump

# Atau langsung ke file di dalam volume backup
docker exec postgres_db pg_dumpall \
  -U $DB_USER \
  > /backup/db/all-databases-$(date +%Y%m%d).sql
```

#### Restore Volume dari Backup

```bash
# =====================================================
# RESTORE VOLUME
# =====================================================

# Pastikan container yang menggunakan volume sudah di-stop!
docker compose stop postgres

# Buat volume baru (atau gunakan yang sudah ada)
docker volume create pgdata

# Restore dari backup
# Catatan: --strip-components=1 menghapus '.' di awal path di dalam tar
docker run --rm \
  -v pgdata:/data \
  -v /backup/volumes:/backup:ro \
  alpine \
  sh -c "cd /data && tar xzvf /backup/pgdata-20250615-030000.tar.gz --strip-components=0"

# Verifikasi restore
docker run --rm \
  -v pgdata:/data:ro \
  alpine \
  ls -la /data/

# Start kembali container
docker compose start postgres

# Verifikasi database berjalan normal
docker exec postgres_db psql -U $DB_USER -d $DB_NAME -c "\dt"
```

#### Restore PostgreSQL dari pg_dump

```bash
# Restore dari pg_dump format custom
docker exec -i postgres_db pg_restore \
  -U $DB_USER \
  -d $DB_NAME \
  --clean \          # Drop existing objects sebelum restore
  --if-exists \      # Tidak error jika object tidak ada
  < /backup/db/myapp-20250615.pgdump

# Restore dari SQL dump
docker exec -i postgres_db psql \
  -U $DB_USER \
  -d $DB_NAME \
  < /backup/db/myapp-20250615.sql
```

#### Skrip Backup Otomatis

```bash
#!/bin/bash
# /usr/local/bin/docker-volume-backup.sh

set -euo pipefail

BACKUP_DIR="/backup/volumes"
RETENTION_DAYS=7
DATE=$(date +%Y%m%d-%H%M%S)
LOG_FILE="/var/log/docker-backup.log"

echo "=== Docker Volume Backup Started at $(date) ===" | tee -a $LOG_FILE

# Buat direktori backup jika belum ada
mkdir -p $BACKUP_DIR

# List volumes yang perlu di-backup (customize sesuai kebutuhan)
VOLUMES=("pgdata" "redisdata" "uploads-data")

for VOLUME in "${VOLUMES[@]}"; do
    echo "Backing up volume: $VOLUME" | tee -a $LOG_FILE
    
    docker run --rm \
        -v "${VOLUME}:/data:ro" \
        -v "${BACKUP_DIR}:/backup" \
        alpine \
        tar czvf "/backup/${VOLUME}-${DATE}.tar.gz" -C /data . \
        2>> $LOG_FILE
    
    echo "✓ Backup ${VOLUME} complete: ${BACKUP_DIR}/${VOLUME}-${DATE}.tar.gz" | tee -a $LOG_FILE
done

# Hapus backup yang lebih lama dari RETENTION_DAYS
echo "Removing backups older than ${RETENTION_DAYS} days..." | tee -a $LOG_FILE
find $BACKUP_DIR -name "*.tar.gz" -mtime +$RETENTION_DAYS -delete

echo "=== Backup Complete at $(date) ===" | tee -a $LOG_FILE

# Tampilkan ukuran total backup
echo "Total backup size:" | tee -a $LOG_FILE
du -sh $BACKUP_DIR | tee -a $LOG_FILE
```

```bash
# Buat skrip executable dan setup cron
chmod +x /usr/local/bin/docker-volume-backup.sh

# Jalankan setiap hari jam 2 pagi
sudo crontab -e
0 2 * * * /usr/local/bin/docker-volume-backup.sh
```

---

## Rangkuman & Quick Reference

### Cheat Sheet: Perintah Paling Sering Dipakai

```bash
# === ESSENTIALS ===
docker ps                          # List running containers
docker ps -a                       # List ALL containers
docker images                      # List images
docker logs -f <name>              # Follow container logs
docker exec -it <name> bash        # Shell ke dalam container
docker stats                       # Monitor resource usage

# === COMPOSE ESSENTIALS ===
docker compose up -d               # Start stack
docker compose down                # Stop dan hapus stack
docker compose logs -f             # Follow semua logs
docker compose ps                  # Status services
docker compose exec <svc> bash     # Shell ke service
docker compose restart <svc>       # Restart service tertentu

# === CLEANUP ===
docker system df                   # Cek penggunaan disk
docker system prune -a             # Bersihkan semua yang tidak digunakan
docker volume prune                # Hapus volume tidak dipakai (HATI-HATI!)

# === BACKUP ===
# Backup volume
docker run --rm -v <vol>:/data:ro -v $(pwd):/backup alpine \
  tar czvf /backup/<vol>-$(date +%Y%m%d).tar.gz -C /data .
```

### Checklist Keamanan Docker untuk Production

- [ ] Semua container berjalan sebagai user non-root
- [ ] Resource limits (CPU & RAM) dikonfigurasi di semua service
- [ ] Filesystem container di-set `read_only: true` (dengan tmpfs untuk direktori yang perlu write)
- [ ] Multiple networks digunakan untuk isolasi (frontend ↔ backend)
- [ ] Docker socket (`/var/run/docker.sock`) tidak di-mount langsung ke container
- [ ] Log rotation dikonfigurasi di `daemon.json`
- [ ] Image menggunakan tag version spesifik (bukan `latest`)
- [ ] Secrets tidak di-hardcode di `docker-compose.yml` (gunakan `.env` atau Docker Secrets)
- [ ] `.env` dan file sensitif masuk ke `.gitignore`
- [ ] Backup volume berjalan otomatis via cron
- [ ] Image di-scan untuk vulnerability sebelum deploy
- [ ] `live-restore: true` dikonfigurasi di daemon agar container tidak mati saat Docker daemon di-update

---

*Panduan ini dibuat untuk digunakan sebagai referensi teknis. Selalu uji konfigurasi di environment staging sebelum diterapkan ke production.*
