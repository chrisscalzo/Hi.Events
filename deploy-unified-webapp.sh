#!/bin/bash

# Deploy unified Hi.Events application to Azure Web App
# Runs both Laravel backend (PHP) and React Router frontend (Node.js SSR)

set -e

# Configuration
RESOURCE_GROUP="wee-whiskey-fest-rg"
LOCATION="eastus"
APP_SERVICE_PLAN="whiskey-fest-plan"
WEB_APP_NAME="whiskey-fest-events"
PHP_VERSION="8.3"
NODE_VERSION="20-lts"

# Storage configuration
STORAGE_ACCOUNT="whiskeyfeststorage"
DO_SPACES_ENDPOINT="https://nyc3.digitaloceanspaces.com"
DO_SPACES_BUCKET="whiskey-fest-storage"
DO_SPACES_KEY="DO801B39VNUTL72KGQND"
DO_SPACES_SECRET="vieyP/R1d5TZUnB4g72C5mGHRFfmhAJFTZJ2Ze+AW/k"

# Database configuration
DB_HOST="wee-whiskey-fest-db.postgres.database.azure.com"
DB_NAME="hievents"
DB_USER="hievents_admin"
DB_PASSWORD_KEY="DB_PASSWORD"

# Redis configuration
REDIS_HOST="wee-whiskey-fest-redis.redis.cache.windows.net"
REDIS_PASSWORD_KEY="REDIS_PASSWORD"

echo "Starting unified Hi.Events deployment to Azure Web App..."

# Check if logged in to Azure
if ! az account show &> /dev/null; then
    echo "Not logged in to Azure. Please run 'az login' first."
    exit 1
fi

# Create App Service Plan if it doesn't exist
if ! az appservice plan show -n $APP_SERVICE_PLAN -g $RESOURCE_GROUP &> /dev/null; then
    echo "Creating App Service Plan: $APP_SERVICE_PLAN (Linux, B2)..."
    az appservice plan create \
        --name $APP_SERVICE_PLAN \
        --resource-group $RESOURCE_GROUP \
        --location $LOCATION \
        --is-linux \
        --sku B2
else
    echo "App Service Plan $APP_SERVICE_PLAN already exists."
fi

# Create Web App if it doesn't exist
if ! az webapp show -n $WEB_APP_NAME -g $RESOURCE_GROUP &> /dev/null; then
    echo "Creating Web App: $WEB_APP_NAME (PHP $PHP_VERSION)..."
    az webapp create \
        --name $WEB_APP_NAME \
        --resource-group $RESOURCE_GROUP \
        --plan $APP_SERVICE_PLAN \
        --runtime "PHP:$PHP_VERSION"
    
    echo "Web App created successfully!"
else
    echo "Web App $WEB_APP_NAME already exists."
fi

# Get database password from Azure Key Vault or user input
echo "Please enter the database password for PostgreSQL:"
read -s DB_PASSWORD
echo ""

echo "Please enter the Redis password:"
read -s REDIS_PASSWORD
echo ""

