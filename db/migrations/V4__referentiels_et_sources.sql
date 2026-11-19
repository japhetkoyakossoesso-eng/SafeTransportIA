-- Référentiels et sources réelles, communs à tous les environnements.
-- Les fiches détaillées sont dans docs/02-sources.

SET search_path = core, public;

INSERT INTO transport_modes (code, label_fr, label_en, definition) VALUES
  ('road', 'Routier', 'Road',
   'Accident corporel : sur une voie ouverte à la circulation publique, au moins un véhicule et au moins une victime (définition ONISR). Tué = décès dans les 30 jours.'),
  ('air', 'Aérien', 'Air',
   'Accident : décès ou blessure grave, ou dommage important à l''aéronef (OACI annexe 13, 49 CFR 830.2 aux États-Unis). Les incidents graves sont des incidents.'),
  ('rail', 'Ferroviaire', 'Rail',
   'Accident significatif au sens de la directive (UE) 2016/798. À confirmer au jalon 3.'),
  ('maritime', 'Maritime', 'Maritime',
   'Accident ou sinistre maritime au sens du code OMI. À confirmer au jalon 3.');

INSERT INTO roles (code, label_fr, description) VALUES
  ('analyst', 'Analyste', 'Consulte, filtre et analyse les données validées.'),
  ('reporter', 'Agent déclarant', 'Saisit des signalements (non vérifiés par défaut).'),
  ('safety_manager', 'Responsable sécurité', 'Valide signalements et mesures préventives.'),
  ('admin', 'Administrateur', 'Gère sources, imports, rôles et audit.'),
  ('researcher', 'Chercheur', 'Accès lecture aux données agrégées et au corpus documentaire.');

-- L'ordre compte : les tests et le jeu simulé utilisent ces identifiants.
INSERT INTO organizations (name, acronym, kind, country_code, website) VALUES
  ('Observatoire national interministériel de la sécurité routière', 'ONISR', 'data_provider', 'FR', 'https://www.onisr.securite-routiere.gouv.fr'),
  ('National Transportation Safety Board', 'NTSB', 'investigation_body', 'US', 'https://www.ntsb.gov'),
  ('Bureau d''enquêtes et d''analyses pour la sécurité de l''aviation civile', 'BEA', 'investigation_body', 'FR', 'https://www.bea.aero'),
  ('SafeTransport AI', 'STAI', 'internal', 'FR', NULL),
  ('Service des données et études statistiques', 'SDES', 'data_provider', 'FR', 'https://www.statistiques.developpement-durable.gouv.fr'),
  ('Federal Aviation Administration', 'FAA', 'regulator', 'US', 'https://www.faa.gov');

-- Les sources restent « under_review » : un administrateur les valide depuis le back-office.
INSERT INTO data_sources (code, name, kind, provider_org_id, transport_mode_id, country_code, url, license,
                          data_format, data_dictionary_url, known_biases, default_confidence) VALUES
  ('onisr_baac', 'Bases annuelles des accidents corporels de la circulation routière (BAAC)', 'open_data', 1, 1, 'FR',
   'https://www.data.gouv.fr/fr/datasets/53698f4ca3a729239d2036df/',
   'Licence Ouverte / Open Licence (Etalab)', 'csv',
   'https://www.onisr.securite-routiere.gouv.fr/sites/default/files/2024-10/Description%20des%20bases%20de%20donn%C3%A9es%20annuelles.pdf',
   'Accidents corporels seulement (pas de dégâts matériels seuls). Base brute non corrigée des erreurs de saisie. '
   'Blessé hospitalisé non comparable avant/après 2018 et plus labellisé depuis 2019. Variables modifiées en 2019. '
   'Usagers en fuite ajoutés à partir de 2021 avec des champs manquants. Géolocalisation parfois limitée à la commune. '
   'Collectivités d''outre-mer hors DROM seulement depuis 2019.',
   'high'),
  ('ntsb_avall', 'NTSB aviation accident and incident database', 'open_data', 2, 2, 'US',
   'https://data.ntsb.gov/avdata/', 'Données publiques du gouvernement américain (à confirmer)', 'mdb',
   'https://www.ntsb.gov/pages/AviationDownloadDataDictionary.aspx',
   'Recensement de l''aviation civile américaine ; peu d''événements étrangers. Rapports « Preliminary » susceptibles de changer. '
   'Pas de gravité de blessure pour les incidents. Coordonnées parfois estimées depuis la ville ou l''aéroport le plus proche. '
   'Le téléchargement passe sur l''API NTSB le 5 avril 2027.',
   'high'),
  ('sdes_circulation', 'Bilan de la circulation (véhicules-kilomètres)', 'open_data', 5, 1, 'FR',
   'https://www.statistiques.developpement-durable.gouv.fr', 'Licence Ouverte / Open Licence (Etalab)', 'xlsx',
   NULL,
   'Dénominateur d''exposition routier. Estimations nationales annuelles, révisées d''une édition à l''autre. Lien précis à compléter.',
   'medium'),
  ('faa_ga_survey', 'General Aviation and Part 135 Activity Survey (heures de vol)', 'open_data', 6, 2, 'US',
   'https://www.faa.gov', 'Données publiques du gouvernement américain (à confirmer)', 'pdf/xlsx',
   NULL,
   'Dénominateur d''exposition pour l''aviation générale américaine. Enquête par sondage, estimations avec marge d''erreur. '
   'Ne couvre pas le transport commercial de la partie 121. Lien précis à compléter.',
   'medium');
