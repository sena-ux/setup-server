# 🐳 Panduan Lengkap: Docker + FrankenPHP untuk Aplikasi PHP
### (Laravel Octane & CodeIgniter | Koneksi Database Native Host)

> **Versi:** 2.0.0 | **Dibuat oleh:** Senior DevOps Engineer  
> **Target:** Developer yang ingin mengemas aplikasi PHP ke dalam Docker menggunakan FrankenPHP, dengan database tetap berjalan secara native di host server.

---

## 📌 Prasyarat

Sebelum memulai, pastikan environment Anda memenuhi hal berikut:

| Kebutuhan | Versi Minimum |
|---|---|
| Docker Engine | 24.x |
| Docker Compose | v2.x (`docker compose`) |
| Database (di Host) | MySQL 8.x / MariaDB 10.x |
| Sistem Operasi Host | Ubuntu 22.04 / Debian 12 |

> ⚠️ **PENTING:** Database berjalan **native di host** (bukan di dalam container). Pastikan MySQL/MariaDB sudah aktif dan dapat menerima koneksi dari luar localhost.

---

## 🔑 Konsep Utama: Koneksi dari Container ke Database Host

Karena database Anda berada di **luar Docker**, container tidak bisa menggunakan `localhost` atau `127.0.0.1`. Gunakan salah satu dari dua pendekatan berikut:

```
Container Docker
      │
      │  Menggunakan `host-gateway`
      ▼
  host.docker.internal  ──────►  Database di Host (port 3306)
```

**Dua cara untuk terhubung ke host:**

1. **`host.docker.internal`** → Nama DNS khusus yang merujuk ke IP host dari dalam container *(direkomendasikan untuk portabilitas)*
2. **IP Host Langsung** (misal: `172.17.0.1`) → Bisa digunakan tapi kurang fleksibel

Kedua cara ini diaktifkan melalui opsi `extra_hosts` di `docker-compose.yml`.

---

---

# BAGIAN 1: LARAVEL (dengan Laravel Octane)

## 1.1 Struktur Direktori Lengkap untuk Laravel

Berikut adalah layout folder yang **ideal** untuk proyek Laravel dengan FrankenPHP, termasuk semua file konfigurasi Docker:

```
laravel-app/                                 # Root direktori proyek
│
├── app/                                     # Core aplikasi Laravel
│   ├── Http/
│   ├── Models/
│   └── ...
│
├── bootstrap/
│   ├── app.php
│   └── cache/                               # ⬅️ PERLU WRITABLE
│
├── config/                                  # Konfigurasi aplikasi Laravel
│   ├── app.php
│   ├── database.php
│   └── ...
│
├── database/
│   ├── factories/
│   ├── migrations/
│   └── seeders/
│
├── public/                                  # ⬅️ DOCUMENT ROOT
│   ├── index.php                            # Entry point Laravel
│   ├── .htaccess
│   └── ...
│
├── resources/
│   ├── views/
│   ├── css/
│   └── js/
│
├── routes/
│   ├── web.php
│   ├── api.php
│   └── ...
│
├── storage/                                 # ⬅️ PERLU WRITABLE
│   ├── logs/                                # Menyimpan log aplikasi
│   ├── framework/                           # Cache, session, views
│   └── app/                                 # File upload user
│
├── vendor/                                  # Dependencies Composer
│
├── docker/                                  # 📁 FOLDER KONFIGURASI DOCKER
│   ├── Caddyfile                           # ⬅️ LETAK CADDYFILE
│   ├── .dockerignore                       # (optional, bisa di root)
│   └── nginx.conf                          # (jika menggunakan nginx, opsional)
│
├── .env                                     # ⬅️ Environment variables (JANGAN di-commit!)
├── .env.example                             # Template .env
├── .gitignore
├── .dockerignore                            # ⬅️ File/folder yang TIDAK masuk docker build
│
├── artisan                                  # CLI Laravel
├── composer.json
├── composer.lock
│
├── Dockerfile                               # ⬅️ BUILD INSTRUCTION
├── docker-compose.yml                      # ⬅️ ORCHESTRATION
└── README.md
```

---

## 1.2 Dockerfile untuk Laravel Octane - Panduan Konfigurasi Lengkap

### 📝 Buat File: `Dockerfile` (di root proyek)

