# Sources d'exposition

Un nombre d'accidents ne se compare pas tout seul : il faut le diviser par une mesure d'activité.
Ces mesures vont dans `core.exposure_measures` et la vue `bi.annual_rates` calcule les taux pour
10⁸ unités. Sans mesure d'exposition, le taux est « non calculable ».

## Routier

| | |
|---|---|
| Code | `sdes_circulation` |
| Producteur | SDES, ministère de la Transition écologique |
| Mesure | véhicules-kilomètres parcourus en France, par an (`metric = 'vehicle_km'`) |
| Licence | Licence Ouverte (Etalab) |
| À faire | trouver le lien exact de la série sur le site du SDES et le noter dans `data_sources.url` |

Limites : estimations nationales révisées d'une édition à l'autre ; pas de détail fin par commune.
Pour une carte par zone il faudra une autre mesure (trafic moyen journalier, population) et le dire.

## Aérien

| | |
|---|---|
| Code | `faa_ga_survey` |
| Producteur | FAA, General Aviation and Part 135 Activity Survey |
| Mesure | heures de vol par an (`metric = 'flight_hours'`) |
| Licence | données publiques du gouvernement américain (à confirmer) |
| À faire | trouver le lien exact de l'édition annuelle et le noter dans `data_sources.url` |

Limites : enquête par sondage, donc une marge d'erreur ; ne couvre pas les compagnies aériennes
régulières (partie 121). Pour elles, il faudra une autre source (nombre de vols ou heures de vol).

## Règle

On ne compare deux taux que si leur `metric` est le même. Véhicules-kilomètres et heures de vol ne
se comparent pas.
