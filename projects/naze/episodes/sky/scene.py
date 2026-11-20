"""空の色の回の画面。行の scene=dict(kind=…) を描く(無い行は前の行を引き継ぐ)。場面が変わると 0.5 秒で溶け合わせる。

kind: sky / prism / waves / scatter / formula / spectrum / layers / moon / path / airmass / sunset / cloud / mars
scene に panel=dict(kind="big"|"compare"|…) があれば naze.mapscene の枠を重ね、絵は残りの場所に寄せる。
数字の出どころは ../research.md(レイリー散乱の 1/λ⁴、Kasten & Young 1989 の空気の通り道の式、大気の質量の高さ分布)。
"""
from __future__ import annotations

import math
import random

from PIL import Image, ImageDraw, ImageFilter

from naze import mapscene, overlay as O
from naze.config import H, W

LAND = W > H
S = min(W, H) / 1080


def _ease(u):
    u = max(0.0, min(1.0, u))
    return u * u * (3 - 2 * u)


def wl_rgb(nm: float) -> tuple:
    """波の長さ(nm)のおよその色。"""
    if nm < 440:
        r, g, b = -(nm - 440) / 60, 0.0, 1.0
    elif nm < 490:
        r, g, b = 0.0, (nm - 440) / 50, 1.0
    elif nm < 510:
        r, g, b = 0.0, 1.0, -(nm - 510) / 20
    elif nm < 580:
        r, g, b = (nm - 510) / 70, 1.0, 0.0
    elif nm < 645:
        r, g, b = 1.0, -(nm - 645) / 65, 0.0
    else:
        r, g, b = 1.0, 0.0, 0.0
    f = 0.45 + 0.55 * (nm - 380) / 40 if nm < 420 else (0.45 + 0.55 * (750 - nm) / 50 if nm > 700 else 1.0)
    return tuple(int(255 * max(0, min(1, c * f)) ** 0.8) for c in (r, g, b))


COL = dict(violet=wl_rgb(410), blue=(70, 140, 255), green=wl_rgb(530), yellow=wl_rgb(580), red=(240, 60, 50))


def grad(img, top, bot, box=None):
    x0, y0, x1, y1 = box or (0, 0, W, H)
    d = ImageDraw.Draw(img)
    n = int(y1 - y0)
    for i in range(0, n, 2):
        u = i / max(1, n)
        c = tuple(int(top[j] + (bot[j] - top[j]) * u) for j in range(3))
        d.rectangle([x0, y0 + i, x1, y0 + i + 2], fill=c)


def glow(img, cx, cy, r, col, a=1.0):
    lay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    for i in range(12, 0, -1):
        rr = r * (1 + i * 0.35)
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=col + (int(18 * a),))
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 255, 245, int(255 * a)))
    img.alpha_composite(lay)


def text(d, xy, s, size, col=O.WHITE, anchor="la", stroke=5):
    d.text(xy, s, font=O.font(int(size * S)), fill=col, anchor=anchor, stroke_width=stroke, stroke_fill=O.NAVY)


def label(d, xy, s, size=40, col=O.WHITE, anchor="mm"):
    """白い字の小さな札(箱つき)。重なりの点検に載せる。"""
    f = O.font(int(size * S))
    bb = d.textbbox(xy, s, font=f, anchor=anchor)
    pad = 12 * S
    box = (bb[0] - pad, bb[1] - pad * 0.7, bb[2] + pad, bb[3] + pad * 0.7)
    d.rounded_rectangle(box, int(10 * S), fill=O.NAVY + (220,), outline=col, width=max(2, int(3 * S)))
    d.text(xy, s, font=f, fill=col, anchor=anchor)
    O.BOXES.append(("label", box, s, 1.0))


# ---- Gemini で作った写真風の絵(assets/*_gemini.jpg)-------------------------------------------

from pathlib import Path

ASSETS = Path(__file__).resolve().parent / "assets"
FOCUS = dict(bluesky=0.62, cloud=0.5, mars_day=0.55, mars_sunset=0.5, moon=0.42, sunset=0.6)
_PH = {}


