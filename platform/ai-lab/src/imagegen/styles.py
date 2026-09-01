"""プロンプトのプリセット。

「フラットイラストで、余白多めで…」と毎回書くのは面倒なうえ、
書き方がぶれると絵柄もぶれる。よく使う指定に名前を付けておく。
`styles.json` をリポジトリ直下に置けば追加・上書きできる。
"""

from __future__ import annotations

import json
from pathlib import Path

from .config import get_env, project_root
from .core.errors import ConfigError

STYLES_FILE = "styles.json"

#: 名前 -> (説明, プロンプトに足す指定)
#:
#: 説明は利用者向けなので日本語、モデルへ渡す指定は英語にする。
#: 生成モデルは英語で学習されているため、日本語の指定を混ぜると追従が落ちる。
BUILTIN_STYLES: dict[str, tuple[str, str]] = {
    "flat": (
        "フラットイラスト。資料やスライドに馴染む",
        "flat vector illustration, simplified shapes, muted palette, "
        "generous whitespace, minimal shading",
    ),
    "banner": (
        "バナー・OGP画像。中央に余白を残す",
        "wide banner background, abstract and understated, "
        "empty space in the center for text, smooth gradient",
    ),
    "icon": (
        "アイコン・サムネイル。単一の被写体",
        "single subject centered, solid background, bold clean outline, "
        "minimal detail, icon style",
    ),
    "watercolor": (
        "水彩画",
        "watercolor painting, soft bleeding colors, paper texture, visible brush strokes",
    ),
    "line": (
        "線画・スケッチ",
        "black line art on white background, thin clean lines, no shading, simple sketch",
    ),
    "photo": (
        "写真風",
        "photorealistic photograph, natural light, shallow depth of field, no text",
    ),
    "diagram": (
        "説明図・図解",
        "simple explanatory diagram, geometric shapes, limited color palette, no text",
    ),
}


def custom_path() -> Path:
    """ユーザー定義スタイルの置き場（IMAGEGEN_STYLES_FILE で変更可）。"""
    override = get_env("IMAGEGEN_STYLES_FILE")
    return Path(override) if override else project_root() / STYLES_FILE


def all_styles() -> dict[str, tuple[str, str]]:
    """組み込み＋ユーザー定義。同名ならユーザー定義が勝つ。"""
    styles = dict(BUILTIN_STYLES)
    path = custom_path()
    if not path.is_file():
        return styles
    try:
        custom = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return styles  # 壊れていても組み込みは使えるようにする
    for name, value in (custom or {}).items():
        if isinstance(value, str):
            styles[str(name)] = ("(ユーザー定義)", value)
        elif isinstance(value, dict) and value.get("prompt"):
            styles[str(name)] = (str(value.get("description", "(ユーザー定義)")), str(value["prompt"]))
    return styles


def apply(prompt: str, style: str | None) -> str:
    """プロンプトにスタイルの指定を足す。"""
    if not style:
        return prompt
    styles = all_styles()
    if style not in styles:
        raise ConfigError(
            f"未知のスタイルです: {style}（使えるもの: {', '.join(sorted(styles))}）"
        )
    return f"{prompt}, {styles[style][1]}"


def names() -> list[str]:
    return sorted(all_styles())
