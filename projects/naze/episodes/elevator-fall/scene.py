"""落ちるエレベーターの回(計算の回)の画面。行の scene=dict(kind=…) を描く(無い行は前の行を引き継ぐ)。
場面が変わると 0.5 秒で溶け合わせる。実機・事故の写真は使わない。図は全部コードで描く。
数字の出どころは sim/calc.txt と research.md。台本は scripts.md。

kind: formula(札) / shaft(昇降路・かご・人形。mode は MODES) / bars(横棒) / floors(何階ぶんの建物) / car(車と壁) /
      kei(軽自動車を積む) / ground_jump(地上と箱の中の跳び) / window(蹴り始めの窓の帯) / cue(合図は底の10m手前) /
      egg(卵を受ける) / lineup(9回ぶんの人形) / esb(1945年のビル) / air(空気とケーブル) / gov(ロープ・調速機・非常止め) /
      door_gap(扉のすき間の奥のレール) / twodoll(伸びた脚と曲げた膝)

人形の動きは見せるための形(スロー)。数字は札にだけ出し、札の数字は全部 calc.txt の値。
"""
from __future__ import annotations

import math

from PIL import Image, ImageDraw

from naze import overlay as O
from naze.config import H, W

LAND = W > H
S = min(W, H) / 1080
COLS = dict(dim=O.DIM, white=O.WHITE, yel=O.YEL, red=O.RED, green=O.GREEN)
BG0, BG1 = (10, 18, 40), (16, 30, 62)
SHAFT = (24, 30, 44)
STEEL = (120, 130, 150)
GLASS = (150, 200, 240)
DOLL = (226, 228, 234)
DOLL2 = (180, 184, 196)
GREY = (170, 178, 192)
GRN = (110, 220, 140)
RED_ = (240, 90, 80)
ORG = (240, 150, 40)
CLAW = (255, 196, 40)

TI = 2.0      # 落とす場面で床に当たる時刻(場面の頭から。見せるための時間)


def _ease(u):
    u = max(0.0, min(1.0, u))
    return u * u * (3 - 2 * u)


def lerp(a, b, u):
    return a + (b - a) * u


def mix(c, bg, a):
    return tuple(int(c[i] * a + bg[i] * (1 - a)) for i in range(3))


def grad(img, top=BG0, bot=BG1, box=None):
    x0, y0, x1, y1 = box or (0, 0, W, H)
    d = ImageDraw.Draw(img)
    n = int(y1 - y0)
    for i in range(0, n, 2):
        u = i / max(1, n)
        d.rectangle([x0, y0 + i, x1, y0 + i + 2], fill=tuple(int(top[j] + (bot[j] - top[j]) * u) for j in range(3)))


def text(d, xy, s, size, col=O.WHITE, anchor="la", stroke=5):
    d.text(xy, s, font=O.font(int(size * S)), fill=col, anchor=anchor, stroke_width=stroke, stroke_fill=O.NAVY)


def fitsize(s, size, maxw):
    sz = size
    while O.font(int(sz * S)).getlength(s) > maxw and sz > 22:
        sz -= 2
    return sz


def vtext(d, xy, s, size, col=O.WHITE, anchor="mm", maxw=None, stroke=4):
    if maxw:
        size = fitsize(s, size, maxw)
    text(d, xy, s, size, col, anchor, stroke)


def label(d, xy, s, size=40, col=O.WHITE, anchor="mm", maxw=None):
    """白い字の小さな札(箱つき)。重なりの点検に載せる。"""
    if maxw:
        size = fitsize(s, size, maxw)
    f = O.font(int(size * S))
    bb = d.textbbox(xy, s, font=f, anchor=anchor)
    pad = 12 * S
    box = (bb[0] - pad, bb[1] - pad * 0.7, bb[2] + pad, bb[3] + pad * 0.7)
    d.rounded_rectangle(box, int(10 * S), fill=O.NAVY + (220,), outline=col, width=max(2, int(3 * S)))
    d.text(xy, s, font=f, fill=col, anchor=anchor)
    O.BOXES.append(("label", box, s, 1.0))


def head(d, box, s, col=O.YEL, size=44):
    x0, y0, x1, y1 = box
    label(d, ((x0 + x1) / 2, y0 + 50 * S), s, size, col, maxw=(x1 - x0) - 80 * S)


def big_label(img, xy, s, col=O.YEL, size=110, u=1.0):
    """当たったあとの大きな札。大きく出て、すっと落ち着く。"""
    sz = int(size * S)
    f = O.font(sz)
    pad = int(26 * S)
    tw = int(f.getlength(s))
    lay = Image.new("RGBA", (tw + pad * 2, sz + pad * 2), (0, 0, 0, 0))
    ld = ImageDraw.Draw(lay)
    ld.rounded_rectangle([3, 3, lay.width - 4, lay.height - 4], int(22 * S), fill=(8, 16, 36, 235), outline=col, width=int(8 * S))
    ld.text((lay.width / 2, lay.height / 2 - int(4 * S)), s, font=f, fill=col, anchor="mm")
    sc = 1.0 + 0.35 * (1 - _ease(u * 3))
    lay = lay.resize((max(1, int(lay.width * sc)), max(1, int(lay.height * sc))), Image.LANCZOS)
    x, y = xy
    img.alpha_composite(lay, (int(x - lay.width / 2), int(y - lay.height / 2)))
    O.BOXES.append(("label", (x - lay.width / 2, y - lay.height / 2, x + lay.width / 2, y + lay.height / 2), s, 1.0))


def arrow(d, p0, p1, col, w=5):
    d.line([p0, p1], fill=col, width=max(2, int(w * S)))
    ang = math.atan2(p1[1] - p0[1], p1[0] - p0[0])
    hl = 22 * S
    for s in (-1, 1):
        a = ang + math.pi + s * 0.45
        d.line([p1, (p1[0] + hl * math.cos(a), p1[1] + hl * math.sin(a))], fill=col, width=max(2, int(w * S)))


# ---- 人形 -------------------------------------------------------------------------------------

LEG, THIGH, TORSO, HEADR = 0.46, 0.45, 0.52, 0.11


def pose(knee=0.0, lean=0.0, arm=20.0, tip=0.0, elbow=20.0):
    return dict(knee=knee, lean=lean, arm=arm, tip=tip, elbow=elbow)


STAND = pose(arm=6, elbow=4)
READY = pose(knee=25, lean=8, arm=30)
CROUCH = pose(knee=95, lean=30, arm=-30)
TIPTOE = pose(tip=0.08, arm=35, elbow=15)      # 腕を上げると手が先に天井に当たるので、下げたまま
UP = pose(tip=0.08, arm=15, elbow=10)          # つま先立ちのまま天井へ上がる形


def mixpose(a, b, u):
    return {k: lerp(a[k], b[k], u) for k in a}


def doll_points(p):
    """足もとを原点(上が +y、前が +x)にした関節の位置(m)。膝の曲げは太ももとすねで半分ずつ。"""
    kb = math.radians(p["knee"]) / 2
    ank = (0.0, 0.08 + p["tip"])
    knee = (ank[0] + LEG * math.sin(kb), ank[1] + LEG * math.cos(kb))
    hip = (knee[0] - THIGH * math.sin(kb), knee[1] + THIGH * math.cos(kb))
    ln = math.radians(p["lean"])
    sh = (hip[0] + TORSO * math.sin(ln), hip[1] + TORSO * math.cos(ln))
    hd = (sh[0] + 0.16 * math.sin(ln), sh[1] + 0.16 * math.cos(ln))
    am = math.radians(p["arm"])          # 0 = 下へ垂らす、180 = 真上
    el = (sh[0] + 0.29 * math.sin(am), sh[1] - 0.29 * math.cos(am))
    ae = math.radians(p["arm"] + p["elbow"])
    wr = (el[0] + 0.26 * math.sin(ae), el[1] - 0.26 * math.cos(ae))
    toe = (0.14, 0.0)
    heel = (-0.06, p["tip"])
    return dict(ank=ank, knee=knee, hip=hip, sh=sh, hd=hd, el=el, wr=wr, toe=toe, heel=heel)


def doll_height(p):
    q = doll_points(p)
    return q["hd"][1] + HEADR


