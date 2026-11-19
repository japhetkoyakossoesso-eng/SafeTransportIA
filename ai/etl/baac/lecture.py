import csv
from pathlib import Path

FICHIERS = ("caracteristiques", "lieux", "vehicules", "usagers")

# Colonnes sans lesquelles on ne peut rien faire
COLONNES_REQUISES = {
    "caracteristiques": {"Num_Acc", "jour", "mois", "an", "hrmn", "dep", "com", "lat", "long"},
    "lieux": {"Num_Acc"},
    "vehicules": {"Num_Acc"},
    "usagers": {"Num_Acc", "grav"},
}

# En 2022 la clé du fichier caractéristiques s'appelle Accident_Id
RENOMMAGES = {"Accident_Id": "Num_Acc", "num_acc": "Num_Acc"}


class FichierInvalide(Exception):
    pass


def trouver_fichiers(dossier):
    """Associe chaque type de fichier BAAC à un CSV du dossier, d'après son nom."""
    dossier = Path(dossier)
    csvs = sorted(p for p in dossier.glob("*.csv") if "immatricul" not in p.name.lower())
    motifs = {"caracteristiques": ("car",), "lieux": ("lieu",), "vehicules": ("vehic",), "usagers": ("usag",)}
    trouves = {}
    for nom, debuts in motifs.items():
        candidats = [p for p in csvs if p.name.lower().startswith(debuts)]
        if len(candidats) != 1:
            raise FichierInvalide(f"{len(candidats)} fichier(s) « {nom} » dans {dossier}, il en faut un")
        trouves[nom] = candidats[0]
    return trouves


def lire_texte(chemin):
    brut = Path(chemin).read_bytes()
    try:
        return brut.decode("utf-8-sig")
    except UnicodeDecodeError:
        return brut.decode("latin-1")


def lire_csv(chemin, type_fichier):
    texte = lire_texte(chemin)
    premiere_ligne = texte.split("\n", 1)[0]
    separateur = max([";", ",", "\t"], key=premiere_ligne.count)
    lignes = list(csv.DictReader(texte.splitlines(), delimiter=separateur))
    lignes = [
        {RENOMMAGES.get(k.strip(), k.strip()): (v or "").strip() for k, v in ligne.items() if k}
        for ligne in lignes
    ]

    colonnes = set(lignes[0]) if lignes else set()
    manquantes = COLONNES_REQUISES[type_fichier] - colonnes
    if manquantes:
        raise FichierInvalide(f"{Path(chemin).name} : colonnes manquantes {sorted(manquantes)}")
    return lignes


def lire_annee(dossier):
    """Lit les 4 fichiers et regroupe tout par accident (Num_Acc)."""
    chemins = trouver_fichiers(dossier)
    donnees = {nom: lire_csv(chemin, nom) for nom, chemin in chemins.items()}

    accidents = {}
    doublons = []
    for ligne in donnees["caracteristiques"]:
        num = ligne["Num_Acc"]
        if num in accidents:
            doublons.append(num)
            continue
        accidents[num] = {"caracteristiques": ligne, "lieux": [], "vehicules": [], "usagers": []}

    for nom in ("lieux", "vehicules", "usagers"):
        for ligne in donnees[nom]:
            if ligne["Num_Acc"] in accidents:
                accidents[ligne["Num_Acc"]][nom].append(ligne)

    return chemins, accidents, doublons
