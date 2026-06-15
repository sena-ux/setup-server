# 🐳 Panduan Lengkap: Docker + FrankenPHP untuk Aplikasi PHP
### (Laravel Octane & CodeIgniter | Koneksi Database Native Host)

> **Versi:** 1.0.0 | **Dibuat oleh:** Senior DevOps Engineer  
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

## 1.1 Struktur Direktori

Berikut adalah layout folder yang **ideal** untuk proyek Laravel dengan FrankenPHP:

```
laravel-app/                      # Root direktori proyek
├── app/                          # Core aplikasi Laravel
├── bootstrap/
│   └── app.php
├── config/
├── database/
├── public/
│   └── index.php
├── resources/
├── routes/
├── storage/
├── vendor/
│
├── docker/                       # ← Semua konfigurasi Docker disimpan di sini
│   └── Caddyfile                 # Konfigurasi web server Caddy (opsional, jika override)
│
├── .env                          # Environment variables Laravel
├── .env.example
├── artisan
├── composer.json
├── Dockerfile                    # ← Dockerfile untuk build image
└── docker-compose.yml            # ← Orkestrasi container
```

---

## 1.2 Dockerfile untuk Laravel Octane

```dockerfile
# =============================================================================
# Dockerfile - Laravel dengan FrankenPHP + Octane (Worker Mode)
# Base image: dunglas/frankenphp dengan Alpine Linux (ringan & aman)
# =============================================================================

FROM dunglas/frankenphp:latest-alpine AS base

# -----------------------------------------------------------------------------
# [LABEL] Metadata image untuk dokumentasi dan traceability
# -----------------------------------------------------------------------------
LABEL maintainer="devops@perusahaan.com"
LABEL description="Laravel Octane dengan FrankenPHP"

# -----------------------------------------------------------------------------
# [INSTALL DEPENDENCIES] Install library sistem yang dibutuhkan ekstensi PHP
# Alpine menggunakan apk sebagai package manager
# -----------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# [INSTALL PHP EXTENSIONS] Install ekstensi PHP yang dibutuhkan Laravel
# install-php-extensions adalah script bawaan image dunglas/frankenphp
# yang sangat memudahkan instalasi ekstensi tanpa compile manual
# -----------------------------------------------------------------------------
RUN install-php-extensions \
    # Internationalization - WAJIB untuk Laravel Octane
    intl \
    # Arbitrary precision math - dibutuhkan untuk kalkulasi keuangan
    bcmath \
    # Koneksi ke MySQL/MariaDB via PDO (lebih modern, direkomendasikan)
    pdo_mysql \
    # Koneksi MySQL via MySQLi (alternatif/legacy)
    mysqli \
    # Kompresi file ZIP
    zip \
    # Manipulasi gambar
    gd \
    # Ekstensi untuk Redis (caching & queue)
    redis \
    # OPcache untuk optimasi performa (caching bytecode PHP)
    opcache \
    # PCNTL - KRITIS untuk Laravel Octane Worker Mode
    # Mengizinkan PHP mengelola proses & signal handling
    pcntl \
    # Ekstensi string multibyte
    mbstring

# -----------------------------------------------------------------------------
# [OPCACHE CONFIGURATION] Optimasi performa PHP di production
# OPcache menyimpan compiled bytecode sehingga tidak perlu compile ulang
# -----------------------------------------------------------------------------
RUN echo "opcache.enable=1" >> /usr/local/etc/php/conf.d/opcache.ini && \
    echo "opcache.memory_consumption=256" >> /usr/local/etc/php/conf.d/opcache.ini && \
    echo "opcache.max_accelerated_files=20000" >> /usr/local/etc/php/conf.d/opcache.ini && \
    # Di production, matikan revalidasi file untuk performa maksimal
    echo "opcache.validate_timestamps=0" >> /usr/local/etc/php/conf.d/opcache.ini && \
    echo "opcache.save_comments=1" >> /usr/local/etc/php/conf.d/opcache.ini

# -----------------------------------------------------------------------------
# [COMPOSER] Install Composer (PHP package manager) langsung di container
# -----------------------------------------------------------------------------
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# -----------------------------------------------------------------------------
# [WORKING DIRECTORY] Set direktori kerja di dalam container
# -----------------------------------------------------------------------------
WORKDIR /app

# -----------------------------------------------------------------------------
# [COPY COMPOSER FILES FIRST] Teknik layer caching Docker:
# Salin composer.json & composer.lock duluan sebelum source code,
# sehingga `composer install` hanya dijalankan ulang jika dependencies berubah
# -----------------------------------------------------------------------------
COPY composer.json composer.lock ./

# Install dependencies PHP (tanpa dev dependencies untuk production)
# --no-scripts: hindari autorun script yang mungkin membutuhkan .env
RUN composer install \
    --no-dev \
    --no-scripts \
    --no-autoloader \
    --prefer-dist \
    --optimize-autoloader

# -----------------------------------------------------------------------------
# [COPY SOURCE CODE] Salin seluruh kode aplikasi ke container
# .dockerignore memastikan file tidak perlu (node_modules, .git) tidak ikut
# -----------------------------------------------------------------------------
COPY . .

# Generate optimized autoloader setelah semua file tersedia
RUN composer dump-autoload --optimize --no-dev

# -----------------------------------------------------------------------------
# [PERMISSION] Set permission yang benar untuk direktori storage Laravel
# www-data atau user frankenphp harus bisa write ke folder storage & cache
# -----------------------------------------------------------------------------
RUN chown -R www-data:www-data /app/storage /app/bootstrap/cache && \
    chmod -R 775 /app/storage /app/bootstrap/cache

# -----------------------------------------------------------------------------
# [HEALTH CHECK] Docker akan memeriksa kesehatan container secara berkala
# Jika health check gagal, container dianggap unhealthy
# -----------------------------------------------------------------------------
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost/up || exit 1

# -----------------------------------------------------------------------------
# [ENTRYPOINT] FrankenPHP dijalankan dalam mode worker untuk Octane
# Worker mode: PHP script di-load sekali dan menangani banyak request
# --worker flag mengaktifkan worker mode dengan entrypoint Octane
# -----------------------------------------------------------------------------
CMD ["frankenphp", "run", "--config", "/etc/caddy/Caddyfile"]
```

