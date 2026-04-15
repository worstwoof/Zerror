from __future__ import annotations

from datetime import datetime

from sqlalchemy import DateTime, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from backend.app.db.session import Base


class AppStateSnapshot(Base):
    __tablename__ = "app_state_snapshots"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    sync_user_id: Mapped[str] = mapped_column(String(128), unique=True, index=True)
    snapshot_json: Mapped[str] = mapped_column(Text, default="{}", nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )
