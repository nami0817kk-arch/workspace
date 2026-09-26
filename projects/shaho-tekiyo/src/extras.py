"""社会保険料のほかに、手取りと損得を考えるのに要る数字（雇用保険料・国民年金保険料・将来の年金の増え方）。

率の正は `data/other_rates.json`（出典付き）。premium.py と同じく、収録していない時点は
黙って計算せず None を返す（画面側で「まだ公表されていない」と出す）。

- 雇用保険料: 総支給額（通勤手当も含む）× 労働者負担の率。端数は天引きのとき50銭以下切り捨て
  （社会保険料と同じ扱い）。雇用保険は週20時間以上で入るので、社会保険に入る前から引かれている人が多い
- 国民年金保険料: 自分で国民年金を払っていた人（第1号被保険者）が、厚生年金に入ると払わなくてよくなる額
- 将来の年金: 老齢厚生年金の報酬比例部分 = 標準報酬月額 × 5.481/1000 × 加入月数（平成15年4月以降の期間）。
  再評価率は考えない、今の価値での目安。65歳から一生受け取る額が、1年加入するごとにこれだけ増える
"""
from __future__ import annotations

import json
from datetime import date
from fractions import Fraction
from pathlib import Path

from premium import payroll_round

_RAW = json.loads((Path(__file__).resolve().parent.parent / "data" / "other_rates.json").read_text(encoding="utf-8"))
RATES: dict = _RAW


def _period(entries: list[dict], as_of: date) -> dict | None:
    for e in entries:
        if date.fromisoformat(e["valid_from"]) <= as_of <= date.fromisoformat(e["valid_until"]):
            return e
    return None


def employment_yen(as_of: date, gross_pay_yen: int) -> int | None:
    e = _period(RATES["employment"], as_of)
    if e is None:
        return None
    return payroll_round(Fraction(gross_pay_yen * e["worker_per_mille"], 1000))


def kokumin_nenkin_yen(as_of: date) -> int | None:
    e = _period(RATES["kokumin_nenkin"], as_of)
    return None if e is None else e["monthly_yen"]


def pension_increase_per_year(pension_standard_yen: int) -> int:
    """1年（12か月）加入したときに増える老齢厚生年金（年額、円未満切り捨て）。"""
    per = RATES["pension_accrual"]["per_mille_x1000"]
    return pension_standard_yen * per * 12 // 1_000_000


def sickness_daily_yen(health_standard_yen: int) -> int:
    """傷病手当金の1日あたりの額（協会けんぽ）。標準報酬月額÷30 を10円未満四捨五入し、2/3 を1円未満四捨五入。
    加入から12か月たつ前は、加入後の平均と全被保険者の平均の低いほうで計算されるが、ここでは標準報酬月額そのままで出す。"""
    per_day = (health_standard_yen + 150) // 300 * 10
    return (4 * per_day + 3) // 6


# 協会けんぽの額表は「東京」「大阪」のように短い名前。画面では正式な名前で出す。
def pref_full(short: str) -> str:
    if short == "北海道":
        return short
    if short == "東京":
        return "東京都"
    if short in ("京都", "大阪"):
        return short + "府"
    return short + "県"


def extras_json() -> str:
    return json.dumps(RATES, ensure_ascii=False, separators=(",", ":"))


def _band(rows: list, amount: int) -> list:
    for r in rows:
        lo, hi = r[0], r[1]
        if amount >= lo and (hi is None or amount <= hi):
            return r
    raise ValueError(amount)


def income_tax_yen(as_of: date, after_social_yen: int, dependents: int = 0) -> int | None:
    """月々の給与から天引きされる所得税（源泉徴収税額）の目安。国税庁「電算機計算の特例」（月額表・甲欄）の式どおり。

    after_social_yen: その月の社会保険料等控除後の給与等の金額（課税される給与 − 社会保険料 − 雇用保険料。通勤手当は含めない）
    dependents: 源泉控除対象配偶者と源泉控除対象親族の数（1人につき31,667円を控除）
    税額表（月額表）の額とは数十円ずれることがある（特例の注記どおり。差は年末調整で精算される）。
    """
    w = _period(RATES["withholding"], as_of)
    if w is None:
        return None
    a = max(after_social_yen, 0)
    _, _, rate, const = _band(w["employment_deduction"], a)
    kyuyo = -(-a * rate // 100_000) + const  # 1円未満切り上げ
    basic = _band(w["basic_deduction"], a)[2]
    b = a - kyuyo - w["dependent_deduction"] * dependents - basic
    if b <= 0:
        return 0
    _, _, rate, const = _band(w["rates"], b)
    num = b * rate - const * 100_000  # 単位: 1/100000 円
    if num <= 0:
        return 0
    return (num + 500_000) // 1_000_000 * 10  # 10円未満四捨五入
