"""共通ユーティリティ。"""

from __future__ import annotations

import re
import unicodedata
from datetime import datetime


def slugify(text: str, max_length: int = 40) -> str:
    """ファイル名に使える短い文字列へ変換する（日本語はそのまま残す）。"""
    text = unicodedata.normalize("NFKC", text).strip()
    text = re.sub(r'[\\/:*?"<>|\s]+', "_", text)
    text = re.sub(r"_{2,}", "_", text).strip("_.")
    if len(text) > max_length:
        text = text[:max_length].rstrip("_.")
    return text or "image"


def timestamp() -> str:
    """YYYYmmdd_HHMMSS 形式のタイムスタンプ。"""
    return datetime.now().strftime("%Y%m%d_%H%M%S")


def parse_size(size: str) -> tuple[int, int]:
    """'1024x1024' のような文字列を (幅, 高さ) に変換する。"""
    match = re.fullmatch(r"\s*(\d+)\s*[x×]\s*(\d+)\s*", size)
    if not match:
        raise ValueError(f"サイズの指定が不正です: {size!r} (例: 1024x1024)")
    return int(match.group(1)), int(match.group(2))
