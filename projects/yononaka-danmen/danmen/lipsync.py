# -*- coding: utf-8 -*-
"""立ち絵の口を、声に合わせて動かす。

素材には**口を開けた絵が無い**（表情ごとに口の形が違うだけ）。
そこで、閉じた口のうえに**口の中を描き足して**開いた口を作る。
顔のどこに口があるかは人ごとに決め打ちする（`MOUTH`）。

    envelope(wav)        … 声の大きさの時系列（0〜1）を出す
    open_mouth(im, who, amount)  … 口を開けた立ち絵を作る
    frames(im, who, wav) … 声に合わせた (画像, 秒数) の並びを返す

**開き具合は3段階に丸める**（閉じ・半分・開き）。なめらかに変えると画像の数が
増えすぎるうえ、見た目はほとんど変わらない。
"""
from __future__ import annotations

import array
import wave
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

# 顔の矩形に対する、口の位置と大きさ。y は**閉じた口の線**の位置
MOUTH = {
    "katari": {"y": 0.726, "w": 0.195, "h": 0.054},
    "kikite": {"y": 0.752, "w": 0.150, "h": 0.058},
}
STEP = 0.08             # 声の大きさを測る間隔（秒）
LEVELS = (0.0, 0.5, 0.9)   # 口の開き具合の3段階

# **もともと口が開いている表情**には描かない（二重になる）
OPEN_ALREADY = {
    "katari_egao", "katari_hakushu", "katari_ikari", "katari_odoroki",
    "kikite_hakushu", "kikite_naki", "kikite_odoroki", "kikite_warai",
    "kikite_yorokobi",
}


def face_box(im: Image.Image) -> tuple[int, int, int, int]:
    """顔のあたり（上から18%）の矩形。立ち絵は全身なので、この割合で取れる。"""
    h = int(im.height * 0.18)
    top = im.crop((0, 0, im.width, h))
    bb = top.getbbox()
    return bb if bb else (0, 0, im.width, h)


def can_move(mood_name: str) -> bool:
    """その表情で口パクできるか。もともと口が開いているものは動かさない。"""
    return mood_name not in OPEN_ALREADY


def open_mouth(im: Image.Image, who: str, amount: float) -> Image.Image:
    """口を開けた立ち絵。amount は 0（閉じ）〜1（最大）。

    **開いた口の上端を、もとの閉じた口の線に合わせる。** 中心を合わせると、
    もとの線が上に残ったまま下に口ができて、二重に見えた（2026-10-07）。
    **幅は開き具合で変えない。** 人が口を開けるとき、横には広がらず縦に開く。
    """
    m = MOUTH.get(who)
    if not m or amount <= 0.02:
        return im
    x0, y0, x1, y1 = face_box(im)
    fw, fh = x1 - x0, y1 - y0
    cx = x0 + fw * 0.5
    line = y0 + fh * m["y"]          # もとの閉じた口の線
    w = fw * m["w"] * (1.0 - 0.06 * amount)      # 開くほど少しすぼまる
    h = fh * m["h"] * amount
    if h < 2:
        return im
    top = line - h * 0.22            # 上端を線の少し上に置き、下へ開く
    out = im.convert("RGBA").copy()
    layer = Image.new("RGBA", out.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.ellipse([cx - w / 2, top, cx + w / 2, top + h], fill=(142, 64, 58, 255))
    # 下の歯のきわ。これが無いと、ただの黒い穴に見える
    ty0, ty1 = top + 2, top + h * 0.28
    if ty1 > ty0 and w > 12:
        d.ellipse([cx - w / 2 + 5, ty0, cx + w / 2 - 5, ty1], fill=(222, 198, 190, 255))
    layer = layer.filter(ImageFilter.GaussianBlur(1.2))
    # 立ち絵の外（透明なところ）には描かない
    layer.putalpha(Image.composite(layer.split()[3],
                                   Image.new("L", out.size, 0), out.split()[3]))
    out.alpha_composite(layer)
    return out


def envelope(wav: Path, step: float = STEP) -> list[float]:
    """声の大きさの時系列（0〜1）。息継ぎで口が閉じるので、口パクに使える。"""
    with wave.open(str(wav), "rb") as w:
        n, sr, sw, ch = w.getnframes(), w.getframerate(), w.getsampwidth(), w.getnchannels()
        data = w.readframes(n)
    if sw != 2:
        return []
    a = array.array("h")
    a.frombytes(data)
    if ch == 2:
        a = a[::2]
    per = max(int(sr * step), 1)
    out: list[float] = []
    for i in range(0, len(a), per):
        c = a[i:i + per]
        if not c:
            break
        out.append((sum(float(v) * v for v in c) / len(c)) ** 0.5)
    mx = max(out) if out else 0
    if not mx:
        return [0.0] * len(out)
    # 少し持ち上げる（小さい声でも口が動くように）
    return [min(v / mx * 1.5, 1.0) for v in out]


def snap(v: float) -> float:
    """開き具合を3段階に丸める。画像の数を抑えるため。"""
    if v < 0.18:
        return LEVELS[0]
    if v < 0.52:
        return LEVELS[1]
    return LEVELS[2]


def levels(wav: Path, step: float = STEP) -> list[float]:
    """その音声に合わせた、口の開き具合の並び（3段階）。"""
    return [snap(v) for v in envelope(wav, step)]


def runs(vals: list[float], step: float = STEP) -> list[tuple[float, float]]:
    """同じ開き具合が続くところをまとめて (開き具合, 秒数) にする。

    まとめないと、1秒あたり 12 枚の画像を ffmpeg に渡すことになる。
    """
    out: list[tuple[float, float]] = []
    for v in vals:
        if out and abs(out[-1][0] - v) < 1e-6:
            out[-1] = (v, out[-1][1] + step)
        else:
            out.append((v, step))
    return out
