"""豊予海峡(地理・型 G つながらない): 本編 5 章とショート 5 本の台本と画面。ch1〜ch5・s1〜s5 の ep.py がここから読む。
数字と出典は sim/facts.md(環境省・大分県・国土交通省九州地方整備局・国道九四フェリー)。海峡の最短の幅と断面は sim/measure.py(国土地理院の標高タイル)。
画面の作りは青ヶ島の回(episodes/aogashima/parts.py)を写した。2〜3 行ごとに種類を変える(立体の地図・海峡の断面・棒・数字)。"""
CREDIT = "地図: 国土地理院・NASA・Terrain Tiles"
RED, YEL, WHITE, BLUE = (240, 90, 80), (255, 214, 64), (255, 255, 255), (120, 190, 255)
GREY, GREEN, SAND = (170, 180, 200), (110, 200, 110), (226, 196, 140)

# 地点(経度, 緯度)。九州側・四国側の岬は標高データで測った最短の 2 点
SAGA, KYU_PT = (131.8682, 33.2510), (131.9035, 33.2675)
TIP, MISAKI = (132.0140, 33.3422), (132.0300, 33.3440)
MID = ((KYU_PT[0] + TIP[0]) / 2, (KYU_PT[1] + TIP[1]) / 2)
OITA, MATSU = (131.6060, 33.2382), (132.7657, 33.8392)

WEST = (132.2, 33.45, 3.4, 0)
STRAIT = (131.96, 33.30, 0.30, 0)
STRAIT_T = (131.96, 33.30, 0.26, 35)
NEAR_K = (131.905, 33.268, 0.09, 35)
NEAR_S = (132.01, 33.338, 0.09, 35)
WEST_P = (132.2, 33.45, 2.4, 0)
STRAIT_P = (131.96, 33.30, 0.20, 0)
NEAR_KP = (131.905, 33.268, 0.06, 35)

# 断面の線: 九州の佐賀関半島 → 四国の佐田岬(幅 13km あまり)。右が四国
_V = (TIP[0] - KYU_PT[0], TIP[1] - KYU_PT[1])
S_A = (KYU_PT[0] - 0.05 * _V[0], KYU_PT[1] - 0.05 * _V[1])
S_B = (TIP[0] + 0.02 * _V[0], TIP[1] + 0.02 * _V[1])
S_KW = dict(zmax=300, zmin=-330, ends=[(0.03, "九州（佐賀関）"), (0.97, "四国（佐田岬）")])
S_LAB = [(0.12, 230, "九州側の半島", WHITE), (0.5, -120, "海峡", BLUE), (0.9, 150, "四国側の半島", WHITE)]


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


def CARD(big, sub=None, note=None, view=STRAIT, step=None, count=True, tr=None):
    d = dict(shot="card", big=big, sub=sub, note=note, view=view, step=step, count=count)
    if tr:
        d["tr"] = tr
    return d


def SLICE(step=None, tr=None, **kw):
    d = dict(shot="slice", a=S_A, b=S_B, step=step, title="豊予海峡を切る", labels=S_LAB, **S_KW)
    d.update(kw)
    if tr:
        d["tr"] = tr
    return d


def BARS(items, title=None, note=None, fmt="{}", step=None, tr=None):
    d = dict(shot="bars", items=items, title=title, note=note, fmt=fmt, step=step)
    if tr:
        d["tr"] = tr
    return d


ANSWERS = [("海峡は14km。フェリーで約70分", "1日16往復。国道197号の海の上の区間"),
           ("海の深さは、およそ180m", "岩は固く、活断層も見つかっていない"),
           ("トンネルは、海峡の幅の1.5倍の21.3km", "道路の坂は4%まで。深く潜るほど長くなる"),
           ("事業費は、1兆5,200億円", "海の下が9,300億円、陸の道が5,900億円"),
           ("作れるかは、50年かけて調べ済み", "残るのは、お金の出し方")]

P = {}

