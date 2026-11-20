"""シベリア(地理・型 E いない): 本編 5 章とショート 5 本の台本と画面。ch1〜ch5・s1〜s5 の ep.py がここから読む。
画面の作りは死海の回(episodes/deadsea/parts.py)を写した。ここでの「シベリア」はロシアのシベリア連邦管区＋極東連邦管区。

数字の出典:
- ロシア統計局 2021 年国勢調査: シベリア連邦管区 436 万 1,800km²・1,680 万 0,947 人、極東連邦管区 695 万 2,600km²・797 万 5,762 人
  → あわせて 1,131 万km²・2,478 万人。1km² あたり 約 2.2 人
- 日本: 37 万 8,000km²(国土地理院)・約 1 億 2,400 万人(総務省 人口推計)。1km² あたり 約 330 人
- 永久凍土: ロシアの国土の約 65%(ロシア天然資源・環境相 コズロフ、2021 年)
- シベリア鉄道 モスクワ〜ウラジオストク 9,288km(ロシア鉄道)
自分で測ったもの(sim/measure.py、Natural Earth):
- 州の多角形を正積の図法で足すと 1,120 万km²、日本の 30.0 倍(統計局の値と 1% ちがい)
- 町(populated places 252 か所、都市の人口の見積もり pop_max の合計 1,543 万人)を緯度で分けると、
  北緯 60 度より北は 土地の 39%・町の人口の 7%、北緯 55 度より南は 土地の 35%・町の人口の 61%。大きな町の上位 15 はすべて北緯 57 度より南。東京〜北極点は約 6,030km(緯度から計算)
- 同じ緯度の町(pop_max): ヘルシンキ 北緯 60.2 度 111 万・ストックホルム 59.4 度 126 万・ムルマンスク 69.0 度 32 万・
  ノリリスク 69.3 度 17 万・スルグト 61.3 度 40 万
地点・川・鉄道の道すじは地図から読んだ(読み)。"""
import json
from pathlib import Path

CREDIT = "地図: NASA・Terrain Tiles・Natural Earth"
RED, YEL, WHITE, BLUE = (240, 90, 80), (255, 214, 64), (255, 255, 255), (120, 190, 255)
GREY, GREEN, SAND = (170, 180, 200), (110, 200, 110), (226, 196, 140)
RIVER = (70, 210, 255)
AREA = (255, 150, 60)

_M = json.loads((Path(__file__).parent / "sim" / "measure.json").read_text(encoding="utf-8"))

# 地点(経度, 緯度)。読み
MOSCOW, YEKAT, OMSK, NOVOSIB = (37.6, 55.75), (60.6, 56.84), (73.4, 55.0), (82.96, 55.03)
KRASNO, IRKUTSK, ULANUDE, CHITA = (92.86, 56.02), (104.25, 52.32), (107.6, 51.8), (113.5, 52.05)
KHABA, VLADI = (135.1, 48.45), (131.9, 43.13)
YAKUTSK, NORILSK, SURGUT = (129.74, 62.03), (88.22, 69.34), (73.43, 61.26)
HELSINKI, STOCKHOLM, MURMANSK = (24.93, 60.18), (18.1, 59.35), (33.1, 68.97)
RAIL = [MOSCOW, YEKAT, OMSK, NOVOSIB, KRASNO, IRKUTSK, ULANUDE, CHITA, (127.5, 50.3), KHABA, VLADI]
OB = [(85.0, 52.0), (83.0, 55.0), (77.0, 61.0), (69.0, 61.0), (66.0, 66.5), (67.0, 71.0)]
YENISEI = [(92.0, 53.7), (92.9, 56.0), (90.0, 60.0), (86.5, 66.0), (86.2, 69.4), (82.5, 72.0)]
LENA = [(106.0, 54.0), (115.0, 58.0), (122.0, 60.5), (129.7, 62.0), (127.5, 66.0), (125.5, 70.0), (127.0, 72.5)]

ALL = (104.0, 60.0, 165.0, 0)
ALL_T = (104.0, 56.0, 145.0, 25)
WEST = (55.0, 61.0, 115.0, 0)
SOUTHB = (100.0, 53.0, 95.0, 20)
NORTHV = (100.0, 65.0, 85.0, 20)
YAKV = (129.0, 62.0, 42.0, 15)
NORV = (90.0, 68.0, 42.0, 15)
ALL_P = (104.0, 60.0, 125.0, 0)
WEST_P = (45.0, 62.0, 85.0, 0)
SOUTHB_P = (100.0, 54.0, 75.0, 0)
NORTH_P = (100.0, 65.0, 65.0, 0)


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


