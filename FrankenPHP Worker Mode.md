[![FrankenPHP Worker Mode](https://img.youtube.com/vi/A79c5jwc4U0/0.jpg)](https://www.youtube.com/watch?v=A79c5jwc4U0)

# FrankenPHP Worker Mode, Port Berbeda dan Multi Sites/Domain (youtube)

## Bahasan

1. WORKER MODE dengan Laravel Octane
2. PENGATURAN PORT
3. MULTI SITE/DOMAIN

## Langkah-langkah

1. Create VM-Multipass
   ```
   multipass launch -n franken -c 3 -m 3G -d 32G
   sudo apt update
   sudo apt upgrade -y
   sudo apt install zip -y
   ```

2. Install docker https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository
   ```
   #Add Docker's official GPG key:
    sudo apt-get update
    sudo apt-get install ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    #Add the repository to Apt sources:
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
   ```

3. Install php
   ```
   sudo apt install php php-mbstring php-dom php-tokenizer php-readline php-sqlite3 php-curl -y
   ```

4. Install composer https://getcomposer.org/download/
   ```
   php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
   php -r "if (hash_file('sha384', 'composer-setup.php') === 'dac665fdc30fdd8ec78b38b9800061b4150413ff2e3b6f88543c636f7cd84f6db9189d43a81e5503cda447da73c7e5b6') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
   php composer-setup.php
   php -r "unlink('composer-setup.php');"
   sudo mv composer.phar /usr/local/bin/composer
   ```

5. Install laravel
   ```
   composer global require laravel/installer
   echo 'export PATH="$PATH:$HOME/.config/composer/vendor/bin"' >> ~/.bashrc
   ```

6. Install frankenphp
   ```
   curl https://frankenphp.dev/install.sh | sh
   mv frankenphp /usr/local/bin/
   frankenphp php-server -r server/
   ```

7. Project Laravel baru
   ```
   laravel new worker
   cd worker
   ```

8. Laravel Octane https://frankenphp.dev/docs/laravel/#laravel-octane/
   ```
   composer require laravel/octane
   php artisan octane:install --server=frankenphp

   php artisan octane:frankenphp

   php artisan octane:frankenphp --workers 20 --port 80

   php artisan octane:frankenphp --admin-port 2020 --port 8001
   ```

# Xenara Cafe and Coworking Space
Ruko Citra Grand, Blok LONDON C-08, Semarang, Jawa Tengah, Indonesia 50276
