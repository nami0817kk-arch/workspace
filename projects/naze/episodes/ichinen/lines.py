"""大人の1年は、なぜ短いのか(2026-11-22 台本 第1稿)の台本と画面。本編 ch1〜ch6(横)とショート s1〜s4(縦)の ep.py がここを読む。
台本の正は 台本.md と同じ文。画面の作りは naze/stage.py の冒頭。

出どころ:
- 14〜94 歳の 499 人(ドイツ・オーストリア)。この 1 週間・1 か月・1 年の速さは年齢で差がなく、この 10 年だけ年上ほど速い
  (14〜59 歳で上がり、60 歳で止まる): Wittmann & Lehnhoff 2005, Psychological Reports 97:921。
  内容は Wittmann & Mella 2021, Timing & Time Perception 9:275 の本文で確かめた(同じ調査の答えを調べ直した論文)
- 同じ結果: オランダ・ニュージーランド(Friedman & Janssen 2010)、日本(Janssen, Naka & Friedman 2013, Time & Society 22:274、N=868)
- 子どもがいる人は、この 10 年をより速く感じた: Wittmann & Mella 2021
- 熱を出した妻に 1 秒に 1 つずつ 60 まで数えてもらい、熱が高いほど速く数えた: Hoagland 1933, Journal of General Psychology 9:267
  (手順は Neuroscience for Kids 2004-02 の紹介。秒数の細かい数字は見つからなかったので台本では使わない)
- 31m の落下。落ちている間も速い数字は読めず、あとで自分の落下を他の人の落下より 36% 長く見積もった:
  Stetson, Fiesta & Eagleman 2007, PLoS ONE 2:e1295
- 落ちている時間 約 2.5 秒: 31m の自由落下の計算 √(2×31÷9.8)=2.52 秒
- 休暇のパラドックス: Claudia Hammond 2012『Time Warped』
- 記憶は 10〜30 歳ごろのものがいちばん多く残る(レミニセンス・バンプ): Rubin ほか
- ジャネーの法則: Paul Janet 1877。50 歳の 1 年は 5 歳の 1 年の 10 分の 1 → 365÷10 ≒ 36 日
"""
from PIL import Image, ImageDraw

from naze import stage as sg

W, H, P = sg.W, sg.H, sg.PORTRAIT
QTAG = "大人の1年は、なぜ短いのか"
COLORS = {"子ども": (255, 200, 90), "大人": (150, 210, 255)}
BG = (12, 16, 28, 255)


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


def WD(a, b, on=None):
    return dict(kind="words", rows=[a, b], rows_on=[None, on])


def C(fn, credit="図: 理の書"):
    return dict(kind="custom", fn=fn, credit=credit)


def ST(n, on):
    return dict(k="step", n=n, on=on)


def NOTE(fx, fy, text, on):
    return dict(k="note", xy=(W * fx, H * fy), text=text, on=on)


def Q(label, on, fy=0.45):
    return dict(k="q", xy=(W * 0.5, H * fy), label=label, on=on)


def DIM(on, a=0.4):
    return dict(k="dim", amount=a, on=on)


def _steps(c):
    return {f["n"]: c.when(f) for f in c.seg["fx"] if f["k"] == "step"}


def _k(t, steps, n, dd=0.6):
    return sg.ease((t - steps.get(n, 1e9)) / dd)


def _font(sz_land, sz_port):
    return sg.F("YuGothB.ttc", sz_port if P else sz_land)


# ---- 図: 人生の帯(5 歳と 50 歳で、1 年が占める割合) -------------------------------------------------
def draw_life(img: Image.Image, t: float, c) -> None:
    """step 1 = 5 歳の帯(5 つに区切り 1 つを黄色)、step 2 = 50 歳の帯(50 に区切り 1 つを黄色)。"""
    st = _steps(c)
    bg = Image.new("RGBA", (W, H), BG)
    d = ImageDraw.Draw(bg, "RGBA")
    x0, x1 = (W * 0.10, W * 0.90) if not P else (W * 0.08, W * 0.92)
    fL, fS = _font(46, 52), _font(36, 42)
    rows = [(1, 5, "5歳", "1年＝人生の5分の1", H * (0.30 if not P else 0.30)), (2, 50, "50歳", "1年＝人生の50分の1", H * (0.58 if not P else 0.48))]
    for n, years, name, label, y in rows:
        k = _k(t, st, n)
        if k <= 0:
            continue
        a = int(255 * k)
        bh = 70 if not P else 90
        sg.stext(d, (x0, y - 50), name, fL, (255, 255, 255, a), anchor="lm")
        w = (x1 - x0) * min(1.0, k * 1.2)
        d.rounded_rectangle([x0, y, x0 + w, y + bh], 10, fill=(60, 75, 105, a))
        seg = (x1 - x0) / years
        for i in range(1, years):
            xx = x0 + seg * i
            if xx < x0 + w:
                d.line([(xx, y + 4), (xx, y + bh - 4)], fill=(20, 26, 40, a), width=2 if years > 10 else 4)
        last = x0 + seg * (years - 1)
        if last < x0 + w:
            d.rectangle([last, y, x1 if w >= x1 - x0 - 1 else x0 + w, y + bh], fill=(255, 214, 64, a))
        sg.stext(d, (x1, y + bh + 45), label, fS, (255, 214, 64, a), anchor="rm")
    img.alpha_composite(bg)


