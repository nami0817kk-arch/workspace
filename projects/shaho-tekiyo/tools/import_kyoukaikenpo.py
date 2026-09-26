"""協会けんぽの保険料額表（エクセル版・全都道府県分）から料率を取り出し、data/ に JSON で置く。

**料率は毎年3月分から改定される。** 新しい年度の額表が出たら、これを回して
`data/` に1ファイル足し、`src/premium.py` の `RATE_FILES` に1行足す。
古い年度のファイルは消さない（過去の時点を選んだ人に、その時点の料率で答えるため）。

    pip install openpyxl
    curl -o r8ippan3.xlsx https://www.kyoukaikenpo.or.jp/assets/r8ippan3.xlsx
    python tools/import_kyoukaikenpo.py r8ippan3.xlsx --fiscal-year 2026 \
        --valid-from 2026-04-01 --valid-until 2027-02-28

取り出すだけでなく、**額表に載っている全都道府県・全等級の「折半額」を、取り出した料率から
計算し直して1円未満まで一致することを確かめる**。一致しなければ書き出さずに止まる
（シートの並びが変わって別の列を読んだ、を黙って通さないため）。

料率は 1/100000 単位の整数で持つ（10.28% → 10280）。浮動小数で持つと、
0.1028 が 0.10279999… になり、端数処理の境目で1円ずれる。
"""
from __future__ import annotations

import argparse
import json
import re
from fractions import Fraction
from pathlib import Path

import openpyxl

SOURCE_PAGE = "https://www.kyoukaikenpo.or.jp/g7/cat330/sb3150/r08/r8ryougakuhyou3gatukara/"

# シート上の位置（令和8年度版で確認）。0始まりの行・列。
_RATE_ROW = 7
_COL_HEALTH, _COL_HEALTH_CARE, _COL_KODOMO, _COL_PENSION = 5, 7, 9, 11
_FIRST_GRADE_ROW = 10
_COL_GRADE, _COL_STANDARD, _COL_LOWER = 0, 1, 2
_COL_HALF_HEALTH, _COL_HALF_HEALTH_CARE, _COL_HALF_KODOMO, _COL_HALF_PENSION = 6, 8, 10, 12


def _to_units(rate: float) -> int:
    """0.1028 → 10280（1/100000 単位）。"""
    units = round(rate * 100_000)
    if abs(units - rate * 100_000) > 1e-6:
        raise ValueError(f"料率 {rate} が 0.001% 単位で表せない")
    return units


def _half(standard: int, units: int) -> Fraction:
    return Fraction(standard * units, 200_000)


def _read_sheet(ws) -> tuple[dict, list, list, list]:
    rows = list(ws.iter_rows(min_row=1, max_row=80, values_only=True))
    rate_row = rows[_RATE_ROW]
    health = _to_units(rate_row[_COL_HEALTH])
    health_care = _to_units(rate_row[_COL_HEALTH_CARE])
    rates = {
        "health": health,
        "care": health_care - health,
        "kodomo": _to_units(rate_row[_COL_KODOMO]),
        "pension": _to_units(rate_row[_COL_PENSION]),
    }

    health_grades, pension_grades, halves = [], [], []
    for row in rows[_FIRST_GRADE_ROW:]:
        grade, standard = row[_COL_GRADE], row[_COL_STANDARD]
        if grade is None or not isinstance(standard, (int, float)):
            continue
        lower = row[_COL_LOWER] or 0
        label = str(grade)
        health_no = int(label.split("(")[0])
        health_grades.append([health_no, int(standard), int(lower)])
        pension_no = None
        if "(" in label:
            pension_no = int(label.split("(")[1].rstrip(")"))
            pension_grades.append([pension_no, int(standard), int(lower)])
        halves.append((int(standard), row[_COL_HALF_HEALTH], row[_COL_HALF_HEALTH_CARE],
                       row[_COL_HALF_KODOMO], row[_COL_HALF_PENSION] if pension_no else None))
    return rates, health_grades, pension_grades, halves


def _check_halves(pref: str, rates: dict, halves: list) -> None:
    """額表の折半額を、取り出した料率から計算し直して照合する。"""
    for standard, h, hc, k, p in halves:
        expected = [
            (h, rates["health"]),
            (hc, rates["health"] + rates["care"]),
            (k, rates["kodomo"]),
            (p, rates["pension"]),
        ]
        for official, units in expected:
            if official is None:
                continue
            if abs(Fraction(official).limit_denominator(100) - _half(standard, units)) > Fraction(1, 100):
                raise ValueError(f"{pref} 標準報酬 {standard} で額表 {official} と計算 {float(_half(standard, units))} がずれる")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("xlsx")
    ap.add_argument("--fiscal-year", type=int, required=True)
    ap.add_argument("--valid-from", required=True, help="この料率で計算してよい最初の日（YYYY-MM-DD）")
    ap.add_argument("--valid-until", required=True, help="この料率で計算してよい最後の日（YYYY-MM-DD）")
    ap.add_argument("--xlsx-url", default="https://www.kyoukaikenpo.or.jp/assets/r8ippan3.xlsx")
    args = ap.parse_args()

    wb = openpyxl.load_workbook(args.xlsx, read_only=True, data_only=True)
    prefectures: dict[str, dict] = {}
    health_grades0 = pension_grades0 = None
    for name in wb.sheetnames:
        rates, health_grades, pension_grades, halves = _read_sheet(wb[name])
        _check_halves(name, rates, halves)
        if health_grades0 is None:
            health_grades0, pension_grades0 = health_grades, pension_grades
        elif (health_grades, pension_grades) != (health_grades0, pension_grades0):
            raise ValueError(f"{name} の等級表が他の都道府県と違う")
        prefectures[name] = rates

    # 厚生年金の1等級は「93,000円未満」すべて（額表の注記「4（1）等級の報酬月額欄は、
    # 厚生年金保険の場合『93,000円未満』と読み替えてください」）。
    pension_grades0[0][2] = 0

    if len(prefectures) != 47:
        raise ValueError(f"都道府県が {len(prefectures)} 件しかない")
    for key in ("kodomo", "pension", "care"):
        if len({r[key] for r in prefectures.values()}) != 1:
            raise ValueError(f"{key} の率が都道府県で違う（全国一律のはず）")

    out = {
        "fiscal_year": args.fiscal_year,
        "valid_from": args.valid_from,
        "valid_until": args.valid_until,
        "unit": "1/100000",
        "source": {
            "name": "全国健康保険協会（協会けんぽ）",
            "title": f"令和{args.fiscal_year - 2018}年度保険料額表",
            "page": SOURCE_PAGE,
            "xlsx": args.xlsx_url,
        },
        "health_grades": health_grades0,
        "pension_grades": pension_grades0,
        "prefectures": prefectures,
    }
    dest = Path(__file__).resolve().parent.parent / "data" / f"kyoukaikenpo_{args.fiscal_year}.json"
    dest.parent.mkdir(exist_ok=True)
    text = json.dumps(out, ensure_ascii=False, indent=1)
    # 等級の [番号, 標準報酬, 下限] は1行に畳む（人が差分を読めるように）。
    text = re.sub(r"\[\s+(\d+),\s+(\d+),\s+(\d+)\s+\]", r"[\1, \2, \3]", text)
    dest.write_text(text + "\n", encoding="utf-8", newline="\n")
    print(f"wrote {dest}（{len(prefectures)}都道府県・健保{len(health_grades0)}等級・厚年{len(pension_grades0)}等級、額表と全件照合済み）")


if __name__ == "__main__":
    main()
