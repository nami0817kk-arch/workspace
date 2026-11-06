"""南極の氷が全部とけたら(世界版): 本編 5 章とショート 5 本の台本と画面。ch1〜ch5・s1〜s5 の ep.py がここから読む。
数字は sim/calc.py(結果 sim/calc.txt)と sim/flood.py(sim/flood.txt)。測った値・定数の出どころは各ファイルの冒頭と make_desc.py。
画面は 2〜3 行ごとに種類を変える(海面を上げる地図・南極を真上から・断面・コップ・並べる・棒・数字)。"""
CREDIT = "地図: NASA・Terrain Tiles・ETOPO 2022"
RED, YEL, WHITE, BLUE = (240, 90, 80), (255, 214, 64), (255, 255, 255), (120, 190, 255)
GREY = (170, 180, 200)

WORLD = (15, 18, 300, 0)
EASIA = (122, 33, 34, 30)
NCHINA = (119.5, 37.6, 16, 30)
JAPAN = (137.2, 35.3, 9, 35)
EUROPE = (5, 50, 22, 30)
USAE = (-78, 31.5, 52, 12)
SASIA = (88.5, 23, 16, 30)

TOKYO, OSAKA, SEOUL = (139.75, 35.69), (135.5, 34.69), (126.98, 37.57)
SHANGHAI, BEIJING, WUHAN = (121.47, 31.23), (116.39, 39.93), (114.3, 30.59)
LONDON, PARIS, AMS = (-0.12, 51.5), (2.33, 48.87), (4.9, 52.37)
NY, MIAMI = (-73.98, 40.75), (-80.2, 25.77)
DHAKA, KOLKATA = (90.4, 23.73), (88.36, 22.57)


def MAP(view, *layers, view_to=None, step=None, tr=None, inset=False):
    s = dict(shot="map", view=view, layers=list(layers))
    for k, v in (("view_to", view_to), ("step", step), ("tr", tr)):
        if v is not None:
            s[k] = v
    if inset:
        s["inset"] = True
    return s


def FLOOD(level=58, rise_s=3.0, id="flood", at=0.0):
    return dict(kind="flood", level=level, rise_s=rise_s, id=id, at=at)


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


def POLAR(mode="ice", step=None, tr=None, **kw):
    d = dict(shot="polar", mode=mode, step=step, **kw)
    if tr:
        d["tr"] = tr
    return d


def SECT(mode="ice", step=None, tr=None, **kw):
    d = dict(shot="section", mode=mode, step=step, **kw)
    if tr:
        d["tr"] = tr
    return d


def GLASS(mode="float", step=None, tr=None, **kw):
    d = dict(shot="glass", mode=mode, step=step, **kw)
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


ANT_LABELS = [((-80, 80), "東南極"), ((-79, -110), "西南極")]
ANSWERS = [("海は58m上がり、大都市53のうち34が沈む", "沈む陸は日本30個ぶん"),
           ("南極の氷は2,722万立方km", "平均の厚さ2,117m"),
           ("単純に割れば69m。正しくは58m", "浮かぶ氷と、海面より下の氷の分を引く"),
           ("とかすには、太陽の光を全部注いで1年半", "地球にたまる熱だけなら約680年"),
           ("いまの速さなら11万年以上", "ただし速さは25年で4倍以上に")]

P = {}

# ---- 第1章 58mで沈む世界 -------------------------------------------------------------------------------
S_C1 = MAP(WORLD, FLOOD(rise_s=4.0), LABEL((-40, 35), "海面 ＋58m", 72, YEL, on="58m", count=True), step=0)
S_C2 = ICONS("floor", 19, title="58m ＝ ビルの約19階", note="1階 3mで計算", step=0)
S_C4 = CARD("1,134万平方km", sub="海の下になる陸", note="日本の30個ぶん", view=WORLD, step=0)
S_C6 = ICONS("city", 53, title="人口500万人を超える都市 53", hl=34, note="青は、中心が58mより低い34都市", step=0, tr="zoom")
S_C8 = MAP(JAPAN, FLOOD(rise_s=3.0, id="f_jp"), PIN(TOKYO, "東京 36m", id="p_tk"), PIN(OSAKA, "大阪 5m", id="p_os", at=0.4), step=0, tr="whip")
S_C9 = MAP(NCHINA, FLOOD(rise_s=3.0, id="f_nc"), PIN(BEIJING, "北京 52m", id="p_bj"), PIN(SEOUL, "ソウル 30m", id="p_se", at=0.4),
           PIN(SHANGHAI, "上海 11m", id="p_sh", at=0.6), step=0, view_to=(120.5, 36.8, 18, 30))
