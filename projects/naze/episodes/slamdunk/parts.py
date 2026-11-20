"""スラムダンク「山王戦の最後、パスを受けて打てるか」。本編 6 章とショート 5 本の台本と画面。
ch1〜ch6・s1〜s5 の ep.py がここから読む。台本は scripts.md(2026-10-30 確定・ユーザー承認済み。行・数字・断り書きを変えない)、出典と計算は research.md。
作品の絵・キャラの絵は使わない(作品名は文字の札だけ)。AI の絵も使わない。図は scene.py が全部コードで描く(コート・ボール・選手は図形)。
出典: Woods ほか 2015, Frontiers in Human Neuroscience 9:131(単純反応時間)/ NBA・FIBA の0.3秒の決まり(英語版 Wikipedia「Trent Tucker Rule」経由・二次資料)/
バスケ用品メーカーの解説(受けて放すまでの時間)。距離・パスの速さ・受けて放す0.3秒は仮置き。飛ぶ時間・余り秒・跳び上がりの時間は自分の計算。"""

CREDIT = "反応時間の論文・NBAの決まり・自分の計算（距離・速さは仮置き）"
CREDIT_V = "反応時間の論文・自分の計算（距離・速さは仮置き）"

import re

GREEN, YEL, RED, WHITE, DIM, BLUE, ORANGE = "green", "yel", "red", "white", "dim", "blue", "orange"


def CARD(*rows):
    return dict(kind="formula", rows=list(rows))


def EXPCARD(n, text):
    return dict(kind="formula", rows=[(f"実験{n}", 130, YEL), (text, 66, WHITE)])


def seg(n, s, d, c, t, st, ghost=False):
    return dict(n=n, s=s, d=d, c=c, t=t, st=st, ghost=ghost)


RE = lambda st, ghost=False: seg("反応", 0, 0.22, "RE", "反応 0.22秒", st, ghost)
RE_G = lambda st: seg("反応", 0, 0.22, "RE", "反応 0.22秒　飛ぶより長い", st, True)

# 実験ごとの時間の帯。st は何段目で出るか
EX = {
    "E1": dict(remain=1.0, need=1.32, segs=[RE(1), seg("飛ぶ", 0.22, 0.5, "FL", "ボールが飛ぶ 0.5秒", 2), seg("受けて打つ", 0.72, 0.6, "CA", "受けて打つ 0.6秒", 3)]),
    "E2": dict(remain=1.0, need=1.1, segs=[RE(1), seg("飛ぶ", 0, 0.5, "FL", "ボールが飛ぶ 0.5秒", 2), seg("受けて打つ", 0.5, 0.6, "CA", "受けて打つ 0.6秒", 3)]),
    "E2L": dict(remain=2.0, need=1.1, xmax=2.2, segs=[seg("飛ぶ", 0, 0.5, "FL", "ボールが飛ぶ 0.5秒", 1), seg("受けて打つ", 0.5, 0.6, "CA", "受けて打つ 0.6秒", 2)]),
    "E3": dict(remain=1.0, need=0.9, segs=[RE(1), seg("飛ぶ", 0, 0.5, "FL", "ボールが飛ぶ 0.5秒", 2), seg("先に跳んで打つ", 0.5, 0.4, "CA", "先に跳んで打つ 0.4秒", 3)]),
    "E4": dict(remain=0.5, need=0.9, segs=[RE(1), seg("飛ぶ", 0, 0.5, "FL", "ボールが飛ぶ 0.5秒", 2), seg("先に跳んで打つ", 0.5, 0.4, "CA", "先に跳んで打つ 0.4秒", 3)]),
    "E5": dict(remain=0.5, need=0.6, need_st=3, br_st=4, segs=[seg("飛ぶ", 0, 0.2, "FL", "飛ぶ 0.2秒", 1), seg("打つ", 0.2, 0.4, "CA", "打つ 0.4秒", 2), RE_G(5)]),
    "E6": dict(remain=0.5, need=0.43, need_st=3, br_st=4, segs=[seg("飛ぶ", 0, 0.13, "FL", "飛ぶ 0.13秒", 1), seg("放す", 0.13, 0.3, "CA", "受けて放す 0.3秒", 2)]),
    "E7": dict(remain=0.3, need=0.43, need_st=3, br_st=4, segs=[seg("飛ぶ", 0, 0.13, "FL", "飛ぶ 0.13秒", 1), seg("放す", 0.13, 0.3, "CA", "受けて放す 0.3秒", 2)]),
    "E8": dict(remain=0.5, need=0.52, need_st=4, br_st=5, br_txt="足りない", segs=[seg("飛ぶ", 0, 0.13, "FL", "飛ぶ 0.13秒", 1), RE(2), seg("放す", 0.22, 0.3, "CA", "受けて放す 0.3秒", 3)]),
}


def TL(key, stage, **kw):
    return dict(kind="tl", stage=stage, **EX[key], **kw)


def MT(n, v, pv=None):
    return dict(n=n, v=v, pv=v if pv is None else pv)


def COURT(**kw):
    return dict(kind="court", **kw)


def BARS(rows, vmax, head=None, **kw):
    return dict(kind="bars", rows=rows, vmax=vmax, head=head, **kw)


