IMAGE ?= statuspulse:local
COMPOSE ?= docker compose
APP_ENV ?= production
BUILD_VERSION ?= local
BUILD_SHA ?= local

.PHONY: build up down logs test clean shell

build:
	docker build \
		--build-arg APP_ENV=$(APP_ENV) \
		--build-arg BUILD_VERSION=$(BUILD_VERSION) \
		--build-arg BUILD_SHA=$(BUILD_SHA) \
		-t $(IMAGE) .

up:
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down

logs:
	$(COMPOSE) logs -f

test:
	curl -fsS http://localhost:$${APP_PORT:-8000}/health

clean:
	$(COMPOSE) down --volumes --rmi local --remove-orphans

shell:
	$(COMPOSE) exec app bash
