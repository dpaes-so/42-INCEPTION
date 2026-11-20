# Data of the two named volumes lives here on the host (see srcs/docker-compose.yml).
DATA_DIR = /home/dpaes-so/data

COMPOSE = docker compose --env-file srcs/.env -f srcs/docker-compose.yml

SECRETS = secrets/db_password.txt secrets/db_root_password.txt \
          secrets/wp_admin_password.txt secrets/wp_user_password.txt

.PHONY: all check dirs build up down stop restart logs ps clean fclean re

all: up

# Stop early with a clear message if the local configuration is missing.
check:
	@test -f srcs/.env || { echo "Missing srcs/.env: copy srcs/.env.example and fill it in (see DEV_DOC.md)."; exit 1; }
	@for f in $(SECRETS); do \
		test -s $$f || { echo "Missing or empty $$f (see DEV_DOC.md)."; exit 1; }; \
	done

dirs:
	mkdir -p $(DATA_DIR)/mariadb $(DATA_DIR)/wordpress

build: check
	$(COMPOSE) build

up: check dirs
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down

stop:
	$(COMPOSE) stop

restart:
	$(COMPOSE) restart

logs:
	$(COMPOSE) logs -f

ps:
	$(COMPOSE) ps -a

clean: down

# Removes containers, images, volumes and the data in $(DATA_DIR).
# The data files belong to container users (mysql, www-data), so a throwaway
# container deletes them instead of `sudo rm`.
fclean:
	$(COMPOSE) down -v --rmi all
	docker run --rm -v $(DATA_DIR):/data debian:bookworm rm -rf /data/mariadb /data/wordpress

re:
	$(MAKE) down
	$(MAKE) up
