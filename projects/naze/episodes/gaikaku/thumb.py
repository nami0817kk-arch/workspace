"""首都圏外郭放水路の回の本編のサムネイル(1280×720)。python episodes/gaikaku/thumb.py → out/gaikaku/thumb_long.jpg
下地は調圧水槽の写真(Wikimedia Commons、CC0、2 枚並びの左半分)。札は赤地に白・大きな字は 2 行・黄色は 1 か所(galapagos/thumb.py の作りを写した)。"""
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = Path(__file__).resolve().parent
OUT = HERE.parents[1] / "out" / "gaikaku"
SRC = json.loads((HERE / "sim" / "photos.json").read_text(encoding="utf-8"))
YEL, WHITE, INK = (255, 222, 0), (255, 255, 255), (8, 10, 18)


def font(size, weight="Black"):
    f = ImageFont.truetype("C:/Windows/Fonts/NotoSansJP-VF.ttf", size)
    f.set_variation_by_name(weight)
    return f


ph = Image.open(OUT / "photos" / "tankgold.jpg").convert("RGB")
# 1280×720 に切り出す(柱の並びが右へ奥行きを作る位置)
s = max(1280 / ph.width, 720 / ph.height)
ph = ph.resize((round(ph.width * s), round(ph.height * s)), Image.LANCZOS)
x0 = 0
y0 = int(ph.height * 0.40 - 360)
ph = ph.crop((x0, y0, x0 + 1280, y0 + 720))
a = np.asarray(ph).astype(np.float32) / 255
g = a.mean(axis=2, keepdims=True)
a = np.clip(g + (a - g) * 1.25, 0, 1)
a = np.clip((a - 0.5) * 1.1 + 0.5, 0, 1)
yy = np.linspace(0, 1, 720, dtype=np.float32)[:, None, None]
a *= 1 - 0.78 * np.clip((yy - 0.35) / 0.65, 0, 1)                    # 下を暗くして字を立てる
xx = np.linspace(0, 1, 1280, dtype=np.float32)[None, :, None]
a *= 1 - 0.35 * np.clip((0.55 - xx) / 0.55, 0, 1)                    # 左も少し暗く(字の側)
img = Image.fromarray((a * 255).astype(np.uint8)).convert("RGBA")
d = ImageDraw.Draw(img)


def shadow_box(box, r=14):
    shd = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(shd).rounded_rectangle((box[0] + 6, box[1] + 8, box[2] + 6, box[3] + 8), r, fill=(0, 0, 0, 190))
    img.alpha_composite(shd.filter(ImageFilter.GaussianBlur(6)))


def big(xy, s, size, col, stroke=12, anchor="lm"):
    f = font(size)
    sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).text((xy[0] + 6, xy[1] + 9), s, font=f, fill=(0, 0, 0, 220), anchor=anchor, stroke_width=stroke + 3, stroke_fill=(0, 0, 0, 220))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(7)))
    ImageDraw.Draw(img).text(xy, s, font=f, fill=col, anchor=anchor, stroke_width=stroke, stroke_fill=INK)


# 札(赤地に白)
lab = "春日部のサッカー場の地下"
ft = font(44)
bx = d.textbbox((46, 62), lab, font=ft, anchor="lm")
pad = 16
box = (bx[0] - pad, bx[1] - pad, bx[2] + pad, bx[3] + pad)
shadow_box(box)
d = ImageDraw.Draw(img)
d.rounded_rectangle(box, 14, fill=(225, 35, 35, 255), outline=WHITE, width=4)
d.text((46, 62), lab, font=ft, fill=WHITE, anchor="lm")
big((46, 470), "川を地下50mに", 120, WHITE, 14)
big((46, 612), "造った理由", 128, YEL, 15)
ImageDraw.Draw(img).text((1270, 712), f"写真: {SRC['tankgold']['artist']}（{SRC['tankgold']['license']}）", font=font(18, "Bold"), fill=(255, 255, 255, 200), anchor="rd", stroke_width=3, stroke_fill=INK)
img.convert("RGB").save(OUT / "thumb_long.jpg", quality=93)
print(OUT / "thumb_long.jpg")
