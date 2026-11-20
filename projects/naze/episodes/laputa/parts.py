"""ラピュタを風船で浮かせる: 本編 11 章とショート 5 本の台本と画面。ch1〜ch11・s1〜s5 の ep.py がここから読む。
台本は scripts.md(10版、2026-11-01 ユーザー承認。文を変えない)、出典と計算は research.md・sim/*.py。
作品の映像・絵・音声・台詞は使わない。島は自作の簡単な図(雲・城・巨大な木・下の岩)。図は全部 scene.py がコードで描く(AI 絵は作らない)。
足したのは読みの say(YOMI)と画面だけ。
出典: 柳田理科雄(Yahoo!ニュース エキスパート 2022)・岡田斗司夫(note 2019)・QuizKnock(2022)の島の幅、花崗岩の密度=産総研 地質調査研究報告、
国際標準大気、Qualatex Helium Chart、NASA Balloon Program、気象庁 高層気象観測、東京ドーム施設概要、USGS MCS 2026(ヘリウム)、IEA(水素)、
FAA Balloon Flying Handbook、Energy Institute(一次エネルギー)、airships.net・Smithsonian(ヒンデンブルク号)、ケブラー49・東レ T1100G・
Bai ほか Nature Nanotechnology 2018(CNT の束)、H2Tools。計算は sim/calc.py・deep.py・cushion.py・frame.py。
"""
import re

CREDIT = "島の幅は3人の見積り・数字は自分の計算（標準大気）　島の図は自作"
CREDIT_V = "島の図は自作・数字は自分の計算"

GREEN, YEL, RED, WHITE, DIM = "green", "yel", "red", "white", "dim"
GREY = (170, 178, 192)
GRN = (110, 220, 140)
BLU = (90, 170, 235)
RD = (240, 90, 80)
VIO = (185, 140, 245)
TEAL = (80, 210, 190)
YL = (255, 214, 64)
AMBER = (240, 170, 70)


def K(kind, **kw):
    return dict(kind=kind, **kw)


def CARD(*rows, **kw):
    return dict(kind="formula", rows=list(rows), **kw)


def MARK(sym, *rows, **kw):
    """大きな ×・○ の札。"""
    return dict(kind="formula", rows=[(sym, 190, RED if sym == "×" else GREEN)] + list(rows), mark=sym, **kw)


def ISL(**kw):
    return K("island", **kw)


def BARS(rows, vmax, head=None, **kw):
    """rows = [(名前, 値, 数字の札, 色)]"""
    return K("bars", rows=list(rows), vmax=vmax, head=head, **kw)


def TABLE(rows, head, **kw):
    return K("table", rows=list(rows), head=head, **kw)


def BIG(big, sub, **kw):
    return K("big", big=big, sub=sub, **kw)


# 島の重さ(research.md 2-2。calc.py 2.92億・17.4億・48.3億t)
W_L = ("軽い島", 2.92, "2.9億t", GREY)
W_M = ("真ん中の島", 17.4, "17億t", YL)
W_H = ("重い島", 48.3, "48億t", RD)
KANARI = "形と岩の密度は仮置き"
AIR5 = "空気は5,000mのまま"
# 必要な強さ(強さ÷密度 MJ/kg。cushion.py: 境目 約6.7、ケブラー 2.40、T1100G 3.91、CNT繊維 6.77、CNT束 61.5)
S_KEV = ("ケブラー", 2.40, "2.40", AMBER)
S_CF = ("炭素繊維 T1100G", 3.91, "3.91", BLU)
S_CNTF = ("ナノチューブの糸", 6.77, "6.77　ぎりぎり届く", TEAL)
S_CNTB = ("ナノチューブの束", 61.5, "61.5　桁違い", GRN)
NEED = (6.7, "要る強さ　約6.7（ケブラーの約2.8倍）", RD)
S_HEAD = "糸の強さ ÷ 密度（MJ/kg）　同じ重さでの強さ"
# 膜・帯・ひもの重さ(cushion.py 9版: 輪の帯 5,980万t・縦の帯 3,720万t・ひも 1,760万t・膜 8.25万t、計 1.15億t = 島の6.6%)
WT_ROWS = [("島", 17.4, "17.4億t", YL), ("輪の帯", 0.598, "5,980万t", BLU), ("縦の帯", 0.372, "3,720万t", TEAL),
           ("ひも", 0.176, "1,760万t", AMBER), ("膜", 0.000825, "8.25万t", GREY)]
WT_NOTE = "膜・帯・ひも　全部で1.15億t　島の約7%"
# 1m³ の浮く力(research.md 3-1、deep.py)
LIFT_SEA = [("ヘリウム", 1.0557, "1.0557kg", BLU), ("水素", 1.1397, "1.1397kg", GRN)]
F_SEA = CARD(("浮く力 ＝ 押しのけた空気の重さ − ガスの重さ", 54, YEL), ("海面の1立方メートル", 46, DIM),
             ("ヘリウム　1.2250 − 0.1693 ＝ 1.0557kg", 52, WHITE), ("水素　1.1397kg", 52, WHITE))
F_5000 = CARD(("浮く力 ＝ 押しのけた空気の重さ − ガスの重さ", 54, YEL), ("5,000mの水素 1立方メートル", 46, DIM),
              ("0.7361 − 0.0512 ＝ 0.6849kg", 60, WHITE), ("気圧と気温は標準大気の式", 40, DIM))
YEARS_HE = [("世界の生産　1年分", 1, "1年", GREY), ("真ん中の島", 8680, "約8,700年分", RD)]
YEARS_HE3 = [("世界の生産　1年分", 1, "1年", GREY), ("軽い島", 1460, "約1,500年分", AMBER), ("真ん中の島", 8680, "約8,700年分", RD)]
YEARS_H2 = [("ヘリウム", 8680, "約8,700年分", RD), ("水素", 1.3, "1.3年分", GRN)]
CUSH = lambda st, **kw: K("cushion", stage=st, **kw)
FIN = lambda st, **kw: K("final", stage=st, **kw)

P = {}

