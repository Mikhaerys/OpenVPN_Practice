# OpenVPN Access Server Docker Makefile
# Provides convenient commands for managing the OpenVPN deployment

.PHONY: help setup start stop restart status logs update backup restore cleanup health-check

# Default target
help: ## Show this help message
	@echo "OpenVPN Access Server Docker Commands"
	@echo "====================================="
	@echo ""
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "Examples:"
	@echo "  make setup          # Initial setup"
	@echo "  make start          # Start the server"
	@echo "  make logs-follow    # Follow logs in real-time"
	@echo "  make backup         # Create backup"

# Setup and Installation
setup: ## Run initial setup script
	@chmod +x scripts/setup.sh
	@./scripts/setup.sh

# Container Management
start: ## Start OpenVPN container
	docker-compose up -d

stop: ## Stop OpenVPN container
	docker-compose down

restart: ## Restart OpenVPN container
	docker-compose restart

status: ## Show container status and VPN connections
	@chmod +x scripts/maintenance.sh
	@./scripts/maintenance.sh status

# Logging
logs: ## Show container logs
	docker logs openvpn-access-server

logs-follow: ## Follow container logs in real-time
	docker logs -f openvpn-access-server

logs-tail: ## Show last 100 lines of logs
	@chmod +x scripts/maintenance.sh
	@./scripts/maintenance.sh logs -n 100

# Maintenance
update: ## Update OpenVPN to latest version
	@chmod +x scripts/maintenance.sh
	@./scripts/maintenance.sh update

cleanup: ## Clean up old logs and temporary files
	@chmod +x scripts/maintenance.sh
	@./scripts/maintenance.sh cleanup

health-check: ## Perform comprehensive health check
	@chmod +x scripts/maintenance.sh
	@./scripts/maintenance.sh health-check

# Backup and Restore
backup: ## Create backup of configuration and data
	@chmod +x scripts/backup.sh
	@./scripts/backup.sh

backup-compress: ## Create compressed backup
	@chmod +x scripts/backup.sh
	@./scripts/backup.sh --compress

backup-config: ## Backup only configuration files
	@chmod +x scripts/backup.sh
	@./scripts/backup.sh --config-only

restore: ## Restore from backup (requires BACKUP_PATH variable)
	@chmod +x scripts/restore.sh
	@if [ -z "$(BACKUP_PATH)" ]; then \
		echo "Error: BACKUP_PATH variable is required"; \
		echo "Usage: make restore BACKUP_PATH=backups/20241129_143022"; \
		exit 1; \
	fi
	@./scripts/restore.sh $(BACKUP_PATH)

# User Management
list-users: ## List all VPN users
	@chmod +x scripts/maintenance.sh
	@./scripts/maintenance.sh list-users

add-user: ## Add new VPN user (requires USERNAME variable)
	@chmod +x scripts/maintenance.sh
	@if [ -z "$(USERNAME)" ]; then \
		echo "Error: USERNAME variable is required"; \
		echo "Usage: make add-user USERNAME=john"; \
		exit 1; \
	fi
	@./scripts/maintenance.sh add-user $(USERNAME)

remove-user: ## Remove VPN user (requires USERNAME variable)
	@chmod +x scripts/maintenance.sh
	@if [ -z "$(USERNAME)" ]; then \
		echo "Error: USERNAME variable is required"; \
		echo "Usage: make remove-user USERNAME=john"; \
		exit 1; \
	fi
	@./scripts/maintenance.sh remove-user $(USERNAME)

reset-admin: ## Reset admin password (requires PASSWORD variable)
	@chmod +x scripts/maintenance.sh
	@if [ -z "$(PASSWORD)" ]; then \
		echo "Error: PASSWORD variable is required"; \
		echo "Usage: make reset-admin PASSWORD=newpassword"; \
		exit 1; \
	fi
	@./scripts/maintenance.sh reset-admin $(PASSWORD)

# Information and Diagnostics
cert-info: ## Show certificate information
	@chmod +x scripts/maintenance.sh
	@./scripts/maintenance.sh cert-info

network-test: ## Test network connectivity
	@chmod +x scripts/maintenance.sh
	@./scripts/maintenance.sh network-test

# Quick access to web interfaces
open-admin: ## Open admin web interface in browser (Linux/macOS)
	@echo "Opening Admin UI: https://localhost:943/admin"
	@if command -v xdg-open > /dev/null; then \
		xdg-open https://localhost:943/admin; \
	elif command -v open > /dev/null; then \
		open https://localhost:943/admin; \
	else \
		echo "Please open https://localhost:943/admin in your browser"; \
	fi

open-client: ## Open client web interface in browser (Linux/macOS)
	@echo "Opening Client UI: https://localhost:943/"
	@if command -v xdg-open > /dev/null; then \
		xdg-open https://localhost:943/; \
	elif command -v open > /dev/null; then \
		open https://localhost:943/; \
	else \
		echo "Please open https://localhost:943/ in your browser"; \
	fi

# Development and Testing
shell: ## Open shell in OpenVPN container
	docker exec -it openvpn-access-server /bin/bash

config-check: ## Validate configuration files
	@echo "Checking .env file..."
	@if [ ! -f .env ]; then \
		echo "Error: .env file not found"; \
		exit 1; \
	fi
	@echo "✓ .env file exists"
	@echo "Checking docker-compose.yml..."
	@docker-compose config > /dev/null
	@echo "✓ docker-compose.yml is valid"

# Clean up everything (DANGEROUS)
clean: ## Remove all containers, volumes, and data (DANGEROUS!)
	@echo "WARNING: This will remove all OpenVPN data!"
	@read -p "Are you sure? Type 'yes' to continue: " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		docker-compose down -v; \
		docker volume prune -f; \
		sudo rm -rf data/ logs/ config/; \
		echo "All data removed"; \
	else \
		echo "Operation cancelled"; \
	fi

# Install prerequisites (Linux only)
install-prereqs: ## Install Docker and Docker Compose (Ubuntu/Debian)
	@echo "Installing Docker and Docker Compose..."
	@sudo apt-get update
	@sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
	@curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
	@echo "deb [arch=$$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
	@sudo apt-get update
	@sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
	@sudo usermod -aG docker $$USER
	@echo "Docker installed. Please log out and log back in for group changes to take effect."