"""海の水を全部抜いたら(世界版): 本編 5 章とショート 5 本の台本と画面。ch1〜ch5・s1〜s5 の ep.py がここから読む。
数字は sim/calc.py(結果 sim/calc.txt、ETOPO 2022 を 0.1 度おき)と sim/straits.py(sim/straits.txt、海峡とマリアナ海溝は 60 秒そのまま)。
本からの数字: 中央海嶺 6万5千km(NOAA Ocean Service)、2万年ほど前の海面 120m 以上低い(Lambeck ほか 2014 PNAS)、
チャレンジャー海淵 10,935m(Greenaway ほか 2021)、エベレスト 8,849m(2020 年 中国・ネパール発表)、月の直径 3,474km(NASA)、日本の面積 37.8万平方km(国土地理院)。
画面は 2〜3 行ごとに種類を変える(海面を下げる地図・海の断面・並べる・棒・数字)。"""
CREDIT = "地図: NASA・Terrain Tiles・ETOPO 2022"
RED, YEL, WHITE, BLUE = (240, 90, 80), (255, 214, 64), (255, 255, 255), (120, 190, 255)
GREY, SAND = (170, 180, 200), (226, 196, 140)

WORLD = (15, 18, 300, 0)
EUROPE = (2, 52, 20, 30)
BERING = (-163, 64, 24, 25)
SEASIA = (108, 2, 30, 20)
JPN = (140, 44, 24, 30)
MED = (10, 38, 36, 20)
ATL = (-35, 22, 95, 10)
WPAC = (146, 27, 52, 20)
MARIANA = (143, 15, 30, 20)

ATL_A, ATL_B = (-80, 30), (-9, 30)                 # 大西洋を北緯30度で(フロリダ→モロッコ)
PAC_A, PAC_B = (140.2, 35.5), (239.5, 35.5)        # 太平洋を北緯35.5度で(千葉→カリフォルニア)
MAR_A, MAR_B = (136, 11.35), (149, 11.35)          # マリアナ海溝を北緯11.35度で
ECS_A, ECS_B = (121.5, 31.5), (130, 26.5)            # 上海の沖から南東へ(大陸棚→沖縄の溝→太平洋)


def MAP(view, *layers, view_to=None, step=None, tr=None, inset=False):
    s = dict(shot="map", view=view, layers=list(layers))
    for k, v in (("view_to", view_to), ("step", step), ("tr", tr)):
        if v is not None:
            s[k] = v
    if inset:
        s["inset"] = True
    return s


def DRAIN(level, frm=0, fall_s=3.0, id="drain", at=0.0):
    return dict(kind="drain", level=level, frm=frm, fall_s=fall_s, id=id, at=at)


def LABEL(at_ll, text, size=56, color=WHITE, at=0.0, on=None, count=False, id=None):
    d = dict(kind="label", at_ll=at_ll, text=text, size=size, color=color, id=id or f"lab_{text}", at=at, count=count)
    if on:
        d["on"] = on
    return d


def PIN(at_ll, text, id=None, at=0.0, on=None, size=44):
    d = dict(kind="pin", at_ll=at_ll, text=text, id=id or f"pin_{text}", at=at, size=size)
    if on:
        d["on"] = on
    return d


def CARD(big, sub=None, note=None, view=WORLD, step=None, count=True, tr=None):
    d = dict(shot="card", big=big, sub=sub, note=note, view=view, step=step, count=count)
    if tr:
        d["tr"] = tr
    return d


def SLICE(a, b, level=0, frm=0, step=None, tr=None, **kw):
    d = dict(shot="slice", a=a, b=b, level=level, frm=frm, step=step, **kw)
    if tr:
        d["tr"] = tr
    return d


def ICONS(kind, n, title=None, note=None, hl=0, step=None, tr=None):
    d = dict(shot="icons", kind=kind, n=n, title=title, note=note, hl=hl, step=step)
    if tr:
        d["tr"] = tr
    return d


