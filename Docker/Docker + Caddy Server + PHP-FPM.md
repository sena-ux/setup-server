# Panduan Docker: Caddy Server + PHP-FPM untuk Laravel & CodeIgniter
### (Database Native di Host OS)

> **Stack:** Docker · Caddy v2 (Auto-HTTPS) · PHP-FPM · MySQL/PostgreSQL (native di host)  
> **Versi acuan:** Caddy 2.7+, PHP 8.2-FPM, Laravel 10/11, CodeIgniter 4.x / 3.x

---

## Prasyarat

```bash
# Pastikan Docker & Compose tersedia
docker --version        # Docker 24+
docker compose version  # Compose v2+

# Database native sudah berjalan di host
sudo systemctl status mysql   # atau postgresql
```

---

---

# BAGIAN 1: SETUP UNTUK LARAVEL

---

## 1. Struktur Direktori

```
laravel-project/
├── docker/
│   ├── caddy/
│   │   └── Caddyfile
│   └── php/
│       ├── Dockerfile
│       └── php-fpm.conf          # (opsional, override default pool)
├── src/                          # Root Laravel project
│   ├── app/
│   ├── bootstrap/
│   ├── config/
│   ├── database/
│   ├── public/                   # Document root Caddy
│   │   └── index.php
│   ├── resources/
│   ├── routes/
│   ├── storage/
│   ├── vendor/
│   ├── .env                      # Konfigurasi DB ke host
│   └── composer.json
├── docker-compose.yml
└── .env.docker                   # Variabel khusus Docker Compose
```

---

## 2. Konfigurasi Caddyfile (Laravel)

**Path:** `docker/caddy/Caddyfile`

```caddyfile
# ============================================================
# Caddyfile — Laravel dengan Auto-HTTPS
# ============================================================

# Ganti dengan domain asli Anda. Caddy otomatis request
# sertifikat TLS via Let's Encrypt / ZeroSSL.
aplikasi.example.com {

    # --- Root & Encoding ---
    root * /srv/app/public
    encode gzip zstd

    # --- Logging ---
    log {
        output file /var/log/caddy/laravel_access.log {
            roll_size 50mb
            roll_keep 5
        }
        format json
    }

    # --- Aset Statis ---
    # Caddy melayani file statis langsung dari /public
    # sebelum meneruskan ke PHP-FPM. Urutan ini krusial.
    @static {
        file
        path *.css *.js *.png *.jpg *.jpeg *.gif *.ico *.svg
             *.woff *.woff2 *.ttf *.eot *.pdf *.map
    }
    handle @static {
        # Cache control untuk aset statis
        header Cache-Control "public, max-age=31536000, immutable"
        file_server
    }

    # --- PHP via FastCGI ---
    # php_fastcgi menangani: index.php fallback, splitting PATH_INFO,
    # dan header FastCGI standar secara otomatis.
    php_fastcgi phpfpm:9000 {
        # Nama service PHP-FPM di docker-compose
        root /srv/app/public

        # Env yang diteruskan ke PHP (opsional, berguna untuk debug)
        env APP_ENV production

        # Timeout untuk request yang berat (upload file besar, dll.)
        read_timeout  300s
        write_timeout 300s
    }

    # --- Security Headers ---
    header {
        X-Frame-Options "SAMEORIGIN"
        X-Content-Type-Options "nosniff"
        X-XSS-Protection "1; mode=block"
        Referrer-Policy "strict-origin-when-cross-origin"
        Permissions-Policy "geolocation=(), microphone=()"
        # Hapus server signature
        -Server
    }

    # --- Health Check Endpoint ---
    respond /health 200

    # --- Blokir akses ke file sensitif ---
    @sensitive {
        path /.env* /storage/* /composer.json /composer.lock
    }
    respond @sensitive 403
}

# ============================================================
# Development: gunakan localhost (tanpa TLS)
# Uncomment blok ini untuk dev, comment blok di atas.
# ============================================================
# :80 {
#     root * /srv/app/public
#     encode gzip
#     php_fastcgi phpfpm:9000
#     file_server
#     log
# }
```

> **Tips Auto-HTTPS:**  
> - Caddy memerlukan port **80 dan 443** terbuka ke internet agar ACME challenge berhasil.  
> - Untuk staging/testing, tambahkan `tls internal` agar Caddy generate sertifikat self-signed tanpa hit Let's Encrypt.

