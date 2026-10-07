# -*- coding: utf-8 -*-
"""アイコンを主役にした図、4つ。

今までの図は文字と棒だけだった。同じ中身でも、3Dアイコンが1つ入ると
画面の密度が変わる。素材は `assets/icons/` の30点。

    icon_stats   … アイコン＋数字を横に並べる
    icon_flow    … アイコンを矢印でつないで流れを見せる
    icon_list    … アイコン付きの箇条書き
    icon_compare … 大きなアイコン2つで左右を比べる

板の作り（色帯＋金の線＋落ち影）は news.py と揃えてある。
"""
from __future__ import annotations

import re
from pathlib import Path

from PIL import Image, ImageDraw

from danmen import icons
from danmen.news import (AMBER_D, AMBER_L, GOLD, GREEN_D, GREEN_L, INK, INK_SUB,
                         F, _bar, _credit, _panel, put_number)

UNIT = re.compile(r"(\d+(?:[,.]\d+)*)|([^\d]+)")
AMBER = (196, 122, 10)
TEAL = (16, 140, 118)
GRAY = (118, 126, 138)


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


def icon_stats(fig: dict) -> Image.Image:
    """アイコン＋数字を横に並べる。節の頭で「この回の数字」を出すのに使う。"""
    items = fig["items"][:4]
    w, h = 1240, 500
    im, d, top = _panel(w, h, fig.get("title", ""), band=fig.get("band", (20, 34, 64)))
    cw = (w - 80) // max(len(items), 1)
    for n, it in enumerate(items):
        cx = 40 + cw * n + cw / 2
        focus = bool(it.get("focus"))
        # 丸い台に載せる（縦横の比が違うアイコンを並べても揃って見える）
        pl = icons.plate(str(it.get("icon", "")), 118,
                         fill=(253, 246, 232) if focus else (241, 243, 246),
                         ring=AMBER if focus else None)
        im.alpha_composite(pl, (int(cx - pl.width / 2), top + 4))
        d = ImageDraw.Draw(im)
        val = str(it.get("value", ""))
        size = 62
        while _text_w(val, size) > cw - 40 and size > 28:
            size -= 4
        vy = top + 4 + pl.height + 24
        put_number(d, val, cx - _text_w(val, size) / 2, vy, size,
                   fill=AMBER if focus else INK)
        lab = str(it.get("label", ""))
        lf = F(27, 800)
        for i, ln in enumerate(_wrap(d, lab, lf, cw - 30)[:2]):
            d.text((cx - d.textlength(ln, font=lf) / 2, vy + size + 18 + i * 36), ln,
                   font=lf, fill=INK_SUB)
        if n < len(items) - 1:
            d.line([(40 + cw * (n + 1), top + 30), (40 + cw * (n + 1), h - 90)],
                   fill="#E2E5EA", width=2)
    _credit(d, fig.get("credit", ""), w, h)
    return im


def icon_flow(fig: dict) -> Image.Image:
    """アイコンを矢印でつないで流れを見せる。お金が誰から誰へ動くか。"""
    steps = fig["steps"][:4]
    w, h = 1320, 480
    im, d, top = _panel(w, h, fig.get("title", ""), band=fig.get("band", (20, 34, 64)))
    n = len(steps)
    cw = (w - 100) / max(n, 1)
    for i, st in enumerate(steps):
        cx = 50 + cw * i + cw / 2
        focus = bool(st.get("focus"))
        pl = icons.plate(str(st.get("icon", "")), 124,
                         fill=(253, 246, 232) if focus else (241, 243, 246),
                         ring=AMBER if focus else None)
        im.alpha_composite(pl, (int(cx - pl.width / 2), top + 10))
        d = ImageDraw.Draw(im)
        lab = str(st.get("label", ""))
        lf = F(32, 900 if focus else 800)
        ly = top + 10 + pl.height + 16
        for k, ln in enumerate(_wrap(d, lab, lf, cw - 30)[:2]):
            d.text((cx - d.textlength(ln, font=lf) / 2, ly + k * 40), ln,
                   font=lf, fill=INK if focus else INK_SUB)
            ly2 = ly + k * 40
        note = str(st.get("note", ""))
        if note:
            nf = F(23, 600)
            d.text((cx - d.textlength(note, font=nf) / 2, ly2 + 44), note,
                   font=nf, fill=INK_SUB)
        if i < n - 1:
            # 矢印。アイコンの高さの真ん中あたりに置く
            ax = cx + pl.width / 2 + 8
            bx = 50 + cw * (i + 1) + cw / 2 - pl.width / 2 - 8
            ay = top + 10 + pl.height / 2
            d.line([(ax, ay), (bx - 16, ay)], fill=GOLD, width=7)
            d.polygon([(bx - 18, ay - 16), (bx - 18, ay + 16), (bx + 6, ay)], fill=GOLD)
            amt = str(st.get("amount", ""))
            if amt:
                af = F(26, 900)
                mx = (ax + bx) / 2
                tw = d.textlength(amt, font=af)
                d.rounded_rectangle([mx - tw / 2 - 12, ay - 58, mx + tw / 2 + 12, ay - 14],
                                    radius=8, fill=(255, 255, 255), outline=GOLD, width=3)
                d.text((mx - tw / 2, ay - 54), amt, font=af, fill=AMBER)
    _credit(d, fig.get("credit", ""), w, h)
    return im


