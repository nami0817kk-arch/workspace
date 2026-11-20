"""首都圏外郭放水路の画面。屋久島の回の scene.py(青ヶ島の scene.py をそのまま使う)を写し、地図の下地を春日部のまわりに、
地下の図を自分で描く shot を足す:

  under  地下の断面(立坑・トンネル・調圧水槽・ポンプ場)。upto で見せる部品の数、深さは横より何倍かに強調して書く
  shaft  立坑 1 本の断面(本当の縦横比)。mode="free" そのまま落ちる水(時速を物理で数える)・"spiral" 壁を伝って落ちる水・"both"
  tank   調圧水槽。mode="plan" 柱 59 本を上から数える・"float" 地下水の浮力と重しの釣り合い
  flat   春日部から荒川河口までの標高の断面(ほぼ平ら)・mode="coin" 100m で 1.4cm を 1円玉 9 枚で見せる

数字は parts.py の冒頭。国土地理院の標高は sim/measure.py。2 倍で描いて縮める(縁がギザギザしない)。"""
import importlib.util
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT))
from naze import dem as demlib  # noqa: E402
from naze import fig3d, worldmap  # noqa: E402
from naze import overlay as ov  # noqa: E402

_spec = importlib.util.spec_from_file_location("aoga_scene", ROOT / "episodes" / "aogashima" / "scene.py")
base = importlib.util.module_from_spec(_spec)
sys.modules["aoga_scene"] = base
_spec.loader.exec_module(base)

LAND, W, H = base.LAND, base.W, base.H
YEL, WHITE, NAVY = base.YEL, base.WHITE, base.NAVY
RED = (240, 90, 80)
GROUND, GROUND2, ROCK = (118, 88, 58), (92, 70, 50), (70, 62, 62)
CONC, CONC_D = (170, 176, 188), (118, 124, 138)
WATER, WATER_D = (80, 205, 255), (40, 120, 190)
HOLLOW = (16, 22, 36)
GREEN = (96, 170, 80)

# ---- 地図の下地: 日本 → 関東 → 春日部のあたり → 立坑のまわり ------------------------------------------------
base.MAP = worldmap.Map(lat0=36.0, bases=[((122, 24, 150, 42), 5), ((138.2, 34.5, 141.2, 37.2), 9), ((138.7, 35.1, 140.9, 36.8), 11),
                                          ((139.3, 35.5, 140.3, 36.4), 12), ((139.62, 35.88, 139.98, 36.1), 13),
                                          ((139.72, 35.955, 139.84, 36.03), 15), ((139.795, 35.99, 139.825, 36.004), 17)])
MAP = base.MAP
base.STEPS = ["1 地下神殿", "2 お皿の土地", "3 地下の川", "4 59本の柱", "5 江戸川へ"]


def ease(u):
    return base.ease(u)


def region():
    return base.region()


def canvas():
    x0, y0, x1, y1 = region()
    w, h = x1 - x0, y1 - y0
    big = Image.new("RGBA", (w * 2, h * 2), (0, 0, 0, 0))
    return big, ImageDraw.Draw(big), (x0, y0, w, h)


def put(img, big, box):
    x0, y0, w, h = box
    img.alpha_composite(big.resize((w, h), Image.LANCZOS), (x0, y0))


def rect2(d, x0, y0, x1, y1, fill, outline=None, width=0, r=0):
    pts = [2 * x0, 2 * y0, 2 * x1, 2 * y1]
    if r:
        d.rounded_rectangle(pts, r * 2, fill=fill, outline=outline, width=width * 2)
    else:
        d.rectangle(pts, fill=fill, outline=outline, width=width * 2)


def poly2(d, pts, fill, outline=None):
    d.polygon([(2 * x, 2 * y) for x, y in pts], fill=fill, outline=outline)


def line2(d, pts, fill, width=4):
    d.line([(2 * x, 2 * y) for x, y in pts], fill=fill, width=int(2 * width), joint="curve")


