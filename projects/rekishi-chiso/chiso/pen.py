"""絵の一部を大きく見せる（detail）と、赤ペンの書き込み（mark）。2026-10-07。

同じ背景の絵が2分前後動かない区間があった（信長の回）。絵は1本20枚前後しか集まらないので、
同じ1枚から「新しいもの」を何度も作れるようにする。

    detail: {box: [820, 300, 1400, 760], label: 鉄砲隊}     # 元の絵の画素（0〜1 の割合でも可）
    mark: [{type: circle, at: [0.3, 0.2, 0.6, 0.5]}, {type: note, at: [0.62, 0.15], text: 三段撃ち？}]
    mark: {type: strike, at: 2}                              # 図の2番目の項目に取り消し線

detail はその行のあいだ、真ん中の額（render.Painter.DETAIL_BOX）にその絵の一部を大きく出し、下に小さな札。
止まった絵で、動かさない（背景を動かさない決まり）。肖像・図・年表はその行だけ隠れる（図より先に出る）。

mark は大きく見せた絵・図・真ん中の額（背景の絵）・肖像の上に、赤い手書き風の印を1つずつ足していく。
同じもの（同じ detail・同じ図・同じ背景）の上にいるあいだは前の行の印が残り、替わると消える（mark: null でも消える）。
at は図なら「何番目の項目」（1から）、絵なら [x, y]（点）か [x0, y0, x1, y1]（範囲）。4つとも1以下なら割合、
そうでなければ元の絵の画素。図に座標で書くときは図の板の中の割合。

別チャンネル「世の中の断面図」の annotate.py を下敷きにした。あちらの apply は RGBA を RGB に落とすので、
ここでは別の層に描いて alpha_composite で重ね、透明を保つ（本編の前景は透明な層）。
"""
from __future__ import annotations

import json
import math
import random

from PIL import Image, ImageDraw, ImageFilter

PEN = (208, 30, 30)          # 赤ペン
PEN_W = 7
MARK_FRAMES = 14             # 書き込み1つを描き進めるコマ数（約0.5秒）
GOLD = (214, 178, 110)
HAND_FONT = "C:/Windows/Fonts/UDDigiKyokashoN-B.ttc"     # 手書きに近い教科書体（無ければゴシック）


# --- 絵の一部を大きく --------------------------------------------------------------
def crop_box(spec: dict, size: tuple[int, int]) -> tuple[int, int, int, int]:
    """detail の box を元の絵の画素に（割合なら掛ける）。絵の外にははみ出させない。"""
    w, h = size
    x0, y0, x1, y1 = spec["box"]
    if max(x0, y0, x1, y1) <= 1.0:
        x0, y0, x1, y1 = x0 * w, y0 * h, x1 * w, y1 * h
    x0, y0 = max(0, int(x0)), max(0, int(y0))
    x1, y1 = min(w, int(math.ceil(x1))), min(h, int(math.ceil(y1)))
    return x0, y0, max(x0 + 1, x1), max(y0 + 1, y1)


def detail_tile(painter, spec: dict) -> tuple[Image.Image, tuple[int, int, int, int]]:
    """切り抜いて額の中の大きさに合わせた絵と、元の絵での範囲。作るのは1回だけ（控える）。"""
    x0, y0, x1, y1 = painter.DETAIL_BOX
    key = ("detail", spec["image"], tuple(spec["box"]), x1 - x0, y1 - y0)
    if key not in painter._images:
        src = painter.image(spec["image"]).convert("RGB")
        box = crop_box(spec, src.size)
        part = src.crop(box)
        bw, bh = x1 - x0 - 40, y1 - y0 - 40
        s = min(bw / part.width, bh / part.height)
        part = part.resize((max(1, int(part.width * s)), max(1, int(part.height * s))), Image.LANCZOS)
        painter._images[key] = (part, box)
    return painter._images[key]


def draw_detail(painter, img: Image.Image, spec: dict) -> tuple[int, int, int, int]:
    """真ん中の額に、絵の一部を大きく。下に小さな札（label）。左上に全体の中のどこかを小さく。
    絵が出ている場所 (x, y, w, h) を返す（赤ペンの位置合わせに使う）。"""
    part, box = detail_tile(painter, spec)
    x0, y0, x1, y1 = painter.DETAIL_BOX
    px = (x0 + x1) // 2 - part.width // 2
    py = (y0 + y1) // 2 - part.height // 2
    painter.frame(img, px, py, part.width, part.height)
    img.paste(part, (px, py))
    dr = ImageDraw.Draw(img, "RGBA")
    _whole(painter, img, spec, box, px, py, part)
    label = spec.get("label") or ""
    if label:
        f = painter.font("serif", 30, bold=True)
        w = f.getlength(label) + 44
        cx, top = px + part.width / 2, py + part.height + 4
        dr.rounded_rectangle([cx - w / 2 + 4, top + 6, cx + w / 2 + 4, top + 50], radius=8, fill=(0, 0, 0, 120))
        dr.rounded_rectangle([cx - w / 2, top, cx + w / 2, top + 44], radius=8, fill=(120, 30, 26, 245),
                             outline=GOLD, width=2)
        dr.text((cx, top + 22), label, font=f, fill=(255, 248, 230), anchor="mm")
    return px, py, part.width, part.height


def _whole(painter, img, spec, box, px, py, part) -> None:
    """額の左上に、絵の全体を小さく出して、いま大きくしている所を金の枠で示す。"""
    src = painter.image(spec["image"])
    th = 92
    tw = max(1, int(src.width * th / src.height))
    if tw > 170:
        tw, th = 170, max(1, int(src.height * 170 / src.width))
    key = ("whole", spec["image"], tw, th)
    if key not in painter._images:
        painter._images[key] = src.convert("RGB").resize((tw, th), Image.LANCZOS)
    thumb = painter._images[key]
    s = tw / src.width
    if (box[2] - box[0]) * (box[3] - box[1]) > 0.8 * src.width * src.height:
        return                                            # ほぼ全体なら出さない
    x, y = px + 10, py + 10
    dr = ImageDraw.Draw(img, "RGBA")
    dr.rectangle([x - 3, y - 3, x + tw + 2, y + th + 2], fill=(20, 16, 10, 255), outline=GOLD, width=1)
    img.paste(thumb, (x, y))
    dr = ImageDraw.Draw(img, "RGBA")
    dr.rectangle([x + box[0] * s, y + box[1] * s, x + box[2] * s, y + box[3] * s], outline=(255, 214, 90), width=2)


# --- 赤ペン -------------------------------------------------------------------------
def spec_of(mark: str | None) -> tuple[list[dict], int]:
    if not mark:
        return [], 0
    d = json.loads(mark)
    return d["items"], int(d.get("from", 0))


def resolve(at, view, src_size=None) -> tuple[float, float, float, float]:
    """at（割合か元の絵の画素）を画面の座標の範囲に。view は絵が出ている (x, y, w, h)、
    src_size は元の絵の (幅, 高さ) か、切り抜いた範囲 (x0, y0, x1, y1)。点は幅0の範囲で返す。"""
    vx, vy, vw, vh = view
    vals = list(at) + list(at) if len(at) == 2 else list(at)
    if max(vals) <= 1.0 or src_size is None:
        fx = [vals[0], vals[2]]
        fy = [vals[1], vals[3]]
    else:
        if len(src_size) == 2:
            ox, oy, sw, sh = 0, 0, src_size[0], src_size[1]
        else:
            ox, oy, sw, sh = src_size[0], src_size[1], src_size[2] - src_size[0], src_size[3] - src_size[1]
        fx = [(vals[0] - ox) / sw, (vals[2] - ox) / sw]
        fy = [(vals[1] - oy) / sh, (vals[3] - oy) / sh]
    return vx + vw * fx[0], vy + vh * fy[0], vx + vw * fx[1], vy + vh * fy[1]


def _rnd(i: int) -> random.Random:
    return random.Random(1007 + i)


def _wobble(pts, rnd, amp=2.0):
    out = []
    for i, (x, y) in enumerate(pts):
        k = math.sin(i * 0.35) * amp + rnd.uniform(-amp * 0.5, amp * 0.5)
        out.append((x + k * 0.4, y + k * 0.6))
    return out