def BARS(items, title=None, note=None, fmt="{}", step=None, tr=None):
    d = dict(shot="bars", items=items, title=title, note=note, fmt=fmt, step=step)
    if tr:
        d["tr"] = tr
    return d


ANSWERS = [("海の水は13億3,700万立方km", "陸にのせると厚さ8.9km。エベレストが埋まる"),
           ("31m下げるとイギリスは大陸と地続き", "120mで日本も大陸とつながる"),
           ("2,000mで水は半分。海の中に6万5千kmの山脈", "大西洋の真ん中を南北に走る"),
           ("4,000〜5,000mで海の底の3分の1が現れる", "海の底のほとんどは深く平らな平原"),
           ("最後に残るのはマリアナ海溝", "深さ1万935m。日本から南へ2,700km")]
BANDS = [("0〜1,000m", 11.3, SAND), ("1,000〜3,000m", 12.9, GREY), ("3,000〜4,000m", 22.3, GREY),
         ("4,000〜5,000m", 32.1, YEL), ("5,000〜6,000m", 20.3, GREY), ("6,000m より深い", 1.0, RED)]

P = {}

# ---- 第1章 抜いていく -----------------------------------------------------------------------------------
P["ch1"] = dict(title="第1章 抜いていく", cta=False, lines=[
    dict(id="c1", text="地球の海の水を全部抜くと、出てくる海の底は、陸地の2.4倍の広さです。",
         scene=MAP(WORLD, DRAIN(11000, fall_s=6.0), step=0)),
    dict(id="c2", text="海の水は、全部で13億3,700万立方km。", scene=CARD("13億3,700万立方km", sub="地球の海の水", note="ETOPO 2022 の海の深さから計算", step=0)),
    dict(id="c3", text="陸の上に全部のせると、厚さは8.9km。", scene=BARS([("陸にのせた海の水", 8.92, BLUE), ("エベレスト", 8.849, GREY)], title="高さくらべ（計算）", fmt="{}km", step=0)),
    dict(id="c4", text="エベレストが、すっぽり埋まる量です。"),
    dict(id="c5", text="平均の深さは3,713m。富士山の高さとほぼ同じです。", scene=SLICE(PAC_A, PAC_B, step=0, title="太平洋を、日本からアメリカまで切る",
         ends=[(0.02, "日本"), (0.97, "アメリカ")], zmin=-9000)),
    dict(id="c6", text="この水を、上から少しずつ抜いていきます。", section=True, scene=MAP(WORLD, DRAIN(200, fall_s=5.0, id="d_c6"), step=0, view_to=(40, 25, 220, 0))),
    dict(id="c7", text="どこから何が現れて、最後にどこが残るのか。", style="question", sub="海を抜いていくと\n最後に【どこが】残るのか"),
    dict(id="c8", text="答えを先に言います。", section=True),
    dict(id="c9", text="たった31m下げただけで、イギリスは大陸と歩いてつながります。", scene=MAP(EUROPE, DRAIN(31, fall_s=3.0, id="d_c9"), PIN((-1.5, 52.5), "イギリス"), PIN((2.3, 48.9), "フランス", at=0.3), step=0, tr="whip")),
    dict(id="c10", text="4,000mから5,000mの間で、海の底の3分の1が、一気に現れます。", scene=MAP(WORLD, DRAIN(5000, frm=4000, fall_s=4.0, id="d_c10"), step=0)),
    dict(id="c11", text="そして最後に残るのは、日本から南へ2,700km、マリアナ海溝です。", scene=MAP(MARIANA, DRAIN(8000, frm=5000, fall_s=4.0, id="d_c11"), PIN((142.42, 11.35), "マリアナ海溝"), step=0, tr="whip")),
    dict(id="c12", text="世界の海の深さのデータで、海面を下げて確かめます。", scene=SLICE(ATL_A, ATL_B, level=3000, step=0, title="海の深さのデータで、海面を下げる", zmin=-7000,
         ends=[(0.02, "フロリダ"), (0.97, "モロッコ")])),
])

