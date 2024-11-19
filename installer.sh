#!/bin/bash

# Set error handling
set -e

echo "=== Mulai Instalasi ZYA CBT ==="

# 1. Unduh file installer LAMP dan CBT
echo "Mengunduh file installer LAMP..."
wget -q https://raw.githubusercontent.com/emuhib/zyacbtinstall/main/setup_lamp_cbt_interactive.sh -O setup_lamp_cbt_interactive.sh

echo "Mengunduh file CBT..."
wget -q https://example.com/cbt.7z -O /tmp/cbt.7z  # Ganti link dengan link file CBT Anda

# 2. Berikan izin eksekusi pada installer LAMP
chmod +x setup_lamp_cbt_interactive.sh

# 3. Jalankan installer LAMP
echo "Menjalankan installer LAMP..."
sudo bash setup_lamp_cbt_interactive.sh

# 4. Hapus file index.html bawaan Apache
echo "Menghapus file index.html..."
sudo rm -f /var/www/html/index.html

# 5. Pindahkan dan ekstrak file CBT
echo "Memindahkan dan mengekstrak file CBT..."
sudo mv /tmp/cbt.7z /var/www/html/
sudo 7z x /var/www/html/cbt.7z -o/var/www/html/

# 6. Impor database MySQL
read -p "Masukkan username MySQL: " MYSQL_USER
read -sp "Masukkan password MySQL: " MYSQL_PASSWORD
echo ""
read -p "Masukkan nama database untuk CBT: " CBT_DATABASE

echo "Membuat database dan mengimpor file SQL..."
mysql -u $MYSQL_USER -p$MYSQL_PASSWORD -e "CREATE DATABASE $CBT_DATABASE;"
mysql -u $MYSQL_USER -p$MYSQL_PASSWORD $CBT_DATABASE < /var/www/html/cbt.sql

# 7. Konfigurasi database.php
echo "Mengedit konfigurasi database..."
sudo sed -i "s/'username' => '.*'/'username' => '$MYSQL_USER'/" /var/www/html/application/config/database.php
sudo sed -i "s/'password' => '.*'/'password' => '$MYSQL_PASSWORD'/" /var/www/html/application/config/database.php
sudo sed -i "s/'database' => '.*'/'database' => '$CBT_DATABASE'/" /var/www/html/application/config/database.php

# 8. Atur izin file dan direktori
echo "Mengatur izin file dan direktori..."
sudo chown -R www-data:www-data /var/www/html
sudo find /var/www/html -type d -exec chmod 755 {} \;
sudo find /var/www/html -type f -exec chmod 644 {} \;

# 9. Restart Apache
echo "Restarting Apache..."
sudo systemctl restart apache2

# 10. Konfigurasi MySQL untuk menonaktifkan ONLY_FULL_GROUP_BY
echo "Mengedit konfigurasi MySQL untuk menonaktifkan ONLY_FULL_GROUP_BY..."
sudo sed -i '/^\[mysqld\]/a sql_mode = "STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION"' /etc/mysql/mysql.conf.d/mysqld.cnf

echo "Restarting MySQL..."
sudo systemctl restart mysql

echo "=== Instalasi ZYA CBT Selesai ==="
echo "Akses CBT Anda melalui IP VPS Anda."
