"""富士山の本編のサムネイル(1280×720)。国土地理院の標高データで山頂を東西に切った横顔を描き、測った傾きを書き込む。
python episodes/fuji/thumb.py"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
import numpy as np  # noqa: E402
from PIL import Image, ImageDraw, ImageFilter  # noqa: E402

from naze import dem, overlay as O  # noqa: E402

OUT = Path(__file__).resolve().parents[2] / "out" / "fuji"
OUT.mkdir(parents=True, exist_ok=True)
W, H = 2560, 1440
TOP = (138.7274, 35.3606)
EX = 2.3                        # 高さの強調(絵として。角度の数字は実測)

d = dem.load(138.50, 35.20, 138.96, 35.535, z=13)
xs = np.linspace(-11, 11, 900)                      # 山頂から西(-)〜東(+) km
hs = []
for x in xs:
    lon = TOP[0] + x / (111.32 * math.cos(math.radians(TOP[1])))
    h = d.height_at(lon, TOP[1], r=1)
    hs.append(h if h == h else 0)
hs = np.convolve(np.pad(np.array(hs), 2, mode="edge"), np.ones(5) / 5, mode="valid")

# 空(夜明けの色)
img = Image.new("RGB", (W, H))
top_c, bot_c = np.array([18, 30, 70]), np.array([250, 170, 110])
a = np.linspace(0, 1, H)[:, None] ** 1.6
sky = (top_c * (1 - a) + bot_c * a).astype(np.uint8)
img = Image.fromarray(np.repeat(sky[:, None, :], W, axis=1).reshape(H, W, 3))
d2 = ImageDraw.Draw(img)

x0, x1 = 700, W + 80                                # 山は右寄り
base_y = H - 40
s = (x1 - x0) / 22.0                                  # 1km の画素
px = lambda x: x0 + (x + 11) * s
py = lambda h: base_y - h / 1000 * s * EX
poly = [(0, py(hs[0]))] + [(px(x), py(h)) for x, h in zip(xs, hs)] + [(W, H), (0, H)]
d2.polygon(poly, fill=(46, 58, 92))
# 雪(標高 3000m より上)
snow = [(px(x), py(h)) for x, h in zip(xs, hs) if h > 3000]
if len(snow) > 2:
    lay = Image.new("L", (W, H), 0)
    ImageDraw.Draw(lay).polygon(snow, fill=255)
    img.paste((235, 240, 250), mask=lay)
d2 = ImageDraw.Draw(img)
d2.line([(px(x), py(h)) for x, h in zip(xs, hs)], fill=(250, 230, 200), width=6)


def angle_mark(side, deg, label_xy):
    """山頂近くの斜面に、傾きの線と度数を書く。side=-1 西 / +1 東。"""
    h0, h1 = 3700, 3000
    i0 = np.argmin(np.abs(xs - 0))
    rng = range(i0, 0, -1) if side < 0 else range(i0, len(xs))
    pa = pb = None
    for i in rng:
        if pa is None and hs[i] < h0:
            pa = (px(xs[i]), py(hs[i]))
        if hs[i] < h1:
            pb = (px(xs[i]), py(hs[i]))
            break
    ex = (pb[0] - pa[0]) * 1.6, (pb[1] - pa[1]) * 1.6
    d2.line([pa, (pa[0] + ex[0], pa[1] + ex[1])], fill=O.YEL, width=12)
    d2.line([pb, (pb[0] + side * 200, pb[1])], fill=(255, 255, 255), width=6)
    f = O.font(170)
    t = f"{deg}°"
    if label_xy is None:
        label_xy = (pb[0] - f.getlength(t) - 60, pb[1] - 230) if side < 0 else (pb[0] + 230, pb[1] - 230)
    d2.text(label_xy, t, font=f, fill=O.YEL, stroke_width=12, stroke_fill=O.NAVY)
    g = O.font(64)
    d2.text((label_xy[0] + 10, label_xy[1] - 80), "西" if side < 0 else "東", font=g, fill=O.WHITE, stroke_width=8, stroke_fill=O.NAVY)


angle_mark(-1, 38, None)
angle_mark(+1, 22, None)

# 左の字
def rows(lines, x, y, size, gap=1.2):
    for i, row in enumerate(lines):
        xx = x
        for t, hl in O.parse(row):
            f = O.font(size)
            d2.text((xx, y + i * size * gap), t, font=f, fill=O.YEL if hl else O.WHITE, stroke_width=14, stroke_fill=O.NAVY)
            xx += f.getlength(t)


lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
grad = Image.new("L", (W, 1))
for x in range(W):
    grad.putpixel((x, 0), int(200 * max(0.0, 1 - x / (W * 0.5))))
sh = Image.new("RGBA", (W, H), O.NAVY + (0,))
sh.putalpha(grad.resize((W, H)))
img = img.convert("RGBA")
img.alpha_composite(sh)
d2 = ImageDraw.Draw(img)
rows(["富士山は", "【左右対称】", "じゃなかった"], 80, 230, 150)
d2.text((86, 1180), "国土地理院の標高データで測定", font=O.font(56), fill=O.DIM, stroke_width=6, stroke_fill=O.NAVY)
img.convert("RGB").resize((1280, 720), Image.LANCZOS).save(OUT / "thumb_long.jpg", quality=93)
print(OUT / "thumb_long.jpg")
