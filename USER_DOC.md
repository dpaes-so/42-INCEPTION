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

| Command        | Effect                                                      |
|----------------|-------------------------------------------------------------|
| `make`         | Build the images if needed and start everything             |
| `make stop`    | Stop the containers and keep them                           |
| `make down`    | Stop and remove the containers (data is kept)               |
| `make restart` | Restart the containers                                      |
| `make re`      | `make down` then `make`                                     |
| `make fclean`  | Remove containers, images, volumes **and all site data**    |

The data stays in `/home/dpaes-so/data` across `make down`, a reboot or a
rebuild. Only `make fclean` deletes it.

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
make ps                         # all three containers should be "Up"
make logs                       # follow the logs (Ctrl+C to quit)
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

If a container keeps restarting, `docker logs <name>` shows why. A missing
`srcs/.env` or secret file is reported by `make` before anything starts.
