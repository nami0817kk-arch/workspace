"""南極の回の本編のサムネイル(1280×720)。python episodes/antarctic/thumb.py → out/antarctic/thumb_long.jpg
下地は Gemini で作った絵(assets/thumb_bg.jpg、海に沈んだ東京と氷山。隅に「イメージ」)。地図の版は thumb_bg.py。
字は左に「南極の氷が 全部とけたら」「海面 ＋58m」(数字は黄色)。"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = Path(__file__).resolve().parent
OUT = HERE.parents[1] / "out" / "antarctic"
OUT.mkdir(parents=True, exist_ok=True)
YEL, WHITE, INK, RED = (255, 222, 0), (255, 255, 255), (8, 10, 18), (240, 40, 40)
S = 1280 / 1920
CITY = {"東京": (1589, 461), "北京": (562, 289), "上海": (727, 686)}   # thumb_bg.py の範囲(126, 34, 40, 30)での位置

bg = Image.open(HERE / "assets" / "thumb_bg.jpg").convert("RGB")    # Gemini で作った絵(海に沈んだ東京と氷山)
bg = bg.resize((round(bg.width * 720 / bg.height), 720), Image.LANCZOS)
img = bg.crop((0, 0, 1280, 720))
a = np.asarray(img).astype(np.float32)
xx = np.linspace(0, 1, 1280, dtype=np.float32)[None, :, None]
a *= 1 - 0.45 * np.clip((0.5 - xx) / 0.5, 0, 1)                  # 左を暗くして字を立てる
img = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).convert("RGBA")


def font(size, weight="Black"):
    f = ImageFont.truetype("C:/Windows/Fonts/NotoSansJP-VF.ttf", size)
    f.set_variation_by_name(weight)
    return f


def big(xy, s, size, col, stroke=12, anchor="la"):
    f = font(size)
    sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).text((xy[0] + 6, xy[1] + 9), s, font=f, fill=(0, 0, 0, 210), anchor=anchor, stroke_width=stroke + 3, stroke_fill=(0, 0, 0, 210))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(7)))
    ImageDraw.Draw(img).text(xy, s, font=f, fill=col, anchor=anchor, stroke_width=stroke, stroke_fill=INK)


big((34, 24), "南極の氷が全部とけたら", 80, WHITE, 12)    # 左の氷山(y 200 前後)は隠さない
big((44, 300), "海面", 96, WHITE, 12)
big((28, 420), "＋58m", 236, YEL, 16)
ImageDraw.Draw(img).text((1262, 706), "イメージ", font=font(24, "Bold"), fill=(255, 255, 255, 200), anchor="rd", stroke_width=3, stroke_fill=INK)
img.convert("RGB").save(OUT / "thumb_long.jpg", quality=93)
print(OUT / "thumb_long.jpg")
