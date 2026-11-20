"""テニスの王子様「サムライドライブ」(割れたボールは返せるのか)。本編 6 章とショート 5 本の台本と画面。
ch1〜ch6・s1〜s5 の ep.py がここから読む。台本は scripts.md(2026-10-29 確定。行・数字・断り書きを変えない)、出典と計算は research.md。
作品の絵・キャラの絵は使わない(作品名と技名は文字の札だけ)。AI の絵も使わない。図は scene.py が全部コードで描く。
出典: ITF Rules of Tennis 2026(ボール・ネット・ラケットの規則)/ Goodwill ほか 2007(デビスカップ1試合の回転)/ Kwon ほか 2017 J Sports Sci Med 16:505 /
Cross & Lindsey 2013 / Goodwill ほか 2004(空気抵抗・揚力の係数)。角度・外れ幅・エネルギーは research.md の計算(初速・高さは仮置き)。"""

CREDIT = "ITF規則2026・測定の論文・自分の計算（球速・回転・高さは仮置き）"
CREDIT_V = "ITF規則2026・自分の計算（球速・回転は仮置き）"

import re

GREEN, YEL, RED, WHITE, DIM = "green", "yel", "red", "white", "dim"


def CARD(*rows):
    return dict(kind="formula", rows=list(rows))


def EXPCARD(n, text):
    return dict(kind="formula", rows=[(f"実験{n}", 130, YEL), (text, 66, WHITE)])


def M(n, stage=1):
    return dict(n=n, stage=stage)


def COURT(paths=(), meter=None, stage=3, **kw):
    d = dict(kind="court", paths=list(paths), stage=stage, **kw)
    if meter is not None:
        d["meter"] = meter
    return d


def G(p):
    return dict(p, ghost=True)


PA1 = dict(ang=3.47, off=0)
PA2 = dict(ang=3.47, off=13, hit=True, gap="13cm低い・ボール2個分")
PA3 = dict(ang=4.11, off=0, land=18.0, show_land="着地 18.0m先")
PA4 = dict(ang=4.11, off=58, hit=True, gap="58cm低い・ボール約9個分")
PA5 = dict(ang=6.93, off=0, land=16.2, show_land="着地 16.2m先")
PA6 = dict(ang=8.82, off=0, land=15.5, show_land="着地 15.5m先")
PA7 = dict(ang=6.93, off=0, land=16.2)

NAMECARD = CARD(("漫画「テニスの王子様」", 84, WHITE), ("技「サムライドライブ」", 100, YEL))
C_START = dict(kind="court", paths=[], stage=1)
C_DIST = dict(kind="court", paths=[], stage=2)
SPEED0 = dict(kind="speed", stage=0)
SPEED1 = dict(kind="speed", stage=1)
NET0 = dict(kind="netsec", stage=0)
NET1 = dict(kind="netsec", stage=1)
NET2 = dict(kind="netsec", stage=2)
NET3 = dict(kind="netsec", stage=3)
WIN1 = dict(kind="window", stage=1, meter=dict(n=0, stage=1, zero=True))
ANGL0 = dict(kind="angline", stage=0)
ANGL1 = dict(kind="angline", stage=1)
DEG1 = dict(kind="deg1")
UNC0 = dict(kind="uncert", stage=0)
UNC1 = dict(kind="uncert", stage=1)
QBLANK = dict(kind="formula", rows=[])
BALLSIZE = dict(kind="ballsize")
NETH = dict(kind="netheight")
AIRDRAG = dict(kind="airdrag")
MAGNUS = dict(kind="magnus")
SPIN0 = dict(kind="spin", stage=0)
SPIN1 = dict(kind="spin", stage=1, v1=3000)
SPIN2 = dict(kind="spin", stage=2, v0=3000, v1=5000)
SPIN2S = dict(kind="spin", stage=2, v0=5000, v1=5000)
RUB0 = dict(kind="rub", stage=0)
RUB1 = dict(kind="rub", stage=1)
RUB2 = dict(kind="rub", stage=2)
HALVES0 = dict(kind="halves", stage=0)
SHELLS0 = dict(kind="shells", stage=0)
SHELLS1 = dict(kind="shells", stage=1)
SPREAD0 = dict(kind="spread", stage=0)
SPREAD1 = dict(kind="spread", stage=1)
APPLE0 = dict(kind="apple", stage=0)
APPLE1 = dict(kind="apple", stage=1)
BSEC0 = dict(kind="ballsec", stage=0)
BSEC1 = dict(kind="ballsec", stage=1)
MB0 = dict(kind="meterbig", stage=0)
MB2 = dict(kind="meterbig", stage=2)
MB3 = dict(kind="meterbig", stage=3)
FACE0 = dict(kind="face", stage=0)
FACE1 = dict(kind="face", stage=1)
FACE2 = dict(kind="face", stage=2)
FACE3 = dict(kind="face", stage=3, meter=dict(n=8))
FACE4 = dict(kind="face", stage=4, meter=dict(n=9))
FACE0M = dict(kind="face", stage=0, meter=dict(n=0, frame=True))
Y_ = (255, 214, 64)
W_ = (255, 255, 255)


def ANG(rays, tri=None, head=None):
    return dict(kind="angle", rays=rays, tri=tri, head=head)


ANG1 = ANG([(3.47, "3.47°", Y_, False)], head="角度 = 打ち出す向き（水平から上向き）")
ANG1T = ANG([(3.47, "3.47°", Y_, False)], tri=("1m進んで", "6cm上がる"), head="3.47°の角度")
ANG2 = ANG([(3.47, "3.47°", W_, True), (4.11, "4.11°", Y_, False)], head="0.64°だけ、上げる")
ANG3 = ANG([(4.11, "4.11°", Y_, False)], head="直したばかりの角度のまま")
ANG4 = ANG([(4.11, "4.11°", W_, True), (6.93, "6.93°", Y_, False)], tri=("1m進んで", "12cm上がる"), head="回転で下に曲がる分、さらに上へ")


def BARS(rows, vmax, head=None, **kw):
    return dict(kind="bars", rows=rows, vmax=vmax, head=head, **kw)


BLU, YL, GR, RD, GY = (90, 170, 235), (240, 200, 70), (110, 220, 140), (240, 90, 80), (190, 195, 205)
B_TIMES = BARS([("空気を考えない", 0.4, None, "約0.4秒", GY), ("空気を考える", 0.45, None, "約0.45秒", YL)], 0.55, "ネットに着く時間")
B_G = BARS([("重力", 9.8, None, "1秒に 秒速9.8mずつ", GY), ("回転が下へ押す力", 6.8, None, "1秒に 秒速6.8mずつ（約0.7倍）", RD)], 11, "落ちる速さの増え方")
B_969 = BARS([("大学男子13人の平均", 969, None, "969回転", GR)], 5400, "実際に測られた回転（毎分）")
B_DAVIS = BARS([("大学男子13人の平均", 969, None, "969回転", GR), ("デビスカップ1試合の最大", 3800, 4300, "3,800〜4,300回転", YL)], 5400, "実際に測られた回転（毎分）", grow_from=1)
B_5000 = BARS([("大学男子13人の平均", 969, None, "969回転", GR), ("デビスカップ1試合の最大", 3800, 4300, "3,800〜4,300回転", YL),
               ("5,000回転", 5000, None, "5,000回転　その最大を超える", RD)], 5400, "実際に測られた回転（毎分）", grow_from=2)
B_5000S = BARS([("大学男子13人の平均", 969, None, "平均969回転", GR), ("5,000回転", 5000, None, "5,000回転　約5倍", RD)], 5400, "実際に測られた回転（毎分）", grow_from=1)
B_DAVIS5 = BARS([("デビスカップ1試合の最大", 3800, 4300, "3,800〜4,300回転", YL), ("5,000回転", 5000, None, "5,000回転　さらに上", RD)], 5400, "実際に測られた回転（毎分）", grow_from=1)
B_SAFE = BARS([("測られた最大", 3800, 4300, "3,800〜4,300回転", YL), ("実験7の回転", 3000, None, "3,000回転（最大の約7〜8割）", GR)], 5400, "測られた範囲にそろえる", grow_from=1)
B_RUB = BARS([("5,000回転", 29, None, "秒速29m（時速約105km）", RD), ("実験7の3,000回転", 17.5, None, "秒速17.5m（時速約63km）", GR)], 34, "ラケットがこする速さ", grow_from=0)
B_E1 = BARS([("3,000回転", 2.1, None, "2.1ジュール", GR), ("殻を裂く目安", 3, 7, "3〜7ジュール", YL), ("3,800回転", 3.4, None, "3.4ジュール", GR), ("5,000回転", 5.9, None, "5.9ジュール", GR)], 8, "回転のエネルギー", grow_from=0)
B_E2 = BARS([("3,000回転", 2.1, None, "2.1ジュール　足りない", RD), ("殻を裂く目安", 3, 7, "3〜7ジュール", YL)], 8, "成功した回転では足りない", grow_from=0)
B_ARRIVE = BARS([("背を前にした殻", 0.60, None, "0.60秒", GR), ("くぼみを前にした殻", 1.0, None, "1.0秒", RD), ("丸いままの球", 0.56, None, "0.56秒", GY)], 1.2, "ネットから一番後ろの線まで 11.9m", grow_from=0)
B_SLOW = BARS([("実験8の速さ", 0.5, None, "秒速0.5m（時速1.8km）", RD), ("実験9の速さ", 0.1, None, "秒速0.1m前後以下（時速0.4km）", GR)], 0.6, "2つが横へ離れる速さ", grow_from=0)

