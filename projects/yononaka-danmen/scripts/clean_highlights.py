# -*- coding: utf-8 -*-
# 使い方: python scripts/clean_highlights.py <元のフォルダ> <出力フォルダ>
# **順番は clean_highlights → clean_specks → clean_specks --gray**（2026-10-09 に確立）
"""瞳のハイライトの中の黒い点を埋める。

ハイライトは丸い白なので、**白の塊の凸包の中にある暗い点は全部ゴミ**とみなせる。
縁に接した点は「囲まれた穴」にならず fill_white_holes.py では残った。
白目（三日月形）は凸包が瞳まで覆うので、丸さ（面積/凸包）で除く。
"""
import sys
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
from skimage.morphology import convex_hull_image, disk

SRC = Path(sys.argv[1]); DST = Path(sys.argv[2])
# 顔の範囲（のっぺらぼうの肌を塗りつぶして作ったもの）。目の外には触らないための囲い
face = np.asarray(Image.open(r"C:/Users/なみ/dev/output/yononaka-danmen/assets/characters/kikite_face_mask.png")) > 0
dry = "--dry" in sys.argv
for n in ["normal","talk_small","talk_big","blink","surprise","smile","wonder","pout","trouble"]:
    a = np.asarray(Image.open(SRC / (n + ".png")).convert("RGBA")).copy()
    rgb = a[..., :3].astype(np.int16)
    lum = rgb.mean(axis=2)
    sat = rgb.max(axis=2) - rgb.min(axis=2)
    eye = face.copy(); eye[:300] = False; eye[440:] = False
    white = (lum > 200) & (sat < 45) & eye
    closed = ndi.binary_closing(white, structure=disk(3)) & eye
    lab, k = ndi.label(closed)
    out = []
    for i in range(1, k + 1):
        c = lab == i
        area = int(c.sum())
        if area < 15 or area > 700:
            continue
        ys, xs = np.nonzero(c)
        y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
        hull = np.zeros_like(c)
        hull[y0:y1, x0:x1] = convex_hull_image(c[y0:y1, x0:x1])
        solid = area / hull.sum()
        w = white & hull
        if w.sum() < 10:
            continue
        fill = np.median(rgb[w], axis=0)
        bad = hull & (lum < fill.mean() - 15)   # 40 だと灰色が残ってまだらに見えた
        # **丸さでは分けられない**（困る・不満の白目は丸さ0.87あった）。
        # ハイライトは瞳の上にあるので、まわりが暗い。白目はまわりに肌が来る
        ring = ndi.binary_dilation(hull, iterations=3) & ~hull
        around = float(lum[ring].mean())
        kind = "ハイライト" if (area <= 250 and around < 120) else "白目"
        out.append("({},{}) 面積{} 周り{:.0f} {} 暗点{}".format(x0, y0, area, around, kind, int(bad.sum())))
        R_, G_ = rgb[..., 0], rgb[..., 1]
        speck = (rgb.max(axis=2) < 130) & ((R_ - G_) <= np.maximum(2, 0.3 * R_))
        near = ndi.binary_dilation(hull, iterations=3)
        inside_bad = hull & (lum < fill.mean() - 40)
        if kind == "ハイライト" and (inside_bad.any() or (near & speck).any()) and not dry:
            # **点のあるハイライトだけ、白一色で塗り直す**（点の無いものは触らない）。
            # 暗い所だけ塗るとまだらになり、凸包を硬く塗ると多角形に見えた。
            # 楕円に当てはめる案は元のふちと合わずトゲトゲになった。
            # → 点を瞳の色で消した下地に、ふちをぼかした白を重ねる
            col = np.percentile(rgb[w], 90, axis=0)
            base = rgb.astype(float).copy()
            fixb = near & speck & ~hull
            v = ~near & (lum < 200) & ~speck
            v |= near & ~speck & ~ndi.binary_dilation(hull, iterations=1) & (lum < 200)
            num = np.stack([ndi.gaussian_filter(rgb[..., ch] * v, 2.0) for ch in range(3)], axis=2)
            den = ndi.gaussian_filter(v.astype(float), 2.0)
            okb = fixb & (den > 0.05)
            base[okb] = num[okb] / den[okb][:, None]
            alpha = ndi.gaussian_filter(hull.astype(float), 0.8)
            alpha[ndi.binary_erosion(hull, iterations=1)] = 1.0
            alpha = np.maximum(alpha, (lum > 200) * 0.0)
            zone = near
            al = alpha[zone][:, None]
            a[..., :3][zone] = np.clip(col * al + base[zone] * (1 - al), 0, 255).astype(np.uint8)
    if not dry:
        Image.fromarray(a).save(DST / (n + ".png"))
    print(n, " / ".join(out))
