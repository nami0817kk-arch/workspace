"""天気の子 × 東京の低い土地: 本編 5 章とショート 5 本の台本と画面。ch1〜ch5・s1〜s5 の ep.py がここから読む。出典は research.md。"""
from common import *  # noqa: F403

W0 = cam("center", 30, 16, 0, 0.0)          # 東京全体(南から)
WE = cam("east", 22, 10, 20, 0.0)           # 東の低い土地
WP = cam("east", 30, 14, 0, 0.0)            # 右に図が出るとき

P = {}

P["ch1"] = dict(title="第1章 23区の2割は、海より低い", cta=False,
    lines=[
        dict(id="c1", text="東京23区の約2割は、満潮の海面より、低い土地です。東京都の資料の数字です。"),
        dict(id="c2", text="その広さ、124平方km。そこに、約150万人が暮らしています。", panel=dict(kind="big", text="約150万人", sub="海より低い土地に暮らす人（東京都）", at=0.3),
             say="その、ひろさ、ひゃくにじゅうよん、へいほうキロメートル。そこに、やく、ひゃくごじゅうまんにんが、くらしています。"),
        dict(id="c3", text="2019年の映画、天気の子。その年の邦画で1位になった作品です。", section=True),
        dict(id="c4", text="映画の結末では、雨が降り続いて、東京の東側の低い土地が、水に沈んだ姿が描かれます。", panel=dict(kind="image", path=str(HERE / "assets" / "flood_tower_panel.jpg"), box=(960, 200, 1880, 740), at=0.0)),
        dict(id="c5", text="あの景色は、空想なのでしょうか。", style="question", sub="水に沈んだ東京は\n【空想】なのか？"),
        dict(id="c6", text="答えは、半分は本当です。東京には、もともと沈みやすい土地が、広がっているのです。"),
        dict(id="c7", text="この動画では、国土地理院の標高データで、東京に水を上げて、確かめていきます。"),
        dict(id="c8", text="まず、東京の高さを、立体にしてみます。", section=True),
        dict(id="c9", text="西は高く、東は低い。"),
        dict(id="c10", text="新宿駅のあたりは、標高38m。代々木は35m。", labels=[L("shinjuku", "新宿 38m", O.YEL, 0.1), L("yoyogi", "代々木 35m", O.YEL, 0.5, True)]),
        dict(id="c11", text="ところが、東へ行くと、東京駅は3.4m。お台場は2.3m。", labels=[L("tokyo", "東京駅 3.4m", O.WHITE, 0.1), L("odaiba", "お台場 2.3m", O.WHITE, 0.5)]),
        dict(id="c12", text="そして、江東区役所のあたりは、マイナス0.2m。亀戸は、マイナス0.7m。", labels=[L("koto", "江東区役所 −0.2m", O.BLUE, 0.1, True), L("kameido", "亀戸 −0.7m", O.BLUE, 0.5)],
             say="そして、こうとうくやくしょの、あたりは、マイナス、レイテンニメートル。かめいどは、マイナス、レイテンナナメートル。"),
        dict(id="c13", text="海の高さより、低い所に、街があるのです。"),
    ],
    shots=[dict(line="c1", a=cam("center", 34, 20, -10, 0.0), b=W0),
           dict(line="c2", a=WP, b=cam("east", 28, 13, 8, 0.0)),
           dict(line="c3", a=cam("east", 18, 6, 30, 0.0), b=cam("east", 18, 6, 0, 0.0)),
           dict(line="c8", a=cam("center", 30, 22, 0, 0.0), b=cam("center", 26, 9, -40, 0.0)),
           dict(line="c10", a=cam("west", 14, 6, -20, 0.0), b=cam("west", 13, 5, 0, 0.0)),
           dict(line="c11", a=cam("odaiba", 15, 7, 0, 0.0), b=cam("odaiba", 15, 7, 15, 0.0)),
           dict(line="c12", a=cam("koto", 10, 4, 20, 0.0), b=cam("koto", 9, 4, 40, 0.0)),
           dict(line="c13", a=WE, b=cam("east", 24, 11, 0, 0.0))])

