# Masuk ke folder project Laravel
```cd /path/to/laravel```

# Ubah izin untuk bootstrap/cache dan storage
```chmod -R 775 bootstrap/cache```
```chmod -R 775 storage```

# Ubah izin untuk folder upload profile
```chmod -R 775 public/admin/images```

# Ubah owner agar web server (www-data atau nginx) bisa menulis
```chown -R $USER:www-data bootstrap/cache storage public/admin/images
```
