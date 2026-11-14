"""海面は平らではない(ジオイド・地理と物理・型 I): 本編 5 章とショート 5 本の台本と画面。ch1〜ch5・s1〜s5 の ep.py がここから読む。
台本は scripts.md(字は同じ。1 行 = 声の 1 区切り)。数字と出典は scripts.md の「確かめた数字」と sim/calc.txt。
画面は 2〜3 行ごとに種類を変える(じゃがいもの地球・海面の地図・断面・糸の重り・みかん・地球の断面・3 つの面・氷・札・棒・日本の地図)。"""
CREDIT = "海面の高さ: EGM2008・国土地理院／地球: NASA"
RED, YEL, WHITE, BLUE = (240, 90, 80), (255, 214, 64), (255, 255, 255), (120, 190, 255)
GREY, SAND = (170, 180, 200), (226, 196, 140)

LOW, HIGH = (78.75, 4.67), (147.33, -8.42)               # (経度, 緯度) いちばん低い・高い海面
TOKYO, SAPPORO, FUKUOKA = (139.70, 35.69), (141.35, 43.06), (130.40, 33.59)
FUJI, CHICHI, YONA = (138.7274, 35.3606), (142.19, 27.09), (123.0, 24.47)
NAHA, MINAMI = (127.68, 26.21), (153.98, 24.29)
OSHIKA, SHIRE = (141.50, 38.30), (145.05, 44.05)

JP_ALL = (138.5, 32.5, 40, 0)
JP = (139.5, 37.6, 26, 0)
FUJI_V = (138.73, 35.36, 1.2, 35)
SHORT_JP = (137.5, 34.0, 26, 0)


def MAP(view, *layers, view_to=None, step=None, tr=None):
    s = dict(shot="map", view=view, layers=list(layers))
    for k, v in (("view_to", view_to), ("step", step), ("tr", tr)):
        if v is not None:
            s[k] = v
    return s


def LABEL(at_ll, text, size=56, color=WHITE, at=0.0, on=None, id=None):
    d = dict(kind="label", at_ll=at_ll, text=text, size=size, color=color, id=id or f"lab_{text}_{at_ll}", at=at)
    if on:
        d["on"] = on
    return d


def PIN(at_ll, text, id=None, at=0.0, size=44):
    return dict(kind="pin", at_ll=at_ll, text=text, id=id or f"pin_{text}", at=at, size=size)


def LINE(pts, color=YEL, width=6, id=None, at=0.0):
    return dict(kind="route", pts=pts, color=color, width=width, id=id or f"route_{pts[0]}_{pts[-1]}", at=at)


def S(shot, step=None, tr=None, **kw):
    d = dict(shot=shot, **kw)
    if step is not None:
        d["step"] = step
    if tr:
        d["tr"] = tr
    return d


def POT(center=(80, 5), to=None, ex=1.0, tint=1.0, marks=(), step=None, **kw):
    return S("potato", step, center=center, to=to or center, ex=ex, tint=tint, marks=list(marks), **kw)


def GMAP(view, view_to=None, step=None, **kw):
    return S("gmap", step, view=view, view_to=view_to or view, **kw)


def CARD(big, sub=None, note=None, step=None, count=True, **kw):
    return S("gcard", step, big=big, sub=sub, note=note, count=count, **kw)


def BARS(items, title=None, note=None, fmt="{}", step=None, **kw):
    return S("bars", step, items=items, title=title, note=note, fmt=fmt, **kw)


M_LOW = (LOW, "-107m", (120, 170, 255))
M_HIGH = (HIGH, "+86m", (255, 120, 90))
M_FUJI = (FUJI, "富士山", (255, 255, 255))

P = {}

