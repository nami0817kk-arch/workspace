"""社会保険に入ったとき、給与から引かれる保険料（本人負担分）の目安を出す。

料率の正は `data/kyoukaikenpo_<年度>.json`（`tools/import_kyoukaikenpo.py` が
協会けんぽの保険料額表から作り、額表の全等級と照合してある）。ここで数字を書き写さない。

**料率は毎年3月分から改定される。** 収録していない時点を聞かれたら、手元の最新の料率で
黙って計算せず `RatesOutOfRange` にする（`eligibility.ScheduleOutOfRange` と同じ考え方）。
新しい年度の額表が出たら `tools/import_kyoukaikenpo.py` を回し、`RATE_FILES` に1行足す。

計算の中身（協会けんぽの保険料額表の注記どおり）:

- 報酬月額（通勤手当・残業代の見込みも含む）から標準報酬月額の等級を引く。
  健康保険は50等級、厚生年金は32等級で、下限・上限が違う
- 本人負担 = 標準報酬月額 × 料率 ÷ 2（労使折半）
- 給与から天引きするときの端数は **50銭以下切り捨て、50銭を超えたら切り上げ**
- 40〜64歳（介護保険第2号被保険者）は介護保険料率が加わる
- 子ども・子育て支援金（令和8年4月分から）は健康保険料と一緒に納める

**対象は協会けんぽに入っている会社だけ。** 健康保険組合の会社は料率が組合ごとに違う。
画面側で必ずそう断る。所得税・住民税・雇用保険料の変化はここでは計算しない。
"""
from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import date
from fractions import Fraction
from pathlib import Path

_DATA_DIR = Path(__file__).resolve().parent.parent / "data"

# 収録している料率ファイル。古い年度も消さない（過去の時点を選んだ人に、その時点の率で答える）。
RATE_FILES: tuple[str, ...] = ("kyoukaikenpo_2026.json",)

_UNIT = 100_000  # 料率は 1/100000 単位の整数（10.28% → 10280）


class RatesOutOfRange(Exception):
    """収録している料率がまだ覆っていない時点の保険料を計算しようとした。"""


@dataclass(frozen=True)
class RateTable:
    fiscal_year: int
    valid_from: date
    valid_until: date
    source: dict
    health_grades: tuple[tuple[int, int, int], ...]  # (等級, 標準報酬月額, 報酬月額の下限)
    pension_grades: tuple[tuple[int, int, int], ...]
    prefectures: dict[str, dict[str, int]]


def _load(name: str) -> RateTable:
    raw = json.loads((_DATA_DIR / name).read_text(encoding="utf-8"))
    return RateTable(
        fiscal_year=raw["fiscal_year"],
        valid_from=date.fromisoformat(raw["valid_from"]),
        valid_until=date.fromisoformat(raw["valid_until"]),
        source=raw["source"],
        health_grades=tuple(tuple(g) for g in raw["health_grades"]),
        pension_grades=tuple(tuple(g) for g in raw["pension_grades"]),
        prefectures=raw["prefectures"],
    )


TABLES: tuple[RateTable, ...] = tuple(sorted((_load(n) for n in RATE_FILES), key=lambda t: t.valid_from))

# 都道府県の並び（北海道→沖縄）。額表のシート順のまま。
PREFECTURES: tuple[str, ...] = tuple(TABLES[-1].prefectures)


def table_for(as_of: date) -> RateTable:
    for t in TABLES:
        if t.valid_from <= as_of <= t.valid_until:
            return t
    raise RatesOutOfRange(
        f"{as_of} 時点の保険料率は収録していません"
        f"（収録範囲: {TABLES[0].valid_from}〜{TABLES[-1].valid_until}）。"
    )


def standard_monthly(grades: tuple[tuple[int, int, int], ...], monthly_pay_yen: int) -> tuple[int, int]:
    """報酬月額から (等級, 標準報酬月額) を引く。"""
    applicable = grades[0]
    for g in grades:
        if monthly_pay_yen >= g[2]:
            applicable = g
        else:
            break
    return applicable[0], applicable[1]


def payroll_round(amount: Fraction) -> int:
    """給与から天引きするときの端数処理。50銭以下は切り捨て、50銭を超えたら切り上げ。"""
    whole = amount.numerator // amount.denominator
    return whole + (1 if amount - whole > Fraction(1, 2) else 0)


def _employee_share(standard: int, units: int) -> int:
    return payroll_round(Fraction(standard * units, 2 * _UNIT))


@dataclass(frozen=True)
class PremiumResult:
    table: RateTable
    prefecture: str
    monthly_pay_yen: int
    health_grade: int
    health_standard: int
    pension_grade: int
    pension_standard: int
    health_yen: int  # 健康保険料（40〜64歳は介護保険料込み）
    kodomo_yen: int  # 子ども・子育て支援金
    pension_yen: int  # 厚生年金保険料
    includes_care: bool

    @property
    def total_yen(self) -> int:
        return self.health_yen + self.kodomo_yen + self.pension_yen

    @property
    def take_home_yen(self) -> int:
        """報酬月額から社会保険料だけを引いた額（税・雇用保険は引いていない）。"""
        return self.monthly_pay_yen - self.total_yen


def estimate(*, as_of: date, prefecture: str, monthly_pay_yen: int, age_40_to_64: bool) -> PremiumResult:
    table = table_for(as_of)
    if prefecture not in table.prefectures:
        raise KeyError(f"{prefecture} は料率表にありません")
    rates = table.prefectures[prefecture]
    health_grade, health_standard = standard_monthly(table.health_grades, monthly_pay_yen)
    pension_grade, pension_standard = standard_monthly(table.pension_grades, monthly_pay_yen)
    health_units = rates["health"] + (rates["care"] if age_40_to_64 else 0)
    return PremiumResult(
        table=table,
        prefecture=prefecture,
        monthly_pay_yen=monthly_pay_yen,
        health_grade=health_grade,
        health_standard=health_standard,
        pension_grade=pension_grade,
        pension_standard=pension_standard,
        health_yen=_employee_share(health_standard, health_units),
        kodomo_yen=_employee_share(health_standard, rates["kodomo"]),
        pension_yen=_employee_share(pension_standard, rates["pension"]),
        includes_care=age_40_to_64,
    )


def tables_json() -> str:
    """計算機（ブラウザ側 JS）に渡す料率。data/ の JSON をそのまま並べるだけ。"""
    return json.dumps(
        [json.loads((_DATA_DIR / n).read_text(encoding="utf-8")) for n in RATE_FILES],
        ensure_ascii=False,
        separators=(",", ":"),
    )
