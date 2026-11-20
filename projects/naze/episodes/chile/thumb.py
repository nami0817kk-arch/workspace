"""チリの本編のサムネイル(1280×720)。python episodes/chile/thumb.py → out/chile/thumb_long.jpg
2026-11-05 人気の地理の回 12 本を見て作り直し: 大陸の形がひと目で分かる真上の地図・字は大きく 3 段まで・主役を指す・比べる物を並べる。
- 地図は下地だけ描き、チリと日本の形は自前で塗る(影で浮かせ、縁を光らせる)
- 日本は本当の大きさで、チリの西の海に置く(北の端をそろえて長さを比べられるように)
- 「93km」から、いちばん狭い所(南緯31.55度・自分で測った値)へ線を引いて、字と地図をつなぐ
- 字は Noto Sans JP の Black。縁は黒、その下に柔らかい影"""
import math
import os
import sys
from pathlib import Path

os.environ["NAZE_ASPECT"] = "landscape"
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1]))
sys.path.insert(0, str(HERE))
import numpy as np  # noqa: E402
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont  # noqa: E402

import scene  # noqa: E402
from naze import worldmap  # noqa: E402
from naze.config import H, W  # noqa: E402

OUT = HERE.parents[1] / "out" / "chile"
OUT.mkdir(parents=True, exist_ok=True)
INK, YEL, WHITE, RED = (8, 10, 18), (255, 222, 0), (255, 255, 255), (235, 40, 35)
VIEW = (-66, -33, 104, 0)                                  # 真上から南米
NARROW = (-70.9, -31.55)                                   # いちばん狭い所(sim/calc.txt)
_fonts = {}


def font(size, weight="Black"):
    k = (size, weight)
    if k not in _fonts:
        f = ImageFont.truetype("C:/Windows/Fonts/NotoSansJP-VF.ttf", size)
        f.set_variation_by_name(weight)
        _fonts[k] = f
    return _fonts[k]


# -- 下地: 地図だけ(層なし)。色を少し濃く --
M = scene.MAP
M.finish = False
v = M.view(*VIEW)
base = Image.fromarray(M.base_img(v, 5.0)).convert("RGB")
base = ImageEnhance.Color(base).enhance(1.25)
base = ImageEnhance.Brightness(base).enhance(0.82).convert("RGBA")


def polys(rings_ll):
    return [[v.px(x, y) for x, y in r] for r in rings_ll if len(r) > 2]


def mask_of(ps):
    m = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(m)
    for p in ps:
        d.polygon(p, fill=255)
    return m


def glow(img, m, color, radius, strength=1.0):
    g = m.filter(ImageFilter.GaussianBlur(radius))
    a = np.clip(np.asarray(g, np.float32) * strength, 0, 255).astype("uint8")
    lay = Image.new("RGBA", img.size, color + (0,))
    lay.putalpha(Image.fromarray(a))
    return Image.alpha_composite(img, lay)


def shadow(img, m, dx, dy, radius, alpha):
    g = m.filter(ImageFilter.GaussianBlur(radius))
    a = (np.asarray(g, np.float32) * alpha / 255).astype("uint8")
    lay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    lay.putalpha(Image.fromarray(a))
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(lay, (dx, dy))
    return Image.alpha_composite(img, out)


def fill(img, m, top, bottom, alpha=255):
    """上から下へ色が移る塗り(平らな赤より立体に見える)。"""
    g = np.linspace(0, 1, H, dtype=np.float32)[:, None, None]
    col = np.array(top, np.float32) * (1 - g) + np.array(bottom, np.float32) * g
    lay = np.dstack([np.broadcast_to(col, (H, W, 3)), np.asarray(m, np.float32) * alpha / 255]).astype("uint8")
    return Image.alpha_composite(img, Image.fromarray(lay, "RGBA"))


def edge(m, width=3):
    """外側だけの縁(内側に食いこむと細い国が白く見える)。"""
    a = np.asarray(m.filter(ImageFilter.MaxFilter(width)), np.int16) - np.asarray(m, np.int16)
    return Image.fromarray(np.clip(a, 0, 255).astype("uint8"))


img = base
# -- 日本: 本当の大きさ。北の端をチリの北の端にそろえ、チリの西の海に --
km = [r for r in M._ghost_km("JPN")                       # 小さな島は点になるので省く
      if max(p[0] for p in r) - min(p[0] for p in r) + max(p[1] for p in r) - min(p[1] for p in r) > 60]
jy_max = max(p[1] for r in km for p in r)
chl = [r for r in worldmap.shapes("CHL") if len(r) > 8 and min(p[0] for p in r) > -77]   # 沖の島(イースター島など)は点になるので省く
chl_north = max(p[1] for r in chl for p in r)
J_LON, J_LAT = -95.0, chl_north - jy_max / 111.32 - 0.6
jp = []
for r in km:
    ring = []
    for ex, ny in r:
        lat = J_LAT + ny / 111.32
        ring.append((J_LON + ex / (111.32 * math.cos(math.radians(lat))), lat))
    jp.append(ring)
jm = mask_of(polys(jp))
img = shadow(img, jm, 10, 14, 10, 150)
img = glow(img, jm, (255, 255, 255), 14, 1.2)
img = fill(img, jm, (250, 252, 255), (205, 215, 235), 235)
img = glow(img, edge(jm), (255, 255, 255), 0.5, 1.0)

# -- チリ: 影で浮かせ、外に赤い光、中は上から下へ明るい赤→深い赤、縁は白 --
cm = mask_of(polys(chl))
img = shadow(img, cm, 10, 14, 10, 170)
img = glow(img, cm.filter(ImageFilter.MaxFilter(9)), (255, 60, 40), 22, 1.6)
img = fill(img, cm, (255, 70, 55), (200, 20, 25))
img = glow(img, edge(cm), (255, 240, 235), 0.5, 0.9)

