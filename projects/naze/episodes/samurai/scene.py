"""テニスの王子様「サムライドライブ」(計算の回)の画面。行の scene=dict(kind=…) を描く(無い行は前の行を引き継ぐ)。
場面が変わると 0.5 秒で溶け合わせる。作品の絵・キャラの絵は使わない。AI の絵も使わない。図は全部コードで描く。
数字の出どころは research.md。外れ幅メーターは全編を貫く軸(行の scene に meter=dict(n=実験番号) を付けると右に出る)。
kind: formula / bars / court / meterbig / window / angline / angle / deg1 / uncert / speed / spin / magnus / rub / halves /
      shells / spread / face / apple / ballsec / netsec / ballsize / netheight / airdrag / conds
"""
from __future__ import annotations

import math

from PIL import Image, ImageDraw

from naze import mapscene, overlay as O
from naze.config import H, W

LAND = W > H
S = min(W, H) / 1080
COLS = dict(dim=O.DIM, white=O.WHITE, yel=O.YEL, red=O.RED, green=O.GREEN)
BG0, BG1 = (10, 18, 40), (16, 30, 62)
BALL = (214, 232, 70)
TAGGED = [False]
def _ease(u):
    u = max(0.0, min(1.0, u))
    return u * u * (3 - 2 * u)


def grad(img, top=BG0, bot=BG1, box=None):
    x0, y0, x1, y1 = box or (0, 0, W, H)
    d = ImageDraw.Draw(img)
    n = int(y1 - y0)
    for i in range(0, n, 2):
        u = i / max(1, n)
        d.rectangle([x0, y0 + i, x1, y0 + i + 2], fill=tuple(int(top[j] + (bot[j] - top[j]) * u) for j in range(3)))


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


def head(d, box, s, col=O.YEL, size=44):
    x0, y0, x1, y1 = box
    label(d, ((x0 + x1) / 2, y0 + (130 if (TAGGED[0] and not LAND) else 50) * S), s, size, col)


def arrow(d, x0, y0, x1, y1, w, col):
    """(x0,y0)→(x1,y1) の太い矢印。"""
    ang = math.atan2(y1 - y0, x1 - x0)
    L = math.hypot(x1 - x0, y1 - y0)
    hl = min(L * 0.5, w * 2.2)
    bx, by = x1 - math.cos(ang) * hl, y1 - math.sin(ang) * hl
    d.line([(x0, y0), (bx, by)], fill=col, width=int(w))
    nx, ny = -math.sin(ang), math.cos(ang)
    d.polygon([(x1, y1), (bx + nx * w * 1.1, by + ny * w * 1.1), (bx - nx * w * 1.1, by - ny * w * 1.1)], fill=col)


def mix(c, bg, a):
    return tuple(int(c[i] * a + bg[i] * (1 - a)) for i in range(3))



def bars(d, box, rows, vmax, k=1.0, grow_from=0, marks=(), names_above=None, y_top=None):
    """rows = [(名前, 値 or 範囲の下, 範囲の上 or None, 数字の札, 色)]。値は vmax に対する横の長さ。"""
    x0, y0, x1, y1 = box
    na = (not LAND) if names_above is None else names_above
    ya = y_top if y_top is not None else y0 + (210 if not LAND else 130) * S
    n = len(rows)
    rh = min((200 if not na else 230) * S, (y1 - 50 * S - ya) / n)
    if y_top is None:   # 行が少ないときは、空いた所の真ん中に寄せる
        ya = max(ya, ya + ((y1 - 50 * S - ya) - rh * n) * 0.4)
    gx0 = x0 + 50 * S if na else x0 + (x1 - x0) * 0.27
    gx1 = x1 - 50 * S
    px = lambda v: gx0 + (gx1 - gx0) * min(v, vmax) / vmax
    bh = rh * (0.3 if na else 0.44)
    f = O.font(int(36 * S))
    for i, (name, lo, hi, txt, col) in enumerate(rows):
        a = 1.0 if i < grow_from else _ease(k * 1.8 - 0.35 * (i - grow_from))
        cy = ya + rh * (i + 0.5) + (12 * S if na else 0)
        nsz = 36 if na else 38
        while O.font(int(nsz * S)).getlength(name) > ((x1 - x0 - 100 * S) if na else (gx0 - x0 - 40 * S)) and nsz > 22:
            nsz -= 2
        if na:
            text(d, (gx0, cy - bh / 2 - 12 * S), name, nsz, O.WHITE, "ld", 4)
        else:
            text(d, (gx0 - 20 * S, cy), name, nsz, O.WHITE, "rm", 4)
        if a <= 0:
            continue
        end = px(hi if hi is not None else lo)
        e = gx0 + max(8 * S, (end - gx0)) * a
        if hi is not None:
            m = gx0 + (px(lo) - gx0) * a
            d.rectangle([gx0, cy - bh / 2, e, cy + bh / 2], fill=mix(col, BG1, 0.5))
            d.rectangle([gx0, cy - bh / 2, m, cy + bh / 2], fill=col)
        else:
            d.rectangle([gx0, cy - bh / 2, e, cy + bh / 2], fill=col)
        tw = f.getlength(txt)
        if a > 0.6:
            if e + 14 * S + tw > x1 - 20 * S:
                text(d, (e - 14 * S, cy), txt, 36, O.WHITE, "rm", 5)
            else:
                text(d, (e + 14 * S, cy), txt, 36, O.WHITE, "lm", 4)
    for v, s, col in marks:
        xm = px(v)
        d.line([(xm, ya - 6 * S), (xm, ya + rh * n)], fill=col, width=max(2, int(4 * S)))
        text(d, (min(xm, x1 - 20 * S), ya - 14 * S), s, 32, col, "md" if xm < x1 - 200 * S else "rd", 4)


# ---- ダイヤル -----------------------------------------------------------------------------

def dial(d, cx, cy, R, vmax, val, ticks, zones=(), shake=0.0):
    """半円のメーター。val が vmax を超えると針は端で振り切れる。zones = [(a, b, 色)]。"""
    w = int(34 * S)
    d.arc([cx - R, cy - R, cx + R, cy + R], 180, 360, fill=(40, 52, 78), width=w)
    for a, b, c in zones:
        d.arc([cx - R, cy - R, cx + R, cy + R], 180 + 180 * a / vmax, 180 + 180 * b / vmax, fill=c, width=w)
    for v, s in ticks:
        th = math.radians(180 + 180 * v / vmax)
        d.line([(cx + math.cos(th) * (R - w * 0.6), cy + math.sin(th) * (R - w * 0.6)), (cx + math.cos(th) * (R + w * 0.7), cy + math.sin(th) * (R + w * 0.7))], fill=O.WHITE, width=max(2, int(4 * S)))
        text(d, (cx + math.cos(th) * (R + w * 1.5), cy + math.sin(th) * (R + w * 1.5)), s, 30, O.DIM, "mm", 3)
    th = math.radians(180 + 180 * min(val, vmax * 1.02) / vmax) + math.radians(shake)
    d.line([(cx, cy), (cx + math.cos(th) * (R - w * 0.2), cy + math.sin(th) * (R - w * 0.2))], fill=O.WHITE, width=int(10 * S))
    d.ellipse([cx - 18 * S, cy - 18 * S, cx + 18 * S, cy + 18 * S], fill=O.WHITE)


# ---- 場面 -------------------------------------------------------------------------------

def sc_formula(img, box, t, k, P):
    grad(img, box=box)
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    cx = (x0 + x1) / 2
    rows = P["rows"]
    gap = (y1 - y0) / (len(rows) + 1)
    for i, (s, size, col) in enumerate(rows):
        a = _ease(k * (len(rows) + 0.5) * 1.8 - i)
        if a <= 0:
            continue
        cc = COLS[col]
        c = tuple(int(v * a + 20 * (1 - a)) for v in cc)
        sz = size
        f = O.font(int(sz * S))
        while f.getlength(s) > (x1 - x0) - (80 if LAND else 200) * S and sz > 30:
            sz -= 4
            f = O.font(int(sz * S))
        text(d, (cx, y0 + gap * (i + 1) + 6 * S * math.sin(t * 1.3 + i)), s, sz, c, "mm", 6)


def _tag(img, box, n):
    """左上の「実験N」の札。"""
    d = ImageDraw.Draw(img)
    x0, y0 = box[0], box[1]
    s = f"実験{n}" if isinstance(n, int) else str(n)
    f = O.font(int(44 * S))
    w = f.getlength(s)
    bx = (x0 + 24 * S, y0 + 14 * S, x0 + 24 * S + w + 40 * S, y0 + 14 * S + 70 * S)
    d.rounded_rectangle(bx, int(14 * S), fill=O.YEL, outline=O.NAVY, width=int(3 * S))
    d.text(((bx[0] + bx[2]) / 2, (bx[1] + bx[3]) / 2), s, font=f, fill=O.NAVY, anchor="mm")
    O.BOXES.append(("label", bx, s, 1.0))


def _stamp(img, box, kind, u):
    """大きな「失敗」(赤)・「成功」(緑)の札。u=0→1 で、大きく出てすっと落ち着く。"""
    s, col = ("失敗", O.RED) if kind == "fail" else ("成功", O.GREEN)
    sz = int((140 if LAND else 190) * S)
    f = O.font(sz)
    pad = int(36 * S)
    tw = int(f.getlength(s))
    lay = Image.new("RGBA", (tw + pad * 2, sz + pad * 2), (0, 0, 0, 0))
    ld = ImageDraw.Draw(lay)
    ld.rounded_rectangle([4, 4, lay.width - 5, lay.height - 5], int(30 * S), fill=(8, 16, 36, 235), outline=col, width=int(12 * S))
    ld.text((lay.width / 2, lay.height / 2 - int(6 * S)), s, font=f, fill=col, anchor="mm")
    sc = 1.0 + 0.5 * (1 - _ease(u * 3))
    lay = lay.resize((int(lay.width * sc), int(lay.height * sc)), Image.LANCZOS).rotate(8, expand=True, resample=Image.BICUBIC)
    cx = box[2] - lay.width / 2 - 40 * S
    cy = box[1] + lay.height / 2 + (24 if LAND else 90) * S
    img.alpha_composite(lay, (int(cx - lay.width / 2), int(cy - lay.height / 2)))


