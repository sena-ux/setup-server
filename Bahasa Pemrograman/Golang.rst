==================================================
Modul Pembelajaran Komprehensif: Pemrograman Go
==================================================

.. |Author| replace:: Senior Backend Engineer & Technical Writer
.. |Date| replace:: Juni 2026

:Penulis: |Author|
:Tanggal: |Date|
:Status: Produksi / Lengkap
:Target Pembaca: Developer Pemula hingga Menengah

Modul ini dirancang sebagai panduan definitif untuk menguasai bahasa pemrograman Go (Golang) dari dasar hingga konsep tingkat lanjut seperti konkurensi dan desain sistem. Seluruh dokumentasi ini ditulis menggunakan standar reStructuredText (.rst) yang valid dan siap dikompilasi menggunakan Sphinx.

---

1. Pendahuluan ke Go
====================

Sejarah Singkat & Filosofi Desain
---------------------------------
Bahasa pemrograman Go (sering disebut **Golang**) dikembangkan di Google pada tahun 2007 oleh tiga engineer terkemuka: **Robert Griesemer, Rob Pike, dan Ken Thompson**. Dirilis sebagai proyek *open-source* pada November 2009, Go diciptakan untuk menyelesaikan masalah skala besar yang dihadapi Google: basis kode yang masif, proses kompilasi yang lambat, serta kesulitan dalam memanfaatkan perangkat keras *multi-core* secara efisien.

Filosofi desain Go berpusat pada tiga pilar utama:

* **Simplicity (Kesederhanaan):** Go sengaja dirancang dengan jumlah *keyword* yang sedikit (hanya sekitar 25 keyword). Tidak ada fitur-fitur kompleks seperti *class inheritance*, *pointer arithmetic*, atau *implicit type conversion*.
* **Readability (Keterbacaan):** Kode yang mudah dibaca jauh lebih berharga daripada kode yang singkat namun ambigu. Sintaksis Go memaksa developer menulis kode dengan gaya yang seragam.
* **Efficiency (Efisiensi):** Go adalah bahasa yang dikompilasi langsung ke bahasa mesin (*compiled language*), memberikan performa tinggi yang mendekati C/C++, namun dengan kenyamanan pengembangan layaknya bahasa dinamis (Python/JavaScript) berkat adanya *Garbage Collection*.

Kelebihan Go Dibanding Bahasa Lain
----------------------------------

.. list-table:: Perbandingan Go dengan Bahasa Lain
   :widths: 20 40 40
   :header-rows: 1

   * - Fitur / Karakteristik
     - Go
     - C++ / Java / Python
   * - **Proses Kompilasi**
     - Sangat cepat, langsung menghasilkan satu file biner statis.
     - C++ lambat; Java butuh JVM; Python adalah bahasa interpretasi (lambat).
   * - **Manajemen Memori**
     - Otomatis menggunakan *Garbage Collector* yang dioptimalkan untuk *low latency*.
     - C++ manual; Java memiliki GC yang cenderung menggunakan memori besar.
   * - **Konkurensi**
     - Native (Built-in) lewat *Goroutines* dan *Channels* yang sangat ringan.
     - Membutuhkan thread OS yang berat (Java/C++) atau terhalang oleh GIL (Python).
   * - **Sistem Tipe Data**
     - *Statically typed* dengan *type inference*. Fleksibel melalui *implicit interface*.
     - Java/C++ sangat kaku; Python bersifat *dynamically typed* (rawan runtime error).

Instalasi & Setup Environment
-----------------------------
Untuk memulai pengembangan dengan Go, ikuti langkah-langkah instalasi berikut:

1. Unduh installer resmi dari situs `golang.org <https://golang.org/dl/>`_ sesuai dengan sistem operasi Anda.
2. Jalankan installer dan ikuti petunjuk grafis atau gunakan manajemen paket (misal: ``brew install go`` di macOS atau ``sudo apt install golang-go`` di Ubuntu).

Memahami Variabel Lingkungan (*Environment Variables*):

* **$GOROOT:** Menunjukkan direktori tempat binary dan SDK Go terinstal (misalnya ``/usr/local/go`` atau ``C:\Go``). Sejak Go versi modern, Anda jarang perlu mengubah variabel ini secara manual.
* **$GOPATH:** Direktori kerja workspace Anda. Secara default, workspace ini berada di ``$HOME/go``. Di sinilah package pihak ketiga yang diunduh dan binary hasil kompilasi lokal disimpan.
* **Go Modules (Go Mod):** Sistem manajemen dependensi resmi Go sejak versi 1.11. Dengan Go Modules, Anda tidak lagi wajib meletakkan kode proyek di dalam folder ``$GOPATH/src``. Anda dapat membuat proyek di direktori mana pun di dalam sistem operasi.

Struktur Proyek Standar & Program "Hello World"
-----------------------------------------------
Mari kita buat proyek pertama kita menggunakan Go Modules. Jalankan perintah berikut pada terminal Anda:

.. code-block:: bash

    mkdir halo-dunia
    cd halo-dunia
    go mod init halo-dunia

Perintah ``go mod init`` akan menghasilkan file ``go.mod`` yang berfungsi mencatat dependensi proyek Anda. Selanjutnya, buat file bernama ``main.go`` dan masukkan kode berikut:

.. code-block:: go

    package main

    import "fmt"

    // fungsi main adalah entry point utama dari program Go
    func main() {
        fmt.Println("Hello, World!")
    }