---

## 3. Dockerfile PHP-FPM (Laravel)

**Path:** `docker/php/Dockerfile`

```dockerfile
# ============================================================
# Dockerfile — PHP 8.2 FPM untuk Laravel
# ============================================================
FROM php:8.2-fpm-alpine

# --- System dependencies ---
RUN apk add --no-cache \
    bash \
    curl \
    git \
    unzip \
    libpng-dev \
    libjpeg-turbo-dev \
    libwebp-dev \
    freetype-dev \
    libzip-dev \
    oniguruma-dev \
    icu-dev \
    linux-headers

# --- PHP Extensions ---
RUN docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg \
        --with-webp \
    && docker-php-ext-install -j$(nproc) \
        pdo \
        pdo_mysql \
        pdo_pgsql \
        mbstring \
        exif \
        pcntl \
        bcmath \
        gd \
        zip \
        intl \
        opcache

# --- Redis extension (via PECL) ---
RUN pecl install redis && docker-php-ext-enable redis

# --- OPcache konfigurasi production ---
COPY opcache.ini /usr/local/etc/php/conf.d/opcache.ini

# --- Composer ---
COPY --from=composer:2.7 /usr/bin/composer /usr/bin/composer

# --- PHP-FPM pool configuration ---
# Hapus pool default, ganti dengan konfigurasi custom
RUN rm /usr/local/etc/php-fpm.d/www.conf
COPY php-fpm.conf /usr/local/etc/php-fpm.d/laravel.conf

# --- User non-root untuk keamanan ---
RUN addgroup -g 1000 -S appgroup && \
    adduser -u 1000 -S appuser -G appgroup

WORKDIR /srv/app

# Mount source dari host (via volume), bukan COPY
# sehingga perubahan kode tidak perlu rebuild image.

USER appuser

EXPOSE 9000
CMD ["php-fpm"]
```

**`docker/php/opcache.ini`:**

```ini
[opcache]
opcache.enable=1
opcache.enable_cli=0
opcache.memory_consumption=256
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=20000
opcache.revalidate_freq=0       ; 0 = selalu pakai cache (production)
opcache.validate_timestamps=0   ; matikan di production, aktifkan di dev
opcache.save_comments=1
opcache.fast_shutdown=1
```

**`docker/php/php-fpm.conf`:**

```ini
[laravel]
user  = appuser
group = appgroup

; Socket TCP lebih mudah dengan multi-container
listen = 0.0.0.0:9000

; Dynamic process management
pm                   = dynamic
pm.max_children      = 20
pm.start_servers     = 5
pm.min_spare_servers = 3
pm.max_spare_servers = 10
pm.max_requests      = 500       ; Restart worker tiap 500 req, cegah memory leak

; Timeout
request_terminate_timeout = 300

; Log
catch_workers_output      = yes
php_flag[display_errors]  = off
php_admin_value[error_log] = /var/log/fpm-laravel.log
php_admin_flag[log_errors] = on
```

---

## 4. Docker Compose & Akses Database Native

**`docker-compose.yml`:**

```yaml
# ============================================================
# docker-compose.yml — Laravel (DB di Host Native)
# ============================================================
version: "3.9"

services:

  # ----------------------------------------------------------
  # Caddy Web Server
  # ----------------------------------------------------------
  caddy:
    image: caddy:2.7-alpine
    container_name: laravel_caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"   # HTTP/3 (QUIC)
    volumes:
      # Konfigurasi Caddy
      - ./docker/caddy/Caddyfile:/etc/caddy/Caddyfile:ro
      # Source Laravel (Caddy butuh akses /public untuk aset statis)
      - ./src:/srv/app:ro
      # Persistent: sertifikat TLS & data Caddy
      - caddy_data:/data
      - caddy_config:/config
      - caddy_logs:/var/log/caddy
    networks:
      - app_network
    # Akses ke host OS untuk DB native
    extra_hosts:
      - "host.docker.internal:host-gateway"
    depends_on:
      - phpfpm

  # ----------------------------------------------------------
  # PHP-FPM
  # ----------------------------------------------------------
  phpfpm:
    build:
      context: ./docker/php
      dockerfile: Dockerfile
    container_name: laravel_phpfpm
    restart: unless-stopped
    volumes:
      # Source Laravel (read-write: storage, bootstrap/cache)
      - ./src:/srv/app
      # Log PHP-FPM
      - phpfpm_logs:/var/log
    networks:
      - app_network
    extra_hosts:
      - "host.docker.internal:host-gateway"
    environment:
      # Override .env jika perlu (opsional)
      APP_ENV: production
    # Jangan expose port 9000 ke luar — hanya internal network
    expose:
      - "9000"

# ============================================================
# Networks
# ============================================================
networks:
  app_network:
    driver: bridge

# ============================================================
# Volumes
# ============================================================
volumes:
  caddy_data:
    driver: local
  caddy_config:
    driver: local
  caddy_logs:
    driver: local
  phpfpm_logs:
    driver: local
```

