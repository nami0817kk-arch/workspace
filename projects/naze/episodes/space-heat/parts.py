"""宇宙はマイナス270℃なのに、なぜ冷えないのか: 本編 5 章とショート 5 本の台本と画面。ch1〜ch5・s1〜s5 の ep.py がここから読む。
数字は sim/calc.py(結果 sim/calc.txt)、測った値・定数の出どころは research.md と calc.py の冒頭。
画面は 2〜3 行ごとに種類を変える(地球儀・3つの道・空気・板・軌道・人・流れ・放熱板・宇宙服・並べる・棒・絵)。場面の絵は make_illust.py(FLUX の無料枠)。"""
CREDIT = "地球: NASA Blue Marble"
RED, YEL, WHITE, BLUE = (245, 90, 75), (255, 214, 64), (255, 255, 255), (110, 180, 255)
GREY = (170, 180, 200)


def G(center=(140, 20), to=None, r=0.42, dx=0.0, step=None, tr=None):
    d = dict(shot="globe", center=center, to=to or (center[0] + 25, center[1]), r=r, hl=None, dx=dx, step=step)
    if tr:
        d["tr"] = tr
    return d


def CARD(big, sub=None, note=None, step=None, count=True, tr=None):
    d = dict(shot="card", big=big, sub=sub, note=note, step=step, count=count)
    if tr:
        d["tr"] = tr
    return d


_DRAWN = dict(iss1=dict(shot="station"), iss2=dict(shot="station", center=(60, 20), to=(80, 15)),
              radiator1=dict(shot="station", hl="radiators"), radiator2=dict(shot="station", hl="radiators", center=(20, 30), to=(40, 25)),
              window1=dict(shot="station", center=(-40, 10), to=(-20, 5)), dark1=dict(shot="station", dark=True, center=(170, 0), to=(185, 0)),
              thermos1=dict(shot="flask"), thermos2=dict(shot="flask"), suit1=dict(shot="suit"), suit2=dict(shot="suit"))


def ILLUST(name, title=None, sub=None, pan=None, step=None, tr=None):
    """場面の絵の代わりに、コードで描く図(scene.py の station・flask・suit)を返す。FLUX の無料枠を使い切った日に作ったため。"""
    d = dict(_DRAWN[name], step=step)
    if title:
        d["title"] = title
    if tr:
        d["tr"] = tr
    return d


def S(shot, step=None, tr=None, **kw):
    d = dict(shot=shot, step=step, **kw)
    if tr:
        d["tr"] = tr
    return d


ANSWERS = [("空気は地上の1兆分の1", "触れて冷えることも、空気に運んでもらうこともできない"),
           ("残る道は光だけ", "日なたの黒い板は120℃、人は1時間に8℃"),
           ("水とアンモニアで集めて、放熱板から捨てる", "70kW を 475平方m で"),
           ("放熱板は白い", "黒なら日なたで62℃、熱を捨てられない"),
           ("宇宙服は、水を凍らせて蒸発させる", "8時間で 3.6kg、354W")]

P = {}

