import argparse
import sys
from datetime import date

from app.config import settings
from etl.ntsb.chargement import importer, rapport_texte
from etl.ntsb.lecture import FichierInvalide
from etl.ntsb.telechargement import extraire, telecharger

DOSSIER = "../data/raw/ntsb"


def main(argv=None):
    parser = argparse.ArgumentParser(prog="python -m etl.ntsb", description="Import NTSB")
    commandes = parser.add_subparsers(dest="commande", required=True)

    t = commandes.add_parser("telecharger", help="télécharge avall.zip depuis data.ntsb.gov")
    t.add_argument("--dossier", default=DOSSIER)

    x = commandes.add_parser("extraire", help="exporte les tables events et aircraft en CSV (mdbtools)")
    x.add_argument("archive", nargs="?", default=f"{DOSSIER}/avall.zip")

    i = commandes.add_parser("importer", help="importe events.csv et aircraft.csv dans la base")
    i.add_argument("dossier", nargs="?", default=DOSSIER)
    i.add_argument("--depuis", type=date.fromisoformat, help="première date gardée, ex. 2023-01-01")
    i.add_argument("--jusqua", type=date.fromisoformat, help="dernière date gardée, ex. 2023-12-31")
    i.add_argument("--valide-par", type=int, default=None,
                   help="id de l'utilisateur qui valide l'import (sinon : non vérifié)")

    args = parser.parse_args(argv)

    if args.commande == "telecharger":
        print(telecharger(args.dossier))
        return 0
    if args.commande == "extraire":
        try:
            for chemin in extraire(args.archive):
                print(chemin)
        except RuntimeError as erreur:
            print(f"Erreur : {erreur}", file=sys.stderr)
            return 2
        return 0

    try:
        rapport = importer(args.dossier, settings.database_url, args.depuis, args.jusqua, args.valide_par)
    except FichierInvalide as erreur:
        print(f"Erreur : {erreur}", file=sys.stderr)
        return 2
    print(rapport_texte(rapport))
    return 0


if __name__ == "__main__":
    sys.exit(main())
