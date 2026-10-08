"""サムネイルの「押したくなる」要素（10-08 ユーザー「サムネにもう少し人を惹きつける要素を入れたい！」）。

人気の歴史解説24枚の調べ（research/thumb_hooks.md）で強かった要素を、どの構図にも台本で足し外しできるようにした。
書かなければ何もしない（今までのサムネイルは画素まで同じ）。**1枚に1つか2つまで**（盛ると量産型の解説に見える）。

    thumbnail:
      reactor: {who: tsumugi, face: 驚き, side: right, size: large}
                          # 聞き手の驚き顔を腰から上で大きく。主役（画面の真ん中）の方を向く。右下の小さい2人は出さない
                          # who: tsumugi／kenzaki、face: config の表情（驚き・疑問…）、side: right／left、size: large／medium
      hide: {box: [x0, y0, x1, y1], style: silhouette, mark: "？"}
                          # 絵の一部を隠して大きな「？」。style: silhouette（影絵）／blackout（黒塗り）／blur（ぼかし）
                          # **本編で答えが出るものだけ**（台本と合わないサムネは YouTube の「誤解を招く」決まりに当たる）
      contrast: [天下人, 供は100人]
                          # 落差の二語。左（上）は小さめ白、右（下）は特大の黄。lead・main の代わりに同じ所へ出す
                          # {from, to, style: arrow／strike}。arrow は間に赤い矢印、strike は上の語を赤線で消して下に本当の語
      flip: true          # 肖像を左右反転（face・versus の left／right にも書ける）。auto なら facing（元の絵で顔が向く側）から決める
      facing: right       # 元の絵で人物が向いている側。文字の方を向いていなければ auto で反転する
      flash: true         # 事件の瞬間の赤い光（炎・爆ぜる火の粉）。{at: [x, y], color: [r, g, b]}

座標はサムネイル（1280x720）の座標。
"""
from __future__ import annotations

import hashlib
import math
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps

from . import thumbfx

W, H = 1280, 720
YEL = (255, 214, 40)
ORANGE = (255, 150, 30)
RED = (205, 30, 40)
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
EMBER = (255, 96, 24)

KEYS = ("reactor", "hide", "contrast", "flip", "flash")
WHO = {"tsumugi": "聞き", "つむぎ": "聞き", "聞き": "聞き", "kenzaki": "語り", "剣崎": "語り", "語り": "語り"}
FACING = {"聞き": "left", "語り": "front"}     # 立ち絵が向いている側（つむぎは左へ腕を出す・剣崎は正面）
SIZES = {"large": 0.88, "medium": 0.68}       # 画面の高さの何割を立ち絵にするか
BUST = 0.42                                   # 立ち絵の上から何割を見せるか（腰から上）
HIDE_STYLES = ("silhouette", "blackout", "blur")
CONTRAST_STYLES = ("auto", "arrow", "strike")
from .check import THUMB_HOOKS_MAX as MAX_HOOKS  # noqa: E402  これより多く足すと check が知らせる（目安は check.py の頭）


def used(t: dict) -> list[str]:
    """台本で足した要素の名前（書いた順）。"""
    return [k for k in KEYS if t.get(k) not in (None, False)]


# --- 書き方の点検 ----------------------------------------------------------------------

def _box(b) -> bool:
    return isinstance(b, (list, tuple)) and len(b) == 4 and b[0] < b[2] and b[1] < b[3]


def problems(t: dict) -> list[str]:
    """書き方の誤り（check が × にする）。"""
    out = []
    r = t.get("reactor")
    if r not in (None, False):
        r = reactor_spec(r)
        if r["who"] not in WHO:
            out.append(f"サムネイルの reactor.who は tsumugi か kenzaki: {r['who']}")
        if r["side"] not in ("left", "right"):
            out.append("サムネイルの reactor.side は right か left")
        if r["size"] not in SIZES:
            out.append(f"サムネイルの reactor.size は {'／'.join(SIZES)}")
    h = t.get("hide")
    if h not in (None, False):
        if not (isinstance(h, dict) and _box(h.get("box"))):
            out.append("サムネイルの hide は {box: [x0, y0, x1, y1], style, mark}")
        elif h.get("style", "silhouette") not in HIDE_STYLES:
            out.append(f"サムネイルの hide.style は {'／'.join(HIDE_STYLES)}")
    c = t.get("contrast")
    if c not in (None, False):
        try:
            contrast_spec(c)
        except ValueError as e:
            out.append(str(e))
    for where, v in [("", t)] + [(f"{k}.", t[k]) for k in ("left", "right") if isinstance(t.get(k), dict)]:
        if v.get("flip") not in (None, True, False, "auto"):
            out.append(f"サムネイルの {where}flip は true／false／auto")
        if v.get("facing") not in (None, "left", "right"):
            out.append(f"サムネイルの {where}facing は left か right（元の絵で人物が向いている側）")
    f = t.get("flash")
    if isinstance(f, dict) and f.get("at") is not None and not (isinstance(f["at"], (list, tuple)) and len(f["at"]) == 2):
        out.append("サムネイルの flash.at は [x, y]")
    return out


