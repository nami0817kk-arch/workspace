"""本編 第4章「二つの地震」。出典は ../research.md。
2011年のずれた面の四角は、気象庁の解析(長さ約450km・幅約200km)を、震源(北緯38.10度・東経142.86度)の辺りに置いたおおよその範囲。"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common import *  # noqa: E402,F403
from naze import mapscene  # noqa: E402
from naze.mapscene import draw  # noqa: E402,F401

RUPTURE = dict(kind="box", id="rupture", sw=(141.7, 36.1), ne=(144.0, 40.15), at=0.2)
EPI = dict(kind="label", id="epi", at_ll=(142.86, 38.10), text="×", color=O.WHITE, size=64)
TWO = [dict(kind="label", id="t1", at_ll=(146.2, 37.0), text="海溝型", color=O.YEL, size=54, at=0.3),
       dict(kind="label", id="t2", at_ll=(136.5, 36.6), text="陸の活断層", color=O.OCHRE, size=54, at=0.6)]
S_TWO = dict(view=JAPAN_V, layers=[PLATES_FILL, PLATES] + TWO)
S_2011 = dict(view=(142.3, 38.2, 13), layers=[Q(id="q2011", data="world_m6_2011-2011", by_depth=False, color=O.RED, size=2.0, grow=0.5), EPI])
S_RUP = dict(view=(142.3, 38.2, 13), layers=S_2011["layers"] + [RUPTURE, dict(kind="label", id="rl", at_ll=(146.2, 38.1), text="約450km×約200km", color=O.WHITE, size=44, at=0.4)])
S_TOKYO = dict(view=(140.5, 37.2, 16), layers=[RUPTURE, dict(kind="line", id="to", a=TOKYO, b=OSAKA, at=0.2),
                                              dict(kind="label", id="tol", at_ll=(137.4, 36.0), text="東京〜大阪 約400km", color=O.YEL, size=40, at=0.5)])
S_28 = dict(view=(144.5, 38.2, 16), layers=[RUPTURE, EPI], panel=dict(kind="big", text="約28m", sub="いちばん大きくずれた所（ビルの9階ほど）", at=0.2))
S_SEC = dict(view=(141.5, 38.6, 13), layers=[RUPTURE], panel=section_panel(at=0.0, grow=0.5))
S_1000 = dict(view=(144.5, 38.2, 16), layers=[RUPTURE, EPI], panel=dict(kind="big", text="約1000倍", sub="マグニチュード9は、7のエネルギーの", at=0.2))
OSHIKA = (141.50, 38.30)
S_GNSS = dict(view=(141.6, 38.4, 5), layers=[dict(kind="label", id="osl", at_ll=(141.0, 38.62), text="観測点「牡鹿」", color=O.WHITE, size=42),
                                             dict(kind="arrow", id="osa", a=OSHIKA, b=(142.15, 38.12), color=O.YEL, at=0.3)],
              panel=dict(kind="big", text="東南東へ約5.3m", sub="沈んだのは約1.2m（国土地理院）", size=110, at=0.3, box=(1040, 160, 1880, 560)))
S_TSUNAMI = dict(view=(142.3, 38.2, 13), layers=[RUPTURE, EPI, Q(id="q2011", data="world_m6_2011-2011", by_depth=False, color=O.RED, size=2.0)])
FAULTS = [dict(kind="label", id="f95", at_ll=(134.9, 34.4), text="1995 兵庫県南部地震", color=O.OCHRE, size=40, at=0.1),
          dict(kind="label", id="f16", at_ll=(130.8, 32.6), text="2016 熊本地震", color=O.OCHRE, size=40, at=0.5)]
SHALLOW = Q(id="qs", filter=lambda q: q[2] < 20 and on_land(q[0], q[1]), by_depth=False, color=O.OCHRE, grow=0.7, size=1.6)
S_LAND = dict(view=(137, 35.5, 22), layers=[SHALLOW])
S_2000 = dict(view=(141, 35.5, 26), layers=[SHALLOW], panel=dict(kind="big", text="約2000", sub="日本の活断層（地震本部）", at=0.2))
S_FAULTS = dict(view=(135, 34.5, 14), layers=[SHALLOW] + FAULTS)
S_BOTH = dict(view=JAPAN_V, layers=[PLATES_FILL, PLATES, Q(id="qall", grow=0.6)] + TWO)

EP = dict(
    kind="sim", aspect="landscape", title="第4章 二つの地震", credit=CREDIT, cta=False,
    lines=[
        dict(id="c1", text="日本の地震は、大きく、二つに分けられます。", scene=S_TWO),
        dict(id="c2", text="ひとつは、海の板と陸の板の境目で起きる、海溝型。"),
        dict(id="c3", text="もうひとつは、陸の中の、活断層が動く地震です。"),
        dict(id="c4", text="まず、海溝型。2011年3月11日、東北地方太平洋沖地震。", section=True, scene=S_2011),
        dict(id="c5", text="マグニチュード9.0。国内の観測史上、最大の地震です。"),
        dict(id="c6", text="気象庁の解析では、ずれた面の長さは、約450km。幅は、約200km。", scene=S_RUP),
        dict(id="c7", text="東京から大阪までの直線よりも、長い範囲です。", scene=S_TOKYO),
        dict(id="c8", text="いちばん大きくずれた所では、約28m。", scene=S_28, say="いちばん、おおきくずれたところでは、やく、にじゅうはちメートル。"),
        dict(id="c9", text="ビルの9階ほどの長さが、一度に、すべったのです。"),
        dict(id="c10", text="その場所は、前の章の、あの斜めの板の、上の面でした。", scene=S_SEC),
        dict(id="c11", text="マグニチュード9は、7より2大きい。エネルギーは、約1000倍です。", scene=S_1000),
        dict(id="c12", text="陸の形も、変わりました。", section=True, scene=S_GNSS),
        dict(id="c13", text="国土地理院は、全国の観測点で、地面の動きを測っています。"),
        dict(id="c14", text="宮城県石巻市の観測点「牡鹿」は、一度に、東南東へ約5.3m動きました。", say="みやぎけん、いしのまきしの、かんそくてん、おしかは、いちどに、とうなんとうへ、やく、ごてんさんメートル、うごきました。"),
        dict(id="c15", text="そして、約1.2m、沈みました。", say="そして、やく、いってんにメートル、しずみました。"),
        dict(id="c16", text="引きずりこまれていた陸の板が、海の方へ、跳ね返ったのです。"),
        dict(id="c17", text="海の底が持ち上がり、大きな津波が、起きました。", scene=S_TSUNAMI),
        dict(id="c18", text="もうひとつが、陸の中の地震です。", section=True, scene=S_LAND),
        dict(id="c19", text="押され続けた陸の板には、内側にも、ひびが入ります。"),
        dict(id="c20", text="そのひびが、くり返しずれ動いた跡。これを、活断層と呼びます。"),
        dict(id="c21", text="日本には、約2000の活断層が、あるといわれています。", scene=S_2000),
        dict(id="c22", text="陸の地震は、海溝型より、規模の小さいものが多い。", scene=S_LAND),
        dict(id="c23", text="ところが、人の住む町の近くで起きると、大きな被害になります。"),
        dict(id="c24", text="1995年の阪神・淡路大震災。2016年の熊本地震。", scene=S_FAULTS),
        dict(id="c25", text="どちらも、陸の活断層の地震でした。"),
        dict(id="c26", text="海の境目でも、陸の中でも。どちらも、動き続ける板から、生まれているのです。", scene=S_BOTH),
    ],
)


def sfx_events(L):
    return mapscene.sfx(EP["lines"], L)
