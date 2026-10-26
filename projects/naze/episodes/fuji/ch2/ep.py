"""本編 第2章「富士山は、何でできているのか」。出典は ../research.md。"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common import *  # noqa: E402,F403

EP = dict(BASE, aspect="landscape", cta=False, title="第2章 富士山は、何でできているのか",
    lines=[
        dict(id="c1", text="富士山は、火山です。それも、成層火山と呼ばれる種類の火山です。"),
        dict(id="c2", text="成層とは、層が重なる、という意味です。", panel=dict(kind="big", text="成層火山", sub="噴火のたびに積もった層が重なる山", at=0.1)),
        dict(id="c3", text="噴火のたびに、溶岩や、火山灰、火山礫が出て、それが積み重なってできた山なのです。",
             say="ふんかのたびに、ようがんや、かざんばい、かざんれきが、でて、それが、つみかさなって、できた、やまなのです。"),
        dict(id="c4", text="黒っぽい火山礫は、スコリアと呼ばれます。富士山の登山道で、足もとに広がる、黒い砂利です。",
             say="くろっぽい、かざんれきは、スコリアと、よばれます。ふじさんの、とざんどうで、あしもとに、ひろがる、くろい、じゃりです。"),
        dict(id="c5", text="一度の噴火で、できたわけではありません。", section=True),
        dict(id="c6", text="山梨県の説明では、何度も繰り返された噴火によって、今の形になった、とあります。"),
        dict(id="c7", text="最近の8000年ほどは、斜面に溶岩や火山灰を積もらせる、中くらいから小さな噴火を、繰り返してきました。"),
        dict(id="c8", text="少しずつ、少しずつ、上に積み重ねてきた山なのです。"),
        dict(id="c9", text="では、その山は、どれくらいの大きさなのか。", section=True),
        dict(id="c10", text="気象庁の資料では、富士山の体積は、約400立方km。", panel=dict(kind="big", text="約400km³", sub="富士山の体積（気象庁）", at=0.2),
             say="きしょうちょうの、しりょうでは、ふじさんの、たいせきは、やく、よんひゃく、りっぽうキロメートル。"),
        dict(id="c11", text="1辺が約7.4kmの、サイコロと同じ大きさです。", panel=dict(kind="big", text="1辺7.4km", sub="のサイコロと同じ体積", at=0.0)),
        dict(id="c12", text="裾野の広さは、直径およそ50km。", labels=[dict(point="w12", text="直径およそ50km", color=O.YEL, at=0.2)]),
        dict(id="c13", text="時速4kmで歩いても、端から端まで、12時間以上かかる幅です。"),
        dict(id="c14", text="これだけの量を、噴火で、積み上げてきたのです。"),
        dict(id="c15", text="気象庁や内閣府の資料では、富士山の岩は、主に玄武岩。黒っぽい、重い岩です。"),
        dict(id="c16", text="なぜ、ここで、それほど噴火が続いたのか。", section=True),
        dict(id="c17", text="富士山の足もとには、プレートの境目があります。", panel=dict(kind="image", path=str(ASSETS / "plates_fuji.png"), at=0.1)),
        dict(id="c18", text="北米プレート、ユーラシアプレート、フィリピン海プレート。3枚の境目が接する所が、ほぼ富士山の真下にあたります。",
             panel=dict(kind="image", path=str(ASSETS / "plates_fuji.png"), at=0.0),
             say="ほくべいプレート、ユーラシアプレート、フィリピンかいプレート。さんまいの、さかいめが、せっするところが、ほぼ、ふじさんの、ましたに、あたります。"),
        dict(id="c19", text="このことが、マグマが長く供給され続けてきた理由ではないか、と考えられています。", panel=dict(kind="image", path=str(ASSETS / "plates_fuji.png"), at=0.0)),
        dict(id="c20", text="では、富士山は、いつから、ここにあるのでしょうか。"),
    ],
    shots=[
        dict(line="c1", a=cam("top", 16, 6, 0, -0.8), b=cam("top", 14, 5, 25, -0.6)),
        dict(line="c2", a=cam("e3", 18, 7, 0, -0.8), b=cam("e3", 17, 7, 8, -0.8)),
        dict(line="c4", a=cam("top", 8, 3, 160, 0.2), b=cam("top", 7, 2.6, 190, 0.2)),
        dict(line="c5", a=cam("top", 18, 8, -30, -1.3), b=cam("top", 18, 8, 30, -1.3)),
        dict(line="c9", a=cam("top", 24, 14, 0, -2.3), b=cam("top", 22, 13, 0, -2.3)),
        dict(line="c10", a=cam("e3", 22, 10, 0, -1.3), b=cam("e3", 21, 10, 6, -1.3)),
        dict(line="c12", a=cam("top", 26, 20, 0, -2.4), b=cam("top", 26, 20, 30, -2.4)),
        dict(line="c14", a=cam("top", 16, 5, 200, -0.3), b=cam("top", 16, 5, 230, -0.3)),
        dict(line="c16", a=cam("top", 20, 9, 0, -1.3), b=cam("top", 20, 9, -15, -1.3)),
        dict(line="c17", a=cam("e3", 20, 8, 0, -1.3), b=cam("e3", 19, 8, -8, -1.3)),
        dict(line="c20", a=cam("top", 18, 7, 0, -0.8), b=cam("top", 20, 8, 0, -0.8)),
    ],
)
