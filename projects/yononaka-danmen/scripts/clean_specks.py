# -*- coding: utf-8 -*-
# 使い方: python scripts/clean_specks.py <元> <出力> [--gray]
# **順番は clean_highlights → clean_specks → clean_specks --gray**（2026-10-09 に確立）
"""黒い点（透明が黒に化けた跡）を、まわりから塗り直して消す。

**点は無彩色の黒、絵の線は赤茶。** 線の暗い所も R が G・B より大きい
（口 大の瞳の輪郭は [8,1,1]、点は [0,0,0] [11,9,5] [35,33,28]）。
暗さだけで選ぶと、口 大の唇の線と瞳の輪郭まで消えた（2026-10-09）。
さらに「小さい」「まわりが明るい」「まわりに白がある」ものだけにする。
塗る色は近くの白の画素だけの平均（下に経緯）。白で一律に塗ると白目の陰より浮き、
inpaint だと瞳の茶色がにじんだ。
"""
import sys
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

src = Path(sys.argv[1]); dst = Path(sys.argv[2])
GRAY = "--gray" in sys.argv
# 顔の範囲（のっぺらぼうの肌を塗りつぶして作ったもの）。目の外には触らないための囲い
face = np.asarray(Image.open(r"C:/Users/なみ/dev/output/yononaka-danmen/assets/characters/kikite_face_mask.png")) > 0
from skimage.morphology import disk
DISK4, DISK2 = disk(4).astype(bool), disk(2).astype(bool)
for n in ["normal","talk_small","talk_big","blink","surprise","smile","wonder","pout","trouble"]:
    a = np.asarray(Image.open(src / (n + ".png")).convert("RGBA")).copy()
    rgb = a[..., :3].astype(np.int16)
    mx = rgb.max(axis=2); lum = rgb.mean(axis=2)
    sat = rgb.max(axis=2) - rgb.min(axis=2)
    R, G = rgb[..., 0], rgb[..., 1]
    neutral = (R - G) <= np.maximum(2, 0.3 * R)
    # 灰色の点もある（口 小・不満の白目。明るさ100前後）。黒だけでは残った
    # 口の中（歯の境目）は灰色の線なので、灰色まで拾うのは目の高さだけ
    band = np.zeros_like(face); band[335:400] = True
    # **黒い点と灰色の点は別々に探す。** 一度に探すと黒い点が周りの灰色とつながって
    # 大きな塊になり、拾えなくなった（ふつうの顔の白目の点が戻った）
    if GRAY:
        core = (mx >= 45) & (mx < 130) & band & neutral & face
    else:
        core = (mx < 45) & neutral & face
    lab, k = ndi.label(core, structure=np.ones((3, 3)))
    # 守る所: 暗い大きな塊（瞳・まつげ・眉）
    dl, _ = ndi.label(lum < 150, structure=np.ones((3, 3)))
    sz = np.bincount(dl.ravel()); sz[0] = 0
    big = sz[dl] > 60
    brown = (lum < 170) & ~neutral
    mask = np.zeros(core.shape, bool); solid = np.zeros(core.shape, bool); edge = np.zeros(core.shape, bool); hit = []
    for i, sl in enumerate(ndi.find_objects(lab), 1):
        c = np.zeros_like(core); c[sl] = lab[sl] == i
        if c.sum() > 25:
            continue
        if GRAY:
            # **線のふちのぼかしは灰色の点に見える。** 口 大の瞳の黒い輪郭のふちを塗って
            # 輪郭が細った。灰色の点は、すぐ隣に自分より暗い所が無いものだけ
            nb = ndi.binary_dilation(c, iterations=2) & ~c
            if lum[nb].min() < lum[c].min() - 5:
                continue
        ring = ndi.binary_dilation(c, iterations=4) & ~ndi.binary_dilation(c, iterations=2)
        med = float(np.median(lum[ring]))
        if med - lum[c].mean() < 70:
            continue                     # まわりも暗い（まつげ・瞳の中）
        if ((lum[ring] > 185) & (sat[ring] < 35)).mean() < 0.25:
            continue                     # まわりに白が無い（白目・ハイライトの点だけを消す）
        # **点のまわりには白い縁（圧縮でできた輪）もある。** 暗い所だけ塗ると、その縁が
        # 白目の陰より明るく浮いてムラに見えた。点のまわり4画素をまるごと塗り直す（2画素では白い輪が残った）。
        # 瞳・まつげ（大きな暗い塊）は塗らない（芯だけは塗る）
        # 丸く広げる（iterations で広げると、ひし形のふちが見えた）
        # 茶色い暗い画素（瞳の輪郭の細い線）も守る。大きな塊にならない細い線が
        # 白で埋まり、感心の顔で白目と瞳の反射がつながった
        if (ndi.binary_dilation(c, iterations=1) & big).any():
            # **瞳の縁に接した点は、白でなく周りの色（白と茶の両方）で埋める。**
            # 白で埋めると瞳が欠けたり、白目と瞳の反射がつながった（感心の顔）
            edge |= c | (ndi.binary_dilation(c, iterations=1) & neutral & (lum < med - 25))
        else:
            mask |= (ndi.binary_dilation(c, structure=DISK4) & ~big & ~brown) | c
            solid |= ndi.binary_dilation(c, structure=DISK2) | c
        hit.append("({},{})".format(sl[1].start, sl[0].start))
    # **塗る色は、近くの白（白目・ハイライト）の画素だけの重み付き平均。**
    # inpaint はまわり全部から伸ばすので、瞳の茶色が白目ににじんだ（2026-10-09）
    valid = (lum > 170) & (sat < 45) & ~ndi.binary_dilation(mask, iterations=1)
    num = np.stack([ndi.gaussian_filter(rgb[..., ch] * valid, 3.0) for ch in range(3)], axis=2)
    den = ndi.gaussian_filter(valid.astype(float), 3.0)[..., None]
    # ふちはぼかして馴染ませる。点とそのすぐ外（solid）は必ず塗り切る
    al = ndi.gaussian_filter(mask.astype(float), 1.0)
    al[solid] = 1.0
    al[~ndi.binary_dilation(mask, iterations=2)] = 0
    ok = (al > 0) & (den[..., 0] > 0.02)
    fill = num[ok] / den[ok]
    w = al[ok][:, None]
    a[..., :3][ok] = np.clip(fill * w + rgb[ok] * (1 - w), 0, 255).astype(np.uint8)
    if edge.any():
        cur = a[..., :3].astype(float)
        # 点のふちの灰色（無彩色で暗め）は手本にしない。灰色のしみになった
        v = ~edge & ~(neutral & (lum < 170))
        num2 = np.stack([ndi.gaussian_filter(cur[..., ch] * v, 1.2) for ch in range(3)], axis=2)
        den2 = ndi.gaussian_filter(v.astype(float), 1.2)[..., None]
        a[..., :3][edge] = np.clip(num2[edge] / den2[edge], 0, 255).astype(np.uint8)
    mask |= edge
    # **点の跡の薄い輪を均す。** 点がいくつも寄っていると、まわりの白の判定から漏れて
    # ふちの灰色が輪郭のように残った。点のあった所の3画素以内だけ、
    # まわり7画素の中央値より暗い無彩色の画素を中央値に置き換える
    near = ndi.binary_dilation(mask, iterations=3)
    cur = a[..., :3].astype(np.int16)
    med7 = np.stack([ndi.median_filter(cur[..., ch], size=7) for ch in range(3)], axis=2)
    cl = cur.mean(axis=2); ml = med7.mean(axis=2)
    cs = cur.max(axis=2) - cur.min(axis=2)
    ghost = near & (cl < ml - 10) & (cs < 45) & (ml > 170)
    a[..., :3][ghost] = med7[ghost].astype(np.uint8)
    Image.fromarray(a).save(dst / (n + ".png"))
    print("{:11s} 点 {:2d} 個 {}".format(n, len(hit), " ".join(hit)))
