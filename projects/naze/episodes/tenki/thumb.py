"""天気の子の本編のサムネイル(1280×720)。映画の絵は使わず、Gemini で作った「雨で沈んだ東京」の想像図に、
「天気の子」の字と計算の数字を重ねる。右下に標高データの立体(水位5.7m)を小窓で入れて、計算の回だと分かるようにする。
python episodes/tenki/thumb.py → out/tenki/thumb_long.jpg"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from PIL import Image, ImageDraw, ImageFilter  # noqa: E402

from naze import overlay as O  # noqa: E402

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = ROOT / "out" / "tenki"
OUT.mkdir(parents=True, exist_ok=True)
W, H = 2560, 1440
RAIN = (120, 200, 255)


def base(name, shade):
    img = Image.open(HERE / "assets" / name).convert("RGB").resize((W, H), Image.LANCZOS).convert("RGBA")
    sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(sh)
    for (x0, y0, x1, y1, a, axis) in shade:                   # 字の下だけ暗くする(端から薄く)
        for i in range(int((y1 - y0) if axis == "y" else (x1 - x0))):
            u = 1 - i / max(1, (y1 - y0) if axis == "y" else (x1 - x0))
            if axis == "y":
                d.line([(x0, y0 + i), (x1, y0 + i)], fill=O.NAVY + (int(a * u),))
            else:
                d.line([(x0 + i, y0), (x0 + i, y1)], fill=O.NAVY + (int(a * u),))
    img.alpha_composite(sh)
    return img


def rows(img, lines, x, y, size, gap=1.18, right=False, color=O.WHITE):
    d = ImageDraw.Draw(img)
    for i, row in enumerate(lines):
        parts = O.parse(row)
        sz = size[i] if isinstance(size, (list, tuple)) else size
        f = O.font(sz)
        tw = sum(f.getlength(t) for t, _ in parts)
        xx = x - tw if right else x
        yy = y + sum((size[j] if isinstance(size, (list, tuple)) else size) * gap for j in range(i))
        for t, hl in parts:
            d.text((xx, yy), t, font=f, fill=O.YEL if hl else color, stroke_width=max(10, sz // 9), stroke_fill=O.NAVY)
            xx += f.getlength(t)


def title_tag(img, x, y, size=120):
    """「天気の子」の札: 雨の色の帯に白抜きの字。"""
    f = O.font(size)
    t = "天気の子"
    w = f.getlength(t) + size * 0.9
    h = size * 1.45
    lay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ld = ImageDraw.Draw(lay)
    ld.rounded_rectangle([x, y, x + w, y + h], int(h * 0.22), fill=(30, 110, 200, 240), outline=(255, 255, 255, 255), width=8)
    img.alpha_composite(lay.filter(ImageFilter.GaussianBlur(0.6)))
    ImageDraw.Draw(img).text((x + w / 2, y + h / 2), t, font=f, fill=O.WHITE, anchor="mm")
    return x + w


def badge(img, x, y, top, big, col):
    f1, f2 = O.font(60), O.font(100)
    w = max(f1.getlength(top), f2.getlength(big)) + 110
    h = 300
    lay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(lay).rounded_rectangle([x - w, y, x, y + h], 30, fill=O.NAVY + (225,), outline=col + (255,), width=7)
    img.alpha_composite(lay)
    d = ImageDraw.Draw(img)
    d.text((x - w / 2, y + 85), top, font=f1, fill=O.WHITE, anchor="mm")
    d.text((x - w / 2, y + 198), big, font=f2, fill=col, anchor="mm")


def learn(img, x, y, items, col=RAIN, right=False):
    """「この動画でわかること」の札。items = [(前半, 強調)]。"""
    f0, f1 = O.font(50), O.font(62)
    lw = max(f1.getlength("・" + a + b) for a, b in items)
    w = max(lw, f0.getlength("この動画でわかること")) + 90
    h = 110 + len(items) * 92 + 20
    if right:
        x = x - w
    lay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ld = ImageDraw.Draw(lay)
    ld.rounded_rectangle([x, y, x + w, y + h], 28, fill=O.NAVY + (228,), outline=col + (255,), width=6)
    ld.rounded_rectangle([x, y, x + w, y + 92], 28, fill=col + (255,))
    ld.rectangle([x, y + 60, x + w, y + 92], fill=col + (255,))
    img.alpha_composite(lay)
    d = ImageDraw.Draw(img)
    d.text((x + w / 2, y + 47), "この動画でわかること", font=f0, fill=O.NAVY, anchor="mm")
    for i, (a, b) in enumerate(items):
        yy = y + 112 + i * 92
        d.text((x + 45, yy), "・" + a, font=f1, fill=O.WHITE)
        d.text((x + 45 + f1.getlength("・" + a), yy), b, font=f1, fill=O.YEL)


ITEMS = [("雨が流れないと1年で", "水位5.7m"), ("23区の約2割は", "海より低い"), ("東が低いのは", "埋め立てと沈下")]


def note(img, s, x, y):
    ImageDraw.Draw(img).text((x, y), s, font=O.font(42), fill=O.WHITE, stroke_width=6, stroke_fill=O.NAVY)


# ---- 東京タワーが水面から出ている想像図 + 標高データの小窓(2026-10-27 ユーザーが A の絵に B の字と図を選んだ) -----------------------------------------
b = base("flood_tower_gemini.jpg", [(0, 0, W, 720, 220, "y")])
bx = 80
x1 = title_tag(b, bx, 60, 118)
rows(b, ["の雨が"], x1 + 30, 70, 130)
rows(b, ["本当に降ったら", "東京は【どこまで沈む】"], bx, 290, [140, 150])
dem = Image.open(ROOT / "out" / "tenki_ch2" / "stills" / "s_2327.png").convert("RGB")
z = 1.5
cw, ch = dem.width / z, dem.height / z
cx, cy = dem.width * 0.40, dem.height * 0.60
dem = dem.crop((int(cx - cw / 2), int(cy - ch / 2), int(cx + cw / 2), int(cy + ch / 2))).resize((760, 428), Image.LANCZOS)
px, py = W - 80 - 760, H - 80 - 428
lay = Image.new("RGBA", b.size, (0, 0, 0, 0))
ImageDraw.Draw(lay).rounded_rectangle([px - 10, py - 10, px + 770, py + 438], 22, fill=(255, 255, 255, 255))
b.alpha_composite(lay)
b.paste(dem, (px, py))
d = ImageDraw.Draw(b)
d.rounded_rectangle([px, py, px + 470, py + 70], 0, fill=O.NAVY + (230,))
d.text((px + 20, py + 12), "標高データで計算", font=O.font(44), fill=RAIN)
note(b, "絵はAIの想像図", 84, 1370)
b.convert("RGB").resize((1280, 720), Image.LANCZOS).save(OUT / "thumb_long.jpg", quality=93)
print("ok")
