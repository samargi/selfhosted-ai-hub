# ============================================
# Intelligent Patch System
# ============================================

# Environment
ANTHROPIC_API_KEY ?= $(shell grep ANTHROPIC_API_KEY .env 2>/dev/null | cut -d '=' -f2 | tr -d ' ')
PATCHES_DIR = ./etc/patches

setup-continue: ## Setup Continue CLI and patch system
	@echo "🔧 Setting up Continue CLI..."
	@if ! command -v continue &> /dev/null; then \
		echo "Installing Continue CLI..."; \
		npm install -g continue; \
	fi
	@mkdir -p $(PATCHES_DIR)/{features,content,scripts,.continue}
	@if [ ! -f "$(PATCHES_DIR)/.continue/config.json" ]; then \
		export ANTHROPIC_API_KEY=$(ANTHROPIC_API_KEY) && \
		envsubst < $(PATCHES_DIR)/.continue/config.json.template > $(PATCHES_DIR)/.continue/config.json; \
		echo "✅ Continue CLI configured"; \
	else \
		echo "ℹ️  Continue already configured"; \
	fi
	@echo ""
	@echo "📝 Add your features to: $(PATCHES_DIR)/features/"
	@echo "💾 Add content files to: $(PATCHES_DIR)/content/"
	@echo ""

analyze-patches: ## Analyze what patches would do (dry-run)
	@echo "📊 Analyzing patches..."
	@bash $(PATCHES_DIR)/scripts/apply-patches.sh analyze

apply-patches: ## Apply all patches intelligently using AI
	@echo "🚀 Applying patches..."
	@bash $(PATCHES_DIR)/scripts/apply-patches.sh apply

validate-patches: ## Validate applied patches
	@echo "🧪 Validating patches..."
	@bash $(PATCHES_DIR)/scripts/apply-patches.sh validate

patch-diff: ## Show diff of applied patches
	@if [ -f "$(PATCHES_DIR)/applied.patch" ]; then \
		echo "📝 Applied patches diff:"; \
		echo ""; \
		cat $(PATCHES_DIR)/applied.patch; \
	else \
		echo "ℹ️  No patches applied yet. Run 'make apply-patches' first."; \
	fi

patch-clean: ## Clean temporary patch files
	@bash $(PATCHES_DIR)/scripts/apply-patches.sh clean

patch-status: ## Show patch system status
	@echo "📊 Patch System Status"
	@echo "====================="
	@echo ""
	@echo "Continue CLI: $$(command -v continue &> /dev/null && echo '✅ Installed' || echo '❌ Not installed')"
	@echo "Config: $$([ -f '$(PATCHES_DIR)/.continue/config.json' ] && echo '✅ Configured' || echo '❌ Missing')"
	@echo ""
	@echo "Features:"
	@ls -1 $(PATCHES_DIR)/features/*.yaml 2>/dev/null | sed 's|.*/||; s/\.yaml//' | sed 's/^/  • /' || echo "  (none)"
	@echo ""
	@echo "Last applied: $$([ -f '$(PATCHES_DIR)/applied.patch' ] && stat -f '%Sm' -t '%Y-%m-%d %H:%M' $(PATCHES_DIR)/applied.patch 2>/dev/null || stat -c '%y' $(PATCHES_DIR)/applied.patch 2>/dev/null | cut -d' ' -f1-2 || echo 'never')"
	@echo ""

patch-help: ## Show detailed patch system help
	@echo ""
	@echo "🔧 Intelligent Patch System"
	@echo "============================"
	@echo ""
	@echo "The patch system uses Continue CLI + Anthropic Claude Sonnet"
	@echo "to intelligently apply modifications to Open WebUI."
	@echo ""
	@echo "📚 Quick Start:"
	@echo "  1. make setup-continue       - Setup Continue CLI"
	@echo "  2. make analyze-patches      - See what will change"
	@echo "  3. make apply-patches        - Apply all patches"
	@echo "  4. docker-compose restart    - Restart with patches"
	@echo ""
	@echo "🔍 Available Commands:"
	@echo "  make setup-continue          - Setup Continue CLI and config"
	@echo "  make analyze-patches         - Analyze patches (dry-run)"
	@echo "  make apply-patches           - Apply all patches with AI"
	@echo "  make validate-patches        - Run validation checks"
	@echo "  make patch-diff              - Show unified diff"
	@echo "  make patch-clean             - Clean temporary files"
	@echo "  make patch-status            - Show system status"
	@echo "  make patch-help              - This help message"
	@echo ""
	@echo "📖 Documentation:"
	@echo "  See Agents.md for detailed architecture and development guide"
	@echo ""

# Update help to include patch commands
help: ## Show this help message
	@echo ""
	@echo "📦 Selfhosted AI Hub - Available Commands"
	@echo "=========================================="
	@echo ""
	@echo "🚀 Service Management:"
	@echo "  make start              - Start all services"
	@echo "  make stop               - Stop all services"
	@echo "  make restart <service>  - Restart specific service"
	@echo "  make delete             - Remove all containers and networks"
	@echo ""
	@echo "🔍 Monitoring:"
	@echo "  make logs <service>     - Show logs"
	@echo "  make shell <container>  - Open shell"
	@echo "  make env                - Validate config"
	@echo ""
	@echo "🔧 Intelligent Patching:"
	@echo "  make setup-continue     - Setup patch system"
	@echo "  make analyze-patches    - Analyze patches (dry-run)"
	@echo "  make apply-patches      - Apply patches with AI"
	@echo "  make validate-patches   - Validate patches"
	@echo "  make patch-help         - Patch system help"
	@echo ""
	@echo "🧪 Testing:"
	@echo "  make test-websocket     - Test WebSocket"
	@echo "  make patch-status       - Patch system status"
	@echo ""
	@echo "📚 For more info: make patch-help"
	@echo ""