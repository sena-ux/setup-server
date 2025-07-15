#!/bin/bash

# Stop on error
set -e

PHP_VERSION=8.3

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

# Install Composer
echo "📦 Menginstal Composer..."
EXPECTED_SIGNATURE="$(curl -s https://composer.github.io/installer.sig)"
php$PHP_VERSION -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
ACTUAL_SIGNATURE="$(php$PHP_VERSION -r "echo hash_file('sha384', 'composer-setup.php');")"

if [ "$EXPECTED_SIGNATURE" != "$ACTUAL_SIGNATURE" ]; then
    >&2 echo "❌ ERROR: Invalid installer signature"
    rm composer-setup.php
    exit 1
fi

php$PHP_VERSION composer-setup.php --install-dir=/usr/local/bin --filename=composer
rm composer-setup.php

# Verifikasi
echo "🎉 Composer versi $(composer --version) berhasil terinstal!"

echo "✅ Server siap! PHP $PHP_VERSION terpasang. Laravel dapat diletakkan di $PROJECT_DIR"