```dockerfile
# =============================================================================
# Dockerfile - Laravel dengan FrankenPHP + Octane (Worker Mode)
# Lokasi: ./Dockerfile (di root direktori proyek)
# Base image: dunglas/frankenphp dengan Alpine Linux (ringan & aman)
# =============================================================================

FROM dunglas/frankenphp:latest-alpine AS base

# ═════════════════════════════════════════════════════════════════════════
# SECTION 1: METADATA (Informasi image)
# ═════════════════════════════════════════════════════════════════════════
LABEL maintainer="devops@perusahaan.com"
LABEL description="Laravel Octane dengan FrankenPHP"
LABEL version="1.0"

# ═════════════════════════════════════════════════════════════════════════
# SECTION 2: INSTALL SYSTEM DEPENDENCIES
# Alpine menggunakan apk sebagai package manager
# ═════════════════════════════════════════════════════════════════════════
RUN apk add --no-cache \
    # Dibutuhkan untuk ekstensi intl (internationalization)
    icu-dev \
    # Dibutuhkan untuk ekstensi zip
    libzip-dev \
    zip \
    unzip \
    # Dibutuhkan untuk proses background & signal handling di Octane
    libstdc++ \
    oniguruma-dev \
    # Dibutuhkan untuk ekstensi GD (manipulasi gambar)
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    # Curl untuk HTTP client
    curl-dev \
    # Git untuk composer install
    git

# ═════════════════════════════════════════════════════════════════════════
# SECTION 3: INSTALL PHP EXTENSIONS
# install-php-extensions = script bawaan image dunglas/frankenphp
# ═════════════════════════════════════════════════════════════════════════
RUN install-php-extensions \
    # ⬇️ INTERNATIONALIZATION - WAJIB untuk Laravel Octane
    intl \
    # ⬇️ ARBITRARY PRECISION MATH - untuk kalkulasi keuangan
    bcmath \
    # ⬇️ DATABASE - Koneksi ke MySQL/MariaDB via PDO (modern)
    pdo_mysql \
    # ⬇️ DATABASE - Koneksi MySQL via MySQLi (alternatif)
    mysqli \
    # ⬇️ COMPRESSION - Kompresi file ZIP
    zip \
    # ⬇️ IMAGE MANIPULATION - GD untuk image processing
    gd \
    # ⬇️ CACHING - Ekstensi untuk Redis
    redis \
    # ⬇️ PERFORMANCE - OPcache untuk optimasi performa
    opcache \
    # ⬇️ PROCESS CONTROL - KRITIS untuk Laravel Octane Worker Mode
    # Mengizinkan PHP mengelola proses & signal handling
    pcntl \
    # ⬇️ STRING HANDLING - Ekstensi string multibyte
    mbstring

# ═════════════════════════════════════════════════════════════════════════
# SECTION 4: KONFIGURASI OPCACHE
# OPcache = menyimpan compiled bytecode sehingga tidak perlu compile ulang
# ═════════════════════════════════════════════════════════════════════════
RUN echo "opcache.enable=1" >> /usr/local/etc/php/conf.d/opcache.ini && \
    echo "opcache.memory_consumption=256" >> /usr/local/etc/php/conf.d/opcache.ini && \
    echo "opcache.max_accelerated_files=20000" >> /usr/local/etc/php/conf.d/opcache.ini && \
    # Di production, matikan revalidasi file untuk performa maksimal
    echo "opcache.validate_timestamps=0" >> /usr/local/etc/php/conf.d/opcache.ini && \
    echo "opcache.save_comments=1" >> /usr/local/etc/php/conf.d/opcache.ini

# ═════════════════════════════════════════════════════════════════════════
# SECTION 5: INSTALL COMPOSER
# Composer = PHP package manager untuk manage dependencies
# ═════════════════════════════════════════════════════════════════════════
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# ═════════════════════════════════════════════════════════════════════════
# SECTION 6: SET WORKING DIRECTORY
# Semua perintah setelah ini akan berjalan di /app
# ═════════════════════════════════════════════════════════════════════════
WORKDIR /app

# ═════════════════════════════════════════════════════════════════════════
# SECTION 7: COPY COMPOSER FILES (Layer Caching Optimization)
# Salin composer.json & composer.lock DULUAN sebelum source code
# Alasan: jika dependencies tidak berubah, layer ini bisa di-cache
# ═════════════════════════════════════════════════════════════════════════
COPY composer.json composer.lock ./

# Install dependencies PHP
RUN composer install \
    --no-dev \
    --no-scripts \
    --no-autoloader \
    --prefer-dist \
    --optimize-autoloader

# ═════════════════════════════════════════════════════════════════════════
# SECTION 8: COPY SOURCE CODE
# Sekarang salin seluruh kode aplikasi
# .dockerignore memastikan file tidak perlu (node_modules, .git) tidak ikut
# ═════════════════════════════════════════════════════════════════════════
COPY . .

# Generate optimized autoloader setelah semua file tersedia
RUN composer dump-autoload --optimize --no-dev

# ═════════════════════════════════════════════════════════════════════════
# SECTION 9: SET PERMISSIONS
# Set permission yang benar untuk direktori storage Laravel
# www-data atau user frankenphp harus bisa write ke folder storage & cache
# ═════════════════════════════════════════════════════════════════════════
RUN chown -R www-data:www-data /app/storage /app/bootstrap/cache && \
    chmod -R 775 /app/storage /app/bootstrap/cache

# ═════════════════════════════════════════════════════════════════════════
# SECTION 10: HEALTH CHECK
# Docker akan memeriksa kesehatan container secara berkala
# Jika health check gagal, container dianggap unhealthy
# ═════════════════════════════════════════════════════════════════════════
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost/up || exit 1

# ═════════════════════════════════════════════════════════════════════════
# SECTION 11: COPY CADDYFILE (CUSTOM WEB SERVER CONFIG)
# Copy custom Caddyfile dari folder docker/ ke dalam image
# PENTING: Pastikan file docker/Caddyfile sudah ada sebelum build!
# ═════════════════════════════════════════════════════════════════════════
COPY docker/Caddyfile /etc/caddy/Caddyfile

# ═════════════════════════════════════════════════════════════════════════
# SECTION 12: EXPOSE PORTS
# Tentukan port yang akan di-expose (dokumentasi, tidak mandatory)
# ═════════════════════════════════════════════════════════════════════════
EXPOSE 80 443

# ═════════════════════════════════════════════════════════════════════════
# SECTION 13: ENTRYPOINT/CMD
# FrankenPHP dijalankan dengan Caddyfile config
# Worker mode: PHP script di-load sekali dan menangani banyak request
# ═════════════════════════════════════════════════════════════════════════
CMD ["frankenphp", "run", "--config", "/etc/caddy/Caddyfile"]
```

### 🔧 Cara Konfigurasi Dockerfile:

1. **Buat file `Dockerfile`** di root proyek Anda
2. **Sesuaikan maintainer email** di bagian SECTION 1
3. **Jika ada ekstensi PHP tambahan** yang dibutuhkan, tambahkan di SECTION 3
4. **Pastikan folder `docker/` sudah ada** sebelum build (untuk SECTION 11)
5. **Jalankan build:**
   ```bash
   docker compose up -d --build
   ```

---

## 1.3 Docker Compose untuk Laravel - Panduan Konfigurasi Lengkap

### 📝 Buat File: `docker-compose.yml` (di root proyek)

