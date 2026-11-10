"""青ヶ島(地理・型 B いる): 本編 5 章とショート 5 本の台本と画面。ch1〜ch5・s1〜s5 の ep.py がここから読む。
数字と出典は sim/facts.md(東京都・気象庁・東京電力パワーグリッド・国土交通省)。島の形は sim/measure.py(国土地理院の標高タイル)。
画面の作りはハワイの回(episodes/hawaii/parts.py)を写した。2〜3 行ごとに種類を変える(立体の地図・島の断面・地下の図・棒・数字)。"""
CREDIT = "地図: 国土地理院・NASA・Terrain Tiles"
RED, YEL, WHITE, BLUE = (240, 90, 80), (255, 214, 64), (255, 255, 255), (120, 190, 255)
GREY, GREEN, SAND = (170, 180, 200), (110, 200, 110), (226, 196, 140)

AOGA = (139.7635, 32.4575, 0.06, 35)
AOGA_TOP = (139.7635, 32.4575, 0.065, 0)
CALDERA = (139.7655, 32.4535, 0.032, 40)
HACHI = (139.78, 32.80, 2.2, 0)
TOKYO = (139.75, 34.05, 8.5, 0)

TOCHO, VILLAGE, HACHIJO = (139.6917, 35.6895), (139.7633, 32.4669), (139.7968, 33.1077)
MARUYAMA, TOP, PORT, FLOOR = (139.7665, 32.4532), (139.7592, 32.4585), (139.7590, 32.4465), (139.7680, 32.4545)
S_A, S_B = (139.7612, 32.476), (139.7695, 32.440)      # 集落→丸山→南へ、北北西から南南東に切る
S_KW = dict(zmax=620, zmin=-160, ends=[(0.03, "北（集落）"), (0.95, "南")])
S_LAB = [(0.25, 360, "集落"), (0.50, 210, "火口の底"), (0.63, 300, "丸山")]


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


def CARD(big, sub=None, note=None, view=AOGA, step=None, count=True, tr=None):
    d = dict(shot="card", big=big, sub=sub, note=note, view=view, step=step, count=count)
    if tr:
        d["tr"] = tr
    return d


def SLICE(step=None, tr=None, **kw):
    d = dict(shot="slice", a=S_A, b=S_B, step=step, title="青ヶ島を切る", labels=S_LAB, **S_KW)
    d.update(kw)
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


ANSWERS = [("火口の中に、148人の村がある", "崖に囲まれた、二重の火山の島"),
           ("水は、斜面で雨を受けて集める", "地下の水は塩水。サッカー場1面ぶんで足りる"),
           ("電気は、船で運ぶ油で作る", "太陽光は雲で揺れ、19kWまでしかつなげない"),
           ("船が出られるのは、1年の半分ほど", "野菜は、風をよける火口の底の畑で"),
           ("火口の熱で、塩を作る", "1785年の噴火では、50年あまり無人島に")]

P = {}

# ---- 第1章 火口の村 -------------------------------------------------------------------------------------
P["ch1"] = dict(title="第1章 火口の村", cta=False, lines=[
    dict(id="a1", text="東京から南へ358km。火山の火口の中に、人が住む島があります。", scene=MAP(TOKYO, LINE([TOCHO, VILLAGE], id="r_tk"), PIN(TOCHO, "東京"), PIN(VILLAGE, "青ヶ島", at=0.4),
         LABEL((140.5, 34.1), "358km", 64, YEL, on="358km"), step=0)),
    dict(id="a2", text="東京都、青ヶ島村。", scene=MAP(AOGA, PIN(VILLAGE, "青ヶ島村", id="p_v1"), step=0, tr="zoom")),
    dict(id="a3", text="人口は148人。日本でいちばん人の少ない村です。", scene=CARD("148人", sub="青ヶ島村の人口（2025年4月）", note="東京都保健医療局", step=0)),
    dict(id="a4", text="島の広さは5.96平方km。東京ドーム約127個ぶんです。"),
    dict(id="a5", text="島のまわりは、45度から70度の崖です。", scene=MAP(AOGA, LABEL((139.7545, 32.468), "崖", 60, YEL), LABEL((139.776, 32.444), "崖", 60, YEL, id="l_cl2"), step=0, view_to=(139.7635, 32.4575, 0.05, 45))),
    dict(id="a6", text="その内側に、大きな火口が開いています。", scene=SLICE(step=0)),
    dict(id="a7", text="火口の底の真ん中には、もう1つの山、丸山。"),
    dict(id="a8", text="火山の中に、もう1つ火山がある島です。", scene=MAP(CALDERA, PIN(MARUYAMA, "丸山"), step=0, tr="zoom")),
    dict(id="a9", text="ここで暮らす人の水と電気と食べ物は、どうしているのか。", style="question", sub="火口の島の暮らし\n【水・電気・食べ物】は？", scene=MAP(AOGA_TOP, step=0)),
    dict(id="a10", text="答えを先に言います。", section=True),
    dict(id="a11", text="水は、空から集めます。", scene=LENS(step=0, title="島の地下", lens_label="うすい真水")),
    dict(id="a12", text="電気は、船で運ぶ油で作ります。", scene=MAP(HACHI, LINE([HACHIJO, VILLAGE], id="r_h1"), PIN(HACHIJO, "八丈島"), PIN(VILLAGE, "青ヶ島", id="p_v2"), step=0, tr="whip")),
    dict(id="a13", text="食べ物は、船と、火口の底の畑から。", scene=SLICE(step=0, labels=S_LAB + [(0.52, 330, "畑", GREEN)])),
    dict(id="a14", text="島の形と数字で、1つずつ確かめます。", scene=MAP(AOGA, step=0, view_to=(139.7635, 32.4575, 0.075, 25))),
])

