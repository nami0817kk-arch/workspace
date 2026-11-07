"""ハワイの水はどこから(地理): 本編 5 章とショート 5 本の台本と画面。ch1〜ch5・s1〜s5 の ep.py がここから読む。
数字と出典は sim/facts.md(NWS・USGS・ハワイ大学 Rainfall Atlas・ホノルル水道局・州の統計書)。島の高さは sim/fetch.py。
画面は 2〜3 行ごとに種類を変える(立体の地図・島の断面・地下の図・棒・数字)。"""
CREDIT = "地図: NASA・Terrain Tiles"
RED, YEL, WHITE, BLUE = (240, 90, 80), (255, 214, 64), (255, 255, 255), (120, 190, 255)
GREY, GREEN, SAND = (170, 180, 200), (110, 200, 110), (226, 196, 140)

ISLANDS = (-157.5, 20.4, 7.5, 30)
PACIFIC = (-140, 30, 60, 10)
KAUAI = (-159.52, 21.97, 1.3, 35)
BIG = (-155.5, 19.45, 2.3, 35)
OAHU = (-157.98, 21.47, 1.0, 35)

WAIALEALE, MANA, HONOLULU, SF = (-159.498, 22.074), (-159.78, 22.04), (-157.92, 21.32), (-122.42, 37.77)
MAUNAKEA, MAUNALOA, AKAKA, HANALEI = (-155.468, 19.821), (-155.603, 19.475), (-155.153, 19.854), (-159.50, 22.20)
K_A, K_B = (-159.25, 22.25), (-159.75, 21.92)       # カウアイ島を北東→南西に(ワイアレアレの近く)
B_A, B_B = (-155.0, 20.15), (-156.0, 19.45)          # ハワイ島を北東→南西に(マウナケアを通る)


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


def ARROW(a, b, color=WHITE, width=12, id=None, at=0.0):
    return dict(kind="arrow", a=a, b=b, color=color, width=width, id=id or f"arr_{a}_{b}", at=at)


def LINE(pts, color=YEL, width=6, id=None, at=0.0):
    return dict(kind="route", pts=pts, color=color, width=width, id=id or f"route_{pts[0]}", at=at)


def WIND(lon0, lat0, n=4, step=0.35, length=0.9, id="w"):
    """北東から吹く風の矢印を、(lon0, lat0) のあたりに n 本。"""
    return [ARROW((lon0 + length + i * step * 0.3, lat0 + length * 0.7 - i * step), (lon0 + i * step * 0.3, lat0 - i * step),
                  color=(225, 240, 255), width=10, id=f"{id}{i}", at=0.1 * i) for i in range(n)]


def CARD(big, sub=None, note=None, view=ISLANDS, step=None, count=True, tr=None):
    d = dict(shot="card", big=big, sub=sub, note=note, view=view, step=step, count=count)
    if tr:
        d["tr"] = tr
    return d


def SLICE(a, b, step=None, tr=None, **kw):
    d = dict(shot="slice", a=a, b=b, step=step, **kw)
    if tr:
        d["tr"] = tr
    return d


def LENS(step=None, tr=None, **kw):
    d = dict(shot="lens", step=step, **kw)
    if tr:
        d["tr"] = tr
    return d


def BARS(items, title=None, note=None, fmt="{}", step=None, tr=None):
    d = dict(shot="bars", items=items, title=title, note=note, fmt=fmt, step=step)
    if tr:
        d["tr"] = tr
    return d


ANSWERS = [("海の真ん中に、1年に1万mm降る山がある", "同じ島の反対側は19分の1"),
           ("水を運ぶのは、北東から吹く貿易風", "山にぶつかって冷え、雲と雨になる"),
           ("4,000mの山頂は乾いている", "およそ2,000mの雲のふたの下で雨が落ちる"),
           ("雨は岩にしみこみ、海水の上に浮く", "1m上なら、海面の下40mまで真水"),
           ("オアフ島の水道は、ほぼ全部が地下水", "山の一滴が井戸に届くまで、長いと25年")]
K_SLICE = dict(zmax=2400, zmin=-1200, ends=[(0.03, "北東（風上）"), (0.95, "南西（風下）")])
B_SLICE = dict(zmax=5200, zmin=-1500, ends=[(0.03, "北東（風上）"), (0.95, "南西（風下）")])

