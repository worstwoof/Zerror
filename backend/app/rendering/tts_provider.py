from __future__ import annotations

import json
import os
import shutil
import subprocess
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, Iterable, List

from backend.app.core.config import settings

HTTP_TTS_PROVIDERS = {"cosyvoice_http", "f5_http", "gpt_sovits_http"}


@dataclass(frozen=True)
class TtsSynthesisResult:
    path: Path | None
    provider: str
    fallback_used: bool
    chunk_count: int
    voice: str
    elapsed_seconds: float
    error_summary: str = ""

    def diagnostics(self) -> Dict[str, Any]:
        return {
            "tts_provider": self.provider,
            "tts_fallback_used": self.fallback_used,
            "tts_chunk_count": self.chunk_count,
            "tts_voice": self.voice,
            "tts_elapsed_seconds": round(self.elapsed_seconds, 3),
            "tts_error_summary": self.error_summary,
            "voiceover_generated": self.path is not None and self.path.exists(),
        }


def synthesize_voiceover(video_path: Path, *, text: str) -> TtsSynthesisResult:
    started_at = time.perf_counter()
    provider = _tts_provider()
    result = _synthesize_with_provider(video_path, text=text, provider=provider)
    if result.path is not None and result.path.exists():
        return result

    fallback_provider = _tts_fallback_provider()
    if fallback_provider and fallback_provider != provider:
        fallback = _synthesize_with_provider(
            video_path,
            text=text,
            provider=fallback_provider,
            fallback_used=True,
        )
        if fallback.path is not None and fallback.path.exists():
            return fallback

    elapsed = time.perf_counter() - started_at
    return TtsSynthesisResult(
        path=None,
        provider=provider,
        fallback_used=False,
        chunk_count=0,
        voice=_tts_voice(),
        elapsed_seconds=elapsed,
        error_summary=result.error_summary,
    )


def tts_diagnostics_base() -> Dict[str, Any]:
    provider = _tts_provider()
    fallback_provider = _tts_fallback_provider()
    piper_model = _piper_voice_model()
    piper_model_exists = bool(piper_model and Path(piper_model).exists())
    return {
        "tts_provider": provider,
        "tts_fallback_provider": fallback_provider,
        "tts_service_configured": bool(_tts_service_url()),
        "tts_voice": _tts_voice(),
        "tts_timeout_seconds": _tts_timeout_seconds(),
        "tts_fallback_used": False,
        "tts_chunk_count": 0,
        "tts_elapsed_seconds": 0,
        "tts_error_summary": "",
        "voiceover_engine": provider,
        "voiceover_command_configured": bool(_piper_command()),
        "voiceover_model_configured": piper_model_exists,
        "voiceover_configured": _provider_configured(provider)
        or bool(fallback_provider and _provider_configured(fallback_provider)),
        "voiceover_generated": False,
    }


def split_tts_text(text: str, *, max_chars: int = 260) -> List[str]:
    normalized = " ".join(str(text).replace("\n", " ").split())
    if not normalized:
        return []

    chunks: list[str] = []
    current: list[str] = []
    punctuation = set("。！？!?；;，,、")
    for character in normalized:
        current.append(character)
        should_split = character in punctuation and len(current) >= max_chars * 0.45
        if len(current) >= max_chars or should_split:
            value = "".join(current).strip()
            if value:
                chunks.append(value)
            current = []
    tail = "".join(current).strip()
    if tail:
        chunks.append(tail)
    return chunks


def _synthesize_with_provider(
    video_path: Path,
    *,
    text: str,
    provider: str,
    fallback_used: bool = False,
) -> TtsSynthesisResult:
    started_at = time.perf_counter()
    provider = provider or "piper"
    if provider in HTTP_TTS_PROVIDERS:
        result = _synthesize_http_voiceover(video_path, text=text, provider=provider)
    elif provider == "piper":
        result = _synthesize_piper_voiceover(video_path, text=text)
    else:
        result = TtsSynthesisResult(
            path=None,
            provider=provider,
            fallback_used=fallback_used,
            chunk_count=0,
            voice=_tts_voice(),
            elapsed_seconds=0,
            error_summary=f"Unsupported TTS provider: {provider}",
        )
    elapsed = time.perf_counter() - started_at
    return TtsSynthesisResult(
        path=result.path,
        provider=result.provider,
        fallback_used=fallback_used or result.fallback_used,
        chunk_count=result.chunk_count,
        voice=result.voice,
        elapsed_seconds=elapsed,
        error_summary=result.error_summary,
    )


