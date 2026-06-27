===================================================
Modul Pemrograman C++ Modern & Arsitektur Sistem
===================================================

BAB 1: Fondasi Dasar & Sintaksis C++ Modern
===========================================

Keunggulan C++ Modern
---------------------
* **Low-latency**: Eksekusi deterministik tanpa Garbage Collector.
* **Zero-cost abstraction**: Abstraksi tingkat tinggi (e.g., templates, lambdas) dikompilasi tanpa overhead performa runtime.
* **Direct Hardware Access**: Kontrol penuh atas memori dan interaksi hardware.

Alur Kompilasi C++
------------------
* **Preprocessor**: Memproses direktif seperti `#include` dan `#define`. Menghasilkan file `.i`.
* **Compiler**: Mengubah kode sumber menjadi kode assembly. Menghasilkan file `.s`.
* **Assembler**: Mengubah kode assembly menjadi mesin/objek biner. Menghasilkan file `.o` atau `.obj`.
* **Linker**: Menggabungkan file objek dengan library luar menjadi executable tunggal.

Tipe Data, Variabel, dan Konstanta
----------------------------------
* Tipe data primitif: `int`, `float`, `double`, `char`, `bool`, `void`.
* `const`: Variabel imutabel yang dievaluasi pada runtime.
* `constexpr`: Konstanta yang dievaluasi secara opsional atau wajib pada saat kompilasi (compile-time).

.. code-block:: cpp

    #include <iostream>
    #include <string>

    int main() {
        int umur = 25;
        double gaji = 15000000.50;
        char inisial = 'A';
        bool isActive = true;

        const int runtime_limit = umur * 2;
        constexpr int compile_limit = 100 * 5;

        std::cout << "Umur: " << umur << ", Limit: " << compile_limit << "\\n";
        return 0;
    }

Control Flow Modern
-------------------
* Menggunakan C++17/C++20 structured binding dalam kondisi `if`.
* Optimalisasi percabangan dan perulangan modern.

.. code-block:: cpp

    #include <iostream>
    #include <map>
    #include <string>

    int main() {
        std::map<std::string, int> skor = {{"Andi", 90}, {"Budi", 85}};

        // If dengan inisialisasi / structured binding (C++17)
        if (auto [it, inserted] = skor.insert({"Cici", 95}); inserted) {
            std::cout << "Berhasil menambahkan " << it->first << " dengan skor " << it->second << "\\n";
        }

        // Switch case standar
        int opsi = 2;
        switch (opsi) {
            case 1: std::cout << "Opsi 1\\n"; break;
            case 2: std::cout << "Opsi 2\\n"; break;
            default: std::cout << "Opsi tidak valid\\n"; break;
        }

        // Range-based for loop dengan structured binding (C++20)
        for (const auto& [nama, nilai] : skor) {
            std::cout << nama << " mendapatkan nilai " << nilai << "\\n";
        }

        return 0;
    }


BAB 2: Manajemen Memori & Smart Pointers
========================================

Stack vs Heap Memori
--------------------
* **Stack**: Alokasi cepat, otomatis dikelola oleh scope, ukuran terbatas (fixed size).
* **Heap**: Alokasi dinamis via `new`/`malloc`, ukuran fleksibel, harus dikelola manual jika tanpa smart pointers.
* **Memory Leak**: Kegagalan membebaskan memori heap (`delete`), menyebabkan konsumsi RAM terus membengkak.

Konsep RAII (Resource Acquisition Is Initialization)
-----------------------------------------------------
* Manajemen resource terikat pada siklus hidup (lifecycle) object.
* Resource dialokasikan di constructor dan dilepaskan secara otomatis di destructor.

Smart Pointers Modern
---------------------
* `std::unique_ptr`: Kepemilikan tunggal (exclusive ownership), tidak bisa disalin, hanya bisa dipindahkan (`std::move`).
* `std::shared_ptr`: Kepemilikan bersama (shared ownership), menghitung referensi objek (reference counting).
* `std::weak_ptr`: Referensi non-owning untuk menghindari siklus referensi melingkar (circular dependency).