def draw_doll(d, fx, fy, ppm, p, rot=0.0, col=DOLL, face=1):
    """顔のない人形。fx, fy は足もとの画面の位置。rot は足もとまわりの回し(度、+ で前へ倒れる)。face=-1 で左向き。"""
    q = doll_points(p)
    c, s = math.cos(math.radians(rot)), math.sin(math.radians(rot))

    def P(pt):
        x, y = pt[0] * face, pt[1]
        xr, yr = x * c + y * s * face, -x * s * face + y * c
        return (fx + xr * ppm, fy - yr * ppm)

    wl = max(3, int(0.11 * ppm))
    back = mix(col, (40, 46, 60), 0.72)
    ol = (60, 66, 84)

    def limb(a, b, cc, w):
        d.line([P(a), P(b)], fill=ol, width=w + max(2, int(0.02 * ppm)))
        d.line([P(a), P(b)], fill=cc, width=w)
        for pt in (a, b):
            x, y = P(pt)
            r = w / 2
            d.ellipse([x - r, y - r, x + r, y + r], fill=cc)

    off = (0.04, 0.0)
    sh2 = (q["sh"][0] - 0.05, q["sh"][1])
    limb(q["sh"], q["el"], back, int(wl * 0.8))           # 奥の腕と脚
    limb(q["el"], q["wr"], back, int(wl * 0.7))
    limb((q["hip"][0] - off[0], q["hip"][1]), (q["knee"][0] - off[0], q["knee"][1]), back, wl)
    limb((q["knee"][0] - off[0], q["knee"][1]), (q["ank"][0] - off[0], q["ank"][1]), back, wl)
    limb(q["heel"], q["toe"], back, int(wl * 0.6))
    limb(q["hip"], sh2, col, int(wl * 1.9))               # 胴
    limb(q["hip"], q["knee"], col, wl)                     # 手前の脚
    limb(q["knee"], q["ank"], col, wl)
    limb(q["heel"], q["toe"], col, int(wl * 0.6))
    limb(q["sh"], q["el"], col, int(wl * 0.8))             # 手前の腕
    limb(q["el"], q["wr"], col, int(wl * 0.7))
    hx, hy = P(q["hd"])
    r = HEADR * ppm
    d.ellipse([hx - r - 2, hy - r - 2, hx + r + 2, hy + r + 2], fill=ol)
    d.ellipse([hx - r, hy - r, hx + r, hy + r], fill=col)
    return P(q["hd"]), P(q["hip"])


# ---- 昇降路とかご -----------------------------------------------------------------------------

CAR_H = 2.3


def layout(box):
    """(全体図の箱, かごの寄りの箱, 札を置く場所の中心)"""
    x0, y0, x1, y1 = box
    if LAND:
        ov = (x0 + 120 * S, y0 + 110 * S, x0 + 290 * S, y1 - 40 * S)
        ch = y1 - y0 - 170 * S
        cw = ch * 0.72
        cx = x0 + (x1 - x0) * 0.40
        car = (cx - cw / 2, y0 + 120 * S, cx + cw / 2, y0 + 120 * S + ch)
        side = ((car[2] + x1) / 2 + 20 * S, (y0 + y1) / 2)
    else:
        ov = (x0 + 90 * S, y0 + 110 * S, x0 + 190 * S, y1 - 260 * S)
        ch = y1 - y0 - 420 * S
        cw = ch * 0.72
        cx = x0 + (x1 - x0) * 0.58
        car = (cx - cw / 2, y0 + 110 * S, cx + cw / 2, y0 + 110 * S + ch)
        side = ((x0 + x1) / 2, y1 - 130 * S)
    return ov, car, side


def overview(d, ov, h_car, catch_h=None):
    """建物の断面(10階ぶん)と、かごの位置。h_car はかごの床の高さ(m、底=0)。"""
    x0, y0, x1, y1 = ov
    d.rectangle([x0, y0, x1, y1], fill=(30, 38, 56), outline=(90, 100, 124), width=max(2, int(2 * S)))
    py = lambda h: y1 - (y1 - y0) * h / 33.0
    for f in range(0, 11):
        y = py(f * 3)
        d.line([(x0, y), (x0 + 16 * S, y)], fill=(130, 140, 160), width=max(1, int(2 * S)))
        if f in (1, 5, 10):
            text(d, (x0 - 10 * S, y), f"{f}階" if f else "", 24, O.DIM, "rm", 3)
    sx0, sx1 = (x0 + x1) / 2 - 22 * S, (x0 + x1) / 2 + 22 * S
    d.rectangle([sx0, py(33), sx1, y1], fill=(14, 18, 28))
    cy1 = py(h_car)
    cy0 = py(h_car + CAR_H)
    d.rectangle([sx0 + 3 * S, cy0, sx1 - 3 * S, cy1], fill=O.YEL)
    text(d, ((x0 + x1) / 2, y1 + 8 * S), "底", 24, O.DIM, "ma", 3)


def car_frame(img, car, off, catch=0.0, rails=False, bottom_px=None, snap=0.0, ropes=True):
    """かごの寄り。off は昇降路の壁の模様のずれ(px、落ちる速さを見せる)。bottom_px は底(緩衝器)の床からの距離(px)。"""
    d = ImageDraw.Draw(img, "RGBA")
    x0, y0, x1, y1 = car
    w = x1 - x0
    sx0, sx1 = x0 - w * 0.32, x1 + w * 0.32
    ry0, ry1 = region()[1], region()[3]
    d.rectangle([sx0, ry0, sx1, ry1], fill=SHAFT)
    step = 90 * S                       # 昇降路の壁の継ぎ目(上へ流れる)
    o = off % step
    yy = ry0 - step + o
    while yy < ry1:
        d.line([(sx0, yy), (x0 - 18 * S, yy)], fill=(44, 52, 70), width=max(2, int(3 * S)))
        d.line([(x1 + 18 * S, yy), (sx1, yy)], fill=(44, 52, 70), width=max(2, int(3 * S)))
        yy += step
    for rx in (x0 - 12 * S, x1 + 12 * S):     # レール
        d.rectangle([rx - 5 * S, ry0, rx + 5 * S, ry1], fill=(150, 156, 170))
    if bottom_px is not None:
        by = y1 + bottom_px
        if by + 18 * S < ry1:
            d.rectangle([sx0, by + 18 * S, sx1, ry1], fill=(54, 58, 70))
            d.rectangle([(x0 + x1) / 2 - 40 * S, by, (x0 + x1) / 2 + 40 * S, by + 18 * S], fill=(200, 80, 60))
            d.rectangle([x0 + 0.12 * w, by, x0 + 0.12 * w + 30 * S, by + 18 * S], fill=(200, 80, 60))
    if ropes:
        cx = (x0 + x1) / 2
        for i, dx in enumerate((-30, 0, 30)):
            xx = cx + dx * S
            if snap <= 0:
                d.line([(xx, ry0), (xx, y0)], fill=(170, 170, 176), width=max(2, int(5 * S)))
            else:
                ln = max(0.0, (y0 - ry0 - 20 * S) * (1 - snap * 1.2))
                wav = 14 * S * math.sin(snap * 20 + i)
                d.line([(xx, y0), (xx + wav, y0 - ln)], fill=(170, 170, 176), width=max(2, int(5 * S)))
    d.rectangle([x0, y0, x1, y1], fill=mix(GLASS, SHAFT, 0.14) + (255,), outline=mix(GLASS, SHAFT, 0.8), width=max(3, int(5 * S)))
    d.rectangle([x0, y1 - 14 * S, x1, y1], fill=(110, 118, 138))
    d.rectangle([x0, y0, x1, y0 + 12 * S], fill=(110, 118, 138))
    hr = y1 - 0.95 / CAR_H * (y1 - y0)                  # 手すり
    d.line([(x1 - 22 * S, hr), (x1 - 4 * S, hr)], fill=(190, 196, 210), width=max(3, int(7 * S)))
    if rails or catch > 0:
        for rx, sgn in ((x0 - 12 * S, 1), (x1 + 12 * S, -1)):
            cy = y1 - 30 * S
            g = 10 * S * (1 - catch)
            col = CLAW if catch > 0 else (150, 140, 110)
            for side in (-1, 1):
                xx = rx + side * (8 * S + g)
                d.polygon([(xx, cy - 22 * S), (xx + side * 14 * S, cy - 30 * S), (xx + side * 14 * S, cy + 8 * S), (xx, cy)], fill=col)
    return d


def ppm_of(car):
    return (car[3] - car[1] - 14 * S) / CAR_H


