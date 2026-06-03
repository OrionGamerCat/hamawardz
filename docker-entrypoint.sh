#!/bin/bash
set -e

echo "export SERVER_NAME=${SERVER_NAME:-localhost}" >> /etc/apache2/envvars

cd /var/www/html

# Ensure required Laravel storage directories exist (volume may be empty on first run)
mkdir -p storage/app \
        storage/app/public \
        storage/framework/cache/data \
        storage/framework/sessions \
        storage/framework/views \
        storage/logs

# Copy .env if it doesn't exist in the volume-backed location
if [ ! -f .env ]; then
    cp .env.example .env
fi

# Set environment values from Docker env vars
sed -i "s!APP_ENV=.*!APP_ENV=${APP_ENV:-production}!" .env
sed -i "s!APP_DEBUG=.*!APP_DEBUG=${APP_DEBUG:-false}!" .env
sed -i "s!APP_URL=.*!APP_URL=${APP_URL:-http://localhost}!" .env
sed -i "s!APP_IMPRESSUM_URL=.*!APP_IMPRESSUM_URL=${APP_IMPRESSUM_URL:-}!" .env
sed -i "s!APP_DATA_PROTECTION_URL=.*!APP_DATA_PROTECTION_URL=${APP_DATA_PROTECTION_URL:-}!" .env
sed -i "s!#WAVELOG_URL=.*!WAVELOG_URL=${WAVELOG_URL:-}!" .env
sed -i "s!#WAVELOG_API_KEY=.*!WAVELOG_API_KEY=${WAVELOG_API_KEY:-}!" .env
sed -i "s!DB_CONNECTION=.*!DB_CONNECTION=sqlite!" .env
sed -i "s!DB_DATABASE=.*!DB_DATABASE=database.sqlite!" .env

# Generate app key if not already set
if grep -q "APP_KEY=$" .env || grep -q "APP_KEY=SomeRandomString" .env; then
    php artisan key:generate --force
fi

# Restore version.txt if missing (wiped by volume mount)
if [ ! -f storage/app/version.txt ]; then
    cp /var/www/html/storage/app/version.txt.bak storage/app/version.txt 2>/dev/null || echo "1.2" > storage/app/version.txt
fi

# Create SQLite database file if missing
if [ ! -f database/database.sqlite ]; then
    touch database/database.sqlite
    chown www-data:www-data database/database.sqlite
fi

# Trust all proxies so Laravel honours X-Forwarded-Proto from Traefik
sed -i "s/protected \$proxies;/protected \$proxies = '*';/" /var/www/html/app/Http/Middleware/TrustProxies.php

# Run migrations
php artisan migrate

# Create storage symlink
php artisan storage:link 2>/dev/null || true

# Ensure images directory exists with correct permissions
mkdir -p public/storage/images
chmod -R a+rw public/storage/images
chown -R www-data:www-data storage bootstrap/cache database

exec "$@"