def SIB(alpha=0.35, width=4, id=None, color=AREA):
    """シベリア＋極東の外形(Natural Earth の州をまとめたもの)。"""
    return dict(kind="area", rings=_M["rings"], color=color, alpha=alpha, width=width, id=id or f"sib_{alpha}", at=0.0)


def LAT(lat, tag="", color=YEL):
    """緯度の線(東経 40〜180 度)。"""
    return LINE([(lo, lat) for lo in range(40, 181, 10)], color, 5, id=f"lat{lat}{tag}")


def RIVERS(tag=""):
    return [LINE(OB, RIVER, 10, id=f"ob{tag}"), LINE(YENISEI, RIVER, 10, id=f"ye{tag}"), LINE(LENA, RIVER, 10, id=f"le{tag}")]


def JAPAN(alpha=0.6):
    return dict(kind="fill", code="JPN", color=RED, alpha=alpha, id=f"jp_{alpha}", at=0.0)


def CARD(big, sub=None, note=None, view=ALL, step=None, count=True, tr=None):
    d = dict(shot="card", big=big, sub=sub, note=note, view=view, step=step, count=count)
    if tr:
        d["tr"] = tr
    return d


def BARS(items, title=None, note=None, fmt="{}", step=None, tr=None):
    d = dict(shot="bars", items=items, title=title, note=note, fmt=fmt, step=step)
    if tr:
        d["tr"] = tr
    return d


CENSUS, MINE = "ロシア統計局（2021年国勢調査）", "自分で測った（Natural Earth）"
LANDPOP = BARS([("60度より北：土地", 39, GREY), ("60度より北：町の人", 7, YEL),
                ("55度より南：土地", 35, GREY), ("55度より南：町の人", 61, BLUE)], title="シベリア全体に占める割合（%）", note=MINE, fmt="{}%")

ANSWERS = [("日本の30倍の土地に、日本の5分の1の人", "1km²あたり約2人。日本の150分の1"),
           ("寒さだけではない", "同じ北緯60度に、100万人の町がある"),
           ("凍った地面と、北へ流れる川", "国土の約65%が永久凍土。川は凍る北の海へ"),
           ("人は、南の鉄道の帯に集まる", "北緯55度より南に、町の人の61%"),
           ("北の町は、資源か港があるところ", "ノリリスクのニッケル、スルグトの石油")]

P = {}

# ---- 第1章 日本の30倍 -------------------------------------------------------------------------------------
P["ch1"] = dict(title="第1章 日本の30倍", cta=False, lines=[
    dict(id="a1", text="ロシアの東側に広がる、シベリア。", scene=MAP(ALL, SIB(), step=0)),
    dict(id="a2", text="シベリアと極東をあわせた広さは、約1,131万km²。", scene=CARD("約1,131万km²", sub="シベリア連邦管区＋極東連邦管区", note=CENSUS, step=0)),
    dict(id="a3", text="日本の、およそ30倍です。", scene=MAP(ALL, SIB(id="sib_a3"), JAPAN(), LABEL((138.0, 33.0), "日本", 54, WHITE), step=0)),
    dict(id="a4", text="地図の州の形から、自分で面積を足しても、30.0倍でした。", scene=BARS([("シベリア＋極東", 1120, AREA), ("日本", 37.3, RED)], title="広さ（万km²、自分で測った）", note=MINE, fmt="{:,}", step=0)),
    dict(id="a5", text="ところが、住んでいる人は、約2,478万人。", scene=CARD("約2,478万人", sub="シベリア＋極東の人口（2021年）", note=CENSUS, step=0)),
    dict(id="a6", text="日本の、5分の1ほどしかいません。", scene=BARS([("シベリア＋極東", 2478, AREA), ("日本", 12400, RED)], title="人口（万人）", note=CENSUS + "・総務省", fmt="{:,}", step=0)),
    dict(id="a7", text="1km²あたり、約2人。日本は、約330人です。", scene=BARS([("シベリア＋極東", 2.2, AREA), ("日本", 330, RED)], title="1km²あたりの人（人）", note=CENSUS + "・総務省", fmt="{}", step=0)),
    dict(id="a8", text="日本の、150分の1の混み方です。"),
    dict(id="a9", text="なぜ、こんなに広い土地に、人がいないのか。", style="question", sub="日本の30倍の土地に\n【人がいない】理由", scene=MAP(ALL_T, SIB(alpha=0.2, id="sib_q"), step=0)),
    dict(id="a10", text="答えを先に言います。", section=True),
    dict(id="a11", text="寒さだけではありません。凍った地面と、北へ流れる川。", scene=MAP(ALL, *RIVERS(), step=0)),
    dict(id="a12", text="そして、人が通れる道が、南の1本の帯にしかないことです。", scene=MAP(ALL, LINE(RAIL, YEL, 8, id="rail_a"), step=0)),
    dict(id="a13", text="町がどこにあるかは、地図のデータで、緯度ごとに自分で数えました。", scene=MAP(ALL, LAT(60, "a"), LAT(55, "a", BLUE), LABEL((150, 61.5), "北緯60度", 44, YEL), step=0)),
])

