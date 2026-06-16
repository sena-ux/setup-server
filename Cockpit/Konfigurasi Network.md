# 🌐 Podman Network Architecture & Nginx Proxy Manager Setup
## Production-Grade Reverse Proxy dengan SSL Centralized

---

## 📋 Daftar Isi
1. [Arsitektur Network Overview](#arsitektur-network-overview)
2. [Custom Podman Network Setup](#custom-podman-network-setup)
3. [Container Web Deployment](#container-web-deployment)
4. [Nginx Proxy Manager Installation](#nginx-proxy-manager-installation)
5. [NPM UI Configuration](#npm-ui-configuration)
6. [SSL/TLS Management](#ssltls-management)
7. [Troubleshooting & Monitoring](#troubleshooting--monitoring)
8. [Production Best Practices](#production-best-practices)

---

## 🏗️ Arsitektur Network Overview

### Diagram Arsitektur

```
┌─────────────────────────────────────────────────────────────────┐
│                         PUBLIC INTERNET                          │
│                        80/443 (HTTPS)                            │
└──────────────────────────────┬──────────────────────────────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │  Host Server (UFW)   │
                    │  Port 80 -> 8080     │
                    │  Port 443 -> 8443    │
                    └──────────────────────┘
                               │
                               ▼
                    ┌──────────────────────────────┐
                    │  Nginx Proxy Manager (NPM)   │
                    │  172.20.0.2                  │
                    │  ✓ Reverse Proxy             │
                    │  ✓ SSL Termination           │
                    │  ✓ Load Balancing            │
                    └──────────────────────────────┘
                               │
                ┌──────────────┼──────────────┐
                │              │              │
                ▼              ▼              ▼
    ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
    │  Laravel App    │  │  CodeIgniter    │  │  Static Web     │
    │  172.20.0.10    │  │  172.20.0.11    │  │  172.20.0.12    │
    │  Port 80        │  │  Port 80        │  │  Port 80        │
    │  (FrankenPHP)   │  │  (Nginx+PHP-FPM)│  │  (Nginx)        │
    └─────────────────┘  └─────────────────┘  └─────────────────┘
            │                    │                    │
            └────────────────────┼────────────────────┘
                                 │
                     ┌───────────────────────┐
                     │  web_service Network  │
                     │  172.20.0.0/16        │
                     └───────────────────────┘
```

### Key Components

1. **Host Server Firewall (UFW)**
   - Publiknya hanya port 80 dan 443
   - Internal service terisolasi

2. **Nginx Proxy Manager (NPM)**
   - Single entry point untuk semua traffic
   - SSL/TLS termination
   - Request routing berdasarkan hostname
   - Access logs & analytics

3. **Internal Container Network (web_service)**
   - Private network 172.20.0.0/16
   - Containers tidak exposed ke publik
   - Internal communication hanya via container names atau IP

4. **Application Containers**
   - Berjalan di port 80 internal
   - Tidak perlu expose port individual
   - NPM forward request via network

---

## 🔧 Custom Podman Network Setup

### 1. Create Custom Bridge Network

```bash
# Create network dengan spesifikasi
podman network create \
  --driver bridge \
  --subnet 172.20.0.0/16 \
  --gateway 172.20.0.1 \
  --opt="com.docker.network.driver.mtu=1500" \
  --label="name=web_service" \
  --label="environment=production" \
  web_service

# Verifikasi creation
podman network ls

# Inspect network details
podman network inspect web_service
```

**Output Expected:**
```json
[
  {
    "Name": "web_service",
    "Id": "abc123def...",
    "Driver": "bridge",
    "Containers": {},
    "Options": {
      "com.docker.network.driver.mtu": "1500"
    },
    "Labels": {
      "environment": "production",
      "name": "web_service"
    },
    "IPAM": {
      "Config": [
        {
          "Subnet": "172.20.0.0/16",
          "Gateway": "172.20.0.1"
        }
      ]
    }
  }
]
```

---

### 2. Network Configuration Best Practices

#### A. DNS Resolution dalam Network

```bash
# Test DNS resolution antar container
podman run --rm \
  --network web_service \
  busybox nslookup npm

# Output: Server IP untuk npm container
```

Podman built-in DNS resolver memungkinkan:
- Container dapat akses container lain via **container name**
- Contoh: `http://laravel-app` akan resolve ke 172.20.0.10
- Otomatis, tidak perlu konfigurasi tambahan

#### B. Network Isolation

```bash
# Container HANYA dapat berkomunikasi dalam same network
# Container di network A tidak bisa akses network B
podman network create web_service_1
podman network create web_service_2

# Container di web_service_1 TIDAK bisa reach web_service_2
```

#### C. Multi-Network (Advanced)

```bash
# Container bisa di-attach ke multiple networks
podman run -d \
  --name multi-app \
  --network web_service \
  --network backend_service \
  my-app:latest

# Accessible dari kedua network
```

---

### 3. Verify Network Connectivity

```bash
# Test sambil container belum ada
podman network inspect web_service

# Setelah container running
podman network inspect web_service | jq '.[] | .Containers'

# Expected output:
# {
#   "npm": {...},
#   "laravel-app": {...},
#   "codeigniter-app": {...}
# }
```

---

## 🐳 Container Web Deployment

### 1. Deploy Laravel Container (FrankenPHP)

#### **PENTING: Disable Auto-SSL di FrankenPHP**

FrankenPHP secara default menjalankan Caddy dengan auto-HTTPS. Kami HARUS disable ini karena SSL akan dihandle oleh NPM.

```bash
podman run -d \
  --name laravel-app \
  --network web_service \
  --ip 172.20.0.10 \
  \
  # CRITICAL: Disable Caddy & Auto-SSL
  --env FRANKENPHP_CONFIG="worker ./public/index.php" \
  --env CADDY_DISABLED=1 \
  \
  # Application environment
  --env APP_ENV=production \
  --env APP_DEBUG=false \
  --env APP_URL=https://laravel.example.com \
  --env APP_KEY=base64:your-key-here \
  \
  # Database
  --env DB_HOST=postgres-db \
  --env DB_PORT=5432 \
  --env DB_DATABASE=laravel_db \
  --env DB_USERNAME=laravel_user \
  --env DB_PASSWORD=secure_pass \
  \
  # Cache & Session
  --env CACHE_DRIVER=redis \
  --env SESSION_DRIVER=redis \
  --env REDIS_HOST=redis-cache \
  --env REDIS_PORT=6379 \
  \
  # Volumes
  -v laravel-storage:/app/storage \
  -v laravel-cache:/app/bootstrap/cache \
  -v laravel-env:/app/.env:ro \
  \
  # Resource limits
  --memory 1g \
  --memory-swap 1.5g \
  --cpus 1 \
  \
  # Restart policy
  --restart unless-stopped \
  \
  # Health check (port 80, bukan 443!)
  --health-cmd='curl -f http://localhost/health || exit 1' \
  --health-interval=30s \
  --health-timeout=10s \
  --health-retries=3 \
  \
  # Labels untuk NPM
  --label app=laravel \
  --label version=1.0 \
  \
  laravel-frankenphp:1.0
```

#### **Customized Caddyfile untuk HTTP Only (No SSL)**

Buat file `Caddyfile-http-only` dalam Laravel image:

```caddyfile
:80 {
    # Root directory
    root * /app/public
    
    # Enable file serving
    file_server
    
    # Laravel routing
    rewrite * /index.php?{query}
    
    # PHP handler (no TLS)
    php_fastcgi 127.0.0.1:9000 {
        env APP_ENV production
        env APP_DEBUG false
        capture_errors on
    }
    
    # Remove Security Headers yang akan dihandle NPM
    # Jangan add HSTS, X-Frame-Options, dll
    # NPM akan add headers dengan SSL info
    
    # Basic headers only
    header {
        X-Powered-By "FrankenPHP"
        -Server
    }
    
    # Caching untuk static assets
    @static {
        path /js/* /css/* /images/* /fonts/*
    }
    
    header @static Cache-Control "public, max-age=3600"
    
    # Deny sensitive files
    @sensitive {
        path /.env* /.git* /storage/* /bootstrap/cache/*
    }
    
    respond @sensitive "Not Found" 404
    
    # Logging
    log {
        output stdout
        format json
    }
}
```

#### **Modified Containerfile untuk HTTP Only**

```dockerfile
# ... (build stages sama seperti sebelumnya)

FROM dunglas/frankenphp:latest-alpine

# Disable auto-HTTPS Caddy
ENV FRANKENPHP_CONFIG="worker ./public/index.php" \
    CADDY_DISABLED=0 \
    APP_ENV=production \
    APP_DEBUG=false

WORKDIR /app

# ... (copy files)

# Copy HTTP-only Caddyfile
COPY Caddyfile-http-only /etc/caddy/Caddyfile

# Expose HANYA port 80 (no 443!)
EXPOSE 80

CMD ["frankenphp", "run", "--config", "/etc/caddy/Caddyfile"]
```

---

### 2. Deploy CodeIgniter Container (Nginx + PHP-FPM)

```bash
podman run -d \
  --name codeigniter-app \
  --network web_service \
  --ip 172.20.0.11 \
  \
  # Volumes
  -v codeigniter-storage:/app/writable \
  -v codeigniter-env:/app/.env:ro \
  \
  # Environment
  --env CI_ENVIRONMENT=production \
  --env APP_BASEURL=https://codeigniter.example.com \
  \
  # Resource limits
  --memory 512m \
  --cpus 0.5 \
  \
  # Restart policy
  --restart unless-stopped \
  \
  # Labels
  --label app=codeigniter \
  \
  codeigniter-nginx-fpm:1.0
```

---

### 3. Deploy Static Web Container (Nginx)

```bash
podman run -d \
  --name static-web \
  --network web_service \
  --ip 172.20.0.12 \
  \
  # Volumes
  -v static-content:/usr/share/nginx/html:ro \
  \
  # Resource limits
  --memory 256m \
  --cpus 0.25 \
  \
  # Restart
  --restart unless-stopped \
  \
  # Labels
  --label app=static \
  \
  nginx:1.25-alpine
```

---

### 4. Verify Container Network Connectivity

```bash
# List all containers dalam web_service
podman network inspect web_service | jq '.[] | .Containers'

# Test DNS resolution
podman exec laravel-app nslookup codeigniter-app
podman exec laravel-app nslookup static-web

# Test HTTP connectivity
podman exec laravel-app curl -v http://codeigniter-app
podman exec laravel-app curl -v http://static-web

# Verify no SSL conflict
podman exec laravel-app curl -v http://localhost:80
# Should return 200 OK, NOT redirect to HTTPS
```

---

## 🔌 Nginx Proxy Manager Installation

### 1. Deploy NPM Container

```bash
# Create NPM network (sama dengan app network)
podman network create \
  --driver bridge \
  --subnet 172.20.0.0/16 \
  --gateway 172.20.0.1 \
  web_service

# Create NPM database volume
podman volume create npm-db
podman volume create npm-data

# Run NPM Container
podman run -d \
  --name nginx-proxy-manager \
  --network web_service \
  --ip 172.20.0.2 \
  \
  # Port mapping (expose ke host)
  -p 8080:81 \
  -p 80:80 \
  -p 443:443 \
  \
  # Volumes
  -v npm-data:/data \
  -v npm-db:/etc/letsencrypt \
  \
  # Environment
  --env PUID=1000 \
  --env PGID=1000 \
  --env TZ=Asia/Jakarta \
  \
  # Resource limits
  --memory 512m \
  --cpus 1 \
  \
  # Restart policy
  --restart unless-stopped \
  \
  # Health check
  --health-cmd='curl -f http://localhost:81/health || exit 1' \
  --health-interval=30s \
  --health-timeout=10s \
  --health-retries=3 \
  \
  # Labels
  --label app=npm \
  --label role=reverse-proxy \
  \
  jlesage/nginx-proxy-manager:latest
```

#### **Alternative: Dengan docker-compose**

```yaml
version: '3.8'

services:
  nginx-proxy-manager:
    image: jlesage/nginx-proxy-manager:latest
    container_name: nginx-proxy-manager
    restart: unless-stopped
    
    networks:
      web_service:
        ipv4_address: 172.20.0.2
    
    ports:
      - "80:80"
      - "443:443"
      - "8080:81"  # Admin UI
    
    environment:
      PUID: 1000
      PGID: 1000
      TZ: Asia/Jakarta
    
    volumes:
      - npm-data:/data
      - npm-db:/etc/letsencrypt
    
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:81"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  web_service:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
          gateway: 172.20.0.1

volumes:
  npm-data:
  npm-db:
```

Deploy:
```bash
podman-compose up -d
podman-compose ps
```

---

### 2. Access NPM Admin UI

```bash
# URL untuk admin panel
https://your-server-ip:8080

# Default credentials
Username: admin@example.com
Password: changeme

# IMPORTANT: Change credentials segera setelah first login!
```

---

### 3. Verify NPM Container Status

```bash
# Check if running
podman ps | grep nginx-proxy-manager

# Check logs
podman logs -f nginx-proxy-manager

# Test connectivity
curl -v http://localhost:80
# Should get 502 Bad Gateway (karena belum configure upstream)

# Test NPM admin UI
curl -v http://localhost:8080
```

---

## 🎛️ NPM UI Configuration

### 1. Login ke NPM Admin Panel

1. Buka browser: `https://your-server-ip:8080`
2. Login dengan default credentials: `admin@example.com` / `changeme`
3. **Immediately change password!** (Users > Click admin > Password)

---

### 2. Configure Proxy Host untuk Laravel

#### **Step 1: Add New Proxy Host**

```
Hosts > Proxy Hosts > Add Proxy Host
```

#### **Step 2: Details Tab**

```
┌─────────────────────────────────────────┐
│ Domain Names:  laravel.example.com      │
│                www.laravel.example.com  │
│                                         │
│ Scheme:        http ☑  https ☐          │
│                                         │
│ Forward Host:  laravel-app              │
│ Forward Port:  80                       │
│                                         │
│ Access List:   Publicly Accessible      │
│                                         │
│ ☑ Cache Assets                          │
│ ☑ Block Common Exploits                 │
│ ☑ Websockets Support                    │
└─────────────────────────────────────────┘

[Save]
```

**Penjelasan:**
- **Domain Names**: Public domain yang ingin accessible
- **Scheme**: Gunakan `http` karena routing internal, NPM handle SSL
- **Forward Host**: Nama container dalam network = `laravel-app`
- **Forward Port**: 80 (port internal Laravel)

---

#### **Step 3: SSL Tab**

```
Proxy Hosts > laravel-app > SSL Tab

┌──────────────────────────────────────┐
│ SSL Certificate:  [Let's Encrypt]  ▼  │
│                                      │
│ ☑ Force SSL                         │
│ ☑ HTTP/2 Support                   │
│ ☑ HSTS Enabled                      │
│                                      │
│ HSTS Max Age:     31536000 (1 year) │
│ HSTS Subdomains:  ☑                 │
│ HSTS Preload:     ☑                 │
│                                      │
│ OCSP Stapling:    ☑                 │
└──────────────────────────────────────┘

[Save]
```

**Penjelasan:**
- **SSL Certificate**: Let's Encrypt akan auto-issue & renew
- **Force SSL**: Redirect HTTP ke HTTPS
- **HSTS**: Security header untuk enforce HTTPS
- **OCSP Stapling**: Performance improvement untuk SSL

---

#### **Step 4: Advanced Tab**

```
Proxy Hosts > laravel-app > Advanced Tab

Custom Nginx Configuration (tambahkan):

location ~* ^/uploads/ {
    expires 30d;
    add_header Cache-Control "public, immutable";
}

location ~ ^/\. {
    deny all;
}

# Remove server header
proxy_pass_header Server;
proxy_hide_header Server;

# Add security headers
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;

# Timeouts untuk Laravel
proxy_connect_timeout 600s;
proxy_send_timeout 600s;
proxy_read_timeout 600s;
```

---

#### **Step 5: Access Lists Tab**

```
Proxy Hosts > laravel-app > Access Lists

☑ Publicly Accessible (default)

OR untuk restrict:

☑ Custom Access List
  - Add new access list dengan IP whitelist
  - Contoh: 203.0.113.0/24 (office subnet)
```

---

### 3. Configure Proxy Host untuk CodeIgniter

Repeat langkah yang sama:

```
Hosts > Proxy Hosts > Add Proxy Host

Details Tab:
- Domain Names: codeigniter.example.com
- Scheme: http
- Forward Host: codeigniter-app
- Forward Port: 80

SSL Tab:
- Use Let's Encrypt
- Force SSL: ☑
- HSTS: ☑

[Save]
```

---

### 4. Configure Proxy Host untuk Static Web

```
Hosts > Proxy Hosts > Add Proxy Host

Details Tab:
- Domain Names: static.example.com
- Scheme: http
- Forward Host: static-web
- Forward Port: 80
- Cache Assets: ☑

SSL Tab:
- Let's Encrypt
- Force SSL: ☑

[Save]
```

---

### 5. Verify All Proxy Hosts

```
Proxy Hosts Dashboard:

┌─────────────────────────────────────────────────────┐
│ Domain              Status    Certificate  Traffic  │
├─────────────────────────────────────────────────────┤
│ laravel.example.com     ✓      Let's Encrypt  ↑    │
│ codeigniter.example.com ✓      Let's Encrypt  ↑    │
│ static.example.com      ✓      Let's Encrypt  ↑    │
└─────────────────────────────────────────────────────┘
```

---

## 🔒 SSL/TLS Management

### 1. Let's Encrypt Auto-Renewal

```bash
# NPM otomatis manage Let's Encrypt
# Certificates akan di-renew otomatis 30 hari sebelum expiry

# Verifikasi di NPM UI
Proxy Hosts > [Domain] > SSL Tab

# View certificate details:
# - Issue Date
# - Expiry Date
# - Renewal Status
```

### 2. Check Certificate dari CLI

```bash
# List certificates dalam container
podman exec nginx-proxy-manager \
  ls -la /etc/letsencrypt/live/

# View certificate info
podman exec nginx-proxy-manager \
  openssl x509 -in /etc/letsencrypt/live/laravel.example.com/cert.pem \
  -text -noout

# Check expiry date
podman exec nginx-proxy-manager \
  openssl x509 -in /etc/letsencrypt/live/laravel.example.com/cert.pem \
  -noout -enddate
```

### 3. Custom SSL Certificate

Jika ingin upload custom certificate:

```
Proxy Hosts > [Domain] > SSL Tab

┌──────────────────────────────────────┐
│ SSL Certificate: [Custom Upload]  ▼  │
│                                      │
│ [Upload Certificate]                 │
│ [Upload Private Key]                 │
│                                      │
│ atau                                 │
│                                      │
│ Certificate (PEM):    [paste here]   │
│ Private Key:          [paste here]   │
└──────────────────────────────────────┘

[Save]
```

---

## 🔍 Troubleshooting & Monitoring

### 1. Container Network Debugging

```bash
# Lihat network namespace
podman network inspect web_service

# Check IP assignments
podman exec npm nslookup laravel-app
podman exec npm nslookup codeigniter-app

# Test connectivity dari NPM ke apps
podman exec npm curl -v http://laravel-app
podman exec npm curl -v http://codeigniter-app:80

# Verify no SSL loop
podman exec npm curl -v http://laravel-app:80
# Should return 200 OK, NOT HTTPS redirect!
```

---

### 2. Common Issues & Solutions

#### Issue 1: "Bad Gateway 502"

**Symptom**: Access domain, return 502 error

**Debugging**:
```bash
# Check NPM logs
podman logs -f nginx-proxy-manager

# Check app logs
podman logs -f laravel-app

# Verify connectivity
podman exec npm curl -v http://laravel-app

# Check DNS resolution
podman exec npm nslookup laravel-app

# Verify both in same network
podman network inspect web_service | jq '.[] | .Containers'
```

**Solutions**:
1. Pastikan container name benar (case-sensitive!)
2. Pastikan container running: `podman ps`
3. Pastikan same network: `podman inspect <container> | grep -A5 Networks`
4. Pastikan app listening di port 80
5. Cek firewall rules

---

#### Issue 2: "SSL Certificate Error"

**Symptom**: Browser warning tentang invalid certificate

**Debugging**:
```bash
# Check certificate validity
podman exec npm openssl x509 -in /etc/letsencrypt/live/laravel.example.com/cert.pem -text

# Check NPM logs untuk Let's Encrypt errors
podman logs npm | grep letsencrypt

# Verify DNS resolution pointing to server
nslookup laravel.example.com
```

**Solutions**:
1. DNS harus pointing ke server IP yang correct
2. Port 80 dan 443 harus accessible dari publik
3. Let's Encrypt challenge memerlukan HTTP access
4. Wait ~5 minutes untuk automatic renewal

---

#### Issue 3: "HTTPS Redirect Loop"

**Symptom**: Browser stuck in redirect loop

**Cause**: FrankenPHP auto-HTTPS masih aktif!

**Fix**:
```bash
# CRITICAL: Verify Caddy disabled
podman inspect laravel-app | grep -A5 ENV | grep FRANKENPHP

# Should output:
# "FRANKENPHP_CONFIG=worker ./public/index.php"
# NOT "FRANKENPHP_CONFIG=..." dengan HTTPS

# If not disabled, recreate container:
podman stop laravel-app
podman rm laravel-app

# Run dengan CADDY_DISABLED=1
podman run -d \
  --name laravel-app \
  --network web_service \
  --env FRANKENPHP_CONFIG="worker ./public/index.php" \
  --env CADDY_DISABLED=1 \
  ...
  laravel-frankenphp:1.0

# Verify HTTP works
podman exec npm curl -v http://laravel-app
```

---

#### Issue 4: "Connection Refused"

**Symptom**: Cannot connect ke container

```bash
# Check if port 80 listening
podman exec laravel-app \
  netstat -tlnp | grep 80

# Check process running
podman exec laravel-app ps aux

# View container logs
podman logs --tail 50 laravel-app
```

**Solutions**:
1. Ensure APP listening pada port 80 (bukan 8080 atau lain)
2. Check application config tidak force HTTPS
3. Verify PHP-FPM/Caddy running: `podman exec laravel-app ps aux`

---

### 3. Monitoring & Health Checks

#### A. NPM Dashboard

```
NPM UI > Dashboard

┌────────────────────────────────────────┐
│ Dashboard                              │
├────────────────────────────────────────┤
│ Proxy Hosts:       3 ✓                │
│ Redirects:         0                  │
│ Streams:           0                  │
│ Access Lists:      2                  │
│ Certificates:      3 ✓ (Auto-renew)  │
│                                       │
│ Recent Traffic:    ↑↑↑                │
│ Status Codes:                         │
│  - 200: 95%       ✓                  │
│  - 404: 4%        ⚠                  │
│  - 502: 1%        ✗                  │
└────────────────────────────────────────┘
```

---

#### B. Monitor Container Stats

```bash
# Real-time monitoring
podman stats npm laravel-app codeigniter-app static-web

# Container logs aggregation
podman logs -f npm &
podman logs -f laravel-app &
podman logs -f codeigniter-app &

# Network traffic
podman network stats web_service
```

---

#### C. View Access Logs di NPM

```
NPM UI > Hosts > [Domain] > Reports

┌───────────────────────────────────────┐
│ Traffic Report                        │
├───────────────────────────────────────┤
│ Status Codes:                         │
│  - 2xx: ████████░░ 80%               │
│  - 3xx: █░░░░░░░░  5%                │
│  - 4xx: ░░░░░░░░░  10%               │
│  - 5xx: ░░░░░░░░░  5%                │
│                                      │
│ Top 10 URLs:                         │
│ 1. /                                 │
│ 2. /api/users                        │
│ 3. /images/logo.png                  │
│ ...                                  │
└───────────────────────────────────────┘
```

---

#### D. Check Certificate Expiry

```bash
# Manual check
podman exec npm \
  openssl x509 -in /etc/letsencrypt/live/laravel.example.com/cert.pem \
  -noout -enddate

# Output: notAfter=Jun 15 12:34:56 2025 GMT

# Alert jika < 30 hari: setup monitoring
# NPM akan auto-renew 30 hari sebelum expiry
```

---

## 🛡️ Production Best Practices

### 1. Firewall Configuration

```bash
# Open only necessary ports
sudo ufw allow 22/tcp          # SSH
sudo ufw allow 80/tcp          # HTTP
sudo ufw allow 443/tcp         # HTTPS
sudo ufw deny 8080/tcp         # Block NPM admin dari publik

# OR: Restrict NPM admin ke specific IP
sudo ufw allow from 203.0.113.10 to any port 8080

# Verify rules
sudo ufw status numbered
```

---

### 2. Network Isolation

```bash
# Containers HANYA accessible via NPM
# Direct access to port 80 dari host tidak bisa

# Container ports tidak exposed
podman ps -a
# Output: tidak ada port mapping untuk app containers

# Only NPM punya port mapping:
# 0.0.0.0:80->80
# 0.0.0.0:443->443
# 0.0.0.0:8080->81
```

---

### 3. Secrets & Environment Management

```bash
# Use .env files dengan secure permissions
chmod 600 .env

# Use podman secrets untuk sensitive data
podman secret create db_password -
# (paste password, Ctrl+D)

# Reference dalam compose:
version: '3.8'
services:
  laravel-app:
    environment:
      DB_PASSWORD: /run/secrets/db_password
    secrets:
      - db_password

secrets:
  db_password:
    external: true
```

---

### 4. Logging & Monitoring Stack

```yaml
# docker-compose dengan logging
services:
  npm:
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
        labels: "app=npm"

  laravel-app:
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
        labels: "app=laravel"
```

---

### 5. Backup Strategy

```bash
#!/bin/bash
# backup-npm.sh

BACKUP_DIR="/backups/npm"
DATE=$(date +%Y%m%d_%H%M%S)

# Backup NPM data
podman run --rm \
  -v npm-data:/data \
  -v $BACKUP_DIR:/backup \
  alpine tar czf /backup/npm-data_$DATE.tar.gz -C /data .

# Backup certificates
podman run --rm \
  -v npm-db:/certs \
  -v $BACKUP_DIR:/backup \
  alpine tar czf /backup/npm-certs_$DATE.tar.gz -C /certs .

echo "Backup completed: $BACKUP_DIR"
```

---

### 6. Zero-Downtime Deployment

```bash
# Update app container tanpa downtime
podman pull laravel-app:2.0

# Create new container
podman run -d \
  --name laravel-app-new \
  --network web_service \
  --ip 172.20.0.20 \
  laravel-app:2.0

# Warmup new container
sleep 5
podman exec npm curl -v http://laravel-app-new

# Update NPM to point ke new container
# (Change forward host: 172.20.0.10 -> 172.20.0.20)

# Remove old container
podman stop laravel-app
podman rm laravel-app

# Rename new container
podman rename laravel-app-new laravel-app

# Update NPM back to use container name
# (Change forward host: 172.20.0.20 -> laravel-app)
```

---

## 📊 Architecture Summary

```
                    ┌─────────────────────┐
                    │   Public Internet    │
                    │  (Your Users)       │
                    └──────────┬──────────┘
                               │
                    ┌──────────▼──────────┐
                    │   Host Firewall     │
                    │   (UFW)             │
                    │ 80/443 ONLY OPEN    │
                    └──────────┬──────────┘
                               │
        ┌──────────────────────┼──────────────────────┐
        │                      │                      │
    HTTP/80             HTTPS/443               Admin/8080
        │                      │                      │
        └──────────────────────┼──────────────────────┘
                               │
                    ┌──────────▼──────────┐
                    │  Nginx Proxy Mgr    │
                    │  (NPM)              │
                    │  172.20.0.2         │
                    │  - Reverse Proxy    │
                    │  - SSL/TLS Term.    │
                    │  - Load Balancing   │
                    └──────────┬──────────┘
                               │
        ┌──────────────────────┼──────────────────────┐
        │                      │                      │
    HTTP/80               HTTP/80               HTTP/80
        │                      │                      │
    ┌───▼────┐          ┌──────▼──────┐      ┌────▼────┐
    │ Laravel │          │ CodeIgniter │      │ Static  │
    │  App    │          │    App      │      │  Web    │
    │172.20.  │          │ 172.20.     │      │172.20.  │
    │  0.10   │          │   0.11      │      │  0.12   │
    └────┬────┘          └──────┬──────┘      └────┬────┘
         │                      │                   │
         └──────────────────────┼───────────────────┘
                                │
                    ┌───────────▼──────────┐
                    │ web_service Network  │
                    │ 172.20.0.0/16        │
                    │ (Internal Only)      │
                    └──────────────────────┘
```

---

## ✅ Deployment Checklist

- [ ] Custom network `web_service` created (172.20.0.0/16)
- [ ] All app containers dalam same network
- [ ] FrankenPHP CADDY_DISABLED=1 diset
- [ ] NPM container running dengan IP 172.20.0.2
- [ ] Firewall allow 80, 443, 8080 only
- [ ] NPM default password changed
- [ ] Proxy hosts configured untuk semua domains
- [ ] Let's Encrypt certificates active
- [ ] SSL force enabled untuk semua hosts
- [ ] HSTS headers configured
- [ ] DNS pointing ke server IP correct
- [ ] All containers in auto-restart mode
- [ ] Health checks enabled
- [ ] Monitoring/logging setup
- [ ] Backup strategy implemented

---

**Last Updated**: June 2026  
**Network**: Podman 4.0+  
**NPM Version**: Latest (jlesage)  
**Production Ready**: ✅ Yes