# ---- 第2章 最初の200m -----------------------------------------------------------------------------------
P["ch2"] = dict(title="第2章 最初の200m", cta=False, lines=[
    dict(id="d1", text="まず、50m下げます。", scene=MAP(WORLD, DRAIN(50, fall_s=3.0, id="d_d1"), step=1, tr="zoom")),
    dict(id="d2", text="出てくる海の底は、1,070万平方km。日本の28個ぶんです。", scene=ICONS("japan", 28, title="50m下げて出てくる底 ＝ 日本 28個ぶん", note="1,070万平方km（計算）", step=1)),
    dict(id="d3", text="イギリスは、31mでフランスと地続きになります。", scene=MAP(EUROPE, DRAIN(50, fall_s=3.0, id="d_d3"), PIN((-1.5, 52.5), "イギリス"), PIN((2.3, 48.9), "フランス", at=0.3),
         LABEL((3.5, 54.5), "31mで地続き", 50, YEL, on="31m"), step=1, tr="whip")),
    dict(id="d4", text="アラスカとシベリアも、45mでつながります。", scene=MAP(BERING, DRAIN(50, fall_s=3.0, id="d_d4"), PIN((-152, 64), "アラスカ"), PIN((-173.5, 65.8), "シベリア", at=0.3), step=1)),
    dict(id="d5", text="スマトラもボルネオも、マレー半島と1つの陸になります。", scene=MAP(SEASIA, DRAIN(50, fall_s=3.0, id="d_d5"), PIN((101.5, -0.5), "スマトラ"), PIN((114, 0.5), "ボルネオ", at=0.3), step=1, tr="whip")),
    dict(id="d6", text="陸のまわりの海は、浅い棚のように広がっているのです。", scene=SLICE(ECS_A, ECS_B, level=50, step=1, title="上海の沖から、沖縄の先へ切る", zmax=300, zmin=-2500,
         ends=[(0.03, "上海の沖"), (0.95, "沖縄の先")], labels=[(0.25, -500, "浅くて平らな棚", SAND)])),
    dict(id="d7", text="深さはおよそ200mまで。大陸棚と呼ばれます。"),
    dict(id="d8", text="次は、120mまで下げます。", section=True, scene=MAP(JPN, DRAIN(120, frm=50, fall_s=4.0, id="d_d8"), step=1, tr="zoom")),
    dict(id="d9", text="北海道は、59mでサハリンとつながります。", scene=MAP(JPN, DRAIN(120, frm=50, fall_s=0.1, id="d_d9"), PIN((143, 43.5), "北海道"), PIN((142.7, 49.5), "サハリン", at=0.3), step=1)),
    dict(id="d10", text="サハリンは、すぐに大陸と地続きです。"),
    dict(id="d11", text="本州と北海道も、およそ120mでつながります。", scene=MAP(JPN, DRAIN(125, frm=100, fall_s=3.0, id="d_d11"), PIN((140.5, 39.5), "本州"), PIN((143, 43.5), "北海道", at=0.3), step=1)),
    dict(id="d12", text="実は2万年ほど前、海はいまより120m以上低かったのです。", scene=CARD("120m以上", sub="2万年ほど前の海は、いまより低かった", note="氷河期（Lambeck ほか 2014）", view=JPN, step=1, count=False)),
    dict(id="d13", text="それでも、海の水は、まだ97%残っています。", scene=CARD("97%", sub="120m下げても残る水", note="計算", view=WORLD, step=1)),
    dict(id="d14", text="海の水のほとんどは、もっと深い所にあるのです。", scene=MAP(WORLD, DRAIN(120, fall_s=0.1, id="d_d14"), step=1, view_to=(-30, 20, 200, 0))),
])

