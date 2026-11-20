"""トガリネズミの回の本編のサムネイル(1280×720)。python episodes/shrew/thumb.py → out/shrew/thumb_long.jpg
下地は Gemini で作った絵(assets/gem_snow.jpg、雪の上のトガリネズミ。虫の絵はサムネに使わない(2026-11-07 指示)。隅に「イメージ」)。
字は「見たら何がわかるか」を書く(2026-11-07 指示)。上に「毎日 自分の6倍を食べる」、大きく「小さい動物ほど 大食いな理由」(理由の行だけ黄色)。"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = Path(__file__).resolve().parent
OUT = HERE.parents[1] / "out" / "shrew"
OUT.mkdir(parents=True, exist_ok=True)
YEL, WHITE, INK, RED = (255, 222, 0), (255, 255, 255), (8, 10, 18), (240, 40, 40)
S = 1280 / 1920
CITY = {"東京": (1589, 461), "北京": (562, 289), "上海": (727, 686)}   # thumb_bg.py の範囲(126, 34, 40, 30)での位置

bg = Image.open(HERE / "assets" / "gem_snow.jpg").convert("RGB")    # Gemini で作った絵(雪の上のトガリネズミ)
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


big((34, 40), "毎日 自分の6倍を食べる", 60, WHITE, 11)                # 右下のトガリネズミを隠さないよう、字は左の 680px に収める
big((34, 150), "小さい動物ほど", 90, WHITE, 13)
big((28, 280), "大食いな理由", 104, YEL, 15)
ImageDraw.Draw(img).text((1262, 706), "イメージ", font=font(24, "Bold"), fill=(255, 255, 255, 200), anchor="rd", stroke_width=3, stroke_fill=INK)
img.convert("RGB").save(OUT / "thumb_long.jpg", quality=93)
print(OUT / "thumb_long.jpg")
