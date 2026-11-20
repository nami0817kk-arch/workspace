"""アマゾン川(地理・型 G つながらない): 本編 5 章とショート 5 本の台本と画面。ch1〜ch5・s1〜s5 の ep.py がここから読む。
画面の作りはシベリアの回(episodes/siberia/parts.py)を写した。

数字の出典:
- マナウス港の水位計(リオ・ネグロ、1902 年から): 最高 30.02m(2021 年 6 月)、最低 12.11m(2024 年 10 月 9 日)。
  ブラジル地質調査所(SGB)の 2025 年の技術ノートと、マナウス港の記録をもとにした研究・報道。差は 17.91m
- ブラジル地理統計院(IBGE)2022 年国勢調査: アマゾナス州 3,941,613 人・1,558,704km²、マナウス 2,063,547 人
- アマゾン川の本流に橋がないこと、2011 年に支流のネグロ川にマナウスとイランドゥバを結ぶ橋ができたこと(Live Science ほか)
- 日本の面積 37 万 8,000km²(国土地理院)。東京駅〜横浜駅 約 29km
自分で測ったもの:
- sim/measure.py: 標高データ(Terrain Tiles、SRTM)で、マナウス〜サンタレンを南北に 5 本切り、水面から 20m 以内の低い帯の幅を測った:
  西経 59.5 度 24.6km・58.5 度 38.8km・57.5 度 58.7km・56.5 度 59.3km・55.5 度 42.5km。森の木の高さが乗るので目安
- python sim/measure.py state: Natural Earth のアマゾナス州の面積 157 万km²(IBGE の値と約 1% ちがい)
地点・川の道すじは地図から読んだ(読み)。"""
import json
from pathlib import Path

CREDIT = "地図: NASA・Terrain Tiles・Natural Earth"
RED, YEL, WHITE, BLUE = (240, 90, 80), (255, 214, 64), (255, 255, 255), (120, 190, 255)
GREY, GREEN, SAND = (170, 180, 200), (110, 200, 110), (226, 196, 140)
RIVER = (70, 210, 255)
AREA = (255, 150, 60)

_ST = json.loads((Path(__file__).parent / "sim" / "amazonas.json").read_text(encoding="utf-8"))

# 地点(経度, 緯度)。読み
MANAUS, IRANDUBA, SANTAREM, OBIDOS = (-60.02, -3.10), (-60.19, -3.28), (-54.71, -2.44), (-55.52, -1.90)
IQUITOS, MOUTH, BELEM = (-73.25, -3.75), (-50.0, -0.3), (-48.5, -1.45)
AMAZON = [IQUITOS, (-69.94, -4.25), (-64.7, -3.35), (-61.5, -3.6), (-59.9, -3.15), (-58.44, -3.14), (-55.5, -1.9), (-54.7, -2.42), (-52.0, -1.6), MOUTH]
NEGRO = [(-67.0, 0.5), (-62.9, -0.97), (-60.0, -3.1)]
MADEIRA = [(-63.9, -8.76), (-61.0, -5.5), (-58.8, -3.4)]
CUTS = [(-59.5, (-3.12, -3.34)), (-58.5, (-3.13, -3.48)), (-57.5, (-2.36, -2.89)), (-56.5, (-2.03, -2.57)), (-55.5, (-1.92, -2.30))]

BASIN = (-62.0, -3.5, 30.0, 0)
BASIN_T = (-60.0, -4.5, 26.0, 25)
MID = (-57.5, -2.7, 7.5, 0)
MID_T = (-57.5, -3.0, 6.5, 30)
MANV = (-60.0, -3.1, 1.2, 25)
BASIN_P = (-60.0, -3.5, 22.0, 0)
MID_P = (-57.5, -2.7, 5.5, 0)
MAN_P = (-60.0, -3.1, 1.0, 0)


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


def RIV(tag=""):
    return LINE(AMAZON, RIVER, 12, id=f"amz{tag}")


def TRIBS(tag=""):
    return [LINE(NEGRO, RIVER, 8, id=f"neg{tag}"), LINE(MADEIRA, RIVER, 8, id=f"mad{tag}")]


