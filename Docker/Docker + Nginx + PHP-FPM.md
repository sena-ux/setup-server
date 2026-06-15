# Panduan Teknis: Docker Multi-Container untuk Aplikasi PHP
## Arsitektur Nginx + PHP-FPM dengan Native Database di Host

> **Target Audience:** DevOps / Backend Developer  
> **Stack:** Docker, Nginx, PHP-FPM, Laravel / CodeIgniter  
> **Database:** MySQL / PostgreSQL terinstal native di host OS (di luar Docker)

---

## Konsep Arsitektur

```
┌─────────────────────────────────────────────────────┐
│                    HOST SERVER                      │
│                                                     │
│  ┌──────────────────────────────────────────────┐  │
│  │           DOCKER NETWORK (bridge)            │  │
│  │                                              │  │
│  │  ┌─────────────┐      ┌──────────────────┐  │  │
│  │  │    NGINX    │─────▶│    PHP-FPM       │  │  │
│  │  │  :80 / :443 │FastCGI│  php:8.2-fpm    │  │  │
│  │  └─────────────┘      └────────┬─────────┘  │  │
│  └───────────────────────────────┼─────────────┘  │
│                                   │                 │
│  ┌────────────────────────────────▼─────────────┐  │
│  │        DATABASE NATIVE (MySQL / PostgreSQL)  │  │
│  │        Accessible via host.docker.internal   │  │
│  └──────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

**Aliran request:**
`Client → Nginx (port 80) → FastCGI → PHP-FPM → Database (host native)`

---

---

# BAGIAN 1: ARSITEKTUR UNTUK LARAVEL

---

## Step 1 — Struktur Direktori

```
laravel-docker/
│
├── docker/
│   ├── nginx/
│   │   └── default.conf          # Konfigurasi virtual host Nginx
│   └── php/
│       └── Dockerfile            # Image PHP-FPM custom
│
├── src/                          # Root project Laravel (hasil clone / composer create)
│   ├── app/
│   ├── bootstrap/
│   ├── config/
│   ├── database/
│   ├── public/                   # ◀ Document root Nginx diarahkan ke sini
│   │   └── index.php
│   ├── resources/
│   ├── routes/
│   ├── storage/
│   ├── vendor/
│   ├── .env                      # Konfigurasi Laravel (DB, APP_KEY, dll)
│   └── composer.json
│
├── docker-compose.yml            # Orkestrasi multi-container
└── .env                          # Variabel Docker Compose (port, path, dll)
```

> **Konvensi:** Kode Laravel dipisah ke folder `src/` agar konfigurasi Docker di root tetap bersih dan tidak bercampur.

---

## Step 2 — Dockerfile PHP-FPM

**File:** `docker/php/Dockerfile`

```dockerfile
# ============================================================
# Stage 1: Base PHP-FPM Alpine
# ============================================================
FROM php:8.2-fpm-alpine

# Labels metadata
LABEL maintainer="devops@yourdomain.com"
LABEL description="PHP-FPM 8.2 for Laravel production"

# ============================================================
# Install system dependencies
# ============================================================
RUN apk add --no-cache \
    # Build tools
    autoconf \
    gcc \
    g++ \
    make \
    # Libraries untuk ekstensi PHP
    libpng-dev \
    libjpeg-turbo-dev \
    libwebp-dev \
    freetype-dev \
    libzip-dev \
    icu-dev \
    oniguruma-dev \
    libxml2-dev \
    curl-dev \
    # Utilities
    curl \
    unzip \
    git \
    bash

# ============================================================
# Konfigurasi dan install ekstensi PHP
# ============================================================

# GD (untuk image processing)
RUN docker-php-ext-configure gd \
    --with-freetype \
    --with-jpeg \
    --with-webp

# Install semua ekstensi yang dibutuhkan Laravel
RUN docker-php-ext-install \
    pdo \
    pdo_mysql \
    pdo_pgsql \        
    pgsql \            
    mbstring \
    exif \
    pcntl \
    bcmath \
    gd \
    zip \
    intl \
    opcache \
    xml \
    curl \
    fileinfo \
    tokenizer \
    ctype \
    json \
    session

