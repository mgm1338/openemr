#!/bin/bash

# OpenEMR Local Deployment Script
# This script sets up a local OpenEMR development environment
# that won't conflict with project updates

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.local.yml"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if Docker is running
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker Desktop and try again."
        exit 1
    fi
    print_success "Docker is running"
}

# Function to check if ports are available
check_ports() {
    # Load environment variables if .env exists
    if [ -f "$SCRIPT_DIR/.env" ]; then
        source "$SCRIPT_DIR/.env"
    fi
    
    local ports=("${HTTP_PORT:-8080}" "${HTTPS_PORT:-8443}" "${PHPMYADMIN_PORT:-8081}" "${MYSQL_PORT:-3307}")
    local busy_ports=()
    
    for port in "${ports[@]}"; do
        if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
            busy_ports+=($port)
        fi
    done
    
    if [ ${#busy_ports[@]} -ne 0 ]; then
        print_error "The following ports are busy: ${busy_ports[*]}"
        print_error "Please stop services on these ports or customize ports in .env file"
        exit 1
    fi
    print_success "All required ports are available"
}

# Function to build OpenEMR assets
build_assets() {
    print_status "Building OpenEMR assets..."
    cd "$PROJECT_ROOT"
    
    if [ ! -f "composer.json" ]; then
        print_error "composer.json not found. Are you in the OpenEMR project root?"
        exit 1
    fi
    
    # Check if Node.js is available
    if ! command -v npm &> /dev/null; then
        print_warning "npm not found. Skipping asset build. You may need to build assets manually."
        return
    fi
    
    # Install dependencies and build
    print_status "Installing composer dependencies..."
    composer install --no-dev --optimize-autoloader
    
    print_status "Installing npm dependencies..."
    npm install
    
    print_status "Building assets..."
    npm run build
    
    print_status "Optimizing autoloader..."
    composer dump-autoload -o
    
    print_success "Assets built successfully"
}

# Function to start services
start_services() {
    print_status "Starting OpenEMR local deployment..."
    cd "$SCRIPT_DIR"
    
    docker-compose -f "$COMPOSE_FILE" up -d
    
    print_success "Services started successfully!"
    print_status "Waiting for services to be ready..."
    sleep 10
}

# Function to show service status
show_status() {
    # Load environment variables if .env exists
    if [ -f "$SCRIPT_DIR/.env" ]; then
        source "$SCRIPT_DIR/.env"
    fi
    
    local http_port=${HTTP_PORT:-8080}
    local https_port=${HTTPS_PORT:-8443}
    local phpmyadmin_port=${PHPMYADMIN_PORT:-8081}
    local mysql_port=${MYSQL_PORT:-3307}
    local oe_user=${OE_USER:-admin}
    local oe_pass=${OE_PASS:-admin_password}
    local mysql_user=${MYSQL_USER:-openemr}
    local mysql_pass=${MYSQL_PASSWORD:-openemr_user_pass}
    
    print_status "Service URLs:"
    echo -e "  ${GREEN}OpenEMR Application:${NC} http://localhost:$http_port"
    echo -e "  ${GREEN}OpenEMR HTTPS:${NC}       https://localhost:$https_port"
    echo -e "  ${GREEN}phpMyAdmin:${NC}          http://localhost:$phpmyadmin_port"
    echo ""
    print_status "Credentials:"
    echo -e "  ${YELLOW}Username:${NC} $oe_user"
    echo -e "  ${YELLOW}Password:${NC} $oe_pass"
    echo ""
    print_status "Database access:"
    echo -e "  ${YELLOW}Host:${NC}     localhost:$mysql_port"
    echo -e "  ${YELLOW}Database:${NC} openemr"
    echo -e "  ${YELLOW}Username:${NC} $mysql_user"
    echo -e "  ${YELLOW}Password:${NC} $mysql_pass"
    echo ""
    if [ ! -f "$SCRIPT_DIR/.env" ]; then
        print_warning "No .env file found. Copy .env.example to .env and customize passwords."
    fi
}

# Function to stop services
stop_services() {
    print_status "Stopping OpenEMR local deployment..."
    cd "$SCRIPT_DIR"
    docker-compose -f "$COMPOSE_FILE" down
    print_success "Services stopped"
}

# Function to clean up everything
cleanup() {
    print_status "Cleaning up OpenEMR local deployment..."
    cd "$SCRIPT_DIR"
    docker-compose -f "$COMPOSE_FILE" down -v --remove-orphans
    docker volume prune -f
    print_success "Cleanup completed"
}

# Function to show logs
show_logs() {
    cd "$SCRIPT_DIR"
    docker-compose -f "$COMPOSE_FILE" logs -f
}

# Main script logic
case "${1:-start}" in
    "start")
        print_status "Starting OpenEMR local deployment..."
        check_docker
        check_ports
        build_assets
        start_services
        show_status
        ;;
    "stop")
        stop_services
        ;;
    "restart")
        stop_services
        sleep 2
        check_docker
        check_ports
        start_services
        show_status
        ;;
    "status")
        show_status
        ;;
    "logs")
        show_logs
        ;;
    "cleanup")
        cleanup
        ;;
    "build")
        build_assets
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|cleanup|build}"
        echo ""
        echo "Commands:"
        echo "  start    - Start the local OpenEMR deployment (default)"
        echo "  stop     - Stop the deployment"
        echo "  restart  - Restart the deployment"
        echo "  status   - Show service URLs and credentials"
        echo "  logs     - Show service logs"
        echo "  cleanup  - Stop services and remove all data"
        echo "  build    - Build OpenEMR assets only"
        exit 1
        ;;
esac