# ---- 第1章 近いのに船 -----------------------------------------------------------------------------------
P["ch1"] = dict(title="第1章 近いのに船", cta=False, lines=[
    dict(id="a1", text="九州と四国のあいだは、いちばん近いところで14km。", scene=MAP(STRAIT, PIN(SAGA, "佐賀関（大分）", id="p_sa"), PIN(TIP, "佐田岬（愛媛）", id="p_ti"),
         LINE([KYU_PT, TIP], id="r_14"), LABEL((131.945, 33.318), "14km", 64, YEL, on="14km"), step=0)),
    dict(id="a2", text="東京駅から羽田空港までより、少し近い距離です。", scene=CARD("約14km", sub="九州と四国のいちばん近いところ", note="環境省", step=0)),
    dict(id="a3", text="それなのに、橋もトンネルもありません。", scene=MAP(STRAIT_T, step=0, view_to=(131.96, 33.30, 0.34, 20))),
    dict(id="a4", text="渡る方法は、船だけです。", scene=MAP(STRAIT, LINE([SAGA, MISAKI], id="r_fe"), PIN(SAGA, "佐賀関", id="p_sa2"), PIN(MISAKI, "三崎", id="p_mi"), step=0)),
    dict(id="a5", text="国道九四フェリー。大分の佐賀関から、愛媛の三崎まで。約70分です。", scene=CARD("約70分", sub="佐賀関〜三崎のフェリー", note="国道九四フェリー", step=0)),
    dict(id="a6", text="1日に16往復します。", scene=CARD("16往復", sub="1日のフェリーの本数", note="国道九四フェリー", step=0)),
    dict(id="a7", text="じつは、この航路は、国道197号の一部です。", scene=MAP(WEST, LINE([OITA, SAGA, MISAKI, MATSU], id="r_197"), PIN(OITA, "大分", id="p_oi"), PIN(MATSU, "松山", id="p_ma"),
         LABEL((132.2, 33.05), "国道197号", 56, YEL, on="国道197号"), step=0, tr="zoom")),
    dict(id="a8", text="道路の地図では、海の上も、国道なのです。"),
    dict(id="a9", text="なぜ、14kmがつながらないのか。", style="question", sub="九州と四国の14km\n【橋もトンネルも】ない理由", scene=MAP(STRAIT, step=0)),
    dict(id="a10", text="答えを先に言います。", section=True),
    dict(id="a11", text="作れないからではありません。作れると、すでに調べられています。", scene=SLICE(step=0)),
    dict(id="a12", text="ないのは、深さに見合う長さと、お金です。", scene=MAP(STRAIT_T, step=0)),
    dict(id="a13", text="海の深さ、トンネルの長さ、事業費。数字で確かめます。", scene=MAP(STRAIT, step=0, view_to=(131.96, 33.30, 0.26, 20))),
    dict(id="a14", text="海の深さは、国土地理院などの標高データで自分で測り、事業費は大分県の資料を使います。"),
])

