"""アラル海(地理・型 A 水の行方): 本編 5 章とショート 5 本の台本と画面。ch1〜ch5・s1〜s5 の ep.py がここから読む。

数字の出典:
- Micklin, Aladin, Chida ほか(2020)「The Aral Sea: A Story of Devastation and Partial Recovery of a Large Lake」
  (S. Mischke 編『Large Asian Lakes in a Changing World』Springer、doi:10.1007/978-3-030-42254-7)
  - 表 4.1: 1960 年 水面 53.4m・67,499km²・1,089km³・平均の深さ 16.1m・塩分 10g/L。1989 年 39,734km²。
    2014 年 6,990km²(1960 年の 10.4%)・東の湖 0。2018 年 9,668km²・西の湖 水面 23m・塩分 150g/L 超
  - 1911〜1960 年の水の出入り: 川 56km³ + 湖の上の雨と雪 9.1km³ = 65.1km³、蒸発 66.1km³(Bortnik・Chistyayeva 1990)
  - アムダリヤ: 山を出る 62km³ のうち湖に届くのは 40km³(1960 年より前)。長さ 2,620km。シルダリヤ: 37km³ のうち約 15km³
  - 畑(灌漑)は 1960 年 約 500 万 ha → 2010 年 820 万 ha。流域で取る水の 92% が畑
  - 東の湖: 1960 年 最大の深さ 28.4m、西の湖 69m。2014 年の夏に干上がった(おそらく約 600 年ぶり)
  - 塩まじりの砂嵐: 10 万km² を超え、風下へ 500km 超
  - 商業の漁は 1980 年代のはじめに終わった
  - コクアラルの堤防: 長さ 13km、2003〜2005 年。北の湖の漁獲 695t(2005)→ 6,000t(2016)
  - 1992〜2011 年に湖に入った水は平均 8.8km³/年
- Conrad・Kobildjanova「The Economics of an Environmental Disaster: The Aral Sea」(Cornell): 1975〜1985 年に湖へ入った川の水は約 10km³/年(Gleick 1993)
- 北海道の面積 83,424km²(国土地理院)。琵琶湖の水の量 27.5km³(滋賀県)。海水の塩分 約 35g/L
自分で計算したもの:
- 蒸発の深さ 66.1km³ ÷ 67,499km² = 0.98m/年(約 1m)。雨と雪を引くと (66.1−9.1) ÷ 67,499 = 0.844m/年
- 保てる広さ = 入る水 ÷ 0.844m。56km³ → 約 6 万 6,000km²。8.8km³ → 約 1 万 400km²
- 昔の岸の線: sim/measure.py で Terrain Tiles の等高線を引いた(53.4m の線の内側が約 68,600km²、記録とのずれ 2%)
地点の座標は地図から読んだ(読み): アラリスク・ムイナク・堤防・川の道すじ。"""
import json
from pathlib import Path

CREDIT = "地図: NASA・Terrain Tiles・Natural Earth"
RED, YEL, WHITE, BLUE = (240, 90, 80), (255, 214, 64), (255, 255, 255), (120, 190, 255)
GREY, GREEN, SAND = (170, 180, 200), (110, 200, 110), (226, 196, 140)
RIVER = (70, 210, 255)
LAKE = (40, 120, 255)

_S = json.loads((Path(__file__).parent / "sim" / "shores.json").read_text(encoding="utf-8"))["shores"]

# 地点(経度, 緯度)。読み
ARALSK, MUYNAK = (61.67, 46.80), (58.99, 43.77)
DIKE = (60.75, 46.12)
WEST_B, EAST_B = (58.55, 45.15), (60.4, 44.9)
NORTH_A = (61.1, 46.45)
AMU = [(71.4, 37.1), (67.3, 37.2), (65.2, 37.8), (63.6, 39.1), (61.4, 40.9), (60.6, 41.5), (59.6, 42.45), (59.4, 43.4)]
SYR = [(72.8, 40.8), (69.6, 40.3), (68.0, 41.25), (68.25, 43.3), (65.5, 44.85), (62.1, 45.76), (61.2, 46.05)]
PAMIR, TIAN = (72.5, 38.6), (75.0, 41.5)

