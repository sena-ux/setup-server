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
