"""サムネイルの作り込み（10-07 ユーザー「もう少し作り込んだサムネにしたい」）。

構図（face・scene・versus・number・map）の上に、文字・背景・小物・質感を重ねる。classic と3案の b・c には使わない
（画素まで今と同じ）。Pillow だけで描く。人物の切り抜きだけ rembg（任意。無ければ切り抜かない）。

    thumbnail:
      layout: face
      light: right          # 斜めの光（主役の側を明るく、反対側を落とす）。left／right／top／none
      rays: true            # 放射状の光の筋（控えめ）。[x, y] で中心を指定
      tint: right           # 片側を朱色に染める。left／right／none、{side: right, color: [r, g, b]}
      blur: true            # 周辺のぼかし（奥行き）
      torn: true            # 破れの縁・ひび割れ（scene の帯の上端、versus の境目）
      texture: true         # 紙の質感をうっすら全体に
      badge: 1582年          # 古文書の切れ端風の札。{text: 記録, at: [x, y], angle: -6}
      arrow: {from: [x, y], to: [x, y]}            # 赤い矢印（サムネイルの座標。bend で曲げる）。並べて複数も可
      circle: [x0, y0, x1, y1]                     # 手書き風の赤い丸囲み。並べて複数も可
      cutout: true          # 主役の絵から人物を切り抜き（rembg）、縁取り＋影で前に浮かせる。face・versus は既定で入
                            # false で切る。paintings/x.png（透明 PNG）や {image, x, y, height} なら、その絵を前に重ねる
      fx: false             # 作り込みを全部外す（10-07 の素の構図に戻す）

書かなければ構図ごとの既定（DEFAULTS）。主色も構図ごとに決める（PALETTES）。
切り抜きは work/<台本>/cutout_<絵のハッシュ>.png に控える（2回目からは読むだけ）。rembg（任意の依存、
requirements-cutout.txt）が無い環境では切り抜かずに描く（CI はこちら）。
"""
from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageOps

W, H = 1280, 720
YEL = (255, 214, 40)
RED = (205, 30, 40)
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
PAPER = (238, 224, 190)
INK = (58, 40, 24)
VERMILION = (226, 70, 34)

# 構図ごとの主色（main のグラデーションの上・下、縁取りの内側、光の色）
PALETTES = {
    "face": {"main": (YEL, (255, 150, 30)), "inner": (40, 14, 0), "light": (255, 170, 90)},       # 暖色
    "scene": {"main": (YEL, (255, 150, 20)), "inner": (10, 10, 18), "light": (255, 236, 200)},     # 墨と金
    "versus": {"main": (YEL, (255, 150, 20)), "inner": (30, 0, 0), "light": (255, 210, 150)},      # 朱と金
    "number": {"main": (YEL, (255, 150, 20)), "inner": (40, 0, 0), "light": (255, 120, 60)},       # 深い赤
    "map": {"main": ((255, 226, 120), (214, 150, 40)), "inner": (8, 16, 36), "light": (255, 220, 140)},  # 紺と金
}

DEFAULTS = {
    "face": {"light": "auto", "blur": True, "texture": True, "rays": False, "tint": "none", "torn": False},
    "scene": {"light": "top", "blur": True, "texture": True, "rays": False, "tint": "none", "torn": True},
    "versus": {"light": "none", "blur": False, "texture": True, "rays": True, "tint": "right", "torn": True},
    "number": {"light": "none", "blur": True, "texture": True, "rays": True, "tint": "none", "torn": False},
    "map": {"light": "none", "blur": False, "texture": True, "rays": False, "tint": "none", "torn": False},
}
TILT = {"face": -3.0, "versus": -5.0}      # 主役の語の傾き（度）。scene・number・map は傾けない
AUTO_CUTOUT = ("face", "versus")           # 人物を自動で切り抜いて前に浮かせる構図（rembg が無ければ切り抜かない）
OUTLINE = {"face": WHITE, "versus": (236, 196, 96)}         # 切り抜いた人物の縁（face は白、versus は金）


