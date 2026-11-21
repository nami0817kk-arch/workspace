"""ペンギンの回(2026-11-21 台本 第1稿)の台本と画面。本編 ch1〜ch6(横)とショート s1〜s4(縦)の ep.py がここを読む。
台本の正は 台本.md(この lines.py から書き出す)。画面の作りは naze/stage.py の冒頭。

出どころ:
- 表面の温度(気温 −17.6℃、背中 −23.2℃、お腹 −21.8℃、頭 −18.8℃、翼 −17.0℃、足 −16.8℃、0℃を上回ったのは目のまわりだけ、オス 40 羽、
  2008 年 6 月、ポワント・ジェオロジー): McCafferty et al. 2013, Biology Letters 9:20121192
- 晴れた空は空気より 20℃以上冷たいことがある: 同上(本文)
- 足(足根)の温度は 0℃より数度高い: Goldsmith & Sladen 1961, J Physiol 157:251(McCafferty 2013 が引用)
- 足・頭・わきの下の動脈と静脈の網で熱を戻す: McCafferty 2013 の考察
- 翼の付け根の動脈の数はコウテイペンギンがいちばん多い: Thomas & Fordyce 2012(McCafferty 2013 が引用)
- 体の中の温度 37.5℃: Gilbert, Le Maho & Ancel(繁殖期の深部体温 37.5±0.4℃)
- 群れの中の気温は最高 37.5℃、記録計は 8 羽の羽に付けた: Gilbert et al. 2006
- 群れは 30〜60 秒ごとに少しずつ進み、波のように伝わる。1.3 秒ごとの写真を 4 時間: Zitterbart et al. 2011, PLoS ONE
- 群れで固まると、小さな群れより約 26% 少ない力ですむ: Ancel et al. 1997, Nature 385:304
- 群れなしでは、食べずにいられるのは約 60 日で、卵がかえるまでもたない: Ancel ほか(1997 を引いた後の論文)
- オスの絶食は約 115 日、そのうち卵を温めるのが約 65 日、体重 38.2kg → 22.75kg(40.5% 減): Groscolas 1986, J Comp Physiol B
- 気温はマイナス 40℃、風は秒速 40m まで: Le Maho et al. 1976(総説の引用)。マイナス 10℃を下回ると余分な力を使い始める(下限臨界温度 約 −10℃): Le Maho 1976
- 表の羽は 1 平方センチに多くて約 9 本、鳥でいちばん密ではない。綿毛は表の羽の約 4 倍の密度:
  Williams, Hagelin & Kooyman 2015, Proc R Soc B 282:20152033
- 赤道より北にもいるのはガラパゴスペンギンだけ。暑いときは犬のように口を開けて息をし、翼を広げ、前かがみで足に日陰を作る(足は血の流れが多く、熱が出入りしやすい)
- アフリカペンギンは 10〜20℃の海で餌をとり、30℃を超える陸で子育てする: Welman et al. 2024, Bird Conservation International
- 目の上のピンクの肌は、暑いと血を多く流して熱を逃がす(動物園・水族館の解説)
"""
from PIL import Image, ImageDraw

from naze import stage as sg

W, H, P = sg.W, sg.H, sg.PORTRAIT
QTAG = "ペンギンの足は、なぜ凍らないのか"
COLORS = {"南極": (150, 210, 255), "赤道": (255, 170, 90)}


def S(name):
    return f"assets/stock/{name}"


def V(name, start=0.0, speed=1.0, cx=0.5, place=None, **kw):
    d = dict(kind="video", src=S(name + ".mp4"), start=start, speed=speed, cx=cx, **kw)
    if place:
        d["place"] = place
    return d


def PH(name, move="in", place=None):
    d = dict(kind="photo", src=S(name + ".jpg"), move=move)
    if place:
        d["place"] = place
    return d


def XY(fx, fy, cx=0.5):
    if not P:
        return (fx * W, fy * H)
    sw = H * 16 / 9
    x0 = min(max(sw * cx - W / 2, 0), sw - W)
    return (fx * sw - x0, fy * H)


def BOX(fx0, fy0, fx1, fy1, cx=0.5):
    a, b = XY(fx0, fy0, cx), XY(fx1, fy1, cx)
    return (max(0, a[0]), max(0, a[1]), min(W, b[0]), min(H, b[1]))


# ---- 図: 温度の目盛り(体の中・足の中・気温・表面を 1 本の目盛りに置く) ---------------------------------
THERMO = {  # step 番号 → (温度, 札, 色)
    1: (37.5, "体の中 37.5℃", (255, 140, 90)),
    2: (3.0, "足の中 0℃の少し上", (255, 214, 64)),
    3: (-17.6, "気温 −17.6℃", (200, 200, 205)),
    4: (-23.2, "背中の表面 −23.2℃", (130, 190, 255)),
}


def draw_thermo(img: Image.Image, t: float, c) -> None:
    """縦の目盛り(+40℃〜−30℃)。step n で THERMO[n] の印が出る。0℃の線は常に出す。"""
    steps = {f["n"]: c.when(f) for f in c.seg["fx"] if f["k"] == "step"}
    show = c.seg.get("show", [1, 2, 3, 4])
    bg = Image.new("RGBA", (W, H), (10, 16, 30, 255))
    d = ImageDraw.Draw(bg, "RGBA")
    top, bot = (H * 0.16, H * 0.80) if not P else (H * 0.20, H * 0.68)
    x = W * (0.36 if not P else 0.30)

    def y(v):
        return top + (40 - v) / 70 * (bot - top)
    d.rounded_rectangle([x - 18, top - 10, x + 18, bot + 10], 18, fill=(40, 50, 70, 255))
    fS = sg.F("YuGothB.ttc", 30 if not P else 36)
    for v in (40, 20, 0, -20):
        d.line([(x + 24, y(v)), (x + 50, y(v))], fill=(150, 160, 180, 255), width=3)
        sg.stext(d, (x + 60, y(v)), f"{v:+d}℃".replace("+0", "0"), fS, (170, 180, 200, 255), anchor="lm")
    d.line([(x - 60, y(0)), (W * 0.92, y(0))], fill=(255, 255, 255, 110), width=2)
    fL = sg.F("YuGothB.ttc", 46 if not P else 52)
    for n in show:
        if n not in steps:
            continue
        k = sg.ease((t - steps[n]) / 0.5)
        if k <= 0:
            continue
        v, label, col = THERMO[n]
        yy = y(v)
        r = 22
        d.ellipse([x - r, yy - r, x + r, yy + r], fill=col + (int(255 * k),))
        d.line([(x + 30, yy), (x + 200, yy)], fill=col + (int(255 * k),), width=4)
        sg.stext(d, (x + 215, yy), label, fL, col + (int(255 * k),), anchor="lm")
    img.alpha_composite(bg)


