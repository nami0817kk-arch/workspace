"""ショート 5 本の台本(縦)。s1〜s5 の ep.py がここから読む。出典は research.md。"""
from common import *  # noqa: F403

PS_WE = dict(PROF_WE)
PS_SE = dict(PROF_SE)
C0 = cam("top", 12, 4, 0, -0.6)

S = {
    "s1": dict(title="富士山は左右対称ではなかった",
        lines=[
            dict(id="c1", text="富士山は、左右がそろった、きれいな三角形。そう思っていませんか。"),
            dict(id="c2", text="国土地理院の標高データで、斜面の傾きを、測ってみました。"),
            dict(id="c3", text="山頂の近くの傾きは、東が22度。北が27度。南が30度。", profile=PS_WE),
            dict(id="c4", text="そして西は、38度。東と西で、16度も違いました。", profile=PS_WE),
            dict(id="c5", text="なぜ、それでも、きれいに見えるのか。", style="question", sub="それでも\nなぜ【きれい】に\n見えるのか"),
            dict(id="c6", text="答えは、反りかえった線。山頂の近くは30度ほどの急な坂。"),
            dict(id="c7", text="下へ行くほど、ゆるやかになり、裾野では、10度ほどです。"),
            dict(id="c8", text="この線が、どの方向にもあるので、少しの違いがあっても、きれいな三角に見えるのです。"),
            dict(id="c9", text="次に富士山を見たら、右と左の斜面を、比べてみてください。"),
        ],
        shots=[dict(line="c1", a=cam("top", 13, 5, -20, -0.6), b=cam("top", 12, 4, 20, -0.6)),
               dict(line="c3", a=cam("top", 14, 6, 0, 0.2), b=cam("top", 13, 6, 10, 0.2)),
               dict(line="c5", a=cam("top", 12, 3, 90, -0.4), b=cam("top", 12, 3, 60, -0.4)),
               dict(line="c8", a=cam("top", 13, 4, -60, -0.6), b=cam("top", 13, 4, -100, -0.6))]),
    "s2": dict(title="富士山の中には古い火山が隠れていた",
        lines=[
            dict(id="c1", text="今の富士山ができたのは、約1万1000年前から後。意外と新しい山です。", say="いまの、ふじさんが、できたのは、やく、いちまんいっせんねんまえから、あと。いがいと、あたらしい、やまです。"),
            dict(id="c2", text="では、それより前は、何があったのか。", style="question", sub="それより前は\n【何が】あったのか"),
            dict(id="c3", text="答えは、富士山の中。もっと古い火山が、隠れています。"),
            dict(id="c4", text="いちばん古いのは、先小御岳。数十万年前の火山です。", panel=dict(STEPS, items=STEPS["items"][:1], at=0.0, grow=0.5),
                 say="いちばん、ふるいのは、せんこみたけ。すうじゅうまんねんまえの、かざんです。"),
            dict(id="c5", text="次が小御岳。約10万年前までに、活動を終えました。", panel=dict(STEPS, items=STEPS["items"][:2], at=0.0, grow=0.5),
                 say="つぎが、こみたけ。やく、じゅうまんねんまえまでに、かつどうを、おえました。"),
            dict(id="c6", text="その南で、約10万年前に噴火を始めたのが、古富士。", panel=dict(STEPS, items=STEPS["items"][:3], at=0.0, grow=0.5),
                 say="その、みなみで、やく、じゅうまんねんまえに、ふんかを、はじめたのが、こふじ。"),
            dict(id="c7", text="今の富士山は、この古い山たちの上に、かぶさってできています。", panel=dict(STEPS, at=0.0, grow=0.5)),
            dict(id="c8", text="見えている富士山の奥に、見えない古い富士山が、いくつも眠っているのです。"),
            dict(id="c9", text="次に富士山の写真を見たら、その中に眠る、3つの古い山を思い出してください。"),
        ],
        shots=[dict(line="c1", a=cam("top", 12, 4, 0, -0.6), b=cam("top", 11, 4, 30, -0.6)),
               dict(line="c4", a=cam("top", 16, 5, 0, 0.7), b=cam("top", 15, 5, -10, 0.7)),
               dict(line="c8", a=cam("top", 12, 3, 180, -0.6), b=cam("top", 12, 3, 210, -0.6))]),
    "s3": dict(title="富士山の体積は1辺7.4kmのサイコロと同じ",
        lines=[
            dict(id="c1", text="富士山の体積は、約400立方km。気象庁の資料の数字です。", panel=dict(kind="big", text="約400km³", sub="富士山の体積（気象庁）", at=0.2),
                 say="ふじさんの、たいせきは、やく、よんひゃく、りっぽうキロメートル。きしょうちょうの、しりょうの、すうじです。"),
            dict(id="c2", text="1辺が、約7.4kmのサイコロと、同じ大きさです。", panel=dict(kind="big", text="1辺7.4km", sub="のサイコロと同じ体積", at=0.0)),
            dict(id="c3", text="裾野の広さは、直径およそ50km。"),
            dict(id="c4", text="これだけの量が、どうやって積み上がったのか。", style="question", sub="これだけの量が\nどうやって\n【積み上がった】のか",
                 say="これだけの、りょうが、どうやって、つみあがったのか。"),
            dict(id="c5", text="答えは、噴火の積み重ね。富士山は、成層火山と呼ばれる火山です。"),
            dict(id="c6", text="噴火のたびに、溶岩や火山灰が出て、それが層になって重なってきました。"),
            dict(id="c7", text="一度の噴火ではなく、何度も、何度も。"),
            dict(id="c8", text="最近の8000年ほどは、中くらいから小さな噴火を、繰り返してきました。"),
            dict(id="c9", text="次に富士山を見たら、その中に重なる、何千年分の層を思い出してください。"),
        ],
        shots=[dict(line="c1", a=cam("top", 16, 6, 0, 0.2), b=cam("top", 15, 6, 10, 0.2)),
               dict(line="c3", a=cam("top", 24, 22, 0, -2.4), b=cam("top", 24, 22, 30, -2.4)),
               dict(line="c4", a=cam("top", 12, 3, 60, -0.4), b=cam("top", 12, 3, 90, -0.4)),
               dict(line="c7", a=cam("top", 10, 3, 200, -0.2), b=cam("top", 10, 3, 230, -0.2))]),
    "s4": dict(title="富士山の最後の噴火は山頂ではなかった",
        lines=[
            dict(id="c1", text="1707年。富士山が、最後に噴火した年です。", say="せんななひゃくななねん。ふじさんが、さいごに、ふんかした、としです。"),
            dict(id="c2", text="噴火したのは、山頂ではありません。南東の斜面、標高3000m付近でした。", labels=[dict(point="hoei", text="宝永火口", color=O.RED, at=0.4)]),
            dict(id="c3", text="噴火は、16日間、続きました。", panel=dict(kind="big", text="16日間", sub="宝永噴火", at=0.1)),
            dict(id="c4", text="火山灰は、その日のうちに、江戸にも降りました。", panel=dict(kind="image", path=str(ASSETS / "ash_hoei.png"), at=0.1)),
            dict(id="c5", text="今の川崎では、厚さ5cm。灰は、房総半島まで、届きました。", panel=dict(kind="image", path=str(ASSETS / "ash_hoei.png"), at=0.0)),
            dict(id="c6", text="その跡は、今も見えます。"),
            dict(id="c7", text="南東の斜面に、ぽっかり開いた、大きなくぼみ。宝永火口です。", labels=[dict(point="hoei", text="宝永火口", color=O.RED, at=0.2)]),
            dict(id="c8", text="標高データで南東の斜面を切ると、標高2500mあたりで、線が一度くぼんでいます。", profile=PS_SE),
            dict(id="c9", text="あれから319年。富士山は、今も活火山です。"),
            dict(id="c10", text="次に富士山を見たら、南東の斜面の、小さなこぶを探してみてください。その下が、宝永火口です。"),
        ],
        shots=[dict(line="c1", a=cam("top", 13, 5, 135, -0.8), b=cam("hoei", 8, 3, 135, 0.5)),
               dict(line="c4", a=cam("top", 14, 5, 120, -0.8), b=cam("top", 14, 5, 110, -0.8)),
               dict(line="c6", a=cam("hoei", 6, 2.4, 140, 0.3), b=cam("hoei", 5, 2, 160, 0.3)),
               dict(line="c8", a=cam("hoei", 9, 4, 135, 1.5), b=cam("hoei", 8, 4, 150, 1.5)),
               dict(line="c9", a=cam("top", 12, 4, 0, -0.6), b=cam("top", 13, 5, 20, -0.6))]),
    "s5": dict(title="富士山の頂上は8月でも6.4度",
        lines=[
            dict(id="c1", text="富士山の頂上は、いちばん暑い8月でも、平均6.4度。", panel=dict(kind="big", text="8月 6.4℃", sub="頂上の平均気温（気象庁）", at=0.3),
                 say="ふじさんの、ちょうじょうは、いちばん、あつい、ハチガツでも、へいきん、ロクテンヨンド。"),
            dict(id="c2", text="1年の平均は、マイナス5.9度です。気象庁が測った、30年の平均です。", panel=dict(kind="big", text="−5.9℃", sub="1年の平均（1991〜2020年）", at=0.0),
                 say="いちねんの、へいきんは、マイナス、ゴテンキュウドです。きしょうちょうが、はかった、さんじゅうねんの、へいきんです。"),
            dict(id="c3", text="太陽に近いのに、なぜ寒いのか。", style="question", sub="太陽に近いのに\nなぜ【寒い】のか"),
            dict(id="c4", text="答えは、空気。高い所の空気は、薄くて、冷たいのです。"),
            dict(id="c5", text="空気は、上へ上がると、ふくらみます。ふくらむとき、自分の熱を使って、冷えていきます。"),
            dict(id="c6", text="日本の空の平均では、100m高くなるごとに、約0.5度、気温が下がります。", panel=dict(kind="big", text="100mで約0.5℃", sub="日本の空の平均（気象庁）", size=96, at=0.2),
                 say="にほんの、そらの、へいきんでは、ひゃくメートル、たかくなるごとに、やく、レイテンゴド、きおんが、さがります。"),
            dict(id="c7", text="富士山の高さで計算すると、麓より、約19度低い。", panel=dict(kind="big", text="約19℃低い", sub="3776m × 0.5℃/100m", at=0.1)),
            dict(id="c8", text="夏の麓が30度でも、頂上は、10度ほどです。"),
            dict(id="c9", text="次に夏の富士山を見たら、その頂上が、上着の要る寒さだと、思い出してください。"),
        ],
        shots=[dict(line="c1", a=cam("top", 10, 4, 0, 0.6), b=cam("top", 9, 4, 15, 0.6)),
               dict(line="c3", a=cam("top", 6, 2, 30, 0.8), b=cam("top", 5, 1.8, 60, 0.8)),
               dict(line="c4", a=cam("top", 14, 4, 90, -0.4), b=cam("top", 14, 4, 120, -0.4)),
               dict(line="c8", a=cam("top", 16, 5, 180, -0.8), b=cam("top", 18, 6, 160, -0.8))]),
}


def ep_for(name: str) -> dict:
    s = S[name]
    return dict(BASE, aspect="portrait", title=s["title"], lines=s["lines"], shots=s["shots"], header=HEADERS[name])


HEADERS = {"s1": "富士山は【左右対称】？", "s2": "富士山の中の【古い山】", "s3": "富士山は【どれだけ大きい】？",
           "s4": "富士山の【最後の噴火】", "s5": "富士山の頂上は【なぜ寒い】？"}
