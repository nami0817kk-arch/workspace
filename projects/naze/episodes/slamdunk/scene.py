"""スラムダンク「山王戦の最後、パスを受けて打てるか」(計算の回)の画面。行の scene=dict(kind=…) を描く(無い行は前の行を引き継ぐ)。
場面が変わると 0.5 秒で溶け合わせる。作品の絵・キャラの絵は使わない。コート・ボール・選手は図形の簡略図。図は全部コードで描く。
軸は「余り秒メーター」(時計の残り − 必要な時間。プラス＝計算では間に合う)。行の scene に meter=dict(n=実験番号, v=余り秒, pv=前の値) を付けると右(縦なら下)に出る。
kind: formula / tl(時間の帯) / court(コートを上から) / span / meterbig / jump / wall / sur(まとめ) / bars
"""
from __future__ import annotations

import math

from PIL import Image, ImageDraw

from naze import mapscene, overlay as O
from naze.config import H, W

LAND = W > H
S = min(W, H) / 1080
COLS = dict(dim=O.DIM, white=O.WHITE, yel=O.YEL, red=O.RED, green=O.GREEN, blue=O.BLUE, orange=(250, 165, 80))
BG0, BG1 = (10, 18, 40), (16, 30, 62)
C_RE, C_FL, C_CA = (90, 170, 235), (240, 200, 70), (250, 165, 80)     # 反応(青)・ボールが飛ぶ(黄)・受けて打つ(橙)
LANE = dict(RE=C_RE, FL=C_FL, CA=C_CA)
GOOD, BAD = (70, 200, 120), (240, 90, 80)
BALLC = (240, 140, 40)
TAGGED = [False]
# 実験ごとの余り秒(メーターの跡の点)
VAL = {1: -0.32, 2: -0.10, 3: 0.10, 4: -0.40, 5: -0.10, 6: 0.07, 7: -0.13}


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


def cap(d, xy, s, size=30, col=O.DIM, anchor="mm"):
    """箱なしの小さな注記(重なりの点検には載せない)。"""
    text(d, xy, s, size, col, anchor, 3)


def mix(c, bg, a):
    return tuple(int(c[i] * a + bg[i] * (1 - a)) for i in range(3))


def arrow(d, x0, y0, x1, y1, w, col):
    ang = math.atan2(y1 - y0, x1 - x0)
    L = math.hypot(x1 - x0, y1 - y0)
    hl = min(L * 0.5, w * 2.2)
    bx, by = x1 - math.cos(ang) * hl, y1 - math.sin(ang) * hl
    d.line([(x0, y0), (bx, by)], fill=col, width=int(w))
    nx, ny = -math.sin(ang), math.cos(ang)
    d.polygon([(x1, y1), (bx + nx * w * 1.1, by + ny * w * 1.1), (bx - nx * w * 1.1, by - ny * w * 1.1)], fill=col)


def hbracket(d, x0, x1, y, s, col=O.YEL, size=34, up=True):
    d.line([(x0, y), (x1, y)], fill=col, width=max(2, int(4 * S)))
    for x in (x0, x1):
        d.line([(x, y - 14 * S), (x, y + 14 * S)], fill=col, width=max(2, int(4 * S)))
    if s:
        label(d, ((x0 + x1) / 2, y + (-48 if up else 48) * S), s, size, col)


def bar_text(d, x0, x1, yc, s, fs, inside=(20, 28, 50)):
    """帯の中に収まれば帯の中に(紺の字)、収まらなければ右(右端を越えるなら左)に白い字で書く。"""
    f = O.font(int(fs * S))
    w = f.getlength(s)
    if x1 - x0 > w + 24 * S:
        d.text(((x0 + x1) / 2, yc), s, font=f, fill=inside, anchor="mm")
    elif x1 + 16 * S + w < W - 20 * S:
        text(d, (x1 + 16 * S, yc), s, fs, O.WHITE, "lm", 4)
    else:
        text(d, (x0 - 16 * S, yc), s, fs, O.WHITE, "rm", 4)


def dash_v(d, x, y0, y1, col, w=4, seg=14, gap=10):
    y = y0
    while y < y1:
        d.line([(x, y), (x, min(y + seg * S, y1))], fill=col, width=max(2, int(w * S)))
        y += (seg + gap) * S


def fsign(v):
    return f"{v:+g}".replace("-", "−")


# ---- 札(文字だけの場面)・実験の札・判定の札 ---------------------------------------------------

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
        while f.getlength(s) > (x1 - x0) - (80 if LAND else 120) * S and sz > 30:
            sz -= 4
            f = O.font(int(sz * S))
        text(d, (cx, y0 + gap * (i + 1) + 6 * S * math.sin(t * 1.3 + i)), s, sz, c, "mm", 6)


