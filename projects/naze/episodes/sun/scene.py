"""太陽にゴミを捨てない(計算の回)の画面。行の scene=dict(kind=…) を描く(無い行は前の行を引き継ぐ)。
下地は 1 本のあいだ「太陽系を斜め上から見た図」(kind: space)。カプセルの道すじは軌道の式を数値で解いて描く(sim/calc.py と同じ定数)。
あいだに全面の図(card・bars・count・earth109・canister・train・vectors・saturn・quote・areas・answer・sunset)を挟む。場面が変わると 0.5 秒で溶け合わせる。
写真・AI 絵は使わない。図は全部コードで描く。数字の出どころは scripts.md の出典と sim/calc.txt。
"""
from __future__ import annotations

import math
import random

from PIL import Image, ImageDraw, ImageFilter

from naze import mapscene, overlay as O
from naze.config import H, W

LAND = W > H
S = min(W, H) / 1080
BG0, BG1 = (6, 10, 26), (12, 22, 50)
SUNC = (255, 196, 80)
EARTHC = (90, 170, 235)
CAPC = (255, 120, 90)
GRY = (150, 160, 180)
GRN = (110, 220, 140)
YL = O.YEL
RD = O.RED
AMB = (240, 170, 70)
BLU = (90, 170, 235)
COLS = dict(white=O.WHITE, yel=O.YEL, red=O.RED, green=O.GREEN, dim=O.DIM, grey=GRY, amber=AMB, blue=BLU)


def C(c):
    return COLS.get(c, c) if isinstance(c, str) else c


def _ease(u):
    u = max(0.0, min(1.0, u))
    return u * u * (3 - 2 * u)


def region():
    """図を置く範囲(字幕の上)。"""
    return (0, 60, W, 920) if LAND else (0, 200, W, 1460)


# ---------------------------------------------------------------- 軌道の計算(太陽を原点、単位は天文単位と年)
GM = 4 * math.pi ** 2
KMS = 1 / 4.740470          # 1 km/s を 天文単位/年 に
R_SUN = 695700 / 149597870.7
VE = 2 * math.pi            # 地球の公転の速さ(29.78 km/s)
PLANETS = [("水星", 0.387, (190, 180, 170), 4), ("金星", 0.723, (235, 205, 140), 6), ("地球", 1.0, EARTHC, 7),
           ("火星", 1.524, (220, 110, 80), 5), ("木星", 5.203, (220, 180, 140), 11)]
PANG = {"水星": 2.3, "金星": 0.6, "地球": -math.pi / 2, "火星": 2.9, "木星": 1.15}   # 図の中で止めておく位置(角度)
EARTH = (0.0, -1.0)


def _orbit(p, v, stop, tmax=6.0):
    """位置 p・速さ v から数値で解く。stop(x, y, vx, vy, t) が真になるか太陽に当たれば止める。"""
    x, y = p
    vx, vy = v
    t = 0.0
    pts = [(x, y)]

    def acc(x, y):
        r3 = (x * x + y * y) ** 1.5
        return -GM * x / r3, -GM * y / r3

    while t < tmax:
        r = math.hypot(x, y)
        dt = 0.0015 * r ** 1.5
        ax1, ay1 = acc(x, y)
        x2, y2 = x + vx * dt / 2, y + vy * dt / 2
        ax2, ay2 = acc(x2, y2)
        vx2, vy2 = vx + ax1 * dt / 2, vy + ay1 * dt / 2
        x3, y3 = x + vx2 * dt / 2, y + vy2 * dt / 2
        vx3, vy3 = vx + ax2 * dt / 2, vy + ay2 * dt / 2
        ax3, ay3 = acc(x3, y3)
        x4, y4 = x + vx3 * dt, y + vy3 * dt
        vx4, vy4 = vx + ax3 * dt, vy + ay3 * dt
        ax4, ay4 = acc(x4, y4)
        x += dt / 6 * (vx + 2 * vx2 + 2 * vx3 + vx4)
        y += dt / 6 * (vy + 2 * vy2 + 2 * vy3 + vy4)
        vx += dt / 6 * (ax1 + 2 * ax2 + 2 * ax3 + ax4)
        vy += dt / 6 * (ay1 + 2 * ay2 + 2 * ay3 + ay4)
        t += dt
        pts.append((x, y))
        if math.hypot(x, y) <= R_SUN or stop(x, y, vx, vy, t):
            break
    return pts


def _until_out(rmax):
    """近日点を過ぎて、rmax より外へ出たら止める。"""
    st = dict(inbound=True)

    def f(x, y, vx, vy, t):
        if st["inbound"] and x * vx + y * vy > 0:
            st["inbound"] = False
        return (not st["inbound"]) and math.hypot(x, y) > rmax
    return f


def _period(p, v):
    r = math.hypot(*p)
    v2 = v[0] ** 2 + v[1] ** 2
    a = 1 / (2 / r - v2 / GM)
    return 2 * math.pi * math.sqrt(a ** 3 / GM) if a > 0 else 99


