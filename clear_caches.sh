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

# Menghapus Cache Nginx
echo "🌀 Menghapus Cache Nginx..."
sudo rm -rf /var/cache/nginx/*
sudo rm -rf /var/log/nginx/*.log

# Menghapus Cache PostgreSQL (Vacuum)
echo "🐘 Membersihkan Cache PostgreSQL (VACUUM)..."
sudo -u postgres psql -c "VACUUM FULL;"
sudo -u postgres psql -c "REINDEX DATABASE postgres;"

# Menghapus Cache PHP (opcache, sessions)
echo "🐘 Menghapus Cache PHP (Opcache & Sessions)..."
sudo rm -rf /var/lib/php/sessions/*
sudo rm -rf /var/log/php*

# Menghapus Cache Systemd Journal Logs (Kalau Terlalu Besar)
echo "📝 Menghapus Journal Logs Systemd..."
sudo journalctl --vacuum-time=7d  # Menyimpan log hanya 7 hari terakhir

# Menghapus Cache Snap (Kalau Kamu Menggunakan Snap)
echo "📦 Menghapus Cache Snap..."
sudo rm -rf /var/cache/snapd/

# Menghapus Cache System
echo "🧩 Menghapus Cache System (/var/cache)..."
sudo rm -rf /var/cache/*

echo "✅ Pembersihan Selesai! Sistem telah dibersihkan dengan aman."
