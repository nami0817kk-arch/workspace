"""深海魚: 本編 5 章とショート 5 本の台本と画面。ch1〜ch5・s1〜s5 の ep.py がここから読む。

出典と計算は research.md(TEOS-10 gsw 3.6.23・ボイルの法則・球の殻の応力・Yancey ほか 2014 PNAS ほか)。
台本の文言はユーザー確定版(scripts.md 2版)。足したのは読みの say= と字幕の改行・強調だけ。
"""

CREDIT = "水圧は海水の状態式 TEOS-10、空気はボイルの法則で計算"
CREDIT_V = "水圧は TEOS-10 で計算"          # 縦は幅が狭いので短く


# ---- 場面(アニメする場面は行ごとに新しい dict を作る。同じ場面を続けるときは still=True で止める) --------
def ST(to, frm=None, **kw):
    return dict(kind="strip", to=to, frm=to if frm is None else frm, **kw)


def PIST(n, vol, **kw):
    return dict(kind="piston", n=n, vol=vol, **kw)


def HULL(to, frm=None, **kw):
    return dict(kind="hull", to=to, frm=to if frm is None else frm, **kw)


def card(n, sub, base):
    """実験の札(右の枠に大きく「実験n」)。"""
    return dict(base, panel=dict(kind="big", text=f"実験{n}", sub=sub, size=170, at=0.05))


def big(text, sub, base, size=130, at=0.15, title=None):
    p = dict(kind="big", text=text, sub=sub, size=size, at=at)
    if title:
        p["title"] = title
    return dict(base, panel=p)


def FISH(note=None):
    return dict(kind="photo", name="fish", **({"note": note} if note else {}))


def SUB(note=None):
    return dict(kind="photo", name="sub", **({"note": note} if note else {}))


def DEEP():
    return dict(kind="deep")


def MAP():
    return dict(kind="map")


def LIST():
    return dict(kind="list")


def JAR(**kw):
    return dict(kind="jar", mode="water", **kw)


def JARVS(**kw):
    return dict(kind="jar", mode="vs", **kw)


def SEA(**kw):
    return dict(kind="sea", **kw)


def BAL(**kw):
    return dict(kind="balance", **kw)


def FSEC(**kw):
    return dict(kind="fishsec", **kw)


def OSM(**kw):
    return dict(kind="osm", **kw)


def PROT(**kw):
    return dict(kind="protein", **kw)


def BARS(**kw):
    return dict(kind="bars", **kw)


def SPH(mode, **kw):
    return dict(kind="spheres", mode=mode, **kw)


def BLAD(mode, **kw):
    return dict(kind="bladder", mode=mode, **kw)


def BOT(mode, **kw):
    return dict(kind="bottle", mode=mode, **kw)


def PRS(mode, **kw):
    return dict(kind="pressure", mode=mode, **kw)


def WT(kg, **kw):
    return dict(kind="weight", kg=kg, **kw)


# 読み(kana で全行を見て直したもの)。台本の字のまま読むと違う所だけを置き換えて say にする(ep_for)。
YOMI = [
    ("伊豆・小笠原海溝", "いず・おがさわらかいこう"),
    ("チャレンジャー海淵", "ちゃれんじゃーかいえん"),
    ("しんかい6500", "しんかいろくせんごひゃく"),
    ("1平方cm", "いちへいほうセンチ"),
    ("日本の南", "にほんのみなみ"),
    ("TEOS-10", "テオス・テン"),
    ("中と外", "なかとそと"),
    ("1万mの", "いちまんメートルの"),
    ("1万mへ", "いちまんメートルへ"),
]


def yomi(text: str) -> str:
    for a, b in YOMI:
        text = text.replace(a, b)
    return text