P = {}

# ---- 第1章 雨の島 ---------------------------------------------------------------------------------------
P["ch1"] = dict(title="第1章 雨の島", cta=False, lines=[
    dict(id="c1", text="海の真ん中のハワイに、1年に約1万mmの雨が降る山があります。", scene=MAP(KAUAI, PIN(WAIALEALE, "ワイアレアレ山"), step=0)),
    dict(id="c2", text="日本の平均の、およそ6倍です。", scene=BARS([("ワイアレアレ山", 10000, BLUE), ("日本の平均", 1700, GREY)], title="1年に降る雨（mm）", fmt="{:,}", step=0)),
    dict(id="c3", text="ところが、同じ島の反対側のマナは、たったの514mm。", scene=MAP(KAUAI, PIN(WAIALEALE, "ワイアレアレ山 約1万mm", id="p_w2"), PIN(MANA, "マナ 514mm", id="p_m", at=0.2), step=0, tr="whip")),
    dict(id="c4", text="19分の1しかありません。"),
    dict(id="c5", text="一番近い大陸のアメリカまでは、3,857km。", scene=MAP(PACIFIC, LINE([HONOLULU, SF], id="r_sf"), PIN(HONOLULU, "ホノルル"), PIN(SF, "サンフランシスコ", at=0.4),
         LABEL((-140, 32.5), "3,857km", 64, YEL, on="3,857km"), step=0)),
    dict(id="c6", text="大陸から川が流れてくることもない、海の真ん中の島です。"),
    dict(id="c7", text="この雨は、どこから来て、どこへ消えるのか。", style="question", sub="海の真ん中の雨は\n【どこから】来るのか", scene=MAP(ISLANDS, step=0, view_to=(-157.2, 20.6, 6.0, 35))),
    dict(id="c8", text="答えを先に言います。", section=True),
    dict(id="c9", text="水を運んでくるのは、海の上を吹く貿易風です。", scene=MAP(ISLANDS, *WIND(-156.6, 22.3, n=4, step=0.6, length=1.4), step=0, tr="zoom")),
    dict(id="c10", text="山が、その風から雨をしぼり取ります。", scene=SLICE(K_A, K_B, wind=True, wet=0.55, step=0, title="カウアイ島を切る", **K_SLICE)),
    dict(id="c11", text="そして雨は岩にしみこみ、海水の上に浮かぶ地下水になります。", scene=LENS(step=0, title="島の地下")),
    dict(id="c12", text="島の高さのデータで、山を切って確かめます。", scene=SLICE(B_A, B_B, step=0, title="ハワイ島を切る", **B_SLICE)),
])

# ---- 第2章 風 ------------------------------------------------------------------------------------------
P["ch2"] = dict(title="第2章 風", cta=False, lines=[
    dict(id="d1", text="ハワイには、1年の大半、北東から風が吹いています。", scene=MAP(ISLANDS, *WIND(-156.6, 22.3, n=4, step=0.6, length=1.4, id="wd"), step=1, tr="zoom")),
    dict(id="d2", text="夏は、8割から9割の時間、この風が吹きます。", scene=CARD("8〜9割", sub="夏に北東の風が吹く時間", note="WRCC「Climate of Hawaii」", step=1, count=False)),
    dict(id="d3", text="貿易風と呼ばれる風です。"),
    dict(id="d4", text="風は、何千kmも海の上を渡ってくるあいだに、水蒸気をたっぷり含みます。", scene=MAP(PACIFIC, *[ARROW((-128 - i * 4, 35 - i * 3), (-146 - i * 3, 26.5 - i * 2.4), color=(225, 240, 255), width=12, id=f"wp{i}", at=0.15 * i) for i in range(4)],
         PIN(HONOLULU, "ハワイ"), step=1, tr="whip")),
    dict(id="d5", text="その風が、島の山にぶつかります。", scene=SLICE(K_A, K_B, wind=True, step=1, title="カウアイ島を切る", **K_SLICE)),
    dict(id="d6", text="空気は斜面を押し上げられて、冷えます。"),
    dict(id="d7", text="冷えると、水蒸気が雲になり、雨になって落ちるのです。", scene=SLICE(K_A, K_B, wind=True, wet=0.55, step=1, title="カウアイ島を切る", **K_SLICE)),
    dict(id="d8", text="だから、風が当たる北東側は、緑の森です。", section=True, scene=MAP(KAUAI, LABEL((-159.38, 22.2), "北東 緑の森", 48, GREEN), step=1, tr="zoom")),
    dict(id="d9", text="山を越えた南西側には、雨を落としきった乾いた風しか来ません。", scene=MAP(KAUAI, LABEL((-159.38, 22.2), "北東 緑の森", 48, GREEN, id="l_g2"), LABEL((-159.7, 21.95), "南西 乾いた土", 48, SAND), step=1)),
    dict(id="d10", text="衛星写真で見ても、島の色が、東と西で違います。", scene=MAP(ISLANDS, step=1, view_to=(-157.0, 20.5, 5.5, 30))),
])

