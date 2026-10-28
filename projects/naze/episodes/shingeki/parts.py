"""進撃の巨人: 超大型巨人を人の体で作ったら。本編 5 章とショート 5 本の台本と画面。ch1〜ch5・s1〜s5 の ep.py がここから読む。
出典と計算は research.md、台本の承認版は scripts.md(2026-10-28 ユーザー承認。月と火星は外した)。作品の絵は使わない。"""

CREDIT = "人と同じ形・同じ重さの体を仮定して計算（骨の強さ Reilly & Burstein 1975 ほか）"
CREDIT_V = "人と同じ体を仮定した計算（Reilly & Burstein 1975 ほか）"  # 縦は幅が狭いので短く

WALL = dict(kind="wall")
BUILD = dict(kind="wall", building=True)
HUMAN = dict(kind="grow", h=(1.7, 1.7))
BOX3 = dict(kind="box3")
ELE = dict(kind="elephants", n=480)
BONE = dict(kind="bonesec")
COIN = dict(kind="coin")
DICE = dict(kind="dice")
LAW = dict(kind="formula", rows=[("長さ ×2", 70, "dim"), ("広さ ×4（2乗）", 90, "white"), ("重さ ×8（3乗）", 110, "yel")])
RATIO = dict(kind="formula", rows=[("重さ　約4万4千倍", 80, "white"), ("骨の断面　約1,250倍", 80, "white"), ("骨の負担　35倍", 120, "yel")])
METER0 = dict(kind="meter", seq=[(1.7, "walk")])
BEND = dict(kind="bend")
STEEL = dict(kind="steel")
THIGH = dict(kind="thigh")
STYRO = dict(kind="styro")
CURVE = dict(kind="curve")
QBLANK = dict(kind="formula", rows=[])
HALDANE = dict(kind="formula", rows=[("1926年　ホールデン", 60, "dim"), ("身長18m（人の10倍）", 80, "white"), ("重さ 1000倍　骨 100倍", 90, "white"), ("一歩ごとに骨が折れる", 100, "yel")])
GALILEO = dict(kind="galileo")
LINEUP = dict(kind="animals", hl="elephant")  # 同じ縮尺の影絵(大きさを比べる行)
ELEPHANT = dict(kind="photo", name="elephant", note="アフリカゾウ　約6トン")
DINO = dict(kind="photo", name="dino", note="最大級の恐竜　約70トン（推定）")
WHALE = dict(kind="photo", name="whale", note="シロナガスクジラ　約150トン")


def EXP(n, text):
    return dict(kind="formula", rows=[(f"実験{n}", 120, "yel"), (text, 76, "white")])


