#!/bin/bash

# OpenVPN Access Server Maintenance Script
# This script provides various maintenance operations for OpenVPN

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
CONTAINER_NAME="openvpn-access-server"

# Function to print colored output
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to show usage
show_usage() {
    echo "OpenVPN Access Server Maintenance Script"
    echo ""
    echo "Usage: $0 COMMAND [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  status           Show server status and connections"
    echo "  logs             Show server logs"
    echo "  restart          Restart the OpenVPN server"
    echo "  update           Update OpenVPN server image"
    echo "  cleanup          Clean up old logs and temporary files"
    echo "  reset-admin      Reset admin password"
    echo "  list-users       List all VPN users"
    echo "  add-user         Add a new VPN user"
    echo "  remove-user      Remove a VPN user" 
    echo "  cert-info        Show certificate information"
    echo "  network-test     Test network connectivity"
    echo "  health-check     Perform comprehensive health check"
    echo ""
    echo "Options:"
    echo "  -h, --help       Show this help message"
    echo "  -f, --follow     Follow logs (for logs command)"
    echo "  -n, --lines N    Show last N lines (for logs command)"
    echo ""
    echo "Examples:"
    echo "  $0 status                    # Show status"
    echo "  $0 logs -f                   # Follow logs"
    echo "  $0 logs -n 100               # Show last 100 lines"
    echo "  $0 add-user john             # Add user 'john'"
    echo "  $0 reset-admin newpassword   # Reset admin password"
}

# Function to check if container is running
check_container() {
    if ! docker ps --format "table {{.Names}}" | grep -q "^$CONTAINER_NAME$"; then
        print_message $RED "Container $CONTAINER_NAME is not running!"
        print_message $YELLOW "Start it with: docker-compose up -d"
        exit 1
    fi
}

# Function to show server status
show_status() {
    print_message $GREEN "=== OpenVPN Access Server Status ==="
    
    # Container status
    print_message $BLUE "Container Information:"
    docker ps --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    
    # Resource usage
    print_message $BLUE "Resource Usage:"
    docker stats "$CONTAINER_NAME" --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"
    echo ""
    
    # Active connections
    print_message $BLUE "Active VPN Connections:"
    docker exec "$CONTAINER_NAME" /usr/local/openvpn_as/scripts/sacli VPNStatus 2>/dev/null || {
        print_message $YELLOW "Could not retrieve VPN status"
    }
    
    # Service status
    print_message $BLUE "Service Status:"
    docker exec "$CONTAINER_NAME" systemctl is-active openvpnas 2>/dev/null || {
        print_message $YELLOW "Could not check service status"
    }
}

# Function to show logs
show_logs() {
    local follow=false
    local lines=""
    
    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--follow)
                follow=true
                shift
                ;;
            -n|--lines)
                lines="--tail $2"
                shift 2
                ;;
            *)
                break
                ;;
        esac
    done
    
    print_message $BLUE "OpenVPN Access Server Logs:"
    
    if [ "$follow" = true ]; then
        docker logs -f $lines "$CONTAINER_NAME"
    else
        docker logs $lines "$CONTAINER_NAME"
    fi
}

# Function to restart server
restart_server() {
    print_message $BLUE "Restarting OpenVPN Access Server..."
    
    cd "$PROJECT_DIR"
    
    if command -v docker-compose &> /dev/null; then
        docker-compose restart
    else
        docker compose restart
    fi
    
    print_message $GREEN "Server restarted successfully."
}

# Function to update server
update_server() {
    print_message $BLUE "Updating OpenVPN Access Server..."
    
    cd "$PROJECT_DIR"
    
    # Pull latest image
    print_message $BLUE "Pulling latest image..."
    if command -v docker-compose &> /dev/null; then
        docker-compose pull
    else
        docker compose pull
    fi
    
    # Recreate container with new image
    print_message $BLUE "Recreating container..."
    if command -v docker-compose &> /dev/null; then
        docker-compose up -d
    else
        docker compose up -d
    fi
    
    print_message $GREEN "Server updated successfully."
}

