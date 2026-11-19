# Base de données — PostgreSQL 16 + PostGIS 3 + pgvector

| Fichier | Contenu | Origine |
|---|---|---|
| `migrations/V1__schema_core.sql` | extensions, types harmonisés, 27 tables (schémas `core` et `sensitive`), index, triggers d'audit et de cohérence | `001_schema.sql` |
| `migrations/V2__schema_bi.sql` | schéma `bi` en étoile pour Power BI : `dim_date`, `dim_mode`, `dim_location`, `dim_severity`, `dim_source`, `fact_occurrences`, `annual_rates` | `003_bi.sql` |
| `migrations/V3__security_roles.sql` | rôles par composant : `st_api`, `st_etl`, `st_ml`, `st_bi_reader`, `st_agent_readonly` | `004_security.sql` |
| `migrations/V4__referentiels_et_sources.sql` | modes, rôles, organisations, sources réelles (BAAC, NTSB, exposition) | phase 02 |
| `seed/R__seed_simulated.sql` | comptes de démo + source `sim_demo` (id 900) + faits **simulés** (dev et CI seulement) | `002_seed.sql` |
| `tests/900_tests.sql` | 29 tests de contraintes, dans une transaction annulée | `900_tests.sql` |
| `initdb/10_app_roles.sh` | comptes de connexion `app_api`, `app_ai`, `app_admin`, `app_bi` + schéma `admin` (exécuté une fois, à la création du volume) | nouveau |
| `Dockerfile` | image `pgvector/pgvector:pg16` + paquet PostGIS 3 (multi-architecture) | nouveau |

Conversion : seuls les `BEGIN;` / `COMMIT;` de premier niveau ont été retirés, Flyway exécutant
chaque migration dans sa propre transaction. Vérifié le 19/11/2026 : 4 migrations appliquées par
Flyway 11, puis 29/29 tests OK.

```bash
make db-migrate   # démarre la base et applique les migrations
make db-test      # 29 tests
make db-reset     # repart d'une base vide
```

## Règles

* Ne jamais modifier une migration déjà appliquée : ajouter `V5__…`, `V6__…`.
* Une nouvelle table doit recevoir ses `GRANT` vers les rôles `st_*` dans sa propre migration
  (les `GRANT … ON ALL TABLES` de V3 ne s'appliquent qu'aux tables existantes à ce moment-là).
* Le seed simulé est une migration *repeatable* : Flyway la rejoue si son contenu change, ce qui
  échouera sur les contraintes d'unicité. Après l'avoir modifiée : `make db-reset`.
* Les référentiels réels sont dans V4 ; le seed ne contient que des données de démo.

## Comment le schéma distingue les six natures de données (§1)

| Nature | Représentation |
|---|---|
| Accident | table `accidents` (gravité harmonisée `severity` + libellé source conservé) |
| Incident | table `incidents` (`incident_class` : grave, incident, quasi-accident) ; requalification via `escalated_to_accident_id` |
| Signalement non vérifié | table `reports`, `validation_status = 'unverified'` par défaut ; qualifié ensuite en accident ou incident |
| Hypothèse | `accident_factors.assertion_level = 'hypothesis'` ; une suggestion d'IA ne peut **pas** être enregistrée comme fait établi, un fait établi exige une preuve |
| Recommandation | `corrective_actions.kind = 'recommendation'` ; seule une `measure` peut être mise en œuvre, et jamais sans `approved_by` (validation humaine) |
| Donnée simulée | `is_simulated` sur les faits ; forcé par trigger si la source est de type `simulation`, refusé si la source est réelle |

## Autres choix

* **Provenance** sur chaque fait : `data_source_id`, `source_record_id` (ligne brute JSON dans `source_records`), `source_ref`, `confidence`, `validation_status`, `validated_by/at`.
* **Dédoublonnage / idempotence** : `UNIQUE (data_source_id, source_ref)` sur les faits, `UNIQUE (data_source_id, external_id, record_sha256)` sur les enregistrements bruts, un même fichier (SHA-256) ne peut être importé avec succès qu'une fois.
* **Comparabilité** : table `exposure_measures` (vols, véh-km, trafic…) et vue `bi.annual_rates` qui calcule des taux pour 10⁸ unités d'exposition.
* **IA prédictive** : `risk_predictions` impose 0 ≤ ci_low ≤ score ≤ ci_high ≤ 1 et `training_cutoff ≤ period_start` (pas de fuite temporelle), avec version de modèle.
* **RAG** : `documents` (organisme, URL, licence, langue, version, hash) → `document_chunks` (pages, `tsvector` lexical + `vector(1024)` HNSW cosinus) → `rag_queries` / `rag_query_chunks` (citations, abstention justifiée, coût, latence, benchmark).
* **Données sensibles** : e-mails, noms, contacts des déclarants dans le schéma `sensitive`, lisible uniquement par `st_api`. Pas d'immatriculation de véhicule routier.
* **Audit** : trigger générique sur les tables métier ; l'application déclare l'acteur par transaction (`SET LOCAL app.user_id`, `app.actor_type`). Le journal est en ajout seul.

Tables ajoutées à la liste du §4 : `user_roles`, `reports`, `event_vehicles`, `exposure_measures`, `rag_query_chunks` (+ `sensitive.user_identities`, `sensitive.report_contacts`).

Dimension des embeddings : 1024 (modèle multilingue type bge-m3). À ajuster quand le modèle sera choisi en phase 14.
