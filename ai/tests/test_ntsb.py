from datetime import date
from pathlib import Path

import pytest

from etl.ntsb.chargement import dans_la_periode
from etl.ntsb.lecture import FichierInvalide, lire_dossier
from etl.ntsb.transformation import lire_date, lire_dms, lire_heure, transformer

FIXTURES = Path(__file__).parent / "fixtures" / "ntsb"
_, EVENEMENTS, DOUBLONS = lire_dossier(FIXTURES)


def test_lecture():
    assert len(EVENEMENTS) == 7
    assert DOUBLONS == ["20230601000006"]
    assert EVENEMENTS["20230101000001"]["aircraft"][0]["far_part"] == "091"


def test_dossier_sans_export(tmp_path):
    with pytest.raises(FichierInvalide, match="extraire"):
        lire_dossier(tmp_path)


def test_dates_et_heures():
    assert lire_date("2023-05-07") == date(2023, 5, 7)
    assert lire_date("2023-05-07 00:00:00") == date(2023, 5, 7)
    assert lire_date("05/07/23 00:00:00") == date(2023, 5, 7)
    assert lire_date("12/17/82 00:00:00") == date(1982, 12, 17)
    assert lire_heure("815") == (8, 15)
    assert lire_heure("0") == (0, 0)


def test_dms():
    assert lire_dms("324500N", 2) == pytest.approx(32.75)
    assert lire_dms("0965000W", 3) == pytest.approx(-96.8333, abs=1e-3)
    assert lire_dms("abc", 2) is None


def test_accident_mortel():
    ligne = transformer("20230101000001", EVENEMENTS["20230101000001"])
    assert ligne["genre"] == "accident" and ligne["qualite"] == "valid"
    assert ligne["severity"] == "fatal" and ligne["fatalities"] == 2
    assert ligne["occurred_at"].utcoffset().total_seconds() == -5 * 3600
    assert ligne["lat"] == pytest.approx(28.5333)
    assert ligne["category"] == "far_091"
    assert ligne["aeroport_code"] == "MCO" and ligne["pays"] == "US"


def test_incident():
    ligne = transformer("20230201000002", EVENEMENTS["20230201000002"])
    assert ligne["genre"] == "incident"
    assert ligne["occurred_at"].hour == 8


def test_coordonnees_dms_si_pas_de_decimal():
    ligne = transformer("20230301000003", EVENEMENTS["20230301000003"])
    assert ligne["lat"] == pytest.approx(32.75) and ligne["severity"] == "serious"


def test_fuseau_inconnu_et_tues_absents():
    ligne = transformer("20230401000004", EVENEMENTS["20230401000004"])
    assert ligne["qualite"] == "warning"
    assert ligne["occurred_at"] is None
    assert ligne["severity"] == "fatal" and ligne["fatalities"] is None


def test_type_inconnu_rejete():
    assert transformer("20230501000005", EVENEMENTS["20230501000005"])["qualite"] == "rejected"


def test_pays_hors_usa():
    ligne = transformer("20230601000006", EVENEMENTS["20230601000006"])
    assert ligne["pays"] == "ZZ"
    assert [p["regle"] for p in ligne["problemes"]] == ["pays_inconnu"]


def test_des_tues_forcent_la_gravite():
    groupe = {"event": dict(EVENEMENTS["20230301000003"]["event"], inj_tot_f="1"), "aircraft": []}
    ligne = transformer("x", groupe)
    assert ligne["severity"] == "fatal"
    assert "gravite_incoherente" in [p["regle"] for p in ligne["problemes"]]


def test_periode():
    groupe = EVENEMENTS["20220701000007"]
    assert not dans_la_periode(groupe, date(2023, 1, 1), None)
    assert dans_la_periode(groupe, None, None)
