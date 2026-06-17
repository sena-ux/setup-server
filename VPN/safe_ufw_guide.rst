========================================================================
Panduan Aman Konfigurasi UFW Firewall: Bebas Risiko Terkunci (Anti-Lockout)
========================================================================

Mengonfigurasi firewall pada server jarak jauh (*remote server*) sering kali menimbulkan kecemasan bagi seorang DevOps pemula. Kesalahan kecil dalam urutan perintah dapat memutus sesi SSH dan mengunci Anda di luar sistem secara permanen. 

Panduan ini menggunakan **UFW (Uncomplicated Firewall)** yang ramah pemula dan menerapkan taktik jaring pengaman (*Safety Net*) 100% aman untuk memastikan Anda tidak akan pernah terkunci lagi saat melakukan eksperimen.

1. Mengapa Pemula Sering Terkunci? (Analisis Kesalahan Umum)
============================================================

Ada tiga kesalahan fatal yang paling sering terjadi saat mengonfigurasi firewall:

* **Mengaktifkan Firewall Sebelum Membuat Aturan (Rules):** Menjalankan perintah ``ufw enable`` pada kondisi *default policy* ``DROP`` tanpa mengizinkan port SSH terlebih dahulu.
* **Asumsi Nomor Port yang Salah:** Mengizinkan port default ``22``, padahal daemon SSH di server telah diubah ke custom port (misalnya ``2222``).
* **Kehilangan Sesi SSH Saat Mengubah Default Policy:** Mengubah kebijakan global menjadi ``DROP`` di tengah jalan sebelum memastikan aturan lalu lintas masuk (*ingress*) untuk IP atau port Anda sudah aktif secara presisi.

2. Trik "Safety Net" (Jaring Pengaman) Menggunakan Cron Job
==========================================================

Sebelum menyentuh konfigurasi UFW, kita akan memasang jaring pengaman otomatis. Kita akan memerintahkan server untuk **mematikan UFW setiap 10 menit**. 

Jika Anda melakukan kesalahan dan koneksi SSH terputus, Anda cukup menunggu maksimal 10 menit hingga Cron Job mematikan firewall, dan Anda dapat masuk kembali untuk memperbaiki konfigurasi.

Langkah-langkah memasang Safety Net:
------------------------------------

1. Buka konfigurasi crontab global dengan hak akses root:

   .. code-block:: bash

       sudo crontab -e

2. Tambahkan baris berikut di bagian paling bawah file:

   .. code-block:: text

       # Matikan UFW setiap 10 menit untuk mencegah self-lockout saat uji coba
       */10 * * * * /usr/sbin/ufw disable

3. Simpan dan keluar dari editor. Sekarang Anda memiliki waktu 10 menit untuk bereksperimen dengan aman.

3. Konfigurasi Aturan Port Sebelum Mengaktifkan UFW
===================================================

Pastikan port esensial (SSH dan VPN) didaftarkan **SEBELUM** Anda beralih ke status ``enable``.

Langkah 1: Cek Port SSH Anda Saat Ini
--------------------------------------
Pastikan Anda tahu di port mana SSH Anda berjalan. Jalankan perintah:

.. code-block:: bash

    sudo ss -tulpn | grep sshd

*Jika output menunjukkan ``*:22``, berarti Anda menggunakan port default. Jika ``*:2222``, gunakan port tersebut pada langkah berikutnya.*

Langkah 2: Daftarkan Aturan Port Secara Berurutan
-------------------------------------------------
Jalankan perintah berikut secara berurutan di terminal:

.. code-block:: bash

    # 1. Izinkan port SSH (Sesuaikan jika Anda menggunakan custom port, misal: 2222/tcp)
    sudo ufw allow 22/tcp comment 'Akses SSH Utama'

    # 2. Izinkan port WireGuard VPN (Menggunakan protokol UDP)
    sudo ufw allow 51820/udp comment 'Akses WireGuard VPN'

Langkah 3: Verifikasi Aturan yang Telah Dibuat
----------------------------------------------
Cek daftar antrean aturan yang baru saja Anda buat sebelum mengaktifkannya:

.. code-block:: bash

    sudo ufw show added

4. Mengubah Default Policy Menjadi DROP dan Mengaktifkan UFW
============================================================

Secara default, jika tidak ada aturan yang cocok, UFW akan menolak semua paket masuk. Namun, untuk memastikan sistem benar-benar ketat, kita set *default policy* ke ``DROP`` secara eksplisit.

.. code-block:: bash

    # Mengubah kebijakan default lalu lintas masuk menjadi DROP
    sudo ufw default deny incoming

    # Mengubah kebijakan default lalu lintas keluar menjadi ALLOW (Aman agar server bisa update)
    sudo ufw default allow outgoing

Mengaktifkan Firewall:
----------------------
Sekarang, aktifkan UFW dengan percaya diri:

.. code-block:: bash

    sudo ufw enable

Sistem akan menampilkan peringatan: ``Command may disrupt existing ssh connections. Proceed with y/n?``. Ketik ``y`` lalu ``Enter``.

.. note::
   **JANGAN TUTUP SESI SSH ANDA SAAT INI.** Buka jendela terminal baru di komputer Anda, lalu coba lakukan koneksi SSH baru ke server. Jika koneksi baru berhasil masuk, konfigurasi Anda sukses!

Menghapus Safety Net (Jika Sudah Sukses):
----------------------------------------
Jika uji coba koneksi baru berhasil dan Anda yakin semuanya aman, hapus Cron Job jaring pengaman agar firewall tetap aktif permanen.

.. code-block:: bash

    sudo crontab -e
    # Hapus atau beri tanda komentar (#) pada baris UFW disable yang dibuat tadi.

5. Cara Membaca Log UFW untuk Analisis Paket Terblokir
======================================================

Jika ada layanan yang tiba-tiba tidak bisa diakses setelah UFW aktif, Anda perlu memeriksa log untuk melihat paket apa saja yang dijatuhkan (*dropped*).

Langkah 1: Aktifkan Fitur Logging UFW
-------------------------------------

.. code-block:: bash

    sudo ufw logging on

Langkah 2: Membaca Log Secara Real-Time
---------------------------------------
Log UFW akan dicatat ke dalam file syslog sistem. Gunakan perintah berikut untuk memantaunya secara langsung:

.. code-block:: bash

    sudo tail -f /var/log/ufw.log

*Jika file tersebut kosong pada distro tertentu, Anda bisa memeriksa log sistem melalui dmesg atau journalctl:*

.. code-block:: bash

    sudo journalctl -f -u ufw

Contoh Baris Log yang Diblokir:
-------------------------------

.. code-block:: text

    [UFW BLOCK] IN=eth0 OUT= MAC=52:54:00:... SRC=192.168.1.50 DST=10.0.0.1 LEN=40 TOS=0x00 PROTO=TCP SPT=45322 DPT=80 WINDOW=0 RES=0x00 SYN URGP=0

*Cara membaca data di atas:*
* ``SRC``: Alamat IP asal yang mencoba masuk (192.168.1.50).
* ``DST``: Alamat IP server Anda (10.0.0.1).
* ``PROTO``: Protokol yang digunakan (TCP).
* ``DPT``: *Destination Port* / Port tujuan (80). Artinya, ada lalu lintas HTTP (port 80) yang diblokir oleh UFW karena Anda belum membuat aturan ``ufw allow 80/tcp``.
