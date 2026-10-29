"""ロケット(段を捨てないと実用的に宇宙へ届かない): 本編 5 章とショート 5 本の台本と画面。ch1〜ch5・s1〜s5 の ep.py がここから読む。
台本は scripts.md(確定。一字も変えない)、出典と計算は research.md。作品・実機の写真は使わない。図は全部コードで描く。
足したのは読みの say= と字幕の改行・強調だけ。
"""
import re

CREDIT = "ツィオルコフスキーの式・地球の重力定数で自分で計算（質量は公表値からの計算）"
CREDIT_V = "ロケットの式で自分で計算（質量は公表値から）"

GREEN, YEL, RED, WHITE, DIM = "green", "yel", "red", "white", "dim"
AMBER = (240, 170, 70)
GREY = (170, 178, 192)
GRN = (110, 220, 140)
BLU = (90, 170, 235)
RD = (240, 90, 80)
ORG = (240, 150, 40)
YL = (255, 214, 64)


def K(kind, **kw):
    return dict(kind=kind, **kw)


def CARD(*rows):
    return dict(kind="formula", rows=list(rows))


def EXPCARD(n, text):
    return dict(kind="formula", rows=[(f"実験{n}", 130, YEL), (text, 66, WHITE)])


def QBLANK():
    return dict(kind="formula", rows=[])


def STACK(*cols, head=None):
    return K("stack", cols=list(cols), head=head)


def COL(name, *segs, hl=False):
    return dict(name=name, segs=list(segs), hl=hl)


def CARGO(val, **kw):
    return K("cargo", val=val, **kw)


def BARS(rows, vmax, **kw):
    return K("bars", rows=rows, vmax=vmax, **kw)


def RANGE(marks=(), bands=((9.3, 10.0, "資料の幅 9.3〜10km/s", YL),), **kw):
    return K("range", bands=list(bands), marks=list(marks), **kw)


KANA_NOTE = None
TL_ITEMS = [("1958", "アトラス　ブースターを捨てる1.5段式"), ("1993", "DC-X　水素の1段式の試作機　最高 約2.5km"),
            ("1996", "DC-XA　約3.1kmまで上がる"), ("1996", "DC-XA　着陸で脚が出ず転倒、炎上"),
            ("1996", "X-33を受注　使ったお金 約12.8億ドル"), ("1999", "X-33　複合材の水素タンクが試験で壊れた"),
            ("2001", "X-33　中止　一度も飛んでいない"), ("2024", "スカイロン　会社が経営破綻")]

P = {}

