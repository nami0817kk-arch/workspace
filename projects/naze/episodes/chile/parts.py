"""チリはなぜ細長いのか: 本編 5 章とショート 5 本の台本と画面。ch1〜ch5・s1〜s5 の ep.py がここから読む。
台本は scripts.md(2版)。数字は sim/calc.py(結果 sim/calc.txt)、出典は scripts.md の頭。
画面は naze/shots.py のショートを 2〜3 行ごとに切り替える(地図だけで通すと一辺倒。2026-11-04 ユーザー指摘)。
場面の絵は make_illust.py(FLUX の無料枠)。画面の隅に「イメージ」。"""
from pathlib import Path

from scene import chile_rows

A = Path(__file__).resolve().parent / "assets"
CREDIT = "地図: NASA Blue Marble・Terrain Tiles・Natural Earth"
RED, YEL, WHITE, BLUE = (240, 90, 80), (255, 214, 64), (255, 255, 255), (120, 190, 255)
SAND = (236, 200, 120)

# 地点(経度, 緯度)
NORTH = (-69.51, -17.51)
SOUTH = (-67.62, -55.92)
SANTIAGO = (-70.65, -33.45)
NARROW = chile_rows([-31.55])[0]


def MAP(view, *layers, view_to=None, relief=None, panel=None, step=None, tr=None, inset=False, fx=None):
    s = dict(shot="map", view=view, layers=list(layers))
    if tr:
        s["tr"] = tr
    if inset:
        s["inset"] = True
    if fx:
        s["fx"] = fx
    if view_to:
        s["view_to"] = view_to
    if relief is not None:
        s["relief"] = relief
    if panel:
        s["panel"] = panel
    if step is not None:
        s["step"] = step
    return s


def FILL(code, color=RED, alpha=0.5, id=None, at=0.0, **kw):
    return dict(kind="fill", code=code, color=color, alpha=alpha, id=id or f"fill_{code}", at=at, **kw)


def LABEL(at_ll, text, size=56, color=WHITE, id=None, at=0.0, on=None, count=False):
    d = dict(kind="label", at_ll=at_ll, text=text, size=size, color=color, id=id or f"lab_{text}", at=at, count=count)
    if on:
        d["on"] = on
    return d


def CARD(big, sub=None, note=None, view=None, step=None, count=True, tr=None):
    d = dict(shot="card", big=big, sub=sub, note=note, view=view, step=step, count=count)
    if tr:
        d["tr"] = tr
    return d


def ILLUST(name, title=None, sub=None, pan=(0.0, 0.0, 0.06, 0.03), step=None, fx=None, grade=None, tr=None):
    d = dict(shot="illust", path=str(A / f"illust_{name}.jpg"), title=title, sub=sub, pan=pan, step=step)
    for k, v in (("fx", fx), ("grade", grade), ("tr", tr)):
        if v:
            d[k] = v
    return d


CHL = FILL("CHL", id="chl")
WIDE = (-64, -33, 62, 38)

P = {}

