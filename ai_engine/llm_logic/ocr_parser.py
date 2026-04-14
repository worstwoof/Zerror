from __future__ import annotations

import re


def normalize_ocr_text(text: str) -> str:
    normalized = text.replace("\r\n", "\n").replace("\r", "\n")
    normalized = re.sub(r"[ \t]+", " ", normalized)
    normalized = re.sub(r"\n{3,}", "\n\n", normalized)
    normalized = normalized.replace("（ ", "（").replace(" ）", "）")
    normalized = normalized.replace("( ", "(").replace(" )", ")")
    return normalized.strip()