# Install Redis extension via PECL
RUN pecl install redis \
    && docker-php-ext-enable redis

# ============================================================
# PHP-FPM & OPcache konfigurasi (production-tuned)
# ============================================================
COPY <<'EOF' /usr/local/etc/php/conf.d/custom.ini
; ---- Security ----
expose_php = Off

; ---- Performance ----
memory_limit = 256M
max_execution_time = 60
upload_max_filesize = 50M
post_max_size = 55M

; ---- OPcache (production) ----
opcache.enable = 1
opcache.memory_consumption = 128
opcache.interned_strings_buffer = 8
opcache.max_accelerated_files = 10000
opcache.revalidate_freq = 0
opcache.validate_timestamps = 0
opcache.fast_shutdown = 1
EOF

# ============================================================
# Install Composer
# ============================================================
COPY --from=composer:2.7 /usr/bin/composer /usr/bin/composer

# ============================================================
# Setup aplikasi
# ============================================================
WORKDIR /var/www/html

# Copy kode Laravel
COPY ./src .

# Install dependencies (tanpa dev, optimized untuk production)
RUN composer install \
    --no-dev \
    --optimize-autoloader \
    --no-interaction \
    --no-progress

# Set permission yang benar untuk Laravel
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html/storage \
    && chmod -R 755 /var/www/html/bootstrap/cache

# Jalankan sebagai user www-data (non-root, best practice)
USER www-data

EXPOSE 9000

CMD ["php-fpm"]
```

> **Catatan `pdo_pgsql` & `pgsql`:** Hapus baris tersebut jika Anda hanya menggunakan MySQL.

---

## Step 3 — Konfigurasi Nginx

**File:** `docker/nginx/default.conf`

```nginx
# ============================================================
# Nginx Virtual Host — Laravel Application
# ============================================================

server {
    listen 80;
    server_name _;                        # Tangkap semua hostname
    root /var/www/html/public;            # ◀ Root Laravel adalah /public

    index index.php index.html;

    # ---- Logging ----
    access_log /var/log/nginx/access.log;
    error_log  /var/log/nginx/error.log warn;

    # ---- Ukuran upload ----
    client_max_body_size 55M;

    # ---- Security Headers ----
    add_header X-Frame-Options "SAMEORIGIN"            always;
    add_header X-Content-Type-Options "nosniff"        always;
    add_header X-XSS-Protection "1; mode=block"        always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # ---- Sembunyikan versi Nginx ----
    server_tokens off;

    # ================================================================
    # URL Rewriting — Inti dari konfigurasi Laravel
    # Semua request yang bukan file/folder nyata → diteruskan ke index.php
    # ================================================================
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    # ================================================================
    # PHP-FPM FastCGI Passthrough
    # Request .php diteruskan ke container php-fpm via socket TCP
    # ================================================================
    location ~ \.php$ {
        # Keamanan: blokir .php di dalam upload
        try_files $uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;

        # "php-fpm" adalah nama service di docker-compose.yml
        # Port 9000 adalah default PHP-FPM
        fastcgi_pass   php-fpm:9000;
        fastcgi_index  index.php;

        # FastCGI parameters standar
        include        fastcgi_params;
        fastcgi_param  SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        fastcgi_param  PATH_INFO       $fastcgi_path_info;
        fastcgi_param  SERVER_NAME     $host;

        # Timeout untuk request yang lama (misal: export data besar)
        fastcgi_read_timeout 300;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;

        # Buffer tuning
        fastcgi_buffer_size          128k;
        fastcgi_buffers              4 256k;
        fastcgi_busy_buffers_size    256k;
    }

    # ================================================================
    # Cache static assets
    # ================================================================
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # ---- Blokir akses ke file sensitif ----
    location ~ /\.(?!well-known).* {
        deny all;
    }

    location ~ /\.(env|git|htaccess) {
        deny all;
        return 404;
    }
}
```

---

## Step 4 — Docker Compose & Environment

### `docker-compose.yml`

```yaml
# ============================================================
# Docker Compose — Laravel Multi-Container
# Versi: Compose V2 (tanpa "version" key, sudah deprecated)
# ============================================================

