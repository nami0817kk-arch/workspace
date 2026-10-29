"""深海魚の回の画面。行の scene=dict(kind=…) を描く(無い行は前の行を引き継ぐ)。場面が変わると 0.5 秒で溶け合わせる。
計算の図は全部コードで描く。AI で作った絵は assets/fish_gemini.jpg(魚・クサウオ)と assets/sub_gemini.jpg(潜水艇)だけ。
ファイルが無いときは、コードで描いた魚・潜水艇の影絵にする。

kind: photo(魚・潜水艇の絵) / strip(深さの断面と指先にかかる重さ) / weight(指先に重りが乗る) / piston(空気が縮む・肺) /
      bottle(ペットボトルが沈む・空気の粒) / cup(発泡スチロールのカップ) / bladder(うきぶくろ) / jar(1L の水が縮む・空気と並べる) /
      sea(海面が上がる) / fishsec(魚の体の水の割合) / balance(内と外の押し合い) / hull(潜水艇の殻の断面) /
      spheres(2つの球・魚と潜水艇) / protein(たんぱく質の形) / bars(TMAO の棒グラフ) / osm(体の液と海水の濃さ) /
      map(伊豆・小笠原海溝) / list(実験の一覧) / deep(暗い海と雪のような粒)
数字の出どころは ../research.md。水圧は TEOS-10(gsw)、空気はボイルの法則、殻は球の殻の応力(しんかい6500 と同じ余裕)。
"""
from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

from naze import mapscene, overlay as O
from naze.config import H, W

LAND = W > H
S = min(W, H) / 1080
ASSETS = Path(__file__).resolve().parent / "assets"
QUIET = [False]              # 問いの行は札を出さない(大きな問いの字と重なるので)
SEA0, SEA1 = (70, 150, 200), (6, 12, 30)
SKIN = (222, 170, 140)
FISH = (150, 190, 215)


def _ease(u):
    u = max(0.0, min(1.0, u))
    return u * u * (3 - 2 * u)


def lerp(a, b, u):
    return tuple(int(a[i] + (b[i] - a[i]) * u) for i in range(3))


def grad(img, top, bot, box=None):
    x0, y0, x1, y1 = box or (0, 0, W, H)
    d = ImageDraw.Draw(img)
    n = int(y1 - y0)
    for i in range(0, n, 2):
        d.rectangle([x0, y0 + i, x1, y0 + i + 2], fill=lerp(top, bot, i / max(1, n)))


def bg(img, box=None):
    grad(img, (10, 22, 48), (6, 12, 30), box)


def text(d, xy, s, size, col=O.WHITE, anchor="la", stroke=5):
    d.text(xy, s, font=O.font(int(size * S)), fill=col, anchor=anchor, stroke_width=stroke, stroke_fill=O.NAVY)


def fit_text(d, xy, s, size, maxw, col=O.YEL, anchor="mm", stroke=6):
    sz = int(size * S)
    while sz > 20 and O.font(sz).getlength(s) > maxw:
        sz -= 4
    d.text(xy, s, font=O.font(sz), fill=col, anchor=anchor, stroke_width=stroke, stroke_fill=O.NAVY)


def label(d, xy, s, size=40, col=O.WHITE, anchor="mm"):
    """白い字の小さな札(箱つき)。重なりの点検に載せる。"""
    if QUIET[0]:
        return
    f = O.font(int(size * S))
    bb = d.textbbox(xy, s, font=f, anchor=anchor)
    pad = 12 * S
    box = (bb[0] - pad, bb[1] - pad * 0.7, bb[2] + pad, bb[3] + pad * 0.7)
    d.rounded_rectangle(box, int(10 * S), fill=O.NAVY + (220,), outline=col, width=max(2, int(3 * S)))
    d.text(xy, s, font=f, fill=col, anchor=anchor)
    O.BOXES.append(("label", box, s, 1.0))


def arrow(d, a, b, col, w=6, head=22):
    d.line([a, b], fill=col, width=int(w * S))
    ang = math.atan2(b[1] - a[1], b[0] - a[0])
    h = head * S
    d.polygon([b, (b[0] - h * math.cos(ang - 0.45), b[1] - h * math.sin(ang - 0.45)),
               (b[0] - h * math.cos(ang + 0.45), b[1] - h * math.sin(ang + 0.45))], fill=col)


def snow(img, box, t, n=70, seed=3, alpha=150):
    """暗い海に降る小さな粒(画面を止めない)。"""
    x0, y0, x1, y1 = box
    rnd = random.Random(seed)
    lay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    for _ in range(n):
        u, v, sp, r = rnd.random(), rnd.random(), rnd.uniform(0.012, 0.035), rnd.uniform(1.5, 4.0)
        y = y0 + ((v + t * sp) % 1.0) * (y1 - y0)
        x = x0 + u * (x1 - x0) + 14 * S * math.sin(t * 0.5 + u * 20)
        d.ellipse([x - r * S, y - r * S, x + r * S, y + r * S], fill=(200, 215, 230, alpha))
    img.alpha_composite(lay)


def fish_side(d, cx, cy, L, col=FISH, tail=True, eye=True):
    """全長 L・頭が右の魚の影絵(丸い頭に細い尾)。"""
    h = L * 0.34
    d.ellipse([cx - L * 0.3, cy - h / 2, cx + L * 0.5, cy + h / 2], fill=col)
    d.polygon([(cx - L * 0.2, cy - h * 0.28), (cx - L * 0.5, cy - h * 0.1), (cx - L * 0.5, cy + h * 0.1), (cx - L * 0.2, cy + h * 0.28)], fill=col)
    if tail:
        d.polygon([(cx - L * 0.46, cy), (cx - L * 0.62, cy - h * 0.45), (cx - L * 0.62, cy + h * 0.45)], fill=col)
    d.polygon([(cx - L * 0.05, cy - h * 0.45), (cx + L * 0.1, cy - h * 0.8), (cx + L * 0.2, cy - h * 0.42)], fill=col)
    if eye:
        r = L * 0.028
        d.ellipse([cx + L * 0.33 - r, cy - h * 0.12 - r, cx + L * 0.33 + r, cy - h * 0.12 + r], fill=(12, 20, 40))


def sub_side(d, cx, cy, L, col=(220, 225, 232)):
    """潜水艇の影絵(丸い船体に窓と小さな足)。"""
    d.ellipse([cx - L * 0.5, cy - L * 0.3, cx + L * 0.5, cy + L * 0.3], fill=col)
    d.rectangle([cx - L * 0.12, cy - L * 0.42, cx + L * 0.12, cy - L * 0.22], fill=col)
    d.ellipse([cx + L * 0.2, cy - L * 0.12, cx + L * 0.4, cy + L * 0.08], fill=(30, 60, 90), outline=(120, 160, 190), width=max(2, int(L * 0.01)))
    d.line([(cx - L * 0.35, cy + L * 0.34), (cx + L * 0.35, cy + L * 0.34)], fill=col, width=max(3, int(L * 0.03)))
    d.line([(cx - L * 0.2, cy + L * 0.28), (cx - L * 0.2, cy + L * 0.34)], fill=col, width=max(3, int(L * 0.03)))
    d.line([(cx + L * 0.2, cy + L * 0.28), (cx + L * 0.2, cy + L * 0.34)], fill=col, width=max(3, int(L * 0.03)))
    d.ellipse([cx - L * 0.62, cy - L * 0.08, cx - L * 0.5, cy + L * 0.04], fill=(160, 170, 180))


