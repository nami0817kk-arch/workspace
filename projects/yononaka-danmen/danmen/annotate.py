# -*- coding: utf-8 -*-
"""画面に「手で書き込んだ」強調を重ねる。

出来上がった図や画面の上から掛ける。ニュースの解説で、説明しながら
赤ペンで囲んだり線を引いたりするあの動き、その結果だけを静止画で作る。

    circle     … 赤で囲む（楕円。2周ぶん、少し揺らして描く）
    box        … 赤で四角く囲む
    underline  … 下線（波打つ）
    strike     … 取り消し線
    highlight  … 蛍光ペン（半透明の帯。文字の上に乗せる）
    arrow      … 曲がった矢印で指す
    cross      … ×印
    check      … レの印
    note       … 手書きの短い言葉（少し傾ける）
    bang       … 「！」や「※」の書き込み

使い方:

    from danmen import annotate
    im = annotate.apply(im, [
        {"kind": "circle", "box": [300, 400, 700, 520]},
        {"kind": "arrow", "to": [500, 460], "from": [900, 700], "text": "ここ"},
    ])

座標は画像の実ピクセル。`seed` を変えると揺らし方が変わる。
"""
from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

FONT_PATH = "C:/Windows/Fonts/NotoSansJP-VF.ttf"
PEN = (214, 38, 38)          # 赤ペン
PEN_SUB = (28, 74, 196)      # 青ペン
MARKER = (255, 226, 86)      # 蛍光ペン（黄）
INK = (24, 26, 32)


def F(size: int, weight: int = 900) -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(FONT_PATH, size)
    try:
        f.set_variation_by_axes([weight])
    except Exception:
        pass
    return f


def _col(spec: dict) -> tuple[int, int, int]:
    c = spec.get("color", "red")
    if isinstance(c, (list, tuple)):
        return tuple(c)                     # type: ignore[return-value]
    return {"red": PEN, "blue": PEN_SUB, "ink": INK}.get(str(c), PEN)


def _rnd(spec: dict) -> random.Random:
    return random.Random(int(spec.get("seed", 7)))


# ---- 線の形 -----------------------------------------------------------------

def _wobble(pts: list[tuple[float, float]], rnd: random.Random,
            amp: float = 2.4) -> list[tuple[float, float]]:
    """点の並びを少し揺らす。まっすぐ引けていない線に見せるため。"""
    out = []
    for i, (x, y) in enumerate(pts):
        k = math.sin(i * 0.35) * amp + rnd.uniform(-amp * 0.5, amp * 0.5)
        out.append((x + k, y + k * 0.6))
    return out


def _ellipse_pts(box, rnd, turns: float = 1.08, phase: float = 0.0):
    x0, y0, x1, y1 = box
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    rx, ry = (x1 - x0) / 2, (y1 - y0) / 2
    n = 120
    pts = []
    start = phase + rnd.uniform(-0.3, 0.3)
    for i in range(n + 1):
        t = start + i / n * (2 * math.pi * turns)
        # 一周のあいだに半径をゆっくり変える（手で回したときの歪み）
        k = 1.0 + math.sin(t * 2.0 + phase) * 0.018 + rnd.uniform(-0.008, 0.008)
        pts.append((cx + math.cos(t) * rx * k, cy + math.sin(t) * ry * k))
    return pts


def circle(d: ImageDraw.ImageDraw, spec: dict) -> None:
    """赤で囲む。2周ぶん描くので、勢いよく丸を付けたように見える。"""
    rnd = _rnd(spec)
    box = spec["box"]
    col, w = _col(spec), int(spec.get("width", 9))
    for p in range(int(spec.get("passes", 2))):
        d.line(_ellipse_pts(box, rnd, phase=p * 1.7), fill=col,
               width=max(w - p * 2, 4), joint="curve")