---

## 5. Konfigurasi `.env` Laravel — Akses DB di Host

**`src/.env`:**

```dotenv
APP_NAME="Aplikasi Saya"
APP_ENV=production
APP_KEY=base64:GANTI_DENGAN_KEY_ANDA
APP_DEBUG=false
APP_URL=https://aplikasi.example.com

# ============================================================
# DATABASE — MySQL/PostgreSQL Native di Host
# ============================================================
# Gunakan host.docker.internal agar container bisa reach
# database yang berjalan di host OS.
# Tidak perlu mengubah konfigurasi DB di host.

DB_CONNECTION=mysql
DB_HOST=host.docker.internal    # <-- KUNCI: resolve ke IP host
DB_PORT=3306
DB_DATABASE=nama_database
DB_USERNAME=db_user
DB_PASSWORD=db_password_aman

# ============================================================
# CACHE & SESSION
# ============================================================
CACHE_STORE=redis
QUEUE_CONNECTION=redis
SESSION_DRIVER=redis

REDIS_HOST=host.docker.internal
REDIS_PASSWORD=null
REDIS_PORT=6379
```

### Konfigurasi MySQL di Host agar Menerima Koneksi dari Docker

```sql
-- Jalankan di MySQL host sebagai root
-- Beri akses dari subnet Docker (default: 172.17.0.0/16)
CREATE USER 'db_user'@'172.%.%.%' IDENTIFIED BY 'db_password_aman';
GRANT ALL PRIVILEGES ON nama_database.* TO 'db_user'@'172.%.%.%';
FLUSH PRIVILEGES;
```

```bash
# Cek subnet Docker yang aktif
docker network inspect laravel_app_network | grep Subnet
# Biasanya: "Subnet": "172.18.0.0/16"
```

```ini
# /etc/mysql/mysql.conf.d/mysqld.cnf
# Ubah bind-address agar MySQL listen di semua interface
# (atau spesifik ke IP bridge Docker)
[mysqld]
bind-address = 0.0.0.0
```

```bash
sudo systemctl restart mysql
```

### Perintah Deploy Laravel

```bash
# Build dan jalankan container
docker compose up -d --build

# Generate app key (pertama kali)
docker compose exec phpfpm php artisan key:generate

# Jalankan migrasi
docker compose exec phpfpm php artisan migrate --force

# Optimize untuk production
docker compose exec phpfpm php artisan config:cache
docker compose exec phpfpm php artisan route:cache
docker compose exec phpfpm php artisan view:cache
docker compose exec phpfpm php artisan storage:link

# Cek log
docker compose logs -f caddy
docker compose logs -f phpfpm
```

---

---

# BAGIAN 2: SETUP UNTUK CODEIGNITER (CI4 / CI3)

---

## 1. Struktur Direktori

### CodeIgniter 4

```
ci4-project/
├── docker/
│   ├── caddy/
│   │   └── Caddyfile
│   └── php/
│       ├── Dockerfile
│       └── php-fpm.conf
├── src/                          # Root CI4 project
│   ├── app/
│   │   ├── Config/
│   │   │   └── Database.php      # Konfigurasi DB
│   │   ├── Controllers/
│   │   ├── Models/
│   │   └── Views/
│   ├── public/                   # Document root (mirip Laravel)
│   │   └── index.php
│   ├── system/
│   ├── vendor/
│   ├── writable/                 # Cache, logs, uploads (perlu write permission)
│   └── .env
├── docker-compose.yml
└── .env.docker
```

### CodeIgniter 3

