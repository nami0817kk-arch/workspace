"""数字の図（stats・calc・numberline・line）と、左右の全画面比べ（versus）。figures.draw から呼ばれる。

2026-10-07、別チャンネル「世の中の断面図」の charts3（stats・calc）・charts5（numberline）・charts2（line）・
news4（versus）から移した。断面図は1枚の静止画を返す作りなので、chiso の作り（古紙色の板の上に t=0→1 で
描き進める）に合わせて書き直した。数字の組み方（数字は太く大きく、単位は半分の大きさ）は figures.put_number。

    figure: {type: stats, title: 信長の数字, items: [[生涯, 49年, 本能寺で], [元服, 13歳], [石高, 約700万石, 最盛期]]}
    figure: {type: calc, title: 中国大返し, terms: [[200km, 備中高松→山崎], [7日], [約29km/日, 1日あたり]], ops: [÷, ＝]}
    figure: {type: numberline, title: 享年くらべ, items: [[織田信長, 49], [豊臣秀吉, 62]], unit: 歳, focus: 織田信長}
    figure: {type: line, title: 石高の移り変わり, points: [[1560年, 20], [1570年, 100], [1582年, 700]], unit: 万石}
    figure: {type: versus, title: 同じ年の2人, left: {image: …, name: 織田信長, number: 49歳, note: 本能寺で死す}, right: {…}}

どれも `upto: n` で先頭 n 項目だけ描ける（figures の説明を参照）。注目の1つ（stats・calc は最後、
numberline・line は focus か最後）だけ朱、ほかは墨。
"""
from __future__ import annotations

import math

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

from .figures import (COAST, INKD, PAPER, RED, _ease, _grow, _items, _panel, _steps, fit_number, note_item,
                      number_width, put_number)

SUB = (110, 90, 60)          # 見出し・説明（薄い墨）
RULE = (190, 160, 110)       # 区切りの線
GOLD = (214, 178, 110)


def _fmt(v) -> str:
    """値を画面の数字に（1000 → 1,000、2.5 → 2.5）。文字ならそのまま。"""
    if isinstance(v, bool) or not isinstance(v, (int, float)):
        return str(v)
    if float(v).is_integer():
        return f"{int(v):,}"
    return f"{v:,}"


def _fade(img: Image.Image, p: float, draw_fn, rise: int = 24) -> None:
    """p（0〜1）のぶん、下から少し上がりながら出す。p>=1 はそのまま描く（透明は落とさない）。"""
    if p <= 0:
        return
    if p >= 1:
        draw_fn(ImageDraw.Draw(img, "RGBA"), 0)
        return
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(layer, "RGBA"), int(rise * (1 - _ease(p))))
    layer.putalpha(layer.split()[3].point(lambda v: int(v * _ease(p))))
    img.alpha_composite(layer)


def _note(painter, dr, spec, box, show: bool) -> None:
    if spec.get("note") and show:
        ax0, ay0, ax1, ay1 = box
        dr.text(((ax0 + ax1) / 2, ay1 - 6), str(spec["note"]), font=painter.font("gothic", 28), fill=SUB, anchor="ms")


# --- 数字を並べる（最大3つ） -----------------------------------------------------
def draw_stats(painter, img, spec, t):
    dr, box = _panel(painter, img, spec.get("title", ""))
    ax0, ay0, ax1, ay1 = box
    items = _items(spec["items"])[:3]
    n = len(items)
    lo, hi = _grow(spec, n)
    steps = _steps(t, lo, hi)
    focus = int(spec.get("focus", n - 1)) if not isinstance(spec.get("focus"), str) else \
        next((i for i, it in enumerate(items) if it["label"] == spec["focus"]), n - 1)
    cw = (ax1 - ax0) / max(n, 1)
    bottom = ay1 - (44 if spec.get("note") else 0)
    cy = (ay0 + bottom) / 2
    for i, it in enumerate(items[:hi]):
        x0 = ax0 + i * cw
        cx = x0 + cw / 2
        hot = i == focus
        size = fit_number(painter, str(it["value"]), 150 if hot else 124, cw - 60)
        nw = number_width(painter, str(it["value"]), size)
        note_item(i, (cx - nw / 2, cy + 60 - size * 0.78, cx + nw / 2, cy + 60 + 6))

        def one(d, dy, it=it, cx=cx, hot=hot, size=size, x0=x0, i=i):
            if i:
                d.line([(x0, ay0 + 30), (x0, bottom - 20)], fill=RULE, width=2)
            d.text((cx, cy - 120 + dy), str(it["label"]), font=painter.font("gothic", 38), fill=SUB, anchor="mm")
            w = number_width(painter, str(it["value"]), size)
            put_number(painter, d, cx - w / 2, cy + 60 + dy, str(it["value"]), size, RED if hot else INKD)
            if it.get("note"):
                d.text((cx, cy + 120 + dy), str(it["note"]), font=painter.font("gothic", 30), fill=SUB, anchor="mm")
        _fade(img, steps[i], one)
    _note(painter, ImageDraw.Draw(img, "RGBA"), spec, box, t >= 1 and hi >= n)