def icon_list(fig: dict) -> Image.Image:
    """アイコン付きの箇条書き。見立ての節で理由を並べるときに使う。"""
    items = fig["items"][:5]
    w, h = 1180, 160 + len(items) * 142
    im, d, top = _panel(w, h, fig.get("title", ""), band=fig.get("band", (20, 34, 64)))
    y = top
    for n, it in enumerate(items, 1):
        focus = bool(it.get("focus"))
        pl = icons.plate(str(it.get("icon", "")), 86,
                         fill=(253, 246, 232) if focus else (241, 243, 246),
                         ring=AMBER if focus else None)
        im.alpha_composite(pl, (58, y))
        d = ImageDraw.Draw(im)
        # 番号を台の左下に小さく添える
        nf = F(24)
        d.ellipse([46, y + pl.height - 44, 46 + 44, y + pl.height], fill=AMBER if focus else GRAY)
        d.text((46 + (44 - d.textlength(str(n), font=nf)) / 2, y + pl.height - 40), str(n),
               font=nf, fill="white")
        x = 58 + pl.width + 28
        lab = str(it.get("label", ""))
        lf = F(38, 900)
        d.text((x, y + 14), lab, font=lf, fill=INK)
        note = str(it.get("note", ""))
        if note:
            nf2 = F(25, 600)
            for k, ln in enumerate(_wrap(d, note, nf2, w - x - 60)[:2]):
                d.text((x, y + 66 + k * 36), ln, font=nf2, fill=INK_SUB)
        y += 142
    _credit(d, fig.get("credit", ""), w, h)
    return im


def icon_compare(fig: dict) -> Image.Image:
    """大きなアイコン2つで左右を比べる。日本と世界、昔といま。"""
    left, right = fig["left"], fig["right"]
    w, h = 1180, 640
    im, d, top = _panel(w, h, fig.get("title", ""), band=fig.get("band", (20, 34, 64)))
    mid = w / 2
    d.line([(mid, top + 10), (mid, h - 110)], fill="#DFE3E8", width=3)
    for side, s in ((0, left), (1, right)):
        cx = mid / 2 + side * mid
        focus = bool(s.get("focus"))
        icons.put(im, str(s.get("icon", "")), cx, top + 190, 170)
        d = ImageDraw.Draw(im)
        name = str(s.get("name", ""))
        nf = F(40)
        d.text((cx - d.textlength(name, font=nf) / 2, top + 206), name, font=nf,
               fill=INK if focus else INK_SUB)
        val = str(s.get("value", ""))
        size = 86
        while _text_w(val, size) > mid - 90 and size > 36:
            size -= 5
        put_number(d, val, cx - _text_w(val, size) / 2, top + 260, size,
                   fill=AMBER if focus else INK)
        note = str(s.get("note", ""))
        if note:
            f = F(26, 700)
            for k, ln in enumerate(_wrap(d, note, f, mid - 90)[:3]):
                d.text((cx - d.textlength(ln, font=f) / 2, top + 268 + size + k * 38), ln,
                       font=f, fill=INK_SUB)
    _credit(d, fig.get("credit", ""), w, h)
    return im


KINDS = {"icon_stats": icon_stats, "icon_flow": icon_flow,
         "icon_list": icon_list, "icon_compare": icon_compare}


def draw(fig: dict, out: Path) -> Path:
    kind = fig.get("kind")
    if kind not in KINDS:
        raise SystemExit("知らない種類です: {}（使えるのは {}）".format(kind, " / ".join(KINDS)))
    im = KINDS[kind](fig)
    out.parent.mkdir(parents=True, exist_ok=True)
    im.save(out)
    return out
