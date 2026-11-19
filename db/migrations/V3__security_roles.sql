-- Migration Flyway convertie depuis 004_security.sql (V1 du modèle, testé 29/29).
-- BEGIN/COMMIT retirés : Flyway exécute chaque migration dans sa propre transaction.
-- =============================================================================
-- SafeTransport AI — Rôles PostgreSQL par composant (moindre privilège)
-- Rôles « groupes » sans connexion ; les comptes de connexion (mots de passe hors
-- dépôt, via variables d'environnement / secrets Docker) en héritent.
-- =============================================================================


DO $$
DECLARE r text;
BEGIN
  FOREACH r IN ARRAY ARRAY['st_api', 'st_etl', 'st_ml', 'st_bi_reader', 'st_agent_readonly']
  LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r) THEN
      EXECUTE format('CREATE ROLE %I NOLOGIN', r);
    END IF;
  END LOOP;
END $$;

REVOKE ALL ON SCHEMA core, sensitive, bi FROM PUBLIC;

-- API Java (Spring Boot) : CRUD métier, seule à lire/écrire les données personnelles.
GRANT USAGE ON SCHEMA core, sensitive, bi TO st_api;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA core TO st_api;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA sensitive TO st_api;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA core TO st_api;
GRANT SELECT ON ALL TABLES IN SCHEMA bi TO st_api;

-- ETL Python : imports, enregistrements bruts, faits, exposition, documents.
GRANT USAGE ON SCHEMA core TO st_etl;
GRANT SELECT ON ALL TABLES IN SCHEMA core TO st_etl;
GRANT INSERT, UPDATE ON core.import_jobs, core.source_records, core.accidents, core.incidents,
                        core.locations, core.weather_conditions, core.vehicles, core.event_vehicles,
                        core.exposure_measures, core.documents, core.document_chunks TO st_etl;
GRANT INSERT ON core.audit_logs TO st_etl;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA core TO st_etl;

-- FastAPI ML / RAG : lecture des faits, écriture prédictions, chunks, requêtes RAG.
GRANT USAGE ON SCHEMA core TO st_ml;
GRANT SELECT ON ALL TABLES IN SCHEMA core TO st_ml;
GRANT INSERT, UPDATE ON core.risk_predictions, core.document_chunks, core.rag_queries, core.rag_query_chunks TO st_ml;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA core TO st_ml;

-- Power BI : uniquement le schéma bi.
GRANT USAGE ON SCHEMA bi TO st_bi_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA bi TO st_bi_reader;
-- Les vues bi lisent core avec les droits de leur propriétaire : pas d'accès direct à core nécessaire.

-- Agents IA : lecture seule, jamais les données personnelles ni le journal d'audit.
GRANT USAGE ON SCHEMA core, bi TO st_agent_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA core, bi TO st_agent_readonly;
REVOKE SELECT ON core.audit_logs, core.users FROM st_agent_readonly;

-- Personne d'autre que st_api ne lit le schéma sensitive (vérifié dans les tests).

