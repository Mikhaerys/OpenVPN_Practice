#!/bin/bash

# OpenVPN Access Server Docker Setup Script
# This script initializes and starts the OpenVPN Access Server

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Function to print colored output
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to check if Docker is running
check_docker() {
    print_message $BLUE "Checking Docker installation..."
    if ! command -v docker &> /dev/null; then
        print_message $RED "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_message $RED "Docker is not running. Please start Docker first."
        exit 1
    fi
    
    print_message $GREEN "Docker is installed and running."
}

# Function to check if Docker Compose is available
check_docker_compose() {
    print_message $BLUE "Checking Docker Compose installation..."
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        print_message $RED "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    print_message $GREEN "Docker Compose is available."
}

# Function to create necessary directories
create_directories() {
    print_message $BLUE "Creating necessary directories..."
    
    mkdir -p "$PROJECT_DIR/config"
    mkdir -p "$PROJECT_DIR/data"
    mkdir -p "$PROJECT_DIR/data/openvpn-as"
    mkdir -p "$PROJECT_DIR/logs"
    
    # Set proper permissions
    chmod 755 "$PROJECT_DIR/config"
    chmod 755 "$PROJECT_DIR/data"
    chmod 755 "$PROJECT_DIR/logs"
    
    print_message $GREEN "Directories created successfully."
}

# Function to check and create .env file
setup_env_file() {
    print_message $BLUE "Setting up environment file..."
    
    if [ ! -f "$PROJECT_DIR/.env" ]; then
        if [ -f "$PROJECT_DIR/.env.example" ]; then
            cp "$PROJECT_DIR/.env.example" "$PROJECT_DIR/.env"
            print_message $YELLOW "Created .env file from .env.example"
            print_message $YELLOW "Please edit .env file to customize your settings!"
        else
            print_message $RED ".env.example file not found!"
            exit 1
        fi
    else
        print_message $GREEN ".env file already exists."
    fi
}

# Function to validate environment variables
validate_env() {
    print_message $BLUE "Validating environment configuration..."
    
    source "$PROJECT_DIR/.env"
    
    # Check if critical variables are set
    if [ "$ADMIN_PASSWORD" = "changeme" ] || [ "$ADMIN_PASSWORD" = "changeme123!" ]; then
        print_message $RED "WARNING: You are using the default admin password!"
        print_message $YELLOW "Please change ADMIN_PASSWORD in the .env file for security."
        read -p "Do you want to continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    if [ "$SERVER_HOSTNAME" = "localhost" ]; then
        print_message $YELLOW "WARNING: SERVER_HOSTNAME is set to localhost."
        print_message $YELLOW "This will only work for local testing. Set your public IP/domain for remote access."
    fi
    
    print_message $GREEN "Environment validation completed."
}

# Function to pull the OpenVPN image
pull_image() {
    print_message $BLUE "Pulling OpenVPN Access Server Docker image..."
    
    source "$PROJECT_DIR/.env"
    docker pull "openvpn/openvpn-as:${OPENVPN_VERSION:-latest}"
    
    print_message $GREEN "Image pulled successfully."
}

# Function to start the OpenVPN container
start_container() {
    print_message $BLUE "Starting OpenVPN Access Server container..."
    
    cd "$PROJECT_DIR"
    
    # Use docker-compose or docker compose based on availability
    if command -v docker-compose &> /dev/null; then
        docker-compose up -d
    else
        docker compose up -d
    fi
    
    print_message $GREEN "Container started successfully."
}

# Function to wait for container to be ready
wait_for_container() {
    print_message $BLUE "Waiting for OpenVPN Access Server to be ready..."
    
    source "$PROJECT_DIR/.env"
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if docker exec openvpn-access-server test -f /opt/openvpn-as/init/as-init &> /dev/null; then
            print_message $GREEN "OpenVPN Access Server is ready!"
            break
        fi
        
        attempt=$((attempt + 1))
        echo -n "."
        sleep 5
    done
    
    if [ $attempt -eq $max_attempts ]; then
        print_message $RED "Timeout waiting for OpenVPN Access Server to be ready."
        print_message $YELLOW "Check container logs: docker logs openvpn-access-server"
        exit 1
    fi
}

# Function to display connection information
show_connection_info() {
    print_message $GREEN "=== OpenVPN Access Server Setup Complete ==="
    
    source "$PROJECT_DIR/.env"
    
    echo
    print_message $BLUE "Connection Information:"
    print_message $YELLOW "Admin Web UI: https://${SERVER_HOSTNAME}:${ADMIN_UI_PORT:-943}/admin"
    print_message $YELLOW "Client Web UI: https://${SERVER_HOSTNAME}:${CLIENT_UI_PORT:-943}/"
    print_message $YELLOW "Username: ${ADMIN_USERNAME:-openvpn}"
    print_message $YELLOW "Password: ${ADMIN_PASSWORD}"
    echo
    print_message $BLUE "OpenVPN Connection:"
    print_message $YELLOW "Server: ${SERVER_HOSTNAME}"
    print_message $YELLOW "Port: ${OPENVPN_PORT:-1194}"
    print_message $YELLOW "Protocol: ${VPN_PROTOCOL:-udp}"
    echo
    print_message $GREEN "Next Steps:"
    print_message $YELLOW "1. Access the Admin Web UI to configure your VPN server"
    print_message $YELLOW "2. Create user accounts in the Admin interface"
    print_message $YELLOW "3. Download client configuration files"
    print_message $YELLOW "4. Import configuration into OpenVPN clients"
    echo
    print_message $BLUE "Useful Commands:"
    print_message $YELLOW "View logs: docker logs openvpn-access-server"
    print_message $YELLOW "Stop server: docker-compose down"
    print_message $YELLOW "Restart server: docker-compose restart"
    print_message $YELLOW "Update server: docker-compose pull && docker-compose up -d"
}

# Main execution
main() {
    print_message $GREEN "=== OpenVPN Access Server Docker Setup ==="
    
    check_docker
    check_docker_compose
    create_directories
    setup_env_file
    validate_env
    pull_image
    start_container
    wait_for_container
    show_connection_info
    
    print_message $GREEN "Setup completed successfully!"
}

# Run main function
main "$@"