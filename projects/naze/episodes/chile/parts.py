"""チリはなぜ細長いのか: 本編 5 章とショート 5 本の台本と画面。ch1〜ch5・s1〜s5 の ep.py がここから読む。
台本は scripts.md(2版)。数字は sim/calc.py(結果 sim/calc.txt)、出典は scripts.md の頭。
画面は naze/shots.py のショートを 2〜3 行ごとに切り替える(地図だけで通すと一辺倒。2026-11-04 ユーザー指摘)。
場面の絵は make_illust.py(FLUX の無料枠)。画面の隅に「イメージ」。"""
from pathlib import Path

from scene import chile_rows, trench_line

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
                   LABEL((-73, -14.5), "ペルー", 56, SAND, on="ペルー"), LABEL((-64.5, -17), "ボリビア", 56, SAND, on="ボリビア"), step=0)),
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
                   LABEL((-64.5, -34.5), "平均186km", 64, YEL, at=0.75, count=True), view_to=(-71, -36, 16, 40), step=0, inset=True)),
    dict(id="c17", text="細い所は、南緯31度あたり。93kmです。",
         scene=MAP((-70.6, -31.4, 8, 48), FILL("CHL", id="chl", alpha=0.35), dict(kind="hlines", rows=[NARROW], id="narrow"),
                   LABEL((-71.1, -31.1), "93km", 84, YEL), dict(kind="latline", lat=-31.55, id="lat31", at=0.2),
                   LABEL((-73.4, -31.9), "南緯31度", 44, WHITE, at=0.3), relief=0.09, step=0)),
    dict(id="c18", text="この細い帯の、東の縁を見てください。",
         scene=MAP((-69.4, -24, 9.5, 66), view_to=(-69.8, -29, 9.5, 66), relief=0.12, step=0)),
    dict(id="c19", text="北の半分には、6,000mを超える峰が並びます。",
         scene=dict(shot="block", view=(-70.2, -24.4, 14, 60), lat=-27.11, lon=(-74.2, -66.2), step=0, tr="zoom",
                    labels=[(-68.54, 7600, "約6,900m"), (-73.2, 1200, "太平洋")])),
    dict(id="c20", text="アンデス山脈です。",
         scene=ILLUST("pass2", title="アンデス山脈", pan=(-0.02, 0.0, 0.04, 0.02), step=0, fx="snow", tr="whip")),
    dict(id="c21", text="この白い線が、最後に、答えの1つめになります。",
         scene=MAP((-68, -34, 42, 50), CHL, dict(kind="border", a="CHL", b="ARG", color=WHITE, width=6, glow=True, id="ridge", grow=0.7),
                   dict(kind="border", a="CHL", b="BOL", color=WHITE, width=6, glow=True, id="ridge2", grow=0.7), step=0)),
])


# ---- 2〜5章・ショートで使う部品 --------------------------------------------------------------

MENDOZA, SANJUAN, SANLUIS = (-68.83, -32.89), (-68.52, -31.54), (-66.34, -33.30)
BAIRES, LIMA = (-58.38, -34.60), (-77.04, -12.05)
CUYO = "ARG:Mendoza+ARG:San Juan+ARG:San Luis"
OJOS, RICHARDS = (-68.54, -27.11), (-71.35, -23.30)
ANTOF, ARICA, TACNA, TITICACA = (-70.40, -23.65), (-70.31, -18.48), (-70.25, -18.01), (-69.4, -15.8)
CONCEP, VALDIVIA = (-73.05, -36.83), (-73.24, -39.81)
PUNTA_ARENAS, BULNES, ANCUD = (-70.91, -53.16), (-70.93, -53.63), (-73.83, -41.87)
PATAGONIA_E = "ARG:Neuquén+ARG:Río Negro+ARG:Chubut+ARG:Santa Cruz"
BOL_COAST = "CHL:Antofagasta@-24,-21.4"                     # 1874〜1904 のボリビアの海岸(南緯24度からロア川まで)
TARAPACA = "CHL:Tarapacá"
ARICA_R = "CHL:Arica y Parinacota"
ARAUCANIA = "CHL:La Araucanía"
# 1960年の地震でずれた範囲(USGS: レブ〜プエルト・アイセン、約1,000km。沖の位置は読み)
RUPTURE = [(-73.9, -37.6), (-74.2, -39.5), (-74.4, -41.5), (-74.3, -43.3), (-73.6, -45.4)]
# アンクー号の道筋(チロエ島から外海を南へ、海峡へ。読み)
SHIP = [(-73.9, -41.9), (-75.2, -44.0), (-75.9, -47.0), (-75.7, -50.0), (-74.9, -52.4), (-73.6, -53.1), (-72.2, -53.7), (-70.95, -53.62)]
STRAIT = [(-68.4, -52.4), (-69.6, -52.6), (-70.5, -53.0), (-70.95, -53.6), (-71.6, -53.85), (-72.6, -53.5), (-73.6, -52.85), (-74.6, -52.6)]
# 湖の水が山を抜けて太平洋へ(ヘネラル・カレーラ湖からバケル川。読み)
BAKER = [(-71.2, -46.5), (-72.0, -46.6), (-72.8, -47.2), (-73.6, -47.8)]
SOUTH_ANDES = (-71.5, -46.5, 10, 55)
TRENCH = trench_line()
GREEN_ = (110, 220, 140)


def TL(items, cur, view=WIDE, step=None, tr=None):
    d = dict(shot="timeline", items=items, cur=cur, view=view, step=step)
    if tr:
        d["tr"] = tr
    return d


def ARROW(a, b, color=YEL, id=None, at=0.0, on=None, width=14):
    d = dict(kind="arrow", a=a, b=b, color=color, id=id or f"arr_{a}_{b}", at=at, width=width)
    if on:
        d["on"] = on
    return d


def LINE(pts, color=YEL, id="line", width=6, on=None, at=0.0, glow=False):
    d = dict(kind="line", pts=pts, color=color, id=id, width=width, at=at, glow=glow)
    if on:
        d["on"] = on
    return d


def ROUTE(pts, color=YEL, id="route", on=None, at=0.0, grow=0.8):
    d = dict(kind="route", pts=pts, color=color, id=id, at=at, grow=grow)
    if on:
        d["on"] = on
    return d


def PIN(at_ll, text, id=None, on=None, at=0.0):
    d = dict(kind="pin", at_ll=at_ll, text=text, id=id or f"pin_{text}", at=at)
    if on:
        d["on"] = on
    return d


ANSWERS = [("海の板がもぐり、アンデス山脈を押し上げた", "地面の力"), ("その峰の上に、国境が引かれた", "1776年・1881年"),
           ("北は、硝石の戦争で729km伸びた", "1879〜1929年"), ("南は、広い土地より海峡を選んだ", "1881年")]


def CARDS(n, still=False, groups=(), step=4):
    return dict(shot="cards", items=ANSWERS, n=n, still=still, groups=list(groups), view=WIDE, step=step)


TL4 = [(1874, "南緯24度の境"), (1879, "戦争が始まる"), (1883, "ペルーと講和"), (1904, "ボリビアと講和"), (1929, "アリカとタクナ")]

