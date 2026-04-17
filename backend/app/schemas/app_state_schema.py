from __future__ import annotations

from datetime import datetime
from typing import Any, Dict

from pydantic import BaseModel, Field


class AppStateWriteRequest(BaseModel):
    snapshot: Dict[str, Any] = Field(default_factory=dict)


class AppStateResponse(BaseModel):
    sync_user_id: str
    snapshot: Dict[str, Any] = Field(default_factory=dict)
    updated_at: datetime | None = None
