"""台詞の吹き出し・ナレーション・叫び文字(物語を見せるための字幕)。合成の最後に重ねる。

台本の captions: [{kind: say|narr|shout, who: A, text: "…", t0: 秒, t1: 秒, color: [r,g,b]}, ...]
  say    人物の頭の上に吹き出し(しっぽが頭を向く)。who で話す人を指す
  narr   画面の下にナレーションの帯
  shout  画面の中央に大きな叫び文字(技名など。少し弾んで出る)
時刻は台本の設計時間(tau)。スローモーションでも、その区間のあいだ出続ける。
"""
from __future__ import annotations

import math
from typing import List, Tuple

from PIL import Image, ImageDraw

from . import anime, camera, fk

W, H = camera.W, camera.H


def _wrap(d: ImageDraw.ImageDraw, text: str, font, max_w: int) -> List[str]:
    lines, cur = [], ""
    for ch in text:
        if ch == "\n":
            lines.append(cur)
            cur = ""
            continue
        if d.textlength(cur + ch, font=font) > max_w and cur:
            lines.append(cur)
            cur = ch
        else:
            cur += ch
    if cur:
        lines.append(cur)
    return lines


def _head_px(plan: dict, f: int, who: str, xf=None) -> Tuple[float, float, float]:
    a = plan["actors"][who]
    p = plan["frames"][f]["actors"][who]
    s = 1 if a.get("facing", 1) >= 0 else -1
    sk = fk.skeleton(p, s, p["root_x"], a.get("scale", 1.0))
    hx, hz = sk["head"]
    cam = plan["frames"][f]["cam"]
    x, y = camera.project(cam, hx, 0.0, hz)[:2]
    r = sk["head_r"] * camera.px_per_unit(cam)
    if xf is not None:                                 # 縦画面: 切り出しの左端 x0 と拡大 k
        x, y, r = (x - xf[0]) * xf[1], y * xf[1], r * xf[1]
    return x, y, r


def _say(img: Image.Image, plan: dict, f: int, c: dict, age: int, xf=None, placed=None) -> None:
    W, H = img.size
    d = ImageDraw.Draw(img)
    size = int(c.get("size", 34) * (1.3 if W < 1000 else 1.0))
    font = anime._font(size)
    lines = _wrap(d, c["text"], font, int(c.get("max_w", 520) * (0.95 if W < 1000 else 1.0)))
    tw = max(d.textlength(l, font=font) for l in lines)
    lh = int(size * 1.25)
    bw, bh = tw + 44, lh * len(lines) + 30
    hx, hy, hr = _head_px(plan, f, c["who"], xf)
    pop = min(1.0, (age + 1) / 4)                      # 出だしの数コマで、少し弾む
    k = 0.75 + 0.25 * pop + (0.06 * math.sin(pop * math.pi) if pop < 1 else 0)
    cx = min(max(hx, bw / 2 * k + 12), W - bw / 2 * k - 12)
    top = hy - hr - 40 - bh * k
    if top < 12:                                       # 頭が画面の上端に近いときは、横に出す
        top = 12
    x0, x1 = cx - bw / 2 * k, cx + bw / 2 * k
    y0, y1 = top, top + bh * k
    for _ in range(4):                                 # 先に置いた吹き出しと重なるときは、少しずつ上へずらす(上端を越えるなら、下へ)
        hit = next((r for r in (placed or []) if x0 < r[2] and x1 > r[0] and y0 < r[3] and y1 > r[1]), None)
        if hit is None:
            break
        dy = (hit[1] - 10) - y1 if hit[1] - 10 - (y1 - y0) > 8 else (hit[3] + 10) - y0
        y0, y1 = y0 + dy, y1 + dy
    if placed is not None:
        placed.append((x0, y0, x1, y1))
    d.rounded_rectangle([x0, y0, x1, y1], radius=26, fill=(255, 255, 255), outline=(15, 15, 20), width=4)
    tx = min(max(hx, x0 + 30), x1 - 30)
    d.polygon([(tx - 16, y1 - 2), (tx + 16, y1 - 2), (hx, min(hy - hr - 6, y1 + 46))], fill=(255, 255, 255), outline=(15, 15, 20))
    d.line([(tx - 14, y1 - 1), (tx + 14, y1 - 1)], fill=(255, 255, 255), width=5)
    for i, l in enumerate(lines):
        d.text((x0 + 22 * k, y0 + 15 * k + i * lh * k), l, font=anime._font(int(size * k)), fill=(15, 15, 20))


def _narr(img: Image.Image, c: dict) -> None:
    W, H = img.size
    ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    size = int(c.get("size", 36) * (0.8 if W < 1000 else 1.0))
    font = anime._font(size)
    lines = _wrap(d, c["text"], font, W - 160)
    lh = int(size * 1.3)
    bh = lh * len(lines) + 30
    d.rectangle([0, H - bh - 24, W, H - 24], fill=(8, 8, 14, 205))
    for i, l in enumerate(lines):
        tw = d.textlength(l, font=font)
        d.text(((W - tw) / 2, H - bh - 24 + 15 + i * lh), l, font=font, fill=(255, 255, 255, 255))
    img.paste(Image.alpha_composite(img.convert("RGBA"), ov).convert("RGB"))


def _shout(img: Image.Image, c: dict, age: int) -> None:
    W, H = img.size
    d = ImageDraw.Draw(img)
    size = int(c.get("size", 150) * (0.55 if W < 1000 else 1.0) * (0.7 + 0.3 * min(1.0, (age + 1) / 4) + (0.08 if age < 3 else 0)))
    font = anime._font(size)
    tw = d.textlength(c["text"], font=font)
    while tw > W - 80 and size > 30:                   # 長い文は、画面に収まる大きさまで縮める
        size = int(size * 0.92)
        font = anime._font(size)
        tw = d.textlength(c["text"], font=font)
    col = tuple(c.get("color", (255, 226, 60)))
    x, y = (W - tw) / 2, c.get("y", H * 0.36)
    d.text((x, y), c["text"], font=font, fill=col, stroke_width=max(6, size // 14), stroke_fill=(15, 12, 20))


def draw(frame: Image.Image, plan: dict, f: int, xf=None) -> Image.Image:
    caps = plan.get("scene", {}).get("captions")
    if not caps:
        return frame
    tau = plan["frames"][f]["tau"]
    img = frame.copy()
    placed = []
    for c in caps:
        if not (c["t0"] <= tau < c["t1"]):
            continue
        age = 0
        while age < 8 and f - age - 1 >= 0 and plan["frames"][f - age - 1]["tau"] >= c["t0"]:
            age += 1
        k = c.get("kind", "say")
        if k == "say":
            _say(img, plan, f, c, age, xf, placed)
        elif k == "narr":
            _narr(img, c)
        elif k == "shout":
            _shout(img, c, age)
    return img
