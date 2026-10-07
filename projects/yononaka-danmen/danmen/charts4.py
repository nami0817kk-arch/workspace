# -*- coding: utf-8 -*-
"""図の追加、5種。

    newspaper   … 新聞記事風。見出し＋リード＋写真。報じられ方を見せる
    donut       … ドーナツ。中央に数字を置く
    schedule    … いつ何が起きるか。日付と予定の表
    checklist   … 条件を満たすかどうか。○×で並べる
    thermometer … 縦のゲージ。目標までの距離

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
SERIES = [(GREEN_D, GREEN_L), (AMBER_D, AMBER_L), (BLUE_D, BLUE_L), (GRAY_D, GRAY_L)]


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


def newspaper(fig: dict) -> Image.Image:
    """新聞記事風。『どう報じられたか』を見せる。引用の範囲で使う。"""
    w, h = typo.PANEL_W, 620
    im, d, top = _panel(w, h, fig.get("title", "報じられ方"), band=fig.get("band", (38, 38, 42)))
    pad = 58
    # 紙の地色と、新聞らしい細い罫
    d.rectangle([pad, top, w - 20, h - 20], fill=(250, 249, 244))
    d.line([(pad, top + 2), (w - 20, top + 2)], fill=(90, 90, 96), width=4)
    head = str(fig.get("head", ""))
    hf = F(56)
    y = top + 28
    for ln in _wrap(d, head, hf, w - pad * 2 - 40)[:3]:
        d.text((pad + 20, y), ln, font=hf, fill=(24, 24, 28))
        y += 70
    d.line([(pad + 20, y + 6), (w - 60, y + 6)], fill=(170, 170, 176), width=2)
    y += 26
    photo = fig.get("photo")
    body_w = w - pad * 2 - 40
    if photo and Path(str(photo)).exists():
        pic = Image.open(str(photo)).convert("RGB")
        pic.thumbnail((430, 300))
        im.paste(pic, (w - 60 - pic.width, y))
        d.rectangle([w - 60 - pic.width, y, w - 60, y + pic.height], outline=(180, 180, 186), width=2)
        body_w = w - pad * 2 - 40 - pic.width - 40
    bf = F(27, 600)
    for ln in _wrap(d, str(fig.get("body", "")), bf, body_w)[:7]:
        d.text((pad + 20, y), ln, font=bf, fill=(40, 40, 46))
        y += 40
    paper = str(fig.get("paper", ""))
    if paper:
        d.text((pad + 20, h - 54), paper, font=F(22, 700), fill=INK_SUB)
    _credit(d, fig.get("credit", ""), w, h)
    return im


def donut(fig: dict) -> Image.Image:
    """ドーナツ。真ん中に数字を置けるのが円グラフとの違い。"""
    items = fig["items"][:5]
    w, h = typo.PANEL_W, 520
    im, d, top = _panel(w, h, fig.get("title", ""), band=fig.get("band", (20, 34, 64)))
    total = sum(float(i["value"]) for i in items) or 1
    cx, cy, r = int(w * 0.22), top + 190, 182
    inner = int(r * 0.58)
    start = -90.0
    for n, it in enumerate(items):
        ang = 360 * float(it["value"]) / total
        dark, light = SERIES[n % len(SERIES)]
        d.pieslice([cx - r, cy - r, cx + r, cy + r], start, start + ang,
                   fill=light, outline=(255, 255, 255), width=4)
        start += ang
    d.ellipse([cx - inner, cy - inner, cx + inner, cy + inner], fill=(252, 252, 250))
    center = str(fig.get("center", ""))
    if center:
        size = 60
        while _text_w(center, size) > inner * 1.7 and size > 26:
            size -= 4
        put_number(d, center, cx - _text_w(center, size) / 2, cy - size * 0.62, size, fill=INK)
    sub = str(fig.get("center_sub", ""))
    if sub:
        sf = F(22, 700)
        d.text((cx - d.textlength(sub, font=sf) / 2, cy + 30), sub, font=sf, fill=INK_SUB)
    y = top + 30
    for n, it in enumerate(items):
        _, light = SERIES[n % len(SERIES)]
        lx = int(w * 0.44)
        d.rounded_rectangle([lx, y + 4, lx + 30, y + 36], radius=6, fill=light)
        d.text((lx + 52, y - 2), str(it["label"]), font=F(typo.BODY), fill=INK)
        pct = "{:.0f}%".format(float(it["value"]) / total * 100)
        pf = F(typo.BODY)
        d.text((w - d.textlength(pct, font=pf) - 40, y - 2), pct, font=pf, fill=INK_SUB)
        note = str(it.get("note", ""))
        if note:
            d.text((lx + 52, y + 44), note, font=F(typo.NOTE, 600), fill=INK_SUB)
        y += 92
    _credit(d, fig.get("credit", ""), w, h)
    return im


def schedule(fig: dict) -> Image.Image:
    """いつ何が起きるか。これからの予定を日付つきで並べる。"""
    items = fig["items"]
    w, h = typo.PANEL_W, 150 + len(items) * 92
    im, d, top = _panel(w, h, fig.get("title", ""), band=fig.get("band", (20, 34, 64)))
    x_line = int(w * 0.24)
    d.line([(x_line, top), (x_line, h - 50)], fill="#DFE3E8", width=4)
    y = top
    for n, it in enumerate(items):
        done = bool(it.get("done"))
        now = bool(it.get("now"))
        col = (196, 122, 10) if now else ((16, 140, 118) if done else (176, 182, 190))
        d.text((58, y + 10), str(it["when"]), font=F(typo.BODY, 900 if now else 700),
               fill=INK if now else INK_SUB)
        d.ellipse([x_line - 14, y + 16, x_line + 14, y + 44], fill=col,
                  outline=(255, 255, 255), width=4)
        if now:
            halo = Image.new("RGBA", im.size, (0, 0, 0, 0))
            ImageDraw.Draw(halo).ellipse([x_line - 26, y + 4, x_line + 26, y + 56],
                                         outline=(196, 122, 10), width=5)
            im.alpha_composite(halo.filter(ImageFilter.GaussianBlur(4)))
            d = ImageDraw.Draw(im)
        d.text((x_line + 56, y + 8), str(it["what"]), font=F(typo.BODY, 900 if now else 700),
               fill=INK if (now or done) else INK_SUB)
        note = str(it.get("note", ""))
        if note:
            d.text((x_line + 56, y + 58), note, font=F(typo.NOTE, 600), fill=INK_SUB)
        y += 92
    _credit(d, fig.get("credit", ""), w, h)
    return im


def checklist(fig: dict) -> Image.Image:
    """条件を満たすかどうか。○×で並べる。「なぜ安くならないか」の整理に使う。"""
    items = fig["items"]
    w, h = typo.PANEL_W, 150 + len(items) * 96
    im, d, top = _panel(w, h, fig.get("title", ""), band=fig.get("band", (20, 34, 64)))
    y = top
    for it in items:
        ok = bool(it.get("ok"))
        col = (16, 140, 118) if ok else (192, 57, 43)
        # 塗りつぶした丸に、白でしるしを描く（輪郭だけだと小さい画面で見えない）
        d.ellipse([58, y + 6, 58 + 56, y + 62], fill=col)
        cx, cy = 58 + 28, y + 34
        if ok:
            d.line([(cx - 14, cy + 1), (cx - 4, cy + 12), (cx + 15, cy - 12)],
                   fill="white", width=7, joint="curve")
        else:
            d.line([(cx - 12, cy - 12), (cx + 12, cy + 12)], fill="white", width=7)
            d.line([(cx + 12, cy - 12), (cx - 12, cy + 12)], fill="white", width=7)
        d.text((158, y + 2), str(it["label"]), font=F(typo.BODY), fill=INK)
        note = str(it.get("note", ""))
        if note:
            d.text((158, y + 58), note, font=F(typo.NOTE, 600), fill=INK_SUB)
        y += 96
    _credit(d, fig.get("credit", ""), w, h)
    return im


def thermometer(fig: dict) -> Image.Image:
    """横のゲージ。目標までどれだけ来ているかを見せる。

    もとは縦の柱だったが、16:9 の画面に置くと左右が大きく空いた（2026-10-07）。
    横に寝かせると、同じ中身で文字も大きくできる。
    """
    value = float(fig.get("value", 0))
    goal = float(fig.get("goal", 100))
    w, h = typo.PANEL_W, 500
    im, d, top = _panel(w, h, fig.get("title", ""), band=fig.get("band", (20, 34, 64)))
    bx0, bx1 = 110, w - 110
    by, bh = top + 96, 96
    d.rounded_rectangle([bx0, by, bx1, by + bh], radius=bh // 2, fill="#E3E6EA")
    ratio = max(0.0, min(value / goal if goal else 0, 1.0))
    fill_w = int((bx1 - bx0) * ratio)
    if fill_w > 20:
        bar = _bar((fill_w, bh), AMBER_D, AMBER_L, radius=bh // 2)
        im.alpha_composite(bar, (bx0, by))
    d = ImageDraw.Draw(im)
    # いまの値は、棒の先の上に置く
    val = str(fig.get("note", value))
    vx = bx0 + fill_w
    d.line([(vx, by - 24), (vx, by + bh + 24)], fill=(196, 122, 10), width=5)
    vw = _text_w(val, typo.TITLE + 14)
    put_number(d, val, min(max(vx - vw / 2, bx0), bx1 - vw), by - typo.TITLE - 44,
               typo.TITLE + 14, fill=INK)
    lab = str(fig.get("label", ""))
    if lab:
        lf = F(typo.NOTE, 700)
        d.text((min(max(vx - d.textlength(lab, font=lf) / 2, bx0), bx1 - 100),
                by + bh + 32), lab, font=lf, fill=INK_SUB)
    # 目標は右端に
    gl = str(fig.get("goal_note", goal))
    gf = F(typo.BODY, 800)
    gt = "目標 " + gl
    d.text((bx1 - d.textlength(gt, font=gf), by + bh + 32), gt, font=gf, fill=INK_SUB)
    # 0 は左端に
    zf = F(typo.NOTE, 700)
    d.text((bx0, by + bh + 32), str(fig.get("base_label", "0")), font=zf, fill=INK_SUB)
    _credit(d, fig.get("credit", ""), w, h)
    return im


KINDS = {"newspaper": newspaper, "donut": donut, "schedule": schedule,
         "checklist": checklist, "thermometer": thermometer}


def draw(fig: dict, out: Path) -> Path:
    kind = fig.get("kind")
    if kind not in KINDS:
        raise SystemExit("知らない種類です: {}（使えるのは {}）".format(kind, " / ".join(KINDS)))
    im = KINDS[kind](fig)
    out.parent.mkdir(parents=True, exist_ok=True)
    im.save(out)
    return out
