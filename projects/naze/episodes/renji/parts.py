"""電子レンジ: 本編 5 章とショート 5 本の台本と画面。ch1〜ch5・s1〜s5 の ep.py がここから読む。

出典は research.md(電波法施行規則 第46条の7、FDA、USDA、シャープの社史、Khattak ほか 2019 PNAS ほか)。
数字はデバイの式(水の誘電率)と熱の伝わり方から自分で計算した(heat_calc.py・scene.py の heat_run)。
台本の文言はユーザー承認済み(scripts.md 2版)。足したのは読みの say= と字幕の改行・強調だけ。
"""

CREDIT = "図は水の測定値と熱の伝わり方から計算"

# ---- 場面 -------------------------------------------------------------------------------
SLAB = dict(kind="slab", mode="reach")
SLAB_HEAT = dict(kind="slab", mode="layer")
SLAB_COND = dict(kind="slab", mode="conduct")
OVEN = dict(kind="oven")
FIELD = dict(kind="field")
DECAY0 = dict(kind="decay", marks=[])
DECAY1 = dict(kind="decay", marks=[2])
DECAY3 = dict(kind="decay", marks=[2, 4, 6])
DECAY26 = dict(kind="decay", marks=[2, 6])

HEAT_COLD = dict(kind="heat", frac=0.0)
HEAT_RUN = dict(kind="heat", run=True)
HEAT_ALL = dict(kind="heat")
HEAT = [dict(kind="heat", hl=[i]) for i in range(4)]
HEAT_03 = dict(kind="heat", hl=[0, 3])
PULSE0 = dict(kind="pulse", frac=0.0)
PULSE_RUN = dict(kind="pulse", run=True)
PULSE = dict(kind="pulse")
PULSE_C = dict(kind="pulse", hl=0)
PULSE_P = dict(kind="pulse", hl=1, diff=True)
PULSE_ARROW = dict(kind="pulse", arrows=True)

MOL_MANY = dict(kind="mol", mode="many")
MOL_ONE = dict(kind="mol", mode="one")
MOL_FIELD = dict(kind="mol", mode="field")
MOL_HEAT = dict(kind="mol", mode="field", heat=True)
MOL_ICE = dict(kind="mol", mode="ice")

ORDER = [2.45, 5.8, 20, 0.915]
DEPTH0 = dict(kind="depth", show=[])
DEPTH = [dict(kind="depth", show=ORDER[:i + 1], hl=ORDER[i]) for i in range(4)]
DEPTH_20 = dict(kind="depth", show=ORDER, hl=20)
DEPTH_245 = dict(kind="depth", show=ORDER, hl=2.45, good=True)
ABSORB = dict(kind="absorb")

MOTTLE = dict(kind="turn", spin=False)
WAVELEN = dict(kind="wavelen")
REFLECT = dict(kind="standing", mode="reflect")
STAND = dict(kind="standing", mode="sum")
STAND_GAP = dict(kind="standing", mode="gap")
TURN = dict(kind="turn", spin=True)
SHRINK0 = dict(kind="shrink", grape=False, water=False)
SHRINK = dict(kind="shrink", grape=False)
SHRINK_G = dict(kind="shrink", grape=True)
GRAPE = dict(kind="grape")

THAW_OUT = dict(kind="thaw", mode="outer")
THAW_MELT = dict(kind="thaw", mode="melt")
THAW_RUN = dict(kind="thaw", mode="runaway")
ICEWATER0 = dict(kind="icewater", ice=False)
ICEWATER = dict(kind="icewater", ice=True)


def card(n, sub, base):
    """実験の札(右の枠に大きく「実験n」)。"""
    return dict(base, panel=dict(kind="big", text=f"実験{n}", sub=sub, size=170, at=0.05))


def big(text, sub, base, size=130, at=0.15, title=None):
    p = dict(kind="big", text=text, sub=sub, size=size, at=at)
    if title:
        p["title"] = title
    return dict(base, panel=p)


