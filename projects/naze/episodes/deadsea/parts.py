"""死海(地理・型 A 水の行方): 本編 5 章とショート 5 本の台本と画面。ch1〜ch5・s1〜s5 の ep.py がここから読む。
画面の作りはアラル海の回(episodes/aral/parts.py)を写した。

数字の出典:
- Vey ほか(2021)「Dead Sea level drop and subsidence…」Scientific Reports(PMC8242068):
  2018 年 10 月の水面 海面下 433m。2014〜2017 年の下がり方 年 110±7cm。正味の蒸発 年 約 1,000mm(約 7 億m³)。
  ヨルダン川の流れ込みは 1955 年より前と比べて 9 割減り、いまは年 0.6〜4 億m³。湖の底などから湧く地下水 約 1.7 億m³、
  周りからの流れ込み 0.58〜0.66 億m³、雨 約 0.45 億m³。カリ(肥料の原料)の工場の正味の水の使用 約 2.5 億m³ が下がる分の約 4 割
- イスラエル環境保護省(2018、Globes 2018-02-13 の記事): 40 年で 30m 下がった。下がり方は 1970〜80 年代の年 0.7m から年 1.2m に。
  1979 年に北と南の 2 つに分かれ、南は工場の池になった。デガニア・アルモットのダムでヨルダン川の流れが止まった。2015 年に穴 5,500 個
- ICL(2018 年の持続可能性報告「Dead Sea water level」): 北の湖から南の池へ 4.3 億m³ をくみ上げ、2.7 億m³ を戻す(正味 1.6 億m³)。
  上流で使われる水 約 14 億m³。ICL が止まっても年 0.85m 下がる。紅海からの年 2.5 億m³ の管の案では、下がり方が年 35cm ゆるみ、なお年 約 0.75m 下がる
- 琵琶湖の面積 669km²(国土地理院)。東京ドームの容積 124 万m³。東京タワー 333m
自分で測った・計算したもの:
- sim/measure.py: 標高データ(SRTM、2000 年 2 月)の水面は海面下 412m、北の湖の面積 約 641km²。海面下 403m(1978 年ごろの水位)の線の内側は 約 693km²
- 1 年に湖から減る水: 1.1m × 641km² ≈ 7 億m³(東京ドーム 約 570 杯)。工場の 2.5 億m³ はその約 35%。
  紅海からの 2.5 億m³ ÷ 641km² ≈ 0.39m → 1.1 − 0.39 ≈ 0.7m(ICL の見込み 0.75m とほぼ同じ)
地点の座標は地図から読んだ(読み)。"""
import json
from pathlib import Path

CREDIT = "地図: NASA・Terrain Tiles・Natural Earth"
RED, YEL, WHITE, BLUE = (240, 90, 80), (255, 214, 64), (255, 255, 255), (120, 190, 255)
GREY, GREEN, SAND = (170, 180, 200), (110, 200, 110), (226, 196, 140)
RIVER = (70, 210, 255)
LAKE = (40, 120, 255)

_S = json.loads((Path(__file__).parent / "sim" / "shores.json").read_text(encoding="utf-8"))["shores"]

# 地点(経度, 緯度)。読み
EINGEDI, MASADA, LISAN, PONDS = (35.39, 31.46), (35.35, 31.31), (35.52, 31.27), (35.43, 31.12)
GALILEE, DEGANIA = (35.59, 32.82), (35.575, 32.71)
NORTH_L = (35.48, 31.55)
JORDAN = [(35.575, 32.71), (35.57, 32.5), (35.55, 32.25), (35.53, 32.0), (35.55, 31.85), (35.56, 31.77)]
AQABA = (35.0, 29.53)

REGION = (35.45, 31.6, 2.6, 0)
SEA = (35.45, 31.45, 0.9, 0)
SEA_T = (35.45, 31.38, 0.8, 35)
NORTHV = (35.47, 31.58, 0.55, 25)
SOUTHV = (35.45, 31.2, 0.6, 25)
WIDE = (35.6, 31.2, 7.5, 0)
SEA_P = (35.47, 31.45, 0.7, 0)
REGION_P = (35.5, 31.9, 2.0, 0)
WIDE_P = (35.4, 31.0, 5.0, 0)


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


