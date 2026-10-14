"""サムネイルの作り込みと人物の切り抜き（2026-10-08、構図 face・scene・versus・number のときだけ）。

classic（構図を書かない回）には**一切使わない**。今のサムネと画素まで同じにするため。
別チャンネル「歴史の地層」の `chiso/thumbfx.py`（10-07）を、こちらの決まりに合わせて写した。

**写さなかったもの**（こちらの決まりに当たる）:
- 周辺のぼかし（`depth`）……「左がぼやけるのは禁止」（2026-09-20）。奥行きは暗さだけで出す
- 切り抜いた人物の後ろをぼかす処理 …… 同じ理由。後ろは**少し暗くするだけ**
- 紙の質感・破れの縁・古文書の札 …… 歴史の絵の飾りで、サッカーの写真に合わない

人物の切り抜きは rembg（**任意の依存**。requirements-cutout.txt。CI には入れない）。
入っていなければ切り抜かずに描く。学習済みデータ isnet-general-use（約179MB、無料）は
初回に `~/.rembg/models/` へ1回だけ落ちる。切り抜いた形は `output/cache/cutout/` に控える。
"""

from __future__ import annotations

import hashlib
import math
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageOps

WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
# versus の片側を染める赤（チャンネルの赤 BAND_RED と同じ系統）
TINT_RED = (222, 20, 30)


# --- 文字 -----------------------------------------------------------------------------