# ---- 第1章 熱がこもる宇宙ステーション -------------------------------------------------------------------
P["ch1"] = dict(title="第1章 熱がこもる宇宙ステーション", cta=False, lines=[
    dict(id="c1", text="宇宙は、マイナス270℃の世界です。", scene=G((150, 25), (175, 20), 0.40, step=0)),
    dict(id="c2", text="ところが、国際宇宙ステーションは、熱がたまって困っています。", scene=ILLUST("iss1", step=0)),
    dict(id="c3", text="中から捨てられる熱は、最大で70kW。", scene=CARD("70kW", sub="宇宙ステーションが捨てられる熱", note="アメリカ側の設計の上限", step=0)),
    dict(id="c4", text="人が1人100Wの熱を出すとすると、700人ぶんです。", scene=S("icons", kind="person", n=70, title="人 700人ぶん", note="1つの印で10人", step=0)),
    dict(id="c5", text="その熱を捨てるために、白くて大きな板を6枚も広げています。", scene=ILLUST("radiator1", step=0)),
    dict(id="c6", text="放熱板といって、1枚が長さ23m、幅3.4m。"),
    dict(id="c7", text="6枚を合わせると475平方m。テニスコートおよそ2面ぶんです。", scene=CARD("475平方m", sub="放熱板 6枚の面積", note="テニスコート 約1.8面", step=0)),
    dict(id="c8", text="マイナス270℃の宇宙に浮かんでいるのに、なぜわざわざ熱を捨てるのか。", style="question",
         sub="マイナス270℃の宇宙で\nなぜ【冷えない】のか", scene=G((160, 10), (180, 5), 0.46, step=0, tr="flash")),
    dict(id="c9", text="放っておけば、勝手に冷えそうなものです。"),
    dict(id="c10", text="答えを先に言います。", section=True),
    dict(id="c11", text="宇宙は、寒いのではありません。", scene=CARD("熱を渡す相手がいない", sub="答え", note="宇宙は、寒いのではない", count=False, step=0, tr="flash")),
    dict(id="c12", text="熱を渡す相手が、ほとんどいないのです。"),
    dict(id="c13", text="熱が逃げる道と、光だけで決まる温度を、計算して確かめます。", scene=S("ways", step=0, title="熱が逃げる道")),
])

# ---- 第2章 熱が逃げる3つの道 -------------------------------------------------------------------------
P["ch2"] = dict(title="第2章 熱が逃げる3つの道", cta=False, lines=[
    dict(id="d1", text="熱いお茶が冷めるとき、熱は3つの道で逃げていきます。", scene=S("ways", step=1, tr="zoom")),
    dict(id="d2", text="1つ目は、触れている物へ伝わる道。", scene=S("ways", hl=0, step=1)),
    dict(id="d3", text="2つ目は、まわりの空気が運び去る道。", scene=S("ways", hl=1, step=1)),
    dict(id="d4", text="3つ目は、光になって出ていく道です。", scene=S("ways", hl=2, step=1)),
    dict(id="d5", text="目には見えませんが、温かい物は、赤外線という光を出しています。"),
    dict(id="d6", text="では、宇宙ステーションのまわりはどうでしょう。", section=True, scene=G((135, 35), (160, 30), 0.50, dx=0.1, step=1)),
    dict(id="d7", text="飛んでいる高さは、およそ400km。"),
    dict(id="d8", text="そこにも空気はありますが、地上のおよそ1兆分の1しかありません。", scene=CARD("1兆分の1", sub="高さ400kmの空気の濃さ（地上と比べて）", step=1)),
    dict(id="d9", text="6畳の部屋なら、地上の空気は61kgあります。", scene=S("air", step=1, title="同じ6畳の部屋の空気")),
    dict(id="d10", text="同じ部屋を400kmの高さに持っていくと、空気は1グラムの2千万分の1です。"),
    dict(id="d11", text="これでは、空気が熱を運び去ることはできません。", scene=S("ways", cross=[1], step=1)),
    dict(id="d12", text="しかも宇宙ステーションは、何にも触れずに浮かんでいます。", scene=S("ways", cross=[0, 1], step=1)),
    dict(id="d13", text="残る道は、光だけです。"),
    dict(id="d14", text="魔法瓶が冷めにくいのは、壁と壁のすき間を真空にしてあるからです。", scene=ILLUST("thermos1", step=1, tr="whip")),
    dict(id="d15", text="宇宙は、とても大きな魔法瓶の中と同じなのです。"),
])

