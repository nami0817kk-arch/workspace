"""ショート5「予知できない理由」(本編 第5章)。出典は ../research.md。"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common import *  # noqa: E402,F403
from naze import mapscene  # noqa: E402
from naze.mapscene import draw  # noqa: E402,F401

NANKAI = [dict(kind="label", id="nk", at_ll=(135.6, 32.3), text="南海トラフ", color=O.YEL, size=50, at=0.3)]
NV = (136, 33.6, 9)
S1 = dict(view=P_JAPAN, layers=[Q(id="qall", grow=0.8)])
S2 = dict(view=P_JAPAN, layers=[Q(id="qall")], panel=dict(kind="quote", text="「日時と場所を特定した\n地震を予知する情報は\nデマと考えられます」", src=JMA_SRC, size=56, at=0.2))
S3 = dict(view=P_JAPAN, layers=[PLATES], panel=dict(kind="image", path=str(ASSETS / "ruler_gemini.jpg"), at=0.0))
S4 = dict(view=P_JAPAN, layers=[PLATES], panel=dict(kind="image", path=str(ASSETS / "subduction_gemini.jpg"), at=0.0))
S5 = dict(view=NV, layers=[PLATES_FILL, PLATES] + NANKAI)
S6 = dict(view=NV, layers=[PLATES_FILL, PLATES] + NANKAI, panel=dict(kind="big", text="60〜90%程度以上", sub="30年以内（別の計算では20〜50%）", size=86, at=0.1))

EP = dict(
    kind="sim", title="地震の予知はできない、と気象庁も言っている", credit=CREDIT,
    lines=[
        dict(id="c1", text="「来週、東京で大地震」。そんな情報を、見たことはありませんか。", scene=S1),
        dict(id="c2", text="気象庁は、日時と場所を特定した予知の情報は、デマと考えられる、と説明しています。", scene=S2),
        dict(id="c3", text="なぜ、予知できないのか。", style="question", sub="なぜ、地震は\n【予知できない】のか。"),
        dict(id="c4", text="答えは、地面のこわれ方。下じきを、曲げるところを、思い浮かべてください。", scene=S3),
        dict(id="c5", text="いつ戻るかは、小さな傷や、力のかかり方で、変わります。"),
        dict(id="c6", text="地下の板も同じ。ゆがみがたまっていても、いつ割れるかは、決まらないのです。", scene=S4),
        dict(id="c7", text="その代わりに、国は、確率を出しています。", scene=S5),
        dict(id="c8", text="南海トラフの地震は、30年以内に、60〜90%程度以上。別の計算では、20〜50%。", scene=S6,
             say="なんかいトラフの、じしんは、さんじゅうねんいないに、ろくじゅっパーセントから、きゅうじゅっパーセント、ていどいじょう。べつのけいさんでは、にじゅっパーセントから、ごじゅっパーセント。"),
        dict(id="c9", text="どちらも、いちばん高いランクです。"),
        dict(id="c10", text="日付は言えなくても、起きやすさは分かる。だから、備えることに意味があります。", scene=S5),
        dict(id="c11", text="次に「予知」を名乗る情報を見たら、気象庁の、この説明を思い出してください。", scene=S2),
    ],
)


def sfx_events(L):
    return mapscene.sfx(EP["lines"], L)