def CUTLINES(tag=""):
    """谷の幅を測った 5 本の線(低い帯の南北の端)。"""
    return [LINE([(lon, a), (lon, b)], YEL, 9, id=f"cut{lon}{tag}") for lon, (a, b) in CUTS]


def STATE(alpha=0.25, id=None):
    return dict(kind="area", rings=_ST["rings"], color=AREA, alpha=alpha, width=4, id=id or f"st_{alpha}", at=0.0)


def CARD(big, sub=None, note=None, view=BASIN, step=None, count=True, tr=None):
    d = dict(shot="card", big=big, sub=sub, note=note, view=view, step=step, count=count)
    if tr:
        d["tr"] = tr
    return d


def BARS(items, title=None, note=None, fmt="{}", step=None, tr=None):
    d = dict(shot="bars", items=items, title=title, note=note, fmt=fmt, step=step)
    if tr:
        d["tr"] = tr
    return d


SGB, IBGE, MINE = "マナウス港の水位計（SGBほか）", "ブラジル地理統計院（2022年）", "自分で測った（標高データ）"
LEVEL = BARS([("最高（2021年）", 30.02, BLUE), ("最低（2024年）", 12.11, YEL)], title="マナウスの川の水位（m）", note=SGB, fmt="{}")
WIDTH = BARS([("西経59.5度", 24.6, BLUE), ("西経58.5度", 38.8, BLUE), ("西経57.5度", 58.7, YEL), ("西経56.5度", 59.3, YEL), ("西経55.5度", 42.5, BLUE)],
             title="川の低い谷の幅（km）", note=MINE, fmt="{}")

ANSWERS = [("6,000km以上の本流に、橋は1本もない", "支流には、2011年に橋ができた"),
           ("水位は、1年で最大18m上下する", "マナウスの水位計で、12mから30m"),
           ("雨季に水につかる谷は、幅25〜60km", "橋は、谷ごとまたぐ長さが要る"),
           ("橋の先に、つなぐ町がない", "日本の4倍の州に394万人。半分はマナウス"),
           ("ここでは、川そのものが道", "人も物も、船で動く")]

P = {}

# ---- 第1章 橋のない大河 -----------------------------------------------------------------------------------
P["ch1"] = dict(title="第1章 橋のない大河", cta=False, lines=[
    dict(id="a1", text="南アメリカを横切る、アマゾン川。", scene=MAP(BASIN, RIV(), step=0)),
    dict(id="a2", text="長さは、6,000kmを超えます。東京から、シンガポールまでより長い距離です。", scene=CARD("6,000km以上", sub="アマゾン川の長さ", step=0, count=False)),
    dict(id="a3", text="ところが、この本流には、橋が1本もありません。", scene=MAP(BASIN_T, RIV("a3"), step=0)),
    dict(id="a4", text="日本の川なら、町ごとに橋があるのに、です。"),
    dict(id="a5", text="なぜ、世界最大の川に、橋がないのか。", style="question", sub="6,000km以上の大河に\n【橋が1本もない】理由", scene=MAP(MID, RIV("a5"), step=0)),
    dict(id="a6", text="答えを先に言います。", section=True),
    dict(id="a7", text="作れないからでは、ありません。", scene=MAP(MANV, PIN(MANAUS, "マナウス", id="p_ma"), step=0)),
    dict(id="a8", text="川の水位が大きく上下し、谷そのものが広いこと。", scene=LEVEL),
    dict(id="a9", text="そして何より、橋の先に、つなぐ町がほとんどないことです。", scene=MAP(BASIN, STATE(), step=0)),
    dict(id="a10", text="川の水位は、マナウスの港の、100年以上続く水位計の記録で確かめます。", scene=MAP(MANV, PIN(MANAUS, "マナウスの港", id="p_ma2"), step=0)),
    dict(id="a11", text="谷の幅は、標高データで、自分で測りました。", scene=MAP(MID, RIV("a11"), *CUTLINES("a"), step=0)),
])