# --- 計算の式 -------------------------------------------------------------------
def draw_calc(painter, img, spec, t):
    """200km ÷ 7日 ＝ 約29km/日。項と記号が左から順に出る。最後（答え）だけ大きく朱。"""
    dr, box = _panel(painter, img, spec.get("title", ""))
    ax0, ay0, ax1, ay1 = box
    terms = _items(spec["terms"], ("value", "label"))
    n = len(terms)
    ops = list(spec.get("ops") or (["×"] * (n - 2) + ["＝"]))
    ops += ["＝"] * max(0, n - 1 - len(ops))
    lo, hi = _grow(spec, n)
    # 大きさは全部の項で決める（項が増えても前の項が動かない）
    scale = 1.0
    while True:
        sizes = [int((150 if k == n - 1 else 100) * scale) for k in range(n)]
        of = painter.font("gothic", int(72 * scale))
        widths = [number_width(painter, str(tm["value"]), s) for tm, s in zip(terms, sizes)]
        gap = 36 * scale
        total = sum(widths) + sum(of.getlength(o) + gap * 2 for o in ops[:n - 1])
        if total <= ax1 - ax0 - 40 or scale < 0.4:
            break
        scale -= 0.05
    x = (ax0 + ax1) / 2 - total / 2
    bottom = ay1 - (44 if spec.get("note") else 0)
    base = (ay0 + bottom) / 2 + 50
    # 項と記号を1つずつ（項 → 記号 → 項 …）。新しく出る項の前の記号は、その項と一緒に出る
    steps = _steps(t, lo, hi)
    for k in range(hi):
        hot = k == n - 1
        if k:
            op = ops[k - 1]

            def draw_op(d, dy, x=x, op=op):
                d.text((x + gap, base - sizes[0] * 0.32 + dy), op, font=of, fill=SUB, anchor="lm")
            _fade(img, steps[k], draw_op, rise=0)
            x += of.getlength(op) + gap * 2

        note_item(k, (x, base - sizes[k] * 0.78, x + widths[k], base + 6))

        def draw_term(d, dy, x=x, k=k, hot=hot):
            tm = terms[k]
            put_number(painter, d, x, base + dy, str(tm["value"]), sizes[k], RED if hot else INKD)
            if tm.get("label"):
                d.text((x + widths[k] / 2, base + 50 + dy), str(tm["label"]), font=painter.font("gothic", 30),
                       fill=SUB, anchor="mt")
            if hot:
                d.line([(x - 6, base + 14 + dy), (x + widths[k] + 6, base + 14 + dy)], fill=RED + (200,), width=5)
        _fade(img, steps[k], draw_term)
        x += widths[k]
    _note(painter, ImageDraw.Draw(img, "RGBA"), spec, box, t >= 1 and hi >= n)


