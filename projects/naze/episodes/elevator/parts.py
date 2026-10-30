"""宇宙エレベーター(ケーブルは自分の重さで切れないか): 本編 6 章とショート 5 本の台本と画面。ch1〜ch6・s1〜s5 の ep.py がここから読む。
台本は scripts.md(確定。一字も変えない)、出典と計算は research.md。作品・実機の写真は使わない。図は全部コードで描く(AI 絵は作らない)。
足したのは読みの say= と字幕の改行・強調だけ。
出典: 大林組の構想=総務省「宙を拓くタスクフォース」資料2-3(2018年11月)、地球の重力定数・恒星日から自分で計算、
鋼=日本製鉄 季刊誌2015年11月号、炭素繊維=東レ T1100G、CNTの束=Bai et al. Nature Nanotechnology 2018、グラフェン=Lee et al. Science 2008。
"""
import re

CREDIT = "大林組の構想（総務省資料）・地球の重力定数で自分で計算"
CREDIT_V = "地球の重力定数と素材の強さで自分で計算"

GREEN, YEL, RED, WHITE, DIM = "green", "yel", "red", "white", "dim"
AMBER = (240, 170, 70)
GREY = (170, 178, 192)
GRN = (110, 220, 140)
BLU = (90, 170, 235)
RD = (240, 90, 80)
VIO = (185, 140, 245)
TEAL = (80, 210, 190)
YL = (255, 214, 64)


def K(kind, **kw):
    return dict(kind=kind, **kw)


def CARD(*rows):
    return dict(kind="formula", rows=list(rows))


def EXPCARD(n, text):
    return dict(kind="formula", rows=[(f"実験{n}", 130, YEL), (text, 66, WHITE)])


def QBLANK():
    return dict(kind="formula", rows=[])


# 切れる長さ(素材の性質)の横棒の行。値は km。台本の数字だけを使う
STEEL = ("鋼", 23.0, None, "約23km", GREY)
KEV = ("ケブラー", 244, None, "約240km", AMBER)
CF = ("炭素繊維", 399, None, "約400km", BLU)
CNT = ("ナノチューブの糸", 690, None, "約690km", TEAL)
BUN = ("ナノチューブの束", 6275, None, "約6,300km", GRN)
GRA = ("グラフェン（測定のみ）", 5900, None, "約5,900km相当", VIO)
# ケーブルに要る長さ(ケーブル側の必要)
N4940 = ("要る長さ（太さ一定）", 4937.7, None, "約4,940km", RD)
N2140 = ("要る長さ（10倍の枠）", 2140, None, "約2,140km", RD)
N1070 = ("要る長さ（100倍の枠）", 1070, None, "約1,070km", RD)
N4290 = ("要る長さ（安全率2）", 4290, None, "約4,290km", RD)
M2140 = (2140, "ケーブルに要る長さ（10倍の枠）約2,140km", RD)


def M(rows, marks=(), head=None, note=None, room=False, done=False, vmax=7000, foot=None, ncol=RD):
    return K("meter", rows=list(rows), marks=list(marks), head=head, note=note, room=room, done=done, vmax=vmax, foot=foot, ncol=ncol)


def TABLE(rows, old=0, room=False, head="実験の結果"):
    return K("table", rows=list(rows), old=old, room=room, head=head)


T1 = ("実験1", "鋼　太さ一定", "×", "約215倍足りない")
T2 = ("実験2", "鋼　先細り（10倍の枠）", "×", "約90倍足りない")
T3 = ("実験3", "ケブラー・炭素繊維", "×", "炭素繊維で約5.4倍足りない")
T4a = ("実験4", "ナノチューブの糸", "×", "約3.1倍足りない")
T4b = ("", "ナノチューブの束", "○", "枠に入る（余裕 約3倍）")
T4c = ("", "グラフェン", "△", "測定のみ")


def CABLE(stage, **kw):
    return K("cable", stage=stage, **kw)


def GC(stage, **kw):
    return K("gcurve", stage=stage, **kw)


def TAPER(**kw):
    return K("taper", **kw)


def BIG(big, sub, **kw):
    return K("big", big=big, sub=sub, **kw)


def AREAS(stage):
    return K("areas", stage=stage)


def LAT(mode):
    return K("lattice", mode=mode)


P = {}