# ---- 第2章 寒さではない -----------------------------------------------------------------------------------
P["ch2"] = dict(title="第2章 寒さではない", cta=False, lines=[
    dict(id="b1", text="まず、どこに人がいるのかを見ます。", scene=MAP(ALL, LAT(60, "b"), LAT(55, "b", BLUE), step=1)),
    dict(id="b2", text="シベリアの町、252か所の人口を、緯度で分けて足しました。"),
    dict(id="b3", text="北緯60度より北は、土地の39%。でも、町に住む人は、7%だけです。", scene=LANDPOP),
    dict(id="b4", text="北緯55度より南は、土地の35%に、町の人の61%が集まっています。"),
    dict(id="b5", text="人は、南の端に寄っているのです。", scene=MAP(ALL_T, LAT(55, "b2", BLUE), PIN(NOVOSIB, "ノボシビルスク", id="p_nv"), PIN(KRASNO, "クラスノヤルスク", id="p_kr"), step=1)),
    dict(id="b6", text="普通は、北は寒いから、人が住めないと思いますよね。", section=True, scene=MAP(NORTHV, LAT(60, "b3"), step=1)),
    dict(id="b7", text="ところが、同じ北緯60度に、100万人を超える町があります。", scene=MAP(WEST, LAT(60, "b4"), PIN(HELSINKI, "ヘルシンキ", id="p_he"), PIN(STOCKHOLM, "ストックホルム", id="p_st"), step=1)),
    dict(id="b8", text="フィンランドのヘルシンキ。北緯60.2度に、約111万人。", scene=BARS([("ヘルシンキ", 111, BLUE), ("ストックホルム", 126, BLUE), ("シベリア北部", 102, AREA)], title="北緯60度前後の町の人口（万人）", note=MINE, fmt="{}", step=1)),
    dict(id="b9", text="スウェーデンのストックホルムは、北緯59.4度に、約126万人。", scene=MAP(WEST, LAT(60, "b9"), PIN(STOCKHOLM, "ストックホルム", id="p_st9"), step=1)),
    dict(id="b10", text="北緯60度より北のシベリアの町を、ぜんぶ足しても、約102万人です。", scene=CARD("約102万人", sub="北緯60度より北のシベリアの町、ぜんぶ", note=MINE, view=NORTHV, step=1)),
    dict(id="b11", text="もっと北にも、町はあります。北緯69度のムルマンスクに、約32万人。", scene=MAP(WEST, PIN(MURMANSK, "ムルマンスク", id="p_mu"), LAT(69, "b"), step=1)),
    dict(id="b12", text="ムルマンスクは、冬も凍らない港の町です。", scene=CARD("冬も凍らない港", sub="ムルマンスク（北緯69度）", view=WEST, step=1, count=False)),
    dict(id="b13", text="緯度だけでは、決まらない。では、シベリアの北には、何が足りないのか。"),
])

