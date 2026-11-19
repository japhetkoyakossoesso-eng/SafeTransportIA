# Phase 07 : API Java

Le code est dans `api/` (Spring Boot 4, Java 21). L'API lit la base avec le compte `app_api` et ne passe jamais par le schéma `sensitive` pour répondre, sauf pour vérifier un mot de passe.

## Démarrer

```bash
make up                    # ou : docker compose up -d --build
```

- Documentation interactive : http://localhost:8080/api/docs
- Description OpenAPI brute : http://localhost:8080/v3/api-docs

Pour lancer l'API hors Docker (base démarrée) :

```bash
cd api
set -a; . ../.env; set +a
./mvnw spring-boot:run
```

## Se connecter

Les comptes de démonstration ont le mot de passe `demo` (jeu simulé seulement, jamais en production) :

| Compte | Rôle |
|---|---|
| `analyste.demo` | analyst |
| `resp.securite.demo` | safety_manager |
| `admin.demo` | admin |
| `declarant.demo` | reporter |

```bash
curl -s -X POST localhost:8080/api/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"analyste.demo","password":"demo"}'
```

La réponse contient un jeton valable 8 heures, à envoyer dans chaque requête : `Authorization: Bearer <jeton>`. Dans `/api/docs`, le bouton « Authorize » fait la même chose.

Le jeton est signé avec `API_JWT_SECRET` (fichier `.env`, 32 caractères minimum). Chaque connexion est écrite dans `core.audit_logs` (action `LOGIN`).

## Routes

| Route | Qui | Rôle |
|---|---|---|
| `POST /api/v1/auth/login` | tout le monde | obtenir un jeton |
| `GET /api/v1/health`, `/transport-modes`, `/sources` | tout le monde | état, référentiels, catalogue des sources |
| `GET /api/v1/accidents` | analyst, researcher, safety_manager, admin | liste filtrée et paginée |
| `GET /api/v1/accidents/{id}` | idem | fiche détail avec lieu, source et facteurs |
| `GET /api/v1/accidents/export.csv` | idem | mêmes filtres que la liste, sans pagination |
| `PATCH /api/v1/accidents/{id}/validation` | safety_manager, admin | changer le statut de validation |
| `GET /api/v1/incidents`, `/incidents/{id}` | analyst, researcher, safety_manager, admin | incidents |
| `GET /api/v1/imports`, `/imports/{id}` | analyst, researcher, safety_manager, admin | rapports qualité des imports, avec les rejets |
| `POST /api/v1/imports/{id}/validation` | safety_manager, admin | valider d'un coup les accidents non vérifiés d'un import |

Sans jeton, l'API répond 401. Avec un rôle insuffisant, elle répond 403 (par exemple un déclarant qui liste les accidents, ou un analyste qui valide).

Filtres de la liste et de l'export : `mode` (road, air, rail, maritime), `from` et `to` (dates AAAA-MM-JJ), `severity` (répétable : fatal, serious, minor, none, unknown), `country` (FR, US…), `source` (onisr_baac…), `includeUnverified`, `includeSimulated`, `page` et `size` (200 au maximum).

Par défaut, seuls les accidents **validés et réels** sont renvoyés. Les accidents importés par l'ETL sont « non vérifiés » tant qu'un responsable ne les a pas validés :

```bash
# avec un jeton de resp.securite.demo, valider tout l'import n°1
curl -s -X POST localhost:8080/api/v1/imports/1/validation -H "Authorization: Bearer $JETON"
```

Chaque changement de statut est tracé dans `core.audit_logs` avec l'auteur, l'avant et l'après.

## Tests

- `./mvnw verify` : tests JUnit des contrôleurs et de la sécurité (base simulée par des mocks).
- Test sur une vraie base (`BaseReelleTest`), lancé par la CI après la migration et l'import BAAC :

```bash
cd api
set -a; . ../.env; set +a
API_TEST_DB=1 DB_HOST=localhost ./mvnw test -Dtest=BaseReelleTest
```
