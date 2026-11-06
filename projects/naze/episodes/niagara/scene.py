"""ナイアガラの滝の画面。下地は五大湖の立体の地図(naze/worldmap.py)と、ここで描く図(naze/shots.py に足す):

  section  滝を横から切った図。硬い岩・柔らかい岩・滝つぼ。mode="still"|"undercut"(ひさしが伸びる)|"collapse"(落ちて縁が下がる)|"retreat"(くり返す)
  profile  エリー湖からオンタリオ湖まで、川に沿って縦に切った図(高さと距離)。marks=["99m", "51m", "35km", "now", "past", "erie"]、move=(km, km)
  weir     湖の出口をせきとして横から見た図。mode="still"|"cut"(岩が10m欠けて水面が下がる。52日で5m は sim/calc.txt)
  icons    同じ物を n 個並べる(pool・plant・lake・floor)。title・note
  bars     棒で比べる。items=[(名前, 値, 色)]、unit
  pair     絵を2枚、左右(縦の画面は上下)に並べる。left/right=(絵の名前, 題)

川の線は OpenStreetMap(sim/river.json)。高さの値は research.md の測った値(エリー湖の出口 174.4m → 滝の上 151m → 滝で 51m → 峡谷 → オンタリオ湖 74m)。"""
from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from naze import overlay as ov
from naze import shots, worldmap
from naze.config import H, W

HERE = Path(__file__).resolve().parent
A = HERE / "assets"
LAND = W > H
worldmap.land_borders = lambda: []        # 国境の白い線は、川(米加の境)を太い帯で隠すので描かない
worldmap.countries = lambda: {}           # 国の縁の薄い線も同じ(この回は国の塗りを使わない)
MAP = worldmap.Map(lat0=43, bases=[((-94, 39, -72, 50), 6), ((-84, 41, -76, 45.5), 8), ((-79.8, 42.5, -78.4, 43.6), 9)])
STEPS = ["1 動く滝", "2 叩く力", "3 ブレーキ", "4 湖の出口", "5 答え"]
RIVER = [(b, a) for a, b in json.loads((HERE / "sim" / "river.json").read_text(encoding="utf-8"))["pts"]]
FALLS_LL = (-79.0755, 43.0775)

YEL, WHITE, NAVY, DIM = ov.YEL, ov.WHITE, ov.NAVY, ov.DIM
CAP, SHALE, LOW = (196, 160, 112), (112, 120, 138), (78, 72, 70)
WATER, WATER2, FOAM = (54, 128, 196), (34, 92, 158), (225, 240, 250)
RED = (240, 90, 80)


def region():
    """図を描いてよい範囲(左上の出典の隅と、下の字幕を避ける)。"""
    return (0, 110, W, 905) if LAND else (0, 230, W, 1450)


def ease(u):
    u = max(0.0, min(1.0, u))
    return u * u * (3 - 2 * u)


def text(d, xy, s, size, col=WHITE, anchor="mm", sw=6, reg=True):
    f = ov.font(size)
    d.text(xy, s, font=f, fill=col, anchor=anchor, stroke_width=sw, stroke_fill=NAVY)
    if reg:
        ov.BOXES.append(("label", d.textbbox(xy, s, font=f, anchor=anchor), s, 1.0))


def back(img):
    g = np.linspace(0, 1, H, dtype=np.float32)[:, None, None]
    a = np.array([14, 24, 46], np.float32) * (1 - g) + np.array([30, 46, 78], np.float32) * g
    img.paste(Image.fromarray(np.broadcast_to(a, (H, W, 3)).astype(np.uint8)).convert("RGBA"), (0, 0))


def sky_ground(img, horizon):
    back(img)


# ---- 滝を横から切った図 --------------------------------------------------------------------------