# ---- 第3章 光だけで決まる温度 -------------------------------------------------------------------------
P["ch3"] = dict(title="第3章 光だけで決まる温度", cta=False, lines=[
    dict(id="e1", text="光だけで熱をやり取りすると、物は何℃になるのか。", scene=S("plate", color="black", sides=1, temp=None, step=2, title="光だけで決まる温度")),
    dict(id="e2", text="地球のあたりで、太陽の光は1平方mあたり1,361W。", scene=CARD("1,361W", sub="太陽の光（1平方mあたり）", note="地球のあたりで", step=2)),
    dict(id="e3", text="この光を、黒い板に真正面から当てます。", scene=S("plate", color="black", sides=1, temp=120, step=2, title="黒い板に、太陽の光を当てる")),
    dict(id="e4", text="板は温まるほど、強い赤外線を出すようになります。"),
    dict(id="e5", text="入る光と出る光が釣り合う温度を計算すると、120℃。"),
    dict(id="e6", text="JAXAが示している日なたの温度、120℃と同じです。", scene=CARD("120℃", sub="宇宙の日なた（JAXA）", note="計算した黒い板と同じ", step=2)),
    dict(id="e7", text="ところが日陰に入ると、入ってくる光がなくなります。", scene=S("orbit", step=2, title="90分で地球を1周")),
    dict(id="e8", text="板は光を出し続けて、どんどん冷えていく。"),
    dict(id="e9", text="宇宙ステーションは、90分で地球を1周します。"),
    dict(id="e10", text="1日に16回、日なたと日陰を行き来しているのです。", scene=CARD("1日16回", sub="日なたと日陰を行き来する", note="90分で1周", step=2)),
    dict(id="e11", text="では、人が宇宙にそのまま出たら、一瞬で凍ってしまうのか。", section=True, scene=S("body", mode="none", step=2, title="人が宇宙に出たら")),
    dict(id="e12", text="皮膚の温度を33℃として、人が出す赤外線を計算すると、641W。", scene=S("body", mode="watts", step=2)),
    dict(id="e13", text="体が作る熱は100Wほどなので、差し引き541Wずつ失います。"),
    dict(id="e14", text="それでも、体全体で下がるのは、1時間に8℃です。", scene=S("body", mode="cool", step=2, title="体全体の温度（計算）")),
    dict(id="e15", text="一瞬で凍ることはありません。"),
    dict(id="e16", text="1966年、真空の部屋で、宇宙服の空気が抜ける事故がありました。", scene=CARD("1966年", sub="真空の部屋で、宇宙服の空気が抜けた", note="0.5秒で、地上の約150分の1の気圧に", count=False, step=2)),
    dict(id="e17", text="中の人が倒れたのは12〜15秒後。原因は寒さではなく、酸素が足りなくなったことでした。", scene=CARD("12〜15秒", sub="倒れるまで", note="原因は酸素が足りないこと", count=False, step=2)),
    dict(id="e18", text="宇宙は、人を一瞬で凍らせるほど、冷たくはないのです。", scene=ILLUST("suit2", step=2)),
])

# ---- 第4章 宇宙ステーションの熱の捨て方 -------------------------------------------------------------------
P["ch4"] = dict(title="第4章 宇宙ステーションの熱の捨て方", cta=False, lines=[
    dict(id="f1", text="では、宇宙ステーションは、どうやって熱を捨てているのか。", scene=ILLUST("window1", step=3, tr="zoom")),
    dict(id="f2", text="中では、人と機械が、休まず熱を出しています。"),
    dict(id="f3", text="その熱を、まず水で集めます。", scene=S("loop", step=3, title="熱を運ぶ流れ")),
    dict(id="f4", text="水は、外を回るアンモニアに熱を渡し、アンモニアが放熱板まで運びます。"),
    dict(id="f5", text="アンモニアは毒なので、部屋の外だけを回ります。"),
    dict(id="f6", text="外でアンモニアを使う理由は、凍りにくいこと。", scene=S("bars", items=[("水", 0, BLUE), ("アンモニア", -77, YEL)], title="凍る温度", fmt="{}℃", step=3)),
    dict(id="f7", text="水は0℃で凍りますが、アンモニアはマイナス77℃まで凍りません。"),
    dict(id="f8", text="では、熱を捨てるのに、どれだけ広い板が要るのか。", section=True, scene=S("plate", color="white", sides=1, temp=None, step=3, title="放熱板 1平方m が出す光")),
    dict(id="f9", text="2.8℃の板1平方mが出す赤外線を計算すると、296W。", scene=CARD("296W", sub="2.8℃の板 1平方mが出す赤外線", step=3)),
    dict(id="f10", text="下の地球からも赤外線が届くので、差し引き234W。", scene=CARD("234W", sub="地球から届く赤外線を引くと", note="296W − 62W", step=3)),
    dict(id="f11", text="70kWを捨てるには、片面だけで300平方m要ります。", scene=S("bars", items=[("計算（片面）", 300, BLUE), ("実物 6枚", 475, YEL)], title="70kWを捨てる板の広さ", fmt="{}平方m", step=3)),
    dict(id="f12", text="実物の放熱板は、6枚で475平方m。計算の1.6倍あります。"),
    dict(id="f13", text="ここで大事なのが、板の色です。", section=True, scene=S("pairp", step=3, title="日なたに置いた板の温度（計算）", tr="flash")),
    dict(id="f14", text="もし放熱板が黒かったら、日なたでは62℃になります。"),
    dict(id="f15", text="中から運んできた2.8℃のアンモニアより熱く、これでは熱を捨てられません。"),
    dict(id="f16", text="実物の放熱板には、白い塗料が塗ってあります。", scene=ILLUST("radiator2", step=3)),
    dict(id="f17", text="この塗料は、太陽の光を86%はね返しながら、赤外線はしっかり出します。", scene=S("plate", color="white", sides=2, temp=-65, step=3, title="白い塗料の板（両面から光を出す）")),
    dict(id="f18", text="両面から光を出す白い板なら、日なたでもマイナス65℃まで下がる計算です。"),
    dict(id="f19", text="さらに放熱板は、首を振るように回って、向きを変え続けています。", scene=S("radiator", step=3, title="放熱板を横から見る")),
])