# ---- 第2章 海の底 ---------------------------------------------------------------------------------------
P["ch2"] = dict(title="第2章 海の底", cta=False, lines=[
    dict(id="b1", text="まず、海の深さを見ます。", scene=SLICE(step=1)),
    dict(id="b2", text="海峡の両側は、急に深くなっています。"),
    dict(id="b3", text="大分市の資料では、いちばん深いところで、水深約180m。", scene=CARD("約180m", sub="豊予海峡の最大水深", note="大分市", step=1)),
    dict(id="b4", text="海の深さのデータで、断面の線に沿って自分で測っても、およそ180mでした。", scene=SLICE(step=1, labels=S_LAB[:1] + [(0.56, -200, "約180m", YEL)] + S_LAB[2:])),
    dict(id="b5", text="東京タワーの大展望台、150mより深い海です。", scene=BARS([("豊予海峡の深さ", 180, BLUE), ("東京タワーの大展望台", 150, GREY)], title="深さと高さ（m）", fmt="{:,}", step=1)),
    dict(id="b6", text="船は、この海の上を走るだけです。"),
    dict(id="b7", text="道路を通すなら、この深さの下の岩を掘ることになります。", scene=SLICE(step=1, labels=S_LAB[:1] + [(0.5, -285, "海の下の岩", SAND)] + S_LAB[2:])),
    dict(id="b8", text="では、海の下の岩は、掘れるのか。", section=True, scene=MAP(STRAIT_T, step=1)),
    dict(id="b9", text="1974年から9年間、旧日本鉄道建設公団が、岩を調べました。", scene=CARD("9年間", sub="旧日本鉄道建設公団の調査（1974〜82年）", note="大分県", step=1)),
    dict(id="b10", text="岩は、三波川変成岩という、固い片岩が中心です。"),
    dict(id="b11", text="ところどころに、蛇紋岩や、くだけているかもしれない所もあります。", scene=SLICE(step=1)),
    dict(id="b12", text="それでも結論は、「青函トンネルの技術で、十分に作れる」でした。", scene=CARD("十分に可能", sub="旧鉄道建設公団の結論", note="大分県", step=1, count=False)),
    dict(id="b13", text="2025年には、産業技術総合研究所が、活断層を見直しました。"),
    dict(id="b14", text="トンネルの道すじに、活断層は、確認できませんでした。", scene=MAP(STRAIT_T, step=1)),
    dict(id="b15", text="海の底の岩は、作れない理由では、なかったのです。", scene=SLICE(step=1)),
])

# ---- 第3章 トンネルの長さ -------------------------------------------------------------------------------
P["ch3"] = dict(title="第3章 トンネルの長さ", cta=False, lines=[
    dict(id="c1", text="それなら、トンネルは、どのくらいの長さになるのか。", scene=MAP(STRAIT, step=2, tr="zoom")),
    dict(id="c2", text="海峡の幅は、14kmです。", scene=CARD("14km", sub="海峡の幅", note="環境省", step=2)),
    dict(id="c3", text="ところが、大分県が考えた道路トンネルは、21.3kmです。", scene=BARS([("海峡の幅", 14.0, GREY), ("道路トンネル", 21.3, YEL)], title="長さ（km）", note="大分県（2026年）", fmt="{}", step=2)),
    dict(id="c4", text="海峡の幅の、約1.5倍です。"),
    dict(id="c5", text="海を渡るだけなのに、なぜ、そんなに長いのか。", style="question", sub="14kmの海に\n【21.3kmのトンネル】", scene=MAP(STRAIT_T, step=2)),
    dict(id="c6", text="理由の1つは、道路の坂の決まりです。", section=True),
    dict(id="c7", text="この計画で、いちばん急な坂は、4%。100m進んで、4m下がる坂です。", scene=CARD("4%", sub="道路トンネルのいちばん急な坂", note="大分県", step=2, count=False)),
    dict(id="c8", text="100m下がるのに、2.5km進む必要があります。", scene=BARS([("100m下がる", 2.5, BLUE), ("200m下がる", 5.0, YEL)], title="坂で進む長さ（km）", note="自分で計算（4%の坂）", fmt="{}", step=2)),
    dict(id="c9", text="200m下がるなら、5kmです。"),
    dict(id="c10", text="海の底まで下りて、また上がる。", scene=SLICE(step=2)),
    dict(id="c11", text="その坂を、両側に作るので、道のりが伸びるのです。"),
    dict(id="c12", text="トンネルの長さは、海峡の幅だけでは決まりません。深さも効いてきます。", scene=MAP(STRAIT_T, step=2)),
    dict(id="c13", text="近いのに、長い。これが、14kmの海のむずかしさです。", scene=BARS([("海峡の幅", 14.0, GREY), ("道路トンネル", 21.3, YEL)], title="長さ（km）", note="大分県（2026年）", fmt="{}", step=2)),
])

