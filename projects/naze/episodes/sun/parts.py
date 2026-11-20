"""太陽にゴミを捨てない: 本編 5 章とショート 5 本の台本と画面。ch1〜ch5・s1〜s5 の ep.py がここから読む。
台本は scripts.md(3版)。字は変えず、短い文を 1〜3 文ずつ 1 行(声の 1 区切り)にまとめた。出典と計算は scripts.md と sim/calc.txt。
"""
import math

CREDIT = "軌道の速さの式・ロケットの式で自分で計算（太陽と地球の値は NASA）"

YEL, WHITE, GREEN, RED, DIM, BLUE = "yel", "white", "green", "red", "dim", "blue"
CAP = (255, 120, 90)
GRY = (150, 160, 180)


def K(kind, **kw):
    return dict(kind=kind, **kw)


def CARD(*rows, **kw):
    return dict(kind="card", rows=list(rows), **kw)


def SP(view, *layers, names=("金星", "地球"), hl=(), tag=None):
    return dict(kind="space", view=view, layers=list(layers), names=list(names), hl=list(hl), tag=tag)


def PATH(name, grow=True, dur=3.0, dim=False, col=CAP, **kw):
    return dict(t="path", name=name, grow=grow, dur=dur, dim=dim, col=col, **kw)


def ARW(p, v, text="", col=YEL, **kw):
    return dict(t="arrow", p=p, v=v, text=text, col=col, **kw)


def LAB(pos, text, col=WHITE, **kw):
    return dict(t="label", pos=pos, text=text, col=col, **kw)


def SIDE(*rows, **kw):
    return dict(t="card", rows=list(rows), **kw)


def BARS(rows, vmax, head=None):
    return K("bars", rows=rows, vmax=vmax, head=head)


EARTH = (0.0, -1.0)
VEN = (0.723 * math.cos(0.6), 0.723 * math.sin(0.6))
VDIR = (-math.sin(0.6), math.cos(0.6))
RAD = (math.cos(0.6), math.sin(0.6))
Q = (VEN[0] + VDIR[0] * 0.1, VEN[1] + VDIR[1] * 0.1)     # 金星の進む先を横切る所
WIDE = (0, -0.3, 2.9)
BIG = (0, -0.25, 3.4)
JUP = (0, 1.7, 12.5)
ANS = ["太陽へは、捨てられる", "でも、地球の横の速さを、秒速27km消す必要がある", "月ロケット1機で筒2本。日本の分だけで200兆円",
       "地下に埋める、40倍のお金", "打ち上げは、40回に1回失敗する"]
PARKER_NEAR = (0, 0, 0.13)

P = {}

P["ch1"] = dict(title="第1章 いちばん大きな的", cta=False, lines=[
    dict(id="c1", text="空に、いちばん大きな的があります。太陽です。", scene=K("sunset")),
    dict(id="c2", text="直径は、地球109個ぶん。", scene=K("earth109")),
    dict(id="c3", text="表面の温度は、およそ6,000度。何を投げこんでも、ばらばらになります。",
         scene=CARD(("表面の温度", 70, WHITE), ("およそ6,000度", 160, YEL))),
    dict(id="c4", text="一方、地上には、捨て場に困っている物があります。原子力発電で出る、いちばん危ないゴミ。", section=True,
         scene=K("canister", head="原子力発電で出る、いちばん危ないゴミ")),
    dict(id="c5", text="ガラスで固めた、高さ1.3mの筒です。", scene=K("canister", head="ガラスで固めた筒", weight=True)),
    dict(id="c6", text="日本には、いま2,500本。", scene=K("count", val=2500, fmt="{v:,.0f}本", head="日本にあるガラス固化体", cans=25, sub="（筒1つの絵＝100本）")),
    dict(id="c7", text="何万年も、人から遠ざけておく必要があります。"),
    dict(id="c8", text="それなら、太陽に捨ててしまえばいい。そう考えた人は、昔からいました。",
         scene=SP(WIDE, ARW(EARTH, (0, 0.75), "太陽へ捨てる？", YEL, on="太陽に捨て", dy=-10, dx=170))),
    dict(id="c9", text="1970年代には、NASA も本気で調べています。", scene=CARD(("1974年", 90, YEL), ("NASAの報告", 110, WHITE), ("宇宙へ捨てる案を調べた", 60, DIM))),
    dict(id="c10", text="それなのに、いまも1本も、太陽へは送られていません。", scene=CARD(("太陽へ送った筒", 70, WHITE), ("0本", 200, RED))),
    dict(id="c11", text="なぜ、太陽に捨てないのか。", style="question", sub="なぜ\n【太陽に捨てない】のか", scene=CARD()),
    dict(id="c12", text="実は、捨てることはできます。ただ、とんでもなく高くつく。その原因は、地球の速さです。",
         scene=CARD(("捨てることは、できる", 70, GREEN), ("でも、とんでもなく高くつく", 84, YEL), ("原因は　地球の速さ", 70, WHITE))),
    dict(id="c13", text="筒を1本積んだカプセルで、確かめます。撃ち方を変えて、4回。", section=True,
         scene=SP((0, -0.75, 1.3), LAB("earth", "カプセル（筒1本）", YEL, dy=-70), names=("金星", "地球"))),
    dict(id="c14", text="1回目。地球の重力を抜けた所から、太陽に、まっすぐ向けて撃ちます。速さは、秒速10km。",
         scene=SP(WIDE, ARW(EARTH, (0, 0.33), "太陽へ 秒速10km", YEL, on="秒速10km", dx=150, dy=10), tag="1回目")),
    dict(id="c15", text="カプセルは、太陽へ向かって飛び出しました。ところが。",
         scene=SP(WIDE, PATH("r10", dur=7.5), LAB("peri", "近づけたのは ここまで", YEL, ln="c16", at=0.5, name="r10", dx=-260), names=("金星", "地球"), tag="1回目")),
    dict(id="c16", text="道すじは横へそれて、金星の道のあたりで折り返します。"),
    dict(id="c17", text="太陽には、かすりもしません。的は、あんなに大きいのに。",
         scene=SP(WIDE, PATH("r10", grow=False), LAB("peri", "金星の道のあたり", YEL, name="r10", dx=-240), names=("金星", "地球"), hl=("金星",), tag="1回目")),
])

