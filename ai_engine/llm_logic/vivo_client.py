from __future__ import annotations

import base64
import json
import logging
import time
import uuid
from typing import Any, Dict, List

import requests

from backend.app.core.config import Settings


logger = logging.getLogger(__name__)


class VivoAPIError(RuntimeError):
    pass


class VivoLMClient:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings

    def chat_completion(self, prompt: str, messages: List[Dict[str, Any]] | None = None) -> str:
        request_id = str(uuid.uuid4())
        started_at = time.perf_counter()
        payload = {
            "model": self.settings.vivo_text_model,
            "messages": messages or [{"role": "user", "content": prompt}],
            "temperature": 0.3,
            "max_tokens": self.settings.vivo_max_tokens,
            "stream": False,
        }
        payload.update(
            self._build_thinking_payload(
                model_name=self.settings.vivo_text_model,
                thinking_mode=self.settings.vivo_text_thinking_mode,
            )
        )
        payload.update(
            self._build_reasoning_payload(
                model_name=self.settings.vivo_text_model,
                reasoning_effort=self.settings.vivo_text_reasoning_effort,
            )
        )
        try:
            response = requests.post(
                f"{self.settings.vivo_base_url}/chat/completions",
                headers=self._json_headers(),
                params={"request_id": request_id},
                json=payload,
                timeout=min(self.settings.vivo_timeout_seconds, self.settings.vivo_vision_timeout_seconds),
            )
        except requests.RequestException as exc:
            logger.warning(
                "vivo chat failed request_id=%s model=%s elapsed=%.2fs error=%s",
                request_id,
                self.settings.vivo_text_model,
                time.perf_counter() - started_at,
                exc,
            )
            raise VivoAPIError(f"vivo 聊天接口网络异常，request_id={request_id}，错误={exc}") from exc
        logger.info(
            "vivo chat finished request_id=%s model=%s status=%s elapsed=%.2fs",
            request_id,
            self.settings.vivo_text_model,
            response.status_code,
            time.perf_counter() - started_at,
        )
        return self._extract_chat_content(response, request_id)

    def vision_completion(self, prompt: str, image_bytes: bytes, mime_type: str = "image/png") -> str:
        request_id = str(uuid.uuid4())
        started_at = time.perf_counter()
        normalized_mime_type = self._normalize_image_mime_type(
            image_bytes=image_bytes,
            mime_type=mime_type,
        )
        logger.info(
            "vivo vision image request_id=%s model=%s mime_type=%s normalized_mime_type=%s image_kb=%.1f",
            request_id,
            self.settings.vivo_vision_model,
            mime_type,
            normalized_mime_type,
            len(image_bytes) / 1024,
        )
        payload = {
            "model": self.settings.vivo_vision_model,
            "messages": [
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": prompt},
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": self._build_data_uri(image_bytes, normalized_mime_type),
                            },
                        },
                    ],
                }
            ],
            "temperature": 0.3,
            "max_tokens": self.settings.vivo_max_tokens,
            "stream": False,
        }
        payload.update(
            self._build_thinking_payload(
                model_name=self.settings.vivo_vision_model,
                thinking_mode=self.settings.vivo_vision_thinking_mode,
            )
        )
        payload.update(
            self._build_reasoning_payload(
                model_name=self.settings.vivo_vision_model,
                reasoning_effort=self.settings.vivo_vision_reasoning_effort,
            )
        )
        try:
            response = requests.post(
                f"{self.settings.vivo_base_url}/chat/completions",
                headers=self._json_headers(),
                params={"request_id": request_id},
                json=payload,
                timeout=self.settings.vivo_vision_timeout_seconds,
            )
        except requests.RequestException as exc:
            raise VivoAPIError(f"vivo 多模态接口网络异常，request_id={request_id}，错误={exc}") from exc
        return self._extract_chat_content(response, request_id)

    def ocr_image(self, image_bytes: bytes) -> Dict[str, Any]:
        request_id = str(uuid.uuid4())
        payload = {
            "image": base64.b64encode(image_bytes).decode("utf-8"),
            "pos": 2,
        }
        if self.settings.vivo_app_id:
            payload["businessid"] = f"aigc{self.settings.vivo_app_id}"

        try:
            response = requests.post(
                self.settings.vivo_ocr_url,
                headers={
                    "Authorization": f"Bearer {self.settings.vivo_api_key}",
                    "Content-Type": "application/x-www-form-urlencoded",
                },
                params={"requestId": request_id},
                data=payload,
                timeout=min(self.settings.vivo_timeout_seconds, 30),
            )
        except requests.RequestException as exc:
            raise VivoAPIError(f"vivo OCR 接口网络异常，request_id={request_id}，错误={exc}") from exc
        self._raise_for_status(response, request_id)

        data = response.json()
        raw_text, blocks = self._extract_ocr_text(data)
        return {
            "raw_text": raw_text,
            "blocks": blocks,
            "request_id": request_id,
            "raw_response": data,
        }

    def _json_headers(self) -> Dict[str, str]:
        headers = {
            "Content-Type": "application/json; charset=utf-8",
            "Authorization": f"Bearer {self.settings.vivo_api_key}",
        }
        if self.settings.vivo_app_id:
            headers["app_id"] = self.settings.vivo_app_id
        return headers

    def _extract_chat_content(self, response: requests.Response, request_id: str) -> str:
        self._raise_for_status(response, request_id)
        data = response.json()
        try:
            choice = data["choices"][0]
            content = choice["message"]["content"]
            finish_reason = choice.get("finish_reason", "")
            logger.info(
                "vivo chat parsed request_id=%s finish_reason=%s content_len=%s",
                request_id,
                finish_reason or "unknown",
                len(str(content)),
            )
            return content
        except (KeyError, IndexError, TypeError) as exc:
            raise VivoAPIError(
                f"vivo 聊天接口返回结构异常，request_id={request_id}，响应={json.dumps(data, ensure_ascii=False)}"
            ) from exc

    def _build_thinking_payload(self, *, model_name: str, thinking_mode: str) -> Dict[str, Any]:
        normalized_mode = self._normalize_thinking_mode(thinking_mode)
        if normalized_mode == "auto":
            return {}

        lowered_model = (model_name or "").lower()
        if "qwen" in lowered_model:
            enabled = normalized_mode == "enabled"
            logger.info(
                "vivo thinking config model=%s field=enable_thinking value=%s",
                model_name,
                enabled,
            )
            return {"enable_thinking": enabled}

        if any(token in lowered_model for token in ["deepseek", "doubao", "volc"]):
            logger.info(
                "vivo thinking config model=%s field=thinking.type value=%s",
                model_name,
                normalized_mode,
            )
            return {"thinking": {"type": normalized_mode}}

        logger.info(
            "vivo thinking config skipped model=%s unsupported_mode_mapping=%s",
            model_name,
            normalized_mode,
        )
        return {}

    def _build_reasoning_payload(self, *, model_name: str, reasoning_effort: str) -> Dict[str, Any]:
        normalized_effort = self._normalize_reasoning_effort(reasoning_effort)
        if normalized_effort == "auto":
            return {}

        lowered_model = (model_name or "").lower()
        if not any(token in lowered_model for token in ["qwen", "deepseek", "doubao", "volc"]):
            logger.info(
                "vivo reasoning config skipped model=%s unsupported_effort_mapping=%s",
                model_name,
                normalized_effort,
            )
            return {}

        logger.info(
            "vivo reasoning config model=%s field=reasoning_effort value=%s",
            model_name,
            normalized_effort,
        )
        return {"reasoning_effort": normalized_effort}

    def _normalize_thinking_mode(self, thinking_mode: str) -> str:
        normalized = (thinking_mode or "auto").strip().lower()
        aliases = {
            "auto": "auto",
            "enabled": "enabled",
            "enable": "enabled",
            "true": "enabled",
            "on": "enabled",
            "disabled": "disabled",
            "disable": "disabled",
            "false": "disabled",
            "off": "disabled",
        }
        return aliases.get(normalized, "auto")

    def _normalize_reasoning_effort(self, reasoning_effort: str) -> str:
        normalized = (reasoning_effort or "auto").strip().lower()
        aliases = {
            "": "auto",
            "auto": "auto",
            "default": "auto",
            "minimal": "minimal",
            "none": "minimal",
            "off": "minimal",
            "low": "low",
            "medium": "medium",
            "high": "high",
        }
        return aliases.get(normalized, "auto")

    def _extract_ocr_text(self, data: Dict[str, Any]) -> tuple[str, List[Dict[str, Any]]]:
        candidates = [
            data.get("result"),
            data.get("data"),
            data.get("results"),
        ]
        blocks: List[Dict[str, Any]] = []

        for candidate in candidates:
            if isinstance(candidate, dict):
                ocr_items = candidate.get("OCR")
                if isinstance(ocr_items, list):
                    blocks = [item for item in ocr_items if isinstance(item, dict)]
                    texts = [self._extract_block_text(item) for item in blocks]
                    merged = "\n".join(text for text in texts if text)
                    if merged.strip():
                        return merged, blocks

                lines = candidate.get("lines") or candidate.get("items") or candidate.get("words")
                if isinstance(lines, list):
                    blocks = [item for item in lines if isinstance(item, dict)]
                    texts = [self._extract_block_text(item) for item in blocks]
                    merged = "\n".join(text for text in texts if text)
                    if merged.strip():
                        return merged, blocks

                for key in ("text", "content", "ocrText", "words"):
                    if candidate.get(key):
                        return str(candidate[key]).strip(), blocks

            if isinstance(candidate, list):
                blocks = [item for item in candidate if isinstance(item, dict)]
                texts = [self._extract_block_text(item) for item in blocks]
                merged = "\n".join(text for text in texts if text)
                if merged.strip():
                    return merged, blocks

        for key in ("text", "content", "ocrText", "words"):
            if data.get(key):
                return str(data[key]).strip(), blocks

        return json.dumps(data, ensure_ascii=False), blocks

    def _extract_block_text(self, block: Dict[str, Any]) -> str:
        for key in ("text", "words", "content", "ocrText"):
            value = block.get(key)
            if isinstance(value, str) and value.strip():
                return value.strip()
        return ""

    def _raise_for_status(self, response: requests.Response, request_id: str) -> None:
        try:
            response.raise_for_status()
        except requests.HTTPError as exc:
            body = response.text
            raise VivoAPIError(
                f"vivo 接口请求失败，request_id={request_id}，status={response.status_code}，body={body}"
            ) from exc

    def _build_data_uri(self, image_bytes: bytes, mime_type: str) -> str:
        encoded = base64.b64encode(image_bytes).decode("utf-8")
        return f"data:{mime_type};base64,{encoded}"

    def _normalize_image_mime_type(self, *, image_bytes: bytes, mime_type: str) -> str:
        sniffed_mime_type = self._sniff_image_mime_type(image_bytes)
        if sniffed_mime_type:
            return sniffed_mime_type

        normalized = (mime_type or "").strip().lower()
        aliases = {
            "image/jpg": "image/jpeg",
            "image/pjpeg": "image/jpeg",
            "image/x-png": "image/png",
            "application/octet-stream": "image/jpeg",
        }
        if normalized in aliases:
            return aliases[normalized]
        if normalized.startswith("image/"):
            return normalized
        return "image/jpeg"

    def _sniff_image_mime_type(self, image_bytes: bytes) -> str:
        if image_bytes.startswith(b"\xff\xd8\xff"):
            return "image/jpeg"
        if image_bytes.startswith(b"\x89PNG\r\n\x1a\n"):
            return "image/png"
        if image_bytes.startswith((b"GIF87a", b"GIF89a")):
            return "image/gif"
        if len(image_bytes) >= 12 and image_bytes[:4] == b"RIFF" and image_bytes[8:12] == b"WEBP":
            return "image/webp"
        return ""
