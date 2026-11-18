"""ガラパゴス諸島(生き物・型 B いる＋C 同じなのに違う): 本編 5 章とショート 5 本の台本と画面。ch1〜ch5・s1〜s5 の ep.py がここから読む。
画面の作りはアマゾン川の回(episodes/amazon/parts.py)を写した。生き物は Wikimedia Commons の写真(sim/photos.py、出典は sim/photos.json)。

数字の出典:
- Galapagos Conservancy(galapagos.org「Biodiversity」): 固有種は陸の鳥 約80%・爬虫類と陸の哺乳類 97%・植物 30%超。
  住みついた陸の鳥 29 種のうち 22 種が固有。もともといる陸の哺乳類は 6 種。ゾウガメは食べず飲まずで最長 1 年、
  今 15 種・大きな 10 の島に 15 以上の群れ、ドーム型は湿った高地のある大きな島・鞍型は乾いた島で日照りの食べ物不足に応じて。
  カメ・イグアナは植物の筏などで流れ着いた。ガラパゴスペンギンは北半球にいる唯一のペンギン。ウミイグアナは海に出る唯一のトカゲ・20万〜30万匹
- 島の年代: Frontiers in Earth Science 2018(10.3389/feart.2018.00050)の総説。サンクリストバル 約235万年前・エスパニョーラ 約261万〜271万年前の溶岩(White et al. 1993)。
  ナスカプレートはホットスポットに対して東へ 100万年に約51km(Argus et al. 2011)
- 海の温度: Karnauskas et al. 2015(Geophysical Research Letters)。イサベラ・フェルナンディナの西の冷たい水のたまり、1年の平均 22〜23度。
  ペンギンの巣はクロムウェル海流がわき上がる所に集まる(Boersma、Condor 1998)
- 1977 年の日照り(ダフネ・メジャー): 中くらいのガラパゴスフィンチの 8 割以上が死に、大きなくちばしの鳥が生き残った(Grant 夫妻、Balzan 賞の講演 2005。
  Boag & Grant 1981 Science 214:82-85 を引く Nature 1984)
- ダーウィンの来島 1835 年
自分で測ったもの(sim/measure.py、Terrain Tiles z10・Natural Earth 10m):
- 本土の岸からいちばん近い島まで 約928km。あいだの海のいちばん深い所 約3,199m。イサベラ・フェルナンディナの西の海の底 中央値 約3,171m
- 1km²以上の島 25・10km²以上 12。陸の合計 約8,600km²(1 画素約 300m の粗い値。四国 18,800km² の半分弱)。いちばん高い所 1,695m(イサベラ島の北)
- 東京〜福岡 まっすぐ約886km
地点・海流の道すじは地図から読んだ(読み)。"""
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
PH = HERE.parents[1] / "out" / "galapagos" / "photos"
_SRC = json.loads((HERE / "sim" / "photos.json").read_text(encoding="utf-8"))

CREDIT = "地図: NASA・Terrain Tiles・Natural Earth"
RED, YEL, WHITE, BLUE = (240, 90, 80), (255, 214, 64), (255, 255, 255), (120, 190, 255)
GREY, GREEN, SAND = (170, 180, 200), (110, 200, 110), (226, 196, 140)
COLD = (90, 200, 255)
WARM = (255, 140, 70)

# 地点(経度, 緯度)。読み
COAST, NEAR = (-80.916, -1.066), (-89.255, -0.719)
ISABELA, WOLF, FERN = (-91.1, -0.55), (-91.335, 0.043), (-91.55, -0.37)
SANCRI, ESPA, SANTACRUZ, DAPHNE = (-89.45, -0.85), (-89.68, -1.38), (-90.33, -0.65), (-90.37, -0.42)
QUITO = (-78.5, -0.2)
HUMBOLDT = [(-80.0, -14.0), (-82.5, -8.0), (-85.5, -4.0), (-89.0, -2.0)]
CROMWELL_A, CROMWELL_B = (-93.6, -0.25), (-91.9, -0.3)

WIDE = (-85.5, -1.5, 18.0, 0)
WIDE_T = (-86.0, -3.5, 15.0, 30)
ARCH = (-90.5, -0.45, 3.4, 0)
ARCH_T = (-90.5, -0.9, 3.0, 35)
WEST = (-91.3, -0.35, 1.2, 0)
WEST_T = (-91.3, -0.6, 1.1, 40)
WIDE_P = (-85.5, -1.2, 13.0, 0)
ARCH_P = (-90.5, -0.5, 2.6, 0)
WEST_P = (-91.3, -0.35, 0.9, 0)


def MAP(view, *layers, view_to=None, step=None, tr=None):
    s = dict(shot="map", view=view, layers=list(layers))
    for k, v in (("view_to", view_to), ("step", step), ("tr", tr)):
        if v is not None:
            s[k] = v
    return s


def LABEL(at_ll, text, size=56, color=WHITE, at=0.0, on=None, id=None):
    d = dict(kind="label", at_ll=at_ll, text=text, size=size, color=color, id=id or f"lab_{text}", at=at)
    if on:
        d["on"] = on
    return d


def PIN(at_ll, text, id=None, at=0.0, size=44):
    return dict(kind="pin", at_ll=at_ll, text=text, id=id or f"pin_{text}", at=at, size=size)


def LINE(pts, color=YEL, width=6, id=None, at=0.0):
    return dict(kind="route", pts=pts, color=color, width=width, id=id or f"route_{pts[0]}", at=at)


def ARROW(a, b, color=YEL, width=14, id=None, at=0.0):
    return dict(kind="arrow", a=a, b=b, color=color, width=width, id=id or f"arr_{a}", at=at)


def EQ(tag=""):
    return dict(kind="latline", lat=0.0, id=f"eq{tag}", at=0.0)


def ECU(tag="", alpha=0.35):
    return dict(kind="fill", code="ECU", color=WARM, alpha=alpha, id=f"ecu{tag}", at=0.0)


