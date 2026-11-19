"""ETL : import des sources ouvertes (ONISR/BAAC, NTSB…), contrôle qualité, dédoublonnage.

Stub. Chaque import écrira dans core.import_jobs puis core.source_records (ligne brute + SHA-256)
avant de produire des faits (accidents, incidents) avec leur provenance.
"""

from fastapi import APIRouter

router = APIRouter(prefix="/etl", tags=["etl"])

SOURCES = ["onisr_baac", "ntsb_avall"]


@router.get("/sources")
def list_sources() -> dict:
    return {"sources": SOURCES, "status": "not_implemented"}
