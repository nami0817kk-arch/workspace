"""気象庁の平年値（地上気象観測、1991〜2020年）の zip から、使う地点・要素だけを取り出して data/ に置く。

    curl -O https://www.data.jma.go.jp/stats/data/mdrr/normal/2020/data/normal_surface.zip
    curl -O https://www.data.jma.go.jp/stats/data/mdrr/normal/2020/20250325/normal_surface_ver5.zip
    curl -O https://www.data.jma.go.jp/stats/data/mdrr/normal/2020/data/normal_amedas_monthly.zip
    python tools/import_jma.py normal_surface.zip normal_surface_ver5.zip normal_amedas_monthly.zip

2つ目以降の zip は、1つ目の同じファイルを上書きする（2025-03-25 の第5版は延岡の風速・日照だけの更新）。

平年値は10年ごとに更新される（次は2030年の平年値、2031年ごろ公表）。更新が出たら、これを回し直す。

値はファイルのとおり整数のまま持つ（気温は 0.1℃、降水量は 0.1mm、日数は 0.1日）。
リマークが 8（正常値）でない値は None にする（0 は「統計値なし」）。
"""
from __future__ import annotations

import csv
import io
import json
import sys
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "src"))

from stations import STATIONS  # noqa: E402

# 月別で使う要素（要素番号 → 名前）。番号の意味は気象庁「地上気象観測平年値ファイルフォーマット」。
MONTHLY = {
    "0500": "temp",  # 気温 月平均 0.1℃
    "0600": "tmax",  # 日最高気温 月平均 0.1℃
    "0700": "tmin",  # 日最低気温 月平均 0.1℃
    "4000": "precip",  # 降水量 月合計 0.1mm
    "4600": "rain_days",  # 日降水量≧1.0mm 日数 0.1日
    "5800": "snow_days",  # 雪（降雪）日数 0.1日
    "1100": "summer_days",  # 日最高気温≧25℃ 日数 0.1日
    "1200": "hot_days",  # 日最高気温≧30℃ 日数 0.1日
    "1500": "frost_days",  # 日最低気温＜0℃ 日数 0.1日
    "1000": "ice_days",  # 日最高気温＜0℃ 日数 0.1日
    "3500": "sunshine",  # 日照時間 月合計 0.1時間
    "2000": "humidity",  # 相対湿度 月平均 1%
    "6200": "snow_depth_max",  # 積雪の深さ 月最大 1cm
}
# 旬別（上旬・中旬・下旬）で使う要素。
DEKAD = {"0500": "temp", "0600": "tmax", "0700": "tmin", "4000": "precip"}

SOURCE = {
    "name": "気象庁",
    "title": "平年値（統計期間1991〜2020年）地上気象観測",
    "page": "https://www.data.jma.go.jp/stats/data/mdrr/normal/index.html",
}


def _values(row: list[str], count: int) -> list[int | None]:
    cells = [c.strip() for c in row[6:]]
    out: list[int | None] = []
    for i in range(count):
        value, rmk = cells[2 * i], cells[2 * i + 1]
        out.append(int(value) if rmk == "8" and value != "" else None)
    return out


def _read(zips: list[zipfile.ZipFile], kind: str, code: str) -> list[list[str]]:
    prefix = {
        "monthly": "nml_sfc_m_",
        "month_basis_10day": "nml_sfc_mb10d_",
        "daily": "nml_sfc_d_",
        "seasonal_phenomena": "nml_sfc_sph_",
    }[kind]
    rows = None
    for z in zips:  # 後の zip が優先（第5版の上書き）
        for name in z.namelist():
            if name.endswith(f"/{kind}/{prefix}{code}.csv"):
                text = z.read(name).decode("cp932")
                rows = [r for r in csv.reader(io.StringIO(text)) if r]
    if rows is None:
        raise FileNotFoundError(f"{code} の {kind} が zip に無い")
    return rows


