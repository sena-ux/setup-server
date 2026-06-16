# Panduan Deployment Aplikasi CodeIgniter di Atas Podman

Panduan lengkap untuk menjalankan aplikasi CodeIgniter 3 dan CodeIgniter 4 menggunakan Podman dengan 2 arsitektur berbeda: **FrankenPHP** dan **Nginx + PHP-FPM**.

---

## 📋 Daftar Isi

- [BAB 1: CodeIgniter 3 Deployment](#bab-1-codeigniter-3-deployment)
  - [1.1 Metode FrankenPHP](#11-metode-frankephp)
  - [1.2 Metode Nginx + PHP-FPM](#12-metode-nginx--php-fpm)
- [BAB 2: CodeIgniter 4 Deployment](#bab-2-codeigniter-4-deployment)
  - [2.1 Metode FrankenPHP](#21-metode-frankephp)
  - [2.2 Metode Nginx + PHP-FPM](#22-metode-nginx--php-fpm)
- [Troubleshooting & Optimasi](#troubleshooting--optimasi)

---

# BAB 1: CodeIgniter 3 Deployment

CodeIgniter 3 masih menggunakan struktur lama dengan `index.php` di root folder. Panduan ini mengoptimalkan routing agar bekerja sempurna di Podman baik dengan FrankenPHP maupun Nginx + PHP-FPM.

## 1.1 Metode FrankenPHP

### Deskripsi
FrankenPHP adalah implementasi PHP modern berbasis Go yang memungkinkan jalankan PHP tanpa memerlukan server terpisah. Cocok untuk aplikasi CodeIgniter 3 yang sederhana.

### Persiapan

Struktur folder aplikasi CI3:
```
myapp-ci3/
├── application/
├── system/
├── index.php
├── .htaccess (optional, tidak digunakan FrankenPHP)
└── ...
```

### Langkah 1: Membuat Dockerfile untuk FrankenPHP

Buat file `Containerfile.frankephp.ci3` di root project:

```dockerfile
# Containerfile.frankephp.ci3
FROM dunglas/frankenphp:latest-alpine

WORKDIR /app

# Install dependencies
RUN apk add --no-cache \
    git \
    curl \
    zip \
    unzip

# Copy aplikasi CodeIgniter 3
COPY . .

# Install Composer dependencies (jika menggunakan)
RUN if [ -f "composer.json" ]; then \
        curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer && \
        composer install --no-dev --optimize-autoloader; \
    fi

# Set permission untuk folder writable
RUN chmod -R 755 . && \
    mkdir -p writable && \
    chmod -R 777 writable

# Expose port
EXPOSE 80

# Start FrankenPHP
CMD ["frankenphp", "run", "--addr", "0.0.0.0:80"]
```

### Langkah 2: Konfigurasi Routing FrankenPHP

FrankenPHP menggunakan `Caddyfile` untuk konfigurasi. Buat file `Caddyfile` di root project:

```caddyfile
# Caddyfile
{
    # Disable telemetry
    telemetry disable
}

:80 {
    # Root directory
    root * /app
    
    # Encode responses
    encode gzip
    
    # Serve static files
    file_server
    
    # Rewrite semua request ke index.php (CodeIgniter routing)
    rewrite * /index.php?{query}
    
    # Handle PHP files
    php_fastcgi localhost:9000
}
```

**Catatan**: Untuk FrankenPHP, Anda perlu memodifikasi `Caddyfile` agar routing CI3 bekerja. Alternatif, gunakan PHP built-in server dengan script:

Buat file `start.sh`:

```bash
#!/bin/bash
set -e

cd /app

# Start FrankenPHP dengan routing yang tepat
frankenphp run \
    --addr 0.0.0.0:80 \
    --debug
```

Modifikasi Dockerfile:

```dockerfile
FROM dunglas/frankenphp:latest-alpine

WORKDIR /app

RUN apk add --no-cache git curl zip unzip bash

COPY . .

RUN if [ -f "composer.json" ]; then \
        curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer && \
        composer install --no-dev --optimize-autoloader; \
    fi

RUN chmod -R 755 . && mkdir -p writable && chmod -R 777 writable

COPY Caddyfile /etc/caddy/Caddyfile

EXPOSE 80

CMD ["frankenphp", "run", "--addr", "0.0.0.0:80"]
```

### Langkah 3: Build Image

```bash
# Build image
podman build -t ci3-frankephp -f Containerfile.frankephp.ci3 .

# Atau dengan buildah
buildah bud -t ci3-frankephp -f Containerfile.frankephp.ci3 .
```

### Langkah 4: Menjalankan Container

```bash
# Jalankan container interaktif
podman run -it \
    --name ci3-app \
    -p 8080:80 \
    -v $(pwd):/app:Z \
    ci3-frankephp

# Atau detached mode
podman run -d \
    --name ci3-app \
    -p 8080:80 \
    -v $(pwd):/app:Z \
    ci3-frankephp
```

### Langkah 5: Testing

Akses aplikasi di browser:
```
http://localhost:8080/
http://localhost:8080/index.php/welcome  (CI3 routing)
http://localhost:8080/welcome            (tanpa index.php)
```

### Optimasi Permission untuk Podman Rootless

Jika menggunakan Podman Rootless:

```bash
# Check Podman rootless status
podman info | grep rootless

# Set UID mapping untuk folder
mkdir -p /tmp/podman-ci3
podman unshare chown -R $(id -u):$(id -g) /tmp/podman-ci3

# Gunakan dalam container
podman run -d \
    --name ci3-app \
    -p 8080:80 \
    -v /tmp/podman-ci3:/app:Z \
    ci3-frankephp
```

---

## 1.2 Metode Nginx + PHP-FPM

### Deskripsi
Metode ini menggunakan 2 container terpisah: satu untuk Nginx (web server) dan satu untuk PHP-FPM (PHP interpreter). Lebih fleksibel dan production-ready.

### Struktur Docker Compose

```yaml
# docker-compose.yml (atau podman-compose.yml)
version: '3.8'

services:
  php-fpm:
    build:
      context: .
      dockerfile: Containerfile.php-fpm.ci3
    container_name: ci3-php-fpm
    networks:
      - ci3-network
    volumes:
      - ./:/app:Z
      - php_socket:/run/php-fpm
    environment:
      - PHP_MEMORY_LIMIT=256M
      - PHP_MAX_UPLOAD_SIZE=50M
    restart: unless-stopped

  nginx:
    build:
      context: .
      dockerfile: Containerfile.nginx.ci3
    container_name: ci3-nginx
    ports:
      - "8080:80"
    depends_on:
      - php-fpm
    networks:
      - ci3-network
    volumes:
      - ./:/app:Z
      - php_socket:/run/php-fpm
    restart: unless-stopped

volumes:
  php_socket:

networks:
  ci3-network:
    driver: bridge
```

### Langkah 1: Membuat Dockerfile untuk PHP-FPM

Buat file `Containerfile.php-fpm.ci3`:

```dockerfile
# Containerfile.php-fpm.ci3
FROM php:8.2-fpm-alpine

WORKDIR /app

# Install system dependencies
RUN apk add --no-cache \
    git \
    curl \
    zip \
    unzip \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libxml2-dev

# Install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-install -j$(nproc) \
    gd \
    pdo \
    pdo_mysql \
    xml \
    json \
    curl

# Copy aplikasi
COPY . .

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Install dependencies
RUN if [ -f "composer.json" ]; then \
        composer install --no-dev --optimize-autoloader; \
    fi

# Set permissions
RUN chmod -R 755 . && \
    mkdir -p writable && \
    chmod -R 777 writable

# Copy PHP-FPM config
COPY php-fpm.conf /usr/local/etc/php-fpm.d/z-custom.conf

EXPOSE 9000

CMD ["php-fpm"]
```

### Langkah 2: Konfigurasi PHP-FPM

Buat file `php-fpm.conf`:

```ini
# php-fpm.conf
[global]
error_log = /proc/self/fd/2
log_level = warning

[www]
user = www-data
group = www-data

listen = /run/php-fpm/php-fpm.sock
listen.owner = www-data
listen.group = www-data
listen.mode = 0666

pm = dynamic
pm.max_children = 10
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3

clear_env = no
catch_workers_output = yes
decorate_workers_output = no
```

### Langkah 3: Membuat Dockerfile untuk Nginx

Buat file `Containerfile.nginx.ci3`:

```dockerfile
# Containerfile.nginx.ci3
FROM nginx:alpine

WORKDIR /app

# Copy konfigurasi Nginx
COPY nginx.conf /etc/nginx/nginx.conf
COPY nginx-ci3.conf /etc/nginx/conf.d/default.conf

# Copy aplikasi
COPY . .

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

### Langkah 4: Konfigurasi Nginx untuk CI3

Buat file `nginx-ci3.conf`:

```nginx
# nginx-ci3.conf
upstream php-fpm {
    server unix:/run/php-fpm/php-fpm.sock;
}

server {
    listen 80;
    server_name _;

    root /app;
    index index.php;

    # Gzip compression
    gzip on;
    gzip_types text/plain text/css text/javascript application/javascript application/json;
    gzip_min_length 1000;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Logging
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log warn;

    # Deny access to sensitive files
    location ~ /\. {
        deny all;
    }

    location ~ ~$ {
        deny all;
    }

    # Static files caching
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        expires 365d;
        add_header Cache-Control "public, immutable";
    }

    # PHP routing untuk CodeIgniter 3
    # Rewrite semua request ke index.php
    location / {
        try_files $uri $uri/ @rewrite;
    }

    location @rewrite {
        rewrite ^/(.*)$ /index.php/$1 last;
    }

    # Handle PHP files
    location ~ \.php(.*)$ {
        fastcgi_pass php-fpm;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_param PATH_INFO $fastcgi_path_info;
        fastcgi_param PATH_TRANSLATED $document_root$fastcgi_path_info;
        include fastcgi_params;
        
        # Timeout settings
        fastcgi_connect_timeout 60s;
        fastcgi_send_timeout 60s;
        fastcgi_read_timeout 60s;
    }
}
```

### Langkah 5: Konfigurasi Nginx Utama

Buat file `nginx.conf`:

```nginx
# nginx.conf
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
    use epoll;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 50M;

    include /etc/nginx/conf.d/*.conf;
}
```

### Langkah 6: Build dan Jalankan dengan Docker Compose

```bash
# Build images
docker-compose build
# atau
podman-compose build

# Jalankan services
docker-compose up -d
# atau
podman-compose up -d

# Lihat logs
docker-compose logs -f
podman-compose logs -f

# Stop services
docker-compose down
podman-compose down
```

### Langkah 7: Testing

```bash
# Test Nginx dan PHP-FPM
curl http://localhost:8080/
curl http://localhost:8080/welcome

# Check container status
docker-compose ps
podman-compose ps

# Akses shell container
docker-compose exec php-fpm sh
podman-compose exec php-fpm sh
```

### Optimasi Permission untuk Podman Rootless

```bash
# Buat directory untuk socket dengan permission yang benar
mkdir -p /tmp/podman-sockets
podman unshare chown -R $(id -u):$(id -g) /tmp/podman-sockets

# Update docker-compose.yml
# volumes:
#   php_socket:
#     driver: local
#     driver_opts:
#       type: tmpfs
#       device: tmpfs
#       o: size=100m,uid=$(id -u),gid=$(id -g)
```

---

# BAB 2: CodeIgniter 4 Deployment

CodeIgniter 4 menggunakan struktur modern dengan folder `public/` sebagai entry point. Ini memberikan keamanan lebih baik dan organisasi kode yang lebih baik.

## 2.1 Metode FrankenPHP

### Deskripsi
CodeIgniter 4 dengan FrankenPHP adalah kombinasi modern yang sangat cocok untuk development dan production skala kecil-menengah.

### Persiapan

Struktur folder aplikasi CI4:
```
myapp-ci4/
├── app/
├── public/
│   ├── index.php
│   └── .htaccess (optional)
├── writable/
├── composer.json
└── .env
```

### Langkah 1: Membuat Dockerfile untuk FrankenPHP

Buat file `Containerfile.frankephp.ci4`:

```dockerfile
# Containerfile.frankephp.ci4
FROM dunglas/frankenphp:latest-alpine

WORKDIR /app

# Install dependencies
RUN apk add --no-cache \
    git \
    curl \
    zip \
    unzip \
    bash

# Copy aplikasi CodeIgniter 4
COPY . .

# Install Composer dependencies
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer && \
    composer install --no-dev --optimize-autoloader

# Set permissions untuk folder writable
RUN chmod -R 755 . && \
    chmod -R 777 writable && \
    chmod -R 777 public

# Copy Caddyfile
COPY Caddyfile /etc/caddy/Caddyfile

# Expose port
EXPOSE 80

CMD ["frankenphp", "run", "--addr", "0.0.0.0:80"]
```

### Langkah 2: Konfigurasi Caddyfile untuk CI4

Buat file `Caddyfile`:

```caddyfile
# Caddyfile untuk CodeIgniter 4
{
    telemetry disable
}

:80 {
    # Root directory adalah public folder
    root * /app/public
    
    # Encode responses
    encode gzip
    
    # Serve static files
    file_server
    
    # Rewrite semua request ke index.php dengan query string
    @notfile {
        not path /index.php
        file_try_files /index.php
    }
    rewrite @notfile /index.php
    
    # Handle PHP files
    php_fastcgi localhost:9000
}
```

### Langkah 3: Build Image

```bash
# Build image
podman build -t ci4-frankephp -f Containerfile.frankephp.ci4 .

# Atau dengan buildah
buildah bud -t ci4-frankephp -f Containerfile.frankephp.ci4 .
```

### Langkah 4: Menjalankan Container

```bash
# Jalankan container dengan environment variables
podman run -d \
    --name ci4-app \
    -p 8080:80 \
    -v $(pwd):/app:Z \
    -e CI_ENVIRONMENT=production \
    -e APP_BASEURL=http://localhost:8080/ \
    ci4-frankephp

# Atau dengan interactive mode untuk testing
podman run -it \
    --name ci4-app \
    -p 8080:80 \
    -v $(pwd):/app:Z \
    -e CI_ENVIRONMENT=development \
    ci4-frankephp
```

### Langkah 5: Database Migration (jika diperlukan)

```bash
# Access container shell
podman exec -it ci4-app bash

# Run migrations
php spark migrate

# Run seeders
php spark db:seed SomeSeeder

# Exit
exit
```

### Langkah 6: Testing

```bash
# Test aplikasi
curl http://localhost:8080/
curl http://localhost:8080/api/endpoint

# Lihat logs
podman logs -f ci4-app

# Check container
podman ps
```

### Optimasi Permission untuk Podman Rootless

```bash
# Setup untuk Podman Rootless
podman unshare chown -R $(id -u):$(id -g) $(pwd)

# Run dengan user mapping
podman run -d \
    --userns=keep-id \
    --name ci4-app \
    -p 8080:80 \
    -v $(pwd):/app:Z \
    ci4-frankephp

# Verify permissions
podman exec ci4-app ls -la /app/writable
```

---

## 2.2 Metode Nginx + PHP-FPM

### Deskripsi
Metode production-ready dengan pemisahan antara web server dan PHP interpreter. Sangat scalable dan maintainable.

### Langkah 1: Docker Compose Configuration

Buat file `docker-compose.yml` (atau `podman-compose.yml`):

```yaml
# docker-compose.yml untuk CI4
version: '3.8'

services:
  php-fpm:
    build:
      context: .
      dockerfile: Containerfile.php-fpm.ci4
    container_name: ci4-php-fpm
    networks:
      - ci4-network
    volumes:
      - ./:/app:Z
      - php_socket:/run/php-fpm
    environment:
      - CI_ENVIRONMENT=production
      - APP_BASEURL=http://localhost:8080/
      - PHP_MEMORY_LIMIT=256M
      - PHP_MAX_UPLOAD_SIZE=50M
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "ping", "-c", "1", "127.0.0.1:9000"]
      interval: 30s
      timeout: 10s
      retries: 3

  nginx:
    build:
      context: .
      dockerfile: Containerfile.nginx.ci4
    container_name: ci4-nginx
    ports:
      - "8080:80"
    depends_on:
      - php-fpm
    networks:
      - ci4-network
    volumes:
      - ./:/app:Z
      - php_socket:/run/php-fpm
      - ./nginx-ci4.conf:/etc/nginx/conf.d/default.conf:ro
    restart: unless-stopped

volumes:
  php_socket:

networks:
  ci4-network:
    driver: bridge
```

### Langkah 2: Dockerfile untuk PHP-FPM (CI4)

Buat file `Containerfile.php-fpm.ci4`:

```dockerfile
# Containerfile.php-fpm.ci4
FROM php:8.2-fpm-alpine

WORKDIR /app

# Install system dependencies
RUN apk add --no-cache \
    git \
    curl \
    zip \
    unzip \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libxml2-dev \
    libpq-dev \
    bash

# Install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-install -j$(nproc) \
    gd \
    pdo \
    pdo_mysql \
    pdo_pgsql \
    xml \
    json \
    curl \
    mbstring

# Copy aplikasi
COPY . .

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Install PHP dependencies
RUN composer install --no-dev --optimize-autoloader

# Set permissions
RUN chmod -R 755 . && \
    chmod -R 777 writable && \
    chmod -R 755 public

# Copy PHP-FPM config
COPY php-fpm.conf /usr/local/etc/php-fpm.d/z-custom.conf

# Copy php.ini
COPY php.ini /usr/local/etc/php/conf.d/z-custom.ini

EXPOSE 9000

CMD ["php-fpm"]
```

### Langkah 3: Konfigurasi PHP-FPM

Buat file `php-fpm.conf`:

```ini
# php-fpm.conf untuk CI4
[global]
error_log = /proc/self/fd/2
log_level = warning
daemonize = no

[www]
user = www-data
group = www-data

listen = /run/php-fpm/php-fpm.sock
listen.owner = www-data
listen.group = www-data
listen.mode = 0666

pm = dynamic
pm.max_children = 20
pm.start_servers = 4
pm.min_spare_servers = 2
pm.max_spare_servers = 8
pm.max_requests = 1000

clear_env = no
catch_workers_output = yes
decorate_workers_output = no

; Untuk CodeIgniter
env[SCRIPT_FILENAME] = $document_root$fastcgi_script_name
```

### Langkah 4: Konfigurasi PHP.ini

Buat file `php.ini`:

```ini
# php.ini
memory_limit = 256M
max_execution_time = 30
max_input_time = 60
upload_max_filesize = 50M
post_max_size = 50M
date.timezone = Asia/Jakarta

; Untuk CI4
display_errors = Off
error_log = /proc/self/fd/2

; Sessions
session.save_handler = files
session.save_path = /tmp/php-sessions
session.gc_maxlifetime = 1440

; Extensions yang penting untuk CI4
extension_dir = /usr/local/lib/php/extensions/no-debug-non-zts-20220829
```

### Langkah 5: Dockerfile untuk Nginx (CI4)

Buat file `Containerfile.nginx.ci4`:

```dockerfile
# Containerfile.nginx.ci4
FROM nginx:alpine

WORKDIR /app

# Install bash untuk healthcheck
RUN apk add --no-cache bash

# Copy Nginx config
COPY nginx.conf /etc/nginx/nginx.conf
COPY nginx-ci4.conf /etc/nginx/conf.d/default.conf

# Copy aplikasi
COPY . .

# Expose port
EXPOSE 80

# Healthcheck
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/health || exit 1

CMD ["nginx", "-g", "daemon off;"]
```

### Langkah 6: Konfigurasi Nginx untuk CI4

Buat file `nginx-ci4.conf`:

```nginx
# nginx-ci4.conf untuk CodeIgniter 4
upstream php-fpm {
    server unix:/run/php-fpm/php-fpm.sock;
}

server {
    listen 80;
    server_name _;

    # Root directory adalah public folder (CI4 best practice)
    root /app/public;
    index index.php;

    # Character encoding
    charset utf-8;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_types text/plain text/css text/javascript application/javascript application/json application/xml+rss;
    gzip_min_length 1000;
    gzip_comp_level 6;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Logging
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log warn;

    # Deny access to hidden files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    # Deny access to backup files
    location ~ ~$ {
        deny all;
        access_log off;
        log_not_found off;
    }

    # Deny access to writable folder
    location ~ /writable/ {
        deny all;
        access_log off;
        log_not_found off;
    }

    # Static files caching
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot|font)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "OK";
    }

    # Main application routing untuk CI4
    location / {
        try_files $uri $uri/ /index.php$is_args$args;
    }

    # Handle PHP files
    location ~ \.php$ {
        fastcgi_pass php-fpm;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param REQUEST_METHOD $request_method;
        fastcgi_param REQUEST_URI $request_uri;
        fastcgi_param QUERY_STRING $query_string;
        fastcgi_param SERVER_NAME $server_name;
        fastcgi_param SERVER_PORT $server_port;
        fastcgi_param SERVER_PROTOCOL $server_protocol;
        fastcgi_param HTTP_HOST $http_host;
        
        include fastcgi_params;
        
        # Timeout settings
        fastcgi_connect_timeout 60s;
        fastcgi_send_timeout 60s;
        fastcgi_read_timeout 60s;
    }
}
```

### Langkah 7: Konfigurasi Nginx Utama

Buat file `nginx.conf`:

```nginx
# nginx.conf
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 2048;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    # Performance settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 50M;

    # Buffers
    client_body_buffer_size 10M;
    client_header_buffer_size 1k;
    large_client_header_buffers 4 8k;

    # Hide Nginx version
    server_tokens off;

    # SSL settings (optional)
    # ssl_ciphers HIGH:!aNULL:!MD5;
    # ssl_prefer_server_ciphers on;

    include /etc/nginx/conf.d/*.conf;
}
```

### Langkah 8: Build dan Jalankan

```bash
# Build images
docker-compose build
# atau
podman-compose build

# Jalankan services
docker-compose up -d
# atau
podman-compose up -d

# Lihat logs
docker-compose logs -f
podman-compose logs -f

# Lihat status
docker-compose ps
podman-compose ps
```

### Langkah 9: Running Migrations & Seeders

```bash
# Access PHP-FPM container
docker-compose exec php-fpm bash
# atau
podman-compose exec php-fpm bash

# Inside container:
php spark migrate

# Run specific migration group
php spark migrate --group production

# Run seeders
php spark db:seed

# Specific seeder
php spark db:seed UserSeeder

# Check database
php spark db:table users

# Exit container
exit
```

### Langkah 10: Testing Aplikasi

```bash
# Test main page
curl http://localhost:8080/

# Test with specific route
curl http://localhost:8080/api/users

# Test dengan header
curl -H "Accept: application/json" http://localhost:8080/api/users

# Check logs
docker-compose logs nginx
docker-compose logs php-fpm

# Stop services
docker-compose down

# Stop dengan volume cleanup
docker-compose down -v
```

### Optimasi Permission untuk Podman Rootless

```bash
# Setup user namespace untuk Podman Rootless
podman unshare chown -R $(id -u):$(id -g) $(pwd)

# Set folder permissions
podman unshare chmod -R 777 writable

# Run dengan rootless mode
podman-compose up -d

# Verify
podman exec ci4-php-fpm ls -la /app/writable
podman exec ci4-php-fpm whoami
```

### Backup & Restore Database

```bash
# Backup database
docker-compose exec php-fpm php spark db:backup

# Restore dari backup
docker-compose exec php-fpm php spark db:restore

# Dump database (MySQL)
docker-compose exec php-fpm mysqldump -u user -p database > backup.sql
```

---

# Troubleshooting & Optimasi

## Masalah Umum dan Solusi

### 1. 404 Not Found pada routing CI3/CI4

**Masalah**: Akses route tertentu mengembalikan 404

**Solusi untuk FrankenPHP**:
- Pastikan `Caddyfile` sudah melakukan rewrite dengan benar
- Gunakan `try_files` atau `rewrite` yang tepat
- Check log FrankenPHP: `podman logs ci3-app`

**Solusi untuk Nginx + PHP-FPM**:
- Verifikasi `try_files $uri $uri/ /index.php$is_args$args` di nginx config
- Check Nginx access/error logs
- Pastikan PHP-FPM container berjalan: `podman ps`

```bash
# Restart PHP-FPM
docker-compose restart php-fpm
podman-compose restart php-fpm
```

### 2. Permission Denied pada folder writable/logs

**Masalah**: Application tidak bisa write ke folder tertentu

**Solusi**:
```bash
# Set proper permissions
podman exec ci4-php-fpm chmod -R 777 /app/writable
podman exec ci4-php-fpm chown -R www-data:www-data /app/writable

# Untuk Podman Rootless
podman unshare chmod -R 777 writable
podman unshare chown -R $(id -u):$(id -g) writable
```

### 3. PHP Extensions tidak terinstall

**Masalah**: Fatal error: Call to undefined function

**Solusi**: Tambahkan extension di Dockerfile

```dockerfile
RUN docker-php-ext-install -j$(nproc) \
    pdo_mysql \
    mbstring \
    curl \
    gd
```

Rebuild container:
```bash
docker-compose build --no-cache
podman-compose build --no-cache
```

### 4. Database Connection Error

**Masalah**: SQLSTATE[HY000] [2002] Connection refused

**Solusi**:
- Pastikan database container running (jika ada)
- Check `.env` file untuk database credentials yang benar
- Pastikan host address menggunakan service name (Docker Compose)

Contoh `.env` yang benar:
```
database.default.hostname = db  # (nama service di compose)
database.default.username = root
database.default.password = password
database.default.database = myapp
```

### 5. Memory Limit Exceeded

**Masalah**: Fatal error: Allowed memory size exhausted

**Solusi**: Increase memory limit di `php-fpm.conf` atau `php.ini`

```ini
memory_limit = 512M  ; increase from 256M
```

Rebuild dan restart:
```bash
docker-compose up -d --build
```

### 6. Slow Performance pada File Upload

**Masalah**: Upload besar timeout

**Solusi**:
- Increase PHP timeouts di `php.ini`
- Increase Nginx timeouts di `nginx.conf`
- Increase Nginx client body buffer

```nginx
# nginx.conf
client_max_body_size 100M;
client_body_buffer_size 50M;

# nginx-ci4.conf
fastcgi_read_timeout 300s;
fastcgi_connect_timeout 300s;
```

### 7. CORS Error

**Masalah**: XMLHttpRequest blocked by CORS

**Solusi**: 
- Update CORS configuration di CI4/CI3
- Tambahkan header di Nginx:

```nginx
# nginx-ci4.conf
add_header 'Access-Control-Allow-Origin' '*' always;
add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
add_header 'Access-Control-Allow-Headers' 'Content-Type' always;

if ($request_method = 'OPTIONS') {
    return 204;
}
```

## Optimasi Performa

### 1. Enable Caching

```nginx
# Static files dengan long expiry
location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
    expires 30d;
    add_header Cache-Control "public, immutable";
}
```

### 2. Compress Responses

Sudah enabled di config, tapi bisa di-tune:

```nginx
gzip on;
gzip_comp_level 6;  # 1-9, lebih tinggi = lebih kecil tapi lebih CPU
gzip_min_length 1000;  # Hanya compress >= 1000 bytes
```

### 3. PHP-FPM Process Management

Adjust berdasarkan traffic:

```ini
[www]
pm = dynamic
pm.max_children = 20      # Total process
pm.start_servers = 4      # Initial process
pm.min_spare_servers = 2  # Min idle
pm.max_spare_servers = 8  # Max idle
pm.max_requests = 1000    # Recycle after N requests
```

### 4. Database Query Optimization

- Enable query cache di database
- Use proper indexes
- Use CodeIgniter's `->cache()` method

```php
// CI4
$users = $this->db->table('users')->cache(3600)->get()->getResultArray();
```

### 5. Container Resource Limits

Buat file `docker-compose.override.yml`:

```yaml
version: '3.8'

services:
  php-fpm:
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 512M
        reservations:
          cpus: '0.5'
          memory: 256M

  nginx:
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 256M
```

## Security Best Practices

### 1. Update Docker Images Regularly

```bash
# Check for updates
docker pull php:8.2-fpm-alpine
docker pull nginx:alpine
docker pull dunglas/frankenphp:latest-alpine

# Rebuild with latest base images
docker-compose build --no-cache
```

### 2. Remove Debug Information

Di `php.ini`:
```ini
display_errors = Off
error_reporting = E_ALL
log_errors = On
error_log = /var/log/php-error.log
```

### 3. Use `.env` untuk Secrets

Jangan commit `.env` file:
```bash
echo ".env" >> .gitignore
echo ".env.local" >> .gitignore

# Create .env.example
cp .env .env.example
# Remove sensitive data dari .env.example
```

### 4. Restrict File Permissions

```bash
# Make files read-only where possible
find . -type f -exec chmod 644 {} \;
find . -type d -exec chmod 755 {} \;

# Writable folders
chmod 777 writable logs cache temp
```

### 5. Use nginx Security Headers

Sudah included di config, tapi verifikasi:
```bash
curl -I http://localhost:8080
# Check untuk X-Frame-Options, X-Content-Type-Options, dll
```

## Monitoring dan Logging

### 1. Check Logs

```bash
# Combined logs
docker-compose logs -f --tail=100

# Specific service
docker-compose logs -f nginx
docker-compose logs -f php-fpm

# With timestamps
docker-compose logs -f --timestamps

# Last 50 lines
docker-compose logs --tail=50
```

### 2. Monitor Container Resources

```bash
# CPU dan memory usage
docker stats

# Atau untuk Podman
podman stats

# Dengan specific container
docker stats ci4-nginx ci4-php-fpm
```

### 3. Health Checks

```bash
# Check container health
docker-compose ps

# Manual health check
curl -I http://localhost:8080/health

# Check PHP-FPM health
docker-compose exec php-fpm php -v
docker-compose exec php-fpm php -m  # Lihat loaded extensions
```

## Deployment ke Production

### 1. Environment Variables untuk Production

```bash
# .env.production
CI_ENVIRONMENT=production
APP_BASEURL=https://yourdomain.com/
database.default.hostname=db-prod.internal
database.default.username=user
database.default.password=secure_password
```

### 2. SSL/HTTPS dengan Let's Encrypt

Tambahkan ke `docker-compose.yml`:

```yaml
  nginx:
    # ... existing config
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx-ci4.conf:/etc/nginx/conf.d/default.conf:ro
      - ./certbot/conf:/etc/letsencrypt:ro
      - ./certbot/www:/var/www/certbot:ro

  certbot:
    image: certbot/certbot
    volumes:
      - ./certbot/conf:/etc/letsencrypt
      - ./certbot/www:/var/www/certbot
    command: certonly --webroot -w /var/www/certbot --email you@example.com -d yourdomain.com
```

### 3. Automated Backups

```bash
# Backup script
#!/bin/bash
BACKUP_DIR="/backups/ci4"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup database
docker-compose exec -T php-fpm php spark db:backup > $BACKUP_DIR/db_$DATE.sql

# Backup files
tar -czf $BACKUP_DIR/app_$DATE.tar.gz ./

echo "Backup completed: $BACKUP_DIR"
```

---

## Quick Reference Commands

```bash
# Build & Run
docker-compose up -d --build
podman-compose up -d --build

# Stop & Remove
docker-compose down
podman-compose down

# View logs
docker-compose logs -f
podman-compose logs -f

# Execute command in container
docker-compose exec php-fpm php spark
podman-compose exec php-fpm php spark

# SSH ke container
docker-compose exec nginx sh
podman-compose exec nginx sh

# Check services status
docker-compose ps
podman-compose ps

# Clean up unused resources
docker system prune -a
podman system prune -a

# Rebuild specific service
docker-compose up -d --build php-fpm
podman-compose up -d --build php-fpm

# View container resource usage
docker stats
podman stats
```

---

## Kesimpulan

Panduan ini telah mencakup:

✅ **CodeIgniter 3** dengan FrankenPHP dan Nginx + PHP-FPM  
✅ **CodeIgniter 4** dengan FrankenPHP dan Nginx + PHP-FPM  
✅ Konfigurasi routing yang tepat untuk setiap setup  
✅ Permission handling untuk Podman Rootless  
✅ Troubleshooting dan optimization  
✅ Security best practices  
✅ Deployment guidelines  

Pilih metode yang sesuai dengan kebutuhan Anda:
- **FrankenPHP**: Lebih sederhana, cocok untuk development dan skala kecil
- **Nginx + PHP-FPM**: Lebih professional, scalable, cocok untuk production

Semoga panduan ini membantu! 🚀