# ---- 第3章 海の中の山脈 ---------------------------------------------------------------------------------
P["ch3"] = dict(title="第3章 海の中の山脈", cta=False, lines=[
    dict(id="e1", text="地中海は、283m下げると、大西洋と切れます。", scene=MAP(MED, DRAIN(283, frm=120, fall_s=3.0, id="d_e1"), PIN((-5.6, 36.0), "ジブラルタル海峡"), step=2, tr="zoom")),
    dict(id="e2", text="大きな湖のようになるのです。", scene=MAP(MED, DRAIN(283, frm=280, fall_s=0.1, id="d_e2"), LABEL((18, 34.5), "地中海", 60, WHITE), step=2)),
    dict(id="e3", text="1,000m下げても、海の水は4分の3が残ります。", scene=MAP(WORLD, DRAIN(1000, frm=283, fall_s=4.0, id="d_e3"), step=2, tr="whip")),
    dict(id="e4", text="2,000mで、水はようやく半分です。", scene=CARD("半分", sub="2,000m下げたときに残る水", note="52%（計算）", step=2, count=False)),
    dict(id="e5", text="すると、大西洋の真ん中に、何かが現れます。", section=True, scene=MAP(ATL, DRAIN(3000, frm=2000, fall_s=4.5, id="d_e5"), step=2, tr="zoom")),
    dict(id="e6", text="海の底を、南北に走る長い山脈です。", scene=MAP(ATL, DRAIN(3000, frm=2990, fall_s=0.1, id="d_e6"), LABEL((-38, 25), "海の中の山脈", 60, YEL, on="山脈"), step=2)),
    dict(id="e7", text="大西洋を、横に切ってみます。", scene=SLICE(ATL_A, ATL_B, level=0, step=2, title="大西洋を北緯30度で切る", zmin=-7000,
         ends=[(0.02, "フロリダ"), (0.97, "モロッコ")])),
    dict(id="e8", text="両側の深い所は5,000m以上。真ん中だけが、盛り上がっています。", scene=SLICE(ATL_A, ATL_B, level=3000, step=2, title="大西洋を北緯30度で切る", zmin=-7000,
         ends=[(0.02, "フロリダ"), (0.97, "モロッコ")], labels=[(0.52, -1500, "真ん中の山脈", YEL), (0.2, -6200, "5,000m以上", WHITE), (0.8, -6200, "5,000m以上", WHITE)])),
    dict(id="e9", text="ここは、海の底が両側へ少しずつ広がっていく割れ目です。"),
    dict(id="e10", text="こうした海の中の山脈は、地球をぐるりと6万5千km。", scene=MAP(WORLD, DRAIN(3000, frm=2990, fall_s=0.1, id="d_e10"), step=2, view_to=(-20, 0, 260, 0))),
    dict(id="e11", text="陸のどの山脈よりも長い、地球で一番長い山脈です。", scene=CARD("6万5千km", sub="海の中の山脈の長さ", note="地球を1周半（NOAA）", step=2, count=False)),
    dict(id="e12", text="3,000m下げて、出てくる海の底は、まだ4分の1。", scene=MAP(WORLD, DRAIN(3000, frm=2990, fall_s=0.1, id="d_e12"), step=2)),
    dict(id="e13", text="本当の変化は、ここからです。"),
])