def options(t: dict, layout: str) -> dict:
    """台本の thumbnail: から、作り込みの設定を作る（書いていないものは構図の既定）。fx: false なら全部切る。"""
    if layout not in DEFAULTS or t.get("fx") is False:
        return {"on": False}
    o = dict(DEFAULTS[layout])
    for k in ("light", "blur", "texture", "rays", "tint", "torn"):
        if k in t:
            o[k] = t[k]
    for k in ("badge", "arrow", "circle"):
        o[k] = t.get(k)
    o["cutout"] = t.get("cutout", layout in AUTO_CUTOUT)
    o["on"] = True
    o["layout"] = layout
    o["palette"] = PALETTES[layout]
    o["tilt"] = float(t.get("tilt", TILT.get(layout, 0.0)))
    return o


def problems(t: dict) -> list[str]:
    """作り込みの書き方の誤り（check が × にする）。"""
    out = []
    if "light" in t and t["light"] not in ("left", "right", "top", "none", False, None):
        out.append("サムネイルの light は left／right／top／none")
    tint = t.get("tint")
    if isinstance(tint, dict):
        tint = tint.get("side")
    if tint not in (None, False, "none", "left", "right"):
        out.append("サムネイルの tint は left／right／none（または {side, color}）")
    for a in _as_list(t.get("arrow")):
        if not (isinstance(a, dict) and _pt(a.get("from")) and _pt(a.get("to"))):
            out.append("サムネイルの arrow は {from: [x, y], to: [x, y]}")
    for c in _as_list(t.get("circle"), boxes=True):
        if not (isinstance(c, (list, tuple)) and len(c) == 4):
            out.append("サムネイルの circle は [x0, y0, x1, y1]")
    b = t.get("badge")
    if isinstance(b, dict) and not b.get("text"):
        out.append("サムネイルの badge に text がありません")
    return out


def _pt(p) -> bool:
    return isinstance(p, (list, tuple)) and len(p) == 2


def _as_list(v, boxes=False):
    if not v:
        return []
    if isinstance(v, dict):
        return [v]
    if boxes and isinstance(v, (list, tuple)) and v and not isinstance(v[0], (list, tuple)):
        return [v]
    return list(v)


# --- 文字 -----------------------------------------------------------------------------

