# Install SSH Server
Langkah-langkah install ssh server for linux
## SSH Server
```
1. apt install openssh-server -y
2. systemctl status ssh
3. systemctl start ssh
4. systemctl enable ssh
```
## Setting ROOT
```
sudo nano /etc/ssh/sshd_config
PermitRootLogin yes
PasswordAuthentication yes

ip a / hostname -I
ssh root@ip
```

## Custom Port SSH
```
nano /etc/ssh/sshd_config
Port 2222
ufw allow 2222/tcp
ufw status
systemctl restart ssh

ssh -p 2222 user@IP_SERVER
```

Jika SSH sama maka hapus dulu keygen yang lama
```
ssh-keygen -R "[103.207.97.114]:8084"
```