# ---- 第3章 凍った地面と北へ流れる川 ------------------------------------------------------------------------
P["ch3"] = dict(title="第3章 凍った地面と北へ流れる川", cta=False, lines=[
    dict(id="c1", text="1つ目は、地面です。", scene=MAP(NORTHV, step=2, tr="zoom")),
    dict(id="c2", text="ロシアの国土の約65%は、永久凍土の地域です。", scene=CARD("約65%", sub="ロシアの国土のうち永久凍土の地域", note="ロシア天然資源・環境相（2021年）", view=NORTHV, step=2, count=False)),
    dict(id="c3", text="1年じゅう凍ったままの地面です。"),
    dict(id="c4", text="家を建てると、家の熱で、下の氷がとけて、地面が沈みます。", scene=CARD("家の熱で沈む", sub="凍った地面の上に建てると", view=YAKV, step=2, count=False)),
    dict(id="c5", text="だから北の町の建物は、くいを打って、地面から浮かせて建てます。"),
    dict(id="c6", text="道路も、鉄道も、同じ苦労をします。"),
    dict(id="c7", text="2つ目は、川です。", section=True, scene=MAP(ALL, *RIVERS("c"), step=2)),
    dict(id="c8", text="シベリアの大きな川、オビ川、エニセイ川、レナ川。", scene=MAP(ALL, *RIVERS("c2"), LABEL((73.0, 64.0), "オビ川", 48, RIVER), LABEL((91.0, 63.0), "エニセイ川", 48, RIVER), LABEL((123.0, 64.5), "レナ川", 48, RIVER), step=2)),
    dict(id="c9", text="どれも、南から北へ流れて、北極海に出ます。"),
    dict(id="c10", text="日本の川は、町と海をつなぐ道になります。", scene=MAP(ALL_T, *RIVERS("c3"), step=2)),
    dict(id="c11", text="ところがシベリアの川は、凍る北の海へ向かうので、外の世界への道になりません。"),
    dict(id="c12", text="しかも春は、南の上流から先にとけます。", scene=MAP(NORTHV, *RIVERS("c4"), step=2)),
    dict(id="c13", text="下流は、まだ凍ったまま。行き場のない水が、あふれて洪水になるのです。"),
])

# ---- 第4章 鉄道の帯 ---------------------------------------------------------------------------------------
P["ch4"] = dict(title="第4章 鉄道の帯", cta=False, lines=[
    dict(id="d1", text="では、人はどこに集まったのか。", scene=MAP(ALL, step=3, tr="zoom")),
    dict(id="d2", text="答えは、1本の線の上です。", section=True, scene=MAP(ALL, LINE(RAIL, YEL, 8, id="rail_d"), step=3)),
    dict(id="d3", text="シベリア鉄道。モスクワから、日本海のウラジオストクまで。", scene=MAP(ALL, LINE(RAIL, YEL, 8, id="rail_d2"), PIN(MOSCOW, "モスクワ", id="p_mo"), PIN(VLADI, "ウラジオストク", id="p_vl"), step=3)),
    dict(id="d4", text="長さは、9,288km。東京から北極点までの、約1.5倍の距離です。", scene=CARD("9,288km", sub="シベリア鉄道（モスクワ〜ウラジオストク）", note="ロシア鉄道", step=3)),
    dict(id="d5", text="この線に沿って、大きな町が並んでいます。", scene=MAP(SOUTHB, LINE(RAIL, YEL, 8, id="rail_d3"), PIN(OMSK, "オムスク", id="p_om"), PIN(NOVOSIB, "ノボシビルスク", id="p_nv4"), PIN(KRASNO, "クラスノヤルスク", id="p_kr4"), PIN(IRKUTSK, "イルクーツク", id="p_ir"), step=3)),
    dict(id="d6", text="オムスク、ノボシビルスク、クラスノヤルスク、イルクーツク。"),
    dict(id="d7", text="シベリアの大きな町、上位15は、すべて北緯57度より南です。", scene=CARD("15のうち15", sub="大きな町のうち、北緯57度より南の町", note=MINE, view=SOUTHB, step=3, count=False)),
    dict(id="d8", text="南は、凍った地面が少なく、畑も作れます。", scene=LANDPOP),
    dict(id="d9", text="そこに道が通り、道に沿って町ができ、町がさらに人を呼んだのです。"),
    dict(id="d10", text="北には、この帯につながる道が、ほとんどありません。", section=True, scene=MAP(NORTHV, LINE(RAIL, YEL, 8, id="rail_d4"), step=3)),
    dict(id="d11", text="冬だけ、凍った川の上を走る「氷の道」を使う町もあります。"),
    dict(id="d12", text="人が住めないのではなく、物が運べない。それが北の、人の少なさです。", scene=MAP(ALL_T, LINE(RAIL, YEL, 8, id="rail_d5"), step=3)),
])