def _tag(img, box, n):
    d = ImageDraw.Draw(img)
    x0, y0 = box[0], box[1]
    s = f"実験{n}" if isinstance(n, int) else str(n)
    f = O.font(int(44 * S))
    w = f.getlength(s)
    bx = (x0 + 24 * S, y0 + 14 * S, x0 + 24 * S + w + 40 * S, y0 + 14 * S + 70 * S)
    d.rounded_rectangle(bx, int(14 * S), fill=O.YEL, outline=O.NAVY, width=int(3 * S))
    d.text(((bx[0] + bx[2]) / 2, (bx[1] + bx[3]) / 2), s, font=f, fill=O.NAVY, anchor="mm")
    O.BOXES.append(("label", bx, s, 1.0))


def _stamp(img, box, kind, u, v=0.0):
    """判定の札。fail=「間に合わない」(赤)、ok=「計算では間に合う」(緑)。メーターの反対側に、大きく出てすっと落ち着く。"""
    s, col = ("間に合わない", O.RED) if kind == "fail" else ("計算では\n間に合う", O.GREEN)
    rows = s.split("\n")
    sz = int((52 if LAND else 80) * S)
    f = O.font(sz)
    pad = int(30 * S)
    tw = int(max(f.getlength(r) for r in rows))
    th = int(sz * 1.25 * len(rows))
    lay = Image.new("RGBA", (tw + pad * 2, th + pad * 2), (0, 0, 0, 0))
    ld = ImageDraw.Draw(lay)
    ld.rounded_rectangle([4, 4, lay.width - 5, lay.height - 5], int(24 * S), fill=(8, 16, 36, 240), outline=col, width=int(10 * S))
    for i, r in enumerate(rows):
        ld.text((lay.width / 2, pad + sz * 1.25 * (i + 0.5)), r, font=f, fill=col, anchor="mm")
    sc = 1.0 + 0.5 * (1 - _ease(u * 3))
    lay = lay.resize((int(lay.width * sc), int(lay.height * sc)), Image.LANCZOS).rotate(7, expand=True, resample=Image.BICUBIC)
    x0, y0, x1, y1 = box
    cx = x0 + (x1 - x0) * (0.56 if LAND else 0.64)
    cy = y0 + (y1 - y0) * (0.40 if v < 0 else 0.68)    # メーターの針と反対側(針が下なら上、上なら下)
    img.alpha_composite(lay, (int(cx - lay.width / 2), int(cy - lay.height / 2)))


# ---- 余り秒メーター ---------------------------------------------------------------------------

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
    """余り秒メーター(全編を貫く軸)。0 を中心にした縦の目盛り。上が「間に合う」(プラス)、下が「間に合わない」(マイナス)。"""
    x0, y0, x1, y1 = mb
    grad(img, box=mb)
    d = ImageDraw.Draw(img)
    n = spec.get("n", 0)
    stage = spec.get("stage", 1)
    hh = (140 if LAND else 112) * S
    ftr = 30 * S
    top_v, bot_v = 0.5, -0.5
    ppu = ((y1 - y0) - hh - ftr) / (top_v - bot_v)
    yv = lambda v: y0 + hh + (top_v - v) * ppu
    cx = x0 + (x1 - x0) * (0.22 if not full else 0.30)
    bw = (74 if full else 56) * S
    label(d, ((x0 + x1) / 2, y0 + 40 * S), "余り秒メーター", 38 if LAND else 34, O.WHITE)
    cap(d, ((x0 + x1) / 2, y0 + 92 * S), "余り秒 ＝ 時計の残り − 必要な時間", 28 if LAND else 26, O.DIM)
    if stage >= 1:
        d.rectangle([cx - bw / 2, yv(top_v), cx + bw / 2, yv(0)], fill=(52, 128, 88))
        d.rectangle([cx - bw / 2, yv(0), cx + bw / 2, yv(bot_v)], fill=(140, 62, 62))
    else:
        d.rectangle([cx - bw / 2, yv(top_v), cx + bw / 2, yv(bot_v)], fill=(60, 74, 104))
    for i in range(-5, 6):
        v = i / 10
        yy = yv(v)
        d.line([(cx - bw / 2 - 14 * S, yy), (cx - bw / 2, yy)], fill=O.WHITE, width=max(2, int(3 * S)))
        lab = "0" if i == 0 else fsign(v)
        text(d, (cx - bw / 2 - 20 * S, yy), lab, 26, O.WHITE if i == 0 else O.DIM, "rm", 3)
    d.line([(cx - bw / 2 - 22 * S, yv(0)), (cx + bw / 2 + 12 * S, yv(0))], fill=O.WHITE, width=max(3, int(5 * S)))
    xr = x1 - 50 * S
    if stage >= 1:
        text(d, (xr, yv(0.44)), "↑ 間に合う", 30, (140, 235, 175), "rm", 4)
        text(d, (xr, yv(-0.44)), "↓ 間に合わない", 30, (250, 150, 140), "rm", 4)
    # 前の実験の跡(バーの上の小さな丸と実験の番号)
    for m in range(1, n):
        yy = yv(VAL[m])
        d.ellipse([cx - 14 * S, yy - 14 * S, cx + 14 * S, yy + 14 * S], fill=(232, 236, 246), outline=O.NAVY, width=2)
        text(d, (cx, yy), str(m), 20, O.NAVY, "mm", 0)
    v = spec.get("v")
    if v is not None:
        pv = spec.get("pv", v)
        u = _ease(k * 2.0)
        vv = pv + (v - pv) * u
        ym = yv(vv)
        col = GOOD if v > 0 else BAD
        tri = [(cx + bw / 2 + 8 * S, ym), (cx + bw / 2 + 50 * S, ym - 22 * S), (cx + bw / 2 + 50 * S, ym + 22 * S)]
        d.polygon(tri, fill=col, outline=O.NAVY)
        label(d, (cx + bw / 2 + 62 * S, ym), fsign(v) + "秒", 46 if LAND else 44, O.GREEN if v > 0 else O.RED, "lm")


