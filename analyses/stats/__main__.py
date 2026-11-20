import argparse

from stats.rapport import produire


def main(argv=None):
    parser = argparse.ArgumentParser(prog="python -m stats", description="Rapport statistique d'une année")
    parser.add_argument("annee", type=int)
    parser.add_argument("--sortie", default=None, help="par défaut output/<annee>")
    args = parser.parse_args(argv)
    chemin = produire(args.annee, args.sortie or f"output/{args.annee}")
    print(f"Rapport écrit dans {chemin}")


if __name__ == "__main__":
    main()