.. code-block:: cpp

    #include <iostream>
    #include <memory>

    class Resource {
    public:
        Resource() { std::cout << "Resource Dialokasikan\\n"; }
        ~Resource() { std::cout << "Resource Dilepaskan\\n"; }
        void doSomething() { std::cout << "Resource Bekerja\\n"; }
    };

    struct Node {
        std::shared_ptr<Node> next;
        std::weak_ptr<Node> prev; // Mencegah circular reference
        ~Node() { std::cout << "Node Dihancurkan\\n"; }
    };

    int main() {
        // 1. std::unique_ptr
        std::unique_ptr<Resource> res1 = std::make_unique<Resource>();
        res1->doSomething();
        // std::unique_ptr<Resource> res2 = res1; // Error: Tidak bisa di-copy
        std::unique_ptr<Resource> res2 = std::move(res1); // Dipindahkan

        // 2. std::shared_ptr
        std::shared_ptr<Resource> shared1 = std::make_shared<Resource>();
        {
            std::shared_ptr<Resource> shared2 = shared1;
            std::cout << "Reference Count: " << shared1.use_count() << "\\n"; // Output: 2
        }
        std::cout << "Reference Count: " << shared1.use_count() << "\\n"; // Output: 1

        // 3. std::weak_ptr
        auto node1 = std::make_shared<Node>();
        auto node2 = std::make_shared<Node>();
        node1->next = node2;
        node2->prev = node1; // Menggunakan weak_ptr

        return 0;
    }


BAB 3: OOP Lanjutan & Runtime Polymorphism
==========================================

Encapsulation & Rule of Five
----------------------------
* **Encapsulation**: Menyembunyikan status internal objek menggunakan `private` atau `protected`.
* **Rule of Five**: Jika kelas mendefinisikan salah satu dari destructor, copy constructor, copy assignment, move constructor, atau move assignment, maka kelimanya harus didefinisikan secara eksplisit.

.. code-block:: cpp

    #include <iostream>
    #include <utility>

    class Buffer {
    private:
        int* data;
        size_t size;
    public:
        Buffer(size_t s) : size(s), data(new int[s]) {}
        
        // Destructor
        ~Buffer() { delete[] data; }

        // Copy Constructor
        Buffer(const Buffer& other) : size(other.size), data(new int[other.size]) {
            for(size_t i = 0; i < size; ++i) data[i] = other.data[i];
        }

        // Copy Assignment Operator
        Buffer& operator=(const Buffer& other) {
            if (this == &other) return *this;
            delete[] data;
            size = other.size;
            data = new int[other.size];
            for(size_t i = 0; i < size; ++i) data[i] = other.data[i];
            return *this;
        }

        // Move Constructor
        Buffer(Buffer&& other) noexcept : data(other.data), size(other.size) {
            other.data = nullptr;
            other.size = 0;
        }

        // Move Assignment Operator
        Buffer& operator=(Buffer&& other) noexcept {
            if (this == &other) return *this;
            delete[] data;
            data = other.data;
            size = other.size;
            other.data = nullptr;
            other.size = 0;
            return *this;
        }
    };

Multiple Inheritance & Diamond Problem
--------------------------------------
* Diamond Problem terjadi ketika sebuah sub-class mewarisi dua class yang memiliki parent class yang sama.
* Solusi: Menggunakan pewarisan virtual (`virtual inheritance`).

Cara Kerja VTable & VPtr
------------------------
* **VTable (Virtual Table)**: Array statis berisi fungsi pointer yang dibuat per class yang memiliki fungsi virtual.
* **VPtr (Virtual Pointer)**: Pointer tersembunyi di dalam instance objek yang menunjuk ke VTable kelasnya untuk resolusi fungsi pada saat runtime.