def sc_meterbig(img, box, t, k, P):
    """メーターだけを大きく出す。stage 0: 軸だけ / 1: 上が間に合う・下が間に合わない。"""
    x0, y0, x1, y1 = box
    grad(img, box=box)
    st = P.get("stage", 0)
    mb = (x0 + (x1 - x0) * 0.04, y0, x0 + (x1 - x0) * 0.52, y1) if LAND else (x0, y0 + (y1 - y0) * 0.30, x1, y1)
    meter(img, mb, dict(n=0, stage=st), k, t, full=True)
    d = ImageDraw.Draw(img)
    items = {0: [("ものさしは 1つ", O.YEL), ("余り秒", O.WHITE), ("＝ 時計の残り", O.WHITE), ("− 必要な時間", O.WHITE)],
             1: [("プラスなら", O.WHITE), ("間に合う", O.GREEN), ("マイナスなら", O.WHITE), ("間に合わない", O.RED)]}[st]
    sizes = {0: [70, 120, 56, 56], 1: [56, 100, 56, 100]}[st]
    if LAND:
        bx0, bx1 = x0 + (x1 - x0) * 0.56, x1 - 30 * S
        by = (y0 + y1) / 2 - 140 * S
        for i, (s, col) in enumerate(items):
            a = _ease(k * 4 - i * 0.7)
            if a <= 0:
                continue
            c = tuple(int(v * a + 20 * (1 - a)) for v in col)
            text(d, ((bx0 + bx1) / 2, by + i * 96 * S), s, sizes[i], c, "mm", 6)
    else:
        by = y0 + 30 * S
        for i, (s, col) in enumerate(items):
            a = _ease(k * 4 - i * 0.7)
            if a <= 0:
                continue
            c = tuple(int(v * a + 20 * (1 - a)) for v in col)
            text(d, ((x0 + x1) / 2, by + i * 62 * S), s, int(sizes[i] * 0.62), c, "mm", 6)


# ---- 時間の帯(必要な時間 と 時計の残り) -------------------------------------------------------------

