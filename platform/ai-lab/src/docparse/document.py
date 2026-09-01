"""読み取った PDF を表すデータ型。

**ページ番号を必ず持つ。** どのページから拾った値か言えないと、
一次情報として使えない（引用のたびに人が原文を開き直すことになる）。
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field

#: ページ範囲の指定（"1-3,5" のような形）
RANGE_RE = re.compile(r"^\s*(\d+)\s*(?:-\s*(\d+)\s*)?$")


@dataclass
class Page:
    """PDF の1ページ。"""

    number: int  # 1始まり（人が原文を開くときの番号に合わせる）
    text: str = ""
    tables: list[list[list[str]]] = field(default_factory=list)

    @property
    def lines(self) -> list[str]:
        return [line.strip() for line in self.text.splitlines() if line.strip()]

    @property
    def has_text(self) -> bool:
        return bool(self.text.strip())


@dataclass
class Document:
    """PDF 1冊。"""

    path: str = ""
    pages: list[Page] = field(default_factory=list)
    meta: dict = field(default_factory=dict)

    @property
    def page_count(self) -> int:
        return len(self.pages)

    @property
    def text(self) -> str:
        """全ページの本文（どこがページの切れ目か分かる形で連結する）。"""
        return "\n\n".join(f"--- p.{page.number} ---\n{page.text}".rstrip() for page in self.pages)

    @property
    def has_text_layer(self) -> bool:
        """文字が1ページでも入っているか（スキャン画像だけの PDF は False）。"""
        return any(page.has_text for page in self.pages)

    def page(self, number: int) -> Page | None:
        for page in self.pages:
            if page.number == number:
                return page
        return None

    def tables(self) -> list[tuple[int, list[list[str]]]]:
        """(ページ番号, 表) の一覧。表も出典つきで扱う。"""
        return [(page.number, table) for page in self.pages for table in page.tables]


def parse_pages(spec: str | None) -> list[int] | None:
    """"1-3,5" のような指定をページ番号の一覧にする。None は全ページ。"""
    if not spec or not spec.strip():
        return None

    numbers: list[int] = []
    for part in spec.split(","):
        match = RANGE_RE.match(part)
        if not match:
            raise ValueError(f"ページの指定が不正です: {part!r}（例: 1-3,5）")
        start = int(match.group(1))
        end = int(match.group(2) or start)
        if start < 1:
            raise ValueError(f"ページ番号は1から始まります: {part!r}")
        if end < start:
            raise ValueError(f"ページの範囲が逆です: {part!r}")
        numbers.extend(range(start, end + 1))

    # 重複を消しつつ、書かれた順ではなくページ順に読む
    return sorted(set(numbers))