def SHORE(yr, color=LAKE, alpha=0.5, width=4, id=None, at=0.0):
    """その年の北の湖(標高データの等高線)。alpha=0 なら岸の線だけ。"""
    return dict(kind="area", rings=_S[yr], color=color, alpha=alpha, width=width, id=id or f"shore_{yr}_{alpha}", at=at)


def JRIVER(tag=""):
    return LINE(JORDAN, RIVER, 12, id=f"r_jo{tag}")


def CARD(big, sub=None, note=None, view=SEA, step=None, count=True, tr=None):
    d = dict(shot="card", big=big, sub=sub, note=note, view=view, step=step, count=count)
    if tr:
        d["tr"] = tr
    return d


def BARS(items, title=None, note=None, fmt="{}", step=None, tr=None):
    d = dict(shot="bars", items=items, title=title, note=note, fmt=fmt, step=step)
    if tr:
        d["tr"] = tr
    return d


VEY, MOE, ICL = "Vey ほか（2021）", "イスラエル環境保護省（2018）", "ICL（2018）"

ANSWERS = [("毎年約1.1m下がる。40年で30m", "海面下433m（2018年）"),
           ("ヨルダン川の水は、9割減った", "上流のダムと、まわりの国の水道・畑へ"),
           ("下がる分の約4割は、塩を取る池", "湖の水をくみ上げて、乾かしている"),
           ("1年に減る水は、約7億m³", "1.1m × 641km²。東京ドーム約570杯"),
           ("紅海から2.5億m³入れても、年0.7m下がる", "止めるには、減る分すべてが要る")]

P = {}

# ---- 第1章 いちばん低い湖 ---------------------------------------------------------------------------------
P["ch1"] = dict(title="第1章 いちばん低い湖", cta=False, lines=[
    dict(id="a1", text="陸の上で、いちばん低い水面。それが、死海です。", scene=MAP(WIDE, step=0, view_to=SEA)),
    dict(id="a2", text="2018年の水面は、海面より433m下。", scene=CARD("海面下433m", sub="死海の水面（2018年10月）", note=VEY, step=0, count=False)),
    dict(id="a3", text="東京タワーを水面に立てても、てっぺんは、まだ海面より100m下です。", scene=BARS([("死海の水面（海面から下へ）", 433, BLUE), ("東京タワー", 333, GREY)], title="高さ（m）", note=VEY, fmt="{}", step=0)),
    dict(id="a4", text="しかも、その水面は、毎年、約1.1mずつ下がっています。", scene=MAP(SEA_T, SHORE("2000", alpha=0.0, width=5), step=0)),
    dict(id="a5", text="40年で、30m。ビルの10階分です。", scene=CARD("40年で30m", sub="死海の水面が下がった高さ", note=MOE, step=0, count=False)),
    dict(id="a6", text="水は、どこへ消えているのか。", style="question", sub="海面下433mの湖\n【水はどこへ】消えている", scene=MAP(SEA, step=0)),
    dict(id="a7", text="答えを先に言います。", section=True),
    dict(id="a8", text="1つは、入ってくる川の水が、9割減ったこと。", scene=MAP(REGION, JRIVER(), PIN(GALILEE, "ガリラヤ湖", id="p_ga"), step=0)),
    dict(id="a9", text="もう1つは、湖の水そのものが、くみ上げられて乾かされていることです。", scene=MAP(SOUTHV, PIN(PONDS, "塩を取る池", id="p_po"), step=0)),
    dict(id="a10", text="昔の岸は、標高データの等高線で、自分で引きました。", scene=MAP(SEA, SHORE("1978", alpha=0.0, width=5, id="l78"), SHORE("2000", id="s00"), LABEL((35.62, 31.75), "1978年ごろの岸", 44, YEL), step=0)),
    dict(id="a11", text="水の出入りは、論文と、政府と会社の資料の数字で確かめます。"),
])

