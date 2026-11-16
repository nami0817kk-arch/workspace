"""屋久島(地理・型 A 水の行方): 本編 5 章とショート 5 本の台本と画面。ch1〜ch5・s1〜s5 の ep.py がここから読む。
画面の作りは豊予海峡の回(episodes/hoyo/parts.py)を写した。国土地理院の空中写真と標高。

数字の出典:
- 気象庁 平年値(1991〜2020 年)の年降水量: 屋久島 4,651.7mm、種子島 2,532.5mm、東京 1,598.2mm
  (屋久島・種子島は気象庁のデータを加工したサイトで確かめた)
- 林野庁「屋久島の自然」: 山の上の年降水量は 8,000〜10,000mm と推測
- 環境省: 島で使う電気の 99.5% が水力発電。国土交通省: 屋久島電工が水力発電所を 3 つ動かしている
- 宮之浦岳 1,936m(国土地理院、九州でいちばん高い山)
- 「月のうち三十五日は雨」: 林芙美子『浮雲』の屋久島の言い回し
- 東京ドームの容積 124 万m³
自分で測った・計算したもの:
- sim/measure.py(国土地理院の標高タイル): 屋久島 面積 506km²・いちばん高い所 1,931m・そこから海岸まで 9.8km・1,000m より上 124km²。
  種子島 面積 456km²・いちばん高い所 281m。2 つの島のあいだ 最短 17.8km(z12 の陸地の形から)
- 雨の量: 506km²(自分で測った) × 4.65m ≒ 23.5 億m³(海沿いの値で少なく見積もった。山の上はもっと多い)→ 東京ドーム 約 1,900 杯
- 空気が冷える: 雲の中では 100m 上るごとに約 0.5 度。1,900m 上ると約 10 度下がる。
  空気 1m³ が持てる水: 25 度で約 23g、15 度で約 13g(飽和水蒸気量)→ 約 10g が水になって出てくる
地点・黒潮の道すじは地図から読んだ(読み)。"""
import json
from pathlib import Path

CREDIT = "地図: 国土地理院・NASA・Terrain Tiles"
RED, YEL, WHITE, BLUE = (240, 90, 80), (255, 214, 64), (255, 255, 255), (120, 190, 255)
GREY, GREEN, SAND = (170, 180, 200), (110, 200, 110), (226, 196, 140)
RIVER = (70, 210, 255)
WARM = (255, 140, 70)

# 地点(経度, 緯度)。読み
PEAK, MIYANOURA, ANBO, ONOAIDA = (130.5045, 30.3361), (130.565, 30.425), (130.645, 30.31), (130.56, 30.235)
TANEGA = (130.98, 30.62)
KUROSHIO = [(127.0, 27.0), (128.8, 28.9), (130.0, 29.75), (130.9, 30.05), (131.8, 30.65), (133.5, 32.4)]
WIND = [(130.2, 29.95), (130.42, 30.22), (130.5, 30.33)]
ANBO_R = [(130.52, 30.33), (130.58, 30.32), (130.645, 30.31)]

SOUTH = (130.0, 29.8, 9.0, 0)
BOTH = (130.75, 30.48, 1.25, 0)
ISLAND = (130.53, 30.35, 0.55, 0)
ISLAND_T = (130.53, 30.30, 0.5, 40)
PEAKV = (130.51, 30.33, 0.18, 45)
BOTH_P = (130.75, 30.5, 1.0, 0)
ISLAND_P = (130.53, 30.35, 0.42, 0)
SOUTH_P = (130.3, 29.9, 6.0, 0)

S_A, S_B = (130.497, 30.465), (130.512, 30.228)
S_KW = dict(zmax=2300, zmin=-300, ends=[(0.04, "北の海"), (0.96, "南の海")])
S_LAB = [(0.55, 2050, "宮之浦岳 1,936m", YEL)]


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


def KURO(tag=""):
    return LINE(KUROSHIO, WARM, 14, id=f"kuro{tag}")


