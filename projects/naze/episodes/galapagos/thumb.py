"""ガラパゴスの回の本編のサムネイル(1280×720)。python episodes/galapagos/thumb.py → out/galapagos/thumb_long.jpg
題材は「生き物がここにしかいない理由」なので、1 種ではなく 3 種(ウミイグアナ・ゾウガメ・ペンギン)を並べる
(2026-11-18「題材とサムネ違くない？」。最初はウミイグアナ 1 匹と「海に潜るトカゲ」の札で、トカゲの話に見えた)。
写真は sim/photos.json(Wikimedia Commons。色を濃くして切り抜いた)。大きな字は 2 行・黄色は 1 か所・札は赤地に白。"""
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = Path(__file__).resolve().parent
OUT = HERE.parents[1] / "out" / "galapagos"
SRC = json.loads((HERE / "sim" / "photos.json").read_text(encoding="utf-8"))
YEL, WHITE, INK = (255, 222, 0), (255, 255, 255), (8, 10, 18)
PW = 1280 // 3
# (写真, 切り出す中心 x, y(写真の幅・高さに対する割合), 写真の高さの何割を使うか, 札)
PANELS = [("swim", 0.36, 0.45, 0.80, "海に潜るトカゲ"),
          ("domeeat", 0.47, 0.50, 0.85, "1年食べないカメ"),
          ("penguin", 0.50, 0.45, 0.80, "赤道のペンギン")]


def font(size, weight="Black"):
    f = ImageFont.truetype("C:/Windows/Fonts/NotoSansJP-VF.ttf", size)
    f.set_variation_by_name(weight)
    return f


img = Image.new("RGBA", (1280, 720), (10, 14, 24, 255))
for i, (name, fx, fy, fh, lab) in enumerate(PANELS):
    ph = Image.open(OUT / "photos" / f"{name}.jpg").convert("RGB")
    ch = ph.height * fh
    cw = ch * PW / 720
    x0 = min(max(0, ph.width * fx - cw / 2), ph.width - cw)
    y0 = min(max(0, ph.height * fy - ch / 2), ph.height - ch)
    p = ph.resize((PW, 720), Image.LANCZOS, box=(x0, y0, x0 + cw, y0 + ch))
    a = np.asarray(p).astype(np.float32) / 255
    g = a.mean(axis=2, keepdims=True)
    a = np.clip(g + (a - g) * 1.3, 0, 1)
    a = np.clip((a - 0.5) * 1.12 + 0.5, 0, 1)
    yy = np.linspace(0, 1, 720, dtype=np.float32)[:, None, None]
    a *= 1 - 0.7 * np.clip((yy - 0.45) / 0.55, 0, 1)                 # 下を暗くして字を立てる
    img.paste(Image.fromarray((a * 255).astype(np.uint8)).convert("RGBA"), (i * PW, 0))
d = ImageDraw.Draw(img)
for i in (1, 2):
    d.line([(i * PW, 0), (i * PW, 720)], fill=(255, 255, 255, 255), width=6)

# 札(赤地に白)を各パネルの上に
ft = font(40)
for i, (_, _, _, _, lab) in enumerate(PANELS):
    cx = i * PW + PW / 2
    bx = d.textbbox((cx, 58), lab, font=ft, anchor="mm")
    pad = 14
    shd = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(shd).rounded_rectangle((bx[0] - pad + 6, bx[1] - pad + 8, bx[2] + pad + 6, bx[3] + pad + 8), 14, fill=(0, 0, 0, 190))
    img.alpha_composite(shd.filter(ImageFilter.GaussianBlur(6)))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((bx[0] - pad, bx[1] - pad, bx[2] + pad, bx[3] + pad), 14, fill=(225, 35, 35, 255), outline=(255, 255, 255, 255), width=4)
    d.text((cx, 58), lab, font=ft, fill=WHITE, anchor="mm")


def big(xy, s, size, col, stroke=12, anchor="mm"):
    f = font(size)
    sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).text((xy[0] + 6, xy[1] + 9), s, font=f, fill=(0, 0, 0, 220), anchor=anchor, stroke_width=stroke + 3, stroke_fill=(0, 0, 0, 220))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(7)))
    ImageDraw.Draw(img).text(xy, s, font=f, fill=col, anchor=anchor, stroke_width=stroke, stroke_fill=INK)


big((640, 478), "爬虫類の97%がここだけ", 88, WHITE, 13)
big((640, 606), "ガラパゴスにしかいない理由", 92, YEL, 15)
cr = " / ".join(SRC[n]["artist"] for n, *_ in PANELS)
ImageDraw.Draw(img).text((1270, 712), f"写真: {cr}（CC BY / BY-SA）", font=font(18, "Bold"), fill=(255, 255, 255, 200), anchor="rd", stroke_width=3, stroke_fill=INK)
img.convert("RGB").save(OUT / "thumb_long.jpg", quality=93)
print(OUT / "thumb_long.jpg")
