"""富士山の回の図の素材(地図)を描く。python episodes/fuji/make_assets.py → episodes/fuji/assets/*.png"""
import os
import sys
from pathlib import Path

os.environ["NAZE_ASPECT"] = "landscape"
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from PIL import ImageDraw  # noqa: E402

from naze import mapscene as M  # noqa: E402
from naze import overlay as O  # noqa: E402

A = Path(__file__).resolve().parent / "assets"
A.mkdir(exist_ok=True)
FUJI = (138.7274, 35.3606)


def mark(img, v, lonlat, text, col=O.YEL, size=48, dy=-60):
    x, y = v.px(*lonlat)
    d = ImageDraw.Draw(img)
    d.polygon([(x, y - 22), (x - 20, y + 14), (x + 20, y + 14)], fill=col, outline=O.NAVY)
    f = O.font(size)
    d.text((x - f.getlength(text) / 2, y + dy), text, font=f, fill=col, stroke_width=7, stroke_fill=O.NAVY)


# 1. 富士山の下の 3 枚のプレート
v = M.View(138.6, 35.0, 9)
img = M.base(v)
M.draw_layer(img, v, dict(kind="plates", fill=True), 1, 1)
M.draw_layer(img, v, dict(kind="plates"), 1, 1)
for g, ll in {"NA": (140.4, 36.9), "EU": (136.3, 36.3), "PS": (138.6, 33.4)}.items():
    M.draw_layer(img, v, dict(kind="label", at_ll=ll, text=M.PLATE_NAME[g], color=M.PLATE_COL[g], size=54), 1, 1)
mark(img, v, FUJI, "富士山", size=60)
img.convert("RGB").save(A / "plates_fuji.png")

# 2. 宝永噴火の灰が届いた所(江戸・川崎・房総)。下地は国土地理院の陰影起伏図＋淡色地図のタイル(細かい)
import io  # noqa: E402
import math  # noqa: E402
import time  # noqa: E402
import urllib.request  # noqa: E402

from PIL import Image  # noqa: E402

from naze.config import CACHE  # noqa: E402


def gsi_tiles(kind, ext, lon0, lat0, lon1, lat1, z):
    def txy(lon, lat):
        n = 2 ** z
        return (lon + 180) / 360 * n, (1 - math.log(math.tan(math.radians(lat)) + 1 / math.cos(math.radians(lat))) / math.pi) / 2 * n
    x0, y0 = txy(lon0, lat1)
    x1, y1 = txy(lon1, lat0)
    td = CACHE / "gsimap" / kind
    td.mkdir(parents=True, exist_ok=True)
    big = Image.new("RGB", ((int(x1) - int(x0) + 1) * 256, (int(y1) - int(y0) + 1) * 256), (200, 220, 235))
    for ty in range(int(y0), int(y1) + 1):
        for tx in range(int(x0), int(x1) + 1):
            p = td / f"{z}_{tx}_{ty}.{ext}"
            if not p.exists():
                try:
                    p.write_bytes(urllib.request.urlopen(f"https://cyberjapandata.gsi.go.jp/xyz/{kind}/{z}/{tx}/{ty}.{ext}", timeout=30).read())
                except Exception:
                    continue
                time.sleep(0.1)
            big.paste(Image.open(p).convert("RGB"), ((tx - int(x0)) * 256, (ty - int(y0)) * 256))
    ox, oy = (x0 - int(x0)) * 256, (y0 - int(y0)) * 256
    img = big.crop((int(ox), int(oy), int(ox + (x1 - x0) * 256), int(oy + (y1 - y0) * 256)))
    return img, (x0, y0, x1, y1)


BB = (138.35, 34.85, 140.55, 36.0)
pale, (tx0, ty0, tx1, ty1) = gsi_tiles("pale", "png", *BB, 10)
hill, _ = gsi_tiles("hillshademap", "png", *BB, 10)
img = Image.blend(pale, hill.resize(pale.size), 0.35).resize((1920, int(1920 * pale.height / pale.width)), Image.LANCZOS)
img = img.crop((0, (img.height - 1080) // 2, 1920, (img.height - 1080) // 2 + 1080)) if img.height >= 1080 else img.resize((1920, 1080))
crop_off = 0


class _V:
    def px(self, lon, lat):
        n = 2 ** 10
        x = (lon + 180) / 360 * n
        y = (1 - math.log(math.tan(math.radians(lat)) + 1 / math.cos(math.radians(lat))) / math.pi) / 2 * n
        return (x - tx0) / (tx1 - tx0) * 1920, (y - ty0) / (ty1 - ty0) * 1080


v = _V()
img = img.convert("RGBA")
d = ImageDraw.Draw(img)
x0, y0 = v.px(*FUJI)
for ll in ((139.7671, 35.6812), (139.7030, 35.5308), (140.1, 35.3)):
    x1, y1 = v.px(*ll)
    for s in range(0, 1000, 40):
        f0, f1 = s / 1000, min(1, (s + 22) / 1000)
        d.line([(x0 + (x1 - x0) * f0, y0 + (y1 - y0) * f0), (x0 + (x1 - x0) * f1, y0 + (y1 - y0) * f1)], fill=(120, 70, 40), width=10)
mark(img, v, FUJI, "富士山", size=56)
mark(img, v, (139.7671, 35.6812), "江戸", col=O.WHITE, size=52)
mark(img, v, (139.7030, 35.5308), "川崎 厚さ5cm", col=O.WHITE, size=46, dy=24)
mark(img, v, (140.1, 35.3), "房総半島", col=O.WHITE, size=46, dy=24)
img.convert("RGB").save(A / "ash_hoei.png")
print("ok", list(A.glob("*.png")))