def CARD(big, sub=None, note=None, view=ISLAND, step=None, count=True, tr=None):
    d = dict(shot="card", big=big, sub=sub, note=note, view=view, step=step, count=count)
    if tr:
        d["tr"] = tr
    return d


def BARS(items, title=None, note=None, fmt="{}", step=None, tr=None):
    d = dict(shot="bars", items=items, title=title, note=note, fmt=fmt, step=step)
    if tr:
        d["tr"] = tr
    return d


def SLICE(step=None, tr=None, **kw):
    d = dict(shot="slice", a=S_A, b=S_B, step=step, title="屋久島を南北に切る", labels=S_LAB, **S_KW)
    d.update(kw)
    if tr:
        d["tr"] = tr
    return d


JMA, RINYA, MINE = "気象庁（平年値）", "林野庁", "自分で測った（国土地理院の標高）"
RAIN = BARS([("屋久島", 4651.7, BLUE), ("種子島", 2532.5, GREY), ("東京", 1598.2, GREY)], title="1年の雨の量（mm）", note=JMA, fmt="{:,}")
HEIGHT = BARS([("屋久島", 1931, YEL), ("種子島", 281, GREY)], title="いちばん高い所（m）", note=MINE, fmt="{:,}")

ANSWERS = [("海沿いでも、東京の約3倍の雨", "山の上は1年に8,000〜10,000mm"),
           ("隣の種子島と、大きさは同じ。高さは7倍", "雨は種子島の約1.8倍"),
           ("黒潮の湿った風が、山にぶつかって上る", "約10度冷えて、空気1m³から約10gの水"),
           ("1年に約23億m³の雨。東京ドーム約1,900杯", "短く急な川で、すぐ海へ"),
           ("島の電気の99.5%は、その雨の水力", "雨が、島の暮らしを動かしている")]

P = {}

# ---- 第1章 雨の島 -----------------------------------------------------------------------------------------
P["ch1"] = dict(title="第1章 雨の島", cta=False, lines=[
    dict(id="a1", text="鹿児島の南の海に浮かぶ、屋久島。", scene=MAP(SOUTH, step=0, view_to=ISLAND)),
    dict(id="a2", text="この島の雨は、1年に4,651.7mm。", scene=CARD("4,651.7mm", sub="屋久島の1年の雨（平年値）", note=JMA, step=0)),
    dict(id="a3", text="東京の、約3倍です。", scene=RAIN),
    dict(id="a4", text="しかも、これは海沿いで測った値です。"),
    dict(id="a5", text="山の上では、1年に8,000mmから10,000mmと推測されています。", scene=CARD("8,000〜10,000mm", sub="山の上の1年の雨（推測）", note=RINYA, view=ISLAND_T, step=0, count=False)),
    dict(id="a6", text="作家の林芙美子は、この島を「月のうち三十五日は雨」と書きました。", scene=MAP(ISLAND_T, step=0)),
    dict(id="a7", text="なぜ、屋久島だけ、こんなに雨が多いのか。", style="question", sub="東京の3倍の雨\n【屋久島だけ】なぜ多い", scene=MAP(ISLAND, step=0)),
    dict(id="a8", text="答えを先に言います。", section=True),
    dict(id="a9", text="海から、いきなり高い山が立ち上がっているからです。", scene=SLICE(step=0)),
    dict(id="a10", text="その山が、黒潮の上を渡ってきた湿った風を、空へ押し上げます。", scene=MAP(SOUTH, KURO("a"), step=0)),
    dict(id="a11", text="山の高さと坂は、国土地理院の標高データで、自分で測りました。", scene=MAP(ISLAND_T, PIN(PEAK, "宮之浦岳", id="p_pk"), step=0)),
    dict(id="a12", text="雨が水になる量は、空気の温度から、自分で計算します。"),
])

