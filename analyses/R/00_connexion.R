# Connexion à la base SafeTransport AI (lecture seule, schéma bi).
# Les identifiants sont lus dans les variables d'environnement (fichier .env à la racine).
library(DBI)

if (file.exists(".env")) readRenviron(".env")

con <- dbConnect(
  RPostgres::Postgres(),
  host     = Sys.getenv("DB_HOST", "localhost"),
  port     = as.integer(Sys.getenv("DB_PORT", "5432")),
  dbname   = Sys.getenv("POSTGRES_DB", "safetransport"),
  user     = Sys.getenv("BI_DB_USER", "app_bi"),
  password = Sys.getenv("BI_DB_PASSWORD")
)

taux <- dbGetQuery(con, "SELECT * FROM bi.annual_rates")
print(taux)
