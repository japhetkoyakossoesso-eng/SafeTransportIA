import os
from pathlib import Path

import psycopg

# Parties de la réglementation américaine (FAR) que l'enquête FAA « General Aviation and Part 135 » couvre (hors lignes régulières 121 et 129)
AVIATION_GENERALE = ("far_091", "far_091k", "far_133", "far_135", "far_137")

# Chaque périmètre rapproche un numérateur (accidents) de son dénominateur d'exposition
PERIMETRES = {
    "route_metropole": {
        "titre": "Route, France métropolitaine",
        "mode": "road",
        "pays": "FR",
        "filtre": "left(coalesce(l.admin2, ''), 2) NOT IN ('97', '98')",
        "metrique": "vehicle_km",
        "par": 1e9,
        "unite": "par milliard de véhicules-km",
    },
    "aviation_generale_us": {
        "titre": "Aviation générale, États-Unis",
        "mode": "air",
        "pays": "US",
        "filtre": "f.category IN ('" + "', '".join(AVIATION_GENERALE) + "')",
        "metrique": "flight_hours",
        "par": 1e5,
        "unite": "pour 100 000 heures de vol",
    },
}

BASE = """
    FROM bi.fact_occurrences f
    JOIN bi.dim_mode m ON m.mode_key = f.mode_key
    JOIN bi.dim_date d ON d.date_key = f.date_key
    LEFT JOIN bi.dim_location l ON l.location_key = f.location_key
    WHERE f.occurrence_type = 'accident' AND f.validation_status = 'validated' AND NOT f.is_simulated
      AND d.year = %(annee)s
"""


def lire_env(chemin):
    valeurs = {}
    if chemin.exists():
        for ligne in chemin.read_text().splitlines():
            if "=" in ligne and not ligne.lstrip().startswith("#"):
                cle, valeur = ligne.split("=", 1)
                valeurs[cle.strip()] = valeur.strip()
    return valeurs


# Compte en lecture seule sur le schéma bi, comme Power BI
def connexion():
    env = {**lire_env(Path(__file__).resolve().parents[2] / ".env"), **os.environ}
    return psycopg.connect(
        host=env.get("DB_HOST", "localhost") if env.get("DB_HOST") != "db" else "localhost",
        port=env.get("DB_PORT", "5432"),
        dbname=env.get("POSTGRES_DB", "safetransport"),
        user=env.get("BI_DB_USER", "app_bi"),
        password=env.get("BI_DB_PASSWORD", "change-me-bi"),
    )


def lignes(conn, sql, params):
    with conn.cursor() as cur:
        cur.execute(sql, params)
        noms = [c.name for c in cur.description]
        return [dict(zip(noms, ligne, strict=True)) for ligne in cur.fetchall()]


def par_mode(conn, annee):
    return lignes(conn, """
        SELECT m.code AS mode, count(*) AS accidents,
               count(*) FILTER (WHERE f.severity_key = 'fatal') AS mortels,
               sum(f.fatalities) AS tues, sum(f.serious_injuries) AS graves,
               count(*) FILTER (WHERE f.severity_key = 'unknown') AS gravite_inconnue,
               count(*) FILTER (WHERE l.precision IS NULL OR l.precision = 'unknown') AS lieu_inconnu
    """ + BASE + " GROUP BY 1 ORDER BY 2 DESC", {"annee": annee})


def par_mois(conn, annee):
    return lignes(conn, "SELECT m.code AS mode, d.month AS mois, count(*) AS accidents, sum(f.fatalities) AS tues"
                  + BASE + " GROUP BY 1, 2 ORDER BY 1, 2", {"annee": annee})


def par_jour(conn, annee):
    return lignes(conn, "SELECT m.code AS mode, d.day_of_week AS jour, count(*) AS accidents"
                  + BASE + " GROUP BY 1, 2 ORDER BY 1, 2", {"annee": annee})


def sources(conn, annee):
    return lignes(conn, """
        SELECT s.name AS source, s.license AS licence, count(*) AS accidents
        FROM bi.fact_occurrences f
        JOIN bi.dim_date d ON d.date_key = f.date_key
        JOIN bi.dim_source s ON s.source_key = f.source_key
        WHERE f.occurrence_type = 'accident' AND f.validation_status = 'validated' AND NOT f.is_simulated
          AND d.year = %(annee)s
        GROUP BY 1, 2 ORDER BY 3 DESC
    """, {"annee": annee})


def numerateur(conn, annee, cle):
    p = PERIMETRES[cle]
    return lignes(conn, """
        SELECT count(*) AS accidents, count(*) FILTER (WHERE f.severity_key = 'fatal') AS mortels,
               coalesce(sum(f.fatalities), 0) AS tues
    """ + BASE + f" AND m.code = %(mode)s AND l.country_code = %(pays)s AND {p['filtre']}",
                  {"annee": annee, "mode": p["mode"], "pays": p["pays"]})[0]


def exposition(conn, annee, cle):
    p = PERIMETRES[cle]
    trouve = lignes(conn, """
        SELECT e.value, e.unit_note, s.name AS source, s.license AS licence
        FROM bi.fact_exposure e
        JOIN bi.dim_mode m ON m.mode_key = e.mode_key
        JOIN bi.dim_source s ON s.source_key = e.source_key
        WHERE m.code = %(mode)s AND e.country_code = %(pays)s AND e.admin1 = '' AND e.metric = %(metrique)s
          AND e.period_start = make_date(%(annee)s, 1, 1) AND e.period_end = make_date(%(annee)s, 12, 31)
          AND NOT e.is_simulated
    """, {"annee": annee, "mode": p["mode"], "pays": p["pays"], "metrique": p["metrique"]})
    return trouve[0] if trouve else None


def annees_exposees(conn, cle):
    p = PERIMETRES[cle]
    return [r["year"] for r in lignes(conn, """
        SELECT e.year FROM bi.fact_exposure e JOIN bi.dim_mode m ON m.mode_key = e.mode_key
        WHERE m.code = %(mode)s AND e.country_code = %(pays)s AND e.admin1 = '' AND e.metric = %(metrique)s
          AND NOT e.is_simulated
        ORDER BY 1
    """, {"mode": p["mode"], "pays": p["pays"], "metrique": p["metrique"]})]


# Ce qui reste hors des périmètres de taux : outre-mer, événements hors États-Unis, vols commerciaux
def hors_perimetre(conn, annee):
    return lignes(conn, """
        SELECT count(*) FILTER (WHERE m.code = 'road' AND left(l.admin2, 2) IN ('97', '98')) AS route_outre_mer,
               coalesce(sum(f.fatalities) FILTER (WHERE m.code = 'road' AND left(l.admin2, 2) IN ('97', '98')), 0)
                   AS tues_outre_mer,
               count(*) FILTER (WHERE m.code = 'air' AND coalesce(l.country_code, 'ZZ') <> 'US') AS air_hors_us,
               count(*) FILTER (WHERE m.code = 'air' AND l.country_code = 'US'
                                AND coalesce(f.category, '') <> ALL(%(ga)s)) AS air_us_hors_ag
    """ + BASE, {"annee": annee, "ga": list(AVIATION_GENERALE)})[0]