def _evening_by_dekad(daily_rows: list[list[str]]) -> list[int | None]:
    """日別平年値の20時の気温（要素9000）を、旬ごとに平均する（0.1℃）。36個。
    夜のライトアップや夕食に出かける時間帯の目安に使う。旬の区切りは1〜10日・11〜20日・21日〜月末。"""
    out: list[int | None] = []
    by_month = {int(r[6]): r for r in daily_rows if r[2].strip() == "9000"}
    for month in range(1, 13):
        cells = [c.strip() for c in by_month[month][7:]]
        days = [int(cells[2 * i]) for i in range(len(cells) // 2) if cells[2 * i + 1] == "8"]
        for lo, hi in ((0, 10), (10, 20), (20, len(days))):
            part = days[lo:hi]
            out.append(round(sum(part) / len(part)) if part else None)
    return out


def _first_snow(rows: list[list[str]]) -> dict | None:
    """雪の初日（要素7300）の平年日。統計年数も一緒に持つ（地点によって期間が短い）。"""
    for r in rows:
        if r[2].strip() == "7300" and r[7].strip() == "8":
            mmdd = int(r[6])
            return {"month": mmdd // 100, "day": mmdd % 100, "from": int(r[4]), "to": int(r[5])}
    return None


def _amedas_monthly(z: zipfile.ZipFile, code: str) -> dict:
    name = next(n for n in z.namelist() if n.endswith(f"nml_amd_m_{code}.csv"))
    rows = {r[2].strip(): r for r in csv.reader(io.StringIO(z.read(name).decode("cp932"))) if r}
    return {key: _values(rows[num], 12) for num, key in (("0600", "tmax"), ("0700", "tmin"))}


def main() -> None:
    amedas = [zipfile.ZipFile(p) for p in sys.argv[1:] if "amedas" in Path(p).name]
    zips = [zipfile.ZipFile(p) for p in sys.argv[1:] if "amedas" not in Path(p).name]
    if not zips:
        raise SystemExit("zip を指定する")
    index_name = next(n for z in zips for n in z.namelist() if n.endswith("surface_station_index.csv"))
    index_zip = next(z for z in zips if index_name in z.namelist())
    elevations = {
        r[0].strip(): float(r[8]) for r in csv.reader(io.StringIO(index_zip.read(index_name).decode("cp932"))) if r and r[0].strip().isdigit()
    }
    data: dict[str, dict] = {}
    for st in STATIONS:
        monthly_rows = {r[2].strip(): r for r in _read(zips, "monthly", st.code)}
        dekad_rows = {r[2].strip(): r for r in _read(zips, "month_basis_10day", st.code)}
        monthly = {}
        for num, key in MONTHLY.items():
            row = monthly_rows.get(num)
            monthly[key] = _values(row, 12) if row else [None] * 12  # 13番目は年の値。使わない
        dekad = {key: _values(dekad_rows[num], 36) for num, key in DEKAD.items()}
        for key in ("temp", "tmax", "tmin"):
            if any(v is None for v in monthly[key]) or any(v is None for v in dekad[key]):
                raise ValueError(f"{st.name}（{st.code}）の {key} に欠けがある")
        dekad["evening"] = _evening_by_dekad(_read(zips, "daily", st.code))
        entry = {"elevation": round(elevations[st.code]), "monthly": monthly, "dekad": dekad, "first_snow": _first_snow(_read(zips, "seasonal_phenomena", st.code))}
        if st.nearby_points:
            if not amedas:
                raise SystemExit("周辺の観測点があるので normal_amedas_monthly.zip も指定する")
            entry["nearby"] = {code: _amedas_monthly(amedas[0], code) for code, _label, _elev in st.nearby_points}
        data[st.code] = entry

    out = {"source": SOURCE, "period": "1991-2020", "stations": data}
    dest = Path(__file__).resolve().parent.parent / "data" / "normals.json"
    dest.parent.mkdir(exist_ok=True)
    dest.write_text(json.dumps(out, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8", newline="\n")
    print(f"wrote {dest}（{len(data)}地点）")


if __name__ == "__main__":
    main()