# ---- 第2章 水 -------------------------------------------------------------------------------------------
P["ch2"] = dict(title="第2章 水", cta=False, lines=[
    dict(id="b1", text="青ヶ島に降る雨は、1年に約2,600mm。", scene=BARS([("青ヶ島", 2602, BLUE), ("日本の平均", 1700, GREY)], title="1年に降る雨（mm）", fmt="{:,}", step=1)),
    dict(id="b2", text="日本の平均の、約1.5倍です。"),
    dict(id="b3", text="ところが、島には真水の水源がありません。", scene=MAP(AOGA, step=1, tr="zoom")),
    dict(id="b4", text="地下の水も、塩水なのです。", scene=LENS(step=1, title="島の地下", lens_label="うすい真水")),
    dict(id="b5", text="小さな島では、しみこんだ雨が、すぐに海の水とまざります。"),
    dict(id="b6", text="そこで島の人は、雨が地面にしみこむ前に受けます。", scene=SLICE(step=1, labels=S_LAB[:1] + [(0.33, 470, "雨を受ける斜面", BLUE)])),
    dict(id="b7", text="山の斜面をおおって、雨を水道の池へ流すのです。"),
    dict(id="b8", text="どのくらいの広さがあれば足りるのか、計算します。", section=True, scene=MAP(AOGA_TOP, PIN(VILLAGE, "集落", id="p_v8"), step=1)),
    dict(id="b9", text="1人が1日に使う水は、約230リットル。", scene=CARD("230リットル", sub="1人が1日に使う水", note="国土交通省", step=1, count=False)),
    dict(id="b10", text="148人なら、1年で約1万2,400立方mです。", scene=CARD("1万2,400立方m", sub="148人が1年に使う水", step=1, count=False)),
    dict(id="b11", text="平年の雨なら、約4,800平方mで受ければ足ります。", scene=BARS([("平年 2,602mm", 4774, BLUE), ("2023年 1,652mm", 7519, SAND), ("サッカー場1面", 7140, GREEN)], title="雨を受けるのに要る広さ（平方m）", fmt="{:,}", step=1)),
    dict(id="b12", text="雨の少なかった2023年は、1,652mm。それでも約7,500平方m。"),
    dict(id="b13", text="サッカー場、およそ1面ぶんです。"),
    dict(id="b14", text="島に降る雨の、たった1,250分の1です。", scene=CARD("1,250分の1", sub="島に降る雨のうち、使う量", step=1, count=False)),
    dict(id="b15", text="水が少ないのではありません。ためる場所がないのです。", scene=MAP(AOGA_TOP, step=1)),
    dict(id="b16", text="じつは昔、火口の底には池が2つありました。", section=True, scene=MAP(CALDERA, LABEL(FLOOR, "昔の池", 54, BLUE), step=1, tr="zoom")),
    dict(id="b17", text="その池は、なぜ消えたのか。最後の章で話します。"),
])

