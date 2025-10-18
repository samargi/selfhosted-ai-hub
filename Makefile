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
		$(DOCKER_COMPOSE) logs --tail=100 -f $(word 2, $(MAKECMDGOALS)); \
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
		$(DOCKER_COMPOSE) exec $(word 2, $(MAKECMDGOALS)) sh -c 'bash || sh' \
	fi;

# Grant necessary permissions to the certificate folder and files for HTTP access
set-permissions:
	@docker-compose exec caddy chmod -R a+r /data/caddy/pki/authorities/local

# Update all Docker images and restart services
update-all:
	$(DOCKER_COMPOSE) pull
	$(MAKE) start

# --- Open WebUI Custom Build ---

# Build custom Open WebUI image (if custom features enabled)
build-webui:
	@echo "🔨 Building custom Open WebUI image..."
	@if [ -f "./etc/open-webui/Dockerfile" ]; then \
		$(DOCKER_COMPOSE) build open-webui; \
		echo "✅ Custom Open WebUI built successfully"; \
	else \
		echo "ℹ️  No custom Dockerfile found - using official image"; \
		echo "   See Agents.md for custom features setup"; \
	fi

# Rebuild Open WebUI with latest base image (no cache)
rebuild-webui:
	@echo "🔄 Rebuilding custom Open WebUI with latest base..."
	@if [ -f "./etc/open-webui/Dockerfile" ]; then \
		$(DOCKER_COMPOSE) pull open-webui 2>/dev/null || true; \
		$(DOCKER_COMPOSE) build --no-cache --pull open-webui; \
		$(DOCKER_COMPOSE) up -d open-webui; \
		echo "✅ Open WebUI rebuilt and restarted"; \
	else \
		echo "ℹ️  No custom Dockerfile found - pulling official image"; \
		$(DOCKER_COMPOSE) pull open-webui; \
		$(DOCKER_COMPOSE) up -d open-webui; \
	fi

# Show Open WebUI build logs
logs-webui-build:
	@echo "📋 Open WebUI build logs:"
	@$(DOCKER_COMPOSE) logs open-webui | grep -E "(patch|build|error|warning)" || echo "No build logs found"

# Test WebSocket connection (for custom features)
test-websocket:
	@echo "🔌 Testing WebSocket connection..."
	@curl -s -i -N -H "Connection: Upgrade" -H "Upgrade: websocket" \
		-H "Sec-WebSocket-Version: 13" -H "Sec-WebSocket-Key: test" \
		https://localhost/health 2>&1 | head -n 5 || echo "❌ WebSocket test failed"

# Check custom Open WebUI version
check-webui-version:
	@echo "📦 Open WebUI image info:"
	@docker images | grep "open-webui" | head -n 3

# Clean Open WebUI build cache
clean-webui-cache:
	@echo "🧹 Cleaning Open WebUI build cache..."
	@docker builder prune -f
	@echo "✅ Build cache cleaned"

# --- Open WebUI update/diff helpers ---

# Image and paths
OPENWEBUI_IMAGE ?= ghcr.io/open-webui/open-webui:main
OPENWEBUI_TMP_CTR ?= owui-tmp
OPENWEBUI_TMP_DIR ?= ./.tmp/openwebui-new
SUDO ?= sudo
OPENWEBUI_FRONTEND_DIR ?= ./etc/open-webui/build
OPENWEBUI_STATIC_DIR   ?= ./etc/open-webui/backend/static

# Internal helper: extract assets from the image into a temp dir
define _extract_openwebui_assets
	@set -e; \
	echo "[info] Pulling image $(OPENWEBUI_IMAGE)"; \
	docker pull $(OPENWEBUI_IMAGE) >/dev/null; \
	echo "[info] Creating temp container $(OPENWEBUI_TMP_CTR)"; \
	docker rm -f $(OPENWEBUI_TMP_CTR) >/dev/null 2>&1 || true; \
	docker create --name $(OPENWEBUI_TMP_CTR) $(OPENWEBUI_IMAGE) >/dev/null; \
	echo "[info] Preparing temp dir $(OPENWEBUI_TMP_DIR)"; \
	mkdir -p $(OPENWEBUI_TMP_DIR)/frontend $(OPENWEBUI_TMP_DIR)/static; \
	if docker cp $(OPENWEBUI_TMP_CTR):/app/build/. $(OPENWEBUI_TMP_DIR)/frontend/ >/dev/null 2>&1; then \
		echo "[info] Using frontend source: /app/build"; \
	elif docker cp $(OPENWEBUI_TMP_CTR):/app/frontend/dist/. $(OPENWEBUI_TMP_DIR)/frontend/ >/dev/null 2>&1; then \
		echo "[info] Using frontend source: /app/frontend/dist"; \
	else \
		echo "[error] Could not find frontend build"; \
		docker rm -f $(OPENWEBUI_TMP_CTR) >/dev/null 2>&1 || true; \
		exit 2; \
	fi; \
	if docker cp $(OPENWEBUI_TMP_CTR):/app/backend/open_webui/static/. $(OPENWEBUI_TMP_DIR)/static/ >/dev/null 2>&1; then \
		echo "[info] Copied static from /app/backend/open_webui/static"; \
	else \
		echo "[warn] /app/backend/open_webui/static not found"; \
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
	@echo ""
	@echo "📦 Selfhosted AI Hub - Available Commands"
	@echo "=========================================="
	@echo ""
	@echo "🚀 Service Management:"
	@echo "  make start              - Start all services in detached mode"
	@echo "  make stop               - Stop all services"
	@echo "  make restart <service>  - Restart specific service"
	@echo "  make delete             - Remove all containers and networks"
	@echo "  make update-all         - Update all Docker images and restart"
	@echo ""
	@echo "🔍 Monitoring & Debugging:"
	@echo "  make logs <service>     - Show logs for specific service"
	@echo "  make shell <container>  - Open shell in container"
	@echo "  make env                - Validate Docker Compose config"
	@echo ""
	@echo "🔧 Open WebUI Management:"
	@echo "  make build-webui        - Build custom Open WebUI image (if enabled)"
	@echo "  make rebuild-webui      - Rebuild with latest base (no cache)"
	@echo "  make check-webui-diff   - Preview Open WebUI updates (dry-run)"
	@echo "  make update-webui       - Sync Open WebUI assets from latest image"
	@echo "  make logs-webui-build   - Show Open WebUI build logs"
	@echo "  make check-webui-version - Show Open WebUI image version"
	@echo ""
	@echo "🧪 Testing & Utilities:"
	@echo "  make test-websocket     - Test WebSocket connection"
	@echo "  make clean-webui-cache  - Clean Docker build cache"
	@echo "  make set-permissions    - Grant permissions for certificates"
	@echo ""
	@echo "📚 Documentation:"
	@echo "  See README.md for general setup"
	@echo "  See Agents.md for custom features and architecture"
	@echo ""