def notes(t: dict) -> list[str]:
    """気をつけること（check が知らせる。止めない）。"""
    out = []
    n = used(t)
    if len(n) > MAX_HOOKS:
        out.append(f"サムネイルの引きの要素が{len(n)}つ（{'・'.join(n)}）。主役を1つに絞るため{MAX_HOOKS}つまでを推奨")
    if t.get("hide") not in (None, False):
        out.append("サムネイルで隠したもの（hide）の答えが本編で出るか確かめる（出ないなら誤解を招くサムネになる）")
    if t.get("contrast") not in (None, False):
        out.append("サムネイルの落差の二語（contrast）が本編の事実と合っているか確かめる")
    flips = [("", t)] + [(f"{k}.", t[k]) for k in ("left", "right") if isinstance(t.get(k), dict)]
    for where, v in flips:
        if v.get("flip") in (True, "auto"):
            out.append(f"サムネイルの {where}flip：肖像を左右反転します。文字・紋の入った絵、和服（左前＝死者の着方になる）・"
                       "刀の差し方が分かる絵では使わない（目で確かめる）")
        if v.get("flip") == "auto" and not v.get("facing"):
            out.append(f"サムネイルの {where}flip: auto には {where}facing（元の絵で人物が向いている側）が要ります（いまは反転しません）")
    return out


# --- 左右反転（視線の向き） --------------------------------------------------------------

def want_flip(v: dict, toward: str) -> bool:
    """人物を toward（left／right）の向きにするために反転するか。flip: true は必ず、auto は facing から。"""
    f = v.get("flip")
    if f is True:
        return True
    if f == "auto":
        return v.get("facing") in ("left", "right") and v["facing"] != toward
    return False


def mirror(img: Image.Image, crop):
    """絵を左右反転し、crop（元の絵の座標）も反転した絵の座標に直す。"""
    out = ImageOps.mirror(img)
    if not crop:
        return out, crop
    x0, y0, x1, y1 = crop
    return out, [img.width - x1, y0, img.width - x0, y1]


# --- 聞き手の驚き顔（reactor） ------------------------------------------------------------

def reactor_spec(r) -> dict:
    r = {} if r is True else dict(r or {})
    return {"who": str(r.get("who", "tsumugi")), "face": str(r.get("face", "驚き")), "side": r.get("side", "right"),
            "size": r.get("size", "large")}


_FIG: dict = {}


def reactor_figure(r: dict, config: dict, assets: Path) -> Image.Image | None:
    """腰から上の立ち絵（主役＝画面の真ん中の方を向く）。立ち絵が無ければ None。"""
    who = WHO.get(r["who"], "聞き")
    cast = (config.get("cast") or {}).get(who) or {}
    src = None
    if cast.get("faces"):
        for name in (f"{r['face']}_open.png", f"{r['face']}_shut.png"):
            p = assets / cast["faces"] / name
            if p.exists():
                src = p
                break
    if src is None and who == "聞き" and (assets / "characters" / "tsumugi_surprised_helmet.png").exists():
        src = assets / "characters" / "tsumugi_surprised_helmet.png"
    if src is None and cast.get("image") and (assets / cast["image"]).exists():
        src = assets / cast["image"]
    if src is None:
        return None
    key = (str(src), r["size"], r["side"])
    if key not in _FIG:
        im = Image.open(src).convert("RGBA")
        im = im.crop(im.getbbox())
        im = im.crop((0, 0, im.width, int(im.height * BUST)))
        h = int(H * SIZES[r["size"]])
        im = im.resize((max(1, int(im.width * h / im.height)), h), Image.LANCZOS)
        toward = "left" if r["side"] == "right" else "right"
        if FACING[who] not in (toward, "front"):
            im = ImageOps.mirror(im)
        _FIG[key] = im
    return _FIG[key]