# ---- 第5章 宇宙服は氷で冷やす。そして答え -----------------------------------------------------------------
P["ch5"] = dict(title="第5章 宇宙服は氷で冷やす。そして答え", lines=[
    dict(id="g1", text="最後に、宇宙服です。", scene=ILLUST("suit1", step=4, tr="whip")),
    dict(id="g2", text="中の人は、動いているとき、191Wほどの熱を出します。"),
    dict(id="g3", text="服の中に熱がこもれば、すぐに暑くて動けなくなってしまいます。"),
    dict(id="g4", text="そこで使うのが、水です。", scene=S("sublim", step=4, title="宇宙服の冷やし方")),
    dict(id="g5", text="背負った装置の中で、水を、細かい穴のあいた板へ送ります。"),
    dict(id="g6", text="穴の外は真空。水は熱を奪われて、板の上で凍ります。"),
    dict(id="g7", text="その氷が真空へ蒸発していくとき、熱を持ち去るのです。"),
    dict(id="g8", text="1回の船外活動で捨てる水は、およそ3.6kg。", scene=S("icons", kind="bottle", n=7, title="3.6kg ＝ ペットボトル 約7本", note="500mLで計算", step=4)),
    dict(id="g9", text="500mLのペットボトル、7本ぶんです。"),
    dict(id="g10", text="氷が蒸発するときに奪う熱から計算すると、8時間ならして354W。", scene=CARD("354W", sub="3.6kgの氷が奪う熱（8時間ならす）", note="人の熱と、服の機械の熱", step=4)),
    dict(id="g11", text="自分の水を捨てて、人と機械の熱を冷ましているのです。"),
    dict(id="g12", text="まとめます。", section=True, scene=S("cards", items=ANSWERS, n=1, step=4, tr="flash")),
    dict(id="g13", text="1つ目。宇宙の空気は地上の1兆分の1。触れて冷えることも、空気に運んでもらうこともできない。"),
    dict(id="g14", text="2つ目。残る道は光だけ。日なたの黒い板は120℃、人は1時間に8℃しか下がらない。", scene=S("cards", items=ANSWERS, n=2, step=4)),
    dict(id="g15", text="3つ目。宇宙ステーションは、水とアンモニアで熱を集め、放熱板から光で捨てる。", scene=S("cards", items=ANSWERS, n=3, step=4)),
    dict(id="g16", text="4つ目。放熱板は白い。黒なら日なたで62℃になり、熱を捨てられない。", scene=S("cards", items=ANSWERS, n=4, step=4)),
    dict(id="g17", text="5つ目。宇宙服は、水を凍らせて蒸発させ、熱を捨てる。", scene=S("cards", items=ANSWERS, n=5, step=4)),
    dict(id="g18", text="宇宙は寒いのではなく、熱を渡す相手がいない場所なのです。", scene=G((120, 15), (150, 10), 0.44, step=4)),
    dict(id="g19", text="次に魔法瓶でお茶を飲むときは、壁と壁のすき間を思い出してください。", scene=ILLUST("thermos2", step=4)),
    dict(id="g20", text="そこにあるのは、宇宙と同じ真空です。"),
])