def arrow2(d, a, b, fill, width=6, head=22):
    line2(d, [a, b], fill, width)
    ang = math.atan2(b[1] - a[1], b[0] - a[0])
    p1 = (b[0] - head * math.cos(ang - 0.45), b[1] - head * math.sin(ang - 0.45))
    p2 = (b[0] - head * math.cos(ang + 0.45), b[1] - head * math.sin(ang + 0.45))
    poly2(d, [b, p1, p2], fill)


def dim2(d, a, b, fill=WHITE, width=4):
    """寸法線(両端に矢)。"""
    arrow2(d, a, b, fill, width, 18)
    arrow2(d, b, a, fill, width, 18)


def text(d, xy, s, size, col=WHITE, anchor="mm", sw=6):
    base.text(d, xy, s, size, col, anchor, sw)


def title_note(img, sc):
    x0, y0, x1, y1 = region()
    d = ImageDraw.Draw(img, "RGBA")
    if sc.get("title"):
        text(d, (W / 2, y0 + 50), sc["title"], 58 if LAND else 46, YEL)
    if sc.get("note"):
        text(d, (W / 2, y1 - 10), sc["note"], 38 if LAND else 32, WHITE, "md")


def strata(d, x0, y0, x1, y1, seed=1):
    """地面(上が茶色・下へ暗く)と、層の線。"""
    n = 28
    for i in range(n):
        a = i / n
        c = tuple(int(GROUND[k] * (1 - a) + ROCK[k] * a) for k in range(3))
        rect2(d, x0, y0 + (y1 - y0) * i / n, x1, y0 + (y1 - y0) * (i + 1) / n + 1, c + (255,))
    rng = np.random.default_rng(seed)
    for _ in range(14):
        yy = y0 + (y1 - y0) * rng.uniform(0.08, 0.95)
        xx = x0 + (x1 - x0) * rng.uniform(0, 0.8)
        line2(d, [(xx, yy), (xx + (x1 - x0) * rng.uniform(0.08, 0.25), yy + rng.uniform(-3, 3))], (0, 0, 0, 40), 2)


# ---- under: 地下の断面 ---------------------------------------------------------------------------------------
KMS = [0.0, 1.22, 2.62, 4.52, 5.81]           # 第5・4・3・2・1 立坑の位置(OpenStreetMap の点から測った道のり km)
DEP = [74.5, 68.8, 74.8, 71.4, 76.5]          # 掘削深さ m(国土交通省)
KEND = 6.3                                    # ポンプ場(国土交通省の全長)


