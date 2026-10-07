# -*- coding: utf-8 -*-
"""判定・比較のための図、5つ。

    flowchart  … 分岐の図。「あなたは当てはまる？」を辿れるようにする
    matrix     … 4象限。2つの軸で分けて位置を示す
    receipt    … レシート風の明細。内訳を1行ずつ
    numberline … 数直線。値がどのあたりかを1本の線で
    verdict    … ◎○△× の比較表。案を並べて比べる

板の作り（色帯＋金の線＋落ち影）は news.py と揃えてある。
"""
from __future__ import annotations

import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

from danmen import typo
from danmen.news import (AMBER_D, AMBER_L, BLUE_D, BLUE_L, GOLD, GRAY_D, GRAY_L,
                         GREEN_D, GREEN_L, INK, INK_SUB, RED_D, RED_L, F, _bar,
                         _credit, _panel, put_number)

UNIT = re.compile(r"(\d+(?:[,.]\d+)*)|([^\d]+)")
GREEN = (16, 140, 118)
RED = (196, 48, 42)
AMBER = (164, 102, 8)        # 文字用。塗りより濃い（白地で 4.6:1）


def _text_w(text: str, size: int) -> float:
    probe = ImageDraw.Draw(Image.new("RGB", (1, 1)))
    w = 0.0
    for m in UNIT.finditer(text):
        w += probe.textlength(m.group(0), font=F(size) if m.group(1) else F(int(size * 0.58), 800))
    return w


def _wrap(d, text: str, font, width: float) -> list[str]:
    lines, cur = [], ""
    for ch in text:
        if ch == "\n":
            lines.append(cur); cur = ""; continue
        cur += ch
        if d.textlength(cur, font=font) > width:
            lines.append(cur); cur = ""
    if cur:
        lines.append(cur)
    return lines


def flowchart(fig: dict) -> Image.Image:
    """分岐の図。問い → はい／いいえ → 結論。視聴者が自分で辿れる。"""
    steps = fig["steps"]          # [{ask, yes, no}] 最後に ends
    w, h = typo.PANEL_W, 230 + len(steps) * 190 + (110 if fig.get("end") else 0)
    im, d, top = _panel(w, h, fig.get("title", ""), band=fig.get("band", (20, 34, 64)))
    y = top
    cw = int(w * 0.46)
    cx = 80
    for i, st in enumerate(steps):
        ask = str(st.get("ask", ""))
        # 問いの箱
        d.rounded_rectangle([cx, y, cx + cw, y + 110], radius=12, fill=(20, 34, 64))
        for n, ln in enumerate(_wrap(d, ask, F(31), cw - 60)[:2]):
            d.text((cx + 30, y + (24 if n == 0 else 64)), ln, font=F(31), fill="white")
        # 右へ「いいえ」
        no = str(st.get("no", ""))
        if no:
            ax = cx + cw + 16
            # 「いいえ」の札が箱に重ならないよう、矢印を長めに取る
            lf = F(typo.NOTE, 800)
            lw = d.textlength("いいえ", font=lf)
            d.line([(ax, y + 60), (ax + lw + 24, y + 60)], fill=RED, width=5)
            d.polygon([(ax + lw + 24, y + 44), (ax + lw + 24, y + 76),
                       (ax + lw + 50, y + 60)], fill=RED)
            d.text((ax + 10, y + 10), "いいえ", font=lf, fill=RED)
            nf = F(28, 800)
            nw = max(d.textlength(l, font=nf) for l in _wrap(d, no, nf, 420)[:2]) + 56
            d.rounded_rectangle([ax + lw + 62, y + 10, ax + lw + 62 + nw, y + 100], radius=10,
                                fill=(252, 240, 238), outline=RED, width=3)
            for n, ln in enumerate(_wrap(d, no, nf, 420)[:2]):
                d.text((ax + lw + 86, y + 22 + n * 44), ln, font=nf, fill=(140, 30, 26))
        # 下へ「はい」
        if i < len(steps) - 1 or fig.get("end"):
            d.line([(cx + 60, y + 110), (cx + 60, y + 170)], fill=GREEN, width=5)
            d.polygon([(cx + 47, y + 170), (cx + 73, y + 170), (cx + 60, y + 190)], fill=GREEN)
            d.text((cx + 80, y + 126), "はい", font=F(typo.NOTE, 800), fill=GREEN)
        y += 190
    end = str(fig.get("end", ""))
    if end:
        d.rounded_rectangle([cx, y, cx + cw, y + 108], radius=12, fill=GREEN)
        for n, ln in enumerate(_wrap(d, end, F(33), cw - 60)[:2]):
            d.text((cx + 30, y + 24 + n * 42), ln, font=F(33), fill="white")
    _credit(d, fig.get("credit", ""), w, h)
    return im