def box(d: ImageDraw.ImageDraw, spec: dict) -> None:
    """四角く囲む。角をはみ出させると手書きらしくなる。"""
    rnd = _rnd(spec)
    x0, y0, x1, y1 = spec["box"]
    col, w = _col(spec), int(spec.get("width", 9))
    o = 16                                   # 横線だけ角をはみ出させる
    for a, b in (((x0 - o, y0), (x1 + o, y0)), ((x1, y0), (x1, y1)),
                 ((x1 + o, y1), (x0 - o, y1)), ((x0, y1), (x0, y0))):
        n = 24
        pts = [(a[0] + (b[0] - a[0]) * i / n, a[1] + (b[1] - a[1]) * i / n)
               for i in range(n + 1)]
        d.line(_wobble(pts, rnd, 2.0), fill=col, width=w, joint="curve")


def underline(d: ImageDraw.ImageDraw, spec: dict) -> None:
    """下線。まっすぐではなく、ゆるく波打たせる。"""
    rnd = _rnd(spec)
    x0, y, x1 = spec["at"][0], spec["at"][1], spec["at"][2]
    col, w = _col(spec), int(spec.get("width", 8))
    n = 40
    amp = float(spec.get("amp", 2.2))
    pts = [(x0 + (x1 - x0) * i / n, y + math.sin(i * 0.5) * amp) for i in range(n + 1)]
    d.line(_wobble(pts, rnd, 1.0), fill=col, width=w, joint="curve")
    if spec.get("double"):
        pts2 = [(x, y + 14 + math.sin(i * 0.5 + 1) * amp * 0.7) for i, (x, y) in enumerate(pts)]
        d.line(_wobble(pts2, rnd, 1.4), fill=col, width=max(w - 3, 3), joint="curve")


def strike(d: ImageDraw.ImageDraw, spec: dict) -> None:
    """取り消し線。「この説は違う」を示すときに使う。"""
    rnd = _rnd(spec)
    x0, y, x1 = spec["at"][0], spec["at"][1], spec["at"][2]
    col, w = _col(spec), int(spec.get("width", 8))
    n = 30
    pts = [(x0 + (x1 - x0) * i / n, y + math.sin(i * 0.4) * 2.5) for i in range(n + 1)]
    d.line(_wobble(pts, rnd, 1.4), fill=col, width=w, joint="curve")


def arrow(d: ImageDraw.ImageDraw, spec: dict) -> None:
    """曲がった矢印で指す。from から to へ。text を付けると根元に書く。"""
    rnd = _rnd(spec)
    sx, sy = spec["from"]
    ex, ey = spec["to"]
    col, w = _col(spec), int(spec.get("width", 8))
    bend = float(spec.get("bend", 0.28))
    # 制御点を線分の垂直方向にずらして弧にする
    mx, my = (sx + ex) / 2, (sy + ey) / 2
    dx, dy = ex - sx, ey - sy
    cx, cy = mx - dy * bend, my + dx * bend
    n = 40
    pts = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        pts.append((u * u * sx + 2 * u * t * cx + t * t * ex,
                    u * u * sy + 2 * u * t * cy + t * t * ey))
    d.line(_wobble(pts, rnd, 1.2), fill=col, width=w, joint="curve")
    # 矢じり
    px, py = pts[-6]
    ang = math.atan2(ey - py, ex - px)
    L = float(spec.get("head", 34))
    for s in (+1, -1):
        a = ang + math.pi + s * 0.42
        d.line([(ex, ey), (ex + math.cos(a) * L, ey + math.sin(a) * L)],
               fill=col, width=w, joint="curve")
    text = str(spec.get("text", ""))
    if text:
        f = F(int(spec.get("size", 44)))
        tw = d.textlength(text, font=f)
        tx = sx - tw / 2 + (24 if ex > sx else -24)
        d.text((tx, sy - (60 if ey > sy else -20)), text, font=f, fill=col,
               stroke_width=4, stroke_fill=(255, 255, 255))


def cross(d: ImageDraw.ImageDraw, spec: dict) -> None:
    """×印。誤解を潰す節で使う。"""
    rnd = _rnd(spec)
    x0, y0, x1, y1 = spec["box"]
    col, w = _col(spec), int(spec.get("width", 11))
    for a, b in (((x0, y0), (x1, y1)), ((x1, y0), (x0, y1))):
        n = 16
        pts = [(a[0] + (b[0] - a[0]) * i / n, a[1] + (b[1] - a[1]) * i / n)
               for i in range(n + 1)]
        d.line(_wobble(pts, rnd, 2.2), fill=col, width=w, joint="curve")


