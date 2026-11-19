import pytest

from etl.baac.telechargement import choisir_ressources


def ressource(titre, fichier, fmt="csv"):
    return {"title": titre, "url": f"https://static.data.gouv.fr/resources/x/{fichier}", "format": fmt}


RESSOURCES = [
    ressource("Caractéristiques des accidents de l'année 2023", "caract-2023.csv"),
    ressource("Lieux des accidents de l'année 2023", "lieux-2023.csv"),
    ressource("Véhicules impliqués 2023", "vehicules-2023.csv"),
    ressource("Usagers 2023", "usagers-2023.csv"),
    ressource("Véhicules immatriculés 2023", "vehicules-immatricules-baac-2023.csv"),
    ressource("Caractéristiques 2022", "carcteristiques-2022.csv"),
    ressource("Description des bases", "description.pdf", "pdf"),
]


def test_choisit_les_bonnes_ressources():
    choix = choisir_ressources(RESSOURCES, 2023)
    assert choix["vehicules"]["url"].endswith("vehicules-2023.csv")
    assert choix["caracteristiques"]["url"].endswith("caract-2023.csv")


def test_annee_absente():
    with pytest.raises(ValueError, match="2019"):
        choisir_ressources(RESSOURCES, 2019)
