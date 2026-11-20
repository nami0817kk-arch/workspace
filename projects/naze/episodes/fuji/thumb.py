"""富士山の本編のサムネイル(1280×720)。Gemini で作った富士山の絵(assets/fuji_gemini.jpg、南から見た夕景)に、
標高データで実測した傾き(山頂近く 西38°・東22°)の札と、問いの字を重ねる。python episodes/fuji/thumb.py"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from PIL import Image, ImageDraw  # noqa: E402

from naze import overlay as O  # noqa: E402

HERE = Path(__file__).resolve().parent
OUT = HERE.parents[1] / "out" / "fuji"
OUT.mkdir(parents=True, exist_ok=True)
W, H = 2560, 1440

img = Image.open(HERE / "assets" / "fuji_gemini.jpg").convert("RGB").resize((W, H), Image.LANCZOS).convert("RGBA")
# 左側を少し暗くして字を立たせる
grad = Image.new("L", (W, 1))
for x in range(W):
    grad.putpixel((x, 0), int(170 * max(0.0, 1 - x / (W * 0.55))))
sh = Image.new("RGBA", (W, H), O.NAVY + (0,))
sh.putalpha(grad.resize((W, H)))
img.alpha_composite(sh)
d = ImageDraw.Draw(img)


def rows(lines, x, y, size, gap=1.18):
    for i, row in enumerate(lines):
        xx = x
        for t, hl in O.parse(row):
            f = O.font(size)
            d.text((xx, y + i * size * gap), t, font=f, fill=O.YEL if hl else O.WHITE, stroke_width=16, stroke_fill=O.NAVY)
            xx += f.getlength(t)


def badge(cx, cy, side, deg):
    """斜面の横の札: 「西」「東」と大きな角度。"""
    f1, f2 = O.font(64), O.font(150)
    t1, t2 = side, f"{deg}°"
    w = max(f1.getlength(t1), f2.getlength(t2)) + 90
    h = 64 + 150 + 70
    lay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(lay).rounded_rectangle([cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2], 34, fill=O.NAVY + (205,), outline=O.YEL + (255,), width=6)
    img.alpha_composite(lay)
    dd = ImageDraw.Draw(img)
    dd.text((cx - f1.getlength(t1) / 2, cy - h / 2 + 22), t1, font=f1, fill=O.WHITE)
    dd.text((cx - f2.getlength(t2) / 2, cy - h / 2 + 82), t2, font=f2, fill=O.YEL)


badge(1500, 560, "西", 38)
badge(2330, 560, "東", 22)
d = ImageDraw.Draw(img)
rows(["富士山は", "【左右対称】", "じゃなかった"], 90, 200, 160)
d.text((96, 1240), "国土地理院の標高データで測定", font=O.font(54), fill=O.WHITE, stroke_width=7, stroke_fill=O.NAVY)
img.convert("RGB").resize((1280, 720), Image.LANCZOS).save(OUT / "thumb_long.jpg", quality=93)
print(OUT / "thumb_long.jpg")
