"""進撃の巨人の本編のサムネイル(1280×720)。作品の絵は使わない。下地は Gemini で作った絵(assets/thumb_gemini.jpg: 高い石の壁の上から、
湯気をまとった巨人の影が頭と肩を出す。作品のデザインには似せていない。足元に小さな人)。左に「【進撃の巨人】の超大型巨人を／人の体で作ったら」と、動画でわかること 3 つ
(電子レンジの回で決めた形、2026-10-29)。python episodes/shingeki/thumb.py"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from PIL import Image, ImageDraw  # noqa: E402

from naze import overlay as O  # noqa: E402

HERE = Path(__file__).resolve().parent
OUT = HERE.parents[1] / "out" / "shingeki"
OUT.mkdir(parents=True, exist_ok=True)
W, H = 2560, 1440
INK, RED = (20, 30, 60), (225, 30, 30)

src = Image.open(HERE / "assets" / "thumb_gemini.jpg").convert("RGB")
s = max(W / src.width, H / src.height)
src = src.resize((int(src.width * s + 1), int(src.height * s + 1)), Image.LANCZOS)
img = src.crop((0, 0, W, H)).convert("RGBA")
k = W / 1376  # 下地の座標(1376×768)からの倍率

# 字の後ろ(左)を白く飛ばす
sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
ds = ImageDraw.Draw(sh)
for x in range(0, 1500, 4):
    a = int(185 * max(0.0, 1 - x / 1500) ** 0.8)
    ds.rectangle([x, 0, x + 4, H], fill=(255, 255, 255, a))
img.alpha_composite(sh)
d = ImageDraw.Draw(img)


def tag(xy, s, size, fg, bg, anchor="mm"):
    f = O.font(size)
    x0, y0, x1, y1 = d.textbbox(xy, s, font=f, anchor=anchor)
    p = size * 0.22
    d.rounded_rectangle([x0 - p, y0 - p, x1 + p, y1 + p], radius=int(p), fill=bg)
    d.text(xy, s, font=f, fill=fg, anchor=anchor)


# 巨人・壁・人の高さと、骨の負担
tag((1250 * k, 60 * k), "60m", 96, INK, (255, 205, 60))
tag((1120 * k, 520 * k), "壁 50m", 80, INK, (255, 255, 255))
tag((690 * k, 738 * k), "人 1.7m", 64, INK, (255, 205, 60))
tag((1180 * k, 640 * k), "骨の負担 1.7倍", 92, (255, 255, 255), RED)

# 「進撃の巨人」の札と見出し
f = O.font(110)
t = "進撃の巨人"
w = f.getlength(t) + 100
d.rounded_rectangle([80, 90, 80 + w, 90 + 165], 36, fill=(190, 35, 35))
d.text((80 + w / 2, 90 + 83), t, font=f, fill=(255, 255, 255), anchor="mm")
d.text((80 + w + 25, 90 + 83), "の超大型巨人を", font=O.font(104), fill=INK, anchor="lm", stroke_width=12, stroke_fill=(255, 255, 255))
d.text((80, 300), "人の体で作ったら", font=O.font(165), fill=INK, stroke_width=16, stroke_fill=(255, 255, 255))

# 動画でわかること 3 つ(本編の実験から)
ITEMS = [("歩くだけで", "骨が折れる"), ("ふつうの鉄でも", "42mまで"), ("歩ける体は", "発泡スチロール並み")]
fi = O.font(76)
for i, (a, b) in enumerate(ITEMS):
    y = 640 + i * 190
    x1 = 80 + 150 + fi.getlength(a + b) + 50
    d.rounded_rectangle([80, y, x1, y + 150], radius=30, fill=(255, 255, 255, 235), outline=INK, width=6)
    d.ellipse([105, y + 25, 205, y + 125], fill=RED)
    d.text((155, y + 75), str(i + 1), font=O.font(70), fill=(255, 255, 255), anchor="mm")
    d.text((235, y + 75), a, font=fi, fill=INK, anchor="lm")
    d.text((235 + fi.getlength(a), y + 75), b, font=fi, fill=RED, anchor="lm")
img.convert("RGB").resize((1280, 720), Image.LANCZOS).save(OUT / "thumb_long.jpg", quality=93)
print(OUT / "thumb_long.jpg")