# ---- 第1章 平らなはずの海 -----------------------------------------------------------------------------------
_a1 = POT((60, 10), to=(80, 4), ex=(0.0, 1.0), marks=[M_LOW], step=0)
_a3 = S("gprof", 0, ex=(0.0, 0.0), title="インド洋のくぼみを、本当の縮尺で切る")
_a6 = S("plumb", 0, mode="light")
_a9 = POT((20, 20), to=(40, 15), ex=0.0, tint=0.0, step=0, legend=False)
_a12 = POT((150, 0), to=(120, 5), ex=0.0, tint=1.0, step=0, title="人工衛星で測った海面の高さ")
_a19 = GMAP((88, 5, 70), (92, 5, 64), step=0, marks=[M_LOW], line=(LOW, (103.1, 4.67)), line_label="東へ 約2,700km")
_a21 = S("gprof", 0, ex=(0.0, 1.0))
_a26 = BARS([("海面の高い所と低い所の差", 193, BLUE), ("東京タワー", 333, GREY)], title="高さ（m）", note="重力の模型 EGM2008 から計算", fmt="{}m", step=0)
P["ch1"] = dict(title="第1章 平らなはずの海", cta=False, lines=[
    dict(id="a1", text="インド洋の真ん中では、海面がまわりより約100m低くなっています。", scene=_a1),
    dict(id="a2", text="30階建てのビルが、まるごと沈む深さです。", scene=_a1),
    dict(id="a3", text="ところが、この上を船で走っても、だれも気づきません。", scene=_a3),
    dict(id="a4", text="坂があるようにも、見えません。", scene=_a3),
    dict(id="a5", text="なぜ、海面は平らにならないのでしょうか。", style="question", sub="海の表面は\n【平らではなかった】", scene=GMAP((80, 0, 150), (78, 3, 110), step=0, fade_in=True)),
    dict(id="a6", text="答えを先に言うと、場所によって重力が少しずつ違うからです。", section=True, scene=_a6),
    dict(id="a7", text="水は、重力の向きに合わせて表面をそろえます。", scene=_a6),
    dict(id="a8", text="世界の海面の高さと、重力のデータで確かめます。", scene=GMAP((20, 10, 360), (60, 10, 330), step=0, title="世界の海面の高さ（重力の模型 EGM2008）")),
    dict(id="a9", text="まず、ふつうの考え方から始めます。", section=True, scene=_a9),
    dict(id="a10", text="コップの水は、ゆらしてもすぐ平らに戻ります。", scene=S("plumb", 0, mode="plain")),
    dict(id="a11", text="海も同じで、表面はどこも同じ高さのはずです。", scene=_a9),
    dict(id="a12", text="ところが、人工衛星で海面の高さを測ると、そうなっていません。", scene=_a12),
    dict(id="a13", text="衛星は電波を海に当てて、はね返るまでの時間で高さを測ります。", scene=_a12),
    dict(id="a14", text="狂いは、数cmほどです。", scene=CARD("数cm", sub="衛星で測る海面の高さの狂い", step=0, count=False)),
    dict(id="a15", text="そうして描いた海面の地図が、こちらです。", scene=GMAP((0, 10, 360), (60, 5, 300), step=0)),
    dict(id="a16", text="高さの差を、1万倍に大きくしています。", scene=POT((40, 10), to=(70, 6), ex=(0.0, 1.0), step=0, note="高さの差を1万倍に大きくしています")),
    dict(id="a17", text="インド洋の真ん中、スリランカの南に、大きなくぼみがあります。", scene=GMAP((80, 8, 70), (79, 6, 52), step=0, marks=[M_LOW], names=[((80.7, 7.8), "スリランカ"), ((78.5, 21), "インド")])),
    dict(id="a18", text="いちばん深い所で、約107mです。", scene=CARD("約107m", sub="いちばん低い海面（スリランカの南）", note="重力の模型 EGM2008 から計算", step=0)),
    dict(id="a19", text="縁から底まで、近い東側でも約2,700kmあります。", scene=_a19),
    dict(id="a20", text="日本列島が、すっぽり入る長さです。", scene=_a19),
    dict(id="a21", text="だから、坂はとてもゆるやかです。", scene=_a21),
    dict(id="a22", text="いちばん急な東側でも、25km進んでやっと1m下がります。", scene=_a21),
    dict(id="a23", text="これでは、船の上で気づけません。", scene=CARD("25kmで1m", sub="いちばん急な東側の坂", note="自分で計算", step=0, count=False)),
    dict(id="a24", text="逆に、まわりより高い場所もあります。", section=True, scene=POT((110, 0), to=(140, -6), ex=1.0, marks=[M_HIGH], step=0)),
    dict(id="a25", text="ニューギニアのあたりは、約86m盛り上がっています。", scene=CARD("約86m", sub="いちばん高い海面（ニューギニア）", note="重力の模型 EGM2008 から計算", step=0)),
    dict(id="a26", text="低い所と高い所の差は、約193mです。", scene=_a26),
    dict(id="a27", text="東京タワーの、6割ほどの高さです。", scene=_a26),
    dict(id="a28", text="地球の海は、じゃがいものように、でこぼこしていたのです。", scene=POT((0, 15), to=(100, 5), ex=1.0, step=0, spin=20)),
    dict(id="a29", text="このでこぼこは、最後に富士山の高さにつながります。", scene=POT((115, 25), to=(138, 33), ex=1.0, marks=[M_FUJI], step=0)),
])

