COMPOSE = docker compose -f srcs/docker-compose.yml

DATA = /home/$(USER)/data

all: up

up:
	mkdir -p $(DATA)/mariadb
	mkdir -p $(DATA)/wordpress
	$(COMPOSE) up --build -d

down:
	$(COMPOSE) down

clean: down

fclean: clean
	$(COMPOSE) down -v --rmi all
	sudo rm -rf $(DATA)

re: fclean all

.PHONY: all up down clean fclean re
