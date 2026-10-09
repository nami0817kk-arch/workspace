# -*- coding: utf-8 -*-
"""立ち絵。**1人1枚の絵の、口・目・眉だけを差し替える。**

2026-10-09 に作り直した。それまでは表情ごとに19枚の絵を持っていたが、
口が動かず、表情ごとに顔の大きさも違った（幅753〜836px）。いまは

    立ち絵1枚（口を閉じ、目を開けた状態）＋ パーツ（口3・目4・眉4）

を組み合わせる。パーツは Gemini に「横一列に並べた1枚」として描かせ、
切り出してある（`assets/characters/parts/<who>/`）。

    face(who, mouth=0, eye="open", brow="normal")   … 表情を作る
    load(who, h)                                     … 高さを指定して読む

**位置はキャラごとに実測して POS に書く。** 目で読むと外す
（口の幅を70pxと読んで、実際は38pxだった。2026-10-09）。連結成分で測ること。
"""
from __future__ import annotations

from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

BASE = Path(r"C:/Users/なみ/dev/output/yononaka-danmen/assets/characters")

# キャラごとの位置。すべて立ち絵の画素で、連結成分で実測した値
POS = {
    "katari": {
        "size": (409, 526),
        "mouth_cx": 204, "mouth_w": 46,
        "mouth_top": {1: 209, 2: 206, 3: 202},     # 開くほど上唇が上がる
        "mouth_box": (181, 203, 227, 230),         # 元の口（消す範囲）
        "eye_l": (166, 140), "eye_r": (242, 140), "eye_w": 38,
        "eye_box": [(146, 132, 187, 151), (222, 132, 263, 151)],
        "brow_l": (167, 122), "brow_r": (240, 122), "brow_w": 52,
        "brow_box": [(138, 113, 197, 131), (211, 113, 270, 131)],
        "glasses": (125, 118, 292, 162),           # 眼鏡を取り分ける範囲（無ければ None）
    },
}
# 口の段階（1 小 / 2 中 / 3 大）。大きく開いた1枚を縦に潰して作る
SQUASH = {1: 0.20, 2: 0.52, 3: 1.0}
_cache: dict = {}


def _biggest(im: Image.Image, box=None, thr=110) -> Image.Image:
    """いちばん大きな暗い塊だけを抜き出す（眼鏡のフレームなど）。"""
    x0, y0, x1, y1 = box or (0, 0, im.width, im.height)
    px = im.load()
    w = x1 - x0
    seen = bytearray(w * (y1 - y0))
    best: list = []

    def dark(x, y):
        r, g, b, a = px[x, y]
        return a > 60 and (r + g + b) / 3 < thr

    for sy in range(y0, y1):
        for sx in range(x0, x1):
            if seen[(sy - y0) * w + (sx - x0)] or not dark(sx, sy):
                continue
            pts, q = [], deque([(sx, sy)])
            seen[(sy - y0) * w + (sx - x0)] = 1
            while q:
                x, y = q.popleft()
                pts.append((x, y))
                for nx, ny in ((x+1, y), (x-1, y), (x, y+1), (x, y-1)):
                    if x0 <= nx < x1 and y0 <= ny < y1 \
                            and not seen[(ny-y0)*w + (nx-x0)] and dark(nx, ny):
                        seen[(ny-y0)*w + (nx-x0)] = 1
                        q.append((nx, ny))
            if len(pts) > len(best):
                best = pts
    layer = Image.new("RGBA", im.size, (0, 0, 0, 0))
    lp = layer.load()
    for x, y in best:
        lp[x, y] = px[x, y]
    return layer


def _body(p: Image.Image) -> Image.Image:
    """パーツから、いちばん大きな塊だけ残す（口のあごの線などを捨てる）。

    **目には使わない。** 白目が別の塊なので捨てられる（2026-10-09 に踏んだ）。
    """
    w, h = p.size
    px = p.load()
    seen = bytearray(w * h)
    best: list = []
    for sy in range(h):
        for sx in range(w):
            if seen[sy*w+sx] or px[sx, sy][3] < 8:
                continue
            pts, q = [], deque([(sx, sy)])
            seen[sy*w+sx] = 1
            while q:
                x, y = q.popleft()
                pts.append((x, y))
                for nx, ny in ((x+1, y), (x-1, y), (x, y+1), (x, y-1)):
                    if 0 <= nx < w and 0 <= ny < h and not seen[ny*w+nx] and px[nx, ny][3] >= 8:
                        seen[ny*w+nx] = 1
                        q.append((nx, ny))
            if len(pts) > len(best):
                best = pts
    out = Image.new("RGBA", p.size, (0, 0, 0, 0))
    op = out.load()
    for x, y in best:
        op[x, y] = px[x, y]
    bb = out.getbbox()
    return out.crop(bb) if bb else out


