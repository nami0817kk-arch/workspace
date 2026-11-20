"""小さい動物ほどたくさん食べる(トガリネズミ): 本編 5 章とショート 5 本の台本と画面。ch1〜ch5・s1〜s5 の ep.py がここから読む。
数字と出典は sim/facts.md(論文)と sim/calc.txt(自分の計算)。場面の絵は Gemini(gem_*)と FLUX(illust_*)で作った。
画面は 2〜3 行ごとに種類を変える(場面の絵・数字・サイコロ・グラフ・心臓・棒)。"""
from pathlib import Path

A = Path(__file__).resolve().parent / "assets"
CREDIT = "絵: AI で作ったイメージ"
RED, YEL, WHITE, BLUE = (240, 90, 80), (255, 214, 64), (255, 255, 255), (120, 190, 255)
GREY, SAND = (170, 180, 200), (226, 196, 140)


def ILL(name, pan=None, step=None, tr=None, title=None):
    d = dict(shot="illust", path=str(A / name), step=step)
    if pan:
        d["pan"] = pan
    if tr:
        d["tr"] = tr
    if title:
        d["title"] = title
    return d


def BIG(big, sub=None, note=None, step=None, count=True, tr=None):
    d = dict(shot="big", big=big, sub=sub, note=note, step=step, count=count)
    if tr:
        d["tr"] = tr
    return d


def CUBES(n=1, step=None, tr=None, **kw):
    d = dict(shot="cubes", n=n, step=step, **kw)
    if tr:
        d["tr"] = tr
    return d


def CHART(n=4, step=None, tr=None, **kw):
    d = dict(shot="chart", n=n, step=step, **kw)
    if tr:
        d["tr"] = tr
    return d


def HEART(items, step=None, tr=None, **kw):
    d = dict(shot="heart", items=items, step=step, **kw)
    if tr:
        d["tr"] = tr
    return d


def BARS(items, title=None, note=None, fmt="{}", step=None, tr=None):
    d = dict(shot="bars", items=items, title=title, note=note, fmt=fmt, step=step)
    if tr:
        d["tr"] = tr
    return d


EAT, SNOW, PILE = "gem_eat.jpg", "gem_snow.jpg", "gem_pile.jpg"
RUN, ELE, HUM, VS = "illust_shrew_run2.jpg", "illust_elephant2.jpg", "illust_hummingbird1.jpg", "illust_mouse_elephant2.jpg"
HEARTS = [("人", 70, (200, 130, 130)), ("コビトジャコウネズミ", 1511, RED)]
ANSWERS = [("体重2gで、毎日体重の6倍を食べる", "食べないと数時間しか生きられない"),
           ("小さいほど、体重に比べて表面が広い", "2gは6トンより144倍、熱の逃げ口が多い"),
           ("体重1gあたり、ゾウの約40倍のエネルギー", "心臓は1分に1,511回"),
           ("ためる余裕がない", "体の脂肪は1日足らずで全部入れ替わる"),
           ("冬は脳まで縮めて節約する", "小ささの限界に近い体")]

P = {}

# ---- 第1章 小さすぎる体 ---------------------------------------------------------------------------------
P["ch1"] = dict(title="第1章 小さすぎる体", cta=False, lines=[
    dict(id="c1", text="世界で最も小さい哺乳類の1つ、コビトジャコウネズミ。体重は、わずか2gです。", scene=ILL(EAT, pan=(0.25, 0.1, 0.75, 0.9), step=0)),
    dict(id="c2", text="1円玉2枚と同じ重さです。", scene=BIG("2g", sub="コビトジャコウネズミの体重", note="1円玉 2枚ぶん", step=0, count=False)),
    dict(id="c3", text="この動物は、1日にコオロギを8匹から12匹食べます。", scene=ILL(PILE, pan=(0.3, 0.1, 0.8, 0.9), step=0, tr="whip")),
    dict(id="c4", text="重さにすると、自分の体重の約6倍です。", scene=BIG("約6倍", sub="1日に食べる量（体重に比べて）", note="Geyer ほか 2022", step=0, count=False)),
    dict(id="c5", text="体重60kgの人なら、1日に360kg食べる計算です。", scene=BARS([("人の体重", 60, GREY), ("同じ割合で食べると", 360, YEL)], title="60kgの人に置きかえると（計算）", fmt="{}kg", step=0)),
    dict(id="c6", text="そして、食べないと、数時間しか生きられません。", scene=ILL(RUN, pan=(0.2, 0.2, 0.7, 0.8), step=0)),
    dict(id="c7", text="なぜ小さい動物は、こんなに食べなければならないのか。", style="question", sub="小さい動物は\nなぜ【たくさん】食べるのか"),
    dict(id="c8", text="答えを先に言います。", section=True),
    dict(id="c9", text="体の熱が、体の表面から逃げていくからです。", scene=CUBES(1, step=0, title="熱は表面から逃げる", label="作る熱は体の中、逃げる口は表面")),
    dict(id="c10", text="体が小さいほど、体重に比べて表面が広く、熱がどんどん逃げます。", scene=CUBES(10, step=0, title="小さく分けると、表面は広がる")),
    dict(id="c11", text="体の大きさと、体を保つのに要るエネルギーで、計算して確かめます。", scene=CHART(4, step=0, title="体重1gあたりのエネルギー")),
])

