#!/bin/bash

# OpenVPN Access Server Restore Script
# This script restores OpenVPN configuration and data from backups

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Default values
BACKUP_DIR="$PROJECT_DIR/backups"
CONTAINER_NAME="openvpn-access-server"
FORCE=false
CONFIG_ONLY=false

# Function to print colored output
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS] BACKUP_PATH"
    echo ""
    echo "Arguments:"
    echo "  BACKUP_PATH          Path to backup directory or archive"
    echo ""
    echo "Options:"
    echo "  -h, --help           Show this help message"
    echo "  -f, --force          Force restore without confirmation"
    echo "  --config-only        Restore only configuration files"
    echo ""
    echo "Examples:"
    echo "  $0 backups/20241129_143022                    # Restore from directory"
    echo "  $0 backups/20241129_143022.tar.gz            # Restore from archive"
    echo "  $0 --config-only backups/20241129_143022     # Config only"
    echo "  $0 --force backups/20241129_143022           # No confirmation"
}

# Parse command line arguments
BACKUP_PATH=""
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        --config-only)
            CONFIG_ONLY=true
            shift
            ;;
        -*)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
        *)
            if [ -z "$BACKUP_PATH" ]; then
                BACKUP_PATH="$1"
            else
                echo "Error: Multiple backup paths specified"
                show_usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Check if backup path is provided
if [ -z "$BACKUP_PATH" ]; then
    echo "Error: Backup path is required"
    show_usage
    exit 1
fi

# Function to check if container exists
check_container() {
    if ! docker ps -a --format "table {{.Names}}" | grep -q "^$CONTAINER_NAME$"; then
        print_message $RED "Container $CONTAINER_NAME does not exist!"
        print_message $YELLOW "Please create the container first: docker-compose up -d"
        exit 1
    fi
}

# Function to extract backup if needed
extract_backup() {
    local backup_path=$1
    
    if [[ "$backup_path" == *.tar.gz ]]; then
        print_message $BLUE "Extracting backup archive..."
        
        local extract_dir="${backup_path%.tar.gz}"
        local backup_dir=$(dirname "$backup_path")
        
        cd "$backup_dir"
        tar -xzf "$(basename "$backup_path")"
        
        if [ $? -eq 0 ]; then
            print_message $GREEN "Archive extracted to: $extract_dir"
            echo "$extract_dir"
        else
            print_message $RED "Failed to extract archive!"
            exit 1
        fi
    else
        echo "$backup_path"
    fi
}

# Function to validate backup
validate_backup() {
    local backup_path=$1
    
    print_message $BLUE "Validating backup..."
    
    if [ ! -d "$backup_path" ]; then
        print_message $RED "Backup directory does not exist: $backup_path"
        exit 1
    fi
    
    # Check for essential backup files
    local has_config=false
    local has_metadata=false
    
    if [ -d "$backup_path/etc" ] || [ -f "$backup_path/config_database.txt" ]; then
        has_config=true
    fi
    
    if [ -f "$backup_path/backup_metadata.txt" ]; then
        has_metadata=true
    fi
    
    if [ "$has_config" = false ]; then
        print_message $RED "No configuration files found in backup!"
        exit 1
    fi
    
    if [ "$has_metadata" = true ]; then
        print_message $GREEN "Found backup metadata:"
        cat "$backup_path/backup_metadata.txt" | head -10
        echo ""
    fi
    
    print_message $GREEN "Backup validation passed."
}

# Function to confirm restore
confirm_restore() {
    if [ "$FORCE" = true ]; then
        return 0
    fi
    
    print_message $YELLOW "WARNING: This will overwrite the current OpenVPN configuration!"
    print_message $YELLOW "The container will be stopped and restarted during the process."
    echo ""
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_message $BLUE "Restore cancelled."
        exit 0
    fi
}

# Function to stop container
stop_container() {
    print_message $BLUE "Stopping OpenVPN container..."
    
    if docker ps --format "table {{.Names}}" | grep -q "^$CONTAINER_NAME$"; then
        docker stop "$CONTAINER_NAME"
        print_message $GREEN "Container stopped."
    else
        print_message $YELLOW "Container was not running."
    fi
}

