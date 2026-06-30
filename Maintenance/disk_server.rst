============================================================
Panduan Teknis Sistem: Manajemen Disk & Pembersihan Server
============================================================

:Penulis: Admin Sistem
:Status: Produksi / Dokumentasi Internal
:Terakhir Diperbarui: Juni 2026

Panduan ini menyediakan instruksi langkah-demi-langkah yang komprehensif untuk mendiagnosis, melacak, dan membersihkan ruang penyimpanan (*disk space*) pada server Linux produksi. Fokus utama panduan ini mencakup penggunaan utilitas ``du``, pengelolaan log kontainer **Podman**, pembersihan berkas *binary log* database, serta eliminasi *bloat* aplikasi.

---

Kupas Tuntas Perintah ``du`` (Disk Usage)
=========================================

Perintah ``du`` adalah perkakas standar Linux yang digunakan untuk menghitung estimasi penggunaan ruang berkas dan direktori.

Definisi Argumen ``du -sh``
---------------------------

* **``d`` (disk usage):** Perintah dasar untuk memeriksa alokasi fisik ruang penyimpanan berkas/folder.
* **``s`` (summarize):** Meringkas hasil keluaran. Tanpa argumen ``-s``, sistem akan menampilkan setiap sub-direktori satu per satu (menghasilkan *wall of text*). Argumen ini memaksa sistem hanya menampilkan total ukuran dari target yang ditunjuk.
* **``h`` (human-readable):** Mentransformasi hitungan blok biner menjadi satuan yang mudah dipahami manusia (K untuk Kilobytes, M untuk Megabytes, G untuk Gigabytes, T untuk Terabytes).

Pipa Perintah (*Command Pipelines*) untuk Pelacakan
---------------------------------------------------

Menjalankan ``du -sh`` secara mandiri sering kali kurang efisien pada direktori yang dalam. Gunakan kombinasi *pipeline* berikut untuk melacak 10 folder terbesar di dalam suatu direktori:

