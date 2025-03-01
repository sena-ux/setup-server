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


## Uji Coba Koneksi ke GitHub
```
ssh -T git@github.com
```

## Konfigurasi SSH Secara Global untuk GitHub
```
nano ~/.ssh/config
```

Isi dengan
```
Host github.com
    User git
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no
```

## Clode repo priivate
Full Branch
```
git clone git@github.com:username/repo-private.git
```
Branch Tertentu
```
git clone --branch NAMA_BRANCH --single-branch URL_REPO
```
