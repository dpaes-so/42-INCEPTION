FROM debian:bookworm

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        nginx openssl gettext-base \
    && rm -rf /var/lib/apt/lists/* \
    && rm -f /etc/nginx/sites-enabled/default

COPY conf/nginx.conf.template /etc/nginx/templates/nginx.conf.template
COPY tools/setup.sh /usr/local/bin/setup.sh

RUN chmod +x /usr/local/bin/setup.sh

EXPOSE 443

ENTRYPOINT ["/usr/local/bin/setup.sh"]
CMD ["nginx", "-g", "daemon off;"]
