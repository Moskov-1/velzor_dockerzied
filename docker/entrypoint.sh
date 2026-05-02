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

# If artisan exists, rebuild caches using runtime environment
if [ -f artisan ]; then
  # Clear existing caches to avoid stale data
  php artisan config:clear || true
  php artisan route:clear || true
  php artisan view:clear || true

  # Recreate caches using runtime environment variables
  php artisan config:cache || true
  php artisan route:cache || true
  php artisan view:cache || true
fi

# Execute the CMD
exec "$@"
