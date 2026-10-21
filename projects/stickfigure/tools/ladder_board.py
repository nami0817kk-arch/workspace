"""勝ち抜き戦の看板(字なし)を描く。下から青・紫・赤の相手が並び、緑の印が勝つたびに上がる。倒した相手には×。
s0: 始まる前 / s1: 青に勝った / s2: 紫に勝った / s3: 優勝(てっぺんに星)

使い方: python tools/ladder_board.py  → assets/bg/ladder_s0.png 〜 s3.png
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

W, H = 440, 560
GREEN, RIVALS = (128, 217, 77), [(64, 140, 242), (158, 89, 217), (235, 82, 71)]   # 下から 青・紫・赤
OUT = Path(__file__).resolve().parents[1] / "assets" / "bg"


def figure(d, cx, cy, col, s=1.0):
    r = 22 * s
    d.ellipse([cx - r, cy - r - 30 * s, cx + r, cy + r - 30 * s], fill=col)
    lw = int(7 * s)
    d.line([cx, cy - 8 * s, cx, cy + 30 * s], fill=col, width=lw)
    d.line([cx - 18 * s, cy + 6 * s, cx + 18 * s, cy + 6 * s], fill=col, width=lw)
    d.line([cx, cy + 30 * s, cx - 14 * s, cy + 56 * s], fill=col, width=lw)
    d.line([cx, cy + 30 * s, cx + 14 * s, cy + 56 * s], fill=col, width=lw)


def star(d, cx, cy, r, col):
    import math
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        rr = r if i % 2 == 0 else r * 0.45
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    d.polygon(pts, fill=col, outline=(120, 80, 10))


def draw(stage: int) -> Image.Image:
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([0, 0, W - 1, H - 1], 26, fill=(120, 80, 48))                 # 木の枠
    d.rounded_rectangle([22, 22, W - 23, H - 23], 16, fill=(244, 232, 205))             # 紙
    rows = [H - 130, H - 270, H - 410]                                                   # 青・紫・赤の段の高さ
    lx = 120                                                                             # 緑が登る柱
    d.line([lx, H - 50, lx, 70], fill=(170, 150, 120), width=14)
    top = rows[stage - 1] if stage >= 1 else H - 50
    if stage == 3:
        top = 100
    d.line([lx, H - 50, lx, top], fill=GREEN, width=14)
    for i, (y, col) in enumerate(zip(rows, RIVALS)):
        d.line([lx, y, 290, y], fill=(170, 150, 120) if stage <= i else GREEN, width=8)
        figure(d, 320, y - 6, col, 1.0)
        if stage > i:                                                                    # 倒した相手に ×
            d.line([285, y - 70, 355, y + 40], fill=(60, 40, 30), width=10)
            d.line([355, y - 70, 285, y + 40], fill=(60, 40, 30), width=10)
    gy = (H - 50 if stage == 0 else rows[stage - 1]) if stage < 3 else 175
    figure(d, lx, gy - 20, GREEN, 0.9)
    if stage == 3:
        star(d, lx, 62, 36, (250, 205, 60))
    return im


def main():
    for s in range(4):
        p = OUT / f"ladder_s{s}.png"
        draw(s).save(p)
        print(p)


if __name__ == "__main__":
    main()