P["ch1"] = dict(title="第1章 3万6千kmの糸", cta=False, lines=[
    dict(id="c1", text="鋼のケーブルは、上から垂らすと、約23kmで自分の重さで切れます。", scene=K("hang")),
    dict(id="c2", text="約23km。山手線を1周するより、短い距離です。", scene=K("loop")),
    dict(id="c3", text="宇宙エレベーターは、地上から宇宙へ、ケーブルを伸ばす構想です。", scene=CABLE(0)),
    dict(id="c4", text="行き先は、静止軌道。地球の自転と同じ周期で回り、真上に止まって見える場所です。", scene=CABLE(1)),
    dict(id="c5", text="高さは約3万6千km。地球1周の、およそ9割にあたります。", scene=M([("地球1周", 10, None, "10割", GREY), ("静止軌道の高さ", 9, None, "約9割", YL)], vmax=10, head="高さを地球1周と比べる")),
    dict(id="c6", text="大林組という会社が、この構想を資料にまとめています。2018年の資料です。", scene=CARD(("大林組（おおばやしぐみ）の構想", 62, YEL), ("2018年の資料", 80, WHITE))),
    dict(id="c7", text="ケーブルの全長は9万6千km。静止軌道より上の、おもりまで含めた長さです。", scene=M([("静止軌道まで", 3.6, None, "約3万6千km", YL), ("全長（おもりまで）", 9.6, None, "約9万6千km", AMBER)], vmax=10, head="ケーブルの全長")),
    dict(id="c8", text="目指すのは2050年。建設費は、10兆6,600億円と推計されています。", scene=CARD(("目指すのは", 56, WHITE), ("2050年", 130, YEL), ("建設費の推計　10兆6,600億円", 56, WHITE))),
    dict(id="c9", text="このケーブルが自分の重さで切れないために、どんな強さが要るのか。", scene=QBLANK(), style="question", sub="このケーブルが自分の重さで\n切れないために、\n【どんな強さ】が要るのか"),
    dict(id="c10", text="前の動画では、ロケットは荷物を、打ち上げの重さの約4%しか運べないと計算しました。", scene=CARD(("前の動画（ロケット）", 60, DIM), ("荷物は打ち上げの重さの約4%", 64, YEL))),
    dict(id="c11", text="ロケットを使わずに上がる道は、ないのか。", scene=CARD(("ロケットを使わずに", 70, WHITE), ("上がる道は、ないのか", 100, YEL))),
    dict(id="c12", text="強さを測る、ものさしを決めます。同じ素材の糸を上から垂らして、自分の重さで切れる長さ。", scene=CARD(("ものさし", 120, YEL), ("同じ素材の糸を上から垂らして", 56, WHITE), ("自分の重さで切れる長さ", 64, WHITE)), section=True),
    dict(id="c13", text="重力は、地上のままで数えます。以後、これを「切れる長さ」と呼びます。鋼は約23kmです。", scene=CARD(("切れる長さ", 130, YEL), ("鋼　約23km", 100, WHITE), ("重力は地上のまま", 48, DIM))),
    dict(id="c14", text="計算の置き方です。赤道の上で、真上にまっすぐ、ケーブルを1本。", scene=CABLE(2, still=True)),
    dict(id="c15", text="乗り物も荷物も、風も入れません。ケーブルの重さだけを数えます。", scene=CARD(("乗り物も荷物も風も入れない", 60, WHITE), ("ケーブルの重さだけ", 100, YEL))),
    dict(id="c16", text="だから、これから出る数字は、最低ラインです。実際は、もっと厳しくなります。", scene=CARD(("これから出る数字は", 56, WHITE), ("最低ライン", 130, YEL), ("実際は、もっと厳しい", 56, DIM))),
    dict(id="c17", text="地球の重力と自転は、公表されている定数で計算しました。素材の強さは、メーカーや論文の値です。", scene=CARD(("重力と自転　公表されている定数", 54, WHITE), ("素材の強さ　メーカーや論文の値", 54, WHITE))),
    dict(id="c18", text="素材を1つずつ、計算で試します。実験していきます。", scene=TABLE([("実験1", "鋼　太さ一定", "？", ""), ("実験2", "鋼　先細り", "？", ""), ("実験3", "ケブラー・炭素繊維", "？", ""), ("実験4", "実験室の素材", "？", ""), ("実験5", "長いケーブルにすると", "？", "")], head="素材ごとに、枠に入る？")),
])
P["ch2"] = dict(title="第2章 実験1 太さ一定の鋼", cta=False, lines=[
    dict(id="c1", text="実験1。まず何も考えず、鋼のケーブルを、太さ一定のまま伸ばします。", scene=EXPCARD(1, "太さ一定の鋼"), section=True, exp=1),
    dict(id="c2", text="使うのは、明石海峡大橋と同じ級の鋼線。1平方ミリに、約180kgを吊るせる強さです。", scene=CARD(("明石海峡大橋と同じ級の鋼線", 60, WHITE), ("1平方ミリで約180kg", 100, YEL), ("吊るせる強さ", 56, DIM))),
    dict(id="c3", text="1平方ミリとは、直径1.1mmほどの針金の断面です。", scene=K("wire")),
    dict(id="c4", text="この鋼の切れる長さは、約23km。", scene=M([STEEL], head="切れる長さ")),
    dict(id="c5", text="では、3万6千kmのケーブルに、どれだけの長さが要るのか。求めます。", scene=CARD(("ケーブルに要る長さを", 66, WHITE), ("求める", 120, YEL))),
    dict(id="c6", text="「ケーブルに要る長さ」とは、素材の切れる長さが、最低でもそれだけ要る、という数です。", scene=CARD(("ケーブルに要る長さ", 90, YEL), ("素材の切れる長さが", 56, WHITE), ("最低でもそれだけ要る、という数", 56, WHITE))),
    dict(id="c7", text="地上の重力のままなら、3万6千km分の重さがかかります。でも、実際は違います。", scene=GC(0)),
    dict(id="c8", text="上へ行くほど、重力が弱くなるからです。静止軌道では、地上の約2%しかありません。", scene=GC(1)),
    dict(id="c9", text="もう1つ。地球が回っているので、ケーブルは外へ振り回されます。この力を、遠心力といいます。", scene=GC(2)),
    dict(id="c10", text="静止軌道では、重力と遠心力が、ちょうど同じ強さ。打ち消し合います。", scene=GC(3)),
    dict(id="c11", text="高さごとに、重力と遠心力の差を足していきます。", scene=GC(4)),
    dict(id="c12", text="結果、一番上にかかる負担は、同じ素材のケーブルを、4,940kmぶん垂らしたのと同じです。"),
    dict(id="c13", text="3万6千kmの、7分の1ほどです。", scene=GC(5)),
    dict(id="c14", text="ケーブルに要る長さは、約4,940km。鋼の切れる長さは、約23km。", scene=M([N4940, STEEL], head="ケーブルに要る長さ と 鋼の切れる長さ", room=True)),
    dict(id="c15", text="割ると、約215倍。鋼では、215倍足りません。失敗です。", scene=M([N4940, STEEL], head="ケーブルに要る長さ と 鋼の切れる長さ", room=True, done=True, note="鋼は約215倍足りない")),
    dict(id="c16", text="太さを2倍にしても、変わりません。太くした分、重くなるからです。切れる長さは、素材で決まります。", scene=K("twothread")),
    dict(id="c17", text="太さでは、直せない。直せるのは、太さの配分です。", scene=TABLE([T1])),
])
P["ch3"] = dict(title="第3章 実験2 先細りにする", cta=False, lines=[
    dict(id="c1", text="実験2。ケーブルを、先細りにします。", scene=EXPCARD(2, "先細りにする"), section=True, exp=2),
    dict(id="c2", text="地上が細く、上ほど太いケーブル。この形を、専門ではテーパーといいます。", scene=TAPER()),
    dict(id="c3", text="上のほうは、下の全部の重さを支えます。だから、上ほど太くします。"),
    dict(id="c4", text="求めるのは、地上に対する、一番上の断面積の倍率。断面積とは、ケーブルを輪切りにした面積です。", scene=CARD(("断面積", 100, YEL), ("ケーブルを輪切りにした面積", 56, WHITE), ("地上に対する、一番上の倍率を求める", 48, DIM))),
    dict(id="c5", text="輪切りの面積あたりの力を見ます。どの高さでも限界ちょうどになるよう、太さを決めます。", scene=CARD(("輪切りの面積あたりの力", 60, WHITE), ("どの高さでも限界ちょうど", 70, YEL), ("になるよう、太さを決める", 56, WHITE))),
    dict(id="c6", text="鋼で計算します。一番上の断面積は、地上の10の93乗倍。", scene=BIG("10の93乗倍", "鋼で計算した　一番上の断面積 ÷ 地上の断面積", room=True)),
    dict(id="c7", text="約2のあとに、0が93個。地上が1平方ミリなら、上は宇宙の広さでも収まりません。", scene=BIG("10の93乗倍", "約2のあとに、0が93個", zeros=True, room=True)),
    dict(id="c8", text="失敗です。鋼は、先細りにしても、この形になりません。"),
    dict(id="c9", text="ここで、枠を置きます。ここでは、上の断面積は地上の10倍までと置きます。", scene=TAPER(frame=True, head="枠　上の断面積は地上の10倍まで")),
    dict(id="c10", text="この枠に収めるなら、ケーブルに要る長さは、約2,140km。", scene=M([N4940, N2140, STEEL], head="ケーブルに要る長さが縮む")),
    dict(id="c11", text="太さ一定のときの、約4割です。"),
    dict(id="c12", text="鋼の切れる長さは、23km。枠に収めても、約90倍足りません。", scene=M([N4940, N2140, STEEL], head="ケーブルに要る長さが縮む", done=True, note="鋼は約90倍足りない")),
    dict(id="c13", text="枠を100倍に広げたら、どうか。ケーブルに要る長さは、約1,070km。", scene=M([N2140, N1070, STEEL], head="枠を100倍に広げる")),
    dict(id="c14", text="それでも鋼は、約47倍足りません。", scene=M([N2140, N1070, STEEL], head="枠を100倍に広げる", done=True, note="鋼は約47倍足りない")),
    dict(id="c15", text="先細りは、要る強さを下げてくれます。でも、素材そのものの強さが要ります。", scene=TABLE([T1, T2], old=1)),
    dict(id="c16", text="残る手は、素材を替えること。まず、今買える中で最も強い部類から。", scene=CARD(("残る手は、素材を替えること", 66, WHITE), ("まず、今買える中で", 56, DIM), ("最も強い部類から", 90, YEL))),
])
P["ch4"] = dict(title="第4章 実験3 今ある最強級の量産素材", cta=False, lines=[
    dict(id="c1", text="実験3。素材を、ケブラーに替えます。防弾チョッキに使う繊維です。", scene=EXPCARD(3, "今ある最強級の量産素材"), section=True, exp=3),
    dict(id="c2", text="強さは、1平方ミリで約350kg。重さは、鋼の約5分の1。", scene=CARD(("ケブラー", 110, YEL), ("1平方ミリで約350kg", 64, WHITE), ("重さは鋼の約5分の1", 64, WHITE))),
    dict(id="c3", text="切れる長さは、約240km。", scene=M([STEEL, KEV], [M2140], head="切れる長さ")),
    dict(id="c4", text="ケーブルに要る約2,140kmに、約8.8倍足りません。", scene=M([STEEL, KEV], [M2140], head="切れる長さ", done=True, note="ケブラーは約8.8倍足りない")),
    dict(id="c5", text="ケブラーの強さは、資料によって幅があります。ここは、有利な側の値で数えました。", scene=CARD(("ケブラーの強さは", 60, WHITE), ("資料によって幅がある", 76, YEL), ("ここは有利な側の値", 56, DIM))),
    dict(id="c6", text="不利な側の値なら、約11倍足りません。", scene=CARD(("不利な側の値なら", 66, WHITE), ("約11倍足りない", 110, YEL))),
    dict(id="c7", text="次に、炭素繊維。釣りざおや飛行機に使う、黒い繊維です。", scene=CARD(("炭素繊維", 120, YEL), ("釣りざおや飛行機に使う黒い繊維", 52, WHITE))),
    dict(id="c8", text="東レの「T1100G」。繊維1本の強さは、1平方ミリで約710kg。重さは、鋼の約4分の1です。", scene=CARD(("東レ「T1100G」", 90, YEL), ("1平方ミリで約710kg", 64, WHITE), ("重さは鋼の約4分の1", 64, WHITE))),
    dict(id="c9", text="切れる長さは、約400km。", scene=M([STEEL, KEV, CF], [M2140], head="切れる長さ")),
    dict(id="c10", text="2,140kmに対して、約5.4倍足りません。", scene=M([STEEL, KEV, CF], [M2140], head="切れる長さ", done=True, note="炭素繊維は約5.4倍足りない")),
    dict(id="c11", text="ここで、枠を外します。切れないよう、限界ちょうどに先細りにすると、炭素繊維では、上が地上の約24万倍。", scene=BIG("約24万倍", "枠を外した先細り　炭素繊維の上の断面積 ÷ 地上", head="枠を外すと")),
    dict(id="c12", text="地上が1平方ミリなら、上は約0.24平方メートル。座布団1枚ほどです。", scene=AREAS(1)),
    dict(id="c13", text="ケブラーなら、約6億倍。上は約600平方メートル、テニスコート2面より広くなります。", scene=AREAS(2)),
    dict(id="c14", text="失敗です。10倍の枠には入りません。枠を100倍に広げても、炭素繊維は約2.7倍足りません。", scene=TABLE([T1, T2, T3], old=2, room=True)),
    dict(id="c15", text="しかも、この710kgは、繊維1本の値。繊維を束ねて樹脂で固めると、約半分になります。", scene=CARD(("この710kgは", 56, WHITE), ("繊維1本の値", 100, YEL), ("束ねて樹脂で固めると約半分", 56, WHITE))),
    dict(id="c16", text="つまり、最も有利な値で数えて、これです。", scene=CARD(("最も有利な値で数えて", 66, WHITE), ("これです", 110, YEL))),
    dict(id="c17", text="さらに強い素材は、実験室にあります。", scene=CARD(("さらに強い素材は", 66, WHITE), ("実験室にある", 110, YEL))),
])
P["ch5"] = dict(title="第5章 実験4 実験室の最強級", cta=False, lines=[
    dict(id="c1", text="実験4。実験室の素材に進みます。カーボンナノチューブ。炭素の原子が筒になった素材です。", scene=EXPCARD(4, "実験室の最強級"), section=True, exp=4),
    dict(id="c2", text="筒の太さは、髪の毛の1万分の1ほど。以後、ナノチューブと呼びます。", scene=LAT("tube")),
    dict(id="c3", text="大林組の資料には、こうあります。1991年に見つかったこの素材で、実現性が一気に高まった。", scene=CARD(("1991年に見つかった素材で", 56, WHITE), ("実現性が一気に高まった", 70, YEL), ("大林組の資料より", 44, DIM))),
    dict(id="c4", text="まず、糸にした場合。解説記事が引く、著者の言葉では、糸の最高は、1平方ミリで約900kgです。", scene=CARD(("まず、糸にした場合", 80, YEL), ("糸の最高は1平方ミリで約900kg", 60, WHITE), ("解説記事が引く、著者の言葉", 44, DIM))),
    dict(id="c5", text="重さは、鋼の約6分の1と置きます。密度は、仮に1.3と置きました。確かめた値ではありません。", scene=CARD(("重さは鋼の約6分の1と置く", 60, WHITE), ("密度は、仮に1.3", 90, YEL), ("確かめた値ではない", 56, RED))),
    dict(id="c6", text="切れる長さは、約690km。", scene=M([STEEL, KEV, CF, CNT], [M2140], head="切れる長さ", room=True)),
    dict(id="c7", text="2,140kmに、約3.1倍足りません。失敗です。", scene=M([STEEL, KEV, CF, CNT], [M2140], head="切れる長さ", room=True, done=True, note="糸は約3.1倍足りない")),
    dict(id="c8", text="次に、実験室の最高値。2018年、ナノチューブの束で、強さを測った報告があります。長さは、数センチ。", scene=CARD(("2018年　ナノチューブの束", 66, YEL), ("強さを測った報告", 60, WHITE), ("束の長さは数センチ", 70, WHITE))),
    dict(id="c9", text="1平方ミリで、約8トン。ギガパスカルという単位では、80を超えます。", scene=CARD(("1平方ミリで約8トン", 90, YEL), ("80ギガパスカルを超える", 70, WHITE))),
    dict(id="c10", text="強さは、鋼の約45倍。しかも軽いので、切れる長さでは、約270倍です。", scene=CARD(("強さは鋼の約45倍", 80, YEL), ("しかも軽いので", 52, WHITE), ("切れる長さでは約270倍", 80, YEL))),
    dict(id="c11", text="ナノチューブの束の切れる長さは、約6,300km。", scene=M([STEEL, KEV, CF, CNT, BUN], [M2140], head="切れる長さ")),
    dict(id="c12", text="ケーブルに要る2,140kmの、約3倍。枠に入ります。", scene=M([STEEL, KEV, CF, CNT, BUN], [M2140], head="切れる長さ", done=True, note="要る長さの約3倍　枠に入る", ncol=GRN)),
    dict(id="c13", text="上の断面積は、地上の約2.2倍で済みます。太さ一定でも、要る4,940kmを超えます。", scene=M([BUN, N4940], head="太さ一定でも、要る長さを超える", note="上の断面積は、地上の約2.2倍", ncol=GRN)),
    dict(id="c14", text="もう1つ、グラフェン。炭素の原子が、平らに1層だけ並んだ膜です。", scene=LAT("sheet")),
    dict(id="c15", text="2008年の測定で、強さは約130ギガパスカル。小さな膜を押して測った値です。", scene=CARD(("2008年の測定", 60, WHITE), ("強さは約130ギガパスカル", 80, YEL), ("小さな膜を押して測った値", 52, WHITE))),
    dict(id="c16", text="密度は、黒鉛の値で置きました。切れる長さに直すと、約5,900kmです。", scene=M([STEEL, KEV, CF, CNT, BUN, GRA], [M2140], head="切れる長さ")),
    dict(id="c17", text="ケーブルにした例は、見つかっていません。", scene=CARD(("グラフェンを", 60, WHITE), ("ケーブルにした例は", 60, WHITE), ("見つかっていない", 100, YEL))),
    dict(id="c18", text="ここまで近づきました。ナノチューブの束なら、枠に入ります。", scene=TABLE([T1, T2, T3, T4a, T4b, T4c], old=3, head="ここまで近づいた")),
    dict(id="c19", text="でも、この80は、ナノチューブの束の、数センチでの値。ケーブルに要るのは、3万6千km。その差を、次で数えます。", scene=CARD(("この80は", 60, WHITE), ("数センチの束での値", 70, YEL), ("ケーブルに要るのは約3万6千km", 56, WHITE))),
])
P["ch6"] = dict(title="第6章 実験5 長いケーブルにすると", lines=[
    dict(id="c1", text="実験5。実験室の値を、現実に近づけます。", scene=EXPCARD(5, "長いケーブルにすると"), section=True, exp=5),
    dict(id="c2", text="1つ目は、安全率。壊れる強さの、半分までしか使わない。ふつう、余裕を見ます。", scene=CARD(("安全率", 130, YEL), ("壊れる強さの半分までしか使わない", 52, WHITE))),
    dict(id="c3", text="この場合、ケーブルに要る長さは、2倍になります。", scene=CARD(("ケーブルに要る長さは", 60, WHITE), ("2倍になる", 130, YEL))),
    dict(id="c4", text="10倍の枠で、約4,290km。ナノチューブの束の約6,300kmは、まだ枠に入ります。", scene=M([BUN, N4290], head="安全率2で、要る長さは2倍")),
    dict(id="c5", text="余裕は、約1.5倍です。", scene=M([BUN, N4290], head="安全率2で、要る長さは2倍", done=True, note="余裕は約1.5倍", ncol=GRN)),
    dict(id="c6", text="2つ目は、長さ。ナノチューブの束は、数センチ。必要なのは、約3万6千kmです。", scene=M([("実験の束の長さ", 0.00005, None, "数センチ", GRN), ("ケーブルに必要な長さ", 36000, None, "約3万6千km", YL)], vmax=36000, head="束の長さと、必要な長さ")),
    dict(id="c7", text="1センチと数えれば、約36億倍。5センチでも、約7億倍の長さです。", scene=CARD(("1センチと数えれば", 56, WHITE), ("約36億倍", 130, YEL), ("5センチでも約7億倍の長さ", 56, WHITE))),
    dict(id="c8", text="長い糸は、1か所でも欠けると、そこから切れます。長いほど、欠けのある場所に当たりやすくなります。", scene=K("flaw")),
    dict(id="c9", text="実験の束は、欠けの少ない筒だけで作られました。", scene=CARD(("実験の束は", 60, WHITE), ("欠けの少ない筒だけ", 100, YEL), ("で作られた", 60, WHITE))),
    dict(id="c10", text="では、どこまで落ちたら、枠を外れるのか。求めます。", scene=CARD(("どこまで落ちたら", 70, WHITE), ("枠を外れるのか", 110, YEL))),
    dict(id="c11", text="安全率2のままだと、実験値の約7割まで落ちると、枠を超えます。", scene=M([("実験の値", 6275, None, "約6,300km", GRN), ("実験値の約7割", 4290, None, "約7割", YL)], [(4290, "ケーブルに要る長さ（安全率2）約4,290km", RD)], head="安全率2のまま", note="約7割まで落ちると、枠を超える")),
    dict(id="c12", text="密度は、詰まり方で変わります。1.6に置くと、余裕は約1.2倍に減ります。", scene=CARD(("密度を1.6に置くと", 60, WHITE), ("余裕は約1.2倍に減る", 90, YEL))),
    dict(id="c13", text="そして、その強さで長く作った例は、まだ報告されていません。", scene=CARD(("その強さで長く作った例は", 56, WHITE), ("まだ報告されていない", 90, YEL))),
    dict(id="c14", text="さらに、この計算は最低ラインです。静止軌道より上のおもりも、荷物も、風も入っていません。", scene=CARD(("この計算は最低ライン", 70, YEL), ("おもりも荷物も風も入っていない", 52, WHITE))),
    dict(id="c15", text="答えです。今ある量産の素材は、10倍の枠に、炭素繊維で約5.4倍足りません。", scene=CARD(("答え", 130, YEL), ("今ある量産の素材は", 56, WHITE), ("10倍の枠に、炭素繊維で約5.4倍足りない", 54, RED)), section=True),
    dict(id="c16", text="枠を外しても、炭素繊維の上は、地上の約24万倍です。", scene=CARD(("答え", 130, YEL), ("枠を外しても、炭素繊維の上は", 56, WHITE), ("地上の約24万倍", 100, RED))),
    dict(id="c17", text="実験室のナノチューブの束なら、枠に入ります。ただ、その強さで長く作った例は、まだ報告されていません。", scene=CARD(("答え", 130, YEL), ("実験室のナノチューブの束なら枠に入る", 54, GREEN), ("長く作った例は、まだ報告されていない", 50, WHITE))),
    dict(id="c18", text="冒頭の鋼に戻ります。最初の鋼は、23kmで切れました。ナノチューブの束なら、約6,300km。", scene=M([STEEL, BUN], head="冒頭の鋼に戻る")),
    dict(id="c19", text="宇宙までの距離は、この数字が決めています。", scene=M([STEEL, BUN], head="冒頭の鋼に戻る", done=True, note="宇宙までの距離は、この数字が決めている", ncol=YL)),
    dict(id="c20", text="次に吊り橋を渡ったら、足元のワイヤーを見てください。あの鋼線は、約23km垂らすと、自分の重さで切れます。", scene=K("hang")),
])
P["s1"] = dict(title="4,940kmぶんの負担", lines=[
    dict(id="c1", text="宇宙エレベーターのケーブルは、3万6千kmの高さまで伸びます。地球1周の、およそ9割です。", scene=CABLE(1)),
    dict(id="c2", text="行き先は、静止軌道。地球の自転と同じ周期で回り、真上に止まって見える場所です。"),
    dict(id="c3", text="では、そのケーブルは、3万6千km分の重さを支えるのか。違います。", scene=CARD(("3万6千km分の重さを", 60, WHITE), ("支えるのか", 90, WHITE), ("違う", 140, RED))),
    dict(id="c4", text="上へ行くほど、重力が弱くなるからです。静止軌道では、地上の約2%。", scene=GC(1)),
    dict(id="c5", text="さらに、地球の自転で、ケーブルは外へ振り回されます。この力を、遠心力といいます。", scene=GC(2)),
    dict(id="c6", text="静止軌道では、重力と遠心力が、同じ強さで打ち消し合います。", scene=GC(3)),
    dict(id="c7", text="高さごとに、その差を足していきます。", scene=GC(4)),
    dict(id="c8", text="一番上にかかる負担は、同じ素材のケーブルを、4,940kmぶん垂らしたのと同じです。"),
    dict(id="c9", text="3万6千kmの、7分の1ほどです。", scene=GC(5)),
    dict(id="c10", text="同じ素材の糸を垂らして、自分の重さで切れる長さ。これを、切れる長さと呼びます。ケーブルには、4,940kmぶんの切れる長さが要ります。", scene=CARD(("切れる長さ", 110, YEL), ("同じ素材の糸を垂らして", 48, WHITE), ("自分の重さで切れる長さ", 48, WHITE), ("ケーブルには約4,940kmぶん要る", 48, WHITE))),
    dict(id="c11", text="次に夜空を見上げたら、思い出してください。静止軌道では、地上の約2%の重力が、遠心力と釣り合っています。", scene=GC(3)),
])
P["s2"] = dict(title="鋼は215倍足りない", lines=[
    dict(id="c1", text="鋼のケーブルを、上から垂らします。自分の重さで切れるのは、約23km。山手線を1周するより、短い距離です。", scene=K("hang")),
    dict(id="c2", text="この長さを、切れる長さと呼びます。同じ素材の糸が、自分の重さで切れるまでの長さです。", scene=CARD(("切れる長さ", 110, YEL), ("同じ素材の糸が", 52, WHITE), ("自分の重さで切れるまでの長さ", 52, WHITE))),
    dict(id="c3", text="使うのは、明石海峡大橋と同じ級の鋼線。1平方ミリに、約180kgを吊るせます。", scene=K("wire")),
    dict(id="c4", text="一方、宇宙エレベーターのケーブルに要る長さは、約4,940km。静止軌道の高さまで、太さ一定で伸ばした場合です。", scene=M([N4940, STEEL], head="ケーブルに要る長さ と 鋼の切れる長さ")),
    dict(id="c5", text="割ると、約215倍。鋼では、215倍足りません。", scene=M([N4940, STEEL], head="ケーブルに要る長さ と 鋼の切れる長さ", done=True, note="鋼は約215倍足りない")),
    dict(id="c6", text="太さを2倍にしたら、どうか。変わりません。太くした分、重くなるからです。", scene=K("twothread")),
    dict(id="c7", text="切れる長さは、太さではなく、素材で決まります。", scene=CARD(("切れる長さは", 60, WHITE), ("太さではなく", 70, WHITE), ("素材で決まる", 110, YEL))),
    dict(id="c8", text="太さを変えても、直らない。実験は、失敗です。", scene=CARD(("太さを変えても直らない", 66, WHITE), ("実験は、失敗", 110, RED))),
    dict(id="c9", text="橋のケーブルが自分の重さで切れないのは、長さが数kmで済むからです。", scene=CARD(("橋のケーブルが切れないのは", 56, WHITE), ("長さが数kmで済むから", 80, YEL))),
])
P["s3"] = dict(title="先を10の93乗倍にしても", lines=[
    dict(id="c1", text="宇宙エレベーターのケーブルを、先細りにします。地上が細く、上ほど太い形。専門では、テーパーといいます。", scene=TAPER()),
    dict(id="c2", text="上のほうは、下の全部の重さを支えます。だから、上ほど太くします。"),
    dict(id="c3", text="鋼で計算します。上の断面積を、地上の何倍にすれば、全体が限界ちょうどになるか。", scene=CARD(("鋼で計算", 100, YEL), ("上の断面積は地上の何倍で", 56, WHITE), ("限界ちょうどになるか", 56, WHITE))),
    dict(id="c4", text="答えは、10の93乗倍。約2のあとに、0が93個です。", scene=BIG("10の93乗倍", "約2のあとに、0が93個")),
    dict(id="c5", text="地上が1平方ミリなら、上は宇宙の広さでも収まりません。", scene=BIG("10の93乗倍", "約2のあとに、0が93個", zeros=True)),
    dict(id="c6", text="では、枠を置きます。ここでは、上の断面積は地上の10倍までと置きます。", scene=TAPER(frame=True, head="枠　上の断面積は地上の10倍まで")),
    dict(id="c7", text="その枠なら、ケーブルに要る長さは、約2,140km。", scene=M([N4940, N2140, STEEL], head="ケーブルに要る長さが縮む")),
    dict(id="c8", text="鋼の切れる長さは約23km。枠に収めても、約90倍足りません。", scene=M([N4940, N2140, STEEL], head="ケーブルに要る長さが縮む", done=True, note="鋼は約90倍足りない")),
    dict(id="c9", text="枠を100倍に広げても、要るのは約1,070km。", scene=M([N2140, N1070, STEEL], head="枠を100倍に広げる")),
    dict(id="c10", text="それでも鋼は、約47倍足りません。", scene=M([N2140, N1070, STEEL], head="枠を100倍に広げる", done=True, note="鋼は約47倍足りない")),
    dict(id="c11", text="先細りは、要る強さを下げます。でも、素材の強さは、変えられません。", scene=CARD(("先細りは、要る強さを下げる", 60, WHITE), ("でも素材の強さは", 56, WHITE), ("変えられない", 100, YEL))),
])
P["s4"] = dict(title="炭素繊維でも5.4倍", lines=[
    dict(id="c1", text="今買える中で、最も強い部類の素材なら、宇宙エレベーターのケーブルは作れるのか。計算します。", scene=CARD(("今買える中で", 56, WHITE), ("最も強い部類の素材", 70, YEL), ("ケーブルは作れるのか", 56, WHITE))),
    dict(id="c2", text="炭素繊維。釣りざおや飛行機に使う、黒い繊維です。東レの「T1100G」を使います。", scene=CARD(("炭素繊維", 110, YEL), ("釣りざおや飛行機に使う黒い繊維", 44, WHITE), ("東レ「T1100G」", 66, WHITE))),
    dict(id="c3", text="繊維1本の強さは、1平方ミリで約710kg。重さは、鋼の約4分の1です。", scene=CARD(("1平方ミリで約710kg", 76, YEL), ("重さは鋼の約4分の1", 60, WHITE))),
    dict(id="c4", text="自分の重さで切れる長さは、約400km。これを、切れる長さと呼びます。", scene=M([STEEL, CF], head="切れる長さ")),
    dict(id="c5", text="まず、枠を外します。切れないよう、限界ちょうどに先細りにすると、上は地上の約24万倍。", scene=BIG("約24万倍", "枠を外した先細り　炭素繊維の上の断面積 ÷ 地上", head="枠を外すと")),
    dict(id="c6", text="地上が1平方ミリなら、上は約0.24平方メートル。座布団1枚ほどです。", scene=AREAS(1)),
    dict(id="c7", text="次に、上の断面積を、地上の10倍までに収める枠。ケーブルに要る長さは、約2,140kmです。", scene=M([STEEL, CF], [M2140], head="切れる長さ")),
    dict(id="c8", text="割ると、約5.4倍足りません。", scene=M([STEEL, CF], [M2140], head="切れる長さ", done=True, note="炭素繊維は約5.4倍足りない")),
    dict(id="c9", text="ケブラーなら、上は地上の約6億倍。約600平方メートルで、テニスコート2面より広くなります。", scene=AREAS(2)),
    dict(id="c10", text="しかも、710kgは繊維1本の値。繊維を束ねて樹脂で固めると、約半分になります。", scene=CARD(("この710kgは", 56, WHITE), ("繊維1本の値", 100, YEL), ("束ねて樹脂で固めると約半分", 52, WHITE))),
    dict(id="c11", text="最も有利な値で数えて、これです。", scene=CARD(("最も有利な値で数えて", 66, WHITE), ("これです", 110, YEL))),
])
P["s5"] = dict(title="数センチの束と3万6千km", lines=[
    dict(id="c1", text="カーボンナノチューブ。炭素の原子が筒になった、髪の毛の1万分の1ほどの細さの素材です。", scene=LAT("tube")),
    dict(id="c2", text="2018年、ナノチューブの束で、強さを測った報告があります。長さは、数センチ。", scene=CARD(("2018年　ナノチューブの束", 66, YEL), ("強さを測った報告", 60, WHITE), ("束の長さは数センチ", 70, WHITE))),
    dict(id="c3", text="1平方ミリで、約8トン。ギガパスカルという単位では、80を超えます。", scene=CARD(("1平方ミリで約8トン", 90, YEL), ("80ギガパスカルを超える", 70, WHITE))),
    dict(id="c4", text="重さは、鋼の約6分の1、密度1.3と置きました。確かめた値ではありません。", scene=CARD(("重さは鋼の約6分の1", 60, WHITE), ("密度1.3と置いた", 90, YEL), ("確かめた値ではない", 56, RED))),
    dict(id="c5", text="ナノチューブの束の切れる長さは、約6,300km。同じ素材の糸が、自分の重さで切れる長さです。", scene=M([STEEL, BUN], head="切れる長さ")),
    dict(id="c6", text="宇宙エレベーターの枠に要る約2,140kmの、約3倍。計算の上では、枠に入ります。", scene=M([STEEL, BUN], [M2140], head="切れる長さ", done=True, note="要る長さの約3倍　計算の上では枠に入る", ncol=GRN)),
    dict(id="c7", text="ただし、ナノチューブの束は数センチ。必要なのは、約3万6千kmです。", scene=M([("実験の束の長さ", 0.00005, None, "数センチ", GRN), ("ケーブルに必要な長さ", 36000, None, "約3万6千km", YL)], vmax=36000, head="束の長さと、必要な長さ")),
    dict(id="c8", text="1センチと数えれば、約36億倍。5センチでも、約7億倍の長さです。", scene=CARD(("1センチと数えれば", 56, WHITE), ("約36億倍", 130, YEL), ("5センチでも約7億倍の長さ", 56, WHITE))),
    dict(id="c9", text="長い糸は、1か所でも欠けると、そこから切れます。", scene=K("flaw")),
    dict(id="c10", text="壊れる強さの半分までしか使わない、安全率2。この場合、余裕は約1.5倍です。実験値の約7割まで落ちると、枠を超えます。", scene=M([("実験の値", 6275, None, "約6,300km", GRN), ("実験値の約7割", 4290, None, "約7割", YL)], [(4290, "ケーブルに要る長さ（安全率2）約4,290km", RD)], head="安全率2のまま", note="約7割まで落ちると、枠を超える")),
    dict(id="c11", text="その強さで長く作った例は、まだ報告されていません。", scene=CARD(("その強さで長く作った例は", 56, WHITE), ("まだ報告されていない", 90, YEL))),
])


