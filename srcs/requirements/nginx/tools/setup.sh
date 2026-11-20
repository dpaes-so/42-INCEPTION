#!/bin/sh
set -eu

: "${DOMAIN_NAME:?DOMAIN_NAME is missing}"

mkdir -p /etc/nginx/ssl

if [ ! -s /etc/nginx/ssl/inception.key ] || [ ! -s /etc/nginx/ssl/inception.crt ]; then
    (
        umask 077
        openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
            -keyout /etc/nginx/ssl/inception.key \
            -out /etc/nginx/ssl/inception.crt \
            -subj "/CN=${DOMAIN_NAME}" \
            -addext "subjectAltName=DNS:${DOMAIN_NAME}"
    )
fi

envsubst '${DOMAIN_NAME}' \
    < /etc/nginx/templates/nginx.conf.template \
    > /etc/nginx/conf.d/inception.conf

exec "$@"