# ---- ショート ---------------------------------------------------------------------------------------
P["s1"] = dict(title="宇宙はマイナス270℃なのに、冷えない", lines=[
    dict(id="a1", text="宇宙はマイナス270℃。なのに、物は簡単には冷えません。", scene=G((150, 25), (170, 20), 0.40)),
    dict(id="a2", text="宇宙ステーションが飛ぶ高さ400kmの空気は、地上の1兆分の1。", scene=CARD("1兆分の1", sub="高さ400kmの空気（地上と比べて）")),
    dict(id="a3", text="6畳の部屋なら、地上は61kg。400kmでは、1グラムの2千万分の1です。", scene=S("air", title="同じ6畳の部屋の空気")),
    dict(id="a4", text="これでは、空気が熱を運んでくれません。", scene=S("ways", cross=[1])),
    dict(id="a5", text="何にも触れていないので、伝わる先もない。", scene=S("ways", cross=[0, 1])),
    dict(id="a6", text="残る道は、赤外線という光で出すことだけです。"),
    dict(id="a7", text="魔法瓶が冷めにくいのも、壁のすき間が真空だから。", scene=ILLUST("thermos1")),
    dict(id="a8", text="宇宙は、とても大きな魔法瓶の中なのです。"),
])

P["s2"] = dict(title="宇宙の日なたは120℃になる", lines=[
    dict(id="b1", text="宇宙の日なたに黒い板を置くと、120℃になります。", scene=S("plate", color="black", sides=1, temp=120)),
    dict(id="b2", text="太陽の光は、1平方mあたり1,361W。", scene=CARD("1,361W", sub="太陽の光（1平方mあたり）")),
    dict(id="b3", text="板は、温まるほど強い赤外線を出します。", scene=S("plate", color="black", sides=1, temp=120)),
    dict(id="b4", text="入る光と出る光が釣り合う温度を計算すると、120℃。"),
    dict(id="b5", text="JAXAが示す日なたの温度とも、ぴったり合います。", scene=CARD("120℃", sub="宇宙の日なた（JAXA）")),
    dict(id="b6", text="ところが日陰に入ると、光はもう来ません。", scene=S("orbit", title="90分で地球を1周")),
    dict(id="b7", text="宇宙ステーションは90分で1周。1日に16回、日なたと日陰を行き来します。"),
    dict(id="b8", text="宇宙は寒いのではなく、熱さと寒さが極端な場所なのです。", scene=ILLUST("dark1")),
])

P["s3"] = dict(title="宇宙に出ても、人は一瞬で凍らない", lines=[
    dict(id="h1", text="宇宙に生身で出ても、一瞬で凍ることはありません。", scene=S("body", mode="none", title="人が宇宙に出たら")),
    dict(id="h2", text="空気がないので、熱は光でしか逃げないからです。"),
    dict(id="h3", text="皮膚が33℃の人が出す赤外線は、計算で641W。", scene=S("body", mode="watts")),
    dict(id="h4", text="体が作る熱を引くと、541Wずつ失います。"),
    dict(id="h5", text="それでも体全体で下がるのは、1時間に8℃です。", scene=S("body", mode="cool", title="体全体の温度（計算）")),
    dict(id="h6", text="1966年、真空の部屋で宇宙服の空気が抜けた事故では、12〜15秒で倒れました。", scene=CARD("12〜15秒", sub="1966年の事故で、倒れるまで", count=False)),
    dict(id="h7", text="原因は寒さではなく、酸素が足りなくなったこと。"),
    dict(id="h8", text="宇宙で本当に怖いのは、寒さより、息ができないことなのです。", scene=ILLUST("suit2")),
])