P["ch2"] = dict(title="第2章 秒速30kmの横すべり", cta=False, lines=[
    dict(id="c1", text="外れたわけは、撃つ前にあります。カプセルは、止まった所から撃たれたのではありません。",
         scene=SP(BIG, PATH("r10", grow=False, dim=True), names=("金星", "地球"))),
    dict(id="c2", text="地球は、太陽のまわりを回っています。",
         scene=SP(BIG, ARW(EARTH, (0.7, 0), "地球の進む向き", BLUE, dy=50, dx=60), names=("水星", "金星", "地球", "火星"), hl=("地球",))),
    dict(id="c3", text="その速さ、秒速30km。時速にすると、10万7,000km。", scene=CARD(("地球の速さ", 70, WHITE), ("秒速30km", 170, YEL), ("時速 10万7,000km", 80, WHITE))),
    dict(id="c4", text="新幹線の、335倍です。東京から大阪まで、13秒。",
         scene=BARS([("新幹線", 320, GRY, "時速320km"), ("地球", 107225, YEL, "時速10万7,000km")], 107225, head="新幹線の335倍　東京から大阪まで13秒")),
    dict(id="c5", text="地球に乗っている物は、全部この速さで横へ動いています。あなたも、ロケットも、カプセルも。",
         scene=SP((0, -0.9, 0.9), ARW(EARTH, (0.28, 0), "全部 秒速30kmで横へ", BLUE, dy=-60, dx=40), names=("地球",))),
    dict(id="c6", text="走る電車の窓から、真横にボールを投げたとします。ボールは、真横には飛びません。電車と同じ速さで、前へも進みます。", section=True,
         scene=K("train")),
    dict(id="c7", text="カプセルも同じです。太陽へ秒速10km。横へ秒速30km。", scene=K("vectors", vr=10, head="カプセルの2つの速さ")),
    dict(id="c8", text="横のほうが、3倍も速い。だから、太陽へは向かえず、斜めに流されます。"),
    dict(id="c9", text="2回目。もっと強く撃ってみます。太陽へ向けて、秒速20km。2倍の速さです。", section=True,
         scene=SP(BIG, PATH("r10", grow=False, dim=True), ARW(EARTH, (0, 0.66), "太陽へ 秒速20km", YEL, on="秒速20km", dx=160, dy=10), tag="2回目")),
    dict(id="c10", text="それでも、外れました。",
         scene=SP(BIG, PATH("r10", grow=False, dim=True), PATH("r20", dur=6.0),
                  LAB("peri", "近づけたのは ほんの少し", YEL, ln="c11", at=0.3, name="r20", dx=-280), hl=("金星",), tag="2回目")),
    dict(id="c11", text="近づけたのは、ほんの少し。金星の道を、少し越えただけ。"),
    dict(id="c12", text="横の速さが、消えていないからです。", scene=CARD(("消えていないのは", 70, WHITE), ("横の秒速30km", 150, YEL))),
    dict(id="c13", text="月が地球に落ちてこないのと、同じしくみです。落ちてはいる。でも、横へ速すぎて、いつも外れる。",
         scene=CARD(("月も、地球へ落ち続けている", 76, WHITE), ("横へ速いから、外れ続ける", 84, YEL))),
    dict(id="c14", text="地球も、46億年、太陽へ落ち続けて、外れ続けています。",
         scene=SP(WIDE, LAB("earth", "46億年 落ち続けて、外れ続ける", YEL, dy=-80), names=("金星", "地球"), hl=("地球",))),
    dict(id="c15", text="足りないのは、太陽へ向かう力ではありません。横の速さを、消すことです。",
         scene=CARD(("足りないのは", 70, WHITE), ("横の速さを、消すこと", 120, YEL))),
])