# --- 数直線 ---------------------------------------------------------------------
def draw_numberline(painter, img, spec, t):
    """1本の線の上に人物・出来事を並べる（享年・年号の比べ）。点が順に打たれる。"""
    dr, box = _panel(painter, img, spec.get("title", ""))
    ax0, ay0, ax1, ay1 = box
    items = _items(spec["items"], ("label", "value", "note"))
    n = len(items)
    vals = [float(it["value"]) for it in items]
    lo_v = float(spec.get("min", min(vals)))
    hi_v = float(spec.get("max", max(vals)))
    if "min" not in spec or "max" not in spec:
        pad = max(1.0, (hi_v - lo_v) * 0.08)
        lo_v = lo_v - pad if "min" not in spec else lo_v
        hi_v = hi_v + pad if "max" not in spec else hi_v
    span = (hi_v - lo_v) or 1
    unit = str(spec.get("unit", ""))
    focus = spec.get("focus")
    x0, x1 = ax0 + 70, ax1 - 70
    bottom = ay1 - (44 if spec.get("note") else 0)
    ly = (ay0 + bottom) / 2 + 10
    X = lambda v: x0 + (v - lo_v) / span * (x1 - x0)
    dr.line([(x0 - 30, ly), (x1 + 30, ly)], fill=COAST, width=8)
    dr.polygon([(x1 + 30, ly - 14), (x1 + 54, ly), (x1 + 30, ly + 14)], fill=COAST)
    sf = painter.font("gothic", 26)
    for k, v in (("min", lo_v), ("max", hi_v)):
        if k in spec:                                            # 端の目盛りは min・max を書いたときだけ
            dr.line([(X(v), ly - 14), (X(v), ly + 14)], fill=COAST, width=3)
            dr.text((X(v), ly + 24), f"{_fmt(v)}{unit}", font=sf, fill=SUB, anchor="mt")
    lo, hi = _grow(spec, n)
    steps = _steps(t, lo, hi)
    order = sorted(range(n), key=lambda i: vals[i])
    up = {i: (k % 2 == 0) for k, i in enumerate(order)}            # 隣どうしは上と下に分ける
    for i in range(hi):
        it = items[i]
        hot = focus is not None and str(focus) == str(it["label"])
        col = RED if hot else INKD
        px = X(vals[i])
        u = up[i]

        _num = str(it["note"]) or f"{_fmt(it['value'])}{unit}"
        _nw = number_width(painter, _num, 58 if hot else 46) / 2 + 6
        note_item(i, (px - _nw, ly - 200, px + _nw, ly - 104) if u else (px - _nw, ly + 104, px + _nw, ly + 200))

        def one(d, dy, it=it, px=px, u=u, col=col, hot=hot):
            r = 18 if hot else 13
            stem = 96 if u else -96
            d.line([(px, ly), (px, ly - stem)], fill=col, width=4)
            d.ellipse([px - r, ly - r, px + r, ly + r], fill=col, outline=PAPER, width=4)
            lf = painter.font("serif", 38 if hot else 32, bold=True)
            num = str(it["note"]) or f"{_fmt(it['value'])}{unit}"
            size = 58 if hot else 46
            nw = number_width(painter, num, size)
            if u:
                put_number(painter, d, px - nw / 2, ly - 112 + dy, num, size, col)
                d.text((px, ly - 112 - size - 8 + dy), str(it["label"]), font=lf, fill=col, anchor="ms")
            else:
                d.text((px, ly + 110 + dy), str(it["label"]), font=lf, fill=col, anchor="mt")
                put_number(painter, d, px - nw / 2, ly + 152 + size * 0.8 + dy, num, size, col)
        _fade(img, steps[i], one, rise=16)
    _note(painter, ImageDraw.Draw(img, "RGBA"), spec, box, t >= 1 and hi >= n)


