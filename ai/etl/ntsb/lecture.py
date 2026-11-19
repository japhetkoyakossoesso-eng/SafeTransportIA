import csv
from pathlib import Path

# Noms des tables de avall.mdb exportées en CSV par mdb-export
COLONNES_REQUISES = {
    "events": {"ev_id", "ev_type", "ev_date", "ev_time", "ev_tmzn", "ev_city", "ev_state", "ev_country",
               "latitude", "longitude", "ev_highest_injury", "inj_tot_f", "inj_tot_s", "inj_tot_m"},
    "aircraft": {"ev_id"},
}


class FichierInvalide(Exception):
    pass


def lire_csv(chemin, table):
    chemin = Path(chemin)
    if not chemin.exists():
        raise FichierInvalide(f"{chemin} introuvable (lancer d'abord : python -m etl.ntsb extraire)")
    with open(chemin, encoding="utf-8", errors="replace", newline="") as f:
        lignes = [
            {k.strip(): (v or "").strip() for k, v in ligne.items() if k}
            for ligne in csv.DictReader(f)
        ]
    colonnes = set(lignes[0]) if lignes else set()
    manquantes = COLONNES_REQUISES[table] - colonnes
    if manquantes:
        raise FichierInvalide(f"{chemin.name} : colonnes manquantes {sorted(manquantes)}")
    return lignes


def lire_dossier(dossier):
    """Lit events.csv et aircraft.csv et regroupe les aéronefs sous leur événement."""
    dossier = Path(dossier)
    chemins = {"events": dossier / "events.csv", "aircraft": dossier / "aircraft.csv"}
    evenements = {}
    doublons = []
    for ligne in lire_csv(chemins["events"], "events"):
        if ligne["ev_id"] in evenements:
            doublons.append(ligne["ev_id"])
            continue
        evenements[ligne["ev_id"]] = {"event": ligne, "aircraft": []}
    for ligne in lire_csv(chemins["aircraft"], "aircraft"):
        if ligne["ev_id"] in evenements:
            evenements[ligne["ev_id"]]["aircraft"].append(ligne)
    return chemins, evenements, doublons
