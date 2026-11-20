import argparse
import csv
from decimal import Decimal
from pathlib import Path

import psycopg

from app.config import settings

COLONNES = ["mode", "pays", "debut", "fin", "metrique", "valeur", "unite", "source", "origine"]


class FichierInvalide(Exception):
    pass


# Le fichier de référence dit d'où vient chaque chiffre (fichier officiel, feuille, cellule)
def lire(chemin):
    with open(chemin, newline="", encoding="utf-8") as f:
        lecteur = csv.DictReader(f)
        manque = set(COLONNES) - set(lecteur.fieldnames or [])
        if manque:
            raise FichierInvalide(f"colonnes manquantes : {', '.join(sorted(manque))}")
        lignes = []
        for n, ligne in enumerate(lecteur, start=2):
            try:
                valeur = Decimal(ligne["valeur"])
            except ArithmeticError as e:
                raise FichierInvalide(f"ligne {n} : valeur « {ligne['valeur']} » illisible") from e
            if valeur <= 0:
                raise FichierInvalide(f"ligne {n} : la valeur doit être positive")
            if not ligne["origine"].strip():
                raise FichierInvalide(f"ligne {n} : l'origine du chiffre est obligatoire")
            lignes.append({**ligne, "valeur": valeur})
        return lignes


REQUETE = """
INSERT INTO core.exposure_measures (transport_mode_id, country_code, period_start, period_end,
                                    metric, value, unit_note, data_source_id, confidence)
SELECT m.id, %(pays)s, %(debut)s, %(fin)s, CAST(%(metrique)s AS core.exposure_metric),
       %(valeur)s, %(unite)s || ' (' || %(origine)s || ')', s.id, 'medium'
FROM core.transport_modes m, core.data_sources s
WHERE m.code = %(mode)s AND s.code = %(source)s
ON CONFLICT (transport_mode_id, country_code, admin1, period_start, period_end, metric, data_source_id)
DO UPDATE SET value = EXCLUDED.value, unit_note = EXCLUDED.unit_note
"""


def importer(chemin, database_url):
    lignes = lire(chemin)
    with psycopg.connect(database_url) as conn:
        conn.execute("SELECT set_config('app.actor_type', 'service', false)")
        for ligne in lignes:
            conn.execute(REQUETE, ligne)
    return len(lignes)


def main(argv=None):
    parser = argparse.ArgumentParser(
        prog="python -m etl.exposition",
        description="Charge les dénominateurs d'exposition (trafic, heures de vol)",
    )
    parser.add_argument("fichier", nargs="?", default=str(Path("../data/reference/exposition.csv")))
    args = parser.parse_args(argv)
    try:
        n = importer(args.fichier, settings.database_url)
    except FichierInvalide as erreur:
        print(f"Erreur : {erreur}")
        return 2
    print(f"{n} mesure(s) d'exposition chargée(s) depuis {args.fichier}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