```yaml
# =============================================================================
# docker-compose.yml - Laravel + FrankenPHP + Octane
# Lokasi: ./docker-compose.yml (di root direktori proyek)
# Versi: Compose Specification (tanpa `version:` header, sudah deprecated)
# =============================================================================

services:

  # ═════════════════════════════════════════════════════════════════════════
  # SERVICE: laravel-app
  # Nama service: laravel-app (bisa diakses via DNS internal Docker)
  # Container utama yang menjalankan aplikasi Laravel dengan FrankenPHP Octane
  # ═════════════════════════════════════════════════════════════════════════
  laravel-app:

    # ─────────────────────────────────────────────────────────────────────
    # [BUILD] Instruksi untuk build image
    # ─────────────────────────────────────────────────────────────────────
    build:
      # Context = folder yang dijadikan "konteks build" (file source)
      # Disini kita gunakan . (current directory) karena Dockerfile ada di root
      context: .
      
      # Dockerfile = file yang berisi instruksi build
      # Path relatif dari context (context: . + dockerfile: Dockerfile)
      dockerfile: Dockerfile
      
      # Target = target stage jika menggunakan multi-stage build
      # Jika Dockerfile punya "FROM ... AS base", gunakan target: base
      target: base
      
      # Args = build arguments (opsional)
      # Bisa diakses dalam Dockerfile via ${ARG_NAME}
      # args:
      #   - BUILD_ENV=production

    # ─────────────────────────────────────────────────────────────────────
    # [CONTAINER NAME] Nama container yang mudah diidentifikasi
    # Bisa diakses via: docker exec laravel_frankenphp ...
    # ─────────────────────────────────────────────────────────────────────
    container_name: laravel_frankenphp

    # ─────────────────────────────────────────────────────────────────────
    # [RESTART POLICY] Kebijakan restart saat container mati
    # Options: no | always | unless-stopped | on-failure
    # ─────────────────────────────────────────────────────────────────────
    restart: unless-stopped

    # ─────────────────────────────────────────────────────────────────────
    # [ENVIRONMENT VARIABLES] File yang berisi env vars
    # Laravel membaca file .env secara otomatis, tapi bisa di-override di sini
    # ─────────────────────────────────────────────────────────────────────
    env_file:
      - .env

    # ─────────────────────────────────────────────────────────────────────
    # [PORT MAPPING] Expose port dari container ke host
    # Format: "HOST_PORT:CONTAINER_PORT"
    # ─────────────────────────────────────────────────────────────────────
    ports:
      # HTTP - akses via http://localhost atau http://domain.com
      - "80:80"
      
      # HTTPS - FrankenPHP (Caddy) menangani SSL/TLS otomatis via Let's Encrypt
      - "443:443"
      
      # HTTP/3 (QUIC) - protokol modern untuk performa lebih baik
      - "443:443/udp"

    # ─────────────────────────────────────────────────────────────────────
    # [VOLUMES] Mount direktori untuk development atau persistent data
    # Format: "HOST_PATH:CONTAINER_PATH" atau "NAMED_VOLUME:CONTAINER_PATH"
    # ─────────────────────────────────────────────────────────────────────
    volumes:
      # Mount storage Laravel agar file upload & log persisten di host
      # Jika host folder tidak ada, Docker akan create otomatis
      - ./storage:/app/storage
      
      # Mount cache bootstrap agar tidak perlu generate ulang setiap restart
      - laravel_cache:/app/bootstrap/cache
      
      # Caddy data: menyimpan SSL certificates agar tidak perlu request ulang
      # named volume = persisten antar container restart
      - caddy_data:/data
      
      # Caddy config: konfigurasi Caddy yang persisten
      - caddy_config:/config

    # ─────────────────────────────────────────────────────────────────────
    # [EXTRA HOSTS] ⬅️ WAJIB! INI KUNCI KONEKSI KE DATABASE NATIVE DI HOST
    # Menambahkan entry ke /etc/hosts di dalam container
    # Format: "HOSTNAME:IP" atau "HOSTNAME:host-gateway"
    #
    # host-gateway = nilai spesial Docker yang otomatis di-resolve ke IP host
    # Dari dalam container, Anda bisa akses via: host.docker.internal
    # ─────────────────────────────────────────────────────────────────────
    extra_hosts:
      - "host.docker.internal:host-gateway"

    # ─────────────────────────────────────────────────────────────────────
    # [ULIMITS] Tingkatkan batas file descriptor untuk handle banyak koneksi
    # Laravel Octane dengan banyak worker membutuhkan ini
    # ─────────────────────────────────────────────────────────────────────
    ulimits:
      nofile:
        soft: 65536
        hard: 65536

    # ─────────────────────────────────────────────────────────────────────
    # [LOGGING] Konfigurasi logging container
    # ─────────────────────────────────────────────────────────────────────
    logging:
      driver: "json-file"
      options:
        max-size: "10m"    # Maksimum ukuran file log sebelum rotasi
        max-file: "3"      # Jumlah file log yang disimpan (rotasi)

# ═════════════════════════════════════════════════════════════════════════
# [VOLUMES] Definisi named volumes untuk data persisten
# Named volume = data disimpan di Docker volume, tidak di host filesystem
# Keuntungan: data persisten antar container, bisa shared antar container
# ═════════════════════════════════════════════════════════════════════════
volumes:
  # laravel_cache: untuk menyimpan cache bootstrap Laravel
  laravel_cache:
    driver: local
  
  # caddy_data: untuk menyimpan SSL certificates Caddy
  caddy_data:
    driver: local
  
  # caddy_config: untuk menyimpan konfigurasi Caddy
  caddy_config:
    driver: local
```

### 🔧 Cara Konfigurasi docker-compose.yml:

1. **Buat file `docker-compose.yml`** di root proyek
2. **Pastikan file `.env` sudah ada** (di bagian `env_file`)
3. **Sesuaikan port jika ada konflik:**
   - Jika port 80 sudah terpakai: ubah menjadi `"8080:80"` (akses via `http://localhost:8080`)
   - Jika port 443 sudah terpakai: ubah menjadi `"8443:443"`
