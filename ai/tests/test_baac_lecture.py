from pathlib import Path

import pytest

from etl.baac.lecture import FichierInvalide, lire_annee, lire_csv, trouver_fichiers

FIXTURES = Path(__file__).parent / "fixtures" / "baac_2023"


def test_trouve_les_quatre_fichiers():
    assert set(trouver_fichiers(FIXTURES)) == {"caracteristiques", "lieux", "vehicules", "usagers"}


def test_dossier_incomplet(tmp_path):
    (tmp_path / "caract-2023.csv").write_text("Num_Acc\n")
    with pytest.raises(FichierInvalide):
        trouver_fichiers(tmp_path)


def test_accident_id_renomme_en_num_acc():
    lignes = lire_csv(FIXTURES / "caract-2023.csv", "caracteristiques")
    assert lignes[0]["Num_Acc"] == "202300000001"
    assert lignes[0]["lat"] == "48,86200000"


def test_colonne_manquante(tmp_path):
    fichier = tmp_path / "usagers.csv"
    fichier.write_text("Num_Acc;place\n1;1\n")
    with pytest.raises(FichierInvalide, match="grav"):
        lire_csv(fichier, "usagers")


def test_latin1_et_virgule(tmp_path):
    fichier = tmp_path / "lieux.csv"
    fichier.write_bytes("Num_Acc,voie\n1,Allée des Pins\n".encode("latin-1"))
    assert lire_csv(fichier, "lieux")[0]["voie"] == "Allée des Pins"


def test_regroupement_par_accident():
    _, accidents, doublons = lire_annee(FIXTURES)
    assert len(accidents) == 6
    assert doublons == ["202300000005"]
    assert len(accidents["202300000001"]["usagers"]) == 2
    assert accidents["202300000004"]["usagers"] == []
