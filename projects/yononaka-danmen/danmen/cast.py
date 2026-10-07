# -*- coding: utf-8 -*-
"""立ち絵を読む。語り手（katari）と聞き手（kikite）の2人。

素材は `assets/characters/` にある全身の絵。画面では**胸から上**で使うことが
多いので、`bust` で上の方だけを切り出す。

    moods(who)                … その人に使える表情
    load(who, mood, h, part)  … 立ち絵を読む。part は bust / half / full
    put(im, who, mood, ...)   … 画面に置く。縁をうっすら光らせて背景から浮かせる

**名前と中身がずれている絵があったので注意。** katari_nattoku は中身が聞き手
だったので `raw/` に退避した。ここでは語りの「納得」は笑顔で代える。
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

BASE = Path(r"C:/Users/なみ/dev/output/yononaka-danmen/assets/characters")
_CACHE: dict[tuple, Image.Image] = {}

# 絵が無い表情は、近いものに寄せる
ALIAS = {
    ("katari", "nattoku"): "egao",       # 中身が聞き手だったので退避した
    ("katari", "warai"): "egao",
    ("katari", "yorokobi"): "hakushu",
    ("kikite", "setsumei"): "nattoku",
    ("kikite", "shinken"): "nattoku",
    ("kikite", "sumashi"): "",
    ("kikite", "komari"): "fuman",
    ("kikite", "rakutan"): "naki",
    ("kikite", "ikari"): "fuman",
}

# 胸から上／腰から上／全身。切る割合（上から）
PARTS = {"bust": 0.30, "half": 0.56, "full": 1.0}


def moods(who: str) -> list[str]:
    """その人に実際に絵がある表情。"""
    if not BASE.exists():
        return []
    out = []
    for p in BASE.glob(str(who) + "*.png"):
        s = p.stem
        out.append(s[len(who) + 1:] if s != who else "")
    return sorted(out)


def _file(who: str, mood: str) -> Path | None:
    mood = ALIAS.get((who, mood), mood)
    p = BASE / ((who + "_" + mood if mood else who) + ".png")
    if p.exists():
        return p
    p = BASE / (who + ".png")
    return p if p.exists() else None


def load(who: str, mood: str = "", h: int = 520, part: str = "bust") -> Image.Image | None:
    """立ち絵を読む。h は切り出したあとの高さ。"""
    key = (who, mood, h, part)
    if key in _CACHE:
        return _CACHE[key]
    p = _file(who, mood)
    if p is None:
        return None
    im = Image.open(p).convert("RGBA")
    frac = PARTS.get(part, 0.30)
    if frac < 1.0:
        im = im.crop((0, 0, im.width, int(im.height * frac)))
        bb = im.getbbox()
        if bb:
            im = im.crop(bb)
    s = h / im.height
    im = im.resize((max(int(im.width * s), 1), h), Image.LANCZOS)
    _CACHE[key] = im
    return im


def put(im: Image.Image, who: str, mood: str = "", h: int = 520, part: str = "bust",
        right: int | None = None, left: int | None = None, bottom: int | None = None,
        glow: bool = True, flip: bool = False) -> int:
    """画面に置く。right か left のどちらかで横の位置を決める。返すのは置いた幅。"""
    ch = load(who, mood, h, part)
    if ch is None:
        return 0
    if flip:
        ch = ch.transpose(Image.FLIP_LEFT_RIGHT)
    W, H = im.size
    by = H if bottom is None else bottom
    if right is not None:
        x = W - right - ch.width
    elif left is not None:
        x = left
    else:
        x = W - 40 - ch.width
    y = by - ch.height
    if glow:
        # 縁をうっすら光らせて、暗い背景から浮かせる
        a = ch.split()[3]
        ring = Image.new("RGBA", ch.size, (255, 255, 255, 0))
        ring.putalpha(a.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(6)))
        halo = Image.new("RGBA", im.size, (0, 0, 0, 0))
        halo.alpha_composite(Image.composite(
            Image.new("RGBA", ch.size, (255, 255, 255, 120)),
            Image.new("RGBA", ch.size, (255, 255, 255, 0)), ring.split()[3]), (x, y))
        im.alpha_composite(halo)
    im.alpha_composite(ch, (x, y))
    return ch.width