# ---- 第3章 電気 -----------------------------------------------------------------------------------------
P["ch3"] = dict(title="第3章 電気", cta=False, lines=[
    dict(id="c1", text="島の電気を作る発電所は、1つだけです。", scene=MAP(AOGA, PIN(VILLAGE, "集落", id="p_v3"), step=2, tr="zoom")),
    dict(id="c2", text="油を燃やして電気を作り、力は760kW。", scene=CARD("760kW", sub="青ヶ島の発電所", note="東京電力パワーグリッド（2026年）", step=2)),
    dict(id="c3", text="八丈島の発電所の、約20分の1です。", scene=BARS([("八丈島", 15100, GREY), ("青ヶ島", 760, YEL)], title="島の発電所の力（kW）", fmt="{:,}", step=2)),
    dict(id="c4", text="燃やす油は、船で運んできます。", scene=MAP(HACHI, LINE([HACHIJO, VILLAGE], id="r_h3"), PIN(HACHIJO, "八丈島", id="p_h3"), PIN(VILLAGE, "青ヶ島", id="p_v4"), step=2, tr="whip")),
    dict(id="c5", text="それなら、太陽の光を使えばよいのでは。"),
    dict(id="c6", text="ところが、太陽光の発電をつなげる上限は、19kWでした。", scene=CARD("19kW", sub="太陽光をつなげる上限（2014年）", note="東京電力", step=2)),
    dict(id="c7", text="発電所の40分の1です。", scene=BARS([("発電所", 760, GREY), ("太陽光の上限", 19, YEL)], title="青ヶ島の電気（kW）", fmt="{:,}", step=2)),
    dict(id="c8", text="理由は、雲です。", section=True, scene=MAP(AOGA_TOP, step=2)),
    dict(id="c9", text="雲が通ると、太陽光の電気は、数秒で大きく減ります。"),
    dict(id="c10", text="大きな町の電気の網なら、この揺れを吸いこめます。"),
    dict(id="c11", text="小さな島の発電所では受けとめきれず、電気の質がくずれます。", scene=CARD("数秒", sub="雲で太陽光の電気が揺れる速さ", note="東京電力の説明資料", step=2, count=False)),
    dict(id="c12", text="島が小さいほど、晴れの日の光も使いにくいのです。", scene=MAP(AOGA, step=2, view_to=(139.7635, 32.4575, 0.08, 20))),
])

# ---- 第4章 船と畑 ---------------------------------------------------------------------------------------
P["ch4"] = dict(title="第4章 船と畑", cta=False, lines=[
    dict(id="d1", text="油も、食べ物も、多くは八丈島から船で来ます。", scene=MAP(HACHI, LINE([HACHIJO, VILLAGE], id="r_h4"), PIN(HACHIJO, "八丈島", id="p_h4"), PIN(VILLAGE, "青ヶ島", id="p_v5"), step=3, tr="zoom")),
    dict(id="d2", text="八丈島から南へ約70km。船で約3時間です。", scene=MAP(HACHI, LINE([HACHIJO, VILLAGE], id="r_h4"), PIN(HACHIJO, "八丈島", id="p_h4"), PIN(VILLAGE, "青ヶ島", id="p_v5"),
         LABEL((139.95, 32.80), "約70km", 60, YEL, on="70km"), step=3)),
    dict(id="d3", text="ところが、この船が出られるのは、1年の半分ほど。", scene=CARD("50〜60%", sub="八丈島〜青ヶ島の船が出られる割合", note="東京都保健医療局", step=3, count=False)),
    dict(id="d4", text="港は崖の下にあり、波が高いと船をつけられません。", scene=MAP(AOGA, PIN(PORT, "港"), step=3, view_to=(139.761, 32.450, 0.03, 45))),
    dict(id="d5", text="東京都は今も、防波堤を作って、船が出られる日を増やそうとしています。"),
    dict(id="d6", text="人を運ぶヘリコプターは、毎日飛びます。八丈島から20分。", scene=CARD("9人", sub="ヘリコプターに乗れる人数", note="東京都八丈支庁", step=3)),
    dict(id="d7", text="でも、乗れるのは9人までです。"),
    dict(id="d8", text="そこで、野菜は島で作ります。", section=True, scene=MAP(CALDERA, PIN(MARUYAMA, "丸山", id="p_m4"), step=3, tr="zoom")),
    dict(id="d9", text="畑があるのは、火口の底です。", scene=SLICE(step=3, labels=S_LAB + [(0.52, 330, "畑", GREEN)])),
    dict(id="d10", text="底は、標高100mほど。まわりの山は、400m近くあります。"),
    dict(id="d11", text="底から見ると、高さ300m近い壁に、ぐるりと囲まれています。"),
    dict(id="d12", text="この壁が、海からの強い風をさえぎります。", scene=MAP(CALDERA, step=3, view_to=(139.7655, 32.4535, 0.028, 55))),
    dict(id="d13", text="船が来ない日に足りなくなる野菜を、この畑で育てているのです。"),
])

