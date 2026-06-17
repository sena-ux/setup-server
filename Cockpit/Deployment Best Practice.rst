===================================================================
Panduan Produksi: Deployment SIMASDA & INLISLITEv33 (Podman Pods)
===================================================================

:Arsitektur: Podman Pods + FrankenPHP + Nginx Proxy Manager (NPM) + UFW
:Strategi Data: Stateless Container dengan Live Mounting (*hostPath*)
:Status Proyek: SIMASDA (Laravel Octane Worker), INLISLITEv33 (CI4 Standar)

Dokumen ini memuat panduan standardisasi deployment untuk aplikasi **SIMASDA** dan **INLISLITEv33**. Arsitektur ini didesain guna mencapai performa tinggi, isolasi total antar-aplikasi, serta kemudahan pemeliharaan (*zero-downtime code updates*).

.. note::
   **Filosofi Utama:** Kontainer murni hanya bertindak sebagai peminjam *environment* runtime PHP & Web Server, sedangkan seluruh kode, file konfigurasi, dan file unggahan (*uploads*) dari pengguna disimpan secara mutlak di dalam *disk* server lokal (Native OS).

Struktur Direktori Akhir pada Native OS
=======================================

Seluruh folder proyek diletakkan secara mandiri di bawah direktori ``/home/app/``:

.. code-block:: text

   /home/app/
   ├── SIMASDA/
   │   ├── app/
   │   ├── public/
   │   ├── storage/            # Persisten di Host OS
   │   ├── .env
   │   ├── Caddyfile          # Mode Laravel Octane Worker
   │   ├── Containerfile
   │   ├── entrypoint.sh
   │   └── simasda-pod.yaml
   └── inlislitev33/
       ├── app/
       ├── public/
       ├── .env
       ├── Caddyfile          # Mode CI4 Standar (Non-Worker)
       ├── Containerfile
       ├── entrypoint.sh
       └── inlislite-pod.yaml

Konfigurasi Proyek 1: SIMASDA (Laravel Octane)
==============================================

Caddyfile (SIMASDA)
-------------------
.. code-block:: caddy

   :80 {
       root * public
       file_server

       frankenphp {
           worker public/index.php
       }
   }

entrypoint.sh (SIMASDA)
-----------------------
.. code-block:: bash

   #!/bin/bash
   cd /app

   if [ ! -d "vendor" ]; then
       echo "[INIT] Folder vendor tidak ditemukan. Menjalankan 'composer install'..."
       composer install --no-dev --optimize-autoloader --no-interaction --prefer-dist
   fi

   if [ -f ".env" ]; then
       if ! grep -q "APP_KEY=base64" .env; then
           echo "[INIT] Generate APP_KEY Laravel..."
           php artisan key:generate --no-interaction
       fi
   fi

   chown -R www-data:www-data /app/storage /app/bootstrap/cache
   chmod -R 775 /app/storage /app/bootstrap/cache

   echo "[START] Menyalakan FrankenPHP + Laravel Octane..."
   exec frankenphp run --config /app/Caddyfile

.. note::
   **Trik Bash Interpreter Bypass:** Hak eksekusi skrip ``entrypoint.sh`` dipaksa lewat interpreter ``/bin/bash`` yang dipanggil langsung melalui properti ``command`` di file YAML Podman. Ini menghindari kendala *Permission Denied* akibat penimpaan sistem berkas oleh fitur *Live Mounting*.

Containerfile (SIMASDA & INLISLITEv33)
--------------------------------------
.. code-block:: dockerfile

   FROM docker.io/dunglas/frankenphp:1.9-alpine

   RUN apk add --no-cache icu-dev libzip-dev zip unzip libstdc++ oniguruma-dev libpng-dev libjpeg-turbo-dev freetype-dev curl-dev git postgresql-dev bash && \
       docker-php-ext-install pdo pdo_pgsql pgsql

   RUN install-php-extensions intl bcmath pdo_mysql mysqli zip gd redis opcache pcntl mbstring pdo_pgsql pgsql

   RUN echo "opcache.enable=1" >> /usr/local/etc/php/conf.d/opcache.ini && \
       echo "opcache.memory_consumption=256" >> /usr/local/etc/php/conf.d/opcache.ini && \
       echo "opcache.max_accelerated_files=20000" >> /usr/local/etc/php/conf.d/opcache.ini && \
       echo "opcache.validate_timestamps=0" >> /usr/local/etc/php/conf.d/opcache.ini && \
       echo "opcache.save_comments=1" >> /usr/local/etc/php/conf.d/opcache.ini

   COPY --from=docker.io/library/composer:2 /usr/bin/composer /usr/bin/composer

   WORKDIR /app