.. note::
   Setiap program Go yang dapat dieksekusi harus memiliki ``package main`` dan di dalamnya harus terdapat fungsi bernama ``func main()``.

**Penjelasan Alur Kode Baris per Baris:**

* ``package main``: Menandakan bahwa file ini adalah bagian dari package utama. Package ``main`` memberi tahu compiler Go bahwa file ini harus dikompilasi sebagai file eksekutabel, bukan sebagai library/package yang diekspor.
* ``import "fmt"``: Mengimpor package bawaan (standard library) bernama ``fmt`` (singkatan dari *format*). Package ini menyediakan fungsi-fungsi untuk memformat teks, termasuk mencetak teks ke layar console.
* ``func main() { ... }``: Mendefinisikan fungsi utama program. Ketika file biner hasil kompilasi dijalankan, instruksi pertama yang dieksekusi adalah kode di dalam blok fungsi ini.
* ``fmt.Println("Hello, World!")``: Memanggil fungsi ``Println`` dari package ``fmt`` untuk mencetak string ke layar, diikuti dengan karakter baris baru (*newline*).

Untuk menjalankan kode tersebut tanpa kompilasi manual, gunakan perintah:

.. code-block:: bash

    go run main.go

Untuk mengompilasi menjadi satu file binary statis:

.. code-block:: bash

    go build main.go
    ./main

---

2. Dasar-Dasar Sintaksis & Tipe Data
====================================

Deklarasi Variabel & Konstanta
------------------------------
Go menyediakan beberapa cara untuk mendeklarasikan variabel dengan tujuan memberikan fleksibilitas namun tetap mempertahankan keamanan tipe data (*type safety*).

.. code-block:: go

    package main

    import "fmt"

    func main() {
        // 1. Deklarasi standar dengan tipe data eksplisit
        var nama String = "Sena Pernata"
        
        // 2. Deklarasi dengan inferensi tipe (type inference)
        var umur = 22
        
        // 3. Short variable declaration (hanya bisa di dalam fungsi)
        domisili := "Bali"
        
        // 4. Deklarasi beberapa variabel sekaligus
        var x, y int = 10, 20
        
        // 5. Deklarasi konstanta (nilainya tidak bisa diubah)
        const Pi = 3.14159

        fmt.Printf("Nama: %s, Umur: %d, Lokasi: %s\n", nama, umur, domisili)
        fmt.Printf("Koordinat: %d, %d | Nilai Pi: %f\n", x, y, Pi)
    }

**Penjelasan Alur Kode:**
Program di atas menginisialisasi variabel menggunakan tiga teknik berbeda. Variabel ``nama`` dideklarasikan secara eksplisit sebagai string. Variabel ``umur`` menebak tipenya sendiri berdasarkan nilai ``22`` (integer). Variabel ``domisili`` menggunakan operator short-declaration ``:=`` yang secara otomatis mengalokasikan memori dan menentukan tipe data tanpa keyword ``var``. Terakhir, fungsi ``fmt.Printf`` digunakan untuk mencetak string terformat menggunakan kata kunci penanda format (*verb*) seperti ``%s`` untuk string dan ``%d`` untuk integer.

.. warning::
   Go sangat ketat terhadap variabel yang tidak digunakan. Jika Anda mendeklarasikan suatu variabel di dalam fungsi namun tidak pernah membacanya, compiler Go akan memunculkan error compile-time: ``variable declared and not used``.

Tipe Data Dasar
---------------
Go memiliki tipe data statis yang sangat eksplisit:

* **String:** Kumpulan karakter yang *immutable* (tidak bisa diubah setelah dibuat), didefinisikan dengan tanda petik ganda (``"..."``) atau backtick (``\`...\``) untuk multiline string.
* **Numeric:**
    * Integer beranda (*signed*): ``int``, ``int8``, ``int16``, ``int32``, ``int64``.
    * Integer tak beranda (*unsigned*): ``uint``, ``uint8``, ``uint16``, ``uint32``, ``uint64``, ``uintptr``.
    * Float (desimal): ``float32``, ``float64``.
    * Alias: ``byte`` (sama dengan ``uint8``) dan ``rune`` (sama dengan ``int32``, merepresentasikan karakter Unicode).
* **Boolean:** Hanya bernilai ``true`` atau ``false``.

Control Flow
------------
Struktur kendali di Go memiliki keunikan tersendiri, salah satunya adalah penghapusan tanda kurung ``()`` untuk kondisi.

.. code-block:: go

    package main

    import "fmt"

    func main() {
        nilai := 85

        // If-Else dengan statement inisialisasi opsional
        if batas := 70; nilai >= batas {
            fmt.Println("Selamat, Anda Lulus!")
        } else {
            fmt.Println("Silakan coba lagi.")
        }

        // Switch-Case tanpa implicit fallthrough
        sistemOperasi := "linux"
        switch sistemOperasi {
        case "windows":
            fmt.Println("Sistem Operasi: Microsoft Windows")
        case "linux", "ubuntu": // multi-value case
            fmt.Println("Sistem Operasi: Open Source Linux")
        default:
            fmt.Println("Sistem Operasi tidak dikenal")
        }

        // Satu-satunya perulangan di Go: For Loop
        // Gaya standar
        for i := 0; i < 3; i++ {
            fmt.Printf("Iterasi ke-%d\n", i)
        }

        // For sebagai perulangan "While"
        counter := 0
        for counter < 2 {
            fmt.Println("Counter:", counter)
            counter++
        }
    }

