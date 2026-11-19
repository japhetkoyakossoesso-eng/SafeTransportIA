from fastapi import FastAPI

from app.db import database_version
from app.routers import etl, ml, rag

app = FastAPI(
    title="SafeTransport AI — services IA",
    description="ETL des sources ouvertes, modèles prédictifs et RAG sur rapports d'enquête.",
    version="0.1.0",
)

app.include_router(etl.router)
app.include_router(ml.router)
app.include_router(rag.router)


@app.get("/health")
def health() -> dict:
    body = {"service": "ai", "status": "ok"}
    try:
        body["database"] = database_version()
    except Exception as exc:  # la base peut ne pas être démarrée : on le signale sans planter
        body["status"] = "degraded"
        body["database"] = f"indisponible : {type(exc).__name__}"
    return body
