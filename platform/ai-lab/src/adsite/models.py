"""台帳と実績のデータ構造。永続化は :mod:`adsite.storage` が担当する。"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime


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
class AdDaily:
    """日×ページの広告実績。"""

    day: date
    page: str
    impressions: int = 0
    clicks: int = 0
    pageviews: int = 0
    earnings_usd: float = 0.0