def reactor_box(t: dict, config: dict, assets: Path):
    """立ち絵の置き場所（x0, y0, x1, y1）。文字はここを避ける。"""
    if t.get("reactor") in (None, False):
        return None
    r = reactor_spec(t["reactor"])
    fig = reactor_figure(r, config, assets)
    if fig is None:
        return None
    x = W - fig.width + 18 if r["side"] == "right" else -18
    return (x, H - fig.height, x + fig.width, H)


def put_reactor(img: Image.Image, t: dict, config: dict, assets: Path) -> None:
    """立ち絵を下の隅に。縁を光らせて暗い絵から浮かせ、下に影。"""
    box = reactor_box(t, config, assets)
    if box is None:
        return
    r = reactor_spec(t["reactor"])
    fig = reactor_figure(r, config, assets)
    x, y = box[0], box[1]
    a = Image.new("L", img.size, 0)
    a.paste(fig.getchannel("A"), (x, y))
    sh = Image.new("L", img.size, 0)
    sh.paste(a, (-14 if r["side"] == "right" else 14, 10))
    img.paste(BLACK, (0, 0), sh.filter(ImageFilter.GaussianBlur(14)).point(lambda v: int(v * 0.7)))
    glow = a.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(10)).point(lambda v: min(255, int(v * 1.1)))
    img.paste((255, 236, 190), (0, 0), glow)
    img.paste(fig, (x, y), fig)


# --- 隠して見せる（hide） ---------------------------------------------------------------

def _silhouette_shape(size) -> Image.Image:
    """人の形（頭と肩）の影。切り抜きが使えないときの形。"""
    w, h = size
    m = Image.new("L", (w * 4, h * 4), 0)
    d = ImageDraw.Draw(m)
    W4, H4 = w * 4, h * 4
    hw = min(W4 * 0.46, H4 * 0.34)                   # 頭の幅
    cx = W4 / 2
    d.ellipse([cx - hw / 2, H4 * 0.05, cx + hw / 2, H4 * 0.05 + hw * 1.25], fill=255)
    d.rectangle([cx - hw * 0.22, H4 * 0.05 + hw * 1.1, cx + hw * 0.22, H4 * 0.05 + hw * 1.45], fill=255)
    sw = min(W4 * 0.98, hw * 2.6)
    top = H4 * 0.05 + hw * 1.35
    d.rounded_rectangle([cx - sw / 2, top, cx + sw / 2, H4 + hw], radius=int(hw * 0.7), fill=255)
    return m.resize((w, h), Image.LANCZOS)


def _hide_key(region: Image.Image) -> str:
    return hashlib.sha1(region.tobytes()).hexdigest()[:16]


