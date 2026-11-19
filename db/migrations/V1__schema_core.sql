-- Migration Flyway convertie depuis 001_schema.sql (V1 du modèle, testé 29/29).
-- BEGIN/COMMIT retirés : Flyway exécute chaque migration dans sa propre transaction.
-- =============================================================================
-- SafeTransport AI — Modèle de données initial (V1)
-- PostgreSQL 16 + PostGIS 3 + pgvector
--
-- Principes (cahier des charges V3, §1, §4, §10) :
--   * clés primaires/étrangères explicites, unicité sur les identifiants sources ;
--   * horodatage (created_at / updated_at) et provenance sur chaque fait ;
--   * niveau de confiance + statut de validation sur chaque fait ;
--   * distinction explicite : accident / incident / signalement non vérifié /
--     hypothèse / recommandation / données simulées ;
--   * données personnelles isolées dans le schéma `sensitive` ;
--   * journal d'audit alimenté automatiquement par trigger.
--
-- Schémas :
--   core       données métier, sources, imports, IA, RAG, audit
--   sensitive  données personnelles (accès restreint)
--   bi         modèle en étoile pour Power BI (voir 003_bi.sql)
-- =============================================================================


CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pgcrypto;   -- gen_random_uuid(), digest()

CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS sensitive;

SET search_path = core, public;

-- -----------------------------------------------------------------------------
-- 1. Types énumérés (vocabulaire harmonisé)
-- -----------------------------------------------------------------------------

-- Cycle de validation d'une donnée. « unverified » = signalement non vérifié.
CREATE TYPE validation_status AS ENUM
  ('unverified', 'under_review', 'validated', 'rejected', 'retracted');

-- Niveau de confiance attribué à la donnée (source, qualité, recoupements).
CREATE TYPE confidence_level AS ENUM ('unknown', 'low', 'medium', 'high');

-- Gravité harmonisée entre modes et pays. Le libellé d'origine est conservé
-- à côté (severity_source_label) pour ne jamais perdre l'information brute.
CREATE TYPE severity_level AS ENUM ('none', 'minor', 'serious', 'fatal', 'unknown');

-- Classe d'incident (pas d'accident au sens des définitions harmonisées).
CREATE TYPE incident_class AS ENUM ('serious_incident', 'incident', 'near_miss', 'other');

-- Statut épistémique d'un facteur contributif : fait établi ≠ hypothèse.
CREATE TYPE assertion_level AS ENUM ('established', 'probable', 'hypothesis');

CREATE TYPE factor_category AS ENUM
  ('human', 'technical', 'environmental', 'infrastructure', 'organizational', 'other');

CREATE TYPE location_precision AS ENUM
  ('exact', 'approximate', 'municipality', 'region', 'country', 'unknown');

CREATE TYPE organization_kind AS ENUM
  ('investigation_body', 'regulator', 'operator', 'data_provider', 'research', 'internal', 'other');

CREATE TYPE source_kind AS ENUM ('open_data', 'api', 'manual_upload', 'user_report', 'document', 'simulation');

CREATE TYPE import_status AS ENUM ('pending', 'running', 'succeeded', 'partial', 'failed', 'cancelled');

CREATE TYPE record_quality AS ENUM ('pending', 'valid', 'warning', 'rejected', 'duplicate');

-- Recommandation (proposée) vs mesure (décidée et mise en œuvre).
CREATE TYPE action_kind AS ENUM ('recommendation', 'measure');

CREATE TYPE action_origin AS ENUM
  ('investigation_body', 'internal_analysis', 'regulation', 'ai_suggestion', 'other');

CREATE TYPE action_status AS ENUM
  ('proposed', 'under_review', 'approved', 'rejected', 'in_progress', 'implemented', 'abandoned');

CREATE TYPE evaluation_conclusion AS ENUM ('effective', 'partially_effective', 'not_effective', 'inconclusive');

CREATE TYPE document_type AS ENUM
  ('investigation_report', 'safety_recommendation', 'statistical_report', 'regulation', 'other');

CREATE TYPE exposure_metric AS ENUM
  ('flights', 'flight_hours', 'vehicle_km', 'passenger_km', 'train_km', 'vessel_movements', 'traffic_volume', 'population');

CREATE TYPE actor_type AS ENUM ('user', 'service', 'ai_agent', 'system');

-- -----------------------------------------------------------------------------
-- 2. Fonctions utilitaires
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION core.set_updated_at() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END $$;

-- -----------------------------------------------------------------------------
-- 3. Référentiels, organisations, utilisateurs, rôles
-- -----------------------------------------------------------------------------