services:

  # ----------------------------------------------------------
  # Service 1: Nginx (Web Server / Reverse Proxy)
  # ----------------------------------------------------------
  nginx:
    image: nginx:1.25-alpine
    container_name: laravel_nginx
    restart: unless-stopped
    ports:
      - "${NGINX_PORT:-80}:80"        # HTTP
      # - "${NGINX_SSL_PORT:-443}:443" # HTTPS (aktifkan jika pakai SSL)
    volumes:
      # Mount kode aplikasi (read-only untuk Nginx)
      - ./src:/var/www/html:ro
      # Mount konfigurasi Nginx
      - ./docker/nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
      # Mount log (opsional, untuk debugging)
      - ./logs/nginx:/var/log/nginx
    depends_on:
      php-fpm:
        condition: service_healthy
    networks:
      - app-network
    # ◀ Kunci: agar Nginx bisa di-reach dari luar Docker
    extra_hosts:
      - "host.docker.internal:host-gateway"

  # ----------------------------------------------------------
  # Service 2: PHP-FPM (Application Server)
  # ----------------------------------------------------------
  php-fpm:
    build:
      context: .
      dockerfile: ./docker/php/Dockerfile
    container_name: laravel_phpfpm
    restart: unless-stopped
    volumes:
      # Mount kode aplikasi (read-write untuk PHP)
      - ./src:/var/www/html
      # Mount log PHP (opsional)
      - ./logs/php:/var/log/php
    environment:
      # Teruskan variabel dari .env ke dalam container
      - APP_ENV=${APP_ENV:-production}
      - APP_DEBUG=${APP_DEBUG:-false}
    networks:
      - app-network
    # ◀ Kunci utama: akses ke database native di host OS
    extra_hosts:
      - "host.docker.internal:host-gateway"
    healthcheck:
      test: ["CMD", "php-fpm", "-t"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

# ----------------------------------------------------------
# Network
# ----------------------------------------------------------
networks:
  app-network:
    driver: bridge
    name: laravel_network
```

---

### `.env` — Variabel Docker Compose

**File:** `.env` (root project, di sebelah `docker-compose.yml`)

```dotenv
# ============================================================
# Docker Compose Environment Variables
# ============================================================

# Port yang di-expose Nginx ke host
NGINX_PORT=80
NGINX_SSL_PORT=443

# Environment aplikasi
APP_ENV=production
APP_DEBUG=false
```

---

### `.env` — Konfigurasi Laravel

**File:** `src/.env` (di dalam folder Laravel)

```dotenv
# ============================================================
# Laravel Application Environment
# ============================================================

APP_NAME="MyApp"
APP_ENV=production
APP_KEY=base64:GENERATE_WITH_php_artisan_key_generate
APP_DEBUG=false
APP_URL=http://yourdomain.com

LOG_CHANNEL=stack
LOG_LEVEL=error

# ============================================================
# Database — Koneksi ke MySQL NATIVE di Host OS
# ============================================================
# PENTING: Gunakan "host.docker.internal" bukan "localhost" atau "127.0.0.1"
# Karena dari dalam container, localhost = container itu sendiri
# host.docker.internal = IP gateway ke host machine

DB_CONNECTION=mysql
DB_HOST=host.docker.internal      # ◀ Kunci koneksi ke host
DB_PORT=3306
DB_DATABASE=nama_database_anda
DB_USERNAME=user_database_anda
DB_PASSWORD=password_database_anda

# Jika menggunakan PostgreSQL, ganti dengan:
# DB_CONNECTION=pgsql
# DB_HOST=host.docker.internal
# DB_PORT=5432
# DB_DATABASE=nama_database
# DB_USERNAME=postgres
# DB_PASSWORD=password

# ============================================================
# Cache & Session
# ============================================================
CACHE_DRIVER=file
SESSION_DRIVER=file
QUEUE_CONNECTION=sync

# Jika menggunakan Redis native di host:
# REDIS_HOST=host.docker.internal
# REDIS_PORT=6379
```

---

## Konfigurasi Database Host untuk Laravel

Agar container dapat terhubung ke database native di host, database harus dikonfigurasi untuk menerima koneksi dari IP selain `localhost`.

### MySQL — Izinkan Koneksi dari Docker

```sql
-- Jalankan di MySQL host sebagai root
-- Ganti 'user_laravel' dan 'password_kuat' sesuai kebutuhan

CREATE USER 'user_laravel'@'172.%.%.%' IDENTIFIED BY 'password_kuat';
GRANT ALL PRIVILEGES ON nama_database.* TO 'user_laravel'@'172.%.%.%';
FLUSH PRIVILEGES;

-- Atau izinkan dari semua IP (hanya untuk development):
-- CREATE USER 'user_laravel'@'%' IDENTIFIED BY 'password_kuat';
```

Pastikan MySQL listen di semua interface, bukan hanya `127.0.0.1`:

```ini
# /etc/mysql/mysql.conf.d/mysqld.cnf (Ubuntu/Debian)
# /etc/my.cnf (CentOS/RHEL)

[mysqld]
bind-address = 0.0.0.0    # Dengarkan di semua interface
```

Restart MySQL: `sudo systemctl restart mysql`

### PostgreSQL — Izinkan Koneksi dari Docker

```bash
# Edit pg_hba.conf (lokasi bergantung distro):
# Ubuntu: /etc/postgresql/15/main/pg_hba.conf

# Tambahkan baris berikut (izinkan subnet Docker default):
host    nama_database    user_laravel    172.17.0.0/16    md5
```

```ini
# Edit postgresql.conf:
listen_addresses = '*'    # atau '0.0.0.0'
```

Restart: `sudo systemctl restart postgresql`

---

## Deployment Commands — Laravel

```bash
# 1. Clone repo dan masuk ke direktori
git clone https://github.com/yourrepo/laravel-app.git laravel-docker
cd laravel-docker

# 2. Copy dan edit environment files
cp src/.env.example src/.env
nano src/.env    # ← isi DB_HOST=host.docker.internal, dll

# 3. Build dan jalankan container
docker compose up -d --build

# 4. Generate app key
docker exec laravel_phpfpm php artisan key:generate

# 5. Jalankan migrasi (database harus sudah ada dan bisa diakses)
docker exec laravel_phpfpm php artisan migrate --force

# 6. Jalankan seeder (jika diperlukan)
docker exec laravel_phpfpm php artisan db:seed --force

# 7. Optimasi untuk production
docker exec laravel_phpfpm php artisan config:cache
docker exec laravel_phpfpm php artisan route:cache
docker exec laravel_phpfpm php artisan view:cache

# 8. Cek status container
docker compose ps

# 9. Lihat log real-time
docker compose logs -f
```

---

---

# BAGIAN 2: ARSITEKTUR UNTUK CODEIGNITER

---

## Catatan Perbedaan CI3 vs CI4

| Aspek | CodeIgniter 3 (CI3) | CodeIgniter 4 (CI4) |
|---|---|---|
| Document Root Nginx | `/var/www/html` (root project) | `/var/www/html/public` |
| Entry Point | `index.php` di root | `index.php` di `/public` |
| URL Rewriting | Perlu hapus `index.php` dari URL | Sama, via `.htaccess` / Nginx |
| Config Database | `application/config/database.php` | `.env` atau `app/Config/Database.php` |
| PHP Minimum | 5.6+ | 7.4+ (Rekomendasi 8.1+) |

---

## Step 1 — Struktur Direktori

### CodeIgniter 4

```
ci4-docker/
│
├── docker/
│   ├── nginx/
│   │   └── default.conf          # Konfigurasi Nginx untuk CI4
│   └── php/
│       └── Dockerfile            # Image PHP-FPM untuk CI4
│
├── src/                          # Root project CI4
│   ├── app/
│   │   ├── Config/
│   │   │   └── Database.php      # Konfigurasi database CI4
│   │   ├── Controllers/
│   │   ├── Models/
│   │   └── Views/
│   ├── public/                   # ◀ Document root Nginx (sama seperti Laravel)
│   │   ├── index.php
│   │   └── .htaccess
│   ├── system/
│   ├── writable/                 # Storage (logs, cache, sessions)
│   ├── vendor/
│   └── .env                      # Konfigurasi CI4 environment
│
├── docker-compose.yml
└── .env
```

### CodeIgniter 3

```
ci3-docker/
│
├── docker/
│   ├── nginx/
│   │   └── default.conf          # Konfigurasi Nginx untuk CI3
│   └── php/
│       └── Dockerfile
│
├── src/                          # Root project CI3
│   ├── application/
│   │   ├── config/
│   │   │   ├── config.php
│   │   │   └── database.php      # ◀ Konfigurasi database CI3
│   │   ├── controllers/
│   │   ├── models/
│   │   └── views/
│   ├── system/
│   ├── index.php                 # ◀ Entry point CI3 (di root, bukan /public)
│   └── .htaccess
│
├── docker-compose.yml
└── .env
```

---

## Step 2 — Konfigurasi Nginx

### `default.conf` untuk CodeIgniter 4

**File:** `docker/nginx/default.conf`

```nginx
# ============================================================
# Nginx Virtual Host — CodeIgniter 4
# Document root: /var/www/html/public (sama dengan Laravel)
# ============================================================

server {
    listen 80;
    server_name _;
    root /var/www/html/public;        # ◀ CI4 juga menggunakan /public

    index index.php index.html;

    access_log /var/log/nginx/access.log;
    error_log  /var/log/nginx/error.log warn;

    client_max_body_size 50M;
    server_tokens off;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN"    always;
    add_header X-Content-Type-Options "nosniff" always;

    # ================================================================
    # URL Rewriting untuk CI4
    # ================================================================
    location / {
        try_files $uri $uri/ /index.php$is_args$args;
    }

    # ================================================================
    # PHP-FPM FastCGI Passthrough
    # ================================================================
    location ~ \.php$ {
        try_files $uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;

        fastcgi_pass  php-fpm:9000;   # Nama service di docker-compose
        fastcgi_index index.php;

        include       fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        fastcgi_param PATH_INFO       $fastcgi_path_info;

        fastcgi_read_timeout 120;
    }

    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
        expires 30d;
        add_header Cache-Control "public";
        access_log off;
    }

    # Blokir akses ke folder sensitif CI4
    location ~ ^/(app|system|writable|vendor)/ {
        deny all;
        return 403;
    }

    # Blokir file dot dan env
    location ~ /\.(env|git|htaccess) {
        deny all;
        return 404;
    }
}
```

---

### `default.conf` untuk CodeIgniter 3

**File:** `docker/nginx/default.conf`

```nginx
# ============================================================
# Nginx Virtual Host — CodeIgniter 3
# PERBEDAAN UTAMA: Document root = root project (BUKAN /public)
# ============================================================

