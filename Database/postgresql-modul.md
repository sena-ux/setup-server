# Modul Pembelajaran PostgreSQL: Dari Dasar Hingga Tingkat Lanjut

> Modul ini disusun sebagai panduan belajar mandiri dan referensi kerja bagi pengembang yang ingin memahami PostgreSQL secara komprehensif, mulai dari konsep dasar basis data relasional hingga teknik optimasi dan studi kasus aplikasi nyata.

---

## Daftar Isi

1. [Pendahuluan](#1-pendahuluan)
2. [Instalasi PostgreSQL di Linux](#2-instalasi-postgresql-di-linux)
3. [Konfigurasi PostgreSQL](#3-konfigurasi-postgresql)
4. [Manajemen User & Role](#4-manajemen-user--role)
5. [Database Management](#5-database-management)
6. [Tipe Data PostgreSQL](#6-tipe-data-postgresql)
7. [Table Management](#7-table-management)
8. [CRUD Operations](#8-crud-operations)
9. [Query Lanjutan](#9-query-lanjutan)
10. [Index dan Optimasi](#10-index-dan-optimasi)
11. [Backup & Restore](#11-backup--restore)
12. [Transaction](#12-transaction)
13. [Security Best Practices](#13-security-best-practices)
14. [Studi Kasus: Sistem Sekolah](#14-studi-kasus-sistem-sekolah)
15. [Tips & Best Practice PostgreSQL](#15-tips--best-practice-postgresql)
16. [Error Umum dan Cara Mengatasinya](#16-error-umum-dan-cara-mengatasinya)
17. [Studi Kasus Tambahan: Sistem Kasir Sederhana](#17-studi-kasus-tambahan-sistem-kasir-sederhana)

---

## 1. Pendahuluan

### 1.1 Apa itu PostgreSQL

**PostgreSQL** (sering disebut "Postgres") adalah sistem manajemen basis data relasional (RDBMS) yang bersifat *open source*, dikembangkan sejak akhir 1980-an di University of California, Berkeley. PostgreSQL dikenal sebagai salah satu database paling canggih dan stabil karena mendukung standar SQL secara luas serta menyediakan fitur-fitur tingkat lanjut seperti tipe data JSON, full-text search, replikasi, dan ekstensibilitas melalui *extension*.

Secara sederhana, PostgreSQL dapat dianalogikan sebagai sebuah **gudang data raksasa yang sangat terorganisir**. Setiap barang (data) disimpan dalam rak (tabel) yang memiliki label dan kategori jelas (kolom dan tipe data), serta memiliki sistem keamanan (user dan role) yang mengatur siapa boleh mengambil atau menambah barang di rak tertentu.

### 1.2 Kelebihan PostgreSQL Dibanding Database Lain

| Aspek | PostgreSQL | MySQL | SQLite |
|---|---|---|---|
| Lisensi | Open source (PostgreSQL License) | Open source (GPL) | Open source (Public Domain) |
| Kepatuhan terhadap standar SQL | Sangat tinggi | Menengah | Menengah |
| Tipe data lanjutan (JSON, Array, UUID) | Sangat lengkap | Terbatas | Terbatas |
| Concurrency (MVCC) | Sangat matang | Cukup baik | Terbatas |
| Skalabilitas untuk aplikasi besar | Sangat baik | Baik | Tidak cocok |
| Extensibility (custom function, extension) | Sangat fleksibel | Terbatas | Tidak ada |
| Cocok untuk | Aplikasi enterprise, data kompleks | Aplikasi web umum | Aplikasi kecil/embedded |

**Poin penting kelebihan PostgreSQL:**

- **ACID Compliance penuh**: Setiap transaksi dijamin Atomicity, Consistency, Isolation, dan Durability.
- **Dukungan JSON/JSONB**: Memungkinkan PostgreSQL berfungsi seperti database relasional sekaligus NoSQL.
- **Extensible**: Bisa menambahkan tipe data, fungsi, bahkan bahasa prosedural baru (PL/pgSQL, PL/Python, dll).
- **Concurrency tinggi** menggunakan MVCC (Multi-Version Concurrency Control), sehingga pembacaan data tidak saling mengunci dengan penulisan data.
- **Komunitas besar dan aktif**, dengan dukungan jangka panjang dan dokumentasi resmi yang sangat lengkap.

### 1.3 Konsep Dasar RDBMS

RDBMS (*Relational Database Management System*) adalah sistem yang menyimpan data dalam bentuk **tabel-tabel** yang saling berelasi melalui kunci (*key*).

Beberapa istilah dasar yang wajib dipahami:

- **Database**: Kumpulan dari beberapa tabel dan objek lain (index, view, function) yang saling berhubungan dalam satu konteks aplikasi.
- **Table**: Struktur data berbentuk baris dan kolom, mirip seperti spreadsheet.
- **Row (baris/record)**: Satu entri data dalam tabel.
- **Column (kolom/field)**: Atribut atau properti dari data, masing-masing punya tipe data tertentu.
- **Primary Key (PK)**: Kolom (atau kombinasi kolom) yang menjadi identitas unik setiap baris.
- **Foreign Key (FK)**: Kolom yang merujuk ke primary key di tabel lain, digunakan untuk membangun relasi antar tabel.
- **Schema**: Ruang nama (namespace) di dalam database yang mengelompokkan tabel-tabel dan objek lainnya.

**Analogi sederhana:**

Bayangkan sebuah sekolah. *Database* adalah seluruh sistem administrasi sekolah. *Table* `siswa` adalah buku daftar siswa, setiap baris adalah satu siswa, dan setiap kolom adalah informasi seperti nama, NIS, dan tanggal lahir. *Primary key* adalah NIS (Nomor Induk Siswa) karena tidak ada dua siswa yang memiliki NIS sama. Jika tabel `nilai` memiliki kolom `nis` yang merujuk ke tabel `siswa`, maka kolom tersebut adalah *foreign key*.

### 1.4 Arsitektur PostgreSQL (Client-Server, Process Model)

PostgreSQL menggunakan model **client-server**. Artinya, terdapat satu proses server utama (`postgres`) yang berjalan di latar belakang (*background*), dan klien (bisa berupa aplikasi, `psql`, atau tools seperti DBeaver/pgAdmin) terhubung ke server tersebut melalui jaringan (TCP/IP) atau Unix socket.

```
┌─────────────┐        ┌────────────────────────────────────┐
│   Klien     │        │           SERVER POSTGRESQL          │
│ (psql, app, │ ─────▶ │  ┌────────────┐    ┌──────────────┐ │
│  pgAdmin)   │        │  │ Postmaster │───▶│ Backend Proc. │ │
└─────────────┘        │  │ (Listener) │    │ (per koneksi) │ │
                        │  └────────────┘    └──────┬───────┘ │
                        │                            │         │
                        │   ┌────────────────────────▼──────┐ │
                        │   │     Shared Buffer (Memory)    │ │
                        │   └────────────────────────┬──────┘ │
                        │                            │         │
                        │   ┌────────────────────────▼──────┐ │
                        │   │     Disk Storage (Data Files) │ │
                        │   └────────────────────────────────┘ │
                        └────────────────────────────────────┘
```

**Komponen utama arsitektur PostgreSQL:**

1. **Postmaster (Server Process)**: Proses utama yang pertama kali dijalankan. Bertugas mendengarkan koneksi masuk pada port tertentu (default 5432) dan membuat proses anak (*backend process*) baru untuk setiap koneksi klien.
2. **Backend Process**: Setiap koneksi klien akan ditangani oleh satu proses backend khusus. Ini berarti PostgreSQL menggunakan model *multi-process*, bukan *multi-thread* (berbeda dengan beberapa RDBMS lain).
3. **Shared Memory / Shared Buffer**: Area memori yang digunakan bersama oleh semua proses backend untuk menyimpan cache data (halaman tabel/index) agar akses lebih cepat.
4. **WAL (Write-Ahead Log)**: Mekanisme pencatatan perubahan data sebelum benar-benar ditulis ke disk, untuk menjamin durabilitas dan recovery jika terjadi crash.
5. **Background Processes**: Beberapa proses latar belakang seperti `autovacuum` (membersihkan data yang sudah tidak terpakai), `checkpointer`, dan `wal writer`.

**Analogi:** Bayangkan PostgreSQL seperti sebuah restoran. *Postmaster* adalah resepsionis yang menerima tamu (koneksi) di pintu masuk. Setiap tamu yang masuk akan dilayani oleh satu pelayan khusus (*backend process*). Dapur (*shared buffer*) adalah tempat bahan makanan (data) disiapkan agar pelayan tidak perlu bolak-balik ke gudang (disk) setiap saat. Buku catatan pesanan (*WAL*) dicatat terlebih dahulu sebelum makanan benar-benar disajikan, sehingga jika terjadi masalah, pesanan tetap bisa dilacak.

---

## 2. Instalasi PostgreSQL di Linux

### 2.1 Instalasi di Ubuntu/Debian (apt)

Buka terminal dan jalankan perintah berikut secara berurutan:

```bash
# Update daftar paket
sudo apt update

# Install PostgreSQL beserta package tambahan (contrib)
sudo apt install postgresql postgresql-contrib -y

# Cek versi yang terinstal
psql --version
```

**Penjelasan:**
- `postgresql` adalah paket inti yang berisi server database.
- `postgresql-contrib` berisi modul tambahan (extension) yang umum dipakai, seperti `pgcrypto` dan `uuid-ossp`.
- Setelah instalasi, service PostgreSQL biasanya akan otomatis berjalan dan aktif saat boot.

### 2.2 Instalasi di CentOS/RHEL (yum/dnf)

Untuk distribusi berbasis RHEL (CentOS, Rocky Linux, AlmaLinux), repositori resmi PostgreSQL perlu ditambahkan terlebih dahulu karena versi default di repo OS biasanya tertinggal.

```bash
# Install repositori PostgreSQL resmi (contoh untuk PostgreSQL 16 di RHEL/Rocky 9)
sudo dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-x86_64/pgdg-redhat-repo-latest.noarch.rpm

# Nonaktifkan modul PostgreSQL bawaan OS (agar tidak konflik versi)
sudo dnf -qy module disable postgresql

# Install PostgreSQL versi tertentu
sudo dnf install -y postgresql16-server postgresql16-contrib

# Inisialisasi database (khusus RHEL-based, wajib dilakukan manual)
sudo /usr/pgsql-16/bin/postgresql-16-setup initdb
```

**Penjelasan:**
- Pada distribusi berbasis RHEL, langkah `initdb` **wajib** dijalankan secara manual untuk membuat direktori data awal (*data directory*), berbeda dengan Ubuntu/Debian yang melakukannya otomatis saat instalasi.

### 2.3 Menjalankan Service PostgreSQL

```bash
# Mengaktifkan service agar berjalan otomatis saat boot
sudo systemctl enable postgresql

# Menjalankan service
sudo systemctl start postgresql

# Khusus RHEL-based dengan versi spesifik
sudo systemctl enable postgresql-16
sudo systemctl start postgresql-16
```

### 2.4 Mengecek Status Service

```bash
# Mengecek status service PostgreSQL
sudo systemctl status postgresql
```

Output yang menunjukkan service berjalan normal akan menampilkan baris `Active: active (running)`. Jika status menunjukkan `failed` atau `inactive`, periksa log dengan:

```bash
sudo journalctl -u postgresql -n 50 --no-pager
```

### 2.5 Struktur Direktori PostgreSQL

Berikut adalah lokasi-lokasi penting yang perlu diketahui (path dapat sedikit berbeda tergantung distribusi dan versi):

| Komponen | Lokasi Umum (Ubuntu/Debian) | Lokasi Umum (RHEL-based) |
|---|---|---|
| File konfigurasi (`postgresql.conf`, `pg_hba.conf`) | `/etc/postgresql/<versi>/main/` | `/var/lib/pgsql/<versi>/data/` |
| Direktori data (data files) | `/var/lib/postgresql/<versi>/main/` | `/var/lib/pgsql/<versi>/data/` |
| Binary executable (`psql`, `pg_dump`, dll) | `/usr/lib/postgresql/<versi>/bin/` | `/usr/pgsql-<versi>/bin/` |
| Log file | `/var/log/postgresql/` | `/var/lib/pgsql/<versi>/data/log/` |

**Analogi:** Direktori data dapat dianggap sebagai "gudang fisik" tempat seluruh data tabel disimpan dalam bentuk file biner, sedangkan `postgresql.conf` dan `pg_hba.conf` adalah "buku aturan" yang mengatur bagaimana gudang tersebut dioperasikan dan siapa yang boleh masuk.

### 2.6 Default Port dan Konfigurasi Awal

- **Default port**: `5432`
- **User default**: `postgres` (superuser sistem operasi dan database)

Untuk masuk ke PostgreSQL pertama kali setelah instalasi:

```bash
# Beralih ke user sistem 'postgres'
sudo -i -u postgres

# Masuk ke prompt psql
psql
```

Setelah masuk, prompt akan berubah menjadi:

```
postgres=#
```

Tanda `#` menunjukkan bahwa user yang login adalah **superuser**. Jika user biasa, tanda akan berupa `>`.

---

## 3. Konfigurasi PostgreSQL

### 3.1 File Konfigurasi Utama

PostgreSQL memiliki dua file konfigurasi paling penting:

#### a. `postgresql.conf`

File ini mengatur **perilaku umum server**, seperti port, alamat listening, alokasi memori, logging, dan parameter performa lainnya.

Lokasi umum: `/etc/postgresql/<versi>/main/postgresql.conf` (Ubuntu) atau `/var/lib/pgsql/<versi>/data/postgresql.conf` (RHEL).

#### b. `pg_hba.conf`

Singkatan dari **"PostgreSQL Host-Based Authentication"**. File ini mengatur **siapa boleh terhubung dari mana, ke database mana, dan dengan metode otentikasi apa**.

Lokasi umum: berada di direktori yang sama dengan `postgresql.conf`.

**Analogi:** `postgresql.conf` adalah "panel kontrol mesin" yang mengatur cara kerja internal server, sedangkan `pg_hba.conf` adalah "buku tamu satpam" yang menentukan siapa saja yang diizinkan masuk gedung dan melalui pintu mana.

### 3.2 Setting `listen_addresses`

Parameter ini menentukan alamat IP mana yang akan "didengarkan" oleh PostgreSQL untuk menerima koneksi.

Buka file `postgresql.conf`:

```bash
sudo nano /etc/postgresql/16/main/postgresql.conf
```

Cari dan ubah baris berikut:

```conf
# Hanya menerima koneksi dari localhost (default)
listen_addresses = 'localhost'

# Menerima koneksi dari semua alamat IP (untuk akses remote)
listen_addresses = '*'

# Atau spesifik ke IP tertentu
listen_addresses = '192.168.1.10,localhost'
```

> **Catatan keamanan**: Mengatur `listen_addresses = '*'` membuat server "dapat dijangkau" dari jaringan luar, namun akses sebenarnya masih dikontrol oleh `pg_hba.conf`. Jangan pernah membuka akses tanpa mengatur firewall dan otentikasi yang ketat.

### 3.3 Setting Port

Secara default, PostgreSQL berjalan di port `5432`. Untuk mengubahnya, cari baris berikut di `postgresql.conf`:

```conf
port = 5432
```

Ubah sesuai kebutuhan, misalnya:

```conf
port = 5433
```

> Mengubah port berguna jika ingin menjalankan beberapa instance PostgreSQL secara bersamaan di satu server, atau untuk alasan keamanan (menyamarkan port default).

### 3.4 Konfigurasi Koneksi Local dan Remote

Pada file `pg_hba.conf`, setiap baris memiliki format:

```
TYPE  DATABASE  USER  ADDRESS  METHOD
```

Contoh konfigurasi default:

```conf
# TYPE  DATABASE        USER            ADDRESS                 METHOD

# Koneksi lokal melalui Unix socket
local   all             postgres                                peer

# Koneksi dari localhost (IPv4)
host    all             all             127.0.0.1/32            scram-sha-256

# Koneksi dari localhost (IPv6)
host    all             all             ::1/128                 scram-sha-256
```

**Penjelasan kolom:**

- **TYPE**: `local` (koneksi via Unix socket, tanpa jaringan) atau `host` (koneksi via TCP/IP).
- **DATABASE**: Nama database yang diizinkan, atau `all` untuk semua database.
- **USER**: Nama user/role PostgreSQL, atau `all` untuk semua user.
- **ADDRESS**: Rentang IP yang diizinkan (format CIDR).
- **METHOD**: Metode otentikasi, misalnya:
  - `trust` — tanpa password (sangat tidak disarankan untuk produksi).
  - `peer` — mencocokkan user sistem operasi dengan user database (umum untuk koneksi lokal).
  - `md5` / `scram-sha-256` — login menggunakan password terenkripsi (`scram-sha-256` lebih aman dan disarankan).

**Contoh menambahkan akses remote dari jaringan tertentu:**

```conf
# Mengizinkan semua user terhubung ke database 'sekolah' dari jaringan 192.168.1.0/24
host    sekolah         all             192.168.1.0/24          scram-sha-256
```

### 3.5 Restart Service Setelah Konfigurasi

Setiap kali file `postgresql.conf` atau `pg_hba.conf` diubah, service harus di-*restart* (atau *reload* untuk perubahan tertentu) agar perubahan diterapkan.

```bash
# Restart penuh (untuk perubahan postgresql.conf seperti listen_addresses, port)
sudo systemctl restart postgresql

# Reload (cukup untuk perubahan pg_hba.conf, tanpa memutus koneksi aktif)
sudo systemctl reload postgresql
```

Verifikasi apakah server sudah mendengarkan port baru:

```bash
sudo ss -tulnp | grep postgres
```

---

## 4. Manajemen User & Role

### 4.1 Konsep Role di PostgreSQL

PostgreSQL **tidak membedakan antara "user" dan "role"** secara mendasar — keduanya adalah objek yang sama. Perbedaannya hanya pada atribut `LOGIN`:

- **Role dengan atribut `LOGIN`** berfungsi seperti **user** (dapat digunakan untuk login/koneksi).
- **Role tanpa atribut `LOGIN`** berfungsi seperti **group** (digunakan untuk mengelompokkan permission, lalu di-assign ke user lain).

Perintah `CREATE USER` sebenarnya adalah alias dari `CREATE ROLE ... LOGIN`.

**Analogi:** Bayangkan sebuah perusahaan. *Role* adalah "jabatan" seperti Admin, Staff Gudang, atau Manajer. *User* adalah "karyawan" yang diberi salah satu jabatan tersebut. Satu karyawan bisa memiliki lebih dari satu jabatan (role) sekaligus, dan setiap jabatan memiliki hak akses (privilege) berbeda terhadap sumber daya perusahaan (database, tabel).

### 4.2 Membuat User

```sql
-- Membuat user baru dengan password
CREATE USER sena WITH PASSWORD 'passwordAman123';
```

**Penjelasan:**
- `sena` adalah nama user yang dibuat.
- `WITH PASSWORD '...'` menetapkan password untuk otentikasi.
- Secara default, user baru memiliki hak `LOGIN` namun **tidak** memiliki privilege khusus terhadap database mana pun.

Membuat user dengan atribut tambahan:

```sql
-- User dengan kemampuan membuat database
CREATE USER admin_sekolah WITH PASSWORD 'rahasia123' CREATEDB;

-- User superuser (memiliki akses penuh ke seluruh sistem)
CREATE USER super_admin WITH PASSWORD 'superRahasia' SUPERUSER;
```

> **Peringatan**: Atribut `SUPERUSER` memberikan akses tanpa batas. Gunakan hanya untuk kebutuhan administrasi sistem, jangan untuk user aplikasi.

### 4.3 Mengubah Password

```sql
-- Mengubah password user yang sudah ada
ALTER USER sena WITH PASSWORD 'passwordBaru456';
```

**Penjelasan:** Perintah ini akan menggantikan password lama dengan yang baru. Password baru otomatis dienkripsi sesuai metode yang dikonfigurasi di `password_encryption` (default: `scram-sha-256` pada versi PostgreSQL terbaru).

### 4.4 Menghapus User

```sql
-- Menghapus user
DROP USER sena;
```

**Penjelasan:** Perintah ini akan gagal jika user tersebut masih memiliki objek (tabel, database) atau privilege yang dimilikinya di database lain. Solusinya, hak akses/objek tersebut harus dipindahkan (`REASSIGN OWNED`) atau dihapus (`DROP OWNED`) terlebih dahulu:

```sql
-- Memindahkan kepemilikan objek dari 'sena' ke 'postgres' sebelum menghapus
REASSIGN OWNED BY sena TO postgres;
DROP OWNED BY sena;
DROP USER sena;
```

### 4.5 Memberikan Privilege

```sql
-- Memberikan seluruh privilege pada database 'sekolah' kepada user 'sena'
GRANT ALL PRIVILEGES ON DATABASE sekolah TO sena;
```

**Penjelasan:**
- `GRANT` digunakan untuk memberikan hak akses.
- `ALL PRIVILEGES` mencakup hak seperti `CONNECT`, `CREATE`, dan `TEMPORARY` pada level database.
- Untuk privilege yang lebih granular pada level tabel:

```sql
-- Memberikan hak baca dan tulis pada tabel 'siswa'
GRANT SELECT, INSERT, UPDATE, DELETE ON siswa TO sena;

-- Memberikan hak hanya membaca (read-only)
GRANT SELECT ON ALL TABLES IN SCHEMA public TO sena;
```

Untuk **mencabut** privilege, gunakan `REVOKE`:

```sql
-- Mencabut hak hapus data dari user 'sena'
REVOKE DELETE ON siswa FROM sena;
```

### 4.6 Role dan Permission Level

Berikut tingkatan hak akses (privilege) umum dalam PostgreSQL, dari yang paling terbatas hingga paling luas:

| Level | Privilege | Keterangan |
|---|---|---|
| Database | `CONNECT` | Hak untuk terhubung ke database |
| Database | `CREATE` | Hak untuk membuat schema/objek baru di database |
| Tabel | `SELECT` | Hak membaca data |
| Tabel | `INSERT` | Hak menambah data |
| Tabel | `UPDATE` | Hak mengubah data |
| Tabel | `DELETE` | Hak menghapus data |
| Sistem | `SUPERUSER` | Akses penuh tanpa batasan, melewati seluruh sistem permission |
| Sistem | `CREATEDB` | Hak membuat database baru |
| Sistem | `CREATEROLE` | Hak membuat role/user baru |

**Contoh penerapan role group (best practice):**

```sql
-- Membuat role group tanpa LOGIN
CREATE ROLE staf_sekolah;

-- Memberikan privilege ke role group
GRANT SELECT, INSERT, UPDATE ON siswa, guru, kelas TO staf_sekolah;

-- Memberikan role group tersebut ke user tertentu
GRANT staf_sekolah TO sena;
```

Dengan pendekatan ini, jika ada perubahan kebijakan akses, administrator hanya perlu mengubah privilege pada role `staf_sekolah`, dan seluruh user yang memiliki role tersebut akan otomatis terdampak.

---

## 5. Database Management

### 5.1 Membuat Database

```sql
-- Membuat database baru
CREATE DATABASE sekolah;
```

**Penjelasan:** Perintah ini membuat database baru bernama `sekolah` dengan konfigurasi default (encoding `UTF8`, owner adalah user yang menjalankan perintah).

Membuat database dengan opsi tambahan:

```sql
-- Membuat database dengan owner dan encoding spesifik
CREATE DATABASE sekolah
  OWNER admin_sekolah
  ENCODING 'UTF8'
  TEMPLATE template0;
```

### 5.2 Menampilkan Database

Melalui `psql` (perintah meta, diawali tanda `\`):

```
\l
```

Melalui SQL standar (dapat dijalankan dari aplikasi atau tools GUI):

```sql
SELECT datname FROM pg_database;
```

**Penjelasan:** Tabel sistem `pg_database` adalah *catalog table* internal PostgreSQL yang menyimpan informasi seluruh database yang ada di server.

### 5.3 Menghapus Database

```sql
-- Menghapus database (hati-hati, tidak bisa dibatalkan!)
DROP DATABASE sekolah;
```

**Penjelasan:** Perintah ini akan gagal jika masih ada koneksi aktif ke database tersebut. Pastikan tidak ada sesi yang terhubung, atau gunakan opsi `WITH (FORCE)` (tersedia mulai PostgreSQL 13):

```sql
DROP DATABASE sekolah WITH (FORCE);
```

> **Peringatan**: Perintah `DROP DATABASE` bersifat permanen dan tidak dapat di-*rollback*. Selalu lakukan backup terlebih dahulu sebelum menghapus database produksi.

### 5.4 Menggunakan Database

Melalui `psql`:

```
\c sekolah
```

**Penjelasan:** Perintah `\c` (connect) digunakan untuk berpindah koneksi dari database yang sedang aktif ke database lain. Setelah berhasil, prompt akan menunjukkan nama database aktif, misalnya:

```
sekolah=#
```

> Pada aplikasi (misalnya Laravel), perpindahan database dilakukan melalui konfigurasi koneksi (`DB_DATABASE` di file `.env`), bukan melalui perintah `\c` yang hanya berlaku di sesi `psql` interaktif.

---

## 6. Tipe Data PostgreSQL

Pemilihan tipe data yang tepat sangat berpengaruh terhadap efisiensi penyimpanan, performa query, dan integritas data. Berikut adalah tipe data yang paling umum digunakan.

### 6.1 Numeric (INT, BIGINT, DECIMAL)

| Tipe Data | Ukuran | Rentang Nilai | Kapan Digunakan |
|---|---|---|---|
| `SMALLINT` | 2 byte | -32.768 s/d 32.767 | Nilai kecil, misalnya umur, jumlah tingkat kelas |
| `INTEGER` (`INT`) | 4 byte | ±2,1 miliar | Nilai umum seperti ID, jumlah stok |
| `BIGINT` | 8 byte | ±9,2 kuintiliun | ID dengan volume sangat besar, timestamp dalam milidetik |
| `DECIMAL(p,s)` / `NUMERIC(p,s)` | Variabel | Presisi eksak sesuai `p` (jumlah digit) dan `s` (jumlah desimal) | Nilai uang/mata uang, perhitungan yang butuh presisi eksak |
| `REAL` / `DOUBLE PRECISION` | 4/8 byte | Presisi floating-point | Data ilmiah, sensor, di mana sedikit pembulatan dapat ditoleransi |
| `SERIAL` / `BIGSERIAL` | 4/8 byte | Sama seperti INTEGER/BIGINT | Kolom auto-increment, umum untuk primary key |

```sql
-- Contoh penggunaan tipe numerik
CREATE TABLE produk (
    id SERIAL PRIMARY KEY,
    nama VARCHAR(100),
    stok INTEGER,
    harga NUMERIC(12,2)  -- contoh: 1500000.50
);
```

> **Tips**: Untuk nilai uang, **selalu gunakan `NUMERIC` atau `DECIMAL`**, jangan `REAL`/`DOUBLE PRECISION`, karena tipe floating-point dapat menimbulkan kesalahan pembulatan kecil yang berbahaya dalam perhitungan finansial.

### 6.2 Character (VARCHAR, TEXT)

| Tipe Data | Keterangan | Kapan Digunakan |
|---|---|---|
| `CHAR(n)` | Panjang tetap (fixed-length), akan diisi spasi jika kurang | Kode dengan panjang tetap, misalnya kode pos 5 digit |
| `VARCHAR(n)` | Panjang variabel dengan batas maksimum `n` karakter | Nama, email, judul — data dengan batas wajar |
| `TEXT` | Panjang variabel tanpa batas spesifik | Deskripsi panjang, konten artikel, catatan |

```sql
CREATE TABLE artikel (
    id SERIAL PRIMARY KEY,
    judul VARCHAR(255),       -- judul dibatasi 255 karakter
    isi TEXT                  -- isi artikel tanpa batas panjang
);
```

> **Catatan**: Secara performa, PostgreSQL memperlakukan `VARCHAR` dan `TEXT` hampir identik secara internal. Perbedaan utamanya hanyalah pembatasan panjang pada level aplikasi/validasi data.

### 6.3 Date/Time

| Tipe Data | Format Contoh | Kapan Digunakan |
|---|---|---|
| `DATE` | `2026-06-13` | Tanggal saja, tanpa informasi waktu (tanggal lahir, tanggal masuk) |
| `TIME` | `14:30:00` | Waktu saja, tanpa tanggal (jam pelajaran) |
| `TIMESTAMP` | `2026-06-13 14:30:00` | Tanggal dan waktu tanpa zona waktu |
| `TIMESTAMPTZ` | `2026-06-13 14:30:00+08` | Tanggal dan waktu **dengan** zona waktu (disarankan untuk aplikasi modern) |
| `INTERVAL` | `'2 days'`, `'1 month'` | Representasi durasi/selisih waktu |

```sql
CREATE TABLE absensi (
    id SERIAL PRIMARY KEY,
    tanggal DATE,
    jam_masuk TIME,
    dibuat_pada TIMESTAMPTZ DEFAULT now()
);
```

> **Tips**: Gunakan `TIMESTAMPTZ` (timestamp with time zone) untuk kolom seperti `created_at`/`updated_at`, terutama jika aplikasi diakses dari berbagai zona waktu, karena PostgreSQL akan otomatis menyimpan dalam UTC dan mengonversi sesuai zona waktu sesi saat ditampilkan.

### 6.4 Boolean

```sql
CREATE TABLE siswa (
    id SERIAL PRIMARY KEY,
    nama VARCHAR(100),
    is_aktif BOOLEAN DEFAULT true
);
```

**Penjelasan:** Tipe `BOOLEAN` hanya memiliki tiga kemungkinan nilai: `TRUE`, `FALSE`, atau `NULL` (tidak diketahui). Cocok digunakan untuk flag status seperti `is_active`, `is_verified`, atau `is_deleted`.

### 6.5 JSON dan JSONB

| Tipe Data | Keterangan |
|---|---|
| `JSON` | Menyimpan data dalam format teks JSON, mempertahankan format asli (termasuk spasi dan urutan key) |
| `JSONB` | Menyimpan data JSON dalam format biner yang sudah diproses, **lebih cepat untuk query dan mendukung indexing** |

```sql
CREATE TABLE konfigurasi_aplikasi (
    id SERIAL PRIMARY KEY,
    nama_aplikasi VARCHAR(100),
    pengaturan JSONB
);

-- Insert data JSONB
INSERT INTO konfigurasi_aplikasi (nama_aplikasi, pengaturan)
VALUES ('ArsiPro', '{"tema": "gelap", "notifikasi": true, "bahasa": "id"}');

-- Query berdasarkan isi JSONB
SELECT * FROM konfigurasi_aplikasi
WHERE pengaturan->>'bahasa' = 'id';
```

**Penjelasan operator JSONB:**
- `->` mengambil nilai sebagai tipe JSON.
- `->>` mengambil nilai sebagai tipe TEXT.
- `@>` memeriksa apakah JSONB mengandung struktur tertentu (*containment*).

> **Rekomendasi**: Hampir selalu gunakan `JSONB`, bukan `JSON`, kecuali ada kebutuhan spesifik untuk mempertahankan format teks asli secara persis.

### 6.6 UUID

```sql
-- Mengaktifkan extension untuk generate UUID (jika belum aktif)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE dokumen (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nama_file VARCHAR(255),
    diunggah_pada TIMESTAMPTZ DEFAULT now()
);
```

**Penjelasan:** `UUID` (Universally Unique Identifier) adalah identifier 128-bit yang dijamin unik secara global, tidak hanya dalam satu tabel. Cocok digunakan ketika:
- ID tidak boleh mudah ditebak (untuk keamanan, misalnya URL publik).
- Data akan disinkronisasi antar sistem terdistribusi tanpa risiko duplikasi ID.

> Mulai PostgreSQL 13, fungsi `gen_random_uuid()` dari extension `pgcrypto` juga umum digunakan sebagai alternatif `uuid_generate_v4()`.

### 6.7 Ringkasan Kapan Menggunakan Masing-Masing Tipe

```
Apakah data berupa angka?
├── Ya, untuk identitas (ID) yang bertambah otomatis → SERIAL / BIGSERIAL
├── Ya, untuk nilai uang/presisi penting           → NUMERIC(p,s)
├── Ya, untuk angka bulat umum                     → INTEGER / BIGINT
└── Ya, untuk data ilmiah/sensor                   → DOUBLE PRECISION

Apakah data berupa teks?
├── Pendek, panjang dibatasi (nama, email)  → VARCHAR(n)
├── Panjang tidak terbatas (deskripsi)      → TEXT
└── Kode dengan panjang tetap (kode pos)    → CHAR(n)

Apakah data berupa tanggal/waktu?
├── Hanya tanggal      → DATE
├── Hanya waktu        → TIME
└── Tanggal + waktu    → TIMESTAMPTZ (disarankan)

Apakah data berupa struktur fleksibel/dinamis (seperti konfigurasi)?
└── JSONB

Apakah data memerlukan identitas unik global (tidak hanya per tabel)?
└── UUID

Apakah data berupa kondisi ya/tidak?
└── BOOLEAN
```

---

## 7. Table Management

### 7.1 Membuat Tabel: CREATE TABLE

```sql
CREATE TABLE siswa (
    id SERIAL PRIMARY KEY,
    nis VARCHAR(20) NOT NULL UNIQUE,
    nama_lengkap VARCHAR(100) NOT NULL,
    tanggal_lahir DATE,
    jenis_kelamin CHAR(1) CHECK (jenis_kelamin IN ('L', 'P')),
    created_at TIMESTAMPTZ DEFAULT now()
);
```

**Penjelasan setiap bagian:**
- `id SERIAL PRIMARY KEY` — kolom ID otomatis bertambah dan menjadi kunci utama.
- `nis VARCHAR(20) NOT NULL UNIQUE` — NIS wajib diisi (`NOT NULL`) dan tidak boleh ada duplikat (`UNIQUE`).
- `jenis_kelamin CHAR(1) CHECK (...)` — kolom dengan validasi nilai, hanya menerima `'L'` atau `'P'`.
- `created_at TIMESTAMPTZ DEFAULT now()` — otomatis terisi waktu saat ini ketika baris baru dibuat.

### 7.2 Primary Key

**Primary Key (PK)** adalah kolom (atau kombinasi kolom) yang secara unik mengidentifikasi setiap baris dalam tabel. Sebuah tabel hanya boleh memiliki **satu** primary key, namun primary key dapat terdiri dari lebih dari satu kolom (*composite key*).

```sql
-- Primary key tunggal (paling umum)
CREATE TABLE guru (
    id SERIAL PRIMARY KEY,
    nip VARCHAR(20) NOT NULL
);

-- Composite primary key (kombinasi dua kolom)
CREATE TABLE nilai_siswa (
    siswa_id INTEGER NOT NULL,
    mapel_id INTEGER NOT NULL,
    nilai NUMERIC(5,2),
    PRIMARY KEY (siswa_id, mapel_id)
);
```

**Analogi:** Primary key seperti nomor KTP — setiap warga negara wajib memiliki nomor yang unik dan tidak boleh sama dengan warga lain, sehingga identitasnya tidak akan tertukar.

### 7.3 Foreign Key

**Foreign Key (FK)** adalah kolom yang merujuk ke primary key di tabel lain, digunakan untuk menjaga **integritas referensial** — yaitu memastikan data yang dirujuk benar-benar ada.

```sql
CREATE TABLE kelas (
    id SERIAL PRIMARY KEY,
    nama_kelas VARCHAR(50) NOT NULL,
    wali_kelas_id INTEGER REFERENCES guru(id)
);
```

**Penjelasan:** Kolom `wali_kelas_id` pada tabel `kelas` merujuk ke kolom `id` pada tabel `guru`. PostgreSQL akan menolak `INSERT` atau `UPDATE` jika nilai `wali_kelas_id` tidak ada dalam tabel `guru`.

Menentukan perilaku saat data induk dihapus/diubah (`ON DELETE` / `ON UPDATE`):

```sql
CREATE TABLE siswa_kelas (
    id SERIAL PRIMARY KEY,
    siswa_id INTEGER REFERENCES siswa(id) ON DELETE CASCADE,
    kelas_id INTEGER REFERENCES kelas(id) ON DELETE SET NULL
);
```

| Opsi | Keterangan |
|---|---|
| `CASCADE` | Jika baris induk dihapus, baris terkait di tabel ini juga otomatis dihapus |
| `SET NULL` | Jika baris induk dihapus, kolom FK pada baris terkait diatur menjadi `NULL` |
| `RESTRICT` (default) | Mencegah penghapusan baris induk jika masih ada baris terkait |
| `NO ACTION` | Mirip `RESTRICT`, namun pengecekan dapat ditunda (deferred) dalam transaksi |

**Analogi:** Foreign key seperti nomor referensi pada surat tugas yang menyebutkan "Berdasarkan SK No. 123/2026" — surat tersebut hanya valid jika SK No. 123/2026 benar-benar ada dan tercatat.

### 7.4 Constraint (NOT NULL, UNIQUE, CHECK)

```sql
CREATE TABLE guru (
    id SERIAL PRIMARY KEY,
    nip VARCHAR(20) NOT NULL UNIQUE,        -- wajib diisi & tidak boleh duplikat
    nama_lengkap VARCHAR(100) NOT NULL,     -- wajib diisi
    gaji NUMERIC(12,2) CHECK (gaji >= 0),   -- gaji tidak boleh negatif
    email VARCHAR(100) UNIQUE
);
```

**Penjelasan jenis constraint:**
- `NOT NULL` — kolom wajib memiliki nilai, tidak boleh kosong.
- `UNIQUE` — nilai pada kolom harus berbeda untuk setiap baris (boleh `NULL` lebih dari satu kali, karena `NULL` tidak dianggap sama dengan `NULL` lainnya).
- `CHECK (kondisi)` — memastikan nilai memenuhi kondisi logis tertentu sebelum data disimpan.

Constraint juga dapat diberi nama agar lebih mudah dikelola:

```sql
CREATE TABLE guru (
    id SERIAL PRIMARY KEY,
    nip VARCHAR(20),
    gaji NUMERIC(12,2),
    CONSTRAINT uq_nip UNIQUE (nip),
    CONSTRAINT chk_gaji_positif CHECK (gaji >= 0)
);
```

### 7.5 Mengubah Tabel: ALTER TABLE

```sql
-- Menambah kolom baru
ALTER TABLE siswa ADD COLUMN no_telepon VARCHAR(20);

-- Mengubah tipe data kolom
ALTER TABLE siswa ALTER COLUMN no_telepon TYPE VARCHAR(15);

-- Mengganti nama kolom
ALTER TABLE siswa RENAME COLUMN no_telepon TO nomor_hp;

-- Menambahkan constraint NOT NULL pada kolom yang sudah ada
ALTER TABLE siswa ALTER COLUMN nama_lengkap SET NOT NULL;

-- Menghapus kolom
ALTER TABLE siswa DROP COLUMN nomor_hp;

-- Mengganti nama tabel
ALTER TABLE siswa RENAME TO data_siswa;
```

### 7.6 Menghapus Tabel: DROP TABLE

```sql
-- Menghapus tabel
DROP TABLE siswa;

-- Menghapus tabel hanya jika ada (mencegah error jika tabel tidak ditemukan)
DROP TABLE IF EXISTS siswa;

-- Menghapus tabel beserta objek lain yang bergantung padanya (FK dari tabel lain)
DROP TABLE siswa CASCADE;
```

> **Peringatan**: `DROP TABLE ... CASCADE` akan menghapus seluruh constraint, view, atau objek lain yang bergantung pada tabel tersebut. Gunakan dengan sangat hati-hati pada lingkungan produksi.

---

## 8. CRUD Operations

CRUD adalah singkatan dari **Create (INSERT)**, **Read (SELECT)**, **Update (UPDATE)**, dan **Delete (DELETE)** — empat operasi dasar yang membentuk inti interaksi dengan database.

Untuk contoh pada bagian ini, kita akan menggunakan tabel `siswa` berikut:

```sql
CREATE TABLE siswa (
    id SERIAL PRIMARY KEY,
    nis VARCHAR(20) NOT NULL UNIQUE,
    nama_lengkap VARCHAR(100) NOT NULL,
    kelas VARCHAR(20),
    nilai_rata_rata NUMERIC(5,2),
    is_aktif BOOLEAN DEFAULT true
);
```

### 8.1 INSERT

#### a. Insert Satu Data

```sql
INSERT INTO siswa (nis, nama_lengkap, kelas, nilai_rata_rata)
VALUES ('2026001', 'Ni Putu Sena Wardani', '9A', 88.50);
```

**Penjelasan:** Setiap kolom yang disebutkan dalam tanda kurung pertama harus memiliki pasangan nilai pada `VALUES` dengan urutan yang sama. Kolom `id` tidak perlu disebutkan karena bertipe `SERIAL` (otomatis terisi), dan `is_aktif` tidak disebutkan karena memiliki nilai `DEFAULT`.

#### b. Insert Multiple Data

```sql
INSERT INTO siswa (nis, nama_lengkap, kelas, nilai_rata_rata)
VALUES
    ('2026002', 'Made Wira Adiputra', '9A', 92.00),
    ('2026003', 'Kadek Ayu Lestari', '9B', 85.75),
    ('2026004', 'I Komang Bagus', '9B', 79.30);
```

**Penjelasan:** Memasukkan beberapa baris sekaligus dalam satu perintah `INSERT` lebih efisien dibandingkan menjalankan `INSERT` satu per satu, karena hanya memerlukan satu kali eksekusi ke server.

### 8.2 SELECT

#### a. Select Semua Data

```sql
SELECT * FROM siswa;
```

**Penjelasan:** Tanda `*` berarti "semua kolom". Untuk kebutuhan produksi, sebaiknya sebutkan kolom secara eksplisit agar query lebih efisien dan jelas:

```sql
SELECT id, nis, nama_lengkap, kelas FROM siswa;
```

#### b. Select dengan Kondisi WHERE

```sql
-- Menampilkan siswa dari kelas 9A
SELECT * FROM siswa WHERE kelas = '9A';

-- Menampilkan siswa dengan nilai rata-rata di atas 85
SELECT nama_lengkap, nilai_rata_rata FROM siswa WHERE nilai_rata_rata > 85;

-- Kombinasi beberapa kondisi
SELECT * FROM siswa WHERE kelas = '9B' AND nilai_rata_rata >= 80;

-- Kondisi pencarian teks (case-insensitive menggunakan ILIKE)
SELECT * FROM siswa WHERE nama_lengkap ILIKE '%wira%';
```

**Penjelasan operator umum:**
- `=`, `!=` (atau `<>`), `>`, `<`, `>=`, `<=` — perbandingan standar.
- `AND`, `OR`, `NOT` — kombinasi kondisi logika.
- `LIKE` — pencarian pola teks (case-sensitive), `%` sebagai wildcard.
- `ILIKE` — sama seperti `LIKE` namun *case-insensitive* (khas PostgreSQL).
- `IN (...)` — mencocokkan dengan beberapa nilai sekaligus.
- `BETWEEN ... AND ...` — mencocokkan rentang nilai.
- `IS NULL` / `IS NOT NULL` — memeriksa apakah nilai kosong.

```sql
-- Contoh IN dan BETWEEN
SELECT * FROM siswa WHERE kelas IN ('9A', '9B');
SELECT * FROM siswa WHERE nilai_rata_rata BETWEEN 80 AND 90;
```

#### c. ORDER BY

```sql
-- Mengurutkan berdasarkan nilai rata-rata, dari tertinggi ke terendah
SELECT nama_lengkap, nilai_rata_rata FROM siswa ORDER BY nilai_rata_rata DESC;

-- Mengurutkan berdasarkan beberapa kolom
SELECT * FROM siswa ORDER BY kelas ASC, nilai_rata_rata DESC;
```

**Penjelasan:** `ASC` (ascending, dari kecil ke besar) adalah default, sedangkan `DESC` (descending, dari besar ke kecil) harus dituliskan secara eksplisit. Ketika mengurutkan berdasarkan beberapa kolom, urutan pertama menjadi prioritas utama, dan kolom berikutnya digunakan untuk "memecah" kesamaan nilai pada kolom sebelumnya.

#### d. LIMIT dan OFFSET

```sql
-- Menampilkan 5 siswa dengan nilai tertinggi
SELECT nama_lengkap, nilai_rata_rata FROM siswa
ORDER BY nilai_rata_rata DESC
LIMIT 5;

-- Pagination: menampilkan 10 data, dimulai dari data ke-11 (halaman ke-2)
SELECT * FROM siswa
ORDER BY id
LIMIT 10 OFFSET 10;
```

**Penjelasan:**
- `LIMIT n` membatasi jumlah baris yang dikembalikan.
- `OFFSET m` melewati `m` baris pertama sebelum mulai mengambil data.
- Kombinasi `LIMIT` dan `OFFSET` umum digunakan untuk **pagination** pada aplikasi web. Rumusnya: `OFFSET = (halaman - 1) * jumlah_per_halaman`.

> **Tips performa**: Untuk pagination pada dataset besar, `OFFSET` dengan nilai besar dapat memperlambat query karena database harus "melewati" baris-baris sebelumnya. Pertimbangkan teknik *keyset pagination* (menggunakan `WHERE id > nilai_terakhir`) untuk dataset sangat besar.

### 8.3 UPDATE

#### a. Update Data dengan Kondisi

```sql
-- Mengubah nilai rata-rata siswa dengan NIS tertentu
UPDATE siswa
SET nilai_rata_rata = 90.00
WHERE nis = '2026001';
```

> **Peringatan penting**: Klausa `WHERE` pada `UPDATE` bersifat **wajib** untuk menargetkan baris tertentu. Jika klausa `WHERE` dihilangkan, **seluruh baris dalam tabel akan diperbarui**.

#### b. Update Multiple Kolom

```sql
-- Mengubah beberapa kolom sekaligus dalam satu baris
UPDATE siswa
SET kelas = '9C',
    nilai_rata_rata = 91.25,
    is_aktif = true
WHERE nis = '2026003';
```

**Penjelasan:** Setiap kolom yang diubah dipisahkan dengan tanda koma setelah klausa `SET`. Semua perubahan akan diterapkan secara atomik (semua berhasil atau semua gagal bersamaan).

### 8.4 DELETE

#### a. Delete dengan Kondisi

```sql
-- Menghapus data siswa dengan NIS tertentu
DELETE FROM siswa WHERE nis = '2026004';

-- Menghapus siswa yang sudah tidak aktif
DELETE FROM siswa WHERE is_aktif = false;
```

#### b. Delete Semua Data

```sql
-- Menghapus seluruh baris, namun struktur tabel tetap ada
DELETE FROM siswa;

-- Alternatif yang lebih cepat untuk mengosongkan tabel besar
TRUNCATE TABLE siswa;
```

**Perbedaan `DELETE` tanpa `WHERE` dan `TRUNCATE`:**

| Aspek | `DELETE FROM tabel` | `TRUNCATE TABLE tabel` |
|---|---|---|
| Kecepatan | Lebih lambat (baris dihapus satu per satu, dicatat di WAL) | Sangat cepat (mengosongkan halaman data langsung) |
| Trigger `ON DELETE` | Dipicu untuk setiap baris | Tidak dipicu |
| Reset `SERIAL`/auto-increment | Tidak reset | Dapat di-reset dengan `RESTART IDENTITY` |
| Bisa di-`ROLLBACK` dalam transaksi | Ya | Ya (di PostgreSQL) |

```sql
-- TRUNCATE dengan reset nilai SERIAL ke awal
TRUNCATE TABLE siswa RESTART IDENTITY;
```

> **Peringatan**: Sama seperti `UPDATE`, perintah `DELETE FROM tabel` tanpa `WHERE` akan **menghapus seluruh baris** dalam tabel. Selalu pastikan klausa `WHERE` sudah benar — disarankan untuk menjalankan `SELECT` dengan kondisi yang sama terlebih dahulu untuk memverifikasi baris mana yang akan terdampak.

---

## 9. Query Lanjutan

Pada bagian ini, kita menggunakan skema sederhana berikut sebagai contoh:

```sql
CREATE TABLE siswa (
    id SERIAL PRIMARY KEY,
    nama_lengkap VARCHAR(100),
    kelas_id INTEGER REFERENCES kelas(id)
);

CREATE TABLE kelas (
    id SERIAL PRIMARY KEY,
    nama_kelas VARCHAR(50)
);

CREATE TABLE nilai (
    id SERIAL PRIMARY KEY,
    siswa_id INTEGER REFERENCES siswa(id),
    mapel VARCHAR(50),
    nilai NUMERIC(5,2)
);
```

### 9.1 JOIN (INNER, LEFT, RIGHT)

**JOIN** digunakan untuk menggabungkan baris dari dua atau lebih tabel berdasarkan kolom yang berelasi.

```
INNER JOIN                  LEFT JOIN                    RIGHT JOIN
┌─────────┐                ┌─────────┐                  ┌─────────┐
│   A     │                │   A     │                  │   A     │
│  ┌──────┼──┐             │ ┌───────┼─┐                │   ┌─────┼───┐
│  │ Hasil│  │             │ │ Hasil │ │                │   │Hasil│   │
│  └──────┼──┘             │ │(semua)│ │                │   │(sm) │   │
└─────────┘                └─┴───────┴─┘                └───┴─────┴───┘
     B          Hanya baris      B    Semua dari A,           B   Semua dari B,
                yg cocok di             cocok dari B               cocok dari A
                kedua tabel
```

#### a. INNER JOIN

Mengembalikan baris yang **memiliki kecocokan di kedua tabel**.

```sql
-- Menampilkan nama siswa beserta nama kelasnya
SELECT s.nama_lengkap, k.nama_kelas
FROM siswa s
INNER JOIN kelas k ON s.kelas_id = k.id;
```

**Penjelasan:** Hanya siswa yang memiliki `kelas_id` valid (cocok dengan `id` pada tabel `kelas`) yang akan ditampilkan. Jika seorang siswa memiliki `kelas_id` bernilai `NULL` atau tidak cocok, baris tersebut **tidak akan muncul**.

#### b. LEFT JOIN

Mengembalikan **seluruh baris dari tabel kiri** (tabel pertama), beserta data yang cocok dari tabel kanan. Jika tidak ada kecocokan, kolom dari tabel kanan akan bernilai `NULL`.

```sql
-- Menampilkan semua siswa, termasuk yang belum memiliki kelas
SELECT s.nama_lengkap, k.nama_kelas
FROM siswa s
LEFT JOIN kelas k ON s.kelas_id = k.id;
```

**Penjelasan:** Cocok digunakan ketika ingin memastikan **semua data dari tabel utama tetap muncul**, meskipun relasinya belum lengkap. Contoh kasus: menampilkan semua siswa meski belum ditempatkan di kelas mana pun.

#### c. RIGHT JOIN

Kebalikan dari `LEFT JOIN` — mengembalikan **seluruh baris dari tabel kanan**, beserta data yang cocok dari tabel kiri.

```sql
-- Menampilkan semua kelas, termasuk kelas yang belum memiliki siswa
SELECT s.nama_lengkap, k.nama_kelas
FROM siswa s
RIGHT JOIN kelas k ON s.kelas_id = k.id;
```

> **Tips**: `RIGHT JOIN` jarang digunakan dalam praktik karena query yang sama selalu dapat ditulis sebagai `LEFT JOIN` dengan menukar urutan tabel. Sebagian besar pengembang lebih memilih konsistensi dengan selalu menggunakan `LEFT JOIN`.

### 9.2 Subquery

**Subquery** adalah query yang berada di dalam query lain, digunakan ketika hasil dari satu query diperlukan sebagai input bagi query lainnya.

```sql
-- Menampilkan siswa yang memiliki nilai mapel 'Matematika' di atas rata-rata
SELECT nama_lengkap
FROM siswa
WHERE id IN (
    SELECT siswa_id FROM nilai
    WHERE mapel = 'Matematika'
    AND nilai > (SELECT AVG(nilai) FROM nilai WHERE mapel = 'Matematika')
);
```

**Penjelasan:** Subquery terdalam `(SELECT AVG(nilai) FROM nilai WHERE mapel = 'Matematika')` menghitung nilai rata-rata mapel Matematika terlebih dahulu. Subquery kedua mengambil daftar `siswa_id` yang nilainya di atas rata-rata tersebut. Query utama kemudian menampilkan nama siswa berdasarkan daftar ID tersebut.

**Analogi:** Subquery seperti bertanya kepada seseorang, namun jawabannya bergantung pada hasil pertanyaan lain yang harus dijawab terlebih dahulu — "Berapa nilai rata-rata kelas?" harus dijawab dulu sebelum bisa menjawab "Siapa saja yang nilainya di atas rata-rata?".

### 9.3 GROUP BY dan HAVING

```sql
-- Menghitung jumlah siswa per kelas
SELECT k.nama_kelas, COUNT(s.id) AS jumlah_siswa
FROM siswa s
JOIN kelas k ON s.kelas_id = k.id
GROUP BY k.nama_kelas;

-- Menampilkan kelas dengan jumlah siswa lebih dari 20
SELECT k.nama_kelas, COUNT(s.id) AS jumlah_siswa
FROM siswa s
JOIN kelas k ON s.kelas_id = k.id
GROUP BY k.nama_kelas
HAVING COUNT(s.id) > 20;
```

**Penjelasan:**
- `GROUP BY` mengelompokkan baris berdasarkan nilai kolom tertentu, biasanya dikombinasikan dengan fungsi agregat.
- `HAVING` digunakan untuk **memfilter hasil setelah pengelompokan**, berbeda dengan `WHERE` yang memfilter **sebelum** pengelompokan.

> **Perbedaan penting**: `WHERE` tidak dapat digunakan dengan fungsi agregat secara langsung (misalnya `WHERE COUNT(s.id) > 20` akan menghasilkan error), karena `WHERE` dievaluasi sebelum data dikelompokkan. Untuk itu, gunakan `HAVING`.

### 9.4 Aggregate Function (COUNT, SUM, AVG, MAX, MIN)

```sql
-- Menghitung total siswa
SELECT COUNT(*) AS total_siswa FROM siswa;

-- Menghitung total nilai seluruh siswa untuk mapel Matematika
SELECT SUM(nilai) AS total_nilai FROM nilai WHERE mapel = 'Matematika';

-- Menghitung rata-rata nilai
SELECT AVG(nilai) AS rata_rata FROM nilai WHERE mapel = 'Matematika';

-- Mencari nilai tertinggi dan terendah
SELECT MAX(nilai) AS nilai_tertinggi, MIN(nilai) AS nilai_terendah
FROM nilai WHERE mapel = 'Matematika';
```

| Fungsi | Keterangan |
|---|---|
| `COUNT(*)` | Menghitung jumlah baris |
| `COUNT(kolom)` | Menghitung jumlah baris dengan nilai tidak `NULL` pada kolom tersebut |
| `SUM(kolom)` | Menjumlahkan nilai numerik |
| `AVG(kolom)` | Menghitung nilai rata-rata |
| `MAX(kolom)` | Mengambil nilai maksimum |
| `MIN(kolom)` | Mengambil nilai minimum |

### 9.5 CASE WHEN

`CASE WHEN` adalah ekspresi kondisional dalam SQL, mirip dengan struktur `if-else` pada bahasa pemrograman.

```sql
-- Memberikan keterangan kelulusan berdasarkan nilai
SELECT
    s.nama_lengkap,
    n.nilai,
    CASE
        WHEN n.nilai >= 90 THEN 'Sangat Baik'
        WHEN n.nilai >= 75 THEN 'Baik'
        WHEN n.nilai >= 60 THEN 'Cukup'
        ELSE 'Perlu Bimbingan'
    END AS keterangan
FROM siswa s
JOIN nilai n ON s.id = n.siswa_id
WHERE n.mapel = 'Matematika';
```

**Penjelasan:** PostgreSQL akan mengevaluasi setiap kondisi `WHEN` secara berurutan dari atas ke bawah, dan menggunakan nilai dari kondisi pertama yang terpenuhi (`TRUE`). Jika tidak ada kondisi yang terpenuhi, nilai dari `ELSE` akan digunakan. Klausa `ELSE` bersifat opsional — jika dihilangkan dan tidak ada kondisi yang cocok, hasilnya adalah `NULL`.

---

## 10. Index dan Optimasi

### 10.1 Apa itu Index

**Index** adalah struktur data tambahan yang membantu PostgreSQL menemukan baris-baris tertentu lebih cepat, tanpa harus memeriksa seluruh tabel baris demi baris (*sequential scan*).

**Analogi:** Index seperti daftar isi pada sebuah buku tebal. Tanpa daftar isi, untuk mencari topik "Transaction" pembaca harus membuka halaman satu per satu dari awal. Dengan daftar isi (index), pembaca dapat langsung melompat ke halaman yang dituju. Namun, daftar isi juga membutuhkan halaman tambahan (ruang penyimpanan) dan harus diperbarui setiap kali isi buku berubah (setiap kali ada `INSERT`/`UPDATE`/`DELETE`).

### 10.2 Cara Membuat Index: CREATE INDEX

```sql
-- Membuat index pada kolom 'nama_lengkap' di tabel siswa
CREATE INDEX idx_siswa_nama ON siswa (nama_lengkap);

-- Index unik (mencegah duplikasi sekaligus mempercepat pencarian)
CREATE UNIQUE INDEX idx_siswa_nis ON siswa (nis);

-- Index pada beberapa kolom (composite index)
CREATE INDEX idx_nilai_siswa_mapel ON nilai (siswa_id, mapel);

-- Menghapus index
DROP INDEX idx_siswa_nama;
```

**Penjelasan:** Secara default, PostgreSQL membuat index B-tree, yang cocok untuk sebagian besar kasus pencarian umum (`=`, `<`, `>`, `BETWEEN`, `ORDER BY`).

> **Catatan**: Kolom dengan `PRIMARY KEY` dan `UNIQUE` **otomatis** memiliki index, sehingga tidak perlu membuat index tambahan secara manual untuk kolom tersebut.

### 10.3 Kapan Menggunakan Index

**Gunakan index pada kolom yang:**
- Sering digunakan dalam klausa `WHERE`.
- Sering digunakan untuk `JOIN` (terutama kolom foreign key).
- Sering digunakan untuk `ORDER BY`.
- Memiliki nilai yang cukup unik/bervariasi (*high cardinality*).

**Hindari index berlebihan pada kolom yang:**
- Jarang digunakan dalam query.
- Memiliki nilai yang sangat sedikit variasinya (contoh: kolom `BOOLEAN` dengan hanya dua nilai mungkin tidak banyak membantu).
- Sering di-`UPDATE`/`INSERT` dalam volume besar — karena setiap perubahan data juga harus memperbarui index, yang dapat memperlambat operasi tulis.

**Analogi:** Membuat terlalu banyak daftar isi pada buku yang sama (satu per topik kecil) justru akan membuat buku menjadi tebal dan sulit diperbarui setiap kali ada revisi kecil. Index harus dibuat secara selektif, hanya pada bagian yang benar-benar sering "dicari".

### 10.4 EXPLAIN Query

`EXPLAIN` digunakan untuk melihat **rencana eksekusi** (*execution plan*) yang akan digunakan PostgreSQL untuk menjalankan sebuah query, tanpa benar-benar menjalankannya.

```sql
EXPLAIN SELECT * FROM siswa WHERE nis = '2026001';
```

Contoh output:

```
Seq Scan on siswa  (cost=0.00..18.50 rows=1 width=72)
  Filter: ((nis)::text = '2026001'::text)
```

Untuk melihat waktu eksekusi nyata, gunakan `EXPLAIN ANALYZE` (perintah ini **benar-benar menjalankan** query):

```sql
EXPLAIN ANALYZE SELECT * FROM siswa WHERE nis = '2026001';
```

Contoh output setelah index dibuat pada kolom `nis`:

```
Index Scan using idx_siswa_nis on siswa  (cost=0.15..8.17 rows=1 width=72)
  Index Cond: ((nis)::text = '2026001'::text)
  Planning Time: 0.085 ms
  Execution Time: 0.025 ms
```

**Penjelasan istilah penting:**
- `Seq Scan` (*Sequential Scan*) — PostgreSQL memeriksa seluruh baris tabel satu per satu. Cocok untuk tabel kecil, namun lambat untuk tabel besar.
- `Index Scan` — PostgreSQL menggunakan index untuk langsung menemukan baris yang relevan, jauh lebih efisien untuk tabel besar.
- `cost` — estimasi "biaya" (bukan waktu nyata) yang dibutuhkan, terdiri dari biaya awal dan biaya total.
- `rows` — estimasi jumlah baris yang akan dikembalikan.
- `Execution Time` — waktu nyata eksekusi (hanya muncul dengan `ANALYZE`).

> **Tips debugging query**: Jika sebuah query terasa lambat, langkah pertama adalah menjalankan `EXPLAIN ANALYZE`. Jika hasilnya menunjukkan `Seq Scan` pada tabel besar dengan kondisi `WHERE` spesifik, ini adalah indikasi kuat bahwa kolom tersebut membutuhkan index.

---

## 11. Backup & Restore

### 11.1 Backup Database: pg_dump

```bash
# Backup database 'sekolah' ke dalam file SQL (format plain text)
pg_dump -U postgres -d sekolah -f sekolah_backup.sql

# Backup dengan format custom (lebih ringkas dan mendukung restore selektif)
pg_dump -U postgres -d sekolah -F c -f sekolah_backup.dump
```

**Penjelasan opsi:**
- `-U postgres` — user yang digunakan untuk koneksi.
- `-d sekolah` — nama database yang akan dibackup.
- `-f` — nama file output.
- `-F c` — format *custom* (binary, terkompresi), diperlukan untuk menggunakan `pg_restore` dengan opsi lanjutan seperti restore tabel tertentu saja.

> Jika diminta password, masukkan password user PostgreSQL yang digunakan. Untuk menghindari input password interaktif (misalnya pada script otomatis), gunakan file `.pgpass` atau environment variable `PGPASSWORD`.

### 11.2 Restore Database: psql / pg_restore

#### a. Restore dari Format Plain SQL (psql)

```bash
# Membuat database tujuan terlebih dahulu (jika belum ada)
createdb -U postgres sekolah_baru

# Restore dari file .sql
psql -U postgres -d sekolah_baru -f sekolah_backup.sql
```

#### b. Restore dari Format Custom (pg_restore)

```bash
# Restore dari file .dump (format custom)
pg_restore -U postgres -d sekolah_baru sekolah_backup.dump

# Restore dengan opsi membuat database secara otomatis jika belum ada
pg_restore -U postgres -d sekolah_baru --create sekolah_backup.dump
```

**Penjelasan:** `pg_restore` hanya dapat digunakan untuk file hasil `pg_dump` dengan format selain *plain* (yaitu `custom`, `directory`, atau `tar`). Untuk format *plain* (`.sql`), gunakan `psql`.

### 11.3 Backup Semua Database

```bash
# Backup seluruh database beserta role/user dalam satu file
pg_dumpall -U postgres -f semua_database_backup.sql

# Restore seluruh database dari hasil pg_dumpall
psql -U postgres -f semua_database_backup.sql
```

**Penjelasan:** `pg_dumpall` berguna untuk migrasi server secara penuh, karena turut mencakup informasi global seperti role, password (terenkripsi), dan tablespace, yang tidak disertakan oleh `pg_dump` biasa (yang hanya membackup satu database).

| Tool | Cakupan | Format Output |
|---|---|---|
| `pg_dump` | Satu database | Plain SQL, Custom, Directory, Tar |
| `pg_dumpall` | Seluruh database + role/global objects | Plain SQL saja |
| `pg_restore` | Restore dari format Custom/Directory/Tar | - |
| `psql -f` | Restore dari format Plain SQL | - |

> **Rekomendasi praktik backup**: Jadwalkan backup otomatis secara berkala (misalnya menggunakan `cron`), simpan hasil backup di lokasi terpisah dari server utama (off-site), dan **uji proses restore secara berkala** — backup yang belum pernah diuji restore-nya tidak dapat dianggap sebagai backup yang andal.

---

## 12. Transaction

### 12.1 BEGIN, COMMIT, ROLLBACK

**Transaction** adalah sekumpulan operasi (`INSERT`, `UPDATE`, `DELETE`) yang diperlakukan sebagai satu unit kerja tunggal — **semua berhasil, atau semua dibatalkan**. Konsep ini dikenal sebagai prinsip **ACID** (Atomicity, Consistency, Isolation, Durability).

```sql
BEGIN;

UPDATE rekening SET saldo = saldo - 100000 WHERE id = 1;  -- kurangi saldo pengirim
UPDATE rekening SET saldo = saldo + 100000 WHERE id = 2;  -- tambah saldo penerima

COMMIT;
```

**Penjelasan:**
- `BEGIN` — memulai transaksi. Semua perintah setelah ini belum permanen sampai `COMMIT` dijalankan.
- `COMMIT` — menyimpan seluruh perubahan secara permanen ke database.
- `ROLLBACK` — membatalkan seluruh perubahan yang dilakukan sejak `BEGIN`, mengembalikan data ke kondisi sebelumnya.

```sql
BEGIN;

UPDATE rekening SET saldo = saldo - 100000 WHERE id = 1;
-- terjadi kesalahan / kondisi tidak terpenuhi

ROLLBACK;  -- membatalkan perubahan saldo di atas
```

### 12.2 Contoh Kasus Penggunaan

**Kasus: Transfer saldo antar rekening pada aplikasi perbankan.**

```sql
BEGIN;

-- 1. Periksa apakah saldo pengirim cukup
SELECT saldo FROM rekening WHERE id = 1;
-- (hasil: 500000, anggap cukup untuk transfer 100000)

-- 2. Kurangi saldo pengirim
UPDATE rekening SET saldo = saldo - 100000 WHERE id = 1;

-- 3. Tambah saldo penerima
UPDATE rekening SET saldo = saldo + 100000 WHERE id = 2;

-- 4. Catat riwayat transaksi
INSERT INTO riwayat_transaksi (dari_id, ke_id, jumlah, waktu)
VALUES (1, 2, 100000, now());

COMMIT;
```

**Mengapa transaksi penting di sini?** Jika langkah ke-2 berhasil (saldo pengirim sudah berkurang) namun langkah ke-3 gagal (misalnya karena koneksi terputus), tanpa transaksi maka **uang akan "hilang"** — sudah dikurangi dari pengirim, namun belum ditambahkan ke penerima. Dengan transaksi, jika terjadi kegagalan pada langkah mana pun, seluruh perubahan (langkah 2, 3, dan 4) akan otomatis dibatalkan (`ROLLBACK`) sehingga data tetap konsisten.

**Analogi:** Transaksi seperti proses tukar-menukar barang di meja yang dilakukan dengan kontrak — "Saya akan menyerahkan barang A, **dan** Anda menyerahkan barang B, **secara bersamaan**". Jika salah satu pihak membatalkan di tengah jalan, maka pertukaran dianggap **tidak pernah terjadi**, bukan setengah-setengah.

### 12.3 SAVEPOINT (Tambahan Lanjutan)

Untuk transaksi kompleks, PostgreSQL mendukung `SAVEPOINT` — titik kontrol di tengah transaksi yang memungkinkan rollback parsial.

```sql
BEGIN;

UPDATE rekening SET saldo = saldo - 100000 WHERE id = 1;

SAVEPOINT sebelum_transfer_kedua;

UPDATE rekening SET saldo = saldo - 50000 WHERE id = 1;

-- Jika terjadi masalah pada transfer kedua, batalkan hanya bagian ini
ROLLBACK TO SAVEPOINT sebelum_transfer_kedua;

COMMIT;  -- transfer pertama tetap tersimpan, transfer kedua dibatalkan
```

---

## 13. Security Best Practices

### 13.1 Manajemen User

- **Terapkan prinsip *least privilege*** — setiap user/aplikasi hanya diberi privilege minimum yang diperlukan untuk menjalankan tugasnya. Aplikasi web umumnya **tidak memerlukan** privilege `SUPERUSER`.
- **Gunakan role group** untuk mengelompokkan permission (lihat bagian 4.6), sehingga pengelolaan akses lebih terstruktur dan mudah diaudit.
- **Buat user terpisah untuk setiap aplikasi/layanan**, jangan menggunakan satu user (apalagi user `postgres`) untuk semua aplikasi. Ini memudahkan audit dan membatasi dampak jika kredensial salah satu aplikasi bocor.
- **Audit user secara berkala** dengan memeriksa daftar role dan privilege:

```sql
-- Menampilkan seluruh role dan atributnya
\du

-- Atau melalui SQL standar
SELECT rolname, rolsuper, rolcreatedb, rolcanlogin FROM pg_roles;
```

### 13.2 Enkripsi Password

PostgreSQL versi modern (13+) menggunakan algoritma `scram-sha-256` sebagai metode hashing password default, yang lebih aman dibandingkan `md5`.

Memastikan metode enkripsi yang digunakan:

```sql
SHOW password_encryption;
```

Jika hasilnya `md5`, ubah ke `scram-sha-256` di `postgresql.conf`:

```conf
password_encryption = scram-sha-256
```

> **Catatan**: Setelah mengubah `password_encryption`, password user yang **sudah ada** tidak otomatis terenkripsi ulang. User perlu mengganti passwordnya kembali (`ALTER USER ... WITH PASSWORD ...`) agar hash baru menggunakan algoritma yang baru.

### 13.3 Pengaturan Akses pg_hba.conf

- **Hindari metode `trust`** pada lingkungan produksi — metode ini memungkinkan koneksi tanpa password sama sekali.
- **Batasi `ADDRESS` seketat mungkin** — jangan gunakan `0.0.0.0/0` kecuali benar-benar diperlukan dan sudah dilindungi firewall/VPN.
- **Pisahkan akses berdasarkan database dan user**, jangan gunakan `all` secara default jika tidak diperlukan.

Contoh konfigurasi yang lebih aman dibandingkan konfigurasi default yang longgar:

```conf
# TYPE  DATABASE   USER            ADDRESS            METHOD

# Hanya user aplikasi yang boleh konek ke database aplikasinya, dari server aplikasi tertentu
host    sekolah    app_sekolah     10.0.0.5/32        scram-sha-256

# Admin hanya bisa konek dari jaringan internal kantor
host    all        admin_db        192.168.10.0/24    scram-sha-256
```

### 13.4 Tips Keamanan Database Tambahan

1. **Selalu gunakan koneksi terenkripsi (SSL/TLS)** untuk koneksi remote, dengan mengaktifkan `ssl = on` pada `postgresql.conf` dan mewajibkan `hostssl` (bukan `host`) pada `pg_hba.conf`.
2. **Jangan hardcode kredensial database** dalam kode sumber — gunakan environment variable atau secret manager.
3. **Update PostgreSQL secara berkala** untuk mendapatkan patch keamanan terbaru.
4. **Batasi akses jaringan dengan firewall** (misalnya `ufw` atau `iptables`), hanya izinkan port 5432 diakses dari IP yang dipercaya.
5. **Lakukan backup terenkripsi** dan simpan kredensial backup secara aman.
6. **Aktifkan logging untuk aktivitas mencurigakan**, misalnya percobaan login yang gagal, melalui parameter `log_connections` dan `log_disconnections` di `postgresql.conf`.

---

## 14. Studi Kasus: Sistem Sekolah

Pada bagian ini, kita akan membangun sistem database sederhana untuk pengelolaan data sekolah yang terdiri dari tiga entitas utama: **siswa**, **guru**, dan **kelas**.

### 14.1 Diagram Relasi Antar Tabel

```
┌────────────────┐         ┌────────────────┐         ┌────────────────┐
│      guru       │         │      kelas      │         │      siswa      │
├────────────────┤         ├────────────────┤         ├────────────────┤
│ id (PK)         │◀───────│ wali_kelas_id   │         │ id (PK)         │
│ nip             │         │ id (PK)         │◀───────│ kelas_id (FK)   │
│ nama_lengkap    │         │ nama_kelas      │         │ nis             │
│ email           │         │ tingkat         │         │ nama_lengkap    │
│ no_telepon      │         └────────────────┘         │ tanggal_lahir   │
└────────────────┘                                     │ jenis_kelamin   │
                                                         └────────────────┘
```

**Penjelasan relasi:**
- Satu `guru` dapat menjadi wali kelas untuk satu `kelas` (relasi one-to-one/one-to-many tergantung kebijakan, di sini diasumsikan satu guru bisa menjadi wali hanya satu kelas).
- Satu `kelas` dapat memiliki banyak `siswa` (relasi one-to-many).
- Setiap `siswa` hanya dimiliki oleh satu `kelas` pada satu waktu.

### 14.2 Membuat Struktur Tabel

```sql
-- Membuat database
CREATE DATABASE sekolah;

-- Setelah terhubung ke database 'sekolah' (\c sekolah), buat tabel berikut:

-- Tabel guru
CREATE TABLE guru (
    id SERIAL PRIMARY KEY,
    nip VARCHAR(20) NOT NULL UNIQUE,
    nama_lengkap VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE,
    no_telepon VARCHAR(15),
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Tabel kelas (memiliki FK ke guru sebagai wali kelas)
CREATE TABLE kelas (
    id SERIAL PRIMARY KEY,
    nama_kelas VARCHAR(50) NOT NULL,
    tingkat INTEGER CHECK (tingkat BETWEEN 1 AND 12),
    wali_kelas_id INTEGER REFERENCES guru(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Tabel siswa (memiliki FK ke kelas)
CREATE TABLE siswa (
    id SERIAL PRIMARY KEY,
    nis VARCHAR(20) NOT NULL UNIQUE,
    nama_lengkap VARCHAR(100) NOT NULL,
    tanggal_lahir DATE,
    jenis_kelamin CHAR(1) CHECK (jenis_kelamin IN ('L', 'P')),
    kelas_id INTEGER REFERENCES kelas(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);
```

**Penjelasan keputusan desain:**
- `wali_kelas_id ON DELETE SET NULL` — jika data guru dihapus, kelas tersebut tidak ikut terhapus, namun `wali_kelas_id` menjadi `NULL` (kelas menjadi "belum ada wali kelas").
- `kelas_id ON DELETE SET NULL` — jika sebuah kelas dihapus, siswa-siswa di dalamnya tidak ikut terhapus, namun menjadi "belum memiliki kelas", sehingga data siswa tetap aman.

### 14.3 Mengisi Data Awal

```sql
-- Insert data guru
INSERT INTO guru (nip, nama_lengkap, email, no_telepon) VALUES
('198501012010011001', 'Drs. I Wayan Sudiarta', 'wayan.sudiarta@sekolah.sch.id', '081234567001'),
('198703152011012002', 'Ni Made Ratih, S.Pd', 'made.ratih@sekolah.sch.id', '081234567002');

-- Insert data kelas, mereferensikan id guru yang baru dibuat
INSERT INTO kelas (nama_kelas, tingkat, wali_kelas_id) VALUES
('9A', 9, 1),
('9B', 9, 2);

-- Insert data siswa, mereferensikan id kelas
INSERT INTO siswa (nis, nama_lengkap, tanggal_lahir, jenis_kelamin, kelas_id) VALUES
('2026001', 'Ni Putu Sena Wardani', '2011-03-12', 'P', 1),
('2026002', 'Made Wira Adiputra', '2011-07-25', 'L', 1),
('2026003', 'Kadek Ayu Lestari', '2011-01-30', 'P', 2);
```

### 14.4 Contoh Query CRUD Lengkap

#### a. CREATE — Menambahkan Siswa Baru ke Kelas 9B

```sql
INSERT INTO siswa (nis, nama_lengkap, tanggal_lahir, jenis_kelamin, kelas_id)
VALUES ('2026004', 'I Komang Bagus Surya', '2011-09-18', 'L', 2);
```

#### b. READ — Menampilkan Daftar Siswa Lengkap dengan Nama Kelas dan Wali Kelas

```sql
SELECT
    s.nis,
    s.nama_lengkap,
    s.jenis_kelamin,
    k.nama_kelas,
    g.nama_lengkap AS nama_wali_kelas
FROM siswa s
LEFT JOIN kelas k ON s.kelas_id = k.id
LEFT JOIN guru g ON k.wali_kelas_id = g.id
ORDER BY k.nama_kelas, s.nama_lengkap;
```

**Penjelasan:** Query ini menggabungkan tiga tabel menggunakan `LEFT JOIN` agar siswa yang belum memiliki kelas (atau kelas yang belum memiliki wali kelas) tetap muncul dalam hasil, dengan nilai `NULL` pada kolom yang relevan.

#### c. READ — Menghitung Jumlah Siswa per Kelas

```sql
SELECT
    k.nama_kelas,
    COUNT(s.id) AS jumlah_siswa
FROM kelas k
LEFT JOIN siswa s ON s.kelas_id = k.id
GROUP BY k.nama_kelas
ORDER BY k.nama_kelas;
```

#### d. UPDATE — Memindahkan Siswa ke Kelas Lain

```sql
-- Memindahkan siswa dengan NIS '2026003' dari kelas 9B ke kelas 9A
UPDATE siswa
SET kelas_id = (SELECT id FROM kelas WHERE nama_kelas = '9A')
WHERE nis = '2026003';
```

**Penjelasan:** Subquery `(SELECT id FROM kelas WHERE nama_kelas = '9A')` digunakan agar kita tidak perlu mengetahui `id` numerik kelas secara manual — cukup merujuk berdasarkan nama kelas yang lebih mudah diingat.

#### e. UPDATE — Mengganti Wali Kelas

```sql
UPDATE kelas
SET wali_kelas_id = (SELECT id FROM guru WHERE nip = '198703152011012002')
WHERE nama_kelas = '9A';
```

#### f. DELETE — Menghapus Siswa Berdasarkan NIS

```sql
DELETE FROM siswa WHERE nis = '2026004';
```

#### g. Query Analisis — Mencari Siswa yang Belum Ditempatkan di Kelas Mana Pun

```sql
SELECT nis, nama_lengkap
FROM siswa
WHERE kelas_id IS NULL;
```

**Penjelasan:** Berguna untuk laporan administrasi, misalnya menemukan siswa baru yang belum dialokasikan ke kelas tertentu di awal tahun ajaran.

---

## 15. Tips & Best Practice PostgreSQL

### 15.1 Naming Convention

Konsistensi penamaan objek database sangat penting untuk keterbacaan dan kemudahan maintenance jangka panjang.

| Objek | Konvensi | Contoh |
|---|---|---|
| Tabel | `snake_case`, bentuk **jamak** atau **tunggal** (konsisten), huruf kecil | `siswa`, `mata_pelajaran` |
| Kolom | `snake_case`, deskriptif | `nama_lengkap`, `tanggal_lahir` |
| Primary key | `id` | `id` |
| Foreign key | `<nama_tabel_tunggal>_id` | `kelas_id`, `guru_id` |
| Index | `idx_<tabel>_<kolom>` | `idx_siswa_nis` |
| Constraint | `<tipe>_<tabel>_<kolom>` | `chk_guru_gaji`, `uq_siswa_nis` |
| Fungsi/Trigger | `fn_<tujuan>`, `trg_<tujuan>` | `fn_hitung_nilai_akhir`, `trg_update_timestamp` |

> **Tips**: Hindari penggunaan huruf kapital pada nama objek (tabel/kolom). PostgreSQL bersifat *case-sensitive* untuk identifier yang diberi tanda kutip ganda (`"NamaTabel"`), yang sering menyebabkan kebingungan. Gunakan `snake_case` huruf kecil secara konsisten agar tidak perlu menulis tanda kutip sama sekali.

### 15.2 Struktur Database yang Baik

1. **Terapkan normalisasi yang wajar** (umumnya hingga 3NF/Third Normal Form) — hindari duplikasi data, namun jangan terlalu ekstrem hingga query menjadi sangat kompleks (*over-normalization*).
2. **Selalu sertakan kolom audit** seperti `created_at` dan `updated_at` (bertipe `TIMESTAMPTZ`) pada setiap tabel utama, untuk keperluan pelacakan dan debugging.
3. **Gunakan `SERIAL`/`BIGSERIAL` atau `UUID` secara konsisten** sebagai primary key di seluruh sistem — jangan mencampur strategi tanpa alasan jelas.
4. **Definisikan foreign key secara eksplisit** dengan aturan `ON DELETE`/`ON UPDATE` yang sesuai kebutuhan bisnis, jangan dibiarkan default begitu saja.
5. **Gunakan schema** (`CREATE SCHEMA`) untuk memisahkan grup tabel pada aplikasi besar/multi-modul, misalnya schema `akademik`, `keuangan`, `inventaris`.

### 15.3 Optimasi Query

1. **Hindari `SELECT *`** pada kode aplikasi produksi — sebutkan kolom yang benar-benar dibutuhkan untuk mengurangi transfer data dan meningkatkan keterbacaan.
2. **Gunakan `EXPLAIN ANALYZE`** secara rutin saat menulis query kompleks atau ketika query terasa lambat.
3. **Buat index pada kolom foreign key dan kolom yang sering difilter**, namun hindari index berlebihan (lihat bagian 10.3).
4. **Gunakan `LIMIT`** saat melakukan eksplorasi data pada tabel besar, agar tidak menarik jutaan baris secara tidak sengaja.
5. **Pertimbangkan *connection pooling*** (misalnya menggunakan PgBouncer) untuk aplikasi dengan banyak koneksi singkat, karena setiap koneksi PostgreSQL adalah proses terpisah yang relatif "berat".
6. **Jalankan `VACUUM` dan `ANALYZE` secara berkala** (umumnya sudah ditangani otomatis oleh `autovacuum`), untuk membersihkan baris-baris yang sudah "mati" akibat `UPDATE`/`DELETE` dan memperbarui statistik query planner.

```sql
-- Memperbarui statistik tabel secara manual (membantu query planner membuat keputusan lebih baik)
ANALYZE siswa;

-- Membersihkan ruang yang tidak terpakai akibat UPDATE/DELETE
VACUUM siswa;
```

### 15.4 Error Handling

Saat menulis fungsi atau prosedur (PL/pgSQL), gunakan blok `EXCEPTION` untuk menangani error secara terkontrol:

```sql
DO $$
BEGIN
    INSERT INTO siswa (nis, nama_lengkap) VALUES ('2026001', 'Duplikat Test');
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'NIS sudah terdaftar, data tidak disimpan.';
    WHEN OTHERS THEN
        RAISE NOTICE 'Terjadi error tidak terduga: %', SQLERRM;
END $$;
```

**Penjelasan:**
- `unique_violation` adalah kode error spesifik yang terjadi ketika constraint `UNIQUE` dilanggar.
- `WHEN OTHERS` menangkap seluruh jenis error lain yang belum ditangani secara spesifik, dan `SQLERRM` menampilkan pesan error aslinya.
- Pendekatan ini umum digunakan dalam *trigger* atau *stored procedure* untuk validasi data yang lebih kompleks.

Pada level aplikasi (misalnya Laravel), penanganan error dilakukan dengan menangkap exception dari query builder/Eloquent:

```php
try {
    DB::table('siswa')->insert([
        'nis' => '2026001',
        'nama_lengkap' => 'Duplikat Test',
    ]);
} catch (\Illuminate\Database\QueryException $e) {
    if ($e->getCode() === '23505') { // kode error unique_violation
        // tangani duplikasi NIS
    }
    throw $e;
}
```

---

## 16. Error Umum dan Cara Mengatasinya

| Pesan Error | Penyebab Umum | Cara Mengatasi |
|---|---|---|
| `FATAL: password authentication failed for user "..."` | Password salah, atau metode otentikasi di `pg_hba.conf` tidak sesuai | Periksa kembali password; pastikan baris `pg_hba.conf` untuk user/database tersebut menggunakan metode yang benar (`scram-sha-256`/`md5`), lalu `reload` service |
| `FATAL: no pg_hba.conf entry for host "..."` | Tidak ada baris konfigurasi yang cocok dengan IP/koneksi tersebut | Tambahkan baris yang sesuai di `pg_hba.conf` untuk IP, database, dan user yang relevan, lalu `reload` |
| `ERROR: relation "siswa" does not exist` | Nama tabel salah ketik, atau berada di schema/database yang berbeda dari yang sedang aktif | Periksa nama tabel dengan `\dt`, pastikan terhubung ke database yang benar (`\c namadb`) |
| `ERROR: duplicate key value violates unique constraint` | Mencoba memasukkan nilai yang sudah ada pada kolom `UNIQUE`/`PRIMARY KEY` | Periksa data yang akan di-insert, gunakan `ON CONFLICT` jika perlu menangani duplikasi |
| `ERROR: null value in column "..." violates not-null constraint` | Kolom wajib (`NOT NULL`) tidak diisi saat `INSERT` | Pastikan semua kolom `NOT NULL` tanpa `DEFAULT` diberikan nilai |
| `ERROR: insert or update on table "..." violates foreign key constraint` | Nilai foreign key merujuk ke baris yang tidak ada di tabel induk | Pastikan data induk (misalnya `kelas_id`) sudah ada sebelum menambahkan data anak (misalnya `siswa`) |
| `ERROR: syntax error at or near "..."` | Kesalahan penulisan sintaks SQL (tanda koma, tanda kutip, kata kunci) | Periksa kembali struktur query, perhatikan tanda kutip tunggal untuk string dan tanda kutip ganda untuk identifier |
| `ERROR: column "..." does not exist` | Nama kolom salah ketik, atau lupa alias tabel pada `JOIN` | Periksa nama kolom dengan `\d nama_tabel`, pastikan alias digunakan dengan konsisten |
| `FATAL: database "..." does not exist` | Salah nama database saat koneksi, atau database belum dibuat | Periksa daftar database dengan `\l`, buat database jika belum ada |
| `ERROR: permission denied for table "..."` | User tidak memiliki privilege yang cukup | Jalankan `GRANT` privilege yang sesuai dari user dengan hak akses lebih tinggi |
| `ERROR: current transaction is aborted, commands ignored until end of transaction block` | Salah satu query dalam transaksi gagal, namun transaksi belum di-`ROLLBACK`/`COMMIT` | Jalankan `ROLLBACK` untuk membatalkan transaksi yang error, lalu mulai transaksi baru |
| `could not connect to server: Connection refused` | Service PostgreSQL belum berjalan, atau salah port/host | Cek status service (`systemctl status postgresql`), pastikan `listen_addresses` dan port sudah benar |

### 16.1 Tips Debugging Query SQL

1. **Baca pesan error dari bawah ke atas** — PostgreSQL sering menampilkan konteks tambahan (`HINT:`, `DETAIL:`, `CONTEXT:`) yang sangat membantu menentukan lokasi masalah sebenarnya.
2. **Sederhanakan query secara bertahap** — jika query kompleks dengan banyak `JOIN` gagal, coba jalankan bagian per bagian (misalnya satu `JOIN` dahulu) untuk mengisolasi sumber error.
3. **Gunakan `\d nama_tabel` pada `psql`** untuk memastikan struktur tabel (nama kolom, tipe data, constraint) sesuai dengan yang diasumsikan dalam query.
4. **Periksa tipe data saat membandingkan kolom** — error seperti `operator does not exist: integer = text` menunjukkan ketidaksesuaian tipe data, yang dapat diatasi dengan `CAST` atau `::tipe_data`.
5. **Untuk error transaksi yang "macet"**, selalu jalankan `ROLLBACK` sebelum mencoba query lain dalam sesi yang sama.
6. **Gunakan `RAISE NOTICE`** di dalam fungsi/blok PL/pgSQL untuk menampilkan nilai variabel pada titik tertentu saat debugging logic yang kompleks.

---

## 17. Studi Kasus Tambahan: Sistem Kasir Sederhana

Sebagai pelengkap, berikut adalah rancangan database untuk sistem kasir (Point of Sale/POS) sederhana, yang menerapkan banyak konsep yang telah dibahas sebelumnya: relasi antar tabel, tipe data `NUMERIC` untuk uang, `JSONB`, transaksi, dan agregasi.

### 17.1 Diagram Relasi

```
┌────────────────┐       ┌────────────────────┐       ┌────────────────┐
│     produk      │       │   transaksi          │       │ detail_transaksi │
├────────────────┤       ├────────────────────┤       ├────────────────┤
│ id (PK)         │◀──────┼─ produk_id (FK)      │       │ id (PK)          │
│ nama_produk     │       │ id (PK)              │◀──────┤ transaksi_id (FK)│
│ harga           │       │ kode_transaksi       │       │ produk_id (FK)   │
│ stok            │       │ total_bayar          │       │ jumlah           │
└────────────────┘       │ metode_pembayaran    │       │ harga_satuan     │
                          │ waktu_transaksi      │       │ subtotal         │
                          └────────────────────┘       └────────────────┘
```

### 17.2 Membuat Struktur Tabel

```sql
CREATE DATABASE kasir;
-- \c kasir

-- Tabel produk
CREATE TABLE produk (
    id SERIAL PRIMARY KEY,
    nama_produk VARCHAR(100) NOT NULL,
    harga NUMERIC(12,2) NOT NULL CHECK (harga >= 0),
    stok INTEGER NOT NULL DEFAULT 0 CHECK (stok >= 0),
    kategori VARCHAR(50),
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Tabel transaksi (header)
CREATE TABLE transaksi (
    id SERIAL PRIMARY KEY,
    kode_transaksi VARCHAR(20) NOT NULL UNIQUE,
    total_bayar NUMERIC(12,2) NOT NULL DEFAULT 0,
    metode_pembayaran VARCHAR(20) CHECK (metode_pembayaran IN ('tunai', 'kartu', 'qris')),
    waktu_transaksi TIMESTAMPTZ DEFAULT now()
);

-- Tabel detail_transaksi (item per transaksi)
CREATE TABLE detail_transaksi (
    id SERIAL PRIMARY KEY,
    transaksi_id INTEGER NOT NULL REFERENCES transaksi(id) ON DELETE CASCADE,
    produk_id INTEGER NOT NULL REFERENCES produk(id),
    jumlah INTEGER NOT NULL CHECK (jumlah > 0),
    harga_satuan NUMERIC(12,2) NOT NULL,
    subtotal NUMERIC(12,2) NOT NULL
);
```

**Penjelasan keputusan desain:**
- `transaksi` dan `detail_transaksi` dipisah (pola *header-detail*), karena satu transaksi (struk) bisa terdiri dari banyak item produk.
- `harga_satuan` disimpan ulang pada `detail_transaksi` (bukan hanya mengandalkan `produk.harga`), agar **histori transaksi tidak berubah** meskipun harga produk berubah di kemudian hari.
- `detail_transaksi.transaksi_id ON DELETE CASCADE` — jika satu transaksi dihapus (misal pembatalan), seluruh detail itemnya ikut terhapus otomatis.

### 17.3 Mengisi Data Awal

```sql
INSERT INTO produk (nama_produk, harga, stok, kategori) VALUES
('Kopi Hitam', 8000, 100, 'Minuman'),
('Nasi Goreng', 18000, 50, 'Makanan'),
('Es Teh Manis', 5000, 100, 'Minuman');
```

### 17.4 Contoh Transaksi Penjualan (Menggunakan Transaction)

Skenario: pelanggan membeli 2 Kopi Hitam dan 1 Nasi Goreng, dibayar tunai.

```sql
BEGIN;

-- 1. Buat header transaksi
INSERT INTO transaksi (kode_transaksi, metode_pembayaran)
VALUES ('TRX-20260613-001', 'tunai')
RETURNING id;
-- (anggap hasilnya: id = 1)

-- 2. Tambahkan detail item: Kopi Hitam (2x @ 8.000)
INSERT INTO detail_transaksi (transaksi_id, produk_id, jumlah, harga_satuan, subtotal)
VALUES (1, 1, 2, 8000, 16000);

-- 3. Tambahkan detail item: Nasi Goreng (1x @ 18.000)
INSERT INTO detail_transaksi (transaksi_id, produk_id, jumlah, harga_satuan, subtotal)
VALUES (1, 2, 1, 18000, 18000);

-- 4. Kurangi stok produk sesuai pembelian
UPDATE produk SET stok = stok - 2 WHERE id = 1;  -- Kopi Hitam
UPDATE produk SET stok = stok - 1 WHERE id = 2;  -- Nasi Goreng

-- 5. Update total_bayar pada header transaksi (16000 + 18000 = 34000)
UPDATE transaksi SET total_bayar = 34000 WHERE id = 1;

COMMIT;
```

**Penjelasan:** `RETURNING id` adalah fitur khas PostgreSQL yang mengembalikan nilai kolom (misalnya `id` hasil `SERIAL`) langsung setelah `INSERT`, tanpa perlu query `SELECT` tambahan — sangat berguna untuk mendapatkan ID transaksi yang baru dibuat untuk digunakan pada `INSERT` berikutnya.

Seluruh langkah dibungkus dalam satu `BEGIN ... COMMIT` karena jika salah satu langkah gagal (misalnya stok tidak cukup), seluruh transaksi penjualan harus dibatalkan agar data stok dan laporan keuangan tetap konsisten.

### 17.5 Contoh Query Laporan

```sql
-- Laporan penjualan per produk (jumlah terjual dan total pendapatan)
SELECT
    p.nama_produk,
    SUM(dt.jumlah) AS total_terjual,
    SUM(dt.subtotal) AS total_pendapatan
FROM detail_transaksi dt
JOIN produk p ON dt.produk_id = p.id
GROUP BY p.nama_produk
ORDER BY total_pendapatan DESC;

-- Laporan total penjualan harian
SELECT
    DATE(waktu_transaksi) AS tanggal,
    COUNT(*) AS jumlah_transaksi,
    SUM(total_bayar) AS total_pendapatan
FROM transaksi
GROUP BY DATE(waktu_transaksi)
ORDER BY tanggal DESC;

-- Mencari produk dengan stok menipis (di bawah 10)
SELECT nama_produk, stok
FROM produk
WHERE stok < 10
ORDER BY stok ASC;
```

---

## Penutup

Modul ini telah membahas PostgreSQL secara komprehensif, mulai dari konsep dasar RDBMS, instalasi, konfigurasi, manajemen user dan database, tipe data, manajemen tabel, operasi CRUD, query lanjutan, indexing, backup/restore, transaksi, hingga praktik keamanan dan studi kasus nyata.

**Saran langkah selanjutnya untuk pembelajaran lebih lanjut:**

1. Pelajari **PL/pgSQL** secara lebih dalam untuk membuat *function*, *trigger*, dan *stored procedure*.
2. Pelajari **window functions** (`ROW_NUMBER()`, `RANK()`, `LAG()`, `LEAD()`) untuk analisis data tingkat lanjut.
3. Pelajari **partitioning tabel** untuk menangani dataset yang sangat besar.
4. Pelajari **replikasi dan high availability** untuk kebutuhan produksi skala besar.
5. Praktikkan langsung pada proyek nyata — dokumentasi ini dapat digunakan sebagai referensi sambil mengerjakan studi kasus serupa pada proyek yang sedang dikembangkan.

---

*Dokumen ini disusun sebagai modul pembelajaran dan referensi kerja PostgreSQL. Semua contoh query telah disesuaikan dengan kasus penggunaan dunia nyata (sistem sekolah dan sistem kasir) agar mudah dipahami dan diterapkan langsung.*
