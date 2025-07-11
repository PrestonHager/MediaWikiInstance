#!/bin/bash

# MediaWiki Docker Installation Script
set -e

# Default values
ADMIN_USER="Admin"
WIKI_NAME="Wiki"
ADMIN_PASSWORD=""
COMPOSE_CMD=""
NEED_SUDO=""
SUDO_CACHED=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --admin-user=*)
        ADMIN_USER="${1#*=}"
        ;;
        --admin-password=*)
        ADMIN_PASSWORD="${1#*=}"
        ;;
        --wiki-name=*)
        WIKI_NAME="${1#*=}"
        ;;
        *)
        echo "Unknown option: $1"
        exit 1
        ;;
    esac
    shift
done

# Get admin password if not provided
if [ -z "$ADMIN_PASSWORD" ]; then
    read -sp "Enter admin password (for $WIKI_NAME): " ADMIN_PASSWORD
    echo
fi

# Cache sudo credentials
cache_sudo() {
    if [ $SUDO_CACHED -eq 0 ] && [ -n "$SUDO_PREFIX" ]; then
        echo "Caching sudo credentials..."
        sudo -v
        SUDO_CACHED=1
        
        # Refresh sudo in background
        while true; do
            sudo -v
            sleep 60
        done &
        SUDO_REFRESHER_PID=$!
        trap 'kill $SUDO_REFRESHER_PID' EXIT
    fi
}

# Determine container runtime
detect_runtime() {
    if command -v docker &> /dev/null; then
        if docker compose version &> /dev/null; then
            echo "docker compose"
            return
        fi
    fi
    
    if command -v podman &> /dev/null; then
        if podman compose version &> /dev/null; then
            echo "podman compose"
            return
        fi
    fi
    
    echo "none"
}

# Check for sudo requirements
check_sudo() {
    local runtime="$1"
    if [[ "$runtime" == "docker compose" ]]; then
        if ! docker info &> /dev/null; then
            echo "sudo"
        fi
    elif [[ "$runtime" == "podman compose" ]]; then
        if ! podman info &> /dev/null; then
            echo "sudo"
        fi
    fi
}

# Detect container runtime
RUNTIME=$(detect_runtime)
if [[ "$RUNTIME" == "none" ]]; then
    echo "Error: No compatible container runtime found."
    echo "Please install either:"
    echo "1. Docker with Compose plugin (docker compose)"
    echo "2. Podman with Compose plugin (podman compose)"
    exit 1
fi

# Check if sudo is needed
SUDO_REQUIRED=$(check_sudo "$RUNTIME")
if [ -n "$SUDO_REQUIRED" ]; then
    SUDO_PREFIX="sudo "
else
    SUDO_PREFIX=""
fi

# Create initial compose file without LocalSettings mount
cat > compose-initial.yaml <<EOF
# Docker compose file for MediaWiki (Initial Setup)

services:
  mediawiki:
    image: mediawiki:latest
    container_name: mediawiki-initial
    ports:
      - "8080:80"
    depends_on:
      db:
        condition: service_healthy
    environment:
      - MEDIAWIKI_DB_TYPE=mysql
      - MEDIAWIKI_DB_HOST=db
      - MEDIAWIKI_DB_NAME=mediawiki
      - MEDIAWIKI_DB_USER=mediawikiuser
      - MEDIAWIKI_DB_PASSWORD=mediawikipassword
    volumes:
      - ./Loftia:/var/www/html/skins/Loftia

  db:
    image: mariadb:latest
    container_name: db-initial
    environment:
      - MYSQL_ROOT_PASSWORD=rootpassword
      - MYSQL_DATABASE=mediawiki
      - MYSQL_USER=mediawikiuser
      - MYSQL_PASSWORD=mediawikipassword
    volumes:
      - db_data:/var/lib/mysql
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql
    healthcheck:
      test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
      interval: 5s
      timeout: 3s
      retries: 30

volumes:
  db_data:
EOF

# Create database init script
cat > init.sql <<EOF
CREATE USER IF NOT EXISTS 'mediawikiuser'@'%' IDENTIFIED BY 'mediawikipassword';
GRANT ALL PRIVILEGES ON mediawiki.* TO 'mediawikiuser'@'%';
FLUSH PRIVILEGES;
EOF

# Cache sudo credentials once
cache_sudo

# Start initial stack
echo "Starting initial containers..."
${SUDO_PREFIX}${RUNTIME} -f compose-initial.yaml up -d

# Wait for DB to be ready
echo "Waiting for database to initialize..."
DB_HEALTHY=0
for i in {1..30}; do
    if ${SUDO_PREFIX}${RUNTIME} -f compose-initial.yaml ps db | grep -q '(healthy)'; then
        DB_HEALTHY=1
        break
    fi
    sleep 5
    echo "Waiting for database to become healthy ($i/30)..."
done

if [ $DB_HEALTHY -eq 0 ]; then
    echo "Error: Database did not become healthy in time"
    ${SUDO_PREFIX}${RUNTIME} -f compose-initial.yaml logs db
    exit 1
fi

# Run MediaWiki installation with server name
echo "Running MediaWiki installation..."
${SUDO_PREFIX}${RUNTIME} -f compose-initial.yaml exec -T mediawiki \
    php maintenance/install.php \
    --dbtype mysql \
    --dbname mediawiki \
    --dbuser mediawikiuser \
    --dbpass mediawikipassword \
    --dbserver db \
    --lang en \
    --server "http://localhost:8080" \
    --pass "$ADMIN_PASSWORD" \
    --scriptpath "" \
    "$WIKI_NAME" \
    "$ADMIN_USER"

# Copy generated settings using SERVICE NAME (not container name)
echo "Extracting LocalSettings.php..."
${SUDO_PREFIX}${RUNTIME} -f compose-initial.yaml cp mediawiki:/var/www/html/LocalSettings.php ./

# Set proper permissions
echo "Setting file permissions..."
if [ -n "$SUDO_PREFIX" ]; then
    sudo chown $(id -u):$(id -g) LocalSettings.php
else
    chown $(id -u):$(id -g) LocalSettings.php
fi
chmod 664 LocalSettings.php

# Stop initial stack
echo "Stopping initial containers..."
${SUDO_PREFIX}${RUNTIME} -f compose-initial.yaml down

# Start main stack
echo "Starting main stack..."
${SUDO_PREFIX}${RUNTIME} -f compose.yaml up -d

# Configure skin settings
echo "Configuring Loftia skin..."
cat >> LocalSettings.php <<'EOS'

// ==================================================
// Loftia Skin Configuration
// ==================================================

// Disable all other skins
$wgSkipSkins = [
    'CologneBlue',
    'MinervaNeue',
    'MonoBook',
    'Timeless',
    'Vector'
];

// Enable Loftia skin
wfLoadSkin('Loftia');
$wgDefaultSkin = 'loftia';

EOS

# Restart to apply changes
echo "Restarting MediaWiki..."
${SUDO_PREFIX}${RUNTIME} -f compose.yaml restart mediawiki

echo "=================================================="
echo "Installation complete!"
echo "Access your wiki at: http://localhost:8080"
echo "Admin username: $ADMIN_USER"
echo "Admin password: $ADMIN_PASSWORD"
echo "=================================================="