P["ch1"] = dict(title="第1章 9.4km/sの壁", cta=False, lines=[
    dict(id="c1", text="ファルコン9。アメリカのスペースX社が、何度も飛ばしているロケットです。", scene=K("f9", stage=0)),
    dict(id="c2", text="荷物を1kg、宇宙へ運ぶとします。荷物とは、衛星のような、運びたいもの。1kgは、ペットボトル2本ぶんです。", scene=K("kg", stage=0)),
    dict(id="c3", text="そのために打ち上げるのは、燃料も機体も入れて、約25kg。お米の袋、5つぶんです。", scene=K("kg", stage=1)),
    dict(id="c4", text="荷物は、全体の約4%。機体を使い捨てにした場合の数字です。"),
    dict(id="c5", text="残りの96%は、燃料と機体です。", scene=STACK(COL("打ち上げの重さ（約25kg）", ("燃料と機体", 96, AMBER, "96%"), ("荷物", 4, GRN, "約4%")))),
    dict(id="c6", text="ロケットは普通、燃料を使い切った部分を、途中で切り離して捨てます。この区切りを、段といいます。", scene=K("stages", mode="cut")),
    dict(id="c7", text="もし、段を捨てずに、1つの機体で宇宙へ行けたら、ずっと楽なはず。", scene=K("stages", mode="single")),
    dict(id="c8", text="それは、できないのか。", style="question", sub="それは\n【できない】のか", scene=QBLANK()),
    dict(id="c9", text="まず、宇宙に出るために要る速さを見ます。", section=True, scene=CARD(("宇宙に出るために", 70, WHITE), ("要る速さ", 120, YEL))),
    dict(id="c10", text="宇宙に出るとは、地球のまわりを回り続けること。その回る道を、軌道と呼びます。", scene=K("orbit")),
    dict(id="c11", text="地上200kmの軌道を回るには、秒速7.8km。新幹線の約88倍です。", scene=K("speedo", val=7.8, name="軌道の速さ", rowtxt="秒速7.8km", sub="地上200kmの軌道", mult=True)),
    dict(id="c12", text="東京から大阪まで、約51秒。地球を、90分で1周する速さです。", scene=K("route")),
    dict(id="c13", text="でも、7.8kmでは足りません。昇る間に、速さを失うからです。", scene=K("hstack", vmax=10, segs=[("軌道の速さ", 7.8, BLU, "7.8km/s")], head="7.8kmでは足りない")),
    dict(id="c14", text="失う理由は3つ。重力に逆らう分、空気の抵抗、向きを変える分です。",
         scene=K("hstack", vmax=10, segs=[("軌道の速さ", 7.8, BLU, "7.8km/s"), ("重力に逆らう分", 0.8, RD, ""), ("向きを変える分", 0.65, ORG, ""), ("空気の抵抗", 0.15, GREY, "")],
                 head="昇る間に失う速さ")),
    dict(id="c15", text="失う速さは、合わせて約1.5〜2km/s。"),
    dict(id="c16", text="7.8に足すと、約9.4km/s。新幹線の約106倍です。", scene=K("speedo", val=9.4, name="必要な速さ", rowtxt="秒速約9.4km", sub="見積もり", mult=True)),
    dict(id="c17", text="資料には、9.3〜10km/sの幅があります。", scene=RANGE()),
    dict(id="c18", text="私がざっくり計算した値は、8.9km/sほどでした。", scene=RANGE([(8.9, "私の計算 8.9km/s", RD, 0)])),
    dict(id="c19", text="幅の中の値として、約9.4を置きます。見積もりです。", scene=RANGE([(8.9, "私の計算 8.9km/s", RD, 0), (9.4, "置く値 約9.4km/s", GRN, 1)])),
    dict(id="c20", text="地球の自転も、助けになります。東向きに打つと、地球の回る勢いに乗れます。", scene=K("rotation", stage=0)),
    dict(id="c21", text="種子島で、秒速約400m。7.8kmの約5%です。", scene=K("rotation", stage=1)),
    dict(id="c22", text="約9.4は、この助けを引いたあとの見積もりです。"),
    dict(id="c23", text="追いかけるのは、荷物です。全体の何%が、荷物になるか。冒頭の4%を、どこまで増やせるか。",
         scene=CARGO(0, ghost=4, ghost_txt="冒頭の約4%", note=["実験前は、空っぽ"])),
    dict(id="c24", text="段を捨てずに、約9.4km/sを出せるのか。実験していきます。", scene=CARD(("ロケットの式", 120, YEL), ("速さ ＝ 燃料の勢い × ln（倍率）", 60, WHITE))),
])
P["ch2"] = dict(title="第2章 実験1・2 1段で打つ、軽くする", cta=False, lines=[
    dict(id="c1", text="実験1。まず何も考えず、1つの機体に燃料を詰めて打ちます。", section=True, exp=1, scene=EXPCARD(1, "1つの機体で打つ")),
    dict(id="c2", text="使うのは、ツィオルコフスキーの式。ロシアの科学者が、1903年に出しました。",
         scene=CARD(("ツィオルコフスキーの式", 76, YEL), ("速さ ＝ 燃料の勢い × ln（倍率）", 60, WHITE), ("1903年　ロシアの科学者", 44, DIM))),
    dict(id="c3", text="燃料を後ろへ噴くと、反動で前へ進む。その速さを求める式です。"),
    dict(id="c4", text="燃料の勢いも決めます。燃料の勢いは、比推力という数字で表します。", scene=CARD(("燃料の勢い ＝ 比推力", 76, YEL))),
    dict(id="c5", text="数字が大きいほど、少ない燃料で速くなります。ファルコン9に近い、300秒と置きます。", scene=CARD(("比推力　300秒", 120, YEL), ("大きいほど、少ない燃料で速くなる", 52, WHITE))),
    dict(id="c6", text="ここで、倍率という言葉を使います。離陸のときの重さが、燃え尽きたあとの重さの、何倍か。それが倍率です。", scene=K("massfig")),
    dict(id="c7", text="以後、倍率は、この意味だけで使います。"),
    dict(id="c8", text="約9.4km/sを出すには、倍率が約24倍、要ります。", scene=K("ratio", rows=[("必要な倍率", 24.4, YL, "約24倍")], head="倍率のメーター")),
    dict(id="c9", text="つまり、離陸の重さの約96%が、燃料。燃え尽きたあとに残るのは、約4%です。",
         scene=STACK(COL("離陸の重さ", ("燃え尽きたあとに残る", 4, GREY, "約4%"), ("燃料", 96, AMBER, "約96%")))),
    dict(id="c10", text="残る4%に、空の機体と荷物が入ります。空の機体とは、燃料を使い切ったあとの、タンクとエンジンです。",
         scene=STACK(COL("離陸の重さ", ("空の機体と荷物", 4, GRN, "残る約4%"), ("燃料", 96, AMBER, "約96%")))),
    dict(id="c11", text="離陸の重さが1トンなら、軽自動車1台ぶん。燃料が約960kg、残りは約40kgです。", scene=K("ton", stage=0)),
    dict(id="c12", text="40kgに、タンクもエンジンも荷物も入る。大人1人より軽い重さです。"),
    dict(id="c13", text="ファルコン9は、燃料タンクを上下に重ねた形です。下を1段目、上を2段目と呼びます。", scene=K("f9", stage=1, head="ファルコン9を上下に分けると")),
    dict(id="c14", text="その1段目は、空の機体が約5%。公開されている資料から、私が割った値です。", scene=K("f9", stage=2, head="ファルコン9の1段目")),
    dict(id="c15", text="1トンなら、約51kg。さっきの40kgより、重くなります。", scene=K("ton", stage=2)),
    dict(id="c16", text="荷物がゼロでも、届く速さは秒速8.7〜9.1km。9.4に届かず、失敗です。",
         scene=RANGE([(9.4, "必要 約9.4km/s", RD, 0)], bands=[(8.7, 9.1, "荷物ゼロで届く速さ 8.7〜9.1km/s", AMBER)])),
    dict(id="c17", text="実験2。機体を、限界まで軽くします。", section=True, exp=2, scene=EXPCARD(2, "機体を、限界まで軽くする")),
    dict(id="c18", text="使うのは、アトラス。1958年に衛星を軌道へ乗せた、アメリカの古いロケットです。", scene=K("balloon", stage=2)),
    dict(id="c19", text="薄いステンレスの、風船のようなタンクでした。", scene=K("balloon", stage=0)),
    dict(id="c20", text="空でも、窒素というガスで膨らませないと、自分の重さでつぶれます。", scene=K("balloon", stage=1)),
    dict(id="c21", text="アトラスは、横に補助のエンジンが付いていました。これがブースターです。途中で捨てる形で、1.5段式と呼ばれます。", scene=K("balloon", stage=2)),
    dict(id="c22", text="ここでは、捨てる前の、全部ついた状態で数えます。"),
    dict(id="c23", text="離陸の重さは116トン。空の機体は5.4トンです。",
         scene=BARS([("離陸の重さ", 116, None, "116トン", AMBER), ("空の機体", 5.4, None, "5.4トン", GREY)], 125, head="アトラスの重さ")),
    dict(id="c24", text="割ると、約4.65%。ここまで軽くしても、荷物はゼロの理想で、秒速約9.0kmです。", scene=K("speedo", val=9.0, name="アトラスの理想", rowtxt="秒速約9.0km", sub="荷物ゼロの理想")),
    dict(id="c25", text="燃料の勢いは、300秒と置いた値です。"),
    dict(id="c26", text="資料の幅の下端、9.3にも届きません。倍率が、あと1割以上、足りません。失敗です。",
         scene=RANGE([(9.0, "アトラス 約9.0km/s", AMBER, 0), (9.4, "必要 約9.4km/s", RD, 1)])),
    dict(id="c27", text="風船のタンクが、実機の軽さの限りです。"),
    dict(id="c28", text="ここまでの荷物は、0%。1kgも、乗りませんでした。", scene=CARGO(0, note=["実験1・2：荷物 0%"])),
])
P["ch3"] = dict(title="第3章 実験3 燃料を、増やす", cta=False, lines=[
    dict(id="c1", text="荷物は、0%のまま。機体がこれ以上、軽くならないなら、燃料を増やします。実験3です。", section=True, exp=3, scene=EXPCARD(3, "燃料を、増やす")),
    dict(id="c2", text="アトラスの倍率は、約21.5倍。速さは約9.0km/sでした。",
         scene=K("ratio", rows=[("アトラス　速さ 約9.0km/s", 21.5, AMBER, "約21.5倍")], need=24.4, head="倍率のメーター")),
    dict(id="c3", text="この倍率を約31倍にできれば、速さは約10.1km/s。9.4を越えます。",
         scene=K("ratio", rows=[("燃料を足して　速さ 約10.1km/s", 31, GRN, "約31倍")], need=24.4, head="倍率のメーター")),
    dict(id="c4", text="ただし、これは、タンクをそのままに、燃料だけ足せた場合の話です。"),
    dict(id="c5", text="現実は違います。燃料が増えれば、入れ物も大きく、重くなります。", scene=K("growtank")),
    dict(id="c6", text="空の機体の割合が、4.65%のまま。それなら、倍率は約21.5倍のままです。"),
    dict(id="c7", text="倍率の上限は、100を、機体の割合で割った数。100割る4.65で、約21.5です。", scene=K("limit")),
    dict(id="c8", text="欲しいのは、約24倍。燃料をいくら足しても、そこへ行きません。失敗です。"),
    dict(id="c9", text="しかも、速さは足し算、倍率は掛け算。速さを1km/s足すたびに、倍率は約1.4倍になります。", scene=K("compound")),
    dict(id="c10", text="速さは、9.0から9.4へ。増えたのは、4%ちょっとです。",
         scene=BARS([("速さ　9.0 → 9.4km/s", 4.4, None, "4%ちょっと", BLU), ("倍率　21.5 → 24.4", 13.5, None, "1割以上", RD)], 16, head="増えた割合")),
    dict(id="c11", text="でも倍率は、21.5から24.4へ。増えたのは、1割以上です。", scene=BARS([("速さ　9.0 → 9.4km/s", 4.4, None, "4%ちょっと", BLU), ("倍率　21.5 → 24.4", 13.5, None, "1割以上", RD)], 16, head="増えた割合", grow_from=1)),
    dict(id="c12", text="重いリュックにペットボトルを足すと、足した分を運ぶのに、また力が要る。燃料も同じです。"),
    dict(id="c13", text="軽くしても、増やしても、届かない。3回続けて、失敗しました。", scene=K("fails")),
    dict(id="c14", text="荷物は、まだ0%。", scene=CARGO(0, note=["実験1〜3：荷物 0%"])),
    dict(id="c15", text="残る手は、燃料そのものを替えることです。", scene=CARD(("残る手は", 70, WHITE), ("燃料そのものを替える", 100, YEL))),
])
_HYD = [("燃料", 88, AMBER, "約88%")]
P["ch4"] = dict(title="第4章 実験4 水素と、1段に挑んだ人たち", cta=False, lines=[
    dict(id="c1", text="実験4。燃料そのものを、水素に替えます。", section=True, exp=4, scene=EXPCARD(4, "燃料を、水素に替える")),
    dict(id="c2", text="水素は、噴き出す勢いが強い燃料。燃料の勢いを、450秒と置きます。",
         scene=BARS([("灯油系（置いた値）", 300, None, "300秒", GREY), ("水素", 450, None, "450秒", GRN)], 500, head="燃料の勢い（比推力）")),
    dict(id="c3", text="同じ約9.4km/sでも、倍率は24倍から、約8.4倍に下がります。",
         scene=K("ratio", rows=[("灯油系　300秒", 24.4, GREY, "約24倍"), ("水素　450秒", 8.4, GRN, "約8.4倍")], head="必要な倍率")),
    dict(id="c4", text="燃料は、離陸の重さの約88%で済みます。", scene=STACK(COL("水素の1段", ("残り", 12, GREY, "約12%"), ("燃料", 88, AMBER, "約88%")))),
    dict(id="c5", text="空の機体を、離陸の重さの6%に収められれば、荷物は約6%乗ります。機体を軽く見積もった、理想の置き方です。",
         scene=STACK(COL("理想の置き方", ("荷物", 6, GRN, "約6%"), ("空の機体", 6, GREY, "6%"), ("燃料", 88, AMBER, "約88%")))),
    dict(id="c6", text="日本のロケット、H3。その1段目は、公開されている資料から割ると、約6%です。",
         scene=STACK(COL("H3の1段目（公開資料から割った値）", ("", 6, (70, 82, 110), ""), ("空の機体", 6, GREY, "約6%"), ("燃料", 88, AMBER, "約88%")))),
    dict(id="c7", text="ここまで軽い機体は、あります。計算の上では、水素の1段でも届きます。"),
    dict(id="c8", text="でも、実機の水素タンクは、大きくて重い。", scene=CARD(("実機の水素タンクは", 70, WHITE), ("大きくて重い", 110, YEL))),
    dict(id="c9", text="アメリカのX-33という計画は、機体を約10%と見込んでいました。",
         scene=STACK(COL("機体 6%", ("荷物", 6, GRN, "約6%"), ("空の機体", 6, GREY, ""), ("燃料", 88, AMBER, "")),
                     COL("機体 10%（X-33）", ("荷物", 2, GRN, "約2%"), ("空の機体", 10, GREY, ""), ("燃料", 88, AMBER, ""), hl=True),
                     COL("機体 12%", ("荷物", 0, GRN, "届かない"), ("空の機体", 12, GREY, ""), ("燃料", 88, AMBER, "")),
                     head="空の機体の割合と荷物")),
    dict(id="c10", text="その重さだと、荷物は約2%。12%だと、届きません。", scene=CARGO(2, frm=6, ghost=6, ghost_txt="理想 約6%", note=["機体が12%だと、届かない"])),
    dict(id="c11", text="では、1段で軌道を目指した人は、いなかったのか。いました。", section=True,
         scene=CARD(("1段で軌道を目指した人は", 66, WHITE), ("いなかったのか？", 100, YEL))),
    dict(id="c12", text="1958年のアトラスも、1段に近い機体でした。ただ、ブースターを2分ほどで捨てる1.5段式で、純粋な1段ではありません。", scene=K("balloon", stage=2)),
    dict(id="c13", text="1993年に飛び始めたDC-X。アメリカが作った、水素の1段式ロケットの、3分の1の大きさの試作機です。最高は約2.5km。",
         scene=K("alt", stage=0)),
    dict(id="c14", text="改良型のDC-XAは、約3.1kmまで上がりました。軌道の高さの、約60分の1です。", scene=K("alt", stage=1)),
    dict(id="c15", text="1996年、着陸のときに脚が1本出ず、転倒して燃えました。", scene=K("tl", items=TL_ITEMS, cur=3)),
    dict(id="c16", text="同じ年に、X-33が受注されました。水素の1段式の宇宙船、ベンチャースターの、小さな試験機です。", scene=K("xfig")),
    dict(id="c17", text="使ったお金は、約12.8億ドル。1,000億円を超える額です。", scene=K("tl", items=TL_ITEMS, cur=4, big="約12.8億ドル ＝ 1,000億円超")),
    dict(id="c18", text="1999年、水素タンクが試験で壊れました。複合材という、軽くて強い素材で作ったタンクです。", scene=K("tl", items=TL_ITEMS, cur=5)),
    dict(id="c19", text="作り直すと重くなり、倍率が合わない。2001年に中止。一度も飛んでいません。", scene=K("tl", items=TL_ITEMS, cur=6)),
    dict(id="c20", text="英国のスカイロンは、空気を吸うエンジンで、1段で軌道を狙う計画でした。", scene=K("tl", items=TL_ITEMS + [("計画", "スカイロン　空気を吸うエンジンで1段を狙う")], cur=7)),
    dict(id="c21", text="会社は2024年に経営破綻し、機体は作られないまま止まっています。", scene=K("tl", items=TL_ITEMS[:7] + [("2024", "スカイロン　会社が経営破綻、機体は作られず")], cur=7)),
    dict(id="c22", text="私が調べた範囲では、地上から1段で軌道に着いた機体は、まだありません。", scene=CARD(("地上から1段で軌道に着いた機体", 60, WHITE), ("私が調べた範囲では、まだ無い", 66, YEL))),
    dict(id="c23", text="水素の1段は、実機の重さでは、荷物が約2%。使い物になる量ではありません。ほぼ失敗です。", scene=CARGO(2, note=["水素の1段（実機の重さ）：荷物 約2%"])),
    dict(id="c24", text="段を捨てない道は、ここで尽きました。行き止まりです。最後に、段を捨てます。", scene=CARD(("段を捨てない道は", 70, WHITE), ("行き止まり", 120, RED))),
])
P["ch5"] = dict(title="第5章 実験5 使い終わった段を、捨てる", lines=[
    dict(id="c1", text="段を捨てない道は、行き止まり。実験5。燃料を使い切った段を、切り離して捨てます。", section=True, exp=5, scene=EXPCARD(5, "使い終わった段を、捨てる")),
    dict(id="c2", text="速さを半分ずつ、2つの段で出します。4.7km/sを、2回です。",
         scene=K("hstack", vmax=10, segs=[("1段目", 4.7, BLU, "4.7km/s"), ("2段目", 4.7, GRN, "4.7km/s")], total="合わせて 約9.4km/s", head="速さを2つに分ける")),
    dict(id="c3", text="1段で約24倍だった倍率が、各段で約4.9倍。4.9倍を2回掛けると、約24倍です。",
         scene=CARD(("1段で　約24倍", 76, WHITE), ("2段に分けると　各段 約4.9倍", 70, YEL), ("4.9 × 4.9 ＝ 約24", 80, GREEN))),
    dict(id="c4", text="3段に分ければ、各段は約2.9倍です。", scene=CARD(("3段に分けると", 70, WHITE), ("各段 約2.9倍", 120, YEL))),
    dict(id="c5", text="倍率は掛け算なので、速さを分けると、一気に楽になります。"),
    dict(id="c6", text="荷物を数えます。各段の空の機体を、8%と置きます。", scene=CARD(("各段の空の機体　8%", 90, YEL), ("荷物の割合を数える", 56, WHITE))),
    dict(id="c7", text="2章の5%や4.65%より重い。実機より厳しい置き方です。"),
    dict(id="c8", text="それでも荷物は、2段で約1.8%。1段では乗らなかった荷物が、乗りました。成功です。", scene=CARGO(1.8, note=["各段 8%の厳しい置き方でも、荷物が乗った"])),
    dict(id="c9", text="3段で約2.4%、4段で約2.6%。",
         scene=BARS([("2段", 1.8, None, "約1.8%", GRN), ("3段", 2.4, None, "約2.4%", GRN), ("4段", 2.6, None, "約2.6%", GRN)], 3.2, head="段の数と、荷物の割合")),
    dict(id="c10", text="3段から4段への増えは、わずか0.2ポイントです。"),
    dict(id="c11", text="段が増えるほど、つなぎ目もエンジンも増えます。この計算には入っていません。だから実機は、2〜3段に落ち着きます。",
         scene=CARD(("段が増えると", 66, WHITE), ("つなぎ目もエンジンも増える", 76, YEL), ("この計算には入っていない", 56, DIM))),
    dict(id="c12", text="答え合わせは、ファルコン9です。", section=True, scene=CARD(("答え合わせ", 120, YEL), ("ファルコン9", 90, WHITE))),
    dict(id="c13", text="1段目で出す速さは、約3.75km/s。2段目は、約5.50km/sです。",
         scene=K("hstack", vmax=10, segs=[("1段目", 3.75, BLU, "3.75km/s"), ("2段目", 5.5, GRN, "5.50km/s")], total="足して 約9.25km/s", head="ファルコン9の2つの段")),
    dict(id="c14", text="足して、約9.25km/s。燃料の勢いは、地上と宇宙の中間の値を使いました。簡易の計算です。"),
    dict(id="c15", text="9.3に近い、見積もりの下のほうです。", scene=RANGE([(9.25, "ファルコン9 約9.25km/s", GRN, 0), (9.4, "置いた値 約9.4km/s", YL, 1)])),
    dict(id="c16", text="運べる荷物は、使い捨ての場合で22.8トン。全体の約4%です。", scene=CARGO(4, big="22.8トン（約4%）", note=["ファルコン9　使い捨ての場合"])),
    dict(id="c17", text="実機が8%の計算より多く運べるのは、実機のほうが軽いから。"),
    dict(id="c18", text="空の機体は、1段目が約5.1%、2段目が約3.6%です。",
         scene=BARS([("計算の置き方", 8, None, "各段 8%", GREY), ("ファルコン9の1段目", 5.1, None, "約5.1%", GRN), ("ファルコン9の2段目", 3.6, None, "約3.6%", GRN)], 9, head="空の機体の割合")),
    dict(id="c19", text="しかも2段目は、燃料の勢いが348秒と高い。", scene=CARD(("2段目の燃料の勢い", 66, WHITE), ("348秒", 130, YEL))),
    dict(id="c20", text="荷物は、0%の灯油から、実機で約4%に。冒頭の数字に、ようやく届きました。", scene=CARGO(4, frm=0, ghost=4, ghost_txt="冒頭の約4%", note=["0% → 実機で約4%"])),
    dict(id="c21", text="水素でも、2段に分ければ、理想の置き方で約9.2%まで増えます。",
         scene=BARS([("水素　1段", 6, None, "約6%", GRN), ("水素　2段", 9.2, None, "約9.2%", GRN)], 10.5, head="水素の荷物（理想の置き方）")),
    dict(id="c22", text="答えです。灯油は、実機の軽さでは、1段で届きません。", scene=CARD(("答え", 130, YEL), ("灯油は、実機の軽さでは", 60, WHITE), ("1段で届かない", 90, RED))),
    dict(id="c23", text="水素なら届きます。でも実機の重さでは、荷物は2%ほど。だから実用的には、段を捨てます。",
         scene=CARD(("答え", 130, YEL), ("水素なら届く。でも荷物は2%ほど", 60, WHITE), ("だから実用的には、段を捨てる", 76, GREEN))),
    dict(id="c24", text="冒頭の1kgに戻ります。燃料込みで25kgを打ち上げて、運んだ荷物1kg。それは、使い終わった段を捨てながら運んだものです。", scene=K("kg", stage=1)),
    dict(id="c25", text="1段目を回収する機体も、いったんは切り離します。"),
    dict(id="c26", text="次にロケットの打ち上げを見たら、離れていく部分を目で追ってください。あれが、約9.4km/sに届くために手放した重さです。",
         scene=K("stages", mode="drop", head="離れていく部分", note="あれが、手放した重さ")),
])
P["s1"] = dict(title="9.4km/sの壁", lines=[
    dict(id="c1", text="ロケットが宇宙へ出るのに要る速さは、約秒速9.4km。新幹線の約106倍です。", scene=K("speedo", val=9.4, name="必要な速さ", rowtxt="秒速約9.4km", sub="見積もり", mult=True)),
    dict(id="c2", text="宇宙に出るとは、地球のまわりを回り続けること。その道が、軌道です。", scene=K("orbit")),
    dict(id="c3", text="地上200kmの軌道を回るだけなら、秒速7.8km。東京から大阪まで、約51秒です。", scene=K("route")),
    dict(id="c4", text="なのに、なぜ、7.8kmでは足りないのか。", style="question", sub="なのに\n【なぜ】\n7.8kmでは足りないのか", scene=QBLANK()),
    dict(id="c5", text="答えは、昇る間に失う速さ。重力に逆らう分、空気、向きを変える分で、約1.5〜2km/sです。",
         scene=K("hstack", vmax=10, segs=[("軌道の速さ", 7.8, BLU, "7.8km/s"), ("重力に逆らう分", 0.8, RD, ""), ("向きを変える分", 0.65, ORG, ""), ("空気", 0.15, GREY, "")], head="昇る間に失う速さ")),
    dict(id="c6", text="7.8に足して、約9.4km/s。資料には、9.3〜10km/sの幅があります。", scene=RANGE()),
    dict(id="c7", text="私がざっくり計算した値は、8.9km/sほどでした。", scene=RANGE([(8.9, "私の計算 8.9km/s", RD, 0)])),
    dict(id="c8", text="幅の中の値として、約9.4を置きます。見積もりです。", scene=RANGE([(8.9, "私の計算 8.9km/s", RD, 0), (9.4, "置く値 約9.4km/s", GRN, 1)])),
    dict(id="c9", text="ざっくり計算で、いちばん大きいのは、重力に逆らう分。約0.8km/sです。空気の抵抗は、ごくわずかでした。",
         scene=K("hstack", vmax=10, segs=[("軌道の速さ", 7.8, BLU, "7.8km/s"), ("重力に逆らう分", 0.8, RD, ""), ("向きを変える分", 0.65, ORG, ""), ("空気", 0.15, GREY, "")], head="いちばん大きいのは重力")),
    dict(id="c10", text="一方で、地球の自転が助けてくれます。東向きに打てば、種子島で秒速約400m。", scene=K("rotation", stage=0)),
    dict(id="c11", text="時速にすると、約1440km。7.8kmの約5%が、打つ前から付いています。", scene=K("rotation", stage=1)),
    dict(id="c12", text="約9.4は、この助けを引いたあとの値です。"),
    dict(id="c13", text="ロケットが東へ傾いていくのを見たら、地球の回転に乗ろうとしている姿です。"),
])
P["s2"] = dict(title="燃料96%、機体は4%", lines=[
    dict(id="c1", text="アメリカのロケット、ファルコン9。これを、1つの機体で宇宙へ行けるか、考えます。", scene=K("f9", stage=0)),
    dict(id="c2", text="離陸の重さを、1トンとします。軽自動車1台ぶんです。目指す速さは、約秒速9.4km。", scene=K("ton", stage=0, split=False)),
    dict(id="c3", text="燃料の勢いは、ファルコン9に近い値に置きます。この勢いを表す数字を、比推力といいます。300秒です。", scene=CARD(("比推力　300秒", 120, YEL), ("燃料の勢いを表す数字", 56, WHITE))),
    dict(id="c4", text="この条件だと、離陸の重さは、燃え尽きたあとの約24倍、必要です。この倍率で、残りの重さが決まります。", scene=K("ratio", rows=[("必要な倍率", 24.4, YL, "約24倍")], head="倍率のメーター")),
    dict(id="c5", text="燃料は約960kg。残りは約40kgです。", scene=K("ton", stage=0)),
    dict(id="c6", text="残りの40kgに、タンクもエンジンも荷物も入ります。大人1人より軽い重さです。"),
    dict(id="c7", text="ファルコン9の1段目は、公開されている資料から割ると、空の機体が約5%。1トンなら、約51kgです。1段目とは、下の部分のことです。", scene=K("f9", stage=2, head="ファルコン9の1段目")),
    dict(id="c8", text="40kgに対して、51kg。足りません。", scene=K("ton", stage=2)),
    dict(id="c9", text="荷物がゼロでも、届く速さは秒速8.7〜9.1km。", scene=RANGE([(9.4, "必要 約9.4km/s", RD, 0)], bands=[(8.7, 9.1, "荷物ゼロで届く速さ 8.7〜9.1km/s", AMBER)])),
    dict(id="c10", text="つまり、1つの機体では、荷物どころか、機体の分が先に足りません。"),
    dict(id="c11", text="ロケットが細長いのは、中身の大半が燃料で、機体は薄い皮だからです。"),
])
P["s3"] = dict(title="風船のタンク", lines=[
    dict(id="c1", text="空っぽだと、自分の重さでつぶれるロケットがありました。アトラスです。", scene=K("balloon", stage=1)),
    dict(id="c2", text="1958年に、衛星を軌道へ乗せた、アメリカのロケット。軌道とは、地球のまわりを回る道です。", scene=K("balloon", stage=2)),
    dict(id="c3", text="タンクは薄いステンレス。風船のようなタンクでした。", scene=K("balloon", stage=0)),
    dict(id="c4", text="空でも、窒素というガスで膨らませておかないと、形を保てません。", scene=K("balloon", stage=1)),
    dict(id="c5", text="横に補助のエンジン、ブースターが付いていて、途中で捨てる形でした。1.5段式といいます。", scene=K("balloon", stage=2)),
    dict(id="c6", text="捨てる前の全部で数えます。離陸の重さは116トン。空の機体は5.4トンです。",
         scene=BARS([("離陸の重さ", 116, None, "116トン", AMBER), ("空の機体", 5.4, None, "5.4トン", GREY)], 125, head="アトラスの重さ")),
    dict(id="c7", text="割ると、約4.65%。", scene=CARD(("空の機体の割合", 66, WHITE), ("約4.65%", 130, YEL))),
    dict(id="c8", text="ここまで軽くしても、荷物はゼロの理想で、秒速約9.0km。燃料の勢いは、300秒と置いた値です。", scene=K("speedo", val=9.0, name="アトラスの理想", rowtxt="秒速約9.0km", sub="荷物ゼロの理想")),
    dict(id="c9", text="見積もりの下端、9.3にも届きません。実機の軽さでは、約9.4kmに、あと1割ほど足りません。", scene=RANGE([(9.0, "アトラス 約9.0km/s", AMBER, 0), (9.4, "必要 約9.4km/s", RD, 1)])),
    dict(id="c10", text="つまり、軽くするには限界があります。風船より軽いタンクは、作れそうにありません。"),
    dict(id="c11", text="アトラスが軌道に着いたのは、ブースターを約2分で捨てたから。捨てたあとの空の機体は、離陸の重さの約2%でした。",
         scene=CARD(("ブースターを約2分で捨てると", 60, WHITE), ("空の機体は 離陸の重さの約2%", 66, YEL))),
    dict(id="c12", text="風船をふくらませるように、ロケットも、中の圧で形を保っています。", scene=K("balloon", stage=0)),
])
P["s4"] = dict(title="燃料を足しても", lines=[
    dict(id="c1", text="燃料を増やせば、その分だけ速くなる。そう思いませんか。", scene=CARD(("燃料を増やせば", 80, WHITE), ("その分だけ速くなる？", 90, YEL))),
    dict(id="c2", text="理由は、増やした分、タンクも重くなるから。速さは、思ったほど伸びません。", scene=K("growtank")),
    dict(id="c3", text="ここで、倍率を使います。離陸のときの重さが、燃え尽きたあとの重さの、何倍か。", scene=K("massfig")),
    dict(id="c4", text="アトラスの倍率は、約21.5倍。速さは約9.0km/sです。", scene=K("ratio", rows=[("アトラス　速さ 約9.0km/s", 21.5, AMBER, "約21.5倍")], need=24.4, head="倍率のメーター")),
    dict(id="c5", text="倍率を約31倍にできれば、速さは約10.1km/s。でもそれは、タンクを変えずに、燃料だけ足せた場合です。",
         scene=K("ratio", rows=[("燃料を足して　速さ 約10.1km/s", 31, GRN, "約31倍")], need=24.4, head="倍率のメーター")),
    dict(id="c6", text="タンクの割合が同じなら、倍率は約21.5倍で止まります。", scene=K("limit")),
    dict(id="c7", text="100を、空の機体の割合4.65で割った数が、上限だからです。"),
    dict(id="c8", text="欲しいのは、約24倍。燃料をいくら足しても、届きません。"),
    dict(id="c9", text="速さを1km/s足すたび、倍率は約1.4倍。速さは足し算、倍率は掛け算です。", scene=K("compound")),
    dict(id="c10", text="速さは、4%ちょっとの増加。でも倍率は、1割以上の増加です。",
         scene=BARS([("速さ　9.0 → 9.4km/s", 4.4, None, "4%ちょっと", BLU), ("倍率　21.5 → 24.4", 13.5, None, "1割以上", RD)], 16, head="増えた割合")),
    dict(id="c11", text="引っ越しの荷物を増やすと、段ボールも増えます。運ぶ重さの割合は、変わりません。", scene=CARD(("荷物を増やすと", 70, WHITE), ("段ボールも増える", 100, YEL))),
])
P["s5"] = dict(title="段を捨てる", lines=[
    dict(id="c1", text="ロケットは、燃料を使い切ったら、その部分を切り離します。この区切りを、段といいます。", scene=K("stages", mode="cut")),
    dict(id="c2", text="倍率とは、離陸のときの重さが、燃え尽きたあとの重さの、何倍か。1つの機体だと、約24倍も要りました。", scene=K("massfig")),
    dict(id="c3", text="2段に分けると、各段は約4.9倍。3段なら、各段は約2.9倍です。",
         scene=K("ratio", rows=[("1段", 24.4, GREY, "約24倍"), ("2段　各段", 4.9, GRN, "約4.9倍"), ("3段　各段", 2.9, GRN, "約2.9倍")], head="必要な倍率")),
    dict(id="c4", text="答えは、速さを分けること。倍率は掛け算なので、半分ずつなら、ぐっと楽になります。"),
    dict(id="c5", text="各段の空の機体を、実機より重い8%と置きます。荷物は、2段で約1.8%。3段で約2.4%。4段で約2.6%です。",
         scene=BARS([("2段", 1.8, None, "約1.8%", GRN), ("3段", 2.4, None, "約2.4%", GRN), ("4段", 2.6, None, "約2.6%", GRN)], 3.2, head="段の数と、荷物の割合")),
    dict(id="c6", text="3段から4段への増えは、0.2ポイントだけ。"),
    dict(id="c7", text="段が増えれば、つなぎ目もエンジンも増えます。この計算には入っていません。", scene=CARD(("段が増えると", 66, WHITE), ("つなぎ目もエンジンも増える", 76, YEL))),
    dict(id="c8", text="だから実機は、2〜3段になります。"),
    dict(id="c9", text="ファルコン9は2段で、約9.25km/s。9.3に近い、見積もりの下のほうです。燃料の勢いは、地上と宇宙の中間の値で数えた、簡易の計算です。",
         scene=K("hstack", vmax=10, segs=[("1段目", 3.75, BLU, "3.75km/s"), ("2段目", 5.5, GRN, "5.50km/s")], total="足して 約9.25km/s", head="ファルコン9の2つの段")),
    dict(id="c10", text="荷物は、使い捨ての場合で22.8トン、全体の約4%。", scene=CARGO(4, big="22.8トン（約4%）", note=["ファルコン9　使い捨ての場合"])),
    dict(id="c11", text="8%の計算より多いのは、機体が軽く、2段目の燃料の勢いが高いからです。",
         scene=BARS([("計算の置き方", 8, None, "各段 8%", GREY), ("ファルコン9の1段目", 5.1, None, "約5.1%", GRN), ("ファルコン9の2段目", 3.6, None, "約3.6%", GRN)], 9, head="空の機体の割合")),
    dict(id="c12", text="階段を一気に飛ぶより、踊り場で休みながら登るほうが楽。ロケットも、段を分けて登ります。", scene=CARD(("階段を一気に飛ぶより", 66, WHITE), ("踊り場で休みながら登る", 90, YEL))),
])


