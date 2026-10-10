# -*- coding: utf-8 -*-
"""サムネイル（1280×720）。台本の `thumbnail:` 欄から作る。

**歴史の地層の `chiso/thumb.py` の決まりを写した**（2026-10-09）。

| | |
|---|---|
| 文字 | 上下の2〜3かたまり。**1語だけ特大の黄** |
| キャラ | **右下に2人。** 岬が後ろ、驚いた小倉が手前 |
| 目印 | **下端の細い金の帯だけ。** チャンネル名の札は入れない |
| 右下の隅 | **文字を置かない**（YouTube の再生時間が重なる） |
| 構図 | **回ごとに変える。** そろえるのは帯・字体・色だけ |

**量産型に見せないための肝は「構図を毎回変えること」。**
そろえるものを増やすほど、並べたときに同じ顔に見える。

台本の書き方:

    thumbnail:
      layout: classic          # classic / number / versus
      photo: gas_station       # assets/photos のファイル名（部分一致で探す）
      icon: pump               # 右上に置くアイコン（assets/icons の名前）
      hook: ガソリンが高いのは     # 上・小さく
      myth: 原油のせい            # 上・通説
      stamp: それだけじゃない      # 通説を打ち消す赤い判子
      tag: 2年だけ が半世紀        # 金の札（**事実で煽る**。嘘の煽りは入れない）
      lead: 1リットル175円のうち   # 主役の数字の上
      main: 70.6円               # **特大の黄。1本に1つだけ**
      tail: が、税金              # 数字の下
      bars: [[本体, 92], [税金, 70.6], [流通, 12]]   # 数字の下の内訳
      credit: 資源エネルギー庁の週次調査をもとに試算
"""
from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

from danmen import cast, icons, screens

W, H = 1280, 720
VF = r"C:/Windows/Fonts/NotoSansJP-VF.ttf"
PHOTOS = Path(r"C:/Users/なみ/dev/output/yononaka-danmen/assets/photos")
GOLD, CREAM, RED, NAVY = (255, 206, 72), (252, 250, 245), (214, 48, 49), (10, 16, 34)
BAR_COLORS = [(116, 136, 178), GOLD, (214, 152, 60), (156, 112, 66), (96, 150, 140)]
LAYOUTS = ("classic", "number", "versus", "term")


def F(size: int, weight: int = 900):
    f = ImageFont.truetype(VF, size)
    try:
        f.set_variation_by_axes([weight])
    except Exception:
        pass
    return f


def find_photo(key: str | None) -> Path | None:
    """部分一致で写真を探す。**名前の文字列を backdrop にそのまま渡さない**
    （パスを受け取る作りなので、文字列だと濃紺のままになる。2026-10-09 に踏んだ）。"""
    if not key or not PHOTOS.exists():
        return None
    k = str(key).lower()
    for p in sorted(PHOTOS.glob("*.jpe*g")) + sorted(PHOTOS.glob("*.png")):
        if k in p.name.lower():
            return p
    return None


def backdrop(key, dark=0.38):
    im = screens.backdrop(find_photo(key), dark=dark, blur=2).convert("RGB")
    return im.resize((W, H), Image.LANCZOS)


def _vignette(im):
    v = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(v)
    d.rectangle([0, 0, W, H], fill=(4, 8, 18, 160))
    d.ellipse([-W * 0.2, -H * 0.3, W * 1.2, H * 1.3], fill=(0, 0, 0, 0))
    im.alpha_composite(v.filter(ImageFilter.GaussianBlur(90)))


def _speed_lines(im, cx, cy, n=130, a=58):
    lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    rng = random.Random(5)
    for _ in range(n):
        ang = rng.uniform(0, 2 * math.pi)
        r0 = rng.uniform(260, 420)
        r1 = r0 + rng.uniform(260, 620)
        d.line([(cx + r0 * math.cos(ang), cy + r0 * math.sin(ang)),
                (cx + r1 * math.cos(ang), cy + r1 * math.sin(ang))],
               fill=(255, 255, 255, a), width=rng.choice((2, 3, 4, 6)))
    im.alpha_composite(lay.filter(ImageFilter.GaussianBlur(1.2)))


def _glow_text(im, xy, s, size, fill, stroke=20, glow=GOLD, amt=28):
    lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(lay).text(xy, s, font=F(size), fill=glow + (200,),
                             stroke_width=stroke + 12, stroke_fill=glow + (160,))
    im.alpha_composite(lay.filter(ImageFilter.GaussianBlur(amt)))
    ImageDraw.Draw(im).text(xy, s, font=F(size), fill=fill,
                            stroke_width=stroke, stroke_fill=(6, 10, 18))


def _slant(im, y, h, col=NAVY, alpha=235, deg=-4):
    lay = Image.new("RGBA", (W + 300, h + 160), (0, 0, 0, 0))
    ImageDraw.Draw(lay).rectangle([0, 80, W + 300, 80 + h], fill=col + (alpha,))
    im.alpha_composite(lay.rotate(deg, resample=Image.BICUBIC, expand=False), (-150, y - 80))


def _stamp(text, deg=-9, size=38):
    f = F(size)
    tw = int(f.getbbox(text)[2])
    im = Image.new("RGBA", (tw + 60, size + 42), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((0, 0, im.width - 8, im.height - 6), 12, fill=RED)
    d.rounded_rectangle((3, 3, im.width - 11, im.height - 9), 10,
                        outline=(255, 255, 255, 200), width=3)
    d.text((im.width // 2 - 4, im.height // 2 - 3), text, font=f, fill="white", anchor="mm")
    return im.rotate(deg, expand=True, resample=Image.BICUBIC)


def _tag(text, size=34):
    f = F(size)
    tw = int(f.getbbox(text)[2])
    im = Image.new("RGBA", (tw + 48, size + 28), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((0, 0, im.width - 4, im.height - 4), 10, fill=GOLD)
    d.text((im.width // 2 - 2, im.height // 2 - 2), text, font=f, fill=(20, 24, 40), anchor="mm")
    return im.rotate(-3, expand=True, resample=Image.BICUBIC)


def _arrow(im, x0, y0, x1, y1, w=15):
    lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    d.line([(x0, y0), (x1, y1)], fill=RED + (255,), width=w)
    ang = math.atan2(y1 - y0, x1 - x0)
    for s in (0.6, -0.6):
        d.line([(x1, y1), (x1 - 46 * math.cos(ang + s), y1 - 46 * math.sin(ang + s))],
               fill=RED + (255,), width=w)
    im.alpha_composite(lay.filter(ImageFilter.GaussianBlur(8)))
    im.alpha_composite(lay)


def _bubble(text, size=44):
    f = F(size)
    bw = int(f.getbbox(text)[2]) + 76
    im = Image.new("RGBA", (bw, size + 66), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((0, 0, bw - 1, size + 40), 20, fill=(255, 255, 255, 247),
                        outline=(20, 28, 48, 255), width=6)
    d.polygon([(bw * 0.26, size + 38), (bw * 0.42, size + 38), (bw * 0.24, size + 64)],
              fill=(255, 255, 255, 247), outline=(20, 28, 48, 255))
    d.text((bw // 2, (size + 40) // 2), text, font=f, fill=(24, 30, 48), anchor="mm")
    return im


DECOR = Path(r"C:/Users/なみ/dev/output/yononaka-danmen/assets/decor")
# 明るさをアルファにしてある素材は、**重ねて光らせる**（覆い焼きに近い使い方）
GLOW_DECOR = {"rays", "crack"}


def decor(name: str, h: int) -> Image.Image | None:
    """飾りの素材（Gemini 製 6種）。burst／ink／crack／ribbon／torn／rays。"""
    p = DECOR / "{}.png".format(name)
    if not p.exists():
        return None
    im = Image.open(p).convert("RGBA")
    s = h / im.height
    return im.resize((max(1, int(im.width * s)), h), Image.LANCZOS)


def put_decor(im, name: str, xy, h: int, alpha: float = 1.0, deg: float = 0.0):
    """飾りを重ねる。**1枚に2つまで。** 多いと散らかって文字が読めなくなる。"""
    d = decor(name, h)
    if d is None:
        return
    if deg:
        d = d.rotate(deg, expand=True, resample=Image.BICUBIC)
    if alpha < 0.999:
        d.putalpha(d.split()[3].point(lambda v: int(v * alpha)))
    im.alpha_composite(d, xy)


def _icon(im, name, h=210):
    """右上にアイコン。**実際の幅から右端を決める**（決め打ちだとはみ出す）。"""
    ic = icons.load(name, h) if name else None
    if ic is None:
        return
    ix, iy = W - ic.width - 46, 60
    ring = Image.new("RGBA", (ic.width + 90, ic.height + 90), (0, 0, 0, 0))
    ImageDraw.Draw(ring).ellipse((0, 0, ring.width - 1, ring.height - 1), fill=GOLD + (46,))
    im.alpha_composite(ring.filter(ImageFilter.GaussianBlur(26)), (ix - 45, iy - 45))
    sh = ic.copy()
    sh.putalpha(ic.split()[3].point(lambda v: int(v * 0.55)))
    im.alpha_composite(sh.filter(ImageFilter.GaussianBlur(10)), (ix + 6, iy + 10))
    im.alpha_composite(ic, (ix, iy))


def _two(im, h_back=400, h_front=430, bubble_text=""):
    k = cast.load("katari", "", h_back, "bust")
    c = cast.load("kikite", "odoroki", h_front, "bust")
    if c is None:
        return
    bx = W - 24 - c.width
    if k is not None:
        dim = ImageEnhance.Brightness(k.convert("RGB")).enhance(0.82).convert("RGBA")
        dim.putalpha(k.split()[3])
        im.alpha_composite(dim, (bx - int(k.width * 0.64), H - k.height - 14))
    im.alpha_composite(c, (bx, H - c.height - 14))
    if bubble_text:
        im.alpha_composite(_bubble(bubble_text), (bx - 76, H - c.height - 64))


def _bars(d, x, y, w, h, parts):
    total = sum(v for _, v in parts) or 1
    cx = x
    for i, (_, v) in enumerate(parts):
        bw = int(w * v / total)
        d.rectangle([cx, y, cx + bw, y + h], fill=BAR_COLORS[i % len(BAR_COLORS)])
        cx += bw
    d.rectangle([x - 2, y - 2, x + w + 2, y + h + 2], outline=(250, 250, 250), width=3)


def _band(im, credit=""):
    """下端の細い帯。**これだけが毎回そろう目印。**"""
    # **サムネイルに出典は書かない**（2026-10-10 ユーザー「サムネに出典は不要」）。
    # 出典は本編の板と概要欄に出す。台本の credit: は残っていても描かない
    d = ImageDraw.Draw(im)
    d.rectangle([0, H - 14, W, H], fill=NAVY)
    d.rectangle([0, H - 17, W, H - 14], fill=GOLD)


def _classic(spec):
    im = backdrop(spec.get("photo"), 0.34).convert("RGBA")
    _vignette(im)
    _speed_lines(im, 430, 430)
    _icon(im, spec.get("icon"))
    _slant(im, 14, 104)
    d = ImageDraw.Draw(im)
    if spec.get("hook"):
        d.text((42, 30), str(spec["hook"]), font=F(46, 800), fill=(196, 210, 236),
               stroke_width=8, stroke_fill=(6, 10, 18))
    if spec.get("myth"):
        d.text((42, 84), str(spec["myth"]), font=F(58), fill=CREAM,
               stroke_width=10, stroke_fill=(6, 10, 18))
        if spec.get("stamp"):
            w = d.textlength(str(spec["myth"]), font=F(58))
            im.alpha_composite(_stamp(str(spec["stamp"])), (int(42 + w + 24), 74))
    if spec.get("tag"):
        im.alpha_composite(_tag(str(spec["tag"])), (42, 184))
    if spec.get("lead"):
        d.text((46, 262), str(spec["lead"]), font=F(42, 800), fill=(214, 226, 246),
               stroke_width=8, stroke_fill=(6, 10, 18))
    # 飾り（任意）。**1枚に2つまで**
    for i, dec in enumerate((spec.get("decor") or [])[:2]):
        put_decor(im, str(dec.get("name", "")),
                  (int(dec.get("x", 0)), int(dec.get("y", 0))),
                  int(dec.get("h", 260)), float(dec.get("alpha", 1.0)),
                  float(dec.get("deg", 0)))
    main = str(spec.get("main", ""))
    if main:
        _glow_text(im, (36, 306), main, 206, GOLD)
    if spec.get("tail"):
        d2 = ImageDraw.Draw(im)
        d2.text((46, 528), str(spec["tail"]), font=F(74), fill=CREAM,
                stroke_width=13, stroke_fill=(6, 10, 18))
    parts = [(str(a), float(b)) for a, b in (spec.get("bars") or [])]
    if parts:
        d3 = ImageDraw.Draw(im)
        _bars(d3, 46, 626, 560, 34, parts)
    if main:
        _arrow(im, 690, 276, 536, 352)
    _two(im, bubble_text=str(spec.get("bubble", "")))
    _band(im, str(spec.get("credit", "")))
    return im.convert("RGB")


def _number(spec):
    im = backdrop(spec.get("photo"), 0.52).convert("RGBA")
    _vignette(im)
    _speed_lines(im, 380, 360, 150, 66)
    _icon(im, spec.get("icon"), 190)
    d = ImageDraw.Draw(im)
    if spec.get("lead"):
        d.text((52, 40), str(spec["lead"]), font=F(56, 800), fill=CREAM,
               stroke_width=12, stroke_fill=(6, 10, 18))
    main = str(spec.get("main", ""))
    if main:
        _glow_text(im, (40, 112), main, 236, GOLD, stroke=24)
    if spec.get("tail"):
        d.text((52, 410), str(spec["tail"]), font=F(70), fill=CREAM,
               stroke_width=14, stroke_fill=(6, 10, 18))
    if spec.get("tail2"):
        d.text((52, 500), str(spec["tail2"]), font=F(104), fill=CREAM,
               stroke_width=18, stroke_fill=(6, 10, 18))
    _two(im, 330, 356, str(spec.get("bubble", "")))
    _band(im, str(spec.get("credit", "")))
    return im.convert("RGB")


def _versus(spec):
    left, right = spec.get("left", {}), spec.get("right", {})
    im = Image.new("RGBA", (W, H), NAVY)
    for side, s in (("l", left), ("r", right)):
        b = backdrop(s.get("photo"), 0.40).crop((120, 0, 760, H)).resize((W // 2, H), Image.LANCZOS)
        im.paste(b, (0 if side == "l" else W // 2, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([W // 2 - 4, 0, W // 2 + 4, H], fill=GOLD)
    for x0, s, gold in ((46, left, True), (W // 2 + 46, right, False)):
        if s.get("name"):
            d.text((x0, 40), str(s["name"]), font=F(72), fill=CREAM,
                   stroke_width=14, stroke_fill=(6, 10, 18))
        if s.get("value"):
            col = GOLD if gold else CREAM
            d.text((x0 - 6, 128), str(s["value"]), font=F(112), fill=col,
                   stroke_width=18, stroke_fill=(6, 10, 18))
    if spec.get("lead"):
        d.text((46, 470), str(spec["lead"]), font=F(50), fill=CREAM,
               stroke_width=11, stroke_fill=(6, 10, 18))
    if spec.get("tail"):
        d.text((46, 536), str(spec["tail"]), font=F(96), fill=CREAM,
               stroke_width=17, stroke_fill=(6, 10, 18))
    _two(im, 330, 356, str(spec.get("bubble", "")))
    _band(im, str(spec.get("credit", "")))
    return im.convert("RGB")


def _term(spec):
    """**言葉そのものを主役にする**（2026-10-10 ユーザー「カルテルとは？を強くする」）。

    上に問いの言葉を画面いっぱいの金で（`main`）。その下に、その言葉で起きた事実を白で
    （`lead` 小・`tail` 大・`tail2`）。右下に2人。人と文字が重ならないよう、下の文字は左半分に収める。
    """
    im = backdrop(spec.get("photo"), 0.40).convert("RGBA")
    _vignette(im)
    _speed_lines(im, 640, 200, 150, 60)
    main = str(spec.get("main", ""))
    if main:
        # 画面の幅に合わせて大きさを決める（左右 40px）
        size = 260
        while size > 120 and ImageDraw.Draw(im).textlength(main, font=F(size)) > W - 80:
            size -= 4
        w = ImageDraw.Draw(im).textlength(main, font=F(size))
        _glow_text(im, (int((W - w) / 2), 18), main, size, GOLD, stroke=24)
    d = ImageDraw.Draw(im)
    y = 300
    if spec.get("lead"):
        d.text((48, y), str(spec["lead"]), font=F(48, 800), fill=(214, 226, 246),
               stroke_width=10, stroke_fill=(6, 10, 18))
        y += 66
    if spec.get("tail"):
        d.text((44, y), str(spec["tail"]), font=F(112), fill=CREAM,
               stroke_width=18, stroke_fill=(6, 10, 18))
        y += 138
    if spec.get("tail2"):
        d.text((48, y), str(spec["tail2"]), font=F(64), fill=CREAM,
               stroke_width=13, stroke_fill=(6, 10, 18))
    _two(im, 340, 368, str(spec.get("bubble", "")))
    _band(im, str(spec.get("credit", "")))
    return im.convert("RGB")


def make(spec: dict) -> Image.Image:
    """台本の `thumbnail:` 欄からサムネイルを作る。"""
    layout = str(spec.get("layout", "classic"))
    fn = {"classic": _classic, "number": _number, "versus": _versus, "term": _term}.get(layout)
    if fn is None:
        raise ValueError("知らない構図です: {}（使えるのは {}）".format(layout, "／".join(LAYOUTS)))
    return fn(spec)


def layout_streak(layouts: list[str], limit: int = 3) -> str | None:
    """**同じ構図が続いていないか。** 量産型に見える原因はこれ。"""
    run, prev = 0, None
    for la in layouts:
        run = run + 1 if la == prev else 1
        prev = la
        if run >= limit:
            return "構図「{}」が {} 回続いています。別の構図にしてください".format(la, run)
    return None