def draw_under(img, sc, t, u):
    base.back(img)
    big, d, box = canvas()
    _, _, w, h = box
    n = sc.get("upto", 6)
    mx = 90 if LAND else 40
    gx0, gx1 = mx, w - mx
    surf, bot = h * (0.26 if LAND else 0.2), h * 0.86
    dm = (bot - surf) / 82.0
    pxkm = (gx1 - gx0 - (260 if LAND else 200)) / KEND
    X = lambda km: gx0 + 20 + km * pxkm   # noqa: E731
    Y = lambda m: surf + m * dm           # noqa: E731
    ratio = dm / (pxkm / 1000.0)
    a = lambda i: ease((u * 5.2 - i * 0.55) if n > 1 else 1.0)  # noqa: E731
    strata(d, 0, surf, w, bot + 18)
    rect2(d, 0, surf - 7, w, surf, GREEN + (255,))
    tx0, tx1 = X(5.97), X(5.97) + (96 if LAND else 70)
    px0 = tx1
    px1 = px0 + (120 if LAND else 80)
    rv = px1 + (62 if LAND else 52)
    # 江戸川(右の端の水面と堤防)
    rect2(d, rv, surf - 78, w, surf, WATER_D + (255,))
    poly2(d, [(rv - 40, surf), (rv, surf - 90), (rv + 6, surf - 90), (rv + 6, surf)], GREEN + (255,))
    shafts = []
    for i, (km, dep) in enumerate(zip(KMS, DEP)):
        shafts.append((X(km), dep))
    sw = 30 if LAND else 24
    # 立坑
    ka = a(1) if n >= 2 else 0
    tun_top, tun_bot = 50.0, 61.0
    ta = a(2) if n >= 3 else 0
    if ka > 0:
        for x, dep in shafts:
            yy = surf + (Y(dep) - surf) * ka
            rect2(d, x - sw / 2 - 5, surf, x + sw / 2 + 5, yy + 5, CONC + (255,))
            rect2(d, x - sw / 2, surf, x + sw / 2, yy, HOLLOW + (255,))
    # トンネル
    if ta > 0:
        xt1 = X(KMS[0]) + (X(KMS[4]) - X(KMS[0])) * ta
        rect2(d, X(KMS[0]), Y(tun_top) - 5, xt1, Y(tun_bot) + 5, CONC + (255,))
        rect2(d, X(KMS[0]), Y(tun_top), xt1, Y(tun_bot), HOLLOW + (255,))
    # 調圧水槽・つなぎ
    ba = a(3) if n >= 4 else 0
    if ba > 0:
        rect2(d, X(KMS[4]) + sw / 2, Y(5), tx0, Y(25), CONC + (int(255 * ba),))
        rect2(d, X(KMS[4]) + sw / 2, Y(8), tx0, Y(22), HOLLOW + (int(255 * ba),))
        rect2(d, tx0, Y(3), tx1, Y(25.5), CONC + (int(255 * ba),))
        rect2(d, tx0 + 5, Y(6), tx1 - 5, Y(22), HOLLOW + (int(255 * ba),))
        for k in range(1, 5):
            px = tx0 + 5 + (tx1 - tx0 - 10) * k / 5
            rect2(d, px - 3, Y(6), px + 3, Y(22), CONC_D + (int(255 * ba),))
    # ポンプ場と江戸川への管
    pa = a(4) if n >= 5 else 0
    if pa > 0:
        rect2(d, px0, Y(0), px1 + 14, Y(23.6), CONC + (int(255 * pa),))
        rect2(d, px0 + 6, Y(2), px1 + 8, Y(21.6), (30, 50, 80, int(255 * pa)))
        rect2(d, px1 + 14, surf - 22, rv + 6, surf - 4, CONC + (int(255 * pa),))
    # 水が走る(トンネルの水・水槽がたまる・江戸川へ)
    wa = a(5) if n >= 6 else 0
    if wa > 0:
        phase = (t * 0.9) % 1.0
        xs0, xs1 = X(KMS[0]), X(KMS[4])
        rect2(d, xs0, Y(tun_top + 3), xs0 + (xs1 - xs0) * min(1.0, wa * 1.4), Y(tun_bot - 1), WATER + (200,))
        for i in range(9):
            xx = xs0 + ((i / 9 + phase) % 1.0) * (xs1 - xs0) * min(1.0, wa * 1.4)
            rect2(d, xx - 14, Y(tun_top + 5), xx + 14, Y(tun_top + 7), (255, 255, 255, 170))
        for x, dep in shafts:
            top = Y(tun_top - 22 * wa)
            rect2(d, x - sw / 2 + 2, top, x + sw / 2 - 2, Y(dep) - 2, WATER + (150,))
        lev = Y(22) - (Y(22) - Y(7)) * min(1.0, wa * 1.2)
        rect2(d, tx0 + 5, lev, tx1 - 5, Y(22), WATER + (210,))
        rect2(d, px0 + 6, Y(14), px1 + 8, Y(21.6), WATER + (170,))
        rect2(d, px1 + 14, surf - 20, rv + 6, surf - 6, WATER + (210,))
        # 江戸川へ汲み上げる矢
        arrow2(d, (px1 + 22, surf - 13), (rv - 4, surf - 13), (255, 255, 255, 230), 5, 16)
    # 寸法線
    xr = X(KMS[2]) + 55
    if n >= 3:
        dim2(d, (xr, surf + 2), (xr, Y(tun_top)), WHITE, 3)
    if n >= 2:
        xs = X(KMS[3]) - 50
        dim2(d, (xs, surf + 2), (xs, Y(DEP[3])), YEL, 3)
    if n >= 1:
        dim2(d, (X(0), surf - 46), (X(KEND), surf - 46), WHITE, 3)
    put(img, big, box)
    # ---- 字 ----
    d1 = ImageDraw.Draw(img, "RGBA")
    ox, oy = box[0], box[1]
    fs = 38 if LAND else 30
    text(d1, (ox + (X(0) + X(KEND)) / 2, oy + surf - 66), "約6.3km", fs + 6, WHITE)
    if n >= 2:
        for k, (x, dep) in enumerate(shafts):
            text(d1, (ox + x, oy + Y(dep) + 36), f"第{5 - k}", fs - 6, WHITE)
        text(d1, (ox + X(KMS[3]) - 50, oy + Y(36) + 0), "深さ約70m", fs, YEL, "rm")
    if n >= 3:
        text(d1, (ox + xr + 14, oy + Y(25)), "地下約50m", fs, WHITE, "lm")
    if n >= 4:
        text(d1, (ox + (tx0 + tx1) / 2 + 30, oy + Y(31)), "調圧水槽", fs, WHITE, "rm")
    if n >= 5:
        text(d1, (ox + px0 + 12, oy + Y(31)), "ポンプ場", fs, WHITE, "lm")
        text(d1, (ox + min(rv + (w - rv) / 2, w - 70), oy + surf - 40), "江戸川", fs, WHITE)
    note = sc.get("note") or f"深さは横の約{ratio:.0f}倍に強調して描いた図"
    text(d1, (W / 2, region()[3] - 10), note, 34 if LAND else 28, WHITE, "md")
    if sc.get("title"):
        text(d1, (W / 2, region()[1] + 50), sc["title"], 58 if LAND else 46, YEL)