def matrix(fig: dict) -> Image.Image:
    """4象限。2つの軸で分ける。items は {label, x, y}（それぞれ -1〜1）。"""
    w, h = typo.PANEL_W, 760
    im, d, top = _panel(w, h, fig.get("title", ""), band=fig.get("band", (20, 34, 64)))
    pad = 120
    x0, y0 = pad, top + 40
    x1, y1 = w - pad - 20, h - 110
    cxm, cym = (x0 + x1) / 2, (y0 + y1) / 2
    d.rectangle([x0, y0, x1, y1], fill=(246, 247, 249))
    d.line([(cxm, y0), (cxm, y1)], fill="#C9CDD3", width=3)
    d.line([(x0, cym), (x1, cym)], fill="#C9CDD3", width=3)
    ax = fig.get("axis", {})
    d.text(((x0 + x1) / 2 - d.textlength(str(ax.get("top", "")), font=F(typo.NOTE, 800)) / 2, y0 - 36),
           str(ax.get("top", "")), font=F(typo.NOTE, 800), fill=INK_SUB)
    d.text(((x0 + x1) / 2 - d.textlength(str(ax.get("bottom", "")), font=F(typo.NOTE, 800)) / 2, y1 + 14),
           str(ax.get("bottom", "")), font=F(typo.NOTE, 800), fill=INK_SUB)
    d.text((x0 - 50, cym - 48), str(ax.get("left", "")), font=F(typo.NOTE, 800), fill=INK_SUB)
    rt = str(ax.get("right", ""))
    d.text((x1 - d.textlength(rt, font=F(typo.NOTE, 800)) + 60, cym - 48), rt, font=F(typo.NOTE, 800), fill=INK_SUB)
    # 印を先に全部打ってから、札を置く（札が印を隠さないように）
    pts = []
    for it in fig.get("items", []):
        px = cxm + float(it.get("x", 0)) * (x1 - x0) / 2 * 0.82
        py = cym - float(it.get("y", 0)) * (y1 - y0) / 2 * 0.82
        focus = bool(it.get("focus"))
        col = AMBER if focus else (90, 100, 112)
        r = 18 if focus else 13
        d.ellipse([px - r, py - r, px + r, py + r], fill=col, outline="white", width=4)
        pts.append((px, py, r, focus, str(it.get("label", ""))))
    # 札。重なったら上下にずらし、右に出ないときは左に出す
    taken: list[tuple[float, float, float, float]] = []
    for px, py, r, focus, lab in pts:
        f = F(27, 900 if focus else 700)
        tw = d.textlength(lab, font=f)
        left = px + r + 12 + tw > x1 + 10
        lx = (px - r - 12 - tw) if left else (px + r + 12)
        ly = py - 18
        for _ in range(8):
            box = (lx - 4, ly - 2, lx + tw + 4, ly + 36)
            if not any(box[0] < t[2] and t[0] < box[2] and box[1] < t[3] and t[1] < box[3]
                       for t in taken):
                break
            ly += 40 if py <= cym else -40
        taken.append((lx - 4, ly - 2, lx + tw + 4, ly + 36))
        if abs(ly - (py - 18)) > 6:
            # ずらした札は、どの印のものか分かるように細い線で結ぶ
            ex = lx + tw + 6 if left else lx - 6
            d.line([(px, py), (ex, ly + 16)], fill=(186, 192, 200), width=2)
        d.text((lx, ly), lab, font=f, fill=INK if focus else INK_SUB)
    _credit(d, fig.get("credit", ""), w, h)
    return im


