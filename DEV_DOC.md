# Developer documentation

How to set up, build and manage the Inception stack. For everyday use, see
[USER_DOC.md](USER_DOC.md).

## Repository layout

```
.
├── Makefile                  # entry point: creates the data dirs, runs docker compose
├── secrets/                  # password files (ignored by git, you create them)
└── srcs/
    ├── .env.example          # template for srcs/.env (copy it, ignored by git)
    ├── docker-compose.yml    # services, network, named volumes, secrets
    └── requirements/
        ├── mariadb/          # Dockerfile, conf/99-inception.cnf, tools/setup.sh
        ├── nginx/            # Dockerfile, conf/nginx.conf (site config), tools/setup.sh
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
| `WP_TITLE`       | Site title                                                   |
| `WP_ADMIN_USER`  | Administrator username; must not contain "admin"             |
| `WP_ADMIN_EMAIL` | Administrator email                                          |
| `WP_USER`        | Second user (subscriber)                                     |
| `WP_USER_EMAIL`  | Second user's email                                          |

Docker Compose reads `srcs/.env` (next to `docker-compose.yml`) and passes it to
the containers with `env_file`. No password goes in `.env`.

### Secrets: `secrets/*.txt`

Four files, one password each. The two database passwords must not contain
`'` or `\`: they go between quotes in the SQL that creates the users. An easy
way to generate them:

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

Without `srcs/.env` or any of these files, `make` stops with a Docker
Compose error naming the missing file.

## Build and launch

```bash
make            # = make up: mkdir /home/$USER/data/{mariadb,wordpress}, then compose up --build -d
```

Under the hood, the Makefile runs:

```bash
docker compose -f srcs/docker-compose.yml up --build -d
```

On first start (the healthchecks in `docker-compose.yml` keep this order):

1. **mariadb** initialises `/var/lib/mysql` with `mariadb-install-db`, creates the
   database and user with `mariadbd --bootstrap`, sets the root password,
   writes the `.inception_initialized` marker, then `exec`s `mariadbd`. It
   becomes healthy when `mariadb-admin ping` answers.
2. **wordpress** starts once mariadb is healthy (its script still waits up to
   60 s for a database connection, as a safety net), then uses WP-CLI to download
   WordPress, create `wp-config.php`, install the site (admin user) and create the
   second user. Then it `exec`s `php-fpm8.2 -F`, and becomes healthy once
   PHP-FPM is PID 1.
3. **nginx** starts once wordpress is healthy. It creates a new self-signed
   certificate for `DOMAIN_NAME`, then `exec`s `nginx -g "daemon off;"`. Its
   site config (`conf/nginx.conf`, copied over Debian's default site) has the
   domain written in `server_name`; change it there too if you change
   `DOMAIN_NAME`.

On later starts each script sees the existing data and goes straight to the
daemon.

## Manage containers and volumes

```bash
docker compose -f srcs/docker-compose.yml ps        # containers
docker compose -f srcs/docker-compose.yml logs -f   # follow all logs
docker logs -f wordpress                  # one service
docker exec -it mariadb sh                # shell in a container
docker exec -it wordpress wp user list --allow-root
docker compose -f srcs/docker-compose.yml build nginx   # rebuild one image

docker network ls                         # inception_inception (bridge)
docker volume ls                          # inception_mariadb_data, inception_wordpress_data
docker volume inspect inception_mariadb_data   # Options.device = /home/$USER/data/mariadb
```

| Target        | Does                                                                 |
|---------------|----------------------------------------------------------------------|
| `make down`   | Remove containers and the network; volumes and data stay             |
| `make clean`  | Same as `make down`                                                  |
| `make fclean` | `clean`, then `compose down -v --rmi all` and `sudo rm -rf /home/$USER/data` |
| `make re`     | `fclean` + `all`: rebuild everything with an empty site              |

`fclean` needs `sudo` because the data files belong to container users
(`mysql`, `www-data`), not to you.

## Where data lives and how it persists

| Volume                     | Mounted at                    | Data on the host               |
|----------------------------|-------------------------------|--------------------------------|
| `inception_mariadb_data`   | `/var/lib/mysql` (mariadb)    | `/home/$USER/data/mariadb`  |
| `inception_wordpress_data` | `/var/www/html` (wordpress and nginx) | `/home/$USER/data/wordpress` |

Both are named volumes using the `local` driver with
`type: none, o: bind, device: /home/${USER}/data/...`. Docker Compose takes
`USER` from your shell, so on the VM the path is `/home/dpaes-so/data`. Run
`make` as yourself, not with `sudo` (which would make it `/home/root/data`). Removing the
containers, the images, or even the volumes (`docker volume rm`) leaves the
files in `/home/$USER/data`. The next `make` finds the setup markers
there and reuses the existing database and site. After a VM reboot, run
`make` again. (`restart: on-failure` restarts a container that crashes, not
one that Docker stopped cleanly at shutdown.)

To start over with an empty site: `make fclean && make`.
