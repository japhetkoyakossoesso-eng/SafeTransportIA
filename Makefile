# Raccourcis (facultatifs) : make up, make test…
.PHONY: env up down logs db-migrate db-test db-reset psql test

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

# Supprime le volume de données puis recrée la base et rejoue les migrations.
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
