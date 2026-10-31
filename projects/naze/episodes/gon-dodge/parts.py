"""ゴンのドッジボールの一球。本編 8 章とショート 5 本の台本と画面。ch1〜ch8・s1〜s5 の ep.py がここから読む。
台本は scripts.md の10版(2026-11-01 ユーザー OK)。語りの文は変えない。［］は画面の指示 → scene、（読み: ）→ YOMI。
作品の絵・キャラクターの絵・音声・台詞は使わない(作品名は文字の札だけ)。人は記号の丸と棒人間。図は scene.py が全部コードで描く。
出典(数字は sim/calc.txt・sim/deep.txt・sim/punch_mj.txt と research.md):
  モルテン「ドッジボール5000 軽量」約330g(メーカー公式)/ Fleisig ほか 2017 Sports Health 9(3)(重い球の投球)/
  Walilko, Viano & Bir 2005 BJSM 39(10)(五輪ボクサーの拳 秒速9.14m・有効質量2.9kg・パンチ力3,427N)/
  Guo & Li ISBS 会議録(バレーの最速スパイク)/ MLB 最速 105.8mph(チャップマン 2010)/ EHF EURO 2026 最速 134.1km/h(KINEXON)/
  Burkhart ほか 2012 J Orthop Res 30(6) ほか献体の実験(橈骨 1.6〜3.4kN)/ FIVB 競技規則(バレーボールの内圧 0.30〜0.325kg/cm²)/
  単純な視覚の反応の時間 約0.18〜0.21秒 / 衝突は MuJoCo 3.17 と式で32通り一致(punch_mj.py)/ 空気の抵抗・レイリーの式・熱の流れの式は deep.py。
  選手の体重100〜150kg・摩擦0.5〜0.8・場の外まで0.5〜3m・10m・抗力係数0.92・つぶれ10cm・ゴンの床の摩擦0.6は仮置き。
"""

CREDIT = "実験の論文・公式記録と自分の計算（置いた値は仮置き）"
CREDIT_V = "論文・公式記録と自分の計算（仮置きあり）"

GREEN, YEL, RED, WHITE, DIM, BLUE, ORANGE = "green", "yel", "red", "white", "dim", "blue", "orange"


def CARD(*rows):
    return dict(kind="formula", rows=list(rows))


def K(kind, **kw):
    return dict(kind=kind, **kw)


def PLACE(*rows):
    return CARD(("仮置き", 120, RED), *[(r, 60, WHITE) for r in rows])


TITLE = CARD(("漫画『HUNTER×HUNTER』", 84, WHITE), ("グリードアイランド編", 66, DIM), ("ドッジボールの試合", 100, YEL))
TITLE_S = CARD(("漫画『HUNTER×HUNTER』", 76, WHITE), ("ドッジボールの試合", 96, YEL))
THIRD = CARD(("3度目の一球", 140, YEL), ("とびきり力をためた一撃", 66, WHITE))
C_HOLD = K("court", mode="hold")
C_FIST = K("court", mode="fist")
C_FLY = K("court", mode="fly")
C_GHOST = K("court", mode="ghost")
C_NOCATCH = K("court", mode="nocatch")
C_CHARGE = K("court", mode="charge")
PUNCH_29 = K("punch", M=2.9, e=0.8, ball_txt="球　時速44〜53km")
PUNCH_INF = K("punch", M=None, e=0.8, ball_txt="球　時速49〜59km", head="体重を全部乗せても　時速60kmに届かない", hcol=(255, 214, 64))
CAP0 = K("cap", st=0)
CAP1 = K("cap", st=1)
FISTCMP = K("bars", rows=[("五輪ボクサーの拳", 9.14, "秒速9.14m", (190, 195, 205)), ("投手の手", 34.2, "秒速34m（拳の3.7倍）", (110, 220, 140))],
            vmax=40, head="手から離れる速さ")
SWING = CARD(("腕を振る", 120, GREEN), ("か", 60, WHITE), ("まっすぐ突く", 120, RED))
P = {}

P["ch1"] = dict(title="第1章 拳で打った一球", cta=False, lines=[
    dict(id="c1", text="『HUNTER×HUNTER』のグリードアイランド編に、ドッジボールの試合があります。", scene=TITLE),
    dict(id="c2", text="この試合で、ゴンは球を投げません。拳で殴って、飛ばします。", scene=C_FIST),
    dict(id="c3", text="仲間に球を持ってもらって、力をためて、ドン。", scene=K("court", mode="hold", launch=True)),
    dict(id="c4", text="なかでも3度目の一球は、とびきり力をためた一撃でした。", scene=THIRD),
    dict(id="c5", text="ところが、相手チームの中心の選手は、この球を捕りにいきませんでした。", scene=C_FLY),
    dict(id="c6", text="捕れば、自分の体ごと場の外へ押し出される。そう見て、打ち返しました。", scene=C_GHOST),
    dict(id="c7", text="飛んできた球を、捕らない。ドッジボールでは、まずない選び方です。", scene=CARD(("飛んできた球を", 72, WHITE), ("捕らない", 150, RED), ("ドッジボールでは　まずない選び方", 56, DIM))),
    dict(id="c8", text="作中に、球の速さを示す数字は出てきません。", scene=CARD(("作中に", 70, WHITE), ("球の速さの数字は", 84, WHITE), ("出てこない", 120, YEL))),
    dict(id="c9", text="では、あの一球は、どれほどの速さだったのか。", scene=CARD(("あの一球は", 84, WHITE), ("どれほどの速さだったのか", 100, YEL))),
    dict(id="c10", text="手がかりは、この「捕らなかった」という判断、ひとつだけ。", scene=CARD(("手がかりは　ひとつだけ", 70, WHITE), ("「捕らなかった」という判断", 92, YEL))),
    dict(id="c11", text="測った記録と計算でたどっていくと、拳で打ったとは思えない数字が出てきます。",
         scene=CARD(("測った記録　と　計算", 80, WHITE), ("拳で打ったとは", 96, YEL), ("思えない数字", 110, YEL))),
])

