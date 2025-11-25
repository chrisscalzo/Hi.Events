#!/bin/bash
set -e

cd /home/site/wwwroot

echo "Running post-deployment tasks..."

# Run migrations
php artisan migrate --force

# Create storage link
php artisan storage:link

# Cache optimization
php artisan config:cache
php artisan route:cache
php artisan view:cache

echo "Post-deployment tasks completed successfully!"