CREATE TABLE transport_modes (
  id          smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  code        text NOT NULL UNIQUE CHECK (code ~ '^[a-z_]+$'),   -- road, air, rail, maritime
  label_fr    text NOT NULL,
  label_en    text NOT NULL,
  definition  text,       -- définition harmonisée d'un accident pour ce mode
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE organizations (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name          text NOT NULL,
  acronym       text,
  kind          organization_kind NOT NULL,
  country_code  char(2) CHECK (country_code ~ '^[A-Z]{2}$'),     -- ISO 3166-1 alpha-2
  website       text,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (name, country_code)
);

CREATE TABLE roles (
  id          smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  code        text NOT NULL UNIQUE,   -- analyst, reporter, safety_manager, admin, researcher
  label_fr    text NOT NULL,
  description text
);

-- Compte applicatif : aucune donnée personnelle ici (voir sensitive.user_identities).
CREATE TABLE users (
  id               bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id        uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
  username         text NOT NULL UNIQUE,
  organization_id  bigint REFERENCES organizations(id) ON DELETE SET NULL,
  is_active        boolean NOT NULL DEFAULT true,
  is_service_account boolean NOT NULL DEFAULT false,   -- ETL, FastAPI, agent IA
  last_login_at    timestamptz,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE user_roles (
  user_id     bigint   NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role_id     smallint NOT NULL REFERENCES roles(id) ON DELETE RESTRICT,
  granted_by  bigint REFERENCES users(id) ON DELETE SET NULL,
  granted_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, role_id)
);

-- Données personnelles séparées : droits d'accès distincts (cf. 004_security.sql).
CREATE TABLE sensitive.user_identities (
  user_id        bigint PRIMARY KEY REFERENCES core.users(id) ON DELETE CASCADE,
  email          text NOT NULL UNIQUE CHECK (email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  full_name      text,
  password_hash  text,          -- NULL si authentification déléguée (OIDC/Keycloak)
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now()
);

-- -----------------------------------------------------------------------------
-- 4. Sources, imports, enregistrements bruts (traçabilité + dédoublonnage)
-- -----------------------------------------------------------------------------

CREATE TABLE data_sources (
  id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  code                text NOT NULL UNIQUE CHECK (code ~ '^[a-z0-9_]+$'),  -- ex. onisr_baac, ntsb_avall
  name                text NOT NULL,
  kind                source_kind NOT NULL,
  provider_org_id     bigint REFERENCES organizations(id) ON DELETE RESTRICT,
  transport_mode_id   smallint REFERENCES transport_modes(id),
  country_code        char(2) CHECK (country_code ~ '^[A-Z]{2}$'),
  url                 text,
  license             text,          -- ex. Licence Ouverte 2.0
  data_format         text,          -- csv, json, xml, pdf…
  data_dictionary_url text,
  known_biases        text,          -- couverture, sous-déclaration, changements de définition
  default_confidence  confidence_level NOT NULL DEFAULT 'unknown',
  is_simulated        boolean NOT NULL DEFAULT false,
  validation_status   validation_status NOT NULL DEFAULT 'under_review',  -- validée par un admin (portail PHP)
  validated_by        bigint REFERENCES users(id) ON DELETE SET NULL,
  validated_at        timestamptz,
  is_active           boolean NOT NULL DEFAULT true,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  CHECK ((kind = 'simulation') = is_simulated),
  CHECK (validation_status <> 'validated' OR (validated_by IS NOT NULL AND validated_at IS NOT NULL))
);

CREATE TABLE import_jobs (
  id               bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  data_source_id   bigint NOT NULL REFERENCES data_sources(id) ON DELETE RESTRICT,
  status           import_status NOT NULL DEFAULT 'pending',
  file_name        text,
  file_sha256      char(64) CHECK (file_sha256 ~ '^[0-9a-f]{64}$'),  -- intégrité du fichier
  pipeline_name    text NOT NULL,     -- ex. etl.onisr_baac
  pipeline_version text NOT NULL,     -- version du code ETL (tag git)
  triggered_by     bigint REFERENCES users(id) ON DELETE SET NULL,
  started_at       timestamptz,
  finished_at      timestamptz,
  rows_read        integer NOT NULL DEFAULT 0 CHECK (rows_read >= 0),
  rows_inserted    integer NOT NULL DEFAULT 0 CHECK (rows_inserted >= 0),
  rows_updated     integer NOT NULL DEFAULT 0 CHECK (rows_updated >= 0),
  rows_rejected    integer NOT NULL DEFAULT 0 CHECK (rows_rejected >= 0),
  rows_duplicate   integer NOT NULL DEFAULT 0 CHECK (rows_duplicate >= 0),
  error_summary    jsonb,             -- journal d'erreurs agrégé
  created_at       timestamptz NOT NULL DEFAULT now(),
  CHECK (finished_at IS NULL OR started_at IS NULL OR finished_at >= started_at)
);
-- Idempotence : un même fichier ne peut être importé avec succès qu'une fois par source.
CREATE UNIQUE INDEX import_jobs_once_per_file
  ON import_jobs (data_source_id, file_sha256)
  WHERE status IN ('succeeded', 'partial') AND file_sha256 IS NOT NULL;

-- Enregistrement brut tel que reçu : la « source de chaque chiffre ».
CREATE TABLE source_records (
  id               bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  data_source_id   bigint NOT NULL REFERENCES data_sources(id) ON DELETE RESTRICT,
  import_job_id    bigint REFERENCES import_jobs(id) ON DELETE SET NULL,
  external_id      text NOT NULL,           -- identifiant dans la source (ex. Num_Acc ONISR, ev_id NTSB)
  record_sha256    char(64) NOT NULL CHECK (record_sha256 ~ '^[0-9a-f]{64}$'),
  payload          jsonb NOT NULL,          -- ligne brute (CSV/JSON/XML normalisé en JSON)
  quality_status   record_quality NOT NULL DEFAULT 'pending',
  quality_issues   jsonb,                   -- [{rule, field, message}]
  duplicate_of_id  bigint REFERENCES source_records(id) ON DELETE SET NULL,
  received_at      timestamptz NOT NULL DEFAULT now(),
  -- Une version donnée d'un enregistrement source n'est stockée qu'une fois.
  UNIQUE (data_source_id, external_id, record_sha256),
  CHECK (quality_status <> 'duplicate' OR duplicate_of_id IS NOT NULL),
  CHECK (duplicate_of_id IS DISTINCT FROM id)
);
CREATE INDEX source_records_import_idx ON source_records (import_job_id);
CREATE INDEX source_records_quality_idx ON source_records (quality_status) WHERE quality_status <> 'valid';

-- -----------------------------------------------------------------------------
-- 5. Lieux, conditions météo, véhicules
-- -----------------------------------------------------------------------------

CREATE TABLE locations (
  id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  geom            geography(Point, 4326),      -- NULL si seule l'unité administrative est connue
  precision       location_precision NOT NULL DEFAULT 'unknown',
  country_code    char(2) NOT NULL CHECK (country_code ~ '^[A-Z]{2}$'),
  admin1          text,      -- région / État
  admin2          text,      -- département / comté
  municipality    text,
  insee_code      text,      -- code commune (FR)
  site_name       text,      -- aéroport, gare, port, PK routier…
  site_code       text,      -- code OACI/IATA, UIC, LOCODE…
  created_at      timestamptz NOT NULL DEFAULT now(),
  CHECK (geom IS NOT NULL OR precision IN ('municipality', 'region', 'country', 'unknown'))
);
CREATE INDEX locations_geom_gix ON locations USING gist (geom);
CREATE INDEX locations_admin_idx ON locations (country_code, admin1, admin2);

CREATE TABLE weather_conditions (
  id                 bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  observed_at        timestamptz,
  location_id        bigint REFERENCES locations(id) ON DELETE SET NULL,
  condition_code     text,     -- code harmonisé : clear, rain, snow, fog, wind, ice…
  condition_source_label text, -- libellé d'origine (ex. « Pluie légère »)
  temperature_c      numeric(4,1),
  visibility_m       integer CHECK (visibility_m >= 0),
  wind_speed_ms      numeric(5,1) CHECK (wind_speed_ms >= 0),
  precipitation_mm   numeric(6,1) CHECK (precipitation_mm >= 0),
  light_condition    text,     -- day, night_lit, night_unlit, dusk…
  data_source_id     bigint REFERENCES data_sources(id) ON DELETE RESTRICT,
  created_at         timestamptz NOT NULL DEFAULT now()
);

-- Pas d'immatriculation de véhicule routier (donnée personnelle indirecte).
CREATE TABLE vehicles (
  id                 bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  transport_mode_id  smallint NOT NULL REFERENCES transport_modes(id),
  category           text NOT NULL,   -- car, truck, bicycle, airplane, helicopter, train, ship…
  make               text,
  model              text,
  public_identifier  text,            -- uniquement si public : immatriculation aéronef, IMO navire
  year_built         smallint CHECK (year_built BETWEEN 1850 AND 2100),
  operator_org_id    bigint REFERENCES organizations(id) ON DELETE SET NULL,
  created_at         timestamptz NOT NULL DEFAULT now(),
  UNIQUE (transport_mode_id, public_identifier)
);

-- -----------------------------------------------------------------------------
-- 6. Faits : accidents, incidents, signalements
-- Colonnes de provenance/qualité communes :
--   data_source_id, source_record_id, source_ref, confidence, validation_status,
--   validated_by/at, is_simulated, created_at/updated_at
-- -----------------------------------------------------------------------------

CREATE TABLE accidents (
  id                    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id             uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
  transport_mode_id     smallint NOT NULL REFERENCES transport_modes(id),
  occurred_at           timestamptz,               -- NULL si l'heure est inconnue
  occurred_date         date NOT NULL,             -- toujours renseignée
  location_id           bigint REFERENCES locations(id) ON DELETE SET NULL,
  weather_condition_id  bigint REFERENCES weather_conditions(id) ON DELETE SET NULL,
  category              text,                      -- typologie propre au mode (collision, CFIT, déraillement…)
  severity              severity_level NOT NULL DEFAULT 'unknown',
  severity_source_label text,                      -- gravité telle qu'exprimée par la source
  fatalities            integer CHECK (fatalities >= 0),
  serious_injuries      integer CHECK (serious_injuries >= 0),
  minor_injuries        integer CHECK (minor_injuries >= 0),
  summary               text,
  -- provenance & qualité
  data_source_id        bigint NOT NULL REFERENCES data_sources(id) ON DELETE RESTRICT,
  source_record_id      bigint REFERENCES source_records(id) ON DELETE SET NULL,
  source_ref            text NOT NULL,             -- identifiant dans la source
  confidence            confidence_level NOT NULL DEFAULT 'unknown',
  validation_status     validation_status NOT NULL DEFAULT 'unverified',
  validated_by          bigint REFERENCES users(id) ON DELETE SET NULL,
  validated_at          timestamptz,
  is_simulated          boolean NOT NULL DEFAULT false,
  created_by            bigint REFERENCES users(id) ON DELETE SET NULL,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  UNIQUE (data_source_id, source_ref),
  CHECK (occurred_at IS NULL OR (occurred_at AT TIME ZONE 'UTC')::date BETWEEN occurred_date - 1 AND occurred_date + 1),
  CHECK (severity <> 'fatal' OR fatalities IS NULL OR fatalities > 0),
  CHECK (fatalities IS NULL OR fatalities = 0 OR severity IN ('fatal', 'unknown')),
  CHECK (validation_status <> 'validated' OR (validated_by IS NOT NULL AND validated_at IS NOT NULL))
);
CREATE INDEX accidents_mode_date_idx ON accidents (transport_mode_id, occurred_date);
CREATE INDEX accidents_location_idx  ON accidents (location_id);
CREATE INDEX accidents_status_idx    ON accidents (validation_status);

CREATE TABLE incidents (
  id                    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id             uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
  transport_mode_id     smallint NOT NULL REFERENCES transport_modes(id),
  incident_class        incident_class NOT NULL DEFAULT 'incident',
  occurred_at           timestamptz,
  occurred_date         date NOT NULL,
  location_id           bigint REFERENCES locations(id) ON DELETE SET NULL,
  weather_condition_id  bigint REFERENCES weather_conditions(id) ON DELETE SET NULL,
  category              text,
  minor_injuries        integer CHECK (minor_injuries >= 0),
  summary               text,
  escalated_to_accident_id bigint REFERENCES accidents(id) ON DELETE SET NULL, -- requalification
  data_source_id        bigint NOT NULL REFERENCES data_sources(id) ON DELETE RESTRICT,
  source_record_id      bigint REFERENCES source_records(id) ON DELETE SET NULL,
  source_ref            text NOT NULL,
  confidence            confidence_level NOT NULL DEFAULT 'unknown',
  validation_status     validation_status NOT NULL DEFAULT 'unverified',
  validated_by          bigint REFERENCES users(id) ON DELETE SET NULL,
  validated_at          timestamptz,
  is_simulated          boolean NOT NULL DEFAULT false,
  created_by            bigint REFERENCES users(id) ON DELETE SET NULL,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  UNIQUE (data_source_id, source_ref),
  CHECK (occurred_at IS NULL OR (occurred_at AT TIME ZONE 'UTC')::date BETWEEN occurred_date - 1 AND occurred_date + 1),
  CHECK (validation_status <> 'validated' OR (validated_by IS NOT NULL AND validated_at IS NOT NULL))
);
CREATE INDEX incidents_mode_date_idx ON incidents (transport_mode_id, occurred_date);
CREATE INDEX incidents_location_idx  ON incidents (location_id);

-- Signalement saisi par un agent déclarant (Vue.js / Power Apps).
-- Non vérifié par construction ; après revue il est qualifié en accident ou incident.
-- (Table ajoutée à la liste du §4 pour matérialiser le « signalement non vérifié ».)
CREATE TABLE reports (
  id                 bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id          uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
  reporter_id        bigint REFERENCES users(id) ON DELETE SET NULL,
  transport_mode_id  smallint NOT NULL REFERENCES transport_modes(id),
  occurred_at        timestamptz,
  occurred_date      date NOT NULL,
  location_id        bigint REFERENCES locations(id) ON DELETE SET NULL,
  description        text NOT NULL,
  proposed_kind      text NOT NULL DEFAULT 'unknown' CHECK (proposed_kind IN ('accident', 'incident', 'unknown')),
  validation_status  validation_status NOT NULL DEFAULT 'unverified',
  reviewed_by        bigint REFERENCES users(id) ON DELETE SET NULL,
  reviewed_at        timestamptz,
  review_comment     text,
  accident_id        bigint REFERENCES accidents(id) ON DELETE SET NULL,  -- après qualification
  incident_id        bigint REFERENCES incidents(id) ON DELETE SET NULL,
  is_simulated       boolean NOT NULL DEFAULT false,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  CHECK (num_nonnulls(accident_id, incident_id) <= 1),
  CHECK (validation_status IN ('unverified', 'under_review') OR (reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL))
);
CREATE INDEX reports_status_idx ON reports (validation_status, created_at);

-- Contact du déclarant : donnée personnelle, isolée.
CREATE TABLE sensitive.report_contacts (
  report_id   bigint PRIMARY KEY REFERENCES core.reports(id) ON DELETE CASCADE,
  name        text,
  email       text,
  phone       text,
  consent_at  timestamptz NOT NULL,       -- consentement à être recontacté
  delete_after date NOT NULL               -- minimisation : date de purge
);

-- Véhicules impliqués (accident OU incident).
CREATE TABLE event_vehicles (
  id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  accident_id  bigint REFERENCES accidents(id) ON DELETE CASCADE,
  incident_id  bigint REFERENCES incidents(id) ON DELETE CASCADE,
  vehicle_id   bigint NOT NULL REFERENCES vehicles(id) ON DELETE RESTRICT,
  role         text,       -- ex. « véhicule A », « aéronef principal »
  occupants    integer CHECK (occupants >= 0),
  CHECK (num_nonnulls(accident_id, incident_id) = 1),
  UNIQUE (accident_id, vehicle_id),
  UNIQUE (incident_id, vehicle_id)
);

-- Facteurs contributifs : un facteur peut être établi, probable ou une simple hypothèse.
CREATE TABLE accident_factors (
  id                 bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  accident_id        bigint REFERENCES accidents(id) ON DELETE CASCADE,
  incident_id        bigint REFERENCES incidents(id) ON DELETE CASCADE,
  category           factor_category NOT NULL,
  factor_code        text,          -- code de taxonomie (ex. ADREP / ICAO, CAST)
  description        text NOT NULL,
  assertion_level    assertion_level NOT NULL DEFAULT 'hypothesis',
  confidence         confidence_level NOT NULL DEFAULT 'unknown',
  evidence_document_id bigint,      -- FK ajoutée après création de documents
  stated_by          text NOT NULL DEFAULT 'internal_analysis'
                     CHECK (stated_by IN ('investigation_body', 'internal_analysis', 'ai_suggestion', 'source_data')),
  data_source_id     bigint REFERENCES data_sources(id) ON DELETE RESTRICT,
  created_by         bigint REFERENCES users(id) ON DELETE SET NULL,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  CHECK (num_nonnulls(accident_id, incident_id) = 1),
  -- Un facteur « établi » doit s'appuyer sur un document ou une source de données.
  CHECK (assertion_level <> 'established' OR evidence_document_id IS NOT NULL OR data_source_id IS NOT NULL),
  -- Une suggestion d'IA ne peut jamais être enregistrée comme fait établi.
  CHECK (stated_by <> 'ai_suggestion' OR assertion_level = 'hypothesis')
);
CREATE INDEX accident_factors_accident_idx ON accident_factors (accident_id);
CREATE INDEX accident_factors_incident_idx ON accident_factors (incident_id);

-- Dénominateurs d'exposition, indispensables aux comparaisons entre modes/pays.
-- (Table ajoutée à la liste du §4.)
CREATE TABLE exposure_measures (
  id                 bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  transport_mode_id  smallint NOT NULL REFERENCES transport_modes(id),
  country_code       char(2) NOT NULL CHECK (country_code ~ '^[A-Z]{2}$'),
  admin1             text NOT NULL DEFAULT '',          -- '' = niveau national
  period_start       date NOT NULL,
  period_end         date NOT NULL,
  metric             exposure_metric NOT NULL,
  value              numeric NOT NULL CHECK (value > 0),
  unit_note          text,
  data_source_id     bigint NOT NULL REFERENCES data_sources(id) ON DELETE RESTRICT,
  confidence         confidence_level NOT NULL DEFAULT 'unknown',
  is_simulated       boolean NOT NULL DEFAULT false,
  created_at         timestamptz NOT NULL DEFAULT now(),
  CHECK (period_end >= period_start),
  UNIQUE (transport_mode_id, country_code, admin1, period_start, period_end, metric, data_source_id)
);

-- -----------------------------------------------------------------------------
-- 7. Documents et RAG (pgvector)
-- -----------------------------------------------------------------------------

CREATE TABLE documents (
  id                 bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  title              text NOT NULL,
  document_type      document_type NOT NULL,
  issuing_org_id     bigint REFERENCES organizations(id) ON DELETE RESTRICT,  -- organisme
  transport_mode_id  smallint REFERENCES transport_modes(id),
  country_code       char(2) CHECK (country_code ~ '^[A-Z]{2}$'),
  region             text,
  url                text NOT NULL,
  license            text NOT NULL,       -- corpus public documenté : licence obligatoire
  language           text NOT NULL CHECK (language ~ '^[a-z]{2}$'),   -- ISO 639-1
  published_on       date,
  version            text NOT NULL DEFAULT '1',
  file_sha256        char(64) NOT NULL CHECK (file_sha256 ~ '^[0-9a-f]{64}$'),
  page_count         integer CHECK (page_count > 0),
  accident_id        bigint REFERENCES accidents(id) ON DELETE SET NULL,
  incident_id        bigint REFERENCES incidents(id) ON DELETE SET NULL,
  data_source_id     bigint REFERENCES data_sources(id) ON DELETE RESTRICT,
  ingested_at        timestamptz NOT NULL DEFAULT now(),
  created_at         timestamptz NOT NULL DEFAULT now(),
  UNIQUE (url, version),
  UNIQUE (file_sha256),
  CHECK (num_nonnulls(accident_id, incident_id) <= 1)
);

ALTER TABLE accident_factors
  ADD CONSTRAINT accident_factors_evidence_fk
  FOREIGN KEY (evidence_document_id) REFERENCES documents(id) ON DELETE SET NULL;

-- Dimension 1024 : modèle multilingue type bge-m3 / multilingual-e5-large.
-- Changer de modèle = nouvelle colonne/ré-indexation ; le modèle est tracé par ligne.
CREATE TABLE document_chunks (
  id                bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  document_id       bigint NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
  chunking_version  text NOT NULL,           -- paramètres de segmentation (taille, recouvrement)
  chunk_index       integer NOT NULL CHECK (chunk_index >= 0),
  page_start        integer NOT NULL CHECK (page_start > 0),
  page_end          integer NOT NULL,
  section_title     text,
  content           text NOT NULL,
  content_tsv       tsvector GENERATED ALWAYS AS (to_tsvector('simple', content)) STORED,  -- recherche lexicale
  token_count       integer CHECK (token_count > 0),
  embedding         vector(1024),
  embedding_model   text,
  created_at        timestamptz NOT NULL DEFAULT now(),
  UNIQUE (document_id, chunking_version, chunk_index),
  CHECK (page_end >= page_start),
  CHECK ((embedding IS NULL) = (embedding_model IS NULL))
);
CREATE INDEX document_chunks_tsv_gin ON document_chunks USING gin (content_tsv);
CREATE INDEX document_chunks_embedding_hnsw ON document_chunks USING hnsw (embedding vector_cosine_ops);

CREATE TABLE rag_queries (
  id                 bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id            bigint REFERENCES users(id) ON DELETE SET NULL,
  question           text NOT NULL,
  filters            jsonb,                 -- {mode, region, period, organization}
  answer             text,
  abstained          boolean NOT NULL DEFAULT false,
  abstention_reason  text,
  conflicts_detected boolean NOT NULL DEFAULT false,
  llm_provider       text NOT NULL,          -- local / api
  llm_model          text NOT NULL,
  prompt_version     text NOT NULL,
  retrieval_config   jsonb,                  -- k, poids lexical/vectoriel, reranker
  latency_ms         integer CHECK (latency_ms >= 0),
  input_tokens       integer CHECK (input_tokens >= 0),
  output_tokens      integer CHECK (output_tokens >= 0),
  cost_eur           numeric(10,5) CHECK (cost_eur >= 0),
  user_rating        smallint CHECK (user_rating BETWEEN 1 AND 5),
  is_benchmark       boolean NOT NULL DEFAULT false,   -- question du jeu de référence
  created_at         timestamptz NOT NULL DEFAULT now(),
  CHECK (abstained OR answer IS NOT NULL),
  CHECK (NOT abstained OR abstention_reason IS NOT NULL)
);

-- Passages récupérés / cités pour chaque réponse (citations + pages).
CREATE TABLE rag_query_chunks (
  rag_query_id  bigint  NOT NULL REFERENCES rag_queries(id) ON DELETE CASCADE,
  chunk_id      bigint  NOT NULL REFERENCES document_chunks(id) ON DELETE RESTRICT,
  rank          integer NOT NULL CHECK (rank > 0),
  lexical_score real,
  vector_score  real,
  fused_score   real,
  cited         boolean NOT NULL DEFAULT false,
  PRIMARY KEY (rag_query_id, chunk_id)
);

-- -----------------------------------------------------------------------------
-- 8. Prévention : recommandations, mesures, évaluation
-- -----------------------------------------------------------------------------

CREATE TABLE corrective_actions (
  id                 bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  title              text NOT NULL,
  description        text NOT NULL,
  kind               action_kind NOT NULL DEFAULT 'recommendation',
  origin             action_origin NOT NULL,
  transport_mode_id  smallint REFERENCES transport_modes(id),
  accident_id        bigint REFERENCES accidents(id) ON DELETE SET NULL,
  incident_id        bigint REFERENCES incidents(id) ON DELETE SET NULL,
  source_document_id bigint REFERENCES documents(id) ON DELETE SET NULL,
  source_reference   text,          -- n° de recommandation de l'organisme d'enquête
  target_org_id      bigint REFERENCES organizations(id) ON DELETE SET NULL,
  status             action_status NOT NULL DEFAULT 'proposed',
  proposed_by        bigint REFERENCES users(id) ON DELETE SET NULL,
  approved_by        bigint REFERENCES users(id) ON DELETE SET NULL,   -- validation humaine
  approved_at        timestamptz,
  due_date           date,
  implemented_at     date,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  CHECK (num_nonnulls(accident_id, incident_id) <= 1),
  -- Aucune mesure ne passe en approbation/mise en œuvre sans validation humaine.
  CHECK (status NOT IN ('approved', 'in_progress', 'implemented')
         OR (approved_by IS NOT NULL AND approved_at IS NOT NULL)),
  CHECK (status <> 'implemented' OR implemented_at IS NOT NULL),
  -- Seule une mesure (pas une recommandation) peut être mise en œuvre.
  CHECK (status NOT IN ('in_progress', 'implemented') OR kind = 'measure')
);
CREATE INDEX corrective_actions_status_idx ON corrective_actions (status);

CREATE TABLE action_evaluations (
  id                    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  corrective_action_id  bigint NOT NULL REFERENCES corrective_actions(id) ON DELETE CASCADE,
  indicator             text NOT NULL,   -- ex. accidents graves / 100 M véh-km
  exposure_metric       exposure_metric,
  before_start          date NOT NULL,
  before_end            date NOT NULL,
  after_start           date NOT NULL,
  after_end             date NOT NULL,
  value_before          numeric,
  value_after           numeric,
  ci_low                numeric,         -- intervalle de confiance de l'écart
  ci_high               numeric,
  method                text NOT NULL,   -- avant/après, groupe témoin, DiD, ITS…
  conclusion            evaluation_conclusion NOT NULL DEFAULT 'inconclusive',
  evaluated_by          bigint REFERENCES users(id) ON DELETE SET NULL,
  notes                 text,
  created_at            timestamptz NOT NULL DEFAULT now(),
  CHECK (before_end >= before_start AND after_end >= after_start AND after_start > before_end),
  CHECK (ci_low IS NULL OR ci_high IS NULL OR ci_low <= ci_high)
);

-- -----------------------------------------------------------------------------
-- 9. IA prédictive (probabiliste, aide à l'analyse uniquement)
-- -----------------------------------------------------------------------------

CREATE TABLE risk_predictions (
  id                 bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  model_name         text NOT NULL,
  model_version      text NOT NULL,        -- version MLflow / tag
  model_card_url     text,
  transport_mode_id  smallint NOT NULL REFERENCES transport_modes(id),
  location_id        bigint REFERENCES locations(id) ON DELETE CASCADE,
  zone               geography(Polygon, 4326),   -- alternative : maille/zone
  period_start       date NOT NULL,
  period_end         date NOT NULL,
  target             text NOT NULL,        -- ex. P(≥1 accident grave sur la période)
  risk_score         numeric(6,5) NOT NULL CHECK (risk_score BETWEEN 0 AND 1),
  ci_low             numeric(6,5) NOT NULL CHECK (ci_low BETWEEN 0 AND 1),
  ci_high            numeric(6,5) NOT NULL CHECK (ci_high BETWEEN 0 AND 1),
  explanation        jsonb,                -- contributions des variables (SHAP…)
  training_cutoff    date NOT NULL,        -- évaluation temporelle : pas de fuite
  is_simulated       boolean NOT NULL DEFAULT false,
  created_at         timestamptz NOT NULL DEFAULT now(),
  CHECK (ci_low <= risk_score AND risk_score <= ci_high),
  CHECK (period_end >= period_start),
  CHECK (training_cutoff <= period_start),
  CHECK (num_nonnulls(location_id, zone) = 1)
);
CREATE INDEX risk_predictions_lookup_idx ON risk_predictions (transport_mode_id, period_start, model_version);
CREATE INDEX risk_predictions_zone_gix ON risk_predictions USING gist (zone);

COMMENT ON TABLE risk_predictions IS
  'Scores probabilistes d''aide à l''analyse. Ne doivent pas piloter un système de sécurité critique.';

-- -----------------------------------------------------------------------------
-- 10. Audit
-- L'application positionne l'acteur par transaction :
--   SET LOCAL app.user_id = '42'; SET LOCAL app.actor_type = 'user';
--   SET LOCAL app.request_id = '…';
-- -----------------------------------------------------------------------------

CREATE TABLE audit_logs (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  occurred_at   timestamptz NOT NULL DEFAULT now(),
  actor_user_id bigint REFERENCES users(id) ON DELETE SET NULL,
  actor_type    actor_type NOT NULL DEFAULT 'system',
  action        text NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE', 'LOGIN', 'EXPORT', 'VALIDATE', 'OTHER')),
  table_name    text NOT NULL,
  row_id        bigint,
  old_data      jsonb,
  new_data      jsonb,
  request_id    text,
  client_ip     inet
);
CREATE INDEX audit_logs_entity_idx ON audit_logs (table_name, row_id, occurred_at);
CREATE INDEX audit_logs_actor_idx  ON audit_logs (actor_user_id, occurred_at);

CREATE OR REPLACE FUNCTION core.audit_row_change() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = core, pg_temp AS $$
DECLARE
  v_user  bigint     := nullif(current_setting('app.user_id', true), '')::bigint;
  v_type  actor_type := coalesce(nullif(current_setting('app.actor_type', true), ''), 'system')::actor_type;
  v_req   text       := nullif(current_setting('app.request_id', true), '');
  v_old   jsonb;
  v_new   jsonb;
BEGIN
  IF TG_OP IN ('UPDATE', 'DELETE') THEN v_old := to_jsonb(OLD); END IF;
  IF TG_OP IN ('INSERT', 'UPDATE') THEN v_new := to_jsonb(NEW); END IF;
  -- Les vecteurs d'embedding ne sont pas journalisés (volume).
  v_old := v_old - 'embedding';
  v_new := v_new - 'embedding';
  INSERT INTO core.audit_logs (actor_user_id, actor_type, action, table_name, row_id, old_data, new_data, request_id)
  VALUES (v_user, v_type, TG_OP, TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME,
          coalesce(v_new ->> 'id', v_old ->> 'id')::bigint, v_old, v_new, v_req);
  RETURN NULL;
END $$;

-- Triggers updated_at + audit sur les tables métier.
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['organizations', 'users', 'data_sources', 'accidents', 'incidents',
                           'reports', 'accident_factors', 'corrective_actions']
  LOOP
    EXECUTE format('CREATE TRIGGER %I BEFORE UPDATE ON core.%I FOR EACH ROW EXECUTE FUNCTION core.set_updated_at()',
                   t || '_set_updated_at', t);
  END LOOP;

  FOREACH t IN ARRAY ARRAY['users', 'user_roles', 'data_sources', 'import_jobs', 'accidents', 'incidents',
                           'reports', 'accident_factors', 'corrective_actions', 'action_evaluations',
                           'documents', 'exposure_measures']
  LOOP
    EXECUTE format('CREATE TRIGGER %I AFTER INSERT OR UPDATE OR DELETE ON core.%I FOR EACH ROW EXECUTE FUNCTION core.audit_row_change()',
                   t || '_audit', t);
  END LOOP;
END $$;

CREATE TRIGGER user_identities_set_updated_at BEFORE UPDATE ON sensitive.user_identities
  FOR EACH ROW EXECUTE FUNCTION core.set_updated_at();

-- Le journal d'audit est en ajout seul.
CREATE OR REPLACE FUNCTION core.audit_logs_immutable() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'audit_logs est en ajout seul (% interdit)', TG_OP;
END $$;
CREATE TRIGGER audit_logs_no_update BEFORE UPDATE OR DELETE ON audit_logs
  FOR EACH ROW EXECUTE FUNCTION core.audit_logs_immutable();

-- -----------------------------------------------------------------------------
-- 11. Cohérence « simulé » : un fait issu d'une source de simulation est simulé.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION core.enforce_simulated_flag() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF (SELECT is_simulated FROM core.data_sources WHERE id = NEW.data_source_id) THEN
    NEW.is_simulated := true;
  ELSIF NEW.is_simulated THEN
    RAISE EXCEPTION 'Donnée marquée simulée mais rattachée à une source réelle (data_source_id=%)', NEW.data_source_id;
  END IF;
  RETURN NEW;
END $$;

CREATE TRIGGER accidents_simulated_flag BEFORE INSERT OR UPDATE OF data_source_id, is_simulated ON accidents
  FOR EACH ROW EXECUTE FUNCTION core.enforce_simulated_flag();
CREATE TRIGGER incidents_simulated_flag BEFORE INSERT OR UPDATE OF data_source_id, is_simulated ON incidents
  FOR EACH ROW EXECUTE FUNCTION core.enforce_simulated_flag();
CREATE TRIGGER exposure_simulated_flag BEFORE INSERT OR UPDATE OF data_source_id, is_simulated ON exposure_measures
  FOR EACH ROW EXECUTE FUNCTION core.enforce_simulated_flag();