P["ch2"] = dict(title="第2章 捕らなかった理由", cta=False, lines=[
    dict(id="c1", text="捕れば押し出される。これは、運動量の話です。", scene=CARD(("捕れば押し出される", 72, WHITE), ("運動量", 170, YEL))),
    dict(id="c2", text="運動量は、重さと速さを掛けたもの。ぶつかる勢い、と思ってください。",
         scene=CARD(("運動量", 100, YEL), ("＝　重さ　×　速さ", 110, WHITE), ("ぶつかる勢い", 64, DIM))),
    dict(id="c3", text="台車に乗った人が、飛んできたボールを捕る。", scene=K("cart", st=0)),
    dict(id="c4", text="軽い球でも、捕った瞬間、人と台車はすっと動き出します。", scene=K("cart", st=1)),
    dict(id="c5", text="球の勢いが、そっくり人に移るからです。", scene=K("cart", st=2)),
    dict(id="c6", text="移る前と後で、勢いの合計は変わりません。"),
    dict(id="c7", text="床に立っていれば、その勢いは、足で踏んばって受け止めるしかない。", scene=K("floor", mode="stand")),
    dict(id="c8", text="ただ、踏んばれる力には上限があります。", scene=K("floor", mode="box")),
    dict(id="c9", text="重い家具を押すと、ある所まではびくともしないのに、越えたとたん、ずるっと滑る。"),
    dict(id="c10", text="あの境目です。重さと、床の滑りにくさで決まります。",
         scene=CARD(("踏んばれる力の上限", 84, YEL), ("＝ 摩擦 × 重さ × 重力", 96, WHITE), ("重さと　床の滑りにくさで決まる", 56, DIM))),
    dict(id="c11", text="滑った先が線の外なら、アウト。捕ったのに外へ出たら、捕った意味がありません。", scene=K("floor", mode="out")),
    dict(id="c12", text="相手の選手は、120kgほどの大きな体としておきます。",
         scene=PLACE("相手の選手の体重　100〜150kg", "場の外まで　0.5〜3m", "床の摩擦　0.5〜0.8", "球　330g")),
    dict(id="c13", text="ここからは、真ん中の見積りで話します。",
         scene=CARD(("置いた値の真ん中", 120, YEL), ("体重120kg・場の外まで1.5m・摩擦0.6", 56, WHITE))),
    dict(id="c14", text="120kgの体が床で踏んばれるのは、72kgの物を支えるくらいの力。",
         scene=CARD(("踏んばれる力の上限", 70, WHITE), ("708N", 180, YEL), ("72kgの物を支えるくらい", 64, DIM))),
    dict(id="c15", text="そのブレーキで、線の手前で止まりきれるのは、時速15kmまで。", scene=K("floor", mode="stop")),
    dict(id="c16", text="軽く走るくらいの速さですね。"),
    dict(id="c17", text="一方の球は、330g。選手と合わせた重さの、およそ365分の1しかありません。", scene=K("grid", n=365)),
    dict(id="c18", text="勢いの合計は、変わらない。", scene=CARD(("勢いの合計は", 84, WHITE), ("変わらない", 140, YEL), ("m v ＝ (M＋m) V", 80, WHITE))),
    dict(id="c19", text="だから球は、その365倍の速さで来ないと、選手を外まで運べません。",
         scene=CARD(("球の速さ", 72, WHITE), ("時速15km　×　365", 120, YEL), ("選手を外まで運ぶ　最低の速さ", 56, DIM))),
    dict(id="c20", text="時速15kmの、365倍。掛け算すると……。", scene=CARD(("時速15km", 110, WHITE), ("×　365　＝　？", 150, YEL))),
])

SPEED1, SPEED2, SPEED3 = K("speed", st=1), K("speed", st=2), K("speed", st=3)