def text(img: Image.Image, xy, s: str, font, fill=WHITE, inner=BLACK, inner_w: int = 10,
         outer=None, outer_w: int = 0, shadow: bool = True, angle: float = 0.0,
         anchor: str = "la", spans=None) -> None:
    """二重の縁取り（内側 inner・外側 outer）と、下右にずらした影で1行描く。

    `spans` は [(文字, 色), …]。伏せ字の ● だけ赤にするのに使う（無ければ全部 fill）。
    img は RGBA でも RGB でもよい。
    """
    if not s:
        return
    stroke = inner_w + outer_w
    x0, y0, x1, y1 = font.getbbox(s, anchor=anchor, stroke_width=stroke)
    size = getattr(font, "size", 40)
    off = max(3, size // 20)
    pad = stroke + off * 3 + 8
    tw, th = x1 - x0 + pad * 2, y1 - y0 + pad * 2
    if angle:
        extra = int(abs(math.sin(math.radians(angle))) * max(tw, th) / 2) + 4
        pad += extra
        tw, th = tw + extra * 2, th + extra * 2
    ax, ay = pad - x0, pad - y0

    def mask(width: int) -> Image.Image:
        m = Image.new("L", (tw, th), 0)
        ImageDraw.Draw(m).text((ax, ay), s, font=font, fill=255, anchor=anchor,
                               stroke_width=width, stroke_fill=255)
        return m

    m_out, m_in = mask(stroke), mask(inner_w)
    tile = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    if shadow:
        sh = Image.new("L", (tw, th), 0)
        sh.paste(m_out, (off, off))
        sh = sh.filter(ImageFilter.GaussianBlur(max(1, off // 2))).point(lambda v: v * 170 // 255)
        tile.paste((0, 0, 0, 255), (0, 0), sh)
    if outer is not None and outer_w:
        tile.paste(tuple(outer) + (255,), (0, 0), m_out)
        tile.paste(tuple(inner) + (255,), (0, 0), m_in)
    else:
        tile.paste(tuple(inner) + (255,), (0, 0), m_out)
    # 中の色。spans があれば区切りごとに色を変える（左から順に、幅を測って並べる）
    ink = ImageDraw.Draw(tile)
    if spans and anchor.startswith("l"):
        x = ax
        for part, color in spans:
            ink.text((x, ay), part, font=font, fill=tuple(color) + (255,), anchor=anchor)
            x += font.getlength(part)
    else:
        ink.text((ax, ay), s, font=font, fill=tuple(fill) + (255,), anchor=anchor)
    if angle:
        tile = tile.rotate(angle, resample=Image.BICUBIC, center=(ax, ay))
    x, y = xy
    img.paste(tile, (int(round(x - ax)), int(round(y - ay))), tile)


# --- 光 -------------------------------------------------------------------------------

def _direction_mask(size, angle: float) -> Image.Image:
    """angle の向きに 0→255 と明るくなる斜めの勾配。"""
    w, h = size
    g = Image.linear_gradient("L").rotate(angle, resample=Image.BICUBIC, expand=True)
    s = g.width
    inner = int(s / math.sqrt(2)) - 4
    g = g.crop(((s - inner) // 2, (s - inner) // 2, (s + inner) // 2, (s + inner) // 2))
    return g.resize((w, h), Image.BILINEAR)


def light(img: Image.Image, side: str, color=(255, 236, 190), dark: float = 0.62,
          beam: float = 0.14) -> None:
    """主役の側を明るく、反対側を落とす斜めの光。光の側に細い光の帯を1本。

    **落とすのは明るさだけ**（ぼかさない）。反対側は字を置く所なので、暗いほうが読める。
    """
    angle = {"right": 60, "left": -60, "top": 180}.get(side)
    if angle is None:
        return
    w, h = img.size
    base = img.convert("RGB")
    m = _direction_mask((w, h), angle)
    lit = ImageEnhance.Brightness(base).enhance(1.06)
    shade = ImageEnhance.Brightness(base).enhance(dark)
    out = Image.composite(lit, shade, m.point(lambda v: min(255, int(v * 1.5))))
    band = Image.new("L", (w * 2, h * 2), 0)
    d = ImageDraw.Draw(band)
    if side == "top":
        d.rectangle([0, 0, w * 2, 240], fill=255)
        band = band.filter(ImageFilter.GaussianBlur(90)).crop((w // 2, 0, w // 2 + w, h))
    else:
        cx = w * 2 * (0.80 if side == "right" else 0.20)
        if side == "right":
            poly = [(cx - 90, 0), (cx + 60, 0), (cx - 380, h * 2), (cx - 620, h * 2)]
        else:
            poly = [(cx - 60, 0), (cx + 90, 0), (cx + 620, h * 2), (cx + 380, h * 2)]
        d.polygon(poly, fill=255)
        band = band.filter(ImageFilter.GaussianBlur(70)).resize((w, h))
    out = Image.composite(Image.new("RGB", (w, h), color), out, band.point(lambda v: int(v * beam)))
    _put(img, out)


def rays(img: Image.Image, center, color=(255, 240, 150), alpha: float = 0.16, n: int = 30,
         hole: int = 120, seed: int = 7) -> None:
    """放射状の光の筋（集中線を控えめに）。真ん中（文字の所）は薄くする。"""
    w, h = img.size
    cx, cy = center
    rnd = random.Random(seed)
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    r = math.hypot(w, h)
    step = 2 * math.pi / n
    for i in range(n):
        a = i * step + rnd.uniform(-0.15, 0.15) * step
        width = step * rnd.uniform(0.18, 0.42)
        d.polygon([(cx, cy), (cx + r * math.cos(a - width / 2), cy + r * math.sin(a - width / 2)),
                   (cx + r * math.cos(a + width / 2), cy + r * math.sin(a + width / 2))], fill=255)
    m = m.filter(ImageFilter.GaussianBlur(4))
    fade = Image.radial_gradient("L").resize((hole * 10, hole * 10))
    ring = Image.new("L", (w, h), 255)
    ring.paste(fade, (int(cx - fade.width / 2), int(cy - fade.height / 2)))
    ring = ring.point(lambda v: min(255, v * 3))
    m = ImageChops.multiply(m, ring).point(lambda v: int(v * alpha))
    base = img.convert("RGB")
    _put(img, Image.composite(Image.new("RGB", (w, h), color), base, m))


def tint(img: Image.Image, side: str, color=TINT_RED, strength: float = 0.42,
         split=None) -> None:
    """片側を赤に染める（明るさは残す）。split は境目の x（[上の x, 下の x] で斜め）。"""
    if side not in ("left", "right"):
        return
    w, h = img.size
    base = img.convert("RGB")
    colored = ImageOps.colorize(ImageOps.grayscale(base), (24, 0, 0), color,
                                mid=tuple(int(c * 0.75) for c in color))
    m = Image.new("L", (w, h), 0)
    top, bottom = split if isinstance(split, (list, tuple)) else (split or w // 2, split or w // 2)
    if side == "right":
        ImageDraw.Draw(m).polygon([(top, 0), (w, 0), (w, h), (bottom, h)], fill=int(255 * strength))
    else:
        ImageDraw.Draw(m).polygon([(0, 0), (top, 0), (bottom, h), (0, h)], fill=int(255 * strength))
    m = m.filter(ImageFilter.GaussianBlur(14))
    _put(img, Image.composite(colored, base, m))


def _put(img: Image.Image, rgb: Image.Image) -> None:
    """RGB の結果を img（RGBA でもよい）へ戻す。"""
    if img.mode == "RGBA":
        img.paste(rgb.convert("RGBA"))
    else:
        img.paste(rgb)


# --- 人物の切り抜き（rembg。入っていなければ切り抜かない） ---------------------------------

REMBG_MODEL = "isnet-general-use"
CACHE = Path("output/cache/cutout")
_SESSION = None
_MEMO: dict = {}


def available() -> bool:
    """rembg が入っているか（入っていなければ切り抜きは黙って外れる）。"""
    try:
        import rembg  # noqa: F401
    except ImportError:
        return False
    return True


def _segment(tile: Image.Image):
    """rembg で人物の形（L）を出す。rembg が無い環境（CI）では None。"""
    global _SESSION
    try:
        from rembg import new_session, remove
    except ImportError:
        return None
    if _SESSION is None:
        _SESSION = new_session(REMBG_MODEL)
    return remove(tile.convert("RGB"), session=_SESSION).getchannel("A")


def largest_blob(alpha: Image.Image, work: int = 240) -> Image.Image:
    """いちばん大きい塊だけ残す（後ろの観客・隣の選手の切れ端を落とす）。塊の中の穴は埋める。"""
    k = work / max(alpha.size)
    small = alpha.resize((max(1, int(alpha.width * k)), max(1, int(alpha.height * k))), Image.BILINEAR)
    lab = small.point(lambda v: 255 if v > 60 else 0).filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.MinFilter(3))
    label, sizes = 1, {}
    px = lab.load()
    for y in range(lab.height):
        for x in range(lab.width):
            if px[x, y] == 255 and label < 250:
                ImageDraw.floodfill(lab, (x, y), label)
                sizes[label] = lab.histogram()[label]
                label += 1
    if not sizes:
        return alpha
    best = max(sizes, key=sizes.get)
    keep = lab.point(lambda v: 255 if v == best else 0)
    outside = Image.new("L", (keep.width + 2, keep.height + 2), 0)
    outside.paste(keep, (1, 1))
    ImageDraw.floodfill(outside, (0, 0), 128)
    filled = outside.crop((1, 1, keep.width + 1, keep.height + 1)).point(lambda v: 0 if v == 128 else 255)
    soft = keep.resize(alpha.size, Image.BILINEAR).filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(2))
    inner = filled.resize(alpha.size, Image.BILINEAR).filter(ImageFilter.MinFilter(7)).filter(ImageFilter.GaussianBlur(3))
    return ImageChops.lighter(ImageChops.multiply(alpha, soft), inner)


# 抜けの良し悪しの目安。**悪ければ使わない**（今の写真のまま描く）
MIN_AREA = 0.04       # 人の形が絵のこれより小さい（何も抜けていない）
MIN_REACH = 0.55      # 人の形の下端が絵の高さのこれより上で終わる（首だけ・顔だけ）
MIN_SHOULDER = 1.35   # 下のほう（肩・胴）の幅が、上のほう（頭）の幅のこれ倍より狭い（体が欠けた）


def usable(mask: Image.Image, face=None) -> bool:
    """切り抜きが使えるか。首だけ・体が欠けた・顔の所が抜けていない形は使わない。

    face は顔の枠（x, y, w, h、mask と同じ座標）。分かっていれば、その真ん中が
    人の形の中にあることも見る（別の人を抜いていないか）。
    """
    small = mask.resize((200, max(2, int(200 * mask.height / mask.width)))).point(
        lambda v: 255 if v > 128 else 0)
    total = small.width * small.height
    area = small.histogram()[255] / total
    box = small.getbbox()
    if area < MIN_AREA or box is None:
        return False
    x0, y0, x1, y1 = box
    if y1 / small.height < MIN_REACH:
        return False

    def row_width(y: int) -> int:
        row = small.crop((0, y, small.width, y + 1)).getbbox()
        return 0 if row is None else row[2] - row[0]

    height = y1 - y0
    head = max(1, max(row_width(y0 + int(height * t)) for t in (0.06, 0.10, 0.14)))
    body = max(row_width(y0 + int(height * t)) for t in (0.55, 0.70, 0.85))
    if body < head * MIN_SHOULDER:
        return False
    if face is not None:
        fx, fy, fw, fh = face
        k = small.width / mask.width
        cx, cy = int((fx + fw / 2) * k), int((fy + fh / 2) * k)
        if not (0 <= cx < small.width and 0 <= cy < small.height):
            return False
        if small.getpixel((cx, cy)) < 128:
            return False
    return True


def key_of(tile: Image.Image, *parts) -> str:
    """控えの名前：**切ったあとの絵そのもの**のハッシュ。

    写真のファイルと大きさだけで鍵を作ると、切る位置（顔の寄せ方）を変えたときに
    前の位置の形を読んで、縁取りが人からずれた（2026-10-08、メッシの見本で踏んだ）。
    """
    digest = hashlib.sha1(tile.convert("RGB").tobytes()).hexdigest()
    return hashlib.sha1(repr((digest, tile.size) + parts).encode()).hexdigest()[:16]


def person_mask(tile: Image.Image, key: str, cache: Path | None = None, face=None):
    """tile（そのまま画面に貼る絵）から人物の形を出す。使えない形・rembg 無しなら None。

    cache（既定は CACHE）/cutout_<key>.png に控え、次からはそれを読む（rembg は1枚に数秒かかる）。
    """
    if key in _MEMO:
        return _MEMO[key]
    cache = CACHE if cache is None else cache
    path = Path(cache) / f"cutout_{key}.png" if cache else None
    if path is not None and not path.is_absolute():
        from .config import _resolve
        path = _resolve(path)
    if path is not None and path.exists():
        with Image.open(path) as im:
            m = im.convert("RGBA").getchannel("A")
        if m.size == tile.size:
            _MEMO[key] = m if usable(m, face) else None
            return _MEMO[key]
    seg = _segment(tile)
    if seg is None:
        return None
    m = largest_blob(seg.resize(tile.size))
    if path is not None:
        path.parent.mkdir(parents=True, exist_ok=True)
        out = tile.convert("RGBA")
        out.putalpha(m)
        out.save(path)
    _MEMO[key] = m if usable(m, face) else None
    return _MEMO[key]


def pop_out(img: Image.Image, tile: Image.Image, pos, mask: Image.Image, outline=WHITE,
            width: int = 9, clip: Image.Image | None = None, dim: float = 0.80) -> None:
    """切り抜いた人物を、太い縁取り＋影で前に浮かせる。後ろの写真は**少し暗くするだけ**（ぼかさない）。"""
    x, y = int(pos[0]), int(pos[1])
    a = Image.new("L", img.size, 0)
    a.paste(mask, (x, y))
    if clip is not None:
        a = ImageChops.multiply(a, clip)
    base = img.convert("RGB")
    if dim < 1:
        back = Image.new("L", img.size, 0)
        back.paste(255, (x, y, x + tile.width, y + tile.height))
        if clip is not None:
            back = ImageChops.multiply(back, clip)
        base = Image.composite(ImageEnhance.Brightness(base).enhance(dim), base, back)
    grown = a.filter(ImageFilter.GaussianBlur(width * 0.7)).point(lambda v: 255 if v > 24 else int(v * 10))
    sh = Image.new("L", img.size, 0)
    sh.paste(grown, (12, 12))
    base.paste((0, 0, 0), (0, 0), sh.filter(ImageFilter.GaussianBlur(12)).point(lambda v: int(v * 0.6)))
    base.paste(tuple(outline), (0, 0), grown)
    person = Image.new("RGB", img.size, 0)
    person.paste(tile.convert("RGB"), (x, y))
    base.paste(person, (0, 0), a)
    _put(img, base)
