"""ガラパゴスの回の本編のサムネイル(1280×720)。python episodes/galapagos/thumb.py → out/galapagos/thumb_long.jpg
下地は海を泳ぐウミイグアナの写真(sim/photos.json の swim。CC BY-SA 3.0、色を濃くして周りを暗くした)。
アマゾン川の回の型: 色を濃く・周りを暗く・主役に赤い丸・赤地に白い字の札・大きな字は2行・黄色は1か所。"""
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = Path(__file__).resolve().parent
OUT = HERE.parents[1] / "out" / "galapagos"
SRC = json.loads((HERE / "sim" / "photos.json").read_text(encoding="utf-8"))["swim"]
YEL, WHITE, INK = (255, 222, 0), (255, 255, 255), (8, 10, 18)

ph = Image.open(OUT / "photos" / "swim.jpg").convert("RGB")
ph = ph.resize((1280, round(ph.height * 1280 / ph.width)), Image.LANCZOS)
img = ph.crop((0, 60, 1280, 780))
a = np.asarray(img).astype(np.float32) / 255
g = a.mean(axis=2, keepdims=True)
a = np.clip(g + (a - g) * 1.35, 0, 1)
a = np.clip((a - 0.5) * 1.15 + 0.5, 0, 1)
yy, xx = np.mgrid[0:720, 0:1280].astype(np.float32)
vig = 1 - 0.5 * np.clip(((xx - 480) / 760) ** 2 + ((yy - 340) / 480) ** 2 - 0.3, 0, 1)
a *= vig[..., None]
a *= (1 - 0.6 * np.clip((xx / 1280 - 0.5) / 0.5, 0, 1))[..., None]      # 右を暗くして字を立てる
img = Image.fromarray((a * 255).astype(np.uint8)).convert("RGBA")


def font(size, weight="Black"):
    f = ImageFont.truetype("C:/Windows/Fonts/NotoSansJP-VF.ttf", size)
    f.set_variation_by_name(weight)
    return f


def big(xy, s, size, col, stroke=12, anchor="ra"):
    f = font(size)
    sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).text((xy[0] + 6, xy[1] + 9), s, font=f, fill=(0, 0, 0, 210), anchor=anchor, stroke_width=stroke + 3, stroke_fill=(0, 0, 0, 210))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(7)))
    ImageDraw.Draw(img).text(xy, s, font=f, fill=col, anchor=anchor, stroke_width=stroke, stroke_fill=INK)


# 主役(ウミイグアナ)に赤い丸
cx, cy, rx, ry = 470, 330, 270, 165
ring = Image.new("RGBA", img.size, (0, 0, 0, 0))
ImageDraw.Draw(ring).ellipse((cx - rx, cy - ry, cx + rx, cy + ry), outline=(0, 0, 0, 160), width=22)
img.alpha_composite(ring.filter(ImageFilter.GaussianBlur(5)))
ImageDraw.Draw(img).ellipse((cx - rx, cy - ry, cx + rx, cy + ry), outline=(235, 40, 40, 255), width=13)
# 札: 赤地に白い字
ft = font(70)
lab, lx, ly = "海に潜るトカゲ", 330, 600
bx = ImageDraw.Draw(img).textbbox((lx, ly), lab, font=ft, anchor="mm")
pad = 22
shd = Image.new("RGBA", img.size, (0, 0, 0, 0))
ImageDraw.Draw(shd).rounded_rectangle((bx[0] - pad + 8, bx[1] - pad + 12, bx[2] + pad + 8, bx[3] + pad + 12), 20, fill=(0, 0, 0, 200))
img.alpha_composite(shd.filter(ImageFilter.GaussianBlur(8)))
ImageDraw.Draw(img).rounded_rectangle((bx[0] - pad, bx[1] - pad, bx[2] + pad, bx[3] + pad), 20, fill=(225, 35, 35, 255), outline=(255, 255, 255, 255), width=5)
ImageDraw.Draw(img).text((lx, ly), lab, font=ft, fill=WHITE, anchor="mm")

big((1250, 34), "爬虫類の97%が、ここだけの種類", 44, WHITE, 9)
big((1250, 250), "ガラパゴスに", 112, WHITE, 15)
big((1250, 420), "しかいない理由", 112, YEL, 16)
ImageDraw.Draw(img).text((1262, 706), f"写真: {SRC['artist']}（{SRC['license']}）", font=font(22, "Bold"), fill=(255, 255, 255, 210), anchor="rd", stroke_width=3, stroke_fill=INK)
img.convert("RGB").save(OUT / "thumb_long.jpg", quality=93)
print(OUT / "thumb_long.jpg")
