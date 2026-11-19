-- Données de référence + jeu de test SIMULÉ

SET search_path = core, public;

-- Référentiels
INSERT INTO transport_modes (code, label_fr, label_en, definition) VALUES
  ('road',     'Routier',       'Road',     'Accident corporel : au moins un véhicule, voie ouverte à la circulation, au moins une victime (définition ONISR).'),
  ('air',      'Aérien',        'Air',      'Accident au sens de l''Annexe 13 OACI ; les incidents graves sont enregistrés comme incidents.'),
  ('rail',     'Ferroviaire',   'Rail',     'Accident significatif au sens de la directive (UE) 2016/798 — à confirmer phase avancée.'),
  ('maritime', 'Maritime',      'Maritime', 'Accident/sinistre maritime au sens du code OMI — à confirmer phase avancée.');

INSERT INTO roles (code, label_fr, description) VALUES
  ('analyst',        'Analyste',               'Consulte, filtre et analyse les données validées.'),
  ('reporter',       'Agent déclarant',        'Saisit des signalements (non vérifiés par défaut).'),
  ('safety_manager', 'Responsable sécurité',   'Valide signalements et mesures préventives.'),
  ('admin',          'Administrateur',         'Gère sources, imports, rôles et audit.'),
  ('researcher',     'Chercheur',              'Accès lecture aux données agrégées et au corpus documentaire.');

INSERT INTO organizations (name, acronym, kind, country_code, website) VALUES
  ('Observatoire national interministériel de la sécurité routière', 'ONISR', 'data_provider', 'FR', 'https://www.onisr.securite-routiere.gouv.fr'),
  ('National Transportation Safety Board', 'NTSB', 'investigation_body', 'US', 'https://www.ntsb.gov'),
  ('Bureau d''enquêtes et d''analyses pour la sécurité de l''aviation civile', 'BEA', 'investigation_body', 'FR', 'https://www.bea.aero'),
  ('SafeTransport AI (démo)', 'STAI', 'internal', 'FR', NULL);

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

-- Sources
INSERT INTO data_sources (code, name, kind, provider_org_id, transport_mode_id, country_code, url, license, data_format,
                          known_biases, default_confidence, validation_status, validated_by, validated_at) VALUES
  ('onisr_baac', 'Bases annuelles des accidents corporels (BAAC)', 'open_data', 1, 1, 'FR',
   'https://www.data.gouv.fr/fr/datasets/bases-de-donnees-annuelles-des-accidents-corporels-de-la-circulation-routiere-annees-de-2005-a-2023/',
   'Licence Ouverte 2.0', 'csv', 'Accidents corporels uniquement ; ruptures de série possibles entre millésimes (à vérifier dans les notices annuelles).', 'high', 'validated', 1, now()),
  ('ntsb_avall', 'NTSB aviation accident database', 'open_data', 2, 2, 'US',
   'https://www.ntsb.gov/Pages/AviationQueryV2.aspx', 'Public domain (US Gov)', 'mdb/csv',
   'Couverture centrée sur les États-Unis.', 'high', 'validated', 1, now());

INSERT INTO data_sources (code, name, kind, provider_org_id, country_code, license, data_format, default_confidence, is_simulated)
VALUES ('sim_demo', 'Jeu de données simulé pour tests et démonstration', 'simulation', 4, 'FR', 'CC0', 'sql', 'unknown', true);

-- Faits simulés
INSERT INTO locations (geom, precision, country_code, admin1, admin2, municipality, insee_code) VALUES
  (ST_SetSRID(ST_MakePoint(1.4442, 43.6047), 4326)::geography, 'exact', 'FR', 'Occitanie', 'Haute-Garonne', 'Toulouse', '31555'),
  (ST_SetSRID(ST_MakePoint(1.3677, 43.6293), 4326)::geography, 'exact', 'FR', 'Occitanie', 'Haute-Garonne', 'Blagnac', '31069'),
  (NULL, 'municipality', 'FR', 'Occitanie', 'Tarn', 'Albi', '81004');

UPDATE locations SET site_name = 'Aéroport Toulouse-Blagnac', site_code = 'LFBO' WHERE id = 2;

INSERT INTO weather_conditions (observed_at, location_id, condition_code, condition_source_label, light_condition, data_source_id)
VALUES ('2025-03-14 18:30+01', 1, 'rain', 'Pluie légère', 'dusk', 3);

SET LOCAL app.user_id = '5';
SET LOCAL app.actor_type = 'service';

INSERT INTO accidents (transport_mode_id, occurred_at, occurred_date, location_id, weather_condition_id, category,
                       severity, severity_source_label, fatalities, serious_injuries, minor_injuries, summary,
                       data_source_id, source_ref, confidence, created_by)
VALUES
  (1, '2025-03-14 18:35+01', '2025-03-14', 1, 1, 'collision_2_vehicules', 'serious', 'Blessé hospitalisé', 0, 1, 2,
   'SIMULÉ — collision en intersection par temps de pluie.', 3, 'SIM-ROAD-0001', 'medium', 5),
  (1, NULL, '2025-06-02', 3, NULL, 'pieton', 'fatal', 'Tué', 1, 0, 0,
   'SIMULÉ — piéton heurté hors agglomération.', 3, 'SIM-ROAD-0002', 'low', 5);

INSERT INTO incidents (transport_mode_id, incident_class, occurred_at, occurred_date, location_id, category, summary,
                       data_source_id, source_ref, confidence, created_by)
VALUES (2, 'serious_incident', '2025-09-10 07:12+02', '2025-09-10', 2, 'runway_incursion',
        'SIMULÉ — incursion sur piste, remise de gaz.', 3, 'SIM-AIR-0001', 'medium', 5);

INSERT INTO accident_factors (accident_id, category, description, assertion_level, stated_by, data_source_id)
VALUES (1, 'environmental', 'Chaussée mouillée', 'established', 'source_data', 3),
       (1, 'human', 'Refus de priorité possible — à confirmer', 'hypothesis', 'internal_analysis', NULL);

INSERT INTO reports (reporter_id, transport_mode_id, occurred_date, location_id, description, proposed_kind, is_simulated)
VALUES (3, 1, '2025-10-01', 1, 'SIMULÉ — quasi-collision vélo / bus au carrefour.', 'incident', true);

INSERT INTO exposure_measures (transport_mode_id, country_code, period_start, period_end, metric, value, unit_note, data_source_id)
VALUES (1, 'FR', '2025-01-01', '2025-12-31', 'vehicle_km', 6.0e11, 'véhicules-km, valeur fictive', 3);

INSERT INTO corrective_actions (title, description, kind, origin, transport_mode_id, accident_id, status, proposed_by)
VALUES ('Revoir la signalisation du carrefour', 'SIMULÉ — ajout d''un feu tricolore et marquage.', 'recommendation',
        'internal_analysis', 1, 1, 'proposed', 2);
