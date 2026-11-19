-- Tests SQL des contraintes, dans une transaction annulée à la fin

\pset tuples_only on
\pset format unaligned
BEGIN;
SET search_path = core, public;

-- Vérifie qu'une instruction échoue avec le SQLSTATE attendu.
CREATE FUNCTION pg_temp.expect_error(label text, stmt text, expected_state text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  BEGIN
    EXECUTE stmt;
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE = expected_state THEN
      RAISE NOTICE 'OK   %', label;
      RETURN;
    END IF;
    RAISE EXCEPTION 'FAIL % : SQLSTATE % attendu, % obtenu (%)', label, expected_state, SQLSTATE, SQLERRM;
  END;
  RAISE EXCEPTION 'FAIL % : l''instruction aurait dû échouer', label;
END $$;

CREATE FUNCTION pg_temp.expect_true(label text, cond boolean) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  IF cond IS NOT TRUE THEN RAISE EXCEPTION 'FAIL %', label; END IF;
  RAISE NOTICE 'OK   %', label;
END $$;

-- 1. Unicité des identifiants sources (dédoublonnage / idempotence)
SELECT pg_temp.expect_error('accident en double (même source, même source_ref) refusé',
  $$INSERT INTO accidents (transport_mode_id, occurred_date, data_source_id, source_ref)
    VALUES (1, '2025-03-14', 900, 'SIM-ROAD-0001')$$, '23505');

SELECT pg_temp.expect_error('enregistrement brut identique refusé',
  $$INSERT INTO source_records (data_source_id, external_id, record_sha256, payload)
    VALUES (1, 'X1', repeat('a', 64), '{}'), (1, 'X1', repeat('a', 64), '{}')$$, '23505');

INSERT INTO import_jobs (data_source_id, status, file_sha256, pipeline_name, pipeline_version)
VALUES (1, 'succeeded', repeat('b', 64), 'etl.onisr_baac', 'v0.1.0');
SELECT pg_temp.expect_error('même fichier importé deux fois avec succès refusé',
  $$INSERT INTO import_jobs (data_source_id, status, file_sha256, pipeline_name, pipeline_version)
    VALUES (1, 'succeeded', repeat('b', 64), 'etl.onisr_baac', 'v0.1.0')$$, '23505');
INSERT INTO import_jobs (data_source_id, status, file_sha256, pipeline_name, pipeline_version)
VALUES (1, 'failed', repeat('b', 64), 'etl.onisr_baac', 'v0.1.0');   -- une tentative échouée reste permise
SELECT pg_temp.expect_true('tentative échouée du même fichier acceptée', true);

-- 2. Validation humaine obligatoire
SELECT pg_temp.expect_error('accident « validated » sans validateur refusé',
  $$UPDATE accidents SET validation_status = 'validated' WHERE id = 1$$, '23514');
UPDATE accidents SET validation_status = 'validated', validated_by = 4, validated_at = now() WHERE id = 1;
SELECT pg_temp.expect_true('accident validé avec validateur accepté',
  (SELECT validation_status = 'validated' FROM accidents WHERE id = 1));

SELECT pg_temp.expect_error('mesure approuvée sans approbateur refusée',
  $$UPDATE corrective_actions SET status = 'approved' WHERE id = 1$$, '23514');
SELECT pg_temp.expect_error('recommandation « implemented » refusée (seule une mesure peut l''être)',
  $$UPDATE corrective_actions SET status = 'implemented', approved_by = 4, approved_at = now(),
      implemented_at = current_date WHERE id = 1$$, '23514');

-- 3. Hypothèse vs fait établi
SELECT pg_temp.expect_error('suggestion IA enregistrée comme fait établi refusée',
  $$INSERT INTO accident_factors (accident_id, category, description, assertion_level, stated_by, data_source_id)
    VALUES (1, 'human', 'x', 'established', 'ai_suggestion', 900)$$, '23514');
SELECT pg_temp.expect_error('fait établi sans preuve refusé',
  $$INSERT INTO accident_factors (accident_id, category, description, assertion_level)
    VALUES (1, 'human', 'x', 'established')$$, '23514');
SELECT pg_temp.expect_error('facteur rattaché à la fois à un accident et un incident refusé',
  $$INSERT INTO accident_factors (accident_id, incident_id, category, description)
    VALUES (1, 1, 'human', 'x')$$, '23514');

-- 4. Données simulées
SELECT pg_temp.expect_true('fait issu de sim_demo marqué simulé automatiquement',
  (SELECT bool_and(is_simulated) FROM accidents WHERE data_source_id = 900));
SELECT pg_temp.expect_error('donnée simulée rattachée à une source réelle refusée',
  $$INSERT INTO accidents (transport_mode_id, occurred_date, data_source_id, source_ref, is_simulated)
    VALUES (1, '2025-01-01', 1, 'FAKE-1', true)$$, 'P0001');
SELECT pg_temp.expect_error('source « simulation » non marquée simulée refusée',
  $$INSERT INTO data_sources (code, name, kind) VALUES ('sim_bad', 'x', 'simulation')$$, '23514');

-- 5. Gravité harmonisée cohérente
SELECT pg_temp.expect_error('accident mortel avec 0 tué refusé',
  $$INSERT INTO accidents (transport_mode_id, occurred_date, severity, fatalities, data_source_id, source_ref)
    VALUES (1, '2025-01-01', 'fatal', 0, 900, 'SIM-X-1')$$, '23514');
SELECT pg_temp.expect_error('tués > 0 mais gravité « minor » refusé',
  $$INSERT INTO accidents (transport_mode_id, occurred_date, severity, fatalities, data_source_id, source_ref)
    VALUES (1, '2025-01-01', 'minor', 2, 900, 'SIM-X-2')$$, '23514');

-- 6. Prédictions probabilistes bornées, sans fuite temporelle
SELECT pg_temp.expect_error('score hors intervalle de confiance refusé',
  $$INSERT INTO risk_predictions (model_name, model_version, transport_mode_id, location_id, period_start, period_end,
      target, risk_score, ci_low, ci_high, training_cutoff)
    VALUES ('rf', '0.1', 1, 1, '2026-01-01', '2026-12-31', 'p', 0.9, 0.1, 0.5, '2025-12-31')$$, '23514');
SELECT pg_temp.expect_error('données d''entraînement postérieures à la période prédite refusées',
  $$INSERT INTO risk_predictions (model_name, model_version, transport_mode_id, location_id, period_start, period_end,
      target, risk_score, ci_low, ci_high, training_cutoff)
    VALUES ('rf', '0.1', 1, 1, '2026-01-01', '2026-12-31', 'p', 0.3, 0.1, 0.5, '2026-06-30')$$, '23514');

-- 7. RAG : abstention justifiée, embeddings, recherche hybride
SELECT pg_temp.expect_error('réponse RAG ni donnée ni abstenue refusée',
  $$INSERT INTO rag_queries (question, llm_provider, llm_model, prompt_version) VALUES ('q', 'local', 'm', 'v1')$$, '23514');

INSERT INTO documents (title, document_type, issuing_org_id, transport_mode_id, url, license, language, file_sha256, page_count)
VALUES ('Rapport fictif', 'investigation_report', 3, 2, 'https://example.org/r.pdf', 'Etalab 2.0', 'fr', repeat('c', 64), 10);
INSERT INTO document_chunks (document_id, chunking_version, chunk_index, page_start, page_end, content, embedding, embedding_model)
SELECT (SELECT id FROM documents WHERE file_sha256 = repeat('c', 64)), 'c512-o64', g, g + 1, g + 1, 'Incursion sur piste et remise de gaz, passage ' || g,
       (SELECT array_agg(random())::real[] FROM generate_series(1, 1024))::vector, 'bge-m3'
FROM generate_series(0, 4) g;
SELECT pg_temp.expect_true('recherche lexicale trouve les passages',
  (SELECT count(*) = 5 FROM document_chunks WHERE content_tsv @@ plainto_tsquery('simple', 'incursion piste')));
SELECT pg_temp.expect_true('recherche vectorielle (cosinus) renvoie un plus proche voisin',
  (SELECT count(*) = 3 FROM (SELECT id FROM document_chunks
     ORDER BY embedding <=> (SELECT embedding FROM document_chunks WHERE chunk_index = 2) LIMIT 3) s));

-- 8. Audit automatique et immuable
SELECT pg_temp.expect_true('validation de l''accident journalisée avec l''acteur',
  EXISTS (SELECT 1 FROM audit_logs WHERE table_name = 'core.accidents' AND row_id = 1 AND action = 'UPDATE'
          AND new_data ->> 'validation_status' = 'validated'));
SELECT pg_temp.expect_true('insertion ETL journalisée comme service (acteur 5)',
  EXISTS (SELECT 1 FROM audit_logs WHERE table_name = 'core.accidents' AND action = 'INSERT'
          AND actor_user_id = 5 AND actor_type = 'service'));
SELECT pg_temp.expect_error('modification du journal d''audit refusée',
  $$UPDATE audit_logs SET action = 'OTHER'$$, 'P0001');

-- 9. Spatial et BI
SELECT pg_temp.expect_true('distance Toulouse–Blagnac ≈ 6,6 km (PostGIS)',
  (SELECT ST_Distance(a.geom, b.geom) BETWEEN 6000 AND 7500 FROM locations a, locations b WHERE a.id = 1 AND b.id = 2));
SELECT pg_temp.expect_true('fait BI : 2 accidents + 1 incident',
  (SELECT count(*) = 3 FROM bi.fact_occurrences));
SELECT pg_temp.expect_true('taux annuel calculé avec dénominateur d''exposition',
  (SELECT accidents_per_1e8_exposure > 0 FROM bi.annual_rates WHERE year = 2025 AND country_code = 'FR'));

-- 10. Séparation des données sensibles
SELECT pg_temp.expect_true('seul st_api peut lire sensitive.user_identities',
  has_table_privilege('st_api', 'sensitive.user_identities', 'SELECT')
  AND NOT has_table_privilege('st_etl', 'sensitive.user_identities', 'SELECT')
  AND NOT has_table_privilege('st_bi_reader', 'sensitive.user_identities', 'SELECT')
  AND NOT has_table_privilege('st_agent_readonly', 'sensitive.user_identities', 'SELECT'));
SELECT pg_temp.expect_true('agent IA : aucune écriture possible sur les faits',
  NOT has_table_privilege('st_agent_readonly', 'core.accidents', 'INSERT')
  AND NOT has_table_privilege('st_agent_readonly', 'core.corrective_actions', 'UPDATE'));

ROLLBACK;
\echo 'Tous les tests SQL sont passés.'
