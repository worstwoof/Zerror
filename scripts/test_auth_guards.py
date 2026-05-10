from __future__ import annotations

import sys
from pathlib import Path

from fastapi import HTTPException

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from backend.app.api.v1.auth import (
    _normalize_email,
    _normalize_login_identifier,
    _normalize_username,
    _validate_username,
)
from backend.app.core.auth import get_bearer_token, hash_password, verify_password


def test_auth_identity_normalizers_trim_expected_fields() -> None:
    assert _normalize_username("  student_01  ") == "student_01"
    assert _normalize_email("  Student@Example.COM  ") == "student@example.com"
    assert _normalize_login_identifier("  Student@Example.COM  ") == "Student@Example.COM"


def test_username_validation_rejects_short_or_unsafe_values() -> None:
    _validate_username("abc_123")

    for username in ("ab", "bad/name"):
        try:
            _validate_username(username)
        except HTTPException as exc:
            assert exc.status_code == 400
        else:
            raise AssertionError(f"{username!r} should be rejected")


def test_bearer_token_parser_requires_bearer_scheme() -> None:
    assert get_bearer_token("Bearer token-value") == "token-value"
    assert get_bearer_token("bearer   spaced-token  ") == "spaced-token"

    for header in (None, "Basic token", "Bearer   "):
        try:
            get_bearer_token(header)  # type: ignore[arg-type]
        except HTTPException as exc:
            assert exc.status_code == 401
        else:
            raise AssertionError(f"{header!r} should be rejected")


def test_password_hash_round_trip() -> None:
    stored = hash_password("correct horse battery staple")

    assert verify_password("correct horse battery staple", stored)
    assert not verify_password("wrong password", stored)
    assert not verify_password("password", "not-a-valid-hash")


if __name__ == "__main__":
    test_auth_identity_normalizers_trim_expected_fields()
    test_username_validation_rejects_short_or_unsafe_values()
    test_bearer_token_parser_requires_bearer_scheme()
    test_password_hash_round_trip()
    print("auth guard tests passed")
