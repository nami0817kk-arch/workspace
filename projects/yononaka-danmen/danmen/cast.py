# -*- coding: utf-8 -*-
"""立ち絵。**表情ごとに完成した1枚の絵を読む。**

`assets/characters/<who>/<表情>.png`。どれも同じ大きさ・同じ構図で、
顔の中だけが違う。だから切り替えても体は1画素も動かない。

## 作り方（2026-10-09 に確立。この手順を変えない）

1. Gemini に「のっぺらぼう」（目・眉・口の無い立ち絵）を作らせる
2. のっぺらぼうと元の立ち絵を添付し、**表情を1つずつ描き足させる**
3. 返ってきた絵を、**顔の外（髪・服）が一致するように**拡大率とずれを自動で探して
   のっぺらぼうに重ねる（`scripts/align_faces.py`。誤差は19前後に収まる）
4. **顔の範囲だけ**を取り出して、のっぺらぼうに載せる（肌の色の差は平均で補正）
5. **白目・瞳のハイライトの黒い点を消す。** Gemini の絵は透明だった所が黒い点になって
   返ってくる（小倉の9枚中7枚にあった）。`scripts/clean_highlights.py` →
   `scripts/clean_specks.py` → `scripts/clean_specks.py --gray` の順に通し、
   目を3倍以上に拡大して前後を見比べる。消したあとは動画のコマでも見る

**パーツを切り貼りする方式はやめた。** 目・眉・口を別々に描かせて私が座標を測って
貼ると、縮尺・位置・左右・太さがずれ続け、30回以上直しても正しくならなかった。
表情ごと描かせれば、位置と大きさは絵を描いた時点で決まる。

    face(who, expr="normal", mouth=0, blink=False)   … その瞬間の絵
    load(who, height, ...)                            … 高さを指定して読む

口パクと瞬きは「ふつう」の顔のときだけ動かす。**口のあたり・目のあたりだけを差し替える**
（まるごと替えると目まで替わってちらつく）。
ほかの表情は口を開け閉めしない。表情を出している数秒は、その絵を止めて見せる。
"""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

BASE = Path(r"C:/Users/なみ/dev/output/yononaka-danmen/assets/characters")

# 表情の名前（台本・movie.py から呼ぶ名前）→ 絵のファイル名
EXPR = {
    "normal": "normal",      # ふつう
    "surprise": "surprise",  # 驚き
    "smile": "smile",        # にっこり
    "wonder": "wonder",      # 感心
    "pout": "pout",          # 不満
    "trouble": "trouble",    # 困る
    "grimace": "grimace",    # 歯を食いしばる
    "laugh": "laugh",        # 大笑い（岬）
    "serious": "serious",    # 真剣（岬）
    "pucker": "pucker",      # 口をすぼめる（小倉）
    "huh": "huh",            # 「え？」（小倉）
    "oh": "oh",              # 小さく「お」（小倉）
    "sad": "sad",            # しょんぼり（小倉）
}
# その人に絵の無い表情は、ふつうの顔で出す（岬に pout は無い、など）
# 口パクの絵（ふつうの顔のときだけ）。0 閉じ / 1・2 小 / 3 大
# **2 を「大」にすると叫んでいるように見える**（2026-10-09。喋っているコマの55%が大だった）
TALK = {0: "normal", 1: "talk_small", 2: "talk_small", 3: "talk_big"}
BLINK = "blink"

_cache: dict = {}


def _img(who: str, name: str) -> Image.Image:
    key = (who, name)
    if key not in _cache:
        p = BASE / who / (name + ".png")
        if not p.exists():
            raise FileNotFoundError("立ち絵がありません: {}".format(p))
        _cache[key] = Image.open(p).convert("RGBA")
    return _cache[key]


def has(who: str) -> bool:
    """その人の表情の絵が揃っているか。"""
    return (BASE / who / "normal.png").exists()