P["ch1"] = dict(title="第1章 雲の中の島", cta=False, lines=[
    dict(id="c1", text="分厚い雲の中に、島がひとつ浮かんでいます。", scene=ISL(mode="cloud", zoom=(1.25, 1.0))),
    dict(id="c2", text="てっぺんには城。その城を抱きかかえるように、巨大な木が枝を広げていて、", scene=ISL(mode="cloud", focus="top", tags=["城と巨大な木"])),
    dict(id="c3", text="下には、ごつごつした岩のかたまり。", scene=ISL(mode="cloud", focus="rock", tags=["岩のかたまり"])),
    dict(id="c4", text="天空の城、ラピュタ。", scene=ISL(mode="cloud", name="天空の城ラピュタ", zoom=(1.0, 1.08))),
    dict(id="c5", text="作中では、この島がずっと空に浮かび続けています。", scene=ISL(mode="cloud", drift=True)),
    dict(id="c6", text="もし、この島を現実の風船で浮かせるとしたら。", scene=ISL(mode="cloud", dim=True), style="question",
         sub="もし、この島を\n【現実の風船】で浮かせるとしたら"),
    dict(id="c7", text="先に言っておくと、これは一筋縄ではいきません。", scene=CARD(("先に言っておくと", 60, WHITE), ("一筋縄ではいかない", 110, YEL)), section=True),
    dict(id="c8", text="途中で地球のガスが足りなくなり、火の心配が出てきて、空の高さまでが壁になる。",
         scene=CARD(("地球のガスが足りない", 72, WHITE), ("火の心配", 72, WHITE), ("空の高さの壁", 72, WHITE))),
    dict(id="c9", text="そして最後に、思いもしない敵が待っています。", scene=CARD(("そして最後に", 60, WHITE), ("思いもしない敵", 110, RED))),
    dict(id="c10", text="浮くのか、浮かないのか。最後の絵まで、計算してみます。", scene=CARD(("浮くのか、浮かないのか", 100, YEL), ("最後の絵まで計算する", 60, WHITE))),
    dict(id="c11", text="まずは、島の大きさから。", scene=ISL(mode="plain", measure=1), section=True),
    dict(id="c12", text="作中の島を画面から測ると、城のいちばん下の段の幅は1.6〜1.8km。", scene=ISL(mode="plain", measure=2)),
    dict(id="c13", text="歩いて20分ほどで、横切れる大きさです。", scene=ISL(mode="plain", measure=3)),
    dict(id="c14", text="上は城と町、下は岩のかたまり。岩を花崗岩とすると、1立方メートルで約2.65t。", scene=ISL(mode="plain", parts=2, tag=KANARI)),
    dict(id="c15", text="重さを左右するのは、中の詰まり具合。部屋だらけなら軽いし、岩がぎっしりなら重い。", scene=K("fill")),
    dict(id="c16", text="軽く見ても2.9億t、重く見れば48億t。", scene=BARS([W_L, W_H], 50, "島の重さ（中の詰まり具合で変わる）")),
    dict(id="c17", text="真ん中をとって、17億t。", scene=BARS([W_L, W_M, W_H], 50, "島の重さ（中の詰まり具合で変わる）", grow=[1])),
    dict(id="c18", text="東京ドームを岩でいっぱいにして、約530杯分の重さです。", scene=K("domes", n=530)),
    dict(id="c19", text="……とても、雲の中に浮かんでいられる重さには見えません。", scene=ISL(mode="cloud", tags=["17億t"], zoom=(1.0, 1.1))),
])

P["ch2"] = dict(title="第2章 お祭りの風船で測る", cta=False, lines=[
    dict(id="c1", text="この重さを、身近なもので測ってみます。お祭りで配る、あのヘリウムの風船。", scene=K("balloon", stage=0), section=True),
    dict(id="c2", text="1個が持ち上げられるのは、10g。1円玉10枚ぶんの力しかありません。", scene=K("balloon", stage=1, formula=True)),
    dict(id="c3", text="これを1億個集めても、やっと1,000t。", scene=K("cube")),
    dict(id="c4", text="島の重さは、その170万倍。", scene=BIG("170万倍", "島 17億t ÷ 風船1億個の1,000t")),
    dict(id="c5", text="つまり、要る風船は――170兆個。", scene=BIG("170兆個", "島を浮かせるのに要るお祭りの風船", count=True)),
    dict(id="c6", text="世界中の人に、ひとり2万個ずつ配って、やっと足りる数です。", scene=K("people")),
    dict(id="c7", text="ふくらませるだけでも大仕事で、1秒に1個ずつ休まず続けても、終わるまで約550万年。", scene=BIG("約550万年", "1秒に1個ずつ、休まずふくらませる")),
    dict(id="c8", text="ピラミッドができてから今日までが、約4,500年。その1,000倍以上になります。",
         scene=BARS([("ピラミッドから今日まで", 4500, "約4,500年", AMBER), ("風船をふくらませ終わるまで", 5.51e6, "約550万年", RD)], 5.6e6, "かかる年数")),
    dict(id="c9", text="全部を1列に並べれば、地球から太陽までの約330倍の長さ。", scene=K("row")),
    dict(id="c10", text="とんでもない数ですが、これでもまだ海面での話。", scene=CARD(("とんでもない数", 70, WHITE), ("これでもまだ　海面での話", 90, YEL))),
    dict(id="c11", text="作中のラピュタが浮かんでいるのは、雲の中や、その上です。", scene=ISL(mode="cloud", zoom=(1.1, 1.0))),
    dict(id="c12", text="雲の上の空気は、海面より4割も薄い。", scene=K("airbox", note="4割も薄い")),
    dict(id="c13", text="普通に考えれば、浮かせるのはもっと大変になるはずです。", scene=CARD(("普通に考えれば", 66, WHITE), ("もっと大変になるはず", 100, YEL))),
])

P["ch3"] = dict(title="第3章 あの島の高さで", cta=False, lines=[
    dict(id="c1", text="ここでは、雲の上の一例として、高さ5,000mにしておきます。", scene=K("alt", stage=0, tag="高さ5,000mは仮置き"), section=True),
    dict(id="c2", text="富士山の頂上より、さらに1,200mほど上。", scene=K("alt", stage=1, tag="高さ5,000mは仮置き")),
    dict(id="c3", text="海面なら1立方メートルで1.2kgある空気が、ここでは0.74kgしかありません。", scene=K("airbox")),
    dict(id="c4", text="浮く力は、押しのけた空気の重さから生まれます。空気が軽くなれば、風船の力も弱くなるはず。", scene=F_5000),
    dict(id="c5", text="ところが、要るガスの量は、1gも増えません。", scene=K("gasbar")),
    dict(id="c6", text="袋が自由にふくらめれば、の話ですが。"),
    dict(id="c7", text="上へ行くほど、中のガスもふくらんでいくからです。", scene=K("rise")),
    dict(id="c8", text="高い山の上で、お菓子の袋がパンパンになる。あれと同じことが起きています。", scene=K("snack")),
    dict(id="c9", text="押しのける空気は薄くなる。でも、そのぶん押しのける量が増える。差し引きすると、浮く力は変わりません。", scene=K("two", stage=0)),
    dict(id="c10", text="増えるのは、袋の大きさだけ。海面の約1.7倍になります。", scene=K("two", stage=1)),
    dict(id="c11", text="あの島の高さでも、ガスは足さなくていい。袋を大きくすればいい。", scene=CARD(("あの島の高さでも", 60, WHITE), ("ガスは足さなくていい", 90, YEL), ("袋を大きくすればいい", 90, WHITE))),
    dict(id="c12", text="では、袋はどこまで大きくできるのか。", scene=CARD(("では、袋は", 70, WHITE), ("どこまで大きくできるのか", 100, YEL))),
])

