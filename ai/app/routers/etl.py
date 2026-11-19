from fastapi import APIRouter

router = APIRouter(prefix="/etl", tags=["etl"])


@router.get("/sources")
def list_sources():
    return {"sources": ["onisr_baac", "ntsb_avall"], "status": "not_implemented"}
