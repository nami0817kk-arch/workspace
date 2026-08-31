"""パイプライン上を流れるデータ構造。

すべて dataclass。永続化は :mod:`moneyloop.storage` が担当し、
このモジュールは DB を知らない（テストしやすくするため）。
"""

from __future__ import annotations

import hashlib
import re
from dataclasses import dataclass, field
from datetime import date, datetime
from typing import Any


def content_hash(title: str, url: str) -> str:
    """記事の同一性キー。URLのクエリ・末尾スラッシュ差と表記ゆれを吸収する。"""
    normalized_url = re.sub(r"[?#].*$", "", url.strip().lower()).rstrip("/")
    normalized_title = re.sub(r"\s+", " ", title.strip().lower())
    return hashlib.sha256(f"{normalized_url}|{normalized_title}".encode()).hexdigest()[:32]


@dataclass(frozen=True)
class Source:
    """ニッチごとの情報源（RSS/Atom）。"""

    name: str
    url: str


@dataclass(frozen=True)
class Niche:
    """1つの有料メディア枠。ニッチ単位で号・購読者・収支が分かれる。"""

    code: str
    name: str
    audience: str
    angle: str
    sources: tuple[Source, ...] = ()


@dataclass
class Item:
    """情報源から収集した1記事。"""

    niche: str
    source: str
    title: str
    url: str
    summary: str
    published_at: datetime | None = None
    fetched_at: datetime | None = None
    hash: str = ""

    def __post_init__(self) -> None:
        if not self.hash:
            self.hash = content_hash(self.title, self.url)


@dataclass
class ScoredItem:
    """LLMが付けた重要度スコア付きの記事。"""

    item: Item
    score: int
    why: str
    tags: tuple[str, ...] = ()


@dataclass
class Issue:
    """生成された1号分のコンテンツ。"""

    niche: str
    issue_date: date
    title: str
    teaser_md: str
    body_md: str
    takeaways: tuple[str, ...] = ()
    item_hashes: tuple[str, ...] = ()
    model: str = ""
    input_tokens: int = 0
    output_tokens: int = 0
    cost_usd: float = 0.0
    id: int | None = None

    @property
    def slug(self) -> str:
        return f"{self.issue_date.isoformat()}-{self.niche}"


@dataclass
class Subscriber:
    """購読者。plan が有料プランなら本文全体を受け取る。"""

    email: str
    niche: str
    plan: str = "free"
    status: str = "active"  # active | canceled
    started_at: date | None = None
    canceled_at: date | None = None
    id: int | None = None


@dataclass
class LedgerEntry:
    """収支1行。kind は 'cost' か 'revenue'。amount_usd は常に正の値。"""

    ts: datetime
    kind: str
    category: str
    amount_usd: float
    note: str = ""
    ref: str = ""
    id: int | None = None


@dataclass
class RunReport:
    """1回のパイプライン実行の結果サマリ。"""

    niche: str
    run_date: date
    collected: int = 0
    fresh: int = 0
    scored: int = 0
    selected: int = 0
    issue: Issue | None = None
    delivered_free: int = 0
    delivered_paid: int = 0
    cost_usd: float = 0.0
    skipped_reason: str = ""
    errors: list[str] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        return {
            "niche": self.niche,
            "run_date": self.run_date.isoformat(),
            "collected": self.collected,
            "fresh": self.fresh,
            "scored": self.scored,
            "selected": self.selected,
            "issue_title": self.issue.title if self.issue else None,
            "delivered_free": self.delivered_free,
            "delivered_paid": self.delivered_paid,
            "cost_usd": round(self.cost_usd, 6),
            "skipped_reason": self.skipped_reason,
            "errors": self.errors,
        }