def DIST(tag=""):
    return LINE([COAST, NEAR], YEL, 8, id=f"dist{tag}")


def HUMB(tag=""):
    return LINE(HUMBOLDT, COLD, 12, id=f"hum{tag}")


def CROM(tag=""):
    return ARROW(CROMWELL_A, CROMWELL_B, COLD, 16, id=f"crom{tag}")


def PHOTO(name, step=None, pan=None, zoom=None, tr=None):
    s = _SRC[name]
    d = dict(shot="illust", path=str(PH / f"{name}.jpg"), label=f"写真: {s['artist']}（{s['license']}）", step=step)
    if pan:
        d["pan"] = pan
    if zoom:
        d["zoom"] = zoom
    if tr:
        d["tr"] = tr
    return d


def CARD(big, sub=None, note=None, view=ARCH, step=None, count=True, tr=None):
    d = dict(shot="card", big=big, sub=sub, note=note, view=view, step=step, count=count)
    if tr:
        d["tr"] = tr
    return d


def BARS(items, title=None, note=None, fmt="{}", step=None, tr=None):
    d = dict(shot="bars", items=items, title=title, note=note, fmt=fmt, step=step)
    if tr:
        d["tr"] = tr
    return d


def SEA(step=None, plate=False, tr=None, view=(-85.4, 0.6, 16.0, 58), inner=False):
    """本土からガラパゴスまで、南緯 0.75 度で海を切った箱。plate で本土の沖に沈みこむ板。"""
    d = dict(shot="block", view=view, lat=-0.75, lon=(-91.9, -79.0), depth_m=9000, step=step,
             labels=[(-89.6 if inner else -90.6, 2600, "ガラパゴス"), (-81.0 if inner else -79.8, 2600, "南米"), (-85.5, -1500, "深さ約3,200mの海")])
    if plate:
        d.update(plate=True, trench=-81.0)
    if tr:
        d["tr"] = tr
    return d


def HOT(step=None, tr=None, view=(-90.7, -0.1, 4.6, 58), inner=False):
    """島の下を切った箱。西の端の下にホットスポット。"""
    d = dict(shot="block", view=view, lat=-0.45, lon=(-92.4, -89.0), depth_m=9000, step=step,
             labels=[(-91.55, -4200 if inner else -2600, "ホットスポット"), (-91.2 if inner else -91.5, 2400, "西は若い"), (-89.9 if inner else -89.4, 1800, "東は古い")])
    if tr:
        d["tr"] = tr
    return d


GC, MINE, FR = "Galapagos Conservancy", "自分で測った（標高データ）", "Frontiers in Earth Science 2018"
ENDEMIC = BARS([("爬虫類・陸の哺乳類", 97, YEL), ("陸の鳥", 80, BLUE), ("植物", 30, GREEN)], title="ここにしかいない種類の割合（%）", note=GC + "（植物は30%以上）", fmt="{}")
FAR = BARS([("本土〜ガラパゴス", 928, YEL), ("東京〜福岡", 886, GREY)], title="まっすぐの距離（km）", note=MINE, fmt="{:,}")
AGES = BARS([("エスパニョーラ", 270, YEL), ("サンクリストバル", 235, YEL)],
            title="見つかった古い溶岩（万年前）", note=FR + "（東の島。西は今も噴火）", fmt="{}")

ANSWERS = [("大陸から約930km", "来られる生き物が限られた"),
           ("海の底の火山から生まれた", "一度も大陸とつながっていない"),
           ("赤道なのに冷たい海", "ペンギンと海藻を育てた"),
           ("島どうしも離れている", "同じ生き物が、島ごとに違う姿に")]

P = {}

# ---- 第1章 ここにしかいない生き物 --------------------------------------------------------------------------
P["ch1"] = dict(title="第1章 ここにしかいない生き物", cta=False, lines=[
    dict(id="a1", text="南米エクアドルの沖に浮かぶ、ガラパゴス諸島。", scene=dict(shot="globe", center=(-60, -10), to=(-86, -1), hl="ECU", step=0)),
    dict(id="a2", text="ここには、海に潜って海藻を食べるトカゲがいます。", scene=PHOTO("swim", step=0)),
    dict(id="a3", text="何も食べずに、1年生きられるカメもいます。", scene=PHOTO("domeeat", step=0, tr="whip")),
    dict(id="a4", text="赤道の真下なのに、ペンギンもいます。", scene=PHOTO("penguin", step=0, tr="whip")),
    dict(id="a5", text="島の爬虫類と陸の哺乳類は、97%がここにしかいない種類です。", scene=CARD("97%", sub="ここにしかいない種類（爬虫類・陸の哺乳類）", note=GC, step=0)),
    dict(id="a6", text="陸の鳥は約80%。植物も30%以上が、ここだけのものです。", scene=ENDEMIC),
    dict(id="a7", text="1835年、若いダーウィンがこの島に立ち寄りました。", scene=MAP(ARCH_T, step=0, view_to=(-90.5, -0.8, 2.6, 40))),
    dict(id="a8", text="生き物が少しずつ姿を変える「進化」の考えを、のちにまとめた学者です。"),
    dict(id="a9", text="なぜ、ガラパゴスの生き物は、ここにしかいないのか。", style="question", sub="爬虫類の97%が\n【ここだけ】の理由", scene=MAP(WIDE, ECU("a9"), step=0)),
    dict(id="a10", text="答えを先に言います。", section=True),
    dict(id="a11", text="3つの条件が重なったからです。", scene=MAP(WIDE_T, ECU("a11", 0.25), step=0)),
    dict(id="a12", text="1つ目。大陸から約930km離れた、海の真ん中にあること。", scene=MAP(WIDE, ECU("a12", 0.25), DIST("a12"), LABEL((-85.0, 0.2), "約930km", 64, YEL, on="930"), step=0)),
    dict(id="a13", text="2つ目。海の底の火山から生まれ、一度も大陸とつながったことがないこと。", scene=SEA(step=0, tr="zoom")),
    dict(id="a14", text="3つ目。赤道なのに、冷たい海に囲まれていること。", scene=MAP(WIDE_T, EQ("a14"), HUMB("a14"), LABEL((-86.5, 0.6), "赤道", 52, WHITE), step=0)),
    dict(id="a15", text="さらに、島どうしも離れています。だから、同じ生き物でも島ごとに姿が変わりました。", scene=MAP(ARCH, PIN(ISABELA, "イサベラ島", id="p_ai"), PIN(SANTACRUZ, "サンタクルス島", id="p_as"), PIN(SANCRI, "サンクリストバル島", id="p_ac"), step=0)),
    dict(id="a16", text="本土からの距離と海の深さは、標高のデータで、自分で測りました。", scene=MAP(WIDE, DIST("a16"), step=0, view_to=(-85.5, -1.5, 16.0, 20))),
    dict(id="a17", text="まず、島の大きさを見ておきます。", section=True, scene=MAP(ARCH_T, step=0)),
    dict(id="a18", text="1km²より大きな島が25。そのうち、10km²より大きな島が12です。", scene=CARD("25の島", sub="1km²より大きな島（10km²より大きいのは12）", note=MINE, view=ARCH, step=0)),
    dict(id="a19", text="陸を全部足しても、四国の半分ほどの広さです。", scene=BARS([("ガラパゴスの陸", 0.86, YEL), ("四国", 1.88, GREY)], title="広さ（万km²）", note=MINE + "・国土地理院", fmt="{}", step=0)),
    dict(id="a20", text="この小さな陸に、ここにしかいない生き物が集まっています。", scene=PHOTO("bask", step=0)),
])

