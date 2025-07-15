#!/bin/bash

# Stop on error
set -e

# Prompt: PHP Version
read -p "Masukkan versi PHP yang ingin digunakan (default: 8.3): " PHP_VERSION
PHP_VERSION=${PHP_VERSION:-8.3}

# Prompt: Laravel Project Directory
read -p "Masukkan path direktori Laravel (default: /var/www/laravel-app): " PROJECT_DIR
PROJECT_DIR=${PROJECT_DIR:-/var/www/laravel-app}

echo "🚀 Memulai Setup Server Laravel..."

# Update system dan install dependencies dasar
sudo apt update && sudo apt upgrade -y
sudo apt install -y software-properties-common curl unzip git

# Install PHP dan ekstensi Laravel
echo "🔧 Menginstal PHP $PHP_VERSION dan ekstensi Laravel..."
sudo apt install -y \
    php$PHP_VERSION \
    php$PHP_VERSION-fpm \
    php$PHP_VERSION-cli \
    php$PHP_VERSION-mbstring \
    php$PHP_VERSION-xml \
    php$PHP_VERSION-curl \
    php$PHP_VERSION-mysql \
    php$PHP_VERSION-pgsql \
    php$PHP_VERSION-bcmath \
    php$PHP_VERSION-zip \
    php$PHP_VERSION-tokenizer \
    php$PHP_VERSION-gd

# Install Nginx
echo "🌐 Menginstal Nginx..."
sudo apt install -y nginx

# Install PostgreSQL
echo "🗄️ Menginstal PostgreSQL..."
sudo apt install -y postgresql postgresql-contrib

# Siapkan direktori Laravel
echo "📁 Menyiapkan direktori Laravel di $PROJECT_DIR"
sudo mkdir -p $PROJECT_DIR
sudo chown -R $USER:www-data $PROJECT_DIR
sudo chmod -R 775 $PROJECT_DIR

echo "✅ Server siap! PHP $PHP_VERSION terpasang. Laravel dapat diletakkan di $PROJECT_DIR"