# ---- shaft: 立坑 1 本 -------------------------------------------------------------------------------------
G = 9.8


def draw_shaft(img, sc, t, u):
    base.back(img)
    big, d, box = canvas()
    _, _, w, h = box
    mode = sc.get("mode", "free")
    surf = h * (0.24 if LAND else 0.2)
    bot = h * 0.9
    pm = (bot - surf) / 80.0                         # 1m の画素
    cx = w * (0.5 if LAND else 0.5)
    sw = 31.6 * pm
    top_in = surf + 14.8 * pm                        # 流入口(底から 60m 上)
    sx0, sx1 = cx - sw / 2, cx + sw / 2
    strata(d, 0, surf, w, h)
    rect2(d, 0, surf - 7, w, surf, GREEN + (255,))
    y_floor = surf + 74.8 * pm
    rect2(d, sx0 - 28, surf, sx1 + 28, y_floor + 36, CONC + (255,))
    rect2(d, sx0, surf, sx1, y_floor, HOLLOW + (255,))
    # 川と流入口(左)
    rect2(d, 0, surf - 40, sx0 - 28 - 30, surf, WATER_D + (255,))
    rect2(d, 0, top_in - 22, sx0, top_in + 22, WATER + (230,))
    rect2(d, 0, top_in - 22, sx0 - 28, top_in + 22, WATER + (230,))
    rect2(d, sx0 - 30, top_in - 28, sx0, top_in + 28, CONC_D + (255,))
    rect2(d, sx0 - 28, top_in - 18, sx0 + 2, top_in + 18, WATER + (255,))
    # 水の落ち方
    free_u, spi_u = (u, None) if mode == "free" else ((None, u) if mode == "spiral" else (min(1.0, u * 2.0), max(0.0, u * 2.0 - 1.0) if u > 0.5 else None))
    speed = None
    if free_u is not None and (mode != "both" or u <= 0.5):
        tt = ease(free_u / 0.9 if free_u < 0.9 else 1.0) * 3.5
        fall = min(60.0, 0.5 * G * tt * tt)
        v = min(math.sqrt(2 * G * 60.0), G * tt)
        speed = v * 3.6
        ytop = top_in
        ybot = top_in + fall * pm
        # 水の柱(落ちている間は細く、勢いで広がる)
        rect2(d, cx - sw * 0.14, ytop - 6, cx + sw * 0.14, ybot, WATER + (230,))
        for k in range(6):
            yy = ytop + (ybot - ytop) * (k + 0.5) / 6
            rect2(d, cx - sw * 0.2 + (k % 2) * 6, yy - 3, cx + sw * 0.2 - (k % 2) * 6, yy + 3, (255, 255, 255, 120))
        if fall >= 59.9:
            r = (u - 0.85) * 5 if u > 0.85 else 0
            rect2(d, sx0 + 6, y_floor - 24, sx1 - 6, y_floor, WATER + (220,))
            if free_u > 0.92:
                for kx in range(-4, 5):
                    xx = cx + kx * sw * 0.07
                    line2(d, [(xx, y_floor - 24), (xx + kx * 7, y_floor - 24 - abs(10 - abs(kx) * 1) * 6)], (255, 255, 255, 220), 4)
    if spi_u is not None and (mode == "spiral" or u > 0.5):
        pr = min(1.0, spi_u * 1.15 if mode == "both" else u * 1.15)
        # 壁を伝うらせん(前面の筋だけ描く)
        for k in range(5):
            pts = []
            for i in range(60):
                s = i / 59.0 * pr
                ang = s * 7.0 * math.pi + k * 0.4
                x = cx + (sw * 0.46) * math.sin(ang)
                y = top_in + s * (y_floor - top_in)
                if math.cos(ang) > -0.1:
                    pts.append((x, y))
                elif len(pts) > 1:
                    line2(d, pts, WATER + (235,), 8)
                    pts = []
                else:
                    pts = []
            if len(pts) > 1:
                line2(d, pts, WATER + (235,), 8)
        if pr > 0.97:
            rect2(d, sx0 + 6, y_floor - 12, sx1 - 6, y_floor, WATER + (200,))
        speed = None
    # 寸法線
    dim2(d, (sx1 + 70, top_in), (sx1 + 70, y_floor), YEL, 4)
    dim2(d, (sx0, surf - 62), (sx1, surf - 62), WHITE, 4)
    dim2(d, (sx0 - 80, surf + 2), (sx0 - 80, y_floor), WHITE, 3) if LAND else None
    put(img, big, box)
    d1 = ImageDraw.Draw(img, "RGBA")
    ox, oy = box[0], box[1]
    fs = 40 if LAND else 32
    text(d1, (ox + cx, oy + surf - 86), "内径 約30m", fs, WHITE)
    text(d1, (ox + sx1 + 90, oy + (top_in + y_floor) / 2), "約60m\n落ちる", fs, YEL, "lm")
    if LAND:
        text(d1, (ox + sx0 - 100, oy + (surf + y_floor) / 2), "深さ\n約70m", fs, WHITE, "rm")
    text(d1, (ox + sx0 - 120, oy + top_in - 56), "川の水", fs - 4, WHITE, "mm")
    if speed is not None:
        txt = f"時速 {speed:,.0f}km"
        text(d1, (ox + cx, oy + h * 0.5), txt, 60 if LAND else 56, YEL if speed > 100 else WHITE)
    elif mode in ("spiral", "both") and ((mode == "spiral") or u > 0.5):
        text(d1, (ox + cx, oy + h * 0.5), "壁を伝って、らせん", 44 if LAND else 40, WHITE)
    if sc.get("title"):
        text(d1, (W / 2, region()[1] + 50), sc["title"], 58 if LAND else 46, YEL)
    if sc.get("note"):
        text(d1, (W / 2, region()[3] - 10), sc["note"], 36 if LAND else 30, WHITE, "md")


