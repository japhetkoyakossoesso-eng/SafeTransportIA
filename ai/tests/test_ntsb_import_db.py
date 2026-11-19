import os
from datetime import date
from pathlib import Path

import psycopg
import pytest

from app.config import settings
from etl.ntsb.chargement import importer

FIXTURES = Path(__file__).parent / "fixtures" / "ntsb"

pytestmark = pytest.mark.skipif(os.environ.get("ETL_TEST_DB") != "1", reason="ETL_TEST_DB=1 pour lancer")


def compter(sql):
    with psycopg.connect(settings.database_url) as conn:
        return conn.execute(sql).fetchone()[0]


def test_import_ntsb():
    rapport = importer(FIXTURES, settings.database_url, depuis=date(2023, 1, 1), jusqua=date(2023, 12, 31))
    assert rapport["statut"] == "partial"
    assert rapport["lus"] == 7
    comptes = (rapport["accidents"], rapport["incidents"], rapport["rejetes"], rapport["doublons"])
    assert comptes == (4, 1, 1, 1)
    assert rapport["lus"] == sum(comptes)

    source = "JOIN core.data_sources s ON s.id = e.data_source_id AND s.code = 'ntsb_avall'"
    assert compter(f"SELECT count(*) FROM core.accidents e {source}") == 4
    assert compter(f"SELECT count(*) FROM core.incidents e {source}") == 1
    assert compter("SELECT site_code FROM core.locations l JOIN core.accidents a ON a.location_id = l.id "
                   "WHERE a.source_ref = '20230101000001'") == "MCO"

    assert importer(FIXTURES, settings.database_url, depuis=date(2023, 1, 1),
                    jusqua=date(2023, 12, 31))["statut"] == "deja_importe"

    # Toute la période : seul l'accident de 2022 est nouveau
    rapport = importer(FIXTURES, settings.database_url)
    assert rapport["accidents"] == 1 and rapport["incidents"] == 0
    assert compter(f"SELECT count(*) FROM core.accidents e {source}") == 5