def _paths():
    P = {}
    for vr in (10, 20):                                  # 太陽の向きにまっすぐ(地球は下、太陽は上。横の速さは右向き)
        v = (VE, vr * KMS)
        P[f"r{vr}"] = _orbit(EARTH, v, _until_out(1.45))
    for dv in (10, 20, 27):                              # うしろ向きに撃って、横の速さを消す
        v = (VE - dv * KMS, 0.0)
        per = _period(EARTH, v)
        P[f"b{dv}"] = _orbit(EARTH, v, lambda x, y, vx, vy, t, per=per: t >= per * 0.999)
    P["out12"] = _orbit(EARTH, (VE + 12.34 * KMS, 0.0), lambda x, y, vx, vy, t: math.hypot(x, y) > 7.5)
    rj = 5.2                                             # 木星の遠さまで行って、そこで消す
    a1 = (1 + rj) / 2
    v1 = math.sqrt(GM * (2 - 1 / a1))
    up = _orbit(EARTH, (v1, 0.0), lambda x, y, vx, vy, t: x * vx + y * vy < 0 and t > 0.1)
    P["jup1"] = up
    x, y = up[-1]
    r = math.hypot(x, y)
    a2 = (r + R_SUN * 0.5) / 2                         # 表面の少し内側をねらう(当たって止まる)
    v2 = math.sqrt(GM * (2 / r - 1 / a2))
    P["jup2"] = _orbit((x, y), (v2 * -y / r, v2 * x / r), lambda *a: False, 4.0)      # 左回り(地球と同じ向き)
    return P


PATHS = _paths()


# ---------------------------------------------------------------- 下地(星)と描く道具
_STARS = {}


def stars():
    if "img" not in _STARS:
        img = Image.new("RGBA", (W, H), BG0 + (255,))
        d = ImageDraw.Draw(img)
        for i in range(0, H, 2):
            u = i / H
            d.rectangle([0, i, W, i + 2], fill=tuple(int(BG0[j] + (BG1[j] - BG0[j]) * u) for j in range(3)))
        rnd = random.Random(7)
        for _ in range(int(900 * W * H / (1920 * 1080))):
            x, y = rnd.uniform(0, W), rnd.uniform(0, H)
            b = rnd.choice([90, 120, 160, 210, 250])
            rr = rnd.choice([0.8, 1.0, 1.0, 1.4, 2.0]) * S
            d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=(b, b, min(255, b + 20)))
        _STARS["img"] = img
    return _STARS["img"].copy()


def text(d, xy, s, size, col=O.WHITE, anchor="la", stroke=5):
    d.text(xy, s, font=O.font(int(size * S)), fill=C(col), anchor=anchor, stroke_width=int(stroke * S) or 1, stroke_fill=O.NAVY)


def fit(s, size, maxw):
    while size > 20 and O.font(int(size * S)).getlength(s) > maxw:
        size -= 2
    return size


def label(d, xy, s, size=40, col=O.WHITE, anchor="mm"):
    """札(箱つき)。重なりの点検に載せる。"""
    f = O.font(int(size * S))
    bb = d.textbbox(xy, s, font=f, anchor=anchor)
    pad = 12 * S
    box = (bb[0] - pad, bb[1] - pad * 0.7, bb[2] + pad, bb[3] + pad * 0.7)
    d.rounded_rectangle(box, int(10 * S), fill=O.NAVY + (225,), outline=C(col), width=max(2, int(3 * S)))
    d.text(xy, s, font=f, fill=C(col), anchor=anchor)
    O.BOXES.append(("label", box, s, 1.0))
    return box


def head(d, s, col=O.YEL, size=46):
    x0, y0, x1, y1 = region()
    label(d, ((x0 + x1) / 2, y0 + 46 * S), s, size, col)


def arrow(d, p0, p1, w, col, hd=None):
    x0, y0 = p0
    x1, y1 = p1
    L = math.hypot(x1 - x0, y1 - y0)
    if L < 2:
        return
    ux, uy = (x1 - x0) / L, (y1 - y0) / L
    hd = hd or max(14 * S, w * 3.2)
    bx, by = x1 - ux * hd, y1 - uy * hd
    d.line([x0, y0, bx, by], fill=C(col), width=int(w))
    d.polygon([(x1, y1), (bx - uy * hd * 0.6, by + ux * hd * 0.6), (bx + uy * hd * 0.6, by - ux * hd * 0.6)], fill=C(col))


def glow_disc(img, cx, cy, r, col, glow=3.0, a=1.0):
    g = int(r * glow) + 4
    lay = Image.new("RGBA", (g * 2, g * 2), (0, 0, 0, 0))
    ld = ImageDraw.Draw(lay)
    for i in range(14, 0, -1):
        rr = r + (g - r) * i / 14
        al = int(110 * a * (1 - i / 14) ** 2)
        ld.ellipse([g - rr, g - rr, g + rr, g + rr], fill=col + (al,))
    ld.ellipse([g - r, g - r, g + r, g + r], fill=col + (int(255 * a),))
    img.alpha_composite(lay, (int(cx - g), int(cy - g)))


def start_of(L, lines, cur):
    """層が出る時刻。on="言葉" ならその言葉を言い始めた瞬間、無ければ at(今の行の何割か)。"""
    key = L.get("on")
    i0 = next((i for i, l in enumerate(lines) if l["id"] == cur["id"]), 0)
    if L.get("ln"):                                      # 場面の中の何行目(id)の頭から
        l = next(l for l in lines if l["id"] == L["ln"])
        return l["start"] + L.get("at", 0.0) * (l["end"] - l["start"])
    if key:
        for l in lines[i0:]:
            if key in l.get("text", ""):
                mk = (l.get("marks") or {}).get(key)
                if mk is None:
                    mk = l["text"].index(key) / max(1, len(l["text"])) * (l["end"] - l["start"])
                return l["start"] + mk
    return cur["start"] + L.get("at", 0.0) * (cur["end"] - cur["start"])


