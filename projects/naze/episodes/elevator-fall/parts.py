"""落ちていくエレベーターで、着地の直前に跳べば助かるか: 本編 5 章とショート 5 本の台本と画面。ch1〜ch5・s1〜s5 の ep.py がここから読む。
台本は scripts.md(3版で確定。一字も変えない)、出典は research.md、数字は sim/calc.py(結果 sim/calc.txt)。
図は全部コードで描く(実機・事故の写真は使わない)。足したのは読みの say= と画面の指定だけ。
出典: 建築基準法施行令129条の4・129条の10、告示1414号(安全率)、国交省資料(調速機の125%・135%)、
昇降機等事故調査部会 報告書 2012(平和台駅)、NASA Eiband 1959(人がけがなく耐えた衝撃)、Jain ほか 2015(反応時間)、
ギネス世界記録(1945年 エンパイア・ステート・ビル)。
"""

CREDIT = "人形と数字は物理の計算（MuJoCo で検算）・法令と事故報告書"
CREDIT_V = "人形と数字は物理の計算・法令と事故報告書"

GREEN, YEL, RED, WHITE, DIM = "green", "yel", "red", "white", "dim"
GREY = (170, 178, 192)
GRN = (110, 220, 140)
RD = (240, 90, 80)
ORG = (240, 150, 40)
YL = (255, 214, 64)
BLU = (90, 170, 235)


def K(kind, **kw):
    return dict(kind=kind, **kw)


def CARD(*rows):
    return dict(kind="formula", rows=list(rows))


def SH(mode, **kw):
    """昇降路とかごと人形。mode は scene.py の MODES。res=当たったあとの大きな札、spd=速さの札、still=最後の形で出す。"""
    return K("shaft", mode=mode, **kw)


def BARS(rows, head, vmax, note=None, done=False):
    return K("bars", rows=list(rows), head=head, vmax=vmax, note=note, done=done)


def FLOORS(rows, head="何階から落ちたのと同じか", vmax=10):
    return K("floors", rows=list(rows), head=head, vmax=vmax)


# 横棒の行(名前, 値, 札, 色)
G600 = ("1回目 立ったまま", 600, "600G", RD)
G415 = ("6回目 完ぺきに跳ぶ", 415, "415G", ORG)
G60 = ("7回目 膝を曲げて待つ", 60, "60G", GRN)
V87 = ("何もしない", 87, "時速87km", RD)
V76 = ("地上と同じ跳び", 76, "時速76km", ORG)
V73 = ("落ちる箱の中で蹴る", 73, "時速73km", YL)
F10 = ("10階", 10.0, "10階", RD)
F76 = ("地上と同じ跳び", 7.6, "7.6階", ORG)
F69 = ("箱の中で蹴る", 6.9, "6.9階", YL)

P = {}

