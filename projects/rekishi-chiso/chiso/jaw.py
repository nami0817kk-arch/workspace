"""剣崎雌雄の口を開けた絵を作る（公式の絵は1枚だけなので、口を描き足す）。

口（肌の青ではない画素）を上下に分け、下半分を下へずらす。ずらす量は口の真ん中ほど大きく
（あごが開く形）、あいだは口の中の暗い赤で塗る。剣崎雌雄の規約は二次創作に制限なし。
できた絵を、つむぎと同じ名前の付け方（faces.face_key）で全部の調子ぶん置く（表情は変えない）。
"""
from __future__ import annotations

import math
import shutil
from pathlib import Path

from PIL import Image

# 余白を切った公式の絵の上での口の範囲（x0, y0, x1, y1）と、上下の分かれ目。絵を差し替えたら測り直す
MOUTH_BOX = (272, 260, 358, 306)
MOUTH_MID = 284
OPEN_PX = 18


def _is_skin(p) -> bool:
    return p[2] > p[0] + 25            # 青っぽい肌


def open_mouth(src: Image.Image, d: int = OPEN_PX) -> Image.Image:
    x0, y0, x1, y1 = MOUTH_BOX
    mask = {(x, y) for x in range(x0, x1) for y in range(y0, y1) if not _is_skin(src.getpixel((x, y)))}
    if not mask:
        return src.copy()
    xs = [x for x, _ in mask]
    cx, r = (min(xs) + max(xs)) / 2, (max(xs) - min(xs)) / 2 + 1
    shift = lambda x: int(round(d * math.sqrt(max(0.0, 1 - ((x - cx) / r) ** 2))))
    im = src.copy()
    px, sp = im.load(), src.load()
    upper = {(x, y) for x, y in mask if y < MOUTH_MID}
    lower = {(x, y) for x, y in mask if y >= MOUTH_MID}
    cols: dict[int, list[int]] = {}
    for x, y in upper:
        c = cols.setdefault(x, [10 ** 9, -1])
        c[1] = max(c[1], y)
    for x, y in lower:
        c = cols.setdefault(x, [10 ** 9, -1])
        c[0] = min(c[0], y + shift(x))
    for x, (ylo, yup) in cols.items():
        if yup < 0 or ylo >= 10 ** 9:
            continue
        for y in range(yup + 1, ylo):
            t = (y - yup) / max(1, ylo - yup)
            k = 0.75 + 0.25 * abs(t - 0.5) * 2            # 真ん中ほど暗い
            px[x, y] = (int(131 * k), int(50 * k), int(55 * k), 255)
    for x, y in sorted(lower, key=lambda p: -p[1]):
        px[x, y + shift(x)] = sp[x, y]
    for x, y in upper:
        px[x, y] = sp[x, y]
    return im


def build(src_png: str | Path, out_dir: Path, put_helmet) -> list[Path]:
    from .faces import EXPRESSIONS, face_key
    out_dir.mkdir(parents=True, exist_ok=True)
    src = Image.open(src_png).convert("RGBA")
    src = src.crop(src.getbbox())
    made = {}
    for is_open, im in ((False, src), (True, open_mouth(src))):
        tmp = out_dir / "_src.png"
        im.save(tmp)
        target = out_dir / f"_{'open' if is_open else 'shut'}.png"
        put_helmet(str(tmp), str(target))
        tmp.unlink()
        made[is_open] = target
    out = []
    for tone in EXPRESSIONS:
        for is_open in (False, True):
            for blink in (False, True):
                t = out_dir / f"{face_key(tone, is_open, blink)}.png"
                shutil.copyfile(made[is_open], t)
                out.append(t)
    return out
