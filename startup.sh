#!/bin/bash

# Azure Web App Unified Startup Script
# Runs both Laravel PHP backend and React Router SSR frontend

set -e

echo "Starting Hi.Events unified application..."

# Install Node.js if not present (Azure should have it)
if ! command -v node &> /dev/null; then
    echo "Node.js not found, installing..."
    curl -sL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
fi

echo "Node version: $(node --version)"
echo "PHP version: $(php --version)"

# Navigate to application root
cd /home/site/wwwroot

# Set up Laravel backend
echo "Setting up Laravel backend..."
cd backend

# Create .env if it doesn't exist (will be populated by App Settings)
if [ ! -f .env ]; then
    cp .env.example .env || true
fi

# Install Composer dependencies if vendor doesn't exist
if [ ! -d "vendor" ]; then
    echo "Installing Composer dependencies..."
    composer install --no-dev --optimize-autoloader
fi

# Run Laravel optimizations
php artisan config:cache || true
php artisan route:cache || true
php artisan view:cache || true

# Run migrations
php artisan migrate --force || echo "Migration failed or already up to date"

# Start PHP-FPM in background
echo "Starting PHP-FPM..."
php-fpm -D

# Set up React Router SSR frontend
echo "Setting up React Router SSR frontend..."
cd ../frontend

# Install npm dependencies if node_modules doesn't exist
if [ ! -d "node_modules" ]; then
    echo "Installing npm dependencies..."
    npm ci --production
fi

# Build frontend if dist doesn't exist
if [ ! -d "dist" ]; then
    echo "Building frontend..."
    npm run build
fi

# Start nginx to route traffic
echo "Starting nginx..."
mkdir -p /var/log/nginx
cp /home/site/wwwroot/nginx.conf /etc/nginx/nginx.conf
nginx -t && nginx

# Start Node.js SSR server (foreground - keeps container alive)
echo "Starting Node.js SSR server..."
NODE_ENV=production node server.js

echo "All services started successfully!"
