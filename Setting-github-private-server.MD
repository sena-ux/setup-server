# Setting Kumon dengan github private
Berikut ini rangkaian setting nya agar server bisa berkomunikasi dengan git hub yang private.

## Generate SSH Key untuk Server
```
ssh-keygen -t rsa -b 4096 -C "server@domain.com"
```
