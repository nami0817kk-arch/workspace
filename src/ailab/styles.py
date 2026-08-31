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
BUILTIN_STYLES: dict[str, tuple[str, str]] = {
    "flat": (
        "フラットイラスト。資料やスライドに馴染む",
        "フラットイラスト、単純化された形、落ち着いた配色、余白多め、影は控えめ",
    ),
    "banner": (
        "バナー・OGP画像。中央に余白を残す",
        "横長のバナー用背景、抽象的で主張しすぎない、中央に文字を置ける余白、"
        "なめらかなグラデーション",
    ),
    "icon": (
        "アイコン・サムネイル。単一の被写体",
        "単一の被写体を中央に、単色の背景、はっきりした輪郭、装飾は最小限、アイコン風",
    ),
    "watercolor": ("水彩画", "水彩画、にじみと紙の質感、やわらかい色、手描きの筆致"),
    "line": ("線画・スケッチ", "白背景の線画、細い黒線、陰影なし、簡潔なスケッチ"),
    "photo": (
        "写真風",
        "写実的な写真、自然光、浅い被写界深度、余計な文字を入れない",
    ),
    "diagram": (
        "説明図・図解",
        "説明用の簡潔な図、幾何学的な形、限られた配色、文字は入れない",
    ),
}


def custom_path() -> Path:
    """ユーザー定義スタイルの置き場（AILAB_STYLES_FILE で変更可）。"""
    override = get_env("AILAB_STYLES_FILE")
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
    return f"{prompt}。{styles[style][1]}"


def names() -> list[str]:
    return sorted(all_styles())