def draw_section(img, sc, t, u):
    """横は 0〜220m、縦は -30〜+70m(川の下流の水面を 0)。滝は右から左へ落ちる(上流が右)。"""
    back(img)
    x0, y0, x1, y1 = region()
    pad = 70 if LAND else 40
    xoff = 0.0 if LAND else 70.0              # 縦の画面は滝のまわりだけ大きく
    sx = (x1 - x0 - 2 * pad) / (220.0 - xoff)
    sy = sx * (0.78 if LAND else 1.0)
    base_y = y0 + (y1 - y0) * (0.80 if LAND else 0.66)

    def P(x, y):
        return (x0 + pad + (x - xoff) * sx, base_y - y * sy)

    mode = sc.get("mode", "still")
    lip = 120.0                    # 縁の位置(m)
    over = 0.0                     # ひさしの長さ
    fall = 0.0                     # 落ちる途中の塊(0〜1)
    cycles = 0
    if mode == "undercut":
        over = 22 * ease(u)
    elif mode == "collapse":
        over = 22.0
        fall = ease((u - 0.25) / 0.6)
    elif mode == "retreat":
        k = u * 3
        cycles = int(min(2.999, k))
        ph = k - cycles
        over = 18 * ease(ph / 0.6)
        fall = ease((ph - 0.6) / 0.35)
        lip = 120.0 + cycles * 18
    d = ImageDraw.Draw(img, "RGBA")
    top, cap_b, sh_b, bottom = 51.0, 27.0, 9.0, -30.0
    right = 220.0
    # 下の岩(峡谷の底)
    d.polygon([P(0, sh_b), P(right, sh_b), P(right, bottom), P(0, bottom)], fill=LOW)
    # 柔らかい岩: 縁の下はえぐれて、ひさしの奥まで引っこむ
    under = lip + over
    d.polygon([P(under, cap_b), P(right, cap_b), P(right, sh_b), P(under - 6, sh_b)], fill=SHALE)
    if over > 1 and fall < 1:                                  # えぐれた所(水と泡が入りこむ)
        d.polygon([P(lip, cap_b), P(under, cap_b), P(under - 6, sh_b), P(lip, sh_b)], fill=(26, 70, 120, 235))
        d.line([P(lip, cap_b), P(under, cap_b), P(under - 6, sh_b)], fill=YEL, width=4)
    # 硬い岩の板(縁から上流へ)
    cap_l = lip if fall < 1 else lip + over
    d.polygon([P(cap_l, top), P(right, top), P(right, cap_b), P(cap_l, cap_b)], fill=CAP)
    for yy in (45, 39, 33):                                   # 層の筋
        d.line([P(cap_l, yy), P(right, yy)], fill=(170, 136, 92), width=2)
    for yy in (22, 15):
        d.line([P(under, yy), P(right, yy)], fill=(96, 104, 122), width=2)
    # 落ちる塊
    if 0 < fall < 1:
        bx = lip - 4 * fall
        by = -fall * fall * 44
        r = fall * 0.5
        pts = [(lip, top), (lip + over, top), (lip + over, cap_b), (lip, cap_b)]
        cx, cy = lip + over / 2, (top + cap_b) / 2
        rot = [((px - cx) * math.cos(r) - (py - cy) * math.sin(r) + cx - (lip - bx), (px - cx) * math.sin(r) + (py - cy) * math.cos(r) + cy + by) for px, py in pts]
        d.polygon([P(*q) for q in rot], fill=CAP, outline=(120, 96, 60))
    # 上流の川(岩の上の水)と、縁から落ちる水
    edge = cap_l if fall >= 1 or mode in ("still", "undercut") else lip
    d.polygon([P(edge, top), P(right, top), P(right, top + 4), P(edge + 6, top + 4)], fill=WATER)
    ph = (t * 1.3) % 1.0
    for i in range(7):                                         # 水のカーテン(放物線)
        off = i * 2.2
        pts = []
        for s in np.linspace(0, 1, 18):
            x = edge - off * 0.3 - 9 * s - 3 * s * s
            y = top + 2 - (top + 2) * s ** 1.6
            pts.append(P(x, y))
        d.line(pts, fill=WATER2 + (210,) if i % 2 else WATER + (230,), width=max(3, int(5 * sx)))
    # 滝つぼの水と渦
    d.rectangle([P(0, 0)[0], P(0, 0)[1], P(edge + 2, 0)[0], P(0, bottom)[1]], fill=WATER + (150,))
    wl = [P(x, 0.6 * math.sin(x / 7 + t * 3)) for x in np.linspace(0, edge, 40)]
    d.line(wl, fill=FOAM + (200,), width=3)
    cxp, cyp = P(edge - 14, -9)
    rr = 11 * sx
    a0 = (t * 180) % 360
    d.arc([cxp - rr, cyp - rr * 0.6, cxp + rr, cyp + rr * 0.6], a0, a0 + 270, fill=FOAM + (230,), width=5)
    for k in range(10):                                        # しぶき
        a = (k * 0.618 + t * 0.7) % 1.0
        px, py = P(edge - 6 - 22 * a, 3 + 18 * math.sin(math.pi * a))
        d.ellipse([px - 4, py - 4, px + 4, py + 4], fill=FOAM + (int(160 * (1 - a)),))
    # 札
    lab = sc.get("labels", True)
    fs = 44 if LAND else 40
    if lab:
        text(d, P(right - 4, (top + cap_b) / 2), "硬い岩 約24m", fs, WHITE, "rm")
        text(d, P(right - 4, (cap_b + sh_b) / 2), "柔らかい岩 約18m", fs, WHITE, "rm")
        text(d, P(max(20, edge - 60), -18), "滝つぼ", fs, FOAM, "mm")
    if sc.get("height", False):
        hx = edge - 32
        d.line([P(hx, 0), P(hx, top)], fill=YEL, width=5)
        for yy in (0, top):
            d.line([P(hx - 4, yy), P(hx + 4, yy)], fill=YEL, width=5)
        text(d, P(hx - 6, top / 2), "51m", 64, YEL, "rm")
    if mode == "retreat" or sc.get("arrow"):
        ax, ay = P(min(right - 20, lip + 40), top + 9)
        bx_, by_ = P(lip - 4, top + 9)
        d.line([(bx_, ay), (ax, ay)], fill=YEL, width=6)
        d.polygon([(ax + 22, ay), (ax, ay - 14), (ax, ay + 14)], fill=YEL)
        text(d, (bx_ - 24, ay), "うしろ(上流)へ下がる", fs, YEL, "rm")
    if sc.get("title"):
        text(d, (W / 2, y0 + 50), sc["title"], 60 if LAND else 52, YEL)