P["ch4"] = dict(title="第4章 もっと大きな袋", cta=False, lines=[
    dict(id="c1", text="身近なところでは、気象庁の気球。", scene=K("weather", stage=0), section=True),
    dict(id="c2", text="毎日2回、各地から空へ放たれていて、中身は水素です。", scene=K("weather", stage=1)),
    dict(id="c3", text="上がるにつれてふくらみ、高さ約30kmで、ぱちんと割れます。", scene=K("weather", stage=2)),
    dict(id="c4", text="もっと大きいのが、NASAの科学気球。", scene=K("nasa", stage=0)),
    dict(id="c5", text="膜の厚さは0.02mm。食品を包むラップほどの薄さしかないのに、", scene=K("nasa", stage=1)),
    dict(id="c6", text="ふくらむと113万立方メートル。", scene=K("nasa", stage=2)),
    dict(id="c7", text="東京ドームが約124万立方メートルなので、ほぼドーム1つ分の袋が空に浮かぶことになります。", scene=K("domevs")),
    dict(id="c8", text="昔の飛行船ヒンデンブルク号は、全長245m。東京タワーの7割ほどもありました。", scene=K("ship")),
    dict(id="c9", text="実は、袋は大きければ大きいほど得をします。", scene=K("spheres", stage=0)),
    dict(id="c10", text="大きさを2倍にしても、膜は4倍で済む。なのに、中の体積は8倍になる。", scene=K("spheres", stage=1)),
    dict(id="c11", text="膜の重さより、浮く力のほうが速く増えていくわけです。", scene=K("spheres", stage=2)),
    dict(id="c12", text="では、ラピュタに要る袋はどれくらいか。5,000mの空気のまま数えると、2.74兆立方メートル。",
         scene=CARD(("ラピュタに要るヘリウムの袋", 60, WHITE), ("2.74兆立方メートル", 110, YEL), ("真ん中の島・5,000mの空気のまま数える", 42, DIM))),
    dict(id="c13", text="これを島の真上に積み上げたら、高さ約1,200km。宇宙ステーションが回る高さの3倍です。", scene=K("column")),
    dict(id="c14", text="あの城と巨木の上から、袋の柱が宇宙まで突き抜けてしまう。"),
    dict(id="c15", text="さすがに無理なので、横に広げて1つの袋にまとめます。", scene=ISL(mode="plain", bag="sphere")),
    dict(id="c16", text="袋の大きさの見当はつきました。問題は、中に入れるヘリウムです。", scene=CARD(("袋の大きさの見当はついた", 64, WHITE), ("問題は、中に入れるヘリウム", 90, YEL))),
])

P["ch5"] = dict(title="第5章 ヘリウムの壁", cta=False, lines=[
    dict(id="c1", text="ヘリウムは、地下の天然ガスから取り出すガス。", scene=K("under", stage=0), section=True),
    dict(id="c2", text="病院のMRIにも使われていて、ものを極低温に冷やす役目では、代わりが利きません。",
         scene=CARD(("病院のMRI", 100, YEL), ("ものを極低温に冷やす役目", 64, WHITE), ("代わりが利かない", 80, WHITE))),
    dict(id="c3", text="世界で1年に作られる量は、1.9億立方メートル。アメリカ地質調査所の2026年版の数字です。",
         scene=CARD(("世界で1年に作られるヘリウム", 60, WHITE), ("1.9億立方メートル", 110, YEL), ("アメリカ地質調査所（USGS）2026年版", 42, DIM))),
    dict(id="c4", text="ラピュタに要る量を地上の量に直すと、1.65兆立方メートル。",
         scene=CARD(("ラピュタに要るヘリウム（地上の量に直す）", 56, WHITE), ("1.65兆立方メートル", 110, YEL), ("真ん中の島・空気は5,000mのまま", 42, DIM))),
    dict(id="c5", text="世界の生産の、約8,700年分。", scene=BARS(YEARS_HE, 9000, "ヘリウム　世界の生産の何年分か", tag=AIR5)),
    dict(id="c6", text="8,700年前といえば、人類がまだ文字を持っていなかった頃です。", scene=K("timeline")),
    dict(id="c7", text="一番軽い島ですら、約1,500年分。", scene=BARS(YEARS_HE3, 9000, "ヘリウム　世界の生産の何年分か", grow=[1], tag=AIR5)),
    dict(id="c8", text="それなら、地下で見つかっているヘリウムを全部かき集めたら。", scene=K("under", stage=1)),
    dict(id="c9", text="全部で約400億立方メートル。", scene=K("under", stage=2)),
    dict(id="c10", text="……それでも、島の40分の1にも届きません。", scene=ISL(mode="plain", lit=1 / 41.4, tags=["約40分の1しか浮かない"])),
    dict(id="c11", text="ヘリウムでは、ラピュタは浮かない。", scene=MARK("×", ("ヘリウムでは浮かない", 90, WHITE))),
    dict(id="c12", text="次の手は、ガスそのものを替えることです。", scene=CARD(("次の手", 70, WHITE), ("ガスそのものを替える", 110, YEL))),
])