4. **Jalankan:**
   ```bash
   docker compose up -d --build
   ```
5. **Cek status:**
   ```bash
   docker compose ps
   docker compose logs -f
   ```

---

## 1.4 Caddyfile untuk Laravel - Panduan Konfigurasi Lengkap

### 📝 Buat File: `docker/Caddyfile` (di folder docker/)

```caddyfile
# =============================================================================
# Caddyfile - Konfigurasi Web Server untuk Laravel Octane
# Lokasi: ./docker/Caddyfile (di folder docker/, relatif dari root proyek)
# FrankenPHP menggunakan Caddy sebagai web server di balik layar
# =============================================================================

# ═════════════════════════════════════════════════════════════════════════
# SECTION 1: GLOBAL CONFIGURATION
# Konfigurasi global untuk seluruh Caddy instance
# ═════════════════════════════════════════════════════════════════════════
{
    # Mode admin untuk management API Caddy
    # off = disable admin API (untuk production)
    # on = enable admin API (untuk development, default: http://localhost:2019)
    admin off
    
    # Aktifkan modul FrankenPHP di Caddy
    frankenphp
    
    # Email untuk notifikasi Let's Encrypt
    # PENTING: Gunakan email asli di production
    # Development: bisa "webmaster@example.com"
    email webmaster@example.com
}

# ═════════════════════════════════════════════════════════════════════════
# SECTION 2: SITE CONFIGURATION
# Konfigurasi untuk domain/port yang dilayani
# ═════════════════════════════════════════════════════════════════════════

# Matcher: localhost (ganti dengan domain asli di production)
# Port: :80 berarti Caddy listen di semua interface pada port 80
localhost {
    
    # ─────────────────────────────────────────────────────────────────────
    # [ROOT] Tentukan document root
    # root * /app/public = serve dari /app/public (folder public Laravel)
    # WAJIB! Tanpa ini, Laravel .env akan ter-expose
    # ─────────────────────────────────────────────────────────────────────
    root * /app/public

    # ─────────────────────────────────────────────────────────────────────
    # [PHP SERVER] Gunakan FrankenPHP untuk handle request PHP
    # php_server = directive untuk FrankenPHP
    # Otomatis menemukan index.php dan route ke PHP handler
    # ─────────────────────────────────────────────────────────────────────
    php_server {
        # (opsional) worker mode untuk Octane (sudah dihandle via .env)
        # num 4  ← Jumlah worker process (sesuaikan dengan CPU cores)
    }

    # ─────────────────────────────────────────────────────────────────────
    # [ENCODING] Kompres response untuk performa
    # zstd = Zstandard (compression algo baru, paling efisien)
    # br = Brotli (good compression, support modern browser)
    # gzip = Gzip (compatibility dengan browser lama)
    # ─────────────────────────────────────────────────────────────────────
    encode zstd br gzip

    # ─────────────────────────────────────────────────────────────────────
    # [FILE SERVER] Handle file static langsung tanpa PHP
    # Lebih efisien dibanding route ke PHP
    # ─────────────────────────────────────────────────────────────────────
    file_server

    # ─────────────────────────────────────────────────────────────────────
    # [SECURITY HEADERS] Tambahkan custom header untuk keamanan
    # ─────────────────────────────────────────────────────────────────────
    header {
        # Proteksi terhadap XSS attack
        X-Content-Type-Options nosniff
        
        # Prevent clickjacking
        X-Frame-Options DENY
        
        # Proteksi XSS untuk browser old (deprecated tapi tetap useful)
        X-XSS-Protection "1; mode=block"
        
        # HSTS: force HTTPS untuk akses berikutnya (production only)
        # Uncomment jika pakai HTTPS di production
        # Strict-Transport-Security "max-age=31536000; includeSubDomains"
    }

    # ─────────────────────────────────────────────────────────────────────
    # [LOGGING] Konfigurasi logging request
    # ─────────────────────────────────────────────────────────────────────
    log {
        # Output = kemana log dikirim (stderr = ke container logs)
        output stderr
        
        # Format = format log message
        # console = readable format untuk development
        # json = structured JSON (bagus untuk log aggregation)
        format console
        
        # Level = minimal log level yang ditampilkan
        # DEBUG < INFO < WARN < ERROR
        level INFO
    }
}
```

### 🔧 Cara Konfigurasi Caddyfile:

1. **Buat folder `docker/`** di root proyek (jika belum ada):
   ```bash
   mkdir -p docker
   ```

2. **Buat file `docker/Caddyfile`** dengan konten di atas

3. **Untuk production, sesuaikan:**
   - Ganti `localhost` dengan domain asli Anda:
     ```caddyfile
     yourdomain.com {
         root * /app/public
         ...
     }
     ```
   - Ganti email menjadi email asli:
     ```caddyfile
     email your-email@example.com
     ```
   - Uncomment HSTS header untuk force HTTPS:
     ```caddyfile
     Strict-Transport-Security "max-age=31536000; includeSubDomains"
     ```

4. **Pastikan Dockerfile sudah memiliki:**
   ```dockerfile
   COPY docker/Caddyfile /etc/caddy/Caddyfile
   ```

5. **Rebuild container:**
   ```bash
   docker compose up -d --build
   ```

---

## 1.5 File `.env` - Konfigurasi Environment Laravel

### 📝 Buat atau Edit: `.env` (di root proyek)

