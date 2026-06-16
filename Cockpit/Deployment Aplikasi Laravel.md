# 🚀 Laravel Containerization Guide: FrankenPHP vs Nginx+PHP-FPM
## Production-Ready Deployment dengan Podman

---

## 📋 Daftar Isi
1. [Skenario 1: FrankenPHP (Worker Mode)](#skenario-1-frankenphp-worker-mode)
2. [Skenario 2: Nginx + PHP-FPM](#skenario-2-nginx--php-fpm)
3. [Perbandingan & Rekomendasi](#perbandingan--rekomendasi)
4. [Deployment Best Practices](#deployment-best-practices)
5. [Monitoring & Debugging](#monitoring--debugging)
6. [Production Checklist](#production-checklist)

---

## 🎯 Skenario 1: FrankenPHP (Worker Mode)

### Overview FrankenPHP
FrankenPHP adalah runtime PHP modern yang dibangun dengan Go, memberikan performa tinggi dengan fitur:
- **Worker Mode** - Server tetap hidup, reuse container untuk multiple requests
- **Built-in Caddy** - Web server terintegrasi dengan SSL/TLS otomatis
- **Modern PHP** - Support PHP 8.2, 8.3 dengan fitur terbaru
- **Single Container** - Deployment sederhana, lebih cepat startup

---

### 1.1 Multi-Stage Containerfile untuk FrankenPHP

```dockerfile
# =============================================================================
# STAGE 1: Builder - Persiapkan aplikasi Laravel
# =============================================================================
FROM alpine:3.18 AS builder

WORKDIR /app

# Install dependencies build
RUN apk add --no-cache \
    curl \
    git \
    composer \
    nodejs \
    npm

# Copy hanya file yang diperlukan composer
COPY composer.json composer.lock ./

# Install PHP dependencies (production)
RUN composer install \
    --no-dev \
    --prefer-dist \
    --optimize-autoloader \
    --no-interaction

# Copy seluruh aplikasi
COPY . .

# Build frontend assets
RUN npm install --frozen-lockfile && \
    npm run build && \
    npm cache clean --force

# Generate optimized app config
RUN php artisan config:cache && \
    php artisan route:cache && \
    php artisan view:cache

# =============================================================================
# STAGE 2: FrankenPHP Production Image
# =============================================================================
FROM dunglas/frankenphp:latest-alpine

# Set environment sebagai production
ENV APP_ENV=production \
    APP_DEBUG=false \
    FRANKENPHP_CONFIG="worker ./public/index.php"

WORKDIR /app

# Install system dependencies
RUN apk add --no-cache \
    bash \
    curl \
    git \
    ca-certificates \
    postgresql-client \
    mysql-client \
    redis

# Install PHP extensions (FrankenPHP support)
RUN install-php-extensions \
    pdo \
    pdo_mysql \
    pdo_pgsql \
    bcmath \
    mbstring \
    gd \
    opcache \
    zip \
    intl \
    json \
    curl \
    fileinfo \
    exif

# Copy Composer dari builder
COPY --from=builder --chown=www-data:www-data /app/vendor ./vendor

# Copy installed npm packages dan built assets
COPY --from=builder --chown=www-data:www-data /app/node_modules ./node_modules
COPY --from=builder --chown=www-data:www-data /app/public ./public

# Copy aplikasi
COPY --chown=www-data:www-data . .

# Create required directories dengan permissions
RUN mkdir -p \
    bootstrap/cache \
    storage/logs \
    storage/framework/cache \
    storage/framework/sessions \
    storage/framework/views && \
    chown -R www-data:www-data bootstrap storage

# Configure Opcache untuk Production
RUN echo '[opcache]' > /usr/local/etc/php/conf.d/opcache.ini && \
    echo 'opcache.enable=1' >> /usr/local/etc/php/conf.d/opcache.ini && \
    echo 'opcache.memory_consumption=256' >> /usr/local/etc/php/conf.d/opcache.ini && \
    echo 'opcache.interned_strings_buffer=16' >> /usr/local/etc/php/conf.d/opcache.ini && \
    echo 'opcache.max_accelerated_files=10000' >> /usr/local/etc/php/conf.d/opcache.ini && \
    echo 'opcache.validate_timestamps=0' >> /usr/local/etc/php/conf.d/opcache.ini && \
    echo 'opcache.save_comments=0' >> /usr/local/etc/php/conf.d/opcache.ini

# Configure FrankenPHP untuk Worker Mode
RUN echo '[PHP]' > /usr/local/etc/php/conf.d/frankenphp.ini && \
    echo 'max_execution_time=30' >> /usr/local/etc/php/conf.d/frankenphp.ini && \
    echo 'post_max_size=100M' >> /usr/local/etc/php/conf.d/frankenphp.ini && \
    echo 'upload_max_filesize=100M' >> /usr/local/etc/php/conf.d/frankenphp.ini

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:80/health || exit 1

# Switch to non-root user
USER www-data

# Expose port
EXPOSE 80 443

# Run FrankenPHP Worker Mode
CMD ["frankenphp", "run", "--config", "/etc/caddy/Caddyfile"]
```

---

### 1.2 Caddyfile Configuration untuk FrankenPHP

Buat file `Caddyfile` di root Laravel:

```caddyfile
# Caddyfile - Konfigurasi untuk FrankenPHP

{
    # Global options
    admin off
    auto_https off
}

:80 {
    # Root directory
    root * /app/public
    
    # Laravel index handler
    file_server
    
    # Route semua request ke Laravel
    rewrite * /index.php?{query}
    
    # PHP handler (built-in dalam FrankenPHP)
    php_fastcgi unix//var/run/php/frankenphp.sock {
        env APP_ENV production
        env APP_DEBUG false
        capture_errors on
    }
    
    # Security headers
    header {
        # Prevent MIME sniffing
        X-Content-Type-Options "nosniff"
        
        # Enable XSS protection
        X-XSS-Protection "1; mode=block"
        
        # Prevent clickjacking
        X-Frame-Options "SAMEORIGIN"
        
        # Referrer policy
        Referrer-Policy "strict-origin-when-cross-origin"
        
        # Permissions policy
        Permissions-Policy "geolocation=(), microphone=(), camera=()"
        
        # HSTS (Strict-Transport-Security) untuk HTTPS
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
    }
    
    # Compress responses
    encode gzip
    
    # Caching static assets
    @static {
        path /js/* /css/* /images/* /fonts/*
    }
    
    header @static Cache-Control "public, max-age=31536000, immutable"
    
    # Deny access ke file sensitif
    @sensitive {
        path /.env* /.git* /storage/* /bootstrap/cache/*
    }
    
    respond @sensitive "Not Found" 404
    
    # Logs
    log {
        output stdout
        format single_field common_log
    }
}

# HTTPS configuration (optional, dengan auto-renewal)
# https:// {
#     tls internal
#     # ... rest of config
# }
```

---

### 1.3 Build FrankenPHP Image

```bash
# Build image
podman build -f Containerfile -t laravel-frankenphp:1.0 .

# Verify build
podman images | grep laravel-frankenphp

# Test image locally
podman run --rm \
  -it \
  -p 8080:80 \
  laravel-frankenphp:1.0
```

---

### 1.4 Deploy FrankenPHP Container

#### A. Basic Deployment
```bash
# Run container dengan network custom
podman run -d \
  --name laravel-app \
  --network app-network \
  -p 8080:80 \
  -p 8443:443 \
  \
  # Volume mounts
  -v laravel-env:/app/.env \
  -v laravel-storage:/app/storage \
  -v laravel-cache:/app/bootstrap/cache \
  -v laravel-logs:/app/storage/logs \
  \
  # Environment variables
  -e APP_KEY=base64:your-app-key \
  -e APP_URL=https://laravel.example.com \
  -e LOG_CHANNEL=stack \
  -e LOG_LEVEL=info \
  -e DB_HOST=postgres-db \
  -e DB_PORT=5432 \
  -e DB_DATABASE=laravel \
  -e DB_USERNAME=laravel_user \
  -e DB_PASSWORD=secure_password \
  -e CACHE_DRIVER=redis \
  -e SESSION_DRIVER=redis \
  -e REDIS_HOST=redis-cache \
  -e REDIS_PORT=6379 \
  \
  # Restart policy
  --restart unless-stopped \
  \
  # Resource limits
  --memory 1g \
  --memory-swap 1.5g \
  --cpus 2 \
  \
  # Health check
  --health-cmd='curl -f http://localhost:80/health || exit 1' \
  --health-interval=30s \
  --health-timeout=10s \
  --health-start-period=5s \
  --health-retries=3 \
  \
  # Logging
  --log-driver journald \
  \
  laravel-frankenphp:1.0
```

#### B. Advanced: Dengan SSL/TLS via Caddy

Edit Caddyfile:
```caddyfile
laravel.example.com {
    root * /app/public
    file_server
    rewrite * /index.php?{query}
    
    php_fastcgi unix//var/run/php/frankenphp.sock {
        env APP_ENV production
    }
    
    # TLS Configuration
    tls {
        issuer acme {
            email admin@example.com
        }
    }
    
    # Security headers
    header {
        X-Content-Type-Options "nosniff"
        X-XSS-Protection "1; mode=block"
        X-Frame-Options "SAMEORIGIN"
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
    }
}
```

Deploy dengan port 443:
```bash
podman run -d \
  --name laravel-app \
  -p 80:80 \
  -p 443:443 \
  -v laravel-storage:/app/storage \
  -v laravel-env:/app/.env \
  --restart unless-stopped \
  laravel-frankenphp:1.0
```

#### C. Dengan Docker-Compose / Podman-Compose

Buat `docker-compose.yml`:

```yaml
version: '3.8'

services:
  # FrankenPHP Application
  laravel:
    build:
      context: .
      dockerfile: Containerfile
    container_name: laravel-app
    restart: unless-stopped
    working_dir: /app
    networks:
      - laravel-network
    ports:
      - "80:80"
      - "443:443"
    environment:
      APP_ENV: production
      APP_DEBUG: "false"
      APP_KEY: ${APP_KEY}
      APP_URL: ${APP_URL}
      DB_HOST: postgres
      DB_PORT: 5432
      DB_DATABASE: ${DB_DATABASE}
      DB_USERNAME: ${DB_USERNAME}
      DB_PASSWORD: ${DB_PASSWORD}
      CACHE_DRIVER: redis
      SESSION_DRIVER: redis
      REDIS_HOST: redis
      REDIS_PORT: 6379
    volumes:
      - ./storage:/app/storage
      - ./bootstrap/cache:/app/bootstrap/cache
      - ./.env:/app/.env:ro
      - ./logs:/app/storage/logs
    depends_on:
      - postgres
      - redis
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 5s

  # PostgreSQL Database
  postgres:
    image: postgres:15-alpine
    container_name: laravel-postgres
    restart: unless-stopped
    networks:
      - laravel-network
    environment:
      POSTGRES_DB: ${DB_DATABASE}
      POSTGRES_USER: ${DB_USERNAME}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - postgres-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USERNAME}"]
      interval: 10s
      timeout: 5s
      retries: 5

  # Redis Cache
  redis:
    image: redis:7-alpine
    container_name: laravel-redis
    restart: unless-stopped
    networks:
      - laravel-network
    command: redis-server --appendonly yes
    volumes:
      - redis-data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

networks:
  laravel-network:
    driver: bridge

volumes:
  postgres-data:
  redis-data:
```

Deploy:
```bash
# Create .env file
cp .env.example .env

# Deploy stack
podman-compose up -d

# Check status
podman-compose ps

# View logs
podman-compose logs -f laravel
```

---

### 1.5 Database Migration & Setup

```bash
# Run artisan commands dalam container
podman exec laravel-app php artisan migrate

# Seed database
podman exec laravel-app php artisan db:seed

# Create cache tables
podman exec laravel-app php artisan cache:table

# Create queue tables
podman exec laravel-app php artisan queue:table

# Generate app key jika belum
podman exec laravel-app php artisan key:generate

# Verify application
podman exec laravel-app php artisan tinker
# Kemudian test: php > DB::connection()->getPdo()
```

---

## 🐳 Skenario 2: Nginx + PHP-FPM

### Overview
Traditional setup dengan Nginx dan PHP-FPM yang terpisah, memberikan fleksibilitas dan kontrol lebih.

**Opsi A**: Two Separate Containers (Recommended untuk production)
**Opsi B**: Single Container dengan Supervisor (Simplified setup)

---

### 2.1 Containerfile untuk PHP-FPM

```dockerfile
# =============================================================================
# STAGE 1: Builder
# =============================================================================
FROM alpine:3.18 AS builder

WORKDIR /app

RUN apk add --no-cache \
    curl \
    git \
    composer \
    nodejs \
    npm \
    php \
    php-composer

COPY composer.json composer.lock ./

RUN composer install \
    --no-dev \
    --prefer-dist \
    --optimize-autoloader \
    --no-interaction

COPY . .

RUN npm install --frozen-lockfile && \
    npm run build && \
    npm cache clean --force

# =============================================================================
# STAGE 2: PHP-FPM Production
# =============================================================================
FROM php:8.3-fpm-alpine

WORKDIR /app

# Install system dependencies
RUN apk add --no-cache \
    bash \
    curl \
    git \
    ca-certificates \
    postgresql-client \
    mysql-client \
    redis \
    supervisor

# Install PHP extensions via pecl dan docker-php-ext-install
RUN apk add --no-cache --virtual .build-deps \
    autoconf \
    gcc \
    g++ \
    make \
    pcre-dev && \
    \
    docker-php-ext-install \
    pdo \
    pdo_mysql \
    pdo_pgsql \
    bcmath \
    mbstring \
    gd \
    zip \
    intl \
    exif \
    curl \
    fileinfo && \
    \
    pecl install redis opcache && \
    docker-php-ext-enable redis opcache && \
    \
    apk del .build-deps

# Configure Opcache untuk Production
COPY opcache.ini /usr/local/etc/php/conf.d/opcache.ini

# Configure PHP-FPM
COPY php-fpm.conf /usr/local/etc/php-fpm.conf
COPY www.conf /usr/local/etc/php-fpm.d/www.conf

# Copy dari builder
COPY --from=builder --chown=www-data:www-data /app/vendor ./vendor
COPY --from=builder --chown=www-data:www-data /app/node_modules ./node_modules
COPY --from=builder --chown=www-data:www-data /app/public ./public
COPY --chown=www-data:www-data . .

# Create required directories
RUN mkdir -p \
    bootstrap/cache \
    storage/logs \
    storage/framework/cache \
    storage/framework/sessions \
    storage/framework/views && \
    chown -R www-data:www-data bootstrap storage

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:9000/ping || exit 1

EXPOSE 9000

CMD ["php-fpm"]
```

**File: `opcache.ini`**
```ini
[opcache]
opcache.enable=1
opcache.memory_consumption=256
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=10000
opcache.validate_timestamps=0
opcache.save_comments=0
opcache.revalidate_freq=0
opcache.preload=/app/bootstrap/cache/opcache.preload.php
opcache.preload_user=www-data
```

**File: `php-fpm.conf`**
```ini
[global]
; PID file location
pid = /var/run/php-fpm.pid

; Error log
error_log = /proc/self/fd/2
log_level = warning

[www]
; Listen on TCP socket untuk komunikasi dengan Nginx
listen = 0.0.0.0:9000
listen.backlog = 65535

; Access log
access.log = /proc/self/fd/2

; User
user = www-data
group = www-data

; Process management
pm = dynamic
pm.max_children = 20
pm.start_servers = 5
pm.min_spare_servers = 2
pm.max_spare_servers = 8
pm.process_idle_timeout = 10s
pm.max_requests = 1000
pm.max_requests_grace_period = 30s

; Env variables
catch_workers_output = yes
decorate_workers_output = yes

; Status page
pm.status_path = /status
ping.path = /ping
ping.response = pong

; Security
clear_env = no
```

---

### 2.2 Containerfile untuk Nginx

```dockerfile
# =============================================================================
# Nginx Web Server untuk Laravel
# =============================================================================
FROM nginx:1.25-alpine

WORKDIR /app

# Install curl untuk health check
RUN apk add --no-cache curl

# Copy custom nginx config
COPY nginx.conf /etc/nginx/nginx.conf
COPY laravel.conf /etc/nginx/conf.d/default.conf

# Create required directories
RUN mkdir -p /var/log/nginx && \
    touch /var/log/nginx/access.log /var/log/nginx/error.log && \
    chown -R nginx:nginx /var/log/nginx

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/health || exit 1

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]
```

**File: `nginx.conf`**
```nginx
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

    # Performance optimization
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 100M;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript 
               application/json application/javascript application/xml+rss 
               application/atom+xml image/svg+xml;

    include /etc/nginx/conf.d/*.conf;
}
```

**File: `laravel.conf`** (Nginx server config untuk Laravel)
```nginx
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    server_name _;
    
    root /app/public;
    index index.php index.html index.htm;

    # Charset
    charset utf-8;

    # Security headers
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;

    # HSTS untuk HTTPS (enable hanya untuk production dengan SSL)
    # add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Health check endpoint
    location ~ ^/(health|status)$ {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    # Deny access ke hidden files dan directories
    location ~ /\. {
        deny all;
    }

    # Deny access ke .env dan sensitif files
    location ~ /\.env {
        deny all;
    }

    location ~ /\.git {
        deny all;
    }

    # Cache static files
    location ~ ^/(js|css|images|fonts)(/|$) {
        expires 30d;
        add_header Cache-Control "public, immutable";
        try_files $uri =404;
    }

    # Main Laravel routing
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    # PHP handler - pass ke PHP-FPM container
    location ~ \.php$ {
        fastcgi_pass php-fpm:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        
        # Standard FastCGI params
        include fastcgi_params;
        fastcgi_param PATH_INFO $fastcgi_path_info;
        fastcgi_param PATH_TRANSLATED $document_root$fastcgi_path_info;
        
        # Timeouts
        fastcgi_connect_timeout 60s;
        fastcgi_send_timeout 60s;
        fastcgi_read_timeout 60s;
        
        # Buffering
        fastcgi_buffering on;
        fastcgi_buffers 8 16k;
        fastcgi_buffer_size 32k;
        fastcgi_busy_buffers_size 64k;
        fastcgi_temp_file_write_size 64k;
    }

    # Deny executing PHP in upload/storage directories
    location ~ ^/storage/.*\.php$ {
        deny all;
    }

    # Laravel public disk (storage symlink)
    location ~ ^/storage {
        alias /app/storage/app/public;
        expires 30d;
        add_header Cache-Control "public";
    }

    # Error pages
    error_page 404 /index.php;
    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        root /usr/share/nginx/html;
    }
}
```

---

### 2.3 Build Nginx & PHP-FPM Images

```bash
# Build PHP-FPM image
podman build \
  -f Containerfile.php \
  -t laravel-php-fpm:1.0 \
  .

# Build Nginx image
podman build \
  -f Containerfile.nginx \
  -t laravel-nginx:1.0 \
  .

# Verify builds
podman images | grep laravel
```

---

### 2.4 Deploy Option A: Two Separate Containers

#### A. Create Custom Network
```bash
podman network create laravel-network \
  --subnet 10.0.9.0/24 \
  --gateway 10.0.9.1
```

#### B. Run PHP-FPM Container
```bash
podman run -d \
  --name laravel-php-fpm \
  --network laravel-network \
  \
  # Volume mounts
  -v laravel-app:/app \
  -v laravel-env:/app/.env \
  -v laravel-storage:/app/storage \
  -v laravel-cache:/app/bootstrap/cache \
  -v laravel-logs:/app/storage/logs \
  \
  # Environment variables
  -e APP_ENV=production \
  -e APP_DEBUG=false \
  -e APP_KEY=base64:your-app-key \
  -e DB_HOST=postgres-db \
  -e DB_DATABASE=laravel \
  -e DB_USERNAME=laravel_user \
  -e DB_PASSWORD=secure_password \
  -e CACHE_DRIVER=redis \
  -e REDIS_HOST=redis-cache \
  \
  # Resource limits
  --memory 512m \
  --memory-swap 768m \
  --cpus 1 \
  \
  # Restart policy
  --restart unless-stopped \
  \
  # Health check
  --health-cmd='curl -f http://localhost:9000/ping || exit 1' \
  --health-interval=30s \
  --health-timeout=10s \
  --health-retries=3 \
  \
  laravel-php-fpm:1.0
```

#### C. Run Nginx Container
```bash
podman run -d \
  --name laravel-nginx \
  --network laravel-network \
  \
  # Port mapping
  -p 80:80 \
  -p 443:443 \
  \
  # Volume mounts (read-only untuk nginx)
  -v laravel-app:/app:ro \
  -v laravel-storage:/app/storage:ro \
  \
  # Resource limits
  --memory 256m \
  --memory-swap 384m \
  --cpus 1 \
  \
  # Restart policy
  --restart unless-stopped \
  \
  # Health check
  --health-cmd='curl -f http://localhost/health || exit 1' \
  --health-interval=30s \
  --health-timeout=10s \
  --health-retries=3 \
  \
  laravel-nginx:1.0
```

#### D. Verify Communication
```bash
# Nginx to PHP-FPM resolution
podman exec laravel-nginx \
  nslookup laravel-php-fpm

# Test PHP-FPM ping
podman exec laravel-nginx \
  wget http://laravel-php-fpm:9000/ping -O -

# Test full application
curl -v http://localhost
```

---

### 2.5 Deploy Option B: Single Container dengan Supervisor

```dockerfile
# =============================================================================
# Single Container: Nginx + PHP-FPM dengan Supervisor
# =============================================================================
FROM php:8.3-fpm-alpine

WORKDIR /app

# Install dependencies
RUN apk add --no-cache \
    bash \
    curl \
    git \
    ca-certificates \
    nginx \
    supervisor \
    postgresql-client \
    mysql-client

# Install PHP extensions
RUN docker-php-ext-install \
    pdo pdo_mysql pdo_pgsql \
    bcmath mbstring gd zip intl exif curl fileinfo && \
    pecl install redis opcache && \
    docker-php-ext-enable redis opcache

# Copy configurations
COPY php-fpm-single.conf /usr/local/etc/php-fpm.conf
COPY laravel.conf /etc/nginx/conf.d/default.conf
COPY supervisord.conf /etc/supervisord.conf

# Copy application
COPY --chown=www-data:www-data . .

# Create directories
RUN mkdir -p bootstrap/cache storage/{logs,framework/cache,framework/sessions,framework/views} && \
    chown -R www-data:www-data bootstrap storage

# Expose ports
EXPOSE 80 443

# Start supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
```

**File: `supervisord.conf`**
```ini
[supervisord]
nodaemon=true
logfile=/var/log/supervisor/supervisord.log
pidfile=/var/run/supervisord.pid

[program:php-fpm]
command=php-fpm
autostart=true
autorestart=true
stderr_logfile=/var/log/supervisor/php-fpm.err.log
stdout_logfile=/var/log/supervisor/php-fpm.out.log

[program:nginx]
command=/usr/sbin/nginx -g "daemon off;"
autostart=true
autorestart=true
stderr_logfile=/var/log/supervisor/nginx.err.log
stdout_logfile=/var/log/supervisor/nginx.out.log
stopasgroup=true
killasgroup=true
```

Deploy single container:
```bash
podman build -f Containerfile.single -t laravel-all-in-one:1.0 .

podman run -d \
  --name laravel-app \
  -p 80:80 \
  -p 443:443 \
  -v laravel-env:/app/.env \
  -v laravel-storage:/app/storage \
  -v laravel-cache:/app/bootstrap/cache \
  --restart unless-stopped \
  laravel-all-in-one:1.0
```

---

### 2.6 Docker-Compose untuk Nginx + PHP-FPM

```yaml
version: '3.8'

services:
  # PHP-FPM
  php-fpm:
    build:
      context: .
      dockerfile: Containerfile.php
    container_name: laravel-php-fpm
    restart: unless-stopped
    networks:
      - laravel-network
    working_dir: /app
    environment:
      APP_ENV: production
      APP_DEBUG: "false"
      APP_KEY: ${APP_KEY}
      DB_HOST: postgres
      DB_DATABASE: ${DB_DATABASE}
      DB_USERNAME: ${DB_USERNAME}
      DB_PASSWORD: ${DB_PASSWORD}
      CACHE_DRIVER: redis
      REDIS_HOST: redis
    volumes:
      - ./:/app
      - ./storage:/app/storage
      - ./bootstrap/cache:/app/bootstrap/cache
      - ./.env:/app/.env:ro
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/ping"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Nginx Web Server
  nginx:
    build:
      context: .
      dockerfile: Containerfile.nginx
    container_name: laravel-nginx
    restart: unless-stopped
    networks:
      - laravel-network
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./public:/app/public:ro
      - ./storage:/app/storage:ro
      - ./:/app:ro
    depends_on:
      - php-fpm
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # PostgreSQL
  postgres:
    image: postgres:15-alpine
    container_name: laravel-postgres
    restart: unless-stopped
    networks:
      - laravel-network
    environment:
      POSTGRES_DB: ${DB_DATABASE}
      POSTGRES_USER: ${DB_USERNAME}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - postgres-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USERNAME}"]
      interval: 10s
      timeout: 5s
      retries: 5

  # Redis
  redis:
    image: redis:7-alpine
    container_name: laravel-redis
    restart: unless-stopped
    networks:
      - laravel-network
    command: redis-server --appendonly yes
    volumes:
      - redis-data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

networks:
  laravel-network:
    driver: bridge

volumes:
  postgres-data:
  redis-data:
```

Deploy:
```bash
podman-compose up -d
podman-compose logs -f
```

---

## 📊 Perbandingan & Rekomendasi

### Tabel Perbandingan

| Aspek | FrankenPHP | Nginx + PHP-FPM |
|-------|-----------|-----------------|
| **Kompleksitas** | Sederhana (1 container) | Lebih kompleks (2+ containers) |
| **Performa** | Excellent (Worker mode) | Excellent (Proven setup) |
| **Startup Time** | ⚡ Cepat | ⚡⚡ Lebih cepat |
| **Memory** | ~150-200MB | ~250-300MB |
| **Scalability** | Load balancer di belakang | Horizontal scale easy |
| **Flexibility** | Limited | Very flexible |
| **Learning Curve** | Mudah | Standar |
| **Production Ready** | ✅ Yes | ✅ Yes |
| **Debugging** | Mudah | Mudah |

### Rekomendasi Pemilihan

**Gunakan FrankenPHP jika:**
- ✅ Aplikasi sederhana/medium
- ✅ Ingin minimal container
- ✅ Setup modern, minimal config
- ✅ Performance adalah priority
- ✅ Team familiar dengan Go/modern PHP

**Gunakan Nginx + PHP-FPM jika:**
- ✅ Aplikasi large/complex
- ✅ Perlu granular control per service
- ✅ Plan untuk horizontal scaling
- ✅ Team familiar dengan nginx
- ✅ Legacy sistem yang sudah running

---

## 🚀 Deployment Best Practices

### 1. Environment Management

```bash
# Create .env file dengan secure defaults
cat > .env << 'EOF'
APP_ENV=production
APP_DEBUG=false
APP_NAME=Laravel
APP_KEY=base64:your-app-key-here

# Database
DB_HOST=postgres-db
DB_PORT=5432
DB_DATABASE=laravel_db
DB_USERNAME=laravel_user
DB_PASSWORD=SECURE_PASSWORD_HERE

# Redis
CACHE_DRIVER=redis
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis
REDIS_HOST=redis-cache
REDIS_PORT=6379

# Log
LOG_CHANNEL=stack
LOG_LEVEL=notice

# Mail (jika diperlukan)
MAIL_DRIVER=smtp
MAIL_HOST=smtp.mailtrap.io
MAIL_PORT=465
MAIL_USERNAME=your_username
MAIL_PASSWORD=your_password

# Queue
QUEUE_CONNECTION=redis
EOF

# Set permissions
chmod 600 .env
```

### 2. Volume Strategy

```bash
# Create named volumes
podman volume create laravel-env
podman volume create laravel-storage
podman volume create laravel-cache
podman volume create laravel-logs
podman volume create postgres-data
podman volume create redis-data

# Backup volumes
podman volume inspect laravel-storage
sudo tar czf storage-backup.tar.gz /var/lib/containers/storage/volumes/laravel-storage/
```

### 3. Networking Security

```bash
# Create isolated network
podman network create \
  --subnet 10.0.9.0/24 \
  --gateway 10.0.9.1 \
  --opt="com.docker.network.driver.mtu=1500" \
  laravel-network

# Containers dalam network tidak exposed ke docker bridge
# Hanya port mapping yang explicitly expose
```

### 4. Resource Limits (Production)

```bash
# FrankenPHP (single container)
podman run -d \
  --memory 2g \
  --memory-swap 3g \
  --cpus 2 \
  --pids-limit 500 \
  ...

# PHP-FPM
podman run -d \
  --memory 1g \
  --cpus 1 \
  ...

# Nginx
podman run -d \
  --memory 256m \
  --cpus 0.5 \
  ...
```

### 5. Logging Strategy

```bash
# Centralized logging ke journald
podman run -d \
  --log-driver journald \
  --log-opt labels=app,version,service \
  ...

# View logs
journalctl CONTAINER_NAME=laravel-app -f

# Or use docker/podman logs
podman logs -f --tail 100 laravel-app
```

### 6. Health Checks

```bash
# Endpoint /health harus return 200
# File: routes/web.php
Route::get('/health', function () {
    try {
        // Check database
        DB::connection()->getPdo();
        
        // Check cache
        Cache::get('test');
        
        return response()->json(['status' => 'ok'], 200);
    } catch (\Exception $e) {
        return response()->json(['status' => 'error', 'message' => $e->getMessage()], 500);
    }
});
```

### 7. Backup Strategy

```bash
#!/bin/bash
# backup-laravel.sh

BACKUP_DIR="/backups/laravel"
DATE=$(date +%Y%m%d_%H%M%S)

# Database backup
podman exec laravel-postgres pg_dump -U laravel_user laravel_db \
  | gzip > $BACKUP_DIR/db_$DATE.sql.gz

# Storage backup
podman run --rm -v laravel-storage:/storage -v $BACKUP_DIR:/backup \
  alpine tar czf /backup/storage_$DATE.tar.gz -C /storage .

# Config backup
tar czf $BACKUP_DIR/config_$DATE.tar.gz .env

echo "Backup completed: $BACKUP_DIR"
```

---

## 📈 Monitoring & Debugging

### 1. Container Logs

```bash
# Follow logs
podman logs -f laravel-app

# Last N lines
podman logs --tail 50 laravel-app

# With timestamps
podman logs -t laravel-app

# Specific time range
podman logs --since 10m laravel-app
```

### 2. Realtime Monitoring

```bash
# Stats real-time
podman stats laravel-app

# Detailed inspection
podman inspect laravel-app | jq '.'

# Process monitoring
podman top laravel-app -eo pid,user,%cpu,%mem,comm
```

### 3. Execute Commands dalam Container

```bash
# Laravel artisan
podman exec laravel-php-fpm php artisan migrate
podman exec laravel-php-fpm php artisan cache:clear
podman exec laravel-php-fpm php artisan view:cache

# Database operations
podman exec laravel-postgres psql -U laravel_user -d laravel_db

# Redis operations
podman exec laravel-redis redis-cli
```

### 4. Debugging

```bash
# Check DNS resolution
podman exec laravel-nginx nslookup php-fpm

# Test network connectivity
podman exec laravel-nginx wget http://php-fpm:9000/ping -O -

# Check mounted volumes
podman exec laravel-php-fpm ls -la /app

# Verify environment
podman exec laravel-php-fpm printenv | grep APP_
```

---

## ✅ Production Checklist

- [ ] `.env` file dengan APP_KEY yang valid
- [ ] Database migration sudah selesai
- [ ] Storage symlink sudah dibuat: `php artisan storage:link`
- [ ] Cache dikonfigurasi dengan Redis
- [ ] Session driver diset ke Redis
- [ ] Queue connection diset untuk background jobs
- [ ] Health endpoint `/health` accessible
- [ ] Security headers dikonfigurasi (X-Frame-Options, etc)
- [ ] HTTPS/TLS configured (dengan Caddy atau cert)
- [ ] Resource limits diset
- [ ] Restart policy diset ke `unless-stopped`
- [ ] Health checks enable
- [ ] Logging strategy implementasi
- [ ] Backup strategy implementasi
- [ ] Monitoring setup (stats, logs)
- [ ] Database backup automated
- [ ] Systemd service created untuk auto-start
- [ ] Firewall rules configured (80, 443 open)
- [ ] Volume data persistent
- [ ] Zero-downtime deployment strategy

---

## 🔗 Useful Commands Reference

```bash
# Build commands
podman build -t laravel:1.0 .
podman build -f Containerfile.php -t laravel-php:1.0 .

# Run commands
podman run -d --name app -p 80:80 laravel:1.0
podman run -d --network laravel-net --name php -v app:/app laravel-php:1.0

# Compose commands
podman-compose up -d
podman-compose down
podman-compose logs -f

# Troubleshooting
podman ps -a
podman logs -f container-name
podman exec container-name bash
podman stats
podman inspect container-name

# Cleanup
podman stop container-name
podman rm container-name
podman image rm image-name
podman system prune -a
```

---

**Last Updated**: June 2026  
**Compatibility**: PHP 8.2+, Laravel 10+  
**Production Ready**: ✅ Yes