# ---- 第5章 答え -----------------------------------------------------------------------------------------
CARDS_N = lambda n: dict(shot="cards", items=ANSWERS, n=n, view=AOGA, step=4)  # noqa: E731
P["ch5"] = dict(title="第5章 答え", cta=True, lines=[
    dict(id="e1", text="火口の底には、もう1つの恵みがあります。", scene=MAP(CALDERA, PIN(MARUYAMA, "丸山", id="p_m5"), step=4, tr="zoom")),
    dict(id="e2", text="丸山のまわりでは、今も地面から湯気が出ています。島の言葉で、ひんぎゃ。"),
    dict(id="e3", text="その熱で海の水を煮つめて、塩を作っています。", scene=CARD("ひんぎゃの塩", sub="火山の熱で作る塩", note="東京都八丈支庁", step=4, count=False)),
    dict(id="e4", text="でも火山は、恵みであり、こわさでもあります。", section=True, scene=SLICE(step=4)),
    dict(id="e5", text="1785年、この火口で噴火が起きました。"),
    dict(id="e6", text="島にいた327人のうち、130人から140人が亡くなったとされます。", scene=CARD("327人", sub="1785年の噴火のとき島にいた人", note="気象庁", step=4)),
    dict(id="e7", text="残った人は八丈島へ逃げ、島は50年あまり、無人島になりました。", scene=MAP(HACHI, LINE([VILLAGE, HACHIJO], id="r_h5"), PIN(HACHIJO, "八丈島", id="p_h5"), PIN(VILLAGE, "青ヶ島", id="p_v6"), step=4, tr="whip")),
    dict(id="e8", text="火口の底の2つの池を、溶岩で埋めたのも、この噴火です。", scene=MAP(CALDERA, LABEL(FLOOR, "昔の池", 54, BLUE, id="l_ike5"), step=4, tr="zoom")),
    dict(id="e9", text="それでも人は島へ戻り、いまも148人が暮らしています。", scene=MAP(AOGA, PIN(VILLAGE, "集落", id="p_v7"), step=4)),
    dict(id="e10", text="まとめます。", section=True, scene=CARDS_N(1)),
    dict(id="e11", text="1つ目。火口の中に、148人の村がある。崖に囲まれた、二重の火山の島です。"),
    dict(id="e12", text="2つ目。地下の水は塩水。水は、斜面で雨を受けて集める。サッカー場1面ぶんで足りる。", scene=CARDS_N(2)),
    dict(id="e13", text="3つ目。電気は、船で運ぶ油で作る。太陽光は雲で揺れ、19kWまでしかつなげない。", scene=CARDS_N(3)),
    dict(id="e14", text="4つ目。船が出られるのは、1年の半分ほど。野菜は、風をよける火口の底の畑で育てる。", scene=CARDS_N(4)),
    dict(id="e15", text="5つ目。火口の熱で塩を作る。そして1785年の噴火では、50年あまり無人島になった。", scene=CARDS_N(5)),
    dict(id="e16", text="青ヶ島の水は空から、電気は船の油から、野菜は火口の底から来ていました。", scene=MAP(AOGA, step=4, view_to=(139.7635, 32.4575, 0.075, 30))),
    dict(id="e17", text="次に蛇口をひねったら、その水がどこで集められたかを、思い出してください。", scene=MAP(AOGA_TOP, step=4)),
])

# ---- ショート -------------------------------------------------------------------------------------------
AOGA_P = (139.7635, 32.4575, 0.045, 35)
CALDERA_P = (139.7655, 32.4535, 0.022, 40)
HACHI_P = (139.78, 32.80, 0.9, 0)