# ---- 川を縦に切った図 ---------------------------------------------------------------------------

PROFILE = [(0.0, 174.4), (33.0, 172.0), (34.3, 162.0), (35.1, 151.1), (35.12, 100.1), (40.6, 92.0), (45.2, 77.5), (58.5, 74.6)]


def draw_profile(img, sc, t, u):
    back(img)
    x0, y0, x1, y1 = region()
    padl, padr = (190, 190) if LAND else (110, 60)
    zt, zb = 200.0, 90.0                   # 縦の範囲(標高 m)
    k0, k1 = sc.get("range", (-14.0, 66.0))   # 横の範囲(km、左がエリー湖)
    top_px, bot_px = y0 + (70 if LAND else 140), y1 - 20

    def P(km, z):
        return (x0 + padl + (km - k0) / (k1 - k0) * (x1 - x0 - padl - padr), top_px + (zt - z) / (zt - zb) * (bot_px - top_px))

    d = ImageDraw.Draw(img, "RGBA")
    fpos = 35.1
    mv = sc.get("move")
    if mv:
        fpos = mv[0] + (mv[1] - mv[0]) * ease(u * 1.3)
    # 地面(川の線の下を塗る)。滝の位置を動かすときは、滝の前後で高さを置き直す
    prof = list(PROFILE)
    if mv:
        dx = fpos - 35.1
        prof = [(0.0, 174.4), (33.0 + dx * 0.98, 172.0), (fpos - 0.8, 162.0), (fpos, 151.1), (fpos + 0.02, 100.1), (45.2, 77.5), (58.5, 74.6)]
    pts = [P(km, z) for km, z in prof]
    d.polygon(pts + [P(prof[-1][0], zb), P(prof[0][0], zb)], fill=(92, 82, 70))
    d.line(pts, fill=(170, 150, 120), width=4)
    # 湖
    erie_bottom = 174.4 - 64
    d.polygon([P(k0, 173.4), P(0.3, 173.4), P(0.3, 168), P(-3, erie_bottom), P(-11, erie_bottom + 6), P(k0, 160)], fill=WATER + (230,))
    d.polygon([P(58.5, 74.6), P(k1, 74.6), P(k1, zb), P(60, zb)], fill=WATER + (230,))
    text(d, P(-7, 186), "エリー湖", 50 if LAND else 40, WHITE)
    text(d, P(61.5, 112 if LAND else 120), "オンタリオ湖", 50 if LAND else 40, WHITE)
    # 川の水(線の上に薄く)
    d.line([(x, y - 3) for x, y in pts], fill=WATER + (255,), width=6)
    # 滝の印
    fx_, fy_ = P(fpos, 151.1)
    d.line([P(fpos, 151.1), P(fpos + 0.02, 100.1)], fill=FOAM, width=8)
    marks = sc.get("marks", [])
    fs = 44 if LAND else 36
    if "falls" in marks or "51m" in marks:
        text(d, (fx_, fy_ - 60), "滝", 52 if LAND else 44, YEL)
    if "51m" in marks:
        xa = P(fpos + 2.2, 0)[0]
        d.line([(xa, P(0, 151.1)[1]), (xa, P(0, 100.1)[1])], fill=YEL, width=5)
        text(d, (xa + 14, P(0, 125)[1]), "51m", 56, YEL, "lm")
    if "99m" in marks:
        xa = P(53, 0)[0]
        d.line([(xa, P(0, 173.4)[1]), (xa, P(0, 74.6)[1])], fill=WHITE, width=4)
        d.line([(P(0.3, 0)[0], P(0, 173.4)[1]), (xa + 10, P(0, 173.4)[1])], fill=(255, 255, 255, 110), width=2)
        text(d, (xa + 14, P(0, 124)[1]), "99m", 56, WHITE, "lm")
    if "35km" in marks:
        yy = P(0, 186)[1]
        gx = P(0.3, 0)[0] + (fx_ - P(0.3, 0)[0]) * ease(u * 2)
        d.line([(P(0.3, 0)[0], yy), (gx, yy)], fill=YEL, width=6)
        for xx in (P(0.3, 0)[0], fx_):
            d.line([(xx, yy - 14), (xx, yy + 14)], fill=YEL, width=5)
        text(d, ((P(0.3, 0)[0] + fx_) / 2, yy - 40), "川に沿って 35km", fs, YEL)
    if "past" in marks:
        px_, py_ = P(46.2, 151.1)
        d.line([(px_, py_ - 30), (px_, P(0, 77)[1])], fill=(255, 255, 255, 120), width=3)
        text(d, (px_, py_ - 130), "1万2千年前の滝", fs, WHITE, "mm")
        yy = py_ - 70
        d.line([(fx_ + 8, yy), (px_ - 8, yy)], fill=RED, width=6)
        d.polygon([(fx_ + 4, yy), (fx_ + 26, yy - 12), (fx_ + 26, yy + 12)], fill=RED)
        text(d, ((fx_ + px_) / 2, yy - 36), "11km", 60, RED)
    if "gorge" in marks:
        text(d, P(41, 120), "峡谷", fs, WHITE)
    if sc.get("title"):
        text(d, (W / 2, y0 + 30), sc["title"], 56 if LAND else 46, YEL)
    text(d, (x1 - 20, y0 + 6), "高さは強調して描いています", 26, DIM, "rt", 3, reg=False)


