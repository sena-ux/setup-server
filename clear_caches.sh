#!/bin/bash

echo "⏳ Membersihkan Cache & File Sampah di Ubuntu..."

# Membersihkan Cache APT
echo "🧹 Membersihkan APT Cache..."
sudo apt-get clean
sudo apt-get autoremove -y

# Menghapus File Temporary
echo "🗑 Menghapus file temporary di /tmp dan /var/tmp..."
sudo rm -rf /tmp/*
sudo rm -rf /var/tmp/*

# Menghapus Cache Pengguna
echo "🧼 Menghapus cache user..."
rm -rf ~/.cache/*

# Membersihkan Logrotate (Jika Ada Konfigurasi)
echo "📁 Menjalankan Logrotate..."
sudo logrotate -f /etc/logrotate.conf

# Membersihkan RAM Cache
echo "💾 Menghapus RAM Cache..."
sudo sync && sudo sysctl -w vm.drop_caches=3

echo "✅ Pembersihan Selesai!"
