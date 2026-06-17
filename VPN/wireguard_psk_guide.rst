============================================================
Panduan Konfigurasi Preshared Key (PSK) pada WireGuard VPN
============================================================

Panduan ini menjelaskan langkah-langkah untuk menambahkan lapisan keamanan tambahan berupa *Preshared Key* (PSK) pada instalasi WireGuard yang sudah berjalan di server Linux (Ubuntu/Debian).

1. Konsep Kriptografi PSK pada WireGuard
=======================================

Secara *default*, WireGuard menggunakan kriptografi kunci publik (*asymmetric cryptography*) menggunakan Curve25519 untuk melakukan *key exchange*. Meskipun sangat aman, metode ini rentan terhadap ancaman masa depan dari *Quantum Computing* jika peretas merekam lalu lintas data yang terenkripsi sekarang dan mendekripsinya di masa depan ketika komputer kuantum yang kuat sudah tersedia.

Dengan menambahkan **Preshared Key (PSK)**, WireGuard menyuntikkan kunci simetris 256-bit tambahan ke dalam proses *key exchange* (Noise_IKpsk2_25519_ChaChaPoly_BLAKE2s). 

.. note::
   Jika kunci publik Anda dicuri atau didekripsi oleh komputer kuantum di masa depan, penyerang **tetap tidak bisa** mendekripsi lalu lintas data Anda kecuali mereka juga memiliki kunci PSK ini. Ini memberikan keamanan dengan sifat *Post-Quantum Resistance*.

2. Men-generate Kunci PSK di Server
===================================

Langkah pertama adalah membuat kunci PSK baru yang aman menggunakan perintah bawaan WireGuard (``wg genpsk``).

Jalankan perintah berikut di terminal server Anda:

.. code-block:: bash

    # Pindah ke direktori WireGuard dan atur umask agar file bersifat privat
    cd /etc/wireguard/
    umask 077

    # Generate PSK dan simpan ke file teks
    wg genpsk > client1.psk

    # Tampilkan isi kunci PSK untuk disalin nanti
    cat client1.psk

Kunci yang dihasilkan akan berupa string *base64* sepanjang 44 karakter, mirip seperti ini:
``KjH7G...[CONTOH_KUNCI_PSK]...v9X8=``

3. Modifikasi File Konfigurasi SERVER (``wg0.conf``)
===================================================

Anda perlu menambahkan opsi ``PresharedKey`` di bawah blok ``[Peer]`` milik klien yang bersangkutan. 

Buka file konfigurasi server:

.. code-block:: bash

    sudo nano /etc/wireguard/wg0.conf

Sesuaikan strukturnya seperti contoh di bawah ini:

.. code-block:: ini

    [Interface]
    Address = 10.0.0.1/24
    SaveConfig = false
    PrivateKey = <KUNCI_PRIVAT_SERVER>
    ListenPort = 51820

    # Blok Peer Klien yang ditambahkan PSK
    [Peer]
    PublicKey = <KUNCI_PUBLIK_KLIEN>
    PresharedKey = <ISI_KUNCI_PSK_YANG_DIGENERATE_TADI>
    AllowedIPs = 10.0.0.2/32

4. Modifikasi File Konfigurasi KLIEN
====================================

Kunci PSK yang **sama** harus dimasukkan ke dalam konfigurasi klien (Laptop atau HP). Jika kunci tidak cocok atau tidak diisi di salah satu sisi, koneksi akan gagal total.

Buka konfigurasi klien Anda (misal: ``client.conf``):

.. code-block:: ini

    [Interface]
    Address = 10.0.0.2/24
    PrivateKey = <KUNCI_PRIVAT_KLIEN>
    DNS = 1.1.1.1

    [Peer]
    PublicKey = <KUNCI_PUBLIK_SERVER>
    PresharedKey = <ISI_KUNCI_PSK_YANG_SAMA_DENGAN_SERVER>
    Endpoint = <IP_PUBLIK_SERVER>:51820
    AllowedIPs = 0.0.0.0/0
    PersistentKeepalive = 25

5. Me-restart Service WireGuard dengan Aman
============================================

Untuk menerapkan konfigurasi baru tanpa memutus sesi SSH Anda saat ini, jangan gunakan perintah ``systemctl restart wg-quick@wg0`` jika Anda tidak yakin dengan konfigurasi routingnya. 

Cara paling aman dan *seamless* (tanpa memutus koneksi yang sedang berjalan) adalah menggunakan perintah ``wg syncconf``:

.. code-block:: bash

    # Muat ulang konfigurasi wg0 secara dinamis tanpa mematikan interface
    sudo wg syncconf wg0 <(sudo wg-quick strip wg0)

Perintah di atas akan membaca perubahan pada ``wg0.conf`` dan menerapkannya langsung ke *kernel module* WireGuard secara instan.

6. Verifikasi Koneksi dengan PSK
================================

Setelah konfigurasi di sisi server dan klien aktif, lakukan verifikasi untuk memastikan PSK telah bekerja dengan benar.

Langkah 1: Cek Status WireGuard di Server
-----------------------------------------
Jalankan perintah berikut:

.. code-block:: bash

    sudo wg show

Jika konfigurasi sukses, Anda akan melihat baris **preshared key** muncul pada informasi peer tersebut:

.. code-block:: text

    interface: wg0
      public key: vSg...server...pub=
      private key: (hidden)
      listening port: 51820

    peer: cKj...client...pub=
      preshared key: abcdefghijklmnopqrstuvwxyz0123456789=  <-- MEMASTIKAN PSK AKTIF
      endpoint: 203.0.113.5:12345
      allowed ips: 10.0.0.2/32
      latest handshake: 5 seconds ago
      transfer: 1.2 KiB received, 840 B sent

Langkah 2: Uji Konektivitas (Ping)
----------------------------------
Lakukan *ping* dari sisi klien ke IP server WireGuard:

.. code-block:: bash

    ping -c 3 10.0.0.1

.. important::
   Jika status ``latest handshake`` terus diperbarui (di bawah 2 menit) dan data ``transfer`` terus bertambah saat Anda melakukan ping, maka konfigurasi PSK Anda telah **berhasil 100% dan berjalan dengan aman**.
