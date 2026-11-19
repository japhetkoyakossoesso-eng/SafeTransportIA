# ONISR : bases annuelles des accidents corporels (BAAC)

## Identité

| | |
|---|---|
| Code | `onisr_baac` |
| Producteur | ONISR (Observatoire national interministériel de la sécurité routière), publié par le ministère de l'Intérieur |
| Où | [data.gouv.fr](https://www.data.gouv.fr/fr/datasets/53698f4ca3a729239d2036df/) |
| Documentation | [Description des bases de données annuelles](https://www.onisr.securite-routiere.gouv.fr/sites/default/files/2024-10/Description%20des%20bases%20de%20donn%C3%A9es%20annuelles.pdf) (ONISR, octobre 2024) |
| Licence | Licence Ouverte / Open Licence (Etalab) |
| Années | 2005 à aujourd'hui, une publication par an (fiche mise à jour le 30/10/2026) |
| Confiance par défaut | `high` : source officielle, recensement par les forces de l'ordre |

## Ce qui est compté

Un **accident corporel** :

- survient sur une voie publique ou privée ouverte à la circulation publique ;
- implique au moins un véhicule ;
- implique au moins une victime.

Les accidents avec seulement des dégâts matériels ne sont pas dans la base.

Gravité d'une victime :

| Code `grav` | Libellé | Définition | Notre `severity` |
|---|---|---|---|
| 1 | Indemne | pas blessé | `none` |
| 4 | Blessé léger | soins médicaux, pas hospitalisé plus de 24 h | `minor` |
| 3 | Blessé hospitalisé | hospitalisé plus de 24 h | `serious` |
| 2 | Tué | décès sur le coup ou dans les 30 jours | `fatal` |

La gravité d'un accident est celle de sa victime la plus grave. Le libellé d'origine va dans
`severity_source_label`.

Territoire : métropole et départements d'outre-mer (Guadeloupe, Guyane, Martinique, La Réunion,
Mayotte depuis 2012). Les autres territoires d'outre-mer ne sont en open data que depuis 2019.

## Format

Quatre fichiers CSV par année, reliés par `Num_Acc` :

| Fichier | Une ligne par | Clé |
|---|---|---|
| caractéristiques | accident | `Num_Acc` |
| lieux | accident | `Num_Acc` |
| véhicules | véhicule | `Num_Acc`, `id_vehicule` |
| usagers | personne impliquée | `Num_Acc`, `id_vehicule`, `id_usager` |

Le séparateur, l'encodage et le format des coordonnées changent selon les années : l'ETL doit les
détecter et non les supposer (à vérifier sur chaque millésime au moment de l'import).

Valeurs manquantes : cellule vide, `0`, `.` ou `-1` selon les variables.

### Variables utiles pour le MVP

**Caractéristiques**

| Variable | Sens | Vers |
|---|---|---|
| `Num_Acc` | identifiant de l'accident | `accidents.source_ref` |
| `jour`, `mois`, `an`, `hrmn` | date et heure | `occurred_at`, `occurred_date` |
| `lum` | éclairage (1 plein jour … 5 nuit avec éclairage allumé) | `weather_conditions.light_condition` |
| `atm` | météo (1 normale, 2 pluie légère, 3 pluie forte, 4 neige-grêle, 5 brouillard, 6 vent fort, 7 éblouissant, 8 couvert, 9 autre) | `weather_conditions` |
| `agg` | 1 hors agglomération, 2 en agglomération | `locations` |
| `int` | type d'intersection (1 hors intersection … 9 autre) | `locations` |
| `col` | type de collision (1 frontale … 7 sans collision) | `accidents.category` |
| `dep`, `com` | codes INSEE du département et de la commune | `locations.insee_code` |
| `lat`, `long` | coordonnées WGS84 | `locations.geom` |

**Lieux** : `catr` (1 autoroute, 2 nationale, 3 départementale, 4 communale, 5 hors réseau public,
6 parking, 7 routes de métropole urbaine, 9 autre), `surf` (état de la chaussée), `vma` (vitesse
maximale autorisée), `situ`, `infra`.

**Véhicules** : `id_vehicule`, `catv` (catégorie : 01 vélo, 07 voiture, 33 moto > 125 cm³,
37 autobus, 50 EDP à moteur, 80 VAE…), `obs`, `obsm`, `choc`, `manv`, `motor`.

**Usagers** : `id_usager`, `catu` (1 conducteur, 2 passager, 3 piéton), `grav`, `sexe`, `an_nais`,
`trajet`, `secu1` à `secu3`.

On n'importe pas d'immatriculation ni de donnée qui identifie une personne. `an_nais` et `sexe`
servent seulement à des statistiques agrégées.

## Biais et ruptures connus

- **Blessé hospitalisé, 2018** : « Les données sur la qualification de blessé hospitalisé depuis
  l'année 2018 ne peuvent être comparées aux années précédentes ». Ne pas tracer une série
  `serious` qui traverse 2018 sans le signaler.
- **Label statistique** : l'indicateur blessé hospitalisé n'est plus labellisé par l'Autorité de la
  statistique publique depuis 2019. Les tués restent l'indicateur le plus fiable.
- **2019** : nouvelles variables et nouvelles modalités (équipements de sécurité passés de 2 à 3
  variables, identifiants `id_vehicule` / `id_usager`). L'ETL a deux parseurs : avant et après 2019.
- **2021** : les usagers en fuite sont ajoutés, avec sexe, âge et parfois gravité manquants.
- **Base brute** : « non corrigée des erreurs de saisies ». Les contrôles qualité de l'ETL rejettent
  les lignes incohérentes et les comptent dans le rapport d'import.
- **Géolocalisation** : tous les accidents ne sont pas localisés précisément ; parfois seule la
  commune est connue. On le note dans `locations.precision`.
- **Sous-déclaration** : seuls les accidents connus des forces de l'ordre sont comptés. Les blessés
  légers, et surtout les cyclistes seuls, sont sous-représentés.
- **Données occultées** : certaines informations sont masquées pour la confidentialité.

## Exposition

Pour des taux, on divise par les véhicules-kilomètres du SDES (voir [exposition.md](exposition.md)).
Les deux sources n'ont pas la même couverture exacte : à préciser dans la note de méthode.

## Pour l'import (phase 06)

1. Télécharger les quatre fichiers d'une année, calculer leur SHA-256.
2. Enregistrer chaque ligne brute dans `source_records` (clé : `Num_Acc` + fichier).
3. Assembler accident, lieu, véhicules, usagers ; harmoniser la gravité.
4. `UNIQUE (data_source_id, source_ref)` garantit qu'un second import ne crée pas de doublon.