# ---- 第5章 北の町と答え ------------------------------------------------------------------------------------
_CV = [(ALL, (104.0, 60.0, 150.0, 15)), (WEST, (45.0, 61.0, 100.0, 15)), (ALL_T, (104.0, 62.0, 130.0, 30)),
       (SOUTHB, (95.0, 53.0, 82.0, 25)), (NORTHV, (95.0, 66.0, 74.0, 25))]
CARDS_N = lambda n: dict(shot="cards", items=ANSWERS, n=n, view=_CV[n - 1][0], view_to=_CV[n - 1][1], step=4)  # noqa: E731
P["ch5"] = dict(title="第5章 北の町と答え", cta=True, lines=[
    dict(id="e1", text="それでも、北にも町はあります。", scene=MAP(NORTHV, PIN(NORILSK, "ノリリスク", id="p_no"), PIN(SURGUT, "スルグト", id="p_su"), PIN(YAKUTSK, "ヤクーツク", id="p_ya"), step=4, tr="zoom")),
    dict(id="e2", text="北緯69度のノリリスク。約17万人の町です。", scene=MAP(NORV, PIN(NORILSK, "ノリリスク", id="p_no2"), step=4)),
    dict(id="e3", text="地下に、ニッケルなどの大きな鉱山があります。"),
    dict(id="e4", text="国のほかの地域とつながる道路も鉄道もなく、行き来は飛行機と、川と海の船です。", scene=CARD("道路も鉄道もない", sub="ノリリスクと国のほかの地域", view=NORV, step=4, count=False)),
    dict(id="e5", text="北緯61度のスルグトは、約40万人。石油の町です。", scene=BARS([("スルグト", 40, YEL), ("ノリリスク", 17, YEL)], title="北の町の人口（万人）", note=MINE, fmt="{}", step=4)),
    dict(id="e6", text="北に町ができるのは、そこに掘る物があるときです。"),
    dict(id="e7", text="ヤクーツクは、凍った地面の上の、大きな町です。", scene=MAP(YAKV, PIN(YAKUTSK, "ヤクーツク", id="p_ya2"), LINE(LENA, RIVER, 10, id="le_e"), step=4)),
    dict(id="e8", text="町の前を流れるレナ川には、橋がありません。夏は船、冬は凍った川の上を渡ります。"),
    dict(id="e9", text="まとめます。", section=True, scene=CARDS_N(1)),
    dict(id="e10", text="1つ目。シベリアは、日本の30倍の土地に、日本の5分の1の人。1km²あたり、約2人です。"),
    dict(id="e11", text="2つ目。寒さだけではない。同じ北緯60度に、100万人を超える町があります。", scene=CARDS_N(2)),
    dict(id="e12", text="3つ目。国土の約65%が永久凍土。川は、凍る北の海へ流れます。", scene=CARDS_N(3)),
    dict(id="e13", text="4つ目。人は、南の鉄道の帯に集まる。北緯55度より南に、町の人の61%です。", scene=CARDS_N(4)),
    dict(id="e14", text="5つ目。北の町は、資源か港があるところ。ノリリスクのニッケル、スルグトの石油です。", scene=CARDS_N(5)),
    dict(id="e15", text="住めないから、いないのではありません。運べないから、いないのです。", scene=MAP(ALL, LINE(RAIL, YEL, 8, id="rail_e"), SIB(alpha=0.15, id="sib_e"), step=4)),
    dict(id="e16", text="次に地図でロシアを見たら、南の端の、細い線をたどってみてください。", scene=MAP(ALL_T, LINE(RAIL, YEL, 8, id="rail_e2"), step=4)),
])