S_C11 = MAP(EASIA, FLOOD(id="f_ea"), PIN(WUHAN, "武漢 23m", id="p_wh"), PIN(SHANGHAI, "上海", id="p_sh2"),
            LABEL((117.5, 29.2), "海から700km以上", 54, YEL, on="700km"), step=0)
S_C12 = MAP(EUROPE, FLOOD(rise_s=3.0, id="f_eu"), PIN(LONDON, "ロンドン 3m", id="p_ld"), PIN(PARIS, "パリ 51m", id="p_pr", at=0.3),
            LABEL((5.6, 52.9), "オランダ 96%", 50, YEL, on="オランダ"), step=0, tr="whip")
S_C14 = MAP(USAE, FLOOD(rise_s=3.0, id="f_us"), PIN(NY, "ニューヨーク 23m", id="p_ny"), PIN(MIAMI, "マイアミ 1m", id="p_mi", at=0.3),
            LABEL((-74.5, 29), "フロリダ 95%", 50, YEL, on="フロリダ"), step=0)
S_C15 = MAP(SASIA, FLOOD(rise_s=3.0, id="f_sa"), PIN(DHAKA, "ダッカ 16m", id="p_dh"), PIN(KOLKATA, "コルカタ 11m", id="p_kk", at=0.3),
            LABEL((91.5, 25.6), "バングラデシュ 91%", 48, YEL, on="バングラデシュ"), step=0, tr="whip")
S_C16 = POLAR("ice", step=0, tr="flash", title="南極の氷は、どれだけあって、とけるのに何年かかるのか")
S_C19 = CARD("1年半", sub="太陽の光を、全部注いだとしても", note="いまの速さなら 11万年以上", view=WORLD, step=0, count=False, tr="flash")
S_C21 = SECT("ice", step=0, title="氷の厚さのデータで、南極を切って計算する")

P["ch1"] = dict(title="第1章 58mで沈む世界", cta=False, lines=[
    dict(id="c1", text="南極の氷が全部とけると、世界の海は58m上がります。", scene=S_C1),
    dict(id="c2", text="ビルなら、およそ19階の高さです。", scene=S_C2),
    dict(id="c3", text="海の水は、低い土地を伝って、陸の奥まで入りこみます。", scene=MAP(WORLD, FLOOD(id="flood"), step=0, view_to=(40, 25, 220, 0))),
    dict(id="c4", text="海の下になる陸は、1,134万平方km。", scene=S_C4),
    dict(id="c5", text="日本の30個ぶんです。"),
    dict(id="c6", text="人口500万人を超える大都市は、世界に53あります。", scene=S_C6),
    dict(id="c7", text="そのうち34の都市で、中心の地面が58mより低いのです。"),
    dict(id="c8", text="東京の中心は36m。大阪は5m。どちらも海の下です。", scene=S_C8),
    dict(id="c9", text="北京は、海から150kmも離れています。", scene=S_C9),
    dict(id="c10", text="それでも中心の高さは52m。わずかに沈みます。"),
    dict(id="c11", text="長江をさかのぼって、海から700km以上奥の武漢まで、海になります。", scene=S_C11),
    dict(id="c12", text="ヨーロッパでは、ロンドンもパリも沈みます。", scene=S_C12),
    dict(id="c13", text="オランダは、陸の96%が58mより低い国です。"),
    dict(id="c14", text="アメリカでは、ニューヨークとマイアミ。フロリダ半島も、95%が海の下です。", scene=S_C14),
    dict(id="c15", text="バングラデシュは、国の91%が沈みます。", scene=S_C15),
    dict(id="c16", text="では、南極の氷は、どれだけあって、とけるのに何年かかるのか。", style="question", sub="南極の氷は、とけるのに\n【何年】かかるのか", scene=S_C16),
    dict(id="c17", text="58mという数字は、どこから来たのか。"),
    dict(id="c18", text="答えを先に言います。", section=True),
    dict(id="c19", text="地球に届く太陽の光を、全部注いだとしても、とけるまで1年半かかります。", scene=S_C19),
    dict(id="c20", text="いまの速さなら、11万年以上です。"),
    dict(id="c21", text="南極の氷の厚さのデータと、地面の高さのデータで、計算して確かめます。", scene=S_C21),
])

