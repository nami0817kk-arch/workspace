"""社会保険（健康保険・厚生年金）の短時間労働者への適用拡大 — 加入判定ロジック。

出典: 厚生労働省 社会保険適用拡大特設サイト
https://www.mhlw.go.jp/tekiyoukakudai/jugyouin/taisho/
（企画書 https://claude.ai/artifact/JvCm7MmGbxE1y7gz9jEgcH に転記済みの年次表と同じ数字）

**この表は法定の日程なので、料率のように毎年書き換える必要はない。**
ただし国会で日程そのものが変わることはありうるので、変わったら SCHEDULE を直す。

短時間労働者が「特定適用事業所」で加入対象になる要件（以下をすべて満たす）:

1. 週の所定労働時間が20時間以上
2. 賃金要件（月額8.8万円以上）— **2026年10月に撤廃**
3. 学生でないこと（夜間部・定時制課程・休学中の学生は、この除外の対象外
   というのが一般的な取り扱い。最終確認は日本年金機構へ）
4. 勤務先の従業員数（厚生年金保険の被保険者数）が、その時点の
   企業規模要件を満たすこと（満たさない場合でも、労使合意があれば
   任意に適用対象にできる制度がある）
5. 継続して2か月を超える雇用が見込まれること

このモジュールが判定するのは 1〜4 のみ。**5は入力項目にしていない**
（通常の継続雇用なら満たすため）。画面側で必ず注記を添える。

**断定はしない。** ここで返すのは公表されている基準に照らした結果であって、
複数事業所での勤務や特殊な雇用形態などの個別の事情は年金事務所・
社会保険労務士への確認が要る。
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import date

WEEKLY_HOURS_REQUIREMENT = 20
_WAGE_REQUIREMENT_YEN = 88_000  # 2026年10月に撤廃されるまでの賃金要件（月額）


@dataclass(frozen=True)
class Regime:
    """ある時点で適用される要件の組み合わせ。"""

    effective_from: date
    company_size_threshold: int | None  # None = 企業規模を問わない（撤廃後）
    wage_requirement_yen: int | None  # None = 賃金要件なし（撤廃後）
    label: str


# 企業規模要件・賃金要件が変わる各段階。古い順に並べる。
# 2024年10月時点の「51人以上」を起点とする。それより前は本計算機の対象外
# （古い段階を調べたい人はほぼいないので、範囲を広げるコストに見合わない）。
SCHEDULE: tuple[Regime, ...] = (
    Regime(
        date(2024, 10, 1), 51, _WAGE_REQUIREMENT_YEN,
        "2024年10月〜：従業員51人以上・賃金月額8.8万円以上（現行）",
    ),
    Regime(
        date(2026, 10, 1), 51, None,
        "2026年10月〜：賃金要件を撤廃。企業規模要件（51人以上）はそのまま",
    ),
    Regime(
        date(2027, 10, 1), 36, None,
        "2027年10月〜：企業規模要件が「従業員36人以上」に拡大",
    ),
    Regime(
        date(2029, 10, 1), 21, None,
        "2029年10月〜：企業規模要件が「従業員21人以上」に拡大",
    ),
    Regime(
        date(2032, 10, 1), 11, None,
        "2032年10月〜：企業規模要件が「従業員11人以上」に拡大",
    ),
    Regime(
        date(2035, 10, 1), None, None,
        "2035年10月〜：企業規模要件を撤廃（すべての事業所が対象）",
    ),
)

# サイトの「年次別の解説」ページはこの5件（2026年10月以降の変化点）。
# 2024年10月分（起点）は「現行」として比較表にだけ出す。
MILESTONES: tuple[Regime, ...] = SCHEDULE[1:]


class ScheduleOutOfRange(Exception):
    """SCHEDULE がまだ覆っていない日付を判定しようとした。"""


def regime_for(as_of: date) -> Regime:
    """as_of 時点で適用される要件を返す。範囲外の日付は例外にする
    （market_calendar.CalendarOutOfRange と同じ考え方。黙って現行扱いにしない）。
    """
    if as_of < SCHEDULE[0].effective_from:
        raise ScheduleOutOfRange(
            f"{as_of} は {SCHEDULE[0].effective_from} より前です。"
            "この計算機は2024年10月以降を対象にしています。"
        )
    applicable = SCHEDULE[0]
    for regime in SCHEDULE:
        if regime.effective_from <= as_of:
            applicable = regime
        else:
            break
    return applicable


@dataclass(frozen=True)
class EligibilityResult:
    as_of: date
    regime: Regime
    hours_ok: bool
    wage_ok: bool
    not_student_ok: bool
    employer_size_ok: bool

    @property
    def eligible(self) -> bool:
        return self.hours_ok and self.wage_ok and self.not_student_ok and self.employer_size_ok


def evaluate(
    *,
    as_of: date,
    weekly_hours: float,
    monthly_wage_yen: int,
    is_student: bool,
    employer_size: int,
) -> EligibilityResult:
    """短時間労働者としての加入対象かどうかを判定する。"""
    regime = regime_for(as_of)
    hours_ok = weekly_hours >= WEEKLY_HOURS_REQUIREMENT
    wage_ok = (
        regime.wage_requirement_yen is None
        or monthly_wage_yen >= regime.wage_requirement_yen
    )
    not_student_ok = not is_student
    employer_size_ok = (
        regime.company_size_threshold is None
        or employer_size >= regime.company_size_threshold
    )
    return EligibilityResult(
        as_of=as_of,
        regime=regime,
        hours_ok=hours_ok,
        wage_ok=wage_ok,
        not_student_ok=not_student_ok,
        employer_size_ok=employer_size_ok,
    )