C_E7 = COURT([PA7], M(7))
P = {}

P["ch1"] = dict(title="第1章 ネットの上端で、ボールを割る", cta=False, lines=[
    dict(id="c1", text="漫画、テニスの王子様の技、サムライドライブ。", scene=NAMECARD),
    dict(id="c2", text="ものすごい回転のボールを、ネットの上端で真っ二つにする技です。", scene=NET0),
    dict(id="c3", text="使うのは、主人公の中学生、リョーマ。", scene=CARD(("使うのは", 80, WHITE), ("主人公の中学生　リョーマ", 90, YEL))),
    dict(id="c4", text="最終巻の42巻、決勝の1球。相手は強敵の幸村です。", scene=CARD(("最終巻 42巻　決勝の1球", 84, YEL), ("相手は 強敵の幸村", 84, WHITE))),
    dict(id="c5", text="幸村は、割れた2つを、両方返します。", scene=HALVES0),
    dict(id="c6", text="返ってきた2つを、リョーマが打ち返して、勝負が決まります。"),
    dict(id="c7", text="テニスボールは、重さ約57g。卵1個ほどです。直径は6.7cm。", scene=BALLSIZE),
    dict(id="c8", text="ネットの真ん中の高さは、0.914m。大人の腰の少し下です。", scene=NETH),
    dict(id="c9", text="その上端で、このボールを割るわけです。", scene=NET0),
    dict(id="c10", text="ただし、球の速さも回転も高さも、公式な数字はありません。", scene=CARD(("球の速さ・回転・高さ", 84, WHITE), ("公式な数字は ありません", 90, RED))),
    dict(id="c11", text="だから、こう置きます。速さは秒速30m。時速108kmです。新幹線の約3分の1。", scene=SPEED0),
    dict(id="c12", text="打つ高さは、仮に1.0mと置きます。", scene=C_START),
    dict(id="c13", text="打つ場所は、コートの一番後ろの線、ベースライン。ここからネットまで、11.9mです。", scene=C_DIST),
    dict(id="c14", text="飛ぶ時間は、空気を考えなければ約0.4秒。空気を考えると約0.45秒です。", scene=B_TIMES),
    dict(id="c15", text="こんな技が、現実で打てるのか。割れた2つを返せるのかも、確かめます。", style="question", sub="こんな技が\n現実で【打てる】のか", scene=QBLANK),
    dict(id="c16", text="道具は3つ。テニスの国際ルール、実際に測った研究の論文、自分の計算です。", scene=CARD(("道具は3つ", 100, YEL), ("テニスの国際ルール", 60, WHITE), ("実際に測った研究の論文", 60, WHITE), ("自分の計算", 60, WHITE))),
    dict(id="c17", text="ものさしは1つ。名前は「外れ幅」です。", scene=MB0),
    dict(id="c18", text="ボールの下が、ネットの上端にちょうどふれる高さを、0cmとします。そこから何cm、高いか低いかを言います。", scene=dict(kind="window", stage=0, meter=dict(n=0, stage=0, zero=True))),
    dict(id="c19", text="0cmがちょうど。6.7cm低くなるまでは、まだふれます。それより低いと下に刺さり、高いと上を越えます。", scene=WIN1),
    dict(id="c20", text="この外れ幅を、実験ごとに言います。ラケットの話になったら、基準を替えます。", scene=MB2),
    dict(id="c21", text="実験していきます。", scene=CARD(("重力と空気と回転の計算", 80, YEL), ("実験していきます", 66, WHITE))),
])
P["ch2"] = dict(title="第2章 実験1〜3 重力だけで打つ、空気で外れる、直す", cta=False, lines=[
    dict(id="c1", text="実験1。まず何も考えず、重力だけで計算します。空気は考えません。", section=True, exp=1, scene=EXPCARD(1, "重力だけで計算する")),
    dict(id="c2", text="秒速30m、高さ1.0m。ボールの下が、ネットの上端にふれる角度を探します。", scene=C_START),
    dict(id="c3", text="角度とは、打ち出す向きです。水平を0°とした、上向きの角度で言います。", scene=ANG1),
    dict(id="c4", text="答えは3.47°。水平からほんの少し上です。1m進んで、6cm上がる角度。", scene=ANG1T),
    dict(id="c5", text="ネットまでは0.397秒。外れ幅は0cm。ふれます。", scene=COURT([PA1], M(1))),
    dict(id="c6", text="あっさり当たりました。これなら打てそうです。"),
    dict(id="c7", text="実験2。同じ角度を、現実の空気の中で打ちます。", section=True, exp=2, scene=EXPCARD(2, "同じ角度を空気の中で打つ")),
    dict(id="c8", text="空気は、速いボールほど、ブレーキをかけます。", scene=AIRDRAG),
    dict(id="c9", text="ネットに着くころ、秒速30mが23.9mに。約2割、遅くなります。", scene=SPEED1),
    dict(id="c10", text="その分、球は落ちる。ネットの位置で、狙いより13cm低い。ボール2個分です。", scene=COURT([G(PA1), PA2], M(2))),
    dict(id="c11", text="ネットに当たって、落ちます。外れ幅は13cm低い。失敗です。"),
    dict(id="c12", text="実験3。角度を直します。空気で落ちる分、少し上へ向けます。", section=True, exp=3, scene=EXPCARD(3, "角度を直す")),
    dict(id="c13", text="3.47°を、4.11°に。0.64°だけ、上げました。", scene=ANG2),
    dict(id="c14", text="ふれます。外れ幅は0cm。打った場所から18.0m先に落ちます。", scene=COURT([G(PA2), PA3], M(3))),
    dict(id="c15", text="外れ幅は、0cmに戻りました。でもここまでは、回転なし。"),
    dict(id="c16", text="サムライドライブは「超回転」の技です。ふつうよりずっと強い回転のこと。", scene=SPIN0),
    dict(id="c17", text="次は、ここに回転を足します。"),
])
P["ch3"] = dict(title="第3章 実験4・5 回転で沈む、直す", cta=False, lines=[
    dict(id="c1", text="外れ幅は0cm。ここに回転を足します。実験4。", section=True, exp=4, scene=EXPCARD(4, "回転を足す")),
    dict(id="c2", text="回転は、毎分3,000回転。1秒に50回転です。", scene=SPIN1),
    dict(id="c3", text="前に回るボールは、空気の流れで、下へ押されます。上側が、進む向きへ回る回転です。", scene=MAGNUS),
    dict(id="c4", text="この力は、落ちる速さを1秒に秒速6.8mずつ増やします。重力の約0.7倍です。", scene=B_G),
    dict(id="c5", text="角度は、直したばかりの4.11°のままで打ちます。", scene=ANG3),
    dict(id="c6", text="ネットの位置で、狙いより58cm低い。ボール約9個分です。", scene=COURT([G(PA3), PA4], M(4))),
    dict(id="c7", text="ネットの下に、突き刺さります。外れ幅は58cm低い。"),
    dict(id="c8", text="実験2の4倍以上の外れ方です。失敗です。"),
    dict(id="c9", text="実験5。角度を直します。回転で下に曲がる分、さらに上へ。", section=True, exp=5, scene=EXPCARD(5, "角度を直す")),
    dict(id="c10", text="4.11°を、6.93°に。1m進んで、12cm上がる角度です。", scene=ANG4),
    dict(id="c11", text="ふれます。外れ幅は0cm。", scene=COURT([PA5], M(5))),
    dict(id="c12", text="着地は16.2m先。回転なしの18.0mより、約1.7m手前に落ちます。", scene=COURT([G(PA3), PA5], M(5))),
    dict(id="c13", text="ただし、ふれる範囲は狭い。ボールのどこかが上端にふれる高さは、0cmから6.7cm低いまで。ボール1個分の幅です。", scene=dict(kind="window", stage=2, meter=dict(n=5, stage=1))),
    dict(id="c14", text="この範囲を、窓と呼びます。"),
    dict(id="c15", text="角度にすると、窓は約6.60°から6.93°。窓の幅は約0.32°。1°の約3分の1です。", scene=ANGL0),
    dict(id="c16", text="6.93°は窓の上限。これより上へ向けると、ネットを越えます。", scene=ANGL1),
    dict(id="c17", text="角度が1°ずれると、ネットの高さで約20cmずれます。ボール3個分です。", scene=DEG1),
    dict(id="c18", text="しかも、この角度は計算の仮定しだい。回転が曲げる力の見積もりで、±0.7°ほど動きます。", scene=UNC0),
    dict(id="c19", text="本当の角度は、窓の外かもしれません。", scene=UNC1),
    dict(id="c20", text="それでも、窓に入る角度は存在します。外れ幅は0cm。", scene=COURT([PA5], M(5))),
    dict(id="c21", text="次は、回転を増やします。「超」と呼べる回転まで。", scene=SPIN2),
])
P["ch4"] = dict(title="第4章 実験6・7 測られた範囲を超える、範囲の中でそろえる", cta=False, lines=[
    dict(id="c1", text="毎分3,000回転で、「超」と呼べるのか。実験6。5,000回転にします。", section=True, exp=6, scene=EXPCARD(6, "5,000回転にする")),
    dict(id="c2", text="角度は8.82°。着地は15.5m先。計算では、ふれます。外れ幅は0cm。", scene=COURT([G(PA5), PA6], M(6))),
    dict(id="c3", text="ただし5,000回転は、測られた範囲をわずかに超えます。目安の値です。", scene=SPIN2S),
    dict(id="c4", text="問題は、回転をかけるラケットです。", scene=CARD(("問題は", 80, WHITE), ("回転をかける ラケット", 100, YEL))),
    dict(id="c5", text="回転は、ラケットが球の表面をこすってかけます。", scene=RUB0),
    dict(id="c6", text="球に吸い付いて、すべらないとしても、こする速さは秒速29m要ります。時速約105kmです。", scene=RUB1),
    dict(id="c7", text="吸い付きが悪ければ、もっと速く要ります。", scene=RUB2),
    dict(id="c8", text="実際に測られた数字を見ます。大学の男子選手13人のフォアハンド。利き腕側の、基本の打ち方です。", scene=CARD(("実際に測られた数字", 80, YEL), ("大学の男子選手 13人", 66, WHITE), ("フォアハンド（利き腕側の基本の打ち方）", 50, WHITE))),
    dict(id="c9", text="回転は、平均969回転。", scene=B_969),
    dict(id="c10", text="国別対抗の大会、デビスカップ。その1試合では、最大3,800〜4,300回転。", scene=B_DAVIS),
    dict(id="c11", text="5,000回転は、その最大を超えます。出せると言える根拠がありません。", scene=B_5000),
    dict(id="c12", text="外れ幅は0cmでも、失敗です。", scene=COURT([G(PA5), PA6], M(6))),
    dict(id="c13", text="実験7。条件を、測られた範囲にそろえます。", section=True, exp=7, scene=EXPCARD(7, "測られた範囲にそろえる")),
    dict(id="c14", text="回転は3,000回転。測られた最大の、約7〜8割です。", scene=B_SAFE),
    dict(id="c15", text="こする速さは秒速17.5m。時速約63km。街を走る車の速さで届きます。", scene=B_RUB),
    dict(id="c16", text="速さは秒速30m。高さは1.0m。角度は6.93°。", scene=dict(kind="conds", head="実験7の条件", items=[("30m", "速さ", "秒速30m（仮置き）"), ("1.0m", "打つ高さ", "仮置き"), ("6.93°", "角度", "窓の上限")])),
    dict(id="c17", text="ボールの下が、ネットの上端にふれます。外れ幅は0cm。成功です。", scene=COURT([PA7], M(7))),
    dict(id="c18", text="ふれる角度は、見つかりました。"),
    dict(id="c19", text="ところが、ふれることと、割れることは別です。割れるか、割れたあと返せるか、最後に確かめます。", scene=CARD(("ふれる と 割れる は別", 84, YEL), ("割れるか　返せるか", 80, WHITE), ("最後に確かめます", 60, DIM))),
])
P["ch5"] = dict(title="第5章 割れるのか", cta=False, lines=[
    dict(id="c1", text="外れ幅は0cm。ネットの上端にふれるところまで来ました。残りは、割れるか。", section=True, scene=C_E7),
    dict(id="c2", text="回るボールには、回転のエネルギーがあります。単位はジュール。", scene=CARD(("回るボールには", 76, WHITE), ("回転のエネルギー", 100, YEL), ("単位は ジュール", 66, WHITE))),
    dict(id="c3", text="1ジュールは、りんご1個を、1m持ち上げる力です。", scene=APPLE0),
    dict(id="c4", text="3,000回転は、2.1ジュール。りんごを約2m持ち上げる分。飛ぶボールのエネルギーの約8%です。", scene=APPLE1),
    dict(id="c5", text="テニスボールは、中が空洞のゴムの殻です。これを裂く目安は、3〜7ジュール。", scene=BSEC0),
    dict(id="c6", text="確かさは低い、おおよその大きさを見るための数字です。", scene=BSEC1),
    dict(id="c7", text="届くのは、約3,700回転から。", scene=B_E1),
    dict(id="c8", text="成功した3,000回転は、2.1ジュール。足りません。", scene=B_E2),
    dict(id="c9", text="しかも、切る刃がありません。ネットの上端には針金が通り、その上を白い帯がおおいます。", scene=NET1),
    dict(id="c10", text="帯の深さは5〜6.35cm。針金は、太さ最大8mmまでです。", scene=NET2),
    dict(id="c11", text="ルールどおりなら、ボールにふれるのは帯。丸い針金は、刃ではありません。", scene=NET3),
    dict(id="c12", text="ルールでは、ボールが壊れたら、そのポイントはやり直し。作中は、返せなければ得点です。", scene=CARD(("ルールでは", 70, WHITE), ("ボールが壊れたら やり直し", 80, YEL), ("作中は 返せなければ得点", 66, DIM))),
    dict(id="c13", text="割れるかは、回転が足りず、刃もありません。", scene=CARD(("割れるかは", 76, WHITE), ("回転が足りず　刃もない", 96, RED))),
    dict(id="c14", text="では、割れたことにします。割れた2つは、返せるのか。", scene=CARD(("割れたことにして", 84, YEL), ("割れた2つは 返せるのか", 80, WHITE))),
])
P["ch6"] = dict(title="第6章 実験8・9 割れた2つを、返せるのか", lines=[
    dict(id="c1", text="ここから、外れ幅の基準を替えます。ラケットの面の端から、何cm外れたか。0cmなら当たり。", section=True, scene=MB3),
    dict(id="c2", text="面とは、ボールを打つ、網の部分です。", scene=FACE0),
    dict(id="c3", text="実験8。割れた殻は、半球が2つ。1つ約28gです。", exp=8, scene=SHELLS0),
    dict(id="c4", text="半球には、丸い背と、へこんだくぼみがあります。くぼみを前にすると、パラシュートのように空気を受けます。"),
    dict(id="c5", text="ネットから、コートの一番後ろの線まで、11.9m。ここに着く時間を比べます。", scene=dict(kind="court", paths=[], stage=3, netfirst=True)),
    dict(id="c6", text="背を前にした殻は、0.60秒。くぼみを前にした殻は、1.0秒。丸いままの球は、0.56秒です。", scene=B_ARRIVE),
    dict(id="c7", text="殻の向きは、飛ぶあいだに変わります。曲がり方の数字は出せません。", scene=SHELLS1),
    dict(id="c8", text="2つが横へ離れる速さを、それぞれ秒速0.5mと置きます。時速1.8km。歩く速さの半分以下です。", scene=SPREAD0),
    dict(id="c9", text="着くころ、2つの殻の間は0.6〜1.0m開きます。この間の距離を、離れ幅と呼びます。", scene=SPREAD1),
    dict(id="c10", text="ラケットの面は、横の幅が最大29.2cm。向きで変わるので、横に分かれる場合で見積もります。", scene=FACE1),
    dict(id="c11", text="面の幅から、ボールの直径を引くと、約22cm。2つの中心が22cm以内なら、両方当たります。", scene=FACE2),
    dict(id="c12", text="離れ幅0.6〜1.0mから、22cmを引いて、外れ幅は38〜79cm。", scene=FACE3),
    dict(id="c13", text="1振りでは、2つは返せません。失敗です。"),
    dict(id="c14", text="実験9。離れる速さを、小さくします。", section=True, exp=9, scene=EXPCARD(9, "離れる速さを、小さくする")),
    dict(id="c15", text="両方入るのは、秒速0.1m前後以下。時速0.4km。1秒に10cmほどの、ほぼ止まって見える速さです。", scene=B_SLOW),
    dict(id="c16", text="回転のエネルギーの、数千分の1しか使えません。", scene=CARD(("使えるのは", 76, WHITE), ("数千分の1", 130, YEL), ("回転のエネルギーの", 60, DIM))),
    dict(id="c17", text="ここまで静かに割れれば、外れ幅は0cm。2つとも、1振りで返せます。", scene=FACE4),
    dict(id="c18", text="2回に分けて返す案は、時間の数字が無く、言えません。", scene=CARD(("2回に分けて返す案は", 70, WHITE), ("時間の数字が無く 言えない", 80, RED))),
    dict(id="c19", text="答えです。ネットの上端にふれる角度は、存在します。", scene=CARD(("答え", 130, YEL), ("ネットの上端にふれる角度は", 56, WHITE), ("存在する", 110, GREEN))),
    dict(id="c20", text="条件は、秒速30mで、回転は3,000回転。", scene=dict(kind="conds", head="答えの条件", items=[("30m", "速さ", "秒速30m（仮置き）"), ("3,000", "回転", "毎分3,000回転")])),
    dict(id="c21", text="角度は約6.6〜6.93°。外れ幅は0cm。", scene=dict(kind="window", stage=2, meter=dict(n=7, stage=1))),
    dict(id="c22", text="ただし窓は、ボール1個分。角度は見積もりで、±0.7°ほど動きます。", scene=UNC0),
    dict(id="c23", text="割れた2つを返せるのも、離れる速さが秒速0.1m前後以下のとき。", scene=B_SLOW),
    dict(id="c24", text="割れるかは、回転が足りず、刃もない。割れ方を決められるかは、漫画です。", scene=CARD(("割れるかは", 70, WHITE), ("回転が足りず　刃もない", 90, RED), ("割れ方を決められるかは 漫画", 66, YEL))),
    dict(id="c25", text="冒頭の1球に戻ります。次にテニスを見たら、ネットの白い帯に当たる音を聞いてください。中に、針金が通っています。", scene=NET3),
])
P["s1"] = dict(title="ネットの高さとボール", lines=[
    dict(id="c1", text="漫画、テニスの王子様の技、サムライドライブ。ボールをネットで真っ二つにします。", scene=NAMECARD),
    dict(id="c2", text="ボールは、重さ約57g、卵1個ほど。直径は6.7cmです。", scene=BALLSIZE),
    dict(id="c3", text="ネットの真ん中の高さは、0.914m。大人の腰の少し下です。", scene=NETH),
    dict(id="c4", text="ここに当てられるか、計算します。ものさしは「外れ幅」。", scene=MB0),
    dict(id="c5", text="ボールの下が、ネットの上端にふれる高さを、0cmとします。そこから何cmずれたかです。", scene=dict(kind="window", stage=0, meter=dict(n=0, stage=0, zero=True))),
    dict(id="c6", text="球の速さは、仮に秒速30mと置きます。時速108km。新幹線の約3分の1です。", scene=SPEED0),
    dict(id="c7", text="打つ高さは1.0m。まず、空気を考えず、重力だけで計算します。", exp=1, scene=C_START),
    dict(id="c8", text="角度は、3.47°。水平からほんの少し上です。", scene=ANG1),
    dict(id="c9", text="外れ幅は0cm。あっさりふれました。", scene=COURT([PA1], M(1))),
    dict(id="c10", text="でもこれは、空気がない世界の話です。現実では、どうなるか。", scene=CARD(("空気がない世界の話", 80, YEL), ("現実では、どうなるか", 80, WHITE))),
])
P["s2"] = dict(title="空気で外れる", lines=[
    dict(id="c1", text="漫画、テニスの王子様の技を、現実の空気の中で打ちます。", scene=NAMECARD),
    dict(id="c2", text="ものさしは「外れ幅」。ボールの下が、ネットの上端にふれる高さを0cmとして、何cmずれたかです。", scene=WIN1),
    dict(id="c3", text="重力だけで出した角度、3.47°のまま打ちます。水平からほんの少し上です。", exp=2, scene=ANG1),
    dict(id="c4", text="球は秒速30m、時速108kmで出ます。", scene=SPEED0),
    dict(id="c5", text="空気は、速いボールにブレーキをかけます。ネットに着くころ、秒速23.9m。時速86kmです。", scene=SPEED1),
    dict(id="c6", text="約2割遅くなって、球は落ちます。狙いより13cm低い。ボール2個分です。", scene=COURT([G(PA1), PA2], M(2))),
    dict(id="c7", text="ネットに当たって、外れ幅は13cm低い。失敗です。"),
    dict(id="c8", text="直します。角度を、4.11°へ。0.64°だけ、上げます。", exp=3, scene=ANG2),
    dict(id="c9", text="外れ幅は0cm。ふれます。", scene=COURT([G(PA2), PA3], M(3))),
    dict(id="c10", text="空気の分は、角度で直せました。次は、超回転です。", scene=SPIN0),
])
P["s3"] = dict(title="回転で沈む", lines=[
    dict(id="c1", text="漫画、テニスの王子様のサムライドライブは、超回転の技。ふつうよりずっと強い回転です。", scene=SPIN0),
    dict(id="c2", text="回転を、毎分3,000回転にします。1秒に50回転です。", exp=4, scene=SPIN1),
    dict(id="c3", text="ものさしは「外れ幅」。ネットの上端にふれる高さを0cmとして、何cmずれたかです。", scene=WIN1),
    dict(id="c4", text="前に回るボールは、空気の流れで、下へ押されます。", scene=MAGNUS),
    dict(id="c5", text="この力は、落ちる速さを1秒に秒速6.8mずつ増やします。重力の約0.7倍です。", scene=B_G),
    dict(id="c6", text="角度は4.11°のまま。ネットの位置で、58cm低い。ボール約9個分です。", scene=COURT([G(PA3), PA4], M(4))),
    dict(id="c7", text="ネットの下に刺さります。外れ幅は58cm低い。失敗です。"),
    dict(id="c8", text="直します。角度を、6.93°へ。外れ幅は0cm。ふれます。", exp=5, scene=COURT([G(PA4), PA5], M(5))),
    dict(id="c9", text="ただし、ふれる角度の幅は狭い。約6.60°から6.93°。幅は約0.32°、ボール1個分の高さです。", scene=ANGL0),
    dict(id="c10", text="1°ずれると、ネットの高さで約20cmずれます。ボール3個分。", scene=DEG1),
    dict(id="c11", text="超回転で当てるのは、角度の勝負です。", scene=CARD(("超回転で当てるのは", 66, WHITE), ("角度の勝負", 120, YEL))),
])
P["s4"] = dict(title="ラケットの限界", lines=[
    dict(id="c1", text="漫画、テニスの王子様のサムライドライブは、超回転。毎分5,000回転なら、どうなるか。", exp=6, scene=SPIN2),
    dict(id="c2", text="ものさしは「外れ幅」。ネットの上端にふれる高さを0cmとして、何cmずれたかです。", scene=WIN1),
    dict(id="c3", text="角度は8.82°。計算では、外れ幅は0cm。ふれます。", scene=COURT([PA6], M(6))),
    dict(id="c4", text="ただし5,000回転は、測られた範囲をわずかに超えます。計算は目安です。", scene=SPIN2S),
    dict(id="c5", text="回転は、ラケットが球をこすってかけます。球に吸い付いても、こする速さは秒速29m。時速約105km要ります。", scene=RUB1),
    dict(id="c6", text="実際に測った数字を見ます。大学の男子選手13人のフォアハンドは、平均969回転。5,000回転は、その約5倍です。", scene=B_5000S),
    dict(id="c7", text="国別対抗の大会、デビスカップ。1試合の最大は、3,800〜4,300回転。5,000回転は、さらに上です。", scene=B_DAVIS5),
    dict(id="c8", text="出せると言える根拠がありません。外れ幅は0cmでも、失敗です。", scene=COURT([PA6], M(6))),
    dict(id="c9", text="測られた範囲にそろえて、3,000回転。角度は6.93°。外れ幅は0cm。成功です。", exp=7, scene=COURT([PA7], M(7))),
    dict(id="c10", text="ふれる角度は、見つかりました。"),
])
P["s5"] = dict(title="割れた2つは返せるか", lines=[
    dict(id="c1", text="漫画、テニスの王子様で、割れたボールが、両方打ち返される。それは、打てるのか。", scene=HALVES0),
    dict(id="c2", text="割れたことにして、計算します。ものさしは「外れ幅」。ラケットの面の端から、何cm外れたかです。0cmなら当たり。", scene=FACE0M),
    dict(id="c3", text="面とは、ボールを打つ網の部分。横の幅は最大29.2cm。", scene=FACE1),
    dict(id="c4", text="面の幅からボールの直径を引くと、約22cm。2つの中心が22cm以内なら、両方当たります。横に分かれる場合の見積もりです。", scene=FACE2),
    dict(id="c5", text="割れた殻は、半球で、1つ約28g。へこんだ側を前にすると、空気をつかんで遅くなります。", exp=8, scene=SHELLS0),
    dict(id="c6", text="ネットから、コートの一番後ろの線まで、11.9m。着くまで0.60秒から1.0秒。丸い球は0.56秒です。", scene=B_ARRIVE),
    dict(id="c7", text="2つが横へ離れる速さは、それぞれ秒速0.5mと置きます。歩く速さの半分以下です。", scene=SPREAD0),
    dict(id="c8", text="着くころ、2つの間は0.6〜1.0m。外れ幅は、38〜79cm。1振りでは、返せません。失敗です。", scene=FACE3),
    dict(id="c9", text="直します。離れる速さを、秒速0.1m前後以下に。外れ幅は0cm。両方返せます。", exp=9, scene=FACE4),
    dict(id="c10", text="ただし、そう割れるかは、漫画です。", scene=CARD(("そう割れるかは", 80, WHITE), ("漫画です", 130, YEL))),
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
SAY = {}
_RE = [(re.compile(r"(?<=\d)〜(?=\d)"), "から"), (re.compile(r"(?<=\d)g"), "グラム"), (re.compile("°"), "度"), (re.compile("±"), "プラスマイナス"), (re.compile("幸村"), "ゆきむら")]


def _auto_say(text):
    """° は声の仕組みが読まないので「度」に、± と数字の〜と幸村を読みに替える(字幕は台本のまま)。"""
    s = text
    for r, to in _RE:
        s = r.sub(to, s)
    return s if s != text else None


def ep_for(name: str) -> dict:
    p = dict(P[name])
    p["lines"] = _finish(p["lines"])
    p["lines"] = [dict(l, say=SAY[(name, l["id"])]) if (name, l["id"]) in SAY else (dict(l, say=_auto_say(l["text"])) if _auto_say(l["text"]) else l) for l in p["lines"]]
    return dict(kind="sim", aspect="portrait" if name.startswith("s") else "landscape", credit=CREDIT_V if name.startswith("s") else CREDIT, **p)
