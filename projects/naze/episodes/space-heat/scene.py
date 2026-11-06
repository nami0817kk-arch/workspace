"""宇宙で冷えない回の画面。shots.py の地球儀・場面の絵・数字の札に、ここで描く図を足す:

  ways     熱が逃げる 3 つの道(触れる・空気が運ぶ・光)。hl=強める道の番号、cross=[消す道の番号]
  air      地上と 400km の空気を、同じ大きさの箱に粒で並べて比べる
  plate    板に太陽の光を当て、赤外線が出ていく図。color="black"|"white"、sides=1|2、temp=釣り合う温度(数え上げる)
  pairp    黒い板と白い板を並べる(日なたの温度)
  orbit    地球のまわりを回る宇宙ステーション。日なたと日陰を行き来する
  body     人の形から赤外線が出て、体の温度が 1 時間で 8℃ 下がる
  loop     中の水 → 熱を渡す所 → 外のアンモニア → 放熱板 の流れ
  radiator 放熱板を横から見る。太陽に縁を向けるように回る
  sublim   宇宙服の冷やし方: 水 → 細かい穴の板 → 氷 → 真空へ蒸発
  icons    同じ物を n 個並べる(person・bottle)
  bars     棒で比べる
  cards    答えの並べ直し

数字は sim/calc.txt(計算)と research.md(測った値・定数)。図は形を簡単にして描いている。"""
from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from naze import overlay as ov
from naze import shots, worldmap
from naze.config import H, W

HERE = Path(__file__).resolve().parent
A = HERE / "assets"
LAND = W > H
MAP = worldmap.Map(lat0=0, bases=[((-180, -60, 180, 70), 2)])     # 章の帯にだけ使う(地図の下地は描かない)
STEPS = ["1 こもる熱", "2 3つの道", "3 光の温度", "4 熱の捨て方", "5 答え"]

YEL, WHITE, NAVY, DIM = ov.YEL, ov.WHITE, ov.NAVY, ov.DIM
RED, BLUE, ORANGE = (245, 90, 75), (110, 180, 255), (255, 150, 60)
SUN = (255, 214, 90)
PANEL_W, PANEL_B = (236, 240, 246), (34, 36, 44)


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


_BACK = None


def back(img):
    """宇宙の暗い下地と星(1 本のあいだ同じ並び)。"""
    global _BACK
    if _BACK is None:
        g = np.linspace(0, 1, H, dtype=np.float32)[:, None, None]
        a = np.array([6, 10, 24], np.float32) * (1 - g) + np.array([16, 26, 54], np.float32) * g
        a = np.broadcast_to(a, (H, W, 3)).copy()
        rng = np.random.default_rng(7)
        n = 420
        sx, sy = rng.integers(0, W, n), rng.integers(0, H, n)
        a[sy, sx] = rng.uniform(70, 200, (n, 1))
        _BACK = Image.fromarray(a.astype(np.uint8)).convert("RGBA")
    img.paste(_BACK, (0, 0))


def title(d, s, y=None):
    x0, y0, x1, y1 = region()
    text(d, (W / 2, y if y is not None else y0 + 55), s, 62 if LAND else 50, YEL)


def note(d, s):
    x0, y0, x1, y1 = region()
    text(d, (W / 2, y1 - 8), s, 42 if LAND else 36, WHITE, "md")


def arrow(d, p0, p1, col, w=8, head=26):
    d.line([p0, p1], fill=col, width=w)
    ang = math.atan2(p1[1] - p0[1], p1[0] - p0[0])
    a1, a2 = ang + 2.6, ang - 2.6
    d.polygon([p1, (p1[0] + head * math.cos(a1), p1[1] + head * math.sin(a1)), (p1[0] + head * math.cos(a2), p1[1] + head * math.sin(a2))], fill=col)


def wave(d, p0, ang, length, col, t, w=6, amp=12, k=0.06, a=255):
    """赤外線の波打つ矢印(時間で流れる)。"""
    pts = []
    ca, sa = math.cos(ang), math.sin(ang)
    for s in np.linspace(0, length, 40):
        off = amp * math.sin(s * k - t * 9)
        pts.append((p0[0] + ca * s - sa * off, p0[1] + sa * s + ca * off))
    d.line(pts, fill=col + (a,), width=w)
    end = pts[-1]
    arrow(d, pts[-4], end, col + (a,), w, 22)


def sun_disc(img, cx, cy, r):
    lay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    for k in range(6, 0, -1):
        rr = r * (1 + k * 0.35)
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=SUN + (int(26 * (7 - k) / 6),))
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 236, 160, 255))
    img.alpha_composite(lay.filter(ImageFilter.GaussianBlur(3)))


# ---- 熱が逃げる 3 つの道 ----------------------------------------------------------------------------