P["ch2"] = dict(title="第2章 山の峰が国境", cta=False, lines=[
    dict(id="c1", text="1541年。スペイン人が、ペルーから南へ来ました。",
         scene=MAP((-70, -24, 46, 30), ROUTE([LIMA, (-70.4, -18.5), (-70.3, -24.0), (-70.9, -29.0), SANTIAGO], id="conq", grow=0.9),
                   PIN(LIMA, "リマ", on="ペルー"), LABEL((-62, -26), "1541年", 80, YEL, on="1541年"), step=1, tr="zoom", inset=True)),
    dict(id="c2", text="山と海のあいだの谷に、町を作ります。サンティアゴです。",
         scene=ILLUST("valley2", title="1541年 サンティアゴ", grade="old", step=1, pan=(0.02, 0.0, -0.03, 0.02))),
    dict(id="c3", text="ところが、最初のチリは、山の向こうにもありました。",
         scene=MAP((-68.5, -33, 14, 45), FILL("CHL", id="chl", alpha=0.35), FILL(CUYO, color=RED, alpha=0.3, id="cuyo", on="山の向こう", wipe="east"),
                   relief=0.1, step=1, tr="whip")),
    dict(id="c4", text="1561年、チリの隊が山を越えて、町を作ります。",
         scene=MAP((-68.5, -33, 14, 45), FILL("CHL", id="chl", alpha=0.35), FILL(CUYO, color=RED, alpha=0.3, id="cuyo"),
                   ROUTE([SANTIAGO, (-70.0, -32.85), MENDOZA], id="cross", on="山を越えて"), PIN(MENDOZA, "メンドーサ", on="町を作ります"),
                   LABEL((-66.3, -31.6), "1561年", 72, YEL, on="1561年"), relief=0.1, step=1)),
    dict(id="c5", text="いまはアルゼンチンのワインの町、メンドーサです。",
         scene=ILLUST("vineyard2", title="メンドーサ", sub="いまはアルゼンチン", step=1, pan=(0.0, 0.02, 0.05, 0.0))),
    dict(id="c6", text="山の向こうの3つの町は、200年以上、チリでした。",
         scene=MAP((-68, -32.5, 16, 40), FILL("CHL", id="chl", alpha=0.35), FILL(CUYO, color=RED, alpha=0.3, id="cuyo"),
                   PIN(MENDOZA, "メンドーサ", id="p_men"), PIN(SANJUAN, "サンフアン", id="p_sj", on="3つの町"), PIN(SANLUIS, "サンルイス", id="p_sl", on="3つの町"),
                   LABEL((-64.8, -30.0), "200年以上", 70, YEL, on="200年以上", count=True), step=1, tr="zoom")),
    dict(id="c7", text="1776年。スペインの王が、線を引き直します。",
         scene=TL([(1541, "サンティアゴ"), (1561, "メンドーサ"), (1776, "線の引き直し"), (1881, "境界条約"), (1902, "裁定")], 2, view=(-66, -33, 40, 0), step=1, tr="flash")),
    dict(id="c8", text="ブエノスアイレスを中心に、新しい区切りを作りました。",
         scene=MAP((-63, -33, 26, 25), FILL("CHL", id="chl", alpha=0.35), FILL(CUYO, color=RED, alpha=0.3, id="cuyo"),
                   PIN(BAIRES, "ブエノスアイレス", on="ブエノスアイレス"), step=1)),
    dict(id="c9", text="山の東の3つの町は、そちらへ移されます。",
         scene=MAP((-63, -33, 26, 25), FILL("CHL", id="chl", alpha=0.35), FILL(CUYO, color=SAND, alpha=0.4, id="cuyo_b", on="そちら", wipe="east"),
                   PIN(BAIRES, "ブエノスアイレス", id="p_ba"), ARROW(MENDOZA, (-60.5, -34.2), id="move", on="移されます"), step=1)),
    dict(id="c10", text="残ったのは、冬には雪で閉ざされる峰。",
         scene=ILLUST("pass2", fx="snow", step=1, pan=(0.03, 0.0, -0.02, 0.03), tr="whip")),
    dict(id="c11", text="こうして、山の峰が、国の東の縁になります。",
         scene=MAP((-69, -33, 20, 55), CHL, dict(kind="border", a="CHL", b="ARG", color=WHITE, width=5, glow=True, id="ridge", grow=0.8),
                   view_to=(-69.5, -38, 20, 55), relief=0.1, step=1)),
    dict(id="c12", text="独立のあと、1881年。チリとアルゼンチンが、条約を結びます。",
         scene=CARD("1881年", sub="チリとアルゼンチンの境界条約", step=1, tr="flash", count=False)),
    dict(id="c13", text="国境は、最も高い峰で、水を分ける線。",
         scene=CARD("最も高い峰で、水を分ける線", sub="1881年 境界条約 第1条", step=1, count=False)),
    dict(id="c14", text="雨が西へ流れればチリ、東へ流れればアルゼンチン。",
         scene=MAP((-70, -33.5, 9, 50), FILL("CHL", id="chl", alpha=0.3), dict(kind="border", a="CHL", b="ARG", color=WHITE, width=5, glow=True, id="ridge"),
                   ARROW((-70.2, -33.0), (-71.6, -33.0), color=BLUE, id="w", on="西"), ARROW((-69.8, -33.6), (-68.4, -33.6), color=BLUE, id="e", on="東へ"),
                   LABEL((-71.9, -32.5), "チリ", 56, RED, on="チリ"), LABEL((-68.0, -34.2), "アルゼンチン", 56, SAND, on="アルゼンチン"), relief=0.12, step=1)),
    dict(id="c15", text="普通は、いちばん高い峰が、水も分けるはずです。",
         scene=dict(shot="block", view=(-70.3, -32.1, 11, 58), lat=-33.0, lon=(-73.5, -67.5), step=1, tr="zoom",
                    labels=[(-70.0, 6600, "峰＝水を分ける"), (-72.6, 900, "太平洋へ"), (-68.2, 2500, "大西洋へ")])),
    dict(id="c16", text="ところが南では、川が、山を突き抜けて流れていました。",
         scene=MAP(SOUTH_ANDES, FILL("CHL", id="chl", alpha=0.3), dict(kind="border", a="CHL", b="ARG", color=WHITE, width=4, id="ridge_s"),
                   ROUTE(BAKER, color=BLUE, id="baker", on="川"), LABEL((-70.3, -45.8), "湖の水は西へ", 50, BLUE, on="突き抜けて"), relief=0.13, step=1, inset=True)),
    dict(id="c17", text="高い峰の線と、水を分ける線が、ずれていたのです。",
         scene=MAP(SOUTH_ANDES, FILL("CHL", id="chl", alpha=0.3), ROUTE(BAKER, color=BLUE, id="baker"),
                   LINE([(-73.3, -44.0), (-73.0, -46.0), (-73.4, -48.5)], color=WHITE, id="peaks", on="高い峰の線", glow=True),
                   LINE([(-71.3, -44.0), (-71.0, -46.0), (-71.6, -48.5)], color=BLUE, id="divide", on="水を分ける線", glow=True),
                   LABEL((-74.6, -43.4), "高い峰の線", 44, WHITE, on="高い峰の線"), LABEL((-69.6, -43.4), "水を分ける線", 44, BLUE, on="水を分ける線"),
                   LABEL((-72.2, -49.4), "（線は図）", 32, WHITE, at=0.2), relief=0.13, step=1)),
    dict(id="c18", text="両国は譲らず、イギリスの王に決めてもらいます。",
         scene=CARD("1902年", sub="イギリス王の裁定", note="1898年に両国が任せた", step=1, count=False, tr="whip")),
    dict(id="c19", text="1902年。線は、2本のあいだに引かれました。",
         scene=MAP(SOUTH_ANDES, FILL("CHL", id="chl", alpha=0.3), LINE([(-73.3, -44.0), (-73.0, -46.0), (-73.4, -48.5)], color=WHITE, id="peaks"),
                   LINE([(-71.3, -44.0), (-71.0, -46.0), (-71.6, -48.5)], color=BLUE, id="divide"),
                   dict(kind="border", a="CHL", b="ARG", color=YEL, width=6, glow=True, id="award", on="2本のあいだ", grow=0.8),
                   LABEL((-75.0, -49.6), "いまの国境", 46, YEL, on="2本のあいだ"), relief=0.13, step=1)),
    dict(id="c20", text="東の壁は、こうして決まりました。",
         scene=MAP((-68, -35, 44, 45), CHL, dict(kind="border", a="CHL", b="ARG", color=WHITE, width=5, glow=True, id="ridge2", grow=0.7), step=1, tr="zoom")),
    dict(id="c21", text="西に目を移すと、沖には、山と同じくらい深い溝が走っています。",
         scene=MAP((-74, -30, 22, 40), FILL("CHL", id="chl", alpha=0.35), LINE(TRENCH, color=BLUE, id="trench", on="深い溝", glow=True),
                   view_to=(-75, -31, 18, 48), step=1)),
])

