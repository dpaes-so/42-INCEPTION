#!/bin/sh
set -eu

mkdir -p /run/mysqld /var/lib/mysql
chown -R mysql:mysql /run/mysqld /var/lib/mysql

if [ ! -f /var/lib/mysql/.inception_initialized ]; then
    DB_PASSWORD=$(cat /run/secrets/db_password)
    DB_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)

    mariadb-install-db --user=mysql --datadir=/var/lib/mysql

    mariadbd --user=mysql --bootstrap <<SQL
FLUSH PRIVILEGES;
CREATE DATABASE \`${DB_NAME}\`;
CREATE USER '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
SQL

    touch /var/lib/mysql/.inception_initialized
    echo "MariaDB initial setup complete."
fi

exec mariadbd --user=mysql