server {
    listen 80;
    server_name _;
    root /var/www/html;               # ◀ CI3: root project langsung (tidak ada /public)

    index index.php index.html;

    access_log /var/log/nginx/access.log;
    error_log  /var/log/nginx/error.log warn;

    client_max_body_size 50M;
    server_tokens off;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN"    always;
    add_header X-Content-Type-Options "nosniff" always;

    # ================================================================
    # URL Rewriting untuk CI3
    # Menghapus "index.php" dari URL (clean URL)
    # ================================================================
    location / {
        try_files $uri $uri/ /index.php?/$request_uri;
    }

    # ================================================================
    # PHP-FPM FastCGI Passthrough
    # ================================================================
    location ~ \.php$ {
        try_files $uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;

        fastcgi_pass  php-fpm:9000;
        fastcgi_index index.php;

        include       fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        fastcgi_param PATH_INFO       $fastcgi_path_info;

        fastcgi_read_timeout 120;
    }

    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 30d;
        add_header Cache-Control "public";
        access_log off;
    }

    # ================================================================
    # PENTING: Blokir akses langsung ke folder sensitif CI3
    # ================================================================
    location ~ ^/(application|system|vendor)/ {
        deny all;
        return 403;
    }

    # Blokir file sensitif
    location ~ /\.(git|htaccess|env) {
        deny all;
        return 404;
    }

    # Blokir akses ke file config
    location ~* /application/config/ {
        deny all;
        return 403;
    }
}
```

---

## Step 3 — Docker Compose untuk CodeIgniter

### `docker-compose.yml`

```yaml
# ============================================================
# Docker Compose — CodeIgniter (CI3 / CI4)
# ============================================================

