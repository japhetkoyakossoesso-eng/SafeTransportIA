-- Mot de passe « demo » pour les comptes de démonstration (jamais en production : db/seed n'y est pas chargé)
-- Passe après R__seed_simulated (ordre alphabétique) et peut être rejoué sans risque

UPDATE sensitive.user_identities i
SET password_hash = crypt('demo', gen_salt('bf', 10))
FROM core.users u
WHERE u.id = i.user_id AND u.username LIKE '%.demo';