```dotenv
# =============================================================================
# .env - Konfigurasi Environment Laravel untuk Docker + FrankenPHP
# Lokasi: ./ (root direktori proyek)
# PENTING: File ini JANGAN di-commit! Tambahkan ke .gitignore
# =============================================================================

# ═════════════════════════════════════════════════════════════════════════
# APPLICATION CONFIGURATION
# ═════════════════════════════════════════════════════════════════════════
APP_NAME="Aplikasi Laravel Saya"
APP_ENV=production
APP_KEY=base64:GENERATE_DENGAN_php_artisan_key:generate
APP_DEBUG=false
APP_URL=http://localhost

# ═════════════════════════════════════════════════════════════════════════
# OCTANE CONFIGURATION - Worker Mode untuk Performance
# ═════════════════════════════════════════════════════════════════════════
OCTANE_SERVER=frankenphp
OCTANE_WORKERS=4          # ← Sesuaikan dengan jumlah CPU core (atau 2x CPU)
OCTANE_MAX_REQUESTS=500   # ← Restart worker setiap 500 request (prevent memory leak)

# ═════════════════════════════════════════════════════════════════════════
# DATABASE - KONEKSI KE HOST NATIVE
# ═════════════════════════════════════════════════════════════════════════
DB_CONNECTION=mysql

# ⚠️ KUNCI UTAMA: Gunakan `host.docker.internal` bukan `localhost`
# Alasan: localhost dari dalam container = container itu sendiri
#         host.docker.internal = IP gateway host (tempat MySQL Anda)
DB_HOST=host.docker.internal

DB_PORT=3306
DB_DATABASE=nama_database_laravel
DB_USERNAME=laravel_user
DB_PASSWORD=password_aman_anda

# ═════════════════════════════════════════════════════════════════════════
# CACHE & SESSION - Gunakan Redis atau File
# ═════════════════════════════════════════════════════════════════════════
CACHE_DRIVER=redis
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis

# Jika Redis juga di host native, gunakan host.docker.internal
REDIS_HOST=host.docker.internal
REDIS_PASSWORD=null
REDIS_PORT=6379

# ═════════════════════════════════════════════════════════════════════════
# LOGGING
# ═════════════════════════════════════════════════════════════════════════
LOG_CHANNEL=stderr
LOG_LEVEL=warning

# ═════════════════════════════════════════════════════════════════════════
# MAIL CONFIGURATION (opsional)
# ═════════════════════════════════════════════════════════════════════════
MAIL_MAILER=smtp
MAIL_HOST=smtp.mailtrap.io
MAIL_PORT=465
MAIL_USERNAME=your_username
MAIL_PASSWORD=your_password
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS="hello@example.com"
MAIL_FROM_NAME="${APP_NAME}"
```

---

## 1.6 File `.dockerignore` - File yang TIDAK masuk Docker Build

### 📝 Buat File: `.dockerignore` (di root proyek)

```dockerignore
# =============================================================================
# .dockerignore - File/folder yang TIDAK ikut dalam Docker build context
# Lokasi: ./ (root direktori proyek)
# Keuntungan: mempercepat build & mengurangi ukuran image
# =============================================================================

# Git
.git
.gitignore
.github/

# Dependencies (akan di-install ulang di container)
vendor/
node_modules/

# Environment (JANGAN masukkan ke dalam image!)
.env
.env.*
!.env.example

# Log dan cache lokal
storage/logs/*
storage/framework/cache/*
storage/framework/sessions/*
bootstrap/cache/*

# Testing
tests/
.phpunit.result.cache
phpunit.xml

# Development tools
.editorconfig
.php-cs-fixer.php
phpstan.neon
.eslintrc

# Docker files (tidak perlu ada di dalam image)
docker-compose*.yml
Dockerfile*
docker/

# OS
.DS_Store
Thumbs.db

# IDE
.vscode/
.idea/
*.swp
*.swo
```

---

---

# BAGIAN 2: CODEIGNITER (CI4 / CI3)

## 2.1 Struktur Direktori Lengkap untuk CodeIgniter 4

```
codeigniter4-app/                           # Root direktori proyek
│
├── app/                                    # Kode aplikasi (Controller, Model, Views)
│   ├── Controllers/
│   │   └── Home.php
│   ├── Models/
│   │   └── UserModel.php
│   ├── Views/
│   │   └── welcome_message.php
│   └── Config/
│       └── Database.php                    # ⬅️ KONFIGURASI DATABASE CI4
│
├── public/                                 # ⬅️ DOCUMENT ROOT
│   ├── index.php                           # Entry point CI4
│   ├── .htaccess
│   └── ...
│
├── system/                                 # Framework core CI4 (READ-ONLY)
├── vendor/                                 # Dependencies Composer
├── writable/                               # ⬅️ PERLU WRITABLE!
│   ├── logs/
│   ├── cache/
│   └── uploads/
│
├── docker/                                 # 📁 FOLDER KONFIGURASI DOCKER
│   ├── Caddyfile                          # ⬅️ LETAK CADDYFILE CI4
│   └── .dockerignore
│
├── .env                                    # ⬅️ Environment variables
├── .env.example
├── .gitignore
│
├── composer.json
├── composer.lock
│
├── Dockerfile                              # ⬅️ BUILD INSTRUCTION
├── docker-compose.yml                     # ⬅️ ORCHESTRATION
└── README.md
```

---

## 2.2 Dockerfile untuk CodeIgniter 4 - Panduan Lengkap

### 📝 Buat File: `Dockerfile` (di root proyek)

