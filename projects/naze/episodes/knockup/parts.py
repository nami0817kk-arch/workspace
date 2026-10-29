"""ワンピース: ノックアップストリーム(水の柱で船は雲の海まで届くか)。本編 5 章とショート 5 本の台本と画面。\nch1〜ch5・s1〜s5 の ep.py がここから読む。台本は scripts.md(2026-10-29 ユーザー承認。一字も変えない)、出典と計算は research.md。\n作品の絵は使わない。船の想像図だけ assets/ship_gemini.jpg(AI で作成)があれば使う。"""
import re

CREDIT = "標準大気1976・材料力学の式で自分で計算（作中の高さは作中の設定）"
CREDIT_V = "標準大気1976で自分で計算（高さは作中の設定）"  # 縦は幅が狭いので短く

GREEN, YEL, RED, WHITE, DIM = "green", "yel", "red", "white", "dim"
COL0 = dict(kind="column", stage=0)
COL1 = dict(kind="column", stage=1)
COL2 = dict(kind="column", stage=2)
COL3 = dict(kind="column", stage=3)
RULER0 = dict(kind="ruler", stage=0)
RULER1 = dict(kind="ruler", stage=1)
QBLANK = dict(kind="formula", rows=[])
PLUME0 = dict(kind="plume", stage=0)
PLUME1 = dict(kind="plume", stage=1)
PLUME2 = dict(kind="plume", stage=2)
DECEL = dict(kind="decel")
SPEED_DIAL = dict(kind="speed", bars=False)
SPEED_BOTH = dict(kind="speed", bars=True)
DROPS0 = dict(kind="drops", stage=0)
DROPS1 = dict(kind="drops", stage=1)
AIRARROW = dict(kind="airarrow")
DROPFLY0 = dict(kind="dropfly", stage=0)
DROPFLY1 = dict(kind="dropfly", stage=1)
RAIN = dict(kind="rain")
PUSH0 = dict(kind="push", stage=0)
PUSH1 = dict(kind="push", stage=1)
WIDEN0 = dict(kind="widen", stage=0)
WIDEN1 = dict(kind="widen", stage=1)
WIDEN2 = dict(kind="widen", stage=2)
WIDEN3 = dict(kind="widen", stage=3)
FOUNTAIN = dict(kind="fountain")
PERSON0 = dict(kind="persong", stage=0)
PERSON1 = dict(kind="persong", stage=1)
SHIP = dict(kind="ship")
HULL = dict(kind="hull")
COIN = dict(kind="coin")
PLANK = dict(kind="struct", which="plank")
BEAM0 = dict(kind="struct", which="beam", stage=0)
BEAM1 = dict(kind="struct", which="beam", stage=1)
SKYTREE = dict(kind="skytree")
WEIGHTLESS = dict(kind="weightless")
CONDS = dict(kind="conds")
GDIAL = dict(kind="gdial")
BLUE_ = (90, 170, 235)
TARGET = ("白海 高さ7000m", 7000, None, "7000m", (240, 200, 70))


def _bars(rows, vmax, **kw):
    return dict(kind="bars", rows=rows, vmax=vmax, **kw)


B_FOUNT = _bars([("キング・ファハド噴水", 312, None, "312m", (90, 170, 235)), TARGET], 7000, head="7000mは 約22倍の高さ")
B_GEYSER = _bars([("スチームボート間欠泉", 116, None, "最大116m", (90, 170, 235)), TARGET], 7000, head="7000mは 約60倍の高さ")
_VOLC_ROWS = [("世界一の噴水", 312, None, "312m", (90, 170, 235)),
              ("世界一の間欠泉", 116, None, "116m", (90, 170, 235)),
              ("セントヘレンズ山の噴火", 2000, 5500, "勢いだけで 2〜5.5km", (200, 120, 80)),
              TARGET]
B_VOLC = _bars(_VOLC_ROWS, 7000, head="どれも 7000mに足りない", grow_from=2)
B_VOLC_S = _bars(_VOLC_ROWS, 7000, head="どれも 7000mに足りない", grow_from=0)
B_CLOCK = _bars([("頂上まで", 37.8, None, "約38秒", (240, 200, 70)), ("作中の噴き上げ", 60, None, "約1分（作中の説明）", (90, 170, 235))], 66, head="時間は足りる")
_DR = [("直径1m　約0.5トン", 1917, None, "少なくとも 秒速1,900m", (200, 120, 80)),
       ("直径10m", 423, 488, "秒速420〜490m", (200, 160, 80)),
       ("直径100m", 375, 380, "秒速375m前後", (110, 220, 140)),
       ("空気が無いときの計算", 370.5, None, "秒速370m", (190, 195, 205))]
B_DROPS1 = _bars(_DR[:1], 2100, head="玉の大きさと 要る速さ", marks=[(370.5, "370m", (240, 90, 80))])
B_DROPS2 = _bars(_DR[:2], 2100, head="玉の大きさと 要る速さ", grow_from=1, marks=[(370.5, "370m", (240, 90, 80))])
B_DROPS3 = _bars(_DR, 2100, head="玉の大きさと 要る速さ", grow_from=2, marks=[(370.5, "370m", (240, 90, 80))])
B_DROPS3S = _bars(_DR, 2100, head="玉の大きさと 要る速さ", grow_from=0, marks=[(370.5, "370m", (240, 90, 80))])
B_97 = _bars([("後ろの水の速さ", 100, None, "100%", (90, 170, 235)), ("柱の先頭の速さ", 96.6, None, "約97%", (110, 220, 140))], 112, head="先頭は ほとんど遅くならない")
B_3PCT = _bars([("柱の長さ（高さ7000m）", 7000, None, "7000m", (90, 170, 235)), ("空気を押しのけるのに使う分", 206, None, "約200m（約3%）", (240, 90, 80))], 7000, head="使うのは わずか3%")
B_TIME = _bars([("空気が無いときの到着", 37.8, None, "約38秒", (190, 195, 205)), ("柱の先頭の到着", 38.5, None, "約39秒", (110, 220, 140))], 46, head="遅れは 約1秒")
B_FINAL = _bars([("世界一の噴水", 104.2, None, "秒速104m（時速375km）", (90, 170, 235)),
                 ("セントヘレンズ山の噴火", 200, 330, "秒速200〜330m", (200, 120, 80)),
                 ("要る速さ", 370.5, None, "秒速370m以上", (240, 90, 80))], 420, head="どれも 秒速370mに届かない")
GB_DIST = _bars([("30mで押し上げる", 234, None, "約230G", (240, 90, 80)), ("100m", 71, None, "約70G", (240, 150, 80)), ("1km", 8, None, "約8G", (110, 220, 140))], 260, head="押す距離ごとの G")
GB_46 = _bars([("30m", 234, None, "約230G", (240, 90, 80)), ("約150m", 46, None, "46G", (240, 200, 70))], 260, head="46Gなら 約150m", marks=[(46.2, "耐えた記録", (240, 200, 70))])
GB_3G = _bars([("約3.5km", 3, None, "3G", (110, 220, 140))], 60, head="3Gなら 船も人も持つ", marks=[(46.2, "耐えた記録 46G", (240, 200, 70))])
GB_3G_LONG = _bars([("押し上げ 約3.5km", 3, None, "3G", (110, 220, 140)), ("人が耐えた記録（一瞬）", 46.2, None, "46G", (240, 200, 70))], 90, head="3Gなら 船も人も持つ")
GB_S4A = _bars([("約130m以上（乾いたオーク）", 56, None, "56G以下", (240, 200, 70)), ("約240m以上（生木）", 30, None, "30G以下", (110, 220, 140))], 70, head="梁を守る押し上げ距離")
GB_S4B = _bars([("約3.5km", 3, None, "3G", (110, 220, 140)), ("約150m（一瞬の記録）", 46, None, "46G", (240, 200, 70))], 60, head="人は 長く押されると きつい", grow_from=0)


def CARD(*rows):
    return dict(kind="formula", rows=list(rows))


def EXPCARD(n, text):
    return dict(kind="formula", rows=[(f"実験{n}", 130, YEL), (text, 66, WHITE)])


CARD_CALC = CARD(("重力と空気の計算", 90, YEL), ("うまくいくまで、何度でも", 56, WHITE))
CARD_NEED = CARD(("勢いでは届かない", 90, RED), ("どれだけ速ければ届くのか", 66, YEL))
CARD_COLUMN = CARD(("玉ではなく", 76, WHITE), ("つながった柱", 110, YEL))
CARD_SHIP = CARD(("水は、これで届く", 86, GREEN), ("では、船と人は？", 80, YEL))
CARD_LAST = CARD(("最後の実験", 130, YEL), ("条件を、全部そろえる", 66, WHITE))
CARD_SPEED = CARD(("届かない", 100, RED), ("足りないのは 水の速さ", 70, YEL))
CARD_THICK = CARD(("太い柱を", 80, WHITE), ("途切れさせない", 100, YEL))
CARD_BEAM = CARD(("船底の板は 持つ", 74, GREEN), ("折れるのは 荷物の梁", 74, RED))

P = {}

P["ch1"] = dict(title="第1章 本物の勢いで、打ち上げてみる", cta=False, lines=[
    dict(id="c1", text="ワンピースに出てくる、ノックアップストリーム。海から空へ、船を突き上げる海流です。", scene=COL0),
    dict(id="c2", text="作中の設定では、船がまず着く雲の海「白海」は、高さ7000m。", scene=RULER0),
    dict(id="c3", text="富士山の約2倍。空島がある「白々海」は、さらに上の1万mです。", scene=RULER1),
    dict(id="c4", text="水の勢いだけで、船はそこまで届くのか。", style="question", sub="水の勢いだけで\n船は【届く】のか", scene=QBLANK),
    dict(id="c5", text="実験していきます。うまくいくまで、何度でも試します。", scene=CARD_CALC),
    dict(id="c6", text="実験1。まず、世界一高い噴水で、水を打ち上げてみます。", section=True, exp=1, scene=EXPCARD(1, "世界一高い噴水で打つ")),
    dict(id="c7", text="サウジアラビアのキング・ファハド噴水。高さ312m。水は、時速375kmで噴き出します。", scene=B_FOUNT),
    dict(id="c8", text="7000mは、その約22倍の高さ。届きません。失敗です。"),
    dict(id="c9", text="世界一高く噴く間欠泉、スチームボートでも、最大116m。7000mは、その約60倍です。", scene=B_GEYSER),
    dict(id="c10", text="実験2。では、火山の噴火で、打ち上げてみます。", section=True, exp=2, scene=PLUME0),
    dict(id="c11", text="1980年のセントヘレンズ山。噴き出す速さは、秒速200〜330mと見積もられています。", scene=PLUME1),
    dict(id="c12", text="それでも、勢いだけで届くのは2〜5.5km。7000mには足りません。失敗です。", scene=B_VOLC),
    dict(id="c13", text="1991年のピナトゥボ山の噴煙は、40km近くまで昇りました。でもそれは、熱い煙が熱気球のように浮いたからです。", scene=PLUME2),
    dict(id="c14", text="勢いでは、届かない。では、どれだけ速ければ届くのか。", exp=0, scene=CARD_NEED),
])
P["ch2"] = dict(title="第2章 必要な速さと、空気", cta=False, lines=[
    dict(id="c1", text="まず、必要な速さを計算します。水を、真上に打ち上げます。", section=True, exp=0, scene=DECEL),
    dict(id="c2", text="上に飛んだものは、1秒ごとに秒速9.8mずつ遅くなります。"),
    dict(id="c3", text="7000mでちょうど止まるなら、出だしは秒速370m。時速約1300km。新幹線の約4倍、世界一の噴水の約3.5倍です。", scene=SPEED_BOTH),
    dict(id="c4", text="音は秒速約340m。水は、それを追い越す速さで飛び出します。"),
    dict(id="c5", text="頂上まで約38秒。作中では、噴き上げは約1分続くと説明されます。時間は足ります。", scene=B_CLOCK),
    dict(id="c6", text="実験3。この速さで、ペットボトル1本分の水の玉を打ちます。", section=True, exp=3, scene=DROPS0),
    dict(id="c7", text="空気は、速いものほど強く押し返します。速さが2倍なら、押し返す力は4倍。", scene=AIRARROW),
    dict(id="c8", text="秒速370mでは、届きません。秒速20kmまで上げても、空気に負けます。失敗です。", scene=DROPFLY0),
    dict(id="c9", text="実験4。玉を、大きくしてみます。", section=True, exp=4, scene=EXPCARD(4, "玉を、大きくする")),
    dict(id="c10", text="直径1m、重さ約0.5トン。少なくとも秒速1900m。音の約5.6倍が要ります。", scene=B_DROPS1),
    dict(id="c11", text="直径10m。秒速420〜490m。まだ、370mでは足りません。", scene=B_DROPS2),
    dict(id="c12", text="直径100m。秒速375m前後。最初の計算の370mと、ほとんど同じです。やっと、届きます。", scene=B_DROPS3),
    dict(id="c13", text="大きい玉ほど、重さのわりに空気を受ける面が小さい。だから空気に強い。", scene=DROPS1),
    dict(id="c14", text="でも、直径100mの水の玉を、どう打つのか。ノックアップストリームは、玉ではなく、つながった柱です。", exp=0, scene=CARD_COLUMN),
])
P["ch3"] = dict(title="第3章 実験5 玉を、つながった柱に変える", cta=False, lines=[
    dict(id="c1", text="実験5。玉を、つながった柱に変えます。水は途切れず、柱のまま昇ります。", section=True, exp=5, scene=EXPCARD(5, "玉を、つながった柱に変える")),
    dict(id="c2", text="柱の先頭は、空気を押しのけて進みます。後ろの水は、先頭が開けた道を通ります。", scene=PUSH0),
    dict(id="c3", text="水は、空気より約800倍重い。だから先頭は、ほとんど遅くなりません。", scene=PUSH1),
    dict(id="c4", text="計算すると、先頭の速さは後ろの水の約97%。", scene=B_97),
    dict(id="c5", text="空気を押しのけるのに使う水は、柱の長さで約200m。7000mの、わずか3%です。", scene=B_3PCT),
    dict(id="c6", text="先頭が7000mに着くのは約39秒後。最初の計算の38秒と、1秒しか違いません。", scene=B_TIME),
    dict(id="c7", text="太い柱が途切れずに続けば、空気はほとんど邪魔になりません。水は、成功です。", scene=PUSH1),
    dict(id="c8", text="ただし柱は、上に行くほど遅くなります。そのぶん水が詰まって、太くなります。", section=True, scene=WIDEN0),
    dict(id="c9", text="高さ6000mで、太さは根元の約1.6倍。6900mでは約3倍。", scene=WIDEN1),
    dict(id="c10", text="頂上では、水が横に広がって、傘のように開きます。噴水のてっぺんと同じ形です。", scene=WIDEN2),
    dict(id="c11", text="秒速400mで噴き出せば、7000mでもまだ秒速150m。雲に飛び込む勢いは残っています。", scene=WIDEN3),
])
P["ch4"] = dict(title="第4章 実験6・7 船と人は耐えられるか", cta=False, lines=[
    dict(id="c1", text="水は、これで届きます。でも、船と人は、無事でしょうか。", section=True, exp=0, scene=CARD_SHIP),
    dict(id="c2", text="実験6。船に、荷物と人を乗せて、30mで秒速370mまで押し上げます。", exp=6, scene=EXPCARD(6, "船と人を30mで押し上げる")),
    dict(id="c3", text="押す距離で、加速の強さが決まります。体にかかる力はGで表し、地上で立っているときが1G。", scene=PERSON0),
    dict(id="c4", text="30mなら約230G。100mで約70G、1kmで約8Gです。", scene=GB_DIST),
    dict(id="c5", text="まず、船です。仮に、全長30mの木造帆船、重さ200トン。復元船のマイフラワー2世は、全長約32m、重さ約240トンです。", scene=SHIP),
    dict(id="c6", text="230Gでは、船は水から、約4万7000トンの力で押し上げられます。", scene=HULL),
    dict(id="c7", text="1円玉1枚の面積に、大人1人分、約100kg。それが船底全体にかかります。", scene=COIN),
    dict(id="c8", text="船底の板は、厚さ8cm、骨組みの間隔40cmと置きます。オークの生木で約230G、乾いた木なら約430G。ぎりぎり持ちます。", scene=PLANK),
    dict(id="c9", text="弱いのは、中の荷物です。1トンの大砲が、長さ2mの梁1本に乗ると、乾いたオークで約56G。生木なら約30G。", scene=BEAM0),
    dict(id="c10", text="30mでは、大砲が梁を折ります。失敗です。", scene=BEAM1),
    dict(id="c11", text="人も同じです。耐えた記録は、1954年のロケットそりで46G。ほんの一瞬。230Gは、問題外です。", scene=PERSON1),
    dict(id="c12", text="実験7。押し上げる距離を、延ばします。", section=True, exp=7, scene=EXPCARD(7, "押し上げる距離を延ばす")),
    dict(id="c13", text="46Gなら約150m。荷物の梁も、ほぼ同じ距離で持ちます。", scene=GB_46),
    dict(id="c14", text="スペースシャトルは、3Gまでに抑えていました。3Gなら、押し上げは約3.5km。スカイツリー5本半です。", scene=SKYTREE),
    dict(id="c15", text="3Gなら、船は何ともありません。人も耐えられます。成功です。", scene=GB_3G_LONG),
    dict(id="c16", text="押し上げが終わると、船の中は約38秒、無重力。訓練機の約25秒の1.5倍です。", scene=WEIGHTLESS),
])
P["ch5"] = dict(title="第5章 条件を、全部そろえる", lines=[
    dict(id="c1", text="条件を、全部そろえます。", section=True, exp=0, scene=CARD_LAST),
    dict(id="c2", text="水は、秒速370m以上で噴き出す。柱は太く、途切れさせない。船は、数kmかけて、ゆっくり押し上げる。", scene=CONDS),
    dict(id="c3", text="先頭は、約39秒後に、高さ7000mへ。", scene=COL1),
    dict(id="c4", text="船は、雲の海に着きました。成功です。", scene=COL2),
    dict(id="c5", text="ただし、ここで比べた本物は、どれも秒速370mに届きません。", scene=B_FINAL),
    dict(id="c6", text="物理は、届かないとは言いません。ただ、火山より速い水が要ります。"),
    dict(id="c7", text="冒頭の、雲まで伸びる水の柱。あれは、音より速く昇る水でした。", scene=COL3),
    dict(id="c8", text="噴水を見かけたら、てっぺんで水が止まって広がる所を見てください。7000mの頂上も、同じ形です。", scene=FOUNTAIN),
])
P["s1"] = dict(title="噴水も火山も届かない", lines=[
    dict(id="c1", text="ワンピースのノックアップストリーム。海から空へ、船を突き上げる海流です。", scene=COL0),
    dict(id="c2", text="作中の設定では、船が着く雲の海は、高さ7000mです。", scene=RULER0),
    dict(id="c3", text="世界一の噴水や火山の勢いで、そこまで届くのか。", style="question", sub="噴水や火山の勢いで\n【届く】のか", scene=QBLANK),
    dict(id="c4", text="答えは、届きません。足りないのは、水の速さです。", scene=CARD_SPEED),
    dict(id="c5", text="世界一高い噴水は、サウジアラビアのキング・ファハド噴水で312m。7000mは、その約22倍の高さです。", scene=B_FOUNT),
    dict(id="c6", text="火山の噴火でも、噴き出す速さは秒速200〜330m。勢いだけで届くのは2〜5.5kmです。", scene=B_VOLC_S),
    dict(id="c7", text="7000mでちょうど止まるなら、出だしは秒速370m。時速約1300kmです。", scene=SPEED_DIAL),
    dict(id="c8", text="新幹線の約4倍。音の秒速340mも超えます。", scene=SPEED_BOTH),
    dict(id="c9", text="頂上までは約38秒。しかも空気があれば、さらに速さが要ります。", scene=DECEL),
    dict(id="c10", text="噴水を見かけたら、てっぺんの高さを見てください。噴き出す速さが、その高さを決めています。", scene=FOUNTAIN),
])
P["s2"] = dict(title="小さな水の玉は届かない", lines=[
    dict(id="c1", text="ワンピースの、空島へ行く水の柱。もし、ペットボトル1本分の玉だったら。", scene=DROPFLY1),
    dict(id="c2", text="秒速20kmで打っても、高さ7000mには届きません。"),
    dict(id="c3", text="速く打てば届くはずなのに、なぜでしょう。", style="question", sub="速く打てば届くのに\n【なぜ】届かない？", scene=QBLANK),
    dict(id="c4", text="答えは、空気。速いほど、強く押し返されるからです。", scene=AIRARROW),
    dict(id="c5", text="作中の設定では、船が空へ上がる高さは7000m。水の玉の大きさを変えて計算しました。", scene=RULER0),
    dict(id="c6", text="空気の押し返しは、速さが2倍なら4倍。", scene=AIRARROW),
    dict(id="c7", text="直径1mの玉でも、少なくとも秒速1900m。音の5倍以上です。", scene=B_DROPS1),
    dict(id="c8", text="直径10mなら秒速420〜490m。直径100mなら秒速375m。計算した370mと、ほぼ同じです。", scene=B_DROPS3S),
    dict(id="c9", text="大きい玉ほど、重さのわりに空気を受ける面が小さい。だから空気に負けません。", scene=DROPS1),
    dict(id="c10", text="雨を見かけたら、小さな粒ほどゆっくり落ちてくるのを見てください。同じ理由です。", scene=RAIN),
])
P["s3"] = dict(title="水の柱は上で太る", lines=[
    dict(id="c1", text="ワンピースのノックアップストリーム。作中の設定では、船は高さ7000mまで昇ります。", scene=COL0),
    dict(id="c2", text="世界一高く噴く間欠泉でも、最大116m。7000mは、その約60倍です。", scene=B_GEYSER),
    dict(id="c3", text="水の柱は、どうすれば、そこまで届くのか。", style="question", sub="水の柱は\nどうすれば【届く】のか", scene=QBLANK),
    dict(id="c4", text="答えは、太い柱を、途切れさせないこと。", scene=CARD_THICK),
    dict(id="c5", text="柱の先頭は空気を押しのけ、後ろの水は、その道を通ります。", scene=PUSH0),
    dict(id="c6", text="水は空気の約800倍重い。先頭の速さは、後ろの水の約97%までしか落ちません。", scene=PUSH1),
    dict(id="c7", text="空気を押しのけるのに使う水は、柱の長さで約200m。7000mの3%です。", scene=B_3PCT),
    dict(id="c8", text="しかも柱は、上ほど遅くなって太ります。6900mでは、根元の約3倍。", scene=WIDEN1),
    dict(id="c9", text="てっぺんでは、傘のように開きます。", scene=WIDEN2),
    dict(id="c10", text="噴水を見かけたら、てっぺんで水が広がる形を見てください。7000mの頂上も、同じ形です。", scene=FOUNTAIN),
])
P["s4"] = dict(title="船の板は持つ。折れるのは荷物の梁", lines=[
    dict(id="c1", text="ワンピースのノックアップストリームで、船を秒速370mまで押し上げる。船は、壊れないのか。", scene=SHIP),
    dict(id="c2", text="作中の設定では、船が着く雲の海は、高さ7000mです。", scene=RULER0),
    dict(id="c3", text="答えは、船底の板は持つ。折れるのは、荷物の梁です。", scene=CARD_BEAM),
    dict(id="c4", text="仮に、全長30mの木造帆船、重さ200トン。30mで押し上げると、約230Gかかります。", scene=GDIAL),
    dict(id="c5", text="船底の板は、厚さ8cmのオークで、生木なら約230G、乾いた木なら約430Gまで持ちます。", scene=PLANK),
    dict(id="c6", text="ところが、1トンの大砲が乗った長さ2mの梁は、乾いたオークで約56G。生木なら約30Gで折れます。", scene=BEAM0),
    dict(id="c7", text="56Gに収めるなら、押し上げは約130m以上。30Gなら約240m以上です。", scene=GB_S4A),
    dict(id="c8", text="人が耐えた記録は46G、ほんの一瞬。スペースシャトルの3Gなら、約3.5kmです。", scene=GB_S4B),
    dict(id="c9", text="3Gなら、船は何ともありません。きついのは、長く押される人のほうです。", scene=GB_3G),
    dict(id="c10", text="重い荷物をのせた棚つきの台車を急に押すと、先に壊れるのは棚。船も同じです。"),
])
P["s5"] = dict(title="全部そろえば届く", lines=[
    dict(id="c1", text="ワンピースのノックアップストリーム。作中の設定では、船は高さ7000mまで昇ります。", scene=COL0),
    dict(id="c2", text="水の勢いだけで、船はそこまで届くのか。", style="question", sub="水の勢いだけで\n船は【届く】のか", scene=QBLANK),
    dict(id="c3", text="答えは、届きます。ただし、条件が3つ要ります。", scene=CONDS),
    dict(id="c4", text="1つめ。水は、秒速370m以上で噴き出す。音より速く。", scene=SPEED_DIAL),
    dict(id="c5", text="2つめ。水は、太い柱にして、途切れさせない。空気にも負けません。", scene=COL0),
    dict(id="c6", text="3つめ。船は、数kmかけて、ゆっくり押し上げる。3Gなら、船も人も持ちます。", scene=GB_3G),
    dict(id="c7", text="条件がそろえば、先頭は約39秒で、7000mに着きます。", scene=COL1),
    dict(id="c8", text="ただし、世界一の噴水も火山も、秒速370mには届きません。", scene=B_FINAL),
    dict(id="c9", text="物理は、無理とは言いません。ただ、火山より速い水が要ります。"),
    dict(id="c10", text="噴水を見かけたら、てっぺんで水が広がる形を見てください。7000mの頂上も、同じ形です。", scene=FOUNTAIN),
])


def _finish(lines):
    """実験の札(exp)を次の行へ引き継ぎ、「失敗です」「成功です」の行に札を出す位置(行の中の割合)を足す。"""
    cur = 0
    res = []
    for l in lines:
        l = dict(l)
        if "exp" in l:
            cur = l["exp"]
        else:
            l["exp"] = cur
        for key, kind in (("失敗です", "fail"), ("成功です", "ok")):
            if key in l["text"]:
                l["verdict"] = (kind, l["text"].index(key) / len(l["text"]))
        res.append(l)
    return res


# 読みの直し(kana の出力を全行見て、違う所だけ。ひらがなで書く)
SAY = {
    ("ch1", "c2"): "さくちゅうの、せっていでは、ふねが、まず、つく、くものうみ、はくかい、は、たかさ、ななせんメートル。",
    ("ch1", "c3"): "ふじさんの、やく、にばい。そらじまが、ある、はくはくかい、は、さらに、うえの、いちまんメートルです。",
    ("ch1", "c11"): "せんきゅうひゃくはちじゅうねんの、セントヘレンズさん。ふきだす、はやさは、びょうそく、にひゃくから、さんびゃくさんじゅうメートルと、みつもられています。",
}


def ep_for(name: str) -> dict:
    p = dict(P[name])
    p["lines"] = _finish(p["lines"]) if name.startswith("ch") else p["lines"]
    p["lines"] = [dict(l, say=SAY[(name, l["id"])]) if (name, l["id"]) in SAY else l for l in p["lines"]]
    return dict(kind="sim", aspect="portrait" if name.startswith("s") else "landscape", credit=CREDIT_V if name.startswith("s") else CREDIT, **p)