# ---- 第2章 930kmの海 ---------------------------------------------------------------------------------------
P["ch2"] = dict(title="第2章 930kmの海", cta=False, lines=[
    dict(id="b1", text="1つ目の条件、距離から見ます。", scene=MAP(WIDE, ECU("b1", 0.25), step=1, tr="zoom")),
    dict(id="b2", text="いちばん近い本土の岸から、いちばん近い島まで。", scene=MAP(WIDE, ECU("b2", 0.25), PIN(COAST, "本土の岸", id="p_bc"), PIN(NEAR, "いちばん近い島", id="p_bn"), step=1)),
    dict(id="b3", text="地図の形から測ると、約930kmでした。", scene=MAP(WIDE, ECU("b3", 0.25), DIST("b3"), LABEL((-85.0, 0.2), "約930km", 72, YEL, on="930"), step=1)),
    dict(id="b4", text="東京から福岡まで、まっすぐ約890km。それより遠いのです。", scene=FAR),
    dict(id="b5", text="あいだの海の深さも、標高のデータで測りました。", scene=SEA(step=1, tr="zoom")),
    dict(id="b6", text="いちばん深い所は、約3,200m。", scene=CARD("約3,200m", sub="本土とガラパゴスのあいだの海の、いちばん深い所", note=MINE, view=WIDE, step=1)),
    dict(id="b6b", text="東京スカイツリーを5本積んでも、届かない深さです。", scene=BARS([("海のいちばん深い所", 3199, BLUE), ("スカイツリー5本", 3170, GREY)], title="深さ・高さ（m）", note=MINE + "・スカイツリー634m", fmt="{:,}", step=1)),
    dict(id="b7", text="海の水を抜いてみると、島と大陸のあいだには、深い谷が残ります。", scene=SEA(step=1, view=(-85.4, 0.4, 15.0, 62))),
    dict(id="b8", text="陸の道は、どこにもありません。"),
    dict(id="b9", text="生き物は、歩いては来られないのです。", scene=MAP(WIDE_T, DIST("b9"), step=1)),
    dict(id="b10", text="海を越えて来られたのは、3つの方法だけです。", section=True, scene=CARD("3つ", sub="海を越える方法", view=WIDE, step=1, count=False)),
    dict(id="b11", text="飛ぶ。泳ぐ。そして、流れ着く。", scene=CARD("飛ぶ・泳ぐ・流れ着く", view=WIDE_T, step=1, count=False)),
    dict(id="b12", text="鳥は、飛んで来ました。島に住みついた陸の鳥29種のうち、22種がここだけの種類です。", scene=PHOTO("finch", step=1)),
    dict(id="b13", text="アシカやペンギンは、海を泳いで来ました。", scene=PHOTO("sealion", step=1, tr="whip")),
    dict(id="b14", text="では、飛べず、泳ぎも得意でないカメやトカゲは。", scene=PHOTO("dome", step=1, tr="whip")),
    dict(id="b15", text="川から流された木や草のかたまりに乗って、流れ着いたと考えられています。", scene=MAP(WIDE, LINE([(-80.2, -2.5), (-84.0, -2.0), (-88.0, -1.2), NEAR], BLUE, 8, id="r_raft"), step=1)),
    dict(id="b16", text="ゾウガメは、何も食べず、何も飲まずに、最長1年生きられます。", scene=CARD("最長1年", sub="ゾウガメが食べず飲まずで生きられる長さ", note=GC, view=WIDE, step=1, count=False)),
    dict(id="b17", text="何週間も海を漂っても、生きたまま島に着けたのです。", scene=PHOTO("domeeat", step=1, pan=(0.1, 0.0, 0.0, 0.05))),
    dict(id="b18", text="逆に、たどり着けなかった生き物もいます。", section=True, scene=MAP(WIDE_T, ECU("b18", 0.3), step=1)),
    dict(id="b19", text="もともといた陸の哺乳類は、ネズミとコウモリの仲間の、わずか6種。", scene=CARD("6種", sub="もともといた陸の哺乳類", note=GC, view=ARCH, step=1)),
    dict(id="b20", text="シカもサルも、来られませんでした。"),
    dict(id="b21", text="930kmの海が、来られる生き物をふるいにかけたのです。", scene=MAP(WIDE, DIST("b21"), step=1, view_to=(-86.5, -1.2, 14.0, 25))),
])

