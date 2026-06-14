# Panduan Teknis: Konfigurasi OpenVPN Server di Debian 12 (Bookworm)
### Isolasi Layanan Sensitif dari Internet Publik

---

> **Tujuan Arsitektur:** Mengisolasi seluruh layanan sensitif (SSH, Code-Server, Database) agar **hanya dapat diakses** melalui tunnel OpenVPN. Internet publik hanya dapat menjangkau port HTTPS (443) dan port OpenVPN (1194/UDP).

---

## Daftar Isi

1. [Instalasi OpenVPN & Easy-RSA](#1-instalasi-openvpn--easy-rsa)
2. [Pembangunan PKI (Public Key Infrastructure)](#2-pembangunan-pki-public-key-infrastructure)
3. [Konfigurasi OpenVPN Server](#3-konfigurasi-openvpn-server)
4. [Pembuatan File `.ovpn` & Koneksi Client](#4-pembuatan-file-ovpn--koneksi-client)
5. [Isolasi Layanan (Service Binding)](#5-isolasi-layanan-service-binding)
6. [Pengerasan Firewall dengan UFW](#6-pengerasan-firewall-dengan-ufw)
7. [Verifikasi & Troubleshooting](#7-verifikasi--troubleshooting)

---

## 1. Instalasi OpenVPN & Easy-RSA

### 1.1 Update Sistem & Instalasi Paket

Masuk sebagai `root` atau gunakan `sudo`. Pastikan sistem dalam kondisi terkini sebelum instalasi.

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y openvpn easy-rsa
```

### 1.2 Verifikasi Instalasi

```bash
openvpn --version
ls /usr/share/easy-rsa/
```

Output `ls` seharusnya menampilkan direktori yang berisi skrip Easy-RSA seperti `easyrsa`, `openssl-easyrsa.cnf`, dan lainnya.

---

## 2. Pembangunan PKI (Public Key Infrastructure)

PKI digunakan untuk menerbitkan sertifikat yang digunakan server dan client untuk saling autentikasi. Seluruh proses dilakukan di server.

### 2.1 Inisialisasi Direktori Easy-RSA

```bash
# Buat salinan direktori Easy-RSA di lokasi kerja yang aman
sudo make-cadir /etc/openvpn/easy-rsa
cd /etc/openvpn/easy-rsa
```

### 2.2 Konfigurasi Variabel Easy-RSA

Edit file `vars` untuk menyesuaikan identitas CA Anda:

```bash
sudo nano /etc/openvpn/easy-rsa/vars
```

Tambahkan atau sesuaikan baris berikut di bagian bawah file:

```bash
set_var EASYRSA_REQ_COUNTRY    "ID"
set_var EASYRSA_REQ_PROVINCE   "Jawa Barat"
set_var EASYRSA_REQ_CITY       "Jakarta"
set_var EASYRSA_REQ_ORG        "Organisasi Anda"
set_var EASYRSA_REQ_EMAIL      "admin@domain.anda"
set_var EASYRSA_REQ_OU         "IT Security"
set_var EASYRSA_ALGO           "ec"
set_var EASYRSA_DIGEST         "sha512"
set_var EASYRSA_CA_EXPIRE      3650
set_var EASYRSA_CERT_EXPIRE    825
```

> **Catatan:** Menggunakan algoritma `ec` (Elliptic Curve) lebih disarankan daripada RSA karena memberikan keamanan yang lebih tinggi dengan ukuran kunci yang lebih kecil.

### 2.3 Inisialisasi PKI

```bash
cd /etc/openvpn/easy-rsa
sudo ./easyrsa init-pki
```

Output yang diharapkan:
```
init-pki complete; you may now create a CA or requests.
Your newly created PKI dir is: /etc/openvpn/easy-rsa/pki
```

### 2.4 Membuat Certificate Authority (CA)

```bash
sudo ./easyrsa build-ca nopass
```

Anda akan diminta mengisi **Common Name** untuk CA. Masukkan nama deskriptif, misalnya `VPN-CA-Server`:

```
Common Name (eg: your user, host, or server name) [Easy-RSA CA]: VPN-CA-Server
```

File CA yang dihasilkan:
- **Sertifikat CA (publik):** `/etc/openvpn/easy-rsa/pki/ca.crt`
- **Private Key CA (RAHASIA):** `/etc/openvpn/easy-rsa/pki/private/ca.key`

> ⚠️ **PERINGATAN KEAMANAN:** File `ca.key` adalah kunci master PKI Anda. **Jangan pernah** membagikan atau mengekspos file ini. Simpan salinan cadangan di media offline yang aman.

### 2.5 Membuat Sertifikat & Private Key Server

```bash
sudo ./easyrsa gen-req server nopass
sudo ./easyrsa sign-req server server
```

Pada langkah `sign-req`, Anda akan diminta konfirmasi:
```
Confirm request details: yes
```

File yang dihasilkan:
- **Sertifikat Server:** `/etc/openvpn/easy-rsa/pki/issued/server.crt`
- **Private Key Server:** `/etc/openvpn/easy-rsa/pki/private/server.key`

### 2.6 Membuat Sertifikat & Private Key Client

Ganti `client1` dengan nama identifier client yang diinginkan (misalnya nama pengguna atau hostname):

```bash
sudo ./easyrsa gen-req client1 nopass
sudo ./easyrsa sign-req client client1
```

File yang dihasilkan:
- **Sertifikat Client:** `/etc/openvpn/easy-rsa/pki/issued/client1.crt`
- **Private Key Client:** `/etc/openvpn/easy-rsa/pki/private/client1.key`

### 2.7 Generate Parameter Diffie-Hellman (DH)

> **Catatan:** Langkah ini hanya diperlukan jika Anda menggunakan algoritma RSA. Jika menggunakan `ec` (seperti konfigurasi di atas), lewati langkah ini karena DH tidak digunakan dengan Elliptic Curve.

Jika Anda memilih RSA, jalankan:

```bash
sudo ./easyrsa gen-dh
```

Proses ini membutuhkan waktu beberapa menit tergantung kapasitas CPU server.

### 2.8 Generate TLS Authentication Key (tls-crypt)

`tls-crypt` menambahkan lapisan autentikasi tambahan sebelum handshake TLS, mencegah serangan DoS dan port scanning terhadap server OpenVPN:

```bash
sudo openvpn --genkey secret /etc/openvpn/easy-rsa/pki/ta.key
```

### 2.9 Salin File ke Direktori OpenVPN

```bash
# Salin sertifikat dan kunci ke direktori konfigurasi OpenVPN
sudo cp /etc/openvpn/easy-rsa/pki/ca.crt /etc/openvpn/server/
sudo cp /etc/openvpn/easy-rsa/pki/issued/server.crt /etc/openvpn/server/
sudo cp /etc/openvpn/easy-rsa/pki/private/server.key /etc/openvpn/server/
sudo cp /etc/openvpn/easy-rsa/pki/ta.key /etc/openvpn/server/

# Jika menggunakan RSA, salin juga file DH:
# sudo cp /etc/openvpn/easy-rsa/pki/dh.pem /etc/openvpn/server/

# Atur permission yang ketat pada file kunci privat
sudo chmod 600 /etc/openvpn/server/server.key
sudo chmod 600 /etc/openvpn/server/ta.key
```

---

## 3. Konfigurasi OpenVPN Server

### 3.1 Membuat File Konfigurasi Server

Buat file konfigurasi utama server:

```bash
sudo nano /etc/openvpn/server/server.conf
```

Salin seluruh konfigurasi berikut:

```conf
# =============================================================
# Konfigurasi OpenVPN Server - Debian 12 (Bookworm)
# =============================================================

# --- Interface & Protokol ---
# Gunakan TUN device (layer 3, routing mode)
dev tun

# Protokol UDP lebih efisien untuk VPN (lebih cepat dari TCP)
proto udp

# Port listener OpenVPN
port 1194

# --- Sertifikat & Kunci ---
# Lokasi Certificate Authority
ca /etc/openvpn/server/ca.crt

# Sertifikat server (identitas publik server)
cert /etc/openvpn/server/server.crt

# Private key server (RAHASIA - jaga keamanannya)
key /etc/openvpn/server/server.key

# TLS Authentication key untuk mencegah serangan DoS/scan
tls-crypt /etc/openvpn/server/ta.key

# Cipher untuk enkripsi data channel
cipher AES-256-GCM

# Autentikasi HMAC tambahan
auth SHA256

# TLS versi minimum
tls-version-min 1.2

# Batasi cipher TLS yang diperbolehkan (keamanan lebih ketat)
tls-cipher TLS-ECDHE-ECDSA-WITH-AES-256-GCM-SHA384

# --- Topologi & Subnet IP ---
# Gunakan mode subnet (lebih modern dari net30)
topology subnet

# Subnet IP internal VPN: server mendapat 10.8.0.1, client 10.8.0.2 dst.
server 10.8.0.0 255.255.255.0

# Simpan pemetaan IP client agar IP tidak berubah saat reconnect
ifconfig-pool-persist /var/log/openvpn/ipp.txt

# --- Routing ---
# JANGAN push default gateway ke client (lalu lintas internet client
# tetap melewati koneksi lokal mereka, bukan melalui server VPN).
# Hapus tanda '#' pada baris di bawah jika ingin semua trafik
# client melewati server (full-tunnel mode - opsional).
# push "redirect-gateway def1 bypass-dhcp"

# Push DNS server ke client (opsional, gunakan DNS publik atau milik Anda)
push "dhcp-option DNS 1.1.1.1"
push "dhcp-option DNS 8.8.8.8"

# --- Keepalive & Timeout ---
# Ping setiap 10 detik, anggap koneksi terputus setelah 120 detik
keepalive 10 120

# --- Performa ---
# Kompresi (dinonaktifkan karena rentan terhadap serangan VORACLE)
compress

# Izinkan banyak client terhubung sekaligus
duplicate-cn

# Jumlah maksimal client bersamaan
max-clients 10

# --- Keamanan Sistem ---
# Jalankan proses OpenVPN sebagai user/group tanpa hak istimewa
user nobody
group nogroup

# Pertahankan state kunci dan tunnel saat proses restart/reload
persist-key
persist-tun

# --- Logging ---
# Lokasi status koneksi aktif
status /var/log/openvpn/openvpn-status.log

# Lokasi file log utama
log-append /var/log/openvpn/openvpn.log

# Level verbositas log (0=silent, 9=sangat detail; 3 direkomendasikan untuk produksi)
verb 3

# Notifikasi singkat untuk client yang reconnect
mute 20

# Eksplisit nyatakan mode server
mode server
tls-server

# Notifikasi ke client saat server restart
explicit-exit-notify 1
```

### 3.2 Membuat Direktori Log

```bash
sudo mkdir -p /var/log/openvpn
sudo chown nobody:nogroup /var/log/openvpn
```

### 3.3 Mengaktifkan IP Forwarding

IP Forwarding memungkinkan kernel Linux meneruskan paket antar-interface jaringan (diperlukan untuk routing VPN):

```bash
# Aktifkan sementara (langsung berlaku, hilang setelah reboot)
sudo sysctl -w net.ipv4.ip_forward=1

# Aktifkan permanen (persisten setelah reboot)
sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sudo sysctl -p
```

Verifikasi:
```bash
cat /proc/sys/net/ipv4/ip_forward
# Output harus: 1
```

### 3.4 Menjalankan & Mengaktifkan Service OpenVPN

```bash
# Aktifkan dan jalankan service OpenVPN server
sudo systemctl enable --now openvpn-server@server

# Cek status service
sudo systemctl status openvpn-server@server
```

Output yang diharapkan menampilkan status `Active: active (running)`.

**Jika terjadi error, periksa log:**
```bash
sudo journalctl -u openvpn-server@server -n 50 --no-pager
sudo tail -f /var/log/openvpn/openvpn.log
```

### 3.5 Verifikasi Interface TUN

Setelah service berjalan, interface `tun0` harus muncul:

```bash
ip addr show tun0
```

Output yang diharapkan:
```
3: tun0: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1500 ...
    inet 10.8.0.1/24 brd 10.8.0.255 scope global tun0
```

---

## 4. Pembuatan File `.ovpn` & Koneksi Client

### 4.1 Konsep File `.ovpn` Terpadu

File `.ovpn` yang baik menggabungkan seluruh sertifikat dan kunci ke dalam **satu file tunggal**, sehingga mudah didistribusikan ke client tanpa perlu menyalin banyak file terpisah.

### 4.2 Salin File yang Dibutuhkan ke Direktori Sementara

Lakukan di server sebagai persiapan sebelum membuat file `.ovpn`:

```bash
# Buat direktori output sementara
sudo mkdir -p /tmp/client-configs/keys

# Salin file-file yang diperlukan
sudo cp /etc/openvpn/server/ca.crt /tmp/client-configs/keys/
sudo cp /etc/openvpn/server/ta.key /tmp/client-configs/keys/
sudo cp /etc/openvpn/easy-rsa/pki/issued/client1.crt /tmp/client-configs/keys/
sudo cp /etc/openvpn/easy-rsa/pki/private/client1.key /tmp/client-configs/keys/

sudo chmod 700 /tmp/client-configs/keys
```

### 4.3 Script Otomatis Pembuatan File `.ovpn`

Buat script berikut untuk mengotomatisasi pembuatan file `.ovpn`:

```bash
sudo nano /tmp/make_client_config.sh
```

Isi script:

```bash
#!/bin/bash
# ============================================================
# Script Pembuat File .ovpn Client
# Penggunaan: sudo ./make_client_config.sh <nama_client> <IP_publik_server>
# Contoh:    sudo ./make_client_config.sh client1 203.0.113.10
# ============================================================

CLIENT=$1
SERVER_IP=$2
KEY_DIR=/tmp/client-configs/keys
OUTPUT_DIR=/tmp/client-configs
CA="${KEY_DIR}/ca.crt"
CERT="${KEY_DIR}/${CLIENT}.crt"
KEY="${KEY_DIR}/${CLIENT}.key"
TA="${KEY_DIR}/ta.key"

# Validasi argumen
if [[ -z "$CLIENT" || -z "$SERVER_IP" ]]; then
    echo "ERROR: Argumen kurang."
    echo "Penggunaan: $0 <nama_client> <IP_publik_server>"
    exit 1
fi

# Validasi file
for f in "$CA" "$CERT" "$KEY" "$TA"; do
    if [[ ! -f "$f" ]]; then
        echo "ERROR: File tidak ditemukan: $f"
        exit 1
    fi
done

OUTPUT="${OUTPUT_DIR}/${CLIENT}.ovpn"

cat > "$OUTPUT" <<EOF
# =============================================================
# Konfigurasi OpenVPN Client - ${CLIENT}
# =============================================================
client
dev tun
proto udp
remote ${SERVER_IP} 1194

# Verifikasi sertifikat server
remote-cert-tls server

# Pertahankan status saat ping timeout
resolv-retry infinite
nobind
persist-key
persist-tun

# Cipher dan autentikasi (HARUS sama dengan server)
cipher AES-256-GCM
auth SHA256
tls-version-min 1.2
tls-cipher TLS-ECDHE-ECDSA-WITH-AES-256-GCM-SHA384

# Kompresi (sesuaikan dengan server)
compress

# Level log
verb 3

# Redirect: hanya gunakan VPN untuk subnet server, bukan semua trafik
# (split-tunnel mode - sesuai tujuan arsitektur ini)
route-nopull
route 10.8.0.0 255.255.255.0

<ca>
$(cat ${CA})
</ca>

<cert>
$(sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' ${CERT})
</cert>

<key>
$(cat ${KEY})
</key>

<tls-crypt>
$(cat ${TA})
</tls-crypt>
EOF

chmod 600 "$OUTPUT"
echo "✅ File .ovpn berhasil dibuat: ${OUTPUT}"
```

Jalankan script:

```bash
sudo chmod +x /tmp/make_client_config.sh
# Ganti 203.0.113.10 dengan IP publik server Anda yang sebenarnya
sudo /tmp/make_client_config.sh client1 203.0.113.10
```

File `.ovpn` akan tersedia di `/tmp/client-configs/client1.ovpn`.

### 4.4 Transfer File `.ovpn` ke Client

Gunakan `scp` untuk mentransfer file secara aman dari server ke mesin client:

```bash
# Jalankan di mesin CLIENT (bukan server)
scp user@<IP_PUBLIK_SERVER>:/tmp/client-configs/client1.ovpn ~/client1.ovpn
```

Setelah ditransfer, hapus file dari server untuk keamanan:

```bash
# Jalankan di SERVER
sudo rm -rf /tmp/client-configs/
```

### 4.5 Instalasi OpenVPN di Client Linux (Debian/Ubuntu)

Jalankan di mesin **client**:

```bash
sudo apt update
sudo apt install -y openvpn
```

### 4.6 Melakukan Koneksi dari Client via Terminal

```bash
# Koneksi menggunakan file .ovpn
sudo openvpn --config ~/client1.ovpn
```

Biarkan terminal ini berjalan. Buka terminal baru untuk bekerja.

**Verifikasi koneksi berhasil:**

```bash
# Di terminal baru, cek apakah IP VPN sudah didapat
ip addr show tun0

# Ping ke IP internal server VPN
ping 10.8.0.1

# Coba akses SSH melalui VPN (gunakan IP internal, bukan IP publik)
ssh user@10.8.0.1
```

---

## 5. Isolasi Layanan (Service Binding)

Langkah ini memastikan layanan sensitif **hanya mendengarkan** pada interface loopback atau interface VPN, bukan pada interface publik.

### 5.1 SSH Server

Edit konfigurasi SSH:

```bash
sudo nano /etc/ssh/sshd_config
```

Cari dan ubah baris `ListenAddress`:

```conf
# Dengarkan HANYA pada interface loopback dan IP VPN internal
# HAPUS atau komentari baris: #ListenAddress 0.0.0.0
ListenAddress 127.0.0.1
ListenAddress 10.8.0.1
```

Restart SSH:

```bash
sudo systemctl restart sshd
sudo systemctl status sshd
```

> ⚠️ **PERINGATAN KRITIS:** Sebelum me-restart SSH, pastikan Anda sudah terhubung ke VPN dan **buka sesi SSH cadangan** melalui IP VPN (`ssh user@10.8.0.1`) di terminal terpisah. Jika konfigurasi salah, Anda masih bisa mengakses server melalui konsol langsung atau panel kontrol VPS.

### 5.2 MySQL

Edit file konfigurasi MySQL:

```bash
sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf
```

Ubah `bind-address`:

```conf
[mysqld]
# Hanya dengarkan pada IP VPN internal
# bind-address = 127.0.0.1      <- nonaktifkan jika ada
bind-address = 10.8.0.1
```

Restart MySQL:

```bash
sudo systemctl restart mysql
sudo systemctl status mysql
```

Verifikasi:

```bash
sudo ss -tlnp | grep 3306
# Output harus menampilkan: 10.8.0.1:3306
```

### 5.3 PostgreSQL

Edit file konfigurasi PostgreSQL (sesuaikan versi, misalnya `14` atau `15`):

```bash
sudo nano /etc/postgresql/*/main/postgresql.conf
```

Ubah `listen_addresses`:

```conf
# Dengarkan HANYA pada IP VPN internal
listen_addresses = '10.8.0.1'
```

Edit juga `pg_hba.conf` untuk membatasi koneksi:

```bash
sudo nano /etc/postgresql/*/main/pg_hba.conf
```

Tambahkan atau pastikan ada baris berikut (izinkan koneksi dari subnet VPN):

```conf
# TYPE  DATABASE  USER  ADDRESS          METHOD
host    all       all   10.8.0.0/24      md5
```

Restart PostgreSQL:

```bash
sudo systemctl restart postgresql
sudo systemctl status postgresql
```

### 5.4 Code-Server (VS Code di Browser)

Edit file service atau konfigurasi Code-Server:

```bash
# Jika menggunakan file konfigurasi (~/.config/code-server/config.yaml)
nano ~/.config/code-server/config.yaml
```

Ubah `bind-addr`:

```yaml
bind-addr: 10.8.0.1:8080
auth: password
password: password-anda-yang-kuat
cert: false
```

Jika dijalankan sebagai systemd service:

```bash
sudo nano /etc/systemd/system/code-server.service
```

Pastikan `ExecStart` menggunakan `--bind-addr`:

```ini
[Service]
ExecStart=/usr/bin/code-server --bind-addr 10.8.0.1:8080
```

Reload dan restart:

```bash
sudo systemctl daemon-reload
sudo systemctl restart code-server
```

Verifikasi semua binding:

```bash
sudo ss -tlnp | grep -E '22|3306|5432|8080'
# Semua port sensitif harus menampilkan 10.8.0.1 atau 127.0.0.1, BUKAN 0.0.0.0
```

---

## 6. Pengerasan Firewall dengan UFW

> ⚠️ **PERINGATAN SEBELUM MEMULAI BAGIAN INI:**
>
> **Risiko Kehilangan Akses SSH.** Jika Anda saat ini terhubung ke server melalui SSH via IP publik, konfigurasi UFW yang salah urutan atau salah aturan dapat **memutus koneksi Anda secara permanen** hingga reboot atau intervensi konsol.
>
> **Lakukan langkah-langkah ini secara berurutan persis seperti yang tertulis.**
> Idealnya, lakukan dari konsol langsung server (bukan melalui SSH remote) atau pastikan Anda sudah menyiapkan sesi cadangan melalui panel VPS.

### 6.1 Instalasi UFW

```bash
sudo apt install -y ufw
```

### 6.2 Atur Kebijakan Default (SEBELUM mengaktifkan UFW)

```bash
# Tolak semua koneksi masuk secara default
sudo ufw default deny incoming

# Izinkan semua koneksi keluar secara default
sudo ufw default allow outgoing
```

### 6.3 Atur Aturan Firewall (URUTAN PENTING)

**Langkah 1 - Izinkan port kritis DULU sebelum mengaktifkan UFW:**

```bash
# Izinkan HTTPS untuk publik
sudo ufw allow 443/tcp comment 'HTTPS Publik'

# Izinkan port OpenVPN untuk publik (WAJIB agar client bisa konek)
sudo ufw allow 1194/udp comment 'OpenVPN Server'
```

**Langkah 2 - Izinkan akses layanan sensitif HANYA dari subnet VPN:**

```bash
# Izinkan SSH hanya dari subnet VPN
sudo ufw allow from 10.8.0.0/24 to any port 22 proto tcp comment 'SSH via VPN Only'

# Izinkan MySQL hanya dari subnet VPN
sudo ufw allow from 10.8.0.0/24 to any port 3306 proto tcp comment 'MySQL via VPN Only'

# Izinkan PostgreSQL hanya dari subnet VPN
sudo ufw allow from 10.8.0.0/24 to any port 5432 proto tcp comment 'PostgreSQL via VPN Only'

# Izinkan Code-Server hanya dari subnet VPN
sudo ufw allow from 10.8.0.0/24 to any port 8080 proto tcp comment 'Code-Server via VPN Only'
```

**Langkah 3 - Blokir eksplisit akses publik ke port sensitif:**

Meskipun kebijakan `default deny incoming` sudah memblokir semua port yang tidak diizinkan, tambahkan aturan `DENY` eksplisit sebagai lapisan pertahanan kedua:

```bash
# Blokir akses publik ke SSH dari internet (0.0.0.0/0)
sudo ufw deny from any to any port 22 proto tcp comment 'Block SSH from Public'

# Blokir akses publik ke MySQL dari internet
sudo ufw deny from any to any port 3306 proto tcp comment 'Block MySQL from Public'

# Blokir akses publik ke PostgreSQL dari internet
sudo ufw deny from any to any port 5432 proto tcp comment 'Block PostgreSQL from Public'

# Blokir akses publik ke Code-Server dari internet
sudo ufw deny from any to any port 8080 proto tcp comment 'Block Code-Server from Public'
```

> **Catatan Teknis:** UFW memproses aturan secara berurutan (first-match). Aturan `ALLOW from 10.8.0.0/24` yang ditambahkan **sebelum** aturan `DENY from any` akan diproses lebih dulu, sehingga client VPN tetap dapat terhubung sementara internet publik diblokir.

### 6.4 Konfigurasi UFW untuk Traffic VPN (Masquerading)

Aktifkan NAT masquerading agar traffic VPN dapat diteruskan dengan benar. Temukan nama interface jaringan publik Anda terlebih dahulu:

```bash
ip route get 8.8.8.8 | awk '{print $5; exit}'
# Catat nama interface (biasanya: eth0, ens3, ens18, atau sejenisnya)
```

Edit file konfigurasi UFW before rules:

```bash
sudo nano /etc/ufw/before.rules
```

Tambahkan blok berikut di **PALING ATAS** file, **sebelum** baris `*filter`:

```
# NAT rules for OpenVPN
*nat
:POSTROUTING ACCEPT [0:0]
# Ganti 'eth0' dengan nama interface publik server Anda
-A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE
COMMIT
```

Aktifkan juga IP forwarding di UFW:

```bash
sudo nano /etc/ufw/sysctl.conf
```

Pastikan baris berikut tidak dikomentari:

```conf
net/ipv4/ip_forward=1
```

### 6.5 Aktifkan UFW

> ⚠️ **MOMEN KRITIS:** Pastikan Anda sudah menambahkan **semua aturan ALLOW** di langkah sebelumnya sebelum menjalankan perintah ini. Setelah UFW aktif, koneksi yang tidak diizinkan akan langsung ditolak.

```bash
sudo ufw enable
```

Konfirmasi dengan mengetik `y` dan tekan Enter.

### 6.6 Verifikasi Aturan Firewall

```bash
# Tampilkan semua aturan dengan nomor urut
sudo ufw status numbered
```

Output yang diharapkan (kurang lebih):

```
Status: active

     To                         Action      From
     --                         ------      ----
[ 1] 443/tcp                    ALLOW IN    Anywhere
[ 2] 1194/udp                   ALLOW IN    Anywhere
[ 3] 22/tcp                     ALLOW IN    10.8.0.0/24
[ 4] 3306/tcp                   ALLOW IN    10.8.0.0/24
[ 5] 5432/tcp                   ALLOW IN    10.8.0.0/24
[ 6] 8080/tcp                   ALLOW IN    10.8.0.0/24
[ 7] 22/tcp                     DENY IN     Anywhere
[ 8] 3306/tcp                   DENY IN     Anywhere
[ 9] 5432/tcp                   DENY IN     Anywhere
[10] 8080/tcp                   DENY IN     Anywhere
```

---

## 7. Verifikasi & Troubleshooting

### 7.1 Checklist Verifikasi Akhir

**Di Server:**

```bash
# 1. Cek service OpenVPN berjalan
sudo systemctl is-active openvpn-server@server

# 2. Cek interface tun0 aktif dengan IP 10.8.0.1
ip addr show tun0

# 3. Cek IP Forwarding aktif
cat /proc/sys/net/ipv4/ip_forward

# 4. Cek port yang sedang didengarkan (harus menunjukkan 10.8.0.1, bukan 0.0.0.0 untuk port sensitif)
sudo ss -tlnp

# 5. Cek aturan UFW aktif
sudo ufw status numbered

# 6. Cek log VPN untuk koneksi client
sudo tail -f /var/log/openvpn/openvpn-status.log
```

**Di Client (setelah koneksi VPN aktif):**

```bash
# 1. Cek IP tun0 client (harus mendapat IP di subnet 10.8.0.x)
ip addr show tun0

# 2. Ping ke server VPN
ping -c 4 10.8.0.1

# 3. Coba akses SSH via VPN
ssh user@10.8.0.1

# 4. Coba akses Code-Server via browser (setelah terhubung VPN)
# Buka: http://10.8.0.1:8080

# 5. Pastikan port sensitif TIDAK bisa diakses via IP publik
nmap -p 22,3306,5432,8080 <IP_PUBLIK_SERVER>
# Semua port tersebut harus berstatus: filtered
```

### 7.2 Troubleshooting Umum

**Masalah: Client tidak bisa ping ke 10.8.0.1**
```bash
# Cek apakah tun0 di server aktif
ip link show tun0
# Cek log OpenVPN
sudo journalctl -u openvpn-server@server -f
```

**Masalah: OpenVPN service gagal start**
```bash
# Periksa sintaks konfigurasi
sudo openvpn --config /etc/openvpn/server/server.conf --daemon
sudo journalctl -u openvpn-server@server -n 100
```

**Masalah: Terkunci dari SSH setelah mengaktifkan UFW**
```bash
# Akses melalui konsol VPS provider, lalu:
sudo ufw disable
# Tambahkan kembali aturan yang benar, lalu aktifkan ulang
```

**Masalah: MySQL tidak bisa diakses dari client VPN**
```bash
# Di server, verifikasi MySQL bind-address
sudo grep bind-address /etc/mysql/mysql.conf.d/mysqld.cnf
# Harus: bind-address = 10.8.0.1

# Cek apakah MySQL listen di port yang benar
sudo ss -tlnp | grep 3306
```

**Menambahkan Client Baru:**
```bash
cd /etc/openvpn/easy-rsa
sudo ./easyrsa gen-req client2 nopass
sudo ./easyrsa sign-req client client2
sudo cp pki/issued/client2.crt /tmp/client-configs/keys/
sudo cp pki/private/client2.key /tmp/client-configs/keys/
sudo /tmp/make_client_config.sh client2 <IP_PUBLIK_SERVER>
```

**Mencabut Sertifikat Client (Revoke):**
```bash
cd /etc/openvpn/easy-rsa
sudo ./easyrsa revoke client1
sudo ./easyrsa gen-crl
sudo cp pki/crl.pem /etc/openvpn/server/
# Tambahkan 'crl-verify /etc/openvpn/server/crl.pem' ke server.conf lalu restart
sudo systemctl restart openvpn-server@server
```

---

## Ringkasan Arsitektur Keamanan

```
Internet Publik
      │
      │  Port 443/tcp  ─────────────────────► Layanan HTTPS (Publik)
      │  Port 1194/udp ─────────────────────► OpenVPN Server
      │
      │  Port 22/tcp   ─────── BLOKIR ───────► SSH          ✗
      │  Port 3306/tcp ─────── BLOKIR ───────► MySQL        ✗
      │  Port 5432/tcp ─────── BLOKIR ───────► PostgreSQL   ✗
      │  Port 8080/tcp ─────── BLOKIR ───────► Code-Server  ✗
      │
[Debian 12 Server]
      │
      └── Tunnel VPN (tun0: 10.8.0.0/24)
              │
              ├── 10.8.0.1 (Server VPN)
              │       ├── SSH         ✓ (hanya dari 10.8.0.0/24)
              │       ├── MySQL       ✓ (hanya dari 10.8.0.0/24)
              │       ├── PostgreSQL  ✓ (hanya dari 10.8.0.0/24)
              │       └── Code-Server ✓ (hanya dari 10.8.0.0/24)
              │
              └── 10.8.0.2+ (Client VPN - Anda)
```

---

*Dokumen ini ditulis untuk Debian 12 (Bookworm) dengan OpenVPN 2.6.x dan Easy-RSA 3.x.*
*Selalu uji konfigurasi di lingkungan staging sebelum menerapkan ke produksi.*
