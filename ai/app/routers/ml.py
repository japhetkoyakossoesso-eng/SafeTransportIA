from fastapi import APIRouter

router = APIRouter(prefix="/ml", tags=["ml"])

# Une prédiction reste une aide à l'analyse, jamais une décision automatique
DISCLAIMER = (
    "Estimation probabiliste d'aide à l'analyse. Ne doit pas servir de système "
    "autonome de pilotage ou de sécurité critique."
)


@router.get("/models")
def list_models():
    return {"models": [], "disclaimer": DISCLAIMER, "status": "not_implemented"}