# ---- 第3章 海の底から生まれた島 ----------------------------------------------------------------------------
P["ch3"] = dict(title="第3章 海の底から生まれた島", cta=False, lines=[
    dict(id="c1", text="2つ目の条件。島の生まれ方です。", scene=MAP(ARCH, step=2, tr="zoom")),
    dict(id="c2", text="ガラパゴスの島は、すべて火山です。", scene=PHOTO("lava", step=2)),
    dict(id="c3", text="島の下の深い所に、熱いマグマがわき上がる出口があります。「ホットスポット」と呼ばれます。", scene=HOT(step=2, tr="zoom")),
    dict(id="c4", text="マグマが海の底を突き破り、積み重なって、海の上に顔を出しました。"),
    dict(id="c5", text="いちばん高い所は、イサベラ島の山。標高のデータでは、約1,700mです。", scene=MAP(WEST_T, PIN(WOLF, "約1,700m", id="p_cw"), step=2)),
    dict(id="c6", text="まわりの海の底は、深さ約3,200m。", scene=BARS([("海の底から山の上まで", 4900, YEL), ("富士山", 3776, GREY)], title="高さ（m）", note=MINE + "（約1,700m＋約3,200m）", fmt="{:,}", step=2)),
    dict(id="c7", text="海の底から数えると、富士山より高い山なのです。"),
    dict(id="c8", text="ここで大事なのは、海の底が動いていることです。", section=True, scene=MAP(ARCH_T, step=2)),
    dict(id="c9", text="島が乗った海の底の板、ナスカプレートは、東へ動いています。", scene=MAP(ARCH, ARROW((-91.6, -1.45), (-89.2, -1.45), YEL, 16, id="a_plate"), LABEL((-90.4, -1.7), "ナスカプレート", 52, YEL), step=2)),
    dict(id="c10", text="速さは、100万年で約51km。1年なら約5cm。爪が伸びるのに近い速さです。", scene=CARD("1年に約5cm", sub="100万年で約51km（東へ）", note=FR, view=ARCH, step=2, count=False)),
    dict(id="c11", text="ところが、マグマの出口は動きません。", scene=HOT(step=2)),
    dict(id="c12", text="だから、生まれた島は東へ運ばれ、西で新しい島が生まれます。"),
    dict(id="c13", text="いちばん西のフェルナンディナ島は、今も噴火を続ける若い島です。", scene=MAP(WEST, PIN(FERN, "フェルナンディナ島", id="p_cf"), step=2, view_to=(-91.4, -0.4, 0.9, 30))),
    dict(id="c14", text="東のサンクリストバル島では、約235万年前の溶岩が見つかっています。", scene=AGES),
    dict(id="c15", text="エスパニョーラ島では、約270万年前です。"),
    dict(id="c15b", text="西の端から東の端までは、測ると約240kmあります。", scene=MAP(ARCH, LINE([FERN, SANCRI], YEL, 8, id="r_we"), LABEL((-90.5, -0.35), "約240km", 60, YEL, on="240"), step=2)),
    dict(id="c16", text="島は、ベルトコンベアに乗って並んだように、東ほど古いのです。", scene=MAP(ARCH, PIN(FERN, "若い", id="p_cy"), PIN(ESPA, "古い", id="p_co"), ARROW((-91.4, -1.6), (-89.4, -1.6), YEL, 12, id="a_conv"), step=2)),
    dict(id="c17", text="つまり、どの島も、生まれたときは溶岩だけの、生き物のいない島でした。", section=True, scene=PHOTO("lava", step=2, pan=(0.1, 0.0, -0.05, 0.03))),
    dict(id="c18", text="日本列島は、昔は大陸とつながっていました。だから、大陸と同じ仲間の生き物が多くいます。", scene=dict(shot="globe", center=(135, 35), to=(130, 38), step=2)),
    dict(id="c19", text="ガラパゴスは、一度も大陸とつながったことがありません。", scene=SEA(step=2, tr="zoom")),
    dict(id="c20", text="ここの生き物は、すべて海を越えて来たものの子孫です。", scene=MAP(WIDE_T, DIST("c20"), step=2)),
    dict(id="c21", text="来てからの数百万年で、少しずつ姿を変えていきました。", scene=PHOTO("swim", step=2, pan=(0.05, 0.0, -0.05, 0.0))),
])