# ---- 第2章 18m上下する川 ----------------------------------------------------------------------------------
P["ch2"] = dict(title="第2章 18m上下する川", cta=False, lines=[
    dict(id="b1", text="まず、川の高さを見ます。", scene=MAP(MANV, PIN(MANAUS, "マナウス", id="p_mb"), step=1)),
    dict(id="b2", text="アマゾンの真ん中の町、マナウス。港には、1902年から続く水位計があります。"),
    dict(id="b3", text="いちばん高かったのは、2021年。30.02mでした。", scene=LEVEL),
    dict(id="b4", text="いちばん低かったのは、2024年10月。12.11mです。"),
    dict(id="b5", text="その差は、約18m。ビルの6階分です。", scene=CARD("約18m", sub="マナウスの水位の差（いちばん高い時と低い時）", note=SGB, view=MANV, step=1, count=False)),
    dict(id="b6", text="しかも毎年、雨季と乾季で、大きく上がり下がりします。"),
    dict(id="b7", text="普通は、橋は川の水面の少し上に、かければよいと思いますよね。", section=True, scene=MAP(MANV, RIV("b7"), step=1)),
    dict(id="b8", text="ところが、ここでは、水面そのものが、ビル6階分も動きます。"),
    dict(id="b9", text="いちばん高い水の上に、橋を通さなければなりません。", scene=CARD("水面＋18m", sub="橋をかける高さの目安", view=MANV, step=1, count=False)),
    dict(id="b10", text="しかもマナウスには、海を渡る大きな船が、上ってきます。"),
    dict(id="b11", text="その船の、さらに上を通す高さが、要るのです。"),
    dict(id="b12", text="2024年の水位は、記録を取り始めてから、いちばん低い値でした。", scene=MAP(MID_T, RIV("b12"), step=1)),
    dict(id="b13", text="川は、毎年、別の顔になるのです。"),
])

# ---- 第3章 60kmの谷 ---------------------------------------------------------------------------------------
P["ch3"] = dict(title="第3章 60kmの谷", cta=False, lines=[
    dict(id="c1", text="次に、川の横の広がりを見ます。", scene=MAP(MID, RIV("c1"), step=2, tr="zoom")),
    dict(id="c2", text="マナウスから下流へ、南北に5本、線を引きました。", scene=MAP(MID, RIV("c2"), *CUTLINES("c"), step=2)),
    dict(id="c3", text="標高データで、水面から20m以内の、低い土地の幅を測ります。"),
    dict(id="c4", text="結果は、25kmから60km。", scene=WIDTH),
    dict(id="c5", text="いちばん広い所は、約59km。東京駅から横浜駅までの、2倍あります。"),
    dict(id="c6", text="雨季になると、この低い谷が、森ごと水につかります。", section=True, scene=MAP(MID_T, RIV("c6"), *CUTLINES("c2"), step=2)),
    dict(id="c7", text="水の中に森が立つ、水につかる森です。"),
    dict(id="c8", text="つまり川の本当の幅は、季節で大きく変わるのです。", scene=CARD("25〜60km", sub="雨季に水につかる谷の幅", note=MINE, view=MID, step=2, count=False)),
    dict(id="c9", text="橋をかけるなら、水の上だけでなく、この谷ごと、またがなければなりません。", scene=MAP(MID, *CUTLINES("c3"), step=2)),
    dict(id="c10", text="土は、川が運んだ、やわらかい泥と砂です。", scene=MAP(MANV, RIV("c10"), step=2)),
    dict(id="c11", text="岸は、川の流れで、少しずつ削られて動きます。"),
    dict(id="c12", text="長く、高く、やわらかい地面の上に。お金も、手間も、大きくなります。"),
])