# ---- 第4章 一気に干上がる -------------------------------------------------------------------------------
P["ch4"] = dict(title="第4章 一気に干上がる", cta=False, lines=[
    dict(id="f1", text="3,000mから、4,000mへ。", scene=MAP(WORLD, DRAIN(4000, frm=3000, fall_s=4.0, id="d_f1"), step=3, tr="zoom")),
    dict(id="f2", text="出てくる底は、4分の1から、半分近くまで増えます。", scene=BARS([("3,000m", 24.2, GREY), ("4,000m", 46.5, YEL)], title="出てくる海の底の割合（計算）", fmt="{}%", step=3)),
    dict(id="f3", text="さらに、5,000mへ。", scene=MAP(WORLD, DRAIN(5000, frm=4000, fall_s=4.0, id="d_f3"), step=3, tr="whip")),
    dict(id="f4", text="今度は、海の底の3分の1が、一気に現れます。"),
    dict(id="f5", text="海の底を、深さで分けてみます。", section=True, scene=BARS(BANDS, title="海の底の深さの割合（計算）", fmt="{}%", step=3)),
    dict(id="f6", text="一番広いのは、4,000mから5,000mの深さ。32%です。"),
    dict(id="f7", text="海の底の大部分は、深くて平らな平原なのです。", scene=SLICE(PAC_A, PAC_B, level=4000, frm=3000, step=3, title="太平洋を、日本からアメリカまで切る", zmin=-9000,
         ends=[(0.02, "日本"), (0.97, "アメリカ")], labels=[(0.5, -6900, "深くて平らな平原", SAND)])),
    dict(id="f8", text="5,000mまで下げると、残る水は、たったの2.4%。", scene=CARD("2.4%", sub="5,000m下げたときに残る水", note="計算", step=3)),
    dict(id="f9", text="太平洋も大西洋も、いくつもの水たまりに分かれます。", scene=MAP(WORLD, DRAIN(5000, frm=4990, fall_s=0.1, id="d_f9"), step=3, view_to=(60, 5, 200, 0))),
    dict(id="f10", text="6,000mでは、海の底の99%が干上がります。", scene=MAP(WORLD, DRAIN(6000, frm=5000, fall_s=4.0, id="d_f10"), step=3)),
    dict(id="f11", text="残る水の広さは370万平方km。日本の10個ぶんほどです。", scene=ICONS("japan", 10, title="残る水の広さ ＝ 日本 10個ぶん", note="370万平方km（計算）", step=3)),
    dict(id="f12", text="その水は、細長い溝にだけ残っています。", scene=MAP(WPAC, DRAIN(6000, frm=5990, fall_s=0.1, id="d_f12"), step=3, tr="zoom")),
    dict(id="f13", text="海溝と呼ばれる、海の底の深い溝です。"),
])

# ---- 第5章 最後の水たまり -------------------------------------------------------------------------------
CARDS_N = lambda n: dict(shot="cards", items=ANSWERS, n=n, view=WORLD, step=4)  # noqa: E731
P["ch5"] = dict(title="第5章 最後の水たまり", cta=True, lines=[
    dict(id="g1", text="海溝が並ぶのは、太平洋のふちです。", scene=MAP(WPAC, DRAIN(7000, frm=6000, fall_s=4.0, id="d_g1"), PIN((144.2, 37.5), "日本海溝"), PIN((142.42, 11.35), "マリアナ海溝", at=0.3), step=4, tr="zoom")),
    dict(id="g2", text="日本のすぐ東の、日本海溝もその1つです。"),
    dict(id="g3", text="そして最後まで残るのが、マリアナ海溝です。", scene=MAP(MARIANA, DRAIN(8000, frm=6000, fall_s=5.0, id="d_g3"), PIN((142.42, 11.35), "マリアナ海溝"), step=4, tr="whip")),
    dict(id="g4", text="一番深いチャレンジャー海淵は、深さ1万935m。", scene=SLICE(MAR_A, MAR_B, level=7500, frm=4000, step=4, title="マリアナ海溝を切る", zmax=1000, zmin=-11000,
         ends=[(0.03, "西"), (0.97, "東")], labels=[(0.49, -9800, "チャレンジャー海淵", YEL)])),
    dict(id="g5", text="エベレストを沈めても、上に2,000m以上の水が残る深さです。", scene=BARS([("チャレンジャー海淵", 10.935, BLUE), ("エベレスト", 8.849, GREY)], title="深さと高さ", fmt="{}km", step=4)),
    dict(id="g6", text="まとめます。", section=True, scene=CARDS_N(1)),
    dict(id="g7", text="1つ目。海の水を陸にのせると、厚さ8.9km。エベレストが埋まる。"),
    dict(id="g8", text="2つ目。31m下げるとイギリスが、120mで日本も、大陸とつながる。", scene=CARDS_N(2)),
    dict(id="g9", text="3つ目。2,000mで水は半分。海の中に、6万5千kmの山脈が現れる。", scene=CARDS_N(3)),
    dict(id="g10", text="4つ目。4,000mから5,000mで、海の底の3分の1が一気に現れる。", scene=CARDS_N(4)),
    dict(id="g11", text="5つ目。最後に残るのは、深さ1万935mのマリアナ海溝。", scene=CARDS_N(5)),
    dict(id="g12", text="海は、浅い棚と、深くて平らな底と、細い溝でできていました。", scene=MAP(WORLD, DRAIN(4500, fall_s=6.0, id="d_g12"), step=4, view_to=(60, 15, 200, 0))),
    dict(id="g13", text="次に海を見たら、その下に、4,000mの平原が広がっていると思い出してください。"),
])