# ---- 第2章 入る水と出る水 ---------------------------------------------------------------------------------
P["ch2"] = dict(title="第2章 入る水と出る水", cta=False, lines=[
    dict(id="b1", text="まず、死海の形を見ます。", scene=MAP(REGION, SHORE("2000", id="s00b"), step=1)),
    dict(id="b2", text="死海にも、出ていく川がありません。", scene=MAP(REGION, JRIVER("b"), step=1)),
    dict(id="b3", text="入った水は、蒸発して、空へ出ていくだけです。"),
    dict(id="b4", text="空へ出る水は、1年に、深さ約1m分です。", scene=CARD("約1m", sub="1年に蒸発する水の深さ", note=VEY, step=1, count=False)),
    dict(id="b5", text="入る水は、湖の底から湧く地下水が、1年に約1.7億m³。", scene=BARS([("湖の底などから湧く地下水", 1.7, BLUE), ("ヨルダン川（いま）", 0.6, RIVER), ("まわりから流れ込む水", 0.6, GREY), ("湖の上の雨", 0.45, GREY)], title="1年に入る水（億m³）", note=VEY + "（ヨルダン川は0.6〜4億m³）", fmt="{}", step=1)),
    dict(id="b6", text="まわりから流れ込む水と、雨が、あわせて約1億m³。"),
    dict(id="b7", text="ヨルダン川は、年によって、0.6億から4億m³です。"),
    dict(id="b8", text="では、1年に、どれだけ減っているのか。", section=True, scene=MAP(SEA_T, SHORE("2000", id="s00c"), step=1)),
    dict(id="b9", text="2000年の北の湖を、標高データで測ると、約641km²。", scene=BARS([("死海の北の湖（2000年）", 641, BLUE), ("琵琶湖", 669, GREY)], title="広さ（km²）", note="自分で測った・国土地理院", fmt="{:,}", step=1)),
    dict(id="b10", text="琵琶湖と、ほぼ同じ広さです。"),
    dict(id="b11", text="この広さで、毎年1.1m下がる。掛け算すると、約7億m³です。", scene=CARD("約7億m³", sub="1年に湖から減る水（1.1m × 641km²）", note="自分で計算", step=1, count=False)),
    dict(id="b12", text="東京ドーム、約570杯分の水が、毎年、消えているのです。", scene=BARS([("1年に減る水", 7.05, YEL), ("東京ドーム1杯", 0.0124, GREY)], title="水の量（億m³）", note="自分で計算", fmt="{}", step=1)),
])

# ---- 第3章 ヨルダン川 -------------------------------------------------------------------------------------
P["ch3"] = dict(title="第3章 ヨルダン川", cta=False, lines=[
    dict(id="c1", text="次は、入る水の主役、ヨルダン川です。", scene=MAP(REGION, JRIVER("c"), PIN(GALILEE, "ガリラヤ湖", id="p_ga3"), step=2, tr="zoom")),
    dict(id="c2", text="北のガリラヤ湖から、死海まで流れてきます。"),
    dict(id="c3", text="1955年より前と比べると、いまの流れは、1割ほどしかありません。", scene=BARS([("1955年より前", 100, BLUE), ("いま", 10, YEL)], title="ヨルダン川から死海へ入る水（昔を100として）", note=VEY, fmt="{}", step=2)),
    dict(id="c4", text="9割が、途中で取られているのです。"),
    dict(id="c5", text="ガリラヤ湖の出口には、デガニアのダムがあります。", section=True, scene=MAP(REGION, JRIVER("c2"), PIN(DEGANIA, "デガニアのダム", id="p_de"), step=2, view_to=(35.57, 32.4, 1.2, 25))),
    dict(id="c6", text="その下のアルモットのダムとあわせて、ヨルダン川の流れは、ほとんど止まりました。"),
    dict(id="c7", text="湖の水は、まわりの国の水道と、畑に使われます。", scene=CARD("約14億m³", sub="上流で使われる水（1年）", note=ICL, view=REGION, step=2)),
    dict(id="c8", text="上流で使われる水は、1年に約14億m³。湖から減る水の、2倍の量です。"),
    dict(id="c9", text="それに合わせて、死海の下がり方も、速くなりました。", scene=BARS([("1970〜80年代", 0.7, BLUE), ("2018年ごろ", 1.2, YEL)], title="1年に下がる高さ（m）", note=MOE, fmt="{}", step=2)),
    dict(id="c10", text="1970年代から80年代は、1年に約0.7m。いまは約1.2mです。"),
    dict(id="c11", text="入る水が減った分だけ、水面が下がる。ここまでは、アラル海と同じです。", scene=MAP(SEA, SHORE("1978", alpha=0.0, id="l78c"), SHORE("2000", id="s00d"), step=2)),
])

