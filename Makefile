## To read environment variables from .env, you can do:
## $(call dotenv,VARIABLE_NAME,DEFAULT_VALUE)
define dotenv
$(shell test -f .env && grep -qP '^$(1)\=' .env && grep -P '^$(1)\=' .env | cut -d '=' -f 2 || echo '$(2)')
endef

MAKEFLAGS += --no-print-directory
DOCKER_PORT_HTTP ?= $(call dotenv,DOCKER_PORT_HTTP,8080)

# Export all variables so they are accessible in the shells created by make
export

##
## Binaries
##

DOCKER_COMPOSE = docker-compose
COMPOSER = $(DOCKER_COMPOSE) run --rm --no-deps php composer
PHP = $(DOCKER_COMPOSE) run --rm --no-deps php

##
## Entrypoints
##

.PHONY: up
up:
	$(MAKE) build
	$(DOCKER_COMPOSE) up -d --remove-orphan
	@echo "\e[30m\e[42m\n"
	@echo " The app is up and running at http://localhost:$(DOCKER_PORT_HTTP)"
	@echo "\e[49m\e[39m\n"

.PHONY: down
down:
	$(DOCKER_COMPOSE) down --remove-orphan

.PHONY: destroy
destroy:
	$(DOCKER_COMPOSE) down --remove-orphan --volumes --rmi local

##
## Build
##

.PHONY: build
build:
	$(MAKE) .env
	$(DOCKER_COMPOSE) build
	$(MAKE) dependencies
	$(MAKE) cache
	$(PHP) bin/console assets:install public

.env:
	cp -n .env.dist .env

.PHONY: dependencies
dependencies:
	$(COMPOSER) install \
		--no-interaction \
		--no-ansi \
		--prefer-dist \
		--optimize-autoloader

.PHONY: cache
cache:
	$(PHP) rm -rf var/cache
	$(PHP) bin/console cache:warmup