P["ch3"] = dict(title="第3章 一球の速さ", cta=False, lines=[
    dict(id="c1", text="少なくとも、時速5,500km。", scene=CARD(("少なくとも", 84, WHITE), ("時速5,500km", 190, YEL), ("置いた値の真ん中", 60, DIM))),
    dict(id="c2", text="野球の最速が、時速170kmほど。その30倍を超えています。", scene=SPEED1),
    dict(id="c3", text="音の速さで言えば、4倍以上。", scene=SPEED2),
    dict(id="c4", text="いちばん控えめに見ても、少なくとも時速2,420kmです。", scene=SPEED3),
    dict(id="c5", text="どれも、これより遅ければ捕って止まれた、という最低の速さです。",
         scene=CARD(("どれも", 70, WHITE), ("これより遅ければ　捕って止まれた", 76, WHITE), ("最低の速さ", 130, YEL))),
    dict(id="c6", text="しかも、ここまでは空気の抵抗を入れていません。", scene=CARD(("ここまでは", 76, WHITE), ("空気の抵抗なし", 130, YEL))),
    dict(id="c7", text="車の窓から手を出すと、スピードが上がるほど、ぐっと強く押し戻されますよね。", scene=K("wind")),
    dict(id="c8", text="空気の抵抗は、速さの2乗で効きます。速さが2倍なら、4倍。",
         scene=CARD(("抵抗 ＝ ½ × 空気の密度 × 抗力係数 × 断面 × 速さ²", 56, WHITE), ("速さ2倍　→　抵抗4倍", 110, YEL))),
    dict(id="c9", text="打った所から相手まで、10mほどとして計算します。", scene=PLACE("打った所から相手まで　10m", "抗力係数　0.92（目安0.9〜1.0）")),
    dict(id="c10", text="たった10m飛ぶあいだに、速さは半分ほどまで落ちてしまう。", scene=K("decay", st=1)),
    dict(id="c11", text="相手の所で時速5,500kmを残すには。", scene=K("decay", st=2)),
    dict(id="c12", text="打った瞬間は、少なくとも時速9,900km。", scene=K("decay", st=3)),
    dict(id="c13", text="音の8倍です。", scene=CARD(("時速9,900km", 130, YEL), ("音の8倍", 150, WHITE))),
    dict(id="c14", text="……ちょっと待ってください。そんな速さで、球のほうはもつのか。", scene=CARD(("そんな速さで", 84, WHITE), ("球は　もつのか", 140, YEL))),
    dict(id="c15", text="音より速い球の前では、空気が逃げきれずに押し固められます。", scene=K("shock", st=0)),
    dict(id="c16", text="球の正面にかかる空気は、86気圧。", scene=K("shock", st=1)),
    dict(id="c17", text="バレーボールの中の空気は、まわりより0.3気圧ほど高いだけ。", scene=K("press", st=0)),
    dict(id="c18", text="その、およそ270倍の力で押されている。ふつうの球なら、正面からぺしゃんこです。", scene=K("press", st=1)),
    dict(id="c19", text="熱もたまります。せき止められた空気が、球の正面を焼くからです。", scene=K("heat", st=0)),
    dict(id="c20", text="表面が、ゴムに近い材料だとすると。", scene=PLACE("表面の材料", "ゴムに近い値")),
    dict(id="c21", text="届くまでのわずか0.005秒で、表面は600℃を超えます。", scene=K("heat", st=1)),
    dict(id="c22", text="ゴムなら、もう熱で傷み始めている温度です。", scene=K("heat", st=2)),
    dict(id="c23", text="それでも作中の球は、そのまま打ち返されます。", scene=CARD(("それでも　作中の球は", 76, WHITE), ("そのまま打ち返される", 110, YEL))),
    dict(id="c24", text="そして、この速さだと、もう1つおかしなことが起きます。", scene=CARD(("この速さだと", 84, WHITE), ("もう1つ　おかしなことが起きる", 84, YEL))),
])

P["ch4"] = dict(title="第4章 見てから、では間に合わない", cta=False, lines=[
    dict(id="c1", text="球が、相手まで10mを飛ぶ時間です。", scene=K("time", st=0)),
    dict(id="c2", text="長くても、0.0049秒。", scene=K("time", st=1, grow=True)),
    dict(id="c3", text="まばたき1回より、ずっと短い。", scene=CARD(("まばたき1回より", 90, WHITE), ("ずっと短い", 150, YEL))),
    dict(id="c4", text="人が光を見てから体が動き出すまでには、測ると、およそ0.2秒かかります。", scene=K("time", st=2, grow=True)),
    dict(id="c5", text="球が届くのは、その41分の1より短い時間。", scene=K("time", st=3)),
    dict(id="c6", text="いちばん控えめに見ても、反応の18分の1より短い。", scene=K("time", st=4, grow=True)),
    dict(id="c7", text="打たれてから球を見て、捕るか、やめるかを決める。", scene=CARD(("打たれてから　球を見て", 76, WHITE), ("捕るか　やめるか　決める", 100, YEL))),
    dict(id="c8", text="その時間は、計算の上では、どこにもありません。", scene=K("time", st=5)),
    dict(id="c9", text="決められるとしたら、球が飛ぶ前。", scene=CARD(("決められるとしたら", 80, WHITE), ("球が飛ぶ前", 150, YEL))),
    dict(id="c10", text="拳に力をためていくゴンを、見ているあいだだけです。", scene=C_CHARGE),
    dict(id="c11", text="しかも、音より速い球は、通り道に衝撃波を残します。", scene=K("shock", st=2)),
    dict(id="c12", text="コートには、ドンと、破裂のような音が響く速さです。", scene=K("shock", st=3)),
    dict(id="c13", text="……でも、思い出してください。この球、投げた球じゃない。拳で打った球です。",
         scene=CARD(("この球", 84, WHITE), ("投げた球じゃない", 100, WHITE), ("拳で打った球", 140, YEL))),
    dict(id="c14", text="拳で打つと、球はどこまで速くなるのか。現実の人間で確かめてみます。",
         scene=CARD(("拳で打つと", 84, WHITE), ("球はどこまで速くなる？", 100, YEL), ("現実の人間で確かめる", 60, DIM))),
])