P["ch3"] = dict(title="第3章 山と海溝は同じ力で", cta=False, lines=[
    dict(id="c1", text="チリの西の海の底。",
         scene=MAP((-72.5, -25, 12, 62), view_to=(-72.5, -27, 11, 62), relief=0.1, step=2, tr="zoom")),
    dict(id="c2", text="岸のすぐ沖に、深い溝が走っています。",
         scene=MAP((-72.5, -25, 14, 50), LINE(TRENCH, color=BLUE, id="trench", on="深い溝", glow=True), relief=0.1, step=2, inset=True)),
    dict(id="c3", text="いちばん深い所は、8,065m。",
         scene=MAP((-71.0, -24.5, 9, 45), LINE(TRENCH, color=BLUE, id="trench", glow=True), PIN(RICHARDS, "リチャーズ海淵"),
                   LABEL((-73.0, -22.6), "8,065m", 84, BLUE, on="8,065m", count=True), relief=0.1, step=2)),
    dict(id="c4", text="一方、陸のいちばん高い峰は、およそ6,900m。",
         scene=MAP((-70.0, -25.6, 9, 45), LINE(TRENCH, color=BLUE, id="trench", glow=True), PIN(RICHARDS, "リチャーズ海淵", id="p_r"),
                   PIN(OJOS, "オホス・デル・サラード", on="陸"), LABEL((-67.6, -27.9), "約6,900m", 80, YEL, on="6,900m", count=True), relief=0.1, step=2)),
    dict(id="c5", text="2つのあいだは、509km。",
         scene=MAP((-70.0, -25.4, 9, 30), PIN(RICHARDS, "リチャーズ海淵", id="p_r"), PIN(OJOS, "オホス・デル・サラード", id="p_o"),
                   LINE([OJOS, RICHARDS], color=YEL, id="d509", width=5), LABEL((-69.2, -24.6), "509km", 80, YEL, on="509km", count=True), relief=0.1, step=2)),
    dict(id="c6", text="その間に、高さの差が、およそ1万5,000m。",
         scene=dict(shot="block", view=(-70.1, -22.3, 13, 58), lat=-25.2, lon=(-74.5, -66.5), step=2, tr="zoom",
                    labels=[(-68.6, 7800, "峰"), (-71.9, -9000, "海溝"), (-70.3, 9800, "差 約1万5,000m")])),
    dict(id="c7", text="富士山を、4つ積んだ段差です。",
         scene=CARD("富士山 4つ分", sub="1万4,958m ÷ 3,776m", step=2, tr="whip", count=False)),
    dict(id="c8", text="この段差を作ったのは、1つの力です。",
         scene=dict(shot="globe", center=(-90, -25), to=(-80, -28), r=0.62, hl=None, dx=0.05, step=2)),
    dict(id="c9", text="海の底の板が、南アメリカの下へ、もぐりこんでいる。",
         scene=MAP((-76, -28, 32, 30), ARROW((-90, -26), (-74, -26), color=BLUE, id="pl1", on="海の底の板", width=18),
                   ARROW((-90, -32), (-75, -32), color=BLUE, id="pl2", on="海の底の板", width=18), LABEL((-86, -23), "ナスカプレート", 56, BLUE, on="海の底の板"),
                   LINE(TRENCH, color=WHITE, id="trench_w", glow=True), step=2, inset=True)),
    dict(id="c10", text="速さは、1年に6.5cmから8cm。",
         scene=CARD("年 6.5〜8cm", sub="海の板がもぐりこむ速さ（USGS）", note="爪が伸びるより少し速い", step=2, count=False)),
    dict(id="c11", text="100万年なら、65kmから80km。",
         scene=CARD("65〜80km", sub="100万年で", step=2, count=False, tr="flash")),
    dict(id="c12", text="もぐりこむ所が、溝になる。",
         scene=dict(shot="block", view=(-70.1, -22.3, 13, 58), lat=-25.2, lon=(-74.5, -66.5), plate=True, trench=-71.6, step=2,
                    labels=[(-72.6, -6500, "沈む海の板")])),
    dict(id="c13", text="押された陸が、しわになって盛り上がる。"),
    dict(id="c14", text="それが、アンデス山脈です。",
         scene=MAP((-69.4, -24, 9.5, 66), view_to=(-69.8, -29, 9.5, 66), relief=0.12, step=2)),
    dict(id="c15", text="だから平らな土地は、そのあいだの細い帯だけ。",
         scene=MAP((-70.6, -31.4, 8, 48), FILL("CHL", id="chl", color=GREEN_, alpha=0.4, on="細い帯"), LINE(TRENCH, color=BLUE, id="trench", glow=True),
                   dict(kind="border", a="CHL", b="ARG", color=WHITE, width=5, glow=True, id="ridge"), relief=0.1, step=2)),
    dict(id="c16", text="この力は、地面も揺らします。",
         scene=ILLUST("araucaria_b1", step=2, pan=(0.0, 0.02, 0.04, 0.0), tr="whip")),
    dict(id="c17", text="1960年、チリで、記録に残る最大の地震が起きました。",
         scene=CARD("1960年", sub="チリ地震", note="記録に残る最大の地震（USGS）", step=2, count=False, tr="flash")),
    dict(id="c18", text="マグニチュード9.5。ずれた長さは、およそ1,000km。",
         scene=MAP((-72, -41.5, 16, 40), FILL("CHL", id="chl", alpha=0.3), LINE(RUPTURE, color=RED, id="rup", width=12, on="ずれた長さ", glow=True),
                   LABEL((-68.5, -39.5), "M9.5", 84, RED, on="9.5", count=True), LABEL((-68.6, -42.8), "約1,000km", 64, YEL, on="1,000km", count=True),
                   step=2, inset=True)),
    dict(id="c19", text="東京から博多までより、長い距離です。",
         scene=CARD("886km", sub="東京駅 → 博多駅", note="ずれた長さは、これより長い", step=2, tr="whip")),
    dict(id="c20", text="東は山、西は海。ここまでの2つは、地面が決めました。",
         scene=CARDS(1, still=True, step=2)),
    dict(id="c21", text="残る2つは、人の線。1つめは、砂漠の下の白い石から始まります。",
         scene=ILLUST("nitrate2", grade="old", fx="dust", step=2, pan=(0.0, 0.0, 0.05, 0.02))),
])

