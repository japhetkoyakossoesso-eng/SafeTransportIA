import os
import shutil
from pathlib import Path

import psycopg
import pytest

from app.config import settings
from etl.baac.chargement import importer

FIXTURES = Path(__file__).parent / "fixtures" / "baac_2023"

pytestmark = pytest.mark.skipif(os.environ.get("ETL_TEST_DB") != "1", reason="ETL_TEST_DB=1 pour lancer")


def compter(sql):
    with psycopg.connect(settings.database_url) as conn:
        return conn.execute(sql).fetchone()[0]


def test_import_puis_reimport(tmp_path):
    rapport = importer(FIXTURES, settings.database_url)
    assert rapport["statut"] == "partial"
    assert rapport["lus"] == 7
    assert rapport["inseres"] == 5 and rapport["rejetes"] == 1 and rapport["doublons"] == 1
    assert rapport["lus"] == rapport["inseres"] + rapport["rejetes"] + rapport["doublons"]

    nb = ("SELECT count(*) FROM core.accidents a JOIN core.data_sources s ON s.id = a.data_source_id "
          "WHERE s.code = 'onisr_baac'")
    assert compter(nb) == 5
    assert compter("SELECT count(*) FROM core.locations l JOIN core.accidents a ON a.location_id = l.id "
                   "WHERE a.source_ref = '202300000001' AND l.geom IS NOT NULL") == 1

    assert importer(FIXTURES, settings.database_url)["statut"] == "deja_importe"

    # Même année, fichier un peu modifié : rien n'est inséré deux fois
    copie = tmp_path / "2023"
    shutil.copytree(FIXTURES, copie)
    with open(copie / "lieux-2023.csv", "a") as f:
        f.write('"202300000006";"4";"";"";"";"2";"2";"0";"1";"";"";"1";"";"";"1";"0";"1";"50"\n')
    rapport = importer(copie, settings.database_url)
    assert rapport["inseres"] == 0
    assert compter(nb) == 5