# -- 右側の字の面: 境目が見えない、なだらかな暗さ --
xs = np.linspace(0, 1, W, dtype=np.float32)[None, :]
a = 235 * np.clip((xs - 0.47) / 0.20, 0, 1) ** 1.6
panel = np.dstack([np.full((H, W), INK[0]), np.full((H, W), INK[1]), np.full((H, W), INK[2]), np.broadcast_to(a, (H, W))]).astype("uint8")
img = Image.alpha_composite(img, Image.fromarray(panel, "RGBA"))
# 周りを少し暗く
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
vig = (np.clip(((xx / W - 0.5) ** 2 + (yy / H - 0.5) ** 2) * 1.6, 0, 1) * 150).astype("uint8")
img = Image.alpha_composite(img, Image.fromarray(np.dstack([np.zeros((H, W, 3), "uint8"), vig]), "RGBA"))


def text(img, x, y, parts, size, anchor="ls", stroke=None, weight="Black", shadow_px=10):
    """字を並べて書く。黒い縁＋下に柔らかい影。戻り値は (絵, 右端の x)。"""
    stroke = stroke if stroke is not None else max(4, int(size * 0.075))
    f = font(size, weight)
    total = sum(f.getlength(t) for t, _ in parts)
    if anchor[0] == "r":
        x -= total
    elif anchor[0] == "m":
        x -= total / 2
    an = "l" + anchor[1]
    sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ds = ImageDraw.Draw(sh)
    xx = x
    for t, _ in parts:
        ds.text((xx + shadow_px * 0.5, y + shadow_px), t, font=f, fill=(0, 0, 0, 200), anchor=an, stroke_width=stroke, stroke_fill=(0, 0, 0, 200))
        xx += f.getlength(t)
    img = Image.alpha_composite(img, sh.filter(ImageFilter.GaussianBlur(shadow_px * 0.8)))
    d = ImageDraw.Draw(img)
    xx = x
    for t, col in parts:
        d.text((xx, y), t, font=f, fill=col, anchor=an, stroke_width=stroke, stroke_fill=INK)
        xx += f.getlength(t)
    return img, xx


def tag(img, x, y, t, size, bg, fg=WHITE):
    """色の帯に白い字(右寄せの見出し)。"""
    f = font(size)
    w = f.getlength(t)
    pad = size * 0.32
    d = ImageDraw.Draw(img)
    box = (x - w - pad * 2, y - size * 1.05, x, y + size * 0.28)
    d.rounded_rectangle((box[0] + 8, box[1] + 10, box[2] + 8, box[3] + 10), 10, fill=(0, 0, 0, 150))
    d.rounded_rectangle(box, 10, fill=bg)
    d.text((x - pad, y), t, font=f, fill=fg, anchor="rs")
    return img, box


# -- 地図の上の名前 --
cx, cy = v.px(-73.6, -41.0)                                # 日本の下の海から、チリの南の帯を指す
img, _ = text(img, cx - 170, cy + 40, [("チリ", WHITE)], 120, anchor="rs")
d = ImageDraw.Draw(img)
d.line([(cx - 160, cy + 2), (cx - 14, cy - 4)], fill=INK, width=16)
d.line([(cx - 160, cy + 2), (cx - 14, cy - 4)], fill=WHITE, width=8)
jx = sum(v.px(*p)[0] for p in jp[0]) / len(jp[0])
jtop = min(v.px(*p)[1] for r in jp for p in r)
jl, jb = v.px(J_LON - 6, J_LAT + 2)                       # 日本の形の左上の海
img, _ = text(img, jl, jb - 30, [("日本", WHITE)], 84, anchor="ms")
img, _ = text(img, jl, jb + 22, [("同じ縮尺", (225, 230, 245))], 40, anchor="ms", weight="Bold", stroke=4, shadow_px=4)

# -- 右の字 --
RX = 1840
img, box = tag(img, RX, 250, "広さは日本の2倍なのに", 70, RED)
f93, fkm, fw = font(330), font(170), font(200)
w_all = fw.getlength("幅") + 20 + f93.getlength("93") + fkm.getlength("km")
x0 = RX - w_all
img, xe = text(img, x0, 600, [("幅", WHITE)], 200, shadow_px=14)
img, xe = text(img, xe + 20, 600, [("93", YEL)], 330, shadow_px=16)
img, _ = text(img, xe, 600, [("km", YEL)], 170, shadow_px=12)
img, _ = text(img, RX, 880, [("なぜ", WHITE), ("細い", (255, 80, 70)), ("？", WHITE)], 190, anchor="rs", shadow_px=14)

# -- 「幅」の左からいちばん狭い所へ細い線(字と地図をつなぐ) --
nx, ny = v.px(*NARROW)
d = ImageDraw.Draw(img)
sx, sy = x0 - 14, 470
d.line([(sx, sy), (nx + 26, ny)], fill=INK, width=9)
d.line([(sx, sy), (nx + 26, ny)], fill=YEL, width=4)
d.ellipse([nx - 20, ny - 20, nx + 20, ny + 20], outline=INK, width=10)
d.ellipse([nx - 20, ny - 20, nx + 20, ny + 20], outline=YEL, width=5)

img.convert("RGB").resize((1280, 720), Image.LANCZOS).save(OUT / "thumb_long.jpg", quality=94)
img.convert("RGB").resize((320, 180), Image.LANCZOS).save(OUT / "thumb_long_small.jpg", quality=92)   # スマホの一覧の大きさで読めるか
print(OUT / "thumb_long.jpg")