ARAL = (60.0, 45.05, 4.8, 0)
ARAL_T = (60.0, 44.7, 4.4, 35)
BASIN = (64.0, 42.6, 19.0, 0)
WESTV = (59.0, 45.0, 2.0, 30)
NORTHV = (61.0, 46.3, 1.7, 30)
ARAL_P = (60.0, 45.05, 3.4, 0)
BASIN_P = (63.5, 42.5, 13.0, 0)
NORTH_P = (61.0, 46.3, 1.3, 0)


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
    """その年の湖の広さ(標高データの等高線)。alpha=0 なら岸の線だけ。"""
    return dict(kind="area", rings=_S[yr], color=color, alpha=alpha, width=width, id=id or f"shore_{yr}_{alpha}", at=at)


def RIVERS(at=0.0, tag=""):
    return [LINE(AMU, RIVER, 12, id=f"r_amu{tag}", at=at), LINE(SYR, RIVER, 12, id=f"r_syr{tag}", at=at)]


def CARD(big, sub=None, note=None, view=ARAL, step=None, count=True, tr=None):
    d = dict(shot="card", big=big, sub=sub, note=note, view=view, step=step, count=count)
    if tr:
        d["tr"] = tr
    return d


def BARS(items, title=None, note=None, fmt="{}", step=None, tr=None):
    d = dict(shot="bars", items=items, title=title, note=note, fmt=fmt, step=step)
    if tr:
        d["tr"] = tr
    return d


M2014 = "Micklin ほか（2020）"
IO = [("入る水（川＋雨と雪）", 65.1, BLUE), ("出る水（蒸発）", 66.1, YEL)]

ANSWERS = [("出口のない湖。毎年、深さ約1m分が空へ", "入る水と出る水が、つり合っていた"),
           ("くまれたのは、湖ではなく川の水", "届く水は1年に約56km³から約10km³へ"),
           ("畑は、北海道ほどの広さに", "流域で取る水の92%が畑へ"),
           ("浅い東側から消えた", "西は約30m下がり、塩は海の4倍以上"),
           ("広さ＝入る水÷0.84m", "8.8km³なら約1万km²。測った広さとほぼ同じ")]

P = {}

# ---- 第1章 消えた湖 ---------------------------------------------------------------------------------------
P["ch1"] = dict(title="第1章 消えた湖", cta=False, lines=[
    dict(id="a1", text="中央アジアの砂漠に、かつて、世界で4番目に大きな湖がありました。", scene=MAP(BASIN, SHORE("1960"), step=0, view_to=ARAL)),
    dict(id="a2", text="アラル海。1960年の広さは、約6万7,500km²。", scene=MAP(ARAL, SHORE("1960"), LABEL((59.9, 45.7), "1960年の湖", 60, WHITE), step=0)),
    dict(id="a3", text="北海道の、およそ8割の広さです。", scene=BARS([("アラル海（1960年）", 67499, BLUE), ("北海道", 83424, GREY)], title="広さ（km²）", note=M2014 + "・国土地理院", fmt="{:,}", step=0)),
    dict(id="a4", text="ところが、2014年の夏、湖の東側が、すっかり干上がりました。", scene=MAP(ARAL_T, SHORE("1960", alpha=0.0, width=5), LABEL(EAST_B, "干上がった", 60, YEL, on="干上がりました"), step=0)),
    dict(id="a5", text="残った水面は、1960年の、わずか1割です。", scene=CARD("約1割", sub="2014年に残った水面（1960年比）", note=M2014, step=0)),
    dict(id="a6", text="ためていた水は、琵琶湖のおよそ40杯分でした。", scene=BARS([("アラル海（1960年）", 1089, BLUE), ("琵琶湖", 27.5, GREY)], title="水の量（km³）", note=M2014 + "・滋賀県", fmt="{:,}", step=0)),
    dict(id="a7", text="その水は、どこへ消えたのか。", style="question", sub="世界4位の湖の水は\n【どこへ消えた】のか", scene=MAP(ARAL, SHORE("1960", alpha=0.0), step=0)),
    dict(id="a8", text="答えを先に言います。", section=True),
    dict(id="a9", text="水は、空へ消えました。", scene=MAP(ARAL_T, step=0, view_to=(60.0, 44.7, 3.6, 40))),
    dict(id="a10", text="アラル海には、出ていく川がありません。", scene=MAP(BASIN, *RIVERS(), step=0)),
    dict(id="a11", text="入った水は、蒸発して、空へ出ていくだけです。"),
    dict(id="a12", text="1960年までは、入る水と、空へ出る水が、ほぼ同じでした。", scene=BARS(IO, title="1年の水の出入り（km³）", note=M2014, fmt="{}", step=0)),
    dict(id="a13", text="そのつり合いを、何が崩したのか。", scene=MAP(ARAL, SHORE("1960"), step=0)),
    dict(id="a14", text="昔の岸は、標高データの等高線で、自分で引きました。", scene=MAP(ARAL, SHORE("1960", alpha=0.0, width=5, id="l60"), LABEL((58.4, 46.6), "1960年の岸", 50, BLUE), step=0)),
    dict(id="a15", text="水の出入りは、この湖を調べてきた研究者の論文で確かめます。"),
])