def sc_tl(img, box, t, k, P):
    """上の帯が時計の残り、真ん中が反応・飛ぶ・受けて打つの帯、下が必要な時間。残りの線を越えた分が赤。"""
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = box
    xmax = P.get("xmax", 1.5)
    gx0, gx1 = x0 + 50 * S, x1 - 60 * S
    px = lambda v: gx0 + (gx1 - gx0) * v / xmax
    segs, stage = P["segs"], P.get("stage", 0)
    n = len(segs)
    need_st, br_st = P.get("need_st", n + 1), P.get("br_st", n + 2)
    remain, need = P["remain"], P["need"]
    top = y0 + 140 * S
    nrow = n + 2
    pitch = min(124 * S, (y1 - top - 120 * S) / nrow)
    bh = pitch * 0.56
    fs = 36 if LAND else 30
    yc = lambda i: top + pitch * (i + 0.5)
    gy1 = top + pitch * nrow
    anim = lambda st: _ease(k * 2.2) if stage == st else 1.0
    # 目盛り(上に)と薄い縦線
    for i in range(0, int(xmax / 0.5) + 1):
        v = i * 0.5
        d.line([(px(v), top - 6 * S), (px(v), gy1)], fill=(44, 62, 100), width=max(2, int(2 * S)))
        cap(d, (px(v), top - 30 * S), "0" if v == 0 else f"{v:g}秒", 26, O.DIM, "md")
    dash_v(d, px(remain), top - 8 * S, gy1, O.WHITE)      # 時計が終わる線(帯や字の下に敷く)
    # 時計の残り
    d.rectangle([px(0), yc(0) - bh / 2, px(remain), yc(0) + bh / 2], fill=(205, 210, 225))
    bar_text(d, px(0), px(remain), yc(0), f"時計の残り {remain:.1f}秒", fs)
    # 各帯
    focus = P.get("focus")
    for si, sg in enumerate(segs):
        if stage < sg["st"]:
            continue
        i = si + 1
        a = anim(sg["st"])
        col = LANE[sg["c"]]
        if focus is not None and si != focus:
            col = mix(col, BG1, 0.35)
        xa, xb = px(sg["s"]), px(sg["s"] + sg["d"] * a)
        if sg.get("ghost"):
            d.rectangle([xa, yc(i) - bh / 2, xb, yc(i) + bh / 2], fill=mix(col, BG1, 0.35), outline=BAD, width=max(3, int(4 * S)))
            if a > 0.8:
                bar_text(d, xa, xb, yc(i), sg["t"], fs)
        else:
            d.rectangle([xa, yc(i) - bh / 2, xb, yc(i) + bh / 2], fill=col)
            if a > 0.8:
                bar_text(d, xa, xb, yc(i), sg["t"], fs)
    # 必要な時間
    iN = n + 1
    if stage >= need_st:
        a = anim(need_st)
        e = need * a
        inn = min(e, remain)
        d.rectangle([px(0), yc(iN) - bh / 2, px(inn), yc(iN) + bh / 2], fill=GOOD)
        if e > remain:
            d.rectangle([px(remain), yc(iN) - bh / 2, px(e), yc(iN) + bh / 2], fill=BAD)
        if a > 0.8:
            bar_text(d, px(0), px(need), yc(iN), f"必要な時間 {need:.2f}".rstrip("0").rstrip(".") + "秒", fs)
    # 余りの括弧
    if stage >= br_st:
        lo, hi = min(need, remain), max(need, remain)
        ybr = yc(iN) + bh / 2 + 18 * S
        col = O.RED if need > remain else O.GREEN
        txt = P.get("br_txt") or (f"足りない {round(need - remain, 2):g}秒" if need > remain else f"余り {round(remain - need, 2):g}秒")
        hbracket(d, px(lo), px(hi), ybr, txt, col, 34 if LAND else 30, up=False)
    if P.get("note"):
        label(d, (x1 - 24 * S, y0 + 52 * S), P["note"], 34 if LAND else 28, O.YEL, "rm")
    fl = P.get("flag")
    if fl and stage >= fl["st"]:
        xf, lane = px(fl["x"]), fl["lane"]
        r = 30 * S
        d.ellipse([xf - r, yc(lane) - r, xf + r, yc(lane) + r], outline=O.RED, width=max(3, int(5 * S)))
        label(d, (x1 - 24 * S, y0 + 52 * S), fl["t"], 34 if LAND else 28, O.RED, "rm")


# ---- コートを上から見た図 -----------------------------------------------------------------------