P["ch6"] = dict(title="第6章 ガスを替える", cta=False, lines=[
    dict(id="c1", text="候補のひとつ目は、熱した空気。熱気球です。", scene=K("hot", stage=0), section=True),
    dict(id="c2", text="これならガスはいらない。空気を温めるだけで済みます。", scene=K("hot", stage=1)),
    dict(id="c3", text="ただ、中を121℃まで熱しても、浮く力はヘリウムの約4割。",
         scene=BARS([("ヘリウム", 0.634, "0.634kg", BLU), ("熱した空気（中121℃）", 0.259, "0.259kg　約4割", AMBER)], 0.75, "1立方メートルの浮く力", tag=AIR5)),
    dict(id="c4", text="121℃は、多くの熱気球が続けて使ってよい上限の温度です。", scene=K("hot", stage=2)),
    dict(id="c5", text="しかも、浮かせている間はずっと燃やし続けなければなりません。", scene=K("hot", stage=3)),
    dict(id="c6", text="真ん中の島なら、燃やす量は世界で使うエネルギーの6〜10%。", scene=K("share", tag="熱の逃げ方は普通の熱気球と同じ割合（仮置き）")),
    dict(id="c7", text="島が浮かんでいる限り、それが毎日続く。熱気球は、ここで脱落です。", scene=MARK("×", ("熱気球は脱落", 90, WHITE))),
    dict(id="c8", text="最後の手は、水素。4章の気象庁の気球に入っていた、あのガスです。", scene=K("weather", stage=1)),
    dict(id="c9", text="ヘリウムより軽くて、浮く力は約8%大きい。", scene=BARS(LIFT_SEA, 1.25, "海面の1立方メートルの浮く力", note="水素は約8%大きい", ncol=GRN)),
    dict(id="c10", text="しかも世界では、1年に約1億tも使われています。", scene=CARD(("世界で使われる水素", 64, WHITE), ("1年に約1億t", 120, YEL), ("IEA（国際エネルギー機関）", 40, DIM))),
    dict(id="c11", text="真ん中の島に要るのは、その1.3年分。", scene=BARS(YEARS_H2, 9000, "真ん中の島　世界の生産の何年分か")),
    dict(id="c12", text="8,700年が、一気に1年あまりまで縮みました。", scene=BARS(YEARS_H2, 9000, "真ん中の島　世界の生産の何年分か", done=True, note="8,700年 → 1年あまり", ncol=GRN)),
    dict(id="c13", text="ただし、水素は燃えます。空気に4%混ざるだけで、火がつくほど。", scene=K("mix4")),
    dict(id="c14", text="1937年、ヒンデンブルク号は着陸の時に炎上しました。", scene=CARD(("1937年", 120, YEL), ("ヒンデンブルク号", 80, WHITE), ("着陸の時に炎上", 70, WHITE))),
    dict(id="c15", text="中は水素。乗っていた97人のうち35人と、地上の1人。あわせて36人が亡くなっています。",
         scene=CARD(("中は水素", 60, WHITE), ("乗っていた97人のうち35人", 66, WHITE), ("地上の1人", 66, WHITE), ("あわせて36人が亡くなった", 72, YEL))),
    dict(id="c16", text="それでも、量で勝負できるガスは水素しかない。火を遠ざけて、水素で行きます。", scene=MARK("○", ("火を遠ざけて、水素で行く", 80, WHITE))),
    dict(id="c17", text="……と言いたいところですが、ここまでの数え方には、大きな見落としがありました。",
         scene=CARD(("ここまでの数え方には", 66, WHITE), ("大きな見落とし", 120, RED))),
])

P["ch7"] = dict(title="第7章 空の高さの壁", cta=False, lines=[
    dict(id="c1", text="ここまでは、袋のまわりの空気を5,000mの濃さで数えてきました。", scene=K("bag", stage=0), section=True),
    dict(id="c2", text="ひもの重さまで入れて同じように数えると、真ん中の島に要る水素の袋は、直径18.5km。", scene=K("bag", stage=1)),
    dict(id="c3", text="これをNASAの気球と同じ形にすると、ぐんと背が高くなります。", scene=K("bag", stage=2)),
    dict(id="c4", text="てっぺんの空気の濃さは、袋の口のたった1割。", scene=K("bag", stage=3)),
    dict(id="c5", text="高さごとに空気を変えて数え直すと、浮く力は3分の1ほどに落ちてしまいます。",
         scene=BARS([("5,000mの空気のまま", 100, "100%", GREY), ("高さごとに空気を変える", 35, "35%", RD)], 110, "直径18.5kmの袋の浮く力", tag="標準大気の式で計算")),
    dict(id="c6", text="ここで、話がひっくり返ります。3章の「1gも増えない」は、袋が小さいときの話だった。",
         scene=CARD(("3章の「1gも増えない」は", 66, WHITE), ("袋が小さいときの話", 110, YEL))),
    dict(id="c7", text="根っこにあるのは、空気そのものの重さ。", scene=K("aircol", stage=0)),
    dict(id="c8", text="5,000mより上の空気は、1平方メートルあたり5.5t。", scene=K("aircol", stage=1)),
    dict(id="c9", text="袋がどれだけがんばっても、押しのけられるのはこの重さまでです。", scene=K("aircol", stage=2)),
    dict(id="c10", text="だから真ん中の島には、少なくとも316平方キロメートルの空が要る。", scene=K("area", stage=0)),
    dict(id="c11", text="山手線の内側が、5つすっぽり入る広さです。", scene=K("area", stage=1)),
    dict(id="c12", text="直径18.5kmの袋の影は、269平方キロメートル。届きません。", scene=K("area", stage=2)),
    dict(id="c13", text="袋を何個も横に並べても、ひもが斜めに引っぱるせいで、やっぱり届かない。", scene=K("cluster")),
    dict(id="c14", text="今ある材料で浮かせられるのは、軽く見積もった2.9億tの島だけ。",
         scene=TABLE([("軽い島", "2.9億t", "○", "浮く"), ("真ん中の島", "17億t", "×", "届かない"), ("重い島", "48億t", "×", "届かない")], "今ある材料で、袋で浮かせると")),
    dict(id="c15", text="その島なら、直径14.5kmの袋1つ。水素は年産の約9か月分で済みます。", scene=ISL(mode="plain", bag="nasa", baglabel=["直径14.5kmの袋1つ", "水素は年産の約9か月分"], weight="2.9億t")),
    dict(id="c16", text="でも、まだ終われません。ここから、真ん中の17億tの島に挑みます。", scene=CARD(("まだ終われない", 70, WHITE), ("真ん中の17億tの島に挑む", 100, YEL))),
])

