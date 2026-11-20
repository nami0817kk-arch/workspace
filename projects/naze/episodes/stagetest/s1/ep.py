"""試し: 画面の作り(naze/stage.py)で作るショート。ナミブ砂漠「海のそばなのに、なぜ砂漠？」(投稿しない。2026-11-20)

出どころ(試しなので確かめは途中):
  東京の年間降水量 1,598.2mm(気象庁 平年値 1991〜2020)→ 約1,600ミリ
  ナミブ砂漠の海岸の町(ワルビスベイ・スワコプムント)の年間降水量は 20mm に届かない(要確認: 一次資料)
  ナミブ砂漠は大西洋岸に沿って約2,000km(アンゴラ南部〜ナミビア〜南アフリカ北西部)
  ベンゲラ海流: 沖を北へ流れる冷たい海流。海面近くの空気が冷やされ、上の暖かい空気との間に逆転層ができて雨雲が育たず、霧になる
"""
import math

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from naze import stage as sg
from naze import worldmap

W, H = sg.W, sg.H
MAPSPEC = dict(lat0=-23, bases=[((-2, -40, 36, -6), 5), ((8, -33, 20, -13), 7)])


def coast():
    pts = [p for c in ("AGO", "NAM", "ZAF") for poly in worldmap.shapes(c) for p in poly if p[0] < 19 and -31.5 < p[1] < -15.0]
    best = {}
    for lon, lat in pts:
        b = round(lat * 4) / 4
        if b not in best or lon < best[b]:
            best[b] = lon
    out = [(best[b] - 0.25, b) for b in sorted(best, reverse=True)]
    return [out[0]] + [((a[0] + b[0] + c[0]) / 3, b[1]) for a, b, c in zip(out, out[1:], out[2:])] + [out[-1]]


def air():
    """海から陸へ向かう空気の流れ(弓なり)。"""
    a, b = (9.5, -24.6), (15.4, -23.2)
    return [(a[0] + (b[0] - a[0]) * s, a[1] + (b[1] - a[1]) * s + math.sin(math.pi * s) * 0.9) for s in [i / 30 for i in range(31)]]


