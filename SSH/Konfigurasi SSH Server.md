# 🔐 Panduan Teknis: Konfigurasi SSH Server yang Aman di Debian 12 (Bookworm)

**Versi Dokumen:** 1.0  
**Sistem Operasi:** Debian 12 (Bookworm)  
**Tingkat:** Intermediate – Advanced  
**Ditulis oleh:** Senior System Administrator & Pakar Keamanan Siber

---

## Daftar Isi

1. [Install SSH Server & Persiapan](#1-install-ssh-server--persiapan)
2. [Manajemen User & Hak Akses Sudo](#2-manajemen-user--hak-akses-sudo)
3. [Konfigurasi SSH Key-Based Authentication](#3-konfigurasi-ssh-key-based-authentication)
4. [Pengerasan Keamanan (Hardening) SSH](#4-pengerasan-keamanan-hardening-ssh)
5. [Praktik Keamanan Tambahan](#5-praktik-keamanan-tambahan)
6. [Pengujian dan Verifikasi](#6-pengujian-dan-verifikasi)

---

## 1. Install SSH Server & Persiapan

### 1.1 Masuk sebagai Root (Jika Diperlukan)

> **📌 Catatan:** Pada instalasi Debian 12 minimal (tanpa GUI), Anda mungkin hanya memiliki akses sebagai `root` di awal. Gunakan perintah berikut untuk beralih ke sesi root jika Anda login sebagai user biasa:

```bash
su -
```

Tanda `-` (dash) penting — ini memastikan Anda mendapatkan environment root yang lengkap, termasuk variabel PATH yang benar. Tanpa tanda ini, beberapa perintah sistem mungkin tidak ditemukan.

---

### 1.2 Perbarui Daftar Paket

Sebelum menginstal paket apapun, selalu perbarui indeks repositori terlebih dahulu:

```bash
apt update && apt upgrade -y
```

---

### 1.3 Instalasi OpenSSH Server

```bash
apt install openssh-server -y
```

---

### 1.4 Aktifkan dan Jalankan Service SSH

Perintah berikut akan mengaktifkan SSH agar otomatis berjalan saat server dinyalakan (`enable`) sekaligus langsung menjalankannya saat ini juga (`--now`):

```bash
systemctl enable --now ssh
```

---

### 1.5 Verifikasi Status Service

```bash
systemctl status ssh
```

Output yang diharapkan akan menampilkan `active (running)`:

```
● ssh.service - OpenBSD Secure Shell server
     Loaded: loaded (/lib/systemd/system/ssh.service; enabled; preset: enabled)
     Active: active (running) since ...
```

---

### 1.6 Cek Versi OpenSSH

```bash
ssh -V
```

Pastikan versi yang terinstal adalah **OpenSSH 9.x** atau lebih baru, yang sudah tersedia secara default di Debian 12.

---

## 2. Manajemen User & Hak Akses Sudo

> **⚠️ Peringatan Keamanan:** Login langsung sebagai `root` via SSH adalah praktik yang sangat tidak disarankan. Selalu gunakan user non-root dengan hak akses sudo yang terkontrol.

### 2.1 Instalasi Paket `sudo`

Instalasi Debian 12 minimal sering kali **tidak menyertakan** paket `sudo`. Pasang terlebih dahulu (jalankan sebagai `root`):

```bash
apt install sudo -y
```

---

### 2.2 Membuat User Baru (Non-Root)

Ganti `namauser` dengan nama user yang Anda inginkan:

```bash
adduser namauser
```

Anda akan diminta mengisi:
- Password baru (isi dua kali)
- Informasi tambahan (Full Name, Room Number, dll.) — boleh dikosongi dengan tekan Enter

---

### 2.3 Menambahkan User ke Grup `sudo`

```bash
usermod -aG sudo namauser
```

**Penjelasan flag:**
- `-a` → Append (tambahkan ke grup, jangan hapus grup yang sudah ada)
- `-G sudo` → Tambahkan ke grup `sudo`

---

### 2.4 Verifikasi Keanggotaan Grup

```bash
groups namauser
```

Output yang diharapkan:

```
namauser : namauser sudo
```

---

### 2.5 Uji Hak Akses Sudo

Beralih ke user baru dan uji sudo:

```bash
su - namauser
sudo whoami
```

Output yang diharapkan: `root`

---

## 3. Konfigurasi SSH Key-Based Authentication

Autentikasi berbasis SSH Key jauh lebih aman dibandingkan password. Key pair terdiri dari:
- **Private Key** → Disimpan di komputer klien (JANGAN pernah dibagikan)
- **Public Key** → Disimpan di server di file `~/.ssh/authorized_keys`

---

### 3.1 Generate SSH Key Pair di Sisi Klien

Jalankan perintah ini di **komputer klien** (bukan di server):

**Opsi A — Ed25519 (Direkomendasikan, lebih modern dan lebih cepat):**

```bash
ssh-keygen -t ed25519 -C "identitas-opsional@hostname"
```

**Opsi B — RSA 4096-bit (Kompatibilitas lebih luas):**

```bash
ssh-keygen -t rsa -b 4096 -C "identitas-opsional@hostname"
```

**Prompt yang akan muncul:**

```
Enter file in which to save the key (~/.ssh/id_ed25519): [Enter untuk default]
Enter passphrase (empty for no passphrase): [SANGAT DISARANKAN mengisi passphrase]
Enter same passphrase again:
```

> **🔒 Tips Keamanan:** Selalu gunakan **passphrase** pada private key Anda. Ini adalah lapisan keamanan tambahan jika private key Anda pernah dicuri.

Dua file akan dibuat di `~/.ssh/`:
- `id_ed25519` → **Private Key** (izin harus `600`, hanya pemilik yang bisa baca)
- `id_ed25519.pub` → **Public Key** (aman untuk dibagikan ke server)

---

### 3.2 Transfer Public Key ke Server

**Metode 1 — Menggunakan `ssh-copy-id` (Paling Mudah):**

```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub -p 22 namauser@IP_SERVER
```

Ganti `IP_SERVER` dengan alamat IP server Anda. Anda akan diminta memasukkan password user sekali, lalu public key akan otomatis terpasang.

---

**Metode 2 — Manual (Jika `ssh-copy-id` tidak tersedia):**

Di sisi klien, tampilkan isi public key:

```bash
cat ~/.ssh/id_ed25519.pub
```

Salin outputnya, lalu di **server**, jalankan sebagai user yang dituju:

```bash
# Buat direktori .ssh jika belum ada
mkdir -p ~/.ssh

# Tempel public key (paste) ke file authorized_keys
echo "PASTE_PUBLIC_KEY_DISINI" >> ~/.ssh/authorized_keys
```

---

### 3.3 Atur Hak Akses File (Kritis!)

> **⚠️ Penting:** SSH akan **menolak** membaca `authorized_keys` jika permission file tidak tepat. Ini fitur keamanan bawaan SSH.

Di server, jalankan sebagai user yang dituju:

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

**Penjelasan permission:**
- `700` pada direktori `.ssh` → Hanya pemilik yang bisa masuk ke direktori
- `600` pada `authorized_keys` → Hanya pemilik yang bisa baca dan tulis file

Verifikasi permission:

```bash
ls -la ~/.ssh/
```

---

### 3.4 Uji Koneksi dengan SSH Key

Dari komputer klien:

```bash
ssh -i ~/.ssh/id_ed25519 -p 22 namauser@IP_SERVER
```

Jika berhasil, Anda masuk tanpa diminta password user (hanya passphrase key jika sudah diatur).

> **✅ Jangan lanjutkan ke Langkah 4 sebelum memastikan login dengan SSH Key berhasil!**

---

## 4. Pengerasan Keamanan (Hardening) SSH

Semua konfigurasi SSH tersimpan di file:

```
/etc/ssh/sshd_config
```

### 4.1 Backup File Konfigurasi Asli

> **⚠️ Wajib dilakukan sebelum mengedit konfigurasi apapun!**

```bash
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
```

Verifikasi backup:

```bash
ls -la /etc/ssh/sshd_config*
```

---

### 4.2 Edit File Konfigurasi SSH

```bash
sudo nano /etc/ssh/sshd_config
```

Atau menggunakan `vim`:

```bash
sudo vim /etc/ssh/sshd_config
```

---

### 4.3 Ubah Port Default SSH

Menemukan baris berikut (mungkin diawali `#`):

```
#Port 22
```

Ubah menjadi (gunakan port pilihan Anda, contoh: 2288):

```
Port 2288
```

> **⚠️ Peringatan Kritis:** JANGAN restart SSH dulu setelah mengubah port. Pastikan terlebih dahulu firewall sudah membuka port baru (lihat Langkah 5.3). Jika tidak, Anda akan ter-lockout dari server!

**Mengapa mengubah port?**
- Mengurangi noise dari automated bots yang terus-menerus mencoba brute-force port 22
- Bukan solusi keamanan utama, namun mengurangi log yang berisik secara signifikan

---

### 4.4 Nonaktifkan Login Root Langsung

Temukan baris:

```
#PermitRootLogin prohibit-password
```

Ubah menjadi:

```
PermitRootLogin no
```

**Penjelasan nilai-nilai yang tersedia:**
| Nilai | Keterangan |
|---|---|
| `yes` | Root boleh login (tidak aman) |
| `no` | Root tidak bisa login sama sekali (**direkomendasikan**) |
| `prohibit-password` | Root hanya boleh login dengan Key, tidak dengan password |
| `forced-commands-only` | Root hanya untuk perintah tertentu saja |

---

### 4.5 Nonaktifkan Autentikasi Password

> **🔒 Lakukan HANYA setelah SSH Key dipastikan bekerja di Langkah 3.4!**

Temukan baris:

```
#PasswordAuthentication yes
```

Ubah menjadi:

```
PasswordAuthentication no
```

Juga pastikan baris-baris berikut dikonfigurasi:

```
ChallengeResponseAuthentication no
KbdInteractiveAuthentication no
UsePAM yes
```

> **📌 Cara Mengaktifkan Kembali Autentikasi Password (Jika Diperlukan):**
> Jika di kemudian hari Anda perlu mengaktifkan kembali login dengan password (misalnya untuk kebutuhan sementara), ubah baris ini di `sshd_config`:
> ```
> PasswordAuthentication yes
> ```
> Kemudian restart SSH: `sudo systemctl restart ssh`
> **Ingat:** Selalu nonaktifkan kembali setelah keperluan selesai.

---

### 4.6 Konfigurasi Lengkap Rekomendasi Keamanan

Berikut adalah kumpulan parameter keamanan yang disarankan dalam satu blok. Tambahkan atau sesuaikan di `sshd_config`:

```
# ============================================
# KONFIGURASI KEAMANAN SSH - DEBIAN 12
# ============================================

# Port kustom (ubah sesuai kebutuhan)
Port 2288

# Protokol SSH (pastikan hanya versi 2)
Protocol 2

# Batasi alamat yang di-listen (opsional, jika server punya multiple interface)
# ListenAddress 0.0.0.0

# Nonaktifkan login root
PermitRootLogin no

# Nonaktifkan autentikasi password (aktifkan setelah SSH Key terkonfigurasi)
PasswordAuthentication no
ChallengeResponseAuthentication no
KbdInteractiveAuthentication no

# Aktifkan autentikasi dengan public key
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys

# Nonaktifkan fitur-fitur yang tidak diperlukan
X11Forwarding no
AllowTcpForwarding no
PermitEmptyPasswords no
PermitUserEnvironment no

# Batasi waktu login
LoginGraceTime 30

# Maksimal percobaan autentikasi per koneksi
MaxAuthTries 3

# Batasi sesi per koneksi
MaxSessions 5

# Timeout idle (lihat Langkah 5.2)
ClientAliveInterval 300
ClientAliveCountMax 2

# Batasi akses hanya untuk user tertentu (lihat Langkah 5.1)
AllowUsers namauser

# Algoritma kriptografi yang kuat (opsional, untuk hardening lanjut)
# KexAlgorithms curve25519-sha256,diffie-hellman-group14-sha256
# Ciphers aes256-gcm@openssh.com,chacha20-poly1305@openssh.com
# MACs hmac-sha2-256,hmac-sha2-512
```

---

### 4.7 Validasi Sintaks Konfigurasi

Sebelum merestart SSH, selalu validasi sintaks file konfigurasi:

```bash
sudo sshd -t
```

Jika tidak ada output (tidak ada error), konfigurasi valid dan aman untuk diterapkan.

---

### 4.8 Reload/Restart SSH Service

```bash
sudo systemctl restart ssh
```

Atau gunakan reload (lebih aman, tidak memutus sesi yang sedang aktif):

```bash
sudo systemctl reload ssh
```

---

## 5. Praktik Keamanan Tambahan

### 5.1 Batasi Login Hanya untuk User Tertentu (`AllowUsers`)

Direktif `AllowUsers` memastikan hanya user yang disebutkan secara eksplisit yang bisa login via SSH. User lain akan ditolak meskipun memiliki akun di server.

```bash
sudo nano /etc/ssh/sshd_config
```

Tambahkan atau modifikasi baris:

```
# Satu user
AllowUsers namauser

# Beberapa user (pisahkan dengan spasi)
AllowUsers namauser user2 deployuser

# Hanya izinkan user dari IP tertentu
AllowUsers namauser@192.168.1.100

# Izinkan seluruh anggota grup tertentu (alternatif AllowUsers)
AllowGroups sshusers sudo
```

> **📌 Catatan:** `AllowUsers` dan `AllowGroups` bersifat **whitelist**. Siapapun yang tidak tercantum akan langsung ditolak, tanpa melihat konfigurasi lainnya.

---

### 5.2 Konfigurasi Auto-Logout Saat Idle

Parameter `ClientAliveInterval` dan `ClientAliveCountMax` bekerja sama untuk mendeteksi dan memutus sesi yang tidak aktif.

```
# Kirim sinyal "keep-alive" ke klien setiap 300 detik (5 menit)
ClientAliveInterval 300

# Putuskan koneksi jika klien tidak merespons sebanyak 2 kali berturut-turut
ClientAliveCountMax 2
```

**Cara kerjanya:**
- SSH server akan mengirim sinyal ke klien setiap `ClientAliveInterval` detik
- Jika klien tidak merespons sebanyak `ClientAliveCountMax` kali, koneksi diputus
- Total waktu timeout = `300 × 2 = 600 detik` (10 menit)

**Sesuaikan nilai sesuai kebutuhan:**
- Server produksi sensitif: `ClientAliveInterval 60`, `ClientAliveCountMax 3` (3 menit)
- Server development: `ClientAliveInterval 300`, `ClientAliveCountMax 3` (15 menit)

---

### 5.3 Konfigurasi Firewall — Wajib Sebelum Restart SSH!

> **⚠️ Peringatan Krusial: JANGAN restart SSH sebelum firewall dikonfigurasi!**
> Jika Anda mengganti port SSH ke 2288 dan me-restart SSH tanpa membuka port tersebut di firewall terlebih dahulu, Anda akan **ter-lockout** dari server dan tidak bisa masuk lagi!

---

#### Opsi A: Menggunakan UFW (Uncomplicated Firewall) — Lebih Mudah

Instal UFW jika belum ada:

```bash
sudo apt install ufw -y
```

**Langkah konfigurasi (URUTAN PENTING):**

```bash
# Langkah 1: Buka port SSH BARU terlebih dahulu
sudo ufw allow 2288/tcp comment 'SSH Custom Port'

# Langkah 2: (Opsional) Tutup port 22 lama setelah memastikan port baru berfungsi
# sudo ufw deny 22/tcp

# Langkah 3: Izinkan koneksi keluar
sudo ufw default allow outgoing

# Langkah 4: Blokir koneksi masuk yang tidak diizinkan
sudo ufw default deny incoming

# Langkah 5: Aktifkan UFW
sudo ufw enable

# Verifikasi status
sudo ufw status verbose
```

Output verifikasi yang diharapkan:

```
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), disabled (routed)
New profiles: skip

To                         Action      From
--                         ------      ----
2288/tcp                   ALLOW IN    Anywhere
```

---

#### Opsi B: Menggunakan nftables — Lebih Powerful (Default di Debian 12)

> **📌 Catatan:** Debian 12 menggunakan nftables sebagai backend firewall default.

Cek apakah nftables aktif:

```bash
sudo systemctl status nftables
```

Buat atau edit file konfigurasi nftables:

```bash
sudo nano /etc/nftables.conf
```

Contoh konfigurasi dasar yang aman:

```nft
#!/usr/sbin/nft -f

flush ruleset

table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;

        # Izinkan koneksi loopback
        iif lo accept

        # Izinkan koneksi yang sudah terbentuk (established/related)
        ct state established,related accept

        # Izinkan ICMP (ping)
        ip protocol icmp accept
        ip6 nexthdr icmpv6 accept

        # Izinkan SSH di port baru
        tcp dport 2288 accept comment "SSH Custom Port"

        # Log koneksi yang ditolak (opsional)
        # log prefix "nftables-drop: " counter drop
    }

    chain output {
        type filter hook output priority 0; policy accept;
    }

    chain forward {
        type filter hook forward priority 0; policy drop;
    }
}
```

Terapkan konfigurasi:

```bash
sudo nft -f /etc/nftables.conf

# Aktifkan nftables agar berjalan otomatis
sudo systemctl enable --now nftables

# Verifikasi ruleset aktif
sudo nft list ruleset
```

---

### 5.4 Keamanan Tambahan: Fail2Ban (Sangat Direkomendasikan)

Fail2Ban secara otomatis memblokir IP yang terlalu sering gagal login:

```bash
sudo apt install fail2ban -y
```

Buat konfigurasi lokal:

```bash
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo nano /etc/fail2ban/jail.local
```

Temukan dan sesuaikan bagian `[sshd]`:

```ini
[sshd]
enabled  = true
port     = 2288
filter   = sshd
logpath  = /var/log/auth.log
maxretry = 3
bantime  = 3600
findtime = 600
```

**Penjelasan parameter:**
- `maxretry = 3` → Blokir setelah 3 kali gagal login
- `bantime = 3600` → IP diblokir selama 1 jam (3600 detik)
- `findtime = 600` → Hitung percobaan gagal dalam 10 menit terakhir

Aktifkan Fail2Ban:

```bash
sudo systemctl enable --now fail2ban
sudo fail2ban-client status sshd
```

---

## 6. Pengujian dan Verifikasi

> **⚠️ Aturan Paling Penting: JANGAN pernah menutup sesi SSH yang sedang aktif saat melakukan pengujian!**
> Buka tab terminal baru atau sesi terminal baru untuk pengujian. Jika ada yang salah, Anda masih bisa memperbaikinya melalui sesi yang aktif.

---

### 6.1 Urutan Pengujian yang Aman (Checklist)

Ikuti urutan ini secara ketat:

```
[ ] 1. Konfigurasi sshd_config selesai diedit
[ ] 2. sudo sshd -t (validasi sintaks — tidak ada error)
[ ] 3. Firewall sudah membuka port 2288
[ ] 4. sudo systemctl restart ssh
[ ] 5. Buka TAB TERMINAL BARU (JANGAN tutup sesi lama)
[ ] 6. Uji koneksi ke port baru dari klien
[ ] 7. Pastikan login berhasil di sesi baru
[ ] 8. Baru tutup sesi lama jika semua berfungsi
```

---

### 6.2 Uji Koneksi dari Klien

Di **tab terminal baru** pada komputer klien, jalankan:

```bash
# Dengan SSH Key (metode utama)
ssh -i ~/.ssh/id_ed25519 -p 2288 namauser@IP_SERVER

# Mode verbose untuk debugging (sangat membantu jika ada masalah)
ssh -vvv -i ~/.ssh/id_ed25519 -p 2288 namauser@IP_SERVER
```

---

### 6.3 Verifikasi di Sisi Server

Setelah berhasil login, verifikasi beberapa hal:

```bash
# Cek port yang sedang didengarkan SSH
sudo ss -tlnp | grep ssh

# Cek log SSH untuk aktivitas terbaru
sudo tail -50 /var/log/auth.log

# Cek sesi yang sedang aktif
who
w

# Cek status service SSH
sudo systemctl status ssh
```

Output `ss` yang diharapkan (menunjukkan port 2288 aktif):

```
LISTEN  0   128   0.0.0.0:2288   0.0.0.0:*   users:(("sshd",pid=XXX,fd=3))
```

---

### 6.4 Uji Penolakan Login Root

Pastikan login root ditolak:

```bash
# Dari klien (di tab baru), coba login sebagai root
ssh -p 2288 root@IP_SERVER
```

Output yang diharapkan:

```
root@IP_SERVER: Permission denied (publickey).
```

Ini berarti konfigurasi `PermitRootLogin no` berfungsi dengan benar.

---

### 6.5 Uji Penolakan Login dengan Password

Pastikan autentikasi password ditolak:

```bash
# Coba tanpa SSH key (khusus pengujian)
ssh -o PubkeyAuthentication=no -p 2288 namauser@IP_SERVER
```

Output yang diharapkan:

```
namauser@IP_SERVER: Permission denied (publickey).
```

Ini mengkonfirmasi `PasswordAuthentication no` berfungsi.

---

### 6.6 Tambahan: Buat File `~/.ssh/config` di Klien (Opsional tapi Sangat Disarankan)

Agar tidak perlu mengetik panjang setiap kali koneksi, buat file konfigurasi SSH di klien:

```bash
nano ~/.ssh/config
```

Isi dengan:

```
Host myserver
    HostName IP_SERVER
    User namauser
    Port 2288
    IdentityFile ~/.ssh/id_ed25519
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

Set permission file:

```bash
chmod 600 ~/.ssh/config
```

Sekarang Anda bisa koneksi hanya dengan:

```bash
ssh myserver
```

---

## Ringkasan Konfigurasi Akhir `/etc/ssh/sshd_config`

Berikut adalah ringkasan baris-baris kunci yang telah diubah:

| Parameter | Nilai Lama | Nilai Baru | Alasan |
|---|---|---|---|
| `Port` | `22` | `2288` | Kurangi automated scanning |
| `PermitRootLogin` | `prohibit-password` | `no` | Cegah akses root langsung |
| `PasswordAuthentication` | `yes` | `no` | Wajibkan SSH Key |
| `X11Forwarding` | `yes` | `no` | Kurangi attack surface |
| `LoginGraceTime` | `120` | `30` | Kurangi window brute-force |
| `MaxAuthTries` | `6` | `3` | Batasi percobaan login |
| `ClientAliveInterval` | (tidak ada) | `300` | Auto-logout idle |
| `ClientAliveCountMax` | (tidak ada) | `2` | Auto-logout idle |
| `AllowUsers` | (tidak ada) | `namauser` | Whitelist user |

---

## Pemulihan Darurat (Jika Ter-Lockout)

Jika Anda ter-lockout dari server, gunakan salah satu metode berikut:

1. **Akses via Console/VNC** → Melalui panel kontrol VPS (DigitalOcean, Vultr, dll.) biasanya tersedia akses console web
2. **Rescue Mode** → Boot server ke rescue mode dari panel kontrol VPS
3. **Recovery via Fisik** → Jika server fisik, colok monitor dan keyboard langsung ke server

Setelah mendapat akses:

```bash
# Restore konfigurasi backup
sudo cp /etc/ssh/sshd_config.backup /etc/ssh/sshd_config
sudo systemctl restart ssh
```

---

*Panduan ini disusun mengikuti standar keamanan CIS Benchmark untuk OpenSSH dan rekomendasi resmi dari OpenSSH Project.*

---

**Akhir Dokumen**