P["ch8"] = dict(title="第8章 島を低い雲へ", cta=False, lines=[
    dict(id="c1", text="最初の手は、島そのものを下ろすこと。", scene=K("low", stage=0), section=True),
    dict(id="c2", text="作中の島は、雲の中にも浮かんでいます。5,000mは、あくまで雲の上の一例でした。"),
    dict(id="c3", text="そこで、低い雲の高さ、1,000mまで下ろしてみます。", scene=K("low", stage=1, tag="高さ1,000mは仮置き")),
    dict(id="c4", text="島を下ろしたぶん、袋はひもで高く吊り上げる。", scene=K("low", stage=2, tag="高さ1,000mは仮置き")),
    dict(id="c5", text="5kmほど上に吊っても、袋の口は5,800m。元の島とほぼ同じ高さに収まります。", scene=K("low", stage=3, tag="高さ1,000mは仮置き")),
    dict(id="c6", text="島が5,000mのままなら、袋の口は11kmまで上がります。", scene=K("low", stage=4)),
    dict(id="c7", text="袋の口より上の空気は、1平方メートルに4.9t。要る空は、352平方キロメートルで済む。",
         scene=CARD(("袋の口（5,800m）より上の空気", 60, WHITE), ("1平方メートルに4.9t", 90, YEL), ("要る空は352平方キロメートル", 80, WHITE))),
    dict(id="c8", text="口が11kmまで上がっていたら、その2倍ほど要るところでした。",
         scene=BARS([("口が5,800m", 352, "352平方キロメートル", GRN), ("口が11km", 710, "その2倍ほど", RD)], 760, "真ん中の島に要る空")),
    dict(id="c9", text="一歩前進。次は、袋の形を変えます。", scene=CARD(("一歩前進", 110, GREEN), ("次は、袋の形を変える", 80, WHITE))),
])

P["ch9"] = dict(title="第9章 座布団の袋", cta=False, lines=[
    dict(id="c1", text="背の高い袋はやめて、横に広い座布団の形にします。", scene=CUSH(0, tag="上下の膜を縦の帯で3mおきにつなぐ（仮置き）"), section=True),
    dict(id="c2", text="島は、袋の下から漏斗のように張ったひもで吊ります。", scene=CUSH(1)),
    dict(id="c3", text="ひもを真下に張れれば楽ですが、袋の幅は島の20倍近い。", scene=CUSH(1, wlabel=True)),
    dict(id="c4", text="外側のひもは斜めに張るしかなく、そのぶん袋を内側へぐいっと引き寄せます。", scene=CUSH(2)),
    dict(id="c5", text="いちばん外のひもは、真下の3倍の力で横に引く。", scene=CUSH(3)),
    dict(id="c6", text="全部足すと、横の力は島の重さの2倍以上。", scene=CUSH(4)),
    dict(id="c7", text="これが、最後の敵です。", scene=CARD(("これが", 70, WHITE), ("最後の敵", 150, RED), ("斜めのひもの横の力", 60, WHITE))),
    dict(id="c8", text="押し返すには、袋の口を閉じて、中の圧力を上げる。傘の骨を、空気の圧力で張るような形です。", scene=CUSH(5)),
    dict(id="c9", text="上乗せする圧力は、外の気圧の2倍以上。", scene=CUSH(5, plabel="上乗せする圧力　外の気圧の2倍以上")),
    dict(id="c10", text="すると今度は、その圧力を閉じ込める帯が重くなりすぎました。", scene=CUSH(6)),
    dict(id="c11", text="同じ形でケブラーを使うと、帯とひもだけで38億t。浮く力は16億tしかありません。",
         scene=BARS([("帯とひも（ケブラー）", 38.3, "38億t", RD), ("浮く力", 16.1, "16億t", GRN)], 42, "同じ形でケブラーを使うと", mark="×")),
    dict(id="c12", text="炭素繊維に替えても届かないし、骨組みで支えても、ひもと袋の群れが重すぎる。",
         scene=TABLE([("ケブラー", "帯とひもが重すぎる", "×", "浮く力16億t"), ("炭素繊維 T1100G", "帯とひもが重すぎる", "×", "届かない"),
                      ("骨組みで支える", "ひもと袋の群れが重い", "×", "届かない")], "今ある材料での座布団の袋")),
    dict(id="c13", text="残るのは、もっと強い糸を探すことです。", scene=CARD(("残るのは", 70, WHITE), ("もっと強い糸を探すこと", 100, YEL))),
])