```dockerfile
# =============================================================================
# Dockerfile - CodeIgniter 4 dengan FrankenPHP
# Lokasi: ./Dockerfile (di root direktori proyek)
# Mode: Standard (bukan Worker Mode - CI4 tidak perlu Octane)
# =============================================================================

FROM dunglas/frankenphp:latest-alpine AS base

LABEL maintainer="devops@perusahaan.com"
LABEL description="CodeIgniter 4 dengan FrankenPHP"

# ═════════════════════════════════════════════════════════════════════════
# SECTION 1: INSTALL SYSTEM DEPENDENCIES
# ═════════════════════════════════════════════════════════════════════════
RUN apk add --no-cache \
    icu-dev \
    libzip-dev \
    zip \
    unzip \
    curl-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    git

# ═════════════════════════════════════════════════════════════════════════
# SECTION 2: INSTALL PHP EXTENSIONS - CODEIGNITER 4
# ═════════════════════════════════════════════════════════════════════════
RUN install-php-extensions \
    # ⬇️ INTERNATIONALIZATION - WAJIB untuk CI4
    intl \
    # ⬇️ DATABASE - MySQLi (driver default CI4)
    mysqli \
    # ⬇️ DATABASE - PDO MySQL (alternatif modern)
    pdo_mysql \
    # ⬇️ COMPRESSION - ZIP
    zip \
    # ⬇️ IMAGE - GD untuk image processing
    gd \
    # ⬇️ PERFORMANCE - OPcache
    opcache \
    # ⬇️ STRING - Multibyte support
    mbstring \
    # ⬇️ XML - Processing
    xml \
    # ⬇️ JSON - JSON support
    json \
    # ⬇️ CURL - HTTP client
    curl

# ═════════════════════════════════════════════════════════════════════════
# SECTION 3: KONFIGURASI PHP
# ═════════════════════════════════════════════════════════════════════════
RUN echo "upload_max_filesize=32M" >> /usr/local/etc/php/conf.d/custom.ini && \
    echo "post_max_size=32M" >> /usr/local/etc/php/conf.d/custom.ini && \
    echo "memory_limit=256M" >> /usr/local/etc/php/conf.d/custom.ini && \
    echo "max_execution_time=60" >> /usr/local/etc/php/conf.d/custom.ini

# ═════════════════════════════════════════════════════════════════════════
# SECTION 4: KONFIGURASI OPCACHE
# ═════════════════════════════════════════════════════════════════════════
RUN echo "opcache.enable=1" >> /usr/local/etc/php/conf.d/opcache.ini && \
    echo "opcache.memory_consumption=128" >> /usr/local/etc/php/conf.d/opcache.ini && \
    echo "opcache.max_accelerated_files=10000" >> /usr/local/etc/php/conf.d/opcache.ini && \
    echo "opcache.validate_timestamps=0" >> /usr/local/etc/php/conf.d/opcache.ini

# ═════════════════════════════════════════════════════════════════════════
# SECTION 5: INSTALL COMPOSER
# ═════════════════════════════════════════════════════════════════════════
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# ═════════════════════════════════════════════════════════════════════════
# SECTION 6: WORKING DIRECTORY
# ═════════════════════════════════════════════════════════════════════════
WORKDIR /app

# ═════════════════════════════════════════════════════════════════════════
# SECTION 7: INSTALL DEPENDENCIES
# ═════════════════════════════════════════════════════════════════════════
COPY composer.json composer.lock ./
RUN composer install \
    --no-dev \
    --no-scripts \
    --no-autoloader \
    --prefer-dist \
    --optimize-autoloader

# ═════════════════════════════════════════════════════════════════════════
# SECTION 8: COPY SOURCE CODE
# ═════════════════════════════════════════════════════════════════════════
COPY . .

# Generate autoloader
RUN composer dump-autoload --optimize --no-dev

# ═════════════════════════════════════════════════════════════════════════
# SECTION 9: SET PERMISSIONS - WRITABLE FOLDER
# CI4 membutuhkan folder writable yang bisa ditulis
# Folder `writable` berisi logs, cache, session, dan upload temp
# ═════════════════════════════════════════════════════════════════════════
RUN chown -R www-data:www-data /app/writable && \
    chmod -R 775 /app/writable

# ═════════════════════════════════════════════════════════════════════════
# SECTION 10: HEALTH CHECK
# ═════════════════════════════════════════════════════════════════════════
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

# ═════════════════════════════════════════════════════════════════════════
# SECTION 11: COPY CADDYFILE
# ═════════════════════════════════════════════════════════════════════════
COPY docker/Caddyfile /etc/caddy/Caddyfile

# ═════════════════════════════════════════════════════════════════════════
# SECTION 12: EXPOSE PORTS
# ═════════════════════════════════════════════════════════════════════════
EXPOSE 80 443

# ═════════════════════════════════════════════════════════════════════════
# SECTION 13: CMD - JALANKAN FRANKENPHP
# ═════════════════════════════════════════════════════════════════════════
CMD ["frankenphp", "run", "--config", "/etc/caddy/Caddyfile"]
```

---

## 2.3 Docker Compose untuk CodeIgniter 4 - Panduan Lengkap

### 📝 Buat File: `docker-compose.yml` (di root proyek)

```yaml
# =============================================================================
# docker-compose.yml - CodeIgniter 4 + FrankenPHP
# Lokasi: ./docker-compose.yml (di root direktori proyek)
# =============================================================================

services:

  codeigniter4-app:

    # ─────────────────────────────────────────────────────────────────────
    # [BUILD] Instruksi untuk build image
    # ─────────────────────────────────────────────────────────────────────
    build:
      context: .
      dockerfile: Dockerfile
      target: base

    # ─────────────────────────────────────────────────────────────────────
    # [CONTAINER NAME]
    # ─────────────────────────────────────────────────────────────────────
    container_name: ci4_frankenphp

    # ─────────────────────────────────────────────────────────────────────
    # [RESTART POLICY]
    # ─────────────────────────────────────────────────────────────────────
    restart: unless-stopped

    # ─────────────────────────────────────────────────────────────────────
    # [ENV FILE]
    # ─────────────────────────────────────────────────────────────────────
    env_file:
      - .env

    # ─────────────────────────────────────────────────────────────────────
    # [PORTS]
    # ─────────────────────────────────────────────────────────────────────
    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"

    # ─────────────────────────────────────────────────────────────────────
    # [VOLUMES] Mount folder writable dan SSL certificates
    # ─────────────────────────────────────────────────────────────────────
    volumes:
      # Mount folder writable agar log & cache persisten di host
      - ./writable:/app/writable
      
      # SSL certificates Caddy
      - caddy_data:/data
      - caddy_config:/config

    # ─────────────────────────────────────────────────────────────────────
    # [EXTRA HOSTS] WAJIB untuk koneksi ke database native di host
    # ─────────────────────────────────────────────────────────────────────
    extra_hosts:
      - "host.docker.internal:host-gateway"

    # ─────────────────────────────────────────────────────────────────────
    # [ENVIRONMENT] Override env vars
    # ─────────────────────────────────────────────────────────────────────
    environment:
      CI_ENVIRONMENT: production

    # ─────────────────────────────────────────────────────────────────────
    # [LOGGING]
    # ─────────────────────────────────────────────────────────────────────
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

# ═════════════════════════════════════════════════════════════════════════
# [NAMED VOLUMES]
# ═════════════════════════════════════════════════════════════════════════
volumes:
  caddy_data:
    driver: local
  caddy_config:
    driver: local
```