# Function to cleanup
cleanup_server() {
    print_message $BLUE "Cleaning up OpenVPN Access Server..."
    
    # Clean old logs
    print_message $BLUE "Cleaning old logs..."
    docker exec "$CONTAINER_NAME" find /var/log -name "*.log.*" -mtime +7 -delete 2>/dev/null || {
        print_message $YELLOW "Could not clean old logs"
    }
    
    # Clean temporary files
    print_message $BLUE "Cleaning temporary files..."
    docker exec "$CONTAINER_NAME" find /tmp -type f -mtime +1 -delete 2>/dev/null || {
        print_message $YELLOW "Could not clean temporary files"
    }
    
    # Docker system cleanup
    print_message $BLUE "Cleaning Docker system..."
    docker system prune -f
    
    print_message $GREEN "Cleanup completed."
}

# Function to reset admin password
reset_admin_password() {
    local new_password=$1
    
    if [ -z "$new_password" ]; then
        read -s -p "Enter new admin password: " new_password
        echo ""
        if [ -z "$new_password" ]; then
            print_message $RED "Password cannot be empty!"
            exit 1
        fi
    fi
    
    print_message $BLUE "Resetting admin password..."
    
    # Get admin username from env file
    local admin_user="openvpn"
    if [ -f "$PROJECT_DIR/.env" ]; then
        admin_user=$(grep "^ADMIN_USERNAME=" "$PROJECT_DIR/.env" | cut -d'=' -f2 | tr -d '"' | tr -d "'")
    fi
    
    # Reset password
    docker exec -it "$CONTAINER_NAME" /usr/local/openvpn_as/scripts/sacli --user "$admin_user" SetLocalPassword <<< "$new_password" || {
        print_message $RED "Failed to reset admin password!"
        exit 1
    }
    
    print_message $GREEN "Admin password reset successfully."
}

# Function to list users
list_users() {
    print_message $BLUE "VPN Users:"
    
    docker exec "$CONTAINER_NAME" /usr/local/openvpn_as/scripts/sacli UserPropQuery 2>/dev/null | grep -E "^[a-zA-Z0-9_-]+\." | cut -d'.' -f1 | sort -u || {
        print_message $YELLOW "Could not retrieve user list"
    }
}

# Function to add user
add_user() {
    local username=$1
    
    if [ -z "$username" ]; then
        read -p "Enter username: " username
        if [ -z "$username" ]; then
            print_message $RED "Username cannot be empty!"
            exit 1
        fi
    fi
    
    print_message $BLUE "Adding user: $username"
    
    # Add user
    docker exec "$CONTAINER_NAME" /usr/local/openvpn_as/scripts/sacli --user "$username" --key "type" --value "user_connect" UserPropPut || {
        print_message $RED "Failed to add user!"
        exit 1
    }
    
    # Enable auto-login
    docker exec "$CONTAINER_NAME" /usr/local/openvpn_as/scripts/sacli --user "$username" --key "prop_autologin" --value "true" UserPropPut
    
    # Set password
    read -s -p "Enter password for $username: " password
    echo ""
    if [ -n "$password" ]; then
        docker exec -it "$CONTAINER_NAME" /usr/local/openvpn_as/scripts/sacli --user "$username" SetLocalPassword <<< "$password"
    fi
    
    print_message $GREEN "User $username added successfully."
}

# Function to remove user
remove_user() {
    local username=$1
    
    if [ -z "$username" ]; then
        read -p "Enter username to remove: " username
        if [ -z "$username" ]; then
            print_message $RED "Username cannot be empty!"
            exit 1
        fi
    fi
    
    print_message $YELLOW "WARNING: This will permanently remove user $username"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_message $BLUE "Operation cancelled."
        exit 0
    fi
    
    print_message $BLUE "Removing user: $username"
    
    # Remove user
    docker exec "$CONTAINER_NAME" /usr/local/openvpn_as/scripts/sacli --user "$username" UserPropDel || {
        print_message $RED "Failed to remove user!"
        exit 1
    }
    
    print_message $GREEN "User $username removed successfully."
}

# Function to show certificate info
show_cert_info() {
    print_message $BLUE "Certificate Information:"
    
    # Server certificate
    docker exec "$CONTAINER_NAME" openssl x509 -in /opt/openvpn-as/etc/certs/server.crt -text -noout 2>/dev/null | grep -E "(Subject:|Issuer:|Not Before:|Not After:)" || {
        print_message $YELLOW "Could not retrieve certificate information"
    }
    
    # CA certificate
    print_message $BLUE "CA Certificate:"
    docker exec "$CONTAINER_NAME" openssl x509 -in /opt/openvpn-as/etc/certs/ca.crt -text -noout 2>/dev/null | grep -E "(Subject:|Issuer:|Not Before:|Not After:)" || {
        print_message $YELLOW "Could not retrieve CA certificate information"
    }
}