BLU, YL, GR, RD, GY, OR = (90, 170, 235), (240, 200, 70), (110, 220, 140), (240, 90, 80), (190, 195, 205), (250, 165, 80)
B_REL = BARS([("平均", 0.6, "約0.6秒", OR), ("ステフィン・カリー（NBA）", 0.4, "約0.4秒", GR)], 0.7, "受けてから放すまで（メーカー資料）")
B_REL2 = BARS([("平均", 0.6, "約0.6秒", GY), ("トップ級", 0.4, "約0.4秒", GR)], 0.7, "受けてから放すまで（メーカー資料）", grow_from=2)
B_REL3 = BARS([("実験3　トップ級", 0.4, "0.4秒", GY), ("実験6　仮置き", 0.3, "0.3秒", OR)], 0.5, "受けて放す時間", grow_from=1)

NAMECARD = CARD(("漫画「スラムダンク」", 84, WHITE), ("山王戦　最後の1球", 100, YEL))
NAMEONLY = CARD(("漫画「スラムダンク」", 90, WHITE))
MB0 = dict(kind="meterbig", stage=0)
MB1 = dict(kind="meterbig", stage=1)
QBLANK = dict(kind="formula", rows=[])
PREM1 = CARD(("前提", 130, YEL), ("桜木は　パスが来ると読んで待っている", 60, WHITE), ("と考えて　計算する", 60, WHITE))
PREM2 = CARD(("前提", 130, YEL), ("桜木は　先に跳んで　0.4秒で打てた", 60, WHITE), ("絵からは　決まらない　だから仮に置く", 52, DIM))
PLACE = lambda a, b: CARD(("仮置き", 130, RED), (a, 66, WHITE), (b, 54, DIM))
SPAN = dict(kind="span")


def WALL(st):
    return dict(kind="wall", stage=st)


def SUR(st, hl=None, brace=None):
    rows = [("残り2秒・平均の速さ", 0.9, "ふつうの速さで間に合う"), ("残り1秒・トップ級の速さ", 0.1, "先に跳ぶ読みが要る"),
            ("残り0.5秒・限界を全部重ねる", 0.07, "現実には出ない組み合わせ"), ("残り0.3秒・限界でも", -0.13, "足りない")]
    return dict(kind="sur", stage=st, rows=rows, hl=hl, brace=brace)


def JUMP(st):
    return dict(kind="jump", stage=st)


# ---- 本編 ------------------------------------------------------------------------------------
E2_M5 = TL("E2", 5, meter=MT(2, -0.10, -0.32))
E3_M5 = TL("E3", 5, meter=MT(3, 0.10, -0.10))
E4_M5 = TL("E4", 5, meter=MT(4, -0.40, 0.10))
E5_M4 = TL("E5", 4, meter=MT(5, -0.10, -0.40))
E6_M4 = TL("E6", 4, meter=MT(6, 0.07, -0.10))
E7_M4 = TL("E7", 4, meter=MT(7, -0.13, 0.07))
FAIL, OK = "fail", "ok"

P = {}
P["ch1"] = dict(title="第1章 残りわずかなパス", cta=False, lines=[
    dict(id="c1", text="バスケットボールには、0.3秒の決まりがあります。", scene=CARD(("0.3秒", 280, YEL), ("バスケットボールの決まり", 60, WHITE))),
    dict(id="c2", text="試合が止まったあとの再開、スローインなどの場面です。", scene=CARD(("試合が止まったあとの再開", 72, WHITE), ("スローインなど", 100, YEL))),
    dict(id="c3", text="残りが0.3秒を切ったら。受けて打つシュートは、点になりません。", scene=CARD(("残りが0.3秒を切ったら", 80, WHITE), ("受けて打つシュートは", 80, WHITE), ("点にならない", 110, RED))),
    dict(id="c4", text="アメリカのプロリーグ、NBAの決まりです。", scene=CARD(("アメリカのプロリーグ", 70, WHITE), ("NBAの決まり", 120, YEL))),
    dict(id="c5", text="国際ルールを決める団体、FIBAにも。似た決まりがあるようです。", scene=CARD(("国際ルールを決める団体", 66, WHITE), ("FIBAにも", 120, YEL), ("似た決まりがあるようです", 56, WHITE))),
    dict(id="c6", text="受けて打つには、それ以上の時間が要る。そういう考えです。", scene=CARD(("受けて打つには", 80, WHITE), ("それ以上の時間が要る", 96, YEL))),
    dict(id="c7", text="漫画、スラムダンクの最後は、この決まりの場面とは違います。プレーは、続いている最中です。",
         scene=CARD(("漫画「スラムダンク」", 84, WHITE), ("最後は　決まりの場面とは違う", 64, YEL), ("プレーは　続いている最中", 64, WHITE))),
    dict(id="c8", text="でも、同じ壁を、計算で測れます。", scene=CARD(("同じ壁を", 84, WHITE), ("計算で測る", 130, YEL))),
    dict(id="c9", text="作中では、全国大会の2回戦。主人公たちの湘北が、強豪の山王と戦います。", scene=CARD(("全国大会　2回戦", 90, WHITE), ("湘北　対　山王", 120, YEL))),
    dict(id="c10", text="山王のエース、つまり得点役が決めて、山王が1点リード。残りは9秒ほどです。", scene=CARD(("湘北 77 − 78 山王", 110, YEL), ("山王が1点リード", 70, WHITE), ("残り　約9秒", 84, WHITE))),
    dict(id="c11", text="湘北の最後の攻め。高校1年生の流川が、ボールを運びます。", scene=COURT(d=4, ball="A", note="流川がボールを運ぶ")),
    dict(id="c12", text="流川がゴールの下へ切り込むと、山王の選手が集まります。", scene=COURT(d=4, ball="A", defenders=True, note="山王の選手が集まる")),
    dict(id="c13", text="そこで流川は、同じ1年生の桜木に、パスを出します。", scene=COURT(d=4, ball="fly", defenders=True, note="流川から桜木へパス")),
    dict(id="c14", text="桜木は、バスケを始めて間もない選手です。", scene=CARD(("桜木", 130, YEL), ("バスケを始めて　間もない選手", 66, WHITE))),
    dict(id="c15", text="桜木は、ジャンプシュートを打ちます。跳び上がって、頂点で放つシュートです。", scene=COURT(d=4, ball="shot", note="桜木のジャンプシュート")),
    dict(id="c16", text="ボールは入って、79対78。湘北の逆転勝ちです。", scene=CARD(("79 − 78", 170, YEL), ("湘北の逆転勝ち", 90, WHITE))),
    dict(id="c17", text="打つ前、桜木は「左手は、そえるだけ」とつぶやきます。", scene=CARD(("打つ前のつぶやき", 60, DIM), ("「左手は、そえるだけ」", 96, YEL))),
    dict(id="c18", text="パスが出たときの残りは、解説で「2秒」と「1秒」に割れます。", scene=CARD(("パスが出たときの残り", 72, WHITE), ("2秒　と　1秒", 140, YEL), ("解説で割れている", 56, DIM))),
    dict(id="c19", text="だから、短い1秒の場合を中心に、長い2秒の場合も見ます。", scene=CARD(("中心は　短い1秒", 100, YEL), ("長い2秒の場合も　見る", 80, WHITE))),
    dict(id="c20", text="問いは、これです。ボールが流川の手を離れてから、桜木の手を離れるまで。何秒かかるのか。", scene=SPAN),
    dict(id="c21", text="残りの時間で、間に合うのか。", style="question", sub="残りの時間で\n【間に合う】のか", scene=QBLANK),
    dict(id="c22", text="ものさしは、1つ。「余り秒」です。試合の残り時間から、必要な時間を引いた秒数です。", scene=MB0),
    dict(id="c23", text="プラスなら、間に合う。マイナスなら、間に合いません。", scene=MB1),
    dict(id="c24", text="道具は4つ。反応時間の論文、ルール、メーカーの数字、そして計算です。",
         scene=CARD(("道具は4つ", 100, YEL), ("反応時間の論文", 56, WHITE), ("ルール", 56, WHITE), ("メーカーの数字", 56, WHITE), ("そして計算", 56, WHITE))),
    dict(id="c25", text="実験していきます。", scene=CARD(("秒の足し算", 120, YEL), ("実験していきます", 66, WHITE))),
])

P["ch2"] = dict(title="第2章 実験1・2 足し算で外れる、重ねて直す", cta=False, lines=[
    dict(id="c1", text="実験1。まず、何も考えずに、時間を全部たし算します。", section=True, exp=1, scene=EXPCARD(1, "時間を全部たし算する")),
    dict(id="c2", text="残りは、短い1秒の場合で置きます。", scene=TL("E1", 0)),
    dict(id="c3", text="必要な時間は、3つの時間の足し算です。",
         scene=CARD(("必要な時間は　3つの足し算", 66, WHITE), ("①　反応する時間", 70, BLUE), ("②　ボールが飛ぶ時間", 70, YEL), ("③　受けて打つ時間", 70, ORANGE))),
    dict(id="c4", text="はじめに、桜木が、パスを見て反応する時間。", scene=TL("E1", 1)),
    dict(id="c5", text="光を見て、ボタンを押すまで。測った論文があります。若い大人の平均は、0.22秒。"),
    dict(id="c6", text="次に、ボールが飛ぶ時間。流川と桜木は、車1台ぶん、4m離れていると置きます。", scene=COURT(d=4, ball="A", dlabel="4m（車1台ぶん）")),
    dict(id="c7", text="飛ぶ時間は、距離を速さで割れば出ます。パスの速さは、秒速8mと置きます。時速29km。", scene=COURT(d=4, ball="fly", dlabel="4m", speed="秒速8m（時速29km）")),
    dict(id="c8", text="割り算します。4mを、秒速8mで割ります。", scene=CARD(("4m ÷ 秒速8m", 130, WHITE))),
    dict(id="c9", text="答えは、0.5秒です。", scene=TL("E1", 2)),
    dict(id="c10", text="4mと秒速8mは、測った数字ではありません。仮に置いた数字です。", scene=PLACE("4m と　秒速8m は", "測った数字ではない")),
    dict(id="c11", text="最後に、桜木が、ボールを受けてから、手を離すまで。", scene=TL("E1", 2, note="最後は　受けてから放すまで")),
    dict(id="c12", text="平均で、約0.6秒。用品メーカーの解説の数字です。測り方は書いてありません。", scene=CARD(("メーカー資料の数字", 60, DIM), ("平均で　約0.6秒", 110, YEL), ("測り方は　書いていない", 56, WHITE))),
    dict(id="c13", text="足し算します。反応が0.22秒。飛ぶ時間が0.5秒。", scene=TL("E1", 3)),
    dict(id="c14", text="受けて打つのが、0.6秒。合計は、1.32秒です。", scene=TL("E1", 4)),
    dict(id="c15", text="残りは1.0秒。余り秒は、マイナス0.32秒。", scene=TL("E1", 5, meter=MT(1, -0.32, 0.0))),
    dict(id="c16", text="間に合わない計算です。", v=(FAIL, "間に合わない計算です")),
    dict(id="c17", text="実験2。足し算が、まちがっていました。", section=True, exp=2, scene=EXPCARD(2, "足し算が　まちがっていた")),
    dict(id="c18", text="反応は、ボールが飛んでいるあいだに起きます。", scene=TL("E2", 2)),
    dict(id="c19", text="反応しているあいだに、ボールは1.8m進みます。", scene=COURT(d=4, ball="reach", p=0.45, dlabel="4m", reach_label="1.8m進む")),
    dict(id="c20", text="反応と飛ぶ時間は、重なる。長いほう、つまり飛ぶ0.5秒だけ数えます。", scene=TL("E2", 2, focus=1)),
    dict(id="c21", text="ここで、前提を1つ置きます。桜木は、パスが来ると読んで待っている、と考えて計算します。", scene=PREM1),
    dict(id="c22", text="飛ぶ0.5秒に、受けて打つ0.6秒を足します。", scene=TL("E2", 3)),
    dict(id="c23", text="合計は、1.1秒。余り秒は、マイナス0.1秒。", scene=E2_M5),
    dict(id="c24", text="まだ足りません。間に合わない計算です。", v=(FAIL, "間に合わない計算です")),
    dict(id="c25", text="足りないのは、わずか。次は、受けて打つ時間を縮められないか、試します。",
         scene=CARD(("足りないのは　わずか", 84, WHITE), ("次は　受けて打つ時間を", 70, YEL), ("縮められないか　試す", 70, YEL))),
])

P["ch3"] = dict(title="第3章 実験3 先に跳んで、間に合わせる", cta=False, lines=[
    dict(id="c1", text="余り秒は、マイナス0.1秒。足りないのは、ボールが80cm進むあいだです。", scene=TL("E2", 5, meter=MT(2, -0.10, -0.10))),
    dict(id="c2", text="実験3。受けて打つ時間を、縮めます。", section=True, exp=3, scene=EXPCARD(3, "受けて打つ時間を縮める")),
    dict(id="c3", text="ジャンプシュートは、跳び上がった頂点で放します。", scene=JUMP(0)),
    dict(id="c4", text="受けてから跳ぶと、頂点まで約0.3秒かかります。重力の式で出した計算です。", scene=JUMP(1)),
    dict(id="c5", text="先に跳べば、受けたときには、もう空中です。その分の時間が、浮きます。", scene=JUMP(2)),
    dict(id="c6", text="NBAのステフィン・カリー選手は、約0.4秒。用品メーカーの解説の数字です。", scene=B_REL),
    dict(id="c7", text="この速さを、トップ級と呼びます。さっきの0.6秒は、平均です。", scene=B_REL2),
    dict(id="c8", text="桜木が、先に跳んで、0.4秒で打てたか。絵からは決まりません。", scene=PREM2),
    dict(id="c9", text="先に跳んで打てた、と考えて、0.4秒と置きます。飛ぶ時間は、0.5秒のまま。", scene=TL("E3", 3)),
    dict(id="c10", text="合計は、0.9秒。残りは、1.0秒。", scene=TL("E3", 4)),
    dict(id="c11", text="余り秒は、プラス0.1秒。", scene=E3_M5),
    dict(id="c12", text="計算では、間に合います。", v=(OK, "計算では、間に合います")),
    dict(id="c13", text="ただし、ぎりぎり。プラス0.1秒は、ボールが80cm進むあいだだけです。"),
    dict(id="c14", text="距離も速さも、仮に置いた数字です。0.1秒の余りは、すぐ動きます。", scene=CARD(("距離も　速さも　仮置き", 72, WHITE), ("0.1秒の余りは", 72, WHITE), ("すぐ動く", 120, RED))),
    dict(id="c15", text="平均の0.6秒に戻すと、マイナス0.1秒。", scene=TL("E2", 5, meter=MT(2, -0.10, 0.10))),
    dict(id="c16", text="長い2秒の場合なら、平均の速さでも、プラス0.9秒です。", exp="残り2秒の場合", scene=TL("E2L", 4, br_st=4, need_st=3)),
    dict(id="c17", text="残りが1秒か2秒かで、答えの重さが変わります。", scene=CARD(("残りが　1秒か　2秒か", 80, WHITE), ("答えの重さが　変わる", 90, YEL))),
    dict(id="c18", text="では、残りが短くなったら。", scene=CARD(("では　残りが", 80, WHITE), ("短くなったら", 120, YEL))),
])

