#!/bin/bash

# OpenVPN Access Server Backup Script
# This script creates backups of OpenVPN configuration and data

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
COMPRESS=false
CONFIG_ONLY=false
RETENTION_DAYS=30

# Function to print colored output
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help           Show this help message"
    echo "  -d, --backup-dir     Backup directory (default: ./backups)"
    echo "  -c, --compress       Compress backup files"
    echo "  --config-only        Backup only configuration files"
    echo "  --retention-days     Keep backups for N days (default: 30)"
    echo ""
    echo "Examples:"
    echo "  $0                   # Basic backup"
    echo "  $0 --compress        # Compressed backup"
    echo "  $0 --config-only     # Configuration only"
    echo "  $0 -d /custom/path   # Custom backup directory"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -d|--backup-dir)
            BACKUP_DIR="$2"
            shift 2
            ;;
        -c|--compress)
            COMPRESS=true
            shift
            ;;
        --config-only)
            CONFIG_ONLY=true
            shift
            ;;
        --retention-days)
            RETENTION_DAYS="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Function to check if container is running
check_container() {
    if ! docker ps --format "table {{.Names}}" | grep -q "^$CONTAINER_NAME$"; then
        print_message $RED "Container $CONTAINER_NAME is not running!"
        print_message $YELLOW "Please start the container first: docker-compose up -d"
        exit 1
    fi
}

# Function to create backup directory
create_backup_dir() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="$BACKUP_DIR/$timestamp"
    
    mkdir -p "$backup_path"
    echo "$backup_path"
}

# Function to backup configuration
backup_configuration() {
    local backup_path=$1
    
    print_message $BLUE "Backing up OpenVPN configuration..."
    
    # Backup configuration directory
    docker cp "$CONTAINER_NAME:/opt/openvpn-as/etc" "$backup_path/" 2>/dev/null || {
        print_message $YELLOW "Warning: Could not backup /opt/openvpn-as/etc"
    }
    
    # Backup database configuration
    docker exec "$CONTAINER_NAME" /usr/local/openvpn_as/scripts/sacli ConfigQuery > "$backup_path/config_database.txt" 2>/dev/null || {
        print_message $YELLOW "Warning: Could not backup configuration database"
    }
    
    # Backup user database
    docker exec "$CONTAINER_NAME" /usr/local/openvpn_as/scripts/sacli UserPropQuery > "$backup_path/user_database.txt" 2>/dev/null || {
        print_message $YELLOW "Warning: Could not backup user database"
    }
    
    print_message $GREEN "Configuration backup completed."
}

# Function to backup data
backup_data() {
    local backup_path=$1
    
    if [ "$CONFIG_ONLY" = true ]; then
        print_message $YELLOW "Skipping data backup (config-only mode)."
        return
    fi
    
    print_message $BLUE "Backing up OpenVPN data..."
    
    # Backup temporary/runtime data
    docker cp "$CONTAINER_NAME:/opt/openvpn-as/tmp" "$backup_path/" 2>/dev/null || {
        print_message $YELLOW "Warning: Could not backup /opt/openvpn-as/tmp"
    }
    
    # Backup logs
    docker cp "$CONTAINER_NAME:/var/log" "$backup_path/logs" 2>/dev/null || {
        print_message $YELLOW "Warning: Could not backup logs"
    }
    
    print_message $GREEN "Data backup completed."
}

# Function to create metadata file
create_metadata() {
    local backup_path=$1
    local metadata_file="$backup_path/backup_metadata.txt"
    
    print_message $BLUE "Creating backup metadata..."
    
    {
        echo "OpenVPN Access Server Backup Metadata"
        echo "======================================"
        echo "Backup Date: $(date)"
        echo "Backup Path: $backup_path"
        echo "Container Name: $CONTAINER_NAME"
        echo "Config Only: $CONFIG_ONLY"
        echo "Compressed: $COMPRESS"
        echo ""
        echo "Container Information:"
        docker inspect "$CONTAINER_NAME" --format='Image: {{.Config.Image}}' 2>/dev/null || echo "Image: Unknown"
        docker inspect "$CONTAINER_NAME" --format='Created: {{.Created}}' 2>/dev/null || echo "Created: Unknown"
        echo ""
        echo "OpenVPN Version:"
        docker exec "$CONTAINER_NAME" /usr/local/openvpn_as/scripts/sacli version 2>/dev/null || echo "Version: Unknown"
        echo ""
        echo "Backup Contents:"
        find "$backup_path" -type f -exec basename {} \; 2>/dev/null | sort
    } > "$metadata_file"
    
    print_message $GREEN "Metadata created."
}

# Function to compress backup
compress_backup() {
    local backup_path=$1
    local parent_dir=$(dirname "$backup_path")
    local backup_name=$(basename "$backup_path")
    
    if [ "$COMPRESS" = true ]; then
        print_message $BLUE "Compressing backup..."
        
        cd "$parent_dir"
        tar -czf "${backup_name}.tar.gz" "$backup_name"
        
        if [ $? -eq 0 ]; then
            rm -rf "$backup_name"
            print_message $GREEN "Backup compressed: ${backup_path}.tar.gz"
        else
            print_message $RED "Compression failed!"
            exit 1
        fi
    fi
}

# Function to cleanup old backups
cleanup_old_backups() {
    if [ "$RETENTION_DAYS" -gt 0 ]; then
        print_message $BLUE "Cleaning up backups older than $RETENTION_DAYS days..."
        
        # Find and remove old backup directories
        find "$BACKUP_DIR" -maxdepth 1 -type d -name "20*" -mtime +$RETENTION_DAYS -exec rm -rf {} \; 2>/dev/null || true
        
        # Find and remove old backup archives
        find "$BACKUP_DIR" -maxdepth 1 -name "*.tar.gz" -mtime +$RETENTION_DAYS -exec rm -f {} \; 2>/dev/null || true
        
        print_message $GREEN "Cleanup completed."
    fi
}

# Function to show backup summary
show_summary() {
    local backup_path=$1
    
    print_message $GREEN "=== Backup Summary ==="
    
    if [ "$COMPRESS" = true ]; then
        local backup_file="${backup_path}.tar.gz"
        if [ -f "$backup_file" ]; then
            local size=$(du -h "$backup_file" | cut -f1)
            print_message $YELLOW "Backup File: $backup_file"
            print_message $YELLOW "Size: $size"
        fi
    else
        if [ -d "$backup_path" ]; then
            local size=$(du -sh "$backup_path" | cut -f1)
            local files=$(find "$backup_path" -type f | wc -l)
            print_message $YELLOW "Backup Directory: $backup_path"
            print_message $YELLOW "Size: $size"
            print_message $YELLOW "Files: $files"
        fi
    fi
    
    print_message $GREEN "Backup completed successfully!"
}

# Main function
main() {
    print_message $GREEN "=== OpenVPN Access Server Backup ==="
    
    # Check prerequisites
    check_container
    
    # Create backup
    local backup_path=$(create_backup_dir)
    print_message $BLUE "Creating backup in: $backup_path"
    
    backup_configuration "$backup_path"
    backup_data "$backup_path"
    create_metadata "$backup_path"
    compress_backup "$backup_path"
    cleanup_old_backups
    
    # Show summary
    show_summary "$backup_path"
}

# Run main function
main "$@"