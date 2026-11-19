"""RAG sur les rapports d'enquête (BEA, NTSB…).

Stub. Pipeline prévu : core.documents → core.document_chunks (tsvector + vector(1024))
→ recherche hybride → réponse du LLM avec citations (core.rag_queries / rag_query_chunks),
ou abstention justifiée si les sources ne suffisent pas.
"""

from fastapi import APIRouter
from pydantic import BaseModel, Field

router = APIRouter(prefix="/rag", tags=["rag"])


class Question(BaseModel):
    question: str = Field(min_length=3, max_length=2000)


@router.post("/ask")
def ask(q: Question) -> dict:
    return {
        "question": q.question,
        "answer": None,
        "citations": [],
        "abstained": True,
        "reason": "RAG non implémenté (stub).",
    }