# ---- 第2章 表面と体積 -----------------------------------------------------------------------------------
P["ch2"] = dict(title="第2章 表面と体積", cta=False, lines=[
    dict(id="d1", text="動物の体の熱は、体の中で作られて、皮膚から外へ逃げていきます。", scene=ILL(SNOW, pan=(0.3, 0.2, 0.8, 0.8), step=1, tr="zoom")),
    dict(id="d2", text="作る熱は、体の大きさで決まります。逃げる熱は、表面の広さで決まります。"),
    dict(id="d3", text="ここに、1辺1cmのサイコロがあります。", section=True, scene=CUBES(1, step=1, title="1辺 1cm のサイコロ")),
    dict(id="d4", text="表面の広さは、6平方cmです。"),
    dict(id="d5", text="これを1辺1mmに切ると、1,000個になります。", scene=CUBES(10, step=1, title="1辺 1mm に切る")),
    dict(id="d6", text="重さは同じなのに、表面は全部で60平方cm。10倍に増えました。"),
    dict(id="d7", text="小さく分けるほど、表面は広くなるのです。"),
    dict(id="d8", text="2gのコビトジャコウネズミと、6トンのゾウ。", scene=ILL(VS, pan=(0.1, 0.1, 0.9, 0.9), step=1, tr="whip")),
    dict(id="d9", text="同じ形だとすると、体重1gあたりの表面は、小さいほうが144倍も広い計算です。", scene=BIG("144倍", sub="体重1gあたりの表面の広さ", note="2g と 6トン、同じ形として計算", step=1)),
    dict(id="d10", text="熱の逃げ口が、144倍あるのと同じです。"),
])

# ---- 第3章 燃やし続ける体 -------------------------------------------------------------------------------
P["ch3"] = dict(title="第3章 燃やし続ける体", cta=False, lines=[
    dict(id="e1", text="では、実際に、どれだけのエネルギーを使っているのか。", scene=CHART(0, step=2, title="体重1gあたりのエネルギー", tr="zoom")),
    dict(id="e2", text="動物が体を保つのに要るエネルギーは、体重の4分の3乗に比例します。", scene=CHART(4, step=2, title="体重1gあたりのエネルギー")),
    dict(id="e3", text="クライバーの法則と呼ばれる決まりです。"),
    dict(id="e4", text="これで計算すると、体重1gあたり、2gの動物は、ゾウの約40倍のエネルギーを使います。", scene=BIG("約40倍", sub="体重1gあたりのエネルギー（2g と 6トン）", note="クライバーの式で計算", step=2)),
    dict(id="e5", text="そのエネルギーを、体のすみずみへ運ぶのが心臓です。", section=True, scene=HEART(HEARTS, step=2, title="心臓が打つ速さ")),
    dict(id="e6", text="コビトジャコウネズミの心臓は、1分に最大1,511回。"),
    dict(id="e7", text="1秒に25回。恒温動物で記録された中で、一番速い心拍です。", scene=BIG("1秒に25回", sub="コビトジャコウネズミの心臓", note="Jürgens ほか 1996", step=2, count=False)),
    dict(id="e8", text="体重あたりで、人の67倍の酸素を使っています。", scene=BARS([("人", 1, GREY), ("コビトジャコウネズミ", 67, RED)], title="体重あたりの酸素の量（人を1として）", fmt="{}倍", step=2)),
    dict(id="e9", text="息をする回数は、1分に最大894回です。"),
])

