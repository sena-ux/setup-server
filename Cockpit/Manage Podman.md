# 🐳 Podman Management Guide: CLI & Cockpit Web UI
## DevOps Daily Operations - Cheatsheet & Visual Tutorial

---

## 📋 Daftar Isi
1. [Custom Network Management](#custom-network-management)
2. [Image Building & Management](#image-building--management)
3. [Container Deployment](#container-deployment)
4. [Performance Monitoring](#performance-monitoring)
5. [Cockpit Integration & Systemd Services](#cockpit-integration--systemd-services)
6. [Advanced CLI Cheatsheet](#advanced-cli-cheatsheet)
7. [Troubleshooting](#troubleshooting)

---

## 🌐 Custom Network Management

### Understanding Podman Networks

Podman supports multiple network drivers:
- **bridge** (default) - Container berkomunikasi via virtual bridge
- **macvlan** - Container mendapat MAC address sendiri
- **ipvlan** - Container dengan IP address terpisah
- **host** - Container menggunakan host network directly
- **none** - No network connectivity

---

### 1. Create Custom Network (CLI)

#### A. Create Bridge Network (Recommended)
```bash
# Basic network creation
podman network create my-network

# With custom subnet
podman network create \
  --subnet 10.0.9.0/24 \
  --gateway 10.0.9.1 \
  my-network

# With DNS enabled
podman network create \
  --subnet 10.0.9.0/24 \
  --dns 8.8.8.8 \
  --dns 8.8.4.4 \
  my-network

# Full configuration example
podman network create \
  --subnet 10.0.9.0/24 \
  --gateway 10.0.9.1 \
  --opt="com.docker.network.driver.mtu=1500" \
  --label=env=prod \
  --label=team=backend \
  prod-network
```

#### B. Create Macvlan Network (untuk bridging ke physical interface)
```bash
# Macvlan network
podman network create \
  -d macvlan \
  --subnet 192.168.1.0/24 \
  --gateway 192.168.1.1 \
  -o parent=eth0 \
  macvlan-network
```

---

### 2. List & Inspect Networks

```bash
# List all networks
podman network ls

# Detailed information
podman network inspect my-network

# Pretty format
podman network ls --format "table {{.Name}}\t{{.Driver}}\t{{.Created}}"

# Filter networks
podman network ls --filter label=env=prod

# Get specific network info
podman network inspect my-network | jq '.'
```

---

### 3. Connect Container ke Network

```bash
# Run container dengan custom network
podman run -d \
  --name web-app \
  --network my-network \
  -p 8080:80 \
  nginx:latest

# Run dengan static IP dalam network
podman run -d \
  --name db-server \
  --network my-network \
  --ip 10.0.9.100 \
  postgres:15

# Connect existing container ke network
podman network connect my-network existing-container

# Disconnect container dari network
podman network disconnect my-network existing-container

# Connect ke multiple networks
podman run -d \
  --name multi-net-app \
  --network network1 \
  --network network2 \
  -p 8080:80 \
  my-image:latest
```

---

### 4. Delete & Cleanup Networks

```bash
# Remove single network
podman network rm my-network

# Remove unused networks
podman network prune

# Remove dengan force (jika ada containers terhubung)
podman network rm -f my-network

# Remove multiple networks
podman network rm network1 network2 network3

# Remove all networks (DANGEROUS!)
podman network prune -f
```

---

### 5. Advanced Network Operations

```bash
# Export network configuration
podman network inspect my-network > network-config.json

# Test DNS resolution antar container
podman run --rm --network my-network busybox nslookup web-app

# Test connectivity antar container
podman run --rm --network my-network \
  busybox ping -c 3 db-server

# View network statistics
podman network stats

# Monitor network usage
watch podman network stats
```

---

## 🏗️ Image Building & Management

### 1. Build Images from Dockerfile/Containerfile

#### A. Basic Build
```bash
# Build dari current directory Dockerfile
podman build -t my-app:1.0 .

# Build dengan custom Containerfile
podman build -f custom.Containerfile -t my-app:1.0 .

# Build dengan build arguments
podman build \
  --build-arg VERSION=1.0 \
  --build-arg ENV=prod \
  -t my-app:1.0 \
  .
```

#### B. Advanced Build Options
```bash
# Multi-stage build dengan target stage
podman build \
  --target production \
  -t my-app:latest \
  .

# Build dengan cache control
podman build --no-cache -t my-app:latest .

# Build dengan custom registry
podman build \
  -t registry.example.com/my-app:1.0 \
  .

# Build dengan multiple tags
podman build \
  -t my-app:latest \
  -t my-app:1.0 \
  -t my-app:stable \
  .

# Build dengan resource limits
podman build \
  --memory 2g \
  --cpus 2 \
  -t my-app:latest \
  .

# Build dan push langsung ke registry
podman build \
  -t docker.io/myuser/my-app:latest \
  . && \
  podman push docker.io/myuser/my-app:latest
```

#### C. Example Containerfile
```dockerfile
# Save sebagai Containerfile
FROM alpine:3.18

ARG VERSION=latest

RUN apk add --no-cache \
    python3 \
    py3-pip \
    curl

WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

USER nobody

ENTRYPOINT ["python3", "app.py"]
```

Build command:
```bash
podman build -t my-app:${VERSION} .
```

---

### 2. Download & Manage Images

```bash
# Search image
podman search nginx
podman search --filter stars=10 nginx

# Pull image
podman pull nginx:latest
podman pull docker.io/library/nginx:1.25

# Pull dari custom registry
podman pull myregistry.com/myapp:v1.0

# Pull dengan signature verification
podman pull --signature-policy=/etc/containers/policy.json nginx

# List local images
podman images
podman images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"

# Filter images
podman images --filter="before=nginx:latest"
podman images --filter="dangling=true"

# Tag image
podman tag nginx:latest myregistry.com/my-nginx:1.0

# Push image ke registry
podman push myregistry.com/my-nginx:1.0

# Save image ke file
podman save nginx:latest -o nginx.tar
podman save nginx:latest | gzip > nginx.tar.gz

# Load image dari file
podman load -i nginx.tar
gunzip -c nginx.tar.gz | podman load

# Remove image
podman rmi nginx:latest

# Remove dangling images
podman image prune
podman image prune -a  # Remove unused images
podman image prune -a --filter="until=24h"  # Remove images older than 24h
```

---

### 3. Cleanup & Prune Operations

```bash
# Remove dangling images (tidak ada container yang menggunakannya)
podman image prune
podman image prune -a

# Remove dangling volumes
podman volume prune

# Remove exited containers
podman container prune
podman container prune --filter="until=168h"  # Older than 7 days

# Remove dangling networks
podman network prune

# Full system cleanup (ALL dangling images, containers, volumes, networks)
podman system prune

# Aggressive cleanup (remove ALL unused resources)
podman system prune -a

# With specific filters
podman system prune -a --filter="until=72h"

# Check storage usage before cleanup
podman system df

# Check detailed breakdown
podman system df -v
```

---

### 4. Image Inspection & Security

```bash
# Inspect image layers
podman inspect nginx:latest | jq '.'

# View image history
podman history nginx:latest

# Scan image vulnerabilities (dengan Trivy)
trivy image nginx:latest

# Scan dengan severity level
trivy image --severity HIGH,CRITICAL nginx:latest

# Get image digest/SHA
podman inspect --format='{{.Id}}' nginx:latest

# Compare images
podman inspect nginx:latest nginx:1.25 | jq '.'
```

---

## 📦 Container Deployment

### 1. Deploy Container dengan Full Configuration

#### A. Basic Deployment
```bash
# Simple HTTP server
podman run -d \
  --name web-server \
  -p 8080:80 \
  nginx:latest
```

#### B. Production-Grade Deployment
```bash
# Complete configuration example
podman run -d \
  --name my-app \
  \
  # Network configuration
  --network my-network \
  --ip 10.0.9.50 \
  -p 8080:8080 \
  \
  # Volume mounting
  -v my-app-data:/app/data:rw \
  -v /home/admin/configs:/app/config:ro \
  -v /etc/localtime:/etc/localtime:ro \
  \
  # Restart policy
  --restart unless-stopped \
  \
  # Resource limits
  --memory 1g \
  --memory-swap 1.5g \
  --cpus 1 \
  --pids-limit 200 \
  \
  # Environment variables
  -e APP_ENV=production \
  -e LOG_LEVEL=info \
  -e DB_HOST=db-server \
  -e DB_PORT=5432 \
  \
  # Security options
  --security-opt=no-new-privileges:true \
  --cap-drop=ALL \
  --cap-add=NET_BIND_SERVICE \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=100m \
  -u 1000:1000 \
  \
  # Health check
  --health-cmd='curl -f http://localhost:8080/health || exit 1' \
  --health-interval=30s \
  --health-timeout=10s \
  --health-start-period=5s \
  --health-retries=3 \
  \
  # Labels & metadata
  --label app=myapp \
  --label version=1.0 \
  --label team=backend \
  \
  # Logging
  --log-driver journald \
  --log-opt labels=app,version \
  \
  my-image:latest
```

---

### 2. Port Configuration

```bash
# Single port mapping
podman run -d -p 8080:80 nginx:latest

# Multiple port mappings
podman run -d \
  -p 8080:80 \
  -p 8443:443 \
  nginx:latest

# Bind ke specific IP
podman run -d \
  -p 127.0.0.1:8080:80 \
  nginx:latest

# Expose port range
podman run -d \
  -p 8000-8100:8000-8100 \
  my-service:latest

# UDP port
podman run -d \
  -p 53:53/udp \
  coredns:latest

# Mix TCP & UDP
podman run -d \
  -p 5353:5353/tcp \
  -p 5353:5353/udp \
  my-dns:latest
```

---

### 3. Volume Management

```bash
# Named volume
podman run -d \
  -v app-data:/app/data \
  my-app:latest

# Bind mount (direct filesystem)
podman run -d \
  -v /home/admin/app-data:/app/data:rw \
  my-app:latest

# Read-only mount
podman run -d \
  -v /home/admin/config:/app/config:ro \
  my-app:latest

# Temporary filesystem
podman run -d \
  --tmpfs /tmp:rw,noexec,nosuid,size=500m \
  my-app:latest

# Create volume dengan options
podman volume create \
  --opt=type=tmpfs \
  --opt=device=tmpfs \
  --opt=o=size=1g,noexec,nosuid \
  cache-volume

podman run -d \
  -v cache-volume:/cache \
  my-app:latest

# List volumes
podman volume ls

# Inspect volume
podman volume inspect app-data

# Cleanup volumes
podman volume prune
```

---

### 4. Restart Policy

```bash
# No automatic restart
podman run -d \
  --restart no \
  my-app:latest

# Always restart (unless explicitly stopped)
podman run -d \
  --restart always \
  my-app:latest

# Restart unless stopped
podman run -d \
  --restart unless-stopped \
  my-app:latest

# Restart on failure (max 5 attempts)
podman run -d \
  --restart on-failure:5 \
  my-app:latest

# Restart on failure dengan delay
podman run -d \
  --restart on-failure:5 \
  --restart-timeout=30 \
  my-app:latest
```

---

### 5. Network Integration

```bash
# Run dengan custom network
podman run -d \
  --network my-network \
  --name backend-api \
  my-api:latest

# Connect dengan fixed IP
podman run -d \
  --network my-network \
  --ip 10.0.9.100 \
  --name database \
  postgres:15

# DNS alias (hostname resolution)
podman run -d \
  --network my-network \
  --network-alias db \
  --network-alias database \
  postgres:15

# Inter-container communication test
podman run --rm \
  --network my-network \
  busybox ping -c 2 database
```

---

### 6. Environment Variables & Config

```bash
# Single environment variable
podman run -d \
  -e APP_ENV=production \
  my-app:latest

# Multiple environment variables
podman run -d \
  -e APP_ENV=production \
  -e LOG_LEVEL=debug \
  -e DB_HOST=db.example.com \
  -e DB_USER=admin \
  -e DB_PASS=secret \
  my-app:latest

# Load from file
podman run -d \
  --env-file /home/admin/.env \
  my-app:latest

# Override default values
podman run -d \
  --env-file /home/admin/.env.default \
  -e DB_PASS=new-password \
  my-app:latest
```

---

## 📊 Performance Monitoring

### 1. CPU & Memory Monitoring (CLI)

```bash
# Real-time container stats
podman stats

# Specific container
podman stats my-app

# Watch stats continuously
watch podman stats

# Output in table format dengan detail
podman stats --format "table {{.Container}}\t{{.CPUPercent}}\t{{.MemUsage}}\t{{.NetIO}}"

# Non-streaming (one-time snapshot)
podman stats --no-stream

# Filter containers
podman stats --filter "label=app=myapp"
```

**Output Format Penjelasan:**
```
CONTAINER ID  NAME       CPU %  MEM USAGE / LIMIT  MEM %  NET I/O  BLOCK I/O
abc123        my-app     2.5%   256 MB / 1 GB      25.6%  100KB/MB 50MB/10MB
```

---

### 2. Disk I/O Monitoring

```bash
# Check container filesystem usage
podman exec my-app df -h

# Monitor disk I/O dengan blkio stats
podman stats --format "table {{.Container}}\t{{.BlockIO}}"

# Check volume usage
podman system df

# Detailed volume breakdown
podman system df -v

# Container-specific disk usage
podman ps -a --format "{{.Names}}" | while read name; do
  echo "=== $name ==="
  podman exec $name du -sh /app 2>/dev/null || echo "N/A"
done
```

---

### 3. Process Monitoring

```bash
# View running processes dalam container
podman top my-app

# Detailed process info
podman top my-app -eo pid,user,%cpu,%mem,comm

# Monitor process tree
podman top my-app forest

# Check limit processes
podman inspect my-app | grep PidsLimit
```

---

### 4. Real-time Logging

```bash
# Follow logs (like tail -f)
podman logs -f my-app

# Last 100 lines
podman logs --tail 100 my-app

# Last 30 minutes
podman logs --since 30m my-app

# Timestamp included
podman logs -t my-app

# Specific date range
podman logs --since 2024-06-16T10:00:00 --until 2024-06-16T11:00:00 my-app

# Show both stdout dan stderr
podman logs my-app 2>&1

# Follow dengan tail
podman logs -f --tail 50 my-app

# Watch logs dari multiple containers
podman logs -f my-app db-server
```

---

### 5. Advanced Monitoring

```bash
# Monitor dengan journalctl (systemd logging)
journalctl -u podman -f

# Monitor specific container logs via journalctl
sudo journalctl CONTAINER_NAME=my-app -f

# Network statistics
podman run --rm \
  --network container:my-app \
  busybox netstat -an

# Monitor dengan custom interval
while true; do
  clear
  echo "=== Podman Stats @ $(date) ==="
  podman stats --no-stream
  sleep 5
done

# Export stats ke CSV untuk analysis
podman stats --format "{{.Container}},{{.CPUPercent}},{{.MemUsage}}" \
  | tee -a stats.csv
```

---

### 6. Health Check Monitoring

```bash
# View health status
podman inspect --format='{{json .State.Health.Status}}' my-app

# Detailed health info
podman inspect my-app | jq '.[] | {Name: .Name, Health: .State.Health}'

# Monitor health continuously
watch -n 5 'podman inspect my-app | jq ".[].State.Health"'

# Get last health check output
podman inspect my-app | jq '.[] | .State.Health.Log[-1]'
```

---

## 🖥️ Cockpit Integration & Systemd Services

### 1. Akses Cockpit Web UI

```bash
# Access via browser
https://your-server-ip:9090

# Default port: 9090
# Login dengan credentials server Anda (root atau user dengan sudo)
```

---

### 2. Navigasi Cockpit untuk Podman Management

#### **A. Main Dashboard**
```
Cockpit Home Screen
├── System Information (CPU, Memory, Disk)
├── Services (View status of podman.service)
├── Logs (Real-time system logs)
└── Software Updates
```

#### **B. Containers Section (via Cockpit Plugin)**
```
Cockpit > Podman (or Containers)
├── Images
│   ├── List all images
│   ├── Pull image
│   ├── Build from Dockerfile
│   ├── Remove image
│   └── Image details
├── Containers
│   ├── List running containers
│   ├── Container details
│   ├── Create new container
│   ├── Start/Stop/Restart
│   ├── View logs
│   └── Execute command
└── Networks
    ├── List networks
    ├── Create network
    ├── View network details
    └── Delete network
```

---

### 3. Create Container via Cockpit UI

**Step-by-Step Visual Guide:**

```
1. Buka Cockpit > Containers

2. Klik "Create Container" button

3. Fill in Container Details:
   ┌─────────────────────────────────┐
   │ Container Name:     web-server   │
   │ Image:              nginx:latest │
   │ Command:            (optional)   │
   │ Working Directory:   /app        │
   └─────────────────────────────────┘

4. Port Configuration:
   ┌─────────────────────────────────┐
   │ Port Mapping:                   │
   │ Container Port:  80             │
   │ Host Port:       8080           │
   │ [Add Port Mapping]              │
   └─────────────────────────────────┘

5. Volume Configuration:
   ┌─────────────────────────────────┐
   │ Volume Mounting:                │
   │ Container Path:  /var/www/html  │
   │ Host Path:       /home/admin/.. │
   │ Read-only:       ☐              │
   │ [Add Volume]                    │
   └─────────────────────────────────┘

6. Environment Variables:
   ┌─────────────────────────────────┐
   │ APP_ENV=production              │
   │ LOG_LEVEL=info                  │
   │ [Add Variable]                  │
   └─────────────────────────────────┘

7. Advanced Settings:
   ┌─────────────────────────────────┐
   │ Restart Policy:    unless-stopped│
   │ Memory Limit:      1 GB          │
   │ CPU Limit:         1 CPU         │
   │ [More Options]                  │
   └─────────────────────────────────┘

8. Klik "Create Container"
```

---

### 4. Container Management via Cockpit

#### **View Running Containers**
```
Cockpit > Containers

Container List:
├─ web-server (Running)
│  ├─ Image: nginx:latest
│  ├─ Status: Running (2 days)
│  ├─ Ports: 8080:80
│  ├─ Actions: [Start] [Stop] [Restart] [Delete]
│  └─ [View Logs] [Execute]
│
├─ db-server (Stopped)
│  ├─ Image: postgres:15
│  ├─ Status: Exited (1 day ago)
│  └─ Actions: [Start] [Stop] [Restart] [Delete]
└─ ...
```

#### **Container Details & Logs**

```
Click Container > Details:

┌─────────────────────────────────────────┐
│ Container: web-server                   │
├─────────────────────────────────────────┤
│ ID:          abc123def456               │
│ Image:       nginx:latest               │
│ Status:      Running (2 days 5 hours)   │
│ Ports:       8080:80, 8443:443         │
│ Network:     my-network (10.0.9.50)     │
│ Memory:      128 MB / 1 GB              │
│ CPU:         2.5%                       │
├─────────────────────────────────────────┤
│ [View Logs] [Restart] [Stop] [Delete]  │
│ [Inspect] [Execute Shell]               │
└─────────────────────────────────────────┘

Logs Section:
┌─────────────────────────────────────────┐
│ Logs for: web-server                    │
├─────────────────────────────────────────┤
│ 2024-06-16 10:23:45 Starting...         │
│ 2024-06-16 10:23:46 Listening on :80   │
│ 2024-06-16 10:24:12 GET / HTTP/1.1 200│
│ 2024-06-16 10:24:15 GET /api HTTP/1.1  │
│ ...                                     │
│ [Refresh] [Follow Logs] [Clear]         │
└─────────────────────────────────────────┘
```

---

### 5. Convert Container ke Systemd Service

#### **A. CLI Method - Generate Systemd Unit File**

```bash
# Generate systemd unit dari running container
podman generate systemd --name my-app > /home/admin/.config/systemd/user/my-app.service

# Verifikasi file yang dibuat
cat /home/admin/.config/systemd/user/my-app.service
```

**Output Example:**
```ini
[Unit]
Description=Podman container-my-app.service
Documentation=man:podman-generate-systemd(1)
Wants=network-online.target
After=network-online.target
RequiresMountsFor=%t/containers

[Service]
Environment="PODMAN_SYSTEMD_UNIT=%n"
Restart=on-failure
ExecStart=/usr/bin/podman start my-app
ExecStop=/usr/bin/podman stop -t 10 my-app
ExecStopPost=/usr/bin/podman stop -t 10 my-app
Type=forking
PIDFile=%t/containers/my-app.pid

[Install]
WantedBy=default.target
```

#### **B. Enable Service untuk Auto-Start**

```bash
# Reload systemd daemon
systemctl --user daemon-reload

# Enable service
systemctl --user enable my-app.service

# Start service
systemctl --user start my-app.service

# Check status
systemctl --user status my-app.service

# View logs
journalctl --user -u my-app.service -f

# Stop service
systemctl --user stop my-app.service
```

---

### 6. Generate Systemd untuk Rootless Podman (Advanced)

```bash
# Generate dengan custom options
podman generate systemd \
  --name my-app \
  --new \
  --restart-policy=unless-stopped \
  > /home/admin/.config/systemd/user/my-app.service

# Untuk system-wide (memerlukan sudo)
sudo podman generate systemd \
  --name my-app \
  > /etc/systemd/system/my-app.service

# Enable lingering agar systemd user services jalan tanpa login
sudo loginctl enable-linger admin

# Verify
sudo loginctl show-user admin | grep Linger
```

---

### 7. Cockpit UI untuk Systemd Services

#### **Navigate to Cockpit Services**

```
Cockpit > Services

Services List:
├─ my-app.service
│  ├─ Status: ✓ Running (auto-start enabled)
│  ├─ Process ID: 12345
│  ├─ Memory: 256 MB
│  ├─ Actions: [Start] [Stop] [Restart] [Enable] [Disable]
│  └─ [View Logs]
│
├─ cockpit.service
│  ├─ Status: ✓ Running
│  └─ Actions: ...
└─ podman.service
   └─ Status: ✓ Running
```

#### **Start/Stop Service via Cockpit**

```
Click Service (e.g., my-app.service):

┌────────────────────────────────────┐
│ Service: my-app.service            │
├────────────────────────────────────┤
│ Status: ✓ Running                  │
│ Started: 6/16 10:23 AM             │
│ Enabled: Yes (auto-start)          │
│                                    │
│ [Restart] [Stop] [Disable]         │
│                                    │
│ Logs:                              │
│ Jun 16 10:23:45 systemd[1234]:     │
│   Started Podman container...      │
│ Jun 16 10:23:46 podman[5678]:      │
│   Container started successfully   │
│ ...                                │
└────────────────────────────────────┘
```

---

### 8. Enable/Disable Service Persistence

#### **A. Make Service Auto-Start pada Boot**

```bash
# Check current status
systemctl --user is-enabled my-app.service

# Enable auto-start
systemctl --user enable my-app.service

# Verify
systemctl --user is-enabled my-app.service  # output: enabled

# Status overview
systemctl --user status my-app.service
```

#### **B. Cockpit UI untuk Persistence**

```
Services > my-app.service

┌────────────────────────────────┐
│ ☑ Start on boot               │ <- Toggle ini untuk auto-start
│ ☑ Service is running          │
└────────────────────────────────┘
```

---

### 9. View Logs di Cockpit

#### **Method 1: Via Services**

```
Cockpit > Services > my-app.service > [Logs tab]

┌──────────────────────────────────────────┐
│ Logs for: my-app.service                 │
├──────────────────────────────────────────┤
│ Time               Message                │
├──────────────────────────────────────────┤
│ Jun 16 10:23:45    Started service       │
│ Jun 16 10:24:10    Container ready       │
│ Jun 16 10:25:33    Connection received   │
│ Jun 16 10:26:01    Request processed     │
│                                          │
│ [Refresh] [Follow] [Clear] [More...]     │
└──────────────────────────────────────────┘
```

#### **Method 2: Via Logs Section**

```
Cockpit > Logs

┌──────────────────────────────────────────┐
│ Filter:  [Search box]                    │
│ Service: [Dropdown - select my-app]      │
│ Lines:   [Show last: 50 ▾]               │
├──────────────────────────────────────────┤
│ Complete log output with timestamps      │
│ ...                                      │
└──────────────────────────────────────────┘
```

#### **Method 3: CLI (More Control)**

```bash
# Follow logs in real-time
journalctl --user -u my-app.service -f

# Last 50 lines
journalctl --user -u my-app.service -n 50

# Since specific time
journalctl --user -u my-app.service --since "2024-06-16 10:00:00"

# Until specific time
journalctl --user -u my-app.service --until "2024-06-16 12:00:00"

# With priority level
journalctl --user -u my-app.service -p err

# Output in JSON
journalctl --user -u my-app.service -o json
```

---

### 10. Complete Workflow: Container → Systemd → Auto-Start

#### **Step-by-Step Full Integration**

```bash
# STEP 1: Create container
podman run -d \
  --name my-app \
  --network my-network \
  -p 8080:8080 \
  -v app-data:/app/data \
  -e APP_ENV=production \
  --restart unless-stopped \
  my-image:latest

# STEP 2: Verify container running
podman ps | grep my-app

# STEP 3: Generate systemd unit
podman generate systemd \
  --name my-app \
  > /home/admin/.config/systemd/user/my-app.service

# STEP 4: Reload systemd
systemctl --user daemon-reload

# STEP 5: Enable auto-start
systemctl --user enable my-app.service

# STEP 6: Start service
systemctl --user start my-app.service

# STEP 7: Verify service running
systemctl --user status my-app.service

# STEP 8: View logs
journalctl --user -u my-app.service -f

# STEP 9: Access via Cockpit
# Open browser > https://localhost:9090
# Navigate to Services > my-app.service
# Verify "Start on boot" is enabled

# STEP 10: Test reboot
sudo reboot

# After reboot, verify container auto-started
podman ps | grep my-app
systemctl --user status my-app.service
```

---

### 11. Troubleshooting Systemd Integration

#### **Service Won't Start**

```bash
# Check systemd unit syntax
systemctl --user validate my-app.service

# View detailed error logs
journalctl --user -u my-app.service -e

# Check if container is already running
podman ps -a | grep my-app

# If container exists, remove it first
podman stop my-app
podman rm my-app

# Then recreate and generate systemd
podman run -d --name my-app my-image:latest
podman generate systemd --name my-app \
  > ~/.config/systemd/user/my-app.service
systemctl --user daemon-reload
systemctl --user start my-app.service
```

#### **Lingering Not Enabled**

```bash
# Check current status
loginctl show-user admin | grep Linger

# Enable lingering
sudo loginctl enable-linger admin

# Verify
loginctl show-user admin | grep Linger
# Output: Linger=yes
```

#### **Service Starts but Container Exits**

```bash
# Check container logs
podman logs my-app

# Run container manually to see error
podman run -it my-image:latest /bin/bash

# Check if image is correct
podman images | grep my-image
```

---

## 🔧 Advanced CLI Cheatsheet

### Quick Reference Commands

```bash
# CONTAINER BASICS
podman ps                               # List running containers
podman ps -a                            # List all containers
podman run -d -p 8080:80 nginx         # Run detached with port mapping
podman exec -it container-name bash    # Execute shell in container
podman logs -f container-name          # Follow logs
podman stop container-name             # Stop container gracefully
podman kill container-name             # Force kill container
podman rm container-name               # Remove stopped container
podman restart container-name          # Restart container

# IMAGE OPERATIONS
podman images                           # List local images
podman pull image:tag                   # Download image
podman build -t myimage:1.0 .          # Build from Dockerfile
podman rmi image:tag                    # Remove image
podman save image:tag -o image.tar      # Export image
podman load -i image.tar                # Import image

# NETWORK MANAGEMENT
podman network ls                       # List networks
podman network create mynet             # Create network
podman network rm mynet                 # Remove network
podman network connect mynet container  # Connect container to network

# VOLUME OPERATIONS
podman volume ls                        # List volumes
podman volume create myvolume           # Create volume
podman volume rm myvolume               # Remove volume
podman volume inspect myvolume          # View volume details

# MONITORING & STATS
podman stats                            # Real-time stats
podman stats --no-stream                # One-time snapshot
podman top container-name               # View processes
podman inspect container-name           # Detailed information

# CLEANUP
podman image prune                      # Remove dangling images
podman container prune                  # Remove exited containers
podman volume prune                     # Remove unused volumes
podman network prune                    # Remove dangling networks
podman system prune -a                  # Full cleanup
podman system df                        # Storage usage

# SYSTEMD INTEGRATION
podman generate systemd --name container > unit-file.service
systemctl --user daemon-reload
systemctl --user enable container.service
systemctl --user start container.service
journalctl --user -u container.service -f
```

---

## 🐛 Troubleshooting

### Common Issues & Solutions

#### 1. Container Permission Denied (Rootless Mode)

**Error**: `permission denied while trying to connect to Docker daemon`

```bash
# Solution 1: Enable lingering
sudo loginctl enable-linger admin

# Solution 2: Set XDG_RUNTIME_DIR
export XDG_RUNTIME_DIR=/run/user/$(id -u)

# Solution 3: Check subuid/subgid
cat /etc/subuid | grep admin
cat /etc/subgid | grep admin
```

#### 2. Port Already in Use

**Error**: `Error: bind: address already in use`

```bash
# Find process using port
sudo lsof -i :8080
# atau
sudo netstat -tlnp | grep 8080

# Kill process
sudo kill -9 <PID>

# Or use different port
podman run -p 9080:80 nginx
```

#### 3. Network Connectivity Issues

**Error**: `network unreachable` atau `cannot connect to container`

```bash
# Verify network exists
podman network ls

# Recreate network
podman network rm problematic-net
podman network create --subnet 10.0.9.0/24 problematic-net

# Reconnect containers
podman network disconnect problematic-net container-name
podman network connect problematic-net container-name

# Test DNS resolution
podman run --rm --network problematic-net \
  busybox nslookup container-name
```

#### 4. Volume Mount Permission Denied

**Error**: `Permission denied` when accessing volume

```bash
# Check volume permissions
podman volume inspect myvolume

# For bind mounts, check ownership
ls -la /home/admin/app-data

# Fix permissions
sudo chown -R 1000:1000 /home/admin/app-data

# Or run container with correct user
podman run -u 1000:1000 -v /home/admin/app-data:/app ...
```

#### 5. Systemd Service Won't Auto-Start

**Error**: Service enabled but container not starting after reboot

```bash
# Check if lingering is enabled
loginctl show-user admin | grep Linger

# Enable if needed
sudo loginctl enable-linger admin

# Verify service file
cat ~/.config/systemd/user/my-app.service

# Check for ExecStart path errors
systemctl --user validate my-app.service

# Manually test
systemctl --user restart my-app.service
podman ps | grep my-app
```

#### 6. Cockpit Can't Connect to Podman

**Error**: "Failed to connect to Podman" di Cockpit UI

```bash
# Check podman socket
ls -la ~/.local/share/podman/podman.sock

# Check if podman service running
podman system info

# Restart podman
systemctl --user restart podman

# Check Cockpit plugin installed
sudo apt list --installed | grep cockpit

# Reinstall if needed
sudo apt install -y cockpit-podman
```

#### 7. High Memory/CPU Usage

**Issue**: Container consuming too many resources

```bash
# Monitor in real-time
podman stats container-name

# Check container config
podman inspect container-name | grep -A5 Memory

# Add resource limits
podman run -d \
  --memory 512m \
  --cpus 1 \
  my-image:latest

# Update existing container (requires restart)
# Edit ~/.config/systemd/user/container.service
# Restart: systemctl --user restart container.service
```

---

## 📚 Reference & Additional Resources

### Official Documentation
- Podman CLI: https://docs.podman.io/
- Cockpit: https://cockpit-project.org/
- Systemd Service: https://www.freedesktop.org/software/systemd/man/systemd.service.html

### Common Configuration Files
```
/etc/containers/containers.conf        # Global Podman config
/etc/containers/registries.conf         # Registry configuration
~/.config/containers/containers.conf    # User-level Podman config
~/.config/systemd/user/                 # User systemd units
/etc/systemd/system/                    # System-wide units
```

### Key Directories
```
~/.local/share/podman/                  # Podman socket & data
~/.local/share/containers/storage/      # Images & layers
/var/lib/containers/storage/            # System-wide containers
```

---

## ✅ Quick Checklist

- [ ] Podman installed dan running
- [ ] Cockpit accessible (https://localhost:9090)
- [ ] Custom networks dibuat untuk container isolation
- [ ] Images dapat di-pull dan di-build dengan sukses
- [ ] Container running dengan proper network, volume, dan resource limits
- [ ] Monitoring dan logging working via CLI dan Cockpit
- [ ] Systemd integration enabled untuk auto-start
- [ ] Services persist across reboots
- [ ] Logs accessible dan can be followed in real-time
- [ ] Cleanup tasks scheduled regularly

---

**Last Updated**: June 2026  
**Platform**: Ubuntu 24.04 LTS, Debian 12  
**Tested By**: DevOps Engineer

