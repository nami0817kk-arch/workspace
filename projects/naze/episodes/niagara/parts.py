"""ナイアガラの滝は後退している: 本編 5 章とショート 5 本の台本と画面。ch1〜ch5・s1〜s5 の ep.py がここから読む。
台本は scripts.md(2版)。数字は sim/calc.py(結果 sim/calc.txt)、測った値の出どころは research.md。
画面は 2〜3 行ごとに種類を変える(地図・滝の断面・川の縦断面・湖の出口・並べる・棒・絵)。場面の絵は make_illust.py(FLUX の無料枠)。"""
import math

from scene import FALLS_LL, RIVER

CREDIT = "地図: NASA Blue Marble・Terrain Tiles・Natural Earth、川の線 OpenStreetMap"
RED, YEL, WHITE, BLUE = (240, 90, 80), (255, 214, 64), (255, 255, 255), (120, 190, 255)
GREY = (170, 180, 200)

ERIE_OUT = (-78.905, 42.906)
ONT_MOUTH = (-79.064, 43.262)
QUEENSTON = (-79.0447, 43.1532)
INTAKE = (-79.04, 43.066)
PLANTS = (-79.05, 43.145)
WHIRL = (-79.069, 43.119)
ERIE_C, ONT_C = (-81.0, 42.15), (-77.9, 43.68)


def _near(ll):
    return min(range(len(RIVER)), key=lambda k: (RIVER[k][0] - ll[0]) ** 2 + (RIVER[k][1] - ll[1]) ** 2)


IF, IQ = _near(FALLS_LL), _near(QUEENSTON)
UP = RIVER[: IF + 1]                 # エリー湖の出口から滝まで
GORGE = RIVER[IF: IQ + 1]           # 滝から崖の口まで(峡谷 約11km)

WIDE = (-81.5, 44.0, 17, 30)
TWO = (-79.25, 42.95, 3.4, 40)
NIAG = (-79.02, 43.07, 1.5, 42)
OUTV = (-78.95, 42.93, 1.2, 40)


def MAP(view, *layers, view_to=None, step=None, tr=None, inset=False, fx=None):
    s = dict(shot="map", view=view, layers=list(layers))
    for k, v in (("view_to", view_to), ("step", step), ("tr", tr), ("fx", fx)):
        if v is not None:
            s[k] = v
    if inset:
        s["inset"] = True
    return s


def LABEL(at_ll, text, size=56, color=WHITE, at=0.0, on=None, count=False, id=None):
    d = dict(kind="label", at_ll=at_ll, text=text, size=size, color=color, id=id or f"lab_{text}", at=at, count=count)
    if on:
        d["on"] = on
    return d


def LINE(pts, color=YEL, width=6, id="line", grow=0.6, glow=True, at=0.0, on=None):
    d = dict(kind="line", pts=pts, color=color, width=width, id=id, grow=grow, glow=glow, at=at)
    if on:
        d["on"] = on
    return d


def PIN(at_ll, text, id=None, at=0.0, size=46):
    return dict(kind="pin", at_ll=at_ll, text=text, id=id or f"pin_{text}", at=at, size=size)


def CARD(big, sub=None, note=None, view=WIDE, step=None, count=True, tr=None):
    d = dict(shot="card", big=big, sub=sub, note=note, view=view, step=step, count=count)
    if tr:
        d["tr"] = tr
    return d


def ILLUST(name, title=None, sub=None, pan=(0.0, 0.0, 0.05, 0.03), step=None, tr=None, fx=None, grade=None):
    from scene import A
    d = dict(shot="illust", path=str(A / f"illust_{name}.jpg"), title=title, sub=sub, pan=pan, step=step)
    for k, v in (("tr", tr), ("fx", fx), ("grade", grade)):
        if v:
            d[k] = v
    return d


def SEC(mode="still", step=None, tr=None, **kw):
    d = dict(shot="section", mode=mode, step=step, **kw)
    if tr:
        d["tr"] = tr
    return d


def PROF(*marks, move=None, title=None, step=None, tr=None):
    d = dict(shot="profile", marks=list(marks), step=step, title=title)
    if move:
        d["move"] = move
    if tr:
        d["tr"] = tr
    return d


def WEIR(mode="still", title=None, step=None, tr=None):
    d = dict(shot="weir", mode=mode, title=title, step=step)
    if tr:
        d["tr"] = tr
    return d


