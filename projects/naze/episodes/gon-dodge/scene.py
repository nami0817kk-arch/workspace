"""ゴンのドッジボールの一球(計算の回)の画面。行の scene=dict(kind=…) を描く(無い行は前の行を引き継ぐ)。
場面が変わると 0.5 秒で溶け合わせる。作品の絵・キャラの絵は一切使わない。人は丸と棒の記号、球は丸。図は全部コードで描く。
数字は sim/calc.txt・sim/deep.txt・sim/punch_mj.txt と同じ(曲線は deep.py と同じ式でここで計算し直す)。
kind: formula / court / cart / floor / grid / speed / wind / decay / shock / press / heat / time / punch / cap / table / pitch /
      bars / human / arm / bone / fbar / slide / fist / squash / recoil
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
BALLC = (240, 140, 40)
GON = (235, 95, 85)          # ゴン(記号の丸。作品の絵ではない)
MATE = (90, 170, 235)        # 仲間
OPP = (170, 176, 190)        # 相手
GOOD, BAD = (70, 200, 120), (240, 90, 80)
GRID = (44, 62, 100)

# ---- 計算(deep.py と同じ式) -------------------------------------------------------------------
RHO, CSND, MB, DB = 1.225, 340.0, 0.33, 0.21
AB = math.pi * (DB / 2) ** 2
KDRAG = 0.5 * RHO * 0.92 * AB / MB          # 超音速の抗力係数 0.92(仮置き)。dv/dx = -K v


def v_at(x, v_arrive=5516 / 3.6, L=10.0):
    """相手の所(L)で v_arrive になる球の、打った所から x の速さ(m/s)"""
    return v_arrive * math.exp(KDRAG * (L - x))


def _heat_curve():
    """置いた値の真ん中・空気ありの組の、球の表面の温度(℃)の時間の並び(deep.py 9 と同じ式。半無限の固体に熱の流れ)"""
    n = 400
    dx = 10.0 / n
    ts, qs = [0.0], []
    for i in range(n):
        v = v_at(i * dx + dx / 2)
        qs.append(1.7415e-4 * math.sqrt(RHO / (DB / 2)) * v ** 3)
        ts.append(ts[-1] + dx / v)
    e = math.sqrt(0.15 * 1100.0 * 1900.0)
    out = []
    for j in range(1, 81):
        t = ts[-1] * j / 80
        acc = 0.0
        for i in range(n):
            if ts[i] >= t:
                break
            acc += qs[i] * 2 * (math.sqrt(t - ts[i]) - math.sqrt(max(0.0, t - ts[i + 1])))   # 区間ごとに 1/√(t−τ) を積分
        out.append((t, 15 + acc / (math.sqrt(math.pi) * e)))
    return [(0.0, 15.0)] + out


HEAT = _heat_curve()


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
    text(d, xy, s, size, col, anchor, 3)


def mix(c, bg, a):
    return tuple(int(c[i] * a + bg[i] * (1 - a)) for i in range(3))


def arrow(d, x0, y0, x1, y1, w, col):
    ang = math.atan2(y1 - y0, x1 - x0)
    L = math.hypot(x1 - x0, y1 - y0)
    if L < 2:
        return
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
        text(d, ((x0 + x1) / 2, y + (-40 if up else 40) * S), s, size, col, "mm", 5)


def dash(d, p0, p1, col, w=4, seg=14, gap=10):
    (x0, y0), (x1, y1) = p0, p1
    L = math.hypot(x1 - x0, y1 - y0)
    if L < 1:
        return
    ux, uy = (x1 - x0) / L, (y1 - y0) / L
    s = 0.0
    while s < L:
        e = min(L, s + seg * S)
        d.line([(x0 + ux * s, y0 + uy * s), (x0 + ux * e, y0 + uy * e)], fill=col, width=max(2, int(w * S)))
        s += (seg + gap) * S


def ball(d, x, y, r, col=BALLC):
    d.ellipse([x - r, y - r, x + r, y + r], fill=col, outline=O.WHITE, width=max(2, int(3 * S)))
    d.arc([x - r * 0.7, y - r * 0.7, x + r * 0.7, y + r * 0.7], 200, 320, fill=(255, 200, 140), width=max(2, int(3 * S)))


def dot(d, x, y, r, col, outline=O.WHITE):
    d.ellipse([x - r, y - r, x + r, y + r], fill=col, outline=outline, width=max(2, int(4 * S)))


def figure(d, cx, foot, h, col, pose="stand", lean=0.0):
    """記号の棒人間。pose: stand / reach(腕を前へ) / punch(右へ突く) / catch(両手を前へ)"""
    r = h * 0.09
    w = max(5, int(h * 0.045))
    hip = (cx + lean * h * 0.2, foot - h * 0.47)
    sh = (cx + lean * h * 0.35, foot - h * 0.8)
    d.line([(cx - h * 0.12, foot), hip, (cx + h * 0.12, foot)], fill=col, width=w, joint="curve")
    d.line([hip, sh], fill=col, width=w)
    if pose == "punch":
        d.line([sh, (sh[0] + h * 0.42, sh[1] + h * 0.02)], fill=col, width=w)
        d.line([sh, (sh[0] - h * 0.16, sh[1] + h * 0.2)], fill=col, width=w)
        dot(d, sh[0] + h * 0.45, sh[1] + h * 0.02, h * 0.06, col)
    elif pose == "catch":
        d.line([sh, (sh[0] - h * 0.3, sh[1] + h * 0.08)], fill=col, width=w)
        d.line([sh, (sh[0] - h * 0.3, sh[1] + h * 0.18)], fill=col, width=w)
    elif pose == "reach":
        d.line([sh, (sh[0] + h * 0.3, sh[1] + h * 0.1)], fill=col, width=w)
        d.line([sh, (sh[0] + h * 0.3, sh[1] + h * 0.2)], fill=col, width=w)
    else:
        d.line([sh, (sh[0] - h * 0.15, sh[1] + h * 0.3)], fill=col, width=w)
        d.line([sh, (sh[0] + h * 0.15, sh[1] + h * 0.3)], fill=col, width=w)
    d.ellipse([sh[0] - r, sh[1] - r * 2.6, sh[0] + r, sh[1] - r * 0.6], fill=col)


def fsz(s, size, maxw):
    sz = size
    while O.font(int(sz * S)).getlength(s) > maxw and sz > 24:
        sz -= 2
    return sz


def head(d, box, s, col=O.YEL, size=None):
    """図の上の見出し(箱つきの札)"""
    x0, y0, x1, y1 = box
    sz = fsz(s, size or (40 if LAND else 38), (x1 - x0) - 120 * S)
    label(d, ((x0 + x1) / 2, y0 + 48 * S), s, sz, col)


# ---- 札(文字だけの場面) -----------------------------------------------------------------------

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
        sz = fsz(s, size, (x1 - x0) - (90 if LAND else 110) * S)
        text(d, (cx, y0 + gap * (i + 1) + 6 * S * math.sin(t * 1.3 + i)), s, sz, c, "mm", 6)


# ---- 試合の場(上から見た図。丸は記号) ---------------------------------------------------------

def sc_court(img, box, t, k, P):
    """mode: hold(仲間が球を持ち、ゴンが力をためる) / fist(拳で打つ) / fly(球が飛ぶ) / ghost(捕れば場の外へ) / nocatch(捕らずに打ち返す) / charge(力をためるのを見ている)"""
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    grad(img, box=box)
    mode = P.get("mode", "hold")
    mx = (x1 - x0) * 0.10
    top = y0 + (130 if LAND else 170) * S
    bot = y1 - (70 if LAND else 120) * S
    cx0, cx1 = x0 + mx, x1 - mx
    d.rectangle([cx0, top, cx1, bot], fill=(36, 70, 60), outline=(236, 228, 208), width=max(3, int(5 * S)))
    mid = (cx0 + cx1) / 2
    d.line([(mid, top), (mid, bot)], fill=(236, 228, 208), width=max(3, int(5 * S)))
    cy = (top + bot) / 2
    u = (cx1 - cx0) / 20                        # 図の1目盛り
    gx, mxp = cx0 + 4.2 * u, cx0 + 6.6 * u      # ゴン・仲間
    ox = cx1 - 3.6 * u                          # 相手の中心の選手
    pr = (0.7 if LAND else 0.95) * u
    br = (0.32 if LAND else 0.42) * u
    # 相手の他の選手(小さな灰色の丸)
    for dx, dy in ((-2.6, -2.6), (-2.2, 2.8), (-5.0, 0.4)):
        dot(d, ox + dx * u, cy + dy * u, pr * 0.8, (120, 126, 140), O.NAVY)
    for dx, dy in ((-1.4, -3.0), (-0.6, 3.0)):
        dot(d, gx + dx * u, cy + dy * u, pr * 0.8, (80, 110, 150), O.NAVY)
    fs = 34 if LAND else 34
    # ゴン(記号の丸)と仲間
    dot(d, gx, cy, pr, GON)
    text(d, (gx, cy + pr + 34 * S), "ゴン", fs, (255, 170, 160), "mm", 5)
    dot(d, mxp, cy - 1.6 * u, pr * 0.85, MATE)
    text(d, (mxp, cy - 1.6 * u - pr - 30 * S), "仲間", fs - 2, (160, 210, 255), "mm", 5)
    big = pr * 1.25
    ghost = mode == "ghost"
    oxx = ox
    if ghost:
        e = _ease((k - 0.15) * 2.2)
        oxx = ox + (cx1 + 1.2 * u - ox) * e
        d.ellipse([ox - big, cy - big, ox + big, cy + big], outline=(200, 205, 215), width=max(2, int(3 * S)))
        if e > 0.05:
            dot(d, oxx, cy, big, mix(OPP, BG1, 0.55), (210, 214, 224))
            arrow(d, ox + big, cy, oxx - big * 0.4, cy, 8 * S, O.RED)
    else:
        dot(d, ox, cy, big, OPP)
    text(d, (ox, cy - big - 36 * S), "相手の中心の選手", fs - 4, (225, 228, 236), "mm", 5)
    hold = (mxp + pr * 1.3, cy - 1.0 * u)            # 仲間が持つ球の位置
    fist = (gx + pr * 1.1, cy - 0.2 * u)
    note = None
    if mode in ("hold", "charge"):
        launch = P.get("launch") and k > 0.72
        for i in range(3):     # 力をためる輪(t で回し続ける)
            ph = (t * 1.4 + i / 3) % 1.0
            rr = pr * (1.2 + 1.6 * ph)
            c = mix((255, 214, 64), BG1, 1 - ph)
            d.ellipse([gx - rr, cy - rr, gx + rr, cy + rr], outline=c, width=max(2, int(5 * S)))
        if launch:
            e = _ease((k - 0.72) / 0.28)
            bx = hold[0] + (ox - big - hold[0]) * e
            by = hold[1] + (cy - hold[1]) * e
            for j in range(1, 5):
                d.line([(bx - j * 0.9 * u, by - j * 0.02 * u), (bx - (j - 0.6) * 0.9 * u, by)], fill=(255, 200, 120), width=max(2, int(4 * S)))
            ball(d, bx, by, br)
            if e < 0.5:
                text(d, (hold[0] + 2.4 * u, hold[1] - 1.2 * u), "ドン", 64 if LAND else 56, O.YEL, "mm", 6)
        else:
            ball(d, *hold, br)
        note = "力をためる" if mode == "hold" else None
        if mode == "charge":
            dash(d, (ox - big, cy - 0.2 * u), (gx + pr * 1.6, cy - 0.2 * u), (255, 214, 64), 4)
            note = "決められるのは　ここを見ているあいだだけ"
    elif mode == "fist":
        e = _ease(k * 2.0)
        ph = (t % 2.4) / 2.4
        hit = ph > 0.35
        fx = fist[0] + (hold[0] - 0.3 * u - fist[0]) * min(1.0, ph / 0.35)
        d.line([(gx, cy), (fx, hold[1])], fill=GON, width=max(6, int(12 * S)))
        dot(d, fx, hold[1], 0.28 * u, GON)
        bx = hold[0] if not hit else hold[0] + (ox - big - hold[0]) * _ease((ph - 0.35) / 0.4)
        by = hold[1] if not hit else hold[1] + (cy - hold[1]) * _ease((ph - 0.35) / 0.4)
        ball(d, bx, by, br)
        note = "投げずに　拳で殴って飛ばす" if e > 0.3 else None
    elif mode == "fly":
        ph = (t % 1.8) / 1.8
        bx = hold[0] + (ox - big - hold[0]) * ph
        by = hold[1] + (cy - hold[1]) * ph
        for j in range(1, 6):
            d.line([(bx - j * 0.8 * u, by - (cy - hold[1]) * 0.8 * j / (ox - hold[0]) * u), (bx - (j - 0.5) * 0.8 * u, by)], fill=mix((255, 200, 120), BG1, 1 - j / 7), width=max(2, int(5 * S)))
        ball(d, bx, by, br)
        note = "3度目の一球"
    elif mode == "ghost":
        ball(d, oxx - big * 0.9, cy, br)
        dash(d, (cx1, top), (cx1, bot), O.RED, 6)
        if k > 0.35:
            text(d, (cx1 - 0.2 * u, top - 28 * S), "場の外", fs, O.RED, "rm", 5)
        note = "捕れば　体ごと場の外へ"
    elif mode == "nocatch":
        ph = (t % 2.4) / 2.4
        if ph < 0.4:
            q = ph / 0.4
            bx, by = hold[0] + (ox - big - hold[0]) * q, hold[1] + (cy - hold[1]) * q
        else:
            q = (ph - 0.4) / 0.6
            bx, by = ox - big + (mid - 2.0 * u - (ox - big)) * q, cy - 2.5 * u * math.sin(q * math.pi * 0.5)
        ball(d, bx, by, br)
        arrow(d, ox - big - 0.4 * u, cy + 1.2 * u, mid + 1.0 * u, cy + 1.2 * u, 7 * S, (225, 228, 236))
        note = "捕らずに　打ち返す"
    if note:
        label(d, ((x0 + x1) / 2, y0 + 56 * S), note, 38 if LAND else 34, O.YEL)


# ---- 台車の図(勢いの合計は変わらない) ---------------------------------------------------------

def sc_cart(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    st = P.get("st", 0)
    floor = y1 - (110 if LAND else 170) * S
    d.line([(x0 + 40 * S, floor), (x1 - 40 * S, floor)], fill=(160, 170, 190), width=max(3, int(6 * S)))
    for i in range(30):
        xx = x0 + 40 * S + i * (x1 - x0) / 30
        d.line([(xx, floor), (xx - 20 * S, floor + 22 * S)], fill=(90, 100, 125), width=2)
    hfig = (400 if LAND else 380) * S
    cw = 240 * S
    base = x0 + (x1 - x0) * 0.55
    ph = (t % 4.0) / 4.0 if st >= 1 else min(1.0, k * 1.2) * 0.3
    catch = 0.3
    if ph < catch:
        cxp = base
        bx = x1 - 60 * S - (x1 - 60 * S - (base - 0.32 * hfig)) * (ph / catch)
    else:
        q = (ph - catch) / (1 - catch)
        cxp = base - (x1 - x0) * 0.32 * q
        bx = cxp - 0.32 * hfig
    cy = floor - 40 * S
    d.rounded_rectangle([cxp - cw / 2, cy - 30 * S, cxp + cw / 2, cy + 10 * S], int(8 * S), fill=(120, 130, 155), outline=O.WHITE, width=max(2, int(3 * S)))
    for wx in (cxp - cw * 0.32, cxp + cw * 0.32):
        rr = 26 * S
        d.ellipse([wx - rr, floor - 2 * rr, wx + rr, floor], fill=(60, 66, 84), outline=O.WHITE, width=max(2, int(3 * S)))
        a = -(cxp - base) / rr
        d.line([(wx, floor - rr), (wx + rr * 0.9 * math.cos(a), floor - rr + rr * 0.9 * math.sin(a))], fill=O.WHITE, width=2)
    figure(d, cxp, cy - 30 * S, hfig, (230, 235, 245), pose="catch")
    ball(d, bx, cy - 30 * S - hfig * 0.72, 30 * S)
    fs = 36 if LAND else 32
    yl = cy - 30 * S - hfig - 50 * S
    if ph < catch:
        arrow(d, bx + 50 * S, cy - 30 * S - hfig * 0.72, bx + 150 * S, cy - 30 * S - hfig * 0.72, 7 * S, (255, 200, 120)) if False else None
        text(d, (bx + 130 * S, cy - 30 * S - hfig * 0.72 - 70 * S), "球　m・v", fs, (255, 200, 120), "mm", 5)
        arrow(d, bx + 160 * S, cy - 30 * S - hfig * 0.72, bx + 40 * S, cy - 30 * S - hfig * 0.72, 7 * S, (255, 200, 120))
    else:
        arrow(d, cxp - cw / 2 - 20 * S, cy - 60 * S, cxp - cw / 2 - 200 * S, cy - 60 * S, 9 * S, O.YEL)
        text(d, (cxp, yl), "人＋台車＋球　(M＋m)・V", fs, O.YEL, "mm", 5)
    if st >= 2:
        label(d, ((x0 + x1) / 2, y0 + 56 * S), "m v ＝ (M＋m) V　勢いの合計は変わらない", 38 if LAND else 32, O.YEL)
    else:
        label(d, ((x0 + x1) / 2, y0 + 56 * S), "台車に乗って　ボールを捕る", 38 if LAND else 34, O.WHITE)


# ---- 床と摩擦 -----------------------------------------------------------------------------------

def sc_floor(img, box, t, k, P):
    """mode: box(重い家具。押す力が上限を越えると滑る) / out(滑った先が線の外) / stop(線の手前で止まりきれる速さ) / stand(足で踏んばる)"""
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    mode = P.get("mode", "box")
    floor = y1 - (110 if LAND else 190) * S
    d.rectangle([x0 + 30 * S, floor, x1 - 30 * S, floor + 24 * S], fill=(110, 84, 62))
    d.line([(x0 + 30 * S, floor), (x1 - 30 * S, floor)], fill=(200, 170, 130), width=max(3, int(5 * S)))
    fs = 36 if LAND else 32
    if mode == "box":
        ph = (t % 4.5) / 4.5
        push = min(1.0, ph / 0.6)                 # 押す力 0→上限
        slide = max(0.0, (ph - 0.6) / 0.4)
        bw, bh = (300 if LAND else 280) * S, (230 if LAND else 220) * S
        bx = (x0 + x1) / 2 - bw / 2 + slide * slide * (x1 - x0) * 0.22
        d.rectangle([bx, floor - bh, bx + bw, floor], fill=(150, 112, 80), outline=(230, 200, 160), width=max(3, int(5 * S)))
        for j in range(1, 3):
            d.line([(bx + 20 * S, floor - bh * j / 3), (bx + bw - 20 * S, floor - bh * j / 3)], fill=(110, 80, 56), width=max(2, int(4 * S)))
        ly = floor - bh / 2
        arrow(d, bx - 30 * S - 200 * S * push, ly, bx - 10 * S, ly, 12 * S, O.YEL)
        text(d, (bx - 130 * S, ly - 56 * S), "押す力", fs, O.YEL, "mm", 5)
        fr = min(push, 1.0)
        arrow(d, bx + bw * 0.5, floor + 50 * S, bx + bw * 0.5 - 200 * S * fr, floor + 50 * S, 10 * S, (140, 210, 255))
        text(d, (bx + bw * 0.5 + 20 * S, floor + 50 * S), "床の摩擦", fs - 4, (140, 210, 255), "lm", 5)
        s = "ここまでは　びくともしない" if slide <= 0 else "上限を越えて　ずるっと滑る"
        label(d, ((x0 + x1) / 2, y0 + 56 * S), "踏んばれる力の上限 ＝ 摩擦 × 重さ × 重力", 36 if LAND else 30, O.WHITE)
        text(d, ((x0 + x1) / 2, y0 + 150 * S), s, 44 if LAND else 40, O.RED if slide > 0 else O.GREEN, "mm", 6)
        return
    line_x = x0 + (x1 - x0) * 0.80
    dash(d, (line_x, floor - (480 if LAND else 560) * S), (line_x, floor + 20 * S), O.RED, 7)
    text(d, (line_x + (16 if LAND else -16) * S, floor - (460 if LAND else 540) * S), "線（この先は場の外）", fs - 4, O.RED, "la" if LAND else "ra", 5)
    hfig = (330 if LAND else 340) * S
    start = x0 + (x1 - x0) * 0.25
    if mode == "stand":
        figure(d, start + 120 * S, floor, hfig, (230, 235, 245), pose="catch")
        ph = (t % 2.0) / 2.0
        ball(d, start + 120 * S - hfig * 0.3 - 30 * S - 260 * S * (1 - ph), floor - hfig * 0.72, 28 * S)
        arrow(d, start - 160 * S, floor - hfig * 0.45, start + 40 * S, floor - hfig * 0.45, 10 * S, (255, 200, 120))
        text(d, (start - 60 * S, floor - hfig * 0.45 - 46 * S), "球の勢い", fs - 4, (255, 200, 120), "mm", 5)
        arrow(d, start + 260 * S, floor + 56 * S, start + 80 * S, floor + 56 * S, 9 * S, (140, 210, 255))
        text(d, (start + 280 * S, floor + 56 * S), "足で踏んばる", fs - 4, (140, 210, 255), "lm", 5)
        label(d, ((x0 + x1) / 2, y0 + 56 * S), "床の上では　足で受け止めるしかない", 38 if LAND else 32, O.WHITE)
        return
    ph = (t % 4.0) / 4.0
    q = min(1.0, ph / 0.75)
    if mode == "out":
        px = start + (line_x + (x1 - line_x) * 0.6 - start) * (1 - (1 - q) ** 1.6)
        figure(d, px, floor, hfig, (230, 235, 245), pose="catch", lean=-0.3)
        if px > line_x:
            text(d, (line_x + (x1 - line_x) / 2, floor - hfig - 70 * S), "アウト", 64 if LAND else 56, O.RED, "mm", 6)
        label(d, ((x0 + x1) / 2, y0 + 56 * S), "捕ったのに　外へ出たら　アウト", 38 if LAND else 32, O.WHITE)
    else:   # stop
        stop_x = line_x - 18 * S
        px = start + (stop_x - start) * (1 - (1 - q) ** 2)
        figure(d, px, floor, hfig, (230, 235, 245), pose="catch", lean=-0.3 * (1 - q))
        hbracket(d, start, line_x, floor + 70 * S, "場の外まで　1.5m", O.YEL, fs - 2, up=False)
        label(d, ((x0 + x1) / 2, y0 + 56 * S), "V ＝ √(2 × 摩擦 × 重力 × 距離) ＝ 秒速4.20m", 36 if LAND else 30, O.YEL)
        text(d, ((x0 + x1) / 2, y0 + 150 * S), "止まりきれるのは　時速15kmまで", 46 if LAND else 40, O.WHITE, "mm", 6)


# ---- 重さの比べ(タイル) ---------------------------------------------------------------------------

def sc_grid(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    n = P.get("n", 365)
    cols = 25 if LAND else 19
    rows = math.ceil(n / cols)
    top = y0 + 130 * S
    area_w = (x1 - x0) * (0.62 if LAND else 0.86)
    cell = min(area_w / cols, (y1 - top - 90 * S) / rows)
    gx = (x0 + x1) / 2 - cols * cell / 2 if not LAND else x0 + 60 * S
    shown = int(n * _ease(k * 1.6)) if P.get("grow", True) else n
    for i in range(n):
        r, c = divmod(i, cols)
        xx, yy = gx + c * cell, top + r * cell
        if i == 0:
            col = BALLC
        elif i < shown:
            col = (150, 160, 185)
        else:
            col = (40, 54, 86)
        d.rounded_rectangle([xx + 2, yy + 2, xx + cell - 2, yy + cell - 2], int(cell * 0.2), fill=col)
    label(d, ((x0 + x1) / 2, y0 + 56 * S), P.get("head", "選手と合わせた重さ ＝ 球のおよそ365倍"), 38 if LAND else 32, O.YEL)
    fs = 40 if LAND else 34
    if LAND:
        tx = gx + cols * cell + 60 * S
        text(d, (tx, top + 40 * S), "■ 球 1つ分 ＝ 330g", fs, BALLC, "la", 5)
        text(d, (tx, top + 120 * S), "選手（120kg）と球", fs, O.WHITE, "la", 5)
        text(d, (tx, top + 190 * S), "＝ この 365個分", fs, O.WHITE, "la", 5)
        text(d, (tx, top + 300 * S), "球は 365分の1", 60, O.YEL, "la", 6)
    else:
        yy = top + rows * cell + 50 * S
        text(d, ((x0 + x1) / 2, yy), "■ 1つ ＝ 球 330g　全部で 選手と球", fs - 4, O.WHITE, "mm", 5)


# ---- 速さの帯(横棒。ゴンの値は「少なくとも」で右へ伸びる) --------------------------------------------

def hbar_rows(d, box, rows, vmax, k, unit_fmt, top_pad=140, grow_last=True, xlabel=None, open_rows=()):
    """rows = [(名前, 値, 札の字, 色, 少なくとも?)]。少なくとも の行は値から右の端まで点線の矢印。"""
    x0, y0, x1, y1 = box
    n = len(rows)
    na = not LAND
    top = y0 + top_pad * S
    pitch = min((150 if LAND else 190) * S, (y1 - top - 70 * S) / max(1, n))
    gx0 = x0 + (540 if LAND else 60) * S
    gx1 = x1 - 70 * S
    px = lambda v: gx0 + (gx1 - gx0) * min(v, vmax) / vmax
    bh = pitch * (0.42 if not na else 0.30)
    for i, (name, val, txt, col, atleast) in enumerate(rows):
        a = _ease(k * 1.8) if (grow_last and i == n - 1) else 1.0
        yc = top + pitch * (i + 0.5) + (16 * S if na else 0)
        if na:
            text(d, (gx0, yc - bh / 2 - 12 * S), name, fsz(name, 34, gx1 - gx0), O.WHITE, "ld", 4)
        else:
            text(d, (gx0 - 20 * S, yc), name, fsz(name, 36, gx0 - x0 - 50 * S), O.WHITE, "rm", 4)
        e = gx0 + max(6 * S, px(val) - gx0) * a
        d.rectangle([gx0, yc - bh / 2, e, yc + bh / 2], fill=col)
        if atleast and a > 0.9:
            dash(d, (e + 8 * S, yc), (gx1 - 30 * S, yc), col, 6)
            arrow(d, gx1 - 40 * S, yc, gx1 + 30 * S, yc, 8 * S, col)
        if a > 0.6:
            f = O.font(int(36 * S))
            tw = f.getlength(txt)
            if atleast:
                ty = yc - bh / 2 - (26 if LAND else 22) * S if not na else yc + bh / 2 + 26 * S
                text(d, (min(e, gx1 - tw) if e + tw < gx1 else gx1 - tw, ty), txt, 34, O.WHITE, "lm", 5)
            elif e + 14 * S + tw > gx1:
                text(d, (e - 14 * S, yc), txt, 34, O.WHITE, "rm", 5)
            else:
                text(d, (e + 14 * S, yc), txt, 34, O.WHITE, "lm", 4)
    return px, top, pitch


def sc_speed(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    st = P.get("st", 1)
    rows = [("野球の最速", 170.3, "時速170km", (190, 195, 205), False)]
    if st >= 2:
        rows.append(("音の速さ", 1220, "時速約1,220km", (140, 200, 240), False))
    if st >= 3:
        rows.append(("ゴン　控えめ", 2424, "少なくとも 2,420km", (250, 165, 80), True))
    rows.append(("ゴン　真ん中", 5516, "少なくとも 5,500km", (240, 90, 80), True))
    if st >= 3:
        rows.append(("ゴン　大きめ", 11254, "少なくとも 11,250km", (200, 70, 70), True))
    hbar_rows(d, box, rows, 12000, k if st == P.get("grow_st", st) else 1.0, None, grow_last=False)
    hd = {1: "野球の最速の　30倍を超える", 2: "音の速さの　4倍以上", 3: "上の端は無い　どれも最低の速さ"}[st]
    head(d, box, "時速（km）　" + hd)


# ---- 車の窓から手を出す(空気の抵抗は速さの2乗) ---------------------------------------------------------

def sc_wind(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    ph = (t % 6.0) / 6.0
    fast = ph >= 0.5
    sp = 2.0 if fast else 1.0
    cx = x0 + (x1 - x0) * (0.40 if LAND else 0.5)
    cy = y0 + (y1 - y0) * (0.55 if LAND else 0.42)
    cw, ch = (520 if LAND else 560) * S, 220 * S
    d.rounded_rectangle([cx - cw / 2, cy - ch / 2, cx + cw / 2, cy + ch / 2], int(40 * S), fill=(70, 90, 130), outline=O.WHITE, width=max(2, int(4 * S)))
    d.rounded_rectangle([cx - cw * 0.35, cy - ch * 0.42, cx + cw * 0.15, cy - ch * 0.02], int(14 * S), fill=(150, 190, 225))
    for wx in (cx - cw * 0.3, cx + cw * 0.3):
        rr = 46 * S
        d.ellipse([wx - rr, cy + ch / 2 - rr, wx + rr, cy + ch / 2 + rr], fill=(40, 44, 60), outline=O.WHITE, width=max(2, int(3 * S)))
    hx, hy = cx - cw * 0.1, cy - ch * 0.5 - 60 * S
    d.line([(cx - cw * 0.1, cy - ch * 0.2), (hx, hy)], fill=(240, 200, 170), width=max(8, int(22 * S)))
    d.ellipse([hx - 34 * S, hy - 40 * S, hx + 34 * S, hy + 24 * S], fill=(240, 200, 170))
    n = 4 if not fast else 4
    for i in range(n):
        yy = hy - 40 * S + i * 22 * S
        L = 120 * S * sp * sp / 2
        off = ((t * 300 * S * sp) % (140 * S))
        xs = hx - 60 * S - L - off
        arrow(d, xs, yy, hx - 46 * S, yy, max(4, int(6 * S * sp)), (200, 230, 255))
    # 速さと押し戻す力の棒
    bx0 = x0 + (x1 - x0) * (0.70 if LAND else 0.14)
    by = y0 + (y1 - y0) * (0.30 if LAND else 0.72)
    fs = 36 if LAND else 32
    bw_max = (x1 - bx0 - 60 * S) * (0.45 if LAND else 0.42)
    for j, (nm, v, col) in enumerate((("速さ", sp, (255, 214, 64)), ("押し戻す力", sp * sp, (240, 90, 80)))):
        yy = by + j * 130 * S
        text(d, (bx0, yy), nm, fs, O.WHITE, "lm", 5)
        w = bw_max * v / 4
        xs = bx0 + (130 if LAND else 220) * S
        d.rectangle([xs, yy + 30 * S, xs + w, yy + 70 * S], fill=col)
        text(d, (xs + w + 16 * S, yy + 50 * S), f"{v:g}倍", fs, col, "lm", 5)
    label(d, ((x0 + x1) / 2, y0 + 56 * S), "速さが2倍なら　押し戻す力は4倍", 38 if LAND else 34, O.YEL)


# ---- グラフの軸 ------------------------------------------------------------------------------------

def axes(d, box, xr, yr, xt, yt, xlab, ylab, pad=(150, 120, 80, 110)):
    """xr, yr = (最小, 最大)。xt, yt = 目盛り [(値, 字)]。戻り値は 座標の関数。pad = (左, 上, 右, 下)"""
    x0, y0, x1, y1 = box
    gl, gt, gr, gb = x0 + pad[0] * S, y0 + pad[1] * S, x1 - pad[2] * S, y1 - pad[3] * S
    X = lambda v: gl + (gr - gl) * (v - xr[0]) / (xr[1] - xr[0])
    Y = lambda v: gb - (gb - gt) * (v - yr[0]) / (yr[1] - yr[0])
    for v, s in yt:
        d.line([(gl, Y(v)), (gr, Y(v))], fill=GRID, width=max(1, int(2 * S)))
        cap(d, (gl - 14 * S, Y(v)), s, 26, O.DIM, "rm")
    for v, s in xt:
        d.line([(X(v), gb), (X(v), gb + 10 * S)], fill=O.DIM, width=max(2, int(3 * S)))
        cap(d, (X(v), gb + 34 * S), s, 26, O.DIM, "mm")
    d.line([(gl, gb), (gr, gb)], fill=O.WHITE, width=max(2, int(4 * S)))
    d.line([(gl, gt), (gl, gb)], fill=O.WHITE, width=max(2, int(4 * S)))
    cap(d, (gr, gb + 72 * S), xlab, 28, O.DIM, "rm")
    cap(d, (gl - 10 * S, gt - 30 * S), ylab, 28, O.DIM, "lm")
    return X, Y, (gl, gt, gr, gb)


# ---- 速さが落ちていくグラフ(空気あり) --------------------------------------------------------------

def sc_decay(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    st = P.get("st", 1)
    X, Y, (gl, gt, gr, gb) = axes(d, box, (0, 10), (0, 11000), [(i, f"{i}m") for i in range(0, 11, 2)],
                                  [(v, f"{v:,}") for v in range(0, 11001, 2000)], "打った所からの距離", "時速（km）",
                                  pad=(150, 130, 90, 110) if LAND else (130, 150, 60, 120))
    a = _ease(k * 1.6) if st == 1 else 1.0
    pts = [(X(x / 10), Y(v_at(x / 10) * 3.6)) for x in range(0, int(100 * a) + 1)]
    if len(pts) > 1:
        d.line(pts, fill=(240, 90, 80), width=max(4, int(7 * S)), joint="curve")
    # 球が線の上を進む(t で回し続ける)
    q = (t % 3.0) / 3.0 * a
    ball(d, X(10 * q), Y(v_at(10 * q) * 3.6), 18 * S)
    fs = 34 if LAND else 30
    if st >= 2:
        dot(d, X(10), Y(5516), 12 * S, O.YEL, O.NAVY)
        text(d, (X(10) - 20 * S, Y(5516) + 50 * S), "相手の所　5,500km", fs, O.YEL, "rm", 5)
    if st >= 3:
        dot(d, X(0), Y(9966), 12 * S, O.YEL, O.NAVY)
        text(d, (X(0) + 30 * S, Y(9966) + 60 * S), "打った瞬間　少なくとも9,900km", fs, O.YEL, "lm", 5)
        text(d, (X(5), Y(1500)), "いちばん控えめなら　打った瞬間 4,300km以上", fs - 4, O.DIM, "mm", 4)
    head(d, box, "置いた値の真ん中・空気あり　10mで速さは半分ほどに")


# ---- 衝撃波 ---------------------------------------------------------------------------------------

def sc_shock(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    st = P.get("st", 0)
    cy = (y0 + y1) / 2 + 30 * S
    r = (70 if LAND else 80) * S
    if st >= 2:     # 通り道に衝撃波を残す(横切る)
        ph = (t % 2.5) / 2.5
        bx = x0 - r + (x1 - x0 + 2 * r) * ph
    else:
        bx = x0 + (x1 - x0) * (0.60 if LAND else 0.62)
    # 空気の粒(左へ流れる=球から見た空気)
    for i in range(60):
        yy = y0 + 120 * S + ((i * 97) % int(y1 - y0 - 160 * S))
        xx = x1 - ((t * 900 * S + i * 173) % (x1 - x0))
        dd = math.hypot(xx - bx, yy - cy)
        if st < 2 and xx > bx and dd < r * 2.2:
            continue
        d.ellipse([xx - 3 * S, yy - 3 * S, xx + 3 * S, yy + 3 * S], fill=(120, 150, 200))
    # 球の前の弓形の衝撃波
    pts_u, pts_d = [], []
    for j in range(0, 40):
        yy = j / 39 * (y1 - y0) * 0.45
        xx = bx + r * 1.35 - (yy / r) ** 1.6 * r * 0.55
        pts_u.append((xx, cy - yy))
        pts_d.append((xx, cy + yy))
    for pts in (pts_u, pts_d):
        d.line(pts, fill=(255, 230, 150), width=max(4, int(7 * S)))
    for s_ in range(6):      # 押し固められた空気の層
        rr = r * (1.06 + s_ * 0.05)
        d.arc([bx - rr, cy - rr, bx + rr, cy + rr], -60, 60, fill=mix((255, 150, 80), BG1, 1 - s_ / 7), width=max(2, int(4 * S)))
    ball(d, bx, cy, r)
    fs = 36 if LAND else 32
    if st == 0:
        label(d, ((x0 + x1) / 2, y0 + 56 * S), "空気が逃げきれずに　押し固められる", 38 if LAND else 32, O.WHITE)
    elif st == 1:
        label(d, ((x0 + x1) / 2, y0 + 56 * S), "レイリーの式　球の正面にかかる空気は　86気圧", 38 if LAND else 30, O.YEL)
        text(d, (bx + r * 1.7, cy - r * 1.6), "正面　86気圧", 48 if LAND else 44, O.YEL, "lm" if LAND else "mm", 6) if LAND else \
            text(d, (bx - r * 0.3, cy - r * 2.4), "正面　86気圧", 44, O.YEL, "mm", 6)
        cap(d, ((x0 + x1) / 2, y1 - 40 * S), "打った瞬間（時速9,900km・音の8倍）の　正面の1点", 28 if LAND else 26, O.DIM)
    else:
        label(d, ((x0 + x1) / 2, y0 + 56 * S), "音より速い球は　通り道に衝撃波を残す", 38 if LAND else 32, O.WHITE)
        if st >= 3:
            for i in range(3):
                q = (t * 1.2 + i / 3) % 1.0
                rr = r * (1.5 + 3 * q)
                d.ellipse([bx - rr, cy - rr, bx + rr, cy + rr], outline=mix((255, 214, 64), BG1, 1 - q), width=max(2, int(4 * S)))
            text(d, ((x0 + x1) / 2, y1 - 60 * S), "ドン　と　破裂のような音", 48 if LAND else 44, O.YEL, "mm", 6)


# ---- 圧力の比べ ------------------------------------------------------------------------------------

def sc_press(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    st = P.get("st", 0)
    vmax = 0.5 if st == 0 else 0.5 + (95 - 0.5) * _ease(k * 1.6)
    rows = [("バレーボールの中", 0.31, "まわりより 0.3気圧ほど高い", (140, 200, 240), False)]
    if st >= 1:
        rows.append(("球の正面", 85.8, "86気圧", (240, 90, 80), False))
    hbar_rows(d, box, rows, vmax, 1.0 if st == 0 else k, None, top_pad=170, grow_last=False)
    if st == 0:
        head(d, box, "バレーボールの規則　0.30〜0.325kg/cm²", O.WHITE)
    else:
        head(d, box, "およそ270倍の力で押される")
        if k > 0.6:
            text(d, ((x0 + x1) / 2, y1 - 50 * S), "ふつうの球なら　正面からぺしゃんこ", 46 if LAND else 40, O.RED, "mm", 6)


# ---- 熱 --------------------------------------------------------------------------------------------

def sc_heat(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    st = P.get("st", 0)
    if st == 0:
        cy = (y0 + y1) / 2 + 30 * S
        bx = (x0 + x1) / 2
        r = 110 * S
        for i in range(8):
            rr = r * (1.0 + 0.09 * i)
            c = mix((255, 120, 40), BG1, max(0.0, 0.9 - i * 0.11) * (0.8 + 0.2 * math.sin(t * 6 + i)))
            d.pieslice([bx - rr, cy - rr, bx + rr, cy + rr], -70, 70, fill=c)
        ball(d, bx, cy, r)
        d.pieslice([bx - r, cy - r, bx + r, cy + r], -55, 55, fill=(255, 110, 50))
        for i in range(5):
            yy = cy - r + i * r / 2
            xx = x1 - 60 * S - ((t * 500 * S + i * 90) % (220 * S))
            arrow(d, xx, yy, bx + r * 1.2, yy + (cy - yy) * 0.3, 6 * S, (255, 200, 140))
        label(d, ((x0 + x1) / 2, y0 + 56 * S), "せき止められた空気が　球の正面を焼く", 38 if LAND else 32, O.WHITE)
        return
    X, Y, (gl, gt, gr, gb) = axes(d, box, (0, 5.0), (0, 800), [(i, f"{i}") for i in range(0, 6)],
                                  [(v, f"{v}℃") for v in range(0, 801, 200)], "打ってからの時間（1000分の1秒）", "表面の温度",
                                  pad=(160, 130, 90, 110) if LAND else (140, 160, 60, 130))
    if st >= 2:
        d.rectangle([gl, Y(300), gr, Y(200)], fill=(70, 60, 90))
        text(d, (gr - 10 * S, (Y(300) + Y(200)) / 2), "ゴムが傷み始める 200〜300℃", 30 if LAND else 26, (230, 200, 255), "rm", 4)
    a = _ease(k * 1.5) if st == 1 else 1.0
    pts = [(X(tt * 1000), Y(T)) for tt, T in HEAT[: max(2, int(len(HEAT) * a))]]
    d.line(pts, fill=(255, 130, 60), width=max(4, int(7 * S)), joint="curve")
    fs = 32 if LAND else 28
    pk = max(HEAT, key=lambda p: p[1])
    if a > 0.6:
        dot(d, X(pk[0] * 1000), Y(pk[1]), 11 * S, O.YEL, O.NAVY)
        text(d, (X(pk[0] * 1000), Y(pk[1]) - 40 * S), "いちばん高いとき　670℃", fs, O.YEL, "mm", 5)
    if a > 0.95:
        te, Te = HEAT[-1]
        dot(d, X(te * 1000), Y(Te), 11 * S, O.YEL, O.NAVY)
        text(d, (X(te * 1000) - 10 * S, Y(Te) + 46 * S), "届くとき 600℃", fs, O.YEL, "rm", 5)
    head(d, box, "熱の流れの式（置いた値の真ん中・空気あり）")


# ---- 時間の目盛り ----------------------------------------------------------------------------------

def sc_time(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    st = P.get("st", 1)
    gl = x0 + (500 if LAND else 70) * S
    gr = x1 - 80 * S
    X = lambda v: gl + (gr - gl) * v / 0.25
    top = y0 + (170 if LAND else 220) * S
    for i in range(0, 6):
        v = i * 0.05
        d.line([(X(v), top - 10 * S), (X(v), y1 - 60 * S)], fill=GRID, width=max(1, int(2 * S)))
        cap(d, (X(v), top - 36 * S), "0" if i == 0 else f"{v:.2f}秒", 26, O.DIM, "md")
    rows = []
    if st >= 1:
        rows.append(("球が10m飛ぶ（真ん中）", 0.0049, "0.0049秒以下", (240, 90, 80)))
    if st >= 4:
        rows.append(("球が10m飛ぶ（控えめ）", 0.0112, "0.0112秒以下", (250, 165, 80)))
    if st >= 2:
        rows.insert(0, ("人が反応する", 0.2, "約0.2秒（0.18〜0.21秒）", (140, 200, 240)))
    pitch = (150 if LAND else 190) * S
    na = not LAND
    for i, (nm, v, s, col) in enumerate(rows):
        yc = top + pitch * (i + 0.6)
        bh = 56 * S
        if na:
            text(d, (gl, yc - bh / 2 - 14 * S), nm, 34, O.WHITE, "ld", 4)
        else:
            text(d, (gl - 20 * S, yc), nm, fsz(nm, 34, gl - x0 - 40 * S), O.WHITE, "rm", 4)
        grow = _ease(k * 1.8) if (i == len(rows) - 1 and P.get("grow")) else 1.0
        e = X(v * grow)
        d.rectangle([gl, yc - bh / 2, max(gl + 5 * S, e), yc + bh / 2], fill=col)
        if v > 0.05:
            d.rectangle([X(0.18), yc - bh / 2 - 6 * S, X(0.21), yc - bh / 2], fill=O.WHITE)
            text(d, (e + 14 * S, yc), s, 32, O.WHITE, "lm", 4) if e < X(0.205) else text(d, (gl + 20 * S, yc), s, 32, (20, 28, 50), "lm", 0)
        else:
            text(d, (max(gl + 5 * S, e) + 16 * S, yc), s, 32, O.WHITE, "lm", 4)
        if st >= 5 and v > 0.05:
            d.line([(gl, yc - bh), (X(0.2), yc + bh)], fill=O.RED, width=max(4, int(8 * S)))
    hd = {0: "球が相手まで10mを飛ぶ時間", 1: "置いた値の真ん中・空気あり", 2: "人が光を見てから動き出すまで", 3: "反応の　41分の1より短い",
          4: "いちばん控えめでも　18分の1より短い", 5: "見てから決める時間は　どこにもない"}[st]
    head(d, box, hd)
    if st == 0:
        text(d, ((x0 + x1) / 2, (top + y1) / 2), "球が飛ぶ時間は？", 80 if LAND else 70, O.YEL, "mm", 6)


# ---- 拳が球を打つ(衝突の式で動かす) ----------------------------------------------------------------

def punch_v(V, M, e, m=MB):
    """拳の速さ V・有効質量 M(None=無限大)・はね返り e → (球の速さ, 打ったあとの拳の速さ)"""
    if M is None:
        return (1 + e) * V, V
    vb = (1 + e) * M * V / (M + m)
    return vb, V - m * vb / M


def sc_punch(img, box, t, k, P):
    """横から見た図。拳(左)が止まった球に当たり、球が右へ飛ぶ。速さの比は式 v=(1+e)MV/(M+m) どおり(punch_mj.py で MuJoCo と一致)。"""
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    M, e = P.get("M", 2.9), P.get("e", 0.8)
    V = 9.14
    vb, vf = punch_v(V, M, e)
    cy = y0 + (y1 - y0) * (0.55 if LAND else 0.50)
    scale = (x1 - x0) * 0.022                   # 画面上の 1 m/s あたりの速さ(画素/秒)
    period = 3.2
    ph = t % period
    r_b = 54 * S
    bx0 = x0 + (x1 - x0) * 0.42
    fr = 48 * S
    t_hit = 1.1
    fx_start = bx0 - r_b - fr - V * scale * t_hit
    if ph < t_hit:
        fx = fx_start + V * scale * ph
        bx = bx0
    else:
        q = ph - t_hit
        fx = bx0 - r_b - fr + vf * scale * q
        bx = bx0 + vb * scale * q
    sq = 0.0
    if 0 < ph - t_hit < 0.08:
        sq = math.sin((ph - t_hit) / 0.08 * math.pi) * 0.25
    # 腕(太い線)と拳
    d.line([(x0 - 50 * S, cy + 30 * S), (fx - fr * 0.6, cy)], fill=(230, 200, 170), width=max(10, int(34 * S)))
    d.rounded_rectangle([fx - fr, cy - fr * 0.9, fx + fr, cy + fr * 0.9], int(fr * 0.4), fill=(240, 200, 170), outline=O.WHITE, width=max(2, int(3 * S)))
    if bx < x1 + r_b:
        rx, ry = r_b * (1 - sq), r_b * (1 + sq * 0.6)
        d.ellipse([bx - rx, cy - ry, bx + rx, cy + ry], fill=BALLC, outline=O.WHITE, width=max(2, int(3 * S)))
    fs = 36 if LAND else 32
    text(d, (x0 + (x1 - x0) * 0.20, cy - 130 * S), f"拳　秒速{V}m（時速33km）", fs, (240, 200, 170), "mm", 5)
    text(d, (x0 + (x1 - x0) * 0.74, cy - 130 * S), P.get("ball_txt", "球　時速44〜53km"), fs, (255, 200, 120), "mm", 5)
    mtxt = "拳の重さ　∞（体重を全部乗せる）" if M is None else f"拳の重さ（有効質量）　{M}kg"
    cap(d, (x0 + (x1 - x0) * 0.30, cy + 140 * S), mtxt, 30 if LAND else 28, O.DIM)
    cap(d, (x0 + (x1 - x0) * 0.30, cy + 190 * S), f"この絵は はね返り{e}　球 = 拳の{vb / V:.2f}倍", 30 if LAND else 28, O.DIM)
    label(d, ((x0 + x1) / 2, y0 + 56 * S), P.get("head", "仮置き　はね返り0.5〜0.8　球330g"), 36 if LAND else 32, P.get("hcol", O.RED))


# ---- 頭打ちのグラフ --------------------------------------------------------------------------------

def sc_cap(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    st = P.get("st", 0)
    X, Y, (gl, gt, gr, gb) = axes(d, box, (0, 20), (0, 2.2), [(v, f"{v}kg") for v in range(0, 21, 5)],
                                  [(v / 10, f"{v / 10:g}倍") for v in range(0, 23, 5)], "拳の重さ", "球の速さ ÷ 拳の速さ",
                                  pad=(160, 140, 90, 110) if LAND else (140, 170, 60, 130))
    a = _ease(k * 1.5) if st == 0 else 1.0
    for e, col in ((0.8, (240, 90, 80)), (0.5, (250, 165, 80))):
        lim = 1 + e
        dash(d, (gl, Y(lim)), (gr, Y(lim)), mix(col, BG1, 0.7), 4)
        pts = [(X(m / 10), Y(lim * (m / 10) / (m / 10 + MB))) for m in range(1, int(200 * a) + 1)]
        if len(pts) > 1:
            d.line(pts, fill=col, width=max(4, int(6 * S)), joint="curve")
        text(d, (gr - 10 * S, Y(lim) - 28 * S), f"はね返り{e}　{lim:g}倍で頭打ち", 30 if LAND else 26, col, "rm", 4)
    if a > 0.3:
        dot(d, X(2.9), Y(1.8 * 2.9 / 3.23), 10 * S, O.WHITE, O.NAVY)
        text(d, (X(2.9) + 20 * S, Y(1.8 * 2.9 / 3.23) + 40 * S), "ボクサーの拳 2.9kg", 28 if LAND else 26, O.WHITE, "lm", 4)
    if st >= 1:
        d.line([(gl, Y(2.0)), (gr, Y(2.0))], fill=O.WHITE, width=max(2, int(3 * S)))
        text(d, (gl + 20 * S, Y(2.0) - 28 * S), "動く壁でも　壁の速さの2倍まで", 30 if LAND else 26, O.WHITE, "lm", 4)
    head(d, box, P.get("head", "球は　拳の速さの1.8倍で頭打ち（はね返り0.8まで）"))


# ---- 表(式と動きの計算) ----------------------------------------------------------------------------

MJ_ROWS = [("9.14", "2.9", "0.787", "52.8", "52.8"), ("9.14", "2.9", "0.506", "44.5", "44.5"),
           ("9.14", "1000（壁）", "0.787", "58.8", "58.8"), ("9.14", "1000（壁）", "0.506", "49.5", "49.5"),
           ("13.30", "1000（壁）", "0.787", "85.6", "85.5")]


def sc_table(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    hdr = ("拳の速さ m/s", "拳の重さ kg", "はね返り", "動きの計算", "式")
    cols = [0.13, 0.33, 0.52, 0.70, 0.88] if LAND else [0.12, 0.33, 0.53, 0.72, 0.90]
    top = y0 + 150 * S
    pitch = min(100 * S, (y1 - top - 80 * S) / (len(MJ_ROWS) + 1))
    fs = 32 if LAND else 24
    for j, h in enumerate(hdr):
        text(d, (x0 + (x1 - x0) * cols[j], top), h, fs, O.YEL, "mm", 4)
    d.line([(x0 + 40 * S, top + pitch * 0.5), (x1 - 40 * S, top + pitch * 0.5)], fill=O.DIM, width=2)
    for i, r in enumerate(MJ_ROWS):
        a = _ease(k * 3 - i * 0.4)
        if a <= 0:
            continue
        yy = top + pitch * (i + 1)
        for j, v in enumerate(r):
            s = v + (" km/h" if j >= 3 else "")
            text(d, (x0 + (x1 - x0) * cols[j], yy), s, fs + 2, mix(O.WHITE, BG1, a), "mm", 4)
    label(d, ((x0 + x1) / 2, y0 + 56 * S), "式と動きの計算（MuJoCo）　32通りで時速0.1km以内", 36 if LAND else 28, O.WHITE)
    text(d, ((x0 + x1) / 2, y1 - 40 * S), "効くのは　拳の重さではなく　拳の速さ", 40 if LAND else 34, O.YEL, "mm", 5)


# ---- 投手の重い球(Fleisig ほか 2017) -----------------------------------------------------------------

PITCH = [(113, 35.4), (142, 34.2), (170, 33.1), (198, 31.9)]     # 球の重さ g・手から離れる速さ m/s(実測)


def v_pitch(g):
    return math.sqrt(460.4 / (0.254 + g / 1000))       # (腕の有効質量＋球)×速さ² ＝ 一定 で 4oz・7oz に合わせた式


def sc_pitch(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    st = P.get("st", 0)
    X, Y, (gl, gt, gr, gb) = axes(d, box, (0, 360), (0, 140), [(v, f"{v}g") for v in (0, 100, 200, 300)],
                                  [(v, f"{v}") for v in range(0, 141, 20)], "球の重さ", "時速（km）",
                                  pad=(150, 140, 80, 110) if LAND else (120, 170, 50, 130))
    bw = 22 * S
    for g, v in PITCH:
        a = _ease(k * 2) if st == 0 else 1.0
        yy = Y(v * 3.6 * a)
        d.rectangle([X(g) - bw, yy, X(g) + bw, gb], fill=(140, 200, 240))
        if a > 0.8:
            cap(d, (X(g), yy - 24 * S), f"{v * 3.6:.0f}", 26, O.WHITE, "mm")
    if st >= 1:
        a = _ease(k * 1.6) if st == 1 else 1.0
        g1 = 198 + (330 - 198) * a
        pts = [(X(g), Y(v_pitch(g) * 3.6)) for g in range(100, int(g1) + 1, 4)]
        d.line(pts[: len(pts)], fill=(250, 165, 80), width=max(3, int(5 * S)))
        dash(d, (X(198), Y(v_pitch(198) * 3.6) - 20 * S), (X(g1), Y(v_pitch(g1) * 3.6) - 20 * S), (250, 165, 80), 3)
        if a > 0.8:
            text(d, (X(260), Y(126)), "式の延長", 34 if LAND else 30, O.RED, "mm", 5)
    if st >= 2:
        d.rectangle([X(330) - bw, Y(102), X(330) + bw, gb], fill=mix((250, 165, 80), BG1, 0.5), outline=(250, 165, 80), width=max(2, int(3 * S)))
        text(d, (X(330), Y(102) - 70 * S), "330g", 34 if LAND else 30, O.WHITE, "mm", 5)
        text(d, (X(330) - 10 * S, Y(102) - 30 * S), "時速96〜102km", 32 if LAND else 28, (250, 165, 80), "rm", 5)
    head(d, box, "高校と大学の投手25人　重い球ほど遅くなる（113g〜198gを実測）", O.WHITE)


# ---- 横棒(汎用) ------------------------------------------------------------------------------------

def sc_bars(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    rows = [(n, v, s, c, False) for n, v, s, c in P["rows"]]
    hbar_rows(d, box, rows, P["vmax"], k, None, top_pad=160, grow_last=P.get("grow", True))
    if P.get("head"):
        head(d, box, P["head"], P.get("hcol", O.YEL))
    if P.get("foot"):
        text(d, ((x0 + x1) / 2, y1 - 50 * S), P["foot"], 44 if LAND else 38, O.YEL, "mm", 6)


# ---- 人間チームの挑戦 -------------------------------------------------------------------------------

HUMAN = [("拳で打つ", 53, None), ("速い拳＋体重を全部", 86, None), ("投手が投げる", 102, None), ("バレーのスパイク", 110, None),
         ("メジャーリーグ最速", 141, 170.3), ("ハンドボール（欧州選手権）", 147, 134.1)]


def sc_human(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    n = P.get("n", 1)
    raw = P.get("raw")          # 直す前の記録を出す行(4 か 5)
    fix = P.get("fix")          # 直す前→直したあとへ動かす行
    gon = P.get("gon", False)
    vmax = 220
    top = y0 + 140 * S
    nrow = 7.6
    pitch = (y1 - top - 40 * S) / nrow
    na = not LAND
    gl = x0 + (430 if LAND else 60) * S
    gr = x1 - 80 * S
    px = lambda v: gl + (gr - gl) * v / vmax
    bh = pitch * (0.46 if LAND else 0.32)
    for v in (0, 50, 100, 150, 200):  # 目盛り
        d.line([(px(v), top), (px(v), top + pitch * nrow)], fill=GRID, width=max(1, int(2 * S)))
        cap(d, (px(v), top - 18 * S), f"{v}", 24, O.DIM, "md")
    cap(d, (gr, top - 18 * S), "時速（km）", 24, O.DIM, "rd") if False else None
    if P.get("band"):
        d.rectangle([px(130), top, px(150), top + pitch * 6], fill=(70, 70, 100))
        text(d, (px(140), top + pitch * (7 if gon else 6) + 26 * S), "人間の限界 130〜150km", 30 if LAND else 26, (230, 200, 255), "mm", 4)
    fs = 34 if LAND else 30
    for i in range(min(n, 6)):
        name, val, rv = HUMAN[i]
        yc = top + pitch * (i + 0.5) + (12 * S if na else 0)
        if na:
            text(d, (gl, yc - bh / 2 - 10 * S), name, 30, O.WHITE, "ld", 4)
        else:
            text(d, (gl - 20 * S, yc), name, fsz(name, fs, gl - x0 - 40 * S), O.WHITE, "rm", 4)
        last = i == n - 1
        v = val
        sub = ""
        if rv is not None and raw == i:
            v = rv
            sub = "（145g）" if i == 4 else "（450g）"
        elif rv is not None and fix == i:
            v = rv + (val - rv) * _ease(k * 1.6)
        a = _ease(k * 1.8) if (last and fix != i and not gon and P.get("grow", True)) else 1.0
        e = px(v * a)
        col = (140, 200, 240) if i < 4 else (110, 220, 140)
        d.rectangle([gl, yc - bh / 2, e, yc + bh / 2], fill=col)
        if a > 0.6:
            text(d, (e + 12 * S, yc), f"{v:.1f}km{sub}" if (rv is not None and raw == i) else f"{v:.0f}km", fs - 2, O.WHITE, "lm", 4)
    if gon:
        yc = top + pitch * 6.5 + (12 * S if na else 0)
        if na:
            text(d, (gl, yc - bh / 2 - 10 * S), "ゴンの一球（いちばん控えめ）", 30, O.YEL, "ld", 4)
        else:
            text(d, (gl - 20 * S, yc), "ゴン（控えめ）", fs, O.YEL, "rm", 4)
        a = _ease(k * 1.4)
        e = gl + (x1 + 400 * S - gl) * a
        d.rectangle([gl, yc - bh / 2, e, yc + bh / 2], fill=(240, 90, 80))
        if a > 0.7:
            text(d, ((gl + gr) / 2, yc), "少なくとも 2,420km　→ 画面に収まらない", fs, O.WHITE, "mm", 5)
    head(d, box, P.get("head", "人間チームの挑戦　目標は 時速2,420km"))


# ---- 腕を引いて止める ---------------------------------------------------------------------------------

def sc_arm(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    hl = P.get("hl", 30)
    panels = [(30, "1.0", "約1キロニュートン"), (10, "2.9", "2.9キロニュートン")]
    n = len(panels)
    for i, (cm, kn, _) in enumerate(panels):
        if LAND:
            px0, px1 = x0 + (x1 - x0) * i / n, x0 + (x1 - x0) * (i + 1) / n
            py0, py1 = y0 + 110 * S, y1
        else:
            px0, px1 = x0, x1
            py0, py1 = y0 + 110 * S + (y1 - y0 - 110 * S) * i / n, y0 + 110 * S + (y1 - y0 - 110 * S) * (i + 1) / n
        on = cm == hl
        cy = (py0 + py1) / 2 + 20 * S
        L = (px1 - px0) * 0.0028 * cm * 1.25 * 100 / 100 * (1 if LAND else 1.3)
        ph = (t % 2.6) / 2.6
        pull = _ease(ph / 0.5) if ph < 0.5 else 1.0
        hx0 = px0 + (px1 - px0) * 0.62
        hx = hx0 - L * 3.4 * pull * (1 if True else 0)
        sx = px0 + (px1 - px0) * 0.85            # 肩
        col = O.WHITE if on else mix(O.WHITE, BG1, 0.45)
        d.line([(sx, cy - 30 * S), (hx + 30 * S, cy)], fill=col, width=max(8, int(20 * S)))
        ball(d, hx, cy, 40 * S, BALLC if on else mix(BALLC, BG1, 0.45))
        bx_l, bx_r = hx0 - L * 3.4, hx0
        d.line([(bx_l, cy + 80 * S), (bx_r, cy + 80 * S)], fill=O.YEL if on else O.DIM, width=max(3, int(5 * S)))
        for xx in (bx_l, bx_r):
            d.line([(xx, cy + 66 * S), (xx, cy + 94 * S)], fill=O.YEL if on else O.DIM, width=max(3, int(5 * S)))
        text(d, ((bx_l + bx_r) / 2, cy + 126 * S), f"{cm}cm引く" if cm == 30 else f"{cm}cmで止める", 34, O.YEL if on else O.DIM, "mm", 5)
        text(d, ((px0 + px1) / 2, py0 + 40 * S), f"平均の力　{kn}kN", 46 if LAND else 40, O.YEL if on else O.DIM, "mm", 6)
    label(d, ((x0 + x1) / 2, y0 + 50 * S), "時速150kmの球を　腕を引きながら止める", 36 if LAND else 32, O.WHITE)


# ---- 骨の札 -----------------------------------------------------------------------------------------

def sc_bone(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    st = P.get("st", 0)
    cy = (y0 + y1) / 2 + (20 if LAND else -60) * S
    ex, wx = x0 + (x1 - x0) * 0.12, x0 + (x1 - x0) * (0.70 if LAND else 0.78)
    sk = (88, 70, 60)
    d.rounded_rectangle([ex - 40 * S, cy - 110 * S, wx + 40 * S, cy + 110 * S], int(100 * S), fill=(70, 58, 56))
    # 手(記号)
    d.ellipse([wx + 10 * S, cy - 90 * S, wx + 200 * S, cy + 90 * S], fill=(70, 58, 56))
    d.ellipse([wx + 30 * S, cy - 150 * S, wx + 110 * S, cy - 70 * S], fill=(70, 58, 56))      # 親指(上)
    ulna = [(ex, cy + 40 * S), (wx, cy + 50 * S)]
    radius = [(ex + 40 * S, cy - 30 * S), (wx, cy - 50 * S)]
    d.line(ulna, fill=(200, 200, 205), width=max(10, int(30 * S)))
    glow = 0.6 + 0.4 * math.sin(t * 3)
    d.line(radius, fill=mix((255, 214, 64), (200, 200, 205), glow), width=max(12, int(38 * S)))
    fs = 40 if LAND else 36
    text(d, ((ex + wx) / 2, cy - 160 * S), "橈骨（親指側の腕の骨）", fs, O.YEL, "mm", 6)
    text(d, ((ex + wx) / 2, cy + 130 * S), "尺骨", 30, O.DIM, "mm", 4)
    text(d, (wx + 120 * S, cy + 140 * S), "手首", 30, O.DIM, "mm", 4)
    text(d, (wx + 70 * S, cy - 190 * S), "親指", 30, O.DIM, "mm", 4)
    if st >= 1:
        xc = wx - 70 * S
        d.line([(xc, cy - 90 * S), (xc + 22 * S, cy - 50 * S), (xc - 10 * S, cy - 30 * S), (xc + 16 * S, cy - 4 * S)], fill=O.RED, width=max(4, int(8 * S)))
        label(d, ((x0 + x1) / 2, y1 - 60 * S), "献体の実験　1.6〜3.4kNで折れた", 40 if LAND else 34, O.RED)
    label(d, ((x0 + x1) / 2, y0 + 50 * S), "比べるのは　手首の親指側の骨", 36 if LAND else 32, O.WHITE)


# ---- 力の比べ(折れる力の帯) ----------------------------------------------------------------------------

def sc_fbar(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    st = P.get("st", 0)
    gl = x0 + (420 if LAND else 70) * S
    gr = x1 - 80 * S
    X = lambda v: gl + (gr - gl) * v / 4.0
    top = y0 + 190 * S
    bottom = y1 - 110 * S
    d.rectangle([X(1.6), top - 30 * S, X(3.4), bottom], fill=(110, 50, 60))
    text(d, (X(2.5), bottom + 36 * S), "橈骨が折れる力 1.6〜3.4kN", 32 if LAND else 28, (255, 170, 160), "mm", 4)
    for v in range(0, 5):
        cap(d, (X(v), top - 54 * S), f"{v}kN", 26, O.DIM, "mm")
        d.line([(X(v), top - 30 * S), (X(v), bottom)], fill=GRID, width=1)
    rows = [("30cm引いて止める", 1.0, "約1kN")]
    if st >= 1:
        rows.append(("10cmで止める", 2.9, "2.9kN"))
    pitch = (bottom - top) / 2
    for i, (nm, v, s) in enumerate(rows):
        yc = top + pitch * (i + 0.5)
        bh = 60 * S
        a = _ease(k * 1.8) if (i == len(rows) - 1 and st == P.get("grow_st", -1)) else 1.0
        if LAND:
            text(d, (gl - 20 * S, yc), nm, 34, O.WHITE, "rm", 4)
        else:
            text(d, (gl, yc - bh / 2 - 14 * S), nm, 32, O.WHITE, "ld", 4)
        e = X(v * a)
        d.rectangle([gl, yc - bh / 2, e, yc + bh / 2], fill=(140, 200, 240) if v < 1.6 else (250, 165, 80))
        text(d, (e + 14 * S, yc), s, 34, O.WHITE, "lm", 5)
    head(d, box, "止めるあいだの平均の力（時速150kmの球）" if st == 0 else "手首1本で受けたら　折れる力に届く")


# ---- 捕った選手が滑る ---------------------------------------------------------------------------------

def sc_slide(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    floor = y1 - (110 if LAND else 190) * S
    d.rectangle([x0 + 30 * S, floor, x1 - 30 * S, floor + 24 * S], fill=(110, 84, 62))
    line_x = x0 + (x1 - x0) * 0.62
    dash(d, (line_x, floor - 520 * S), (line_x, floor + 20 * S), O.RED, 7)
    text(d, (line_x + 16 * S, floor - 500 * S), "線", 34, O.RED, "la", 5)
    ph = (t % 3.0) / 3.0
    start = x0 + (x1 - x0) * 0.22
    px = start + (x1 - start + 200 * S) * (ph ** 0.8)
    figure(d, px, floor, 330 * S, (230, 235, 245), pose="catch", lean=-0.4)
    for j in range(1, 6):
        d.line([(px - 80 * S - j * 40 * S, floor - 260 * S + j * 30 * S), (px - 30 * S - j * 40 * S, floor - 260 * S + j * 30 * S)], fill=(150, 160, 190), width=3)
    label(d, ((x0 + x1) / 2, y0 + 56 * S), "捕った選手は　1秒たたずに　線の外へ", 38 if LAND else 32, O.YEL)


# ---- 拳の速さの帯(m/s) ----------------------------------------------------------------------------------

def sc_fist(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    st = P.get("st", 1)
    rows = [("五輪ボクサーの拳", 9.14, "秒速9.14m", (190, 195, 205), False)]
    if st >= 1:
        rows.append(("ゴンの拳（控えめ・空気なし）", 374, "少なくとも 秒速370m", (250, 165, 80), True))
    if st >= 2:
        rows.append(("ゴンの拳（控えめ・空気あり）", 676, "少なくとも 秒速670m", (240, 90, 80), True))
    px, top, pitch = hbar_rows(d, box, rows, 800, k, None, top_pad=170, grow_last=True)
    xs = px(340)
    dash(d, (xs, top - 20 * S), (xs, top + pitch * len(rows)), (140, 200, 240), 5)
    text(d, (xs, top - 40 * S), "音の速さ 秒速約340m", 30 if LAND else 26, (140, 200, 240), "mm", 4)
    hd = {1: "音より速い拳（はね返り0.8までの場合）", 2: "音のほぼ2倍　五輪ボクサーの70倍超"}[st]
    head(d, box, hd)


# ---- 拳と球がつぶれる ----------------------------------------------------------------------------------

def sc_squash(img, box, t, k, P):
    """拳(左の塊)が球を押しつぶし、はね返す。押しつけている時間は ばねの半周期 π×つぶれ÷拳の速さ(0.465ms)。力は半分の正弦波。"""
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    st = P.get("st", 0)
    period = 3.0
    ph = (t % period) / period
    R = (130 if LAND else 140) * S
    cx = x0 + (x1 - x0) * (0.42 if LAND else 0.55)
    cy = y0 + (y1 - y0) * (0.47 if LAND else 0.36)
    c0, c1 = 0.30, 0.62               # 接している区間(ゆっくり見せる)
    if ph < c0:
        squash = 0.0
        fx = cx - R - (1 - ph / c0) * 260 * S
        bx = cx
    elif ph < c1:
        q = (ph - c0) / (c1 - c0)
        squash = math.sin(q * math.pi)
        fx = cx - R + squash * R * 0.95
        bx = cx + (q - 0.5) * R * 0.6 if q > 0.5 else cx
    else:
        q = (ph - c1) / (1 - c1)
        squash = 0.0
        fx = cx - R + 0.0 - q * 40 * S
        bx = cx + R * 0.3 + q * (x1 - cx + R)
    depth = squash * R * 0.95
    # 球(左がつぶれた楕円)
    lim = x0 + (x1 - x0) * 0.62 if (LAND and st >= 2) else x1
    if bx + R < lim:
        left = fx
        right = bx + R
        top_, bot_ = cy - R * (1 + 0.18 * squash), cy + R * (1 + 0.18 * squash)
        d.ellipse([min(left, right - 20 * S) - (0 if squash > 0 else 0), top_, right, bot_], fill=BALLC, outline=O.WHITE, width=max(2, int(3 * S))) if squash > 0 else \
            d.ellipse([bx - R, cy - R, bx + R, cy + R], fill=BALLC, outline=O.WHITE, width=max(2, int(3 * S)))
    d.rounded_rectangle([fx - 230 * S, cy - 110 * S, fx, cy + 110 * S], int(40 * S), fill=(240, 200, 170), outline=O.WHITE, width=max(2, int(3 * S)))
    fs = 34 if LAND else 30
    if st >= 1:
        y_b = cy + R * 1.35
        hbracket(d, cx - R, cx - R + R * 0.95, y_b, "いちばん深いつぶれ 10cm", O.YEL, fs, up=False)
    # 力の時間の形(半分の正弦波)
    if st >= 2:
        gx0, gx1 = (x0 + (x1 - x0) * 0.66, x1 - 60 * S) if LAND else (x0 + 120 * S, x1 - 120 * S)
        gy1 = (y0 + (y1 - y0) * 0.78) if LAND else (y1 - 90 * S)
        gh = (220 if LAND else 200) * S
        d.line([(gx0, gy1), (gx1, gy1)], fill=O.WHITE, width=max(2, int(3 * S)))
        pts = [(gx0 + (gx1 - gx0) * (0.1 + 0.8 * i / 40), gy1 - gh * math.sin(math.pi * i / 40)) for i in range(41)]
        d.line(pts, fill=(240, 90, 80), width=max(3, int(5 * S)))
        hbracket(d, pts[0][0], pts[-1][0], gy1 + 30 * S, "0.465ms（約0.0005秒）", O.YEL, fs - 4, up=False)
        text(d, ((gx0 + gx1) / 2, gy1 - gh - 34 * S), "拳が受ける力", fs - 4, O.WHITE, "mm", 4)
        if st >= 3:
            d.line([(pts[0][0], gy1 - gh * 2 / math.pi), (pts[-1][0], gy1 - gh * 2 / math.pi)], fill=O.YEL, width=max(2, int(3 * S)))
            text(d, (pts[-1][0] - 6 * S, gy1 - gh * 2 / math.pi - 26 * S), "平均 0.86MN", fs - 6, O.YEL, "rm", 4)
    hd = {0: "拳が当たると　球はばねのようにつぶれて　はね返る", 1: "仮置き　いちばん深いつぶれ 10cm", 2: "ばねの半周期　押しつけるのは 0.0005秒ほど",
          3: "拳が受ける力　平均で約90トン（0.86MN）"}[st]
    head(d, box, hd, O.RED if st == 1 else O.YEL)


# ---- 反動 -----------------------------------------------------------------------------------------------

def sc_recoil(img, box, t, k, P):
    x0, y0, x1, y1 = box
    grad(img, box=box)
    d = ImageDraw.Draw(img)
    st = P.get("st", 0)
    floor = y1 - (130 if LAND else 220) * S
    d.rectangle([x0 + 30 * S, floor, x1 - 30 * S, floor + 24 * S], fill=(110, 84, 62))
    ph = (t % 3.4) / 3.4
    start = x0 + (x1 - x0) * (0.62 if LAND else 0.70)
    slide = (x1 - x0) * (0.40 if LAND else 0.50)
    q = 0.0 if ph < 0.15 else 1 - (1 - min(1.0, (ph - 0.15) / 0.65)) ** 2
    gx = start - slide * q
    hfig = (320 if LAND else 340) * S
    figure(d, gx, floor, hfig, GON, pose="punch", lean=0.2)
    bxp = start + hfig * 0.55 + (x1 - start) * min(1.0, max(0.0, ph - 0.15) * 6)
    if bxp < x1 - 20 * S:
        ball(d, bxp, floor - hfig * 0.78, 26 * S)
    fs = 36 if LAND else 32
    if st < 3:
        cap(d, (gx, floor + 60 * S), "ゴン（記号）", 28, O.DIM)
    if st >= 1:
        ay = floor - hfig - 60 * S
        arrow(d, start + 40 * S, ay, start + 240 * S, ay, 9 * S, (255, 200, 120))
        arrow(d, start - 40 * S, ay, start - 240 * S, ay, 9 * S, O.YEL)
        text(d, (start + 140 * S, ay - 44 * S), "球の勢い", fs - 4, (255, 200, 120), "mm", 5)
        text(d, (start - 140 * S, ay - 44 * S), "同じだけ", fs - 4, O.YEL, "mm", 5)
    if st >= 2:
        text(d, (x0 + (x1 - x0) * 0.30, y0 + 160 * S), "49kgの体に　時速29km（秒速8.19m）", 44 if LAND else 38, O.YEL, "mm", 6)
    if st >= 3:
        hbracket(d, start - slide, start, floor + 110 * S, "", O.YEL)
        text(d, (start - slide / 2, floor + 150 * S), "5.7m滑る（摩擦0.6は仮置き）", fs - 2, O.YEL, "mm", 5) if not LAND else \
            text(d, (start - slide / 2, floor + 74 * S), "5.7m滑る（摩擦0.6は仮置き）", fs - 2, O.YEL, "mm", 5)
    label(d, ((x0 + x1) / 2, y0 + 56 * S), "打った反動も　ゴンの体に返ってくる", 38 if LAND else 32, O.WHITE)


KINDS = dict(formula=sc_formula, court=sc_court, cart=sc_cart, floor=sc_floor, grid=sc_grid, speed=sc_speed, wind=sc_wind, decay=sc_decay,
             shock=sc_shock, press=sc_press, heat=sc_heat, time=sc_time, punch=sc_punch, cap=sc_cap, table=sc_table, pitch=sc_pitch,
             bars=sc_bars, human=sc_human, arm=sc_arm, bone=sc_bone, fbar=sc_fbar, slide=sc_slide, fist=sc_fist, squash=sc_squash,
             recoil=sc_recoil)


def region(P):
    return (0, 100, W, 880) if LAND else (0, 240, W, 1370)


def paint(sc, t, k):
    img = Image.new("RGBA", (W, H), BG0 + (255,))
    KINDS[sc["kind"]](img, region(sc), t, k, sc)
    return img


def draw(img, dr, t, ctx):
    lines, defs = ctx["lines"], ctx["defs"]
    scs = ctx.setdefault("_scenes", mapscene.scenes(lines, defs))
    cur = ctx["cur"] or lines[0]
    i = next(j for j, l in enumerate(lines) if l["id"] == cur["id"])
    now, prev = scs[i], (scs[i - 1] if i > 0 else None)
    k = ctx["k"]
    if prev is now:      # 前の行から引き継いだ図は、描き直さずそのまま見せる(動きは t で続く)
        k = 1.0
    u = _ease((t - cur["start"]) / 0.5)
    b = paint(prev, t, 1.0) if prev is not None and prev is not now and u < 1 else None
    O.BOXES.clear()
    a = paint(now, t, k)
    if b is not None:
        a = Image.blend(b, a, u)
    z = 1.0 + 0.03 * (0.5 + 0.5 * math.sin(2 * math.pi * t / 12.0))     # ゆっくり寄って引く(画面を止めない)
    zw, zh = int(W * z), int(H * z)
    a = a.resize((zw, zh), Image.BILINEAR).crop(((zw - W) // 2, (zh - H) // 2, (zw - W) // 2 + W, (zh - H) // 2 + H))
    img.paste(a, (0, 0))


def sfx_for(lines_def, L):
    return sorted(mapscene.sfx(lines_def, L))