P["ch5"] = dict(title="第5章 人間はこの一球を出せるか", cta=False, lines=[
    dict(id="c1", text="まずは拳。五輪ボクサー7人のパンチを測った実験があります。", scene=CARD(("五輪ボクサー", 130, YEL), ("7人のパンチを測った実験", 72, WHITE))),
    dict(id="c2", text="拳の速さは、平均で時速33km。", scene=CARD(("拳の速さ　平均", 72, WHITE), ("時速33km", 170, YEL), ("秒速9.14m", 76, DIM))),
    dict(id="c3", text="この拳で、330gのドッジボールを正面から打つと。", scene=K("punch", M=2.9, e=0.8, ball_txt="球　？")),
    dict(id="c4", text="ボールは、時速50kmほど。", scene=PUNCH_29),
    dict(id="c5", text="自転車で坂を下るくらい。拍子抜けするほど遅い。", scene=CARD(("自転車で坂を下るくらい", 76, WHITE), ("拍子抜けするほど遅い", 100, YEL))),
    dict(id="c6", text="普通は、体重を乗せればもっと速くなるはず。", scene=CARD(("普通は", 76, WHITE), ("体重を乗せれば", 100, YEL), ("もっと速くなるはず", 100, YEL))),
    dict(id="c7", text="ところが、全部乗せても、時速60kmに届きません。", scene=PUNCH_INF),
    dict(id="c8", text="球は、拳の速さの1.8倍で頭打ちになります。はね返りを0.8までとした場合です。", scene=CAP0),
    dict(id="c9", text="重い拳は、動く壁みたいなもの。壁ではね返った球は、壁の速さの2倍を超えられない。", scene=CAP1),
    dict(id="c10", text="効くのは拳の重さではなく、拳の速さ。ぶつかる式は、動きの計算でも確かめました。", scene=K("table")),
    dict(id="c11", text="では、投げたらどうか。", scene=CARD(("では", 80, WHITE), ("投げたら　どうか", 150, YEL))),
    dict(id="c12", text="高校と大学の投手25人に、重さの違う球を投げてもらった実験があります。", scene=K("pitch", st=0)),
    dict(id="c13", text="重い球ほど遅くなる。その傾きをたどって、330gまで伸ばします。", scene=K("pitch", st=1)),
    dict(id="c14", text="測った重さの外なので、ここは式の延長です。", scene=CARD(("式の延長", 150, RED), ("測った重さ（113〜198g）の外", 70, WHITE))),
    dict(id="c15", text="結果は、時速100kmほど。拳の倍です。", scene=K("pitch", st=2)),
    dict(id="c16", text="投手の球は、手から秒速34mで離れていきます。拳の3.7倍の速さで、手が振り抜かれている。", scene=FISTCMP),
    dict(id="c17", text="差は、腕を振るか、まっすぐ突くか。拳は、球を飛ばすには遅い打ち方です。", scene=SWING),
    dict(id="c18", text="だからこそ、ゴンの一球は異常です。遅いはずの打ち方で、あの数字を出している。",
         scene=CARD(("だからこそ", 76, WHITE), ("ゴンの一球は　異常", 120, YEL), ("遅いはずの打ち方で　あの数字", 64, WHITE))),
    dict(id="c19", text="では、腕を振る人たちなら、どこまで迫れるのか。", scene=CARD(("腕を振る人たちなら", 84, WHITE), ("どこまで迫れる？", 120, YEL))),
])

P["ch6"] = dict(title="第6章 人間チームの挑戦", cta=False, lines=[
    dict(id="c1", text="人間チーム、挑みます。", scene=CARD(("人間チーム", 160, YEL), ("挑みます", 100, WHITE))),
    dict(id="c2", text="目標は、いちばん控えめに見たゴンの一球。時速2,420km。",
         scene=CARD(("目標", 90, WHITE), ("時速2,420km", 170, YEL), ("いちばん控えめに見たゴンの一球", 60, DIM))),
    dict(id="c3", text="まずは、おさらい。拳で打って53km。", scene=K("human", n=1)),
    dict(id="c4", text="いちばん速い拳の人が、体重を全部乗せても86km。", scene=K("human", n=2)),
    dict(id="c5", text="投手が投げて、102km。", scene=K("human", n=3)),
    dict(id="c6", text="3人目は、腕を振って打つ、バレーのスパイク。この球に直して110km。投手を抜きました。", scene=K("human", n=4)),
    dict(id="c7", text="やっぱり、腕を振ると速い。"),
    dict(id="c8", text="4人目は、メジャーリーグの最速、時速170.3km。", scene=K("human", n=5, raw=4)),
    dict(id="c9", text="ついに150kmを越えた……と思いきや。"),
    dict(id="c10", text="野球の球は145gと軽い。この球の重さに直すと、141kmまで落ちてしまいます。", scene=K("human", n=5, fix=4)),
    dict(id="c11", text="最後はハンドボール。欧州選手権の最速、450gの球で時速134.1km。", scene=K("human", n=6, raw=5)),
    dict(id="c12", text="この球に直すと147km。これが、人間チームの最高記録です。", scene=K("human", n=6, fix=5)),
    dict(id="c13", text="それでも、150kmには届きません。", scene=K("human", n=6, band=True, grow=False, head="それでも　150kmに届かない")),
    dict(id="c14", text="人間の限界の上の端、150kmで割ってみると。", scene=CARD(("人間の限界の上の端", 76, WHITE), ("時速150km", 150, YEL), ("で割る", 76, WHITE))),
    dict(id="c15", text="ゴンの一球は、少なくとも16倍。", scene=CARD(("ゴンの一球は", 84, WHITE), ("少なくとも16倍", 150, YEL), ("2,420 ÷ 150", 64, DIM))),
    dict(id="c16", text="真ん中の見積りなら、少なくとも36倍。", scene=CARD(("真ん中の見積りなら", 80, WHITE), ("少なくとも36倍", 150, YEL), ("5,500 ÷ 150", 64, DIM))),
    dict(id="c17", text="人間チーム、完敗です。", scene=CARD(("人間チーム", 110, WHITE), ("完敗", 200, RED))),
    dict(id="c18", text="棒グラフに並べると、ゴンの一球は、画面に収まりません。", scene=K("human", n=6, band=True, gon=True, head="棒グラフに並べると")),
    dict(id="c19", text="では、もし相手の選手が、あの球を捕っていたら。", scene=CARD(("もし相手の選手が", 80, WHITE), ("あの球を捕っていたら", 110, YEL))),
])

