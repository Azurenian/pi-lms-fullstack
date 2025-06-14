#!/bin/bash
# Pi-LMS Docker Deployment Script for Orange Pi 5
# This script automates the deployment process for classroom environments

set -euo pipefail

# Configuration
PROJECT_NAME="pi-lms"
DEPLOY_DIR="/opt/pi-lms"
BACKUP_DIR="/opt/pi-lms-backups"
LOG_FILE="/var/log/pi-lms-deploy.log"
ENV_FILE=".env"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "${LOG_FILE}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" | tee -a "${LOG_FILE}"
    exit 1
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1" | tee -a "${LOG_FILE}"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $1" | tee -a "${LOG_FILE}"
}

# Banner
print_banner() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    Pi-LMS Docker Deployment                 ║"
    echo "║                Orange Pi 5 Classroom Setup                  ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Check if running as correct user
check_user() {
    if [[ $EUID -eq 0 ]]; then
        error "This script should not be run as root. Run as regular user with sudo access."
    fi
    
    if ! groups $USER | grep -q '\bdocker\b'; then
        error "User $USER is not in docker group. Run: sudo usermod -aG docker $USER && newgrp docker"
    fi
}

# Check Orange Pi 5 system requirements
check_system_requirements() {
    log "Checking Orange Pi 5 system requirements..."

    # Check architecture
    ARCH=$(uname -m)
    if [[ "$ARCH" != "aarch64" ]]; then
        warning "Expected ARM64 architecture (aarch64), found: $ARCH"
    fi

    # Check Docker
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed. Install with: curl -fsSL https://get.docker.com | sh"
    fi

    # Check Docker Compose
    if ! docker compose version &> /dev/null; then
        error "Docker Compose is not installed or not working"
    fi

    # Check available memory (Orange Pi 5 should have 8GB)
    TOTAL_MEMORY=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    AVAILABLE_MEMORY=$(free -m | awk 'NR==2{printf "%.0f", $7}')
    
    if [[ $TOTAL_MEMORY -lt 6144 ]]; then
        warning "Total memory is ${TOTAL_MEMORY}MB. Orange Pi 5 should have 8GB (8192MB)"
    fi
    
    if [[ $AVAILABLE_MEMORY -lt 2048 ]]; then
        warning "Available memory is low (${AVAILABLE_MEMORY}MB). Consider closing other applications."
    fi

    # Check disk space
    AVAILABLE_SPACE=$(df -BG "$(pwd)" | awk 'NR==2{print $4}' | sed 's/G//')
    if [[ $AVAILABLE_SPACE -lt 10 ]]; then
        error "Insufficient disk space. At least 10GB required, found ${AVAILABLE_SPACE}GB"
    fi

    # Check network connectivity
    if ! ping -c 1 8.8.8.8 &> /dev/null; then
        warning "No internet connectivity. Some features may not work."
    fi

    log "System requirements check completed"
}

# Setup directory structure
setup_directories() {
    log "Setting up directory structure..."
    
    # Create data directories
    mkdir -p data/{database,media,ollama,redis,ai-temp}
    mkdir -p data/logs/{nginx,frontend,backend,ai,ollama,redis}
    mkdir -p data/ssl
    mkdir -p nginx/conf.d

    # Set proper permissions
    chmod 755 data
    chmod -R 755 data/logs
    
    log "Directory structure created"
}

# Create environment file if it doesn't exist
setup_environment() {
    log "Setting up environment configuration..."
    
    if [[ ! -f "$ENV_FILE" ]]; then
        if [[ -f ".env.production" ]]; then
            cp .env.production "$ENV_FILE"
            log "Copied .env.production to .env"
        else
            error "No environment template found. Please create .env.production first."
        fi
    fi
    
    # Check for required environment variables
    if ! grep -q "GEMINI_API_KEY.*your-gemini-api-key" "$ENV_FILE"; then
        warning "GEMINI_API_KEY appears to be set. Verify it's correct."
    else
        warning "Please update GEMINI_API_KEY in $ENV_FILE"
    fi
    
    if ! grep -q "YOUTUBE_API_KEY.*your-youtube-api-key" "$ENV_FILE"; then
        warning "YOUTUBE_API_KEY appears to be set. Verify it's correct."
    else
        warning "Please update YOUTUBE_API_KEY in $ENV_FILE"
    fi
    
    log "Environment configuration ready"
}

# Create backup of existing deployment
create_backup() {
    if [[ -f "data/database/lms-payload.db" ]] || [[ -d "data/media" ]]; then
        log "Creating backup of existing data..."
        
        BACKUP_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        BACKUP_PATH="${BACKUP_DIR}/backup_${BACKUP_TIMESTAMP}"
        
        mkdir -p "$BACKUP_PATH"
        
        # Backup database
        if [[ -f "data/database/lms-payload.db" ]]; then
            cp -r data/database "$BACKUP_PATH/"
            log "Database backed up"
        fi
        
        # Backup media files
        if [[ -d "data/media" ]]; then
            cp -r data/media "$BACKUP_PATH/"
            log "Media files backed up"
        fi
        
        # Backup environment
        if [[ -f "$ENV_FILE" ]]; then
            cp "$ENV_FILE" "$BACKUP_PATH/"
            log "Environment configuration backed up"
        fi
        
        log "Backup created at: $BACKUP_PATH"
        
        # Keep only last 5 backups
        cd "$BACKUP_DIR" && ls -t backup_* | tail -n +6 | xargs -r rm -rf
        cd - > /dev/null
    fi
}

