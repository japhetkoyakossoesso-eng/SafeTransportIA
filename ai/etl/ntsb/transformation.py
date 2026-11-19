import hashlib
import json
import re
from datetime import date, datetime, timedelta, timezone

GRAVITE = {"FATL": "fatal", "SERS": "serious", "MINR": "minor", "NONE": "none"}

# Fuseaux NTSB (heure locale de l'événement) en heures par rapport à UTC
FUSEAUX = {
    "UTC": 0, "GMT": 0, "Z": 0,
    "AST": -4, "ADT": -3, "EST": -5, "EDT": -4, "CST": -6, "CDT": -5, "MST": -7, "MDT": -6,
    "PST": -8, "PDT": -7, "AKST": -9, "AKDT": -8, "YST": -9, "YDT": -8, "HST": -10, "HDT": -9,
    "SST": -11, "CHST": 10, "ChST": 10,
}

PAYS = {"USA": "US", "US": "US"}


def empreinte(objet):
    texte = json.dumps(objet, sort_keys=True, ensure_ascii=False)
    return hashlib.sha256(texte.encode("utf-8")).hexdigest()


def probleme(regle, champ, message):
    return {"regle": regle, "champ": champ, "message": message}


def rejet(regle, champ, message):
    return {"qualite": "rejected", "problemes": [probleme(regle, champ, message)]}


def lire_date(texte):
    """mdb-export écrit 2023-05-07 (avec -D) ou 05/07/23 00:00:00 (par défaut)."""
    texte = texte.split(" ")[0]
    if "-" in texte:
        return date.fromisoformat(texte)
    mois, jour, annee = (int(x) for x in texte.split("/"))
    if annee < 100:
        annee += 1900 if annee >= 60 else 2000
    return date(annee, mois, jour)


def lire_heure(texte):
    texte = texte.split(".")[0].zfill(4)
    heures, minutes = int(texte[:-2]), int(texte[-2:])
    if heures > 23 or minutes > 59:
        raise ValueError(texte)
    return heures, minutes


def lire_entier(texte):
    if texte in ("", None):
        return None
    return int(float(texte))


def lire_dms(texte, chiffres_degres):
    """Format NTSB DDMMSSN / DDDMMSSW."""
    m = re.fullmatch(r"(\d+)([NSEW])", texte.strip().upper())
    if not m:
        return None
    nombre = m.group(1).zfill(chiffres_degres + 4)
    degres = int(nombre[:chiffres_degres])
    minutes = int(nombre[chiffres_degres:chiffres_degres + 2])
    secondes = int(nombre[chiffres_degres + 2:chiffres_degres + 4])
    valeur = degres + minutes / 60 + secondes / 3600
    return -valeur if m.group(2) in "SW" else valeur


def lire_coordonnees(e):
    try:
        lat, lon = e.get("dec_latitude", ""), e.get("dec_longitude", "")
        if lat and lon:
            return float(lat), float(lon)
        if e["latitude"] and e["longitude"]:
            return lire_dms(e["latitude"], 2), lire_dms(e["longitude"], 3)
    except ValueError:
        pass
    return None, None


def transformer(ev_id, groupe):
    e = groupe["event"]
    base = {"ev_id": ev_id, "payload": groupe, "sha": empreinte(groupe)}
    problemes = []

    genre = {"ACC": "accident", "INC": "incident"}.get(e["ev_type"].upper())
    if genre is None:
        return base | rejet("type_inconnu", "ev_type", f"type « {e['ev_type']} » ni ACC ni INC")

    try:
        jour = lire_date(e["ev_date"])
    except ValueError:
        return base | rejet("date_invalide", "ev_date", "date illisible")

    occurred_at = None
    fuseau = FUSEAUX.get(e["ev_tmzn"].strip()) if e["ev_tmzn"] else None
    try:
        if e["ev_time"]:
            heures, minutes = lire_heure(e["ev_time"])
            if fuseau is None:
                problemes.append(probleme("fuseau_inconnu", "ev_tmzn", f"fuseau « {e['ev_tmzn']} » inconnu"))
            else:
                tz = timezone(timedelta(hours=fuseau))
                occurred_at = datetime(jour.year, jour.month, jour.day, heures, minutes, tzinfo=tz)
    except ValueError:
        problemes.append(probleme("heure_invalide", "ev_time", "heure illisible, gardée vide"))

    tues = lire_entier(e["inj_tot_f"])
    graves = lire_entier(e["inj_tot_s"])
    legers = lire_entier(e["inj_tot_m"])
    severity = GRAVITE.get(e["ev_highest_injury"].upper(), "unknown")
    if tues and severity != "fatal":
        problemes.append(probleme("gravite_incoherente", "ev_highest_injury", "tués, gravité non mortelle"))
        severity = "fatal"
    if severity == "fatal" and not tues:
        tues = None

    lat, lon = lire_coordonnees(e)
    if lat is None or lon is None or not (-90 <= lat <= 90 and -180 <= lon <= 180):
        if e["latitude"] or e["longitude"] or e.get("dec_latitude"):
            problemes.append(probleme("coordonnees_invalides", "latitude/longitude", "coordonnées ignorées"))
        lat = lon = None

    code = e["ev_country"].upper()
    pays = PAYS.get(code) or (code if len(code) == 2 else None)
    if pays is None:
        problemes.append(probleme("pays_inconnu", "ev_country", f"code pays « {code} » non converti"))
        pays = "ZZ"

    far = next((a.get("far_part") for a in groupe["aircraft"] if a.get("far_part")), None)

    return base | {
        "genre": genre,
        "qualite": "warning" if problemes else "valid",
        "problemes": problemes,
        "occurred_date": jour,
        "occurred_at": occurred_at,
        "severity": severity,
        "severity_label": e["ev_highest_injury"] or None,
        "fatalities": tues,
        "serious_injuries": graves,
        "minor_injuries": legers,
        "category": f"far_{far.lower()}" if far else None,
        "lat": lat,
        "lon": lon,
        "precision": "approximate" if lat is not None else "municipality",
        "pays": pays,
        "etat": e["ev_state"] or None,
        "ville": e["ev_city"] or None,
        "aeroport_code": e.get("ev_nr_apt_id") or None,
        "aeroport_nom": e.get("apt_name") or None,
    }