# ---- 第4章 お金 -----------------------------------------------------------------------------------------
P["ch4"] = dict(title="第4章 お金", cta=False, lines=[
    dict(id="d1", text="次は、お金です。", scene=MAP(STRAIT, step=3, tr="zoom")),
    dict(id="d2", text="大分県は、2026年3月に、事業費を試算しました。"),
    dict(id="d3", text="トンネルと、両側の陸の道をあわせて、1兆5,200億円です。", scene=CARD("1兆5,200億円", sub="トンネルと陸の道の事業費", note="大分県（2026年3月）", step=3, count=False)),
    dict(id="d4", text="日本の人口、約1億2,000万人で割ると、1人あたり約1万3,000円です。", scene=CARD("約1万3,000円", sub="日本の人口で割った1人あたり", note="自分で計算", step=3, count=False)),
    dict(id="d5", text="内訳を見ます。", section=True, scene=BARS([("海の下のトンネル", 9300, YEL), ("陸の道", 5900, SAND)], title="事業費（億円）", note="大分県（2026年3月）", fmt="{:,}", step=3)),
    dict(id="d6", text="海の下が9,300億円。陸の道が5,900億円です。"),
    dict(id="d7", text="海の下には、3種類のトンネルを掘ります。", scene=BARS([("車が通る本坑", 6200, YEL), ("調べる先進導坑", 1600, BLUE), ("工事の作業坑", 1500, GREY)], title="海の下のトンネル（億円）", note="大分県", fmt="{:,}", step=3)),
    dict(id="d8", text="車が通る本坑が、6,200億円。", scene=CARD("6,200億円", sub="車が通る本坑", note="大分県", step=3, count=False)),
    dict(id="d9", text="地質を調べながら進む先進導坑が、1,600億円。", scene=SLICE(step=3, labels=S_LAB[:1] + [(0.5, -285, "先進導坑で岩を調べる", BLUE)] + S_LAB[2:])),
    dict(id="d10", text="工事のための作業坑が、1,500億円です。", scene=CARD("1,500億円", sub="工事のための作業坑", note="大分県", step=3, count=False)),
    dict(id="d11", text="意外なのは、陸の道です。", section=True, scene=MAP(NEAR_S, step=3)),
    dict(id="d12", text="愛媛県側だけで4,900億円。大分県側の、約5倍です。", scene=BARS([("大分県側", 1000, BLUE), ("愛媛県側", 4900, YEL)], title="陸の道（億円）", note="大分県", fmt="{:,}", step=3)),
    dict(id="d13", text="愛媛県側は、大洲・八幡浜自動車道の保内インターまで、道を新しく作る見積もりです。", scene=MAP(WEST, LINE([MISAKI, MATSU], id="r_ehime"), PIN(MATSU, "松山", id="p_ma3"), step=3, view_to=(132.3, 33.55, 2.2, 0))),
    dict(id="d14", text="しかも、通行料が入るのは、開通してからです。", scene=CARD("開通してから", sub="通行料が入るのは", note="大分県", step=3, count=False)),
    dict(id="d15", text="建設のお金を、どう集めるか。これが、いちばんの宿題です。", scene=MAP(STRAIT, step=3)),
])

# ---- 第5章 調べ尽くされている ----------------------------------------------------------------------------
_CV = [(STRAIT, (131.96, 33.30, 0.24, 20)), (NEAR_K, (131.92, 33.28, 0.07, 30)), (STRAIT_T, (131.96, 33.30, 0.20, 25)),
       (NEAR_S, (132.00, 33.33, 0.07, 30)), (STRAIT, (131.96, 33.30, 0.34, 10))]
