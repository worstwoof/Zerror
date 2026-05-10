from __future__ import annotations

import hashlib
import hmac
import secrets
from datetime import datetime, timedelta, timezone

from fastapi import Depends, Header, HTTPException, status
from sqlalchemy.orm import Session

from backend.app.core.config import settings
from backend.app.db.models import AuthSession, User
from backend.app.db.session import get_db


PBKDF2_ITERATIONS = settings.auth_pbkdf2_iterations


def hash_password(password: str) -> str:
    salt = secrets.token_hex(16)
    digest = hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        salt.encode("utf-8"),
        PBKDF2_ITERATIONS,
    ).hex()
    return f"pbkdf2_sha256${PBKDF2_ITERATIONS}${salt}${digest}"


def verify_password(password: str, stored_hash: str) -> bool:
    try:
        algorithm, iteration_text, salt, expected_digest = stored_hash.split("$", 3)
        iterations = int(iteration_text)
    except (TypeError, ValueError):
        return False

    if algorithm != "pbkdf2_sha256":
        return False

    actual_digest = hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        salt.encode("utf-8"),
        iterations,
    ).hex()
    return hmac.compare_digest(actual_digest, expected_digest)


def issue_session_token() -> str:
    return secrets.token_urlsafe(32)


def hash_session_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def build_sync_user_id() -> str:
    return f"user_{secrets.token_hex(8)}"


def create_auth_session(db: Session, user: User) -> tuple[AuthSession, str]:
    token = issue_session_token()
    now = datetime.now(timezone.utc)
    session = AuthSession(
        user_id=user.id,
        token_hash=hash_session_token(token),
        expires_at=now + timedelta(days=settings.auth_session_days),
        last_used_at=now,
    )
    db.add(session)
    db.flush()
    return session, token


def get_bearer_token(authorization: str | None = Header(default=None)) -> str:
    if authorization is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required.",
        )

    scheme, _, value = authorization.partition(" ")
    if scheme.lower() != "bearer" or not value.strip():
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authorization header.",
        )
    return value.strip()


def get_current_auth_session(
    token: str = Depends(get_bearer_token),
    db: Session = Depends(get_db),
) -> AuthSession:
    session = (
        db.query(AuthSession)
        .filter(AuthSession.token_hash == hash_session_token(token))
        .first()
    )
    if session is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication session not found.",
        )

    now = datetime.now(timezone.utc)
    expires_at = session.expires_at
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    if expires_at <= now:
        db.delete(session)
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication session expired.",
        )

    session.last_used_at = now
    db.commit()
    db.refresh(session)
    return session


def get_current_user(
    session: AuthSession = Depends(get_current_auth_session),
) -> User:
    return session.user