P["ch1"] = dict(title="第1章 人形を落とす", cta=False, lines=[
    dict(id="c1", text="10階で、扉が閉まります。", scene=SH("door")),
    dict(id="c2", text="動き出してすぐ、上で、バチンと音がする。", scene=SH("snap")),
    dict(id="c3", text="体が、ふわりと軽くなる。", scene=SH("float")),
    dict(id="c4", text="床が、足の下から逃げていく。", scene=SH("fall")),
    dict(id="c5", text="底まで、2.5秒。", scene=SH("fall", clock=True, res="2.47秒")),
    dict(id="c6", text="着地の直前に跳べば助かる。よく聞く話です。", scene=CARD(),
         style="question", sub="着地の直前に跳べば\n【助かる】？"),
    dict(id="c7", text="計算すると、答えは逆でした。", scene=CARD(("計算すると", 64, WHITE), ("答えは逆", 140, YEL))),
    dict(id="c8", text="跳ぶより、膝を曲げて待つほうが、受ける力は7分の1。",
         scene=BARS([("跳ぶ", 415, "415G", ORG), ("膝を曲げて待つ", 60, "60G", GRN)], "受ける力（体重の何倍か）", 450, note="膝なら7分の1")),
    dict(id="c9", text="これを、この人形で確かめます。", scene=SH("bow"), section=True),
    dict(id="c10", text="何度落としても、平気な作りです。"),
    dict(id="c11", text="ロープが切れ、止める仕組みも全部効かなかったとします。",
         scene=CARD(("ロープが切れ", 70, WHITE), ("止める仕組みも", 70, WHITE), ("全部効かない", 120, RED))),
    dict(id="c12", text="落ちる速さ、跳ぶ力、天井までの距離。すべて計算で出しました。",
         scene=CARD(("仮置き", 56, DIM), ("1階3m・人60kg・かご1,000kg", 60, WHITE), ("天井まで2.3m", 60, WHITE), ("すべて物理の計算", 80, YEL))),
    dict(id="c13", text="1回目。何もせず、立ったまま。", scene=SH("stand"), run=1, section=True),
    dict(id="c14", text="床に当たる速さは、時速87km。", scene=SH("stand", still=True, res="時速87km")),
    dict(id="c15", text="高速道路の車が、壁にぶつかる速さです。", scene=K("car")),
    dict(id="c16", text="人形の脚は、5cmで止まりました。", scene=SH("stand", still=True, res="5cmで止まる", note="仮置き")),
    dict(id="c17", text="かかった力は、体重の600倍。", scene=SH("stand", still=True, res="600G", sub="体重の600倍")),
    dict(id="c18", text="60kgの体に、36トン。", scene=K("kei")),
    dict(id="c19", text="軽自動車を30台以上、積んだ重さです。"),
    dict(id="c20", text="2回目。床の直前で、思いきり跳びます。", scene=SH("jump"), run=2, section=True),
    dict(id="c21", text="跳ぶ力は、垂直跳び50cmぶん。", scene=CARD(("仮置き", 56, DIM), ("垂直跳び50cmぶん", 100, YEL), ("床を離れる速さ 秒速3.1m", 56, WHITE))),
    dict(id="c22", text="結果は、時速87kmが76kmに。", scene=BARS([V87, V76], "床に当たる速さ", 90)),
    dict(id="c23", text="10階から落ちたのが、7.6階になっただけ。", scene=FLOORS([F10, F76])),
    dict(id="c24", text="75階なら、68階。当たる力は9%しか減りません。",
         scene=FLOORS([("75階", 75.0, "75階", RD), ("跳んだら", 68.1, "68階", ORG)], head="75階から落ちたら", vmax=75)),
    dict(id="c25", text="跳んで消せるのは、自分が跳べる速さだけ。", scene=CARD(("跳んで消せるのは", 64, WHITE), ("自分が跳べる速さだけ", 96, YEL))),
    dict(id="c26", text="落ちる速さには、まるで届かない。"),
    dict(id="c27", text="……ところが、計算を一コマずつ解くと、引っかかりが出ました。",
         scene=CARD(("計算を一コマずつ解くと", 64, WHITE), ("引っかかり", 140, YEL)), run=0),
    dict(id="c28", text="落ちている箱の中では、人形が地上より強く跳べたのです。",
         scene=CARD(("落ちている箱の中では", 64, WHITE), ("地上より強く跳べた", 110, YEL))),
])

P["ch2"] = dict(title="第2章 体重計は0kg", cta=False, lines=[
    dict(id="c1", text="落ちているあいだ、かごと人形は同じ速さです。", scene=SH("same"), section=True),
    dict(id="c2", text="足元に体重計を置くと、目盛りは0kg。", scene=SH("scale")),
    dict(id="c3", text="ダイエットの成果ではありません。"),
    dict(id="c4", text="宇宙ステーションの中と、同じ状態です。", scene=CARD(("宇宙ステーションの中と", 64, WHITE), ("同じ状態", 140, YEL))),
    dict(id="c5", text="あれも、地球へ落ち続けているから浮く。", scene=CARD(("あれも地球へ", 64, WHITE), ("落ち続けている", 110, YEL), ("だから浮く", 70, WHITE))),
    dict(id="c6", text="普通に考えれば、踏んばれない所では跳べないはず。", scene=CARD(("普通に考えれば", 60, DIM), ("踏んばれない所では", 70, WHITE), ("跳べないはず", 120, WHITE))),
    dict(id="c7", text="ところが、足が床に触れていれば、蹴れるんです。", scene=SH("push", res="蹴れる")),
    dict(id="c8", text="宇宙飛行士が、壁を蹴って進むのと同じ。", scene=CARD(("宇宙飛行士は", 64, WHITE), ("壁を蹴って進む", 110, YEL))),
    dict(id="c9", text="しかも、地上より強い。", scene=CARD(("しかも", 64, WHITE), ("地上より強い", 140, YEL))),
    dict(id="c10", text="地上で跳ぶとき、脚の力の4割以上は、自分の重さを持ち上げるのに消えます。",
         scene=BARS([("重さを持ち上げる", 44, "44%", GREY), ("跳ぶ速さになる", 56, "56%", YL)], "地上で跳ぶときの脚の力", 100)),
    dict(id="c11", text="落ちる箱の中には、その重さがない。",
         scene=BARS([("重さを持ち上げる", 0.01, "0%", GREY), ("跳ぶ速さになる", 100, "100%", YL)], "落ちる箱の中の脚の力", 100)),
    dict(id="c12", text="脚の力が、まるごと速さになる。"),
    dict(id="c13", text="3回目。落ちる箱の中で、同じ脚の力で蹴ります。", scene=SH("boxjump"), run=3, section=True),
    dict(id="c14", text="跳ぶ速さは、地上の3割増し。",
         scene=BARS([("地上の跳び", 3.13, "秒速3.1m", GREY), ("落ちる箱の中", 4.08, "秒速4.1m", YL)], "跳んで消せる速さ（脚の力は一定と仮置き）", 5, note="3割増し")),
    dict(id="c15", text="かごは押し返されて、少しだけ速く落ちる。", scene=SH("recoil")),
    dict(id="c16", text="人形の重さは、かごの17分の1ほど。かごが速くなるのは秒速0.24mです。",
         scene=CARD(("人形の重さは", 60, WHITE), ("かごの17分の1ほど", 90, YEL), ("かご ＋秒速0.24m", 70, WHITE))),
    dict(id="c17", text="床に当たるのは、時速73km。", scene=BARS([V87, V76, V73], "床に当たる速さ", 90)),
    dict(id="c18", text="6.9階から落ちたのと同じ。", scene=FLOORS([F10, F76, F69])),
    dict(id="c19", text="2回目より、もう1階近く得をしました。"),
    dict(id="c20", text="ただ、蹴るには、先にしゃがむ必要があります。", scene=SH("crouch"), run=0),
    dict(id="c21", text="浮いた体で膝を曲げると、足のほうが床から浮く。"),
    dict(id="c22", text="手すりを押して、体を沈めておくしかありません。", scene=SH("rail_push")),
    dict(id="c23", text="そして、跳んだ人形の頭の上には、天井があります。", scene=SH("gap", still=True)),
])

