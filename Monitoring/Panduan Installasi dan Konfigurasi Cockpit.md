# Panduan Lengkap Konfigurasi dan Pengerasan Keamanan Cockpit di Debian 12 (Bookworm)

> **Dokumen ini ditujukan untuk Developer & System Administrator** yang ingin memonitor dan mengelola server Linux secara visual melalui Web GUI, namun tetap mengutamakan keamanan tingkat tinggi (hardened security). Seluruh langkah telah diuji pada **Debian 12 (Bookworm)** dan mengikuti standar industri (*best practices*).

---

## Daftar Isi

1. [Pendahuluan & Instalasi Cockpit](#1-pendahuluan--instalasi-cockpit)
2. [Manajemen Login & Otentikasi](#2-manajemen-login--otentikasi-password--ssh-key)
3. [Kustomisasi Konfigurasi Cockpit](#3-kustomisasi-konfigurasi-cockpit)
4. [Skenario Keamanan Jaringan & Firewall (UFW)](#4-skenario-keamanan-jaringan--firewall-ufw)
5. [Manajemen Service via Cockpit](#5-manajemen-service-systemd--supervisor-di-cockpit)
6. [Penanganan Error & Troubleshooting](#6-penanganan-error--troubleshooting-common-errors)

---

## 1. Pendahuluan & Instalasi Cockpit

### Apa itu Cockpit?

**Cockpit** adalah antarmuka administrasi server berbasis web yang dikembangkan oleh Red Hat. Ia memungkinkan administrator untuk memantau performa sistem, mengelola service systemd, mengatur pengguna, serta mengakses terminal langsung dari browser — tanpa harus bergantung sepenuhnya pada CLI.

Cockpit bersifat **stateless** dan **ringan**: ia tidak menjalankan proses latar belakang yang terus-menerus. Sebagai gantinya, ia menggunakan mekanisme **Socket Activation** via `cockpit.socket` (systemd), sehingga proses Cockpit hanya aktif ketika ada koneksi masuk dari browser.

### Arsitektur: Socket Activation

```
Browser (HTTPS:9090)
        │
        ▼
  cockpit.socket  ◄── systemd mendengarkan port 9090
        │
        ▼  (saat ada koneksi)
  cockpit.service ◄── diaktifkan otomatis oleh socket
        │
        ▼
  cockpit-bridge  ◄── berkomunikasi dengan sistem via D-Bus/SSH
```

Keuntungan arsitektur ini:
- **Hemat RAM & CPU** — proses `cockpit.service` hanya berjalan saat sesi aktif.
- **Zero attack surface saat idle** — tidak ada proses yang mendengarkan permintaan jika tidak ada koneksi.
- **Restart otomatis** — jika `cockpit.service` crash, `cockpit.socket` tetap hidup dan siap menerima koneksi berikutnya.

---

### 1.1 Instalasi Cockpit

#### Langkah 1 — Update sistem

```bash
sudo apt update && sudo apt upgrade -y
```

#### Langkah 2 — Install Cockpit dari repositori resmi Debian

```bash
sudo apt install -y cockpit
```

> **Catatan:** Paket `cockpit` di repositori resmi Debian 12 sudah mencakup `cockpit-bridge`, `cockpit-ws` (web server), dan `cockpit-system` (modul sistem dasar). Tidak diperlukan repositori pihak ketiga.

#### Langkah 3 — Aktifkan dan jalankan `cockpit.socket`

```bash
# Aktifkan socket agar otomatis berjalan saat booting
sudo systemctl enable --now cockpit.socket
```

#### Langkah 4 — Verifikasi status socket

```bash
sudo systemctl status cockpit.socket
```

Output yang diharapkan:

```
● cockpit.socket - Cockpit Web Service Socket
     Loaded: loaded (/lib/systemd/system/cockpit.socket; enabled; preset: enabled)
     Active: active (listening) since ...
   Triggers: ● cockpit.service
     Listen: [::]:9090 (Stream)
```

#### Langkah 5 — Verifikasi port aktif

```bash
ss -tlnp | grep 9090
```

Output:

```
LISTEN 0 128 [::]:9090 [::]:* users:(("systemd",pid=1,fd=...))
```

#### Langkah 6 — Akses awal Cockpit

Buka browser dan navigasikan ke:

```
https://<IP_SERVER>:9090
```

> **⚠️ Peringatan SSL Awal:** Browser akan menampilkan peringatan "Not Secure" karena Cockpit menggunakan sertifikat SSL *self-signed* bawaan. Ini **normal** pada tahap ini. Klik "Advanced" → "Proceed" untuk melanjutkan. Solusi permanen dibahas di [Bagian 6 — Troubleshooting](#masalah-3-sertifikat-ssltls-dianggap-not-secure).

---

### 1.2 Instalasi Plugin Tambahan (Opsional namun Direkomendasikan)

```bash
# Plugin untuk manajemen storage (disk, LVM, RAID)
sudo apt install -y cockpit-storaged

# Plugin untuk manajemen kontainer Podman/Docker
sudo apt install -y cockpit-podman

# Plugin untuk manajemen paket (PackageKit)
sudo apt install -y cockpit-packagekit
```

Setelah instalasi plugin, **refresh browser** atau restart session Cockpit untuk melihat menu baru di sidebar.

---

## 2. Manajemen Login & Otentikasi (Password & SSH Key)

### 2.1 Login Menggunakan User Linux & Password

Cockpit **tidak** memiliki database pengguna sendiri. Ia menggunakan **PAM (Pluggable Authentication Modules)** untuk memverifikasi kredensial, artinya username dan password yang digunakan adalah **akun Linux yang sudah ada** di server.

#### Langkah Login Standar

1. Buka `https://<IP_SERVER>:9090` di browser.
2. Masukkan **Username** dan **Password** akun Linux Anda.
3. Jika akun Anda adalah anggota grup `sudo`, Anda akan mendapatkan akses administratif penuh.
4. Klik **Log In**.

> **Catatan Penting (Debian):** Di Debian, user biasa **tidak otomatis** mendapat akses sudo. Lihat [Bagian 6 — Troubleshooting, Masalah 2](#masalah-2-error-login-failed-atau-user-tidak-memiliki-hak-administratif) untuk cara menambahkan user ke grup sudo.

#### Opsi "Reuse my password for privileged tasks"

Saat login, terdapat checkbox **"Reuse my password for privileged tasks"**. Jika dicentang, Cockpit akan menggunakan password yang sama untuk menjalankan perintah `sudo` secara transparan di latar belakang. Ini praktis, namun hanya aktifkan jika Anda yakin koneksi Anda aman.

---

### 2.2 Konfigurasi Login Menggunakan SSH Key (Otentikasi Kriptografi)

Ini adalah metode yang **jauh lebih aman** karena menghilangkan kebutuhan password dan kebal terhadap serangan *brute force*.

#### Cara Kerjanya

Cockpit menggunakan **SSH Key** yang terdaftar di sistem untuk mengotentikasi pengguna ketika Cockpit perlu melakukan eskalasi privilese atau terhubung ke host lain. Secara internal, Cockpit menggunakan `cockpit-ssh` untuk memfasilitasi koneksi ini.

#### Langkah 1 — Generate SSH Key Pair (di mesin klien/lokal Anda)

Jalankan perintah ini di **komputer lokal** (laptop/PC Anda), bukan di server:

```bash
ssh-keygen -t ed25519 -C "cockpit-admin-key" -f ~/.ssh/cockpit_ed25519
```

Perintah ini menghasilkan dua file:
- `~/.ssh/cockpit_ed25519` → **Private Key** (JANGAN pernah dibagikan)
- `~/.ssh/cockpit_ed25519.pub` → **Public Key** (yang akan didaftarkan ke server)

#### Langkah 2 — Salin Public Key ke Server

```bash
ssh-copy-id -i ~/.ssh/cockpit_ed25519.pub username@<IP_SERVER>
```

Atau secara manual, tampilkan isi public key:

```bash
cat ~/.ssh/cockpit_ed25519.pub
```

Lalu di server, tambahkan ke file `authorized_keys` user yang bersangkutan:

```bash
# Di server, sebagai user yang dituju
mkdir -p ~/.ssh
chmod 700 ~/.ssh
nano ~/.ssh/authorized_keys
# Paste isi public key di sini
chmod 600 ~/.ssh/authorized_keys
```

#### Langkah 3 — Verifikasi Login SSH via Key (Tanpa Password)

Dari mesin lokal, uji koneksi:

```bash
ssh -i ~/.ssh/cockpit_ed25519 username@<IP_SERVER>
```

Jika berhasil masuk tanpa diminta password, berarti konfigurasi SSH Key sudah benar.

#### Langkah 4 — Konfigurasi SSH Daemon di Server untuk Keamanan Optimal

Edit file konfigurasi SSH:

```bash
sudo nano /etc/ssh/sshd_config
```

Pastikan atau tambahkan baris-baris berikut:

```ini
# Nonaktifkan login password SSH (gunakan key saja)
PasswordAuthentication no

# Nonaktifkan login root langsung via SSH
PermitRootLogin no

# Aktifkan autentikasi public key
PubkeyAuthentication yes

# Lokasi file authorized_keys
AuthorizedKeysFile .ssh/authorized_keys
```

Restart SSH daemon:

```bash
sudo systemctl restart ssh
```

> **⚠️ PERINGATAN KRITIS:** Sebelum menonaktifkan `PasswordAuthentication`, **PASTIKAN** Anda sudah berhasil login via SSH Key dan telah membuka sesi terminal lain sebagai backup. Jika Anda terkunci keluar, Anda harus mengakses server melalui konsol fisik atau VNC dari panel kontrol VPS Anda.

#### Langkah 5 — Menggunakan SSH Key di Cockpit Web UI

Saat membuka Cockpit di browser:

1. Masukkan username.
2. Di field password, **biarkan kosong**.
3. Cockpit akan secara otomatis mendeteksi SSH Key yang terdaftar di `~/.ssh/authorized_keys` untuk user tersebut.

Alternatif, Cockpit juga dapat menggunakan **SSH Agent** dari mesin lokal jika Anda mengakses Cockpit melalui tunnel SSH:

```bash
# Di mesin lokal, buat SSH tunnel ke Cockpit
ssh -L 9090:localhost:9090 -i ~/.ssh/cockpit_ed25519 username@<IP_SERVER> -N &

# Buka browser ke
# https://localhost:9090
```

---

## 3. Kustomisasi Konfigurasi Cockpit

### 3.1 Mengubah Port Default Cockpit (dari 9090 ke Port Kustom)

Port default Cockpit adalah `9090`. Mengubahnya ke port yang tidak umum (*security through obscurity*) dapat mengurangi noise dari *automated scanners*.

#### Metode: Override Konfigurasi systemd Socket

Cockpit menggunakan unit socket systemd. Cara terbaik mengubah port adalah dengan membuat file **drop-in override** (bukan mengedit file asli, agar update sistem tidak menimpa perubahan Anda).

#### Langkah 1 — Buat direktori override

```bash
sudo mkdir -p /etc/systemd/system/cockpit.socket.d/
```

#### Langkah 2 — Buat file konfigurasi override

```bash
sudo nano /etc/systemd/system/cockpit.socket.d/listen.conf
```

Isi file tersebut:

```ini
[Socket]
# Kosongkan daftar listener yang ada terlebih dahulu
ListenStream=
# Tentukan port baru (contoh: 9443)
ListenStream=9443
```

> **Penting:** Baris `ListenStream=` yang kosong **wajib ada** untuk menghapus nilai port lama (9090) sebelum mendefinisikan port baru. Tanpa baris kosong ini, kedua port akan aktif bersamaan.

#### Langkah 3 — Reload dan restart

```bash
sudo systemctl daemon-reload
sudo systemctl restart cockpit.socket
```

#### Langkah 4 — Verifikasi port baru aktif

```bash
ss -tlnp | grep 9443
```

#### Langkah 5 — Izinkan port baru di firewall

```bash
# Hapus rule port lama (jika ada)
sudo ufw delete allow 9090/tcp

# Tambahkan rule port baru
sudo ufw allow 9443/tcp comment "Cockpit custom port"
```

Cockpit sekarang dapat diakses di `https://<IP_SERVER>:9443`.

---

### 3.2 Mengubah Password User dari Dalam Cockpit

1. Login ke Cockpit.
2. Klik nama user di pojok kanan atas → **Accounts** (atau navigasi ke menu **Accounts** di sidebar).
3. Klik username yang ingin diubah passwordnya.
4. Klik tombol **Set Password**.
5. Masukkan password baru dua kali dan klik **Set**.

Perubahan ini langsung berlaku pada akun Linux sistem dan sinkron dengan PAM.

> Sebagai alternatif via CLI:
> ```bash
> sudo passwd nama_user
> ```

---

### 3.3 Membatasi Akses Root Langsung via Cockpit

Mengizinkan login root langsung adalah risiko keamanan besar. Praktik terbaik adalah: **login sebagai user biasa, lalu eskalasi ke root via sudo**.

#### Langkah 1 — Edit file konfigurasi Cockpit

```bash
sudo mkdir -p /etc/cockpit
sudo nano /etc/cockpit/cockpit.conf
```

Tambahkan konfigurasi berikut:

```ini
[WebService]
# Tolak login langsung sebagai root
LoginTitle = Server Administration Panel
AllowUnencrypted = false

[Session]
# Paksa penggunaan sudo untuk eskalasi, bukan login root langsung
Banner = /etc/cockpit/banner.txt
```

#### Langkah 2 — Nonaktifkan login root via PAM Cockpit

Edit file PAM khusus Cockpit:

```bash
sudo nano /etc/pam.d/cockpit
```

Tambahkan baris berikut **di bagian paling atas** (sebelum baris `auth` yang lain):

```
# Tolak login root langsung via Cockpit
auth    required     pam_listfile.so item=user sense=deny file=/etc/cockpit/deny-users onerr=succeed
```

Buat file daftar user yang diblokir:

```bash
sudo nano /etc/cockpit/deny-users
```

Isi:

```
root
```

#### Langkah 3 — Pastikan user operasional Anda memiliki sudo

```bash
# Tambahkan user ke grup sudo
sudo usermod -aG sudo nama_user
```

#### Langkah 4 — Restart Cockpit

```bash
sudo systemctl restart cockpit
```

Mulai sekarang, percobaan login sebagai `root` via Cockpit akan ditolak. User harus login sebagai user biasa dan menggunakan fitur "administrative access" (sudo) di dalam Cockpit.

---

### 3.4 Konfigurasi File `cockpit.conf` Lengkap (Referensi)

```bash
sudo nano /etc/cockpit/cockpit.conf
```

```ini
[WebService]
# Judul yang ditampilkan di halaman login
LoginTitle = [NAMA_SERVER] - Admin Panel

# Daftar origins yang diizinkan (ganti dengan domain/IP server Anda)
Origins = https://admin.namadomain.com https://<IP_SERVER>:9443

# Larang koneksi HTTP tidak terenkripsi
AllowUnencrypted = false

# Protokol minimum TLS
# (dikonfigurasi di level sistem, bukan di cockpit.conf)

[Session]
# Durasi idle sebelum sesi otomatis logout (dalam detik)
# 1800 = 30 menit
IdleTimeout = 1800

# Banner login (opsional)
# Banner = /etc/cockpit/banner.txt
```

Simpan dan restart:

```bash
sudo systemctl restart cockpit
```

---

## 4. Skenario Keamanan Jaringan & Firewall (UFW)

> **⚠️ PERINGATAN SEBELUM MENGAKTIFKAN UFW:**
> Jika Anda mengakses server ini via SSH, **PASTIKAN** rule SSH (port 22 atau port kustom SSH Anda) sudah ditambahkan **SEBELUM** mengaktifkan UFW. Kegagalan melakukan ini akan mengakibatkan Anda **terkunci keluar dari server**.

### Persiapan Awal UFW

```bash
# Install UFW jika belum ada
sudo apt install -y ufw

# Set kebijakan default: tolak semua koneksi masuk, izinkan semua koneksi keluar
sudo ufw default deny incoming
sudo ufw default allow outgoing

# WAJIB: Izinkan SSH terlebih dahulu sebelum enable!
sudo ufw allow 22/tcp comment "SSH Access"
# ATAU jika SSH di port kustom:
# sudo ufw allow 2222/tcp comment "SSH Custom Port"

# Aktifkan UFW
sudo ufw enable

# Verifikasi status
sudo ufw status verbose
```

---

### SKENARIO A — Ekspos Publik (Tidak Direkomendasikan)

> **⚠️ RISIKO KEAMANAN TINGGI:** Mengekspos port Cockpit ke internet publik berarti antarmuka administrasi server Anda dapat diakses oleh siapa saja di seluruh dunia. Ini membuka permukaan serangan yang signifikan, termasuk serangan *brute force*, eksploitasi kerentanan zero-day di Cockpit, dan serangan *credential stuffing*. Gunakan skenario ini HANYA jika tidak ada alternatif lain, dan selalu kombinasikan dengan langkah mitigasi di bawah.

#### A1 — Membuka Port ke Semua IP (Paling Berbahaya)

```bash
# HANYA jika benar-benar tidak ada pilihan lain
sudo ufw allow 9443/tcp comment "Cockpit - PUBLIC ACCESS"
```

#### A2 — Membatasi Akses ke IP Statis Tertentu (Whitelisting IP)

Ini adalah cara yang **jauh lebih aman** untuk skenario publik. Hanya izinkan IP rumah atau kantor Anda:

```bash
# Izinkan IP statis rumah/kantor (ganti dengan IP Anda yang sebenarnya)
sudo ufw allow from 203.0.113.50 to any port 9443 proto tcp comment "Cockpit - IP Kantor"
sudo ufw allow from 198.51.100.25 to any port 9443 proto tcp comment "Cockpit - IP Rumah"

# Blokir semua akses lain ke port Cockpit
sudo ufw deny 9443/tcp comment "Cockpit - Block Public"
```

> **Catatan:** Pastikan urutan rule UFW sudah benar. UFW memproses rule secara berurutan — rule `allow` spesifik harus ada **sebelum** rule `deny` yang lebih umum.

#### A3 — Verifikasi dan Cek Urutan Rule

```bash
sudo ufw status numbered
```

Contoh output yang benar:

```
     To                         Action      From
     --                         ------      ----
[ 1] 22/tcp                     ALLOW IN    Anywhere
[ 2] 9443/tcp                   ALLOW IN    203.0.113.50
[ 3] 9443/tcp                   ALLOW IN    198.51.100.25
[ 4] 9443/tcp                   DENY IN     Anywhere
```

#### Rekomendasi Tambahan untuk Skenario A

- Aktifkan **Fail2Ban** untuk memblokir IP yang gagal login berulang kali.
- Gunakan sertifikat SSL yang valid (Let's Encrypt), bukan *self-signed*.
- Aktifkan **2FA (Two-Factor Authentication)** melalui modul PAM Google Authenticator.
- Pantau log akses secara rutin: `sudo journalctl -u cockpit -f`

---

### SKENARIO B — Akses via VPN (Sangat Direkomendasikan)

Ini adalah pendekatan yang **paling aman**. Port Cockpit **sama sekali tidak diekspos ke internet publik**. Satu-satunya cara mengakses Cockpit adalah dengan terlebih dahulu terhubung ke **VPN server**, kemudian mengakses Cockpit melalui IP internal VPN.

#### Arsitektur Skenario B

```
Internet Publik
       │
       │  ← Port 9443 TERTUTUP untuk publik
       │
  ┌────▼────────────────────────────────────┐
  │            SERVER LINUX                  │
  │                                          │
  │  Port 1194 (UDP) ← OpenVPN/WireGuard    │
  │  Port 9443       ← Cockpit (HANYA VPN)  │
  │                                          │
  │  VPN Internal Network: 10.8.0.0/24      │
  └──────────────────────────────────────────┘
       │
       │  ← Koneksi dari VPN Client (10.8.0.2)
       │
  ┌────▼──────────┐
  │  Admin/Dev    │
  │  (VPN Client) │
  └───────────────┘
```

#### B1 — Setup UFW untuk Skenario VPN

```bash
# Izinkan port VPN dari internet publik (OpenVPN)
sudo ufw allow 1194/udp comment "OpenVPN"
# ATAU untuk WireGuard:
# sudo ufw allow 51820/udp comment "WireGuard VPN"

# Izinkan Cockpit HANYA dari rentang IP internal VPN
sudo ufw allow from 10.8.0.0/24 to any port 9443 proto tcp comment "Cockpit - VPN Only (OpenVPN)"
# ATAU jika VPN Anda menggunakan subnet yang berbeda:
# sudo ufw allow from 10.0.0.0/24 to any port 9443 proto tcp comment "Cockpit - VPN Only"
# sudo ufw allow from 172.16.0.0/12 to any port 9443 proto tcp comment "Cockpit - Corporate VPN"

# BLOKIR semua akses publik ke port Cockpit
sudo ufw deny 9443/tcp comment "Cockpit - Block All Public Access"
```

#### B2 — Verifikasi Rule UFW Skenario B

```bash
sudo ufw status numbered
```

Output yang diharapkan:

```
Status: active

     To                         Action      From
     --                         ------      ----
[ 1] 22/tcp                     ALLOW IN    Anywhere
[ 2] 1194/udp                   ALLOW IN    Anywhere
[ 3] 9443/tcp                   ALLOW IN    10.8.0.0/24
[ 4] 9443/tcp                   DENY IN     Anywhere
```

#### B3 — Cara Mengakses Cockpit via VPN

1. Hubungkan klien Anda ke VPN server.
2. Setelah terhubung, klien Anda akan mendapatkan IP internal (contoh: `10.8.0.2`).
3. Buka browser dan akses Cockpit menggunakan **IP internal server** (bukan IP publik):

```
https://10.8.0.1:9443
# atau menggunakan IP server di interface VPN
```

> **Keuntungan Skenario B:**
> - Port 9443 **tidak terlihat** dari internet publik sama sekali (port scanner tidak dapat mendeteksinya).
> - Serangan *brute force* terhadap Cockpit mustahil dilakukan tanpa akses VPN terlebih dahulu.
> - Lapisan keamanan ganda: VPN (autentikasi + enkripsi) + Cockpit (autentikasi Linux).
> - Jika VPN server dikonfigurasi dengan *certificate-based auth*, ini setara dengan 2FA.

#### B4 — Test Keamanan: Verifikasi Port Tertutup dari Publik

Dari mesin yang **tidak terhubung ke VPN**, jalankan:

```bash
# Scan port dari luar (ganti dengan IP publik server Anda)
nmap -p 9443 <IP_PUBLIK_SERVER>
```

Output yang diharapkan (port tertutup):

```
PORT     STATE    SERVICE
9443/tcp filtered https-alt
```

Status `filtered` berarti port tidak dapat dijangkau dari internet — persis yang kita inginkan.

---

## 5. Manajemen Service (Systemd & Supervisor di Cockpit)

### 5.1 Memantau, Start, Stop, dan Restart Service via Web GUI

Cockpit menyediakan antarmuka grafis yang intuitif untuk mengelola seluruh service systemd di server Anda tanpa perlu CLI.

#### Navigasi ke Tab Services

1. Login ke Cockpit (`https://<IP_SERVER>:9443`).
2. Di sidebar kiri, klik **Services**.
3. Anda akan melihat daftar semua unit systemd yang tersedia, dikategorikan berdasarkan tipe (Service, Socket, Target, Timer, Path).

#### Mencari Service Spesifik

Gunakan kotak pencarian di bagian atas daftar untuk mencari service yang diinginkan. Contoh: ketik `nginx`, `mysql`, atau `supervisor`.

#### Operasi Dasar pada Service

Untuk setiap service (contoh: Nginx), langkah-langkahnya:

1. **Klik nama service** (misalnya `nginx.service`) dari daftar.
2. Halaman detail service akan terbuka, menampilkan:
   - Status aktif (*active/inactive/failed*)
   - PID proses
   - Waktu service terakhir dimulai
   - Cuplikan log terbaru
3. Gunakan tombol-tombol kontrol:

| Tombol       | Fungsi                              | Setara CLI                        |
|--------------|-------------------------------------|-----------------------------------|
| **Start**    | Jalankan service                    | `systemctl start nginx`           |
| **Stop**     | Hentikan service                    | `systemctl stop nginx`            |
| **Restart**  | Restart service                     | `systemctl restart nginx`         |
| **Reload**   | Reload konfigurasi tanpa restart    | `systemctl reload nginx`          |
| **Enable**   | Aktifkan auto-start saat boot       | `systemctl enable nginx`          |
| **Disable**  | Nonaktifkan auto-start saat boot    | `systemctl disable nginx`         |

#### Contoh: Mengelola Nginx

```
Services → [Search: nginx] → nginx.service → [Restart]
```

#### Contoh: Mengelola MySQL/MariaDB

```
Services → [Search: mysql] → mysql.service → [Start/Stop/Restart]
```

#### Contoh: Mengelola Supervisor

```
Services → [Search: supervisor] → supervisor.service → [Restart]
```

> **Catatan Supervisor:** Cockpit mengelola Supervisor sebagai service systemd, bukan proses individu yang dikelola Supervisor. Untuk mengelola program spesifik di dalam Supervisor (seperti queue worker Laravel), Anda masih perlu menggunakan `supervisorctl` via terminal Cockpit.

---

### 5.2 Menggunakan Terminal Bawaan Cockpit

Cockpit menyediakan terminal web yang sepenuhnya fungsional:

1. Di sidebar kiri, klik **Terminal**.
2. Terminal akan terbuka dengan shell Bash sebagai user Anda.
3. Untuk perintah yang membutuhkan sudo:

```bash
sudo supervisorctl status
sudo supervisorctl restart laravel-worker:*
```

---

### 5.3 Membaca Journal Log Real-Time

Ketika sebuah service mendadak *error* atau *stop*, log adalah sumber informasi paling berharga.

#### Via Web UI Cockpit

1. Navigasi ke **Services** → klik nama service yang bermasalah.
2. Di bagian bawah halaman detail, klik **View all logs** atau langsung gulir ke bagian **Journal**.
3. Log akan ditampilkan secara real-time dan di-highlight berdasarkan level severity (INFO, WARNING, ERROR, CRITICAL).

#### Via Menu Logs (Semua Logs Sistem)

1. Di sidebar kiri, klik **Logs**.
2. Gunakan filter yang tersedia:
   - **Priority:** Error, Warning, Notice, Info, Debug
   - **Service:** Filter berdasarkan nama service (contoh: `nginx`, `mysql`)
   - **Time:** Filter berdasarkan rentang waktu

#### Via Terminal Cockpit (Real-Time Streaming)

Untuk monitoring log yang lebih granular:

```bash
# Ikuti log Nginx secara real-time
sudo journalctl -u nginx -f

# Ikuti log MySQL secara real-time
sudo journalctl -u mysql -f

# Ikuti log Supervisor secara real-time
sudo journalctl -u supervisor -f

# Tampilkan 50 baris terakhir dari semua log sistem
sudo journalctl -n 50 --no-pager

# Filter log berdasarkan waktu
sudo journalctl -u nginx --since "2024-01-01 08:00:00" --until "2024-01-01 10:00:00"

# Tampilkan hanya error dan critical
sudo journalctl -p err -u nginx -f
```

#### Contoh Diagnosa: Service Nginx Tiba-Tiba Stop

```bash
# 1. Cek status
sudo systemctl status nginx

# 2. Lihat log error terbaru
sudo journalctl -u nginx -n 50 --no-pager

# 3. Test konfigurasi Nginx
sudo nginx -t

# 4. Restart jika konfigurasi valid
sudo systemctl restart nginx
```

---

## 6. Penanganan Error & Troubleshooting (Common Errors)

### Masalah 1: Error "Web Page Not Available / Connection Refused" Setelah Mengubah Port

**Gejala:** Browser menampilkan `ERR_CONNECTION_REFUSED` atau `This site can't be reached` setelah port Cockpit diubah dari 9090 ke port baru.

**Penyebab Umum:**

1. File konfigurasi override tidak dibuat dengan benar.
2. Lupa menjalankan `systemctl daemon-reload`.
3. Port baru belum diizinkan di UFW.
4. SELinux/AppArmor memblokir port baru (jarang di Debian, tapi perlu dicek).

**Solusi:**

```bash
# Langkah 1: Verifikasi file override ada dan benar
cat /etc/systemd/system/cockpit.socket.d/listen.conf

# Pastikan isinya:
# [Socket]
# ListenStream=
# ListenStream=9443

# Langkah 2: Reload dan restart
sudo systemctl daemon-reload
sudo systemctl restart cockpit.socket

# Langkah 3: Verifikasi port baru sedang di-listen
sudo ss -tlnp | grep cockpit
# atau
sudo ss -tlnp | grep 9443

# Langkah 4: Periksa status socket
sudo systemctl status cockpit.socket

# Langkah 5: Pastikan firewall mengizinkan port baru
sudo ufw status numbered
sudo ufw allow 9443/tcp comment "Cockpit"
sudo ufw reload

# Langkah 6: Test koneksi dari server itu sendiri
curl -k https://localhost:9443
```

Jika masih gagal, cek apakah ada proses lain yang menggunakan port tersebut:

```bash
sudo lsof -i :9443
```

---

### Masalah 2: Error "Login Failed" atau User Tidak Memiliki Hak Administratif

**Gejala A:** Login gagal dengan pesan "Login failed" meskipun username dan password sudah benar.

**Gejala B:** Berhasil login, tetapi tidak ada opsi administratif (tombol grayed out, muncul pesan "Limited access").

#### Solusi A: User Tidak Ada atau Password Salah

```bash
# Verifikasi user ada di sistem
id nama_user

# Reset password user jika lupa
sudo passwd nama_user

# Pastikan akun tidak terkunci
sudo passwd -S nama_user
# Jika status menunjukkan 'L' (Locked), buka kunci:
sudo passwd -u nama_user
```

#### Solusi B: User Tidak Ada di Grup Sudo (Debian)

Di Debian, user baru **tidak otomatis** mendapatkan akses sudo. Ini adalah penyebab paling umum dari masalah "Limited access" di Cockpit.

```bash
# Tambahkan user ke grup sudo
sudo usermod -aG sudo nama_user

# ATAU edit /etc/sudoers secara langsung (gunakan visudo!)
sudo visudo
# Tambahkan baris berikut:
# nama_user ALL=(ALL:ALL) ALL

# Verifikasi keanggotaan grup
groups nama_user
# Output harus mengandung: sudo

# PENTING: User perlu logout dan login kembali agar perubahan grup efektif
```

#### Solusi C: Cek Log PAM Cockpit

```bash
sudo journalctl -u cockpit -n 50
# atau
sudo tail -f /var/log/auth.log | grep cockpit
```

---

### Masalah 3: Sertifikat SSL/TLS Dianggap "Not Secure" oleh Browser

**Gejala:** Browser menampilkan peringatan keamanan, ikon gembok merah/silang, atau `NET::ERR_CERT_AUTHORITY_INVALID`.

**Penyebab:** Cockpit menggunakan sertifikat SSL *self-signed* yang tidak dikenal oleh *Certificate Authority* (CA) publik.

#### Opsi 1: Bypass Sementara (Tidak Direkomendasikan untuk Produksi)

Klik **Advanced** → **Proceed to [IP] (unsafe)** di browser. Ini hanya untuk testing dan development.

#### Opsi 2: Install Sertifikat Let's Encrypt (Direkomendasikan untuk Domain Publik)

Cockpit secara otomatis akan menggunakan sertifikat yang ditempatkan di `/etc/cockpit/ws-certs.d/`.

```bash
# Install Certbot
sudo apt install -y certbot

# Generate sertifikat (ganti dengan domain Anda)
# Pastikan port 80 terbuka sementara untuk validasi HTTP-01
sudo ufw allow 80/tcp
sudo certbot certonly --standalone -d admin.namadomain.com

# Salin sertifikat ke direktori Cockpit
sudo cp /etc/letsencrypt/live/admin.namadomain.com/fullchain.pem \
        /etc/cockpit/ws-certs.d/1-server.cert
sudo cp /etc/letsencrypt/live/admin.namadomain.com/privkey.pem \
        /etc/cockpit/ws-certs.d/1-server.key

# Set permission yang benar
sudo chmod 640 /etc/cockpit/ws-certs.d/1-server.key
sudo chown root:cockpit-ws /etc/cockpit/ws-certs.d/1-server.key

# Restart Cockpit
sudo systemctl restart cockpit

# Tutup kembali port 80 jika tidak dibutuhkan
sudo ufw delete allow 80/tcp
```

#### Otomasi Renewal Sertifikat Let's Encrypt

```bash
# Buat script renewal hook
sudo nano /etc/letsencrypt/renewal-hooks/deploy/cockpit-cert.sh
```

Isi script:

```bash
#!/bin/bash
DOMAIN="admin.namadomain.com"

cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem /etc/cockpit/ws-certs.d/1-server.cert
cp /etc/letsencrypt/live/$DOMAIN/privkey.pem /etc/cockpit/ws-certs.d/1-server.key
chmod 640 /etc/cockpit/ws-certs.d/1-server.key
chown root:cockpit-ws /etc/cockpit/ws-certs.d/1-server.key
systemctl restart cockpit
```

```bash
# Buat script executable
sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/cockpit-cert.sh

# Test renewal
sudo certbot renew --dry-run
```

#### Opsi 3: Generate Sertifikat Self-Signed dengan SAN (Untuk Intranet/VPN)

Untuk lingkungan internal (VPN), Anda bisa membuat sertifikat *self-signed* yang lebih baik dengan Subject Alternative Name (SAN):

```bash
# Generate sertifikat self-signed yang valid 10 tahun dengan SAN
sudo openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
  -keyout /etc/cockpit/ws-certs.d/1-server.key \
  -out /etc/cockpit/ws-certs.d/1-server.cert \
  -subj "/CN=cockpit-server" \
  -addext "subjectAltName=IP:10.8.0.1,IP:192.168.1.100,DNS:cockpit.internal"

# Set permission
sudo chmod 640 /etc/cockpit/ws-certs.d/1-server.key
sudo chown root:cockpit-ws /etc/cockpit/ws-certs.d/1-server.key

# Restart Cockpit
sudo systemctl restart cockpit
```

Kemudian, impor sertifikat ini ke *trust store* browser atau sistem operasi klien Anda agar tidak ada peringatan.

---

### Masalah 4: Cockpit Tiba-Tiba Disconnect Sendiri Saat Sedang Digunakan

**Gejala:** Sesi Cockpit terputus secara tiba-tiba, menampilkan pesan "Disconnected from server" atau "Socket closed", meskipun tidak ada aktivitas atau bahkan saat sedang aktif bekerja.

**Penyebab dan Solusinya:**

#### Penyebab A: Session Idle Timeout

Cockpit memiliki batas waktu idle default. Perpanjang atau nonaktifkan:

```bash
sudo nano /etc/cockpit/cockpit.conf
```

```ini
[Session]
# Durasi idle timeout dalam detik (0 = tidak ada timeout)
# Default: 900 (15 menit)
IdleTimeout = 3600
```

```bash
sudo systemctl restart cockpit
```

#### Penyebab B: Timeout di Nginx/Load Balancer (Jika Cockpit di Belakang Reverse Proxy)

Jika Cockpit diakses melalui Nginx sebagai reverse proxy, Nginx mungkin menutup koneksi WebSocket yang idle terlalu cepat.

```nginx
# Di konfigurasi Nginx untuk Cockpit
location / {
    proxy_pass https://localhost:9443;
    proxy_http_version 1.1;
    
    # Header wajib untuk WebSocket
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    
    # Perpanjang timeout (dalam detik)
    proxy_read_timeout 3600;
    proxy_send_timeout 3600;
    proxy_connect_timeout 3600;
    
    # Keepalive
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

#### Penyebab C: Keepalive SSH Terputus

Jika Cockpit diakses melalui SSH tunnel, tambahkan konfigurasi keepalive:

Di mesin lokal, edit `~/.ssh/config`:

```
Host server-cockpit
    HostName <IP_SERVER>
    User nama_user
    IdentityFile ~/.ssh/cockpit_ed25519
    ServerAliveInterval 60
    ServerAliveCountMax 10
    LocalForward 9090 localhost:9443
```

#### Penyebab D: Resource Server Habis (OOM Killer)

Periksa apakah `cockpit.service` di-kill oleh OOM Killer:

```bash
sudo dmesg | grep -i "oom\|killed"
sudo journalctl -k | grep -i "oom\|killed"
sudo journalctl -u cockpit --since "1 hour ago" | grep -i "killed\|error\|failed"
```

Jika terbukti karena OOM, pertimbangkan untuk menambah RAM atau mengurangi beban service lain di server.

#### Penyebab E: Sertifikat SSL Expired

```bash
# Cek tanggal expired sertifikat Cockpit
sudo openssl x509 -in /etc/cockpit/ws-certs.d/0-self-signed.cert -noout -dates
# atau sertifikat kustom:
sudo openssl x509 -in /etc/cockpit/ws-certs.d/1-server.cert -noout -dates
```

Jika sudah expired, lakukan renewal (lihat Masalah 3).

---

## Ringkasan Perintah Penting (Quick Reference)

```bash
# === COCKPIT SERVICE ===
sudo systemctl status cockpit.socket    # Cek status
sudo systemctl start cockpit.socket     # Mulai
sudo systemctl stop cockpit.socket      # Hentikan
sudo systemctl restart cockpit          # Restart
sudo systemctl enable cockpit.socket    # Auto-start saat boot
sudo journalctl -u cockpit -f           # Log real-time

# === UFW FIREWALL ===
sudo ufw status numbered                # Lihat semua rule
sudo ufw allow from 10.8.0.0/24 to any port 9443 proto tcp  # VPN only
sudo ufw delete allow 9090/tcp          # Hapus rule lama
sudo ufw reload                         # Reload konfigurasi

# === SERTIFIKAT SSL ===
sudo ls -la /etc/cockpit/ws-certs.d/    # Lihat sertifikat aktif
sudo openssl x509 -in /etc/cockpit/ws-certs.d/0-self-signed.cert -noout -dates

# === KONFIGURASI ===
sudo nano /etc/cockpit/cockpit.conf     # Edit konfigurasi Cockpit
sudo nano /etc/systemd/system/cockpit.socket.d/listen.conf  # Override port
sudo systemctl daemon-reload            # Reload setelah edit systemd
```

---

## Checklist Keamanan Akhir

Sebelum server masuk ke lingkungan produksi, pastikan semua item berikut sudah terpenuhi:

- [ ] Cockpit diakses **hanya melalui VPN** (Skenario B), bukan diekspos ke publik.
- [ ] Login root langsung via Cockpit **diblokir**.
- [ ] User operasional menggunakan **SSH Key** untuk autentikasi, bukan password.
- [ ] `PasswordAuthentication no` sudah aktif di `/etc/ssh/sshd_config`.
- [ ] Port Cockpit sudah diubah dari **9090 ke port kustom**.
- [ ] UFW aktif dengan **default deny incoming** policy.
- [ ] Sertifikat SSL sudah diganti dari *self-signed* ke **Let's Encrypt** (jika domain publik) atau sertifikat internal yang diimport ke klien (jika intranet).
- [ ] `IdleTimeout` dikonfigurasi di `/etc/cockpit/cockpit.conf`.
- [ ] Fail2Ban diinstall dan dikonfigurasi untuk memblokir brute force.
- [ ] Log Cockpit dipantau secara rutin via `journalctl -u cockpit`.

---

*Dokumen ini ditulis mengikuti standar keamanan industri untuk administrasi server Linux. Selalu uji setiap perubahan di lingkungan staging sebelum menerapkan ke server produksi.*

*Versi Dokumen: 1.0 | Platform: Debian 12 (Bookworm) | Cockpit: v306+*
