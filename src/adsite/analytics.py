"""広告収益の実測取り込みと、必要トラフィックの逆算。

AdSenseの管理画面からCSVを落として食わせると、moneyloopの台帳に計上される。
購読収益と同じPLに載るので、`moneyloop report` で合算して見られる。
"""

from __future__ import annotations

import csv
import io
from dataclasses import dataclass
from datetime import date, datetime

from moneyloop.ledger import record_revenue
from moneyloop.storage import Storage

# AdSenseのCSVは言語設定で列名が変わるため、別名で吸収する。
_ALIASES = {
    "date": ("date", "日付", "day", "日"),
    "page": ("page", "page url", "ページ", "url", "ページ url"),
    "impressions": ("impressions", "ad impressions", "表示回数", "広告の表示回数", "インプレッション"),
    "clicks": ("clicks", "クリック数", "クリック"),
    "earnings": ("estimated earnings", "earnings", "推定収益額", "推定収益", "収益"),
    "pageviews": ("page views", "pageviews", "ページビュー", "ページビュー数"),
}


@dataclass
class AdRow:
    day: date
    page: str
    impressions: int
    clicks: int
    earnings_usd: float
    pageviews: int = 0


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


def parse_report(csv_text: str) -> tuple[list[AdRow], list[str]]:
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

    rows: list[AdRow] = []
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
            AdRow(
                day=day,
                page=get("page").strip(),
                impressions=int(_number(get("impressions"))),
                clicks=int(_number(get("clicks"))),
                earnings_usd=_number(get("earnings")),
                pageviews=int(_number(get("pageviews"))),
            )
        )
    return rows, errors


def _parse_date(value: str) -> date:
    value = value.strip()
    for fmt in ("%Y-%m-%d", "%Y/%m/%d", "%m/%d/%Y", "%Y年%m月%d日"):
        try:
            return datetime.strptime(value, fmt).date()
        except ValueError:
            continue
    raise ValueError(value)


def record_ad_revenue(storage: Storage, rows: list[AdRow], network: str = "adsense") -> tuple[int, float]:
    """日次で集計して計上する。ref に日付を使うので再取り込みしても二重計上しない。"""
    by_day: dict[date, float] = {}
    for row in rows:
        by_day[row.day] = by_day.get(row.day, 0.0) + row.earnings_usd

    count = 0
    total = 0.0
    for day, amount in sorted(by_day.items()):
        if amount <= 0:
            continue
        if record_revenue(
            storage,
            category=f"ads:{network}",
            amount_usd=amount,
            ref=f"ads:{network}:{day.isoformat()}",
            note=f"{network} {day.isoformat()}",
            ts=datetime.combine(day, datetime.min.time()),
        ):
            count += 1
            total += amount
    return count, total


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


def summarize_rows(rows: list[AdRow]) -> AdStats:
    return AdStats(
        impressions=sum(r.impressions for r in rows),
        clicks=sum(r.clicks for r in rows),
        pageviews=sum(r.pageviews for r in rows),
        earnings_usd=sum(r.earnings_usd for r in rows),
    )


def top_pages(rows: list[AdRow], limit: int = 10) -> list[tuple[str, float]]:
    totals: dict[str, float] = {}
    for row in rows:
        if row.page:
            totals[row.page] = totals.get(row.page, 0.0) + row.earnings_usd
    return sorted(totals.items(), key=lambda kv: -kv[1])[:limit]


def pageviews_needed(target_monthly_usd: float, rpm_usd: float) -> int:
    """目標月間収益に必要な月間PV。広告が規模の商売であることがここで数字になる。"""
    if rpm_usd <= 0:
        return 0
    return int(round(target_monthly_usd / rpm_usd * 1000))
