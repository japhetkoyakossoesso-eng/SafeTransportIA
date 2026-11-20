-- Dénominateurs d'exposition lisibles depuis le schéma bi (statistiques, Power BI)

CREATE VIEW bi.fact_exposure AS
  SELECT e.id                          AS exposure_id,
         e.transport_mode_id           AS mode_key,
         e.country_code,
         e.admin1,
         e.period_start,
         e.period_end,
         extract(year FROM e.period_start)::int AS year,
         e.metric::text                AS metric,
         e.value,
         e.unit_note,
         e.data_source_id              AS source_key,
         e.confidence::text            AS confidence,
         e.is_simulated
  FROM core.exposure_measures e;

GRANT SELECT ON bi.fact_exposure TO st_api, st_bi_reader, st_agent_readonly;

-- Liens précis des deux sources d'exposition
UPDATE core.data_sources
SET url = 'https://www.statistiques.developpement-durable.gouv.fr/bilan-annuel-des-transports-en-2023',
    known_biases = 'Dénominateur d''exposition routier, France métropolitaine seulement. Estimations nationales annuelles, '
                   'rebasées en 2023 et provisoires pour la dernière année.'
WHERE code = 'sdes_circulation';

UPDATE core.data_sources
SET url = 'https://www.faa.gov/data_research/aviation_data_statistics/general_aviation',
    known_biases = 'Dénominateur d''exposition pour l''aviation générale américaine et la partie 135. Enquête par sondage, '
                   'erreur type d''environ 1 % sur le total. Ne couvre pas le transport commercial régulier (parties 121 et 129).'
WHERE code = 'faa_ga_survey';
