"""ショート1「0.25%と2割」(本編 第1章の答えを 1 本で)。出典は ../research.md。"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common import *  # noqa: E402,F403
from naze import mapscene  # noqa: E402
from naze.mapscene import draw  # noqa: E402,F401

JPL = dict(kind="label", id="jp", at_ll=(138, 37), text="日本", size=60, color=O.YEL)
S1 = dict(view=P_WORLD, layers=[JPL])
S2 = dict(view=P_WORLD, layers=[JPL, Q(id="wq", data=WORLD, grow=0.8)],
          panel=dict(kind="compare", value="18.5%", unit="陸地の割合 0.25%", n=74, note="M6以上の地震（2003〜2013年）", at=0.2))
S3 = dict(view=P_JAPAN, layers=[PLATES_FILL, PLATES] + plate_labels(portrait=True))
S4 = dict(view=P_WORLD, layers=[PLATES, Q(id="wq", data=WORLD, grow=0.5), JPL])
S5 = dict(view=P_JAPAN, layers=[PLATES_FILL, PLATES, dict(kind="arrow", id="arPA", a=(146.5, 36.5), b=(143.2, 37.3), color=M.PLATE_COL["PA"])])
S6 = dict(view=P_JAPAN, layers=[PLATES], panel=dict(kind="image", path=str(ASSETS / "subduction_gemini.jpg"), at=0.0))
S7 = dict(view=P_JAPAN, layers=[Q(id="qall", grow=0.8)], panel=dict(kind="big", text="1日に約5回", sub="震度1以上（ふだんの年 約2000回）", size=110, at=0.2))
S8 = dict(view=P_JAPAN, layers=[Q(id="qall")], panel=dict(kind="big", text="1日に12回", sub="去年 2025年は 4456回", size=110, at=0.2))

EP = dict(
    kind="sim", title="日本の陸地は世界の0.25%なのに", credit=CREDIT,
    lines=[
        dict(id="c1", text="日本の陸地は、世界のわずか0.25%。", scene=S1),
        dict(id="c2", text="なのに、世界の大きな地震の、約2割が、日本で起きています。", scene=S2),
        dict(id="c3", text="マグニチュード6以上を数えた、国の集計です。陸地の割合の、70倍以上。"),
        dict(id="c4", text="なぜ、日本にだけ、集まるのか。", style="question", sub="なぜ、日本にだけ\n【集まる】のか。"),
        dict(id="c5", text="答えは、地面の下。日本の下には、岩の板が、4枚集まっています。", scene=S3),
        dict(id="c6", text="太平洋を囲む、地震の輪。日本は、その北西の角です。", scene=S4),
        dict(id="c7", text="海の板が、年に8cmずつ押し寄せて、日本の下へ、もぐりこむ。", scene=S5, say="うみのいたが、ねんに、はっセンチずつ、おしよせて、にほんのしたへ、もぐりこむ。"),
        dict(id="c8", text="引きずられた陸の板が、ゆがみをため、跳ね上がる。それが、地震です。", scene=S6),
        dict(id="c9", text="揺れを感じる地震は、ふだんの年で、およそ2000回。1日に5回ほど。", scene=S7),
        dict(id="c10", text="去年は、4456回。1日に12回でした。", scene=S8),
        dict(id="c11", text="次に小さな揺れを感じたら、足もとで、板が押し合っていることを、思い出してください。", scene=S3),
    ],
)


def sfx_events(L):
    return mapscene.sfx(EP["lines"], L)
