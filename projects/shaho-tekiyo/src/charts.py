"""ページに埋め込む図（インライン SVG）を作る。JS なしで見える。

色は base.html の CSS 変数（--s1〜--s4、ライト/ダークで切り替え）を使う。dataviz の既定パレット
（青・橙・水色・黄の順。隣り合う組み合わせは色覚の違いでも見分けられることを確認済み）。
文字は色で塗らず、凡例の色見本で見分ける。各要素に <title> を付けて、マウスを乗せると値が出る。

計算機の画面（static/charts.js）にも同じ図がある。見た目を変えたら両方そろえる。
"""
from __future__ import annotations

from html import escape


def _yen(n: int) -> str:
    return f"{n:,}円"


def breakdown_bar(parts: list[tuple[str, int, str]], total: int, caption: str) -> str:
    """月収がどこへ行くかの横帯（100%）。parts は (名前, 金額, 色の番号 's1'〜) の並び。"""
    w, h, gap = 640, 44, 2
    x = 0.0
    rects = []
    for name, value, color in parts:
        if value <= 0:
            continue
        width = w * value / total
        pct = value / total * 100
        rects.append(
            f'<rect x="{x:.1f}" y="0" width="{max(width - gap, 1):.1f}" height="{h}" rx="4" class="fill-{color}">'
            f"<title>{escape(name)} {_yen(value)}（{pct:.1f}%）</title></rect>"
        )
        # 帯の中に収まるときだけ割合を書く（収まらないものは凡例と表に任せる）
        if width >= 56:
            rects.append(
                f'<text x="{x + width / 2 - gap / 2:.1f}" y="{h / 2 + 5:.1f}" text-anchor="middle" class="in-{color}">{pct:.0f}%</text>'
            )
        x += width
    legend = "".join(
        f'<li><span class="sw fill-{color}"></span>{escape(name)} <strong>{_yen(value)}</strong></li>'
        for name, value, color in parts
        if value > 0
    )
    return (
        f'<figure class="viz"><svg viewBox="0 0 {w} {h}" role="img" aria-label="{escape(caption)}" class="bar100">'
        + "".join(rects)
        + f'</svg><ul class="legend">{legend}</ul><figcaption>{escape(caption)}</figcaption></figure>'
    )