.. code-block:: cpp

    #include <iostream>

    class Base {
    public:
        virtual void interface() = 0; // Pure virtual function
        virtual ~Base() = default;
    };

    class ParentA : virtual public Base {
    public:
        void interface() override { std::cout << "Respons dari A\\n"; }
    };

    class ParentB : virtual public Base {
    public:
        void interface() override { std::cout << "Respons dari B\\n"; }
    };

    // Menyelesaikan Diamond Problem dengan Virtual Inheritance
    class Child : public ParentA, public ParentB {
    public:
        void interface() override {
            ParentA::interface(); // Memilih implementasi secara spesifik
        }
    };

    int main() {
        Base* poly = new Child();
        poly->interface(); // Runtime polymorphism melalui VTable
        delete poly;
        return 0;
    }


BAB 4: Standard Template Library (STL) & Multi-threading
========================================================

STL Containers Karakteristik
----------------------------
* `std::vector`: Array dinamis berkelanjutan di memori. Akses indeks acak `O(1)`, penyisipan di akhir `Amortized O(1)`.
* `std::unordered_map`: Hash table. Pencarian elemen rata-rata `O(1)`, kasus terburuk `O(n)`. Tidak terurut.
* `std::map`: Self-balancing Red-Black Tree. Pencarian elemen `O(log n)`. Elemen otomatis terurut berdasarkan key.

.. code-block:: cpp

    #include <iostream>
    #include <vector>
    #include <unordered_map>
    #include <map>

    int main() {
        std::vector<int> vec = {1, 2, 3};
        vec.push_back(4);

        std::unordered_map<int, std::string> u_map;
        u_map[1] = "C++";

        std::map<int, std::string> o_map;
        o_map[2] = "Java";
        o_map[1] = "Python"; // Otomatis disortir berdasarkan key

        return 0;
    }

Konkurensi Modern (C++20)
-------------------------
* `std::jthread`: Thread yang otomatis melakukan `.join()` saat keluar dari scope (RAII-compliant).
* `std::mutex`: Sinkronisasi untuk mengamankan data bersama dari kondisi Race Condition.
* `std::lock_guard`: Lock berbasis RAII untuk mengunci mutex secara aman dan melepaskannya otomatis.

.. code-block:: cpp

    #include <iostream>
    #include <thread>
    #include <mutex>
    #include <vector>

    std::mutex mtx;
    int counter = 0;

    void increment(int id) {
        for (int i = 0; i < 1000; ++i) {
            std::lock_guard<std::mutex> lock(mtx); // Mengunci aman
            counter++;
        }
    }

    int main() {
        std::vector<std::jthread> workers;
        for (int i = 0; i < 5; ++i) {
            workers.emplace_back(increment, i); // jthread otomatis join()
        }
        
        // Menunggu seluruh thread selesai secara otomatis lewat destructor jthread
        workers.clear(); 
        
        std::cout << "Total Counter Akhir: " << counter << "\\n"; // Output presisi: 5000
        return 0;
    }


BAB 5: Integrasi Database (SQLite C++ Driver)
=============================================

Koneksi & Operasi CRUD dengan SQLite3
-------------------------------------
* Library: `<sqlite3.h>`.
* Menggunakan Prepared Statements untuk mencegah SQL Injection.

