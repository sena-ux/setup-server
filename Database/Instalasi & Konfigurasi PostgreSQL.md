# Panduan Instalasi & Konfigurasi PostgreSQL (v16/v17)
### Linux (Ubuntu 24.04 LTS / Rocky Linux 9) & Windows 11 / Windows Server
> **Role:** Senior DevOps Engineer & DBA | **Scope:** Infrastruktur & Sistem (Non-SQL/DML/DDL)

---

## Daftar Isi

1. [Prasyarat (Pre-Requisites)](#1-prasyarat-pre-requisites)
2. [Metode Instalasi — Linux](#2-metode-instalasi--linux)
3. [Metode Instalasi — Windows](#3-metode-instalasi--windows)
4. [Konfigurasi Jaringan & Port](#4-konfigurasi-jaringan--port)
5. [Manajemen Servis & Otentikasi Awal](#5-manajemen-servis--otentikasi-awal)
6. [Firewall & Keamanan Sistem](#6-firewall--keamanan-sistem)
7. [Troubleshooting Umum](#7-troubleshooting-umum)

---

## 1. Prasyarat (Pre-Requisites)

### 1.1 Linux — Ubuntu 24.04 LTS

| Kebutuhan | Minimum | Rekomendasi Produksi |
|---|---|---|
| CPU | 1 Core | 4+ Core |
| RAM | 1 GB | 8 GB+ |
| Disk | 10 GB | 100 GB+ (SSD/NVMe) |
| OS | Ubuntu 24.04 LTS | Ubuntu 24.04 LTS |
| Akses | `sudo` user | `sudo` user |

```bash
# Pastikan sistem up-to-date
sudo apt update && sudo apt upgrade -y

# Install dependensi umum
sudo apt install -y curl ca-certificates gnupg lsb-release wget

# Cek versi OS (pastikan output: 24.04)
lsb_release -rs
```

### 1.2 Linux — Rocky Linux 9

```bash
# Pastikan sistem up-to-date
sudo dnf update -y

# Install dependensi umum
sudo dnf install -y curl wget gnupg2 epel-release

# Cek versi OS
cat /etc/rocky-release
```

### 1.3 Windows 11 / Windows Server

- **OS:** Windows 11 Pro/Enterprise atau Windows Server 2019/2022
- **Akses:** Local Administrator atau Domain Admin
- **Dependensi:** Microsoft Visual C++ Redistributable 2015–2022 (diinstall otomatis oleh wizard)
- **Disk:** Minimal 1 GB untuk binari; pisahkan drive untuk data (`D:\pgdata` atau volume dedicated)
- **Firewall:** Akses untuk membuat Inbound Rule

---

## 2. Metode Instalasi — Linux

> **Wajib menggunakan repositori resmi PGDG**, bukan repo bawaan distro (versinya tertinggal).

### 2.1 Ubuntu 24.04 LTS — PostgreSQL 17

```bash
# Step 1: Import signing key resmi PostgreSQL
sudo install -d /usr/share/postgresql-common/pgdg
sudo curl -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc --fail \
  https://www.postgresql.org/media/keys/ACCC4CF8.asc

# Step 2: Tambahkan repositori PGDG
sudo sh -c 'echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] \
  https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" \
  > /etc/apt/sources.list.d/pgdg.list'

# Step 3: Update index paket
sudo apt update

# Step 4: Install PostgreSQL 17 (ganti 17 dengan 16 jika diperlukan)
sudo apt install -y postgresql-17

# Step 5: Verifikasi instalasi
psql --version
# Output: psql (PostgreSQL) 17.x

# Cek status service
sudo systemctl status postgresql@17-main
```

### 2.2 Rocky Linux 9 — PostgreSQL 17

```bash
# Step 1: Disable modul PostgreSQL bawaan Rocky (PENTING!)
sudo dnf -qy module disable postgresql

# Step 2: Install repositori PGDG untuk RHEL 9
sudo dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-x86_64/pgdg-redhat-repo-latest.noarch.rpm

# Step 3: Install PostgreSQL 17
sudo dnf install -y postgresql17-server postgresql17-contrib

# Step 4: Inisialisasi database cluster (WAJIB di RHEL/Rocky, berbeda dari Ubuntu!)
sudo /usr/pgsql-17/bin/postgresql-17-setup initdb

# Step 5: Enable & start service
sudo systemctl enable postgresql-17
sudo systemctl start postgresql-17

# Step 6: Verifikasi
psql --version
sudo systemctl status postgresql-17
```

> **Catatan Kritis Rocky Linux:**
> - Path binary: `/usr/pgsql-17/bin/`
> - Path data: `/var/lib/pgsql/17/data/`
> - `initdb` **wajib** dijalankan manual, tidak otomatis seperti Ubuntu.

---

## 3. Metode Instalasi — Windows

### 3.1 Download Installer Resmi

1. Buka browser, navigasi ke: **https://www.postgresql.org/download/windows/**
2. Klik **"Download the installer"** (diarahkan ke EnterpriseDB/EDB)
3. Pilih versi **17.x** (atau 16.x) → kolom **Windows x86-64** → klik ikon unduh

### 3.2 Menjalankan Wizard Installer

Jalankan file `.exe` sebagai **Administrator** (klik kanan → *Run as administrator*).

| Layar Wizard | Pilihan & Tips |
|---|---|
| **Installation Directory** | Default: `C:\Program Files\PostgreSQL\17` — aman dibiarkan |
| **Data Directory** | **Ubah** ke drive terpisah: `D:\PostgreSQL\17\data` (hindari drive OS) |
| **Password** | Isi password untuk superuser `postgres` — **simpan di password manager!** |
| **Port** | Default `5432` — **ubah ke port kustom di sini** (misal: `5433`) |
| **Locale** | Pilih `C` atau `en_US.UTF-8` untuk kompatibilitas maksimal |
| **Stack Builder** | Bisa di-skip (klik *Finish* tanpa centang) |

### 3.3 Verifikasi Post-Install Windows

Buka **PowerShell** atau **CMD** sebagai Administrator:

```powershell
# Cek versi
& "C:\Program Files\PostgreSQL\17\bin\psql.exe" --version
# Output: psql (PostgreSQL) 17.x

# Cek apakah service berjalan
Get-Service -Name "postgresql*"
# Atau di CMD:
sc query postgresql-x64-17
```

---

## 4. Konfigurasi Jaringan & Port

### 4.1 Lokasi File Konfigurasi

| Platform | `postgresql.conf` | `pg_hba.conf` |
|---|---|---|
| Ubuntu 24.04 | `/etc/postgresql/17/main/postgresql.conf` | `/etc/postgresql/17/main/pg_hba.conf` |
| Rocky Linux 9 | `/var/lib/pgsql/17/data/postgresql.conf` | `/var/lib/pgsql/17/data/pg_hba.conf` |
| Windows | `D:\PostgreSQL\17\data\postgresql.conf` | `D:\PostgreSQL\17\data\pg_hba.conf` |

### 4.2 Mengubah Port Default (5432 → 5433)

Edit file `postgresql.conf`:

```bash
# Linux — buka dengan editor
sudo nano /etc/postgresql/17/main/postgresql.conf
# Rocky: sudo nano /var/lib/pgsql/17/data/postgresql.conf
```

Cari dan ubah baris berikut:

```ini
# Sebelum (biasanya tercomment):
#port = 5432

# Sesudah (hapus # dan ubah port):
port = 5433
```

> **Windows:** Buka file dengan Notepad atau Notepad++ **sebagai Administrator**, lakukan perubahan yang sama.

### 4.3 Konfigurasi `listen_addresses`

Masih di file `postgresql.conf`, cari parameter `listen_addresses`:

```ini
# Hanya localhost (default — tidak bisa diakses dari luar):
listen_addresses = 'localhost'

# Akses dari SEMUA IP (development/staging — hati-hati di produksi!):
listen_addresses = '*'

# Akses dari IP spesifik (rekomendasi produksi):
listen_addresses = '192.168.1.10, 10.0.0.5'
```

> **Best Practice Produksi:** Gunakan IP spesifik atau load balancer IP, bukan `*`. Kombinasikan dengan `pg_hba.conf` untuk kontrol berlapis.

### 4.4 Konfigurasi `pg_hba.conf` (Host-Based Authentication)

File ini mengontrol **siapa yang boleh konek, dari mana, dan dengan metode apa**.

```bash
sudo nano /etc/postgresql/17/main/pg_hba.conf
```

**Struktur baris:**
```
TYPE    DATABASE    USER    ADDRESS             METHOD
```

**Contoh konfigurasi lengkap:**

```ini
# ============================================================
# pg_hba.conf — Konfigurasi Produksi
# ============================================================

# Koneksi lokal via Unix socket (jangan diubah)
local   all             postgres                                peer
local   all             all                                     peer

# Koneksi lokal via TCP (localhost)
host    all             all             127.0.0.1/32            scram-sha-256
host    all             all             ::1/128                 scram-sha-256

# Koneksi dari subnet internal (contoh: 192.168.1.0/24)
host    all             all             192.168.1.0/24          scram-sha-256

# Koneksi dari IP spesifik (misal: application server)
host    myappdb         appuser         10.0.0.50/32            scram-sha-256

# Akses dari SEMUA IP (TIDAK DIREKOMENDASIKAN untuk produksi)
# host  all             all             0.0.0.0/0               scram-sha-256
```

**Pilihan Metode Enkripsi:**

| Metode | Keterangan | Rekomendasi |
|---|---|---|
| `scram-sha-256` | Enkripsi modern, aman, PostgreSQL 10+ | ✅ **Gunakan ini** |
| `md5` | Legacy, kompatibel dengan client lama | ⚠️ Hanya jika client tidak support SCRAM |
| `peer` | Cocokkan user OS dengan user DB (lokal saja) | ✅ Untuk koneksi lokal |
| `trust` | Tanpa password — **BAHAYA!** | ❌ Jangan di produksi |

### 4.5 Restart Service Setelah Konfigurasi

```bash
# Ubuntu
sudo systemctl restart postgresql@17-main

# Rocky Linux
sudo systemctl restart postgresql-17

# Windows PowerShell (sebagai Admin)
Restart-Service -Name "postgresql-x64-17"
```

### 4.6 Verifikasi Port Aktif

```bash
# Linux — pastikan port 5433 LISTEN
sudo ss -tlnp | grep 5433
# Atau:
sudo netstat -tlnp | grep 5433

# Output yang diharapkan:
# LISTEN  0  128  0.0.0.0:5433  0.0.0.0:*  users:(("postgres",pid=XXXX))
```

```powershell
# Windows PowerShell
netstat -ano | Select-String ":5433"
# Atau:
Get-NetTCPConnection -LocalPort 5433
```

---

## 5. Manajemen Servis & Otentikasi Awal

### 5.1 Manajemen Service di Linux (systemd)

**Ubuntu 24.04:**

```bash
# Start service
sudo systemctl start postgresql@17-main

# Stop service
sudo systemctl stop postgresql@17-main

# Restart service
sudo systemctl restart postgresql@17-main

# Reload konfigurasi TANPA restart (untuk perubahan pg_hba.conf)
sudo systemctl reload postgresql@17-main

# Enable auto-start saat boot
sudo systemctl enable postgresql@17-main

# Disable auto-start
sudo systemctl disable postgresql@17-main

# Cek status detail
sudo systemctl status postgresql@17-main
```

**Rocky Linux 9:**

```bash
# Start service
sudo systemctl start postgresql-17

# Stop service
sudo systemctl stop postgresql-17

# Restart service
sudo systemctl restart postgresql-17

# Reload konfigurasi
sudo systemctl reload postgresql-17

# Enable auto-start saat boot
sudo systemctl enable postgresql-17

# Cek status detail
sudo systemctl status postgresql-17
```

### 5.2 Manajemen Service di Windows

**Metode 1 — Services.msc (GUI):**

```
1. Tekan Win + R → ketik services.msc → Enter
2. Cari "postgresql-x64-17"
3. Klik kanan → Start / Stop / Restart
4. Untuk auto-start: klik kanan → Properties → Startup type: Automatic
```

**Metode 2 — PowerShell (sebagai Administrator):**

```powershell
# Start service
Start-Service -Name "postgresql-x64-17"

# Stop service
Stop-Service -Name "postgresql-x64-17"

# Restart service
Restart-Service -Name "postgresql-x64-17"

# Cek status
Get-Service -Name "postgresql-x64-17"

# Set auto-start saat boot
Set-Service -Name "postgresql-x64-17" -StartupType Automatic

# Set manual
Set-Service -Name "postgresql-x64-17" -StartupType Manual
```

**Metode 3 — CMD (sebagai Administrator):**

```cmd
:: Start
net start postgresql-x64-17

:: Stop
net stop postgresql-x64-17

:: Cek status
sc query postgresql-x64-17
```

### 5.3 Login Pertama Kali & Set Password Master

**Linux — Login sebagai User `postgres`:**

```bash
# Beralih ke user sistem 'postgres'
sudo -i -u postgres

# Masuk ke psql shell (via Unix socket, tanpa password)
psql

# Di dalam psql prompt, set password untuk superuser postgres:
ALTER USER postgres WITH PASSWORD 'P@ssw0rd_Super_Kuat!';

# Keluar dari psql
\q

# Keluar dari user postgres
exit
```

**Verifikasi koneksi dengan password baru (via TCP):**

```bash
# Koneksi via TCP dengan port kustom 5433
psql -h 127.0.0.1 -p 5433 -U postgres -W
# Masukkan password saat diminta
```

**Windows — Login via psql:**

```powershell
# Buka PowerShell sebagai Administrator
# Navigasi ke direktori bin PostgreSQL
cd "C:\Program Files\PostgreSQL\17\bin"

# Login ke psql (password sudah di-set saat wizard, tapi bisa diubah)
.\psql.exe -h localhost -p 5433 -U postgres -W

# Di dalam psql prompt:
# ALTER USER postgres WITH PASSWORD 'P@ssw0rd_Super_Kuat!';
# \q
```

> **Catatan:** Di Ubuntu, koneksi lokal pertama menggunakan metode `peer` (tanpa password) via `sudo -u postgres psql`. Setelah password diset, koneksi TCP menggunakan `scram-sha-256`.

---

## 6. Firewall & Keamanan Sistem

### 6.1 UFW — Ubuntu 24.04

```bash
# Cek status UFW
sudo ufw status

# Aktifkan UFW jika belum (HATI-HATI: pastikan koneksi SSH tidak terblokir!)
# sudo ufw allow OpenSSH
# sudo ufw enable

# Buka port 5433 dari IP/subnet spesifik (REKOMENDASI)
sudo ufw allow from 192.168.1.0/24 to any port 5433 proto tcp

# Buka port 5433 dari IP spesifik
sudo ufw allow from 10.0.0.50 to any port 5433 proto tcp

# Buka port 5433 dari SEMUA IP (tidak disarankan untuk produksi)
# sudo ufw allow 5433/tcp

# Reload UFW untuk menerapkan aturan
sudo ufw reload

# Verifikasi aturan
sudo ufw status numbered
```

**Hapus rule jika salah:**

```bash
# Lihat nomor rule
sudo ufw status numbered

# Hapus berdasarkan nomor (misal nomor 3)
sudo ufw delete 3
```

### 6.2 Firewalld — Rocky Linux 9

```bash
# Cek status firewalld
sudo firewall-cmd --state

# Cek zone aktif
sudo firewall-cmd --get-active-zones

# Buka port 5433 secara PERMANEN di zone default
sudo firewall-cmd --permanent --add-port=5433/tcp

# Buka port 5433 hanya untuk IP/subnet spesifik (menggunakan rich rule)
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" \
  source address="192.168.1.0/24" port port="5433" protocol="tcp" accept'

# Reload firewalld untuk menerapkan perubahan
sudo firewall-cmd --reload

# Verifikasi port terbuka
sudo firewall-cmd --list-ports
sudo firewall-cmd --list-rich-rules
```

**Hapus rule jika salah:**

```bash
# Hapus port
sudo firewall-cmd --permanent --remove-port=5433/tcp

# Hapus rich rule (copy paste rule yang sama dengan --remove)
sudo firewall-cmd --permanent --remove-rich-rule='rule family="ipv4" \
  source address="192.168.1.0/24" port port="5433" protocol="tcp" accept'

sudo firewall-cmd --reload
```

### 6.3 Windows Defender Firewall

**Metode 1 — PowerShell (sebagai Administrator):**

```powershell
# Buat Inbound Rule untuk port 5433 dari subnet spesifik
New-NetFirewallRule `
  -DisplayName "PostgreSQL 17 - Port 5433" `
  -Direction Inbound `
  -Protocol TCP `
  -LocalPort 5433 `
  -RemoteAddress "192.168.1.0/24" `
  -Action Allow `
  -Profile Domain,Private `
  -Description "Allow PostgreSQL 5433 from internal network"

# Verifikasi rule
Get-NetFirewallRule -DisplayName "PostgreSQL 17 - Port 5433"
```

**Untuk membuka dari SEMUA IP (hapus -RemoteAddress):**

```powershell
New-NetFirewallRule `
  -DisplayName "PostgreSQL 17 - Port 5433 - All" `
  -Direction Inbound `
  -Protocol TCP `
  -LocalPort 5433 `
  -Action Allow `
  -Profile Any
```

**Metode 2 — Windows Firewall GUI:**

```
1. Buka Windows Defender Firewall with Advanced Security
   (cari di Start Menu atau: wf.msc)
2. Klik kanan "Inbound Rules" → New Rule
3. Rule Type: Port → Next
4. Protocol: TCP, Specific local port: 5433 → Next
5. Action: Allow the connection → Next
6. Profile: centang sesuai kebutuhan (Domain, Private, Public) → Next
7. Name: "PostgreSQL 17 - Port 5433" → Finish
8. (Opsional) Klik kanan rule baru → Properties → Scope
   → Remote IP: tambahkan subnet spesifik
```

**Hapus rule Windows Firewall:**

```powershell
Remove-NetFirewallRule -DisplayName "PostgreSQL 17 - Port 5433"
```

---

## 7. Troubleshooting Umum

### 7.1 Lokasi File Log PostgreSQL

| Platform | Path Log |
|---|---|
| Ubuntu 24.04 | `/var/log/postgresql/postgresql-17-main.log` |
| Rocky Linux 9 | `/var/lib/pgsql/17/data/log/` (format: `postgresql-YYYY-MM-DD_HHMMSS.log`) |
| Windows | `D:\PostgreSQL\17\data\log\` (format: `postgresql-YYYY-MM-DD_HHMMSS.log`) |

**Cara membaca log secara real-time:**

```bash
# Ubuntu — tail log aktif
sudo tail -f /var/log/postgresql/postgresql-17-main.log

# Rocky Linux — tail log terbaru
sudo tail -f /var/lib/pgsql/17/data/log/$(ls -t /var/lib/pgsql/17/data/log/ | head -1)

# Atau menggunakan journald (semua distro)
sudo journalctl -u postgresql@17-main -f    # Ubuntu
sudo journalctl -u postgresql-17 -f         # Rocky Linux
```

### 7.2 Error: "Failed to bind to port"

**Gejala:**

```
FATAL: could not bind IPv4 address "0.0.0.0": Address already in use
LOG: could not bind to port 5433
```

**Penyebab & Solusi:**

```bash
# Cek proses mana yang menggunakan port 5433
sudo ss -tlnp | grep 5433
# Atau:
sudo lsof -i :5433

# Jika ada instance PostgreSQL lain yang jalan:
sudo systemctl stop postgresql@16-main   # stop versi lain
# Atau ubah port di postgresql.conf ke port berbeda

# Windows:
netstat -ano | findstr :5433
# Cari PID, lalu:
tasklist | findstr <PID>
# Kill proses jika diperlukan:
taskkill /PID <PID> /F
```

**Checklist:**

- Pastikan tidak ada dua instance PostgreSQL berjalan dengan port yang sama
- Pastikan nilai `port` di `postgresql.conf` sudah di-save dan service di-restart
- Cek apakah ada aplikasi lain (pgAdmin, dll.) yang menggunakan port tersebut

### 7.3 Error: "Ident authentication failed"

**Gejala:**

```
FATAL: Ident authentication failed for user "postgres"
# Atau:
FATAL: peer authentication failed for user "myuser"
```

**Penyebab:** Koneksi via TCP ke `localhost` tapi `pg_hba.conf` menggunakan metode `ident` atau `peer` (yang hanya valid untuk koneksi Unix socket).

**Solusi — Edit `pg_hba.conf`:**

```bash
sudo nano /etc/postgresql/17/main/pg_hba.conf
```

Cari baris yang mirip ini:

```ini
# SEBELUM (penyebab error):
host    all     all     127.0.0.1/32    ident

# SESUDAH (ubah metode):
host    all     all     127.0.0.1/32    scram-sha-256
```

```bash
# Reload konfigurasi (tidak perlu full restart)
sudo systemctl reload postgresql@17-main   # Ubuntu
sudo systemctl reload postgresql-17         # Rocky Linux
```

### 7.4 Error: "Connection refused" dari Host Remote

**Checklist diagnostik:**

```bash
# 1. Cek listen_addresses di postgresql.conf (harus '*' atau IP spesifik, bukan 'localhost')
sudo grep -E "^listen_addresses|^#listen_addresses" /etc/postgresql/17/main/postgresql.conf

# 2. Cek port yang aktif
sudo ss -tlnp | grep 5433

# 3. Cek pg_hba.conf (harus ada baris yang mengizinkan IP klien)
sudo grep -v "^#\|^$" /etc/postgresql/17/main/pg_hba.conf

# 4. Cek firewall (UFW)
sudo ufw status

# 5. Test koneksi dari server itu sendiri dulu
psql -h 127.0.0.1 -p 5433 -U postgres -W

# 6. Test koneksi dari mesin remote (jalankan di mesin klien)
# (install postgresql-client jika belum ada)
psql -h <SERVER_IP> -p 5433 -U postgres -W

# 7. Test port terbuka dari klien (tanpa psql)
telnet <SERVER_IP> 5433
# Atau:
nc -zv <SERVER_IP> 5433
```

### 7.5 Cek Konfigurasi Aktif dari dalam psql

```sql
-- Cek port yang sedang berjalan
SHOW port;

-- Cek listen_addresses aktif
SHOW listen_addresses;

-- Cek direktori data
SHOW data_directory;

-- Cek lokasi file konfigurasi
SHOW config_file;
SHOW hba_file;

-- Reload pg_hba.conf tanpa restart (superuser only)
SELECT pg_reload_conf();
```

---

## Referensi Cepat — Cheat Sheet

### Path Kritis per Platform

| Item | Ubuntu 24.04 | Rocky Linux 9 | Windows |
|---|---|---|---|
| Binary | `/usr/lib/postgresql/17/bin/` | `/usr/pgsql-17/bin/` | `C:\Program Files\PostgreSQL\17\bin\` |
| Data Dir | `/var/lib/postgresql/17/main/` | `/var/lib/pgsql/17/data/` | `D:\PostgreSQL\17\data\` |
| Config | `/etc/postgresql/17/main/` | `/var/lib/pgsql/17/data/` | `D:\PostgreSQL\17\data\` |
| Log | `/var/log/postgresql/` | `/var/lib/pgsql/17/data/log/` | `D:\PostgreSQL\17\data\log\` |
| Service Name | `postgresql@17-main` | `postgresql-17` | `postgresql-x64-17` |

### Urutan Perubahan Konfigurasi (Checklist)

```
[ ] 1. Edit postgresql.conf → ubah port & listen_addresses
[ ] 2. Edit pg_hba.conf → tambah/ubah baris akses & metode auth
[ ] 3. Restart/reload service PostgreSQL
[ ] 4. Buka port baru di Firewall (UFW / Firewalld / Windows Firewall)
[ ] 5. Tutup port lama di Firewall (jika ganti port)
[ ] 6. Verifikasi port LISTEN dengan ss/netstat
[ ] 7. Test koneksi lokal dulu, lalu dari remote
[ ] 8. Cek log jika ada error
```

---

*Dokumen ini dibuat untuk PostgreSQL 16/17 pada Ubuntu 24.04 LTS, Rocky Linux 9, Windows 11/Server.*
*Selalu rujuk ke [dokumentasi resmi PostgreSQL](https://www.postgresql.org/docs/) untuk perubahan parameter yang lebih mendalam.*
