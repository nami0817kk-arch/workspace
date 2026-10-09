# -*- coding: utf-8 -*-
"""立ち絵。**顔のパーツが無い「のっぺらぼう」に、目・眉・口を貼って表情を作る。**

2026-10-09 に、この形に落ち着いた。それまでは完成した顔の目や口を肌の色で
塗りつぶしてから貼っていたが、**消す処理が全ての不具合の元**だった。

  ・肌の色をどこから取るかで、眼鏡の黒や髪の黒を拾って真っ黒になる
  ・消す矩形がパーツより大きいと、四角い跡が出る
  ・小さいと元の目が残って二重になる

のっぺらぼうを土台にすれば、**貼るだけ**で済む。岬と小倉で合わせて30回以上
直したが、この一手で全部消えた（ユーザーの発案）。

    face(who, mouth=0, eye="normal", brow="normal")  … 表情を作る
    load(who, h, ...)                                 … 高さを指定して読む

**肝は `_skin_out()`。** パーツには肌の部分も写り込んでいるので、のっぺらぼうの
同じ位置と色を比べ、近ければ透明にする。これをしないと四角い継ぎ目が出る。
縁をぼかす手もあるが、**パーツまで薄くなる**のでだめだった。

**位置はキャラごとに実測して POS に書く。** 目で読むと外し、連結成分で測ると
髪を拾う。**目盛りを画像に描いて読む**のが確実（2026-10-09）。
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

BASE = Path(r"C:/Users/なみ/dev/output/yononaka-danmen/assets/characters")

POS = {
    "kikite": {
        "blank": "kikite_blank.png",
        "size": (479, 718),
        # 貼り位置（パーツの左上の座標）。目盛りを引いて実測した
        "eye_l": (152, 183), "eye_r": (258, 183),
        "brow_l": (162, 155), "brow_r": (253, 155),
        "mouth": (198, 276),
        # 開いた口は縦に伸びるので、段階ごとに上へずらす
        "mouth_lift": {1: 2, 2: 6, 3: 14},
        "skin_tol": 70,          # これより色が近ければ肌とみなして透明にする
        # **パーツの元の大きさがばらばら**（切り出した「ふつう」は58px、
        # Gemini のものは158px）。貼る前にこの幅に揃える（2026-10-09）
        "eye_w": 58, "brow_w": 56, "mouth_w": 79,
    },
}
# 口の段階（1 小 / 2 中 / 3 大）。大きく開いた1枚を縦に潰して作る
SQUASH = {1: 0.22, 2: 0.55, 3: 1.0}
_cache: dict = {}


def blank(who: str) -> Image.Image:
    """のっぺらぼう（顔のパーツが無い立ち絵）。"""
    key = ("blank", who)
    if key not in _cache:
        _cache[key] = Image.open(BASE / POS[who]["blank"]).convert("RGBA")
    return _cache[key]


def base(who: str) -> Image.Image:
    """元の立ち絵（ふつうの顔）。表情を変えないときに使う。"""
    key = ("base", who)
    if key not in _cache:
        _cache[key] = Image.open(BASE / (who + ".png")).convert("RGBA")
    return _cache[key]


def _part(who: str, name: str):
    p = BASE / "parts" / who / (name + ".png")
    if not p.exists():
        return None
    key = ("part", who, name)
    if key not in _cache:
        _cache[key] = Image.open(p).convert("RGBA")
    return _cache[key]


def _skin_out(p, bg, x0, y0, tol):
    """パーツのうち、**のっぺらぼうの肌と同じ色の画素を透明にする。**

    パーツには肌も写り込んでいる。そのまま貼ると、わずかな陰影の違いが
    四角い継ぎ目として見える（2026-10-09）。色で抜けば、はっきりしたまま消える。
    """
    out = p.copy()
    op, bp = out.load(), bg.load()
    bw, bh = bg.size
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = op[x, y]
            if a < 8:
                continue
            bx, by = x0 + x, y0 + y
            if not (0 <= bx < bw and 0 <= by < bh):
                continue
            br, bg_, bb_, ba = bp[bx, by]
            if ba < 8 or abs(r - br) + abs(g - bg_) + abs(b - bb_) < tol:
                op[x, y] = (r, g, b, 0)
    return out


def _put(im, who, name, xy, flip=False, squash=1.0, lift=0, width=None):
    p = _part(who, name)
    if p is None:
        return
    if width and p.width != width:
        # **パーツごとに元の大きさが違う。** 貼る前に基準の幅へ揃える
        p = p.crop(p.getbbox())
        k = width / p.width
        p = p.resize((width, max(int(p.height * k), 1)), Image.LANCZOS)
    if squash != 1.0:
        p = p.resize((p.width, max(int(p.height * squash), 1)), Image.LANCZOS)
    if flip:
        p = p.transpose(Image.FLIP_LEFT_RIGHT)
    x, y = xy[0], xy[1] - lift
    im.alpha_composite(_skin_out(p, blank(who), x, y, POS[who]["skin_tol"]), (x, y))


def face(who: str, mouth=0, eye: str = "normal", brow: str = "normal"):
    """のっぺらぼうに、目・眉・口を貼って表情を作る。

    mouth … 0/"normal" 閉じ / 1 小 / 2 中 / 3 大 / "smile" / "frown" / "poka"
    eye   … normal / half / shut / wide / smile / star
    brow  … normal / up / angry / sad
    """
    P = POS[who]
    im = blank(who).copy()

    for kind, val in (("brow", brow), ("eye", eye)):
        left, right = P[kind + "_l"], P[kind + "_r"]
        w = P[kind + "_w"]
        _put(im, who, "{}_{}".format(kind, val), left, width=w)
        own = "{}_{}_right".format(kind, val)
        if _part(who, own) is not None:
            _put(im, who, own, right, width=w)
        else:
            _put(im, who, "{}_{}".format(kind, val), right, flip=True, width=w)

    if mouth in (0, "normal"):
        _put(im, who, "mouth_normal", P["mouth"], width=P["mouth_w"])
    elif isinstance(mouth, str):
        _put(im, who, "mouth_" + mouth, P["mouth"], width=P["mouth_w"])
    else:
        _put(im, who, "mouth_open", P["mouth"], width=P["mouth_w"],
             squash=SQUASH[mouth], lift=P["mouth_lift"][mouth])
    return im


def load(who: str, height: int, mouth=0, eye: str = "normal", brow: str = "normal"):
    """表情を作って、指定の高さに縮める。"""
    im = face(who, mouth, eye, brow)
    s = height / im.height
    return im.resize((max(int(im.width * s), 1), height), Image.LANCZOS)