# ---- 第4章 南の池 -----------------------------------------------------------------------------------------
P["ch4"] = dict(title="第4章 南の池", cta=False, lines=[
    dict(id="d1", text="ところが、死海には、もう1つの理由があります。", scene=MAP(SEA, step=3, tr="zoom")),
    dict(id="d2", text="1979年、死海は、北と南の2つに分かれました。", scene=MAP(SEA, PIN(LISAN, "リサン半島", id="p_li"), LABEL(NORTH_L, "北の湖", 54, WHITE), LABEL(PONDS, "南", 54, WHITE), step=3)),
    dict(id="d3", text="水が下がって、間の浅いところが、陸になったのです。"),
    dict(id="d4", text="いま南にあるのは、湖ではなく、四角い池の並びです。", section=True, scene=MAP(SOUTHV, PIN(PONDS, "塩を取る池", id="p_po4"), step=3)),
    dict(id="d5", text="肥料の原料になる、カリウムの塩を取る工場の池です。"),
    dict(id="d6", text="普通は、湖の水が減るのは、川の水を取ったからだと思いますよね。", scene=MAP(SEA_T, step=3)),
    dict(id="d7", text="ところが、ここでは、湖の水そのものを、池にくみ上げています。"),
    dict(id="d8", text="イスラエルの会社ICLは、2018年に、北の湖から約4.3億m³をくみ上げました。", scene=BARS([("くみ上げた水", 4.3, YEL), ("湖へ戻した水", 2.7, BLUE), ("差し引き", 1.6, RED)], title="ICLの池の水（億m³、2018年）", note=ICL, fmt="{}", step=3)),
    dict(id="d9", text="戻したのは約2.7億m³。差し引き、約1.6億m³が、池で空へ出ていきます。"),
    dict(id="d10", text="ヨルダン側の工場もあわせると、正味約2.5億m³。", scene=CARD("約4割", sub="水面が下がる分のうち、塩を取る池の分", note=VEY, view=SOUTHV, step=3, count=False)),
    dict(id="d11", text="論文の見積もりでは、水面が下がる分の、約4割にあたります。"),
    dict(id="d12", text="さっきの7億m³と比べると、35%。自分の計算でも、ほぼ同じです。"),
    dict(id="d13", text="水が引いた岸では、地面に穴が開き始めました。", section=True, scene=MAP(NORTHV, SHORE("1978", alpha=0.0, id="l78d"), PIN(EINGEDI, "エンゲディ", id="p_en"), step=3)),
    dict(id="d14", text="地下の塩の層に真水が入り、塩がとけて、穴になるのです。"),
    dict(id="d15", text="2015年の時点で、その数は約5,500個です。", scene=CARD("約5,500個", sub="死海の岸に開いた穴（2015年）", note=MOE, view=NORTHV, step=3)),
])

# ---- 第5章 止まらない理由 ----------------------------------------------------------------------------------
_CV = [(SEA, (35.45, 31.45, 0.8, 20)), (REGION, (35.52, 32.2, 1.6, 25)), (SOUTHV, (35.44, 31.15, 0.5, 30)),
       (SEA_T, (35.45, 31.4, 0.7, 35)), (WIDE, (35.3, 30.6, 5.0, 10))]