---

## 1.3 Docker Compose untuk Laravel

```yaml
# =============================================================================
# docker-compose.yml - Laravel + FrankenPHP + Octane
# Versi: Compose Specification (tanpa `version:` header, sudah deprecated)
# =============================================================================

services:

  # ---------------------------------------------------------------------------
  # SERVICE: laravel-app
  # Container utama yang menjalankan aplikasi Laravel dengan FrankenPHP Octane
  # ---------------------------------------------------------------------------
  laravel-app:
    # Build image dari Dockerfile di direktori saat ini
    build:
      context: .
      dockerfile: Dockerfile
      # Target stage jika menggunakan multi-stage build
      target: base

    # Nama container yang mudah diidentifikasi
    container_name: laravel_frankenphp

    # Restart policy: selalu restart jika container mati (kecuali dihentikan manual)
    restart: unless-stopped

    # -------------------------------------------------------------------------
    # [ENVIRONMENT VARIABLES] Override atau tambah env vars dari file .env
    # Laravel membaca file .env secara otomatis, tapi kita bisa override di sini
    # -------------------------------------------------------------------------
    env_file:
      - .env

    # -------------------------------------------------------------------------
    # [PORT MAPPING] Expose port dari container ke host
    # Format: "HOST_PORT:CONTAINER_PORT"
    # -------------------------------------------------------------------------
    ports:
      # HTTP - akses via http://localhost atau http://domain.com
      - "80:80"
      # HTTPS - FrankenPHP (Caddy) menangani SSL/TLS otomatis via Let's Encrypt
      - "443:443"
      # HTTP/3 (QUIC) - protokol modern untuk performa lebih baik
      - "443:443/udp"

    # -------------------------------------------------------------------------
    # [VOLUMES] Mount direktori untuk development atau persistent data
    # -------------------------------------------------------------------------
    volumes:
      # Mount storage Laravel agar file upload & log persisten
      - ./storage:/app/storage
      # Mount cache bootstrap agar tidak perlu generate ulang setiap restart
      - laravel_cache:/app/bootstrap/cache
      # Caddy data: menyimpan SSL certificates agar tidak perlu request ulang
      - caddy_data:/data
      # Caddy config: konfigurasi Caddy yang persisten
      - caddy_config:/config

    # -------------------------------------------------------------------------
    # [EXTRA HOSTS] ← INI ADALAH KUNCI KONEKSI KE DATABASE NATIVE DI HOST
    #
    # `host-gateway` adalah nilai spesial Docker yang secara otomatis
    # di-resolve ke IP gateway host (biasanya 172.17.0.1 atau sejenisnya).
    #
    # Dengan ini, dari dalam container Anda bisa menggunakan:
    #   - host.docker.internal → untuk akses ke MySQL di host
    #
    # Ini WAJIB ada agar koneksi database dari container ke host berfungsi!
    # -------------------------------------------------------------------------
    extra_hosts:
      - "host.docker.internal:host-gateway"

    # -------------------------------------------------------------------------
    # [ULIMITS] Tingkatkan batas file descriptor untuk handle banyak koneksi
    # Laravel Octane dengan banyak worker membutuhkan ini
    # -------------------------------------------------------------------------
    ulimits:
      nofile:
        soft: 65536
        hard: 65536

    # -------------------------------------------------------------------------
    # [LOGGING] Konfigurasi logging container
    # -------------------------------------------------------------------------
    logging:
      driver: "json-file"
      options:
        max-size: "10m"    # Maksimum ukuran file log
        max-file: "3"      # Jumlah file log yang disimpan (rotasi)

# =============================================================================
# [VOLUMES] Definisi named volumes untuk data persisten
# =============================================================================
volumes:
  laravel_cache:
    driver: local
  caddy_data:
    driver: local
  caddy_config:
    driver: local
```