# Function to restore configuration
restore_configuration() {
    local backup_path=$1
    
    print_message $BLUE "Restoring configuration..."
    
    # Restore configuration directory
    if [ -d "$backup_path/etc" ]; then
        docker cp "$backup_path/etc/." "$CONTAINER_NAME:/opt/openvpn-as/etc/"
        print_message $GREEN "Configuration directory restored."
    fi
    
    # Restore configuration database
    if [ -f "$backup_path/config_database.txt" ]; then
        print_message $BLUE "Restoring configuration database..."
        # This would require the container to be running and proper sacli commands
        print_message $YELLOW "Note: Configuration database restore requires manual intervention."
        print_message $YELLOW "File available at: $backup_path/config_database.txt"
    fi
    
    # Restore user database
    if [ -f "$backup_path/user_database.txt" ]; then
        print_message $BLUE "Restoring user database..."
        print_message $YELLOW "Note: User database restore requires manual intervention."
        print_message $YELLOW "File available at: $backup_path/user_database.txt"
    fi
}

# Function to restore data
restore_data() {
    local backup_path=$1
    
    if [ "$CONFIG_ONLY" = true ]; then
        print_message $YELLOW "Skipping data restore (config-only mode)."
        return
    fi
    
    print_message $BLUE "Restoring data..."
    
    # Restore temporary/runtime data
    if [ -d "$backup_path/tmp" ]; then
        docker cp "$backup_path/tmp/." "$CONTAINER_NAME:/opt/openvpn-as/tmp/"
        print_message $GREEN "Runtime data restored."
    fi
    
    # Note: Logs are typically not restored to avoid confusion
    if [ -d "$backup_path/logs" ]; then
        print_message $YELLOW "Log files found in backup but not restored (to avoid confusion)."
        print_message $YELLOW "Logs available at: $backup_path/logs"
    fi
}

# Function to start container
start_container() {
    print_message $BLUE "Starting OpenVPN container..."
    
    cd "$PROJECT_DIR"
    
    # Use docker-compose or docker compose based on availability
    if command -v docker-compose &> /dev/null; then
        docker-compose up -d
    else
        docker compose up -d
    fi
    
    print_message $GREEN "Container started."
}

# Function to wait for container readiness
wait_for_container() {
    print_message $BLUE "Waiting for OpenVPN Access Server to be ready..."
    
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if docker exec "$CONTAINER_NAME" test -f /opt/openvpn-as/init/as-init &> /dev/null; then
            print_message $GREEN "OpenVPN Access Server is ready!"
            return 0
        fi
        
        attempt=$((attempt + 1))
        echo -n "."
        sleep 5
    done
    
    echo ""
    print_message $YELLOW "Warning: Timeout waiting for OpenVPN Access Server to be ready."
    print_message $YELLOW "Check container logs: docker logs $CONTAINER_NAME"
    return 1
}

# Function to show restore summary
show_summary() {
    local backup_path=$1
    
    print_message $GREEN "=== Restore Summary ==="
    print_message $YELLOW "Backup Source: $backup_path"
    print_message $YELLOW "Container: $CONTAINER_NAME"
    print_message $YELLOW "Config Only: $CONFIG_ONLY"
    
    # Show connection info
    source "$PROJECT_DIR/.env" 2>/dev/null || true
    echo ""
    print_message $BLUE "Connection Information:"
    print_message $YELLOW "Admin Web UI: https://${SERVER_HOSTNAME:-localhost}:${ADMIN_UI_PORT:-943}/admin"
    print_message $YELLOW "Client Web UI: https://${SERVER_HOSTNAME:-localhost}:${CLIENT_UI_PORT:-943}/"
    
    print_message $GREEN "Restore completed successfully!"
    print_message $YELLOW "Please verify the configuration in the Admin Web UI."
}

# Function to cleanup extracted files
cleanup() {
    if [ -n "$EXTRACTED_PATH" ] && [ "$EXTRACTED_PATH" != "$BACKUP_PATH" ]; then
        print_message $BLUE "Cleaning up extracted files..."
        rm -rf "$EXTRACTED_PATH"
    fi
}

# Main function
main() {
    print_message $GREEN "=== OpenVPN Access Server Restore ==="
    
    # Check prerequisites
    check_container
    
    # Extract backup if needed
    local restore_path=$(extract_backup "$BACKUP_PATH")
    if [ "$restore_path" != "$BACKUP_PATH" ]; then
        EXTRACTED_PATH="$restore_path"
        trap cleanup EXIT
    fi
    
    # Validate backup
    validate_backup "$restore_path"
    
    # Confirm restore
    confirm_restore
    
    # Perform restore
    stop_container
    restore_configuration "$restore_path"
    restore_data "$restore_path"
    start_container
    
    # Wait for readiness and show summary
    if wait_for_container; then
        show_summary "$restore_path"
    else
        print_message $YELLOW "Restore completed but container may need manual intervention."
    fi
}

# Run main function
main "$@"