# ---- 第2章 水は重力にそろう ---------------------------------------------------------------------------------
_b3 = S("plumb", 1, mode="plain")
_b6 = S("plumb", 1, mode="mountain")
_b10 = S("plumb", 1, mode="heavy")
_b12 = S("plumb", 1, mode="light")
_b18 = S("ellip", 1)
_b22 = S("ellip", 1, title="回っているので、赤道がふくらむ")
_b25 = S("ellip", 1, geo=True, title="物差しの地球と、本当の海面")
P["ch2"] = dict(title="第2章 水は重力にそろう", cta=False, lines=[
    dict(id="b1", text="なぜ、海面にでこぼこができるのでしょうか。", scene=POT((60, 0), to=(85, 5), ex=1.0, step=1, tr="zoom")),
    dict(id="b2", text="鍵は、水がどちらを「下」と感じるかです。", scene=GMAP((78, 5, 90), (80, 4, 70), step=1)),
    dict(id="b3", text="糸に重りをつけて垂らすと、真下を指します。", scene=_b3),
    dict(id="b4", text="この向きが、その場所の重力の向きです。", scene=_b3),
    dict(id="b5", text="水の表面は、いつもこの向きに直角になります。", scene=S("plumb", 1, mode="plain", note="水面は、糸に直角")),
    dict(id="b6", text="では、すぐそばに大きな山があったらどうでしょう。", scene=_b6),
    dict(id="b7", text="山の重さに、重りは少しだけ引かれます。", scene=_b6),
    dict(id="b8", text="糸はほんのわずか、山のほうへ傾きます。", scene=S("plumb", 1, mode="mountain", note="傾きは大きくして描いています")),
    dict(id="b9", text="すると水の表面も、山のほうで少し持ち上がります。", scene=S("plumb", 1, mode="mountain", note="水面も山のほうで持ち上がる")),
    dict(id="b10", text="海の底に重い岩があれば、その上に水が寄ってきます。", scene=_b10),
    dict(id="b11", text="海面は、盛り上がります。", scene=_b10),
    dict(id="b12", text="逆に、下が軽ければ、水は離れて海面がへこみます。", scene=_b12),
    dict(id="b13", text="インド洋のくぼみは、下が軽いしるしなのです。", scene=GMAP((80, 3, 60), (78, 5, 50), step=1, marks=[M_LOW])),
    dict(id="b14", text="どれくらいの違いでしょうか。", section=True, scene=CARD("0.02度", sub="糸の傾き（いちばん大きい所）", note="重力の模型から自分で計算", step=1, count=False)),
    dict(id="b15", text="糸の傾きは、いちばん大きい所でも0.02度ほどです。"),
    dict(id="b16", text="1km先で、わずか36cmずれるくらいです。", scene=CARD("36cm", sub="1km先での糸のずれ", note="自分で計算", step=1)),
    dict(id="b17", text="それでも、海の水は正直に動きます。", scene=POT((50, 0), to=(75, 3), ex=1.0, step=1)),
    dict(id="b18", text="ここで、もう1つの思い込みを外します。", section=True, scene=_b18),
    dict(id="b19", text="地球は、まん丸ではありません。", scene=_b18),
    dict(id="b20", text="赤道の半径は6,378km、北極までは6,357kmです。", scene=BARS([("赤道までの半径", 6378, YEL), ("北極までの半径", 6357, BLUE)], title="地球の半径（km）", note="GRS80", fmt="{:,}km", step=1)),
    dict(id="b21", text="21kmの差があり、少しつぶれたみかんの形です。", scene=CARD("21km", sub="赤道と北極の半径の差", note="GRS80", step=1)),
    dict(id="b22", text="地球が回っているので、赤道がふくらむのです。", scene=_b22),
    dict(id="b23", text="この形は、計算で出せます。", scene=_b22),
    dict(id="b24", text="測る人は、このみかんの形を「物差しの地球」にします。", scene=S("ellip", 1, title="これが「物差しの地球」")),
    dict(id="b25", text="そのうえで、本当の海面との差を測ります。", scene=_b25),
    dict(id="b26", text="この差が、最大で107mのでこぼこです。", scene=_b25),
    dict(id="b27", text="21kmに比べれば、200分の1ほどの小さな差です。", scene=BARS([("赤道と北極の差", 21000, YEL), ("海面のでこぼこ", 107, BLUE)], title="大きさ（m）", fmt="{:,}m", step=1)),
    dict(id="b28", text="でも、この小さな差が、地下の重さの地図になります。", scene=POT((20, 10), to=(90, 0), ex=1.0, step=1)),
    dict(id="b29", text="次は、インド洋の下に何があるのかを見ていきます。", scene=GMAP((80, 0, 80), (78, 4, 55), step=1, marks=[M_LOW])),
])

# ---- 第3章 インド洋の下は軽い --------------------------------------------------------------------------------
_c2 = S("mantle", 2, stage=(0.0, 0.0), names=False)
_c11 = S("mantle", 2, stage=(0.0, 0.3), title="1億4,000万年前から")
_c14 = S("mantle", 2, stage=(0.5, 0.95))
P["ch3"] = dict(title="第3章 インド洋の下は軽い", cta=False, lines=[
    dict(id="c1", text="インド洋の下が軽いのは、なぜでしょうか。", scene=GMAP((78, 4, 80), (79, 4, 60), step=2, marks=[M_LOW], tr="zoom")),
    dict(id="c2", text="海の底の岩は、ほかの海とそれほど変わりません。", scene=_c2),
    dict(id="c3", text="答えは、もっと深い所にあります。", scene=_c2),
    dict(id="c4", text="地球の中は、ゆっくり動く熱い岩でできています。", scene=S("mantle", 2, stage=(0.0, 0.0))),
    dict(id="c5", text="マントルと呼ばれる層で、深さ約2,900kmまで続きます。", scene=CARD("約2,900km", sub="マントルの深さ", step=2)),
    dict(id="c6", text="熱い岩はふくらんで軽くなり、ゆっくり昇ります。", scene=S("plumb", 2, mode="light", title="熱い岩は軽い")),
    dict(id="c7", text="冷たい岩は重くなり、沈んでいきます。", scene=S("plumb", 2, mode="heavy", title="冷たい岩は重い")),
    dict(id="c8", text="何千万年もかけて、鍋のみそ汁のように回っています。", scene=S("mantle", 2, stage=(0.0, 0.15))),
    dict(id="c9", text="2023年、インドの研究チームがこの動きを計算しました。", section=True, scene=CARD("2023年", sub="インドの研究チームの計算", note="Geophysical Research Letters", step=2, count=False)),
    dict(id="c10", text="1億4,000万年前から、プレートの動きを入れて再現しています。", scene=CARD("1億4,000万年前", sub="計算を始めた時代", step=2, count=False)),
    dict(id="c11", text="当時、インドとアジアのあいだには、テチス海という海がありました。", scene=_c11),
    dict(id="c12", text="その海の底の板は、地球の奥へ沈んでいきました。", scene=_c11),
    dict(id="c13", text="沈んだ板は、アフリカの下にある大きな熱い塊を押しました。", scene=S("mantle", 2, stage=(0.3, 0.5))),
    dict(id="c14", text="押された塊から、熱い岩の柱が昇ります。", scene=_c14),
    dict(id="c15", text="その柱が、インド洋の下へ流れ込みました。", scene=_c14),
    dict(id="c16", text="熱い岩は軽い。だから重力が弱まり、海面がへこんだのです。", scene=S("plumb", 2, mode="light")),
    dict(id="c17", text="計算で、くぼみの形と深さが再現できました。", scene=POT((60, 0), to=(80, 4), ex=1.0, marks=[M_LOW], step=2)),
    dict(id="c18", text="では、盛り上がっている所はどうでしょう。", section=True, scene=POT((120, 0), to=(145, -6), ex=1.0, marks=[M_HIGH], step=2)),
    dict(id="c19", text="ニューギニアのあたりは、海の板が地球の奥へ沈み込む場所です。", scene=GMAP((145, -5, 50), (146, -6, 40), step=2, marks=[M_HIGH], names=[((142.5, -5.5), "ニューギニア")])),
    dict(id="c20", text="冷たく重い板が、地下にたまっています。", scene=S("plumb", 2, mode="heavy")),
    dict(id="c21", text="重いから、水が寄って海面が上がります。", scene=S("plumb", 2, mode="heavy", note="水が寄って、海面が上がる")),
    dict(id="c22", text="つまり、海面のでこぼこは、地下の地図です。", scene=POT((30, 10), to=(110, 0), ex=1.0, step=2)),
    dict(id="c23", text="深さ数百km、数千kmの重さが、海の表面に出ています。", scene=S("mantle", 2, stage=(1.0, 1.0))),
    dict(id="c24", text="海面を見れば、地球の中が少し透けて見えるのです。", scene=POT((100, 0), to=(160, 5), ex=1.0, step=2)),
])

