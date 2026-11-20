import shutil
import subprocess
import urllib.request
import zipfile
from pathlib import Path

URL_AVALL = "https://data.ntsb.gov/avdata/FileDirectory/DownloadFile?fileID=C%3A%5Cavdata%5Cavall.zip"
TABLES = ("events", "aircraft")


def telecharger(dossier):
    dossier = Path(dossier)
    dossier.mkdir(parents=True, exist_ok=True)
    chemin = dossier / "avall.zip"
    requete = urllib.request.Request(URL_AVALL, headers={"User-Agent": "safetransport-etl"})
    with urllib.request.urlopen(requete, timeout=300) as reponse, open(chemin, "wb") as f:
        shutil.copyfileobj(reponse, f)
    return chemin


def extraire(archive, dossier=None):
    """Sort avall.mdb de l'archive puis exporte les tables utiles en CSV avec mdb-export (mdbtools)."""
    archive = Path(archive)
    dossier = Path(dossier) if dossier else archive.parent
    if shutil.which("mdb-export") is None:
        raise RuntimeError("mdb-export introuvable : installer mdbtools (sur Mac : brew install mdbtools)")

    mdb = archive
    if archive.suffix.lower() == ".zip":
        with zipfile.ZipFile(archive) as z:
            nom = next(n for n in z.namelist() if n.lower().endswith(".mdb"))
            z.extract(nom, dossier)
            mdb = dossier / nom

    fichiers = []
    for table in TABLES:
        sortie = dossier / f"{table}.csv"
        with open(sortie, "w", encoding="utf-8") as f:
            commande = ["mdb-export", "-D", "%Y-%m-%d", "-T", "%Y-%m-%d %H:%M:%S", str(mdb), table]
            subprocess.run(commande, stdout=f, check=True)
        fichiers.append(sortie)
    return fichiers