# 動きの場面(MODES)。どれも「場面の頭からの秒 ts」で決まる
def fall_off(ts, t0=0.0):
    """昇降路の壁の模様のずれ(px)。落ちる速さ g t に比例(見せるために縮めてある)。"""
    u = max(0.0, ts - t0)
    return 0.5 * 9.81 * u * u * 160 * S


def drop(ts):
    """落とす場面: かごの高さ(m)・壁のずれ・底までの距離(px)・当たってからの秒。"""
    if ts < TI:
        h = 30.0 * (1 - (ts / TI) ** 2)
        off = fall_off(ts)
        rem = max(0.0, (TI - ts)) * 900 * S
        return h, off, rem, None
    return 0.0, fall_off(TI), 0.0, ts - TI


def flash(d, x, y, u, r=160, col=(255, 240, 200)):
    if 0 <= u < 1:
        rr = r * S * (0.3 + u)
        a = int(200 * (1 - u))
        d.ellipse([x - rr, y - rr * 0.35, x + rr, y + rr * 0.35], outline=col + (a,), width=max(3, int(8 * S * (1 - u))))


def sc_shaft(img, box, t, ts, P):
    mode = P["mode"]
    still = P.get("still")
    if still:
        ts = 9.0
    ov, car, side = layout(box)
    x0, y0, x1, y1 = car
    ppm = ppm_of(car)
    floor = y1 - 14 * S
    cx = (x0 + x1) / 2
    fx = cx - 0.12 * (x1 - x0)
    h_car, off, rem, after = 30.0, 0.0, None, None
    snap = 0.0
    p = STAND
    lift = 0.0              # 人形の足が床から浮く高さ(m)
    rot = 0.0
    catch = 0.0
    rails = P.get("rails", False)
    slow = False
    hit_col = None
    d0 = ImageDraw.Draw(img, "RGBA")
    if mode == "door":
        p = STAND
    elif mode == "bow":
        p = pose(lean=35 * (0.5 - 0.5 * math.cos(min(ts, 1.6) / 1.6 * 2 * math.pi)), arm=10)
    elif mode == "snap":
        snap = max(0.0, (ts - 0.6) / 0.6)
        off = fall_off(ts, 0.9)
        h_car = 30.0 - 0.5 * 9.81 * max(0, ts - 0.9) ** 2 * 0.05
    elif mode in ("float", "fall", "same", "scale"):
        off = fall_off(ts + 0.6)
        snap = 1.0
        tt = (ts + 0.6) % 2.4 if mode == "fall" else min(ts + 0.6, 2.0)
        h_car = 30.0 * (1 - (tt / 2.47) ** 2) if mode == "fall" else 30.0 - 4.9 * (0.4 * min(ts, 3.0)) ** 2
        lift = 0.03 + 0.02 * math.sin(ts * 2.0) if mode in ("float", "scale") else 0.01
        p = pose(arm=40 + 10 * math.sin(ts * 1.5), knee=5)
    elif mode in ("stand", "jump", "boxjump", "early", "late", "perfect", "straight", "knee", "lie"):
        snap = 1.0
        h_car, off, rem, after = drop(ts)
        slow = TI - 0.7 < ts < TI + 0.6
        if mode == "stand":
            p = STAND
            if after is not None:
                u = _ease(after / 0.25)
                p = pose(knee=40 * u, lean=20 * u, arm=20 + 30 * u)
                hit_col = RED_
        elif mode in ("jump", "boxjump"):
            big = 1.3 if mode == "boxjump" else 1.0
            if ts < TI - 0.6:
                p = READY
            elif ts < TI - 0.25:
                p = mixpose(READY, CROUCH, _ease((ts - (TI - 0.6)) / 0.35))
            elif ts < TI:
                u = _ease((ts - (TI - 0.25)) / 0.2)
                p = mixpose(CROUCH, TIPTOE, u)
                lift = 0.12 * big * max(0.0, (ts - (TI - 0.1)) / 0.1)
            else:
                u = _ease(after / 0.2)
                lift = max(0.0, 0.12 * big * (1 - after / 0.08))
                p = mixpose(TIPTOE, pose(knee=35, lean=18, arm=40), u)
                hit_col = ORG
        elif mode == "early":
            tp0 = 0.5
            if ts < tp0:
                p = mixpose(READY, CROUCH, _ease(ts / tp0))
            elif ts < tp0 + 0.25:
                p = mixpose(CROUCH, TIPTOE, _ease((ts - tp0) / 0.25))
            else:
                p = TIPTOE
                lift = min(0.5 + 0.0, (ts - tp0 - 0.25) * 1.6)
                if lift >= 0.5:
                    p = UP
            if after is not None:
                lift = max(0.0, 0.5 - after * 6)
                p = mixpose(p, pose(knee=50, lean=25, arm=40), _ease(after / 0.2))
                hit_col = RED_
        elif mode == "late":
            if ts < TI - 0.4:
                p = mixpose(READY, CROUCH, _ease(ts / (TI - 0.4)))
            elif ts < TI:
                p = mixpose(CROUCH, pose(knee=50, lean=15, arm=90), _ease((ts - (TI - 0.4)) / 0.4))
            else:
                p = mixpose(pose(knee=50, lean=15, arm=90), pose(knee=70, lean=30, arm=40), _ease(after / 0.2))
                hit_col = ORG
        elif mode in ("perfect", "straight"):
            if mode == "perfect" and ts < TI - 0.55:
                p = mixpose(READY, CROUCH, _ease(ts / (TI - 0.55)))
            elif mode == "perfect" and ts < TI - 0.05:
                p = mixpose(CROUCH, TIPTOE, _ease((ts - (TI - 0.55)) / 0.45))
            else:
                p = pose(tip=0.0, arm=30, elbow=10)
                lift = 0.02 if ts < TI else 0.0
            if after is not None:
                u = _ease(after / 0.12)
                p = pose(knee=6 * u, arm=30 + 30 * u, elbow=10)
                hit_col = RED_
        elif mode == "knee":
            p = READY
            if after is not None:
                u = _ease(after / 0.5)
                p = mixpose(READY, pose(knee=125, lean=40, arm=-20), u)
                hit_col = GRN
        elif mode == "lie":
            p = pose(arm=170, elbow=0)
            rot = 90
            if after is not None:
                hit_col = RED_
    elif mode == "catch":
        snap = 1.0
        if ts < 0.9:
            off = fall_off(ts)
        else:
            off = fall_off(0.9) + 160 * S * 9.81 * 0.9 * (0.3 - 0.3 * math.exp(-(ts - 0.9) / 0.1))
        catch = _ease((ts - 0.75) / 0.2)
        h_car = 30.0 - min(0.9, ts) * 1.1
        p = STAND if ts < 0.9 else mixpose(STAND, pose(knee=12, arm=30), _ease((ts - 0.9) / 0.15) * (1 - _ease((ts - 1.2) / 0.4)))
        rails = True
    elif mode == "recoil":
        snap = 1.0
        off = fall_off(ts + 1.0)
        h_car = 20.0
        k = min(1.0, ts / 0.6)
        p = mixpose(CROUCH, TIPTOE, _ease(k))
        lift = max(0.0, (ts - 0.6) * 0.5) % 0.4
    elif mode == "push":
        snap = 1.0
        off = fall_off(ts + 1.0)
        h_car = 20.0
        ph = (ts % 2.4) / 2.4
        if ph < 0.4:
            p = mixpose(STAND, CROUCH, _ease(ph / 0.4))
            lift = 0.0
        elif ph < 0.55:
            p = mixpose(CROUCH, TIPTOE, _ease((ph - 0.4) / 0.15))
        else:
            p = TIPTOE
            lift = (ph - 0.55) * 0.9
    elif mode == "crouch":
        snap = 1.0
        off = fall_off(ts + 1.0)
        h_car = 20.0
        u = _ease((ts % 3.0) / 1.5) if (ts % 3.0) < 1.5 else 1 - _ease((ts % 3.0 - 1.5) / 1.5)
        p = mixpose(STAND, pose(knee=95, lean=10, arm=40), u)
        lift = (doll_height(STAND) - doll_height(p)) * 0.75     # 体の重心はほとんど動かず、足のほうが上がる
    elif mode == "rail_push":
        snap = 1.0
        off = fall_off(ts + 1.0)
        h_car = 20.0
        u = _ease(min(1.0, ts / 1.2))
        p = mixpose(STAND, pose(knee=95, lean=25, arm=95, elbow=-40), u)
    elif mode == "ready":
        snap = 1.0
        off = fall_off(ts + 0.6)
        h_car = 22.0
        p = READY
    elif mode in ("gap", "bonk", "stuck"):
        snap = 1.0
        off = fall_off(ts + 1.2)
        h_car = 18.0
        p = UP
        lift = 0.0 if mode == "gap" else (CAR_H - 0.014 - doll_height(p))
        if mode == "stuck":
            p = pose(tip=0.08, arm=15, knee=15)
            lift = CAR_H - 0.014 - doll_height(p)
    d = car_frame(img, car, off, catch=catch, rails=rails, bottom_px=rem, snap=snap)
    if mode == "lie":
        draw_doll(d, fx - 0.75 * ppm, floor - 0.13 * ppm, ppm, p, rot=-90, face=-1)
    else:
        hd, hip = draw_doll(d, fx, floor - lift * ppm, ppm, p, rot=rot)
    if mode == "scale":
        sx = fx + 0.02 * ppm
        d.rounded_rectangle([sx - 0.28 * ppm, floor - 0.07 * ppm, sx + 0.28 * ppm, floor], int(6 * S), fill=(230, 232, 240), outline=(60, 66, 84), width=max(2, int(3 * S)))
        label(d, (side[0], side[1] - 100 * S), "体重計", 44, O.WHITE)
        big_label(img, (side[0], side[1] + 70 * S), "0kg", O.YEL, 150, ts / 0.6)
    if mode == "same":
        v = 9.81 * min(ts + 0.6, 2.4) * 3.6
        label(d, (side[0], side[1] - 80 * S), f"かご　時速{v:.0f}km", 48, O.WHITE)
        label(d, (side[0], side[1] + 30 * S), f"人形　時速{v:.0f}km", 48, O.YEL)
        text(d, (side[0], side[1] + 130 * S), "同じ速さ", 56, O.YEL, "mm", 5)
    if mode in ("gap", "bonk", "stuck"):
        q = UP
        top = y0 + 12 * S
        hy = floor - (doll_height(q) + (0 if mode == "gap" else lift)) * ppm
        if mode == "gap":
            xx = fx - 0.4 * ppm
            arrow(d, (xx, hy), (xx, top + 4 * S), O.YEL, 5)
            arrow(d, (xx, top + 4 * S), (xx, hy), O.YEL, 5)
        if mode == "bonk":
            flash(d, fx, top + 10 * S, (ts - 0.0) / 0.4, 120, (255, 230, 120))
    if mode == "rail_push":
        label(d, (x1 - 60 * S, y1 - 0.95 / CAR_H * (y1 - y0) - 50 * S), "手すり", 34, O.WHITE)
    if after is not None and hit_col is not None:
        flash(d, fx, floor, after / 0.5, 200, (255, 240, 200))
    if slow and not still and not P.get("bare"):
        label(d, (x0 + 70 * S, y0 + 40 * S), "スロー", 30, O.DIM)
    overview(d, ov, max(0.0, h_car))
    if P.get("clock"):
        tt = min(2.47, (ts + 0.6) % 2.4 / 2.4 * 2.47)
        big_label(img, side, P["res"], O.YEL, 120, 1.0)
        text(d, (side[0], side[1] + 120 * S), "底に着くまで", 40, O.WHITE, "mm", 4)
        return
    res = P.get("res")
    show = still or after is not None or mode in ("push", "gap", "bonk", "catch", "knee") or mode not in ("stand",)
    if res and show:
        u = 1.0 if still else (after / 0.6 if after is not None else ts / 0.6)
        if mode == "catch" and not still:
            u = (ts - 1.0) / 0.6
        if u > 0:
            col = O.GREEN if P.get("ok") else (O.YEL if not res.endswith("G") else O.RED)
            if res in ("60G",):
                col = O.GREEN
            big_label(img, side, res, col, 120 if len(res) < 6 else 84, u)
    if P.get("note"):
        text(d, (side[0], side[1] + 120 * S), P["note"], 34, O.DIM, "mm", 3)


