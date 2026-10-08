# -*- coding: utf-8 -*-
"""立ち絵の口を開ける（口パク用）。**元の絵を加工するので、体は1画素も動かない。**

**「歴史の地層」の `chiso/jaw.py` を写した**（2026-10-08）。
向こうは公式の絵が1枚しかないキャラで、同じやり方で口パクをしている。

2026-10-07 に「口の線より下を切り出して下げる」を試して失敗した
（四角い帯が出て、あごが切れた）。歴史の地層との違いは2つ。

- **下げる量を弧にする**（真ん中ほど大きく下げる）。一律に下げると四角い帯になる
- **口の画素だけを動かす**（肌色でない画素でマスクを作る）。四角い領域ごと動かさない

2026-10-08 に Gemini で差分を作る方法を5通り試したが、生成するたびに顔が変わるため、
コマを切り替えると**微妙にブレる**。元の絵を加工すればブレようがない。
"""
from __future__ import annotations

import math

import numpy as np
from PIL import Image
from scipy import ndimage

# 口の中の色（暗い赤茶）。真ん中ほど暗くする
INNER = (150, 92, 86)   # 元の絵が淡いので、歴史の地層より明るめ


def find_mouth(im: Image.Image, top: float = 0.03, bottom: float = 0.19):
    """全身の立ち絵から口の範囲を見つける。返すのは (x0, y0, x1, y1, 上下の分かれ目)。

    唇は**肌より赤く、横長**。顔の下半分で探す（首の影と襟は外す）。
    """
    H = im.height
    fy0, fy1 = int(H * top), int(H * bottom)
    arr = np.array(im.convert("RGB")).astype(np.int16)
    a = im.convert("RGBA").split()[3]
    alpha = np.array(a)
    r, g = arr[:, :, 0], arr[:, :, 1]
    red = ((r - g) > 26) & (r > 120) & (alpha > 128)
    band = np.zeros(red.shape, bool)
    y0 = fy0 + int((fy1 - fy0) * 0.48)
    y1 = fy0 + int((fy1 - fy0) * 0.74)
    band[y0:y1] = red[y0:y1]
    xs_all = np.where(alpha[fy0:fy1].any(axis=0))[0]
    if not len(xs_all):
        return None
    cx, w = (xs_all.min() + xs_all.max()) / 2, xs_all.max() - xs_all.min()
    band[:, : int(cx - w * 0.22)] = False
    band[:, int(cx + w * 0.22):] = False
    lab, n = ndimage.label(band)
    if n == 0:
        return None
    best, score = None, -1.0
    for i in range(1, n + 1):
        ys, xs = np.where(lab == i)
        bw, bh = xs.max() - xs.min() + 1, ys.max() - ys.min() + 1
        if len(xs) < 40 or bw < bh * 1.4:
            continue
        s = len(xs) * (bw / max(bh, 1))
        if s > score:
            best, score = i, s
    if best is None:
        return None
    ys, xs = np.where(lab == best)
    x0, x1 = int(xs.min()), int(xs.max()) + 1
    my0, my1 = int(ys.min()), int(ys.max()) + 1
    pad = int((x1 - x0) * 0.10)
    return (max(0, x0 - pad), max(0, my0 - pad), x1 + pad, my1 + pad,
            int((my0 + my1) / 2))


def open_mouth(src: Image.Image, box, d: int) -> Image.Image:
    """口を `d` 画素ぶん開ける。`box` は find_mouth が返したもの。"""
    if d <= 0:
        return src.copy()
    x0, y0, x1, y1, mid = box
    im = src.convert("RGBA").copy()
    sp = src.convert("RGBA").load()
    px = im.load()
    arr = np.array(src.convert("RGB")).astype(np.int16)

    # **口＝この範囲の中の「暗い画素」**（口の線と唇の影）。
    # 「肌でない画素」で取ると、肌の色はキャラごとに違うので外す。
    # 範囲は find_mouth が唇だけに絞ってあるので、顎の線は入らない。
    sub = arr[y0:y1, x0:x1]
    # **唇は「赤み」で取る。** 暗さで取ると口の合わせ目の線しか拾えず、
    # 口の中が四角く開いた（2026-10-08）。実測では唇の r-g が 26〜45、肌が 17〜19。
    # 歴史の地層も色で口を取っている（あちらは「青っぽい肌でない画素」）。
    rr, gg = sub[:, :, 0], sub[:, :, 1]
    light = sub.min(axis=2)
    mask = ((rr - gg) >= 25) | (light <= 150)
    # 上下の分かれ目＝口の合わせ目。いちばん暗い画素が多い行
    dark_rows = (light <= 170).sum(axis=1)
    if dark_rows.max() > 0:
        mid = y0 + int(np.argmax(dark_rows))
    if not mask.any():
        return im
    ys, xs = np.where(mask)
    xs = xs + x0
    ys = ys + y0
    cx = (xs.min() + xs.max()) / 2
    r = (xs.max() - xs.min()) / 2 + 1

    def shift(x: int) -> int:
        """**真ん中ほど大きく下げる。** 一律だと四角い帯になる。"""
        return int(round(d * math.sqrt(max(0.0, 1 - ((x - cx) / r) ** 2))))

    pts = list(zip(xs.tolist(), ys.tolist()))
    upper = [(x, y) for x, y in pts if y < mid]
    lower = [(x, y) for x, y in pts if y >= mid]
    cols: dict[int, list[int]] = {}
    for x, y in upper:
        c = cols.setdefault(x, [10 ** 9, -1])
        c[1] = max(c[1], y)
    for x, y in lower:
        c = cols.setdefault(x, [10 ** 9, -1])
        c[0] = min(c[0], y + shift(x))
    # 空いたところを口の中の色で塗る
    for x, (ylo, yup) in cols.items():
        if yup < 0 or ylo >= 10 ** 9:
            continue
        for y in range(yup + 1, ylo):
            t = (y - yup) / max(1, ylo - yup)
            k = 0.75 + 0.25 * abs(t - 0.5) * 2          # 真ん中ほど暗い
            px[x, y] = (int(INNER[0] * k), int(INNER[1] * k), int(INNER[2] * k), 255)
    # 下半分を下げる（下から順に動かす）
    for x, y in sorted(lower, key=lambda p: -p[1]):
        if y + shift(x) < im.height:
            px[x, y + shift(x)] = sp[x, y]
    for x, y in upper:
        px[x, y] = sp[x, y]
    return im


def steps(src: Image.Image, n: int = 5, max_open: float = 0.42) -> list[Image.Image]:
    """口の開き具合を n 段で作る。`max_open` は口の高さに対する割合。"""
    box = find_mouth(src)
    if box is None:
        return [src.convert("RGBA").copy() for _ in range(n)]
    h = box[3] - box[1]
    out = []
    for i in range(n):
        d = int(round(h * max_open * i / max(1, n - 1)))
        out.append(open_mouth(src, box, d))
    return out