def sc_court(img, box, t, k, P):
    """コートの一部を上から見た簡略図。桜木(赤)・流川(青)・山王の選手(灰)・ボールを、丸で描く。"""
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    d.rectangle(box, fill=(78, 60, 48))
    LINE = (236, 228, 208)
    u = min(112 * S, (y1 - y0 - 110 * S) / 5.2)
    cx = (x0 + x1) / 2
    by = y0 + 96 * S                               # ベースライン
    lane_len = min(5.8 * u, (y1 - by - 40 * S))
    lw = max(3, int(4 * S))
    d.line([(cx - 3.2 * u, by), (cx + 3.2 * u, by)], fill=LINE, width=lw)
    d.rectangle([cx - 2.45 * u, by, cx + 2.45 * u, by + lane_len], outline=LINE, width=lw)
    if lane_len >= 5.8 * u - 1:
        d.arc([cx - 1.8 * u, by + 5.8 * u - 1.8 * u, cx + 1.8 * u, by + 5.8 * u + 1.8 * u], 0, 180, fill=LINE, width=lw)
    d.rectangle([x0, y1, x1, H], fill=BG0)          # 描きすぎた線を、図の枠の外で消す
    d.line([(cx - 0.9 * u, by + 1.2 * u), (cx + 0.9 * u, by + 1.2 * u)], fill=O.WHITE, width=int(8 * S))
    hy = by + 1.2 * u + 0.35 * u
    d.ellipse([cx - 0.23 * u, hy - 0.23 * u, cx + 0.23 * u, hy + 0.23 * u], outline=BALLC, width=max(3, int(5 * S)))
    dist = P.get("d", 4)
    py = by + 3.3 * u
    sx = cx - 2.0 * u                              # 桜木
    rx = sx + dist * u                             # 流川
    pr = 0.42 * u
    if P.get("defenders"):
        for dx, dy in ((0.9, -1.2), (-0.4, -1.5), (1.4, 0.1)):
            a = _ease(k * 3)
            qx = rx + dx * u * (1.6 - 0.6 * a)
            qy = py + dy * u * (1.6 - 0.6 * a)
            d.ellipse([qx - pr, qy - pr, qx + pr, qy + pr], fill=(150, 156, 168), outline=O.NAVY, width=3)
    for (px_, py_, col) in ((sx, py, (235, 80, 80)), (rx, py, (80, 160, 240))):
        d.ellipse([px_ - pr, py_ - pr, px_ + pr, py_ + pr], fill=col, outline=O.WHITE, width=max(3, int(4 * S)))
    label(d, (sx, py + 0.95 * u), "桜木", 34 if LAND else 30, (255, 150, 140))
    label(d, (rx, py + 0.95 * u), "流川", 34 if LAND else 30, (150, 200, 255))
    ball = P.get("ball", "A")
    A, B = (rx - 0.2 * u, py - 0.1 * u), (sx + 0.2 * u, py - 0.1 * u)
    hoop = (cx, hy)
    pos = A
    if ball == "B":
        pos = B
    elif ball == "fly":
        e = _ease(k * 1.5)
        pos = (A[0] + (B[0] - A[0]) * e, A[1] + (B[1] - A[1]) * e)
    elif ball == "reach":
        e = _ease(k * 1.5) * P.get("p", 0.45)
        pos = (A[0] + (B[0] - A[0]) * e, A[1] + (B[1] - A[1]) * e)
    elif ball == "shot":
        e = _ease(k * 1.5)
        pos = (B[0] + (hoop[0] - B[0]) * e, B[1] + (hoop[1] - B[1]) * e)
    if ball in ("fly", "reach"):
        arrow(d, A[0] - 0.5 * u, A[1], B[0] + 0.7 * u, B[1], 6 * S, (190, 198, 215))
    if ball == "shot":
        arrow(d, B[0], B[1] - 0.5 * u, hoop[0] - 0.3 * u, hoop[1] + 0.3 * u, 6 * S, (190, 198, 215))
    br = 0.17 * u
    d.ellipse([pos[0] - br, pos[1] - br, pos[0] + br, pos[1] + br], fill=BALLC, outline=O.WHITE, width=max(2, int(3 * S)))
    fs = 34 if LAND else 28
    if P.get("dlabel"):
        hbracket(d, sx, rx, py + 1.75 * u, P["dlabel"], O.YEL, fs, up=False)
    if P.get("reach_label"):
        xe = A[0] + (B[0] - A[0]) * P.get("p", 0.45)
        hbracket(d, xe, A[0], py - 0.9 * u, P["reach_label"], O.RED, fs, up=True)
    if P.get("speed"):
        label(d, ((sx + rx) / 2, py - 1.0 * u), P["speed"], fs, O.YEL)
    if P.get("note"):
        label(d, (x1 - 50 * S, y0 + 52 * S), P["note"], fs, O.WHITE, "rm")


# ---- 「何秒かかるのか」 --------------------------------------------------------------------------

def sc_span(img, box, t, k, P):
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = box
    yc = (y0 + y1) / 2 + 20 * S
    xa, xb = x0 + (x1 - x0) * 0.22, x0 + (x1 - x0) * 0.78
    a = _ease(k * 2)
    for x, s, col in ((xa, "流川の手を離れる", (150, 200, 255)), (xb, "桜木の手を離れる", (255, 150, 140))):
        d.line([(x, yc - 70 * S), (x, yc + 70 * S)], fill=col, width=int(8 * S))
        d.ellipse([x - 20 * S, yc - 20 * S, x + 20 * S, yc + 20 * S], fill=BALLC, outline=O.WHITE, width=3)
        label(d, (x, yc - 130 * S), s, 40 if LAND else 34, col)
    arrow(d, xa + 30 * S, yc, xa + 30 * S + (xb - xa - 70 * S) * a, yc, 10 * S, O.YEL)
    if a > 0.6:
        text(d, ((xa + xb) / 2, yc - 70 * S), "何秒かかる？", 76 if LAND else 60, O.YEL, "mm", 6)