CARDS_N = lambda n: dict(shot="cards", items=ANSWERS, n=n, view=_CV[n - 1][0], view_to=_CV[n - 1][1], step=4)  # noqa: E731
P["ch5"] = dict(title="第5章 止まらない理由", cta=True, lines=[
    dict(id="e1", text="では、どうすれば、水面は止まるのか。", scene=MAP(SEA, SHORE("2000", id="s00e"), step=4, tr="zoom")),
    dict(id="e2", text="まず、工場を止めたら。", section=True),
    dict(id="e3", text="ICLの見込みでは、それでも1年に約0.85m下がります。", scene=BARS([("いま", 1.1, YEL), ("ICLが止まったら", 0.85, BLUE)], title="1年に下がる高さ（m）", note=ICL, fmt="{}", step=4)),
    dict(id="e4", text="次に、紅海から、水を引いたら。", section=True, scene=MAP(WIDE, LINE([AQABA, (35.4, 31.1)], YEL, 8, id="r_rs"), PIN(AQABA, "紅海", id="p_aq"), step=4)),
    dict(id="e5", text="考えられてきたのは、1年に約2.5億m³を、管で運ぶ案です。"),
    dict(id="e6", text="自分で割ってみます。2.5億m³を、641km²に広げると、深さ約0.39m。", scene=CARD("約0.39m", sub="2.5億m³ ÷ 641km²", note="自分で計算", view=WIDE, step=4, count=False)),
    dict(id="e7", text="1.1mから引くと、まだ、1年に約0.7m下がります。", scene=BARS([("いま", 1.1, YEL), ("紅海から2.5億m³入れたら", 0.71, BLUE)], title="1年に下がる高さ（m）", note="自分で計算", fmt="{}", step=4)),
    dict(id="e8", text="ICLの見込みも、約0.75m。ほぼ同じ答えです。"),
    dict(id="e9", text="止めるには、毎年減る約7億m³を、まるごと足すしかありません。", scene=CARD("約7億m³", sub="水面を止めるのに要る水（1年）", note="自分で計算", step=4, count=False)),
    dict(id="e10", text="まとめます。", section=True, scene=CARDS_N(1)),
    dict(id="e11", text="1つ目。死海は、毎年約1.1m下がる。40年で、30mです。"),
    dict(id="e12", text="2つ目。ヨルダン川の水は、9割減った。上流のダムと、水道や畑へ回っています。", scene=CARDS_N(2)),
    dict(id="e13", text="3つ目。下がる分の約4割は、塩を取る池。湖の水をくみ上げて、乾かしています。", scene=CARDS_N(3)),
    dict(id="e14", text="4つ目。1年に減る水は、約7億m³。東京ドーム、約570杯分です。", scene=CARDS_N(4)),
    dict(id="e15", text="5つ目。紅海から2.5億m³入れても、1年に約0.7m下がる。止めるには、減る分すべてが要ります。", scene=CARDS_N(5)),
    dict(id="e16", text="水は、空へ。その一部は、塩を取るために、わざと空へ出されていたのです。", scene=MAP(SEA_T, SHORE("1978", alpha=0.0, id="l78e"), step=4)),
    dict(id="e17", text="次に「死海の塩」を見かけたら、その塩のために乾かされた水を、思い出してください。", scene=MAP(SEA, step=4, view_to=(35.45, 31.45, 1.1, 20))),
])

# ---- ショート ---------------------------------------------------------------------------------------------
P["s1"] = dict(title="陸でいちばん低い湖は、40年で30m下がった", lines=[
    dict(id="k1", text="陸の上で、いちばん低い水面。死海です。", scene=MAP(SEA_P, SHORE("2000", id="s00k"))),
    dict(id="k2", text="2018年の水面は、海面より433m下。東京タワーを立てても、てっぺんはまだ海面の下です。", scene=BARS([("死海の水面（海面から下へ）", 433, BLUE), ("東京タワー", 333, GREY)], title="高さ（m）", fmt="{}")),
    dict(id="k3", text="その水面は、毎年、約1.1mずつ下がっています。", scene=MAP(SEA_P, SHORE("1978", alpha=0.0, id="l78k"), SHORE("2000", id="s00k2"))),
    dict(id="k4", text="40年で、30m。ビルの10階分です。", scene=CARD("40年で30m", sub="死海の水面が下がった高さ", view=SEA_P, count=False)),
    dict(id="k5", text="理由の1つは、入ってくるヨルダン川の水が、9割減ったことです。", scene=MAP(REGION_P, JRIVER("k"))),
    dict(id="k6", text="出口のない湖は、入る水が減れば、そのぶん下がるしかないのです。", scene=MAP(SEA_P, tr="whip")),
])

