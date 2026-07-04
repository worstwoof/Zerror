from __future__ import annotations

from collections.abc import Generator

from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from backend.app.core.config import settings


class Base(DeclarativeBase):
    pass


def _engine_kwargs() -> dict[str, object]:
    kwargs: dict[str, object] = {
        "pool_pre_ping": True,
    }
    if settings.database_url.startswith("sqlite"):
        kwargs["connect_args"] = {"check_same_thread": False}
    return kwargs


engine = create_engine(settings.database_url, **_engine_kwargs())
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False, expire_on_commit=False)


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db() -> None:
    from backend.app.db import models  # noqa: F401

    Base.metadata.create_all(bind=engine)
    _ensure_runtime_schema()


def _ensure_runtime_schema() -> None:
    inspector = inspect(engine)
    if "error_records" not in inspector.get_table_names():
        return
    existing_columns = {
        column["name"]
        for column in inspector.get_columns("error_records")
    }
    with engine.begin() as connection:
        if "rich_artifacts_json" not in existing_columns:
            connection.execute(
                text(
                    "ALTER TABLE error_records "
                    "ADD COLUMN rich_artifacts_json TEXT NOT NULL DEFAULT ''"
                )
            )
        if "classification_json" not in existing_columns:
            connection.execute(
                text(
                    "ALTER TABLE error_records "
                    "ADD COLUMN classification_json TEXT NOT NULL DEFAULT ''"
                )
            )