services:

  # ----------------------------------------------------------
  # Service 1: Nginx
  # ----------------------------------------------------------
  nginx:
    image: nginx:1.25-alpine
    container_name: ci_nginx
    restart: unless-stopped
    ports:
      - "${NGINX_PORT:-80}:80"
    volumes:
      - ./src:/var/www/html:ro
      - ./docker/nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
      - ./logs/nginx:/var/log/nginx
    depends_on:
      - php-fpm
    networks:
      - app-network
    extra_hosts:
      - "host.docker.internal:host-gateway"

  # ----------------------------------------------------------
  # Service 2: PHP-FPM
  # ----------------------------------------------------------
  php-fpm:
    build:
      context: .
      dockerfile: ./docker/php/Dockerfile
    container_name: ci_phpfpm
    restart: unless-stopped
    volumes:
      - ./src:/var/www/html
      - ./logs/php:/var/log/php
    networks:
      - app-network
    # ◀ Kunci: akses ke database native di host OS
    extra_hosts:
      - "host.docker.internal:host-gateway"

networks:
  app-network:
    driver: bridge
    name: ci_network
```

---

## Step 4 — Konfigurasi Database di CodeIgniter

### CodeIgniter 4 — via `.env`

**File:** `src/.env`

```dotenv
# ============================================================
# CodeIgniter 4 Environment
# ============================================================

CI_ENVIRONMENT = production

# ============================================================
# Database — Koneksi ke Host Native
# ============================================================
# Gunakan host.docker.internal, BUKAN localhost atau 127.0.0.1

database.default.hostname = host.docker.internal
database.default.database = nama_database_ci4
database.default.username = user_ci4
database.default.password = password_ci4
database.default.DBDriver = MySQLi
database.default.DBPrefix =
database.default.port     = 3306

# Untuk PostgreSQL:
# database.default.DBDriver = Postgre
# database.default.port     = 5432

# App config
app.baseURL = 'http://yourdomain.com/'
app.indexPage = ''
```

---

### CodeIgniter 4 — via `app/Config/Database.php`

**File:** `src/app/Config/Database.php`

```php
<?php

namespace Config;

use CodeIgniter\Database\Config;

class Database extends Config
{
    public string $defaultGroup = 'default';

    public array $default = [
        'DSN'          => '',
        // ◀ host.docker.internal = IP host server dari dalam container
        'hostname'     => 'host.docker.internal',
        'username'     => 'user_ci4',
        'password'     => 'password_ci4',
        'database'     => 'nama_database_ci4',
        'DBDriver'     => 'MySQLi',     // atau 'Postgre' untuk PostgreSQL
        'DBPrefix'     => '',
        'pConnect'     => false,
        'DBDebug'      => false,        // false di production
        'charset'      => 'utf8mb4',
        'DBCollat'     => 'utf8mb4_general_ci',
        'swapPre'      => '',
        'encrypt'      => false,
        'compress'     => false,
        'strictOn'     => false,
        'failover'     => [],
        'port'         => 3306,
    ];
}
```

---

### CodeIgniter 3 — via `application/config/database.php`

**File:** `src/application/config/database.php`

```php
<?php

defined('BASEPATH') OR exit('No direct script access allowed');

$active_group = 'default';
$query_builder = TRUE;

$db['default'] = array(
    'dsn'          => '',
    // ◀ host.docker.internal agar container bisa reach database di host OS
    'hostname'     => 'host.docker.internal',
    'username'     => 'user_ci3',
    'password'     => 'password_ci3',
    'database'     => 'nama_database_ci3',
    'dbdriver'     => 'mysqli',         // atau 'postgre' untuk PostgreSQL
    'dbprefix'     => '',
    'pconnect'     => FALSE,
    'db_debug'     => FALSE,            // FALSE di production
    'cache_on'     => FALSE,
    'cachedir'     => '',
    'char_set'     => 'utf8mb4',
    'dbcollat'     => 'utf8mb4_general_ci',
    'swap_pre'     => '',
    'encrypt'      => FALSE,
    'compress'     => FALSE,
    'stricton'     => FALSE,
    'failover'     => array(),
    'save_queries' => FALSE,            // FALSE di production (hemat memori)
    'port'         => 3306,
);
```

---

### CodeIgniter 3 — Konfigurasi Base URL

**File:** `src/application/config/config.php`

```php
<?php