P["ch2"] = dict(title="第2章 仮に、雨が流れなかったら", cta=False,
    water=[("c4", 0.0, -1.0), ("c4", 0.9, 0.0), ("c5", 0.45, 1.7), ("c6", 1.0, 1.7), ("c7", 0.3, 3.8), ("c8", 1.0, 3.8), ("c9", 0.3, 5.7), ("c11", 0.5, 5.7), ("c12", 0.3, 10.4), ("c16", 1.0, 10.4), ("c17", 0.8, -1.0)],
    lines=[
        dict(id="c1", text="では、仮に。映画のように、雨が降り続いたとしたら。", section=True),
        dict(id="c2", text="しかも、降った雨が、川にも海にも流れず、全部、東京の低い土地にたまり続けたら、どうなるでしょう。", style="question",
             sub="仮に、雨が\n【流れなかったら】？"),
        dict(id="c3", text="計算に使うのは、東京の、ふだんの年の雨の量です。気象庁の平年値で、1年に1598mm。", panel=dict(kind="big", text="1年に1598mm", sub="東京の雨（気象庁の平年値）", size=100, at=0.4),
             say="けいさんに、つかうのは、とうきょうの、ふだんの、としの、あめの、りょうです。きしょうちょうの、へいねんちで、いちねんに、せんごひゃくきゅうじゅうはちミリ。"),
        dict(id="c4", text="東京駅を中心とした、約33km四方の陸地に、この雨が降り続けて、低い所から水がたまっていく、と考えます。"),
        dict(id="c5", text="1か月。いちばん雨の多い10月の、平年の雨の量なら、水の高さは約1.7m。陸地の17%が沈みます。",
             say="いっかげつ。いちばん、あめの、おおい、じゅうがつの、へいねんの、あめの、りょうなら、みずの、たかさは、やく、イッテンナナメートル。りくちの、じゅうななパーセントが、しずみます。"),
        dict(id="c6", text="荒川と江戸川の、下流のあたりです。", labels=[L("katsushika", "葛飾区", O.WHITE, 0.1), L("edogawa", "江戸川区", O.WHITE, 0.3)]),
        dict(id="c7", text="半年。水の高さは、約3.8m。東京駅の3.4mを、越えました。", labels=[L("tokyo", "東京駅 3.4m", O.WHITE, 0.5)],
             say="はんとし。みずの、たかさは、やく、サンテンハチメートル。とうきょうえきの、サンテンヨンメートルを、こえました。"),
        dict(id="c8", text="お台場の2.3mは、もっと前。雨がたまり始めて、およそ3か月目に沈みます。", labels=[L("odaiba", "お台場 2.3m", O.WHITE, 0.1)],
             say="おだいばの、ニテンサンメートルは、もっと、まえ。あめが、たまりはじめて、およそ、さんかげつめに、しずみます。"),
        dict(id="c9", text="1年。水の高さは、約5.7m。陸地の、ほぼ半分が、水の下です。", section=True, say="いちねん。みずの、たかさは、やく、ゴテンナナメートル。りくちの、ほぼ、はんぶんが、みずの、したです。"),
        dict(id="c10", text="映画で描かれた、東側の低い土地が沈む景色に、近づいてきました。", panel=dict(kind="image", path=str(HERE / "assets" / "flood_cliff_panel.jpg"), box=(960, 200, 1880, 740), at=0.0)),
        dict(id="c11", text="では、仮に、2年半、降り続いたら。"),
        dict(id="c12", text="水の高さは、約10.4m。陸地の54%が沈みます。", say="みずの、たかさは、やく、ジュッテンヨンメートル。りくちの、ごじゅうよんパーセントが、しずみます。"),
        dict(id="c13", text="その高さは、ちょうど、田端の高台の、ふちのあたり。田端駅のあたりの標高は、9.9mです。", labels=[L("tabata", "田端 9.9m", O.YEL, 0.3)],
             say="その、たかさは、ちょうど、たばたの、たかだいの、ふちの、あたり。たばたえきの、あたりの、ひょうこうは、キュウテンキュウメートルです。"),
        dict(id="c14", text="映画で、主人公たちが暮らす家がある、あの高台です。", profile=PROF_TABATA),
        dict(id="c15", text="新宿の38m、代々木の35mは、それでも、まだ水の上にあります。", labels=[L("shinjuku", "新宿 38m", O.YEL, 0.1), L("yoyogi", "代々木 35m", O.YEL, 0.3, True)]),
        dict(id="c16", text="もちろん、これは仮の計算です。本当は、雨は川から海へ流れ、堤防と水門が街を守っています。"),
        dict(id="c17", text="でも、東京が、西の台地と東の低い土地に分かれ、その境目に崖が走っていることは、本当なのです。"),
    ],
    shots=[dict(line="c1", a=cam("east", 26, 12, 10, 0.0), b=cam("east", 24, 11, -10, 0.0)),
           dict(line="c3", a=WP, b=cam("east", 29, 14, 6, 0.0)),
           dict(line="c4", a=cam("center", 30, 18, 0, 0.0), b=cam("center", 28, 15, 10, 0.0)),
           dict(line="c6", a=cam("katsushika", 14, 6, 30, 0.0), b=cam("katsushika", 13, 6, 50, 0.0)),
           dict(line="c7", a=cam("tokyo", 14, 6, 0, 0.0), b=cam("tokyo", 13, 6, 15, 0.0)),
           dict(line="c8", a=cam("odaiba", 15, 7, 0, 0.0), b=cam("odaiba", 15, 7, 15, 0.0)),
           dict(line="c9", a=cam("center", 30, 16, 0, 0.0), b=cam("center", 30, 16, 20, 0.0)),
           dict(line="c11", a=cam("east", 26, 12, -20, 0.0), b=cam("center", 28, 14, 0, 0.0)),
           dict(line="c13", a=cam("tabata", 10, 4, 120, 0.0), b=cam("tabata", 9, 4, 140, 0.0)),
           dict(line="c15", a=cam("west", 14, 6, -20, 0.0), b=cam("west", 14, 6, 0, 0.0)),
           dict(line="c16", a=W0, b=cam("center", 30, 16, -15, 0.0))])