def wall_columns(rows: list[dict], baseline: int, caption: str) -> str:
    """週の時間ごとの手取りの縦棒。週19時間の手取りを横線で示し、それより少ない棒を橙、以上を青にする。
    rows: {"label": "週20時間", "net": 80950, "base": True/False}（base は週19時間の棒）"""
    w, h = 640, 300
    left, right, top, bottom = 50, 8, 28, 62
    pw, ph = w - left - right, h - top - bottom
    nets = [r["net"] for r in rows]
    lo = 0  # 棒は0から（途中から始めると差が大きく見える）
    step = 20000
    hi = int(-(-max(nets) * 1.05 // step) * step)
    band = pw / len(rows)
    bar_w = min(40, band * 0.6)

    def y(v: float) -> float:
        return top + ph * (hi - v) / (hi - lo)

    out = [f'<svg viewBox="0 0 {w} {h}" role="img" aria-label="{escape(caption)}" class="cols">']
    for t in range(lo, hi + 1, step):
        out.append(f'<line x1="{left}" x2="{w - right}" y1="{y(t):.1f}" y2="{y(t):.1f}" class="grid"/>')
        if t:
            out.append(f'<text x="{left - 6}" y="{y(t) + 4:.1f}" text-anchor="end" class="axis">{t // 10000}万</text>')
    for i, r in enumerate(rows):
        cx = left + band * (i + 0.5)
        color = "base" if r.get("base") else ("s1" if r["net"] >= baseline else "s2")
        top_y = y(r["net"])
        height = y(lo) - top_y
        # 上の角だけ丸める（下は基線でまっすぐ）
        out.append(
            f'<path d="M{cx - bar_w / 2:.1f},{y(lo):.1f} V{top_y + 4:.1f} Q{cx - bar_w / 2:.1f},{top_y:.1f} {cx - bar_w / 2 + 4:.1f},{top_y:.1f} '
            f'H{cx + bar_w / 2 - 4:.1f} Q{cx + bar_w / 2:.1f},{top_y:.1f} {cx + bar_w / 2:.1f},{top_y + 4:.1f} V{y(lo):.1f} Z" class="fill-{color}">'
            f'<title>{escape(r["label"])}: 手取り {_yen(r["net"])}（週19時間より{"+" if r["net"] >= baseline else "−"}{_yen(abs(r["net"] - baseline))}）</title></path>'
        )
        if r.get("label_value"):
            out.append(f'<text x="{cx:.1f}" y="{top_y - 8:.1f}" text-anchor="middle" class="val">{r["net"] / 10000:.1f}万</text>')
        out.append(f'<text x="{cx:.1f}" y="{h - bottom + 22:.1f}" text-anchor="middle" class="axis">{escape(r["short"])}</text>')
    out.append(f'<line x1="{left}" x2="{w - right}" y1="{y(baseline):.1f}" y2="{y(baseline):.1f}" class="ref"/>')
    out.append(f'<text x="{w / 2:.1f}" y="{h - 4}" text-anchor="middle" class="axis">週の労働時間（時間）</text>')
    out.append("</svg>")
    legend = (
        '<ul class="legend"><li><span class="sw fill-base"></span>週19時間（加入なし）</li>'
        '<li><span class="sw fill-s2"></span>週19時間より少ない</li>'
        '<li><span class="sw fill-s1"></span>週19時間以上に戻った</li>'
        f'<li><span class="sw-line"></span>週19時間の手取り（{_yen(baseline)}）</li></ul>'
    )
    return f'<figure class="viz">{"".join(out)}{legend}<figcaption>{escape(caption)}</figcaption></figure>'


def stages_timeline(stages: list[tuple[str, str, bool]], caption: str) -> str:
    """企業規模要件の段階。stages: (時期, 対象になる会社, いまの段階か)。横に5つ並べ、矢印でつなぐ。"""
    n = len(stages)
    w, h = 640, 180
    box_w = (w - (n - 1) * 14) / n
    out = [f'<svg viewBox="0 0 {w} {h}" role="img" aria-label="{escape(caption)}" class="timeline">']
    for i, (when, who, now) in enumerate(stages):
        x = i * (box_w + 14)
        # 段が進むほど対象が広がる → 帯の高さを伸ばして「広がり」を見せる
        bar_h = 18 + i * 10
        # 棒の下端は下の名前（スマホでは24px）と重ならないように h-46 まで
        out.append(f'<rect x="{x:.1f}" y="{h - 46 - bar_h}" width="{box_w:.1f}" height="{bar_h}" rx="4" class="fill-{"s1" if now else "step"}">'
                   f"<title>{escape(when)}: {escape(who)}</title></rect>")
        # 「2027年10月」は2行に分ける（スマホで横にあふれないように）
        if "年" in when:
            y_part, m_part = when.split("年", 1)
            out.append(
                f'<text x="{x + box_w / 2:.1f}" y="26" text-anchor="middle" class="axis strong">'
                f'<tspan x="{x + box_w / 2:.1f}">{escape(y_part)}年</tspan><tspan x="{x + box_w / 2:.1f}" dy="1.15em">{escape(m_part)}</tspan></text>'
            )
        else:
            out.append(f'<text x="{x + box_w / 2:.1f}" y="26" text-anchor="middle" class="axis strong">{escape(when)}</text>')
        out.append(f'<text x="{x + box_w / 2:.1f}" y="{h - 6}" text-anchor="middle" class="axis">{escape(who)}</text>')
        if i < n - 1:
            ax = x + box_w + 2
            out.append(f'<path d="M{ax + 9:.1f},{h - 60} l-8,-5 v10 z" class="arrow"/>')
    out.append("</svg>")
    return f'<figure class="viz">{"".join(out)}<figcaption>{escape(caption)}</figcaption></figure>'


def hbars(items: list[tuple[str, int, str]], caption: str) -> str:
    """横棒で金額を並べる（0から）。items: (名前, 金額, 色の番号)。
    名前は棒の上の行に書く（左に置くと、スマホで文字を大きくしたときに左端からはみ出す）。金額は棒の先。"""
    w, row = 640, 76
    h = row * len(items)
    vmax = max(v for _, v, _ in items)
    pw = w - 150
    out = [f'<svg viewBox="0 0 {w} {h}" role="img" aria-label="{escape(caption)}" class="hbars">']
    for i, (name, value, color) in enumerate(items):
        y0 = i * row
        bw = max(pw * value / vmax, 2)
        out.append(f'<text x="0" y="{y0 + 22}" class="axis strong">{escape(name)}</text>')
        out.append(f'<rect x="0" y="{y0 + 34}" width="{bw:.1f}" height="28" rx="4" class="fill-{color}"><title>{escape(name)} {_yen(value)}</title></rect>')
        out.append(f'<text x="{bw + 10:.1f}" y="{y0 + 55}" class="val">{_yen(value)}</text>')
    out.append("</svg>")
    return f'<figure class="viz">{"".join(out)}<figcaption>{escape(caption)}</figcaption></figure>'
