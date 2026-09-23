"""ビルド時に SVG のグラフを作る。

外部のグラフライブラリを読み込まない理由:

- このサイトは静的ページで、表示速度と「開いた瞬間に読めること」が価値。
  CDN から数百KBのJSを落としてから描く形にすると、そこが一番遅くなる。
- 検索エンジンにも、JSを切った環境にも、そのまま読める。
- 値そのものは必ず同じページの表に載っている。グラフは形を見るためのもので、
  グラフが読めないと値が分からない、という作りにはしない。

作図の決まり（読み手のために固定しているもの）:

- 1つのグラフに1系統だけ。凡例は置かない（見出しが何のグラフか言っている）。
- 棒は24px以下、データ側の端だけ角を丸める。棒の間は必ず2px以上あける。
- 目盛り線は1px・実線・地の色に近い灰色。破線にしない（別の意味に見える）。
- 数値ラベルは全部には付けない。最大値の1本だけに付け、残りは目盛りと表で読む。
- 文字に系統の色を使わない（色は棒が持ち、文字は本文の色のまま）。
- 上昇は赤、下落は青。サイトの表と同じ対応にする（日本の相場表示の慣習）。
"""
from __future__ import annotations

from html import escape

# サイトの配色。白地に対して、明度帯・彩度・色覚多様性の分離・コントラストを
# 検証済み（dataviz の validate_palette.js で6項目すべて PASS）。
COLOR_GAIN = "#d64545"
COLOR_LOSS = "#2563a8"
COLOR_GRID = "#e5e7eb"
COLOR_TEXT = "#1a1a1a"
COLOR_MUTED = "#6b7280"

BAR_RADIUS = 4
MAX_BAR = 24
MIN_GAP = 2
# 名前の欄（コードとの間）に収まる文字数。超えたら切る。
NAME_MAX_CHARS = 12


def _nice_step(max_value: float, target_ticks: int = 4) -> float:
    """目盛りを 1 / 2 / 5 の系列の切りのいい数にする。"""
    if max_value <= 0:
        return 1
    raw = max_value / target_ticks
    magnitude = 10 ** (len(str(int(raw))) - 1) if raw >= 1 else 0.1
    for m in (1, 2, 5, 10):
        if raw <= m * magnitude:
            return m * magnitude
    return 10 * magnitude


def _ticks(max_value: float) -> list[float]:
    """0 から、最大値を**覆いきる**ところまでの目盛り。

    最後の目盛りが最大値より小さいと、棒が目盛りの外にはみ出して
    数値ラベルも画の外に落ちる（2026-09-23 に実際に起きた）。
    """
    step = _nice_step(max_value)
    out, v = [], 0.0
    while True:
        out.append(round(v, 6))
        if v >= max_value:
            return out
        v += step


def _rounded_right(x: float, y: float, w: float, h: float, r: float) -> str:
    """左端は直角、右端（データ側）だけ丸い棒。"""
    r = max(0.0, min(r, w, h / 2))
    return (
        f"M{x:.1f},{y:.1f} H{x + w - r:.1f} Q{x + w:.1f},{y:.1f} {x + w:.1f},{y + r:.1f} "
        f"V{y + h - r:.1f} Q{x + w:.1f},{y + h:.1f} {x + w - r:.1f},{y + h:.1f} "
        f"H{x:.1f} Z"
    )


def _rounded_top(x: float, y: float, w: float, h: float, r: float) -> str:
    """下端（基線）は直角、上端だけ丸い柱。"""
    r = max(0.0, min(r, w / 2, h))
    return (
        f"M{x:.1f},{y + h:.1f} V{y + r:.1f} Q{x:.1f},{y:.1f} {x + r:.1f},{y:.1f} "
        f"H{x + w - r:.1f} Q{x + w:.1f},{y:.1f} {x + w:.1f},{y + r:.1f} "
        f"V{y + h:.1f} Z"
    )


def _ellipsize(text: str, max_chars: int) -> str:
    """名前の欄に収まらない銘柄名を切る。

    切らずに置くと、左端のコードに重なって両方読めなくなる。
    全角で数えるのは、銘柄名がほぼ全角だから（多少の誤差は余白で吸収する）。
    """
    return text if len(text) <= max_chars else text[: max_chars - 1] + "…"


def _svg(width: int, height: int, label: str, body: str) -> str:
    return (
        f'<svg class="chart" viewBox="0 0 {width} {height}" width="{width}" height="{height}" '
        f'role="img" aria-label="{escape(label)}" xmlns="http://www.w3.org/2000/svg">'
        f"{body}</svg>"
    )