def draw_ways(img, sc, t, u):
    back(img)
    x0, y0, x1, y1 = region()
    d = ImageDraw.Draw(img, "RGBA")
    names = ["触れる物へ伝わる", "空気が運び去る", "光(赤外線)で出る"]
    hl, cross = sc.get("hl"), sc.get("cross", [])
    for i, nm in enumerate(names):
        if LAND:
            cx, cy, cw, ch = W * (0.2 + 0.3 * i), (y0 + y1) / 2 + 20, 250, 300
        else:
            cx, cy, cw, ch = W / 2, y0 + 210 + i * 400, 300, 160
        on = hl is None or hl == i
        a = 255 if on else 90
        d.rounded_rectangle([cx - cw, cy - ch, cx + cw, cy + ch], 26, fill=NAVY + (200 if on else 120,), outline=(YEL + (255,)) if hl == i else (255, 255, 255, 90), width=4)
        ix, iy = (cx, cy - 50) if LAND else (cx - 150, cy)
        cup = [ix - 50, iy - 40, ix + 50, iy + 60]
        if i == 0:                                    # 板の上の湯のみ、下へ熱
            d.rounded_rectangle(cup, 14, fill=(230, 120, 80, a))
            d.rectangle([ix - 120, iy + 60, ix + 120, iy + 84], fill=(150, 160, 180, a))
            arrow(d, (ix, iy + 70), (ix, iy + 130), RED + (a,), 7, 20)
        elif i == 1:                                  # 湯のみのまわりを流れる空気
            d.rounded_rectangle(cup, 14, fill=(230, 120, 80, a))
            for k in range(3):
                yy = iy - 30 + k * 36
                ph = (t * 1.2 + k * 0.3) % 1.0
                xs = ix + 70 + ph * 70
                d.arc([xs - 30, yy - 14, xs + 30, yy + 14], 200, 340, fill=BLUE + (a,), width=6)
        else:                                         # 湯のみから出る波
            d.rounded_rectangle(cup, 14, fill=(230, 120, 80, a))
            for k, ang in enumerate((-0.5, 0.0, 0.5)):
                wave(d, (ix + 60, iy + 10), ang, 90, RED, t + k * 0.2, 5, 8, 0.12, a)
        tx, ty = (cx, cy + ch - 60) if LAND else (cx + 60, cy)
        text(d, (tx, ty), f"{i + 1}  {nm}", 44 if LAND else 42, WHITE if on else DIM, "mm" if LAND else "mm")
        if i in cross:
            k = ease(u * 3)
            r = (cw if LAND else ch) * 0.7 * k
            d.line([(cx - r, cy - r), (cx + r, cy + r)], fill=RED + (230,), width=16)
            d.line([(cx - r, cy + r), (cx + r, cy - r)], fill=RED + (230,), width=16)
    if sc.get("title"):
        title(d, sc["title"])


# ---- 空気の濃さ ------------------------------------------------------------------------------------

def draw_air(img, sc, t, u):
    back(img)
    x0, y0, x1, y1 = region()
    d = ImageDraw.Draw(img, "RGBA")
    if LAND:
        boxes = [(W * 0.27, (y0 + y1) / 2 + 30), (W * 0.73, (y0 + y1) / 2 + 30)]
        s = 280
    else:
        boxes = [(W / 2, y0 + 380), (W / 2, y0 + 900)]
        s = 220
    rng = np.random.default_rng(4)
    labs = [("地上", "6畳の部屋に 61kg"), ("高さ400km", "1グラムの2千万分の1")]
    for k, (cx, cy) in enumerate(boxes):
        a = ease(u * 3 - k * 0.6)
        d.rectangle([cx - s, cy - s * 0.8, cx + s, cy + s * 0.8], outline=(255, 255, 255, int(200 * a)), width=4)
        n = 700 if k == 0 else 1
        px = rng.uniform(-1, 1, n)
        py = rng.uniform(-1, 1, n)
        vx = rng.uniform(-1, 1, n)
        vy = rng.uniform(-1, 1, n)
        for i in range(n):
            xx = ((px[i] + vx[i] * t * 0.25 + 1) % 2) - 1
            yy = ((py[i] + vy[i] * t * 0.25 + 1) % 2) - 1
            q = (cx + xx * (s - 10), cy + yy * (s * 0.8 - 10))
            r = 4 if k == 0 else 7
            d.ellipse([q[0] - r, q[1] - r, q[0] + r, q[1] + r], fill=BLUE + (int(220 * a),))
        text(d, (cx, cy - s * 0.8 - 42), labs[k][0], 54 if LAND else 46, YEL if k else WHITE)
        text(d, (cx, cy + s * 0.8 + 44), labs[k][1], 44 if LAND else 40, WHITE)
    if sc.get("title"):
        title(d, sc["title"])


# ---- 光を受けて光を出す板 ---------------------------------------------------------------------------

