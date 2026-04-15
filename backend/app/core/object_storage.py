from __future__ import annotations

import mimetypes
import re
import uuid
from datetime import datetime, timezone
from urllib.parse import unquote, urlparse

from qcloud_cos import CosConfig, CosS3Client

from backend.app.core.config import Settings


class ObjectStorageError(RuntimeError):
    pass


class TencentCOSStorage:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        config = CosConfig(
            Region=settings.tencent_cos_region,
            SecretId=settings.tencent_cos_secret_id,
            SecretKey=settings.tencent_cos_secret_key,
        )
        self.client = CosS3Client(config)

    def upload_bytes(
        self,
        *,
        file_bytes: bytes,
        filename: str | None,
        content_type: str | None,
        folder: str,
    ) -> tuple[str, str]:
        if not file_bytes:
            raise ObjectStorageError("Uploaded file is empty.")

        object_key = self._build_object_key(
            folder=folder,
            filename=filename,
            content_type=content_type,
        )
        mime_type = self._resolve_content_type(filename, content_type)

        try:
            self.client.put_object(
                Bucket=self.settings.tencent_cos_bucket,
                Body=file_bytes,
                Key=object_key,
                ContentType=mime_type,
            )
        except Exception as exc:  # noqa: BLE001
            raise ObjectStorageError(f"Failed to upload file to Tencent COS: {exc}") from exc

        return object_key, self._build_public_url(object_key)

    def delete_file_reference(self, file_reference: str) -> bool:
        object_key = self._extract_object_key(file_reference)
        if not object_key:
            return False

        try:
            self.client.delete_object(
                Bucket=self.settings.tencent_cos_bucket,
                Key=object_key,
            )
        except Exception as exc:  # noqa: BLE001
            raise ObjectStorageError(f"Failed to delete file from Tencent COS: {exc}") from exc
        return True

    def _build_object_key(
        self,
        *,
        folder: str,
        filename: str | None,
        content_type: str | None,
    ) -> str:
        safe_folder = re.sub(r"[^a-zA-Z0-9/_-]+", "-", folder).strip("-/")
        suffix = self._infer_suffix(filename, content_type)
        date_prefix = datetime.now(timezone.utc).strftime("%Y/%m/%d")
        return f"{safe_folder}/{date_prefix}/{uuid.uuid4().hex}{suffix}"

    def _infer_suffix(self, filename: str | None, content_type: str | None) -> str:
        if filename:
            guess = mimetypes.guess_extension(mimetypes.guess_type(filename)[0] or "")
            explicit = mimetypes.guess_extension(content_type or "")
            existing = ""
            if "." in filename:
                existing = "." + filename.rsplit(".", 1)[-1].lower()
            return existing or explicit or guess or ".bin"
        return mimetypes.guess_extension(content_type or "") or ".bin"

    def _resolve_content_type(self, filename: str | None, content_type: str | None) -> str:
        if content_type:
            return content_type
        guessed_type, _ = mimetypes.guess_type(filename or "")
        return guessed_type or "application/octet-stream"

    def _build_public_url(self, object_key: str) -> str:
        if self.settings.tencent_cos_base_url:
            return f"{self.settings.tencent_cos_base_url.rstrip('/')}/{object_key}"
        bucket = self.settings.tencent_cos_bucket
        region = self.settings.tencent_cos_region
        return f"https://{bucket}.cos.{region}.myqcloud.com/{object_key}"

    def _extract_object_key(self, file_reference: str) -> str | None:
        if not file_reference:
            return None

        if "://" not in file_reference:
            return file_reference.lstrip("/") or None

        parsed = urlparse(file_reference)
        if not parsed.scheme or not parsed.netloc:
            return None

        default_host = f"{self.settings.tencent_cos_bucket}.cos.{self.settings.tencent_cos_region}.myqcloud.com"
        if parsed.netloc == default_host:
            return unquote(parsed.path.lstrip("/")) or None

        if self.settings.tencent_cos_base_url:
            base = urlparse(self.settings.tencent_cos_base_url)
            if parsed.netloc != base.netloc:
                return None

            base_path = base.path.rstrip("/")
            current_path = parsed.path
            if base_path:
                prefix = f"{base_path}/"
                if not current_path.startswith(prefix):
                    return None
                current_path = current_path[len(prefix):]

            return unquote(current_path.lstrip("/")) or None

        return None