# ---- 第3章 山の高さ -------------------------------------------------------------------------------------
P["ch3"] = dict(title="第3章 山の高さ", cta=False, lines=[
    dict(id="e1", text="では、山が高いほど、雨は多いのでしょうか。", scene=MAP(BIG, step=2, tr="zoom")),
    dict(id="e2", text="ハワイ島には、4,000mを超える山が2つあります。", scene=MAP(BIG, PIN(MAUNAKEA, "マウナケア"), PIN(MAUNALOA, "マウナロア", at=0.3), step=2)),
    dict(id="e3", text="ところが、その山頂のあたりは、1年に204mmしか降りません。", scene=CARD("204mm", sub="マウナケア山頂あたりの1年の雨", note="ハワイ大学 Rainfall Atlas", view=BIG, step=2)),
    dict(id="e4", text="ハワイで、一番雨の少ない場所です。"),
    dict(id="e5", text="理由は、およそ2,000mの高さにある、雲のふたです。", section=True, scene=SLICE(B_A, B_B, inv=2000, step=2, title="ハワイ島を切る", **B_SLICE)),
    dict(id="e6", text="その高さでは、上の空気のほうが暖かく、下から空気が上がっていけません。"),
    dict(id="e7", text="雲はふたの下に押さえられ、山の中腹で雨を落とします。", scene=SLICE(B_A, B_B, inv=2000, wind=True, wet=0.42, step=2, title="ハワイ島を切る", **B_SLICE)),
    dict(id="e8", text="ふたより上は、湿り気が4割もない、乾いた空気です。", scene=SLICE(B_A, B_B, inv=2000, wind=True, wet=0.42, step=2, title="ハワイ島を切る",
         labels=[(0.47, 4700, "乾いた山頂", SAND)], **B_SLICE)),
    dict(id="e9", text="一方、カウアイ島のワイアレアレ山は、高さおよそ1,500m。", scene=SLICE(K_A, K_B, inv=2000, step=2, title="カウアイ島を切る", **K_SLICE)),
    dict(id="e10", text="山頂まで、すっぽり雲のふたの下に収まっています。", scene=SLICE(K_A, K_B, inv=2000, wind=True, wet=0.55, step=2, title="カウアイ島を切る", **K_SLICE)),
    dict(id="e11", text="だから山頂まで雲がかかり、雨が降り続けるのです。", scene=MAP(KAUAI, PIN(WAIALEALE, "ワイアレアレ山", id="p_w3"), step=2, tr="whip")),
])