P["ch3"] = dict(title="第3章 東京は、もともと海だった", cta=False,
    lines=[
        dict(id="c1", text="なぜ、東京の東は、これほど低いのか。"),
        dict(id="c2", text="ひとつの答えは、昔は、海だったからです。"),
        dict(id="c3", text="徳川家康が江戸に入った1590年ころ。今の日比谷公園や、皇居の外苑のあたりは、日比谷入江という、浅い海でした。", section=True,
             labels=[L("hibiya", "日比谷公園", O.BLUE, 0.4)], say="とくがわ、いえやすが、えどに、はいった、せんごひゃくきゅうじゅうねんころ。いまの、ひびやこうえんや、こうきょの、がいえんの、あたりは、ひびやいりえという、あさい、うみでした。"),
        dict(id="c4", text="家康は、山を削った土で、この入江を、埋め立てていきました。東京都水道局の資料にある話です。"),
        dict(id="c5", text="今の日比谷のあたりの標高は、2.6m。かつての海は、今も、低い土地として、残っているのです。", labels=[L("hibiya", "日比谷 2.6m", O.BLUE, 0.1)]),
        dict(id="c6", text="東京駅の3.4mも、同じ低い土地の上です。", profile=PROF_KOKYO),
        dict(id="c7", text="皇居の中は、21.9m。台地の端に、城が建てられました。", profile=PROF_KOKYO, labels=[L("kokyo", "皇居 21.9m", O.YEL, 0.2)]),
        dict(id="c8", text="普通は、東京は昔から陸だったと思いがちです。ところが、街の真ん中は、人が海を埋めて作った土地なのです。"),
        dict(id="c9", text="では、東側の土地は、埋め立てだけで、低くなったのでしょうか。"),
    ],
    shots=[dict(line="c1", a=WE, b=cam("east", 20, 9, 30, 0.0)),
           dict(line="c3", a=cam("hibiya", 10, 4, 0, 0.0), b=cam("hibiya", 8, 3.5, 15, 0.0)),
           dict(line="c6", a=cam("kokyo", 9, 4, -10, 0.0), b=cam("kokyo", 8, 3.5, 10, 0.0)),
           dict(line="c8", a=cam("center", 20, 8, 0, 0.0), b=cam("center", 20, 8, 20, 0.0))])