**Penjelasan Alur Kode:**
Blok ``if`` menggunakan fitur inisialisasi variabel lokal (``batas := 70``) yang hanya valid berada di dalam cakupan (*scope*) blok ``if-else`` tersebut. Pada bagian ``switch-case``, Go secara otomatis menyematkan perintah ``break`` di akhir setiap case, sehingga program tidak akan masuk ke case berikutnya kecuali Anda secara eksplisit menambahkan kata kunci ``fallthrough``. Perulangan dilakukan hanya menggunakan kata kunci ``for``, membuktikan prinsip minimalis Go karena tidak memerlukan kata kunci ``while``.

Penanganan Pointer Secara Mendalam
----------------------------------
Pointer adalah variabel yang menyimpan *alamat memori* dari variabel lain, bukan menyimpan nilai riil data tersebut. Go mengizinkan penggunaan pointer untuk efisiensi performa, tetapi melarang operasi aritmatika pointer demi alasan keamanan.

* Operator ``&`` (Address-of): Digunakan untuk mendapatkan alamat memori suatu variabel.
* Operator ``*`` (Dereference): Digunakan untuk mengakses atau mengubah nilai yang berada di alamat memori yang ditunjuk.

.. code-block:: go

    package main

    import "fmt"

    func ubahNilaiMurni(angka int) {
        angka = 100 // Hanya mengubah salinan data (Pass by Value)
    }

    func ubahNilaiPointer(angka *int) {
        *angka = 500 // Mengubah nilai asli di alamat memori (Pass by Reference)
    }

    func main() {
        x := 10
        fmt.Println("Nilai awal x:", x)

        ubahNilaiMurni(x)
        fmt.Println("Setelah ubahNilaiMurni:", x) // Output tetap 10

        ubahNilaiPointer(&x)
        fmt.Println("Setelah ubahNilaiPointer:", x) // Output berubah jadi 500

        fmt.Println("Alamat memori x:", &x)
    }

**Penjelasan Alur Kode:**
Secara default, Go menerapkan aturan *pass-by-value*, artinya setiap kali variabel dikirim ke dalam fungsi, Go menduplikasi data tersebut ke memori baru. Fungsi ``ubahNilaiMurni`` menerima salinan nilai variabel ``x``, sehingga perubahan di dalam fungsi tidak berdampak pada variabel luar. Sebaliknya, fungsi ``ubahNilaiPointer`` menerima parameter berupa alamat memori (``*int``). Dengan melakukan dereferensi ``*angka = 500``, fungsi langsung memanipulasi lokasi memori asli tempat variabel ``x`` disimpan.

.. note::
   **Kapan harus menggunakan pointer?**
   
   1. Gunakan pointer jika fungsi perlu memodifikasi argumen input yang dikirimkan.
   2. Gunakan pointer jika data yang dilewatkan berukuran sangat besar (seperti struct dengan puluhan field) untuk menghindari konsumsi memori akibat penyalinan data (*overhead copying*).
   
   **Kapan jangan menggunakan pointer?**
   
   Untuk tipe data primitif berukuran kecil (seperti ``int``, ``float64``, ``bool``) yang tidak perlu diubah nilainya, melewatkan nilainya secara langsung jauh lebih cepat dan meringankan kerja *Garbage Collector*.

---

3. Struktur Data Lanjutan
=========================

Array vs Slices
---------------
Di dalam internal memori Go, **Array** dan **Slice** adalah dua makhluk yang sangat berbeda meskipun terlihat mirip dari segi sintaksis.

* **Array:** Struktur data dengan ukuran tetap (*fixed size*) yang ditentukan saat kompilasi. Ukuran array merupakan bagian dari tipe datanya (``[5]int`` berberda tipe dengan ``[10]int``).
* **Slice:** Struktur data dinamis yang dibangun di atas array (*backing array*). Slice bertindak sebagai jendela fleksibel yang merepresentasikan elemen-elemen array di bawahnya. Slice memiliki tiga komponen internal: pointer ke backing array, panjang (*length*), dan kapasitas (*capacity*).

.. code-block:: go

    package main

    import "fmt"

    func main() {
        // Deklarasi Array (Fixed size)
        var kumpulanAngka [3]int = [3]int{10, 20, 30}
        fmt.Println("Array:", kumpulanAngka)

        // Deklarasi Slice (Ukuran dinamis)
        bukanArray := []int{1, 2, 3}
        fmt.Printf("Slice awal: %v, Len: %d, Cap: %d\n", bukanArray, len(bukanArray), cap(bukanArray))

        // Menambahkan elemen ke slice menggunakan append
        bukanArray = append(bukanArray, 4)
        fmt.Printf("Setelah append: %v, Len: %d, Cap: %d\n", bukanArray, len(bukanArray), cap(bukanArray))

        // Fungsi copy untuk menduplikasi slice secara aman
        salinanSlice := make([]int, len(bukanArray))
        copy(salinanSlice, bukanArray)
        fmt.Println("Hasil salinan slice:", salinanSlice)
    }

**Penjelasan Alur Kode:**
Variabel ``kumpulanAngka`` didefinisikan sebagai array 3 elemen. Ukurannya tidak bisa bertambah. Di sisi lain, ``bukanArray`` dibuat sebagai slice tanpa menentukan angka di dalam tanda kurung siku ``[]``. Ketika kita memanggil fungsi ``append(bukanArray, 4)``, Go secara otomatis memeriksa apakah kapasitas (*capacity*) awal mencukupi. Jika penuh, Go membuat backing array baru yang berukuran dua kali lipat lebih besar, menyalin data lama, lalu menambahkan elemen baru. Fungsi ``make`` digunakan untuk mengalokasikan slice baru dengan panjang tertentu agar fungsi ``copy`` dapat menduplikasi elemen secara presisi tanpa menimpa alamat memori slice asal.

