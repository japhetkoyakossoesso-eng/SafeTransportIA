#!/usr/bin/env bash
set -euo pipefail

# Lancé une seule fois, quand le volume de la base est créé
psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
  -v api_pw="$API_DB_PASSWORD" \
  -v ai_pw="$AI_DB_PASSWORD" \
  -v admin_pw="$ADMIN_DB_PASSWORD" \
  -v bi_pw="$BI_DB_PASSWORD" <<'SQL'
CREATE ROLE st_api NOLOGIN;
CREATE ROLE st_etl NOLOGIN;
CREATE ROLE st_ml NOLOGIN;
CREATE ROLE st_bi_reader NOLOGIN;
CREATE ROLE st_agent_readonly NOLOGIN;

CREATE ROLE app_api LOGIN PASSWORD :'api_pw' IN ROLE st_api;
CREATE ROLE app_ai LOGIN PASSWORD :'ai_pw' IN ROLE st_etl, st_ml;
CREATE ROLE app_admin LOGIN PASSWORD :'admin_pw' IN ROLE st_api;
CREATE ROLE app_bi LOGIN PASSWORD :'bi_pw' IN ROLE st_bi_reader;

-- Tables techniques de Laravel
CREATE SCHEMA admin AUTHORIZATION app_admin;
SQL
