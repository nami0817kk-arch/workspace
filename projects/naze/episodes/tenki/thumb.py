"""天気の子の本編のサムネイル(1280×720)。標高データの立体に、仮の計算の水位 5.7m(1年ぶん)まで水を上げたコマ(out/tenki_ch2/stills/s_2327.png)に字を重ねる。
映画の絵は使わない。python episodes/tenki/thumb.py"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from PIL import Image, ImageDraw  # noqa: E402

from naze import overlay as O  # noqa: E402

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = ROOT / "out" / "tenki"
OUT.mkdir(parents=True, exist_ok=True)
W, H = 2560, 1440

src = Image.open(ROOT / "out" / "tenki_ch2" / "stills" / "s_2327.png").convert("RGB")
z = 1.55                                                     # 沈んだ東の街を大きく、右下に寄せる
cw, ch = src.width / z, src.height / z
cx, cy = src.width * 0.40, src.height * 0.60
img = src.crop((int(cx - cw / 2), int(cy - ch / 2), int(cx + cw / 2), int(cy + ch / 2))).resize((W, H), Image.LANCZOS).convert("RGBA")
sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
d = ImageDraw.Draw(sh)
for y in range(H):
    d.line([(0, y), (W, y)], fill=O.NAVY + (int(190 * max(0.0, 1 - y / (H * 0.55))),))
img.alpha_composite(sh)
d = ImageDraw.Draw(img)


def rows(lines, x, y, size, gap=1.2):
    for i, row in enumerate(lines):
        xx = x
        for t, hl in O.parse(row):
            f = O.font(size)
            d.text((xx, y + i * size * gap), t, font=f, fill=O.YEL if hl else O.WHITE, stroke_width=16, stroke_fill=O.NAVY)
            xx += f.getlength(t)


rows(["仮に雨が流れなかったら", "東京は1年で【水位5.7m】"], 90, 80, 150)
f1, f2 = O.font(60), O.font(96)
bx, by = 1640, 1010
lay = Image.new("RGBA", img.size, (0, 0, 0, 0))
ImageDraw.Draw(lay).rounded_rectangle([bx, by, bx + 820, by + 300], 30, fill=O.NAVY + (215,), outline=O.BLUE + (255,), width=6)
img.alpha_composite(lay)
d = ImageDraw.Draw(img)
d.text((bx + 410, by + 80), "23区の約2割は", font=f1, fill=O.WHITE, anchor="mm")
d.text((bx + 410, by + 195), "もう海より低い", font=f2, fill=O.BLUE, anchor="mm")
d.text((96, 1320), "国土地理院の標高データで計算（仮の計算）", font=O.font(50), fill=O.WHITE, stroke_width=7, stroke_fill=O.NAVY)
img.convert("RGB").resize((1280, 720), Image.LANCZOS).save(OUT / "thumb_long.jpg", quality=93)
print(OUT / "thumb_long.jpg")