P["ch4"] = dict(title="第4章 地面が、4.5m下がった", cta=False,
    lines=[
        dict(id="c1", text="東京の東の土地が低いのには、もうひとつ、理由があります。"),
        dict(id="c2", text="地面そのものが、沈んだのです。", section=True),
        dict(id="c3", text="東京都の調査では、江東区南砂の観測点は、1918年からの累計で、約4.5m沈みました。", labels=[L("minamisuna", "南砂 約4.5m沈んだ", O.RED, 0.4)],
             say="とうきょうとの、ちょうさでは、こうとうくみなみすなの、かんそくてんは、せんきゅうひゃくじゅうはちねんからの、るいけいで、やく、ヨンテンゴメートル、しずみました。"),
        dict(id="c4", text="亀戸でも、約4.3mです。", labels=[L("kameido", "亀戸 約4.3m", O.RED, 0.1)], say="かめいどでも、やく、ヨンテンサンメートルです。"),
        dict(id="c5", text="大人の背の、2倍以上も、地面が下がったことになります。", panel=dict(kind="big", text="約4.5m", sub="大人の背の2倍以上（南砂・1918年から）", at=0.1)),
        dict(id="c6", text="原因は、工場などで、地下の水を、くみ上げすぎたこと。"),
        dict(id="c7", text="地下の水が抜けると、粘土の層が縮んで、地面が沈んでいきます。"),
        dict(id="c8", text="いちばん速く沈んだのは、昭和43年。江戸川区西葛西で、1年に約24cmでした。", labels=[L("nishikasai", "西葛西 1年に約24cm", O.RED, 0.3, True)],
             say="いちばん、はやく、しずんだのは、しょうわ、よんじゅうさんねん。えどがわく、にしかさいで、いちねんに、やく、にじゅうよんセンチでした。"),
        dict(id="c9", text="今は、地下の水のくみ上げを抑えて、沈む速さは、ほぼ止まっています。"),
        dict(id="c10", text="でも、一度沈んだ地面は、元には戻りません。"),
        dict(id="c11", text="第1章の、マイナス0.7mの亀戸。その低さは、こうして生まれたのです。", labels=[L("kameido", "亀戸 −0.7m", O.BLUE, 0.2)],
             say="だいいっしょうの、マイナス、レイテンナナメートルの、かめいど。その、ひくさは、こうして、うまれたのです。"),
    ],
    shots=[dict(line="c1", a=WE, b=cam("east", 20, 9, -20, 0.0)),
           dict(line="c3", a=cam("minamisuna", 10, 4, 10, 0.0), b=cam("minamisuna", 9, 4, 30, 0.0)),
           dict(line="c5", a=WP, b=cam("east", 28, 13, 6, 0.0)),
           dict(line="c6", a=cam("east", 16, 6, 60, 0.0), b=cam("east", 16, 6, 80, 0.0)),
           dict(line="c8", a=cam("nishikasai", 10, 4, 20, 0.0), b=cam("nishikasai", 9, 4, 40, 0.0)),
           dict(line="c9", a=cam("east", 20, 9, 0, 0.0), b=cam("east", 20, 9, 20, 0.0)),
           dict(line="c11", a=cam("kameido", 9, 3.5, 0, 0.0), b=cam("kameido", 8, 3.5, 20, 0.0))])