.. code-block:: bash

   du -sh /jalur/ke/direktori/* 2>/dev/null | sort -rh | head -n 10

**Penjelasan Aliran Data:**
#. ``2>/dev/null``: Membuang pesan error *Permission Denied* ke tempat sampah virtual agar tidak mengotori layar.
#. ``sort -rh``: Mengurutkan hasil berdasarkan ukuran teks (*human-readable numeric sort*) secara terbalik dari yang paling besar ke yang paling kecil (``-r`` = *reverse*).
#. ``head -n 10``: Membatasi keluaran hanya untuk 10 baris teratas.

---

Manajemen & Pembersihan Log Sistem Operasi
===========================================

Sebelum menyentuh layer aplikasi dan kontainer, bersihkan sisa log OS yang menumpuk.

Systemd Journal Logs
--------------------

Secara default, ``journalctl`` dapat mengonsumsi ruang penyimpanan hingga puluhan Gigabyte jika tidak dibatasi.

* **Periksa ukuran log saat ini:**

  .. code-block:: bash

     journalctl --disk-usage

* **Pembersihan instan (Sisakan hanya 3 hari terakhir):**

  .. code-block:: bash

     journalctl --vacuum-time=3d

* **Pembersihan instan (Batasi total ukuran menjadi 2GB):**

  .. code-block:: bash

     journalctl --vacuum-size=2G

Log Rotasi Tradisional (``/var/log``)
-------------------------------------

Berkas log lama yang sudah terkompresi (``.gz``) atau berkas log index usang (``.1``) aman untuk dihapus:

.. code-block:: bash

   find /var/log -type f -name "*.gz" -delete
   find /var/log -type f -name "*.1" -delete

---

Pembersihan Layer Kontainer Podman
==================================

Podman menyimpan seluruh data *image*, kontainer mati, *cache overlay*, dan volume di dalam direktori ``/var/lib/containers``. Jika ukurannya membengkak, lakukan pembersihan total secara aman.

Pembersihan Otomatis via Prune
------------------------------

Jangan menghapus berkas di dalam direktori ``/var/lib/containers`` secara manual menggunakan ``rm -rf``. Gunakan mesin internal Podman:

.. code-block:: bash

   podman system prune -a --volumes --force

**Efek Perintah:**
* Menghapus semua kontainer yang statusnya berhenti (*stopped*).
* Menghapus semua jaringan (*networks*) kontainer yang tidak digunakan.
* Menghapus semua *image* yang tidak terikat ke kontainer aktif (*dangling & unused images*).
* Menghapus seluruh volume lokal yang tidak digunakan oleh kontainer aktif.

Pembersihan Log Spesifik Kontainer
----------------------------------

Jika ada kontainer aktif yang terus menulis log ke standard output (stdout), berkas log kontainer tersebut dapat membesar. Anda dapat mengosongkan berkas log kontainer aktif tanpa mematikan kontainer menggunakan metode *truncate*:

.. code-block:: bash

   find /var/lib/containers/storage/overlay-containers/ -name "*container.log" -exec truncate -s 0 {} \;

---

Pembersihan & Optimasi Database MariaDB / MySQL
===============================================

Sektor ini dibagi menjadi dua bagian: pembersihan berkas transaksi (*Binary Log*) dan pembersihan tabel sampah operasional aplikasi.

Bagian 1: Pembersihan Berkas Binary Log (``mysql-bin``)
--------------------------------------------------------

*Binary Log* mencatat setiap perubahan data untuk kebutuhan replikasi. Pada server tunggal (*standalone*), log ini aman dibersihkan jika ukurannya menguras ruang disk.

.. warning::
   Jangan pernah menghapus berkas ``mysql-bin.xxxxxx`` langsung menggunakan perintah ``rm`` di Linux. Hal itu merusak indeks internal database dan dapat memicu kegagalan start layanan MySQL/MariaDB.

* **Langkah Pembersihan Aman via Konsol SQL:**

  #. Masuk ke MySQL/MariaDB:

     .. code-block:: bash

        mysql -u root -p

  #. Jalankan salah satu perintah berikut di dalam prompt ``mysql>``:

     .. code-block:: sql

        -- Opsi A: Hapus log transaksi yang umurnya lebih dari 1 hari
        PURGE BINARY LOGS BEFORE NOW() - INTERVAL 1 DAY;

        -- Opsi B: Hapus log transaksi dan sisakan mulai dari nomor berkas tertentu
        PURGE BINARY LOGS TO 'mysql-bin.001008';

  #. Keluar dari prompt:

     .. code-block:: sql

        EXIT;

* **Automasi Pembatasan Binlog (Berkala):**

  Edit berkas konfigurasi database (``/etc/mysql/my.cnf`` atau ``/etc/mysql/mariadb.conf.d/50-server.cnf``), cari blok ``[mysqld]`` dan tambahkan konfigurasi berikut:

  .. code-block:: ini

     [mysqld]
     # Otomatis hapus binlog setelah 3 hari (259200 detik)
     binlog_expire_logs_seconds = 259200
     # Batasi ukuran per file log agar tidak bengkak menjadi gigabyte
     max_binlog_size = 500M

  Setelah disimpan, *restart* layanan database:

  .. code-block:: bash

     systemctl restart mariadb

Bagian 2: Pembersihan Tabel Sampah Aplikasi (Kasus: INLISLite v3)
----------------------------------------------------------------

Pada aplikasi INLISLite 3, tabel riwayat pencarian OPAC (``opaclogs`` dan ``opaclogs_keyword``) sering kali mendominasi ukuran database hingga puluhan GB.

* **Langkah Mengosongkan Tabel Log Pencarian & Klaim Ruang Penyimpanan:**

  #. Masuk ke MySQL/MariaDB:

     .. code-block:: bash

        mysql -u root -p

  #. Pindah ke database target dan lakukan pengosongan tabel (*Truncate*):

     .. code-block:: sql

        USE db_inlislite32;
        TRUNCATE TABLE opaclogs;
        TRUNCATE TABLE opaclogs_keyword;

  #. Deframentasikan tabel fisik pada disk agar OS Linux dapat langsung membaca ruang kosong yang baru dilepaskan:

     .. code-block:: sql

        OPTIMIZE TABLE opaclogs, opaclogs_keyword;
        EXIT;

---

Pembersihan Layer Aplikasi (Kasus: CodeIgniter 4 / INLISLite Writable)
======================================================================

Masalah ruang penyimpanan penuh pada INLISLite v3 sering dipicu oleh folder ``writable/debugbar`` yang membengkak akibat aplikasi dibiarkan berjalan dalam mode *Development*.

Langkah 1: Pembersihan Instan via CLI
-------------------------------------

Hapus seluruh data riwayat Debugbar lama yang mengendap:

.. code-block:: bash

   find /home/app/inlislitev33/writable/debugbar/ -type f -delete

Langkah 2: Amankan Lingkungan Aplikasi (*Production Environment*)
-----------------------------------------------------------------

Ubah mode aplikasi menjadi *Production* untuk mematikan fitur perekaman Debugbar secara permanen.

#. Buka berkas lingkungan aplikasi:

   .. code-block:: bash

      nano /home/app/inlislitev33/.env

#. Cari variabel ``CI_ENVIRONMENT`` dan ubah nilainya:

   .. code-block:: env

      CI_ENVIRONMENT = production

#. Simpan berkas (``Ctrl+O``, ``Enter``) dan keluar (``Ctrl+X``).

---

Automasi Pembersihan Berkala (Cron Job)
=======================================

Agar server tidak mengalami kondisi *Disk Full* di masa mendatang, buat skema otomatisasi menggunakan utilitas Cron.

#. Buka editor Crontab sistem:

   .. code-block:: bash

      crontab -e

#. Tambahkan baris-baris berikut di akhir berkas untuk eksekusi setiap hari pada pukul 02:00 dini hari:

   .. code-block:: text

      # Menghapus file cache & temporary aplikasi yang berumur lebih dari 7 hari
      0 2 * * * find /home/app/inlislitev33/writable/cache/ -type f -mtime +7 -delete
      
      # Antisipasi pembersihan log aplikasi yang terlewat
      0 2 * * * find /home/app/inlislitev33/writable/logs/ -type f -mtime +7 -delete