# ---------------------------------------------------------------- 太陽系の図
TILT = 0.62 if LAND else 0.95     # 斜めに見る(縦を縮める)。縦の画面は縦に余るので、ほぼ真上から


class Cam:
    def __init__(self, cx, cy, span):
        self.cx, self.cy, self.span = cx, cy, span
        x0, y0, x1, y1 = region()
        self.ox, self.oy = (x0 + x1) / 2, (y0 + y1) / 2 + (20 if LAND else 0) * S
        self.k = (x1 - x0) * 0.92 / span

    def px(self, x, y):
        return self.ox + (x - self.cx) * self.k, self.oy - (y - self.cy) * self.k * TILT


def cam_at(view, prev_view, u):
    if prev_view is None or u >= 1:
        return Cam(*view)
    e = _ease(u)
    ls = math.log(prev_view[2]) + (math.log(view[2]) - math.log(prev_view[2])) * e
    return Cam(prev_view[0] + (view[0] - prev_view[0]) * e, prev_view[1] + (view[1] - prev_view[1]) * e, math.exp(ls))


def draw_orbits(img, cam, names, hl=()):
    d = ImageDraw.Draw(img)
    for nm, r, col, rad in PLANETS:
        if r * cam.k < 30 * S or r * cam.k > 6 * W:
            continue
        cx, cy = cam.px(0, 0)
        rx, ry = r * cam.k, r * cam.k * TILT
        w = max(2, int((4 if nm in hl else 2) * S))
        oc = (235, 205, 140) if nm in hl else (70, 90, 130)
        d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], outline=oc, width=w)
        a = PANG[nm]
        x, y = cam.px(r * math.cos(a), r * math.sin(a))
        rr = rad * S
        if nm == "地球":
            glow_disc(img, x, y, rr * 1.3, EARTHC, 2.2)
        else:
            d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=col)
        if nm in names:
            text(d, (x, y + rr + 8 * S), nm, 34, (200, 210, 230), "ma", 4)


def draw_sun(img, cam, a=1.0):
    x, y = cam.px(0, 0)
    r = max(R_SUN * cam.k, 14 * S)
    glow_disc(img, x, y, r, SUNC, 3.2 if r < 60 * S else 1.6, a)


def draw_path(img, cam, pts, frac, col, w=4, head_dot=True, dim=False):
    if frac <= 0 or len(pts) < 2:
        return
    n = max(2, int(len(pts) * min(1.0, frac)))
    sp = [cam.px(*p) for p in pts[:n]]
    d = ImageDraw.Draw(img)
    c = C(col)
    if dim:
        c = tuple(int(v * 0.55) for v in c)
    d.line(sp, fill=c, width=max(2, int(w * S)), joint="curve")
    if head_dot and frac < 1.0:
        x, y = sp[-1]
        glow_disc(img, x, y, 7 * S, CAPC, 2.4)


def _path_frac(L, t, t0):
    dur = L.get("dur", 3.0)
    return _ease((t - t0) / dur) if L.get("grow", True) else 1.0


def sc_space(img, sc, t, ctx, u_view):
    lines, cur = ctx["lines"], ctx["cur"]
    view = sc.get("view", (0, 0, 3.2))
    cam = cam_at(view, ctx.get("_prev_view"), u_view)
    names = sc.get("names", ["金星", "地球"])
    draw_orbits(img, cam, names, sc.get("hl", ()))
    draw_sun(img, cam)
    d = ImageDraw.Draw(img)
    for L in sc.get("layers", []):
        t0 = start_of(L, lines, sc["_anchor"])
        if t < t0:
            continue
        a = _ease((t - t0) / 0.4)
        kind = L["t"]
        if kind == "path":
            draw_path(img, cam, PATHS[L["name"]], _path_frac(L, t, t0), L.get("col", CAPC), L.get("w", 4), dim=L.get("dim", False))
        elif kind == "loops":                             # パーカーの輪が縮んでいく(近日点は NASA の公表値に近い並び)
            peri = [0.163, 0.129, 0.111, 0.0924, 0.0738, 0.0632, 0.0444, 0.0412]
            n = L.get("n", 8)
            frac = _ease((t - t0) / L.get("dur", 6.0)) if L.get("grow", True) else 1.0
            shown = 1 + int(frac * (n - 1) + 1e-6)
            for i, q in enumerate(peri[:shown]):
                Q = 0.73
                aa, e = (q + Q) / 2, (Q - q) / (Q + q)
                pts = [(aa * (math.cos(th) - e) * -1, aa * math.sqrt(1 - e * e) * math.sin(th)) for th in [j * math.pi / 60 for j in range(121)]]
                last = i == shown - 1
                draw_path(img, cam, pts, 1.0, (255, 150, 90) if last else (150, 110, 90), 4 if last else 2, head_dot=False)
            d = ImageDraw.Draw(img)
            if L.get("count", True):
                label(d, (region()[2] - 210 * S, region()[1] + 70 * S), f"金星のそば {min(7, shown - 1 if shown > 1 else 0)}回", 44, YL)
        elif kind == "arrow":
            p0 = L["p"]
            p1 = (p0[0] + L["v"][0], p0[1] + L["v"][1])
            q0, q1 = cam.px(*p0), cam.px(*p1)
            gx = q0[0] + (q1[0] - q0[0]) * a
            gy = q0[1] + (q1[1] - q0[1]) * a
            arrow(d, q0, (gx, gy), 9 * S, L.get("col", YL))
            if L.get("text") and a > 0.9:
                tx, ty = q1[0] + L.get("dx", 0) * S, q1[1] + L.get("dy", -40) * S
                label(d, (tx, ty), L["text"], L.get("size", 38), L.get("col", YL))
        elif kind == "label":
            at = L["pos"]
            if at == "sun":
                xy = cam.px(0, 0)
            elif at == "earth":
                xy = cam.px(*EARTH)
            elif at == "end":
                xy = cam.px(*PATHS[L["name"]][-1])
            elif at == "peri":                           # 道すじのうち、太陽にいちばん近い所
                xy = cam.px(*min(PATHS[L["name"]], key=lambda p: math.hypot(*p)))
            elif isinstance(at, str):
                xy = cam.px(*PATHS[L["name"]][int(len(PATHS[L["name"]]) * float(at))])
            else:
                xy = cam.px(*at)
            label(d, (xy[0] + L.get("dx", 0) * S, xy[1] + L.get("dy", 0) * S), L["text"], L.get("size", 38), L.get("col", O.WHITE))
        elif kind == "card":
            card_side(img, L["rows"], a)
            d = ImageDraw.Draw(img)
        elif kind == "ring":                              # 太陽を囲む距離の輪(半径 r 天文単位)
            cx, cy = cam.px(0, 0)
            rx, ry = L["r"] * cam.k, L["r"] * cam.k * TILT
            d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], outline=C(L.get("col", YL)), width=max(2, int(3 * S)))
    if sc.get("tag"):
        tag(img, sc["tag"])