X1 = card(1, "水に電波を当てて、どこまで届くか", OVEN)
X2 = card(2, "厚さを変えて温める", HEAT_COLD)
X3 = card(3, "周波数を変えて比べる", DEPTH0)
X4 = card(4, "氷に電波を当てる", ICEWATER0)
LAW = big("2,450MHz", "±50MHz・電波法施行規則", OVEN, size=120, title="日本の決まり")

# 読み(kana で全行を見て直したもの)。台本の字のまま読むと違う所だけを置き換えて say にする(ep_for)。
#   ℃ → 「ドシイ」と読む / 3分の1 → 「サンプンノイチ」と読む / 日本 → 「ニッポン」/ 札 → 「サツ」
#   2.45ギガヘルツ・24億5千万回は読めているが切れ目が細かいので仮名にする
YOMI = [
    ("2.45ギガヘルツ", "にーてんよんごギガヘルツ"),
    ("24億5千万回", "にじゅうよんおくごせんまんかい"),
    ("数千分の1", "すうせんぶんのいち"),
    ("30分の1", "さんじゅうぶんのいち"),
    ("10分の1", "じゅうぶんのいち"),
    ("3分の1", "さんぶんのいち"),
    ("℃", "度"),
    ("日本", "にほん"),
    ("裏の札", "裏のふだ"),
    ("6cmおき", "6センチおき"),
]


def yomi(text: str) -> str:
    for a, b in YOMI:
        text = text.replace(a, b)
    return text

