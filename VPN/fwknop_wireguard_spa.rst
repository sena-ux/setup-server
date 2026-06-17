========================================================================
Panduan Advance SPA dengan fwknop: Membangun "Gerbang Gaib" WireGuard
========================================================================

Panduan ini membahas langkah-langkah implementasi **Single Packet Authorization (SPA)** menggunakan ``fwknop`` (*FireWall Knock Operator*). Dengan metode ini, port WireGuard Anda (``51820 UDP``) akan berstatus ``DROP`` (tertutup total) dari pemindaian luar (*port scanning*). Port hanya akan terbuka secara dinamis selama beberapa detik setelah server menerima satu paket autentikasi terenkripsi yang valid dari klien.

1. Arsitektur dan Cara Kerja fwknop (SPA)
========================================

Berbeda dengan *Port Knocking* tradisional yang mengetuk beberapa port secara berurutan dan rentan terhadap serangan *replay*, SPA bekerja dengan mengirimkan **satu paket tunggal** yang terenkripsi dan terautentikasi melalui protokol UDP.



Cara Kerja Sistem:
------------------

1. **Klien** mengemas data berisi: IP asal klien, stempel waktu (*timestamp*), acakan acak (*nonce*), dan perintah akses (buka port 51820).
2. Data tersebut dienkripsi dengan **Rijndael (AES-256)** dan ditandatangani dengan **HMAC-SHA256** untuk menjamin integritas paket.
3. Klien mengirimkan paket ini ke server lewat port acak (default: ``62201 UDP``).
4. Daemon ``fwknopd`` di **Server** terus memantau lalu lintas jaringan secara pasif via *packet capture* (pcap) **tanpa membuka port soket mendengarkan (listening socket)**.
5. Jika ``fwknopd`` berhasil mendekripsi dan memvalidasi HMAC paket tersebut, ia akan memerintahkan *firewall* (``iptables``) untuk membuka port WireGuard khusus untuk IP klien selama durasi singkat (misal: 30 detik).
6. Klien melakukan *handshake* WireGuard. Setelah durasi habis, ``fwknopd`` menghapus aturan di ``iptables``, namun koneksi WireGuard yang sudah mapan (*established*) tetap berjalan normal.

2. Instalasi Paket fwknop
==========================

Langkah 1: Instalasi di Sisi Server (Ubuntu/Debian)
---------------------------------------------------
Jalankan perintah berikut untuk memasang daemon server:

.. code-block:: bash

    sudo apt update
    sudo apt install fwknop-server iptables -y

.. note::
   ``fwknopd`` sangat bergantung pada aturan ``iptables``. Jika server Anda menggunakan UFW atau Nftables, pastikan backend ``iptables-legacy`` tetap tersedia.

Langkah 2: Instalasi di Sisi Klien (Laptop Linux/macOS)
-------------------------------------------------------
Untuk klien berbasis Linux (Ubuntu/Debian), instal paket klien:

.. code-block:: bash

    sudo apt install fwknop-client -y

*Untuk pengguna macOS, Anda bisa memasangnya menggunakan Homebrew:* ``brew install fwknop``

3. Men-generate Keys (Kunci Enkripsi dan HMAC)
==============================================

Proses autentikasi membutuhkan dua pasang kunci simetris: **Rijndael Key** (untuk enkripsi) dan **HMAC Key** (untuk tanda tangan digital). Kita akan men-generate kunci ini di sisi klien terlebih dahulu.

Jalankan perintah berikut di **Laptop/Klien**:

.. code-block:: bash

    # Generate kunci otomatis untuk akses ke IP publik server Anda
    fwknop -A tcp/22 -D <IP_PUBLIK_SERVER> --key-gen

*Catatan: Parameter ``-A tcp/22`` di atas hanyalah syarat sintaks generator. Perintah ini akan menghasilkan output string kunci seperti berikut:*

.. code-block:: text

    [+] KEY_BASE64:      vX9Fk...[KUNCI_RIJNDAEL_ANDA]...=
    [+] HMAC_KEY_BASE64: 9zQA2...[KUNCI_HMAC_ANDA]......=

Salin kedua string *base64* tersebut karena akan kita pasang di konfigurasi server dan klien.

4. Konfigurasi di Sisi Server
=============================

Kita perlu mengonfigurasi dua file utama di direktori ``/etc/fwknop/``.

Langkah 1: Modifikasi ``/etc/fwknop/fwknopd.conf``
--------------------------------------------------
File ini mengatur perilaku global dari daemon server. Buka file tersebut:

.. code-block:: bash

    sudo nano /etc/fwknop/fwknopd.conf

Cari dan sesuaikan parameter berikut (pastikan nama *interface* jaringan sesuai dengan kartu jaringan server Anda, misal: ``eth0`` atau ``enp0s3``):

.. code-block:: ini

    # Tentukan interface internet publik yang dipantau oleh fwknopd
    PCAP_INTF                   eth0

    # Pastikan baris ini aktif untuk mengizinkan pemakaian iptables
    ENABLE_IPT_FORWARDING       N

Langkah 2: Modifikasi ``/etc/fwknop/access.conf``
--------------------------------------------------
File ini menyimpan hak akses dan kunci autentikasi unik untuk setiap klien.

