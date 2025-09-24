.DEFAULT_GOAL := help

# Makefile for managing Docker Compose services

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

# --- Open WebUI update/diff helpers ---

# Image and paths
OPENWEBUI_IMAGE ?= ghcr.io/open-webui/open-webui:main
OPENWEBUI_TMP_CTR ?= owui-tmp
OPENWEBUI_TMP_DIR ?= ./.tmp/openwebui-new
SUDO ?= sudo
OPENWEBUI_FRONTEND_DIR ?= ./etc/open-webui/build
OPENWEBUI_STATIC_DIR   ?= ./etc/open-webui/backend/static

# Internal helper: extract assets from the image into a temp dir
# - Detects /app/build or /app/frontend/dist as the frontend build source
# - Always extracts /app/backend/static to tmp static dir
define _extract_openwebui_assets
	@set -e; \
	echo "[info] Pulling image $(OPENWEBUI_IMAGE)"; \
	docker pull $(OPENWEBUI_IMAGE) >/dev/null; \
	echo "[info] Creating temp container $(OPENWEBUI_TMP_CTR)"; \
	docker rm -f $(OPENWEBUI_TMP_CTR) >/dev/null 2>&1 || true; \
	docker create --name $(OPENWEBUI_TMP_CTR) $(OPENWEBUI_IMAGE) >/dev/null; \
	echo "[info] Preparing temp dir $(OPENWEBUI_TMP_DIR)"; \
	mkdir -p $(OPENWEBUI_TMP_DIR)/frontend $(OPENWEBUI_TMP_DIR)/static; \
	# Try copy /app/build first, then /app/frontend/dist — works even if container is stopped
	if docker cp $(OPENWEBUI_TMP_CTR):/app/build/. $(OPENWEBUI_TMP_DIR)/frontend/ >/dev/null 2>&1; then \
		echo "[info] Using frontend source: /app/build"; \
	elif docker cp $(OPENWEBUI_TMP_CTR):/app/frontend/dist/. $(OPENWEBUI_TMP_DIR)/frontend/ >/dev/null 2>&1; then \
		echo "[info] Using frontend source: /app/frontend/dist"; \
	else \
		echo "[error] Could not find frontend build (looked at /app/build and /app/frontend/dist)"; \
		echo "        Please inspect the container paths manually."; \
		docker rm -f $(OPENWEBUI_TMP_CTR) >/dev/null 2>&1 || true; \
		exit 2; \
	fi; \
	# Static files (optional)
	if docker cp $(OPENWEBUI_TMP_CTR):/app/backend/open_webui/static/. $(OPENWEBUI_TMP_DIR)/static/ >/dev/null 2>&1; then \
		echo "[info] Copied static from /app/backend/open_webui/static"; \
	else \
		echo "[warn] /app/backend/open_webui/static not found in image; continuing without static assets"; \
	fi; \
	docker rm -f $(OPENWEBUI_TMP_CTR) >/dev/null 2>&1 || true; \
	echo "[info] Assets extracted to $(OPENWEBUI_TMP_DIR)"
endef

# Show what would change (no file modifications)
check-webui-diff:
	@echo "[info] Checking diff between image assets and $(OPENWEBUI_FRONTEND_DIR)"
	$(call _extract_openwebui_assets)
	@set -e; \
	echo "[info] Comparing FRONTEND (dry-run)"; \
	mkdir -p $(OPENWEBUI_FRONTEND_DIR) $(OPENWEBUI_STATIC_DIR); \
	if command -v rsync >/dev/null 2>&1; then \
		rsync -a --delete --dry-run "$(OPENWEBUI_TMP_DIR)/frontend/" "$(OPENWEBUI_FRONTEND_DIR)/" | sed 's/^/[rsync] /'; \
		echo "[info] Comparing STATIC (dry-run)"; \
		rsync -a --delete --dry-run "$(OPENWEBUI_TMP_DIR)/static/" "$(OPENWEBUI_STATIC_DIR)/" | sed 's/^/[rsync] /'; \
	else \
		echo "[warn] rsync not found; falling back to diff -qr"; \
		diff -qr "$(OPENWEBUI_TMP_DIR)/frontend" "$(OPENWEBUI_FRONTEND_DIR)" || true; \
		diff -qr "$(OPENWEBUI_TMP_DIR)/static" "$(OPENWEBUI_STATIC_DIR)" || true; \
	fi; \
	echo "[info] Done. Review the lines above for additions/deletions."

# Apply the update (synchronize files; removes files not in image)
update-webui:
	@echo "[info] Updating $(OPENWEBUI_FRONTEND_DIR) and $(OPENWEBUI_STATIC_DIR) from image"
	$(call _extract_openwebui_assets)
	@set -e; \
	$(SUDO) mkdir -p "$(OPENWEBUI_FRONTEND_DIR)" "$(OPENWEBUI_STATIC_DIR)"; \
	if command -v rsync >/dev/null 2>&1; then \
		$(SUDO) rsync -a --delete "$(OPENWEBUI_TMP_DIR)/frontend/" "$(OPENWEBUI_FRONTEND_DIR)/"; \
		$(SUDO) rsync -a --delete "$(OPENWEBUI_TMP_DIR)/static/"   "$(OPENWEBUI_STATIC_DIR)/"; \
	else \
		(cd "$(OPENWEBUI_TMP_DIR)/frontend" && tar cf - .) | $(SUDO) tar xpf - -C "$(OPENWEBUI_FRONTEND_DIR)"; \
		(cd "$(OPENWEBUI_TMP_DIR)/static"   && tar cf - .) | $(SUDO) tar xpf - -C "$(OPENWEBUI_STATIC_DIR)"; \
	fi; \
	echo "[info] Update complete."

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
	@echo "  make check-webui-diff   - Preview changes between image assets and local frontend/static (dry-run)"
	@echo "  make update-webui       - Sync local frontend/static from the latest image assets (apply changes)"