# ---- 図: 調査の結果(模式図。年齢と「速く過ぎた」と感じる強さ) ----------------------------------------
def draw_survey(img: Image.Image, t: float, c) -> None:
    """step 1 = 予想(どの期間も年上ほど速い、点線)、2 = 1 週間・1 か月・1 年は平ら、3 = 10 年は 59 歳まで上がり 60 歳で止まる。"""
    st = _steps(c)
    bg = Image.new("RGBA", (W, H), BG)
    d = ImageDraw.Draw(bg, "RGBA")
    l, r = (W * 0.14, W * 0.86) if not P else (W * 0.12, W * 0.90)
    top, bot = (H * 0.18, H * 0.74) if not P else (H * 0.22, H * 0.58)
    fS, fL = _font(32, 38), _font(40, 46)
    d.line([(l, bot), (r, bot)], fill=(170, 180, 200, 255), width=3)
    d.line([(l, top), (l, bot)], fill=(170, 180, 200, 255), width=3)

    def X(age):
        return l + (age - 14) / 80 * (r - l)

    def Y(v):
        return bot - v * (bot - top)
    for age in (14, 30, 50, 70, 94):
        sg.stext(d, (X(age), bot + 30), f"{age}歳", fS, (170, 180, 200, 255), anchor="mm")
    sg.stext(d, (l + 10, top - 30), "速く過ぎたと感じる", fS, (170, 180, 200, 255), anchor="lm")
    k1, k2, k3 = _k(t, st, 1), _k(t, st, 2), _k(t, st, 3)
    if k1 > 0:
        a = int(200 * k1 * (1 - 0.7 * k2))
        for i in range(0, 20):
            u0, u1 = i / 20, (i + 0.5) / 20
            d.line([(X(14 + 80 * u0), Y(0.25 + 0.6 * u0)), (X(14 + 80 * u1), Y(0.25 + 0.6 * u1))], fill=(200, 200, 210, a), width=5)
        if k2 <= 0:
            sg.stext(d, (X(80), Y(0.95)), "予想", fL, (220, 220, 230, a), anchor="mm")
    if k2 > 0:
        a = int(255 * k2)
        for v, name in ((0.42, "1年"), (0.36, "1か月"), (0.30, "1週間")):
            w = X(14) + (X(94) - X(14)) * min(1, k2 * 1.2)
            d.line([(X(14), Y(v)), (w, Y(v))], fill=(150, 210, 255, a), width=6)
            sg.stext(d, (X(94) + 10, Y(v)), name, fS, (150, 210, 255, a), anchor="lm")
    if k3 > 0:
        a = int(255 * k3)
        pts = []
        for i in range(41):
            age = 14 + 80 * i / 40
            if age > 14 + 80 * k3:
                break
            v = 0.40 + 0.45 * (min(age, 59) - 14) / 45
            pts.append((X(age), Y(v)))
        if len(pts) > 1:
            d.line(pts, fill=(255, 214, 64, a), width=8)
        sg.stext(d, (X(94) + 10, Y(0.85)), "10年", fL, (255, 214, 64, a), anchor="lm")
    sg.stext(d, (r, bot + 70), "模式図（形だけを示す）", fS, (120, 130, 150, 255), anchor="rm")
    img.alpha_composite(bg)


# ---- 図: 5 段階の答え -------------------------------------------------------------------------------
def draw_scale(img: Image.Image, t: float, c) -> None:
    bg = Image.new("RGBA", (W, H), BG)
    d = ImageDraw.Draw(bg, "RGBA")
    names = ["とても遅い", "遅い", "どちらでも", "速い", "とても速い"]
    f = _font(36, 40)
    if not P:
        bw, gap, y = W * 0.15, W * 0.02, H * 0.42
        x = (W - (bw * 5 + gap * 4)) / 2
        for i, nm in enumerate(names):
            col = (60 + 40 * i, 90 + 20 * i, 140 - 10 * i, 255)
            d.rounded_rectangle([x, y, x + bw, y + 140], 16, fill=col)
            sg.stext(d, (x + bw / 2, y + 70), nm, f, (255, 255, 255, 255), anchor="mm")
            x += bw + gap
    else:
        bh, gap = H * 0.07, H * 0.015
        y = H * 0.20
        for i, nm in enumerate(names):
            col = (60 + 40 * i, 90 + 20 * i, 140 - 10 * i, 255)
            d.rounded_rectangle([W * 0.15, y, W * 0.85, y + bh], 16, fill=col)
            sg.stext(d, (W / 2, y + bh / 2), nm, f, (255, 255, 255, 255), anchor="mm")
            y += bh + gap
    img.alpha_composite(bg)


# ---- 図: 時計の 1 分と、熱のある妻の「1 分」(模式図) -------------------------------------------------
def draw_minute(img: Image.Image, t: float, c) -> None:
    """step 1 = 時計の 1 分(円が 1 周する)、step 2 = 妻の「1 分」(同じ 60 を数え終えるのが早い。円が途中で止まる)。"""
    st = _steps(c)
    bg = Image.new("RGBA", (W, H), BG)
    d = ImageDraw.Draw(bg, "RGBA")
    rr = (H * 0.20) if not P else (W * 0.26)
    cs = [(W * 0.30, H * 0.45), (W * 0.70, H * 0.45)] if not P else [(W * 0.5, H * 0.26), (W * 0.5, H * 0.56)]
    f = _font(40, 46)
    for n, (cx, cy), name, frac, col in ((1, cs[0], "時計の1分", 1.0, (150, 210, 255)), (2, cs[1], "熱のある妻の「1分」", 0.75, (255, 214, 64))):
        if n not in st or t < st[n]:
            continue
        k = _k(t, st, n, 2.0)
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], outline=(90, 100, 125, 255), width=6)
        end = -90 + 360 * frac * k
        if k > 0:
            d.pieslice([cx - rr + 10, cy - rr + 10, cx + rr - 10, cy + rr - 10], -90, end, fill=col + (170,))
        sg.stext(d, (cx, cy + rr + 45), name, f, col + (255,), anchor="mm")
    sg.stext(d, (W - 40, H * (0.86 if not P else 0.70)), "模式図", _font(30, 36), (120, 130, 150, 255), anchor="rm")
    img.alpha_composite(bg)