# ---- 第4章 日本の見えない海面 --------------------------------------------------------------------------------
_d4 = MAP(JP, LABEL(TOKYO, "東京 37m", 52, YEL, on="東京"), LABEL(SAPPORO, "札幌 32m", 52, YEL, on="札幌"), LABEL(FUKUOKA, "福岡 33m", 52, YEL, on="福岡"), step=3, view_to=(138.5, 37.2, 23, 0))
_d6 = MAP(JP_ALL, LABEL(CHICHI, "父島 49m", 52, YEL, on="父島"), LABEL(YONA, "与那国島 23m", 52, YEL, on="与那国"), step=3, view_to=(136.0, 31.0, 38, 0))
_d8 = S("levels", 3, title="見えない海面は、陸の下にも続く")
_d11 = S("levels", 3)
_d18 = MAP(JP, LINE([TOKYO, (140.9, 38.3), SAPPORO], id="r_n"), LINE([TOKYO, (135.5, 34.7), FUKUOKA], id="r_s"), step=3, view_to=(137.5, 36.5, 20, 0))
P["ch4"] = dict(title="第4章 日本の見えない海面", cta=False, lines=[
    dict(id="d1", text="では、日本ではどうなっているでしょうか。", scene=MAP(JP_ALL, step=3, tr="zoom", view_to=(137.0, 34.5, 32, 0))),
    dict(id="d2", text="日本の海面も、物差しの地球から浮いています。", scene=GMAP((138, 34, 40), (138, 35, 30), step=3)),
    dict(id="d3", text="国土地理院の計算で、各地を測りました。", scene=CARD("ジオイド2024", sub="国土地理院のジオイド高計算", note="9か所を測った", step=3, count=False)),
    dict(id="d4", text="東京は37m、札幌は32m、福岡は33m。", scene=_d4),
    dict(id="d5", text="富士山の山頂の下では、43mです。", scene=MAP(FUJI_V, LABEL(FUJI, "43m", 64, YEL), step=3, view_to=(138.73, 35.36, 0.9, 40))),
    dict(id="d6", text="小笠原の父島は49m、与那国島は23mでした。", scene=_d6),
    dict(id="d7", text="日本の中だけでも、26mの差があります。", scene=BARS([("父島", 49, YEL), ("富士山頂", 43, BLUE), ("東京", 37, BLUE), ("札幌", 32, BLUE), ("与那国島", 23, GREY)], title="見えない海面の高さ（m）", note="国土地理院 ジオイド2024", fmt="{}m", step=3)),
    dict(id="d8", text="この見えない海面は、陸の下にも続いています。", scene=_d8),
    dict(id="d9", text="東京湾の海面の高さを、陸の下へのばした面です。", scene=_d8),
    dict(id="d10", text="地図の標高は、すべてこの面から測っています。", scene=CARD("標高の0m", sub="東京湾の平均の海面", note="測量法", step=3, count=False)),
    dict(id="d11", text="ここで、衛星で高さを測るとどうなるでしょう。", section=True, scene=_d11),
    dict(id="d12", text="衛星が出す高さは、物差しの地球からの高さです。", scene=_d11),
    dict(id="d13", text="そのままでは、見えない海面のぶんだけずれます。", scene=MAP(FUJI_V, step=3, view_to=(138.73, 35.36, 1.6, 25))),
    dict(id="d14", text="富士山の山頂なら、約43m高く出ます。", scene=CARD("+43m", sub="衛星だけで測った富士山頂", step=3)),
    dict(id="d15", text="3,776mの山が、3,818mになってしまうのです。", scene=S("levels", 3, title="3,776mの山が、3,818mに")),
    dict(id="d16", text="だから、見えない海面の高さを引いて、標高に直します。", scene=CARD("3,818 − 43 = 3,776", sub="衛星の高さ − 見えない海面 = 標高", step=3, count=False)),
    dict(id="d17", text="2025年4月、日本はこの方法に切り替えました。", section=True, scene=CARD("2025年4月", sub="衛星で標高を決める方法へ", note="国土地理院", step=3, count=False)),
    dict(id="d18", text="それまでは、東京から高さを順に測ってつないでいました。", scene=_d18),
    dict(id="d19", text="この方法は、遠くへ行くほど狂いがたまります。", scene=_d18),
    dict(id="d20", text="切り替えで、日本中の標高が書き換わりました。", scene=MAP(JP, step=3, view_to=(140.0, 39.0, 14, 0))),
    dict(id="d21", text="宮城県の牡鹿半島では、57cm上がりました。", scene=MAP((141.4, 38.35, 2.4, 30), LABEL(OSHIKA, "+57cm", 64, YEL), step=3, view_to=(141.45, 38.32, 1.8, 35))),
    dict(id="d22", text="北海道の知床半島では、67cm下がりました。", scene=MAP((145.0, 44.0, 2.4, 30), LABEL(SHIRE, "-67cm", 64, BLUE), step=3, view_to=(145.05, 44.05, 1.8, 35))),
    dict(id="d23", text="さらに、遠くの島には、それぞれの海面があります。", section=True, scene=MAP(JP_ALL, PIN(NAHA, "那覇", id="p_na"), PIN(MINAMI, "南鳥島", id="p_mi"), PIN(CHICHI, "父島", id="p_ch"), step=3, view_to=(140.0, 28.0, 38, 0))),
    dict(id="d24", text="沖縄の那覇の海面は、東京湾の海面より約68cm高い所にあります。", scene=MAP((127.7, 26.3, 2.2, 25), LABEL(NAHA, "+68cm", 64, YEL), step=3, view_to=(127.7, 26.25, 1.6, 30))),
    dict(id="d25", text="南鳥島では、約1m高い所です。", scene=MAP((150.0, 25.5, 14, 0), PIN(MINAMI, "南鳥島", id="p_mi2"), LABEL((153.98, 25.4), "約+1m", 64, YEL), step=3, view_to=(151.5, 25.0, 11, 0))),
    dict(id="d26", text="同じ海でつながっているのに、高さがそろっていないのです。", scene=BARS([("南鳥島", 100, YEL), ("那覇", 68, BLUE), ("父島", 64, BLUE), ("東京湾", 0, GREY)], title="島ごとの海面（東京湾より何cm高いか）", note="国土地理院 基準面補正量", fmt="{}cm", step=3)),
    dict(id="d27", text="海の流れや水の温かさでも、海面は場所ごとに少し変わります。", scene=GMAP((138, 30, 40), (142, 32, 34), step=3)),
    dict(id="d28", text="日本の地図は、このずれまで測って作られています。", scene=MAP(JP_ALL, step=3, view_to=(137.5, 34.0, 30, 0))),
])

