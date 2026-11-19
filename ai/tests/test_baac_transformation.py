from datetime import date
from pathlib import Path

from etl.baac.lecture import lire_annee
from etl.baac.transformation import lire_coordonnee, lire_heure, transformer

FIXTURES = Path(__file__).parent / "fixtures" / "baac_2023"
_, ACCIDENTS, _ = lire_annee(FIXTURES)


def test_coordonnees():
    assert lire_coordonnee("48,862") == 48.862
    assert lire_coordonnee("4886200") == 48.862
    assert lire_coordonnee("") is None


def test_heure():
    assert lire_heure("06:00") == (6, 0)
    assert lire_heure("1745") == (17, 45)
    assert lire_heure("5") == (0, 5)


def test_accident_grave_a_paris():
    ligne = transformer("202300000001", ACCIDENTS["202300000001"])
    assert ligne["qualite"] == "valid"
    assert ligne["severity"] == "serious"
    assert ligne["serious_injuries"] == 1
    assert ligne["occurred_date"] == date(2023, 5, 7)
    assert ligne["occurred_at"].utcoffset().total_seconds() == 2 * 3600
    assert ligne["category"] == "deux_vehicules_par_cote"
    assert ligne["precision"] == "approximate"


def test_accident_mortel():
    ligne = transformer("202300000002", ACCIDENTS["202300000002"])
    assert ligne["severity"] == "fatal"
    assert ligne["fatalities"] == 1 and ligne["minor_injuries"] == 1


def test_reunion_sans_coordonnees():
    ligne = transformer("202300000003", ACCIDENTS["202300000003"])
    assert ligne["qualite"] == "valid"
    assert ligne["lat"] is None and ligne["precision"] == "municipality"
    assert ligne["occurred_at"].utcoffset().total_seconds() == 4 * 3600


def test_sans_usager_rejete():
    ligne = transformer("202300000004", ACCIDENTS["202300000004"])
    assert ligne["qualite"] == "rejected"
    assert ligne["problemes"][0]["regle"] == "sans_usager"


def test_avertissements():
    ligne = transformer("202300000005", ACCIDENTS["202300000005"])
    assert ligne["qualite"] == "warning"
    assert {p["regle"] for p in ligne["problemes"]} == {"sans_victime", "coordonnees_invalides"}
    assert ligne["severity"] == "unknown"


def test_date_invalide():
    groupe = {"caracteristiques": {"jour": "31", "mois": "2", "an": "2023"}, "usagers": []}
    assert transformer("x", groupe)["problemes"][0]["regle"] == "date_invalide"


def test_empreinte_stable():
    a = transformer("202300000006", ACCIDENTS["202300000006"])
    b = transformer("202300000006", ACCIDENTS["202300000006"])
    assert a["sha"] == b["sha"]