---

## 1.4 Konfigurasi Caddyfile (Opsional - Override Default)

Jika Anda perlu mengkustomisasi behavior web server, buat file `docker/Caddyfile`:

```caddyfile
# =============================================================================
# Caddyfile - Konfigurasi Web Server untuk Laravel Octane
# FrankenPHP menggunakan Caddy sebagai web server di balik layar
# =============================================================================

{
    # Mode admin untuk management API Caddy (matikan di production jika tidak perlu)
    admin off
    
    # Aktifkan FrankenPHP
    frankenphp
    
    # Nonaktifkan email notifikasi Let's Encrypt saat development
    # Hapus baris ini di production dan isi dengan email asli
    email webmaster@example.com
}

# Konfigurasi untuk domain/port yang dilayani
# Ganti `localhost` dengan domain asli di production
localhost {
    # Gunakan FrankenPHP untuk handle request PHP
    # worker: aktifkan worker mode untuk Octane
    # num: jumlah worker process (sesuaikan dengan CPU cores)
    php_server {
        worker {
            file /app/public/index.php
            # Jumlah worker process - aturan umum: 2x jumlah CPU core
            num 4
        }
    }

    # Encode respons dengan gzip/zstd untuk kompres data
    encode zstd br gzip

    # Handle file static langsung tanpa PHP (lebih efisien)
    file_server

    # Header keamanan
    header {
        # Proteksi XSS
        X-Content-Type-Options nosniff
        X-Frame-Options DENY
        X-XSS-Protection "1; mode=block"
    }

    # Log akses untuk debugging
    log {
        output stderr
        format console
        level INFO
    }
}
```

---

## 1.5 Konfigurasi Laravel Octane

### Langkah 1: Install Package Octane

```bash
# Masuk ke container yang sedang berjalan
docker compose exec laravel-app bash

# Install package Laravel Octane
composer require laravel/octane

# Publish konfigurasi Octane
php artisan octane:install --server=frankenphp
```

### Langkah 2: Konfigurasi File `.env`

```dotenv
# =============================================================================
# .env - Konfigurasi Environment Laravel untuk Docker + FrankenPHP
# =============================================================================

APP_NAME="Nama Aplikasi Anda"
APP_ENV=production
APP_KEY=base64:GENERATE_DENGAN_php_artisan_key:generate
APP_DEBUG=false

# URL aplikasi - gunakan domain asli atau localhost
APP_URL=http://localhost

# =============================================================================
# OCTANE CONFIGURATION
# =============================================================================

# Server yang digunakan Octane (harus frankenphp karena kita pakai FrankenPHP)
OCTANE_SERVER=frankenphp

# Jumlah worker process - sesuaikan dengan CPU server
# Aturan umum: sama dengan jumlah CPU core atau 2x CPU core
OCTANE_WORKERS=4

# Jumlah request per worker sebelum worker di-restart (mencegah memory leak)
OCTANE_MAX_REQUESTS=500

# =============================================================================
# DATABASE - KONEKSI KE HOST NATIVE
# =============================================================================

DB_CONNECTION=mysql

# ⬇️ KUNCI UTAMA: Gunakan `host.docker.internal` bukan `localhost`
# `localhost` dari dalam container merujuk ke container itu sendiri (tidak ada DB di sana!)
# `host.docker.internal` di-resolve ke IP gateway host (tempat MySQL Anda berjalan)
DB_HOST=host.docker.internal

# Port MySQL default - sesuaikan jika Anda menggunakan port lain
DB_PORT=3306

# Nama database Anda
DB_DATABASE=nama_database_anda

# User MySQL yang memiliki akses dari luar localhost
# PENTING: User ini harus sudah diberi akses dari IP Docker (lihat catatan di bawah)
DB_USERNAME=laravel_user
DB_PASSWORD=password_aman_anda

# =============================================================================
# CACHE & SESSION - Gunakan Redis atau File
# =============================================================================
CACHE_DRIVER=redis
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis

# Jika Redis juga di host native, gunakan host.docker.internal
REDIS_HOST=host.docker.internal
REDIS_PASSWORD=null
REDIS_PORT=6379

# =============================================================================
# LOGGING
# =============================================================================
LOG_CHANNEL=stderr
LOG_LEVEL=warning
```

