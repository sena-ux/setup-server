# Panduan Keamanan Database Host untuk Container Podman: UFW & Network Isolation

Panduan teknis untuk mengamankan akses database native di host OS dari container Podman menggunakan UFW dengan network isolation yang ketat.

---

## 📋 Daftar Isi

- [Pengenalan Architecture](#pengenalan-architecture)
- [1. Konfigurasi Database Native](#1-konfigurasi-database-native)
- [2. Identifikasi Interface Jaringan Podman](#2-identifikasi-interface-jaringan-podman)
- [3. Aturan UFW Spesifik & Eksklusif](#3-aturan-ufw-spesifik--eksklusif)
- [4. Persistence & Automation](#4-persistence--automation)
- [5. Docker vs Podman Rootless: Network Handling](#5-docker-vs-podman-rootless-network-handling)
- [Testing & Verification](#testing--verification)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

---

## Pengenalan Architecture

### Skenario Anda

```
┌─────────────────────────────────────────────────────────────┐
│                      Host OS (172.20.0.1)                   │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  MariaDB/PostgreSQL (NATIVE)                        │   │
│  │  Bind Address: 172.20.0.1 atau 127.0.0.1          │   │
│  │  Port: 3306 (MySQL/MariaDB) atau 5432 (PostgreSQL) │   │
│  │                                                      │   │
│  │  UFW Rules:                                         │   │
│  │  Allow IN  172.20.0.0/16 → 3306 (via podman-iface) │   │
│  │  REJECT OUT 172.20.0.0/16 to 3306 (exclude iface)  │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌──────────────────────────────────┐                       │
│  │ Podman Network (172.20.0.0/16)   │                       │
│  │ Interface: podman0 (kvm/slirp)   │                       │
│  │                                  │                       │
│  │  ┌──────────────────────────┐   │                       │
│  │  │ Container App            │   │                       │
│  │  │ IP: 172.20.0.x          │   │                       │
│  │  │ Gateway: 172.20.0.1      │   │                       │
│  │  └──────────────────────────┘   │                       │
│  └──────────────────────────────────┘                       │
└─────────────────────────────────────────────────────────────┘
```

### Keamanan yang Diinginkan

✅ Container Podman (172.20.0.0/16) **bisa** akses database di host  
❌ Network lain **TIDAK BISA** akses database  
❌ Port database TIDAK terbuka ke network publik  
✅ Rules bersifat **persistent** dan automatic

---

# 1. Konfigurasi Database Native

## 1.1 MariaDB / MySQL

### Step 1: Edit Konfigurasi MySQL

```bash
# Backup konfigurasi original
sudo cp /etc/mysql/mariadb.conf.d/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf.backup

# Edit konfigurasi
sudo nano /etc/mysql/mariadb.conf.d/50-server.cnf
```

### Step 2: Modify bind-address

Cari baris `bind-address` dan ubah:

```ini
# SEBELUM
# bind-address            = 127.0.0.1

# SESUDAH - Listen on Podman network gateway
bind-address            = 172.20.0.1

# Atau listen on semua interface (less secure, not recommended)
# bind-address            = 0.0.0.0

# Untuk dual-bind (localhost + Podman)
# bind-address            = 127.0.0.1,172.20.0.1
```

**Opsi Rekomendasi**:
- `127.0.0.1` - Hanya localhost (paling aman untuk testing)
- `172.20.0.1` - Hanya Podman network (recommended)
- `0.0.0.0` - Semua interface (TIDAK RECOMMENDED untuk production)

### Step 3: Konfigurasi Port & Skip External Connections

Tambahkan di `[mysqld]` section:

```ini
[mysqld]
bind-address            = 172.20.0.1
port                    = 3306

# Tidak listen ke IPv6 (optional)
skip-networking         = 0
skip-name-resolve       = 1

# Maksimal connections dari container
max_connections         = 100

# TCP keep-alive (prevent idle connections)
interactive_timeout     = 28800
wait_timeout            = 28800
```

### Step 4: Restart MariaDB

```bash
# Restart service
sudo systemctl restart mariadb

# Verify bind address
sudo netstat -tulpn | grep 3306
# atau
sudo ss -tulpn | grep 3306

# Output yang diharapkan:
# tcp  0  0 172.20.0.1:3306  0.0.0.0:*  LISTEN  xxxx/mariadb
```

### Step 5: Create Database User untuk Container

```bash
# Connect ke MySQL
sudo mysql -u root -p

# Create user dengan akses terbatas ke segmen Podman
CREATE USER 'podman_user'@'172.20.%' IDENTIFIED BY 'secure_password_here';

# Grant privileges
GRANT ALL PRIVILEGES ON myapp.* TO 'podman_user'@'172.20.%';

# Atau untuk specific privileges saja
GRANT SELECT, INSERT, UPDATE, DELETE ON myapp.* TO 'podman_user'@'172.20.%';

# Flush privileges
FLUSH PRIVILEGES;

# Verify user
SELECT user, host FROM mysql.user WHERE user='podman_user';

# Exit
EXIT;
```

---

## 1.2 PostgreSQL

### Step 1: Edit PostgreSQL Configuration

```bash
# Backup original
sudo cp /etc/postgresql/14/main/postgresql.conf /etc/postgresql/14/main/postgresql.conf.backup

# Edit
sudo nano /etc/postgresql/14/main/postgresql.conf
```

### Step 2: Modify listen_addresses

```ini
# SEBELUM
# listen_addresses = 'localhost'

# SESUDAH
listen_addresses = '172.20.0.1'

# Atau untuk dual-binding
# listen_addresses = 'localhost,172.20.0.1'
```

### Step 3: Configure pg_hba.conf (Host-Based Authentication)

```bash
sudo nano /etc/postgresql/14/main/pg_hba.conf
```

Tambahkan baris di bagian akhir:

```
# Podman network access
host    myapp       podman_user     172.20.0.0/16       md5
host    replication replication_user 172.20.0.0/16       md5

# IPv4 local connections (existing)
host    all         all             127.0.0.1/32        md5

# IPv6 local connections (existing)
host    all         all             ::1/128             md5
```

### Step 4: Restart PostgreSQL

```bash
sudo systemctl restart postgresql

# Verify listen address
sudo ss -tulpn | grep 5432

# Output yang diharapkan:
# tcp  0  0 172.20.0.1:5432  0.0.0.0:*  LISTEN  xxxx/postgres
```

### Step 5: Create PostgreSQL User

```bash
# Connect sebagai postgres user
sudo -u postgres psql

# Create user
CREATE USER podman_user WITH PASSWORD 'secure_password_here';

# Create database
CREATE DATABASE myapp OWNER podman_user;

# Grant privileges
GRANT CONNECT ON DATABASE myapp TO podman_user;
GRANT USAGE ON SCHEMA public TO podman_user;
GRANT CREATE ON SCHEMA public TO podman_user;

# Exit
\q
```

---

# 2. Identifikasi Interface Jaringan Podman

## 2.1 Untuk Podman User (Rootless)

### Method 1: Menggunakan `podman network inspect`

```bash
# List semua network Podman
podman network ls

# Inspect network spesifik (misalkan network name adalah 'my-network')
podman network inspect my-network
```

**Output Contoh**:

```json
[
  {
    "Name": "my-network",
    "Id": "2f3b4a5c6d7e8f9a0b1c2d3e4f5a6b7c",
    "Driver": "bridge",
    "NetworkInterface": "podman0",
    "Created": "2024-01-10T10:30:45.123456789Z",
    "Subnets": [
      {
        "Subnet": "172.20.0.0/16",
        "Gateway": "172.20.0.1"
      }
    ],
    "Labels": {},
    "Options": {},
    "IPAMOptions": {},
    "Internal": false,
    "IPv6": false,
    "DisableDns": false
  }
]
```

**Yang Penting**:
- `"NetworkInterface": "podman0"` - Nama interface di host
- `"Subnet": "172.20.0.0/16"` - Range IP network
- `"Gateway": "172.20.0.1"` - IP gateway (host side)

### Method 2: Menggunakan `ip addr` dan `ip route`

```bash
# Lihat semua interface network
ip addr

# Lihat hanya interface yang relevan dengan Podman
ip addr show | grep -E "^[0-9]+:|172.20"

# Lihat routing table
ip route | grep 172.20

# Output contoh:
# 172.20.0.0/16 dev podman0 proto kernel scope link src 172.20.0.1
```

### Method 3: Menggunakan `ifconfig` (legacy)

```bash
# Check semua interfaces
ifconfig | grep -A 10 "podman0"

# Output contoh:
# podman0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
#         inet 172.20.0.1  netmask 255.255.0.0  broadcast 172.20.255.255
#         inet6 fe80::42:56ff:fe34:4d2b  prefixlen 64  scopeid 0x20<link>
```

### Method 4: Menggunakan `netstat` atau `ss`

```bash
# Lihat interface dengan IP 172.20.x.x
ss -an | grep 172.20

# Lihat routing
netstat -rn | grep 172.20
# atau
ip route show | grep 172.20
```

---

## 2.2 Perbedaan Podman Rootless vs Podman Root

### Podman Rootless (User namespace)

- **Network Type**: slirp4netns atau netavark (user-space networking)
- **Interface Name**: Biasanya **tun0** atau **tap0** (tidak ada bridge interface di host)
- **Visibility**: Interface **TIDAK terlihat** di host dengan `ip addr show`
- **Routing**: Dihandle melalui user namespace, bukan kernel network namespace
- **Implication untuk UFW**: 

  ```bash
  # Interface tidak terlihat di host!
  # Jadi tidak bisa pakai "-i podman0" di UFW rule
  
  # Harus pakai CIDR directly:
  # ufw allow in from 172.20.0.0/16 to 172.20.0.1 port 3306
  ```

### Podman Root (System-wide)

- **Network Type**: Bridge network (native kernel bridge)
- **Interface Name**: `podman0`, `br-xxx` (terlihat di host)
- **Visibility**: Interface **TERLIHAT** di host dengan `ip addr show`
- **Routing**: Dihandle oleh kernel network
- **Implication untuk UFW**:

  ```bash
  # Bisa pakai interface spesifik:
  # ufw allow in on podman0 from 172.20.0.0/16 to 172.20.0.1 port 3306
  ```

### Visualisasi Perbedaan

```
DOCKER (Root):
┌─────────────────────────────────────┐
│ Host Kernel Network                 │
│ Interface: docker0 / br-xxxx         │ ← Terlihat di host
│ 172.17.0.0/16 (default)            │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ Container Network Namespace     │ │
│ │ eth0: 172.17.0.2               │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘

PODMAN ROOTLESS (User namespace):
┌─────────────────────────────────────┐
│ User Namespace (User's session)     │
│ Virtual Interface: tun0 / tap0       │ ← TIDAK terlihat di host!
│ 172.20.0.0/16                       │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ Container Network Namespace     │ │
│ │ eth0: 172.20.0.2               │ │
│ └─────────────────────────────────┘ │
│                                     │
│ [slirp4netns / netavark]            │
│ User-space networking stack         │
└─────────────────────────────────────┘
```

---

## 2.3 Finding Podman Network pada Podman Rootless

Karena interface **tidak terlihat** di host, gunakan cara alternatif:

### Cek network configuration dari Podman config

```bash
# Untuk Podman Rootless, config disimpan di user home
cat ~/.config/containers/networks/my-network.json

# Output contoh:
# {
#   "name": "my-network",
#   "id": "2f3b4a5c6d7e8f9a0b1c2d3e4f5a6b7c",
#   "driver": "bridge",
#   "network_interface": "podman0",
#   "subnets": [
#     {
#       "subnet": "172.20.0.0/16",
#       "gateway": "172.20.0.1"
#     }
#   ]
# }
```

### Cek dari running container

```bash
# Start container (jika belum ada)
podman run -d --name test-container --network my-network alpine sleep 1000

# Inspect container network
podman inspect test-container --format='{{json .NetworkSettings.Networks}}'

# Output contoh:
# {
#   "my-network": {
#     "IPAddress": "172.20.0.2",
#     "Gateway": "172.20.0.1",
#     "IPPrefixLen": 16,
#     "MacAddress": "02:42:ac:14:00:02"
#   }
# }

# Clean up
podman rm -f test-container
```

### Cek netstat dari container perspective

```bash
# Exec command dalam container
podman exec test-container ip addr

# Output contoh:
# 1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536
# 2: eth0: <BROADCAST,UP,LOWER_UP> mtu 1500
#     inet 172.20.0.2/16 brd 172.20.255.255
```

---

# 3. Aturan UFW Spesifik & Eksklusif

## 3.1 Persiapan UFW

### Step 1: Install UFW

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install ufw -y

# Cek status
sudo ufw status
```

### Step 2: Enable UFW

```bash
# Enable UFW
sudo ufw enable

# Cek status
sudo ufw status verbose

# Output:
# Status: active
# Logging: on (low)
# Default: deny (incoming), allow (outgoing), allow (routed)
```

### Step 3: Konfigurasi Default Policy

```bash
# Default: Deny incoming, Allow outgoing
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw default allow routed
```

---

## 3.2 UFW Rules untuk Database Access

### Kasus 1: Podman Root dengan Interface Bridge

Jika menggunakan Podman root dan interface `podman0` **terlihat** di host:

```bash
# ALLOW: Container dari podman0 interface ke port 3306
sudo ufw allow in on podman0 from 172.20.0.0/16 to 172.20.0.1 port 3306 proto tcp

# REJECT: Semua akses lain ke port 3306
sudo ufw reject in from any to 172.20.0.1 port 3306 proto tcp

# Verify rules
sudo ufw status numbered
```

### Kasus 2: Podman Rootless (Recommended untuk security)

Karena interface tidak terlihat di host, gunakan CIDR langsung:

```bash
# ALLOW: Podman network range ke database
sudo ufw allow in from 172.20.0.0/16 to 172.20.0.1 port 3306 proto tcp

# ALLOW: Localhost access untuk management
sudo ufw allow in from 127.0.0.1 to 127.0.0.1 port 3306 proto tcp

# REJECT: Semua akses lain ke port 3306
sudo ufw reject in to 172.20.0.1 port 3306 proto tcp
sudo ufw reject in to 127.0.0.1 port 3306 proto tcp

# Verify rules
sudo ufw status numbered
```

**Catatan**: Dengan Podman Rootless, kita tidak bisa menggunakan `-i interface` di UFW rule, tapi bisa pakai source IP range langsung.

### Kasus 3: Multi-Network Setup

Jika ada multiple Podman networks:

```bash
# Network 1: App services (172.20.0.0/16)
sudo ufw allow in from 172.20.0.0/16 to 172.20.0.1 port 3306 proto tcp

# Network 2: Worker services (172.21.0.0/16)
sudo ufw allow in from 172.21.0.0/16 to 172.21.0.1 port 3306 proto tcp

# Network 3: Cache services (172.22.0.0/16)
sudo ufw allow in from 172.22.0.0/16 to 172.22.0.1 port 3306 proto tcp

# Reject semua akses lain
sudo ufw reject in to any port 3306 proto tcp
```

---

## 3.3 PostgreSQL Rules

Untuk PostgreSQL (port 5432), aturan serupa:

```bash
# ALLOW Podman network
sudo ufw allow in from 172.20.0.0/16 to 172.20.0.1 port 5432 proto tcp

# ALLOW localhost
sudo ufw allow in from 127.0.0.1 to 127.0.0.1 port 5432 proto tcp

# REJECT others
sudo ufw reject in to 172.20.0.1 port 5432 proto tcp
sudo ufw reject in to 127.0.0.1 port 5432 proto tcp
```

---

## 3.4 Advanced: UFW dengan Custom Application Profile

Buat custom UFW profile untuk lebih mudah dikelola:

```bash
# Edit UFW applications config
sudo nano /etc/ufw/applications.d/podman-database

# Isi file:
[Podman-MySQL]
title=MySQL for Podman Containers
description=Allow MySQL access from Podman network
ports=3306/tcp

[Podman-PostgreSQL]
title=PostgreSQL for Podman Containers
description=Allow PostgreSQL access from Podman network
ports=5432/tcp
```

Setelah membuat profile, gunakan:

```bash
# List profiles
sudo ufw app list

# Apply profile untuk Podman network
sudo ufw allow from 172.20.0.0/16 app "Podman-MySQL"

# Verify
sudo ufw status verbose
```

---

## 3.5 Verification Rules

```bash
# Show all rules dengan line numbers
sudo ufw status numbered

# Show rules yang berhubungan dengan database
sudo ufw status | grep 3306

# Show detailed logging
sudo ufw logging high
sudo tail -f /var/log/ufw.log | grep 3306

# Test rule dengan nmap (dari host)
# BEFORE applying strict rules:
nmap -p 3306 localhost

# AFTER applying strict rules:
# Port should show as "filtered" or "rejected"
```

---

# 4. Persistence & Automation

## 4.1 UFW Rules Persistence

UFW secara default **SUDAH persistent** setelah di-enable:

```bash
# Rules disimpan di:
# /etc/ufw/rules.d/ (custom rules)
# /etc/default/ufw (global config)
# /var/lib/ufw/ (runtime state)

# Backup rules
sudo cp -r /etc/ufw /etc/ufw.backup.$(date +%Y%m%d)

# View rules file
cat /etc/ufw/rules.d/user.rules

# View IPv4 rules
cat /etc/ufw/rules.d/user.rules | grep -v "^#" | head -20
```

## 4.2 Persisten Across Reboot

Verify persistence dengan reboot test:

```bash
# Catat current rules
sudo ufw status numbered > /tmp/ufw_before_reboot.txt

# Reboot
sudo reboot

# Setelah reboot, verify rules masih ada
sudo ufw status numbered > /tmp/ufw_after_reboot.txt

# Compare
diff /tmp/ufw_before_reboot.txt /tmp/ufw_after_reboot.txt
```

## 4.3 Database Bind Address Persistence

Database bind address sudah persistent di config file, tapi verify:

```bash
# MariaDB
sudo cat /etc/mysql/mariadb.conf.d/50-server.cnf | grep bind-address

# PostgreSQL
sudo cat /etc/postgresql/14/main/postgresql.conf | grep listen_addresses
```

---

## 4.4 Automated UFW Rules Backup

Buat script untuk backup UFW rules secara berkala:

```bash
# File: /usr/local/bin/backup-ufw-rules.sh
#!/bin/bash

BACKUP_DIR="/var/backups/ufw"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup UFW rules
sudo ufw status > $BACKUP_DIR/ufw_status_$DATE.txt
sudo cp -r /etc/ufw $BACKUP_DIR/ufw_config_$DATE/

# Keep only last 30 days
find $BACKUP_DIR -type f -mtime +30 -delete

echo "UFW rules backed up to $BACKUP_DIR/ufw_status_$DATE.txt"
```

Setup cron job:

```bash
# Edit crontab
sudo crontab -e

# Tambahkan baris (backup setiap hari jam 2 AM):
0 2 * * * /usr/local/bin/backup-ufw-rules.sh

# Verify cron job
sudo crontab -l | grep backup-ufw
```

---

## 4.5 Automated UFW Rules Generation

Buat script untuk generate UFW rules otomatis berdasarkan Podman networks:

```bash
# File: /usr/local/bin/setup-podman-firewall.sh
#!/bin/bash

set -e

# Warna output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}[*] Setting up UFW rules for Podman networks${NC}"

# 1. Enable UFW jika belum
if ! sudo ufw status | grep -q "active"; then
    echo -e "${YELLOW}[*] Enabling UFW...${NC}"
    echo "y" | sudo ufw enable
fi

# 2. Set default policy
echo -e "${YELLOW}[*] Setting default policies...${NC}"
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw default allow routed

# 3. Allow SSH (IMPORTANT!)
echo -e "${YELLOW}[*] Allowing SSH access...${NC}"
sudo ufw allow in ssh || true

# 4. Get Podman networks
echo -e "${YELLOW}[*] Scanning Podman networks...${NC}"
PODMAN_NETWORKS=$(podman network ls --format "{{.Name}}")

if [ -z "$PODMAN_NETWORKS" ]; then
    echo -e "${RED}[!] No Podman networks found${NC}"
    exit 1
fi

# 5. For each network, get subnet and add UFW rule
for NETWORK in $PODMAN_NETWORKS; do
    SUBNET=$(podman network inspect "$NETWORK" --format "{{index .Subnets 0}}" 2>/dev/null | grep -oP '(\d+\.\d+\.\d+\.\d+/\d+)')
    GATEWAY=$(podman network inspect "$NETWORK" --format "{{index .Subnets 0 \"Gateway\"}}" 2>/dev/null)
    
    if [ -n "$SUBNET" ] && [ -n "$GATEWAY" ]; then
        echo -e "${GREEN}[+] Found network: $NETWORK${NC}"
        echo "    Subnet: $SUBNET"
        echo "    Gateway: $GATEWAY"
        
        # Add rule untuk database (MySQL)
        echo -e "${YELLOW}[*] Adding UFW rule for MySQL ($SUBNET → $GATEWAY:3306)${NC}"
        sudo ufw allow in from "$SUBNET" to "$GATEWAY" port 3306 proto tcp || true
        
        # Add rule untuk database (PostgreSQL)
        echo -e "${YELLOW}[*] Adding UFW rule for PostgreSQL ($SUBNET → $GATEWAY:5432)${NC}"
        sudo ufw allow in from "$SUBNET" to "$GATEWAY" port 5432 proto tcp || true
    fi
done

# 6. Reject database port secara keseluruhan
echo -e "${YELLOW}[*] Rejecting other access to database ports...${NC}"
sudo ufw reject in to any port 3306 proto tcp || true
sudo ufw reject in to any port 5432 proto tcp || true

# 7. Show final rules
echo -e "${GREEN}[+] Final UFW rules:${NC}"
sudo ufw status numbered

echo -e "${GREEN}[+] UFW setup complete!${NC}"
```

Jalankan script:

```bash
# Make executable
sudo chmod +x /usr/local/bin/setup-podman-firewall.sh

# Run script
sudo /usr/local/bin/setup-podman-firewall.sh

# Atau dengan sudo dalam script
/usr/local/bin/setup-podman-firewall.sh
```

---

## 4.6 Systemd Service untuk Auto-Repair Rules

Buat systemd service yang memastikan UFW rules tetap applied:

```bash
# File: /etc/systemd/system/podman-firewall-repair.service
[Unit]
Description=Podman Firewall Rules Auto-Repair
After=network-online.target ufw.service
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/setup-podman-firewall.sh
User=root

[Install]
WantedBy=multi-user.target
```

Setup timer (jalankan setiap 10 menit):

```bash
# File: /etc/systemd/system/podman-firewall-repair.timer
[Unit]
Description=Podman Firewall Rules Auto-Repair Timer
Requires=podman-firewall-repair.service

[Timer]
OnBootSec=2min
OnUnitActiveSec=10min
Persistent=true

[Install]
WantedBy=timers.target
```

Enable services:

```bash
# Reload systemd
sudo systemctl daemon-reload

# Enable timer
sudo systemctl enable podman-firewall-repair.timer

# Start timer
sudo systemctl start podman-firewall-repair.timer

# Check status
sudo systemctl status podman-firewall-repair.timer

# View logs
sudo journalctl -u podman-firewall-repair.service -f
```

---

# 5. Docker vs Podman Rootless: Network Handling

## 5.1 Docker Architecture (Traditional)

### How Docker Works

```
┌─────────────────────────────────────────────────────────┐
│                    Host OS                               │
│                                                          │
│  ┌────────────────────────────────────────────────────┐ │
│  │ Docker Daemon (root process)                       │ │
│  │ Manages: containers, images, networks              │ │
│  └────────────────────────────────────────────────────┘ │
│                         ↓                                 │
│  ┌────────────────────────────────────────────────────┐ │
│  │ Kernel Network Namespace                           │ │
│  │ Real kernel bridge interface: docker0              │ │
│  │ IP: 172.17.0.1/16                                  │ │
│  │                                                     │ │
│  │ ┌──────────────────┐         ┌──────────────────┐  │ │
│  │ │ Container 1      │         │ Container 2      │  │ │
│  │ │ Network NS       │         │ Network NS       │  │ │
│  │ │ eth0: 172.17.0.2 │ ← veth ← │ eth0: 172.17.0.3 │  │ │
│  │ └──────────────────┘         └──────────────────┘  │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  host routing: 172.17.0.0/16 → docker0                 │
└─────────────────────────────────────────────────────────┘
```

### Docker Interface Visibility

```bash
# Docker interface SELALU terlihat di host
ip addr show docker0

# Output:
# 4: docker0: <BROADCAST,RUNNING,MULTICAST> mtu 1500
#    inet 172.17.0.1/16 scope global docker0

# Sehingga UFW rule bisa menggunakan interface:
sudo ufw allow in on docker0 from 172.17.0.0/16 port 3306
```

### Docker Firewall Considerations

```bash
# Docker memodifikasi iptables langsung (bukan UFW)
# Ini bisa conflict dengan UFW rules!

# Docker tambahkan rules di:
# iptables -t nat -A POSTROUTING -s 172.17.0.0/16 ! -o docker0 -j MASQUERADE

# Check Docker iptables rules
sudo iptables -L -n | grep -i docker
sudo iptables -t nat -L -n | grep -i docker

# Ini menyebabkan: UFW rules bisa ter-override oleh Docker!
```

---

## 5.2 Podman Rootless Architecture

### How Podman Rootless Works

```
┌─────────────────────────────────────────────────────────┐
│                    Host OS                               │
│                                                          │
│  ┌────────────────────────────────────────────────────┐ │
│  │ Podman (user process, NOT root)                    │ │
│  │ Manages: containers, images, networks              │ │
│  │ Runs inside user namespace                         │ │
│  └────────────────────────────────────────────────────┘ │
│                         ↓                                 │
│  ┌────────────────────────────────────────────────────┐ │
│  │ User Namespace (isolated from host)                │ │
│  │ Virtual networking stack: slirp4netns / netavark   │ │
│  │                                                     │ │
│  │ Simulated bridge (NOT real kernel interface):      │ │
│  │ 172.20.0.0/16                                       │ │
│  │ Gateway: 172.20.0.1 (user-space, invisible)        │ │
│  │                                                     │ │
│  │ ┌──────────────────┐         ┌──────────────────┐  │ │
│  │ │ Container 1      │         │ Container 2      │  │ │
│  │ │ Network NS       │         │ Network NS       │  │ │
│  │ │ eth0: 172.20.0.2 │         │ eth0: 172.20.0.3 │  │ │
│  │ └──────────────────┘         └──────────────────┘  │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  NO kernel routing table entry for 172.20.0.0/16       │
│  (interface TIDAK terlihat di host)                     │
└─────────────────────────────────────────────────────────┘
```

### Podman Rootless Interface Visibility

```bash
# Podman Rootless interface TIDAK terlihat di host
ip addr show podman0
# Output: Error - interface tidak ada!

# IP hanya terlihat DARI DALAM container
podman run alpine ip addr show
# eth0 ada dengan IP 172.20.0.2

# Sehingga UFW rule TIDAK bisa menggunakan interface name:
# ❌ TIDAK WORK: sudo ufw allow in on podman0 ...

# HARUS gunakan CIDR directly:
# ✅ WORK: sudo ufw allow in from 172.20.0.0/16 ...
```

### Podman Rootless Firewall Considerations

```bash
# Podman Rootless menggunakan user-space networking
# TIDAK memodifikasi kernel iptables secara langsung
# (iptables modifications terjadi DALAM user namespace saja)

# Sehingga:
# ✅ UFW rules TIDAK akan ter-override
# ✅ No conflict dengan iptables-docker
# ✅ More predictable firewall behavior

# Verify: tidak ada Podman iptables rules di host kernel
sudo iptables -L -n | grep -i podman
# Output: (kosong/tidak ada)

# Tapi iptables rules ADA dalam user namespace:
podman run alpine iptables -L -n | grep -i podman
# Output: (bisa ada, dalam container namespace)
```

---

## 5.3 Perbandingan Tabel

| Aspek | Docker | Podman Rootless |
|-------|--------|-----------------|
| **Daemon** | Root process (privileged) | User process (unprivileged) |
| **Interface Name** | `docker0` / `br-xxxx` | Virtual (slirp4netns/netavark) |
| **Interface Visibility** | ✅ Terlihat di host | ❌ Tidak terlihat |
| **Kernel Network NS** | ✅ Shared dengan host | ❌ Isolated (user namespace) |
| **iptables Modification** | ✅ Host kernel iptables | ❌ User namespace iptables |
| **UFW Compatibility** | ⚠️ Potential conflict | ✅ No conflict |
| **Security** | ❌ Needs privilege escalation | ✅ Rootless = safer |
| **UFW Rule Syntax** | `on interface_name` | `from CIDR` |
| **Persistence** | Depends on Docker daemon | Independent of Podman |
| **Complexity** | Medium (iptables conflicts) | Low (isolated networking) |

---

## 5.4 UFW Rules Syntax Comparison

### Docker (dengan interface)

```bash
# ALLOW dengan interface spesifik
sudo ufw allow in on docker0 from 172.17.0.0/16 to 172.17.0.1 port 3306 proto tcp

# REJECT others
sudo ufw reject in to 172.17.0.1 port 3306 proto tcp
```

### Podman Rootless (tanpa interface)

```bash
# ALLOW dengan CIDR range saja
sudo ufw allow in from 172.20.0.0/16 to 172.20.0.1 port 3306 proto tcp

# REJECT others (tidak perlu specify interface)
sudo ufw reject in to 172.20.0.1 port 3306 proto tcp
```

---

# Testing & Verification

## Test 1: Verify Database Binding

### MariaDB/MySQL

```bash
# From host, test connection dari Podman network IP
mysql -h 172.20.0.1 -u podman_user -p myapp -e "SELECT 1;"

# Output yang diharapkan:
# +---+
# | 1 |
# +---+
# | 1 |
# +---+

# Verify port listening
sudo netstat -tulpn | grep 3306

# Output yang diharapkan:
# tcp  0  0 172.20.0.1:3306  0.0.0.0:*  LISTEN  xxxx/mariadb
```

### PostgreSQL

```bash
# From host
psql -h 172.20.0.1 -U podman_user -d myapp -c "SELECT 1;"

# Output yang diharapkan:
#  ?column?
# ----------
#        1
# (1 row)

# Verify port listening
sudo ss -tulpn | grep 5432
```

---

## Test 2: Verify UFW Rules

```bash
# Show all rules
sudo ufw status numbered

# Expected output untuk MySQL case:
# Status: active
# 
#      To                      Action      From
#      --                      ------      ----
# [ 1] 22/tcp                  ALLOW IN    Anywhere
# [ 2] 3306/tcp                ALLOW IN    172.20.0.0/16
# [ 3] 3306                    REJECT IN   Anywhere
# ...

# Test rule dengan UFW itself
sudo ufw show added

# Show rule lebih detail
sudo ufw show added | grep 3306
```

---

## Test 3: Container to Database Connection

### Create test container dengan network

```bash
# Buat container dengan podman network
podman run -d \
    --name db-test \
    --network my-network \
    -e MYSQL_HOST=172.20.0.1 \
    -e MYSQL_USER=podman_user \
    -e MYSQL_PASSWORD=secure_password \
    -e MYSQL_DB=myapp \
    mysql:8.0 sleep 1000

# Verify container has correct IP
podman inspect db-test --format='{{json .NetworkSettings.Networks}}'
```

### Test connection dari container

```bash
# Exec into container
podman exec db-test bash

# Inside container:
# Test MySQL connection
mysql -h 172.20.0.1 -u podman_user -p myapp -e "SELECT 1;"

# Test dengan 'mysql' command line tool
mysql -h 172.20.0.1 -u podman_user -password=secure_password myapp -e "SELECT DATABASE();"

# Expected output:
# +----------+
# | DATABASE |
# +----------+
# | myapp    |
# +----------+

# Exit container
exit

# Clean up
podman rm -f db-test
```

---

## Test 4: UFW Blocking Test

### Attempt dari host (seharusnya blocked)

```bash
# Try access database dari localhost (unless explicitly allowed)
mysql -h 127.0.0.1 -u podman_user -p myapp -e "SELECT 1;"

# Expected: Connection refused atau timeout

# Try access dari random IP (seharusnya blocked)
# Ini tidak bisa ditest dari host karena localhost, tapi bisa cek logs:
sudo tail -20 /var/log/ufw.log | grep 3306

# Expected output:
# UFW REJECT IN=eth0 OUT= MAC=... SRC=xxx DST=172.20.0.1 DPORT=3306
```

### Blocking test dari container lain

```bash
# Buat container di NETWORK LAIN (tidak allowed)
podman network create other-network

podman run -d \
    --name blocked-container \
    --network other-network \
    alpine sleep 1000

# Try access dari container ini
podman exec blocked-container sh

# Inside container:
# Try to connect (akan timeout/refused)
timeout 3 bash -c '</dev/tcp/172.20.0.1/3306' && echo "CONNECTED" || echo "BLOCKED"

# Expected output: BLOCKED

# Clean up
podman rm -f blocked-container
podman network rm other-network
```

---

## Test 5: UFW Log Analysis

```bash
# Enable detailed logging
sudo ufw logging high

# Check logs
sudo tail -f /var/log/ufw.log

# Filter hanya database-related logs
sudo grep "DPORT=3306" /var/log/ufw.log

# Count allowed vs rejected
sudo grep -c "ALLOW" /var/log/ufw.log
sudo grep -c "REJECT" /var/log/ufw.log

# Export logs ke file untuk analysis
sudo grep "3306" /var/log/ufw.log > /tmp/ufw_db_logs.txt
```

---

## Test 6: Performance Test

```bash
# Cek apakah UFW rules menambah latency
# Sebelum strict rules:
time mysql -h 172.20.0.1 -u podman_user -p myapp -e "SELECT 1;" 

# Sesudah strict rules (seharusnya waktu hampir sama):
time mysql -h 172.20.0.1 -u podman_user -p myapp -e "SELECT 1;"

# Catat hasil keduanya dan compare
```

---

# Troubleshooting

## Issue 1: Container Cannot Connect to Database

### Diagnosis

```bash
# Check UFW rules
sudo ufw status numbered

# Check if rule for Podman network exists
sudo ufw status | grep 172.20

# Check if database is running
sudo systemctl status mariadb
sudo systemctl status postgresql

# Check if database listening on correct address
sudo ss -tulpn | grep 3306
sudo ss -tulpn | grep 5432
```

### Solutions

```bash
# 1. Add missing UFW rule
sudo ufw allow in from 172.20.0.0/16 to 172.20.0.1 port 3306 proto tcp

# 2. Verify database bind address
sudo mysql -e "SELECT @@bind_address;"

# 3. Restart database
sudo systemctl restart mariadb
sudo systemctl restart postgresql

# 4. Check container network
podman inspect container-name --format='{{json .NetworkSettings.Networks}}'

# 5. Test connectivity dari container
podman exec container-name mysql -h 172.20.0.1 -u user -p database -e "SELECT 1;"
```

---

## Issue 2: UFW Rules Not Persistent After Reboot

### Diagnosis

```bash
# Check UFW status after reboot
sudo ufw status

# Check if UFW service enabled
sudo systemctl is-enabled ufw

# Check UFW config
sudo cat /etc/default/ufw
```

### Solutions

```bash
# 1. Enable UFW service
sudo systemctl enable ufw

# 2. Check UFW rules are saved
sudo cat /etc/ufw/rules.d/user.rules

# 3. If rules missing, re-apply them:
sudo ufw allow in from 172.20.0.0/16 to 172.20.0.1 port 3306 proto tcp

# 4. Verify persistence config
sudo cat /etc/default/ufw | grep ENABLED
# Should show: ENABLED=yes

# 5. Reload UFW
sudo ufw reload
```

---

## Issue 3: Cannot Access Database from Localhost Management

### Diagnosis

```bash
# Try localhost access
mysql -h 127.0.0.1 -u root -p

# Check if rule for localhost exists
sudo ufw status | grep 127.0.0.1
```

### Solutions

```bash
# 1. Add localhost rule
sudo ufw allow in from 127.0.0.1 to 127.0.0.1 port 3306 proto tcp

# 2. Or allow socket access (no port needed)
# Socket-based access biasanya bypass UFW

# 3. Verify localhost access works
mysql -u root -p -e "SELECT 1;"
```

---

## Issue 4: Wrong Podman Network CIDR

### Diagnosis

```bash
# Verify actual Podman network CIDR
podman network inspect my-network --format='{{json .Subnets}}'

# Check container IP
podman inspect container-name --format='{{.NetworkSettings.IPAddress}}'
```

### Solutions

```bash
# 1. If network CIDR different, update UFW rules
# Contoh: jika network adalah 192.168.100.0/24 bukan 172.20.0.0/16:

sudo ufw delete allow in from 172.20.0.0/16 to 172.20.0.1 port 3306 proto tcp
sudo ufw allow in from 192.168.100.0/24 to 192.168.100.1 port 3306 proto tcp

# 2. Update database bind address if needed
sudo nano /etc/mysql/mariadb.conf.d/50-server.cnf
# Change: bind-address = 192.168.100.1

sudo systemctl restart mariadb
```

---

## Issue 5: UFW Blocking Valid Traffic

### Diagnosis

```bash
# Check detailed logs
sudo tail -100 /var/log/ufw.log | grep REJECT

# Check rule order (rules are applied top-down)
sudo ufw status numbered

# Check if there's a default DENY rule before ALLOW rule
```

### Solutions

```bash
# 1. Check rule order
sudo ufw status numbered

# 2. If needed, delete and recreate rules in correct order
# Delete incorrect rule:
sudo ufw delete allow in from 172.20.0.0/16 port 3306

# Re-add with correct syntax:
sudo ufw allow in from 172.20.0.0/16 to 172.20.0.1 port 3306 proto tcp

# 3. Make sure REJECT rules are at the end
sudo ufw reject in to any port 3306 proto tcp

# 4. Reload and verify
sudo ufw reload
sudo ufw status numbered
```

---

# Best Practices

## Security Best Practices

### 1. Least Privilege Principle

```bash
# ❌ JANGAN: Allow all traffic
sudo ufw allow from 0.0.0.0/0 to any port 3306

# ✅ LAKUKAN: Allow hanya dari Podman network
sudo ufw allow in from 172.20.0.0/16 to 172.20.0.1 port 3306 proto tcp

# ❌ JANGAN: Allow semua port
sudo ufw allow from 172.20.0.0/16

# ✅ LAKUKAN: Allow specific port saja
sudo ufw allow in from 172.20.0.0/16 to 172.20.0.1 port 3306 proto tcp
```

### 2. Use Specific Source IPs

```bash
# ❌ JANGAN: Allow dari range yang terlalu luas
sudo ufw allow in from 0.0.0.0/0 port 3306

# ✅ LAKUKAN: Allow dari Podman network saja
sudo ufw allow in from 172.20.0.0/16 port 3306

# Jika hanya 1-2 container: allow specific IPs
sudo ufw allow in from 172.20.0.2,172.20.0.3 port 3306
```

### 3. Use Explicit REJECT, Not Just Deny

```bash
# ❌ Rely on default deny:
# (tanpa rule apapun, semua akan di-deny tapi tidak ter-log)

# ✅ Explicit REJECT dengan logging:
sudo ufw reject in to any port 3306 proto tcp
sudo ufw logging high
```

### 4. Rotate Database Credentials Regularly

```bash
# Container user password
ALTER USER 'podman_user'@'172.20.%' IDENTIFIED BY 'new_secure_password_here';

# Update container environment variables
podman run ... -e MYSQL_PASSWORD=new_secure_password_here ...
```

### 5. Monitor and Audit

```bash
# Setup regular log review
sudo tail -100 /var/log/ufw.log

# Setup alerts for rejected connection attempts
# (integrate dengan monitoring system seperti Prometheus, Grafana)

# Regular security audit
sudo ufw status verbose
sudo iptables -L -n
sudo netstat -tulpn
```

---

## Operational Best Practices

### 1. Document All Rules

```bash
# Create UFW rules documentation
cat > /etc/ufw/UFW_RULES_DOCUMENTATION.md << 'EOF'
# UFW Rules Documentation

## Database Access Rules
- Rule 1: Allow MySQL from Podman network (172.20.0.0/16)
  Command: sudo ufw allow in from 172.20.0.0/16 to 172.20.0.1 port 3306 proto tcp
  Reason: Container database access
  Added: 2024-01-10
  By: DevOps Team

- Rule 2: Reject all other MySQL access
  Command: sudo ufw reject in to any port 3306 proto tcp
  Reason: Security - ensure only Podman can access
  Added: 2024-01-10
  By: DevOps Team
EOF

# View documentation
cat /etc/ufw/UFW_RULES_DOCUMENTATION.md
```

### 2. Version Control Rules

```bash
# Backup rules to git
sudo cp /etc/ufw /tmp/ufw_config_backup
cd /tmp/ufw_config_backup
git init
git add .
git commit -m "UFW initial config snapshot"

# Track changes
git log --oneline
git diff HEAD~1
```

### 3. Test Before Applying

```bash
# Create test VM/container untuk test rules sebelum apply ke production
# ...atau gunakan UFW dry-run:

# List rules yang akan di-add (tanpa apply)
sudo ufw show added

# Untuk revert semua rules:
sudo ufw reset

# Atau revert individual rule:
sudo ufw delete allow in from 172.20.0.0/16 port 3306
```

### 4. Setup Alerts

```bash
# Monitor UFW logs dengan auditd
sudo apt-get install auditd -y

# Add audit rule untuk UFW
sudo auditctl -w /var/log/ufw.log -p wa -k ufw_changes

# View audit logs
sudo ausearch -k ufw_changes
```

### 5. Regular Testing Schedule

```bash
# Create weekly test script
cat > /usr/local/bin/test-podman-db-access.sh << 'EOF'
#!/bin/bash
# Test Podman → Database connectivity weekly

DATE=$(date +%Y-%m-%d)
LOG="/var/log/podman-db-test-$DATE.log"

echo "Testing Podman → Database connectivity" > $LOG

# Test container
podman run --rm \
    --network my-network \
    mysql:8.0 \
    mysql -h 172.20.0.1 -u podman_user -p -e "SELECT 1;" >> $LOG 2>&1

if [ $? -eq 0 ]; then
    echo "✓ Test PASSED on $DATE" >> $LOG
else
    echo "✗ Test FAILED on $DATE" >> $LOG
    # Send alert
    mail -s "Podman DB Test Failed" admin@example.com < $LOG
fi
EOF

# Setup cron
sudo crontab -e
# Add: 0 2 * * 0 /usr/local/bin/test-podman-db-access.sh
```

---

## Network Isolation Best Practices

### 1. Use Podman User Network untuk Isolation

```bash
# Buat network khusus untuk database access
podman network create \
    --driver bridge \
    --subnet 172.20.0.0/16 \
    --gateway 172.20.0.1 \
    database-network

# Atau dengan custom options
podman network create \
    --driver bridge \
    --subnet 172.20.0.0/16 \
    --gateway 172.20.0.1 \
    --opt "com.docker.network.bridge.name=podman-db" \
    database-network

# List networks
podman network ls

# Inspect network
podman network inspect database-network
```

### 2. Separate Networks for Different Services

```bash
# Database network
podman network create database-network --subnet 172.20.0.0/16

# App network
podman network create app-network --subnet 172.21.0.0/16

# Cache network
podman network create cache-network --subnet 172.22.0.0/16

# UFW rules untuk setiap network:
# Database → Host
sudo ufw allow in from 172.20.0.0/16 to 172.20.0.1 port 3306

# Cache → Host (Redis)
sudo ufw allow in from 172.22.0.0/16 to 172.22.0.1 port 6379
```

### 3. Network Policies dengan Podman

```bash
# View network policies (jika menggunakan CNI plugins)
podman network inspect database-network --format='{{json .Options}}'

# Setup advanced network options
podman run \
    --network database-network \
    --network-alias db-app \
    --ip 172.20.0.10 \
    app-container
```

### 4. Monitor Network Traffic

```bash
# Capture traffic ke port 3306
sudo tcpdump -i any -n port 3306 -w /tmp/db-traffic.pcap

# Analyze packets
sudo tcpdump -r /tmp/db-traffic.pcap

# Real-time monitoring
sudo nethogs

# Monitor dengan ss
watch -n 1 'ss -tulpn | grep 3306'
```

---

## Summary Checklist

```bash
# [ ] Database Native Configuration
# [ ] MariaDB/PostgreSQL bind-address set correctly
# [ ] Database user created dengan host pattern (172.20.%)
# [ ] Test database connection dari host

# [ ] Podman Network Identification
# [ ] Identify network name: podman network ls
# [ ] Find network CIDR: podman network inspect
# [ ] Verify container IP: podman run && podman inspect

# [ ] UFW Configuration
# [ ] UFW installed: apt-get install ufw
# [ ] UFW enabled: ufw enable
# [ ] Default policy set: ufw default deny/allow
# [ ] Database rules added: ufw allow from 172.20.0.0/16

# [ ] Persistence Testing
# [ ] Rules saved: ufw status
# [ ] Test reboot: reboot && ufw status
# [ ] Systemd timer set: systemctl enable podman-firewall-repair.timer

# [ ] Security Verification
# [ ] UFW rules are specific (not 0.0.0.0/0)
# [ ] Database only accessible from Podman network
# [ ] Testing script created
# [ ] Logging enabled: ufw logging high

# [ ] Documentation & Monitoring
# [ ] UFW rules documented
# [ ] Backup script created
# [ ] Monitoring/alerting setup
# [ ] Testing schedule defined

# [ ] Production Deployment
# [ ] All tests pass
# [ ] Rules persisted across reboot
# [ ] Monitoring alerts working
# [ ] Team trained on procedures
```

---

## Quick Command Reference

```bash
# UFW Management
ufw enable                                    # Enable UFW
ufw disable                                   # Disable UFW
ufw status verbose                            # Show detailed status
ufw status numbered                           # Show rules dengan line numbers
ufw allow in ssh                              # Allow SSH
ufw allow in from 172.20.0.0/16 port 3306    # Allow Podman network

# Database
sudo systemctl restart mariadb                # Restart MySQL
sudo systemctl restart postgresql             # Restart PostgreSQL
mysql -h 172.20.0.1 -u user -p database      # Test MySQL connection
psql -h 172.20.0.1 -U user -d database       # Test PostgreSQL connection

# Podman
podman network ls                             # List networks
podman network inspect network-name           # Show network details
podman run -d --network my-net container     # Run with specific network

# Verification
sudo netstat -tulpn | grep 3306              # Check port listening
sudo ufw show added                           # Show added rules
sudo tail -f /var/log/ufw.log                 # Monitor UFW logs
```

---

Panduan ini memberikan keamanan maksimal dengan UFW rules yang spesifik dan persistent untuk akses database dari Podman container.