# ---- 第4章 赤道の冷たい海 ----------------------------------------------------------------------------------
P["ch4"] = dict(title="第4章 赤道の冷たい海", cta=False, lines=[
    dict(id="d1", text="3つ目の条件は、海の温度です。", scene=MAP(WIDE, EQ("d1"), step=3, tr="zoom")),
    dict(id="d2", text="ガラパゴスは、赤道の真上にあります。", scene=MAP(ARCH, EQ("d2"), LABEL((-89.3, 0.18), "赤道", 52, WHITE), step=3)),
    dict(id="d3", text="いちばん大きなイサベラ島には、赤道の線が通っています。", scene=MAP(WEST, EQ("d3"), PIN(ISABELA, "イサベラ島", id="p_di"), step=3, view_to=(-91.2, -0.1, 1.0, 25))),
    dict(id="d4", text="赤道の海なら、あたたかいはず。ところが、ここの海は冷たいのです。", section=True, scene=CARD("赤道なのに\n冷たい海", view=ARCH, step=3, count=False)),
    dict(id="d5", text="南からは、冷たい水を運ぶ流れが来ます。フンボルト海流です。", scene=MAP(WIDE_T, HUMB("d5"), LABEL((-82.0, -9.0), "フンボルト海流", 52, COLD), step=3)),
    dict(id="d6", text="さらに西からは、海の深い所を東へ流れる流れがぶつかります。クロムウェル海流です。", scene=MAP((-91.8, -0.4, 3.6, 0), CROM("d6"), LABEL((-92.9, -0.75), "クロムウェル海流", 50, COLD), step=3, view_to=(-91.6, -0.5, 3.2, 20))),
    dict(id="d7", text="この流れが島の山の根元に当たり、深くの冷たい水を、海面へ押し上げます。", scene=HOT(step=3, tr="zoom")),
    dict(id="d8", text="イサベラ島とフェルナンディナ島の西には、まわりより冷たい水のたまりができます。", scene=MAP((-91.75, -0.45, 1.9, 30), dict(kind="area", rings=[[(-92.1, 0.25), (-91.65, 0.3), (-91.45, -0.2), (-91.55, -0.75), (-91.95, -0.9), (-92.25, -0.4)]], color=COLD, alpha=0.35, width=4, id="cold", at=0.0), step=3)),
    dict(id="d9", text="1年の平均で、22〜23度です。", scene=CARD("22〜23度", sub="島の西の冷たい水のたまり（1年の平均）", note="Karnauskas ほか 2015", view=WEST, step=3, count=False)),
    dict(id="d10", text="深くの水には、栄養がたっぷり含まれています。"),
    dict(id="d11", text="だから、魚や海藻がよく育ちます。", scene=MAP(WEST, step=3, view_to=(-91.4, -0.3, 0.9, 30))),
    dict(id="d12", text="この冷たい海に、ペンギンがいます。", section=True, scene=PHOTO("penguinswim", step=3)),
    dict(id="d13", text="ガラパゴスペンギン。北半球にもすむ、ただ1種類のペンギンです。", scene=PHOTO("penguin", step=3, tr="whip")),
    dict(id="d14", text="巣を作る場所は、冷たい水がわくイサベラ島とフェルナンディナ島のまわりに集まっています。", scene=MAP(WEST, PIN(FERN, "フェルナンディナ島", id="p_df"), PIN((-91.25, -0.95), "イサベラ島", id="p_di2"), step=3)),
    dict(id="d15", text="では、陸はどうか。島の海沿いは雨が少なく、溶岩とサボテンの乾いた土地です。", scene=PHOTO("cactus", step=3)),
    dict(id="d16", text="陸には食べ物が少ない。海には海藻がたくさんある。"),
    dict(id="d17", text="そこで、海に潜って海藻を食べるようになったのが、ウミイグアナです。", scene=PHOTO("swim", step=3, tr="whip")),
    dict(id="d18", text="海に出るトカゲは、世界でこの1種類だけです。", scene=CARD("世界で1種類", sub="海に出るトカゲ", note=GC, view=WEST, step=3, count=False)),
    dict(id="d19", text="島には、20万〜30万匹がいます。", scene=CARD("20万〜30万匹", sub="ウミイグアナの数", note=GC, view=ARCH, step=3, count=False)),
    dict(id="d20", text="冷たい海には長くいられないので、潜ったあとは黒い体で岩に並び、日を浴びて温まります。", scene=PHOTO("bask", step=3)),
    dict(id="d21", text="赤道の日差しと、冷たい海。この組み合わせが、ほかでは見ない暮らし方を生みました。", scene=MAP(ARCH_T, EQ("d21"), ARROW((-92.2, -0.25), (-91.6, -0.3), COLD, 16, id="cromd21"), step=3)),
])

# ---- 第5章 島ごとに違う ------------------------------------------------------------------------------------
_CV = [(WIDE, (-85.5, -1.5, 16.0, 15)), (ARCH, (-90.5, -0.6, 3.0, 30)), (WEST, (-91.3, -0.4, 1.0, 30)), (ARCH_T, (-90.5, -0.8, 2.6, 40))]
CARDS_N = lambda n: dict(shot="cards", items=ANSWERS, n=n, view=_CV[n - 1][0], view_to=_CV[n - 1][1], step=4)  # noqa: E731
P["ch5"] = dict(title="第5章 島ごとに違う", cta=True, lines=[
    dict(id="e1", text="最後に、もう1つのなぜです。", scene=MAP(ARCH, step=4, tr="zoom")),
    dict(id="e2", text="同じガラパゴスの中でも、島ごとに生き物の姿が違うのです。", scene=MAP(ARCH_T, PIN(ISABELA, "イサベラ島", id="p_ei"), PIN(SANTACRUZ, "サンタクルス島", id="p_es"), PIN(ESPA, "エスパニョーラ島", id="p_ee"), step=4)),
    dict(id="e3", text="ゾウガメは、今15種類。大きな10の島に、別々の群れがいます。", scene=CARD("15種類", sub="ゾウガメ（大きな10の島に、別々の群れ）", note=GC, view=ARCH, step=4)),
    dict(id="e4", text="甲羅の形は、2通りあります。", section=True, scene=PHOTO("dome", step=4)),
    dict(id="e5", text="丸いドーム型と、前がそり上がった、鞍の形です。", scene=PHOTO("saddle", step=4, tr="whip")),
    dict(id="e6", text="ドーム型は、高い山があって、湿った森のある大きな島にすみます。", scene=PHOTO("domeeat", step=4, tr="whip")),
    dict(id="e7", text="地面に草が多いので、首を上げなくても食べられます。"),
    dict(id="e8", text="鞍の形は、乾いた島にすみます。", scene=PHOTO("saddle2", step=4)),
    dict(id="e9", text="日照りで草が枯れると、残るのは背の高いサボテンです。", scene=PHOTO("cactus", step=4, tr="whip")),
    dict(id="e10", text="首を高く伸ばせるように、甲羅の前がそり上がりました。", scene=PHOTO("saddle2", step=4, pan=(0.08, -0.02, -0.02, 0.02), zoom=(1.08, 1.22))),
    dict(id="e11", text="島の高さが雨を決め、雨が食べ物を決め、食べ物が甲羅の形を決めたのです。", scene=CARD("高さ→雨→食べ物→甲羅", view=ARCH_T, step=4, count=False)),
    dict(id="e12", text="鳥でも、同じことが起きています。", section=True, scene=PHOTO("finch", step=4)),
    dict(id="e13", text="ダーウィンフィンチと呼ばれる、小さな鳥の仲間です。"),
    dict(id="e14", text="1977年、ダフネ・メジャーという小さな島が、ひどい日照りになりました。", scene=MAP(ARCH, PIN(DAPHNE, "ダフネ・メジャー島", id="p_ed"), step=4, view_to=(-90.4, -0.5, 1.4, 30))),
    dict(id="e15", text="柔らかい種がなくなり、残ったのは硬い殻の種だけ。"),
    dict(id="e16", text="その島の鳥の8割以上が死にました。", scene=CARD("8割以上", sub="1977年の日照りで死んだ鳥（ダフネ・メジャー島）", note="Grant 夫妻の調べ", view=ARCH, step=4, count=False)),
    dict(id="e17", text="生き残ったのは、くちばしの大きな鳥でした。硬い種を割れたからです。", scene=PHOTO("finch", step=4, pan=(0.12, -0.05, 0.05, 0.0), zoom=(1.1, 1.3))),
    dict(id="e18", text="次の世代は、くちばしが大きくなりました。"),
    dict(id="e19", text="姿が変わるところを、人が目の前で見たのです。", scene=MAP(ARCH_T, step=4)),
    dict(id="e20", text="答えをまとめます。", section=True, scene=CARDS_N(1)),
    dict(id="e21", text="大陸から約930km。来られる生き物が限られました。"),
    dict(id="e22", text="海の底の火山から生まれ、一度も大陸とつながっていません。", scene=CARDS_N(2)),
    dict(id="e23", text="赤道なのに冷たい海が、ペンギンと海藻を育てました。", scene=CARDS_N(3)),
    dict(id="e24", text="そして島どうしが離れているので、同じ生き物が、島ごとに違う姿になりました。", scene=CARDS_N(4)),
    dict(id="e25", text="爬虫類の97%がここだけの種類なのは、そのためです。", scene=ENDEMIC),
    dict(id="e26", text="次にゾウガメを見たら、甲羅の前の形を見てください。どんな島から来たかが、わかります。", scene=PHOTO("saddle", step=4)),
])