# ---- 第4章 食べ続ける -----------------------------------------------------------------------------------
P["ch4"] = dict(title="第4章 食べ続ける", cta=False, lines=[
    dict(id="f1", text="ヨーロッパのトガリネズミは、体重9gほどです。", scene=ILL(RUN, pan=(0.1, 0.2, 0.6, 0.8), step=3, tr="zoom")),
    dict(id="f2", text="1日に、体重の45%から77%を食べます。", scene=BARS([("少ない時期", 45, GREY), ("多い時期", 77, YEL)], title="1日に食べる量（体重に比べて）", fmt="{}%", step=3)),
    dict(id="f3", text="5℃の寒さで餌を取り上げると、5時間のうちに死んだという実験の記録があります。", scene=ILL(SNOW, pan=(0.4, 0.3, 0.9, 0.9), step=3)),
    dict(id="f4", text="体の脂肪は、9時間から24時間で、全部入れ替わります。", scene=BIG("9〜24時間", sub="体の脂肪が全部入れ替わる時間", note="Keicher ほか 2017", step=3, count=False)),
    dict(id="f5", text="体に、エネルギーをためておく余裕がないのです。"),
    dict(id="f6", text="一方、ゾウは1日に12時間から18時間、食べ続けます。", section=True, scene=ILL(ELE, pan=(0.2, 0.1, 0.8, 0.9), step=3, tr="whip")),
    dict(id="f7", text="それでも、食べる量は、多くても体重の1割です。", scene=BARS([("ゾウ", 10, GREY), ("コビトジャコウネズミ", 600, RED)], title="1日に食べる量（体重に比べて）", fmt="{}%", step=3)),
    dict(id="f8", text="冬になると、トガリネズミは驚くことをします。", scene=ILL(SNOW, pan=(0.0, 0.0, 1.0, 1.0), step=3)),
    dict(id="f9", text="頭の骨を15%、脳を最大で26%縮めて、使うエネルギーを減らすのです。", scene=BIG("脳 −26%", sub="冬のトガリネズミ", note="頭骨 −15%（Lázaro ほか 2017・2018）", step=3, count=False)),
    dict(id="f10", text="春になると、また大きくなります。"),
])

# ---- 第5章 答え -----------------------------------------------------------------------------------------
CARDS_N = lambda n: dict(shot="cards", items=ANSWERS, n=n, step=4)  # noqa: E731
P["ch5"] = dict(title="第5章 答え", cta=True, lines=[
    dict(id="g1", text="鳥のハチドリも、とても小さな体です。", scene=ILL(HUM, pan=(0.1, 0.05, 0.9, 0.95), step=4, tr="zoom")),
    dict(id="g2", text="夜は体温を下げて眠り、エネルギーを節約します。"),
    dict(id="g3", text="アンデスの山では、体温が3.26℃まで下がったハチドリが見つかっています。", scene=BIG("3.26℃", sub="眠っているハチドリの体温", note="Wolf ほか 2020", step=4, count=False)),
    dict(id="g4", text="体温を保てる、小ささの限界に近い動物たちなのです。", scene=CHART(2, step=4, title="小さいほど、体重1gあたりのエネルギーが要る")),
    dict(id="g5", text="まとめます。", section=True, scene=CARDS_N(1)),
    dict(id="g6", text="1つ目。体重2gで、毎日体重の6倍を食べる。食べないと数時間しかもたない。"),
    dict(id="g7", text="2つ目。小さいほど、体重に比べて表面が広い。熱の逃げ口は144倍。", scene=CARDS_N(2)),
    dict(id="g8", text="3つ目。体重1gあたり、ゾウの約40倍のエネルギー。心臓は1分に1,511回。", scene=CARDS_N(3)),
    dict(id="g9", text="4つ目。ためる余裕がない。体の脂肪は1日足らずで全部入れ替わる。", scene=CARDS_N(4)),
    dict(id="g10", text="5つ目。冬は脳まで縮めて節約する。小ささの限界に近い体。", scene=CARDS_N(5)),
    dict(id="g11", text="小さい動物は、体の表面から逃げる熱と、いつも戦っています。", scene=ILL(EAT, pan=(0.3, 0.2, 0.8, 0.8), step=4)),
    dict(id="g12", text="次に小さな動物を見たら、その胸の中で、心臓が1秒に何回打っているか、想像してみてください。", scene=HEART(HEARTS, step=4, title="心臓が打つ速さ")),
])