# ---- 図: 31m の落下(10 階建てと並べる) ---------------------------------------------------------------
def draw_fall(img: Image.Image, t: float, c) -> None:
    """step 1 = 10 階建てのビルと 31m の線、step 2 = 人(点)が背中から落ちて網で止まる。"""
    st = _steps(c)
    bg = Image.new("RGBA", (W, H), BG)
    d = ImageDraw.Draw(bg, "RGBA")
    top, bot = (H * 0.14, H * 0.80) if not P else (H * 0.16, H * 0.64)
    bx0, bx1 = (W * 0.30, W * 0.44) if not P else (W * 0.18, W * 0.46)
    tx = (W * 0.62) if not P else (W * 0.70)
    f, fs = _font(44, 50), _font(30, 36)
    k1 = _k(t, st, 1)
    if k1 > 0:
        a = int(255 * k1)
        fh = (bot - top) / 10
        for i in range(10):
            y0 = bot - fh * (i + 1)
            d.rectangle([bx0, y0 + 3, bx1, y0 + fh - 3], fill=(70, 85, 115, a))
            for j in range(3):
                wx = bx0 + (bx1 - bx0) * (0.15 + 0.3 * j)
                d.rectangle([wx, y0 + fh * 0.3, wx + (bx1 - bx0) * 0.15, y0 + fh * 0.7], fill=(150, 180, 220, int(a * 0.6)))
        sg.stext(d, ((bx0 + bx1) / 2, bot + 40), "10階建て", fs, (200, 210, 230, a), anchor="mm")
        d.line([(tx, top), (tx, bot)], fill=(255, 214, 64, a), width=4)
        d.line([(tx - 40, top), (tx + 40, top)], fill=(255, 214, 64, a), width=4)
        d.line([(tx - 40, bot), (tx + 40, bot)], fill=(255, 214, 64, a), width=4)
        sg.stext(d, (tx + 60, (top + bot) / 2), "31m", f, (255, 214, 64, a), anchor="lm")
    if 2 in st:
        u = min(max((t - st[2]) / 2.52, 0.0), 1.0)
        y = top + (bot - top - 30) * u * u
        d.line([(tx - 110, bot - 10), (tx - 10, bot - 10)], fill=(220, 220, 230, 255), width=5)
        d.ellipse([tx - 82, y - 22, tx - 38, y + 22], fill=(255, 140, 90, 255))
    img.alpha_composite(bg)


# ---- 図: 年齢ごとの思い出の多さ(模式図) ----------------------------------------------------------------
def draw_memory(img: Image.Image, t: float, c) -> None:
    """step 1 = 0〜70 歳の思い出の多さの山。10〜30 歳が高い。"""
    st = _steps(c)
    bg = Image.new("RGBA", (W, H), BG)
    d = ImageDraw.Draw(bg, "RGBA")
    l, r = (W * 0.12, W * 0.88) if not P else (W * 0.10, W * 0.90)
    top, bot = (H * 0.20, H * 0.72) if not P else (H * 0.22, H * 0.56)
    fS = _font(32, 38)
    d.line([(l, bot), (r, bot)], fill=(170, 180, 200, 255), width=3)
    for age in (0, 10, 20, 30, 50, 70):
        sg.stext(d, (l + (r - l) * age / 70, bot + 30), f"{age}歳", fS, (170, 180, 200, 255), anchor="mm")
    sg.stext(d, (l, top - 30), "よく思い出す出来事の多さ", fS, (170, 180, 200, 255), anchor="lm")
    k = _k(t, st, 1, 1.5)
    if k > 0:
        import math
        n = 70
        for i in range(n):
            age = 70 * i / n
            if i / n > k:
                break
            v = 0.18 + 0.75 * math.exp(-((age - 20) / 8.5) ** 2) + 0.25 * max(0, (age - 55) / 15)
            x0 = l + (r - l) * i / n
            x1 = l + (r - l) * (i + 1) / n - 2
            col = (255, 214, 64, 230) if 10 <= age < 30 else (110, 140, 190, 230)
            d.rectangle([x0, bot - v * (bot - top), x1, bot], fill=col)
        sg.stext(d, (l + (r - l) * 20 / 70, top - 30 + 70), "10〜30歳", _font(42, 48), (255, 214, 64, int(255 * k)), anchor="mm")
    sg.stext(d, (r, bot + 75), "模式図（形だけを示す）", fS, (120, 130, 150, 255), anchor="rm")
    img.alpha_composite(bg)


# ---- 本編(横)----------------------------------------------------------------------------------------
CARD_JANET = dict(kind="card", title="ジャネーの法則", sub="1877年", body="感じる1年の長さは、生きてきた年数に反比例する。", src="Paul Janet 1877")
CARD_FALL = dict(kind="card", title="落下の実験", sub="2007年", body="人を31mの高さから背中向きに落とし、腕の画面の速い数字が読めるかを調べた。", src="Stetson ほか 2007 PLoS ONE")
CARD_HOLIDAY = dict(kind="card", title="休暇のパラドックス", sub="クローディア・ハモンド", body="旅行の間は短いのに、あとで思い出すと長く感じる。", src="Hammond 2012『Time Warped』")
BARS_FALL = dict(kind="bars", items=[dict(name="他の人の落下", value=100, unit=""), dict(name="自分の落下", value=136, unit="", label="36%長い", on="36")])