P["ch3"] = dict(title="第3章 うしろ向きに撃つ", cta=False, lines=[
    dict(id="c1", text="3回目。向きを変えます。太陽へではなく、地球が進む向きの、真うしろへ。ブレーキをかけるのです。", section=True,
         scene=SP((0, -0.8, 1.3), ARW(EARTH, (0.3, 0), "地球の進む向き", BLUE, dy=-50, dx=40), ARW(EARTH, (-0.3, 0), "真うしろへ撃つ", RED, on="真うしろ", dy=-50, dx=-40),
                  names=("地球",), tag="3回目")),
    dict(id="c2", text="まず、秒速10kmぶん、消してみます。", scene=SP(WIDE, SIDE(("消す速さ", 50, WHITE), ("秒速10km", 100, YEL)), names=("水星", "金星", "地球"), tag="3回目")),
    dict(id="c3", text="カプセルは、太陽へ近づいていきました。金星の道を越え、水星の道も越えます。",
         scene=SP(WIDE, PATH("b10", dur=9.0), names=("水星", "金星", "地球"), hl=("水星", "金星"), tag="3回目")),
    dict(id="c4", text="でも、そこまで。太陽をかすめもせず、回って戻ってきました。"),
    dict(id="c5", text="秒速20kmぶん、消します。",
         scene=SP((0, -0.45, 1.5), PATH("b10", grow=False, dim=True), PATH("b20", dur=2.4, at=0.1), SIDE(("消す速さ", 50, WHITE), ("秒速20km", 100, YEL)),
                  names=("水星", "金星", "地球"), tag="3回目")),
    dict(id="c6", text="太陽の半径の12倍まで、近づきました。まだ、届きません。",
         scene=SP((0, 0, 0.36), PATH("b20", grow=False), dict(t="ring", r=0.056, col=YEL), LAB((0, 0.056), "太陽の半径の12倍", YEL, dy=-40, at=0.35), names=())),
    dict(id="c7", text="4回目。秒速27kmぶん、消します。", section=True,
         scene=SP((0, -0.45, 1.5), PATH("b10", grow=False, dim=True), PATH("b20", grow=False, dim=True), SIDE(("消す速さ", 50, WHITE), ("秒速27km", 100, YEL)),
                  names=("水星", "金星", "地球"), tag="4回目")),
    dict(id="c8", text="カプセルは、太陽の表面に届きました。やっと、命中です。",
         scene=SP((0, -0.45, 1.5), PATH("b10", grow=False, dim=True), PATH("b20", grow=False, dim=True), PATH("b27", dur=3.0, col=(255, 90, 60)),
                  LAB("sun", "命中", RED, on="命中", dy=-80), names=("水星", "金星", "地球"), tag="4回目")),
    dict(id="c9", text="必要なブレーキは、秒速27km。", scene=CARD(("必要なブレーキ", 70, WHITE), ("秒速27km", 180, YEL))),
    dict(id="c10", text="では、このブレーキは、どれほど大変なのか。ロケットは、燃料を後ろへ噴いて、速さを変えます。変えたい速さが大きいほど、燃料は雪だるまのように増えます。",
         section=True, scene=CARD(("変えたい速さが大きいほど", 70, WHITE), ("燃料は雪だるま式に増える", 96, YEL))),
    dict(id="c11", text="月へ向かうなら、出発の重さは、届ける重さの2倍。",
         scene=BARS([("月へ", 2, BLUE, "2倍")], 130, head="出発の重さは、届ける重さの何倍か")),
    dict(id="c12", text="太陽へ落とすなら、127倍です。",
         scene=BARS([("月へ", 2, BLUE, "2倍"), ("太陽へ", 127, RED, "127倍")], 130, head="出発の重さは、届ける重さの何倍か")),
    dict(id="c13", text="これは、いちばん燃費のよい、水素で燃やすエンジンで数えた場合です。",
         scene=BARS([("月へ", 2, BLUE, "2倍"), ("太陽へ", 127, RED, "127倍")], 130, head="水素のエンジンで計算（低い軌道から）")),
    dict(id="c14", text="人を月へ運んだ、サターンV というロケットがあります。史上最大級の、このロケット1機。", scene=K("saturn", stage=0)),
    dict(id="c15", text="太陽へ届けられるのは、1トン足らず。あの筒で、2本です。", scene=K("saturn", stage=1)),
    dict(id="c16", text="日本にある2,500本を捨てるには、1,300機。サターンV が飛んだのは、全部で13回でした。", scene=K("saturn", stage=2, head="サターンVが飛んだのは 全部で13回")),
    dict(id="c17", text="1機の値段は、今のお金で、およそ1,500億円。", section=True, scene=CARD(("サターンV 1機", 70, WHITE), ("およそ1,500億円", 150, YEL))),
    dict(id="c18", text="1,300機なら、およそ200兆円です。", scene=K("count", val=200, fmt="およそ{v:.0f}兆円", head="1,300機の値段", sub="（日本の2,500本を太陽へ）")),
    dict(id="c19", text="地下に埋める計画は、4万本ぶんで、約4.7兆円。16倍の本数を埋めても、40分の1で済みます。",
         scene=BARS([("太陽へ 2,500本", 201, RED, "約200兆円"), ("地下へ 4万本", 4.7, GREEN, "約4.7兆円")], 210, head="捨てる費用")),
])

P["ch4"] = dict(title="第4章 本物は、遠回りをした", cta=False, lines=[
    dict(id="c1", text="では、太陽へ行った探査機は、無いのでしょうか。あります。", scene=SP((0, 0, 1.9), names=("水星", "金星", "地球"))),
    dict(id="c2", text="2018年に打ち上げられた、NASA の探査機。名前は、パーカー・ソーラー・プローブ。",
         scene=CARD(("パーカー・ソーラー・プローブ", 86, YEL), ("2018年　NASAの探査機", 60, WHITE))),
    dict(id="c3", text="重さは、685kg。軽自動車より軽い。", scene=CARD(("重さ", 70, WHITE), ("685kg", 180, YEL), ("軽自動車より軽い", 64, DIM))),
    dict(id="c4", text="これを、大型のロケット、デルタIVヘビーで撃ちました。それでも、まっすぐには行けません。",
         scene=CARD(("デルタIVヘビーで打ち上げ", 80, WHITE), ("それでも、まっすぐには行けない", 84, YEL))),
    dict(id="c5", text="使ったのは、金星です。金星のすぐそばを通ると、金星の重力に引かれます。", section=True,
         scene=SP((VEN[0], VEN[1] + 0.06, 0.7), ARW(VEN, (VDIR[0] * 0.18, VDIR[1] * 0.18), "金星の進む向き", BLUE, dx=-60, dy=-40), names=("金星",), hl=("金星",))),
    dict(id="c6", text="通り方を選べば、速さを少し奪ってもらえる。金星の進む先を横切ると、うしろへ引かれて、遅くなるのです。",
         scene=SP((VEN[0], VEN[1] + 0.06, 0.7), ARW(VEN, (VDIR[0] * 0.18, VDIR[1] * 0.18), "金星の進む向き", BLUE, dx=-60, dy=-40),
                  ARW((Q[0] + RAD[0] * 0.13, Q[1] + RAD[1] * 0.13), (-RAD[0] * 0.26, -RAD[1] * 0.26), "探査機の道", (255, 150, 90), dx=-90, dy=20, at=0.2),
                  ARW(Q, (-VDIR[0] * 0.075, -VDIR[1] * 0.075), "うしろへ引かれる", RED, on="うしろへ", dx=150, dy=30),
                  names=("金星",), hl=("金星",))),
    dict(id="c7", text="燃料を使わない、ブレーキです。", scene=CARD(("燃料を使わない", 76, WHITE), ("ブレーキ", 180, YEL))),
    dict(id="c8", text="これを、7回くり返しました。1回ごとに、道すじが少しずつ、太陽へ近づきます。",
         scene=SP((0, 0, 1.7), dict(t="loops", dur=8.0), names=("水星", "金星", "地球"), hl=("金星",))),
    dict(id="c9", text="かかった時間は、6年。"),
    dict(id="c10", text="2024年12月。いちばん近づいた所は、表面から610万km。",
         scene=SP(PARKER_NEAR, dict(t="loops", grow=False, count=False), LAB((-0.0461, 0.0), "表面から610万km", YEL, dx=-60, dy=-70), names=())),
    dict(id="c11", text="太陽の直径の、4つぶん手前です。触れてはいません。落ちてもいません。"),
    dict(id="c12", text="685kgを、6年かけて、ここまで。", scene=CARD(("685kgを", 90, WHITE), ("6年かけて、ここまで", 120, YEL))),
    dict(id="c13", text="NASA は、こう説明しています。太陽へ行くには、火星へ行く55倍のエネルギーが要る。", section=True,
         scene=K("quote", rows=[("太陽へ行くには", 64, (255, 255, 255)), ("火星へ行く55倍のエネルギーが要る", 76, (255, 214, 64))], src="NASA")),
    dict(id="c14", text="太陽の手前にある水星でさえ、同じです。水星を回る探査機は、着くまでに6年半かかりました。",
         scene=SP((0, 0, 1.3), SIDE(("水星の探査機 メッセンジャー", 40, WHITE), ("着くまで 6年半", 84, YEL), on="水星を回る"), names=("水星", "金星"), hl=("水星",))),
    dict(id="c15", text="近いのに、行きにくい。太陽系でいちばん行きにくい場所は、真ん中だったのです。",
         scene=SP(BIG, LAB("sun", "いちばん行きにくいのは、真ん中", YEL, dy=-130, on="真ん中"), names=("水星", "金星", "地球", "火星"))),
])

P["ch5"] = dict(title="第5章 外へ捨てるほうが楽、そして答え", lines=[
    dict(id="c1", text="では、反対はどうでしょう。太陽系の外へ、捨ててしまう。こちらは、ブレーキではなく、アクセルです。",
         scene=SP((2.2, 0.5, 11), ARW(EARTH, (1.6, 0), "前へ撃つ", GREEN, on="太陽系の外", dy=-50), PATH("out12", dur=5.0, col=(110, 220, 140), on="捨ててしまう"),
                  names=("地球", "火星", "木星"))),
    dict(id="c2", text="地球の秒速30kmに、あと12km足せばいい。", scene=CARD(("外へ出すのに足す速さ", 70, WHITE), ("秒速12km", 180, GREEN))),
    dict(id="c3", text="太陽へ落とす27kmの、半分以下です。",
         scene=BARS([("外へ", 12.3, GREEN, "秒速12km"), ("太陽へ", 26.9, RED, "秒速27km")], 30, head="変える速さ")),
    dict(id="c4", text="実際、太陽系の外へ向かう道に乗った探査機は、もう5機あります。ボイジャー1号は、いまも秒速17kmで遠ざかっています。",
         scene=CARD(("太陽系の外へ向かう探査機", 66, WHITE), ("5機", 180, GREEN), ("ボイジャー1号は いまも秒速17km", 56, DIM))),
    dict(id="c5", text="太陽に落ちた探査機は、まだ1機もありません。太陽系の果てのほうが、太陽より近いのです。",
         scene=CARD(("太陽に落ちた探査機", 70, WHITE), ("0機", 200, RED))),
    dict(id="c6", text="ここで、もう1つ。太陽へ捨てるいちばん安い道も、実は外まわりです。いったん、木星の遠さまで飛ばす。", section=True,
         scene=SP(JUP, PATH("jup1", dur=5.5, at=0.25), names=("地球", "木星"), hl=("木星",))),
    dict(id="c7", text="遠くへ行くほど、横の速さは小さくなります。そこでなら、消すブレーキは、秒速7kmで済む。",
         scene=SP(JUP, PATH("jup1", grow=False), SIDE(("木星の遠さなら", 50, WHITE), ("消すのは 秒速7km", 84, YEL), on="そこでなら"), LAB("end", "ここでブレーキ", RED, name="jup1", dy=-50),
                  names=("地球", "木星"), hl=("木星",))),
    dict(id="c8", text="あとは、2年かけて、太陽へ落ちていきます。まっすぐ行くより、4割ほど少ない力で届く。",
         scene=SP(JUP, PATH("jup1", grow=False, dim=True), PATH("jup2", dur=4.0, col=(255, 90, 60)), SIDE(("まっすぐより", 50, WHITE), ("4割少ない力", 84, GREEN), on="まっすぐ"),
                  names=("地球", "木星"))),
    dict(id="c9", text="太陽へ行きたければ、まず太陽から離れる。それでも、外へ捨てるより大変です。",
         scene=CARD(("太陽へ行きたければ", 70, WHITE), ("まず太陽から離れる", 110, YEL), ("それでも、外へ捨てるより大変", 60, DIM))),
    dict(id="c10", text="そして、最後の壁が残ります。ロケットは、ときどき失敗します。", section=True, scene=CARD(("最後の壁", 90, WHITE), ("打ち上げの失敗", 130, RED))),
    dict(id="c11", text="2024年は、およそ40回に1回。", scene=CARD(("2024年　261回のうち 失敗6回", 64, WHITE), ("およそ40回に1回", 140, RED))),
    dict(id="c12", text="何千機も撃てば、何十回かは、落ちてくる。積んでいるのは、いちばん危ないゴミです。",
         scene=CARD(("何千機も撃てば", 70, WHITE), ("何十回かは、落ちてくる", 110, RED))),
    dict(id="c13", text="1978年、原子炉を積んだソ連の衛星が、カナダに落ちました。破片を探した広さは、北海道の1.5倍。", scene=K("areas")),
    dict(id="c14", text="答えを、並べます。1つ。太陽へは、捨てられる。", section=True, scene=K("answer", items=ANS, n=1)),
    dict(id="c15", text="2つ。でも地球は秒速30kmで横へ動いていて、その速さを27km消さなければならない。", scene=K("answer", items=ANS, n=2)),
    dict(id="c16", text="3つ。だから、月ロケット1機で、筒は2本。日本の分だけで200兆円。", scene=K("answer", items=ANS, n=3)),
    dict(id="c17", text="4つ。地下に埋める、40倍のお金です。", scene=K("answer", items=ANS, n=4)),
    dict(id="c18", text="5つ。そして、打ち上げは40回に1回、失敗する。", scene=K("answer", items=ANS, n=5)),
    dict(id="c19", text="だから、ゴミは地面の下へ埋める道が選ばれました。"),
    dict(id="c20", text="冒頭の、いちばん大きな的に戻ります。太陽は、近くて大きい。でも、そこへ落とすのが、いちばん高くつく。", section=True,
         scene=K("sunset", text="近くて大きい。でも、いちばん高くつく")),
    dict(id="c21", text="夕日が沈むのを見たら、思い出してください。沈んでいるのは太陽ではなく、秒速30kmで走る、足もとのほうです。", style="end",
         sub="沈んでいるのは\n【秒速30kmで走る足もと】", scene=K("sunset", rise=1.0)),
])

