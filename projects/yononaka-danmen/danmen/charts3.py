# -*- coding: utf-8 -*-
"""ニュースで頻出するが、まだ無かった図をさらに4つ。

    relation … 相関図。誰と誰が、どう繋がっているか
    calc     … 計算の板。どう計算したかを見せる
    stats    … 数字を3つ並べる（1日／1年／生涯）
    gauge    … 半円のメーター。達成度・割合

板の作り（色帯＋金の線＋落ち影）は news.py と揃えてある。
"""
from __future__ import annotations

import math
import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

from danmen import typo
from danmen.news import (AMBER_D, AMBER_L, BLUE_D, BLUE_L, GOLD, GRAY_D, GRAY_L,
                         GREEN_D, GREEN_L, INK, INK_SUB, RED_D, RED_L, F, _bar,
                         _credit, _panel, put_number)

UNIT = re.compile(r"(\d+(?:[,.]\d+)*)|([^\d]+)")


def _text_w(text: str, size: int) -> float:
    probe = ImageDraw.Draw(Image.new("RGB", (1, 1)))
    w = 0.0
    for m in UNIT.finditer(text):
        num = m.group(1)
        w += probe.textlength(m.group(0), font=F(size) if num else F(int(size * 0.58), 800))
    return w


def relation(fig: dict) -> Image.Image:
    """相関図。nodes に {id,label,note,x,y}、links に {from,to,label,kind} を書く。

    x,y は 0〜1 の割合で置く。kind は give（実線・矢印）/ weak（点線）。
    """
    nodes = {str(n["id"]): n for n in fig["nodes"]}
    w, h = typo.PANEL_W, 640
    im, d, top = _panel(w, h, fig.get("title", ""), band=fig.get("band", (20, 34, 64)))
    area_t, area_b = top, h - 40
    bw, bh = 320, 124

    def pos(n):
        x = 60 + float(n.get("x", 0.5)) * (w - 120 - bw)
        y = area_t + float(n.get("y", 0.5)) * (area_b - area_t - bh)
        return x, y

    # 線を先に引く
    for ln in fig.get("links", []):
        a, b = nodes.get(str(ln["from"])), nodes.get(str(ln["to"]))
        if not a or not b:
            continue
        ax, ay = pos(a)
        bx, by = pos(b)
        p1 = (ax + bw / 2, ay + bh / 2)
        p2 = (bx + bw / 2, by + bh / 2)
        weak = ln.get("kind") == "weak"
        col = (170, 176, 184) if weak else (90, 100, 112)
        if weak:
            # 点線
            steps = 28
            for i in range(steps):
                if i % 2:
                    continue
                t0, t1 = i / steps, (i + 1) / steps
                d.line([(p1[0] + (p2[0] - p1[0]) * t0, p1[1] + (p2[1] - p1[1]) * t0),
                        (p1[0] + (p2[0] - p1[0]) * t1, p1[1] + (p2[1] - p1[1]) * t1)],
                       fill=col, width=4)
        else:
            d.line([p1, p2], fill=col, width=5)
            ang = math.atan2(p2[1] - p1[1], p2[0] - p1[0])
            tipx = p2[0] - math.cos(ang) * (bw / 2 - 6)
            tipy = p2[1] - math.sin(ang) * (bh / 2 - 6)
            d.polygon([(tipx, tipy),
                       (tipx - math.cos(ang - 0.42) * 26, tipy - math.sin(ang - 0.42) * 26),
                       (tipx - math.cos(ang + 0.42) * 26, tipy - math.sin(ang + 0.42) * 26)],
                      fill=col)
        lab = str(ln.get("label", ""))
        if lab:
            mx, my = (p1[0] + p2[0]) / 2, (p1[1] + p2[1]) / 2
            f = F(typo.NOTE + 4, 800)
            tw = d.textlength(lab, font=f)
            d.rounded_rectangle([mx - tw / 2 - 14, my - 22, mx + tw / 2 + 14, my + 22],
                                radius=8, fill=(255, 255, 255, 240), outline=col, width=2)
            d.text((mx - tw / 2, my - 16), lab, font=f, fill=INK)

    # 箱をあとから
    for n in fig["nodes"]:
        x, y = pos(n)
        kind = n.get("kind", "normal")
        dark, light = {"focus": (AMBER_D, AMBER_L), "cost": (RED_D, RED_L),
                       "gain": (GREEN_D, GREEN_L)}.get(kind, (BLUE_D, BLUE_L))
        box = _bar((bw, bh), dark, light, radius=12)
        sh = Image.new("RGBA", (bw + 30, bh + 30), (0, 0, 0, 0))
        sh.paste((0, 0, 0, 130), (12, 14), box.split()[3])
        im.alpha_composite(sh.filter(ImageFilter.GaussianBlur(8)), (int(x) - 12, int(y) - 10))
        im.alpha_composite(box, (int(x), int(y)))
        d = ImageDraw.Draw(im)
        lab, f = str(n["label"]), F(typo.BODY)
        d.text((x + (bw - d.textlength(lab, font=f)) / 2, y + 18), lab, font=f, fill="white")
        note = str(n.get("note", ""))
        if note:
            nf = F(typo.NOTE, 700)
            d.text((x + (bw - d.textlength(note, font=nf)) / 2, y + 62), note, font=nf,
                   fill=(255, 255, 255, 220))
    _credit(d, fig.get("credit", ""), w, h)
    return im


