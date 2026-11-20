*This project has been created as part of the 42 curriculum by dpaes-so.*

# Inception

## Description

Inception is a system administration project: it sets up a small web
infrastructure with Docker Compose inside a virtual machine. Three services each
run in their own container, built from my own Dockerfiles on `debian:bookworm`
(the penultimate stable Debian):

| Service     | Role                                                                    |
|-------------|-------------------------------------------------------------------------|
| `nginx`     | The only entry point, on port 443, with TLSv1.2/TLSv1.3 and a self-signed certificate |
| `wordpress` | WordPress with PHP-FPM (no web server), installed and set up with WP-CLI |
| `mariadb`   | The WordPress database                                                  |

The site is served at `https://dpaes-so.42.fr`. The database and the website
files persist in two Docker named volumes whose data lives in
`/home/dpaes-so/data` on the host.

## Instructions

Requirements: a Linux VM with Docker Engine, the Docker Compose plugin, `make`
and `openssl`. See [DEV_DOC.md](DEV_DOC.md) for the full setup.

```bash
# 1. Configuration (not in git)
cp srcs/.env.example srcs/.env
mkdir -p secrets
for s in db_password db_root_password wp_admin_password wp_user_password; do
    openssl rand -hex 16 > secrets/$s.txt
done

# 2. Point the domain at the VM
echo "127.0.0.1 dpaes-so.42.fr" | sudo tee -a /etc/hosts

# 3. Build and start
make
```

Then open `https://dpaes-so.42.fr` and accept the self-signed certificate.
Other targets: `make down` (stop, keep the data), `make fclean` (also deletes
all data) and `make re` (`fclean` + `make`).
[USER_DOC.md](USER_DOC.md) explains day-to-day use.

## Project description

### How Docker is used

- **One Dockerfile per service** in `srcs/requirements/<service>/`, with its
  config in `conf/` and its entrypoint script in `tools/`. No ready-made image
  is pulled apart from `debian:bookworm`.
- **Entrypoint scripts** (`tools/setup.sh`) do the first-run setup, then
  `exec` the real daemon (`nginx`, `php-fpm8.2 -F`, `mariadbd`). The daemon
  becomes PID 1 and runs in the foreground, so Docker can see when it crashes
  and stop it cleanly. No `tail -f`, `sleep infinity` or background jobs.
- **`srcs/docker-compose.yml`** builds the three images (each named after its
  service: `nginx`, `wordpress`, `mariadb`), passes `srcs/.env` to them with
  `env_file`, connects them on one bridge network, mounts the volumes and
  secrets, and restarts containers on a crash (`restart: on-failure`).
- **The Makefile** creates the data folders and runs Docker Compose.

### Main design choices

- **First-run markers:** MariaDB is only set up when its data folder has no
  setup marker, and WordPress only downloads, configures and installs itself
  when it is not done yet. Restarting or rebuilding keeps the existing data.
- **MariaDB bootstrap:** the database and users are created with
  `mariadbd --bootstrap`, so no temporary server runs in the background.
- **Start order with healthchecks:** WordPress only starts when MariaDB answers
  (`mariadb-admin ping`), and NGINX only when WordPress has finished its setup
  and PHP-FPM runs (`depends_on` with `condition: service_healthy`).
- **Passwords stay out of the image and `.env`:** the scripts read them from
  `/run/secrets/*` at start-up.
- **Minimal attack surface:** only NGINX publishes a port (443). PHP-FPM (9000)
  and MariaDB (3306) are only reachable on the internal network.
- **Users:** the administrator username (`WP_ADMIN_USER`) does not contain
  "admin", as the subject requires. The second user is a subscriber who can
  comment.

### Virtual Machines vs Docker

A virtual machine emulates a whole computer: it boots its own kernel and full
operating system on virtual hardware. That gives strong isolation but costs
gigabytes of disk, a lot of RAM and slow boots. A Docker container is an
isolated process on the host's kernel (namespaces and cgroups) with its own
filesystem from an image. Containers start in seconds, weigh megabytes, and
an image runs the same everywhere. In this project the VM is the host, and
Docker isolates each service inside it.

### Secrets vs Environment Variables

Environment variables are fine for configuration that isn't sensitive (domain,
database name, usernames), so those live in `srcs/.env`. But environment
variables can be read with `docker inspect`, are inherited by child
processes and often end up in logs. Docker secrets are files mounted
read-only at `/run/secrets/<name>` only in the containers that need them, and
they are not part of the image or the container's environment. All passwords
here are secrets, kept in `secrets/` and ignored by git.

### Docker Network vs Host Network

With `network: host` a container shares the host's network stack: every port
it opens is open on the host, and there is no isolation between services. A
user-defined bridge network (`inception` here) gives the containers a private
network with built-in DNS, so `wordpress` reaches `mariadb:3306` by name. Only
the ports listed under `ports:` (here just 443 on NGINX) are reachable from
outside.

### Docker Volumes vs Bind Mounts

A bind mount maps any host path straight into a container. It depends on the
host's folder layout and Docker does not manage it. A named volume is managed
by Docker (`docker volume ls/inspect/rm`), has a name independent of the host
layout, and is filled from the image the first time it is used. The subject
asks for named volumes whose data sits in `/home/dpaes-so/data`, so both
volumes use the `local` driver with `driver_opts` (`type: none`, `o: bind`,
`device: /home/${USER}/data/...`, which is `/home/dpaes-so/data` on the VM). They are still named volumes, and
`docker volume inspect` shows where the data lives.

## Resources

- [Docker documentation](https://docs.docker.com/): Dockerfile reference,
  Compose file reference, [secrets in Compose](https://docs.docker.com/compose/how-tos/use-secrets/),
  [volumes](https://docs.docker.com/engine/storage/volumes/) and
  [networking](https://docs.docker.com/engine/network/)
- [Dockerfile best practices](https://docs.docker.com/build/building/best-practices/)
  and the role of PID 1 in containers
- [NGINX documentation](https://nginx.org/en/docs/): `ngx_http_ssl_module`,
  `ngx_http_fastcgi_module`
- [WP-CLI commands](https://developer.wordpress.org/cli/commands/)
- [MariaDB documentation](https://mariadb.com/kb/en/documentation/):
  `mariadb-install-db`, `mariadbd --bootstrap`, user management
- [PHP-FPM configuration](https://www.php.net/manual/en/install.fpm.configuration.php)

### AI usage

Claude (Claude Code) was used as a review and testing assistant, not to write
the services from scratch:

- Running the stack on macOS (OrbStack) and testing it against the subject and
  the evaluation sheet: TLS versions, port 80 closed, admin login, user
  comment, page edit, persistence and restart.
- Finding and fixing issues: the Makefile used `.RECIPEPREFIX`, which the
  `make` on macOS does not support; WP-CLI printed passwords into
  `docker logs`; the volumes were not stored in `/home/dpaes-so/data`; the
  second user's first comment was held for moderation.
- Drafting this README, `USER_DOC.md` and `DEV_DOC.md`, which I then reviewed.

All code and docs were reviewed and are understood by me.
