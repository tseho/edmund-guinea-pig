ARG PHP_VERSION=8.1.12
ARG COMPOSER_VERSION=2.4.4

###############################################################################

FROM php:${PHP_VERSION}-apache AS core

RUN apt-get update \
    && apt-get install -y --no-install-recommends --no-install-suggests \
        libicu-dev \
        libonig-dev \
    && docker-php-ext-install \
        bcmath \
        intl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && mv /etc/apache2/mods-available/rewrite.load /etc/apache2/mods-enabled/rewrite.load

COPY ./docker/php/php.ini /usr/local/etc/php/conf.d/000-docker.ini
COPY ./docker/apache/apache2.conf /etc/apache2/apache2.conf
COPY ./docker/apache/ports.conf /etc/apache2/ports.conf
COPY ./docker/apache/app.conf /etc/apache2/sites-available/000-default.conf

###############################################################################

FROM composer:${COMPOSER_VERSION} AS composer

###############################################################################

FROM core AS dev-tools

ENV COMPOSER_HOME=/tmp

RUN apt-get update \
    && apt-get install -y \
        git \
        unzip \
        curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY --from=composer /usr/bin/composer /usr/bin/composer
COPY ./docker/composer/php.ini /usr/local/etc/php/conf.d/custom.ini

###############################################################################

FROM dev-tools as dev

ARG USER=www-data

RUN pecl install \
        xdebug \
        pcov  \
    && docker-php-ext-enable \
        xdebug \
        pcov

RUN mkdir -p /srv/app && chown $USER /srv/app
WORKDIR /srv/app
USER $USER

###############################################################################

FROM dev-tools AS vendors

WORKDIR /srv/app
COPY composer.json composer.lock symfony.lock ./
RUN composer install \
        --no-scripts \
        --no-interaction \
        --no-ansi \
        --prefer-dist \
        --optimize-autoloader \
        --no-dev

###############################################################################

FROM core AS prod

ARG USER=www-data

RUN mkdir -p /srv/app && chown $USER /srv/app
WORKDIR /srv/app
USER $USER
ENV APP_ENV=prod

COPY --from=vendors /srv/app/vendor vendor
COPY bin bin
COPY config config
COPY public/index.php public/index.php
COPY src src
COPY .env.dist .env.dist

RUN cp -n .env.dist .env \
    && php bin/console cache:warmup \
    && php bin/console assets:install public