// ============================================================
// Base URL — wajib diisi agar CI3 berfungsi dengan benar
// ============================================================
$config['base_url'] = 'http://yourdomain.com/';

// Kosongkan index_page karena Nginx sudah handle rewriting
$config['index_page'] = '';
```

---

## Deployment Commands — CodeIgniter

```bash
# 1. Masuk ke direktori project
cd ci4-docker    # atau ci3-docker

# 2. Setup environment
cp src/.env.example src/.env    # Khusus CI4
nano src/.env                   # Edit konfigurasi DB

# 3. Build dan jalankan
docker compose up -d --build

# 4. Cek koneksi database (CI4)
docker exec ci_phpfpm php spark db:table

# 5. Jalankan migrasi CI4
docker exec ci_phpfpm php spark migrate

# 6. Cek status
docker compose ps
docker compose logs -f nginx
docker compose logs -f php-fpm
```

---

---

# Troubleshooting Umum

---

## Problem 1: `Connection refused` ke Database Host

**Gejala:** `SQLSTATE[HY000] [2002] Connection refused`

**Solusi:**
```bash
# 1. Cek apakah host.docker.internal resolve dengan benar
docker exec laravel_phpfpm ping -c 3 host.docker.internal

# 2. Cek apakah port database terbuka dari dalam container
docker exec laravel_phpfpm nc -zv host.docker.internal 3306

# 3. Pastikan MySQL bind-address bukan 127.0.0.1
grep bind-address /etc/mysql/mysql.conf.d/mysqld.cnf

# 4. Pastikan user database mengizinkan koneksi dari IP Docker
mysql -u root -p -e "SELECT user, host FROM mysql.user;"
```

## Problem 2: `Permission denied` pada Storage / Cache

**Gejala:** Laravel/CI tidak bisa write ke storage

```bash
# Fix permission dari dalam container
docker exec laravel_phpfpm chown -R www-data:www-data /var/www/html/storage
docker exec laravel_phpfpm chmod -R 775 /var/www/html/storage

# Untuk CI4
docker exec ci_phpfpm chown -R www-data:www-data /var/www/html/writable
```

## Problem 3: Nginx `502 Bad Gateway`

**Gejala:** Nginx tidak bisa reach PHP-FPM

```bash
# Cek apakah PHP-FPM container berjalan
docker compose ps

# Cek log PHP-FPM
docker compose logs php-fpm

# Verifikasi nama service di fastcgi_pass sesuai docker-compose
# Nama service "php-fpm" di docker-compose.yml harus sama dengan
# yang ada di nginx default.conf: fastcgi_pass php-fpm:9000;
```

## Problem 4: URL `index.php` muncul di CI3

**Gejala:** URL tidak clean, selalu ada `/index.php/`

```bash
# Pastikan di config.php CI3:
# $config['index_page'] = '';   ← string kosong, bukan 'index.php'

# Verifikasi konfigurasi Nginx sudah menggunakan:
# try_files $uri $uri/ /index.php?/$request_uri;
```

---

# Ringkasan Perbedaan Konfigurasi

| Konfigurasi | Laravel | CI4 | CI3 |
|---|---|---|---|
| **Nginx `root`** | `/var/www/html/public` | `/var/www/html/public` | `/var/www/html` |
| **Nginx `try_files`** | `/index.php?$query_string` | `/index.php$is_args$args` | `/index.php?/$request_uri` |
| **DB Host di app** | `host.docker.internal` | `host.docker.internal` | `host.docker.internal` |
| **DB Config file** | `src/.env` | `src/.env` atau `Database.php` | `application/config/database.php` |
| **Folder terproteksi** | `.env`, `.git` | `app/`, `system/`, `writable/` | `application/`, `system/` |
| **OPcache** | Direkomendasikan | Direkomendasikan | Direkomendasikan |

---

*Panduan ini dibuat untuk lingkungan production. Selalu review security policy sesuai kebutuhan organisasi Anda sebelum deploy ke publik.*