# ---- ショート ---------------------------------------------------------------------------------------------
P["s1"] = dict(title="赤道の真下に、ペンギンがいる", lines=[
    dict(id="k1", text="赤道の真下に、ペンギンがいます。", scene=PHOTO("penguin")),
    dict(id="k2", text="ガラパゴス諸島の、ガラパゴスペンギンです。", scene=MAP(WIDE_P, EQ("k2"), ECU("k2", 0.25))),
    dict(id="k3", text="北半球にもすむ、ただ1種類のペンギンです。", scene=PHOTO("penguinswim")),
    dict(id="k4", text="赤道の海は、あたたかいはず。なぜ、ここで暮らせるのか。", style="question", scene=MAP(ARCH_P, EQ("k4"))),
    dict(id="k5", text="答えは、海の深くから、冷たい水がわき上がっているからです。", section=True),
    dict(id="k6", text="島の西には、海の深い所を東へ流れる流れがあります。クロムウェル海流です。", scene=MAP((-91.4, -0.4, 2.6, 0), ARROW((-92.6, -0.25), (-91.7, -0.3), COLD, 16, id="cromk6"), LABEL((-92.0, 0.3), "クロムウェル海流", 44, COLD))),
    dict(id="k7", text="この流れが、海の底からそびえる島の山にぶつかります。", scene=HOT(view=(-90.9, 0.4, 3.6, 58), inner=True)),
    dict(id="k8", text="行き場をなくした深くの冷たい水が、海面へ押し上げられます。"),
    dict(id="k9", text="イサベラ島の西の海は、1年の平均で22〜23度。まわりより冷たい水のたまりです。", scene=CARD("22〜23度", sub="島の西の海（1年の平均）", view=WEST_P, count=False)),
    dict(id="k10", text="深い水は栄養が多く、魚がよく集まります。", scene=MAP(WEST_P, step=None, view_to=(-91.4, -0.3, 0.75, 25))),
    dict(id="k11", text="ペンギンが巣を作る場所は、この冷たい水がわく島のまわりに集まっています。", scene=MAP(WEST_P, PIN(FERN, "フェルナンディナ島", id="p_kf"))),
    dict(id="k12", text="赤道のペンギンは、海の底の山が作った、冷たい海で暮らしているのです。", scene=PHOTO("penguin", pan=(0.05, 0.0, -0.05, 0.03))),
    dict(id="k13", text="次にペンギンを見たら、赤道にもすむ仲間がいることを思い出してください。", scene=MAP(ARCH_P, EQ("k13"), tr="whip")),
])