def _plate(img, d, cx, cy, hgt, color, sides, temp, t, u, label=True, sun=True, scale=1.0):
    pw = 30 * scale
    col = PANEL_B if color == "black" else PANEL_W
    if sun:
        sx = cx - (560 if LAND else 330) * scale
        sun_disc(img, sx, cy, 70 * scale)
        d = ImageDraw.Draw(img, "RGBA")
        for k in range(5):
            yy = cy - hgt * 0.4 + k * hgt * 0.2
            ph = (t * 0.8 + k * 0.17) % 1.0
            xa = sx + 90 * scale
            xb = cx - pw - 10
            xm = xa + (xb - xa) * ph
            d.line([(xa, yy), (xb, yy)], fill=SUN + (110,), width=int(5 * scale))
            arrow(d, (xm - 40, yy), (xm, yy), SUN + (255,), int(7 * scale), int(20 * scale))
            if color == "white":                       # はね返る光
                d.line([(cx - pw - 10, yy), (cx - pw - 120 * scale, yy - 70 * scale)], fill=SUN + (90,), width=int(4 * scale))
    d.rectangle([cx - pw, cy - hgt / 2, cx + pw, cy + hgt / 2], fill=col + (255,), outline=(120, 130, 150), width=3)
    k = ease(u * 1.6)
    if k > 0.05:
        for kk in range(3):
            yy = cy - hgt * 0.3 + kk * hgt * 0.3
            wave(d, (cx + pw + 8, yy), 0.0, 150 * scale, RED, t + kk * 0.3, int(6 * scale), 10 * scale, 0.07 / scale, int(255 * k))
            if sides == 2:
                wave(d, (cx - pw - 8, yy + hgt * 0.15), math.pi + 0.35, 120 * scale, RED, t + kk * 0.3, int(6 * scale), 10 * scale, 0.07 / scale, int(255 * k))
    if temp is not None:
        v = temp * ease(u * 1.4)
        s = f"{int(round(v)):+d}℃"
        text(d, (cx, cy - hgt / 2 - 60 * scale), s, int(86 * scale), YEL if temp > 0 else BLUE)
    return d


def draw_plate(img, sc, t, u):
    back(img)
    x0, y0, x1, y1 = region()
    d = ImageDraw.Draw(img, "RGBA")
    cx = W * (0.56 if LAND else 0.58)
    cy = (y0 + y1) / 2 + 40
    d = _plate(img, d, cx, cy, 380 if LAND else 460, sc.get("color", "black"), sc.get("sides", 1), sc.get("temp"), t, u, scale=1.0 if LAND else 0.85)
    if sc.get("title"):
        title(d, sc["title"])
    if sc.get("note"):
        note(d, sc["note"])


def draw_pairp(img, sc, t, u):
    back(img)
    x0, y0, x1, y1 = region()
    d = ImageDraw.Draw(img, "RGBA")
    if LAND:
        spots = [(W * 0.30, (y0 + y1) / 2 + 60), (W * 0.78, (y0 + y1) / 2 + 60)]
    else:
        spots = [(W * 0.62, y0 + 400), (W * 0.62, y0 + 920)]
    d = ImageDraw.Draw(img, "RGBA")
    for k, ((cx, cy), (c, tp, nm)) in enumerate(zip(spots, [("black", 62, "黒い板"), ("white", -65, "白い塗料の板")])):
        uu = max(0.0, u * 1.3 - k * 0.25)
        d = _plate(img, d, cx, cy, 300 if LAND else 280, c, 2, tp, t, uu, sun=True, scale=0.62 if LAND else 0.75)
        text(d, (cx, cy + (180 if LAND else 175)), nm, 46 if LAND else 40, WHITE)
    if sc.get("title"):
        title(d, sc["title"])
    if sc.get("note"):
        note(d, sc["note"])


# ---- 地球を回る ------------------------------------------------------------------------------------

def draw_orbit(img, sc, t, u):
    back(img)
    x0, y0, x1, y1 = region()
    cx, cy = (W * 0.55, (y0 + y1) / 2 + 60) if LAND else (W / 2, (y0 + y1) / 2 + 60)
    R = 190 if LAND else 240
    orb = R * 1.5
    sun_disc(img, W * 0.07 if LAND else W * 0.1, cy if LAND else y0 + 90, 60)
    sh = Image.new("RGBA", img.size, (0, 0, 0, 0))                                                        # 地球の影(ぼかす)
    ImageDraw.Draw(sh).polygon([(cx, cy - R), (W + 50, cy - R * 0.9), (W + 50, cy + R * 0.9), (cx, cy + R)], fill=(0, 0, 8, 120))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(14)))
    d = ImageDraw.Draw(img, "RGBA")
    d.ellipse([cx - R, cy - R, cx + R, cy + R], fill=(40, 100, 180))
    d.pieslice([cx - R, cy - R, cx + R, cy + R], -90, 90, fill=(14, 30, 60))
    d.ellipse([cx - orb, cy - orb, cx + orb, cy + orb], outline=(255, 255, 255, 80), width=3)
    ang = -math.pi + (t / 4.5) * 2 * math.pi                # 4.5 秒で 1 周(90 分を縮めて)
    px, py = cx + orb * math.cos(ang), cy + orb * math.sin(ang)
    lit = not (math.cos(ang) > 0 and abs(math.sin(ang)) * orb < R)
    d.rectangle([px - 26, py - 6, px + 26, py + 6], fill=(240, 240, 250) if lit else (90, 100, 120))
    d.rectangle([px - 6, py - 22, px + 6, py + 22], fill=(220, 180, 80) if lit else (80, 80, 90))
    lab = "日なた ＋120℃" if lit else "日陰"
    text(d, (px, py - 60), lab, 44 if LAND else 40, YEL if lit else BLUE)
    if sc.get("title"):
        title(d, sc["title"])
    if sc.get("note"):
        note(d, sc["note"])