Maps
----
Map adalah implementasi dari struktur data *hash table* atau *key-value pair*. Map sangat efisien untuk pencarian data berdasarkan kata kunci (*key*) unik.

.. code-block:: go

    package main

    import "fmt"

    func main() {
        // Inisialisasi map menggunakan fungsi make
        // Key: string, Value: int
        rapor := make(map[string]int)

        // Manipulasi: Tambah & Update data
        rapor["Sena"] = 95
        rapor["Andi"] = 80
        fmt.Println("Map Rapor:", rapor)

        // Mengecek eksistensi sebuah key (Comma-ok idiom)
        nilai, ada := rapor["Budi"]
        if ada {
            fmt.Println("Nilai Budi:", nilai)
        } else {
            fmt.Println("Data Budi tidak ditemukan dalam sistem.")
        }

        // Menghapus data berdasarkan key
        delete(rapor, "Andi")
        fmt.Println("Setelah Andi dihapus:", rapor)
    }

**Penjelasan Alur Kode:**
Map dibuat dengan sintaks ``make(map[TipeKey]TipeValue)``. Pada bagian pengecekan key, Go menyediakan mekanisme yang aman bernama *comma-ok idiom* (``nilai, ada := rapor["Budi"]``). Variabel pertama (``nilai``) akan menampung value dari key jika ditemukan, atau nilai default (*zero value*) jika tidak ditemukan. Variabel kedua (``ada``) adalah tipe boolean yang bernilai ``true`` jika key tersebut eksis di dalam map. Fungsi bawaan ``delete`` digunakan untuk menghapus entri key secara permanen.

Structs
-------
Karena Go tidak memiliki kata kunci ``class``, **Struct** merupakan pondasi utama dalam pemodelan data objek. Struct adalah kumpulan dari satu atau beberapa field tipe data yang dikelompokkan bersama.

.. code-block:: go

    package main

    import "fmt"

    // Definisi Struct utama
    type Karyawan struct {
        ID       int
        Nama     string
        Posisi   string
        Kontak   DetailKontak // Nested struct
    }

    type DetailKontak struct {
        Email string
        Telp  string
    }

    // Method Receiver (Value Receiver)
    func (k Karyawan) CetakProfil() {
        fmt.Printf("Karyawan #%d: %s (%s)\n", k.ID, k.Nama, k.Posisi)
    }

    // Method Receiver (Pointer Receiver) untuk mengubah data internal struct
    func (k *Karyawan) PerbaruiPosisi(posisiBaru string) {
        k.Posisi = posisiBaru
    }

    func main() {
        // Inisialisasi struct beserta nested struct
        staf := Karyawan{
            ID:     101,
            Nama:   "I Made Sena",
            Posisi: "Junior Developer",
            Kontak: DetailKontak{
                Email: "sena@example.com",
                Telp:  "0812345678",
            },
        }

        staf.CetakProfil()

        // Mengubah posisi menggunakan Pointer Receiver
        staf.PerbaruiPosisi("Senior Cloud Engineer")
        fmt.Println("--- Jabatan Diperbarui ---")
        staf.CetakProfil()

        // Anonymous Struct (Hanya dipakai sekali tempat)
        config := struct {
            Port string
            Host string
        }{
            Port: "8080",
            Host: "localhost",
        }
        fmt.Printf("Aplikasi berjalan di %s:%s\n", config.Host, config.Port)
    }

**Penjelasan Alur Kode:**
Kita mendefinisikan sebuah struct bernama ``Karyawan`` yang memiliki relasi komposisi (*nested struct*) dengan ``DetailKontak``. Fungsi ``CetakProfil`` dideklarasikan sebagai *Method Receiver* dengan menempelkan ``(k Karyawan)`` sebelum nama fungsi, memberikan kemampuan pada variabel bertipe ``Karyawan`` untuk memanggil method tersebut layaknya objek OOP. Perhatikan fungsi ``PerbaruiPosisi`` yang menggunakan *Pointer Receiver* (``k *Karyawan``); jika kita tidak menggunakan pointer, perubahan nama jabatan hanya akan terjadi pada salinan struct lokal di dalam cakupan method tersebut, sementara objek asli di fungsi ``main`` tidak akan pernah berubah nilainya.

---

4. Rekayasa Perangkat Lunak di Go (Object-Oriented ala Go)
==========================================================

Encapsulation & Abstraction
---------------------------
Go menerapkan konsep *Encapsulation* (pembungkusan data) bukan dengan kata kunci ``private`` atau ``public``, melainkan melalui aturan kapitalisasi nama komponen (variabel, fungsi, struct, field, method):

* **Exported (Public):** Jika nama komponen diawali dengan **Huruf Kapital** (A-Z), komponen tersebut dapat diakses dan digunakan oleh package lain yang mengimpor package tempat komponen itu berada.
* **Unexported (Private):** Jika nama komponen diawali dengan **Huruf Kecil** (a-z), komponen tersebut terkunci secara lokal dan hanya bisa diakses dari dalam package yang sama.

