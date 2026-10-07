"""ブラウザで動く static/calc.js が、Python 側（eligibility.py・premium.py）と同じ答えを返すか。

画面に出る数字は JS が計算する。Python 側だけテストしても、JS の写し間違いは素通りする。
入力の組み合わせを総当たりで node に渡し、1件でも食い違えば落とす。
node が無い環境では飛ばす（GitHub Actions の ubuntu-latest には入っている）。
"""
import json
import shutil
import subprocess
from datetime import date
from pathlib import Path

import pytest

import eligibility
import extras
import premium
import render

_CALC_JS = Path(__file__).resolve().parents[1] / "static" / "calc.js"

pytestmark = pytest.mark.skipif(shutil.which("node") is None, reason="node が無い")

_DATES = ["2025-01-01", "2026-09-30", "2026-10-01", "2027-02-28", "2027-03-01", "2027-10-01", "2035-10-01"]
_PAYS = [0, 50_000, 62_999, 63_000, 88_000, 92_999, 93_000, 104_000, 126_000, 150_000, 300_000, 700_000, 2_000_000]


def _run_node(cases: list[dict]) -> list:
    script = f"""
const calc = require({json.dumps(str(_CALC_JS))});
const schedule = {render.schedule_json()};
const tables = {premium.tables_json()};
const cases = JSON.parse(require('fs').readFileSync(0, 'utf8'));
const out = cases.map(c => c.kind === 'elig'
  ? (r => r && {{eligible: r.eligible, hours: r.hoursOk, wage: r.wageOk, student: r.notStudentOk, size: r.employerSizeOk}})(
      calc.evaluate(schedule, {eligibility.WEEKLY_HOURS_REQUIREMENT}, c.as_of, c.hours, c.wage, c.student, c.size))
  : c.kind === 'bonus'
  ? (r => r && [r.standard, r.health, r.kodomo, r.pension, r.total])(
      calc.bonusEstimate(tables, c.as_of, c.pref, c.bonus, c.care))
  : (r => r && [r.health, r.kodomo, r.pension, r.total, r.takeHome])(
      calc.estimate(tables, c.as_of, c.pref, c.pay, c.care)));
process.stdout.write(JSON.stringify(out));
"""
    res = subprocess.run(
        ["node", "-e", script], input=json.dumps(cases), capture_output=True, text=True, encoding="utf-8", check=True
    )
    return json.loads(res.stdout)


def test_加入判定がpythonと一致する():
    cases, expected = [], []
    for d in _DATES:
        for hours in (19.5, 20, 30):
            for wage in (87_999, 88_000, 60_000):
                for student in (False, True):
                    for size in (10, 11, 20, 21, 35, 36, 50, 51):
                        cases.append({"kind": "elig", "as_of": d, "hours": hours, "wage": wage, "student": student, "size": size})
                        r = eligibility.evaluate(
                            as_of=date.fromisoformat(d), weekly_hours=hours, monthly_wage_yen=wage,
                            is_student=student, employer_size=size,
                        )
                        expected.append({"eligible": r.eligible, "hours": r.hours_ok, "wage": r.wage_ok,
                                         "student": r.not_student_ok, "size": r.employer_size_ok})
    assert _run_node(cases) == expected


def test_保険料がpythonと一致する():
    cases, expected = [], []
    for d in ("2026-04-01", "2026-10-01", "2027-02-28", "2027-03-01", "2026-03-31"):
        for pref in premium.PREFECTURES:
            for pay in _PAYS:
                for care in (False, True):
                    cases.append({"kind": "premium", "as_of": d, "pref": pref, "pay": pay, "care": care})
                    try:
                        r = premium.estimate(as_of=date.fromisoformat(d), prefecture=pref, monthly_pay_yen=pay, age_40_to_64=care)
                        expected.append([r.health_yen, r.kodomo_yen, r.pension_yen, r.total_yen, r.take_home_yen])
                    except premium.RatesOutOfRange:
                        expected.append(None)
    got = _run_node(cases)
    mismatches = [(c, g, e) for c, g, e in zip(cases, got, expected) if g != e]
    assert not mismatches, mismatches[:5]


# 所得税の突き合わせ: 区切りの前後（給与所得控除・基礎控除・税率の境目）を含めて広く。
TAX_CASES = [[a, d] for a in (0, 50_000, 100_000, 158_333, 158_334, 170_620, 299_999, 300_000, 549_999, 550_000,
                              708_330, 708_331, 900_000, 2_120_833, 2_120_834, 2_300_000, 5_000_000) for d in (0, 1, 3)]


