# -*- coding: utf-8 -*-
"""表情の絵を、のっぺらぼうに重ねて立ち絵にする。

    python scripts/align_faces.py --who kikite --blank のっぺらぼう.jpg \
        --face normal=元の立ち絵.png --face surprise=驚き.jpg --face smile=にっこり.jpg ...

出力は `assets/characters/<who>/<表情>.png`（どれも同じ大きさ・同じ構図）。

## 手順（2026-10-09 に確立）

1. **のっぺらぼうの背景を抜く**（黒い背景を外から辿る。輪郭の白いにじみも消す）
2. **顔の範囲を出す**：額から肌色を塗り広げる（髪と輪郭線で止まる）
3. **重ねる**：顔の外（髪・服）が一致するように、拡大率と縦横のずれを探す
   （粗く探してから細かく詰める）。誤差が 25 を超えたら重なっていないので止める
4. **顔だけ取り出す**：顔の範囲を 3px 内側に縮め、境目を 2px ぼかして載せる。
   肌の色は、目鼻から離れた所の平均の差で補正する

**私が座標を測る工程が無い。** パーツを測って貼る方式では、縮尺・位置・左右・太さが
ずれ続けた（30回以上直しても正しくならなかった）。
"""
from __future__ import annotations

import argparse
import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ASSETS = Path(r"C:/Users/なみ/dev/output/yononaka-danmen/assets/characters")
MAX_ERR = 25.0           # 重ねたあとの髪・服の色の差（RGB 合計の平均）。これを超えたら失敗


