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


def badge(img, x, y, label, value, col, w=330, h=170):
    """数字の札(小さな見出し＋大きな数字)。"""
    lay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    d.rounded_rectangle([x, y, x + w, y + h], 26, fill=O.NAVY + (235,), outline=tuple(col) + (255,), width=6)
    img.alpha_composite(lay)
    d = ImageDraw.Draw(img)
    f1, f2 = O.font(44), O.font(96)
    d.text((x + w / 2 - f1.getlength(label) / 2, y + 14), label, font=f1, fill=O.WHITE)
    d.text((x + w / 2 - f2.getlength(value) / 2, y + 62), value, font=f2, fill=tuple(col))


# 本編: 問い(左上)＋数字の札 2 つ(左下)＋震源で光る日本(右)に赤い丸
img, v = base((131.5, 36.2, 40), [Q(id="q", data=JP, size=1.0)])
img = glow(img)
img = shade_left(img, 0.56)
cx, cy = v.px(139.0, 36.8)
circle(img, cx, cy, 320)
text_block(img, ["なぜ日本は", "【地震】が", "多いのか？"], 70, 90, size=138)
badge(img, 70, 640, "日本の陸地", "0.25%", O.WHITE)
ImageDraw.Draw(img).text((418, 680), "→", font=O.font(90), fill=O.WHITE, stroke_width=6, stroke_fill=O.NAVY)
badge(img, 510, 640, "世界の大地震", "約2割", O.YEL, w=360)
ImageDraw.Draw(img).text((74, 860), "1万回の震源で確かめる", font=O.font(50), fill=O.DIM, stroke_width=6, stroke_fill=O.NAVY)
img.convert("RGB").resize((1280, 720), Image.LANCZOS).save(OUT / "thumb_long.jpg", quality=93)
print(OUT / "thumb_long.jpg")
