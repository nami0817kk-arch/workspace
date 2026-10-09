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

**パーツを切り貼りする方式はやめた。** 目・眉・口を別々に描かせて私が座標を測って
貼ると、縮尺・位置・左右・太さがずれ続け、30回以上直しても正しくならなかった。
表情ごと描かせれば、位置と大きさは絵を描いた時点で決まる。

    face(who, expr="normal", mouth=0, blink=False)   … その瞬間の絵
    load(who, height, ...)                            … 高さを指定して読む

口パクと瞬きは「ふつう」の顔のときだけ動かす（口 小・口 大・目を閉じた絵がある）。
ほかの表情は口を開け閉めしない。表情を出している数秒は、その絵を止めて見せる。
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

BASE = Path(r"C:/Users/なみ/dev/output/yononaka-danmen/assets/characters")

# 表情の名前（台本・movie.py から呼ぶ名前）→ 絵のファイル名
EXPR = {
    "normal": "normal",      # ふつう
    "surprise": "surprise",  # 驚き
    "smile": "smile",        # にっこり
    "wonder": "wonder",      # 感心
    "pout": "pout",          # 不満
    "trouble": "trouble",    # 困る
}
# 口パクの絵（ふつうの顔のときだけ）。0 閉じ / 1 小 / 2・3 大
TALK = {0: "normal", 1: "talk_small", 2: "talk_big", 3: "talk_big"}
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


def face(who: str, expr: str = "normal", mouth: int = 0, blink: bool = False) -> Image.Image:
    """その瞬間の絵。

    expr  … normal / surprise / smile / wonder / pout / trouble
    mouth … 0〜3（ふつうの顔のときだけ効く）
    blink … True で目を閉じた絵（ふつうの顔で口を閉じているときだけ効く）
    """
    if expr != "normal":
        return _img(who, EXPR.get(expr, "normal"))
    if blink and not mouth:
        return _img(who, BLINK)
    return _img(who, TALK.get(int(mouth), "normal"))


def load(who: str, height: int, expr: str = "normal", mouth: int = 0,
         blink: bool = False) -> Image.Image:
    """指定の高さに縮めて返す。同じ組み合わせは使い回す。"""
    key = ("load", who, height, expr, int(mouth), bool(blink))
    if key not in _cache:
        im = face(who, expr, mouth, blink)
        s = height / im.height
        _cache[key] = im.resize((max(int(im.width * s), 1), height), Image.LANCZOS)
    return _cache[key]