P["ch5"] = dict(title="第5章 本当に、沈むことはあるのか",
    lines=[
        dict(id="c1", text="では、東京は、本当に沈むことがあるのでしょうか。", section=True),
        dict(id="c2", text="江東区・墨田区・足立区・葛飾区・江戸川区。江東5区が、2018年に、大きな水害の想定を出しました。",
             labels=[L("koto", "江東区", O.WHITE, 0.0), L("sumida", "墨田区", O.WHITE, 0.15), L("adachi", "足立区", O.WHITE, 0.3), L("katsushika", "葛飾区", O.WHITE, 0.45, True), L("edogawa", "江戸川区", O.WHITE, 0.6, True)]),
        dict(id="c3", text="荒川や江戸川が大きくあふれたり、大きな高潮が来たりしたとき。"),
        dict(id="c4", text="最大で、約10m浸水する地域がある。", panel=dict(kind="big", text="最大 約10m", sub="浸水の深さ（江東5区の想定）", at=0.2), say="さいだいで、やく、じゅうメートル、しんすいする、ちいきが、ある。"),
        dict(id="c5", text="水が引くまでに、2週間以上かかる地域もある。", panel=dict(kind="big", text="2週間以上", sub="水が引くまで（江東5区の想定）", at=0.1)),
        dict(id="c6", text="5区に暮らす260万人のうち、250万人が、浸水する区域にいます。", panel=dict(kind="big", text="250万人", sub="5区の260万人のうち、浸水する区域に", at=0.2)),
        dict(id="c7", text="映画の雨は、空想です。でも、水に弱い土地は、本当にあるのです。", section=True, panel=dict(kind="image", path=str(HERE / "assets" / "flood_tower_panel.jpg"), box=(960, 200, 1880, 740), at=0.0)),
        dict(id="c8", text="ふだん東京が沈まないのは、堤防と水門が、川と海から、街を守っているからです。"),
        dict(id="c9", text="23区の約2割が、海より低い。その上で、私たちは暮らしています。"),
        dict(id="c10", text="映画の東京の景色は、標高データで見ると、遠い空想ではありませんでした。", style="end", sub="水に沈んだ東京は\n【遠い空想ではなかった】"),
        dict(id="c11", text="次に東京の東を歩いたら、川の堤防の高さと、街の高さを、見比べてみてください。街のほうが、低いはずです。"),
    ],
    shots=[dict(line="c1", a=cam("east", 22, 10, -20, 0.0), b=WE),
           dict(line="c2", a=cam("east", 18, 12, 0, 0.0), b=cam("east", 18, 12, 15, 0.0)),
           dict(line="c4", a=WP, b=cam("east", 28, 13, 8, 0.0)),
           dict(line="c7", a=cam("east", 14, 5, 60, 0.0), b=cam("east", 14, 5, 90, 0.0)),
           dict(line="c9", a=W0, b=cam("center", 34, 20, 0, 0.0))])

S0 = cam("center", 24, 13, 0, 0.0)
SE = cam("east", 18, 8, 20, 0.0)
P["s1"] = dict(title="東京23区の約2割は満潮の海より低かった", header="東京の【2割】は海より低い",
    lines=[
        dict(id="c1", text="東京23区の約2割は、満潮の海面より、低い土地です。"),
        dict(id="c2", text="東京都の資料では、その広さ124平方km。約150万人が暮らしています。", panel=dict(kind="big", text="約150万人", sub="海より低い土地に（東京都）", at=0.3),
             say="とうきょうとの、しりょうでは、その、ひろさ、ひゃくにじゅうよん、へいほうキロメートル。やく、ひゃくごじゅうまんにんが、くらしています。"),
        dict(id="c3", text="どこが低いのか。", style="question", sub="どこが\n【低い】のか"),
        dict(id="c4", text="答えは、東。標高データで見ると、新宿は38m、東京駅は3.4m。", labels=[L("shinjuku", "新宿 38m", O.YEL, 0.2), L("tokyo", "東京駅 3.4m", O.WHITE, 0.6)]),
        dict(id="c5", text="江東区役所のあたりは、マイナス0.2m。亀戸は、マイナス0.7mです。", labels=[L("koto", "−0.2m", O.BLUE, 0.1, True), L("kameido", "−0.7m", O.BLUE, 0.5)],
             say="こうとうくやくしょの、あたりは、マイナス、レイテンニメートル。かめいどは、マイナス、レイテンナナメートルです。"),
        dict(id="c6", text="西は高く、東は低い。東京は、斜めに傾いた街なのです。"),
        dict(id="c7", text="普段沈まないのは、堤防と水門が守っているから。"),
        dict(id="c8", text="次に東京の東を歩いたら、街が、川の水面より低いことを、思い出してください。"),
    ],
    shots=[dict(line="c1", a=S0, b=cam("center", 22, 12, 15, 0.0)),
           dict(line="c4", a=cam("center", 22, 10, -20, 0.0), b=cam("center", 22, 10, 0, 0.0)),
           dict(line="c5", a=cam("koto", 9, 4, 20, 0.0), b=cam("koto", 9, 4, 40, 0.0)),
           dict(line="c6", a=S0, b=SE)])

