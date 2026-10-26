"""本編 第3章「富士山の中には、古い山が眠っている」。出典は ../research.md。"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common import *  # noqa: E402,F403

S0 = dict(STEPS, at=0.1, grow=0.5)
EP = dict(BASE, aspect="landscape", cta=False, title="第3章 富士山の中には、古い山が眠っている",
    lines=[
        dict(id="c1", text="実は、今の富士山の中には、もっと古い山が、隠れています。"),
        dict(id="c2", text="内閣府の報告書によると、富士山は、何代もの火山が重なってできています。", panel=dict(STEPS, at=0.2, grow=40)),
        dict(id="c3", text="いちばん古いのは、先小御岳。数十万年前に活動していた、と考えられている火山です。", panel=dict(STEPS, items=STEPS["items"][:1], at=0.0, grow=0.5),
             say="いちばん、ふるいのは、せんこみたけ。すうじゅうまんねんまえに、かつどうしていた、と、かんがえられている、かざんです。"),
        dict(id="c4", text="次に、小御岳。約10万年前までに、活動を終えました。", panel=dict(STEPS, items=STEPS["items"][:2], at=0.0, grow=0.5),
             say="つぎに、こみたけ。やく、じゅうまんねんまえまでに、かつどうを、おえました。"),
        dict(id="c5", text="その南の斜面で、約10万年前に噴火を始めたのが、古富士です。", panel=dict(STEPS, items=STEPS["items"][:3], at=0.0, grow=0.5),
             say="その、みなみの、しゃめんで、やく、じゅうまんねんまえに、ふんかを、はじめたのが、こふじです。"),
        dict(id="c6", text="そして、約1万1000年前から後が、今の富士山。新富士と呼ばれます。", panel=dict(S0, grow=0.5),
             say="そして、やく、いちまんいっせんねんまえから、あとが、いまの、ふじさん。しんふじと、よばれます。"),
        dict(id="c7", text="つまり、私たちが見ている富士山は、古い山の上に、かぶさってできた、いちばん新しい顔なのです。", panel=dict(S0, grow=0.3)),
        dict(id="c8", text="古い山の上に、新しい山が重なる。何十万年もかけて、富士山は、背を伸ばしてきたのです。", section=True),
        dict(id="c9", text="今の富士山の下に、どれだけ古い山が残っているのか。それは、研究で少しずつ分かってきたことです。"),
        dict(id="c10", text="先小御岳は、地面の下から見つかった、隠れた火山だと、報告書は書いています。", say="せんこみたけは、じめんのしたから、みつかった、かくれた、かざんだと、ほうこくしょは、かいています。"),
        dict(id="c11", text="見えている富士山の形の奥に、見えない、古い富士山がいくつも眠っているのです。"),
        dict(id="c12", text="では、新しい富士山は、どんな噴火を繰り返してきたのか。", section=True),
        dict(id="c13", text="古富士は、山頂の火口から、多量の火山灰や火山礫を、繰り返し噴き出しました。", say="こふじは、さんちょうの、かこうから、たりょうの、かざんばいや、かざんれきを、くりかえし、ふきだしました。"),
        dict(id="c14", text="山頂から出たものは、山の周りに、積もっていきます。", labels=[dict(point="top", text="山頂の火口", color=O.YEL, at=0.1)]),
        dict(id="c15", text="何度も、何度も、同じ所から。"),
        dict(id="c16", text="これが、富士山の、すそ野の広い形を、少しずつ作っていったのです。"),
        dict(id="c17", text="ただし、富士山の噴火は、山頂だけではありません。"),
        dict(id="c18", text="次の章では、山頂ではない所から起きた、2つの大きな噴火を見ていきます。"),
    ],
    shots=[
        dict(line="c1", a=cam("top", 14, 4, 60, -0.3), b=cam("top", 13, 4, 30, -0.3)),
        dict(line="c2", a=cam("e3", 20, 8, 0, -1.3), b=cam("e3", 19, 8, -10, -1.3)),
        dict(line="c8", a=cam("top", 18, 6, 180, -0.8), b=cam("top", 18, 6, 210, -0.8)),
        dict(line="c12", a=cam("top", 8, 6, 0, 0.6), b=cam("top", 6, 5, 20, 0.6)),
        dict(line="c16", a=cam("top", 22, 10, 0, -1.8), b=cam("top", 22, 10, 40, -1.8)),
        dict(line="c17", a=cam("top", 20, 9, -40, -1.8), b=cam("top", 22, 10, -60, -1.8)),
    ],
)