P = {}
P["ch1"] = dict(title="第1章 「中から温まる」は、本当か", cta=False, lines=[
    dict(id="c1", text="電子レンジの電波が、しっかり届くのは、食べ物の表面から約2cmまで。", scene=SLAB),
    dict(id="c2", text="よく「電子レンジは中から温める」と言われます。でも、真ん中までは、ほとんど届きません。"),
    dict(id="c3", text="では、なぜ中まで熱くなるのか。", style="question", sub="では、なぜ\n【中まで】熱くなるのか"),
    dict(id="c4", text="答えは、外側で生まれた熱が、中へ伝わるから。", scene=SLAB_COND),
    dict(id="c5", text="この動画では、電子レンジの中を、計算で実験していきます。", scene=OVEN),
    dict(id="c6", text="実験1。水に電波を当てて、どこまで届くかを計算します。", section=True, scene=X1),
    dict(id="c7", text="電子レンジの電波は、1秒に24億5千万回、向きが変わる波です。", scene=FIELD,
         sub="電子レンジの電波は、1秒に\n【24億5千万回】、向きが変わる波です。"),
    dict(id="c8", text="水の中では、この電波は、進むほど弱くなります。", scene=DECAY0),
    dict(id="c9", text="水の測定値から計算すると、約2cmで、強さは3分の1。", scene=DECAY1),
    dict(id="c10", text="4cmで、約10分の1。6cmでは、約30分の1です。", scene=DECAY3),
    dict(id="c11", text="熱は、食べ物の中で生まれます。でも、生まれるのは表面から数cmの層。", scene=SLAB_HEAT),
    dict(id="c12", text="オーブンのように、表面だけを焼くのとは違います。ただし真ん中は、外から伝わる熱で温まるのです。", scene=SLAB_COND,
         sub="オーブンのように、表面だけを焼くのとは違います。|ただし真ん中は、\n外から伝わる熱で温まるのです。"),
])
P["ch2"] = dict(title="第2章 厚さを変えて、温めてみる", cta=False, lines=[
    dict(id="c1", text="実験2。同じ電子レンジで、厚さの違う食べ物を、温めてみます。", section=True, scene=X2),
    dict(id="c2", text="食べ物は、10cm四方の水のかたまり。5℃の冷蔵庫から出したところ。電波は上と下から入るとします。", scene=HEAT_COLD,
         sub="食べ物は、【10cm】四方の水のかたまり。|【5℃】の冷蔵庫から出したところ。|電波は上と下から入るとします。"),
    dict(id="c3", text="一番熱い所が100℃になった瞬間に、真ん中の温度を見ます。", scene=HEAT_RUN,
         sub="一番熱い所が【100℃】になった瞬間に、\n真ん中の温度を見ます。"),
    dict(id="c4", text="厚さ2cm。真ん中は、96℃。ほぼ全体が、熱くなりました。", scene=HEAT[0],
         sub="厚さ【2cm】。真ん中は、【96℃】。\nほぼ全体が、熱くなりました。"),
    dict(id="c5", text="厚さ4cm。真ん中は、78℃。", scene=HEAT[1], sub="厚さ【4cm】。真ん中は、【78℃】。"),
    dict(id="c6", text="厚さ6cm。真ん中は、54℃。", scene=HEAT[2], sub="厚さ【6cm】。真ん中は、【54℃】。"),
    dict(id="c7", text="そして厚さ10cm。外は100℃なのに、真ん中は、たった23℃。", scene=HEAT[3],
         sub="そして厚さ【10cm】。外は100℃なのに、\n真ん中は、たった【23℃】。"),
    dict(id="c8", text="厚さが5倍になると、真ん中は、ほとんど温まらないうちに、外が煮えてしまうのです。", scene=HEAT_03,
         sub="厚さが【5倍】になると、真ん中は、\nほとんど温まらないうちに、外が煮えてしまうのです。"),
    dict(id="c9", text="では、温め方を変えると、どうなるか。", section=True, scene=PULSE0),
    dict(id="c10", text="厚さ6cmで、10秒温めて20秒休む、をくり返します。", scene=PULSE_RUN),
    dict(id="c11", text="外が100℃になったとき、真ん中は70℃。続けて温めたときの54℃より、16℃高くなりました。", scene=PULSE_P,
         sub="外が100℃になったとき、真ん中は【70℃】。|続けて温めたときの54℃より、\n【16℃】高くなりました。"),
    dict(id="c12", text="休んでいる間に、外の熱が、中へ伝わるからです。", scene=PULSE_ARROW),
])
P["ch3"] = dict(title="第3章 周波数を変えると、どうなるか", cta=False, lines=[
    dict(id="c1", text="では、電波は、どうやって熱を生むのか。", section=True, scene=MOL_MANY),
    dict(id="c2", text="水の分子は、片側がプラス、反対側がマイナスに、少しかたよっています。", scene=MOL_ONE),
    dict(id="c3", text="電波が来ると、分子は、電波の向きにそろおうとして、くるっと回ります。", scene=MOL_FIELD),
    dict(id="c4", text="向きは1秒に24億5千万回入れ替わり、分子どうしが、こすれ合う。そのこすれが、熱です。", scene=MOL_HEAT,
         sub="向きは1秒に【24億5千万回】入れ替わり、|分子どうしが、こすれ合う。\nそのこすれが、熱です。"),
    dict(id="c5", text="実験3。電波の周波数を変えて、水にどこまで届くかを比べます。", section=True, scene=X3),
    dict(id="c6", text="2.45ギガヘルツなら、強さが3分の1になるのは、約1.9cm。", scene=DEPTH[0],
         sub="【2.45ギガヘルツ】なら、\n強さが3分の1になるのは、約【1.9cm】。"),
    dict(id="c7", text="5.8ギガヘルツにすると、約3.5mm。", scene=DEPTH[1], sub="【5.8ギガヘルツ】にすると、約【3.5mm】。"),
    dict(id="c8", text="20ギガヘルツでは、約0.4mm。表面の薄い皮だけが、熱くなります。", scene=DEPTH[2],
         sub="【20ギガヘルツ】では、約【0.4mm】。\n表面の薄い皮だけが、熱くなります。"),
    dict(id="c9", text="逆に、0.9ギガヘルツまで下げると、約13cm。大きなかたまりの奥まで届きます。", scene=DEPTH[3],
         sub="逆に、【0.9ギガヘルツ】まで下げると、約【13cm】。\n大きなかたまりの奥まで届きます。"),
    dict(id="c10", text="普通は、水が一番よく吸う周波数に合わせると思いがちです。ところが、吸いすぎると、表面しか温まらない。", scene=ABSORB,
         sub="普通は、水が一番よく吸う周波数に\n合わせると思いがちです。|ところが、吸いすぎると、\n表面しか温まらない。"),
    dict(id="c11", text="家庭の電子レンジは、日本の電波法の規則で、2,450メガヘルツ前後と決まっています。", scene=LAW,
         sub="家庭の電子レンジは、日本の電波法の規則で、\n【2,450メガヘルツ】前後と決まっています。"),
    dict(id="c12", text="世界共通で空けてある周波数で、数cmまで届く。ちょうどいい場所なのです。", scene=DEPTH_245),
])
P["ch4"] = dict(title="第4章 なぜ、温めムラができるのか", cta=False, lines=[
    dict(id="c1", text="電子レンジで温めると、熱い所と冷たい所が、まだらになります。", section=True, scene=MOTTLE),
    dict(id="c2", text="2.45ギガヘルツの電波は、波の長さが約12cm。", scene=WAVELEN,
         sub="【2.45ギガヘルツ】の電波は、波の長さが約【12cm】。"),
    dict(id="c3", text="電波は、庫内の壁ではね返ります。", scene=REFLECT),
    dict(id="c4", text="行く波と、はね返る波が重なると、強い所と弱い所が、動かずに並びます。", scene=STAND),
    dict(id="c5", text="強い所の間隔は、波の長さの半分。およそ6cmです。", scene=STAND_GAP),
    dict(id="c6", text="そこで、食べ物を回して、強い所と弱い所を、順番に通らせる。それが、回る皿です。", scene=TURN),
    dict(id="c7", text="日本で最初の回る皿の電子レンジは、1966年、シャープの製品です。",
         scene=big("1966年", "日本初の回る皿（シャープ）", TURN, size=150)),
    dict(id="c8", text="もう1つ、不思議な計算があります。", section=True, scene=SHRINK0),
    dict(id="c9", text="水の中に入ると、電波の波は縮みます。計算すると、約1.4cm。", scene=SHRINK,
         sub="水の中に入ると、電波の波は縮みます。\n計算すると、約【1.4cm】。"),
    dict(id="c10", text="ちょうど、ブドウ1粒ほどの大きさです。", scene=SHRINK_G),
    dict(id="c11", text="半分に切ったブドウを温めると、火花が出ることがあります。2019年、カナダの研究者が、粒の中に電波が集まるためだと確かめました。",
         scene=big("2019年", "カナダの研究（PNAS）", GRAPE, size=150, at=0.35),
         sub="半分に切ったブドウを温めると、\n火花が出ることがあります。|2019年、カナダの研究者が、\n粒の中に電波が集まるためだと確かめました。"),
    dict(id="c12", text="火事のもとになるので、まねはしないでください。", scene=big("まねしない", "火事のもとになります", GRAPE, size=120, at=0.1)),
])
P["ch5"] = dict(title="第5章 氷に、電波を当ててみる", lines=[
    dict(id="c1", text="凍った肉を温めると、外は煮えたのに、中は凍ったまま。", section=True, scene=THAW_OUT),
    dict(id="c2", text="実験4。氷に電波を当てて、どこまで届くかを計算します。", scene=X4),
    dict(id="c3", text="氷の分子は、固まっていて、くるっと回れません。", scene=MOL_ICE),
    dict(id="c4", text="だから氷は、電波を、水の数千分の1しか吸わない。", scene=big("数千分の1", "氷が電波を吸う強さ（水と比べて）", MOL_ICE, size=130),
         sub="だから氷は、電波を、\n水の【数千分の1】しか吸わない。"),
    dict(id="c5", text="計算すると、氷の中で電波が3分の1になるのは、約12m先。ほぼ素通りです。", scene=ICEWATER,
         sub="計算すると、氷の中で電波が3分の1になるのは、\n約【12m】先。ほぼ素通りです。"),
    dict(id="c6", text="ところが、一部が解けて水になると、そこだけが、急に電波を吸い始めます。", scene=THAW_MELT),
    dict(id="c7", text="熱くなった所はさらに解け、さらに吸う。だから、そこだけ煮えてしまうのです。", scene=THAW_RUN),
    dict(id="c8", text="解凍モードが、弱い電波で休み休み温めるのは、実験2と同じ理由。熱が中へ伝わる時間を作っています。", scene=PULSE_ARROW,
         sub="解凍モードが、弱い電波で休み休み温めるのは、\n実験2と同じ理由。|熱が中へ伝わる時間を作っています。"),
    dict(id="c9", text="電子レンジは、表面から約2cmで熱を生み、中は、外から伝わる熱で温まる。", section=True, scene=SLAB_COND),
    dict(id="c10", text="厚さ10cmなら、外が100℃でも、真ん中は23℃でした。", scene=HEAT[3],
         sub="厚さ【10cm】なら、外が100℃でも、\n真ん中は【23℃】でした。"),
    dict(id="c11", text="冒頭の「中から温める」は、半分だけ正解だったのです。", scene=big("半分だけ正解", "熱は外側で生まれ、中へ伝わる", SLAB_COND, size=110)),
    dict(id="c12", text="次に大きなおかずを温めたら、途中で一度、休ませてみてください。熱が、中へ回ります。", scene=OVEN,
         sub="次に大きなおかずを温めたら、\n途中で一度、休ませてみてください。|熱が、中へ回ります。"),
])

