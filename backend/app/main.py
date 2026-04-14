from __future__ import annotations

from fastapi import FastAPI

from backend.app.api.v1.upload import router as ai_router
from backend.app.core.config import settings


app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    debug=settings.debug,
    description="Cuoti DouDui MVP backend for OCR and AI analysis powered by vivo LLM.",
)

app.include_router(ai_router)


@app.get("/")
def root() -> dict[str, str]:
    return {
        "message": "Cuoti DouDui backend is running.",
        "docs": "/docs",
    }