def calc(fig: dict) -> Image.Image:
    """計算の板。式をそのまま見せる。『どう出した数字か』を隠さない。"""
    terms = fig["terms"]          # [{value, label}] 最後が答え
    w, h = typo.PANEL_W, 380
    im, d, top = _panel(w, h, fig.get("title", ""), band=fig.get("band", (20, 34, 64)))
    ops = fig.get("ops", ["×"] * (len(terms) - 2) + ["＝"])
    sizes = [52] * (len(terms) - 1) + [78]
    total_w = sum(_text_w(str(t["value"]), s) for t, s in zip(terms, sizes))
    total_w += sum(ImageDraw.Draw(Image.new("RGB", (1, 1))).textlength(o, font=F(typo.TITLE, 800)) + 56
                   for o in ops)
    x = (w - total_w) / 2 + 20
    y = top + 30
    for i, (t, size) in enumerate(zip(terms, sizes)):
        last = i == len(terms) - 1
        val = str(t["value"])
        col = (196, 122, 10) if last else INK
        put_number(d, val, x, y + (0 if last else 14), size, fill=col, shadow=last)
        lab = str(t.get("label", ""))
        if lab:
            lf = F(typo.NOTE + 2, 700)
            lw = d.textlength(lab, font=lf)
            vw = _text_w(val, size)
            d.text((x + (vw - lw) / 2, y + (96 if last else 88)), lab, font=lf, fill=INK_SUB)
        x += _text_w(val, size)
        if i < len(ops):
            of = F(typo.TITLE, 800)
            d.text((x + 24, y + 26), ops[i], font=of, fill=INK_SUB)
            x += d.textlength(ops[i], font=of) + 56
    note = str(fig.get("note", ""))
    if note:
        d.text((60, h - 40), note, font=F(typo.NOTE, 600), fill=INK_SUB)
    _credit(d, fig.get("credit", ""), w, h)
    return im


def stats(fig: dict) -> Image.Image:
    """数字を3つ並べる。1日／1年／生涯のように、同じものを尺度を変えて出す。"""
    items = fig["items"][:3]
    w, h = typo.PANEL_W, 340
    im, d, top = _panel(w, h, fig.get("title", ""), band=fig.get("band", (20, 34, 64)))
    cw = (w - 100) // max(len(items), 1)
    for i, it in enumerate(items):
        x = 50 + i * cw
        last = i == len(items) - 1
        if i:
            d.line([(x - 10, top + 10), (x - 10, h - 60)], fill="#E3E6EA", width=2)
        lab, lf = str(it.get("label", "")), F(typo.NOTE + 4, 800)
        d.text((x + (cw - d.textlength(lab, font=lf)) / 2, top), lab, font=lf, fill=INK_SUB)
        val, size = str(it["value"]), 72 if last else 60
        vw = _text_w(val, size)
        while vw > cw - 40 and size > 32:        # 枠に収まるまで縮める
            size -= 4
            vw = _text_w(val, size)
        put_number(d, val, x + (cw - vw) / 2, top + 46, size,
                   fill=(196, 122, 10) if last else INK, shadow=last)
        note = str(it.get("note", ""))
        if note:
            nf = F(typo.NOTE, 700)
            d.text((x + (cw - d.textlength(note, font=nf)) / 2, top + 150), note,
                   font=nf, fill=INK_SUB)
    _credit(d, fig.get("credit", ""), w, h)
    return im


def gauge(fig: dict) -> Image.Image:
    """半円のメーター。割合や達成度をひとつ見せる。"""
    value = float(fig.get("value", 0))
    mx = float(fig.get("max", 100))
    w, h = typo.PANEL_W, 560
    im, d, top = _panel(w, h, fig.get("title", ""), band=fig.get("band", (20, 34, 64)))
    cx, cy, r = w / 2, top + 290, 250
    th = 58
    d.arc([cx - r, cy - r, cx + r, cy + r], 180, 360, fill="#E1E4E9", width=th)
    ratio = max(0.0, min(value / mx if mx else 0, 1.0))
    if ratio > 0:
        d.arc([cx - r, cy - r, cx + r, cy + r], 180, 180 + 180 * ratio,
              fill=(196, 122, 10), width=th)
    val = str(fig.get("note", "{:.0f}%".format(ratio * 100)))
    size = 120
    put_number(d, val, cx - _text_w(val, size) / 2, cy - 150, size, fill=INK)
    lead = str(fig.get("lead", ""))
    if lead:                                   # 弧の外（下）に置く。重ねない
        lf = F(typo.BODY, 800)
        d.text((cx - d.textlength(lead, font=lf) / 2, cy + 86), lead, font=lf, fill=INK_SUB)
    lo, hi = str(fig.get("min_label", "0")), str(fig.get("max_label", int(mx)))
    lf2 = F(typo.NOTE, 700)
    d.text((cx - r - d.textlength(lo, font=lf2) / 2, cy + 40), lo, font=lf2, fill=INK_SUB)
    d.text((cx + r - d.textlength(hi, font=lf2) / 2, cy + 40), hi, font=lf2, fill=INK_SUB)
    _credit(d, fig.get("credit", ""), w, h)
    return im


KINDS = {"relation": relation, "calc": calc, "stats": stats, "gauge": gauge}


def draw(fig: dict, out: Path) -> Path:
    kind = fig.get("kind")
    if kind not in KINDS:
        raise SystemExit("知らない種類です: {}（使えるのは {}）".format(kind, " / ".join(KINDS)))
    im = KINDS[kind](fig)
    out.parent.mkdir(parents=True, exist_ok=True)
    im.save(out)
    return out