# Configure Web App settings
echo "Configuring Web App settings..."
az webapp config appsettings set \
    --name $WEB_APP_NAME \
    --resource-group $RESOURCE_GROUP \
    --settings \
    APP_NAME="Hi.Events" \
    APP_ENV="production" \
    APP_DEBUG="false" \
    APP_URL="https://${WEB_APP_NAME}.azurewebsites.net" \
    APP_KEY="base64:$(openssl rand -base64 32)" \
    LOG_CHANNEL="stack" \
    LOG_LEVEL="error" \
    DB_CONNECTION="pgsql" \
    DB_HOST="$DB_HOST" \
    DB_PORT="5432" \
    DB_DATABASE="$DB_NAME" \
    DB_USERNAME="$DB_USER" \
    DB_PASSWORD="$DB_PASSWORD" \
    CACHE_DRIVER="redis" \
    QUEUE_CONNECTION="redis" \
    SESSION_DRIVER="redis" \
    REDIS_HOST="$REDIS_HOST" \
    REDIS_PASSWORD="$REDIS_PASSWORD" \
    REDIS_PORT="6380" \
    REDIS_CLIENT="predis" \
    REDIS_SCHEME="tls" \
    FILESYSTEM_DISK="s3" \
    AWS_ACCESS_KEY_ID="$DO_SPACES_KEY" \
    AWS_SECRET_ACCESS_KEY="$DO_SPACES_SECRET" \
    AWS_DEFAULT_REGION="nyc3" \
    AWS_BUCKET="$DO_SPACES_BUCKET" \
    AWS_ENDPOINT="$DO_SPACES_ENDPOINT" \
    AWS_URL="https://whiskey-fest-storage.nyc3.cdn.digitaloceanspaces.com" \
    AWS_USE_PATH_STYLE_ENDPOINT="false" \
    MAIL_MAILER="smtp" \
    MAIL_HOST="smtp.sendgrid.net" \
    MAIL_PORT="587" \
    MAIL_ENCRYPTION="tls" \
    NODE_ENV="production" \
    NODE_PORT="5678" \
    VITE_API_URL_CLIENT="/api/v1" \
    VITE_API_URL_SERVER="http://127.0.0.1:8080/api/v1" \
    VITE_FRONTEND_URL="https://${WEB_APP_NAME}.azurewebsites.net" \
    WEBSITES_ENABLE_APP_SERVICE_STORAGE="true" \
    WEBSITES_PORT="8080" \
    SCM_DO_BUILD_DURING_DEPLOYMENT="true"

# Configure startup command
echo "Configuring startup command..."
az webapp config set \
    --name $WEB_APP_NAME \
    --resource-group $RESOURCE_GROUP \
    --startup-file "/home/site/wwwroot/startup.sh"

# Enable logging
echo "Enabling application logging..."
az webapp log config \
    --name $WEB_APP_NAME \
    --resource-group $RESOURCE_GROUP \
    --application-logging filesystem \
    --detailed-error-messages true \
    --failed-request-tracing true \
    --web-server-logging filesystem

# Deploy code from GitHub
echo "Configuring GitHub deployment..."
echo "Would you like to configure continuous deployment from GitHub? (y/n)"
read -r SETUP_GITHUB

if [ "$SETUP_GITHUB" = "y" ]; then
    echo "Enter your GitHub repository URL (e.g., https://github.com/chrisscalzo/Hi.Events):"
    read -r GITHUB_REPO
    
    echo "Enter branch name (default: production):"
    read -r BRANCH
    BRANCH=${BRANCH:-production}
    
    az webapp deployment source config \
        --name $WEB_APP_NAME \
        --resource-group $RESOURCE_GROUP \
        --repo-url "$GITHUB_REPO" \
        --branch "$BRANCH" \
        --manual-integration
    
    echo "GitHub deployment configured! Push to $BRANCH to deploy."
else
    echo "Skipping GitHub deployment. You can deploy manually using:"
    echo "  az webapp deployment source config-zip --name $WEB_APP_NAME --resource-group $RESOURCE_GROUP --src <zip-file>"
fi

# Get Web App URL
WEB_APP_URL=$(az webapp show --name $WEB_APP_NAME --resource-group $RESOURCE_GROUP --query defaultHostName -o tsv)

echo ""
echo "============================================"
echo "Deployment Configuration Complete!"
echo "============================================"
echo "Web App URL: https://$WEB_APP_URL"
echo ""
echo "Next steps:"
echo "1. Push your code to trigger deployment"
echo "2. Monitor deployment: az webapp log tail --name $WEB_APP_NAME --resource-group $RESOURCE_GROUP"
echo "3. Configure custom domain: events.weewhiskeyfest.com"
echo "4. Add CNAME record in GoDaddy: events -> $WEB_APP_URL"
echo ""
echo "To view logs:"
echo "  az webapp log tail --name $WEB_APP_NAME --resource-group $RESOURCE_GROUP"
echo ""