def _rows_split(who: str) -> int:
    """目と口の境目の高さ。**絵の差分から自動で決める**（座標を測らない）。

    瞬きの絵とふつうの絵の差は目のあたりに、口 大の絵との差は口のあたりに出る。
    その2つの帯のあいだを境目にする。
    """
    key = ("split", who)
    if key in _cache:
        return _cache[key]
    nm = np.asarray(_img(who, "normal").convert("RGB")).astype(np.int16)

    def band(name):
        d = (np.abs(np.asarray(_img(who, name).convert("RGB")).astype(np.int16) - nm).sum(axis=2) > 60)
        r = d.sum(axis=1)
        return r

    # 口 大との差は「眉」「目」「口」（岬は「あご」も）の帯に分かれる。
    # その上の帯の下端と、口の帯の上端のあいだを境目にする
    # （最初は瞬きの差のいちばん強い行から辿ったら、眉の帯で止まって y319 になった）
    r = band("talk_big")
    on = [i for i, v in enumerate(r) if v > 8]
    bands, b0 = [], on[0]
    for a, b in zip(on, on[1:]):
        if b - a > 6:
            bands.append((b0, a)); b0 = b
    bands.append((b0, on[-1]))
    bands = [bd for bd in bands if r[bd[0]:bd[1] + 1].sum() > 200]
    # **いちばん差の大きい帯が口。** 岬は口の下にあごの線の差の帯があり、
    # 最後の帯を口とみなすと境目があごになった（2026-10-10）
    sums = [int(r[a:b + 1].sum()) for a, b in bands]
    if len(bands) == 1:
        # 口 大の絵の目がふつうと同じなら、差は口の帯だけ。その少し上を境目にする
        # （小倉の口 大を「え？」の絵に替えたとき、2026-10-10）
        _cache[key] = max(bands[0][0] - 8, 0)
        return _cache[key]
    mi = max(range(1, len(bands)), key=lambda i: sums[i])
    end, start = bands[mi - 1][1], bands[mi][0]
    _cache[key] = (end + start) // 2
    return _cache[key]


def _swap(who: str, base: Image.Image, name: str, lower: bool) -> Image.Image:
    """base の、目のあたり（lower=False）か口のあたり（lower=True）だけを name の絵に替える。

    **表情の絵をまるごと替えると、目まで替わる。** 口 小・口 大の目は Gemini が描いた目で、
    ふつうの顔の目と形やほくろが違い、喋るたびに目がちらついた（2026-10-09）。
    9枚とも同じ位置に重ねてあるので、差のある所だけを切り替えれば足りる。
    """
    key = ("swap", who, name, lower)
    if key not in _cache:
        src = _img(who, name)
        a = np.asarray(src.convert("RGB")).astype(np.int16)
        n = np.asarray(_img(who, "normal").convert("RGB")).astype(np.int16)
        d = (np.abs(a - n).sum(axis=2) > 40)
        split = _rows_split(who)
        if lower:
            d[:split] = False
        else:
            d[split:] = False
        m = Image.fromarray((d * 255).astype(np.uint8))
        m = m.filter(ImageFilter.MaxFilter(11)).filter(ImageFilter.GaussianBlur(3))
        _cache[key] = (src, m)
    src, m = _cache[key]
    return Image.composite(src, base, m)


def face(who: str, expr: str = "normal", mouth: int = 0, blink: bool = False) -> Image.Image:
    """その瞬間の絵。

    expr  … normal / surprise / smile / wonder / pout / trouble
    mouth … 0〜3（ふつうの顔のときだけ効く。口のあたりだけ替える）
    blink … True で目を閉じる（ふつうの顔のときだけ効く。目のあたりだけ替える）
    """
    if expr != "normal":
        name = EXPR.get(expr, "normal")
        if not (BASE / who / (name + ".png")).exists():
            name = "normal"
        return _img(who, name)
    key = ("face", who, int(mouth), bool(blink))
    if key not in _cache:
        im = _img(who, "normal")
        if blink:
            im = _swap(who, im, BLINK, lower=False)
        talk = TALK.get(int(mouth), "normal")
        if talk != "normal":
            im = _swap(who, im, talk, lower=True)
        _cache[key] = im
    return _cache[key]


def load(who: str, height: int, expr: str = "normal", mouth: int = 0,
         blink: bool = False) -> Image.Image:
    """指定の高さに縮めて返す。同じ組み合わせは使い回す。"""
    key = ("load", who, height, expr, int(mouth), bool(blink))
    if key not in _cache:
        im = face(who, expr, mouth, blink)
        s = height / im.height
        _cache[key] = im.resize((max(int(im.width * s), 1), height), Image.LANCZOS)
    return _cache[key]
