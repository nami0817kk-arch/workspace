"""ナイアガラの本編のサムネイル(1280×720)。python episodes/niagara/thumb.py → out/niagara/thumb_long.jpg
下地は場面の絵(illust_falls1、イメージ)。左を暗くして字を 3 段、大事な 1 語(16万年後)だけ黄色。赤い丸は、絵の滝の縁が切れていて当てる所が無いので付けない。"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = Path(__file__).resolve().parent
OUT = HERE.parents[1] / "out" / "niagara"
OUT.mkdir(parents=True, exist_ok=True)
YEL, WHITE, INK, RED = (255, 222, 0), (255, 255, 255), (8, 10, 18), (240, 60, 50)


def font(size, weight="Black"):
    f = ImageFont.truetype("C:/Windows/Fonts/NotoSansJP-VF.ttf", size)
    f.set_variation_by_name(weight)
    return f


ph = Image.open(HERE / "assets" / "illust_falls1.jpg").convert("RGB")
w, h = ph.size
crop = ph.crop((int(w * 0.02), 0, int(w * 0.02) + int(h * 16 / 9), h)) if w / h > 16 / 9 else ph
img = crop.resize((1280, 720), Image.LANCZOS)
a = np.asarray(img).astype(np.float32)
x = np.linspace(0, 1, 1280, dtype=np.float32)[None, :, None]
a *= 0.35 + 0.65 * np.clip((x - 0.05) / 0.6, 0, 1)            # 左を暗く
img = Image.fromarray(a.astype(np.uint8)).convert("RGBA")


def big(xy, s, size, col):
    f = font(size)
    sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).text((xy[0] + 6, xy[1] + 8), s, font=f, fill=(0, 0, 0, 200), stroke_width=14, stroke_fill=(0, 0, 0, 200))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(6)))
    ImageDraw.Draw(img).text(xy, s, font=f, fill=col, stroke_width=12, stroke_fill=INK)


big((48, 50), "ナイアガラの滝がエリー湖に届くのは", 64, WHITE)
big((40, 170), "〇〇年後", 210, YEL)
big((52, 450), "それでも、湖の水は抜けない", 76, WHITE)
img.convert("RGB").save(OUT / "thumb_long.jpg", quality=92)
print(OUT / "thumb_long.jpg")