P["s2"] = dict(title="死海が下がる4割は、塩を取る池のせいだった", lines=[
    dict(id="m1", text="死海の水面は、毎年約1.1m下がっています。", scene=MAP(SEA_P, SHORE("2000", id="s00m"))),
    dict(id="m2", text="普通は、川の水を取ったからだと思いますよね。でも、それだけではありません。", scene=MAP(SEA_P, PIN(PONDS, "塩を取る池", id="p_pm"))),
    dict(id="m3", text="南には、肥料の原料のカリウムの塩を取る、工場の池が並んでいます。"),
    dict(id="m4", text="工場は、北の湖の水をくみ上げて、池で乾かしています。", scene=BARS([("くみ上げた水", 4.3, YEL), ("湖へ戻した水", 2.7, BLUE), ("差し引き", 1.6, RED)], title="ICLの池の水（億m³、2018年）", fmt="{}")),
    dict(id="m5", text="両岸の工場で、正味約2.5億m³。水面が下がる分の、約4割です。", scene=CARD("約4割", sub="下がる分のうち、塩を取る池の分", view=SEA_P, count=False)),
    dict(id="m6", text="死海の水は、塩を取るために、わざと空へ出されていたのです。", scene=MAP(SEA_P, tr="whip")),
])

P["s3"] = dict(title="ヨルダン川の水は、9割が死海に届かない", lines=[
    dict(id="n1", text="死海に入る川は、ヨルダン川です。", scene=MAP(REGION_P, JRIVER("n"), PIN(GALILEE, "ガリラヤ湖", id="p_gn"))),
    dict(id="n2", text="1955年より前と比べると、いま死海に届く水は、1割ほどしかありません。", scene=BARS([("1955年より前", 100, BLUE), ("いま", 10, YEL)], title="死海へ入る水（昔を100として）", fmt="{}")),
    dict(id="n3", text="ガリラヤ湖の出口のデガニアと、その下のアルモット。2つのダムで、流れはほとんど止まりました。", scene=MAP(REGION_P, JRIVER("n2"), PIN(DEGANIA, "デガニア", id="p_dn"))),
    dict(id="n4", text="上流で使われる水は、1年に約14億m³。まわりの国の水道と、畑に回っています。", scene=CARD("約14億m³", sub="上流で使われる水（1年）", view=REGION_P)),
    dict(id="n5", text="そのぶん、死海の下がり方は、1年に0.7mから、1.2mに速まりました。", scene=BARS([("1970〜80年代", 0.7, BLUE), ("2018年ごろ", 1.2, YEL)], title="1年に下がる高さ（m）", fmt="{}")),
    dict(id="n6", text="川の水を使えば、その先の湖が、下がるのです。", scene=MAP(SEA_P, tr="whip")),
])

P["s4"] = dict(title="死海の岸に、5,500個の穴が開いた理由", lines=[
    dict(id="q1", text="死海の岸には、5,500個もの穴が開いています。", scene=MAP(SEA_P, PIN(EINGEDI, "エンゲディ", id="p_eq"), SHORE("1978", alpha=0.0, id="l78q"))),
    dict(id="q2", text="2015年の時点の数です。", scene=CARD("約5,500個", sub="死海の岸に開いた穴（2015年）", view=SEA_P)),
    dict(id="q3", text="原因は、水面が下がったことです。40年で、30m下がりました。", scene=MAP(SEA_P, SHORE("1978", alpha=0.0, id="l78q2"), SHORE("2000", id="s00q"))),
    dict(id="q4", text="水が引いた岸の地下には、塩の層が残っています。"),
    dict(id="q5", text="そこへ真水の地下水が入ると、塩がとけて、地面がぬけ落ちるのです。", scene=CARD("塩がとける", sub="地下の塩の層に、真水が入る", view=SEA_P, count=False)),
    dict(id="q6", text="湖が下がると、陸にまで、穴が開くのです。", scene=MAP(SEA_P, tr="whip")),
])