def ICONS(kind, n, title=None, note=None, step=None, tr=None):
    d = dict(shot="icons", kind=kind, n=n, title=title, note=note, step=step)
    if tr:
        d["tr"] = tr
    return d


def BARS(items, title=None, note=None, fmt="{}", step=None, tr=None):
    d = dict(shot="bars", items=items, title=title, note=note, fmt=fmt, step=step)
    if tr:
        d["tr"] = tr
    return d


def PAIR(left, right, step=None, tr=None):
    d = dict(shot="pair", left=left, right=right, step=step)
    if tr:
        d["tr"] = tr
    return d


RIV = LINE(RIVER, YEL, 5, id="riv", grow=0.0)
LAKES = [LABEL((-79.75, 42.68), "エリー湖", 60, WHITE, id="l_erie"), LABEL((-78.55, 43.45), "オンタリオ湖", 60, WHITE, id="l_ont")]

ANSWERS = [("滝は、柔らかい岩をえぐられて下がる", "硬い岩が支えを失って割れ落ちる"),
           ("昔は発電所3基ぶんの力、1年に1.28m", "288万kW"),
           ("人が水を抜き、縁も伸びて、1年22cm", "縁1mあたりの水が6分の1"),
           ("湖の高さは出口の岩で決まる", "岩が削れる速さでしか下がれない"),
           ("届くのは16万年後。湖は一気には抜けない", "35km ÷ 22cm")]

P = {}

# ---- 第1章 動いている滝 ---------------------------------------------------------------------------
S_C1 = ILLUST("falls1", pan=(0.02, -0.02, -0.03, 0.02), step=0)
S_C2 = PROF("past", "gorge", move=(46.2, 35.1), title="1万2千年で、滝は11km下がった", step=0, tr="zoom")
S_C2["range"] = (22.0, 62.0)
S_C4 = ILLUST("gorge1", pan=(0.0, 0.03, 0.04, -0.02), step=0)
S_C5 = MAP(TWO, RIV, *[dict(l) for l in LAKES], LABEL((-79.75, 42.55), "173m", 52, YEL, on="99m", id="l_173"),
           LABEL((-78.55, 43.30), "74m", 52, YEL, on="99m", id="l_74"), step=0, view_to=(-79.25, 43.0, 3.2, 42))
S_C8 = ICONS("floor", 33, title="99m ＝ ビルの約33階", step=0)
S_C9 = PROF("51m", "99m", title="川に沿って縦に切ると", step=0)
S_C10 = CARD("2,832トン", sub="1秒に落ちる水（観光の季節の昼）", note="条約で決めた最低の量", view=NIAG, step=0)
S_C11 = ICONS("pool", 9, title="25mプール 9杯 ／ 1秒", note="プール1杯 300トンで計算", step=0)
S_C12 = MAP(NIAG, LINE(UP, YEL, 8, id="up", grow=0.9), PIN(FALLS_LL, "滝", id="p_f"), PIN(ERIE_OUT, "エリー湖の出口", id="p_e"),
            LABEL((-78.82, 43.0), "35km", 70, YEL, on="35km", count=True), step=0)
S_C14 = PROF("35km", "51m", title="エリー湖に届いたら、湖の水はどうなるのか", step=0, tr="flash")
S_C17 = CARD("一気には抜けない", sub="答え", note="湖の高さを決めているのは、出口の岩", view=TWO, step=0, count=False, tr="flash")
S_C19 = PROF("51m", "99m", "35km", title="落ちる水の力と、出ていく水の流れを計算する", step=0)

