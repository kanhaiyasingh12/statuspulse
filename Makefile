IMAGE ?= statuspulse:local
COMPOSE ?= docker compose

.PHONY: build up down logs test clean shell

build:
	docker build -t $(IMAGE) .

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