P = {}
P["ch1"] = dict(title="第1章 指先に、何kgかかるか", cta=False, lines=[
    dict(id="c1", text="2022年、水深8,336mを泳ぐ魚が撮影されました。", scene=FISH("水深 8,336m")),
    dict(id="c2", text="場所は日本の南、伊豆・小笠原海溝。", scene=MAP()),
    dict(id="c3", text="魚が見つかった、世界で一番深い記録です。",
         scene=big("世界記録", "東京海洋大学・西オーストラリア大学", MAP(), size=120, title="撮影した調査チーム（ほか）")),
    dict(id="c4", text="そこでは、指先1平方cmに約870kgの重さがかかっています。", scene=WT("870")),
    dict(id="c5", text="それでも、深海魚はつぶれない。なぜでしょう。", style="question", sub="それでも、深海魚は\n【つぶれない】。\nなぜでしょう", scene=DEEP()),
    dict(id="c6", text="では、実験していきます。", scene=LIST()),
    dict(id="c7", text="実験1。深さごとに、指先1平方cmにかかる重さを計算します。", section=True, scene=card(1, "深さごとの、指先の重さ", ST(0))),
    dict(id="c8", text="水深10mで約1kg。水1L分です。", scene=ST(10, 0, ratio="水1L分の重さ")),
    dict(id="c9", text="1,000mで約100kg。体重100kgの人が、指先に乗る重さです。", scene=ST(1000, 10, ratio="体重100kgの人が指先に乗る重さ")),
    dict(id="c10", text="「しんかい6500」が潜る6,500mで、約680kg。", scene=ST(6500, 1000, ratio="「しんかい6500」が潜る深さ")),
    dict(id="c11", text="世界一深いのは、マリアナ海溝のチャレンジャー海淵。10,935mです。", scene=ST(10935, 6500, ratio="チャレンジャー海淵")),
    dict(id="c12", text="指先1平方cmに、約1.1トン。1辺1mの水の箱より重い力です。", scene=WT("1100", cube=True)),
    dict(id="c13", text="地上の約1,100倍の力で、押されています。", scene=ST(10935, 10935, ratio="地上の約1,100倍")),
    dict(id="c14", text="魚が撮影された8,336mでも、地上の約840倍。その中を、魚は泳いでいました。", scene=ST(8336, 10935, rec=True, ratio="地上の約840倍")),
])
P["ch2"] = dict(title="第2章 空気の入ったものを、沈めてみる", cta=False, lines=[
    dict(id="c1", text="実験2。今度は、空気の入ったものを沈めます。", section=True, scene=card(2, "空気の入ったものを沈める", PIST(2, "空気の体積 1/2"))),
    dict(id="c2", text="空気は、押されるほど縮みます。押す力が2倍なら、体積は半分。", scene=PIST(2, "空気の体積 1/2")),
    dict(id="c3", text="水深10mで、押す力は地上の2倍。", scene=PIST(2, "空気の体積 1/2", note="水深10m　押す力は2倍")),
    dict(id="c4", text="息を止めて10m潜ると、肺の空気は半分になります。", scene=dict(kind="piston", lung=True)),
    dict(id="c5", text="1,000mまで沈めると、空気は100分の1。", scene=PIST(100, "空気の体積 1/100", note="水深1,000m")),
    dict(id="c6", text="500mLのペットボトルの空気を、8,336mまで沈めたら。", scene=BOT("sink")),
    dict(id="c7", text="空気は845分の1。わずか0.6mL。", scene=BOT("grain")),
    dict(id="c8", text="直径1cmほどの粒です。ペットボトルは、くしゃっとつぶれます。", scene=BOT("grain", still=True)),
    dict(id="c9", text="発泡スチロールのカップも、深海に沈めると、小さく縮んで戻ってきます。", scene=dict(kind="cup")),
    dict(id="c10", text="アメリカの海洋大気庁の調査船で、実際に試されています。中の細かい空気の粒が、押されて縮むからです。", scene=dict(kind="cup", still=True)),
    dict(id="c11", text="魚にも、空気の袋を持つものがいます。うきぶくろです。", scene=BLAD("normal")),
    dict(id="c12", text="深い所では、その空気も何百分の1に縮もうとします。", scene=BLAD("shrink")),
    dict(id="c13", text="記録の魚の仲間、深い海溝にすむクサウオのなかまには、うきぶくろがありません。", scene=FISH("クサウオのなかま　うきぶくろは無い")),
    dict(id="c14", text="つぶれるのは空気。空気が無ければ、つぶれるものがありません。", scene=BLAD("none")),
])
P["ch3"] = dict(title="第3章 水そのものを、1,000気圧で押す", cta=False, lines=[
    dict(id="c1", text="実験3。では、水そのものはどれだけ縮むのか。", section=True, scene=card(3, "水そのものを1,000気圧で押す", JAR(hold=0.0))),
    dict(id="c2", text="1,000気圧で押せば、普通は何でもぺちゃんこです。", scene=JAR(hold=0.0)),
    dict(id="c3", text="ところが水は、ほとんど縮みません。"),
    dict(id="c4", text="海水の国際的な計算式、TEOS-10で計算しました。"),
    dict(id="c5", text="1,000気圧で、縮むのは約4%。", scene=JAR()),
    dict(id="c6", text="1Lの水が約960mLになるだけ。減るのは40mLです。", scene=JAR(still=True)),
    dict(id="c7", text="空気なら、同じ力で約1,000分の1です。", scene=JARVS()),
    dict(id="c8", text="では、もし海の水が少しも縮まなかったら。", section=True, scene=SEA(hold=0.0)),
    dict(id="c9", text="海の平均の深さ、約3,700mで計算しました。"),
    dict(id="c10", text="海面は、約30m高くなります。10階建てのビルほど。", scene=SEA()),
    dict(id="c11", text="海の水は、少しだけ縮んで、今の高さに収まっています。", scene=SEA(still=True)),
    dict(id="c12", text="魚の体も、ほとんどが水。マダラの身で、約81%です。", scene=FSEC()),
    dict(id="c13", text="ペットボトルは、中が空気。外だけ、水圧が強くなります。", scene=PRS("bottle")),
    dict(id="c14", text="内と外の差で、つぶれます。", scene=PRS("bottle", still=True)),
    dict(id="c15", text="魚は、中も水。外の水圧は、体の中にも、そのまま伝わります。", scene=PRS("fish")),
    dict(id="c16", text="中と外から同じ強さで押し合うので、つぶす力は残りません。", scene=BAL()),
    dict(id="c17", text="深海魚は、力ずくで耐えているのではなく、水圧と釣り合っています。"),
])
P["ch4"] = dict(title="第4章 人が行くなら、殻は何cmか", cta=False, lines=[
    dict(id="c1", text="実験4。では、人が深海へ行くなら。", section=True, scene=card(4, "人が行くなら、殻は何cm", HULL(6500, same=True))),
    dict(id="c2", text="人は、空気を吸わないと生きられません。"),
    dict(id="c3", text="だから、空気の部屋ごと潜ります。その部屋が、潜水艇の殻です。", scene=SUB("空気の部屋ごと潜る")),
    dict(id="c4", text="「しんかい6500」の殻は、チタンの球。中の直径は2m、厚さは73.5mm。", scene=HULL(6500, same=True)),
    dict(id="c5", text="同じ余裕で、もっと深く潜るなら、殻の厚さは何cm要るでしょう。", scene=HULL(6500, same=True)),
    dict(id="c6", text="1,000mなら、約1cm。", scene=HULL(1000, 6500, same=True)),
    dict(id="c7", text="3,000mで、約3cm。", scene=HULL(3000, 1000, same=True)),
    dict(id="c8", text="6,500mで、実物と同じ7.35cm。", scene=HULL(6500, 3000, same=True)),
    dict(id="c9", text="そして10,935m。約13.5cm。重さは、ほぼ2倍になります。", scene=HULL(10935, 6500, same=True, weight=True)),
    dict(id="c10", text="実際に1万1千mまで潜れる潜水艇は、中の直径を1.5mに縮めて、厚さ9cmにしています。", scene=SPH("two")),
    dict(id="c11", text="部屋を小さくして、殻を厚くする。空気を守るには、それだけ要ります。", scene=SPH("two", still=True)),
    dict(id="c12", text="魚には、守る空気の部屋がありません。だから殻はいりません。", scene=SPH("fish")),
])
P["ch5"] = dict(title="第5章 それでも、魚が住めない深さ", lines=[
    dict(id="c1", text="では、魚はどこまでも深く住めるのか。", section=True, scene=DEEP()),
    dict(id="c2", text="魚が見つかっているのは、8,336mまで。", scene=ST(8336, 0, rec=True, readout=False)),
    dict(id="c3", text="その下、一番深い10,935mまでの約2,600mでは、魚はまだ見つかっていません。", scene=ST(10935, 8336, rec=True, gray=True, readout=False)),
    dict(id="c4", text="実験5。魚の体の中の液を、深さごとに比べます。", scene=card(5, "体の中の液の濃さを比べる", PROT(hold=0.0))),
    dict(id="c5", text="強い圧力は、たんぱく質の形をくずしやすいと考えられています。", scene=PROT()),
    dict(id="c6", text="深い所の魚ほど、TMAOという物質を多く持っています。", scene=PROT(tmao=True)),
    dict(id="c7", text="たんぱく質を守る働きがある、と考えられています。", scene=PROT(tmao=True, still=True)),
    dict(id="c8", text="浅い所の魚に比べ、水深7,000mの魚は約10倍。", scene=BARS()),
    dict(id="c9", text="ためるほど、体の中の液は濃くなります。", scene=OSM()),
    dict(id="c10", text="2014年の研究の計算では、深さ約8,200mで、海水と同じ濃さになります。", scene=OSM(still=True)),
    dict(id="c11", text="それより深いと、海の水が体へしみ込む向きに変わります。"),
    dict(id="c12", text="魚の体は、その逆向きに合わせられないのでは、と研究者は考えています。"),
    dict(id="c13", text="記録の8,336mは、その線とほぼ同じ深さです。", scene=OSM(still=True, rec=True)),
    dict(id="c14", text="つぶれる原因は、水圧の強さではありません。中と外の、圧力の差です。", section=True, scene=PRS("both")),
    dict(id="c15", text="深海魚は、体の中も水で、つぶれる空気も持たない。だから、その差が、ほとんど生まれません。", scene=PRS("fish")),
    dict(id="c16", text="住める深さを決めているのは、体の中の化学だと考えられています。", scene=OSM(still=True, rec=True)),
    dict(id="c17", text="冒頭の、8,336mの魚。指先に約870kgの重さの中を、殻もなしに泳いでいました。", scene=FISH("水深 8,336m　指先に約870kg")),
    dict(id="c18", text="プールで潜って耳がつんとしたら、それは、縮んでいく空気です。"),
])

