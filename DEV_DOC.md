# Developer documentation

How to set up, build and manage the Inception stack. For everyday use, see
[USER_DOC.md](USER_DOC.md).

## Repository layout

```
.
├── Makefile                  # entry point: checks config, creates data dirs, runs compose
├── secrets/                  # password files (ignored by git, you create them)
└── srcs/
    ├── .env.example          # template for srcs/.env (copy it, ignored by git)
    ├── docker-compose.yml    # services, network, named volumes, secrets
    └── requirements/
        ├── mariadb/          # Dockerfile, conf/99-inception.cnf, tools/setup.sh
        ├── nginx/            # Dockerfile, conf/nginx.conf.template, tools/setup.sh
        └── wordpress/        # Dockerfile, conf/www.conf (PHP-FPM pool), tools/setup.sh
```

## Set up the environment from scratch

### Prerequisites

On the VM (Debian/Ubuntu):

- Docker Engine with the Compose plugin (`docker compose version` must work).
  Follow <https://docs.docker.com/engine/install/>, then run
  `sudo usermod -aG docker $USER` and log in again to use Docker without `sudo`.
- `make`, `git` and `openssl`.

### Domain

```bash
echo "127.0.0.1 dpaes-so.42.fr" | sudo tee -a /etc/hosts
```

### Configuration file: `srcs/.env`

```bash
cp srcs/.env.example srcs/.env
```

| Variable         | Meaning                                                      |
|------------------|--------------------------------------------------------------|
| `DOMAIN_NAME`    | Site domain, `dpaes-so.42.fr`                                |
| `DB_NAME`        | WordPress database name (letters, digits, `_`)               |
| `DB_USER`        | MariaDB user for WordPress (letters, digits, `_`)            |
| `WP_VERSION`     | WordPress version that WP-CLI downloads                      |
| `WP_TITLE`       | Site title                                                   |
| `WP_ADMIN_USER`  | Administrator username; must not contain "admin"             |
| `WP_ADMIN_EMAIL` | Administrator email                                          |
| `WP_USER`        | Second user (subscriber)                                     |
| `WP_USER_EMAIL`  | Second user's email                                          |

No password goes in `.env`.

### Secrets: `secrets/*.txt`

Four files, one password each. MariaDB only accepts hexadecimal passwords,
so generate them with `openssl`:

```bash
mkdir -p secrets
for s in db_password db_root_password wp_admin_password wp_user_password; do
    openssl rand -hex 16 > secrets/$s.txt
done
chmod 600 secrets/*.txt
```

| File                    | Used by             | Mounted at                         |
|-------------------------|---------------------|------------------------------------|
| `db_password.txt`       | mariadb, wordpress  | `/run/secrets/db_password`         |
| `db_root_password.txt`  | mariadb             | `/run/secrets/db_root_password`    |
| `wp_admin_password.txt` | wordpress           | `/run/secrets/wp_admin_password`   |
| `wp_user_password.txt`  | wordpress           | `/run/secrets/wp_user_password`    |

`make` refuses to start if `srcs/.env` or any of these files is missing or
empty.

## Build and launch

```bash
make            # = make up: check config, mkdir /home/dpaes-so/data/{mariadb,wordpress}, compose up -d --build
```

Under the hood, the Makefile runs:

```bash
docker compose --env-file srcs/.env -f srcs/docker-compose.yml up -d --build
```

On first start:

1. **mariadb** initialises `/var/lib/mysql` with `mariadb-install-db`, creates the
   database and user with `mariadbd --bootstrap`, sets the root password,
   writes the `.inception_initialized` marker, then `exec`s `mariadbd`.
2. **wordpress** waits up to 60 s for MariaDB, then uses WP-CLI to download
   WordPress, create `wp-config.php`, install the site (admin user) and create the
   second user. Then it `exec`s `php-fpm8.2 -F`.
3. **nginx** creates a self-signed certificate for `DOMAIN_NAME`, renders its
   config from the template, then `exec`s `nginx -g "daemon off;"`.

On later starts each script sees the existing data and goes straight to the
daemon.

## Manage containers and volumes

```bash
make ps                                   # docker compose ps -a
make logs                                 # follow all logs
docker logs -f wordpress                  # one service
docker exec -it mariadb sh                # shell in a container
docker exec -it wordpress wp user list --allow-root
docker compose --env-file srcs/.env -f srcs/docker-compose.yml build nginx   # rebuild one image

docker network ls                         # inception_inception (bridge)
docker volume ls                          # inception_mariadb_data, inception_wordpress_data
docker volume inspect inception_mariadb_data   # Options.device = /home/dpaes-so/data/mariadb
```

| Target        | Does                                                                 |
|---------------|----------------------------------------------------------------------|
| `make down`   | Remove containers and the network; volumes and data stay             |
| `make re`     | `down` + `up`                                                        |
| `make fclean` | `compose down -v --rmi all`, then deletes `/home/dpaes-so/data/*`    |

`fclean` deletes the data with a throwaway `debian:bookworm` container,
because the files belong to container users (`mysql`, `www-data`) and a plain
`rm` would need `sudo`.

## Where data lives and how it persists

| Volume                     | Mounted at                    | Data on the host               |
|----------------------------|-------------------------------|--------------------------------|
| `inception_mariadb_data`   | `/var/lib/mysql` (mariadb)    | `/home/dpaes-so/data/mariadb`  |
| `inception_wordpress_data` | `/var/www/html` (wordpress; read-only in nginx) | `/home/dpaes-so/data/wordpress` |

Both are named volumes using the `local` driver with
`type: none, o: bind, device: /home/dpaes-so/data/...`. Removing the
containers, the images, or even the volumes (`docker volume rm`) leaves the
files in `/home/dpaes-so/data`. The next `make` finds the setup markers
there and reuses the existing database and site. After a VM reboot, the
containers start again with the Docker service (`restart: unless-stopped`),
or with `make`.

To start over with an empty site: `make fclean && make`.
