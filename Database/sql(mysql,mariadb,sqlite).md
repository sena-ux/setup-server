# 📚 Dokumentasi SQL Lengkap: MySQL, MariaDB & SQLite
### Panduan Komprehensif untuk Pemula hingga Profesional

> **Versi:** 1.0.0 | **Bahasa:** Indonesia | **Level:** Pemula hingga Menengah

---

## Daftar Isi

1. [Pendahuluan](#1-pendahuluan)
2. [Instalasi & Setup](#2-instalasi--setup)
3. [Koneksi Database](#3-koneksi-database)
4. [Manajemen Database](#4-manajemen-database)
5. [Tipe Data](#5-tipe-data)
6. [Table Management](#6-table-management)
7. [CRUD Operations](#7-crud-operations)
8. [Query Lanjutan](#8-query-lanjutan)
9. [Index & Optimasi](#9-index--optimasi)
10. [Transaction](#10-transaction)
11. [User & Privilege](#11-user--privilege)
12. [Backup & Restore](#12-backup--restore)
13. [Tabel Perbandingan](#13-tabel-perbandingan)
14. [Studi Kasus: Sistem Kasir](#14-studi-kasus-sistem-kasir)
15. [Error Umum & Cara Mengatasinya](#15-error-umum--cara-mengatasinya)
16. [Tips Debugging Query SQL](#16-tips-debugging-query-sql)
17. [Best Practice](#17-best-practice)

---

## 1. Pendahuluan

### 1.1 Apa itu SQL?

**SQL** (Structured Query Language) adalah bahasa standar yang digunakan untuk berkomunikasi dengan database relasional. SQL memungkinkan kita untuk:

- **Menyimpan** data ke dalam tabel
- **Mengambil** data berdasarkan kondisi tertentu
- **Memperbarui** data yang sudah ada
- **Menghapus** data yang tidak diperlukan
- **Mengelola** struktur database

> **Analogi:** Bayangkan database seperti sebuah lemari arsip raksasa. SQL adalah "bahasa" yang Anda gunakan untuk memberi instruksi kepada petugas arsip: "Ambilkan semua dokumen dari laci A yang bertanggal setelah Januari 2024" — itulah SQL.

### 1.2 Gambaran Umum Tiga Database

```
┌─────────────────────────────────────────────────────────────────┐
│                    EKOSISTEM DATABASE SQL                        │
│                                                                  │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────────────┐ │
│  │    MySQL     │   │   MariaDB    │   │       SQLite         │ │
│  │              │   │              │   │                      │ │
│  │  🌐 Server   │   │  🌐 Server   │   │  📁 File-based       │ │
│  │  Eksternal   │   │  Eksternal   │   │  Embedded            │ │
│  │              │   │              │   │                      │ │
│  │  Port: 3306  │   │  Port: 3306  │   │  Tanpa Port          │ │
│  │  Multi-user  │   │  Multi-user  │   │  Single-file         │ │
│  │  Oracle Corp │   │  Open Source │   │  Serverless          │ │
│  └──────────────┘   └──────────────┘   └──────────────────────┘ │
│                                                                  │
│         CLIENT-SERVER MODEL              EMBEDDED MODEL          │
│  ┌────────┐   TCP/IP   ┌────────┐   ┌────────────────────────┐  │
│  │  App   │ ─────────► │  DB   │   │  App + DB dalam 1 file  │  │
│  │(Client)│            │Server  │   │                         │  │
│  └────────┘            └────────┘   └────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### 1.3 Penjelasan Masing-Masing

#### 🐬 MySQL
MySQL adalah sistem manajemen database relasional (RDBMS) yang paling populer di dunia web. Dikembangkan oleh MySQL AB dan kini dimiliki oleh Oracle Corporation.

**Karakteristik:**
- Arsitektur client-server
- Sangat populer di ekosistem LAMP (Linux, Apache, MySQL, PHP)
- Performa tinggi untuk aplikasi web berskala besar
- Mendukung replikasi dan clustering

#### 🦭 MariaDB
MariaDB adalah *fork* (turunan) dari MySQL yang dibuat oleh pendiri asli MySQL setelah akuisisi Oracle. Dirancang sebagai pengganti drop-in yang 100% kompatibel dengan MySQL.

**Karakteristik:**
- Kompatibel hampir penuh dengan MySQL
- Sepenuhnya open-source (GPL)
- Fitur tambahan seperti Aria storage engine
- Perkembangan komunitas lebih aktif

#### 🪶 SQLite
SQLite adalah database yang tertanam langsung di dalam aplikasi (embedded). Seluruh database disimpan dalam satu file `.db`.

**Karakteristik:**
- Tidak memerlukan server terpisah
- Satu file = satu database
- Digunakan di Android, iOS, browser, dan aplikasi desktop
- Tidak cocok untuk akses multi-user bersamaan

### 1.4 Kapan Menggunakan Masing-Masing?

```
PANDUAN PEMILIHAN DATABASE
═══════════════════════════════════════════════════════════════
Pertanyaan Kunci                           Rekomendasi
═══════════════════════════════════════════════════════════════
Apakah aplikasi diakses banyak user        → MySQL / MariaDB
  secara bersamaan?

Apakah ini proyek open-source murni?       → MariaDB

Apakah ini aplikasi mobile/desktop         → SQLite
  yang berdiri sendiri?

Apakah perlu fitur enterprise lanjutan?    → MySQL (Enterprise)

Apakah ini untuk prototipe/testing?        → SQLite

Apakah butuh replikasi & clustering?       → MySQL / MariaDB

Apakah butuh database lokal di browser?   → SQLite (via WebAssembly)
═══════════════════════════════════════════════════════════════
```

---

## 2. Instalasi & Setup

### 2.1 MySQL

#### Instalasi di Ubuntu/Debian

```bash
# Update package list
sudo apt update

# Install MySQL Server
sudo apt install mysql-server -y

# Jalankan skrip keamanan awal
sudo mysql_secure_installation
```

#### Instalasi di CentOS/RHEL/Fedora

```bash
# Install MySQL repository
sudo yum install mysql-server -y
# atau menggunakan dnf (Fedora/RHEL 8+)
sudo dnf install mysql-server -y
```

#### Menjalankan Service MySQL

```bash
# Mulai service
sudo systemctl start mysql

# Aktifkan agar berjalan saat boot
sudo systemctl enable mysql

# Cek status service
sudo systemctl status mysql

# Restart service
sudo systemctl restart mysql

# Stop service
sudo systemctl stop mysql
```

#### Login ke MySQL

```bash
# Login sebagai root (Ubuntu)
sudo mysql

# Login dengan password
mysql -u root -p

# Login ke host tertentu
mysql -u username -p -h 192.168.1.100 -P 3306

# Login langsung ke database tertentu
mysql -u username -p nama_database
```

### 2.2 MariaDB

#### Instalasi di Ubuntu/Debian

```bash
# Update package list
sudo apt update

# Install MariaDB Server (bukan mysql-server!)
sudo apt install mariadb-server mariadb-client -y

# Jalankan skrip keamanan
sudo mysql_secure_installation
```

#### Instalasi di CentOS/RHEL

```bash
sudo yum install mariadb-server mariadb -y
# atau
sudo dnf install mariadb-server mariadb -y
```

#### Menjalankan Service MariaDB

```bash
# Mulai service (nama service: mariadb, bukan mysql)
sudo systemctl start mariadb

# Aktifkan agar berjalan saat boot
sudo systemctl enable mariadb

# Cek status
sudo systemctl status mariadb
```

> **⚠️ Catatan Perbedaan:** Di MariaDB, nama service adalah `mariadb`, sedangkan di MySQL adalah `mysql`. Namun pada beberapa distro, kedua nama tersebut bisa saling alias.

#### Login ke MariaDB

```bash
# Sama persis dengan MySQL
mysql -u root -p

# Atau menggunakan binary MariaDB langsung
mariadb -u root -p
```

### 2.3 SQLite

#### Instalasi

```bash
# Ubuntu/Debian
sudo apt install sqlite3 -y

# CentOS/RHEL
sudo yum install sqlite -y

# macOS (sudah terinstall, atau via Homebrew)
brew install sqlite

# Verifikasi instalasi
sqlite3 --version
```

> **💡 Tidak Ada Service!** SQLite tidak memiliki service yang berjalan di background. Setiap kali Anda membuka file `.db`, SQLite langsung membacanya — tidak perlu start/stop server.

#### Menggunakan CLI sqlite3

```bash
# Membuka atau membuat database baru
sqlite3 nama_database.db

# Membuka database dengan mode verbose
sqlite3 -echo nama_database.db

# Menjalankan perintah SQL dari file
sqlite3 nama_database.db < script.sql

# Menjalankan query langsung dari terminal
sqlite3 nama_database.db "SELECT * FROM produk;"
```

#### Perintah Khusus SQLite CLI (diawali titik)

```sql
-- Melihat daftar tabel
.tables

-- Melihat struktur tabel
.schema nama_tabel

-- Mode output yang lebih rapi
.mode column
.headers on

-- Export ke CSV
.mode csv
.output hasil.csv
SELECT * FROM produk;
.output stdout

-- Keluar dari SQLite
.quit
```

---

## 3. Koneksi Database

### 3.1 MySQL & MariaDB — CLI

```bash
# Format lengkap
mysql -u [username] -p[password] -h [host] -P [port] [nama_database]

# Contoh praktis
mysql -u root -p                          # Login lokal sebagai root
mysql -u admin -p mydb                    # Login ke database 'mydb'
mysql -u user -p -h 10.0.0.5 -P 3306     # Login ke server remote
```

### 3.2 Koneksi dari Aplikasi

#### PHP (MySQLi / PDO)

```php
<?php
// Menggunakan PDO (kompatibel MySQL & MariaDB)
$dsn = "mysql:host=localhost;dbname=toko;charset=utf8mb4";
$username = "root";
$password = "secret";

try {
    $pdo = new PDO($dsn, $username, $password, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);
    echo "Koneksi berhasil!";
} catch (PDOException $e) {
    echo "Koneksi gagal: " . $e->getMessage();
}
?>
```

#### Python

```python
# MySQL / MariaDB menggunakan mysql-connector-python
import mysql.connector

conn = mysql.connector.connect(
    host="localhost",
    user="root",
    password="secret",
    database="toko"
)
cursor = conn.cursor()
cursor.execute("SELECT * FROM produk")
hasil = cursor.fetchall()
conn.close()

# SQLite (built-in Python, tanpa install tambahan!)
import sqlite3

conn = sqlite3.connect("toko.db")    # Buat/buka file database
cursor = conn.cursor()
cursor.execute("SELECT * FROM produk")
hasil = cursor.fetchall()
conn.close()
```

#### Node.js

```javascript
// MySQL / MariaDB
const mysql = require('mysql2/promise');

const conn = await mysql.createConnection({
  host: 'localhost',
  user: 'root',
  password: 'secret',
  database: 'toko'
});

const [rows] = await conn.execute('SELECT * FROM produk');
await conn.end();

// SQLite menggunakan better-sqlite3
const Database = require('better-sqlite3');
const db = new Database('toko.db');

const rows = db.prepare('SELECT * FROM produk').all();
db.close();
```

### 3.3 SQLite — Membuka Database

```bash
# Membuka database yang sudah ada
sqlite3 toko.db

# Jika file belum ada, SQLite akan membuat file baru
sqlite3 database_baru.db

# Database in-memory (hanya untuk sesi ini, tidak disimpan ke file)
sqlite3 :memory:
```

---

## 4. Manajemen Database

### 4.1 Membuat Database

```sql
-- MySQL & MariaDB
CREATE DATABASE toko;

-- Dengan encoding yang eksplisit (sangat direkomendasikan untuk teks Indonesia)
CREATE DATABASE toko CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Dengan pengecekan apakah sudah ada
CREATE DATABASE IF NOT EXISTS toko;
```

> **📝 SQLite:** Tidak ada perintah `CREATE DATABASE`. Database = file `.db`. Saat Anda membuka file baru dengan `sqlite3 toko.db`, database langsung terbuat.

### 4.2 Melihat Daftar Database

```sql
-- MySQL & MariaDB
SHOW DATABASES;

-- Output contoh:
-- +--------------------+
-- | Database           |
-- +--------------------+
-- | information_schema |
-- | mysql              |
-- | performance_schema |
-- | toko               |
-- +--------------------+
```

```bash
# SQLite — melihat file database yang ada di direktori
ls -la *.db

# Atau menggunakan perintah di dalam CLI SQLite
.databases
```

### 4.3 Memilih / Menggunakan Database

```sql
-- MySQL & MariaDB
USE toko;

-- Konfirmasi database aktif
SELECT DATABASE();
```

```bash
# SQLite — database sudah dipilih saat membuka file
sqlite3 toko.db
# Sekarang Anda sudah berada di dalam database 'toko'
```

### 4.4 Menghapus Database

```sql
-- MySQL & MariaDB
DROP DATABASE toko;

-- Dengan pengecekan
DROP DATABASE IF EXISTS toko;
```

```bash
# SQLite — cukup hapus file-nya!
rm toko.db
```

> **⚠️ PERINGATAN:** Perintah DROP DATABASE akan menghapus SEMUA data secara permanen. Selalu buat backup sebelum menjalankan perintah ini!

---

## 5. Tipe Data

### 5.1 Tabel Perbandingan Tipe Data

```
┌──────────────┬───────────────────┬───────────────────┬───────────────────────┐
│  Kategori    │  MySQL/MariaDB    │    SQLite         │  Keterangan           │
├──────────────┼───────────────────┼───────────────────┼───────────────────────┤
│  Bilangan    │  TINYINT          │  INTEGER          │  SQLite hanya punya   │
│  Bulat       │  SMALLINT         │  INTEGER          │  satu tipe INTEGER    │
│              │  MEDIUMINT        │  INTEGER          │  (1-8 byte, adaptif)  │
│              │  INT / INTEGER    │  INTEGER          │                       │
│              │  BIGINT           │  INTEGER          │                       │
├──────────────┼───────────────────┼───────────────────┼───────────────────────┤
│  Bilangan    │  FLOAT            │  REAL             │  SQLite: REAL = 8     │
│  Desimal     │  DOUBLE           │  REAL             │  byte floating point  │
│              │  DECIMAL(p,s)     │  NUMERIC          │                       │
├──────────────┼───────────────────┼───────────────────┼───────────────────────┤
│  Teks        │  CHAR(n)          │  TEXT             │  SQLite: semua teks   │
│              │  VARCHAR(n)       │  TEXT             │  tersimpan sebagai    │
│              │  TINYTEXT         │  TEXT             │  TEXT tanpa batas     │
│              │  TEXT             │  TEXT             │  ukuran eksplisit     │
│              │  MEDIUMTEXT       │  TEXT             │                       │
│              │  LONGTEXT         │  TEXT             │                       │
├──────────────┼───────────────────┼───────────────────┼───────────────────────┤
│  Tanggal     │  DATE             │  TEXT / INTEGER   │  SQLite tidak punya   │
│  & Waktu     │  TIME             │  TEXT / INTEGER   │  tipe tanggal native. │
│              │  DATETIME         │  TEXT / INTEGER   │  Simpan sebagai TEXT  │
│              │  TIMESTAMP        │  INTEGER          │  format ISO 8601 atau │
│              │  YEAR             │  TEXT             │  UNIX timestamp       │
├──────────────┼───────────────────┼───────────────────┼───────────────────────┤
│  Boolean     │  BOOLEAN / BOOL   │  INTEGER (0/1)    │  MySQL: alias TINYINT │
│              │  TINYINT(1)       │  INTEGER (0/1)    │  SQLite: 0=false,     │
│              │                   │                   │  1=true               │
├──────────────┼───────────────────┼───────────────────┼───────────────────────┤
│  Binary      │  BLOB             │  BLOB             │  Keduanya mendukung   │
│              │  MEDIUMBLOB       │  BLOB             │  penyimpanan data     │
│              │  LONGBLOB         │  BLOB             │  biner                │
├──────────────┼───────────────────┼───────────────────┼───────────────────────┤
│  JSON        │  JSON             │  TEXT (manual)    │  MySQL 5.7+/MariaDB   │
│              │                   │                   │  10.2+ punya tipe     │
│              │                   │                   │  JSON native          │
└──────────────┴───────────────────┴───────────────────┴───────────────────────┘
```

### 5.2 Contoh Penggunaan Tipe Data

```sql
-- MySQL & MariaDB: Definisi tipe data ketat
CREATE TABLE contoh_tipe (
    id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nama        VARCHAR(100) NOT NULL,
    deskripsi   TEXT,
    harga       DECIMAL(12, 2),
    stok        INT DEFAULT 0,
    aktif       BOOLEAN DEFAULT TRUE,
    dibuat_pada DATETIME DEFAULT CURRENT_TIMESTAMP,
    gambar      BLOB
);
```

```sql
-- SQLite: Tipe data lebih fleksibel (dynamic typing)
CREATE TABLE contoh_tipe (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    nama        TEXT NOT NULL,
    deskripsi   TEXT,
    harga       REAL,
    stok        INTEGER DEFAULT 0,
    aktif       INTEGER DEFAULT 1,           -- 1 = true, 0 = false
    dibuat_pada TEXT DEFAULT (datetime('now')),
    gambar      BLOB
);
```

### 5.3 Perbedaan Penting: SQLite Dynamic Typing

SQLite menggunakan sistem "type affinity" — tipe data yang Anda tulis hanyalah **saran**, bukan aturan keras.

```sql
-- Di SQLite, ini VALID dan tidak error!
CREATE TABLE fleksibel (nilai TEXT);
INSERT INTO fleksibel VALUES (42);        -- Menyimpan angka di kolom TEXT
INSERT INTO fleksibel VALUES ('hello');   -- Menyimpan teks
INSERT INTO fleksibel VALUES (3.14);      -- Menyimpan float
INSERT INTO fleksibel VALUES (NULL);      -- Menyimpan NULL

-- Di MySQL/MariaDB, INT akan menolak nilai teks non-numerik
CREATE TABLE ketat (nilai INT);
INSERT INTO ketat VALUES ('hello');  -- ERROR di MySQL (tergantung SQL mode)
```

---

## 6. Table Management

### 6.1 Membuat Tabel (CREATE TABLE)

```sql
-- Sintaks yang kompatibel di ketiga database (dengan catatan)
CREATE TABLE produk (
    id          INTEGER PRIMARY KEY,
    kode        VARCHAR(20) UNIQUE NOT NULL,
    nama        VARCHAR(100) NOT NULL,
    harga       DECIMAL(12, 2) NOT NULL,
    stok        INTEGER NOT NULL DEFAULT 0,
    dibuat_pada DATETIME
);
```

#### Perbedaan AUTO_INCREMENT

```sql
-- MySQL & MariaDB: Gunakan AUTO_INCREMENT
CREATE TABLE produk (
    id   INT AUTO_INCREMENT PRIMARY KEY,
    nama VARCHAR(100)
);

-- SQLite: Gunakan AUTOINCREMENT (opsional) atau INTEGER PRIMARY KEY saja
-- INTEGER PRIMARY KEY sudah otomatis auto-increment di SQLite!
CREATE TABLE produk (
    id   INTEGER PRIMARY KEY,            -- Sudah auto-increment
    -- atau:
    id   INTEGER PRIMARY KEY AUTOINCREMENT, -- Lebih ketat: tidak reuse ID
    nama TEXT
);
```

### 6.2 Primary Key

```sql
-- Single column primary key
CREATE TABLE pelanggan (
    id   INTEGER PRIMARY KEY AUTO_INCREMENT,  -- MySQL/MariaDB
    nama VARCHAR(100)
);

-- Composite primary key (lebih dari satu kolom)
CREATE TABLE detail_transaksi (
    transaksi_id INTEGER,
    produk_id    INTEGER,
    jumlah       INTEGER,
    PRIMARY KEY (transaksi_id, produk_id)    -- Kompatibel di ketiganya
);
```

### 6.3 Foreign Key

```sql
-- MySQL & MariaDB: Foreign Key penuh dengan REFERENCES
CREATE TABLE transaksi (
    id           INTEGER AUTO_INCREMENT PRIMARY KEY,
    pelanggan_id INTEGER NOT NULL,
    tanggal      DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (pelanggan_id) REFERENCES pelanggan(id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
);
```

```sql
-- SQLite: Foreign Key didukung tapi HARUS diaktifkan dulu!
PRAGMA foreign_keys = ON;  -- Wajib dijalankan setiap koneksi!

CREATE TABLE transaksi (
    id           INTEGER PRIMARY KEY,
    pelanggan_id INTEGER NOT NULL,
    tanggal      TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (pelanggan_id) REFERENCES pelanggan(id)
);
```

> **⚠️ SQLite Foreign Key:** Secara default, SQLite MENONAKTIFKAN foreign key enforcement. Anda harus menjalankan `PRAGMA foreign_keys = ON;` setiap kali membuka koneksi.

### 6.4 Constraint

```sql
-- Contoh constraint lengkap (sebagian besar kompatibel di ketiganya)
CREATE TABLE produk (
    id          INTEGER PRIMARY KEY,
    kode        VARCHAR(20) UNIQUE NOT NULL,           -- UNIQUE + NOT NULL
    nama        VARCHAR(100) NOT NULL,
    harga       DECIMAL(12,2) NOT NULL CHECK (harga >= 0),  -- CHECK constraint
    stok        INTEGER DEFAULT 0 CHECK (stok >= 0),
    kategori    VARCHAR(50) DEFAULT 'Umum'
);
```

### 6.5 Memodifikasi Tabel

```sql
-- Menambah kolom baru
-- MySQL & MariaDB:
ALTER TABLE produk ADD COLUMN diskon DECIMAL(5,2) DEFAULT 0;
ALTER TABLE produk ADD COLUMN gambar_url VARCHAR(255) AFTER nama;  -- MySQL: bisa tentukan posisi

-- SQLite: ALTER TABLE sangat terbatas! Hanya bisa ADD COLUMN
ALTER TABLE produk ADD COLUMN diskon REAL DEFAULT 0;
-- SQLite TIDAK bisa: DROP COLUMN, RENAME COLUMN (sebelum v3.25), MODIFY COLUMN

-- Mengubah nama kolom (MySQL 5.7+ / MariaDB)
ALTER TABLE produk RENAME COLUMN harga TO harga_jual;

-- Menghapus kolom (MySQL / MariaDB)
ALTER TABLE produk DROP COLUMN gambar_url;
```

> **⚠️ SQLite ALTER TABLE:** Sangat terbatas. Untuk restrukturisasi besar, cara umumnya adalah: buat tabel baru → copy data → hapus tabel lama → rename tabel baru.

### 6.6 Menghapus dan Melihat Struktur Tabel

```sql
-- Menghapus tabel
DROP TABLE IF EXISTS produk;

-- Melihat struktur tabel
-- MySQL & MariaDB:
DESCRIBE produk;
SHOW COLUMNS FROM produk;
SHOW CREATE TABLE produk;  -- Melihat query CREATE TABLE lengkap

-- SQLite:
PRAGMA table_info(produk);  -- Melihat info kolom
.schema produk              -- Di CLI: melihat CREATE TABLE
```

---

## 7. CRUD Operations

### Gambaran CRUD

```
┌────────────────────────────────────────────────────┐
│                   CRUD OPERATIONS                   │
│                                                     │
│  C reate  →  INSERT INTO tabel VALUES (...)         │
│  R ead    →  SELECT kolom FROM tabel WHERE ...      │
│  U pdate  →  UPDATE tabel SET kolom=nilai WHERE ... │
│  D elete  →  DELETE FROM tabel WHERE ...            │
│                                                     │
│  ⚠️  SELALU gunakan WHERE pada UPDATE dan DELETE!  │
│     Tanpa WHERE = seluruh data terpengaruh!         │
└────────────────────────────────────────────────────┘
```

### 7.1 INSERT — Menyimpan Data

#### Insert Satu Baris

```sql
-- Sintaks dasar (kompatibel di ketiganya)
INSERT INTO produk (kode, nama, harga, stok)
VALUES ('PRD001', 'Kopi Arabika 250g', 45000.00, 100);

-- Tanpa menyebut nama kolom (urutan harus sesuai definisi tabel)
INSERT INTO produk VALUES (NULL, 'PRD002', 'Teh Hijau 100g', 25000.00, 50, NOW());
-- Catatan: NULL untuk auto-increment ID, NOW() untuk datetime MySQL
-- SQLite: gunakan (datetime('now')) atau NULL untuk datetime

-- Insert dengan kolom pilihan (kolom lain pakai DEFAULT)
INSERT INTO produk (nama, harga)
VALUES ('Gula Pasir 1kg', 14000.00);
```

#### Insert Banyak Baris Sekaligus

```sql
-- Kompatibel di MySQL, MariaDB, dan SQLite (v3.7.11+)
INSERT INTO produk (kode, nama, harga, stok)
VALUES
    ('PRD003', 'Susu UHT 1L',     18000.00, 200),
    ('PRD004', 'Roti Tawar',       12000.00,  75),
    ('PRD005', 'Minyak Goreng 1L', 22000.00, 150),
    ('PRD006', 'Garam Halus',       5000.00, 300);
```

#### INSERT OR REPLACE / UPSERT

```sql
-- SQLite: INSERT OR REPLACE (jika konflik, hapus dan insert ulang)
INSERT OR REPLACE INTO produk (id, kode, nama, harga)
VALUES (1, 'PRD001', 'Kopi Arabika Premium', 50000.00);

-- MySQL 8.0+ / MariaDB 10.3+: INSERT ... ON DUPLICATE KEY UPDATE
INSERT INTO produk (kode, nama, harga, stok)
VALUES ('PRD001', 'Kopi Arabika', 45000.00, 100)
ON DUPLICATE KEY UPDATE
    harga = VALUES(harga),
    stok  = stok + VALUES(stok);

-- MySQL 8.0+ / MariaDB 10.5.2+: Sintaks UPSERT modern
INSERT INTO produk (kode, nama, harga)
VALUES ('PRD001', 'Kopi Arabika', 45000.00)
AS new_val
ON DUPLICATE KEY UPDATE
    harga = new_val.harga;
```

### 7.2 SELECT — Membaca Data

#### SELECT Dasar

```sql
-- Mengambil semua kolom dan semua baris
SELECT * FROM produk;

-- Mengambil kolom tertentu saja
SELECT kode, nama, harga FROM produk;

-- Menggunakan alias kolom
SELECT
    kode              AS 'Kode Produk',
    nama              AS 'Nama Produk',
    harga             AS 'Harga (Rp)',
    stok              AS 'Stok Tersedia'
FROM produk;

-- Menggunakan ekspresi / kalkulasi
SELECT
    nama,
    harga,
    harga * 1.11 AS harga_dengan_ppn
FROM produk;
```

#### WHERE — Filter Data

```sql
-- Filter dengan kondisi tunggal
SELECT * FROM produk WHERE stok > 0;

-- Filter dengan berbagai operator
SELECT * FROM produk WHERE harga BETWEEN 10000 AND 50000;
SELECT * FROM produk WHERE nama LIKE '%kopi%';     -- Mengandung 'kopi'
SELECT * FROM produk WHERE nama LIKE 'Kopi%';      -- Diawali 'Kopi'
SELECT * FROM produk WHERE kode IN ('PRD001', 'PRD002', 'PRD003');
SELECT * FROM produk WHERE stok IS NULL;
SELECT * FROM produk WHERE stok IS NOT NULL;

-- Kombinasi kondisi dengan AND / OR
SELECT * FROM produk
WHERE harga > 20000
  AND stok > 0
  AND nama LIKE '%L%';

-- Menggunakan NOT
SELECT * FROM produk
WHERE NOT (harga < 10000 OR stok = 0);
```

#### ORDER BY — Mengurutkan Data

```sql
-- Urut ascending (A-Z, kecil-besar) — default
SELECT * FROM produk ORDER BY nama ASC;

-- Urut descending (Z-A, besar-kecil)
SELECT * FROM produk ORDER BY harga DESC;

-- Urut berdasarkan banyak kolom
SELECT * FROM produk
ORDER BY
    stok DESC,    -- Stok terbanyak di atas
    harga ASC;    -- Jika stok sama, harga termurah dulu

-- NULLS LAST (SQLite & MySQL)
-- SQLite: NULL secara default di atas dalam ASC
SELECT * FROM produk ORDER BY stok ASC NULLS LAST;
-- MySQL: Trik untuk NULL di akhir
SELECT * FROM produk ORDER BY stok IS NULL ASC, stok ASC;
```

#### LIMIT & OFFSET — Paginasi

```sql
-- Ambil 10 baris pertama (kompatibel di ketiganya)
SELECT * FROM produk LIMIT 10;

-- Ambil 10 baris, mulai dari baris ke-21 (untuk halaman 3, 10 data/halaman)
SELECT * FROM produk LIMIT 10 OFFSET 20;

-- Sintaks alternatif MySQL/MariaDB (kurang direkomendasikan)
SELECT * FROM produk LIMIT 20, 10;  -- LIMIT [offset], [count]

-- Contoh paginasi dinamis:
-- Halaman 1: LIMIT 10 OFFSET 0
-- Halaman 2: LIMIT 10 OFFSET 10
-- Halaman 3: LIMIT 10 OFFSET 20
-- Rumus: OFFSET = (halaman - 1) * jumlah_per_halaman
```

#### SELECT dengan Fungsi Bawaan

```sql
-- Fungsi string
SELECT UPPER(nama), LOWER(kode), LENGTH(nama) FROM produk;
SELECT CONCAT(kode, ' - ', nama) AS label FROM produk;        -- MySQL/MariaDB
SELECT kode || ' - ' || nama AS label FROM produk;            -- SQLite

-- Fungsi tanggal
-- MySQL/MariaDB:
SELECT NOW(), CURDATE(), DATE_FORMAT(dibuat_pada, '%d-%m-%Y') FROM produk;

-- SQLite:
SELECT datetime('now'), date('now'), strftime('%d-%m-%Y', dibuat_pada) FROM produk;

-- Fungsi kondisional
SELECT
    nama,
    harga,
    CASE
        WHEN harga < 10000  THEN 'Murah'
        WHEN harga < 50000  THEN 'Sedang'
        ELSE 'Mahal'
    END AS kategori_harga
FROM produk;
```

### 7.3 UPDATE — Memperbarui Data

```sql
-- Update satu kolom
UPDATE produk SET stok = 150 WHERE id = 1;

-- Update banyak kolom sekaligus
UPDATE produk
SET
    harga = 48000.00,
    stok  = stok + 50          -- Tambah stok 50 dari nilai saat ini
WHERE kode = 'PRD001';

-- Update dengan kondisi kompleks
UPDATE produk
SET harga = harga * 0.9        -- Diskon 10% untuk semua
WHERE kategori = 'Makanan'
  AND stok > 100;

-- Update menggunakan CASE
UPDATE produk
SET harga = CASE
    WHEN stok > 200 THEN harga * 0.85   -- Diskon 15% jika stok banyak
    WHEN stok > 100 THEN harga * 0.90   -- Diskon 10%
    ELSE harga                           -- Tidak ada diskon
END;
```

> **⚠️ BAHAYA:** Selalu sertakan `WHERE` pada perintah `UPDATE`. Tanpa `WHERE`, SEMUA baris akan diperbarui!

### 7.4 DELETE — Menghapus Data

```sql
-- Hapus satu baris berdasarkan ID
DELETE FROM produk WHERE id = 5;

-- Hapus berdasarkan kondisi
DELETE FROM produk WHERE stok = 0;

-- Hapus data lama (contoh: transaksi lebih dari 1 tahun)
-- MySQL/MariaDB:
DELETE FROM transaksi
WHERE tanggal < DATE_SUB(NOW(), INTERVAL 1 YEAR);

-- SQLite:
DELETE FROM transaksi
WHERE tanggal < datetime('now', '-1 year');

-- Hapus SEMUA data (lebih cepat daripada DELETE tanpa WHERE)
TRUNCATE TABLE produk;   -- MySQL/MariaDB: reset auto_increment juga
DELETE FROM produk;      -- Semua database (termasuk SQLite), auto_increment tidak reset
```

> **💡 TRUNCATE vs DELETE:** `TRUNCATE` lebih cepat karena tidak mencatat setiap baris yang dihapus, namun tidak bisa digunakan dengan WHERE dan tidak bisa di-rollback di beberapa konfigurasi. SQLite tidak mendukung TRUNCATE.

---

## 8. Query Lanjutan

### 8.1 JOIN — Menggabungkan Data dari Beberapa Tabel

```
VISUALISASI JOIN:
═══════════════════════════════════════════════════════════════
Tabel A     INNER JOIN    LEFT JOIN     RIGHT JOIN   FULL JOIN
   ●──────────────────────────────────────────────────────────
   ●         ● ●           ● ●           ● ●           ● ●
   ●                         ●             ●           ● ●
   ●                         ●                         ● ●
            Irisan        Semua A        Semua B     Semua A+B
═══════════════════════════════════════════════════════════════
```

#### INNER JOIN — Data yang Ada di Kedua Tabel

```sql
-- Mengambil transaksi beserta nama pelanggan
SELECT
    t.id            AS nomor_transaksi,
    p.nama          AS nama_pelanggan,
    t.tanggal,
    t.total_bayar
FROM transaksi t
INNER JOIN pelanggan p ON t.pelanggan_id = p.id;

-- JOIN tiga tabel sekaligus
SELECT
    t.id           AS nomor_transaksi,
    p.nama         AS pelanggan,
    pr.nama        AS nama_produk,
    dt.jumlah,
    dt.subtotal
FROM transaksi t
INNER JOIN pelanggan p ON t.pelanggan_id = p.id
INNER JOIN detail_transaksi dt ON t.id = dt.transaksi_id
INNER JOIN produk pr ON dt.produk_id = pr.id;
```

#### LEFT JOIN — Semua Data Tabel Kiri

```sql
-- Semua pelanggan, termasuk yang belum pernah bertransaksi
SELECT
    p.nama          AS nama_pelanggan,
    COUNT(t.id)     AS jumlah_transaksi,
    COALESCE(SUM(t.total_bayar), 0) AS total_belanja
FROM pelanggan p
LEFT JOIN transaksi t ON p.id = t.pelanggan_id
GROUP BY p.id, p.nama;

-- Menemukan pelanggan yang BELUM PERNAH bertransaksi
SELECT p.nama
FROM pelanggan p
LEFT JOIN transaksi t ON p.id = t.pelanggan_id
WHERE t.id IS NULL;  -- NULL berarti tidak ada pasangan di tabel kanan
```

#### RIGHT JOIN — Semua Data Tabel Kanan

```sql
-- MySQL & MariaDB mendukung RIGHT JOIN
-- SQLite TIDAK mendukung RIGHT JOIN! Gunakan LEFT JOIN dengan urutan tabel dibalik.

-- MySQL/MariaDB:
SELECT p.nama, t.tanggal
FROM transaksi t
RIGHT JOIN pelanggan p ON t.pelanggan_id = p.id;

-- SQLite (ekuivalen):
SELECT p.nama, t.tanggal
FROM pelanggan p
LEFT JOIN transaksi t ON p.id = t.pelanggan_id;
```

#### CROSS JOIN dan SELF JOIN

```sql
-- CROSS JOIN: setiap baris dari tabel A dipasangkan dengan semua baris tabel B
SELECT p1.nama AS produk_a, p2.nama AS produk_b
FROM produk p1
CROSS JOIN produk p2
WHERE p1.id < p2.id;  -- Hindari pasangan duplikat

-- SELF JOIN: tabel bergabung dengan dirinya sendiri
-- Contoh: mencari produk dalam kategori yang sama
SELECT p1.nama AS produk, p2.nama AS produk_terkait
FROM produk p1
INNER JOIN produk p2 ON p1.kategori = p2.kategori
WHERE p1.id <> p2.id;
```

### 8.2 GROUP BY & Aggregate Functions

```sql
-- Fungsi aggregate dasar (kompatibel di ketiganya)
SELECT
    kategori,
    COUNT(*)           AS jumlah_produk,
    SUM(stok)          AS total_stok,
    AVG(harga)         AS rata_harga,
    MIN(harga)         AS harga_termurah,
    MAX(harga)         AS harga_termahal
FROM produk
GROUP BY kategori;

-- GROUP BY banyak kolom
SELECT
    kategori,
    YEAR(dibuat_pada) AS tahun,    -- MySQL/MariaDB
    COUNT(*) AS jumlah
FROM produk
GROUP BY kategori, YEAR(dibuat_pada);

-- SQLite: tidak ada fungsi YEAR(), gunakan strftime
SELECT
    kategori,
    strftime('%Y', dibuat_pada) AS tahun,
    COUNT(*) AS jumlah
FROM produk
GROUP BY kategori, strftime('%Y', dibuat_pada);
```

### 8.3 HAVING — Filter Setelah GROUP BY

```sql
-- Tampilkan hanya kategori dengan lebih dari 5 produk
SELECT kategori, COUNT(*) AS jumlah_produk
FROM produk
GROUP BY kategori
HAVING COUNT(*) > 5;

-- HAVING dengan kondisi kompleks
SELECT
    pelanggan_id,
    COUNT(*)      AS jumlah_transaksi,
    SUM(total_bayar) AS total_belanja
FROM transaksi
GROUP BY pelanggan_id
HAVING jumlah_transaksi >= 3          -- Filter setelah GROUP BY
   AND total_belanja > 500000;

-- Perbedaan WHERE dan HAVING:
-- WHERE → filter SEBELUM pengelompokan (beroperasi pada baris individual)
-- HAVING → filter SETELAH pengelompokan (beroperasi pada hasil agregasi)
SELECT kategori, COUNT(*) AS jumlah
FROM produk
WHERE stok > 0         -- Filter produk dulu: hanya yang stoknya > 0
GROUP BY kategori
HAVING COUNT(*) > 2;   -- Kemudian filter: hanya kategori dengan > 2 produk aktif
```

### 8.4 Subquery

```sql
-- Subquery di WHERE: produk yang harganya di atas rata-rata
SELECT nama, harga
FROM produk
WHERE harga > (SELECT AVG(harga) FROM produk);

-- Subquery dengan IN: pelanggan yang pernah membeli 'Kopi Arabika'
SELECT nama
FROM pelanggan
WHERE id IN (
    SELECT DISTINCT t.pelanggan_id
    FROM transaksi t
    INNER JOIN detail_transaksi dt ON t.id = dt.transaksi_id
    INNER JOIN produk p ON dt.produk_id = p.id
    WHERE p.nama LIKE '%Kopi%'
);

-- Subquery di FROM (derived table)
SELECT kategori, rata_harga
FROM (
    SELECT kategori, AVG(harga) AS rata_harga
    FROM produk
    GROUP BY kategori
) AS ringkasan
WHERE rata_harga > 30000;

-- EXISTS — lebih efisien dari IN untuk banyak data
SELECT p.nama
FROM pelanggan p
WHERE EXISTS (
    SELECT 1
    FROM transaksi t
    WHERE t.pelanggan_id = p.id
      AND YEAR(t.tanggal) = 2024    -- MySQL/MariaDB
);

-- SQLite versi EXISTS:
SELECT p.nama
FROM pelanggan p
WHERE EXISTS (
    SELECT 1
    FROM transaksi t
    WHERE t.pelanggan_id = p.id
      AND strftime('%Y', t.tanggal) = '2024'
);
```

### 8.5 CTE (Common Table Expressions)

```sql
-- WITH clause — Didukung MySQL 8.0+, MariaDB 10.2+, SQLite 3.35+
WITH pelanggan_vip AS (
    SELECT
        pelanggan_id,
        COUNT(*)         AS jumlah_transaksi,
        SUM(total_bayar) AS total_belanja
    FROM transaksi
    GROUP BY pelanggan_id
    HAVING total_belanja > 1000000
)
SELECT
    p.nama,
    v.jumlah_transaksi,
    v.total_belanja
FROM pelanggan_vip v
INNER JOIN pelanggan p ON v.pelanggan_id = p.id
ORDER BY v.total_belanja DESC;
```

---

## 9. Index & Optimasi

### 9.1 Apa itu Index?

```
ANALOGI: Index seperti indeks di belakang buku.
Tanpa index → baca seluruh buku untuk cari kata "database"
Dengan index → langsung ke halaman yang tepat

TANPA INDEX:          DENGAN INDEX:
┌─────────────┐       ┌─────────────┐   ┌──────────────┐
│ Baca baris 1│       │ Index Tree  │   │ Data Tabel   │
│ Baris 2     │  →→→  │ ├─ "Ali"  → 5 │→│ Baris 5: Ali │
│ Baris 3     │       │ ├─ "Budi" → 2 │→│              │
│ ...         │       │ └─ "Sari" → 8 │→│              │
│ Baris N     │       └─────────────┘   └──────────────┘
O(N)                  O(log N)
```

### 9.2 Membuat Index

```sql
-- Index biasa (non-unique)
CREATE INDEX idx_produk_nama ON produk(nama);

-- Index unik (sekaligus constraint UNIQUE)
CREATE UNIQUE INDEX idx_produk_kode ON produk(kode);

-- Index komposit (banyak kolom)
CREATE INDEX idx_transaksi_tgl_pel ON transaksi(tanggal, pelanggan_id);

-- MySQL/MariaDB: Index FULLTEXT untuk pencarian teks
CREATE FULLTEXT INDEX idx_produk_ft ON produk(nama, deskripsi);

-- Menghapus index
DROP INDEX idx_produk_nama ON produk;     -- MySQL/MariaDB
DROP INDEX IF EXISTS idx_produk_nama;     -- SQLite

-- Melihat index yang ada
-- MySQL/MariaDB:
SHOW INDEX FROM produk;
-- SQLite:
PRAGMA index_list(produk);
PRAGMA index_info(idx_produk_nama);
```

### 9.3 Menganalisis Performa Query

```sql
-- EXPLAIN: melihat rencana eksekusi query
-- MySQL/MariaDB:
EXPLAIN SELECT * FROM produk WHERE nama LIKE '%Kopi%';
EXPLAIN ANALYZE SELECT * FROM transaksi WHERE pelanggan_id = 5;

-- SQLite:
EXPLAIN QUERY PLAN SELECT * FROM produk WHERE nama LIKE '%Kopi%';

-- Output EXPLAIN akan menunjukkan:
-- - Apakah menggunakan index atau FULL TABLE SCAN
-- - Jumlah baris yang diperkirakan dibaca
-- - Tipe join yang digunakan
```

### 9.4 Tips Optimasi Index

```sql
-- ✅ BAIK: Query yang bisa memanfaatkan index
SELECT * FROM produk WHERE kode = 'PRD001';           -- Kolom terindex
SELECT * FROM transaksi WHERE tanggal > '2024-01-01'; -- Range pada kolom terindex
SELECT * FROM produk WHERE nama = 'Kopi Arabika';     -- Exact match

-- ❌ BURUK: Query yang TIDAK bisa memanfaatkan index
SELECT * FROM produk WHERE UPPER(nama) = 'KOPI';      -- Fungsi pada kolom
SELECT * FROM produk WHERE nama LIKE '%arabika%';      -- Wildcard di awal
SELECT * FROM produk WHERE harga + 100 > 50000;        -- Operasi pada kolom

-- ✅ SOLUSI untuk query di atas:
SELECT * FROM produk WHERE nama LIKE 'Kopi%';          -- Wildcard hanya di akhir
-- Atau: simpan data dalam bentuk yang bisa diindex
-- Untuk LIKE '%teks%', gunakan FULLTEXT index
```

---

## 10. Transaction

### 10.1 Apa itu Transaction?

```
ANALOGI: Transfer Bank
═════════════════════════════════════════════════════
Langkah 1: Kurangi saldo pengirim Rp 500.000
Langkah 2: Tambah saldo penerima Rp 500.000

Tanpa transaction:
  ❌ Langkah 1 berhasil
  ❌ Langkah 2 GAGAL (error server)
  → Uang hilang dari pengirim, tidak masuk ke penerima!

Dengan transaction:
  ✅ Langkah 1 berhasil (tapi belum disimpan permanen)
  ❌ Langkah 2 GAGAL
  → ROLLBACK! Langkah 1 dibatalkan. Saldo pengirim kembali.
═════════════════════════════════════════════════════

Properti ACID:
  A - Atomicity  : Semua berhasil atau semua gagal
  C - Consistency: Data selalu valid sebelum dan sesudah transaksi
  I - Isolation  : Transaksi tidak saling mengganggu
  D - Durability : Data yang di-COMMIT bertahan meski server mati
```

### 10.2 Sintaks Transaction

```sql
-- Sintaks dasar (kompatibel di ketiganya)
BEGIN;               -- atau BEGIN TRANSACTION;
  -- ... operasi SQL di sini ...
COMMIT;              -- Simpan semua perubahan permanen

-- Jika ada error:
BEGIN;
  -- ... operasi SQL di sini ...
ROLLBACK;            -- Batalkan semua perubahan sejak BEGIN
```

### 10.3 Contoh Praktis Transaction

```sql
-- Contoh: Proses transaksi penjualan

BEGIN;

-- 1. Kurangi stok produk
UPDATE produk SET stok = stok - 3 WHERE id = 1;

-- 2. Simpan data transaksi
INSERT INTO transaksi (pelanggan_id, tanggal, total_bayar)
VALUES (5, NOW(), 135000.00);  -- MySQL
-- SQLite: VALUES (5, datetime('now'), 135000.00);

-- 3. Simpan detail transaksi
INSERT INTO detail_transaksi (transaksi_id, produk_id, jumlah, subtotal)
VALUES (LAST_INSERT_ID(), 1, 3, 135000.00);  -- MySQL: LAST_INSERT_ID()
-- SQLite: VALUES (last_insert_rowid(), 1, 3, 135000.00);
-- MariaDB: VALUES (LAST_INSERT_ID(), 1, 3, 135000.00);

-- Jika semua berhasil:
COMMIT;

-- Jika ada yang gagal (di aplikasi, bungkus dalam try-catch):
-- ROLLBACK;
```

### 10.4 SAVEPOINT

```sql
-- Titik simpan dalam transaction (untuk rollback parsial)
BEGIN;

INSERT INTO produk (nama, harga) VALUES ('Produk A', 10000);

SAVEPOINT setelah_produk_a;  -- Tandai posisi ini

INSERT INTO produk (nama, harga) VALUES ('Produk B', -500);  -- Harga negatif, tidak valid!

-- Kembali ke savepoint, hanya batalkan insert Produk B
ROLLBACK TO SAVEPOINT setelah_produk_a;

-- Lanjutkan dan commit (Produk A tetap tersimpan)
INSERT INTO produk (nama, harga) VALUES ('Produk C', 15000);
COMMIT;
```

### 10.5 Perbedaan Penting Transaction

```
┌────────────────┬─────────────────────────────────────────────────┐
│   Database     │   Perilaku Transaction                          │
├────────────────┼─────────────────────────────────────────────────┤
│ MySQL          │ Auto-commit ON secara default.                  │
│ (InnoDB)       │ Setiap query langsung di-commit jika tidak dalam│
│                │ blok BEGIN/COMMIT.                              │
│                │ InnoDB = ACID penuh ✅                          │
│                │ MyISAM = TIDAK mendukung transaction ❌          │
├────────────────┼─────────────────────────────────────────────────┤
│ MariaDB        │ Sama seperti MySQL dengan InnoDB/Aria engine.   │
│                │ Aria engine mendukung crash-safe.              │
├────────────────┼─────────────────────────────────────────────────┤
│ SQLite         │ Auto-commit ON secara default.                  │
│                │ Implicit transaction untuk setiap statement.    │
│                │ Mode WAL (Write-Ahead Log) tersedia untuk       │
│                │ performa concurrency yang lebih baik.           │
│                │ PRAGMA journal_mode=WAL; -- Aktifkan WAL mode   │
└────────────────┴─────────────────────────────────────────────────┘
```

```sql
-- MySQL: Mematikan auto-commit untuk sesi ini
SET autocommit = 0;

-- MySQL: Melihat storage engine tabel
SHOW TABLE STATUS LIKE 'produk';  -- Pastikan Engine = InnoDB

-- SQLite: Mengaktifkan WAL mode untuk performa lebih baik
PRAGMA journal_mode = WAL;
```

---

## 11. User & Privilege (MySQL & MariaDB)

> **📝 Catatan SQLite:** SQLite tidak memiliki sistem manajemen user bawaan. Keamanan akses dikendalikan oleh sistem operasi (permission file).

### 11.1 Melihat User yang Ada

```sql
-- MySQL & MariaDB
SELECT user, host, authentication_string FROM mysql.user;

-- Atau lebih ringkas:
SELECT user, host FROM mysql.user;
```

### 11.2 Membuat User

```sql
-- Buat user untuk koneksi lokal
CREATE USER 'kasir'@'localhost' IDENTIFIED BY 'password_kuat_123!';

-- Buat user yang bisa koneksi dari mana saja (hati-hati!)
CREATE USER 'developer'@'%' IDENTIFIED BY 'dev_pass_456!';

-- Buat user untuk IP spesifik
CREATE USER 'backup_user'@'10.0.0.50' IDENTIFIED BY 'backup_pass_789!';

-- MySQL 8.0+: Spesifikasi plugin autentikasi
CREATE USER 'admin'@'localhost'
IDENTIFIED WITH caching_sha2_password BY 'admin_pass!';
```

### 11.3 Memberikan Hak Akses (GRANT)

```sql
-- Berikan semua hak akses ke semua tabel di database 'toko'
GRANT ALL PRIVILEGES ON toko.* TO 'admin'@'localhost';

-- Berikan hak baca saja
GRANT SELECT ON toko.* TO 'laporan'@'localhost';

-- Berikan hak CRUD (tanpa bisa ubah struktur)
GRANT SELECT, INSERT, UPDATE, DELETE ON toko.* TO 'kasir'@'localhost';

-- Berikan akses ke tabel tertentu saja
GRANT SELECT ON toko.produk TO 'kasir'@'localhost';

-- Berikan akses ke kolom tertentu
GRANT SELECT (nama, harga) ON toko.produk TO 'display'@'localhost';

-- Izinkan user memberikan hak aksesnya ke user lain
GRANT SELECT ON toko.* TO 'supervisor'@'localhost' WITH GRANT OPTION;

-- Memberikan akses sekalian membuat user
GRANT ALL PRIVILEGES ON toko.* TO 'admin'@'localhost' IDENTIFIED BY 'password_kamu';

-- Terapkan perubahan privilege
FLUSH PRIVILEGES;
```

### 11.4 Melihat Hak Akses

```sql
-- Melihat privilege user tertentu
SHOW GRANTS FOR 'kasir'@'localhost';

-- Melihat privilege user saat ini
SHOW GRANTS;
SHOW GRANTS FOR CURRENT_USER();
```

### 11.5 Mencabut Hak Akses (REVOKE)

```sql
-- Cabut semua privilege
REVOKE ALL PRIVILEGES ON toko.* FROM 'kasir'@'localhost';

-- Cabut privilege spesifik
REVOKE DELETE ON toko.* FROM 'kasir'@'localhost';

-- Cabut grant option
REVOKE GRANT OPTION ON toko.* FROM 'supervisor'@'localhost';

FLUSH PRIVILEGES;
```

### 11.6 Mengubah Password & Menghapus User

```sql
-- Ubah password (MySQL 8.0+)
ALTER USER 'kasir'@'localhost' IDENTIFIED BY 'password_baru_!';

-- Ubah password (cara lama, masih berfungsi)
SET PASSWORD FOR 'kasir'@'localhost' = PASSWORD('password_baru_!');

-- Hapus user
DROP USER 'kasir'@'localhost';
DROP USER IF EXISTS 'developer'@'%';

FLUSH PRIVILEGES;
```

---

## 12. Backup & Restore

### 12.1 MySQL & MariaDB — Backup dengan mysqldump

```bash
# Backup satu database
mysqldump -u root -p toko > backup_toko_$(date +%Y%m%d).sql

# Backup dengan kompresi (hemat ruang)
mysqldump -u root -p toko | gzip > backup_toko_$(date +%Y%m%d).sql.gz

# Backup banyak database sekaligus
mysqldump -u root -p --databases toko db_lain > backup_multi.sql

# Backup semua database
mysqldump -u root -p --all-databases > backup_semua.sql

# Backup hanya struktur tabel (tanpa data)
mysqldump -u root -p --no-data toko > struktur_toko.sql

# Backup hanya data (tanpa struktur)
mysqldump -u root -p --no-create-info toko > data_toko.sql

# Backup tabel tertentu saja
mysqldump -u root -p toko produk pelanggan > backup_tabel_pilihan.sql

# Backup dengan opsi lengkap (aman untuk replikasi)
mysqldump -u root -p \
    --single-transaction \
    --routines \
    --triggers \
    --events \
    toko > backup_lengkap.sql
```

### 12.2 MySQL & MariaDB — Restore

```bash
# Restore dari file SQL
mysql -u root -p toko < backup_toko_20240101.sql

# Restore dari file terkompresi
gunzip -c backup_toko_20240101.sql.gz | mysql -u root -p toko

# Buat database baru lalu restore
mysql -u root -p -e "CREATE DATABASE toko_restore;"
mysql -u root -p toko_restore < backup_toko_20240101.sql

# Restore dari dalam MySQL CLI
mysql> SOURCE /path/to/backup_toko.sql;
```

### 12.3 SQLite — Backup

```bash
# Cara termudah: salin file database!
cp toko.db backup_toko_$(date +%Y%m%d).db

# Backup menggunakan perintah .backup di CLI SQLite
sqlite3 toko.db ".backup '/path/to/backup_toko.db'"

# Export ke format SQL (bisa di-import ke database lain)
sqlite3 toko.db .dump > backup_toko.sql

# Export hanya satu tabel
sqlite3 toko.db ".dump produk" > backup_produk.sql

# Export ke CSV
sqlite3 -header -csv toko.db "SELECT * FROM produk;" > produk.csv

# Backup online (untuk database yang sedang digunakan)
sqlite3 toko.db "VACUUM INTO 'backup_toko_clean.db';"
```

### 12.4 SQLite — Restore

```bash
# Restore dari file database
cp backup_toko_20240101.db toko.db

# Restore dari file SQL dump
sqlite3 toko_baru.db < backup_toko.sql

# Import dari CLI
sqlite3 toko.db ".read backup_toko.sql"

# Import CSV ke tabel
sqlite3 toko.db <<EOF
.mode csv
.import produk.csv produk
EOF
```

---

## 13. Tabel Perbandingan

### 13.1 Perbandingan Utama

```
┌──────────────────────┬────────────────────┬────────────────────┬────────────────────┐
│     Aspek            │      MySQL         │     MariaDB        │      SQLite        │
├──────────────────────┼────────────────────┼────────────────────┼────────────────────┤
│ Arsitektur           │ Client-Server      │ Client-Server      │ Serverless/Embedded│
├──────────────────────┼────────────────────┼────────────────────┼────────────────────┤
│ Kepemilikan          │ Oracle (komersial) │ Community (GPL)    │ Public Domain      │
├──────────────────────┼────────────────────┼────────────────────┼────────────────────┤
│ Instalasi            │ Butuh setup server │ Butuh setup server │ Sangat mudah       │
│                      │ dan konfigurasi    │ dan konfigurasi    │ (1 file)           │
├──────────────────────┼────────────────────┼────────────────────┼────────────────────┤
│ Port Default         │ 3306               │ 3306               │ N/A (tanpa port)   │
├──────────────────────┼────────────────────┼────────────────────┼────────────────────┤
│ Multi-user           │ ✅ Ya              │ ✅ Ya              │ ⚠️ Terbatas        │
│ Concurrent Access    │                    │                    │ (file-level lock)  │
├──────────────────────┼────────────────────┼────────────────────┼────────────────────┤
│ User Management      │ ✅ Lengkap         │ ✅ Lengkap         │ ❌ Tidak ada       │
├──────────────────────┼────────────────────┼────────────────────┼────────────────────┤
│ Storage Engine       │ InnoDB (default)   │ InnoDB + Aria      │ Satu engine saja   │
│                      │ MyISAM, Memory,    │ + ColumnStore      │                    │
│                      │ dan lainnya        │ dan lainnya        │                    │
├──────────────────────┼────────────────────┼────────────────────┼────────────────────┤
│ Foreign Key          │ ✅ InnoDB          │ ✅ InnoDB/Aria     │ ⚠️ Ada, tapi OFF  │
│                      │ Support            │ Support            │ secara default     │
├──────────────────────┼────────────────────┼────────────────────┼────────────────────┤
│ Full-text Search     │ ✅ InnoDB/MyISAM   │ ✅ Ya              │ ✅ FTS5 extension  │
├──────────────────────┼────────────────────┼────────────────────┼────────────────────┤
│ JSON Support         │ ✅ Native (5.7+)   │ ✅ Native (10.2+)  │ ⚠️ Text + json()  │
│                      │                    │                    │ function (3.38+)   │
├──────────────────────┼────────────────────┼────────────────────┼────────────────────┤
│ Window Functions     │ ✅ MySQL 8.0+      │ ✅ MariaDB 10.2+   │ ✅ SQLite 3.25+    │
├──────────────────────┼────────────────────┼────────────────────┼────────────────────┤
│ CTE (WITH)           │ ✅ MySQL 8.0+      │ ✅ MariaDB 10.2+   │ ✅ SQLite 3.35+    │
├──────────────────────┼────────────────────┼────────────────────┼────────────────────┤
│ Replikasi            │ ✅ Master-Slave     │ ✅ Master-Slave    │ ❌ Tidak ada       │
│                      │ Master-Master      │ + Galera Cluster   │                    │
├──────────────────────┼────────────────────┼────────────────────┼────────────────────┤
│ Backup               │ mysqldump          │ mysqldump          │ Salin file / .dump │
│                      │ MySQL Enterprise   │ mariabackup        │                    │
├──────────────────────┼────────────────────┼────────────────────┼────────────────────┤
│ Performa             │ ⭐⭐⭐⭐           │ ⭐⭐⭐⭐⭐          │ ⭐⭐⭐ (single     │
│ (high concurrency)   │                    │ (beberapa skenario)│ user: lebih cepat) │
├──────────────────────┼────────────────────┼────────────────────┼────────────────────┤
│ Ukuran Database      │ Tak terbatas       │ Tak terbatas       │ Maks 281 TB        │
│                      │ (hardware)         │ (hardware)         │ (per file)         │
├──────────────────────┼────────────────────┼────────────────────┼────────────────────┤
│ Use Case Utama       │ Web apps,          │ Web apps,          │ Mobile apps,       │
│                      │ Enterprise,        │ Open-source proj,  │ Desktop apps,      │
│                      │ E-commerce         │ Cloud databases    │ Testing, IoT,      │
│                      │                    │                    │ Embedded systems   │
└──────────────────────┴────────────────────┴────────────────────┴────────────────────┘
```

### 13.2 Perbandingan Sintaks Penting

```
┌────────────────────────┬──────────────────────┬──────────────────────┬─────────────────────────┐
│ Fitur                  │ MySQL                │ MariaDB              │ SQLite                  │
├────────────────────────┼──────────────────────┼──────────────────────┼─────────────────────────┤
│ Auto Increment         │ AUTO_INCREMENT        │ AUTO_INCREMENT        │ INTEGER PRIMARY KEY     │
├────────────────────────┼──────────────────────┼──────────────────────┼─────────────────────────┤
│ Last Insert ID         │ LAST_INSERT_ID()      │ LAST_INSERT_ID()      │ last_insert_rowid()    │
├────────────────────────┼──────────────────────┼──────────────────────┼─────────────────────────┤
│ Waktu Sekarang         │ NOW(), SYSDATE()      │ NOW(), SYSDATE()      │ datetime('now')        │
├────────────────────────┼──────────────────────┼──────────────────────┼─────────────────────────┤
│ String Concat          │ CONCAT(a, b)          │ CONCAT(a, b)          │ a || b                 │
├────────────────────────┼──────────────────────┼──────────────────────┼─────────────────────────┤
│ IF Kondisi             │ IF(cond, a, b)        │ IF(cond, a, b)        │ IIF(cond, a, b) /      │
│                        │                      │                      │ CASE WHEN ... END       │
├────────────────────────┼──────────────────────┼──────────────────────┼─────────────────────────┤
│ Limit Sintaks          │ LIMIT n OFFSET m      │ LIMIT n OFFSET m      │ LIMIT n OFFSET m        │
│                        │ atau LIMIT m, n       │ atau LIMIT m, n       │                        │
├────────────────────────┼──────────────────────┼──────────────────────┼─────────────────────────┤
│ Tanggal Format         │ DATE_FORMAT(d, fmt)   │ DATE_FORMAT(d, fmt)   │ strftime(fmt, d)        │
├────────────────────────┼──────────────────────┼──────────────────────┼─────────────────────────┤
│ Tambah Interval        │ DATE_ADD(d, INTERVAL  │ DATE_ADD(d, INTERVAL  │ datetime(d, '+N days') │
│                        │   N DAY)              │   N DAY)              │                        │
└────────────────────────┴──────────────────────┴──────────────────────┴─────────────────────────┘
```

---

## 14. Studi Kasus: Sistem Kasir (Point of Sale)

### 14.1 Diagram Relasi Database

```
┌──────────────────────────────────────────────────────────────────┐
│                    DATABASE: toko_kasir                           │
│                                                                   │
│  ┌──────────────┐          ┌──────────────────┐                  │
│  │  KATEGORI    │          │    PELANGGAN      │                  │
│  ├──────────────┤          ├──────────────────┤                  │
│  │ PK id        │          │ PK id            │                  │
│  │    nama      │          │    nama          │                  │
│  └──────┬───────┘          │    telepon       │                  │
│         │ 1                │    alamat        │                  │
│         │                  │    poin          │                  │
│         │ N                └────────┬─────────┘                  │
│  ┌──────┴───────┐                   │ 1                          │
│  │   PRODUK     │                   │                            │
│  ├──────────────┤                   │ N                          │
│  │ PK id        │          ┌────────┴─────────┐                  │
│  │ FK kategori  │          │   TRANSAKSI       │                  │
│  │    kode      │◄─────────├──────────────────┤                  │
│  │    nama      │          │ PK id            │                  │
│  │    harga     │          │ FK pelanggan_id  │                  │
│  │    stok      │          │    tanggal       │                  │
│  └──────────────┘          │    subtotal      │                  │
│         ▲                  │    diskon        │                  │
│         │ N                │    total_bayar   │                  │
│         │                  │    metode_bayar  │                  │
│  ┌──────┴─────────────┐    └────────┬─────────┘                  │
│  │ DETAIL_TRANSAKSI   │             │ 1                          │
│  ├────────────────────┤             │                            │
│  │ PK transaksi_id    │◄────────────┘ (FK)                      │
│  │ PK produk_id       │                                          │
│  │    jumlah          │                                          │
│  │    harga_satuan    │                                          │
│  │    subtotal        │                                          │
│  └────────────────────┘                                          │
└──────────────────────────────────────────────────────────────────┘
```

### 14.2 Membuat Database & Tabel

#### Versi MySQL / MariaDB

```sql
-- Buat dan pilih database
CREATE DATABASE IF NOT EXISTS toko_kasir
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
USE toko_kasir;

-- Tabel kategori
CREATE TABLE kategori (
    id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nama        VARCHAR(50) NOT NULL UNIQUE,
    deskripsi   TEXT,
    dibuat_pada TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabel produk
CREATE TABLE produk (
    id           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    kategori_id  INT UNSIGNED,
    kode         VARCHAR(20) NOT NULL UNIQUE,
    nama         VARCHAR(100) NOT NULL,
    harga_beli   DECIMAL(12, 2) NOT NULL DEFAULT 0,
    harga_jual   DECIMAL(12, 2) NOT NULL,
    stok         INT NOT NULL DEFAULT 0,
    satuan       VARCHAR(20) DEFAULT 'pcs',
    aktif        BOOLEAN DEFAULT TRUE,
    dibuat_pada  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    diperbarui   TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_produk_kategori
        FOREIGN KEY (kategori_id) REFERENCES kategori(id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT chk_harga_beli CHECK (harga_beli >= 0),
    CONSTRAINT chk_harga_jual CHECK (harga_jual >= 0),
    CONSTRAINT chk_stok CHECK (stok >= 0)
);

-- Tabel pelanggan
CREATE TABLE pelanggan (
    id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    kode        VARCHAR(20) UNIQUE,
    nama        VARCHAR(100) NOT NULL,
    telepon     VARCHAR(20),
    alamat      TEXT,
    email       VARCHAR(100),
    poin        INT DEFAULT 0,
    dibuat_pada TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabel transaksi (header)
CREATE TABLE transaksi (
    id            INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    kode          VARCHAR(30) NOT NULL UNIQUE,  -- Nomor nota, misal: TRX-20240101-001
    pelanggan_id  INT UNSIGNED,
    tanggal       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    subtotal      DECIMAL(14, 2) NOT NULL DEFAULT 0,
    diskon        DECIMAL(14, 2) NOT NULL DEFAULT 0,
    pajak         DECIMAL(14, 2) NOT NULL DEFAULT 0,
    total_bayar   DECIMAL(14, 2) NOT NULL DEFAULT 0,
    bayar         DECIMAL(14, 2) NOT NULL DEFAULT 0,
    kembalian     DECIMAL(14, 2) NOT NULL DEFAULT 0,
    metode_bayar  ENUM('tunai', 'debit', 'kredit', 'qris') DEFAULT 'tunai',
    kasir         VARCHAR(50),
    catatan       TEXT,
    CONSTRAINT fk_trx_pelanggan
        FOREIGN KEY (pelanggan_id) REFERENCES pelanggan(id)
        ON DELETE SET NULL ON UPDATE CASCADE
);

-- Tabel detail transaksi (baris item)
CREATE TABLE detail_transaksi (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    transaksi_id    INT UNSIGNED NOT NULL,
    produk_id       INT UNSIGNED NOT NULL,
    jumlah          INT NOT NULL,
    harga_satuan    DECIMAL(12, 2) NOT NULL,
    diskon_item     DECIMAL(12, 2) DEFAULT 0,
    subtotal        DECIMAL(14, 2) NOT NULL,
    CONSTRAINT fk_detail_trx
        FOREIGN KEY (transaksi_id) REFERENCES transaksi(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_detail_produk
        FOREIGN KEY (produk_id) REFERENCES produk(id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

-- Index untuk performa
CREATE INDEX idx_produk_kode ON produk(kode);
CREATE INDEX idx_produk_nama ON produk(nama);
CREATE INDEX idx_produk_kategori ON produk(kategori_id);
CREATE INDEX idx_trx_tanggal ON transaksi(tanggal);
CREATE INDEX idx_trx_pelanggan ON transaksi(pelanggan_id);
CREATE INDEX idx_detail_trx ON detail_transaksi(transaksi_id);
```

#### Versi SQLite

```sql
-- SQLite: Tidak perlu CREATE DATABASE, langsung buat tabel
-- Jalankan di file: toko_kasir.db

-- Aktifkan foreign key
PRAGMA foreign_keys = ON;

-- Tabel kategori
CREATE TABLE IF NOT EXISTS kategori (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    nama        TEXT NOT NULL UNIQUE,
    deskripsi   TEXT,
    dibuat_pada TEXT DEFAULT (datetime('now'))
);

-- Tabel produk
CREATE TABLE IF NOT EXISTS produk (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    kategori_id  INTEGER,
    kode         TEXT NOT NULL UNIQUE,
    nama         TEXT NOT NULL,
    harga_beli   REAL NOT NULL DEFAULT 0,
    harga_jual   REAL NOT NULL,
    stok         INTEGER NOT NULL DEFAULT 0,
    satuan       TEXT DEFAULT 'pcs',
    aktif        INTEGER DEFAULT 1,
    dibuat_pada  TEXT DEFAULT (datetime('now')),
    diperbarui   TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (kategori_id) REFERENCES kategori(id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CHECK (harga_beli >= 0),
    CHECK (harga_jual >= 0),
    CHECK (stok >= 0)
);

-- Tabel pelanggan
CREATE TABLE IF NOT EXISTS pelanggan (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    kode        TEXT UNIQUE,
    nama        TEXT NOT NULL,
    telepon     TEXT,
    alamat      TEXT,
    email       TEXT,
    poin        INTEGER DEFAULT 0,
    dibuat_pada TEXT DEFAULT (datetime('now'))
);

-- Tabel transaksi
CREATE TABLE IF NOT EXISTS transaksi (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    kode          TEXT NOT NULL UNIQUE,
    pelanggan_id  INTEGER,
    tanggal       TEXT DEFAULT (datetime('now')),
    subtotal      REAL NOT NULL DEFAULT 0,
    diskon        REAL NOT NULL DEFAULT 0,
    pajak         REAL NOT NULL DEFAULT 0,
    total_bayar   REAL NOT NULL DEFAULT 0,
    bayar         REAL NOT NULL DEFAULT 0,
    kembalian     REAL NOT NULL DEFAULT 0,
    metode_bayar  TEXT DEFAULT 'tunai',
    kasir         TEXT,
    catatan       TEXT,
    FOREIGN KEY (pelanggan_id) REFERENCES pelanggan(id)
        ON DELETE SET NULL ON UPDATE CASCADE
);

-- Tabel detail transaksi
CREATE TABLE IF NOT EXISTS detail_transaksi (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    transaksi_id    INTEGER NOT NULL,
    produk_id       INTEGER NOT NULL,
    jumlah          INTEGER NOT NULL,
    harga_satuan    REAL NOT NULL,
    diskon_item     REAL DEFAULT 0,
    subtotal        REAL NOT NULL,
    FOREIGN KEY (transaksi_id) REFERENCES transaksi(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (produk_id) REFERENCES produk(id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

-- Index
CREATE INDEX IF NOT EXISTS idx_produk_kode ON produk(kode);
CREATE INDEX IF NOT EXISTS idx_produk_nama ON produk(nama);
CREATE INDEX IF NOT EXISTS idx_trx_tanggal ON transaksi(tanggal);
CREATE INDEX IF NOT EXISTS idx_detail_trx ON detail_transaksi(transaksi_id);
```

### 14.3 Mengisi Data Awal (Seed Data)

```sql
-- Data Kategori
INSERT INTO kategori (nama, deskripsi) VALUES
    ('Minuman',     'Berbagai jenis minuman'),
    ('Makanan',     'Makanan ringan dan berat'),
    ('Sembako',     'Kebutuhan pokok sehari-hari'),
    ('Kebersihan',  'Produk perawatan dan kebersihan');

-- Data Produk
INSERT INTO produk (kategori_id, kode, nama, harga_beli, harga_jual, stok, satuan) VALUES
    (1, 'MNM001', 'Kopi Arabika 250g',     30000, 45000, 100, 'bungkus'),
    (1, 'MNM002', 'Teh Hijau 100g',        15000, 25000,  80, 'kotak'),
    (1, 'MNM003', 'Susu UHT Full Cream 1L',12000, 18000, 200, 'kotak'),
    (1, 'MNM004', 'Air Mineral 600ml',      2500,  4000, 500, 'botol'),
    (2, 'MKN001', 'Roti Tawar Gandum',      8000, 14000,  50, 'bungkus'),
    (2, 'MKN002', 'Biskuit Cokelat',        9000, 15000,  75, 'kotak'),
    (3, 'SMB001', 'Beras Premium 5kg',     55000, 75000,  40, 'karung'),
    (3, 'SMB002', 'Minyak Goreng 1L',      15000, 22000, 120, 'botol'),
    (3, 'SMB003', 'Gula Pasir 1kg',         9000, 14000, 150, 'kg'),
    (3, 'SMB004', 'Garam Halus 500g',       3000,  5000, 200, 'bungkus'),
    (4, 'KBR001', 'Sabun Mandi',            4500,  7000,  90, 'batang'),
    (4, 'KBR002', 'Shampo 170ml',          18000, 28000,  60, 'botol');

-- Data Pelanggan
INSERT INTO pelanggan (kode, nama, telepon, alamat, email) VALUES
    ('PLG001', 'Budi Santoso',   '08123456789', 'Jl. Merdeka No. 10, Jakarta',   'budi@email.com'),
    ('PLG002', 'Siti Rahayu',    '08234567890', 'Jl. Pahlawan No. 5, Bandung',   'siti@email.com'),
    ('PLG003', 'Ahmad Fauzi',    '08345678901', 'Jl. Sudirman No. 20, Surabaya', 'ahmad@email.com'),
    ('PLG004', 'Dewi Pertiwi',   '08456789012', 'Jl. Diponegoro No. 8, Medan',   'dewi@email.com'),
    ('PLG005', 'Eko Prasetyo',   '08567890123', 'Jl. Gatot Subroto No. 15',      NULL);
```

### 14.4 Operasi CRUD Sistem Kasir

#### CREATE: Memproses Transaksi Baru

```sql
-- Simulasi transaksi: Budi membeli 2 Kopi + 1 Susu + 3 Air Mineral

-- Langkah 1: Mulai transaction
BEGIN;

-- Langkah 2: Hitung subtotal
-- Kopi: 2 x 45000 = 90000
-- Susu: 1 x 18000 = 18000
-- Air:  3 x  4000 = 12000
-- Subtotal = 120000, diskon 0, pajak 11% = 13200, total = 133200

-- Langkah 3: Insert header transaksi
INSERT INTO transaksi (kode, pelanggan_id, subtotal, diskon, pajak, total_bayar, bayar, kembalian, metode_bayar, kasir)
VALUES (
    'TRX-20240615-001',  -- Nomor nota unik
    1,                    -- Budi Santoso
    120000.00,           -- Subtotal
    0.00,                -- Diskon
    13200.00,            -- Pajak 11%
    133200.00,           -- Total bayar
    150000.00,           -- Uang yang diberikan
    16800.00,            -- Kembalian
    'tunai',
    'Admin'
);

-- MySQL/MariaDB: Simpan ID transaksi yang baru dibuat
-- Langkah 4: Insert detail transaksi
INSERT INTO detail_transaksi (transaksi_id, produk_id, jumlah, harga_satuan, subtotal)
VALUES
    (LAST_INSERT_ID(), 1, 2, 45000.00, 90000.00),  -- Kopi Arabika
    (LAST_INSERT_ID(), 3, 1, 18000.00, 18000.00),  -- Susu UHT
    (LAST_INSERT_ID(), 4, 3,  4000.00, 12000.00);  -- Air Mineral

-- SQLite: Ganti LAST_INSERT_ID() dengan last_insert_rowid()

-- Langkah 5: Kurangi stok produk
UPDATE produk SET stok = stok - 2 WHERE id = 1;  -- Kopi
UPDATE produk SET stok = stok - 1 WHERE id = 3;  -- Susu
UPDATE produk SET stok = stok - 3 WHERE id = 4;  -- Air

-- Langkah 6: Tambah poin pelanggan (1 poin per 10.000 transaksi)
UPDATE pelanggan SET poin = poin + 13 WHERE id = 1;  -- 133200 / 10000 = 13 poin

-- Langkah 7: Commit
COMMIT;
```

#### READ: Berbagai Query Laporan

```sql
-- 1. Melihat semua produk dengan kategorinya
SELECT
    p.kode,
    k.nama  AS kategori,
    p.nama,
    p.harga_jual AS harga,
    p.stok,
    p.satuan
FROM produk p
LEFT JOIN kategori k ON p.kategori_id = k.id
WHERE p.aktif = 1  -- MySQL/MariaDB: TRUE juga bisa
ORDER BY k.nama, p.nama;

-- 2. Laporan penjualan hari ini
SELECT
    t.kode        AS nomor_nota,
    p.nama        AS pelanggan,
    t.tanggal,
    t.total_bayar,
    t.metode_bayar,
    t.kasir
FROM transaksi t
LEFT JOIN pelanggan p ON t.pelanggan_id = p.id
WHERE DATE(t.tanggal) = CURDATE()     -- MySQL/MariaDB
-- WHERE date(t.tanggal) = date('now')  -- SQLite
ORDER BY t.tanggal DESC;

-- 3. Ringkasan penjualan per produk hari ini
SELECT
    pr.kode,
    pr.nama             AS produk,
    SUM(dt.jumlah)      AS total_terjual,
    SUM(dt.subtotal)    AS total_pendapatan
FROM detail_transaksi dt
INNER JOIN produk pr ON dt.produk_id = pr.id
INNER JOIN transaksi t ON dt.transaksi_id = t.id
WHERE DATE(t.tanggal) = CURDATE()     -- MySQL/MariaDB
GROUP BY pr.id, pr.kode, pr.nama
ORDER BY total_pendapatan DESC;

-- 4. Stok produk menipis (stok < 20)
SELECT
    k.nama      AS kategori,
    p.kode,
    p.nama      AS produk,
    p.stok,
    p.satuan
FROM produk p
LEFT JOIN kategori k ON p.kategori_id = k.id
WHERE p.stok < 20 AND p.aktif = 1
ORDER BY p.stok ASC;

-- 5. Pelanggan dengan pembelian terbanyak bulan ini
SELECT
    pl.kode,
    pl.nama     AS pelanggan,
    pl.telepon,
    COUNT(t.id)          AS jumlah_transaksi,
    SUM(t.total_bayar)   AS total_belanja,
    pl.poin
FROM pelanggan pl
INNER JOIN transaksi t ON pl.id = t.pelanggan_id
WHERE MONTH(t.tanggal) = MONTH(CURDATE())   -- MySQL/MariaDB
  AND YEAR(t.tanggal)  = YEAR(CURDATE())
-- SQLite: WHERE strftime('%Y-%m', t.tanggal) = strftime('%Y-%m', 'now')
GROUP BY pl.id, pl.kode, pl.nama, pl.telepon, pl.poin
ORDER BY total_belanja DESC
LIMIT 10;

-- 6. Detail transaksi lengkap (struk belanja)
SELECT
    t.kode                  AS nomor_nota,
    t.tanggal,
    pl.nama                 AS pelanggan,
    pr.nama                 AS produk,
    dt.jumlah,
    dt.harga_satuan,
    dt.subtotal,
    t.diskon,
    t.pajak,
    t.total_bayar,
    t.bayar,
    t.kembalian,
    t.metode_bayar
FROM transaksi t
LEFT JOIN pelanggan pl ON t.pelanggan_id = pl.id
INNER JOIN detail_transaksi dt ON t.id = dt.transaksi_id
INNER JOIN produk pr ON dt.produk_id = pr.id
WHERE t.kode = 'TRX-20240615-001'
ORDER BY dt.id;

-- 7. Laporan laba kotor per produk
SELECT
    p.kode,
    p.nama,
    SUM(dt.jumlah)                          AS total_terjual,
    SUM(dt.jumlah * p.harga_beli)           AS total_modal,
    SUM(dt.subtotal)                        AS total_pendapatan,
    SUM(dt.subtotal - (dt.jumlah * p.harga_beli)) AS laba_kotor
FROM detail_transaksi dt
INNER JOIN produk p ON dt.produk_id = p.id
GROUP BY p.id, p.kode, p.nama
ORDER BY laba_kotor DESC;
```

#### UPDATE: Memperbarui Data

```sql
-- Update harga produk
UPDATE produk
SET
    harga_jual  = 48000.00,
    diperbarui  = NOW()      -- MySQL/MariaDB
    -- SQLite: diperbarui = datetime('now')
WHERE kode = 'MNM001';

-- Restok produk (tambah stok)
UPDATE produk
SET
    stok        = stok + 100,
    diperbarui  = NOW()
WHERE kode = 'SMB001';

-- Nonaktifkan produk yang tidak dijual lagi
UPDATE produk
SET
    aktif       = FALSE,    -- atau 0 untuk SQLite
    diperbarui  = NOW()
WHERE kode = 'MKN002';

-- Diskon massal: kurangi harga 10% untuk kategori 'Minuman'
UPDATE produk p
INNER JOIN kategori k ON p.kategori_id = k.id    -- MySQL/MariaDB syntax
SET p.harga_jual = ROUND(p.harga_jual * 0.9, 0)
WHERE k.nama = 'Minuman';

-- SQLite tidak mendukung JOIN di UPDATE, gunakan subquery:
UPDATE produk
SET harga_jual = ROUND(harga_jual * 0.9, 0)
WHERE kategori_id = (SELECT id FROM kategori WHERE nama = 'Minuman');
```

#### DELETE: Menghapus Data

```sql
-- Hapus produk yang tidak aktif dan belum pernah terjual
DELETE FROM produk
WHERE aktif = 0
  AND id NOT IN (SELECT DISTINCT produk_id FROM detail_transaksi);

-- Hapus transaksi test (misalnya transaksi dengan kode 'TEST-%')
-- Karena ada ON DELETE CASCADE, detail_transaksi ikut terhapus
DELETE FROM transaksi WHERE kode LIKE 'TEST-%';

-- Hapus pelanggan yang sudah tidak aktif > 2 tahun dan belum punya transaksi
DELETE FROM pelanggan
WHERE id NOT IN (SELECT DISTINCT pelanggan_id FROM transaksi WHERE pelanggan_id IS NOT NULL)
  AND dibuat_pada < DATE_SUB(NOW(), INTERVAL 2 YEAR);  -- MySQL/MariaDB
-- SQLite: AND dibuat_pada < datetime('now', '-2 years');
```

### 14.5 Query Analitik Bisnis

```sql
-- Omset per hari dalam 30 hari terakhir
SELECT
    DATE(tanggal)   AS tanggal,
    COUNT(*)        AS jumlah_transaksi,
    SUM(total_bayar) AS omset
FROM transaksi
WHERE tanggal >= DATE_SUB(NOW(), INTERVAL 30 DAY)   -- MySQL/MariaDB
-- WHERE tanggal >= datetime('now', '-30 days')      -- SQLite
GROUP BY DATE(tanggal)
ORDER BY tanggal;

-- Produk terlaris bulan ini (Top 5)
SELECT
    p.nama      AS produk,
    SUM(dt.jumlah) AS total_terjual
FROM detail_transaksi dt
INNER JOIN produk p ON dt.produk_id = p.id
INNER JOIN transaksi t ON dt.transaksi_id = t.id
WHERE MONTH(t.tanggal) = MONTH(CURDATE())
GROUP BY p.id, p.nama
ORDER BY total_terjual DESC
LIMIT 5;

-- Analisis metode pembayaran
SELECT
    metode_bayar,
    COUNT(*)         AS jumlah,
    SUM(total_bayar) AS total,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM transaksi), 2) AS persentase
FROM transaksi
GROUP BY metode_bayar
ORDER BY jumlah DESC;
```

---

## 15. Error Umum & Cara Mengatasinya

### 15.1 Daftar Error Umum

```
╔══════════════════════════════════════════════════════════════════════════╗
║  ERROR #1045: Access denied for user 'root'@'localhost'                  ║
╠══════════════════════════════════════════════════════════════════════════╣
║  Penyebab: Password salah atau user tidak ada                            ║
║  Solusi:                                                                 ║
║    sudo mysql                                                            ║
║    ALTER USER 'root'@'localhost' IDENTIFIED BY 'password_baru';         ║
║    FLUSH PRIVILEGES;                                                     ║
╚══════════════════════════════════════════════════════════════════════════╝
```

```
╔══════════════════════════════════════════════════════════════════════════╗
║  ERROR #1062: Duplicate entry 'PRD001' for key 'kode'                   ║
╠══════════════════════════════════════════════════════════════════════════╣
║  Penyebab: Mencoba INSERT nilai yang sudah ada di kolom UNIQUE           ║
║  Solusi:                                                                 ║
║    - Gunakan INSERT IGNORE (abaikan error, skip baris)                  ║
║    - Gunakan INSERT ... ON DUPLICATE KEY UPDATE                          ║
║    - Cek data lebih dulu dengan SELECT sebelum INSERT                   ║
╚══════════════════════════════════════════════════════════════════════════╝
```

```
╔══════════════════════════════════════════════════════════════════════════╗
║  ERROR #1451: Cannot delete or update a parent row: a foreign key       ║
║               constraint fails                                           ║
╠══════════════════════════════════════════════════════════════════════════╣
║  Penyebab: Menghapus data yang masih direferensikan tabel lain          ║
║  Solusi:                                                                 ║
║    - Hapus data di tabel anak (child) dulu                              ║
║    - Atau gunakan ON DELETE CASCADE saat membuat tabel                  ║
║    - Atau gunakan ON DELETE SET NULL                                     ║
╚══════════════════════════════════════════════════════════════════════════╝
```

```
╔══════════════════════════════════════════════════════════════════════════╗
║  ERROR #1054: Unknown column 'nama_produk' in 'field list'              ║
╠══════════════════════════════════════════════════════════════════════════╣
║  Penyebab: Nama kolom salah ketik atau lupa nama alias tabel            ║
║  Solusi:                                                                 ║
║    DESCRIBE nama_tabel;  -- Cek nama kolom yang benar                   ║
║    -- Jika JOIN, pastikan gunakan prefix: p.nama bukan nama_produk      ║
╚══════════════════════════════════════════════════════════════════════════╝
```

```
╔══════════════════════════════════════════════════════════════════════════╗
║  ERROR: no such table: produk (SQLite)                                  ║
╠══════════════════════════════════════════════════════════════════════════╣
║  Penyebab: Membuka file database yang salah, atau tabel belum dibuat    ║
║  Solusi:                                                                 ║
║    .tables          -- Cek daftar tabel yang ada                        ║
║    .databases       -- Cek file database yang sedang dibuka             ║
╚══════════════════════════════════════════════════════════════════════════╝
```

```
╔══════════════════════════════════════════════════════════════════════════╗
║  ERROR #1366: Incorrect integer value for column 'stok'                 ║
╠══════════════════════════════════════════════════════════════════════════╣
║  Penyebab: Memasukkan string ke kolom integer                           ║
║  Solusi:                                                                 ║
║    - Periksa tipe data nilai yang dimasukkan                            ║
║    - Gunakan CAST() jika perlu konversi: CAST('100' AS SIGNED)          ║
╚══════════════════════════════════════════════════════════════════════════╝
```

```
╔══════════════════════════════════════════════════════════════════════════╗
║  Warning: Unsafe statement written to binary log in statement format    ║
╠══════════════════════════════════════════════════════════════════════════╣
║  Penyebab: Query dengan LIMIT tanpa ORDER BY tidak deterministik        ║
║  Solusi:                                                                 ║
║    Selalu tambahkan ORDER BY pada query LIMIT:                          ║
║    SELECT * FROM produk ORDER BY id LIMIT 10;                          ║
╚══════════════════════════════════════════════════════════════════════════╝
```

### 15.2 Error Khusus SQLite

```sql
-- Error: SQLITE_BUSY: database is locked
-- Penyebab: File database sedang digunakan proses lain
-- Solusi: Tutup koneksi lain, atau gunakan WAL mode
PRAGMA journal_mode = WAL;
PRAGMA busy_timeout = 5000;  -- Tunggu 5 detik sebelum error

-- Error: SQLITE_CONSTRAINT: FOREIGN KEY constraint failed
-- Penyebab: Foreign key violation, tapi foreign_keys belum diaktifkan!
-- Pastikan jalankan ini di setiap koneksi:
PRAGMA foreign_keys = ON;

-- Error: SQLITE_READONLY: attempt to write a readonly database
-- Penyebab: Permission file salah
-- Solusi:
-- $ chmod 644 toko.db
-- $ chown user:group toko.db
```

---

## 16. Tips Debugging Query SQL

### 16.1 Strategi Umum

```
PROSES DEBUGGING QUERY SQL
══════════════════════════════════════════════════════════
1. MULAI DARI YANG SEDERHANA
   Tulis query dasar dulu, tambahkan kompleksitas bertahap

2. ISOLASI BAGIAN BERMASALAH
   Uji setiap tabel dan JOIN secara terpisah

3. GUNAKAN EXPLAIN
   Lihat rencana eksekusi untuk memahami apa yang terjadi

4. PERIKSA DATA
   SELECT sederhana untuk memastikan data ada dan valid

5. VERIFIKASI KONDISI WHERE
   Uji kondisi WHERE secara terpisah

6. PERHATIKAN NULL
   NULL bisa menyebabkan hasil unexpected dalam kondisi
══════════════════════════════════════════════════════════
```

### 16.2 Teknik Debugging Praktis

```sql
-- TEKNIK 1: Bagun query bertahap
-- Mulai sederhana:
SELECT * FROM transaksi LIMIT 5;

-- Tambah JOIN:
SELECT t.*, p.nama
FROM transaksi t
INNER JOIN pelanggan p ON t.pelanggan_id = p.id
LIMIT 5;

-- Tambah filter:
SELECT t.*, p.nama
FROM transaksi t
INNER JOIN pelanggan p ON t.pelanggan_id = p.id
WHERE DATE(t.tanggal) = CURDATE()
LIMIT 5;

-- TEKNIK 2: Gunakan COUNT dulu untuk cek apakah ada data
SELECT COUNT(*) FROM transaksi WHERE DATE(tanggal) = CURDATE();
-- Jika 0, berarti tidak ada data, bukan query yang salah!

-- TEKNIK 3: Debug kondisi WHERE
SELECT
    id,
    tanggal,
    DATE(tanggal)        AS tanggal_ekstrak,
    CURDATE()            AS hari_ini,
    DATE(tanggal) = CURDATE() AS kondisi  -- Apakah kondisi TRUE?
FROM transaksi
LIMIT 5;

-- TEKNIK 4: Periksa NULL
SELECT
    id,
    pelanggan_id,
    pelanggan_id IS NULL     AS adalah_null
FROM transaksi;

-- Jangan gunakan: WHERE pelanggan_id = NULL  ← SALAH!
-- Gunakan: WHERE pelanggan_id IS NULL         ← BENAR!

-- TEKNIK 5: EXPLAIN untuk memahami performa
EXPLAIN SELECT * FROM produk WHERE nama LIKE '%kopi%';
-- Jika Type = 'ALL', berarti full table scan (tidak ada index digunakan)

-- TEKNIK 6: Menggunakan variabel untuk debug (MySQL/MariaDB)
SET @test_id = 1;
SELECT * FROM transaksi WHERE id = @test_id;

-- TEKNIK 7: Komentari bagian yang dicurigai
SELECT
    t.id,
    -- t.kode,           -- Komentari dulu kolom yang mungkin bermasalah
    t.total_bayar
    -- , p.nama          -- Uji tanpa JOIN ini dulu
FROM transaksi t
-- LEFT JOIN pelanggan p ON t.pelanggan_id = p.id
LIMIT 10;
```

### 16.3 Query untuk Diagnostic

```sql
-- Cek database saat ini (MySQL/MariaDB)
SELECT DATABASE(), USER(), VERSION();

-- Melihat proses yang sedang berjalan (MySQL/MariaDB)
SHOW PROCESSLIST;

-- Melihat query yang lambat (MySQL/MariaDB)
SHOW VARIABLES LIKE 'slow_query%';
SHOW VARIABLES LIKE 'long_query_time';

-- Cek status tabel
SHOW TABLE STATUS FROM toko_kasir;

-- Analisis tabel (perbarui statistik index)
ANALYZE TABLE produk;      -- MySQL/MariaDB
ANALYZE produk;            -- SQLite: ANALYZE produk; atau hanya ANALYZE;

-- Cek integritas database (SQLite)
PRAGMA integrity_check;

-- Lihat semua index
SHOW INDEX FROM produk;    -- MySQL/MariaDB
PRAGMA index_list(produk); -- SQLite

-- Ukuran tabel
SELECT
    table_name       AS 'Tabel',
    ROUND(((data_length + index_length) / 1024 / 1024), 2) AS 'Ukuran (MB)'
FROM information_schema.TABLES
WHERE table_schema = 'toko_kasir'
ORDER BY (data_length + index_length) DESC;
-- SQLite: PRAGMA page_count; PRAGMA page_size;
```

---

## 17. Best Practice

### 17.1 Penulisan Query

```sql
-- ✅ BAIK: Query yang rapi dan mudah dibaca
SELECT
    p.kode,
    p.nama,
    k.nama  AS kategori,
    p.harga_jual
FROM produk p
INNER JOIN kategori k
    ON p.kategori_id = k.id
WHERE p.aktif = 1
  AND p.stok > 0
ORDER BY k.nama ASC, p.nama ASC
LIMIT 20;

-- ❌ BURUK: Query yang sulit dibaca
select p.kode,p.nama,k.nama,p.harga_jual from produk p inner join kategori k on p.kategori_id=k.id where p.aktif=1 and p.stok>0 order by k.nama,p.nama limit 20;

-- ✅ BAIK: Gunakan nama kolom eksplisit, bukan SELECT *
SELECT id, nama, harga_jual FROM produk;

-- ❌ HINDARI: SELECT * di produksi (performa buruk, data tidak terprediksi)
SELECT * FROM produk;  -- Hindari di production code

-- ✅ BAIK: Gunakan parameterized query di aplikasi (cegah SQL Injection!)
-- PHP PDO:
$stmt = $pdo->prepare("SELECT * FROM produk WHERE id = ?");
$stmt->execute([$id]);

-- ❌ BAHAYA: String concatenation (rentan SQL Injection!)
$query = "SELECT * FROM produk WHERE id = " . $_GET['id'];
```

### 17.2 Normalisasi Database

```
LEVEL NORMALISASI (Normal Form):
═══════════════════════════════════════════════════════════════
1NF (First Normal Form):
  ✓ Setiap kolom berisi nilai atomik (tidak ada list)
  ✓ Setiap baris unik (ada primary key)
  ❌ BURUK: kolom "produk" berisi "Kopi, Teh, Susu"

2NF (Second Normal Form):
  ✓ Memenuhi 1NF
  ✓ Tidak ada partial dependency (setiap non-key kolom
     bergantung pada seluruh primary key, bukan sebagian)

3NF (Third Normal Form):
  ✓ Memenuhi 2NF
  ✓ Tidak ada transitive dependency (non-key kolom tidak
     bergantung pada kolom non-key lainnya)

Praktis: Jika kolom bisa pindah ke tabel lain tanpa kehilangan
         informasi → mungkin perlu normalisasi.
═══════════════════════════════════════════════════════════════
```

```sql
-- ❌ TIDAK NORMAL: Menyimpan nama kategori langsung di tabel produk
CREATE TABLE produk_buruk (
    id        INT PRIMARY KEY,
    nama      VARCHAR(100),
    kategori  VARCHAR(50)   -- Duplikasi data! Jika nama kategori berubah,
                             -- harus update semua baris
);

-- ✅ NORMAL: Pisahkan ke tabel kategori, gunakan foreign key
CREATE TABLE kategori (
    id   INT PRIMARY KEY,
    nama VARCHAR(50) UNIQUE
);

CREATE TABLE produk (
    id          INT PRIMARY KEY,
    kategori_id INT,
    nama        VARCHAR(100),
    FOREIGN KEY (kategori_id) REFERENCES kategori(id)
);
```

### 17.3 Desain Tabel yang Baik

```sql
-- ✅ Checklist desain tabel yang baik:

CREATE TABLE contoh_baik (
    -- 1. Selalu ada primary key
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    -- 2. Kolom NOT NULL untuk data wajib
    nama            VARCHAR(100) NOT NULL,

    -- 3. Kolom UNIQUE untuk data yang harus unik
    kode            VARCHAR(20) NOT NULL UNIQUE,

    -- 4. DEFAULT value yang masuk akal
    stok            INT NOT NULL DEFAULT 0,
    aktif           BOOLEAN DEFAULT TRUE,

    -- 5. Kolom timestamp untuk audit trail
    dibuat_pada     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    diperbarui_pada TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    dibuat_oleh     VARCHAR(50),

    -- 6. CHECK constraint untuk validasi data
    CONSTRAINT chk_stok CHECK (stok >= 0)
);
```

### 17.4 Optimasi Performa

```sql
-- ✅ 1. Index kolom yang sering di-filter dan di-JOIN
CREATE INDEX idx_transaksi_tanggal ON transaksi(tanggal);
CREATE INDEX idx_transaksi_pelanggan ON transaksi(pelanggan_id);

-- ✅ 2. Index komposit untuk query yang sering digunakan bersamaan
CREATE INDEX idx_produk_aktif_stok ON produk(aktif, stok);
-- Query yang membanfaatkan index ini:
-- SELECT * FROM produk WHERE aktif = 1 AND stok > 0;

-- ✅ 3. Hindari SELECT * di produksi
-- Ambil hanya kolom yang dibutuhkan

-- ✅ 4. Gunakan LIMIT pada query yang bisa menghasilkan banyak baris
SELECT * FROM transaksi ORDER BY tanggal DESC LIMIT 100;

-- ✅ 5. Gunakan EXISTS daripada COUNT(*) untuk cek keberadaan
-- ❌ LAMBAT:
SELECT COUNT(*) > 0 FROM transaksi WHERE pelanggan_id = 5;

-- ✅ CEPAT:
SELECT EXISTS(SELECT 1 FROM transaksi WHERE pelanggan_id = 5);

-- ✅ 6. Hindari fungsi pada kolom yang terindex di WHERE
-- ❌ LAMBAT (index tidak digunakan):
SELECT * FROM transaksi WHERE YEAR(tanggal) = 2024;

-- ✅ CEPAT (index digunakan):
SELECT * FROM transaksi
WHERE tanggal >= '2024-01-01' AND tanggal < '2025-01-01';

-- ✅ 7. Gunakan JOIN daripada subquery (umumnya lebih cepat)
-- ❌ Lebih lambat (subquery berulang):
SELECT * FROM produk
WHERE kategori_id IN (SELECT id FROM kategori WHERE nama = 'Minuman');

-- ✅ Lebih cepat (JOIN):
SELECT p.*
FROM produk p
INNER JOIN kategori k ON p.kategori_id = k.id
WHERE k.nama = 'Minuman';
```

### 17.5 Keamanan Database

```sql
-- ✅ 1. Prinsip Least Privilege: Berikan hak akses minimal yang dibutuhkan
-- Untuk aplikasi kasir:
CREATE USER 'app_kasir'@'localhost' IDENTIFIED BY 'strong_pass!@#';
GRANT SELECT, INSERT, UPDATE ON toko_kasir.* TO 'app_kasir'@'localhost';
-- Tidak perlu: DROP, ALTER, TRUNCATE untuk user aplikasi!

-- ✅ 2. Backup reguler
-- Jadwalkan backup otomatis dengan cron:
-- 0 2 * * * mysqldump -u backup_user -p'pass' toko_kasir | gzip > /backup/toko_$(date +\%Y\%m\%d).sql.gz

-- ✅ 3. Selalu validasi dan sanitasi input di sisi aplikasi
-- ✅ 4. Gunakan parameterized query / prepared statement
-- ✅ 5. Enkripsi data sensitif (password, nomor kartu)
-- ✅ 6. Aktifkan SSL/TLS untuk koneksi remote

-- ✅ 7. Jangan simpan password dalam plaintext!
-- Gunakan fungsi hash yang kuat:
-- PHP: password_hash($password, PASSWORD_BCRYPT)
-- Python: bcrypt.hashpw(password, bcrypt.gensalt())
```

### 17.6 Ringkasan Checklist

```
CHECKLIST SEBELUM DEPLOY:
═══════════════════════════════════════════════════════════════
STRUKTUR DATABASE:
  ☐ Semua tabel memiliki primary key
  ☐ Foreign key didefinisikan dengan ON DELETE/UPDATE action
  ☐ Index pada kolom yang sering di-query / di-JOIN
  ☐ Constraint NOT NULL, UNIQUE, CHECK pada kolom yang perlu
  ☐ Charset utf8mb4 (untuk dukungan emoji & karakter khusus)

QUERY:
  ☐ Tidak ada SELECT * di production code
  ☐ Semua UPDATE/DELETE memiliki WHERE clause
  ☐ Query yang kompleks sudah ditest dengan data nyata
  ☐ Operasi kritis dibungkus dalam transaction

KEAMANAN:
  ☐ User database dengan hak akses minimal
  ☐ Tidak ada password di-hardcode dalam kode
  ☐ Parameterized query (bukan string concatenation)
  ☐ Koneksi menggunakan SSL/TLS (jika remote)

BACKUP & MONITORING:
  ☐ Script backup otomatis terjadwal
  ☐ Restore pernah ditest (backup yang tidak pernah ditest = tidak ada backup!)
  ☐ Monitoring query lambat diaktifkan
═══════════════════════════════════════════════════════════════
```

---

## Penutup

Dokumentasi ini mencakup konsep fundamental hingga lanjutan SQL dengan tiga database populer: **MySQL**, **MariaDB**, dan **SQLite**. Berikut ringkasan kapan menggunakan masing-masing:

| Skenario | Rekomendasi |
|----------|-------------|
| Aplikasi web berskala besar | MySQL atau MariaDB |
| Proyek open-source / startup | MariaDB |
| Aplikasi mobile (Android/iOS) | SQLite |
| Aplikasi desktop | SQLite |
| Prototipe dan pengembangan | SQLite |
| Enterprise dengan fitur komersial | MySQL Enterprise |
| Memerlukan Galera Cluster | MariaDB |

### Langkah Selanjutnya

1. **Praktikkan** semua contoh query di lingkungan lokal
2. **Pelajari** ORM (Object Relational Mapping) seperti SQLAlchemy (Python) atau Eloquent (PHP)
3. **Eksplorasi** fitur lanjutan: Stored Procedure, Trigger, View
4. **Pelajari** administrasi database: Replikasi, Partitioning, Clustering
5. **Pelajari** keamanan database lebih mendalam

---

> 📝 **Catatan:** Dokumentasi ini ditulis berdasarkan versi:
> - MySQL 8.0+
> - MariaDB 10.6+
> - SQLite 3.39+
>
> Beberapa fitur mungkin berbeda pada versi yang lebih lama. Selalu rujuk dokumentasi resmi untuk informasi terkini:
> - [MySQL Documentation](https://dev.mysql.com/doc/)
> - [MariaDB Knowledge Base](https://mariadb.com/kb/en/)
> - [SQLite Documentation](https://www.sqlite.org/docs.html)

---
*Dokumentasi ini dibuat sebagai panduan belajar dan referensi kerja SQL lintas database.*