# ---- tank: 調圧水槽 --------------------------------------------------------------------------------------
def draw_tank(img, sc, t, u):
    base.back(img)
    mode = sc.get("mode", "plan")
    if mode == "plan":
        return _tank_plan(img, sc, t, u)
    return _tank_float(img, sc, t, u)


def _tank_plan(img, sc, t, u):
    big, d, box = canvas()
    _, _, w, h = box
    pw = min((w * 0.74) if LAND else (w * 0.9), h * 0.5 * 177.0 / 78.0)
    ph = pw * 78.0 / 177.0
    x0, y0 = (w - pw) / 2 - (40 if LAND else 0), h * (0.27 if LAND else 0.26)
    rect2(d, x0 - 8, y0 - 8, x0 + pw + 8, y0 + ph + 8, CONC + (255,), r=8)
    rect2(d, x0, y0, x0 + pw, y0 + ph, HOLLOW + (255,))
    # 柱 59 本(5 列 × 12 から 1 つ抜いて 59。上から数える)
    cols, rows = 12, 5
    items = [(c, r) for r in range(rows) for c in range(cols)][:59]
    cnt = int(min(59, ease(u * 1.6) * 59 + 0.001)) if sc.get("count", True) else 59
    pwid = pw / 177.0 * 7.0 * 0.9
    phei = pw / 177.0 * 2.0 * 1.8
    for i, (c, r) in enumerate(items):
        if i >= cnt:
            break
        px = x0 + pw * (c + 0.5) / cols
        py = y0 + ph * (r + 0.5) / rows
        rect2(d, px - pwid / 2, py - phei / 2, px + pwid / 2, py + phei / 2, (230, 200, 130, 255) if i == cnt - 1 else CONC + (255,), r=3)
    dim2(d, (x0, y0 + ph + 44), (x0 + pw, y0 + ph + 44), WHITE, 4)
    dim2(d, (x0 + pw + 36, y0), (x0 + pw + 36, y0 + ph), WHITE, 4) if LAND else dim2(d, (x0 - 0, y0 - 36), (x0 - 0, y0 - 36), WHITE, 1)
    put(img, big, box)
    d1 = ImageDraw.Draw(img, "RGBA")
    ox, oy = box[0], box[1]
    fs = 42 if LAND else 34
    text(d1, (ox + x0 + pw / 2, oy + y0 + ph + 90), "長さ 177m", fs, WHITE)
    if LAND:
        text(d1, (ox + x0 + pw + 52, oy + y0 + ph / 2), "幅\n78m", fs, WHITE, "lm")
    else:
        text(d1, (ox + x0 + pw / 2, oy + y0 + ph + 140), "幅 78m", fs, WHITE)
    text(d1, (W / 2, oy + y0 - 58), f"柱 {cnt}本", 84 if LAND else 70, YEL)
    if sc.get("title"):
        text(d1, (W / 2, region()[1] + 50), sc["title"], 58 if LAND else 46, YEL)
    if sc.get("note"):
        text(d1, (W / 2, region()[3] - 10), sc["note"], 36 if LAND else 30, WHITE, "md")