# Build and deploy containers
deploy_containers() {
    log "Building and deploying Pi-LMS containers..."
    
    # Pull base images first
    info "Pulling base Docker images..."
    docker compose pull --ignore-pull-failures
    
    # Build application containers
    info "Building application containers..."
    docker compose build --no-cache
    
    # Stop existing containers
    info "Stopping existing containers..."
    docker compose down --remove-orphans
    
    # Start services
    info "Starting Pi-LMS services..."
    docker compose up -d
    
    log "Container deployment completed"
}

# Initialize Ollama with optimized model
setup_ollama() {
    log "Setting up Ollama with optimized model for Orange Pi 5..."
    
    # Wait for Ollama to be ready
    info "Waiting for Ollama service to start..."
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if docker compose exec -T ollama ollama --version > /dev/null 2>&1; then
            break
        fi
        
        if [[ $attempt -eq $max_attempts ]]; then
            error "Ollama failed to start after ${max_attempts} attempts"
        fi
        
        sleep 10
        ((attempt++))
    done
    
    # Pull optimized model for Orange Pi 5
    info "Pulling Llama 3.2 3B model (optimized for 8GB RAM)..."
    docker compose exec ollama ollama pull llama3.2:3b
    
    log "Ollama setup completed"
}

# Health check all services
health_check() {
    log "Performing comprehensive health check..."
    
    local services=("nginx" "frontend" "backend" "ai-services" "ollama" "redis")
    local max_attempts=20
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        local healthy_count=0
        
        info "Health check attempt ${attempt}/${max_attempts}"
        
        # Check Nginx
        if curl -f -s -m 5 http://localhost/health > /dev/null 2>&1; then
            echo "✅ Nginx: Healthy"
            ((healthy_count++))
        else
            echo "❌ Nginx: Not responding"
        fi
        
        # Check individual service health
        for service in "${services[@]}"; do
            if [[ "$service" == "nginx" ]]; then
                continue  # Already checked
            fi
            
            if docker compose ps "$service" | grep -q "healthy\|Up"; then
                echo "✅ $service: Healthy"
                ((healthy_count++))
            else
                echo "❌ $service: Not healthy"
            fi
        done
        
        if [[ $healthy_count -eq ${#services[@]} ]]; then
            log "All services are healthy!"
            return 0
        fi
        
        if [[ $attempt -eq $max_attempts ]]; then
            error "Health check failed after ${max_attempts} attempts"
        fi
        
        sleep 15
        ((attempt++))
    done
}

# Display deployment information
show_deployment_info() {
    echo
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    DEPLOYMENT SUCCESSFUL!                   ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${BLUE}Classroom Access Information:${NC}"
    echo -e "🌐 Main Application: ${GREEN}http://pilms.local${NC} or ${GREEN}http://$(hostname -I | awk '{print $1}')${NC}"
    echo -e "👨‍💼 Admin Panel: ${GREEN}http://pilms.local/admin${NC}"
    echo -e "🏥 Health Check: ${GREEN}http://pilms.local/health${NC}"
    echo
    echo -e "${BLUE}Service Status:${NC}"
    docker compose ps
    echo
    echo -e "${BLUE}Resource Usage:${NC}"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"
    echo
    echo -e "${BLUE}Useful Commands:${NC}"
    echo -e "📊 View logs: ${YELLOW}docker compose logs -f [service]${NC}"
    echo -e "🔄 Restart service: ${YELLOW}docker compose restart [service]${NC}"
    echo -e "⬇️ Stop all: ${YELLOW}docker compose down${NC}"
    echo -e "⬆️ Start all: ${YELLOW}docker compose up -d${NC}"
    echo -e "📈 Monitor: ${YELLOW}docker compose top${NC}"
}

# Main deployment function
main() {
    print_banner
    
    case "${1:-deploy}" in
        "deploy")
            log "Starting Pi-LMS deployment on Orange Pi 5"
            check_user
            check_system_requirements
            setup_directories
            setup_environment
            create_backup
            deploy_containers
            setup_ollama
            health_check
            show_deployment_info
            log "Pi-LMS deployment completed successfully!"
            ;;
        "health")
            log "Performing health check"
            health_check
            ;;
        "stop")
            log "Stopping Pi-LMS services"
            docker compose down
            log "All services stopped"
            ;;
        "restart")
            log "Restarting Pi-LMS services"
            docker compose restart
            health_check
            log "Services restarted successfully"
            ;;
        "logs")
            docker compose logs -f "${2:-}"
            ;;
        "status")
            docker compose ps
            echo
            docker stats --no-stream
            ;;
        *)
            echo "Usage: $0 {deploy|health|stop|restart|logs [service]|status}"
            echo
            echo "Commands:"
            echo "  deploy  - Full deployment with health checks"
            echo "  health  - Run health checks only"
            echo "  stop    - Stop all services"
            echo "  restart - Restart all services"
            echo "  logs    - View logs (optionally for specific service)"
            echo "  status  - Show service status and resource usage"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"