CARDS_N = lambda n: dict(shot="cards", items=ANSWERS, n=n, view=_CV[n - 1][0], view_to=_CV[n - 1][1], step=4)  # noqa: E731
P["ch5"] = dict(title="第5章 調べ尽くされている", cta=True, lines=[
    dict(id="e1", text="では、なぜ今も、できていないのか。", scene=MAP(STRAIT_T, step=4, tr="zoom")),
    dict(id="e2", text="作れるかどうかは、50年かけて、調べられてきました。", scene=CARD("約50年", sub="1974年から続く調べ", note="大分県", step=4, count=False)),
    dict(id="e3", text="1974年から9年間、旧日本鉄道建設公団。結論は、「十分に可能」。"),
    dict(id="e4", text="2025年の見直しでも、トンネルの道すじに、活断層は確認できません。", scene=SLICE(step=4)),
    dict(id="e5", text="地質の調べは、今も使えるとされています。"),
    dict(id="e6", text="つまり、残っているのは、技術ではありません。", section=True, scene=MAP(STRAIT, step=4)),
    dict(id="e7", text="1兆5,200億円を、誰が、どう出すか。", scene=CARD("1兆5,200億円", sub="誰が、どう出すか", note="大分県", step=4, count=False)),
    dict(id="e8", text="大分県は、2026年7月に、民間のお金を入れる方法を考える研究会を始めました。"),
    dict(id="e9", text="2027年春に、国へ提言する予定です。", scene=MAP(WEST, LINE([OITA, SAGA, MISAKI, MATSU], id="r_197b"), PIN(OITA, "大分", id="p_oi2"), PIN(MATSU, "松山", id="p_ma2"), step=4)),
    dict(id="e10", text="まとめます。", section=True, scene=CARDS_N(1)),
    dict(id="e11", text="1つ目。海峡は14km。フェリーで約70分、1日16往復。国道197号の、海の上の区間です。"),
    dict(id="e12", text="2つ目。海の深さは、およそ180m。岩は固く、活断層も見つかっていません。", scene=CARDS_N(2)),
    dict(id="e13", text="3つ目。トンネルは、幅の1.5倍の21.3km。道路の坂は4%までなので、深く潜るほど長くなります。", scene=CARDS_N(3)),
    dict(id="e14", text="4つ目。事業費は1兆5,200億円。海の下が9,300億円、陸の道が5,900億円です。", scene=CARDS_N(4)),
    dict(id="e15", text="5つ目。作れるかどうかは、50年かけて調べ済み。残るのは、お金の出し方です。", scene=CARDS_N(5)),
    dict(id="e16", text="作れないのではなく、深さの分だけ長く、そして、高い。それが、14kmの答えでした。", scene=MAP(STRAIT, step=4, view_to=(131.96, 33.30, 0.26, 30))),
    dict(id="e17", text="次に四国か九州へ渡るときは、フェリーの窓から、海の下を想像してみてください。", scene=MAP(STRAIT_T, step=4)),
])

# ---- ショート ---------------------------------------------------------------------------------------------
P["s1"] = dict(title="九州と四国は14km。橋がないのは「作れない」からではない", lines=[
    dict(id="k1", text="九州と四国のあいだは、いちばん近いところで14km。", scene=MAP(STRAIT_P, PIN(SAGA, "佐賀関", id="p_ks"), PIN(TIP, "佐田岬", id="p_kt"), LINE([KYU_PT, TIP], id="r_k"))),
    dict(id="k2", text="東京駅から羽田空港までより、少し近い距離です。", scene=CARD("約14km", sub="九州と四国のいちばん近いところ", note="環境省", view=STRAIT_P)),
    dict(id="k3", text="それなのに、橋もトンネルもありません。渡る方法は、フェリーだけです。", scene=MAP(STRAIT_P, LINE([SAGA, MISAKI], id="r_kf"), PIN(SAGA, "佐賀関", id="p_ks2"), PIN(MISAKI, "三崎", id="p_km"))),
    dict(id="k4", text="約70分かけて、1日に16往復しています。", scene=CARD("約70分", sub="佐賀関〜三崎のフェリー", note="国道九四フェリー", view=STRAIT_P, count=False)),
    dict(id="k5", text="作れないのではありません。作れると、50年前から調べられています。", scene=SLICE()),
    dict(id="k6", text="足りないのは、お金。大分県の試算で、1兆5,200億円です。", scene=CARD("1兆5,200億円", sub="トンネルと陸の道の事業費", note="大分県（2026年3月）", view=STRAIT_P, count=False)),
])