# --- 折れ線 ---------------------------------------------------------------------
def draw_line(painter, img, spec, t):
    """移り変わり（石高・人口）。点が左から順に打たれ、線がのびる。最後（または focus）の値だけ大きく朱。"""
    dr, box = _panel(painter, img, spec.get("title", ""))
    ax0, ay0, ax1, ay1 = box
    pts_raw = _items(spec["points"], ("label", "value", "note"))
    n = len(pts_raw)
    vals = [float(p["value"]) for p in pts_raw]
    unit = str(spec.get("unit", ""))
    lo_v = 0.0 if spec.get("zero", True) and min(vals) >= 0 else min(vals)
    hi_v = max(vals)
    span = (hi_v - lo_v) or 1
    bottom = ay1 - (44 if spec.get("note") else 0)
    pl, pr = ax0 + 70, ax1 - 90
    pt, pb = ay0 + 80, bottom - 56
    for k in range(4):                                       # 目盛りの代わりの薄い横線
        gy = pt + (pb - pt) * k / 3
        dr.line([(pl - 20, gy), (pr + 20, gy)], fill=RULE + (140,), width=2)
    step = (pr - pl) / max(n - 1, 1)
    P = [(pl + step * i, pb - (v - lo_v) / span * (pb - pt)) for i, v in enumerate(vals)]
    lo, hi = _grow(spec, n)
    focus = spec.get("focus")
    # 線：前からある区間は描き終え、新しい区間は t でのびる
    e = _ease(t) * max(0, hi - max(lo, 1))
    reach = (max(lo, 1) - 1) + e if hi > lo else hi - 1      # 線の先端（何番目の点まで）
    if hi <= lo:
        reach = hi - 1
    # 大きく朱で出すのは focus、無ければ線がいま届いている最後の点（増える途中も、届くまでは前の点のまま）
    hot_i = next((i for i, p in enumerate(pts_raw) if focus is not None and str(p["label"]) == str(focus)),
                 int(math.floor(reach + 1e-6)))
    area = []
    for i in range(max(0, hi - 1)):
        a, b = P[i], P[i + 1]
        k = max(0.0, min(1.0, reach - i))
        if k <= 0:
            break
        end = (a[0] + (b[0] - a[0]) * k, a[1] + (b[1] - a[1]) * k)
        area += [a, end]
        dr.line([a, end], fill=RED, width=7)
    if len(area) >= 2:
        layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ImageDraw.Draw(layer).polygon(area + [(area[-1][0], pb), (area[0][0], pb)], fill=RED + (36,))
        img.alpha_composite(layer)
        dr = ImageDraw.Draw(img, "RGBA")
    lf = painter.font("gothic", 28)
    for i in range(hi):
        x, y = P[i]
        if i > reach + 1e-6:
            continue                                         # 線がまだ届いていない点は、目盛りの字も出さない
        dr.text((x, pb + 18), str(pts_raw[i]["label"]), font=lf, fill=SUB, anchor="mt")
        hot = i == hot_i
        r = 16 if hot else 10
        dr.ellipse([x - r, y - r, x + r, y + r], fill=RED if hot else PAPER, outline=RED, width=4)
        num = str(pts_raw[i]["note"]) or f"{_fmt(pts_raw[i]['value'])}{unit}"
        size = 64 if hot else 38
        w = number_width(painter, num, size)
        nx = min(max(x - w / 2, ax0 + 10), ax1 - 10 - w)
        put_number(painter, dr, nx, y - r - 14, num, size, RED if hot else INKD, stroke=3, stroke_fill=PAPER)
        note_item(i, (nx, y - r - 14 - size * 0.78, nx + w, y + r))
    _note(painter, ImageDraw.Draw(img, "RGBA"), spec, box, t >= 1 and hi >= n)


# --- 左右の全画面比べ --------------------------------------------------------------
VERSUS_TARGET = 78.0        # 左右の絵の明るさ（灰色の平均）をこの値にそろえる。文字を白で載せて読める暗さ


def _versus_tile(painter, side: dict, w: int, h: int) -> Image.Image:
    key = ("versus", side.get("image"), side.get("x", 0.5), side.get("y", 0.2), w, h)
    if key not in painter._images:
        tile = Image.new("RGB", (w, h), (30, 24, 16))
        if side.get("image"):
            pic = painter.image(str(side["image"])).convert("RGB")
            s = max(w / pic.width, h / pic.height)
            pic = pic.resize((math.ceil(pic.width * s), math.ceil(pic.height * s)), Image.LANCZOS)
            ox = int((pic.width - w) * float(side.get("x", 0.5)))
            oy = int((pic.height - h) * float(side.get("y", 0.2)))
            pic = pic.crop((ox, oy, ox + w, oy + h))
            from PIL import ImageStat
            avg = ImageStat.Stat(pic.convert("L").resize((32, 18))).mean[0]
            tile = ImageEnhance.Brightness(pic).enhance(max(0.3, min(1.4, VERSUS_TARGET / max(avg, 1.0))))
            tile = ImageEnhance.Color(tile).enhance(0.85)
        # 上（名前と数字）を少し暗く、下は字幕と2人のために暗く
        lin = Image.linear_gradient("L").resize((w, h))
        mask = lin.point(lambda v: int(max(0, (v - 150) / 105) * 170))
        top = lin.transpose(Image.FLIP_TOP_BOTTOM).point(lambda v: int(max(0, (v - 120) / 135) * 90))
        dark = Image.new("RGB", (w, h), (12, 10, 8))
        tile = Image.composite(dark, tile, mask)
        tile = Image.composite(dark, tile, top)
        painter._images[key] = tile.convert("RGBA")
    return painter._images[key]


