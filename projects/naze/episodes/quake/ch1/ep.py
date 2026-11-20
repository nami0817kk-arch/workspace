"""本編 第1章「本当に、多いのか」。出典は ../research.md。"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common import *  # noqa: E402,F403
from naze import mapscene  # noqa: E402
from naze.mapscene import draw  # noqa: E402,F401

S_WORLD = dict(view=WORLD_V, layers=[dict(kind="label", id="jp", at_ll=(138, 37), text="日本", size=56, color=O.YEL)])
S_RATIO = dict(view=WORLD_V, layers=S_WORLD["layers"] + [Q(id="wq", data=WORLD, grow=0.8)],
               panel=dict(kind="compare", value="18.5%", unit="陸地の割合 0.25%", n=74, note="M6以上の地震（2003〜2013年）", at=0.1,
                          box=(1040, 540, 1880, 880)))
S_BOX = dict(view=BOX_V, layers=[BOX, Q(id="q6", data=WORLD, grow=0.6, size=1.6)])
S_2011 = dict(view=BOX_V, layers=[BOX, Q(id="q2011", data="world_m6_2011-2011", by_depth=False, color=O.RED, size=1.6, grow=0.6),
                                  dict(kind="label", id="l2011", at_ll=(149, 41), text="2011年のM6以上", color=O.RED, size=50)])
S_RING = dict(view=WORLD_V, layers=[Q(id="wq", data=WORLD, grow=0.5)], panel=dict(kind="bars", items=COUNTRY_BARS, hl=[5], title="M6以上の回数（2014〜2023年）", at=0.15))
S_RING2 = dict(view=WORLD_V, layers=[Q(id="wq", data=WORLD), PLATES])
S_FELT = dict(view=JAPAN_PANEL_V, layers=[Q(id="qall", grow=0.9)], panel=dict(kind="bars", items=FELT_BARS, hl=[0, 9], title="震度1以上を観測した回数（気象庁）", at=0.05))
S_END = dict(view=JAPAN_V, layers=[Q(id="qall")])

EP = dict(
    kind="sim", aspect="landscape", title="第1章 本当に、多いのか", credit=CREDIT, cta=False,
    lines=[
        dict(id="c1", text="日本の陸地は、世界のわずか0.25%です。", scene=S_WORLD),
        dict(id="c2", text="ところが、世界の大きな地震の、約2割が、日本で起きています。", scene=S_RATIO),
        dict(id="c3", text="マグニチュード6以上を数えた、内閣府の集計です。2003年から2013年まで。"),
        dict(id="c4", text="陸地の割合の、70倍以上です。"),
        dict(id="c5", text="なぜ、日本にだけ、これほど地震が集まるのか。", style="question"),
        dict(id="c6", text="答えは、足もとの、地面の下にあります。"),
        dict(id="c7", text="世界の震源の記録と、国の資料で、確かめていきます。"),
        dict(id="c8", text="まず、この数字を、自分で数え直してみました。", section=True, scene=S_BOX),
        dict(id="c9", text="使うのは、アメリカ地質調査所が公開している、世界の地震の記録です。"),
        dict(id="c10", text="2014年から2023年の10年。マグニチュード6以上は、世界で1389回。"),
        dict(id="c11", text="そのうち、日本の近くで起きたのは、87回。約6%でした。"),
        dict(id="c12", text="白書の2割より少ないのは、数えた範囲と、年が違うからです。"),
        dict(id="c13", text="白書の期間には、2011年が入っています。", scene=S_2011),
        dict(id="c14", text="2011年だけで、日本の近くの大きな地震は、84回。その年の世界の、4割でした。"),
        dict(id="c15", text="それでも6%は、陸地の割合の、約25倍。日本は、やはり地震の多い国です。"),
        dict(id="c16", text="では、ほかに地震が多いのは、どこでしょう。", section=True, scene=S_RING),
        dict(id="c17", text="同じ10年を、国や地域ごとに数えると、1位はインドネシア。119回です。"),
        dict(id="c18", text="2位はパプアニューギニア、3位はチリ。日本は60回で、6位でした。"),
        dict(id="c19", text="地図に置くと、上位のほとんどが、太平洋をぐるりと囲んでいます。", scene=S_RING2),
        dict(id="c20", text="日本は、この輪の、北西の角にあるのです。この輪が何なのかは、次の章で分かります。"),
        dict(id="c21", text="揺れを感じる地震は、もっと身近です。", section=True, scene=S_FELT),
        dict(id="c22", text="震度1以上の地震は、ふだんの年で、およそ2000回。"),
        dict(id="c23", text="1日に5回ほど、日本のどこかが、揺れている計算です。"),
        dict(id="c24", text="年ごとに並べると、2016年は、6587回。熊本地震の年です。"),
        dict(id="c25", text="去年、2025年は、4456回。1日に12回でした。"),
        dict(id="c26", text="普通の国なら、地震は、めったに起きない出来事です。", scene=S_END),
        dict(id="c27", text="ところが日本では、毎日の出来事なのです。"),
        dict(id="c28", text="では、その地震は、どこで生まれているのか。地面の下を、のぞいてみます。"),
    ],
)


def sfx_events(L):
    return mapscene.sfx(EP["lines"], L)