ARM30, ARM10 = K("arm", hl=30), K("arm", hl=10)
BONE0, BONE1 = K("bone", st=0), K("bone", st=1)
CMP560 = K("bars", rows=[("橈骨が折れる力（真ん中）", 2.3, "2.3kN", (190, 195, 205)), ("ゴンの一球を30cmで止める", 1291, "約1,290kN", (240, 90, 80))],
           vmax=1300, head="平均の力（真ん中の見積り）", foot="橈骨が折れる力の　およそ560倍")

P["ch7"] = dict(title="第7章 捕っていたら", cta=False, lines=[
    dict(id="c1", text="その前に、人間の限界、時速150kmの球を受けてみます。", scene=CARD(("その前に", 76, WHITE), ("人間の限界", 110, YEL), ("時速150kmの球を受ける", 84, WHITE))),
    dict(id="c2", text="腕を30cm引きながら止めると、止めるあいだの平均の力は、約1キロニュートン。", scene=ARM30),
    dict(id="c3", text="100kgの物を、支えるくらいです。", scene=CARD(("約1kN", 170, YEL), ("100kgの物を支えるくらい", 76, WHITE))),
    dict(id="c4", text="比べるのは、橈骨。手首の親指側にある、腕の骨です。", scene=BONE0),
    dict(id="c5", text="献体の実験では、1.6から3.4キロニュートンで折れました。", scene=BONE1),
    dict(id="c6", text="平均で見れば、折れる力より下。", scene=K("fbar", st=0)),
    dict(id="c7", text="ただ、腕をあまり引かずに10cmで止めると、平均の力は2.9キロニュートン。", scene=ARM10),
    dict(id="c8", text="手首1本で受けたら、折れる力に届く計算です。", scene=K("fbar", st=1, grow_st=1)),
    dict(id="c9", text="10cmで止めるより、30cm引けば、力は3分の1。", scene=CARD(("10cmで止める　→　30cm引く", 76, WHITE), ("力は　3分の1", 150, YEL))),
    dict(id="c10", text="では、ゴンの一球を。真ん中の見積りで、相手の所で少なくとも時速5,500km。",
         scene=CARD(("ゴンの一球", 84, WHITE), ("少なくとも時速5,500km", 120, YEL), ("真ん中の見積り・相手の所", 60, DIM))),
    dict(id="c11", text="これだけ速ければ、捕った選手は、1秒たたずに線の外まで滑っていきます。", scene=K("slide")),
    dict(id="c12", text="同じように30cm引いて止めたとしても、平均の力は、130トンの物を支えるほど。",
         scene=CARD(("30cm引いて止めても", 76, WHITE), ("約1,290kN", 160, YEL), ("130トンの物を支えるほど", 70, WHITE))),
    dict(id="c13", text="橈骨が折れる力の、およそ560倍。", scene=CMP560),
    dict(id="c14", text="しかも、0.0004秒で30cm引くなんて、まず無理です。実際の力は、もっと大きくなります。",
         scene=CARD(("0.0004秒で　30cm引く", 84, WHITE), ("まず無理", 150, RED), ("実際の力は　もっと大きい", 64, DIM))),
    dict(id="c15", text="捕っていたら、手は、ひとたまりもない。", scene=CARD(("捕っていたら", 84, WHITE), ("手は　ひとたまりもない", 110, RED))),
    dict(id="c16", text="捕れば外へ出る。あの読みは、計算でも当たっていました。", scene=CARD(("捕れば外へ出る", 110, YEL), ("あの読みは　計算でも当たっていた", 70, WHITE))),
    dict(id="c17", text="残る謎は、1つ。この一球を打った、拳のほうです。", scene=CARD(("残る謎は　1つ", 84, WHITE), ("この一球を打った", 84, WHITE), ("拳のほう", 150, YEL))),
])

FIST1, FIST2 = K("fist", st=1), K("fist", st=2)

