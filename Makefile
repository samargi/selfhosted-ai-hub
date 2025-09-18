.DEFAULT_GOAL := help

# Makefile for managing Docker Compose services

# Basic Variables
DOCKER_COMPOSE = docker-compose

# Start the services in detached mode
start:
	$(DOCKER_COMPOSE) up -d --build --remove-orphans

# Stop the services
stop:
	$(DOCKER_COMPOSE) down

# Restart the services
restart:
	@if [ -z "$(word 2, $(MAKECMDGOALS))" ]; then \
		echo "Usage: make restart <service_name>"; exit 2; \
	else \
		$(DOCKER_COMPOSE) restart $(word 2, $(MAKECMDGOALS)); \
	fi;

# Remove all containers and networks
delete:
	$(DOCKER_COMPOSE) down --volumes

# Show logs for a specified service
logs:
	@if [ -z "$(word 2, $(MAKECMDGOALS))" ]; then \
		echo "Usage: make logs <container_name>"; exit 2; \
	else \
		$(DOCKER_COMPOSE) logs -f $(word 2, $(MAKECMDGOALS)); \
	fi;

# Validate environment and configuration
env:
	$(DOCKER_COMPOSE) config

# Run a shell in a specified container
shell:
	@container_name=$(name); \
	if [ -z "$(word 2, $(MAKECMDGOALS))" ]; then \
		echo "Usage: make shell <container_name>"; exit 2; \
	else \
		$(DOCKER_COMPOSE) exec $(word 2, $(MAKECMDGOALS)) /bin/sh; \
	fi;

# Grant necessary permissions to the certificate folder and files for HTTP access
set-permissions:
	@docker-compose exec caddy chmod -R a+r /data/caddy/pki/authorities/local

# Update all Docker images and restart services
update-all:
	$(DOCKER_COMPOSE) pull
	$(MAKE) start

# Prevent Make from treating extra arguments as separate targets
%:
	@:

# Help target to display available commands
help:
	@echo "Available Make commands:"
	@echo "  make start              - Start the services in detached mode"
	@echo "  make stop               - Stop the services"
	@echo "  make restart            - Restart the services"
	@echo "  make delete             - Remove all containers and networks"
	@echo "  make logs               - Show logs for a specified service"
	@echo "  make shell              - Run a shell in a specified container"
	@echo "  make set-permissions    - Grant necessary permissions for certs access"
	@echo "  make env                - Validate the environment/configuration"
	@echo "  make update-all         - Update all Docker images and restart services"