def photo(img, name, box):
    """絵を画面いっぱいに敷く。縦では絵の範囲(box)に合わせ、上下はぼかした同じ絵で埋める。"""
    key = (name, W, H)
    if key not in _PH:
        im = Image.open(ASSETS / f"{name}_gemini.jpg").convert("RGB")
        fx = FOCUS.get(name, 0.5)

        def cover(w, h):
            s = max(w / im.width, h / im.height)
            r = im.resize((int(im.width * s + 1), int(im.height * s + 1)), Image.LANCZOS)
            x = int(max(0, min(r.width - w, r.width * fx - w / 2)))
            return r.crop((x, (r.height - h) // 2, x + w, (r.height - h) // 2 + h))
        if LAND:
            out = cover(W, H)
        else:
            x0, y0, x1, y1 = box
            out = cover(W, H).filter(ImageFilter.GaussianBlur(28))
            out = Image.eval(out, lambda v: int(v * 0.55))
            out.paste(cover(int(x1 - x0), int(y1 - y0)), (int(x0), int(y0)))
        out = out.convert("RGBA")
        sh = Image.new("RGBA", out.size, (0, 0, 0, 0))            # 字幕の下だけ暗くして読みやすく
        ds = ImageDraw.Draw(sh)
        y_sub = 975 if LAND else 1640
        for i in range(260):
            ds.line([(0, y_sub - 200 + i), (W, y_sub - 200 + i)], fill=(5, 10, 25, int(min(1, i / 160) * 170)))
        ds.rectangle([0, y_sub + 60, W, H], fill=(5, 10, 25, 170))
        out.alpha_composite(sh)
        _PH[key] = out
    img.alpha_composite(_PH[key])
    d = ImageDraw.Draw(img)
    text(d, (W - 24 * S, (24 if LAND else 120) * S), "絵はAIで作成", 26, O.DIM, "ra", 3)


# ---- 場面 -------------------------------------------------------------------------------

def sc_sky(img, box, t, k, P):
    photo(img, "bluesky", box)


def _clouds(img, t, y):
    lay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    rnd = random.Random(3)
    for i in range(4):
        cx = (rnd.random() * W * 1.3 + t * 18 * S * (1 + i * 0.3)) % (W * 1.3) - W * 0.15
        cy = y + rnd.uniform(-60, 60) * S
        for j in range(7):
            r = rnd.uniform(40, 80) * S
            dx = (j - 3) * 45 * S
            d.ellipse([cx + dx - r, cy - r * 0.8 + abs(j - 3) * 10 * S, cx + dx + r, cy + r * 0.6], fill=(255, 255, 255, 210))
    img.alpha_composite(lay.filter(ImageFilter.GaussianBlur(4 * S)))


def sc_prism(img, box, t, k, P):
    grad(img, (10, 18, 40), (16, 28, 60))
    x0, y0, x1, y1 = box
    cx, cy = x0 + (x1 - x0) * 0.42, (y0 + y1) / 2
    s = (y1 - y0) * 0.28
    d = ImageDraw.Draw(img)
    tri = [(cx, cy - s), (cx - s * 0.9, cy + s * 0.6), (cx + s * 0.9, cy + s * 0.6)]
    ex, ey = cx - s * 0.42, cy - s * 0.05
    d.line([(x0 + 20 * S, cy - s * 0.55), (ex, ey)], fill=(255, 255, 250), width=int(16 * S))
    text(d, (x0 + 30 * S, cy - s * 0.55 - 70 * S), "太陽の光", 44)
    u = _ease(k * 2.2)
    cols = [wl_rgb(n) for n in (420, 460, 500, 540, 580, 620, 680)]
    sx, sy = cx + s * 0.35, cy + s * 0.08
    lay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    dl = ImageDraw.Draw(lay)
    for i, c in enumerate(cols):
        a0 = math.radians(-6 + i * 4.2)
        L = (x1 - sx - 30 * S) * u
        dl.polygon([(ex, ey), (sx, sy), (sx + L * math.cos(a0), sy + L * math.sin(a0)),
                    (sx + L * math.cos(a0 + math.radians(4.2)), sy + L * math.sin(a0 + math.radians(4.2)))], fill=c + (230,))
    img.alpha_composite(lay)
    d = ImageDraw.Draw(img)
    d.polygon(tri, fill=(170, 200, 230, 90), outline=(230, 240, 255), width=int(4 * S))
    shim = 0.5 + 0.5 * math.sin(t * 3)
    d.line([(x0 + 20 * S, cy - s * 0.55), (ex, ey)], fill=(255, 255, int(200 + 50 * shim)), width=int(6 * S))


WAVES = [(400, "紫"), (450, "青"), (530, "緑"), (580, "黄"), (700, "赤")]


def sc_waves(img, box, t, k, P):
    grad(img, (10, 18, 40), (14, 26, 56))
    x0, y0, x1, y1 = box
    rows = P.get("rows", WAVES)
    d = ImageDraw.Draw(img)
    n = len(rows)
    lx = x0 + (x1 - x0) * 0.06
    gx0, gx1 = x0 + (x1 - x0) * 0.27, x1 - (x1 - x0) * 0.05
    hh = (y1 - y0) / (n + 0.4)
    amp = hh * 0.28
    scale = (gx1 - gx0) / 4.2 / 520                          # 520nm の波が 4 つほど入る
    for i, (nm, name) in enumerate(rows):
        if k * (n + 1) * 2.2 < i:
            break
        cy = y0 + hh * (i + 0.7)
        c = wl_rgb(nm) if nm != 450 else COL["blue"]
        lam = nm * scale
        ph = t * 160 * S
        pts = [(x, cy - amp * math.sin(2 * math.pi * (x - gx0 - ph) / lam)) for x in range(int(gx0), int(gx1), 3)]
        hl = P.get("hl")
        w = int((9 if hl in (None, nm) else 4) * S)
        d.line(pts, fill=c if hl in (None, nm) else tuple(int(v * 0.45) for v in c), width=w, joint="curve")
        text(d, (lx, cy), f"{name}", 52, c, "lm")
        text(d, (lx + 80 * S, cy), f"{nm}nm", 40, O.DIM, "lm", 4)
    if P.get("note"):
        text(d, ((x0 + x1) / 2, y1 - 10 * S), P["note"], 38, O.DIM, "md", 4)


def sc_scatter(img, box, t, k, P):
    grad(img, (12, 24, 54), (24, 50, 100))
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    rnd = random.Random(7)
    parts = [(x0 + (x1 - x0) * rnd.uniform(0.3, 0.95), y0 + (y1 - y0) * rnd.uniform(0.15, 0.85)) for _ in range(26)]
    for (px, py) in parts:
        d.ellipse([px - 10 * S, py - 10 * S, px + 10 * S, py + 10 * S], fill=(200, 210, 225))
    by = y0 + (y1 - y0) * 0.5
    d.line([(x0, by), (x1, by)], fill=(255, 255, 240), width=int(14 * S))
    text(d, (x0 + 20 * S, by - 60 * S), "太陽の光", 42)
    lay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    dl = ImageDraw.Draw(lay)
    period = 2.4
    for j in range(110):
        r2 = random.Random(100 + j)
        ph = (t / period + r2.random()) % 1.0
        blue = r2.random() < P.get("blue", 0.86)
        c = COL["blue"] if blue else COL["red"]
        if blue:                                                 # 粒にぶつかって四方へ
            px, py = parts[j % len(parts)]
            ang = r2.uniform(0, 2 * math.pi)
            L = ph * (x1 - x0) * 0.35 + 50 * S
            hx, hy = px + L * math.cos(ang), py + L * math.sin(ang)
            dl.line([(px + (L - 50 * S) * math.cos(ang), py + (L - 50 * S) * math.sin(ang)), (hx, hy)], fill=c + (int(255 * min(1, 1.6 * (1 - ph))),), width=int(9 * S))
        else:                                                    # 赤はまっすぐ抜ける
            hx = x0 + ph * (x1 - x0)
            yy = by + r2.uniform(-8, 8) * S
            dl.line([(hx - 60 * S, yy), (hx, yy)], fill=c + (255,), width=int(10 * S))
    img.alpha_composite(lay)
    if P.get("eye"):
        d = ImageDraw.Draw(img)
        ex, ey = (x0 + x1) / 2, y1 - 40 * S
        d.ellipse([ex - 34 * S, ey - 20 * S, ex + 34 * S, ey + 20 * S], fill=O.WHITE)
        d.ellipse([ex - 13 * S, ey - 13 * S, ex + 13 * S, ey + 13 * S], fill=(30, 40, 60))
    d = ImageDraw.Draw(img)
    label(d, (x0 + (x1 - x0) * 0.22, y0 + 40 * S), "● 空気の粒", 36, O.DIM)


def sc_formula(img, box, t, k, P):
    grad(img, (10, 18, 40), (14, 26, 56))
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    cx = (x0 + x1) / 2
    rows = P["rows"]
    gap = (y1 - y0) / (len(rows) + 1)
    for i, (s, size, col) in enumerate(rows):
        a = _ease(k * (len(rows) + 0.5) * 1.8 - i)
        if a <= 0:
            continue
        c = tuple(int(v * a + 20 * (1 - a)) for v in col)
        text(d, (cx, y0 + gap * (i + 1) + 6 * S * math.sin(t * 1.3 + i)), s, size, c, "mm", 6)


def _planck(nm, T=5778.0):
    l = nm * 1e-9
    return 1 / (l ** 5 * (math.exp(1.4388e-2 / (l * T)) - 1))


def sc_spectrum(img, box, t, k, P):
    grad(img, (10, 18, 40), (14, 26, 56))
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    gx0, gx1 = x0 + (x1 - x0) * 0.1, x1 - (x1 - x0) * 0.06
    gy0, gy1 = y0 + (y1 - y0) * 0.16, y1 - (y1 - y0) * 0.16
    top = max(_planck(n) for n in range(380, 701, 5))
    u = _ease(k * 1.6)
    for n in range(380, 701, 2):
        if (n - 380) / 320 > u:
            break
        x = gx0 + (gx1 - gx0) * (n - 380) / 320
        h = (gy1 - gy0) * _planck(n) / top
        d.rectangle([x, gy1 - h, x + (gx1 - gx0) / 160 + 1, gy1], fill=wl_rgb(n))
    d.line([(gx0, gy1), (gx1, gy1)], fill=O.DIM, width=int(3 * S))
    for n, s in ((400, "紫"), (450, "青"), (550, "緑"), (650, "赤")):
        x = gx0 + (gx1 - gx0) * (n - 380) / 320
        text(d, (x, gy1 + 16 * S), s, 40, O.DIM, "ma", 4)
    text(d, (gx0, gy0 - 50 * S), P.get("title", "太陽の光の、色ごとの量（およその形）"), 40, O.DIM, "la", 4)
    sx = gx0 + (gx1 - gx0) * ((t * 0.12) % 1.0)
    d.line([(sx, gy0), (sx, gy1)], fill=(255, 255, 255, 60), width=int(2 * S))
    if P.get("hl_violet") and u >= 1:
        label(d, (gx0 + (gx1 - gx0) * 0.06, gy0 + (gy1 - gy0) * 0.25), "紫は少ない", 44, O.YEL)


def sc_layers(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, (0, 0, 6), (90, 160, 235), (0, y0, W, y1))
    d = ImageDraw.Draw(img)
    km = lambda z: y1 - (y1 - y0) * min(1.0, z / 36)
    rnd = random.Random(5)
    for i in range(260):                                         # 空気の粒は下ほど多い(約 5.5km ごとに半分)
        z = -5.5 / math.log(2) * math.log(1 - rnd.random() * 0.995)
        x = (x0 + (x1 - x0) * rnd.random() + t * 12 * S * (1 + rnd.random())) % (x1 - x0) + x0
        y = km(z)
        if y > y0:
            d.ellipse([x - 3 * S, y - 3 * S, x + 3 * S, y + 3 * S], fill=(230, 240, 255))
    d.rectangle([0, y1 - 8 * S, W, y1 + 40 * S], fill=(60, 80, 60))
    u = _ease(k * 2)
    for z, s, col in P.get("marks", [(5.5, "地上5.5km  空気の半分", O.YEL), (30, "約30km  空気の99%", O.WHITE)]):
        if u <= 0:
            break
        y = km(z)
        d.line([(x0 + 20 * S, y), (x1 - 20 * S, y)], fill=col, width=int(4 * S))
        label(d, (x0 + (x1 - x0) * 0.62, y - 36 * S), s, 40, col)


def sc_moon(img, box, t, k, P):
    photo(img, "moon", box)
    x0, y0, x1, y1 = box
    label(ImageDraw.Draw(img), ((x0 + x1) / 2, y0 + (y1 - y0) * 0.62), P.get("note", "月の空：昼でも真っ黒"), 46, O.YEL)


def airmass(h):
    return 1 / (math.sin(math.radians(h)) + 0.50572 * (h + 6.07995) ** -1.6364)


def sc_path(img, box, t, k, P):
    grad(img, (8, 14, 34), (14, 26, 56))
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    R = (x1 - x0) * 1.6
    cx, cy = (x0 + x1) / 2, y1 - 110 * S + R
    th = R * 0.07
    lay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    dl = ImageDraw.Draw(lay)
    dl.ellipse([cx - R - th, cy - R - th, cx + R + th, cy + R + th], fill=(70, 140, 230, 110))
    img.alpha_composite(lay)
    d = ImageDraw.Draw(img)
    d.ellipse([cx - R, cy - R, cx + R, cy + R], fill=(30, 70, 50))
    ox, oy = cx, cy - R
    e0, e1 = P.get("elev", (90, 90))
    h = e0 + (e1 - e0) * _ease(k * 1.3)
    a = math.radians(h)
    dx, dy = math.cos(a), -math.sin(a)
    # 空気の層の外側まで(円との交点)
    b = 2 * ((ox - cx) * dx + (oy - cy) * dy)
    c = (ox - cx) ** 2 + (oy - cy) ** 2 - (R + th) ** 2
    s = (-b + math.sqrt(b * b - 4 * c)) / 2
    ex, ey = ox + dx * s, oy + dy * s
    far = 2000 * S
    d.line([(ex, ey), (ex + dx * far, ey + dy * far)], fill=(255, 250, 220), width=int(6 * S))
    d.line([(ox, oy), (ex, ey)], fill=O.YEL, width=int(12 * S))
    sx, sy = ox + dx * min(far, (x1 - x0) * 0.42), oy + dy * min(far, (x1 - x0) * 0.42)
    sx, sy = max(x0 + 60 * S, min(x1 - 60 * S, sx)), max(y0 + 60 * S, sy)
    glow(img, sx, sy, 34 * S, (255, 240, 200))
    d = ImageDraw.Draw(img)
    d.ellipse([ox - 12 * S, oy - 12 * S, ox + 12 * S, oy + 12 * S], fill=O.WHITE)
    label(d, (ox, oy + 50 * S), "見ている人", 34, O.DIM)
    label(d, (x0 + (x1 - x0) * 0.2, y0 + 50 * S), f"太陽の高さ {h:.0f}度", 40, O.WHITE)
    label(d, (x0 + (x1 - x0) * 0.2, y0 + 130 * S), f"空気の道のり 約{airmass(h):.1f}倍" if airmass(h) < 9.95 else f"空気の道のり 約{airmass(h):.0f}倍", 40, O.YEL)


def sc_airmass(img, box, t, k, P):
    grad(img, (10, 18, 40), (14, 26, 56))
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    gx0, gx1 = x0 + (x1 - x0) * 0.13, x1 - (x1 - x0) * 0.06
    gy0, gy1 = y0 + (y1 - y0) * 0.14, y1 - (y1 - y0) * 0.16
    px = lambda h: gx0 + (gx1 - gx0) * (90 - h) / 90
    py = lambda m: gy1 - (gy1 - gy0) * m / 40
    d.line([(gx0, gy1), (gx1, gy1)], fill=O.DIM, width=int(3 * S))
    d.line([(gx0, gy0), (gx0, gy1)], fill=O.DIM, width=int(3 * S))
    for m in (0, 10, 20, 30, 40):
        text(d, (gx0 - 14 * S, py(m)), f"{m}", 32, O.DIM, "rm", 3)
    for h in (90, 60, 30, 10, 0):
        text(d, (px(h), gy1 + 14 * S), f"{h}度", 32, O.DIM, "ma", 3)
    text(d, (gx0, gy0 - 50 * S), "空気の道のり（真上を1とした倍）", 38, O.DIM, "la", 4)
    text(d, (gx1, gy1 + 60 * S), "太陽の高さ →低い", 32, O.DIM, "ra", 3)
    u = _ease(k * 1.4)
    pts = [(px(h / 4), py(min(40, airmass(h / 4)))) for h in range(360, -1, -1) if (90 - h / 4) / 90 <= u]
    if len(pts) > 1:
        d.line(pts, fill=O.YEL, width=int(7 * S), joint="curve")
    for h, s in P.get("pts", []):
        if (90 - h) / 90 <= u:
            m = airmass(h)
            d.ellipse([px(h) - 12 * S, py(m) - 12 * S, px(h) + 12 * S, py(m) + 12 * S], fill=O.WHITE)
            label(d, (px(h) - 150 * S, py(m)), s, 40, O.YEL)
    hd = 90 * (0.5 + 0.5 * math.sin(t * 0.5)) * u
    m = airmass(90 - hd)
    d.ellipse([px(90 - hd) - 7 * S, py(m) - 7 * S, px(90 - hd) + 7 * S, py(m) + 7 * S], fill=(255, 255, 255, 160))


def sc_sunset(img, box, t, k, P):
    photo(img, "sunset", box)


def sc_cloud(img, box, t, k, P):
    photo(img, "cloud", box)
    x0, y0, x1, y1 = box
    label(ImageDraw.Draw(img), ((x0 + x1) / 2, y0 + 50 * S), P.get("note", "大きな粒は、どの色も同じように散らばらせる"), 40, O.WHITE)


def sc_mars(img, box, t, k, P):
    photo(img, "mars_sunset" if P.get("time") == "sunset" else "mars_day", box)
    x0, y0, x1, y1 = box
    label(ImageDraw.Draw(img), ((x0 + x1) / 2, y0 + 60 * S), P.get("note", "火星（想像の絵）"), 40, O.WHITE)


KINDS = dict(sky=sc_sky, prism=sc_prism, waves=sc_waves, scatter=sc_scatter, formula=sc_formula, spectrum=sc_spectrum, layers=sc_layers,
             moon=sc_moon, path=sc_path, airmass=sc_airmass, sunset=sc_sunset, cloud=sc_cloud, mars=sc_mars)


def region(P):
    if P.get("panel"):
        return (0, 100, W * 0.5, 880) if LAND else (0, 230, W, 740)
    return (0, 100, W, 880) if LAND else (0, 240, W, 1480)


def paint(sc, t, k):
    img = Image.new("RGBA", (W, H), (10, 18, 40, 255))
    KINDS[sc["kind"]](img, region(sc), t, k, sc)
    return img


def draw(img, dr, t, ctx):
    lines, defs = ctx["lines"], ctx["defs"]
    scs = ctx.setdefault("_scenes", mapscene.scenes(lines, defs))
    cur = ctx["cur"] or lines[0]
    i = next(j for j, l in enumerate(lines) if l["id"] == cur["id"])
    now, prev = scs[i], (scs[i - 1] if i > 0 else None)
    k = ctx["k"]
    u = _ease((t - cur["start"]) / 0.5)
    b = paint(prev, t, 1.0) if prev is not None and prev is not now and u < 1 else None
    O.BOXES.clear()                                  # 重なりの点検は今の場面の札だけ見る
    a = paint(now, t, k)
    if b is not None:
        a = Image.blend(b, a, u)
    z = 1.0 + 0.025 * (0.5 + 0.5 * math.sin(2 * math.pi * t / 14.0))   # ゆっくり寄り引き(画面を止めない)
    if z > 1.0005:
        zw, zh = int(W * z), int(H * z)
        a = a.resize((zw, zh), Image.BILINEAR).crop(((zw - W) // 2, (zh - H) // 2, (zw - W) // 2 + W, (zh - H) // 2 + H))
    img.paste(a, (0, 0))
    P = now.get("panel")
    if P and not ctx.get("cta"):
        if prev is not None and prev.get("panel") is P:
            mapscene.draw_panel(img, P, 1.0, 1.0)
        else:
            t0 = cur["start"] + P.get("at", 0.0) * (cur["end"] - cur["start"])
            mapscene.draw_panel(img, P, _ease((t - t0) / 0.4), _ease((t - t0) / max(0.4, P.get("grow", 1.2))))


def sfx_for(lines_def, L):
    return mapscene.sfx(lines_def, L)