# ---- 図: 行きと戻りの血管(熱が行きから戻りへ移る) ----------------------------------------------------
def draw_vessels(img: Image.Image, t: float, c) -> None:
    """step 1=行きの血管(上が赤→下が青) 2=戻りの血管(下が青→上が赤) 3=熱が移る(横向きの小さな矢印が流れる)。"""
    steps = {f["n"]: c.when(f) for f in c.seg["fx"] if f["k"] == "step"}

    def k(n, dd=0.6):
        return sg.ease((t - steps.get(n, 1e9)) / dd)
    bg = Image.new("RGBA", (W, H), (10, 16, 30, 255))
    d = ImageDraw.Draw(bg, "RGBA")
    top, bot = (H * 0.16, H * 0.78) if not P else (H * 0.18, H * 0.66)
    xa, xv = (W * 0.43, W * 0.57) if not P else (W * 0.36, W * 0.64)
    fL = sg.F("YuGothB.ttc", 44 if not P else 50)
    sg.stext(d, (W / 2, top - 40), "体（37.5℃）", fL, (255, 170, 120, 255), anchor="mm")
    sg.stext(d, (W / 2, bot + 50), "足（0℃の少し上）", fL, (150, 210, 255, 255), anchor="mm")

    def col(u):  # u=0 上(温かい) → 1 下(冷たい)
        return (int(240 - 140 * u), int(90 + 80 * u), int(70 + 185 * u))
    n = 60
    for x, kk, label, down in ((xa, k(1), "行き", True), (xv, k(2), "戻り", False)):
        if kk <= 0:
            continue
        for i in range(n):
            u0, u1 = i / n, (i + 1) / n
            d.line([(x, top + (bot - top) * u0), (x, top + (bot - top) * u1)], fill=col(u0) + (int(255 * kk),), width=26)
        # 流れの向きの粒
        for j in range(6):
            s = ((t * 0.35 + j / 6) % 1.0)
            u = s if down else 1 - s
            yy = top + (bot - top) * u
            d.ellipse([x - 7, yy - 7, x + 7, yy + 7], fill=(255, 255, 255, int(200 * kk)))
        sg.stext(d, (x + (-80 if down else 80), top + 40), label, sg.F("YuGothB.ttc", 38 if not P else 44),
                 (255, 255, 255, int(255 * kk)), anchor="mm")
    k3 = k(3)
    if k3 > 0:
        for j in range(7):
            u = 0.12 + j * 0.12
            yy = top + (bot - top) * u
            ph = (t * 1.2 + j * 0.3) % 1.0
            xx = xa + 20 + (xv - xa - 40) * ph
            d.line([(xa + 20, yy), (xv - 20, yy)], fill=(255, 214, 64, int(70 * k3)), width=3)
            d.polygon([(xx, yy - 9), (xx + 16, yy), (xx, yy + 9)], fill=(255, 214, 64, int(230 * k3)))
        sg.stext(d, (W / 2, (top + bot) / 2), "熱", sg.F("YuGothB.ttc", 60 if not P else 64), (255, 214, 64, int(255 * k3)), anchor="mm")
    img.alpha_composite(bg)