P["ch4"] = dict(title="第4章 北へ伸びた729km", cta=False, lines=[
    dict(id="c1", text="1874年。チリの北の端は、南緯24度でした。",
         scene=MAP((-68, -21, 22, 35), dict(kind="latline", lat=-24, id="lat24", at=0.3), LABEL((-74.5, -24.6), "南緯24度", 50, WHITE, on="南緯24度"),
                   FILL("CHL@-56,-24", id="chl_old", alpha=0.45), LABEL((-62.5, -20.5), "1874年", 80, YEL, on="1874年"),
                   step=3, tr="zoom", inset=True)),
    dict(id="c2", text="その北は、ボリビアとペルーの土地です。",
         scene=MAP((-68, -21, 22, 35), dict(kind="latline", lat=-24, id="lat24"), FILL("CHL@-56,-24", id="chl_old", alpha=0.45),
                   FILL(BOL_COAST, color=SAND, alpha=0.45, id="bolc", on="ボリビア"), FILL(TARAPACA + "+" + ARICA_R, color=(200, 160, 230), alpha=0.45, id="perc", on="ペルー"),
                   LABEL((-73.8, -22.6), "ボリビア", 48, SAND, on="ボリビア"), LABEL((-73.8, -19.4), "ペルー", 48, (200, 160, 230), on="ペルー"), step=3)),
    dict(id="c3", text="ここは、雨がほとんど降らない砂漠。アタカマ砂漠です。",
         scene=MAP((-69.6, -21.5, 9, 64), view_to=(-69.8, -24.5, 9, 64), relief=0.11, fx="dust", step=3)),
    dict(id="c4", text="何もない土地に見えて、地面の下に宝がありました。",
         scene=ILLUST("nitrate2", grade="old", fx="dust", step=3, pan=(0.04, 0.0, -0.02, 0.03), tr="whip")),
    dict(id="c5", text="硝石です。", scene=CARD("硝石", sub="アタカマ砂漠の地面の下", count=False, step=3)),
    dict(id="c6", text="畑の肥料にも、火薬にもなる石です。", scene=CARD("硝石", sub="アタカマ砂漠の地面の下", note="肥料にも、火薬にも", count=False, step=3)),
    dict(id="c7", text="掘っていた会社には、チリのお金が入っていました。",
         scene=ILLUST("nitrate1", grade="old", step=3, pan=(0.0, 0.03, 0.05, 0.0))),
    dict(id="c8", text="1879年2月。税の争いから、チリが港町を押さえます。",
         scene=MAP((-69.5, -23.3, 10, 40), FILL(BOL_COAST, color=SAND, alpha=0.45, id="bolc"), PIN(ANTOF, "アントファガスタ", on="港町"),
                   LABEL((-66.8, -22.4), "1879年", 80, YEL, on="1879年"), step=3, tr="zoom", inset=True)),
    dict(id="c9", text="太平洋戦争の始まりです。",
         scene=TL(TL4, 1, view=(-68, -21, 22, 0), step=3, tr="flash")),
    dict(id="c10", text="1883年。ペルーは、タラパカの地を手放します。",
         scene=MAP((-68, -21, 22, 35), dict(kind="latline", lat=-24, id="lat24"), FILL("CHL@-56,-24", id="chl_old", alpha=0.45),
                   FILL(BOL_COAST, color=SAND, alpha=0.45, id="bolc"), FILL(ARICA_R, color=(200, 160, 230), alpha=0.45, id="per_ar"),
                   FILL(TARAPACA, color=RED, alpha=0.5, id="tara", on="タラパカ", wipe="south"), LABEL((-73.8, -20.2), "タラパカ", 50, RED, on="タラパカ"),
                   step=3, tr="zoom")),
    dict(id="c11", text="1904年。ボリビアも、海岸をチリに渡しました。",
         scene=MAP((-68, -21, 22, 35), dict(kind="latline", lat=-24, id="lat24"), FILL("CHL@-56,-24", id="chl_old", alpha=0.45),
                   FILL(ARICA_R, color=(200, 160, 230), alpha=0.45, id="per_ar"), FILL(TARAPACA, color=RED, alpha=0.5, id="tara"),
                   FILL(BOL_COAST, color=RED, alpha=0.5, id="bolc_r", on="海岸", wipe="south"), LABEL((-73.8, -22.6), "1904年", 56, YEL, on="1904年"), step=3)),
    dict(id="c12", text="最後に1929年。アリカの町がチリに、タクナがペルーに決まります。",
         scene=MAP((-70, -18.6, 8.5, 35), FILL(ARICA_R, color=RED, alpha=0.5, id="ar_r", on="アリカの町"), FILL("PER:Tacna", color=(200, 160, 230), alpha=0.45, id="tac", on="タクナ"),
                   PIN(ARICA, "アリカ", on="アリカ"), PIN(TACNA, "タクナ", on="タクナ"), LABEL((-67.4, -17.2), "1929年", 72, YEL, on="1929年"), step=3, inset=True)),
    dict(id="c13", text="南緯24度から、いまの北の端まで、729km。",
         scene=dict(shot="split", step=3, tr="whip",
                    left=dict(view=(-69.5, -21, 26, 0), title="1874年", layers=[FILL("CHL@-56,-24", id="o", alpha=0.5),
                              FILL(BOL_COAST, color=SAND, alpha=0.45, id="b"), FILL(TARAPACA + "+" + ARICA_R, color=(200, 160, 230), alpha=0.45, id="p")]),
                    right=dict(view=(-69.5, -21, 26, 0), title="いま", layers=[FILL("CHL", id="c", alpha=0.5),
                               LINE([(-70.5, -24.0), NORTH], color=YEL, id="d729", width=6), LABEL((-66.5, -20.6), "729km", 64, YEL, on="729km", count=True)]))),
    dict(id="c14", text="東京から大阪までの、1.8倍です。",
         scene=CARD("1.8倍", sub="東京駅 → 大阪駅（403km）と比べて", note="729km", step=3)),
    dict(id="c15", text="幅は、山と海で決まったまま。長さだけが、北へ伸びたのです。",
         scene=MAP((-69.5, -26, 30, 40), CHL, LINE([(-70.5, -24.0), NORTH], color=YEL, id="d729", width=6),
                   ARROW((-66.5, -26), (-66.5, -18.5), color=YEL, id="up", on="北へ伸びた"), step=3, tr="zoom")),
    dict(id="c16", text="ところが、この宝は長く続きません。",
         scene=ILLUST("nitrate1", grade="old", fx="dust", step=3, pan=(0.05, 0.02, 0.0, 0.0), tr="whip")),
    dict(id="c17", text="第一次世界大戦のあと、工場で硝石が作れるようになりました。",
         scene=CARD("人工の硝石", sub="第一次世界大戦のあと", note="工場で作れるようになった", count=False, step=3, tr="flash")),
    dict(id="c18", text="戦争で取った砂漠の宝は、値打ちを失っていきます。",
         scene=ILLUST("nitrate2", grade="old", step=3, pan=(0.0, 0.0, 0.06, 0.03))),
    dict(id="c19", text="一方、海を失ったボリビアには、いまも海軍があります。",
         scene=MAP((-66, -17.5, 16, 30), FILL("BOL", color=SAND, alpha=0.45, id="bol", on="ボリビア"),
                   LABEL((-64.5, -17.5), "海のない国", 56, WHITE, on="海を失った"), step=3, tr="zoom", inset=True)),
    dict(id="c20", text="船を浮かべているのは、ペルーとの境のチチカカ湖。",
         scene=ILLUST("titicaca1", title="チチカカ湖", step=3, pan=(0.0, 0.0, 0.05, 0.02))),
    dict(id="c21", text="3月23日は「海の日」。いまも、海への道を求め続けています。",
         scene=CARD("3月23日", sub="ボリビアの「海の日」", count=False, step=3, tr="whip")),
    dict(id="c22", text="北は戦争で伸びました。そのころ南では、国の真ん中に、チリのものではない土地が残っていました。",
         scene=MAP((-71, -38.5, 20, 45), FILL("CHL", id="chl", alpha=0.4), FILL(ARAUCANIA, color=SAND, alpha=0.5, id="arau", on="チリのものではない"),
                   LABEL((-66.5, -38.6), "？", 120, YEL, on="チリのものではない"), step=3, tr="zoom")),
])