Interfaces
----------
*Interface* di Go adalah tipe data abstrak yang mendefinisikan kumpulan dari satu atau beberapa spesifikasi tanda tangan method (*method signatures*). Keunggulan utama Go adalah penerapan sistem **Implicit Implementation**. Sebuah struct tidak perlu menuliskan kata kunci seperti ``implements`` secara eksplisit; selama struct tersebut memiliki semua method yang dituntut oleh suatu interface, Go secara otomatis menganggap struct tersebut telah memenuhi kualifikasi interface terkait.

.. code-block:: go

    package main

    import "fmt"

    // Definisi interface
    type Pembayaran interface {
        ProsesTransaksi(jumlah float64) bool
    }

    // Struct 1: Dompet Digital
    type OVO struct {
        NomorHP string
    }

    // Mengimplementasikan interface Pembayaran secara implisit
    func (o OVO) ProsesTransaksi(jumlah float64) bool {
        fmt.Printf("Memproses pembayaran via OVO sebesar Rp%.2f ke %s\n", jumlah, o.NomorHP)
        return true
    }

    // Struct 2: Transfer Bank
    type BankTransfer struct {
        NomorRekening string
    }

    // Mengimplementasikan interface Pembayaran secara implisit
    func (b BankTransfer) ProsesTransaksi(jumlah float64) bool {
        fmt.Printf("Memproses transfer bank ke rekening %s senilai Rp%.2f\n", b.NomorRekening, jumlah)
        return true
    }

    // Fungsi universal yang menerima kontrak Interface (Polimorfisme)
    func JalankanCheckout(p Pembayaran, total Harga float64) {
        sukses := p.ProsesTransaksi(totalHarga)
        if sukses {
            fmt.Println("Sistem: Transaksi Berhasil Diselesaikan!")
        } else {
            fmt.Println("Sistem: Transaksi Gagal!")
        }
    }

    func main() {
        metodeOvo := OVO{NomorHP: "081999888"}
        metodeBank := BankTransfer{NomorRekening: "123-456-789"}

        // Polimorfisme: Fungsi yang sama mampu menangani dua objek berbeda bentuk
        JalankanCheckout(metodeOvo, 150000)
        fmt.Println("------------------------------------------------")
        JalankanCheckout(metodeBank, 250000)
    }

**Penjelasan Alur Kode:**
Kita merancang sebuah kontrak sistem bernama interface ``Pembayaran`` yang mengharuskan adanya method ``ProsesTransaksi(amount float64) bool``. Dua struct terpisah, yaitu ``OVO`` dan ``BankTransfer``, mendefinisikan fungsi dengan nama dan tanda tangan yang identik. Hasilnya, fungsi ``JalankanCheckout`` dapat berdiri sendiri secara abstrak; fungsi ini tidak peduli apakah pembayaran menggunakan dompet digital atau bank transfer, selama parameter objek yang dikirim mematuhi kontrak interface ``Pembayaran``.

Empty Interface (`any`) & Type Assertion
----------------------------------------
Sejak Go 1.18, kata kunci ``interface{}`` mendapatkan alias berupa kata kunci ``any``. Interface kosong tidak memiliki spesifikasi method apa pun, yang berarti **semua tipe data di Go memenuhi kualifikasi interface kosong**. Ini adalah cara Go menangani nilai dengan tipe data yang dinamis atau tidak diketahui secara pasti saat kompilasi.

Untuk mengembalikan tipe data asli dari variabel ``any``, kita harus menggunakan teknik **Type Assertion**.

.. code-block:: go

    package main

    import "fmt"

    func PeriksaData(i any) {
        // Type Assertion untuk menebak tipe asli di dalam interface kosong
        nilaiString, ok := i.(string)
        if ok {
            fmt.Printf("Data bertipe String: %s\n", nilaiString)
            return
        }

        nilaiInt, ok := i.(int)
        if ok {
            fmt.Printf("Data bertipe Integer: %d\n", nilaiInt)
            return
        }

        fmt.Println("Tipe data tidak teridentifikasi oleh sistem.")
    }

    func main() {
        PeriksaData("Halo dunia pemrograman")
        PeriksaData(2026)
        PeriksaData(3.14)
    }

**Penjelasan Alur Kode:**
Fungsi ``PeriksaData`` menerima argumen bertipe ``any``. Sintaksis ``i.(string)`` memberitahu Go untuk mencoba mengonversi isi batin interface menjadi string. Pola ini mengembalikan dua nilai: nilai asli hasil konversi dan status sukses berupa boolean (``ok``). Jika tipe data tidak cocok, variabel ``ok`` akan bernilai ``false`` tanpa memicu kegagalan sistem (*panic*), sehingga kita dapat mengalihkan alur logika penanganan tipe data lain secara aman.

---

5. Concurrency (Fitur Utama Go)
===============================

Concurrency vs Parallelism
--------------------------
Banyak developer keliru menyamakan kedua konsep ini. Rob Pike menyatakan: *"Concurrency is about dealing with lots of things at once. Parallelism is about doing lots of things at once."*

* **Concurrency (Konkurensi):** Komposisi atau struktur dari program yang dieksekusi secara independen. Program aplikasi dirancang agar pekerjaan bisa dipecah menjadi bagian-bagian kecil yang dapat dijalankan secara bergantian (interleaving) oleh manajemen penjadwalan (*scheduler*).
* **Parallelism (Paralelisme):** Eksekusi fisik dari beberapa tugas secara bersamaan pada waktu yang persis sama di atas perangkat keras komputer dengan CPU *multi-core*.

Goroutines
----------
Goroutine adalah *thread* tingkat aplikasi (bukan thread sistem operasi) yang dikelola sepenuhnya oleh runtime Go. 

