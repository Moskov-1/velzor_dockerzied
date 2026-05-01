# Docker Setup Guide

## Overview

This project uses a multi-stage Docker build with optimized layers for production deployment and development.

### Docker Architecture

The Dockerfile uses 4 stages:

1. **Node Builder** - Builds frontend assets using Vite
2. **PHP Dependencies** - Installs production PHP dependencies
3. **PHP Dev Dependencies** - Installs all PHP dependencies (for reference)
4. **Application Runtime** - Final production image with PHP-FPM, Nginx, and Supervisor

### Key Features

- ✅ Multi-stage builds for optimized image size
- ✅ Separate dependency layers for better caching
- ✅ PHP 8.3 with essential extensions (PDO, Redis, GD, etc.)
- ✅ Nginx reverse proxy with security headers
- ✅ Supervisor for process management
- ✅ Redis support for caching and queues
- ✅ PostgreSQL for database
- ✅ Health checks enabled
- ✅ Production optimizations (OPCache, Gzip, etc.)

---

## Quick Start

### 1. Build the Image

```bash
docker build -t velzon:latest .
```

### 2. Run with Docker Compose

```bash
docker-compose up -d
```

This starts:
- **app** (http://localhost)
- **PostgreSQL** (port 5432)
- **Redis** (port 6379)

### 3. Setup Database

```bash
# Run migrations
docker-compose exec app php artisan migrate

# Seed database (optional)
docker-compose exec app php artisan seed:run
```

### 4. Generate APP_KEY

```bash
docker-compose exec app php artisan key:generate
```

---

## Configuration

### Environment Variables

Copy `.env.docker` to `.env`:

```bash
cp .env.docker .env
```

Update values as needed:
- `APP_KEY` - Generate with `php artisan key:generate`
- `DB_*` - Database credentials
- `REDIS_*` - Redis connection settings
- `STRIPE_*` - Payment gateway keys
- `JWT_SECRET` - JWT signing secret

### Port Mapping

| Service | Port | Use |
|---------|------|-----|
| Nginx | 80 | Web application |
| PostgreSQL | 5432 | Database |
| Redis | 6379 | Cache/Queue |

---

## Development Commands

```bash
# View logs
docker-compose logs -f app

# Run artisan command
docker-compose exec app php artisan <command>

# Run migrations
docker-compose exec app php artisan migrate

# Run seeders
docker-compose exec app php artisan db:seed

# Clear cache
docker-compose exec app php artisan cache:clear

# View database
docker-compose exec postgres psql -U velzon -d velzon

# Redis CLI
docker-compose exec redis redis-cli

# Restart all services
docker-compose restart

# Stop services
docker-compose down

# Stop and remove volumes
docker-compose down -v
```

---

## Production Deployment

### Building for Production

```bash
# Build with optimizations
docker build --target application \
  -t velzon:prod \
  --build-arg APP_ENV=production \
  --build-arg APP_DEBUG=false \
  .
```

### Image Size Optimization

The multi-stage build keeps the final image lean:
- Node builder discarded after build
- Development dependencies not included
- Only production PHP extensions included

### Security Best Practices

- [ ] Change database credentials in `.env`
- [ ] Set strong JWT_SECRET
- [ ] Configure CORS properly
- [ ] Enable HTTPS in production
- [ ] Use secrets management (AWS Secrets Manager, Vault, etc.)
- [ ] Regularly update base images and dependencies

---

## Docker Compose Profiles

### Default (Production)
```bash
docker-compose up -d
```

### Development with Extra Services
```bash
docker-compose --profile dev up -d
```

This adds an optional Nginx service on port 8080.

---

## Troubleshooting

### Container won't start
```bash
docker-compose logs app
```

### Database connection error
- Verify `DB_HOST=postgres` in `.env`
- Check postgres is healthy: `docker-compose ps`
- Reset with: `docker-compose down -v && docker-compose up -d`

### Permission issues
```bash
docker-compose exec app chown -R www-data:www-data /app
```

### Cache issues
```bash
docker-compose exec app php artisan cache:clear
docker-compose exec app php artisan config:clear
```

---

## Layer Caching Optimization

The Dockerfile is structured to maximize Docker layer caching:

1. **Base image** (rarely changes)
2. **System dependencies** (rarely changes)
3. **PHP extensions** (rarely changes)
4. **Composer dependencies** (changes when composer.json changes)
5. **Node dependencies** (changes when package.json changes)
6. **Application code** (changes frequently)

This order ensures faster rebuilds during development.

---

## File Structure

```
.
├── Dockerfile                 # Multi-stage Dockerfile
├── docker-compose.yml         # Docker Compose configuration
├── .dockerignore              # Files to exclude from build
├── .env.docker                # Environment template
└── docker/
    ├── nginx/
    │   ├── nginx.conf         # Main Nginx configuration
    │   └── default.conf       # Site configuration
    ├── php/
    │   ├── php.ini            # PHP settings
    │   └── php-fpm.conf       # PHP-FPM worker config
    └── supervisor/
        └── supervisord.conf   # Process supervisor config
```

---

## Performance Tips

- Enable OPCache in production (configured in php.ini)
- Use Redis for sessions and cache
- Enable Gzip compression (configured in nginx.conf)
- Use database connection pooling for high traffic
- Monitor with `docker stats`

---

## Additional Resources

- [Docker Documentation](https://docs.docker.com)
- [Laravel Docker Guide](https://laravel.com/docs/deployment#docker)
- [Nginx Best Practices](https://nginx.org/en/docs/)
- [PHP-FPM Configuration](https://www.php.net/manual/en/install.fpm.configuration.php)