simasda-pod.yaml
----------------
.. code-block:: yaml

   apiVersion: v1
   kind: Pod
   metadata:
     name: simasda-pod
     labels:
       app: simasda-app
   spec:
     hostNetwork: false
     containers:
       - name: simasda-container
         image: localhost/simasda-image:latest
         imagePullPolicy: Never
         command: ["/bin/bash", "/app/entrypoint.sh"]
         env:
           - name: FRANKENPHP_CONFIG
             value: "worker /app/public/index.php"
         livenessProbe:
           httpGet:
             path: /up
             port: 80
           initialDelaySeconds: 120
           periodSeconds: 30
           timeoutSeconds: 10
           failureThreshold: 3
         volumeMounts:
           - name: source-code
             mountPath: /app
           - name: caddy-data
             mountPath: /data
           - name: caddy-config
             mountPath: /config
         ports:
           - containerPort: 80
     volumes:
       - name: source-code
         hostPath:
           path: /home/app/SIMASDA
       - name: caddy-data
         persistentVolumeClaim:
           claimName: caddy_data_simasda
       - name: caddy-config
         persistentVolumeClaim:
           claimName: caddy_config_simasda
   ---
   apiVersion: v1
   kind: Service
   metadata:
     name: simasda-service
   spec:
     selector:
       app: simasda-app
     ports:
       - protocol: TCP
         port: 80
         targetPort: 80

Konfigurasi Proyek 2: INLISLITEv33 (CI4 / Non-Worker)
====================================================

Caddyfile (INLISLITEv33)
------------------------
.. code-block:: caddy

   :80 {
       root * public
       file_server
       frankenphp
   }

.. warning::
   Karena INLISLITEv33 berbasis CodeIgniter 4 (CI4), aplikasi ini **TIDAK MENDUKUNG** Laravel Octane Worker Mode. Jangan menambahkan blok ``worker`` pada Caddyfile atau variabel ``FRANKENPHP_CONFIG`` pada file YAML agar tidak terjadi *Crash Loop (Restart Terus-menerus)*.

inlislite-pod.yaml
------------------
.. code-block:: yaml

   apiVersion: v1
   kind: Pod
   metadata:
     name: inlislite-pod
     labels:
       app: inlislite-app
   spec:
     hostNetwork: false
     containers:
       - name: inlislite-container
         image: localhost/inlislite-image:latest
         imagePullPolicy: Never
         command: ["/bin/bash", "/app/entrypoint.sh"]
         volumeMounts:
           - name: source-code
             mountPath: /app
         ports:
           - containerPort: 80
     volumes:
       - name: source-code
         hostPath:
           path: /home/app/inlislitev33
   ---
   apiVersion: v1
   kind: Service
   metadata:
     name: inlislite-service
   spec:
     selector:
       app: inlislite-app
     ports:
       - protocol: TCP
         port: 80
         targetPort: 80

Langkah-Langkah Eksekusi (Deployment)
=====================================

1. Membuat Network Bridge Kustom Podman
---------------------------------------
.. code-block:: bash

   sudo podman network create \
     --driver bridge \
     --subnet 172.21.0.0/16 \
     --gateway 172.21.0.1 \
     web_service

2. Konfigurasi UFW Firewall (Akses DB Native)
---------------------------------------------
Identifikasi interface jaringannya (misal: ``podman1``):

.. code-block:: bash

   sudo podman network inspect web_service | grep network_interface

Izinkan akses menuju port database lokal (misal kustom port ``33306``):

.. code-block:: bash

   sudo ufw allow in on podman1 to any port 33306 proto tcp comment "Akses DB internal podman"
   sudo ufw reload

3. Build Image Masing-Masing Aplikasi
-------------------------------------
.. code-block:: bash

   # Build SIMASDA
   cd /home/app/SIMASDA
   sudo podman build -t simasda-image:latest -f Containerfile .

   # Build INLISLITEv33
   cd /home/app/inlislitev33
   sudo podman build -t inlislite-image:latest -f Containerfile .

4. Menyalakan Pod (Kube Play)
-----------------------------
Suntikkan network ``web_service`` langsung via CLI terminal:

.. code-block:: bash

   sudo podman kube play --network web_service /home/app/SIMASDA/simasda-pod.yaml
   sudo podman kube play --network web_service /home/app/inlislitev33/inlislite-pod.yaml

.. note::
   Jika Anda membutuhkan IP angka statis murni via CLI (bukan DNS Service), Anda bisa menyertakan flag ``--ip``, contoh:
   ``sudo podman kube play --network web_service --ip 172.21.0.100 simasda-pod.yaml``

5. Konfigurasi Nginx Proxy Manager (NPM)
----------------------------------------
Buka dashboard UI NPM, buat *Proxy Host* baru dan arahkan langsung ke nama DNS internal Service:

* **SIMASDA:** Forward Hostname: ``simasda-service`` | Port: ``80``
* **INLISLITE:** Forward Hostname: ``inlislite-service`` | Port: ``80``

Panduan Pemeliharaan Harian (Maintenance)
=========================================

Pembaruan Kode (*Live Update*)
------------------------------
Cukup lakukan perubahan kode (misal ``git pull``) langsung di server host native. 

Khusus untuk **SIMASDA (Laravel Octane)**, bersihkan memori RAM kontainer agar kode baru terbaca dengan cara melakukan restart kontainer via Cockpit UI (memakan waktu < 1 detik) atau jalankan perintah:

.. code-block:: bash

   sudo podman exec -it simasda-container php artisan octane:reload

Membongkar Layanan (*Teardown*)
-------------------------------
Untuk mematikan pod secara bersih tanpa menghapus data persisten di Host OS:

.. code-block:: bash

   sudo podman kube down /home/app/SIMASDA/simasda-pod.yaml
   sudo podman kube down /home/app/inlislitev33/inlislite-pod.yaml