def card_side(img, rows, a=1.0):
    """図の右上(縦は上)に出す数字の札。rows=[(字, 大きさ, 色)]。"""
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = region()
    fs = [(s, fit(s, sz, (560 if LAND else 900) * S), c) for s, sz, c in rows]
    w = max(O.font(int(sz * S)).getlength(s) for s, sz, c in fs) + 70 * S
    h = sum(sz * S * 1.22 for s, sz, c in fs) + 50 * S
    bx1 = x1 - 40 * S
    bx0 = bx1 - w
    by0 = y0 + (110 if LAND else 120) * S
    if not LAND:
        bx0, bx1 = (W - w) / 2, (W + w) / 2
    box = (bx0, by0, bx1, by0 + h)
    lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ld = ImageDraw.Draw(lay)
    ld.rounded_rectangle(box, int(22 * S), fill=O.NAVY + (int(230 * a),), outline=YL + (int(255 * a),), width=int(4 * S))
    yy = by0 + 25 * S
    for s, sz, c in fs:
        ld.text(((bx0 + bx1) / 2, yy), s, font=O.font(int(sz * S)), fill=C(c) + (int(255 * a),), anchor="ma")
        yy += sz * S * 1.22
    img.alpha_composite(lay)
    O.BOXES.append(("label", box, "card", 1.0))


def tag(img, s):
    """左上の「1回目」の帯。"""
    d = ImageDraw.Draw(img)
    x0, y0 = region()[0], region()[1]
    f = O.font(int(46 * S))
    w = f.getlength(s)
    bx = (x0 + 30 * S, y0 + 16 * S, x0 + 30 * S + w + 44 * S, y0 + 16 * S + 74 * S)
    d.rounded_rectangle(bx, int(14 * S), fill=O.YEL, outline=O.NAVY, width=int(3 * S))
    d.text(((bx[0] + bx[2]) / 2, (bx[1] + bx[3]) / 2), s, font=f, fill=O.NAVY, anchor="mm")
    O.BOXES.append(("label", bx, s, 1.0))


# ---------------------------------------------------------------- 全面の図
def sc_card(img, sc, t, ctx, k):
    """大きな字の札。rows=[(字, 大きさ, 色)]。"""
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = region()
    rows = sc["rows"]
    tot = sum(sz * S * 1.3 for s, sz, c in rows)
    yy = (y0 + y1) / 2 - tot / 2
    for i, (s, sz, c) in enumerate(rows):
        a = _ease((t - sc["_t0"] - i * 0.25) / 0.35)
        if a <= 0:
            continue
        sz2 = fit(s, sz, (x1 - x0) - 160 * S)
        text(d, ((x0 + x1) / 2, yy + sz * S * 0.65 * 1.3 / 1.3), s, sz2, c, "mm", 7)
        yy += sz * S * 1.3
    O.BOXES.append(("label", (x0 + 80 * S, (y0 + y1) / 2 - tot / 2, x1 - 80 * S, (y0 + y1) / 2 + tot / 2), "card", 1.0))
    if sc.get("tag"):
        tag(img, sc["tag"])