# ---- 第5章 水平とは何か ---------------------------------------------------------------------------------------
_e3 = S("plumb", 4, mode="light", title="船は、平らな所を進んでいる")
_e5 = S("plumb", 4, mode="plain", title="「平ら」＝ 重力の向きに直角な面")
_e11 = S("levels", 4, title="標高は、見えない海面から測る")
_CV = [((138, 34, 40), (139, 35, 36)), ((80, 5, 90), (82, 4, 80)), ((140, 30, 50), (138, 32, 44))]
CARDS_N = lambda n: dict(shot="cards", items=ANSWERS, n=n, view=JP_ALL, view_to=(137.0, 33.5, 36, 0), step=4)  # noqa: E731
ANSWERS = [("海面は平らではない", "インド洋の真ん中は約107m低い"),
           ("地下の重さで、重力が変わる", "下が軽いとへこみ、重いと盛り上がる"),
           ("そのでこぼこの面が「水平」", "標高も、この面から測る")]
P["ch5"] = dict(title="第5章 水平とは何か", cta=True, lines=[
    dict(id="e1", text="冒頭のくぼみに戻ります。", scene=POT((60, 5), to=(80, 4), ex=1.0, marks=[M_LOW], step=4, tr="zoom")),
    dict(id="e2", text="インド洋の真ん中へ向かう船は、坂を下っているのでしょうか。", style="question", sub="くぼみへ向かう船は\n【坂を下っている？】", scene=S("gprof", 4, ex=(1.0, 1.0))),
    dict(id="e3", text="答えは、いいえ。船は平らな所を進んでいます。", scene=_e3),
    dict(id="e4", text="ここが、いちばん大事なところです。", scene=_e3),
    dict(id="e5", text="「平ら」とは、重力の向きに直角な面のことです。", scene=_e5),
    dict(id="e6", text="水を置いても、どちらにも流れない面です。", scene=_e5),
    dict(id="e7", text="くぼみに見えるのは、みかんの形を物差しにしたときだけです。", scene=S("ellip", 4, geo=True, title="くぼみは、物差しから見たときだけ")),
    dict(id="e8", text="水にとっては、くぼみの底も、まわりも、同じ高さです。", scene=S("gprof", 4, ex=(1.0, 1.0), title="水にとっては、どこも同じ高さ")),
    dict(id="e9", text="だから、水はくぼみに流れ込みません。", scene=POT((70, 5), to=(85, 3), ex=(1.0, 0.0), step=4, note="水にとっては、これが平らな面")),
    dict(id="e10", text="船も、坂を感じません。"),
    dict(id="e11", text="本当の高さは、水がどちらへ流れるかで決まります。", scene=_e11),
    dict(id="e12", text="だから、地図の標高は、見えない海面から測るのです。", scene=_e11),
    dict(id="e13", text="もう1つ、この考え方で分かることがあります。", section=True, scene=GMAP((-40, 70, 70), (-42, 72, 60), step=4, names=[((-41, 74), "グリーンランド")])),
    dict(id="e14", text="南極やグリーンランドの氷がとけると、海はどう変わるでしょうか。"),
    dict(id="e15", text="普通は、どこの海も同じだけ上がると考えます。", scene=S("iceprint", 4, melt=False, title="氷がとけたら、海は同じだけ上がる？")),
    dict(id="e16", text="ところが、とけた氷の近くでは、海面がむしろ下がります。", scene=S("iceprint", 4, melt=True, title="とけた氷の近くでは、海面が下がる")),
    dict(id="e17", text="大きな氷は重く、まわりの海の水を引き寄せていました。", scene=S("iceprint", 4, melt=False)),
    dict(id="e18", text="氷が減ると、その力が弱まり、水が離れていきます。", scene=S("iceprint", 4, melt=True, title="氷が減ると、水が離れていく")),
    dict(id="e19", text="NASAによると、氷から最大2,000kmの海岸で、海面が下がります。", scene=CARD("2,000km", sub="氷から、海面が下がる範囲（最大）", note="NASA", step=4)),
    dict(id="e20", text="そのぶん、遠い海の海面が多く上がります。", scene=S("iceprint", 4, melt=True, title="そのぶん、遠い海が多く上がる")),
    dict(id="e21", text="海面のでこぼこは、今も動いているのです。", scene=POT((-60, 40), to=(-20, 30), ex=1.0, step=4)),
    dict(id="e22", text="冒頭で、このでこぼこは富士山につながると言いました。", section=True, scene=MAP(FUJI_V, PIN(FUJI, "富士山", id="p_fu"), step=4, view_to=(138.73, 35.36, 0.8, 40))),
    dict(id="e23", text="富士山の3,776mは、足もとの見えない海面からの高さです。", scene=S("levels", 4, title="3,776mは、見えない海面から")),
    dict(id="e24", text="その海面は、地下の重さで決まっています。", scene=S("mantle", 4, stage=(1.0, 1.0))),
    dict(id="e25", text="富士山の高さには、地球の中の重さが入っているのです。", scene=POT((120, 25), to=(138, 34), ex=1.0, marks=[M_FUJI], step=4)),
    dict(id="e26", text="まとめます。", section=True, scene=CARDS_N(1)),
    dict(id="e27", text="海面は平らではなく、最大で約107mへこんでいます。"),
    dict(id="e28", text="地下の岩の重さが、重力を変えているからです。", scene=CARDS_N(2)),
    dict(id="e29", text="そして、そのでこぼこの面こそが、地球の「水平」です。", scene=CARDS_N(3)),
    dict(id="e30", text="次に地図で標高を見たら、その数字の下を思い出してください。", scene=MAP(FUJI_V, step=4, view_to=(138.73, 35.36, 1.4, 25))),
    dict(id="e31", text="そこには、見えない海面が、でこぼこに続いています。", scene=POT((100, 20), to=(140, 30), ex=1.0, step=4)),
])

