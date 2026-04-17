from __future__ import annotations

import logging

from fastapi import FastAPI

from backend.app.api.v1.app_state import router as app_state_router
from backend.app.api.v1.auth import router as auth_router
from backend.app.api.v1.files import router as files_router
from backend.app.api.v1.upload import router as ai_router
from backend.app.core.config import settings
from backend.app.db.session import init_db


logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s [%(name)s] %(message)s",
)

app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    debug=settings.debug,
    description="Cuoti DouDui MVP backend for OCR and AI analysis powered by vivo LLM.",
)

init_db()

app.include_router(ai_router)
app.include_router(auth_router)
app.include_router(app_state_router)
app.include_router(files_router)


@app.get("/")
def root() -> dict[str, str]:
    return {
        "message": "Cuoti DouDui backend is running.",
        "docs": "/docs",
    }
