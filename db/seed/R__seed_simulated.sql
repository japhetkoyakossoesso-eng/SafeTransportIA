-- Jeu de test SIMULÉ : comptes de démo, source fictive et faits fictifs

SET search_path = core, public;

-- Comptes de démonstration (aucune vraie donnée personnelle).
INSERT INTO users (username, organization_id, is_service_account) VALUES
  ('admin.demo',   4, false),
  ('analyste.demo', 4, false),
  ('declarant.demo', 4, false),
  ('resp.securite.demo', 4, false),
  ('svc.etl', 4, true);

INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id FROM users u JOIN roles r ON
  (u.username, r.code) IN (('admin.demo','admin'), ('analyste.demo','analyst'), ('declarant.demo','reporter'),
                           ('resp.securite.demo','safety_manager'), ('svc.etl','admin'));

INSERT INTO sensitive.user_identities (user_id, email, full_name)
SELECT id, username || '@example.org', initcap(replace(username, '.', ' ')) FROM users WHERE NOT is_service_account;

-- Sources : les réelles viennent de la migration V4, on les marque validées pour la démo
UPDATE data_sources SET validation_status = 'validated', validated_by = 1, validated_at = now()
WHERE code IN ('onisr_baac', 'ntsb_avall');

-- Source simulée avec un identifiant fixe (900) pour ne pas dépendre de l'ordre des sources réelles
INSERT INTO data_sources (id, code, name, kind, provider_org_id, country_code, license, data_format, default_confidence, is_simulated)
OVERRIDING SYSTEM VALUE
VALUES (900, 'sim_demo', 'Jeu de données simulé pour tests et démonstration', 'simulation', 4, 'FR', 'CC0', 'sql', 'unknown', true);

-- Faits simulés
INSERT INTO locations (geom, precision, country_code, admin1, admin2, municipality, insee_code) VALUES
  (ST_SetSRID(ST_MakePoint(1.4442, 43.6047), 4326)::geography, 'exact', 'FR', 'Occitanie', 'Haute-Garonne', 'Toulouse', '31555'),
  (ST_SetSRID(ST_MakePoint(1.3677, 43.6293), 4326)::geography, 'exact', 'FR', 'Occitanie', 'Haute-Garonne', 'Blagnac', '31069'),
  (NULL, 'municipality', 'FR', 'Occitanie', 'Tarn', 'Albi', '81004');

UPDATE locations SET site_name = 'Aéroport Toulouse-Blagnac', site_code = 'LFBO' WHERE id = 2;

INSERT INTO weather_conditions (observed_at, location_id, condition_code, condition_source_label, light_condition, data_source_id)
VALUES ('2025-03-14 18:30+01', 1, 'rain', 'Pluie légère', 'dusk', 900);

SET LOCAL app.user_id = '5';
SET LOCAL app.actor_type = 'service';

INSERT INTO accidents (transport_mode_id, occurred_at, occurred_date, location_id, weather_condition_id, category,
                       severity, severity_source_label, fatalities, serious_injuries, minor_injuries, summary,
                       data_source_id, source_ref, confidence, created_by)
VALUES
  (1, '2025-03-14 18:35+01', '2025-03-14', 1, 1, 'collision_2_vehicules', 'serious', 'Blessé hospitalisé', 0, 1, 2,
   'SIMULÉ — collision en intersection par temps de pluie.', 900, 'SIM-ROAD-0001', 'medium', 5),
  (1, NULL, '2025-06-02', 3, NULL, 'pieton', 'fatal', 'Tué', 1, 0, 0,
   'SIMULÉ — piéton heurté hors agglomération.', 900, 'SIM-ROAD-0002', 'low', 5);

INSERT INTO incidents (transport_mode_id, incident_class, occurred_at, occurred_date, location_id, category, summary,
                       data_source_id, source_ref, confidence, created_by)
VALUES (2, 'serious_incident', '2025-09-10 07:12+02', '2025-09-10', 2, 'runway_incursion',
        'SIMULÉ — incursion sur piste, remise de gaz.', 900, 'SIM-AIR-0001', 'medium', 5);

INSERT INTO accident_factors (accident_id, category, description, assertion_level, stated_by, data_source_id)
VALUES (1, 'environmental', 'Chaussée mouillée', 'established', 'source_data', 900),
       (1, 'human', 'Refus de priorité possible — à confirmer', 'hypothesis', 'internal_analysis', NULL);

INSERT INTO reports (reporter_id, transport_mode_id, occurred_date, location_id, description, proposed_kind, is_simulated)
VALUES (3, 1, '2025-10-01', 1, 'SIMULÉ — quasi-collision vélo / bus au carrefour.', 'incident', true);

INSERT INTO exposure_measures (transport_mode_id, country_code, period_start, period_end, metric, value, unit_note, data_source_id)
VALUES (1, 'FR', '2025-01-01', '2025-12-31', 'vehicle_km', 6.0e11, 'véhicules-km, valeur fictive', 900);

INSERT INTO corrective_actions (title, description, kind, origin, transport_mode_id, accident_id, status, proposed_by)
VALUES ('Revoir la signalisation du carrefour', 'SIMULÉ — ajout d''un feu tricolore et marquage.', 'recommendation',
        'internal_analysis', 1, 1, 'proposed', 2);