# ---- 人の体 ---------------------------------------------------------------------------------------

def draw_body(img, sc, t, u):
    back(img)
    x0, y0, x1, y1 = region()
    d = ImageDraw.Draw(img, "RGBA")
    cx = W * (0.38 if LAND else 0.5)
    cy = (y0 + y1) / 2 + (40 if LAND else -60)
    s = 1.0 if LAND else 0.9
    k = ease(u)
    warm = tuple(int(a + (b - a) * k * 0.5) for a, b in zip((255, 140, 90), (120, 150, 210)))
    d.ellipse([cx - 55 * s, cy - 250 * s, cx + 55 * s, cy - 140 * s], fill=warm)
    d.rounded_rectangle([cx - 95 * s, cy - 130 * s, cx + 95 * s, cy + 90 * s], 40, fill=warm)
    d.rounded_rectangle([cx - 85 * s, cy + 80 * s, cx - 15 * s, cy + 280 * s], 30, fill=warm)
    d.rounded_rectangle([cx + 15 * s, cy + 80 * s, cx + 85 * s, cy + 280 * s], 30, fill=warm)
    d.rounded_rectangle([cx - 150 * s, cy - 120 * s, cx - 100 * s, cy + 70 * s], 25, fill=warm)
    d.rounded_rectangle([cx + 100 * s, cy - 120 * s, cx + 150 * s, cy + 70 * s], 25, fill=warm)
    for j, ang in enumerate(np.linspace(-2.6, 2.6, 8)):
        a0 = ang - math.pi / 2
        p0 = (cx + 170 * s * math.cos(a0), cy - 20 * s + 210 * s * math.sin(a0))
        wave(d, p0, a0, 90 * s, RED, t + j * 0.15, 5, 8, 0.12)
    mode = sc.get("mode", "cool")
    if mode == "cool":
        tx = W * (0.75 if LAND else 0.5)
        ty = cy - 40 if LAND else y1 - 170
        mins = int(60 * k)
        temp = 37 - 8 * k
        text(d, (tx, ty - 80), f"{mins}分後", 54 if LAND else 46, WHITE)
        text(d, (tx, ty + 30), f"{temp:.1f}℃", 120 if LAND else 96, YEL)
    elif mode == "watts":
        tx = W * (0.75 if LAND else 0.5)
        ty = cy - 40 if LAND else y1 - 170
        text(d, (tx, ty - 70), "出す赤外線 641W", 56 if LAND else 46, RED)
        text(d, (tx, ty + 20), "作る熱 100W", 56 if LAND else 46, WHITE)
    if sc.get("title"):
        title(d, sc["title"])


# ---- 熱を運ぶ流れ ----------------------------------------------------------------------------------