def draw_versus(painter, img, spec, t):
    """2枚の絵を左右に全面で並べ、真ん中に金の縦線。名前と大きな数字を載せる。左 → 右の順に出る。"""
    W, H = img.size
    half = W // 2
    steps = _steps(t, 0, 2)
    for k, key in enumerate(("left", "right")):
        side = spec.get(key) or {}
        tile = _versus_tile(painter, side, half, H)
        p = steps[k]
        if p <= 0:
            continue
        if p < 1:
            tile = tile.copy()
            tile.putalpha(tile.split()[3].point(lambda v: int(v * _ease(p))))
        img.alpha_composite(tile, (k * half, 0))
    dr = ImageDraw.Draw(img, "RGBA")
    lh = H * _ease(min(1.0, t * 1.5))
    dr.rectangle([half - 5, (H - lh) / 2, half + 5, (H + lh) / 2], fill=GOLD)
    for k, key in enumerate(("left", "right")):
        side = spec.get(key) or {}
        cx = half / 2 + k * half

        def one(d, dy, side=side, cx=cx):
            name = str(side.get("name", ""))
            if name:
                nf = painter.font("serif", 68, bold=True)
                d.text((cx, 270 + dy), name, font=nf, fill=(250, 244, 228), anchor="ms", stroke_width=6,
                       stroke_fill=(12, 10, 8))
            num = str(side.get("number", ""))
            if num:
                size = fit_number(painter, num, 190, half - 160)
                if not dy:
                    w0 = number_width(painter, num, size)
                    note_item(k, (cx - w0 / 2, 300 + size * 0.95 - size * 0.78, cx + w0 / 2, 300 + size * 0.95 + 6))
                w = number_width(painter, num, size)
                hot = side.get("focus", True)
                put_number(painter, d, cx - w / 2, 300 + size * 0.95 + dy, num, size,
                           GOLD if hot else (250, 244, 228), stroke=8, stroke_fill=(12, 10, 8))
            note = str(side.get("note", ""))
            if note:
                nf = painter.font("gothic", 38)
                d.text((cx, 300 + 190 * 0.95 + 70 + dy), note, font=nf, fill=(240, 228, 200), anchor="mm",
                       stroke_width=4, stroke_fill=(12, 10, 8))
        _fade(img, max(0.0, min(1.0, (t - 0.35 - 0.2 * k) / 0.45)) if t < 1 else 1.0, one)
    title = str(spec.get("title", ""))
    if title:
        dr = ImageDraw.Draw(img, "RGBA")
        tf = painter.font("serif", 48, bold=True)
        tw = tf.getlength(title)
        x0, x1 = W / 2 - tw / 2 - 44, W / 2 + tw / 2 + 44
        shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ImageDraw.Draw(shadow).rounded_rectangle([x0 + 6, 58, x1 + 6, 142], radius=12, fill=(0, 0, 0, 150))
        img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(8)))
        dr = ImageDraw.Draw(img, "RGBA")
        dr.rounded_rectangle([x0, 50, x1, 134], radius=12, fill=(120, 30, 26, 245), outline=GOLD, width=3)
        dr.text((W / 2, 92), title, font=tf, fill=(255, 248, 230), anchor="mm")
    credit = str(spec.get("credit", ""))
    if credit:
        dr.text((W / 2, H - 14), credit, font=painter.font("serif", 18), fill=(176, 164, 140), anchor="ms",
                stroke_width=2, stroke_fill=(12, 10, 8))