# ---- 本編(横)----------------------------------------------------------------------------------------
CH = {}
CH["ch1"] = [
    dict(id="1-1", open="scene", text="南極の冬。気温は、マイナス40℃まで下がります。", say="なんきょくのふゆ。きおんは、マイナスよんじゅうどまで、さがります。", scene=V("c35990540", 2.0)),
    dict(id="1-2", text="風は秒速40メートル。強い台風と同じくらいです。", say="かぜは、びょうそく、よんじゅうメートル。つよいたいふうと、おなじくらいです。", scene=V("c6299773", 0.0)),
    dict(id="1-3", text="太陽は、ほとんど昇りません。", scene=V("c30443061", 14.0)),
    dict(id="1-4", text="その氷の上に、ペンギンが立っています。", scene=PH("p48814")),
    dict(id="1-5", text="コウテイペンギン。いちばん大きなペンギンです。", scene=PH("p36479784", "right")),
    dict(id="1-6", text="この寒さの中に立っているのは、オスです。", scene=PH("p31293895")),
    dict(id="1-7", text="足の上に、卵を1つ乗せています。", scene=PH("p36240733"), fx=[dict(k="note", xy=(W * 0.71, H * 0.86), text="この足の上に卵", on="足の上")]),
    dict(id="1-8", text="お腹の皮をかぶせて、卵を温めるのです。", fx=[dict(k="note", xy=(W * 0.74, H * 0.86), text="足", on="温める")]),
    dict(id="1-9", text="卵を温めるのは、オスだけの仕事です。", scene=PH("p35063543", "left")),
    dict(id="1-10", text="その間、何も食べません。", fx=[dict(k="dim", amount=0.4, on="食べません")]),
    dict(id="1-11", text="卵を待つ日々も合わせると、約115日。", say="たまごをまつひびもあわせると、やく、ひゃくじゅうごにち。",
         scene=dict(kind="bars", items=[dict(name="食べない日", value=115, unit="日")], max=130)),
    dict(id="1-12", text="4か月近く、食べずに氷の上に立ち続けます。", fx=[dict(k="add", ratio=dict(text="約4か月", sub="食べずに立つ"), on="4か月")]),
    dict(id="1-13", text="体重は38キロから、約23キロまで減ります。", say="たいじゅうは、さんじゅうはちキロから、やく、にじゅうさんキロまで、へります。",
         scene=dict(kind="bars", items=[dict(name="はじめ", value=38.2, unit="kg"), dict(name="終わり", value=22.75, unit="kg", label="約23kg", on="23")])),
    dict(id="1-14", text="体の【4割】が、なくなる計算です。", scene=dict(kind="words", rows=["体の", "【4割】がなくなる"], rows_on=[None, "4割"])),
    dict(id="1-15", text="ここで、1つ気になることがあります。", scene=PH("p36240733", "right")),
    dict(id="1-16", text="卵を乗せているのは、足です。", fx=[dict(k="note", xy=(W * 0.74, H * 0.86), text="足", on="足")]),
    dict(id="1-17", text="足の下は、氷です。", scene=V("c30443061", 4.0)),
    dict(id="1-18", text="4か月、氷の上に立って、足は凍らないのか。", scene=PH("p31293895", "left"),
         fx=[dict(k="q", xy=XY(0.5, 0.50), label="凍らない？", on="凍らない")]),
    dict(id="1-19", text="人の足なら、凍傷になる寒さです。", fx=[dict(k="dim", amount=0.4, on="凍傷")]),
    dict(id="1-20", text="今日は、体の温度を測った記録で確かめます。", scene=PH("p7859781")),
    dict(id="1-21", text="熱で写すカメラと、羽に付けた小さな温度計です。", fx=[dict(k="note", xy=(W * 0.5, H * 0.72), text="熱で写すカメラ", on="カメラ")]),
    dict(id="1-22", text="答えは、「寒さに強いから」ではありません。", scene=PH("p46235"), fx=[dict(k="dim", amount=0.35, on="ありません")]),
]
CH["ch2"] = [
    dict(id="2-1", text="まず、足の中の温度です。", scene=PH("p36240733", "left")),
    dict(id="2-2", text="1961年、研究者がペンギンの足の温度を測りました。", say="せんきゅうひゃくろくじゅういちねん、けんきゅうしゃが、ペンギンのあしのおんどを、はかりました。",
         scene=dict(kind="card", title="足の温度を測る", sub="1961年", body="足の中に温度計を当てて、温度を記録した。", src="Goldsmith & Sladen 1961")),
    dict(id="2-3", text="体の中は、37.5℃。", say="からだのなかは、さんじゅうななてんごど。", scene=dict(kind="custom", fn="thermo", credit="図: 理の書"),
         fx=[dict(k="step", n=1, on="37")]),
    dict(id="2-4", text="ところが足の中は、【0℃の少し上】しかありません。", say="ところが、あしのなかは、レイドの、すこしうえしか、ありません。", fx=[dict(k="step", n=2, on="0")]),
    dict(id="2-5", text="体より、30℃以上も冷たいのです。", say="からだより、さんじゅうどいじょうも、つめたいのです。", fx=[dict(k="note", xy=(W * 0.66, H * 0.42), text="差は30℃以上", on="30")]),
    dict(id="2-6", text="普通は、冷えた所に温かい血を送って温めるはず。", scene=PH("p15473260")),
    dict(id="2-7", text="ペンギンは、足をわざと冷たいままにしています。", fx=[dict(k="note", xy=(W * 0.25, H * 0.88), text="冷たいままの足", on="足")]),
    dict(id="2-8", text="しかけは、血管の並び方にあります。", scene=dict(kind="custom", fn="vessels", credit="図: 理の書（模式図）")),
    dict(id="2-9", text="足へ行く血管と、足から戻る血管。", fx=[dict(k="step", n=1, on="行く"), dict(k="step", n=2, on="戻る")]),
    dict(id="2-10", text="この2本が、ぴったり寄りそって走っています。", fx=[dict(k="note", xy=(W * 0.66, H * 0.48), text="ぴったり並ぶ", on="寄りそって")]),
    dict(id="2-11", text="行きの血は、体で温まっている。", fx=[dict(k="note", xy=(W * 0.36, H * 0.34), text="温かい", on="温まって")]),
    dict(id="2-12", text="戻りの血は、氷で冷えている。", fx=[dict(k="note", xy=(W * 0.64, H * 0.68), text="冷たい", on="冷えて")]),
    dict(id="2-13", text="並んで流れるうちに、【熱が行きから戻りへ】移ります。", fx=[dict(k="step", n=3, on="熱が")]),
    dict(id="2-14", text="温かいカップを握ると、手が温まるのと同じです。", scene=V("c40346446", 2.0)),
    dict(id="2-15", text="足に着くころには、行きの血はもう冷えています。", scene=dict(kind="custom", fn="vessels", credit="図: 理の書（模式図）"),
         fx=[dict(k="step", n=1, on="足に"), dict(k="step", n=2, on="足に"), dict(k="step", n=3, on="足に")]),
    dict(id="2-16", text="戻りの血は、体に入る前に温まっています。", fx=[dict(k="note", xy=(W * 0.64, H * 0.34), text="戻りは温まる", on="温まって")]),
    dict(id="2-17", text="熱は足の先まで行かずに、体の中で回るのです。", scene=PH("p36479784")),
    dict(id="2-18", text="だから足は、凍らないぎりぎりの温度で止まります。", scene=PH("p36240733", "right"),
         fx=[dict(k="note", xy=(W * 0.74, H * 0.86), text="足", on="凍らない")]),
    dict(id="2-19", text="冷たいけれど、凍らない。", scene=dict(kind="words", rows=["冷たいけれど、", "【凍らない】"], rows_on=[None, "凍らない"])),
    dict(id="2-20", text="足から、熱をほとんど捨てていないのです。", scene=PH("p15473260", "right")),
    dict(id="2-21", text="同じしくみは、翼の付け根にもあります。", scene=V("c9816871", 1.0)),
    dict(id="2-22", text="コウテイペンギンは、そこに走る動脈の数が、", scene=PH("p31293895", "right")),
    dict(id="2-23", text="ペンギンの中でいちばん多いのです。", fx=[dict(k="note", xy=(W * 0.40, H * 0.45), text="翼の付け根", on="いちばん")]),
    dict(id="2-24", text="では、足以外の体は、どうなっているのか。", scene=PH("p46235", "left"), fx=[dict(k="q", xy=XY(0.5, 0.50), label="体は？", on="足以外")]),
]
CH["ch3"] = [
    dict(id="3-1", text="2008年6月。南極は真冬です。", say="ニセンハチネン、ろくがつ。なんきょくは、まふゆです。", scene=V("c30443061", 10.0)),
    dict(id="3-2", text="フランスの基地の近くで、研究チームがカメラを構えました。",
         scene=dict(kind="map", view=(140, -60, 60, 0), to=(140, -66.7, 14, 20), place=("ポワント・ジェオロジー", "コウテイペンギンの繁殖地"))),
    dict(id="3-3", text="熱で写すカメラです。温かい所ほど明るく写ります。", scene=PH("p7859781", "right")),
    dict(id="3-4", text="撮ったのは、コウテイペンギンのオス40羽。", say="とったのは、コウテイペンギンの、オス、よんじゅうわ。", scene=PH("p48814", "left")),
    dict(id="3-5", text="そのときの気温は、平均マイナス17.6℃。", say="そのときのきおんは、へいきん、マイナス、じゅうななてんろくど。",
         scene=dict(kind="custom", fn="thermo", credit="図: 理の書"), fx=[dict(k="step", n=1, on="その"), dict(k="step", n=3, on="マイナス")]),
    dict(id="3-6", text="ペンギンの体の中は、37.5℃です。", say="ペンギンのからだのなかは、さんじゅうななてんごどです。", fx=[dict(k="note", xy=(W * 0.70, H * 0.20), text="体の中 37.5℃", on="37")]),
    dict(id="3-7", text="普通なら、ペンギンはまわりより温かく写るはず。", scene=PH("p36479784", "right")),
    dict(id="3-8", text="ところが背中の表面は、マイナス23.2℃。", say="ところが、せなかのひょうめんは、マイナス、にじゅうさんてんにど。",
         scene=dict(kind="custom", fn="thermo", credit="図: 理の書"),
         fx=[dict(k="step", n=1, on="ところが"), dict(k="step", n=3, on="ところが"), dict(k="step", n=4, on="マイナス")]),
    dict(id="3-9", text="まわりの空気より、【5℃以上冷たかった】のです。", say="まわりのくうきより、ごどいじょう、つめたかったのです。", fx=[dict(k="note", xy=(W * 0.62, H * 0.60), text="空気より5℃以上冷たい", on="5℃")]),
    dict(id="3-10", text="お腹の表面も、マイナス21.8℃。", say="おなかのひょうめんも、マイナス、ニジュウイッテンハチド。", scene=PH("p31293895")),
    dict(id="3-11", text="頭も、翼も、足も、0℃より下でした。", say="あたまも、つばさも、あしも、れいどより、したでした。", scene=PH("p36240733", "left")),
    dict(id="3-12", text="0℃を上回ったのは、目のまわりだけです。", say="れいどを、うわまわったのは、めのまわりだけです。", scene=PH("p41154370"),
         fx=[dict(k="note", xy=(W * 0.62, H * 0.40), text="目のまわり", on="目の")]),
    dict(id="3-13", text="なぜ、空気より冷たくなるのか。", scene=PH("p48814", "right"), fx=[dict(k="q", xy=XY(0.5, 0.45), label="なぜ？", on="なぜ")]),
    dict(id="3-14", text="答えは、空にあります。", scene=V("c6299773", 10.0)),
    dict(id="3-15", text="晴れた空は、空気よりさらに20℃以上冷たいことがあります。", say="はれたそらは、くうきより、さらに、にじゅうどいじょう、つめたいことがあります。", fx=[dict(k="note", xy=(W * 0.5, H * 0.25), text="空気より20℃以上冷たい空", on="20℃")]),
    dict(id="3-16", text="体の表面は、その冷たい空へ熱を出し続けます。", fx=[dict(k="dim", amount=0.3, on="出し続け")]),
    dict(id="3-17", text="ところが、中からの熱はほとんど届きません。", scene=PH("p46235")),
    dict(id="3-18", text="だから表面だけが、冷えたままになるのです。", fx=[dict(k="dim", amount=0.3, on="冷えた")]),
    dict(id="3-19", text="表面が冷たいのは、熱が漏れていない証拠です。", scene=dict(kind="words", rows=["表面が冷たい", "＝【熱が漏れていない】"], rows_on=[None, "漏れて"])),
    dict(id="3-20", text="37.5℃の体と、マイナス23℃の表面。", say="さんじゅうななてんごどのからだと、マイナス、にじゅうさんどの、ひょうめん。",
         scene=dict(kind="custom", fn="thermo", credit="図: 理の書"), fx=[dict(k="step", n=1, on="37"), dict(k="step", n=4, on="マイナス")]),
    dict(id="3-21", text="その差、約60℃を、羽の層が止めています。", say="そのさ、やくろくじゅうどを、はねのそうが、とめています。", fx=[dict(k="note", xy=(W * 0.70, H * 0.30), text="差 約60℃", on="60℃")]),
    dict(id="3-22", text="では、その羽はどれほど密なのか。", scene=PH("p41154370", "left")),
    dict(id="3-23", text="ペンギンは、鳥でいちばん羽が密だと言われてきました。", scene=PH("p15473260")),
    dict(id="3-24", text="2015年、コウテイペンギンの羽を数えた研究があります。", say="にせんじゅうごねん、コウテイペンギンのはねを、かぞえたけんきゅうがあります。",
         scene=dict(kind="card", title="羽を数える", sub="2015年", body="コウテイペンギンの羽を種類ごとに数え、1平方センチあたりの本数を出した。", src="Williams ほか 2015 Proc R Soc B")),
    dict(id="3-25", text="結果、表の羽の密度は、鳥でいちばんではありませんでした。", say="けっか、おもてのはねの、みつどは、とりで、いちばんではありませんでした。", scene=PH("p31293895", "left"), fx=[dict(k="dim", amount=0.35, on="いちばんでは")]),
    dict(id="3-26", text="1平方センチに、多くても約9本です。", say="イチヘイホウセンチに、おおくても、やく、きゅうほんです。",
         scene=dict(kind="bars", items=[dict(name="表の羽", value=9, unit="本")], max=40)),
    dict(id="3-27", text="決め手は、羽の根元に隠れていました。", scene=PH("p41154370")),
    dict(id="3-28", text="ふわふわの綿毛が、表の羽の【約4倍】の密度で生えていたのです。", say="ふわふわのわたげが、おもてのはねの、やくよんばいの、みつどで、はえていたのです。", scene=dict(kind="bars", items=[dict(name="表の羽", value=9, unit="本")], max=40),
         fx=[dict(k="add", item=dict(name="綿毛", value=36, unit="本", label="約4倍"), on="綿毛")]),
    dict(id="3-29", text="表の羽が風を止め、綿毛が空気をため込む。", say="おもてのはねが、かぜをとめ、わたげが、くうきをためこむ。", scene=PH("p36479784", "left")),
    dict(id="3-30", text="2枚重ねの服のような作りです。", fx=[dict(k="note", xy=(W * 0.5, H * 0.45), text="羽＋綿毛の2枚重ね", on="2枚")]),
    dict(id="3-31", text="それでも、何か月も外に立てば、熱は少しずつ減っていきます。", scene=V("c6299773", 4.0)),
]
CH["ch4"] = [
    dict(id="4-1", text="そこでペンギンは、集まります。", scene=PH("p46235")),
    dict(id="4-2", text="何百羽もが、体を押しつけ合って固まるのです。", fx=[dict(k="spot", box=BOX(0.0, 0.55, 1.0, 1.0), on="押しつけ")]),
    dict(id="4-3", text="研究チームは、8羽の羽に小さな記録計を付けました。", say="けんきゅうチームは、はちわの、はねに、ちいさな、きろくけいを、つけました。", scene=PH("p36479784", "right")),
    dict(id="4-4", text="群れの中の気温を、測るためです。", fx=[dict(k="note", xy=(W * 0.45, H * 0.45), text="羽に記録計", on="気温")]),
    dict(id="4-5", text="外は、マイナスの世界です。", scene=V("c30443061", 2.0)),
    dict(id="4-6", text="ところが群れの中は、最高で【37.5℃】まで上がりました。", say="ところが、むれのなかは、さいこうで、さんじゅうななてんごどまで、あがりました。",
         scene=dict(kind="words", rows=["群れの中は", "【最高37.5℃】"], rows_on=[None, "37"])),
    dict(id="4-7", text="ペンギンの体温と、ほとんど同じです。", scene=PH("p46235", "right")),
    dict(id="4-8", text="お風呂のお湯より、少しぬるいくらいです。", scene=V("c40346446", 5.0)),
    dict(id="4-9", text="でも、群れには外側と内側があります。", scene=PH("p48814"), fx=[dict(k="note", xy=(W * 0.30, H * 0.62), text="外側", on="外側")]),
    dict(id="4-10", text="外側のペンギンは、風に当たり続けます。", scene=V("c35990540", 8.0)),
    dict(id="4-11", text="ずっと外側では、凍えてしまいます。", fx=[dict(k="dim", amount=0.4, on="凍え")]),
    dict(id="4-12", text="ここで、群れが不思議な動きをします。", scene=V("c38709048", 1.0)),
    dict(id="4-13", text="30秒から60秒ごとに、全員が少しだけ前に進むのです。", say="さんじゅうびょうから、ろくじゅうびょうごとに、ぜんいんが、すこしだけ、まえにすすむのです。",
         scene=V("c38709050", 4.0)),
    dict(id="4-14", text="その一歩が、波のように群れを伝わっていきます。", fx=[dict(k="route", pts=[(W * 0.15, H * 0.70), (W * 0.85, H * 0.62)], label="波", dur=2.0, on="波")]),
    dict(id="4-15", text="1.3秒ごとの写真を4時間撮り続けて、見つかった動きです。", say="いってんさんびょうごとの、しゃしんを、よじかん、とりつづけて、みつかった、うごきです。",
         scene=dict(kind="card", title="群れの波", sub="2011年", body="1.3秒ごとの写真を4時間。30〜60秒ごとに、小さな一歩が波のように伝わる。", src="Zitterbart ほか 2011 PLoS ONE")),
    dict(id="4-16", text="波がくり返されるうちに、並びが少しずつ入れ替わります。", scene=PH("p46235", "left")),
    dict(id="4-17", text="外側にいたペンギンも、やがて内側に入れます。", fx=[dict(k="spot", box=BOX(0.25, 0.60, 0.75, 1.0), on="内側")]),
    dict(id="4-18", text="群れは、全員で順番に温まる仕組みなのです。", scene=PH("p15473260", "right")),
    dict(id="4-19", text="では、集まるとどれくらい得なのか。", scene=PH("p48814", "right"), fx=[dict(k="q", xy=XY(0.5, 0.55), label="どれくらい？", on="どれくらい")]),
    dict(id="4-20", text="小さな群れと比べると、使う力は約4分の1少なくてすみました。", say="ちいさなむれとくらべると、つかうちからは、やく、よんぶんのいち、すくなくて、すみました。",
         scene=dict(kind="bars", items=[dict(name="小さな群れ", value=100, unit=""), dict(name="大きな群れ", value=74, unit="", label="約4分の1少ない", on="4分の1")])),
    dict(id="4-21", text="群れなしでは、食べずにいられるのは約60日だけ。", say="むれなしでは、たべずにいられるのは、やく、ろくじゅうにちだけ。",
         scene=dict(kind="bars", items=[dict(name="群れなし", value=60, unit="日")], max=130)),
    dict(id="4-22", text="卵がかえるまで、もちません。", fx=[dict(k="add", item=dict(name="必要な日数", value=115, unit="日"), on="卵が")]),
    dict(id="4-23", text="集まることで、115日の絶食を乗り切っているのです。", say="あつまることで、ひゃくじゅうごにちの、ぜっしょくを、のりきっているのです。", scene=PH("p35063543")),
]
CH["ch5"] = [
    dict(id="5-1", text="ここで、もう1つの思い込みを外します。", scene=PH("p15473260")),
    dict(id="5-2", text="ペンギンは、寒い所の鳥だと思われがちです。", fx=[dict(k="dim", amount=0.3, on="思われ")]),
    dict(id="5-3", text="ところが、赤道の真下に住むペンギンがいます。", scene=dict(kind="map", view=(-80, -5, 60, 0), to=(-90.5, -0.5, 8, 20), place=("ガラパゴス諸島", "赤道の真下"))),
    dict(id="5-4", text="ガラパゴスペンギン。", scene=PH("p26559822")),
    dict(id="5-5", text="赤道より北にもいる、ただ1種のペンギンです。", fx=[dict(k="note", xy=(W * 0.50, H * 0.45), text="赤道より北にもいる", on="ただ1種")]),
    dict(id="5-6", text="陸の上は、強い日差しに焼かれます。", scene=PH("p18750732", "left")),
    dict(id="5-7", text="ここでの悩みは、寒さではありません。", scene=PH("p26559824"), fx=[dict(k="dim", amount=0.35, on="寒さでは")]),
    dict(id="5-8", text="熱がこもることです。", scene=dict(kind="words", rows=["悩みは寒さではなく", "【熱がこもること】"], rows_on=[None, "熱が"])),
    dict(id="5-9", text="暑くなると、犬と同じように口を開けて息をします。", scene=PH("p26559822", "right")),
    dict(id="5-10", text="翼を体から離して、風に当てます。", scene=PH("p27542252")),
    dict(id="5-11", text="そして前かがみになって、足に日陰を作ります。", scene=PH("p26559824", "right")),
    dict(id="5-12", text="足は血がたくさん流れて、熱が出入りしやすい所だからです。", fx=[dict(k="note", xy=(W * 0.62, H * 0.75), text="足に日陰", on="足は")]),
    dict(id="5-13", text="南極では、熱を逃がさないように絞っていた足。", scene=PH("p36240733", "left"), fx=[dict(k="note", xy=(W * 0.71, H * 0.86), text="南極: 熱を逃がさない足", on="絞って")]),
    dict(id="5-14", text="暑い所では、熱の出入り口として使っているのです。", scene=PH("p26559824", "left"), fx=[dict(k="note", xy=(W * 0.62, H * 0.75), text="赤道: 熱の出入り口", on="出入り口")]),
    dict(id="5-15", text="南アフリカのアフリカペンギンも、暑さと戦っています。", scene=V("c34400673", 2.0, place=("南アフリカ", "アフリカペンギン"))),
    dict(id="5-16", text="餌をとる海は、10〜20℃。", say="えさをとるうみは、じゅうどから、にじゅうど。", scene=V("c41078190", 2.0)),
    dict(id="5-17", text="ところが子育てをする陸は、30℃を超える日があります。", say="ところが、こそだてをする、りくは、さんじゅうどを、こえるひが、あります。", scene=PH("p30774926")),
    dict(id="5-18", text="目の上の【ピンクの肌】を見てください。", scene=PH("p27292768"), fx=[dict(k="note", xy=(W * 0.36, H * 0.38), text="ピンクの肌", on="ピンク")]),
    dict(id="5-19", text="暑いと、ここに血を多く流して熱を逃がします。", fx=[dict(k="spot", box=BOX(0.10, 0.18, 0.60, 0.62), on="血を")]),
    dict(id="5-20", text="同じペンギンでも、住む所で熱の扱い方が逆なのです。", scene=V("c15924326", 3.0)),
]
CH["ch6"] = [
    dict(id="6-1", text="ここまでを、まとめます。", scene=PH("p48814")),
    dict(id="6-2", text="足は、凍らないぎりぎりの温度に保つ。", scene=PH("p36240733"), fx=[dict(k="note", xy=(W * 0.74, H * 0.86), text="足", on="足")]),
    dict(id="6-3", text="羽と綿毛で、体の熱を外に出さない。", scene=PH("p41154370", "right")),
    dict(id="6-4", text="そして、群れで温め合う。", scene=PH("p46235", "left")),
    dict(id="6-5", answer=True, text="ペンギンは、寒さに強い体ではありませんでした。", scene=PH("p31293895"), fx=[dict(k="dim", amount=0.3, on="ありません")]),
    dict(id="6-6", text="熱を、ほとんど逃がさない体だったのです。", scene=dict(kind="words", rows=["寒さに強い体ではなく", "【熱を逃がさない体】"], rows_on=[None, "逃がさない"])),
    dict(id="6-7", text="実際、コウテイペンギンにも寒すぎる温度があります。", scene=PH("p36479784")),
    dict(id="6-8", text="マイナス10℃を下回ると、体を温めるために余分な力を使い始めます。", say="マイナスじゅうどを、したまわると、からだを、あたためるために、よぶんなちからを、つかいはじめます。",
         fx=[dict(k="note", xy=(W * 0.50, H * 0.40), text="マイナス10℃が境目", on="マイナス")]),
    dict(id="6-8b", text="南極の冬の寒さの、4分の1ほどの温度です。", say="なんきょくのふゆの、さむさの、よんぶんのいちほどの、おんどです。",
         scene=dict(kind="bars", items=[dict(name="冬の寒さ", value=40, unit="℃", label="−40℃"), dict(name="境目", value=10, unit="℃", label="−10℃", on="4分の1")])),
    dict(id="6-9", text="南極の冬は、それよりずっと寒い。", scene=V("c30443061", 20.0)),
    dict(id="6-10", text="だから、足・羽・群れの3段構えが要るのです。", scene=dict(kind="words", rows=["足・羽・群れの", "【3段構え】"], rows_on=[None, "3段"])),
    dict(id="6-11", text="冒頭の問いに戻ります。", scene=PH("p31293895", "left")),
    dict(id="6-12", text="4か月、氷の上に立って、足は凍らないのか。", scene=PH("p36240733", "right")),
    dict(id="6-13", text="凍りません。", fx=[dict(k="note", xy=(W * 0.74, H * 0.86), text="足", on="凍りません")]),
    dict(id="6-14", text="足の中は、0℃の少し上で止まっています。", say="あしのなかは、レイドの、すこしうえで、とまっています。", scene=dict(kind="custom", fn="thermo", credit="図: 理の書"), fx=[dict(k="step", n=2, on="0")]),
    dict(id="6-15", text="温かい血を、足の先まで届けない。", scene=dict(kind="custom", fn="vessels", credit="図: 理の書（模式図）"),
         fx=[dict(k="step", n=1, on="温かい"), dict(k="step", n=2, on="温かい"), dict(k="step", n=3, on="届けない")]),
    dict(id="6-16", text="だから、少ない熱で凍らずにすむのです。", scene=PH("p15473260")),
    dict(id="6-17", text="次に水族館でペンギンを見たら、足元を見てください。", scene=V("c34917783", 2.0)),
    dict(id="6-18", text="あの足には、熱を体へ戻す血管が走っています。", scene=V("c38709050", 10.0)),
]
TITLES = dict(ch1="氷の上で、4か月立ち続ける", ch2="足は、0℃の少し上", ch3="表面は、空気より冷たい",
              ch4="群れの中は、37.5℃", ch5="暑い国のペンギン", ch6="答え")