# ---- ショート -------------------------------------------------------------------------------------------
WORLD_P = (130, 15, 90, 0)
ATL_P = (-30, 25, 40, 10)
JPN_P = (141, 43, 12, 30)
EUROPE_P = (0, 52, 12, 30)

P["s1"] = dict(title="海を31m下げると、イギリスは大陸と地続き", lines=[
    dict(id="a1", text="海を31m下げるだけで、イギリスは大陸と歩いてつながります。", scene=MAP(EUROPE_P, DRAIN(31, fall_s=3.0), PIN((-1.5, 52.5), "イギリス"), PIN((2.3, 48.9), "フランス", at=0.3))),
    dict(id="a2", text="海峡の底は、それほど浅いのです。", scene=MAP(EUROPE_P, DRAIN(50, frm=31, fall_s=3.0, id="d_a2"))),
    dict(id="a3", text="45mで、アラスカとシベリアもつながります。", scene=MAP((-165, 64.5, 16, 25), DRAIN(50, fall_s=3.0, id="d_a3"), PIN((-156, 64.5), "アラスカ"), PIN((-173.5, 65.8), "シベリア", at=0.3), tr="whip")),
    dict(id="a4", text="50mで出てくる海の底は、日本の28個ぶんです。", scene=ICONS("japan", 28, title="50m下げて出てくる底", note="日本 28個ぶん（計算）")),
    dict(id="a5", text="北海道は59mでサハリンとつながり、大陸と地続きに。", scene=MAP(JPN_P, DRAIN(60, fall_s=3.0, id="d_a5"), PIN((143, 43.5), "北海道"), PIN((142.7, 49.5), "サハリン", at=0.3), tr="whip")),
    dict(id="a6", text="およそ120mで、本州も北海道とつながります。", scene=MAP(JPN_P, DRAIN(125, frm=60, fall_s=3.0, id="d_a6"), PIN((140, 40), "本州"))),
    dict(id="a7", text="2万年ほど前、海は実際に、いまより120m以上低かったのです。", scene=CARD("120m以上", sub="2万年ほど前の海は、いまより低かった", note="氷河期（Lambeck ほか 2014）", view=JPN_P, count=False)),
])

