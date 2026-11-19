# NTSB : base des accidents et incidents d'aviation

## Identité

| | |
|---|---|
| Code | `ntsb_avall` |
| Producteur | National Transportation Safety Board (États-Unis) |
| Où | [data.ntsb.gov/avdata](https://data.ntsb.gov/avdata/) (téléchargement), [CAROL](https://www.ntsb.gov/Pages/Aviationquery.aspx) (recherche en ligne) |
| Documentation | [dictionnaire des données](https://www.ntsb.gov/pages/AviationDownloadDataDictionary.aspx), `eadmspub.pdf` et `codman.pdf` dans le dossier de téléchargement |
| Licence | données publiques du gouvernement américain ; aucune licence n'est affichée sur les pages lues, à confirmer auprès de data@ntsb.gov |
| Années | `avall.zip` : 1982 à aujourd'hui ; `PRE1982.zip` : 1962 à 1981 |
| Mise à jour | fichiers `upJJMMM.zip` publiés les 1, 8, 15 et 22 de chaque mois |
| Confiance par défaut | `high` : enquêtes officielles, mais voir les rapports préliminaires |

**Attention** : le NTSB annonce que le 5 avril 2027 le téléchargement passe sur son API
(`GetCasesByDateRangeV2`, voir developer.ntsb.gov). C'est en plein jalon 3 : l'ETL doit lire un
fichier local, pour qu'on puisse changer seulement la partie téléchargement.

## Ce qui est compté

- **Accident** (49 CFR 830.2) : événement lié à l'exploitation d'un aéronef où une personne est
  tuée ou gravement blessée, ou où l'aéronef subit des dommages importants.
- **Incident** : événement autre qu'un accident qui affecte ou pourrait affecter la sécurité.
  Le NTSB n'enquête que sur certains incidents.

Couverture : recensement de l'aviation civile américaine. Seuls quelques accidents à l'étranger sont
inclus, donc pas de comparaison avec la France à partir de cette base seule.

## Correspondance avec notre modèle

| NTSB | Nous |
|---|---|
| type accident | `core.accidents` |
| type incident | `core.incidents` (classe `incident` ou `serious_incident`) |
| plus haute blessure : mortelle, grave, mineure, aucune | `severity` : `fatal`, `serious`, `minor`, `none` |
| identifiant d'événement (14 caractères) | `source_ref` |
| numéro NTSB | gardé dans la ligne brute |
| latitude, longitude (degrés décimaux) | `locations.geom`, précision `approximate` si estimée |
| aéroport | `locations.site_code`, `site_name` |

Les noms exacts des tables et colonnes du fichier Access (`events`, `aircraft`, `injury`,
`ev_id`, `ev_highest_injury`…) sont à vérifier dans `eadmspub.pdf` au moment d'écrire l'ETL.
Le dictionnaire en ligne décrit l'export de CAROL, dont les colonnes portent d'autres noms
(`EventId`, `InjurySeverity`, `Latitude`…).

## Biais et limites connus

- Rapports « Preliminary » : susceptibles de changer. On les importe avec `validation_status =
  'under_review'` et on les met à jour aux imports suivants.
- Pas de gravité de blessure pour les incidents.
- Coordonnées présentes depuis 2002 pour les événements américains, parfois estimées depuis la
  ville ou l'aéroport le plus proche.
- Synopsis absents avant 1993 et pour les enquêtes que le NTSB ne dirige pas.
- L'existence d'un fichier `Pre2008.zip` laisse penser à un changement de codage en 2008 (non
  confirmé par la documentation lue).
- Aviation générale et transport commercial sont mélangés : il faut filtrer sur le type
  d'exploitation avant de calculer un taux.

## Exposition

Heures de vol de l'enquête FAA pour l'aviation générale (voir [exposition.md](exposition.md)).