def _finish(lines):
    """実験の札(exp)を次の行へ引き継ぎ、「失敗です」「成功です」「ほぼ失敗です」の行に札を出す位置(行の中の割合)を足す。"""
    cur = 0
    res = []
    for l in lines:
        l = dict(l)
        if "exp" in l:
            cur = l["exp"]
        else:
            l["exp"] = cur
        for key, kind in (("ほぼ失敗です", "almost"), ("失敗です", "fail"), ("成功です", "ok")):
            if key in l["text"]:
                l["verdict"] = (kind, l["text"].index(key) / len(l["text"]))
                break
        res.append(l)
    return res


# 読みの直し(kana の出力を全行見て、違う所だけ)。長い語から順に置き換えて say を作る
YOMI = [("ファルコン9", "ファルコンナイン"), ("km/s", "キロメートルまいびょう"), ("〜", "から"), ("X-33", "エックスさーてぃーすりー"),
        ("DC-XA", "でぃーしーえっくすえー"), ("DC-X", "でぃーしーえっくす"), ("H3", "えいちすりー"), ("お米の袋", "おこめのふくろ"),
        ("100割る", "ひゃくわる")]


def yomi(text):
    s = text
    for a, b in YOMI:
        s = s.replace(a, b)
    return s


def ep_for(name: str) -> dict:
    p = dict(P[name])
    p["lines"] = _finish(p["lines"]) if name.startswith("ch") else p["lines"]
    res = []
    for l in p["lines"]:
        y = yomi(l["text"])
        res.append(dict(l, say=y) if y != l["text"] else l)
    p["lines"] = res
    return dict(kind="sim", aspect="portrait" if name.startswith("s") else "landscape", credit=CREDIT_V if name.startswith("s") else CREDIT, **p)