# ---- ジャンプシュート(横から) -----------------------------------------------------------------

def _figure(d, cx, foot, h, col, up=False):
    r = h * 0.085
    hip, sh = foot - h * 0.46, foot - h * 0.78
    w = max(6, int(11 * S))
    d.line([(cx - h * 0.1, foot), (cx, hip), (cx + h * 0.1, foot)], fill=col, width=w, joint="curve")
    d.line([(cx, hip), (cx, sh)], fill=col, width=w)
    ay = sh - (h * 0.26 if up else -h * 0.06)
    d.line([(cx - h * 0.15, ay), (cx, sh), (cx + h * 0.15, ay)], fill=col, width=w, joint="curve")
    d.ellipse([cx - r, sh - r * 1.7 - r, cx + r, sh - r * 1.7 + r], fill=col)


def sc_jump(img, box, t, k, P):
    """stage 0: 頂点で放す / 1: 受けてから跳ぶ(頂点まで約0.3秒) / 2: 先に跳ぶ(受けたときはもう空中)を並べる。"""
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = box
    st = P.get("stage", 0)
    fs = 36 if LAND else 30
    if st == 0:
        panels = [((x0 + x1) / 2, "頂点で放す", "up")]
    elif st == 1:
        panels = [((x0 + x1) / 2, "受けてから跳ぶ", "A")]
    else:
        panels = [(x0 + (x1 - x0) * 0.27, "受けてから跳ぶ", "A"), (x0 + (x1 - x0) * 0.73, "先に跳ぶ", "B")]
    floor = y1 - 70 * S
    h = min(380 * S, (floor - y0 - 290 * S))
    for cx, title, mode in panels:
        label(d, (cx, y0 + 120 * S), title, fs + 4, O.YEL)
        d.line([(cx - 200 * S, floor), (cx + 200 * S, floor)], fill=(160, 170, 190), width=int(5 * S))
        if mode == "up":
            lift = h * 0.30
            _figure(d, cx, floor - lift, h, (230, 235, 245), up=True)
            dash_v(d, cx + 150 * S, floor - lift * 1.0, floor, O.DIM, 3)
            d.ellipse([cx - 22 * S, floor - lift - h * 1.2 - 22 * S, cx + 22 * S, floor - lift - h * 1.2 + 22 * S], fill=BALLC, outline=O.WHITE, width=3)
            cap(d, (cx + 170 * S, floor - lift / 2), "頂点", fs, O.DIM, "lm")
        elif mode == "A":
            e = _ease(k * 1.6)
            lift = h * 0.30 * e
            _figure(d, cx, floor - lift, h, (230, 235, 245), up=True)
            bx, by_ = cx - 130 * S, floor - h * 0.9
            d.ellipse([bx - 20 * S, by_ - 20 * S, bx + 20 * S, by_ + 20 * S], fill=BALLC, outline=O.WHITE, width=3)
            arrow(d, cx + 170 * S, floor - 10 * S, cx + 170 * S, floor - h * 0.30 - 10 * S, 8 * S, O.YEL)
            label(d, (cx + 200 * S, floor - h * 0.15), "頂点まで 約0.3秒", fs - 4, O.YEL, "lm")
            cap(d, (cx - 160 * S, floor - h * 0.9 - 50 * S), "ここで受ける", fs - 6, O.DIM, "mm")
        else:
            lift = h * 0.30
            _figure(d, cx, floor - lift, h, (150, 220, 255), up=True)
            bx, by_ = cx - 130 * S, floor - lift - h * 0.9
            d.ellipse([bx - 20 * S, by_ - 20 * S, bx + 20 * S, by_ + 20 * S], fill=BALLC, outline=O.WHITE, width=3)
            cap(d, (cx - 200 * S, by_ + 60 * S), "受けたとき もう空中", fs - 6, O.DIM, "mm")


# ---- 壁(必要な時間の組み立て) ---------------------------------------------------------------------

