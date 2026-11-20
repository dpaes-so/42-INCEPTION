#!/bin/sh
set -eu

: "${DB_NAME:?DB_NAME is missing}"
: "${DB_USER:?DB_USER is missing}"

for value in "$DB_NAME" "$DB_USER"; do
    case "$value" in
        ''|*[!a-zA-Z0-9_]*)
            echo "Database names and usernames must use letters, digits or underscores." >&2
            exit 1 ;;
    esac
done

mkdir -p /run/mysqld /var/lib/mysql
chown -R mysql:mysql /run/mysqld /var/lib/mysql

if [ ! -f /var/lib/mysql/.inception_initialized ]; then
    if [ -d /var/lib/mysql/mysql ]; then
        echo "Existing database found without a setup marker. Stop and inspect it." >&2
        exit 1
    fi

    DB_PASSWORD=$(cat /run/secrets/db_password)
    DB_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)

    for value in "$DB_PASSWORD" "$DB_ROOT_PASSWORD"; do
        case "$value" in
            ''|*[!0-9a-fA-F]*)
                echo "Use the hexadecimal passwords generated with openssl." >&2
                exit 1 ;;
        esac
    done

    mariadb-install-db --user=mysql --datadir=/var/lib/mysql \
        --auth-root-authentication-method=socket --skip-test-db

    mariadbd --user=mysql --bootstrap <<SQL
FLUSH PRIVILEGES;
CREATE DATABASE \`${DB_NAME}\`;
CREATE USER '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
DROP USER IF EXISTS 'mysql'@'localhost';
SQL

    touch /var/lib/mysql/.inception_initialized
    echo "MariaDB initial setup complete."
fi

exec "$@"