P["ch1"] = dict(title="第1章 動いている滝", cta=False, lines=[
    dict(id="c1", text="ナイアガラの滝は、同じ場所にありません。", scene=S_C1),
    dict(id="c2", text="1万2千年前、滝はいまより11km下流にありました。", scene=S_C2),
    dict(id="c3", text="崖を削りながら、少しずつ上流へ下がってきたのです。"),
    dict(id="c4", text="削ったあとが、この深い谷です。", scene=S_C4),
    dict(id="c5", text="滝の上には、エリー湖があります。", scene=S_C5),
    dict(id="c6", text="滝の下には、オンタリオ湖。"),
    dict(id="c7", text="2つの湖の水面は、高さが99m違います。"),
    dict(id="c8", text="ビルなら、およそ33階ぶんです。", scene=S_C8),
    dict(id="c9", text="その半分を、滝がひと息に落ちます。", scene=S_C9),
    dict(id="c10", text="落ちる水は、観光の季節の昼で、1秒に2,800トン以上。", scene=S_C10),
    dict(id="c11", text="25mのプールが、1秒に9杯空になる量です。", scene=S_C11),
    dict(id="c12", text="滝から川をさかのぼると、35kmでエリー湖です。", scene=S_C12),
    dict(id="c13", text="滝は、その湖へ向かって下がり続けています。"),
    dict(id="c14", text="では、滝がエリー湖まで届いたら。", style="question", sub="滝がエリー湖に届いたら\n【湖の水】はどうなるのか", scene=S_C14),
    dict(id="c15", text="99m下のオンタリオ湖へ、湖の水が流れ出してしまうのか。"),
    dict(id="c16", text="答えを先に言います。", section=True),
    dict(id="c17", text="湖の水は、一気には抜けません。", scene=S_C17),
    dict(id="c18", text="湖の高さを決めているのは、滝ではなく、湖の出口の岩だからです。"),
    dict(id="c19", text="落ちる水の力と、湖から出ていく水の流れを、計算して確かめます。", scene=S_C19),
])

# ---- 第2章 滝が崖を叩く力 ------------------------------------------------------------------------
S_D1 = SEC("still", step=1, tr="zoom", title="滝を横から切る")
S_D5 = SEC("undercut", step=1)
S_D7 = SEC("collapse", step=1)
S_D8 = SEC("retreat", step=1)
S_D9 = ILLUST("dry2", title="1969年", sub="アメリカ滝の水を止めた", step=1, grade="old", tr="whip")
S_D11 = CARD("力 ＝ 水の重さ × 重力 × 高さ", sub="落ちる水の力", note="P ＝ ρ g Q H", view=NIAG, step=1, count=False)
S_D13 = CARD("5,760トン", sub="1秒に流れていた水（人が抜く前）", view=NIAG, step=1)
S_D14 = CARD("288万kW", sub="5,760トン × 重力 × 51m", view=NIAG, step=1)
S_D15 = ICONS("plant", 3, title="大きな発電所 約3基ぶん", note="1基 100万kW とした", step=1)
S_D17 = SEC("retreat", step=1, title="1842〜1906年　1年に1.28m")
S_D19 = ILLUST("falls2", title="大きな滝 9割", sub="アメリカ滝は 1割", step=1)
S_D20 = CARD("12.3トン", sub="縁1mあたりに当たる水（1秒）", note="5,184トン ÷ 縁 420m", view=NIAG, step=1)

P["ch2"] = dict(title="第2章 滝が崖を叩く力", cta=False, lines=[
    dict(id="d1", text="まず、滝はなぜ下がるのか。", scene=S_D1),
    dict(id="d2", text="滝の縁は、厚さ24mほどの硬い岩の板です。"),
    dict(id="d3", text="その下にあるのは、柔らかい岩が18mほど。"),
    dict(id="d4", text="泥が固まった、薄くはがれやすい岩です。"),
    dict(id="d5", text="落ちた水は、滝つぼで渦を巻き、下の柔らかい岩をえぐります。", scene=S_D5),
    dict(id="d6", text="上の硬い岩は、支えを失って、ひさしのように突き出す。"),
    dict(id="d7", text="やがて重さに耐えきれず、割れて落ちます。", scene=S_D7),
    dict(id="d8", text="これをくり返して、滝はうしろへ下がります。", scene=S_D8),
    dict(id="d9", text="1969年には、この仕組みを調べるため、横のアメリカ滝の水を止めました。", scene=S_D9),
    dict(id="d10", text="乾いた岩に48本の穴を掘ると、硬い岩と柔らかい岩の2段の重なりが見えました。"),
    dict(id="d11", text="では、岩をえぐる力は、どれほどなのか。", section=True, scene=S_D11),
    dict(id="d12", text="水が落ちるときの力は、水の重さと落ちる高さのかけ算で出せます。"),
    dict(id="d13", text="人が水を抜く前、ナイアガラ川には1秒に5,760トンが流れていました。", scene=S_D13),
    dict(id="d14", text="それが51m落ちると、力は288万kW。", scene=S_D14),
    dict(id="d15", text="大きな発電所1基を100万kWとすると、およそ3基ぶんです。", scene=S_D15),
    dict(id="d16", text="発電所3基ぶんの力で、休まず崖を叩き続けていたのです。"),
    dict(id="d17", text="1842年から1906年の間、大きな滝は1年に1.28mずつ下がりました。", scene=S_D17),
    dict(id="d18", text="人の背丈より、少し短いくらいです。"),
    dict(id="d19", text="川の水の9割は、大きな滝のほうを落ちます。", scene=S_D19),
    dict(id="d20", text="このとき、縁の長さ1mあたりに当たる水は、1秒に12.3トン。", scene=S_D20),
    dict(id="d21", text="この比を物差しにすれば、ほかの時代の速さも出せます。"),
])

