#!/bin/bash

# Stop on error
set -e

read -p "Masukkan versi PHP yang ingin digunakan (default: 8.3): " PHP_VERSION
PHP_VERSION=${PHP_VERSION:-8.3}

echo "🚀 Starting Setup Server..."

# Update & install dependencies
sudo apt update && sudo apt upgrade -y
sudo apt install -y software-properties-common curl unzip git
# Install PHP and extensions
echo "🔧 Installing PHP $PHP_VERSION and extensions..."
sudo apt install -y php$PHP_VERSION php$PHP_VERSION-fpm php$PHP_VERSION-cli php$PHP_VERSION-mbstring php$PHP_VERSION-xml php$PHP_VERSION-curl php$PHP_VERSION-mysql php$PHP_VERSION-pgsql php$PHP_VERSION-bcmath php$PHP_VERSION-zip php$PHP_VERSION-tokenizer php$PHP_VERSION-gd

# Install Nginx
echo "🌐 Installing Nginx..."
sudo apt install -y nginx

# Install PostgreSQL
echo "🗄️ Installing PostgreSQL..."
sudo apt install -y postgresql postgresql-contrib