P["ch10"] = dict(title="第10章 最強の糸", cta=False, lines=[
    dict(id="c1", text="この形で浮かせるには、どれだけ強い糸が要るのか。", scene=CARD(("この形で浮かせるには", 66, WHITE), ("どれだけ強い糸が要るのか", 100, YEL)), section=True),
    dict(id="c2", text="計算すると、同じ重さで比べてケブラーの約2.8倍。", scene=BARS([S_KEV], 10, S_HEAD, marks=[NEED])),
    dict(id="c3", text="炭素繊維の T1100G と比べても、約1.7倍の強さが要ります。", scene=BARS([S_KEV, S_CF], 10, S_HEAD, marks=[NEED], grow=[1])),
    dict(id="c4", text="今ある量産の繊維は、どれも届かない。", scene=BARS([S_KEV, S_CF], 10, S_HEAD, marks=[NEED], done=True, note="今ある量産の繊維は届かない")),
    dict(id="c5", text="届くのは、実験室で作られたカーボンナノチューブ。炭素の原子が筒になった、細い糸です。", scene=K("lattice")),
    dict(id="c6", text="長い糸に紡いだものでも、ぎりぎり届く。細い束なら、桁違いに超えます。", scene=BARS([S_KEV, S_CF, S_CNTF, S_CNTB], 10, S_HEAD, marks=[NEED], grow=[2, 3])),
    dict(id="c7", text="束の強さを1平方ミリに直すと、約8tを支える計算。",
         scene=CARD(("カーボンナノチューブの束　80GPa", 60, WHITE), ("1平方ミリで約8t", 120, YEL), ("長さ数cmの試料（2018年の論文）", 44, DIM), tag="密度1.3は仮置き")),
    dict(id="c8", text="密度を1.3とすれば、同じ重さでケブラーの約26倍です。",
         scene=BARS([("ケブラー", 1, "1", AMBER), ("ナノチューブの束", 25.7, "約26倍", GRN)], 28, "同じ重さでの強さ（ケブラーを1として）", tag="密度1.3は仮置き")),
    dict(id="c9", text="ただし、これは長さ数cmの試料での値。長いひもにした例は、まだ報告されていません。",
         scene=CARD(("ただし", 60, WHITE), ("長さ数cmの試料での値", 90, YEL), ("長いひもにした例は、まだ報告されていない", 56, WHITE))),
    dict(id="c10", text="その前提で、ひもと帯と膜の補強に、この束を使ってみます。",
         scene=CARD(("作戦", 130, YEL), ("島は低い雲（1,000m）・座布団の袋・漏斗のひも", 52, WHITE), ("ひも・帯・膜の補強はナノチューブの束", 52, WHITE))),
    dict(id="c11", text="袋は直径32km、厚さ12km。", scene=CUSH(7)),
    dict(id="c12", text="中の圧力は、外の約3倍。上乗せは、外の気圧の約2倍です。",
         scene=BARS([("外の気圧", 48, "1", GREY), ("上乗せ", 95, "約2倍", AMBER), ("中の圧力", 143, "約3倍", RD)], 160, "袋の口の高さ（5,800m）の圧力")),
    dict(id="c13", text="これで、ひもが内側へ引く力を、余裕を持たせて押し返せる。", scene=CUSH(5, balance=True)),
    dict(id="c14", text="膜と帯とひもを全部積み上げても、島の7%ほど。", scene=BARS(WT_ROWS, 18.5, "浮かせる重さの内訳", note=WT_NOTE, ncol=GRN)),
    dict(id="c15", text="浮く力は19億t。島と袋を合わせた18.5億tを、わずかに上回りました。",
         scene=BARS([("島と袋（要る重さ）", 18.55, "18.5億t", YL), ("浮く力", 19.25, "19億t", GRN)], 21, "浮く力と要る重さ")),
    dict(id="c16", text="浮く力は、口より上の空気の重さの半分ほど。上限の内側です。",
         scene=BARS([("上限（口より上の空気×影）", 39.77, "40億t", GREY), ("浮く力", 19.25, "19億t　半分ほど", GRN)], 42, "浮く力の上限")),
    dict(id="c17", text="水素は、世界の年産の14年分。中の圧力が高いぶん、ガスも重くなりました。",
         scene=CARD(("水素は", 60, WHITE), ("世界の年産の14年分", 110, YEL), ("中の圧力が高いぶん、ガスも重い", 56, WHITE))),
    dict(id="c18", text="それでも――計算の上では、真ん中の島が浮きます。", scene=MARK("○", ("計算の上では、真ん中の島が浮く", 74, WHITE))),
    dict(id="c19", text="重い48億tの島は、この手でも届きません。",
         scene=TABLE([("軽い島", "2.9億t", "○", "浮く"), ("真ん中の島", "17億t", "○", "計算の上では浮く"), ("重い島", "48億t", "×", "この手でも届かない")], "最強の糸の作戦")),
    dict(id="c20", text="重さが2.8倍なら、要る空も2.8倍。袋がさらに高く伸びて、薄い空気に入ってしまうからです。",
         scene=BARS([("真ん中の島に要る空", 1, "1", YL), ("重い島に要る空", 2.8, "2.8倍", RD)], 3.2, "要る空の広さ")),
])

P["ch11"] = dict(title="第11章 結末", lines=[
    dict(id="c1", text="残る心配は、風と火。", scene=CARD(("残る心配は", 70, WHITE), ("風と火", 150, YEL)), section=True),
    dict(id="c2", text="火の気は、袋に近づけないことにします。口を閉じた袋なので、昼に日差しで温まっても、ガスは逃げません。", scene=CUSH(8, tag="火の気は袋に近づけない")),
    dict(id="c3", text="上空の風が秒速20mでも、袋を押す力は島の重さの0.1%足らず。", scene=CUSH(9, tag="風速と抗力係数0.2〜0.5は仮置き")),
    dict(id="c4", text="小さな力ですが、横から押さえるものが何もないので、島は風と一緒に流されていきます。", scene=FIN(6)),
    dict(id="c5", text="その速さ、時速72km。", scene=FIN(6, speed=True)),
    dict(id="c6", text="雲と一緒に空を渡っていく島。作中の姿とも重なります。", scene=ISL(mode="cloud", drift=True, zoom=(1.0, 1.1))),
    dict(id="c7", text="入れていないのは、袋の作り方と、上がる途中だけ。", scene=CARD(("計算に入れていないもの", 60, DIM), ("袋の作り方", 90, WHITE), ("上がる途中", 90, WHITE))),
    dict(id="c8", text="では、結末の絵です。", scene=FIN(0), section=True),
    dict(id="c9", text="低い雲の中、高さ1,000mに、城と巨木と岩の島。", scene=FIN(1)),
    dict(id="c10", text="その4.8km上に、直径32kmの座布団が広がっています。東京23区がすっぽり隠れる広さ。", scene=FIN(2)),
    dict(id="c11", text="島から袋へは、長いもので17kmのひもが、漏斗のように伸びていて、", scene=FIN(3)),
    dict(id="c12", text="袋のてっぺんは地上17.8km。旅客機よりずっと上です。", scene=FIN(4)),
    dict(id="c13", text="島の幅は、袋の約19分の1。", scene=FIN(5)),
    dict(id="c14", text="空に浮かぶ島の正体は、雲の上の座布団に吊られた島でした。", scene=FIN(5, all=True)),
    dict(id="c15", text="次にお祭りで風船を手にしたら、この大きな座布団を思い出してください。", scene=K("balloon", stage=2)),
])

# ---- ショート ----
P["s1"] = dict(title="島の大きさ", lines=[
    dict(id="c1", text="雲の中に浮かぶ島、ラピュタ。上には城と巨大な木、下には岩のかたまり。", scene=ISL(mode="cloud", tags=["城と巨大な木", "岩のかたまり"])),
    dict(id="c2", text="この島がどれくらい大きいのか、作中の画面から測った人が3人います。", scene=ISL(mode="plain", measure=1)),
    dict(id="c3", text="空想科学研究所の柳田理科雄さんは、パズーの身長を1.4mとして測って、1.6km。", scene=K("three", stage=1)),
    dict(id="c4", text="岡田斗司夫さんは、凧の操縦席を1mとして、崩れたあとの段の幅で1.76km。", scene=K("three", stage=2)),
    dict(id="c5", text="岡田さんは、元の島はもっと大きかったと見ています。"),
    dict(id="c6", text="そしてQuizKnockは、1.8km。", scene=K("three", stage=3)),
    dict(id="c7", text="物差しはばらばらなのに、城のいちばん下の段の幅は、ほぼそろいました。", scene=ISL(mode="plain", measure=2)),
    dict(id="c8", text="歩いて20分ほどで横切れる大きさです。", scene=ISL(mode="plain", measure=3)),
    dict(id="c9", text="では、重さは。上は城と町、下は岩のかたまり。", scene=ISL(mode="plain", parts=1, tag=KANARI)),
    dict(id="c10", text="岩を花崗岩とすれば、1立方メートルで約2.65t。", scene=ISL(mode="plain", parts=2, tag=KANARI)),
    dict(id="c11", text="決め手は中の詰まり具合で、部屋だらけなら軽く、岩がぎっしりなら重い。", scene=K("fill")),
    dict(id="c12", text="軽く見て2.9億t、重く見れば48億t。", scene=BARS([W_L, W_H], 50, "島の重さ")),
    dict(id="c13", text="その差、約17倍。", scene=BARS([W_L, W_H], 50, "島の重さ", done=True, note="その差　約17倍", ncol=YL)),
    dict(id="c14", text="どちらにしても、空に浮かぶにはずっしり重い島です。", scene=ISL(mode="cloud", tags=["2.9億〜48億t"], zoom=(1.0, 1.1))),
])