# ---- 第4章 地下の水 -------------------------------------------------------------------------------------
P["ch4"] = dict(title="第4章 地下の水", cta=False, lines=[
    dict(id="f1", text="降った雨は、どこへ行くのか。", scene=MAP(ISLANDS, step=3, tr="zoom")),
    dict(id="f2", text="ハワイ州全体には、1日に約8,000万立方mの雨が降ります。", scene=CARD("8,000万立方m", sub="ハワイ州に1日に降る雨", note="USGS", step=3)),
    dict(id="f3", text="一部は、川になって海へ流れます。", scene=MAP(KAUAI, PIN(HANALEI, "ハナレイ川"), step=3, tr="whip")),
    dict(id="f4", text="カウアイ島のハナレイ川は、1日に49万立方m。"),
    dict(id="f5", text="でも、もっと多くが、火山の岩にしみこみます。", section=True, scene=LENS(step=3, title="島の地下")),
    dict(id="f6", text="しみこんだ真水は、海水より軽いので、海水の上に浮きます。"),
    dict(id="f7", text="島の地下に、レンズの形をした真水のかたまりができるのです。"),
    dict(id="f8", text="地下の水面が海より1m高ければ、真水は海面の下40mまで届きます。", scene=LENS(step=3, title="島の地下", grow=False,
         labels=[("海面より1m上", (0.5, 0.31), YEL), ("海面の下 40m", (0.5, 0.9), YEL)])),
    dict(id="f9", text="オアフ島の水道は、ほぼ100%がこの地下水です。", scene=MAP(OAHU, PIN(HONOLULU, "ホノルル"), step=3, tr="zoom")),
    dict(id="f10", text="1日に汲む量は、約53万立方m。", scene=BARS([("オアフの水道", 53, BLUE), ("ハナレイ川", 49, GREEN)], title="1日の水の量（万立方m）", fmt="{}", step=3)),
    dict(id="f11", text="ハナレイ川1本の流れと、ほぼ同じです。"),
    dict(id="f12", text="山に降った一滴が井戸に届くまで、長いと25年かかります。", scene=CARD("25年", sub="山の一滴が地下水になるまで", note="ホノルル水道局", view=OAHU, step=3, count=False)),
])

# ---- 第5章 答え -----------------------------------------------------------------------------------------
CARDS_N = lambda n: dict(shot="cards", items=ANSWERS, n=n, view=ISLANDS, step=4)  # noqa: E731
P["ch5"] = dict(title="第5章 答え", cta=True, lines=[
    dict(id="g1", text="川と滝も、この雨が作りました。", scene=MAP(BIG, PIN(AKAKA, "アカカの滝"), step=4, tr="zoom")),
    dict(id="g2", text="ハワイ州には、1年中流れる川が376本あります。", scene=CARD("376本", sub="1年中流れる川", note="ハワイ州 水資源委員会", step=4)),
    dict(id="g3", text="ハワイ島のアカカの滝は、高さ135m。", scene=MAP(BIG, PIN(AKAKA, "アカカの滝 135m", id="p_ak2"), step=4)),
    dict(id="g4", text="まとめます。", section=True, scene=CARDS_N(1)),
    dict(id="g5", text="1つ目。海の真ん中に、1年に1万mm降る山がある。同じ島の反対側は19分の1。"),
    dict(id="g6", text="2つ目。水を運ぶのは、北東から吹く貿易風。山にぶつかって、冷えて雨になる。", scene=CARDS_N(2)),
    dict(id="g7", text="3つ目。4,000mの山頂は乾いている。雲は2,000mのふたの下で雨を落とす。", scene=CARDS_N(3)),
    dict(id="g8", text="4つ目。雨は岩にしみこみ、海水の上に浮く。1m上なら、40m下まで真水。", scene=CARDS_N(4)),
    dict(id="g9", text="5つ目。オアフ島の水道は、ほぼ全部が地下水。一滴が届くまで、長いと25年。", scene=CARDS_N(5)),
    dict(id="g10", text="ハワイの水は、全部が空から来ています。風と山と岩が、海の真ん中に水をためていました。", scene=MAP(ISLANDS, *WIND(-156.6, 22.3, n=4, step=0.6, length=1.4, id="wg"), step=4, view_to=(-157.2, 20.6, 6.5, 35))),
    dict(id="g11", text="次に島の写真を見たら、緑の側と茶色の側を探してください。そこに、風の通り道があります。", scene=MAP(KAUAI, step=4)),
])

# ---- ショート -------------------------------------------------------------------------------------------
ISLANDS_P = (-157.6, 20.6, 4.5, 30)
KAUAI_P = (-159.52, 22.06, 0.8, 35)
BIG_P = (-155.5, 19.6, 1.5, 35)
OAHU_P = (-157.98, 21.47, 0.6, 35)