```
ci3-project/
├── docker/
│   ├── caddy/
│   │   └── Caddyfile
│   └── php/
│       └── Dockerfile
├── src/                          # Root CI3 project
│   ├── application/
│   │   └── config/
│   │       └── database.php      # Konfigurasi DB
│   ├── system/
│   ├── index.php                 # Entry point ada di ROOT (bukan /public)
│   └── .htaccess
├── docker-compose.yml
```

---

## 2. Konfigurasi Caddyfile (CodeIgniter 4)

**Path:** `docker/caddy/Caddyfile`

```caddyfile
# ============================================================
# Caddyfile — CodeIgniter 4 dengan Auto-HTTPS
# CI4 memiliki struktur /public mirip Laravel
# ============================================================

ci4.example.com {

    # Root ke /public (sama seperti Laravel)
    root * /srv/app/public
    encode gzip zstd

    log {
        output file /var/log/caddy/ci4_access.log {
            roll_size 50mb
            roll_keep 5
        }
        format json
    }

    # --- Aset Statis ---
    @static {
        file
        path *.css *.js *.png *.jpg *.jpeg *.gif *.ico
             *.svg *.woff *.woff2 *.ttf *.pdf *.map
    }
    handle @static {
        header Cache-Control "public, max-age=31536000, immutable"
        file_server
    }

    # --- PHP FastCGI untuk CI4 ---
    # CI4 menggunakan index.php di /public sebagai front controller
    php_fastcgi phpfpm:9000 {
        root /srv/app/public
        # CI4 menggunakan PATH_INFO untuk routing
        # php_fastcgi Caddy sudah handle ini secara default
        read_timeout  120s
        write_timeout 120s
    }

    # --- Blokir akses ke direktori sensitif CI4 ---
    @sensitive {
        path /app/* /system/* /writable/* /.env*
             /composer.json /composer.lock /spark
    }
    respond @sensitive 403

    # --- Security Headers ---
    header {
        X-Frame-Options "SAMEORIGIN"
        X-Content-Type-Options "nosniff"
        X-XSS-Protection "1; mode=block"
        -Server
    }

    respond /health 200
}
```

---

## 3. Konfigurasi Caddyfile (CodeIgniter 3)

CI3 **tidak memiliki** folder `/public` — `index.php` ada di root project.

```caddyfile
# ============================================================
# Caddyfile — CodeIgniter 3 dengan Auto-HTTPS
# PERBEDAAN UTAMA: root ke direktori src langsung (bukan /public)
# ============================================================

ci3.example.com {

    # Root ke direktori utama CI3 (bukan /public!)
    root * /srv/app
    encode gzip zstd

    log {
        output file /var/log/caddy/ci3_access.log
        format json
    }

    # --- Aset Statis ---
    @static {
        file
        path *.css *.js *.png *.jpg *.jpeg *.gif
             *.ico *.svg *.woff *.woff2 *.ttf *.pdf
    }
    handle @static {
        header Cache-Control "public, max-age=2592000"
        file_server
    }

    # --- Rewrite untuk CI3 ---
    # CI3 tradisional membutuhkan semua request non-file
    # diarahkan ke index.php
    # Caddy's php_fastcgi + try_files melakukan ini secara otomatis.
    # Pastikan $config['index_page'] = '' di application/config/config.php

    php_fastcgi phpfpm:9000 {
        root /srv/app
        read_timeout  120s
        write_timeout 120s
    }

    # --- Blokir akses ke direktori internal CI3 ---
    @sensitive {
        path /application/* /system/* /.git/*
             /composer.json /composer.lock
    }
    respond @sensitive 403

    header {
        X-Frame-Options "SAMEORIGIN"
        X-Content-Type-Options "nosniff"
        -Server
    }
}
```

> **Catatan CI3 — Konfigurasi `config.php`:**
> ```php
> // application/config/config.php
> $config['base_url']    = 'https://ci3.example.com/';
> $config['index_page']  = '';          // Kosongkan — Caddy handle rewrite
> $config['uri_protocol'] = 'REQUEST_URI';
> ```

---

## 4. Dockerfile PHP-FPM (CodeIgniter)

**`docker/php/Dockerfile`** — CI4 dan CI3 bisa menggunakan Dockerfile serupa:

```dockerfile
# ============================================================
# Dockerfile — PHP 8.2 FPM untuk CodeIgniter 4
# Untuk CI3, ganti ke php:7.4-fpm-alpine atau php:8.1-fpm-alpine
# ============================================================
FROM php:8.2-fpm-alpine

RUN apk add --no-cache \
    bash \
    curl \
    git \
    unzip \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libzip-dev \
    oniguruma-dev \
    icu-dev

RUN docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        pdo \
        pdo_mysql \
        pdo_pgsql \
        mbstring \
        gd \
        zip \
        intl \
        opcache \
        exif

# Untuk CI3 yang masih pakai MySQLi (bukan PDO):
# RUN docker-php-ext-install mysqli

COPY --from=composer:2.7 /usr/bin/composer /usr/bin/composer

COPY php-fpm.conf /usr/local/etc/php-fpm.d/ci.conf
RUN rm -f /usr/local/etc/php-fpm.d/www.conf

RUN addgroup -g 1000 -S appgroup && \
    adduser  -u 1000 -S appuser  -G appgroup

WORKDIR /srv/app
USER appuser

EXPOSE 9000
CMD ["php-fpm"]
```

---

## 5. Docker Compose (CodeIgniter)

```yaml
# ============================================================
# docker-compose.yml — CodeIgniter 4 (DB di Host Native)
# Untuk CI3: ubah path volume sesuai struktur CI3
# ============================================================
version: "3.9"

services:

  caddy:
    image: caddy:2.7-alpine
    container_name: ci_caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"
    volumes:
      - ./docker/caddy/Caddyfile:/etc/caddy/Caddyfile:ro
      # CI4: mount seluruh src karena Caddy butuh /public
      - ./src:/srv/app:ro
      - caddy_data:/data
      - caddy_config:/config
      - caddy_logs:/var/log/caddy
    networks:
      - ci_network
    extra_hosts:
      - "host.docker.internal:host-gateway"
    depends_on:
      - phpfpm

  phpfpm:
    build:
      context: ./docker/php
      dockerfile: Dockerfile
    container_name: ci_phpfpm
    restart: unless-stopped
    volumes:
      - ./src:/srv/app
      # Pastikan writable/ bisa ditulis oleh container
      - ci_writable:/srv/app/writable    # CI4
      # Untuk CI3: - ci_cache:/srv/app/application/cache
    networks:
      - ci_network
    extra_hosts:
      - "host.docker.internal:host-gateway"
    expose:
      - "9000"

networks:
  ci_network:
    driver: bridge

volumes:
  caddy_data:
  caddy_config:
  caddy_logs:
  ci_writable:
```

---

## 6. Konfigurasi Database CodeIgniter ke Host Native

### CodeIgniter 4 — `app/Config/Database.php`

```php
<?php

namespace Config;

use CodeIgniter\Database\Config;

class Database extends Config
{
    public string $defaultGroup = 'default';

    public array $default = [
        'DSN'      => '',
        'hostname' => 'host.docker.internal',   // <-- Resolve ke host OS
        'username' => 'db_user',
        'password' => 'db_password_aman',
        'database' => 'nama_database',
        'DBDriver' => 'MySQLi',                 // atau 'Postgre' untuk PostgreSQL
        'DBPrefix' => '',
        'pConnect' => false,
        'DBDebug'  => false,                    // false di production
        'charset'  => 'utf8mb4',
        'DBCollat' => 'utf8mb4_general_ci',
        'swapPre'  => '',
        'encrypt'  => false,
        'compress' => false,
        'strictOn' => false,
        'failover' => [],
        'port'     => 3306,
        'numberNative' => false,
    ];
}
```

### CodeIgniter 4 — `.env`

```dotenv
# CI4 juga mendukung .env (mirip Laravel)
CI_ENVIRONMENT = production

database.default.hostname = host.docker.internal
database.default.database = nama_database
database.default.username = db_user
database.default.password = db_password_aman
database.default.DBDriver = MySQLi
database.default.port     = 3306
```

### CodeIgniter 3 — `application/config/database.php`

```php
<?php

$active_group = 'default';
$query_builder = TRUE;

$db['default'] = array(
    'dsn'          => '',
    'hostname'     => 'host.docker.internal',  // <-- Host OS dari dalam container
    'username'     => 'db_user',
    'password'     => 'db_password_aman',
    'database'     => 'nama_database',
    'dbdriver'     => 'mysqli',                // 'postgre' untuk PostgreSQL
    'dbprefix'     => '',
    'pconnect'     => FALSE,
    'db_debug'     => (ENVIRONMENT !== 'production'),
    'cache_on'     => FALSE,
    'cachedir'     => '',
    'char_set'     => 'utf8mb4',
    'dbcollat'     => 'utf8mb4_general_ci',
    'swap_pre'     => '',
    'encrypt'      => FALSE,
    'compress'     => FALSE,
    'stricton'     => FALSE,
    'failover'     => array(),
    'save_queries' => FALSE,                   // FALSE di production
);
```