def draw_loop(img, sc, t, u):
    back(img)
    x0, y0, x1, y1 = region()
    d = ImageDraw.Draw(img, "RGBA")
    if LAND:
        boxes = [((W * 0.16, 520), "中の部屋", "人と機械 → 熱"), ((W * 0.43, 520), "熱を渡す所", "水 → アンモニア"), ((W * 0.72, 520), "放熱板", "赤外線で捨てる")]
        bw, bh = 170, 120
    else:
        boxes = [((W / 2, 420), "中の部屋", "人と機械 → 熱"), ((W / 2, 800), "熱を渡す所", "水 → アンモニア"), ((W / 2, 1180), "放熱板", "赤外線で捨てる")]
        bw, bh = 250, 110
    n = len(boxes)
    shown = 1 + int(min(n - 1, u * n * 1.2))
    for i, ((cx, cy), nm, sub) in enumerate(boxes[:shown]):
        col = (WATER := (70, 150, 230)) if i == 0 else (ORANGE if i == 2 else (150, 120, 220))
        d.rounded_rectangle([cx - bw, cy - bh, cx + bw, cy + bh], 24, fill=NAVY + (220,), outline=col + (255,), width=5)
        text(d, (cx, cy - 30), nm, 52 if LAND else 48, YEL)
        text(d, (cx, cy + 45), sub, 38 if LAND else 36, WHITE)
        if i == 2:
            for k in range(3):
                if LAND:
                    wave(d, (cx + bw + 10, cy - 60 + k * 60), 0.0, 110, RED, t + k * 0.3, 5, 8, 0.12)
                else:
                    wave(d, (cx - 160 + k * 160, cy + bh + 10), math.pi / 2, 80, RED, t + k * 0.3, 5, 8, 0.12)
    for i in range(shown - 1):
        (ax, ay), _, _ = boxes[i][0], 0, 0
        (bx, by) = boxes[i + 1][0]
        col = BLUE if i == 0 else ORANGE
        if LAND:
            p0, p1 = (ax + bw + 8, ay), (bx - bw - 8, by)
        else:
            p0, p1 = (ax, ay + bh + 8), (bx, by - bh - 8)
        d.line([p0, p1], fill=col + (180,), width=10)
        ph = (t * 0.9) % 1.0
        q = (p0[0] + (p1[0] - p0[0]) * ph, p0[1] + (p1[1] - p0[1]) * ph)
        d.ellipse([q[0] - 12, q[1] - 12, q[0] + 12, q[1] + 12], fill=WHITE)
        lab = "水" if i == 0 else "アンモニア"
        mx, my = (p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2
        text(d, (mx, my - 40) if LAND else (mx + 140, my), lab, 40, col)
    if sc.get("title"):
        title(d, sc["title"])
    if sc.get("note"):
        note(d, sc["note"])


# ---- 放熱板を横から ---------------------------------------------------------------------------------

def draw_radiator(img, sc, t, u):
    back(img)
    x0, y0, x1, y1 = region()
    d = ImageDraw.Draw(img, "RGBA")
    cx, cy = (W * 0.58, (y0 + y1) / 2 + 20) if LAND else (W / 2 + 60, (y0 + y1) / 2)
    sun_disc(img, W * 0.08 if LAND else W * 0.12, cy, 60)
    d = ImageDraw.Draw(img, "RGBA")
    for k in range(5):
        yy = cy - 160 + k * 80
        arrow(d, (W * 0.14 if LAND else W * 0.2, yy), (cx - 200, yy), SUN + (150,), 5, 18)
    ang = math.radians(90 * ease(u * 1.5))            # 面を太陽へ向けた所(板が縦)から、縁を向ける所(板が横)へ
    L = 300 if LAND else 260
    dx, dy = L * math.cos(ang + math.pi / 2), L * math.sin(ang + math.pi / 2)
    d.line([(cx - dx, cy - dy), (cx + dx, cy + dy)], fill=PANEL_W, width=26)
    k = ease(u * 1.5)
    for s in (-0.6, 0.0, 0.6):
        px, py = cx + dx * s, cy + dy * s
        nx, ny = math.cos(ang), math.sin(ang)
        wave(d, (px + nx * 20, py + ny * 20), ang, 110, RED, t + s, 5, 8, 0.12, int(255 * k))
        wave(d, (px - nx * 20, py - ny * 20), ang + math.pi, 110, RED, t + s, 5, 8, 0.12, int(255 * k))
    text(d, (cx, cy + L + 70 if LAND else cy + L + 80), "太陽に縁を向ける" if u > 0.5 else "面を太陽に向けると、光を浴びる", 46 if LAND else 40, YEL if u > 0.5 else WHITE)
    if sc.get("title"):
        title(d, sc["title"])


# ---- 宇宙服の冷やし方 ---------------------------------------------------------------------------------

def draw_sublim(img, sc, t, u):
    back(img)
    x0, y0, x1, y1 = region()
    d = ImageDraw.Draw(img, "RGBA")
    xa, xb = (W * 0.18, W * 0.82) if LAND else (W * 0.08, W * 0.92)
    base = y1 - (120 if LAND else 260)
    hh = 70 if LAND else 80
    rows = [("体の熱(冷やす水の管)", (255, 140, 90)), ("水", (70, 150, 230)), ("細かい穴の板", (170, 175, 190)), ("氷", (215, 240, 255))]
    shown = 1 + int(min(3, u * 5))
    for i, (nm, col) in enumerate(rows[:shown]):
        yb = base - i * hh
        d.rectangle([xa, yb - hh, xb, yb], fill=col + (235,), outline=NAVY, width=2)
        if i == 2:
            for x in np.arange(xa + 20, xb, 36):
                d.rectangle([x, yb - hh + 8, x + 6, yb - 8], fill=(60, 64, 80))
        text(d, (xb + 20, yb - hh / 2) if LAND else (W / 2, yb - hh / 2), nm, 40 if LAND else 36, WHITE if LAND else NAVY, "lm" if LAND else "mm", sw=6 if LAND else 0)
    if shown >= 4:
        top = base - 4 * hh
        rng = np.random.default_rng(5)
        xs = rng.uniform(xa, xb, 60)
        sp = rng.uniform(0.5, 1.0, 60)
        for x, v in zip(xs, sp):
            ph = (t * v * 0.6 + x * 0.001) % 1.0
            y = top - 10 - ph * (top - y0 - 160)
            d.ellipse([x - 6, y - 6, x + 6, y + 6], fill=(220, 235, 255, int(220 * (1 - ph))))
        text(d, (W / 2, y0 + 150), "真空へ蒸発(熱を持ち去る)", 50 if LAND else 44, YEL)
    arrow(d, (W / 2, base + 60 if LAND else base + 80), (W / 2, base + 10), RED, 8, 24)
    if sc.get("title"):
        title(d, sc["title"])


# ---- 宇宙ステーション・魔法瓶・宇宙服(絵の代わりにコードで描く) -----------------------------------------------

def _station(d, cx, cy, s, t, hl=None):
    """宇宙ステーションを正面から簡単に描く: 横の骨組み・金色の太陽電池の翼 8 枚・白い放熱板 6 枚・中の部屋。"""
    L = 520 * s
    d.rectangle([cx - L, cy - 8 * s, cx + L, cy + 8 * s], fill=(190, 196, 210))
    for side in (-1, 1):                                       # 太陽電池の翼(両端に 2 本ずつ、上下に)
        for j in range(2):
            x = cx + side * (L - 60 * s - j * 120 * s)
            for up in (-1, 1):
                y0, y1 = cy + up * 18 * s, cy + up * 300 * s
                d.rectangle([x - 40 * s, min(y0, y1), x + 40 * s, max(y0, y1)], fill=(176, 132, 52), outline=(230, 196, 110), width=2)
                for k in range(1, 8):
                    yy = y0 + (y1 - y0) * k / 8
                    d.line([(x - 40 * s, yy), (x + 40 * s, yy)], fill=(120, 90, 40), width=1)
    rads = []
    for side in (-1, 1):                                       # 放熱板(翼の内側、下へ 3 枚ずつ)
        for j in range(3):
            x = cx + side * (120 * s + j * 46 * s)
            box = [x - 18 * s, cy + 14 * s, x + 18 * s, cy + 220 * s]
            d.rectangle(box, fill=(236, 240, 246), outline=(160, 168, 186), width=2)
            rads.append(box)
    d.rounded_rectangle([cx - 90 * s, cy - 40 * s, cx + 90 * s, cy + 30 * s], int(20 * s), fill=(214, 218, 228), outline=(150, 156, 170), width=2)
    d.rounded_rectangle([cx - 24 * s, cy - 110 * s, cx + 24 * s, cy + 40 * s], int(16 * s), fill=(206, 210, 222), outline=(150, 156, 170), width=2)
    if hl == "radiators":
        k = 0.5 + 0.5 * math.sin(t * 5)
        for b in rads:
            d.rectangle([b[0] - 5, b[1] - 5, b[2] + 5, b[3] + 5], outline=YEL + (int(150 + 100 * k),), width=5)
        text(d, (cx, cy + 290 * s), "放熱板 6枚", int(56 * s / 0.8) if LAND else 44, YEL)


def draw_station(img, sc, t, u):
    shots.draw_globe(img, dict(center=sc.get("center", (140, 25)), to=sc.get("to", (160, 20)), r=0.9 if LAND else 0.55, dx=0.0), u)
    lay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    g = np.linspace(0, 1, H, dtype=np.float32)[:, None]
    shade = np.clip((0.55 - g) / 0.55, 0, 1)                  # 地球を下へ見せるため、上を暗くする
    a = np.zeros((H, W, 4), np.uint8)
    a[..., 2] = 10
    a[..., 3] = (np.broadcast_to(shade, (H, W)) * 235).astype(np.uint8)
    img.alpha_composite(Image.fromarray(a))
    d = ImageDraw.Draw(img, "RGBA")
    s = (0.82 if LAND else 0.82) * (1 + 0.06 * ease(u))
    cx = W / 2 + (-30 + 60 * u) * (1 if LAND else 0.5)
    cy = H * (0.42 if LAND else 0.36)
    _station(d, cx, cy, s, t, sc.get("hl"))
    if sc.get("dark"):                                         # 右半分を地球の影に
        sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ImageDraw.Draw(sh).rectangle([W * 0.5, 0, W, H], fill=(0, 0, 10, 170))
        img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(40)))
        d = ImageDraw.Draw(img, "RGBA")
        text(d, (W * 0.25, H * 0.12 if LAND else 330), "日なた", 54 if LAND else 46, YEL)
        text(d, (W * 0.75, H * 0.12 if LAND else 330), "日陰", 54 if LAND else 46, BLUE)
    if sc.get("title"):
        title(d, sc["title"])