P["s5"] = dict(title="紅海から水を引いても、死海は止まらない", lines=[
    dict(id="r1", text="下がり続ける死海に、紅海から水を引く案があります。", scene=MAP(WIDE_P, LINE([AQABA, (35.4, 31.1)], YEL, 8, id="r_rr"), PIN(AQABA, "紅海", id="p_ar"))),
    dict(id="r2", text="考えられてきたのは、1年に約2.5億m³を、管で運ぶ案です。", scene=CARD("約2.5億m³", sub="紅海から運ぶ水（1年）", view=WIDE_P)),
    dict(id="r3", text="2.5億m³を、死海の北の湖、641km²に広げると、深さ約0.39m。", scene=CARD("約0.39m", sub="2.5億m³ ÷ 641km²", view=SEA_P, count=False)),
    dict(id="r4", text="毎年1.1m下がる湖なら、まだ1年に約0.7m下がります。", scene=BARS([("いま", 1.1, YEL), ("紅海から入れたら", 0.71, BLUE)], title="1年に下がる高さ（m）", fmt="{}")),
    dict(id="r5", text="止めるには、毎年減る約7億m³を、まるごと足す必要があるのです。", scene=CARD("約7億m³", sub="止めるのに要る水（1年）", view=SEA_P, count=False)),
    dict(id="r6", text="水を足しても、出ていく分には、追いつかないのです。", scene=MAP(SEA_P, tr="whip")),
])

# ---- 読み ------------------------------------------------------------------------------------------------
YOMI = [("433m下", "四百三十三メートルした"), ("100m下", "百メートルした"), ("海面の下", "かいめんのした"), ("北の湖", "きたのみずうみ"), ("出ていく分", "でていくぶん"),
        ("海面下433m", "海面下四百三十三メートル"), ("433m", "四百三十三メートル"), ("約1.1m", "約一点一メートル"), ("1.1m", "一点一メートル"),
        ("約0.85m", "約レイテンハチゴメートル"), ("約0.75m", "約レイテンナナゴメートル"), ("約0.39m", "約レイテンサンキュウメートル"),
        ("約0.7m", "約レイテンナナメートル"), ("0.7m", "レイテンナナメートル"), ("約1.2m", "約一点二メートル"), ("1.2m", "一点二メートル"),
        ("約1m", "約一メートル"), ("100m", "百メートル"), ("30m", "三十メートル"),
        ("約641km²", "約六百四十一平方キロメートル"), ("641km²", "六百四十一平方キロメートル"),
        ("約1.7億m³", "約一点七億立方メートル"), ("約1億m³", "約一億立方メートル"), ("0.6億から4億m³", "れいてんろく億から四億立方メートル"),
        ("約7億m³", "約七億立方メートル"), ("7億m³", "七億立方メートル"), ("約14億m³", "約十四億立方メートル"), ("約4.3億m³", "約四点三億立方メートル"),
        ("約2.7億m³", "約二点七億立方メートル"), ("約1.6億m³", "約一点六億立方メートル"), ("約2.5億m³", "約二点五億立方メートル"), ("2.5億m³", "二点五億立方メートル"),
        ("約5,500個", "約五千五百個"), ("5,500個", "五千五百個"), ("約570杯分", "約五百七十杯分"), ("35%", "三十五パーセント"),
        ("2018年", "二千十八年"), ("2015年", "二千十五年"), ("2000年", "二千年"), ("1979年", "千九百七十九年"), ("1955年", "千九百五十五年"),
        ("1970年代", "千九百七十年代"), ("80年代", "八十年代"), ("40年", "四十年"), ("10階分", "じっかいぶん"),
        ("9割", "きゅうわり"), ("1割", "いちわり"), ("4割", "よんわり"), ("2倍", "にばい"),
        ("1つ目", "ひとつめ"), ("2つ目", "ふたつめ"), ("3つ目", "みっつめ"), ("4つ目", "よっつめ"), ("5つ目", "いつつめ"),
        ("2つ", "ふたつ"), ("1つ", "ひとつ"), ("1年", "いちねん"),
        ("死海", "しかい"), ("ICL", "アイシーエル"), ("紅海", "こうかい"), ("海面下", "かいめんか"), ("ガリラヤ湖", "ガリラヤこ"),
        ("ヨルダン川", "ヨルダンがわ"), ("ヨルダン側", "ヨルダンがわ"), ("両岸", "りょうぎし"), ("真水", "まみず"), ("琵琶湖", "びわこ"),
        ("等高線", "とうこうせん"), ("東京ドーム", "とうきょうドーム"), ("正味", "しょうみ"), ("掛け算", "かけざん"), ("一部", "いちぶ")]


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
