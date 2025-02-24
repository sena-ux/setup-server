# Setting Kumon dengan github private
Berikut ini rangkaian setting nya agar server bisa berkomunikasi dengan git hub yang private.

## Generate SSH Key untuk Server
```
ssh-keygen -t rsa -b 4096 -C "server@domain.com"
```
## Tambahkan SSH Key ke GitHub
```
cat ~/.ssh/id_rsa.pub
```
Salin outputnya, lalu:

- Buka GitHub → Klik Profile → Settings
- Pilih SSH and GPG keys
- Klik New SSH Key
- Masukkan nama key (misalnya Server Global)
- Paste isi dari id_rsa.pub ke kolom Key
- Klik Add SSH Key
