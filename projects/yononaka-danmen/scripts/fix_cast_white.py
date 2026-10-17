# -*- coding: utf-8 -*-
"""立ち絵に残った白を抜く。**1回だけ走らせる道具。**

Gemini で作った立ち絵は背景を抜いてあるが、抜ききれていない。
アルファは2値で、**輪郭の外と髪の束のあいだに真っ白な画素が残る**。
暗い画面に置くと、人の周りが白く浮く（2026-10-08 にユーザーが指摘）。

外側とつながっている白を透明にする。服の白（シャツ）は人物の内側にあって
外から到達できないので残る。

    python scripts/fix_cast_white.py          # どう変わるか見るだけ
    python scripts/fix_cast_white.py --write  # 実際に書き換える（元は raw_white/ へ）
"""
from __future__ import annotations

import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

BASE = Path(r"C:/Users/なみ/dev/output/yononaka-danmen/assets/characters")
BACKUP = BASE / "raw_white"
THR = 228          # これより明るければ「白」とみなす


def strip_outside_white(im: Image.Image, thr: int = THR) -> tuple[Image.Image, int]:
    """外側とつながっている白を透明にする。返すのは (画像, 消した画素の数)。"""
    arr = np.array(im.convert("RGBA"))
    h, w = arr.shape[:2]
    rgb = arr[:, :, :3].astype(np.int16)
    alpha = arr[:, :, 3]
    # 「外」になりうる画素＝すでに透明、または白に近い
    light = (rgb.min(axis=2) >= thr) | (alpha < 24)
    reach = np.zeros((h, w), dtype=bool)
    reach[0, :] = light[0, :]
    reach[-1, :] = light[-1, :]
    reach[:, 0] = light[:, 0]
    reach[:, -1] = light[:, -1]
    for _ in range(800):
        prev = reach.sum()
        grow = reach.copy()
        grow[1:, :] |= reach[:-1, :]
        grow[:-1, :] |= reach[1:, :]
        grow[:, 1:] |= reach[:, :-1]
        grow[:, :-1] |= reach[:, 1:]
        reach = grow & light
        if reach.sum() == prev:
            break
    killed = int((reach & (alpha >= 24)).sum())
    out = arr.copy()
    out[:, :, 3] = np.where(reach, 0, alpha)
    return Image.fromarray(out, "RGBA"), killed


def fill_inner_white(im: Image.Image, thr: int = 230, rounds: int = 20,
                     around: int = 175) -> tuple[Image.Image, int]:
    """**内側に残った純白**を、周りの色で埋める。

    髪の束のあいだに取り残された背景の白は、外とつながっていないので
    `strip_outside_white` では消えない。周りの色で塗って溶かす。

    **周りが暗い白だけ**を埋める。髪の隙間の白は髪（暗い）に囲まれているが、
    シャツの白は周りも明るい。上から何％という範囲で区切る方法も試したが、
    シャツの位置が人によって違い、筋が出た（2026-10-08）。
    閾値は 230。これより下げると、髪のつや（ハイライト）まで消えて
    のっぺりする（2026-10-08 に見比べた）。目のハイライトも残る。
    """
    arr = np.array(im.convert("RGBA"))
    h, w = arr.shape[:2]
    rgb = arr[:, :, :3].astype(np.float32)
    alpha = arr[:, :, 3]
    # 周りの明るさ（半径 6px）。これが暗ければ、髪に囲まれた白とみなす
    gray = im.convert("L").filter(ImageFilter.GaussianBlur(6))
    near = np.array(gray).astype(np.int16)
    white = (rgb.min(axis=2) >= thr) & (alpha > 200) & (near < around)
    killed = int(white.sum())
    for _ in range(rounds):
        if not white.any():
            break
        ok = ~white & (alpha > 200)
        num = np.zeros((h, w, 3), np.float32)
        den = np.zeros((h, w), np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            num += np.roll(rgb, (dy, dx), (0, 1)) * np.roll(ok, (dy, dx), (0, 1))[:, :, None]
            den += np.roll(ok, (dy, dx), (0, 1))
        can = white & (den > 0)
        if not can.any():
            break
        rgb = np.where(can[:, :, None], num / np.maximum(den, 1)[:, :, None], rgb)
        white = white & ~can
    out = arr.copy()
    out[:, :, :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    return Image.fromarray(out, "RGBA"), killed


def erode_edge(im: Image.Image, n: int = 2) -> Image.Image:
    """輪郭を n px 削る。

    アルファが2値なので、**輪郭のすぐ外に「白から髪色へのグラデーション」が
    絵として描かれている**。透明にはできないので、アルファの側を削って隠す。
    2px でほぼ消え、4px 以上だと髪が痩せる（2026-10-08 に見比べた）。
    """
    v = im.copy()
    a = v.split()[3]
    for _ in range(n):
        a = a.filter(ImageFilter.MinFilter(3))
    v.putalpha(a.filter(ImageFilter.GaussianBlur(0.8)))
    return v


def main() -> int:
    write = "--write" in sys.argv
    files = sorted(BASE.glob("*.png"))
    if not files:
        print("立ち絵が見つかりません: {}".format(BASE))
        return 1
    if write:
        BACKUP.mkdir(exist_ok=True)
    total = 0
    for p in files:
        im = Image.open(p).convert("RGBA")
        fixed, killed = strip_outside_white(im)
        fixed, filled = fill_inner_white(fixed)
        fixed = erode_edge(fixed)
        killed += filled
        total += killed
        share = killed / (im.width * im.height)
        print("  {:24s} 外の白 {:>7} ／ 髪の白 {:>6}（{:.2%}）".format(
            p.name, killed - filled, filled, share))
        if write and killed:
            # **元は1回だけ取っておく。** 2回目に走らせたとき、処理済みの絵で
            # バックアップを上書きしてしまわないように
            dst = BACKUP / p.name
            if not dst.exists():
                shutil.copy2(p, dst)
            fixed.save(p)
    print()
    if write:
        print("書き換えました。元は {} にあります。".format(BACKUP))
    else:
        print("見ただけです。実際に書き換えるには --write を付けてください。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
