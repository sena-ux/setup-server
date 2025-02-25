Cara Membuat dan Menjalankan Script di Ubuntu
Kamu bisa membuat script ini dalam sebuah file shell script (.sh) dan menjalankannya di terminal.

1. Buat File Script
Buka terminal dan buat file script, misalnya disable_snap_services.sh:

```
nano disable_snap_services.sh
```
Lalu, masukkan skrip berikut ke dalam file:

```
#!/bin/bash
echo "Menonaktifkan semua layanan Snap yang sedang berjalan..."
```
# Hentikan semua layanan Snap yang sedang berjalan
```
for service in $(systemctl list-units --type=service --state=running | grep snap | awk '{print $1}'); do
    sudo systemctl stop $service
done
```

# Nonaktifkan semua layanan Snap agar tidak berjalan saat booting
```
for service in $(systemctl list-units --type=service --state=running | grep snap | awk '{print $1}'); do
    sudo systemctl disable $service
done
```

# Hentikan dan nonaktifkan Snap daemon utama
```
sudo systemctl stop snapd
sudo systemctl disable snapd

echo "Semua layanan Snap telah dinonaktifkan!"
```
Setelah selesai, tekan CTRL + X, lalu tekan Y, dan tekan Enter untuk menyimpan file.

2. Berikan Izin Eksekusi pada Script
Agar script bisa dijalankan, ubah permission-nya dengan perintah:

```
chmod +x disable_snap_services.sh
```
3. Jalankan Script
Sekarang, jalankan script dengan:
```
sudo ./disable_snap_services.sh
```
(Pakai sudo karena butuh hak akses root untuk menghentikan service)

4. Cek Apakah Semua Service Snap Sudah Dinonaktifkan
Setelah script dijalankan, cek ulang apakah masih ada layanan Snap yang berjalan:
```
systemctl list-units --type=service --state=running | grep snap
```
Jika tidak ada output, berarti semua service Snap sudah berhasil dinonaktifkan.

5. (Opsional) Reboot untuk Memastikan
Jika masih ada yang berjalan, coba restart server:
```
sudo reboot
```
Lalu setelah reboot, cek lagi dengan:
```
systemctl list-units --type=service --state=running | grep snap
```