P["s2"] = dict(title="海の水を陸にのせると、エベレストが埋まる", lines=[
    dict(id="b1", text="地球の海の水を陸の上にのせると、エベレストが埋まります。", scene=MAP(WORLD_P, DRAIN(11000, fall_s=6.0))),
    dict(id="b2", text="海の水は、13億3,700万立方km。", scene=CARD("13億3,700万立方km", sub="地球の海の水", note="海の深さのデータから計算", view=WORLD_P)),
    dict(id="b3", text="陸の広さは、海の半分もありません。", scene=BARS([("海", 360.1, BLUE), ("陸", 149.9, SAND)], title="広さ（百万平方km）", fmt="{}")),
    dict(id="b4", text="だから陸にのせると、厚さ8.9km。", scene=BARS([("のせた水", 8.92, BLUE), ("エベレスト", 8.849, GREY)], title="高さくらべ（計算）", fmt="{}km")),
    dict(id="b5", text="エベレストの8,849mより、少しだけ高いのです。"),
    dict(id="b6", text="平均の深さは3,713m。富士山の高さとほぼ同じ深さの水が、地球の7割を覆っています。", scene=SLICE(PAC_A, PAC_B, title="太平洋を切ると", zmin=-9000, ends=[(0.04, "日本"), (0.95, "アメリカ")])),
    dict(id="b7", text="全部を1つの球にすると、直径1,367km。月の4割の大きさです。", scene=CARD("直径1,367km", sub="海の水を1つの球にすると", note="月の直径は3,474km", view=WORLD_P, count=False)),
])

P["s3"] = dict(title="大西洋の底には、6万5千kmの山脈がある", lines=[
    dict(id="h1", text="大西洋の水を抜くと、真ん中に長い山脈が現れます。", scene=MAP(ATL_P, DRAIN(3000, fall_s=5.0))),
    dict(id="h2", text="横に切ってみると、こうです。", scene=SLICE(ATL_A, ATL_B, title="大西洋を北緯30度で切る", zmin=-7000, ends=[(0.05, "フロリダ"), (0.93, "モロッコ")])),
    dict(id="h3", text="両側は5,000m以上の深さ。真ん中だけが盛り上がっています。", scene=SLICE(ATL_A, ATL_B, level=3000, title="大西洋を北緯30度で切る", zmin=-7000,
         ends=[(0.05, "フロリダ"), (0.93, "モロッコ")], labels=[(0.52, -1500, "真ん中の山脈", YEL)])),
    dict(id="h4", text="ここは、海の底が両側へ広がっていく割れ目です。"),
    dict(id="h5", text="こうした海の中の山脈は、地球をぐるりと6万5千km。", scene=MAP(WORLD_P, DRAIN(3000, frm=2990, fall_s=0.1, id="d_h5"), tr="whip")),
    dict(id="h6", text="地球を1周半する長さで、陸のどの山脈よりも長いのです。", scene=CARD("6万5千km", sub="海の中の山脈の長さ", note="地球を1周半（NOAA）", view=WORLD_P, count=False)),
])

P["s4"] = dict(title="海の底の3分の1は、深さ4,000〜5,000mの平原", lines=[
    dict(id="k1", text="海の底の3分の1は、深さ4,000mから5,000mの、平らな平原です。", scene=MAP(WORLD_P, DRAIN(5000, frm=4000, fall_s=5.0))),
    dict(id="k2", text="海の底を、深さで分けてみます。", scene=BARS(BANDS, title="海の底の深さの割合（計算）", fmt="{}%")),
    dict(id="k3", text="一番広いのは、4,000mから5,000m。32%です。"),
    dict(id="k4", text="だから海面を下げていくと、4,000mを過ぎたとたん、底が一気に現れます。", scene=MAP(WORLD_P, DRAIN(5000, frm=3000, fall_s=5.0, id="d_k4"))),
    dict(id="k5", text="太平洋を切ると、深くて平らな底が、どこまでも続いています。", scene=SLICE(PAC_A, PAC_B, level=4500, frm=3000, title="太平洋を切ると", zmin=-9000, ends=[(0.04, "日本"), (0.95, "アメリカ")])),
    dict(id="k6", text="5,000mまで下げると、残る水はたったの2.4%です。", scene=CARD("2.4%", sub="5,000m下げたときに残る水", note="計算", view=WORLD_P)),
])