P["ch1"] = dict(title="第1章 地図で測る", cta=False, lines=[
    dict(id="c1", text="南アメリカの、左の端。",
         scene=dict(shot="globe", center=(-30, 5), to=(-66, -28), r=0.44, hl=None)),
    dict(id="c2", text="海と山にはさまれた、細い帯があります。",
         scene=dict(shot="globe", center=(-66, -28), to=(-70, -32), r=0.50, hl="CHL")),
    dict(id="c3", text="これが、チリという国です。",
         scene=MAP(WIDE, CHL, LABEL((-80.5, -30), "チリ", 80, RED, on="チリ"), step=0, tr="zoom")),
    dict(id="c4", text="広さは、日本のおよそ2倍。",
         scene=CARD("日本の約2倍", sub="チリの広さ", note="75.6万km²", view=WIDE, step=0, count=False)),
    dict(id="c5", text="それなのに、幅は、いちばん狭い所で93km。",
         scene=MAP((-70.6, -31.4, 8, 48), FILL("CHL", id="chl", alpha=0.35),
                   dict(kind="hlines", rows=[NARROW], id="narrow", at=0.35, grow=0.3),
                   LABEL((-71.1, -31.1), "93km", 84, YEL, on="93km", count=True), relief=0.09, step=0, inset=True)),
    dict(id="c6", text="東京駅から宇都宮駅までと、ほぼ同じです。",
         scene=CARD("98km", sub="東京駅 → 宇都宮駅", note="チリのいちばん狭い所とほぼ同じ", step=0, tr="whip")),
    dict(id="c7", text="すぐ東には、日本の7倍もある国、アルゼンチン。",
         scene=MAP((-63, -36, 58, 30), CHL, FILL("ARG", color=SAND, alpha=0.35, id="arg", on="アルゼンチン", wipe="east"),
                   LABEL((-65, -38), "アルゼンチン", 64, SAND, on="アルゼンチン"), LABEL((-65, -42), "日本の7倍", 48, WHITE, on="7倍"), step=0)),
    dict(id="c8", text="北には、ペルーとボリビア。",
         scene=MAP((-66, -22, 50, 30), CHL, FILL("ARG", color=SAND, alpha=0.35, id="arg"),
                   FILL("PER", color=SAND, alpha=0.30, id="per", on="ペルー"), FILL("BOL", color=SAND, alpha=0.30, id="bol", on="ボリビア"),
                   LABEL((-74, -10), "ペルー", 56, SAND, on="ペルー"), LABEL((-64.5, -17), "ボリビア", 56, SAND, on="ボリビア"), step=0)),
    dict(id="c9", text="隣の国々は、なぜこの細い帯を残したのか。", style="question", sub="隣の国々は、なぜ\nこの【細い帯】を残したのか",
         scene=dict(shot="globe", center=(-70, -30), to=(-68, -33), r=0.62, hl="CHL", dx=0.18)),
    dict(id="c10", text="理由は4つ。2つは地面が決め、2つは人が線を引きました。",
         scene=CARD("理由は4つ", note="地面が2つ・人の線が2つ", view=WIDE, step=0, count=False, tr="flash")),
    dict(id="c11", text="国境のデータで、自分で測って確かめます。",
         scene=MAP((-64, -35, 70, 0), CHL, dict(kind="border", a="CHL", b="ARG", color=WHITE, width=4, id="b_arg", grow=0.8),
                   LABEL((-50, -30), "Natural Earth の国境", 44, WHITE, at=0.3), step=0)),
    dict(id="c12", text="まず、長さ。", section=True,
         scene=MAP((-66, -37, 74, 0), CHL, step=0)),
    dict(id="c13", text="北の端から南の端まで、4,274km。",
         scene=MAP((-66, -37, 74, 0), CHL, dict(kind="line", pts=[NORTH, SOUTH], color=YEL, width=6, id="len", grow=0.6),
                   LABEL((-60.5, -36), "4,274km", 80, YEL, on="4,274km", count=True), step=0)),
    dict(id="c14", text="日本を、同じ大きさで横に並べます。",
         scene=MAP((-60, -37, 74, 0), CHL, dict(kind="line", pts=[NORTH, SOUTH], color=YEL, width=6, id="len"),
                   dict(kind="ghost", code="JPN", at_ll=(-46, -36), id="jpn", on="日本"), LABEL((-33, -33), "日本（同じ縮尺）", 48, WHITE, at=0.4), step=0)),
    dict(id="c15", text="宗谷岬から波照間島までの、1.5倍。",
         scene=CARD("1.5倍", sub="チリの長さ ÷ 宗谷岬〜波照間島（2,892km）", note="4,274km", view=(-60, -37, 74, 0), step=0)),
    dict(id="c16", text="次に、幅。北から南まで、輪切りにして測りました。",
         scene=MAP((-70, -30, 16, 40), FILL("CHL", id="chl", alpha=0.35),
                   dict(kind="hlines", rows=chile_rows([-18.5 - 0.5 * i for i in range(46)]), id="scan", grow=0.9),
                   LABEL((-64, -30), "平均186km", 64, YEL, at=0.75, count=True), view_to=(-71, -36, 16, 40), step=0, inset=True)),
    dict(id="c17", text="細い所は、南緯31度あたり。93kmです。",
         scene=MAP((-70.6, -31.4, 8, 48), FILL("CHL", id="chl", alpha=0.35), dict(kind="hlines", rows=[NARROW], id="narrow"),
                   LABEL((-71.1, -31.1), "93km", 84, YEL), dict(kind="latline", lat=-31.55, id="lat31", at=0.2),
                   LABEL((-73.4, -31.9), "南緯31度", 44, WHITE, at=0.3), relief=0.09, step=0)),
    dict(id="c18", text="この細い帯の、東の縁を見てください。",
         scene=MAP((-69.4, -24, 9.5, 66), view_to=(-69.8, -29, 9.5, 66), relief=0.12, step=0)),
    dict(id="c19", text="北の半分には、6,000mを超える峰が並びます。",
         scene=dict(shot="block", view=(-70.2, -25.2, 14, 60), lat=-27.11, lon=(-74.2, -66.2), step=0, tr="zoom",
                    labels=[(-68.54, 7600, "約6,900m"), (-73.2, 1200, "太平洋")])),
    dict(id="c20", text="アンデス山脈です。",
         scene=ILLUST("pass2", title="アンデス山脈", pan=(-0.02, 0.0, 0.04, 0.02), step=0, fx="snow", tr="whip")),
    dict(id="c21", text="この白い線が、最後に、答えの1つめになります。",
         scene=MAP((-68, -34, 42, 50), CHL, dict(kind="border", a="CHL", b="ARG", color=WHITE, width=6, glow=True, id="ridge", grow=0.7),
                   dict(kind="border", a="CHL", b="BOL", color=WHITE, width=6, glow=True, id="ridge2", grow=0.7), step=0)),
])


YOMI = [("〜", "から"), ("4,274km", "よんせんにひゃくななじゅうよんキロ"), ("93km", "きゅうじゅうさんキロ"),
        ("6,000m", "ろくせんメートル"), ("1.5倍", "いってんごばい"), ("南緯", "なんい"),
        ("日本", "にほん"), ("縁", "ふち")]


def yomi(text):
    s = text
    for a, b in YOMI:
        s = s.replace(a, b)
    return s


def ep_for(name: str) -> dict:
    p = dict(P[name])
    res = []
    for l in p["lines"]:
        if "say" not in l:
            y = yomi(l["text"])
            if y != l["text"]:
                l = dict(l, say=y)
        res.append(l)
    p["lines"] = res
    return dict(kind="sim", aspect="portrait" if name.startswith("s") else "landscape", credit=CREDIT, **p)
