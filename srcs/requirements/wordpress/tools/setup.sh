#!/bin/sh
set -eu

: "${DB_NAME:?DB_NAME is missing}"
: "${DB_USER:?DB_USER is missing}"
: "${DOMAIN_NAME:?DOMAIN_NAME is missing}"
: "${WP_VERSION:?WP_VERSION is missing}"
: "${WP_TITLE:?WP_TITLE is missing}"
: "${WP_ADMIN_USER:?WP_ADMIN_USER is missing}"
: "${WP_ADMIN_EMAIL:?WP_ADMIN_EMAIL is missing}"
: "${WP_USER:?WP_USER is missing}"
: "${WP_USER_EMAIL:?WP_USER_EMAIL is missing}"

case "$(printf '%s' "$WP_ADMIN_USER" | tr '[:upper:]' '[:lower:]')" in
    *admin*) echo "Choose an administrator username without 'admin'." >&2; exit 1 ;;
esac

for secret in db_password wp_admin_password wp_user_password; do
    if [ ! -s "/run/secrets/$secret" ]; then
        echo "Missing or empty secret: $secret" >&2
        exit 1
    fi
done

DB_PASSWORD=$(cat /run/secrets/db_password)
cd /var/www/html

echo "Waiting for MariaDB..."
ready=0
for attempt in $(seq 1 60); do
    if MYSQL_PWD="$DB_PASSWORD" mariadb --protocol=tcp \
        --connect-timeout=2 -h mariadb -u"$DB_USER" "$DB_NAME" \
        -e "SELECT 1" >/dev/null 2>&1; then
        ready=1
        break
    fi
    sleep 1
done

if [ "$ready" -ne 1 ]; then
    echo "Could not connect to MariaDB." >&2
    exit 1
fi
unset DB_PASSWORD

if [ ! -f .core_downloaded ]; then
    wp core download --version="$WP_VERSION" --force --allow-root
    touch .core_downloaded
fi

if [ ! -f wp-config.php ]; then
    (
        umask 077
        wp config create --dbname="$DB_NAME" --dbuser="$DB_USER" \
            --dbhost=mariadb:3306 --dbcharset=utf8mb4 \
            --prompt=dbpass --allow-root < /run/secrets/db_password
    )
fi

if ! wp core is-installed --allow-root; then
    wp core install --url="https://$DOMAIN_NAME" --title="$WP_TITLE" \
        --admin_user="$WP_ADMIN_USER" --admin_email="$WP_ADMIN_EMAIL" \
        --prompt=admin_password --skip-email --allow-root \
        < /run/secrets/wp_admin_password
fi

if ! wp user get "$WP_USER" --field=ID --allow-root >/dev/null 2>&1; then
    wp user create "$WP_USER" "$WP_USER_EMAIL" --role=subscriber \
        --prompt=user_pass --allow-root < /run/secrets/wp_user_password
fi

chown -R www-data:www-data /var/www/html
chmod 640 /var/www/html/wp-config.php

echo "WordPress setup complete. Starting PHP-FPM."
exec "$@"
