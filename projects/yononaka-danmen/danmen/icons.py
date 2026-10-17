# -*- coding: utf-8 -*-
"""アイコンを読んで図に置く。

素材は `output/yononaka-danmen/assets/icons/` にある 30 点（Gemini で自作）。
縦横の比はまちまちなので、**高さを揃えて**置く。横幅で揃えると、
縦長のもの（ポンプ・人）と横長のもの（車・札束）で大きさが揃わない。

    names()              … 使えるアイコンの名前
    load(name, h)        … 高さ h に合わせて読む。無ければ None
    put(im, name, cx, by, h)  … 中心 x・下端 y を指定して置く
    plate(name, h, ...)  … 丸い台に載せたアイコンを作る（並べるときに揃って見える）
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

BASE = Path(r"C:/Users/なみ/dev/output/yononaka-danmen/assets/icons")
_CACHE: dict[tuple[str, int], Image.Image] = {}

# 使わないもの。Gemini が絵の中に文字を焼き込んでしまい、崩れた漢字が読めてしまう。
# smartphone / toolbox / worker は文字の帯を切り落として直した（元は icons/raw/ にある）。
AVOID = {"stamp"}                     # 印鑑の面の字は切り落とせない


def names() -> list[str]:
    """使えるアイコンの名前。文字が読めてしまうものは外す。"""
    if not BASE.exists():
        return []
    return sorted(p.stem for p in BASE.glob("*.png") if p.stem not in AVOID)


def load(name: str, h: int) -> Image.Image | None:
    """高さ h に合わせて読む。見つからなければ None（図は空けて描き続ける）。"""
    key = (name, h)
    if key in _CACHE:
        return _CACHE[key]
    p = BASE / (str(name) + ".png")
    if not p.exists():
        return None
    im = Image.open(p).convert("RGBA")
    w = max(int(im.width * h / im.height), 1)
    im = im.resize((w, h), Image.LANCZOS)
    _CACHE[key] = im
    return im


def put(im: Image.Image, name: str, cx: float, by: float, h: int,
        shadow: bool = True) -> int:
    """中心 x・下端 y を指定して置く。置いた幅を返す（置けなければ 0）。"""
    ic = load(name, h)
    if ic is None:
        return 0
    x, y = int(cx - ic.width / 2), int(by - h)
    if shadow:
        # 足もとに薄い影。浮いて見えないように
        sh = Image.new("RGBA", im.size, (0, 0, 0, 0))
        sw = int(ic.width * 0.62)
        ImageDraw.Draw(sh).ellipse(
            [cx - sw / 2, by - h * 0.06, cx + sw / 2, by + h * 0.07],
            fill=(0, 0, 0, 46))
        im.alpha_composite(sh.filter(ImageFilter.GaussianBlur(7)))
    im.alpha_composite(ic, (x, y))
    return ic.width


def plate(name: str, h: int, pad: int = 26,
          fill: tuple[int, int, int] = (241, 243, 246),
          ring: tuple[int, int, int] | None = None) -> Image.Image:
    """丸い台に載せたアイコン。縦横の比が違うものを並べても大きさが揃って見える。"""
    d_ = h + pad * 2
    out = Image.new("RGBA", (d_, d_), (0, 0, 0, 0))
    dr = ImageDraw.Draw(out)
    dr.ellipse([0, 0, d_ - 1, d_ - 1], fill=fill + (255,))
    if ring:
        dr.ellipse([0, 0, d_ - 1, d_ - 1], outline=ring + (255,), width=5)
    ic = load(name, int(h * 0.88))
    if ic is not None:
        out.alpha_composite(ic, ((d_ - ic.width) // 2, (d_ - ic.height) // 2))
    return out