P["ch8"] = dict(title="第8章 音より速い拳", lines=[
    dict(id="c1", text="拳で打った球は、拳の速さの1.8倍で頭打ち。はね返りを0.8までとした場合でした。", scene=K("cap", st=0)),
    dict(id="c2", text="ということは、あの一球を出すには、拳そのものが速くないといけない。",
         scene=CARD(("あの一球を出すには", 84, WHITE), ("拳そのものが", 110, YEL), ("速くないといけない", 100, YEL))),
    dict(id="c3", text="空気の抵抗を入れず、いちばん控えめに見ても、ゴンの拳は少なくとも秒速370m。", scene=FIST1),
    dict(id="c4", text="音より速い拳です。"),
    dict(id="c5", text="ここからは、いちばん控えめな見積りに、空気の抵抗も入れて話します。", scene=CARD(("ここからは", 76, WHITE), ("控えめ・空気あり", 130, YEL))),
    dict(id="c6", text="このとき、打った瞬間の球は、時速4,300km以上。", scene=CARD(("打った瞬間の球", 80, WHITE), ("時速4,300km以上", 150, YEL))),
    dict(id="c7", text="拳は、少なくとも秒速670m。", scene=FIST2),
    dict(id="c8", text="音の、ほぼ2倍。五輪ボクサーの拳の、70倍を超えます。"),
    dict(id="c9", text="拳が当たった瞬間、球はばねのように押しつぶされて、はね返ります。", scene=K("squash", st=0)),
    dict(id="c10", text="いちばん深くつぶれて、10cmとしておきます。", scene=K("squash", st=1)),
    dict(id="c11", text="拳が球を押しつけているのは、0.0005秒ほど。", scene=K("squash", st=2)),
    dict(id="c12", text="そのわずかなあいだ、拳が受ける力は、平均で約90トン。", scene=K("squash", st=3)),
    dict(id="c13", text="五輪ボクサーのパンチの力の、約250倍。",
         scene=K("bars", rows=[("五輪ボクサーのパンチの力", 3427, "3,427N", (190, 195, 205)), ("ゴンの拳が受ける力", 860000, "約0.86MN（約90トン）", (240, 90, 80))],
                 vmax=880000, head="平均の力", foot="約250倍")),
    dict(id="c14", text="人間の拳なら、骨がもちません。", scene=CARD(("人間の拳なら", 90, WHITE), ("骨がもたない", 150, RED))),
    dict(id="c15", text="打った反動も、ゴンの体に返ってきます。", scene=K("recoil", st=0)),
    dict(id="c16", text="球に渡した勢いと同じだけ、後ろへ押し戻される。", scene=K("recoil", st=1)),
    dict(id="c17", text="49kgの体に、時速29kmの勢い。", scene=K("recoil", st=2)),
    dict(id="c18", text="床の摩擦だけで受けたら、5m以上滑る計算です。", scene=K("recoil", st=3)),
    dict(id="c19", text="あの3度目の一球を、もう一度、頭の中で再生してみます。", scene=THIRD),
    dict(id="c20", text="仲間が支えた球に、ゴンが拳を叩き込む。", scene=K("court", mode="hold", launch=True)),
    dict(id="c21", text="相手の中心の選手は、捕らずに打ち返した。", scene=C_NOCATCH),
    dict(id="c22", text="その球を送り出したのは、音より速い拳でした。", scene=CARD(("その球を送り出したのは", 80, WHITE), ("音より速い拳", 150, YEL))),
    dict(id="c23", text="捕らなかったのも、無理はありません。", scene=CARD(("捕らなかったのも", 84, WHITE), ("無理はない", 150, YEL))),
    dict(id="c24", text="投げるより遅いはずの、拳の一撃で。", scene=CARD(("投げるより遅いはずの", 84, WHITE), ("拳の一撃で", 150, YEL))),
    dict(id="c25", text="相手の所の速さでも、人間の限界の少なくとも16倍。", scene=CARD(("相手の所の速さでも", 76, WHITE), ("人間の限界の", 84, WHITE), ("少なくとも16倍", 150, YEL))),
    dict(id="c26", text="次にドッジボールを受けるときは、腕を引いてください。", scene=ARM30),
    dict(id="c27", text="人間の球なら、それで間に合います。", scene=CARD(("人間の球なら", 90, WHITE), ("それで間に合う", 140, YEL))),
])

# ---- ショート ----------------------------------------------------------------------------------
P["s1"] = dict(title="拳で打つ球は遅い", lines=[
    dict(id="c1", text="『HUNTER×HUNTER』のドッジボール。", scene=TITLE_S),
    dict(id="c2", text="ゴンは、球を投げずに、拳で殴って飛ばします。", scene=C_FIST),
    dict(id="c3", text="でも現実では、拳で打った球は、拍子抜けするほど遅い。", scene=CARD(("でも現実では", 76, WHITE), ("拳で打った球は", 90, WHITE), ("拍子抜けするほど遅い", 96, YEL))),
    dict(id="c4", text="五輪ボクサー7人の測定では、拳の速さは平均で時速33km。", scene=CARD(("五輪ボクサー7人の測定", 70, WHITE), ("拳の速さ　平均", 70, WHITE), ("時速33km", 160, YEL))),
    dict(id="c5", text="この拳で330gのドッジボールを打つと、時速50kmほど。", scene=PUNCH_29),
    dict(id="c6", text="体重を全部乗せても、時速60kmに届きません。", scene=PUNCH_INF),
    dict(id="c7", text="球は、拳の速さの1.8倍で頭打ちになるからです。", scene=CAP0),
    dict(id="c8", text="一方、高校と大学の投手が投げると、時速100kmほど。", scene=K("pitch", st=2)),
    dict(id="c9", text="330gは測った重さの外なので、ここは式の延長です。", scene=CARD(("式の延長", 150, RED), ("測った重さ（113〜198g）の外", 64, WHITE))),
    dict(id="c10", text="投手の手は、秒速34mで振り抜かれている。拳の3.7倍です。", scene=FISTCMP),
    dict(id="c11", text="差は、腕を振るか、まっすぐ突くか。", scene=SWING),
    dict(id="c12", text="拳は、球を飛ばすには遅い打ち方。", scene=CARD(("拳は", 90, WHITE), ("球を飛ばすには", 90, WHITE), ("遅い打ち方", 140, RED))),
    dict(id="c13", text="それなのにゴンの一球は、相手を場の外へ追いやりかけました。", scene=C_GHOST),
])

