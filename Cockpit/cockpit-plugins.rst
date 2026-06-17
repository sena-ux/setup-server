===================================================
Panduan Instalasi Plugin Resmi Cockpit (Production)
===================================================

Dokumentasi ini berisi daftar lengkap *plugin* resmi (*official*) yang dikembangkan dan diaudit langsung oleh tim Cockpit / Red Hat. Demi menjaga keamanan tingkat tinggi pada server *production*, sangat disarankan untuk **hanya** menggunakan *plugin* yang ada di dalam daftar ini.

.. note::
   Semua plugin di bawah ini tersedia langsung di dalam repositori resmi distribusi Linux Anda (Ubuntu/Debian). Anda tidak perlu mengunduh (*clone*) kode dari GitHub pihak ketiga.

Daftar Lengkap Plugin Resmi & Kegunaannya
========================================

1. Cockpit Podman (``cockpit-podman``)
-------------------------------------
* **Kegunaan:** Menyediakan antarmuka visual penuh untuk mengelola kontainer, *pod*, dan *image* berbasis Podman.
* **Fungsi di Production:** Membuat kontainer, melihat log aplikasi (seperti Laravel & Inlislite) secara *real-time*, memantau penggunaan RAM/CPU kontainer, serta mengatur *auto-start* kontainer saat server *booting*.

2. Cockpit NetworkManager (``cockpit-networkmanager``)
-----------------------------------------------------
* **Kegunaan:** Mengelola seluruh konfigurasi jaringan, *interface*, dan *firewall* server secara visual.
* **Fungsi di Production:** Memantau grafik trafik masuk/keluar (*bandwidth*), mengonfigurasi IP statis/dinamis, mengelola *virtual interfaces* (seperti VPN WireGuard ``wg0``), serta mengatur zona *Firewalld*.

3. Cockpit Storage (``cockpit-storaged``)
-----------------------------------------
* **Kegunaan:** Manajemen media penyimpanan (*storage*), partisi disk, dan sistem file Linux.
* **Fungsi di Production:** Memantau kesehatan SSD/NVMe, melihat sisa kapasitas disk harian, membuat partisi baru, mengelola volume LVM, hingga melakukan *mounting* disk tambahan secara aman.

4. Cockpit PackageKit (``cockpit-packagekit``)
---------------------------------------------
* **Kegunaan:** Manajemen pembaruan aplikasi dan paket *software* sistem operasi (setara dengan ``apt``).
* **Fungsi di Production:** Memberikan notifikasi visual jika ada pembaruan keamanan (*security updates*) kritis pada OS Linux, dan memungkinkan Anda menginstalnya cukup dengan satu klik.

5. Cockpit Identities (``cockpit-identities``)
----------------------------------------------
* **Kegunaan:** Pusat manajemen pengguna (User) dan hak akses (Group) sistem operasi secara visual.
* **Fungsi di Production:** Membuat atau menghapus user tim, memblokir akun yang tidak aktif, mengatur hak akses ``sudo``, serta menambahkan SSH Key ke dalam profil user tanpa CLI.

6. Cockpit Benchmark (``cockpit-benchmark``)
--------------------------------------------
* **Kegunaan:** Alat penguji stres (*stress test*) dan pengukur performa maksimal dari komponen server VPS.
* **Fungsi di Production:** Menguji kecepatan baca-tulis (*Read/Write*) storage SSD/NVMe untuk mengukur kesiapan database, serta melakukan pengujian performa CPU saat beban kerja padat.

7. Cockpit Machines (``cockpit-machines``)
------------------------------------------
* **Kegunaan:** Mengelola Mesin Virtual (*Virtual Machines*) berbasis KVM (Kernel-based Virtual Machine).
* **Fungsi di Production:** Membuat dan memantau "anak VPS" terisolasi di dalam server utama jika arsitektur VPS Anda mendukung *nested virtualization*.

8. Cockpit kdump (``cockpit-kdump``)
------------------------------------
* **Kegunaan:** Mengonfigurasi dan memantau sistem *Kernel Crash Dumping* (kdump).
* **Fungsi di Production:** Menyimpan status memori terakhir ke dalam disk jika server mengalami *crash* total atau *kernel panic* mendadak untuk keperluan analisis diagnostik pasca-mati.

9. Cockpit SELinux (``cockpit-selinux``)
----------------------------------------
* **Kegunaan:** Mengelola kebijakan keamanan tingkat tinggi SELinux (Security-Enhanced Linux).
* **Fungsi di Production:** Menganalisis jika ada aplikasi atau kontainer yang diblokir oleh sistem keamanan kernel tanpa harus mematikan fitur SELinux secara global.

10. Cockpit Sosreport (``cockpit-sosreport``)
--------------------------------------------
* **Kegunaan:** Membuat laporan diagnostik sistem secara mendalam (*system diagnostic report*).
* **Fungsi di Production:** Mengompilasi semua konfigurasi dan log server menjadi satu file laporan terenkripsi yang aman untuk kebutuhan audit keamanan atau bantuan teknis.


Langkah-Langkah Instalasi (via Terminal)
========================================

Pastikan Anda masuk sebagai user ``root`` atau menggunakan perintah ``sudo`` sebelum mengeksekusi perintah di bawah ini.

1. Perbarui Indeks Repositori
-----------------------------
Sebelum menginstal, selalu perbarui indeks paket sistem Anda untuk mendapatkan versi plugin paling stabil:

.. code-block:: bash

   sudo apt update

2. Cara Instalasi Per Plugin
----------------------------
Anda bisa memilih untuk menginstal *plugin* yang benar-benar dibutuhkan saja demi menjaga kebersihan menu Cockpit.

**Menginstal Podman Manager (Sangat Direkomendasikan):**

.. code-block:: bash

   sudo apt install cockpit-podman -y

**Menginstal File Storage Manager (Sangat Direkomendasikan):**

.. code-block:: bash

   sudo apt install cockpit-storaged -y

**Menginstal Network Manager:**

.. code-block:: bash

   sudo apt install cockpit-networkmanager -y

**Menginstal Software/Security Update Manager:**

.. code-block:: bash

   sudo apt install cockpit-packagekit -y

**Menginstal User Identities Manager:**

.. code-block:: bash

   sudo apt install cockpit-identities -y

**Menginstal System Benchmark:**

.. code-block:: bash

   sudo apt install cockpit-benchmark -y

3. Menginstal Beberapa Plugin Sekaligus
---------------------------------------
Jika Anda ingin langsung menginstal plugin-plugin esensial untuk server *production* Anda dalam satu perintah, jalankan:

.. code-block:: bash

   sudo apt install cockpit-podman cockpit-storaged cockpit-identities cockpit-packagekit -y

4. Menerapkan Perubahan
-----------------------
Setelah proses instalasi selesai, Anda **tidak perlu** melakukan *restart* pada server VPS Anda. Cukup *refresh* halaman web Cockpit pada browser Anda (F5), atau bersihkan cache browser jika menu belum muncul.

Untuk memastikan servis Cockpit membaca modul baru dengan sempurna, Anda juga bisa merestart servis Cockpit-nya saja:

.. code-block:: bash

   sudo systemctl restart cockpit.socket