# ---- ショート ---------------------------------------------------------------------------------------------
P["s1"] = dict(title="日本の30倍の土地に、日本の5分の1の人しかいない", lines=[
    dict(id="k1", text="シベリアと極東。広さは、日本のおよそ30倍です。", scene=MAP(ALL_P, SIB(id="sib_k"), JAPAN())),
    dict(id="k2", text="ところが、住んでいる人は、約2,478万人。日本の5分の1ほどです。", scene=BARS([("シベリア＋極東", 2478, AREA), ("日本", 12400, RED)], title="人口（万人）", fmt="{:,}")),
    dict(id="k3", text="1km²あたり、約2人。日本の、150分の1です。", scene=CARD("約2人", sub="1km²あたりの人（日本は約330人）", view=ALL_P, count=False)),
    dict(id="k4", text="しかも、その人たちは、南の端に寄っています。", scene=MAP(ALL_P, LAT(55, "k", BLUE))),
    dict(id="k5", text="北緯55度より南の、土地の35%に、町の人の61%。地図のデータで、自分で数えました。", scene=LANDPOP),
    dict(id="k6", text="広い土地の大半は、ほとんど空っぽなのです。", scene=MAP(ALL_P, SIB(alpha=0.2, id="sib_k2"), tr="whip")),
])

P["s2"] = dict(title="北緯60度。ヘルシンキは111万人、シベリアは全部で102万人", lines=[
    dict(id="m1", text="シベリアは寒いから、人がいない。本当でしょうか。", scene=MAP(ALL_P, LAT(60, "m"))),
    dict(id="m2", text="フィンランドのヘルシンキは、北緯60.2度。そこに約111万人が住んでいます。", scene=MAP(WEST_P, LAT(60, "m2"), PIN(HELSINKI, "ヘルシンキ", id="p_hm"))),
    dict(id="m3", text="北緯60度より北のシベリアの町を、ぜんぶ足しても、約102万人。", scene=BARS([("ヘルシンキ1つ", 111, BLUE), ("北緯60度より北のシベリアの町ぜんぶ", 102, AREA)], title="町の人口（万人）", fmt="{}")),
    dict(id="m4", text="町1つに、かないません。"),
    dict(id="m5", text="違いは、海と道です。ヘルシンキは港の町。シベリアの北は、凍った地面と、凍る海です。", scene=MAP(NORTH_P, LAT(60, "m3"))),
    dict(id="m6", text="人がいないのは、緯度のせいだけではないのです。", scene=MAP(ALL_P, tr="whip")),
])

P["s3"] = dict(title="シベリアの大河は、なぜ役に立たないのか", lines=[
    dict(id="n1", text="シベリアには、世界でも指折りの大きな川があります。", scene=MAP(ALL_P, *RIVERS("n"))),
    dict(id="n2", text="オビ川、エニセイ川、レナ川。", scene=MAP(ALL_P, *RIVERS("n2"), LABEL((64.0, 62.0), "オビ川", 44, RIVER), LABEL((96.0, 68.5), "エニセイ川", 44, RIVER), LABEL((127.0, 58.0), "レナ川", 44, RIVER))),
    dict(id="n3", text="ところが、どれも南から北へ流れて、凍る北極海に出ます。"),
    dict(id="n4", text="外の世界への道に、なりにくいのです。", scene=CARD("凍る海へ", sub="シベリアの大きな川の行き先", view=ALL_P, count=False)),
    dict(id="n5", text="しかも春は、南の上流から先にとけて、凍ったままの下流で、水があふれます。", scene=MAP(NORTH_P, *RIVERS("n3"))),
    dict(id="n6", text="川の向きが、人を呼ばなかったのです。", scene=MAP(ALL_P, tr="whip")),
])

P["s4"] = dict(title="シベリアの大きな町は、1本の線の上に並ぶ", lines=[
    dict(id="q1", text="シベリアの大きな町を、地図に置いてみます。", scene=MAP(SOUTHB_P, PIN(OMSK, "オムスク", id="p_qo"), PIN(NOVOSIB, "ノボシビルスク", id="p_qn"), PIN(KRASNO, "クラスノヤルスク", id="p_qk"), PIN(IRKUTSK, "イルクーツク", id="p_qi"))),
    dict(id="q2", text="大きい順に15の町。すべて、北緯57度より南です。", scene=CARD("15のうち15", sub="北緯57度より南にある、大きな町", view=SOUTHB_P, count=False)),
    dict(id="q3", text="その町をつないでいるのが、シベリア鉄道です。", scene=MAP(SOUTHB_P, LINE(RAIL, YEL, 8, id="rail_q"))),
    dict(id="q4", text="モスクワから、ウラジオストクまで、9,288km。", scene=CARD("9,288km", sub="シベリア鉄道", view=ALL_P)),
    dict(id="q5", text="道があるから町ができ、町がまた人を呼ぶ。北には、その道がありません。", scene=MAP(ALL_P, LINE(RAIL, YEL, 8, id="rail_q2"))),
    dict(id="q6", text="シベリアの人は、1本の線の上に暮らしているのです。", scene=MAP(ALL_P, tr="whip")),
])