# ---- 第4章 橋の先に町がない --------------------------------------------------------------------------------
P["ch4"] = dict(title="第4章 橋の先に町がない", cta=False, lines=[
    dict(id="d1", text="それでも、橋をかける国は、たくさんあります。", scene=MAP(BASIN, step=3, tr="zoom")),
    dict(id="d2", text="アマゾンに橋がない、いちばんの理由は、別のところにあります。", section=True),
    dict(id="d3", text="マナウスがある、アマゾナス州を見ます。", scene=MAP(BASIN, STATE(id="st_d"), PIN(MANAUS, "マナウス", id="p_md"), step=3)),
    dict(id="d4", text="広さは、約156万km²。日本の、約4倍です。", scene=BARS([("アマゾナス州", 156, AREA), ("日本", 37.8, RED)], title="広さ（万km²）", note=IBGE + "・国土地理院", fmt="{}", step=3)),
    dict(id="d5", text="そこに住む人は、約394万人。", scene=CARD("約394万人", sub="アマゾナス州の人口（2022年）", note=IBGE, step=3)),
    dict(id="d6", text="しかも、その半分あまり、約206万人が、マナウス1つの町に住んでいます。", scene=BARS([("マナウス", 206, YEL), ("州のほかの町と村", 188, GREY)], title="アマゾナス州の人口（万人）", note=IBGE, fmt="{}", step=3)),
    dict(id="d7", text="マナウスの外は、大半が森です。", scene=MAP(BASIN_T, STATE(alpha=0.15, id="st_d2"), step=3)),
    dict(id="d8", text="橋をかけても、渡った先に、行き先の町がないのです。"),
    dict(id="d9", text="2011年、マナウスの前を流れる支流、ネグロ川には、橋がかかりました。", section=True, scene=MAP(MANV, PIN(MANAUS, "マナウス", id="p_md2"), PIN(IRANDUBA, "イランドゥバ", id="p_ir"), LINE([MANAUS, IRANDUBA], YEL, 8, id="r_br"), step=3)),
    dict(id="d10", text="マナウスと、向こう岸の町イランドゥバを結ぶ橋です。", scene=CARD("2011年", sub="支流ネグロ川の橋（マナウス〜イランドゥバ）", view=MANV, step=3, count=False)),
    dict(id="d11", text="人が多い所には、橋はかかる。少ない所には、かからない。それだけのことなのです。", scene=MAP(BASIN_T, RIV("d11"), PIN(MANAUS, "マナウス", id="p_md3"), step=3)),
])

# ---- 第5章 川が道 -----------------------------------------------------------------------------------------
_CV = [(BASIN, (-62.0, -3.5, 26.0, 15)), (MANV, (-60.0, -3.1, 1.0, 30)), (MID, (-57.5, -2.7, 6.5, 25)),
       (BASIN_T, (-60.0, -4.5, 22.0, 30)), (MID_T, (-57.5, -3.0, 5.5, 35))]
CARDS_N = lambda n: dict(shot="cards", items=ANSWERS, n=n, view=_CV[n - 1][0], view_to=_CV[n - 1][1], step=4)  # noqa: E731
P["ch5"] = dict(title="第5章 川が道", cta=True, lines=[
    dict(id="e1", text="では、人は、どうやって川を渡り、町と町を行き来するのか。", scene=MAP(BASIN, RIV("e1"), *TRIBS("e"), step=4, tr="zoom")),
    dict(id="e2", text="答えは、船です。", section=True),
    dict(id="e3", text="アマゾンでは、川そのものが道路です。", scene=MAP(BASIN_T, RIV("e3"), *TRIBS("e3"), PIN(MANAUS, "マナウス", id="p_me"), PIN(SANTAREM, "サンタレン", id="p_sa"), step=4)),
    dict(id="e4", text="人も、車も、食べ物も、船で運ばれます。"),
    dict(id="e5", text="川を渡るだけなら、船で足ります。"),
    dict(id="e6", text="ただ、2024年のように水位が下がると、船が通れなくなります。", scene=LEVEL),
    dict(id="e7", text="道路にあたる川が、干上がるのです。"),
    dict(id="e8", text="まとめます。", section=True, scene=CARDS_N(1)),
    dict(id="e9", text="1つ目。6,000km以上の本流に、橋は1本もない。支流には、2011年に橋ができました。"),
    dict(id="e10", text="2つ目。水位は、最大で18m上下する。マナウスの水位計で、12mから30mです。", scene=CARDS_N(2)),
    dict(id="e11", text="3つ目。雨季に水につかる谷は、幅25kmから60km。橋は、谷ごとまたぐ長さが要ります。", scene=CARDS_N(3)),
    dict(id="e12", text="4つ目。橋の先に、つなぐ町がない。日本の4倍の州に394万人、その半分はマナウスです。", scene=CARDS_N(4)),
    dict(id="e13", text="5つ目。ここでは、川そのものが道。人も物も、船で動きます。", scene=CARDS_N(5)),
    dict(id="e14", text="橋が作れないのではなく、橋より船のほうが、この土地に合っていたのです。", scene=MAP(MID, RIV("e14"), step=4, view_to=(-57.5, -2.7, 6.0, 25))),
    dict(id="e15", text="次に大きな川の橋を渡ったら、その橋が、両岸の町の人の多さで決まっていることを、思い出してください。", scene=MAP(BASIN, RIV("e15"), step=4)),
])