def _tank_float(img, sc, t, u):
    big, d, box = canvas()
    _, _, w, h = box
    pw = (w * 0.76) if LAND else (w * 0.86)
    pm = pw / 177.0
    ground_y = h * (0.38 if LAND else 0.3)
    base_depth = 25.0
    bx0 = (w - pw) / 2
    tank_h = 25.5 * pm
    water_top = ground_y + 1.0 * pm
    lift_amt = 3.0 * pm
    # u: 0〜0.3 浮力が現れて持ち上がる / 0.3〜0.75 重しが足される / 0.75〜 釣り合う
    lo, hi = sc.get("span", (0.0, 1.0))
    u = lo + (hi - lo) * u                           # 行ごとに、物語のどこを見せるか
    up = ease(u / 0.3)
    wt = ease((u - 0.3) / 0.45)
    lift = lift_amt * up * (1 - wt)
    strata(d, 0, ground_y, w, h)
    rect2(d, 0, ground_y - 7, w, ground_y, GREEN + (255,))
    ov_ = Image.new("RGBA", big.size, (0, 0, 0, 0))
    ImageDraw.Draw(ov_).rectangle([0, int(2 * water_top), 2 * w, 2 * h], fill=(40, 120, 200, 85))
    big.alpha_composite(ov_)
    d = ImageDraw.Draw(big)
    by0 = ground_y + 3 * pm - lift
    by1 = by0 + tank_h
    wall = (1.0 + 2.5 * wt) * pm
    # 土の盛り(天井の上)
    soil = 3.0 * pm * wt
    if soil > 1:
        rect2(d, bx0, by0 - soil, bx0 + pw, by0, GROUND + (255,))
        rect2(d, bx0, by0 - soil - 6, bx0 + pw, by0 - soil, GREEN + (255,))
    rect2(d, bx0, by0, bx0 + pw, by1, CONC + (255,))
    rect2(d, bx0 + wall, by0 + wall, bx0 + pw - wall, by1 - wall, HOLLOW + (255,))
    for k in range(1, 12):
        px = bx0 + pw * k / 12
        if wt > 0.02:
            rect2(d, px - pm, by0 + wall, px + pm, by1 - wall, CONC_D + (int(255 * min(1, wt * 2)),))
    # 浮力(上向き)と重さ(下向き)の矢
    if up > 0.02:
        for k in range(5):
            xx = bx0 + pw * (k + 0.5) / 5
            arrow2(d, (xx, by1 + 90 * up + 10), (xx, by1 + 8), (120, 220, 255, 240), 10, 28)
    if wt > 0.1:
        for k in range(5):
            xx = bx0 + pw * (k + 0.5) / 5
            arrow2(d, (xx, by0 - soil - 30 - 70 * wt), (xx, by0 - soil - 6), (255, 170, 80, 240), 10, 28)
    put(img, big, box)
    d1 = ImageDraw.Draw(img, "RGBA")
    ox, oy = box[0], box[1]
    fs = 42 if LAND else 34
    text(d1, (ox + bx0 + pw / 2, oy + by1 + 150 + 30 * up), "地下水の浮力 25万トン以上", fs + 4, (150, 225, 255))
    if wt > 0.1:
        text(d1, (ox + bx0 + pw / 2, oy + by0 - soil - 130 - 40 * wt), "コンクリート 約30万トン ＋ 土", fs + 4, (255, 190, 110))
    if 0 < up and wt < 0.15 and u > 0.12:
        text(d1, (ox + bx0 + pw / 2, oy + by0 + (by1 - by0) / 2), "浮き上がる！", fs + 14, RED)
    if u > 0.8:
        text(d1, (ox + bx0 + pw / 2, oy + by0 + (by1 - by0) / 2), "浮かない", fs + 14, YEL)
    if sc.get("title"):
        text(d1, (W / 2, region()[1] + 50), sc["title"], 58 if LAND else 46, YEL)
    if sc.get("note"):
        text(d1, (W / 2, region()[3] - 10), sc["note"], 36 if LAND else 30, WHITE, "md")


