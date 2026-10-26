"""地震のセットのサムネイル(1280×720)。地図を高い質で描き起こし、字を重ねる。NAZE_ASPECT=landscape python episodes/quake/thumb.py"""
import os
import sys
from pathlib import Path

os.environ["NAZE_ASPECT"] = "landscape"
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from PIL import Image, ImageDraw, ImageFilter  # noqa: E402

from common import JP, PLATES, PLATES_FILL, Q  # noqa: E402
from naze import mapscene as M  # noqa: E402
from naze import overlay as O  # noqa: E402

OUT = Path(__file__).resolve().parents[2] / "out" / "quake"
OUT.mkdir(parents=True, exist_ok=True)


def base(view, layers):
    v = M.View(*view)
    img = M.base(v)
    for L in layers:
        M.draw_layer(img, v, L, 1.0, 1.0)
    return img, v


def glow(img):
    """点が光って見えるように、明るいところをぼかして足す。"""
    g = img.convert("RGB").filter(ImageFilter.GaussianBlur(10))
    return Image.blend(img.convert("RGB"), Image.composite(g, img.convert("RGB"), g.convert("L").point(lambda p: 255 if p > 150 else 0)), 0.35)


def text_block(img, lines, x, y, size=150, gap=1.18):
    d = ImageDraw.Draw(img)
    for i, row in enumerate(lines):
        segs = O.parse(row)
        f = O.font(size)
        xx = x
        for t, h in segs:
            d.text((xx, y + i * size * gap), t, font=f, fill=O.YEL if h else O.WHITE, stroke_width=14, stroke_fill=O.NAVY)
            xx += f.getlength(t)


def shade_left(img, w=0.62):
    W, H = img.size
    grad = Image.new("L", (W, 1))
    for x in range(W):
        grad.putpixel((x, 0), int(225 * max(0.0, 1 - x / (W * w))))
    sh = Image.new("RGBA", (W, H), O.NAVY + (0,))
    sh.putalpha(grad.resize((W, H)))
    out = img.convert("RGBA")
    out.alpha_composite(sh)
    return out


def circle(img, x, y, r):
    d = ImageDraw.Draw(img)
    d.ellipse([x - r - 4, y - r - 4, x + r + 4, y + r + 4], outline=O.NAVY, width=22)
    d.ellipse([x - r, y - r, x + r, y + r], outline=(235, 45, 45), width=14)


# 本編: 日本の周りの地震(10年・1万回)とプレート。字は左、主役(日本と震源の帯)は右
img, v = base((132.0, 36.0, 44), [PLATES, Q(id="q", data=JP, size=1.0)])
img = glow(img)
img = shade_left(img, 0.55)
cx, cy = v.px(139.2, 36.6)
circle(img, cx, cy, 330)
text_block(img, ["陸地0.25%", "なのに地震は", "【世界の2割】"], 70, 250, size=128)
ImageDraw.Draw(img).text((74, 900), "1万回の震源で確かめる", font=O.font(54), fill=O.DIM, stroke_width=6, stroke_fill=O.NAVY)
img.convert("RGB").resize((1280, 720), Image.LANCZOS).save(OUT / "thumb_long.jpg", quality=93)
print(OUT / "thumb_long.jpg")
