# Stage 1: Node Builder - Build frontend assets
FROM node:20-alpine AS node-builder

WORKDIR /app

# Copy package files
COPY package.json package-lock.json ./

# Install Node dependencies
RUN npm ci

# Copy source code for building assets
COPY . .

# Build frontend assets with Vite
RUN npm run build


# Stage 2: PHP Dependencies - Build PHP dependencies
FROM composer:latest AS php-dependencies

WORKDIR /app

# Copy composer files
COPY composer.json composer.lock ./

# Install PHP dependencies without dev dependencies
RUN composer install \
    --no-dev \
    --no-interaction \
    --no-ansi \
    --no-scripts \
    --prefer-dist \
    --optimize-autoloader


# Stage 3: PHP Development Dependencies - For optimization
FROM composer:latest AS php-dev-dependencies

WORKDIR /app

# Copy composer files
COPY composer.json composer.lock ./

# Install all PHP dependencies including dev
RUN composer install \
    --no-interaction \
    --no-ansi \
    --prefer-dist \
    --optimize-autoloader


# Stage 4: Application Runtime - Final production image
FROM php:8.4-fpm-alpine

# Install system dependencies
RUN apk add --no-cache \
    nginx \
    supervisor \
    postgresql-client \
    mysql-client \
    git \
    curl \
    zip \
    unzip \
    oniguruma-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    gettext-dev \
    bash \
    ca-certificates

# Install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-install \
    pdo \
    pdo_mysql \
    pdo_pgsql \
    mbstring \
    exif \
    pcntl \
    bcmath \
    gd \
    opcache \
    gettext

# Copy PHP configuration
COPY docker/php/php.ini /usr/local/etc/php/php.ini
COPY docker/php/php-fpm.conf /usr/local/etc/php-fpm.d/www.conf

# Set working directory
WORKDIR /app

# Copy built assets from Node builder
COPY --from=node-builder /app/public/build ./public/build

# Copy PHP dependencies from production builder
COPY --from=php-dependencies /app/vendor ./vendor

# Copy application code
COPY . .

# Create necessary directories
RUN mkdir -p /app/storage/logs \
    && mkdir -p /app/storage/framework/cache \
    && mkdir -p /app/storage/framework/sessions \
    && mkdir -p /app/storage/framework/views \
    && mkdir -p /app/bootstrap/cache

# Permissions for storage/bootstrap moved to entrypoint to handle
# runtime mounts and UID/GID differences.

# Copy Nginx configuration
COPY docker/nginx/nginx.conf /etc/nginx/nginx.conf
COPY docker/nginx/default.conf /etc/nginx/conf.d/default.conf

# Copy Supervisor configuration
COPY docker/supervisor/supervisord.conf /etc/supervisor/supervisord.conf

# Run Laravel caches at container startup so they reflect runtime env
# The entrypoint will regenerate config/route/view caches using runtime env
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Expose port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/health || exit 1

# Start PHP-FPM and Nginx via supervisord; entrypoint runs cache commands first
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]