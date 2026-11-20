#!/bin/sh
set -eu

DB_PASSWORD=$(cat /run/secrets/db_password)
WP_ADMIN_PASSWORD=$(cat /run/secrets/wp_admin_password)
WP_USER_PASSWORD=$(cat /run/secrets/wp_user_password)

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

if [ ! -f .core_downloaded ]; then
    wp core download --force --allow-root
    touch .core_downloaded
fi

if [ ! -f wp-config.php ]; then
    wp config create --dbname="$DB_NAME" --dbuser="$DB_USER" \
        --dbpass="$DB_PASSWORD" --dbhost=mariadb:3306 --allow-root
fi

if ! wp core is-installed --url="https://$DOMAIN_NAME" --allow-root; then
    wp core install --url="https://$DOMAIN_NAME" --title="$WP_TITLE" \
        --admin_user="$WP_ADMIN_USER" --admin_password="$WP_ADMIN_PASSWORD" \
        --admin_email="$WP_ADMIN_EMAIL" --skip-email --allow-root
    # By default WordPress holds a user's first comment for moderation;
    # publish comments right away so the second user can comment.
    wp option update comment_previously_approved 0 --allow-root
fi

if ! wp user get "$WP_USER" --field=ID --allow-root >/dev/null 2>&1; then
    wp user create "$WP_USER" "$WP_USER_EMAIL" --role=subscriber \
        --user_pass="$WP_USER_PASSWORD" --allow-root
fi

chown -R www-data:www-data /var/www/html
chmod 640 /var/www/html/wp-config.php

echo "WordPress setup complete. Starting PHP-FPM."
exec php-fpm8.2 -F
