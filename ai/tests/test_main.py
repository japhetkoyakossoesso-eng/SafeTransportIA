from fastapi.testclient import TestClient

from app import main
from app.main import app

client = TestClient(app)


def test_health_without_database(monkeypatch):
    def boom():
        raise ConnectionError("pas de base")

    monkeypatch.setattr(main, "database_version", boom)
    body = client.get("/health").json()
    assert body["status"] == "degraded"


def test_ml_carries_disclaimer():
    body = client.get("/ml/models").json()
    assert "sécurité critique" in body["disclaimer"]


def test_rag_abstains_while_not_implemented():
    body = client.post("/rag/ask", json={"question": "Quels facteurs dans les accidents de nuit ?"}).json()
    assert body["abstained"] is True
    assert body["citations"] == []