def sc_count(img, sc, t, ctx, k):
    """数え上げ。val まで 1.6 秒で数える。"""
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = region()
    u = _ease((t - sc["_t0"] - 0.2) / 1.6)
    v = sc["val"] * u
    s = sc["fmt"].format(v=v)
    sz = fit(s, sc.get("size", 190), (x1 - x0) - 160 * S)
    text(d, ((x0 + x1) / 2, (y0 + y1) / 2 - 10 * S), s, sz, YL, "mm", 9)
    if sc.get("sub"):
        text(d, ((x0 + x1) / 2, (y0 + y1) / 2 + sz * S * 0.75), sc["sub"], 50, O.WHITE, "mm", 5)
    if sc.get("head"):
        head(d, sc["head"])
    if sc.get("cans"):                                   # 筒を並べた帯(1つ＝100本)
        n = int(sc["cans"] * u)
        cw, ch = 16 * S, 40 * S
        per = int((x1 - x0 - 200 * S) / (cw * 1.5))
        for i in range(n):
            cx = x0 + 100 * S + (i % per) * cw * 1.5
            cy = (y1 - 140 * S) + (i // per) * ch * 1.3
            can(d, cx, cy, cw, ch)
    O.BOXES.append(("label", (x0 + 80 * S, (y0 + y1) / 2 - sz * S * 0.6, x1 - 80 * S, (y0 + y1) / 2 + sz * S * 0.6), "count", 1.0))


def can(d, cx, cy, w, h, col=(150, 200, 120)):
    d.rounded_rectangle([cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2], int(w * 0.25), fill=(120, 130, 140), outline=(200, 210, 220), width=max(1, int(2 * S)))
    d.rectangle([cx - w / 2 + 2, cy - h * 0.15, cx + w / 2 - 2, cy + h * 0.15], fill=col)


def sc_bars(img, sc, t, ctx, k):
    """横棒。rows=[(名前, 値, 色, 札)]。log=True なら対数で長さを決めない(そのまま)。"""
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = region()
    rows = sc["rows"]
    if sc.get("head"):
        head(d, sc["head"])
    n = len(rows)
    lx = x0 + (380 if LAND else 60) * S
    rx = x1 - (200 if LAND else 60) * S
    top = y0 + 160 * S
    gap = min(170 * S, (y1 - top - 60 * S) / max(1, n))
    for i, (nm, v, col, lab) in enumerate(rows):
        a = _ease((t - sc["_t0"] - 0.25 * i) / 0.9)
        y = top + gap * (i + 0.5)
        if LAND:
            text(d, (lx - 24 * S, y), nm, 46, O.WHITE, "rm", 5)
            bx0 = lx
        else:
            text(d, (lx, y - 52 * S), nm, 44, O.WHITE, "lm", 5)
            bx0 = lx
        L = (rx - bx0) * v / sc["vmax"] * a
        d.rounded_rectangle([bx0, y - 30 * S, bx0 + max(6 * S, L), y + 30 * S], int(10 * S), fill=C(col))
        if a > 0.95 and lab:
            text(d, (bx0 + L + 18 * S, y), lab, 48, C(col), "lm", 6) if bx0 + L + 300 * S < x1 else text(d, (bx0 + L - 18 * S, y), lab, 48, O.NAVY, "rm", 0)
    O.BOXES.append(("label", (lx - 300 * S if LAND else lx, top, rx, top + gap * n), "bars", 1.0))


def sc_earth109(img, sc, t, ctx, k):
    """太陽の直径に地球を 109 個並べる。"""
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = region()
    cy = (y0 + y1) / 2 + 30 * S
    R = min((x1 - x0) * 0.44, (y1 - y0) * 0.40)
    cx = (x0 + x1) / 2
    glow_disc(img, cx, cy, R, SUNC, 1.15)
    d = ImageDraw.Draw(img)
    n = int(109 * _ease((t - sc["_t0"] - 0.3) / 2.0))
    r = R / 109
    for i in range(n):
        x = cx - R + r + i * 2 * r
        d.ellipse([x - r, cy - r, x + r, cy + r], fill=EARTHC)
    if n:
        label(d, (cx, cy - R * 0.35), f"地球 {n}個", 56, YL)
    head(d, "太陽の直径　＝　地球109個ぶん")


def sc_canister(img, sc, t, ctx, k):
    """ガラス固化体の筒(図。実物の写真ではない)と人の大きさ。"""
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = region()
    base = y1 - 70 * S
    hpx = (y1 - y0) * 0.62
    w = hpx * 0.4 / 1.3
    cx = (x0 + x1) / 2 - (120 if LAND else 0) * S
    a = _ease((t - sc["_t0"]) / 0.6)
    top = base - hpx * a
    d.rounded_rectangle([cx - w / 2, top, cx + w / 2, base], int(w * 0.12), fill=(110, 120, 132), outline=(215, 222, 232), width=int(4 * S))
    d.ellipse([cx - w / 2, top - w * 0.12, cx + w / 2, top + w * 0.12], fill=(150, 160, 172), outline=(215, 222, 232), width=int(3 * S))
    d.rectangle([cx - w / 2 + 6 * S, top + (base - top) * 0.35, cx + w / 2 - 6 * S, top + (base - top) * 0.75], fill=(60, 120, 90))
    ph = hpx / 1.3 * 1.7                                     # 身長 1.7m の人
    px = cx + w / 2 + 160 * S
    hd = ph * 0.13
    d.ellipse([px - hd / 2, base - ph, px + hd / 2, base - ph + hd], fill=(170, 180, 200))
    d.rounded_rectangle([px - hd * 0.7, base - ph + hd * 1.05, px + hd * 0.7, base], int(hd * 0.3), fill=(170, 180, 200))
    text(d, (px, base + 12 * S), "人 1.7m", 34, GRY, "ma", 4)
    d.line([cx - w / 2 - 50 * S, top, cx - w / 2 - 50 * S, base], fill=YL, width=int(4 * S))
    if a > 0.9:
        label(d, (cx - w / 2 - 50 * S, (top + base) / 2), "高さ1.3m", 44, YL, "rm")
        if sc.get("weight"):
            label(d, (cx, top - 70 * S), "重さ500kg", 44, YL)
    text(d, (x0 + 30 * S, y0 + 20 * S), "図：ガラス固化体（イメージ）", 30, GRY, "la", 3) if LAND else text(d, (x0 + 30 * S, y0 + 100 * S), "図：ガラス固化体（イメージ）", 30, GRY, "la", 3)
    head(d, sc.get("head", "ガラス固化体"))


def sc_train(img, sc, t, ctx, k):
    """走る電車から真横に投げたボールは、斜めに進む。"""
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = region()
    gy = y1 - 160 * S
    d.line([x0 + 40 * S, gy + 40 * S, x1 - 40 * S, gy + 40 * S], fill=(90, 100, 120), width=int(6 * S))
    u = ((t - sc["_t0"]) % 4.0) / 4.0
    tx = x0 + 120 * S + (x1 - x0 - 700 * S) * u
    d.rounded_rectangle([tx, gy - 90 * S, tx + 420 * S, gy + 30 * S], int(18 * S), fill=(200, 210, 225), outline=(240, 240, 250), width=int(3 * S))
    for i in range(4):
        d.rectangle([tx + 30 * S + i * 95 * S, gy - 70 * S, tx + 100 * S + i * 95 * S, gy - 30 * S], fill=(80, 140, 200))
    sx, sy = tx + 210 * S, gy - 90 * S
    bx0 = x0 + 120 * S + 210 * S
    for j in range(int(u * 40)):
        uu = j / 40
        px = bx0 + (x1 - x0 - 700 * S) * uu
        py = gy - 90 * S - (y1 - y0) * 0.55 * uu
        d.ellipse([px - 4 * S, py - 4 * S, px + 4 * S, py + 4 * S], fill=CAPC)
    bx = sx
    by = gy - 90 * S - (y1 - y0) * 0.55 * u
    glow_disc(img, bx, by, 14 * S, CAPC, 1.8)
    d = ImageDraw.Draw(img)
    arrow(d, (bx0, gy - 120 * S), (bx0, gy - 120 * S - 200 * S), 7 * S, YL)
    text(d, (bx0 + 20 * S, gy - 230 * S), "投げた向き（真横）", 38, YL, "lm", 5)
    if u > 0.3:
        text(d, (bx + 30 * S, by), "実際の道すじ", 38, CAPC, "lm", 5)
    head(d, sc.get("head", "走る電車から、真横に投げる"))


def sc_vectors(img, sc, t, ctx, k):
    """太陽へ 10km/s、横へ 30km/s、合わさって斜め。"""
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = region()
    sc_k = (y1 - y0 - 260 * S) / 30 * (1.0 if LAND else 0.7)
    ox, oy = x0 + (x1 - x0) * (0.22 if LAND else 0.12), y1 - 90 * S
    vr = sc.get("vr", 10)
    a1 = _ease((t - sc["_t0"]) / 0.6)
    a2 = _ease((t - sc["_t0"] - 0.7) / 0.6)
    a3 = _ease((t - sc["_t0"] - 1.6) / 0.8)
    if LAND:
        arrow(d, (ox, oy), (ox, oy - vr * sc_k * a1), 12 * S, YL)
        arrow(d, (ox, oy), (ox + 30 * sc_k * a2, oy), 12 * S, BLU)
        if a1 > 0.9:
            label(d, (ox - 30 * S, oy - vr * sc_k / 2), f"太陽へ 秒速{vr}km", 42, YL, "rm")
        if a2 > 0.9:
            label(d, (ox + 15 * sc_k, oy + 50 * S), "横へ 秒速30km", 42, BLU)
        if a3 > 0:
            arrow(d, (ox, oy), (ox + 30 * sc_k * a3, oy - vr * sc_k * a3), 12 * S, CAPC)
        if a3 > 0.9:
            label(d, (ox + 30 * sc_k + 20 * S, oy - vr * sc_k - 40 * S), "合わさった道", 42, CAPC, "lm")
        glow_disc(img, ox, y0 + 40 * S, 30 * S, SUNC, 2.0)
        text(ImageDraw.Draw(img), (ox + 60 * S, y0 + 40 * S), "太陽の向き", 36, SUNC, "lm", 4)
    else:
        oy = y1 - 120 * S
        arrow(d, (ox, oy), (ox, oy - vr * sc_k * a1), 12 * S, YL)
        arrow(d, (ox, oy), (ox + 30 * sc_k * a2, oy), 12 * S, BLU)
        if a1 > 0.9:
            label(d, (ox + 120 * S, oy - vr * sc_k - 50 * S), f"太陽へ 秒速{vr}km", 40, YL)
        if a2 > 0.9:
            label(d, (ox + 15 * sc_k, oy + 50 * S), "横へ 秒速30km", 40, BLU)
        if a3 > 0:
            arrow(d, (ox, oy), (ox + 30 * sc_k * a3, oy - vr * sc_k * a3), 12 * S, CAPC)
    head(d, sc.get("head", "2つの速さを合わせると"))


def saturn(d, cx, base, h):
    """サターンV の形(図)。"""
    w = h * 10.1 / 110
    parts = [(0.00, 0.38, 1.0), (0.38, 0.60, 1.0), (0.60, 0.74, 0.66), (0.74, 0.88, 0.66), (0.88, 0.97, 0.35), (0.97, 1.0, 0.12)]
    for i, (a, b, ww) in enumerate(parts):
        y0, y1 = base - h * b, base - h * a
        col = (235, 238, 245) if i % 2 == 0 else (200, 205, 215)
        d.rectangle([cx - w * ww / 2, y0, cx + w * ww / 2, y1], fill=col)
    d.rectangle([cx - w / 2, base - h * 0.30, cx + w / 2, base - h * 0.26], fill=(40, 40, 50))
    for s in (-1, 1):
        d.polygon([(cx + s * w / 2, base - h * 0.06), (cx + s * w * 0.9, base), (cx + s * w / 2, base)], fill=(200, 205, 215))


def sc_saturn(img, sc, t, ctx, k):
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = region()
    base = y1 - 60 * S
    h = (y1 - y0) * 0.70
    cx = (x0 + x1) / 2 - (380 if LAND else 220) * S
    a = _ease((t - sc["_t0"]) / 0.7)
    saturn(d, cx, base + h * (1 - a) * 0.2, h)
    text(d, (x0 + 30 * S, y0 + 20 * S), "図：サターンV（形を簡単にしたもの）", 30, GRY, "la", 3) if LAND else text(d, (x0 + 30 * S, y0 + 100 * S), "図：サターンV（形を簡単にしたもの）", 30, GRY, "la", 3)
    label(d, (cx + h * 0.09 + 30 * S, base - h * 0.95), "高さ110m", 40, O.WHITE, "lm")
    st = sc.get("stage", 0)
    rx = (x0 + x1) / 2 + (240 if LAND else 220) * S
    if st >= 1:
        b = _ease((t - sc["_t0"] - 0.4) / 0.6)
        cw, ch = 70 * S, 180 * S
        for i in range(2):
            can(d, rx + (i - 0.5) * 120 * S, base - ch / 2 - 10 * S + (1 - b) * 40 * S, cw, ch)
        label(d, (rx, base - ch - 80 * S), "太陽へ届くのは 筒2本", 46, YL)
    if st >= 2:
        label(d, (rx, y0 + 150 * S), "日本の2,500本 → 1,300機", 46, RD)
    head(d, sc.get("head", "人を月へ運んだロケット"))


def sc_quote(img, sc, t, ctx, k):
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = region()
    a = _ease((t - sc["_t0"]) / 0.6)
    box = (x0 + 140 * S, y0 + 150 * S, x1 - 140 * S, y1 - 110 * S)
    d.rounded_rectangle(box, int(26 * S), fill=(14, 24, 52), outline=YL, width=int(4 * S))
    text(d, (box[0] + 50 * S, box[1] + 30 * S), "“", 140, YL, "la", 0)
    rows = sc["rows"]
    yy = (box[1] + box[3]) / 2 - len(rows) * 45 * S
    for s, sz, c in rows:
        text(d, ((box[0] + box[2]) / 2, yy), s, fit(s, sz, box[2] - box[0] - 120 * S), c, "mm", 4)
        yy += sz * S * 1.4
    text(d, (box[2] - 40 * S, box[3] - 24 * S), sc.get("src", ""), 32, GRY, "rb", 3)
    O.BOXES.append(("label", box, "quote", a))


def sc_areas(img, sc, t, ctx, k):
    """破片を探した広さ(12.4万km²)と北海道(8.3万km²)を同じ縮尺の正方形で並べる。"""
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = region()
    kpx = (y1 - y0 - 280 * S) / math.sqrt(124000)
    a = _ease((t - sc["_t0"]) / 0.8)
    s1, s2 = math.sqrt(124000) * kpx, math.sqrt(83424) * kpx
    cx = (x0 + x1) / 2
    base = y1 - 80 * S
    gx = 80 * S if LAND else 30 * S
    d.rectangle([cx - gx - s1, base - s1 * a, cx - gx, base], fill=(150, 70, 60), outline=RD, width=int(4 * S))
    d.rectangle([cx + gx, base - s2 * a, cx + gx + s2, base], fill=(60, 110, 150), outline=BLU, width=int(4 * S))
    if a > 0.9:
        label(d, (cx - gx - s1 / 2, base - s1 / 2), "捜索 12.4万km²", 40, O.WHITE)
        label(d, (cx + gx + s2 / 2, base - s2 / 2), "北海道 8.3万km²", 40, O.WHITE)
    head(d, sc.get("head", "1978年　コスモス954号の破片を探した広さ"))


def sc_answer(img, sc, t, ctx, k):
    """答えの並び。items の n 番目までを出し、今の行のものを光らせる。"""
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = region()
    items = sc["items"]
    n = sc["n"]
    top = y0 + 130 * S
    gap = (y1 - top - 30 * S) / len(items)
    for i, s in enumerate(items[:n]):
        a = _ease((t - sc["_t0"]) / 0.4) if i == n - 1 else 1.0
        y = top + gap * (i + 0.5)
        col = YL if i == n - 1 else (205, 212, 228)
        sz = fit(s, 50 if LAND else 44, (x1 - x0) - 260 * S)
        d.ellipse([x0 + 80 * S, y - 30 * S, x0 + 140 * S, y + 30 * S], fill=col)
        d.text((x0 + 110 * S, y), str(i + 1), font=O.font(int(40 * S)), fill=O.NAVY, anchor="mm")
        text(d, (x0 + 170 * S + (1 - a) * 40 * S, y), s, sz, col, "lm", 5)
    head(d, "答え")
    O.BOXES.append(("label", (x0 + 80 * S, top, x1 - 80 * S, top + gap * n), "answer", 1.0))


def sc_sunset(img, sc, t, ctx, k):
    """地球から見た太陽(夕日)。地平線は少しずつ上がる(足もとが回っている)。"""
    d = ImageDraw.Draw(img)
    for i in range(0, H, 3):
        u = i / H
        c = (int(30 + 200 * u), int(30 + 90 * u), int(70 + 10 * u))
        d.rectangle([0, i, W, i + 3], fill=c)
    x0, y0, x1, y1 = region()
    rise = sc.get("rise", 0.0) * _ease((t - sc["_t0"]) / 8.0)
    cx, cy = W / 2, (y0 + y1) / 2 + 40 * S
    glow_disc(img, cx, cy, 120 * S, (255, 170, 70), 3.0)
    d = ImageDraw.Draw(img)
    hy = (y0 + y1) / 2 + 150 * S - rise * 260 * S
    d.polygon([(0, hy + 40 * S), (W * 0.3, hy), (W * 0.6, hy + 25 * S), (W, hy - 10 * S), (W, H), (0, H)], fill=(20, 18, 30))
    if sc.get("text"):
        label(d, (W / 2, y0 + 70 * S), sc["text"], 46, YL)


KINDS = dict(card=sc_card, count=sc_count, bars=sc_bars, earth109=sc_earth109, canister=sc_canister, train=sc_train, vectors=sc_vectors,
             saturn=sc_saturn, quote=sc_quote, areas=sc_areas, answer=sc_answer, sunset=sc_sunset)


def paint(sc, t, ctx, u_view):
    img = stars()
    if sc["kind"] == "space":
        sc_space(img, sc, t, ctx, u_view)
    else:
        if sc["kind"] in ("bars", "card", "count", "answer", "quote"):        # 字の図は、星を少し暗く
            img.alpha_composite(Image.new("RGBA", (W, H), (4, 8, 20, 110)))
        KINDS[sc["kind"]](img, sc, t, ctx, ctx["k"])
    return img


def draw(img, dr, t, ctx):
    lines, defs = ctx["lines"], ctx["defs"]
    scs = ctx.setdefault("_scenes", mapscene.scenes(lines, defs))
    cur = ctx["cur"] or lines[0]
    i = next(j for j, l in enumerate(lines) if l["id"] == cur["id"])
    now = scs[i]
    j = i                                              # 場面の頭の行(同じ場面が続く間、時刻はそこから数える)
    while j > 0 and scs[j - 1] is now:
        j -= 1
    anchor = lines[j]
    now["_anchor"], now["_t0"] = anchor, anchor["start"]
    prev = scs[j - 1] if j > 0 else None
    u = _ease((t - anchor["start"]) / 0.5)
    # 太陽系の図どうしは溶かさず、カメラを 1.2 秒で動かす
    pv = None
    if prev is not None and prev["kind"] == "space" and now["kind"] == "space":
        pv = prev.get("view", (0, 0, 3.2))
    ctx["_prev_view"] = pv
    uv = (t - anchor["start"]) / 1.2 if pv else 1.0
    O.BOXES.clear()
    if prev is not None and now["kind"] != "space" or (prev is not None and prev["kind"] != "space"):
        if u < 1 and prev is not None:
            prev["_anchor"] = lines[j - 1]
            pj = j - 1
            while pj > 0 and scs[pj - 1] is prev:
                pj -= 1
            prev["_anchor"], prev["_t0"] = lines[pj], lines[pj]["start"]
            b = paint(prev, t, ctx, 1.0)
            O.BOXES.clear()
            a = paint(now, t, ctx, uv)
            a = Image.blend(b, a, u)
        else:
            a = paint(now, t, ctx, uv)
    else:
        a = paint(now, t, ctx, uv)
    z = 1.0 + 0.02 * (0.5 + 0.5 * math.sin(2 * math.pi * t / 16.0))
    zw, zh = int(W * z), int(H * z)
    a = a.resize((zw, zh), Image.BILINEAR).crop(((zw - W) // 2, (zh - H) // 2, (zw - W) // 2 + W, (zh - H) // 2 + H))
    img.paste(a, (0, 0))


def sfx_for(lines_def, L):
    """図の種類が変わる行の頭に「シュッ」、数字の札・数え上げ・帯が出る行に「ポン」。"""
    ev, prev = [], None
    for d in lines_def:
        s = d.get("scene")
        if d["id"] not in L or s is None:
            continue
        l = L[d["id"]]
        if prev is not None and s["kind"] != prev["kind"]:
            ev.append((l["start"], "whoosh"))
        if s["kind"] in ("count", "card") or s.get("tag") or any(x["t"] == "card" for x in s.get("layers", [])):
            ev.append((l["start"] + 0.15, "pop"))
        prev = s
    return sorted(ev)