# ---- 第2章 隣の島と比べる ----------------------------------------------------------------------------------
P["ch2"] = dict(title="第2章 隣の島と比べる", cta=False, lines=[
    dict(id="b1", text="まず、隣の島と比べます。", scene=MAP(BOTH, PIN(PEAK, "屋久島", id="p_y"), PIN(TANEGA, "種子島", id="p_t"), step=1)),
    dict(id="b2", text="東に約18km。ロケットの打ち上げで知られる、種子島です。"),
    dict(id="b3", text="2つの島の大きさを、標高データで測りました。", scene=BARS([("屋久島", 506, BLUE), ("種子島", 456, GREY)], title="島の広さ（km²）", note=MINE, fmt="{:,}", step=1)),
    dict(id="b4", text="屋久島は約506km²。種子島は約456km²。ほとんど同じ大きさです。"),
    dict(id="b5", text="ところが、高さがまるで違います。", section=True, scene=HEIGHT),
    dict(id="b6", text="屋久島のいちばん高い所は、1,931m。種子島は、281m。"),
    dict(id="b7", text="屋久島は、種子島の約7倍の高さです。", scene=MAP(BOTH, step=1, view_to=(130.75, 30.45, 1.0, 40))),
    dict(id="b8", text="雨の量は、種子島が2,532.5mm。屋久島は、その約1.8倍です。", scene=RAIN),
    dict(id="b9", text="同じ海の、同じ風の中にある、ほぼ同じ大きさの島。", scene=MAP(BOTH, step=1)),
    dict(id="b10", text="違うのは、高さです。", scene=CARD("高さが7倍", sub="屋久島と種子島", note=MINE, view=BOTH, step=1, count=False)),
    dict(id="b11", text="屋久島には、標高1,000mより高い土地が、約124km²あります。", scene=MAP(ISLAND_T, PIN(PEAK, "宮之浦岳", id="p_pk2"), step=1)),
    dict(id="b12", text="島のおよそ4分の1が、1,000mより上なのです。"),
])

# ---- 第3章 空気を押し上げる --------------------------------------------------------------------------------
P["ch3"] = dict(title="第3章 空気を押し上げる", cta=False, lines=[
    dict(id="c1", text="では、高い山が、なぜ雨を降らせるのか。", scene=MAP(SOUTH, KURO("c"), step=2, tr="zoom")),
    dict(id="c2", text="屋久島のすぐ南を、黒潮が流れています。", scene=MAP(SOUTH, KURO("c2"), LABEL((128.8, 28.4), "黒潮", 60, WARM), step=2)),
    dict(id="c3", text="南から流れてくる、あたたかい海の流れです。"),
    dict(id="c4", text="その上を渡る風は、水をたっぷり含んで、湿っています。", scene=MAP(ISLAND, LINE(WIND, WHITE, 10, id="wind_c"), step=2)),
    dict(id="c5", text="その風が、島にぶつかります。", section=True, scene=SLICE(step=2)),
    dict(id="c6", text="いちばん高い所から海岸までは、まっすぐ9.8km。そのあいだに、1,931m上ります。", scene=CARD("9.8kmで1,931m", sub="宮之浦岳から海岸まで", note=MINE, view=PEAKV, step=2, count=False)),
    dict(id="c7", text="風は、この坂を、上へ上へと押し上げられます。"),
    dict(id="c8", text="空気は、上るほど冷えます。雲の中では、100m上るごとに約0.5度。", scene=CARD("約10度", sub="1,900m上ると冷える温度", note="自分で計算（100mごとに約0.5度）", view=PEAKV, step=2, count=False)),
    dict(id="c9", text="1,900m上れば、約10度冷えます。"),
    dict(id="c10", text="ここで、空気が持てる水の量を見ます。", section=True, scene=BARS([("25度の空気", 23, BLUE), ("15度の空気", 13, YEL)], title="空気1m³が持てる水（g）", note="飽和水蒸気量", fmt="{}", step=2)),
    dict(id="c11", text="25度の空気1m³は、約23gの水を持てます。15度では、約13gです。"),
    dict(id="c12", text="持ちきれなくなった約10gが、水になって出てきます。"),
    dict(id="c13", text="冷たいコップの外に、水滴がつくのと同じです。", scene=CARD("約10g", sub="空気1m³から出てくる水", note="自分で計算", view=PEAKV, step=2, count=False)),
    dict(id="c14", text="山が空気を押し上げ、冷やし、雨をしぼり出す。これが、屋久島の雨です。", scene=SLICE(step=2)),
])