# ---- 第2章 出口のない湖 -----------------------------------------------------------------------------------
P["ch2"] = dict(title="第2章 出口のない湖", cta=False, lines=[
    dict(id="b1", text="まず、湖に入る水を見ます。", scene=MAP(BASIN, *RIVERS(), PIN(PAMIR, "パミール", id="p_pa"), PIN(TIAN, "天山", id="p_ti"), step=1)),
    dict(id="b2", text="アムダリヤ川と、シルダリヤ川。2本の川が、山の雪どけ水を運んできます。"),
    dict(id="b3", text="湖に届く水は、1年に約56km³でした。", scene=CARD("約56km³", sub="1年に湖へ届く川の水（1960年まで）", note=M2014, view=BASIN, step=1)),
    dict(id="b4", text="琵琶湖の水の、約2杯分です。", scene=BARS([("川から湖へ（1年）", 56, BLUE), ("琵琶湖", 27.5, GREY)], title="水の量（km³）", note=M2014 + "・滋賀県", fmt="{}", step=1)),
    dict(id="b5", text="湖の上に降る雨と雪が、1年に約9km³。"),
    dict(id="b6", text="出ていく水は、蒸発だけ。1年に約66km³です。", scene=BARS(IO, title="1年の水の出入り（km³）", note=M2014, fmt="{}", step=1)),
    dict(id="b7", text="この66km³を、湖の広さで割ってみます。", section=True, scene=MAP(ARAL_T, SHORE("1960"), step=1)),
    dict(id="b8", text="毎年、深さ約1m分の水が、空へ出ていたのです。", scene=CARD("約1m", sub="1年に空へ出る水の深さ", note="自分で計算（66.1km³÷6万7,499km²）", step=1, count=False)),
    dict(id="b9", text="それでも湖が保たれたのは、川が同じだけ、運び続けたからです。"),
    dict(id="b10", text="ここで、よくある思い込みを見ます。", section=True, scene=MAP(ARAL, SHORE("1960", alpha=0.0), step=1)),
    dict(id="b11", text="普通は、湖の水を、ポンプでくみ上げたと思いますよね。"),
    dict(id="b12", text="ところが、くまれたのは、湖の水ではありません。", scene=MAP(BASIN, *RIVERS(tag="2"), step=1)),
    dict(id="b13", text="湖に届く前の、川の水です。"),
    dict(id="b14", text="栓のないお風呂で、蛇口だけを細くしたのと同じです。", scene=CARD("蛇口だけ細く", sub="湯気で出ていく分は、変わらない", step=1, count=False)),
    dict(id="b15", text="湯気で出ていく分は、変わりません。だから、水位だけが下がり続けます。", scene=MAP(ARAL_T, SHORE("1960", alpha=0.0), SHORE("1989", id="s89"), step=1)),
])