P["s5"] = dict(title="道路も鉄道もない、北緯69度の17万人の町", lines=[
    dict(id="r1", text="北緯69度。北極圏の中に、約17万人の町があります。", scene=MAP(NORTH_P, PIN(NORILSK, "ノリリスク", id="p_rn"))),
    dict(id="r2", text="ロシアのノリリスクです。", scene=MAP(NORV, PIN(NORILSK, "ノリリスク", id="p_rn2"))),
    dict(id="r3", text="この町には、国のほかの地域とつながる道路も、鉄道もありません。", scene=CARD("道路も鉄道もない", sub="ノリリスクと国のほかの地域", view=NORTH_P, count=False)),
    dict(id="r4", text="行き来は、飛行機と、川と海の船です。"),
    dict(id="r5", text="それでも人がいるのは、地下に、ニッケルなどの大きな鉱山があるからです。", scene=CARD("ニッケル", sub="ノリリスクの鉱山", view=NORTH_P, count=False)),
    dict(id="r6", text="シベリアの北に町ができるのは、掘る物があるところなのです。", scene=MAP(NORTH_P, tr="whip")),
])

# ---- 読み ------------------------------------------------------------------------------------------------
YOMI = [("人がいない", "ひとがいない"), ("約1,131万km²", "約千百三十一万平方キロメートル"), ("約2,478万人", "約二千四百七十八万人"), ("約102万人", "約百二万人"), ("約111万人", "約百十一万人"),
        ("約126万人", "約百二十六万人"), ("約32万人", "約三十二万人"), ("約17万人", "約十七万人"), ("約40万人", "約四十万人"), ("100万人", "百万人"),
        ("1km²", "一平方キロメートル"), ("約330人", "約三百三十人"), ("約2人", "約二人"), ("9,288km", "九千二百八十八キロ"),
        ("北緯60.2度", "北緯六十点二度"), ("北緯59.4度", "北緯五十九点四度"), ("北緯60度", "北緯六十度"), ("北緯55度", "北緯五十五度"),
        ("北緯57度", "北緯五十七度"), ("北緯69度", "北緯六十九度"), ("北緯61度", "北緯六十一度"), ("252か所", "二百五十二かしょ"),
        ("30.0倍", "三十点ゼロ倍"), ("30倍", "三十倍"), ("39%", "三十九パーセント"), ("35%", "三十五パーセント"), ("61%", "六十一パーセント"),
        ("約65%", "約六十五パーセント"), ("7%", "ななパーセント"), ("5分の1", "ごぶんのいち"), ("150分の1", "ひゃくごじゅうぶんのいち"),
        ("上位15", "じょういじゅうご"), ("15の町", "じゅうごのまち"), ("約1.5倍", "約一点五倍"),
        ("1つ目", "ひとつめ"), ("2つ目", "ふたつめ"), ("3つ目", "みっつめ"), ("4つ目", "よっつめ"), ("5つ目", "いつつめ"), ("1つ", "ひとつ"),
        ("1本", "いっぽん"), ("1年じゅう", "いちねんじゅう"),
        ("極東", "きょくとう"), ("永久凍土", "えいきゅうとうど"), ("北極海", "ホッキョクカイ"), ("北極点", "ホッキョクテン"), ("北極圏", "ホッキョクケン"),
        ("日本海", "にほんかい"), ("日本", "にほん"), ("緯度", "いど"), ("上流", "じょうりゅう"), ("下流", "かりゅう"), ("指折り", "ゆびおり"),
        ("ノリリスク", "ノリリスク"), ("スルグト", "スルグト"), ("ヤクーツク", "ヤクーツク"), ("ムルマンスク", "ムルマンスク")]


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
