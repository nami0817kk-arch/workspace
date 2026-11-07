"""小さい動物ほどたくさん食べる(トガリネズミ)の画面。地図は使わず、場面の絵(shots の illust、Gemini と FLUX)と、ここで描く図:

  big      大きな数字(暗い下地)
  cubes    サイコロを切ると表面が広がる(n=1 か 10)
  chart    体重と、体重1gあたりのエネルギー(クライバーの式、両方とも対数)。n=何匹目まで点を置くか
  heart    心臓が打つ速さ(items=[(名前, 回/分, 色)])
  bars     棒で比べる。cards は答えの並べ直し

数字は sim/calc.txt と sim/facts.md。"""
from __future__ import annotations

import math
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from naze import overlay as ov
from naze import shots, worldmap
from naze.config import CACHE, H, W

HERE = Path(__file__).resolve().parent
LAND = W > H
STEPS = ["1 小さすぎる体", "2 表面と体積", "3 燃やし続ける体", "4 食べ続ける", "5 答え"]
YEL, WHITE, NAVY, DIM = ov.YEL, ov.WHITE, ov.NAVY, ov.DIM
RED, BLUE, ICE = (240, 90, 80), (120, 190, 255), (226, 238, 248)


def region():
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
    a = np.array([10, 20, 40], np.float32) * (1 - g) + np.array([24, 40, 70], np.float32) * g
    img.paste(Image.fromarray(np.broadcast_to(a, (H, W, 3)).astype(np.uint8)).convert("RGBA"), (0, 0))



# ---- 地図(この回は使わない。描く道具が下地を求めるので世界の地図を 1 枚だけ置く) -------------------------
MAP = worldmap.Map(lat0=20, bases=[((-180, -60, 179.99, 84), 4)])


def draw_big(img, sc, t, u):
    """暗い下地に大きな数字。sub は上、note は下。count=True で数字が数え上がる。"""
    back(img)
    d = ImageDraw.Draw(img, "RGBA")
    x0, y0, x1, y1 = region()
    cy = (y0 + y1) / 2 - (20 if LAND else 60)
    big = sc["big"]
    if sc.get("count", True):
        big = worldmap.count_text(big, min(1.0, u * 2.2) * 9.0 / 0.9) if hasattr(worldmap, "count_text") else big
    a = ease(u * 4)
    if sc.get("sub"):
        text(d, (W / 2, cy - (130 if LAND else 150)), sc["sub"], 54 if LAND else 50, WHITE)
    f = ov.font(int((170 if LAND else 150) * (0.85 + 0.15 * a)))
    d.text((W / 2, cy), big, font=f, fill=YEL, anchor="mm", stroke_width=10, stroke_fill=NAVY)
    ov.BOXES.append(("label", d.textbbox((W / 2, cy), big, font=f, anchor="mm"), big, 1.0))
    if sc.get("note"):
        text(d, (W / 2, cy + (140 if LAND else 160)), sc["note"], 40 if LAND else 38, DIM)


def _cube(d, cx, cy, s, col, a=255):
    """斜めから見たサイコロ(前・上・横の 3 面)。cx, cy は前の面の左下。"""
    k = s * 0.45
    d.polygon([(cx, cy), (cx + s, cy), (cx + s, cy - s), (cx, cy - s)], fill=col + (a,), outline=NAVY + (a,))
    d.polygon([(cx, cy - s), (cx + s, cy - s), (cx + s + k, cy - s - k), (cx + k, cy - s - k)],
              fill=tuple(min(255, int(c * 1.25)) for c in col) + (a,), outline=NAVY + (a,))
    d.polygon([(cx + s, cy), (cx + s + k, cy - k), (cx + s + k, cy - s - k), (cx + s, cy - s)],
              fill=tuple(int(c * 0.7) for c in col) + (a,), outline=NAVY + (a,))