CH = {}
CH["ch1"] = [
    dict(id="1-1", open="scene", text="小学生の夏休み。約40日、1年の9分の1もありました。", say="しょうがくせいの、なつやすみ。やく、よんじゅうにち、いちねんの、きゅうぶんのいちも、ありました。", scene=V("c3969322", 2.0)),
    dict(id="1-2", text="朝からセミの声。毎日、新しい遊びを見つけました。", scene=V("c3969322", 14.0)),
    dict(id="1-3", text="終わらないように思えた夏です。", scene=V("c4391957", 1.0)),
    dict(id="1-4", text="ところが大人になると、1年があっという間です。", scene=V("c36035831", 0.0)),
    dict(id="1-5", text="気がつけば、もう年末。", scene=PH("p29509502")),
    dict(id="1-6", text="カレンダーをめくるたびに、月日の速さに驚きます。", scene=PH("p6193146", "right")),
    dict(id="1-7", text="時計の針は、子どもにも大人にも、同じ速さで進みます。", scene=V("c9160922", 2.0)),
    dict(id="1-8", text="1年は、誰にとっても365日です。", say="いちねんは、だれにとっても、さんびゃくろくじゅうごにちです。", scene=WD("1年は誰にとっても", "【365日】", "365")),
    dict(id="1-9", text="それなのに、長さがまるで違って感じる。", scene=V("c34509926", 0.0)),
    dict(id="1-10", text="なぜ、大人の1年は短いのか。", fx=[Q("なぜ？", "なぜ")]),
    dict(id="1-11", text="この問いには、よく聞く答えがあります。", scene=PH("p11883419")),
    dict(id="1-12", text="「年を取ったから」。", scene=WD("よく聞く答え", "【年を取ったから】", "年を")),
    dict(id="1-13", text="でも、年を取るとなぜ速いのかは、また別の問いです。", scene=V("c855482", 2.0), fx=[Q("なぜ速い？", "なぜ")]),
    dict(id="1-14", text="今日は、世界の調査と実験で、1つずつ確かめます。", scene=V("c8061061", 0.0)),
    dict(id="1-15", text="まず、よく言われる答えを2つ取り上げます。", scene=WD("よく言われる答え", "【2つ】", "2つ")),
    dict(id="1-16", text="どちらも、もっともらしく聞こえます。", scene=PH("p13553850")),
    dict(id="1-17", text="ところが両方とも、ある調査で外れます。", fx=[DIM("外れ")]),
    dict(id="1-18", text="最後に残る答えは、意外な所にありました。", scene=V("c2975799", 2.0)),
]
CH["ch2"] = [
    dict(id="2-1", text="1つ目の答えは、「ジャネーの法則」です。", scene=CARD_JANET),
    dict(id="2-2", text="1877年、フランスの哲学者ポール・ジャネが書いた考えです。", say="せんはっぴゃくななじゅうななねん、フランスの、てつがくしゃ、ポール・ジャネが、かいた、かんがえです。",
         scene=PH("p13553850", "left", place=("ポール・ジャネ", "フランスの哲学者"))),
    dict(id="2-3", text="感じる1年の長さは、生きてきた年数に反比例する。", scene=WD("感じる1年の長さは", "【生きた年数に反比例】", "反比例")),
    dict(id="2-4", text="難しく聞こえますが、中身は簡単です。", scene=V("c4391957", 6.0)),
    dict(id="2-5", text="5歳の子にとって、1年は人生の5分の1。", say="ごさいのこにとって、いちねんは、じんせいの、ごぶんのいち。", scene=C("life"), fx=[ST(1, "5歳")]),
    dict(id="2-6", text="50歳の人にとって、1年は人生の50分の1。", say="ごじゅっさいのひとにとって、いちねんは、じんせいの、ごじゅうぶんのいち。", fx=[ST(1, "50歳"), ST(2, "50歳")]),
    dict(id="2-7", text="同じ1年でも、人生に占める割合が10倍違います。", say="おなじいちねんでも、じんせいにしめる、わりあいが、じゅうばい、ちがいます。",
         scene=dict(kind="bars", items=[dict(name="5歳", value=20, unit="%", label="5分の1"), dict(name="50歳", value=2, unit="%", label="50分の1")])),
    dict(id="2-8", text="50歳の1年は、5歳の子の約36日ぶんの重さしかない。", say="ごじゅっさいのいちねんは、ごさいのこの、やく、さんじゅうろくにちぶんの、おもさしかない。",
         scene=WD("50歳の1年は", "【5歳の約36日ぶん】", "36")),
    dict(id="2-9", text="だから大人の1年は短い、という説明です。", scene=V("c36035831", 4.0)),
    dict(id="2-10", text="たしかに、それらしく聞こえます。", scene=V("c27333442", 1.0)),
    dict(id="2-11", text="日本でも、よく紹介される考えです。", say="にほんでも、よく、しょうかいされる、かんがえです。", scene=V("c31240469", 1.0)),
    dict(id="2-12", text="ただ、この法則には、気になる所があります。", scene=PH("p13553850", "right"), fx=[Q("気になる所", "気になる")]),
    dict(id="2-13", text="割合で感じるなら、速くなるのは1年だけではありません。", scene=V("c9160922", 6.0)),
    dict(id="2-14", text="1週間も1か月も、同じように速くなるはずです。", fx=[NOTE(0.5, 0.40, "1週間も1か月も", "1週間")]),
    dict(id="2-15", text="50歳の1週間は、5歳の子の1週間の10分の1の重さ。", say="ごじゅっさいのいっしゅうかんは、ごさいのこの、いっしゅうかんの、じゅうぶんのいちの、おもさ。",
         scene=dict(kind="bars", items=[dict(name="5歳の1週間", value=7, unit="日"), dict(name="50歳の1週間", value=0.7, unit="日", label="10分の1", on="10分の1")])),
    dict(id="2-16", text="大人の1週間は、子どもの1日にも届かない計算です。", fx=[dict(k="add", ratio=dict(text="1日に届かない", sub="ジャネーの法則の計算"), on="1日")]),
    dict(id="2-17", text="本当に、そうでしょうか。", scene=V("c34509926", 3.0), fx=[Q("本当？", "本当")]),
    dict(id="2-18", text="大人でも、退屈な会議の1時間は長く感じます。", scene=V("c9068779", 2.0)),
    dict(id="2-19", text="待ち合わせの10分も、長いものです。", say="まちあわせの、じっぷんも、ながいものです。", scene=V("c6328383", 1.0)),
    dict(id="2-20", text="ジャネーの法則は、年と1年の短さを、割り算で言い直したものです。", scene=WD("割り算で", "【言い直しただけ】", "言い直")),
    dict(id="2-21", text="なぜそう感じるのかは、まだ説明していません。", scene=PH("p13553850", "left"), fx=[DIM("まだ")]),
    dict(id="2-22", text="この法則が本当かどうかは、あとで調査の結果で確かめます。", scene=V("c8061061", 3.0)),
    dict(id="2-23", text="その前に、もう1つの答えを見ます。", scene=V("c31423124", 1.0)),
]
CH["ch3"] = [
    dict(id="3-1", text="2つ目の答えは、体の中の時計です。", scene=V("c39488470", 1.0)),
    dict(id="3-2", text="1930年代のアメリカ。", say="せんきゅうひゃくさんじゅうねんだいの、アメリカ。", scene=PH("p1010513", place=("アメリカ", "1930年代"))),
    dict(id="3-3", text="研究者ホーグランドの妻が、インフルエンザで熱を出しました。", scene=V("c7423531", 1.0)),
    dict(id="3-4", text="彼が少し部屋を離れただけなのに、", scene=V("c5239286", 1.0)),
    dict(id="3-5", text="妻は「ずいぶん長かった」と言いました。", scene=WD("「ずいぶん", "【長かった】」", "長かった")),
    dict(id="3-6", text="熱で、時間の感じ方が変わったのではないか。", scene=V("c5858754", 2.0), fx=[Q("熱のせい？", "変わった")]),
    dict(id="3-7", text="そこで、妻に頼みました。", scene=V("c5239286", 5.0)),
    dict(id="3-8", text="1秒に1つずつ、60まで数えてほしい。", say="いちびょうに、ひとつずつ、ろくじゅうまで、かぞえてほしい。", scene=WD("1秒に1つずつ", "【60まで数える】", "60")),
    dict(id="3-9", text="それを、ストップウォッチで測ります。", scene=PH("p19730401")),
    dict(id="3-10", text="熱の高さも、そのたびに測りました。", scene=V("c5858754", 8.0)),
    dict(id="3-11", text="結果、熱が高いときほど、妻は【速く】数えました。", scene=WD("熱が高いほど", "【速く数えた】", "速く")),
    dict(id="3-12", text="妻の「1分」は、本当の1分より短かったのです。", say="つまのいっぷんは、ほんとうのいっぷんより、みじかかったのです。", scene=C("minute", "図: 理の書（模式図）"),
         fx=[ST(1, "妻の"), ST(2, "本当")]),
    dict(id="3-13", text="体の中の時計が、熱で速く進んでいた。", fx=[NOTE(0.70, 0.20, "体の時計が速い", "速く")]),
    dict(id="3-14", text="体の時計が速いと、外の時間はゆっくりに感じます。", scene=V("c8136377", 2.0)),
    dict(id="3-15", text="待っている時間が、長く感じられるのです。", fx=[NOTE(0.5, 0.30, "待つ時間が長い", "長く")]),
    dict(id="3-16", text="では、逆はどうでしょう。", scene=V("c855482", 6.0), fx=[Q("逆は？", "逆")]),
    dict(id="3-17", text="年を取ると、体の働きはゆっくりになると言われます。", fx=[NOTE(0.62, 0.40, "体の働きがゆっくり", "ゆっくり")]),
    dict(id="3-18", text="体の時計も、ゆっくり進むようになるかもしれない。", scene=V("c39488470", 5.0)),
    dict(id="3-19", text="体の時計が遅れれば、外の時間は速く過ぎて見えます。", scene=WD("体の時計が遅れる", "【外の時間が速く見える】", "速く")),
    dict(id="3-20", text="これが2つ目の答え、「体の時計が遅くなる説」です。",
         scene=dict(kind="card", title="体の時計が遅くなる説", sub="答えの候補 2つ目", body="年を取ると体の中の時計がゆっくり進み、外の時間が速く過ぎて見える、という考え。", src="Hoagland 1933 の考えから")),
    dict(id="3-21", text="ジャネーの法則と、体の時計。", scene=WD("ジャネーの法則", "【体の時計】", "体の")),
    dict(id="3-22", text="答えの候補が、2つそろいました。", scene=PH("p13553850", "right")),
    dict(id="3-23", text="どちらが正しいのか。それとも、両方なのか。", fx=[Q("どちら？", "どちら")]),
    dict(id="3-24", text="確かめる方法があります。大人に、直接聞くのです。", scene=V("c8060739", 1.0)),
]
CH["ch4"] = [
    dict(id="4-1", text="2005年、ドイツとオーストリアで、ある調査が行われました。", say="にせんごねん、ドイツと、オーストリアで、あるちょうさが、おこなわれました。",
         scene=dict(kind="map", view=(12, 49, 24, 0), to=(12, 49.5, 12, 15), place=("ドイツ・オーストリア", "2005年の調査"))),
    dict(id="4-2", text="答えたのは、14歳から94歳までの499人。", say="こたえたのは、じゅうよんさいから、きゅうじゅうよんさいまでの、よんひゃくきゅうじゅうきゅうにん。",
         scene=WD("14歳〜94歳", "【499人】", "499")),
    dict(id="4-3", text="中学生から、90代のお年寄りまでです。", say="ちゅうがくせいから、きゅうじゅうだいの、おとしよりまでです。", scene=V("c20589889", 1.0)),
    dict(id="4-4", text="聞いたのは、時間の過ぎる速さです。", scene=V("c8061061", 1.0)),
    dict(id="4-5", text="「この1週間は、速く過ぎましたか」", scene=WD("「この1週間は", "【速く過ぎましたか】」", "速く")),
    dict(id="4-6", text="「この1か月は」「この1年は」", scene=WD("「この1か月は」", "【「この1年は」】", "1年")),
    dict(id="4-7", text="そして、「この10年は」", say="そして、このじゅうねんは。", scene=WD("そして", "【「この10年は」】", "この")),
    dict(id="4-8", text="とても遅いから、とても速いまで、5段階で答えます。", scene=C("scale")),
    dict(id="4-9", text="ジャネーの法則が正しければ、どの質問でも、年上ほど「速い」と答えるはずです。", scene=C("survey", "図: 理の書（模式図）"), fx=[ST(1, "年上")]),
    dict(id="4-10", text="体の時計の説でも、同じです。", fx=[NOTE(0.62, 0.22, "体の時計の説も同じ", "体の")]),
    dict(id="4-11", text="ところが、結果は違いました。", scene=V("c6672301", 1.0)),
    dict(id="4-12", text="この1週間、この1か月、この1年。", scene=C("survey", "図: 理の書（模式図）"), fx=[ST(2, "この")]),
    dict(id="4-13", text="速さの感じ方に、年齢による差はほとんどありませんでした。", fx=[NOTE(0.45, 0.30, "差はほとんどない", "差は")]),
    dict(id="4-14", text="14歳も70歳も、この1年を同じくらいの速さに感じていたのです。", say="じゅうよんさいも、ななじゅっさいも、このいちねんを、おなじくらいの、はやさに、かんじていたのです。", scene=V("c27333442", 4.0)),
    dict(id="4-15", text="差が出たのは、1つの質問だけでした。", scene=WD("差が出たのは", "【1つの質問だけ】", "1つ")),
    dict(id="4-16", text="「この10年は、速く過ぎましたか」", say="このじゅうねんは、はやく、すぎましたか。", scene=C("survey", "図: 理の書（模式図）"), fx=[ST(2, "この"), ST(3, "速く")]),
    dict(id="4-17", text="こちらは、年上ほど「速い」と答えました。", fx=[NOTE(0.40, 0.25, "年上ほど速い", "年上")]),
    dict(id="4-18", text="その差は59歳ごろまで大きくなり、60歳で止まります。", say="そのさは、ごじゅうきゅうさいごろまで、おおきくなり、ろくじゅっさいで、とまります。", fx=[NOTE(0.66, 0.42, "60歳で止まる", "60")]),
    dict(id="4-19", text="同じ結果は、オランダとニュージーランドでも出ました。", scene=V("c13587066", 1.0)),
    dict(id="4-20", text="日本でも、868人に聞いた調査で、同じ形が出ています。", say="にほんでも、はっぴゃくろくじゅうはちにんに、きいた、ちょうさで、おなじかたちが、でています。",
         scene=V("c36035831", 2.0, place=("日本", "868人の調査"))),
    dict(id="4-21", text="年を取っても、今の1週間は速くなっていない。", scene=V("c31423124", 3.0)),
    dict(id="4-22", text="ジャネーの法則も、体の時計の説も、ここで外れます。", scene=WD("ジャネーの法則も 体の時計も", "【ここで外れる】", "外れ")),
    dict(id="4-23", text="速くなるのは、10年を振り返ったときだけ。", say="はやくなるのは、じゅうねんを、ふりかえったときだけ。", scene=V("c10302167", 1.0)),
    dict(id="4-24", text="では、振り返ると、なぜ短くなるのか。", fx=[Q("なぜ短い？", "なぜ")]),
]
CH["ch5"] = [
    dict(id="5-1", text="時間の長さには、2つの感じ方があります。", scene=WD("時間の長さは", "【2つある】", "2つ")),
    dict(id="5-2", text="1つは、今まさに過ぎていく時間。", scene=V("c9160922", 9.0)),
    dict(id="5-3", text="待ち時間や、退屈な授業の長さです。", scene=V("c9068779", 10.0)),
    dict(id="5-4", text="もう1つは、あとから振り返って感じる長さです。", scene=V("c10302167", 10.0)),
    dict(id="5-5", text="この2つは、いつも同じとは限りません。", fx=[NOTE(0.5, 0.35, "いつも同じではない", "限りません")]),
    dict(id="5-6", text="それをはっきり示した実験があります。", scene=CARD_FALL),
    dict(id="5-7", text="2007年、アメリカの研究チームが、人を高い所から落としました。", say="にせんななねん、アメリカの、けんきゅうチームが、ひとを、たかいところから、おとしました。",
         scene=V("c11988849", 1.0, place=("アメリカ", "2007年の実験"))),
    dict(id="5-8", text="高さは31メートル。10階建てのビルほどの高さです。", say="たかさは、さんじゅういちメートル。じっかいだての、ビルほどの、たかさです。", scene=C("fall"), fx=[ST(1, "31")]),
    dict(id="5-9", text="背中から落ちて、下の網で受け止めます。", fx=[ST(1, "背中"), ST(2, "背中")]),
    dict(id="5-10", text="落ちている時間は、約2.5秒です。", say="おちているじかんは、やく、にてんごびょうです。", fx=[ST(1, "落ち"), NOTE(0.18, 0.40, "約2.5秒", "2.5")]),
    dict(id="5-11", text="腕には、数字が速く切り替わる小さな画面を付けました。", scene=V("c31968425", 2.0)),
    dict(id="5-12", text="ふだんの目では、速すぎて読めない数字です。", fx=[NOTE(0.5, 0.30, "速すぎて読めない", "読めない")]),
    dict(id="5-13", text="怖いときに時間がゆっくり見えるなら、落ちている間は読めるはず。", scene=V("c28000863", 2.0), fx=[Q("読める？", "読める")]),
    dict(id="5-14", text="結果、落ちている間も、数字は読めませんでした。", scene=WD("落ちている間も", "【読めなかった】", "読め")),
    dict(id="5-15", text="目に入る時間は、ゆっくりになっていなかったのです。", scene=V("c4476066", 2.0), fx=[DIM("なって")]),
    dict(id="5-16", text="ところが、落ちたあとに聞くと、", scene=V("c28639844", 1.0)),
    dict(id="5-17", text="自分の落下は、他の人の落下より【36%長かった】と答えました。", say="じぶんのらっかは、ほかのひとのらっかより、さんじゅうろくパーセント、ながかったと、こたえました。", scene=BARS_FALL),
    dict(id="5-18", text="長く感じたのは、落ちている最中ではなく、思い出したときでした。", scene=V("c10302167", 18.0)),
    dict(id="5-19", text="研究者は、こう考えました。", scene=V("c7103445", 1.0)),
    dict(id="5-20", text="怖い出来事は、細かいところまで記憶に残る。", scene=V("c11988849", 8.0), fx=[NOTE(0.5, 0.35, "細かく残る", "細かい")]),
    dict(id="5-21", text="記憶が多いほど、あとで長く感じるのだと。", scene=WD("記憶が多いほど", "【あとで長く感じる】", "長く")),
    dict(id="5-22", text="同じことは、旅行でも起きます。", scene=V("c34918624", 1.0)),
    dict(id="5-23", text="楽しい旅行は、行っている間はあっという間です。", scene=V("c39221415", 1.0)),
    dict(id="5-24", text="ところが帰ってから思い出すと、長い旅だったように感じる。", scene=V("c11272050", 1.0)),
    dict(id="5-25", text="イギリスで心理学を伝えるクローディア・ハモンドは、", scene=V("c6180856", 1.0)),
    dict(id="5-26", text="これを「休暇のパラドックス」と呼びました。", scene=CARD_HOLIDAY),
    dict(id="5-27", text="知らない町、初めての食べ物。新しい思い出が、毎日いくつも残るからです。", scene=V("c40352939", 1.0)),
    dict(id="5-28", text="頭は、思い出の数で、過ぎた時間の長さを測っているのです。", scene=WD("思い出の数で", "【時間の長さを測る】", "長さ")),
]
CH["ch6"] = [
    dict(id="6-1", text="では、子どものころの1年を思い出してみます。", scene=V("c11272050", 8.0)),
    dict(id="6-2", text="初めて自転車に乗れた日。", scene=V("c7844322", 1.0)),
    dict(id="6-3", text="初めての学校、初めての友だち。", scene=V("c31240469", 3.0)),
    dict(id="6-4", text="子どもの毎日は、初めてのことでいっぱいです。", scene=V("c8441312", 1.0)),
    dict(id="6-5", text="記憶がいちばん多く残るのは、10歳から30歳ごろだと分かっています。", say="きおくが、いちばんおおく、のこるのは、じゅっさいから、さんじゅっさいごろだと、わかっています。",
         scene=C("memory", "図: 理の書（模式図）"), fx=[ST(1, "記憶")]),
    dict(id="6-6", text="進学、仕事、引っ越し。初めてが続く時期です。", scene=V("c7205258", 1.0)),
    dict(id="6-7", text="大人になると、どうでしょう。", scene=V("c36035831", 5.0)),
    dict(id="6-8", text="同じ時間に起きて、同じ電車に乗る。", scene=V("c27454114", 2.0)),
    dict(id="6-9", text="同じ仕事をして、同じ道で帰る。", scene=V("c35140498", 2.0)),
    dict(id="6-10", text="毎日が似ていると、頭はそれを1つにまとめて覚えます。", scene=V("c31784578", 1.0)),
    dict(id="6-11", text="思い出に残る日が、少なくなるのです。", fx=[DIM("少なく")]),
    dict(id="6-12", text="2021年、さっきの調査を調べ直した研究があります。", say="にせんにじゅういちねん、さっきの、ちょうさを、しらべなおした、けんきゅうがあります。",
         scene=dict(kind="card", title="調べ直し", sub="2021年", body="2005年の調査の答えを、子どもがいるかどうかで分けて比べた。", src="Wittmann & Mella 2021")),
    dict(id="6-13", text="子どもがいる人は、いない人より、この10年を速く感じていました。", say="こどもがいるひとは、いないひとより、このじゅうねんを、はやく、かんじていました。", scene=V("c6262853", 2.0)),
    dict(id="6-14", text="子育てに追われる毎日は、自分の思い出が残りにくいのかもしれません。", fx=[Q("思い出が残りにくい？", "かもしれ", 0.35)]),
    dict(id="6-15", answer=True, text="大人の1年が短いのは、【初めて】が少ないからでした。", scene=WD("大人の1年が短いのは", "【「初めて」が少ないから】", "初めて")),
    dict(id="6-16", text="時計の時間は同じでも、思い出の数が違うのです。", scene=V("c9160922", 12.0)),
    dict(id="6-17", text="ジャネーの法則は、年と短さを結び付けました。", scene=CARD_JANET),
    dict(id="6-18", text="でも本当は、年を取って「初めて」が減ることが、1年を短くしていたのです。", scene=WD("年ではなく", "【「初めて」の数】", "初めて")),
    dict(id="6-19", text="だとすれば、大人の1年も、長くできます。", scene=V("c34918624", 8.0)),
    dict(id="6-20", text="行ったことのない町に行く。", scene=V("c39221415", 5.0)),
    dict(id="6-21", text="食べたことのないものを食べる。", scene=V("c40352939", 4.0)),
    dict(id="6-22", text="冒頭の夏休みに戻ります。", scene=V("c3969322", 12.0)),
    dict(id="6-23", text="あの夏が長かったのは、毎日が初めてだったからです。", scene=V("c4391957", 4.0)),
    dict(id="6-24", text="次に「今年は速かった」と思ったら、今年初めてしたことを数えてみてください。", scene=V("c2975799", 8.0)),
]
TITLES = dict(ch1="夏休みは永遠だった", ch2="答えの候補1 ジャネーの法則", ch3="答えの候補2 体の時計",
              ch4="ところが、速くなっていない", ch5="時間は2つある", ch6="答え")
