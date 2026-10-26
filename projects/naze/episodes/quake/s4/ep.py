"""ショート4「5.3m動いた日本」(本編 第4章)。出典は ../research.md。ずれた面の四角は気象庁の解析の大きさを置いたおおよその範囲。"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common import *  # noqa: E402,F403
from naze import mapscene  # noqa: E402
from naze.mapscene import draw  # noqa: E402,F401

OSHIKA = (141.50, 38.30)
RUPTURE = dict(kind="box", id="rupture", sw=(141.7, 36.1), ne=(144.0, 40.15), at=0.2)
EPI = dict(kind="label", id="epi", at_ll=(142.86, 38.10), text="×", color=O.WHITE, size=64)
S1 = dict(view=(141.7, 38.3, 3.2), layers=[dict(kind="label", id="osl", at_ll=(141.2, 38.55), text="観測点「牡鹿」", color=O.WHITE, size=44),
                                           dict(kind="arrow", id="osa", a=OSHIKA, b=(142.15, 38.12), color=O.YEL, at=0.3)],
          panel=dict(kind="big", text="東南東へ約5.3m", sub="国土地理院の観測", size=96, at=0.3))
S2 = dict(view=(141.7, 38.3, 3.2), layers=S1["layers"], panel=dict(kind="big", text="約1.2m沈んだ", sub="同じ観測点", size=96, at=0.1))
Q11 = Q(id="q2011", data="world_m6_2011-2011", by_depth=False, color=O.RED, size=2.0, grow=0.5)
S3 = dict(view=(142.3, 38.3, 7), layers=[Q11, EPI, RUPTURE])
S4 = dict(view=(139.8, 37.2, 9), layers=[RUPTURE, dict(kind="line", id="to", a=TOKYO, b=OSAKA, at=0.2),
                                        dict(kind="label", id="tol", at_ll=(137.6, 36.2), text="東京〜大阪 約400km", color=O.YEL, size=40, at=0.5)])
S5 = dict(view=(142.3, 38.3, 7), layers=[RUPTURE, EPI], panel=dict(kind="big", text="約28m", sub="いちばん大きくずれた所（ビル9階ほど）", size=130, at=0.1))
S6 = dict(view=P_TOHOKU, layers=[RUPTURE], panel=section_panel(at=0.0, grow=0.6))
S7 = dict(view=(142.3, 38.3, 7), layers=[Q11, EPI, RUPTURE])

EP = dict(
    kind="sim", title="2011年、宮城の地面は一度に5.3m動いた", credit=CREDIT,
    lines=[
        dict(id="c1", text="2011年3月11日。宮城県石巻市の地面は、一度に、東南東へ約5.3m、動きました。", scene=S1,
             say="にせんじゅういちねん、さんがつじゅういちにち。みやぎけん、いしのまきしの、じめんは、いちどに、とうなんとうへ、やく、ごてんさんメートル、うごきました。"),
        dict(id="c2", text="国土地理院の、観測点の記録です。"),
        dict(id="c3", text="同時に、約1.2m、沈みました。", scene=S2, say="どうじに、やく、いってんにメートル、しずみました。"),
        dict(id="c4", text="なぜ、地面ごと、動いたのか。", style="question", sub="なぜ、地面ごと\n【動いた】のか。"),
        dict(id="c5", text="答えは、地下で、海の板と陸の板の境目が、ずれたからです。", scene=S3),
        dict(id="c6", text="ずれた面の長さは、約450km。東京から大阪までの直線より、長い。", scene=S4),
        dict(id="c7", text="いちばん大きくずれた所は、約28m。ビルの9階ほどです。", scene=S5, say="いちばん、おおきくずれたところは、やく、にじゅうはちメートル。ビルの、きゅうかいほどです。"),
        dict(id="c8", text="海の板に引きずりこまれていた陸の板が、海の方へ、跳ね返ったのです。", scene=S6),
        dict(id="c9", text="マグニチュード9.0。国内の観測史上、最大の地震でした。", scene=S7),
        dict(id="c10", text="次に地図で東北の海を見たら、その沖の、450kmの面を思い出してください。"),
    ],
)


def sfx_events(L):
    return mapscene.sfx(EP["lines"], L)
