"""海を抜く回の本編のサムネイル(1280×720)。python episodes/drain/thumb.py → out/drain/thumb_long.jpg
下地は Gemini で作った絵(assets/thumb_bg.jpg、海の水が消えた地球。隅に「イメージ」)。
字は左に「海の水を 全部抜いたら」「最後に残るのは？」(黄色)。"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = Path(__file__).resolve().parent
OUT = HERE.parents[1] / "out" / "drain"
OUT.mkdir(parents=True, exist_ok=True)
YEL, WHITE, INK, RED = (255, 222, 0), (255, 255, 255), (8, 10, 18), (240, 40, 40)
S = 1280 / 1920
CITY = {"東京": (1589, 461), "北京": (562, 289), "上海": (727, 686)}   # thumb_bg.py の範囲(126, 34, 40, 30)での位置

bg = Image.open(HERE / "assets" / "thumb_bg.jpg").convert("RGB")    # Gemini で作った絵(海の水が消えた地球)
bg = bg.resize((round(bg.width * 720 / bg.height), 720), Image.LANCZOS)
img = bg.crop((0, 0, 1280, 720))
a = np.asarray(img).astype(np.float32)
xx = np.linspace(0, 1, 1280, dtype=np.float32)[None, :, None]
a *= 1 - 0.55 * np.clip((0.55 - xx) / 0.55, 0, 1)                  # 左を暗くして字を立てる
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


big((34, 40), "海の水を", 104, WHITE, 13)
big((34, 175), "全部抜いたら", 104, WHITE, 13)
big((34, 420), "最後に", 96, WHITE, 13)
big((34, 535), "残るのは？", 120, YEL, 15)
ImageDraw.Draw(img).text((1262, 706), "イメージ", font=font(24, "Bold"), fill=(255, 255, 255, 200), anchor="rd", stroke_width=3, stroke_fill=INK)
img.convert("RGB").save(OUT / "thumb_long.jpg", quality=93)
print(OUT / "thumb_long.jpg")