def draw(img, dr, t, ctx):
    lines, defs = ctx["lines"], ctx["defs"]
    scs = ctx.setdefault("_scenes", mapscene.scenes(lines, defs))
    cur = ctx["cur"] or lines[0]
    i = next(j for j, l in enumerate(lines) if l["id"] == cur["id"])
    now, prev = scs[i], (scs[i - 1] if i > 0 else None)
    dd = defs.get(cur["id"], {})
    k = ctx["k"]
    if prev is now:      # 前の行から引き継いだ図は、描き直さずそのまま見せる
        k = 1.0
    tag = dd.get("exp") if now["kind"] != "formula" else None
    TAGGED[0] = bool(tag) and not LAND
    u = _ease((t - cur["start"]) / 0.5)
    TAGGED_prev = TAGGED[0]
    b = paint(prev, t, 1.0) if prev is not None and prev is not now and u < 1 else None
    O.BOXES.clear()
    a = paint(now, t, k)
    if b is not None:
        a = Image.blend(b, a, u)
    z = 1.0 + 0.025 * (0.5 + 0.5 * math.sin(2 * math.pi * t / 14.0))
    if z > 1.0005:
        zw, zh = int(W * z), int(H * z)
        a = a.resize((zw, zh), Image.BILINEAR).crop(((zw - W) // 2, (zh - H) // 2, (zw - W) // 2 + W, (zh - H) // 2 + H))
    img.paste(a, (0, 0))
    box = region(now)
    if tag:
        _tag(img, box, tag)
    v = dd.get("verdict")
    if v and not ctx.get("cta"):
        frac = v[1]
        t0 = cur["start"] + frac * (cur["end"] - cur["start"])
        if t >= t0:
            _stamp(img, main_box(now), v[0], (t - t0) / 0.5)


def sfx_for(lines_def, L):
    ev = mapscene.sfx(lines_def, L)
    for d in lines_def:
        v = d.get("verdict")
        if v and d["id"] in L:
            l = L[d["id"]]
            ev.append((l["start"] + v[1] * (l["end"] - l["start"]), "pop"))
    return sorted(ev)


# ---- 共通の部品 ---------------------------------------------------------------------------

def ball_at(d, cx, cy, r, ang=0.0, seam=True, fill=BALL, outline=(250, 250, 235), w=3):
    """テニスボール(黄緑の丸＋白い縫い目)。ang で縫い目が回る。縫い目は丸の中だけに描く。"""
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill, outline=outline, width=max(2, int(w * S)))
    if seam and r > 8:
        n = int(2 * r) + 4
        lay = Image.new("RGBA", (n, n), (0, 0, 0, 0))
        ld = ImageDraw.Draw(lay)
        c = n / 2
        for sgn in (-1, 1):
            bx = c + sgn * r * 1.2 * math.cos(ang)
            by = c + sgn * r * 1.2 * math.sin(ang)
            ld.ellipse([bx - r * 0.95, by - r * 0.95, bx + r * 0.95, by + r * 0.95], outline=(250, 250, 240, 255), width=max(2, int(r * 0.07)))
        m = Image.new("L", (n, n), 0)
        ImageDraw.Draw(m).ellipse([c - r + 3, c - r + 3, c + r - 3, c + r - 3], fill=255)
        lay.putalpha(Image.composite(lay.getchannel("A"), Image.new("L", (n, n), 0), m))
        d._image.alpha_composite(lay, (int(cx - c), int(cy - c)))


def cap(d, xy, s, size=30, col=O.DIM, anchor="mm"):
    """箱なしの小さな注記(重なりの点検には載せない)。"""
    text(d, xy, s, size, col, anchor, 3)


def hbracket(d, x0, x1, y, s, col=O.YEL, size=34, up=True, lab=True):
    d.line([(x0, y), (x1, y)], fill=col, width=max(2, int(4 * S)))
    for x in (x0, x1):
        d.line([(x, y - 14 * S), (x, y + 14 * S)], fill=col, width=max(2, int(4 * S)))
    if lab:
        label(d, ((x0 + x1) / 2, y + (-48 if up else 48) * S), s, size, col)


def vbracket(d, x, y0, y1, col=O.YEL):
    d.line([(x, y0), (x, y1)], fill=col, width=max(2, int(4 * S)))
    for y in (y0, y1):
        d.line([(x - 14 * S, y), (x + 14 * S, y)], fill=col, width=max(2, int(4 * S)))


VAL = {0: None, 1: 0, 2: -13, 3: 0, 4: -58, 5: 0, 6: 0, 7: 0, 8: (-38, -79), 9: 0}
MTXT = {1: ("外れ幅 0cm", O.GREEN), 2: ("外れ幅 13cm低い", O.RED), 3: ("外れ幅 0cm", O.GREEN), 4: ("外れ幅 58cm低い", O.RED),
        5: ("外れ幅 0cm", O.GREEN), 6: ("0cm（測定範囲の外）", O.YEL), 7: ("外れ幅 0cm", O.GREEN),
        8: ("38〜79cm外れ", O.RED), 9: ("外れ幅 0cm", O.GREEN)}


def split(box, P):
    """meter のある場面は、左に図・右(縦なら下)にメーター。"""
    x0, y0, x1, y1 = box
    if not P.get("meter"):
        return box, None
    if LAND:
        xm = x0 + (x1 - x0) * 0.66
        return (x0, y0, xm, y1), (xm + 10 * S, y0, x1, y1)
    ym = y0 + (y1 - y0) * 0.50
    return (x0, y0, x1, ym), (x0, ym, x1, y1)


def meter(img, mb, spec, k, t, full=False):
    """外れ幅メーター(全編を貫く軸)。0cm を中心にした縦の目盛り。上が「越える」、下が「刺さる」。"""
    x0, y0, x1, y1 = mb
    d = ImageDraw.Draw(img)
    grad(img, box=mb)
    n = spec.get("n", 0)
    frame = spec.get("frame", False) or n in (8, 9)
    stage = spec.get("stage", 0)
    hh = 150 * S if LAND else 118 * S
    ftr = 30 * S
    top_v, bot_v = 14.0, -86.0
    ppc = ((y1 - y0) - hh - ftr) / (top_v - bot_v) * -1
    ppc = abs(ppc)
    yv = lambda v: y0 + hh + (top_v - v) * ppc
    cx = x0 + (x1 - x0) * (0.30 if not full else 0.36)
    bw = (64 if full else 40) * S
    label(d, ((x0 + x1) / 2, y0 + 40 * S), "外れ幅メーター", 38 if LAND else 34, O.WHITE)
    sub = "基準：ラケットの面の端" if frame else "基準：ネットの上端にふれる高さ"
    cap(d, ((x0 + x1) / 2, y0 + 92 * S), sub, 28 if LAND else 26, O.YEL if frame else O.DIM)
    # 帯
    if not frame:
        d.rectangle([cx - bw / 2, yv(top_v), cx + bw / 2, yv(0)], fill=(60, 105, 165))
        d.rectangle([cx - bw / 2, yv(0), cx + bw / 2, yv(-6.7)], fill=(70, 200, 120))
        d.rectangle([cx - bw / 2, yv(-6.7), cx + bw / 2, yv(bot_v)], fill=(150, 62, 62))
    else:
        d.rectangle([cx - bw / 2, yv(top_v), cx + bw / 2, yv(0)], fill=(70, 200, 120))
        d.rectangle([cx - bw / 2, yv(0), cx + bw / 2, yv(bot_v)], fill=(150, 62, 62))
    # 目盛り
    for v in range(10, -81, -10):
        yy = yv(v)
        d.line([(cx - bw / 2 - 14 * S, yy), (cx - bw / 2, yy)], fill=O.WHITE, width=max(2, int(3 * S)))
        text(d, (cx - bw / 2 - 22 * S, yy), "0" if v == 0 else (f"+{v}" if v > 0 else f"{v}"), 28, O.WHITE if v == 0 else O.DIM, "rm", 3)
    d.line([(cx - bw / 2 - 22 * S, yv(0)), (cx + bw / 2 + 12 * S, yv(0))], fill=O.WHITE, width=max(3, int(5 * S)))
    cap(d, (cx - bw / 2 - 22 * S, yv(top_v) - 4 * S), "cm", 26, O.DIM, "rd")
    # 越える・刺さる
    xr = x1 - 18 * S
    if not frame:
        text(d, (xr, yv(8)), "↑ 越える", 34, (150, 200, 250), "rm", 4)
        text(d, (xr, yv(-80)), "↓ 刺さる", 34, (250, 150, 140), "rm", 4)
        if stage >= 1:
            cap(d, (cx + bw / 2 + 24 * S, yv(-6.7) + 22 * S), "ふれる 6.7cm", 28, O.GREEN, "lm")
    else:
        text(d, (xr, yv(8)), "↑ 当たり", 34, (130, 230, 160), "rm", 4)
        text(d, (xr, yv(-80)), "↓ 外れ", 34, (250, 150, 140), "rm", 4)
    # 前の実験の跡
    if LAND and n:
        for m in range(1, n):
            if (m >= 8) != (n >= 8):
                continue
            v = VAL[m]
            if isinstance(v, tuple):
                continue
            yy = yv(v)
            d.ellipse([cx - 9 * S, yy - 9 * S, cx + 9 * S, yy + 9 * S], fill=(230, 235, 245), outline=O.NAVY, width=2)
    # いまの値
    if n:
        v = VAL[n]
        u = _ease(k * 2.0)
        s, col = MTXT[n]
        if isinstance(v, tuple):
            ya, yb = yv(v[0]), yv(v[1])
            d.rectangle([cx - bw / 2 - 6 * S, ya, cx + bw / 2 + 6 * S, yb], fill=(250, 90, 80, 255))
            ym = (ya + yb) / 2
            tri = [(cx + bw / 2 + 12 * S, ym), (cx + bw / 2 + 52 * S, ym - 20 * S), (cx + bw / 2 + 52 * S, ym + 20 * S)]
            d.polygon(tri, fill=col)
            label(d, (cx + bw / 2 + 62 * S, ym), s, 34 if LAND else 30, col, "lm")
        else:
            pv = VAL.get(n - 1) if n - 1 in VAL and not isinstance(VAL.get(n - 1), tuple) and (n - 1) >= 1 else 0
            if n == 9:
                pv = -60
            vv = (pv if pv is not None else 0) + (v - (pv if pv is not None else 0)) * u
            ym = yv(vv)
            tri = [(cx + bw / 2 + 8 * S, ym), (cx + bw / 2 + 50 * S, ym - 22 * S), (cx + bw / 2 + 50 * S, ym + 22 * S)]
            d.polygon(tri, fill=col, outline=O.NAVY)
            label(d, (cx + bw / 2 + 62 * S, ym - (30 * S if v == 0 and not LAND else 0)), s, 34 if LAND else 30, col, "lm")
    elif spec.get("zero"):
        ym = yv(0)
        d.polygon([(cx + bw / 2 + 8 * S, ym), (cx + bw / 2 + 50 * S, ym - 22 * S), (cx + bw / 2 + 50 * S, ym + 22 * S)], fill=O.GREEN, outline=O.NAVY)
        label(d, (cx + bw / 2 + 62 * S, ym), "0cm", 34 if LAND else 30, O.GREEN, "lm")
    note = spec.get("note")
    if note:
        cap(d, ((x0 + x1) / 2, y1 - 14 * S), note, 26, O.DIM, "md")


def sc_meterbig(img, box, t, k, P):
    """メーターだけを大きく出す(1章・6章)。stage 0: 軸だけ / 1: 0cm と窓 / 2: 基準を替えると言う / 3: ラケットの面へ替わる。"""
    x0, y0, x1, y1 = box
    grad(img, box=box)
    st = P.get("stage", 0)
    mb = (x0 + (x1 - x0) * 0.04, y0, x0 + (x1 - x0) * (0.52 if LAND else 1.0), y1) if LAND else (x0, y0 + (y1 - y0) * 0.28, x1, y1)
    d = ImageDraw.Draw(img)
    spec = dict(n=0, stage=1 if st >= 1 else 0, frame=(st == 3))
    meter(img, mb, spec, k, t, full=True)
    d = ImageDraw.Draw(img)
    items = {0: [("ものさしは 1つ", O.YEL), ("名前は「外れ幅」", O.WHITE)],
             1: [("0cm", O.GREEN), ("ボールの下が ネットの上端に", O.WHITE), ("ちょうどふれる高さ", O.WHITE)],
             2: [("実験ごとに", O.WHITE), ("外れ幅を 言います", O.YEL), ("ラケットの話になったら", O.WHITE), ("基準を替えます", O.RED)],
             3: [("基準が替わる", O.YEL), ("ラケットの面の端から", O.WHITE), ("何cm外れたか", O.WHITE), ("0cmなら 当たり", O.GREEN)]}[st]
    if LAND:
        bx0, bx1 = x0 + (x1 - x0) * 0.56, x1 - 30 * S
        by = (y0 + y1) / 2 - 62 * S * (len(items) - 1) / 2 - 20 * S
        for i, (s, col) in enumerate(items):
            a = _ease(k * 4 - i * 0.7)
            if a <= 0:
                continue
            c = tuple(int(v * a + 20 * (1 - a)) for v in col)
            sz = 84 if i == 0 and st in (0, 1, 3) else 46
            sz = 100 if (st == 1 and i == 0) else sz
            text(d, ((bx0 + bx1) / 2, by + i * 78 * S + (20 * S if i else 0)), s, sz, c, "mm", 6)
    else:
        by = y0 + 30 * S
        for i, (s, col) in enumerate(items):
            a = _ease(k * 4 - i * 0.7)
            if a <= 0:
                continue
            c = tuple(int(v * a + 20 * (1 - a)) for v in col)
            text(d, ((x0 + x1) / 2, by + i * 60 * S), s, 56 if i == 0 else 38, c, "mm", 6)


# ---- コートの側面図 -----------------------------------------------------------------------

CENTER_NET = 0.914 + 0.0335   # ネットの上端にボールの下がふれるときのボールの中心の高さ(m)


def traj_fn(ang, off, land=None):
    """(x[m]→ボール中心の高さ[m]) と、着地の x。ネットは 11.9m。off は外れ幅(cm低い)。"""
    a = math.tan(math.radians(ang))
    cn = CENTER_NET - off / 100.0
    b = (1.0 + a * 11.9 - cn) / 11.9 ** 2
    sn = a - 2 * b * 11.9
    if land is None:
        disc = a * a + 4 * b * (1.0 - 0.0335)
        xl = (a + math.sqrt(disc)) / (2 * b)
        c2 = b
    else:
        xl = land
        c2 = (cn + sn * (land - 11.9) - 0.0335) / (land - 11.9) ** 2

    def f(x):
        if x <= 11.9:
            return 1.0 + a * x - b * x * x
        dx = x - 11.9
        return cn + sn * dx - c2 * dx * dx
    return f, xl, cn


def court_geom(box, P):
    x0, y0, x1, y1 = box
    netfirst = P.get("netfirst", False)
    gx0 = x0 + (130 if P.get("netfirst") else 70) * S
    ppm = ((x1 - x0) - 140 * S) / 19.0
    gy = y1 - 120 * S
    vs = min(ppm * 4.9, (gy - (y0 + (y1 - y0) * 0.30)) / 1.5)
    return dict(gx0=gx0, ppm=ppm, gy=gy, vs=vs, netfirst=netfirst,
                xn=(gx0 if netfirst else gx0 + 11.9 * ppm))


def sc_court(img, box, t, k, P):
    mainb, mb = split(box, P)
    x0, y0, x1, y1 = mainb
    grad(img, box=mainb)
    d = ImageDraw.Draw(img)
    g = court_geom(mainb, P)
    gx0, ppm, gy, vs = g["gx0"], g["ppm"], g["gy"], g["vs"]
    px = lambda xm: gx0 + xm * ppm
    py = lambda h: gy - h * vs
    stage = P.get("stage", 0)
    netfirst = g["netfirst"]
    # 地面
    d.rectangle([x0, gy, x1, y1], fill=(40, 90, 70))
    d.line([(x0, gy), (x1, gy)], fill=(190, 230, 200), width=max(2, int(4 * S)))
    xn = g["xn"]
    # ネット
    nt = py(0.914)
    d.rectangle([xn - 5 * S, nt, xn + 5 * S, gy], fill=(120, 130, 150))
    for yy in range(int(nt), int(gy), int(max(8, 14 * S))):
        d.line([(xn - 12 * S, yy), (xn + 12 * S, yy)], fill=(110, 125, 150), width=1)
    d.rectangle([xn - 14 * S, nt - 4 * S, xn + 14 * S, nt + 4 * S], fill=O.WHITE)
    if netfirst:
        xb = px(11.9)
        d.line([(xb, gy), (xb, gy - 60 * S)], fill=O.WHITE, width=max(3, int(6 * S)))
        label(d, (xb, gy + 45 * S), "コートの一番後ろの線", 30, O.WHITE)
        hbracket(d, xn, xb, gy - 90 * S, "11.9m", O.YEL, 40)
        label(d, (xn, gy + 45 * S), "ネット", 30, O.WHITE)
        # 割れた殻が飛ぶ矢印
    else:
        # 打つ点・ベースライン
        d.line([(gx0, gy), (gx0, gy - 60 * S)], fill=O.WHITE, width=max(3, int(6 * S)))
        label(d, (gx0 + 30 * S, gy + 45 * S), "ベースライン", 30, O.WHITE, "lm") if False else label(d, (gx0 + 90 * S, gy + 45 * S), "ベースライン", 30, O.WHITE)
        label(d, (xn, gy + 45 * S), "ネット", 30, O.WHITE)
        d.ellipse([gx0 - 8 * S, py(1.0) - 8 * S, gx0 + 8 * S, py(1.0) + 8 * S], fill=O.YEL)
        if stage in (0, 1, 2):
            d.line([(gx0 - 30 * S, py(1.0)), (gx0 - 30 * S, gy)], fill=O.YEL, width=max(2, int(3 * S)))
            if stage == 1:
                label(d, (gx0 + 20 * S, py(1.0) - 60 * S), "打つ高さ 1.0m（仮）", 34, O.YEL, "lm")
        if stage == 2:
            hbracket(d, gx0, xn, gy - 90 * S, "11.9m", O.YEL, 42)
        if stage in (1, 2):
            label(d, (xn, nt - 62 * S), "ネットの上端 0.914m", 30, O.WHITE)
    # 軌道
    for pth in P.get("paths", []):
        f, xl, cn = traj_fn(pth["ang"], pth.get("off", 0), pth.get("land"))
        hit = pth.get("hit", False)
        xend = 11.9 if hit else min(xl, 19.0)
        ghost = pth.get("ghost", False)
        col = pth.get("col", O.DIM if ghost else O.YEL)
        u = 1.0 if ghost else _ease(k * 1.15)
        xc = xend * u
        pts = [(px(xc * i / 80), py(f(xc * i / 80))) for i in range(81)]
        if ghost:
            for i in range(0, 80, 2):
                d.line([pts[i], pts[i + 1]], fill=col, width=max(2, int(4 * S)))
        else:
            d.line(pts, fill=col, width=max(3, int(7 * S)), joint="curve")
            bx, by = pts[-1]
            if hit and u >= 0.999:
                # ネットに当たって落ちる
                yb = py(0.0335)
                dd = _ease((k - 0.8) * 5)
                by2 = by + (yb - by) * dd
                d.line([(bx, by), (bx - 8 * S, by2)], fill=mix(col, BG1, 0.5), width=max(2, int(4 * S)))
                ball_at(d, bx - 8 * S, by2, 13 * S, t * 4)
            else:
                ball_at(d, bx, by, 13 * S, t * 6)
            # 着地
            if not hit and u >= 0.999 and pth.get("show_land"):
                lab = pth["show_land"]
                d.ellipse([px(xl) - 8 * S, gy - 8 * S, px(xl) + 8 * S, gy + 8 * S], fill=col)
                label(d, (px(xl), gy + 45 * S), lab, 30, col)
            # 角度
            if pth.get("ang_lab") and k > 0.15:
                label(d, (gx0 + 130 * S, py(1.0) - 90 * S - (0 if not ghost else 60 * S)), pth["ang_lab"], 34, col, "lm") if False else None
        if pth.get("gap") and not ghost:
            fa, _, cn0 = traj_fn(pth["ang"], 0, None)
            ya, yb = py(CENTER_NET), py(cn)
            d.ellipse([xn - 13 * S, ya - 13 * S, xn + 13 * S, ya + 13 * S], outline=O.GREEN, width=max(2, int(4 * S)))
            if u > 0.99:
                vbracket(d, xn + 60 * S, ya, yb, O.RED)
                if LAND:
                    label(d, (xn + 84 * S, (ya + yb) / 2), pth["gap"], 30, O.RED, "lm")
                else:
                    g1, g2 = pth["gap"].split("・")
                    label(d, (xn + 84 * S, (ya + yb) / 2 - 30 * S), g1, 30, O.RED, "lm")
                    label(d, (xn + 84 * S, (ya + yb) / 2 + 30 * S), g2, 30, O.RED, "lm")
    if P.get("ang_text"):
        label(d, (gx0 + 260 * S, y0 + (y1 - y0) * 0.16), P["ang_text"], 36, O.YEL)
    cap(d, (x1 - 50 * S, y1 - 14 * S), "縦は拡大して描いています", 24, O.DIM, "rd")
    if P.get("head"):
        head(d, mainb, P["head"], O.YEL, 38)
    if mb:
        meter(img, mb, P["meter"], k, t)


# ---- 窓(ネットの上端の拡大) ---------------------------------------------------------------

def sc_window(img, box, t, k, P):
    mainb, mb = split(box, P)
    x0, y0, x1, y1 = mainb
    grad(img, box=mainb)
    d = ImageDraw.Draw(img)
    st = P.get("stage", 0)
    w, h = x1 - x0, y1 - y0
    R = min(h * 0.17, w * 0.1)
    ytop = y0 + h * 0.56
    if st == 1:
        R = min(h * 0.095, w * 0.07)
        ytop = y0 + h * 0.42
    ppc = 2 * R / 6.7
    d.rectangle([x0, ytop, x1, y1], fill=(34, 48, 80))
    for xx in range(int(x0), int(x1), int(max(16, 30 * S))):
        d.line([(xx, ytop + 8 * S), (xx, y1)], fill=(52, 70, 108), width=1)
    d.rectangle([x0, ytop - 6 * S, x1, ytop + 6 * S], fill=O.WHITE)
    if st in (0, 1):
        cap(d, (x0 + 50 * S, ytop + 40 * S), "ネットの上端（白い帯）", 28, O.DIM, "la")

    def ballc(cxx, bottom_off, col=BALL, ghost=False):
        cy = ytop - 6 * S - R - bottom_off * ppc if bottom_off >= 0 else ytop - 6 * S - R - bottom_off * ppc
        if ghost:
            d.ellipse([cxx - R, cy - R, cxx + R, cy + R], outline=col, width=max(3, int(5 * S)))
        else:
            ball_at(d, cxx, cy, R, 0.4, True)
        return cy
    if st == 0:
        cx = x0 + w * 0.5
        ballc(cx, 0)
        label(d, (cx, ytop - 2 * R - 90 * S), "ボールの下が ちょうどふれる", 40, O.GREEN)
        label(d, (cx + R + 170 * S, ytop - 6 * S - 22 * S), "外れ幅 0cm", 44, O.GREEN) if False else None
    elif st == 1:
        cols = [0.15, 0.38, 0.62, 0.85]
        offs = [6.7, 0, -6.7, -13.4]
        labs = [("高い", "越える", (150, 200, 250)), ("0cm", "下がふれる", O.GREEN), ("6.7cm低い", "上がふれる", O.GREEN), ("それより低い", "刺さる", (250, 150, 140))]
        for i, (cf, off) in enumerate(zip(cols, offs)):
            a = _ease(k * 3.5 - i * 0.6)
            if a <= 0:
                continue
            cxx = x0 + w * cf
            cy = ytop - 6 * S - R - off * ppc
            ball_at(d, cxx, cy, R * 0.9 if False else R, 0.4 + i, True, outline=labs[i][2])
            label(d, (cxx, y1 - 90 * S), labs[i][0], 30, labs[i][2])
            label(d, (cxx, y1 - 38 * S), labs[i][1], 30, labs[i][2])
        # ボールの下の高さ(横に引いた印)
    elif st in (2, 5):
        xs0, xs1 = x0 + w * 0.2, x0 + w * 0.8
        cA, cB = x0 + w * 0.34, x0 + w * 0.66
        d.rectangle([xs0, ytop - 6 * S, xs1, ytop + 2 * R - 6 * S], fill=(60, 170, 110, 255) if False else (40, 120, 85))
        d.rectangle([xs0, ytop - 6 * S, xs1, ytop + 2 * R - 6 * S], outline=O.GREEN, width=max(2, int(4 * S)))
        d.rectangle([x0, ytop - 6 * S, x1, ytop + 6 * S], fill=O.WHITE)
        yA = ytop - 6 * S - R
        yB = ytop - 6 * S + R
        d.ellipse([cA - R, yA - R, cA + R, yA + R], outline=BALL, width=max(3, int(5 * S)))
        d.ellipse([cB - R, yB - R, cB + R, yB + R], outline=BALL, width=max(3, int(5 * S)))
        d.line([(cA, yA + R), (cA, yA + R)], fill=O.WHITE)
        cap(d, (cA, yA - R - 22 * S), "下がふれる 0cm", 28, O.GREEN)
        cap(d, (cB, yB + R + 28 * S), "上がふれる 6.7cm低い", 28, O.GREEN)
        vbracket(d, xs1 + 40 * S, ytop - 6 * S, ytop + 2 * R - 6 * S, O.YEL)
        label(d, (xs1 + 60 * S, ytop + R - 6 * S), "ボール1個分", 30, O.YEL, "lm")
        if st == 2:
            label(d, ((xs0 + xs1) / 2, ytop + R * 0.9), "窓", 56, O.GREEN)
            head(d, mainb, "ボールの下の高さが この範囲なら、ボールのどこかがふれる", O.WHITE, 30)
    elif st == 6:
        # 窓の上限(これより上は越える)
        xs0, xs1 = x0 + w * 0.2, x0 + w * 0.8
        d.rectangle([xs0, ytop - 6 * S, xs1, ytop + 2 * R - 6 * S], fill=(40, 120, 85), outline=O.GREEN, width=max(2, int(4 * S)))
        d.rectangle([x0, ytop - 6 * S, x1, ytop + 6 * S], fill=O.WHITE)
        label(d, ((xs0 + xs1) / 2, ytop + R * 0.9), "窓", 56, O.GREEN)
        arrow(d, x0 + w * 0.5, ytop - 50 * S, x0 + w * 0.5, ytop - 6 * S - 3 * R, 12 * S, (150, 200, 250))
        label(d, (x0 + w * 0.5 + 40 * S, ytop - 6 * S - 2 * R - 20 * S), "上限 6.93°　これより上へ向けると 越える", 36, (150, 200, 250), "lm")
    if mb:
        meter(img, mb, P["meter"], k, t)


def sc_angline(img, box, t, k, P):
    """窓の角度(約6.60〜6.93°)の数直線。stage 0: 幅約0.32°、1°の約3分の1 / 1: 上限の印。"""
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    st = P.get("stage", 0)
    ax0, ax1 = x0 + 90 * S, x1 - 90 * S
    pa = lambda a: ax0 + (ax1 - ax0) * (a - 6.0) / 1.0
    yl = y0 + (y1 - y0) * (0.55 if LAND else 0.45)
    d.line([(ax0, yl), (ax1, yl)], fill=O.WHITE, width=max(3, int(5 * S)))
    for i in range(0, 11):
        a = 6.0 + i / 10
        d.line([(pa(a), yl - 14 * S), (pa(a), yl + 14 * S)], fill=O.DIM, width=max(2, int(3 * S)))
        if i % 2 == 0:
            text(d, (pa(a), yl + 40 * S), f"{a:.1f}°", 28, O.DIM, "ma", 3)
    u = _ease(k * 1.6)
    wx0, wx1 = pa(6.60), pa(6.60 + 0.33 * u)
    d.rectangle([wx0, yl - 30 * S, wx1, yl + 30 * S], fill=(70, 200, 120))
    label(d, (pa(6.60), yl - 100 * S), "6.60°", 36, O.GREEN, "ra") if False else None
    if u > 0.9:
        label(d, (pa(6.60) - 60 * S, yl - 90 * S), "6.60°", 36, O.GREEN)
        label(d, (pa(6.93) + 60 * S, yl - 90 * S), "6.93°", 36, O.GREEN)
        if st == 0:
            hbracket(d, pa(6.60), pa(6.93), yl + 130 * S, "窓の幅 約0.32°", O.GREEN, 38, up=False)
            hbracket(d, pa(6.0), pa(7.0), yl + 230 * S, "1°の約3分の1", O.YEL, 38, up=False)
    if st == 1:
        arrow(d, pa(6.93) + 12 * S, yl - 60 * S, pa(7.0) + 40 * S, yl - 60 * S, 10 * S, (150, 200, 250))
        label(d, (pa(6.93) - 120 * S, yl - 170 * S), "これより上へ向けると 越える", 36, (150, 200, 250))
        label(d, (pa(6.93), yl + 130 * S), "窓の上限", 38, O.GREEN) if False else None
        hbracket(d, pa(6.60), pa(6.93), yl + 130 * S, "窓の上限が 6.93°", O.GREEN, 38, up=False)
    head(d, box, "窓を 角度にすると", O.WHITE, 40)
    cap(d, ((x0 + x1) / 2, y1 - 20 * S), "秒速30m・打つ高さ1.0m・毎分3,000回転の計算", 26, O.DIM, "md")


def sc_uncert(img, box, t, k, P):
    """角度は計算の仮定しだいで ±0.7° 動く。窓(0.32°)よりずっと大きい。"""
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    ax0, ax1 = x0 + 90 * S, x1 - 90 * S
    pa = lambda a: ax0 + (ax1 - ax0) * (a - 5.6) / 2.6
    yl = y0 + (y1 - y0) * (0.5 if LAND else 0.42)
    d.line([(ax0, yl), (ax1, yl)], fill=O.WHITE, width=max(3, int(5 * S)))
    for i in range(0, 14):
        a = 5.6 + i * 0.2
        d.line([(pa(a), yl - 12 * S), (pa(a), yl + 12 * S)], fill=O.DIM, width=max(2, int(3 * S)))
        if i % 2 == 0:
            text(d, (pa(a), yl + 36 * S), f"{a:.1f}°", 26, O.DIM, "ma", 3)
    u = _ease(k * 1.6)
    mid = (6.60 + 6.93) / 2
    d.rectangle([pa(mid - 0.7 * u), yl - 70 * S, pa(mid + 0.7 * u), yl - 36 * S], fill=(150, 62, 62))
    d.rectangle([pa(6.60), yl - 30 * S, pa(6.93), yl + 30 * S], fill=(70, 200, 120))
    if u > 0.9:
        label(d, (pa(mid), yl - 130 * S), "計算の仮定しだいで ±0.7° 動く", 38, O.RED)
        label(d, (pa(mid), yl + 130 * S), "窓の幅 約0.32°", 38, O.GREEN)
        if P.get("stage", 0) >= 1:
            label(d, (pa(mid), yl + 230 * S), "本当の角度は 窓の外かもしれない", 38, O.YEL)
    head(d, box, "角度は 見積もりでずれる", O.WHITE, 40)


# ---- 角度の説明 ---------------------------------------------------------------------------

def sc_angle(img, box, t, k, P):
    """打ち出す向き(水平から上向き)。rays=[(角度, 札, 色, 薄い)]、tri=(進む, 上がる)。絵の角度は大きく描く。"""
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    ox, oy = x0 + 150 * S, y0 + (y1 - y0) * 0.72
    Lr = (x1 - x0) * (0.62 if LAND else 0.7)
    d.line([(ox, oy), (ox + Lr + 40 * S, oy)], fill=(190, 230, 200), width=max(3, int(5 * S)))
    cap(d, (ox + Lr + 40 * S, oy + 36 * S), "水平（0°）", 28, O.DIM, "rm")
    mag = 5.0 if max(r[0] for r in P["rays"]) < 5 else 3.0
    for j, (ang, lab, col, dim) in enumerate(P["rays"]):
        a = _ease(k * 1.8 - j * 0.3)
        th = math.radians(ang * mag) * (a if a < 1 else 1)
        ex, ey = ox + Lr * math.cos(th), oy - Lr * math.sin(th)
        c = mix(col, BG0, 0.45) if dim else col
        d.line([(ox, oy), (ex, ey)], fill=c, width=max(3, int((5 if dim else 9) * S)))
        r = (110 + 40 * j) * S
        d.arc([ox - r, oy - r, ox + r, oy + r], -math.degrees(th), 0, fill=c, width=max(2, int(4 * S)))
        if a > 0.8:
            last = j == len(P["rays"]) - 1
            fr = (0.35 if len(P["rays"]) == 1 else 0.62) if last else 0.62
            lx, ly = ox + Lr * fr * math.cos(th), oy - Lr * fr * math.sin(th)
            label(d, (lx, ly + (-52 if last else 52) * S), lab, 34, col)
    if P.get("tri"):
        run, rise = P["tri"]
        if k > 0.4:
            xr = ox + Lr * 0.82
            ang = P["rays"][-1][0]
            th = math.radians(ang * mag)
            yt = oy - (xr - ox) * math.tan(th)
            d.line([(xr, oy), (xr, yt)], fill=O.RED, width=max(3, int(6 * S)))
            label(d, (xr + 30 * S, (oy + yt) / 2), rise, 36, O.RED, "lm")
            label(d, ((ox + xr) / 2, oy + 60 * S), run, 36, O.YEL)
    if P.get("head"):
        head(d, box, P["head"], O.WHITE, 38)
    cap(d, ((x0 + x1) / 2, y1 - 20 * S), "角度は大きく描いています", 24, O.DIM, "md")


def sc_deg1(img, box, t, k, P):
    """角度が1°ずれると、ネットの高さで約20cm(ボール3個分)ずれる。"""
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    ox, oy = x0 + 120 * S, y0 + (y1 - y0) * 0.62
    xn = x1 - (520 if LAND else 400) * S
    Ln = xn - ox
    mag = 9.0
    th0 = math.radians(4.0 * mag) * 0
    ya = oy - Ln * math.tan(math.radians(1.2 * mag))
    yb = oy - Ln * math.tan(math.radians(2.2 * mag))
    u = _ease(k * 1.5)
    d.line([(ox, oy), (xn, oy)], fill=(190, 230, 200), width=max(2, int(3 * S)))
    for yy, col in ((ya, O.GREEN), (yb, O.RED)):
        d.line([(ox, oy), (ox + (xn - ox) * u, oy + (yy - oy) * u)], fill=col, width=max(3, int(7 * S)))
    d.rectangle([xn - 6 * S, oy - 20 * S - (oy - yb), xn + 6 * S, oy + 10 * S], fill=(120, 130, 150)) if False else None
    if u > 0.95:
        vbracket(d, xn + 30 * S, yb, ya, O.YEL)
        label(d, (xn + 30 * S, yb - 60 * S), "ネットの高さで 約20cm", 34, O.YEL)
        r = (ya - yb) / 6.0
        for i in range(3):
            ball_at(d, xn + 110 * S, yb + r * (2 * i + 1), r, 0.3 * i, True)
        label(d, (xn + 110 * S, ya + 56 * S), "ボール3個分", 34, O.WHITE)
        label(d, (ox + 260 * S, oy + 90 * S), "角度が 1° ずれる", 38, O.WHITE) if False else None
    head(d, box, "角度が1°ずれると", O.WHITE, 40)
    cap(d, ((x0 + x1) / 2, y1 - 20 * S), "角度と高さは大きく描いています", 24, O.DIM, "md")


# ---- 速さ・回転 -----------------------------------------------------------------------------

def sc_speed(img, box, t, k, P):
    """速さのメーター。stage 0: 秒速30m(新幹線と比べる) / 1: 秒速30m→23.9m(約2割遅くなる)。"""
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    st = P.get("stage", 0)
    both = (st == 0)
    if both and LAND:
        dx0, dx1, dy0, dy1 = x0, x0 + (x1 - x0) * 0.5, y0, y1
        bbox = (x0 + (x1 - x0) * 0.52, y0, x1, y1)
    elif both:
        dx0, dx1, dy0, dy1 = x0, x1, y0 + 80 * S, y0 + (y1 - y0) * 0.5
        bbox = (x0, y0 + (y1 - y0) * 0.52, x1, y1)
    else:
        dx0, dx1, dy0, dy1 = x0, x1, y0, y1
    cx = (dx0 + dx1) / 2
    R = min((dx1 - dx0) * 0.34, (dy1 - dy0) * 0.62)
    cy = (dy0 + dy1) / 2 + R * 0.45
    u = _ease(k * 1.5)
    v = 30.0 if st == 0 else 30.0 + (23.9 - 30.0) * u
    if st == 0:
        v = 30.0 * u
    dial(d, cx, cy, R, 40, v, [(0, "0"), (10, "10"), (20, "20"), (30, "30"), (40, "40")], zones=[])
    text(d, (cx, cy + 62 * S), f"秒速 {v:.1f}m" if st == 1 else f"秒速 {v:.0f}m", 62, O.YEL, "mm", 6)
    text(d, (cx, cy + 135 * S), f"時速 約{v * 3.6:.0f}km", 42, O.WHITE, "mm", 5)
    if st == 1 and u > 0.9:
        label(d, (cx, cy - R * 0.35), "約2割 遅くなる", 40, O.RED)
        cap(d, (cx, cy - R - 90 * S), "ネットに着くころ", 30, O.DIM)
    if both:
        rows = [("このボール", 30, None, "秒速30m（時速108km）", O.YEL), ("新幹線", 88.9, None, "秒速89m（時速320km）", (120, 150, 190))]
        bars(d, bbox, rows, 110, k, 0, (), True, y_top=bbox[1] + (170 if LAND else 40) * S)
        label(d, ((bbox[0] + bbox[2]) / 2, bbox[1] + (110 if LAND else 30) * S), "新幹線の約3分の1", 38, O.YEL) if LAND else label(d, (cx, y0 + 40 * S), "新幹線の約3分の1", 38, O.YEL)


def sc_spin(img, box, t, k, P):
    """回転。stage 0: 回るボール(超回転) / 1: 毎分3,000回転のメーター / 2: 3,000→5,000回転(測られた範囲)。"""
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    st = P.get("stage", 0)
    if st == 0:
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2 - 20 * S
        r = min((x1 - x0), (y1 - y0)) * 0.26
        ball_at(d, cx, cy, r, t * 9, True, w=4)
        rr = r * 1.35
        for a in (30, 150, 270):
            d.arc([cx - rr, cy - rr, cx + rr, cy + rr], a, a + 70, fill=O.YEL, width=max(4, int(8 * S)))
            th = math.radians(a + 70)
            ex, ey = cx + rr * math.cos(th), cy + rr * math.sin(th)
            d.polygon([(ex, ey), (ex - 26 * S * math.cos(th - 0.6), ey - 26 * S * math.sin(th - 0.6)), (ex - 26 * S * math.cos(th + 0.5), ey - 26 * S * math.sin(th + 0.5))], fill=O.YEL)
        label(d, (cx, y0 + 60 * S), "超回転　ふつうよりずっと強い回転", 42, O.YEL)
        return
    v1 = P.get("v1", 3000)
    v0 = P.get("v0", v1)
    u = _ease(k * 1.5)
    v = v0 + (v1 - v0) * u
    R = min((x1 - x0) * 0.34, (y1 - y0) * 0.5)
    cx = (x0 + x1) / 2 + (R * 0.0)
    cy = (y0 + y1) / 2 + R * 0.55
    zones = [(0, 4300, (50, 120, 90))] if st == 2 else []
    dial(d, cx, cy, R, 6000, v, [(0, "0"), (1000, "1千"), (2000, "2千"), (3000, "3千"), (4000, "4千"), (5000, "5千"), (6000, "6千")], zones=zones)
    text(d, (cx, cy + 62 * S), f"毎分 {int(round(v / 100.0) * 100):,}回転", 60, O.YEL, "mm", 6)
    if st == 1:
        text(d, (cx, cy + 135 * S), "1秒に 50回転", 46, O.WHITE, "mm", 5)
        ball_at(d, cx, cy - R * 0.45, 62 * S, t * 12, True)
    if st == 2:
        label(d, (cx, cy + 140 * S), "測られた範囲をわずかに超える（目安の値）" if LAND else "測られた範囲を\nわずかに超える（目安）".replace("\n", ""), 34 if LAND else 28, O.YEL)
        cap(d, (cx - R * 0.95, cy - R * 0.2 - 90 * S), "緑＝測られた範囲", 28, (130, 230, 160), "ra") if False else None
    head(d, box, "回転の速さ（毎分の回転数）" if st != 2 else "回転を 5,000回転に増やす", O.WHITE, 38)


def sc_magnus(img, box, t, k, P):
    """前に回るボールは、空気の流れで下へ押される。stage 0: 図 / 1: 力の大きさ。"""
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2 - 10 * S
    r = min(x1 - x0, y1 - y0) * 0.18
    # 空気の流れ(右→左、ボールが右へ進む)
    for i, yy in enumerate((-2.0, -1.4, -0.8, 0.8, 1.4, 2.0)):
        y = cy + yy * r * 0.9
        off = ((t * 220 + i * 90) % 240) * S
        xs = x1 - 80 * S - off
        d.line([(xs, y), (xs - 90 * S, y)], fill=(130, 190, 235), width=max(2, int(5 * S)))
    ball_at(d, cx, cy, r, t * 5, True, w=4)
    # 回転の矢印(上側が進む向き)
    rr = r * 1.3
    d.arc([cx - rr, cy - rr, cx + rr, cy + rr], 215, 325, fill=O.YEL, width=max(4, int(8 * S)))
    th = math.radians(325)
    ex, ey = cx + rr * math.cos(th), cy + rr * math.sin(th)
    d.polygon([(ex, ey), (ex - 30 * S, ey - 4 * S), (ex - 8 * S, ey + 28 * S)], fill=O.YEL)
    arrow(d, cx + r * 2.3, cy - r * 0.2, cx + r * 3.4, cy - r * 0.2, 12 * S, O.WHITE)
    cap(d, (cx + r * 2.85, cy - r * 0.2 - 40 * S), "進む向き", 28, O.WHITE)
    arrow(d, cx, cy + r * 1.45, cx, cy + r * 2.6, 16 * S, O.RED)
    label(d, (cx + 40 * S, cy + r * 2.1), "空気に 下へ押される", 38, O.RED, "lm")
    label(d, (cx, cy - r * 1.9), "上側が 進む向きへ回る", 38, O.YEL)


def sc_rub(img, box, t, k, P):
    """回転は、ラケットが球の表面をこすってかける。stage 0: 図 / 1: こする速さ秒速29m / 2: 吸い付きが悪いともっと速く。"""
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    st = P.get("stage", 0)
    cx, cy = (x0 + x1) / 2 + 40 * S, (y0 + y1) / 2 + 20 * S
    r = min(x1 - x0, y1 - y0) * (0.2 if LAND else 0.15)
    ball_at(d, cx, cy, r, 0.4, True, w=4)
    # ラケットの面(球の前側をこする)
    off = ((t * 0.7) % 1.0)
    fx = cx - r - 26 * S
    top, bot = cy - r * 2.0, cy + r * 2.0
    d.rounded_rectangle([fx - 26 * S, top, fx, bot], int(10 * S), fill=(60, 70, 95), outline=(190, 205, 230), width=int(4 * S))
    for yy in range(int(top) + 10, int(bot), int(max(14, 22 * S))):
        d.line([(fx - 26 * S, yy), (fx, yy)], fill=(120, 135, 165), width=1)
    ya = cy + r * 1.7 - r * 3.4 * (off if k < 1 else 0.5)
    arrow(d, fx - 64 * S, cy + r * 1.7, fx - 64 * S, cy - r * 1.7, 14 * S, O.YEL)
    label(d, (fx - 40 * S, top - 44 * S), "ラケットの面", 34, O.WHITE)
    if st >= 1:
        if LAND:
            label(d, (cx + r * 1.9, cy - r * 0.9), "こする速さ 秒速29m", 40, O.YEL, "lm")
            label(d, (cx + r * 1.9, cy - r * 0.9 + 70 * S), "時速約105km", 40, O.YEL, "lm")
        else:
            label(d, (cx, cy + r * 2.3), "こする速さ 秒速29m", 40, O.YEL)
            label(d, (cx, cy + r * 2.3 + 70 * S), "時速約105km", 40, O.YEL)
    if st == 2:
        label(d, (cx + r * 1.9, cy + r * 0.7) if LAND else (cx, cy + r * 2.3 + 140 * S), "吸い付きが悪いと もっと速く", 36, O.RED, "lm" if LAND else "mm")
        arrow(d, fx - 150 * S, cy + r * 1.7, fx - 150 * S, cy - r * 2.2, 14 * S, O.RED)
    if LAND:
        label(d, (cx + r * 1.9, cy + r * 1.9), "回転は ラケットが球をこすってかける", 34, O.WHITE, "lm")


def sc_airdrag(img, box, t, k, P):
    """空気は、速いボールほどブレーキをかける。"""
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    r = min(x1 - x0, y1 - y0) * 0.13
    ball_at(d, cx, cy, r, t * 3, True, w=4)
    arrow(d, cx + r * 1.3, cy, cx + r * 3.4, cy, 14 * S, O.WHITE)
    cap(d, (cx + r * 2.35, cy - 46 * S), "進む向き", 28, O.WHITE)
    for i, yy in enumerate((-1.6, -0.9, 0.9, 1.6)):
        y = cy + yy * r
        off = ((t * 260 + i * 70) % 300) * S
        xs = cx + r * 5.5 - off
        arrow(d, xs, y, xs - 120 * S, y, 7 * S, (130, 190, 235)) if xs - 120 * S > cx + r * 0.2 or False else d.line([(xs, y), (xs - 120 * S, y)], fill=(130, 190, 235), width=max(2, int(5 * S)))
    arrow(d, cx - r * 1.3, cy, cx - r * 3.4, cy, 14 * S, O.RED)
    label(d, (cx - r * 2.35, cy - 56 * S), "空気のブレーキ", 38, O.RED)
    head(d, box, "速いボールほど 空気に強く押し返される", O.WHITE, 36)


# ---- ボールとネット -------------------------------------------------------------------------

def sc_ballsize(img, box, t, k, P):
    """ボールの大きさ比べ(直径6.7cm、重さ約57g、卵1個ほど)。"""
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2 + 20 * S
    ppc = min((x1 - x0) / 20.0, (y1 - y0) / 11.0)
    r = 6.7 / 2 * ppc
    bx = cx - (4.0 * ppc if LAND else 3.4 * ppc)
    ex = cx + (4.2 * ppc if LAND else 3.6 * ppc)
    ball_at(d, bx, cy, r, 0.5, True, w=4)
    d.ellipse([ex - 2.7 * ppc, cy - 3.0 * ppc, ex + 2.7 * ppc, cy + 3.0 * ppc], fill=(238, 222, 190), outline=(250, 240, 220), width=int(4 * S))
    hbracket(d, bx - r, bx + r, cy + r + 50 * S, "直径 6.7cm", O.YEL, 38, up=False)
    label(d, (bx, cy - r - 60 * S), "テニスボール 約57g", 38, O.WHITE)
    label(d, (ex, cy - 3.0 * ppc - 60 * S), "卵1個ほど", 38, O.WHITE)


def sc_netheight(img, box, t, k, P):
    """ネットの真ん中の高さ 0.914m(大人の腰の少し下)。"""
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    gy = y1 - 70 * S
    ppm = (gy - (y0 + 120 * S)) / 1.8
    d.rectangle([x0, gy, x1, y1], fill=(40, 90, 70))
    rx = x0 + (x1 - x0) * 0.58
    # 人(大人 約1.7m)
    pxm = x0 + (x1 - x0) * 0.3
    hp = 1.7 * ppm
    col = (176, 130, 110)
    u = hp / 8.0
    d.ellipse([pxm - u * 0.42, gy - hp, pxm + u * 0.42, gy - hp + u], fill=col)
    d.rounded_rectangle([pxm - u * 0.95, gy - hp + u * 1.05, pxm + u * 0.95, gy - u * 3.9], radius=int(u * 0.35), fill=col)
    d.line([(pxm - u * 0.45, gy - u * 4.0), (pxm - u * 0.55, gy)], fill=col, width=max(2, int(u * 0.62)))
    d.line([(pxm + u * 0.45, gy - u * 4.0), (pxm + u * 0.55, gy)], fill=col, width=max(2, int(u * 0.62)))
    # ネット
    nx0, nx1 = x0 + (x1 - x0) * 0.46, x0 + (x1 - x0) * 0.78
    nt = gy - 0.914 * ppm
    d.rectangle([nx0, nt, nx1, gy], fill=(52, 70, 108))
    for xx in range(int(nx0), int(nx1), int(max(14, 26 * S))):
        d.line([(xx, nt), (xx, gy)], fill=(80, 100, 140), width=1)
    for yy in range(int(nt), int(gy), int(max(14, 26 * S))):
        d.line([(nx0, yy), (nx1, yy)], fill=(80, 100, 140), width=1)
    d.rectangle([nx0, nt - 5 * S, nx1, nt + 5 * S], fill=O.WHITE)
    # 目盛り
    a = _ease(k * 1.5)
    rx0 = x0 + (x1 - x0) * 0.88
    d.line([(rx0, gy), (rx0, gy - 1.0 * ppm)], fill=O.WHITE, width=max(2, int(4 * S)))
    for m in (0.0, 0.5, 1.0):
        d.line([(rx0 - 12 * S, gy - m * ppm), (rx0 + 12 * S, gy - m * ppm)], fill=O.WHITE, width=max(2, int(3 * S)))
        text(d, (rx0 + 22 * S, gy - m * ppm), f"{m:.1f}m" if m else "0", 26, O.DIM, "lm", 3)
    d.line([(nx1, nt), (rx0 - 14 * S, nt)], fill=O.YEL, width=max(2, int(3 * S)))
    label(d, ((nx0 + nx1) / 2, nt - 56 * S), "ネットの真ん中 0.914m", 38, O.YEL)
    cap(d, (pxm, gy - hp - 36 * S), "大人（腰の少し下）", 28, O.DIM)


def sc_netsec(img, box, t, k, P):
    """ネットの断面図。stage 0: 上端とボール / 1: 針金と白い帯 / 2: 寸法 / 3: ボールにふれるのは帯。"""
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    st = P.get("stage", 0)
    ppc = (y1 - y0) * (0.050 if LAND else 0.042)
    cx = (x0 + x1) / 2 - ((x1 - x0) * 0.04 if LAND else 0)
    ytop = y0 + (y1 - y0) * 0.52
    Dpx = 6.0 * ppc
    R = 6.7 / 2 * ppc
    # ネット(下へ続く網)
    d.rectangle([cx - 5 * S, ytop + Dpx, cx + 5 * S, y1 - 30 * S], fill=(100, 115, 150))
    # 白い帯(逆U)
    band_w = 56 * S
    d.rounded_rectangle([cx - band_w / 2, ytop - 6 * S, cx + band_w / 2, ytop + Dpx], int(20 * S), fill=O.WHITE)
    d.rectangle([cx - band_w / 2 + 16 * S, ytop + 34 * S, cx + band_w / 2 - 16 * S, ytop + Dpx + 2], fill=BG1)
    d.rectangle([cx - 5 * S, ytop + 34 * S, cx + 5 * S, ytop + Dpx], fill=(100, 115, 150))
    # 針金
    wr = max(6 * S, 0.8 / 2 * ppc)
    wy = ytop + 12 * S + wr * 0.6
    d.ellipse([cx - wr, wy - wr, cx + wr, wy + wr], fill=(150, 155, 168), outline=(90, 94, 110), width=max(2, int(3 * S)))
    # ボール
    touch = st == 3
    by = ytop - 6 * S - R + (3 * S if touch else 0)
    ball_at(d, cx, by, R, 0.6, True, w=4)
    xl, xr = cx - band_w / 2 - 40 * S, cx + band_w / 2 + 40 * S
    if st == 0:
        label(d, (cx - R - 240 * S, ytop - R - 10 * S), "ボール", 36, O.WHITE)
        label(d, (cx + R + 270 * S, ytop + 10 * S), "ネットの上端", 38, O.YEL)
    if st >= 1:
        label(d, (xl - 180 * S, ytop + 60 * S + (90 * S if st == 2 else 0)), "白い帯", 40, O.WHITE)
        d.line([(xl - 80 * S, ytop + 60 * S + (90 * S if st == 2 else 0)), (cx - band_w / 2 - 4 * S, ytop + 60 * S + (90 * S if st == 2 else 0))], fill=O.WHITE, width=max(2, int(3 * S)))
        label(d, (xr + 200 * S, wy - 70 * S), "針金", 40, O.YEL)
        d.line([(xr + 100 * S, wy - 70 * S), (cx + wr + 4 * S, wy)], fill=O.YEL, width=max(2, int(3 * S)))
    if st == 2:
        vbracket(d, xl - 30 * S, ytop - 6 * S, ytop + Dpx, O.WHITE)
        label(d, (xl - 50 * S, ytop + Dpx + 56 * S - 26 * S), "帯の深さ 5〜6.35cm", 34, O.WHITE, "ra") if False else label(d, (xl - 250 * S, ytop + Dpx / 2 + 110 * S), "帯の深さ 5〜6.35cm", 34, O.WHITE)
        label(d, (xr + 330 * S, wy + 20 * S), "太さ 最大8mm", 36, O.YEL)
    if st == 3:
        label(d, (cx + R + 280 * S, ytop - 120 * S), "ボールにふれるのは 帯", 40, O.GREEN)
        label(d, (xr + 250 * S, wy + 50 * S), "丸い針金は 刃ではない", 36, O.YEL)
        d.line([(xr + 60 * S, wy + 50 * S), (cx + wr + 4 * S, wy + 4 * S)], fill=O.YEL, width=max(2, int(3 * S)))
    head(d, box, "ネットの上端の断面" if st != 3 else "ルールどおりなら", O.WHITE, 40)


# ---- 割れた殻・ラケット面 -------------------------------------------------------------------

def half_disc(d, cx, cy, r, facing, col=BALL, outline=(250, 250, 235)):
    """半円(半球の断面)。facing = 丸い側が向く方角(度、右=0)。"""
    ang0 = facing - 90
    d.pieslice([cx - r, cy - r, cx + r, cy + r], ang0, ang0 + 180, fill=col, outline=outline, width=max(2, int(4 * S)))


def sc_halves(img, box, t, k, P):
    """ボールが真っ二つ。stage 0: 割れた2つが離れる(幸村が両方返す) / 1: 半球の殻(背とくぼみ・空気を受ける)。"""
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    st = P.get("stage", 0)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    r = min(x1 - x0, y1 - y0) * 0.17
    if st == 0:
        u = _ease(k * 1.3)
        gap = (14 + 90 * u) * S
        # 上半分・下半分
        d.pieslice([cx - r, cy - gap - r, cx + r, cy - gap + r], 180, 360, fill=BALL, outline=(250, 250, 235), width=int(4 * S))
        d.pieslice([cx - r, cy + gap - r, cx + r, cy + gap + r], 0, 180, fill=BALL, outline=(250, 250, 235), width=int(4 * S))
        arrow(d, cx + r * 1.5, cy - gap, cx + r * 1.5, cy - gap - 70 * S, 10 * S, O.YEL) if u > 0.6 else None
        arrow(d, cx + r * 1.5, cy + gap, cx + r * 1.5, cy + gap + 70 * S, 10 * S, O.YEL) if u > 0.6 else None
        label(d, (cx, y0 + 60 * S), "ボールを ネットの上端で 真っ二つ", 42, O.YEL)
        if u > 0.8:
            label(d, (cx, y1 - 70 * S), "割れた2つを 両方返す？", 44, O.WHITE)


def sc_shells(img, box, t, k, P):
    """半球の殻の図。stage 0: 背を前/くぼみを前の2つ / 1: 向きが飛ぶあいだに変わる。"""
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    st = P.get("stage", 0)
    w, h = x1 - x0, y1 - y0
    r = min(w * 0.14, h * 0.17)
    cy = y0 + h * (0.45 if LAND else 0.42)
    xa = x0 + w * (0.27 if LAND else 0.28)
    xb = x0 + w * (0.73 if LAND else 0.72)
    if st == 0:
        # 背を前(丸い側が右=進む向き)
        half_disc(d, xa, cy, r, 0)
        arrow(d, xa - r - 100 * S, cy, xa - r - 20 * S, cy, 12 * S, O.WHITE)
        for yy in (-0.9, 0, 0.9):
            d.line([(xa + r + 30 * S, cy + yy * r), (xa + r + 140 * S, cy + yy * r)], fill=(130, 190, 235), width=max(2, int(5 * S)))
        label(d, (xa, cy - r - 70 * S), "丸い背を前", 38, O.GREEN)
        # くぼみを前(平らな側が右=進む向き)
        half_disc(d, xb, cy, r, 180)
        d.arc([xb - r * 0.1, cy - r, xb + r * 0.1, cy + r], 270, 90, fill=O.NAVY, width=2)
        arrow(d, xb - r - 100 * S, cy, xb - r - 20 * S, cy, 12 * S, O.WHITE)
        for yy in (-0.7, 0, 0.7):
            arrow(d, xb + r + 150 * S, cy + yy * r, xb + 8 * S, cy + yy * r, 6 * S, (130, 190, 235))
        label(d, (xb, cy - r - 70 * S), "くぼみを前", 38, O.RED)
        label(d, (xa, cy + r + 70 * S), "0.60秒で着く", 36, O.GREEN)
        label(d, (xb, cy + r + 70 * S), "1.0秒で着く", 36, O.RED)
        cap(d, (xb, cy + r + 150 * S), "パラシュートのように空気を受ける", 28, O.DIM)
        label(d, ((x0 + x1) / 2, y0 + 60 * S), "割れた殻は 半球が2つ（1つ約28g）", 40, O.YEL)
    else:
        xc = (x0 + x1) / 2
        ang = 180 * math.sin(t * 1.4)
        half_disc(d, xc, cy, r * 1.2, ang)
        label(d, (xc, cy + r * 1.2 + 90 * S), "殻の向きは 飛ぶあいだに変わる", 40, O.YEL)
        cap(d, (xc, cy + r * 1.2 + 170 * S), "曲がり方の数字は 出せない", 30, O.DIM)


def sc_spread(img, box, t, k, P):
    """2つの殻が横へ離れる。stage 0: 秒速0.5m(歩く速さの半分以下) / 1: 着くころ0.6〜1.0m開く(離れ幅)。"""
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    st = P.get("stage", 0)
    w, h = x1 - x0, y1 - y0
    cx, cy = (x0 + x1) / 2, y0 + h * 0.5
    r = 70 * S
    u = _ease(k * 1.4)
    if st == 0:
        gap = (80 + 60 * u) * S
        half_disc(d, cx - gap, cy, r, 180)
        half_disc(d, cx + gap, cy, r, 0)
        arrow(d, cx - gap - r - 10 * S, cy, cx - gap - r - 200 * S, cy, 14 * S, O.YEL)
        arrow(d, cx + gap + r + 10 * S, cy, cx + gap + r + 200 * S, cy, 14 * S, O.YEL)
        label(d, (cx - gap - r - 200 * S, cy - 70 * S), "秒速0.5m", 40, O.YEL)
        label(d, (cx + gap + r + 200 * S, cy - 70 * S), "秒速0.5m", 40, O.YEL)
        label(d, (cx, cy + 130 * S), "時速1.8km　歩く速さの半分以下", 40, O.WHITE)
        label(d, (cx, y0 + 60 * S), "2つが横へ離れる速さ（仮に置く）", 38, O.WHITE)
    else:
        gm = (0.6 + 0.4 * (0.5 + 0.5 * math.sin(t * 1.3))) if k >= 1.0 else 0.6 + 0.4 * u
        ppm = (w - 300 * S) / 1.2
        gap = gm * ppm / 2
        half_disc(d, cx - gap, cy, r, 180)
        half_disc(d, cx + gap, cy, r, 0)
        hbracket(d, cx - gap, cx + gap, cy + 100 * S, f"離れ幅 {gm:.1f}m", O.YEL, 40, up=False)
        label(d, (cx, y0 + 60 * S), "着くころ 2つの殻の間は 0.6〜1.0m", 40, O.WHITE)
        cap(d, (cx, cy - 110 * S), "この間の距離が 離れ幅", 30, O.DIM)


def sc_face(img, box, t, k, P):
    """ラケットの面。stage 0: 面 / 1: 横の幅29.2cm / 2: 22cm以内なら両方当たる / 3: 離れ幅0.6〜1.0mだと入らない / 4: 離れる速さを小さくすると入る。"""
    mainb, mb = split(box, P)
    x0, y0, x1, y1 = mainb
    grad(img, box=mainb)
    d = ImageDraw.Draw(img)
    st = P.get("stage", 0)
    w, h = x1 - x0, y1 - y0
    cx, cy = (x0 + x1) / 2, y0 + h * (0.52 if LAND else 0.5)
    if st <= 2:
        cy = y0 + h * 0.45
        sc = min(h * 0.60 / 0.394, w * 0.5 / 0.292)
    else:
        sc = (w - 140 * S) / 1.15
    fw, fh = 0.292 * sc, 0.394 * sc
    edge = (190, 205, 230)
    # 面(網の部分)
    d.ellipse([cx - fw / 2, cy - fh / 2, cx + fw / 2, cy + fh / 2], fill=(34, 52, 84), outline=edge, width=max(3, int(6 * S)))
    for i in range(-6, 7):
        xx = cx + i * fw / 14
        hh = fh / 2 * math.sqrt(max(0.0, 1 - (i * 2 / 14) ** 2))
        d.line([(xx, cy - hh), (xx, cy + hh)], fill=(70, 95, 135), width=1)
    for i in range(-8, 9):
        yy = cy + i * fh / 18
        ww = fw / 2 * math.sqrt(max(0.0, 1 - (i * 2 / 18) ** 2))
        d.line([(cx - ww, yy), (cx + ww, yy)], fill=(70, 95, 135), width=1)
    dball = 0.067 * sc
    if st == 0:
        label(d, (cx, cy - fh / 2 - 60 * S), "面　ボールを打つ網の部分", 38, O.WHITE)
    if st == 1:
        hbracket(d, cx - fw / 2, cx + fw / 2, cy + fh / 2 + 60 * S, "横の幅 最大29.2cm", O.YEL, 38, up=False)
        cap(d, (cx, cy - fh / 2 - 40 * S), "向きで変わるので 横に分かれる場合で見積もる", 28, O.DIM)
    if st == 2:
        z = 0.22 * sc
        d.rectangle([cx - z / 2, cy - 30 * S, cx + z / 2, cy + 30 * S], fill=(70, 200, 120))
        ball_at(d, cx - z / 2, cy, dball / 2, 0.3, True)
        ball_at(d, cx + z / 2, cy, dball / 2, 0.8, True)
        hbracket(d, cx - z / 2, cx + z / 2, cy + fh / 2 + 60 * S, "2つの中心が 約22cm以内", O.GREEN, 38, up=False)
        cap(d, (cx, cy - fh / 2 - 40 * S), "面の幅29.2cm − ボールの直径6.7cm", 28, O.DIM)
    if st >= 3:
        u = _ease(k * 1.4) if st == 3 else 1.0
        z = 0.22 * sc
        if st == 3:
            gm = 0.6 + 0.4 * u
            ca, cb = cx - gm * sc / 2, cx + gm * sc / 2
            ball_at(d, ca, cy, dball / 2, 0.3, True)
            ball_at(d, cb, cy, dball / 2, 0.8, True)
            d.rectangle([cx - z / 2, cy - 18 * S, cx + z / 2, cy + 18 * S], fill=(70, 200, 120))
            hbracket(d, ca, cb, cy + fh / 2 + 70 * S, f"離れ幅 {gm:.1f}m", O.YEL, 38, up=True)
            if u > 0.95:
                label(d, (cx, cy + fh / 2 + 150 * S) if LAND else (cx, cy - fh / 2 - 56 * S), "22cmを引くと 外れ幅は 38〜79cm", 38, O.RED)
        else:
            gm = 0.16
            ca, cb = cx - gm * sc / 2, cx + gm * sc / 2
            d.rectangle([cx - z / 2, cy - 18 * S, cx + z / 2, cy + 18 * S], fill=(70, 200, 120))
            ball_at(d, ca, cy, dball / 2, 0.3, True)
            ball_at(d, cb, cy, dball / 2, 0.8, True)
            sc2 = (w - 140 * S) / 1.15
            label(d, (cx, cy - fh / 2 - 56 * S), "22cm以内なら 両方当たる", 40, O.GREEN)
    if mb:
        meter(img, mb, P["meter"], k, t)


# ---- エネルギー -----------------------------------------------------------------------------

def sc_apple(img, box, t, k, P):
    """1ジュール = りんご1個を1m持ち上げる力。stage 0: 1J / 1: 3,000回転は2.1J(約2m)。"""
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    st = P.get("stage", 0)
    gy = y1 - 80 * S
    ppm = (gy - (y0 + 150 * S)) / 2.5
    ax = x0 + (x1 - x0) * (0.3 if LAND else 0.3)
    d.rectangle([x0, gy, x1, y1], fill=(40, 90, 70))
    d.line([(ax + 130 * S, gy), (ax + 130 * S, gy - 2.5 * ppm)], fill=O.WHITE, width=max(2, int(4 * S)))
    for m in (0, 1, 2):
        d.line([(ax + 118 * S, gy - m * ppm), (ax + 142 * S, gy - m * ppm)], fill=O.WHITE, width=max(2, int(3 * S)))
        text(d, (ax + 156 * S, gy - m * ppm), f"{m}m" if m else "0", 28, O.DIM, "lm", 3)
    u = _ease(k * 1.4)
    hgt = (1.0 if st == 0 else 2.1) * u
    # りんご
    r = 40 * S
    ay = gy - r - hgt * ppm
    d.ellipse([ax - r, ay - r, ax + r, ay + r], fill=(210, 50, 50), outline=(250, 120, 110), width=int(3 * S))
    d.line([(ax, ay - r), (ax + 6 * S, ay - r - 22 * S)], fill=(110, 80, 50), width=int(5 * S))
    d.ellipse([ax + 6 * S, ay - r - 24 * S, ax + 36 * S, ay - r - 6 * S], fill=(90, 170, 90))
    arrow(d, ax - 100 * S, gy - 6 * S, ax - 100 * S, gy - hgt * ppm - 10 * S, 12 * S, O.YEL) if hgt > 0.05 else None
    xt = ax + 260 * S
    if st == 0:
        label(d, (xt, gy - 0.5 * ppm - 60 * S), "りんご1個を 1m持ち上げる力", 42, O.YEL, "lm")
        text(d, (xt, gy - 0.5 * ppm + 20 * S), "＝ 1ジュール", 80, O.WHITE, "lm", 6)
    else:
        label(d, (xt, gy - 1.2 * ppm - 40 * S), "3,000回転は 2.1ジュール", 42, O.YEL, "lm")
        label(d, (xt, gy - 1.2 * ppm + 30 * S), "りんごを 約2m持ち上げる分", 40, O.WHITE, "lm")
        label(d, (xt, gy - 1.2 * ppm + 100 * S), "飛ぶボールのエネルギーの 約8%", 38, O.DIM, "lm")


def sc_ballsec(img, box, t, k, P):
    """テニスボールの断面(中が空洞のゴムの殻)。stage 0: 裂く目安3〜7ジュール / 1: 確かさは低い。"""
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    st = P.get("stage", 0)
    cx, cy = x0 + (x1 - x0) * (0.34 if LAND else 0.5), y0 + (y1 - y0) * (0.5 if LAND else 0.4)
    r = min(x1 - x0, y1 - y0) * (0.3 if LAND else 0.22)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=BALL, outline=(250, 250, 235), width=int(4 * S))
    ri = r * 0.88
    d.ellipse([cx - ri, cy - ri, cx + ri, cy + ri], fill=(20, 32, 60), outline=(150, 160, 120), width=max(2, int(3 * S)))
    cap(d, (cx, cy), "中は空洞", 40, O.DIM)
    label(d, (cx + r + 40 * S, cy - r * 0.55) if LAND else (cx, cy - r - 60 * S), "ゴムの殻", 40, BALL, "lm" if LAND else "mm")
    xs = x0 + (x1 - x0) * 0.68 if LAND else (x0 + x1) / 2
    ys = cy - 60 * S if LAND else y0 + (y1 - y0) * 0.72
    label(d, (xs, ys), "裂く目安　3〜7ジュール", 46, O.YEL)
    if st >= 1:
        label(d, (xs, ys + 90 * S), "確かさは低い", 44, O.RED)
        cap(d, (xs, ys + 160 * S), "おおよその大きさを見るための数字", 28, O.DIM)


