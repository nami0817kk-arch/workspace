"""宇宙で冷えない回の本編のサムネイル(1280×720)。python episodes/space-heat/thumb.py → out/space-heat/thumb_long.jpg
冷たい宇宙(左・青)と、熱をためて赤く光る宇宙ステーション(右)をぶつける。下は地球の縁。
字は 2 段: 「宇宙は −270℃」(数字は氷の色)・「なのに 冷えない」(冷えない だけ黄色)。主役の放熱板に赤い丸。"""
import math
import os
import sys
from pathlib import Path

os.environ["NAZE_ASPECT"] = "landscape"
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1]))
sys.path.insert(0, str(HERE))
import cv2  # noqa: E402
import numpy as np  # noqa: E402
from PIL import Image, ImageDraw, ImageFilter, ImageFont  # noqa: E402

import scene  # noqa: E402
from naze import overlay as ov  # noqa: E402
from naze import shots  # noqa: E402
from naze.config import H, W  # noqa: E402

OUT = HERE.parents[1] / "out" / "space-heat"
OUT.mkdir(parents=True, exist_ok=True)
YEL, WHITE, INK, ICE = (255, 222, 0), (255, 255, 255), (8, 10, 18), (150, 225, 255)


def space():
    """星空と、右下の地球の縁(夜明けの大気の光つき)。"""
    rng = np.random.default_rng(11)
    a = np.zeros((H, W, 3), np.float32)
    a[...] = np.array([3, 6, 16], np.float32)
    n = 900
    sx, sy = rng.integers(0, W, n), rng.integers(0, H, n)
    a[sy, sx] = rng.uniform(60, 230, (n, 1))
    for _ in range(40):                                        # 少し大きい星
        x, y = int(rng.integers(0, W)), int(rng.integers(0, H))
        cv2.circle(a, (x, y), 2, (230, 235, 255), -1, cv2.LINE_AA)
    world, ppd = shots._world()
    cx, cy, R = W * 0.70, H * 2.45, H * 1.80
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    x, y = (xx - cx) / R, -(yy - cy) / R
    rho2 = x * x + y * y
    inside = rho2 <= 1
    z = np.sqrt(np.clip(1 - rho2, 0, 1))
    la0, lo0 = math.radians(-35), math.radians(135)            # 上の縁に日本からオーストラリアあたり
    lat = np.arcsin(np.clip(z * math.sin(la0) + y * math.cos(la0), -1, 1))
    lon = lo0 + np.arctan2(x, z * math.cos(la0) - y * math.sin(la0))
    mx = (((np.degrees(lon) + 180) % 360) * ppd).astype(np.float32)
    my = ((90 - np.degrees(lat)) * ppd).astype(np.float32)
    col = cv2.remap(world, mx, my, cv2.INTER_LINEAR, borderMode=cv2.BORDER_WRAP).astype(np.float32)
    light = np.clip(0.15 + 1.1 * (x * 0.55 + y * 0.6 + z * 0.35), 0.08, 1.2)[..., None]
    col = col * light
    rr = np.sqrt(rho2)
    rim = np.clip(1 - (1 - rr) / 0.012, 0, 1) * inside             # 縁の内側の薄い青
    col = col * (1 - 0.6 * rim[..., None]) + rim[..., None] * np.array([120, 190, 255], np.float32) * 0.6
    glow = np.clip(1 - (rr - 1) / 0.045, 0, 1) * (rr > 1)
    side = np.clip(0.35 + x * 1.2, 0.2, 1.3)[..., None]             # 右ほど明るい大気
    a += (glow ** 1.6)[..., None] * np.array([60, 150, 255], np.float32) * side
    a = np.where(inside[..., None], col, a)
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).convert("RGBA")


def coeffs(src, dst):
    m = []
    for (x, y), (u, v) in zip(dst, src):
        m.append([x, y, 1, 0, 0, 0, -u * x, -u * y])
        m.append([0, 0, 0, x, y, 1, -v * x, -v * y])
    return np.linalg.solve(np.array(m, float), np.array(src, float).reshape(8)).tolist()