# ---- flat: 春日部から荒川河口まで ---------------------------------------------------------------------------
_P = {}
KASUKABE, ARAKAWA = (139.7548, 35.9740), (139.8470, 35.6560)


def _profile():
    if "p" not in _P:
        dm = demlib.load(139.70, 35.62, 139.90, 36.02, z=12)
        n = 160
        hs = []
        for i in range(n + 1):
            f = i / n
            hs.append(dm.height_at(KASUKABE[0] + (ARAKAWA[0] - KASUKABE[0]) * f, KASUKABE[1] + (ARAKAWA[1] - KASUKABE[1]) * f, r=3))
        hs = np.array(hs, np.float32)
        k = 15
        pad = np.pad(hs, (k, k), mode="edge")
        sm = np.array([np.nanmedian(pad[i:i + 2 * k + 1]) for i in range(len(hs))])
        _P["p"] = sm
    return _P["p"]


def draw_flat(img, sc, t, u):
    base.back(img)
    mode = sc.get("mode", "profile")
    big, d, box = canvas()
    _, _, w, h = box
    if mode == "profile":
        sm = _profile()
        gx0, gx1 = (w * 0.12), (w * 0.9)
        gy0, gy1 = h * 0.2, h * 0.78
        ymax = 12.0
        Yp = lambda m: gy1 - (gy1 - gy0) * m / ymax   # noqa: E731
        rect2(d, gx0, gy0, gx1, gy1, (14, 26, 50, 255), outline=(255, 255, 255, 90), width=2)
        for m in (0, 5, 10):
            line2(d, [(gx0, Yp(m)), (gx1, Yp(m))], (255, 255, 255, 60), 2)
        k = ease(u * 1.5)
        n = len(sm)
        pts = [(gx0 + (gx1 - gx0) * i / (n - 1), Yp(float(max(0.0, sm[i])))) for i in range(n)]
        m = max(2, int(n * k))
        poly2(d, pts[:m] + [(pts[m - 1][0], gy1), (pts[0][0], gy1)], (110, 170, 90, 255))
        line2(d, pts[:m], YEL + (255,), 5)
        put(img, big, box)
        d1 = ImageDraw.Draw(img, "RGBA")
        ox, oy = box[0], box[1]
        fs = 38 if LAND else 30
        for mm in (0, 5, 10):
            text(d1, (ox + gx0 - 16, oy + Yp(mm)), f"{mm}m", fs, WHITE, "rm", 4)
        text(d1, (ox + gx0, oy + gy1 + 52), "春日部", fs, WHITE, "mm")
        text(d1, (ox + gx1, oy + gy1 + 52), "荒川の河口", fs, WHITE, "mm")
        text(d1, (ox + (gx0 + gx1) / 2, oy + gy1 + 52), "まっすぐ約36km", fs, WHITE, "mm")
        if k > 0.15:
            text(d1, (ox + gx0 + 30, oy + Yp(5.8) - 46), "約5.8m", fs + 4, YEL, "lm")
        if k > 0.95:
            text(d1, (ox + gx1 - 30, oy + Yp(1.0) - 56), "約1m", fs + 4, YEL, "rm")
    else:
        # 100m の板と 1円玉 9 枚
        gx0, gx1 = w * 0.1, w * 0.74
        yb = h * 0.46
        drop = 40.0                                  # 画面上は 1.4cm を大きく見せる
        k = ease(u * 1.6)
        poly2(d, [(gx0, yb), (gx1, yb + drop * k), (gx1, yb + drop * k + 18), (gx0, yb + 18)], (180, 150, 100, 255))
        line2(d, [(gx0, yb - 40), (gx1, yb - 40)], (255, 255, 255, 120), 3)
        dim2(d, (gx0, yb - 90), (gx1, yb - 90), WHITE, 4)
        coin_w, coin_h = 64, 8
        sx = gx1 + 90
        base_y = yb + drop + 80
        for i in range(9):
            if i / 9 > k + 0.01:
                break
            cy = base_y - i * (coin_h + 1)
            rect2(d, sx - coin_w / 2, cy - coin_h, sx + coin_w / 2, cy, (210, 215, 225, 255), outline=(120, 125, 140, 255), width=1, r=4)
        put(img, big, box)
        d1 = ImageDraw.Draw(img, "RGBA")
        ox, oy = box[0], box[1]
        fs = 40 if LAND else 32
        text(d1, (ox + (gx0 + gx1) / 2, oy + yb - 130), "100m", fs + 6, WHITE)
        text(d1, (ox + sx, oy + base_y + 50), "1円玉 9枚（約1.4cm）", fs, YEL)
        text(d1, (ox + gx0 + 20, oy + yb + 90), "100m進んで、これだけ下がる", fs, WHITE, "lm")
    if sc.get("title"):
        text(d1, (W / 2, region()[1] + 50), sc["title"], 58 if LAND else 46, YEL)
    if sc.get("note"):
        text(d1, (W / 2, region()[3] - 10), sc["note"], 36 if LAND else 30, WHITE, "md")


base.CUSTOM.update(bars=fig3d.draw_bars, under=draw_under, shaft=draw_shaft, tank=draw_tank, flat=draw_flat)

draw, sfx_for = base.draw, base.sfx_for