def sc_wall(img, box, t, k, P):
    """stage 0: 決まりの0.3秒 / 1: ふれた瞬間から時計 / 2: パスが離れた瞬間から時計(飛ぶ0.13秒が加わる) / 3: 合計0.43 / 4: 壁と届く・届かない。"""
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = box
    st = P.get("stage", 0)
    h = y1 - y0
    gx0, gx1 = x0 + 70 * S, x1 - 70 * S
    xmax = 0.6
    px = lambda v: gx0 + (gx1 - gx0) * v / xmax
    bh = (110 if LAND else 90) * S
    ytop = y0 + h * (0.30 if LAND else 0.24)
    yb = ytop + bh
    fs = 36 if LAND else 30
    a = _ease(k * 2)
    if st <= 1:
        d.rectangle([px(0), ytop, px(0.3 * (a if st == 0 else 1)), yb], fill=C_CA)
        text(d, (px(0.15), ytop - 30 * S), "決まりの 0.3秒", fs, O.WHITE, "mm", 4)
    else:
        d.rectangle([px(0), ytop, px(0.13), yb], fill=C_FL)
        d.rectangle([px(0.13), ytop, px(0.43), yb], fill=C_CA)
        text(d, (px(0.065), ytop - 30 * S), "飛ぶ 0.13秒", fs, O.WHITE, "mm", 4)
        text(d, (px(0.28), ytop - 30 * S), "受けて放す 0.3秒", fs, O.WHITE, "mm", 4)
    for i in range(0, 7):
        v = i / 10
        d.line([(px(v), yb + 6 * S), (px(v), yb + 20 * S)], fill=O.DIM, width=max(2, int(3 * S)))
        cap(d, (px(v), yb + 42 * S), "0" if i == 0 else f"{v:g}", 26, O.DIM, "mm")
    cap(d, (gx1 + 36 * S, yb + 42 * S), "秒", 26, O.DIM, "lm")
    d.line([(px(0), ytop - 10 * S), (px(0), yb + 6 * S)], fill=O.WHITE, width=max(3, int(5 * S)))
    if st == 1:
        label(d, (px(0), ytop - 110 * S), "ボールにふれた瞬間から時計が動く", fs, O.YEL, "lm")
    elif st == 2:
        label(d, (px(0), ytop - 110 * S), "パスが離れた瞬間から時計が動く", fs, O.YEL, "lm")
    elif st == 3:
        hbracket(d, px(0), px(0.43), yb + 100 * S, "必要な時間 約0.43秒", O.YEL, fs, up=False)
    if st >= 4:
        xw = px(0.43)
        d.line([(xw, ytop - 40 * S), (xw, yb + 20 * S)], fill=O.RED, width=max(5, int(9 * S)))
        label(d, (xw, ytop - 110 * S), "壁 約0.43秒", fs + 4, O.RED)
        yz = y0 + h * (0.68 if LAND else 0.60)
        zh = 56 * S
        d.rectangle([px(0), yz, xw, yz + zh], fill=(140, 62, 62))
        d.rectangle([xw, yz, px(xmax), yz + zh], fill=(52, 128, 88))
        d.text(((px(0) + xw) / 2, yz + zh / 2), "届かない", font=O.font(int(fs * S)), fill=O.WHITE, anchor="mm")
        d.text(((xw + px(xmax)) / 2, yz + zh / 2), "届く", font=O.font(int(fs * S)), fill=O.WHITE, anchor="mm")
        for v, s, col in ((0.3, "残り0.3秒", O.RED), (0.5, "残り0.5秒", O.GREEN)):
            xm = px(v)
            d.polygon([(xm, yz + zh + 4 * S), (xm - 16 * S, yz + zh + 34 * S), (xm + 16 * S, yz + zh + 34 * S)], fill=col)
            label(d, (xm, yz + zh + 80 * S), s, fs - 2, col)
        cap(d, ((px(0) + px(xmax)) / 2, yz - 30 * S), "時計の残りが これより短いと…", fs - 8, O.DIM)


# ---- まとめ(余り秒の横棒) ------------------------------------------------------------------------

