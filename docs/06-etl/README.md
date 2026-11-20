# Phase 06 : imports BAAC et NTSB

Le code est dans `ai/etl/baac`. Il prend les 4 fichiers d'une année (caractéristiques, lieux, véhicules, usagers), les regroupe par accident (`Num_Acc`) et charge le résultat dans `core.source_records`, `core.locations` et `core.accidents`.

## Utilisation

Depuis le dossier `ai`, avec la base démarrée (`make up`) :

```bash
python -m etl.baac telecharger 2023              # range les CSV dans ../data/raw/baac/2023
python -m etl.baac importer ../data/raw/baac/2023
python -m etl.baac importer ../data/raw/baac/2023 --valide-par 1   # accidents marqués validés par l'utilisateur 1
```

Si le téléchargement échoue (noms de fichiers changés sur data.gouv.fr), on peut poser les 4 CSV à la main dans le dossier : seuls les débuts de nom comptent (`car…`, `lieu…`, `vehic…`, `usag…`). Le fichier des véhicules immatriculés est ignoré.

## Ce que fait l'import

- Lecture : séparateur `;` ou `,` détecté, UTF-8 ou Latin-1, colonne `Accident_Id` (2022) renommée en `Num_Acc`.
- Chaque accident brut est gardé tel quel dans `source_records.payload`, avec son empreinte SHA-256 et sa qualité (`valid`, `warning`, `rejected`).
- Gravité de l'accident = pire gravité des usagers (tué > hospitalisé > léger). Le libellé BAAC est gardé dans `severity_source_label`.
- L'heure BAAC est locale : elle est convertie selon le département (Paris, Réunion, Guadeloupe…).
- Coordonnées : virgule décimale acceptée, anciens formats en degrés × 100 000 convertis, `0,0` ignoré.

## Règles de qualité

| Règle | Effet |
|---|---|
| `date_invalide` | accident rejeté |
| `sans_usager` | accident rejeté |
| `heure_invalide` | chargé, heure laissée vide |
| `sans_victime` | chargé avec gravité `unknown` (usagers en fuite, codes `-1`) |
| `coordonnees_invalides` | chargé sans point, précision « commune » |

## Rejouer un import

- Le même lot de fichiers n'est importé qu'une fois : la deuxième fois, le programme répond « déjà importé ».
- Si les fichiers ont changé (nouvelle version publiée par l'ONISR), seuls les accidents absents sont ajoutés ; ceux déjà en base sont comptés comme doublons.
- Le rapport vérifie toujours : lus = insérés + rejetés + doublons. Il est aussi enregistré dans `core.import_jobs`.

## Tests

- `pytest` dans `ai` : lecture, transformation et choix des fichiers sur un petit jeu inventé (`ai/tests/fixtures/baac_2023`).
- `ETL_TEST_DB=1 DB_HOST=localhost pytest tests/test_baac_import_db.py` : import réel dans la base, lancé aussi par la CI.

Le jeu de test reprend le format 2023 mais n'est pas un extrait officiel. Il faut faire un premier essai sur une vraie année avant de s'y fier.

## NTSB (aviation, États-Unis)

Le code est dans `ai/etl/ntsb`. La base du NTSB est un fichier Microsoft Access (`avall.mdb`, dans `avall.zip`, de 2008 à aujourd'hui). On en exporte deux tables en CSV avec [mdbtools](https://github.com/mdbtools/mdbtools), puis on importe.

```bash
brew install mdbtools                       # une seule fois, sur Mac
python -m etl.ntsb telecharger              # ../data/raw/ntsb/avall.zip (environ 100 Mo)
python -m etl.ntsb extraire                 # events.csv et aircraft.csv à côté
python -m etl.ntsb importer --depuis 2023-01-01 --jusqua 2023-12-31
```

Si le téléchargement échoue, prendre `avall.zip` à la main sur https://data.ntsb.gov/avdata et le poser dans `data/raw/ntsb`. À partir du 5 avril 2027, le NTSB passe à une API : seule l'étape `telecharger` sera à changer.

Ce que fait l'import :

- `ev_type` ACC va dans `core.accidents`, INC dans `core.incidents` (classe `incident`), en mode `air`.
- Gravité depuis `ev_highest_injury` (FATL, SERS, MINR, NONE), code d'origine gardé dans `severity_source_label`. Des tués avec une autre gravité : gravité forcée à `fatal` et avertissement.
- L'heure est locale (`ev_time` en HHMM, fuseau `ev_tmzn` comme EST ou PDT) et convertie en UTC.
- Coordonnées : `dec_latitude` et `dec_longitude` si présentes, sinon `latitude` et `longitude` au format DDMMSSN / DDDMMSSW.
- Lieu : ville, État, aéroport le plus proche (`ev_nr_apt_id`, `apt_name`). La catégorie est la partie de la réglementation FAA du premier aéronef (`far_091`, `far_121`…), utile pour séparer aviation générale et transport commercial.
- Le choix de la période fait partie du lot : importer 2022 puis 2023 depuis le même fichier crée deux imports, sans doublon.

| Règle | Effet |
|---|---|
| `type_inconnu` | événement rejeté (ni ACC ni INC) |
| `date_invalide` | événement rejeté |
| `fuseau_inconnu`, `heure_invalide` | chargé, heure laissée vide (le fuseau manque surtout pour les événements hors États-Unis) |
| `gravite_incoherente` | chargé, gravité corrigée en `fatal` |
| `coordonnees_invalides` | chargé sans point |
| `pays_inconnu` | chargé avec le pays `ZZ` (code NTSB à trois lettres non converti, ou code propre au NTSB comme `A1` pour une zone maritime) |

Les noms de colonnes viennent de la documentation du NTSB (`eadmspub.pdf`). Ils n'ont pas pu être vérifiés sur un vrai fichier ici : si une colonne manque, l'import s'arrête et donne la liste des colonnes absentes.
