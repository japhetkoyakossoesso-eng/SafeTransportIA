# PostgreSQL 16 + pgvector (image officielle multi-architecture, OK sur Mac Apple Silicon)
# + PostGIS 3 installé depuis le dépôt apt.postgresql.org déjà configuré dans l'image.
FROM pgvector/pgvector:pg16

RUN apt-get update \
 && apt-get install -y --no-install-recommends postgresql-16-postgis-3 \
 && rm -rf /var/lib/apt/lists/*

# Exécuté une seule fois, à la création du volume de données.
COPY initdb/ /docker-entrypoint-initdb.d/
