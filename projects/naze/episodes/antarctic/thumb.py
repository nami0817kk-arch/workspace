"""南極の回の本編のサムネイル(1280×720)。python episodes/antarctic/thumb.py → out/antarctic/thumb_long.jpg
下地は thumb_bg.py で描いた、海面を 58m 上げた東アジア(assets/thumb_map.png、自分で計算した塗り)。
字は 2 つ: 上に「南極の氷が全部とけたら」、右下に「海面 ＋58m」(数字は黄色)。東京・北京・上海に印、東京に赤い丸。"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = Path(__file__).resolve().parent
OUT = HERE.parents[1] / "out" / "antarctic"
OUT.mkdir(parents=True, exist_ok=True)
YEL, WHITE, INK, RED = (255, 222, 0), (255, 255, 255), (8, 10, 18), (240, 40, 40)
S = 1280 / 1920
CITY = {"東京": (1589, 461), "北京": (562, 289), "上海": (727, 686)}   # thumb_bg.py の範囲(126, 34, 40, 30)での位置

img = Image.open(HERE / "assets" / "thumb_map.png").convert("RGB").resize((1280, 720), Image.LANCZOS)
a = np.asarray(img).astype(np.float32)
y = np.linspace(0, 1, 720, dtype=np.float32)[:, None, None]
a *= np.clip(0.62 + y * 1.6, 0.62, 1.0)                         # 上を暗くして字を立てる
xx = np.linspace(0, 1, 1280, dtype=np.float32)[None, :, None]
a *= 1 - 0.35 * np.clip((xx - 0.55) / 0.45, 0, 1) * np.clip((y - 0.55) / 0.45, 0, 1)   # 右下も少し暗く
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


d = ImageDraw.Draw(img)
for name, (x, y_) in CITY.items():
    x, y_ = x * S, y_ * S
    if name == "東京":
        for w, c in ((16, INK), (9, RED)):
            d.ellipse([x - 52, y_ - 52, x + 52, y_ + 52], outline=c, width=w)
    d.ellipse([x - 9, y_ - 9, x + 9, y_ + 9], fill=WHITE, outline=INK, width=3)
    big((x, y_ - 66 if name == "東京" else y_ - 22), name, 46, WHITE, 8, "md")
big((34, 22), "南極の氷が全部とけたら", 84, WHITE, 12)
big((1250, 392), "海面", 86, WHITE, 12, "ra")
big((1258, 700), "＋58m", 220, YEL, 15, "rd")
img.convert("RGB").save(OUT / "thumb_long.jpg", quality=93)
print(OUT / "thumb_long.jpg")
