"""本文から語と数値を探す（純粋な処理。PDF ライブラリに触らない）。

決算資料の数字には日本語圏特有の書き方がある。
**負数が △ や ▲ で書かれる**のがその代表で、素直に float に通すと符号が消える。
ここを取り違えると「減益を増益と読む」ので、変換は1箇所に集めてテストで固定する。
"""

from __future__ import annotations

import re
from dataclasses import asdict, dataclass

from .document import Document

#: 数値らしき並び（桁区切り・小数・前後の記号を含む）
NUMBER_RE = re.compile(r"[△▲\-−]?\d[\d,]*(?:\.\d+)?")

#: 負数として扱う先頭記号（△▲ は会計資料の慣習、−は全角マイナス）
MINUS_MARKS = "△▲-−"


@dataclass
class Hit:
    """見つかった1行。ページ番号を必ず持つ。"""

    page: int
    line: str
    numbers: list[str]

    def to_dict(self) -> dict:
        return asdict(self)

    def describe(self) -> str:
        return f"p.{self.page}  {self.line}"


def numbers_in(text: str) -> list[str]:
    """行に含まれる数値らしき文字列を、原文の表記のまま返す。"""
    return NUMBER_RE.findall(text or "")


def to_float(token: str) -> float | None:
    """原文の表記を数値にする。△1,234 は -1234.0。

    読めないものは None を返す（勝手に0にしない。0と「不明」は違う）。
    """
    text = (token or "").strip()
    if not text:
        return None
    negative = text[0] in MINUS_MARKS
    body = text[1:] if negative else text
    body = body.replace(",", "").replace("，", "").strip()
    if not body:
        return None
    try:
        value = float(body)
    except ValueError:
        return None
    return -value if negative else value


def find(document: Document, needle: str, *, limit: int = 20) -> list[Hit]:
    """語を含む行を、ページ番号つきで返す。"""
    if not needle or not needle.strip():
        raise ValueError("探す語を指定してください")

    lowered = needle.strip().lower()
    hits: list[Hit] = []
    for page in document.pages:
        for line in page.lines:
            if lowered in line.lower():
                hits.append(Hit(page=page.number, line=line, numbers=numbers_in(line)))
                if limit and len(hits) >= limit:
                    return hits
    return hits