.. code-block:: cpp

    #include <iostream>
    #include <sqlite3.h>

    int main() {
        sqlite3* db;
        char* errMsg = nullptr;

        // 1. Membuka Koneksi Database
        if (sqlite3_open("system_api.db", &db) != SQLITE_OK) {
            std::cerr << "Gagal membuka database: " << sqlite3_errmsg(db) << "\\n";
            return 1;
        }

        // 2. Membuat Tabel
        const char* createTableSql = "CREATE TABLE IF NOT EXISTS USERS("
                                     "ID INTEGER PRIMARY KEY AUTOINCREMENT,"
                                     "NAME TEXT NOT NULL,"
                                     "EMAIL TEXT NOT NULL);";
        
        if (sqlite3_exec(db, createTableSql, nullptr, nullptr, &errMsg) != SQLITE_OK) {
            std::cerr << "Gagal membuat tabel: " << errMsg << "\\n";
            sqlite3_free(errMsg);
        }

        // 3. Eksekusi Query INSERT dengan Prepared Statement
        const char* insertSql = "INSERT INTO USERS (NAME, EMAIL) VALUES (?, ?);";
        sqlite3_stmt* stmt;

        if (sqlite3_prepare_v2(db, insertSql, -1, &stmt, nullptr) == SQLITE_OK) {
            sqlite3_bind_text(stmt, 1, "Rian Ardiansyah", -1, SQLITE_STATIC);
            sqlite3_bind_text(stmt, 2, "rian@example.com", -1, SQLITE_STATIC);
            
            if (sqlite3_step(stmt) != SQLITE_DONE) {
                std::cerr << "Gagal eksekusi insert\\n";
            }
            sqlite3_finalize(stmt);
        }

        // 4. Eksekusi Query SELECT dan Mengambil Data
        const char* selectSql = "SELECT ID, NAME, EMAIL FROM USERS;";
        if (sqlite3_prepare_v2(db, selectSql, -1, &stmt, nullptr) == SQLITE_OK) {
            while (sqlite3_step(stmt) == SQLITE_ROW) {
                int id = sqlite3_column_int(stmt, 0);
                const unsigned char* name = sqlite3_column_text(stmt, 1);
                const unsigned char* email = sqlite3_column_text(stmt, 2);
                std::cout << "ID: " << id << " | Nama: " << name << " | Email: " << email << "\\n";
            }
            sqlite3_finalize(stmt);
        }

        // 5. Menutup Database
        sqlite3_close(db);
        return 0;
    }


BAB 6: High-Performance Web API dengan C++ (Crow Framework)
===========================================================

Pengenalan Crow Framework
-------------------------
* Crow adalah framework web mikro modern untuk C++ yang sangat cepat, mirip Flask/Express, mendukung routing statis/dinamis dan JSON secara native.

Konfigurasi Proyek CMakeLists.txt
---------------------------------
.. code-block:: cmake

    cmake_minimum_required(VERSION 3.20)
    project(CppWebAPI LANGUAGES CXX)

    set(CMAKE_CXX_STANDARD 20)
    set(CMAKE_CXX_STANDARD_REQUIRED ON)

    # Menghubungkan library eksternal Crow dan SQLite3
    find_package(Threads REQUIRED)

    add_executable(CppWebAPI main.cpp)
    target_link_libraries(CppWebAPI PRIVATE Threads::Threads sqlite3)

Implementasi HTTP REST API Server
---------------------------------
* Endpoint GET: Mengembalikan data format JSON terstruktur.
* Endpoint POST: Membaca, parsing request body JSON, dan mengembalikan response.

.. code-block:: cpp

    #include "crow.h"
    #include <string>

    int main() {
        crow::SimpleApp app;

        // 1. GET Endpoint - Mengembalikan data JSON sederhana
        CROW_ROUTE(app, "/api/v1/status")
        ([](){
            crow::json::wvalue response;
            response["status"] = "Running";
            response["version"] = "1.0.0";
            response["engine"] = "C++20 Crow Framework";
            return response;
        });

        // 2. POST Endpoint - Membaca, parsing body JSON, dan mengembalikan response
        CROW_ROUTE(app, "/api/v1/user").methods(crow::HTTPMethod::POST)
        ([](const crow::request& req){
            auto body_json = crow::json::load(req.body);
            if (!body_json) {
                return crow::response(400, "Format JSON tidak valid");
            }

            // Validasi field kunci JSON
            if (!body_json.has("name") || !body_json.has("email")) {
                return crow::response(400, "Missing required fields: 'name' or 'email'");
            }

            std::string nama = body_json["name"].s();
            std::string email = body_json["email"].s();

            // Simulasi struktur response sukses setelah proses data
            crow::json::wvalue success_res;
            success_res["message"] = "Data pengguna berhasil diproses";
            success_res["data"]["name"] = nama;
            success_res["data"]["email"] = email;
            success_res["persisted"] = true;

            return crow::response(201, success_res);
        });

        // Menentukan port aplikasi berjalan pada port 8080 dengan multi-threading default
        app.port(8080).multithreaded().run();
        return 0;
    }