P["ch5"] = dict(title="第5章 南の取り引き、そして答え", cta=True, lines=[
    dict(id="c1", text="サンティアゴから、南へ433km。",
         scene=MAP((-71.5, -36, 14, 40), FILL("CHL", id="chl", alpha=0.35), PIN(SANTIAGO, "サンティアゴ"), ROUTE([SANTIAGO, CONCEP], id="s433", on="南へ"),
                   LABEL((-68.6, -35.3), "433km", 72, YEL, on="433km", count=True), step=4, tr="zoom", inset=True)),
    dict(id="c2", text="ビオビオ川の南は、長いあいだ、チリのものではありませんでした。",
         scene=MAP((-72, -38, 12, 45), FILL("CHL", id="chl", alpha=0.35), PIN(CONCEP, "ビオビオ川の河口", id="p_bb"),
                   FILL(ARAUCANIA, color=SAND, alpha=0.5, id="arau", on="ビオビオ川の南", wipe="south"), relief=0.1, step=4)),
    dict(id="c3", text="マプチェの人々が暮らす土地、アラウカニアです。",
         scene=ILLUST("araucaria_b1", title="アラウカニア", step=4, pan=(0.02, 0.0, -0.03, 0.02), tr="whip")),
    dict(id="c4", text="1860年。そこへ、フランスの弁護士が現れます。",
         scene=ILLUST("king1", title="1860年", grade="old", step=4, pan=(0.0, 0.02, 0.04, 0.0))),
    dict(id="c5", text="マプチェの長の一部の支えを得て、「アラウカニアとパタゴニアの王」を名乗りました。",
         scene=CARD("アラウカニアと\nパタゴニアの王", sub="フランスの弁護士が名乗った", count=False, step=4, tr="flash")),
    dict(id="c6", text="王はやがてチリに捕まり、国へ送り返されます。",
         scene=ILLUST("king1", grade="old", step=4, pan=(0.04, 0.0, 0.0, 0.03))),
    dict(id="c7", text="チリは1861年、南へ進む計画を立てました。",
         scene=TL([(1843, "海峡に旗"), (1860, "王を名乗る"), (1861, "南へ進む計画"), (1881, "境界条約"), (1883, "戦いが終わる")], 2, view=(-71, -40, 30, 0), step=4, tr="whip")),
    dict(id="c8", text="戦いは、1883年まで続きます。",
         scene=MAP((-72, -38, 12, 45), FILL("CHL", id="chl", alpha=0.35), FILL(ARAUCANIA, color=RED, alpha=0.5, id="arau_r", on="1883年", wipe="south"),
                   LABEL((-68.8, -37.0), "1883年", 72, YEL, on="1883年"), relief=0.1, step=4, tr="zoom")),
    dict(id="c9", text="真ん中の土地を取りこみ、国は1本につながりました。",
         scene=MAP((-68, -37, 50, 40), FILL("CHL", id="chl_all", alpha=0.5), step=4)),
    dict(id="c10", text="残るのは、南の果て。",
         scene=MAP((-71, -52.5, 16, 50), view_to=(-71, -53.2, 12, 55), relief=0.1, step=4, tr="zoom", inset=True)),
    dict(id="c11", text="大西洋と太平洋をつなぐ、細い水路があります。マゼラン海峡です。",
         scene=MAP((-71, -53.2, 12, 50), LINE(STRAIT, color=BLUE, id="strait", width=10, on="細い水路", glow=True),
                   LABEL((-75.8, -51.6), "太平洋", 50, WHITE, on="太平洋"), LABEL((-66.6, -51.8), "大西洋", 50, WHITE, on="大西洋"),
                   LABEL((-71.0, -55.2), "マゼラン海峡", 60, BLUE, on="マゼラン海峡"), relief=0.1, step=4)),
    dict(id="c12", text="1843年、チリの小さな帆船が、海峡に着いて領有を宣言しました。",
         scene=MAP((-73, -48, 16, 40), LINE(STRAIT, color=BLUE, id="strait", width=8), ROUTE(SHIP, id="ship", on="小さな帆船", grow=0.9),
                   PIN(ANCUD, "アンクー", on="小さな帆船"), PIN(BULNES, "ブルネス砦", on="海峡に着いて"), LABEL((-68.5, -46), "1843年", 72, YEL, on="1843年"),
                   step=4, tr="whip")),
    dict(id="c13", text="そして1881年。山の峰を国境にした、あの条約です。",
         scene=ILLUST("strait2", title="1881年", grade="old", step=4, pan=(0.0, 0.0, 0.05, 0.02))),
    dict(id="c14", text="同じ条約に、もう1つの取り引きがありました。",
         scene=CARD("もう1つの取り引き", sub="1881年 境界条約", count=False, step=4, tr="flash")),
    dict(id="c15", text="チリは、東のパタゴニアの広い土地を手放す。",
         scene=MAP((-67, -46, 30, 40), FILL("CHL", id="chl", alpha=0.4), FILL(PATAGONIA_E, color=SAND, alpha=0.5, id="pat", on="東のパタゴニア", wipe="east"),
                   LABEL((-66.5, -45.5), "手放す", 72, SAND, on="手放す"), step=4, tr="zoom")),
    dict(id="c16", text="代わりに、マゼラン海峡を取る。",
         scene=MAP((-67, -46, 30, 40), FILL("CHL", id="chl", alpha=0.4), FILL(PATAGONIA_E, color=SAND, alpha=0.5, id="pat"),
                   LINE(STRAIT, color=RED, id="strait_r", width=12, on="マゼラン海峡", glow=True), LABEL((-71.5, -55.5), "取る", 72, RED, on="取る"), step=4)),
    dict(id="c17", text="広さより、2つの海をつなぐ水路を選んだのです。",
         scene=ILLUST("strait2", step=4, pan=(0.05, 0.02, 0.0, 0.0), tr="whip")),
    dict(id="c18", text="もしパタゴニアを取っていたら、国の形は、まるで違っていました。",
         scene=MAP((-67, -46, 30, 40), FILL("CHL", id="chl", alpha=0.45), FILL(PATAGONIA_E, color=RED, alpha=0.35, id="pat_if", on="パタゴニア"),
                   LABEL((-63.5, -44.5), "もし…", 72, WHITE, on="もし"), step=4, tr="zoom")),
    dict(id="c19", text="では、答えを並べ直します。", section=True,
         scene=dict(shot="globe", center=(-70, -32), to=(-68, -36), r=0.62, hl="CHL", step=4, tr="flash")),
    dict(id="c20", text="1つめ。海の板がもぐりこみ、アンデス山脈を押し上げた。", scene=CARDS(1)),
    dict(id="c21", text="2つめ。その峰の上に、国境が引かれた。", scene=CARDS(2)),
    dict(id="c22", text="3つめ。北は、硝石の戦争で、729km伸びた。", scene=CARDS(3)),
    dict(id="c23", text="4つめ。南は、広い土地より、海峡を選んだ。", scene=CARDS(4)),
    dict(id="c24", text="幅を決めたのは、地面の力。長さを決めたのは、人の線。",
         scene=CARDS(4, still=True, groups=[(0, 1, "幅"), (2, 3, "長さ")])),
    dict(id="c25", text="長さ4,274km、いちばん狭い所で93km。",
         scene=MAP(WIDE, CHL, LABEL((-80.5, -30), "4,274km", 64, YEL, on="4,274km", count=True), LABEL((-80.5, -34), "93km", 64, YEL, on="93km", count=True),
                   step=4, tr="zoom")),
    dict(id="c26", text="次に世界地図を見たら、南アメリカの左の帯を見てください。", style="end",
         scene=dict(shot="globe", center=(-68, -30), to=(-50, -20), r=0.5, hl="CHL", step=4)),
    dict(id="c27", text="その東の縁の白い線は、いまも、海の板に押され続けています。",
         scene=MAP((-68, -34, 42, 50), CHL, dict(kind="border", a="CHL", b="ARG", color=WHITE, width=6, glow=True, id="ridge_end", grow=0.7),
                   ARROW((-86, -30), (-75, -30), color=BLUE, id="push", on="押され"), step=4)),
])