def draw_flask(img, sc, t, u):
    back(img)
    x0, y0, x1, y1 = region()
    d = ImageDraw.Draw(img, "RGBA")
    cx = W * (0.42 if LAND else 0.5)
    top, bot = y0 + (150 if LAND else 260), y1 - (60 if LAND else 220)
    ow, gap = (220 if LAND else 240), 34
    d.rounded_rectangle([cx - ow, top, cx + ow, bot], 50, fill=(150, 158, 172), outline=(220, 226, 236), width=6)
    d.rounded_rectangle([cx - ow + 14, top + 14, cx + ow - 14, bot - 14], 42, fill=(10, 14, 28))         # すき間(真空)
    iw = ow - 14 - gap
    d.rounded_rectangle([cx - iw, top + 14 + gap, cx + iw, bot - 14 - gap], 34, fill=(170, 178, 192), outline=(220, 226, 236), width=4)
    lv = top + 14 + gap + (bot - top) * 0.22
    d.rounded_rectangle([cx - iw + 12, lv, cx + iw - 12, bot - 26 - gap], 26, fill=(150, 90, 40))
    for k in range(3):                                         # 湯気
        ph = (t * 0.5 + k * 0.33) % 1.0
        x = cx - 60 + k * 60
        d.line([(x + 14 * math.sin(ph * 6 + k), lv - 20 - ph * 120), (x + 14 * math.sin(ph * 6 + k + 1), lv - 50 - ph * 120)], fill=(230, 230, 240, int(200 * (1 - ph))), width=6)
    k = ease(u * 2)
    for j in range(3):                                         # 熱は中の壁で止まる
        yy = lv + 60 + j * 90
        wave(d, (cx + iw - 30, yy), 0.0, gap + 10, RED, t + j * 0.3, 5, 6, 0.3, int(255 * k))
    tx = cx + ow + 40 if LAND else W / 2
    ty = (top + bot) / 2 if LAND else bot + 70
    text(d, (tx, ty), "壁と壁のすき間 ＝ 真空", 50 if LAND else 44, YEL, "lm" if LAND else "mm")
    if sc.get("title"):
        title(d, sc["title"])


