"""タコの回(2026-11-21 台本 第2稿)の台本と画面。本編 ch1〜ch6(横)とショート s1〜s5(縦)の ep.py がここを読む。
台本の正は 台本.md。数字の出どころは 台本.md の「出どころ」。画面の作りは naze/stage.py の冒頭。

素材は assets/stock/(git に入れない。sources.json の id で取り直す: python tools/media.py get-v <id> episodes/tako <名前>.mp4)。
AI の絵は make_illust.py(右上に「イメージ(AI で作成)」)。
"""
import math

import cv2
import numpy as np
from PIL import Image, ImageDraw

from naze import stage as sg

W, H, P = sg.W, sg.H, sg.PORTRAIT
QTAG = "タコは本当に、宇宙から来たのか"
COLORS = {"人": (255, 170, 90), "タコ": (120, 200, 255)}


def S(name):
    return f"assets/stock/{name}"


def V(name, start=0.0, speed=1.0, cx=0.5, place=None, **kw):
    d = dict(kind="video", src=S(name + ".mp4"), start=start, speed=speed, cx=cx, **kw)
    if place:
        d["place"] = place
    return d


def PH(name, move="in", place=None):
    d = dict(kind="photo", src=S(name), move=move)
    if place:
        d["place"] = place
    return d


def XY(fx, fy, cx=0.5):
    """横長(16:9)の素材の中の位置(0〜1)を、画面の座標に直す(縦は cover で切った後)。"""
    if not P:
        return (fx * W, fy * H)
    sw = H * 16 / 9
    x0 = min(max(sw * cx - W / 2, 0), sw - W)
    return (fx * sw - x0, fy * H)


def BOX(fx0, fy0, fx1, fy1, cx=0.5):
    a, b = XY(fx0, fy0, cx), XY(fx1, fy1, cx)
    return (max(0, a[0]), max(0, a[1]), min(W, b[0]), min(H, b[1]))


# ---- 3 つの心臓の図(実写のタコの上に、心臓と血の流れの層を重ねる)-----------------------------------
def draw_hearts(img: Image.Image, t: float, c) -> None:
    """step 1=えらの心臓 2 つ 2=全身の心臓 3=血が回る(青い粒が流れる)。下地は実写のタコ(暗くする)。"""
    steps = {f["n"]: c.when(f) for f in c.seg["fx"] if f["k"] == "step"}

    def k(n, d=0.6):
        return sg.ease((t - steps.get(n, 1e9)) / d)
    f = c.st.media.frame(S("oct_coral.mp4"), 0.5 + t * 0.6, 0.45)
    base = (sg.grade(f).astype(np.float32) * 0.42).astype(np.uint8)
    im = Image.fromarray(base).convert("RGBA")
    lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay, "RGBA")
    cx, cy = W / 2, H * (0.44 if P else 0.47)
    sp = W * (0.30 if P else 0.20)
    gl, gr, sy = (cx - sp, cy - 40), (cx + sp, cy - 40), (cx, cy + (200 if P else 150))
    body = (cx, cy + (430 if P else 330))
    fL = sg.F("YuGothB.ttc", 40 if P else 36)
    BLUE = (110, 180, 255)

    def heart(p, r, a, col):
        for i in range(6, 0, -1):
            d.ellipse([p[0] - r - i * 8, p[1] - r - i * 8, p[0] + r + i * 8, p[1] + r + i * 8], fill=col + (int(a * 14),))
        d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=col + (int(a * 230),), outline=(255, 255, 255, int(a * 200)), width=3)
    puls = 1 + 0.08 * max(0.0, math.sin(t * 6.0))
    k1, k2, k3 = k(1), k(2), k(3)
    # 流れの道(体 → えらの心臓 → えら → 全身の心臓 → 体)
    if k3 > 0:
        path = [body, (gl[0], body[1] - 40), gl, (gl[0], gl[1] - 160), (cx, gl[1] - 220), (gr[0], gr[1] - 160), gr, (gr[0], body[1] - 40), sy, body]
        for a_, b_ in zip(path, path[1:]):
            d.line([a_, b_], fill=BLUE + (int(90 * k3),), width=6)
        L = [math.dist(a_, b_) for a_, b_ in zip(path, path[1:])]
        tot = sum(L)
        for j in range(18):
            s = ((t - steps[3]) * 260 + j * tot / 18) % tot
            for (a_, b_), l in zip(zip(path, path[1:]), L):
                if s <= l:
                    u = s / max(l, 1)
                    x, y = a_[0] + (b_[0] - a_[0]) * u, a_[1] + (b_[1] - a_[1]) * u
                    d.ellipse([x - 9, y - 9, x + 9, y + 9], fill=(150, 210, 255, int(230 * k3)))
                    break
                s -= l
    if k1 > 0:
        for p in (gl, gr):
            heart(p, 34 * (puls if k3 > 0 else 1), k1, (90, 150, 255))
        sg.stext(d, (gl[0], gl[1] + 80), "えらの心臓", fL, (200, 225, 255, int(255 * k1)), anchor="mm")
        sg.stext(d, (gr[0], gr[1] + 80), "えらの心臓", fL, (200, 225, 255, int(255 * k1)), anchor="mm")
    if k2 > 0:
        heart(sy, 52 * (puls if k3 > 0 else 1), k2, (70, 120, 255))
        sg.stext(d, (sy[0], sy[1] + 105), "全身へ送る心臓", fL, (200, 225, 255, int(255 * k2)), anchor="mm")
    im.alpha_composite(lay)
    img.alpha_composite(im)


HEART_GILL = (80, 700, 1000, 920) if P else (430, 380, 1490, 585)
HEART_MAIN = (380, 975, 700, 1195) if P else (780, 590, 1140, 805)


# ---- 本編(横)----------------------------------------------------------------------------------------
def camo_spot(cx=0.5):
    return BOX(0.33, 0.24, 0.68, 0.88, cx)