# ---- ショート(縦 1080×1920) -------------------------------------------------------------------
V_CHILE = (-70, -37, 26, 30)                 # 縦の画面にチリが丸ごと入る

P["s1"] = dict(title="チリの幅は、東京〜宇都宮", lines=[
    dict(id="c1", text="チリは、広さが日本のおよそ2倍。",
         scene=dict(shot="globe", center=(-50, -15), to=(-70, -32), r=0.42, hl="CHL")),
    dict(id="c2", text="それなのに、幅は、いちばん狭い所で93km。",
         scene=MAP((-70.8, -31.5, 4.2, 48), FILL("CHL", id="chl", alpha=0.35), dict(kind="hlines", rows=[NARROW], id="narrow", on="93km"),
                   LABEL((-71.0, -30.8), "93km", 96, YEL, on="93km", count=True), relief=0.1, tr="zoom")),
    dict(id="c3", text="東京駅から宇都宮駅までと、ほぼ同じです。",
         scene=CARD("98km", sub="東京駅 → 宇都宮駅", note="ほぼ同じ幅", tr="whip")),
    dict(id="c4", text="長さは、宗谷岬から波照間島までの1.5倍。",
         scene=MAP((-60, -38, 40, 0), CHL, dict(kind="ghost", code="JPN", at_ll=(-50, -36), id="jpn", on="宗谷岬"),
                   LABEL((-60, -16), "1.5倍", 110, YEL, on="1.5倍", count=True), tr="zoom")),
    dict(id="c5", text="なぜ、そんなに細いのか。", style="question", sub="なぜ、そんなに\n【細い】のか",
         scene=dict(shot="globe", center=(-70, -30), to=(-70, -34), r=0.46, hl="CHL")),
    dict(id="c6", text="答えは、東の山と、西の海溝です。",
         scene=MAP(V_CHILE, CHL, dict(kind="border", a="CHL", b="ARG", color=WHITE, width=6, glow=True, id="ridge", on="東の山"),
                   LINE(trench_line(-17.5, -45, 0.5), color=BLUE, id="trench", on="西の海溝", glow=True, width=7), tr="zoom")),
    dict(id="c7", text="東の縁には、アンデス山脈の峰が続きます。",
         scene=MAP((-69.6, -23, 7, 66), view_to=(-69.9, -30, 7, 66), relief=0.12)),
    dict(id="c8", text="国境は、この峰の上に引かれました。",
         scene=MAP((-70, -33.5, 7, 50), FILL("CHL", id="chl", alpha=0.3), dict(kind="border", a="CHL", b="ARG", color=WHITE, width=6, glow=True, id="r2", grow=0.8),
                   relief=0.12)),
    dict(id="c9", text="西は、岸のすぐ沖に、深さ8,000mを超える溝。",
         scene=dict(shot="block", view=(-70.4, -23.6, 9.5, 58), lat=-25.2, lon=(-73.6, -67.2), tr="zoom",
                    labels=[(-71.8, -9000, "深さ8,000m超")])),
    dict(id="c10", text="海の底の板が、陸の下へもぐりこんで、溝と山を同時に作っています。",
         scene=dict(shot="block", view=(-70.4, -23.6, 9.5, 58), lat=-25.2, lon=(-73.6, -67.2), plate=True, trench=-71.6,
                    labels=[(-71.8, -9000, "深さ8,000m超"), (-68.8, 7600, "山")])),
    dict(id="c11", text="山と溝のあいだの細い帯だけが、チリの土地なのです。",
         scene=MAP(V_CHILE, FILL("CHL", id="chl", alpha=0.55, on="細い帯"), tr="zoom")),
    dict(id="c12", text="世界地図でチリを見たら、東の縁の峰の線を見てください。", style="end",
         scene=MAP(V_CHILE, CHL, dict(kind="border", a="CHL", b="ARG", color=WHITE, width=6, glow=True, id="r3", grow=0.7))),
])

P["s2"] = dict(title="メンドーサは、昔チリだった", lines=[
    dict(id="c1", text="アルゼンチンのワインの町、メンドーサ。",
         scene=ILLUST("vineyard2", title="メンドーサ", sub="アルゼンチン", pan=(0.0, 0.0, 0.08, 0.02))),
    dict(id="c2", text="この町を作ったのは、チリから来た人たちです。",
         scene=MAP((-69.5, -33, 7, 45), FILL("CHL", id="chl", alpha=0.35), PIN(MENDOZA, "メンドーサ"), PIN(SANTIAGO, "サンティアゴ", on="チリ"), relief=0.1, tr="zoom")),
    dict(id="c3", text="1561年、チリの隊が、アンデス山脈を越えて作りました。",
         scene=MAP((-69.5, -33, 7, 45), FILL("CHL", id="chl", alpha=0.35), PIN(MENDOZA, "メンドーサ", id="pm"), PIN(SANTIAGO, "サンティアゴ", id="ps"),
                   ROUTE([SANTIAGO, (-70.0, -32.85), MENDOZA], id="cross", on="アンデス山脈を越えて"), LABEL((-69.3, -31.6), "1561年", 90, YEL, on="1561年"), relief=0.1)),
    dict(id="c4", text="それから200年以上、ここはチリでした。",
         scene=MAP((-68.5, -33, 12, 40), FILL("CHL", id="chl", alpha=0.35), FILL(CUYO, color=RED, alpha=0.35, id="cuyo", wipe="east"),
                   LABEL((-67, -36.8), "200年以上", 90, YEL, on="200年以上", count=True))),
    dict(id="c5", text="ではなぜ、いまはアルゼンチンなのか。", style="question", sub="ではなぜ、いまは\n【アルゼンチン】なのか",
         scene=ILLUST("vineyard2", pan=(0.08, 0.02, 0.02, 0.0), tr="whip")),
    dict(id="c6", text="答えは、1776年の線の引き直しです。",
         scene=CARD("1776年", sub="線の引き直し", count=False, tr="flash")),
    dict(id="c7", text="王が、ブエノスアイレスを中心に区切りを作り直します。",
         scene=MAP((-62.5, -33, 21, 25), FILL("CHL", id="chl", alpha=0.35), FILL(CUYO, color=RED, alpha=0.35, id="cuyo"),
                   PIN(BAIRES, "ブエノスアイレス", on="ブエノスアイレス"), tr="zoom")),
    dict(id="c8", text="山の東の町は、そちらへ移されます。",
         scene=MAP((-62.5, -33, 21, 25), FILL("CHL", id="chl", alpha=0.35), FILL(CUYO, color=SAND, alpha=0.45, id="cuyo_b", wipe="east", on="移されます"),
                   PIN(BAIRES, "ブエノスアイレス", id="pba"), ARROW(MENDOZA, (-60.5, -34.2), id="mv", on="移されます"))),
    dict(id="c9", text="残ったのは、冬には雪で閉ざされる峰。",
         scene=ILLUST("pass2", fx="snow", pan=(0.0, 0.0, 0.05, 0.02), tr="whip")),
    dict(id="c10", text="こうして、山の峰がチリの東の縁になりました。",
         scene=MAP((-69.8, -33, 8, 55), CHL, dict(kind="border", a="CHL", b="ARG", color=WHITE, width=6, glow=True, id="r", grow=0.8), relief=0.12, tr="zoom")),
    dict(id="c11", text="1881年、国境は「最も高い峰で、水を分ける線」に。",
         scene=CARD("最も高い峰で\n水を分ける線", sub="1881年 境界条約", count=False, tr="flash")),
    dict(id="c12", text="いまのチリが細長いのは、このときの線のためでもあります。",
         scene=MAP(V_CHILE, CHL, dict(kind="border", a="CHL", b="ARG", color=WHITE, width=6, glow=True, id="r4"), tr="zoom")),
    dict(id="c13", text="メンドーサのワインを見たら、元はチリの町だと思い出してください。", style="end",
         scene=ILLUST("vineyard2", pan=(0.02, 0.0, 0.06, 0.03))),
])