P["ch3"] = dict(title="第3章 頭を打つ", cta=False, lines=[
    dict(id="c1", text="4回目。少し早めに跳びます。", scene=SH("ready"), run=4, section=True),
    dict(id="c2", text="地上なら、跳んだ体はすぐ落ちてくる。", scene=K("ground_jump")),
    dict(id="c3", text="でもここには、引き戻す重さがない。"),
    dict(id="c4", text="人形は、蹴った勢いのまま天井へ。", scene=SH("early")),
    dict(id="c5", text="蹴り終わると、つま先立ち。頭から天井まで50cm。", scene=SH("gap", res="50cm", note="仮置き 天井2.3m・頭1.7m")),
    dict(id="c6", text="0.12秒で、ゴン。", scene=SH("bonk", res="0.12秒")),
    dict(id="c7", text="頭を打つ速さは、時速16km。", scene=SH("bonk", still=True, res="時速16km")),
    dict(id="c8", text="95cmの高さから、頭から落ちるのと同じです。", scene=CARD(("95cmの高さから", 90, YEL), ("頭から落ちるのと同じ", 76, WHITE))),
    dict(id="c9", text="しかも天井に止められた瞬間、人形はまた、かごと同じ速さに戻る。", scene=SH("stuck")),
    dict(id="c10", text="消したはずの秒速4.1mが、そっくり戻ってきました。",
         scene=BARS([("蹴った直後", 4.08, "秒速4.1m 遅く", YL), ("頭を打ったあと", 0.01, "0（かごと同じ）", RD)], "人形が、かごより遅い分", 5)),
    dict(id="c11", text="頭を打って、得はゼロ。踏んだり蹴ったりです。", scene=CARD(("頭を打って", 70, WHITE), ("得はゼロ", 140, RED))),
    dict(id="c12", text="5回目。今度は遅めに跳びます。", scene=SH("late"), run=5, section=True),
    dict(id="c13", text="蹴りきるには、0.19秒かかる。", scene=K("window", stage=0)),
    dict(id="c14", text="蹴りきる前に床が来ると、得は目減りします。"),
    dict(id="c15", text="床の0.10秒前に蹴り始めたら、秒速2.2m。半分ほどです。",
         scene=BARS([("蹴りきれたら", 4.08, "秒速4.1m", YL), ("床の0.10秒前に蹴り始め", 2.21, "秒速2.2m", ORG)], "跳んで消せる速さ", 5, note="半分ほど")),
    dict(id="c16", text="得を全部出せるのは、床の0.30秒前から0.19秒前まで。", scene=K("window", stage=1), run=0),
    dict(id="c17", text="その幅、116ミリ秒。", scene=K("window", stage=2)),
    dict(id="c18", text="そのあいだに、かごは2.5m落ちる。1階ぶんにも満たない幅です。", scene=K("window", stage=3)),
    dict(id="c19", text="しかも、外の見えない閉じた箱。合図はありません。", scene=CARD(("外の見えない", 64, WHITE), ("閉じた箱", 110, WHITE), ("合図はない", 110, YEL))),
    dict(id="c20", text="音に反応するだけでも、人は0.16秒かかる。", scene=CARD(("音に反応するだけで", 64, WHITE), ("約0.16秒", 140, YEL))),
    dict(id="c21", text="間に合わせるには、底の10m手前で「今だ」と分かっていないといけない。", scene=K("cue")),
    dict(id="c22", text="人形なら、計算どおりに跳べます。人には、まず無理です。", scene=CARD(("人形なら", 64, WHITE), ("計算どおりに跳べる", 80, WHITE), ("人には、まず無理", 100, YEL))),
    dict(id="c23", text="それでも、もし窓ぴったりに跳べたら。", scene=CARD(("もし", 64, WHITE), ("窓ぴったりに跳べたら", 100, YEL))),
    dict(id="c24", text="そのとき、いちばん大きな損が待っています。"),
])

P["ch4"] = dict(title="第4章 跳ぶより、膝", cta=False, lines=[
    dict(id="c1", text="6回目。窓ぴったりに、完ぺきに跳びます。", scene=SH("perfect"), run=6, section=True),
    dict(id="c2", text="床に当たるのは時速73km。ここまでは計画どおり。"),
    dict(id="c3", text="ところが、蹴りきった脚は、まっすぐ伸びています。", scene=SH("straight")),
    dict(id="c4", text="床に着いた瞬間、膝で受けるしろが残っていない。"),
    dict(id="c5", text="結果は、体重の415倍。", scene=SH("straight", still=True, res="415G")),
    dict(id="c6", text="1回目の600倍から、3割減っただけです。", scene=BARS([G600, G415], "受ける力（体重の何倍か）", 650, note="3割減っただけ")),
    dict(id="c7", text="7回目。跳ばずに、膝を曲げて待ちます。", scene=SH("knee"), run=7, section=True),
    dict(id="c8", text="膝が沈む50cmをかけて、止まる。", scene=SH("knee", still=True, res="50cmかけて止まる", note="仮置き")),
    dict(id="c9", text="結果は、60倍。", scene=BARS([G600, G415, G60], "受ける力（体重の何倍か）", 650)),
    dict(id="c10", text="完ぺきに跳んだ6回目の、7分の1です。", scene=BARS([G600, G415, G60], "受ける力（体重の何倍か）", 650, note="6回目の7分の1", done=True)),
    dict(id="c11", text="生卵は、手を引きながら受けると割れません。", scene=K("egg"), run=0),
    dict(id="c12", text="止まる距離が長いほど、力は小さい。", scene=CARD(("止まる距離が長いほど", 70, WHITE), ("力は小さい", 140, YEL))),
    dict(id="c13", text="跳ぶことは、その距離を自分で捨てることなんです。", scene=CARD(("跳ぶことは", 64, WHITE), ("その距離を", 70, WHITE), ("自分で捨てること", 110, YEL))),
    dict(id="c14", text="では、60倍なら平気なのか。", scene=CARD(("60倍なら", 90, WHITE), ("平気なのか", 120, YEL))),
    dict(id="c15", text="アメリカ航空宇宙局、NASAの1959年の報告があります。", scene=CARD(("NASA", 140, YEL), ("1959年の報告", 80, WHITE), ("人がけがなく耐えた衝撃", 56, WHITE))),
    dict(id="c16", text="人がけがなく耐えた衝撃の記録です。"),
    dict(id="c17", text="座席に体を固定して、お尻から突き上げる向きで16倍、0.04秒。",
         scene=BARS([("けがなく耐えた記録", 16, "16G・0.04秒", GRN), ("7回目 膝を曲げて待つ", 60, "60G", ORG)], "座席に固定・お尻から突き上げる向き", 70)),
    dict(id="c18", text="60倍は、その4倍近く。膝を曲げても、無事では済みません。",
         scene=BARS([("けがなく耐えた記録", 16, "16G・0.04秒", GRN), ("7回目 膝を曲げて待つ", 60, "60G", ORG)], "座席に固定・お尻から突き上げる向き", 70, note="4倍近く", done=True)),
    dict(id="c19", text="8回目。寝そべります。", scene=SH("lie"), run=8, section=True),
    dict(id="c20", text="背中で受ける向きなら、けがなく耐えた記録は45倍。",
         scene=BARS([("けがなく耐えた記録（背中で受ける）", 45, "45G", GRN)], "座席に固定・背中で受ける向き", 1050)),
    dict(id="c21", text="ただ、寝ると止まる距離が、3cmほどしかない。", scene=SH("lie", still=True, res="3cmで止まる", note="仮置き")),
    dict(id="c22", text="それで、1,000倍。45倍の20倍を超えます。",
         scene=BARS([("けがなく耐えた記録（背中で受ける）", 45, "45G", GRN), ("8回目 寝そべる", 1000, "1,000G", RD)], "背中で受ける向き", 1050, note="20倍を超える")),
    dict(id="c23", text="立っても、跳んでも、膝でも、寝ても。", scene=K("lineup", n=8), run=0),
    dict(id="c24", text="10階から8回落として、無事な回は1つもありませんでした。", scene=K("lineup", n=8, marks=True)),
    dict(id="c25", text="……ところが、記録を探すと、1人いたんです。", scene=CARD(("記録を探すと", 70, WHITE), ("1人いた", 140, YEL))),
    dict(id="c26", text="75階ぶん落ちて、生きのびた人が。", scene=CARD(("75階ぶん落ちて", 100, YEL), ("生きのびた人", 90, WHITE))),
])

P["ch5"] = dict(title="第5章 なぜ彼女は助かったのか", lines=[
    dict(id="c1", text="1945年、ニューヨーク。", scene=K("esb", stage=0), section=True),
    dict(id="c2", text="霧の中で、爆撃機がエンパイア・ステート・ビルにぶつかりました。", scene=K("esb", stage=1)),
    dict(id="c3", text="1台のかごに、エレベーター係の女性が乗っていました。"),
    dict(id="c4", text="ベティ・ルー・オリバーさんです。", scene=CARD(("ベティ・ルー・オリバーさん", 80, YEL), ("エレベーター係", 64, WHITE))),
    dict(id="c5", text="かごをつるケーブルが、切れました。", scene=CARD(("かごをつるケーブルが", 70, WHITE), ("切れた", 140, RED))),
    dict(id="c6", text="ギネス記録では、75階ぶんの落下。", scene=K("esb", stage=2)),
    dict(id="c7", text="階の高さから計算すると、およそ270mから290m。", scene=K("esb", stage=3)),
    dict(id="c8", text="人形の10階の、9倍以上です。", scene=K("esb", stage=4)),
    dict(id="c9", text="空気が無ければ、底では時速260kmを超えます。", scene=CARD(("空気が無ければ", 64, WHITE), ("時速260km超", 140, RED))),
    dict(id="c10", text="それでも彼女は、首と背骨と骨盤を折って、生きのびた。", scene=CARD(("首と背骨と骨盤を折って", 66, WHITE), ("生きのびた", 140, YEL))),
    dict(id="c11", text="跳んだからではありません。"),
    dict(id="c12", text="ギネス記録は、こう書いています。昇降路の空気が、かごを遅くした。", scene=K("air", stage=0)),
    dict(id="c13", text="細い縦穴の空気が、押し縮められたのです。"),
    dict(id="c14", text="底にたまったケーブルが、ばねになったとも。", scene=K("air", stage=1)),
    dict(id="c15", text="落ちるあいだに、何かが、かごの速さを削っていた。", scene=CARD(("落ちるあいだに", 64, WHITE), ("かごの速さを", 80, WHITE), ("削っていた", 130, YEL))),
    dict(id="c16", text="助かる鍵は、中の人ではなく、かごの側にあったんです。", scene=CARD(("助かる鍵は", 64, WHITE), ("中の人ではなく", 70, DIM), ("かごの側", 140, YEL))),
    dict(id="c17", text="今のエレベーターは、その「削る仕組み」を、はじめから積んでいます。", scene=K("gov", stage=0), section=True),
    dict(id="c18", text="まず、ロープ。国の決まりで、支えは2つ以上に分けます。", scene=K("gov", stage=1)),
    dict(id="c19", text="どれか1つでも、かごを支えられる作り。"),
    dict(id="c20", text="ロープは、ふだんかかる力の5倍に耐えます。", scene=K("gov", stage=2)),
    dict(id="c21", text="それでも全部切れたら。", scene=K("gov", stage=3)),
    dict(id="c22", text="かごの速さを見張る輪が、昇降路の上で回っています。", scene=K("gov", stage=4)),
    dict(id="c23", text="調速機。かごとは、別の細いロープでつながっている。", say="ちょうそくき。かごとは、べつの細いロープでつながっている。"),
    dict(id="c24", text="だから、主のロープが全部切れても、速さを測れます。", say="だから、おもの ロープが全部切れても、速さを測れます。"),
    dict(id="c25", text="多くのエレベーターは、速さが1.25倍ほどで電気を切る。", scene=K("gov", stage=5)),
    dict(id="c26", text="1.35倍ほどで、爪がレールをつかむ。", scene=K("gov", stage=6)),
    dict(id="c27", text="この爪を、非常止めといいます。", say="この爪を、ひじょうどめといいます。"),
    dict(id="c28", text="9回目。最初に「効かなかった」とした仕組みを、戻して落とします。", scene=SH("door", rails=True), run=9, section=True),
    dict(id="c29", text="ロープが切れて、少し沈んで、爪がかむ。", scene=SH("catch")),
    dict(id="c30", text="人形は、立ったままです。", scene=SH("catch", still=True, res="立ったまま", ok=True)),
    dict(id="c31", text="作り話ではありません。2011年、東京の地下鉄の駅です。", scene=CARD(("2011年", 140, YEL), ("東京の地下鉄の駅", 70, WHITE)), run=0),
    dict(id="c32", text="エレベーターのロープ3本が、全部切れました。", scene=CARD(("ロープ3本", 120, WHITE), ("すべて破断", 120, RED))),
    dict(id="c33", text="国の報告書の見立てでは、落ちたのは0.5mから1m。", scene=CARD(("落ちたのは", 64, WHITE), ("0.5〜1m", 150, YEL), ("国の報告書の見立て", 52, DIM))),
    dict(id="c34", text="乗っていた人のけがは、打ち身でした。", scene=CARD(("乗っていた人のけがは", 64, WHITE), ("打ち身", 150, YEL))),
    dict(id="c35", text="速くなる前につかむから、やさしく止められる。", scene=CARD(("速くなる前につかむから", 64, WHITE), ("やさしく止まる", 120, YEL))),
    dict(id="c36", text="時速87kmを、体重1倍の力で止めるには30m要ります。",
         scene=BARS([("時速87kmから", 30, "30m", RD)], "体重1倍の力で止めるのに要る距離", 32)),
    dict(id="c37", text="遅いうちにつかめば、5cmで足りる。",
         scene=BARS([("時速87kmから", 30, "30m", RD), ("遅いうち（1.35倍）", 0.05, "5cm", GRN)], "体重1倍の力で止めるのに要る距離", 32, done=True)),
    dict(id="c38", text="9回落として、無事だったのは1回だけ。", scene=K("lineup", n=9, marks=True), section=True),
    dict(id="c39", text="何もしなかった、最後の1回です。", scene=K("lineup", n=9, marks=True, hl=True)),
    dict(id="c40", text="着地の直前に跳ぶか。跳べます。地上より強く。", scene=CARD(("着地の直前に跳ぶか", 64, WHITE), ("跳べる", 140, YEL), ("地上より強く", 70, WHITE))),
    dict(id="c41", text="でも窓は116ミリ秒。うまく跳べても、膝のクッションを捨てる。", scene=CARD(("窓は116ミリ秒", 90, YEL), ("うまく跳べても", 60, WHITE), ("膝のクッションを捨てる", 76, WHITE))),
    dict(id="c42", text="落ちたら、跳ばずに膝を曲げる。", scene=CARD(("落ちたら", 64, WHITE), ("跳ばずに膝を曲げる", 110, YEL))),
    dict(id="c43", text="そして本当に人を守るのは、脚ではなく、レールをつかむ爪です。", scene=K("gov", stage=6)),
    dict(id="c44", text="次にエレベーターに乗ったら、扉のすき間の奥を見てください。", scene=K("door_gap")),
    dict(id="c45", text="そこを通るレールを、爪がつかみます。"),
])

P["s1"] = dict(title="直前に跳んだら、何階になる？", lines=[
    dict(id="c1", text="10階から落ちるエレベーター。床の直前で、人形が跳びます。", scene=SH("jump")),
    dict(id="c2", text="結果、10階が7.6階になっただけでした。", scene=FLOORS([F10, F76])),
    dict(id="c3", text="床に当たる速さは、時速87km。", scene=SH("stand", still=True, res="時速87km")),
    dict(id="c4", text="高速道路の車が、壁にぶつかる速さです。", scene=K("car")),
    dict(id="c5", text="跳ぶ力は、垂直跳び50cmぶん。", scene=CARD(("仮置き", 56, DIM), ("垂直跳び50cmぶん", 90, YEL), ("1階3m", 56, WHITE))),
    dict(id="c6", text="時速にすると、11kmしか消せません。", scene=CARD(("消せるのは", 64, WHITE), ("時速11km", 140, YEL))),
    dict(id="c7", text="87kmが、76km。", scene=BARS([V87, V76], "床に当たる速さ", 90)),
    dict(id="c8", text="75階から落ちたら、68階。当たる力は9%減るだけ。",
         scene=FLOORS([("75階", 75.0, "75階", RD), ("跳んだら", 68.1, "68階", ORG)], head="75階から落ちたら", vmax=75)),
    dict(id="c9", text="落ちる箱の中では、地上より3割強く跳べます。", scene=SH("boxjump")),
    dict(id="c10", text="それでも、6.9階。", scene=FLOORS([F10, F76, F69])),
    dict(id="c11", text="跳んで消せるのは、自分が跳べる速さだけ。", scene=CARD(("跳んで消せるのは", 64, WHITE), ("自分が跳べる速さだけ", 90, YEL))),
    dict(id="c12", text="落ちる速さには、まるで届かないんです。"),
])