P["s2"] = dict(title="仮に東京の雨が流れなかったら", header="仮に雨が【流れなかったら】",
    water=[("c3", 0.0, -1.0), ("c3", 0.9, 0.0), ("c4", 0.3, 1.7), ("c4", 0.75, 3.8), ("c5", 0.3, 5.7), ("c5", 1.0, 5.7), ("c7", 0.3, 10.4), ("c8", 0.7, 10.4)],
    lines=[
        dict(id="c1", text="仮に、東京に降った雨が、川にも海にも流れなかったら。", panel=dict(kind="image", path=str(HERE / "assets" / "flood_tower_panel.jpg"), at=0.0)),
        dict(id="c2", text="東京の雨は、ふだんの年で1598mm。気象庁の平年値です。", panel=dict(kind="big", text="1年に1598mm", sub="東京の雨（気象庁）", size=96, at=0.3),
             say="とうきょうの、あめは、ふだんの、としで、せんごひゃくきゅうじゅうはちミリ。きしょうちょうの、へいねんちです。"),
        dict(id="c3", text="東京駅を中心とした約33km四方に降った雨が、全部、低い所にたまるとして計算しました。"),
        dict(id="c4", text="1か月で、水の高さ約1.7m。半年で約3.8m。東京駅が沈みます。", say="いっかげつで、みずの、たかさ、やく、イッテンナナメートル。はんとしで、やく、サンテンハチメートル。とうきょうえきが、しずみます。"),
        dict(id="c5", text="1年で、約5.7m。陸地の、ほぼ半分が水の下です。", say="いちねんで、やく、ゴテンナナメートル。りくちの、ほぼ、はんぶんが、みずの、したです。"),
        dict(id="c6", text="では、2年半なら。", style="question", sub="では\n【2年半】なら"),
        dict(id="c7", text="水の高さは約10.4m。映画、天気の子の主人公たちが暮らす、田端の高台のふちに届きます。", labels=[L("tabata", "田端 9.9m", O.YEL, 0.5)],
             say="みずの、たかさは、やく、ジュッテンヨンメートル。えいが、てんきのこの、しゅじんこうたちが、くらす、たばたの、たかだいの、ふちに、とどきます。"),
        dict(id="c8", text="もちろん仮の計算。本当は、雨は海へ流れ、堤防が街を守っています。"),
        dict(id="c9", text="次に大雨の予報を見たら、その雨がどこへ流れていくのかを、思い出してください。"),
    ],
    shots=[dict(line="c1", a=S0, b=cam("center", 22, 12, 10, 0.0)),
           dict(line="c3", a=cam("east", 22, 11, 0, 0.0), b=cam("east", 20, 10, 20, 0.0)),
           dict(line="c5", a=S0, b=cam("center", 24, 13, -15, 0.0)),
           dict(line="c7", a=cam("tabata", 9, 4, 120, 0.0), b=cam("tabata", 8, 4, 140, 0.0)),
           dict(line="c8", a=S0, b=cam("center", 26, 14, 0, 0.0))])

P["s3"] = dict(title="日比谷は海だった", header="日比谷は【海】だった",
    lines=[
        dict(id="c1", text="今の日比谷公園のあたりは、昔、海でした。", labels=[L("hibiya", "日比谷公園", O.BLUE, 0.3)]),
        dict(id="c2", text="徳川家康が江戸に入った1590年ころ。ここは、日比谷入江という浅い海でした。",
             say="とくがわ、いえやすが、えどに、はいった、せんごひゃくきゅうじゅうねんころ。ここは、ひびやいりえという、あさい、うみでした。"),
        dict(id="c3", text="家康は、山を削った土で、入江を埋め立てていきました。"),
        dict(id="c4", text="では、今はどれくらいの高さなのか。", style="question", sub="今は\n【どれくらいの高さ】？"),
        dict(id="c5", text="標高データで測ると、日比谷は2.6m。東京駅も3.4mです。", labels=[L("hibiya", "日比谷 2.6m", O.BLUE, 0.1), L("tokyo", "東京駅 3.4m", O.WHITE, 0.5, True)]),
        dict(id="c6", text="すぐ隣の皇居の中は、21.9m。台地の端に、城が建てられたのです。", profile=PROF_KOKYO),
        dict(id="c7", text="かつての海は、今も低い土地として、残っています。"),
        dict(id="c8", text="次に日比谷を歩いたら、足もとが昔の海の底だと、思い出してください。"),
    ],
    shots=[dict(line="c1", a=cam("hibiya", 9, 4, 0, 0.0), b=cam("hibiya", 8, 3.5, 20, 0.0)),
           dict(line="c4", a=cam("hibiya", 10, 5, -30, 0.0), b=cam("hibiya", 10, 5, -10, 0.0)),
           dict(line="c6", a=cam("tokyo", 9, 4, 160, 0.0), b=cam("tokyo", 9, 4, 180, 0.0))])

