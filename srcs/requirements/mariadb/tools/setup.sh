#!/bin/sh
set -eu

DB_PASSWORD=$(cat /run/secrets/db_password)
DB_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)

mkdir -p /run/mysqld /var/lib/mysql
chown -R mysql:mysql /run/mysqld /var/lib/mysql

if [ ! -d /var/lib/mysql/mysql ]; then
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql
fi

if [ -f /var/lib/mysql/.inception_initialized ]; then
    exec mariadbd --user=mysql
fi

# First start: a temporary server (socket only, no network) to create the
# database and users. It is stopped before the real server starts.
mariadbd --user=mysql --skip-networking &
PID=$!

for i in $(seq 1 10); do
    if mariadb-admin ping --silent; then
        break
    fi
    if [ "$i" -eq 10 ]; then
        echo "MariaDB failed to start." >&2
        exit 1
    fi
    sleep 1
done

mariadb -u root <<SQL
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;
CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
ALTER USER '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
SQL

mariadb-admin -u root --password="${DB_ROOT_PASSWORD}" shutdown
wait "$PID"

touch /var/lib/mysql/.inception_initialized
echo "MariaDB initial setup complete."

exec mariadbd --user=mysql