# Function to test network connectivity
test_network() {
    print_message $BLUE "Network Connectivity Test:"
    
    # Test internet connectivity
    print_message $BLUE "Testing internet connectivity..."
    docker exec "$CONTAINER_NAME" ping -c 3 8.8.8.8 || {
        print_message $RED "Internet connectivity test failed!"
    }
    
    # Test DNS resolution
    print_message $BLUE "Testing DNS resolution..."
    docker exec "$CONTAINER_NAME" nslookup google.com || {
        print_message $RED "DNS resolution test failed!"
    }
    
    # Show network interfaces
    print_message $BLUE "Network interfaces:"
    docker exec "$CONTAINER_NAME" ip addr show
    
    # Show routing table
    print_message $BLUE "Routing table:"
    docker exec "$CONTAINER_NAME" ip route show
}

# Function to perform health check
health_check() {
    print_message $GREEN "=== OpenVPN Access Server Health Check ==="
    
    local issues=0
    
    # Check container status
    print_message $BLUE "Checking container status..."
    if docker ps --format "table {{.Names}}" | grep -q "^$CONTAINER_NAME$"; then
        print_message $GREEN "✓ Container is running"
    else
        print_message $RED "✗ Container is not running"
        ((issues++))
    fi
    
    # Check service status
    print_message $BLUE "Checking OpenVPN service..."
    if docker exec "$CONTAINER_NAME" systemctl is-active openvpnas &>/dev/null; then
        print_message $GREEN "✓ OpenVPN service is active"
    else
        print_message $RED "✗ OpenVPN service is not active"
        ((issues++))
    fi
    
    # Check web interface
    print_message $BLUE "Checking web interface..."
    if docker exec "$CONTAINER_NAME" curl -k -s -f https://localhost:943/ &>/dev/null; then
        print_message $GREEN "✓ Web interface is accessible"
    else
        print_message $RED "✗ Web interface is not accessible"
        ((issues++))
    fi
    
    # Check disk space
    print_message $BLUE "Checking disk space..."
    local disk_usage=$(docker exec "$CONTAINER_NAME" df / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ "$disk_usage" -lt 90 ]; then
        print_message $GREEN "✓ Disk space is adequate ($disk_usage% used)"
    else
        print_message $RED "✗ Disk space is low ($disk_usage% used)"
        ((issues++))
    fi
    
    # Check memory usage
    print_message $BLUE "Checking memory usage..."
    local memory_info=$(docker stats "$CONTAINER_NAME" --no-stream --format "{{.MemPerc}}" | sed 's/%//')
    if (( $(echo "$memory_info < 90" | bc -l) )); then
        print_message $GREEN "✓ Memory usage is normal (${memory_info}%)"
    else
        print_message $RED "✗ Memory usage is high (${memory_info}%)"
        ((issues++))
    fi
    
    # Summary
    echo ""
    if [ $issues -eq 0 ]; then
        print_message $GREEN "All health checks passed! ✓"
    else
        print_message $RED "$issues issue(s) found. Please review the above results."
    fi
}

# Main function
main() {
    local command=$1
    shift
    
    case $command in
        status)
            check_container
            show_status
            ;;
        logs)
            check_container
            show_logs "$@"
            ;;
        restart)
            restart_server
            ;;
        update)
            update_server
            ;;
        cleanup)
            check_container
            cleanup_server
            ;;
        reset-admin)
            check_container
            reset_admin_password "$1"
            ;;
        list-users)
            check_container
            list_users
            ;;
        add-user)
            check_container
            add_user "$1"
            ;;
        remove-user)
            check_container
            remove_user "$1"
            ;;
        cert-info)
            check_container
            show_cert_info
            ;;
        network-test)
            check_container
            test_network
            ;;
        health-check)
            health_check
            ;;
        -h|--help|help)
            show_usage
            ;;
        *)
            echo "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Check if command is provided
if [ $# -eq 0 ]; then
    show_usage
    exit 1
fi

# Run main function
main "$@"