# SERVER PHP CADDY
Server ini akan di bangun dengan menggunakan web server caddy dan php 8.2 pada linux debian 10

## Langkah-langkah
1. Update dan Upgrade
```bash
apt update && apt upgrade -y
```

2. Install Paket dasar
```
apt install -y zip curl unzip git php-cli
```

3. Add Repository PHP-FPM
```
apt install software-properties-common

add-apt-repository ppa:ondrej/php -y

apt update

apt install -y php8.2 php8.2-cli php8.2-common php8.2-mbstring php8.2-xml php8.2-bcmath php8.2-curl php8.2-zip php8.2-mysql php8.2-pgsql php8.2-fpm

apt install -y sqlite3 php8.2-sqlite3 php8.2-mbstring php8.2-xml php8.2-bcmath php8.2-curl php8.2-zip php8.2-mysql php8.2-pgsql php8.2-gd php8.2-imagick php8.2-intl php8.2-tokenizer php8.2-ctype php8.2-opcache php8.2-fileinfo

php -v

php -m | grep sqlite
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
systemctl status mysql
systemctl start mysql
```

6. Install PostgreSQL
```
apt install -y postgresql postgresql-contrib
-u postgres psql
systemctl status postgresql
systemctl start postgresql
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

Buat database :
```
-u postgres psql

CREATE USER laraveluser WITH PASSWORD 'password123';
CREATE DATABASE laraveldb OWNER laraveluser;
GRANT ALL PRIVILEGES ON DATABASE laraveldb TO laraveluser;

\q
```

7. Install Caddy
```
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https

curl -fsSL https://dl.cloudsmith.io/public/caddy/stable/gpg.key | sudo tee /etc/apt/keyrings/caddy.asc >/dev/null

echo "deb [signed-by=/etc/apt/keyrings/caddy.asc] https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main" | sudo tee /etc/apt/sources.list.d/caddy.list

sudo apt update

apt install -y caddy

caddy version

systemctl status caddy
systemctl start caddy
systemctl enable caddy
```

8. Membuat Project laravel
Installer global
```
/bin/bash -c "$(curl -fsSL https://php.new/install/linux/8.4)"

atau

composer global require laravel/installer
reboot
```

Buat Project
```
laravel new laravel-demo
```

Tambahkan akses di Caddyfile
```
:8001 {
    root * /srv/laravel-demo/public
    php_fastcgi unix//run/php/php8.2-fpm.sock
    file_server
}
```

Rubah Kepemilikan agar bisa di akses oleh caddy
```
chown -R caddy:caddy /srv/
chmod -R 777 /srv/
```

Restart Caddy
```
systemctl daemon-reload
systemctl restart caddy
systemctl restart php8.2-fpm
```

9. Reboot System 
```
reboot
```

10. Dokumentasi via AI = https://chatgpt.com/share/67b92606-b45c-800e-986e-b602e0c4475b