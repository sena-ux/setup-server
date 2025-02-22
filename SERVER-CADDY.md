# SERVER PHP CADDY
Server ini akan di bangun dengan menggunakan web server caddy dan php 8.2 pada linux debian 10

## Langkah-langkah
1. Update dan Upgrade
```bash
apt update && apt upgrade -y
```

2. Install Paket dasar
```
apt install -y zip curl unzip git
```

3. Add Repository PHP-FPM
```
apt install software-properties-common

add-apt-repository ppa:ondrej/php -y

apt update

apt install -y php8.2 php8.2-cli php8.2-common php8.2-mbstring php8.2-xml php8.2-bcmath php8.2-curl php8.2-zip php8.2-mysql php8.2-pgsql php8.2-fpm

php -v
```

Jika ada error saat menambahkan repository lakukan beberapa penanganan berikut :
```
rm -f /etc/apt/sources.list.d/ondrej-php*
rm -f /etc/apt/sources.list.d/ondrej-ubuntu-php-plucky.list*
rm -rf /etc/apt/keyrings
grep -r "ppa.launchpad.net" /etc/apt/ => pastikan tidak ada repo dari ubuntu
apt update
```


4. Install Composer
```
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer
composer -v
```

5. Install MYSQL-Server
```
apt install -y mysql-server
mysql_secure_installation
mysql -u root -p
```

6. Install PostgreSQL
```
apt install -y postgresql postgresql-contrib
-u postgres psql
```

Perintah untuk membuat user :
```
CREATE DATABASE laravel_pg;
CREATE USER laravel_user WITH PASSWORD 'password123';
ALTER ROLE laravel_user SET client_encoding TO 'utf8';
ALTER ROLE laravel_user SET default_transaction_isolation TO 'read committed';
ALTER ROLE laravel_user SET timezone TO 'UTC';
GRANT ALL PRIVILEGES ON DATABASE laravel_pg TO laravel_user;

\q
```