# ---- 絵(AI)とそのかわりの影絵 ----------------------------------------------------------------
_PH = {}


def sc_photo(img, box, t, k, P):
    name = P["name"]
    x0, y0, x1, y1 = box
    path = ASSETS / f"{name}_gemini.jpg"
    if not path.exists():
        grad(img, (14, 36, 70), (4, 8, 20), (0, 0, W, H))
        d = ImageDraw.Draw(img)
        cx, cy = W / 2, (y0 + y1) / 2
        sway = 14 * S * math.sin(t * 0.7)
        if name == "sub":
            ls = min(W * 0.5, 720 * S)
            beam = Image.new("RGBA", img.size, (0, 0, 0, 0))
            ImageDraw.Draw(beam).polygon([(cx + ls * 0.4, cy - ls * 0.02 + sway), (cx + ls * 1.5, cy - ls * 0.5), (cx + ls * 1.5, cy + ls * 0.5)], fill=(255, 245, 190, 55))
            img.alpha_composite(beam)
            sub_side(ImageDraw.Draw(img), cx - ls * 0.15, cy + sway, ls * 0.8)
        else:
            lf = min(W * 0.34, 520 * S) if LAND else W * 0.5
            fish_side(d, cx, cy + sway, lf)
        snow(img, (0, 0, W, H), t, 80)
    else:
        key = (name, W, H)
        if key not in _PH:
            im = Image.open(path).convert("RGB")

            def cover(w, h):
                s = max(w / im.width, h / im.height)
                r = im.resize((int(im.width * s + 1), int(im.height * s + 1)), Image.LANCZOS)
                return r.crop(((r.width - w) // 2, (r.height - h) // 2, (r.width - w) // 2 + w, (r.height - h) // 2 + h))
            if LAND:
                out = cover(W, H)
            else:
                out = cover(W, H).filter(ImageFilter.GaussianBlur(28))
                out = Image.eval(out, lambda v: int(v * 0.55))
                out.paste(cover(int(x1 - x0), int(y1 - y0)), (int(x0), int(y0)))
            out = out.convert("RGBA")
            sh = Image.new("RGBA", out.size, (0, 0, 0, 0))
            ds = ImageDraw.Draw(sh)
            y_sub = 975 if LAND else 1640
            for i in range(260):
                ds.line([(0, y_sub - 200 + i), (W, y_sub - 200 + i)], fill=(5, 10, 25, int(min(1, i / 160) * 170)))
            ds.rectangle([0, y_sub + 60, W, H], fill=(5, 10, 25, 170))
            out.alpha_composite(sh)
            _PH[key] = out
        img.alpha_composite(_PH[key])
        snow(img, (0, 0, W, H), t, 40, alpha=90)
        text(ImageDraw.Draw(img), (W - 24 * S, (24 if LAND else 120) * S), "絵はAIで作成", 26, O.DIM, "ra", 3)
    d = ImageDraw.Draw(img)
    if P.get("note"):
        label(d, ((x0 + x1) / 2, y0 + 60 * S), P["note"], 42, O.WHITE)


def sc_deep(img, box, t, k, P):
    grad(img, (14, 36, 70), (4, 8, 20), (0, 0, W, H))
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = box
    fish_side(d, (x0 + x1) / 2 + 30 * S * math.sin(t * 0.5), (y0 + y1) / 2, (min(W * 0.3, 460 * S) if LAND else W * 0.5), (60, 95, 125))
    snow(img, (0, 0, W, H), t, 90)


# ---- 深さの断面 -----------------------------------------------------------------------------
KGN = {0: 0.0, 10: 1.0, 1000: 103.0, 6500: 678.0, 8200: 858.0, 8336: 872.0, 10935: 1150.0}
KGT = {10: "約1kg", 1000: "約100kg", 6500: "約680kg", 8336: "約870kg", 10935: "約1.1トン"}
DMAX = 11000.0


def kg_text(v):
    return f"約{v:,.0f}kg" if v < 1000 else f"約{v / 1000:.1f}トン"


def sc_strip(img, box, t, k, P):
    x0, y0, x1, y1 = box
    bw, bh = x1 - x0, y1 - y0
    bg(img, box)
    d = ImageDraw.Draw(img)
    to, frm = P["to"], P.get("frm", P["to"])
    u = _ease(min(1.0, k * 1.25))
    dep = frm + (to - frm) * u
    cw = (200 if LAND and not P.get("panel") else 150) * S
    cx = x0 + bw * (0.22 if not P.get("panel") else 0.3)
    top, bot = y0 + 70 * S, y1 - 30 * S
    h = bot - top
    yy = lambda dd: top + dd / DMAX * h
    col = Image.new("RGBA", img.size, (0, 0, 0, 0))
    cd = ImageDraw.Draw(col)
    n = int(h)
    for i in range(0, n, 2):
        cd.rectangle([cx - cw / 2, top + i, cx + cw / 2, top + i + 2], fill=lerp(SEA0, (8, 16, 40), min(1.0, (i / h) ** 0.6)) + (255,))
    if P.get("gray"):
        cd.rectangle([cx - cw / 2, yy(8336), cx + cw / 2, bot], fill=(90, 95, 105, 235))
    img.alpha_composite(col)
    d = ImageDraw.Draw(img)
    d.rectangle([cx - cw / 2, top, cx + cw / 2, bot], outline=O.WHITE, width=max(2, int(3 * S)))
    for dd, nm in [(0, "0m"), (1000, "1,000m"), (6500, "6,500m"), (8336, "8,336m"), (10935, "10,935m")]:
        if dd > max(to, frm) + 1 and dd != 0:
            continue
        if P.get("line") and dd == 8336:
            continue
        d.line([(cx - cw / 2 - 12 * S, yy(dd)), (cx - cw / 2, yy(dd))], fill=O.DIM, width=int(3 * S))
        text(d, (cx - cw / 2 - 20 * S, yy(dd)), nm, 28, O.DIM, "rm", 3)
    if P.get("line"):
        yl = yy(8200)
        d.line([(cx - cw / 2 - 12 * S, yl), (cx + cw / 2 + 60 * S, yl)], fill=O.RED, width=int(4 * S))
        text(d, (cx - cw / 2 - 20 * S, yl), "8,200m", 30, O.RED, "rm", 3)
    if P.get("rec"):
        yr = yy(8336)
        d.ellipse([cx - 14 * S, yr - 14 * S, cx + 14 * S, yr + 14 * S], fill=O.YEL, outline=O.NAVY, width=int(3 * S))
        arrow(d, (cx + cw / 2 + 120 * S, yr - 60 * S), (cx + 22 * S, yr - 6 * S), O.YEL)
        if not P.get("readout", True):
            label(d, (cx + cw / 2 + 140 * S, yr - 85 * S), "魚の記録 8,336m", 38, O.YEL, "lm")
    if P.get("gray"):
        label(d, (cx + cw / 2 + 40 * S, (yy(8336) + bot) / 2), "まだ見つかっていない 約2,600m", 38, O.WHITE, "lm")
    py = yy(dep)
    d.polygon([(cx - cw / 2 - 4 * S, py - 12 * S), (cx - cw / 2 - 4 * S, py + 12 * S), (cx - cw / 2 + 26 * S, py)], fill=O.YEL)
    d.line([(cx - cw / 2, py), (cx + cw / 2, py)], fill=O.YEL, width=int(3 * S))
    fish_side(d, cx + 30 * S * math.sin(t * 0.8), py - 6 * S, 56 * S, (230, 235, 240))
    if P.get("readout", True) and not (to == 0 and frm == 0):
        rx0, rx1 = x0 + bw * (0.5 if not P.get("panel") else 0.56), x1 - 40 * S
        rc = (rx0 + rx1) / 2
        ry = (top + bot) / 2
        v = KGN[frm] + (KGN[to] - KGN[frm]) * u
        shown = KGT.get(to) if k > 0.85 else None
        label(d, (rc, ry - 190 * S), f"水深 {dep:,.0f}m", 46, O.WHITE)
        text(d, (rc, ry - 110 * S), "指先1cm²にかかる重さ", 36, O.DIM, "mm", 4)
        fit_text(d, (rc, ry - 20 * S), shown or kg_text(v), 110, rx1 - rx0)
        bx0, bx1 = rx0, rx1
        d.rounded_rectangle([bx0, ry + 60 * S, bx1, ry + 90 * S], int(10 * S), outline=O.DIM, width=int(2 * S))
        d.rounded_rectangle([bx0, ry + 60 * S, bx0 + (bx1 - bx0) * min(1.0, v / 1150), ry + 90 * S], int(10 * S), fill=O.YEL)
        if P.get("ratio"):
            text(d, (rc, ry + 150 * S), P["ratio"], 44, O.WHITE, "mm", 5)


# ---- 指先に重りが乗る ----------------------------------------------------------------------
def finger(d, cx, ytop, w, hgt):
    d.rounded_rectangle([cx - w / 2, ytop, cx + w / 2, ytop + hgt], int(w / 2), fill=SKIN)
    d.rectangle([cx - w / 2, ytop + hgt - w * 0.2, cx + w / 2, ytop + hgt], fill=SKIN)
    d.rectangle([cx - w * 0.2, ytop - 4 * S, cx + w * 0.2, ytop + 6 * S], fill=O.RED)


def sc_weight(img, box, t, k, P):
    x0, y0, x1, y1 = box
    bw, bh = x1 - x0, y1 - y0
    bg(img, box)
    d = ImageDraw.Draw(img)
    cx = x0 + bw * (0.3 if P.get("cube") else 0.5)
    u = _ease(min(1.0, k * 2.0))
    m = min(bw, bh)
    fw = 70 * S
    ftop = y1 - 230 * S
    finger(d, cx, ftop, fw, 200 * S)
    s = {"870": 0.8, "1100": 1.0}[P["kg"]]
    blk = m * 0.42 * s
    by = ftop - 8 * S - blk * u * 0 - (1 - u) * 120 * S
    d.rectangle([cx - blk / 2, by - blk * 0.7, cx + blk / 2, by], fill=(110, 115, 125), outline=O.WHITE, width=int(3 * S))
    d.line([(cx - blk * 0.3, by - blk * 0.7), (cx - blk * 0.3, by - blk * 0.85), (cx + blk * 0.3, by - blk * 0.85), (cx + blk * 0.3, by - blk * 0.7)], fill=O.DIM, width=int(5 * S))
    fit_text(d, (cx, by - blk * 0.35), "約870kg" if P["kg"] == "870" else "約1.1トン", 70, blk * 0.9, O.WHITE)
    label(d, (cx + fw / 2 + 40 * S, ftop + 90 * S), "指先 1cm²", 38, O.RED, "lm")
    if P.get("cube"):
        sx = x0 + bw * (0.72 if LAND else 0.7)
        cs = m * (0.36 if LAND else 0.27)
        sy = y1 - 80 * S
        front = [sx - cs / 2, sy - cs, sx + cs / 2, sy]
        dx, dy = cs * 0.3, -cs * 0.25
        d.polygon([(front[2], front[1]), (front[2] + dx, front[1] + dy), (front[2] + dx, front[3] + dy), (front[2], front[3])], fill=(40, 100, 160), outline=O.WHITE)
        d.polygon([(front[0], front[1]), (front[0] + dx, front[1] + dy), (front[2] + dx, front[1] + dy), (front[2], front[1])], fill=(110, 180, 230), outline=O.WHITE)
        d.rectangle(front, fill=(70, 140, 200), outline=O.WHITE, width=2)
        label(d, (sx + dx / 2, front[1] - cs * 0.55), "1辺1mの水の箱 約1トン", 38, O.WHITE)
        if LAND:
            text(d, ((cx + sx) / 2, sy - cs * 0.6), "<", 120, O.YEL, "mm", 6)


# ---- 空気が縮む -----------------------------------------------------------------------------
def sc_piston(img, box, t, k, P):
    x0, y0, x1, y1 = box
    bw, bh = x1 - x0, y1 - y0
    bg(img, box)
    d = ImageDraw.Draw(img)
    u = _ease(min(1.0, k * 1.4))
    if P.get("lung"):
        cx0, cx1 = x0 + bw * 0.28, x0 + bw * 0.62
        by = (y0 + y1) / 2
        for cx, sc, nm in ((cx0, 1.0, "水深0m"), (cx1, 1 - 0.206 * u, "水深10m")):
            r = min(bw, bh) * 0.28 * sc
            for sx in (-1, 1):
                d.ellipse([cx + sx * r * 0.62 - r * 0.58, by - r * 0.9, cx + sx * r * 0.62 + r * 0.58, by + r * 0.9], fill=(230, 140, 150), outline=O.WHITE, width=int(3 * S))
            d.rectangle([cx - r * 0.05, by - r * 1.25, cx + r * 0.05, by - r * 0.4], fill=(210, 215, 225))
            label(d, (cx, by + min(bw, bh) * 0.28 * 1.05 + 55 * S), nm, 40, O.WHITE)
        label(d, (x0 + bw * 0.84, by), "空気は半分", 46, O.YEL)
        return
    n = P["n"]
    f = 1.0 + (1.0 / n - 1.0) * u
    cw = min(bw * 0.3, 280 * S)
    cx = x0 + bw * 0.3
    top, bot = y0 + 110 * S, y1 - 40 * S
    ch = bot - top
    d.rectangle([cx - cw / 2, top, cx + cw / 2, bot], outline=O.WHITE, width=int(5 * S))
    ph = top + ch * (1 - f)                      # ピストンの下の面
    d.rectangle([cx - cw / 2 - 8 * S, ph - 36 * S, cx + cw / 2 + 8 * S, ph], fill=(150, 155, 165), outline=O.WHITE, width=int(3 * S))
    d.rectangle([cx - 10 * S, top - 60 * S, cx + 10 * S, ph - 36 * S], fill=(150, 155, 165))
    rnd = random.Random(5)
    for i in range(46):
        a, b, sa, sb = rnd.random(), rnd.random(), rnd.uniform(0.8, 2.2), rnd.uniform(0.8, 2.2)
        px = cx - cw / 2 + 14 * S + (cw - 28 * S) * (0.5 + 0.5 * math.sin(t * sa + a * 9))
        py = ph + 12 * S + max(0.0, bot - ph - 24 * S) * (0.5 + 0.5 * math.sin(t * sb + b * 9))
        r = 7 * S
        d.ellipse([px - r, py - r, px + r, py + r], fill=(255, 235, 150))
    for q in range(3):
        ax = cx - cw * 0.3 + q * cw * 0.3
        arrow(d, (ax, top - 150 * S), (ax, top - 70 * S), O.RED, 7, 24)
    lx = cx + cw / 2 + 60 * S
    label(d, (lx, y0 + bh * 0.22), f"押す力 ×{n}" if n < 100 else "押す力 ×100", 54, O.RED, "lm")
    label(d, (lx, y0 + bh * 0.5), P["vol"], 54, O.YEL, "lm")
    if P.get("note"):
        label(d, (lx, y0 + bh * 0.78), P["note"], 40, O.WHITE, "lm")


# ---- ペットボトル・カップ -------------------------------------------------------------------
def bottle(d, cx, yb, hgt, wid, crush=0.0, col=(190, 225, 245)):
    w = wid * (1 - 0.55 * crush)
    hh = hgt * (1 - 0.35 * crush)
    d.rounded_rectangle([cx - w / 2, yb - hh, cx + w / 2, yb], int(w * 0.18), fill=col + (255,) if len(col) == 3 else col, outline=O.WHITE, width=max(2, int(3 * S)))
    d.rectangle([cx - w * 0.17, yb - hh - hgt * 0.1, cx + w * 0.17, yb - hh + 4], fill=col, outline=O.WHITE, width=max(2, int(3 * S)))
    d.rectangle([cx - w * 0.2, yb - hh - hgt * 0.15, cx + w * 0.2, yb - hh - hgt * 0.1], fill=(70, 130, 220))
    if crush > 0.05:
        for i in range(1, 6):
            y = yb - hh + hh * i / 6
            d.line([(cx - w / 2, y), (cx - w * 0.2, y + hh * 0.03), (cx + w * 0.2, y - hh * 0.03), (cx + w / 2, y)], fill=(90, 120, 150), width=max(2, int(3 * S)))


def sc_bottle(img, box, t, k, P):
    x0, y0, x1, y1 = box
    bw, bh = x1 - x0, y1 - y0
    d = ImageDraw.Draw(img)
    mode = P["mode"]
    if mode == "sink":
        top, bot = y0 + 40 * S, y1 - 30 * S
        cx0, cx1 = x0 + bw * 0.12, x0 + bw * 0.34
        colr = Image.new("RGBA", img.size, (0, 0, 0, 0))
        cd = ImageDraw.Draw(colr)
        for i in range(0, int(bot - top), 2):
            cd.rectangle([cx0, top + i, cx1, top + i + 2], fill=lerp(SEA0, (8, 16, 40), min(1.0, (i / (bot - top)) ** 0.6)) + (255,))
        img.alpha_composite(colr)
        d = ImageDraw.Draw(img)
        d.rectangle([cx0, top, cx1, bot], outline=O.WHITE, width=int(3 * S))
        u = _ease(min(1.0, k * 1.2))
        dep = 8336 * u
        by = top + 260 * S + (bot - top - 300 * S) * u
        bottle(d, (cx0 + cx1) / 2, by, 230 * S, 100 * S, crush=_ease(u * 1.6))
        rx = x0 + bw * (0.52 if LAND else 0.4)
        label(d, (rx, y0 + bh * 0.2), f"水深 {dep:,.0f}m", 46, O.WHITE, "lm")
        label(d, (rx, y0 + bh * 0.42), "500mLの空気", 44, O.WHITE, "lm")
        if u > 0.9:
            label(d, (rx, y0 + bh * 0.62), "845分の1  わずか0.6mL", 46, O.YEL, "lm")
        return
    bg(img, box)
    d = ImageDraw.Draw(img)
    u = _ease(min(1.0, k * 1.5))
    sc = bh / 1080
    bx = x0 + bw * 0.22
    bottle(d, bx, y1 - 120 * S, min(bh * 0.55, 420 * S), min(bh * 0.55, 420 * S) * 0.4)
    label(d, (bx, y1 - 70 * S), "500mL", 40, O.WHITE)
    arrow(d, (bx + 110 * S, (y0 + y1) / 2), (x0 + bw * 0.5, (y0 + y1) / 2), O.YEL, 8, 28)
    text(d, ((bx + x0 + bw * 0.5) / 2 + 60 * S, (y0 + y1) / 2 - 60 * S), "水深8,336m", 40, O.DIM, "mm", 4)
    gx, gy = x0 + bw * 0.5 + 130 * S, y1 - 120 * S
    r = (30 + 110 * u) * S
    gcx, gcy = x0 + bw * 0.72, (y0 + y1) / 2
    d.ellipse([gcx - r, gcy - r, gcx + r, gcy + r], fill=(190, 225, 245), outline=O.WHITE, width=int(4 * S))
    label(d, (gcx, gcy + r + 55 * S), "直径 約1cm（0.6mL）", 38, O.YEL)
    # 同じ縮尺の目盛り(ボトルの高さ約20cm: 1cm = 15px)


def sc_cup(img, box, t, k, P):
    x0, y0, x1, y1 = box
    bw, bh = x1 - x0, y1 - y0
    bg(img, box)
    d = ImageDraw.Draw(img)
    u = _ease(min(1.0, k * 1.4))

    def cup(cx, yb, w, h, col=(245, 245, 240)):
        d.polygon([(cx - w / 2, yb - h), (cx + w / 2, yb - h), (cx + w * 0.34, yb), (cx - w * 0.34, yb)], fill=col, outline=O.WHITE)
        d.ellipse([cx - w / 2, yb - h - w * 0.08, cx + w / 2, yb - h + w * 0.08], fill=(225, 225, 220), outline=O.WHITE)
    m = min(bw, bh)
    yb = y1 - 140 * S
    cup(x0 + bw * 0.25, yb, m * 0.32, m * 0.32)
    label(d, (x0 + bw * 0.25, yb + 55 * S), "発泡スチロールのカップ", 36, O.WHITE)
    arrow(d, (x0 + bw * 0.42, yb - m * 0.15), (x0 + bw * 0.55, yb - m * 0.15), O.YEL, 8, 28)
    text(d, (x0 + bw * 0.485, yb - m * 0.27), "深海へ", 40, O.DIM, "mm", 4)
    s = 1 - 0.45 * u
    cup(x0 + bw * 0.74, yb, m * 0.32 * s, m * 0.32 * s)
    label(d, (x0 + bw * 0.74, yb + 55 * S), "小さく縮んで戻る", 36, O.YEL)


def sc_bladder(img, box, t, k, P):
    x0, y0, x1, y1 = box
    bw, bh = x1 - x0, y1 - y0
    bg(img, box)
    d = ImageDraw.Draw(img)
    cx, cy = x0 + bw * 0.42, (y0 + y1) / 2
    L = min(bw * 0.62, bh * 1.3)
    fish_side(d, cx, cy, L, (110, 150, 180))
    if P["mode"] == "none":
        label(d, (cx - L * 0.02, cy + L * 0.34 * 0.78), "空気の袋がない", 40, O.YEL)
        return
    u = _ease(min(1.0, k * 1.2)) if P["mode"] == "shrink" else 0.0
    sc = 1.0 - 0.8 * u
    h = L * 0.34
    d.ellipse([cx - L * 0.12 * sc - L * 0.02, cy - h * 0.2 * sc, cx + L * 0.12 * sc + L * 0.02, cy + h * 0.2 * sc], fill=(255, 240, 170), outline=O.WHITE, width=int(3 * S))
    label(d, (cx - L * 0.02, cy + h * 0.78), "うきぶくろ（空気の袋）", 40, O.YEL)
    if P["mode"] == "shrink":
        text(d, (x0 + bw * 0.5, y0 + 50 * S), "深い所では", 40, O.DIM, "mm", 4)
        label(d, (x0 + bw * 0.5, y0 + 120 * S), "何百分の1に縮もうとする", 44, O.WHITE)


# ---- 水の縮み ---------------------------------------------------------------------------------
def sc_jar(img, box, t, k, P):
    x0, y0, x1, y1 = box
    bw, bh = x1 - x0, y1 - y0
    bg(img, box)
    d = ImageDraw.Draw(img)
    u = _ease(min(1.0, k * 1.4))
    jh = min(bh * 0.66, 440 * S)
    jw = jh * 0.62

    def jar(cx, level, fill):
        yb = y1 - 110 * S
        d.rectangle([cx - jw / 2, yb - jh, cx + jw / 2, yb], outline=O.WHITE, width=int(4 * S))
        yl = yb - jh * level
        if yl < yb - 3:
            d.rectangle([cx - jw / 2 + 2, yl, cx + jw / 2 - 2, yb - 2], fill=fill)
        d.line([(cx - jw / 2 - 30 * S, yb - jh), (cx - jw / 2, yb - jh)], fill=O.YEL, width=int(4 * S))
        return yb, yl
    if P["mode"] == "water":
        cx = x0 + bw * 0.3
        yb, yl = jar(cx, 1 - 0.04 * u, (70, 140, 200))
        lx = cx + jw / 2 + 60 * S
        label(d, (lx, yb - jh), "1,000mL", 40, O.WHITE, "lm")
        if u > 0.5:
            label(d, (lx, yb - jh * 0.72), "約960mL", 44, O.YEL, "lm")
        label(d, (lx, yb - jh * 0.42), "1,000気圧で押す", 40, O.RED, "lm")
        if u > 0.8:
            label(d, (lx, yb - jh * 0.12), "減るのは約40mL（約4%）", 38, O.WHITE, "lm")
    else:
        cx0, cx1 = x0 + bw * 0.27, x0 + bw * 0.7
        yb, _ = jar(cx0, 1 - 0.999 * u, (235, 235, 250))
        jar(cx1, 1 - 0.04 * u, (70, 140, 200))
        label(d, (cx0, yb + 55 * S), "空気 約1,000分の1", 38, O.WHITE)
        label(d, (cx1, yb + 55 * S), "水 約4%", 38, O.YEL)
        text(d, ((cx0 + cx1) / 2, y0 + 70 * S), "同じ 1,000気圧で押す", 40, O.DIM, "mm", 4)


def sc_sea(img, box, t, k, P):
    x0, y0, x1, y1 = box
    bw, bh = x1 - x0, y1 - y0
    bg(img, box)
    d = ImageDraw.Draw(img)
    u = _ease(min(1.0, k * 1.5))
    cx = x0 + bw * (0.3 if LAND else 0.4)
    cw = min(bw * 0.3, 360 * S)
    top, bot = y0 + 170 * S, y1 - 40 * S
    rise = 60 * S * u
    grad(img, (60, 140, 190), (8, 16, 40), (cx - cw / 2, top - rise, cx + cw / 2, bot))
    d = ImageDraw.Draw(img)
    d.rectangle([cx - cw / 2, top - rise, cx + cw / 2, bot], outline=O.WHITE, width=int(3 * S))
    d.rectangle([cx - cw / 2, top - rise, cx + cw / 2, top], outline=O.YEL, width=int(5 * S))
    for i in range(7):
        wx = cx - cw / 2 + cw * i / 6
        d.arc([wx - 20 * S, top - rise - 10 * S, wx + 20 * S, top - rise + 10 * S], 180, 360, fill=O.WHITE, width=int(3 * S))
    text(d, (cx - cw / 2 - 20 * S, (top + bot) / 2), "平均の深さ\n約3,700m", 34, O.DIM, "rm", 4)
    label(d, (cx + cw / 2 + 50 * S, top - rise), "約30m高い", 44, O.YEL, "lm")
    bx = x0 + bw * (0.74 if LAND else 0.8)
    gy = y1 - 60 * S
    fh = 26 * S
    bwid = 130 * S
    for i in range(10):
        d.rectangle([bx - bwid / 2, gy - (i + 1) * fh, bx + bwid / 2, gy - i * fh], fill=(110, 125, 150), outline=O.WHITE)
        for j in (-1, 0, 1):
            d.rectangle([bx + j * 36 * S - 9 * S, gy - (i + 0.72) * fh, bx + j * 36 * S + 9 * S, gy - (i + 0.3) * fh], fill=(255, 230, 150))
    label(d, (bx, gy - 10 * fh - 55 * S), "10階建てのビル 約30m", 36, O.WHITE)


def sc_fishsec(img, box, t, k, P):
    x0, y0, x1, y1 = box
    bw, bh = x1 - x0, y1 - y0
    bg(img, box)
    u = _ease(min(1.0, k * 1.5))
    cx, cy = (x0 + bw * 0.3, (y0 + y1) / 2) if LAND else (x0 + bw * 0.58, y0 + bh * 0.2)
    L = min(bw * 0.5, bh * 1.1) if LAND else bw * 0.7
    lay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    fish_side(ImageDraw.Draw(lay), cx, cy, L, (90, 120, 150, 255))
    mask = lay.split()[3]
    fill = Image.new("RGBA", img.size, (0, 0, 0, 0))
    fd = ImageDraw.Draw(fill)
    h = L * 0.34
    lvl = cy + h * 0.5 - h * 0.81 * u
    fd.rectangle([cx - L, lvl, cx + L, cy + h], fill=(60, 150, 230, 255))
    for i in range(14):
        wx = cx - L * 0.7 + L * 1.4 * i / 13
        fd.ellipse([wx - 22 * S, lvl - 8 * S + 5 * S * math.sin(t * 2 + i), wx + 22 * S, lvl + 8 * S + 5 * S * math.sin(t * 2 + i)], fill=(60, 150, 230, 255))
    base = Image.new("RGBA", img.size, (0, 0, 0, 0))
    base.paste(fill, (0, 0), mask)
    img.alpha_composite(lay)
    img.alpha_composite(base)
    d = ImageDraw.Draw(img)
    label(d, (cx, cy + L * 0.34 + (80 if LAND else 60) * S), "魚の体はほとんど水", 42, O.WHITE)
    cell = min(bw * 0.3 / 10, bh * 0.5 / 10) if LAND else bw * 0.4 / 10
    gx0, gy0 = (x0 + bw * 0.62, y0 + bh * 0.2) if LAND else (x0 + bw * 0.5 - cell * 5, y0 + bh * 0.42)
    nfil = int(81 * u)
    for i in range(100):
        r, c = divmod(i, 10)
        on = i < nfil
        d.rectangle([gx0 + c * cell, gy0 + r * cell, gx0 + (c + 1) * cell - 3 * S, gy0 + (r + 1) * cell - 3 * S], fill=(60, 150, 230) if on else (40, 52, 84))
    label(d, (gx0 + cell * 5, gy0 + cell * 10 + 60 * S), "マダラの身 約81%が水", 38, O.YEL)


def sc_balance(img, box, t, k, P):
    x0, y0, x1, y1 = box
    bw, bh = x1 - x0, y1 - y0
    bg(img, box)
    d = ImageDraw.Draw(img)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2 - 10 * S
    r = min(bw, bh) * (0.2 if LAND else 0.17)
    d.ellipse([cx - r * 1.4, cy - r, cx + r * 1.4, cy + r], fill=(70, 140, 200), outline=O.WHITE, width=int(5 * S))
    pul = 1 + 0.12 * math.sin(t * 3)
    for ang in range(0, 360, 45):
        a = math.radians(ang)
        ex, ey = math.cos(a) * 1.4, math.sin(a)
        p1 = (cx + ex * (r + 120 * S * pul), cy + ey * (r + 120 * S * pul))
        p2 = (cx + ex * (r + 24 * S), cy + ey * (r + 24 * S))
        arrow(d, p1, p2, O.RED, 6, 20)
        q1 = (cx + ex * r * 0.2, cy + ey * r * 0.2)
        q2 = (cx + ex * (r * 0.75) * pul * 0.9, cy + ey * (r * 0.75) * pul * 0.9)
        arrow(d, q1, q2, O.GREEN, 5, 16)
    if LAND:
        label(d, (cx - r * 1.4 - 70 * S, cy - r - 90 * S), "外の水が押す", 40, O.RED, "rm")
        label(d, (cx + r * 1.4 + 70 * S, cy - r - 90 * S), "中の水が押し返す", 40, O.GREEN, "lm")
        label(d, (cx, cy + r + 100 * S), "つぶす力は残らない", 46, O.YEL)
    else:
        label(d, (cx, cy + r + 150 * S), "外の水が押す", 40, O.RED)
        label(d, (cx, cy + r + 230 * S), "中の水が押し返す", 40, O.GREEN)
        label(d, (cx, cy + r + 320 * S), "つぶす力は残らない", 46, O.YEL)


# ---- 潜水艇の殻 --------------------------------------------------------------------------------
HULL_MM = {1000: 10.2, 3000: 31.7, 6500: 73.5, 8336: 97.8, 10935: 135.5}


def sphere(d, cx, cy, ri, t_m, ri_m, col=(200, 208, 220), air=True):
    """中の半径 ri(px)・中の半径 ri_m(m)・殻の厚さ t_m(m) の球の断面。"""
    ro = ri * (1 + t_m / ri_m)
    d.ellipse([cx - ro, cy - ro, cx + ro, cy + ro], fill=col, outline=O.WHITE, width=2)
    d.ellipse([cx - ri, cy - ri, cx + ri, cy + ri], fill=(20, 40, 70) if air else (10, 20, 40), outline=O.WHITE, width=2)
    return ro


def sc_hull(img, box, t, k, P):
    x0, y0, x1, y1 = box
    bw, bh = x1 - x0, y1 - y0
    bg(img, box)
    d = ImageDraw.Draw(img)
    frm, to = P.get("frm", P["to"]), P["to"]
    u = _ease(min(1.0, k * 1.2))
    th = (HULL_MM[frm] + (HULL_MM[to] - HULL_MM[frm]) * u) / 1000.0
    dep = frm + (to - frm) * u
    ri = min(bh * 0.36, bw * (0.2 if LAND else 0.15))
    cx, cy = x0 + bw * (0.27 if LAND else 0.25), (y0 + y1) / 2 + 10 * S
    ro = sphere(d, cx, cy, ri, th, 1.0)
    for ang in range(0, 360, 30):
        a = math.radians(ang)
        arrow(d, (cx + math.cos(a) * (ro + 70 * S), cy + math.sin(a) * (ro + 70 * S)), (cx + math.cos(a) * (ro + 12 * S), cy + math.sin(a) * (ro + 12 * S)), O.RED, 5, 18)
    text(d, (cx, cy), "空気の部屋\n中の直径 2m", 34, O.WHITE, "mm", 4)
    rx = x0 + bw * (0.5 if LAND else 0.56)
    label(d, (rx, y0 + bh * 0.16), f"水深 {dep:,.0f}m", 46, O.WHITE, "lm")
    cm = th * 100
    disp = {1000: "約1cm", 3000: "約3cm", 6500: "7.35cm", 8336: "約9.8cm", 10935: "約13.5cm"}
    fit_text(d, (rx + (x1 - rx) / 2, y0 + bh * 0.4), "殻の厚さ " + (disp[to] if k > 0.85 else f"{cm:.1f}cm"), 70, x1 - rx - 40 * S, O.YEL)
    if P.get("weight"):
        label(d, (rx, y0 + bh * 0.66), "重さは、ほぼ2倍", 46, O.WHITE, "lm")
    if P.get("same"):
        label(d, (rx, y0 + bh * 0.82), "同じ余裕で計算", 36, O.DIM, "lm")


def sc_spheres(img, box, t, k, P):
    x0, y0, x1, y1 = box
    bw, bh = x1 - x0, y1 - y0
    bg(img, box)
    d = ImageDraw.Draw(img)
    u = _ease(min(1.0, k * 1.5))
    ri = min(bh * 0.3, bw * 0.17)
    cy = (y0 + y1) / 2 - 10 * S
    if P["mode"] == "fish":
        cx0, cx1 = x0 + bw * 0.27, x0 + bw * 0.73
        sphere(d, cx1, cy, ri, 0.0735, 1.0)
        text(d, (cx1, cy), "空気の部屋", 34, O.WHITE, "mm", 4)
        label(d, (cx1, cy + ri * 1.2 + 55 * S), "人は殻が要る", 40, O.YEL)
        fish_side(d, cx0 + (0 if LAND else 40 * S), cy, ri * (2.6 if LAND else 1.8), (150, 190, 215))
        label(d, (cx0, cy + ri * 1.2 + 55 * S), "魚は殻なし", 40, O.WHITE)
        return
    cx0, cx1 = x0 + bw * 0.27, x0 + bw * 0.73
    sphere(d, cx0, cy, ri, 0.1355 * u, 1.0)
    sphere(d, cx1, cy, ri * 0.75, 0.09, 0.75)
    text(d, (cx0, cy - ri * 1.25 - 40 * S), "内径 2m", 38, O.DIM, "mm", 4)
    text(d, (cx1, cy - ri * 1.25 - 40 * S), "内径 1.5m", 38, O.DIM, "mm", 4)
    label(d, (cx0, cy + ri * 1.25 + 60 * S), "計算 厚さ13.5cm", 38, O.WHITE)
    label(d, (cx1, cy + ri * 1.25 + 60 * S), "実際 厚さ9cm", 38, O.YEL)
    text(d, (x0 + bw * 0.5, y0 + 50 * S), "水深1万1千mまで", 38, O.DIM, "mm", 4)


# ---- 体の中の化学 -------------------------------------------------------------------------------
def blob(d, cx, cy, R, squeeze, col, t=0.0, wob=0.0):
    pts = []
    for i in range(121):
        a = i / 120 * 2 * math.pi
        r = R * (1 + 0.16 * math.sin(3 * a + 0.5 + wob) + 0.09 * math.sin(5 * a + 1.2) + squeeze * 0.22 * math.sin(2 * a) + 0.05 * squeeze * math.sin(7 * a))
        pts.append((cx + r * math.cos(a) * (1 - 0.18 * squeeze), cy + r * math.sin(a) * (1 + 0.1 * squeeze)))
    d.polygon(pts, fill=col, outline=O.WHITE)


def sc_protein(img, box, t, k, P):
    x0, y0, x1, y1 = box
    bw, bh = x1 - x0, y1 - y0
    bg(img, box)
    d = ImageDraw.Draw(img)
    u = _ease(min(1.0, k * 1.5))
    R = min(bh * 0.2, bw * 0.12)
    cx0, cx1 = x0 + bw * 0.27, x0 + bw * 0.7
    cy = y0 + bh * 0.4
    blob(d, cx0, cy, R, 0.0, (110, 190, 140), wob=0.2 * math.sin(t))
    label(d, (cx0, cy + R * 1.3 + 50 * S), "たんぱく質（ふつうの形）", 36, O.WHITE)
    if P.get("tmao"):
        blob(d, cx1, cy, R, 0.0 + 0.2 * (1 - u), (110, 190, 140), wob=0.2 * math.sin(t))
        rnd = random.Random(9)
        for i in range(int(26 * u)):
            a = rnd.random() * 2 * math.pi
            rr = R * rnd.uniform(1.35, 1.9)
            px, py = cx1 + rr * math.cos(a + 0.3 * math.sin(t + i)), cy + rr * math.sin(a + 0.3 * math.sin(t + i))
            d.ellipse([px - 10 * S, py - 10 * S, px + 10 * S, py + 10 * S], fill=O.YEL)
        if LAND:
            label(d, (cx1, cy + R * 2.0 + 50 * S), "TMAOが守る、と考えられている", 36, O.YEL)
        else:
            label(d, (x0 + bw * 0.5, cy + R * 2.0 + 110 * S), "TMAOが守る、と考えられている", 36, O.YEL)
        return
    sq = u
    blob(d, cx1, cy, R, sq, (190, 150, 110), wob=0.2 * math.sin(t))
    for ang in range(0, 360, 40):
        a = math.radians(ang)
        arrow(d, (cx1 + math.cos(a) * (R * 1.9), cy + math.sin(a) * (R * 1.9)), (cx1 + math.cos(a) * (R * 1.35), cy + math.sin(a) * (R * 1.35)), O.RED, 5, 18)
    label(d, (cx1, cy + R * 1.9 + 50 * S), "強い圧力で形がゆがむ", 36, O.RED)
    arrow(d, (cx0 + R * 1.5, cy), (cx1 - R * 1.9, cy), O.DIM, 5, 20)


def sc_bars(img, box, t, k, P):
    x0, y0, x1, y1 = box
    bw, bh = x1 - x0, y1 - y0
    bg(img, box)
    d = ImageDraw.Draw(img)
    items = [("浅い所の魚", 40), ("水深4,850m", 261), ("水深7,000m", 386)]
    u = _ease(min(1.0, k * 1.5))
    gx0, gx1 = x0 + bw * 0.1, x1 - bw * 0.1
    gy0, gy1 = y0 + 130 * S, y1 - 110 * S
    col = (gx1 - gx0) / 3
    for i, (nm, v) in enumerate(items):
        hh = (gy1 - gy0) * v / 400 * _ease(u * 3 - i * 0.6)
        bx0, bx1 = gx0 + i * col + col * 0.2, gx0 + (i + 1) * col - col * 0.2
        d.rectangle([bx0, gy1 - hh, bx1, gy1], fill=O.YEL if i == 2 else O.OCHRE)
        text(d, ((bx0 + bx1) / 2, gy1 - hh - 14 * S), f"{v}", 40, O.WHITE, "mb", 5)
        text(d, ((bx0 + bx1) / 2, gy1 + 14 * S), nm, 34, O.DIM, "ma", 4)
    d.line([(gx0, gy1), (gx1, gy1)], fill=O.DIM, width=int(3 * S))
    text(d, (gx0, y0 + 60 * S), "筋肉のTMAO（mmol/kg）", 32, O.DIM, "lm", 4)
    if u > 0.9:
        label(d, (gx0 + col * 2.5, y0 + bh * 0.3), "約10倍", 56, O.YEL)


def sc_osm(img, box, t, k, P):
    x0, y0, x1, y1 = box
    bw, bh = x1 - x0, y1 - y0
    bg(img, box)
    d = ImageDraw.Draw(img)
    gx0, gx1 = x0 + bw * 0.1, x1 - bw * 0.06
    gy0, gy1 = y0 + 90 * S, y1 - 90 * S
    px = lambda dep: gx0 + (gx1 - gx0) * dep / 10935
    d.line([(gx0, gy0), (gx0, gy1), (gx1, gy1)], fill=O.DIM, width=int(3 * S))
    for dep in (0, 2000, 4000, 6000, 8000, 10000):
        text(d, (px(dep), gy1 + 14 * S), f"{dep:,}m", 28, O.DIM, "ma", 3)
    ys = gy0 + (gy1 - gy0) * 0.25
    d.line([(gx0, ys), (gx1, ys)], fill=O.BLUE, width=int(6 * S))
    text(d, (gx1, ys - 14 * S), "海水の濃さ", 38, O.BLUE, "rb", 4)
    u = _ease(min(1.0, k * 1.3)) if P.get("grow", True) else 1.0
    pts = []
    for i in range(61):
        dep = 10935 * i / 60
        y = gy1 - (gy1 - ys) * (0.28 + 0.72 * (dep / 8200))
        pts.append((px(dep), y))
    n = max(2, int(len(pts) * u))
    d.line(pts[:n], fill=O.YEL, width=int(6 * S))
    text(d, (px(0) + 20 * S, pts[0][1] - 20 * S), "体の液の濃さ", 38, O.YEL, "lb", 4)
    if u > 0.97:
        d.line([(px(8200), gy0), (px(8200), gy1)], fill=O.RED, width=int(4 * S))
        label(d, (px(8200) - 20 * S, gy0 + 30 * S), "約8,200mで同じ濃さ", 40, O.RED, "rm")
        if P.get("rec"):
            d.ellipse([px(8336) - 14 * S, ys - 14 * S, px(8336) + 14 * S, ys + 14 * S], fill=O.WHITE, outline=O.NAVY, width=int(3 * S))
            label(d, (px(8336) - 30 * S, ys + 80 * S), "魚の記録 8,336m", 38, O.WHITE, "rm")
    text(d, (x1 - 20 * S, y1 - 6 * S), "濃さのイメージ図", 26, O.DIM, "rd", 3)


# ---- 日本地図・実験の一覧 --------------------------------------------------------------------------
JP = [
    [(140.3, 41.4), (141.5, 41.4), (142.0, 39.6), (141.0, 38.3), (140.9, 36.9), (140.6, 35.7), (139.9, 35.1), (139.6, 35.3), (138.8, 34.6), (138.2, 34.6),
     (137.0, 34.6), (136.9, 34.3), (135.8, 33.5), (135.1, 34.1), (135.3, 34.7), (133.0, 34.4), (131.0, 33.9), (131.0, 34.5), (132.5, 35.4), (134.5, 35.6),
     (136.0, 35.7), (136.7, 37.2), (137.3, 37.5), (138.6, 37.9), (139.5, 39.2), (139.9, 40.4)],
    [(129.8, 33.6), (131.0, 33.9), (131.8, 33.0), (131.5, 31.4), (130.7, 31.0), (130.2, 31.3), (129.7, 32.7)],
    [(132.7, 33.9), (134.7, 34.2), (134.5, 33.5), (133.0, 32.8), (132.4, 33.5)],
    [(140.0, 41.5), (141.4, 41.8), (143.3, 42.0), (145.5, 43.3), (145.3, 43.9), (143.5, 44.3), (141.9, 45.4), (141.6, 44.5), (140.4, 43.3), (140.0, 42.0)],
]
TRENCH = [(142.3, 34.3), (142.5, 32.0), (142.9, 29.0), (143.1, 27.0), (143.5, 25.0)]


def sc_map(img, box, t, k, P):
    x0, y0, x1, y1 = box
    bw, bh = x1 - x0, y1 - y0
    grad(img, (20, 60, 100), (10, 30, 60), box)
    d = ImageDraw.Draw(img)
    lat0, lat1, lon0 = 23.5, 45.5, 127.5
    sy = bh * 0.92 / (lat1 - lat0)
    sx = sy * 0.82
    ox = x0 + bw * (0.34 if not P.get("panel") else 0.05)
    pt = lambda lo, la: (ox + (lo - lon0) * sx, y1 - 20 * S - (la - lat0) * sy)
    for poly in JP:
        d.polygon([pt(*p) for p in poly], fill=(95, 120, 90), outline=O.WHITE)
    u = _ease(min(1.0, k * 1.5))
    n = max(2, int(len(TRENCH) * u + 0.999))
    pts = [pt(*p) for p in TRENCH[:n]]
    d.line(pts, fill=O.YEL, width=int(8 * S))
    for lo, la in ((142.2, 27.1), (141.3, 27.7), (142.1, 26.6)):
        x, y = pt(lo, la)
        d.ellipse([x - 4 * S, y - 4 * S, x + 4 * S, y + 4 * S], fill=(95, 120, 90))
    px, py = pt(142.8, 30.0)
    d.ellipse([px - 11 * S, py - 11 * S, px + 11 * S, py + 11 * S], fill=O.RED, outline=O.WHITE, width=int(3 * S))
    label(d, (pt(143.3, 33.2)[0] + 40 * S, pt(143.3, 33.2)[1]), "伊豆・小笠原海溝", 44, O.YEL, "lm")
    label(d, (px + 50 * S, py + 70 * S), "魚が撮影された海溝", 36, O.WHITE, "lm")
    text(d, (x1 - 20 * S, y1 - 6 * S), "位置は略図", 26, O.DIM, "rd", 3)


def sc_list(img, box, t, k, P):
    x0, y0, x1, y1 = box
    bw, bh = x1 - x0, y1 - y0
    bg(img, box)
    d = ImageDraw.Draw(img)
    rows = [("実験1", "深さごとの、指先の重さ"), ("実験2", "空気の入ったものを沈める"), ("実験3", "水そのものを1,000気圧で押す"),
            ("実験4", "人が行くなら、殻は何cm"), ("実験5", "体の中の液の濃さを比べる")]
    n = len(rows)
    rh = (bh - 60 * S) / n
    for i, (a, b) in enumerate(rows):
        v = _ease(k * (n + 1.2) - i)
        if v <= 0:
            continue
        ry = y0 + 30 * S + i * rh + rh / 2
        d.rounded_rectangle([x0 + bw * 0.1, ry - rh * 0.4, x1 - bw * 0.1, ry + rh * 0.4], int(14 * S), fill=(24, 40, 78), outline=(255, 255, 255), width=int(2 * S))
        text(d, (x0 + bw * 0.1 + 36 * S, ry), a, 54, O.YEL, "lm", 5)
        fit_text(d, (x0 + bw * 0.1 + 250 * S, ry), b, 46, x1 - bw * 0.1 - (x0 + bw * 0.1 + 250 * S) - 20 * S, O.WHITE, "lm", 5)


KINDS = dict(photo=sc_photo, deep=sc_deep, strip=sc_strip, weight=sc_weight, piston=sc_piston, bottle=sc_bottle, cup=sc_cup, bladder=sc_bladder,
             jar=sc_jar, sea=sc_sea, fishsec=sc_fishsec, balance=sc_balance, hull=sc_hull, spheres=sc_spheres, protein=sc_protein,
             bars=sc_bars, osm=sc_osm, map=sc_map, list=sc_list)


def region(P):
    if P.get("panel"):
        return (0, 100, W * 0.5, 760) if LAND else (0, 230, W, 740)
    return (0, 100, W, 760) if LAND else (0, 240, W, 1370)


def paint(sc, t, k):
    img = Image.new("RGBA", (W, H), (10, 18, 40, 255))
    if "hold" in sc:
        k = sc["hold"]
    elif sc.get("still"):
        k = 1.0
    if sc["kind"] == "bottle" and sc["mode"] == "sink":
        bg(img, region(sc))
    KINDS[sc["kind"]](img, region(sc), t, k, sc)
    return img


def draw(img, dr, t, ctx):
    lines, defs = ctx["lines"], ctx["defs"]
    scs = ctx.setdefault("_scenes", mapscene.scenes(lines, defs))
    cur = ctx["cur"] or lines[0]
    i = next(j for j, l in enumerate(lines) if l["id"] == cur["id"])
    now, prev = scs[i], (scs[i - 1] if i > 0 else None)
    k = ctx["k"]
    QUIET[0] = defs.get(cur["id"], {}).get("style") == "question" and not ctx.get("cta")
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
