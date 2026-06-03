FROM php:8.2-apache

# Install system dependencies and PHP extensions
RUN apt-get update && apt-get install -y \
    unzip \
    libpng-dev \
    libzip-dev \
    libxml2-dev \
    libonig-dev \
    libsqlite3-dev \
    && docker-php-ext-install \
        gd \
        mbstring \
        bcmath \
        zip \
        pdo \
        pdo_sqlite \
    && docker-php-ext-enable opcache \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Enable Apache mod_rewrite and switch to port 8080 for non-root compatibility
RUN a2enmod rewrite \
    && sed -i 's/Listen 80$/Listen 8080/' /etc/apache2/ports.conf \
    && chmod g+w /etc/apache2/envvars

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html
COPY . .
RUN mkdir -p bootstrap/cache \
        storage/framework/cache/data \
        storage/framework/sessions \
        storage/framework/views \
        storage/logs \
    && composer install --no-dev --optimize-autoloader --no-interaction

RUN printf '<VirtualHost *:8080>\n\
    ServerAdmin webmaster@localhost\n\
    ServerName ${SERVER_NAME}\n\
    DocumentRoot /var/www/html/public\n\
    <Directory /var/www/html/public>\n\
        Options Indexes MultiViews FollowSymLinks\n\
        AllowOverride All\n\
        Require all granted\n\
    </Directory>\n\
    ErrorLog ${APACHE_LOG_DIR}/error.log\n\
    CustomLog ${APACHE_LOG_DIR}/access.log combined\n\
</VirtualHost>\n' > /etc/apache2/sites-available/000-default.conf

# Set permissions — group owner root (GID 0) allows OpenShift's arbitrary UID to write
RUN chown -R www-data:root /var/www/html \
    && chmod -R 755 /var/www/html \
    && chmod -R 775 /var/www/html/storage \
    && chmod -R 775 /var/www/html/bootstrap/cache

RUN cp /var/www/html/storage/app/version.txt /var/www/html/storage/app/version.txt.bak

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 8080
ENTRYPOINT ["docker-entrypoint.sh"]
