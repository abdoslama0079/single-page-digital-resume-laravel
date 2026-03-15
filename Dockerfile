# Stage 1: Build Assets (Frontend)
FROM node:18-alpine as assets
WORKDIR /app
COPY . .
RUN npm install && npm run build

# Stage 2: Build Application (PHP)
FROM php:8.2-fpm-alpine

# Install system dependencies
RUN apk add --no-cache \
    nginx \
    libpng-dev \
    libxml2-dev \
    zip \
    unzip \
    curl

# Install PHP extensions
RUN docker-php-ext-install pdo_mysql bcmath gd

# Get Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www

# Copy application code
COPY . .
COPY --from=assets /app/public /var/www/public

# Install production dependencies
RUN composer install --no-dev --optimize-autoloader

# Setup Nginx config (we will create this file next)
COPY .docker/nginx.conf /etc/nginx/http.d/default.conf

# Create an empty SQLite database
RUN touch database/database.sqlite

# Ensure permissions are correct
RUN chown -R www-data:www-data /var/www/storage /var/www/bootstrap/cache /var/www/database

# Permissions for Laravel
RUN chown -R www-data:www-data /var/www/storage /var/www/bootstrap/cache

EXPOSE 80



# Start Nginx and PHP-FPM
CMD php-fpm -D && nginx -g "daemon off;"