def _erase(im: Image.Image, box, skin_at=None) -> Image.Image:
    """その範囲を肌の色で塗る。

    **肌の色をどこから取るかが肝**（2026-10-09 に2度外した）。
    既定は「すぐ下」だが、眉は下が眼鏡なので真っ黒になり、横は顔の外の髪を拾う。
    眉のように挟まれている所は、鼻筋の側から取る。
    """
    out = im.copy()
    px = out.load()
    x0, y0, x1, y1 = box
    skin = px[skin_at] if skin_at else px[(x0 + x1) // 2, min(y1 + 4, im.height - 1)]
    for y in range(y0, y1):
        for x in range(x0, x1):
            px[x, y] = skin
    r = out.crop((x0-2, y0-2, x1+2, y1+2)).filter(ImageFilter.GaussianBlur(0.8))
    out.paste(r, (x0-2, y0-2))
    return out


def base(who: str) -> Image.Image:
    key = ("base", who)
    if key not in _cache:
        _cache[key] = Image.open(BASE / (who + ".png")).convert("RGBA")
    return _cache[key]


def _part(who: str, name: str) -> Image.Image:
    key = ("part", who, name)
    if key not in _cache:
        p = Image.open(BASE / "parts" / who / (name + ".png")).convert("RGBA")
        _cache[key] = p.crop(p.getbbox())
    return _cache[key]


def _glasses(who: str) -> Image.Image | None:
    g = POS[who].get("glasses")
    if not g:
        return None
    key = ("glass", who)
    if key not in _cache:
        _cache[key] = _biggest(base(who), g)
    return _cache[key]


def face(who: str, mouth=0, eye: str = "open", brow: str = "normal") -> Image.Image:
    """口・目・眉を差し替えた顔を返す。

    mouth … 0 閉じ / 1 小 / 2 中 / 3 大 / "smile" / "frown"
    eye   … open / half / shut / wide
    brow  … normal / up / angry / sad
    """
    P, im = POS[who], base(who).copy()

    # --- 眉 ---------------------------------------------------------------
    if brow != "normal":
        # 眉は上が髪、下が眼鏡。**鼻筋の側の肌**から色を取る
        for i, b in enumerate(P["brow_box"]):
            x = (b[2] + 7) if i == 0 else (b[0] - 7)
            im = _erase(im, b, skin_at=(x, (b[1] + b[3]) // 2))
        p = _body(_part(who, "brow_" + ("normal" if brow == "up" else brow)))
        # **パーツは左右が逆**（そのまま貼ると、真剣が困り顔になる。2026-10-09）
        p = p.transpose(Image.FLIP_LEFT_RIGHT)
        p = p.resize((P["brow_w"], max(int(p.height * P["brow_w"] / p.width), 1)), Image.LANCZOS)
        # 驚きは、ふつうの眉を上にずらす（up のパーツは normal とほぼ同じだった）
        dy = -4 if brow == "up" else 0
        for c, flip in ((P["brow_l"], False), (P["brow_r"], True)):
            q = p.transpose(Image.FLIP_LEFT_RIGHT) if flip else p
            im.alpha_composite(q, (c[0] - q.width // 2, c[1] - q.height // 2 + dy))

    # --- 目 ---------------------------------------------------------------
    if eye != "open":
        if eye == "wide":
            # **見開いた目のパーツは黒目が小さく、白目だらけになる**（2026-10-09）。
            # 元の目を縦に伸ばすと、黒目も一緒に大きくなって驚いて見える
            p = _part(who, "eye_open")
            p = p.resize((p.width, int(p.height * 1.28)), Image.LANCZOS)
        else:
            p = _part(who, "eye_" + eye)
        s = P["eye_w"] / p.width
        p = p.resize((max(int(p.width*s), 1), max(int(p.height*s), 1)), Image.LANCZOS)
        # **閉じ目はパーツが薄いので、高さに合わせると元の目が残って二重になる。**
        # 閉じるときは全部消す。半目はパーツの高さに合わせる（広いと下に肌色の帯）
        top = P["eye_l"][1] - p.height // 2
        for b in P["eye_box"]:
            box = b if eye == "shut" else (b[0], max(b[1], top), b[2], min(b[3], top + p.height))
            im = _erase(im, box)
        for c, flip in ((P["eye_l"], False), (P["eye_r"], True)):
            q = p.transpose(Image.FLIP_LEFT_RIGHT) if flip else p
            im.alpha_composite(q, (c[0] - q.width // 2, c[1] - q.height // 2))
        g = _glasses(who)
        if g:
            im.alpha_composite(g)        # 眼鏡は目の上に戻す

    # --- 口 ---------------------------------------------------------------
    if mouth == "smile":
        return _smile(who, im)
    if mouth == "frown":
        return _frown(who, im)
    if mouth:
        p = _body(_part(who, "mouth_open"))
        k = SQUASH[mouth]
        if k < 1.0:
            p = p.resize((p.width, max(int(p.height * k), 1)), Image.LANCZOS)
        s = P["mouth_w"] / p.width
        p = p.resize((max(int(p.width*s), 1), max(int(p.height*s), 1)), Image.LANCZOS)
        top = P["mouth_top"][mouth]
        # **薄く開いた口は元の下唇を覆いきれない。** はみ出る分だけ消す
        bx = P["mouth_box"]
        if top + p.height < bx[3]:
            px = im.load()
            skin = px[bx[2] + 6, (bx[1] + bx[3]) // 2]
            for y in range(max(top + p.height, bx[1]), bx[3]):
                for x in range(bx[0], bx[2]):
                    px[x, y] = skin
        im.alpha_composite(p, (P["mouth_cx"] - p.width // 2, top))
    return im


def _smile(who: str, im: Image.Image) -> Image.Image:
    """口角を上げる。**元の口の線だけを取り出して、端ほど上へずらす。**

    弧を描くと元の口（上唇が2本・中央にくぼみ）と形が変わり、
    1pxずつ整数でずらすと階段状になり、肌ごと動かすと継ぎ目が弧の筋になった
    （2026-10-09 に3つとも踏んだ）。線だけを高い解像度でずらすのが正解。
    """
    X0, Y0, X1, Y1 = POS[who]["mouth_box"]
    raw = base(who).crop((X0, Y0, X1, Y1))
    line = Image.new("RGBA", raw.size, (0, 0, 0, 0))
    rp, lp = raw.load(), line.load()
    for y in range(raw.height):
        for x in range(raw.width):
            r, g, b, a = rp[x, y]
            if a > 60 and (r + g + b) / 3 < 185:
                lp[x, y] = (r, g, b, a)
    px = im.load()
    skin = px[X1 + 6, (Y0 + Y1) // 2]
    for y in range(Y0, Y1):
        for x in range(X0, X1):
            px[x, y] = skin
    K, PAD = 4, 8
    big = line.resize((line.width * K, line.height * K), Image.LANCZOS)
    lay = Image.new("RGBA", (big.width, big.height + PAD * K), (0, 0, 0, 0))
    for x in range(big.width):
        t = abs(x - (big.width - 1) / 2) / ((big.width - 1) / 2)
        lay.alpha_composite(big.crop((x, 0, x + 1, big.height)),
                            (x, PAD * K - int(round(2.5 * K * t * t))))
    lay = lay.resize((line.width, line.height + PAD), Image.LANCZOS)
    im.alpha_composite(lay, (X0, Y0 - PAD))
    return im


def _frown(who: str, im: Image.Image) -> Image.Image:
    """への字。**4倍で描いてから縮める**（直に描くとギザギザ）。"""
    x0, y0, x1, y1 = POS[who]["mouth_box"]
    px = im.load()
    skin = px[x1 + 6, (y0 + y1) // 2]
    for y in range(y0, y1):
        for x in range(x0, x1):
            px[x, y] = skin
    K = 4
    lay = Image.new("RGBA", ((x1-x0) * K, (y1-y0) * K), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    cx, yc = (POS[who]["mouth_cx"] - x0) * K, (213 - y0) * K
    half = 19 * K
    d.arc([cx-half, yc-2*K, cx+half, yc+12*K], 208, 332, fill=(68, 49, 37, 255), width=2*K)
    d.arc([cx-9*K, yc+6*K, cx+9*K, yc+15*K], 35, 145, fill=(120, 98, 88, 255), width=2*K)
    im.alpha_composite(lay.resize((x1-x0, y1-y0), Image.LANCZOS), (x0, y0))
    return im


def load(who: str, height: int, mouth=0, eye: str = "open", brow: str = "normal") -> Image.Image:
    """表情を作って、指定の高さに縮める。"""
    im = face(who, mouth, eye, brow)
    s = height / im.height
    return im.resize((max(int(im.width * s), 1), height), Image.LANCZOS)