P["ch4"] = dict(title="第4章 実験4・5 残りを削る、パスを速くする", cta=False, lines=[
    dict(id="c1", text="余り秒は、プラス0.1秒。ここから、残りを削ります。", scene=TL("E3", 5, meter=MT(3, 0.10, 0.10))),
    dict(id="c2", text="実験4。残りを、0.5秒にします。", section=True, exp=4, scene=EXPCARD(4, "残りを　0.5秒にする")),
    dict(id="c3", text="動きは、実験3のまま。必要な時間は、0.9秒です。", scene=TL("E4", 4)),
    dict(id="c4", text="余り秒は、マイナス0.4秒。", scene=E4_M5),
    dict(id="c5", text="ボールが桜木の手に着くのは、0.5秒後。その瞬間に、残りは0になります。",
         scene=TL("E4", 5, meter=MT(4, -0.40), flag=dict(x=0.5, lane=2, st=5, t="着いた瞬間に　残り0"))),
    dict(id="c6", text="打つ前に、終わりです。間に合わない計算です。", v=(FAIL, "間に合わない計算です")),
    dict(id="c7", text="実験5。パスを、近く、速くします。", section=True, exp=5, scene=EXPCARD(5, "パスを　近く　速くする")),
    dict(id="c8", text="距離は、3mに縮めます。速さは、秒速15m。", scene=COURT(d=3, ball="fly", dlabel="3m", speed="秒速15m")),
    dict(id="c9", text="時速に直すと、54kmです。", scene=CARD(("秒速15m", 110, WHITE), ("＝　時速54km", 110, YEL))),
    dict(id="c10", text="手で投げる限界に近い、仮に置いた数字です。測った数字は、見つかっていません。", scene=PLACE("手で投げる限界に近い数字", "測った数字は　見つかっていない")),
    dict(id="c11", text="割り算します。3mを、秒速15mで割ります。", scene=CARD(("3m ÷ 秒速15m", 130, WHITE))),
    dict(id="c12", text="答えは、0.2秒です。", scene=TL("E5", 1)),
    dict(id="c13", text="受けて打つのは、トップ級の0.4秒のまま。合計は、0.6秒です。", scene=TL("E5", 3)),
    dict(id="c14", text="残りは0.5秒。余り秒は、マイナス0.1秒。", scene=E5_M4),
    dict(id="c15", text="まだ少し足りません。間に合わない計算です。", v=(FAIL, "間に合わない計算です")),
    dict(id="c16", text="飛ぶ時間は0.2秒。ところが、反応は0.22秒です。反応のほうが、長くなりました。", scene=TL("E5", 5, meter=MT(5, -0.10))),
    dict(id="c17", text="つまり、読んで待っていないと、このパスには間に合いません。", scene=CARD(("読んで待っていないと", 72, WHITE), ("このパスには", 72, WHITE), ("間に合わない", 120, RED))),
    dict(id="c18", text="ここまでの計算は、読んで待っている前提でした。", scene=CARD(("ここまでの計算は", 64, DIM), ("読んで待っている前提", 100, YEL))),
    dict(id="c19", text="では、人間の限界を、全部入れたら。", scene=CARD(("人間の限界を", 84, WHITE), ("全部入れたら", 130, YEL))),
])

P["ch5"] = dict(title="第5章 実験6・7 限界を全部入れる、0.3秒の壁", cta=False, lines=[
    dict(id="c1", text="実験6。人間の最短を、全部入れます。", section=True, exp=6, scene=EXPCARD(6, "人間の最短を　全部入れる")),
    dict(id="c2", text="距離は、2m。パスは、秒速15m。", scene=COURT(d=2, ball="fly", dlabel="2m", speed="秒速15m")),
    dict(id="c3", text="割り算します。2mを、秒速15mで割ります。", scene=CARD(("2m ÷ 秒速15m", 130, WHITE))),
    dict(id="c4", text="答えは、0.13秒です。", scene=TL("E6", 1)),
    dict(id="c5", text="受けて放すのは、0.3秒と仮に置きます。冒頭の決まりが下限と見る数字を、借りました。", scene=PLACE("受けて放すのは　0.3秒", "冒頭の決まりが下限と見る数字を借りた")),
    dict(id="c6", text="跳ぶ高さを、50cmから40cmに変えます。", scene=CARD(("跳ぶ高さ", 72, WHITE), ("50cm → 40cm", 120, YEL))),
    dict(id="c7", text="頂点までは0.29秒。仮に置いた0.3秒に近い数字です。", scene=CARD(("頂点まで　0.29秒", 110, YEL), ("仮に置いた　0.3秒に近い", 64, WHITE))),
    dict(id="c8", text="実験3の0.4秒より、さらに短い仮置きです。", scene=B_REL3),
    dict(id="c9", text="合計は、0.43秒。残りは、0.5秒。", scene=TL("E6", 3)),
    dict(id="c10", text="余り秒は、プラス0.07秒。", scene=E6_M4),
    dict(id="c11", text="計算では、届きます。", v=(OK, "計算では、届きます")),
    dict(id="c12", text="でも、限界を全部、同時に出した組み合わせです。現実には出ません。", scene=CARD(("限界を　全部　同時に出す", 72, WHITE), ("現実には　出ない組み合わせ", 80, RED))),
    dict(id="c13", text="実験7。同じ組み合わせで、残りを0.3秒にします。", section=True, exp=7, scene=EXPCARD(7, "残りを　0.3秒にする")),
    dict(id="c14", text="時計の残りが0.3秒。必要な時間は、0.43秒。", scene=TL("E7", 3)),
    dict(id="c15", text="余り秒は、マイナス0.13秒。", scene=E7_M4),
    dict(id="c16", text="限界を全部出しても、足りません。間に合わない計算です。", v=(FAIL, "間に合わない計算です")),
    dict(id="c17", text="ここで、冒頭の、ルールの0.3秒と見比べます。", scene=WALL(0)),
    dict(id="c18", text="この決まりは、ふれた瞬間から時計が動く場面のものです。", scene=WALL(1)),
    dict(id="c19", text="漫画の最後は、パスが飛ぶ間も時計が進んでいる、と考えます。", scene=WALL(2)),
    dict(id="c20", text="そうなら、飛ぶ0.13秒が、必要な時間に加わります。", scene=WALL(3)),
    dict(id="c21", text="この仮置きでは、壁は約0.43秒。これより短いと、計算では届きません。", scene=WALL(4)),
    dict(id="c22", text="もう1つ、条件を変えます。桜木が、読んで待っていなかったら。", exp="条件を変える", scene=CARD(("もう1つ　条件を変える", 72, WHITE), ("桜木が　読んで待っていなかったら", 64, YEL))),
    dict(id="c23", text="飛ぶ時間は0.13秒。反応の0.22秒のほうが、長い。", scene=TL("E8", 2)),
    dict(id="c24", text="反応0.22秒に、受けて放す0.3秒を足します。", scene=TL("E8", 3)),
    dict(id="c25", text="合計は、0.52秒です。", scene=TL("E8", 4)),
    dict(id="c26", text="読んで待っていないと、残り0.5秒でも、届きません。", scene=TL("E8", 5)),
])

P["ch6"] = dict(title="第6章 答えと、最後の1球", lines=[
    dict(id="c1", text="答えを、まとめます。", scene=SUR(0)),
    dict(id="c2", text="長い2秒の場合。平均の速さで、余り秒はプラス0.9秒。間に合います。", scene=SUR(1)),
    dict(id="c3", text="短い1秒の場合。トップ級の速さで、プラス0.1秒。ぎりぎりです。", scene=SUR(2)),
    dict(id="c4", text="残り0.5秒。限界を全部重ねて、プラス0.07秒。計算上は届く。でも、現実には出ない組み合わせです。", scene=SUR(3)),
    dict(id="c5", text="残り0.3秒。限界でも、マイナス0.13秒。", scene=SUR(4)),
    dict(id="c6", text="漫画の残りが1秒から2秒なら、計算上は、間に合う範囲でした。", scene=SUR(4, hl=(0, 1), brace="漫画の残り　1〜2秒")),
    dict(id="c7", text="2秒なら、普通の速さで間に合う。", scene=SUR(4, hl=(0,), brace="漫画の残り　1〜2秒")),
    dict(id="c8", text="1秒なら、トップ級の速さと、先に跳ぶ読みが要る。0.5秒は、限界を全部重ねて、やっと。", scene=SUR(4, hl=(1, 2), brace="漫画の残り　1〜2秒")),
    dict(id="c9", text="答えは、これです。間に合う範囲。ただし、余りは少ない。", scene=CARD(("答え", 110, YEL), ("間に合う範囲", 110, GREEN), ("ただし　余りは少ない", 70, WHITE))),
    dict(id="c10", text="冒頭の、0.3秒の決まりに戻ります。", scene=CARD(("冒頭の", 70, WHITE), ("0.3秒の決まり", 140, YEL), ("に戻る", 70, WHITE))),
    dict(id="c11", text="あの決まりは、ふれた瞬間から時計が動く場面のものでした。", scene=WALL(1)),
    dict(id="c12", text="漫画の最後は、飛ぶ時間も入ります。この仮置きでは、壁は約0.43秒。", scene=WALL(3)),
    dict(id="c13", text="これより短いと、計算では届きません。", scene=WALL(4)),
    dict(id="c14", text="次にバスケの終盤を見たら、残り時間を見てください。", scene=CARD(("次にバスケの終盤を見たら", 64, WHITE), ("残り時間を見てください", 80, YEL))),
    dict(id="c15", text="ボールが飛ぶ時間も、一緒に数えてみてください。", scene=CARD(("ボールが飛ぶ時間も", 84, WHITE), ("一緒に数えてみてください", 72, YEL))),
])

# ---- ショート ----------------------------------------------------------------------------------
INTRO = "スラムダンクの山王戦、最後の1球。流川のパスを、桜木が受けて決めた。"
METER = "ものさしは、余り秒。時計の残りから、必要な時間を引いた数です。プラスなら、間に合います。"
SHORT1 = "残りは、短い1秒の場合で見ます。"

P["s1"] = dict(title="0.3秒の決まり", lines=[
    dict(id="c1", text="バスケットボールには、0.3秒の決まりがあります。", scene=CARD(("0.3秒", 280, YEL), ("バスケットボールの決まり", 56, WHITE))),
    dict(id="c2", text="スローインなど、止まった試合の再開で。残りが0.3秒を切ったら。", scene=CARD(("スローインなど", 90, YEL), ("止まった試合の再開で", 62, WHITE), ("残りが0.3秒を切ったら", 62, WHITE))),
    dict(id="c3", text="受けて打つシュートは、点になりません。アメリカのプロリーグ、NBAの決まりです。", scene=CARD(("受けて打つシュートは", 66, WHITE), ("点にならない", 110, RED), ("NBAの決まり", 70, YEL))),
    dict(id="c4", text="国際ルールを決める団体、FIBAにも。似た決まりがあるようです。", scene=CARD(("国際ルールの団体", 66, WHITE), ("FIBAにも", 120, YEL), ("似た決まりがあるようです", 52, WHITE))),
    dict(id="c5", text="漫画、スラムダンクの山王戦、最後の1球。", scene=NAMECARD),
    dict(id="c6", text="作中では、流川のパスを桜木が受けて決めます。湘北が79対78で逆転します。", scene=CARD(("流川のパスを", 72, BLUE), ("桜木が受けて決める", 72, ORANGE), ("79 − 78　湘北が逆転", 80, YEL))),
    dict(id="c7", text="パスが出たときの残りは、解説で「2秒」と「1秒」に割れます。", scene=CARD(("パスが出たときの残り", 66, WHITE), ("2秒　と　1秒", 130, YEL), ("解説で割れている", 52, DIM))),
    dict(id="c8", text="山王戦の最後は、この決まりの場面とは違う。でも、同じ壁を、計算で測れます。", scene=CARD(("決まりの場面とは　違う", 66, WHITE), ("でも　同じ壁を", 66, WHITE), ("計算で測れる", 110, YEL))),
    dict(id="c9", text="間に合うのか。次から、計算で確かめます。", style="question", sub="【間に合う】のか\n次から、計算で確かめます", scene=QBLANK),
])

P["s2"] = dict(title="反応は間に合うか", lines=[
    dict(id="c1", text=INTRO, scene=NAMECARD),
    dict(id="c2", text=METER, scene=MB1),
    dict(id="c3", text=SHORT1, scene=TL("E1", 0)),
    dict(id="c4", text="実験1。時間を、全部たし算します。", section=True, exp=1, scene=EXPCARD(1, "時間を全部たし算する")),
    dict(id="c5", text="光を見てボタンを押す反応。若い大人の平均は、0.22秒です。", scene=TL("E1", 1)),
    dict(id="c6", text="ボールが飛ぶ時間は、0.5秒。距離と速さは、仮に置いた数字です。", scene=TL("E1", 2)),
    dict(id="c7", text="受けて打つのは、平均で0.6秒。用品メーカーの解説の数字です。", scene=TL("E1", 3)),
    dict(id="c8", text="合計は、1.32秒。余り秒は、マイナス0.32秒。間に合わない計算です。", scene=TL("E1", 5, meter=MT(1, -0.32, 0.0)), v=(FAIL, "間に合わない計算です")),
    dict(id="c9", text="直します。反応は、ボールが飛んでいるあいだに起きます。反応のあいだに、ボールは1.8m進みます。", exp=2,
         scene=COURT(d=4, ball="reach", p=0.45, dlabel="4m", reach_label="1.8m進む")),
    dict(id="c10", text="桜木は、パスが来ると読んで待っている、と考えます。長いほうだけ数えて、合計は1.1秒。", scene=TL("E2", 4, note="前提：読んで待っている")),
    dict(id="c11", text="余り秒は、マイナス0.1秒。まだ足りません。", scene=E2_M5),
])

P["s3"] = dict(title="先に跳ぶ", lines=[
    dict(id="c1", text=INTRO, scene=NAMECARD),
    dict(id="c2", text=METER, scene=MB1),
    dict(id="c3", text=SHORT1, scene=TL("E2", 0)),
    dict(id="c4", text="平均の速さで計算すると、余り秒はマイナス0.1秒。足りません。", scene=TL("E2", 5, meter=MT(2, -0.10, -0.10))),
    dict(id="c5", text="実験3。受けて打つ時間を、縮めます。", section=True, exp=3, scene=EXPCARD(3, "受けて打つ時間を縮める")),
    dict(id="c6", text="ジャンプシュートは、跳び上がった頂点で放します。", scene=JUMP(0)),
    dict(id="c7", text="受けてから跳ぶと、頂点まで約0.3秒。先に跳べば、受けたときには、もう空中です。", scene=JUMP(2)),
    dict(id="c8", text="用品メーカーの解説では、NBAのカリーが、約0.4秒。トップ級の速さです。", scene=B_REL),
    dict(id="c9", text="桜木が先に跳んで、0.4秒で打てた、と考えます。", scene=PREM2),
    dict(id="c10", text="0.4秒と置くと、合計は0.9秒。", scene=TL("E3", 4)),
    dict(id="c11", text="余り秒は、プラス0.1秒。計算では、間に合います。", scene=E3_M5, v=(OK, "計算では、間に合います")),
    dict(id="c12", text="ただし、仮に置いた数字の誤差で、すぐ消える余りです。", scene=CARD(("仮に置いた数字の誤差で", 62, WHITE), ("すぐ消える余り", 100, RED))),
])