P["s2"] = dict(title="あの一球の速さ", lines=[
    dict(id="c1", text="『HUNTER×HUNTER』のドッジボール。ゴンが拳で打った、3度目の一球。", scene=TITLE_S),
    dict(id="c2", text="相手の中心の選手は、これを捕らずに打ち返しました。", scene=C_NOCATCH),
    dict(id="c3", text="捕れば、体ごと場の外へ押し出される。そう見たからです。", scene=C_GHOST),
    dict(id="c4", text="捕ると、球の勢い、運動量がまるごと選手に移ります。", scene=K("cart", st=2)),
    dict(id="c5", text="でも床で踏んばれる力には、体重と床の滑りにくさで決まる上限がある。", scene=K("floor", mode="box")),
    dict(id="c6", text="相手は、120kgほどの大きな体としておきます。", scene=PLACE("相手の体重　100〜150kg", "場の外まで　0.5〜3m", "床の摩擦　0.5〜0.8", "球　330g")),
    dict(id="c7", text="線の外まで1.5mほどなら、止まりきれるのは時速15kmまで。", scene=K("floor", mode="stop")),
    dict(id="c8", text="330gの球でそれを超えさせるには、その365倍の速さが要ります。", scene=K("grid", n=365)),
    dict(id="c9", text="少なくとも、時速5,500km。", scene=CARD(("少なくとも", 84, WHITE), ("時速5,500km", 170, YEL), ("置いた値の真ん中", 60, DIM))),
    dict(id="c10", text="野球の最速の、30倍を超えます。", scene=SPEED1),
    dict(id="c11", text="いちばん控えめに見ても、少なくとも2,420km。", scene=SPEED3),
    dict(id="c12", text="これより遅ければ、捕って止まれた。そういう、最低の速さです。", scene=CARD(("これより遅ければ", 80, WHITE), ("捕って止まれた", 100, WHITE), ("最低の速さ", 140, YEL))),
])

P["s3"] = dict(title="見てから、では間に合わない", lines=[
    dict(id="c1", text="『HUNTER×HUNTER』のドッジボール。", scene=TITLE_S),
    dict(id="c2", text="ゴンが拳で打った一球を、相手の中心の選手は捕りませんでした。", scene=C_NOCATCH),
    dict(id="c3", text="捕れば、場の外へ押し出される。そう見たからです。", scene=C_GHOST),
    dict(id="c4", text="その判断から逆算すると、球は相手の所で、少なくとも時速5,500km。",
         scene=CARD(("その判断から逆算", 76, WHITE), ("少なくとも", 76, WHITE), ("時速5,500km", 160, YEL), ("置いた値の真ん中", 56, DIM))),
    dict(id="c5", text="空気の抵抗も入れて、10m先まで飛ぶ時間を数えます。", scene=PLACE("打った所から相手まで　10m", "空気の抵抗も入れる")),
    dict(id="c6", text="長くても、0.0049秒。", scene=K("time", st=1, grow=True)),
    dict(id="c7", text="人が光を見てから体が動き出すまでは、およそ0.2秒。", scene=K("time", st=2, grow=True)),
    dict(id="c8", text="球が届くのは、その41分の1より短い時間です。", scene=K("time", st=3)),
    dict(id="c9", text="いちばん控えめに見ても、18分の1より短い。", scene=K("time", st=4, grow=True)),
    dict(id="c10", text="打たれてから球を見て、捕るかどうか決める。", scene=CARD(("打たれてから　球を見て", 70, WHITE), ("捕るかどうか　決める", 96, YEL))),
    dict(id="c11", text="そんな時間は、計算の上では、どこにもありません。", scene=K("time", st=5)),
    dict(id="c12", text="決められるとしたら、球が飛ぶ前。", scene=CARD(("決められるとしたら", 80, WHITE), ("球が飛ぶ前", 150, YEL))),
    dict(id="c13", text="拳に力をためていくゴンを、見ているあいだだけです。", scene=C_CHARGE),
])

