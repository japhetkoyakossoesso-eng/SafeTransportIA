# Analyses statistiques

* `stats/` : rapport statistique en Python (taux, intervalles de confiance, saisonnalité, biais).
  Méthode et résultats : [docs/10-stats](../docs/10-stats/README.md).
* `sql/` : requêtes d'indicateurs exécutables directement sur la base (psql, DBeaver, R).
* `R/` : connexion depuis R pour les graphiques du mémoire.

Règle de comparabilité (cahier des charges) : on ne compare des modes ou des pays qu'à partir
de définitions harmonisées et rapportées à un dénominateur d'exposition (`bi.fact_exposure` :
véhicules-km, heures de vol). Par défaut on exclut les données simulées et non validées.

Les deux outils utilisent le compte en lecture `app_bi` (schéma `bi` uniquement) défini dans `.env`.

## Python

```bash
cd ai && source .venv/bin/activate && python -m etl.exposition && deactivate && cd ..
cd analyses
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python -m stats 2023          # écrit output/2023/rapport.md
pytest -q
```

## R

```r
install.packages(c("DBI", "RPostgres", "dplyr", "ggplot2", "sf"))
source("analyses/R/00_connexion.R")
```