def sc_conds(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    items = P["items"]
    n = len(items)
    cols = [O.YEL, O.BLUE, O.GREEN]
    if LAND:
        gap = 30 * S
        cw = ((x1 - x0) - 100 * S - gap * (n - 1)) / n
        for i, (num, a, b) in enumerate(items):
            u = _ease(k * 3.2 - i * 0.9)
            if u <= 0:
                continue
            cxl = x0 + 50 * S + i * (cw + gap)
            cy0 = y0 + 160 * S + (1 - u) * 40 * S
            col = cols[i % 3]
            d.rounded_rectangle([cxl, cy0, cxl + cw, cy0 + 440 * S], int(24 * S), fill=(24, 40, 78), outline=col, width=int(5 * S))
            text(d, (cxl + cw / 2, cy0 + 90 * S), num, 110 if len(num) < 4 else 80, col, "mm", 6)
            text(d, (cxl + cw / 2, cy0 + 230 * S), a, 44, O.WHITE, "mm", 5)
            text(d, (cxl + cw / 2, cy0 + 330 * S), b, 32, O.DIM, "mm", 4)
    else:
        ch = ((y1 - y0) - 200 * S - (n - 1) * 30 * S) / n
        for i, (num, a, b) in enumerate(items):
            u = _ease(k * 3.2 - i * 0.9)
            if u <= 0:
                continue
            cy0 = y0 + 120 * S + i * (ch + 30 * S) + (1 - u) * 40 * S
            col = cols[i % 3]
            d.rounded_rectangle([x0 + 50 * S, cy0, x1 - 50 * S, cy0 + ch], int(24 * S), fill=(24, 40, 78), outline=col, width=int(5 * S))
            text(d, (x0 + 150 * S, cy0 + ch / 2), num, 90, col, "mm", 6)
            text(d, (x0 + 250 * S, cy0 + ch / 2 - 28 * S), a, 44, O.WHITE, "lm", 5)
            text(d, (x0 + 250 * S, cy0 + ch / 2 + 40 * S), b, 30, O.DIM, "lm", 4)
    head(d, box, P.get("head", "実験7の条件"), O.WHITE, 44)


def sc_bars(img, box, t, k, P):
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    bars(d, box, P["rows"], P["vmax"], k, P.get("grow_from", 0), P.get("marks", ()), P.get("names_above"))
    if P.get("head"):
        head(d, box, P["head"], P.get("hcol", O.YEL))
    if P.get("foot"):
        x0, y0, x1, y1 = box
        text(d, ((x0 + x1) / 2, y1 - 14 * S), P["foot"], 28, O.DIM, "md", 3)


KINDS = dict(formula=sc_formula, bars=sc_bars, court=sc_court, meterbig=sc_meterbig, window=sc_window, angline=sc_angline,
             angle=sc_angle, deg1=sc_deg1, uncert=sc_uncert, speed=sc_speed, spin=sc_spin, magnus=sc_magnus, rub=sc_rub,
             halves=sc_halves, shells=sc_shells, spread=sc_spread, face=sc_face, apple=sc_apple, ballsec=sc_ballsec,
             netsec=sc_netsec, ballsize=sc_ballsize, netheight=sc_netheight, airdrag=sc_airdrag, conds=sc_conds)


def region(P):
    return (0, 100, W, 880) if LAND else (0, 240, W, 1370)


def main_box(P):
    return split(region(P), P)[0]


def paint(sc, t, k):
    img = Image.new("RGBA", (W, H), BG0 + (255,))
    KINDS[sc["kind"]](img, region(sc), t, k, sc)
    return img