# ---- 第4章 雨の行方 ---------------------------------------------------------------------------------------
P["ch4"] = dict(title="第4章 雨の行方", cta=False, lines=[
    dict(id="d1", text="では、降った雨は、どこへ行くのか。", scene=MAP(ISLAND, step=3, tr="zoom")),
    dict(id="d2", text="島に降る雨の量を、計算してみます。", section=True),
    dict(id="d3", text="島の広さ、約506km²に、海沿いの雨、4.65mを掛けます。", scene=CARD("約23億m³", sub="1年に島に降る雨（少なく見積もって）", note="自分で計算", step=3, count=False)),
    dict(id="d4", text="少なく見積もっても、1年に約23億m³。東京ドーム、約1,900杯分です。"),
    dict(id="d5", text="山の上はもっと降るので、本当はさらに多くなります。"),
    dict(id="d6", text="この水は、短く急な川で、海へ下ります。", section=True, scene=MAP(ISLAND_T, LINE(ANBO_R, RIVER, 10, id="r_anbo"), PIN(ANBO, "安房", id="p_an"), step=3)),
    dict(id="d7", text="山のてっぺんから海まで、10kmほどで、2,000m近く下るのです。", scene=SLICE(step=3)),
    dict(id="d8", text="大雨が降ると、川の水は、すぐに増えます。"),
    dict(id="d9", text="そして、この急な水の流れが、島の暮らしを支えています。", section=True, scene=MAP(ISLAND, LINE(ANBO_R, RIVER, 10, id="r_anbo2"), step=3)),
    dict(id="d10", text="島で使う電気の、99.5%は、水力発電です。", scene=CARD("99.5%", sub="島で使う電気のうち、水力発電の分", note="環境省", step=3, count=False)),
    dict(id="d11", text="山に降った雨が、坂を下る力で、電気を起こしているのです。"),
    dict(id="d12", text="雨の多さと、坂の急さ。その2つがそろった島だから、できることです。", scene=MAP(ISLAND_T, step=3)),
])

# ---- 第5章 答え -------------------------------------------------------------------------------------------
_CV = [(ISLAND, (130.53, 30.35, 0.5, 20)), (BOTH, (130.75, 30.48, 1.1, 25)), (SOUTH, (130.2, 29.9, 7.0, 20)),
       (ISLAND_T, (130.53, 30.30, 0.45, 45)), (PEAKV, (130.51, 30.33, 0.16, 50))]
CARDS_N = lambda n: dict(shot="cards", items=ANSWERS, n=n, view=_CV[n - 1][0], view_to=_CV[n - 1][1], step=4)  # noqa: E731
P["ch5"] = dict(title="第5章 答え", cta=True, lines=[
    dict(id="e1", text="まとめます。", section=True, scene=CARDS_N(1)),
    dict(id="e2", text="1つ目。屋久島は、海沿いでも、東京の約3倍の雨。山の上は、1年に8,000から10,000mmです。"),
    dict(id="e3", text="2つ目。隣の種子島と、大きさはほぼ同じ。でも高さは約7倍で、雨は約1.8倍です。", scene=CARDS_N(2)),
    dict(id="e4", text="3つ目。黒潮の湿った風が、山にぶつかって上る。約10度冷えて、空気1m³から約10gの水が出てきます。", scene=CARDS_N(3)),
    dict(id="e5", text="4つ目。1年に約23億m³の雨。東京ドーム約1,900杯分が、短く急な川で、すぐ海へ下ります。", scene=CARDS_N(4)),
    dict(id="e6", text="5つ目。島の電気の99.5%は、その雨を使った水力発電です。", scene=CARDS_N(5)),
    dict(id="e7", text="屋久島に雨が多いのは、島が雨を待っているからではありません。", scene=MAP(ISLAND_T, step=4)),
    dict(id="e8", text="海の上にそびえる山が、空気から、雨をしぼり出しているのです。", scene=SLICE(step=4)),
    dict(id="e9", text="次に、冷たいコップに水滴がついたら、屋久島の山を思い出してください。", scene=MAP(ISLAND, step=4, view_to=(130.53, 30.35, 0.7, 20))),
])

