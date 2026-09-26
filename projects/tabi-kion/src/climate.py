"""平年値から、1ページに出す中身（数字・上中下旬の変化・他の地点との差・服装の目安）を組み立てる。

**服装の目安は当サイトの決めごと**で、気象庁の情報ではない。ページには必ずそう書く。
気温の区切りは下の `_CLOTHING` の1箇所だけに置く。**予報は出さない**（気象業務法第17条。
平年値は過去30年の平均で、予報ではない）。
"""
from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path

from stations import BY_CODE, COMPARE_WITH, Station

_DATA = Path(__file__).resolve().parent.parent / "data" / "normals.json"
_RAW = json.loads(_DATA.read_text(encoding="utf-8"))
SOURCE: dict = _RAW["source"]
PERIOD: str = _RAW["period"]
NORMALS: dict[str, dict] = _RAW["stations"]

# 最高気温・最低気温（℃）から服装の目安を引く。上から順に「この温度以上なら」。
_CLOTHING: tuple[tuple[float, str], ...] = (
    (30, "半袖。日差しと暑さへの備え（帽子・飲み物）"),
    (25, "半袖"),
    (20, "長袖シャツ1枚、または半袖に薄い羽織り"),
    (16, "長袖に薄手の上着（カーディガン・パーカー）"),
    (12, "セーターや薄手のコート・ジャケット"),
    (7, "コート（トレンチ・ウール）"),
    (3, "厚手のコート、マフラー"),
    (-99, "ダウンなどの防寒着、手袋・帽子"),
)


def clothing_for(celsius: float) -> str:
    for threshold, text in _CLOTHING:
        if celsius >= threshold:
            return text
    raise AssertionError("unreachable")


def _c(v: int | None) -> float | None:
    return None if v is None else v / 10


@dataclass(frozen=True)
class MonthClimate:
    station: Station
    month: int  # 1〜12
    temp: float
    tmax: float
    tmin: float
    precip: float | None  # mm
    rain_days: float | None  # 日降水量1mm以上の日数
    snow_days: float | None
    summer_days: float | None
    hot_days: float | None
    frost_days: float | None
    sunshine: float | None  # 時間
    humidity: int | None  # %
    snow_depth_max: int | None  # cm
    dekads: tuple[tuple[str, float, float], ...]  # (上旬/中旬/下旬, 最高, 最低)

    @property
    def day_clothing(self) -> str:
        return clothing_for(self.tmax)

    @property
    def night_clothing(self) -> str:
        return clothing_for(self.tmin)

    def notes(self) -> list[str]:
        """持ち物などの一言。数字から機械的に出す。"""
        out = []
        if self.rain_days is not None and self.rain_days >= 12:
            out.append(f"雨の日（1mm以上）が月に約{self.rain_days:.0f}日。折りたたみ傘があると安心です。")
        if self.snow_days is not None and self.snow_days >= 5:
            out.append(f"雪の降る日が月に約{self.snow_days:.0f}日。滑りにくい靴を。")
        if self.tmax - self.tmin >= 10:
            out.append(f"朝晩と日中の差が約{self.tmax - self.tmin:.0f}℃。脱ぎ着しやすい重ね着が向いています。")
        if self.humidity is not None and self.humidity >= 75 and self.tmax >= 25:
            out.append(f"湿度が平均{self.humidity}%と高く、蒸し暑く感じやすい時期です。")
        if self.hot_days is not None and self.hot_days >= 10:
            out.append(f"最高気温30℃以上の日が月に約{self.hot_days:.0f}日。熱中症に注意。")
        return out


_DEKAD_NAMES = ("上旬", "中旬", "下旬")


def month_climate(code: str, month: int) -> MonthClimate:
    m = NORMALS[code]["monthly"]
    d = NORMALS[code]["dekad"]
    i = month - 1
    dekads = tuple(
        (_DEKAD_NAMES[k], d["tmax"][i * 3 + k] / 10, d["tmin"][i * 3 + k] / 10) for k in range(3)
    )
    return MonthClimate(
        station=BY_CODE[code],
        month=month,
        temp=m["temp"][i] / 10,
        tmax=m["tmax"][i] / 10,
        tmin=m["tmin"][i] / 10,
        precip=_c(m["precip"][i]),
        rain_days=_c(m["rain_days"][i]),
        snow_days=_c(m["snow_days"][i]),
        summer_days=_c(m["summer_days"][i]),
        hot_days=_c(m["hot_days"][i]),
        frost_days=_c(m["frost_days"][i]),
        sunshine=_c(m["sunshine"][i]),
        humidity=m["humidity"][i],
        snow_depth_max=m["snow_depth_max"][i],
        dekads=dekads,
    )


@dataclass(frozen=True)
class Comparison:
    other: Station
    tmax_diff: float  # この地点 − 比べる地点
    tmin_diff: float


def comparisons(code: str, month: int) -> list[Comparison]:
    here = month_climate(code, month)
    out = []
    for other in COMPARE_WITH:
        if other == code:
            continue
        o = month_climate(other, month)
        out.append(Comparison(BY_CODE[other], round(here.tmax - o.tmax, 1), round(here.tmin - o.tmin, 1)))
    return out


def diff_text(diff: float) -> str:
    if abs(diff) < 0.5:
        return "ほぼ同じ"
    return f"{abs(diff):.1f}℃{'高い' if diff > 0 else '低い'}"


def comparison_sentence(comps: list[Comparison]) -> str:
    """「最高気温は東京より0.5℃高く、大阪より1.9℃低い水準です。」"""
    parts = []
    for i, cmp in enumerate(comps):
        last = i == len(comps) - 1
        d = cmp.tmax_diff
        if abs(d) < 0.5:
            parts.append(f"{cmp.other.name}とほぼ同じ" + ("" if last else "で"))
        else:
            word = ("高い" if d > 0 else "低い") if last else ("高く" if d > 0 else "低く")
            parts.append(f"{cmp.other.name}より{abs(d):.1f}℃{word}")
    return "最高気温は" + "、".join(parts) + "水準です。" if parts else ""
