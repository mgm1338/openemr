# OpenEMR Local Deployment

This directory contains scripts and configuration files for deploying OpenEMR locally without conflicts with project updates.

## Quick Start

```bash
# 1. Copy environment file and customize passwords
cp .env.example .env
# Edit .env with your preferred passwords and ports

# 2. Start the local deployment
./deploy.sh start

# 3. Access OpenEMR at:
# - HTTP: http://localhost:8080 (or your custom HTTP_PORT)
# - HTTPS: https://localhost:8443 (or your custom HTTPS_PORT)  
# - phpMyAdmin: http://localhost:8081 (or your custom PHPMYADMIN_PORT)
```

## Features

- **Isolated Environment**: Uses custom ports and container names to avoid conflicts
- **Persistent Data**: Database and application data persist between restarts
- **Development Ready**: Includes phpMyAdmin and development tools
- **Update Safe**: Won't conflict with git pulls or project updates

## Commands

```bash
./deploy.sh start     # Start the deployment (builds assets if needed)
./deploy.sh stop      # Stop all services
./deploy.sh restart   # Restart all services
./deploy.sh status    # Show service URLs and credentials
./deploy.sh logs      # Show live logs from all services
./deploy.sh cleanup   # Stop and remove all data (fresh start)
./deploy.sh build     # Build OpenEMR assets only
```

## Configuration

### Environment Variables

The deployment uses `.env` files for configuration. Copy the example files and customize:

```bash
# Development environment
cp .env.example .env

# Production-like environment  
cp .env.production.example .env.production
```

### Default Credentials (if no .env file)

- **OpenEMR Admin**: admin / admin_password
- **Database**: openemr / openemr_user_pass
- **phpMyAdmin**: openemr / openemr_user_pass

## Port Configuration

| Service | Port | Purpose |
|---------|------|---------|
| 8080 | HTTP | OpenEMR web interface |
| 8443 | HTTPS | OpenEMR secure web interface |
| 8081 | HTTP | phpMyAdmin database admin |
| 3307 | MySQL | Direct database access |

## Directory Structure

```
local-deploy/
├── docker-compose.local.yml  # Docker composition for local deployment
├── deploy.sh                 # Main deployment script
└── README.md                 # This file
```

## Customization

### Changing Ports

Edit `docker-compose.local.yml` and modify the port mappings:

```yaml
ports:
  - "8080:80"    # Change 8080 to your preferred port
  - "8443:443"   # Change 8443 to your preferred HTTPS port
```

### Changing Passwords

Update the environment variables in `docker-compose.local.yml`:

```yaml
environment:
  MYSQL_ROOT_PASSWORD: your_new_root_password
  MYSQL_PASSWORD: your_new_user_password
  OE_PASS: your_new_admin_password
```

### Adding Services

You can extend the docker-compose.local.yml to add additional services like:
- Redis for caching
- Elasticsearch for search
- Additional databases
- Development tools

## Troubleshooting

### Port Conflicts

If ports are busy, either:
1. Stop the conflicting services
2. Change ports in `docker-compose.local.yml`

### Docker Issues

```bash
# Check Docker status
docker info

# View running containers
docker ps

# Check service logs
./deploy.sh logs
```

### Reset Everything

For a completely fresh start:

```bash
./deploy.sh cleanup
./deploy.sh start
```

## Development Workflow

1. **Initial Setup**:
   ```bash
   ./deploy.sh start
   ```

2. **Daily Development**:
   - OpenEMR runs at http://localhost:8080
   - Code changes are automatically reflected
   - Database persists between sessions

3. **Updating Project**:
   ```bash
   git pull origin master
   ./deploy.sh build    # Rebuild assets if needed
   ./deploy.sh restart  # Restart services
   ```

4. **Database Management**:
   - Use phpMyAdmin at http://localhost:8081
   - Or connect directly to localhost:3307

## Integration with Project Updates

This deployment is designed to:
- Use a separate directory (`local-deploy/`) that can be git-ignored
- Use different ports to avoid conflicts with official Docker setups
- Maintain its own Docker volumes and networks
- Not interfere with the main project's Docker configurations

## Security Notes

- This setup is for **development only**
- Default passwords should be changed for any non-local deployment
- The setup includes development tools that shouldn't be used in production
- HTTPS uses self-signed certificates (browser warnings are normal)