# ---- 湖の出口のせき ------------------------------------------------------------------------------

def draw_weir(img, sc, t, u):
    back(img)
    x0, y0, x1, y1 = region()
    d = ImageDraw.Draw(img, "RGBA")
    pad = 60 if LAND else 30
    sx = (x1 - x0 - 2 * pad) / 100.0          # 横 0〜100(目盛りなし)
    sy = (y1 - y0) / 34.0 * (0.72 if LAND else 0.80)   # 縦 1m あたり
    ground = y0 + (y1 - y0) * (0.70 if LAND else 0.62)

    def P(x, z):
        return (x0 + pad + x * sx, ground - z * sy)

    mode = sc.get("mode", "still")
    cut = 0.0
    drop = 0.0
    day = 0
    if mode == "cut":
        cut = 10.0 * ease(u * 4)
        k = max(0.0, (u - 0.25) / 0.75)
        day = int(round(52 * k))
        drop = 5.0 * (1 - math.exp(-2.2 * k)) / (1 - math.exp(-2.2))
    lake = 3.2 - drop
    sill_l, sill_r = 52.0, 66.0
    # 岩の地面
    d.polygon([P(0, -12), P(sill_l - 6, -12), P(sill_l, 0 - cut), P(sill_r, 0 - cut), P(sill_r + 5, -2 - cut), P(100, -9), P(100, -16), P(0, -16)], fill=(108, 96, 84))
    if cut > 0:                                                    # 欠けた所(もとの岩の形を点線で)
        q = [P(sill_l, 0), P(sill_r, 0), P(sill_r, -cut), P(sill_l, -cut), P(sill_l, 0)]
        for (ax_, ay_), (bx2, by2) in zip(q, q[1:]):
            for s_ in np.linspace(0, 1, 12)[::2]:
                e_ = min(1, s_ + 1 / 12)
                d.line([(ax_ + (bx2 - ax_) * s_, ay_ + (by2 - ay_) * s_), (ax_ + (bx2 - ax_) * e_, ay_ + (by2 - ay_) * e_)], fill=(255, 255, 255, 170), width=3)
    # 湖の水
    d.polygon([P(0, lake), P(sill_l, lake), P(sill_l, 0 - cut), P(sill_l - 6, -12), P(0, -12)], fill=WATER + (235,))
    # せきを越える水
    crest = -cut
    hh = 3.2 - drop if mode == "cut" else 3.2
    ov_pts = [P(sill_l, lake), P(sill_l + 6, crest + hh * 0.66), P(sill_r, crest + hh * 0.66 * 0.95), P(sill_r + 4, crest - 1), P(sill_r + 9, crest - 5), P(100, -8.4)]
    under = [P(100, -9), P(sill_r + 5, -2 - cut), P(sill_r, crest), P(sill_l, crest)]
    d.polygon(ov_pts + under, fill=WATER2 + (235,))
    for i in range(8):                                            # 流れの筋
        s = ((t * 0.6 + i / 8) % 1.0)
        xx = sill_l + 2 + s * (100 - sill_l - 2)
        zz = crest + hh * 0.5 if xx < sill_r else crest - (xx - sill_r) * 0.3
        a, b = P(xx, zz), P(xx + 3, zz - (0 if xx < sill_r else 0.9))
        d.line([a, b], fill=FOAM + (180,), width=3)
    fs = 46 if LAND else 38
    text(d, P(20, 3.2 + 6.0), "エリー湖", 56 if LAND else 44, WHITE)
    if mode != "cut":
        text(d, P((sill_l + sill_r) / 2, crest - 6), "出口の岩", fs, (230, 210, 180))
    text(d, P(86, -2), "ナイアガラ川へ", fs, WHITE)
    # 水の高さの物差し
    hx = sill_l - 3
    if mode != "cut":
        d.line([P(hx, crest), P(hx, lake)], fill=YEL, width=5)
        for zz in (crest, lake):
            d.line([P(hx - 1.2, zz), P(hx + 1.2, zz)], fill=YEL, width=5)
        text(d, P(hx - 2, (crest + lake) / 2), f"岩より {lake - crest:.1f}m 上", 50 if LAND else 40, YEL, "rm")
    else:
        for s_ in np.linspace(0, 1, 30)[::2]:                       # もとの水面
            d.line([P(sill_l * s_, 3.2), P(sill_l * min(1, s_ + 1 / 30), 3.2)], fill=(255, 255, 255, 200), width=3)
        text(d, P(sill_l - 1, 3.2 + 1.8), "もとの水面", 36 if LAND else 30, WHITE, "rm")
        text(d, P(26, -6.5), f"{day}日目　水面 {drop:.1f}m 下がる", 56 if LAND else 44, YEL)
        if cut > 0.5:
            text(d, P((sill_l + sill_r) / 2, -cut - 4), "岩が 10m 欠けた", fs, RED)
    if sc.get("title"):
        text(d, (W / 2, y0 + 40), sc["title"], 56 if LAND else 46, YEL)
    text(d, (x1 - 20, y1 - 10), "高さは強調して描いています", 26, DIM, "rd", 3, reg=False)