# ---- 第2章 氷はどれだけあるか ---------------------------------------------------------------------------
S_D1 = POLAR("ice", step=1, tr="zoom", labels=ANT_LABELS)
S_D2 = ICONS("japan", 37, title="南極の氷 ＝ 日本 37個ぶんの広さ", note="1,383万平方km", step=1)
S_D3 = POLAR("ice", step=1, line=True, title="南極を、まっすぐ切ってみる")
S_D4 = SECT("ice", step=1, labels=[(0.26, 3300, "平均の厚さ 2,117m", YEL)])
S_D6 = SECT("below", step=1, title="氷の下の地面の半分近くは、海面より低い")
S_D8 = CARD("2,722万立方km", sub="南極の氷の体積", note="ETOPO 2022 の氷の表面と岩盤から計算", view=WORLD, step=1)
S_D9 = CARD("2京5千兆トン", sub="南極の氷の重さ", view=WORLD, step=1, count=False)
S_D10 = MAP(WORLD, LABEL((-40, 32), "海の広さ 3億6千万平方km", 56, WHITE, id="l_ocean"), step=1, tr="whip")
S_D11 = CARD("69m", sub="全部の氷を水にして、海の広さで割ると", view=WORLD, step=1)
S_D12 = BARS([("単純に割ると", 69.0, GREY), ("データから正しく", 58.2, YEL)], title="海面が上がる高さ（計算）", fmt="{}m", step=1)
S_D13 = CARD("11m", sub="足りない", note="69m − 58m", view=WORLD, step=1, tr="flash")

P["ch2"] = dict(title="第2章 氷はどれだけあるか", cta=False, lines=[
    dict(id="d1", text="まず、南極の氷は、どれくらいあるのでしょう。", scene=S_D1),
    dict(id="d2", text="広さは1,383万平方km。日本の37個ぶんです。", scene=S_D2),
    dict(id="d3", text="この氷を、まっすぐ切ってみます。", scene=S_D3),
    dict(id="d4", text="厚さは、平均で2,117m。", scene=S_D4),
    dict(id="d5", text="富士山の高さの半分を超える氷が、大陸をまるごと覆っています。"),
    dict(id="d6", text="そして、氷の下の地面は、半分近くが海面より低い所にあります。", scene=S_D6),
    dict(id="d7", text="氷の重さで、大陸そのものが押し下げられているのです。"),
    dict(id="d8", text="氷の体積は、2,722万立方km。", scene=S_D8),
    dict(id="d9", text="重さにすると、2京5千兆トンです。", scene=S_D9),
    dict(id="d10", text="この氷を全部水にして、世界の海に広げると、何mになるのか。", section=True, scene=S_D10),
    dict(id="d11", text="海の広さで割ると、69mです。", scene=S_D11),
    dict(id="d12", text="ところが、氷の厚さのデータから正しく計算すると、58m。", scene=S_D12),
    dict(id="d13", text="11mも足りません。", scene=S_D13),
    dict(id="d14", text="この11mは、どこへ消えたのか。"),
])

# ---- 第3章 消えた11m ----------------------------------------------------------------------------------
S_E1 = POLAR("shelf", step=2, tr="zoom", title="赤：海に浮かぶ氷の板")
S_E3 = GLASS("float", step=2, title="コップの氷水", note="とけても、水はあふれない")
S_E6 = MAP((0, 75, 120, 20), LABEL((-10, 84), "北極の海", 60, WHITE, id="l_arc"), step=2, tr="whip")
S_E7 = BARS([("単純に割ると", 69.0, GREY), ("浮かぶ氷", 2.3, BLUE)], title="引く分（計算）", fmt="{}m", step=2)
S_E8 = SECT("below", step=2, tr="zoom", title="赤：海面より低い所にある氷")
S_E10 = GLASS("rock", step=2, title="海の底の岩に乗った氷", note="海面より上に出ていた分だけ、水が増える")
S_E12 = BARS([("単純に割ると", 69.0, GREY), ("浮かぶ氷", 2.3, BLUE), ("海面より下の氷", 8.5, BLUE), ("残り", 58.2, YEL)],
             title="69mから引くと（計算）", fmt="{}m", step=2)
