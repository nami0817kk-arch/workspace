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