# ---- 横棒・建物 -------------------------------------------------------------------------------

def sc_formula(img, box, t, ts, P):
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    cx = (x0 + x1) / 2
    rows = P["rows"]
    gap = (y1 - y0) / (len(rows) + 1)
    k = ts / 1.2
    for i, (s, size, col) in enumerate(rows):
        a = _ease(k * (len(rows) + 0.5) * 1.8 - i)
        if a <= 0:
            continue
        cc = COLS[col] if isinstance(col, str) else col
        c = tuple(int(v * a + 20 * (1 - a)) for v in cc)
        sz = fitsize(s, size, (x1 - x0) - 80 * S)
        text(d, (cx, y0 + gap * (i + 1) + 6 * S * math.sin(t * 1.3 + i)), s, sz, c, "mm", 6)


def sc_bars(img, box, t, ts, P):
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    rows = P["rows"]
    note = P.get("note")
    k = 1.0 if P.get("done") else ts / 1.0
    n = len(rows)
    ya = y0 + 140 * S
    yb = y1 - (110 if note else 40) * S
    rh = min(190 * S, (yb - ya) / n)
    ya = ya + ((yb - ya) - rh * n) * 0.45
    na = not LAND
    gx0 = x0 + 60 * S if na else x0 + (x1 - x0) * 0.33
    gx1 = x1 - 60 * S
    vmax = P["vmax"]
    for i, (name, v, txt, col) in enumerate(rows):
        a = _ease(k * 2.2 - 0.35 * i)
        cy = ya + rh * (i + 0.5) + (16 * S if na else 0)
        bh = rh * (0.32 if na else 0.46)
        if na:
            vtext(d, (gx0, cy - bh / 2 - 12 * S), name, 40, O.WHITE, "ld", maxw=x1 - x0 - 120 * S)
        else:
            vtext(d, (gx0 - 20 * S, cy), name, 40, O.WHITE, "rm", maxw=gx0 - x0 - 40 * S)
        if a <= 0:
            continue
        e = gx0 + max(8 * S, (gx1 - gx0) * min(v, vmax) / vmax) * a
        d.rectangle([gx0, cy - bh / 2, e, cy + bh / 2], fill=col)
        tw = O.font(int(44 * S)).getlength(txt)
        if a > 0.6:
            if e + 16 * S + tw > x1 - 20 * S:
                text(d, (e - 16 * S, cy), txt, 44, O.NAVY, "rm", 0)
            else:
                text(d, (e + 16 * S, cy), txt, 44, O.WHITE, "lm", 4)
    head(d, box, P["head"], O.YEL)
    if note and k > 0.8:
        label(d, ((x0 + x1) / 2, y1 - 50 * S), note, 46, O.YEL)


def building(d, x, yb, w, floors, col, ppf):
    """floors 階ぶんの建物(端数は上の階を欠けさせる)。ppf は 1 階の高さ(px)。"""
    top = yb - floors * ppf
    d.rectangle([x, top, x + w, yb], fill=mix(col, BG1, 0.55), outline=col, width=max(2, int(3 * S)))
    nf = int(math.ceil(floors))
    for f in range(nf):
        fy1 = yb - f * ppf
        fy0 = max(top, fy1 - ppf)
        if ppf > 14 * S:
            d.line([(x, fy1), (x + w, fy1)], fill=mix(col, BG1, 0.8), width=max(1, int(2 * S)))
            for j in range(3):
                wx = x + w * (0.15 + 0.27 * j)
                wy0, wy1 = fy0 + (fy1 - fy0) * 0.3, fy1 - (fy1 - fy0) * 0.3
                if wy1 > wy0:
                    d.rectangle([wx, wy0, wx + w * 0.16, wy1], fill=mix((255, 240, 180), BG1, 0.5))
    return top


def sc_floors(img, box, t, ts, P):
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    rows = P["rows"]
    n = len(rows)
    yb = y1 - 70 * S
    ppf = (yb - (y0 + 170 * S)) / P["vmax"]
    w = min(240 * S, (x1 - x0) * 0.6 / n)
    gap = ((x1 - x0) - w * n) / (n + 1)
    d.line([(x0 + 40 * S, yb), (x1 - 40 * S, yb)], fill=O.WHITE, width=max(2, int(4 * S)))
    for i, (name, fl, txt, col) in enumerate(rows):
        a = _ease(ts / 0.8 * 2 - 0.5 * i)
        if a <= 0:
            continue
        x = x0 + gap * (i + 1) + w * i
        top = building(d, x, yb, w, fl * a, col, ppf)
        text(d, (x + w / 2, top - 16 * S), txt, 56, col, "md", 5)
        vtext(d, (x + w / 2, yb + 14 * S), name, 34, O.WHITE, "ma", maxw=w + gap * 0.8)
    head(d, box, P["head"], O.YEL)