P["s1"] = dict(title="同じ島なのに、雨の量が19倍ちがう", lines=[
    dict(id="a1", text="ハワイのカウアイ島では、同じ島なのに、雨の量が19倍ちがいます。", scene=MAP(KAUAI_P, PIN(WAIALEALE, "ワイアレアレ山"), PIN(MANA, "マナ", at=0.3))),
    dict(id="a2", text="山のワイアレアレは、1年に約1万mm。西のマナは514mm。", scene=BARS([("ワイアレアレ山", 10000, BLUE), ("マナ", 514, SAND)], title="1年に降る雨（mm）", fmt="{:,}")),
    dict(id="a3", text="島には、1年の大半、北東から風が吹いています。", scene=MAP(ISLANDS_P, *WIND(-157.0, 22.2, n=3, step=0.5, length=1.0))),
    dict(id="a4", text="風は山にぶつかって押し上げられ、冷えて雨を落とします。", scene=SLICE(K_A, K_B, wind=True, wet=0.55, title="カウアイ島を切る", **K_SLICE)),
    dict(id="a5", text="山を越えた西側には、乾いた風しか来ないのです。"),
    dict(id="a6", text="衛星写真でも、北東は緑、南西は茶色です。", scene=MAP(KAUAI_P, LABEL((-159.42, 22.18), "緑", 60, GREEN), LABEL((-159.68, 21.97), "茶色", 60, SAND), tr="whip")),
])

P["s2"] = dict(title="一番近い大陸まで3,857km。ハワイの水はどこから", lines=[
    dict(id="b1", text="ハワイから一番近い大陸まで、3,857km。水はどこから来るのでしょう。", scene=MAP((-140, 30, 40, 10), LINE([HONOLULU, SF], id="r_b"), PIN(HONOLULU, "ハワイ"), PIN(SF, "サンフランシスコ", at=0.3))),
    dict(id="b2", text="大陸から川が流れてくることは、ありません。"),
    dict(id="b3", text="水を運ぶのは、海の上を何千kmも渡ってくる貿易風です。", scene=MAP((-145, 28, 40, 10), *[ARROW((-132 - i * 3, 33 - i * 2.5), (-150 - i * 2, 25 - i * 2), color=(225, 240, 255), width=12, id=f"wb{i}", at=0.15 * i) for i in range(3)])),
    dict(id="b4", text="風は、たっぷり水蒸気を含んで、島の山にぶつかります。", scene=SLICE(K_A, K_B, wind=True, wet=0.55, title="カウアイ島を切る", **K_SLICE)),
    dict(id="b5", text="そうして、山には1年に約1万mmの雨が降ります。", scene=CARD("約1万mm", sub="ワイアレアレ山の1年の雨", note="日本の平均の約6倍", view=KAUAI_P, count=False)),
    dict(id="b6", text="ハワイの水は、全部が空から来ているのです。"),
])

P["s3"] = dict(title="4,000mの山頂は、ハワイで一番雨が少ない", lines=[
    dict(id="h1", text="ハワイ島の4,000mを超える山頂は、ハワイで一番雨が少ない場所です。", scene=MAP(BIG_P, PIN(MAUNAKEA, "マウナケア"))),
    dict(id="h2", text="1年に204mm。東京の8分の1ほどです。", scene=BARS([("東京", 1598, BLUE), ("マウナケア山頂あたり", 204, SAND)], title="1年に降る雨（mm）", fmt="{:,}")),
    dict(id="h3", text="理由は、およそ2,000mの高さにある、雲のふたです。", scene=SLICE(B_A, B_B, inv=2000, title="ハワイ島を切る", **B_SLICE)),
    dict(id="h4", text="上の空気のほうが暖かく、下からの空気が上がれません。"),
    dict(id="h5", text="雲はふたの下に押さえられ、山の中腹で雨を落とします。", scene=SLICE(B_A, B_B, inv=2000, wind=True, wet=0.42, title="ハワイ島を切る", **B_SLICE)),
    dict(id="h6", text="だから、山頂は乾いた空気の中にあるのです。"),
])