### Langkah 3: Konfigurasi MySQL di Host agar Menerima Koneksi Docker

```sql
-- Jalankan di MySQL server HOST (bukan di dalam container!)
-- Buat user yang bisa connect dari IP Docker (subnet default: 172.17.0.0/16)

-- Opsi 1: Izinkan dari subnet Docker (lebih aman)
CREATE USER 'laravel_user'@'172.17.0.%' IDENTIFIED BY 'password_aman_anda';
GRANT ALL PRIVILEGES ON nama_database_anda.* TO 'laravel_user'@'172.17.0.%';

-- Opsi 2: Izinkan dari semua host (kurang aman, gunakan hanya untuk development)
CREATE USER 'laravel_user'@'%' IDENTIFIED BY 'password_aman_anda';
GRANT ALL PRIVILEGES ON nama_database_anda.* TO 'laravel_user'@'%';

FLUSH PRIVILEGES;
```

```bash
# Edit konfigurasi MySQL di host agar mendengarkan semua interface
# (bukan hanya 127.0.0.1)

# Cari dan edit file konfigurasi MySQL:
sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf

# Ubah atau tambahkan:
# bind-address = 0.0.0.0
# (ganti dari 127.0.0.1 ke 0.0.0.0)

# Restart MySQL setelah perubahan:
sudo systemctl restart mysql
```

### Langkah 4: Jalankan Container

```bash
# Build dan jalankan semua service
docker compose up -d --build

# Jalankan migrasi database
docker compose exec laravel-app php artisan migrate --force

# Cache konfigurasi untuk performa production
docker compose exec laravel-app php artisan config:cache
docker compose exec laravel-app php artisan route:cache
docker compose exec laravel-app php artisan view:cache

# Cek status dan log
docker compose ps
docker compose logs -f laravel-app
```

---

---

# BAGIAN 2: CODEIGNITER (CI4 / CI3)

## 2.1 Struktur Direktori

### CodeIgniter 4 (CI4)

```
codeigniter4-app/                 # Root direktori proyek CI4
├── app/                          # Kode aplikasi (Controller, Model, Views)
│   ├── Controllers/
│   ├── Models/
│   ├── Views/
│   └── Config/
│       └── Database.php          # ← Konfigurasi database CI4
├── public/                       # ← Document Root (entry point web server)
│   ├── index.php                 # Entry point CI4
│   └── .htaccess
├── system/                       # Framework core CI4
├── vendor/                       # Dependencies Composer
├── writable/                     # Storage (logs, cache, uploads) - harus writable
│
├── .env                          # ← Environment variables CI4
├── composer.json
├── Dockerfile                    # ← Dockerfile untuk build image
└── docker-compose.yml            # ← Orkestrasi container
```

### CodeIgniter 3 (CI3)

```
codeigniter3-app/                 # Root direktori proyek CI3
├── application/                  # Kode aplikasi
│   ├── controllers/
│   ├── models/
│   ├── views/
│   └── config/
│       └── database.php          # ← Konfigurasi database CI3
├── system/                       # Framework core CI3
├── assets/                       # File statis (CSS, JS, images)
├── index.php                     # ← Entry point CI3 (ada di root!)
│
├── Dockerfile
└── docker-compose.yml
```

> 💡 **Perbedaan Utama CI3 vs CI4:**
> - **CI4**: Document Root ada di folder `/public` (seperti Laravel)
> - **CI3**: Document Root ada di **root folder** proyek (index.php ada di root)

---

## 2.2 Dockerfile untuk CodeIgniter 4

