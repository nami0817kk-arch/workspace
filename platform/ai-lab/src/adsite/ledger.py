"""収支台帳とユニットエコノミクス。

広告は規模の商売なので、見るべき数字は「いくら儲かったか」ではなく
**PVあたりいくらか(RPM)** と **原価を賄うのに必要なPV** になる。
"""

from __future__ import annotations

import calendar
from dataclasses import dataclass
from datetime import date, datetime

from .models import LedgerEntry
from .storage import Storage


def record_cost(
    storage: Storage,
    *,
    category: str,
    amount_usd: float,
    ref: str,
    note: str = "",
    ts: datetime | None = None,
) -> bool:
    """支出を計上する。ref が同一なら再計上されない（冪等）。"""
    return storage.add_ledger(
        LedgerEntry(
            ts=ts or datetime.now(),
            kind="cost",
            category=category,
            amount_usd=abs(amount_usd),
            note=note,
            ref=ref,
        )
    )


def record_revenue(
    storage: Storage,
    *,
    category: str,
    amount_usd: float,
    ref: str,
    note: str = "",
    ts: datetime | None = None,
    replace: bool = False,
) -> bool:
    """収益を計上する。

    広告収益は推定値が後日改定されるため、取り込み側は replace=True を使う。
    """
    return storage.add_ledger(
        LedgerEntry(
            ts=ts or datetime.now(),
            kind="revenue",
            category=category,
            amount_usd=abs(amount_usd),
            note=note,
            ref=ref,
        ),
        replace=replace,
    )


def record_monthly_fixed_cost(
    storage: Storage, *, category: str, amount_usd: float, on: date, note: str = ""
) -> bool:
    """ドメイン代・配信サービス等の固定費を月次で計上する。

    ref に年月を含めるので、同じ月に何度実行しても1回しか計上されない。
    """
    return record_cost(
        storage,
        category=category,
        amount_usd=amount_usd,
        ref=f"fixed:{category}:{on.strftime('%Y-%m')}",
        note=note or f"{category} {on.strftime('%Y-%m')}",
        ts=datetime.combine(on.replace(day=1), datetime.min.time()),
    )


@dataclass
class Economics:
    """指定期間のPLとユニットエコノミクス。金額はすべてUSD。"""

    since: date
    until: date
    revenue_usd: float
    cost_usd: float
    pageviews: int
    impressions: int
    clicks: int
    usd_jpy: float

    @property
    def profit_usd(self) -> float:
        return self.revenue_usd - self.cost_usd

    @property
    def margin(self) -> float:
        return self.profit_usd / self.revenue_usd if self.revenue_usd else 0.0

    @property
    def rpm_usd(self) -> float:
        """1000PVあたり収益。PVが未取得ならインプレッション基準に落とす。"""
        base = self.pageviews or self.impressions
        return self.revenue_usd / base * 1000 if base else 0.0

    @property
    def ctr(self) -> float:
        return self.clicks / self.impressions if self.impressions else 0.0

    @property
    def breakeven_pageviews(self) -> int:
        """原価を賄うのに必要な月間PV。RPMの実測がなければ0を返す。"""
        if self.rpm_usd <= 0:
            return 0
        return int(round(self.cost_usd / self.rpm_usd * 1000))

    def to_dict(self) -> dict[str, object]:
        return {
            "period": f"{self.since.isoformat()}..{self.until.isoformat()}",
            "revenue_usd": round(self.revenue_usd, 2),
            "cost_usd": round(self.cost_usd, 4),
            "profit_usd": round(self.profit_usd, 2),
            "margin": round(self.margin, 4),
            "pageviews": self.pageviews,
            "impressions": self.impressions,
            "clicks": self.clicks,
            "ctr": round(self.ctr, 4),
            "rpm_usd": round(self.rpm_usd, 4),
            "breakeven_pageviews": self.breakeven_pageviews,
            "profit_jpy": round(self.profit_usd * self.usd_jpy),
        }


def month_range(on: date) -> tuple[date, date]:
    last = calendar.monthrange(on.year, on.month)[1]
    return date(on.year, on.month, 1), date(on.year, on.month, last)


def summarize(
    storage: Storage, *, usd_jpy: float = 150.0, since: date | None = None, until: date | None = None
) -> Economics:
    """期間のPLを集計する。期間省略時は当月。"""
    if since is None or until is None:
        since, until = month_range(date.today())

    entries = storage.ledger_entries(since=since, until=until)
    daily = storage.ad_daily(since=since, until=until)

    return Economics(
        since=since,
        until=until,
        revenue_usd=sum(e.amount_usd for e in entries if e.kind == "revenue"),
        cost_usd=sum(e.amount_usd for e in entries if e.kind == "cost"),
        pageviews=sum(r.pageviews for r in daily),
        impressions=sum(r.impressions for r in daily),
        clicks=sum(r.clicks for r in daily),
        usd_jpy=usd_jpy,
    )


def pageviews_needed(target_monthly_usd: float, rpm_usd: float) -> int:
    """目標月間収益に必要な月間PV。広告が規模の商売であることがここで数字になる。"""
    if rpm_usd <= 0:
        return 0
    return int(round(target_monthly_usd / rpm_usd * 1000))
