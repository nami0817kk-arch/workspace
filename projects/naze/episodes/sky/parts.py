"""空の色: 本編 5 章とショート 5 本の台本と画面。ch1〜ch5・s1〜s5 の ep.py がここから読む。出典は research.md。"""
from naze import overlay as O

CREDIT = "図はレイリー散乱の式・Kasten & Young(1989)の式から計算"

SKY = dict(kind="sky")
PRISM = dict(kind="prism")
WAVES = dict(kind="waves", note="1ナノメートル＝1mmの100万分の1")
WAVES_BR = dict(kind="waves", rows=[(450, "青"), (700, "赤")])
SCAT = dict(kind="scatter")
SCAT_EYE = dict(kind="scatter", eye=True)
F_LAW = dict(kind="formula", rows=[("散らばる強さ", 60, O.DIM), ("1 ÷（波の長さ）⁴", 110, O.YEL), ("波の長さが半分 → 16倍", 60, O.WHITE)])
F_CALC = dict(kind="formula", rows=[("青 450nm、赤 700nm", 60, O.DIM), ("（700 ÷ 450）⁴", 110, O.WHITE), ("＝ 約5.9", 120, O.YEL)])
SIX = dict(kind="scatter", panel=dict(kind="big", text="約6倍", sub="青い光は赤い光の約6倍散らばる", at=0.25))
SPEC = dict(kind="spectrum", hl_violet=True)
LAYERS = dict(kind="layers")
MOON = dict(kind="moon")
PATH_TOP = dict(kind="path", elev=(90, 90))
PATH_DOWN = dict(kind="path", elev=(90, 10))
PATH_0 = dict(kind="path", elev=(10, 0))
AM = dict(kind="airmass", pts=[(10, "約5.6倍"), (5, "約10倍"), (0, "約38倍")])
SUNSET = dict(kind="sunset")
CLOUD = dict(kind="cloud")
MARS_DAY = dict(kind="mars", time="day", note="火星の昼（想像の絵）")
MARS_SET = dict(kind="mars", time="sunset", note="火星の夕焼け（想像の絵）")

