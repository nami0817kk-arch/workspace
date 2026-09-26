"""「週20時間の壁」の損得。2026年10月から、51人以上の会社では週20時間以上で社会保険に入る
（月収の条件は無くなる）。配偶者などの扶養に入っていて週19時間で働いている人が、週20時間に増やすと
手取りがどれだけ減るか、何時間まで増やせば週19時間のときの手取りを取り戻せるかを出す。

前提（画面にも書く）:
- 週19時間のときは社会保険にも雇用保険にも入らない（雇用保険も週20時間以上から）。所得税だけ引く
- 週20時間以上は社会保険・雇用保険に入る。所得税は扶養0人（扶養に入っている本人の立場）
- 月収 = 時給 × 週の時間 × 52週 ÷ 12か月（1円未満四捨五入）。通勤手当・残業代は無いものとする
- 配偶者の側の変化（配偶者手当・配偶者特別控除）は入れない。会社ごとに違うため
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import date

import extras
import premium

BEFORE_HOURS_X10 = 190  # 週19時間
MAX_HOURS_X10 = 400  # 週40時間まで探す


def monthly_pay(hourly_yen: int, hours_x10: int) -> int:
    """時給 × 週の時間 × 52 ÷ 12 を1円未満四捨五入。時間は10倍の整数で受ける（19.5時間 → 195）。"""
    return (hourly_yen * hours_x10 * 52 * 2 + 120) // 240


def net_uncovered(as_of: date, pay: int) -> int | None:
    tax = extras.income_tax_yen(as_of, pay, 0)
    return None if tax is None else pay - tax


def net_covered(as_of: date, pay: int, prefecture: str, age_40_to_64: bool) -> int | None:
    try:
        p = premium.estimate(as_of=as_of, prefecture=prefecture, monthly_pay_yen=pay, age_40_to_64=age_40_to_64)
    except premium.RatesOutOfRange:
        return None
    koyo = extras.employment_yen(as_of, pay)
    if koyo is None:
        return None
    tax = extras.income_tax_yen(as_of, pay - p.total_yen - koyo, 0)
    if tax is None:
        return None
    return pay - p.total_yen - koyo - tax


@dataclass(frozen=True)
class Kabe:
    hourly: int
    pay_19: int
    net_19: int
    pay_20: int
    net_20: int
    breakeven_hours_x10: int | None  # 週19時間の手取り以上に戻る最小の時間（0.5時間刻み）。40時間でも戻らなければ None
    breakeven_pay: int | None
    breakeven_net: int | None

    @property
    def loss_at_20(self) -> int:
        return self.net_19 - self.net_20


def analyze(as_of: date, hourly_yen: int, prefecture: str = "東京", age_40_to_64: bool = False) -> Kabe | None:
    pay_19 = monthly_pay(hourly_yen, BEFORE_HOURS_X10)
    net_19 = net_uncovered(as_of, pay_19)
    pay_20 = monthly_pay(hourly_yen, 200)
    net_20 = net_covered(as_of, pay_20, prefecture, age_40_to_64)
    if net_19 is None or net_20 is None:
        return None
    be_hours = be_pay = be_net = None
    for h in range(200, MAX_HOURS_X10 + 1, 5):
        pay = monthly_pay(hourly_yen, h)
        net = net_covered(as_of, pay, prefecture, age_40_to_64)
        if net is not None and net >= net_19:
            be_hours, be_pay, be_net = h, pay, net
            break
    return Kabe(hourly_yen, pay_19, net_19, pay_20, net_20, be_hours, be_pay, be_net)
