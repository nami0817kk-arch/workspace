"""進撃の巨人の本編のサムネイル(1280×720)。作品の絵は使わない。下地は Gemini で作った絵(assets/thumb_gemini.jpg: 高い石の壁の上から、
湯気をまとった巨人の影が頭と肩を出す。作品のデザインには似せていない)。
クリックしたくなる形(2026-10-29 ユーザー指示「もう少しこだわって」): 字は少なく、驚きを 1 つだけ特大で、続きが気になる一言を添える。
箱や番号は付けず、字を直接のせる。python episodes/shingeki/thumb.py [案] で out/shingeki/thumb_long[_案].jpg"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from PIL import Image, ImageDraw, ImageEnhance  # noqa: E402

from naze import overlay as O  # noqa: E402

HERE = Path(__file__).resolve().parent
OUT = HERE.parents[1] / "out" / "shingeki"
OUT.mkdir(parents=True, exist_ok=True)
W, H = 2560, 1440
INK, RED, YEL, WHITE, BLACK = (20, 30, 60), (230, 30, 30), (255, 215, 0), (255, 255, 255), (10, 10, 20)
v = sys.argv[1] if len(sys.argv) > 1 else "A"

# 下地: 巨人が大きく見えるよう右上に寄せて拡大し、色を少し濃く
src = Image.open(HERE / "assets" / "thumb_gemini.jpg").convert("RGB")
zoom = 1.22
s = max(W / src.width, H / src.height) * zoom
src = src.resize((int(src.width * s + 1), int(src.height * s + 1)), Image.LANCZOS)
src = src.crop((src.width - W, int(src.height * 0.02), src.width, int(src.height * 0.02) + H))
src = ImageEnhance.Color(src).enhance(1.25)
src = ImageEnhance.Contrast(src).enhance(1.12)
img = src.convert("RGBA")

# 字の後ろ(左)を少し白く
sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
ds = ImageDraw.Draw(sh)
for x in range(0, 1300, 4):
    ds.rectangle([x, 0, x + 4, H], fill=(255, 255, 255, int(120 * max(0.0, 1 - x / 1300))))
img.alpha_composite(sh)
d = ImageDraw.Draw(img)


def big(xy, parts, size, anchor="la", inner=WHITE, outer=BLACK, w1=None, w2=None):
    """二重の縁取りの字(外の縁 outer、内の縁 inner)。parts は (字, 色) の並び"""
    f = O.font(size)
    w1 = w1 or max(10, size // 7)
    w2 = w2 or max(18, size // 4)
    x, y = xy
    if anchor == "ma":
        x -= sum(f.getlength(t) for t, _ in parts) / 2
    for t, col in parts:
        d.text((x, y), t, font=f, fill=col, stroke_width=w2, stroke_fill=outer)
        d.text((x, y), t, font=f, fill=col, stroke_width=w1, stroke_fill=inner)
        x += f.getlength(t)


def tag(xy, s, size, fg, bg, anchor="mm"):
    f = O.font(size)
    x0, y0, x1, y1 = d.textbbox(xy, s, font=f, anchor=anchor)
    p = size * 0.22
    d.rounded_rectangle([x0 - p, y0 - p, x1 + p, y1 + p], radius=int(p), fill=bg)
    d.text(xy, s, font=f, fill=fg, anchor=anchor)
    return x1 + p


def head():
    """左上の小さな前置き: 【進撃の巨人】の超大型巨人を／人の体で作ったら"""
    x = tag((70, 150), "進撃の巨人", 96, WHITE, (190, 30, 30), "lm")
    big((x + 25, 92), [("の超大型巨人を", INK)], 92, w1=10, w2=16, outer=WHITE, inner=WHITE)
    big((70, 230), [("人の体で作ったら", INK)], 120, w1=12, w2=20, outer=WHITE, inner=WHITE)


tag((W - 210, 110), "60m", 110, INK, YEL)

if v == "A":
    # 疑問で引く: 歩いたら骨折 → じゃあ鉄の骨なら？
    head()
    big((70, 470), [("歩いたら", WHITE)], 250, inner=BLACK, outer=WHITE, w1=14, w2=30)
    big((70, 760), [("骨折", RED)], 400, inner=WHITE, outer=BLACK)
    big((80, 1230), [("じゃあ ", WHITE), ("鉄の骨", YEL), ("なら…？", WHITE)], 120, inner=BLACK, outer=BLACK, w1=12, w2=14)
elif v == "B":
    # 数字で引く: 一歩ごとに骨が折れる / 骨の負担 1.7倍
    head()
    big((70, 470), [("一歩ごとに", INK)], 190, outer=WHITE, inner=WHITE, w1=16, w2=26)
    big((70, 720), [("骨が", INK), ("折れる", RED)], 260, outer=WHITE, inner=WHITE, w1=18, w2=34)
    d.rounded_rectangle([70, 1080, 1250, 1330], radius=40, fill=(190, 30, 30))
    big((660, 1105), [("骨の負担 ", WHITE), ("1.7倍", YEL)], 150, anchor="ma", inner=(150, 20, 20), outer=(150, 20, 20), w1=6, w2=8)
elif v == "C":
    # 答えで引く: 歩ける巨人は発泡スチロール並みに軽い!?
    head()
    big((70, 470), [("歩ける巨人は", INK)], 190, outer=WHITE, inner=WHITE, w1=16, w2=26)
    big((70, 720), [("発泡スチロール", RED)], 230, outer=WHITE, inner=WHITE, w1=18, w2=34)
    big((70, 1020), [("並みに", INK), ("軽い", RED), ("!?", INK)], 200, outer=WHITE, inner=WHITE, w1=16, w2=30)

name = "thumb_long.jpg" if v == "A" else f"thumb_long_{v}.jpg"
img.convert("RGB").resize((1280, 720), Image.LANCZOS).save(OUT / name, quality=93)
print(OUT / name)