S_E14 = POLAR("strip", step=2, tr="flash", labels=ANT_LABELS)
S_E16 = SECT("melt", step=2, labels=[(0.3, -1900, "海面より3,000m以上低い谷も", YEL)])

P["ch3"] = dict(title="第3章 消えた11m", cta=False, lines=[
    dict(id="e1", text="1つ目の理由は、海に浮かぶ氷です。", scene=S_E1),
    dict(id="e2", text="南極の周りには、陸から海へ張り出して浮かぶ、氷の板があります。"),
    dict(id="e3", text="コップの氷水を、思い出してください。", scene=S_E3),
    dict(id="e4", text="浮かんだ氷がとけても、水はあふれません。"),
    dict(id="e5", text="氷は、とけたあとの水と同じ重さぶん、もう水を押しのけているからです。"),
    dict(id="e6", text="北極の海の氷がとけても、海面がほとんど上がらないのは、このためです。", scene=S_E6),
    dict(id="e7", text="南極の浮かぶ氷は、計算すると2.3mぶんでした。", scene=S_E7),
    dict(id="e8", text="2つ目の理由は、海面より下にある氷です。", section=True, scene=S_E8),
    dict(id="e9", text="南極の氷の半分近くは、海面より低い岩の上に乗っています。"),
    dict(id="e10", text="その氷のうち、海面より下の部分は、もともと海の水を押しのけています。", scene=S_E10),
    dict(id="e11", text="だから、とけても、その分は海面を上げません。"),
    dict(id="e12", text="この分が8.5m。2つ合わせて約11m。69mから引くと、58mです。", scene=S_E12),
    dict(id="e13", text="では、氷をすべて取り去ると、南極はどんな姿なのか。", section=True),
    dict(id="e14", text="1つの大きな大陸ではありません。", scene=S_E14),
    dict(id="e15", text="東の大きな陸と、西のたくさんの島に分かれます。"),
    dict(id="e16", text="氷の下には、海面より3,000m以上低い谷まであります。", scene=S_E16),
])

# ---- 第4章 とかすのに要る熱 ------------------------------------------------------------------------------
S_F1 = POLAR("ice", step=3, tr="zoom")
S_F2 = CARD("334キロジュール", sub="氷1kgをとかす熱", note="水1kgを0℃から80℃に温めるのと同じくらい", view=WORLD, step=3)
S_F4 = CARD("174兆kW", sub="地球が受け止める太陽の光", view=WORLD, step=3)
S_F6 = CARD("1年半", sub="太陽の光を、1つ残らず南極の氷に注いでも", note="1.52年（計算）", view=WORLD, step=3, count=False)
S_F8 = CARD("1平方mあたり0.76W", sub="地球に少しずつたまっている熱", note="2006〜2020年の平均", view=WORLD, step=3)
S_F10 = BARS([("太陽の光を全部", 1.52, YEL), ("地球にたまる熱を全部", 681, BLUE)], title="南極の氷がとけるまで（計算）", fmt="{}年", step=3)
S_F12 = CARD("2,190億トン", sub="南極が1年に失った氷", note="2012〜2017年（IMBIE 2018）", view=WORLD, step=3, tr="whip")
S_F13 = ICONS("dome", 18, title="水にすると 東京ドーム 約18万杯", note="1つの絵が 1万杯", step=3)
S_F15 = CARD("11万年以上", sub="いまの速さが続いたら", note="2京5千兆トン ÷ 2,190億トン", view=WORLD, step=3, count=False)
S_F16 = BARS([("1992〜1997年", 490, GREY), ("2012〜2017年", 2190, RED)], title="南極が1年に失った氷（IMBIE 2018）", fmt="{:,}億トン", step=3)