P["s4"] = dict(title="島の地下では、真水が海水の上に浮いている", lines=[
    dict(id="k1", text="海に囲まれた島の地下では、真水が海水の上に浮いています。", scene=LENS(title="島の地下")),
    dict(id="k2", text="雨は、火山の岩にしみこみます。"),
    dict(id="k3", text="真水は海水より、40分の1ほど軽いのです。"),
    dict(id="k4", text="だから、レンズの形をした真水のかたまりが、海水の上にできます。", scene=LENS(title="島の地下", grow=False)),
    dict(id="k5", text="地下の水面が海より1m高ければ、真水は海面の下40mまで届きます。", scene=LENS(title="島の地下", grow=False,
         labels=[("海面より1m上", (0.5, 0.33), YEL), ("海面の下 40m", (0.5, 0.92), YEL)])),
    dict(id="k6", text="ハワイの家の水の、約99%が、この地下水です。", scene=CARD("約99%", sub="ハワイの家庭の水のうち地下水", note="USGS", view=OAHU_P, count=False)),
])

P["s5"] = dict(title="ホノルルの水道は、ほぼ100%が地下水", lines=[
    dict(id="m1", text="オアフ島の水道は、ほぼ100%が地下水です。", scene=MAP(OAHU_P, PIN(HONOLULU, "ホノルル"))),
    dict(id="m2", text="1日に汲む量は、約53万立方m。", scene=CARD("53万立方m", sub="オアフ島で1日に汲む地下水", note="ホノルル水道局（2026年）", view=OAHU_P, count=False)),
    dict(id="m3", text="水は、島の山に降った雨です。", scene=MAP(OAHU_P, *WIND(-157.6, 21.75, n=3, step=0.12, length=0.3, id="wm"))),
    dict(id="m4", text="雨は岩にしみこんで、海水の上に浮く真水になります。", scene=LENS(title="島の地下")),
    dict(id="m5", text="山に降った一滴が井戸に届くまで、長いと25年。", scene=CARD("25年", sub="山の一滴が地下水になるまで", view=OAHU_P, count=False)),
    dict(id="m6", text="いま飲んでいる水は、四半世紀前の雨かもしれないのです。"),
])

# ---- 読み ------------------------------------------------------------------------------------------------
YOMI = [("8,000万立方m", "ハッセンマンリッポウメートル"), ("53万立方m", "ゴジュウサンマンリッポウメートル"), ("49万立方m", "ヨンジュウキュウマンリッポウメートル"),
        ("1万mm", "イチマンミリ"), ("514mm", "ゴヒャクジュウヨンミリ"), ("204mm", "ニヒャクヨンミリ"), ("3,857km", "サンゼンハッピャクゴジュウナナキロメートル"),
        ("4,000m", "ヨンセンメートル"), ("2,000m", "ニセンメートル"), ("1,500m", "センゴヒャクメートル"), ("135m", "ヒャクサンジュウゴメートル"),
        ("40m下", "ヨンジュウメートルした"), ("1m上", "イチメートルうえ"), ("40m", "ヨンジュウメートル"), ("1m", "イチメートル"), ("19分の1", "じゅうきゅうぶんのいち"), ("40分の1", "よんじゅうぶんのいち"), ("8分の1", "ハチブンノイチ"),
        ("19倍", "ジュウキュウバイ"), ("6倍", "ロクバイ"), ("376本", "サンビャクナナジュウロッポン"), ("100%", "ヒャクパーセント"), ("99%", "キュウジュウキュウパーセント"),
        ("8割から9割", "ハチワリからキュウワリ"), ("4割", "ヨンワリ"), ("25年", "ニジュウゴネン"), ("何千km", "ナンゼンキロ"),
        ("ワイアレアレ", "ワイアレアレ"), ("マウナケア", "マウナケア"), ("ハナレイ川", "ハナレイがわ"), ("アカカ", "アカカ"),
        ("1つ目", "ひとつめ"), ("2つ目", "ふたつめ"), ("3つ目", "みっつめ"), ("4つ目", "よっつめ"), ("5つ目", "いつつめ"), ("2つ", "ふたつ"), ("1本", "いっぽん"),
        ("日本", "にほん"), ("一滴", "ひとしずく"), ("四半世紀", "しはんせいき"), ("中腹", "ちゅうふく"), ("同じ島", "おなじしま"), ("の下", "のした")]


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