MAPS = dict(ch4=dict(lat0=50, bases=[((0, 42, 24, 57), 5)]))

# ---- ショート(縦)--------------------------------------------------------------------------------------
SH = {}
SH["s1"] = [
    dict(id="1", open="belief", text="年を取るほど、1年が速くなる。そう聞いたことはありませんか。", scene=V("c27333442", 1.0)),
    dict(id="2", text="よく持ち出されるのが、ジャネーの法則です。", scene=CARD_JANET),
    dict(id="3", text="1年は、5歳の子には人生の5分の1、50歳の人には50分の1。", say="いちねんは、ごさいのこには、じんせいの、ごぶんのいち、ごじゅっさいのひとには、ごじゅうぶんのいち。",
         scene=C("life"), fx=[ST(1, "5歳"), ST(2, "50歳")]),
    dict(id="4", text="ところが、これが正しいなら、1週間も1か月も速くなるはず。", scene=V("c9160922", 2.0), fx=[Q("1週間も？", "1週間")]),
    dict(id="5", text="50歳の1週間は、5歳の子の1日にも届かない計算です。", scene=WD("50歳の1週間は", "【5歳の1日にも届かない】", "1日")),
    dict(id="6", text="本当に、そうでしょうか。", scene=V("c34509926", 3.0), fx=[Q("本当？", "本当")]),
    dict(id="7", text="2005年、14歳から94歳の499人に聞いた調査があります。", say="にせんごねん、じゅうよんさいから、きゅうじゅうよんさいの、よんひゃくきゅうじゅうきゅうにんに、きいた、ちょうさがあります。", scene=V("c8061061", 1.0)),
    dict(id="8", text="この1週間、この1か月、この1年は、速く過ぎましたか。", scene=WD("この1週間・1か月・1年は", "【速く過ぎましたか】", "速く")),
    dict(id="9", text="ところが、年齢による差はほとんどありませんでした。", scene=C("survey", "図: 理の書（模式図）"), fx=[ST(2, "ところが")]),
    dict(id="10", text="差が出たのは、「この10年」を振り返る質問だけ。", say="さがでたのは、このじゅうねんを、ふりかえる、しつもんだけ。", fx=[ST(2, "差が"), ST(3, "この")]),
    dict(id="11", answer=True, text="年を取って速くなるのは、今の時間ではなく、振り返った時間だったのです。", scene=WD("速くなるのは", "【振り返った時間】", "振り返")),
]
SH["s2"] = [
    dict(id="1", open="scene", text="1930年代のアメリカ。ある研究者の妻が、インフルエンザで寝込みました。", say="せんきゅうひゃくさんじゅうねんだいの、アメリカ。あるけんきゅうしゃの、つまが、インフルエンザで、ねこみました。", scene=V("c7423531", 1.0)),
    dict(id="2", text="少し部屋を離れただけなのに、妻は「長かった」と言います。", scene=V("c5239286", 1.0)),
    dict(id="3", text="研究者は頼みました。時計の秒針と同じ速さで、60まで数えてほしい。", say="けんきゅうしゃは、たのみました。とけいのびょうしんと、おなじはやさで、ろくじゅうまで、かぞえてほしい。", scene=PH("p19730401")),
    dict(id="4", text="それをストップウォッチで測り、熱も測ります。", scene=V("c5858754", 2.0)),
    dict(id="5", text="熱が高いときほど、妻は速く数えました。", scene=WD("熱が高いほど", "【速く数えた】", "速く")),
    dict(id="6", text="妻の「1分」は、本当の1分より短かったのです。", say="つまのいっぷんは、ほんとうのいっぷんより、みじかかったのです。", scene=C("minute", "図: 理の書（模式図）"), fx=[ST(1, "妻の"), ST(2, "本当")]),
    dict(id="7", text="なぜか。", fx=[Q("なぜ？", "なぜ", 0.40)]),
    dict(id="8", text="研究者は、体の中に時計があると考えました。", scene=V("c39488470", 1.0)),
    dict(id="9", text="熱で体の中の働きが速まると、その時計も速く進む。", fx=[NOTE(0.5, 0.40, "熱で速く進む", "速く進む")]),
    dict(id="10", answer=True, text="体の時計が速いと、外の時間はゆっくりに感じる。だから待つ時間が長かったのです。", scene=WD("体の時計が速いと", "【外の時間はゆっくり】", "ゆっくり")),
    dict(id="11", text="熱を出した日の午後が長いのは、このせいかもしれません。", scene=V("c7423531", 6.0)),
]
SH["s3"] = [
    dict(id="1", open="belief", text="怖いとき、時間がゆっくりに見える。そう言われます。", scene=V("c11988849", 1.0)),
    dict(id="2", text="2007年、それを確かめるために、人を31メートルの高さから落とした実験があります。", say="にせんななねん、それをたしかめるために、ひとを、さんじゅういちメートルの、たかさから、おとした、じっけんがあります。", scene=CARD_FALL),
    dict(id="3", text="10階建てのビルほどの高さです。", say="じっかいだての、ビルほどの、たかさです。", scene=C("fall"), fx=[ST(1, "10階")]),
    dict(id="4", text="背中から落ちて、網で受け止めます。", fx=[ST(1, "背中"), ST(2, "背中")]),
    dict(id="5", text="ところが、腕に付けた速い数字の画面は、落ちている間も読めませんでした。", scene=V("c31968425", 2.0)),
    dict(id="6", text="時間がゆっくり見えていたなら、読めたはずです。", fx=[Q("読める？", "読めた", 0.40)]),
    dict(id="7", text="目に入る時間は、ゆっくりになっていなかったのです。", scene=WD("落ちている間は", "【読めなかった】", "なって")),
    dict(id="8", text="それなのに落ちたあとには、自分の落下を、他の人の落下より36%長く感じたと答えました。", say="ところが、おちたあとには、じぶんのらっかを、ほかのひとのらっかより、さんじゅうろくパーセント、ながくかんじたと、こたえました。", scene=BARS_FALL),
    dict(id="9", text="長く感じたのは、落ちている最中ではなかったのです。", scene=V("c4476066", 2.0), fx=[DIM("なかった")]),
    dict(id="10", answer=True, text="怖い出来事は細かく記憶に残る。その記憶の多さが、あとで時間を長く感じさせていました。", scene=WD("記憶の多さが", "【時間を長くした】", "多さ")),
]
SH["s4"] = [
    dict(id="1", open="scene", text="楽しい旅行は、あっという間に終わります。", scene=V("c34918624", 1.0)),
    dict(id="2", text="ところが帰ってから思い出すと、長い旅だったように感じる。", scene=V("c11272050", 1.0)),
    dict(id="3", text="これは「休暇のパラドックス」と呼ばれています。", scene=CARD_HOLIDAY),
    dict(id="4", text="なぜ、短いのに長いのか。", scene=V("c39221415", 1.0), fx=[Q("なぜ？", "なぜ", 0.40)]),
    dict(id="5", text="時間の感じ方は、2つあります。", scene=WD("時間の感じ方は", "【2つ】", "2つ")),
    dict(id="6", text="今まさに過ぎていく時間と、あとで振り返る時間です。", scene=V("c9160922", 4.0)),
    dict(id="7", text="旅行中は楽しくて、時計を見ません。だから今の時間は速い。", scene=V("c39221415", 6.0)),
    dict(id="8", text="でも旅先では、知らない町、初めての食べ物。新しい思い出が毎日いくつも残ります。", scene=V("c40352939", 1.0)),
    dict(id="9", answer=True, text="頭は、思い出の数で、過ぎた時間の長さを測っているのです。", scene=WD("思い出の数で", "【時間の長さを測る】", "長さ")),
    dict(id="10", text="いつもの1週間は、似た毎日が1つにまとまって、短く思い出されます。", scene=V("c36035831", 1.0)),
    dict(id="11", text="いつもの1週間と同じ7日でも、旅行の7日は長く思い出されるのです。", say="いつものいっしゅうかんと、おなじなのかでも、りょこうのなのかは、ながく、おもいだされるのです。", scene=V("c34918624", 8.0)),
]
STITLES = dict(s1="年を取ると1年が速い、は本当か", s2="熱があると、1分が短くなる", s3="怖い時間は、なぜ長く感じる", s4="旅行は短いのに、あとで長い")


def ep_for(key: str) -> dict:
    if key.startswith("ch"):
        d = dict(kind="stage", title=TITLES[key], qtag=QTAG, colors=COLORS, lines=CH[key])
        if key in MAPS:
            d["map"] = MAPS[key]
        return d
    return dict(kind="stage", title=STITLES[key], qtag=STITLES[key], colors=COLORS, lines=SH[key])