P["s4"] = dict(title="東京の地面は4.5m沈んでいた", header="地面が【4.5m】沈んだ",
    lines=[
        dict(id="c1", text="東京の江東区では、地面が、約4.5m沈みました。", say="とうきょうの、こうとうくでは、じめんが、やく、ヨンテンゴメートル、しずみました。"),
        dict(id="c2", text="東京都の調査で、南砂の観測点の、1918年からの累計です。", labels=[L("minamisuna", "南砂", O.RED, 0.3)],
             say="とうきょうとの、ちょうさで、みなみすなの、かんそくてんの、せんきゅうひゃくじゅうはちねんからの、るいけいです。"),
        dict(id="c3", text="大人の背の、2倍以上です。", panel=dict(kind="big", text="約4.5m", sub="大人の背の2倍以上", at=0.1)),
        dict(id="c4", text="なぜ、地面が沈んだのか。", style="question", sub="なぜ地面が\n【沈んだ】のか"),
        dict(id="c5", text="答えは、地下の水。工場などが、地下の水をくみ上げすぎたのです。"),
        dict(id="c6", text="水が抜けると、粘土の層が縮み、地面が下がっていきました。"),
        dict(id="c7", text="今は、くみ上げを抑えて、ほぼ止まっています。でも、沈んだ地面は戻りません。"),
        dict(id="c8", text="次に江東区を歩いたら、足もとが4.5m沈んだ地面だと、思い出してください。", say="つぎに、こうとうくを、あるいたら、あしもとが、ヨンテンゴメートル、しずんだ、じめんだと、おもいだしてください。"),
    ],
    shots=[dict(line="c1", a=cam("minamisuna", 10, 4, 0, 0.0), b=cam("minamisuna", 9, 4, 20, 0.0)),
           dict(line="c4", a=SE, b=cam("east", 18, 8, 40, 0.0)),
           dict(line="c7", a=cam("minamisuna", 9, 4, 60, 0.0), b=cam("minamisuna", 9, 4, 80, 0.0))])

P["s5"] = dict(title="東京の東の5区で250万人が浸水する区域に", header="東京の東、【250万人】",
    lines=[
        dict(id="c1", text="東京の東、5つの区に暮らす260万人のうち、250万人が、浸水する区域にいます。", panel=dict(kind="big", text="250万人", sub="5区の260万人のうち", at=0.3)),
        dict(id="c2", text="江東5区が、2018年に出した、大きな水害の想定です。"),
        dict(id="c3", text="荒川や江戸川が大きくあふれたり、大きな高潮が来たりしたとき。"),
        dict(id="c4", text="最大で約10m浸水する地域があり、水が引くまで2週間以上かかる地域もある。", say="さいだいで、やく、じゅうメートル、しんすいする、ちいきが、あり、みずが、ひくまで、にしゅうかんいじょう、かかる、ちいきも、ある。"),
        dict(id="c5", text="なぜ、それほど沈むのか。", style="question", sub="なぜ、それほど\n【沈む】のか"),
        dict(id="c6", text="答えは、土地の低さ。この辺りには、海の高さより低い土地が、広がっています。", labels=[L("koto", "−0.2m", O.BLUE, 0.2, True), L("kameido", "−0.7m", O.BLUE, 0.5)]),
        dict(id="c7", text="映画、天気の子の、水に沈んだ東京は空想。でも、水に弱い土地は本当にあるのです。", panel=dict(kind="image", path=str(HERE / "assets" / "flood_cliff_panel.jpg"), at=0.0)),
        dict(id="c8", text="次に大雨の予報を見たら、自分の住む場所の高さを、調べてみてください。"),
    ],
    shots=[dict(line="c1", a=SE, b=cam("east", 18, 8, 40, 0.0)),
           dict(line="c3", a=cam("east", 14, 6, 10, 0.0), b=cam("east", 14, 6, 30, 0.0)),
           dict(line="c6", a=cam("koto", 9, 4, 20, 0.0), b=cam("koto", 9, 4, 40, 0.0)),
           dict(line="c7", a=S0, b=cam("center", 26, 14, 0, 0.0))])


def ep_for(name: str) -> dict:
    p = dict(P[name])
    aspect = "portrait" if name.startswith("s") else "landscape"
    ep = dict(BASE, aspect=aspect, **{k: v for k, v in p.items()})
    return ep
