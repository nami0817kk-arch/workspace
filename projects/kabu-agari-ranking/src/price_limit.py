"""東証の制限値幅（値幅制限）から、その日の値動きの性質を判定する。

ランキングは「何%動いたか」しか言わない。だが読み手が知りたいのは
「それは上限まで買われた（ストップ高）のか、途中で止まったのか」で、
そこは前日終値と制限値幅から機械的に決まる。

出典: 日本取引所グループ「制限値幅」（内国株の売買制度）
https://www.jpx.co.jp/equities/trading/domestic/06.html （2026-09-18 更新時点の表）

**この表は取引所が変えることがある。** 数字を直すときは必ず上記の原文を見る。

制限値幅の拡大について:
2営業日連続でストップ高（安）のまま売買が成立しない等の条件に当たると、
翌営業日から制限値幅が拡大される。拡大後の値幅は銘柄ごとにその都度
決まり、当サイトの手元のデータからは分からない。そのため、通常の値幅を
超える動きは「ストップ高」と言い切らず、**拡大または株式分割などの
調整の可能性がある**として注記に留める。
"""
from __future__ import annotations

# (基準値段の上限（円・未満）, 制限値幅（円）)
_LIMIT_TABLE: list[tuple[float, float]] = [
    (100, 30),
    (200, 50),
    (500, 80),
    (700, 100),
    (1_000, 150),
    (1_500, 300),
    (2_000, 400),
    (3_000, 500),
    (5_000, 700),
    (7_000, 1_000),
    (10_000, 1_500),
    (15_000, 3_000),
    (20_000, 4_000),
    (30_000, 5_000),
    (50_000, 7_000),
    (70_000, 10_000),
    (100_000, 15_000),
    (150_000, 30_000),
    (200_000, 40_000),
    (300_000, 50_000),
    (500_000, 70_000),
    (700_000, 100_000),
    (1_000_000, 150_000),
    (1_500_000, 300_000),
    (2_000_000, 400_000),
    (3_000_000, 500_000),
    (5_000_000, 700_000),
    (7_000_000, 1_000_000),
    (10_000_000, 1_500_000),
    (15_000_000, 3_000_000),
    (20_000_000, 4_000_000),
    (30_000_000, 5_000_000),
    (50_000_000, 7_000_000),
]
_ABOVE_TABLE = 10_000_000  # 50,000,000円以上

# 判定は「終値と騰落率から前日終値を逆算する」ため、丸めのぶんだけ誤差が出る。
# 騰落率は小数2桁までしか持っていない。
_TOLERANCE_RATIO = 0.002
_TOLERANCE_MIN = 0.5

STOP_HIGH = "stop_high"
STOP_LOW = "stop_low"
OVER_LIMIT = "over_limit"


def limit_width(base_price: float) -> float:
    """基準値段（前日終値）に対する制限値幅（円）。"""
    for upper, width in _LIMIT_TABLE:
        if base_price < upper:
            return width
    return _ABOVE_TABLE


def base_price(close: float, change_pct: float) -> float | None:
    """終値と騰落率から前日終値を逆算する。"""
    ratio = 1 + change_pct / 100
    if close is None or change_pct is None or ratio <= 0:
        return None
    return close / ratio


def classify(close: float | None, change_pct: float | None) -> str:
    """その日の値動きの性質。該当しなければ空文字。

    - STOP_HIGH / STOP_LOW … 制限値幅いっぱいまで動いた（ストップ高・安）
    - OVER_LIMIT … 通常の制限値幅を超えている。値幅の拡大か、
      株式分割・併合などの調整が入っている可能性がある
    """
    if close is None or change_pct is None:
        return ""
    base = base_price(close, change_pct)
    if base is None or base <= 0:
        return ""

    move = close - base
    width = limit_width(base)
    tolerance = max(_TOLERANCE_MIN, base * _TOLERANCE_RATIO)

    if abs(move) > width + tolerance:
        return OVER_LIMIT
    if abs(move) >= width - tolerance:
        return STOP_HIGH if move > 0 else STOP_LOW
    return ""


def table_rows() -> list[dict]:
    """制限値幅の表を、そのまま画面に出せる形で返す。

    用語解説のページはこの関数から作る。表を2箇所に書くと必ずずれるため。
    """
    rows = []
    prev = 0
    for upper, width in _LIMIT_TABLE:
        rows.append({
            "range": f"{prev:,}円以上 {upper:,}円未満" if prev else f"{upper:,}円未満",
            "width": f"上下 {width:,}円",
        })
        prev = upper
    rows.append({"range": f"{prev:,}円以上", "width": f"上下 {_ABOVE_TABLE:,}円"})
    return rows


LABELS = {
    STOP_HIGH: "ストップ高",
    STOP_LOW: "ストップ安",
    OVER_LIMIT: "制限値幅超",
}

DESCRIPTIONS = {
    STOP_HIGH: "制限値幅の上限まで上昇（ストップ高）",
    STOP_LOW: "制限値幅の下限まで下落（ストップ安）",
    OVER_LIMIT: "通常の制限値幅を超える変動。株式分割・併合などの調整、"
                "または制限値幅の拡大によるものと考えられる",
}