P = {}
P["ch1"] = dict(title="第1章 超大型巨人を、人の体で作る", cta=False, lines=[
    dict(id="c1", text="進撃の巨人の超大型巨人は、身長60m。高さ50mの壁から、顔が出る大きさです。", scene=WALL),
    dict(id="c2", text="ビルなら、およそ20階建て。", scene=BUILD),
    dict(id="c3", text="もし、この巨人を、人の体のまま作ったら、歩けるのでしょうか。", style="question", sub="人の体のままで\n【歩ける】のか", scene=QBLANK),
    dict(id="c4", text="答えは、歩けない。一歩ごとに、骨が折れる計算です。", scene=dict(kind="meter", seq=[(60, "walk")])),
    dict(id="c5", text="作品の巨人は架空なので、ここからは仮の実験。人の体を、そのまま大きくして確かめます。", scene=dict(kind="grow", h=(1.7, 60))),
    dict(id="c6", text="基準は、身長1.7m、体重65kgの人。", section=True, scene=HUMAN,
         say="きじゅんは、しんちょう、いってんななメートル、たいじゅう、ろくじゅうごキログラムの、ひと。"),
    dict(id="c7", text="60mは、その約35倍。背も肩幅も体の厚みも、35倍にします。", scene=BOX3),
    dict(id="c8", text="重さは、35を3回かけて、約4万4千倍。体重は約2,860トン。",
         say="おもさは、さんじゅうごを、さんかい、かけて、やく、よんまんよんせんばい。たいじゅうは、やく、にせんはっぴゃくろくじゅっトン。"),
    dict(id="c9", text="アフリカゾウのオスが約6トン。ゾウ約480頭分です。", scene=ELE,
         say="アフリカゾウの、オスが、やく、ろくトン。ゾウ、やく、よんひゃくはちじゅっとうぶんです。"),
    dict(id="c10", text="一方、体を支える骨の太さは、断面の広さで効きます。広さは2回かけ算で、約1,250倍。", scene=BONE,
         say="いっぽう、からだを、ささえる、ほねの、ふとさは、だんめんの、ひろさで、ききます。ひろさは、にかい、かけざんで、やく、せんにひゃくごじゅうばい。"),
    dict(id="c11", text="重さは4万4千倍、骨は1,250倍。骨が受け持つ重さは、人の35倍になります。", scene=RATIO,
         say="おもさは、よんまんよんせんばい、ほねは、せんにひゃくごじゅうばい。ほねが、うけもつ、おもさは、ひとの、さんじゅうごばいに、なります。"),
    dict(id="c12", text="普通は、体が大きいほど強そうに見えます。ところが、大きくなるほど、骨は苦しくなるのです。", scene=CURVE),
])
P["ch2"] = dict(title="第2章 少しずつ大きくして、走らせる", cta=False, lines=[
    dict(id="c1", text="実験1。人を少しずつ大きくして、歩かせてみます。", section=True, scene=EXP(1, "人を少しずつ大きくする")),
    dict(id="c2", text="人の骨の硬い部分は、1平方mmに約20kgかけると、つぶれます。1円玉の広さなら、約6トン。", scene=COIN,
         say="ひとの、ほねの、かたい、ぶぶんは、イチヘイホウミリに、やく、にじゅっキロ、かけると、つぶれます。いちえんだまの、ひろさなら、やく、ろくトン。"),
    dict(id="c3", text="生きた人のすねの骨で測ると、歩くときの骨の負担は、その20分の1ほど。", scene=METER0, say="いきた、ひとの、すねの、ほねで、はかると、あるくときの、ほねの、ふたんは、その、にじゅうぶんのいちほど。"),
    dict(id="c4", text="体の倍率と同じだけ、この負担が増えていきます。"),
    dict(id="c5", text="身長3m。負担は、つぶれる強さの1割。まだ平気です。", scene=dict(kind="meter", seq=[(1.7, "walk"), (3, "walk")])),
    dict(id="c6", text="7m。2割。15m級。4割を超えました。", scene=dict(kind="meter", seq=[(3, "walk"), (7, "walk"), (15, "walk")]),
         say="ななメートル。にわり。じゅうごメートルきゅう。よんわりを、こえました。"),
    dict(id="c7", text="そして、34m。負担が、骨の強さに届きます。", scene=dict(kind="meter", seq=[(15, "walk"), (34, "walk")]),
         say="そして、さんじゅうよんメートル。ふたんが、ほねの、つよさに、とどきます。"),
    dict(id="c8", text="60mでは、骨の強さの約1.7倍。歩いた瞬間に、折れる計算です。", scene=dict(kind="meter", seq=[(34, "walk"), (60, "walk")]),
         say="ろくじゅうメートルでは、ほねの、つよさの、やく、いってんななばい。あるいた、しゅんかんに、おれる、けいさんです。"),
    dict(id="c9", text="実験2。今度は、走らせてみます。", section=True, scene=EXP(2, "走らせる")),
    dict(id="c10", text="激しく動くと、骨の負担は、歩くときの約3倍になります。", scene=dict(kind="meter", seq=[(1.7, "walk"), (1.7, "run")])),
    dict(id="c11", text="走って骨が持つのは、身長11mまで。", scene=dict(kind="meter", seq=[(1.7, "run"), (11.3, "run")]),
         say="はしって、ほねが、もつのは、しんちょう、じゅういちメートルまで。"),
    dict(id="c12", text="作品の中で走り回る15m級の巨人も、人の骨のままなら、走った足が折れる計算です。", scene=dict(kind="meter", seq=[(11.3, "run"), (15, "run")]),
         say="さくひんの、なかで、はしりまわる、じゅうごメートルきゅうの、きょじんも、ひとの、ほねの、ままなら、はしった、あしが、おれる、けいさんです。"),
])
P["ch3"] = dict(title="第3章 骨を変えてみる", cta=False, lines=[
    dict(id="c1", text="では、骨をもっと強くしたら、どうなるか。", section=True, scene=BONE),
    dict(id="c2", text="実験3。骨を、鉄に変えます。", scene=EXP(3, "骨を鉄に変える")),
    dict(id="c3", text="ビルの柱などに使う、ふつうの鋼。つぶれ始める強さは、1平方mmに約25kg。", scene=dict(kind="steel", stage=1),
         say="ビルの、はしらなどに、つかう、ふつうの、はがね。つぶれはじめる、つよさは、イチヘイホウミリに、やく、にじゅうごキロ。"),
    dict(id="c4", text="実は、人の骨とほとんど変わりません。骨は、鉄に近い強さを持っているのです。"),
    dict(id="c5", text="ふつうの鋼の骨なら、歩けるのは42mまで。60mには届きません。", scene=dict(kind="steel", stage=2),
         say="ふつうの、はがねの、ほねなら、あるけるのは、よんじゅうにメートルまで。ろくじゅうメートルには、とどきません。"),
    dict(id="c6", text="橋に使う、強い鋼にすると、約78mまで歩ける計算です。", scene=dict(kind="steel", stage=3),
         say="はしに、つかう、つよい、はがねに、すると、やく、ななじゅうはちメートルまで、あるける、けいさんです。"),
    dict(id="c7", text="ただし、鉄は骨の約4倍重い。骨を鉄にすると、体はさらに重くなります。", scene=dict(kind="steel", stage=4)),
    dict(id="c8", text="実験4。今度は、骨を太くしてみます。", section=True, scene=EXP(4, "骨を太くする")),
    dict(id="c9", text="骨の負担を人と同じにするには、骨の断面を、体重と同じ4万4千倍にすればいい。", scene=dict(kind="thigh", stage=0),
         say="ほねの、ふたんを、ひとと、おなじに、するには、ほねの、だんめんを、たいじゅうと、おなじ、よんまんよんせんばいに、すればいい。"),
    dict(id="c10", text="すると骨の太さは、人の約210倍。体の幅は35倍なので、骨だけが6倍太くなります。",
         say="すると、ほねの、ふとさは、ひとの、やく、にひゃくじゅうばい。からだの、はばは、さんじゅうごばいなので、ほねだけが、ろくばい、ふとくなります。"),
    dict(id="c11", text="人の太ももの骨は、直径約2.6cm。巨人では約5.6mです。太ももの太さは約6mなので、太ももの9割が骨になります。", scene=dict(kind="thigh", stage=1),
         say="ひとの、ふとももの、ほねは、ちょっけい、やく、にてんろくセンチ。きょじんでは、やく、ごてんろくメートルです。ふとももの、ふとさは、やく、ろくメートルなので、ふとももの、きゅうわりが、ほねに、なります。"),
    dict(id="c12", text="人なら、骨は太ももの太さの15%ほど。巨人では、筋肉の入る場所が、ほとんど残りません。"),
])
P["ch4"] = dict(title="第4章 体を軽くする", cta=False, lines=[
    dict(id="c1", text="骨を変えられないなら、体の重さを変えてみます。", section=True, scene=dict(kind="meter", seq=[(60, "walk")])),
    dict(id="c2", text="実験5。体を、どこまで軽くすれば歩けるか。", scene=EXP(5, "体を軽くする")),
    dict(id="c3", text="骨の負担を、人と同じにするには、重さを35分の1にすればいい。", scene=dict(kind="styro", stage=0), say="ほねの、ふたんを、ひとと、おなじに、するには、おもさを、さんじゅうごぶんのいちに、すればいい。"),
    dict(id="c4", text="2,860トンの35分の1で、約80トン。最大級の恐竜と、同じくらいです。", scene=dict(kind="styro", stage=1),
         say="にせんはっぴゃくろくじゅっトンの、さんじゅうごぶんのいちで、やく、はちじゅっトン。さいだいきゅうの、きょうりゅうと、おなじくらいです。"),
    dict(id="c5", text="体の中身は、水の35分の1の軽さ。発泡スチロールに近い軽さです。", scene=dict(kind="styro", stage=2), say="からだの、なかみは、みずの、さんじゅうごぶんのいちの、かるさ。はっぽうスチロールに、ちかい、かるさです。"),
    dict(id="c6", text="作品の中では、巨人の体は見た目よりずっと軽い、と語られる場面があります。", scene=WALL),
    dict(id="c7", text="60mの体が歩くには、それほど軽くなければ、計算が合わないのです。"),
])
P["ch5"] = dict(title="第5章 100年前に、同じ計算をした人がいる", lines=[
    dict(id="c1", text="実はこの計算、約100年前に、イギリスの学者が書いています。", section=True, scene=HALDANE),
    dict(id="c2", text="1926年、生物学者のホールデンは、身長18mの巨人を考えました。", say="せんきゅうひゃくにじゅうろくねん、せいぶつがくしゃの、ホールデンは、しんちょう、じゅうはちメートルの、きょじんを、かんがえました。"),
    dict(id="c3", text="背が人の10倍なら、重さは1000倍、骨の断面は100倍。"),
    dict(id="c4", text="人の太ももの骨は、体重の約10倍で折れる。だから巨人は、一歩ごとに骨を折る、と書いています。"),
    dict(id="c5", text="さらに約390年前、ガリレオも、大きな動物ほど、骨を太くしないと持たないと書きました。", scene=GALILEO,
         say="さらに、やく、さんびゃくきゅうじゅうねんまえ、ガリレオも、おおきな、どうぶつほど、ほねを、ふとく、しないと、もたないと、かきました。"),
    dict(id="c6", text="本物の大きな動物は、どうしているのか。", section=True, scene=LINEUP),
    dict(id="c7", text="ゾウの脚は、太くて、まっすぐ。柱のように立てて、骨が曲がるのを減らしています。", scene=ELEPHANT),
    dict(id="c8", text="陸を歩いた最大級の恐竜でも、重さは約70トンと推定されています。超大型巨人の、約40分の1です。", scene=DINO, say="りくを、あるいた、さいだいきゅうの、きょうりゅうでも、おもさは、やく、ななじゅっトンと、すいていされています。ちょうおおがたきょじんの、やく、よんじゅうぶんのいちです。"),
    dict(id="c9", text="シロナガスクジラは約150トン。水が体を浮かせて、支えているからです。", scene=WHALE),
    dict(id="c10", text="体を大きくすると、重さは3乗で増え、骨は2乗でしか強くならない。", section=True, scene=CURVE),
    dict(id="c11", text="人の体のままでは、歩けるのは34m、走れるのは11mまででした。", scene=dict(kind="meter", seq=[(34, "walk"), (11.3, "run")]),
         say="ひとの、からだの、ままでは、あるけるのは、さんじゅうよんメートル、はしれるのは、じゅういちメートルまででした。"),
    dict(id="c12", text="冒頭の、壁から顔を出す巨人。あの体で歩くには、発泡スチロールのように軽くなるしかないのです。", scene=WALL),
    dict(id="c13", text="次に動物園でゾウを見たら、脚の太さを見てください。その太さが、重さと戦った跡です。", scene=ELEPHANT),
])

