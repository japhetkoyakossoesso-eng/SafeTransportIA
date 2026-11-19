# Phase 02 : catalogue des sources

Chaque source utilisée par SafeTransport AI a une fiche ici et une ligne dans `core.data_sources`
(migration `V4__referentiels_et_sources.sql`). L'API les expose sur `GET /api/v1/sources`.

| Code | Source | Mode | Rôle | Licence | Format | Statut |
|---|---|---|---|---|---|---|
| `onisr_baac` | [ONISR, bases BAAC](onisr-baac.md) | routier, France | accidents corporels | Licence Ouverte (Etalab) | csv | fiche complète |
| `ntsb_avall` | [NTSB, base aviation](ntsb.md) | aérien, États-Unis | accidents et incidents | données publiques US (à confirmer) | Access (.mdb) | fiche complète |
| `sdes_circulation` | [SDES, bilan de la circulation](exposition.md#routier) | routier, France | exposition (véhicules-km) | Licence Ouverte (Etalab) | xlsx | lien à compléter |
| `faa_ga_survey` | [FAA, GA and Part 135 Activity Survey](exposition.md#aerien) | aérien, États-Unis | exposition (heures de vol) | données publiques US (à confirmer) | pdf, xlsx | lien à compléter |

Le jeu de test `sim_demo` (identifiant 900) n'est chargé qu'en développement et en CI.

## Ce que contient une fiche

1. Producteur, URL, licence, mise à jour
2. Couverture : années, territoire, ce qui est compté et ce qui ne l'est pas
3. Définitions utilisées par la source
4. Format et dictionnaire des variables utiles
5. Correspondance avec notre modèle (gravité harmonisée, mode, lieu)
6. Biais et ruptures de série connus
7. Niveau de confiance par défaut et pourquoi

## Règles

- Une source n'est utilisée dans les statistiques qu'une fois validée par un administrateur
  (`validation_status = 'validated'`).
- On garde toujours le libellé d'origine à côté de la valeur harmonisée.
- Une rupture de série connue est écrite dans `known_biases` et rappelée sous les graphiques
  concernés.
- Les fichiers bruts ne sont pas mis dans git (`data/raw/` est ignoré) : on garde leur empreinte
  SHA-256 dans `import_jobs`.