P["ch4"] = dict(title="第4章 とかすのに要る熱", cta=False, lines=[
    dict(id="f1", text="では、この氷を全部とかすには、どれだけの熱が要るのか。", scene=S_F1),
    dict(id="f2", text="氷1kgをとかすには、334キロジュールの熱が要ります。", scene=S_F2),
    dict(id="f3", text="同じ1kgの水を、0℃から80℃まで温めるのと、同じくらいの熱です。"),
    dict(id="f4", text="地球が受け止める太陽の光は、174兆kW。", scene=S_F4),
    dict(id="f5", text="この光を、1つ残らず南極の氷に注いだとします。"),
    dict(id="f6", text="それでも、とけきるまでに1年半かかります。", scene=S_F6),
    dict(id="f7", text="実際には、太陽の光のほとんどは、地面や海を温めて、また宇宙へ出ていきます。"),
    dict(id="f8", text="地球に少しずつたまっている熱は、1平方mあたり0.76W。", scene=S_F8),
    dict(id="f9", text="小さな豆電球ほどの熱が、地球のすみずみで足されている計算です。"),
    dict(id="f10", text="これを全部、南極の氷に回しても、およそ680年かかります。", scene=S_F10),
    dict(id="f11", text="そして、実際の速さは、もっと遅い。", section=True),
    dict(id="f12", text="2012年から2017年、南極は1年に2,190億トンの氷を失いました。", scene=S_F12),
    dict(id="f13", text="水にすると、東京ドームおよそ18万杯ぶんです。", scene=S_F13),
    dict(id="f14", text="それでも、南極の氷全体から見れば、11万分の1。"),
    dict(id="f15", text="この速さが続けば、全部とけるのは11万年以上先です。", scene=S_F15),
    dict(id="f16", text="ただし、とける速さは、25年で4倍以上になっています。", scene=S_F16),
])

# ---- 第5章 答え ------------------------------------------------------------------------------------------
S_G1 = MAP(WORLD, FLOOD(rise_s=3.0, id="f_g"), step=4, tr="zoom")
S_G2 = CARD("＋7.4m", sub="グリーンランドの氷も、全部とけたら", note="南極と合わせて 約66m", view=(-42, 72, 60, 20), step=4)
S_G4 = dict(shot="cards", items=ANSWERS, n=1, view=WORLD, step=4, tr="flash")


def CARDS_N(n):
    return dict(shot="cards", items=ANSWERS, n=n, view=WORLD, step=4)


P["ch5"] = dict(title="第5章 答え", lines=[
    dict(id="g1", text="では、南極の氷が全部とけたら、世界はどうなるのか。", scene=S_G1),
    dict(id="g2", text="北のグリーンランドの氷も全部とけると、海はさらに7.4m上がります。", scene=S_G2),
    dict(id="g3", text="合わせて、およそ66mです。"),
    dict(id="g4", text="まとめます。", section=True, scene=S_G4),
    dict(id="g5", text="1つ目。海は58m上がり、大都市53のうち34で、中心が海の下になる。"),
    dict(id="g6", text="2つ目。南極の氷は2,722万立方km。平均の厚さは2,117m。", scene=CARDS_N(2)),
    dict(id="g7", text="3つ目。単純に割れば69m。浮かぶ氷と、海面より下の氷の分を引いて、58m。", scene=CARDS_N(3)),
    dict(id="g8", text="4つ目。とかすには、太陽の光を全部注いでも1年半かかる。", scene=CARDS_N(4)),
    dict(id="g9", text="5つ目。いまの速さなら11万年以上。ただ、その速さは上がっている。", scene=CARDS_N(5)),
    dict(id="g10", text="南極の氷は、すぐには消えない。でも、海の高さを決める大きな貯金なのです。", scene=MAP(WORLD, FLOOD(id="f_g2"), step=4, view_to=(100, 25, 160, 0))),
    dict(id="g11", text="次に世界地図を見たら、海ぞいの大きな町を数えてみてください。", scene=MAP(EASIA, FLOOD(id="f_ea2"), PIN(TOKYO, "東京", id="p_tk2"), PIN(SHANGHAI, "上海", id="p_sh3"), step=4)),
    dict(id="g12", text="その多くが、58mより低い所にあります。"),
])

# ---- ショート -------------------------------------------------------------------------------------------
WORLD_P = (110, 25, 80, 0)
EASIA_P = (120, 34, 14, 30)
JAPAN_P = (137.6, 35.2, 6, 35)

