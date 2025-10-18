.DEFAULT_GOAL := help

# Makefile for managing Docker Compose services

# Include local customizations if present (not in git)
-include Makefile.local

# Basic Variables
DOCKER_COMPOSE = docker-compose

UID := $(shell id -u)
GID := $(shell id -g)

# Start the services in detached mode
start:
	UID=$(UID) GID=$(GID) $(DOCKER_COMPOSE) up -d --build --remove-orphans

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
		$(DOCKER_COMPOSE) logs --tail=100 -f $(word 2, $(MAKECMDGOALS)); \
	fi;

# Validate environment and configuration
env:
	$(DOCKER_COMPOSE) config

# Run a shell in a specified container
shell:
	@if [ -z "$(word 2, $(MAKECMDGOALS))" ]; then \
		echo "Usage: make shell <container_name>"; exit 2; \
	else \
		$(DOCKER_COMPOSE) exec $(word 2, $(MAKECMDGOALS)) sh -c 'bash || sh'; \
	fi;

# Grant necessary permissions to the certificate folder
set-permissions:
	@docker-compose exec caddy chmod -R a+r /data/caddy/pki/authorities/local

# Update all Docker images and restart services
update-all:
	$(DOCKER_COMPOSE) pull
	$(MAKE) start

# Prevent Make from treating extra arguments as separate targets
%:
	@:

# Help target
help:
	@echo ""
	@echo "📦 Selfhosted AI Hub - Available Commands"
	@echo "=========================================="
	@echo ""
	@echo "🚀 Service Management:"
	@echo "  make start              - Start the services in detached mode"
	@echo "  make stop               - Stop the services"
	@echo "  make restart <service>  - Restart specific service"
	@echo "  make delete             - Remove all containers and networks"
	@echo ""
	@echo "🔍 Monitoring:"
	@echo "  make logs <service>     - Show logs for a specified service"
	@echo "  make shell <container>  - Run a shell in a specified container"
	@echo "  make env                - Validate the environment/configuration"
	@echo ""
	@echo "🔄 Updates:"
	@echo "  make update-all         - Update all Docker images and restart services"
	@echo ""
	@echo "🔧 System:"
	@echo "  make set-permissions    - Grant necessary permissions for certs access"
	@echo ""
	@if [ -f "Makefile.local" ]; then \
		echo "🎨 Custom Features (Makefile.local):"; \
		grep -E '^[a-zA-Z_-]+:.*?## .*$$' Makefile.local | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  make %-25s - %s\n", $$1, $$2}' || true; \
		echo ""; \
	else \
		echo "💡 Custom features available - copy Makefile.local.example to Makefile.local"; \
		echo ""; \
	fi