# ---- 第3章 人がかけたブレーキ -----------------------------------------------------------------------
S_E1 = ILLUST("intake1", step=2, tr="whip")
S_E3 = MAP(NIAG, RIV, LINE([INTAKE, (-79.07, 43.10), PLANTS], BLUE, 7, id="tunnel", grow=0.8),
           PIN(INTAKE, "取水口", id="p_in"), PIN(PLANTS, "発電所", id="p_pl", at=0.4), step=2)
S_E4 = CARD("約56%", sub="発電所へ回った川の水（2022年3〜8月）", view=NIAG, step=2)
S_E5 = dict(shot="timeline", items=[(1906, "取水が増える"), (1950, "ナイアガラ条約"), (1969, "アメリカ滝を止める"), (2022, "半分以上を発電へ")], cur=1, view=TWO, step=2)
S_E6 = BARS([("昼（観光の季節）", 2832, YEL), ("夜と冬", 1416, BLUE)], title="滝に流す水（1秒あたりのトン）", fmt="{:,}トン", step=2)
S_E8 = PAIR(("falls1", "昼"), ("night2", "夜　水は半分"), step=2)
S_E9 = ICONS("plant", 2, title="昼 142万kW ／ 夜 71万kW", note="落ちる水の力（1基 100万kW）", step=2)
S_E10 = ILLUST("falls2", title="縁 420m → 762m", sub="1842年 → 2000年", step=2, tr="zoom")
S_E14 = BARS([("1842〜1906年", 12.3, GREY), ("いま", 2.09, YEL)], title="縁1mあたりに当たる水（1秒あたりのトン）", fmt="{}トン", step=2)
S_E16 = CARD("1年に22cm", sub="1.28m × 2.09 ÷ 12.3", note="計算した、いまの後退の速さ", view=NIAG, step=2)
S_E18 = BARS([("昔", 128, GREY), ("縁が伸びただけ", 71, BLUE), ("水だけ抜いた", 39, BLUE), ("いま（両方）", 22, YEL)],
             title="1年に下がる長さ（計算）", fmt="{}cm", step=2)

P["ch3"] = dict(title="第3章 人がかけたブレーキ", cta=False, lines=[
    dict(id="e1", text="ところが今、滝に落ちる水は、ずっと少なくなっています。", scene=S_E1),
    dict(id="e2", text="人が、滝の上で水を抜き取っているからです。"),
    dict(id="e3", text="抜いた水は地下のトンネルで、下流の発電所へ送ります。", scene=S_E3),
    dict(id="e4", text="2022年の春から夏、川の水の半分以上が発電所へ回りました。", scene=S_E4),
    dict(id="e5", text="1950年、アメリカとカナダは約束を結びました。", scene=S_E5),
    dict(id="e6", text="観光の季節の昼は、滝に1秒2,832トン以上を流す。", scene=S_E6),
    dict(id="e7", text="夜と冬は、その半分でいい。"),
    dict(id="e8", text="夜のナイアガラの滝は、水が半分なのです。", scene=S_E8),
    dict(id="e9", text="力にすると、昼が142万kW、夜は71万kW。", scene=S_E9),
    dict(id="e10", text="もう1つ、変わったものがあります。", section=True, scene=S_E10),
    dict(id="e11", text="大きな滝は、馬のひづめの形に丸く広がりました。"),
    dict(id="e12", text="縁の長さは、1842年の420mから、2000年には762mへ。"),
    dict(id="e13", text="水は減り、縁は伸びた。"),
    dict(id="e14", text="いまの大きな滝で、縁1mあたりの水は、1秒に2.09トン。", scene=S_E14),
    dict(id="e15", text="昔の物差しの、6分の1です。"),
    dict(id="e16", text="だから後退の速さも、6分の1になる。", scene=S_E16),
    dict(id="e17", text="計算すると、1年に22cmです。"),
    dict(id="e18", text="水だけ抜いた場合は1年に39cm、縁が伸びただけなら71cm。", scene=S_E18),
    dict(id="e19", text="両方が重なって、ブレーキが強く効いています。"),
    dict(id="e20", text="実際に測った後退も、いまは1年に10cmほどで、昔よりずっと遅くなっています。"),
])