def draw_suit(img, sc, t, u):
    shots.draw_globe(img, dict(center=(100, 10), to=(115, 5), r=0.9 if LAND else 0.55, dx=0.0), u)
    lay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    g = np.linspace(0, 1, H, dtype=np.float32)[:, None]
    a = np.zeros((H, W, 4), np.uint8)
    a[..., 3] = (np.broadcast_to(np.clip((0.6 - g) / 0.6, 0, 1), (H, W)) * 235).astype(np.uint8)
    img.alpha_composite(Image.fromarray(a))
    d = ImageDraw.Draw(img, "RGBA")
    s = (1.0 if LAND else 0.9)
    cx = W * (0.5 if LAND else 0.5) + 20 * math.sin(t * 0.5)
    cy = H * (0.40 if LAND else 0.36) + 12 * math.sin(t * 0.7)
    wh, ln = (240, 242, 246), (170, 176, 190)
    d.rounded_rectangle([cx - 150 * s, cy - 120 * s, cx - 60 * s, cy + 120 * s], int(24 * s), fill=(210, 214, 224), outline=ln, width=3)   # 背中の装置
    d.ellipse([cx - 70 * s, cy - 230 * s, cx + 70 * s, cy - 90 * s], fill=wh, outline=ln, width=3)
    d.ellipse([cx - 44 * s, cy - 200 * s, cx + 56 * s, cy - 120 * s], fill=(200, 150, 50))                       # 金色のバイザー
    d.rounded_rectangle([cx - 90 * s, cy - 100 * s, cx + 90 * s, cy + 110 * s], int(40 * s), fill=wh, outline=ln, width=3)
    d.rounded_rectangle([cx + 80 * s, cy - 90 * s, cx + 130 * s, cy + 60 * s], int(24 * s), fill=wh, outline=ln, width=3)
    d.rounded_rectangle([cx - 80 * s, cy + 100 * s, cx - 15 * s, cy + 300 * s], int(28 * s), fill=wh, outline=ln, width=3)
    d.rounded_rectangle([cx + 15 * s, cy + 100 * s, cx + 80 * s, cy + 290 * s], int(28 * s), fill=wh, outline=ln, width=3)
    d.rectangle([cx - 50 * s, cy - 40 * s, cx + 50 * s, cy + 10 * s], fill=(200, 205, 215), outline=ln, width=2)
    if sc.get("title"):
        title(d, sc["title"])


# ---- 並べる・棒・答え ---------------------------------------------------------------------------------

def _icon(d, kind, cx, cy, s, a):
    al = int(255 * a)
    if kind == "person":
        d.ellipse([cx - s * 0.28, cy - s, cx + s * 0.28, cy - s * 0.45], fill=(255, 180, 120, al))
        d.rounded_rectangle([cx - s * 0.42, cy - s * 0.4, cx + s * 0.42, cy + s * 0.9], int(s * 0.3), fill=(255, 150, 90, al))
    elif kind == "bottle":
        d.rectangle([cx - s * 0.16, cy - s, cx + s * 0.16, cy - s * 0.75], fill=(230, 235, 245, al))
        d.rounded_rectangle([cx - s * 0.38, cy - s * 0.8, cx + s * 0.38, cy + s], int(s * 0.2), fill=(140, 200, 255, al), outline=(255, 255, 255, al), width=3)