def _finish(lines):
    """実験の札(exp)を次の行へ引き継ぎ、「失敗です」「成功です」の行に札を出す位置(行の中の割合)を足す。"""
    cur = 0
    res = []
    for l in lines:
        l = dict(l)
        if "exp" in l:
            cur = l["exp"]
        else:
            l["exp"] = cur
        for key, kind in (("ほぼ失敗です", "almost"), ("失敗です", "fail"), ("成功です", "ok")):
            if key in l["text"]:
                l["verdict"] = (kind, l["text"].index(key) / len(l["text"]))
                break
        res.append(l)
    return res


# 読みの直し(kana の出力を全行見て、違う所だけ)。長い語から順に置き換えて say を作る
YOMI = [("太くした分", "太くしたぶん"), ("最高値", "さいこうち"), ("0.24平方メートル", "れいてんにじゅうよんへいほうメートル"),
        ("〜", "から")]


def yomi(text):
    s = text
    for a, b in YOMI:
        s = s.replace(a, b)
    return s


def ep_for(name: str) -> dict:
    p = dict(P[name])
    p["lines"] = _finish(p["lines"]) if name.startswith("ch") else p["lines"]
    res = []
    scene = None
    for l in p["lines"]:
        if l.get("scene") is not None:
            scene = l["scene"]
        if l.get("verdict") and not (scene or {}).get("room"):
            raise SystemExit(f"{name} {l['id']}: 失敗の札を出す行の図に room=True が無い")
        y = yomi(l["text"])
        res.append(dict(l, say=y) if y != l["text"] else l)
    p["lines"] = res
    return dict(kind="sim", aspect="portrait" if name.startswith("s") else "landscape", credit=CREDIT_V if name.startswith("s") else CREDIT, **p)