# ---- 第3章 川の水の行方 -----------------------------------------------------------------------------------
P["ch3"] = dict(title="第3章 川の水の行方", cta=False, lines=[
    dict(id="c1", text="では、川の水は、どこへ行ったのか。", scene=MAP(BASIN, *RIVERS(), step=2, tr="zoom")),
    dict(id="c2", text="アムダリヤ川は、パミールの山から、約2,600km流れてきます。", scene=MAP(BASIN, LINE(AMU, RIVER, 12, id="r_amu3"), PIN(PAMIR, "パミール", id="p_pa3"), LABEL((63.2, 39.6), "アムダリヤ川", 52, BLUE), step=2)),
    dict(id="c3", text="山を出るときの水は、1年に約62km³。", scene=BARS([("山を出る", 62, BLUE), ("湖に届く", 40, YEL)], title="アムダリヤ川（km³／年、1960年より前）", note=M2014, fmt="{}", step=2)),
    dict(id="c4", text="ところが、湖に届くのは、1960年より前でも約40km³でした。"),
    dict(id="c5", text="砂漠を渡るあいだに、3分の1が消えていたのです。", scene=MAP(BASIN, LINE(AMU, RIVER, 12, id="r_amu3b"), step=2, view_to=(62.5, 40.5, 11, 25))),
    dict(id="c6", text="シルダリヤ川も同じです。約37km³のうち、届くのは約15km³。", scene=BARS([("山を出る", 37, BLUE), ("湖に届く", 15, YEL)], title="シルダリヤ川（km³／年、1960年より前）", note=M2014, fmt="{}", step=2)),
    dict(id="c7", text="そこへ、畑が広がりました。", section=True, scene=MAP(BASIN, *RIVERS(tag="3"), step=2)),
    dict(id="c8", text="育てたのは、主に綿花です。1960年に、約500万ヘクタール。", scene=CARD("約500万ha", sub="流域の畑（1960年）", note=M2014, view=BASIN, step=2)),
    dict(id="c9", text="2010年には、約820万ヘクタール。北海道と、ほぼ同じ広さです。", scene=BARS([("流域の畑（2010年）", 82000, YEL), ("北海道", 83424, GREY)], title="広さ（km²）", note=M2014 + "・国土地理院", fmt="{:,}", step=2)),
    dict(id="c10", text="この流域で取る水の、92%が、畑に使われています。", scene=CARD("92%", sub="流域で取る水のうち、畑の分", note=M2014, view=BASIN, step=2, count=False)),
    dict(id="c11", text="1975年から85年、湖に届いた水は、1年に約10km³。", scene=BARS([("1960年まで", 56, BLUE), ("1975〜85年", 10, YEL)], title="1年に湖へ届く川の水（km³）", note=M2014 + "・Gleick（1993）", fmt="{}", step=2)),
    dict(id="c12", text="1960年までの、約5分の1です。"),
    dict(id="c13", text="畑にまいた水も、多くは葉っぱや土から、空へ出ていきます。", scene=MAP(BASIN, step=2, view_to=(63.0, 41.0, 12, 30))),
    dict(id="c14", text="水は、湖ではなく、畑の上で、空へ出ていくようになったのです。"),
])

