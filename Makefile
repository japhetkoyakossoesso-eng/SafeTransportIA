.PHONY: env up down logs db-migrate db-test db-reset psql test uml

env:
	@test -f .env || cp .env.example .env

up: env
	docker compose up --build -d

down:
	docker compose down

logs:
	docker compose logs -f

db-migrate: env
	docker compose up -d --wait db
	docker compose run --rm flyway

db-test:
	docker compose exec -T db sh -c 'psql -v ON_ERROR_STOP=1 -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -f -' < db/tests/900_tests.sql

db-reset: env
	docker compose down -v
	$(MAKE) db-migrate

psql:
	docker compose exec db sh -c 'psql -U "$$POSTGRES_USER" -d "$$POSTGRES_DB"'

test:
	cd api && ./mvnw -q -B verify
	cd ai && pytest -q
	cd admin && php artisan test
	cd web && npm test
	cd notifications && npm test

# Régénère le diagramme de classes depuis la base
uml:
	docker compose exec -T db sh -c 'psql -v ON_ERROR_STOP=1 -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -f -' < db/tools/uml_classes.sql > docs/03-uml/classes.md