# ---- 並べる・棒・絵2枚 ---------------------------------------------------------------------------

def _icon(d, kind, cx, cy, s, a):
    A_ = int(255 * a)
    if kind == "pool":
        d.rounded_rectangle([cx - s, cy - s * 0.55, cx + s, cy + s * 0.55], 8, fill=WATER + (A_,), outline=WHITE + (A_,), width=3)
        for j in range(1, 4):
            yy = cy - s * 0.55 + j * s * 1.1 / 4
            d.line([(cx - s + 6, yy), (cx + s - 6, yy)], fill=FOAM + (int(A_ * 0.7),), width=2)
    elif kind == "plant":
        d.rectangle([cx - s, cy - s * 0.2, cx + s, cy + s * 0.6], fill=(200, 206, 220, A_))
        d.polygon([(cx - s, cy - s * 0.2), (cx - s * 0.4, cy - s * 0.6), (cx - s * 0.4, cy - s * 0.2)], fill=(170, 176, 190, A_))
        d.rectangle([cx + s * 0.35, cy - s * 1.0, cx + s * 0.6, cy - s * 0.2], fill=(170, 176, 190, A_))
        d.text((cx, cy + s * 0.2), "100万kW", font=ov.font(int(s * 0.38)), fill=NAVY + (A_,), anchor="mm")
    elif kind == "lake":
        d.ellipse([cx - s * 0.9, cy - s * 0.5, cx + s * 0.9, cy + s * 0.5], fill=WATER + (A_,), outline=FOAM + (A_,), width=2)
    elif kind == "floor":
        d.rectangle([cx - s, cy - s * 0.45, cx + s, cy + s * 0.45], fill=(200, 206, 220, A_), outline=NAVY + (A_,), width=2)