# ---- ショート ---------------------------------------------------------------------------------------------
P["s1"] = dict(title="屋久島の雨は、東京の約3倍。山の上はもっと降る", lines=[
    dict(id="k1", text="屋久島の雨は、1年に4,651.7mm。東京の、約3倍です。", scene=MAP(ISLAND_P)),
    dict(id="k2", text="しかも、これは海沿いで測った値。", scene=RAIN),
    dict(id="k3", text="山の上では、1年に8,000mmから10,000mmと推測されています。", scene=CARD("8,000〜10,000mm", sub="山の上の1年の雨（推測）", view=ISLAND_P, count=False)),
    dict(id="k4", text="理由は、海からいきなり立ち上がる、高い山です。", scene=SLICE()),
    dict(id="k5", text="いちばん高い所は約1,930m。海岸から、まっすぐ10km足らずで上ります。"),
    dict(id="k6", text="その山が、湿った風を押し上げて、雨をしぼり出しているのです。", scene=MAP(ISLAND_P, tr="whip")),
])

P["s2"] = dict(title="同じ大きさの隣の島。雨の量は1.8倍ちがう", lines=[
    dict(id="m1", text="屋久島と、その東の種子島。", scene=MAP(BOTH_P, PIN(PEAK, "屋久島", id="p_my"), PIN(TANEGA, "種子島", id="p_mt"))),
    dict(id="m2", text="標高データで測ると、広さは約506km²と約456km²。ほとんど同じです。", scene=BARS([("屋久島", 506, BLUE), ("種子島", 456, GREY)], title="島の広さ（km²）", fmt="{:,}")),
    dict(id="m3", text="ところが雨は、屋久島が4,651.7mm、種子島は2,532.5mm。", scene=RAIN),
    dict(id="m4", text="違いは、高さ。屋久島は1,931m、種子島は281m。約7倍です。", scene=HEIGHT),
    dict(id="m5", text="同じ海の、同じ風の中でも、高い山のある島にだけ、雨が集まるのです。", scene=MAP(BOTH_P, tr="whip")),
])

P["s3"] = dict(title="空気1m³から、約10gの水がしぼり出される", lines=[
    dict(id="n1", text="屋久島の山に、湿った風がぶつかります。", scene=SLICE()),
    dict(id="n2", text="風は坂を押し上げられ、1,900m上ると、約10度冷えます。", scene=CARD("約10度", sub="1,900m上ると冷える温度", view=ISLAND_P, count=False)),
    dict(id="n3", text="25度の空気1m³は、約23gの水を持てます。15度では、約13gです。", scene=BARS([("25度の空気", 23, BLUE), ("15度の空気", 13, YEL)], title="空気1m³が持てる水（g）", fmt="{}")),
    dict(id="n4", text="持ちきれなくなった約10gが、雨になって出てくるのです。"),
    dict(id="n5", text="冷たいコップの外に、水滴がつくのと同じしくみです。", scene=CARD("約10g", sub="空気1m³から出てくる水", view=ISLAND_P, count=False)),
    dict(id="n6", text="屋久島の山は、空気から雨をしぼり出す装置なのです。", scene=MAP(ISLAND_P, tr="whip")),
])

P["s4"] = dict(title="屋久島に降る雨は、1年で東京ドーム約1,900杯", lines=[
    dict(id="q1", text="屋久島に、1年にどれだけ雨が降るのか、計算してみます。", scene=MAP(ISLAND_P)),
    dict(id="q2", text="島の広さ、約506km²に、海沿いの雨、4.65mを掛けます。"),
    dict(id="q3", text="少なく見積もっても、約23億m³。東京ドーム、約1,900杯分です。", scene=CARD("約23億m³", sub="1年に島に降る雨（少なく見積もって）", view=ISLAND_P, count=False)),
    dict(id="q4", text="この水が、10kmほどで2,000m近く下る、急な川で海へ向かいます。", scene=SLICE()),
    dict(id="q5", text="その力で、島で使う電気の99.5%を、水力発電でまかなっています。", scene=CARD("99.5%", sub="島の電気のうち水力の分", view=ISLAND_P, count=False)),
    dict(id="q6", text="屋久島の電気は、雨でできているのです。", scene=MAP(ISLAND_P, tr="whip")),
])

