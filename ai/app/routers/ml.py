"""Modèles prédictifs (scores de risque).

Rappel du cahier des charges : la prédiction est probabiliste, toujours accompagnée
d'un intervalle et d'une version de modèle (core.risk_predictions). Elle ne doit pas
servir de système autonome de pilotage ou de sécurité critique.
"""

from fastapi import APIRouter

router = APIRouter(prefix="/ml", tags=["ml"])

DISCLAIMER = (
    "Estimation probabiliste d'aide à l'analyse. Ne doit pas servir de système "
    "autonome de pilotage ou de sécurité critique."
)


@router.get("/models")
def list_models() -> dict:
    return {"models": [], "disclaimer": DISCLAIMER, "status": "not_implemented"}
