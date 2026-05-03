#!/bin/sh
set -e

# Change to app directory if present
cd /app || exit 0

# Ensure storage and bootstrap/cache ownership and permissions are correct
if [ -d /app/storage ]; then
  chown -R www-data:www-data /app/storage /app/bootstrap/cache || true
  find /app/storage -type d -exec chmod 775 {} \; || true
  find /app/storage -type f -exec chmod 664 {} \; || true
  chmod -R 775 /app/bootstrap/cache || true
fi

# If artisan exists, perform Laravel bootstrap
if [ -f artisan ]; then
  # Create .env if it doesn't exist (Laravel needs this file for artisan commands)
  if [ ! -f /app/.env ]; then
    if [ -f /app/.env.example ]; then
      cp /app/.env.example /app/.env
      echo "Created /app/.env from .env.example"
    else
      echo "APP_KEY=" > /app/.env
      echo "Created minimal /app/.env"
    fi
  fi

  # Generate APP_KEY if not set in .env file
  APP_KEY_VALUE=$(grep '^APP_KEY=' /app/.env | cut -d '=' -f2-)
  if [ -z "$APP_KEY_VALUE" ]; then
    echo "APP_KEY is empty, generating a new one..."
    php artisan key:generate --force || true
  fi

  # Export APP_KEY from .env so it's available to config:cache
  APP_KEY_VALUE=$(grep '^APP_KEY=' /app/.env | cut -d '=' -f2-)
  if [ -n "$APP_KEY_VALUE" ]; then
    export APP_KEY="$APP_KEY_VALUE"
  fi

  # Run pending migrations
  php artisan migrate --force || true

  # Clear all caches first
  php artisan config:clear || true
  php artisan route:clear || true
  php artisan view:clear || true

  # Recreate caches — Only config cache for now as it's the most stable
  # Route caching is disabled as it was causing some routes to be missing
  php artisan config:cache || true
fi


# Execute the CMD
exec "$@"
