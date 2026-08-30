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


#: 生成APIがよく受け取るアスペクト比表記
ASPECT_RATIOS = ["1:1", "16:9", "9:16", "3:2", "2:3", "4:5", "5:4", "21:9", "9:21"]


def closest_aspect_ratio(size: str) -> str:
    """'1024x1536' のようなサイズを、もっとも近いアスペクト比表記に変換する。

    ピクセル指定ではなくアスペクト比を受け取るAPI（Stability、Flux 系）向け。
    """
    try:
        width, height = parse_size(size)
    except ValueError:
        return "1:1"
    target = width / height
    return min(
        ASPECT_RATIOS,
        key=lambda ratio: abs(target - (int(ratio.split(":")[0]) / int(ratio.split(":")[1]))),
    )
