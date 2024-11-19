#!/bin/bash

# Set error handling
set -e

echo "=== Mulai Instalasi ZYA CBT ==="

# 1. Unduh file installer LAMP dan CBT
echo "Mengunduh file installer LAMP..."
wget -q https://raw.githubusercontent.com/emuhib/zyacbtinstall/main/setup_lamp_cbt_interactive.sh -O setup_lamp_cbt_interactive.sh

echo "Mengunduh file CBT..."
wget -q http://157.245.197.117/cbt.7z -O /tmp/cbt.7z

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

# 6. Pilihan domain atau IP
read -p "Apakah Anda ingin menggunakan domain? (y/n): " use_domain
if [[ $use_domain == "y" || $use_domain == "Y" ]]; then
    read -p "Masukkan nama domain (misalnya: cbt.example.com): " DOMAIN_NAME
    # Update konfigurasi Apache dengan domain yang dimasukkan
    echo "Menambahkan konfigurasi Apache untuk domain $DOMAIN_NAME..."
    sudo bash -c "cat > /etc/apache2/sites-available/$DOMAIN_NAME.conf <<EOL
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html
    ServerName $DOMAIN_NAME
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOL"
    # Enable site dan restart Apache
    sudo a2ensite $DOMAIN_NAME.conf
    sudo systemctl restart apache2
else
    echo "Menggunakan IP VPS sebagai alamat CBT."
    # Update konfigurasi Apache untuk menggunakan IP VPS (default)
    sudo bash -c "cat > /etc/apache2/sites-available/000-default.conf <<EOL
<VirtualHost *:80>
    DocumentRoot /var/www/html
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOL"
    sudo systemctl restart apache2
fi

# 7. Impor database MySQL
read -p "Masukkan username MySQL: " MYSQL_USER
read -sp "Masukkan password MySQL: " MYSQL_PASSWORD
echo ""
read -p "Masukkan nama database untuk CBT: " CBT_DATABASE

# Menampilkan opsi file SQL
echo "Pilih file SQL yang ingin diimpor:"
echo "1) zyacbt-public-2024-04-29-dengan-database.sql"
echo "2) zyacbt-public-2024-04-29-tanpa-database.sql"
read -p "Masukkan pilihan Anda (1 atau 2): " sql_choice

# Menentukan file SQL berdasarkan pilihan
if [[ $sql_choice -eq 1 ]]; then
    sql_file="/var/www/html/zyacbt-public-2024-04-29-dengan-database.sql"
elif [[ $sql_choice -eq 2 ]]; then
    sql_file="/var/www/html/zyacbt-public-2024-04-29-tanpa-database.sql"
else
    echo "Pilihan tidak valid. Script dihentikan."
    exit 1
fi

# Jika memilih file dengan database, langsung buat database
if [[ $sql_choice -eq 1 ]]; then
    echo "Mengimpor file SQL dengan database ke MySQL..."
    mysql -u $MYSQL_USER -p$MYSQL_PASSWORD < $sql_file
else
    # Jika memilih file tanpa database, buat database terlebih dahulu
    echo "Membuat database $CBT_DATABASE dan mengimpor file SQL tanpa database..."
    mysql -u $MYSQL_USER -p$MYSQL_PASSWORD -e "CREATE DATABASE $CBT_DATABASE;"
    mysql -u $MYSQL_USER -p$MYSQL_PASSWORD $CBT_DATABASE < $sql_file
fi

# 8. Konfigurasi database.php
echo "Mengedit konfigurasi database..."
sudo sed -i "s/'username' => '.*'/'username' => '$MYSQL_USER'/" /var/www/html/application/config/database.php
sudo sed -i "s/'password' => '.*'/'password' => '$MYSQL_PASSWORD'/" /var/www/html/application/config/database.php
sudo sed -i "s/'database' => '.*'/'database' => '$CBT_DATABASE'/" /var/www/html/application/config/database.php

# 9. Atur izin file dan direktori
echo "Mengatur izin file dan direktori..."
sudo chown -R www-data:www-data /var/www/html
sudo find /var/www/html -type d -exec chmod 755 {} \;
sudo find /var/www/html -type f -exec chmod 644 {} \;

# 10. Restart Apache
echo "Restarting Apache..."
sudo systemctl restart apache2

# 11. Konfigurasi MySQL untuk menonaktifkan ONLY_FULL_GROUP_BY
echo "Mengedit konfigurasi MySQL untuk menonaktifkan ONLY_FULL_GROUP_BY..."
sudo sed -i '/^\[mysqld\]/a sql_mode = "STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION"' /etc/mysql/mysql.conf.d/mysqld.cnf

echo "Restarting MySQL..."
sudo systemctl restart mysql

echo "=== Instalasi ZYA CBT Selesai ==="
echo "Akses CBT Anda melalui domain atau IP VPS Anda."
