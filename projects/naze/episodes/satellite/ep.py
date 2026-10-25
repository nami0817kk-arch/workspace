"""計算の回「人工衛星はなぜ落ちてこないのか」(ニュートンの大砲)。

弾の道すじは、地球の重力(GM = 398600.4418 km³/s²、半径 6371 km)で 0.5 秒刻みに自分で計算したもの。空気の抵抗は無し。
高さ 100 km から水平に撃つと: 秒速2km → 約300km先、5km → 約930km先、7km → 約2,230km先、7.85km → 落ちずに一周(約86分)。
国際宇宙ステーション: 高さ約400km、新幹線(時速300km)の約92倍、秒速約7.7km(NASA は時速約17,500マイル = 秒速約7.8km)、約90分で一周。
  https://www.nasa.gov/international-space-station/space-station-facts-and-figures/
ニュートンの大砲: ニュートン『世界の体系について』(A Treatise of the System of the World, 1728)の思考実験。
"""
from __future__ import annotations

import math

from PIL import ImageDraw

from naze import overlay as O

GM, R, ALT = 398600.4418, 6371.0, 100.0
V_ORBIT = math.sqrt(GM / (R + ALT))


def fly(v: float, dt: float = 0.5, tmax: float = 6000.0):
    """水平に撃った弾の道すじ [(t, x, y)](km、地球の中心が原点、発射点は真上)。地面に届いたら止める。"""
    x, y, vx, vy, t = 0.0, R + ALT, v, 0.0, 0.0
    out = [(t, x, y)]
    while t < tmax:
        r = math.hypot(x, y)
        a = -GM / r ** 3
        vx += a * x * dt
        vy += a * y * dt
        x += vx * dt
        y += vy * dt
        t += dt
        out.append((t, x, y))
        if math.hypot(x, y) < R:
            break
    return out


SHOTS = {"v2": fly(2.0), "v5": fly(5.0), "v7": fly(7.0), "vo": fly(V_ORBIT, tmax=2 * math.pi * (R + ALT) / V_ORBIT)}
COL = {"v2": O.BLUE, "v5": O.GREEN, "v7": O.OCHRE, "vo": O.YEL}
SPEED = {"v2": "2", "v5": "5", "v7": "7", "vo": "7.8"}
DIST = {"v2": "約300km", "v5": "約900km", "v7": "約2,200km"}

# 見せ方: (1km あたりの画素, 画面の中心に来る点 km)
NEAR = (0.95, (450.0, R - 60.0))
MID = (0.36, (1150.0, R - 380.0))
FAR = (0.075, (0.0, 1870.0))       # 地球を少し下へ(上に数字の札を置く)
QV = (0.058, (0.0, 6700.0))         # 問いの文字の下に地球
VIEW = dict(q=QV, ans=QV, setup=NEAR, v2=NEAR, v5=NEAR, key=MID, v7=MID, vo=FAR, orbit=FAR, iss=FAR, end=FAR)
CX, CY = 540, 860