# ---- 第4章 干上がった底 -----------------------------------------------------------------------------------
P["ch4"] = dict(title="第4章 干上がった底", cta=False, lines=[
    dict(id="d1", text="水が減ると、湖はどうなったのか。", scene=MAP(ARAL, SHORE("1960", alpha=0.0), SHORE("1989", id="s89d"), step=3, tr="zoom")),
    dict(id="d2", text="1987年ごろ、湖は、北と南の2つに分かれました。", scene=MAP(ARAL, SHORE("1960", alpha=0.0), SHORE("1989", id="s89e"), LABEL(NORTH_A, "北の湖", 54, WHITE), LABEL((59.6, 44.7), "南の湖", 54, WHITE), step=3)),
    dict(id="d3", text="南の湖は、やがて東と西に分かれます。", scene=MAP(ARAL_T, SHORE("1960", alpha=0.0), LABEL(WEST_B, "西", 64, WHITE), LABEL(EAST_B, "東", 64, WHITE), step=3)),
    dict(id="d4", text="ここで、湖の底の形が効いてきます。", section=True),
    dict(id="d5", text="東側は浅く、1960年でも、いちばん深いところで約28m。", scene=BARS([("東側", 28.4, YEL), ("西側", 69, BLUE)], title="1960年のいちばん深いところ（m）", note=M2014, fmt="{}", step=3)),
    dict(id="d6", text="西側は深く、約69mありました。"),
    dict(id="d7", text="だから、浅い東側が、先に消えたのです。", scene=MAP(ARAL_T, SHORE("1960", alpha=0.0), LABEL(EAST_B, "浅い", 64, YEL), LABEL(WEST_B, "深い", 64, BLUE), step=3)),
    dict(id="d8", text="2014年の夏。東側は、およそ600年ぶりに干上がったとみられています。"),
    dict(id="d9", text="西側も、2018年には、水面が約30m下がりました。", scene=CARD("約30m", sub="西側の水面が下がった高さ（1960→2018年）", note=M2014, view=WESTV, step=3)),
    dict(id="d10", text="ビルの、およそ10階分です。"),
    dict(id="d11", text="水が減ると、塩は濃くなります。", section=True, scene=MAP(WESTV, step=3)),
    dict(id="d12", text="もとは、海の3分の1ほどの、薄い塩水でした。", scene=BARS([("1960年", 10, BLUE), ("海水", 35, GREY), ("2018年の西側", 150, YEL)], title="1リットルの塩（g）", note=M2014, fmt="{}", step=3)),
    dict(id="d13", text="それが西側では、1リットルに150g以上。海の4倍を超えました。"),
    dict(id="d14", text="魚はすめなくなり、1980年代のはじめに、漁は終わりました。", scene=MAP(ARAL, PIN(MUYNAK, "ムイナク", id="p_mu"), PIN(ARALSK, "アラリスク", id="p_ar"), SHORE("1960", alpha=0.0), step=3)),
    dict(id="d15", text="干上がった底には、塩が残ります。", section=True, scene=MAP(ARAL_T, SHORE("1960", color=SAND, alpha=0.3), step=3)),
    dict(id="d16", text="強い風が吹くと、塩まじりの砂嵐になります。"),
    dict(id="d17", text="大きいものは、10万km²以上をおおいます。北海道より、広い範囲です。", scene=CARD("10万km²以上", sub="塩まじりの砂嵐がおおう広さ", note=M2014, step=3)),
    dict(id="d18", text="風下へ、500km以上届くこともあります。"),
])

# ---- 第5章 広さの答え -------------------------------------------------------------------------------------
_CV = [(ARAL, (60.0, 45.0, 4.2, 20)), (BASIN, (64.0, 41.5, 15, 20)), (BASIN, (62.5, 41.2, 11, 30)),
       (ARAL_T, (60.0, 44.8, 3.8, 35)), (ARAL, (60.0, 45.0, 5.2, 10))]