def _part(pts, p: float):
    """線の先頭から p（0〜1）のぶんだけ。"""
    if p >= 1:
        return pts
    n = max(2, int(len(pts) * p) + 1)
    return pts[:n] if p > 0 else []


def _line(d, pts, width=PEN_W):
    if len(pts) >= 2:
        d.line(pts, fill=PEN + (255,), width=width, joint="curve")
        r = width / 2 - 0.5                                     # 線の端を丸く（ペンの先）
        for x, y in (pts[0], pts[-1]):
            d.ellipse([x - r, y - r, x + r, y + r], fill=PEN + (255,))


def _ellipse_pts(box, rnd):
    x0, y0, x1, y1 = box
    cx, cy, rx, ry = (x0 + x1) / 2, (y0 + y1) / 2, (x1 - x0) / 2, (y1 - y0) / 2
    start = -2.2 + rnd.uniform(-0.3, 0.3)                       # 左上から時計回りに、少し行き過ぎて閉じる
    out = []
    for i in range(121):
        t = start + i / 120 * 2 * math.pi * 1.1
        k = 1.0 + math.sin(t * 2.0) * 0.02 + rnd.uniform(-0.006, 0.006)
        out.append((cx + math.cos(t) * rx * k, cy + math.sin(t) * ry * k))
    return out


def _hand_font(painter, size):
    import os
    if "hand" in painter.config.get("fonts", {}) or not os.path.exists(HAND_FONT):
        try:
            return painter.font("hand", size)
        except Exception:
            return painter.font("gothic", size)
    key = ("hand-font", size)
    if key not in painter._fonts:
        from PIL import ImageFont
        try:
            painter._fonts[key] = ImageFont.truetype(HAND_FONT, size)
        except OSError:
            painter._fonts[key] = painter.font("gothic", size)
    return painter._fonts[key]


def _write(painter, layer: Image.Image, text: str, x: float, y: float, p: float, anchor="ls", size=46) -> None:
    """手書きの一言（少し傾ける）。p のぶんだけ字が出る。白い縁取りで、下が何でも読める。"""
    n = max(0, min(len(text), int(math.ceil(len(text) * p))))
    if not n:
        return
    f = _hand_font(painter, size)
    full = f.getlength(text)
    pad = 16
    tile = Image.new("RGBA", (int(full) + pad * 2, int(size * 1.5) + pad * 2), (0, 0, 0, 0))
    ImageDraw.Draw(tile).text((pad, pad + size * 1.1), text[:n], font=f, fill=PEN + (255,), anchor="ls",
                              stroke_width=5, stroke_fill=(255, 252, 244, 255))
    tile = tile.rotate(4, resample=Image.BICUBIC, expand=True)
    tx = x - (tile.width if anchor[0] == "r" else tile.width / 2 if anchor[0] == "m" else 0)
    ty = y - tile.height * (0.75 if anchor[1] == "s" else 0.0)
    tx = max(4, min(layer.width - tile.width - 4, tx))
    ty = max(4, min(layer.height - tile.height - 4, ty))
    layer.alpha_composite(tile, (int(tx), int(ty)))