P["s1"] = dict(title="指先に1.1トン", lines=[
    dict(id="c1", text="世界一深い海の水圧は、指先1平方cmに約1.1トン。", scene=WT("1100")),
    dict(id="c2", text="1辺1mの水の箱より重い力です。", scene=WT("1100", cube=True)),
    dict(id="c3", text="そんな所で、なぜ魚はつぶれないのか。", style="question", sub="そんな所で、\nなぜ魚は\n【つぶれない】のか", scene=DEEP()),
    dict(id="c4", text="答えは、体の中も水だから。外と同じ圧力になって、差が生まれません。", scene=PRS("fish")),
    dict(id="c5", text="つぶれるのは、水圧が強いからではなく、中と外の圧力に差があるとき。", scene=PRS("both")),
    dict(id="c6", text="ペットボトルは、中が空気。外の水圧との差で、つぶれます。", scene=PRS("bottle")),
    dict(id="c7", text="魚は、中も水で、つぶれる空気もない。だから、差がありません。", scene=PRS("fish")),
    dict(id="c8", text="水深10mで約1kg、1,000mで約100kg。2022年には、8,336mを泳ぐ魚が撮影されました。", scene=ST(8336, 10, rec=True, ratio="撮影された魚の深さ")),
    dict(id="c9", text="プールで潜って耳がつんとしたら、それは、縮んでいく空気です。", scene=ST(8336, 8336, rec=True, ratio="撮影された魚の深さ")),
])
P["s2"] = dict(title="ペットボトルを8,000mに", lines=[
    dict(id="c1", text="ペットボトルの空気を、水深8,336mへ。直径1cmほどの粒になります。", scene=BOT("grain")),
    dict(id="c2", text="500mLもあった空気が、なぜでしょう。", style="question", sub="500mLもあった空気が、\nなぜでしょう", scene=DEEP()),
    dict(id="c3", text="答えは、空気が、押された分だけ縮むから。", scene=PIST(2, "空気の体積 1/2")),
    dict(id="c4", text="押す力が2倍なら体積は半分。水深10mで2分の1。", scene=PIST(2, "空気の体積 1/2", still=True, note="水深10m")),
    dict(id="c5", text="1,000mで100分の1。", scene=PIST(100, "空気の体積 1/100", note="水深1,000m")),
    dict(id="c6", text="8,336mでは845分の1。わずか0.6mLです。", scene=BOT("sink")),
    dict(id="c7", text="深海で魚がつぶれないのは、この空気を、体に持っていないから。", scene=BLAD("none")),
    dict(id="c8", text="記録の深さにすむクサウオのなかまには、うきぶくろがありません。", scene=FISH("クサウオのなかま")),
    dict(id="c9", text="空のペットボトルの中の空気も、深海では直径1cmの粒になります。", scene=BOT("grain")),
])
P["s3"] = dict(title="水は4%しか縮まない", lines=[
    dict(id="c1", text="1,000気圧で押しても、水は約4%しか縮みません。", scene=JAR()),
    dict(id="c2", text="普通なら、ぺちゃんこになりそうなのに、なぜでしょう。", style="question", sub="普通なら、\nぺちゃんこに\nなりそうなのに、\nなぜでしょう", scene=DEEP()),
    dict(id="c3", text="答えは、水が縮みにくいから。しかも魚の体は、ほとんど水です。", scene=FSEC()),
    dict(id="c4", text="海水の計算式で確かめました。1Lの水が、約960mLになるだけ。", scene=JAR()),
    dict(id="c5", text="空気なら、同じ力で約1,000分の1です。", scene=JARVS()),
    dict(id="c6", text="もし海の水が少しも縮まなかったら、海面は約30m高い計算です。", scene=SEA()),
    dict(id="c7", text="魚の体も、ほとんどが水。マダラの身なら、約81%です。", scene=FSEC()),
    dict(id="c8", text="だから深海魚は、中と外が釣り合って、つぶれません。", scene=BAL()),
    dict(id="c9", text="コップの水は、1,000気圧で押しても4%しか縮みません。", scene=JAR(still=True)),
])
P["s4"] = dict(title="世界一深い海の殻は13cm", lines=[
    dict(id="c1", text="世界一深い海へ行く潜水艇。殻の厚さは、約13.5cm要る計算です。", scene=HULL(10935, 6500, same=True)),
    dict(id="c2", text="魚は殻なしで泳ぐのに、なぜ人は、そんなに厚い殻が要るのか。", style="question", sub="魚は殻なしで泳ぐのに、\nなぜ人は、\nそんなに厚い殻が\n【要る】のか", scene=DEEP()),
    dict(id="c3", text="答えは、中に、空気の部屋を持っていくから。", scene=SUB("空気の部屋ごと潜る")),
    dict(id="c4", text="「しんかい6500」の殻は、チタンの球。中の直径2m、厚さ73.5mm。6,500mまで潜れます。", scene=HULL(6500, same=True)),
    dict(id="c5", text="この殻と同じ余裕で計算すると、1,000mなら約1cm。3,000mで約3cm。", scene=HULL(3000, 1000, same=True)),
    dict(id="c6", text="10,935mでは、約13.5cm。重さは、ほぼ2倍です。", scene=HULL(10935, 3000, same=True, weight=True)),
    dict(id="c7", text="1万1千mまで潜れる潜水艇は、中の直径を1.5mに縮めて、厚さ9cm。", scene=SPH("two")),
    dict(id="c8", text="魚には、空気の部屋がない。だから殻はいりません。", scene=SPH("fish")),
])
P["s5"] = dict(title="魚が住めるのは8,200mまで？", lines=[
    dict(id="c1", text="魚が住めるのは、深さ約8,200mまで。そう計算した研究があります。", scene=ST(8200, 0, line=True, readout=False)),
    dict(id="c2", text="魚は水圧でつぶれないのに、なぜ限界があるのか。", style="question", sub="魚は水圧で\nつぶれないのに、\nなぜ【限界】が\nあるのか", scene=DEEP()),
    dict(id="c3", text="答えは、体の中の液の濃さにありそうです。", scene=OSM(hold=0.0)),
    dict(id="c4", text="深い所の魚ほど、TMAOという物質を多く持っています。たんぱく質を守る働きがある、と考えられています。", scene=PROT(tmao=True)),
    dict(id="c5", text="水深7,000mの魚では、浅い所の魚の約10倍。", scene=BARS()),
    dict(id="c6", text="ためるほど、体の液は濃くなります。約8,200mで、海水と同じ濃さになる計算です。", scene=OSM()),
    dict(id="c7", text="それより深いと、海の水が体へしみ込む向きに変わります。魚の体はそれに合わせられないのでは、と研究者は考えています。", scene=OSM(still=True)),
    dict(id="c8", text="実際、魚の最深記録は8,336m。その線とほぼ同じ深さです。", scene=OSM(still=True, rec=True)),
    dict(id="c9", text="その下、一番深い10,935mまでの約2,600mでは、魚はまだ見つかっていません。", scene=ST(10935, 8336, rec=True, gray=True, readout=False)),
])


def ep_for(name: str) -> dict:
    p = dict(P[name])
    lines = []
    for l in p["lines"]:
        l = dict(l)
        if "say" not in l and yomi(l["text"]) != l["text"]:
            l["say"] = yomi(l["text"])
        lines.append(l)
    p["lines"] = lines
    v = name.startswith("s")
    return dict(kind="sim", aspect="portrait" if v else "landscape", credit=CREDIT_V if v else CREDIT, **p)