P["s1"] = dict(title="何mで骨が折れるか", lines=[
    dict(id="c1", text="人の体をそのまま大きくすると、身長34mで、歩くだけで骨が折れます。", scene=dict(kind="meter", seq=[(1.7, "walk"), (34, "walk")]),
         say="ひとの、からだを、そのまま、おおきくすると、しんちょう、さんじゅうよんメートルで、あるくだけで、ほねが、おれます。"),
    dict(id="c2", text="大きいほど強そうなのに、なぜでしょう。", style="question", sub="大きいのに\nなぜ【折れる】のか", scene=QBLANK),
    dict(id="c3", text="答えは、重さは3乗、骨の太さは2乗でしか増えないから。", scene=CURVE),
    dict(id="c4", text="歩くときの人の骨の負担は、つぶれる強さの20分の1ほど。", scene=METER0, say="あるくときの、ひとの、ほねの、ふたんは、つぶれる、つよさの、にじゅうぶんのいちほど。"),
    dict(id="c5", text="背を2倍にすると、この負担も2倍。", scene=dict(kind="meter", seq=[(1.7, "walk"), (3.4, "walk")])),
    dict(id="c6", text="3mで1割、15mで4割。", scene=dict(kind="meter", seq=[(3, "walk"), (15, "walk")]), say="さんメートルで、いちわり、じゅうごメートルで、よんわり。"),
    dict(id="c7", text="そして34mで、骨の強さに届きます。", scene=dict(kind="meter", seq=[(15, "walk"), (34, "walk")]), say="そして、さんじゅうよんメートルで、ほねの、つよさに、とどきます。"),
    dict(id="c8", text="60mの超大型巨人なら、骨の強さの約1.7倍。歩いた瞬間に折れる計算です。", scene=dict(kind="meter", seq=[(34, "walk"), (60, "walk")]),
         say="ろくじゅうメートルの、ちょうおおがたきょじんなら、ほねの、つよさの、やく、いってんななばい。あるいた、しゅんかんに、おれる、けいさんです。"),
    dict(id="c9", text="次に大きな動物を見たら、体のわりに脚が太いことを、確かめてください。", scene=ELEPHANT),
])
P["s2"] = dict(title="15m級は走れない", lines=[
    dict(id="c1", text="人の骨のまま大きくなったら、走れるのは身長11mまでです。", scene=dict(kind="meter", seq=[(1.7, "run"), (11.3, "run")]),
         say="ひとの、ほねの、まま、おおきくなったら、はしれるのは、しんちょう、じゅういちメートルまでです。"),
    dict(id="c2", text="15m級の巨人は、なぜ走れないのか。", style="question", sub="15m級は\nなぜ【走れない】のか", scene=QBLANK,
         say="じゅうごメートルきゅうの、きょじんは、なぜ、はしれないのか。"),
    dict(id="c3", text="答えは、走ると骨の負担が、歩くときの約3倍になるから。", scene=dict(kind="meter", seq=[(1.7, "walk"), (1.7, "run")])),
    dict(id="c4", text="背が人の何倍になるかで、骨の負担も同じ倍率で増えます。", scene=CURVE),
    dict(id="c5", text="15m級は、人の約9倍。走ると、負担は骨の強さを3割も超えます。", scene=dict(kind="meter", seq=[(11.3, "run"), (15, "run")]),
         say="じゅうごメートルきゅうは、ひとの、やく、きゅうばい。はしると、ふたんは、ほねの、つよさを、さんわりも、こえます。"),
    dict(id="c6", text="作品の中で走り回る巨人も、人の骨なら、足が折れる計算です。"),
    dict(id="c7", text="6トンのゾウは、速く動いても、4本の足が同時に地面から離れることはありません。", scene=ELEPHANT,
         say="ろくトンの、ゾウは、はやく、うごいても、よんほんの、あしが、どうじに、じめんから、はなれることは、ありません。"),
    dict(id="c8", text="次に走るとき、足の骨に体重の何倍もかかっていることを思い出してください。", scene=dict(kind="meter", seq=[(1.7, "run")])),
])
P["s3"] = dict(title="太ももの9割が骨", lines=[
    dict(id="c1", text="超大型巨人の骨を、人と同じ負担になるまで太くすると、太ももの9割が骨になります。", scene=dict(kind="thigh", stage=1)),
    dict(id="c2", text="どういうことか。", style="question", sub="骨を太くすると\n【何が起きる】のか", scene=QBLANK),
    dict(id="c3", text="答えは、骨の太さを、体の幅の6倍の勢いで増やす必要があるから。"),
    dict(id="c4", text="60mの巨人は、人の35倍。体重は約4万4千倍。", scene=BOX3, say="ろくじゅうメートルの、きょじんは、ひとの、さんじゅうごばい。たいじゅうは、やく、よんまんよんせんばい。"),
    dict(id="c5", text="骨の断面も4万4千倍にすると、太さは人の約210倍。", scene=BONE, say="ほねの、だんめんも、よんまんよんせんばいに、すると、ふとさは、ひとの、やく、にひゃくじゅうばい。"),
    dict(id="c6", text="人の太ももの骨は、直径約2.6cm。巨人では約5.6m。", scene=dict(kind="thigh", stage=1),
         say="ひとの、ふとももの、ほねは、ちょっけい、やく、にてんろくセンチ。きょじんでは、やく、ごてんろくメートル。"),
    dict(id="c7", text="太ももは35倍で約6m。人なら15%ほどの骨が、9割を占めてしまいます。筋肉の入る場所がありません。",
         say="ふとももは、さんじゅうごばいで、やく、ろくメートル。ひとなら、じゅうごパーセントほどの、ほねが、きゅうわりを、しめてしまいます。きんにくの、はいる、ばしょが、ありません。"),
    dict(id="c8", text="次にゾウの写真を見たら、脚が体のわりに太いことを、確かめてください。", scene=ELEPHANT),
])
P["s4"] = dict(title="歩ける巨人は発泡スチロール", lines=[
    dict(id="c1", text="60mの巨人が歩けるとしたら、体は、発泡スチロールに近い軽さです。", scene=dict(kind="styro", stage=2)),
    dict(id="c2", text="なぜ、そこまで軽くなるのか。", style="question", sub="なぜそこまで\n【軽く】なるのか", scene=QBLANK),
    dict(id="c3", text="答えは、骨の負担。人と同じにするには、重さを35分の1にする必要があります。", scene=dict(kind="styro", stage=0), say="こたえは、ほねの、ふたん。ひとと、おなじに、するには、おもさを、さんじゅうごぶんのいちに、する、ひつようが、あります。"),
    dict(id="c4", text="人の体のままなら、60mの巨人は約2,860トン。歩くと骨の負担は、強さの約1.7倍。", scene=dict(kind="meter", seq=[(60, "walk")]),
         say="ひとの、からだの、ままなら、ろくじゅうメートルの、きょじんは、やく、にせんはっぴゃくろくじゅっトン。あるくと、ほねの、ふたんは、つよさの、やく、いってんななばい。"),
    dict(id="c5", text="重さを35分の1の約80トンにすると、負担は人と同じになります。", scene=dict(kind="styro", stage=1),
         say="おもさを、さんじゅうごぶんのいちの、やく、はちじゅっトンに、すると、ふたんは、ひとと、おなじに、なります。"),
    dict(id="c6", text="体の中身は、水の35分の1の軽さです。", scene=dict(kind="styro", stage=2), say="からだの、なかみは、みずの、さんじゅうごぶんのいちの、かるさです。"),
    dict(id="c7", text="作品の中でも、巨人の体は見た目より軽い、と語られる場面があります。", scene=WALL),
    dict(id="c8", text="次に大きな着ぐるみを見たら、中が空っぽで軽いことを思い出してください。"),
])
P["s5"] = dict(title="骨を鉄にしたら", lines=[
    dict(id="c1", text="超大型巨人の骨を、鉄に変えても、60mでは歩けません。", scene=dict(kind="steel", stage=2)),
    dict(id="c2", text="鉄の方が、ずっと強いのではないか。", style="question", sub="鉄の方が\n【強い】のでは？", scene=QBLANK),
    dict(id="c3", text="答えは、人の骨が、もともと鉄に近い強さだから。", scene=dict(kind="steel", stage=1)),
    dict(id="c4", text="人の骨の硬い部分は、1平方mmに約20kgでつぶれます。", scene=COIN, say="ひとの、ほねの、かたい、ぶぶんは、イチヘイホウミリに、やく、にじゅっキロで、つぶれます。"),
    dict(id="c5", text="ビルの柱などに使うふつうの鋼は、約25kg。ほとんど変わりません。", scene=dict(kind="steel", stage=1),
         say="ビルの、はしらなどに、つかう、ふつうの、はがねは、やく、にじゅうごキロ。ほとんど、かわりません。"),
    dict(id="c6", text="ふつうの鋼の骨で歩けるのは、42mまで。", scene=dict(kind="steel", stage=2), say="ふつうの、はがねの、ほねで、あるけるのは、よんじゅうにメートルまで。"),
    dict(id="c7", text="しかも鉄は、骨の約4倍重い。体はさらに重くなります。", scene=dict(kind="steel", stage=4)),
    dict(id="c8", text="次に自分の腕をさわったら、中に鉄並みの骨が入っていると思い出してください。", scene=BONE),
])


def ep_for(name: str) -> dict:
    p = dict(P[name])
    return dict(kind="sim", aspect="portrait" if name.startswith("s") else "landscape", credit=CREDIT_V if name.startswith("s") else CREDIT, **p)
