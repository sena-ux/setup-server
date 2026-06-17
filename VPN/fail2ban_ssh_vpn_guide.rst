========================================================================
Panduan Mengamankan SSH di Balik VPN Menggunakan Fail2Ban
========================================================================

Panduan ini ditujukan bagi Administrator Sistem dan DevOps yang ingin menambahkan lapisan keamanan ekstra pada layanan SSH yang berjalan di jaringan VPN. Fail2Ban akan memantau log autentikasi dan memblokir otomatis IP yang melakukan percobaan masuk yang gagal secara berulang.

1. Instalasi Fail2Ban di Linux (Ubuntu/Debian)
==============================================

Langkah pertama adalah memperbarui indeks paket repositori lokal dan memasang paket Fail2Ban.

Jalankan perintah berikut di terminal server Anda:

.. code-block:: bash

    # Memperbarui repositori paket
    sudo apt update

    # Menginstal Fail2Ban
    sudo apt install fail2ban -y

Setelah instalasi selesai, layanan Fail2Ban akan otomatis berjalan di latar belakang. Anda dapat memastikan statusnya aktif dengan perintah:

.. code-block:: bash

    sudo systemctl status fail2ban

2. Membuat File Konfigurasi Lokal (``jail.local``)
==================================================

Fail2Ban membawa file konfigurasi utama bernama ``/etc/fail2ban/jail.conf``. Namun, file ini **tidak boleh diubah langsung** karena akan tertimpa atau ter-*overwrite* saat ada pembaruan paket di masa mendatang.

Praktik terbaik yang aman adalah membuat salinan atau membuat file baru bernama ``jail.local``. Fail2Ban akan otomatis membaca file ``.local`` ini dan menjadikannya prioritas utama.

.. code-block:: bash

    # Membuat file jail.local baru yang kosong
    sudo nano /etc/fail2ban/jail.local

3. Konfigurasi Detail untuk SSH Jail & Whitelist (IgnoreIP)
==========================================================

Tuliskan konfigurasi di bawah ini ke dalam file ``/etc/fail2ban/jail.local`` yang baru saja Anda buka. 

Pastikan Anda memasukkan segmen IP VPN Anda pada bagian ``ignoreip`` agar Anda tidak terkunci secara tidak sengaja (*self-lockout*) saat fase eksperimen atau belajar.

.. code-block:: ini

    [DEFAULT]
    # 4. Memasukkan IP VPN ke dalam Daftar Putih (Whitelist)
    # Pisahkan dengan spasi jika ingin menambah lebih dari satu IP/CIDR.
    # Contoh: 127.0.0.1 (localhost) dan 10.0.0.0/24 (Subnet VPN Anda)
    ignoreip = 127.0.0.1/8 ::1 10.0.0.0/24

    # Durasi pemblokiran IP (misal: 1h = 1 jam, 1d = 1 hari)
    bantime  = 1h

    # Jendela waktu pencarian log untuk akumulasi kegagalan
    findtime = 10m

    # Jumlah maksimal kegagalan login sebelum IP diblokir
    maxretry = 3

    # Backend pencarian log yang optimal untuk systemd (Ubuntu/Debian modern)
    backend = systemd

    [sshd]
    # Mengaktifkan jail khusus untuk SSH
    enabled = true
    
    # Menentukan port SSH internal Anda. 
    # Jika menggunakan port default, isi 'ssh'. Jika port custom, isi angkanya (misal: 2222)
    port    = ssh
    
    # Jalur log yang akan dipantau (opsional jika menggunakan backend systemd)
    logpath = %(sshd_log)s

Simpan file tersebut (pada Nano: Tekan ``Ctrl + O``, lalu ``Enter``, dan keluar dengan ``Ctrl + X``).

Setelah mengubah konfigurasi, muat ulang layanan Fail2Ban untuk menerapkan perubahan:

.. code-block:: bash

    sudo systemctl restart fail2ban

4. Memantau Status Fail2Ban (Melihat IP Terblokir)
==================================================

Anda dapat menggunakan utilitas bawaan ``fail2ban-client`` untuk memantau status operasional secara langsung dari terminal.

Untuk melihat daftar *jail* yang sedang aktif:
----------------------------------------------

.. code-block:: bash

    sudo fail2ban-client status

Untuk melihat detail statistik dan daftar IP yang diblokir pada jail SSH:
------------------------------------------------------------------------

.. code-block:: bash

    sudo fail2ban-client status sshd

*Contoh output yang berhasil:*

.. code-block:: text

    Status for the jail: sshd
    |- Filter
    |  |- Currently failed: 1
    |  |- Total failed:     6
    |  `- Journal matches:  _SYSTEMD_UNIT=sshd.service + _COMM=sshd
    `- Actions
       |- Currently banned: 1
       |- Total banned:     2
       `- Banned IP list:   192.168.100.55  <-- IP yang sedang diblokir

Memantau log Fail2Ban secara Real-Time:
---------------------------------------

.. code-block:: bash

    sudo tail -f /var/log/fail2ban.log

5. Cara Manual Membuka Blokir (Unban) IP
========================================

Jika ada anggota tim atau Anda sendiri yang melakukan kesalahan pengetikan kata sandi hingga IP terblokir secara tidak sengaja, Anda dapat membuka blokir tersebut secara manual tanpa harus me-restart seluruh sistem.

Gunakan perintah berikut untuk melakukan **unban**:

.. code-block:: bash

    # Format: sudo fail2ban-client set [NAMA_JAIL] unbanip [ALAMAT_IP]
    sudo fail2ban-client set sshd unbanip 192.168.100.55

Jika eksekusi berhasil, sistem akan merespons dengan menampilkan kembali alamat IP tersebut sebagai tanda bahwa aturan pemblokiran pada *firewall* (iptables/nftables) telah dicabut.