```dockerfile
# =============================================================================
# Dockerfile - CodeIgniter 4 dengan FrankenPHP
# Mode: Standard (bukan Worker Mode - CI4 tidak perlu Octane)
# =============================================================================

FROM dunglas/frankenphp:latest-alpine AS base

LABEL maintainer="devops@perusahaan.com"
LABEL description="CodeIgniter 4 dengan FrankenPHP"

# -----------------------------------------------------------------------------
# [INSTALL SYSTEM DEPENDENCIES]
# -----------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# [INSTALL PHP EXTENSIONS]
# Ekstensi yang dibutuhkan CodeIgniter 4
# -----------------------------------------------------------------------------
RUN install-php-extensions \
    # WAJIB: Internationalization untuk CI4
    intl \
    # Koneksi database via MySQLi (driver default CI4)
    mysqli \
    # Koneksi database via PDO (alternatif modern)
    pdo_mysql \
    # Kompresi ZIP
    zip \
    # Manipulasi gambar
    gd \
    # OPcache untuk performa
    opcache \
    # String multibyte
    mbstring \
    # XML processing
    xml \
    # JSON (biasanya sudah include, tapi explicit lebih aman)
    json \
    # Curl untuk HTTP request
    curl

# -----------------------------------------------------------------------------
# [PHP CONFIGURATION] Konfigurasi PHP untuk CI4
# -----------------------------------------------------------------------------
RUN echo "upload_max_filesize=32M" >> /usr/local/etc/php/conf.d/custom.ini && \
    echo "post_max_size=32M" >> /usr/local/etc/php/conf.d/custom.ini && \
    echo "memory_limit=256M" >> /usr/local/etc/php/conf.d/custom.ini && \
    echo "max_execution_time=60" >> /usr/local/etc/php/conf.d/custom.ini

# -----------------------------------------------------------------------------
# [OPCACHE CONFIGURATION]
# -----------------------------------------------------------------------------
RUN echo "opcache.enable=1" >> /usr/local/etc/php/conf.d/opcache.ini && \
    echo "opcache.memory_consumption=128" >> /usr/local/etc/php/conf.d/opcache.ini && \
    echo "opcache.max_accelerated_files=10000" >> /usr/local/etc/php/conf.d/opcache.ini && \
    echo "opcache.validate_timestamps=0" >> /usr/local/etc/php/conf.d/opcache.ini

# -----------------------------------------------------------------------------
# [COMPOSER]
# -----------------------------------------------------------------------------
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# -----------------------------------------------------------------------------
# [WORKING DIRECTORY]
# Set ke root proyek CI4 (bukan /public, itu diatur di web server config)
# -----------------------------------------------------------------------------
WORKDIR /app

# -----------------------------------------------------------------------------
# [INSTALL DEPENDENCIES]
# -----------------------------------------------------------------------------
COPY composer.json composer.lock ./
RUN composer install \
    --no-dev \
    --no-scripts \
    --no-autoloader \
    --prefer-dist \
    --optimize-autoloader

# -----------------------------------------------------------------------------
# [COPY SOURCE CODE]
# -----------------------------------------------------------------------------
COPY . .

# Generate autoloader
RUN composer dump-autoload --optimize --no-dev

# -----------------------------------------------------------------------------
# [PERMISSION] CI4 membutuhkan folder writable yang bisa ditulis
# Folder `writable` berisi logs, cache, session, dan upload temp
# -----------------------------------------------------------------------------
RUN chown -R www-data:www-data /app/writable && \
    chmod -R 775 /app/writable

# -----------------------------------------------------------------------------
# [HEALTH CHECK]
# -----------------------------------------------------------------------------
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

# -----------------------------------------------------------------------------
# [EXPOSE PORT] Port yang dibuka oleh FrankenPHP
# -----------------------------------------------------------------------------
EXPOSE 80 443

# -----------------------------------------------------------------------------
# [CMD] Jalankan FrankenPHP dalam mode standard (bukan worker/Octane)
# FrankenPHP akan otomatis serve PHP files di document root yang dikonfigurasi
# -----------------------------------------------------------------------------
CMD ["frankenphp", "run", "--config", "/etc/caddy/Caddyfile"]
```

---

## 2.3 Dockerfile untuk CodeIgniter 3

