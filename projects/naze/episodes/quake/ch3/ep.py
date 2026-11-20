"""本編 第3章「震源が描く、沈む板」。出典は ../research.md。"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common import *  # noqa: E402,F403
from naze import mapscene  # noqa: E402
from naze.mapscene import draw  # noqa: E402,F401

TRENCH = [dict(kind="label", id="jt", at_ll=(145.6, 40.2), text="日本海溝", color=O.WHITE, size=46, at=0.2),
          dict(kind="label", id="ibt", at_ll=(146.0, 32.4), text="伊豆・小笠原海溝", color=O.WHITE, size=42, at=0.2)]
S_GROW = dict(view=JAPAN_V, layers=[Q(id="qall", grow=0.95)])
S_PAC = dict(view=JAPAN_PANEL_V, layers=[Q(id="qall"), dict(kind="box", id="band", sw=(140.5, 34), ne=(146, 42), at=0.2)],
             panel=dict(kind="big", text="79%", sub="東北〜関東の帯で、太平洋側", size=170, at=0.3))
S_TRENCH = dict(view=JAPAN_V, layers=[Q(id="qall"), PLATES] + TRENCH)
S_SEC = dict(view=(141.5, 38.6, 13), layers=[Q(id="qt"), SECTION_LINE], panel=section_panel(at=0.3, grow=4.0))
SECP = S_SEC["panel"]
S_SEC2 = dict(view=(141.5, 38.6, 13), layers=[Q(id="qt"), SECTION_LINE], panel=SECP)
S_DEPTH = dict(view=JAPAN_PANEL_V, layers=[Q(id="qall")],
               panel=dict(kind="bars", items=[("30kmより\n浅い", 42), ("30〜\n100km", 41), ("100kmより\n深い", 17)], fmt="{}%", title="震源の深さ（日本の近く・M4以上・10年）", at=0.1))
DEEP = Q(id="qdeep", filter=lambda q: q[2] >= 300, size=1.8, grow=0.6)
S_DEEP = dict(view=(140, 31, 30), layers=[DEEP, dict(kind="label", id="deepest", at_ll=(140.6, 26.6), text="最深 686km", color=(190, 90, 230), size=48, at=0.4)])
S_FUJI = dict(view=(146, 31, 34), layers=S_DEEP["layers"],
              panel=dict(kind="compare", value="686km", unit="富士山10個", n=18, note="富士山（3,776m）の約180個分", at=0.15))
S_SEC3 = dict(view=(141.5, 38.6, 13), layers=[Q(id="qt"), SECTION_LINE], panel=SECP)

EP = dict(
    kind="sim", aspect="landscape", title="第3章 震源が描く、沈む板", credit=CREDIT, cta=False,
    lines=[
        dict(id="c1", text="2014年からの10年。日本の近くで起きた、マグニチュード4以上の地震は、11521回。", scene=S_GROW),
        dict(id="c2", text="その震源を、地図に、ひとつずつ置いてみます。"),
        dict(id="c3", text="普通は、地震は日本中に、まんべんなく起きると、思いがちです。"),
        dict(id="c4", text="ところが、点は、太平洋の側に、かたよっています。"),
        dict(id="c5", text="東北から関東の帯で数えると、79%が、太平洋側でした。", scene=S_PAC),
        dict(id="c6", text="点が集まる、そのさらに沖。海の板が、もぐりこみ始める場所。", scene=S_TRENCH),
        dict(id="c7", text="それが、日本海溝。海の底にある、深い溝です。", say="それが、ニホンカイコウ。うみのそこにある、ふかいみぞです。"),
        dict(id="c8", text="南の、伊豆・小笠原の沖にも、同じような溝が続いています。"),
        dict(id="c9", text="次に、地面を、縦に切ってみます。", section=True, scene=S_SEC),
        dict(id="c10", text="東北の、北緯38度のあたりを、東から西へ切った断面です。"),
        dict(id="c11", text="横は東西。縦は、震源の深さです。"),
        dict(id="c12", text="海溝の近くでは、震源は、深さ10kmから20km。"),
        dict(id="c13", text="陸の真下では、深さ50km前後。"),
        dict(id="c14", text="日本海側の下では、100km前後まで、深くなります。"),
        dict(id="c15", text="点が、斜めの線に、並んでいます。"),
        dict(id="c16", text="これが、もぐりこんでいく海の板の、形そのものです。"),
        dict(id="c17", text="深さを並べるだけで、見えない地下の板が、浮かび上がるのです。"),
        dict(id="c18", text="深さで分けると、30kmより浅い地震が、42%。", section=True, scene=S_DEPTH),
        dict(id="c19", text="30kmから100kmが、41%。100kmより深い地震も、17%ありました。"),
        dict(id="c20", text="いちばん深い震源は、686km。小笠原諸島の、西の地下です。", scene=S_DEEP),
        dict(id="c21", text="富士山を、約180個積んだ深さです。", scene=S_FUJI),
        dict(id="c22", text="板は、それほど深くまで、沈みこんでいるのです。", scene=S_DEEP),
        dict(id="c23", text="深い地震の多くは、沈んだ海の板の中で、起きています。"),
        dict(id="c24", text="ここで、ひとつ、覚えておいてください。", scene=S_SEC3),
        dict(id="c25", text="この斜めの板の、上の面。陸の板と、こすれ合う面です。"),
        dict(id="c26", text="この面で起きるのが、いちばん大きな地震です。"),
    ],
)


def sfx_events(L):
    return mapscene.sfx(EP["lines"], L)
