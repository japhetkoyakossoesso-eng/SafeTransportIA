FROM php:8.3-cli
RUN apt-get update \
 && apt-get install -y --no-install-recommends libpq-dev unzip git \
 && docker-php-ext-install pdo_pgsql \
 && rm -rf /var/lib/apt/lists/*
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-autoloader --no-interaction --prefer-dist
COPY . .
RUN composer dump-autoload --optimize && cp -n .env.example .env

EXPOSE 8000
CMD ["sh", "-c", "[ -n \"$APP_KEY\" ] || export APP_KEY=$(php artisan key:generate --show); exec php artisan serve --host=0.0.0.0 --port=8000"]