P["s4"] = dict(title="宇宙ステーションの放熱板が白い理由", lines=[
    dict(id="k1", text="宇宙ステーションの放熱板は、白く塗ってあります。", scene=ILLUST("radiator2")),
    dict(id="k2", text="もし黒かったら、日なたで62℃。", scene=S("pairp", title="日なたの板の温度（計算）")),
    dict(id="k3", text="中から運んだ2.8℃のアンモニアより熱く、熱を捨てられません。"),
    dict(id="k4", text="白い塗料は、太陽の光を86%はね返します。", scene=S("plate", color="white", sides=2, temp=-65)),
    dict(id="k5", text="それでいて、熱の赤外線はしっかり出す。"),
    dict(id="k6", text="計算すると、日なたでもマイナス65℃まで下がります。"),
    dict(id="k7", text="この白い板6枚、475平方mで、最大70kWの熱を捨てています。", scene=CARD("475平方m", sub="放熱板 6枚", note="最大70kWを捨てる")),
    dict(id="k8", text="宇宙で物を冷やすには、色がいちばん大事なのです。", scene=ILLUST("iss2")),
])

P["s5"] = dict(title="宇宙服は、氷で体を冷やしている", lines=[
    dict(id="m1", text="宇宙服は、氷で体を冷やしています。", scene=ILLUST("suit1")),
    dict(id="m2", text="背負った装置の中で、水を細かい穴の板へ送ります。", scene=S("sublim", title="宇宙服の冷やし方")),
    dict(id="m3", text="穴の外は真空。水は熱を奪われて凍ります。"),
    dict(id="m4", text="その氷が真空へ蒸発するとき、熱を持ち去るのです。"),
    dict(id="m5", text="1回の船外活動で捨てる水は、およそ3.6kg。", scene=S("icons", kind="bottle", n=7, title="3.6kg ＝ ペットボトル 約7本", note="500mLで計算")),
    dict(id="m6", text="500mLのペットボトル、7本ぶんです。"),
    dict(id="m7", text="氷が奪う熱から計算すると、8時間ならして354W。", scene=CARD("354W", sub="3.6kgの氷が奪う熱（8時間）")),
    dict(id="m8", text="宇宙は冷やしてくれないので、自分の水を捨てて冷えるのです。"),
])

# ---- 読み ------------------------------------------------------------------------------------------
YOMI = [("70kW", "ななじゅうキロワット"), ("100W", "ひゃくワット"), ("1,361W", "せんさんびゃくろくじゅういちワット"), ("641W", "ろっぴゃくよんじゅういちワット"),
        ("541W", "ごひゃくよんじゅういちワット"), ("296W", "にひゃくきゅうじゅうろくワット"), ("234W", "にひゃくさんじゅうよんワット"), ("191W", "ひゃくきゅうじゅういちワット"),
        ("354W", "さんびゃくごじゅうよんワット"), ("475平方m", "ヨンヒャクナナジュウゴヘイホウメートル"), ("300平方m", "サンビャクヘイホウメートル"),
        ("1平方m", "イチヘイホウメートル"), ("2.8℃", "ニテンハチド"), ("3.6kg", "さんてんろくキログラム"), ("61kg", "ろくじゅういちキログラム"), ("3.4m", "さんてんよんメートル"),
        ("1.6倍", "いってんろくばい"), ("12〜15秒", "じゅうにからじゅうごびょう"), ("6畳", "ろくじょう"), ("500mL", "ゴヒャクミリリットル"),
        ("1兆分の1", "いっちょうぶんのいち"), ("2千万分の1", "にせんまんぶんのいち"), ("生身", "なまみ"), ("日なた", "ひなた"), ("日陰", "ひかげ"),
        ("JAXA", "ジャクサ"), ("魔法瓶", "まほうびん"), ("放熱板", "ほうねつばん"), ("船外活動", "せんがいかつどう"), ("℃", "ど")]


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
