.RECIPEPREFIX := >
COMPOSE = docker compose --env-file srcs/.env -f srcs/docker-compose.yml

.PHONY: all build up down stop restart logs ps clean re

all: up

build:
>$(COMPOSE) build

up:
>$(COMPOSE) up -d --build

down:
>$(COMPOSE) down

stop:
>$(COMPOSE) stop

restart:
>$(COMPOSE) restart

logs:
>$(COMPOSE) logs -f

ps:
>$(COMPOSE) ps -a

clean: down

re:
>$(MAKE) down
>$(MAKE) up
