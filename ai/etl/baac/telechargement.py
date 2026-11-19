import json
import urllib.request
from pathlib import Path

JEU_DE_DONNEES = "https://www.data.gouv.fr/api/1/datasets/53698f4ca3a729239d2036df/"
MOTIFS = {"caracteristiques": ("car",), "lieux": ("lieu",), "vehicules": ("vehic",), "usagers": ("usag",)}


def choisir_ressources(ressources, annee):
    """Repère les 4 CSV d'une année parmi les ressources data.gouv.fr (les noms varient selon les années)."""
    choix = {}
    for nom, debuts in MOTIFS.items():
        candidats = []
        for r in ressources:
            fichier = r["url"].rsplit("/", 1)[-1].lower()
            titre = r.get("title", "").lower()
            texte = f"{titre} {fichier}"
            if str(annee) not in texte or "immatricul" in texte or (r.get("format") or "").lower() != "csv":
                continue
            if titre.startswith(debuts) or fichier.startswith(debuts):
                candidats.append(r)
        if len(candidats) != 1:
            titres = [r.get("title") for r in candidats]
            raise ValueError(f"{nom} {annee} : {len(candidats)} ressource(s) {titres}, à prendre à la main")
        choix[nom] = candidats[0]
    return choix


def telecharger(annee, dossier):
    with urllib.request.urlopen(JEU_DE_DONNEES, timeout=60) as reponse:
        ressources = json.load(reponse)["resources"]
    dossier = Path(dossier)
    dossier.mkdir(parents=True, exist_ok=True)
    fichiers = []
    for nom, ressource in choisir_ressources(ressources, annee).items():
        chemin = dossier / f"{nom}-{annee}.csv"
        urllib.request.urlretrieve(ressource["url"], chemin)
        fichiers.append(chemin)
    return fichiers