.. code-block:: bash

    sudo nano /etc/fwknop/access.conf

Hapus seluruh isinya atau tambahkan konfigurasi berikut di bagian paling bawah file:

.. code-block:: ini

    SOURCE              ANY
    
    # Kunci yang Anda generate di langkah nomor 3 tadi
    KEY_BASE64          <MASUKKAN_KEY_BASE64_DARI_KLIEN>
    HMAC_KEY_BASE64     <MASUKKAN_HMAC_KEY_BASE64_DARI_KLIEN>
    
    # Menentukan port dan protokol WireGuard yang boleh dibuka oleh klien ini
    FORCE_ACCESS        udp/51820
    
    # Durasi port terbuka dalam detik sebelum ditutup kembali otomatis
    FW_ACCESS_TIMEOUT   30

Langkah 3: Restart Daemon Server
--------------------------------
Nyalakan dan aktifkan service ``fwknop-server``:

.. code-block:: bash

    sudo systemctl restart fwknop-server
    sudo systemctl enable fwknop-server

Pastikan port ``51820 UDP`` pada *firewall* utama Anda (iptables/UFW) sudah diset ke **DROP** secara default agar efek "Gerbang Gaib" ini bekerja.

5. Konfigurasi dan Pengiriman Paket SPA dari Klien
==================================================

Kembali ke **Laptop (Klien)**. Cara termudah untuk mengelola koneksi adalah dengan menyimpan profil server ke dalam file konfigurasi lokal klien di ``~/.fwknoprc``.

Buka atau buat file konfigurasi klien:

.. code-block:: bash

    nano ~/.fwknoprc

Tambahkan stanza profil seperti ini:

.. code-block:: ini

    [server_vpn]
    SPA_SERVER          <IP_PUBLIK_SERVER>
    ACCESS              udp/51820
    KEY_BASE64          <KUNCI_RIJNDAEL_YANG_SAMA>
    HMAC_KEY_BASE64     <KUNCI_HMAC_YANG_SAMA>

Cara Mengirimkan Paket Ketukan (SPA Knock):
-------------------------------------------
Saat Anda ingin terhubung ke WireGuard, jalankan perintah ini dari terminal laptop Anda:

.. code-block:: bash

    fwknop -n server_vpn

Perintah ini akan mengirimkan satu paket UDP ke server. Setelah perintah dieksekusi, Anda memiliki waktu 30 detik untuk mengaktifkan koneksi WireGuard Anda (misal: ``wg-quick up wg0``).

6. Testing dan Verifikasi Dinamis
=================================

Untuk membuktikan bahwa aturan firewall dibuat secara dinamis dan otomatis menghilang, lakukan pemantauan pada server menggunakan perintah ``iptables``.

Jalankan perintah ini di **Server** sebelum Anda mengirim paket ketukan:

.. code-block:: bash

    sudo watch -n 1 "iptables -L FWKNOP_INPUT -v -n"

**Analisis Hasil Uji Coba:**

1. **Kondisi Awal:** Rantai (*chain*) ``FWKNOP_INPUT`` akan terlihat kosong, tidak ada aturan yang mengizinkan port 51820.
2. **Saat Paket SPA Dikirim:** Sesaat setelah Anda menjalankan ``fwknop -n server_vpn`` di laptop, rantai di server akan otomatis memunculkan baris baru seperti ini:

   .. code-block:: text

       Chain FWKNOP_INPUT (1 references)
        pkts bytes target     prot opt in     out     source               destination
           0     0 ACCEPT     udp  --  * * <IP_APLIKASI_KLIEN>  0.0.0.0/0            udp dpt:51820

3. **Setelah 30 Detik:** Baris ``ACCEPT`` di atas akan dihapus secara otomatis oleh daemon ``fwknopd``, dan rantai kembali menjadi kosong bersih. Jika koneksi WireGuard Anda sudah terjalin sebelum menit ke-30, koneksi Anda tidak akan terputus karena *state* interaksinya sudah berubah menjadi ``ESTABLISHED``.

7. Tips Troubleshooting
=======================

Jika port tidak terbuka setelah Anda mengirimkan paket ketukan, periksa poin-poin berikut:

* **Stempel Waktu Terlalu Jauh (Clock Skew):** SPA menggunakan pencegahan *replay attack* berbasis waktu. Jika perbedaan waktu jam antara laptop dan server terpaut lebih dari **120 detik**, server akan menolak paket. Sinkronisasikan waktu kedua perangkat menggunakan NTP (``sudo timedatectl set-ntp true``).
* **Salah Menentukan Interface PCAP:** Jika server Anda memiliki banyak interface (misalnya gabungan antara IP publik, internal, dan docker), pastikan parameter ``PCAP_INTF`` di ``fwknopd.conf`` mengarah tepat ke interface tempat paket internet luar masuk.
* **Firewall Memblokir Port Ketukan:** Pastikan server Anda tidak memblokir port default paket SPA masuk (``62201 UDP``). Anda harus mengizinkan port ``62201 UDP`` di firewall utama agar ``fwknopd`` dapat membaca paket pcap tersebut.
