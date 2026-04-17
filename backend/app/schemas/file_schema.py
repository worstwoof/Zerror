from __future__ import annotations

from pydantic import BaseModel


class FileUploadResponse(BaseModel):
    object_key: str
    file_url: str
    content_type: str
    size_bytes: int