EP = dict(
    kind="stage",
    map=MAPSPEC,
    title="海のそばなのに、なぜ砂漠？",
    qtag="海のそばなのに、なぜ砂漠？",
    colors={"東京": (90, 170, 255), "海辺の町": (255, 170, 90)},
    lines=[
        dict(id="a1", open="scene", text="アフリカの南西に、海に沿って【約2,000km】続く砂漠があります。",
             say="アフリカのなんせいに、うみにそって、やくにせんキロメートルつづく、さばくがあります。",
             scene=dict(kind="map", view=(16.5, -21.0, 16, 10), to=(14.2, -23.0, 8.5, 30), place=("ナミブ砂漠", "アフリカ南西部の海岸")),
             fx=[dict(k="route", pts=coast(), dur=2.6, label="約2,000km", label_xy=(W * 0.42, H * 0.42))]),
        dict(id="a2", text="砂の山は、人が豆粒に見えるほど大きい。",
             scene=dict(kind="video", src="assets/stock/person.mp4", start=2.0),
             fx=[dict(k="person", text="人", on="人が")]),
        dict(id="a3", text="ところが、そのすぐ隣は【海】です。",
             scene=dict(kind="video", src="assets/stock/sea.mp4", start=2.0)),
        dict(id="a4", text="すぐ隣に海があるのに、雨がほとんど降らないのです。",
             scene=dict(kind="words", rows=["すぐ隣に、海。", "【なのに、雨が降らない。】"], rows_on=[None, "雨が"])),
        dict(id="a5", text="1年の雨は、東京なら約1,600ミリ。", say="いちねんのあめは、とうきょうなら、やくせんろっぴゃくミリ。",
             scene=dict(kind="bars", items=[dict(name="東京", value=1600, unit="ミリ")])),
        dict(id="a6", text="海辺の町は、【20ミリ】にも届きません。", say="うみべのまちは、にじゅうミリにも、とどきません。",
             fx=[dict(k="add", item=dict(name="海辺の町", value=20, unit="ミリ"), on="20ミリ")]),
        dict(id="a7", text="東京の【80分の1】より少ないのです。", say="とうきょうの、はちじゅうぶんのいちより、すくないのです。",
             fx=[dict(k="add", ratio=dict(text="80分の1", sub="より少ない"))]),
        dict(id="a8", text="目の前の海から、なぜ雨雲が育たないのか。", pause=0.6,
             scene=dict(kind="map", view=(13.4, -23.4, 9, 40), to=(13.8, -23.3, 8, 40), place=("大西洋", "ナミブ砂漠の沖")),
             fx=[dict(k="route", pts=air(), dur=1.6, color=(150, 210, 255), w=7, arrow=True),
                 dict(k="q", ll=(15.6, -21.9), label="雨雲", on="雨雲")]),
        dict(id="a9", text="手がかりは、2つあります。", say="てがかりは、ふたつあります。",
             scene=dict(kind="boxes", n=2)),
        dict(id="a10", text="1つ目は、この砂漠をおおう【霧】。", say="ひとつめは、このさばくをおおう、きり。",
             fx=[dict(k="fill", i=0, src="assets/stock/fog.jpg", label="霧", on="この砂漠"), dict(k="expand", i=0, on="霧")]),
        dict(id="a11", text="霧は来るのに、雨にはならない。",
             scene=dict(kind="photo", src="assets/stock/fog.jpg", move="in"),
             fx=[dict(k="dim", on="雨には")]),
        dict(id="a12", text="2つ目は、沖を流れる【冷たい海流】です。", say="ふたつめは、おきをながれる、つめたいかいりゅうです。",
             scene=dict(kind="custom", fn="cross", credit="映像: Davis Arenas / Pexels", place=("ベンゲラ海流", "アフリカ南西の沖を北へ")),
             fx=[dict(k="step", n=1, on="冷たい")]),
        dict(id="a13", text="冷たい海は、すぐ上の空気を冷やします。",
             fx=[dict(k="step", n=2, on="空気")]),
        dict(id="a14", text="冷えた空気は重く、上の暖かい空気を突き抜けられません。", say="ひえたくうきはおもく、うえのあたたかいくうきを、つきぬけられません。",
             fx=[dict(k="step", n=3, on="突き抜け")]),
        dict(id="a15", answer=True, text="だから雨雲は育たず、霧で止まる。この砂漠は、冷たい海が作っていたのです。",
             say="だから、あまぐもはそだたず、きりでとまる。このさばくは、つめたいうみが、つくっていたのです。",
             fx=[dict(k="step", n=4, on="霧で")]),
        dict(id="a16", text="次に海辺で霧を見たら、その沖の水の冷たさを思い出してください。",
             scene=dict(kind="video", src="assets/stock/dunes.mp4", start=1.0)),
    ],
)


CROSS_SRC, CROSS_CX = "assets/stock/coastdune.mp4", 0.75


def horizon(f: np.ndarray) -> int:
    """空と海の境。右寄りの列の明るさが、空(上の方)より 25 落ちた最初の行。
    いちばん大きく落ちる行を取ると、手前の波打ちぎわを拾った(2026-11-20)。"""
    g = f[:, int(W * 0.55):, :].astype(np.float32).mean(axis=(1, 2))
    sky = g[int(H * 0.22)]
    below = np.nonzero(g[int(H * 0.28):int(H * 0.55)] < sky - 25)[0]
    return int(H * 0.28) + (int(below[0]) if len(below) else int(H * 0.1))


