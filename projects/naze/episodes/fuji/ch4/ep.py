"""本編 第4章「山頂ではない所から、噴火した」。出典は ../research.md。"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common import *  # noqa: E402,F403

LAKES = [dict(point="saiko", text="西湖", color=O.BLUE, at=0.2), dict(point="shoji", text="精進湖", color=O.BLUE, at=0.4)]
EP = dict(BASE, aspect="landscape", cta=False, title="第4章 山頂ではない所から、噴火した",
    lines=[
        dict(id="c1", text="864年、平安時代。富士山の北西の麓で、大きな噴火が起きました。貞観噴火です。",
             say="はっぴゃくろくじゅうよねん、へいあんじだい。ふじさんの、ほくせいの、ふもとで、おおきな、ふんかが、おきました。じょうがん、ふんかです。"),
        dict(id="c2", text="長尾山を中心とする、長さ約3kmにわたる、いくつもの火口から、溶岩が流れ出しました。",
             labels=[dict(point="nagao", text="長尾山", color=O.RED, at=0.1)], say="ながおやまを、ちゅうしんとする、ながさ、やく、さんキロメートルにわたる、いくつもの、かこうから、ようがんが、ながれだしました。"),
        dict(id="c3", text="その量は、内閣府の報告書で、約1.4立方km。", panel=dict(kind="big", text="約1.4km³", sub="貞観噴火の溶岩（内閣府）", at=0.2),
             say="そのりょうは、ないかくふの、ほうこくしょで、やく、いってんよん、りっぽうキロメートル。"),
        dict(id="c4", text="流れた溶岩が固まった上に、今の青木ヶ原の森が、広がっています。", labels=[dict(point="aokigahara", text="青木ヶ原", color=O.GREEN, at=0.2)]),
        dict(id="c5", text="この溶岩は、当時あった大きな湖を、埋めてしまいました。"),
        dict(id="c6", text="そうして分かれて残ったのが、今の西湖と、精進湖です。", labels=LAKES),
        dict(id="c7", text="富士五湖の形にも、噴火が刻まれているのです。", labels=LAKES + [dict(point="kawaguchi", text="河口湖", color=O.BLUE, at=0.2), dict(point="motosu", text="本栖湖", color=O.BLUE, at=0.3)]),
        dict(id="c8", text="そして、1707年。富士山の、最後の噴火が起きます。宝永噴火です。", section=True,
             say="そして、せんななひゃくななねん。ふじさんの、さいごの、ふんかが、おきます。ほうえい、ふんかです。"),
        dict(id="c9", text="噴火したのは、山頂ではなく、南東の斜面。標高3000m付近でした。", labels=[dict(point="hoei", text="宝永火口", color=O.RED, at=0.3)]),
        dict(id="c10", text="噴火は、16日間、続きました。", panel=dict(kind="big", text="16日間", sub="宝永噴火（1707年）", at=0.1)),
        dict(id="c11", text="噴き出したものは、マグマに換算して、約0.7立方km。", panel=dict(kind="big", text="約0.7km³", sub="マグマに換算した噴出量（気象庁）", at=0.1),
             say="ふきだしたものは、マグマに、かんさんして、やく、れいてんなな、りっぽうキロメートル。"),
        dict(id="c12", text="火山灰は、その日のうちに、江戸にも降りました。今の川崎では、厚さ5cm積もった、と記録されています。",
             panel=dict(kind="image", path=str(ASSETS / "ash_hoei.png"), at=0.1)),
        dict(id="c13", text="灰は、房総半島まで、届きました。", panel=dict(kind="image", path=str(ASSETS / "ash_hoei.png"), at=0.0)),
        dict(id="c14", text="この噴火の跡は、今も、はっきり見えます。"),
        dict(id="c15", text="南東の斜面に、ぽっかりと開いた、大きなくぼみ。宝永火口です。", labels=[dict(point="hoei", text="宝永火口", color=O.RED, at=0.1)]),
        dict(id="c16", text="第1章で見た、南東の断面を、思い出してください。標高2500mあたりで、線が一度くぼんでいたのは、この火口だったのです。", profile=PROF_SE),
        dict(id="c17", text="宝永噴火から、今年で319年。富士山は、それから噴火していません。"),
        dict(id="c18", text="でも、富士山は、今も活火山です。気象庁の噴火警戒レベルは、1。活火山であることに留意、とされています。",
             panel=dict(kind="big", text="レベル1", sub="活火山であることに留意（気象庁）", at=0.3)),
        dict(id="c19", text="噴火していない今も、富士山は、生きている山なのです。"),
    ],
    shots=[
        dict(line="c1", a=cam("nagao", 22, 10, -45, 0.5), b=cam("nagao", 18, 8, -30, 0.5)),
        dict(line="c3", a=cam("nagao", 18, 8, -30, 0.5), b=cam("nagao", 17, 8, -20, 0.5)),
        dict(line="c4", a=cam("aokigahara", 12, 6, -20, 0.0), b=cam("aokigahara", 10, 5, 0, 0.0)),
        dict(line="c6", a=cam("saiko", 14, 7, 160, 0.0), b=cam("saiko", 13, 7, 190, 0.0)),
        dict(line="c8", a=cam("top", 18, 7, 135, -0.8), b=cam("hoei", 12, 5, 135, 0.5)),
        dict(line="c10", a=cam("hoei", 12, 5, 120, 0.5), b=cam("hoei", 11, 5, 110, 0.5)),
        dict(line="c12", a=cam("top", 20, 8, 135, -1.3), b=cam("top", 20, 8, 120, -1.3)),
        dict(line="c14", a=cam("hoei", 8, 3, 140, 0.3), b=cam("hoei", 6, 2.4, 160, 0.3)),
        dict(line="c16", a=cam("hoei", 12, 5, 135, 0.5), b=cam("hoei", 11, 5, 150, 0.5)),
        dict(line="c17", a=cam("top", 18, 7, 0, -0.8), b=cam("top", 18, 7, 30, -0.8)),
        dict(line="c18", a=cam("e3", 20, 8, 0, -1.3), b=cam("e3", 19, 8, 10, -1.3)),
    ],
)