# ---- 第4章 湖の高さを決めるもの -----------------------------------------------------------------------
S_F1 = MAP(OUTV, RIV, PIN(ERIE_OUT, "エリー湖の出口", id="p_out"), LABEL((-79.05, 42.80), "エリー湖", 60, WHITE, id="l_e2"), step=3, tr="zoom", inset=True)
S_F3 = MAP(OUTV, RIV, PIN(ERIE_OUT, "エリー湖の出口", id="p_out"), LABEL((-78.72, 42.86), "幅 約600m", 60, YEL, on="600m"), step=3)
S_F4 = WEIR("still", title="出口を横から見る", step=3)
S_F7 = CARD("流れ ＝ 幅 × 高さ の 1.5乗", sub="ふちを越える水の量（せきの式）", note="Q ＝ b √g (2/3 h)^1.5", view=OUTV, step=3, count=False)
S_F9 = WEIR("still", title="1秒に5,760トンを流すと", step=3)
S_F10 = BARS([("いまの流れ", 3.2, YEL), ("流れが2倍", 5.0, BLUE)], title="湖の水面は、出口の岩より何m上か（計算）", fmt="{}m", step=3)
S_F12 = PROF("falls", "35km", title="滝は、崖をうしろへ削る", step=3, tr="whip")
S_F15 = WEIR("cut", title="仮に、出口の岩が一気に10m削れたら", step=3, tr="flash")
S_F18 = ICONS("lake", 38, title="エリー湖 ＝ 琵琶湖 38個ぶん", note="2万5,700平方km", step=3)
S_F19 = MAP(TWO, RIV, *[dict(l) for l in LAKES], step=3, view_to=(-79.6, 42.75, 4.2, 40))

P["ch4"] = dict(title="第4章 湖の高さを決めるもの", cta=False, lines=[
    dict(id="f1", text="では、滝がエリー湖まで届いたら。", scene=S_F1),
    dict(id="f2", text="湖の水は、どこから出ていくのでしょう。"),
    dict(id="f3", text="出口は、幅600mほどの、川の入口です。", scene=S_F3),
    dict(id="f4", text="その川底には、岩があります。", scene=S_F4),
    dict(id="f5", text="湖の水は、この岩を越えた分しか、出ていけません。"),
    dict(id="f6", text="お風呂のふちを越えてあふれる水と、同じです。"),
    dict(id="f7", text="ふちを越える水の量は、ふちの幅と、水がふちより何m上にあるかで決まります。", scene=S_F7),
    dict(id="f8", text="1秒に5,760トンを流すには、湖の水面が岩より何m上にあればいいか。", scene=S_F9),
    dict(id="f9", text="計算すると、3.2mです。"),
    dict(id="f10", text="湖に入る水が2倍に増えても、5.0m。", scene=S_F10),
    dict(id="f11", text="エリー湖の高さは、出口の岩の高さで、ほとんど決まっているのです。"),
    dict(id="f12", text="普通は、滝が来れば、湖の水がそこから落ちていくと思うはずです。", scene=S_F12),
    dict(id="f13", text="ところが、滝は崖をうしろへ削るもの。湖の出口の岩を、下へ掘るわけではありません。"),
    dict(id="f14", text="湖が下がるのは、出口の岩そのものが低くなったときだけです。"),
    dict(id="f15", text="仮に、出口の岩が一気に10m削れたとします。", section=True, scene=S_F15),
    dict(id="f16", text="出ていく水は、いまの8倍。"),
    dict(id="f17", text="それでも、湖が5m下がるには52日かかります。"),
    dict(id="f18", text="湖の広さが、2万5,700平方km。琵琶湖の38個ぶんもあるからです。", scene=S_F18),
    dict(id="f19", text="しかも本物の岩は、一気には削れません。", scene=S_F19),
    dict(id="f20", text="湖は、岩が削れるのと同じ、ゆっくりした速さでしか下がれないのです。"),
])