P["s4"] = dict(title="残りを削る", lines=[
    dict(id="c1", text=INTRO, scene=NAMECARD),
    dict(id="c2", text=METER, scene=MB1),
    dict(id="c3", text="残りが0.5秒だったら、どうなるか。", scene=CARD(("残りが", 80, WHITE), ("0.5秒だったら", 120, YEL))),
    dict(id="c4", text="実験4。トップ級の動きで、必要な時間は0.9秒。残りを、0.5秒にします。", section=True, exp=4, scene=TL("E4", 4)),
    dict(id="c5", text="余り秒は、マイナス0.4秒。ボールが着く瞬間に、残りは0。間に合わない計算です。",
         scene=TL("E4", 5, meter=MT(4, -0.40, 0.0), flag=dict(x=0.5, lane=2, st=5, t="着いた瞬間に　残り0")), v=(FAIL, "間に合わない計算です")),
    dict(id="c6", text="実験5。パスを、近く、速くします。距離は3m、速さは秒速15mです。", section=True, exp=5, scene=COURT(d=3, ball="fly", dlabel="3m", speed="秒速15m")),
    dict(id="c7", text="時速では54km。手で投げる限界に近い、仮に置いた数字です。", scene=PLACE("秒速15m ＝ 時速54km", "手で投げる限界に近い数字")),
    dict(id="c8", text="飛ぶ時間は0.2秒。受けて打つのは、トップ級の0.4秒。", scene=TL("E5", 2)),
    dict(id="c9", text="合計は0.6秒。", scene=TL("E5", 3)),
    dict(id="c10", text="余り秒は、マイナス0.1秒。まだ足りません。", scene=E5_M4),
    dict(id="c11", text="しかも、飛ぶ0.2秒は、反応の0.22秒より短い。読んで待っていないと、間に合いません。", scene=TL("E5", 5, meter=MT(5, -0.10))),
])

P["s5"] = dict(title="0.3秒の壁", lines=[
    dict(id="c1", text=INTRO, scene=NAMECARD),
    dict(id="c2", text=METER, scene=MB1),
    dict(id="c3", text="人間の限界を、全部入れて計算します。", scene=CARD(("人間の限界を", 84, WHITE), ("全部入れて計算", 100, YEL))),
    dict(id="c4", text="実験6。距離は2m、パスは秒速15m。飛ぶ時間は、0.13秒です。", section=True, exp=6, scene=COURT(d=2, ball="fly", dlabel="2m", speed="秒速15m")),
    dict(id="c5", text="受けて放すのは、0.3秒と仮に置きます。バスケの0.3秒の決まりが、下限と見る数字を借りました。", scene=PLACE("受けて放すのは　0.3秒", "0.3秒の決まりが下限と見る数字を借りた")),
    dict(id="c6", text="合計は、0.43秒。残りは0.5秒。", scene=TL("E6", 3)),
    dict(id="c7", text="余り秒は、プラス0.07秒。", scene=E6_M4),
    dict(id="c8", text="計算では届く。でも、限界を全部重ねた、現実には出ない組み合わせです。", v=(OK, "計算では届く")),
    dict(id="c9", text="同じ組み合わせで、残りを0.3秒にします。余り秒は、マイナス0.13秒。足りません。", exp=7, scene=E7_M4, v=(FAIL, "足りません")),
    dict(id="c10", text="0.3秒の決まりは、ふれた瞬間から時計が動く場面のもの。漫画の最後は、飛ぶ時間も入ります。", scene=WALL(2)),
    dict(id="c11", text="この仮置きでは、壁は約0.43秒。これより短いと、計算では届きません。", scene=WALL(4)),
    dict(id="c12", text="漫画の残りは、1秒から2秒。計算上は、間に合う範囲でした。", scene=CARD(("漫画の残りは　1〜2秒", 62, WHITE), ("計算上は", 70, WHITE), ("間に合う範囲", 120, GREEN))),
])


def _finish(lines):
    """実験の札(exp)を次の行へ引き継ぎ、判定の札(v)に、札を出す位置(行の中の割合)を足す。"""
    cur = 0
    res = []
    for l in lines:
        l = dict(l)
        if "exp" in l:
            cur = l["exp"]
        else:
            l["exp"] = cur
        if "v" in l:
            kind, phrase = l.pop("v")
            assert phrase in l["text"], (l["id"], phrase)
            l["verdict"] = (kind, l["text"].index(phrase) / len(l["text"]))
        res.append(l)
    return res


# 読みの直し(kana の出力を全行見て、違う所だけ)。長い語から順に置き換えて say を作る(字幕は台本のまま)
YOMI = [("ステフィン・カリー", "すてぃーふぃん・かりー"), ("カリー", "かりー"), ("スラムダンク", "すらむだんく"), ("湘北", "しょうほく"), ("山王", "さんのう"),
        ("流川", "るかわ"), ("桜木", "さくらぎ"), ("沢北", "さわきた"), ("NBA", "えぬびーえー"), ("FIBA", "ふぃば"), ("左手は、そえるだけ", "ひだりては、そえるだけ"),
        ("余り秒", "あまりびょう"), ("2回戦", "にかいせん"), ("1年生", "いちねんせい"), ("車1台", "くるまいちだい"), ("論文", "ろんぶん"), ("頂点", "ちょうてん"),
        ("〜", "から")]


def yomi(text):
    s = text
    for a, b in YOMI:
        s = s.replace(a, b)
    return s


def ep_for(name: str) -> dict:
    p = dict(P[name])
    p["lines"] = _finish(p["lines"])
    res = []
    for l in p["lines"]:
        y = yomi(l["text"])
        res.append(dict(l, say=y) if y != l["text"] else l)
    p["lines"] = res
    return dict(kind="sim", aspect="portrait" if name.startswith("s") else "landscape", credit=CREDIT_V if name.startswith("s") else CREDIT, **p)