# ---- ショート ---------------------------------------------------------------------------------------------
_PT = dict(r=0.22)
P["s1"] = dict(title="インド洋の真ん中、海面は約100m低い", lines=[
    dict(id="k1", text="インド洋の真ん中では、海面がまわりより約100m低くなっています。", scene=POT((60, 10), to=(80, 4), ex=(0.0, 1.0), marks=[M_LOW], **_PT)),
    dict(id="k2", text="30階建てのビルが、まるごと沈む深さです。", scene=CARD("約100m", sub="まわりより低い海面", note="重力の模型 EGM2008")),
    dict(id="k3", text="なのに、船で走っても気づきません。", scene=S("gprof", ex=(0.0, 0.0))),
    dict(id="k4", text="くぼみはとても広く、25km進んでやっと1m下がるからです。", scene=S("gprof", ex=(0.0, 1.0))),
    dict(id="k5", text="では、なぜ海がへこむのか。", style="question", sub="海が\n【へこむ】理由", scene=GMAP((80, 5, 50), (79, 5, 40), marks=[M_LOW])),
    dict(id="k6", text="答えは、海の下の重さです。"),
    dict(id="k7", text="水の表面は、重力の向きに直角にそろいます。", scene=S("plumb", mode="plain")),
    dict(id="k8", text="下に重い岩があれば水が寄り、軽ければ水が離れます。", scene=S("plumb", mode="light")),
    dict(id="k9", text="インド洋の下には、地球の奥から昇ってきた熱い岩があります。", scene=S("mantle", stage=(0.4, 1.0))),
    dict(id="k10", text="熱い岩は軽いので、重力が少し弱くなります。"),
    dict(id="k11", text="糸の傾きにすると、0.01度ほどの違いです。", scene=CARD("0.01度", sub="くぼみのまわりの糸の傾き", note="自分で計算", count=False)),
    dict(id="k12", text="それでも、水は正直にへこむのです。", scene=POT((70, 5), to=(85, 3), ex=1.0, **_PT)),
    dict(id="k13", text="反対に、ニューギニアのあたりは約86m盛り上がっています。", scene=POT((120, 0), to=(145, -6), ex=1.0, marks=[M_HIGH], **_PT)),
    dict(id="k14", text="海の表面は、じゃがいものようにでこぼこなのです。", scene=POT((0, 15), to=(90, 5), ex=1.0, spin=20, **_PT)),
])

P["s2"] = dict(title="衛星だけで富士山を測ると3,818m", lines=[
    dict(id="m1", text="衛星だけで富士山の山頂の高さを測ると、約3,818mになります。", scene=MAP(FUJI_V, PIN(FUJI, "富士山", id="p_mf"), view_to=(138.73, 35.36, 0.8, 40))),
    dict(id="m2", text="本当の3,776mより、約43m高い数字です。", scene=CARD("+43m", sub="衛星だけで測った富士山頂")),
    dict(id="m3", text="衛星の測り方が、間違っているわけではありません。", scene=S("levels")),
    dict(id="m4", text="衛星は、少しつぶれたみかん形の「物差しの地球」から高さを測ります。", scene=S("ellip")),
    dict(id="m5", text="一方、地図の標高は、海面から測ります。", scene=S("levels", title="地図の標高は、海面から")),
    dict(id="m6", text="その海面は、陸の下にも見えない面として続いています。"),
    dict(id="m7", text="国土地理院の計算では、富士山の下の見えない海面は、物差しより43m上にあります。", scene=MAP(FUJI_V, LABEL(FUJI, "43m", 64, YEL), view_to=(138.73, 35.36, 1.2, 30))),
    dict(id="m8", text="だから43mを引くと、3,776mに戻るのです。", scene=CARD("3,818 − 43 = 3,776", sub="衛星の高さ − 見えない海面 = 標高", count=False)),
    dict(id="m9", text="この差は、場所によって違います。", scene=MAP(SHORT_JP, view_to=(137.0, 33.0, 30, 0))),
    dict(id="m10", text="東京は37m、札幌は32m、父島は49m、与那国島は23m。", scene=BARS([("父島", 49, YEL), ("東京", 37, BLUE), ("札幌", 32, BLUE), ("与那国島", 23, GREY)], title="見えない海面の高さ（m）", fmt="{}m")),
    dict(id="m11", text="日本の中だけでも、26mの差があります。"),
    dict(id="m12", text="重力が場所ごとに少しずつ違い、海面がでこぼこだからです。", scene=GMAP((138, 34, 30), (138, 34, 26))),
    dict(id="m13", text="2025年4月から、日本の標高はこの方法で決めています。", scene=CARD("2025年4月", sub="衛星で標高を決める方法へ", note="国土地理院", count=False)),
])