EP = dict(
    kind="sim",
    title="人工衛星はなぜ落ちてこないのか",
    header="人工衛星はなぜ【落ちない】？",
    credit="道すじは地球の重力で計算（空気の抵抗なし）",
    lines=[
        dict(id="q", text="人工衛星は、なぜ落ちてこないの？", sub="人工衛星は\nなぜ【落ちて】\nこないの？", style="question"),
        dict(id="ans", text="答えは、ものすごい速さで、横に飛んでいるから。大砲で確かめてみましょう。",
             sub="答えは、ものすごい速さで\n【横に飛んでいる】から。|大砲で確かめてみましょう。"),
        dict(id="setup", text="高い山の上から、弾をまっすぐ横に撃ちます。山の高さは100km、空気はないことにします。",
             sub="高い山の上から、\n弾を【まっすぐ横】に撃ちます。|山の高さは100km、\n空気はないことにします。",
             say="たかいやまのうえから、たまを、まっすぐよこに、うちます。やまのたかさは、ひゃっキロ、くうきは、ないことにします。"),
        dict(id="v2", text="ゆっくり撃つと、すぐ落ちます。秒速2kmで、300km先。", sub="ゆっくり撃つと、すぐ落ちます。\n秒速2kmで、【300km】先。",
             say="ゆっくりうつと、すぐおちます。びょうそく、にキロで、さんびゃっキロさき。"),
        dict(id="v5", text="もっと速く。秒速5kmだと、900km先まで飛びました。", sub="もっと速く。\n秒速5kmだと、【900km】先まで飛びました。",
             say="もっとはやく。びょうそく、ごキロだと、きゅうひゃっキロさきまで、とびました。"),
        dict(id="key", text="ここで大事なのは、地球が丸いこと。弾が遠くへ行くほど、地面はカーブして下がっていきます。",
             sub="ここで大事なのは、地球が【丸い】こと。|弾が遠くへ行くほど、\n地面はカーブして【下がって】いきます。"),
        dict(id="v7", text="秒速7kmなら、2200km先。弾が落ちる分と、地面が下がる分が、近くなってきました。",
             sub="秒速7kmなら、【2,200km】先。|弾が落ちる分と、地面が下がる分が、\n【近く】なってきました。",
             say="びょうそく、ななキロなら、にせんにひゃっキロさき。たまがおちるぶんと、じめんがさがるぶんが、ちかくなってきました。"),
        dict(id="vo", text="そして秒速7.8km。弾が落ちる分だけ、地面も下がる。だから、いつまでたっても地面に届きません。",
             sub="そして秒速7.8km。|弾が落ちる分だけ、\n【地面も下がる】。|だから、いつまでたっても\n【地面に届きません】。",
             say="そして、びょうそく、ななてんはちキロ。たまがおちるぶんだけ、じめんも、さがる。だから、いつまでたっても、じめんに、とどきません。"),
        dict(id="orbit", text="弾はそのまま、地球を一周しました。これが人工衛星です。", sub="弾はそのまま、地球を【一周】。\nこれが【人工衛星】です。"),
        dict(id="iss", text="宇宙ステーションも同じ。新幹線のおよそ90倍の速さで、90分で地球を一周しています。",
             sub="宇宙ステーションも同じ。|新幹線のおよそ【90倍】の速さで、\n【90分】で地球を一周しています。",
             say="うちゅうステーションも、おなじ。しんかんせんの、およそ、きゅうじゅうばいの、はやさで、きゅうじゅっぷんで、ちきゅうを、いっしゅうしています。"),
        dict(id="end", text="落ちていないのではなく、落ちながら、地面をよけ続けている。それが人工衛星です。",
             sub="落ちながら、\n【地面をよけ続けている】。", style="end"),
    ],
)


def _ease(u: float) -> float:
    u = max(0.0, min(1.0, u))
    return u * u * (3 - 2 * u)


def _view(ctx, t):
    """今の見せ方。行の頭の 1 秒で前の行の見せ方から移る(拡大率は対数で補間)。"""
    lines = ctx["lines"]
    cur = ctx["cur"] or lines[0]
    i = next(j for j, l in enumerate(lines) if l["id"] == cur["id"])
    now = VIEW[cur["id"]]
    prev = VIEW[lines[i - 1]["id"]] if i > 0 else now
    u = _ease((t - cur["start"]) / 1.0)
    s = math.exp(math.log(prev[0]) + (math.log(now[0]) - math.log(prev[0])) * u)
    c = (prev[1][0] + (now[1][0] - prev[1][0]) * u, prev[1][1] + (now[1][1] - prev[1][1]) * u)
    return s, c


def _shot_k(ctx, sid, t):
    """その弾の進み 0〜1(撃つ行の 0.1〜0.85 で飛ぶ)。撃つ前は None。"""
    L = ctx["L"]
    t0 = L[sid]["start"]
    t1 = L["orbit"]["end"] if sid == "vo" else L[sid]["end"]     # 一周は「届きません」と「一周しました」の2行かけて回る
    if t < t0:
        return None
    return _ease((t - t0 - 0.1 * (t1 - t0)) / (0.75 * (t1 - t0)))