---

## 2.4 Caddyfile untuk CodeIgniter 4 - Panduan Lengkap

### 📝 Buat File: `docker/Caddyfile` (di folder docker/)

```caddyfile
# =============================================================================
# Caddyfile untuk CodeIgniter 4
# Lokasi: ./docker/Caddyfile
# Document Root: /app/public (folder public CI4)
# =============================================================================

{
    admin off
    frankenphp
}

# ═════════════════════════════════════════════════════════════════════════
# SITE CONFIGURATION UNTUK CI4
# ═════════════════════════════════════════════════════════════════════════

:80 {
    # ─────────────────────────────────────────────────────────────────────
    # [ROOT] DOCUMENT ROOT untuk CI4
    # root * /app/public = serve dari /app/public
    # INI SANGAT PENTING - tanpa ini, file sensitif seperti .env ter-expose!
    # ─────────────────────────────────────────────────────────────────────
    root * /app/public

    # ─────────────────────────────────────────────────────────────────────
    # [PHP SERVER] FrankenPHP handler untuk PHP
    # ─────────────────────────────────────────────────────────────────────
    php_server

    # ─────────────────────────────────────────────────────────────────────
    # [ENCODING] Kompres response
    # ─────────────────────────────────────────────────────────────────────
    encode zstd br gzip

    # ─────────────────────────────────────────────────────────────────────
    # [FILE SERVER] Serve static files
    # ─────────────────────────────────────────────────────────────────────
    file_server

    # ─────────────────────────────────────────────────────────────────────
    # [REWRITE] Arahkan semua request ke index.php
    # Ini meniru fungsi .htaccess RewriteEngine CI4
    # Alasan: CI4 menggunakan routing berbasis URL yang di-handle di index.php
    # ─────────────────────────────────────────────────────────────────────
    try_files {path} {path}/ /index.php?{query}

    # ─────────────────────────────────────────────────────────────────────
    # [SECURITY HEADERS] Header keamanan
    # ─────────────────────────────────────────────────────────────────────
    header {
        X-Content-Type-Options nosniff
        X-Frame-Options DENY
        X-XSS-Protection "1; mode=block"
    }

    # ─────────────────────────────────────────────────────────────────────
    # [LOGGING]
    # ─────────────────────────────────────────────────────────────────────
    log {
        output stderr
        format console
        level INFO
    }
}
```

---

## 2.5 File `.env` untuk CodeIgniter 4 - Panduan Lengkap

### 📝 Buat atau Edit: `.env` (di root proyek)

```dotenv
# =============================================================================
# .env - Konfigurasi Environment CodeIgniter 4
# Lokasi: ./ (root direktori proyek)
# PENTING: File ini JANGAN di-commit! Tambahkan ke .gitignore
# =============================================================================

# ═════════════════════════════════════════════════════════════════════════
# APPLICATION CONFIGURATION
# ═════════════════════════════════════════════════════════════════════════
CI_ENVIRONMENT = production

# ═════════════════════════════════════════════════════════════════════════
# DATABASE CONFIGURATION - Koneksi ke host native
# ═════════════════════════════════════════════════════════════════════════

# ⚠️ KUNCI UTAMA: Gunakan `host.docker.internal` bukan `localhost`
database.default.hostname = host.docker.internal

# Port MySQL default - sesuaikan jika Anda menggunakan port lain
database.default.port     = 3306

# Nama database
database.default.database = nama_database_ci4

# User MySQL (harus memiliki privilege dari IP Docker)
database.default.username = ci4_user
database.default.password = password_aman_anda

# Driver database yang digunakan
# `MySQLi` adalah driver default dan direkomendasikan untuk CI4 + MySQL
database.default.DBDriver = MySQLi

# Prefix tabel (kosongkan jika tidak digunakan)
database.default.DBPrefix =

# Enkripsi koneksi (set ke true jika MySQL menggunakan SSL)
database.default.encrypt = false

# Debug mode untuk query (matikan di production!)
database.default.DBDebug  = false

# ═════════════════════════════════════════════════════════════════════════
# LOGGING & DEBUGGING
# ═════════════════════════════════════════════════════════════════════════
app.name = "Aplikasi CI4 Saya"
app.baseURL = "http://localhost/"
```

---

## 2.6 Konfigurasi Database CodeIgniter 4 - Alternatif via File PHP

### 📝 Edit File: `app/Config/Database.php` (Alternatif atau Fallback)