# ---- 比べの図 ----------------------------------------------------------------------------------

def car_shape(d, x, y, L, col):
    """横向きの車(x は前の端、y は地面)。"""
    hgt = L * 0.32
    d.rounded_rectangle([x - L, y - hgt * 0.62, x, y - hgt * 0.15], int(L * 0.05), fill=col)
    d.polygon([(x - L * 0.78, y - hgt * 0.6), (x - L * 0.62, y - hgt), (x - L * 0.28, y - hgt), (x - L * 0.14, y - hgt * 0.6)], fill=col)
    d.polygon([(x - L * 0.72, y - hgt * 0.62), (x - L * 0.6, y - hgt * 0.92), (x - L * 0.46, y - hgt * 0.92), (x - L * 0.46, y - hgt * 0.62)], fill=(150, 200, 240))
    d.polygon([(x - L * 0.42, y - hgt * 0.62), (x - L * 0.42, y - hgt * 0.92), (x - L * 0.3, y - hgt * 0.92), (x - L * 0.2, y - hgt * 0.62)], fill=(150, 200, 240))
    for wx in (x - L * 0.78, x - L * 0.24):
        r = L * 0.09
        d.ellipse([wx - r, y - r * 2, wx + r, y], fill=(30, 30, 36))


def sc_car(img, box, t, ts, P):
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img, "RGBA")
    gy = y1 - 120 * S
    wx = x1 - 260 * S
    d.rectangle([wx, y0 + 180 * S, wx + 60 * S, gy], fill=(150, 150, 160))
    d.line([(x0 + 30 * S, gy), (x1 - 30 * S, gy)], fill=O.WHITE, width=max(2, int(4 * S)))
    L = (420 if LAND else 340) * S
    u = _ease(ts / 1.2)
    xf = lerp(x0 + L + 40 * S, wx, u)
    car_shape(d, xf, gy, L, (220, 70, 60))
    if ts > 1.2:
        flash(d, wx, gy - L * 0.25, (ts - 1.2) / 0.5, 200)
    big_label(img, ((x0 + x1) / 2, y0 + 150 * S), "時速87km", O.YEL, 110, ts / 0.6)
    text(d, ((x0 + x1) / 2, gy + 50 * S), "高速道路の車が、壁にぶつかる速さ", 40, O.WHITE, "mm", 4)


def kei_shape(d, x, y, w, col):
    h = w * 0.62
    d.rounded_rectangle([x, y - h, x + w, y - h * 0.15], int(w * 0.12), fill=col, outline=(40, 40, 50), width=max(1, int(2 * S)))
    d.rectangle([x + w * 0.18, y - h * 0.9, x + w * 0.82, y - h * 0.55], fill=(150, 200, 240))
    for wx in (x + w * 0.22, x + w * 0.78):
        r = w * 0.12
        d.ellipse([wx - r, y - r * 2, wx + r, y], fill=(30, 30, 36))


def sc_kei(img, box, t, ts, P):
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    cols, rows = (12, 3) if LAND else (6, 6)
    w = ((x1 - x0) * (0.62 if LAND else 0.82)) / cols
    gx = x0 + ((x1 - x0) - w * cols) / 2 if not LAND else x0 + 60 * S
    gy = y1 - 80 * S
    n = 36
    shown = int(n * _ease(ts / 2.0))
    for i in range(shown):
        r, c = divmod(i, cols)
        kei_shape(d, gx + c * w + w * 0.05, gy - r * w * 0.68, w * 0.9, (230, 230, 236) if i % 5 else (255, 214, 64))
    if LAND:
        tx = x1 - (x1 - x0) * 0.17
        big_label(img, (tx, (y0 + y1) / 2 - 60 * S), "36トン", O.RED, 110, ts / 0.6)
        text(d, (tx, (y0 + y1) / 2 + 60 * S), "60kg × 600倍", 44, O.WHITE, "mm", 4)
        text(d, (tx, (y0 + y1) / 2 + 120 * S), "軽自動車 30台以上", 44, O.YEL, "mm", 4)
    else:
        big_label(img, ((x0 + x1) / 2, y0 + 230 * S), "36トン", O.RED, 110, ts / 0.6)
        text(d, ((x0 + x1) / 2, y0 + 350 * S), "60kg × 600倍　軽自動車 30台以上", 40, O.WHITE, "mm", 4)
    head(d, box, "60kgの体に", O.YEL)


def sc_ground_jump(img, box, t, ts, P):
    """左: 地上(跳んだ体は戻る)、右: 落ちる箱の中(戻らずに天井へ)。"""
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img, "RGBA")
    half = (x0 + x1) / 2
    for i, (bx0, bx1, name) in enumerate(((x0, half, "地上"), (half, x1, "落ちる箱の中"))):
        gy = y1 - 90 * S
        ppm = (gy - (y0 + 200 * S)) / 2.4
        fx = (bx0 + bx1) / 2
        if i == 1:
            d.rectangle([fx - 0.8 * ppm, gy - CAR_H * ppm, fx + 0.8 * ppm, gy], fill=mix(GLASS, BG1, 0.14), outline=mix(GLASS, BG1, 0.8), width=max(3, int(5 * S)))
        else:
            d.line([(bx0 + 40 * S, gy), (bx1 - 40 * S, gy)], fill=O.WHITE, width=max(2, int(4 * S)))
        ph = ts % 2.0
        if ph < 0.4:
            p, lift = mixpose(STAND, CROUCH, _ease(ph / 0.4)), 0.0
        elif ph < 0.55:
            p, lift = mixpose(CROUCH, TIPTOE, _ease((ph - 0.4) / 0.15)), 0.0
        else:
            p = TIPTOE
            tt = ph - 0.55
            if i == 0:
                lift = max(0.0, 3.13 * tt - 4.9 * tt * tt)
            else:
                lift = min(CAR_H - 0.014 - doll_height(TIPTOE), 1.2 * tt)
        draw_doll(d, fx, gy - lift * ppm, ppm, p)
        text(d, (fx, y0 + 140 * S), name, 50, O.YEL if i else O.WHITE, "mm", 5)
        text(d, (fx, gy + 46 * S), "すぐ落ちてくる" if i == 0 else "戻らずに天井へ", 40, O.WHITE, "mm", 4)


def sc_window(img, box, t, ts, P):
    """床に当たるまでの時間の帯。stage 0=蹴りきるのに0.19秒 1=窓を塗る 2=116ミリ秒 3=そのあいだに2.5m。"""
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img, "RGBA")
    st = P["stage"]
    gx0, gx1 = x0 + 120 * S, x1 - 120 * S
    tmax = 0.5
    px = lambda tb: gx1 - (gx1 - gx0) * tb / tmax       # tb = 床に当たる何秒前
    cy = (y0 + y1) / 2 + 20 * S
    d.line([(gx0, cy), (gx1, cy)], fill=O.WHITE, width=max(3, int(6 * S)))
    for tb in (0.5, 0.4, 0.3, 0.2, 0.1, 0.0):
        x = px(tb)
        d.line([(x, cy - 14 * S), (x, cy + 14 * S)], fill=O.WHITE, width=max(2, int(3 * S)))
        text(d, (x, cy + 36 * S), "床" if tb == 0 else f"{tb:.1f}秒前", 32, O.DIM if tb else O.RED, "ma", 3)
    xr = px(0.0)
    d.rectangle([xr - 6 * S, cy - 80 * S, xr + 6 * S, cy + 20 * S], fill=O.RED)
    u = _ease(ts / 0.8)
    if st == 0:
        a, b = px(0.185), px(0.0)
        d.rectangle([a, cy - 70 * S, a + (b - a) * u, cy - 20 * S], fill=(255, 214, 64, 200))
        label(d, ((a + b) / 2, cy - 130 * S), "蹴りきるのに 0.19秒", 44, O.YEL)
    else:
        a, b = px(0.301), px(0.185)
        d.rectangle([a, cy - 70 * S, a + (b - a) * (u if st == 1 else 1), cy - 20 * S], fill=(110, 220, 140, 220))
        label(d, ((a + b) / 2, cy - 130 * S), "0.30〜0.19秒前に蹴り始める", 40, O.GREEN)
        if st >= 1:
            label(d, (px(0.4), cy + 140 * S), "早いと 天井に頭", 38, O.RED)
            label(d, (px(0.09), cy + 140 * S), "遅いと 蹴りきれない", 38, ORG)
        if st >= 2:
            big_label(img, ((x0 + x1) / 2, y0 + 120 * S), "116ミリ秒", O.YEL, 110, ts / 0.6 if st == 2 else 1.0)
        if st >= 3:
            text(d, ((x0 + x1) / 2, cy + 230 * S), "そのあいだに、かごは2.5m落ちる", 48, O.WHITE, "mm", 5)


