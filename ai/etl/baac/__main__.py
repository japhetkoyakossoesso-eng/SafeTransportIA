import argparse
import sys

from app.config import settings
from etl.baac.chargement import importer, rapport_texte
from etl.baac.lecture import FichierInvalide
from etl.baac.telechargement import telecharger


def main(argv=None):
    parser = argparse.ArgumentParser(prog="python -m etl.baac", description="Import des bases BAAC")
    commandes = parser.add_subparsers(dest="commande", required=True)

    t = commandes.add_parser("telecharger", help="télécharge les 4 fichiers d'une année depuis data.gouv.fr")
    t.add_argument("annee", type=int)
    t.add_argument("--dossier", default=None, help="par défaut ../data/raw/baac/<annee>")

    i = commandes.add_parser("importer", help="importe les 4 fichiers d'un dossier dans la base")
    i.add_argument("dossier")
    i.add_argument("--valide-par", type=int, default=None,
                   help="id de l'utilisateur qui valide l'import (sinon : non vérifié)")

    args = parser.parse_args(argv)

    if args.commande == "telecharger":
        dossier = args.dossier or f"../data/raw/baac/{args.annee}"
        for chemin in telecharger(args.annee, dossier):
            print(chemin)
        return 0

    try:
        rapport = importer(args.dossier, settings.database_url, args.valide_par)
    except FichierInvalide as erreur:
        print(f"Erreur : {erreur}", file=sys.stderr)
        return 2
    print(rapport_texte(rapport))
    return 0


if __name__ == "__main__":
    sys.exit(main())
