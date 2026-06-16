# Panduan Keamanan: Mengamankan Akses Database Host dari Podman Container dengan UFW

> **Role:** Linux Security Specialist  
> **Scope:** Podman Rootless + UFW + MariaDB/PostgreSQL di Host Native  
> **Network Segment:** `172.20.0.0/16` (Podman internal)

---

## Daftar Isi

1. [Pemahaman Arsitektur: Docker vs Podman Rootless](#1-pemahaman-arsitektur-docker-vs-podman-rootless)
2. [Konfigurasi Database Native di Host](#2-konfigurasi-database-native-di-host)
3. [Menemukan Interface Jaringan Podman](#3-menemukan-interface-jaringan-podman)
4. [Membuat Aturan UFW yang Sangat Spesifik](#4-membuat-aturan-ufw-yang-sangat-spesifik)
5. [Memastikan Persistensi Aturan UFW](#5-memastikan-persistensi-aturan-ufw)
6. [Verifikasi dan Pengujian Menyeluruh](#6-verifikasi-dan-pengujian-menyeluruh)
7. [Troubleshooting Umum](#7-troubleshooting-umum)
8. [Ringkasan Checklist Keamanan](#8-ringkasan-checklist-keamanan)

---

## 1. Pemahaman Arsitektur: Docker vs Podman Rootless

Ini adalah perbedaan **fundamental** yang menentukan seluruh strategi firewall Anda.

### 1.1 Docker (Root Bridge — Model Lama)

```
[Container Docker]
      |
  [veth pair]
      |
[br-xxxxxxxxxxxx]  <-- Bridge interface di namespace ROOT
      |
  [iptables/nftables rules (dikelola daemon dockerd)]
      |
[eth0 / Interface Host]
      |
[Internet / Network Luar]
```

**Karakteristik Docker:**
- `dockerd` berjalan sebagai **root**
- Membuat bridge interface kernel nyata: `docker0` atau `br-<network_id>`
- Bridge ini **terlihat langsung** oleh host via `ip addr` dan `ip link`
- UFW/iptables host bisa langsung meng-filter berdasarkan nama interface tersebut
- Docker memanipulasi iptables secara langsung (chain `DOCKER`, `DOCKER-USER`, `DOCKER-ISOLATION-*`)
- **Konsekuensi keamanan:** Docker sering mem-bypass UFW karena memanipulasi iptables di level lebih rendah dari UFW

```bash
# Contoh output Docker — interface bridge terlihat di host
$ ip addr show
...
4: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN
    link/ether 02:42:xx:xx:xx:xx brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.1/16 brd 172.17.255.255 scope global docker0
5: br-a1b2c3d4e5f6: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 ...
    inet 172.20.0.1/16 brd 172.20.255.255 scope global br-a1b2c3d4e5f6
```

---

### 1.2 Podman Rootless — Dua Mekanisme Networking

Podman Rootless memiliki **dua backend networking** yang berbeda secara fundamental:

#### A. slirp4netns (Legacy / Default Lama)

```
[Container Podman]
      |
[slirp4netns process]  <-- Userspace TCP/IP stack, BUKAN kernel networking
      |
[/proc/<pid>/fd/xx]  <-- Socket di namespace user
      |
[Koneksi keluar via NAT di userspace]
      |
[eth0 Host]
```

**Karakteristik slirp4netns:**
- Networking terjadi **sepenuhnya di userspace**, bukan di kernel
- **TIDAK ada bridge interface** yang terlihat di host
- Traffic dari container melewati proses `slirp4netns`, lalu muncul ke host sebagai traffic dari **IP loopback host** (`127.0.0.1`) atau IP host itu sendiri
- Sangat sulit di-filter dengan UFW berdasarkan interface, karena tidak ada interface kernel yang spesifik
- Port forwarding ke host menggunakan `--publish` / `-p`

#### B. Netavark + Pasta (Default Modern — Podman ≥ 4.0)

```
[Container Podman]
      |
  [veth pair]
      |
[podman-bridge / podman1 / nama-custom]  <-- Bridge interface di namespace USER
      |                                      (tapi muncul di host!)
[nftables rules (dikelola netavark)]
      |
[eth0 Host]
```

**Karakteristik Netavark:**
- Membuat bridge interface yang **terlihat di host** (mirip Docker)
- Nama interface: `podman0`, `podman1`, atau nama dari network (`podman network create`)
- Menggunakan **nftables** (bukan iptables) untuk routing dan NAT
- Interface bridge ini bisa menjadi target filter UFW
- Lebih mirip perilaku Docker dalam hal visibilitas interface

#### C. Pasta (Podman ≥ 4.4, Rootless Default Baru)

```
[Container Podman]
      |
[pasta process]  <-- Hybrid: userspace stack tapi lebih terintegrasi
      |
[Interface tap di namespace user]
      |
[Binding langsung ke interface host]
```

**Karakteristik Pasta:**
- Lebih efisien dari slirp4netns
- Bisa mem-bind langsung ke interface host tertentu
- Memberikan visibilitas lebih baik untuk firewall

---

### 1.3 Tabel Perbandingan Kritis

| Aspek | Docker (Root) | Podman Rootless + slirp4netns | Podman Rootless + Netavark |
|-------|--------------|-------------------------------|---------------------------|
| Privilege | Root | Non-root | Non-root |
| Interface di host | `br-xxxx`, `docker0` | **Tidak ada** | `podman0`, `podman1` |
| Visibilitas `ip addr` | Ya | Tidak | Ya |
| Filter UFW per interface | Mudah | Sangat sulit | Bisa |
| Manipulasi iptables | Langsung (bypass UFW) | Tidak | Via nftables |
| IP Container di host | Bridge IP | `127.0.0.1` / IP host | Bridge IP |
| Persistensi interface | Saat daemon up | Saat container run | Saat network aktif |

> **PERINGATAN KEAMANAN KRITIS:** Pada Podman Rootless dengan slirp4netns, koneksi dari container ke host **terlihat berasal dari `127.0.0.1`** di sisi host. Ini artinya aturan UFW yang mem-filter berdasarkan IP source `172.20.x.x` tidak akan bekerja! Anda harus menanganinya berbeda.

---

## 2. Konfigurasi Database Native di Host

### 2.1 Identifikasi IP Gateway Podman

Sebelum mengkonfigurasi database, tentukan IP yang akan digunakan container untuk menjangkau host:

```bash
# Cek IP gateway network Podman (ini adalah IP host dari sisi container)
podman network inspect <nama-network> | grep -A5 '"subnets"'

# Atau lihat semua network
podman network ls
podman network inspect podman  # inspect network default bernama "podman"
```

Contoh output:
```json
{
  "subnets": [
    {
      "subnet": "172.20.0.0/16",
      "gateway": "172.20.0.1"
    }
  ]
}
```

IP `172.20.0.1` adalah IP host yang terlihat dari dalam container. **Ini yang harus di-bind oleh database.**

---

### 2.2 Konfigurasi MariaDB

```bash
# Buka file konfigurasi MariaDB
sudo nano /etc/mysql/mariadb.conf.d/50-server.cnf
# atau
sudo nano /etc/mysql/my.cnf
```

**Konfigurasi bind-address:**

```ini
[mysqld]
# ============================================================
# KONFIGURASI KEAMANAN: Bind hanya ke interface yang diperlukan
# ============================================================

# OPSI 1: Bind ke IP lokal DAN IP gateway Podman
# Ganti 172.20.0.1 dengan IP gateway network Podman Anda
bind-address = 172.20.0.1

# OPSI 2: Jika butuh akses loopback DAN Podman, gunakan multi-bind (MariaDB 10.6+)
# bind-address = 127.0.0.1,172.20.0.1

# JANGAN gunakan ini (terlalu terbuka):
# bind-address = 0.0.0.0

# Port database
port = 3306

# Skip networking publik sama sekali (hanya socket UNIX + bind-address di atas)
# skip-networking = FALSE  <-- biarkan networking aktif, kita kontrol via bind + UFW
```

**Buat user database khusus untuk container:**

```sql
-- Login ke MariaDB
sudo mysql -u root -p

-- Buat user yang HANYA bisa connect dari network Podman
-- Ganti 172.20.%.% dengan subnet Anda
CREATE USER 'appuser'@'172.20.%.%' IDENTIFIED BY 'password_sangat_kuat_di_sini';

-- Berikan privilege hanya ke database yang diperlukan
GRANT SELECT, INSERT, UPDATE, DELETE ON nama_database.* TO 'appuser'@'172.20.%.%';

-- JANGAN berikan GRANT OPTION atau privilege admin
FLUSH PRIVILEGES;

-- Verifikasi
SELECT user, host, plugin FROM mysql.user WHERE user = 'appuser';
```

**Restart dan verifikasi:**

```bash
sudo systemctl restart mariadb

# Verifikasi MariaDB hanya listen di IP yang benar
sudo ss -tlnp | grep 3306
# Output yang diharapkan:
# LISTEN  0  80  172.20.0.1:3306  0.0.0.0:*  users:(("mysqld",...))

# Pastikan TIDAK ada baris seperti:
# LISTEN  0  80  0.0.0.0:3306  ...
```

---

### 2.3 Konfigurasi PostgreSQL

```bash
sudo nano /etc/postgresql/<versi>/main/postgresql.conf
```

```ini
# ============================================================
# KONFIGURASI KEAMANAN PostgreSQL
# ============================================================

# Bind hanya ke localhost dan IP gateway Podman
listen_addresses = '127.0.0.1,172.20.0.1'

# Port default PostgreSQL
port = 5432

# JANGAN gunakan:
# listen_addresses = '*'
# listen_addresses = '0.0.0.0'
```

**Konfigurasi pg_hba.conf untuk autentikasi berbasis IP:**

```bash
sudo nano /etc/postgresql/<versi>/main/pg_hba.conf
```

```
# ============================================================
# pg_hba.conf — Host-Based Authentication
# FORMAT: TYPE  DATABASE  USER  ADDRESS  METHOD
# ============================================================

# Akses lokal via socket UNIX (admin)
local   all             postgres                                peer
local   all             all                                     md5

# Loopback lokal
host    all             all             127.0.0.1/32            md5

# IZINKAN hanya dari subnet Podman, dengan autentikasi password kuat (scram)
host    nama_database   appuser         172.20.0.0/16           scram-sha-256

# TOLAK semua koneksi lain secara eksplisit
host    all             all             0.0.0.0/0               reject
host    all             all             ::/0                    reject
```

**Restart dan verifikasi:**

```bash
sudo systemctl restart postgresql

# Verifikasi listen address
sudo ss -tlnp | grep 5432
# Output yang diharapkan:
# LISTEN  0  244  127.0.0.1:5432  0.0.0.0:*  users:(("postgres",...))
# LISTEN  0  244  172.20.0.1:5432 0.0.0.0:*  users:(("postgres",...))
```

---

## 3. Menemukan Interface Jaringan Podman

### 3.1 Cek Backend Networking yang Aktif

```bash
# Cek backend networking Podman saat ini
podman info | grep -A5 "network"
podman info | grep "networkBackend"

# Output kemungkinan:
# networkBackend: netavark
# atau
# networkBackend: cni
```

### 3.2 Inspect Network Podman

```bash
# Lihat semua network Podman
podman network ls

# Inspect network spesifik (ganti "mynetwork" dengan nama network Anda)
podman network inspect mynetwork

# Atau inspect network default
podman network inspect podman
```

**Contoh output `podman network inspect`:**

```json
[
  {
    "name": "mynetwork",
    "id": "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2",
    "driver": "bridge",
    "network_interface": "podman1",
    "subnets": [
      {
        "subnet": "172.20.0.0/16",
        "gateway": "172.20.0.1"
      }
    ],
    "ipv6_enabled": false,
    "internal": false,
    "dns_enabled": true,
    "options": {}
  }
]
```

**Perhatikan field `"network_interface": "podman1"` — inilah nama bridge interface yang akan digunakan di UFW.**

### 3.3 Verifikasi Interface di Level OS

```bash
# Lihat semua interface jaringan
ip addr show

# Filter hanya interface Podman
ip addr show | grep -A4 "podman"
ip addr show | grep -A4 "172.20"

# Cek dengan ip link
ip link show type bridge

# Alternatif dengan brctl (jika terinstall)
brctl show
```

**Contoh output yang diharapkan (Netavark):**

```
5: podman1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether 8e:xx:xx:xx:xx:xx brd ff:ff:ff:ff:ff:ff
    inet 172.20.0.1/16 brd 172.20.255.255 scope global podman1
       valid_lft forever preferred_lft forever
```

> Interface ini mungkin **tidak muncul** saat tidak ada container yang berjalan. Jalankan setidaknya satu container di network tersebut, lalu cek kembali.

### 3.4 Skrip Otomatis untuk Menemukan Interface

```bash
#!/bin/bash
# Simpan sebagai: find-podman-interface.sh

NETWORK_NAME="${1:-podman}"  # Default: network "podman"
SUBNET="${2:-172.20.0.0/16}"

echo "=== Mencari interface untuk Podman network: $NETWORK_NAME ==="

# Metode 1: Dari podman network inspect
INTERFACE=$(podman network inspect "$NETWORK_NAME" 2>/dev/null | \
  python3 -c "import sys,json; data=json.load(sys.stdin); print(data[0].get('network_interface','N/A'))" 2>/dev/null)

echo "Interface dari podman inspect: $INTERFACE"

# Metode 2: Dari ip addr berdasarkan subnet
echo ""
echo "=== Interface dengan subnet $SUBNET ==="
ip -4 addr show | awk '/inet /{
  split($2, a, "/")
  if (index(a[1], "172.20") == 1) {
    print "  Interface: " $NF " | IP: " $2
  }
}'

# Metode 3: Bridge interfaces
echo ""
echo "=== Semua Bridge Interface ==="
ip link show type bridge | grep -E "^[0-9]+:" | awk '{print "  " $2}' | tr -d ':'
```

```bash
chmod +x find-podman-interface.sh
./find-podman-interface.sh mynetwork 172.20.0.0/16
```

### 3.5 Situasi Khusus: slirp4netns (Tidak Ada Bridge Interface)

Jika Anda menggunakan slirp4netns (biasanya pada Podman versi lama atau konfigurasi tertentu), **tidak ada bridge interface** yang terlihat. Cara mengetahuinya:

```bash
# Cek apakah slirp4netns aktif
ps aux | grep slirp4netns

# Cek dari dalam container — IP host akan terlihat berbeda
podman exec <container_id> ip route show
# Jika ada "host.containers.internal" atau "10.0.2.2", kemungkinan slirp4netns

# Cek koneksi dari sisi host — akan muncul sebagai loopback
sudo ss -tnp | grep 3306
# Koneksi dari container akan muncul dengan source 127.0.0.1, bukan 172.20.x.x
```

**Untuk slirp4netns, strategi firewall berbeda** — lihat Bagian 4.4.

---

## 4. Membuat Aturan UFW yang Sangat Spesifik

### 4.1 Prinsip Keamanan yang Diterapkan

- **Deny by default:** Semua traffic ke port database di-block kecuali yang diizinkan
- **Interface-specific rules:** Filter berdasarkan interface Podman, bukan hanya IP
- **Dual-layer protection:** UFW + bind-address database
- **Principle of least privilege:** Hanya subnet dan interface yang tepat yang diizinkan

### 4.2 Persiapan UFW

```bash
# Pastikan UFW aktif
sudo ufw status verbose

# Jika belum aktif:
sudo ufw enable

# Lihat aturan yang ada
sudo ufw status numbered

# PENTING: Cek apakah UFW sudah memiliki aturan default yang benar
sudo ufw default deny incoming
sudo ufw default allow outgoing
```

### 4.3 Membuat Aturan Spesifik (Netavark — Bridge Interface Terlihat)

**Asumsi:**
- Interface Podman: `podman1` (sesuaikan dengan hasil Bagian 3)
- Subnet Podman: `172.20.0.0/16`
- Port MariaDB: `3306`
- Port PostgreSQL: `5432`

#### Langkah 1: Block port database dari SEMUA sumber (aturan dasar)

```bash
# Block port MariaDB dari semua interface dan IP
sudo ufw deny in to any port 3306 comment 'Block MariaDB dari semua sumber'

# Block port PostgreSQL dari semua interface dan IP
sudo ufw deny in to any port 5432 comment 'Block PostgreSQL dari semua sumber'
```

#### Langkah 2: Izinkan HANYA dari interface Podman + subnet spesifik

```bash
# Izinkan MariaDB HANYA dari interface podman1 dan subnet 172.20.0.0/16
sudo ufw allow in on podman1 from 172.20.0.0/16 to any port 3306 proto tcp comment 'Allow MariaDB dari Podman network podman1 saja'

# Izinkan PostgreSQL HANYA dari interface podman1 dan subnet 172.20.0.0/16
sudo ufw allow in on podman1 from 172.20.0.0/16 to any port 5432 proto tcp comment 'Allow PostgreSQL dari Podman network podman1 saja'
```

> **KRITIS:** Urutan aturan UFW sangat penting. UFW memproses dari atas ke bawah dan berhenti di aturan pertama yang cocok. Pastikan aturan **allow** spesifik **ditempatkan SEBELUM** aturan deny umum dengan `--after` atau `insert`.

#### Langkah 3: Verifikasi urutan aturan

```bash
sudo ufw status numbered
```

**Output yang diharapkan:**

```
Status: active

     To                         Action      From
     --                         ------      ----
[ 1] 3306/tcp on podman1        ALLOW IN    172.20.0.0/16
[ 2] 5432/tcp on podman1        ALLOW IN    172.20.0.0/16
[ 3] 3306                       DENY IN     Anywhere
[ 4] 5432                       DENY IN     Anywhere
[ 5] 3306 (v6)                  DENY IN     Anywhere (v6)
[ 6] 5432 (v6)                  DENY IN     Anywhere (v6)
```

Jika urutan salah, gunakan `insert` untuk menempatkan aturan di posisi yang benar:

```bash
# Hapus aturan yang salah posisi
sudo ufw delete <nomor_aturan>

# Sisipkan di posisi yang benar (misal posisi 1)
sudo ufw insert 1 allow in on podman1 from 172.20.0.0/16 to any port 3306 proto tcp
```

---

### 4.4 Aturan untuk slirp4netns (Tidak Ada Bridge Interface)

Pada slirp4netns, koneksi dari container **muncul sebagai `127.0.0.1`** di host, bukan IP `172.20.x.x`. Pendekatan berbeda diperlukan:

#### Opsi A: Batasi hanya via bind-address database (Rekomendasi Utama)

Karena UFW tidak bisa membedakan traffic slirp4netns dari loopback lokal lainnya berdasarkan IP, **andalkan sepenuhnya pada `bind-address` database** yang sudah dikonfigurasi di Bagian 2. Database hanya akan menerima koneksi di IP yang di-bind.

```bash
# Block akses database dari semua interface KECUALI loopback
sudo ufw deny in to any port 3306 comment 'Block MariaDB dari non-loopback'
sudo ufw deny in to any port 5432 comment 'Block PostgreSQL dari non-loopback'

# Loopback tidak dikelola UFW secara default (UFW mengizinkan loopback)
# Verifikasi:
sudo ufw status verbose | grep -i loopback
```

#### Opsi B: Gunakan `--network=host` dengan bind khusus (jika memungkinkan)

Jika aplikasi Anda bisa dijalankan dengan `--network=host`, container menggunakan network stack host langsung, dan semua aturan UFW berbasis IP berlaku normal. Namun ini mengorbankan isolasi network.

#### Opsi C: Beralih ke Netavark (Rekomendasi Jangka Panjang)

```bash
# Cek versi Podman
podman --version

# Untuk Podman >= 4.0, set default network backend ke netavark
# Edit file konfigurasi containers
sudo nano /etc/containers/containers.conf
# atau untuk rootless user:
nano ~/.config/containers/containers.conf

# Tambahkan/ubah:
[network]
network_backend = "netavark"

# Buat ulang network Podman
podman network rm mynetwork
podman network create --subnet 172.20.0.0/16 --gateway 172.20.0.1 mynetwork
```

---

### 4.5 Aturan UFW Lengkap via `/etc/ufw/before.rules` (Kontrol Maksimal)

Untuk kontrol yang lebih presisi menggunakan iptables raw rules melalui UFW:

```bash
sudo nano /etc/ufw/before.rules
```

Tambahkan di bagian paling bawah file (sebelum `COMMIT`):

```
# ============================================================
# ATURAN KHUSUS PODMAN DATABASE SECURITY
# Ditambahkan oleh: Linux Security Specialist
# ============================================================

# Tambahkan di bagian *filter (sebelum COMMIT di bagian filter)
# Atau buat chain terpisah

# Chain khusus untuk database access control
-N PODMAN_DB_ACCESS

# Izinkan dari interface dan subnet Podman yang benar
-A PODMAN_DB_ACCESS -i podman1 -s 172.20.0.0/16 -j ACCEPT

# Log dan DROP semua yang tidak cocok
-A PODMAN_DB_ACCESS -j LOG --log-prefix "UFW BLOCK DB ACCESS: " --log-level 4
-A PODMAN_DB_ACCESS -j DROP

# Arahkan traffic database ke chain ini
-A ufw-before-input -p tcp --dport 3306 -j PODMAN_DB_ACCESS
-A ufw-before-input -p tcp --dport 5432 -j PODMAN_DB_ACCESS
```

> **Catatan:** Pendekatan via `before.rules` memberikan kontrol lebih granular tapi memerlukan pengetahuan iptables. Gunakan hanya jika aturan UFW standar tidak cukup.

---

### 4.6 Aturan Berbasis Destination IP (Lapisan Tambahan)

Untuk keamanan berlapis, tambahkan aturan yang secara eksplisit mengarahkan traffic hanya ke IP gateway Podman:

```bash
# Izinkan koneksi yang menuju SPESIFIK ke IP gateway Podman (172.20.0.1)
sudo ufw allow in on podman1 from 172.20.0.0/16 to 172.20.0.1 port 3306 proto tcp comment 'MariaDB via Podman gateway only'

sudo ufw allow in on podman1 from 172.20.0.0/16 to 172.20.0.1 port 5432 proto tcp comment 'PostgreSQL via Podman gateway only'

# Blok akses ke port database via IP lain (misal IP publik)
sudo ufw deny in to <IP_PUBLIK_SERVER> port 3306 proto tcp comment 'Block MariaDB via public IP'
sudo ufw deny in to <IP_PUBLIK_SERVER> port 5432 proto tcp comment 'Block PostgreSQL via public IP'
```

---

## 5. Memastikan Persistensi Aturan UFW

### 5.1 Persistensi UFW Dasar

UFW secara default sudah persistent — aturan tersimpan di `/etc/ufw/` dan dimuat saat boot. Namun ada beberapa kondisi yang perlu diperhatikan:

```bash
# Verifikasi UFW diaktifkan saat boot
sudo systemctl is-enabled ufw
# Output: enabled ✓

# Pastikan UFW dimulai sebelum layanan lain
sudo systemctl status ufw
```

**File konfigurasi UFW yang persistent:**

```
/etc/ufw/ufw.conf          — Konfigurasi umum (enable/disable, logging)
/etc/ufw/user.rules        — Aturan IPv4 yang Anda buat
/etc/ufw/user6.rules       — Aturan IPv6
/etc/ufw/before.rules      — Aturan yang diproses sebelum user rules
/etc/ufw/after.rules       — Aturan yang diproses setelah user rules
/etc/ufw/applications.d/   — Profil aplikasi
```

### 5.2 Masalah: Interface Podman Tidak Ada Saat Boot

**Ini adalah tantangan utama Podman!** Interface `podman1` hanya ada ketika:
- Network Podman aktif
- Ada container yang sedang berjalan di network tersebut

Jika UFW di-reload sebelum interface Podman aktif, aturan berbasis interface mungkin tidak diterapkan dengan benar.

**Solusi: systemd service untuk re-apply UFW setelah Podman:**

```bash
# Buat service systemd
sudo nano /etc/systemd/system/ufw-podman-rules.service
```

```ini
[Unit]
Description=Re-apply UFW rules for Podman network interface
After=network.target ufw.service
# Jika menggunakan rootless Podman dengan user service:
# After=network.target ufw.service user@<UID>.service
Wants=ufw.service

[Service]
Type=oneshot
RemainAfterExit=yes
# Tunggu interface Podman muncul (timeout 30 detik)
ExecStartPre=/bin/bash -c 'for i in $(seq 1 30); do ip link show podman1 && break || sleep 1; done'
# Reload UFW rules
ExecStart=/usr/sbin/ufw reload
ExecStop=/bin/true
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable ufw-podman-rules.service
sudo systemctl start ufw-podman-rules.service
```

### 5.3 Solusi Alternatif: udev Rule untuk Deteksi Interface

```bash
# Buat udev rule untuk trigger UFW reload saat interface Podman muncul
sudo nano /etc/udev/rules.d/99-podman-ufw.rules
```

```
# Trigger UFW reload saat interface podman muncul
ACTION=="add", SUBSYSTEM=="net", KERNEL=="podman*", \
  RUN+="/usr/bin/systemctl reload ufw"

# Atau untuk interface bridge spesifik
ACTION=="add", SUBSYSTEM=="net", KERNEL=="podman1", \
  RUN+="/bin/bash -c 'sleep 2 && /usr/sbin/ufw reload'"
```

```bash
sudo udevadm control --reload-rules
```

### 5.4 Podman Rootless: Menjalankan Container sebagai Service (systemd --user)

Untuk memastikan container Podman selalu berjalan (dan interface selalu aktif):

```bash
# Generate unit file systemd dari container yang berjalan
podman generate systemd --new --name <nama_container> > ~/.config/systemd/user/<nama_container>.service

# Aktifkan lingering (agar service user berjalan meski tidak login)
sudo loginctl enable-linger $USER

# Enable service
systemctl --user daemon-reload
systemctl --user enable <nama_container>.service
systemctl --user start <nama_container>.service

# Verifikasi
systemctl --user status <nama_container>.service
```

Atau menggunakan Podman Quadlets (Podman >= 4.4, cara modern):

```bash
# Buat file quadlet
mkdir -p ~/.config/containers/systemd/
nano ~/.config/containers/systemd/myapp.container
```

```ini
[Unit]
Description=My Application Container
After=network-online.target

[Container]
Image=myapp:latest
Network=mynetwork
PublishPort=8080:8080
Environment=DB_HOST=172.20.0.1
Environment=DB_PORT=3306

[Service]
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
```

```bash
systemctl --user daemon-reload
systemctl --user start myapp.service
```

### 5.5 Backup dan Restore Aturan UFW

```bash
# Backup aturan UFW saat ini
sudo cp -a /etc/ufw/ /etc/ufw.backup.$(date +%Y%m%d)

# Atau export ke file
sudo ufw status numbered > /root/ufw-rules-backup-$(date +%Y%m%d).txt

# Restore dari backup (jika diperlukan)
sudo cp -a /etc/ufw.backup.YYYYMMDD/ /etc/ufw/
sudo ufw reload
```

---

## 6. Verifikasi dan Pengujian Menyeluruh

### 6.1 Verifikasi Konfigurasi Database

```bash
# MariaDB: verifikasi bind address
sudo mysql -e "SHOW VARIABLES LIKE 'bind_address';"
sudo mysql -e "SHOW VARIABLES LIKE 'port';"

# Verifikasi socket yang aktif
sudo ss -tlnp | grep -E "3306|5432"

# PostgreSQL: verifikasi listen address
sudo -u postgres psql -c "SHOW listen_addresses;"
sudo -u postgres psql -c "SHOW port;"
```

### 6.2 Verifikasi Aturan UFW

```bash
# Lihat semua aturan aktif
sudo ufw status verbose

# Lihat aturan dengan nomor
sudo ufw status numbered

# Verifikasi aturan iptables yang dihasilkan UFW
sudo iptables -L INPUT -n -v --line-numbers
sudo iptables -L ufw-user-input -n -v --line-numbers

# Filter untuk port database
sudo iptables -L -n -v | grep -E "3306|5432"
```

### 6.3 Pengujian Koneksi dari Container

```bash
# Jalankan container test di network Podman
podman run --rm -it --network mynetwork alpine/curl sh

# Di dalam container, test koneksi ke host:
# (ganti 172.20.0.1 dengan IP gateway Podman Anda)
nc -zv 172.20.0.1 3306   # Harus BERHASIL
nc -zv 172.20.0.1 5432   # Harus BERHASIL

# Test koneksi MySQL dari container
mysql -h 172.20.0.1 -u appuser -p nama_database

# Test koneksi PostgreSQL dari container
psql -h 172.20.0.1 -U appuser -d nama_database
```

### 6.4 Pengujian Blocking dari Luar

```bash
# Test dari mesin lain di network luar — HARUS DITOLAK
# (ganti <IP_PUBLIK_SERVER> dengan IP server Anda)
nc -zv <IP_PUBLIK_SERVER> 3306    # Harus GAGAL/TIMEOUT
nc -zv <IP_PUBLIK_SERVER> 5432    # Harus GAGAL/TIMEOUT

# Test dari localhost dengan IP publik — HARUS DITOLAK
nc -zv <IP_PUBLIK_SERVER> 3306    # Harus GAGAL

# Test dari interface lain — HARUS DITOLAK
nc -zv <IP_INTERFACE_LAIN> 3306   # Harus GAGAL
```

### 6.5 Monitoring Log UFW

```bash
# Aktifkan logging UFW jika belum
sudo ufw logging on
sudo ufw logging medium  # low/medium/high/full

# Monitor log UFW secara real-time
sudo tail -f /var/log/ufw.log

# Filter koneksi yang di-block ke port database
sudo grep -E "DPT=3306|DPT=5432" /var/log/ufw.log

# Analisis dengan journald
sudo journalctl -f -k | grep -E "UFW|3306|5432"
```

### 6.6 Script Verifikasi Otomatis

```bash
#!/bin/bash
# Simpan sebagai: verify-podman-db-security.sh

PODMAN_INTERFACE="podman1"
PODMAN_SUBNET="172.20.0.0/16"
PODMAN_GATEWAY="172.20.0.1"
DB_PORTS="3306 5432"

echo "======================================================"
echo "  Verifikasi Keamanan Database - Podman + UFW"
echo "======================================================"

# 1. Cek UFW status
echo ""
echo "[1] Status UFW:"
ufw_status=$(sudo ufw status | head -1)
echo "    $ufw_status"
[[ "$ufw_status" == "Status: active" ]] && echo "    ✅ UFW aktif" || echo "    ❌ UFW tidak aktif!"

# 2. Cek interface Podman
echo ""
echo "[2] Interface Podman ($PODMAN_INTERFACE):"
if ip link show "$PODMAN_INTERFACE" &>/dev/null; then
  echo "    ✅ Interface ditemukan"
  ip addr show "$PODMAN_INTERFACE" | grep "inet " | awk '{print "    IP: " $2}'
else
  echo "    ⚠️  Interface tidak ditemukan (mungkin tidak ada container berjalan)"
fi

# 3. Cek bind address database
echo ""
echo "[3] Database Bind Address:"
for port in $DB_PORTS; do
  listening=$(ss -tlnp | grep ":$port ")
  if [[ -n "$listening" ]]; then
    echo "    Port $port:"
    echo "$listening" | while read line; do
      local_addr=$(echo "$line" | awk '{print $4}')
      echo "      Listening: $local_addr"
      if [[ "$local_addr" == "0.0.0.0:$port" ]] || [[ "$local_addr" == "*:$port" ]]; then
        echo "      ❌ BERBAHAYA: Mendengarkan di semua interface!"
      else
        echo "      ✅ Terbatas ke IP spesifik"
      fi
    done
  else
    echo "    Port $port: Tidak ada layanan yang berjalan"
  fi
done

# 4. Cek aturan UFW untuk port database
echo ""
echo "[4] Aturan UFW untuk Database:"
for port in $DB_PORTS; do
  echo "    Port $port:"
  sudo ufw status verbose | grep "$port" | while read line; do
    echo "      $line"
  done
done

echo ""
echo "======================================================"
echo "  Verifikasi selesai. Periksa output di atas."
echo "======================================================"
```

```bash
chmod +x verify-podman-db-security.sh
sudo ./verify-podman-db-security.sh
```

---

## 7. Troubleshooting Umum

### 7.1 Container Tidak Bisa Connect ke Database

**Gejala:** Connection refused atau timeout dari container ke `172.20.0.1:3306`

**Langkah diagnosis:**

```bash
# 1. Pastikan database mendengarkan di IP yang benar
sudo ss -tlnp | grep 3306

# 2. Cek dari host ke IP gateway
mysql -h 172.20.0.1 -u appuser -p  # Jika ini gagal, masalah di bind-address

# 3. Cek aturan UFW
sudo ufw status numbered | grep 3306

# 4. Test koneksi langsung (bypass UFW sementara untuk diagnosa)
sudo ufw disable
# Test koneksi dari container
# Jika berhasil setelah UFW dimatikan, masalah ada di aturan UFW
sudo ufw enable

# 5. Cek log UFW
sudo grep "DPT=3306" /var/log/ufw.log | tail -20
```

### 7.2 Aturan UFW Tidak Diterapkan ke Interface Podman

**Gejala:** `ufw status` menampilkan aturan, tapi traffic tetap terblok atau diizinkan secara salah

```bash
# Cek apakah interface ada saat UFW diterapkan
ip link show podman1

# Reload UFW setelah interface aktif
sudo ufw reload

# Verifikasi aturan iptables yang dihasilkan
sudo iptables -L ufw-user-input -n -v | grep podman1
```

### 7.3 Konflik dengan Aturan nftables Podman/Netavark

**Gejala:** Koneksi terblok meski UFW mengizinkan, atau aturan UFW di-bypass

```bash
# Lihat aturan nftables yang ada (Netavark menggunakan nftables)
sudo nft list ruleset

# Cek chain yang dibuat Podman/Netavark
sudo nft list ruleset | grep -A20 "podman"

# Jika ada konflik, Anda mungkin perlu menambahkan aturan di nftables
# JANGAN hapus aturan Netavark — mereka penting untuk routing container
```

### 7.4 Interface Podman Berubah Nama Setelah Restart

```bash
# Inspect network untuk mendapatkan nama interface saat ini
podman network inspect mynetwork | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print(d[0]['network_interface'])"

# Update aturan UFW dengan nama interface baru
sudo ufw delete allow in on podman1 from 172.20.0.0/16 to any port 3306
sudo ufw allow in on <nama_interface_baru> from 172.20.0.0/16 to any port 3306 proto tcp

# Atau buat nama interface statis dengan konfigurasi network Podman
podman network create \
  --subnet 172.20.0.0/16 \
  --gateway 172.20.0.1 \
  --opt "com.docker.network.bridge.name=podman-myapp" \
  mynetwork
```

---

## 8. Ringkasan Checklist Keamanan

### Checklist Pre-Deployment

```
DATABASE CONFIGURATION
[ ] bind-address dikonfigurasi ke IP gateway Podman (bukan 0.0.0.0)
[ ] User database dibuat dengan host restriction 172.20.%.%
[ ] Privilege database minimal (hanya yang diperlukan)
[ ] Verifikasi ss -tlnp tidak menampilkan 0.0.0.0:3306

PODMAN NETWORK
[ ] Network Podman dibuat dengan subnet yang benar (172.20.0.0/16)
[ ] Backend Netavark teridentifikasi dan aktif
[ ] Interface Podman teridentifikasi (podman network inspect)
[ ] Interface terlihat di ip addr saat container berjalan

UFW RULES
[ ] UFW aktif dan diaktifkan saat boot
[ ] Aturan ALLOW spesifik untuk interface + subnet Podman dibuat
[ ] Aturan DENY umum untuk port database dibuat
[ ] Urutan aturan diverifikasi (ALLOW spesifik SEBELUM DENY umum)
[ ] UFW logging diaktifkan

PERSISTENSI
[ ] systemd service untuk Podman container dikonfigurasi
[ ] loginctl enable-linger diaktifkan untuk user Podman rootless
[ ] ufw-podman-rules.service dibuat (jika diperlukan)
[ ] Backup aturan UFW disimpan

VERIFIKASI
[ ] Koneksi dari container ke database BERHASIL
[ ] Koneksi dari IP luar ke port database GAGAL
[ ] Log UFW dipantau
[ ] Script verifikasi dijalankan dan hasilnya bersih
```

---

## Referensi Cepat: Perintah Penting

```bash
# Lihat interface Podman
podman network inspect <network_name> | grep network_interface

# Lihat semua aturan UFW
sudo ufw status numbered

# Tambah aturan UFW
sudo ufw allow in on <interface> from <subnet> to any port <port> proto tcp

# Hapus aturan UFW berdasarkan nomor
sudo ufw delete <nomor>

# Reload UFW
sudo ufw reload

# Monitor log UFW
sudo tail -f /var/log/ufw.log | grep -E "DPT=3306|DPT=5432"

# Verifikasi iptables
sudo iptables -L ufw-user-input -n -v --line-numbers

# Test koneksi dari container
podman exec <container> nc -zv 172.20.0.1 3306
```

---

*Panduan ini dibuat untuk lingkungan: Ubuntu/Debian + Podman Rootless + Netavark + UFW.*  
*Selalu uji konfigurasi di lingkungan staging sebelum menerapkan ke produksi.*  
*Perbarui aturan firewall secara berkala sesuai kebutuhan aplikasi.*