def sc_cue(img, box, t, ts, P):
    """昇降路の縦の図: 底の10m手前で「今だ」。"""
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img, "RGBA")
    top, bot = y0 + 120 * S, y1 - 60 * S
    sx = x0 + (x1 - x0) * (0.32 if LAND else 0.3)
    py = lambda h: bot - (bot - top) * h / 30.0
    d.rectangle([sx - 60 * S, top, sx + 60 * S, bot], fill=SHAFT, outline=(90, 100, 124), width=max(2, int(3 * S)))
    for f in range(0, 11):
        d.line([(sx - 60 * S, py(f * 3)), (sx - 40 * S, py(f * 3))], fill=(130, 140, 160), width=max(1, int(2 * S)))
    u = (ts % 2.6) / 2.6
    h = 30.0 * (1 - u * u)
    d.rectangle([sx - 44 * S, py(h + 2.3), sx + 44 * S, py(h)], fill=O.YEL)
    yc = py(10.1)
    d.line([(sx - 90 * S, yc), (x1 - 80 * S, yc)], fill=O.RED, width=max(2, int(4 * S)))
    label(d, ((sx + x1) / 2 + 30 * S, yc - 70 * S), "底の10m手前で「今だ」", 50, O.RED, maxw=(x1 - sx) - 120 * S)
    text(d, ((sx + x1) / 2 + 30 * S, yc + 60 * S), "反応 約0.16秒 ＋ 蹴る0.19秒 ＋ 窓", 36, O.WHITE, "mm", 4)
    text(d, (sx, bot + 10 * S), "底", 30, O.DIM, "ma", 3)
    text(d, (sx + 80 * S, py(30)), "10階", 32, O.DIM, "lm", 3)


def sc_egg(img, box, t, ts, P):
    """左: 手を止めて受ける(割れる)、右: 手を引きながら受ける(割れない)。"""
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    half = (x0 + x1) / 2
    for i, (bx0, bx1) in enumerate(((x0, half), (half, x1))):
        cx = (bx0 + bx1) / 2
        hy = y1 - 260 * S
        ph = ts % 2.4
        drop_ = min(1.0, ph / 1.0)
        ey = lerp(y0 + 160 * S, hy - 40 * S, drop_ * drop_)
        give = 0.0
        if i == 1 and ph > 1.0:
            give = min(120 * S, (ph - 1.0) * 300 * S)
            ey = hy - 40 * S + give
        d.rounded_rectangle([cx - 90 * S, hy + give, cx + 90 * S, hy + 40 * S + give], int(20 * S), fill=(236, 196, 160))
        if i == 0 and ph > 1.0:
            for a in range(6):
                ang = math.radians(200 + a * 28)
                d.line([(cx, hy - 10 * S), (cx + 70 * S * math.cos(ang), hy - 10 * S + 40 * S * math.sin(ang))], fill=(255, 220, 120), width=max(2, int(4 * S)))
            d.ellipse([cx - 60 * S, hy - 22 * S, cx + 60 * S, hy + 4 * S], fill=(255, 210, 90))
        else:
            d.ellipse([cx - 34 * S, ey - 46 * S, cx + 34 * S, ey + 40 * S], fill=(250, 246, 236), outline=(120, 110, 100), width=max(2, int(2 * S)))
        text(d, (cx, y1 - 150 * S), "手を止めて受ける" if i == 0 else "手を引きながら受ける", 44, O.WHITE, "mm", 4)
        text(d, (cx, y1 - 90 * S), "割れる" if i == 0 else "割れない", 52, O.RED if i == 0 else O.GREEN, "mm", 5)
    head(d, box, "止まる距離が長いほど、力は小さい", O.YEL)


RUNS = [("立ったまま", "×", STAND, 0), ("直前に跳ぶ", "×", TIPTOE, 0), ("箱の中で蹴る", "×", TIPTOE, 0), ("早めに跳ぶ", "×", TIPTOE, 0),
        ("遅めに跳ぶ", "×", pose(knee=50, lean=15, arm=90), 0), ("完ぺきに跳ぶ", "×", pose(arm=30, elbow=10), 0),
        ("膝を曲げる", "×", pose(knee=125, lean=40, arm=-20), 0), ("寝そべる", "×", pose(arm=170, elbow=0), 90),
        ("止める仕組みあり", "○", STAND, 0)]


def sc_lineup(img, box, t, ts, P):
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    n = P["n"]
    cols = n if LAND else 3
    rows_ = 1 if LAND else math.ceil(n / 3)
    cw = (x1 - x0 - 60 * S) / cols
    chh = (y1 - y0 - 160 * S) / rows_
    ppm = min(cw * 0.9 / 1.0, chh * 0.55 / 1.8)
    for i in range(n):
        a = _ease(ts / 0.15 - i * 0.6)
        if a <= 0:
            continue
        r, c = divmod(i, cols)
        cx = x0 + 30 * S + cw * (c + 0.5)
        base = y0 + 140 * S + chh * (r + 1) - 110 * S
        name, mk, p, rot = RUNS[i]
        hl = P.get("hl") and i == 8
        if hl:
            d.rounded_rectangle([cx - cw * 0.48, base - 2.0 * ppm, cx + cw * 0.48, base + 100 * S], int(14 * S), outline=O.GREEN, width=max(3, int(5 * S)))
        if rot:
            pl = cw * 0.8 / 1.85
            draw_doll(d, cx - 0.92 * pl, base - 0.13 * pl, pl, p, rot=-90, face=-1)
        else:
            draw_doll(d, cx - 0.04 * ppm, base, ppm, p)
        d.line([(cx - cw * 0.42, base), (cx + cw * 0.42, base)], fill=(110, 118, 138), width=max(2, int(4 * S)))
        text(d, (cx, base + 16 * S), f"{i + 1}回目", 30, O.YEL, "ma", 3)
        vtext(d, (cx, base + 56 * S), name, 28, O.WHITE, "ma", maxw=cw * 0.95)
        if P.get("marks"):
            text(d, (cx, base - 2.05 * ppm), mk, 70, O.GREEN if mk == "○" else O.RED, "md", 5)
    head(d, box, "10階から落とした結果", O.YEL)


