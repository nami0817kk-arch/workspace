"""本編 第2章「地面の下の、4枚の板」。出典は ../research.md。"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common import *  # noqa: E402,F403
from naze import mapscene  # noqa: E402
from naze.mapscene import draw  # noqa: E402,F401

PLATE_ARROWS = [dict(kind="arrow", id="arPA", a=(152, 37), b=(147, 38), color=M.PLATE_COL["PA"], at=0.1),
                dict(kind="arrow", id="arPS", a=(139, 27.5), b=(137, 30.5), color=M.PLATE_COL["PS"], at=0.1)]
S_WORLD_PL = dict(view=WORLD_V, layers=[dict(PLATES, grow=0.9)])
S_RING = dict(view=WORLD_V, layers=[PLATES, Q(id="wq", data=WORLD, grow=0.5)])
S_JP4 = dict(view=JAPAN_V, layers=[PLATES_FILL, PLATES] + plate_labels())
S_MOVE = dict(view=JAPAN_PANEL_V, layers=[PLATES_FILL, PLATES] + PLATE_ARROWS,
              panel=dict(kind="big", text="年に約8cm", sub="はがきの短い辺（10cm）ほど", at=0.4))
S_MOVE2 = dict(view=JAPAN_PANEL_V, layers=S_MOVE["layers"], panel=dict(kind="big", text="1万年で800m", sub="100年で8m", at=0.2))
S_MOVE3 = dict(view=JAPAN_V, layers=[PLATES_FILL, PLATES] + PLATE_ARROWS)
S_SUB = dict(view=JAPAN_PANEL_V, layers=[PLATES], panel=dict(kind="image", path=str(ASSETS / "subduction_gemini.jpg"), at=0.0))
S_RULER = dict(view=JAPAN_PANEL_V, layers=[PLATES], panel=dict(kind="image", path=str(ASSETS / "ruler_gemini.jpg"), at=0.0))
S_ENERGY = dict(view=JAPAN_PANEL_V, layers=[Q(id="qall", grow=0.8)],
                panel=dict(kind="compare", value="約32倍", unit="1の箱", n=32, note="マグニチュードが1上がると", at=0.3))
S_ENERGY2 = dict(view=JAPAN_PANEL_V, layers=[Q(id="qall")], panel=dict(kind="big", text="約1000倍", sub="マグニチュードが2上がると", at=0.1))
S_MAG = dict(view=JAPAN_PANEL_V, layers=[Q(id="qall")], panel=dict(kind="bars", items=MAG_BARS, title="日本の近くのM4以上（2014〜2023年）", at=0.1, grow=2.5))
S_TOHOKU = dict(view=TOHOKU_V, layers=[Q(id="qt")])

EP = dict(
    kind="sim", aspect="landscape", title="第2章 地面の下の、4枚の板", credit=CREDIT, cta=False,
    lines=[
        dict(id="c1", text="地球の表面は、十数枚の、かたい岩の板で、おおわれています。", scene=S_WORLD_PL),
        dict(id="c2", text="この板を、プレートと呼びます。"),
        dict(id="c3", text="卵の殻の、ひびのように、板と板には、境目があります。"),
        dict(id="c4", text="前の章で見た、太平洋を囲む地震の輪。あれは、板の境目そのものです。", scene=S_RING),
        dict(id="c5", text="日本の下には、そのうち、4枚が集まっています。", scene=S_JP4),
        dict(id="c6", text="海の板が、2枚。太平洋プレートと、フィリピン海プレート。", say="うみのいたが、にまい。たいへいようプレートと、フィリピンかいプレート。"),
        dict(id="c7", text="陸の板が、2枚。北米プレートと、ユーラシアプレート。"),
        dict(id="c8", text="日本列島は、4枚の板の、つなぎ目の上に、乗っているのです。"),
        dict(id="c9", text="しかも、海の板は、じっとしていません。", section=True, scene=S_MOVE3),
        dict(id="c10", text="太平洋プレートは、1年に約8cm、日本の方へ動いています。", scene=S_MOVE),
        dict(id="c11", text="はがきの短い辺が、10cm。毎年、そのくらいずつ、近づいてくる計算です。",
             say="はがきの、みじかいへんが、じゅっセンチ。まいとし、そのくらいずつ、ちかづいてくる、けいさんです。"),
        dict(id="c12", text="100年で、8m。1万年なら、800mになります。", scene=S_MOVE2, say="ひゃくねんで、はちメートル。いちまんねんなら、はっぴゃくメートルになります。"),
        dict(id="c13", text="フィリピン海プレートは、1年に、3cmから5cm。", scene=S_MOVE3, say="フィリピンかいプレートは、いちねんに、さんセンチから、ごセンチ。"),
        dict(id="c14", text="動いてきた海の板は、日本の下へ、もぐりこんでいきます。", scene=S_SUB),
        dict(id="c15", text="このとき、陸の板の端を、地下へ、引きずりこみます。"),
        dict(id="c16", text="引きずられた陸の板は、少しずつ、ゆがみを、ためていきます。"),
        dict(id="c17", text="下じきを、ゆっくり曲げていくところを、思い浮かべてください。", section=True, scene=S_RULER),
        dict(id="c18", text="曲げ続けると、あるとき、パチンと戻ります。"),
        dict(id="c19", text="陸の板が、耐えきれずに、跳ね上がる。", scene=S_SUB),
        dict(id="c20", text="これが、プレートの境目で起きる地震です。"),
        dict(id="c21", text="海の板が動き続けるかぎり、ゆがみは、たまり続けます。"),
        dict(id="c22", text="だから日本では、同じ場所で、地震が、くり返し起きるのです。"),
        dict(id="c23", text="地震の大きさは、マグニチュードで表します。", scene=S_ENERGY),
        dict(id="c24", text="マグニチュードが1上がると、地震のエネルギーは、約32倍。"),
        dict(id="c25", text="2上がると、約1000倍です。", scene=S_ENERGY2),
        dict(id="c26", text="そのかわり、大きな地震ほど、めったに起きません。", scene=S_MAG),
        dict(id="c27", text="日本の近くの10年を数えると、マグニチュード4台が、10435回。5台は999回。6台は81回。7台は6回。"),
        dict(id="c28", text="1つ上がるごとに、回数は、ほぼ10分の1。気象庁の説明と、同じ形になりました。",
             say="ひとつあがるごとに、かいすうは、ほぼ、じゅうぶんのいち。きしょうちょうの、せつめいと、おなじかたちに、なりました。"),
        dict(id="c29", text="この下じきの話は、最後の章で、もう一度使います。", scene=S_RULER),
        dict(id="c30", text="では、もぐりこんだ海の板は、地下で、どんな形をしているのか。震源の記録で、見てみます。", scene=S_TOHOKU),
    ],
)


def sfx_events(L):
    return mapscene.sfx(EP["lines"], L)