P["s3"] = dict(title="沖縄の海面は、東京湾より約68cm高い", lines=[
    dict(id="n1", text="沖縄の那覇の海面は、東京湾の海面より約68cm高い所にあります。", scene=MAP((127.7, 26.3, 2.2, 25), LABEL(NAHA, "+68cm", 64, YEL), view_to=(127.7, 26.25, 1.6, 30))),
    dict(id="n2", text="同じ海でつながっているのに、高さがそろっていないのです。", scene=MAP(SHORT_JP, PIN(NAHA, "那覇", id="p_nn"), PIN(TOKYO, "東京", id="p_nt"), view_to=(134.0, 30.0, 30, 0))),
    dict(id="n3", text="日本の標高は、東京湾の平均の海面から測ります。", scene=CARD("標高の0m", sub="東京湾の平均の海面", count=False)),
    dict(id="n4", text="ところが、遠い島では、島ごとの海面を0mにしています。", scene=MAP(JP_ALL, PIN(NAHA, "那覇", id="p_n2"), PIN(CHICHI, "父島", id="p_c2"), PIN(MINAMI, "南鳥島", id="p_m2"), view_to=(140.0, 28.0, 38, 0))),
    dict(id="n5", text="国土地理院は、その差を島ごとに測って出しています。"),
    dict(id="n6", text="那覇は68cm、父島は64cm、南鳥島は約1mです。", scene=BARS([("南鳥島", 100, YEL), ("那覇", 68, BLUE), ("父島", 64, BLUE)], title="東京湾より何cm高いか", note="国土地理院", fmt="{}cm")),
    dict(id="n7", text="水は、重力の向きに直角な面にそろいます。", scene=S("plumb", mode="plain")),
    dict(id="n8", text="重力は、地下の重さで場所ごとに少し違います。", scene=S("plumb", mode="heavy")),
    dict(id="n9", text="さらに、海の流れや水の温かさでも、海面は上下します。", scene=GMAP((135, 28, 30), (138, 30, 26))),
    dict(id="n10", text="だから、海面は1枚の平らな板になりません。", scene=POT((110, 20), to=(135, 28), ex=1.0, **_PT)),
    dict(id="n11", text="船で行き来しても、坂は感じません。", scene=S("gprof", ex=(1.0, 1.0), title="船は坂を感じない")),
    dict(id="n12", text="それでも、測ると高さがずれているのです。", scene=CARD("68cm", sub="那覇の海面と東京湾の差", note="国土地理院")),
])

P["s4"] = dict(title="2025年4月、日本中の標高が書き換わった", lines=[
    dict(id="q1", text="2025年4月、日本中の標高が書き換わりました。", scene=CARD("2025年4月", sub="日本中の標高の改定", note="国土地理院", count=False)),
    dict(id="q2", text="北海道の知床半島では、67cm下がりました。", scene=MAP((145.0, 44.0, 2.4, 30), LABEL(SHIRE, "-67cm", 64, BLUE), view_to=(145.05, 44.05, 1.8, 35))),
    dict(id="q3", text="宮城県の牡鹿半島では、57cm上がりました。", scene=MAP((141.4, 38.35, 2.4, 30), LABEL(OSHIKA, "+57cm", 64, YEL), view_to=(141.45, 38.32, 1.8, 35))),
    dict(id="q4", text="山が急に動いたわけではありません。", scene=BARS([("牡鹿半島", 57, YEL), ("知床半島", 67, BLUE)], title="標高の書き換え（cm）", note="国土地理院（三角点）", fmt="{}cm")),
    dict(id="q5", text="高さの測り方が変わったのです。"),
    dict(id="q6", text="それまでは、東京から高さを順に測ってつないでいました。", scene=MAP(SHORT_JP, LINE([TOKYO, (140.9, 38.3), SAPPORO], id="r_qn"), LINE([TOKYO, (135.5, 34.7), FUKUOKA], id="r_qs"), view_to=(138.0, 36.0, 24, 0))),
    dict(id="q7", text="遠くへ行くほど、狂いがたまっていきます。"),
    dict(id="q8", text="地震で地面が動いたぶんも、たまっていました。", scene=MAP((141.4, 38.35, 4.0, 20), view_to=(141.4, 38.35, 3.0, 30))),
    dict(id="q9", text="新しい方法では、衛星で高さを測ります。", scene=S("levels")),
    dict(id="q10", text="そこから、陸の下に続く見えない海面の高さを引きます。"),
    dict(id="q11", text="国土地理院は、この見えない海面を、飛行機や船で重力を測って描きました。", scene=GMAP((138, 35, 26), (138, 36, 22))),
    dict(id="q12", text="狂いは、約3cmです。", scene=CARD("約3cm", sub="見えない海面の狂い", note="国土地理院", count=False)),
    dict(id="q13", text="あなたの家の標高も、この日に少し変わっているかもしれません。", scene=MAP(SHORT_JP, view_to=(137.0, 35.5, 20, 0))),
])