def check(d: ImageDraw.ImageDraw, spec: dict) -> None:
    """レの印。"""
    rnd = _rnd(spec)
    x0, y0, x1, y1 = spec["box"]
    col, w = _col(spec), int(spec.get("width", 11))
    pts = [(x0, y0 + (y1 - y0) * 0.55), ((x0 + x1) / 2 - (x1 - x0) * 0.1, y1), (x1, y0)]
    out = []
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        n = 12
        out += [(a[0] + (b[0] - a[0]) * j / n, a[1] + (b[1] - a[1]) * j / n)
                for j in range(n + 1)]
    d.line(_wobble(out, rnd, 1.8), fill=col, width=w, joint="curve")


def bang(d: ImageDraw.ImageDraw, spec: dict) -> None:
    """「！」「？」「※」などの書き込み。少し傾けたいが、傾けるのは apply 側で行う。"""
    text = str(spec.get("text", "！"))
    f = F(int(spec.get("size", 92)))
    x, y = spec["at"]
    col = _col(spec)
    d.text((x, y), text, font=f, fill=col, stroke_width=7, stroke_fill=(255, 255, 255))


def note(d: ImageDraw.ImageDraw, spec: dict) -> None:
    """手書きの短い言葉。白い縁取りを付けて、背景が何でも読めるようにする。"""
    text = str(spec.get("text", ""))
    f = F(int(spec.get("size", 44)))
    x, y = spec["at"]
    col = _col(spec)
    d.text((x, y), text, font=f, fill=col, stroke_width=6, stroke_fill=(255, 255, 255))


# ---- 半透明が要るもの（別の層に描いて重ねる）--------------------------------

def _highlight(im: Image.Image, spec: dict) -> Image.Image:
    """蛍光ペン。文字の上から黄色い帯を乗せる。端を少しはみ出させる。"""
    rnd = _rnd(spec)
    x0, y0, x1, y1 = spec["box"]
    col = spec.get("color")
    rgb = tuple(col) if isinstance(col, (list, tuple)) else MARKER
    alpha = int(spec.get("alpha", 150))
    layer = Image.new("RGBA", im.size, (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    h = (y1 - y0) * float(spec.get("thickness", 0.82))
    n = 26
    pts = [(x0 - 8 + (x1 - x0 + 16) * i / n, (y0 + y1) / 2 + math.sin(i * 0.4) * 1.6)
           for i in range(n + 1)]
    ld.line(_wobble(pts, rnd, 0.6), fill=rgb + (alpha,), width=int(h), joint="curve")
    layer = layer.filter(ImageFilter.GaussianBlur(2.2))
    out = im.convert("RGBA")
    out.alpha_composite(layer)
    return out


PENS = {"circle": circle, "box": box, "underline": underline, "strike": strike,
        "arrow": arrow, "cross": cross, "check": check, "bang": bang, "note": note}
LAYERS = {"highlight": _highlight}


def apply(im: Image.Image, marks: list[dict]) -> Image.Image:
    """書き込みをまとめて重ねる。marks の順に描く（後のものが上）。"""
    out = im.convert("RGBA")
    for m in marks:
        kind = m.get("kind")
        if kind in LAYERS:
            out = LAYERS[kind](out, m)
        elif kind in PENS:
            # ペンの線は、少しだけ滲ませてから重ねると紙に書いたように見える
            layer = Image.new("RGBA", out.size, (0, 0, 0, 0))
            PENS[kind](ImageDraw.Draw(layer), m)
            layer = layer.filter(ImageFilter.GaussianBlur(0.6))
            out.alpha_composite(layer)
        else:
            raise SystemExit("知らない書き込みです: {}（使えるのは {}）".format(
                kind, " / ".join(list(PENS) + list(LAYERS))))
    return out.convert("RGB")


def draw(spec: dict, out: Path) -> Path:
    """単体で試すとき用。spec は {"base": 画像の場所, "marks": [...]}。"""
    im = Image.open(str(spec["base"])).convert("RGB")
    im = apply(im, spec.get("marks", []))
    out.parent.mkdir(parents=True, exist_ok=True)
    im.save(out)
    return out
