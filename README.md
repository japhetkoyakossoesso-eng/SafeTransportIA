# SafeTransport AI

Plateforme d'analyse de la sécurité des transports : centraliser accidents et incidents, fiabiliser
les données, calculer des indicateurs comparables (rapportés à l'exposition), cartographier les
risques, interroger les rapports d'enquête avec un RAG, proposer des mesures préventives traçables
et suivre leur efficacité.

> La prédiction est probabiliste : elle aide l'analyse et ne doit pas servir de système autonome de
> pilotage ou de sécurité critique. Les données simulées sont toujours marquées `is_simulated`.

Feuille de route : [docs/feuille-de-route.md](docs/feuille-de-route.md) · Architecture : [docs/architecture.md](docs/architecture.md) · Cadrage et backlog : [docs/01-cadrage](docs/01-cadrage/README.md) · Sources : [docs/02-sources](docs/02-sources/README.md) · UML : [docs/03-uml](docs/03-uml/README.md) · Import BAAC : [docs/06-etl](docs/06-etl/README.md) · API : [docs/07-api](docs/07-api/README.md) · Interface web : [docs/09-web](docs/09-web/README.md)

## Contenu du dépôt

| Dossier | Techno | Rôle | Port |
|---|---|---|---|
| [`db/`](db/) | PostgreSQL 16 + PostGIS + pgvector, Flyway | schéma (27 tables), migrations, tests SQL | 5432 |
| [`api/`](api/) | Java 21, Spring Boot 4 | API métier REST | 8080 |
| [`ai/`](ai/) | Python 3.12, FastAPI | ETL, modèles prédictifs, RAG | 8000 |
| [`admin/`](admin/) | PHP 8.3, Laravel 13 | back-office | 8001 |
| [`web/`](web/) | Vue 3 + Vite | interface utilisateurs | 5173 |
| [`notifications/`](notifications/) | Node.js 22 | alertes et relances | 3000 |
| [`analyses/`](analyses/) | R + SQL | statistiques, indicateurs | |
| [`bi/`](bi/) | Power BI | tableaux de bord (schéma `bi`) | |
| [`docs/`](docs/) | | architecture, décisions | |

Chaque service est pour l'instant un **stub minimal qui démarre** (route `/health`, tests) : le
fonctionnel arrive phase par phase selon la feuille de route.

## Démarrer (tout avec Docker)

Prérequis : [Docker Desktop](https://www.docker.com/products/docker-desktop/) (Mac Apple Silicon ou Intel).

```bash
cp .env.example .env          # puis changer les mots de passe
docker compose up --build     # premier lancement : quelques minutes
```

Ordre de démarrage automatique : `db` → `flyway` (applique les migrations + le jeu simulé, puis
s'arrête) → `api`, `ai`, `admin`, `notifications`, `web`.

| Vérifier | URL |
|---|---|
| Front | http://localhost:5173 (affiche l'état de l'API et de l'IA) |
| API | http://localhost:8080/api/v1/health · http://localhost:8080/api/v1/sources |
| IA | http://localhost:8000/health · documentation interactive http://localhost:8000/docs |
| Admin | http://localhost:8001/health |
| Notifications | http://localhost:3000/health |

Tests de la base (29 tests de contraintes, dans une transaction annulée) :

```bash
make db-test        # ou : docker compose exec -T db psql -U safetransport_owner -d safetransport -f - < db/tests/900_tests.sql
```

Autres raccourcis : `make db-reset` (recrée la base), `make psql`, `make down`, `make logs`.

## Développer un service sans Docker

Lancer seulement la base : `make db-migrate` (ou `docker compose up -d db && docker compose run --rm flyway`),
puis dans le dossier du service :

| Service | Prérequis | Lancer | Tester |
|---|---|---|---|
| `api` | JDK 21 | `./mvnw spring-boot:run` | `./mvnw verify` |
| `ai` | Python 3.12 | `python -m venv .venv && source .venv/bin/activate && pip install -r requirements-dev.txt && uvicorn app.main:app --reload` | `pytest` |
| `admin` | PHP 8.3, Composer | `composer install && cp .env.example .env && php artisan key:generate && php artisan serve --port 8001` | `php artisan test` |
| `web` | Node 22 | `npm install && npm run dev` | `npm test` |
| `notifications` | Node 22 | `npm run dev` | `npm test` |

Sur Mac : `brew install openjdk@21 python@3.12 php composer node@22`.

## Base de données

* Le schéma appartient à **Flyway** (`db/migrations`, versions `V1`, `V2`…) ; aucun service ne crée
  de tables métier. Une modification = un nouveau fichier `V<n>__description.sql`, jamais la
  modification d'une migration déjà appliquée.
* `db/seed/R__seed_simulated.sql` charge le jeu de données **simulé** en dev et en CI uniquement
  (`FLYWAY_LOCATIONS` dans `.env`). En production, retirer `filesystem:/flyway/seed`.
* Chaque service se connecte avec son propre compte (`app_api`, `app_ai`, `app_admin`, `app_bi`)
  aux droits minimaux ; les données personnelles (schéma `sensitive`) ne sont lisibles que par l'API.
* Détails du modèle : [db/README.md](db/README.md).

## Intégration continue

`.github/workflows/ci.yml` : migrations + tests SQL, build et tests de chaque service, validation
du `docker-compose.yml`, à chaque push sur `main` et chaque pull request.

## Conventions

* Branches : `main` stable ; une branche par fonctionnalité (`feat/import-baac`, `fix/…`), fusion par pull request.
* Commits : `type(portée): message` (ex. `feat(ai): import BAAC 2023`).
* Jamais de secret ni de données brutes dans git (`.env`, `data/raw/`, `.pbix` sont ignorés).
