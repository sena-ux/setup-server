# 🐳 Panduan Infrastruktur Docker: Nginx Proxy Manager + Dozzle Log Viewer

**Dokumentasi Teknis Instalasi, Konfigurasi, dan Pengamanan**

---

## 📋 Daftar Isi

1. [Persyaratan Sistem](#persyaratan-sistem)
2. [Persiapan Awal](#persiapan-awal)
3. [Setup Docker Network](#setup-docker-network)
4. [Konfigurasi Nginx Proxy Manager (NPM)](#konfigurasi-nginx-proxy-manager)
5. [Konfigurasi Dozzle Log Viewer](#konfigurasi-dozzle-log-viewer)
6. [Konfigurasi Firewall UFW](#konfigurasi-firewall-ufw)
7. [Setup Access List di NPM](#setup-access-list-di-npm)
8. [Proxy Host untuk Dozzle](#proxy-host-untuk-dozzle)
9. [Monitoring dan Troubleshooting](#monitoring-dan-troubleshooting)

---

## 🖥️ Persyaratan Sistem

| Komponen | Versi Minimal | Catatan |
|----------|---------------|---------|
| Docker | 20.10+ | Untuk Docker Compose Spec terbaru |
| Docker Compose | 1.29+ | Standalone atau bagian dari Docker Desktop |
| OS | Ubuntu 20.04+ / Debian 11+ | Linux-based (yang direkomendasikan) |
| RAM | 2GB minimum | 4GB+ untuk production |
| Storage | 50GB minimum | Untuk logs dan container images |
| Network | UFW/iptables | Untuk firewall management |
| WireGuard VPN | Installed & configured | Untuk akses VPN (10.0.0.0/24) |

---

## 🚀 Persiapan Awal

### 1. Update Sistem dan Install Dependencies

```bash
# Update package list
sudo apt update
sudo apt upgrade -y

# Install required packages
sudo apt install -y \
  docker.io \
  docker-compose-plugin \
  curl \
  wget \
  net-tools \
  ufw \
  htop
```

### 2. Verifikasi Instalasi Docker

```bash
# Check Docker version
docker --version

# Check Docker Compose version
docker compose version

# Verify Docker daemon running
sudo systemctl status docker

# Verify current user can run Docker (tanpa sudo)
docker ps
```

> ⚠️ **Jika perlu akses docker tanpa sudo**, jalankan:
> ```bash
> sudo usermod -aG docker $USER
> newgrp docker
> ```

### 3. Setup Direktori Aplikasi

```bash
# Buat direktori untuk aplikasi
sudo mkdir -p /home/app/proxy
sudo mkdir -p /home/app/dozzle

# Set proper permissions
sudo chown -R $(whoami):$(whoami) /home/app/

# Verify direktori
ls -lah /home/app/
```

**Expected Output:**
```
drwxr-xr-x  proxy
drwxr-xr-x  dozzle
```

---

## 🌐 Setup Docker Network

### 1. Buat External Network

Jalankan perintah ini **sekali saja** sebelum menjalankan docker-compose:

```bash
# Create external network named 'web_service'
docker network create web_service

# Verify network creation
docker network ls
docker network inspect web_service
```

**Expected Output:**
```
NETWORK ID     NAME          DRIVER    SCOPE
a1b2c3d4e5f6   web_service   bridge    local
```

### 2. Dokumentasi Network

- **Network Name**: `web_service`
- **Driver**: bridge
- **Subnet**: Otomatis (biasanya 172.20.0.0/16)
- **Scope**: local (hanya pada host ini)

> 📌 Jika network sudah ada sebelumnya dan ingin verify:
> ```bash
> docker network rm web_service  # Hapus jika perlu reset
> docker network create web_service  # Buat ulang
> ```

---

## 🔧 Konfigurasi Nginx Proxy Manager

### 1. Struktur Direktori NPM

```
/home/app/proxy/
├── docker-compose.yml       # Konfigurasi Docker Compose
├── data/                    # Volume untuk database & data
├── letsencrypt/             # Volume untuk SSL certificates
└── logs/                    # Volume untuk application logs
```

### 2. Membuat Docker Compose NPM

Buat file `docker-compose.yml` di `/home/app/proxy/`:

```bash
nano /home/app/proxy/docker-compose.yml
```

Salin konten berikut:

```yaml
services:
  nginx-proxy-manager:
    image: 'jc21/nginx-proxy-manager:latest'
    container_name: npm
    restart: unless-stopped
    
    # Port configuration
    ports:
      - "80:80"       # HTTP
      - "443:443"     # HTTPS
      - "81:81"       # Admin dashboard (dibatasi firewall)
    
    # Environment variables
    environment:
      - TZ=Asia/Jakarta
      - DISABLE_IPV6=true
    
    # Volume mounts
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt
      - ./logs:/var/log/nginx
    
    # Network configuration
    networks:
      - web_service
    
    # Health check
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:81"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
    
    # Resource limits (optional tapi recommended)
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 512M
        reservations:
          cpus: '0.5'
          memory: 256M

networks:
  web_service:
    external: true
```

### 3. Jalankan NPM Container

```bash
# Navigate to directory
cd /home/app/proxy

# Create necessary directories
mkdir -p data letsencrypt logs

# Start container in background
docker compose up -d

# Verify container is running
docker compose ps

# Check logs
docker compose logs -f --tail=50
```

### 4. Akses Dashboard NPM Awal

- **URL**: `http://localhost:81`
- **Default Admin Email**: `admin@example.com`
- **Default Password**: `changeme`

> ⚠️ **PENTING**: Ubah default credentials segera setelah login pertama kali!

---

## 📊 Konfigurasi Dozzle Log Viewer

### 1. Struktur Direktori Dozzle

```
/home/app/dozzle/
├── docker-compose.yml       # Konfigurasi Docker Compose
└── logs/                    # Volume untuk Dozzle logs (jika diperlukan)
```

### 2. Membuat Docker Compose Dozzle

Buat file `docker-compose.yml` di `/home/app/dozzle/`:

```bash
nano /home/app/dozzle/docker-compose.yml
```

Salin konten berikut:

```yaml
services:
  dozzle:
    image: 'amir20/dozzle:latest'
    container_name: dozzle
    restart: unless-stopped
    
    # TIDAK menggunakan 'ports' - hanya expose internally
    expose:
      - "8080"
    
    # Environment variables
    environment:
      - TZ=Asia/Jakarta
      - DOZZLE_LEVEL=info
      - DOZZLE_TAILSIZE=300
    
    # Volume mounts (CRITICAL: Docker socket harus read-only)
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    
    # Network configuration
    networks:
      - web_service
    
    # Security options
    security_opt:
      - no-new-privileges:true
    
    # Health check
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:8080"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
    
    # Resource limits
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 256M
        reservations:
          cpus: '0.25'
          memory: 128M

networks:
  web_service:
    external: true
```

### 3. Jalankan Dozzle Container

```bash
# Navigate to directory
cd /home/app/dozzle

# Start container in background
docker compose up -d

# Verify container is running
docker compose ps

# Check logs
docker compose logs -f --tail=50

# Verify container is in web_service network
docker inspect dozzle | grep -A 20 '"Networks"'
```

### 4. Verifikasi Dozzle Internal Access

```bash
# Cek apakah Dozzle accessible dari NPM container
docker exec npm curl -f http://dozzle:8080

# Output yang diharapkan:
# curl: (52) Empty reply from server - ini NORMAL (bukan HTML)
# atau status code 200
```

---

## 🔒 Konfigurasi Firewall UFW

### 1. Status dan Setup Awal UFW

```bash
# Check UFW status
sudo ufw status

# Enable UFW jika belum aktif
sudo ufw enable

# Set default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing
```

### 2. Konfigurasi Rule UFW untuk NPM dan Layanan Lainnya

```bash
# ============================================
# RULE 1: Allow SSH (CRITICAL - jangan lock diri sendiri!)
# ============================================
sudo ufw allow 22/tcp comment "SSH standard port"

# Alternatif: SSH via WireGuard VPN only (port custom 2226)
sudo ufw allow in on wg0 from 10.0.0.0/24 to any port 2226 proto tcp comment "SSH via WireGuard VPN only"

# ============================================
# RULE 2: Allow HTTP (Port 80) - Public Access
# ============================================
sudo ufw allow 80/tcp comment "HTTP - Public access for websites"

# ============================================
# RULE 3: Allow HTTPS (Port 443) - Public Access
# ============================================
sudo ufw allow 443/tcp comment "HTTPS/TLS - Public access for websites"
sudo ufw allow 443/udp comment "HTTP/3 QUIC - Public access (UDP)"

# ============================================
# RULE 4: Allow NPM Admin Dashboard (Port 81)
# - LOCALHOST ONLY
# ============================================
sudo ufw allow from 127.0.0.1 to any port 81 proto tcp comment "NPM Dashboard - localhost only"

# ============================================
# RULE 5: Allow NPM Admin Dashboard (Port 81)
# - VPN ACCESS ONLY (WireGuard)
# ============================================
sudo ufw allow in on wg0 from 10.0.0.0/24 to any port 81 proto tcp comment "NPM Dashboard - WireGuard VPN only (10.0.0.0/24)"

# ============================================
# RULE 6: Allow Dozzle (Port 8080) - INTERNAL ONLY
# ============================================
# IMPORTANT: Dozzle tidak di-expose ke host, hanya internal ke NPM
# Jadi tidak perlu UFW rule untuk port 8080

# ============================================
# RULE 7: (OPTIONAL) Allow DNS over VPN
# ============================================
sudo ufw allow in on wg0 from 10.0.0.0/24 to any port 53 proto tcp comment "DNS via WireGuard VPN"
sudo ufw allow in on wg0 from 10.0.0.0/24 to any port 53 proto udp comment "DNS via WireGuard VPN"
```

### 3. Verifikasi Firewall Rules

```bash
# Display all UFW rules with numbering
sudo ufw status numbered

# Display verbose output
sudo ufw status verbose
```

**Expected Output:**
```
Status: active

     To                         Action      From
     --                         ------      ----
 22/tcp                         ALLOW       Anywhere
 80/tcp                         ALLOW       Anywhere
 443/tcp                        ALLOW       Anywhere
 443/udp                        ALLOW       Anywhere
 81/tcp                         ALLOW       127.0.0.1
 81/tcp (v6)                    ALLOW       Anywhere (v6)
 Anywhere on wg0                ALLOW       10.0.0.0/24 (SSH port 2226)
 Anywhere on wg0                ALLOW       10.0.0.0/24 (NPM port 81)
```

### 4. Test Firewall Rules

```bash
# Test HTTP access (public)
curl -v http://localhost:80

# Test HTTPS access (public)
curl -v https://localhost:443

# Test NPM dashboard from localhost
curl -v http://localhost:81

# Test NPM dashboard from VPN (jalankan dari client yang terhubung VPN)
# SSH ke server dan test dari VPN client machine
curl -v http://<SERVER_VPN_IP>:81
```

### 5. Tips Firewall Management

**Jika ingin menghapus rule:**
```bash
# List dengan nomor
sudo ufw status numbered

# Delete rule by number (contoh hapus rule #5)
sudo ufw delete 5

# Confirm deletion
sudo ufw delete 22/tcp
```

**Jika ingin disable UFW sementara (debugging):**
```bash
sudo ufw disable

# Re-enable
sudo ufw enable
```

---

## 🔐 Setup Access List di NPM

### 1. Login ke NPM Dashboard

1. Buka browser dan akses: `http://localhost:81` atau `http://<server-ip>:81` (via VPN)
2. Login dengan credentials admin Anda
3. Navigasi ke menu **Access Lists** (biasanya di sidebar kiri)

### 2. Buat Access List untuk Dozzle

**Langkah-langkah:**

1. Klik tombol **"Add Access List"** (atau **+** button)
2. Isi form dengan detail berikut:

| Field | Value | Keterangan |
|-------|-------|-----------|
| **Name** | `Dozzle Secure Access` | Nama identitas untuk list ini |
| **Description** | `Restricted access for Dozzle logs - Localhost and VPN only` | Dokumentasi |

3. **Dalam bagian "Allow List"** (IP whitelist), masukkan:
   - **Line 1**: `127.0.0.1` (localhost)
   - **Line 2**: `10.0.0.0/24` (WireGuard VPN segment)

4. **Dalam bagian "Deny List"** (IP blacklist), biarkan kosong atau masukkan:
   - `0.0.0.0/0` (optional - untuk explicitly block semua public)

5. Klik **"Save"** untuk menyimpan Access List

### 3. Hasil Access List Configuration

```
┌─────────────────────────────────────────┐
│ Access List: Dozzle Secure Access       │
├─────────────────────────────────────────┤
│ Status: Active ✓                        │
│                                         │
│ Allow IPs:                              │
│  • 127.0.0.1       (Localhost)         │
│  • 10.0.0.0/24     (VPN Network)       │
│                                         │
│ Deny IPs:                               │
│  • [All others]    (Implicit)          │
└─────────────────────────────────────────┘
```

### 4. Verifikasi Access List (Terminal)

Jika ingin verifikasi via API NPM:

```bash
# Login dan get API token (lakukan sekali untuk dapatkan token)
TOKEN=$(curl -X POST http://localhost:81/api/tokens \
  -H "Content-Type: application/json" \
  -d '{"identity":"admin@example.com","secret":"yourpassword"}' \
  | jq -r '.token')

# Get semua access lists
curl -X GET http://localhost:81/api/access-lists \
  -H "Authorization: Bearer $TOKEN" \
  | jq '.[]'
```

---

## 🌍 Proxy Host untuk Dozzle

### 1. Login ke NPM Dashboard

1. Akses: `http://localhost:81` (atau via VPN)
2. Navigasi ke **Proxy Hosts** di sidebar

### 2. Buat Proxy Host untuk Dozzle

Klik **"Add Proxy Host"** dan isi form berikut:

#### Tab: Details

| Field | Value | Keterangan |
|-------|-------|-----------|
| **Domain Names** | `log.sman2amlapura.sch.id` | Domain untuk akses Dozzle |
| **Scheme** | `http` | Backend scheme (internal) |
| **Forward Hostname/IP** | `dozzle` | Container name di network web_service |
| **Forward Port** | `8080` | Port Dozzle yang di-expose |
| **Cache Assets** | `Off` | Logs lebih baik tanpa cache |
| **Block Common Exploits** | `On` | Untuk security |
| **Websockets Support** | **ON** ⚠️ | **WAJIB untuk Dozzle!** |

#### Tab: SSL Certificate

1. **SSL Certificate**: Pilih **"Request a new SSL Certificate"**
2. **Email Address for Let's Encrypt**: Masukkan email admin Anda
3. **DNS Provider** (jika menggunakan DNS challenge): Pilih provider
4. **Force SSL**: Aktifkan ✓
5. **HTTP/2 Support**: Aktifkan ✓
6. **HSTS Enabled**: Aktifkan ✓
7. Klik **"Save"** untuk request SSL certificate

> ⏳ Tunggu proses SSL certificate dari Let's Encrypt (biasanya 2-5 menit)

#### Tab: Access List

1. **Access List**: Pilih **"Dozzle Secure Access"** (yang sudah dibuat sebelumnya)
2. Klik **"Save"**

### 3. Hasil Proxy Host Configuration

```
┌────────────────────────────────────────────────┐
│ Proxy Host: log.sman2amlapura.sch.id           │
├────────────────────────────────────────────────┤
│ Status: Active ✓                               │
│                                                │
│ Details:                                       │
│  • Domain: log.sman2amlapura.sch.id           │
│  • Backend: http://dozzle:8080                 │
│  • Websockets: Enabled                         │
│  • Block Exploits: Enabled                     │
│                                                │
│ Security:                                      │
│  • SSL Certificate: Let's Encrypt (Valid)     │
│  • Force SSL: Enabled                          │
│  • HSTS: Enabled                               │
│  • Access List: Dozzle Secure Access          │
│    ├─ Allow: 127.0.0.1, 10.0.0.0/24           │
│    └─ Deny: All others                         │
└────────────────────────────────────────────────┘
```

### 4. Test Proxy Host Dozzle

**Dari Localhost (Direct):**
```bash
curl -k https://log.sman2amlapura.sch.id --resolve log.sman2amlapura.sch.id:443:127.0.0.1
```

**Dari VPN Client (jika sudah terhubung):**
```bash
# Browser: https://log.sman2amlapura.sch.id
# atau
curl -k https://log.sman2amlapura.sch.id --resolve log.sman2amlapura.sch.id:443:<SERVER_VPN_IP>
```

**Expected Result:**
- Redirect dari `http://` ke `https://`
- SSL certificate valid (dari Let's Encrypt)
- Dozzle dashboard accessible
- WebSocket connection working

### 5. Troubleshooting Proxy Host

**Jika SSL certificate error:**
```bash
# Check NPM logs
docker logs npm -f --tail=100

# Check SSL certificate status via API
TOKEN=$(curl -X POST http://localhost:81/api/tokens \
  -H "Content-Type: application/json" \
  -d '{"identity":"admin@example.com","secret":"password"}' \
  | jq -r '.token')

curl -X GET http://localhost:81/api/nginx/certificates \
  -H "Authorization: Bearer $TOKEN" | jq '.[]'
```

**Jika Dozzle tidak responsive (502 Bad Gateway):**
```bash
# Verify Dozzle container status
docker ps | grep dozzle

# Check Dozzle logs
docker logs dozzle -f --tail=50

# Test internal connectivity
docker exec npm curl -f http://dozzle:8080
```

**Jika Websocket tidak working:**
```bash
# Verify Websockets Support di NPM dashboard setting
# Re-enable Websockets Support di Proxy Host > Advanced tab
```

---

## 📈 Monitoring dan Troubleshooting

### 1. Monitoring Container Status

```bash
# Check all containers
docker ps -a

# Check resource usage
docker stats

# Check network connectivity
docker network inspect web_service
```

### 2. View Logs

**NPM Logs:**
```bash
# Real-time logs
cd /home/app/proxy
docker compose logs -f

# Last 100 lines
docker compose logs -n 100
```

**Dozzle Logs:**
```bash
# Real-time logs
cd /home/app/dozzle
docker compose logs -f

# View specific time range
docker compose logs --since 2025-01-15T10:00:00 -f
```

**Combined logs (via Dozzle UI):**
- Buka Dozzle di: `https://log.sman2amlapura.sch.id`
- Lihat all container logs secara real-time

### 3. Health Check

```bash
# Check container health
docker inspect npm | grep -A 5 '"Health"'
docker inspect dozzle | grep -A 5 '"Health"'

# Manual health check
curl -f http://localhost:81 && echo "NPM OK" || echo "NPM DOWN"
docker exec npm curl -f http://dozzle:8080 && echo "Dozzle OK" || echo "Dozzle DOWN"
```

### 4. Restart Containers

**Restart satu container:**
```bash
# NPM
cd /home/app/proxy && docker compose restart

# Dozzle
cd /home/app/dozzle && docker compose restart
```

**Restart dengan fresh start:**
```bash
# Stop dan remove
cd /home/app/proxy
docker compose down

# Start fresh
docker compose up -d
```

### 5. Backup & Recovery

**Backup NPM Data:**
```bash
# Backup database dan config
tar -czf npm-backup-$(date +%Y%m%d-%H%M%S).tar.gz \
  /home/app/proxy/data/ \
  /home/app/proxy/letsencrypt/

# Simpan di lokasi aman
mv npm-backup-*.tar.gz /backup/locations/
```

**Restore NPM Data:**
```bash
# Extract backup
cd /home/app/proxy
tar -xzf npm-backup-*.tar.gz

# Restart container
docker compose restart
```

### 6. Update Container Images

```bash
# Update image ke latest version
cd /home/app/proxy
docker compose pull
docker compose up -d

cd /home/app/dozzle
docker compose pull
docker compose up -d
```

### 7. Common Issues & Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| NPM dashboard tidak accessible | Port 81 blocked atau container down | Cek UFW rules, `docker ps`, check logs |
| Dozzle 502 Bad Gateway | Container tidak running atau port issue | `docker ps`, verify `expose: 8080` |
| WebSocket error | WebSocket Support disabled | Enable di NPM Proxy Host settings |
| SSL Certificate pending | DNS not configured | Verify domain DNS A record points to server |
| Access denied (403) | IP tidak dalam whitelist | Verify IP di Access List NPM |
| Container OOM killed | Memory insufficient | Increase resource limits atau add RAM |

---

## 🎯 Checklist Post-Setup

- [ ] Docker dan Docker Compose installed
- [ ] Web service network created
- [ ] NPM container running dan accessible
- [ ] Dozzle container running (internal only)
- [ ] UFW enabled dengan rules yang tepat
- [ ] NPM default credentials changed
- [ ] Access List "Dozzle Secure Access" dibuat
- [ ] Proxy Host untuk Dozzle dibuat dengan SSL
- [ ] Websockets Support aktif
- [ ] Test akses dari localhost
- [ ] Test akses dari VPN
- [ ] Test akses dari public (should be denied)
- [ ] Backup strategy implemented
- [ ] Monitoring & alerting configured

---

## 📞 Support & References

- **Nginx Proxy Manager**: https://nginxproxymanager.com/
- **Dozzle Documentation**: https://dozzle.dev/
- **Docker Documentation**: https://docs.docker.com/
- **UFW Firewall Guide**: https://wiki.ubuntu.com/UncomplicatedFirewall
- **Let's Encrypt**: https://letsencrypt.org/

---

**Dokumentasi ini dibuat pada**: 2026-06-15  
**Versi**: 1.0  
**Status**: Production Ready ✓