Perbandingan alokasi memori secara mendalam:

* **OS Thread:** Dialokasikan di tingkat kernel sistem operasi, membutuhkan memori awal yang besar (biasanya sekitar **1 MB - 8 MB**) untuk tumpukan eksekusi (*stack*), serta membutuhkan proses *context switching* yang mahal karena melibatkan interupsi hardware.
* **Goroutine:** Memiliki alokasi memori awal yang sangat kecil, hanya sekitar **2 KB**. Ukuran stack ini bersifat dinamis (bisa bertambah atau berkurang sesuai kebutuhan program). Jutaan goroutine dapat berjalan secara bersamaan dalam satu aplikasi tanpa membuat sistem kehabisan memori.

Untuk memicu sebuah fungsi berjalan sebagai goroutine baru yang asinkron, Anda cukup menambahkan kata kunci ``go`` di depan pemanggilan fungsi tersebut.

Channels
--------
Channels adalah saluran atau pipa yang berfungsi sebagai media komunikasi sekaligus sinkronisasi antar goroutine. Melalui channel, goroutine dapat mengirim dan menerima data secara aman, menghindari korupsi data akibat perebutan memori (*shared memory*).

* **Unbuffered Channel:** Jenis channel default tanpa kapasitas penyimpanan. Proses pengiriman data (``ch <- data``) akan memblokir goroutine pengirim secara otomatis hingga ada goroutine lain yang siap membaca data dari channel tersebut (``<-ch``).
* **Buffered Channel:** Channel yang memiliki kapasitas tampung (diinisialisasi dengan ``make(chan TipeData, kapasitas)``). Goroutine pengirim tidak akan diblokir selama ruang penyimpanan di dalam channel masih tersedia.

.. code-block:: go

    package main

    import (
        "fmt"
        "time"
    )

    // Fungsi yang akan dijalankan di goroutine terpisah
    func AmbilDataDariAPI(channelHasil chan string) {
        time.Sleep(2 * time.Second) // Simulasi latency jaringan
        channelHasil <- "Data Pengguna Berhasil Diunduh" // Mengirim data ke channel
    }

    func main() {
        // Membuat unbuffered channel
        ch := make(chan string)

        fmt.Println("Memulai operasi asinkron...")
        go AmbilDataDariAPI(ch) // Menjalankan goroutine baru

        // Program utama diblokir di sini sampai channel menerima kiriman data
        hasil := <-ch 
        fmt.Println("Respon diterima:", hasil)
    }

**Penjelasan Alur Kode:**
Program utama (main goroutine) membuat saluran komunikasi bernama ``ch``. Ketika ``go AmbilDataDariAPI(ch)`` dipanggil, fungsi tersebut langsung berjalan di latar belakang secara asinkron. Main goroutine tidak menunggu fungsi selesai melainkan melanjutkan eksekusi ke baris ``hasil := <-ch``. Di titik ini, main goroutine dipaksa berhenti sementara (*blocking*) sampai goroutine API selesai melakukan *sleep* selama 2 detik dan menyuntikkan teks ke dalam channel ``ch``. Setelah data masuk, main goroutine terbangun kembali, mengambil data tersebut, dan menampilkannya ke layar.

Select Statement
----------------
Kata kunci ``select`` digunakan untuk memantau beberapa operasi channel sekaligus. Blok ``select`` akan memblokir eksekusi program hingga salah satu dari case channel yang dipantau siap memproses data.

.. code-block:: go

    package main

    import (
        "fmt"
        "time"
    )

    func main() {
        ch1 := make(chan string)
        ch2 := make(chan string)

        go func() {
            time.Sleep(1 * time.Second)
            ch1 <- "Pesan dari Layanan A"
        }()

        go func() {
            time.Sleep(2 * time.Second)
            ch2 <- "Pesan dari Layanan B"
        }()

        // Memantau channel mana yang merespon paling cepat
        for i := 0; i < 2; i++ {
            select {
            case msg1 := <-ch1:
                fmt.Println("Diterima:", msg1)
            case msg2 := <-ch2:
                fmt.Println("Diterima:", msg2)
            case <-time.After(3 * time.Second): // Timeout guard
                fmt.Println("Error: Respon layanan timeout!")
            }
        }
    }

**Penjelasan Alur Kode:**
Kita memicu dua fungsi anonim (*anonymous goroutine*) yang mengirimkan pesan dengan durasi jeda waktu yang berbeda. Di dalam perulangan loop, perintah ``select`` bertindak sebagai pengatur lalu lintas data. Sesi pertama perulangan akan langsung memicu eksekusi ``case msg1 := <-ch1`` karena durasi tunggunya hanya 1 detik (lebih cepat dari ch2). Sesi kedua perulangan kemudian menangkap data dari ``ch2``. Kita juga menyertakan fungsi ``time.After`` sebagai pengaman sistem (*timeout protection*); jika semua channel tidak memberikan respon melebihi batas 3 detik, program akan membatalkan proses agar tidak terjadi *deadlock* permanen.

Sinkronisasi: WaitGroup & Mutex
-------------------------------
Jika komunikasi antar goroutine membutuhkan koordinasi tanpa pengiriman data spesifik, atau perlu mengamankan variabel yang diakses bersama, Go menyediakan package bawaan ``sync``.