P["s4"] = dict(title="捕っていたら", lines=[
    dict(id="c1", text="『HUNTER×HUNTER』のドッジボール。", scene=TITLE_S),
    dict(id="c2", text="ゴンが拳で打った一球を、相手の中心の選手は捕りませんでした。", scene=C_NOCATCH),
    dict(id="c3", text="もし捕っていたら、手はどうなっていたのか。", scene=CARD(("もし捕っていたら", 90, WHITE), ("手は", 90, WHITE), ("どうなっていたのか", 100, YEL))),
    dict(id="c4", text="まず、人間の限界、時速150kmの球から。", scene=CARD(("まず", 76, WHITE), ("人間の限界", 110, YEL), ("時速150kmの球から", 84, WHITE))),
    dict(id="c5", text="腕を30cm引いて止めると、止めるあいだの平均の力は約1キロニュートン。", scene=ARM30),
    dict(id="c6", text="比べるのは、手首の親指側の骨、橈骨。", scene=BONE0),
    dict(id="c7", text="献体の実験では、1.6から3.4キロニュートンで折れました。", scene=BONE1),
    dict(id="c8", text="平均で見れば、折れる力より下です。", scene=K("fbar", st=0)),
    dict(id="c9", text="では、ゴンの一球。真ん中の見積りで、少なくとも時速5,500km。", scene=CARD(("ゴンの一球", 84, WHITE), ("少なくとも", 76, WHITE), ("時速5,500km", 150, YEL), ("真ん中の見積り", 56, DIM))),
    dict(id="c10", text="同じく30cm引いても、平均の力は、130トンの物を支えるほど。", scene=CARD(("同じく30cm引いても", 76, WHITE), ("約1,290kN", 150, YEL), ("130トンの物を支えるほど", 64, WHITE))),
    dict(id="c11", text="橈骨が折れる力の、およそ560倍です。", scene=CMP560),
    dict(id="c12", text="しかも0.0004秒で30cm引くなんて、まず無理。実際の力は、もっと大きくなります。",
         scene=CARD(("0.0004秒で　30cm引く", 76, WHITE), ("まず無理", 150, RED), ("実際の力は　もっと大きい", 60, DIM))),
    dict(id="c13", text="捕れば外へ出る、という読み。計算でも、当たっていました。", scene=CARD(("捕れば外へ出る", 100, YEL), ("という読み", 76, WHITE), ("計算でも　当たっていた", 84, WHITE))),
])

P["s5"] = dict(title="音より速い拳", lines=[
    dict(id="c1", text="『HUNTER×HUNTER』のドッジボール。", scene=TITLE_S),
    dict(id="c2", text="ゴンが拳で打った一球を、相手の中心の選手は捕りませんでした。", scene=C_NOCATCH),
    dict(id="c3", text="捕れば、場の外へ押し出されると見たからです。", scene=C_GHOST),
    dict(id="c4", text="その判断から逆算すると、いちばん控えめに見ても。", scene=CARD(("その判断から逆算", 80, WHITE), ("いちばん控えめに見ても", 90, YEL))),
    dict(id="c5", text="球は、少なくとも時速2,420km。", scene=CARD(("球は　少なくとも", 80, WHITE), ("時速2,420km", 170, YEL))),
    dict(id="c6", text="野球の最速の、14倍を超える球です。", scene=CARD(("野球の最速の", 84, WHITE), ("14倍超", 170, YEL), ("仮置き　球330g", 60, RED))),
    dict(id="c7", text="ところが、拳で打った球は、拳の速さの1.8倍で頭打ちになります。", scene=CAP0),
    dict(id="c8", text="はね返りを、0.8までとした場合です。"),
    dict(id="c9", text="ということは、拳そのものが速くないと、この球は出ない。", scene=CARD(("拳そのものが", 100, YEL), ("速くないと", 100, YEL), ("この球は出ない", 90, WHITE))),
    dict(id="c10", text="ゴンの拳は、少なくとも秒速370m。", scene=FIST1),
    dict(id="c11", text="音より速い拳です。"),
    dict(id="c12", text="旅客機より速く、拳が動いている。", scene=CARD(("旅客機より速く", 110, YEL), ("拳が動いている", 100, WHITE))),
    dict(id="c13", text="五輪ボクサーの拳の、40倍以上。", scene=CARD(("五輪ボクサーの拳の", 80, WHITE), ("40倍以上", 170, YEL), ("秒速370m ÷ 秒速9.14m", 60, DIM))),
    dict(id="c14", text="あの一球は、音より速い拳から送り出されていました。", scene=CARD(("あの一球は", 84, WHITE), ("音より速い拳から", 110, YEL), ("送り出されていた", 90, WHITE))),
])


# 読みの直し(kana の出力を全行見て、違う所だけ)。長い語から順に置き換えて say を作る(字幕は台本のまま)
YOMI = [("『HUNTER×HUNTER』", "はんたーはんたー"), ("HUNTER×HUNTER", "はんたーはんたー"),   # 「かける」と読ませない
        ("ゴンは球を", "ゴンはたまを"),                # 「ゴン ハッキュウ」と続けて読んだ
        ("場の外", "ばのそと"),                        # 「体ごと場の外」を「ジョオノソト」と読んだ
        ("30cm引きながら", "30cmひきながら"),           # 「ビキナガラ」と濁った
        ("引いて止めた", "ひいてとめた"),               # 「ドメタ」と濁った
        ("℃", "度")]                                  # 「ドシイ」と読んだ


def yomi(text):
    import re
    s = text
    for a, b in YOMI:
        s = s.replace(a, b)
    return re.sub(r"(\d)g(?![a-zA-Z])", r"\1グラム", s)    # 330g を「ジイ」と読んだ(kg は声の仕組みがキログラムと読む)


def ep_for(name: str) -> dict:
    p = dict(P[name])
    res = []
    for l in p["lines"]:
        y = yomi(l["text"])
        res.append(dict(l, say=y) if y != l["text"] else l)
    p["lines"] = res
    short = name.startswith("s")
    return dict(kind="sim", aspect="portrait" if short else "landscape", credit=CREDIT_V if short else CREDIT, **p)
