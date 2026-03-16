# STAGE 1: Build Stage
FROM php:8.2-fpm-alpine as builder

# Install system dependencies and PHP extensions
RUN apk add --no-cache \
    libpng-dev \
    libzip-dev \
    zip \
    unzip \
    git

RUN docker-php-ext-install pdo_mysql gd zip

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /var/www
COPY . .

# Install dependencies and optimize for production
RUN composer install --no-dev --optimize-autoloader --no-interaction

# ---------------------------------------------------------

# STAGE 2: Production Stage
FROM php:8.2-fpm-alpine

# Install only the bare essentials for the web server
RUN apk add --no-cache nginx

# Copy the Nginx config
COPY .docker/nginx.conf /etc/nginx/http.d/default.conf

# Copy ONLY the application code from the builder stage
WORKDIR /var/www
COPY --from=builder /var/www /var/www

# Fix permissions for Laravel
RUN chown -R www-data:www-data /var/www/storage /var/www/cache

# Expose port 80 and start both PHP and Nginx
EXPOSE 80
CMD php-fpm -D && nginx -g 'daemon off;'