# ---------------------------------------------------------------- ショート(縦)
VW = (0, -0.1, 2.5)
P["s1"] = dict(title="太陽に向けて撃っても、当たらない", lines=[
    dict(id="c1", text="太陽に向けてロケットを撃っても、当たりません。", scene=SP(VW, PATH("r10", dur=3.0))),
    dict(id="c2", text="直径は、地球109個ぶんもあるのに。", scene=K("earth109")),
    dict(id="c3", text="なぜ、外れるのか。", style="question", sub="なぜ\n【外れる】のか", scene=CARD()),
    dict(id="c4", text="地球が、横へ動いているからです。速さは、秒速30km。", scene=SP(VW, ARW(EARTH, (0.8, 0), "秒速30km", BLUE, dy=-60), hl=("地球",))),
    dict(id="c5", text="東京から大阪まで、13秒。", scene=CARD(("東京から大阪まで", 70, WHITE), ("13秒", 200, YEL))),
    dict(id="c6", text="地球から撃った物は、全部この速さで横へすべります。走る電車から、真横にボールを投げるのと同じ。ボールは、電車と一緒に前へも進みます。",
         scene=K("train")),
    dict(id="c7", text="太陽へ秒速10kmで撃っても、横へは30km。横のほうが、3倍速い。", scene=K("vectors", vr=10)),
    dict(id="c8", text="だから、太陽のはるか手前で、折り返してしまいます。", scene=SP(VW, PATH("r10", grow=False), LAB("peri", "ここで折り返す", YEL, name="r10", dx=-60, dy=-60))),
    dict(id="c9", text="当てるには、横の速さを消すしかありません。", scene=CARD(("当てるには", 70, WHITE), ("横の速さを消す", 110, YEL))),
    dict(id="c10", text="太陽が的として難しいのは、遠いからではなく、こちらが速すぎるからです。", style="end", sub="遠いからではなく\n【こちらが速すぎる】",
         scene=K("sunset")),
])
P["s2"] = dict(title="太陽へ落とすのは、外へ出すより難しい", lines=[
    dict(id="c1", text="太陽へ物を落とすのと、太陽系の外へ飛ばすの。難しいのは、太陽のほうです。",
         scene=SP(VW, ARW(EARTH, (0, 0.6), "太陽へ", RED, dy=-40, dx=-80), ARW(EARTH, (0.6, 0), "外へ", GREEN, dy=-50, at=0.3))),
    dict(id="c2", text="地球は、太陽のまわりを秒速30kmで回っています。", scene=SP(VW, ARW(EARTH, (0.8, 0), "秒速30km", BLUE, dy=-60), hl=("地球",))),
    dict(id="c3", text="外へ出すには、あと12km足せばいい。", scene=BARS([("外へ（足す）", 12.3, GREEN, "秒速12km")], 30, head="変える速さ")),
    dict(id="c4", text="太陽へ落とすには、27km消さなければならない。2倍以上の差です。",
         scene=BARS([("外へ（足す）", 12.3, GREEN, "秒速12km"), ("太陽へ（消す）", 26.9, RED, "秒速27km")], 30, head="変える速さ")),
    dict(id="c5", text="実際、太陽系の外へ向かう道に乗った探査機は、もう5機。ボイジャー1号は、いまも秒速17kmで遠ざかっています。",
         scene=CARD(("太陽系の外へ向かう探査機", 56, WHITE), ("5機", 200, GREEN), ("ボイジャー1号 いまも秒速17km", 48, DIM))),
    dict(id="c6", text="太陽に落ちた探査機は、1機もありません。", scene=CARD(("太陽に落ちた探査機", 64, WHITE), ("0機", 220, RED))),
    dict(id="c7", text="いちばん近づいた探査機でも、表面から610万km手前。",
         scene=SP((0, 0, 0.14), dict(t="loops", grow=False, count=False), LAB((-0.0461, 0.0), "表面から610万km", YEL, dx=130, dy=-120), names=())),
    dict(id="c8", text="太陽系でいちばん行きにくい場所は、果てではなく、真ん中でした。", style="end", sub="いちばん行きにくいのは\n【果てではなく真ん中】",
         scene=SP(VW, names=("水星", "金星", "地球"))),
])
P["s3"] = dict(title="月ロケット1機で、核のゴミは2本", lines=[
    dict(id="c1", text="核のゴミを、太陽に捨てるとします。月ロケット1機で運べるのは、たった2本です。", scene=K("saturn", stage=1)),
    dict(id="c2", text="ゴミは、ガラスで固めた高さ1.3mの筒。1本500kg。", scene=K("canister", head="ガラスで固めた筒", weight=True)),
    dict(id="c3", text="太陽へ落とすには、秒速27kmのブレーキが要ります。", scene=SP((0, -0.45, 1.4), PATH("b27", dur=3.0, col=(255, 90, 60)), SIDE(("消す速さ", 44, WHITE), ("秒速27km", 90, YEL)))),
    dict(id="c4", text="ロケットは、変える速さが大きいほど、燃料が雪だるまのように増える。", scene=CARD(("変える速さが大きいほど", 60, WHITE), ("燃料は雪だるま式", 100, YEL))),
    dict(id="c5", text="月へ向かうなら、出発の重さは荷物の2倍。", scene=BARS([("月へ", 2, BLUE, "2倍")], 130, head="出発の重さは荷物の何倍か")),
    dict(id="c6", text="太陽へなら、127倍。", scene=BARS([("月へ", 2, BLUE, "2倍"), ("太陽へ", 127, RED, "127倍")], 130, head="出発の重さは荷物の何倍か")),
    dict(id="c7", text="人を月へ運んだサターンV でも、届くのは1トン足らず。", scene=K("saturn", stage=1)),
    dict(id="c8", text="日本にある筒は、2,500本。全部捨てるには、1,300機。", scene=K("saturn", stage=2)),
    dict(id="c9", text="1機およそ1,500億円。合わせて200兆円です。", scene=K("count", val=200, fmt="{v:.0f}兆円", head="1機およそ1,500億円 × 1,300機")),
    dict(id="c10", text="地下に埋める計画は、4万本ぶんで4.7兆円。", scene=BARS([("太陽へ 2,500本", 201, RED, "約200兆円"), ("地下へ 4万本", 4.7, GREEN, "約4.7兆円")], 210, head="捨てる費用")),
    dict(id="c11", text="捨てられないのではなく、高すぎるのです。", style="end", sub="捨てられないのではなく\n【高すぎる】"),
])
P["s4"] = dict(title="太陽へ行った探査機は、金星で7回ブレーキ", lines=[
    dict(id="c1", text="太陽へ向かった探査機は、まっすぐには飛びませんでした。金星のそばを、7回も通っています。",
         scene=SP((0, 0, 1.6), dict(t="loops", dur=7.0), names=("水星", "金星", "地球"), hl=("金星",))),
    dict(id="c2", text="NASA のパーカー・ソーラー・プローブ。重さ685kg。", scene=CARD(("パーカー・ソーラー・プローブ", 64, YEL), ("685kg", 200, WHITE))),
    dict(id="c3", text="地球を出た物は、秒速30kmで横へ動いています。この速さを消さないと、太陽には近づけない。",
         scene=SP(VW, ARW(EARTH, (0.8, 0), "秒速30km", BLUE, dy=-60), hl=("地球",))),
    dict(id="c4", text="そこで、金星の重力を借りました。そばを通るたびに、速さを少し奪ってもらう。",
         scene=SP((VEN[0], VEN[1] - 0.05, 0.6), ARW(VEN, (VDIR[0] * 0.15, VDIR[1] * 0.15), "金星の進む向き", BLUE, dx=0, dy=-50),
                  ARW((Q[0] + RAD[0] * 0.11, Q[1] + RAD[1] * 0.11), (-RAD[0] * 0.22, -RAD[1] * 0.22), "", (255, 150, 90), at=0.1),
                  ARW(Q, (-VDIR[0] * 0.07, -VDIR[1] * 0.07), "うしろへ引かれる", RED, on="奪って", dx=0, dy=60),
                  names=("金星",), hl=("金星",))),
    dict(id="c5", text="燃料を使わない、ブレーキです。", scene=CARD(("燃料を使わない", 70, WHITE), ("ブレーキ", 200, YEL))),
    dict(id="c6", text="7回くり返して、6年。", scene=SP((0, 0, 1.6), dict(t="loops", grow=False), names=("水星", "金星", "地球"))),
    dict(id="c7", text="いちばん近づいた所が、表面から610万km。",
         scene=SP((0, 0, 0.14), dict(t="loops", grow=False, count=False), LAB((-0.0461, 0.0), "表面から610万km", YEL, dx=130, dy=-120), names=())),
    dict(id="c8", text="NASA の説明では、太陽へ行くには火星の55倍のエネルギーが要ります。",
         scene=K("quote", rows=[("太陽へ行くには", 56, (255, 255, 255)), ("火星の55倍の", 76, (255, 214, 64)), ("エネルギーが要る", 76, (255, 214, 64))], src="NASA")),
    dict(id="c9", text="近くに見える太陽は、いちばん遠回りが要る行き先です。", style="end", sub="近くに見える太陽は\n【いちばん遠回り】", scene=K("sunset")),
])
P["s5"] = dict(title="太陽へ行く近道は、木星まで離れること", lines=[
    dict(id="c1", text="太陽へ物を落とす、いちばん安い道。それは、いったん太陽から離れることです。", scene=SP((0, 1.9, 13), PATH("jup1", dur=4.5, on="離れる"), names=("地球", "木星"), hl=("木星",))),
    dict(id="c2", text="地球のあたりでは、横の速さが秒速30km。これを消すのに、27kmのブレーキが要ります。",
         scene=SP((0, -0.45, 1.4), PATH("b27", dur=3.0, col=(255, 90, 60), on="27km"), SIDE(("消す速さ", 44, WHITE), ("秒速27km", 90, YEL)))),
    dict(id="c3", text="ところが、太陽から遠いほど、横の速さは小さくなる。", scene=CARD(("太陽から遠いほど", 64, WHITE), ("横の速さは小さい", 100, YEL))),
    dict(id="c4", text="木星の遠さなら、秒速7kmほど。", scene=CARD(("木星の遠さなら", 64, WHITE), ("秒速7km", 200, YEL))),
    dict(id="c5", text="そこでブレーキをかければ、あとは太陽へ落ちていくだけ。",
         scene=SP((0, 1.9, 13), PATH("jup1", grow=False, dim=True), PATH("jup2", dur=3.5, col=(255, 90, 60)), names=("地球", "木星"))),
    dict(id="c6", text="合わせた力は、まっすぐ行くより4割少ない。",
         scene=BARS([("まっすぐ", 21.3, RED, "秒速21.3km"), ("木星まわり", 13.2, GREEN, "秒速13.2km")], 24, head="低い軌道から変える速さ")),
    dict(id="c7", text="かかる時間は、行きに3年、落ちるのに2年。", scene=CARD(("行き 3年", 120, WHITE), ("落ちるのに 2年", 120, YEL))),
    dict(id="c8", text="太陽へ行きたければ、まず太陽から離れる。宇宙の道は、遠回りが近道になります。", style="end", sub="宇宙の道は\n【遠回りが近道】",
         scene=SP((0, 1.9, 13), PATH("jup1", grow=False), PATH("jup2", grow=False, col=(255, 90, 60)), names=("地球", "木星"))),
])

# 読みの直し(kana の出力を全行見て、違う所だけ)
YOMI = [("サターンV", "サターンファイブ"), ("デルタIVヘビー", "デルタフォーヘビー"), ("NASA ", "なさ"), ("NASA", "なさ"), ("金星", "きんせい"), ("的", "まと"), ("通って", "とおって"), ("1.3m", "いってんさんメートル"),
        ("610万km", "ろっぴゃくじゅうまんキロ")]


def yomi(text):
    s = text
    for a, b in YOMI:
        s = s.replace(a, b)
    return s


def ep_for(name: str) -> dict:
    p = dict(P[name])
    res = []
    for l in p["lines"]:
        y = yomi(l["text"])
        res.append(dict(l, say=y) if y != l["text"] else l)
    p["lines"] = res
    return dict(kind="sim", aspect="portrait" if name.startswith("s") else "landscape", credit=CREDIT, **p)