MAPS = dict(ch3=dict(lat0=-60, bases=[((115, -72, 165, -50), 4)]), ch5=dict(lat0=-3, bases=[((-100, -15, -70, 8), 5)]))

# ---- ショート(縦)--------------------------------------------------------------------------------------
SH = {}
SH["s1"] = [
    dict(id="1", open="scene", text="南極の冬、氷の上に4か月立ち続ける鳥がいます。", say="なんきょくのふゆ、こおりのうえに、よんかげつ、たちつづける、とりがいます。", scene=PH("p48814")),
    dict(id="2", text="コウテイペンギンのオスです。", scene=PH("p31293895")),
    dict(id="3", text="足の上に卵を乗せて、何も食べずに温めます。", scene=PH("p36240733"), fx=[dict(k="note", xy=(W * 0.5, H * 0.62), text="足の上に卵", on="足の上")]),
    dict(id="4", text="足の下は、氷です。", scene=V("c30443061", 4.0)),
    dict(id="5", text="足は、凍らないのか。", scene=PH("p36240733", "left"), fx=[dict(k="q", xy=(W * 0.5, H * 0.45), label="凍らない？", on="凍らない")]),
    dict(id="6", text="体の中は、37.5℃。", say="からだのなかは、さんじゅうななてんごど。", scene=dict(kind="custom", fn="thermo", credit="図: 理の書"), fx=[dict(k="step", n=1, on="37")]),
    dict(id="7", text="ところが足の中は、【0℃の少し上】しかありません。", say="ところが、あしのなかは、レイドの、すこしうえしか、ありません。", fx=[dict(k="step", n=2, on="0")]),
    dict(id="8", text="わざと、冷たいままにしているのです。", scene=PH("p15473260")),
    dict(id="8b", text="体との差は、お風呂のお湯と水道の水ほどの差です。", scene=dict(kind="words", rows=["体と足の差は", "【30℃以上】"], rows_on=[None, "お風呂"])),
    dict(id="9", text="しかけは、血管の並び方です。", scene=dict(kind="custom", fn="vessels", credit="図: 理の書（模式図）")),
    dict(id="10", text="足へ行く血管と、戻る血管が、寄りそって走ります。", fx=[dict(k="step", n=1, on="行く"), dict(k="step", n=2, on="戻る")]),
    dict(id="11", text="行きの温かい血から、戻りの冷たい血へ、熱が移る。", fx=[dict(k="step", n=3, on="熱が")]),
    dict(id="12", text="熱は足の先まで行かず、体の中で回ります。", scene=PH("p36479784")),
    dict(id="13", answer=True, text="だから足は、少ない熱で凍らずにすむのです。", scene=PH("p36240733", "right")),
]
SH["s2"] = [
    dict(id="1", open="belief", text="ペンギンは温かい。そう思いますよね。", scene=PH("p15473260")),
    dict(id="2", text="南極の冬、熱で写すカメラでコウテイペンギンを撮りました。", scene=PH("p7859781")),
    dict(id="3", text="気温は、マイナス17.6℃。", say="きおんは、マイナス、じゅうななてんろくど。", scene=dict(kind="custom", fn="thermo", credit="図: 理の書"), fx=[dict(k="step", n=3, on="マイナス")]),
    dict(id="4", text="ところが背中の表面は、マイナス23.2℃。", say="ところが、せなかのひょうめんは、マイナス、にじゅうさんてんにど。", fx=[dict(k="step", n=4, on="マイナス")]),
    dict(id="5", text="空気より、【5℃以上冷たかった】のです。", say="くうきより、ごどいじょう、つめたかったのです。", fx=[dict(k="note", xy=(W * 0.5, H * 0.55), text="5℃以上冷たい", on="5℃")]),
    dict(id="6", text="0℃を上回ったのは、目のまわりだけ。", say="れいどを、うわまわったのは、めのまわりだけ。", scene=PH("p41154370"), fx=[dict(k="note", xy=(W * 0.5, H * 0.40), text="目のまわり", on="目の")]),
    dict(id="7", text="なぜ、空気より冷たくなるのか。", scene=PH("p48814"), fx=[dict(k="q", xy=XY(0.5, 0.45), label="なぜ？", on="なぜ")]),
    dict(id="8", text="晴れた空は、空気より20℃以上冷たいことがあります。", say="はれたそらは、くうきより、にじゅうどいじょう、つめたいことがあります。", scene=V("c6299773", 10.0)),
    dict(id="9", text="表面は、その空へ熱を出し続けます。", fx=[dict(k="dim", amount=0.3, on="熱を")]),
    dict(id="10", text="なのに、中からの熱はほとんど届かない。", scene=PH("p46235")),
    dict(id="11", answer=True, text="表面が冷たいのは、熱が漏れていない証拠なのです。", scene=dict(kind="words", rows=["表面が冷たい", "＝【熱が漏れていない】"], rows_on=[None, "漏れて"])),
    dict(id="12", text="37.5℃の体との差、約60℃を、羽の層が止めています。", say="さんじゅうななてんごどの、からだとのさ、やくろくじゅうどを、はねのそうが、とめています。", scene=PH("p31293895")),
    dict(id="13", text="お風呂のお湯と、冷凍庫の中ほどの差です。", scene=dict(kind="words", rows=["体と表面の差", "【約60℃】"], rows_on=[None, "冷凍庫"])),
]
SH["s3"] = [
    dict(id="1", open="scene", text="吹雪の南極で、ペンギンが何百羽も固まっています。", scene=PH("p46235")),
    dict(id="2", text="羽に温度計を付けて、群れの中を測りました。", scene=PH("p36479784")),
    dict(id="3", text="外はマイナスの世界。", scene=V("c6299773", 12.0)),
    dict(id="4", text="ところが群れの中は、最高で【37.5℃】。", say="ところが、むれのなかは、さいこうで、さんじゅうななてんごど。", scene=dict(kind="words", rows=["群れの中は", "【最高37.5℃】"], rows_on=[None, "37"])),
    dict(id="5", text="ペンギンの体温と同じくらいです。", scene=PH("p46235", "right")),
    dict(id="6", text="でも、外側のペンギンは風に当たり続けます。", scene=V("c35990540", 8.0)),
    dict(id="7", text="外側は、ずっと寒いままなのか。", scene=PH("p48814"), fx=[dict(k="q", xy=XY(0.4, 0.60), label="外側は？", on="外側")]),
    dict(id="8", text="30秒から60秒ごとに、全員が少しだけ前に進みます。", say="さんじゅうびょうから、ろくじゅうびょうごとに、ぜんいんが、すこしだけ、まえにすすみます。", scene=V("c38709050", 4.0)),
    dict(id="9", text="その一歩が、波のように群れを伝わる。", scene=V("c38709048", 1.0)),
    dict(id="10", answer=True, text="くり返すうちに、外側のペンギンも内側に入れるのです。", scene=PH("p46235", "left")),
    dict(id="11", text="群れなしなら、食べずにいられるのは約60日。", say="むれなしなら、たべずにいられるのは、やく、ろくじゅうにち。", scene=dict(kind="bars", items=[dict(name="群れなし", value=60, unit="日")], max=130)),
    dict(id="12", text="集まることで、115日の絶食を乗り切ります。", say="あつまることで、ひゃくじゅうごにちの、ぜっしょくを、のりきります。", fx=[dict(k="add", item=dict(name="群れで", value=115, unit="日"), on="115")]),
]
SH["s4"] = [
    dict(id="1", open="belief", text="ペンギンは、寒い所の鳥。そう思っていませんか。", scene=PH("p15473260")),
    dict(id="2", text="ところが、赤道の真下に住むペンギンがいます。", scene=PH("p26559822")),
    dict(id="3", text="ガラパゴスペンギン。赤道より北にもいる、ただ1種のペンギンです。", scene=PH("p26559824")),
    dict(id="4", text="ここでの悩みは、寒さではありません。", scene=PH("p18750732"), fx=[dict(k="dim", amount=0.35, on="寒さでは")]),
    dict(id="5", text="熱がこもることです。", scene=dict(kind="words", rows=["悩みは寒さではなく", "【熱がこもること】"], rows_on=[None, "熱が"])),
    dict(id="6", text="暑くなると、犬と同じように口を開けて息をします。", scene=PH("p26559822", "right")),
    dict(id="7", text="翼を体から離して、風に当てます。", scene=PH("p27542252")),
    dict(id="8", text="そして前かがみになって、足に日陰を作ります。", scene=PH("p26559824", "right")),
    dict(id="9", answer=True, text="足は血がたくさん流れて、熱が出入りしやすい所だからです。", fx=[dict(k="note", xy=(W * 0.5, H * 0.60), text="足に日陰", on="足は")]),
    dict(id="10", text="南極のペンギンは、足から熱を逃がさないように絞ります。", scene=PH("p36240733")),
    dict(id="11", text="同じ足を、赤道では熱の出入り口に使っているのです。", scene=PH("p26559822", "left")),
]
STITLES = dict(s1="ペンギンの足は、なぜ凍らない", s2="ペンギンの表面は、空気より冷たい", s3="ペンギンの群れの中は37.5℃", s4="赤道の真下にいるペンギン")


def ep_for(key: str) -> dict:
    if key.startswith("ch"):
        d = dict(kind="stage", title=TITLES[key], qtag=QTAG, colors=COLORS, lines=CH[key])
        if key in MAPS:
            d["map"] = MAPS[key]
        return d
    return dict(kind="stage", title=STITLES[key], qtag=STITLES[key], colors=COLORS, lines=SH[key])