CARDS_N = lambda n: dict(shot="cards", items=ANSWERS, n=n, view=_CV[n - 1][0], view_to=_CV[n - 1][1], step=4)  # noqa: E731
P["ch5"] = dict(title="第5章 広さの答え", cta=True, lines=[
    dict(id="e1", text="最後に、湖の広さを、割り算で出してみます。", scene=MAP(ARAL, SHORE("1960"), step=4, tr="zoom")),
    dict(id="e2", text="1年に空へ出る水の深さは、雨と雪の分を引くと、約0.84m。", scene=CARD("約0.84m", sub="1年に空へ出る深さ（雨と雪を引いた分）", note="自分で計算", step=4, count=False)),
    dict(id="e3", text="入ってくる水を、この深さで割る。それが、湖が保てる広さです。", scene=CARD("入る水÷0.84m", sub="湖が保てる広さ", note="自分で計算", step=4, count=False)),
    dict(id="e4", text="1960年までの約56km³なら、約6万6,000km²。", scene=BARS([("割り算の答え", 66300, YEL), ("1960年の記録", 67499, BLUE)], title="広さ（km²）", note="自分で計算・" + M2014, fmt="{:,}", step=4)),
    dict(id="e5", text="記録の約6万7,500km²と、ほぼ同じです。"),
    dict(id="e6", text="1992年から2011年の20年間。入った水は、平均で1年に約8.8km³。", section=True, scene=CARD("約8.8km³", sub="1年に湖へ入った水（1992〜2011年の平均）", note=M2014, step=4)),
    dict(id="e7", text="割ると、約1万400km²。", scene=BARS([("割り算の答え", 10400, YEL), ("2018年に測った広さ", 9668, BLUE)], title="広さ（km²）", note="自分で計算・" + M2014, fmt="{:,}", step=4)),
    dict(id="e8", text="2018年に測られた広さは、約9,700km²。計算と、ほぼ合います。"),
    dict(id="e9", text="湖は、入る水に見合う大きさまで、縮んだのです。", scene=MAP(ARAL_T, SHORE("1960", alpha=0.0), step=4)),
    dict(id="e10", text="北の小さな湖では、逆のことが起きました。", section=True, scene=MAP(NORTHV, PIN(DIKE, "堤防", id="p_dk"), PIN(ARALSK, "アラリスク", id="p_ar5"), step=4)),
    dict(id="e11", text="2005年、カザフスタンが、長さ13kmの堤防を完成させました。", scene=CARD("13km", sub="北の湖の堤防（2005年）", note=M2014, view=NORTHV, step=4)),
    dict(id="e12", text="北の湖の水が、南へ流れ出るのを止めたのです。"),
    dict(id="e13", text="水面は上がり、魚が戻りました。漁獲は、2005年の695トンから、2016年に6,000トン。", scene=BARS([("2005年", 695, GREY), ("2016年", 6000, YEL)], title="北の湖の漁獲（トン）", note=M2014, fmt="{:,}", step=4)),
    dict(id="e14", text="約9倍に増えました。"),
    dict(id="e15", text="まとめます。", section=True, scene=CARDS_N(1)),
    dict(id="e16", text="1つ目。出口のない湖から、毎年、深さ約1m分の水が空へ出ていた。入る水と、つり合っていました。"),
    dict(id="e17", text="2つ目。くまれたのは、湖ではなく川の水。届く水は、1年に約56km³から、約10km³に減りました。", scene=CARDS_N(2)),
    dict(id="e18", text="3つ目。畑は、北海道ほどの広さに。流域で取る水の92%が、畑に使われています。", scene=CARDS_N(3)),
    dict(id="e19", text="4つ目。浅い東側から消えた。西側は約30m下がり、塩は海の4倍を超えました。", scene=CARDS_N(4)),
    dict(id="e20", text="5つ目。湖の広さは、入る水を0.84mで割った数。計算は、測った広さとほぼ合います。", scene=CARDS_N(5)),
    dict(id="e21", text="水は、なくなったのではありません。畑の上で、空へ出ていったのです。", scene=MAP(ARAL, SHORE("1960"), step=4, view_to=(60.0, 45.0, 4.0, 30))),
    dict(id="e22", text="次にお風呂で湯気を見たら、アラル海を思い出してください。", scene=MAP(ARAL_T, SHORE("1960", alpha=0.0), step=4)),
])

# ---- ショート ---------------------------------------------------------------------------------------------
P["s1"] = dict(title="北海道の8割あった湖が、1割に。水は空へ消えた", lines=[
    dict(id="k1", text="中央アジアのアラル海。1960年には、世界で4番目に大きな湖でした。", scene=MAP(ARAL_P, SHORE("1960"))),
    dict(id="k2", text="広さは約6万7,500km²。北海道の8割ほどです。", scene=BARS([("アラル海（1960年）", 67499, BLUE), ("北海道", 83424, GREY)], title="広さ（km²）", fmt="{:,}")),
    dict(id="k3", text="2014年、残った水面は、その1割になりました。", scene=MAP(ARAL_P, SHORE("1960", alpha=0.0, width=5))),
    dict(id="k4", text="水は、どこへ消えたのか。答えは、空です。", scene=CARD("空へ", sub="アラル海の水の行き先", view=ARAL_P, count=False)),
    dict(id="k5", text="この湖には、出ていく川がありません。入る水と、蒸発する水のつり合いで、大きさが決まっていました。", scene=BARS(IO, title="1年の水の出入り（km³）", fmt="{}")),
    dict(id="k6", text="その川の水を、上流で畑に引いた。だから湖は、縮んだのです。", scene=MAP(BASIN_P, *RIVERS(), tr="whip")),
])