P = {}
P["ch1"] = dict(title="第1章 太陽の光は、白ではない", cta=False, lines=[
    dict(id="c1", text="晴れた日の空は、青い。でも、太陽の光そのものは、青ではありません。", scene=SKY),
    dict(id="c2", text="太陽の光には、虹のすべての色が、混ざっています。NASAの説明です。", scene=PRISM),
    dict(id="c3", text="混ざると、白っぽく見える。それが、太陽の光です。"),
    dict(id="c4", text="では、なぜ空は、青だけを見せるのか。", style="question", sub="なぜ空は\n【青だけ】を見せるのか", scene=SKY),
    dict(id="c5", text="答えは、空気。空気の粒が、青い光だけを、多く散らばらせているのです。", scene=SCAT),
    dict(id="c6", text="この動画では、光と空気を、計算で確かめていきます。"),
    dict(id="c7", text="まず、光の色の違いは、波の長さの違いです。", section=True, scene=WAVES),
    dict(id="c8", text="人の目に見える光は、およそ380ナノメートルから700ナノメートル。",
         say="ひとのめに、みえるひかりは、およそ、さんびゃくはちじゅうナノメートルから、ななひゃくナノメートル。"),
    dict(id="c9", text="ナノメートルは、1mmの100万分の1。目には見えない、小さな波です。",
         say="ナノメートルは、いちミリの、ひゃくまんぶんのいち。めには、みえない、ちいさな、なみです。"),
    dict(id="c10", text="波の短い方が、紫や青。長い方が、赤です。"),
    dict(id="c11", text="この波の長さが、空の色を決めます。", scene=WAVES_BR),
])
P["ch2"] = dict(title="第2章 青い光は、赤の約6倍、散らばる", cta=False, lines=[
    dict(id="c1", text="光が空気の粒にぶつかると、いろいろな方向へ、散らばります。", scene=SCAT),
    dict(id="c2", text="これを、散乱と呼びます。光の波よりずっと小さな粒による散乱は、レイリー散乱と呼ばれます。"),
    dict(id="c3", text="レイリー散乱には、決まりがあります。"),
    dict(id="c4", text="散らばる強さは、波の長さの、4乗に反比例する。", scene=F_LAW, say="ちらばる、つよさは、なみの、ながさの、よんじょうに、はんぴれいする。"),
    dict(id="c5", text="波の長さが半分になると、散らばる強さは、16倍です。", say="なみの、ながさが、はんぶんに、なると、ちらばる、つよさは、じゅうろくばいです。"),
    dict(id="c6", text="青い光を450ナノメートル、赤い光を700ナノメートルとして、計算してみます。", section=True, scene=F_CALC,
         say="あおい、ひかりを、よんひゃくごじゅうナノメートル、あかい、ひかりを、ななひゃくナノメートルとして、けいさんしてみます。"),
    dict(id="c7", text="700を450で割って、4回かける。答えは、約5.9。", say="ななひゃくを、よんひゃくごじゅうで、わって、よんかい、かける。こたえは、やく、ゴテンキュウ。"),
    dict(id="c8", text="青い光は、赤い光の、約6倍も、散らばるのです。", scene=SIX),
    dict(id="c9", text="空のあちこちで散らばった青い光が、四方八方から、私たちの目に届く。", scene=SCAT_EYE),
    dict(id="c10", text="だから、空のどこを見ても、青く見えるのです。", scene=SKY),
    dict(id="c11", text="普通は、空に青い何かがあると思いがちです。ところが、空気そのものに、色はありません。"),
    dict(id="c12", text="空の青は、散らばった太陽の光の色なのです。"),
])
P["ch3"] = dict(title="第3章 なぜ、紫ではないのか", cta=False, lines=[
    dict(id="c1", text="ここで、ひとつ疑問が出ます。", scene=WAVES),
    dict(id="c2", text="青より、紫の方が、波は短い。それなら、空は紫に見えるはずです。", section=True, scene=dict(kind="waves", rows=[(400, "紫"), (450, "青")], hl=400)),
    dict(id="c3", text="答えは、3つあると説明されています。"),
    dict(id="c4", text="ひとつは、太陽の光に、紫がもともと少ないこと。", scene=SPEC),
    dict(id="c5", text="もうひとつは、紫の光の一部が、空の高い所で、吸収されてしまうこと。", scene=LAYERS),
    dict(id="c6", text="そして、人の目が、紫を感じにくいこと。", scene=dict(kind="sky", panel=dict(kind="big", text="3つの理由", sub="紫は少ない・吸収・目", size=110, at=0.3))),
    dict(id="c7", text="この3つが重なって、私たちには、紫より青が、強く見えるのです。"),
    dict(id="c8", text="では、空が暗くなる場所は、あるのでしょうか。", section=True, scene=LAYERS),
    dict(id="c9", text="空気の粒が少ない、高い所です。"),
    dict(id="c10", text="空気の重さの半分は、地上から約5.5kmまでに、集まっています。99%は、約30kmまでです。",
         say="くうきの、おもさの、はんぶんは、ちじょうから、やく、ゴテンゴキロメートルまでに、あつまっています。きゅうじゅうきゅうパーセントは、やく、さんじゅっキロメートルまでです。"),
    dict(id="c11", text="高い所ほど、散らばらせる粒が減り、空は、暗くなっていきます。"),
    dict(id="c12", text="そして、空気がほとんど無い月の上では、昼でも、空は真っ黒です。", scene=MOON),
    dict(id="c13", text="青い空は、空気がある星だけの、景色なのです。", scene=SKY),
])
P["ch4"] = dict(title="第4章 夕焼けは、なぜ赤いのか", cta=False, lines=[
    dict(id="c1", text="夕方になると、空は、赤やオレンジに変わります。", scene=SUNSET),
    dict(id="c2", text="太陽の光は、同じなのに、なぜでしょう。", style="question", sub="同じ光なのに\nなぜ【赤い】のか"),
    dict(id="c3", text="答えは、光が、空気の中を通る道のりです。", section=True, scene=PATH_TOP),
    dict(id="c4", text="太陽が真上にあるとき、光は、空気の層を、まっすぐ短く通り抜けます。"),
    dict(id="c5", text="ところが、太陽が地平線に近づくと、光は、空気の層を、斜めに長く通ることになります。", scene=PATH_DOWN),
    dict(id="c6", text="その長さを、計算してみました。", scene=AM),
    dict(id="c7", text="太陽が真上のときを1とすると、高さが10度のときは、約5.6倍。5度で、約10倍。",
         say="たいようが、まうえの、ときを、いちとすると、たかさが、じゅうどの、ときは、やく、ゴテンロクばい。ごどで、やく、じゅうばい。"),
    dict(id="c8", text="そして地平線では、約38倍。", scene=PATH_0),
    dict(id="c9", text="38倍もの空気を通るうちに、散らばりやすい青い光は、途中で、ほとんど散らばってしまいます。", scene=dict(kind="scatter", blue=0.9)),
    dict(id="c10", text="最後まで残って届くのが、散らばりにくい、赤やオレンジの光。"),
    dict(id="c11", text="だから、夕焼けは、赤いのです。", section=True, scene=SUNSET),
    dict(id="c12", text="雲が、白いのはなぜか。", scene=CLOUD),
    dict(id="c13", text="雲の粒は、およそ0.01mm以上。光の波より、ずっと大きな粒です。", say="くもの、つぶは、およそ、レイテンレイイチミリ、いじょう。ひかりの、なみより、ずっと、おおきな、つぶです。"),
    dict(id="c14", text="大きな粒は、どの色の光も、ほぼ同じように散らばらせます。"),
    dict(id="c15", text="すべての色が混ざって届くので、雲は、白く見えるのです。", scene=SKY),
])
P["ch5"] = dict(title="第5章 火星の夕焼けは、青い", lines=[
    dict(id="c1", text="地球の外では、空は、どんな色なのでしょうか。", scene=MOON),
    dict(id="c2", text="火星の昼の空は、オレンジから赤っぽい色だと、NASAは説明しています。", section=True, scene=MARS_DAY),
    dict(id="c3", text="火星の空気には、細かい砂ぼこりが、たくさん舞っているからです。"),
    dict(id="c4", text="そして、火星の夕焼けは、青い。", scene=MARS_SET),
    dict(id="c5", text="2015年4月、探査車キュリオシティが、火星の夕焼けを撮影しました。太陽のまわりが、青く写っています。"),
    dict(id="c6", text="NASAは、火星の砂ぼこりの細かい粒が、青い光を通しやすいと説明しています。"),
    dict(id="c7", text="地球の夕焼けは赤く、火星の夕焼けは青い。空気の中の粒が違えば、空の色は、逆にもなるのです。", section=True, scene=SUNSET),
    dict(id="c8", text="空の青は、空気の粒と、光の波の、長さの関係で決まっていました。", scene=SCAT),
    dict(id="c9", text="青は赤の約6倍散らばり、夕方の光は、約38倍の空気を通る。", scene=PRISM),
    dict(id="c10", text="次に夕焼けを見たら、その光が、昼の38倍の空気をくぐり抜けてきたことを、思い出してください。", scene=SUNSET),
])