def sc_sur(img, box, t, k, P):
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = box
    rows, st = P["rows"], P.get("stage", 0)
    hl = P.get("hl")
    gx0, gx1 = x0 + 70 * S, x1 - 70 * S
    vlo, vhi = -0.4, 1.0
    px = lambda v: gx0 + (gx1 - gx0) * (v - vlo) / (vhi - vlo)
    label(d, ((x0 + x1) / 2, y0 + 50 * S), "余り秒のまとめ", 40 if LAND else 36, O.YEL)
    top = y0 + 130 * S
    pitch = (y1 - top - 90 * S) / 4
    bh = pitch * 0.28
    fs = 34 if LAND else 28
    d.line([(px(0), top - 10 * S), (px(0), top + pitch * 4)], fill=O.WHITE, width=max(3, int(5 * S)))
    cap(d, (px(0) - 12 * S, y1 - 40 * S), "← 間に合わない", fs - 6, (250, 150, 140), "rm")
    cap(d, (px(0) + 12 * S, y1 - 40 * S), "間に合う →", fs - 6, (140, 235, 175), "lm")
    for i, (name, v, note) in enumerate(rows):
        if i >= st:
            break
        a = 1.0 if i < st - 1 else _ease(k * 2)
        dim = hl is not None and i not in hl
        col = GOOD if v > 0 else BAD
        if dim:
            col = mix(col, BG1, 0.4)
        yc = top + pitch * (i + 0.5)
        text(d, (x0 + 60 * S, yc - bh / 2 - 30 * S), name, fs, mix(O.WHITE, BG1, 0.45) if dim else O.WHITE, "lm", 4)
        xe = px(v * a)
        d.rectangle([min(px(0), xe), yc - bh / 2, max(px(0), xe), yc + bh / 2], fill=col)
        if a > 0.7:
            s = fsign(v) + "秒"
            if v > 0:
                text(d, (max(px(0), xe) + 14 * S, yc), s, 40, O.WHITE, "lm", 5)
            else:
                text(d, (min(px(0), xe) - 14 * S, yc), s, 40, O.WHITE, "rm", 5)
            if note:
                text(d, (x0 + 60 * S, yc + bh / 2 + 30 * S), note, fs - 6, O.DIM, "lm", 3)
    if P.get("brace"):
        label(d, (x1 - 60 * S, y0 + 50 * S), P["brace"], fs - 2, O.YEL, "rm")


# ---- 棒グラフ(copy: 他の回と同じ部品) ------------------------------------------------------------

def bars(d, box, rows, vmax, k=1.0, grow_from=0, names_above=None, y_top=None):
    """rows = [(名前, 値, 数字の札, 色)]。値は vmax に対する横の長さ。"""
    x0, y0, x1, y1 = box
    na = (not LAND) if names_above is None else names_above
    ya = y_top if y_top is not None else y0 + (210 if not LAND else 150) * S
    n = len(rows)
    rh = min((200 if not na else 230) * S, (y1 - 50 * S - ya) / n)
    ya = max(ya, ya + ((y1 - 50 * S - ya) - rh * n) * 0.4)
    gx0 = x0 + 50 * S if na else x0 + (x1 - x0) * 0.27
    gx1 = x1 - 50 * S
    px = lambda v: gx0 + (gx1 - gx0) * min(v, vmax) / vmax
    bh = rh * (0.3 if na else 0.44)
    f = O.font(int(36 * S))
    for i, (name, val, txt, col) in enumerate(rows):
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
        e = gx0 + max(8 * S, (px(val) - gx0)) * a
        d.rectangle([gx0, cy - bh / 2, e, cy + bh / 2], fill=col)
        tw = f.getlength(txt)
        if a > 0.6:
            if e + 14 * S + tw > x1 - 20 * S:
                text(d, (e - 14 * S, cy), txt, 36, O.WHITE, "rm", 5)
            else:
                text(d, (e + 14 * S, cy), txt, 36, O.WHITE, "lm", 4)


def sc_bars(img, box, t, k, P):
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    bars(d, box, P["rows"], P["vmax"], k, P.get("grow_from", 0), P.get("names_above"))
    if P.get("head"):
        x0, y0, x1, y1 = box
        label(d, ((x0 + x1) / 2, y0 + (130 if (TAGGED[0] and not LAND) else 60) * S), P["head"], 42, O.YEL)


KINDS = dict(formula=sc_formula, tl=sc_tl, court=sc_court, span=sc_span, meterbig=sc_meterbig, jump=sc_jump, wall=sc_wall, sur=sc_sur, bars=sc_bars)
TAGKINDS = ("tl", "court", "jump", "bars")     # 「実験N」の札を付ける図


def region(P):
    return (0, 100, W, 880) if LAND else (0, 240, W, 1370)


def paint(sc, t, k):
    img = Image.new("RGBA", (W, H), BG0 + (255,))
    main, mb = split(region(sc), sc)
    KINDS[sc["kind"]](img, main, t, k, sc)
    if mb:
        meter(img, mb, sc["meter"], k, t)
    return img


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
    tag = dd.get("exp") if now["kind"] in TAGKINDS else None
    TAGGED[0] = bool(tag) and not LAND
    u = _ease((t - cur["start"]) / 0.5)
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
        t0 = cur["start"] + v[1] * (cur["end"] - cur["start"])
        if t >= t0:
            main, mb = split(box, now)
            _stamp(img, mb or main, v[0], (t - t0) / 0.5, (now.get("meter") or {}).get("v", 0.0))


def sfx_for(lines_def, L):
    ev = mapscene.sfx(lines_def, L)
    for d in lines_def:
        v = d.get("verdict")
        if v and d["id"] in L:
            l = L[d["id"]]
            ev.append((l["start"] + v[1] * (l["end"] - l["start"]), "pop"))
    return sorted(ev)