def horizontal_bars(
    rows: list[dict],
    *,
    aria_label: str,
    unit: str = "%",
    negative: bool = False,
) -> str:
    """銘柄ごとの大きさを比べる横棒。rows は {label, sub, value} の並び。

    **狭い画面を基準に作る。** SVG は幅に合わせて拡大縮小されるので、
    PC幅（700px）で作ると、スマホでは半分に縮んで文字が読めなくなる。
    そこで 360 幅で組み、CSS 側で拡大の上限を決めている。

    銘柄名は棒の上に置く。横に並べると名前の欄が狭い画面で潰れるため。
    値は最大の1本にだけ書き、残りは目盛りと、同じページの表で読む。
    """
    rows = [r for r in rows if r.get("value") is not None]
    if len(rows) < 2:
        return ""  # 棒1本のグラフは作らない（数字をそのまま読めばよい）

    color = COLOR_LOSS if negative else COLOR_GAIN
    width = 360
    top, row_h, bar_h, name_h, axis_h = 6, 30, 10, 13, 18
    height = top + row_h * len(rows) + axis_h
    plot_w = width

    peak = max(abs(r["value"]) for r in rows)
    ticks = _ticks(peak)
    scale = plot_w / (ticks[-1] or 1)

    parts = []
    for t in ticks:
        x = min(t * scale, width - 0.5)
        parts.append(
            f'<line x1="{x:.1f}" y1="{top}" x2="{x:.1f}" y2="{top + row_h * len(rows)}" '
            f'stroke="{COLOR_GRID}" stroke-width="1"/>'
        )
        anchor = "start" if t == 0 else ("end" if t == ticks[-1] else "middle")
        sign = "-" if negative and t else ""
        parts.append(
            f'<text x="{x:.1f}" y="{height - 5}" text-anchor="{anchor}" font-size="10" '
            f'fill="{COLOR_MUTED}">{sign}{t:g}{escape(unit)}</text>'
        )

    for i, r in enumerate(rows):
        y = top + i * row_h
        w = max(abs(r["value"]) * scale, 1)
        raw_name = str(r["label"])
        name = escape(_ellipsize(raw_name, NAME_MAX_CHARS))
        sub = escape(str(r.get("sub", "")))
        value_text = f'{"-" if negative else "+"}{abs(r["value"]):.2f}{unit}'

        parts.append(
            f'<text x="0" y="{y + name_h - 3}" font-size="11" fill="{COLOR_TEXT}">{name}'
            f'<tspan fill="{COLOR_MUTED}"> {sub}</tspan></text>'
        )
        if i == 0:  # 最大の1本だけ数値を書く（残りは目盛りと表で読む）
            parts.append(
                f'<text x="{width}" y="{y + name_h - 3}" text-anchor="end" font-size="11" '
                f'fill="{COLOR_TEXT}">{value_text}</text>'
            )
        parts.append(
            f'<path d="{_rounded_right(0, y + name_h, w, bar_h, BAR_RADIUS)}" fill="{color}">'
            f"<title>{escape(raw_name)}（{sub}） {value_text}</title></path>"
        )

    return _svg(width, height, aria_label, "".join(parts))


def columns(points: list[dict], *, aria_label: str, unit: str = "") -> str:
    """日ごとの推移を見る柱。points は {label, value, href?} の並び（古い順）。"""
    points = [p for p in points if p.get("value") is not None]
    if len(points) < 3:
        return ""  # 2本以下は推移として読めない

    width, height = 360, 150
    left, right, top, bottom = 26, 4, 14, 22
    plot_w = width - left - right
    plot_h = height - top - bottom

    peak = max(p["value"] for p in points) or 1
    ticks = _ticks(peak)
    scale = plot_h / (ticks[-1] or 1)
    band = plot_w / len(points)
    bar_w = min(MAX_BAR, max(4.0, band - max(MIN_GAP, band * 0.35)))

    parts = []
    for t in ticks:
        y = top + plot_h - t * scale
        parts.append(
            f'<line x1="{left}" y1="{y:.1f}" x2="{width - right}" y2="{y:.1f}" '
            f'stroke="{COLOR_GRID}" stroke-width="1"/>'
        )
        parts.append(
            f'<text x="{left - 5}" y="{y + 3.5:.1f}" text-anchor="end" font-size="10" '
            f'fill="{COLOR_MUTED}">{t:g}</text>'
        )

    # x軸のラベルは詰まるので間引く（両端は必ず出す）
    every = max(1, round(len(points) / 7))
    for i, p in enumerate(points):
        cx = left + band * i + band / 2
        h = p["value"] * scale
        y = top + plot_h - h
        label = escape(str(p["label"]))
        parts.append(
            f'<path d="{_rounded_top(cx - bar_w / 2, y, bar_w, max(h, 1), BAR_RADIUS)}" '
            f'fill="{COLOR_GAIN}"><title>{label} {p["value"]:g}{escape(unit)}</title></path>'
        )
        if i == len(points) - 1 or i % every == 0:
            parts.append(
                f'<text x="{cx:.1f}" y="{height - 8}" text-anchor="middle" font-size="10" '
                f'fill="{COLOR_MUTED}">{label}</text>'
            )

    # 数値を書くのは「直近」と「いちばん高い日」の2本だけ。
    # 全部に書くと読まれない（そして値は表にある）。
    peak_i = max(range(len(points)), key=lambda i: points[i]["value"])
    for i in {len(points) - 1, peak_i}:
        p = points[i]
        cx = left + band * i + band / 2
        y = top + plot_h - p["value"] * scale
        parts.append(
            f'<text x="{cx:.1f}" y="{max(y - 5, 10):.1f}" text-anchor="middle" font-size="11" '
            f'fill="{COLOR_TEXT}">{p["value"]:g}{escape(unit)}</text>'
        )
    return _svg(width, height, aria_label, "".join(parts))