P["s2"] = dict(title="泳げないゾウガメが、930kmの海を渡れた理由", lines=[
    dict(id="m1", text="ガラパゴスのゾウガメは、泳ぎが得意ではありません。", scene=PHOTO("dome")),
    dict(id="m2", text="それなのに、大陸から約930km離れた島にいます。", scene=MAP(WIDE_P, ECU("m2", 0.25), DIST("m2"), LABEL((-85.0, 0.3), "約930km", 56, YEL, on="930"))),
    dict(id="m3", text="どうやって来たのか。", style="question"),
    dict(id="m4", text="答えは、流れ着いた、と考えられています。", section=True, scene=MAP(WIDE_P, LINE([(-80.2, -2.5), (-84.0, -2.0), (-88.0, -1.2), NEAR], BLUE, 8, id="r_raft2"))),
    dict(id="m5", text="南米の川から流された木や草のかたまりに乗って。あるいは、自分の体で浮かんで。"),
    dict(id="m6", text="930kmは、東京から福岡よりも遠い距離です。", scene=FAR),
    dict(id="m7", text="何週間も、食べ物も水もない海の上です。", scene=SEA(view=(-85.4, 0.6, 14.0, 58), inner=True)),
    dict(id="m8", text="ところがゾウガメは、何も食べず、何も飲まずに、最長1年生きられます。", scene=CARD("最長1年", sub="食べず飲まずで生きられる長さ", view=WIDE_P, count=False)),
    dict(id="m9", text="だから、生きたまま島に着けたのです。", scene=PHOTO("domeeat")),
    dict(id="m10", text="逆に、大陸のシカやサルは来られませんでした。", scene=MAP(WIDE_P, ECU("m10", 0.35))),
    dict(id="m11", text="もともといた陸の哺乳類は、ネズミとコウモリの仲間の6種だけです。", scene=CARD("6種", sub="もともといた陸の哺乳類", view=ARCH_P)),
    dict(id="m12", text="海を越える力が、島にいる生き物を選んだのです。", scene=PHOTO("dome", pan=(0.05, 0.0, -0.05, 0.03))),
    dict(id="m13", text="次にカメを見たら、930kmの海を渡った仲間がいることを思い出してください。", scene=MAP(WIDE_P, DIST("m13"), tr="whip")),
])

P["s3"] = dict(title="ガラパゴスの島は、西へ行くほど若い", lines=[
    dict(id="n1", text="ガラパゴス諸島の島は、西へ行くほど若くなります。", scene=MAP(ARCH_P, PIN(FERN, "若い", id="p_ny"), PIN(ESPA, "古い", id="p_no"))),
    dict(id="n2", text="東のエスパニョーラ島では、約270万年前の溶岩。", scene=AGES),
    dict(id="n3", text="西のフェルナンディナ島は、今も噴火を続けています。", scene=PHOTO("lava")),
    dict(id="n4", text="なぜ、島の年齢が、東から西へ並んでいるのか。", style="question", scene=MAP(ARCH_P)),
    dict(id="n5", text="答えは、海の底がベルトコンベアのように動いているからです。", section=True, scene=MAP(ARCH_P, ARROW((-91.4, -1.5), (-89.4, -1.5), YEL, 14, id="a_n5"))),
    dict(id="n6", text="島の下の深くには、マグマがわき上がる出口があります。ホットスポットと呼ばれます。", scene=HOT(view=(-90.9, 0.4, 3.6, 58), inner=True)),
    dict(id="n7", text="この出口は、動きません。"),
    dict(id="n8", text="ところが、その上の海の底の板は、東へ動いています。", scene=MAP(ARCH_P, ARROW((-91.4, -1.5), (-89.4, -1.5), YEL, 14, id="a_n8"), LABEL((-90.4, -1.75), "ナスカプレート", 44, YEL))),
    dict(id="n9", text="速さは、100万年で約51km。1年で約5cmです。", scene=CARD("1年に約5cm", sub="100万年で約51km", view=ARCH_P, count=False)),
    dict(id="n10", text="出口の上で生まれた島は、東へ運ばれていきます。", scene=HOT(view=(-90.9, 0.4, 3.6, 58), inner=True)),
    dict(id="n11", text="そして、出口の上で、また新しい島が生まれます。"),
    dict(id="n12", text="だから、東の島ほど古く、西の島ほど若いのです。", scene=MAP(ARCH_P, PIN(FERN, "若い", id="p_ny2"), PIN(ESPA, "古い", id="p_no2"))),
    dict(id="n13", text="どの島も、溶岩だけの島から始まりました。生き物は、すべて海を越えて来たのです。", scene=PHOTO("lava", pan=(0.1, 0.0, -0.05, 0.03))),
    dict(id="n14", text="次に地図でガラパゴスを見たら、東から西へ、島の年齢をたどってみてください。", scene=MAP(ARCH_P, tr="whip")),
])

P["s4"] = dict(title="海に潜るトカゲは、世界にガラパゴスだけ", lines=[
    dict(id="q1", text="海に潜って、海藻を食べるトカゲがいます。", scene=PHOTO("swim")),
    dict(id="q2", text="ガラパゴスのウミイグアナです。", scene=MAP(ARCH_P)),
    dict(id="q3", text="海に出るトカゲは、世界でこの1種類だけです。", scene=CARD("世界で1種類", sub="海に出るトカゲ", view=ARCH_P, count=False)),
    dict(id="q4", text="なぜ、トカゲが海に潜るようになったのか。", style="question", scene=PHOTO("swim", pan=(0.05, 0.0, -0.05, 0.03))),
    dict(id="q5", text="答えは、陸より海のほうに、食べ物が多かったからです。", section=True),
    dict(id="q6", text="島の海沿いは雨が少なく、溶岩とサボテンの乾いた土地です。", scene=PHOTO("cactus")),
    dict(id="q7", text="一方、まわりの海には、深くから冷たい水がわき上がります。", scene=MAP(ARCH_P, CROM("q7"))),
    dict(id="q8", text="栄養の多い水で、岩には海藻がよく育ちます。", scene=MAP(WEST_P, view_to=(-91.4, -0.3, 0.75, 25))),
    dict(id="q9", text="ウミイグアナは、その海藻を食べて暮らしています。", scene=PHOTO("swim", pan=(-0.05, 0.0, 0.05, 0.0))),
    dict(id="q10", text="島には、20万〜30万匹がいます。", scene=CARD("20万〜30万匹", sub="ウミイグアナの数", view=ARCH_P, count=False)),
    dict(id="q11", text="ただ、冷たい海には長くいられません。"),
    dict(id="q12", text="潜ったあとは、黒い体で岩の上に並び、日を浴びて温まります。", scene=PHOTO("bask")),
    dict(id="q13", text="乾いた陸と、豊かな冷たい海。そのあいだで生まれた暮らし方です。", scene=MAP(ARCH_P, EQ("q13"))),
    dict(id="q14", text="次にトカゲを見たら、海に潜る仲間がいることを思い出してください。", scene=PHOTO("bask", pan=(0.05, 0.0, -0.05, 0.03), tr="whip")),
])