* **sync.WaitGroup:** Penghitung (*counter*) terpusat untuk memantau dan menunggu hingga seluruh goroutine selesai mengeksekusi tugasnya sebelum program utama dimatikan.
* **sync.Mutex (Mutual Exclusion):** Gembok pengunci memori untuk memastikan hanya ada **satu goroutine** yang diizinkan membaca atau memodifikasi variabel global pada satu waktu, mencegah terjadinya fenomena rusaknya nilai data akibat persaingan akses (*Race Condition*).

.. code-block:: go

    package main

    import (
        "fmt"
        "sync"
    )

    var (
        counter int
        wg      sync.WaitGroup
        mu      sync.Mutex // Gembok pelindung variabel counter
    )

    func NaikkanCounter(id int) {
        defer wg.Done() // Menurunkan hitungan WaitGroup jika fungsi selesai

        mu.Lock() // Mengunci akses memori sebelum melakukan perubahan
        counter++
        // Aman dari race condition karena goroutine lain terpaksa mengantre
        mu.Unlock() // Membuka kembali gembok setelah manipulasi data selesai
    }

    func main() {
        jumlahGoroutine := 1000

        // Menentukan jumlah goroutine yang harus ditunggu
        wg.Add(jumlahGoroutine)

        for i := 0; i < jumlahGoroutine; i++ {
            go NaikkanCounter(i)
        }

        wg.Wait() // Menahan main program sampai counter WaitGroup kembali ke angka 0
        fmt.Println("Nilai akhir Counter yang aman:", counter)
    }

**Penjelasan Alur Kode:**
Kita membuat 1000 goroutine yang secara simultan bertugas menaikkan nilai variabel global ``counter``. Tanpa adanya ``sync.Mutex``, operasi ``counter++`` (yang di tingkat mesin terdiri dari proses pembacaan, inkrementasi, dan penulisan kembali) akan saling tumpang tindih antar core CPU, berujung pada nilai akhir yang salah atau acak. Dengan menyematkan ``mu.Lock()`` dan ``mu.Unlock()``, kita mengisolasi baris kritikal tersebut. Selain itu, fungsi ``wg.Wait()`` menjamin program tidak akan keluar (*exit*) prematur sebelum seribu operasi goroutine tersebut tuntas dilaporkan melalui perintah ``wg.Done()``.

---

6. Penanganan Error & Ekosistem Modern
=======================================

Filosofi Error Handling: Error as a Value
-----------------------------------------
Go sengaja tidak mengadopsi mekanisme penanganan error berbasis blok ``try-catch``. Bagi perancang Go, kegagalan operasi (*error*) bukan merupakan kejadian luar biasa (*exception*), melainkan bagian dari aliran logika program yang normal. Oleh sebab itu, di Go, **error diperlakukan sebagai nilai kembalian biasa (value)** yang diimplementasikan melalui tipe interface bawaan:

.. code-block:: go

    type error interface {
        Error() string
    }

.. code-block:: go

    package main

    import (
        "errors"
        "fmt"
    )

    // Fungsi mengembalikan dua nilai: hasil kalkulasi dan objek error
    func Pembagian(a, b float64) (float64, error) {
        if b == 0 {
            return 0, errors.New("kesalahan matematika: tidak bisa membagi angka dengan nol")
        }
        return a / b, nil // nil menandakan tidak terjadi error
    }

    func main() {
        hasil, err := Pembagian(10, 0)
        
        // Pola penanganan error standar di Go
        if err != nil {
            fmt.Println("Terjadi Error ->", err)
            return
        }

        fmt.Println("Hasil Pembagian:", hasil)
    }

**Penjelasan Alur Kode:**
Fungsi ``Pembagian`` memeriksa kondisi pembagi. Jika mendeteksi angka nol, fungsi tersebut mengembalikan nilai default ``0`` disertai objek error yang dirakit lewat fungsi ``errors.New()``. Di sisi pemanggil (fungsi ``main``), kita menangkap kedua nilai tersebut secara berurutan dan langsung menguji kondisi menggunakan ekspresi logika ``if err != nil``. Jika variabel ``err`` berisi objek (tidak kosong/nil), kita langsung menangani error tersebut secepatnya (*fail-fast principle*), menghindari kelanjutan proses kompilasi logika di bawahnya yang berpotensi rusak.

Defer, Panic, dan Recover
-------------------------
Meskipun Go merekomendasikan *error as a value*, terdapat situasi darurat di mana aplikasi mengalami kegagalan fatal yang tidak dapat dipulihkan. Untuk kasus ini, Go menyediakan trio mekanisme: ``defer``, ``panic``, dan ``recover``.

* **defer:** Instruksi untuk menunda eksekusi suatu fungsi hingga fungsi utama yang membungkusnya selesai dieksekusi (sangat berguna untuk aksi pembersihan sumber daya seperti menutup koneksi database atau menutup file). Fungsi berbasis ``defer`` diletakkan ke dalam tumpukan struktur data LIFO (*Last In, First Out*).
* **panic:** Menghentikan aliran eksekusi program normal secara paksa apabila sistem menemui error fatal yang tidak bisa ditoleransi (misalnya: gagal membaca file konfigurasi utama saat booting).
* **recover:** Fungsi bawaan yang digunakan untuk menangkap kembali kendali program yang sedang mengalami kondisi ``panic``, mencegah aplikasi mati total (*crash*) di server produksi.

