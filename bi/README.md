# Power BI

Le rapport se connecte à PostgreSQL avec le compte **`app_bi`** (rôle `st_bi_reader`), qui ne voit
que le schéma `bi` (modèle en étoile créé par la migration `V2__schema_bi.sql`) :

| Table / vue | Rôle |
|---|---|
| `bi.fact_occurrences` | une ligne par accident ou incident |
| `bi.dim_date`, `bi.dim_mode`, `bi.dim_location`, `bi.dim_severity`, `bi.dim_source` | dimensions |
| `bi.annual_rates` | taux pour 10⁸ unités d'exposition |

Connexion : *Obtenir les données → Base de données PostgreSQL*, serveur `localhost:5432`, base
`safetransport`, mode **Import**. Filtre par défaut : `validation_status = 'validated'` et
`is_simulated = false`.

Les fichiers `.pbix` ne sont pas versionnés (ils embarquent des données). Versionner plutôt un
`.pbit` (modèle sans données) dans ce dossier.