CH = {}
CH["ch1"] = [
    dict(id="1-1", open="scene", text="この岩の中に、タコが1匹います。", scene=V("camo2", 0.0, 0.7)),
    dict(id="1-2", text="見つかりましたか。", fx=[dict(k="q", xy=XY(0.5, 0.45), label="", on="見つかり")]),
    dict(id="1-3", text="正解は、ここです。", fx=[dict(k="spot", box=camo_spot(), on="ここ")]),
    dict(id="1-4", text="色だけでなく、模様まで岩に合わせています。", scene=V("camo1", 0.5)),
    dict(id="1-5", text="この生き物が宇宙から来た、と書いた論文があります。", scene=V("oct_eye", 1.0)),
    dict(id="1-6", text="2018年。書いたのは、【33人】の科学者です。", say="にせんじゅうハチねん。かいたのは、さんじゅうさんにんの、かがくしゃです。",
         scene=dict(kind="card", title="Cause of Cambrian Explosion", sub="2018年", body="カンブリア爆発の原因は、地球か宇宙か。著者33人。",
                    src="Progress in Biophysics and Molecular Biology 136巻")),
    dict(id="1-7", text="学校の1クラスと、同じくらいの人数です。", scene=PH("classroom.jpg")),
    dict(id="1-8", text="タコの卵が、凍ったまま宇宙から来た。", scene=PH("ai_comet1.jpg", "left")),
    dict(id="1-9", text="氷の天体に乗って、地球に届いたというのです。", fx=[dict(k="note", xy=(W * 0.45, H * 0.42), text="氷の天体（イメージ）", on="氷の天体")]),
    dict(id="1-10", text="冗談ではなく、学術誌に載った論文です。", scene=dict(kind="words", rows=["冗談ではなく、", "【学術誌に載った論文】"], rows_on=[None, "学術誌"])),
    dict(id="1-11", text="論文が挙げた理由は、2つ。", scene=V("dna", 0.0)),
    dict(id="1-12", text="タコの遺伝子は、人より多い。", fx=[dict(k="note", xy=(W * 0.55, H * 0.40), text="理由1　遺伝子の数", on="遺伝子")]),
    dict(id="1-13", text="そしてタコは、約2億7千万年前に急に現れた。", say="そしてタコは、やくにおくななせんまんねんまえに、きゅうにあらわれた。",
         scene=V("ocean", 0.5), fx=[dict(k="q", xy=(W * 0.5, H * 0.42), label="急に現れた？", on="急に")]),
    dict(id="1-14", text="別の道すじも書かれています。", scene=V("space", 0.5)),
    dict(id="1-15", text="宇宙のウイルスが、遺伝子を運び込んだ。", fx=[dict(k="note", xy=(W * 0.5, H * 0.40), text="宇宙のウイルス？", on="ウイルス")]),
    dict(id="1-16", text="それで、イカがタコに変わったというのです。", scene=V("squid", 5.0)),
    dict(id="1-17", text="たしかにタコの体には、そう思わせる所があります。", scene=V("oct_skin", 3.0)),
    dict(id="1-18", text="今日は、その証拠を5つ、順に見ていきます。", scene=dict(kind="words", rows=["宇宙から来た証拠？", "【5つ】を見ていく"], rows_on=[None, "5つ"])),
    dict(id="1-19", text="最後に、遺伝子と化石が出した答えを見ます。", scene=PH("ai_shell1.jpg", "right")),
    dict(id="1-20", text="答えは、「宇宙人ではなかった」では終わりません。", fx=[dict(k="dim", on="終わりません")]),
]
CH["ch2"] = [
    dict(id="2-1", text="1つ目の証拠は、さっきの変身です。", scene=V("camo1", 2.0)),
    dict(id="2-2", text="色を変える動物は、ほかにもいます。", fx=[dict(k="dim", amount=0.35, on="ほかにも")]),
    dict(id="2-3", text="けれどタコの仲間の変え方は、別格です。", scene=V("oct_skin", 20.0)),
    dict(id="2-4", text="2015年の遺伝子の論文も、", say="にせんじゅうごねんの、いでんしのろんぶんも、", scene=V("dna", 3.0)),
    dict(id="2-5", text="動物の中でいちばん高度だと書いています。", fx=[dict(k="note", xy=(W * 0.5, H * 0.40), text="Nature 2015", on="いちばん")]),
    dict(id="2-6", text="皮膚には、色の入った小さな袋が並んでいます。", scene=V("oct_skin", 40.0, cx=0.45)),
    dict(id="2-7", text="筋肉で袋を広げたり縮めたりして、模様を描きます。", fx=[dict(k="note", xy=XY(0.40, 0.55, 0.45), text="色の袋", on="筋肉")]),
    dict(id="2-8", text="ここで、ひとつ謎があります。", scene=V("oct_eye2", 2.0)),
    dict(id="2-9", text="タコの目は、【色を見分けられません】。", fx=[dict(k="spot", box=BOX(0.40, 0.48, 0.60, 0.82), on="目は")]),
    dict(id="2-10", text="光を感じる色素が、目に1種類しかないのです。", scene=dict(kind="words", rows=["目の色素は、", "【1種類だけ】"], rows_on=[None, "1種類"])),
    dict(id="2-11", text="色が見えないのに、なぜ周りの色に化けられるのか。", scene=V("camo2", 2.0, 0.6),
         fx=[dict(k="q", xy=XY(0.5, 0.45), label="なぜ化けられる？", on="なぜ")]),
    dict(id="2-12", text="手がかりは、目ではなく皮膚にありました。", scene=V("oct_skin", 50.0)),
    dict(id="2-13", text="2015年、アメリカの研究チームが、", say="にせんじゅうごねん、アメリカの、けんきゅうチームが、", scene=V("lab", 1.0, place=("カリフォルニア大学サンタバーバラ校", "2015年の実験"))),
    dict(id="2-14", text="タコの皮膚だけを切り取って、光を当てました。", scene=PH("petri.jpg")),
    dict(id="2-15", text="目にも脳にも、つながっていない皮膚です。", fx=[dict(k="note", xy=(W * 0.55, H * 0.45), text="皮膚だけ", on="つながって")]),
    dict(id="2-16", text="すると、色の袋が【ひとりでに】広がったのです。", scene=V("oct_skin", 10.0)),
    dict(id="2-17", text="いちばんよく反応したのは、青い光でした。", fx=[dict(k="note", xy=(W * 0.5, H * 0.35), text="青い光（480nm）", on="青い光")]),
    dict(id="2-18", text="皮膚には、目と同じしくみのたんぱく質がありました。", scene=dict(kind="card", title="オプシン", sub="光を感じるたんぱく質",
         body="目で光を感じるのと同じ仲間。タコの皮膚の神経にも見つかった。", src="Ramirez & Oakley 2015")),
    dict(id="2-19", text="タコは、皮膚でも光を感じているのです。", scene=V("oct_dark", 3.0)),
    dict(id="2-20", text="ただ、生きたタコがこれをどう使っているのかは、", scene=V("camo1", 5.0)),
    dict(id="2-21", text="まだわかっていません。", fx=[dict(k="q", xy=XY(0.55, 0.45), label="まだ謎", on="まだ")]),
    dict(id="2-22", text="目は色が見えず、皮膚が光を感じる。", scene=V("oct_eye", 6.0)),
    dict(id="2-23", text="たしかに、私たちの知る動物とは違います。", fx=[dict(k="dim", amount=0.35, on="違います")]),
]
CH["ch3"] = [
    dict(id="3-1", text="2つ目の証拠は、体の中にあります。", scene=V("oct_coral", 0.5)),
    dict(id="3-2", text="タコの心臓は、【3つ】。", scene=dict(kind="custom", fn="hearts", credit="映像: JUN HO LEE / Pexels　図: 理の書"),
         fx=[dict(k="step", n=1, on="3つ"), dict(k="step", n=2, on="3つ")]),
    dict(id="3-3", text="2つは、えらの根もとに1つずつ。", fx=[dict(k="spot", box=HEART_GILL, on="えら")]),
    dict(id="3-4", text="体から戻った血を、えらへ押し込みます。", fx=[dict(k="step", n=3, on="押し込み")]),
    dict(id="3-5", text="残りの1つが、全身へ血を送る心臓です。", fx=[dict(k="spot", box=HEART_MAIN, on="全身")]),
    dict(id="3-6", text="そして、その血は【青い】。", scene=V("oct_dark", 10.0)),
    dict(id="3-7", text="人の血は、鉄で酸素を運ぶので赤い。", scene=dict(kind="split", left=dict(src=S("human_eye.mp4"), name="人", start=2.0),
                                                                     right=dict(src=S("oct_dark.mp4"), name="タコ", start=12.0))),
    dict(id="3-8", text="タコの血は、銅で運ぶので青いのです。", fx=[dict(k="focus", name="タコ", on="銅")]),
    dict(id="3-9", text="なぜ、心臓が3つも要るのか。", scene=V("oct_crawl", 1.0), fx=[dict(k="q", xy=XY(0.45, 0.5), label="なぜ3つ？", on="なぜ")]),
    dict(id="3-10", text="答えは、この青い血の弱さにありました。", scene=dict(kind="card", title="ヘモシアニン", sub="タコの血で酸素を運ぶたんぱく質",
         body="鉄ではなく銅を使い、酸素と結びつくと青くなる。", src="Oellermann ほか 2015")),
    dict(id="3-11", text="血1リットルが運べる酸素は、人の約【15分の1】。", say="ちいちリットルがはこべるさんそは、ひとの、やくじゅうごぶんのいち。",
         scene=dict(kind="bars", items=[dict(name="人", value=9.3, unit="ミリモル")]),
         fx=[dict(k="add", item=dict(name="タコ", value=0.61, unit="ミリモル", label="0.61ミリモル"), on="人の"), dict(k="add", ratio=dict(text="15分の1", sub="しか運べない"), on="15分")]),
    dict(id="3-12", text="人の血1リットルぶんの酸素を運ぶには、", scene=PH("bottles.jpg")),
    dict(id="3-13", text="タコの血が、約15リットル要ります。", fx=[dict(k="note", xy=(W * 0.5, H * 0.40), text="約15リットル", on="15リットル")]),
    dict(id="3-14", text="2リットルのペットボトルで、7本半です。", fx=[dict(k="dim", amount=0.3, on="7本半")]),
    dict(id="3-15", text="しかもタコは、休んでいるときでも、", scene=V("oct_eye2", 6.0)),
    dict(id="3-16", text="血の酸素を83%使い切っています。", say="ちのさんそを、はちじゅうさんパーセント、つかいきっています。",
         scene=dict(kind="bars", items=[dict(name="使った酸素", value=83, unit="%")], max=100)),
    dict(id="3-17", text="余りが、ほとんどないのです。", fx=[dict(k="add", ratio=dict(text="残り17%", sub="余りがない"), on="余り")]),
    dict(id="3-18", text="タコを20分間、動かし続けた実験があります。", scene=V("oct_rock", 1.0)),
    dict(id="3-19", text="酸素を使う量は、2.8倍に増えました。", say="さんそをつかうりょうは、にてんハチばいに、ふえました。",
         scene=dict(kind="bars", items=[dict(name="休む", value=1.0, unit="倍")]), fx=[dict(k="add", item=dict(name="動く", value=2.8, unit="倍"), on="2.8")]),
    dict(id="3-20", text="それを支えたのは、心臓が送る血の量。", scene=dict(kind="custom", fn="hearts", credit="映像: JUN HO LEE / Pexels　図: 理の書"),
         fx=[dict(k="step", n=1, on="それを"), dict(k="step", n=2, on="それを"), dict(k="step", n=3, on="心臓")]),
    dict(id="3-21", text="約2.5倍に増えていました。", say="やくにてんごばいに、ふえていました。", scene=dict(kind="bars", items=[dict(name="休む", value=1.0, unit="倍")]),
         fx=[dict(k="add", item=dict(name="動く", value=2.5, unit="倍"), on="2.5")]),
    dict(id="3-22", text="少ない酸素を、たくさん回して補う。", scene=V("oct_coral", 3.0)),
    dict(id="3-23", text="3つの心臓は、そのための作りです。", fx=[dict(k="note", xy=XY(0.5, 0.4, 0.5), text="心臓3つ", on="3つ")]),
    dict(id="3-24", text="ところが、この心臓には弱点があります。", scene=V("oct_rock", 7.0)),
    dict(id="3-25", text="タコが水を吹き出して、勢いよく泳ぐと、", scene=V("oct_rock", 13.0)),
    dict(id="3-26", text="全身へ送る心臓の拍動が、【途切れる】のです。", fx=[dict(k="dim", on="途切れる")]),
    dict(id="3-27", text="泳ぐたびに、心臓が止まりかける生き物。", scene=dict(kind="words", rows=["泳ぐたびに、", "【心臓が止まりかける】"], rows_on=[None, "心臓"])),
    dict(id="3-28", text="これも、宇宙人らしい証拠に見えます。", scene=V("oct_skin", 30.0)),
]
CH["ch4"] = [
    dict(id="4-1", text="3つ目の証拠は、腕です。", scene=V("oct_crawl", 4.0)),
    dict(id="4-2", text="タコの神経は、全部で約4億7千万。", say="タコのしんけいは、ぜんぶで、やくよんおくななせんまん。", scene=V("oct_dark", 18.0)),
    dict(id="4-3", text="頭の脳にあるのは、そのうち約5千万。", say="あたまののうにあるのは、そのうち、やくごせんまん。",
         scene=dict(kind="bars", items=[dict(name="頭の脳", value=0.5, unit="億")], max=3.2)),
    dict(id="4-4", text="腕には、約【3億】。", say="うでには、やくさんおく。", fx=[dict(k="add", item=dict(name="腕", value=3.0, unit="億"), on="3億")]),
    dict(id="4-5", text="頭の脳の、約6倍です。", fx=[dict(k="add", ratio=dict(text="約6倍", sub="腕のほうが多い"), on="6倍")]),
    dict(id="4-6", text="神経の6割以上が、腕にあるのです。", scene=V("oct_crawl", 6.0)),
    dict(id="4-7", text="その腕は、頭の命令を待たずに動きます。", scene=V("oct_rock", 2.0)),
    dict(id="4-8", text="脳とのつながりを切った腕でも、", scene=V("lab", 8.0)),
    dict(id="4-9", text="伸ばす動きは、ふだんとほぼ同じでした。", scene=V("oct_coral", 5.0)),
    dict(id="4-10", text="体から離れた腕は、【1時間】以上、", scene=V("oct_dark", 22.0)),
    dict(id="4-11", text="近くのものをつかみ続けます。", fx=[dict(k="note", xy=XY(0.40, 0.80), text="吸盤", on="つかみ")]),
    dict(id="4-12", text="ところが、どうしてもつかまないものがあります。", scene=V("oct_eye", 9.0), fx=[dict(k="q", xy=XY(0.55, 0.45), label="つかまないもの", on="つかまない")]),
    dict(id="4-13", text="タコ自身の、皮膚です。", scene=V("oct_skin", 45.0)),
    dict(id="4-14", text="研究チームは、タコの皮膚をぬったお皿で試しました。", scene=PH("petri.jpg", "left")),
    dict(id="4-15", text="吸盤は、そのお皿をほとんどつかみませんでした。", fx=[dict(k="dim", amount=0.4, on="ほとんど")]),
    dict(id="4-16", text="皮膚の中の何かが、つかむ反射を止めているのです。", scene=V("oct_skin", 25.0)),
    dict(id="4-17", text="だから、8本の腕はからまりません。", scene=V("oct_crawl", 2.0)),
    dict(id="4-18", text="その物質の正体は、まだわかっていません。", fx=[dict(k="q", xy=XY(0.5, 0.45), label="正体は？", on="正体")]),
    dict(id="4-19", text="吸盤には、味を感じるしくみまであります。", scene=V("oct_dark", 26.0)),
    dict(id="4-20", text="タコは、さわったものを腕で味わっているのです。", fx=[dict(k="note", xy=XY(0.40, 0.80), text="吸盤で味わう", on="味わって")]),
    dict(id="4-21", text="腕の1本1本が、小さな頭のように動く。", scene=V("oct_rock", 4.0)),
    dict(id="4-22", text="私たちとは、まるで違う体です。", fx=[dict(k="dim", amount=0.35, on="まるで")]),
]
CH["ch5"] = [
    dict(id="5-1", text="4つ目の証拠は、道具です。", scene=V("oct_sand", 1.0)),
    dict(id="5-2", text="舞台は、インドネシアの海の底。", scene=dict(kind="map", view=(118, -2, 40, 0), to=(119.5, -3.5, 22, 20), place=("インドネシア", "研究チームが潜った海"))),
    dict(id="5-3", text="研究チームが潜った時間は、合わせて500時間。", say="けんきゅうチームがもぐったじかんは、あわせて、ごひゃくじかん。", scene=V("ocean", 2.0)),
    dict(id="5-4", text="その海で、奇妙なタコが見つかりました。", scene=V("oct_sand", 8.0)),
    dict(id="5-5", text="【ココナッツの殻】を、抱えて歩いていたのです。", scene=PH("ai_coconut1.jpg")),
    dict(id="5-5b", text="名前は、メジロダコといいます。", fx=[dict(k="note", xy=(W * 0.45, H * 0.45), text="メジロダコ", on="メジロダコ")]),
    dict(id="5-6", text="人が海に捨てた、半分に割れた殻です。", scene=PH("coconut.jpg")),
    dict(id="5-7", text="タコは2つの殻を重ねて、体の下に抱えます。", scene=PH("ai_coconut1.jpg", "left")),
    dict(id="5-8", text="8本の腕を竹馬のように突っ張って、歩くのです。", fx=[dict(k="note", xy=(W * 0.40, H * 0.70), text="腕が竹馬", on="竹馬")]),
    dict(id="5-9", text="遠いものは、20メートルも運んでいました。", say="とおいものは、にじゅうメートルも、はこんでいました。", scene=V("oct_sand", 14.0)),
    dict(id="5-10", text="25メートルプールの、8割ほどの距離です。", say="にじゅうごメートルプールの、はちわりほどの、きょりです。", scene=PH("pool.jpg")),
    dict(id="5-11", text="歩きにくそうなのに、なぜ持ち歩くのか。", scene=V("oct_sand", 18.0), fx=[dict(k="q", xy=XY(0.55, 0.40), label="なぜ持ち歩く？", on="なぜ")]),
    dict(id="5-12", text="危ないとき、2つの殻を合わせて中に隠れるのです。", scene=PH("coconut.jpg", "right")),
    dict(id="5-13", text="その場では役に立たない物を、あとのために運ぶ。", scene=PH("ai_coconut1.jpg", "right")),
    dict(id="5-14", text="研究チームは、これを道具の使用だと報告しました。", scene=dict(kind="card", title="道具を使うタコ", sub="2009年",
         body="殻を運び、あとで隠れ家にする。その場で役に立たない物を運ぶので、道具の使用と報告された。", src="Finn ほか 2009 Current Biology")),
    dict(id="5-15", text="タコは、道具を使う動物の仲間入りをしたのです。", scene=V("oct_eye", 12.0)),
    dict(id="5-15b", text="背骨のない動物では、ほとんど例のない発見でした。", scene=dict(kind="words", rows=["背骨のない動物では、", "【ほとんど例がない】"], rows_on=[None, "ほとんど"])),
    dict(id="5-16", text="色が見えないのに化ける。", scene=V("camo2", 4.0, 0.6)),
    dict(id="5-17", text="泳ぐと止まる心臓。考える腕。そして道具。", scene=V("oct_crawl", 3.0)),
    dict(id="5-18", text="ここまで来ると、宇宙説も笑えなくなってきます。", scene=PH("ai_comet1.jpg", "right")),
]
CH["ch6"] = [
    dict(id="6-1", text="最後の証拠は、論文が挙げた遺伝子です。", scene=V("dna", 1.0)),
    dict(id="6-2", text="2015年、タコの遺伝子がすべて読まれました。", say="にせんじゅうごねん、タコのいでんしが、すべてよまれました。", scene=V("lab", 12.0)),
    dict(id="6-3", text="数は、3万3,638個。", say="かずは、さんまんさんぜんろっぴゃくさんじゅうはっこ。", scene=dict(kind="words", rows=["遺伝子の数", "【3万3,638個】"], rows_on=[None, "3万"])),
    dict(id="6-4", text="たしかに、人より多い。", scene=V("oct_eye2", 4.0)),
    dict(id="6-5", text="けれど、中身を一つずつ見ると、", scene=V("dna", 5.0)),
    dict(id="6-6", text="体や神経を作る遺伝子のそろいは、", fx=[dict(k="note", xy=(W * 0.5, H * 0.40), text="体と神経の遺伝子", on="神経")]),
    dict(id="6-7", text="ほかの背骨のない動物と、ほぼ同じでした。", scene=V("squid", 6.0)),
    dict(id="6-8", text="多かったのは、決まった家族の遺伝子です。", scene=V("oct_skin", 35.0)),
    dict(id="6-9", text="たとえば、神経どうしをつなぐ遺伝子。", scene=dict(kind="bars", items=[dict(name="タコ", value=168, unit="個")])),
    dict(id="6-10", text="タコは【168個】。人は58個。", say="タコは、ひゃくろくじゅうはっこ。ひとは、ごじゅうはっこ。", fx=[dict(k="add", item=dict(name="人", value=58, unit="個"), on="人は")]),
    dict(id="6-11", text="人の、約3倍です。", fx=[dict(k="add", ratio=dict(text="約3倍", sub="タコのほうが多い"), on="3倍")]),
    dict(id="6-12", text="同じ貝の仲間のカキやカサガイは、17〜25個です。", say="おなじかいのなかまの、カキやカサガイは、じゅうななから、にじゅうごこです。",
         fx=[dict(k="add", item=dict(name="カキ・カサガイ", value=21, unit="個", label="17〜25個"), on="カキ")]),
    dict(id="6-13", text="地球の動物と同じ遺伝子を、", scene=V("oct_coral", 2.0)),
    dict(id="6-14", text="タコは大きく増やしていたのです。", fx=[dict(k="dim", amount=0.3, on="増やして")]),
    dict(id="6-15", text="次に、化石です。", scene=PH("ai_tenarms1.jpg")),
    dict(id="6-16", text="論文は、タコが約2億7千万年前に、", say="ろんぶんは、タコが、やくにおくななせんまんねんまえに、", scene=V("ocean", 6.0)),
    dict(id="6-17", text="急に現れたと書きました。", fx=[dict(k="q", xy=(W * 0.5, H * 0.42), label="急に？", on="急に")]),
    dict(id="6-18", text="ところが2022年、ある化石が報告されます。", say="ところが、にせんにじゅうにねん、あるかせきが、ほうこくされます。", scene=PH("ai_tenarms1.jpg", "left")),
    dict(id="6-19", text="見つかったのは、アメリカのモンタナ州。", scene=dict(kind="map", view=(-100, 42, 60, 0), to=(-109, 46.8, 18, 20), place=("モンタナ州", "ベアガルチの石灰岩"))),
    dict(id="6-20", text="約【3億2,800万年前】の、タコの仲間の祖先です。", say="やく、さんおくにせんはっぴゃくまんねんまえの、タコのなかまの、そせんです。", scene=PH("ai_tenarms1.jpg", "right")),
    dict(id="6-21", text="論文の言う時代より、6千万年も古い。", say="ろんぶんのいうじだいより、ろくせんまんねんも、ふるい。",
         scene=dict(kind="bars", items=[dict(name="論文の説", value=2.7, unit="億年前"), dict(name="化石", value=3.28, unit="億年前", label="3.28億年前")]),
         fx=[dict(k="focus", name="化石", on="6千万")]),
    dict(id="6-22", text="腕は10本。吸盤もありました。", scene=PH("ai_tenarms1.jpg")),
    dict(id="6-23", text="さらにさかのぼると、約5億年前。", scene=PH("ai_shell1.jpg")),
    dict(id="6-24", text="祖先は、細長い殻を背負っていました。", fx=[dict(k="note", xy=(W * 0.62, H * 0.45), text="細長い殻", on="殻")]),
    dict(id="6-25", text="タコは、殻を捨てた貝の仲間なのです。", scene=V("oct_rock", 1.5)),
    dict(id="6-26", answer=True, text="タコは、宇宙から来たのではありませんでした。", scene=dict(kind="words", rows=["タコは、", "【宇宙から来たのではない】"], rows_on=[None, "宇宙"])),
    dict(id="6-27", text="では、冒頭の約束です。", scene=V("camo2", 0.0, 0.6)),
    dict(id="6-28", text="この答えは、ここで終わりません。", fx=[dict(k="dim", amount=0.4, on="終わりません")]),
    dict(id="6-29", text="人とタコの祖先が分かれたのは、", scene=dict(kind="split", left=dict(src=S("human_eye.mp4"), name="人", start=0.0),
                                                              right=dict(src=S("oct_eye2.mp4"), name="タコ", start=0.0))),
    dict(id="6-30", text="5億年以上も前のことです。", fx=[dict(k="note", xy=(W * 0.5, H * 0.18 if P else H * 0.82), text="5億年以上前に分かれた", on="5億")]),
    dict(id="6-31", text="カメラのような目は、分かれたあとで生まれました。", fx=[dict(k="focus", name="タコ", on="目は")]),
    dict(id="6-32", text="人とタコが、別々の道で、よく似た目を作ったのです。", fx=[dict(k="focus", name="人", on="人と"), dict(k="focus", name="タコ", on="人と")]),
    dict(id="6-33", text="神経をつなぐ遺伝子も、【別々に】増やしていました。", scene=V("dna", 7.0)),
    dict(id="6-34", text="遠い昔に分かれた2つの生き物が、", scene=V("oct_eye", 3.0)),
    dict(id="6-35", text="それぞれに、賢さを作り上げたのです。", fx=[dict(k="dim", amount=0.3, on="賢さ")]),
    dict(id="6-36", text="タコは、宇宙人ではありません。", scene=V("oct_skin", 55.0)),
    dict(id="6-37", text="けれど地球には、私たちとまるで違う作りの、", scene=V("oct_eye2", 8.0)),
    dict(id="6-38", text="【もう1つの知性】がいるのです。", scene=dict(kind="words", rows=["地球には、", "【もう1つの知性】がいる"], rows_on=[None, "もう1つ"])),
    dict(id="6-39", text="次に海でタコを見たら、その目を見てください。", scene=V("oct_eye", 10.0)),
    dict(id="6-40", text="5億年かけて、別の道から作られた目です。", fx=[dict(k="note", xy=(W * 0.48, H * 0.48), text="5億年かけてできた目", on="5億")]),
]
TITLES = dict(ch1="宇宙から来た、という論文", ch2="証拠1 色が見えないのに化ける", ch3="証拠2 泳ぐと止まる心臓",
              ch4="証拠3 考える腕", ch5="証拠4 道具を持ち歩く", ch6="証拠5 遺伝子と、答え")