def sc_esb(img, box, t, ts, P):
    """stage 0=1945年 1=ビル 2=75階ぶん 3=270〜290m 4=10階の9倍以上。"""
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img, "RGBA")
    st = P["stage"]
    gy = y1 - 60 * S
    top = y0 + 150 * S
    bx = x0 + (x1 - x0) * (0.30 if LAND else 0.36)
    hm = 381.0                    # ビルの屋上の高さ(m、尖塔を除く)
    py = lambda m: gy - (gy - top) * m / hm
    w = 150 * S
    d.rectangle([bx - w / 2, py(hm), bx + w / 2, gy], fill=(70, 80, 100), outline=(150, 160, 180), width=max(2, int(3 * S)))
    d.rectangle([bx - w * 0.3, py(hm) - 40 * S, bx + w * 0.3, py(hm)], fill=(70, 80, 100))
    d.line([(bx, py(hm) - 40 * S), (bx, py(hm) - 110 * S)], fill=(150, 160, 180), width=max(2, int(4 * S)))
    for m in range(0, int(hm), 12):
        d.line([(bx - w / 2 + 10 * S, py(m)), (bx + w / 2 - 10 * S, py(m))], fill=(90, 100, 124), width=1)
    d.line([(x0 + 40 * S, gy), (x1 - 40 * S, gy)], fill=O.WHITE, width=max(2, int(4 * S)))
    tx = bx + w / 2 + 60 * S
    if st <= 1:
        text(d, (tx, top + 60 * S), "1945年", 110, O.YEL, "lm", 6)
        text(d, (tx, top + 190 * S), "ニューヨーク", 60, O.WHITE, "lm", 5)
        if st == 1:
            text(d, (tx, top + 290 * S), "エンパイア・ステート・ビル", 48, O.WHITE, "lm", 4)
            fx, fy = bx + w / 2, py(290)
            u = _ease(ts / 1.0)
            pxx = lerp(x1 - 60 * S, fx + 40 * S, u)
            d.polygon([(pxx, fy), (pxx + 90 * S, fy - 16 * S), (pxx + 90 * S, fy + 16 * S)], fill=(200, 200, 210))
            d.line([(pxx + 30 * S, fy - 40 * S), (pxx + 50 * S, fy + 40 * S)], fill=(200, 200, 210), width=max(3, int(8 * S)))
            if u >= 1:
                flash(d, fx, fy, ((ts - 1.0) % 1.2) / 1.2, 120, (255, 160, 80))
        return
    a, b = 270.0, 290.0
    u = _ease(ts / 1.0) if st == 2 else 1.0
    d.rectangle([bx - 20 * S, py(b * u), bx + 20 * S, gy], fill=(255, 214, 64, 150))
    if st == 2:
        label(d, (tx + 140 * S, py(200)), "75階ぶんの落下（ギネス記録）", 46, O.YEL, maxw=x1 - tx - 60 * S)
    if st >= 3:
        for m in (a, b):
            d.line([(bx - w / 2 - 20 * S, py(m)), (bx + w / 2 + 30 * S, py(m))], fill=O.YEL, width=max(2, int(3 * S)))
        label(d, (tx + 140 * S, py(280)), "およそ270〜290m", 52, O.YEL, maxw=x1 - tx - 60 * S)
        text(d, (tx + 140 * S, py(280) + 70 * S), "階の高さから計算", 34, O.DIM, "mm", 3)
    if st >= 4:
        x2 = tx + 200 * S
        d.rectangle([x2, py(30), x2 + 90 * S, gy], fill=O.RED)
        text(d, (x2 + 45 * S, py(30) - 10 * S), "人形の10階 30m", 34, O.RED, "md", 3)
        big_label(img, (x2 + 330 * S, py(130)), "9倍以上", O.YEL, 100, ts / 0.6)


def sc_air(img, box, t, ts, P):
    """stage 0=縦穴の空気が押し縮められる 1=底にたまったケーブル。"""
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img, "RGBA")
    st = P["stage"]
    sx = (x0 + x1) / 2 - (200 * S if LAND else 0)
    top, bot = y0 + 120 * S, y1 - 40 * S
    d.rectangle([sx - 90 * S, top, sx + 90 * S, bot], fill=SHAFT, outline=(110, 118, 138), width=max(3, int(4 * S)))
    u = (ts % 3.0) / 3.0
    cy = lerp(top + 40 * S, bot - 260 * S, _ease(u))
    d.rectangle([sx - 80 * S, cy, sx + 80 * S, cy + 120 * S], fill=O.YEL)
    if st == 0:
        n = 36
        for i in range(n):
            fx = (i * 0.37) % 1
            fy = (i * 0.61) % 1
            yy = cy + 120 * S + (bot - cy - 130 * S) * fy
            d.ellipse([sx - 80 * S + 160 * S * fx - 5 * S, yy - 5 * S, sx - 80 * S + 160 * S * fx + 5 * S, yy + 5 * S], fill=(150, 200, 240, 200))
        label(d, (sx + 330 * S if LAND else sx, (cy + bot) / 2 + (0 if LAND else 0)), "下の空気が押し縮められる", 42, O.WHITE)
        head(d, box, "ギネス記録の書き方", O.YEL)
    else:
        for j in range(9):
            yy = bot - 20 * S - j * 14 * S
            d.arc([sx - 70 * S, yy - 14 * S, sx + 70 * S, yy + 14 * S], 0, 360, fill=(190, 190, 196), width=max(2, int(4 * S)))
        label(d, (sx + 330 * S if LAND else sx, bot - 200 * S), "たまったケーブルが、ばねに", 42, O.WHITE)
        head(d, box, "ギネス記録の書き方", O.YEL)


def sc_gov(img, box, t, ts, P):
    """ロープ・調速機・非常止め。stage 0=今のかご 1=支えは2つ以上 2=5倍 3=全部切れたら 4=調速機 5=1.25倍で電気を切る 6=1.35倍で爪。"""
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img, "RGBA")
    st = P["stage"]
    sx = x0 + (x1 - x0) * (0.32 if LAND else 0.42)
    top, bot = y0 + 110 * S, y1 - 40 * S
    sw = (330 if LAND else 300) * S
    d.rectangle([sx - sw / 2, top, sx + sw / 2, bot], fill=SHAFT, outline=(110, 118, 138), width=max(3, int(4 * S)))
    for rx in (sx - sw / 2 + 20 * S, sx + sw / 2 - 20 * S):
        d.rectangle([rx - 5 * S, top, rx + 5 * S, bot], fill=(150, 156, 170))
    cw, chh = sw - 70 * S, (bot - top) * 0.32
    cy0 = top + (bot - top) * 0.42
    if st == 6:
        cy0 += min(20 * S, ts * 40 * S)
    d.rectangle([sx - cw / 2, cy0, sx + cw / 2, cy0 + chh], fill=mix(GLASS, SHAFT, 0.2), outline=GLASS, width=max(3, int(4 * S)))
    draw_doll(d, sx, cy0 + chh - 6 * S, chh * 0.88 / CAR_H, STAND)
    broken = st >= 3
    for i, dx in enumerate((-24, 0, 24)):
        xx = sx + dx * S
        col = (190, 190, 196) if not broken else (150, 80, 70)
        if broken:
            d.line([(xx, top), (xx, top + 60 * S + 10 * S * i)], fill=col, width=max(2, int(5 * S)))
            d.line([(xx + 6 * S, cy0 - 40 * S - 8 * S * i), (xx, cy0)], fill=col, width=max(2, int(5 * S)))
        else:
            d.line([(xx, top), (xx, cy0)], fill=(255, 214, 64) if st in (1, 2) else col, width=max(2, int(6 * S)))
    gx, gy = sx + sw / 2 + 90 * S, top + 70 * S
    gr = 50 * S
    hot = st >= 4
    ang = ts * (4 if st < 5 else 7)
    d.ellipse([gx - gr, gy - gr, gx + gr, gy + gr], outline=O.YEL if hot else (150, 156, 170), width=max(3, int(8 * S)))
    for j in range(4):
        a = ang + j * math.pi / 2
        d.line([(gx, gy), (gx + gr * math.cos(a), gy + gr * math.sin(a))], fill=O.YEL if hot else (150, 156, 170), width=max(2, int(4 * S)))
    d.line([(gx - gr, gy), (gx - gr, cy0 + chh * 0.5)], fill=O.YEL if hot else (130, 136, 150), width=max(2, int(3 * S)))
    d.line([(gx - gr, cy0 + chh * 0.5), (sx + cw / 2, cy0 + chh * 0.5)], fill=O.YEL if hot else (130, 136, 150), width=max(2, int(3 * S)))
    d.line([(gx + gr, gy), (gx + gr, bot)], fill=O.YEL if hot else (130, 136, 150), width=max(2, int(3 * S)))
    catch = _ease(ts / 0.4) if st == 6 else 0.0
    for rx, sg in ((sx - sw / 2 + 20 * S, 1), (sx + sw / 2 - 20 * S, -1)):
        yy = cy0 + chh - 20 * S
        g = 12 * S * (1 - catch)
        col = CLAW if st == 6 else (140, 130, 100)
        for side in (-1, 1):
            xx = rx + side * (8 * S + g)
            d.polygon([(xx, yy - 26 * S), (xx + side * 16 * S, yy - 34 * S), (xx + side * 16 * S, yy + 8 * S), (xx, yy)], fill=col)
    tx = gx + gr + 60 * S if LAND else x0 + 40 * S
    ty = (top + bot) / 2 if LAND else bot - 120 * S
    anchor = "lm"
    msgs = {
        0: ("今のエレベーター", "落ちきる前につかまえる"),
        1: ("支えは2つ以上", "どれか1つでも支えられる（施行令129条の4）"),
        2: ("安全率5.0", "ふだんかかる力の5倍に耐える"),
        3: ("ロープが全部切れたら", ""),
        4: ("調速機（ちょうそくき）", "かごと別の細いロープでつながる輪"),
        5: ("1.25倍ほどで", "電気を切る（多くのエレベーター）"),
        6: ("1.35倍ほどで", "爪がレールをつかむ＝非常止め"),
    }
    a, b = msgs[st]
    if LAND:
        mw = x1 - tx - 40 * S
        vtext(d, (tx, ty - 50 * S), a, 66, O.YEL, anchor, maxw=mw)
        if b:
            vtext(d, (tx, ty + 40 * S), b, 40, O.WHITE, anchor, maxw=mw)
    else:
        label(d, ((x0 + x1) / 2, top - 30 * S if st else top - 30 * S), a, 54, O.YEL, maxw=x1 - x0 - 80 * S)
        if b:
            vtext(d, ((x0 + x1) / 2, bot + 0 * S - 20 * S), b, 38, O.WHITE, "md", maxw=x1 - x0 - 80 * S)
    if st == 4:
        label(d, (gx, gy + gr + 40 * S), "調速機", 36, O.YEL)
    if st == 6:
        label(d, (sx - sw / 2 - 20 * S, cy0 + chh + 50 * S), "非常止めの爪", 34, CLAW)