# ---- ショート ---------------------------------------------------------------------------------------------
P["s1"] = dict(title="6,000km以上流れるアマゾン川に、橋は1本もない", lines=[
    dict(id="k1", text="アマゾン川の長さは、6,000kmを超えます。", scene=MAP(BASIN_P, RIV("k"))),
    dict(id="k2", text="ところが、その本流には、橋が1本もありません。", scene=CARD("橋は0本", sub="アマゾン川の本流", view=BASIN_P, count=False)),
    dict(id="k3", text="作れないからでは、ありません。", scene=MAP(MAN_P, PIN(MANAUS, "マナウス", id="p_km"))),
    dict(id="k4", text="マナウスがあるアマゾナス州は、日本の約4倍の広さに、約394万人。", scene=BARS([("アマゾナス州", 156, AREA), ("日本", 37.8, RED)], title="広さ（万km²）", fmt="{}")),
    dict(id="k5", text="その半分あまりが、マナウス1つの町に住んでいます。橋の先に、行き先の町がないのです。", scene=MAP(BASIN_P, STATE(id="st_k"))),
    dict(id="k6", text="ここでは橋の代わりに、船が人と物を運んでいます。", scene=MAP(BASIN_P, tr="whip")),
])

P["s2"] = dict(title="アマゾン川の水面は、1年で最大18m上下する", lines=[
    dict(id="m1", text="アマゾン川の真ん中の町、マナウス。", scene=MAP(MAN_P, PIN(MANAUS, "マナウス", id="p_mm"))),
    dict(id="m2", text="港の水位計で、いちばん高かったのは、2021年の30.02m。", scene=LEVEL),
    dict(id="m3", text="いちばん低かったのは、2024年10月の12.11mです。"),
    dict(id="m4", text="その差は、約18m。ビルの6階分です。", scene=CARD("約18m", sub="マナウスの水位の差", view=MAN_P, count=False)),
    dict(id="m5", text="橋をかけるなら、いちばん高い水と、大きな船の、さらに上を通す必要があります。"),
    dict(id="m6", text="水面そのものが動く川に、橋をかけるのは、大ごとなのです。", scene=MAP(MAN_P, tr="whip")),
])

P["s3"] = dict(title="アマゾン川の本当の幅は、60kmになる", lines=[
    dict(id="n1", text="アマゾン川の幅を、標高データで測ってみました。", scene=MAP(MID_P, RIV("n"), *CUTLINES("n"))),
    dict(id="n2", text="マナウスから下流へ、5本の線で切って、水面から20m以内の低い土地の幅を測ります。"),
    dict(id="n3", text="結果は、25kmから60km。", scene=WIDTH),
    dict(id="n4", text="いちばん広い所は、約59km。東京駅から横浜駅までの、2倍です。"),
    dict(id="n5", text="雨季には、この谷が森ごと水につかります。", scene=CARD("25〜60km", sub="雨季に水につかる谷の幅", view=MID_P, count=False)),
    dict(id="n6", text="橋をかけるなら、この谷ごと、またがなければならないのです。", scene=MAP(MID_P, tr="whip")),
])

