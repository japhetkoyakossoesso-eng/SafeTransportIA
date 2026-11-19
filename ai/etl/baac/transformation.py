import hashlib
import json
from datetime import date, datetime
from zoneinfo import ZoneInfo

GRAVITE = {
    "2": ("fatal", "Tué"),
    "3": ("serious", "Blessé hospitalisé"),
    "4": ("minor", "Blessé léger"),
    "1": ("none", "Indemne"),
}
ORDRE = ["fatal", "serious", "minor", "none"]

COLLISION = {
    "1": "deux_vehicules_frontale",
    "2": "deux_vehicules_par_arriere",
    "3": "deux_vehicules_par_cote",
    "4": "trois_vehicules_en_chaine",
    "5": "trois_vehicules_collisions_multiples",
    "6": "autre_collision",
    "7": "sans_collision",
}

# Fuseau horaire selon le département (l'heure BAAC est l'heure locale)
FUSEAUX = {
    "971": "America/Guadeloupe", "972": "America/Martinique", "973": "America/Cayenne",
    "974": "Indian/Reunion", "975": "America/Miquelon", "976": "Indian/Mayotte",
    "977": "America/St_Barthelemy", "978": "America/Marigot", "986": "Pacific/Wallis",
    "987": "Pacific/Tahiti", "988": "Pacific/Noumea",
}


def empreinte(objet):
    texte = json.dumps(objet, sort_keys=True, ensure_ascii=False)
    return hashlib.sha256(texte.encode("utf-8")).hexdigest()


def lire_date(c):
    annee = int(c["an"])
    if annee < 100:  # avant 2019 l'année est sur 2 chiffres
        annee += 2000
    return date(annee, int(c["mois"]), int(c["jour"]))


def lire_heure(hrmn):
    hrmn = hrmn.replace(":", "").zfill(4)
    heures, minutes = int(hrmn[:2]), int(hrmn[2:])
    if heures > 23 or minutes > 59:
        raise ValueError(hrmn)
    return heures, minutes


def lire_coordonnee(texte):
    texte = texte.replace(",", ".").strip()
    if texte in ("", "-", "."):
        return None
    valeur = float(texte)
    if abs(valeur) > 1000:  # anciens millésimes : degrés x 100 000
        valeur /= 100000
    return valeur


def probleme(regle, champ, message):
    return {"regle": regle, "champ": champ, "message": message}


def rejet(regle, champ, message):
    return {"qualite": "rejected", "problemes": [probleme(regle, champ, message)]}


def transformer(num_acc, groupe):
    """Transforme un accident BAAC en ligne prête à charger, avec ses problèmes de qualité."""
    c = groupe["caracteristiques"]
    base = {"num_acc": num_acc, "payload": groupe, "sha": empreinte(groupe)}
    problemes = []

    try:
        jour = lire_date(c)
    except (ValueError, KeyError):
        return base | rejet("date_invalide", "jour/mois/an", "date illisible")

    occurred_at = None
    try:
        heures, minutes = lire_heure(c["hrmn"])
        fuseau = ZoneInfo(FUSEAUX.get(c["dep"][:3], "Europe/Paris"))
        occurred_at = datetime(jour.year, jour.month, jour.day, heures, minutes, tzinfo=fuseau)
    except (ValueError, KeyError):
        problemes.append(probleme("heure_invalide", "hrmn", "heure illisible, gardée vide"))

    victimes = {"fatal": 0, "serious": 0, "minor": 0, "none": 0}
    for usager in groupe["usagers"]:
        if usager["grav"] in GRAVITE:
            victimes[GRAVITE[usager["grav"]][0]] += 1

    if not groupe["usagers"]:
        return base | rejet("sans_usager", "usagers", "aucun usager")

    severity = next((g for g in ORDRE if victimes[g] > 0), "unknown")
    if severity in ("none", "unknown"):
        problemes.append(probleme("sans_victime", "grav", "aucune victime connue (usagers en fuite ?)"))
    libelle = next((lib for code, (g, lib) in GRAVITE.items() if g == severity), None)

    lat = lon = None
    try:
        lat, lon = lire_coordonnee(c["lat"]), lire_coordonnee(c["long"])
    except ValueError:
        pass
    if lat is None or lon is None or not (-90 <= lat <= 90 and -180 <= lon <= 180) or (lat == 0 and lon == 0):
        if c["lat"] or c["long"]:
            problemes.append(probleme("coordonnees_invalides", "lat/long", "coordonnées ignorées"))
        lat = lon = None

    return base | {
        "qualite": "warning" if problemes else "valid",
        "problemes": problemes,
        "occurred_date": jour,
        "occurred_at": occurred_at,
        "severity": severity,
        "severity_label": libelle,
        "fatalities": victimes["fatal"],
        "serious_injuries": victimes["serious"],
        "minor_injuries": victimes["minor"],
        "category": COLLISION.get(c.get("col", "")),
        "lat": lat,
        "lon": lon,
        "precision": "approximate" if lat is not None else "municipality",
        "dep": c["dep"],
        "com": c["com"],
    }
