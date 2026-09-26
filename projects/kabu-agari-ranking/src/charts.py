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

# 色は CSS 変数で渡す。SVG は HTML に直接埋め込まれるので、
# 明暗の切り替え（prefers-color-scheme）にそのまま追従できる。
# 明るい地・暗い地それぞれで、明度帯・彩度・色覚多様性の分離・コントラストを
# 検証済み（dataviz の validate_palette.js で6項目 PASS）。実際の値は base.html。
COLOR_GAIN = "var(--chart-gain)"
COLOR_LOSS = "var(--chart-loss)"
COLOR_GRID = "var(--border)"
COLOR_TEXT = "var(--text)"
COLOR_MUTED = "var(--muted)"

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


def _rounded_bottom(x: float, y: float, w: float, h: float, r: float) -> str:
    """上端（基線）は直角、下端だけ丸い柱（0より下に伸びるもの）。"""
    r = max(0.0, min(r, w / 2, h))
    return (
        f"M{x:.1f},{y:.1f} H{x + w:.1f} V{y + h - r:.1f} "
        f"Q{x + w:.1f},{y + h:.1f} {x + w - r:.1f},{y + h:.1f} "
        f"H{x + r:.1f} Q{x:.1f},{y + h:.1f} {x:.1f},{y + h - r:.1f} Z"
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


def _format_value(value: float, unit: str, negative: bool, signed: bool) -> str:
    """棒に添える数値。率は符号付きの小数2桁、件数は3桁区切りの整数。"""
    if signed:
        return f'{"-" if negative else "+"}{abs(value):.2f}{unit}'
    return f"{abs(value):,.0f}{unit}"


def horizontal_bars(
    rows: list[dict],
    *,
    aria_label: str,
    unit: str = "%",
    negative: bool = False,
    signed: bool = True,
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
        tick_text = f"{t:,.0f}" if not signed and t >= 1000 else f"{t:g}"
        parts.append(
            f'<text x="{x:.1f}" y="{height - 5}" text-anchor="{anchor}" font-size="10" '
            f'fill="{COLOR_MUTED}">{sign}{tick_text}{escape(unit)}</text>'
        )

    for i, r in enumerate(rows):
        y = top + i * row_h
        w = max(abs(r["value"]) * scale, 1)
        raw_name = str(r["label"])
        name = escape(_ellipsize(raw_name, NAME_MAX_CHARS))
        sub = escape(str(r.get("sub", "")))
        value_text = _format_value(r["value"], unit, negative, signed)

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


def _signed_ticks(lo: float, hi: float) -> list[float]:
    """0 を必ず含み、上下それぞれを覆いきる目盛り。"""
    step = _nice_step(max(abs(lo), abs(hi)))
    out, v = [], 0.0
    while v < hi:
        v += step
        out.append(round(v, 6))
    down, v = [], 0.0
    while v > lo:
        v -= step
        down.append(round(v, 6))
    return sorted(down + [0.0] + out)


def columns(points: list[dict], *, aria_label: str, unit: str = "") -> str:
    """日ごとの推移を見る柱。points は {label, value} の並び（古い順）。

    値が負になりうる場合は 0 を基準線にして下向きに描き、色も下落の色にする。
    絶対値で描くと、下げた日が上げた日と同じ向きの棒になって誤読させる。
    """
    points = [p for p in points if p.get("value") is not None]
    if len(points) < 3:
        return ""  # 2本以下は推移として読めない

    width, height = 360, 150
    left, right, top, bottom = 26, 4, 14, 22
    plot_w = width - left - right
    plot_h = height - top - bottom

    values = [p["value"] for p in points]
    hi, lo = max(max(values), 0), min(min(values), 0)
    ticks = _signed_ticks(lo, hi) if lo < 0 else _ticks(hi or 1)
    t_min, t_max = ticks[0], ticks[-1]
    span = (t_max - t_min) or 1
    scale = plot_h / span

    def y_of(value: float) -> float:
        return top + (t_max - value) * scale

    zero_y = y_of(0)
    band = plot_w / len(points)
    bar_w = min(MAX_BAR, max(4.0, band - max(MIN_GAP, band * 0.35)))

    parts = []
    for t in ticks:
        y = y_of(t)
        # 0 の線だけは基準線なので、他の目盛りより少しはっきりさせる
        width_attr = "1.5" if t == 0 and lo < 0 else "1"
        parts.append(
            f'<line x1="{left}" y1="{y:.1f}" x2="{width - right}" y2="{y:.1f}" '
            f'stroke="{COLOR_GRID}" stroke-width="{width_attr}"/>'
        )
        parts.append(
            f'<text x="{left - 5}" y="{y + 3.5:.1f}" text-anchor="end" font-size="10" '
            f'fill="{COLOR_MUTED}">{t:g}</text>'
        )

    # x軸のラベルは詰まるので間引く（両端は必ず出す）
    every = max(1, round(len(points) / 7))
    for i, p in enumerate(points):
        cx = left + band * i + band / 2
        value = p["value"]
        y = y_of(value)
        h = max(abs(zero_y - y), 1)
        label = escape(str(p["label"]))
        if value >= 0:
            path = _rounded_top(cx - bar_w / 2, y, bar_w, h, BAR_RADIUS)
        else:
            path = _rounded_bottom(cx - bar_w / 2, zero_y, bar_w, h, BAR_RADIUS)
        color = COLOR_GAIN if value >= 0 else COLOR_LOSS
        parts.append(
            f'<path d="{path}" fill="{color}">'
            f'<title>{label} {value:g}{escape(unit)}</title></path>'
        )
        if i == len(points) - 1 or i % every == 0:
            parts.append(
                f'<text x="{cx:.1f}" y="{height - 8}" text-anchor="middle" font-size="10" '
                f'fill="{COLOR_MUTED}">{label}</text>'
            )

    # 数値を書くのは「直近」と「振れ幅がいちばん大きい日」の2本だけ。
    # 全部に書くと読まれない（そして値は表にある）。
    peak_i = max(range(len(points)), key=lambda i: abs(points[i]["value"]))
    for i in {len(points) - 1, peak_i}:
        p = points[i]
        cx = left + band * i + band / 2
        y = y_of(p["value"])
        text_y = max(y - 5, 10) if p["value"] >= 0 else min(y + 13, height - bottom)
        parts.append(
            f'<text x="{cx:.1f}" y="{text_y:.1f}" text-anchor="middle" font-size="11" '
            f'fill="{COLOR_TEXT}">{p["value"]:g}{escape(unit)}</text>'
        )
    return _svg(width, height, aria_label, "".join(parts))
