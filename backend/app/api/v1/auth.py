from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import or_
from sqlalchemy.orm import Session

from backend.app.core.auth import (
    build_sync_user_id,
    create_auth_session,
    get_current_auth_session,
    get_current_user,
    hash_password,
    verify_password,
)
from datetime import datetime, timezone

from backend.app.db.models import AuthSession, User, UserProfile
from backend.app.db.session import get_db
from backend.app.schemas.auth_schema import (
    AuthResponse,
    LoginRequest,
    LogoutResponse,
    RegisterRequest,
    UserPayload,
)


router = APIRouter(prefix="/api/v1/auth", tags=["auth"])


@router.post("/register", response_model=AuthResponse, status_code=status.HTTP_201_CREATED)
def register(
    request: RegisterRequest,
    db: Session = Depends(get_db),
) -> AuthResponse:
    username = request.username.strip()
    email = request.email.strip().lower()
    _validate_username(username)

    existing = (
        db.query(User)
        .filter(or_(User.username == username, User.email == email))
        .first()
    )
    if existing is not None:
        if existing.username == username:
            detail = "Username is already taken."
        else:
            detail = "Email is already registered."
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=detail)

    user = User(
        username=username,
        email=email,
        password_hash=hash_password(request.password),
        sync_user_id=build_sync_user_id(),
    )
    db.add(user)
    db.flush()
    db.add(
        UserProfile(
            user_id=user.id,
            display_name=username,
            public_user_id=username,
            motto="",
            password_updated_at=datetime.now(timezone.utc),
        )
    )

    session, token = create_auth_session(db, user)
    db.commit()
    db.refresh(user)
    db.refresh(session)
    return _build_auth_response(user, session, token)


@router.post("/login", response_model=AuthResponse)
def login(
    request: LoginRequest,
    db: Session = Depends(get_db),
) -> AuthResponse:
    identifier = request.identifier.strip()
    user = (
        db.query(User)
        .filter(or_(User.username == identifier, User.email == identifier.lower()))
        .first()
    )
    if user is None or not verify_password(request.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username/email or password.",
        )

    session, token = create_auth_session(db, user)
    db.commit()
    db.refresh(user)
    db.refresh(session)
    return _build_auth_response(user, session, token)


@router.get("/me", response_model=UserPayload)
def me(current_user: User = Depends(get_current_user)) -> UserPayload:
    return _build_user_payload(current_user)


@router.post("/logout", response_model=LogoutResponse)
def logout(
    current_session: AuthSession = Depends(get_current_auth_session),
    db: Session = Depends(get_db),
) -> LogoutResponse:
    db.delete(current_session)
    db.commit()
    return LogoutResponse(message="Signed out successfully.")


def _validate_username(username: str) -> None:
    if len(username) < 3:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Username must be at least 3 characters long.",
        )
    if not all(char.isalnum() or char in {"_", "-"} for char in username):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Username can only contain letters, numbers, underscores, and hyphens.",
        )


def _build_auth_response(user: User, session: AuthSession, token: str) -> AuthResponse:
    return AuthResponse(
        token=token,
        expires_at=session.expires_at,
        user=_build_user_payload(user),
    )


def _build_user_payload(user: User) -> UserPayload:
    return UserPayload(
        id=user.id,
        username=user.username,
        email=user.email,
        sync_user_id=user.sync_user_id,
    )
