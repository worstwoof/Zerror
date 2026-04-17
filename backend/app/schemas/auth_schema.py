from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, EmailStr, Field


class RegisterRequest(BaseModel):
    username: str = Field(min_length=3, max_length=64)
    email: EmailStr
    password: str = Field(min_length=6, max_length=128)


class LoginRequest(BaseModel):
    identifier: str = Field(min_length=3, max_length=255)
    password: str = Field(min_length=6, max_length=128)


class UserPayload(BaseModel):
    id: int
    username: str
    email: str
    sync_user_id: str


class AuthResponse(BaseModel):
    token: str
    token_type: str = "bearer"
    expires_at: datetime
    user: UserPayload


class LogoutResponse(BaseModel):
    message: str