# ---- 第5章 届くのは、いつ。そして答え ------------------------------------------------------------------
S_G1 = MAP(NIAG, LINE(UP, YEL, 8, id="up", grow=0.9), PIN(FALLS_LL, "滝", id="p_f"), PIN(ERIE_OUT, "エリー湖の出口", id="p_e"),
           LABEL((-78.82, 43.0), "35km", 70, YEL), step=4, tr="zoom")
S_G2 = CARD("35km ÷ 22cm", sub="いまの速さで割る", view=NIAG, step=4, count=False)
S_G3 = CARD("16万年", sub="滝がエリー湖に届くまで", note="峡谷を削った1万2千年の13倍", view=TWO, step=4)
S_G5 = BARS([("いまの水で", 16.2, YEL), ("水を抜かなかったら", 5.0, BLUE)], title="エリー湖に届くまで（計算）", fmt="{}万年", step=4)
S_G8 = dict(shot="cards", items=ANSWERS, n=1, view=TWO, step=4, tr="flash")


def CARDS_N(n):
    return dict(shot="cards", items=ANSWERS, n=n, view=TWO, step=4)


S_G14 = MAP(WIDE, RIV, *[dict(l) for l in LAKES], step=4, view_to=(-80.5, 43.6, 12, 32))
S_G15 = PAIR(("falls1", "昼"), ("night2", "夜　水は半分"), step=4)

P["ch5"] = dict(title="第5章 届くのは、いつ。そして答え", lines=[
    dict(id="g1", text="最後に、滝がエリー湖に届くのは、いつなのか。", scene=S_G1),
    dict(id="g2", text="35kmを、いまの1年22cmで割ります。", scene=S_G2),
    dict(id="g3", text="およそ16万年です。", scene=S_G3),
    dict(id="g4", text="峡谷の11kmを削った1万2千年の、13倍です。"),
    dict(id="g5", text="もし人が水を抜かなかったら、1年71cmで、5万年。", scene=S_G5),
    dict(id="g6", text="古い資料に「5万年ほど」とあるのは、この、水を抜かない速さの数字です。"),
    dict(id="g7", text="人のブレーキが、届く日を3倍以上先にのばしました。"),
    dict(id="g8", text="まとめます。", section=True, scene=S_G8),
    dict(id="g9", text="1つ目。滝は、柔らかい岩をえぐられて、うしろへ下がる。"),
    dict(id="g10", text="2つ目。昔は発電所3基ぶんの力で叩き、1年に1.28m下がっていた。", scene=CARDS_N(2)),
    dict(id="g11", text="3つ目。人が水を抜き、縁も伸びて、いまは計算で1年22cm。", scene=CARDS_N(3)),
    dict(id="g12", text="4つ目。エリー湖の高さは出口の岩で決まり、岩が削れる速さでしか下がれない。", scene=CARDS_N(4)),
    dict(id="g13", text="5つ目。届くのは16万年後。そのときも、湖の水は一気には抜けない。", scene=CARDS_N(5)),
    dict(id="g14", text="ナイアガラの滝は、人にブレーキをかけられた滝なのです。", scene=S_G14),
    dict(id="g15", text="次にナイアガラの滝の写真を見たら、昼か夜かを見てください。", scene=S_G15),
    dict(id="g16", text="夜の写真なら、そこを落ちる水は、昼の半分です。"),
])

# ---- ショート ---------------------------------------------------------------------------------------
NIAG_P = (-79.02, 43.09, 0.9, 40)
TWO_P = (-79.2, 42.98, 2.2, 40)