P["s5"] = dict(title="ゾウガメの甲羅は、島によって形が違う", lines=[
    dict(id="r1", text="ガラパゴスのゾウガメは、島によって甲羅の形が違います。", scene=PHOTO("dome")),
    dict(id="r2", text="丸いドーム型と、前がそり上がった、鞍の形です。", scene=PHOTO("saddle", tr="whip")),
    dict(id="r3", text="なぜ、同じゾウガメなのに、形が違うのか。", style="question", scene=MAP(ARCH_P)),
    dict(id="r4", text="答えは、島の高さが、食べ物を変えたからです。", section=True),
    dict(id="r5", text="高い山のある大きな島には、雲がかかって、湿った森ができます。", scene=MAP(WEST_P, PIN(WOLF, "約1,700m", id="p_rw"), view_to=(-91.3, -0.4, 0.75, 30))),
    dict(id="r6", text="地面に草が多いので、首を上げなくても食べられます。ここのカメは、ドーム型です。", scene=PHOTO("domeeat")),
    dict(id="r7", text="低い島は、乾いています。", scene=MAP(ARCH_P, PIN(ESPA, "エスパニョーラ島", id="p_re"))),
    dict(id="r8", text="日照りで草が枯れると、残るのは背の高いサボテンです。", scene=PHOTO("cactus")),
    dict(id="r9", text="首を高く伸ばせるカメが、生き残りやすかったのです。", scene=PHOTO("saddle2")),
    dict(id="r10", text="こうして、乾いた島のカメは、甲羅の前がそり上がりました。"),
    dict(id="r11", text="ゾウガメは今、15種類。大きな10の島に、別々の群れがいます。", scene=CARD("15種類", sub="ゾウガメ（大きな10の島）", view=ARCH_P)),
    dict(id="r12", text="島の高さが雨を決め、雨が食べ物を決め、食べ物が甲羅の形を決めたのです。", scene=CARD("高さ→雨→\n食べ物→甲羅", view=ARCH_P, count=False)),
    dict(id="r13", text="次にゾウガメを見たら、甲羅の前の形を見てください。どんな島から来たかが、わかります。", scene=PHOTO("saddle", pan=(0.05, 0.0, -0.05, 0.03), tr="whip")),
])

# ---- 読み ------------------------------------------------------------------------------------------------
YOMI = [("「進化」", "しんか"), ("「ホットスポット」", "ホットスポット"), ("ダフネ・メジャー", "ダフネメジャー"), ("生きたまま島に", "いきたまま、しまに"),
        ("通っています", "とおっています"), ("深く", "ふかく"), ("8割", "ハチワリ"), ("四国", "シコク"), ("爬虫類", "ハチュウルイ"), ("約930km", "約九百三十キロ"), ("930km", "九百三十キロ"), ("約890km", "約八百九十キロ"), ("約3,200m", "約三千二百メートル"), ("約1,700m", "約千七百メートル"),
        ("約51km", "約五十一キロ"), ("約240km", "約二百四十キロ"), ("5本", "ごほん"), ("東京スカイツリー", "とうきょうスカイツリー"), ("約5cm", "約五センチ"), ("1km²", "一平方キロメートル"), ("10km²", "十平方キロメートル"),
        ("1835年", "千八百三十五年"), ("1977年", "千九百七十七年"), ("100万年", "百万年"), ("約235万年前", "約二百三十五万年前"), ("約270万年前", "約二百七十万年前"),
        ("数百万年", "すうひゃくまんねん"), ("20万〜30万匹", "二十万から三十万びき"), ("22〜23度", "二十二から二十三度"), ("97%", "九十七パーセント"), ("約80%", "約八十パーセント"),
        ("30%以上", "三十パーセント以上"), ("29種", "にじゅうきゅうしゅ"), ("22種", "にじゅうにしゅ"), ("6種", "ろくしゅ"), ("15種類", "じゅうごしゅるい"),
        ("10の島", "とおのしま"), ("1種類", "いっしゅるい"), ("1年", "いちねん"), ("8割", "はちわり"), ("2通り", "ふたとおり"),
        ("1つ目", "ひとつめ"), ("2つ目", "ふたつめ"), ("3つ目", "みっつめ"), ("3つ", "みっつ"), ("1つ", "ひとつ"), ("25。", "にじゅうご。"), ("12です", "じゅうにです"),
        ("何週間", "なんしゅうかん"), ("鞍", "くら"), ("甲羅", "こうら"), ("海藻", "かいそう"), ("爬虫類", "はちゅうるい"), ("哺乳類", "ほにゅうるい"),
        ("北半球", "きたはんきゅう"), ("真下", "ました"), ("真上", "まうえ"), ("日照り", "ひでり"), ("硬い殻", "かたいから"), ("子孫", "しそん"),
        ("溶岩", "ようがん"), ("海沿い", "うみぞい"), ("本土", "ほんど"), ("日本列島", "にほんれっとう"), ("四国", "しこく"), ("富士山", "ふじさん"),
        ("東京", "とうきょう"), ("福岡", "ふくおか"), ("南米", "なんべい"), ("大陸", "たいりく"), ("潜", "もぐ"), ("並び", "ならび"), ("鳥", "とり")]


def yomi(s):
    for a, b in YOMI:
        s = s.replace(a, b)
    return s


SAY = {}


def ep_for(name: str) -> dict:
    p = dict(P[name])
    res = []
    for l in p["lines"]:
        if (name, l["id"]) in SAY:
            l = dict(l, say=SAY[(name, l["id"])])
        elif "say" not in l:
            y = yomi(l["text"])
            if y != l["text"]:
                l = dict(l, say=y)
        res.append(l)
    p["lines"] = res
    return dict(kind="sim", aspect="portrait" if name.startswith("s") else "landscape", credit=CREDIT, **p)