P["s2"] = dict(title="アラル海は、毎年1mずつ空へ消えていた", lines=[
    dict(id="m1", text="アラル海からは、毎年、深さ約1m分の水が、空へ出ていました。", scene=MAP(ARAL_P, SHORE("1960"))),
    dict(id="m2", text="蒸発する水は、1年に約66km³。琵琶湖の2杯分を超えます。", scene=BARS([("1年の蒸発", 66.1, YEL), ("琵琶湖", 27.5, GREY)], title="水の量（km³）", fmt="{}")),
    dict(id="m3", text="それでも湖は保たれました。2本の川が、1年に約56km³を運んでいたからです。", scene=MAP(BASIN_P, *RIVERS())),
    dict(id="m4", text="雨と雪の約9km³を足すと、出る水とほぼ同じです。", scene=BARS(IO, title="1年の水の出入り（km³）", fmt="{}")),
    dict(id="m5", text="ところが1975年からの10年。湖に届く川の水は、約10km³に減りました。", scene=BARS([("1960年まで", 56, BLUE), ("1975〜85年", 10, YEL)], title="1年に湖へ届く川の水（km³）", fmt="{}")),
    dict(id="m6", text="出ていく分は、変わらない。だから水位が、下がり続けたのです。", scene=MAP(ARAL_P, SHORE("1960", alpha=0.0), SHORE("1989", id="s89m"), tr="whip")),
])

P["s3"] = dict(title="縮んだ湖の広さを、割り算1つで当ててみた", lines=[
    dict(id="n1", text="アラル海が縮んだあとの広さは、割り算1つで、ほぼ当てられます。", scene=MAP(ARAL_P, SHORE("1960", alpha=0.0))),
    dict(id="n2", text="1年に空へ出る水の深さは、雨と雪の分を引いて、約0.84m。", scene=CARD("約0.84m", sub="1年に空へ出る深さ", view=ARAL_P, count=False)),
    dict(id="n3", text="入ってくる水を、この深さで割る。それが、湖が保てる広さです。", scene=CARD("入る水÷0.84m", sub="湖が保てる広さ", view=ARAL_P, count=False)),
    dict(id="n4", text="1992年から2011年の20年間。入った水は、平均で1年に約8.8km³。"),
    dict(id="n5", text="割ると、約1万400km²。2018年に測った広さは、約9,700km²。ほぼ同じです。", scene=BARS([("割り算の答え", 10400, YEL), ("2018年に測った広さ", 9668, BLUE)], title="広さ（km²）", fmt="{:,}")),
    dict(id="n6", text="湖は、入る水に見合う大きさまで、縮んだのです。", scene=MAP(ARAL_P, SHORE("1960", alpha=0.0), tr="whip")),
])

P["s4"] = dict(title="アラル海の塩は、海の4倍より濃くなった", lines=[
    dict(id="q1", text="アラル海は、もとは、海の3分の1ほどの薄い塩水でした。", scene=MAP(ARAL_P, SHORE("1960"))),
    dict(id="q2", text="水が減って、2018年、西側の水面は約30m下がりました。ビル10階分です。", scene=CARD("約30m", sub="西側の水面が下がった高さ", view=ARAL_P)),
    dict(id="q3", text="水は空へ出ても、塩は残ります。塩分は、1リットルに150g以上。海の4倍以上です。", scene=BARS([("1960年", 10, BLUE), ("海水", 35, GREY), ("2018年の西側", 150, YEL)], title="1リットルの塩（g）", fmt="{}")),
    dict(id="q4", text="魚はすめなくなり、1980年代のはじめに、漁は終わりました。", scene=MAP(ARAL_P, PIN(MUYNAK, "ムイナク", id="p_qm"), SHORE("1960", alpha=0.0))),
    dict(id="q5", text="干上がった底からは、塩まじりの砂嵐。500km以上先まで届きます。", scene=MAP(ARAL_P, SHORE("1960", color=SAND, alpha=0.3))),
    dict(id="q6", text="水が減った湖には、塩だけが、残るのです。", scene=MAP(ARAL_P, tr="whip")),
])