# ---- ショート -------------------------------------------------------------------------------------------
P["s1"] = dict(title="体重2gの動物は、毎日体重の6倍を食べる", lines=[
    dict(id="a1", text="体重2gのコビトジャコウネズミは、毎日、体重の約6倍を食べます。", scene=ILL(EAT, pan=(0.45, 0.1, 0.8, 0.9))),
    dict(id="a2", text="コオロギを、1日に8匹から12匹。", scene=ILL(PILE, pan=(0.5, 0.1, 0.85, 0.9))),
    dict(id="a3", text="60kgの人なら、毎日360kg食べる計算です。", scene=BARS([("人の体重", 60, GREY), ("同じ割合で食べると", 360, YEL)], title="60kgの人なら（計算）", fmt="{}kg")),
    dict(id="a4", text="食べないと、数時間しか生きられません。"),
    dict(id="a5", text="小さい体は、体重に比べて表面が広く、熱がどんどん逃げるからです。", scene=CUBES(10, title="小さく分けると表面が広がる", label="表面 10倍")),
    dict(id="a6", text="心臓は、1分に最大1,511回打っています。", scene=HEART([("コビトジャコウネズミ", 1511, RED)], title="心臓が打つ速さ")),
])

P["s2"] = dict(title="サイコロを切ると表面が10倍。小さい動物が寒い理由", lines=[
    dict(id="b1", text="1辺1cmのサイコロを、1辺1mmに切ると、表面は10倍になります。", scene=CUBES(1, title="1辺 1cm", label="表面 6平方cm")),
    dict(id="b2", text="1,000個に分かれて、表面は6平方cmから60平方cmへ。", scene=CUBES(10, title="1辺 1mm に切る", label="表面 60平方cm")),
    dict(id="b3", text="動物の体も同じです。小さいほど、体重に比べて表面が広い。", scene=ILL(VS, pan=(0.1, 0.2, 0.6, 0.9))),
    dict(id="b4", text="2gの動物は、6トンのゾウより、体重1gあたりの表面が144倍広い計算です。", scene=BIG("144倍", sub="体重1gあたりの表面", note="同じ形として計算")),
    dict(id="b5", text="熱はその表面から逃げます。だから小さい動物は、食べ続けないと体が冷えてしまうのです。", scene=ILL(SNOW, pan=(0.45, 0.2, 0.85, 0.9))),
])

P["s3"] = dict(title="心臓が1分に1,511回打つ動物", lines=[
    dict(id="h1", text="心臓が1分に1,511回打つ動物がいます。", scene=HEART([("コビトジャコウネズミ", 1511, RED)], title="心臓が打つ速さ")),
    dict(id="h2", text="1秒に25回。体重2gの、コビトジャコウネズミです。", scene=ILL(EAT, pan=(0.45, 0.1, 0.8, 0.9))),
    dict(id="h3", text="人の心臓は、休んでいるとき1分におよそ70回。", scene=HEART(HEARTS, title="心臓が打つ速さ")),
    dict(id="h4", text="体重あたりで、人の67倍の酸素を使っています。", scene=BARS([("人", 1, GREY), ("コビトジャコウネズミ", 67, RED)], title="体重あたりの酸素（人を1として）", fmt="{}倍")),
    dict(id="h5", text="小さい体は熱がどんどん逃げるので、休まず燃やし続けないといけないのです。"),
])

P["s4"] = dict(title="冬になると、脳を縮める動物", lines=[
    dict(id="k1", text="冬になると、脳を縮める動物がいます。", scene=ILL(SNOW, pan=(0.45, 0.2, 0.85, 0.9))),
    dict(id="k2", text="ヨーロッパのトガリネズミです。体重は9gほど。", scene=ILL(RUN, pan=(0.2, 0.2, 0.6, 0.8))),
    dict(id="k3", text="冬の前に、脳は最大で26%、頭の骨は15%縮みます。", scene=BIG("脳 −26%", sub="冬のトガリネズミ", note="頭骨 −15%", count=False)),
    dict(id="k4", text="小さい体は、体重に比べて表面が広く、熱がどんどん逃げます。", scene=CUBES(10, title="小さいほど表面が広い", label="表面 10倍")),
    dict(id="k5", text="脳を小さくして、使うエネルギーを減らすのです。"),
    dict(id="k6", text="春になると、脳はまた大きくなります。", scene=ILL(EAT, pan=(0.45, 0.1, 0.8, 0.9))),
])