def _synthesize_http_voiceover(video_path: Path, *, text: str, provider: str) -> TtsSynthesisResult:
    url = _tts_service_endpoint()
    voice = _tts_voice()
    if not url:
        return TtsSynthesisResult(
            path=None,
            provider=provider,
            fallback_used=False,
            chunk_count=0,
            voice=voice,
            elapsed_seconds=0,
            error_summary="TTS service URL is not configured.",
        )
    chunks = split_tts_text(text)
    if not chunks:
        return TtsSynthesisResult(
            path=None,
            provider=provider,
            fallback_used=False,
            chunk_count=0,
            voice=voice,
            elapsed_seconds=0,
            error_summary="Voiceover text is empty.",
        )
    output_path = video_path.with_name(f"{video_path.stem}.voice.wav")
    chunk_paths: list[Path] = []
    try:
        for index, chunk in enumerate(chunks):
            chunk_path = video_path.with_name(f"{video_path.stem}.tts-{index:02d}.wav")
            _http_tts_chunk(
                provider=provider,
                endpoint=url,
                text=chunk,
                voice=voice,
                output_path=chunk_path,
            )
            chunk_paths.append(chunk_path)
        if _combine_audio_chunks(chunk_paths, output_path):
            return TtsSynthesisResult(
                path=output_path,
                provider=provider,
                fallback_used=False,
                chunk_count=len(chunks),
                voice=voice,
                elapsed_seconds=0,
            )
    except Exception as exc:
        return TtsSynthesisResult(
            path=None,
            provider=provider,
            fallback_used=False,
            chunk_count=len(chunks),
            voice=voice,
            elapsed_seconds=0,
            error_summary=_error_summary(exc),
        )
    finally:
        _unlink_many(chunk_paths)
    return TtsSynthesisResult(
        path=None,
        provider=provider,
        fallback_used=False,
        chunk_count=len(chunks),
        voice=voice,
        elapsed_seconds=0,
        error_summary="TTS audio chunks could not be combined.",
    )


def _synthesize_piper_voiceover(video_path: Path, *, text: str) -> TtsSynthesisResult:
    piper = _piper_command()
    model = _piper_voice_model()
    voice = _tts_voice()
    if not text:
        return TtsSynthesisResult(None, "piper", False, 0, voice, 0, "Voiceover text is empty.")
    if not piper or not model or not Path(model).exists():
        return TtsSynthesisResult(None, "piper", False, 0, voice, 0, "Piper is not configured.")

    output_path = video_path.with_name(f"{video_path.stem}.voice.wav")
    command = [
        piper,
        "--model",
        model,
        "--output_file",
        str(output_path),
    ]
    config_path = _piper_voice_config()
    if config_path and Path(config_path).exists():
        command.extend(["--config", config_path])
    try:
        if output_path.exists():
            output_path.unlink()
        completed = subprocess.run(
            command,
            input=text,
            cwd=video_path.parent,
            capture_output=True,
            text=True,
            timeout=_tts_timeout_seconds(),
            check=False,
        )
        if completed.returncode == 0 and output_path.exists() and output_path.stat().st_size > 0:
            return TtsSynthesisResult(output_path, "piper", False, 1, voice, 0)
        error = (completed.stderr or completed.stdout or "").strip()
        return TtsSynthesisResult(None, "piper", False, 1, voice, 0, error[-400:])
    except Exception as exc:
        return TtsSynthesisResult(None, "piper", False, 1, voice, 0, _error_summary(exc))


def _http_tts_chunk(
    *,
    provider: str,
    endpoint: str,
    text: str,
    voice: str,
    output_path: Path,
) -> None:
    payload = {
        "text": text,
        "voice": voice,
        "speed": 1.0,
        "format": "wav",
        "sample_rate": 24000,
        "provider": provider,
    }
    headers = {
        "Content-Type": "application/json; charset=utf-8",
        "Accept": "audio/wav",
    }
    api_key = _tts_api_key()
    if api_key:
        headers["Authorization"] = f"Bearer {api_key}"
    request = urllib.request.Request(
        endpoint,
        data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
        headers=headers,
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=_tts_timeout_seconds()) as response:
            content = response.read()
    except urllib.error.URLError as exc:
        raise RuntimeError(f"{provider} TTS request failed: {exc}") from exc
    if not content:
        raise RuntimeError(f"{provider} TTS returned empty audio.")
    output_path.write_bytes(content)