P["s1"] = dict(title="空気に色はない", lines=[
    dict(id="c1", text="空気には、色がありません。なのに、空は青い。", scene=SKY),
    dict(id="c2", text="答えは、太陽の光。太陽の光には、虹のすべての色が混ざっています。", scene=PRISM),
    dict(id="c3", text="その光が、空気の粒にぶつかると、散らばります。", scene=SCAT),
    dict(id="c4", text="散らばる強さは、光の波の長さの、4乗に反比例します。", scene=F_LAW, say="ちらばる、つよさは、ひかりの、なみの、ながさの、よんじょうに、はんぴれいします。"),
    dict(id="c5", text="青い光を450ナノメートル、赤い光を700ナノメートルとして計算すると、青は赤の約6倍、散らばる。", scene=SIX,
         say="あおい、ひかりを、よんひゃくごじゅうナノメートル、あかい、ひかりを、ななひゃくナノメートルとして、けいさんすると、あおは、あかの、やく、ろくばい、ちらばる。"),
    dict(id="c6", text="空のあちこちで散らばった青い光が、四方から目に届く。", scene=SCAT_EYE),
    dict(id="c7", text="だから、空のどこを見ても、青いのです。", scene=SKY),
    dict(id="c8", text="次に青空を見たら、それが、散らばった太陽の光だと、思い出してください。"),
])
P["s2"] = dict(title="なぜ紫ではないのか", lines=[
    dict(id="c1", text="空が青いのは、波の短い光ほど、よく散らばるから。", scene=SCAT),
    dict(id="c2", text="でも、青より紫の方が、波は短い。なぜ、空は紫ではないのでしょう。", style="question", sub="なぜ空は\n【紫】ではないのか",
         scene=dict(kind="waves", rows=[(400, "紫"), (450, "青")], hl=400)),
    dict(id="c3", text="答えは、3つあると説明されています。"),
    dict(id="c4", text="ひとつは、太陽の光に、紫がもともと少ないこと。", scene=SPEC),
    dict(id="c5", text="もうひとつは、紫の光の一部が、空の高い所で吸収されること。", scene=LAYERS),
    dict(id="c6", text="そして、人の目が、紫を感じにくいこと。", scene=dict(kind="sky", panel=dict(kind="big", text="3つの理由", sub="少ない・吸収・目", size=110, at=0.3))),
    dict(id="c7", text="3つが重なって、私たちには、青が強く見えるのです。"),
    dict(id="c8", text="次に青空を見たら、その中に隠れている紫を、思い出してください。", scene=SKY),
])
P["s3"] = dict(title="夕焼けは38倍の空気", lines=[
    dict(id="c1", text="夕焼けの光は、昼の約38倍の空気を、通ってきています。", scene=SUNSET,
         say="ゆうやけの、ひかりは、ひるの、やく、サンジュウハチバイの、くうきを、とおってきています。"),
    dict(id="c2", text="太陽が真上なら、光は空気の層を、まっすぐ短く抜けます。", scene=PATH_TOP),
    dict(id="c3", text="ところが、地平線に近い太陽の光は、空気の層を、斜めに長く通る。", scene=PATH_DOWN),
    dict(id="c4", text="計算すると、高さ10度で約5.6倍、地平線で約38倍です。", scene=AM,
         say="けいさんすると、たかさ、じゅうどで、やく、ゴテンロクばい、ちへいせんで、やく、サンジュウハチバイです。"),
    dict(id="c5", text="長い道のりの途中で、散らばりやすい青い光は、ほとんど散らばってしまう。", scene=dict(kind="scatter", blue=0.9)),
    dict(id="c6", text="最後まで残るのが、赤やオレンジの光です。"),
    dict(id="c7", text="だから、夕焼けは赤いのです。", scene=SUNSET),
    dict(id="c8", text="次に夕焼けを見たら、その光がくぐってきた、38倍の空気を思い出してください。"),
])
P["s4"] = dict(title="月の空は真っ黒", lines=[
    dict(id="c1", text="月の上では、昼でも、空は真っ黒です。NASAの説明です。", scene=MOON),
    dict(id="c2", text="なぜ、地球の空は青く、月の空は黒いのか。", style="question", sub="なぜ月の空は\n【黒い】のか", scene=SKY),
    dict(id="c3", text="答えは、空気。月には、空気がほとんどありません。", scene=MOON),
    dict(id="c4", text="地球の空が青いのは、空気の粒が、青い光を散らばらせるから。", scene=SCAT),
    dict(id="c5", text="散らばらせる粒が無ければ、空は、暗いままです。"),
    dict(id="c6", text="地球の空気の重さの半分は、地上5.5kmまで。99%は、約30kmまでにあります。", scene=LAYERS,
         say="ちきゅうの、くうきの、おもさの、はんぶんは、ちじょう、ゴテンゴキロメートルまで。きゅうじゅうきゅうパーセントは、やく、さんじゅっキロメートルまでに、あります。"),
    dict(id="c7", text="その薄い空気の層が、空を青くしているのです。"),
    dict(id="c8", text="次に青空を見上げたら、たった30kmの空気の層を、思い出してください。", scene=SKY,
         say="つぎに、あおぞらを、みあげたら、たった、さんじゅっキロメートルの、くうきの、そうを、おもいだしてください。"),
])
P["s5"] = dict(title="火星の夕焼けは青い", lines=[
    dict(id="c1", text="火星の夕焼けは、青い。", scene=MARS_SET),
    dict(id="c2", text="2015年4月、探査車キュリオシティが撮った火星の夕焼けでは、太陽のまわりが青く写っています。"),
    dict(id="c3", text="昼の火星の空は、オレンジから赤っぽい色。夕焼けと、昼の色が、地球と逆なのです。", scene=MARS_DAY),
    dict(id="c4", text="なぜでしょう。", style="question", sub="なぜ火星の夕焼けは\n【青い】のか"),
    dict(id="c5", text="答えは、空気の中の粒。火星の空気には、細かい砂ぼこりが、たくさん舞っています。"),
    dict(id="c6", text="NASAは、この砂ぼこりの細かい粒が、青い光を通しやすいと説明しています。", scene=MARS_SET),
    dict(id="c7", text="地球の空は、小さな空気の粒が、青を散らばらせて青くなる。粒が違えば、空の色も変わるのです。", scene=SCAT),
    dict(id="c8", text="次に夕焼けを見たら、遠い火星では、それが青いことを思い出してください。", scene=SUNSET),
])


def ep_for(name: str) -> dict:
    p = dict(P[name])
    return dict(kind="sim", aspect="portrait" if name.startswith("s") else "landscape", credit=CREDIT, **p)
