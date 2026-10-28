"""進撃の巨人の本編のサムネイル(1280×720)。作品の絵は使わず、壁の向こうから顔を出す巨人の影絵(自作)に、
「進撃の巨人」の札と計算の答えを重ね、右下に骨の負担のメーター(強さの1.7倍)を入れる。python episodes/shingeki/thumb.py"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
sys.path.insert(0, str(Path(__file__).resolve().parent))
from PIL import Image, ImageDraw, ImageFilter  # noqa: E402

from naze import overlay as O  # noqa: E402

HERE = Path(__file__).resolve().parent
OUT = HERE.parents[1] / "out" / "shingeki"
OUT.mkdir(parents=True, exist_ok=True)
W, H = 2560, 1440
GIANT = (165, 60, 50)

img = Image.new("RGBA", (W, H), (0, 0, 0, 255))
d = ImageDraw.Draw(img)
for y in range(H):                                       # 夕方の空
    u = y / H
    d.line([(0, y), (W, y)], fill=(int(30 + 150 * u), int(40 + 60 * u), int(80 + 20 * u)))
gy = H - 60
sc = 21.0                                                # 1m のピクセル
gx = W * 0.72


def person(x, yb, hp, col):
    u = hp / 8.0
    d.ellipse([x - u * 0.42, yb - hp, x + u * 0.42, yb - hp + u], fill=col)
    d.rounded_rectangle([x - u * 0.95, yb - hp + u * 1.05, x + u * 0.95, yb - u * 3.9], radius=int(u * 0.35), fill=col)
    d.line([(x - u * 0.45, yb - u * 4.0), (x - u * 0.55, yb)], fill=col, width=int(u * 0.62))
    d.line([(x + u * 0.45, yb - u * 4.0), (x + u * 0.55, yb)], fill=col, width=int(u * 0.62))
    d.line([(x - u * 1.0, yb - hp + u * 1.3), (x - u * 1.35, yb - u * 4.1)], fill=col, width=int(u * 0.42))
    d.line([(x + u * 1.0, yb - hp + u * 1.3), (x + u * 1.35, yb - u * 4.1)], fill=col, width=int(u * 0.42))


person(gx, gy + 300, 60 * sc + 300, GIANT)               # 壁の上に胸から上が出るように少し大きく
wy = gy - 50 * sc * 0.62
d.rectangle([0, wy, W, H], fill=(118, 110, 98))
for i in range(0, W, 90):
    d.line([(i, wy), (i, H)], fill=(98, 92, 82), width=3)
d.rectangle([0, wy - 14, W, wy + 8], fill=(150, 140, 125))
# 字の下を暗く
sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
ds = ImageDraw.Draw(sh)
for x in range(1500):
    ds.line([(x, 0), (x, H)], fill=O.NAVY + (int(200 * (1 - x / 1500) ** 0.7),))
img.alpha_composite(sh)
d = ImageDraw.Draw(img)

f = O.font(120)
t = "進撃の巨人"
w = f.getlength(t) + 110
d.rounded_rectangle([80, 70, 80 + w, 70 + 175], 38, fill=(170, 40, 40), outline=O.WHITE, width=8)
d.text((80 + w / 2, 70 + 88), t, font=f, fill=O.WHITE, anchor="mm")
d.text((80 + w + 30, 70 + 88), "の超大型巨人を", font=O.font(110), fill=O.WHITE, anchor="lm", stroke_width=14, stroke_fill=O.NAVY)
d.text((gx + 330, 260), "60m", font=O.font(110), fill=O.YEL, anchor="lm", stroke_width=12, stroke_fill=O.NAVY)


def row(s, y, size):
    x = 90
    for part, hl in O.parse(s):
        ff = O.font(size)
        d.text((x, y), part, font=ff, fill=O.YEL if hl else O.WHITE, stroke_width=max(12, size // 9), stroke_fill=O.NAVY)
        x += ff.getlength(part)


row("人の体で作ったら", 300, 170)
row("【歩くだけで】", 530, 210)
row("【骨が折れる】", 780, 210)
# 骨の負担のメーター
mx0, mx1, my = 1580, 2440, 1240
d.rounded_rectangle([mx0 - 40, my - 200, mx1 + 40, my + 110], 30, fill=O.NAVY + (235,), outline=O.WHITE, width=5)
d.text(((mx0 + mx1) / 2, my - 150), "骨の負担", font=O.font(64), fill=O.DIM, anchor="mm")
d.rounded_rectangle([mx0, my - 60, mx1, my + 40], 20, fill=(30, 40, 60), outline=O.DIM, width=4)
d.rounded_rectangle([mx0, my - 60, mx0 + (mx1 - mx0) * 1.72 / 2.0, my + 40], 20, fill=O.RED)
xb = mx0 + (mx1 - mx0) / 2
d.line([(xb, my - 90), (xb, my + 70)], fill=O.WHITE, width=8)
d.text((mx0 + (mx1 - mx0) * 0.86 - 10, my - 10), "1.7倍", font=O.font(80), fill=O.WHITE, anchor="rm", stroke_width=8, stroke_fill=O.NAVY)
d.text((xb, my + 90), "骨の強さ", font=O.font(40), fill=O.WHITE, anchor="mm", stroke_width=5, stroke_fill=O.NAVY)
img.convert("RGB").resize((1280, 720), Image.LANCZOS).save(OUT / "thumb_long.jpg", quality=93)
print(OUT / "thumb_long.jpg")