def sc_door_gap(img, box, t, ts, P):
    """乗り場の扉。すき間の奥にレールが見える。"""
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img, "RGBA")
    cx = (x0 + x1) / 2
    dw = (420 if LAND else 360) * S
    dt, db = y0 + 120 * S, y1 - 60 * S
    d.rectangle([cx - dw - 40 * S, dt - 40 * S, cx + dw + 40 * S, db], fill=(60, 66, 84))
    gap = 70 * S + 30 * S * math.sin(ts * 0.8)
    d.rectangle([cx - gap / 2, dt, cx + gap / 2, db], fill=(14, 18, 28))
    d.rectangle([cx - 6 * S, dt, cx + 6 * S, db], fill=(170, 176, 190))
    for yy in range(int(dt), int(db), int(60 * S)):
        d.rectangle([cx - 14 * S, yy, cx + 14 * S, yy + 10 * S], fill=(120, 126, 140))
    for sgn in (-1, 1):
        xa = cx + sgn * gap / 2
        xb = cx + sgn * dw
        d.rectangle([min(xa, xb), dt, max(xa, xb), db], fill=(190, 196, 208), outline=(120, 126, 140), width=max(2, int(3 * S)))
    label(d, (cx + dw * 0.5, (dt + db) / 2), "レール", 46, CLAW)
    arrow(d, (cx + dw * 0.5 - 80 * S, (dt + db) / 2), (cx + 16 * S, (dt + db) / 2), CLAW, 5)
    head(d, box, "扉のすき間の奥", O.YEL)


def sc_twodoll(img, box, t, ts, P):
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    half = (x0 + x1) / 2
    gy = y1 - 150 * S
    ppm = (gy - (y0 + 220 * S)) / 1.9
    u = _ease((ts % 2.4) / 0.6)
    draw_doll(d, (x0 + half) / 2, gy, ppm, pose(knee=6 * u, arm=30 + 30 * u, elbow=10))
    draw_doll(d, (half + x1) / 2, gy, ppm, mixpose(READY, pose(knee=125, lean=40, arm=-20), u))
    for cx in ((x0 + half) / 2, (half + x1) / 2):
        d.line([(cx - 160 * S, gy), (cx + 160 * S, gy)], fill=O.WHITE, width=max(2, int(4 * S)))
    text(d, ((x0 + half) / 2, gy + 30 * S), "跳んで伸びきる", 42, O.WHITE, "ma", 4)
    text(d, ((half + x1) / 2, gy + 30 * S), "跳ばずに膝", 42, O.WHITE, "ma", 4)
    big_label(img, ((x0 + half) / 2, y0 + 150 * S), "415G", O.RED, 90, 1.0)
    big_label(img, ((half + x1) / 2, y0 + 150 * S), "60G", O.GREEN, 90, 1.0)


KINDS = dict(formula=sc_formula, shaft=sc_shaft, bars=sc_bars, floors=sc_floors, car=sc_car, kei=sc_kei,
             ground_jump=sc_ground_jump, window=sc_window, cue=sc_cue, egg=sc_egg, lineup=sc_lineup, esb=sc_esb,
             air=sc_air, gov=sc_gov, door_gap=sc_door_gap, twodoll=sc_twodoll)


def region(P=None):
    return (0, 100, W, 880) if LAND else (0, 240, W, 1370)


def paint(sc, t, ts):
    img = Image.new("RGBA", (W, H), BG0 + (255,))
    box = region(sc)
    grad(img, box=box)
    KINDS[sc["kind"]](img, box, t, ts, sc)
    return img


def _tag(img, box, n):
    """左上の「N回目」の札。"""
    d = ImageDraw.Draw(img)
    x0, y0 = box[0], box[1]
    s = f"{n}回目"
    f = O.font(int(44 * S))
    w = f.getlength(s)
    bx = (x0 + 24 * S, y0 + 14 * S, x0 + 24 * S + w + 40 * S, y0 + 14 * S + 70 * S)
    d.rounded_rectangle(bx, int(14 * S), fill=O.YEL, outline=O.NAVY, width=int(3 * S))
    d.text(((bx[0] + bx[2]) / 2, (bx[1] + bx[3]) / 2), s, font=f, fill=O.NAVY, anchor="mm")
    O.BOXES.append(("label", bx, s, 1.0))


def _scenes(lines, defs):
    """行ごとの場面と、その場面が始まった行(引き継いだ行は同じ場面の頭から時間を数える)。"""
    out, cur, first = [], None, None
    for j, l in enumerate(lines):
        dd = defs.get(l["id"], {})
        if dd.get("scene") is not None:
            cur, first = dd["scene"], j
        out.append((cur, first))
    return out


def draw(img, dr, t, ctx):
    lines, defs = ctx["lines"], ctx["defs"]
    scs = ctx.setdefault("_scs", _scenes(lines, defs))
    cur = ctx["cur"] or lines[0]
    i = next(j for j, l in enumerate(lines) if l["id"] == cur["id"])
    now, j0 = scs[i]
    prev = scs[j0 - 1][0] if j0 and j0 > 0 else None
    t0 = lines[j0]["start"]
    ts = t - t0
    dd = defs.get(cur["id"], {})
    u = _ease(ts / 0.5)
    b = None
    if prev is not None and u < 1:
        pj0 = scs[j0 - 1][1]
        b = paint(prev, t, t - lines[pj0]["start"])
    O.BOXES.clear()
    a = paint(now, t, ts)
    if b is not None:
        a = Image.blend(b, a, u)
    z = 1.0 + 0.025 * (0.5 + 0.5 * math.sin(2 * math.pi * t / 14.0))
    if z > 1.0005:
        zw, zh = int(W * z), int(H * z)
        a = a.resize((zw, zh), Image.BILINEAR).crop(((zw - W) // 2, (zh - H) // 2, (zw - W) // 2 + W, (zh - H) // 2 + H))
    img.paste(a, (0, 0))
    run = dd.get("run")
    if run and now["kind"] != "formula":
        _tag(img, region(now), run)


# 落とす場面の音: 当たる瞬間に「ドン」、ロープが切れて「バチン」、頭を打って「ゴン」
DROPS = ("stand", "jump", "boxjump", "early", "late", "perfect", "straight", "knee", "lie")


def sfx_for(lines_def, L):
    from naze import mapscene
    ev = mapscene.sfx(lines_def, L)
    for dd in lines_def:
        s = dd.get("scene")
        if not s or dd["id"] not in L or s.get("still"):
            continue
        t0 = L[dd["id"]]["start"]
        m = s.get("mode")
        if s["kind"] == "shaft":
            if m in DROPS:
                ev.append((t0 + TI, "thud"))
            if m == "early":
                ev.append((t0 + 0.5 + 0.25 + 0.5 / 1.6, "bonk"))
            if m == "bonk":
                ev.append((t0 + 0.05, "bonk"))
            if m == "snap":
                ev.append((t0 + 0.6, "snap"))
            if m == "catch":
                ev.append((t0 + 0.85, "snap"))
        if s["kind"] in ("bars", "floors", "kei") or (s["kind"] == "shaft" and s.get("res")):
            ev.append((t0 + 0.4, "pop"))
    return sorted(ev)
