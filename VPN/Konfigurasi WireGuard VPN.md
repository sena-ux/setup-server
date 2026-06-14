# Panduan Teknis: Konfigurasi WireGuard VPN di Debian 12 (Bookworm)

> **Arsitektur:** Isolasi layanan sensitif (SSH, Code-Server, Database) dari akses internet publik menggunakan WireGuard VPN sebagai tunnel jaringan internal.

---

## Daftar Isi

1. [Arsitektur & Konsep](#1-arsitektur--konsep)
2. [Instalasi & Persiapan Server](#2-instalasi--persiapan-server)
3. [Konfigurasi WireGuard Server](#3-konfigurasi-wireguard-server)
4. [Konfigurasi & Koneksi Client](#4-konfigurasi--koneksi-client-linux-debianubuntu)
5. [Isolasi Layanan (Service Binding)](#5-isolasi-layanan-service-binding)
6. [Pengasahan Firewall (UFW)](#6-pengasahan-firewall-ufw)
7. [Verifikasi & Pemantauan](#7-verifikasi--pemantauan)
8. [Troubleshooting](#8-troubleshooting)

---

## 1. Arsitektur & Konsep

```
[ Internet Publik ]
        │
        │  Port 443 (HTTPS) ✓ Terbuka
        │  Port 51820/UDP (WireGuard) ✓ Terbuka
        │  Port 22 (SSH) ✗ DITOLAK
        │  Port 3306/5432 (DB) ✗ DITOLAK
        │  Port 8080 (Code-Server) ✗ DITOLAK
        │
   ┌────▼────────────────────────────────┐
   │         SERVER DEBIAN 12            │
   │   IP Publik: YOUR_SERVER_IP         │
   │   IP VPN   : 10.0.0.1/24           │
   │                                     │
   │  eth0 (publik) → wg0 (VPN tunnel)  │
   └─────────────────────────────────────┘
                    ▲
                    │  WireGuard Tunnel (Terenkripsi)
                    │
   ┌────────────────▼────────────────────┐
   │         CLIENT LINUX                │
   │   IP VPN: 10.0.0.2/32              │
   │   Akses SSH via 10.0.0.1:22 ✓      │
   │   Akses DB  via 10.0.0.1:5432 ✓    │
   │   Akses CS  via 10.0.0.1:8080 ✓    │
   └─────────────────────────────────────┘
```

**Prinsip utama:**
- Semua layanan internal hanya mendengarkan di antarmuka VPN (`10.0.0.1`) atau localhost (`127.0.0.1`).
- Firewall (UFW) memblokir port sensitif dari sumber mana pun kecuali subnet VPN (`10.0.0.0/24`).
- Satu-satunya pintu masuk dari internet publik adalah port WireGuard (`51820/UDP`).

---

## 2. Instalasi & Persiapan Server

### 2.1 Update Sistem

```bash
sudo apt update && sudo apt upgrade -y
```

### 2.2 Install WireGuard

```bash
sudo apt install wireguard wireguard-tools -y
```

Verifikasi instalasi:

```bash
wg --version
# Contoh output: wireguard-tools v1.0.20210914 - https://www.wireguard.com
```

### 2.3 Generate Kunci Kriptografi Server

WireGuard menggunakan pasangan kunci publik-privat berbasis kurva eliptik Curve25519.

```bash
# Buat direktori konfigurasi (jika belum ada) dan set izin ketat
sudo mkdir -p /etc/wireguard
sudo chmod 700 /etc/wireguard

# Generate private key server
wg genkey | sudo tee /etc/wireguard/server_private.key | wg pubkey | sudo tee /etc/wireguard/server_public.key

# Set izin file private key agar hanya bisa dibaca oleh root
sudo chmod 600 /etc/wireguard/server_private.key
```

Tampilkan nilai kunci untuk dicatat:

```bash
echo "=== SERVER PRIVATE KEY ==="
sudo cat /etc/wireguard/server_private.key

echo "=== SERVER PUBLIC KEY ==="
sudo cat /etc/wireguard/server_public.key
```

> ⚠️ **PERINGATAN:** Private key adalah rahasia absolut. Jangan pernah membagikan `server_private.key` ke siapa pun. Public key boleh dibagikan ke client.

### 2.4 Generate Kunci Kriptografi Client

```bash
# Generate private key client (lakukan di mesin client atau server sementara)
wg genkey | sudo tee /etc/wireguard/client1_private.key | wg pubkey | sudo tee /etc/wireguard/client1_public.key

sudo chmod 600 /etc/wireguard/client1_private.key
```

Tampilkan untuk dicatat:

```bash
echo "=== CLIENT1 PRIVATE KEY ==="
sudo cat /etc/wireguard/client1_private.key

echo "=== CLIENT1 PUBLIC KEY ==="
sudo cat /etc/wireguard/client1_public.key
```

### 2.5 Aktifkan IP Forwarding (Opsional tapi Direkomendasikan)

Aktifkan IP forwarding agar server dapat meneruskan paket antar antarmuka:

```bash
# Aktifkan sementara (hilang setelah reboot)
sudo sysctl -w net.ipv4.ip_forward=1

# Aktifkan permanen
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.d/99-wireguard.conf
sudo sysctl -p /etc/sysctl.d/99-wireguard.conf
```

---

## 3. Konfigurasi WireGuard Server

### 3.1 File Konfigurasi `/etc/wireguard/wg0.conf`

```bash
sudo nano /etc/wireguard/wg0.conf
```

Isi file konfigurasi lengkap:

```ini
##############################################
#   WireGuard Server Configuration          #
#   File: /etc/wireguard/wg0.conf           #
##############################################

[Interface]
# IP internal server di dalam jaringan VPN (gunakan notasi CIDR /24 untuk mendefinisikan subnet)
Address = 10.0.0.1/24

# Port yang akan didengarkan oleh WireGuard untuk koneksi masuk dari client
ListenPort = 51820

# Private key server — RAHASIA, jangan dibagikan
PrivateKey = <ISI_DENGAN_SERVER_PRIVATE_KEY>

# Simpan konfigurasi peer secara otomatis saat wg-quick down
# Berguna jika Anda menambah peer secara dinamis via `wg addpeer`
SaveConfig = false

# Aturan firewall: jalankan saat interface VPN aktif
# Mengizinkan traffic dari VPN ke luar dan mendukung NAT (jika dibutuhkan)
PostUp   = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

##############################################
#   Peer: Client 1 (Laptop/Workstation)     #
##############################################

[Peer]
# Nama peer bersifat komentar, tidak mempengaruhi fungsionalitas
# PublicKey adalah kunci publik milik CLIENT (bukan server)
PublicKey = <ISI_DENGAN_CLIENT1_PUBLIC_KEY>

# IP yang diizinkan untuk peer ini ketika traffic masuk melalui tunnel
# Nilai /32 berarti HANYA IP ini yang diizinkan untuk peer tersebut (satu client, satu IP)
AllowedIPs = 10.0.0.2/32

# PersistentKeepalive: kirim paket keepalive setiap N detik
# Berguna jika client berada di belakang NAT/firewall
PersistentKeepalive = 25
```

> ⚠️ **CATATAN:** Ganti `eth0` pada baris `PostUp`/`PostDown` dengan nama antarmuka jaringan publik server Anda. Cek dengan perintah `ip link show` atau `ip route | grep default`.

### 3.2 Penjelasan Detail Setiap Baris Konfigurasi

| Direktif | Seksi | Penjelasan |
|---|---|---|
| `[Interface]` | — | Mendefinisikan konfigurasi antarmuka lokal server WireGuard |
| `Address` | Interface | IP server di dalam jaringan VPN. `/24` mendefinisikan subnet `10.0.0.0/24` |
| `ListenPort` | Interface | Port UDP yang digunakan WireGuard untuk menerima koneksi. Default: `51820` |
| `PrivateKey` | Interface | Kunci privat server untuk enkripsi/dekripsi tunnel |
| `SaveConfig` | Interface | Jika `true`, WireGuard menyimpan perubahan peer runtime ke file conf saat `wg-quick down` |
| `PostUp` | Interface | Perintah shell yang dieksekusi setelah interface VPN aktif (biasanya aturan iptables) |
| `PostDown` | Interface | Perintah shell yang dieksekusi setelah interface VPN dimatikan (rollback iptables) |
| `[Peer]` | — | Mendefinisikan satu peer (client) yang diizinkan terhubung |
| `PublicKey` | Peer | Kunci publik milik client. Server menggunakan ini untuk memverifikasi identitas client |
| `AllowedIPs` | Peer | Daftar IP yang diizinkan melewati tunnel dari peer ini. `/32` = hanya satu IP spesifik |
| `PersistentKeepalive` | Peer | Interval (detik) pengiriman paket keepalive untuk menjaga koneksi NAT tetap aktif |

### 3.3 Set Izin File Konfigurasi

```bash
sudo chmod 600 /etc/wireguard/wg0.conf
```

### 3.4 Aktifkan & Jalankan WireGuard Server

```bash
# Aktifkan dan jalankan sekaligus, plus set otomatis start saat boot
sudo systemctl enable --now wg-quick@wg0
```

Cek status service:

```bash
sudo systemctl status wg-quick@wg0
```

Output yang diharapkan:

```
● wg-quick@wg0.service - WireGuard via wg-quick(8) for wg0
     Loaded: loaded (/lib/systemd/system/wg-quick@.service; enabled; ...)
     Active: active (exited) since ...
```

---

## 4. Konfigurasi & Koneksi Client (Linux Debian/Ubuntu)

### 4.1 Install WireGuard di Client

```bash
# Di mesin client (Debian/Ubuntu)
sudo apt update
sudo apt install wireguard wireguard-tools -y
```

### 4.2 File Konfigurasi Client `/etc/wireguard/wg0.conf`

```bash
sudo nano /etc/wireguard/wg0.conf
```

Isi konfigurasi client:

```ini
##############################################
#   WireGuard Client Configuration          #
#   File: /etc/wireguard/wg0.conf           #
##############################################

[Interface]
# IP internal client di dalam jaringan VPN
# Gunakan /32 untuk menandakan ini adalah host tunggal (bukan subnet router)
Address = 10.0.0.2/32

# Private key milik CLIENT ini — RAHASIA
PrivateKey = <ISI_DENGAN_CLIENT1_PRIVATE_KEY>

# DNS opsional — bisa dikosongkan jika tidak diperlukan
# DNS = 1.1.1.1

##############################################
#   Peer: Server WireGuard                  #
##############################################

[Peer]
# Public key milik SERVER
PublicKey = <ISI_DENGAN_SERVER_PUBLIC_KEY>

# IP publik server beserta port WireGuard
Endpoint = YOUR_SERVER_PUBLIC_IP:51820

# Traffic yang diarahkan melalui tunnel
# 10.0.0.0/24 → hanya traffic ke jaringan VPN yang melewati tunnel (DIREKOMENDASIKAN)
# 0.0.0.0/0   → SEMUA traffic diarahkan ke VPN (full tunnel, tidak direkomendasikan untuk kasus ini)
AllowedIPs = 10.0.0.0/24

# Keepalive untuk menjaga koneksi dari balik NAT
PersistentKeepalive = 25
```

Set izin file:

```bash
sudo chmod 600 /etc/wireguard/wg0.conf
```

### 4.3 Koneksi & Pemutusan dari Terminal

**Mengaktifkan koneksi VPN:**

```bash
sudo wg-quick up wg0
```

Output yang diharapkan:

```
[#] ip link add wg0 type wireguard
[#] wg setconf wg0 /dev/fd/63
[#] ip -4 address add 10.0.0.2/32 dev wg0
[#] ip link set mtu 1420 up dev wg0
[#] ip -4 route add 10.0.0.0/24 dev wg0
```

**Memutuskan koneksi VPN:**

```bash
sudo wg-quick down wg0
```

**Aktifkan otomatis saat boot (opsional untuk client):**

```bash
sudo systemctl enable wg-quick@wg0
```

**Uji koneksi:**

```bash
# Ping server VPN dari client setelah tunnel aktif
ping 10.0.0.1

# Jika berhasil, Anda dapat terhubung ke layanan:
ssh user@10.0.0.1
```

---

## 5. Isolasi Layanan (Service Binding)

Langkah ini memastikan layanan sensitif hanya dapat dijangkau melalui antarmuka VPN, bukan melalui IP publik.

### 5.1 SSH — Bind ke IP VPN

Edit file konfigurasi SSH:

```bash
sudo nano /etc/ssh/sshd_config
```

Temukan atau tambahkan baris berikut:

```
# Hanya izinkan koneksi SSH dari antarmuka VPN (10.0.0.1) dan localhost
ListenAddress 127.0.0.1
ListenAddress 10.0.0.1
```

> ⚠️ **PERINGATAN KRITIS:** Sebelum menyimpan dan merestart SSH, pastikan Anda sudah terhubung ke VPN dari client dan dapat melakukan SSH ke `10.0.0.1`. Jika tidak, Anda akan terkunci dari server.

Restart SSH setelah memverifikasi koneksi VPN aktif:

```bash
sudo systemctl restart sshd
sudo systemctl status sshd
```

### 5.2 MySQL — Bind ke IP VPN

Edit file konfigurasi MySQL:

```bash
sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf
```

Ubah baris `bind-address`:

```ini
[mysqld]
# Ganti 127.0.0.1 dengan 10.0.0.1 agar dapat diakses via VPN
bind-address = 10.0.0.1
```

Restart MySQL:

```bash
sudo systemctl restart mysql
```

Verifikasi:

```bash
sudo ss -tlnp | grep mysql
# Output: LISTEN 0  ... 10.0.0.1:3306 ...
```

### 5.3 PostgreSQL — Bind ke IP VPN

Edit file konfigurasi PostgreSQL:

```bash
# Sesuaikan versi PostgreSQL (misal: 15)
sudo nano /etc/postgresql/15/main/postgresql.conf
```

Ubah baris `listen_addresses`:

```ini
# Izinkan koneksi dari localhost dan IP VPN
listen_addresses = 'localhost,10.0.0.1'
```

Edit `pg_hba.conf` untuk mengizinkan koneksi dari subnet VPN:

```bash
sudo nano /etc/postgresql/15/main/pg_hba.conf
```

Tambahkan baris berikut:

```
# TYPE  DATABASE  USER  ADDRESS         METHOD
host    all       all   10.0.0.0/24     md5
```

Restart PostgreSQL:

```bash
sudo systemctl restart postgresql
```

### 5.4 Code-Server — Bind ke IP VPN

Edit file konfigurasi Code-Server:

```bash
nano ~/.config/code-server/config.yaml
```

Ubah nilai `bind-addr`:

```yaml
bind-addr: 10.0.0.1:8080
auth: password
password: your-strong-password-here
cert: false
```

Restart Code-Server:

```bash
sudo systemctl restart code-server@$USER
```

---

## 6. Pengasahan Firewall (UFW)

> ⚠️ **PERINGATAN KRITIS SEBELUM MENGAKTIFKAN UFW:**
>
> Jika sesi SSH Anda saat ini terhubung melalui **IP publik server**, pastikan Anda **TIDAK MENUTUP** port SSH dari publik sebelum Anda memverifikasi koneksi SSH via VPN berfungsi. Urutan yang aman:
> 1. Aktifkan WireGuard di server ✓
> 2. Aktifkan WireGuard di client ✓
> 3. Verifikasi `ping 10.0.0.1` berhasil ✓
> 4. Verifikasi `ssh user@10.0.0.1` berhasil dari terminal baru ✓
> 5. Baru terapkan aturan UFW di bawah ini ✓
>
> Jika Anda terkunci, Anda memerlukan akses konsol fisik atau VNC/KVM dari provider VPS.

### 6.1 Install UFW

```bash
sudo apt install ufw -y
```

### 6.2 Set Kebijakan Default

```bash
# Tolak semua koneksi masuk secara default
sudo ufw default deny incoming

# Izinkan semua koneksi keluar secara default
sudo ufw default allow outgoing
```

### 6.3 Buka Port WireGuard (WAJIB dilakukan pertama)

```bash
# Buka port WireGuard UDP dari mana saja (pintu masuk VPN)
sudo ufw allow 51820/udp comment "WireGuard VPN"
```

### 6.4 Buka Port HTTPS (Jika Ada Web Server)

```bash
# Port 443 untuk HTTPS dari publik
sudo ufw allow 443/tcp comment "HTTPS Public"

# Port 80 untuk HTTP (opsional, biasanya untuk redirect ke HTTPS)
sudo ufw allow 80/tcp comment "HTTP Public"
```

### 6.5 Izinkan SSH HANYA dari Subnet VPN

```bash
# HANYA izinkan SSH dari jaringan internal VPN
sudo ufw allow from 10.0.0.0/24 to any port 22 proto tcp comment "SSH via WireGuard VPN only"
```

### 6.6 Izinkan Database HANYA dari Subnet VPN

```bash
# MySQL: hanya dari VPN
sudo ufw allow from 10.0.0.0/24 to any port 3306 proto tcp comment "MySQL via WireGuard VPN only"

# PostgreSQL: hanya dari VPN
sudo ufw allow from 10.0.0.0/24 to any port 5432 proto tcp comment "PostgreSQL via WireGuard VPN only"
```

### 6.7 Izinkan Code-Server HANYA dari Subnet VPN

```bash
# Code-Server: hanya dari VPN
sudo ufw allow from 10.0.0.0/24 to any port 8080 proto tcp comment "Code-Server via WireGuard VPN only"
```

### 6.8 Aktifkan UFW

```bash
sudo ufw enable
```

Konfirmasi dengan mengetik `y` saat diminta.

### 6.9 Verifikasi Aturan UFW

```bash
sudo ufw status verbose
```

Output yang diharapkan:

```
Status: active

To                         Action      From
--                         ------      ----
51820/udp                  ALLOW IN    Anywhere                   # WireGuard VPN
443/tcp                    ALLOW IN    Anywhere                   # HTTPS Public
80/tcp                     ALLOW IN    Anywhere                   # HTTP Public
22/tcp                     ALLOW IN    10.0.0.0/24               # SSH via WireGuard VPN only
3306/tcp                   ALLOW IN    10.0.0.0/24               # MySQL via WireGuard VPN only
5432/tcp                   ALLOW IN    10.0.0.0/24               # PostgreSQL via WireGuard VPN only
8080/tcp                   ALLOW IN    10.0.0.0/24               # Code-Server via WireGuard VPN only
```

---

## 7. Verifikasi & Pemantauan

### 7.1 Cek Status WireGuard (dari Server)

```bash
sudo wg show
```

Output contoh saat client terhubung:

```
interface: wg0
  public key: <SERVER_PUBLIC_KEY>
  private key: (hidden)
  listening port: 51820

peer: <CLIENT1_PUBLIC_KEY>
  endpoint: CLIENT_PUBLIC_IP:PORT
  allowed ips: 10.0.0.2/32
  latest handshake: 5 seconds ago
  transfer: 1.23 MiB received, 456 KiB sent
  persistent keepalive: every 25 seconds
```

Penjelasan kolom penting:
- **latest handshake**: Waktu terakhir client melakukan handshake. Jika lebih dari 3 menit, koneksi mungkin bermasalah.
- **transfer**: Data yang sudah ditransfer. Angka bergerak berarti tunnel aktif dan data mengalir.
- **endpoint**: IP publik dan port efemeral client saat ini.

### 7.2 Perintah Verifikasi Lanjutan

```bash
# Cek antarmuka VPN aktif
ip link show wg0

# Cek IP yang di-assign ke antarmuka VPN
ip addr show wg0

# Cek routing table (memastikan 10.0.0.0/24 lewat wg0)
ip route show | grep wg0

# Cek port yang sedang didengarkan (verifikasi service binding)
sudo ss -tlnp | grep -E "22|3306|5432|8080"
```

Output `ss -tlnp` yang AMAN (layanan terisolasi ke VPN):

```
LISTEN  0  128  10.0.0.1:22     0.0.0.0:*   users:(("sshd",pid=...))
LISTEN  0  128  10.0.0.1:3306   0.0.0.0:*   users:(("mysqld",pid=...))
LISTEN  0  128  10.0.0.1:5432   0.0.0.0:*   users:(("postgres",pid=...))
LISTEN  0  128  10.0.0.1:8080   0.0.0.0:*   users:(("node",pid=...))
```

> ⚠️ **TANDA BAHAYA:** Jika Anda melihat `0.0.0.0:22` atau `*:22` (bukan `10.0.0.1:22`), artinya SSH masih terbuka ke publik dan konfigurasi `sshd_config` belum berhasil diterapkan.

### 7.3 Test Keamanan dari Luar VPN

Dari komputer lain yang TIDAK terhubung ke VPN, coba:

```bash
# Harusnya GAGAL (Connection refused / timeout)
ssh user@YOUR_SERVER_PUBLIC_IP
nc -zv YOUR_SERVER_PUBLIC_IP 3306
nc -zv YOUR_SERVER_PUBLIC_IP 5432
nc -zv YOUR_SERVER_PUBLIC_IP 8080

# Harusnya BERHASIL
curl https://YOUR_SERVER_PUBLIC_IP    # (jika ada web server)
```

---

## 8. Troubleshooting

### Client tidak bisa ping server VPN

```bash
# Cek apakah WireGuard aktif di server
sudo systemctl status wg-quick@wg0

# Cek log sistem
sudo journalctl -u wg-quick@wg0 -f

# Pastikan port 51820 UDP terbuka di firewall server
sudo ufw status | grep 51820

# Cek apakah public key client sudah benar di konfigurasi server
sudo wg show
```

### SSH tetap bisa diakses dari publik

```bash
# Cek konfigurasi sshd
sudo grep -n "ListenAddress" /etc/ssh/sshd_config

# Cek port yang aktif
sudo ss -tlnp | grep :22

# Reload konfigurasi SSH tanpa restart (lebih aman)
sudo systemctl reload sshd
```

### WireGuard gagal start setelah reboot

```bash
# Cek apakah service enabled
sudo systemctl is-enabled wg-quick@wg0

# Lihat log error
sudo journalctl -u wg-quick@wg0 --boot -0

# Validasi sintaks konfigurasi
sudo wg-quick strip wg0
```

### Menambah Client Baru

```bash
# 1. Generate keypair untuk client baru di server
wg genkey | sudo tee /etc/wireguard/client2_private.key | wg pubkey | sudo tee /etc/wireguard/client2_public.key

# 2. Tambah peer baru di /etc/wireguard/wg0.conf server
[Peer]
PublicKey = <CLIENT2_PUBLIC_KEY>
AllowedIPs = 10.0.0.3/32   # IP unik untuk client ke-2
PersistentKeepalive = 25

# 3. Reload konfigurasi WireGuard tanpa memutus koneksi yang ada
sudo wg syncconf wg0 <(sudo wg-quick strip wg0)
```

---

## Referensi Cepat — Perintah Penting

| Tujuan | Perintah |
|---|---|
| Start VPN (server/client) | `sudo wg-quick up wg0` |
| Stop VPN | `sudo wg-quick down wg0` |
| Cek status VPN | `sudo wg show` |
| Restart VPN service | `sudo systemctl restart wg-quick@wg0` |
| Lihat log VPN | `sudo journalctl -u wg-quick@wg0 -f` |
| Cek aturan UFW | `sudo ufw status verbose` |
| Cek port terbuka | `sudo ss -tlnp` |
| Reload sshd config | `sudo systemctl reload sshd` |

---

*Panduan ini dibuat untuk Debian 12 (Bookworm) dengan WireGuard versi terbaru via apt. Selalu backup file konfigurasi sebelum melakukan perubahan pada sistem produksi.*
