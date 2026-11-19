from fastapi import FastAPI

from app.db import database_version
from app.routers import etl, ml, rag

app = FastAPI(title="SafeTransport AI - IA", version="0.1.0")

app.include_router(etl.router)
app.include_router(ml.router)
app.include_router(rag.router)


@app.get("/health")
def health():
    try:
        return {"service": "ai", "status": "ok", "database": database_version()}
    except Exception:  # noqa: BLE001
        return {"service": "ai", "status": "degraded", "database": "indisponible"}
