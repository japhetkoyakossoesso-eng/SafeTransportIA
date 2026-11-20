import pytest

from etl.exposition.__main__ import FichierInvalide, lire

ENTETE = "mode,pays,debut,fin,metrique,valeur,unite,source,origine\n"


def ecrire(tmp_path, lignes):
    chemin = tmp_path / "exposition.csv"
    chemin.write_text(ENTETE + lignes, encoding="utf-8")
    return chemin


def test_lecture(tmp_path):
    chemin = ecrire(tmp_path, "road,FR,2023-01-01,2023-12-31,vehicle_km,609000000000,véhicules-km,"
                              "sdes_circulation,fichier.xlsx feuille X cellule B12\n")
    [ligne] = lire(chemin)
    assert ligne["valeur"] == 609000000000
    assert ligne["metrique"] == "vehicle_km"


@pytest.mark.parametrize("valeur", ["abc", "0", "-5"])
def test_valeur_refusee(tmp_path, valeur):
    ligne = f"air,US,2023-01-01,2023-12-31,flight_hours,{valeur},heures,faa_ga_survey,tableau 1.3\n"
    chemin = ecrire(tmp_path, ligne)
    with pytest.raises(FichierInvalide):
        lire(chemin)


def test_origine_obligatoire(tmp_path):
    chemin = ecrire(tmp_path, "air,US,2023-01-01,2023-12-31,flight_hours,28000000,heures,faa_ga_survey, \n")
    with pytest.raises(FichierInvalide, match="origine"):
        lire(chemin)


def test_colonnes_manquantes(tmp_path):
    chemin = tmp_path / "x.csv"
    chemin.write_text("mode,pays\nroad,FR\n", encoding="utf-8")
    with pytest.raises(FichierInvalide, match="colonnes manquantes"):
        lire(chemin)
