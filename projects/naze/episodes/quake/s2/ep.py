"""ショート2「はがき1枚ぶん近づく海」(本編 第2章)。出典は ../research.md。"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common import *  # noqa: E402,F403
from naze import mapscene  # noqa: E402
from naze.mapscene import draw  # noqa: E402,F401

AR = dict(kind="arrow", id="arPA", a=(146.5, 36.5), b=(143.2, 37.3), color=M.PLATE_COL["PA"])
S1 = dict(view=P_JAPAN, layers=[PLATES_FILL, PLATES, AR])
S2 = dict(view=P_JAPAN, layers=[PLATES_FILL, PLATES, AR], panel=dict(kind="big", text="年に約8cm", sub="はがきの短い辺（10cm）ほど", size=120, at=0.1))
S3 = dict(view=P_JAPAN, layers=[PLATES_FILL, PLATES, AR], panel=dict(kind="big", text="1万年で800m", sub="100年で8m", size=110, at=0.1))
S4 = dict(view=P_WORLD, layers=[dict(PLATES, grow=0.8)])
S5 = dict(view=P_JAPAN, layers=[PLATES], panel=dict(kind="image", path=str(ASSETS / "subduction_gemini.jpg"), at=0.0))
S6 = dict(view=P_JAPAN, layers=[PLATES], panel=dict(kind="image", path=str(ASSETS / "ruler_gemini.jpg"), at=0.0))
S7 = dict(view=P_JAPAN, layers=[PLATES_FILL, PLATES, AR, Q(id="qall", grow=0.8)])

EP = dict(
    kind="sim", title="海の板は年に8cmずつ日本に近づいている", credit=CREDIT,
    lines=[
        dict(id="c1", text="太平洋の海の底は、1年に約8cm、日本に近づいています。", scene=S1),
        dict(id="c2", text="はがきの短い辺が、10cm。毎年、そのくらいです。", scene=S2, say="はがきの、みじかいへんが、じゅっセンチ。まいとし、そのくらいです。"),
        dict(id="c3", text="100年で8m。1万年なら、800mです。", scene=S3, say="ひゃくねんで、はちメートル。いちまんねんなら、はっぴゃくメートルです。"),
        dict(id="c4", text="動いているのは、海の底をつくる、岩の板。プレートと呼びます。", scene=S4),
        dict(id="c5", text="近づいた板は、どこへ行くのか。", style="question", sub="近づいた板は\n【どこへ】行くのか。"),
        dict(id="c6", text="答えは、日本の下。陸の板の下へ、もぐりこんでいきます。", scene=S5),
        dict(id="c7", text="このとき、陸の板の端が、地下へ引きずりこまれます。"),
        dict(id="c8", text="下じきを、ゆっくり曲げるのと、同じです。曲げ続けると、パチンと戻る。", scene=S6),
        dict(id="c9", text="陸の板が耐えきれず、跳ね上がる。これが、プレートの境目の地震です。", scene=S5),
        dict(id="c10", text="海の板が動くかぎり、ゆがみは、たまり続けます。だから、くり返すのです。", scene=S7),
        dict(id="c11", text="次に地震のニュースを見たら、年に8cmの、この動きを思い出してください。"),
    ],
)


def sfx_events(L):
    return mapscene.sfx(EP["lines"], L)