.. code-block:: go

    package main

    import "fmt"

    func JalankanProteksiSistem() {
        // recover HARUS diletakkan di dalam fungsi deferred
        if r := recover(); r != nil {
            fmt.Println("Sistem Berhasil Pulih dari Panic:", r)
        }
    }

    func AksesServer() {
        defer JalankanProteksiSistem() // Daftarkan fungsi penyelamat
        
        fmt.Println("Mencoba menghubungkan ke server inti...")
        // Memicu kondisi panic buatan
        panic("Koneksi database pusat terputus secara tidak terduga!")
        
        fmt.Println("Baris ini tidak akan pernah dieksekusi.")
    }

    func main() {
        AksesServer()
        fmt.Println("Aplikasi utama tetap hidup dan berjalan normal.")
    }

**Penjelasan Alur Kode:**
Ketika fungsi ``AksesServer`` mengeksekusi perintah ``panic``, alur program normal langsung berhenti seketika. Namun, sebelum fungsi benar-benar keluar dan mematikan seluruh aplikasi, runtime Go mendatangi tumpukan fungsi yang dideklarasikan dengan kata kunci ``defer``. Fungsi ``JalankanProteksiSistem`` dipanggil, di dalamnya fungsi ``recover()`` mendeteksi adanya status panic, mengamankan pesan kesalahannya, dan menetralkan status kegagalan tersebut. Hasilnya, kendali eksekusi dikembalikan ke fungsi ``main`` sehingga baris paling akhir aplikasi tetap dapat berjalan dengan mulus.

Bekerja dengan Web API (net/http)
---------------------------------
Go memiliki package standard library ``net/http`` yang sangat tangguh untuk membangun layanan Web API tingkat produksi (*production-ready*) tanpa memerlukan bantuan framework pihak ketiga (seperti Express atau Gin) untuk kebutuhan dasar.

.. code-block:: go

    package main

    import (
        "encoding/json"
        "fmt"
        "net/http"
    )

    type ResponProduk struct {
        ID    int    `json:"id"`
        Nama  string `json:"nama_produk"`
        Harga int    `json:"harga"`
    }

    func HandlerProduk(w http.ResponseWriter, r *http.Request) {
        // Mengatur header agar merespon dalam format JSON
        w.Header().Set("Content-Type", "application/json")

        if r.Method != http.MethodGet {
            w.WriteHeader(http.StatusMethodNotAllowed)
            w.Write([]byte(`{"error": "Metode HTTP tidak diizinkan"}`))
            return
        }

        data := ResponProduk{
            ID:    1,
            Nama:  "Carrier Hiking 60L Pro",
            Harga: 1250000,
        }

        // Serialisasi struct Go menjadi teks JSON, lalu kirim ke client
        w.WriteHeader(http.StatusOK)
        json.NewEncoder(w).Encode(data)
    }

    func main() {
        // Mendaftarkan rute endpoint URL beserta fungsi handler-nya
        http.HandleFunc("/api/produk", HandlerProduk)

        fmt.Println("Server REST API berjalan dengan aman di http://localhost:8080")
        // Menyalakan server HTTP pada port 8080
        err := http.ListenAndServe(":8080", nil)
        if err != nil {
            panic("Gagal menyalakan server: " + err.Error())
        }
    }

**Penjelasan Alur Kode:**
Kita memetakan struct ``ResponProduk`` dengan dekorator penanda metadata tag JSON (``json:"nama_produk"``) untuk mengontrol nama properti keluaran. Fungsi ``HandlerProduk`` bertindak sebagai pengontrol request-response. Kita melakukan validasi metode HTTP untuk memastikan hanya request ``GET`` yang dilayani. Fungsi ``json.NewEncoder(w).Encode(data)`` secara efisien membaca objek data memori internal Go, menerjemahkannya ke format payload JSON standard, dan mengalirkannya langsung (*streaming*) melalui jaringan komputer ke browser atau aplikasi klien yang melakukan request. Server dinyalakan menggunakan fungsi ``http.ListenAndServe``.

Unit Testing Dasar
------------------
Go menyertakan perkakas pengujian (*testing tool*) bawaan yang sangat terintegrasi. Untuk menulis test di Go, ikuti dua aturan mutlak berikut:

1. Nama file pengujian wajib diakhiri dengan sufiks ``_test.go`` (contoh: ``kalkulator_test.go``).
2. Nama fungsi pengujian wajib diawali dengan kata kata ``Test`` dan menerima parameter pointer ``t *testing.T`` (contoh: ``func TestHitungLuas(t *testing.T)``).

Misalkan kita memiliki kode logika bisnis di file ``kalkulator.go``:

.. code-block:: go

    package kalkulator

    func Tambah(a, b int) int {
        return a + b
    }

Berikut adalah file unit testing pendampingnya bernama ``kalkulator_test.go``:

.. code-block:: go

    package kalkulator

    import "testing"

    func TestTambah(t *testing.T) {
        ekspektasi := 15
        hasilRiil := Tambah(10, 5)

        if hasilRiil != ekspektasi {
            t.Errorf("Pengujian Gagal! Ekspektasi: %d, tetapi Hasil Riil yang didapat: %d", ekspektasi, hasilRiil)
        }
    }

Untuk mengeksekusi seluruh rangkaian skenario unit testing di dalam proyek Anda, jalankan perintah resmi berikut pada terminal:

.. code-block:: bash

    go test -v

Bendera parameter ``-v`` (*verbose*) akan menampilkan rincian nama fungsi yang diuji beserta status kelulusannya secara detail.

---

.. note::
   Selamat! Anda telah menyelesaikan seluruh materi modul pembelajaran komprehensif bahasa pemrograman Go. Praktikkan konsep-konsep di atas secara konsisten untuk membangun sistem backend yang efisien, kokoh, dan berskala tinggi.