MAPS = dict(ch5=dict(lat0=-2, bases=[((90, -15, 145, 10), 5)]), ch6=dict(lat0=45, bases=[((-130, 25, -70, 55), 5)]))

# ---- ショート(縦)--------------------------------------------------------------------------------------
SH = {}
SH["s1"] = [
    dict(id="1", open="scene", text="2018年、33人の科学者が論文を出しました。", say="にせんじゅうハチねん、さんじゅうさんにんの、かがくしゃが、ろんぶんをだしました。",
         scene=dict(kind="card", title="Cause of Cambrian Explosion", sub="2018年・著者33人", body="カンブリア爆発の原因は、地球か宇宙か。", src="Progress in Biophysics and Molecular Biology")),
    dict(id="2", text="タコの卵は、凍ったまま【宇宙から】来たのかもしれない。", scene=PH("ai_comet1.jpg", "left")),
    dict(id="3", text="理由の1つは、遺伝子の数でした。", scene=V("dna", 0.0)),
    dict(id="4", text="タコの遺伝子は3万3千個以上。人より多いのです。", say="タコのいでんしは、さんまんさんぜんこいじょう。ひとより、おおいのです。", scene=V("oct_eye2", 2.0)),
    dict(id="5", text="本当に、宇宙から来たのか。", scene=V("camo2", 1.0, 0.6), fx=[dict(k="q", xy=XY(0.5, 0.40), label="宇宙から？", on="宇宙")]),
    dict(id="6", text="タコの遺伝子を1つずつ見ると、", scene=V("lab", 3.0)),
    dict(id="7", text="体や神経を作る遺伝子のそろいは、", scene=V("dna", 4.0)),
    dict(id="8", text="ほかの背骨のない動物とほぼ同じでした。", scene=V("squid", 6.0)),
    dict(id="9", text="多かったのは、神経どうしをつなぐ遺伝子の家族。", scene=dict(kind="bars", items=[dict(name="タコ", value=168, unit="個")])),
    dict(id="10", text="タコは168個、人は58個。", say="タコはひゃくろくじゅうはっこ、ひとは、ごじゅうはっこ。", fx=[dict(k="add", item=dict(name="人", value=58, unit="個"), on="人は")]),
    dict(id="11", text="人の、約3倍です。", fx=[dict(k="add", ratio=dict(text="約3倍", sub=""), on="3倍")]),
    dict(id="12", text="地球の動物と同じ遺伝子を、増やしていたのです。", scene=V("oct_coral", 2.0)),
    dict(id="13", text="さらに2022年、約3億2,800万年前の、", say="さらに、にせんにじゅうにねん、やくさんおくにせんはっぴゃくまんねんまえの、", scene=PH("ai_tenarms1.jpg")),
    dict(id="14", text="タコの仲間の祖先の化石が報告されました。", fx=[dict(k="note", xy=(W * 0.5, H * 0.42), text="3億2,800万年前", on="化石")]),
    dict(id="15", text="論文が「急に現れた」とする時代より、6千万年も前。", say="ろんぶんが、きゅうにあらわれた、とするじだいより、ろくせんまんねんも、まえ。",
         scene=dict(kind="bars", items=[dict(name="論文の説", value=2.7, unit="億年前"), dict(name="化石", value=3.28, unit="億年前", label="3.28億年前")])),
    dict(id="16", answer=True, text="タコは、地球の海で生まれた生き物でした。", scene=V("oct_eye", 10.0)),
]
SH["s2"] = [
    dict(id="1", open="scene", text="この岩の中に、タコがいます。", scene=V("camo2", 0.0, 0.7)),
    dict(id="2", text="正解は、ここ。", fx=[dict(k="spot", box=camo_spot(), on="ここ")]),
    dict(id="3", text="タコは一瞬で、周りの色と模様に化けます。", scene=V("camo1", 0.5)),
    dict(id="4", text="ところが、タコの目は【色を見分けられません】。", scene=V("oct_eye2", 2.0)),
    dict(id="5", text="光を感じる色素が、1種類しかないのです。", scene=dict(kind="words", rows=["目の色素は、", "【1種類だけ】"], rows_on=[None, "1種類"])),
    dict(id="6", text="色が見えないのに、なぜ化けられるのか。", scene=V("camo2", 3.0, 0.6), fx=[dict(k="q", xy=XY(0.5, 0.40), label="なぜ？", on="なぜ")]),
    dict(id="7", text="2015年、研究チームがタコの皮膚だけを切り取り、", say="にせんじゅうごねん、けんきゅうチームが、タコのひふだけをきりとり、", scene=V("lab", 1.0)),
    dict(id="8", text="光を当てました。", scene=PH("petri.jpg")),
    dict(id="9", text="目にも脳にも、つながっていない皮膚です。", fx=[dict(k="note", xy=(W * 0.5, H * 0.45), text="皮膚だけ", on="つながって")]),
    dict(id="10", text="すると、色の袋がひとりでに広がりました。", scene=V("oct_skin", 10.0)),
    dict(id="11", text="いちばん反応したのは、青い光。", fx=[dict(k="note", xy=(W * 0.5, H * 0.38), text="青い光", on="青い")]),
    dict(id="12", answer=True, text="タコは、皮膚でも光を感じていたのです。", scene=V("oct_dark", 3.0)),
    dict(id="13", text="皮膚には、目と同じしくみのたんぱく質がありました。", scene=dict(kind="card", title="オプシン", sub="光を感じるたんぱく質", body="目と同じ仲間が、タコの皮膚の神経にあった。", src="Ramirez & Oakley 2015")),
    dict(id="14", text="ただ、生きたタコがどう使うのかは、まだ謎です。", scene=V("camo1", 5.0)),
    dict(id="15", text="見えない色を、皮膚が補っているのか。", fx=[dict(k="q", xy=XY(0.55, 0.40), label="", on="補って")]),
    dict(id="16", text="答えは、これからの研究が出します。", scene=V("oct_eye", 8.0)),
]
SH["s3"] = [
    dict(id="1", open="belief", text="心臓は、1つ。人も犬も、そうです。", scene=PH("dog.jpg")),
    dict(id="2", text="ところがタコには、心臓が【3つ】あります。", scene=dict(kind="custom", fn="hearts", credit="映像: JUN HO LEE / Pexels　図: 理の書"),
         fx=[dict(k="step", n=1, on="3つ"), dict(k="step", n=2, on="3つ")]),
    dict(id="3", text="しかも泳ぐと、そのうち1つの拍動が途切れます。", scene=V("oct_rock", 13.0)),
    dict(id="4", text="なぜ、そんな作りなのか。", scene=V("oct_crawl", 1.0), fx=[dict(k="q", xy=XY(0.45, 0.5), label="なぜ？", on="なぜ")]),
    dict(id="5", text="2つは、えらに血を押し込む心臓。", scene=dict(kind="custom", fn="hearts", credit="映像: JUN HO LEE / Pexels　図: 理の書"),
         fx=[dict(k="step", n=1, on="2つ"), dict(k="step", n=3, on="押し込む")]),
    dict(id="6", text="1つは、全身へ血を送る心臓です。", fx=[dict(k="step", n=2, on="全身")]),
    dict(id="7", text="手がかりは、タコの青い血。", scene=V("oct_dark", 10.0)),
    dict(id="8", text="タコの血は、銅で酸素を運ぶので青い。", scene=dict(kind="card", title="ヘモシアニン", sub="酸素を運ぶたんぱく質", body="鉄ではなく銅を使い、酸素と結びつくと青くなる。", src="Oellermann ほか 2015")),
    dict(id="9", text="運べる酸素は、人の約15分の1です。", say="はこべるさんそは、ひとの、やくじゅうごぶんのいちです。",
         scene=dict(kind="bars", items=[dict(name="人", value=9.3, unit="ミリモル"), dict(name="タコ", value=0.61, unit="ミリモル", label="0.61ミリモル")])),
    dict(id="10", text="休んでいても、その83%を使い切っています。", say="やすんでいても、そのはちじゅうさんパーセントを、つかいきっています。",
         scene=dict(kind="bars", items=[dict(name="使った酸素", value=83, unit="%")], max=100)),
    dict(id="11", text="余りがないので、動くときは血を回すしかない。", scene=V("oct_rock", 2.0)),
    dict(id="12", text="動くと、心臓が送る血は約2.5倍になります。", say="うごくと、しんぞうがおくるちは、やくにてんごばいになります。",
         scene=dict(kind="bars", items=[dict(name="休む", value=1.0, unit="倍")]), fx=[dict(k="add", item=dict(name="動く", value=2.5, unit="倍"), on="2.5")]),
    dict(id="13", answer=True, text="3つの心臓は、少ない酸素を回し続ける作りなのです。", scene=dict(kind="custom", fn="hearts", credit="映像: JUN HO LEE / Pexels　図: 理の書"),
         fx=[dict(k="step", n=1, on="3つ"), dict(k="step", n=2, on="3つ"), dict(k="step", n=3, on="回し")]),
    dict(id="14", text="ただ、水を吹き出して泳ぐと、", scene=V("oct_rock", 14.0)),
    dict(id="15", text="全身へ送る心臓の拍動が、一時途切れます。", fx=[dict(k="dim", on="途切れ")]),
    dict(id="16", text="泳ぐたびに、心臓が止まりかける。", scene=dict(kind="words", rows=["泳ぐたびに、", "【心臓が止まりかける】"], rows_on=[None, "心臓"])),
    dict(id="17", text="タコの体は、そんな危うい作りでできています。", scene=V("oct_eye", 6.0)),
]
SH["s4"] = [
    dict(id="1", open="scene", text="タコの腕は、切れても【1時間】以上動きます。", scene=V("oct_dark", 22.0)),
    dict(id="2", text="映画の半分ほどの時間です。", scene=PH("cinema.jpg")),
    dict(id="3", text="近くのものを、何でもつかみ続けます。", scene=V("oct_crawl", 2.0)),
    dict(id="4", text="ところが、どうしてもつかまないものがあります。", scene=V("oct_eye", 9.0)),
    dict(id="5", text="それは、何か。", fx=[dict(k="q", xy=XY(0.55, 0.45), label="", on="何か")]),
    dict(id="6", text="つかまなかったのは、タコの体でした。", scene=V("oct_skin", 45.0)),
    dict(id="7", text="生きたタコにも、ほかの切れた腕にも、吸いつかない。", scene=V("oct_coral", 3.0)),
    dict(id="8", text="では、タコの体の何が、つかむのを止めているのか。", scene=V("oct_dark", 26.0), fx=[dict(k="q", xy=XY(0.5, 0.40), label="何が？", on="何が")]),
    dict(id="9", text="研究チームは、タコの皮膚をぬったお皿で試しました。", scene=PH("petri.jpg")),
    dict(id="10", text="吸盤は、そのお皿をほとんどつかみません。", fx=[dict(k="dim", amount=0.4, on="ほとんど")]),
    dict(id="11", text="皮膚をはいだ腕なら、ほかの腕もつかみました。", scene=V("lab", 8.0)),
    dict(id="12", answer=True, text="皮膚の中の物質が、つかむ反射を止めていたのです。", scene=V("oct_skin", 25.0)),
    dict(id="13", text="だから、8本の腕は互いにからまりません。", scene=V("oct_crawl", 5.0)),
    dict(id="14", text="ただ生きたタコは、ときどき切れた腕をつかみます。", scene=V("oct_rock", 2.0)),
    dict(id="15", text="頭の脳が、この止める仕組みを外せるのです。", scene=V("oct_eye2", 4.0)),
    dict(id="16", text="その物質の正体は、まだわかっていません。", fx=[dict(k="q", xy=XY(0.5, 0.40), label="正体は？", on="正体")]),
]
SH["s5"] = [
    dict(id="1", open="scene", text="インドネシアの海に、殻を抱えて歩くタコがいます。", scene=PH("ai_coconut1.jpg")),
    dict(id="2", text="抱えているのは、人が捨てた【ココナッツの殻】。", scene=PH("coconut.jpg")),
    dict(id="3", text="半分に割れた殻を2つ重ねて、体の下に抱えます。", scene=PH("ai_coconut1.jpg", "left")),
    dict(id="4", text="8本の腕を、竹馬のように突っ張って歩きます。", fx=[dict(k="note", xy=(W * 0.45, H * 0.62), text="腕が竹馬", on="竹馬")]),
    dict(id="5", text="遠いと、20メートルも運びます。", say="とおいと、にじゅうメートルも、はこびます。", scene=V("oct_sand", 8.0)),
    dict(id="6", text="25メートルプールの、8割ほどの距離です。", say="にじゅうごメートルプールの、はちわりほどの、きょりです。", scene=PH("pool.jpg")),
    dict(id="7", text="重くて、歩きにくそうなのに。", scene=V("oct_sand", 14.0)),
    dict(id="8", text="なぜ、こんな物を持ち歩くのか。", fx=[dict(k="q", xy=XY(0.5, 0.35), label="なぜ？", on="なぜ")]),
    dict(id="9", text="ヒントは、殻の形です。", scene=PH("coconut.jpg", "right")),
    dict(id="10", text="半分の殻を2つ合わせると、丸い玉になります。", fx=[dict(k="note", xy=(W * 0.5, H * 0.40), text="2つ合わせると玉", on="合わせる")]),
    dict(id="11", answer=True, text="危ないとき、殻を合わせて中に隠れるのです。", scene=PH("ai_coconut1.jpg", "right")),
    dict(id="12", text="その場では役に立たない物を、あとのために運ぶ。", scene=V("oct_sand", 18.0)),
    dict(id="13", text="研究チームは、これを道具の使用だと報告しました。", scene=dict(kind="card", title="道具を使うタコ", sub="2009年",
         body="殻を運び、あとで隠れ家にする。", src="Finn ほか 2009 Current Biology")),
    dict(id="14", text="タコは、道具を使う動物の仲間入りをしたのです。", scene=V("oct_eye", 12.0)),
]
STITLES = dict(s1="タコは宇宙から来た、と書いた33人", s2="色が見えないのに、化けるタコ", s3="泳ぐと止まる、タコの心臓",
               s4="切れたタコの腕が、つかまないもの", s5="ココナッツを抱えて歩くタコ")


def ep_for(key: str) -> dict:
    if key.startswith("ch"):
        d = dict(kind="stage", title=TITLES[key], qtag=QTAG, colors=COLORS, lines=CH[key])
        if key in MAPS:
            d["map"] = MAPS[key]
        return d
    return dict(kind="stage", title=STITLES[key], qtag=STITLES[key], colors=COLORS, lines=SH[key])