P["s5"] = dict(title="屋久島の電気は、99.5%が雨の水力", lines=[
    dict(id="r1", text="屋久島で使う電気の、99.5%は水力発電です。", scene=MAP(ISLAND_P, LINE(ANBO_R, RIVER, 10, id="r_ra"))),
    dict(id="r2", text="燃料を運んでこなくても、電気がほぼまかなえる島です。", scene=CARD("99.5%", sub="島の電気のうち水力の分", view=ISLAND_P, count=False)),
    dict(id="r3", text="理由は、雨と坂。雨は1年に4,651.7mm。東京の約3倍です。", scene=RAIN),
    dict(id="r4", text="その雨が、1,900mを超える山から、10kmほどで海まで下ります。", scene=SLICE()),
    dict(id="r5", text="たっぷりの水が、急な坂を下る。発電に、これ以上ない条件です。"),
    dict(id="r6", text="屋久島の明かりは、山に降った雨がともしているのです。", scene=MAP(ISLAND_P, tr="whip")),
])

# ---- 読み ------------------------------------------------------------------------------------------------
YOMI = [("高い山です", "たかいやまです"), ("海へ下ります", "うみへくだります"), ("海まで下ります", "うみまでくだります"), ("4,651.7mm", "四千六百五十一点七ミリ"), ("2,532.5mm", "二千五百三十二点五ミリ"), ("8,000mmから10,000mm", "八千ミリから一万ミリ"),
        ("8,000から10,000mm", "八千から一万ミリ"), ("約506km²", "約五百六平方キロメートル"), ("約456km²", "約四百五十六平方キロメートル"),
        ("約124km²", "約百二十四平方キロメートル"), ("1,931m", "千九百三十一メートル"), ("281m", "二百八十一メートル"),
        ("約1,930m", "約千九百三十メートル"), ("1,900mを超える", "千九百メートルをこえる"), ("1,900m", "千九百メートル"), ("1,000m", "千メートル"),
        ("2,000m", "二千メートル"), ("100m", "百メートル"), ("9.8km", "九点八キロ"), ("約18km", "約十八キロ"), ("10km", "十キロ"), ("4.65m", "四点六五メートル"),
        ("約23億m³", "約二十三億立方メートル"), ("約1,900杯分", "約千九百杯分"), ("1m³", "一立方メートル"), ("約23g", "約二十三グラム"), ("約13g", "約十三グラム"),
        ("約10g", "約十グラム"), ("約0.5度", "約れいてんご度"), ("約10度", "約十度"), ("25度", "にじゅうご度"), ("15度", "じゅうご度"), ("99.5%", "九十九点五パーセント"),
        ("約1.8倍", "約一点八倍"), ("1.8倍", "一点八倍"), ("約3倍", "約三倍"), ("約7倍", "約七倍"), ("4分の1", "よんぶんのいち"),
        ("1つ目", "ひとつめ"), ("2つ目", "ふたつめ"), ("3つ目", "みっつめ"), ("4つ目", "よっつめ"), ("5つ目", "いつつめ"), ("2つ", "ふたつ"), ("1年", "いちねん"),
        ("月のうち三十五日は雨", "つきのうち、さんじゅうごにちは、あめ"), ("林芙美子", "はやしふみこ"), ("屋久島", "やくしま"), ("種子島", "たねがしま"),
        ("宮之浦岳", "みやのうらだけ"), ("安房", "あんぼう"), ("黒潮", "くろしお"), ("国土地理院", "こくどちりいん"), ("水滴", "すいてき"),
        ("東京ドーム", "とうきょうドーム"), ("海沿い", "うみぞい"), ("湿った", "しめった"), ("装置", "そうち"), ("明かり", "あかり")]


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