def cut_background(img: Image.Image) -> np.ndarray:
    """黒い背景を外から辿って抜き、輪郭のにじみも消したアルファを返す。"""
    w, h = img.size
    sm = np.asarray(img.convert("RGB").filter(ImageFilter.MedianFilter(3))).astype(np.int16)
    mx, mn = sm.max(axis=2), sm.min(axis=2)
    bg_like = (mx <= 125) & ((mx - mn) <= 22)       # 暗く彩度が低い＝背景（髪の濃い茶は残る）
    out = np.zeros((h, w), bool)
    q = deque([(x, 0) for x in range(w)] + [(x, h - 1) for x in range(w)]
              + [(0, y) for y in range(h)] + [(w - 1, y) for y in range(h)])
    while q:
        x, y = q.popleft()
        if not (0 <= x < w and 0 <= y < h) or out[y, x] or not bg_like[y, x]:
            continue
        out[y, x] = True
        q.extend(((x+1, y), (x-1, y), (x, y+1), (x, y-1)))
    a = ~out
    # 輪郭から4px以内の、白っぽく彩度の低いにじみを消し、外周を1px削る
    inner = np.asarray(Image.fromarray((a * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(9))) > 0
    rgb = np.asarray(img.convert("RGB")).astype(np.int16)
    halo = a & ~inner & ((rgb.max(axis=2) - rgb.min(axis=2)) < 28) & (rgb.min(axis=2) > 90)
    a = a & ~halo
    a = np.asarray(Image.fromarray((a * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(3))) > 0
    return a


def face_mask(rgb: np.ndarray, seed) -> np.ndarray:
    """額の一点から肌色を塗り広げて、顔の範囲を出す。"""
    h, w = rgb.shape[:2]
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    skin = (r > 185) & (g > 135) & (r - b > 18) & (r - g < 75)
    m = np.zeros((h, w), bool)
    sx, sy = seed
    if not skin[sy, sx]:
        raise SystemExit("額の位置 {} が肌色ではありません。--seed で額の座標を指定してください".format(seed))
    q = deque([(sx, sy)]); m[sy, sx] = True
    while q:
        x, y = q.popleft()
        for nx, ny in ((x+1, y), (x-1, y), (x, y+1), (x, y-1)):
            if 0 <= nx < w and 0 <= ny < h and not m[ny, nx] and skin[ny, nx]:
                m[ny, nx] = True; q.append((nx, ny))
    return m


def place(img: Image.Image, size, s, dx, dy) -> np.ndarray:
    W, H = size
    w, h = int(round(img.width * s)), int(round(img.height * s))
    im = img.resize((w, h), Image.LANCZOS)
    canvas = Image.new("RGB", (W, H), (0, 0, 0))
    canvas.paste(im.convert("RGB"), (int(round((W - w) / 2 + dx)), int(round((H - h) / 2 + dy))),
                 im if im.mode == "RGBA" else None)
    return np.asarray(canvas).astype(np.int16)


def align(img: Image.Image, blank: np.ndarray, cmp_mask: np.ndarray, base_scale: float):
    """顔の外が一致する拡大率とずれを探す。(誤差, 拡大, dx, dy)。"""
    H, W = blank.shape[:2]

    def err(s, dx, dy, step):
        d = np.abs(place(img, (W, H), s, dx, dy) - blank).sum(axis=2)
        return float(d[cmp_mask][::step].mean())

    best = None
    for k in (0.98, 0.99, 1.0, 1.01, 1.02):
        for dx in range(-12, 13, 4):
            for dy in range(-12, 13, 4):
                e = err(base_scale * k, dx, dy, 7)
                if best is None or e < best[0]:
                    best = (e, base_scale * k, dx, dy)
    _, s0, dx0, dy0 = best
    for s in np.arange(s0 - 0.006 * base_scale, s0 + 0.0061 * base_scale, 0.002 * base_scale):
        for dx in range(dx0 - 3, dx0 + 4):
            for dy in range(dy0 - 3, dy0 + 4):
                e = err(float(s), dx, dy, 3)
                if e < best[0]:
                    best = (e, float(s), dx, dy)
    return err(best[1], best[2], best[3], 1), best[1], best[2], best[3]


def main() -> int:
    ap = argparse.ArgumentParser(description="表情の絵を、のっぺらぼうに重ねて立ち絵にする")
    ap.add_argument("--who", required=True, help="katari / kikite")
    ap.add_argument("--blank", required=True, help="のっぺらぼう（背景は黒）")
    ap.add_argument("--face", action="append", required=True, help="表情名=絵のパス（何度でも）")
    ap.add_argument("--seed", default=None, help="額の座標 x,y（顔の範囲を塗り広げる起点）")
    a = ap.parse_args()

    blank_img = Image.open(a.blank).convert("RGB")
    W, H = blank_img.size
    bl = np.asarray(blank_img).astype(np.int16)
    alpha = cut_background(blank_img)
    seed = tuple(int(v) for v in a.seed.split(",")) if a.seed else (W // 2, int(H * 0.24))
    face = face_mask(bl, seed)
    ys, xs = np.nonzero(face)
    print("顔の範囲 x {}-{} / y {}-{}".format(xs.min(), xs.max(), ys.min(), ys.max()))

    far = np.asarray(Image.fromarray((face * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(41))) > 0
    cmp_mask = (bl.max(axis=2) > 60) & ~far
    soft = Image.fromarray((face * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(7))
    soft = np.asarray(soft.filter(ImageFilter.GaussianBlur(2))).astype(np.float32)[..., None] / 255.0

    out_dir = ASSETS / a.who
    out_dir.mkdir(parents=True, exist_ok=True)
    failed = []
    for item in a.face:
        name, path = item.split("=", 1)
        img = Image.open(path)
        img = img.convert("RGBA") if img.mode in ("RGBA", "LA", "P") else img.convert("RGB")
        base_scale = H / img.height if abs(img.width / img.height - W / H) < 0.01 else W / img.width
        e, s, dx, dy = align(img, bl, cmp_mask, base_scale)
        ok = e <= MAX_ERR
        print("{:12s} 誤差 {:5.1f}  拡大 {:.3f}  ずれ ({:+d},{:+d})  {}".format(
            name, e, s, dx, dy, "OK" if ok else "← 重なっていない"))
        if not ok:
            failed.append(name)
            continue
        ex = place(img, (W, H), s, dx, dy).astype(np.float32)
        calm = face & (np.abs(ex - bl).sum(axis=2) < 40)
        ex = np.clip(ex + (bl[calm] - ex[calm]).mean(axis=0), 0, 255)
        merged = bl.astype(np.float32) * (1 - soft) + ex * soft
        im = Image.fromarray(merged.astype(np.uint8)).convert("RGBA")
        im.putalpha(Image.fromarray((alpha * 255).astype(np.uint8)))
        im.save(out_dir / (name + ".png"))
    if failed:
        print("重ならなかった表情: {}。構図が変わっていないか、絵を見直してください".format(", ".join(failed)))
        return 1
    print("→ {}".format(out_dir))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
