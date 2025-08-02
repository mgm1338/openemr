#!/bin/bash

# OpenEMR Production-like Local Deployment Script
# This script sets up a production-like OpenEMR environment for local testing

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
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.production.yml"
ENV_FILE="$SCRIPT_DIR/.env.production"

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

# Function to generate SSL certificates
generate_ssl_certs() {
    local ssl_dir="$SCRIPT_DIR/ssl"
    
    if [ -f "$ssl_dir/server.crt" ] && [ -f "$ssl_dir/server.key" ]; then
        print_status "SSL certificates already exist"
        return
    fi
    
    print_status "Generating self-signed SSL certificates..."
    mkdir -p "$ssl_dir"
    
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$ssl_dir/server.key" \
        -out "$ssl_dir/server.crt" \
        -subj "/C=US/ST=CA/L=Local/O=OpenEMR/CN=localhost" \
        -addext "subjectAltName = DNS:localhost,IP:127.0.0.1" 2>/dev/null
    
    print_success "SSL certificates generated"
}

# Function to create environment file
create_env_file() {
    if [ ! -f "$ENV_FILE" ]; then
        print_status "Creating production environment file..."
        cat > "$ENV_FILE" << EOF
# Production environment variables
MYSQL_ROOT_PASSWORD=secure_root_pass_$(date +%Y)
MYSQL_PASSWORD=secure_openemr_pass_$(date +%Y)
OE_USER=admin
OE_PASS=secure_admin_pass_$(date +%Y)
EOF
        print_success "Environment file created at $ENV_FILE"
        print_warning "Please review and customize the passwords in $ENV_FILE"
    fi
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
    local ports=("8090" "8453" "8091" "8454" "3308")
    local busy_ports=()
    
    for port in "${ports[@]}"; do
        if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
            busy_ports+=($port)
        fi
    done
    
    if [ ${#busy_ports[@]} -ne 0 ]; then
        print_error "The following ports are busy: ${busy_ports[*]}"
        print_error "Please stop services on these ports or modify docker-compose.production.yml"
        exit 1
    fi
    print_success "All required ports are available"
}

# Function to start services
start_services() {
    print_status "Starting OpenEMR production-like deployment..."
    cd "$SCRIPT_DIR"
    
    docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d
    
    print_success "Services started successfully!"
    print_status "Waiting for services to be ready..."
    
    # Wait for services to be healthy
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if docker-compose -f "$COMPOSE_FILE" ps | grep -q "healthy"; then
            break
        fi
        echo -n "."
        sleep 2
        ((attempt++))
    done
    echo ""
    
    if [ $attempt -gt $max_attempts ]; then
        print_warning "Services may still be starting up. Check logs if issues persist."
    else
        print_success "Services are healthy and ready!"
    fi
}

# Function to show service status
show_status() {
    print_status "Production-like Service URLs:"
    echo -e "  ${GREEN}OpenEMR (Direct):${NC}     http://localhost:8090"
    echo -e "  ${GREEN}OpenEMR (Nginx):${NC}      https://localhost:8454"
    echo -e "  ${GREEN}Nginx HTTP:${NC}           http://localhost:8091 (redirects to HTTPS)"
    echo ""
    
    if [ -f "$ENV_FILE" ]; then
        print_status "Credentials (from $ENV_FILE):"
        source "$ENV_FILE"
        echo -e "  ${YELLOW}Username:${NC} $OE_USER"
        echo -e "  ${YELLOW}Password:${NC} $OE_PASS"
    else
        print_status "Default credentials:"
        echo -e "  ${YELLOW}Username:${NC} admin"
        echo -e "  ${YELLOW}Password:${NC} secure_admin_pass_$(date +%Y)"
    fi
    
    echo ""
    print_status "Database access:"
    echo -e "  ${YELLOW}Host:${NC}     localhost:3308"
    echo -e "  ${YELLOW}Database:${NC} openemr"
    echo -e "  ${YELLOW}Username:${NC} openemr"
    if [ -f "$ENV_FILE" ]; then
        source "$ENV_FILE"
        echo -e "  ${YELLOW}Password:${NC} $MYSQL_PASSWORD"
    else
        echo -e "  ${YELLOW}Password:${NC} secure_openemr_pass_$(date +%Y)"
    fi
    
    echo ""
    print_status "Features in this deployment:"
    echo -e "  ${GREEN}✓${NC} Production-grade database configuration"
    echo -e "  ${GREEN}✓${NC} Nginx reverse proxy with SSL"
    echo -e "  ${GREEN}✓${NC} Security headers and rate limiting"
    echo -e "  ${GREEN}✓${NC} Health checks and monitoring"
    echo -e "  ${GREEN}✓${NC} Proper SSL/TLS configuration"
}

# Function to stop services
stop_services() {
    print_status "Stopping OpenEMR production-like deployment..."
    cd "$SCRIPT_DIR"
    docker-compose -f "$COMPOSE_FILE" down
    print_success "Services stopped"
}

# Function to clean up everything
cleanup() {
    print_status "Cleaning up OpenEMR production-like deployment..."
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

# Function to run security checks
security_check() {
    print_status "Running basic security checks..."
    
    # Check SSL certificate
    if openssl x509 -in "$SCRIPT_DIR/ssl/server.crt" -text -noout >/dev/null 2>&1; then
        print_success "SSL certificate is valid"
    else
        print_error "SSL certificate issue detected"
    fi
    
    # Check for default passwords
    if [ -f "$ENV_FILE" ]; then
        if grep -q "secure_admin_pass_$(date +%Y)" "$ENV_FILE"; then
            print_warning "Using default admin password. Consider changing it in $ENV_FILE"
        fi
    fi
    
    print_success "Security check completed"
}

# Main script logic
case "${1:-start}" in
    "start")
        print_status "Starting OpenEMR production-like deployment..."
        check_docker
        check_ports
        create_env_file
        generate_ssl_certs
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
    "security")
        security_check
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|cleanup|security}"
        echo ""
        echo "Commands:"
        echo "  start     - Start the production-like OpenEMR deployment (default)"
        echo "  stop      - Stop the deployment"
        echo "  restart   - Restart the deployment"
        echo "  status    - Show service URLs and credentials"
        echo "  logs      - Show service logs"
        echo "  cleanup   - Stop services and remove all data"
        echo "  security  - Run basic security checks"
        exit 1
        ;;
esac