def draw_icons(img, sc, t, u):
    back(img)
    x0, y0, x1, y1 = region()
    d = ImageDraw.Draw(img, "RGBA")
    n, kind = sc["n"], sc["kind"]
    if kind == "floor":                                     # 階を積んだビル
        s = (y1 - y0 - 160) / n
        bw = 150 if LAND else 120
        cx = W * (0.62 if LAND else 0.5)
        shown = int(round(n * ease(u * 2.2)))
        for i in range(shown):
            yb = y1 - 30 - i * s
            d.rectangle([cx - bw, yb - s + 2, cx + bw, yb], fill=(200, 206, 220), outline=NAVY, width=1)
            for wx in range(-bw + 14, bw - 10, 34):
                d.rectangle([cx + wx, yb - s * 0.75, cx + wx + 16, yb - s * 0.3], fill=(90, 120, 170))
        text(d, (cx + bw + 30, y1 - 30 - shown * s), f"{shown}階", 64 if LAND else 52, YEL, "lm")
    else:
        cols = sc.get("cols", min(n, 5 if LAND else 3) if n <= 12 else (10 if LAND else 6))
        rows = math.ceil(n / cols)
        cell = min((x1 - x0 - 160) / cols, (y1 - y0 - 220) / rows)
        s = cell * 0.40
        gx0 = W / 2 - cell * (cols - 1) / 2
        gy0 = (y0 + y1) / 2 + 40 - cell * (rows - 1) / 2
        for i in range(n):
            a = ease(u * 2.5 * n / max(1, n) * 1.4 - i * (1.0 / max(4, n)) * 0.9)
            if a <= 0:
                continue
            r_, c_ = divmod(i, cols)
            _icon(d, kind, gx0 + c_ * cell, gy0 + r_ * cell - (1 - a) * 20, s, a)
    if sc.get("title"):
        text(d, (W / 2, y0 + 60), sc["title"], 70 if LAND else 56, YEL)
    if sc.get("note"):
        text(d, (W / 2, y1 - 6 if kind != "floor" else y0 + 140), sc["note"], 44 if LAND else 38, WHITE, "md" if kind != "floor" else "mm")