def draw_cubes(img, sc, t, u):
    """1 辺 1cm のサイコロを n × n × n に切る。左は 1 個、右は切ったもの。表面の広さを下に。"""
    back(img)
    d = ImageDraw.Draw(img, "RGBA")
    x0, y0, x1, y1 = region()
    n = sc.get("n", 1)
    S = 300 if LAND else 330
    base = y0 + (y1 - y0) * (0.72 if LAND else 0.62)
    if n == 1 or not LAND:
        cx = W / 2 - S / 2 - (0 if n == 1 else 0)
    if n == 1:
        _cube(d, W / 2 - S * 0.6, base, S, (230, 200, 120))
        text(d, (W / 2, base + 70), sc.get("label", "1辺 1cm ・ 表面 6平方cm"), 48 if LAND else 40, WHITE)
    else:
        L = W * 0.27 if LAND else W / 2
        R = W * 0.70 if LAND else W / 2
        if LAND:
            _cube(d, L - S * 0.6, base, S, (230, 200, 120))
            text(d, (L, base + 70), "表面 6平方cm", 46, WHITE)
        k = ease(u * 1.8)
        m = min(n, 10)
        s = S / m
        gap = s * 0.35 * k
        ox = R - (S + gap * (m - 1)) * 0.6
        oy = (base if LAND else base)
        for zz in range(m - 1, -1, -1):
            for yy in range(m):
                for xx in range(m):
                    cx = ox + xx * (s + gap) + zz * (s + gap) * 0.45
                    cy = oy - yy * (s + gap) - zz * (s + gap) * 0.45
                    _cube(d, cx, cy, s, (230, 200, 120))
        text(d, (R, base + 70), sc.get("label", "1,000個に切ると 表面 60平方cm"), 46 if LAND else 38, YEL)
    if sc.get("title"):
        text(d, (W / 2, y0 + 55), sc["title"], 58 if LAND else 46, YEL)
    if sc.get("note"):
        text(d, (W / 2, y1 - 10), sc["note"], 40 if LAND else 34, WHITE, "md")


CHART = [("コビトジャコウネズミ", 0.002), ("ヨーロッパトガリネズミ", 0.009), ("人", 60), ("ゾウ", 6000)]


def draw_chart(img, sc, t, u):
    """体重(横、対数)と、体重1gあたりのエネルギー(縦、対数)。クライバーの式の線に動物の点を順に置く。"""
    back(img)
    d = ImageDraw.Draw(img, "RGBA")
    x0, y0, x1, y1 = region()
    gx0, gx1 = x0 + (260 if LAND else 150), x1 - (120 if LAND else 60)
    gy0, gy1 = y0 + (150 if sc.get("title") else 80), y1 - (120 if LAND else 160)
    lm0, lm1 = math.log10(0.001), math.log10(10000)
    e = lambda kg: 70 * kg ** 0.75 / (kg * 1000)  # noqa: E731  体重1gあたり kcal/日
    le0, le1 = math.log10(e(10000)), math.log10(e(0.001))
    X = lambda kg: gx0 + (math.log10(kg) - lm0) / (lm1 - lm0) * (gx1 - gx0)  # noqa: E731
    Y = lambda v: gy1 - (math.log10(v) - le0) / (le1 - le0) * (gy1 - gy0)  # noqa: E731
    d.line([(gx0, gy0), (gx0, gy1), (gx1, gy1)], fill=(200, 210, 230, 200), width=3)
    k = ease(u * 1.6)
    pts = [(X(10 ** (lm0 + (lm1 - lm0) * i / 60)), Y(e(10 ** (lm0 + (lm1 - lm0) * i / 60)))) for i in range(int(60 * k) + 1)]
    if len(pts) > 1:
        d.line(pts, fill=BLUE + (255,), width=6)
    for i, (name, kg) in enumerate(CHART[:sc.get("n", 4)]):
        if ease(u * 3 - i * 0.4) <= 0:
            continue
        px, py = X(kg), Y(e(kg))
        d.ellipse([px - 14, py - 14, px + 14, py + 14], fill=YEL + (255,), outline=NAVY + (255,), width=3)
        lab = f"{name}"
        text(d, (px + (20 if i < 2 else -20), py - 34), lab, 40 if LAND else 32, WHITE, "ld" if i < 2 else "rd")
    text(d, ((gx0 + gx1) / 2, gy1 + 50), "体の重さ（右ほど重い）", 40 if LAND else 34, DIM)
    text(d, (gx0 - 20, (gy0 + gy1) / 2), "体重1gあたり\nのエネルギー", 36 if LAND else 30, DIM, "rm")
    if sc.get("title"):
        text(d, (W / 2, y0 + 55), sc["title"], 58 if LAND else 46, YEL)
    if sc.get("note"):
        text(d, (W / 2, y1 - 10), sc["note"], 40 if LAND else 34, WHITE, "md")