P["s2"] = dict(title="ふくらませるだけで550万年", lines=[
    dict(id="c1", text="雲の中に浮かぶ、天空の城ラピュタ。", scene=ISL(mode="cloud", zoom=(1.2, 1.0))),
    dict(id="c2", text="この島を、お祭りの風船で浮かせてみます。", scene=K("balloon", stage=0)),
    dict(id="c3", text="直径28cmの風船1個が持ち上げられるのは、10g。1円玉10枚ぶんです。", scene=K("balloon", stage=1)),
    dict(id="c4", text="島の重さは、作中の画面から測った大きさで見積もって、真ん中の値で17億t。", scene=BARS([W_L, W_M, W_H], 50, "島の重さ", grow=[1])),
    dict(id="c5", text="風船を1億個集めても、やっと1,000t。島はその170万倍の重さです。", scene=K("cube", times=True)),
    dict(id="c6", text="つまり、要る風船は――170兆個。", scene=BIG("170兆個", "島を浮かせるのに要る風船", count=True)),
    dict(id="c7", text="世界中の人に、ひとり2万個ずつ。4人家族なら、8万個の風船です。", scene=K("people", family=True)),
    dict(id="c8", text="これを、1秒に1個ずつふくらませていきます。", scene=K("counter")),
    dict(id="c9", text="1日で約8万6千個。1年たっても、約3,200万個。", scene=CARD(("1日で", 60, WHITE), ("約8万6千個", 110, YEL), ("1年で", 60, WHITE), ("約3,200万個", 110, YEL))),
    dict(id="c10", text="休まず続けて、ふくらませ終わるのは約550万年後。", scene=BIG("約550万年後", "1秒に1個ずつ、休まず")),
    dict(id="c11", text="ピラミッドができてから今日までの、1,000倍以上です。",
         scene=BARS([("ピラミッドから今日まで", 4500, "約4,500年", AMBER), ("ふくらませ終わるまで", 5.51e6, "約550万年", RD)], 5.6e6, "かかる年数")),
    dict(id="c12", text="並べれば、地球から太陽までの約330倍の列になります。", scene=K("row")),
    dict(id="c13", text="空に浮かぶ島は、風船の数ではとても追いつけない重さでした。", scene=ISL(mode="cloud", tags=["17億t"], zoom=(1.0, 1.1))),
])

P["s3"] = dict(title="雲の上で増えるのは袋だけ", lines=[
    dict(id="c1", text="作中のラピュタは、雲の中や、その上に浮かんでいます。", scene=ISL(mode="cloud", zoom=(1.2, 1.0))),
    dict(id="c2", text="その高さで風船を使ったら、どうなるか。", scene=K("rise", still=True)),
    dict(id="c3", text="ここでは雲の上の一例として、高さ5,000mにしておきます。", scene=K("alt", stage=1, tag="高さ5,000mは仮置き")),
    dict(id="c4", text="富士山の頂上より、1,200mほど上。空気の重さは、海面の約6割しかありません。", scene=K("airbox", note="海面の約6割")),
    dict(id="c5", text="浮く力は押しのけた空気の重さから生まれるので、普通は、もっとたくさんのヘリウムが要るはず。",
         scene=CARD(("浮く力 ＝ 押しのけた空気の重さ − ガスの重さ", 44, YEL), ("空気が薄いなら", 70, WHITE), ("もっとヘリウムが要るはず？", 70, WHITE))),
    dict(id="c6", text="ところが、要るヘリウムは1gも増えません。", scene=K("gasbar")),
    dict(id="c7", text="袋が自由にふくらめれば、の話ですが。"),
    dict(id="c8", text="上へ行くほど、中のガスもふくらむからです。", scene=K("rise")),
    dict(id="c9", text="高い山の上で、お菓子の袋がパンパンになる。あれと同じ。", scene=K("snack")),
    dict(id="c10", text="押しのける空気は薄くなる。でも、押しのける量が増える。差し引きで、浮く力はそのまま。", scene=K("two", stage=0)),
    dict(id="c11", text="雲の上でも、ガスの量は海面と同じ。変わるのは袋の大きさだけで、約1.7倍になります。", scene=K("two", stage=1)),
    dict(id="c12", text="ただし、島ほどの大きな袋になると話は別。", scene=K("bag", stage=2)),
    dict(id="c13", text="袋の上のほうが薄い空気に届いて、この話は崩れてしまいます。", scene=K("bag", stage=3)),
])