P["s1"] = dict(title="南極の氷が全部とけると、海は58m上がる", lines=[
    dict(id="a1", text="南極の氷が全部とけると、世界の海は58m上がります。", scene=MAP(WORLD_P, FLOOD(rise_s=3.5), LABEL((95, -5), "海面 ＋58m", 72, YEL, on="58m", count=True))),
    dict(id="a2", text="ビルなら、19階の高さです。", scene=ICONS("floor", 19, title="58m ＝ ビル約19階")),
    dict(id="a3", text="東京の中心は36m、大阪は5m。どちらも海の下です。", scene=MAP(JAPAN_P, FLOOD(id="f_jp"), PIN(TOKYO, "東京 36m", id="p_tk"), PIN(OSAKA, "大阪 5m", id="p_os", at=0.4), tr="whip")),
    dict(id="a4", text="北京も、海から150km離れているのに、中心は52m。", scene=MAP(EASIA_P, FLOOD(id="f_ea"), PIN(BEIJING, "北京 52m", id="p_bj"), PIN(SHANGHAI, "上海 11m", id="p_sh", at=0.5))),
    dict(id="a5", text="長江をさかのぼって、700km奥の武漢まで海になります。", scene=MAP((116.5, 31.0, 12, 30), FLOOD(id="f_wh"), PIN(WUHAN, "武漢 23m", id="p_wh"), LABEL((117.6, 29.4), "海から700km以上", 50, YEL, on="700km"))),
    dict(id="a6", text="人口500万人を超える都市53のうち、34で中心が58mより低い。", scene=ICONS("city", 53, title="人口500万人超の都市 53", hl=34, note="青：中心が58mより低い")),
    dict(id="a7", text="34の都市を合わせると、3億5千万人が住んでいます。"),
    dict(id="a8", text="海に沈む陸は、日本の30個ぶん。", scene=CARD("日本 30個ぶん", sub="海の下になる陸", note="1,134万平方km", view=WORLD_P, count=False)),
    dict(id="a9", text="ただ、それには、太陽の光を全部注いでも1年半かかる量の氷をとかす必要があります。", scene=POLAR("ice")),
])

P["s2"] = dict(title="南極の氷は、日本37個ぶんの広さで、厚さ2,117m", lines=[
    dict(id="b1", text="南極の氷は、日本の37個ぶんの広さがあります。", scene=POLAR("ice", labels=ANT_LABELS)),
    dict(id="b2", text="厚さは、平均で2,117m。", scene=POLAR("ice", line=True, title="まっすぐ切ると")),
    dict(id="b3", text="切ってみると、こうなります。", scene=SECT("ice")),
    dict(id="b4", text="富士山の高さの半分を超える氷が、大陸を覆っているのです。"),
    dict(id="b5", text="しかも氷の下の地面は、半分近くが海面より低い。", scene=SECT("below")),
    dict(id="b6", text="氷の重さで、大陸が押し下げられています。"),
    dict(id="b7", text="氷の体積は2,722万立方km。重さは2京5千兆トン。", scene=CARD("2京5千兆トン", sub="南極の氷の重さ", note="2,722万立方km", view=WORLD_P, count=False)),
    dict(id="b8", text="全部とけると、世界の海は58m上がります。", scene=MAP(WORLD_P, FLOOD(), LABEL((95, -5), "＋58m", 80, YEL, on="58m", count=True))),
])

P["s3"] = dict(title="南極の氷をとかしても、海は69mではなく58mしか上がらない", lines=[
    dict(id="h1", text="南極の氷を全部水にして、海に広げると69m。", scene=CARD("69m", sub="氷を水にして、海の広さで割ると", view=WORLD_P)),
    dict(id="h2", text="ところが、海が上がるのは58mです。", scene=BARS([("単純に割ると", 69.0, GREY), ("本当は", 58.2, YEL)], title="海面が上がる高さ（計算）", fmt="{}m")),
    dict(id="h3", text="11mは、どこへ消えたのか。"),
    dict(id="h4", text="1つは、海に浮かぶ氷の板です。", scene=POLAR("shelf", title="赤：海に浮かぶ氷")),
    dict(id="h5", text="浮かんだ氷は、とけても海をあふれさせません。", scene=GLASS("float", title="コップの氷水", note="とけても、あふれない")),
    dict(id="h6", text="もう1つは、海面より低い岩に乗った氷です。", scene=SECT("below", title="赤：海面より低い氷")),
    dict(id="h7", text="海面より下の部分は、もともと海の水を押しのけています。", scene=GLASS("rock", title="岩に乗った氷", note="上に出ていた分だけ増える")),
    dict(id="h8", text="浮かぶ氷が2.3m、海面より下の氷が8.5m。", scene=BARS([("浮かぶ氷", 2.3, BLUE), ("海面より下の氷", 8.5, BLUE)], title="引く分（計算）", fmt="{}m")),
    dict(id="h9", text="合わせて11m。だから58mなのです。"),
])

