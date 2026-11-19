#!/usr/bin/env bash
# Crée les comptes de connexion des services (une seule fois, à l'initialisation du volume).
# Les rôles « groupes » st_* portent les droits (migration V3) ; les comptes app_* en héritent.
# Les mots de passe viennent de .env (jamais du dépôt).
set -euo pipefail

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  -v api_pw="${API_DB_PASSWORD:?}" \
  -v ai_pw="${AI_DB_PASSWORD:?}" \
  -v admin_pw="${ADMIN_DB_PASSWORD:?}" \
  -v bi_pw="${BI_DB_PASSWORD:?}" <<'SQL'
-- Rôles groupes (la migration V3 les crée aussi si besoin : IF NOT EXISTS)
DO $$
DECLARE r text;
BEGIN
  FOREACH r IN ARRAY ARRAY['st_api', 'st_etl', 'st_ml', 'st_bi_reader', 'st_agent_readonly'] LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r) THEN
      EXECUTE format('CREATE ROLE %I NOLOGIN', r);
    END IF;
  END LOOP;
END $$;

CREATE ROLE app_api   LOGIN PASSWORD :'api_pw'   IN ROLE st_api;               -- Spring Boot
CREATE ROLE app_ai    LOGIN PASSWORD :'ai_pw'    IN ROLE st_etl, st_ml;        -- FastAPI (ETL + ML + RAG)
CREATE ROLE app_admin LOGIN PASSWORD :'admin_pw' IN ROLE st_api;               -- Laravel (back-office)
CREATE ROLE app_bi    LOGIN PASSWORD :'bi_pw'    IN ROLE st_bi_reader;         -- Power BI

-- Tables propres à Laravel (sessions, jobs, cache…) : schéma séparé, géré par Laravel.
CREATE SCHEMA admin AUTHORIZATION app_admin;
SQL
