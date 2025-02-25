Untuk melihat detail hardware yang digunakan dalam PC dengan Linux Ubuntu, kamu bisa menggunakan beberapa perintah berikut:

1. Melihat Informasi CPU
bash
Copy
Edit
lscpu
Menampilkan detail prosesor seperti model, arsitektur, jumlah core, thread, dan cache.

2. Melihat Informasi RAM
bash
Copy
Edit
free -h
Menampilkan kapasitas RAM yang terpasang dan penggunaan saat ini dalam format yang mudah dibaca.

Untuk detail lebih lanjut:

bash
Copy
Edit
sudo dmidecode --type 17
Menampilkan informasi modul RAM yang lebih lengkap (jenis, kapasitas per slot, kecepatan, dll.).

3. Melihat Informasi Hard Disk / SSD
bash
Copy
Edit
lsblk
Menampilkan daftar partisi dan disk yang terpasang.

Untuk informasi lebih rinci:

bash
Copy
Edit
sudo fdisk -l
Menampilkan detail perangkat penyimpanan seperti kapasitas, partisi, dan tipe file system.

Cek merek dan model hard disk/SSD:

bash
Copy
Edit
sudo hdparm -I /dev/sda | grep "Model"
Gantilah /dev/sda sesuai dengan disk yang ingin dicek.

4. Melihat Informasi Motherboard & BIOS
bash
Copy
Edit
sudo dmidecode -t baseboard
Menampilkan informasi motherboard seperti pabrikan, model, dan versi.

Untuk informasi BIOS:

bash
Copy
Edit
sudo dmidecode -t bios
Menampilkan versi BIOS dan tanggal rilisnya.

5. Melihat Informasi VGA/GPU
Jika menggunakan kartu grafis onboard atau dedicated:

bash
Copy
Edit
lspci | grep -i vga
Menampilkan informasi kartu grafis.

Untuk lebih detail:

bash
Copy
Edit
sudo lshw -C display
Jika menggunakan NVIDIA:

bash
Copy
Edit
nvidia-smi
6. Melihat Semua Informasi Hardware Sekaligus
bash
Copy
Edit
sudo lshw
Menampilkan semua informasi hardware yang terdeteksi di sistem.

Atau jika ingin output yang lebih bersih:

bash
Copy
Edit
sudo lshw -short
7. Melihat Informasi Sensor (Suhu, Tegangan, dll.)
bash
Copy
Edit
sensors
Jika perintah tidak ditemukan, install dengan:

bash
Copy
Edit
sudo apt install lm-sensors -y
sudo sensors-detect
Itu beberapa cara melihat spesifikasi hardware di Ubuntu. Silakan dicoba!





ada beberapa software di Linux yang memiliki UI ramah seperti htop untuk melihat informasi sistem. Berikut beberapa rekomendasi:

1. bpytop (Pengganti htop dengan UI modern)
Fitur:
✅ UI lebih modern & berwarna
✅ Menampilkan CPU, RAM, disk, network, dan proses secara interaktif
✅ Mudah digunakan dengan navigasi keyboard

Install di Ubuntu:

bash
Copy
Edit
sudo apt install bpytop -y
Jalankan dengan:

bash
Copy
Edit
bpytop
2. btop++ (Versi terbaru dari bpytop, lebih ringan & cepat)
Jika ingin versi terbaru yang lebih ringan, gunakan btop++.
Install di Ubuntu:

bash
Copy
Edit
sudo apt install btop -y
Jalankan dengan:

bash
Copy
Edit
btop
3. Glances (Monitoring Sistem All-in-One)
✅ Menampilkan CPU, RAM, disk, network, dan proses
✅ Bisa diakses via terminal atau web UI

Install di Ubuntu:

bash
Copy
Edit
sudo apt install glances -y
Jalankan dengan:

bash
Copy
Edit
glances
Jika ingin menjalankan web UI, ketik:

bash
Copy
Edit
glances -w
Lalu akses di browser:

arduino
Copy
Edit
http://localhost:61208
4. gotop (UI lebih simpel & ringan untuk monitoring CPU/RAM)
Install dengan:

bash
Copy
Edit
snap install gotop
Jalankan dengan:

bash
Copy
Edit
gotop
5. nvtop (Untuk monitoring GPU NVIDIA & AMD)
✅ Alternatif htop khusus untuk GPU
✅ Menampilkan penggunaan VRAM, suhu, dan load GPU

Install di Ubuntu:

bash
Copy
Edit
sudo apt install nvtop -y
Jalankan dengan:

bash
Copy
Edit
nvtop
Semua tool ini memiliki UI yang interaktif seperti htop dan bisa digunakan langsung dari terminal!