P["s1"] = dict(title="ナイアガラの滝は、1万2千年で11km動いた", lines=[
    dict(id="a1", text="ナイアガラの滝は、同じ場所にありません。", scene=ILLUST("falls1", pan=(0.0, 0.0, 0.08, 0.0))),
    dict(id="a2", text="1万2千年前、滝はいまより11km下流にありました。",
         scene=MAP(NIAG_P, RIV, LINE(GORGE, RED, 9, id="gorge", grow=0.9), PIN(FALLS_LL, "いまの滝", id="p_now"),
                   PIN(QUEENSTON, "1万2千年前", id="p_past", at=0.3), LABEL((-78.97, 43.12), "11km", 80, RED, on="11km", count=True), tr="zoom")),
    dict(id="a3", text="いまの滝から下流の崖まで、ずっと深い谷が続いています。", scene=ILLUST("gorge2", pan=(0.0, 0.0, 0.0, 0.06))),
    dict(id="a4", text="この谷は、滝が自分で削ったあとです。"),
    dict(id="a5", text="滝の縁が崩れるたびに、滝は少しずつ上流へ下がりました。", scene=SEC("retreat")),
    dict(id="a6", text="11kmを1万2千年なら、ならして1年に88cm。", scene=CARD("1年に88cm", sub="11km ÷ 1万2,500年", view=NIAG_P)),
    dict(id="a7", text="その先、川をさかのぼると、35kmでエリー湖です。",
         scene=MAP(NIAG_P, LINE(UP, YEL, 8, id="up", grow=0.9), PIN(FALLS_LL, "滝", id="p_f"), PIN(ERIE_OUT, "エリー湖", id="p_e"),
                   LABEL((-78.88, 43.0), "35km", 80, YEL, on="35km", count=True), view_to=(-79.0, 43.0, 0.9, 40))),
    dict(id="a8", text="滝は、湖へ向かって下がり続けています。"),
    dict(id="a9", text="ただ、いまの滝は、昔よりずっと遅くなりました。", scene=ILLUST("intake2")),
    dict(id="a10", text="人が、滝の水を半分以上抜き取っているからです。"),
])

P["s2"] = dict(title="ナイアガラの滝は、発電所3基ぶんの力で崖を叩く", lines=[
    dict(id="b1", text="ナイアガラの滝は、発電所3基ぶんの力で、崖を叩いています。", scene=ILLUST("falls2", pan=(0.0, 0.0, 0.06, 0.02))),
    dict(id="b2", text="水が落ちる力は、水の重さと、落ちる高さのかけ算です。", scene=CARD("重さ × 重力 × 高さ", sub="落ちる水の力", view=NIAG_P, count=False)),
    dict(id="b3", text="人が水を抜く前、川には1秒に5,760トンが流れていました。", scene=CARD("5,760トン", sub="1秒に流れていた水", view=NIAG_P)),
    dict(id="b4", text="それが51m落ちると、288万kW。", scene=CARD("288万kW", sub="5,760トン × 重力 × 51m", view=NIAG_P)),
    dict(id="b5", text="大きな発電所1基を100万kWとすると、3基ぶんです。", scene=ICONS("plant", 3, title="発電所 約3基ぶん", note="1基 100万kW とした")),
    dict(id="b6", text="この力が、滝つぼで渦を巻き、下の柔らかい岩をえぐります。", scene=SEC("undercut")),
    dict(id="b7", text="上の硬い岩は、支えを失って割れ落ちる。", scene=SEC("collapse")),
    dict(id="b8", text="1842年から1906年まで、大きな滝は1年に1.28mずつ下がりました。", scene=SEC("retreat", title="1年に1.28m")),
    dict(id="b9", text="人の背丈より、少し短いくらいです。"),
    dict(id="b10", text="それが毎年、崩れていたのです。"),
])

P["s3"] = dict(title="夜のナイアガラの滝は、水が半分", lines=[
    dict(id="h1", text="夜のナイアガラの滝は、水が半分です。", scene=PAIR(("falls1", "昼"), ("night2", "夜"))),
    dict(id="h2", text="1950年、アメリカとカナダが約束を結びました。", scene=CARD("1950年", sub="ナイアガラ条約", view=TWO_P, count=False)),
    dict(id="h3", text="観光の季節の昼は、滝に1秒2,832トン以上を流す。",
         scene=BARS([("昼", 2832, YEL), ("夜と冬", 1416, BLUE)], title="滝に流す水（1秒）", fmt="{:,}トン")),
    dict(id="h4", text="夜と冬は、その半分の1,416トンでいい。"),
    dict(id="h5", text="残りの水は、滝の上で抜き取って、発電所へ送ります。", scene=ILLUST("intake1")),
    dict(id="h6", text="一方で、大きな滝の縁は、420mから762mに伸びました。", scene=ILLUST("falls2", title="縁 420m → 762m")),
    dict(id="h7", text="縁1mあたりに当たる水は、昔の6分の1。",
         scene=BARS([("昔", 12.3, GREY), ("いま", 2.09, YEL)], title="縁1mあたりの水（1秒）", fmt="{}トン")),
    dict(id="h8", text="削る速さも6分の1になると計算すると、1年に1.28mが、22cmへ。", scene=CARD("1.28m → 22cm", sub="1年に下がる長さ（計算）", view=NIAG_P, count=False)),
    dict(id="h9", text="発電のための約束が、滝の寿命までのばしているのです。", scene=ILLUST("night1")),
])