```dockerfile
# =============================================================================
# Dockerfile - CodeIgniter 3 dengan FrankenPHP
# Perbedaan utama dari CI4: Document Root adalah ROOT FOLDER (bukan /public)
# =============================================================================

FROM dunglas/frankenphp:latest-alpine AS base

LABEL maintainer="devops@perusahaan.com"
LABEL description="CodeIgniter 3 dengan FrankenPHP"

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

# Ekstensi untuk CI3 - mirip CI4 tapi tanpa beberapa ekstensi modern
RUN install-php-extensions \
    intl \
    mysqli \        
    pdo_mysql \
    zip \
    gd \
    opcache \
    mbstring \
    xml \
    curl

# Konfigurasi PHP
RUN echo "upload_max_filesize=32M" >> /usr/local/etc/php/conf.d/custom.ini && \
    echo "post_max_size=32M" >> /usr/local/etc/php/conf.d/custom.ini && \
    echo "memory_limit=128M" >> /usr/local/etc/php/conf.d/custom.ini

WORKDIR /app

# CI3 biasanya tidak menggunakan Composer, tapi jika menggunakannya:
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Salin seluruh proyek (termasuk index.php di root)
COPY . .

# Permission untuk folder application yang perlu ditulis
RUN chown -R www-data:www-data /app/application/logs \
    /app/application/cache && \
    chmod -R 775 /app/application/logs \
    /app/application/cache

HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

EXPOSE 80 443

CMD ["frankenphp", "run", "--config", "/etc/caddy/Caddyfile"]
```

---

## 2.4 Docker Compose untuk CodeIgniter 4

```yaml
# =============================================================================
# docker-compose.yml - CodeIgniter 4 + FrankenPHP
# =============================================================================

services:

  codeigniter4-app:
    build:
      context: .
      dockerfile: Dockerfile
      target: base

    container_name: ci4_frankenphp
    restart: unless-stopped

    env_file:
      - .env

    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"    # HTTP/3

    volumes:
      # Mount folder writable agar log & cache persisten di host
      - ./writable:/app/writable
      # SSL certificates Caddy (persisten agar tidak request ulang)
      - caddy_data:/data
      - caddy_config:/config

    # -------------------------------------------------------------------------
    # [EXTRA HOSTS] ← WAJIB untuk koneksi ke database native di host
    # Menambahkan entry ke /etc/hosts di dalam container:
    # host.docker.internal → IP gateway Docker (= IP host Anda)
    # -------------------------------------------------------------------------
    extra_hosts:
      - "host.docker.internal:host-gateway"

    # -------------------------------------------------------------------------
    # [ENVIRONMENT] Override env vars untuk database
    # Bisa juga diletakkan di file .env
    # -------------------------------------------------------------------------
    environment:
      # Override CI_ENVIRONMENT untuk production
      CI_ENVIRONMENT: production

    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

volumes:
  caddy_data:
    driver: local
  caddy_config:
    driver: local
```

---

## 2.5 Docker Compose untuk CodeIgniter 3

```yaml
# =============================================================================
# docker-compose.yml - CodeIgniter 3 + FrankenPHP
# Perbedaan: tidak ada folder writable standar seperti CI4
# =============================================================================

services:

  codeigniter3-app:
    build:
      context: .
      dockerfile: Dockerfile
      target: base

    container_name: ci3_frankenphp
    restart: unless-stopped

    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"

    volumes:
      # Mount folder log & cache aplikasi CI3
      - ./application/logs:/app/application/logs
      - ./application/cache:/app/application/cache
      # SSL certificates
      - caddy_data:/data
      - caddy_config:/config

    # ← WAJIB: Agar container bisa menjangkau database di host
    extra_hosts:
      - "host.docker.internal:host-gateway"

    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

volumes:
  caddy_data:
    driver: local
  caddy_config:
    driver: local
```

---

## 2.6 Konfigurasi Caddyfile untuk CodeIgniter

Buat file kustom Caddyfile yang disesuaikan dengan document root CI:

### Untuk CI4 (Document Root = `/app/public`)

```caddyfile
# =============================================================================
# Caddyfile untuk CodeIgniter 4
# Document Root: /app/public (folder public CI4)
# =============================================================================

{
    admin off
    frankenphp
}

# Tangani semua request di port 80 (dan 443 dengan auto-HTTPS)
:80 {
    # -------------------------------------------------------------------------
    # [ROOT] Tentukan document root ke folder /public CI4
    # INI SANGAT PENTING - tanpa ini, FrankenPHP akan serve dari /app
    # yang akan mengekspos file sensitif seperti .env!
    # -------------------------------------------------------------------------
    root * /app/public

    # Aktifkan FrankenPHP untuk proses PHP
    php_server

    # Encode response
    encode zstd br gzip

    # Serve file statis jika ada
    file_server

    # -------------------------------------------------------------------------
    # [REWRITE] Arahkan semua request yang bukan file/folder ke index.php
    # Ini meniru fungsi .htaccess RewriteEngine CI4
    # -------------------------------------------------------------------------
    try_files {path} {path}/ /index.php?{query}

    log {
        output stderr
        format console
        level INFO
    }
}
```

### Untuk CI3 (Document Root = `/app` - Root Folder)

