"""電子レンジの本編のサムネイル(1280×720)。下地は Gemini で作った絵(assets/thumb_gemini.jpg: 扉を開けた電子レンジと、外だけ煮えて中は冷たいグラタンの断面)。
左に「電子レンジは／中から温めて／【いなかった】(赤)」、食べ物の外側に「外 100℃」、冷たい真ん中に赤い丸と「中 23℃」(厚さ 10cm の計算)。
python episodes/renji/thumb.py"""
import os
import sys
from pathlib import Path

os.environ["NAZE_ASPECT"] = "landscape"
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1]))
from PIL import Image, ImageDraw, ImageFilter  # noqa: E402

from naze import overlay as O  # noqa: E402

OUT = HERE.parents[1] / "out" / "renji"
OUT.mkdir(parents=True, exist_ok=True)
W, H = 2560, 1440

src = Image.open(HERE / "assets" / "thumb_gemini.jpg").convert("RGB")
s = max(W / src.width, H / src.height)
src = src.resize((int(src.width * s + 1), int(src.height * s + 1)), Image.LANCZOS)
img = src.crop((0, 0, W, H)).convert("RGBA")
k = W / 1376  # 下地の座標(1376×768)からの倍率

# 字の後ろ(左)を白く飛ばす(明るい絵なので字は紺、強調は赤にする)
sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
ds = ImageDraw.Draw(sh)
for x in range(0, 1400, 4):
    a = int(170 * max(0.0, 1 - x / 1400) ** 0.8)
    ds.rectangle([x, 0, x + 4, H], fill=(255, 255, 255, a))
img.alpha_composite(sh)
d = ImageDraw.Draw(img)


def tag(xy, s, size, fg, bg, anchor="mm"):
    f = O.font(size)
    x0, y0, x1, y1 = d.textbbox(xy, s, font=f, anchor=anchor)
    p = size * 0.22
    d.rounded_rectangle([x0 - p, y0 - p, x1 + p, y1 + p], radius=int(p), fill=bg)
    d.text(xy, s, font=f, fill=fg, anchor=anchor)
    return x0 - p, y0 - p, x1 + p, y1 + p


# 冷たい真ん中(切り口)にうっすら青みを足し、赤い丸
cx, cy = 905 * k, 525 * k
rx, ry = 70 * k, 58 * k
cool = Image.new("RGBA", (W, H), (0, 0, 0, 0))
ImageDraw.Draw(cool).ellipse([cx - rx * 0.9, cy - ry * 0.9, cx + rx * 0.9, cy + ry * 0.9], fill=(80, 150, 255, 90))
img.alpha_composite(cool.filter(ImageFilter.GaussianBlur(40)))
d = ImageDraw.Draw(img)
d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], outline=(240, 40, 40), width=16)
tag((cx, cy + ry + 95), "中 23℃", 104, (255, 255, 255), (220, 40, 40), "mt")
# 焼けた外側
ox, oy = 1120 * k, 470 * k
tag((ox + 60, oy - 210), "外 100℃", 104, (40, 20, 10), (255, 205, 60), "mm")
d.line([(ox + 30, oy - 150), (ox, oy - 10)], fill=(255, 205, 60), width=12)


def line(x, y, parts, size):
    f = O.font(size)
    for t, col in parts:
        d.text((x, y), t, font=f, fill=col, stroke_width=16, stroke_fill=(255, 255, 255))
        x += f.getlength(t)


INK, RED = (20, 30, 60), (225, 30, 30)
# 字の案。python episodes/renji/thumb.py [案] で out/renji/thumb_long[_案].jpg
COPY = {
    "": [(200, [("電子レンジは", INK)], 170), (450, [("中から温めて", INK)], 170), (720, [("いなかった", RED)], 215)],
    "A": [(190, [("電子レンジの電波は", INK)], 130), (420, [("表面から", INK), ("数cm", RED)], 190), (700, [("中心は", INK), ("23℃", RED)], 215)],
    "B": [(190, [("電子レンジの", INK)], 160), (430, [("「中から温まる」は", INK)], 128), (680, [("半分だけ", RED), ("正しい", INK)], 175)],
    "C": [(190, [("電子レンジで", INK)], 160), (440, [("外は100℃でも", INK)], 160), (690, [("中心は", INK), ("23℃", RED)], 215)],
}
v = sys.argv[1] if len(sys.argv) > 1 else ""
for y, parts, size in COPY[v]:
    line(80, y, parts, size)
d.text((90, 1080), "厚さ10cmを温める計算", font=O.font(78), fill=(70, 80, 100), stroke_width=8, stroke_fill=(255, 255, 255))
name = f"thumb_long{'_' + v if v else ''}.jpg"
img.convert("RGB").resize((1280, 720), Image.LANCZOS).save(OUT / name, quality=93)
print(OUT / name)