P["s3"] = dict(title="富士山4つ分の段差", lines=[
    dict(id="c1", text="チリでいちばん高い峰は、およそ6,900m。",
         scene=MAP((-69.2, -26.3, 5, 60), PIN(OJOS, "オホス・デル・サラード"), LABEL((-68.6, -25.2), "約6,900m", 96, YEL, on="6,900m", count=True), relief=0.13)),
    dict(id="c2", text="そこから西へ509km行くと、海の底は8,065m。",
         scene=MAP((-70.0, -25.3, 8, 30), PIN(OJOS, "オホス・デル・サラード", id="po"), PIN(RICHARDS, "リチャーズ海淵", on="海の底"),
                   ROUTE([OJOS, RICHARDS], id="go", on="西へ"), LABEL((-71.2, -21.6), "8,065m", 96, BLUE, on="8,065m", count=True), tr="zoom")),
    dict(id="c3", text="高さの差は、およそ1万5,000m。",
         scene=dict(shot="block", view=(-70.4, -23.4, 9.5, 58), lat=-25.2, lon=(-73.6, -67.2), tr="zoom",
                    labels=[(-68.8, 7600, "峰"), (-71.8, -9000, "海溝")])),
    dict(id="c4", text="富士山を、4つ積んだ段差です。", scene=CARD("富士山 4つ分", sub="1万4,958m ÷ 3,776m", count=False, tr="whip")),
    dict(id="c5", text="なぜ、こんな段差が隣りあっているのか。", style="question", sub="なぜ、こんな段差が\n【隣りあって】いるのか",
         scene=dict(shot="globe", center=(-85, -20), to=(-75, -26), r=0.46)),
    dict(id="c6", text="答えは、1つの力です。", scene=CARD("1つの力", count=False, tr="flash")),
    dict(id="c7", text="海の底の板が、南アメリカの下へもぐりこんでいる。",
         scene=MAP((-76, -27, 22, 30), ARROW((-88, -25), (-74.5, -25), color=BLUE, id="a1", on="海の底の板", width=18),
                   ARROW((-88, -30), (-75, -30), color=BLUE, id="a2", on="海の底の板", width=18), LINE(trench_line(-17.5, -40, 0.5), color=WHITE, id="tw", glow=True),
                   LABEL((-82, -21), "ナスカプレート", 60, BLUE, on="海の底の板"), tr="zoom")),
    dict(id="c8", text="速さは、1年に6.5cmから8cm。", scene=CARD("年 6.5〜8cm", sub="もぐりこむ速さ（USGS）", count=False, tr="whip")),
    dict(id="c9", text="もぐる所が溝になり、押された陸が山になる。",
         scene=dict(shot="block", view=(-70.4, -23.4, 9.5, 58), lat=-25.2, lon=(-73.6, -67.2), plate=True, trench=-71.6, tr="zoom",
                    labels=[(-71.8, -9000, "溝"), (-68.8, 7600, "山")])),
    dict(id="c10", text="100万年で、65kmから80km押しこまれます。", scene=CARD("65〜80km", sub="100万年で", count=False, tr="flash")),
    dict(id="c11", text="あいだに残ったのが、平らな細い帯。チリの国土です。",
         scene=MAP(V_CHILE, FILL("CHL", id="chl", alpha=0.55, on="細い帯"), LINE(trench_line(-17.5, -45, 0.5), color=BLUE, id="t3", glow=True), tr="zoom")),
    dict(id="c12", text="チリの地図では、沖の溝と陸の峰を、セットで見てください。", style="end",
         scene=MAP(V_CHILE, CHL, LINE(trench_line(-17.5, -45, 0.5), color=BLUE, id="t3", glow=True),
                   dict(kind="border", a="CHL", b="ARG", color=WHITE, width=6, glow=True, id="r", grow=0.7))),
])

