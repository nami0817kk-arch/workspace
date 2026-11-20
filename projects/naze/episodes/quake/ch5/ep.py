"""本編 第5章「なぜ、予知できないのか」。出典は ../research.md。最後の章なので、登録と高評価のお願いが入る。"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common import *  # noqa: E402,F403
from naze import mapscene  # noqa: E402
from naze.mapscene import draw  # noqa: E402,F401

S_Q1 = dict(view=JAPAN_PANEL_V, layers=[Q(id="qall")], panel=dict(kind="quote", text=JMA_QUOTE, src=JMA_SRC, at=0.4))
S_Q2 = dict(view=JAPAN_PANEL_V, layers=[Q(id="qall")],
            panel=dict(kind="quote", text="「日時と場所を特定した地震を\n予知する情報は\nデマと考えられます」", src=JMA_SRC, at=0.1))
S_RULER = dict(view=JAPAN_PANEL_V, layers=[PLATES], panel=dict(kind="image", path=str(ASSETS / "ruler_gemini.jpg"), at=0.2))
S_SUB = dict(view=JAPAN_PANEL_V, layers=[PLATES], panel=dict(kind="image", path=str(ASSETS / "subduction_gemini.jpg"), at=0.0))
NANKAI = [dict(kind="label", id="nk", at_ll=(135.6, 32.4), text="南海トラフ", color=O.YEL, size=50, at=0.3)]
NV = (136, 33.5, 16)
NVP = (139.5, 33.5, 20)
S_NANKAI = dict(view=NV, layers=[PLATES_FILL, PLATES] + NANKAI)
S_P1 = dict(view=NVP, layers=[PLATES_FILL, PLATES] + NANKAI, panel=dict(kind="big", text="60〜90%程度以上", sub="今後30年以内（地震本部・2025年9月）", size=104, at=0.3))
S_P2 = dict(view=NVP, layers=[PLATES_FILL, PLATES] + NANKAI, panel=dict(kind="big", text="20〜50%", sub="別の計算。どちらも最も高いランク", size=130, at=0.2))
S_INFO = dict(view=NV, layers=[PLATES_FILL, PLATES] + NANKAI + [
    dict(kind="label", id="hy", at_ll=(132.4, 31.6), text="日向灘", color=O.WHITE, size=44, at=0.2)])
S_INFO2 = dict(view=NVP, layers=S_INFO["layers"], panel=dict(kind="big", text="2024年8月8日", sub="はじめて出た「巨大地震注意」", size=100, at=0.2))
S_WORLD = dict(view=WORLD_V, layers=[dict(kind="label", id="jp", at_ll=(138, 37), text="日本", size=56, color=O.YEL)])
S_JP = dict(view=JAPAN_V, layers=[PLATES_FILL, PLATES, dict(kind="arrow", id="arPA", a=(152, 37), b=(147, 38), color=M.PLATE_COL["PA"]),
                                  dict(kind="arrow", id="arPS", a=(139, 27.5), b=(137, 30.5), color=M.PLATE_COL["PS"])] + plate_labels())
S_END = dict(view=JAPAN_V, layers=[Q(id="qall", grow=0.8)])

EP = dict(
    kind="sim", aspect="landscape", title="第5章 なぜ、予知できないのか", credit=CREDIT,
    lines=[
        dict(id="c1", text="これほど調べているなら、いつ来るかも、分かりそうなものです。", scene=S_Q1),
        dict(id="c2", text="ところが、気象庁は、こう説明しています。"),
        dict(id="c3", text="日時と場所と大きさを特定した、確度の高い予測は、難しい。"),
        dict(id="c4", text="日時と場所を特定した予知の情報は、デマと考えられる、とも書いています。", scene=S_Q2),
        dict(id="c5", text="なぜ、難しいのか。第2章の、下じきを、思い出してください。", section=True, scene=S_RULER),
        dict(id="c6", text="曲げた下じきが、いつ戻るか。"),
        dict(id="c7", text="小さな傷や、力のかかり方で、変わります。"),
        dict(id="c8", text="地下の板も、同じです。", scene=S_SUB),
        dict(id="c9", text="ゆがみがたまっていることは、分かります。でも、いつ割れるかまでは、決まらないのです。"),
        dict(id="c10", text="その代わりに、国が出しているのが、確率です。", section=True, scene=S_NANKAI),
        dict(id="c11", text="たとえば、南海トラフの地震。"),
        dict(id="c12", text="今後30年以内に起きる確率は、60〜90%程度以上。", scene=S_P1,
             say="こんご、さんじゅうねんいないに、おきるかくりつは、ろくじゅっパーセントから、きゅうじゅっパーセント、ていどいじょう。"),
        dict(id="c13", text="別の計算では、20〜50%。どちらも、いちばん高いランクです。", scene=S_P2,
             say="べつのけいさんでは、にじゅっパーセントから、ごじゅっパーセント。どちらも、いちばん、たかいランクです。"),
        dict(id="c14", text="2つの数字が並ぶのは、計算のしかたが、違うからです。"),
        dict(id="c15", text="どちらにしても、日付は言えない。でも、起きる場所と、起きやすさは、分かっている。", scene=S_NANKAI),
        dict(id="c16", text="もうひとつ、国が出す情報があります。", section=True, scene=S_INFO),
        dict(id="c17", text="南海トラフの近くで、大きな地震が起きたとき。次の巨大地震に、注意を呼びかける情報です。"),
        dict(id="c18", text="2024年8月8日。日向灘の地震のあと、この情報が、はじめて出されました。", scene=S_INFO2),
        dict(id="c19", text="呼びかけは、1週間で終わりました。巨大地震は、起きていません。"),
        dict(id="c20", text="予知ではなく、いつもより起きやすい、という知らせ。それが、今の科学に言える、精一杯なのです。", scene=S_NANKAI),
        dict(id="c21", text="だから、ふだんから備えることに、意味があるのです。"),
        dict(id="c22", text="日本の陸地は、世界の0.25%。", section=True, scene=S_WORLD),
        dict(id="c23", text="そこに4枚の板が集まり、年に8cmずつ、押し合っています。", scene=S_JP),
        dict(id="c24", text="地震の多さは、偶然ではなく、日本の足もとの、仕組みそのものでした。", style="end", sub="地震の多さは、偶然ではなく\n【足もとの仕組み】そのものでした。", scene=S_END),
        dict(id="c25", text="次に小さな揺れを感じたら、足もとの、何十km下を思い出してください。そこでは今日も、板が少しずつ動いています。"),
    ],
)


def sfx_events(L):
    return mapscene.sfx(EP["lines"], L)