def draw_bars(img, sc, t, u):
    back(img)
    x0, y0, x1, y1 = region()
    d = ImageDraw.Draw(img, "RGBA")
    items = sc["items"]
    vmax = max(v for _, v, _ in items)
    bx0 = x0 + (520 if LAND else 60)
    bx1 = x1 - (320 if LAND else 260)
    top = y0 + (140 if sc.get("title") else 60)
    gap = min(150 if LAND else 220, (y1 - top) / len(items))
    for i, (name, v, col) in enumerate(items):
        a = ease(u * 2.4 - i * 0.35)
        y = top + i * gap
        if LAND:
            text(d, (bx0 - 30, y + 40), name, 46, WHITE, "rm")
            yb = y + 10
        else:
            text(d, (bx0, y + 10), name, 40, WHITE, "lm")
            yb = y + 50
        L = (bx1 - bx0) * v / vmax * a
        d.rounded_rectangle([bx0, yb, bx0 + max(8, L), yb + 64], 10, fill=tuple(col) + (240,))
        if a > 0.2:
            text(d, (bx0 + L + 20, yb + 32), sc.get("fmt", "{}").format(v), 50 if LAND else 44, tuple(col), "lm")
    if sc.get("title"):
        text(d, (W / 2, y0 + 50), sc["title"], 60 if LAND else 48, YEL)
    if sc.get("note"):
        text(d, (W / 2, y1 - 10), sc["note"], 42 if LAND else 36, WHITE, "md")