```php
<?php

namespace Config;

use CodeIgniter\Database\Config;

/**
 * =============================================================================
 * Database Configuration - CodeIgniter 4
 * Lokasi: ./app/Config/Database.php
 * 
 * CATATAN: Jika file .env ada, nilai di sana akan OVERRIDE konfigurasi ini.
 * Gunakan file ini sebagai fallback atau template.
 * =============================================================================
 */
class Database extends Config
{
    /**
     * Nama koneksi database default yang digunakan aplikasi
     */
    public string $defaultGroup = 'default';

    /**
     * Konfigurasi koneksi database utama
     *
     * @var array<string, mixed>
     */
    public array $default = [
        // ⬇️ host.docker.internal = IP host dari dalam container Docker
        // Ini di-set oleh extra_hosts di docker-compose.yml
        'hostname' => 'host.docker.internal',
        'username' => 'ci4_user',
        'password' => 'password_aman_anda',
        'database' => 'nama_database_ci4',

        // Driver MySQLi direkomendasikan untuk MySQL/MariaDB
        'DBDriver' => 'MySQLi',
        'DBPrefix' => '',
        'pConnect' => false,
        'DBDebug'  => false,
        'charset'  => 'utf8mb4',
        'DBCollat' => 'utf8mb4_general_ci',
        'swapPre'  => '',
        'encrypt'  => false,
        'compress' => false,
        'strictOn' => false,
        'failover' => [],
        'port'     => 3306,
    ];

    /**
     * Konfigurasi untuk test environment (opsional)
     */
    public array $tests = [
        'hostname' => 'host.docker.internal',
        'username' => 'ci4_test_user',
        'password' => 'password_test',
        'database' => 'nama_database_ci4_test',
        'DBDriver' => 'MySQLi',
        'DBPrefix' => '',
        'DBDebug'  => true,
        'port'     => 3306,
    ];
}
```

---

## 2.7 Setup MySQL di Host untuk Menerima Koneksi Docker

### 🔧 Langkah 1: Edit Konfigurasi MySQL

```bash
# Edit file konfigurasi MySQL di host
sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf

# Cari baris: bind-address = 127.0.0.1
# Ubah menjadi: bind-address = 0.0.0.0

# Simpan (Ctrl+X, kemudian Y, Enter)

# Restart MySQL
sudo systemctl restart mysql
```

### 🔧 Langkah 2: Buat User MySQL untuk Docker

```bash
# Akses MySQL di host
mysql -u root -p

# Jalankan SQL berikut di MySQL prompt:
```

```sql
-- Buat user untuk CI4 (akses dari subnet Docker)
CREATE USER 'ci4_user'@'172.17.0.%' IDENTIFIED BY 'password_aman_anda';
GRANT ALL PRIVILEGES ON nama_database_ci4.* TO 'ci4_user'@'172.17.0.%';

-- Atau (alternatif: akses dari semua host - kurang aman)
CREATE USER 'ci4_user'@'%' IDENTIFIED BY 'password_aman_anda';
GRANT ALL PRIVILEGES ON nama_database_ci4.* TO 'ci4_user'@'%';

FLUSH PRIVILEGES;
```

---

## 2.8 Jalankan Container CodeIgniter 4

```bash
# Build dan jalankan
docker compose up -d --build

# Cek status container
docker compose ps

# Lihat log real-time
docker compose logs -f codeigniter4-app

# Test koneksi database dari dalam container
docker compose exec codeigniter4-app php -r "
    \$conn = new mysqli('host.docker.internal', 'ci4_user', 'password_aman_anda', 'nama_database_ci4');
    if (\$conn->connect_error) {
        die('❌ Gagal: ' . \$conn->connect_error);
    }
    echo '✅ Berhasil terhubung ke database!';
"
```

---

# 📋 Ringkasan & Referensi Cepat

## File-File yang Harus Dibuat (Checklist)

### Untuk Laravel:
- [ ] `Dockerfile` (di root)
- [ ] `docker-compose.yml` (di root)
- [ ] `docker/Caddyfile` (di folder docker/)
- [ ] `.env` (di root)
- [ ] `.dockerignore` (di root)
- [ ] `.gitignore` (pastikan `.env` tercakup)

### Untuk CodeIgniter 4:
- [ ] `Dockerfile` (di root)
- [ ] `docker-compose.yml` (di root)
- [ ] `docker/Caddyfile` (di folder docker/)
- [ ] `.env` (di root)
- [ ] `.dockerignore` (di root)
- [ ] `app/Config/Database.php` (sudah ada, cukup sesuaikan jika perlu)

---

## Perbandingan Konfigurasi

| Aspek | Laravel | CodeIgniter 4 |
|---|---|---|
| **Document Root** | `/app/public` | `/app/public` |
| **Writable Folder** | `/app/storage` & `/app/bootstrap/cache` | `/app/writable` |
| **DB Config** | `.env` | `.env` atau `app/Config/Database.php` |
| **DB Host (Docker)** | `host.docker.internal` | `host.docker.internal` |
| **Caddyfile Path** | `docker/Caddyfile` | `docker/Caddyfile` |

---

## Troubleshooting & Debug Commands

```bash
# Rebuild image setelah ada perubahan
docker compose up -d --build --force-recreate

# Masuk ke container
docker compose exec codeigniter4-app sh

# Lihat log
docker compose logs -f
docker compose logs -f --tail=50

# Test koneksi database
docker compose exec codeigniter4-app ping host.docker.internal

# Check PHP version & extensions
docker compose exec codeigniter4-app php -v
docker compose exec codeigniter4-app php -m | grep -i mysql

# Hanya stop container (jangan hapus)
docker compose stop

# Hapus semua (HATI-HATI!)
docker compose down -v
```

---

## 📘 Referensi Tambahan

- [FrankenPHP Official Docs](https://frankenphp.dev)
- [Laravel Octane Docs](https://laravel.com/docs/octane)
- [CodeIgniter 4 Docs](https://codeigniter.com/user_guide/index.html)
- [dunglas/frankenphp Docker Hub](https://hub.docker.com/r/dunglas/frankenphp)
- [Caddy Server Docs](https://caddyserver.com/docs/)
- [Docker Compose Reference](https://docs.docker.com/compose/compose-file/)

---

*Panduan ini dibuat untuk production-ready deployment. Selalu review dan sesuaikan konfigurasi dengan kebutuhan spesifik environment Anda sebelum deployment ke production.*