P["s1"] = dict(title="表面100℃、中心23℃", lines=[
    dict(id="c1", text="厚さ10cmの食べ物を電子レンジで温めると、表面が100℃でも、真ん中は23℃。", scene=HEAT[3],
         sub="厚さ【10cm】の食べ物を\n電子レンジで温めると、|表面が100℃でも、\n真ん中は【23℃】。"),
    dict(id="c2", text="なぜ、そんなに差が開くのか。", style="question", sub="なぜ、そんなに\n【差】が開くのか"),
    dict(id="c3", text="答えは、電波が表面から約2cmまでしか届かないから。", scene=SLAB),
    dict(id="c4", text="水の測定値から計算すると、電波は約2cmで3分の1。6cmで30分の1。", scene=DECAY26),
    dict(id="c5", text="熱が生まれるのは外側だけ。真ん中は、外から伝わる熱を待つしかありません。", scene=SLAB_COND),
    dict(id="c6", text="厚さ2cmなら、真ん中は96℃。厚さ10cmなら23℃。", scene=HEAT_03,
         sub="厚さ【2cm】なら、真ん中は【96℃】。\n厚さ【10cm】なら【23℃】。"),
    dict(id="c7", text="薄いほど、むらなく温まるのです。", scene=HEAT_ALL),
    dict(id="c8", text="次に大きなおかずを温めるときは、平たく広げてみてください。", scene=OVEN),
])
P["s2"] = dict(title="休み休みで、中が16℃上がる", lines=[
    dict(id="c1", text="電子レンジは、休み休み温めた方が、真ん中が熱くなります。", scene=PULSE),
    dict(id="c2", text="止めている時間があるのに、なぜでしょう。", style="question", sub="止めている時間があるのに、\nなぜでしょう"),
    dict(id="c3", text="答えは、熱が中へ伝わる時間ができるから。", scene=PULSE_ARROW),
    dict(id="c4", text="厚さ6cmの水のかたまりで、計算しました。", scene=PULSE0),
    dict(id="c5", text="続けて温めると、外が100℃のとき、真ん中は54℃。", scene=PULSE_C,
         sub="続けて温めると、外が100℃のとき、\n真ん中は【54℃】。"),
    dict(id="c6", text="10秒温めて20秒休むと、真ん中は70℃。16℃高くなりました。", scene=PULSE_P,
         sub="10秒温めて20秒休むと、真ん中は【70℃】。\n【16℃】高くなりました。"),
    dict(id="c7", text="解凍モードが弱く休み休み温めるのも、同じ理由です。", scene=OVEN),
    dict(id="c8", text="次に温めムラが出たら、一度止めて、1分待ってみてください。"),
])
P["s3"] = dict(title="周波数を変えたら", lines=[
    dict(id="c1", text="電子レンジの周波数を約8倍にすると、熱くなるのは、表面0.4mmの皮だけ。", scene=DEPTH_20,
         sub="電子レンジの周波数を約【8倍】にすると、|熱くなるのは、\n表面【0.4mm】の皮だけ。"),
    dict(id="c2", text="水を温めたいのに、なぜでしょう。", style="question", sub="水を温めたいのに、\nなぜでしょう"),
    dict(id="c3", text="答えは、水が電波を吸いすぎるから。", scene=MOL_HEAT),
    dict(id="c4", text="水が一番よく吸うのは、約20ギガヘルツ。電子レンジの約8倍です。", scene=ABSORB,
         sub="水が一番よく吸うのは、約【20ギガヘルツ】。\n電子レンジの約【8倍】です。"),
    dict(id="c5", text="そこでは、電波は表面のすぐ近くで、吸われきってしまう。", scene=DEPTH_20),
    dict(id="c6", text="家庭の2.45ギガヘルツなら、約1.9cmまで届きます。", scene=DEPTH_245,
         sub="家庭の【2.45ギガヘルツ】なら、\n約【1.9cm】まで届きます。"),
    dict(id="c7", text="吸いすぎず、届きすぎない。ちょうどいい周波数なのです。"),
    dict(id="c8", text="次に電子レンジの裏の札を見たら、2,450メガヘルツの文字を探してください。", scene=LAW,
         sub="次に電子レンジの裏の札を見たら、|【2,450メガヘルツ】の文字を\n探してください。"),
])
P["s4"] = dict(title="熱い所は6cmおき", lines=[
    dict(id="c1", text="電子レンジの中では、熱い所が、およそ6cmおきに並んでいます。", scene=STAND_GAP),
    dict(id="c2", text="なぜ、まだらになるのか。", style="question", sub="なぜ、\n【まだら】になるのか", scene=MOTTLE),
    dict(id="c3", text="答えは、電波の波の長さ。", scene=WAVELEN),
    dict(id="c4", text="2.45ギガヘルツの電波は、波の長さが約12cm。",
         sub="【2.45ギガヘルツ】の電波は、\n波の長さが約【12cm】。"),
    dict(id="c5", text="壁ではね返った波と重なって、強い所と弱い所が、動かずに並びます。", scene=STAND),
    dict(id="c6", text="強い所の間隔は、半分の約6cm。", scene=STAND_GAP),
    dict(id="c7", text="だから、回る皿で食べ物を動かして、ムラを減らしているのです。", scene=TURN),
    dict(id="c8", text="次に温めムラに気づいたら、6cmおきの熱い所を、探してみてください。", scene=MOTTLE),
])
P["s5"] = dict(title="氷は電波を素通りさせる", lines=[
    dict(id="c1", text="氷の中では、電子レンジの電波は、12m先まで届きます。ほぼ素通りです。", scene=ICEWATER,
         sub="氷の中では、電子レンジの電波は、\n【12m】先まで届きます。|ほぼ素通りです。"),
    dict(id="c2", text="それなら解凍は簡単なはず。なのに、なぜ外だけ煮えるのか。", style="question",
         sub="それなら解凍は簡単なはず。\nなのに、なぜ【外だけ】煮えるのか", scene=THAW_OUT),
    dict(id="c3", text="答えは、解けた所だけが、電波を吸うから。", scene=THAW_MELT),
    dict(id="c4", text="氷の分子は、固まっていて、回れません。だから電波を、水の数千分の1しか吸わない。", scene=MOL_ICE,
         sub="氷の分子は、固まっていて、回れません。|だから電波を、\n水の【数千分の1】しか吸わない。"),
    dict(id="c5", text="一部が解けて水になると、そこだけ急に熱くなります。", scene=THAW_MELT),
    dict(id="c6", text="熱くなった所は、さらに解けて、さらに吸う。", scene=THAW_RUN),
    dict(id="c7", text="解凍モードは、弱く休み休み温めて、熱が中へ伝わる時間を作っています。", scene=PULSE_ARROW),
    dict(id="c8", text="次に解凍するときは、途中で一度ひっくり返してみてください。", scene=OVEN),
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
    return dict(kind="sim", aspect="portrait" if name.startswith("s") else "landscape", credit=CREDIT, **p)