def draw_pair(img, sc, t, u):
    back(img)
    halves = []
    for side in ("left", "right"):
        name, title = sc[side]
        tmp = Image.new("RGBA", (W, H))
        shots.draw_illust(tmp, dict(path=str(A / f"illust_{name}.jpg"), pan=(0, 0, 0.03, 0.02)), u)
        halves.append((tmp, title))
    d = ImageDraw.Draw(img)
    if LAND:
        for k, (tmp, title) in enumerate(halves):
            img.paste(tmp.crop((W // 4, 0, W // 4 + W // 2, H)), (k * W // 2, 0))
        d.line([(W // 2, 0), (W // 2, H)], fill=WHITE, width=4)
        for k, (_, title) in enumerate(halves):
            text(d, (W // 4 + k * W // 2, 170), title, 64, YEL)
    else:
        top, bot = 230, 1450
        hh = (bot - top) // 2
        for k, (tmp, title) in enumerate(halves):
            cut = tmp.resize((W * 2, H * 2 * 1)).crop((W // 2, H - hh // 2 - 200, W // 2 + W, H + hh // 2 - 200))
            img.paste(cut.resize((W, hh)), (0, top + k * hh))
            text(d, (W / 2, top + k * hh + 70), title, 56, YEL)
        d.line([(0, top + hh), (W, top + hh)], fill=WHITE, width=4)
    d.text((W - 36, H - 40 if LAND else 1440), "イメージ", font=ov.font(28), fill=(230, 230, 230), anchor="rd", stroke_width=3, stroke_fill=NAVY)


def draw_cards(img, sc, t, u):
    """答えの並べ直し(shots.draw_cards を、字幕にかからないよう詰めたもの)。"""
    shots._blur_back(img, MAP, sc, t)
    items, n = sc["items"], sc.get("n", len(sc["items"]))
    x0, x1 = (W * 0.16, W * 0.84) if LAND else (W * 0.06, W * 0.94)
    top, gap = (H * 0.12, H * 0.136) if LAND else (H * 0.16, H * 0.125)
    hh = gap * 0.82
    d = ImageDraw.Draw(img, "RGBA")
    for i, (title, sub) in enumerate(items[:n]):
        a = 1.0 if i < n - 1 else ease(u * 4)
        y = top + i * gap + (1 - a) * 30
        d.rounded_rectangle([x0, y, x1, y + hh], 18, fill=NAVY + (int(225 * a),), outline=YEL + (int(255 * a),) if i == n - 1 else (255, 255, 255, int(110 * a)), width=3)
        d.ellipse([x0 + 20, y + hh / 2 - 32, x0 + 84, y + hh / 2 + 32], fill=YEL + (int(255 * a),))
        d.text((x0 + 52, y + hh / 2), str(i + 1), font=ov.font(44), fill=NAVY, anchor="mm")
        d.text((x0 + 108, y + hh / 2 - 16), title, font=ov.font(46 if LAND else 40), fill=(255, 255, 255, int(255 * a)), anchor="lm")
        d.text((x0 + 108, y + hh / 2 + 28), sub, font=ov.font(30), fill=DIM + (int(255 * a),), anchor="lm")
        ov.BOXES.append(("label", (x0, y, x1, y + hh), title, 1.0))


CUSTOM = dict(cards=draw_cards, section=draw_section, profile=draw_profile, weir=draw_weir, icons=draw_icons, bars=draw_bars, pair=draw_pair)
_orig = shots.render_one


def _render_one(img, mp, t, ctx, i, steps=None):
    sc = shots._scenes(ctx)[i]
    shot = (sc or {}).get("shot", "map")
    if shot not in CUSTOM:
        return _orig(img, mp, t, ctx, i, steps)
    lines = ctx["lines"]
    j = i
    while j > 0 and shots._scenes(ctx)[j - 1] is sc:
        j -= 1
    k = i
    while k + 1 < len(lines) and shots._scenes(ctx)[k + 1] is sc:
        k += 1
    t0 = worldmap.start_of(sc, lines, lines[j]) if sc.get("on") else lines[j]["start"]
    t1 = lines[k]["end"]
    u = max(0.0, min(1.0, (t - t0) / max(1e-6, t1 - t0)))
    CUSTOM[shot](img, sc, t, u)
    if steps and sc.get("step") is not None:
        mp.steps_band(img, steps, sc["step"])


shots.render_one = _render_one


def draw(img, dr, t, ctx):
    shots.draw(img, t, ctx, MAP, steps=STEPS if LAND else None)


def sfx_for(lines_def, L):
    return shots.sfx(lines_def, L)