P["s4"] = dict(title="海のないボリビアに、海軍がある", lines=[
    dict(id="c1", text="ボリビアは、海のない国です。",
         scene=MAP((-65, -17, 14, 30), FILL("BOL", color=SAND, alpha=0.5, id="bol", on="ボリビア"), LABEL((-64.5, -16.5), "ボリビア", 80, SAND, on="ボリビア"))),
    dict(id="c2", text="それなのに、いまも海軍があります。", scene=CARD("海軍", sub="海のないボリビアに", count=False, tr="flash")),
    dict(id="c3", text="船を浮かべているのは、ペルーとの境のチチカカ湖。",
         scene=ILLUST("titicaca1", title="チチカカ湖", pan=(0.0, 0.0, 0.08, 0.02), tr="whip")),
    dict(id="c4", text="ボリビアは、もともと海のある国でした。",
         scene=MAP((-68, -21, 12, 35), FILL("BOL", color=SAND, alpha=0.45, id="bol"), FILL(BOL_COAST, color=SAND, alpha=0.55, id="bolc", on="海のある国"),
                   LABEL((-66.0, -25.6), "1874年", 72, YEL, at=0.3), tr="zoom")),
    dict(id="c5", text="なぜ、海を失ったのか。", style="question", sub="なぜ、【海】を\n失ったのか",
         scene=ILLUST("titicaca1", pan=(0.08, 0.02, 0.0, 0.0))),
    dict(id="c6", text="答えは、砂漠の下の石です。", scene=ILLUST("nitrate2", grade="old", fx="dust", pan=(0.0, 0.0, 0.06, 0.03), tr="whip")),
    dict(id="c7", text="アタカマ砂漠の地面には、硝石がありました。", scene=CARD("硝石", sub="アタカマ砂漠", count=False, tr="flash")),
    dict(id="c8", text="畑の肥料にも、火薬にもなる石です。", scene=ILLUST("nitrate1", grade="old", fx="dust", pan=(0.05, 0.0, 0.0, 0.03))),
    dict(id="c9", text="1879年、税をめぐって、チリが港町を押さえます。",
         scene=MAP((-69.8, -23.3, 7, 40), FILL(BOL_COAST, color=SAND, alpha=0.45, id="bolc"), PIN(ANTOF, "アントファガスタ", on="港町"),
                   LABEL((-68.6, -21.2), "1879年", 90, YEL, on="1879年"), tr="zoom")),
    dict(id="c10", text="太平洋戦争です。", scene=TL(TL4, 1, view=(-68, -21, 16, 0), tr="flash")),
    dict(id="c11", text="1904年、ボリビアは海岸をチリに渡しました。",
         scene=MAP((-68, -21, 12, 35), FILL("BOL", color=SAND, alpha=0.45, id="bol"), FILL(BOL_COAST, color=RED, alpha=0.55, id="bolc_r", on="海岸", wipe="south"),
                   LABEL((-66.0, -25.6), "1904年", 72, YEL, on="1904年"), tr="zoom")),
    dict(id="c12", text="チリは、南緯24度から、729km北へ伸びました。",
         scene=MAP((-69.5, -23, 14, 35), FILL("CHL", id="chl", alpha=0.5), dict(kind="latline", lat=-24, id="l24"),
                   LINE([(-70.5, -24.0), NORTH], color=YEL, id="d", width=6, on="729km"), LABEL((-66.8, -20.5), "729km", 90, YEL, on="729km", count=True),
                   LABEL((-66.8, -24.8), "南緯24度", 56, WHITE, on="南緯24度"), ARROW((-73.5, -24), (-73.5, -18.5), id="up", on="北へ"))),
    dict(id="c13", text="ボリビアでは、3月23日が「海の日」。いまも、海への道を求めています。", style="end",
         scene=ILLUST("titicaca1", title="3月23日", sub="海の日", pan=(0.0, 0.02, 0.06, 0.0), tr="whip")),
])

P["s5"] = dict(title="記録に残る最大の地震は、チリ", lines=[
    dict(id="c1", text="記録に残る、最大の地震。", scene=CARD("M9.5", sub="記録に残る最大の地震", tr="flash")),
    dict(id="c2", text="1960年、チリで起きました。マグニチュード9.5。",
         scene=MAP((-72, -41, 14, 35), FILL("CHL", id="chl", alpha=0.35), LABEL((-70.5, -36.2), "1960年", 90, YEL, on="1960年"), tr="zoom")),
    dict(id="c3", text="ずれた長さは、およそ1,000km。",
         scene=MAP((-72, -41, 14, 35), FILL("CHL", id="chl", alpha=0.35), LINE(RUPTURE, color=RED, id="rup", width=14, on="ずれた", glow=True),
                   LABEL((-69.2, -41.5), "約1,000km", 80, YEL, on="1,000km", count=True))),
    dict(id="c4", text="東京から博多までより、長い距離です。", scene=CARD("886km", sub="東京駅 → 博多駅", note="これより長い", tr="whip")),
    dict(id="c5", text="なぜ、チリなのか。", style="question", sub="なぜ、【チリ】なのか",
         scene=dict(shot="globe", center=(-90, -20), to=(-72, -36), r=0.46, hl="CHL")),
    dict(id="c6", text="答えは、チリが細長い理由と同じです。",
         scene=MAP(V_CHILE, FILL("CHL", id="chl", alpha=0.55), tr="zoom")),
    dict(id="c7", text="海の底の板が、年に6.5cmから8cm、陸の下へもぐりこむ。",
         scene=MAP((-76, -33, 22, 30), ARROW((-88, -31), (-75, -31), color=BLUE, id="a1", on="海の底の板", width=18),
                   ARROW((-88, -37), (-75.5, -37), color=BLUE, id="a2", on="海の底の板", width=18), LINE(trench_line(-17.5, -45, 0.5), color=WHITE, id="tw", glow=True),
                   LABEL((-82, -27), "年 6.5〜8cm", 64, BLUE, on="6.5cm"), tr="zoom")),
    dict(id="c8", text="引きずりこまれた陸が、たまった力で、一気に跳ね返る。",
         scene=dict(shot="block", view=(-72.4, -36.2, 9.5, 58), lat=-38.0, lon=(-76.2, -70.0), plate=True, trench=-74.6, tr="flash",
                    labels=[(-74.6, -6000, "沈む板")])),
    dict(id="c9", text="それが、大地震です。", scene=CARD("大地震", count=False, tr="flash")),
    dict(id="c10", text="同じ力が、沖の深い溝と、アンデス山脈を作りました。",
         scene=dict(shot="block", view=(-70.4, -23.4, 9.5, 58), lat=-25.2, lon=(-73.6, -67.2), plate=True, trench=-71.6, tr="zoom",
                    labels=[(-71.8, -9000, "溝"), (-68.8, 7600, "アンデス")])),
    dict(id="c11", text="あいだに残った細い帯が、チリの国土です。",
         scene=MAP(V_CHILE, FILL("CHL", id="chl", alpha=0.55, on="細い帯"), tr="zoom")),
    dict(id="c12", text="揺れも、国の形も、同じ1つの力から生まれていたのです。",
         scene=dict(shot="globe", center=(-72, -34), to=(-66, -30), r=0.46, hl="CHL")),
    dict(id="c13", text="チリの地震のニュースを見たら、国の細さを思い出してください。", style="end",
         scene=MAP(V_CHILE, CHL, dict(kind="border", a="CHL", b="ARG", color=WHITE, width=6, glow=True, id="r", grow=0.7))),
])


YOMI = [("〜", "から"), ("4,274km", "よんせんにひゃくななじゅうよんキロ"), ("93km", "きゅうじゅうさんキロ"),
        ("6,000m", "ろくせんメートル"), ("1.5倍", "いってんごばい"), ("南緯", "なんい"),
        ("日本", "にほん"), ("縁", "ふち"), ("港町", "みなとまち"), ("同じ力", "おなじちから")]
# 行ごとの読みの直し(kana で見て違った所)
SAY = {("ch3", "c6"): "そのあいだに、高さの差が、およそ1万5,000m。",
       ("ch5", "c5"): "マプチェの長の一部の支えを得て、アラウカニアとパタゴニアの王を、名乗りました。",
       ("s2", "c3"): "1561年、チリの隊が、アンデス山脈を越えて、作りました。",
       ("s2", "c11"): "1881年、国境は、最も高い峰で、水を分ける線に。",
       ("s5", "c7"): "海の底の板が、ねんに6.5cmから8cm、陸の下へもぐりこむ。"}


def yomi(text):
    s = text
    for a, b in YOMI:
        s = s.replace(a, b)
    return s


def ep_for(name: str) -> dict:
    p = dict(P[name])
    res = []
    for l in p["lines"]:
        if (name, l["id"]) in SAY:
            l = dict(l, say=yomi(SAY[(name, l["id"])]))
        if "say" not in l:
            y = yomi(l["text"])
            if y != l["text"]:
                l = dict(l, say=y)
        res.append(l)
    p["lines"] = res
    return dict(kind="sim", aspect="portrait" if name.startswith("s") else "landscape", credit=CREDIT, **p)