def draw_heart(img, sc, t, u):
    """心臓が打つ速さ。bpm 回/分 で脈打つハートと、数え上がる回数。"""
    back(img)
    d = ImageDraw.Draw(img, "RGBA")
    x0, y0, x1, y1 = region()
    bpm = sc.get("bpm", 1511)
    items = sc.get("items", [("コビトジャコウネズミ", bpm, RED)])
    n = len(items)
    for i, (name, rate, col) in enumerate(items):
        cx = W * (i + 1) / (n + 1)
        cy = y0 + (y1 - y0) * 0.45
        ph = (t * rate / 60.0) % 1.0
        beat = 1.0 + 0.22 * math.exp(-ph * 8)
        r = (110 if LAND else 120) * beat * (1.0 if n == 1 else 0.85)
        heart = []
        for j in range(60):
            a = 2 * math.pi * j / 60
            hx = 16 * math.sin(a) ** 3
            hy = 13 * math.cos(a) - 5 * math.cos(2 * a) - 2 * math.cos(3 * a) - math.cos(4 * a)
            heart.append((cx + hx * r / 16, cy - hy * r / 16))
        d.polygon(heart, fill=tuple(col) + (255,))
        text(d, (cx, cy + r + 60), name, 44 if LAND else 36, WHITE)
        cnt = int(rate * min(1.0, u * 1.4))
        text(d, (cx, cy + r + 125), f"1分に {cnt:,}回", 56 if LAND else 46, YEL)
    if sc.get("title"):
        text(d, (W / 2, y0 + 55), sc["title"], 58 if LAND else 46, YEL)
    if sc.get("note"):
        text(d, (W / 2, y1 - 10), sc["note"], 40 if LAND else 34, WHITE, "md")


def draw_bars(img, sc, t, u):
    back(img)
    x0, y0, x1, y1 = region()
    d = ImageDraw.Draw(img, "RGBA")
    items = sc["items"]
    vmax = max(v for _, v, _ in items)
    bx0 = x0 + (520 if LAND else 60)
    vw = max(d.textlength(sc.get("fmt", "{}").format(v), font=ov.font(50 if LAND else 44)) for _, v, _ in items)
    bx1 = x1 - max(320 if LAND else 260, vw + 60)                # 値の字が右にはみ出さない幅を空ける
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


def draw_cards(img, sc, t, u):
    back(img)
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
        d.text((x0 + 108, y + hh / 2 - 16), title, font=ov.font(46 if LAND else 38), fill=(255, 255, 255, int(255 * a)), anchor="lm")
        d.text((x0 + 108, y + hh / 2 + 28), sub, font=ov.font(30 if LAND else 28), fill=DIM + (int(255 * a),), anchor="lm")
        ov.BOXES.append(("label", (x0, y, x1, y + hh), title, 1.0))


CUSTOM = dict(cards=draw_cards, big=draw_big, cubes=draw_cubes, chart=draw_chart, heart=draw_heart, bars=draw_bars)
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

