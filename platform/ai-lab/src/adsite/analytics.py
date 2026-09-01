"""広告レポートの取り込み。

AdSenseの管理画面から落としたCSVを食わせると、日次実績と収益が台帳に入る。
以降 `adsite report` がRPM・CTR・損益分岐PVを実測から計算する。
"""

from __future__ import annotations

import csv
import io
from dataclasses import dataclass
from datetime import date, datetime

from .ledger import record_revenue
from .models import AdDaily
from .storage import Storage

# AdSenseのCSVは言語設定や単位表記で列名が変わるため、別名で吸収する。
_ALIASES = {
    "date": ("date", "日付", "day", "日"),
    "page": ("page", "page url", "ページ", "url", "ページ url"),
    "impressions": ("impressions", "ad impressions", "表示回数", "広告の表示回数", "インプレッション"),
    "clicks": ("clicks", "クリック数", "クリック"),
    "earnings": ("estimated earnings", "earnings", "推定収益額", "推定収益", "収益"),
    "pageviews": ("page views", "pageviews", "ページビュー", "ページビュー数"),
}


def _index(header: list[str]) -> dict[str, int]:
    """列名を項目名に対応づける。

    AdSenseは "Estimated earnings (USD)" のように単位を付けてくるので完全一致では
    拾えない。まず完全一致で確定させ、残りだけを前方一致で拾う。この順序がないと
    "page" が "Page views" を先取りして、ページURL列を見失う。
    """
    lowered = [h.strip().lower() for h in header]
    found: dict[str, int] = {}
    claimed: set[int] = set()

    for key, names in _ALIASES.items():
        for i, col in enumerate(lowered):
            if col in names and i not in claimed:
                found[key] = i
                claimed.add(i)
                break

    for key, names in _ALIASES.items():
        if key in found:
            continue
        for i, col in enumerate(lowered):
            if i in claimed:
                continue
            if any(col.startswith(name) for name in names):
                found[key] = i
                claimed.add(i)
                break
    return found


def _number(value: str) -> float:
    """通貨記号・桁区切り・空欄を吸収して数値にする。"""
    cleaned = "".join(ch for ch in (value or "") if ch.isdigit() or ch in ".-")
    try:
        return float(cleaned)
    except ValueError:
        return 0.0


def _parse_date(value: str) -> date:
    value = value.strip()
    for fmt in ("%Y-%m-%d", "%Y/%m/%d", "%m/%d/%Y", "%Y年%m月%d日"):
        try:
            return datetime.strptime(value, fmt).date()
        except ValueError:
            continue
    raise ValueError(value)


def parse_report(csv_text: str) -> tuple[list[AdDaily], list[str]]:
    """AdSenseのCSVを読む。壊れた行は落として理由を返す。"""
    reader = csv.reader(io.StringIO(csv_text.lstrip("﻿")))
    try:
        header = next(reader)
    except StopIteration:
        return [], ["CSVが空です"]

    idx = _index(header)
    missing = [k for k in ("date", "earnings") if k not in idx]
    if missing:
        return [], [f"必須列が見つかりません: {', '.join(missing)}（列名: {', '.join(header)}）"]

    rows: list[AdDaily] = []
    errors: list[str] = []
    for lineno, raw in enumerate(reader, start=2):
        if not raw or len(raw) <= idx["date"]:
            continue
        try:
            day = _parse_date(raw[idx["date"]])
        except ValueError:
            errors.append(f"{lineno}行目: 日付を解釈できません ({raw[idx['date']]!r})")
            continue
        get = lambda key: raw[idx[key]] if key in idx and idx[key] < len(raw) else ""  # noqa: E731
        rows.append(
            AdDaily(
                day=day,
                page=get("page").strip(),
                impressions=int(_number(get("impressions"))),
                clicks=int(_number(get("clicks"))),
                pageviews=int(_number(get("pageviews"))),
                earnings_usd=_number(get("earnings")),
            )
        )
    return rows, errors


def ingest(storage: Storage, rows: list[AdDaily], network: str = "adsense") -> tuple[int, float]:
    """日次実績を保存し、日ごとに集計した収益を台帳へ計上する。

    収益は上書き計上（replace）にしている。AdSenseの金額は推定値で、
    後日確定値に改定されるため、「最後に取り込んだ値が正」が実態に合う。
    実績テーブルも同じ理由で上書きする。
    """
    storage.save_ad_daily(rows)

    by_day: dict[date, float] = {}
    for row in rows:
        by_day[row.day] = by_day.get(row.day, 0.0) + row.earnings_usd

    days = 0
    total = 0.0
    for day, amount in sorted(by_day.items()):
        record_revenue(
            storage,
            category=f"ads:{network}",
            amount_usd=amount,
            ref=f"ads:{network}:{day.isoformat()}",
            note=f"{network} {day.isoformat()}",
            ts=datetime.combine(day, datetime.min.time()),
            replace=True,
        )
        days += 1
        total += amount
    return days, total


@dataclass
class AdStats:
    impressions: int
    clicks: int
    pageviews: int
    earnings_usd: float

    @property
    def ctr(self) -> float:
        return self.clicks / self.impressions if self.impressions else 0.0

    @property
    def rpm_usd(self) -> float:
        """1000表示あたり収益。ページビューがあればページRPMを優先する。"""
        base = self.pageviews or self.impressions
        return self.earnings_usd / base * 1000 if base else 0.0


def summarize_rows(rows: list[AdDaily]) -> AdStats:
    return AdStats(
        impressions=sum(r.impressions for r in rows),
        clicks=sum(r.clicks for r in rows),
        pageviews=sum(r.pageviews for r in rows),
        earnings_usd=sum(r.earnings_usd for r in rows),
    )


def top_pages(rows: list[AdDaily], limit: int = 10) -> list[tuple[str, float]]:
    totals: dict[str, float] = {}
    for row in rows:
        if row.page:
            totals[row.page] = totals.get(row.page, 0.0) + row.earnings_usd
    return sorted(totals.items(), key=lambda kv: -kv[1])[:limit]