def draw_one(painter, layer: Image.Image, m: dict, box, area, i: int, p: float) -> None:
    """書き込み1つ。box は指す範囲（点なら幅0）、area は描いてよい範囲（矢印の向き・字の置き場に使う）。"""
    d = ImageDraw.Draw(layer)
    rnd = _rnd(i)
    x0, y0, x1, y1 = box
    point = (x1 - x0) < 2 and (y1 - y0) < 2
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    kind = m["type"]
    text = str(m.get("text", ""))
    if kind == "circle":
        if point:
            x0, y0, x1, y1 = cx - 60, cy - 50, cx + 60, cy + 50
        px, py = (x1 - x0) * 0.12 + 12, (y1 - y0) * 0.18 + 12
        pts = _wobble(_ellipse_pts((x0 - px, y0 - py, x1 + px, y1 + py), rnd), rnd, 1.2)
        _line(d, _part(pts, p))
        if text and p >= 1:
            _write(painter, layer, text, x1 + px - 10, y0 - py + 8, 1.0, "ls")
    elif kind in ("underline", "strike"):
        if point:
            x0, x1 = cx - 80, cx + 80
        y = (y1 + 10) if kind == "underline" else cy
        n = 36
        pts = [(x0 - 8 + (x1 - x0 + 16) * k / n, y + math.sin(k * 0.5) * (2.2 if kind == "underline" else 1.2)
                + (-(k / n - 0.5) * 6 if kind == "strike" else 0)) for k in range(n + 1)]
        _line(d, _part(_wobble(pts, rnd, 0.8), p), PEN_W + (1 if kind == "strike" else 0))
        if text and p >= 1:                                     # 線の右の端の上（下線は下）に書く
            if kind == "underline":
                _write(painter, layer, text, x1 + 8, y + 52, 1.0, "rs")
            else:
                _write(painter, layer, text, x1 + 8, y - 26, 1.0, "rs")
    elif kind == "arrow":
        ax0, ay0, ax1, ay1 = area
        if m.get("from"):
            sx, sy = m["from_px"]
        else:                                                   # 指す所から、広い側へ斜めに引き出す
            dx = 190 if cx < (ax0 + ax1) / 2 else -190
            dy = 130 if cy < (ay0 + ay1) / 2 else -130
            sx, sy = cx + dx, cy + dy
        # 矢じりは範囲の縁で止める（中身を隠さない）
        ex, ey = cx, cy
        if not point:
            hw, hh = (x1 - x0) / 2 + 10, (y1 - y0) / 2 + 10
            vx, vy = sx - cx, sy - cy
            s = min(hw / abs(vx) if vx else 1e9, hh / abs(vy) if vy else 1e9)
            ex, ey = cx + vx * min(1.0, s), cy + vy * min(1.0, s)
        mx, my = (sx + ex) / 2, (sy + ey) / 2
        bx, by = mx - (ey - sy) * 0.22, my + (ex - sx) * 0.22
        pts = []
        for k in range(41):
            t = k / 40
            u = 1 - t
            pts.append((u * u * sx + 2 * u * t * bx + t * t * ex, u * u * sy + 2 * u * t * by + t * t * ey))
        pts = _wobble(pts, rnd, 0.9)
        body = min(1.0, p / 0.8)
        _line(d, _part(pts, body))
        if p > 0.8:
            hp = (p - 0.8) / 0.2
            qx, qy = pts[-6]
            ang = math.atan2(ey - qy, ex - qx)
            for sgn in (1, -1):
                a = ang + math.pi + sgn * 0.45
                L = 30 * hp
                _line(d, [(ex, ey), (ex + math.cos(a) * L, ey + math.sin(a) * L)])
        if text and p >= 1:
            _write(painter, layer, text, sx, sy + (52 if sy > ey else -6), 1.0, "ms")
    elif kind == "note":
        if point:
            _write(painter, layer, text, x0, y0, p, "ls")
        else:
            _write(painter, layer, text, x1 - 10, y0 - 6, p, "rs")


def draw_marks(painter, img: Image.Image, mark: str | None, locate, area, t: float = 1.0) -> Image.Image:
    """書き込みを重ねる。locate(at) は at を画面の範囲に直す関数（指せなければ None）。
    前の行からある印は描き終えたまま、新しい印（from 以降）は t（0→1）で1つずつ描き進める。"""
    items, start = spec_of(mark)
    if not items:
        return img
    from .figures import _steps
    steps = _steps(t, start, len(items))
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    for i, (m, p) in enumerate(zip(items, steps)):
        if p <= 0:
            continue
        box = locate(m["at"])
        if box is None:
            continue
        if m.get("from"):
            fb = locate(m["from"])
            if fb is None:
                continue
            m = dict(m, from_px=((fb[0] + fb[2]) / 2, (fb[1] + fb[3]) / 2))
        draw_one(painter, layer, m, box, area, i, p)
    # 少しだけ滲ませると紙に書いたように見える。別の層に描いて重ねるので、前景の透明は落ちない
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(0.6)))
    return img
