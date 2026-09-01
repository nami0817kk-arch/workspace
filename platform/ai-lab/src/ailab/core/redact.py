"""エラーメッセージからAPIキーを隠す。

キーはヘッダだけでなくクエリ文字列にも載る（Pixabay など）ため、
外部APIのエラー文やURLがそのまま表示・記録されると漏れうる。
表示の直前で環境変数の値と突き合わせて伏せる、最後の砦。
"""

from __future__ import annotations

import os
import re

#: 値を秘密として扱う環境変数名のパターン
SECRET_NAME = re.compile(r"(API_KEY|ACCESS_KEY|TOKEN|SECRET|PASSWORD)$", re.IGNORECASE)
#: これより短い値は誤って伏せる恐れがあるので対象にしない
MIN_LENGTH = 8
MASK = "***"


def secret_values() -> list[str]:
    """環境変数に入っている秘密の値。"""
    return [
        value
        for name, value in os.environ.items()
        if SECRET_NAME.search(name) and isinstance(value, str) and len(value.strip()) >= MIN_LENGTH
    ]


def redact(text: str) -> str:
    """文字列中のAPIキーを伏せる。"""
    if not text:
        return text
    for value in secret_values():
        text = text.replace(value.strip(), MASK)
    return text
