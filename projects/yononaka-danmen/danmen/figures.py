# -*- coding: utf-8 -*-
"""台本の figure から、画面の真ん中に出す図を描く。

種類は5つ。
    stack    … 積み上げ（何でできているか）
    timeline … 年表（いつ、誰が決めたか）
    flow     … 流れ図（誰が払い、どこへ行くか）
    compare  … 比べる（よその国はどうか）
    bars     … まとめの板（理由を番号で）

配色は dataviz の検証を通したもの（2026-10-06、light で全項目 PASS）。
色は並び順で固定して割り当てる。番号で色を変えない。
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

# --- 決まりの色（dataviz の検証済み） -------------------------------------
PAPER   = "#F4F1EA"   # 紙の地
INK     = "#23303A"   # 主な字
INK_SUB = "#5A6572"   # 添えの字
LINE    = "#D8D2C4"   # 罫
SERIES  = ["#0E8C77", "#C07A0C", "#4A63D0"]   # 並び順で固定。使い回さない
MUTED   = "#B6B0A3"   # 比べる図で、注目しないほう

W, H = 1040, 700
FONT = "C:/Windows/Fonts/meiryo.ttc"
FONTB = "C:/Windows/Fonts/meiryob.ttc"


def _f(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(FONTB if bold else FONT, size)


def _canvas(title: str) -> tuple[Image.Image, ImageDraw.ImageDraw, int]:
    im = Image.new("RGB", (W, H), PAPER)
    d = ImageDraw.Draw(im)
    top = 24
    if title:
        d.text((28, top), title, font=_f(34, True), fill=INK)
        top += 58
        d.line([(28, top), (W - 28, top)], fill=LINE, width=2)
        top += 24
    return im, d, top


def stack(fig: dict) -> Image.Image:
    """積み上げ。各段に名前と実額を直接書く（凡例は作らない）。"""
    im, d, top = _canvas(fig.get("title", ""))
    items = fig["items"]
    total = sum(float(i["value"]) for i in items) or 1
    x, w = 90, 420
    avail = H - top - 70
    y = top + 10
    for n, it in enumerate(items):
        h = int(avail * float(it["value"]) / total)
        col = SERIES[n % len(SERIES)]
        d.rectangle([x, y, x + w, y + h - 2], fill=col)          # 2px の隙間を空ける
        d.text((x + 24, y + h // 2 - 20), str(it["label"]), font=_f(30, True), fill="white")
        note = str(it.get("note", ""))
        if note:
            tw = d.textlength(note, font=_f(30, True))
            d.text((x + w - tw - 24, y + h // 2 - 20), note, font=_f(30, True), fill="white")
        # 右に引き出して割合を書く
        pct = f"{float(it['value']) / total * 100:.0f}%"
        d.line([(x + w + 12, y + h // 2), (x + w + 44, y + h // 2)], fill=LINE, width=2)
        d.text((x + w + 54, y + h // 2 - 18), pct, font=_f(28, True), fill=INK_SUB)
        y += h
    if fig.get("note"):
        d.text((x, H - 48), str(fig["note"]), font=_f(24), fill=INK_SUB)
    return im


def timeline(fig: dict) -> Image.Image:
    """年表。左から右へ。いまに近いほど右。"""
    im, d, top = _canvas(fig.get("title", ""))
    items = fig["items"]
    y = top + 150
    x0, x1 = 150, W - 150
    d.line([(x0, y), (x1, y)], fill=LINE, width=4)
    step = (x1 - x0) / max(len(items) - 1, 1)
    for n, it in enumerate(items):
        x = int(x0 + step * n)
        col = SERIES[n % len(SERIES)]
        d.ellipse([x - 11, y - 11, x + 11, y + 11], fill=col)
        lw = d.textlength(str(it["label"]), font=_f(30, True))
        d.text((x - lw / 2, y + 28), str(it["label"]), font=_f(30, True), fill=INK)
        note = str(it.get("note", ""))
        if note:
            # 文字を折り返して点の上に置く
            width = min(step - 44, 210)
            lines, cur = [], ""
            for ch in note:
                cur += ch
                if d.textlength(cur, font=_f(24)) > width:
                    lines.append(cur); cur = ""
            if cur:
                lines.append(cur)
            for i, ln in enumerate(lines[:4]):
                tw = d.textlength(ln, font=_f(24))
                d.text((x - tw / 2, y - 48 - (len(lines[:4]) - 1 - i) * 30), ln,
                       font=_f(24), fill=INK_SUB)
    return im


def flow(fig: dict) -> Image.Image:
    """流れ図。左から右へ、箱と矢印。"""
    im, d, top = _canvas(fig.get("title", ""))
    items = fig["items"]
    n = len(items)
    bw, bh = min(260, (W - 120 - (n - 1) * 70) // max(n, 1)), 140
    y = top + 120
    x = 60
    for i, it in enumerate(items):
        col = SERIES[i % len(SERIES)]
        d.rounded_rectangle([x, y, x + bw, y + bh], radius=10, fill=col)
        d.text((x + 20, y + 30), str(it["label"]), font=_f(30, True), fill="white")
        note = str(it.get("note", ""))
        if note:
            d.text((x + 20, y + bh + 16), note, font=_f(24), fill=INK_SUB)
        if i < n - 1:
            ax = x + bw + 14
            d.line([(ax, y + bh // 2), (ax + 42, y + bh // 2)], fill=INK_SUB, width=4)
            d.polygon([(ax + 42, y + bh // 2 - 12), (ax + 42, y + bh // 2 + 12),
                       (ax + 62, y + bh // 2)], fill=INK_SUB)
        x += bw + 70
    return im


def compare(fig: dict) -> Image.Image:
    """比べる。注目する1つだけ色を付け、ほかは落とす。"""
    im, d, top = _canvas(fig.get("title", ""))
    items = fig["items"]
    mx = max(float(i["value"]) for i in items) or 1
    y = top + 30
    bw = W - 480          # 右に値を書く場所を残す
    focus = fig.get("focus", items[0]["label"])
    for it in items:
        col = SERIES[0] if str(it["label"]) == str(focus) else MUTED
        w = int(bw * float(it["value"]) / mx)
        d.text((60, y + 10), str(it["label"]), font=_f(30, True), fill=INK)
        d.rectangle([220, y, 220 + max(w, 3), y + 54], fill=col)
        val = str(it.get("note", it["value"]))
        d.text((220 + max(w, 3) + 16, y + 10), val, font=_f(28, True), fill=INK_SUB)
        y += 86
    return im


def bars(fig: dict) -> Image.Image:
    """まとめの板。理由を番号で並べる。"""
    im, d, top = _canvas(fig.get("title", ""))
    y = top + 16
    for n, it in enumerate(fig["items"], 1):
        col = SERIES[(n - 1) % len(SERIES)]
        d.ellipse([60, y, 60 + 52, y + 52], fill=col)
        tw = d.textlength(str(n), font=_f(30, True))
        d.text((60 + 26 - tw / 2, y + 8), str(n), font=_f(30, True), fill="white")
        d.text((140, y + 6), str(it["label"]), font=_f(32, True), fill=INK)
        note = str(it.get("note", ""))
        if note:
            d.text((140, y + 50), note, font=_f(25), fill=INK_SUB)
        y += 110
    return im


KINDS = {"stack": stack, "timeline": timeline, "flow": flow, "compare": compare, "bars": bars}


def draw(fig: dict, out: Path) -> Path:
    kind = fig.get("kind")
    if kind not in KINDS:
        raise SystemExit(f"図の種類「{kind}」は知りません。使えるのは {' / '.join(KINDS)}")
    im = KINDS[kind](fig)
    im = _trim(im)
    out.parent.mkdir(parents=True, exist_ok=True)
    im.save(out)
    return out


def _trim(im: Image.Image, pad: int = 28) -> Image.Image:
    """紙色だけの余白を落とす（図ごとに高さが変わる）。"""
    bg = Image.new("RGB", im.size, PAPER)
    from PIL import ImageChops
    box = ImageChops.difference(im, bg).convert("L").point(lambda v: 255 if v > 8 else 0).getbbox()
    if not box:
        return im
    l, t, r, b = box
    return im.crop((max(l - pad, 0), max(t - pad, 0),
                    min(r + pad, im.width), min(b + pad, im.height)))
