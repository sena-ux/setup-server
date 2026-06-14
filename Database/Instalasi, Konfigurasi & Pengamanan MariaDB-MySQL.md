# Panduan Komprehensif DBA: Instalasi, Konfigurasi & Pengamanan MariaDB / MySQL

> **Dibuat oleh:** Senior Database Administrator & Systems Engineer
> **Versi Panduan:** 1.0
> **Target Platform:** Ubuntu Server 24.04 LTS · Debian 12 (Bookworm) · Windows Server 2022 / Windows 11
> **Engine:** MariaDB 10.11+ / MySQL 8.0+

---

## Daftar Isi

1. [Arsitektur Sistem & Konsep Dasar](#1-arsitektur-sistem--konsep-dasar)
2. [Instalasi di Ubuntu Server 24.04 LTS](#2-instalasi-di-ubuntu-server-2404-lts)
3. [Instalasi di Debian 12 (Bookworm)](#3-instalasi-di-debian-12-bookworm)
4. [Instalasi di Windows Server 2022 / Windows 11](#4-instalasi-di-windows-server-2022--windows-11)
5. [Pembedahan Mendalam: `mysql_secure_installation`](#5-pembedahan-mendalam-mysql_secure_installation)
6. [Konfigurasi Lanjutan: Port, bind-address & Jaringan](#6-konfigurasi-lanjutan-port-bind-address--jaringan)
7. [Manajemen Service](#7-manajemen-service)
8. [Rangkuman Best Practice Keamanan](#8-rangkuman-best-practice-keamanan)

---

## 1. Arsitektur Sistem & Konsep Dasar

### 1.1 Komponen Utama

| Komponen | Deskripsi |
|---|---|
| **mysqld / mariadbd** | Proses daemon utama yang menerima dan memproses query |
| **my.cnf / my.ini** | File konfigurasi utama (Linux: `/etc/mysql/my.cnf`, Windows: `C:\ProgramData\MySQL\...`) |
| **Data Directory** | Direktori penyimpanan file database (default: `/var/lib/mysql`) |
| **Socket File** | File komunikasi Unix IPC (default: `/var/run/mysqld/mysqld.sock`) |
| **Error Log** | Log utama daemon (`/var/log/mysql/error.log`) |
| **Binary Log (binlog)** | Log perubahan data, digunakan untuk replikasi & point-in-time recovery |

### 1.2 Port & Protokol

| Port | Protokol | Fungsi |
|---|---|---|
| **3306** | TCP | Port default MySQL/MariaDB untuk koneksi jaringan |
| **33060** | TCP | MySQL X Protocol (MySQL Shell, MySQL Router) — MySQL 8.0+ |
| **Unix Socket** | IPC | Komunikasi lokal super-cepat, bypass TCP stack |

> **Catatan Keamanan:** Port 3306 adalah port yang paling sering diprobing oleh attacker di internet. Mengganti ke port non-standar adalah **security through obscurity** — bukan pengganti firewall, tetapi mengurangi noise dari automated scanners.

### 1.3 Model Autentikasi Linux vs. MySQL

Ini adalah konsep **paling krusial** yang sering disalahpahami:

```
┌──────────────────────────────────────────────────────────────┐
│                    DUA LAPISAN KEAMANAN                       │
│                                                              │
│  Layer 1: OS / Linux Authentication                          │
│  ┌─────────────────────────────────────────────────────┐     │
│  │  User: root (UID 0)                                 │     │
│  │  Auth: /etc/shadow (password Linux)                 │     │
│  │  Plugin: unix_socket / auth_socket                  │     │
│  │  → Login via: sudo mysql                            │     │
│  └─────────────────────────────────────────────────────┘     │
│                          ↓                                    │
│  Layer 2: MySQL / MariaDB Authentication                     │
│  ┌─────────────────────────────────────────────────────┐     │
│  │  User: root@localhost (dalam tabel mysql.user)      │     │
│  │  Auth: password hash (mysql_native_password / SHA2) │     │
│  │  → Login via: mysql -u root -p                      │     │
│  └─────────────────────────────────────────────────────┘     │
└──────────────────────────────────────────────────────────────┘
```

Pemahaman dua lapisan ini adalah kunci untuk memahami seluruh proses `mysql_secure_installation`.

---

## 2. Instalasi di Ubuntu Server 24.04 LTS

### 2.1 Instalasi MariaDB

```bash
# Langkah 1: Update package index
sudo apt update && sudo apt upgrade -y

# Langkah 2: Install MariaDB Server
sudo apt install mariadb-server mariadb-client -y

# Langkah 3: Verifikasi versi
mariadb --version
# Output contoh: mariadb  Ver 15.1 Distrib 10.11.x-MariaDB

# Langkah 4: Cek status service (seharusnya sudah aktif otomatis)
sudo systemctl status mariadb
```

### 2.2 Instalasi MySQL 8.0 (via Official Repository)

```bash
# Langkah 1: Download MySQL APT Config Package
wget https://dev.mysql.com/get/mysql-apt-config_0.8.30-1_all.deb

# Langkah 2: Install package konfigurasi repo
sudo dpkg -i mysql-apt-config_0.8.30-1_all.deb
# Akan muncul dialog TUI — pilih "MySQL Server & Cluster" → "mysql-8.0" → OK

# Langkah 3: Update dan install
sudo apt update
sudo apt install mysql-server -y

# Langkah 4: Verifikasi
mysql --version
# Output contoh: mysql  Ver 8.0.x for Linux on x86_64 (MySQL Community Server - GPL)

# Langkah 5: Cek status
sudo systemctl status mysql
```

### 2.3 Lokasi File Penting (Ubuntu)

| File / Direktori | Path |
|---|---|
| **Konfigurasi utama** | `/etc/mysql/my.cnf` |
| **Konfigurasi MariaDB** | `/etc/mysql/mariadb.conf.d/50-server.cnf` |
| **Konfigurasi MySQL** | `/etc/mysql/mysql.conf.d/mysqld.cnf` |
| **Data directory** | `/var/lib/mysql/` |
| **Error log** | `/var/log/mysql/error.log` |
| **Socket file** | `/var/run/mysqld/mysqld.sock` |
| **PID file** | `/var/run/mysqld/mysqld.pid` |

---

## 3. Instalasi di Debian 12 (Bookworm)

### 3.1 Instalasi MariaDB

```bash
# Langkah 1: Install dependensi dan import GPG key MariaDB
sudo apt install apt-transport-https curl -y
sudo mkdir -p /etc/apt/keyrings
curl -o /etc/apt/keyrings/mariadb-keyring.pgp \
  'https://mariadb.org/mariadb_release_signing_key.pgp'

# Langkah 2: Tambahkan repository resmi MariaDB
# Untuk MariaDB 10.11 LTS di Debian 12
cat <<EOF | sudo tee /etc/apt/sources.list.d/mariadb.sources
# MariaDB 10.11 repository list - created 2024-01-01
# https://mariadb.org/download/
X-Repolib-Name: MariaDB
Types: deb
URIs: https://downloads.mariadb.com/MariaDB/mariadb-10.11/repo/debian
Suites: bookworm
Components: main
Signed-By: /etc/apt/keyrings/mariadb-keyring.pgp
EOF

# Langkah 3: Install
sudo apt update
sudo apt install mariadb-server mariadb-client -y

# Langkah 4: Aktifkan dan start service
sudo systemctl enable --now mariadb
sudo systemctl status mariadb
```

### 3.2 Instalasi MySQL di Debian 12

```bash
# Langkah 1: Download MySQL APT Config
wget https://dev.mysql.com/get/mysql-apt-config_0.8.30-1_all.deb
sudo dpkg -i mysql-apt-config_0.8.30-1_all.deb

# Langkah 2: Pada dialog pilih MySQL 8.0
sudo apt update
sudo apt install mysql-server -y

# Langkah 3: Enable dan start
sudo systemctl enable --now mysql
```

> **Catatan Debian vs Ubuntu:** Debian menggunakan repositori yang lebih konservatif. Selalu gunakan **official MariaDB Foundation repository** atau **MySQL official APT repository** untuk mendapatkan versi terbaru yang didukung penuh.

---

## 4. Instalasi di Windows Server 2022 / Windows 11

### 4.1 Instalasi MariaDB via MSI

**Langkah 1: Download**
- Buka: https://mariadb.org/download/
- Pilih: **Windows** → **x86_64** → **MSI Package**

**Langkah 2: Jalankan Installer**
```
1. Klik Next pada welcome screen
2. Setujui License Agreement
3. Pilih komponen:
   ✓ MariaDB Server
   ✓ HeidiSQL (opsional, client GUI)
   ✓ MariaDB Command Line Client
4. Konfigurasi:
   - Set root password
   - ✓ Install as service
   - Service Name: MySQL (default, untuk kompatibilitas)
   - ✓ Enable networking
   - Port: 3306 (atau custom)
   - Character Set: utf8mb4
```

**Langkah 3: Verifikasi via PowerShell**
```powershell
# Cek status service
Get-Service -Name MySQL

# Cek apakah port 3306 listening
netstat -an | findstr "3306"

# Login ke MariaDB
mysql -u root -p
```

### 4.2 Instalasi MySQL 8.0 via MSI

**Langkah 1: Download MySQL Installer**
- Buka: https://dev.mysql.com/downloads/installer/
- Pilih: **mysql-installer-community-8.0.x.msi**

**Langkah 2: Setup Type**
```
Pilih: "Server only" (untuk server produksi)
atau
Pilih: "Custom" untuk kontrol penuh atas komponen
```

**Langkah 3: Konfigurasi via MySQL Installer**
```
Type and Networking:
  - Config Type: Server Computer
  - Connectivity: ✓ TCP/IP, Port: 3306
  - ✓ Open Windows Firewall port (hati-hati di produksi!)

Authentication Method:
  - PILIH: "Use Strong Password Encryption" (caching_sha2_password)
  - Hindari mode kompatibilitas kecuali ada legacy client

Accounts and Roles:
  - Set MySQL Root Password: [gunakan password kuat]
  - Add MySQL User Accounts jika diperlukan

Windows Service:
  - ✓ Configure MySQL Server as a Windows Service
  - Service Name: MySQL80
  - ✓ Start the MySQL Server at System Startup
```

### 4.3 Lokasi File Penting (Windows)

| File / Direktori | Path |
|---|---|
| **Konfigurasi (my.ini)** | `C:\ProgramData\MySQL\MySQL Server 8.0\my.ini` |
| **Data directory** | `C:\ProgramData\MySQL\MySQL Server 8.0\Data\` |
| **Error log** | `C:\ProgramData\MySQL\MySQL Server 8.0\Data\<hostname>.err` |
| **MySQL binaries** | `C:\Program Files\MySQL\MySQL Server 8.0\bin\` |
| **MariaDB binaries** | `C:\Program Files\MariaDB 10.11\bin\` |

### 4.4 Tambahkan MySQL ke PATH (Windows)

```powershell
# Via PowerShell (Administrator)
$mysqlPath = "C:\Program Files\MySQL\MySQL Server 8.0\bin"
[Environment]::SetEnvironmentVariable("Path",
  $env:Path + ";$mysqlPath",
  [EnvironmentVariableTarget]::Machine)

# Restart terminal, lalu verifikasi
mysql --version
```

---

## 5. Pembedahan Mendalam: `mysql_secure_installation`

Script ini adalah **wizard interaktif** yang mengotomatiskan serangkaian operasi SQL keamanan. Jalankan setelah instalasi selesai:

```bash
sudo mysql_secure_installation
```

Berikut adalah pembedahan **baris per baris** dari setiap prompt yang akan muncul:

---

### 5.1 Prompt Pertama: Password Root Saat Ini

```
NOTE: RUNNING ALL PARTS OF THIS SCRIPT IS RECOMMENDED FOR ALL MariaDB
      SERVERS IN PRODUCTION USE!  PLEASE READ EACH STEP CAREFULLY!

In order to log into MariaDB to secure it, we'll need the current
password for the root user. If you've just installed MariaDB, and
haven't set the root password yet, you just press enter here.

Enter current password for root (enter for none):
OK, successfully used password, moving on...
```

#### Apa yang Sebenarnya Terjadi?

Script ini mencoba login ke MySQL/MariaDB sebagai root **sebelum** melakukan perubahan apapun. Ini adalah **mekanisme verifikasi akses** — script tidak bisa mengubah keamanan database jika ia sendiri tidak punya akses.

**Skenario A: Instalasi Baru (Fresh Install) — Tekan Enter**

Pada instalasi baru MariaDB di Ubuntu/Debian, user root MySQL **belum memiliki password**. Lebih tepatnya, root menggunakan plugin `unix_socket` atau `auth_socket`, yang berarti:

```sql
-- Kondisi awal di tabel mysql.user:
SELECT user, host, plugin, authentication_string
FROM mysql.user
WHERE user = 'root';

-- Output tipikal:
-- +------+-----------+-------------+-----------------------+
-- | user | host      | plugin      | authentication_string |
-- +------+-----------+-------------+-----------------------+
-- | root | localhost | unix_socket | (kosong)              |
-- +------+-----------+-------------+-----------------------+
```

Karena script dijalankan dengan `sudo`, proses berjalan sebagai user Linux `root`, dan plugin `unix_socket` mengizinkan login **tanpa password** ketika OS user-nya adalah root. Maka menekan Enter pun berhasil.

**Skenario B: Instalasi Lama / Re-run Script**

Jika root MySQL sudah punya password (dari setup sebelumnya), kamu **wajib** memasukkan password tersebut di sini. Salah memasukkan = script berhenti dan keluar dengan error.

**Skenario C: MySQL 8.0 dengan `caching_sha2_password`**

MySQL 8.0 menggunakan plugin `caching_sha2_password` secara default. Pada fresh install, password root **diset** selama proses instalasi (via wizard atau `--initialize`), sehingga kamu harus memasukkannya di sini.

**Implikasi Teknis:**
```
Tekan Enter (no password) → Script login sukses via unix_socket
Memasukkan password benar → Script login sukses via password auth
Memasukkan password salah → Access denied, script EXIT(1)
```

---

### 5.2 Prompt Kedua: Switch to unix_socket Authentication

```
Setting the root password or using the unix_socket ensures that nobody
can log into the MariaDB root user without the proper authorisation.

You already have your root account protected, so you can safely answer 'n'.

Switch to unix_socket authentication [Y/n] n
 ... skipping.
```

#### Apa itu unix_socket Authentication?

`unix_socket` (disebut juga `auth_socket` di MySQL) adalah plugin autentikasi yang **memverifikasi identitas user berdasarkan user OS yang sedang berjalan**, bukan berdasarkan password database.

**Cara Kerjanya:**

```
┌─────────────────────────────────────────────────────────────┐
│              unix_socket Authentication Flow                  │
│                                                             │
│  1. User Linux "john" menjalankan: mysql -u root            │
│                                       ↓                     │
│  2. MySQL membaca UID dari socket connection                 │
│     (via getsockopt SO_PEERCRED di kernel)                  │
│                                       ↓                     │
│  3. MySQL bertanya pada OS: "Siapa pemilik socket ini?"     │
│     OS menjawab: "UID 1001 = user john"                     │
│                                       ↓                     │
│  4. MySQL cek: apakah "john" == "root"? → TIDAK             │
│     → Access DENIED                                         │
│                                                             │
│  5. Jika dijalankan sebagai: sudo mysql                     │
│     OS menjawab: "UID 0 = user root"                        │
│     MySQL cek: apakah "root" == "root"? → IYA               │
│     → Access GRANTED (tanpa password!)                      │
└─────────────────────────────────────────────────────────────┘
```

**Konsekuensi Teknis Memilih Y (Aktifkan unix_socket):**

```bash
# Setelah memilih Y, tabel mysql.user akan berisi:
# plugin = 'unix_socket', authentication_string = ''

# Cara LOGIN yang BERHASIL:
sudo mysql                     # ✓ Berhasil (sebagai Linux root)
sudo mysql -u root             # ✓ Berhasil
sudo mysql -u root --password  # ✗ Gagal! unix_socket tidak pakai password

# Cara LOGIN yang GAGAL:
mysql -u root -p               # ✗ Gagal (bukan Linux root)
mysql -u root -psecretpass     # ✗ Gagal (password diabaikan)

# Dari aplikasi web (PHP/Laravel):
# $pdo = new PDO('mysql:host=localhost', 'root', 'password');
# → ERROR: plugin unix_socket tidak mendukung koneksi PDO dengan password!
```

**Konsekuensi Teknis Memilih n (Tetap Gunakan Password):**

```bash
# Plugin tetap: mysql_native_password atau caching_sha2_password

# Cara LOGIN yang BERHASIL:
mysql -u root -p               # ✓ Berhasil dengan password yang benar
mysql -u root -psecretpass     # ✓ Berhasil (tidak disarankan di CLI, password tampil di history)
sudo mysql                     # ✗ Mungkin gagal jika unix_socket tidak diaktifkan

# Dari aplikasi:
# $pdo = new PDO('mysql:host=localhost', 'root', 'password');
# → Berhasil! ✓
```

**Kapan Memilih Y vs n?**

| Skenario | Pilihan | Alasan |
|---|---|---|
| Server produksi, DBA login via terminal | **Y** | Lebih aman, tidak ada password yang bisa bocor |
| Aplikasi web Laravel/PHP/Python butuh login root | **n** | Aplikasi butuh password eksplisit |
| Server development lokal | **n** | Lebih mudah untuk testing |
| Docker container | **n** | Container tidak punya unix socket yang persisten |

**Rekomendasi Best Practice:** Pilih **n** untuk unix_socket, lalu buat **dedicated user** (bukan root) untuk aplikasi. Root hanya diakses DBA via terminal.

---

### 5.3 Prompt Ketiga: Ganti Password Root

```
Change the root password? [Y/n] Y
New password:
Re-enter new password:
Password updated successfully!
Reloading privilege tables..
 ... Success!
```

#### Mengapa Ada Opsi Ini Jika Awal Sudah Ada Pengecekan Password?

Ini adalah pertanyaan yang sangat bagus dan sering membingungkan. **Jawabannya:** kedua prompt ini punya tujuan yang **berbeda secara fundamental**:

```
┌──────────────────────────────────────────────────────────────┐
│  Prompt #1: "Enter current password"                         │
│  Tujuan: VERIFIKASI (apakah kamu punya akses ke server ini?) │
│  Ini seperti "tunjukkan ID kamu"                             │
└──────────────────────────────────────────────────────────────┘
                          ≠ (berbeda)
┌──────────────────────────────────────────────────────────────┐
│  Prompt #3: "Change the root password?"                      │
│  Tujuan: PENETAPAN (set password baru yang kuat)             │
│  Ini seperti "buat PIN baru untuk akun kamu"                 │
└──────────────────────────────────────────────────────────────┘
```

**Skenario di mana perbedaan ini penting:**

```
Fresh install MariaDB → unix_socket aktif → root tidak punya password MySQL

Prompt #1: Kamu tekan Enter → Login sukses via unix_socket
           (Autentikasi OS berhasil, tapi password MySQL = kosong!)

Prompt #3: "Mau set password MySQL untuk root?"
           → Ini adalah kesempatan untuk MENAMBAHKAN password
             pada akun yang sebelumnya tidak punya password MySQL
```

**Operasi SQL yang dijalankan di balik layar:**

```sql
-- Untuk MariaDB:
UPDATE mysql.user
SET authentication_string = PASSWORD('newpassword'),
    plugin = 'mysql_native_password'
WHERE User = 'root' AND Host = 'localhost';

-- Untuk MySQL 8.0:
ALTER USER 'root'@'localhost'
IDENTIFIED WITH caching_sha2_password BY 'newpassword';

FLUSH PRIVILEGES;
```

**Kapan Harus Mendahulukan Autentikasi OS (unix_socket) vs Password Manual?**

| Situasi | Rekomendasi | Alasan |
|---|---|---|
| **Server yang hanya diakses via SSH** | unix_socket (Y di prompt #2, N di prompt #3) | Keamanan berlapis: SSH key + OS auth |
| **Server dengan banyak DBA** | Password manual | Setiap DBA bisa punya password berbeda |
| **Aplikasi butuh koneksi localhost** | Password manual untuk dedicated user | Aplikasi tidak bisa pakai unix_socket user |
| **Automation / CI/CD pipeline** | Password manual + limited privileges | Script butuh credentials eksplisit |
| **Setelah unix_socket dipilih di prompt #2** | Tidak perlu ganti password (pilih N) | unix_socket sudah proteksi root |

---

### 5.4 Prompt Keempat: Hapus Anonymous Users

```
Remove anonymous users? [Y/n] Y
 ... Success!
```

#### Apa itu Anonymous User di MariaDB/MySQL?

Anonymous user adalah **akun database tanpa nama** — literally user dengan `User = ''` (string kosong) di tabel `mysql.user`. Akun ini dibuat secara otomatis selama proses instalasi MySQL/MariaDB sebagai "kemudahan" untuk testing lokal.

**Lihat dengan mata kepala sendiri:**

```sql
-- Periksa apakah anonymous user ada:
SELECT user, host, plugin, authentication_string
FROM mysql.user
WHERE user = '';

-- Output pada instalasi fresh (SEBELUM secure_installation):
-- +------+-----------+-------------+-----------------------+
-- | user | host      | plugin      | authentication_string |
-- +------+-----------+-------------+-----------------------+
-- |      | localhost | (kosong)    | (kosong)              |
-- |      | hostname  | (kosong)    | (kosong)              |
-- +------+-----------+-------------+-----------------------+
```

**Bagaimana Anonymous User Bekerja:**

```bash
# Dengan anonymous user aktif, SIAPAPUN bisa login tanpa password:
mysql                           # ✓ Login sukses sebagai anonymous!
mysql -u ""                     # ✓ Login sukses sebagai anonymous!
mysql --user="" --password=""   # ✓ Login sukses sebagai anonymous!

# Privileges yang didapat anonymous user:
SHOW GRANTS FOR ''@'localhost';
-- GRANT USAGE ON *.* TO ''@'localhost'
-- (tapi bisa akses database 'test' tanpa batas!)
```

**Mengapa Berbahaya di Lingkungan Produksi:**

```
RISIKO 1: Unauthorized Access
→ Attacker yang berhasil mendapat akses ke OS bisa langsung login
  ke MySQL tanpa perlu tahu password apapun.
  Serangan: mysql -h localhost -u ""

RISIKO 2: Privilege Escalation via Database 'test'
→ Anonymous user secara default punya akses penuh ke database 'test'
  dan semua database yang namanya diawali 'test_'.
  SQL: CREATE TABLE test.pwned (cmd TEXT);
       LOAD DATA INFILE '/etc/passwd' INTO TABLE test.pwned;

RISIKO 3: Wildcard Matching Bug (Historical)
→ MySQL lama punya bug: jika ada user 'app'@'%' dan anonymous user ''@'localhost',
  login dari app@localhost bisa MATCH ke anonymous user dan bukan ke 'app' user!
  Ini menyebabkan koneksi aplikasi tiba-tiba gagal secara misterius.

RISIKO 4: Audit & Compliance Failure
→ Tidak bisa melacak siapa yang melakukan operasi database
  karena tidak ada identitas user yang tercatat di audit log.
```

**Operasi SQL yang dijalankan:**

```sql
-- Script menjalankan:
DELETE FROM mysql.user WHERE User = '';
FLUSH PRIVILEGES;
```

**Jawaban yang benar:** Selalu pilih **Y** di lingkungan produksi.

---

### 5.5 Prompt Kelima: Larang Root Login Remote

```
Normally, root should only be allowed to connect from 'localhost'. This
ensures that someone cannot guess at the root password from the network.

Disallow root login remotely? [Y/n] Y
 ... Success!
```

#### Mengapa Akses Root Remote Dilarang?

**Alasan Arsitektural:**

```
SERANGAN TIPIKAL TERHADAP DATABASE SERVER:

Internet → Port Scan → Temukan 3306 → Brute Force root@% 
→ Jika berhasil: FULL ACCESS ke seluruh database di server

Dengan root login remote DINONAKTIFKAN:
Internet → Port Scan → Temukan 3306 → Brute Force root@%
→ "Access denied for user 'root'@'[IP_ATTACKER]'"
→ Serangan GAGAL meskipun password tertebak!
```

**Perbedaan `root@localhost` vs `root@%`:**

```sql
-- root@localhost: HANYA bisa login dari mesin yang sama (via socket atau 127.0.0.1)
-- root@'%': Bisa login dari IP manapun di dunia

-- Apa yang script lakukan:
DELETE FROM mysql.user WHERE User = 'root' AND Host != 'localhost';
-- Atau lebih spesifik:
DELETE FROM mysql.user WHERE User = 'root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');

FLUSH PRIVILEGES;

-- Verifikasi setelah running:
SELECT user, host FROM mysql.user WHERE user = 'root';
-- Harus menampilkan HANYA:
-- +------+-----------+
-- | user | host      |
-- +------+-----------+
-- | root | localhost |
-- +------+-----------+
```

**Best Practice Jika Developer Tetap Butuh Akses Remote:**

Jangan pernah expose root ke remote! Gunakan salah satu dari pendekatan berikut:

**Opsi A: SSH Tunnel (Paling Aman)**
```bash
# Developer membuat SSH tunnel dari laptop:
ssh -L 3307:127.0.0.1:3306 user@server_ip -N -f
# Penjelasan: Port 3307 di laptop di-forward ke port 3306 di server
# (via koneksi SSH yang terenkripsi)

# Lalu developer konek ke:
mysql -h 127.0.0.1 -P 3307 -u dbadmin -p
# Traffic: Laptop:3307 → SSH Encrypted → Server:22 → MySQL:3306
# MySQL server hanya "melihat" koneksi dari localhost!
```

**Opsi B: Dedicated Remote User dengan Privilege Terbatas**
```sql
-- Buat user khusus, BUKAN root:
CREATE USER 'dbadmin'@'192.168.1.100' IDENTIFIED BY 'StrongP@ssw0rd!';

-- Berikan hanya privilege yang dibutuhkan:
GRANT SELECT, INSERT, UPDATE, DELETE ON myapp_db.* TO 'dbadmin'@'192.168.1.100';

-- JANGAN pernah:
-- GRANT ALL PRIVILEGES ON *.* TO 'dbadmin'@'%';  ← BERBAHAYA!

FLUSH PRIVILEGES;
```

**Opsi C: VPN (untuk Tim)**
```
Arsitektur:
Developer → VPN Client → VPN Server → Internal Network → Database Server
                                       (Private IP, tidak exposed ke internet)

Database server bind-address = IP internal VPN
Firewall: block port 3306 dari internet, izinkan dari VPN subnet saja
```

---

### 5.6 Prompt Keenam: Hapus Database 'test'

```
Remove test database and access to it? [Y/n] Y
 - Dropping test database...
 ... Success!
 - Removing privileges on test database...
 ... Success!
```

#### Apa Bahayanya Membiarkan Database 'test' Aktif?

Database `test` dibuat oleh MySQL/MariaDB installer sebagai sandbox untuk quick testing. **Masalahnya:**

**Bahaya 1: Anonymous User + Test Database = Backdoor**
```sql
-- Anonymous user secara default punya wildcard match untuk database 'test':
GRANT ALL PRIVILEGES ON `test`.* TO ''@'localhost';
GRANT ALL PRIVILEGES ON `test\_%`.* TO ''@'localhost';

-- Artinya:
-- test        → accessible oleh siapapun tanpa login!
-- test_myapp  → accessible oleh siapapun tanpa login!
-- test_backup → accessible oleh siapapun tanpa login!
```

**Bahaya 2: Penyalahgunaan sebagai Staging Area Serangan**
```sql
-- Attacker yang dapat akses anonymous bisa:
-- 1. Buat tabel di 'test' untuk menyimpan hasil eksfiltrasi data
CREATE TABLE test.stolen_data AS SELECT * FROM information_schema.tables;

-- 2. Gunakan sebagai tempat test exploit:
CREATE TABLE test.exploit_test (id INT AUTO_INCREMENT PRIMARY KEY, data TEXT);

-- 3. Kalau ada FILE privilege:
LOAD DATA INFILE '/etc/mysql/my.cnf' INTO TABLE test.config_leak;
```

**Bahaya 3: Resource Consumption**
```
Database 'test' tidak punya quota atau limit.
Siapapun (termasuk anonymous user) bisa:
→ INSERT jutaan baris → menghabiskan disk
→ Membuat tabel besar → I/O spikes
→ JOIN query kompleks → CPU spike (Denial of Service!)
```

**Bahaya 4: Compliance dan Data Governance**
```
Audit ISO 27001 / PCI-DSS akan mempertanyakan:
"Mengapa ada database tidak terproteksi di production server?"
Jawaban "itu cuma database test" tidak akan diterima.
```

**Operasi SQL yang dijalankan:**

```sql
-- Script menjalankan:
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db = 'test' OR Db = 'test\\_%';
FLUSH PRIVILEGES;
```

---

### 5.7 Prompt Ketujuh: Reload Privilege Tables

```
Reload privilege tables now? [Y/n] Y
 ... Success!

Cleaning up...

All done!  If you've set up a MySQL root password, make sure you remember it!
```

#### Apa Fungsi Reload Privilege Tables (FLUSH PRIVILEGES)?

Ini adalah langkah yang **paling sering disalahpahami** oleh DBA junior.

**Bagaimana MySQL/MariaDB Mengelola Privilege:**

```
┌────────────────────────────────────────────────────────────────┐
│                  MySQL Privilege Architecture                   │
│                                                                │
│  Disk Storage:                                                 │
│  ┌──────────────────────────────────┐                          │
│  │  mysql.user table (di disk)      │                          │
│  │  mysql.db table (di disk)        │  ← Perubahan via SQL     │
│  │  mysql.tables_priv (di disk)     │     langsung ke SINI     │
│  └──────────────────────────────────┘                          │
│                       ↓ (dibaca saat startup / FLUSH)          │
│  RAM (Grant Cache):                                            │
│  ┌──────────────────────────────────┐                          │
│  │  In-memory privilege cache       │                          │
│  │  (digunakan untuk setiap query)  │  ← MySQL baca dari SINI  │
│  │                                  │     saat auth check       │
│  └──────────────────────────────────┘                          │
└────────────────────────────────────────────────────────────────┘
```

**Mengapa FLUSH PRIVILEGES Diperlukan?**

```sql
-- Skenario tanpa FLUSH PRIVILEGES:
-- 1. Kamu update tabel mysql.user secara manual:
UPDATE mysql.user SET authentication_string = 'newpass' WHERE User = 'app';
-- Perubahan TERSIMPAN di disk (tabel mysql.user sudah diupdate)

-- 2. Tapi in-memory cache BELUM diperbarui!
-- 3. User 'app' masih bisa login dengan PASSWORD LAMA
--    sampai server di-restart atau FLUSH PRIVILEGES dijalankan

-- Solusi:
FLUSH PRIVILEGES;
-- Sekarang MySQL membaca ulang semua tabel privilege dari disk ke RAM
-- Perubahan LANGSUNG berlaku!
```

**Kapan FLUSH PRIVILEGES Diperlukan (dan Kapan Tidak):**

```sql
-- ✓ PERLU FLUSH PRIVILEGES:
-- Saat memodifikasi tabel mysql.user secara langsung:
UPDATE mysql.user SET ... WHERE ...;
DELETE FROM mysql.user WHERE ...;
INSERT INTO mysql.user VALUES ...;

-- ✗ TIDAK PERLU FLUSH PRIVILEGES:
-- Saat menggunakan statement DCL standar (sudah auto-flush):
CREATE USER ...;             -- Auto-flush ✓
DROP USER ...;               -- Auto-flush ✓
GRANT ... TO ...;            -- Auto-flush ✓
REVOKE ... FROM ...;         -- Auto-flush ✓
ALTER USER ...;              -- Auto-flush ✓
SET PASSWORD FOR ...;        -- Auto-flush ✓
```

**Jadi Mengapa Script Ini Memanggil FLUSH PRIVILEGES di Akhir?**

Karena `mysql_secure_installation` kemungkinan memodifikasi tabel `mysql.user` **secara langsung via UPDATE/DELETE** (bukan via statement DCL), sehingga memerlukan FLUSH eksplisit di akhir untuk memastikan **semua perubahan berlaku** dalam satu transaksi operasional yang atomic.

---

## 6. Konfigurasi Lanjutan: Port, bind-address & Jaringan

### 6.1 Menemukan File Konfigurasi

```bash
# Linux: Cek konfigurasi mana yang dibaca
mysqld --verbose --help 2>/dev/null | grep -A 1 "Default options"
# Output: /etc/my.cnf /etc/mysql/my.cnf ~/.my.cnf

# Atau cek langsung:
mysql --help | grep "Default options" -A 1

# Windows: Cek registry atau gunakan default path
# HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\MySQL\ImagePath
```

### 6.2 Mengubah Port Default ke Port Kustom

**Linux — Edit `/etc/mysql/mariadb.conf.d/50-server.cnf` (MariaDB) atau `/etc/mysql/mysql.conf.d/mysqld.cnf` (MySQL):**

```ini
[mysqld]
# ============================================================
# PORT CONFIGURATION
# Default: 3306 — Ubah ke port non-standar untuk obscurity
# Pilihan umum: 3307, 3308, 33060, atau port acak di range 10000-65535
# ============================================================
port = 33306
```

**Windows — Edit `C:\ProgramData\MySQL\MySQL Server 8.0\my.ini`:**

```ini
[mysqld]
# Port baru
port=33306
```

**Setelah mengubah port:**

```bash
# Linux: Restart service
sudo systemctl restart mariadb   # atau mysql

# Verifikasi port baru aktif:
sudo ss -tlnp | grep 33306
# atau
sudo netstat -tlnp | grep 33306

# Update firewall (UFW):
sudo ufw allow 33306/tcp comment "MariaDB custom port"
sudo ufw deny 3306/tcp comment "Block default MySQL port"

# Koneksi dengan port baru:
mysql -h localhost -P 33306 -u root -p
```

```powershell
# Windows: Restart service via PowerShell (Administrator)
Restart-Service -Name "MySQL"

# Verifikasi port
netstat -an | findstr "33306"

# Buka port di Windows Firewall:
New-NetFirewallRule -DisplayName "MySQL Custom Port" `
  -Direction Inbound -Protocol TCP `
  -LocalPort 33306 -Action Allow

# Blokir port default:
New-NetFirewallRule -DisplayName "Block MySQL Default Port" `
  -Direction Inbound -Protocol TCP `
  -LocalPort 3306 -Action Block
```

### 6.3 Konfigurasi `bind-address`

`bind-address` menentukan **interface jaringan mana** yang didengarkan oleh MySQL/MariaDB. Ini adalah **kontrol keamanan jaringan pertama** sebelum firewall.

```ini
# ============================================================
# BIND-ADDRESS CONFIGURATION
# ============================================================

[mysqld]

# OPSI 1: Hanya loopback — Paling aman (default di banyak distro)
# Database TIDAK bisa diakses dari luar server sama sekali
bind-address = 127.0.0.1

# OPSI 2: Semua interface — Untuk server yang perlu remote access
# BAHAYA jika firewall tidak dikonfigurasi dengan benar!
bind-address = 0.0.0.0

# OPSI 3: IP spesifik — Best practice untuk production remote access
# Hanya interface dengan IP 192.168.10.50 yang mendengarkan
bind-address = 192.168.10.50

# OPSI 4: Multiple bind addresses (MariaDB 10.3.3+ / MySQL 8.0+)
# Mendengarkan di loopback DAN satu IP internal
bind-address = 127.0.0.1
bind-address = 10.10.0.5

# OPSI 5: Unix socket saja (tanpa TCP sama sekali — ultra-secure)
# bind-address tidak diset, matikan networking:
# skip-networking = 1  ← Aktifkan ini untuk local-only mode
```

### 6.4 Skenario Lengkap: Production Server Setup

**Skenario:** Database server dengan IP `10.0.1.10`, menerima koneksi dari application server `10.0.1.20`.

```ini
# /etc/mysql/mariadb.conf.d/50-server.cnf

[mysqld]
# ── Network ──────────────────────────────────────────────────
user                    = mysql
pid-file                = /run/mysqld/mysqld.pid
socket                  = /run/mysqld/mysqld.sock
port                    = 33306
bind-address            = 10.0.1.10

# ── General ──────────────────────────────────────────────────
basedir                 = /usr
datadir                 = /var/lib/mysql
tmpdir                  = /tmp
lc-messages-dir         = /usr/share/mysql
lc-messages             = en_US
skip-external-locking

# ── Character Set ─────────────────────────────────────────────
character-set-server    = utf8mb4
collation-server        = utf8mb4_unicode_ci

# ── Security ──────────────────────────────────────────────────
# Larang load file dari filesystem (cegah LOAD DATA INFILE eksploitasi)
local-infile            = 0
# Sembunyikan versi MySQL dari client yang tidak terautentikasi
# (uncomment jika MariaDB mendukung):
# version_comment        = ""

# ── InnoDB ───────────────────────────────────────────────────
innodb_buffer_pool_size = 1G
innodb_log_file_size    = 256M
innodb_flush_log_at_trx_commit = 1
innodb_file_per_table   = ON

# ── Logging ───────────────────────────────────────────────────
log_error               = /var/log/mysql/error.log
# General query log (matikan di produksi, sangat verbose!):
# general_log            = 0
# general_log_file       = /var/log/mysql/general.log
# Slow query log:
slow_query_log          = 1
slow_query_log_file     = /var/log/mysql/slow.log
long_query_time         = 2

# ── Binary Log (untuk Replikasi / PITR) ───────────────────────
log_bin                 = /var/log/mysql/mysql-bin.log
expire_logs_days        = 7
max_binlog_size         = 100M
binlog_format           = ROW
```

**Buat user database untuk application server:**

```sql
-- Masuk sebagai root:
sudo mysql

-- Buat user yang hanya bisa konek dari IP app server:
CREATE USER 'appuser'@'10.0.1.20'
  IDENTIFIED BY 'Str0ng#P@ssword2024!'
  PASSWORD EXPIRE INTERVAL 90 DAY;

-- Berikan hanya privilege yang dibutuhkan (principle of least privilege):
GRANT SELECT, INSERT, UPDATE, DELETE
  ON myapp_database.*
  TO 'appuser'@'10.0.1.20';

-- Verifikasi:
SHOW GRANTS FOR 'appuser'@'10.0.1.20';

FLUSH PRIVILEGES;
```

**Konfigurasi Firewall UFW:**

```bash
# Izinkan hanya dari IP application server:
sudo ufw allow from 10.0.1.20 to any port 33306 proto tcp \
  comment "Allow app server to MariaDB"

# Blokir akses dari semua IP lain:
sudo ufw deny 33306/tcp comment "Block MariaDB from all others"

# Aktifkan UFW jika belum:
sudo ufw enable

# Verifikasi rules:
sudo ufw status numbered
```

---

## 7. Manajemen Service

### 7.1 Linux — systemd

**MariaDB:**

```bash
# ── START / STOP / RESTART ────────────────────────────────────
sudo systemctl start mariadb      # Mulai service
sudo systemctl stop mariadb       # Hentikan service (graceful shutdown)
sudo systemctl restart mariadb    # Restart (stop + start)
sudo systemctl reload mariadb     # Reload konfigurasi TANPA restart
                                   # (tidak semua perubahan bisa di-reload)

# ── ENABLE / DISABLE (Auto-start saat boot) ───────────────────
sudo systemctl enable mariadb     # Aktifkan auto-start
sudo systemctl disable mariadb    # Nonaktifkan auto-start
sudo systemctl enable --now mariadb  # Enable + langsung start

# ── STATUS & MONITORING ───────────────────────────────────────
sudo systemctl status mariadb     # Status singkat + beberapa baris log terakhir
sudo journalctl -u mariadb -f     # Tail log real-time (follow mode)
sudo journalctl -u mariadb --since "1 hour ago"  # Log 1 jam terakhir
sudo journalctl -u mariadb -n 50  # 50 baris log terakhir

# ── VERIFIKASI KONEKSI ────────────────────────────────────────
sudo mysqladmin ping              # Cek apakah server merespons
sudo mysqladmin status            # Status singkat (uptime, threads, dll)
sudo mysqladmin -u root -p processlist  # Lihat query yang sedang berjalan
```

**MySQL:**

```bash
# Sama dengan di atas, ganti 'mariadb' dengan 'mysql':
sudo systemctl start mysql
sudo systemctl stop mysql
sudo systemctl restart mysql
sudo systemctl status mysql
sudo journalctl -u mysql -f
```

**Tips Tambahan systemd:**

```bash
# Cek apakah service akan auto-start saat boot:
sudo systemctl is-enabled mariadb

# Cek apakah service sedang aktif:
sudo systemctl is-active mariadb

# Lihat dependency tree service:
sudo systemctl list-dependencies mariadb

# Cek unit file konfigurasi systemd:
sudo systemctl cat mariadb

# Override systemd unit (misalnya untuk ubah timeout):
sudo systemctl edit mariadb
# Ini membuat /etc/systemd/system/mariadb.service.d/override.conf
```

### 7.2 Windows — Services Management

**Via PowerShell (Administrator):**

```powershell
# ── START / STOP / RESTART ────────────────────────────────────
# MariaDB (nama service mungkin 'MySQL' jika diinstall dengan nama default):
Start-Service -Name "MySQL"
Stop-Service -Name "MySQL"
Restart-Service -Name "MySQL"

# MySQL:
Start-Service -Name "MySQL80"
Stop-Service -Name "MySQL80"
Restart-Service -Name "MySQL80"

# ── ENABLE / DISABLE AUTO-START ───────────────────────────────
# Set startup type ke Automatic (auto-start saat boot):
Set-Service -Name "MySQL80" -StartupType Automatic

# Set startup type ke Manual (tidak auto-start):
Set-Service -Name "MySQL80" -StartupType Manual

# Disable service:
Set-Service -Name "MySQL80" -StartupType Disabled

# ── STATUS ────────────────────────────────────────────────────
Get-Service -Name "MySQL80"
Get-Service -Name "MySQL*"   # Lihat semua service yang mengandung "MySQL"

# Status detail:
Get-Service -Name "MySQL80" | Select-Object *

# ── MONITORING ────────────────────────────────────────────────
# Lihat Event Log untuk MySQL:
Get-EventLog -LogName Application -Source "MySQL" -Newest 20

# Atau via Event Viewer (GUI):
eventvwr.msc
# → Windows Logs → Application → filter Source = MySQL
```

**Via Services.msc (GUI):**

```
1. Tekan Win + R → ketik "services.msc" → Enter
2. Scroll ke bawah cari "MySQL" atau "MySQL80"
3. Klik kanan → pilih:
   - Start          → Menjalankan service
   - Stop           → Menghentikan service
   - Restart        → Restart service
   - Properties     → Konfigurasi:
     * General tab  → Startup type: Automatic / Manual / Disabled
     * Log On tab   → Account yang menjalankan service
     * Recovery tab → Tindakan saat service crash (restart otomatis)
```

**Via mysqladmin (cross-platform):**

```powershell
# Windows PowerShell:
# Cek apakah server merespons:
& "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysqladmin.exe" -u root -p ping

# Shutdown server dengan graceful:
& "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysqladmin.exe" -u root -p shutdown
```

---

## 8. Rangkuman Best Practice Keamanan

### Checklist Post-Instalasi

```
□ Jalankan mysql_secure_installation setelah instalasi
□ Hapus anonymous users (Y)
□ Larang root login remote (Y)
□ Hapus database test (Y)
□ Set password root yang kuat (minimal 16 karakter, mix huruf/angka/simbol)
□ Ganti port default 3306 ke port non-standar
□ Set bind-address ke IP spesifik (bukan 0.0.0.0 kecuali dibutuhkan)
□ Konfigurasi firewall: hanya izinkan IP yang dibutuhkan
□ Buat dedicated user per-aplikasi (BUKAN root untuk aplikasi)
□ Terapkan principle of least privilege pada semua user
□ Aktifkan slow query log untuk monitoring performa
□ Set local-infile = 0 untuk mencegah eksploitasi LOAD DATA
□ Aktifkan binary logging untuk disaster recovery
□ Setup monitoring dan alerting untuk koneksi yang gagal
□ Review secara berkala: SHOW GRANTS FOR user; SELECT * FROM mysql.user;
```

### Hierarki Keamanan Database

```
Level 1 (Terluar): Firewall / Network Perimeter
  → Hanya port yang diperlukan yang terbuka
  → Whitelist IP yang diizinkan

Level 2: OS & Service Hardening
  → Jalankan mysqld sebagai user 'mysql' (bukan root OS)
  → File permission yang ketat pada data directory
  → SE Linux / AppArmor profile untuk mysqld

Level 3: MySQL Authentication & Authorization
  → Tidak ada anonymous users
  → Tidak ada root remote login
  → Password policy yang kuat
  → Dedicated users per aplikasi

Level 4: Database-level Access Control
  → Principle of least privilege
  → Grant hanya privilege yang benar-benar dibutuhkan
  → Revoke privilege yang tidak lagi digunakan

Level 5: Application-level
  → Prepared statements untuk mencegah SQL injection
  → Parameterized queries
  → Input validation sebelum query
```

---

*Panduan ini berlaku untuk MariaDB 10.6+ / MySQL 8.0+ pada Ubuntu Server 24.04 LTS, Debian 12 (Bookworm), Windows Server 2022, dan Windows 11.*

*Selalu uji konfigurasi di lingkungan staging sebelum menerapkan ke production.*
