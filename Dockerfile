FROM php:8.2-apache

RUN apt-get update && apt-get install -y \
        unzip git cron libpng-dev libzip-dev libxml2-dev libonig-dev libsqlite3-dev \
    && docker-php-ext-install gd mbstring bcmath zip pdo pdo_sqlite \
    && docker-php-ext-enable opcache \
    && a2enmod rewrite \
    && sed -i 's/Listen 80$/Listen 8080/' /etc/apache2/ports.conf \
    && chmod g+w /etc/apache2/envvars \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html
COPY . .

RUN --mount=type=secret,id=GITHUB_TOKEN \
    mkdir -p bootstrap/cache \
        storage/framework/cache/data \
        storage/framework/sessions \
        storage/framework/views \
        storage/logs \
    && COMPOSER_AUTH="{\"github-oauth\":{\"github.com\":\"$(cat /run/secrets/GITHUB_TOKEN)\"}}" \
       composer install --no-dev --optimize-autoloader --no-interaction --ignore-platform-reqs

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
</VirtualHost>\n' > /etc/apache2/sites-available/000-default.conf \
    && echo "* * * * * www-data php /var/www/html/artisan schedule:run >> /dev/null 2>&1" > /etc/cron.d/hamawardz \
    && chmod 0644 /etc/cron.d/hamawardz \
    && chown -R www-data:root /var/www/html \
    && chmod -R 755 /var/www/html \
    && chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache \
    && cp storage/app/version.txt storage/app/version.txt.bak

COPY --chmod=755 docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

EXPOSE 8080
ENTRYPOINT ["docker-entrypoint.sh"]