P["s2"] = dict(title="14kmの海を渡るのに、トンネルは21.3km要る", lines=[
    dict(id="m1", text="九州と四国のあいだの海は、幅が14km。", scene=MAP(STRAIT_P, LINE([KYU_PT, TIP], id="r_m"), LABEL((131.94, 33.32), "14km", 60, YEL), PIN(SAGA, "佐賀関", id="p_ms"))),
    dict(id="m2", text="ところが、大分県が考えたトンネルは、21.3kmです。", scene=BARS([("海峡の幅", 14.0, GREY), ("道路トンネル", 21.3, YEL)], title="長さ（km）", fmt="{}")),
    dict(id="m3", text="海の深さは、約180m。", scene=SLICE(labels=S_LAB[:1] + [(0.56, -200, "約180m", YEL)] + S_LAB[2:])),
    dict(id="m4", text="道路の坂は、いちばん急で4%。100m進んで、4m下がる坂です。"),
    dict(id="m5", text="100m下がるのに、2.5km。200m下がるなら、5kmです。", scene=BARS([("100m下がる", 2.5, BLUE), ("200m下がる", 5.0, YEL)], title="坂で進む長さ（km）", fmt="{}")),
    dict(id="m6", text="トンネルは、幅だけでなく、深さでも長くなるのです。", scene=MAP(STRAIT_P, tr="whip")),
])

P["s3"] = dict(title="1兆5,200億円の中身。高いのは海の下だけではない", lines=[
    dict(id="n1", text="九州と四国を、トンネルでつなぐと、1兆5,200億円。", scene=CARD("1兆5,200億円", sub="トンネルと陸の道の事業費", note="大分県（2026年3月）", view=STRAIT_P, count=False)),
    dict(id="n2", text="海の下のトンネルが、9,300億円。陸の道が、5,900億円です。", scene=BARS([("海の下のトンネル", 9300, YEL), ("陸の道", 5900, SAND)], title="事業費（億円）", fmt="{:,}")),
    dict(id="n3", text="陸の道は、大分県側が1,000億円。愛媛県側が4,900億円です。", scene=BARS([("大分県側", 1000, BLUE), ("愛媛県側", 4900, YEL)], title="陸の道（億円）", fmt="{:,}")),
    dict(id="n4", text="愛媛県側は、大分県側の、約5倍です。", scene=MAP(NEAR_KP, tr="whip")),
    dict(id="n5", text="高いのは、海の下だけではありません。"),
    dict(id="n6", text="数字は、大分県が2026年3月に出した試算です。", scene=MAP(STRAIT_P)),
])

P["s4"] = dict(title="9年かけて調べて、結論は「十分に可能」", lines=[
    dict(id="q1", text="九州と四国を結ぶトンネルは、50年前から調べられています。", scene=MAP(STRAIT_P, PIN(SAGA, "佐賀関", id="p_qs"), PIN(TIP, "佐田岬", id="p_qt"))),
    dict(id="q2", text="1974年から9年間、旧日本鉄道建設公団が、岩を調べました。", scene=CARD("9年間", sub="旧日本鉄道建設公団の調査（1974〜82年）", note="大分県", view=STRAIT_P)),
    dict(id="q3", text="海の下の岩は、三波川変成岩という、固い岩が中心です。", scene=SLICE()),
    dict(id="q4", text="結論は、「青函トンネルの技術で、十分に作れる」。", scene=CARD("十分に可能", sub="旧鉄道建設公団の結論", note="大分県", view=STRAIT_P, count=False)),
    dict(id="q5", text="2025年の見直しでも、トンネルの道すじに、活断層は確認できません。"),
    dict(id="q6", text="作れるかどうかの調べは、もう済んでいるのです。", scene=MAP(STRAIT_P, tr="whip")),
])

