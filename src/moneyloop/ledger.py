"""収支台帳とユニットエコノミクス。

この仕組みの価値は「自動で記事が出ること」ではなく
「1号あたりの原価と、損益分岐に必要な購読者数が常に見えていること」にある。
"""

from __future__ import annotations

import calendar
from dataclasses import dataclass
from datetime import date, datetime

from .config import Config
from .models import LedgerEntry
from .storage import Storage


def record_cost(
    storage: Storage, *, category: str, amount_usd: float, ref: str, note: str = "", ts: datetime | None = None
) -> bool:
    """API原価などの支出を計上する。ref が同一なら再計上されない（冪等）。"""
    if not ref:
        raise ValueError("冪等性のため ref は必須です")
    return storage.add_ledger(
        LedgerEntry(ts=ts or datetime.now(), kind="cost", category=category, amount_usd=abs(amount_usd), note=note, ref=ref)
    )


def record_revenue(
    storage: Storage, *, category: str, amount_usd: float, ref: str, note: str = "", ts: datetime | None = None
) -> bool:
    if not ref:
        raise ValueError("冪等性のため ref は必須です")
    return storage.add_ledger(
        LedgerEntry(ts=ts or datetime.now(), kind="revenue", category=category, amount_usd=abs(amount_usd), note=note, ref=ref)
    )


def accrue_subscriptions(storage: Storage, config: Config, on: date | None = None) -> tuple[int, float]:
    """当月分の購読収益を計上する。

    ref に「購読者×ニッチ×年月」を入れているので、月内に何度実行しても
    二重計上にならない。実決済はStripe等が持ち、ここは会計上の発生ベース。
    """
    on = on or date.today()
    period = on.strftime("%Y-%m")
    plans = {p.code: p for p in config.plans}
    count = 0
    total = 0.0

    for niche in config.niches:
        for sub in storage.subscribers(niche.code, status="active"):
            plan = plans.get(sub.plan)
            if plan is None or plan.monthly_usd <= 0:
                continue
            # 当月に開始した購読も満額計上する（日割りは決済側の責務）。
            if sub.started_at and sub.started_at > on:
                continue
            ref = f"sub:{sub.email}:{niche.code}:{period}"
            if record_revenue(
                storage,
                category=f"subscription:{plan.code}",
                amount_usd=plan.monthly_usd,
                ref=ref,
                note=f"{niche.code} / {plan.name}",
                ts=datetime.combine(on, datetime.min.time()),
            ):
                count += 1
                total += plan.monthly_usd
    return count, total


@dataclass
class Economics:
    """指定期間のPLとユニットエコノミクス。金額はすべてUSD。"""

    since: date
    until: date
    revenue_usd: float
    cost_usd: float
    issues: int
    paying_subscribers: int
    free_subscribers: int
    paid_plan_price_usd: float
    usd_jpy: float

    @property
    def gross_profit_usd(self) -> float:
        return self.revenue_usd - self.cost_usd

    @property
    def gross_margin(self) -> float:
        return self.gross_profit_usd / self.revenue_usd if self.revenue_usd else 0.0

    @property
    def cost_per_issue_usd(self) -> float:
        return self.cost_usd / self.issues if self.issues else 0.0

    @property
    def cost_per_subscriber_usd(self) -> float:
        total = self.paying_subscribers + self.free_subscribers
        return self.cost_usd / total if total else 0.0

    @property
    def arpu_usd(self) -> float:
        total = self.paying_subscribers + self.free_subscribers
        return self.revenue_usd / total if total else 0.0

    @property
    def conversion_rate(self) -> float:
        total = self.paying_subscribers + self.free_subscribers
        return self.paying_subscribers / total if total else 0.0

    @property
    def breakeven_subscribers(self) -> int:
        """原価を賄うのに必要な有料購読者数（切り上げ）。"""
        price_milli = int(round(self.paid_plan_price_usd * 1000))
        if price_milli <= 0:
            return 0
        return -(-int(round(self.cost_usd * 1000)) // price_milli)

    def to_dict(self) -> dict[str, object]:
        return {
            "period": f"{self.since.isoformat()}..{self.until.isoformat()}",
            "revenue_usd": round(self.revenue_usd, 2),
            "cost_usd": round(self.cost_usd, 4),
            "gross_profit_usd": round(self.gross_profit_usd, 2),
            "gross_margin": round(self.gross_margin, 4),
            "issues": self.issues,
            "cost_per_issue_usd": round(self.cost_per_issue_usd, 4),
            "paying_subscribers": self.paying_subscribers,
            "free_subscribers": self.free_subscribers,
            "conversion_rate": round(self.conversion_rate, 4),
            "arpu_usd": round(self.arpu_usd, 4),
            "breakeven_subscribers": self.breakeven_subscribers,
            "gross_profit_jpy": round(self.gross_profit_usd * self.usd_jpy),
        }


def month_range(on: date) -> tuple[date, date]:
    last = calendar.monthrange(on.year, on.month)[1]
    return date(on.year, on.month, 1), date(on.year, on.month, last)


def summarize(storage: Storage, config: Config, since: date | None = None, until: date | None = None) -> Economics:
    """期間のPLを集計する。期間省略時は当月。"""
    if since is None or until is None:
        since, until = month_range(date.today())

    entries = storage.ledger_entries(since=since, until=until)
    revenue = sum(e.amount_usd for e in entries if e.kind == "revenue")
    cost = sum(e.amount_usd for e in entries if e.kind == "cost")

    plans = {p.code: p for p in config.plans}
    paying = free = 0
    for niche in config.niches:
        for sub in storage.subscribers(niche.code, status="active"):
            plan = plans.get(sub.plan)
            if plan and plan.monthly_usd > 0:
                paying += 1
            else:
                free += 1

    # 損益分岐は最安の有料プランで測る。上位プランで割ると必要人数を過小評価するため。
    paid_price = min((p.monthly_usd for p in config.plans if p.paywalled and p.monthly_usd > 0), default=0.0)

    return Economics(
        since=since,
        until=until,
        revenue_usd=revenue,
        cost_usd=cost,
        issues=storage.count_issues(since=since, until=until),
        paying_subscribers=paying,
        free_subscribers=free,
        paid_plan_price_usd=paid_price,
        usd_jpy=config.usd_jpy,
    )