```caddyfile
# =============================================================================
# Caddyfile untuk CodeIgniter 3
# Document Root: /app (root folder proyek, karena index.php ada di root)
# =============================================================================

{
    admin off
    frankenphp
}

:80 {
    # Document root CI3 adalah ROOT folder proyek
    root * /app

    php_server

    encode zstd br gzip

    file_server

    # Rewrite untuk CI3 - arahkan ke index.php
    try_files {path} {path}/ /index.php?{query}

    # -------------------------------------------------------------------------
    # [SECURITY] Blokir akses ke folder sensitif CI3
    # Tanpa ini, folder application/ bisa diakses via browser!
    # -------------------------------------------------------------------------
    @sensitive_dirs {
        path /application/*
        path /system/*
        path /.env
        path /.git/*
    }
    respond @sensitive_dirs 403

    log {
        output stderr
        format console
        level INFO
    }
}
```

---

## 2.7 Konfigurasi Database CodeIgniter

### CI4: File `.env`

```dotenv
# =============================================================================
# .env - Konfigurasi Environment CodeIgniter 4
# File ini TIDAK boleh di-commit ke repository! Tambahkan ke .gitignore
# =============================================================================

# Mode aplikasi
CI_ENVIRONMENT = production

# =============================================================================
# DATABASE CONFIGURATION
# Koneksi ke MySQL/MariaDB yang berjalan NATIVE di host server
# =============================================================================

# ⬇️ Gunakan `host.docker.internal` - ini akan di-resolve ke IP host
# Pastikan extra_hosts sudah dikonfigurasi di docker-compose.yml
database.default.hostname = host.docker.internal

# Port MySQL default
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
```

### CI4: File `app/Config/Database.php` (Alternatif atau Fallback)

```php
<?php

namespace Config;

use CodeIgniter\Database\Config;

/**
 * =============================================================================
 * Database Configuration - CodeIgniter 4
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
        'pConnect' => false,         // Persistent connection (biasanya false)
        'DBDebug'  => false,         // MATIKAN di production!
        'charset'  => 'utf8mb4',     // Charset modern yang mendukung emoji
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
     * Hanya digunakan saat CI_ENVIRONMENT = testing
     */
    public array $tests = [
        'hostname' => 'host.docker.internal',
        'username' => 'ci4_test_user',
        'password' => 'password_test',
        'database' => 'nama_database_ci4_test',
        'DBDriver' => 'MySQLi',
        'DBPrefix' => '',
        'DBDebug'  => true,   // Aktifkan untuk testing
        'port'     => 3306,
    ];
}
```

---

### CI3: File `application/config/database.php`

```php
<?php

/**
 * =============================================================================
 * Database Configuration - CodeIgniter 3
 *
 * Dokumentasi: https://codeigniter.com/userguide3/database/configuration.html
 * =============================================================================
 */

defined('BASEPATH') or exit('No direct script access allowed');

$active_group = 'default';
$query_builder = TRUE;

$db['default'] = array(
    // -------------------------------------------------------------------------
    // [HOSTNAME] Koneksi ke database native di host server
    //
    // ⚠️ JANGAN gunakan `localhost` atau `127.0.0.1` dari dalam container!
    //    Keduanya merujuk ke container itu sendiri, bukan ke host server.
    //
    // ✅ GUNAKAN `host.docker.internal` yang di-resolve ke IP gateway host.
    //    Pastikan `extra_hosts: host.docker.internal:host-gateway` ada di
    //    docker-compose.yml Anda!
    // -------------------------------------------------------------------------
    'hostname' => 'host.docker.internal',

    // User MySQL dengan akses dari IP Docker (misal: 172.17.0.%)
    'username' => 'ci3_user',

    // Password database
    'password' => 'password_aman_anda',

    // Nama database
    'database' => 'nama_database_ci3',

    // -------------------------------------------------------------------------
    // [DBDRIVER] Driver koneksi database
    // `mysqli` direkomendasikan untuk MySQL 5.x+ / MariaDB
    // Alternatif: `pdo` dengan DSN `mysql:host=...`
    // -------------------------------------------------------------------------
    'dbdriver' => 'mysqli',

    'dbprefix' => '',           // Prefix tabel, kosongkan jika tidak digunakan
    'pconnect' => FALSE,        // Persistent connection
    'db_debug' => FALSE,        // MATIKAN di production untuk keamanan!
    'cache_on' => FALSE,        // Query caching
    'cachedir' => '',
    'char_set' => 'utf8mb4',   // Gunakan utf8mb4 untuk dukungan karakter lengkap
    'dbcollat' => 'utf8mb4_general_ci',
    'swap_pre' => '',
    'encrypt'  => FALSE,        // SSL enkripsi
    'compress' => FALSE,        // Kompresi koneksi
    'stricton' => FALSE,        // MySQL Strict Mode
    'failover' => array(),      // Failover database server
    'save_queries' => FALSE,    // Simpan semua query (aktifkan hanya untuk debug)
    'port' => 3306,             // Port MySQL default
);

/* End of file database.php */
/* Location: ./application/config/database.php */
```

