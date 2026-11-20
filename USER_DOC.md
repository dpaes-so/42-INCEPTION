# User documentation

How to run and use the Inception stack day to day. To set it up from
scratch, see [DEV_DOC.md](DEV_DOC.md).

## Services provided

| Service   | What it does                                              | Reachable from          |
|-----------|-----------------------------------------------------------|-------------------------|
| NGINX     | Serves the website over HTTPS (TLSv1.2/1.3) on port 443   | Your browser            |
| WordPress | The website and its admin panel, run by PHP-FPM           | Only through NGINX      |
| MariaDB   | Stores the WordPress content, users and settings          | Only from WordPress     |

Only port 443 is open. `http://dpaes-so.42.fr` (port 80) does not answer.

## Start and stop

Run these from the root of the repository:

| Command       | Effect                                                         |
|---------------|----------------------------------------------------------------|
| `make`        | Create the data folders, build the images and start everything |
| `make down`   | Stop and remove the containers (data is kept)                  |
| `make fclean` | Remove containers, images, volumes **and all site data** (asks for your `sudo` password) |
| `make re`     | `make fclean` then `make`: starts again with an empty site     |

The data lives in `/home/$USER/data` (`/home/dpaes-so/data` on the VM) and
stays there across `make down`, a reboot or a rebuild. Only `make fclean`
(and so `make re`) deletes it.

## Access the website and the admin panel

1. The VM must resolve the domain: `/etc/hosts` needs the line
   `127.0.0.1 dpaes-so.42.fr`.
2. Website: <https://dpaes-so.42.fr>. The certificate is self-signed, so
   the browser shows a warning; accept it to continue.
3. Admin panel: <https://dpaes-so.42.fr/wp-admin>. Log in with the
   administrator account (below).

## Credentials

| What                         | Username (in `srcs/.env`) | Password file                   |
|------------------------------|---------------------------|---------------------------------|
| WordPress administrator      | `WP_ADMIN_USER`           | `secrets/wp_admin_password.txt` |
| WordPress user (subscriber)  | `WP_USER`                 | `secrets/wp_user_password.txt`  |
| MariaDB WordPress user       | `DB_USER`                 | `secrets/db_password.txt`       |
| MariaDB root (local only)    | `root`                    | `secrets/db_root_password.txt`  |

Show a password with, for example, `cat secrets/wp_admin_password.txt`.
These files and `srcs/.env` are ignored by git. Never commit them.

The passwords are only used when the site is created. To change one later,
change it in WordPress (Profile page) or in MariaDB, and update the file to
match. Changing only the file does nothing on an existing installation.

## Check that the services are running

```bash
docker compose -f srcs/docker-compose.yml ps        # all three should be "Up"
docker compose -f srcs/docker-compose.yml logs -f   # follow the logs (Ctrl+C to quit)
docker logs wordpress           # should end with "Starting PHP-FPM."
```

Quick checks:

```bash
# Website answers over HTTPS (-k accepts the self-signed certificate)
curl -k -I https://dpaes-so.42.fr

# Database answers and holds the WordPress tables
docker exec -it mariadb mariadb -u root -p     # password: secrets/db_root_password.txt
#   then: SHOW DATABASES; USE wordpress; SHOW TABLES; SELECT user_login FROM wp_users;
```

If a container keeps restarting, `docker logs <name>` shows why. If
`srcs/.env` or a secret file is missing, `make` stops with a Docker Compose
error naming the missing file.