P["s5"] = dict(title="13kmの堤防1本で、北の湖に魚が戻った", lines=[
    dict(id="r1", text="縮んだアラル海の北側で、湖が戻り始めた場所があります。", scene=MAP(NORTH_P, PIN(ARALSK, "アラリスク", id="p_ra"))),
    dict(id="r2", text="2005年、カザフスタンが、長さ13kmの堤防を完成させました。", scene=CARD("13km", sub="北の湖の堤防（2005年）", view=NORTH_P)),
    dict(id="r3", text="北の湖の水が、南へ流れ出るのを止めたのです。", scene=MAP(NORTH_P, PIN(DIKE, "堤防", id="p_rd"))),
    dict(id="r4", text="水面は上がり、塩は1960年ごろより薄くなりました。"),
    dict(id="r5", text="漁獲は、2005年の695トンから、2016年に6,000トン。約9倍です。", scene=BARS([("2005年", 695, GREY), ("2016年", 6000, YEL)], title="北の湖の漁獲（トン）", fmt="{:,}")),
    dict(id="r6", text="入る水と、出ていく水。つり合いを取り戻せば、湖は戻るのです。", scene=MAP(NORTH_P, tr="whip")),
])

# ---- 読み ------------------------------------------------------------------------------------------------
YOMI = [("北の湖", "きたのみずうみ"), ("アムダリヤ川", "アムダリヤがわ"), ("シルダリヤ川", "シルダリヤがわ"), ("雪どけ水", "ゆきどけみず"),
        ("約6万7,500km²", "約六万七千五百平方キロメートル"), ("6万7,500km²", "六万七千五百平方キロメートル"),
        ("約6万6,000km²", "約六万六千平方キロメートル"), ("約1万400km²", "約一万四百平方キロメートル"),
        ("約9,700km²", "約九千七百平方キロメートル"), ("10万km²", "十万平方キロメートル"),
        ("56km³", "五十六立方キロメートル"), ("66km³", "六十六立方キロメートル"), ("62km³", "六十二立方キロメートル"),
        ("40km³", "四十立方キロメートル"), ("37km³", "三十七立方キロメートル"), ("15km³", "十五立方キロメートル"),
        ("10km³", "十立方キロメートル"), ("9km³", "九立方キロメートル"), ("8.8km³", "八点八立方キロメートル"),
        ("0.84m", "れいてんはちよんメートル"), ("2,600km", "二千六百キロ"), ("500km", "五百キロ"), ("13km", "十三キロ"),
        ("約500万ヘクタール", "約五百万ヘクタール"), ("約820万ヘクタール", "約八百二十万ヘクタール"),
        ("695トン", "六百九十五トン"), ("6,000トン", "六千トン"), ("150g", "百五十グラム"),
        ("28m", "二十八メートル"), ("69m", "六十九メートル"), ("30m", "三十メートル"), ("約1m", "約一メートル"), ("1m", "一メートル"),
        ("92%", "九十二パーセント"), ("1960年", "千九百六十年"), ("2014年", "二千十四年"), ("2018年", "二千十八年"), ("2005年", "二千五年"),
        ("2016年", "二千十六年"), ("2010年", "二千十年"), ("1975年", "千九百七十五年"), ("85年", "八十五年"), ("1987年", "千九百八十七年"),
        ("1992年", "千九百九十二年"), ("2011年", "二千十一年"), ("1980年代", "千九百八十年代"), ("600年", "六百年"), ("20年間", "二十年間"), ("10年", "十年"),
        ("10階分", "じっかいぶん"), ("40杯分", "よんじゅっぱいぶん"), ("2杯分", "にはいぶん"), ("4倍", "よんばい"), ("9倍", "きゅうばい"),
        ("8割", "はちわり"), ("1割", "いちわり"), ("3分の1", "さんぶんのいち"), ("5分の1", "ごぶんのいち"), ("4番目", "よんばんめ"),
        ("1つ目", "ひとつめ"), ("2つ目", "ふたつめ"), ("3つ目", "みっつめ"), ("4つ目", "よっつめ"), ("5つ目", "いつつめ"),
        ("2つ", "ふたつ"), ("2本", "にほん"), ("1リットル", "いちリットル"), ("1年", "いちねん"), ("1つ", "ひとつ"),
        ("アラル海", "アラルかい"), ("綿花", "めんか"), ("漁獲", "ぎょかく"), ("風下", "かざしも"), ("湯気", "ゆげ"), ("蛇口", "じゃぐち"),
        ("栓", "せん"), ("琵琶湖", "びわこ"), ("等高線", "とうこうせん")]


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