P["s1"] = dict(title="火口の中に、148人が暮らす村がある", lines=[
    dict(id="k1", text="東京都には、火山の火口の中に人が住む島があります。", scene=MAP(AOGA_P, PIN(VILLAGE, "青ヶ島村"))),
    dict(id="k2", text="青ヶ島。人口は148人。日本でいちばん人の少ない村です。", scene=CARD("148人", sub="青ヶ島村の人口（2025年4月）", note="東京都保健医療局", view=AOGA_P)),
    dict(id="k3", text="島のまわりは、45度から70度の崖。", scene=MAP(AOGA_P, LABEL((139.7555, 32.467), "崖", 60, YEL), view_to=(139.7635, 32.4575, 0.04, 45))),
    dict(id="k4", text="その内側に大きな火口があり、真ん中に、もう1つの山があります。", scene=SLICE()),
    dict(id="k5", text="火口の底は、標高100mほど。まわりの壁は300m近くあります。"),
    dict(id="k6", text="この壁が風をさえぎるので、火口の底では畑を作っています。", scene=MAP(CALDERA_P, PIN(MARUYAMA, "丸山"), tr="zoom")),
])

P["s2"] = dict(title="地下の水が塩水の島。水はサッカー場1面ぶんの斜面から", lines=[
    dict(id="m1", text="東京都の青ヶ島には、真水の水源がありません。", scene=MAP(AOGA_P, PIN(VILLAGE, "青ヶ島村", id="p_vm"))),
    dict(id="m2", text="地下の水まで、塩水なのです。", scene=LENS(title="島の地下", lens_label="うすい真水")),
    dict(id="m3", text="そこで、山の斜面をおおって、雨を水道の池へ流します。", scene=SLICE(labels=S_LAB[:1] + [(0.33, 470, "雨を受ける斜面", BLUE)])),
    dict(id="m4", text="148人が1年に使う水は、約1万2,400立方m。", scene=CARD("1万2,400立方m", sub="148人が1年に使う水", view=AOGA_P, count=False)),
    dict(id="m5", text="雨の少ない年でも、約7,500平方mで受ければ足ります。サッカー場1面ぶんです。", scene=BARS([("雨の少ない年", 7519, BLUE), ("サッカー場1面", 7140, GREEN)], title="雨を受ける広さ（平方m）", fmt="{:,}")),
    dict(id="m6", text="水がないのではなく、ためる場所がない島なのです。", scene=MAP(AOGA_P, tr="whip")),
])

P["s3"] = dict(title="太陽光が19kWしかつなげない島", lines=[
    dict(id="n1", text="東京都の青ヶ島では、太陽光の発電をつなげる上限が、19kWでした。", scene=CARD("19kW", sub="太陽光をつなげる上限（2014年）", note="東京電力", view=AOGA_P)),
    dict(id="n2", text="島の電気は、油を燃やす発電所が1つだけ。力は760kWです。", scene=BARS([("発電所", 760, GREY), ("太陽光の上限", 19, YEL)], title="青ヶ島の電気（kW）", fmt="{:,}")),
    dict(id="n3", text="理由は、雲です。", scene=MAP(AOGA_P)),
    dict(id="n4", text="雲が通ると、太陽光の電気は、数秒で大きく減ります。"),
    dict(id="n5", text="小さな発電所では、その揺れを受けとめきれません。", scene=CARD("数秒", sub="雲で太陽光の電気が揺れる速さ", note="東京電力の説明資料", view=AOGA_P, count=False)),
    dict(id="n6", text="だから島の電気は、今も船で運ぶ油で作られています。", scene=MAP(HACHI_P, LINE([HACHIJO, VILLAGE], id="r_n"), PIN(HACHIJO, "八丈島"), PIN(VILLAGE, "青ヶ島", id="p_vn"), tr="whip")),
])

P["s4"] = dict(title="船が出られるのは1年の半分。野菜は火口の底で", lines=[
    dict(id="q1", text="東京都の青ヶ島へ行く船は、1年の半分ほどしか出られません。", scene=MAP(HACHI_P, LINE([HACHIJO, VILLAGE], id="r_q"), PIN(HACHIJO, "八丈島"), PIN(VILLAGE, "青ヶ島", id="p_vq"))),
    dict(id="q2", text="八丈島から約70km。出られる割合は、1年に50〜60%です。", scene=CARD("50〜60%", sub="船が出られる割合", note="東京都保健医療局", view=HACHI_P, count=False)),
    dict(id="q3", text="港は崖の下にあり、波が高いと船をつけられないのです。", scene=MAP(AOGA_P, PIN(PORT, "港"), view_to=(139.761, 32.450, 0.025, 45))),
    dict(id="q4", text="そこで、野菜は島で作ります。畑があるのは、火口の底。", scene=SLICE(labels=S_LAB + [(0.52, 330, "畑", GREEN)])),
    dict(id="q5", text="300m近い壁が、海からの強い風をさえぎります。"),
    dict(id="q6", text="船が来ない日に足りなくなる野菜を、この畑で育てているのです。", scene=MAP(CALDERA_P, PIN(MARUYAMA, "丸山", id="p_mq"), tr="zoom")),
])

