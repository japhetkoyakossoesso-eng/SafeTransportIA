# Architecture

```
                    ┌──────────────┐
  navigateur ─────▶ │ web (Vue.js) │ ──/api──▶ api (Spring Boot) ──┐
                    └──────────────┘ ──/ai───▶ ai (FastAPI)  ──────┤
  back-office ────▶ admin (Laravel) ───────────────────────────────┤
                    notifications (Node.js) ◀── événements         │
                                                                   ▼
                       PostgreSQL 16 + PostGIS + pgvector  ◀── Flyway (db/migrations)
                                    ▲
                Power BI (app_bi, schéma bi)   ·   R / SQL (analyses)
```

| Service | Rôle | Compte base | Droits |
|---|---|---|---|
| `api` | API métier : accidents, incidents, signalements, recommandations | `app_api` | `st_api` : CRUD `core`, seul accès à `sensitive` |
| `ai` | ETL des sources ouvertes, ML, RAG | `app_ai` | `st_etl` + `st_ml` |
| `admin` | back-office (référentiels, utilisateurs, validation) | `app_admin` | `st_api` + son schéma `admin` |
| `notifications` | alertes et relances | (aucun pour l'instant) | |
| Power BI, R | indicateurs | `app_bi` | `st_bi_reader` : schéma `bi` seulement |

Le schéma de la base n'appartient qu'à Flyway : aucun service ne crée de tables dans `core`,
`sensitive` ou `bi`. Laravel gère seulement ses tables techniques dans le schéma `admin`.

Feuille de route : https://claude.ai/artifact/8HTCanEuPkQNKmc2kRmBNy