P["s2"] = dict(title="落ちる箱の体重計は0kg", lines=[
    dict(id="c1", text="落ちるエレベーターで体重計に乗ると、0kgです。", scene=SH("scale")),
    dict(id="c2", text="ダイエットの成果ではありません。"),
    dict(id="c3", text="かごも人も、同じ速さで落ちているから。", scene=SH("same")),
    dict(id="c4", text="宇宙ステーションの中と、同じ状態です。", scene=CARD(("宇宙ステーションの中と", 64, WHITE), ("同じ状態", 140, YEL))),
    dict(id="c5", text="踏んばれないなら、跳べないはず。", scene=CARD(("踏んばれないなら", 70, WHITE), ("跳べないはず", 120, WHITE))),
    dict(id="c6", text="ところが、足が床に触れていれば、蹴れる。", scene=SH("push", res="蹴れる")),
    dict(id="c7", text="しかも、地上より強く。", scene=CARD(("しかも", 64, WHITE), ("地上より強く", 140, YEL))),
    dict(id="c8", text="地上では、脚の力の4割以上が、自分の重さを持ち上げるのに消えます。",
         scene=BARS([("重さを持ち上げる", 44, "44%", GREY), ("跳ぶ速さになる", 56, "56%", YL)], "地上で跳ぶときの脚の力", 100)),
    dict(id="c9", text="落ちる箱には、その重さがない。",
         scene=BARS([("重さを持ち上げる", 0.01, "0%", GREY), ("跳ぶ速さになる", 100, "100%", YL)], "落ちる箱の中の脚の力", 100)),
    dict(id="c10", text="同じ脚の力で、秒速3.1mが4.1mに。",
         scene=BARS([("地上の跳び", 3.13, "秒速3.1m", GREY), ("落ちる箱の中", 4.08, "秒速4.1m", YL)], "跳んで消せる速さ（脚の力は一定と仮置き）", 5)),
    dict(id="c11", text="3割増しです。"),
    dict(id="c12", text="それでも10階は、6.9階。助かる速さには届きません。", scene=FLOORS([F10, F69])),
])

P["s3"] = dict(title="早く跳ぶと、頭を打つ", lines=[
    dict(id="c1", text="落ちるエレベーターで早めに跳ぶと、0.12秒で頭を打ちます。", scene=SH("early")),
    dict(id="c2", text="落ちる箱の中には、引き戻す重さがありません。", scene=K("ground_jump")),
    dict(id="c3", text="蹴った勢いのまま、まっすぐ天井へ。", scene=SH("early")),
    dict(id="c4", text="つま先立ちの頭から天井まで、50cm。", scene=SH("gap", res="50cm", note="仮置き")),
    dict(id="c5", text="頭を打つ速さは時速16km。95cmの高さから頭から落ちるのと同じ。", scene=SH("bonk", res="時速16km")),
    dict(id="c6", text="しかも天井に止められて、またかごと同じ速さに戻る。", scene=SH("stuck")),
    dict(id="c7", text="跳んで消した速さが、そっくり戻るんです。"),
    dict(id="c8", text="頭を打って、得はゼロ。", scene=CARD(("頭を打って", 70, WHITE), ("得はゼロ", 140, RED))),
    dict(id="c9", text="遅すぎると、蹴りきる前に床が来る。", scene=K("window", stage=0)),
    dict(id="c10", text="得を全部出せるのは、床の0.30秒前から0.19秒前。", scene=K("window", stage=1)),
    dict(id="c11", text="その幅、116ミリ秒。", scene=K("window", stage=2)),
    dict(id="c12", text="音に反応するだけでも、人は0.16秒かかる。", scene=CARD(("音に反応するだけで", 64, WHITE), ("約0.16秒", 140, YEL))),
    dict(id="c13", text="外の見えない箱の中で、底の10m手前で「今だ」と分からないと、間に合いません。", scene=K("cue")),
])