P["s5"] = dict(title="噴火で50年あまり無人島になった、東京の島", lines=[
    dict(id="r1", text="東京都の青ヶ島は、50年あまり、無人島だったことがあります。", scene=MAP(AOGA_P, PIN(VILLAGE, "青ヶ島", id="p_vr"))),
    dict(id="r2", text="1785年、島の火口で噴火が起きました。", scene=SLICE()),
    dict(id="r3", text="島にいた327人のうち、130人から140人が亡くなったとされます。", scene=CARD("327人", sub="噴火のとき島にいた人", note="気象庁", view=AOGA_P)),
    dict(id="r4", text="残った人は、70km北の八丈島へ逃げました。", scene=MAP(HACHI_P, LINE([VILLAGE, HACHIJO], id="r_r"), PIN(HACHIJO, "八丈島"), PIN(VILLAGE, "青ヶ島", id="p_vr2"), tr="whip")),
    dict(id="r5", text="今も火口の山のまわりでは、地面から湯気が出ています。", scene=MAP(CALDERA_P, PIN(MARUYAMA, "丸山", id="p_mr"), tr="zoom")),
    dict(id="r6", text="島の人はその熱で、海の水から塩を作っています。", scene=CARD("ひんぎゃの塩", sub="火山の熱で作る塩", note="東京都八丈支庁", view=CALDERA_P, count=False)),
])

# ---- 読み ------------------------------------------------------------------------------------------------
YOMI = [("1万2,400立方m", "いちまんにせんよんひゃくりっぽうめーとる"), ("1,250分の1", "せんにひゃくごじゅうぶんのいち"), ("40分の1", "よんじゅうぶんのいち"),
        ("20分の1", "にじゅうぶんのいち"), ("9人", "きゅうにん"), ("4,800平方m", "ヨンセンハッピャクヘイホウメートル"), ("7,500平方m", "ナナセンゴヒャクヘイホウメートル"),
        ("5.96平方km", "ゴーテンキューロクヘイホウキロメートル"), ("2,600mm", "ニセンロッピャクミリ"), ("1,652mm", "センロッピャクゴジュウニミリ"),
        ("358km", "サンビャクゴジュウハッキロ"), ("70km", "ナナジュッキロ"), ("760kW", "ナナヒャクロクジュッキロワット"), ("19kW", "ジュウキュウキロワット"),
        ("230リットル", "ニヒャクサンジュウリットル"), ("1,250分の1", "センニヒャクゴジュウブンノイチ"), ("40分の1", "ヨンジュウブンノイチ"), ("20分の1", "ニジュウブンノイチ"),
        ("1.5倍", "イッテンゴバイ"), ("50〜60%", "ゴジュッパーセントからロクジュッパーセント"), ("45度から70度", "ヨンジュウゴドからナナジュウド"),
        ("148人", "ヒャクヨンジュウハチニン"), ("327人", "サンビャクニジュウナナニン"), ("130人から140人", "ヒャクサンジュウニンからヒャクヨンジュウニン"), ("9人", "キュウニン"),
        ("1785年", "センナナヒャクハチジュウゴネン"), ("2023年", "ニセンニジュウサンネン"), ("50年あまり", "ゴジュウネンあまり"), ("約127個", "ヤクヒャクニジュウナナコ"),
        ("100m", "ヒャクメートル"), ("400m", "ヨンヒャクメートル"), ("300m", "サンビャクメートル"), ("3時間", "サンジカン"), ("20分", "ニジュップン"),
        ("青ヶ島", "アオガシマ"), ("八丈島", "ハチジョウジマ"), ("丸山", "マルヤマ"), ("ひんぎゃ", "ヒンギャ"), ("煮つめ", "につめ"), ("蛇口", "じゃぐち"),
        ("1つ目", "ひとつめ"), ("2つ目", "ふたつめ"), ("3つ目", "みっつめ"), ("4つ目", "よっつめ"), ("5つ目", "いつつめ"), ("2つ", "ふたつ"), ("1つ", "ひとつ"), ("1面", "いちめん"),
        ("日本", "にほん"), ("無人島", "むじんとう"), ("防波堤", "ぼうはてい"), ("の底", "のそこ")]


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