P["s5"] = dict(title="国道なのに、船で70分。国道197号は海の上を通る", lines=[
    dict(id="r1", text="九州と四国をつなぐ国道が、海の上にあります。", scene=MAP(WEST_P, LINE([OITA, SAGA, MISAKI, MATSU], id="r_r"), PIN(OITA, "大分", id="p_ro"), PIN(MATSU, "松山", id="p_rm"))),
    dict(id="r2", text="国道197号。大分から、高知まで続く道です。", scene=CARD("国道197号", sub="大分〜高知", note="国土交通省", view=WEST_P, count=False)),
    dict(id="r3", text="その途中の、佐賀関から三崎までが、フェリーです。", scene=MAP(STRAIT_P, LINE([SAGA, MISAKI], id="r_rf"), PIN(SAGA, "佐賀関", id="p_rs"), PIN(MISAKI, "三崎", id="p_rt"), tr="zoom")),
    dict(id="r4", text="時間は約70分。1日に16往復です。", scene=CARD("約70分", sub="佐賀関〜三崎のフェリー", note="国道九四フェリー", view=STRAIT_P, count=False)),
    dict(id="r5", text="国道の途中に、船がある。それが、14kmの海です。", scene=MAP(STRAIT_P, tr="whip")),
])

# ---- 読み ------------------------------------------------------------------------------------------------
YOMI = [("1兆5,200億円", "イッチョウゴセンニヒャクオクエン"), ("9,300億円", "キュウセンサンビャクオクエン"), ("5,900億円", "ゴセンキュウヒャクオクエン"),
        ("6,200億円", "ロクセンニヒャクオクエン"), ("1,600億円", "センロッピャクオクエン"), ("1,500億円", "センゴヒャクオクエン"),
        ("4,900億円", "ヨンセンキュウヒャクオクエン"), ("1,000億円", "センオクエン"), ("約1万3,000円", "ヤクイチマンサンゼンエン"),
        ("1万3,000円", "イチマンサンゼンエン"), ("1億2,000万人", "イチオクニセンマンニン"), ("21.3km", "ニジュウイッテンサンキロ"),
        ("2.5km", "ニテンゴキロ"), ("14km", "ジュウヨンキロ"), ("国道197号", "コクドウヒャクキュウジュウナナゴウ"), ("197号", "ヒャクキュウジュウナナゴウ"),
        ("180m", "ヒャクハチジュウメートル"), ("150m", "ヒャクゴジュッメートル"), ("200m", "ニヒャクメートル"), ("100m", "ヒャクメートル"),
        ("4m", "ヨンメートル"), ("5km", "ゴキロ"), ("4%", "ヨンパーセント"), ("70分", "ナナジュップン"), ("16往復", "ジュウロクオウフク"),
        ("1974年", "センキュウヒャクナナジュウヨネン"), ("2025年", "ニセンニジュウゴネン"), ("2026年", "ニセンニジュウロクネン"), ("2027年", "ニセンニジュウナナネン"),
        ("9年間", "キュウネンカン"), ("50年", "ゴジュウネン"), ("1.5倍", "イッテンゴバイ"), ("5倍", "ゴバイ"), ("1つ目", "ひとつめ"), ("2つ目", "ふたつめ"),
        ("3つ目", "みっつめ"), ("4つ目", "よっつめ"), ("5つ目", "いつつめ"), ("1つ", "ひとつ"), ("3種類", "さんしゅるい"), ("1日", "いちにち"), ("1人", "ひとり"),
        ("豊予海峡", "ほうよかいきょう"), ("佐賀関", "さがのせき"), ("佐田岬", "さだみさき"), ("三崎", "みさき"), ("国道九四", "こくどうきゅうし"),
        ("三波川変成岩", "さんばがわへんせいがん"), ("蛇紋岩", "じゃもんがん"), ("片岩", "へんがん"), ("先進導坑", "せんしんどうこう"), ("作業坑", "さぎょうこう"),
        ("本坑", "ほんこう"), ("旧日本鉄道建設公団", "きゅうにほんてつどうけんせつこうだん"), ("活断層", "かつだんそう"), ("青函", "せいかん"),
        ("大洲・八幡浜自動車道", "オオズ・ヤワタハマジドウシャドウ"), ("保内", "ほない"), ("大展望台", "だいてんぼうだい"), ("日本", "にほん"), ("2026年3月", "ニセンニジュウロクネンさんがつ")]


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
