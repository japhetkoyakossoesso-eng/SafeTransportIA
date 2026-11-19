-- Migration Flyway convertie depuis 003_bi.sql (V1 du modèle, testé 29/29).
-- BEGIN/COMMIT retirés : Flyway exécute chaque migration dans sa propre transaction.
-- =============================================================================
-- SafeTransport AI — Modèle en étoile pour Power BI (schéma bi)
-- Faits : accidents + incidents (une ligne par événement).
-- Dimensions : temps, mode, lieu, gravité, source.
-- Power BI filtre par défaut : validation_status = 'validated' AND NOT is_simulated.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS bi;
SET search_path = bi, core, public;

-- Dimension temps matérialisée (2000 → 2035).
CREATE TABLE bi.dim_date (
  date_key     integer PRIMARY KEY,         -- AAAAMMJJ
  full_date    date NOT NULL UNIQUE,
  year         smallint NOT NULL,
  quarter      smallint NOT NULL,
  month        smallint NOT NULL,
  month_name   text NOT NULL,
  iso_week     smallint NOT NULL,
  day_of_week  smallint NOT NULL,           -- 1 = lundi
  is_weekend   boolean NOT NULL
);
INSERT INTO bi.dim_date
SELECT to_char(d, 'YYYYMMDD')::int, d, extract(year FROM d), extract(quarter FROM d), extract(month FROM d),
       to_char(d, 'TMMonth'), extract(week FROM d), extract(isodow FROM d), extract(isodow FROM d) IN (6, 7)
FROM generate_series('2000-01-01'::date, '2035-12-31'::date, interval '1 day') AS g(d);

CREATE VIEW bi.dim_mode AS
  SELECT id AS mode_key, code, label_fr, label_en FROM core.transport_modes;

CREATE VIEW bi.dim_location AS
  SELECT id AS location_key, country_code, admin1, admin2, municipality, site_name, site_code, precision::text,
         ST_Y(geom::geometry) AS latitude, ST_X(geom::geometry) AS longitude
  FROM core.locations;

CREATE VIEW bi.dim_severity AS
  SELECT s::text AS severity_key, ord AS severity_rank
  FROM unnest(enum_range(NULL::core.severity_level)) WITH ORDINALITY AS t(s, ord);

CREATE VIEW bi.dim_source AS
  SELECT ds.id AS source_key, ds.code, ds.name, ds.kind::text, ds.license, ds.country_code,
         ds.default_confidence::text, ds.is_simulated, o.acronym AS provider
  FROM core.data_sources ds LEFT JOIN core.organizations o ON o.id = ds.provider_org_id;

CREATE VIEW bi.fact_occurrences AS
  SELECT 'accident'::text            AS occurrence_type,
         a.id                        AS occurrence_id,
         to_char(a.occurred_date, 'YYYYMMDD')::int AS date_key,
         a.transport_mode_id         AS mode_key,
         a.location_id               AS location_key,
         a.severity::text            AS severity_key,
         a.data_source_id            AS source_key,
         a.category,
         coalesce(a.fatalities, 0)        AS fatalities,
         coalesce(a.serious_injuries, 0)  AS serious_injuries,
         coalesce(a.minor_injuries, 0)    AS minor_injuries,
         a.confidence::text          AS confidence,
         a.validation_status::text   AS validation_status,
         a.is_simulated
  FROM core.accidents a
  UNION ALL
  SELECT 'incident', i.id, to_char(i.occurred_date, 'YYYYMMDD')::int, i.transport_mode_id, i.location_id,
         CASE WHEN coalesce(i.minor_injuries, 0) > 0 THEN 'minor' ELSE 'none' END,
         i.data_source_id, i.category, 0, 0, coalesce(i.minor_injuries, 0),
         i.confidence::text, i.validation_status::text, i.is_simulated
  FROM core.incidents i;

-- Indicateur comparable : taux pour une mesure d'exposition, par mode / pays / année.
CREATE VIEW bi.annual_rates AS
  WITH counts AS (
    SELECT a.transport_mode_id, l.country_code, extract(year FROM a.occurred_date)::int AS year, a.is_simulated,
           count(*) AS accidents,
           count(*) FILTER (WHERE a.severity = 'fatal') AS fatal_accidents,
           sum(coalesce(a.fatalities, 0)) AS fatalities
    FROM core.accidents a JOIN core.locations l ON l.id = a.location_id
    WHERE a.validation_status IN ('validated', 'unverified') -- à restreindre à 'validated' en production
    GROUP BY 1, 2, 3, 4
  )
  SELECT c.*, e.metric::text AS exposure_metric, e.value AS exposure_value,
         c.accidents  / e.value * 1e8 AS accidents_per_1e8_exposure,
         c.fatalities / e.value * 1e8 AS fatalities_per_1e8_exposure
  FROM counts c
  JOIN core.exposure_measures e
    ON e.transport_mode_id = c.transport_mode_id AND e.country_code = c.country_code AND e.admin1 = ''
   AND e.period_start = make_date(c.year, 1, 1) AND e.period_end = make_date(c.year, 12, 31)
   AND e.is_simulated = c.is_simulated;