### Langkah Jalankan Container CodeIgniter

```bash
# Build dan jalankan
docker compose up -d --build

# Cek status container
docker compose ps

# Lihat log real-time
docker compose logs -f codeigniter4-app

# Test koneksi database dari dalam container
docker compose exec codeigniter4-app php -r "
    \$conn = new mysqli('host.docker.internal', 'ci4_user', 'password', 'nama_database');
    if (\$conn->connect_error) {
        die('Gagal: ' . \$conn->connect_error);
    }
    echo 'Berhasil terhubung ke database!';
"
```

---

---

# 📋 Ringkasan & Referensi Cepat

## Perbandingan Konfigurasi

| Aspek | Laravel Octane | CodeIgniter 4 | CodeIgniter 3 |
|---|---|---|---|
| **Worker Mode** | ✅ Ya (Octane) | ❌ Tidak | ❌ Tidak |
| **Document Root** | `/app/public` | `/app/public` | `/app` (root) |
| **Ext. Wajib** | `intl, pcntl, pdo_mysql, bcmath` | `intl, mysqli, pdo_mysql` | `intl, mysqli` |
| **Config DB** | `.env` | `.env` atau `Config/Database.php` | `application/config/database.php` |
| **DB Host** | `host.docker.internal` | `host.docker.internal` | `host.docker.internal` |

## Checklist Deployment

- [ ] MySQL di host dikonfigurasi untuk menerima koneksi dari `172.17.0.%`
- [ ] `bind-address = 0.0.0.0` sudah diset di `mysqld.cnf`
- [ ] `extra_hosts: host.docker.internal:host-gateway` ada di `docker-compose.yml`
- [ ] `.env` menggunakan `host.docker.internal` sebagai `DB_HOST`
- [ ] Folder storage/writable memiliki permission `775` dan owner `www-data`
- [ ] File `.env` dan `vendor/` ada di `.dockerignore`
- [ ] Port 80 dan 443 tidak digunakan oleh proses lain di host

## File `.dockerignore` (Wajib Ada!)

```dockerignore
# =============================================================================
# .dockerignore - File/folder yang TIDAK ikut dalam Docker build context
# Ini mempercepat build dan mengurangi ukuran image
# =============================================================================

# Git
.git
.gitignore

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
writable/logs/*
writable/cache/*

# Testing
tests/
.phpunit.result.cache
phpunit.xml

# Development tools
.editorconfig
.php-cs-fixer.php
phpstan.neon

# Docker files (tidak perlu ada di dalam image)
docker-compose*.yml
Dockerfile*
docker/

# OS
.DS_Store
Thumbs.db
```

---

## 🛠️ Perintah Berguna

```bash
# Rebuild image setelah ada perubahan Dockerfile
docker compose up -d --build --force-recreate

# Masuk ke dalam container untuk debugging
docker compose exec laravel-app bash
docker compose exec codeigniter4-app sh    # Alpine menggunakan sh bukan bash

# Lihat log container
docker compose logs -f
docker compose logs -f laravel-app --tail=100

# Cek penggunaan resource
docker stats

# Hapus semua container, network, dan volume (HATI-HATI!)
docker compose down -v

# Hanya hentikan container tanpa hapus
docker compose stop

# Cek koneksi database dari dalam container
docker compose exec laravel-app php artisan db:show

# Test ping ke host dari dalam container
docker compose exec laravel-app ping host.docker.internal
```

---

> 📘 **Referensi Tambahan:**
> - [FrankenPHP Official Docs](https://frankenphp.dev)
> - [Laravel Octane Docs](https://laravel.com/docs/octane)
> - [CodeIgniter 4 Docs](https://codeigniter.com/user_guide/index.html)
> - [dunglas/frankenphp Docker Hub](https://hub.docker.com/r/dunglas/frankenphp)
> - [Caddy Server Docs](https://caddyserver.com/docs/)

---

*Panduan ini dibuat untuk production-ready deployment. Selalu review dan sesuaikan konfigurasi dengan kebutuhan spesifik environment Anda sebelum deployment ke production.*