def receipt(fig: dict) -> Image.Image:
    """レシート風の明細。断面図のチャンネルに合う形。

    大きさと文字は `typo` の基準どおり。画面に等倍で置いたとき、
    スマホでも読める太さにしてある。
    """
    items = fig["items"]
    slots = max(int(fig.get("slots", len(items))), 1)
    if slots > typo.max_rows():
        raise SystemExit(
            "行が多すぎます（{}行）。板に入るのは{}行までです。2つに割ってください。".format(
                slots, typo.max_rows()))
    w = typo.PANEL_W
    h = 126 + slots * typo.ROW + 200
    im, d, top = _panel(w, h, fig.get("title", ""), band=fig.get("band", (20, 34, 64)))
    pad = 90
    d.rectangle([pad, top, w - pad + 40, h - 52], fill=(252, 251, 246))
    y = top + 18
    for it in items:
        lab = str(it.get("label", ""))
        val = str(it.get("value", ""))
        strong = bool(it.get("strong"))
        f = F(typo.BODY, 900 if strong else 700)
        d.text((pad + 30, y), lab, font=f, fill=AMBER if strong else INK)
        size = typo.VALUE + (6 if strong else 0)
        put_number(d, val, w - pad - _text_w(val, size) + 10, y - 2, size,
                   fill=AMBER if strong else INK)
        # 点線。細いと画面では見えないので、少し太く・濃く
        dots_x = pad + 30 + d.textlength(lab, font=f) + 20
        end_x = w - pad - _text_w(val, size) - 16
        x = dots_x
        while x < end_x:
            d.line([(x, y + 34), (x + 9, y + 34)], fill="#BFC5CD", width=3)
            x += 20
        y += typo.ROW
    # 合計の線は、行が増えても動かない位置に固定する
    y = top + 18 + slots * typo.ROW
    d.line([(pad + 30, y + 10), (w - pad + 14, y + 10)], fill=INK, width=4)
    total_l = str(fig.get("total_label", "合計"))
    total_v = str(fig.get("total_value", ""))
    d.text((pad + 30, y + 30), total_l, font=F(typo.TITLE), fill=INK)
    put_number(d, total_v, w - pad - _text_w(total_v, typo.TITLE + 16) + 10, y + 24,
               typo.TITLE + 16, fill=INK)
    _credit(d, fig.get("credit", ""), w, h)
    return im


def row_box(i: int, side: str = "label") -> list[int]:
    """レシートの i 行目（0 から）の矩形。**書き込みを当てる場所**を計算で出す。

    板の大きさを変えるたびに書き込みの座標を手で直すのは事故のもと。
    蛍光ペンや丸はここから取る。side は label（左のことば）か value（右の数字）。
    """
    top = 28 + typo.BAND_H + 26
    y = top + 18 + i * typo.ROW
    pad = 90
    if side == "value":
        return [typo.PANEL_W - pad - 230, y - 8, typo.PANEL_W - pad + 24, y + 62]
    return [pad + 22, y - 2, pad + 22 + 660, y + 58]