def draw_cross(img: Image.Image, t: float, c) -> None:
    """砂丘が海に落ちる実写に重ねる。step 1=海が冷たい(海だけ青く光る) 2=海の上に冷たい空気の層 3=上がる空気が境で止まる 4=霧が陸へ流れる。
    海は描かない(2026-11-20「海が作り物感すごい」)。重ねるのは空気・矢印・霧の透ける層と札だけ。"""
    steps = {f["n"]: c.when(f) for f in c.seg["fx"] if f["k"] == "step"}

    def k(n, d=0.6):
        return sg.ease((t - steps.get(n, 1e9)) / d)
    f = c.st.media.frame(CROSS_SRC, 0.3 + t, CROSS_CX)
    hz = c.st.cache_get(("hz", round(t * 2)), lambda: horizon(f))
    base = sg.grade(f)
    k1 = k(1, 0.8)
    if k1 > 0:   # 海だけを冷たい色に: 元の絵で青みが砂より強く、影ほど暗くない所(影は色を整えると青くなるので元の絵で見る)
        b = f.astype(np.int16)
        lum = b.mean(axis=2)
        m = np.clip((b[..., 2] - b[..., 0]) / 20.0, 0, 1) * np.clip((lum - 90) / 20.0, 0, 1)
        m[:hz] = 0
        m[hz + int(H * 0.25):] = 0
        m = cv2.GaussianBlur(m.astype(np.float32), (0, 0), 3)[..., None] * k1 * (0.28 + 0.05 * math.sin(t * 3))   # 強いと塗った青に見える(0.55 で作り物に戻った)
        base = (base * (1 - m) + np.array([40, 110, 210]) * m).astype(np.uint8)
    im = Image.fromarray(base).convert("RGBA")
    lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay, "RGBA")
    inv = hz - int(H * 0.09)                                         # 冷たい空気の層の上の境
    for y in range(inv - 300, inv + 40):                             # 上は暖かい空気(うすい橙。上下ともぼかして境を作らない)
        d.line([(0, y), (W, y)], fill=(255, 150, 70, int(45 * max(0.0, 1 - abs(y - inv + 130) / 170))))
    k2 = k(2)
    if k2 > 0:
        for y in range(inv, hz + 2):
            d.line([(0, y), (W, y)], fill=(90, 170, 255, int(85 * k2)))
        for x0 in range(0, W, 30):
            d.line([(x0, inv), (x0 + 16, inv)], fill=(255, 255, 255, int(200 * k2)), width=3)
    k4 = k(4, 1.0)
    if k4 > 0:   # 霧: 層の中を海から陸(左)へ流れる
        fl = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        fd = ImageDraw.Draw(fl)
        for j in range(9):
            x = W + 200 - ((j * 230 + (t - steps[4]) * 150) % (W + 500))
            y = inv + 20 + (j * 37) % max(hz - inv + 40, 1)
            fd.ellipse([x - 220, y - 34, x + 220, y + 34], fill=(240, 244, 248, int(120 * k4)))
        lay.alpha_composite(fl.filter(ImageFilter.GaussianBlur(22)))
        d = ImageDraw.Draw(lay, "RGBA")
    im.alpha_composite(lay)
    d = ImageDraw.Draw(im, "RGBA")
    fL = sg.F("YuGothB.ttc", 44)
    sg.stext(d, (50, inv - 70), "暖かい空気", fL, (255, 205, 160), anchor="lm")
    if k2 > 0:
        sg.stext(d, (50, (inv + hz) // 2), "冷たい空気", fL, (185, 220, 255, int(255 * k2)), anchor="lm")
    sg.stext(d, (W - 50, hz + 90), "冷たい海", fL, (185, 220, 255), anchor="rm")
    sg.stext(d, (W - 50, hz + 430), "砂漠", fL, (255, 230, 200), anchor="rm")
    k3 = k(3, 1.4)
    if k3 > 0:
        x, y0 = W * 0.62, hz + 40
        y = y0 - (y0 - inv - 14) * k3
        d.line([(x, y0), (x, y)], fill=(220, 238, 255, 255), width=8)
        d.polygon([(x - 18, y + 4), (x + 18, y + 4), (x, y - 22)], fill=(220, 238, 255, 255))
        if k3 >= 1:
            sg.stext(d, (x + 70, inv - 60), "×", sg.F("meiryob.ttc", 110), sg.YEL, anchor="mm")
    if k4 > 0:
        sg.stext(d, (W * 0.40, (inv + hz) // 2 + 4), "霧", fL, sg.WHITE + (int(255 * k4),), anchor="mm")
    img.alpha_composite(im)
