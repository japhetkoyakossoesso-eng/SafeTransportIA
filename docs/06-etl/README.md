# Phase 06 : import d'une année BAAC

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