P["s4"] = dict(title="地球のヘリウムを全部集めても", lines=[
    dict(id="c1", text="雲の中に浮かぶ、天空の城ラピュタ。", scene=ISL(mode="cloud", zoom=(1.2, 1.0))),
    dict(id="c2", text="この島を、ヘリウムで浮かせようとすると。", scene=ISL(mode="plain", bag="sphere")),
    dict(id="c3", text="島の重さは、作中の画面から見積もって17億t。", scene=CARD(("島の重さ", 70, WHITE), ("17億t", 150, YEL), (AIR5, 44, DIM))),
    dict(id="c4", text="要るヘリウムは、地上の量に直して1.65兆立方メートル。", scene=CARD(("要るヘリウム（地上の量）", 60, WHITE), ("1.65兆", 150, YEL), ("立方メートル", 70, WHITE))),
    dict(id="c5", text="ヘリウムは地下の天然ガスから取り出すガスで、病院のMRIにも使われています。", scene=K("under", stage=0)),
    dict(id="c6", text="世界で1年に作られるのは、1.9億立方メートル。", scene=CARD(("世界で1年に作られる量", 60, WHITE), ("1.9億", 150, YEL), ("立方メートル", 70, WHITE), ("アメリカ地質調査所 2026年版", 44, DIM))),
    dict(id="c7", text="島に要るのは、その約8,700年分。", scene=BARS(YEARS_HE, 9000, "ヘリウム　世界の生産の何年分か")),
    dict(id="c8", text="人類が文字を持つより前から作り続けて、やっと届く量です。", scene=K("timeline")),
    dict(id="c9", text="それなら、地下で見つかっているヘリウムを全部集めたら。全部で約400億立方メートル。", scene=K("under", stage=2)),
    dict(id="c10", text="……それでも、島の40分の1にも届きません。", scene=ISL(mode="plain", lit=1 / 41.4, tags=["約40分の1しか浮かない"])),
    dict(id="c11", text="地球のヘリウムでは、あの城は空に上がらない。", scene=MARK("×", ("地球のヘリウムでは", 70, WHITE), ("空に上がらない", 70, WHITE))),
    dict(id="c12", text="水素なら、話が変わります。浮く力はヘリウムより約8%大きく、17億tの島で年産の1.3年分。", scene=BARS(YEARS_H2, 9000, "17億tの島　世界の生産の何年分か")),
    dict(id="c13", text="ただし、燃えます。", scene=CARD(("ただし", 70, WHITE), ("水素は燃える", 130, RED))),
    dict(id="c14", text="1937年、水素の飛行船ヒンデンブルク号は着陸の時に炎上し、36人が亡くなりました。",
         scene=CARD(("1937年", 120, YEL), ("ヒンデンブルク号", 80, WHITE), ("着陸の時に炎上", 70, WHITE), ("36人が亡くなった", 70, WHITE))),
])

P["s5"] = dict(title="最後の作戦", lines=[
    dict(id="c1", text="雲の中に浮かぶ、天空の城ラピュタ。重さは、作中の画面から見積もって17億t。", scene=ISL(mode="cloud", tags=["17億t"])),
    dict(id="c2", text="島を低い雲の高さ1,000mまで下ろし、横に広い座布団のような袋で吊ってみます。", scene=CUSH(1, tag="高さ1,000mは仮置き")),
    dict(id="c3", text="袋は直径32km、厚さ12km。島は、漏斗のように張ったひもで吊ります。", scene=CUSH(7)),
    dict(id="c4", text="問題は、斜めのひも。", scene=CUSH(2)),
    dict(id="c5", text="袋を内側へ引き寄せる力が、全部で島の重さの約2倍にもなる。", scene=CUSH(4, two=True)),
    dict(id="c6", text="袋の口を閉じて、中の圧力で押し返す。すると、その圧力を閉じ込める帯がとんでもなく重い。", scene=CUSH(6)),
    dict(id="c7", text="計算すると、要るのは同じ重さでケブラーの約2.8倍強い糸。", scene=BARS([S_KEV], 10, S_HEAD, marks=[NEED])),
    dict(id="c8", text="炭素繊維でも、届きません。", scene=BARS([S_KEV, S_CF], 10, S_HEAD, marks=[NEED], grow=[1])),
    dict(id="c9", text="届くのは、実験室のカーボンナノチューブの束。", scene=BARS([S_KEV, S_CF, S_CNTB], 10, S_HEAD, marks=[NEED], grow=[2])),
    dict(id="c10", text="密度を1.3とすれば、同じ重さでケブラーの約26倍です。",
         scene=BARS([("ケブラー", 1, "1", AMBER), ("ナノチューブの束", 25.7, "約26倍", GRN)], 28, "同じ重さでの強さ（ケブラーを1）", tag="密度は仮置き")),
    dict(id="c11", text="膜と帯とひもを全部積んでも、島の7%ほど。水素は、世界の年産の14年分。", scene=BARS(WT_ROWS, 18.5, "浮かせる重さの内訳", note="膜・帯・ひもは島の約7%　水素は年産の14年分", ncol=GRN)),
    dict(id="c12", text="計算の上では、浮きます。", scene=MARK("○", ("計算の上では、浮く", 80, WHITE))),
    dict(id="c13", text="ただし、その強さは長さ数cmの試料の値。長い糸にした例は、まだ報告されていません。",
         scene=CARD(("ただし", 60, WHITE), ("長さ数cmの試料の値", 90, YEL), ("長い糸にした例は", 64, WHITE), ("まだ報告されていない", 64, WHITE))),
])


# 読みの直し(kana の出力を全行見て、違う所だけ)。長い語から順に置き換えて say を作る(字幕は台本のまま)
YOMI = [
    ("空想科学研究所", "くうそうかがくけんきゅうしょ"), ("柳田理科雄", "ヤナギタ・リカオ"), ("岡田さん", "オカダさん"),
    ("花崗岩", "かこうがん"), ("凧の操縦席", "たこのそうじゅうせき"),
    ("アメリカ地質調査所", "アメリカちしつちょうさしょ"), ("MRI", "エムアールアイ"),
    ("ヒンデンブルク号", "ヒンデンブルクごう"), ("T1100G と", "ティーいちいちまるまるジーと"), ("T1100G", "ティーいちいちまるまるジー"),
    ("天空の城ラピュタ", "天空の城、ラピュタ"), ("ひもと帯と膜", "ひもと、おびと、膜"), ("ひもと袋の群れ", "ひもと、ふくろのむれ"),
    ("そのぶん袋を", "そのぶん、袋を"), ("試料での値", "試料でのあたい"), ("試料の値", "試料のあたい"), ("真ん中の値", "真ん中のあたい"),
    ("4.8km上に", "4.8kmうえに"), ("約19分の1", "やくじゅうきゅうぶんのいち"), ("40分の1", "よんじゅうぶんのいち"), ("3分の1", "さんぶんのいち"),
    ("97人", "きゅうじゅうななにん"), ("℃", "度"),
    ("〜", "から"),
]


def yomi(text):
    s = text
    for a, b in YOMI:
        s = s.replace(a, b)
    s = re.sub(r"([\d億万兆])t(?![a-zA-Z])", r"\1トン", s)     # 2.65t・17億t の t は「トン」
    s = re.sub(r"(\d)g(?![a-zA-Z])", r"\1グラム", s)           # 10g は「じゅうジー」と読まれる
    return s


def ep_for(name: str) -> dict:
    p = dict(P[name])
    res = []
    for l in p["lines"]:
        y = yomi(l["text"])
        res.append(dict(l, say=y) if y != l["text"] else l)
    p["lines"] = res
    return dict(kind="sim", aspect="portrait" if name.startswith("s") else "landscape", credit=CREDIT_V if name.startswith("s") else CREDIT, **p)