P["s4"] = dict(title="エリー湖の高さを決めるのは、出口の岩", lines=[
    dict(id="k1", text="ナイアガラの滝がエリー湖に届いても、湖の水は一気には抜けません。",
         scene=MAP(TWO_P, RIV, LABEL((-79.5, 42.7), "エリー湖", 64, WHITE, id="l_e"), PIN(FALLS_LL, "滝", id="p_f"))),
    dict(id="k2", text="湖の高さを決めているのは、出口の岩だからです。", scene=WEIR("still")),
    dict(id="k3", text="湖の水は、出口の岩を越えた分しか出ていけない。"),
    dict(id="k4", text="お風呂のふちからあふれる水と、同じです。"),
    dict(id="k5", text="計算すると、湖の水面は、出口の岩より3.2m上にあるだけ。", scene=CARD("3.2m", sub="湖の水面と出口の岩の差（計算）", view=TWO_P)),
    dict(id="k6", text="滝は崖をうしろへ削るもので、出口の岩を下へ掘るわけではありません。", scene=SEC("retreat")),
    dict(id="k7", text="仮に出口の岩が一気に10m削れても、湖が5m下がるには52日。", scene=WEIR("cut", tr="flash")),
    dict(id="k8", text="湖が、琵琶湖の38個ぶんと広すぎるからです。", scene=ICONS("lake", 38, title="琵琶湖 38個ぶん")),
    dict(id="k9", text="湖は、岩が削れるゆっくりした速さでしか、下がれないのです。"),
])

P["s5"] = dict(title="滝がエリー湖に届くのは、16万年後", lines=[
    dict(id="m1", text="ナイアガラの滝が、上流のエリー湖に届くのは、16万年後です。", scene=CARD("16万年", sub="滝がエリー湖に届くまで", view=TWO_P)),
    dict(id="m2", text="滝から湖までは、川に沿って35km。",
         scene=MAP(NIAG_P, LINE(UP, YEL, 8, id="up", grow=0.9), PIN(FALLS_LL, "滝", id="p_f"), PIN(ERIE_OUT, "エリー湖", id="p_e"),
                   LABEL((-78.88, 43.0), "35km", 80, YEL, on="35km", count=True), view_to=(-79.0, 43.0, 0.9, 40))),
    dict(id="m3", text="昔の滝は、1年に1.28m下がっていました。", scene=SEC("retreat", title="1年に1.28m")),
    dict(id="m4", text="いまは人が水を半分以上抜き、滝の縁も伸びた。", scene=ILLUST("intake1")),
    dict(id="m5", text="縁1mあたりの水から計算すると、いまの速さは1年に22cm。", scene=CARD("1年に22cm", sub="いまの後退（計算）", view=NIAG_P)),
    dict(id="m6", text="35kmを22cmで割ると、16万年。", scene=CARD("35km ÷ 22cm", sub="≒ 16万年", view=NIAG_P, count=False)),
    dict(id="m7", text="水を抜かなければ、5万年でした。",
         scene=BARS([("いまの水", 16.2, YEL), ("抜かなかったら", 5.0, BLUE)], title="届くまで（計算）", fmt="{}万年")),
    dict(id="m8", text="人のブレーキが、届く日を3倍以上先にのばしたのです。"),
    dict(id="m9", text="そして届いても、湖の水は一気には抜けません。", scene=WEIR("still")),
    dict(id="m10", text="湖の高さは、出口の岩で決まっているからです。"),
])

# ---- 読み ------------------------------------------------------------------------------------------
YOMI = [("縁", "ふち"), ("エリー湖", "エリーこ"), ("空になる", "からになる"), ("99m下", "きゅうじゅうきゅうメートルした"),
        ("何m上", "なんメートルうえ"), ("3.2m上", "さんてんにメートルうえ"), ("288万kW", "にひゃくはちじゅうはちまんキロワット"), ("142万kW", "ひゃくよんじゅうにまんキロワット"), ("71万kW", "ななじゅういちまんキロワット"),
        ("100万kW", "ひゃくまんキロワット"), ("2万5,700平方km", "にまんごせんななひゃくへいほうキロメートル"), ("2.09トン", "にてんれいきゅうトン"),
        ("5.0m", "ごてんれいメートル"), ("1.28m", "いってんにーはちメートル"), ("12.3トン", "じゅうにてんさんトン"), ("3.2m", "さんてんにメートル")]


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
