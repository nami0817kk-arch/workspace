"""ショート3「震源を並べたら、板が見えた」(本編 第3章)。出典は ../research.md。"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common import *  # noqa: E402,F403
from naze import mapscene  # noqa: E402
from naze.mapscene import draw  # noqa: E402,F401

LINE = dict(kind="line", id="secline", a=(144.5, 38.5), b=(139.3, 38.5))
SEC = section_panel(at=0.1, grow=3.0)
S1 = dict(view=P_JAPAN, layers=[Q(id="qall", grow=0.9)])
S2 = dict(view=P_TOHOKU, layers=[Q(id="qt"), LINE])
S3 = dict(view=P_TOHOKU, layers=[Q(id="qt"), LINE], panel=SEC)
DEEP = Q(id="qdeep", filter=lambda q: q[2] >= 300, size=1.8, grow=0.6)
S4 = dict(view=(140, 30, 16), layers=[DEEP, dict(kind="label", id="deepest", at_ll=(140.6, 26.9), text="最深 686km", color=(190, 90, 230), size=52, at=0.3)],
          panel=dict(kind="compare", value="686km", unit="富士山10個", n=18, note="富士山の約180個分", at=0.5, box=(60, 200, 1020, 620)))

EP = dict(
    kind="sim", title="1万回の震源を並べたら", credit=CREDIT,
    lines=[
        dict(id="c1", text="日本の近くで、10年に起きた地震。マグニチュード4以上で、11521回。", scene=S1),
        dict(id="c2", text="その震源を、東北で、縦に切って並べてみました。", scene=S2),
        dict(id="c3", text="普通は、震源の深さは、ばらばらだと思いがちです。", scene=S3),
        dict(id="c4", text="ところが、海の近くは浅く、西へ行くほど、深くなっていきます。"),
        dict(id="c5", text="海溝の近くで、深さ10km。陸の真下で、50km。"),
        dict(id="c6", text="日本海側の下では、100km前後。"),
        dict(id="c7", text="点が、斜めの線に、並んでいます。"),
        dict(id="c8", text="これは、日本の下へもぐりこむ、海の板の形です。"),
        dict(id="c9", text="深さを並べるだけで、見えない地下が、浮かび上がるのです。"),
        dict(id="c10", text="いちばん深い震源は、686km。富士山を、約180個積んだ深さでした。", scene=S4),
        dict(id="c11", text="次に震源の深さを聞いたら、その下にある、斜めの板を思い出してください。", scene=S3),
    ],
)


def sfx_events(L):
    return mapscene.sfx(EP["lines"], L)
