# PANDUAN LENGKAP: TAILSCALE MESH VPN PADA DEBIAN 12 (BOOKWORM)
## Isolasi Layanan Sensitif dari Internet Publik

**Versi:** 1.0  
**Tanggal:** Juni 2026  
**Kompatibilitas:** Debian 12 Bookworm  
**Penulis:** Senior System Administrator & Network Security Expert

---

## 📋 DAFTAR ISI

1. [Pendahuluan & Arsitektur](#pendahuluan--arsitektur)
2. [Prasyarat Sistem](#prasyarat-sistem)
3. [Instalasi Tailscale di Server](#instalasi-tailscale-di-server)
4. [Instalasi & Koneksi Client](#instalasi--koneksi-client)
5. [Isolasi Layanan Sensitif](#isolasi-layanan-sensitif)
6. [Konfigurasi Firewall UFW](#konfigurasi-firewall-ufw)
7. [Verifikasi & Testing](#verifikasi--testing)
8. [Tips Dashboard Tailscale](#tips-dashboard-tailscale)
9. [Troubleshooting](#troubleshooting)
10. [Keamanan Lanjutan](#keamanan-lanjutan)

---

## Pendahuluan & Arsitektur

### Tujuan Implementasi

Dokumen ini dirancang untuk membantu Anda menciptakan infrastruktur jaringan yang aman dengan karakteristik:

- ✅ **Isolasi Penuh**: SSH, Code-Server, Database **TIDAK BISA** diakses dari internet publik
- ✅ **Akses Terkontrol**: Hanya bisa diakses dari client Linux Debian/Ubuntu yang terhubung ke Tailnet yang sama
- ✅ **Enkripsi End-to-End**: Semua traffic dienkripsi menggunakan Wireguard
- ✅ **Zero Trust Network**: Setiap device harus terautentikasi sebelum bisa mengakses layanan

### Arsitektur Jaringan

```
┌─────────────────────────────────────────────────────────────┐
│                    INTERNET PUBLIK (0.0.0.0/0)              │
│                                                             │
│  ❌ SSH (port 22)      ❌ Code-Server (port 3000)          │
│  ❌ MySQL (port 3306)  ❌ PostgreSQL (port 5432)          │
└─────────────────────────────────────────────────────────────┘
                              │
                    (UFW BLOCK: Firewall)
                              │
┌─────────────────────────────────────────────────────────────┐
│          SERVER DEBIAN 12 (IP Publik: XXX.XXX.XXX.XXX)      │
│                                                             │
│  ✅ INTERFACE TAILSCALE (tailscale0)                       │
│     └─ IP Tailscale: 100.x.y.z                             │
│                                                             │
│  📌 LAYANAN YANG TERIKAT (Bind):                           │
│     • SSH              → 127.0.0.1:22 atau 100.x.y.z:22    │
│     • Code-Server      → 127.0.0.1:3000 atau 100.x.y.z:3000│
│     • MySQL/PostgreSQL → 127.0.0.1:3306/5432              │
└─────────────────────────────────────────────────────────────┘
                              △
                              │
                    (Tunnel Encrypted via
                     Wireguard/Tailscale)
                              │
           ┌──────────────────┴──────────────────┐
           │                                     │
      ┌────────────────┐            ┌────────────────────┐
      │   CLIENT 1     │            │   CLIENT 2        │
      │ (Linux/Debian) │            │ (Linux/Ubuntu)    │
      │  100.a.b.c     │            │  100.a.b.d        │
      └────────────────┘            └────────────────────┘
        ✅ SSH OK                      ✅ SSH OK
        ✅ DB OK                       ✅ DB OK
        ✅ Code-Server OK              ✅ Code-Server OK
```

---

## Prasyarat Sistem

Sebelum memulai implementasi, pastikan Anda memiliki:

### Requirements Minimum

1. **Server Debian 12 Bookworm** yang sudah terinstall
2. **Koneksi Internet Stabil** pada server dan client
3. **Akun Tailscale Gratis atau Berbayar** (daftar di https://tailscale.com)
4. **Hak Akses Root/Sudo** pada server dan client
5. **Minimal 1 Client Linux** (Debian atau Ubuntu untuk testing)
6. **Systemd** sebagai init system (standar di Debian 12)

### Verifikasi Sistem

```bash
# Cek versi Debian
cat /etc/debian_version

# Cek systemd tersedia
systemctl --version

# Cek koneksi internet
ping -c 4 1.1.1.1

# Cek akses root
sudo whoami  # Output: root
```

---

## Instalasi Tailscale di Server

### Langkah 1: Update Repository Sistem

```bash
# Update package list
sudo apt update

# Upgrade installed packages (opsional tapi disarankan)
sudo apt upgrade -y
```

### Langkah 2: Menambahkan Repository Resmi Tailscale

Tailscale menyediakan repository resmi untuk Debian. Lakukan hal berikut:

```bash
# Install curl jika belum ada
sudo apt install -y curl

# Tambahkan GPG key dari Tailscale
curl -fsSL https://pkgs.tailscale.com/stable/debian/tailscale.asc | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null

# Tambahkan repository Tailscale
curl -fsSL https://pkgs.tailscale.com/stable/debian/tailscale.list | sudo tee /etc/apt/sources.list.d/tailscale.list

# Update lagi untuk mengenali repository baru
sudo apt update
```

### Langkah 3: Instalasi Package Tailscale

```bash
# Install tailscale
sudo apt install -y tailscale

# Verifikasi instalasi
tailscale version

# Output contoh:
# tailscale version 1.46.1 (go1.21)
```

### Langkah 4: Enable dan Start Service Tailscale

```bash
# Enable tailscale daemon untuk otomatis start saat boot
sudo systemctl enable tailscaled

# Start service tailscale
sudo systemctl start tailscaled

# Verifikasi status service
sudo systemctl status tailscaled

# Output contoh:
# ● tailscaled.service - Tailscale client daemon
#      Loaded: loaded (/lib/systemd/system/tailscaled.service; enabled; vendor preset: enabled)
#      Active: active (running) since Fri 2024-06-14 10:30:45 UTC; 2min ago
```

### Langkah 5: Autentikasi Server ke Tailscale Account

Langkah ini menghubungkan server Anda ke akun Tailscale:

```bash
# Lakukan authentikasi
sudo tailscale up

# Output:
# To authenticate, visit:
#
#   https://login.tailscale.com/a/XXXXXXXXXXXXX
#
# Waiting for auth...
```

**📌 PENTING**: Buka URL yang ditampilkan di browser Anda, login dengan akun Tailscale, dan approve device tersebut.

```bash
# Setelah approval dari browser, tunggu pesan sukses:
# (Connection status updated.)
# (Connected)
```

### Langkah 6: Verifikasi Koneksi & Dapatkan IP Tailscale

```bash
# Cek status koneksi
sudo tailscale status

# Output contoh:
# 100.100.100.100   server-debian12          alias@    linux   -

# Dapatkan IP Tailscale IPv4
sudo tailscale ip -4

# Output:
# 100.100.100.100

# Simpan IP ini untuk referensi selanjutnya
echo "IP Tailscale Server: $(sudo tailscale ip -4)" > ~/tailscale_server_ip.txt
cat ~/tailscale_server_ip.txt
```

**🔖 Catatan Penting**: IP format `100.x.y.z` adalah IP private yang HANYA bisa diakses dari perangkat dalam Tailnet yang sama.

---

## Instalasi & Koneksi Client

### Instalasi Tailscale di Client Linux (Debian/Ubuntu)

Lakukan instalasi yang sama di setiap client Linux Anda:

#### Langkah 1: Add Repository Tailscale

```bash
# Sistem dengan sudo
sudo apt update

sudo curl -fsSL https://pkgs.tailscale.com/stable/debian/tailscale.asc | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null

sudo curl -fsSL https://pkgs.tailscale.com/stable/debian/tailscale.list | sudo tee /etc/apt/sources.list.d/tailscale.list

sudo apt update
```

#### Langkah 2: Install Tailscale

```bash
sudo apt install -y tailscale

# Verifikasi
tailscale version
```

#### Langkah 3: Enable dan Start Service

```bash
sudo systemctl enable tailscaled
sudo systemctl start tailscaled
sudo systemctl status tailscaled
```

#### Langkah 4: Authentikasi Client

```bash
sudo tailscale up

# Buka URL yang ditampilkan dan login dengan akun TAILSCALE YANG SAMA
# seperti yang digunakan untuk server
```

#### Langkah 5: Verifikasi Koneksi Client

```bash
# Cek status
sudo tailscale status

# Dapatkan IP Tailscale client
sudo tailscale ip -4

# Test ping ke server (menggunakan IP Tailscale server)
ping -c 4 100.100.100.100  # Ganti dengan IP Tailscale server Anda
```

### Multi-Client Setup

Jika Anda memiliki beberapa client, ulangi proses di atas untuk setiap client. Semua device akan otomatis berada dalam Tailnet yang sama dan bisa saling berkomunikasi melalui IP `100.x.y.z`.

---

## Isolasi Layanan Sensitif

Langkah ini memastikan bahwa SSH, Code-Server, dan Database HANYA bisa diakses melalui interface Tailscale.

### Langkah 1: Verifikasi IP Tailscale Server

```bash
# Di server, jalankan:
sudo tailscale ip -4

# Catat output, misal: 100.100.100.100
TAILSCALE_IP=$(sudo tailscale ip -4)
echo "IP Tailscale: $TAILSCALE_IP"
```

### Langkah 2: Isolasi SSH

SSH harus HANYA accessible melalui Tailscale, bukan dari IP publik:

#### Option A: Bind ke Localhost + Firewall Rules (Rekomendasi)

SSH secara default sudah bind ke `0.0.0.0:22`. Kita akan menggunakan firewall untuk membatasinya.

Lanjut ke bagian **Konfigurasi Firewall UFW** untuk konfigurasi rules.

#### Option B: Bind SSH Hanya ke Interface Tailscale (Advanced)

Jika ingin lebih ketat, edit konfigurasi SSH:

```bash
# Backup original sshd config
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# Edit sshd config
sudo nano /etc/ssh/sshd_config
```

Cari atau tambahkan baris berikut:

```
# Bind hanya ke interface lokal dan Tailscale
# ListenAddress 0.0.0.0
# ListenAddress ::

ListenAddress 127.0.0.1
ListenAddress ::1
ListenAddress 100.100.100.100  # Ganti dengan IP Tailscale server Anda
```

Simpan dan restart SSH:

```bash
# Test syntax
sudo sshd -t

# Jika OK, restart service
sudo systemctl restart ssh

# Verifikasi
sudo ss -tlnp | grep ssh
```

### Langkah 3: Isolasi Code-Server

Code-Server default bind ke `0.0.0.0:8080` atau `127.0.0.1:8080`. Ubah agar hanya listening di localhost atau Tailscale IP:

#### Jika Code-Server Terinstal (misal via Docker atau standalone)

```bash
# Cari proses code-server
ps aux | grep code-server

# Edit konfigurasi code-server (biasanya di ~/.config/code-server/config.yaml)
nano ~/.config/code-server/config.yaml
```

Ubah baris `bind-addr` menjadi:

```yaml
bind-addr: 127.0.0.1:8080
# atau
bind-addr: 100.100.100.100:8080
```

Restart code-server:

```bash
# Jika running via systemd
sudo systemctl restart code-server

# atau kill dan restart manual
pkill -f code-server
code-server &
```

Verifikasi:

```bash
sudo ss -tlnp | grep code-server
# Output harus menunjukkan 127.0.0.1:8080 atau 100.x.y.z:8080
```

### Langkah 4: Isolasi Database (MySQL/PostgreSQL)

#### Untuk MySQL

```bash
# Edit MySQL config
sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf
```

Cari atau tambahkan:

```
[mysqld]
bind-address = 127.0.0.1
# atau untuk Tailscale IP:
# bind-address = 100.100.100.100
port = 3306
```

Restart MySQL:

```bash
sudo systemctl restart mysql

# Verifikasi
sudo ss -tlnp | grep mysql
```

#### Untuk PostgreSQL

```bash
# Edit PostgreSQL config
sudo nano /etc/postgresql/15/main/postgresql.conf
```

Cari atau ubah baris:

```
listen_addresses = 'localhost'
# atau
listen_addresses = '127.0.0.1, 100.100.100.100'
port = 5432
```

Restart PostgreSQL:

```bash
sudo systemctl restart postgresql

# Verifikasi
sudo ss -tlnp | grep postgres
```

### Langkah 5: Verifikasi Binding Services

```bash
# Cek semua services yang listening
sudo ss -tlnp

# Output harus menunjukkan:
# LISTEN  127.0.0.1:22        (SSH)
# LISTEN  127.0.0.1:8080      (Code-Server)
# LISTEN  127.0.0.1:3306      (MySQL)
# LISTEN  127.0.0.1:5432      (PostgreSQL)
#
# ❌ TIDAK boleh ada LISTEN 0.0.0.0 atau IP publik untuk service-service ini
```

---

## Konfigurasi Firewall UFW

⚠️ **PERINGATAN PENTING**: Saat mengaktifkan firewall, Anda bisa terkunci keluar dari sesi SSH. Ikuti langkah-langkah ini dengan **sangat hati-hati**.

### Langkah 1: Cek Status UFW

```bash
# Cek apakah UFW sudah active
sudo ufw status

# Output: 'Status: inactive' atau 'Status: active'
```

### Langkah 2: Reset UFW ke Default (Opsional)

Jika UFW sudah ada konfigurasi sebelumnya:

```bash
# HATI-HATI: ini akan menghapus semua rules
sudo ufw reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
```

### Langkah 3: Tambahkan Rules UFW

**🔴 LANGKAH KRITIS**: Jangan enable UFW sampai semua rules sudah ditambahkan!

#### 3a. Izinkan SSH (SANGAT PENTING DULU!)

```bash
# Izinkan SSH dari mana saja (sebagai safety net sementara)
sudo ufw allow 22/tcp comment "SSH - Will restrict later via Tailscale"

# atau lebih aman: izinkan hanya dari Tailscale interface
# sudo ufw allow in on tailscale0 to any port 22
```

#### 3b. Izinkan Incoming dari Interface Tailscale

```bash
# Izinkan semua incoming dari interface Tailscale
sudo ufw allow in on tailscale0 from any to any comment "Tailscale interface"

# atau lebih spesifik per service:
sudo ufw allow in on tailscale0 to any port 22 comment "SSH via Tailscale"
sudo ufw allow in on tailscale0 to any port 3000 comment "Code-Server via Tailscale"
sudo ufw allow in on tailscale0 to any port 3306 comment "MySQL via Tailscale"
sudo ufw allow in on tailscale0 to any port 5432 comment "PostgreSQL via Tailscale"
```

#### 3c. Blokir Services dari Internet Publik

```bash
# Blokir SSH dari internet publik (kecuali dari Tailscale)
sudo ufw deny 22/tcp comment "Block SSH from public internet"

# Blokir Code-Server dari internet publik
sudo ufw deny 3000/tcp comment "Block Code-Server from public internet"

# Blokir MySQL dari internet publik
sudo ufw deny 3306/tcp comment "Block MySQL from public internet"

# Blokir PostgreSQL dari internet publik
sudo ufw deny 5432/tcp comment "Block PostgreSQL from public internet"
```

#### 3d. Izinkan HTTPS (Port 443) untuk Publik

Jika server Anda menjalankan web service di port 443:

```bash
sudo ufw allow 443/tcp comment "HTTPS - public"
sudo ufw allow 80/tcp comment "HTTP - public"
```

#### 3e. Izinkan Outgoing DNS (untuk Tailscale)

```bash
sudo ufw allow out 53 comment "DNS"
```

### Langkah 4: Cek Rules Sebelum Enable

```bash
# Lihat semua rules yang akan diaplikasikan
sudo ufw show added

# Contoh output yang benar:
# Added user rules (see 'ufw status' for running firewall):
# ufw allow 22/tcp comment "SSH"
# ufw allow in on tailscale0 from any to any comment "Tailscale interface"
# ufw deny 22/tcp comment "Block SSH from public"
# ufw deny 3000/tcp comment "Block Code-Server"
# ufw allow 443/tcp comment "HTTPS"
# ufw allow 80/tcp comment "HTTP"
```

### Langkah 5: Enable UFW

**⚠️ JANGAN LOMPATI LANGKAH INI**: Pastikan Anda tetap terhubung ke session SSH saat ini!

```bash
# Enable firewall
sudo ufw enable

# Ketika ditanya "Command may disrupt existing SSH connections. Proceed with operation (y|n)?"
# Ketik: y
# Lalu tekan Enter
```

**Tunggu 5-10 detik dan periksa koneksi SSH Anda masih berjalan atau tidak.**

### Langkah 6: Verifikasi Status Firewall

```bash
# Cek status firewall
sudo ufw status verbose

# Output contoh:
# Status: active
# Logging: on (low)
# Default: deny (incoming), allow (outgoing), disabled (routed)
# New profiles: skip
#
# To                         Action      From
# --                         ------      ----
# 22/tcp                     ALLOW       Anywhere
# Anywhere on tailscale0     ALLOW       Anywhere
# 22/tcp (v6)                ALLOW       Anywhere (v6)
# 443/tcp                    ALLOW       Anywhere
# 443/tcp (v6)               ALLOW       Anywhere
# 22/tcp                     DENY        Anywhere
# 3000/tcp                   DENY        Anywhere
# 3306/tcp                   DENY        Anywhere
# 5432/tcp                   DENY        Anywhere
```

### Langkah 7: Test dari Client

Dari client Debian/Ubuntu yang terkoneksi ke Tailscale:

```bash
# Test SSH ke server via Tailscale IP
ssh user@100.100.100.100

# Test akses ke Code-Server
curl http://100.100.100.100:3000

# Test MySQL
mysql -h 100.100.100.100 -u root -p

# Test PostgreSQL
psql -h 100.100.100.100 -U postgres
```

**Semua test di atas HARUS berhasil!**

### Langkah 8: Test Blocked Ports (dari Internet Publik)

Gunakan tool online seperti `portscan.com` atau `nmap` dari host eksternal:

```bash
# Dari host publik (bukan dalam Tailnet):
nmap -p 22,3000,3306,5432 <IP_PUBLIK_SERVER>

# Output harus: Port 22, 3000, 3306, 5432 semuanya CLOSED atau FILTERED
```

---

## Verifikasi & Testing

### Pre-Testing Checklist

```bash
# Di SERVER, jalankan:
echo "=== SERVER VERIFICATION ==="

# 1. Cek Tailscale status
echo "1. Tailscale Status:"
sudo tailscale status | head -5

# 2. Cek IP Tailscale
echo "2. Tailscale IP:"
sudo tailscale ip -4

# 3. Cek binding services
echo "3. Services Binding:"
sudo ss -tlnp | grep -E "(ssh|3000|3306|5432)"

# 4. Cek UFW status
echo "4. UFW Status:"
sudo ufw status | head -3

# 5. Cek interface tailscale0
echo "5. Tailscale Interface:"
ip addr show tailscale0 | grep "inet "
```

### Testing Akses dari Client

```bash
# Di CLIENT, jalankan:
echo "=== CLIENT VERIFICATION ==="

# 1. Cek koneksi ke Tailnet
echo "1. Tailscale Status:"
sudo tailscale status | head -5

# 2. Test ping ke server
echo "2. Ping Server:"
ping -c 3 100.100.100.100

# 3. Test SSH
echo "3. SSH Test:"
ssh -v user@100.100.100.100 "echo SSH OK"

# 4. Test Code-Server (jika running)
echo "4. Code-Server Test:"
curl -I http://100.100.100.100:8080

# 5. Test Database (jika MySQL)
echo "5. MySQL Test:"
mysql -h 100.100.100.100 -u root -e "SELECT 1;" 2>/dev/null && echo "MySQL OK" || echo "MySQL Check"
```

### Monitoring Koneksi

```bash
# Monitor traffic Tailscale secara real-time
sudo tailscale netcheck

# Monitor interface statistics
watch -n 1 'ip -s addr show tailscale0'

# Monitor Tailscale daemon logs
sudo journalctl -u tailscaled -f --lines=20
```

---

## Tips Dashboard Tailscale

### Akses Dashboard Tailscale

1. **Buka**: https://login.tailscale.com
2. **Login** dengan akun Anda
3. **Pilih**: "Organization" atau "Personal" (sesuai setup Anda)

### Konfigurasi MagicDNS

MagicDNS memungkinkan Anda mengakses device menggunakan hostname, bukan IP:

**Di Dashboard:**
1. Pergi ke **DNS** → **Magic DNS**
2. Toggle **Enable MagicDNS** ke **ON**
3. Catat domain yang diberikan (contoh: `mynet.ts.net`)

**Hasil:**
- Server bisa diakses via: `server-debian12.mynet.ts.net`
- Client bisa diakses via: `client-ubuntu.mynet.ts.net`

**Di Terminal (Local):**

```bash
# Test MagicDNS (dari client)
ping server-debian12.mynet.ts.net

# Akses SSH dengan hostname
ssh user@server-debian12.mynet.ts.net

# Akses Code-Server dengan hostname
curl http://server-debian12.mynet.ts.net:8080
```

### Konfigurasi ACL (Access Control List)

⚠️ **Important**: ACL memerlukan Tailscale Teams atau Enterprise. Free tier memiliki keterbatasan.

**Untuk Free Tier:**

```json
{
  "Version": "1.0",
  "Groups": {},
  "Hosts": {},
  "TagOwners": {},
  "ACLs": [
    {
      "Action": "accept",
      "Principal": "*",
      "Resources": ["*:*"]
    }
  ],
  "Tests": []
}
```

**Untuk Teams/Enterprise (Recommended):**

Buat ACL yang lebih ketat:

```json
{
  "Version": "1.0",
  "Groups": {
    "group:admins": [
      "user1@example.com",
      "user2@example.com"
    ]
  },
  "Hosts": {
    "server": "100.100.100.100",
    "client1": "100.100.100.101"
  },
  "ACLs": [
    {
      "Action": "accept",
      "Principal": "group:admins",
      "Resources": [
        "server:22",
        "server:3000",
        "server:3306",
        "server:5432"
      ]
    },
    {
      "Action": "reject",
      "Principal": "*",
      "Resources": ["*:*"]
    }
  ],
  "Tests": [
    {
      "User": "user1@example.com",
      "Allow": ["server:22"],
      "Deny": ["server:3000"]
    }
  ]
}
```

### Device Management

**Di Dashboard:**
1. **Devices** → Lihat semua device dalam Tailnet
2. **Per Device**:
   - 🔑 **Key expiry**: Set expiration date untuk security
   - 📍 **Hostname**: Rename device dengan hostname yang meaningful
   - 🔐 **Enable key expiry**: Wajib rotate key setiap 90 hari
   - 🚫 **Disable**: Temporary disable device

**Best Practice:**

```bash
# Di server, set hostname meaningful
sudo tailscale set --hostname="debian12-production"

# Di client, set hostname meaningful
sudo tailscale set --hostname="ubuntu-workstation"
```

### Monitoring & Logging

**Di Dashboard:**
1. **Devices** → Pilih device → **View more**
2. Lihat:
   - Last seen
   - Connection status
   - IP addresses (public & Tailscale)
   - Operating system

---

## Troubleshooting

### Masalah: Client Tidak Bisa Ping Server

```bash
# Di client:
# 1. Cek koneksi ke Tailnet
sudo tailscale status

# Output HARUS menunjukkan server Anda dengan status "active"
# Jika tidak, kemungkinan server belum approve device

# 2. Di server, cek device approval
sudo tailscale status

# 3. Jika server belum terlihat, restart Tailscale
sudo systemctl restart tailscaled

# 4. Cek firewall rules
sudo ufw status | grep tailscale0
```

### Masalah: SSH Timeout atau Connection Refused

```bash
# Di server:
# 1. Cek SSH service running
sudo systemctl status ssh

# 2. Verifikasi SSH binding
sudo ss -tlnp | grep ssh

# 3. Cek UFW rules
sudo ufw show numbered | grep ssh

# 4. Test SSH locally
ssh localhost

# 5. Restart SSH
sudo systemctl restart ssh

# Di client:
# 1. Test dengan verbose flag
ssh -vvv user@100.100.100.100

# 2. Ping server terlebih dahulu
ping 100.100.100.100

# 3. Cek koneksi ke Tailnet
sudo tailscale status
```

### Masalah: Firewall Blocking SSH

**🔴 EMERGENCY FIX** (jika Anda terlocked):

Jika Anda tidak bisa SSH ke server setelah enable firewall:

```bash
# JIKA PUNYA PHYSICAL ACCESS:
# 1. Boot ke console lokal
# 2. Login sebagai root
# 3. Jalankan:

sudo ufw disable
sudo ufw reset
# Ulangi konfigurasi dari Langkah 3

# JIKA TIDAK PUNYA PHYSICAL ACCESS:
# 1. Hubungi provider VPS untuk console access
# 2. Login via IPMI/iLO/IConsole
# 3. Jalankan fix di atas
```

### Masalah: Database Connection Refused

```bash
# Di server:
# 1. Cek service running
sudo systemctl status mysql
# atau
sudo systemctl status postgresql

# 2. Cek binding
sudo ss -tlnp | grep -E "(mysql|postgres)"

# 3. Test koneksi lokal
mysql -u root -p
# atau
sudo -u postgres psql

# 4. Cek firewall
sudo ufw status | grep -E "(3306|5432)"

# Di client:
# 1. Test koneksi dengan verbose
mysql -h 100.100.100.100 -u root -p -v

# 2. Cek aplikasi config
cat ~/.config/app/db_config.ini  # Sesuaikan path
# Pastikan host adalah IP Tailscale server, bukan localhost
```

### Masalah: Tailscale Service Tidak Start

```bash
# Check logs
sudo journalctl -u tailscaled -n 50 -p err

# Restart dengan debug
sudo tailscale debug stat

# Force restart
sudo systemctl restart tailscaled

# Reinstall jika ada corruption
sudo apt remove --purge tailscale
sudo apt install tailscale
sudo systemctl start tailscaled
```

### Masalah: IP Tailscale Berubah-ubah

Ini adalah behavior normal, tapi bisa diatasi:

```bash
# Di dashboard Tailscale:
# 1. Devices → Server
# 2. Cek "IP Addresses"
# 3. Jika berubah, disable/enable device atau:

# Di server:
sudo tailscale logout
sudo tailscale up

# Atau force IP statik (tidak tersedia di free tier)
# Memerlukan Tailscale Teams
```

---

## Keamanan Lanjutan

### 1. SSH Key-Based Authentication Only

Disable password login:

```bash
# Edit SSH config
sudo nano /etc/ssh/sshd_config

# Ubah/tambahkan:
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
Protocol 2

# Test syntax
sudo sshd -t

# Restart
sudo systemctl restart ssh
```

Pastikan Anda sudah setup SSH key sebelum disable password:

```bash
# Generate key di client (jika belum ada)
ssh-keygen -t ed25519 -C "user@example.com"

# Copy key ke server
ssh-copy-id -i ~/.ssh/id_ed25519.pub user@100.100.100.100
```

### 2. Fail2Ban untuk Brute Force Protection

```bash
# Install fail2ban
sudo apt install -y fail2ban

# Create local config
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

# Edit config
sudo nano /etc/fail2ban/jail.local

# Cari dan ubah:
[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 3
findtime = 600
bantime = 3600

# Start & enable
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Verify
sudo fail2ban-client status sshd
```

### 3. Rotate Tailscale Keys Regularly

```bash
# Di dashboard Tailscale:
# 1. Devices → Device Anda
# 2. **Key expiry**: Set untuk 90 hari
# 3. Sebelum expired, jalankan:

sudo tailscale logout
sudo tailscale up
# Approve ulang di browser
```

### 4. Enable UFW Logging

```bash
# Enable detailed logging
sudo ufw logging on
sudo ufw logging high

# Monitor logs
sudo tail -f /var/log/ufw.log

# Contoh output:
# [UFW BLOCK] IN=eth0 OUT= MAC=... SRC=1.2.3.4 DST=X.X.X.X PROTO=TCP SPT=12345 DPT=22 WINDOW=1024 RES=0x00 SYN URGP=0
```

### 5. Database Security Hardening

#### MySQL

```bash
# Run security script
sudo mysql_secure_installation

# Set password policy
mysql -u root -p
mysql> VALIDATE_PASSWORD_COMPONENT INSTALL;
mysql> SET GLOBAL validate_password.policy='STRONG';
mysql> CREATE USER 'appuser'@'127.0.0.1' IDENTIFIED BY 'SecurePassword123!';
mysql> GRANT ALL PRIVILEGES ON appdb.* TO 'appuser'@'127.0.0.1';
mysql> FLUSH PRIVILEGES;
```

#### PostgreSQL

```bash
# Edit pg_hba.conf
sudo nano /etc/postgresql/15/main/pg_hba.conf

# Ensure local connections hanya via socket/127.0.0.1
# host    all             all             127.0.0.1/32            md5
# host    all             all             ::1/128                 md5

sudo systemctl restart postgresql
```

### 6. Regular Backup & Disaster Recovery

```bash
# Backup Tailscale config
sudo cp /var/lib/tailscale /tmp/tailscale.backup -r

# Backup application data
mysqldump -u root -p --all-databases > /tmp/mysql_backup.sql
pg_dump -U postgres --all > /tmp/postgres_backup.sql

# Encrypt backups
gpg --symmetric /tmp/mysql_backup.sql

# Move to safe location
cp /tmp/*.sql.gpg /mnt/secure_backup/
```

### 7. Monitoring & Alerting

```bash
# Install monitoring tools
sudo apt install -y htop iotop nethogs

# Monitor real-time
htop

# Monitor network
nethogs

# Monitor Tailscale
watch -n 5 'sudo tailscale netcheck'

# Setup systemd service monitoring
systemctl status tailscaled ssh mysql
```

---

## Checklist Implementasi Akhir

Sebelum declare production-ready, verifikasi semua poin ini:

- [ ] **Instalasi Tailscale**: Server dan minimal 1 client sudah terinstall
- [ ] **Koneksi Tailnet**: Semua device bisa saling ping via IP Tailscale
- [ ] **Service Binding**: SSH, Code-Server, DB hanya bind ke localhost/Tailscale IP
- [ ] **UFW Active**: Firewall aktif dan rules sesuai dokumentasi
- [ ] **Access Test**: SSH, Code-Server, DB bisa diakses via Tailscale IP
- [ ] **Block Test**: Port-port ini BLOCKED dari internet publik
- [ ] **MagicDNS**: Setup dan testing via hostname berhasil
- [ ] **Key Rotation**: Setup key expiry untuk security
- [ ] **Backup**: Backup data dan config sudah dilakukan
- [ ] **Documentation**: Dokumentasi perubahan disimpan untuk referensi
- [ ] **Incident Response**: Troubleshooting procedures siap jika ada issue

---

## Quick Reference Commands

Untuk referensi cepat:

```bash
# TAILSCALE COMMANDS
sudo tailscale up                          # Authenticate
sudo tailscale down                        # Disconnect
sudo tailscale status                      # Check status
sudo tailscale ip -4                       # Get Tailscale IPv4
sudo tailscale ping <hostname>             # Ping device
sudo tailscale netcheck                    # Network diagnostics
sudo systemctl restart tailscaled          # Restart service
sudo journalctl -u tailscaled -f           # View logs

# FIREWALL COMMANDS
sudo ufw status verbose                    # View all rules
sudo ufw allow 22/tcp                      # Allow port
sudo ufw deny 22/tcp                       # Block port
sudo ufw delete allow 22/tcp               # Delete rule
sudo ufw reset                             # Reset to defaults
sudo ufw enable                            # Turn on
sudo ufw disable                           # Turn off
sudo ufw reload                            # Reload rules

# SERVICE CHECK
sudo systemctl status tailscaled
sudo systemctl status ssh
sudo systemctl status mysql
sudo systemctl status postgresql

# PORT CHECK
sudo ss -tlnp | grep ssh
sudo ss -tlnp | grep 3000
sudo ss -tlnp | grep 3306
sudo ss -tlnp | grep 5432

# NETWORK TESTS
ping 100.100.100.100
ssh user@100.100.100.100
curl http://100.100.100.100:8080
mysql -h 100.100.100.100 -u root -p
psql -h 100.100.100.100 -U postgres
```

---

## Referensi & Resources

- **Tailscale Documentation**: https://tailscale.com/kb/
- **Tailscale Networking**: https://tailscale.com/kb/1016/network-architecture/
- **UFW Documentation**: https://help.ubuntu.com/community/UFW
- **Debian Security**: https://wiki.debian.org/Security/
- **SSH Hardening**: https://www.ssh.com/academy/ssh/best-practices
- **MySQL Security**: https://dev.mysql.com/doc/refman/8.0/en/security.html
- **PostgreSQL Security**: https://www.postgresql.org/docs/current/sql-syntax.html

---

## Support & Contact

Jika mengalami kesulitan:

1. **Check Logs**: `sudo journalctl -u tailscaled -f`
2. **Review Rules**: `sudo ufw status verbose`
3. **Test Connectivity**: `ping`, `curl`, `mysql`, `psql`
4. **Restart Services**: `sudo systemctl restart [service]`
5. **Check Dashboard**: https://login.tailscale.com

Untuk issue yang lebih kompleks:
- Tailscale Community: https://community.tailscale.com/
- Debian Forums: https://forums.debian.net/
- Stack Overflow: Tag `tailscale` dan `debian`

---

**Dokumen ini dibuat dengan perhatian detail untuk keamanan dan skalabilitas. Selalu test di environment non-production sebelum deploy ke production.**

**Last Updated: Juni 2026**  
**Version: 1.0**
