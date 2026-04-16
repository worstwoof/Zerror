from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path
from typing import Dict


PROJECT_ROOT = Path(__file__).resolve().parents[3]
DEFAULT_ENV_PATH = PROJECT_ROOT / ".env"


def _parse_env_file(env_path: Path) -> Dict[str, str]:
    if not env_path.exists():
        return {}

    parsed: Dict[str, str] = {}
    raw_lines = env_path.read_text(encoding="utf-8").splitlines()
    for line in raw_lines:
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if stripped in {'@"', "@'", '"@', "'@"}:
            continue
        if stripped.startswith('"@ |') or stripped.startswith("'@ |"):
            continue
        if "=" in stripped:
            key, value = stripped.split("=", 1)
            parsed[key.strip()] = value.strip().strip("\"'")
        else:
            # Backward compatibility for the current repo's single-line key file.
            parsed["VIVO_API_KEY"] = stripped
    return parsed


def _get_setting(name: str, file_values: Dict[str, str], default: str = "") -> str:
    return os.getenv(name, file_values.get(name, default))


@dataclass(frozen=True)
class Settings:
    app_name: str
    app_version: str
    database_url: str
    auth_session_days: int
    tencent_cos_secret_id: str
    tencent_cos_secret_key: str
    tencent_cos_region: str
    tencent_cos_bucket: str
    tencent_cos_base_url: str
    vivo_api_key: str
    vivo_app_id: str
    vivo_base_url: str
    vivo_ocr_url: str
    vivo_text_model: str
    vivo_vision_model: str
    vivo_timeout_seconds: int
    vivo_max_tokens: int
    debug: bool

    @property
    def has_vivo_credentials(self) -> bool:
        return bool(self.vivo_api_key)

    @property
    def has_tencent_cos_config(self) -> bool:
        return all(
            [
                self.tencent_cos_secret_id,
                self.tencent_cos_secret_key,
                self.tencent_cos_region,
                self.tencent_cos_bucket,
            ]
        )


def get_settings() -> Settings:
    file_values = _parse_env_file(DEFAULT_ENV_PATH)
    return Settings(
        app_name=_get_setting("APP_NAME", file_values, "Cuoti DouDui Backend"),
        app_version=_get_setting("APP_VERSION", file_values, "0.1.0"),
        database_url=_get_setting(
            "DATABASE_URL",
            file_values,
            f"sqlite:///{(PROJECT_ROOT / 'backend' / 'app.db').as_posix()}",
        ),
        auth_session_days=int(_get_setting("AUTH_SESSION_DAYS", file_values, "30")),
        tencent_cos_secret_id=_get_setting("TENCENT_COS_SECRET_ID", file_values),
        tencent_cos_secret_key=_get_setting("TENCENT_COS_SECRET_KEY", file_values),
        tencent_cos_region=_get_setting("TENCENT_COS_REGION", file_values),
        tencent_cos_bucket=_get_setting("TENCENT_COS_BUCKET", file_values),
        tencent_cos_base_url=_get_setting("TENCENT_COS_BASE_URL", file_values),
        vivo_api_key=_get_setting("VIVO_API_KEY", file_values),
        vivo_app_id=_get_setting("VIVO_APP_ID", file_values),
        vivo_base_url=_get_setting("VIVO_API_BASE_URL", file_values, "https://api-ai.vivo.com.cn/v1"),
        vivo_ocr_url=_get_setting("VIVO_OCR_URL", file_values, "https://api-ai.vivo.com.cn/ocr/general_recognition"),
        vivo_text_model=_get_setting("VIVO_TEXT_MODEL", file_values, "Doubao-Seed-2.0-mini"),
        vivo_vision_model=_get_setting("VIVO_VISION_MODEL", file_values, "qwen3.5-plus"),
        vivo_timeout_seconds=int(_get_setting("VIVO_TIMEOUT_SECONDS", file_values, "120")),
        vivo_max_tokens=int(_get_setting("VIVO_MAX_TOKENS", file_values, "4096")),
        debug=_get_setting("DEBUG", file_values, "false").lower() == "true",
    )


settings = get_settings()