def draw(img, dr: ImageDraw.ImageDraw, t: float, ctx) -> None:
    s, (vx, vy) = _view(ctx, t)

    def P(x, y):
        return CX + (x - vx) * s, CY - (y - vy) * s

    cid = ctx["cur"]["id"] if ctx["cur"] else "q"
    # 宇宙と地球
    ex, ey = P(0, 0)
    rr = R * s
    dr.ellipse([ex - rr - 10, ey - rr - 10, ex + rr + 10, ey + rr + 10], fill=(24, 44, 90))
    dr.ellipse([ex - rr, ey - rr, ex + rr, ey + rr], fill=(40, 110, 80), outline=(120, 200, 150), width=4)
    # 山(高さ 100km。遠景では見えないので最小の大きさを持たせる)
    hx, hy = P(0, R + ALT)
    bx, by = P(0, R)
    mh = max(by - hy, 14)
    dr.polygon([(bx - mh * 0.9, by + 2), (bx, by - mh), (bx + mh * 0.9, by + 2)], fill=(150, 130, 100), outline=(220, 200, 160))
    dr.rectangle([bx - 6, by - mh - 8, bx + 10, by - mh + 2], fill=(60, 60, 70))

    # 「まっすぐ進むと」と地面の逃げ方(key の行だけ)
    if cid == "key":
        k = ctx["k"]
        x1 = 2600 * _ease(k / 0.5)
        a, b = P(0, R + ALT), P(x1, R + ALT)
        for j in range(0, int(math.dist(a, b)), 28):
            f0, f1 = j / math.dist(a, b), min(1.0, (j + 16) / math.dist(a, b))
            dr.line([(a[0] + (b[0] - a[0]) * f0, a[1]), (a[0] + (b[0] - a[0]) * f1, a[1])], fill=O.WHITE, width=5)
        f = O.font(40)
        dr.text((P(1200, R + ALT)[0] - 120, a[1] - 64), "まっすぐ進むと…", font=f, fill=O.WHITE, stroke_width=4, stroke_fill=O.NAVY)
        if k > 0.45:
            gx = 2300
            top = P(gx, R + ALT)
            ang = math.asin(gx / R)
            gnd = P(R * math.sin(ang), R * math.cos(ang))
            dr.line([top, gnd], fill=O.RED, width=6)
            dr.polygon([(gnd[0] - 14, gnd[1] - 22), (gnd[0] + 14, gnd[1] - 22), (gnd[0], gnd[1])], fill=O.RED)
            dr.text((top[0] - 230, (top[1] + gnd[1]) / 2 - 24), "地面は下へ", font=f, fill=O.RED, stroke_width=4, stroke_fill=O.NAVY)

    # 弾の道すじ(撃った順に残す。今の弾だけ明るく、玉を描く)
    for sid in ("v2", "v5", "v7", "vo"):
        k = _shot_k(ctx, sid, t)
        if k is None:
            continue
        path = SHOTS[sid]
        n = max(2, int(len(path) * k))
        pts = [P(x, y) for _, x, y in path[:n:2]] + [P(path[n - 1][1], path[n - 1][2])]
        live = cid == sid or (sid == "vo" and cid == "orbit")
        col = COL[sid] if live else tuple(int(c * 0.55) for c in COL[sid])
        dr.line(pts, fill=col, width=7 if live else 5, joint="curve")
        if live or (sid == "vo" and cid in ("iss", "end")):
            px, py = pts[-1]
            if sid == "vo" and cid in ("iss", "end"):
                # 一周したあとは衛星として回り続ける
                L = ctx["L"]
                tt = (t - L["orbit"]["end"]) * 2 * math.pi / 8.0
                px, py = P(-(R + ALT) * math.sin(-tt), (R + ALT) * math.cos(tt))
            dr.ellipse([px - 13, py - 13, px + 13, py + 13], fill=O.WHITE, outline=col, width=5)
        if sid != "vo" and k >= 1.0:
            lx, ly = pts[-1]
            dr.ellipse([lx - 9, ly - 9, lx + 9, ly + 9], fill=col)
            if cid in ("v2", "v5", "key", "v7") and (live or s > 0.3):
                f = O.font(44 if live else 34)
                dr.text((lx - f.getlength(DIST[sid]) / 2, ly + 22), DIST[sid], font=f, fill=COL[sid] if live else O.DIM, stroke_width=4, stroke_fill=O.NAVY)

    # 問いの行: 地球を回る衛星
    if cid in ("q", "ans"):
        tt = t * 2 * math.pi / 6.0
        px, py = P((R + 900) * math.sin(tt), (R + 900) * math.cos(tt))
        dr.ellipse([px - 14, py - 14, px + 14, py + 14], fill=O.WHITE, outline=O.YEL, width=5)

    # 速さの札
    if cid in SPEED:
        f = O.font(110)
        txt = f"秒速 {SPEED[cid]} km"
        dr.text((CX - f.getlength(txt) / 2, 250), txt, font=f, fill=COL[cid], stroke_width=8, stroke_fill=O.NAVY)
    elif cid == "iss":
        f = O.font(64)
        for j, txt in enumerate(["新幹線の 約90倍", "秒速 約8km", "一周 約90分"]):
            dr.text((CX - f.getlength(txt) / 2, 240 + j * 90), txt, font=f, fill=O.YEL, stroke_width=6, stroke_fill=O.NAVY)