P["s5"] = dict(title="氷がとけると、近くの海は下がる", lines=[
    dict(id="r1", text="南極やグリーンランドの氷がとけると、近くの海面はむしろ下がります。", scene=GMAP((-40, 70, 50), (-42, 72, 44), names=[((-41, 74), "グリーンランド")])),
    dict(id="r2", text="海の水は増えるのに、です。", scene=S("iceprint", melt=False, title="氷がとけると、海は？")),
    dict(id="r3", text="理由は、氷の重さです。"),
    dict(id="r4", text="厚さ数千mの氷は重く、まわりの海の水を引き寄せていました。", scene=S("iceprint", melt=False, title="重い氷が、水を引き寄せる")),
    dict(id="r5", text="氷の近くの海面は、その力で盛り上がっていたのです。"),
    dict(id="r6", text="氷が減ると、引く力が弱まります。", scene=S("iceprint", melt=True, title="氷が減ると")),
    dict(id="r7", text="水は離れていき、近くの海面が下がります。"),
    dict(id="r8", text="NASAによると、氷から最大2,000kmの海岸で、海面が下がります。", scene=CARD("2,000km", sub="海面が下がる範囲（最大）", note="NASA")),
    dict(id="r9", text="離れた水は、遠い海へ向かいます。", scene=S("iceprint", melt=True, title="離れた水は、遠い海へ")),
    dict(id="r10", text="だから、遠い海ほど多く上がります。"),
    dict(id="r11", text="海面は、1枚の平らな板ではありません。", scene=POT((-60, 40), to=(-20, 30), ex=1.0, **_PT)),
    dict(id="r12", text="重さの置き場所が変わると、形が変わるのです。", scene=POT((-20, 30), to=(20, 20), ex=1.0, **_PT)),
])

# ---- 読み ------------------------------------------------------------------------------------------------
YOMI = [("約107m", "ヤクヒャクナナメートル"), ("107m", "ヒャクナナメートル"), ("約100m", "ヤクヒャクメートル"), ("約86m", "ヤクハチジュウロクメートル"),
        ("約193m", "ヤクヒャクキュウジュウサンメートル"), ("約2,700km", "ヤクニセンナナヒャクキロ"), ("約2,900km", "ヤクニセンキュウヒャクキロ"),
        ("2,000km", "ニセンキロ"), ("6,378km", "ロクセンサンビャクナナジュウハッキロ"), ("6,357km", "ロクセンサンビャクゴジュウナナキロ"), ("21km", "ニジュウイッキロ"),
        ("25km", "ニジュウゴキロ"), ("1km", "イチキロ"), ("36cm", "サンジュウロクセンチ"), ("57cm", "ゴジュウナナセンチ"), ("67cm", "ロクジュウナナセンチ"),
        ("約68cm", "ヤクロクジュウハッセンチ"), ("68cm", "ロクジュウハッセンチ"), ("64cm", "ロクジュウヨンセンチ"), ("約3cm", "ヤクサンセンチ"), ("数cm", "スウセンチ"),
        ("約3,818m", "ヤクサンゼンハッピャクジュウハチメートル"), ("3,818m", "サンゼンハッピャクジュウハチメートル"), ("3,776m", "サンゼンナナヒャクナナジュウロクメートル"),
        ("43m上", "ヨンジュウサンメートルウエ"), ("約43m", "ヤクヨンジュウサンメートル"), ("43m", "ヨンジュウサンメートル"), ("37m", "サンジュウナナメートル"), ("32m", "サンジュウニメートル"),
        ("33m", "サンジュウサンメートル"), ("49m", "ヨンジュウキュウメートル"), ("23m", "ニジュウサンメートル"), ("26m", "ニジュウロクメートル"), ("約1m", "ヤクイチメートル"),
        ("1m", "イチメートル"), ("0.02度", "レイテンレイニド"), ("0.01度", "レイテンレイイチド"), ("1万倍", "イチマンバイ"), ("200分の1", "ニヒャクブンノイチ"),
        ("6割", "ロクワリ"), ("30階建て", "サンジュッカイダテ"), ("1億4,000万年前", "イチオクヨンセンマンネンマエ"), ("何千万年", "ナンゼンマンネン"),
        ("2023年", "ニセンニジュウサンネン"), ("2025年4月", "ニセンニジュウゴネンシガツ"), ("数千m", "スウセンメートル"), ("数百km", "スウヒャッキロ"), ("数千km", "スウセンキロ"),
        ("1枚", "イチマイ"), ("1つ", "ひとつ"), ("0m", "ゼロメートル"),
        ("牡鹿半島", "おしかはんとう"), ("知床半島", "しれとこはんとう"), ("南鳥島", "みなみとりしま"), ("与那国島", "よなぐにじま"), ("父島", "ちちじま"),
        ("那覇", "ナハ"), ("小笠原", "おがさわら"), ("テチス海", "テチスかい"), ("塊", "かたまり"), ("縁", "ふち"), ("狂い", "くるい"),
        ("国土地理院", "コクドチリイン"), ("水の温かさ", "ミズノアタタカサ"), ("日本", "ニホン"), ("NASA", "ナサ"), ("垂らす", "たらす"), ("鍋", "なべ"), ("物差し", "ものさし"), ("下", "した")]
SAY = {("ch2", "b2"): "カギは、水がどちらを、シタと感じるかです。"}


def yomi(s):
    for a, b in YOMI:
        if a == "下":
            continue
        s = s.replace(a, b)
    return s


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
