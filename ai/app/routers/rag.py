from fastapi import APIRouter
from pydantic import BaseModel, Field

router = APIRouter(prefix="/rag", tags=["rag"])


class Question(BaseModel):
    question: str = Field(min_length=3, max_length=2000)


# Tant que le RAG n'est pas fait, on refuse de répondre plutôt que d'inventer
@router.post("/ask")
def ask(q: Question):
    return {
        "question": q.question,
        "answer": None,
        "citations": [],
        "abstained": True,
        "reason": "RAG pas encore implémenté",
    }