def text(img: Image.Image, xy, s: str, font, fill=WHITE, fill2=None, inner=BLACK, inner_w: int = 10,
         outer=None, outer_w: int = 0, shadow: bool = True, angle: float = 0.0, anchor: str = "la") -> None:
    """二重の縁取り（内側 inner・外側 outer）、下右にずらした影、上下のグラデーション（fill→fill2）、傾き。"""
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
    ax, ay = pad - x0, pad - y0                                  # 台紙の中の基準点

    def mask(width):
        m = Image.new("L", (tw, th), 0)
        ImageDraw.Draw(m).text((ax, ay), s, font=font, fill=255, anchor=anchor, stroke_width=width, stroke_fill=255)
        return m

    m_out, m_in, m_fill = mask(stroke), mask(inner_w), mask(0)
    tile = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    if shadow:                                                   # うっすら立体：下右にずらした暗い層
        sh = Image.new("L", (tw, th), 0)
        sh.paste(m_out, (off, off))
        sh = sh.filter(ImageFilter.GaussianBlur(max(1, off // 2))).point(lambda v: v * 170 // 255)
        tile.paste((0, 0, 0, 255), (0, 0), sh)
    if outer is not None and outer_w:
        tile.paste(outer + (255,), (0, 0), m_out)
    tile.paste(inner + (255,), (0, 0), m_in if outer is not None and outer_w else m_out)
    if fill2 and fill2 != fill:
        gx0, gy0, gx1, gy1 = m_fill.getbbox() or (0, 0, tw, th)
        g = Image.linear_gradient("L").resize((1, max(1, gy1 - gy0)))
        grad = Image.new("RGB", (tw, th), fill)
        col = Image.new("RGB", (tw, gy1 - gy0), fill2)
        grad.paste(col, (0, gy0), g.resize((tw, gy1 - gy0)))
        grad.paste(fill2, (0, gy1, tw, th))
        tile.paste(grad, (0, 0), m_fill)
    else:
        tile.paste(fill + (255,), (0, 0), m_fill)
    if angle:
        tile = tile.rotate(angle, resample=Image.BICUBIC, center=(ax, ay))
    x, y = xy
    img.paste(tile, (int(round(x - ax)), int(round(y - ay))), tile)


# --- 背景 -----------------------------------------------------------------------------

def _direction_mask(angle: float) -> Image.Image:
    """angle の向きに 0→255 と明るくなる斜めの勾配（W x H）。"""
    g = Image.linear_gradient("L").rotate(angle, resample=Image.BICUBIC, expand=True)
    s = g.width
    inner = int(s / math.sqrt(2)) - 4                            # 回したあとの、欠けのない真ん中
    g = g.crop(((s - inner) // 2, (s - inner) // 2, (s + inner) // 2, (s + inner) // 2))
    return g.resize((W, H), Image.BILINEAR)


def light(img: Image.Image, side: str, color=(255, 200, 140), dark: float = 0.5, beam: float = 0.16) -> None:
    """主役の側を明るく、反対側を暗く落とす斜めの光。光の側には細い光の帯を1本。"""
    angle = {"right": 60, "left": -60, "top": 180}.get(side)
    if angle is None:
        return
    m = _direction_mask(angle)                                    # 光の側が 255
    lit = ImageEnhance.Brightness(img).enhance(1.08)
    shade = ImageEnhance.Brightness(img).enhance(dark)
    img.paste(Image.composite(lit, shade, m.point(lambda v: min(255, int(v * 1.5)))))
    band = Image.new("L", (W * 2, H * 2), 0)                      # 斜めの光の帯（光の側の上から）
    d = ImageDraw.Draw(band)
    if side == "top":
        d.rectangle([0, 0, W * 2, 260], fill=255)
        band = band.filter(ImageFilter.GaussianBlur(90)).crop((W // 2, 0, W // 2 + W, H))
    else:
        cx = W * 2 * (0.78 if side == "right" else 0.22)
        d.polygon([(cx - 90, 0), (cx + 60, 0), (cx - 380 if side == "right" else cx + 540, H * 2),
                   (cx - 620 if side == "right" else cx + 300, H * 2)], fill=255)
        band = band.filter(ImageFilter.GaussianBlur(70)).resize((W, H))
    img.paste(Image.composite(Image.new("RGB", (W, H), color), img, band.point(lambda v: int(v * beam))))


def rays(img: Image.Image, center, color=(255, 230, 170), alpha: float = 0.14, n: int = 30,
         hole: int = 140, seed: int = 7) -> None:
    """放射状の光の筋（集中線を控えめに）。真ん中（文字の所）と画面の端は薄くする。"""
    cx, cy = center
    rnd = random.Random(seed)
    m = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(m)
    r = math.hypot(W, H)
    step = 2 * math.pi / n
    for i in range(n):
        a = i * step + rnd.uniform(-0.15, 0.15) * step
        w = step * rnd.uniform(0.18, 0.42)
        d.polygon([(cx, cy), (cx + r * math.cos(a - w / 2), cy + r * math.sin(a - w / 2)),
                   (cx + r * math.cos(a + w / 2), cy + r * math.sin(a + w / 2))], fill=255)
    m = m.filter(ImageFilter.GaussianBlur(5))
    fade = Image.radial_gradient("L").resize((int(hole * 2 * 5), int(hole * 2 * 5)))   # 中心 0 → 外 255
    ring = Image.new("L", (W, H), 255)
    ring.paste(fade, (int(cx - fade.width / 2), int(cy - fade.height / 2)))
    ring = ring.point(lambda v: min(255, v * 3))                   # 中心のまわり（hole）だけ消す
    m = ImageChops.multiply(m, ring).point(lambda v: int(v * alpha))
    img.paste(Image.composite(Image.new("RGB", (W, H), color), img, m))


def tint(img: Image.Image, side: str, color=VERMILION, strength: float = 0.45, edge: int = 160, split=None) -> None:
    """片側を朱色に染める（明るさは残す）。split は境目の x（versus の斜めの線なら [上の x, 下の x]）。"""
    if side not in ("left", "right"):
        return
    gray = ImageOps.grayscale(img)
    colored = ImageOps.colorize(gray, (20, 0, 0), color, mid=tuple(int(c * 0.75) for c in color))
    m = Image.new("L", (W, H), 0)
    top, bottom = split if isinstance(split, (list, tuple)) else (split or W // 2, split or W // 2)
    if side == "right":
        ImageDraw.Draw(m).polygon([(top, 0), (W, 0), (W, H), (bottom, H)], fill=int(255 * strength))
    else:
        ImageDraw.Draw(m).polygon([(0, 0), (top, 0), (bottom, H), (0, H)], fill=int(255 * strength))
    m = m.filter(ImageFilter.GaussianBlur(edge // 8))
    img.paste(Image.composite(colored, img, m))


def depth(img: Image.Image, box=None, radius: int = 10, dark: float = 0.78) -> None:
    """周辺のぼかしと四隅の暗さで奥行き。box（楕円）の中はそのまま。"""
    box = box or (-160, -120, W + 160, H + 120)
    m = Image.new("L", (W, H), 0)
    ImageDraw.Draw(m).ellipse(box, fill=255)
    m = m.filter(ImageFilter.GaussianBlur(120))
    soft = ImageEnhance.Brightness(img.filter(ImageFilter.GaussianBlur(radius))).enhance(dark)
    img.paste(Image.composite(img, soft, m))


def paper(img: Image.Image, strength: int = 2) -> None:
    """紙の質感（chiso.texture の紙の目）を全体にうっすら。strength 回重ねる。"""
    from . import texture
    up, down = texture.grain(img.size)
    out = img
    for _ in range(strength):
        out = ImageChops.subtract(ImageChops.add(out, up), down)
    img.paste(out)


def strata_grain(img: Image.Image, top: int = H - 15, height: int = 70, seed: int = 11) -> None:
    """下端の地層の帯の上に、薄い地層の筋（波打つ横線）を数本。帯の目印そのものは変えない。"""
    rnd = random.Random(seed)
    m = Image.new("L", (W, height), 0)
    d = ImageDraw.Draw(m)
    for i in range(5):
        y = height - 6 - i * (height // 6)
        amp, ph = rnd.uniform(2, 5), rnd.uniform(0, 6)
        pts = [(x, y + amp * math.sin(x / rnd.uniform(70, 140) + ph)) for x in range(0, W + 20, 20)]
        d.line(pts, fill=int(110 - i * 18), width=rnd.choice((2, 3)))
    m = m.filter(ImageFilter.GaussianBlur(1.2))
    fade = Image.linear_gradient("L").resize((W, height))         # 下ほど濃い
    m = ImageChops.multiply(m, fade)
    region = img.crop((0, top - height, W, top))
    region.paste((70, 52, 34), (0, 0), m)
    img.paste(region, (0, top - height))


# --- 小物 -----------------------------------------------------------------------------

def _shadow_paste(img, layer, off=6, blur=5, k=0.6):
    a = layer.getchannel("A")
    sh = Image.new("L", img.size, 0)
    sh.paste(a, (off, off))
    sh = sh.filter(ImageFilter.GaussianBlur(blur)).point(lambda v: int(v * k))
    img.paste((0, 0, 0), (0, 0), sh)
    img.paste(layer, (0, 0), layer)


def arrow(img: Image.Image, a, b, bend: float = 0.18, width: int = 22, color=RED) -> None:
    """赤い矢印（白い縁・影付き）。bend で少し曲げる（正で左回り）。"""
    (x0, y0), (x1, y1) = a, b
    mx, my = (x0 + x1) / 2, (y0 + y1) / 2
    nx, ny = -(y1 - y0), x1 - x0
    cx, cy = mx + nx * bend, my + ny * bend
    pts = [((1 - u) ** 2 * x0 + 2 * (1 - u) * u * cx + u * u * x1,
            (1 - u) ** 2 * y0 + 2 * (1 - u) * u * cy + u * u * y1) for u in (i / 40 for i in range(41))]
    hx, hy = pts[-1]
    px, py = pts[-4]
    ang = math.atan2(hy - py, hx - px)
    head = width * 2.4
    base = (hx - math.cos(ang) * head, hy - math.sin(ang) * head)
    body = [p for p in pts if math.dist(p, (hx, hy)) > head * 0.8]
    left = (base[0] + math.cos(ang + math.pi / 2) * head * 0.62, base[1] + math.sin(ang + math.pi / 2) * head * 0.62)
    right = (base[0] - math.cos(ang + math.pi / 2) * head * 0.62, base[1] - math.sin(ang + math.pi / 2) * head * 0.62)
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for c, w in ((WHITE, width + 12), (color, width)):
        d.line(body, fill=c + (255,), width=w, joint="curve")
        r = w / 2
        d.ellipse([body[0][0] - r, body[0][1] - r, body[0][0] + r, body[0][1] + r], fill=c + (255,))
        grow = (w - width) * 0.75
        tip = (hx + math.cos(ang) * grow, hy + math.sin(ang) * grow)
        lft = (left[0] + math.cos(ang + math.pi * 0.8) * grow, left[1] + math.sin(ang + math.pi * 0.8) * grow)
        rgt = (right[0] + math.cos(ang - math.pi * 0.8) * grow, right[1] + math.sin(ang - math.pi * 0.8) * grow)
        d.polygon([tip, lft, rgt], fill=c + (255,))
    _shadow_paste(img, layer)


def circle(img: Image.Image, box, color=RED, width: int = 11, seed: int = 3) -> None:
    """手書き風の丸囲み（赤ペンの線を太く。白い縁で下が何でも見える）。"""
    from . import pen
    rnd = random.Random(seed)
    pts = pen._wobble(pen._ellipse_pts(box, rnd), rnd, amp=3.0)
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.line(pts, fill=WHITE + (255,), width=width + 8, joint="curve")
    d.line(pts, fill=color + (255,), width=width, joint="curve")
    _shadow_paste(img, layer, off=4, blur=3, k=0.5)


def _jagged(rnd, x0, y0, x1, y1, step=14, amp=5):
    """四辺がぎざぎざの多角形（破った紙）。"""
    pts = []
    for (ax, ay, bx, by) in ((x0, y0, x1, y0), (x1, y0, x1, y1), (x1, y1, x0, y1), (x0, y1, x0, y0)):
        n = max(2, int(math.dist((ax, ay), (bx, by)) / step))
        for i in range(n):
            u = i / n
            jx = rnd.uniform(-amp, amp) if ax == bx else 0
            jy = rnd.uniform(-amp, amp) if ay == by else 0
            pts.append((ax + (bx - ax) * u + jx, ay + (by - ay) * u + jy))
    return pts


def badge(img: Image.Image, label: str, at, font, angle: float = -5.0, seed: int = 5) -> tuple[int, int, int, int]:
    """古文書の切れ端風の札（紙の色・紙の目・破れた縁・墨の字・朱の細い線）。左上の角を at に。範囲を返す。"""
    from . import texture
    rnd = random.Random(seed)
    tw = int(font.getlength(label))
    size = getattr(font, "size", 40)
    pw, ph = tw + 70, int(size * 1.75)
    pad = 24
    tile = Image.new("RGBA", (pw + pad * 2, ph + pad * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(tile)
    poly = _jagged(rnd, pad, pad, pad + pw, pad + ph, step=12, amp=4)
    d.polygon(poly, fill=PAPER + (255,))
    edge = Image.new("L", tile.size, 0)                          # 縁ほど焼けた色
    ImageDraw.Draw(edge).polygon(poly, fill=255)
    burnt = ImageChops.subtract(edge, edge.filter(ImageFilter.GaussianBlur(10))).point(lambda v: min(255, v * 3))
    tile.paste((150, 112, 66, 255), (0, 0), ImageChops.multiply(burnt, edge))
    texture.apply(tile, (pad, pad, pad + pw, pad + ph))
    texture.apply(tile, (pad, pad, pad + pw, pad + ph))
    d = ImageDraw.Draw(tile)
    d.line([(pad + 16, pad + ph - 14), (pad + pw - 16, pad + ph - 14)], fill=RED + (230,), width=4)
    d.text((pad + pw / 2, pad + ph / 2 - 3), label, font=font, fill=INK + (255,), anchor="mm")
    tile = tile.rotate(angle, resample=Image.BICUBIC, expand=True)
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    x, y = int(at[0]), int(at[1])
    layer.paste(tile, (x, y), tile)
    _shadow_paste(img, layer, off=6, blur=6, k=0.55)
    return x, y, x + tile.width, y + tile.height


def torn_edge(img: Image.Image, y: int, below=(6, 4, 2), alpha: int = 225, seed: int = 9, up: bool = False) -> None:
    """帯の上端（up なら下端）を破った紙の縁に。縁のすぐ内側に明るい紙の筋。"""
    rnd = random.Random(seed)
    pts, x = [], -10
    while x < W + 20:
        pts.append((x, y + rnd.uniform(-9, 9)))
        x += rnd.randint(10, 26)
    rim = [(px, py + (5 if not up else -5)) for px, py in pts]
    m = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(m)
    end = H if not up else 0
    d.polygon(pts + [(W + 20, end), (-10, end)], fill=alpha)
    paper_m = Image.new("L", (W, H), 0)
    ImageDraw.Draw(paper_m).line(rim, fill=200, width=5)
    img.paste((222, 204, 168), (0, 0), paper_m.filter(ImageFilter.GaussianBlur(0.8)))
    region = Image.new("L", (W, H), 0)                            # 縁の外側（絵の側）に紙の筋、内側を帯の色に
    ImageDraw.Draw(region).polygon(rim + [(W + 20, end), (-10, end)], fill=alpha)
    img.paste(below, (0, 0), region)


def crack(img: Image.Image, top_x: float, bottom_x: float, color=(255, 214, 40), width: int = 10, seed: int = 4) -> None:
    """versus の境目：上から下へ走るひび（金の線に、ぎざぎざと細い枝。外に光）。"""
    rnd = random.Random(seed)
    pts = []
    n = 26
    for i in range(n + 1):
        u = i / n
        x = top_x + (bottom_x - top_x) * u + (rnd.uniform(-16, 16) if 0 < i < n else 0)
        pts.append((x, H * u))
    glow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(glow).line(pts, fill=255, width=width + 26, joint="curve")
    glow = glow.filter(ImageFilter.GaussianBlur(14)).point(lambda v: int(v * 0.55))
    img.paste((255, 200, 120), (0, 0), glow)
    d = ImageDraw.Draw(img)
    d.line(pts, fill=(30, 10, 0), width=width + 6, joint="curve")
    d.line(pts, fill=color, width=width, joint="curve")
    for i in range(3, n - 2, 5):                                  # 枝分かれの細いひび
        x, y = pts[i]
        s = rnd.choice((-1, 1))
        b = [(x, y)]
        for _ in range(3):
            x += s * rnd.uniform(14, 28)
            y += rnd.uniform(-12, 18)
            b.append((x, y))
        d.line(b, fill=(30, 10, 0), width=6, joint="curve")
        d.line(b, fill=color, width=3, joint="curve")


# --- 人物の切り抜き（rembg。入っていなければ切り抜かずに今の形） -----------------------------------

_SESSION = None
_MEMO: dict = {}
REMBG_MODEL = "isnet-general-use"


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
    """いちばん大きい塊だけ残す（椅子の端などの小さい残りを落とす）。塊の中の穴は埋める
    （日本の肖像画は衣の所が半透明に抜けやすい）。縮めた画で塗りつぶして数える。"""
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
    outside = Image.new("L", (keep.width + 2, keep.height + 2), 0)     # 外から塗って届かない所＝穴
    outside.paste(keep, (1, 1))
    ImageDraw.floodfill(outside, (0, 0), 128)
    filled = outside.crop((1, 1, keep.width + 1, keep.height + 1)).point(lambda v: 0 if v == 128 else 255)
    soft = keep.resize(alpha.size, Image.BILINEAR).filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(2))
    inner = filled.resize(alpha.size, Image.BILINEAR).filter(ImageFilter.MinFilter(7)).filter(ImageFilter.GaussianBlur(3))
    return ImageChops.lighter(ImageChops.multiply(alpha, soft), inner)


MIN_AREA = 0.12          # 人物の形が絵のこれより小さければ使わない
MIN_BODY = 0.35          # 下半分でいちばん幅のある所（肩・膝）が絵の幅のこれより狭ければ（衣が抜けて首だけ等）使わない


def usable(mask: Image.Image) -> bool:
    """切り抜きが使えるか（衣が抜けて首だけ・顔だけになったものは使わない＝今の形に戻す）。"""
    small = mask.resize((200, max(2, int(200 * mask.height / mask.width)))).point(lambda v: 255 if v > 128 else 0)
    area = small.histogram()[255] / (small.width * small.height)
    body = max(small.crop((0, y, small.width, y + 1)).histogram()[255] for y in range(small.height // 2, small.height))
    return area >= MIN_AREA and body / small.width >= MIN_BODY


def person_mask(tile: Image.Image, key: str, cache: Path | None = None):
    """tile（そのまま画面に貼る絵）から人物の形を出す。cache/cutout_<key>.png に控え、次からはそれを読む。"""
    if key in _MEMO:
        return _MEMO[key]
    path = cache / f"cutout_{key}.png" if cache else None
    if path and path.exists():
        with Image.open(path) as im:
            m = im.convert("RGBA").getchannel("A")
        if m.size == tile.size:
            _MEMO[key] = m if usable(m) else None
            return _MEMO[key]
    seg = _segment(tile)
    if seg is None:
        return None
    m = largest_blob(seg.resize(tile.size))
    if path:
        path.parent.mkdir(parents=True, exist_ok=True)
        out = tile.convert("RGBA")
        out.putalpha(m)
        out.save(path)
    _MEMO[key] = m if usable(m) else None
    return _MEMO[key]


def pop_out(img: Image.Image, tile: Image.Image, pos, mask: Image.Image, outline=WHITE, width: int = 9,
            clip: Image.Image | None = None, dim: float = 0.72) -> None:
    """切り抜いた人物を、太い縁取り＋影で背景から前に浮かせる。人物のまわりの背景は少しぼかして落とす。"""
    x, y = int(pos[0]), int(pos[1])
    a = Image.new("L", img.size, 0)
    a.paste(mask, (x, y))
    if clip is not None:
        a = ImageChops.multiply(a, clip)
    box = (x, y, x + tile.width, y + tile.height)
    if dim < 1:                                                  # 人物の後ろ（同じ絵の背景）を落として奥へ
        area = img.crop(box)
        soft = ImageEnhance.Brightness(area.filter(ImageFilter.GaussianBlur(5))).enhance(dim)
        back = Image.new("L", img.size, 0)
        back.paste(255, box)
        if clip is not None:
            back = ImageChops.multiply(back, clip)
        img.paste(soft, (x, y), back.crop(box))
    grown = a.filter(ImageFilter.GaussianBlur(width * 0.7)).point(lambda v: 255 if v > 24 else int(v * 10))
    sh = Image.new("L", img.size, 0)
    sh.paste(grown, (12, 12))
    img.paste((0, 0, 0), (0, 0), sh.filter(ImageFilter.GaussianBlur(12)).point(lambda v: int(v * 0.65)))
    img.paste(outline, (0, 0), grown)
    person = Image.new("RGB", img.size, 0)
    person.paste(tile.convert("RGB"), (x, y))
    img.paste(person, (0, 0), a)


def cutout(img: Image.Image, spec, assets: Path, side: str = "right") -> None:
    """背景を消した人物（透明 PNG）を前に重ねる。spec はパスか {image, x, y, height}。影と縁の光を付ける。"""
    if isinstance(spec, str):
        spec = {"image": spec}
    with Image.open(assets / spec["image"]) as im:
        person = im.convert("RGBA")
    box = person.getbbox()
    if box:
        person = person.crop(box)
    h = int(spec.get("height", H * 0.98))
    person = person.resize((max(1, int(person.width * h / person.height)), h), Image.LANCZOS)
    x = spec.get("x")
    if x is None:
        x = W - person.width - 20 if side == "right" else 20
    y = spec.get("y", H - person.height)
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    layer.paste(person, (int(x), int(y)), person)
    rim = layer.getchannel("A").filter(ImageFilter.MaxFilter(7))   # 縁の光（人物のまわりに細く）
    rim = ImageChops.subtract(rim, layer.getchannel("A")).filter(ImageFilter.GaussianBlur(3)).point(lambda v: int(v * 0.7))
    img.paste((255, 236, 200), (0, 0), rim)
    _shadow_paste(img, layer, off=10, blur=12, k=0.6)


# --- 仕上げ（すべての構図の最後） -------------------------------------------------------------

def finish(img: Image.Image, o: dict, gothic, assets: Path, font_fn) -> None:
    """小物（矢印・丸囲み・札）と質感。文字のあとに描く（札と矢印は文字の上でよい）。"""
    for a in _as_list(o.get("arrow")):
        arrow(img, a["from"], a["to"], float(a.get("bend", 0.18)), int(a.get("width", 22)))
    for c in _as_list(o.get("circle"), boxes=True):
        circle(img, c)
    b = o.get("badge")
    if b:
        b = b if isinstance(b, dict) else {"text": str(b)}
        f = font_fn(b.get("serif") or gothic, int(b.get("size", 46)))
        at = b.get("at") or default_badge_at(o["layout"], f.getlength(str(b["text"])))
        badge(img, str(b["text"]), at, f, float(b.get("angle", -5)))
    if o.get("texture"):
        paper(img, 1)
        strata_grain(img)


def default_badge_at(layout: str, text_w: float):
    """札の既定の置き場所（主役と重ならない隅）。"""
    return {"face": (W - text_w - 150, 26), "scene": (W - text_w - 140, 30), "versus": (40, 455),
            "number": (W - text_w - 150, 40), "map": (W - text_w - 150, 40)}.get(layout, (30, 30))