P["s5"] = dict(title="ゾウは体重の1割、トガリネズミは6倍を毎日食べる", lines=[
    dict(id="m1", text="ゾウが1日に食べる量は、多くても体重の1割です。", scene=ILL(ELE, pan=(0.3, 0.1, 0.8, 0.9))),
    dict(id="m2", text="コビトジャコウネズミは、体重の約6倍です。", scene=BARS([("ゾウ", 10, GREY), ("コビトジャコウネズミ", 600, RED)], title="1日に食べる量（体重に比べて）", fmt="{}%")),
    dict(id="m3", text="体重1gあたりで要るエネルギーは、小さいほうが約40倍。", scene=CHART(4, title="体重1gあたりのエネルギー")),
    dict(id="m4", text="小さい体ほど、体重に比べて表面が広く、熱が逃げるからです。", scene=CUBES(10, title="小さいほど表面が広い", label="表面 10倍")),
    dict(id="m5", text="ゾウは食べる時間が長く、トガリネズミは食べる量が多いのです。", scene=ILL(VS, pan=(0.1, 0.2, 0.6, 0.9))),
])

# ---- 読み ------------------------------------------------------------------------------------------------
YOMI = [("1,511回", "センゴヒャクジュウイッカイ"), ("894回", "ハッピャクキュウジュウヨンカイ"), ("70回", "ナナジュッカイ"), ("25回", "ニジュウゴカイ"),
        ("60平方cm", "ロクジュウヘイホウセンチ"), ("6平方cm", "ロクヘイホウセンチ"), ("1辺1cm", "いっぺんイッセンチ"), ("1辺1mm", "いっぺんイチミリ"),
        ("1,000個", "センコ"), ("360kg", "サンビャクロクジュッキロ"), ("60kg", "ロクジュッキロ"), ("9g", "キュウグラム"), ("2g", "ニグラム"), ("1g", "イチグラム"),
        ("6トン", "ロクトン"), ("144倍", "ヒャクヨンジュウヨンバイ"), ("67倍", "ロクジュウナナバイ"), ("40倍", "ヨンジュウバイ"), ("6倍", "ロクバイ"), ("10倍", "ジュウバイ"),
        ("45%", "ヨンジュウゴパーセント"), ("77%", "ナナジュウナナパーセント"), ("26%", "ニジュウロクパーセント"), ("15%", "ジュウゴパーセント"),
        ("3.26℃", "サンテンニーロクド"), ("5℃", "ゴド"), ("4分の3乗", "ヨンブンノサンジョウ"), ("1円玉2枚", "イチエンだまニマイ"),
        ("8匹から12匹", "ハッピキからジュウニヒキ"), ("9時間から24時間", "クジカンからニジュウヨジカン"), ("12時間から18時間", "ジュウニジカンからジュウハチジカン"),
        ("5時間", "ゴジカン"), ("1割", "イチワリ"), ("1日足らず", "いちにちたらず"), ("1分", "イップン"), ("1秒", "イチビョウ"),
        ("コビトジャコウネズミ", "コビトジャコウネズミ"), ("哺乳類", "ほにゅうるい"), ("恒温動物", "こうおんどうぶつ"), ("心拍", "しんぱく"),
        ("1つ目", "ひとつめ"), ("2つ目", "ふたつめ"), ("3つ目", "みっつめ"), ("4つ目", "よっつめ"), ("5つ目", "いつつめ"), ("1つ", "ひとつ")]


def yomi(s):
    for a, b in YOMI:
        s = s.replace(a, b)
    return s


SAY = {}


def ep_for(name: str) -> dict:
    p = dict(P[name])
    res = []
    for l in p["lines"]:
        if (name, l["id"]) in SAY:
            l = dict(l, say=SAY[(name, l["id"])])
        elif "say" not in l:
            y = yomi(l["text"])
            if y != l["text"]:
                l = dict(l, say=y)
        res.append(l)
    p["lines"] = res
    return dict(kind="sim", aspect="portrait" if name.startswith("s") else "landscape", credit=CREDIT, **p)
