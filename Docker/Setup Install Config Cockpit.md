# 📘 Panduan Migrasi Docker ke Cockpit + Podman
## Untuk Ubuntu Server 24.04 LTS & Debian 12

---

## 📋 Daftar Isi
1. [Persiapan Server](#persiapan-server)
2. [Instalasi Cockpit dan Podman](#instalasi-cockpit-dan-podman)
3. [Konfigurasi Podman Rootless](#konfigurasi-podman-rootless)
4. [Expose Port di Bawah 1024](#expose-port-di-bawah-1024)
5. [Konfigurasi Firewall](#konfigurasi-firewall)
6. [Best Practices Keamanan](#best-practices-keamanan)
7. [Troubleshooting](#troubleshooting)

---

## 🔧 Persiapan Server

### 1. Update dan Upgrade System
```bash
sudo apt update && sudo apt upgrade -y
```

### 2. Install Dependencies Dasar
```bash
sudo apt install -y \
  curl \
  wget \
  git \
  vim \
  htop \
  net-tools \
  jq \
  ca-certificates \
  gnupg \
  lsb-release \
  apt-transport-https \
  software-properties-common \
  ufw
```

### 3. Verifikasi Sistem
```bash
# Cek versi Ubuntu/Debian
lsb_release -a

# Cek kernel version (minimal 5.4 untuk Podman)
uname -r

# Cek architecture
uname -m
```

---

## 🚀 Instalasi Cockpit dan Podman

### 1. Instalasi Cockpit

#### Untuk Ubuntu Server 24.04 LTS:
```bash
sudo apt install -y cockpit cockpit-podman cockpit-packagekit
```

#### Untuk Debian 12:
```bash
sudo apt install -y cockpit cockpit-podman cockpit-packagekit
```

### 2. Aktivasi Cockpit Service
```bash
# Mulai service
sudo systemctl start cockpit.socket

# Enable auto-start
sudo systemctl enable cockpit.socket

# Verifikasi status
sudo systemctl status cockpit.socket
```

### 3. Instalasi Podman

#### Untuk Ubuntu Server 24.04 LTS:
```bash
sudo apt install -y podman podman-compose slirp4netns
```

#### Untuk Debian 12:
Debian 12 memerlukan repository backports untuk versi terbaru:
```bash
# Tambah repository backports
echo "deb http://deb.debian.org/debian bookworm-backports main contrib non-free" | sudo tee /etc/apt/sources.list.d/backports.list

# Update
sudo apt update

# Instalasi dari backports
sudo apt install -y -t bookworm-backports podman podman-compose slirp4netns
```

### 4. Verifikasi Instalasi
```bash
# Verifikasi Cockpit
curl -k https://localhost:9090

# Verifikasi Podman
podman --version

# Cek Podman system
sudo podman system info
```

---

## 🔐 Konfigurasi Podman Rootless

### 1. Buat User Non-Root (jika belum ada)
```bash
# Buat user admin dengan home directory
sudo useradd -m -s /bin/bash admin

# Atau gunakan user existing (contoh: ubuntu, debian)
# Skip langkah ini jika user sudah ada
```

### 2. Konfigurasi subuid dan subgid

#### Langkah A: Edit File subuid
```bash
sudo cat > /etc/subuid << 'EOF'
admin:100000:65536
EOF
```

#### Langkah B: Edit File subgid
```bash
sudo cat > /etc/subgid << 'EOF'
admin:100000:65536
EOF
```

#### Verifikasi Konfigurasi
```bash
sudo cat /etc/subuid
sudo cat /etc/subgid
```

### 3. Konfigurasi Podman Rootless untuk User Admin

#### Switch ke user admin
```bash
sudo su - admin
```

#### Inisialisasi Podman Rootless
```bash
# Jalankan podman images untuk initialize rootless environment
podman images

# Verifikasi socket rootless
ls -la ~/.local/share/podman/podman.sock
```

#### Setup User Lingkungan (sebagai user admin)
```bash
# Tambahkan ke ~/.bashrc
cat >> ~/.bashrc << 'EOF'

# Podman Rootless Configuration
export XDG_RUNTIME_DIR=/run/user/$(id -u)
export DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus
export PODMAN_USERNS=auto
EOF

# Apply konfigurasi
source ~/.bashrc
```

#### Enable Lingering (agar container jalan setelah user logout)
```bash
# Jalankan sebagai root
sudo loginctl enable-linger admin
```

### 4. Konfigurasi Global Podman

#### Edit/Buat ~/.config/containers/podman/containers.conf (User Level)
```bash
# Buat direktori jika belum ada
mkdir -p ~/.config/containers/podman

# Buat konfigurasi
cat > ~/.config/containers/podman/containers.conf << 'EOF'
# Podman Rootless Configuration

[containers]
# Use CNI for networking
cgroup_manager = "cgroupfs"
events_logger = "file"

# Security defaults
ipcns = "private"
network_backend = "netavark"

# Resource limits (optional)
pids_limit = 2048

[engine]
# Use specific runtime
runtime = "runc"
remote = false

# Network settings
default_network = "podman"

# Rootless user mapping
userns_mode = "auto"
EOF
```

#### Edit /etc/containers/storage.conf (Sistem Level - untuk semua user)
```bash
sudo tee /etc/containers/storage.conf > /dev/null << 'EOF'
[storage]
driver = "overlay"
graphroot = "/var/lib/containers/storage"
runroot = "/run/containers"

[storage.options]
mount_program = "/usr/libexec/podman/crun"

[storage.options.overlay]
mountopt = "nodev,metacopy=on"
EOF
```

### 5. Verifikasi Konfigurasi Rootless (sebagai user admin)
```bash
# Test Podman as rootless
podman run --rm busybox echo "Podman Rootless Working!"

# Verifikasi user namespace
podman run --rm busybox id

# Lihat running containers
podman ps -a

# Lihat system info
podman system info
```

---

## 🔌 Expose Port di Bawah 1024

### ⚠️ Masalah: User Non-Root Tidak Bisa Bind Port < 1024

Solusi: Gunakan **net.ipv4.ip_unprivileged_port_start** via sysctl

### 1. Konfigurasi sysctl Persistent

#### Edit /etc/sysctl.d/99-podman-ports.conf
```bash
sudo tee /etc/sysctl.d/99-podman-ports.conf > /dev/null << 'EOF'
# Allow unprivileged users to bind ports below 1024 for Podman Rootless
net.ipv4.ip_unprivileged_port_start = 80
EOF
```

#### Apply Konfigurasi
```bash
# Load sysctl settings
sudo sysctl -p /etc/sysctl.d/99-podman-ports.conf

# Verifikasi
sudo sysctl net.ipv4.ip_unprivileged_port_start
```

### 2. Alternative: Menggunakan Port Mapping

Jika tidak ingin mengubah sysctl, gunakan port forwarding di host:

```bash
# Port forward di firewall atau reverse proxy
# Contoh dengan nginx atau caddy sebagai reverse proxy
# Caddy listening di port 80/443 sebagai root atau dengan sudo
# Podman container di port 8080+
```

### 3. Verifikasi Port Binding (sebagai user admin)

```bash
# Test dengan simple HTTP server di port 80
podman run --rm -d \
  --name test-web \
  -p 80:8080 \
  caddy:latest \
  caddy file-server --listen :8080

# Verifikasi
curl -v http://localhost:80

# Cleanup
podman stop test-web
podman rm test-web
```

---

## 🔥 Konfigurasi Firewall (UFW)

UFW adalah default firewall di Ubuntu/Debian yang mudah dikonfigurasi.

### 1. Enable UFW
```bash
# Check status
sudo ufw status

# Enable UFW
sudo ufw --force enable

# Verifikasi
sudo ufw status verbose
```

### 2. Konfigurasi Rule Dasar

#### Allow SSH (CRITICAL - jangan blok!)
```bash
sudo ufw allow 22/tcp
sudo ufw allow 22/udp
```

#### Allow HTTP & HTTPS
```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

#### Deny Everything Else Inbound (Default Policy)
```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
```

### 3. Amankan Cockpit Dashboard (Port 9090)

#### Opsi A: Restrict Cockpit ke Localhost Only
```bash
# Edit konfigurasi Cockpit
sudo nano /etc/cockpit/cockpit.conf
```

Tambahkan atau edit bagian [WebService]:
```ini
[WebService]
# Listen hanya di localhost
Origins = http://localhost http://localhost:9090
Listen = 127.0.0.1:9090
```

Restart Cockpit:
```bash
sudo systemctl restart cockpit
```

#### Opsi B: Izinkan Cockpit dari IP Spesifik Saja
```bash
# Allow dari IP admin office (ganti dengan IP Anda)
sudo ufw allow from 203.0.113.10 to any port 9090 proto tcp

# Block port 9090 dari internet
sudo ufw deny 9090/tcp
```

#### Opsi C: Reverse Proxy Cockpit via Caddy/Nginx

Setup nginx/caddy untuk menghandle SSL dan routing:

```bash
# Contoh dengan Caddy
podman run -d \
  --name caddy-reverse-proxy \
  -p 80:80 -p 443:443 \
  -v /etc/caddy/Caddyfile:/etc/caddy/Caddyfile:ro \
  -v caddy-data:/data \
  -v caddy-config:/config \
  caddy:latest
```

### 4. Verifikasi Konfigurasi Firewall
```bash
# List semua rules
sudo ufw show added

# Reload firewall
sudo ufw reload

# Status detail
sudo ufw status numbered
```

### 5. Whitelist Podman dan Cockpit (Optional)

Jika ada kontainer yang perlu akses dari luar:

```bash
# Allow specific port untuk kontainer
sudo ufw allow 8080/tcp
sudo ufw allow 3306/tcp  # MySQL example
```

---

## 🛡️ Best Practices Keamanan Podman

### 1. Security Scanning & Vulnerabilities

#### Install Trivy untuk scanning image
```bash
# Install Trivy (Ubuntu/Debian)
sudo apt install -y trivy

# Scan image sebelum run
trivy image busybox
```

#### Gunakan Certified Images
```bash
# Selalu gunakan official images dari registry yang terpercaya
# ❌ JANGAN: podman pull random-image:latest
# ✅ GUNAKAN: podman pull docker.io/library/busybox:latest
```

### 2. Container Security Configuration

#### Template Aman untuk Menjalankan Container
```bash
podman run -d \
  --name my-app \
  --security-opt=no-new-privileges:true \
  --cap-drop=ALL \
  --cap-add=NET_BIND_SERVICE \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,nodev,size=100m \
  --pids-limit 50 \
  --memory 512m \
  --memory-swap 512m \
  --cpus 1 \
  -u 1000:1000 \
  -p 8080:8080 \
  my-image:latest
```

Penjelasan flags:
- `--security-opt=no-new-privileges:true` - Cegah escalation privilege
- `--cap-drop=ALL` - Drop semua capabilities
- `--cap-add=NET_BIND_SERVICE` - Add hanya yang diperlukan
- `--read-only` - Root filesystem readonly
- `--tmpfs` - Temporary mount dengan permission ketat
- `--pids-limit` - Limit proses untuk prevent fork bomb
- `--memory` - Memory limit
- `-u 1000:1000` - Run sebagai non-root user

### 3. Network Security

#### Gunakan Custom Network
```bash
# Buat network isolated
podman network create my-network

# Run container dengan network custom
podman run -d --network my-network my-image:latest
```

#### Disable Network untuk Kontainer yang tidak butuh
```bash
podman run -d --network none my-image:latest
```

### 4. Volume Security

#### Best Practice Volume Mounting
```bash
# ❌ JANGAN: Mount seluruh filesystem
podman run -v /:/mnt my-image

# ✅ GUNAKAN: Mount direktori spesifik dengan permission limited
podman run -v /home/admin/app-data:/app:ro my-image

# ✅ GUNAKAN: Named volume dengan permission kontrol
podman volume create app-data
podman run -v app-data:/app:ro my-image
```

#### Cek volume permissions
```bash
podman volume ls
podman volume inspect app-data
```

### 5. Image Management & Registry Security

#### Konfigurasi Registries yang Aman
```bash
# Edit /etc/containers/registries.conf
sudo tee /etc/containers/registries.conf > /dev/null << 'EOF'
unqualified-search-registries = ["docker.io"]

[[registry]]
location = "docker.io"
insecure = false
blocked = false

[[registry]]
location = "gcr.io"
insecure = false

# Block untrusted registries
[[registry]]
location = "untrusted-registry.com"
blocked = true
EOF
```

#### Signatur Verifikasi (Advanced)
```bash
# Setup signature verification (GPG based)
podman run --signature-policy=/etc/containers/policy.json my-image:latest
```

### 6. Audit dan Logging

#### Enable Audit Logging untuk Podman
```bash
# Edit podman containers.conf
cat >> ~/.config/containers/podman/containers.conf << 'EOF'

[engine]
events_logger = "file"
log_driver = "journald"
EOF
```

#### Monitor Container Activity
```bash
# Real-time monitoring
podman events

# Lihat logs kontainer
podman logs -f container-name

# Lihat system logs
journalctl -u podman -f
sudo journalctl -u podman.service
```

#### Audit Permissions dengan auditctl
```bash
# Install auditd
sudo apt install -y auditd

# Monitor Podman binary
sudo auditctl -w /usr/bin/podman -p x

# Monitor container directories
sudo auditctl -w /var/lib/containers/ -p wa

# List active rules
sudo auditctl -l
```

### 7. Resource Limits & DoS Protection

#### Konfigurasi ulimit Sistem
```bash
# Edit /etc/security/limits.conf
sudo tee -a /etc/security/limits.conf > /dev/null << 'EOF'
admin soft nofile 65536
admin hard nofile 65536
admin soft nproc 4096
admin hard nproc 4096
EOF

# Apply changes
sudo sysctl -p
```

#### Per-Container Resource Limits
```bash
podman run -d \
  --memory 1g \
  --memory-swap 1.5g \
  --cpus 2 \
  --pids-limit 100 \
  --ulimit nofile=1024 \
  --ulimit nproc=1024 \
  my-image:latest
```

### 8. Privilege Escalation Prevention

#### Verify Rootless Mode
```bash
# Jalankan sebagai admin user
podman unshare id

# Harus output: uid=0(root) gid=0(root) groups=0(root)
# Tapi secara actual non-root di host
```

#### Check User Namespaces
```bash
podman run --rm busybox cat /proc/self/uid_map
```

### 9. SELinux/AppArmor Integration

#### Untuk Ubuntu (AppArmor)
```bash
# Verifikasi AppArmor active
aa-status

# Podman otomatis generate profile untuk containers
podman run --rm ubuntu bash -c "cat /proc/self/attr/current"
```

#### Untuk Debian (jika menggunakan SELinux)
```bash
# Install SELinux utilities
sudo apt install -y selinux-utils

# Check SELinux status
getenforce

# Run container dengan SELinux context
podman run --security-opt label=type:container_t my-image
```

### 10. Regular Maintenance & Updates

#### Automated Image Updates
```bash
# Manual update
podman pull my-image:latest

# Atau gunakan tools seperti podman-auto-update
sudo apt install -y podman-auto-update

# Enable auto-update
sudo systemctl enable podman-auto-update.timer
sudo systemctl start podman-auto-update.timer
```

#### Cleanup Unused Resources
```bash
# Remove dangling images
podman image prune -a

# Remove unused volumes
podman volume prune

# Remove exited containers
podman container prune

# Full system cleanup
podman system prune -a
```

#### Backup Image & Data
```bash
# Backup image
podman save my-image:latest | gzip > my-image.tar.gz

# Backup volume
sudo tar czf volume-backup.tar.gz /var/lib/containers/storage/volumes/

# Restore
gunzip my-image.tar.gz | podman load
```

---

## 🔧 Troubleshooting

### 1. Cockpit Tidak Accessible

#### Cek Service Status
```bash
sudo systemctl status cockpit.socket
sudo systemctl status cockpit.service

# Restart jika diperlukan
sudo systemctl restart cockpit.socket
```

#### Verifikasi Port 9090
```bash
sudo netstat -tlnp | grep 9090
# atau
sudo ss -tlnp | grep 9090
```

#### Check Firewall
```bash
sudo ufw status | grep 9090
```

### 2. Podman Rootless Permission Issues

#### Error: "cannot change permissions"
```bash
# Cek subuid/subgid
cat /etc/subuid | grep admin
cat /etc/subgid | grep admin

# Verify user namespace
podman unshare id

# Restart user session
sudo systemctl restart user@$(id -u admin)
```

#### Error: "XDG_RUNTIME_DIR not set"
```bash
# Set environment variable
export XDG_RUNTIME_DIR=/run/user/$(id -u)

# Permanent: add to ~/.bashrc
echo "export XDG_RUNTIME_DIR=/run/user/\$(id -u)" >> ~/.bashrc
source ~/.bashrc
```

### 3. Port Binding < 1024 Tidak Bekerja

#### Verifikasi sysctl setting
```bash
sudo sysctl net.ipv4.ip_unprivileged_port_start
# Output: net.ipv4.ip_unprivileged_port_start = 80
```

#### Try dengan Port >= 1024
```bash
# Test dengan port 8080 dulu
podman run -d -p 8080:8080 my-image

# Jika berhasil, masalah ada di kernel setting
```

#### Reset ke default jika perlu
```bash
sudo sysctl net.ipv4.ip_unprivileged_port_start=1024
```

### 4. Container Network Issues

#### Cek Network Configuration
```bash
# List networks
podman network ls

# Inspect network
podman network inspect podman

# Test connectivity
podman run --rm busybox ping 8.8.8.8
```

#### DNS Resolution Issues
```bash
# Edit /etc/resolv.conf dalam container
podman run --dns 8.8.8.8 --dns 8.8.4.4 my-image

# Atau konfigurasi global
sudo tee /etc/containers/containers.conf > /dev/null << 'EOF'
[containers]
dns_servers = ["8.8.8.8", "8.8.4.4"]
EOF
```

### 5. Firewall Blocking Connections

#### Debug dengan UFW
```bash
# Enable UFW logging
sudo ufw logging on

# View blocked traffic
sudo tail -f /var/log/ufw.log

# Test specific port
sudo nc -lv 8080 &
curl -v http://localhost:8080
```

#### Bypass UFW temporarily untuk testing
```bash
# Disable UFW (HATI-HATI!)
sudo ufw disable

# Enable kembali
sudo ufw enable
```

### 6. Storage Issues

#### Low Disk Space
```bash
# Check storage usage
sudo du -sh /var/lib/containers

# Check available space
df -h

# Cleanup
podman system prune -a
```

#### Permission Denied on Volume
```bash
# Check volume permissions
ls -la /var/lib/containers/storage/volumes/

# Fix permissions
sudo chown -R root:root /var/lib/containers
sudo chmod -R 755 /var/lib/containers
```

---

## 📝 Cheat Sheet - Commands Penting

### Cockpit
```bash
# Start/Stop/Status
sudo systemctl start cockpit.socket
sudo systemctl stop cockpit.socket
sudo systemctl status cockpit.socket

# Enable on boot
sudo systemctl enable cockpit.socket

# Access Web UI
# https://your-server-ip:9090
```

### Podman - Container Management
```bash
# Run container
podman run -d --name myapp -p 8080:80 nginx:latest

# List containers
podman ps -a

# Start/Stop/Remove
podman start myapp
podman stop myapp
podman rm myapp

# Logs & Exec
podman logs -f myapp
podman exec -it myapp bash

# Inspect & Stats
podman inspect myapp
podman stats myapp
```

### Podman - Image Management
```bash
# Search & Pull
podman search nginx
podman pull nginx:latest

# List images
podman images

# Remove image
podman rmi nginx:latest

# Tag image
podman tag nginx:latest myregistry/nginx:v1
```

### System Maintenance
```bash
# Cleanup
podman system prune -a
podman image prune -a
podman volume prune
podman container prune

# System info
podman system info
podman system df

# Check logs
journalctl -u podman -f
sudo journalctl -u cockpit.service -f
```

---

## ✅ Checklist Post-Installation

- [ ] Cockpit accessible di https://localhost:9090
- [ ] Podman rootless berjalan sebagai user admin
- [ ] Dapat bind port 80/443 dari rootless container
- [ ] UFW enable dan hanya port 22, 80, 443 terbuka ke publik
- [ ] Cockpit port 9090 restricted ke localhost atau IP whitelist
- [ ] subuid/subgid dikonfigurasi di /etc/subuid dan /etc/subgid
- [ ] sysctl net.ipv4.ip_unprivileged_port_start = 80 sudah di-set
- [ ] Container berjalan dengan security best practices
- [ ] Audit logging enabled
- [ ] Regular backup strategy in place

---

## 📚 Referensi & Resources

- **Cockpit Documentation**: https://cockpit-project.org/
- **Podman Documentation**: https://podman.io/
- **SELinux Integration**: https://podman.io/blogs/2021/02/04/selinux.html
- **Podman Security**: https://www.redhat.com/en/blog/container-security-podman
- **UFW Firewall Guide**: https://wiki.ubuntu.com/UncomplicatedFirewall
- **sysctl Configuration**: https://man7.org/linux/man-pages/man5/sysctl.conf.5.html

---

## 📞 Support & Questions

Untuk bantuan lebih lanjut, silakan:
1. Check logs: `journalctl -f` atau `podman logs -f container-name`
2. Verify configuration: Gunakan commands di section Troubleshooting
3. Community: https://podman.io/community atau https://ubuntu.com/

---

**Last Updated**: June 2026  
**Tested On**: Ubuntu Server 24.04 LTS, Debian 12  
**Author**: Senior Linux System Administrator