P["s5"] = dict(title="海の水を抜いて、最後に残るのはマリアナ海溝", lines=[
    dict(id="m1", text="海の水を抜いていくと、最後に残るのは、マリアナ海溝です。", scene=MAP((143, 15, 26, 30), DRAIN(9000, frm=4000, fall_s=6.0), PIN((142.42, 11.35), "マリアナ海溝"))),
    dict(id="m2", text="6,000m下げると、海の底の99%が干上がります。", scene=MAP(WORLD_P, DRAIN(6000, fall_s=4.0, id="d_m2"), tr="whip")),
    dict(id="m3", text="水が残るのは、太平洋のふちの細長い溝だけです。", scene=MAP((146, 25, 34, 20), DRAIN(7000, frm=6000, fall_s=3.0, id="d_m3"), PIN((144.2, 37.5), "日本海溝"))),
    dict(id="m4", text="その中で一番深いのが、日本から南へ2,700kmの、チャレンジャー海淵。", scene=SLICE(MAR_A, MAR_B, level=7500, frm=4000, title="マリアナ海溝を切る", zmax=1000, zmin=-11000,
         ends=[(0.05, "西"), (0.95, "東")], labels=[(0.49, -9800, "チャレンジャー海淵", YEL)])),
    dict(id="m5", text="深さは1万935m。", scene=CARD("1万935m", sub="チャレンジャー海淵の深さ", note="2021年の測定", view=WORLD_P, count=False)),
    dict(id="m6", text="エベレストを沈めても、上に2,000m以上の水が残ります。", scene=BARS([("海淵の深さ", 10.935, BLUE), ("エベレスト", 8.849, GREY)], title="深さと高さ", fmt="{}km")),
])

# ---- 読み ------------------------------------------------------------------------------------------------
YOMI = [("13億3,700万立方km", "ジュウサンオクサンゼンナナヒャクマンリッポウキロメートル"), ("1,070万平方km", "センナナジュウマンヘイホウキロメートル"),
        ("370万平方km", "サンビャクナナジュウマンヘイホウキロメートル"), ("6万5千km", "ロクマンゴセンキロメートル"),
        ("1万935m", "イチマンキュウヒャクサンジュウゴメートル"), ("1,367km", "センサンビャクロクジュウナナキロメートル"),
        ("2,700km", "ニセンナナヒャクキロメートル"), ("8,849m", "ハッセンハッピャクヨンジュウキュウメートル"),
        ("3,713m", "サンゼンナナヒャクジュウサンメートル"), ("2,000m", "ニセンメートル"), ("3,000m", "サンゼンメートル"),
        ("4,000m", "ヨンセンメートル"), ("5,000m", "ゴセンメートル"), ("6,000m", "ロクセンメートル"), ("1,000m", "センメートル"),
        ("8.9km", "ハッテンキュウキロメートル"), ("2.4倍", "ニテンヨンバイ"), ("2.4%", "ニテンヨンパーセント"),
        ("283m", "ニヒャクハチジュウサンメートル"), ("120m", "ヒャクニジュウメートル"), ("200m", "ニヒャクメートル"),
        ("31m", "サンジュウイチメートル"), ("45m", "ヨンジュウゴメートル"), ("50m", "ゴジュウメートル"), ("59m", "ゴジュウキュウメートル"),
        ("97%", "キュウジュウナナパーセント"), ("99%", "キュウジュウキュウパーセント"), ("32%", "サンジュウニパーセント"),
        ("28個", "ニジュウハッコ"), ("10個", "ジュッコ"), ("4分の3", "ヨンブンノサン"), ("4分の1", "ヨンブンノイチ"), ("3分の1", "サンブンノイチ"),
        ("1周半", "いっしゅうはん"), ("海淵", "かいえん"), ("海溝", "かいこう"), ("大陸棚", "たいりくだな"), ("地続き", "じつづき"),
        ("1つ目", "ひとつめ"), ("2つ目", "ふたつめ"), ("3つ目", "みっつめ"), ("4つ目", "よっつめ"), ("5つ目", "いつつめ"), ("1つ", "ひとつ"), ("日本", "にほん"), ("大西洋", "たいせいよう")]


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
