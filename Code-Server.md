```
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget unzip
curl -fsSL https://code-server.dev/install.sh | sh
code-server --version
nano ~/.config/code-server/config.yaml

- Isi :
  bind-addr: 0.0.0.0:8080
auth: password
password: ganti_dengan_password_anda
cert: false

code-server


sudo nano /etc/systemd/system/code-server.service
- Isi
[Unit]
Description=Code Server
After=network.target

[Service]
Type=simple
User=ubuntu
ExecStart=/usr/bin/code-server --bind-addr 0.0.0.0:8080
Restart=always

[Install]
WantedBy=multi-user.target

sudo systemctl daemon-reload
sudo systemctl enable --now code-server
sudo systemctl status code-server


sudo nano /etc/caddy/Caddyfile
yourdomain.com {
    reverse_proxy localhost:8080
}

sudo systemctl restart caddy
```