P["s4"] = dict(title="氷の下の南極は、1つの大陸ではない", lines=[
    dict(id="k1", text="氷を取り去ると、南極は1つの大陸ではありません。", scene=POLAR("ice", labels=ANT_LABELS)),
    dict(id="k2", text="南極の氷の厚さは、平均で2,117m。", scene=SECT("ice")),
    dict(id="k3", text="その下の地面は、半分近くが海面より低いのです。", scene=SECT("below")),
    dict(id="k4", text="氷を下から抜いていくと。", scene=POLAR("strip", labels=ANT_LABELS)),
    dict(id="k5", text="東は大きな陸。西は、たくさんの島に分かれます。"),
    dict(id="k6", text="いちばん低い谷は、海面より3,000m以上も下。", scene=SECT("melt", labels=[(0.5, -1900, "海面より3,000m以上低い谷", YEL)])),
    dict(id="k7", text="氷の重さで、大陸が押し下げられているからです。"),
    dict(id="k8", text="南極は、氷の重さで沈んだ、島と陸の集まりなのです。", scene=POLAR("bed", labels=ANT_LABELS)),
])

P["s5"] = dict(title="太陽の光を全部注いでも、南極の氷がとけるまで1年半", lines=[
    dict(id="m1", text="太陽の光を全部注いでも、南極の氷がとけるまで1年半かかります。", scene=POLAR("ice")),
    dict(id="m2", text="氷1kgをとかすのに、334キロジュール。", scene=CARD("334キロジュール", sub="氷1kgをとかす熱", note="水を0℃から80℃に温めるのと同じくらい", view=WORLD_P)),
    dict(id="m3", text="南極の氷は、2京5千兆トン。", scene=CARD("2京5千兆トン", sub="南極の氷の重さ", view=WORLD_P, count=False)),
    dict(id="m4", text="地球が受ける太陽の光、174兆kWを全部使っても、1年半。", scene=CARD("1年半", sub="太陽の光を全部注いでも", note="174兆kW", view=WORLD_P, count=False)),
    dict(id="m5", text="地球に少しずつたまる熱だけなら、およそ680年。", scene=BARS([("太陽の光を全部", 1.52, YEL), ("たまる熱を全部", 681, BLUE)], title="とけるまで（計算）", fmt="{}年")),
    dict(id="m6", text="いまの速さ、1年に2,190億トンなら、11万年以上かかります。", scene=CARD("11万年以上", sub="いまの速さが続いたら", note="1年 2,190億トン（2012〜2017年）", view=WORLD_P, count=False)),
    dict(id="m7", text="ただ、その速さは、25年で4倍以上になりました。", scene=BARS([("1992〜97年", 490, GREY), ("2012〜17年", 2190, RED)], title="1年に失った氷", fmt="{:,}億トン")),
])

# ---- 読み ------------------------------------------------------------------------------------------------
YOMI = [("1,134万平方km", "センヒャクサンジュウヨンマンヘイホウキロメートル"), ("1,383万平方km", "センサンビャクハチジュウサンマンヘイホウキロメートル"),
        ("2,722万立方km", "ニセンナナヒャクニジュウニマンリッポウキロメートル"), ("2京5千兆トン", "ニケイゴセンチョウトン"),
        ("174兆kW", "ヒャクナナジュウヨンチョウキロワット"), ("0.76W", "レイテンナナロクワット"), ("1平方m", "イチヘイホウメートル"),
        ("334キロジュール", "サンビャクサンジュウヨンキロジュール"), ("2,190億トン", "ニセンヒャクキュウジュウオクトン"),
        ("80℃", "ハチジュウド"), ("0℃", "レイド"), ("2.3m", "ニテンサンメートル"), ("8.5m", "ハッテンゴメートル"), ("7.4m", "ナナテンヨンメートル"),
        ("3億5千万人", "サンオクゴセンマンニン"), ("11万分の1", "ジュウイチマンブンノイチ"), ("何m", "なんメートル"), ("海の下", "うみのした"),
        ("武漢", "ぶかん"), ("長江", "ちょうこう")]


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