P["s4"] = dict(title="日本の4倍の州に、人は394万。半分は1つの町", lines=[
    dict(id="q1", text="ブラジルのアマゾナス州。広さは約156万km²で、日本の約4倍です。", scene=MAP(BASIN_P, STATE(id="st_q"))),
    dict(id="q2", text="そこに住む人は、約394万人。", scene=CARD("約394万人", sub="アマゾナス州の人口（2022年）", view=BASIN_P)),
    dict(id="q3", text="そのうち約206万人が、マナウス1つの町に住んでいます。", scene=BARS([("マナウス", 206, YEL), ("州のほかの町と村", 188, GREY)], title="人口（万人）", fmt="{}")),
    dict(id="q4", text="半分あまりが、1つの町に集まっているのです。", scene=MAP(MAN_P, PIN(MANAUS, "マナウス", id="p_qm"))),
    dict(id="q5", text="町の外は、大半が森。だから、アマゾン川の本流には、橋をかける先がありません。"),
    dict(id="q6", text="人がいない所に、橋はかからないのです。", scene=MAP(BASIN_P, tr="whip")),
])

P["s5"] = dict(title="2024年、アマゾン川の水位は122年で最低になった", lines=[
    dict(id="r1", text="アマゾンでは、川そのものが道路です。", scene=MAP(BASIN_P, RIV("r"))),
    dict(id="r2", text="人も、食べ物も、船で運ばれます。"),
    dict(id="r3", text="ところが2024年10月、マナウスの水位は12.11mまで下がりました。", scene=LEVEL),
    dict(id="r4", text="1902年に記録を取り始めてから、いちばん低い値です。", scene=CARD("12.11m", sub="マナウスの水位（2024年10月）", view=MAN_P)),
    dict(id="r5", text="道路にあたる川が浅くなり、船が通りにくくなったのです。", scene=MAP(MAN_P, PIN(MANAUS, "マナウス", id="p_rm"))),
    dict(id="r6", text="橋のない土地では、川の水位が、そのまま暮らしを左右するのです。", scene=MAP(BASIN_P, tr="whip")),
])

# ---- 読み ------------------------------------------------------------------------------------------------
YOMI = [("少し上", "すこしうえ"), ("森ごと水に", "もりごと、みずに"), ("人がいない", "ひとがいない"), ("6,000km", "六千キロ"), ("30.02m", "三十点れいにメートル"), ("12.11m", "ジュウニテンイチイチメートル"), ("約18m", "約十八メートル"), ("18m", "十八メートル"),
        ("10m", "十メートル"), ("20m", "二十メートル"), ("12mから30m", "十二メートルから三十メートル"), ("25kmから60km", "二十五キロから六十キロ"),
        ("約59km", "約五十九キロ"), ("約156万km²", "約百五十六万平方キロメートル"), ("約394万人", "約三百九十四万人"), ("394万人", "三百九十四万人"),
        ("約206万人", "約二百六万人"), ("2021年", "二千二十一年"), ("2024年10月", "二千二十四年十月"), ("2024年", "二千二十四年"),
        ("2011年", "二千十一年"), ("1902年", "千九百二年"), ("122年", "百二十二年"), ("100年", "百年"), ("6階分", "ろっかいぶん"),
        ("4倍", "よんばい"), ("2倍", "にばい"), ("5本", "ごほん"), ("1本", "いっぽん"), ("1つ目", "ひとつめ"), ("2つ目", "ふたつめ"), ("3つ目", "みっつめ"),
        ("4つ目", "よっつめ"), ("5つ目", "いつつめ"), ("1つ", "ひとつ"), ("本流", "ほんりゅう"), ("支流", "しりゅう"), ("雨季", "うき"), ("乾季", "かんき"),
        ("水位計", "すいいけい"), ("水位", "すいい"), ("両岸", "りょうぎし"), ("下流", "かりゅう"), ("大ごと", "おおごと"), ("日本", "にほん"),
        ("東京駅", "とうきょうえき"), ("横浜駅", "よこはまえき"), ("アマゾナス州", "アマゾナスしゅう"), ("ネグロ川", "ネグロがわ"), ("アマゾン川", "アマゾンがわ")]


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
