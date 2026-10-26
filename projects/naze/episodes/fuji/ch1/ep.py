"""本編 第1章「測ると、左右対称ではなかった」。出典は ../research.md。"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common import *  # noqa: E402,F403

C_WIDE = cam("top", 18.0, 7.8, 0, -0.8)
C_PANEL = cam("e3", 18.0, 7.2, 0, -0.8)          # 右に図が出るので富士山を左へ
EP = dict(BASE, aspect="landscape", cta=False, title="第1章 測ると、左右対称ではなかった",
    lines=[
        dict(id="c1", text="富士山の高さは、3776m。", labels=[dict(point="top", text="富士山 3776m", color=O.YEL, at=0.1)]),
        dict(id="c2", text="2番目に高い北岳より、583mも高い、日本一の山です。"),
        dict(id="c3", text="遠くから見ると、左右がそろった、きれいな三角形。"),
        dict(id="c4", text="では、本当に、左右対称なのでしょうか。", style="question", sub="富士山は本当に\n【左右対称】なのか？"),
        dict(id="c5", text="国土地理院の標高データで、立体にして、測ってみました。", section=True),
        dict(id="c6", text="まず、山頂から、東西南北の4つの方向に、斜面を切ってみます。", profile=PROF_WE),
        dict(id="c7", text="普通は、どの方向から見ても、同じ形だと思いがちです。", profile=PROF_WE),
        dict(id="c8", text="ところが、山頂の近くの傾きは、北が27度。東が22度。南が30度。", profile=PROF_SN),
        dict(id="c9", text="そして西は、38度。いちばん急な西と、いちばんゆるい東では、16度も違いました。", profile=PROF_WE,
             panel=None),
        dict(id="c10", text="裾野の広がり方も違います。", labels=[dict(point="w12", text="西", color=O.WHITE, at=0.1), dict(point="n12", text="北", color=O.WHITE, at=0.3)]),
        dict(id="c11", text="山頂から、標高1000mの所まで下りる距離は、西が約8km。北は約12km。"),
        dict(id="c12", text="富士山は、北と東に、なだらかに広がった山なのです。"),
        dict(id="c13", text="それでも、遠くから見ると、きれいに見える。なぜでしょう。", section=True),
        dict(id="c14", text="断面の形を、もう一度見てください。", profile=PROF_SN),
        dict(id="c15", text="山頂の近くは、30度ほどの急な坂。", profile=PROF_SN),
        dict(id="c16", text="中腹で20度台になり、裾野では、10度ほどまで、ゆるやかになります。", profile=PROF_SN),
        dict(id="c17", text="上が急で、下へ行くほど、なだらかに広がる。"),
        dict(id="c18", text="反りかえった、この線が、富士山らしさの正体です。"),
        dict(id="c19", text="どの方向から見ても、この反りかえった線は同じ。だから、少しの違いがあっても、きれいな三角に見えるのです。"),
        dict(id="c20", text="ただし、1か所だけ、この線が乱れる方向があります。", section=True),
        dict(id="c21", text="南東です。山頂から2.5kmほど下った、標高2500mあたりで、線が一度くぼみ、また盛り上がっています。", profile=PROF_SE,
             say="なんとうです。さんちょうから、にてんごキロほど、くだった、ひょうこう、にせんごひゃくメートルあたりで、せんが、いちど、くぼみ、また、もりあがっています。"),
        dict(id="c22", text="この、くぼみが何なのか。その答えは、第4章で分かります。", profile=PROF_SE),
        dict(id="c23", text="では、この形は、どうやってできたのか。次の章では、富士山の中身を見ていきます。"),
    ],
    shots=[
        dict(line="c1", a=cam("top", 20.4, 9.6, -10, -0.8), b=cam("top", 18.0, 7.2, 0, -0.8)),
        dict(line="c3", a=cam("top", 18.0, 5.4, 15, -0.8), b=cam("top", 18.0, 5.4, -15, -0.8)),
        dict(line="c5", a=cam("top", 19.2, 13.2, 0, -2.4), b=C_WIDE),
        dict(line="c6", a=C_PANEL, b=cam("e3", 16.8, 6.6, 10, -0.8)),
        dict(line="c8", a=cam("e3", 16.8, 6.6, 10, -0.8), b=cam("e3", 16.8, 6.6, -10, -0.8)),
        dict(line="c10", a=cam("top", 21.6, 18.0, 0, -2.4), b=cam("top", 20.4, 16.8, 20, -2.4)),
        dict(line="c13", a=cam("top", 18.0, 4.8, 90, -0.8), b=cam("top", 18.0, 4.8, 60, -0.8)),
        dict(line="c14", a=C_PANEL, b=cam("e3", 16.8, 6.6, 8, -0.8)),
        dict(line="c17", a=cam("top", 15.6, 3.6, -60, -0.3), b=cam("top", 15.6, 3.6, -100, -0.3)),
        dict(line="c20", a=cam("hoei", 7.2, 3.6, 135, 0.5), b=cam("hoei", 6.0, 3.0, 150, 0.5)),
        dict(line="c23", a=cam("top", 18.0, 7.2, 0, -0.8), b=cam("top", 20.4, 9.0, 0, -0.8)),
    ],
)
EP["lines"][8].pop("panel")
