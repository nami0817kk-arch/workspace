"""電子レンジの本編のサムネイル(1280×720)。厚さ 10cm の水のかたまりを温めた計算の断面(一番熱い所が 100℃ になった瞬間)を右に大きく描き、
左に「電子レンジは／中から温めて【いなかった】」。真ん中の 23℃ に赤い丸。python episodes/renji/thumb.py"""
import os
import sys
from pathlib import Path

os.environ["NAZE_ASPECT"] = "landscape"
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1]))
sys.path.insert(0, str(HERE))
from PIL import Image, ImageDraw, ImageFilter  # noqa: E402

from naze import overlay as O  # noqa: E402
import scene  # noqa: E402

OUT = HERE.parents[1] / "out" / "renji"
OUT.mkdir(parents=True, exist_ok=True)
W, H = 2560, 1440

img = Image.new("RGBA", (W, H), (10, 18, 40, 255))
scene.grad(img, (10, 18, 40), (18, 34, 70), (0, 0, W, H))
r = scene.heat_run(0.10)
prof, cen, _ = scene.snap(r, r["end"])

# 断面(右側)。上下から電波
bx0, by0, bw, bh = 1420, 250, 1000, 1000
d = ImageDraw.Draw(img)
n = len(prof)
for yy in range(0, bh, 2):
    z = (yy + 1) / bh * (n - 1)
    i = int(z)
    f = z - i
    T = prof[i] * (1 - f) + prof[min(n - 1, i + 1)] * f
    d.rectangle([bx0, by0 + yy, bx0 + bw, by0 + yy + 2], fill=scene.tcol(T))
d.rectangle([bx0, by0, bx0 + bw, by0 + bh], outline=(255, 255, 255), width=8)
for j in range(5):
    x = bx0 + bw * (j + 0.5) / 5
    for (ya, yb) in ((by0 - 170, by0 - 20), (by0 + bh + 170, by0 + bh + 20)):
        scene.squiggle(d, x, ya, yb, 0.0, (150, 220, 255), amp=12, lam=46, w=7)

big = O.font(96)
for (yy, s, col) in ((by0 + 70, "100℃", (255, 255, 255)), (by0 + bh - 70, "100℃", (255, 255, 255))):
    d.text((bx0 + bw - 40, yy), s, font=big, fill=col, anchor="rm", stroke_width=10, stroke_fill=O.NAVY)
cy = by0 + bh / 2
d.text((bx0 + bw / 2, cy), f"{cen:.0f}℃", font=O.font(170), fill=(255, 255, 255), anchor="mm", stroke_width=14, stroke_fill=O.NAVY)
rr = 190
d.ellipse([bx0 + bw / 2 - rr * 1.25, cy - rr, bx0 + bw / 2 + rr * 1.25, cy + rr], outline=(240, 40, 40), width=18)

# 字の後ろを紺でぼかす
sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
ds = ImageDraw.Draw(sh)
ds.rectangle([0, 0, 1380, H], fill=O.NAVY + (150,))
img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(60)))
d = ImageDraw.Draw(img)


def line(x, y, parts, size):
    f = O.font(size)
    for t, col in parts:
        d.text((x, y), t, font=f, fill=col, stroke_width=18, stroke_fill=O.NAVY)
        x += f.getlength(t)


line(90, 250, [("電子レンジは", O.WHITE)], 190)
line(90, 520, [("中から温めて", O.WHITE)], 190)
line(90, 790, [("いなかった", O.YEL)], 230)
d.text((100, 1170), "厚さ10cmを温める計算", font=O.font(80), fill=O.DIM, stroke_width=8, stroke_fill=O.NAVY)
img.convert("RGB").resize((1280, 720), Image.LANCZOS).save(OUT / "thumb_long.jpg", quality=93)
print(OUT / "thumb_long.jpg")
