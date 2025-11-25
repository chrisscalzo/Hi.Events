#!/bin/bash
# This script runs after deployment on Azure App Service

echo "Running post-deployment tasks..."

# Navigate to app directory
cd /home/site/wwwroot

# Clear and cache configuration
echo "Caching configuration..."
php artisan config:cache

# Cache routes
echo "Caching routes..."
php artisan route:cache

# Cache views
echo "Caching views..."
php artisan view:cache

# Create storage link if it doesn't exist
if [ ! -L public/storage ]; then
    echo "Creating storage link..."
    php artisan storage:link
fi

echo "Post-deployment tasks completed!"