---

### Perintah Deploy CodeIgniter

```bash
# Build & start
docker compose up -d --build

# CI4: install dependensi via Composer
docker compose exec phpfpm composer install --no-dev --optimize-autoloader

# CI4: set permission writable/
docker compose exec phpfpm chmod -R 775 writable/

# CI4: clear cache
docker compose exec phpfpm php spark cache:clear

# Test koneksi DB dari dalam container
docker compose exec phpfpm php -r "
    \$conn = new mysqli('host.docker.internal', 'db_user', 'db_password_aman', 'nama_database');
    echo \$conn->connect_error ? 'GAGAL: '.\$conn->connect_error : 'KONEKSI BERHASIL';
"
```

---

---

# REFERENSI CEPAT & TIPS PERFORMA

---

## Troubleshooting Koneksi DB ke Host

| Masalah | Solusi |
|---|---|
| `Connection refused` | Pastikan `bind-address = 0.0.0.0` di `mysqld.cnf` |
| `Host not allowed` | Tambahkan grant untuk subnet Docker (`172.%.%.%`) |
| `host.docker.internal` tidak resolve | Pastikan `extra_hosts: host.docker.internal:host-gateway` di compose |
| PostgreSQL ditolak | Edit `pg_hba.conf`: tambah `host all all 172.0.0.0/8 md5` |

## Perbandingan Caddyfile: Laravel vs CI4 vs CI3

| Aspek | Laravel | CI4 | CI3 |
|---|---|---|---|
| `root *` | `/srv/app/public` | `/srv/app/public` | `/srv/app` (root!) |
| Entry point | `public/index.php` | `public/index.php` | `index.php` |
| `php_fastcgi root` | `/srv/app/public` | `/srv/app/public` | `/srv/app` |
| Folder sensitif | `storage/`, `.env` | `app/`, `writable/` | `application/` |
| URL rewrite | Auto (php_fastcgi) | Auto (php_fastcgi) | Auto + `index_page=''` |

## Tips Performa

```caddyfile
# 1. Aktifkan HTTP/3 (QUIC) — sudah otomatis di Caddy jika port UDP 443 terbuka

# 2. Kompresi: selalu aktifkan gzip + zstd
encode gzip zstd

# 3. Cache aset statis agresif
header Cache-Control "public, max-age=31536000, immutable"

# 4. Untuk traffic tinggi, tuning php-fpm.conf:
# pm.max_children = (RAM tersedia / rata-rata RAM per proses PHP)
# Contoh: 2GB RAM, 50MB/proses → max_children = 40
```

```ini
# php.ini production tweaks (taruh di docker/php/custom.ini)
memory_limit          = 256M
max_execution_time    = 60
upload_max_filesize   = 20M
post_max_size         = 25M
realpath_cache_size   = 4096K
realpath_cache_ttl    = 600
```

## Perintah Maintenance Umum

```bash
# Reload Caddy config tanpa downtime
docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile

# Cek sertifikat TLS
docker compose exec caddy caddy certificates

# Monitor real-time PHP-FPM
docker compose exec phpfpm sh -c "watch -n1 'kill -SIGUSR1 1 && cat /var/log/fpm-status.log'"

# Scale PHP-FPM workers (jika butuh lebih banyak proses)
docker compose up -d --scale phpfpm=3   # butuh load balancer tambahan

# Backup dan restart bersih
docker compose down && docker compose up -d

# Hapus semua container + volumes (HATI-HATI: data hilang)
docker compose down -v
```

---

> **Catatan Keamanan:**  
> - Jangan pernah expose port `9000` PHP-FPM ke publik — hanya lewat internal Docker network.  
> - Gunakan Docker secrets atau vault untuk menyimpan kredensial produksi, bukan plain `.env`.  
> - Jalankan PHP-FPM sebagai user non-root (`appuser`) seperti contoh Dockerfile di atas.  
> - Aktifkan firewall di host: izinkan hanya port 80, 443 dari luar; blokir 9000, 3306 dari internet.