def test_雇用保険料_年金_傷病手当金_県名もpythonと一致する():
    pays = [0, 88_000, 100_000, 100_100, 100_101, 153_333, 250_000]
    standards = [58_000, 88_000, 98_000, 170_000, 650_000, 1_390_000]
    script = f"""
const calc = require({json.dumps(str(_CALC_JS))});
const ex = {extras.extras_json()};
const out = {{
  koyo: {json.dumps(pays)}.map(p => calc.employmentYen(ex, '2026-10-01', p)),
  koyoOut: calc.employmentYen(ex, '2027-04-01', 100000),
  kokumin: calc.kokuminNenkinYen(ex, '2026-10-01'),
  inc: {json.dumps(standards)}.map(s => calc.pensionIncreasePerYear(ex, s)),
  sick: {json.dumps(standards)}.map(s => calc.sicknessDailyYen(s)),
  pref: {json.dumps(list(premium.PREFECTURES), ensure_ascii=False)}.map(calc.prefFull),
  tax: {json.dumps(TAX_CASES)}.map(c => calc.incomeTaxYen(ex, '2026-10-01', c[0], c[1])),
  tax27: {json.dumps(TAX_CASES + [[169_444, 0], [169_445, 0], [177_000, 2], [775_200, 3]])}.map(c => calc.incomeTaxYen(ex, '2027-01-01', c[0], c[1])),
  taxOut: calc.incomeTaxYen(ex, '2028-01-01', 200000, 0),
}};
process.stdout.write(JSON.stringify(out));
"""
    res = subprocess.run(["node", "-e", script], capture_output=True, text=True, encoding="utf-8", check=True)
    got = json.loads(res.stdout)
    assert got["koyo"] == [extras.employment_yen(date(2026, 10, 1), p) for p in pays]
    assert got["koyoOut"] is None
    assert got["kokumin"] == extras.kokumin_nenkin_yen(date(2026, 10, 1))
    assert got["inc"] == [extras.pension_increase_per_year(s) for s in standards]
    assert got["sick"] == [extras.sickness_daily_yen(s) for s in standards]
    assert got["pref"] == [extras.pref_full(p) for p in premium.PREFECTURES]
    assert got["tax"] == [extras.income_tax_yen(date(2026, 10, 1), a, d) for a, d in TAX_CASES]
    assert got["tax27"] == [extras.income_tax_yen(date(2027, 1, 1), a, d) for a, d in TAX_CASES + [[169_444, 0], [169_445, 0], [177_000, 2], [775_200, 3]]]
    assert got["taxOut"] is None


def test_週20時間の壁もpythonと一致する():
    import kabe

    cases = [(h, pref, age) for h in (1016, 1050, 1100, 1226, 1300, 1500) for pref in ("東京", "佐賀", "北海道") for age in (False, True)]
    script = f"""
const calc = require({json.dumps(str(_CALC_JS))});
const tables = {premium.tables_json()};
const ex = {extras.extras_json()};
const cases = {json.dumps(cases, ensure_ascii=False)};
process.stdout.write(JSON.stringify(cases.map(c => {{
  const k = calc.kabeAnalyze(tables, ex, '2026-10-01', c[0], c[1], c[2]);
  return k && [k.pay19, k.net19, k.pay20, k.net20, k.breakeven ? k.breakeven.hoursX10 : null, k.breakeven ? k.breakeven.net : null];
}})));
"""
    res = subprocess.run(["node", "-e", script], capture_output=True, text=True, encoding="utf-8", check=True)
    got = json.loads(res.stdout)
    for (h, pref, age), g in zip(cases, got):
        k = kabe.analyze(date(2026, 10, 1), h, pref, age)
        assert g == [k.pay_19, k.net_19, k.pay_20, k.net_20, k.breakeven_hours_x10, k.breakeven_net], (h, pref, age)


def test_賞与の保険料もpythonと一致する():
    cases, expected = [], []
    for pref in premium.PREFECTURES:
        for bonus in (0, 999, 1_000, 50_500, 100_000, 123_456, 1_500_999, 1_600_000, 6_000_000):
            for care in (False, True):
                cases.append({"kind": "bonus", "as_of": "2026-12-10", "pref": pref, "bonus": bonus, "care": care})
                r = premium.bonus_estimate(as_of=date(2026, 12, 10), prefecture=pref, bonus_yen=bonus, age_40_to_64=care)
                expected.append([r.standard_yen, r.health_yen, r.kodomo_yen, r.pension_yen, r.total_yen])
    got = _run_node(cases)
    mismatches = [(c, g, e) for c, g, e in zip(cases, got, expected) if g != e]
    assert not mismatches, mismatches[:5]


def test_年末調整後の所得税もpythonと一致する():
    cases = [[g, soc] for g in (0, 1_000_000, 1_780_000, 1_780_999, 1_790_000, 1_900_000, 2_000_000, 2_400_000, 3_000_000, 3_600_000, 3_600_001)
             for soc in (0, 150_000, 290_000)]
    script = f"""
const calc = require({json.dumps(str(_CALC_JS))});
process.stdout.write(JSON.stringify({json.dumps(cases)}.map(c => calc.annualIncomeTaxYen(c[0], c[1]))));
"""
    got = json.loads(subprocess.run(["node", "-e", script], capture_output=True, text=True, encoding="utf-8", check=True).stdout)
    assert got == [extras.annual_income_tax_yen(g, s) for g, s in cases]