def station():
    """熱をためた宇宙ステーション: 放熱板を赤く光らせ、熱のゆらぎを出し、少し斜めから見た形に曲げる。"""
    s, cx, cy = 0.74, W / 2, H / 2
    lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay, "RGBA")
    scene._station(d, cx, cy, s, 0.0, None)
    hot = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    hd = ImageDraw.Draw(hot, "RGBA")
    boxes = []
    for side in (-1, 1):
        for j in range(3):
            x = cx + side * (120 * s + j * 46 * s)
            b = [x - 18 * s, cy + 14 * s, x + 18 * s, cy + 220 * s]
            boxes.append(b)
            for k in range(24):                                 # 下ほど赤く、上ほど橙
                y0 = b[1] + (b[3] - b[1]) * k / 24
                y1 = b[1] + (b[3] - b[1]) * (k + 1) / 24
                t = k / 23
                hd.rectangle([b[0], y0, b[2], y1], fill=(255, int(170 - 120 * t), int(40 - 30 * t), 235))
            hd.rectangle(b, outline=(255, 230, 160, 255), width=3)
    hd.rounded_rectangle([cx - 90 * s, cy - 40 * s, cx + 90 * s, cy + 30 * s], int(20 * s), fill=(255, 120, 40, 90))
    lay.alpha_composite(hot)
    # 熱の光(赤い光の暈)
    m = Image.new("L", (W, H), 0)
    md = ImageDraw.Draw(m)
    for b in boxes:
        md.rectangle([b[0] - 6, b[1] - 6, b[2] + 6, b[3] + 6], fill=255)
    md.rounded_rectangle([cx - 100 * s, cy - 120 * s, cx + 100 * s, cy + 40 * s], 30, fill=150)
    glow = Image.new("RGBA", (W, H), (255, 70, 20, 0))
    glow.putalpha(m.filter(ImageFilter.GaussianBlur(46)).point(lambda v: min(255, int(v * 1.6))))
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    out.alpha_composite(glow)
    out.alpha_composite(glow)
    # 熱のゆらぎ(放熱板の下から外へ)
    wl = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    wd = ImageDraw.Draw(wl, "RGBA")
    for i, b in enumerate(boxes):
        bx = (b[0] + b[2]) / 2
        ang = math.radians(90)
        scene.wave(wd, (bx, b[3] + 16), ang, 150, (255, 120, 50), 0.0, w=9, amp=13, k=0.08, a=225)
    out.alpha_composite(wl.filter(ImageFilter.GaussianBlur(1.5)))
    out.alpha_composite(lay)
    # 少し斜め(右手前)から見た形に
    q = 140
    src = [(0, 0), (W, 0), (W, H), (0, H)]
    dst = [(q * 1.1, q * 0.9), (W, -q * 0.5), (W, H + q * 0.5), (q * 1.1, H - q * 0.9)]
    out = out.transform((W, H), Image.PERSPECTIVE, coeffs(src, dst), Image.BICUBIC)
    return out.rotate(-9, resample=Image.BICUBIC, center=(W / 2, H / 2))


# 下地は Gemini で作った絵(assets/thumb_bg.jpg)。左に字の場所を空けるため、絵を右へずらし、左の 600px を横に少し伸ばして埋める
bg = Image.open(HERE / "assets" / "thumb_bg.jpg").convert("RGB")
bg = bg.resize((round(bg.width * 720 / bg.height), 720), Image.LANCZOS)
SHIFT = 70
X0 = 600                                                       # 左の 600px だけ横に伸ばす(継ぎ目を出さない)
ox = np.arange(1280, dtype=np.float32)
sx = np.where(ox < X0, ox * (X0 - SHIFT) / X0, ox - SHIFT)
mx = np.broadcast_to(sx[None, :], (720, 1280)).astype(np.float32)
my = np.broadcast_to(np.arange(720, dtype=np.float32)[:, None], (720, 1280)).astype(np.float32)
a = cv2.remap(np.asarray(bg), mx, my, cv2.INTER_LANCZOS4).astype(np.float32)
x = np.linspace(0, 1, 1280, dtype=np.float32)[None, :, None]
cold = np.clip(1 - x / 0.5, 0, 1)                              # 左は冷たい青に
a = a * (1 - 0.3 * cold) + np.array([20, 70, 140], np.float32) * 0.3 * cold
img = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).convert("RGBA")


def font(size, weight="Black"):
    f = ImageFont.truetype("C:/Windows/Fonts/NotoSansJP-VF.ttf", size)
    f.set_variation_by_name(weight)
    return f


def big(xy, s, size, col, stroke=12, grad=None):
    f = font(size)
    sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).text((xy[0] + 6, xy[1] + 9), s, font=f, fill=(0, 0, 0, 210), stroke_width=stroke + 3, stroke_fill=(0, 0, 0, 210))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(7)))
    ImageDraw.Draw(img).text(xy, s, font=f, fill=col, stroke_width=stroke, stroke_fill=INK)
    if grad:                                                    # 字の中を上から下へ色を変える
        m = Image.new("L", img.size, 0)
        ImageDraw.Draw(m).text(xy, s, font=f, fill=255)
        bb = m.getbbox()
        g = np.zeros((img.size[1], img.size[0], 4), np.uint8)
        t = np.clip((np.arange(img.size[1]) - bb[1]) / max(1, bb[3] - bb[1]), 0, 1)[:, None]
        for c in range(3):
            g[..., c] = (grad[0][c] * (1 - t) + grad[1][c] * t).astype(np.uint8)
        g[..., 3] = np.asarray(m)
        img.alpha_composite(Image.fromarray(g))
    return ImageDraw.Draw(img).textbbox(xy, s, font=f, stroke_width=stroke)


big((44, 22), "宇宙は", 80, WHITE)
big((30, 98), "−270℃", 170, ICE, 13, grad=((235, 250, 255), (90, 190, 255)))
big((48, 330), "なのに", 84, WHITE)
big((30, 420), "冷えない", 172, YEL, 14)
img.convert("RGB").save(OUT / "thumb_long.jpg", quality=93)
print(OUT / "thumb_long.jpg")