def hide(img: Image.Image, t: dict, gothic, cache: Path | None = None) -> None:
    h = t.get("hide")
    if not (isinstance(h, dict) and _box(h.get("box"))):
        return
    x0, y0, x1, y1 = (int(v) for v in h["box"])
    x0, y0, x1, y1 = max(0, x0), max(0, y0), min(W, x1), min(H, y1)
    region = img.crop((x0, y0, x1, y1))
    style = h.get("style", "silhouette")
    if style == "blackout":                                 # 黒塗り（公文書の墨消し）。少し傾けた黒い板
        m = Image.new("L", img.size, 0)
        ImageDraw.Draw(m).rounded_rectangle([x0, y0, x1, y1], radius=10, fill=255)
        sh = Image.new("L", img.size, 0)
        sh.paste(m, (8, 8))
        img.paste(BLACK, (0, 0), sh.filter(ImageFilter.GaussianBlur(8)).point(lambda v: int(v * 0.6)))
        img.paste((14, 12, 10), (0, 0), m)
        ImageDraw.Draw(img).rounded_rectangle([x0, y0, x1, y1], radius=10, outline=RED, width=6)
    elif style == "blur":                                   # 強いぼかし＋暗く（何かは分かるが誰かは分からない）
        soft = region.filter(ImageFilter.GaussianBlur(max(14, (x1 - x0) // 14)))
        soft = Image.blend(soft, Image.new("RGB", soft.size, (20, 14, 10)), 0.25)
        m = Image.new("L", region.size, 0)                  # 縁をぼかした楕円（四角い板に見せない）
        e = max(8, min(region.size) // 10)
        ImageDraw.Draw(m).ellipse([e, e, region.width - 1 - e, region.height - 1 - e], fill=255)
        img.paste(soft, (x0, y0), m.filter(ImageFilter.GaussianBlur(e)))
    else:                                                   # 影絵：人物の形を黒く、縁だけ光らせる
        m = None
        mask = thumbfx.person_mask(region, "hide_" + _hide_key(region), cache)
        if mask is not None:
            m = mask
        if m is None:
            m = _silhouette_shape(region.size)
        a = Image.new("L", img.size, 0)
        a.paste(m, (x0, y0))
        rim = ImageChops.subtract(a.filter(ImageFilter.MaxFilter(9)), a).filter(ImageFilter.GaussianBlur(4))
        img.paste((255, 214, 140), (0, 0), rim.point(lambda v: min(255, v * 2)))
        img.paste((10, 8, 8), (0, 0), a)
    mark = h.get("mark", "？")
    if mark:
        size = int(min(y1 - y0, (x1 - x0) * 1.3) * 0.72)
        f = thumbfx.font(gothic, max(60, size))
        thumbfx.text(img, ((x0 + x1) / 2, (y0 + y1) / 2), str(mark), f, YEL, ORANGE, (40, 14, 0), max(8, size // 14),
                     WHITE if size >= 150 else None, max(3, size // 28) if size >= 150 else 0, angle=-6, anchor="mm")


# --- 事件の瞬間の赤い光（flash） ----------------------------------------------------------

def flash(img: Image.Image, t: dict) -> None:
    f = t.get("flash")
    if f in (None, False):
        return
    f = {} if f is True else dict(f)
    cx, cy = f.get("at") or (W * 0.62, H * 0.42)
    color = tuple(f.get("color") or EMBER)
    r = int(f.get("size", 520))
    glow = Image.radial_gradient("L").resize((r * 2, r * 2))           # 真ん中 0 → 外 255
    m = Image.new("L", (W, H), 0)
    m.paste(ImageOps.invert(glow), (int(cx - r), int(cy - r)))
    m = m.point(lambda v: int(min(255, v * 1.1) * 0.6))
    layer = Image.new("RGB", (W, H), BLACK)
    layer.paste(color, (0, 0), m)
    img.paste(ImageChops.screen(img, layer))
    edge = Image.radial_gradient("L").resize((W, W)).crop((0, (W - H) // 2, W, (W + H) // 2))    # 四隅を赤黒く
    img.paste((40, 4, 0), (0, 0), edge.point(lambda v: int(max(0, v - 150) * 1.2)))
    rnd = random.Random(int(f.get("seed", 13)))                        # 火の粉
    sparks = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(sparks)
    for _ in range(int(f.get("sparks", 70))):
        a = rnd.uniform(0, math.tau)
        dist = rnd.uniform(0.15, 1.0) * r
        x, y = cx + math.cos(a) * dist, cy + math.sin(a) * dist * 0.8 - rnd.uniform(0, 80)
        s = rnd.uniform(2, 6)
        d.ellipse([x - s, y - s, x + s, y + s], fill=rnd.randint(150, 255))
    img.paste((255, 200, 90), (0, 0), sparks.filter(ImageFilter.GaussianBlur(1.2)))
    img.paste((255, 120, 30), (0, 0), sparks.filter(ImageFilter.GaussianBlur(6)).point(lambda v: v // 2))


def under_text(img: Image.Image, t: dict, gothic, cache: Path | None = None) -> None:
    """文字の前（絵の上）に描くもの：赤い光 → 隠し。書いていなければ何もしない。"""
    flash(img, t)
    hide(img, t, gothic, cache)


# --- 落差の二語（contrast） -------------------------------------------------------------

def contrast_spec(c) -> dict:
    if isinstance(c, (list, tuple)):
        if len(c) != 2 or not all(str(x).strip() for x in c):
            raise ValueError("サムネイルの contrast は [前の語, 本当の語] の2つ")
        return {"from": str(c[0]), "to": str(c[1]), "style": "auto"}
    if isinstance(c, dict) and c.get("from") and c.get("to"):
        style = c.get("style", "auto")
        if style not in CONTRAST_STYLES:
            raise ValueError(f"サムネイルの contrast.style は {'／'.join(CONTRAST_STYLES)}")
        return {"from": str(c["from"]), "to": str(c["to"]), "style": style}
    raise ValueError("サムネイルの contrast は [前の語, 本当の語] か {from, to, style}")


def _white(img, xy, s, f, anchor="lm"):
    size = getattr(f, "size", 60)
    thumbfx.text(img, xy, s, f, WHITE, None, BLACK, max(6, size // 12), anchor=anchor)


def _yellow(img, xy, s, f, anchor="lm"):
    size = getattr(f, "size", 60)
    outer = max(3, size // 28) if size >= 150 else 0
    thumbfx.text(img, xy, s, f, YEL, ORANGE, (40, 14, 0), max(8, size // 11), WHITE if outer else None, outer,
                 anchor=anchor)


ARROW_K = 0.78           # 矢印の長さ（右の語の字の大きさに対して）
FROM_K = {"arrow": 0.58, "strike": 0.62}     # 左（上）の語の大きさ（右の語に対して）


def contrast_plan(spec: dict, zone, gothic):
    """zone（x0, y0, x1, y1）に収まる形と大きさ。('arrow' か 'strike', 右の語の大きさ)。"""
    x0, y0, x1, y1 = zone
    zw, zh = x1 - x0, y1 - y0
    a, b = spec["from"], spec["to"]
    styles = ("arrow", "strike") if spec["style"] == "auto" else (spec["style"],)
    best = None
    for style in styles:
        k = FROM_K[style]
        top = min(200, int(zh * 0.92) if style == "arrow" else int(zh / (k * 1.15 + 1.0)))
        for s in range(top, 47, -4):
            fa, fb = thumbfx.font(gothic, int(s * k)), thumbfx.font(gothic, s)
            if style == "arrow":
                width = fa.getlength(a) + s * ARROW_K + fb.getlength(b) + 20
            else:
                width = max(fa.getlength(a) + 20, fb.getlength(b) + 20)
            if width <= zw:
                if best is None or s > best[1] * 1.15:              # strike は右の語がはっきり大きくなるときだけ
                    best = (style, s)
                break
    return best or (styles[-1], 48)


def draw_contrast(img: Image.Image, t: dict, zone, gothic, center: bool = False) -> None:
    spec = contrast_spec(t["contrast"])
    style, s = contrast_plan(spec, zone, gothic)
    x0, y0, x1, y1 = zone
    a, b = spec["from"], spec["to"]
    k = FROM_K[style]
    fa, fb = thumbfx.font(gothic, int(s * k)), thumbfx.font(gothic, s)
    if style == "arrow":
        total = fa.getlength(a) + s * ARROW_K + fb.getlength(b)
        x = x0 + ((x1 - x0) - total) / 2 if center else x0
        yc = (y0 + y1) / 2
        _white(img, (x, yc + s * 0.06), a, fa)
        ax0 = x + fa.getlength(a) + s * 0.12
        ax1 = x + fa.getlength(a) + s * (ARROW_K - 0.1)
        thumbfx.arrow(img, (ax0, yc + s * 0.04), (ax1, yc + s * 0.04), bend=0.0, width=max(10, s // 8))
        _yellow(img, (x + fa.getlength(a) + s * ARROW_K, yc), b, fb)
        return
    sa = int(s * k)
    gap = int(s * k * 0.15)
    block = sa * 1.0 + gap + s
    ytop = y0 + ((y1 - y0) - block) / 2
    xa = x0 + ((x1 - x0) - fa.getlength(a)) / 2 if center else x0 + 6
    xb = x0 + ((x1 - x0) - fb.getlength(b)) / 2 if center else x0
    ya = ytop + sa / 2
    _white(img, (xa, ya), a, fa)
    d = ImageDraw.Draw(img)                                  # 取り消しの赤い線（少し右上がり）
    lw = max(5, sa // 11)
    p0, p1 = (xa - 8, ya + sa * 0.1), (xa + fa.getlength(a) + 8, ya - sa * 0.04)
    d.line([p0, p1], fill=WHITE, width=lw + 6)
    d.line([p0, p1], fill=RED, width=lw)
    _yellow(img, (xb, ytop + sa + gap + s / 2), b, fb)
