# Analyses statistiques (R + SQL)

* `sql/` : requêtes d'indicateurs exécutables directement sur la base (psql, DBeaver, R).
* `R/` : scripts d'analyse (tendances, taux par exposition, tests, graphiques pour le mémoire).

Règle de comparabilité (cahier des charges) : on ne compare des modes ou des pays qu'à partir
de définitions harmonisées et rapportées à un dénominateur d'exposition (`core.exposure_measures` :
vols, véhicules-km, trafic). Par défaut on exclut les données simulées et non validées.

Connexion depuis R : compte en lecture `app_bi` (schéma `bi` uniquement) défini dans `.env`.

```r
install.packages(c("DBI", "RPostgres", "dplyr", "ggplot2", "sf"))
source("analyses/R/00_connexion.R")
```