def _combine_audio_chunks(chunk_paths: Iterable[Path], output_path: Path) -> bool:
    paths = [path for path in chunk_paths if path.exists() and path.stat().st_size > 0]
    if not paths:
        return False
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        if len(paths) == 1:
            shutil.copyfile(paths[0], output_path)
            return output_path.exists() and output_path.stat().st_size > 0
        return False

    concat_path = output_path.with_suffix(".concat.txt")
    try:
        concat_path.write_text(
            "".join(f"file '{path.resolve().as_posix()}'\n" for path in paths),
            encoding="utf-8",
        )
        command = [
            ffmpeg,
            "-y",
            "-f",
            "concat",
            "-safe",
            "0",
            "-i",
            str(concat_path),
            "-af",
            "loudnorm=I=-18:TP=-2:LRA=11",
            "-ar",
            "44100",
            str(output_path),
        ]
        completed = subprocess.run(
            command,
            cwd=output_path.parent,
            capture_output=True,
            text=True,
            timeout=160,
            check=False,
        )
        return completed.returncode == 0 and output_path.exists() and output_path.stat().st_size > 0
    finally:
        try:
            concat_path.unlink(missing_ok=True)
        except OSError:
            pass


def _provider_configured(provider: str) -> bool:
    if provider in HTTP_TTS_PROVIDERS:
        return bool(_tts_service_url())
    if provider == "piper":
        model = _piper_voice_model()
        return bool(_piper_command() and model and Path(model).exists())
    return False


def _tts_provider() -> str:
    return (
        os.getenv("ZERROR_TTS_PROVIDER")
        or os.getenv("TTS_PROVIDER")
        or settings.tts_provider
        or "cosyvoice_http"
    ).strip()


def _tts_fallback_provider() -> str:
    value = (
        os.getenv("ZERROR_TTS_FALLBACK_PROVIDER")
        or os.getenv("TTS_FALLBACK_PROVIDER")
        or settings.tts_fallback_provider
        or "piper"
    ).strip()
    if value.lower() in {"", "none", "off", "disabled", "disable", "false", "no"}:
        return ""
    return value


def _tts_service_url() -> str:
    return (
        os.getenv("ZERROR_TTS_SERVICE_URL")
        or os.getenv("TTS_SERVICE_URL")
        or settings.tts_service_url
    ).strip()


def _tts_service_endpoint() -> str:
    base_url = _tts_service_url().rstrip("/")
    if not base_url:
        return ""
    if base_url.endswith("/v1/tts"):
        return base_url
    return f"{base_url}/v1/tts"


def _tts_api_key() -> str:
    return (
        os.getenv("ZERROR_TTS_API_KEY")
        or os.getenv("TTS_API_KEY")
        or settings.tts_api_key
    )


def _tts_voice() -> str:
    return (
        os.getenv("ZERROR_TTS_VOICE")
        or os.getenv("TTS_VOICE")
        or settings.tts_voice
        or "teacher_female_clear"
    )


def _tts_timeout_seconds() -> int:
    raw = (
        os.getenv("ZERROR_TTS_TIMEOUT_SECONDS")
        or os.getenv("TTS_TIMEOUT_SECONDS")
        or str(settings.tts_timeout_seconds)
        or "300"
    )
    try:
        return max(10, min(600, int(float(raw))))
    except (TypeError, ValueError):
        return 300


def _piper_command() -> str | None:
    return (
        os.getenv("PIPER_TTS_COMMAND")
        or os.getenv("PIPER_COMMAND")
        or settings.piper_tts_command
        or shutil.which("piper")
    )


def _piper_voice_model() -> str:
    return (
        os.getenv("PIPER_VOICE_MODEL")
        or os.getenv("ZERROR_PIPER_VOICE_MODEL")
        or settings.piper_voice_model
    )


def _piper_voice_config() -> str:
    return (
        os.getenv("PIPER_VOICE_CONFIG")
        or os.getenv("ZERROR_PIPER_VOICE_CONFIG")
        or settings.piper_voice_config
    )


def _unlink_many(paths: Iterable[Path]) -> None:
    for path in paths:
        try:
            path.unlink(missing_ok=True)
        except OSError:
            pass


def _error_summary(exc: Exception) -> str:
    return str(exc).strip()[:400] or exc.__class__.__name__