def numberline(fig: dict) -> Image.Image:
    """数直線。値がどのあたりかを1本の線で示す。"""
    items = fig["items"]
    lo = float(fig.get("min", min(float(i["value"]) for i in items)))
    hi = float(fig.get("max", max(float(i["value"]) for i in items)))
    span = (hi - lo) or 1
    w, h = typo.PANEL_W, 560
    im, d, top = _panel(w, h, fig.get("title", ""), band=fig.get("band", (20, 34, 64)))
    x0, x1 = 110, w - 70
    ly = top + 190
    d.line([(x0, ly), (x1, ly)], fill="#C9CDD3", width=8)
    d.text((x0 - 20, ly + 26), str(fig.get("min_label", lo)), font=F(typo.NOTE, 700), fill=INK_SUB)
    mxl = str(fig.get("max_label", hi))
    d.text((x1 - d.textlength(mxl, font=F(typo.NOTE, 700)) + 20, ly + 26), mxl, font=F(typo.NOTE, 700), fill=INK_SUB)
    for n, it in enumerate(items):
        v = float(it["value"])
        px = x0 + (v - lo) / span * (x1 - x0)
        focus = bool(it.get("focus"))
        col = AMBER if focus else (120, 128, 140)
        r = 20 if focus else 13
        up = n % 2 == 0
        d.line([(px, ly), (px, ly - 70 if up else ly + 70)], fill=col, width=4)
        d.ellipse([px - r, ly - r, px + r, ly + r], fill=col, outline="white", width=4)
        lab, f = str(it.get("label", "")), F(27, 900 if focus else 700)
        note, nf = str(it.get("note", "")), F(31 if focus else 26)
        ty = ly - 152 if up else ly + 96
        d.text((px - d.textlength(lab, font=f) / 2, ty), lab, font=f, fill=INK if focus else INK_SUB)
        if note:
            put_number(d, note, px - _text_w(note, nf.size) / 2, ty + 34, nf.size,
                       fill=AMBER if focus else INK_SUB)
    _credit(d, fig.get("credit", ""), w, h)
    return im


MARKS = {"◎": (16, 140, 118), "○": (16, 140, 118), "△": (196, 122, 10), "×": (196, 48, 42)}


def verdict(fig: dict) -> Image.Image:
    """◎○△× の比較表。案を並べて比べる。"""
    cols = fig.get("cols", [])
    items = fig["items"]
    w, h = typo.PANEL_W, 260 + max(int(fig.get("slots", len(items))), 1) * 86
    im, d, top = _panel(w, h, fig.get("title", ""), band=fig.get("band", (20, 34, 64)))
    label_w = 460
    cw = (w - label_w - 60) // max(len(cols), 1)
    for i, c in enumerate(cols):
        f = F(28, 800)
        cx = 58 + label_w + i * cw
        d.text((cx + (cw - d.textlength(str(c), font=f)) / 2, top - 4), str(c), font=f, fill=INK_SUB)
    top += 44
    d.line([(58, top), (w - 24, top)], fill="#D9DDE3", width=2)
    y = top + 12
    for n, it in enumerate(items):
        if n % 2 == 1:
            d.rectangle([44, y - 6, w - 24, y + 70], fill="#F2F4F7")
        d.text((58, y + 16), str(it["label"]), font=F(30, 800), fill=INK)
        for i, v in enumerate(it.get("values", [])):
            cx = 58 + label_w + i * cw
            mark = str(v)
            col = MARKS.get(mark, INK)
            f = F(44)
            d.text((cx + (cw - d.textlength(mark, font=f)) / 2, y + 6), mark, font=f, fill=col)
        y += 86
    note = str(fig.get("note", ""))
    if note:
        d.text((58, h - 66), note, font=F(typo.NOTE, 600), fill=INK_SUB)
    _credit(d, fig.get("credit", ""), w, h)
    return im


KINDS = {"flowchart": flowchart, "matrix": matrix, "receipt": receipt,
         "numberline": numberline, "verdict": verdict}


def draw(fig: dict, out: Path) -> Path:
    kind = fig.get("kind")
    if kind not in KINDS:
        raise SystemExit("知らない種類です: {}（使えるのは {}）".format(kind, " / ".join(KINDS)))
    im = KINDS[kind](fig)
    out.parent.mkdir(parents=True, exist_ok=True)
    im.save(out)
    return out