def draw_icons(img, sc, t, u):
    back(img)
    x0, y0, x1, y1 = region()
    d = ImageDraw.Draw(img, "RGBA")
    n, kind = sc["n"], sc["kind"]
    cols = sc.get("cols", min(n, 8 if LAND else 4) if n <= 12 else (14 if LAND else 7))
    rows = math.ceil(n / cols)
    cell = min((x1 - x0 - 160) / cols, (y1 - y0 - 240) / rows)
    s = cell * 0.40
    gx0 = W / 2 - cell * (cols - 1) / 2
    gy0 = (y0 + y1) / 2 + 30 - cell * (rows - 1) / 2
    for i in range(n):
        a = ease(u * 3.0 - i * (1.6 / max(4, n)))
        if a <= 0:
            continue
        r_, c_ = divmod(i, cols)
        _icon(d, kind, gx0 + c_ * cell, gy0 + r_ * cell - (1 - a) * 20, s, a)
    if sc.get("title"):
        title(d, sc["title"])
    if sc.get("note"):
        note(d, sc["note"])


def draw_bars(img, sc, t, u):
    back(img)
    x0, y0, x1, y1 = region()
    d = ImageDraw.Draw(img, "RGBA")
    items = sc["items"]
    vmax = max(abs(v) for _, v, _ in items)
    bx0 = x0 + (520 if LAND else 60)
    bx1 = x1 - (320 if LAND else 260)
    top = y0 + (160 if sc.get("title") else 60)
    gap = min(150 if LAND else 220, (y1 - top - 60) / len(items))
    for i, (name, v, col) in enumerate(items):
        a = ease(u * 2.4 - i * 0.35)
        y = top + i * gap
        if LAND:
            text(d, (bx0 - 30, y + 40), name, 46, WHITE, "rm")
            yb = y + 10
        else:
            text(d, (bx0, y + 10), name, 40, WHITE, "lm")
            yb = y + 50
        L = (bx1 - bx0) * abs(v) / vmax * a
        d.rounded_rectangle([bx0, yb, bx0 + max(8, L), yb + 64], 10, fill=tuple(col) + (240,))
        if a > 0.2:
            text(d, (bx0 + L + 20, yb + 32), sc.get("fmt", "{}").format(v), 50 if LAND else 44, tuple(col), "lm")
    if sc.get("title"):
        title(d, sc["title"])
    if sc.get("note"):
        note(d, sc["note"])


def draw_cards(img, sc, t, u):
    """答えの並べ直し(字幕にかからないよう詰めたもの)。"""
    back(img)
    items, n = sc["items"], sc.get("n", len(sc["items"]))
    x0, x1 = (W * 0.14, W * 0.86) if LAND else (W * 0.05, W * 0.95)
    top, gap = (H * 0.12, H * 0.136) if LAND else (H * 0.16, H * 0.125)
    hh = gap * 0.82
    d = ImageDraw.Draw(img, "RGBA")
    for i, (ttl, sub) in enumerate(items[:n]):
        a = 1.0 if i < n - 1 else ease(u * 4)
        y = top + i * gap + (1 - a) * 30
        d.rounded_rectangle([x0, y, x1, y + hh], 18, fill=NAVY + (int(225 * a),), outline=YEL + (int(255 * a),) if i == n - 1 else (255, 255, 255, int(110 * a)), width=3)
        d.ellipse([x0 + 20, y + hh / 2 - 32, x0 + 84, y + hh / 2 + 32], fill=YEL + (int(255 * a),))
        d.text((x0 + 52, y + hh / 2), str(i + 1), font=ov.font(44), fill=NAVY, anchor="mm")
        d.text((x0 + 108, y + hh / 2 - 16), ttl, font=ov.font(44 if LAND else 36), fill=(255, 255, 255, int(255 * a)), anchor="lm")
        d.text((x0 + 108, y + hh / 2 + 28), sub, font=ov.font(30 if LAND else 28), fill=DIM + (int(255 * a),), anchor="lm")
        ov.BOXES.append(("label", (x0, y, x1, y + hh), ttl, 1.0))


CUSTOM = dict(ways=draw_ways, air=draw_air, plate=draw_plate, pairp=draw_pairp, orbit=draw_orbit, body=draw_body, loop=draw_loop,
              radiator=draw_radiator, sublim=draw_sublim, icons=draw_icons, bars=draw_bars, cards=draw_cards,
              station=draw_station, flask=draw_flask, suit=draw_suit)
_orig = shots.render_one


def _render_one(img, mp, t, ctx, i, steps=None):
    sc = shots._scenes(ctx)[i]
    shot = (sc or {}).get("shot", "map")
    if shot == "card" and not sc.get("view"):
        back(img)
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