P["s4"] = dict(title="跳ぶと、膝で受けるより7倍きつい", lines=[
    dict(id="c1", text="落ちるエレベーターで跳ぶと、膝で待つより7倍きつい。", scene=K("twodoll")),
    dict(id="c2", text="10階から、時速87km。", scene=SH("stand")),
    dict(id="c3", text="立ったまま着くと、脚は5cmで止まる。体重の600倍です。", scene=SH("stand", still=True, res="600G", note="仮置き 止まるまで5cm")),
    dict(id="c4", text="60kgの体に、36トン。軽自動車30台以上の重さ。", scene=K("kei")),
    dict(id="c5", text="完ぺきに跳んでも、時速73km。", scene=SH("perfect")),
    dict(id="c6", text="しかも蹴りきった脚は、まっすぐ伸びたまま。", scene=SH("straight")),
    dict(id="c7", text="それで、415倍。", scene=BARS([G600, G415], "受ける力（体重の何倍か）", 650)),
    dict(id="c8", text="跳ばずに膝を曲げて、50cmかけて止まると、60倍。", scene=SH("knee", res="60G", note="仮置き 止まるまで50cm")),
    dict(id="c9", text="生卵は、手を引きながら受けると割れません。あれと同じです。", scene=K("egg")),
    dict(id="c10", text="跳ぶと、その膝のしろを自分で捨ててしまう。", scene=BARS([G600, G415, G60], "受ける力（体重の何倍か）", 650, done=True, note="膝なら7分の1")),
    dict(id="c11", text="ただ、人がけがなく耐えた記録は16倍。",
         scene=BARS([("けがなく耐えた記録（NASA 1959年）", 16, "16G・0.04秒", GRN), ("膝を曲げて待つ", 60, "60G", ORG)], "座席に固定・お尻から突き上げる向き", 70)),
    dict(id="c12", text="60倍でも、無事では済まないのです。"),
])

P["s5"] = dict(title="ロープが全部切れても、落ちたのは1mほど", lines=[
    dict(id="c1", text="エレベーターのロープが3本とも切れて、落ちたのは1mほど。", scene=SH("catch")),
    dict(id="c2", text="2011年、東京の地下鉄・平和台駅の事故です。", scene=CARD(("2011年", 140, YEL), ("東京の地下鉄・平和台駅", 66, WHITE))),
    dict(id="c3", text="報告書の見立てでは、0.5mから1m。けがは、打ち身でした。", scene=CARD(("落ちたのは", 64, WHITE), ("0.5〜1m", 150, YEL), ("けがは打ち身（報告書の見立て）", 52, WHITE))),
    dict(id="c4", text="止めたのは、かごについた爪です。", scene=K("gov", stage=6)),
    dict(id="c5", text="かごの速さを見張る輪が、昇降路の上で回っている。", scene=K("gov", stage=4)),
    dict(id="c6", text="調速機です。", say="ちょうそくきです。"),
    dict(id="c7", text="輪とかごは、つり下げるロープとは別の、細いロープでつながっている。"),
    dict(id="c8", text="だから、主のロープが全部切れても働きます。", scene=K("gov", stage=3), say="だから、おもの ロープが全部切れても働きます。"),
    dict(id="c9", text="決められた速さの1.35倍ほどで、爪がレールをつかむ。", scene=K("gov", stage=6)),
    dict(id="c10", text="速くなる前につかむから、5cmほどで止まれる。", say="速くなる前につかむから、5センチほどで、とまれる。",
         scene=BARS([("遅いうち（1.35倍）", 0.05, "5cm", GRN)], "体重1倍の力で止めるのに要る距離", 32)),
    dict(id="c11", text="時速87kmまで待ったら、30m要ります。",
         scene=BARS([("遅いうち（1.35倍）", 0.05, "5cm", GRN), ("時速87kmから", 30, "30m", RD)], "体重1倍の力で止めるのに要る距離", 32)),
    dict(id="c12", text="床の直前に跳ぶより、ずっと確かな仕組みです。", scene=CARD(("床の直前に跳ぶより", 64, WHITE), ("ずっと確か", 140, YEL))),
    dict(id="c13", text="次に乗ったら、扉のすき間の奥を見てください。そこを通るレールを、爪がつかみます。", scene=K("door_gap")),
])


def _finish(lines):
    """「N回目」の札(run)を次の行へ引き継ぐ(run=0 で消す)。"""
    cur = 0
    res = []
    for l in lines:
        l = dict(l)
        if "run" in l:
            cur = l["run"]
        else:
            l["run"] = cur
        res.append(l)
    return res


# 読みの直し(kana の出力を全行見て、違う所だけ)。長い語から順に置き換えて say を作る
YOMI = [("〜", "から"), ("1,000倍", "せんばい"), ("0.5mから1m", "れいてんごメートルからいちメートル")]


def yomi(text):
    s = text
    for a, b in YOMI:
        s = s.replace(a, b)
    return s


def ep_for(name: str) -> dict:
    p = dict(P[name])
    res = []
    for l in _finish(p["lines"]):
        if "say" not in l:
            y = yomi(l["text"])
            if y != l["text"]:
                l = dict(l, say=y)
        res.append(l)
    p["lines"] = res
    return dict(kind="sim", aspect="portrait" if name.startswith("s") else "landscape", credit=CREDIT_V if name.startswith("s") else CREDIT, **p)
