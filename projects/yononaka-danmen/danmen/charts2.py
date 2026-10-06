# -*- coding: utf-8 -*-
"""ニュースで頻出するが、まだ無かった図を4つ。

    line       … 折れ線。推移を見せる
    people     … ピクトグラム。「10人のうち3人」を人の絵で
    japan      … 日本地図。都道府県別に塗る
    waterfall  … 増減の内訳。何が上げ、何が下げたか

板の作り（色帯＋金の線＋落ち影）は news.py と揃えてある。
"""
from __future__ import annotations

import json
import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

from danmen.news import F, PANEL, INK, INK_SUB, GOLD, put_number, _panel, _credit, _bar
from danmen.news import GREEN_D, GREEN_L, AMBER_D, AMBER_L, GRAY_D, GRAY_L, RED_D, RED_L
from danmen.news import BLUE_D, BLUE_L

GEO_JP = Path(r"C:/Users/なみ/dev/output/yononaka-danmen/assets/geo/japan.geojson")
_jp_cache = None


def line(fig: dict) -> Image.Image:
    """折れ線。点は丸、最後だけ大きく。面を薄く塗る。"""
    items = fig["items"]
    w, h = 1180, 560
    im, d, top = _panel(w, h, fig.get("title", ""), band=fig.get("band", (20, 34, 64)))
    vals = [float(i["value"]) for i in items]
    mx, mn = max(vals), min(vals)
    span = (mx - mn) or 1
    plot_l, plot_r = 110, w - 60
    plot_t, plot_b = top + 20, h - 90
    # 薄い横線（目盛りの代わり）
    for k in range(4):
        gy = plot_t + (plot_b - plot_t) * k / 3
        d.line([(plot_l, gy), (plot_r, gy)], fill="#E7EAEE", width=2)
    step = (plot_r - plot_l) / max(len(items) - 1, 1)
    pts = []
    for i, v in enumerate(vals):
        x = plot_l + step * i
        y = plot_b - (v - mn) / span * (plot_b - plot_t) * 0.86
        pts.append((x, y))
    # 面を薄く
    poly = pts + [(pts[-1][0], plot_b), (pts[0][0], plot_b)]
    layer = Image.new("RGBA", im.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).polygon(poly, fill=(24, 164, 138, 46))
    im.alpha_composite(layer)
    d = ImageDraw.Draw(im)
    d.line(pts, fill=(16, 140, 118), width=7, joint="curve")
    for i, (x, y) in enumerate(pts):
        last = i == len(pts) - 1
        r = 15 if last else 9
        d.ellipse([x - r, y - r, x + r, y + r], fill=(16, 140, 118) if last else (255, 255, 255),
                  outline=(16, 140, 118), width=4)
        lab = str(items[i].get("label", ""))
        if lab:
            f = F(24, 700)
            d.text((x - d.textlength(lab, font=f) / 2, plot_b + 16), lab, font=f, fill=INK_SUB)
        note = str(items[i].get("note", ""))
        if note and (last or items[i].get("show")):
            size = 44 if last else 32
            probe = ImageDraw.Draw(Image.new("RGB", (1, 1)))
            tw = sum(probe.textlength(m.group(0),
                     font=F(size) if m.group(1) else F(int(size * 0.58), 800))
                     for m in re.finditer(r"(\d+(?:[,.]\d+)*)|([^\d]+)", note))
            put_number(d, note, x - tw / 2, y - size - 34, size,
                       fill=INK if last else INK_SUB)
    _credit(d, fig.get("credit", ""), w, h)
    return im


def people(fig: dict) -> Image.Image:
    """ピクトグラム。10人（または n 人）のうち何人かを色で示す。"""
    total = int(fig.get("total", 10))
    filled = float(fig.get("filled", 3))
    per_row = int(fig.get("per_row", 10))
    rows = (total + per_row - 1) // per_row
    w, h = 1120, 180 + rows * 150
    im, d, top = _panel(w, h, fig.get("title", ""), band=fig.get("band", (20, 34, 64)))
    size = 96
    gap = (w - 120 - per_row * size) // max(per_row - 1, 1)
    for i in range(total):
        r, c = divmod(i, per_row)
        x = 60 + c * (size + gap)
        y = top + r * 150
        on = i < filled
        col = (196, 122, 10) if on else (205, 209, 214)
        # 頭と体（ピクトグラム）
        d.ellipse([x + size * 0.28, y, x + size * 0.72, y + size * 0.42], fill=col)
        d.rounded_rectangle([x + size * 0.16, y + size * 0.48, x + size * 0.84, y + size * 1.12],
                            radius=int(size * 0.22), fill=col)
    lead = str(fig.get("lead", ""))
    if lead:
        d.text((60, top + rows * 150 - 10), lead, font=F(34, 800), fill=INK)
    _credit(d, fig.get("credit", ""), w, h)
    return im


def _jp() -> dict:
    global _jp_cache
    if _jp_cache is None:
        _jp_cache = json.loads(GEO_JP.read_text(encoding="utf-8"))
    return _jp_cache


def japan(fig: dict) -> Image.Image:
    """日本地図。marks に {name: 都道府県名, color, note} を書くとその県を塗る。"""
    w, h = 1180, 700
    im, d, top = _panel(w, h, fig.get("title", ""), band=fig.get("band", (20, 34, 64)))
    marks = {str(m["name"]): m for m in fig.get("marks", [])}
    lon0, lon1, lat0, lat1 = 122.0, 146.5, 24.0, 46.0   # 沖縄・先島まで入れる
    legend_w = 320
    mw, mh = w - 120 - legend_w, h - top - 60
    ox, oy = 60, top

    def xy(lon, lat):
        return (ox + (lon - lon0) / (lon1 - lon0) * mw,
                oy + (lat1 - lat) / (lat1 - lat0) * mh)

    centers = {}            # 印を打つ県の、だいたいの真ん中
    for feat in _jp()["features"]:
        name = feat["properties"].get("nam_ja", "")
        mark = marks.get(name) or marks.get(name.replace("県", "").replace("府", "").replace("都", ""))
        fill = mark.get("color", "#0E8C77") if mark else "#D7D2C6"
        geom = feat["geometry"]
        polys = geom["coordinates"] if geom["type"] == "MultiPolygon" else [geom["coordinates"]]
        biggest, best = None, -1
        for poly in polys:
            ring = poly[0]
            pts = [xy(float(a), float(b)) for a, b in ring
                   if lon0 <= float(a) <= lon1 and lat0 <= float(b) <= lat1]
            if len(pts) >= 3:
                d.polygon(pts, fill=fill, outline="#FFFFFF")
                if len(pts) > best:
                    best, biggest = len(pts), pts
        if mark and biggest:
            cx = sum(p[0] for p in biggest) / len(biggest)
            cy = sum(p[1] for p in biggest) / len(biggest)
            centers[name] = (cx, cy, fill)

    # 小さい県は塗っても見えないので、印と引き出し線を打つ
    for name, (cx, cy, col) in centers.items():
        d.ellipse([cx - 13, cy - 13, cx + 13, cy + 13], fill=col, outline="#FFFFFF", width=3)
        halo = Image.new("RGBA", im.size, (0, 0, 0, 0))
        ImageDraw.Draw(halo).ellipse([cx - 26, cy - 26, cx + 26, cy + 26],
                                     outline=col + "AA" if isinstance(col, str) else col, width=4)
        im.alpha_composite(halo.filter(ImageFilter.GaussianBlur(3)))
    d = ImageDraw.Draw(im)
    y = top + 10
    for m in fig.get("marks", []):
        col = m.get("color", "#0E8C77")
        d.rounded_rectangle([w - legend_w + 40, y, w - legend_w + 66, y + 24], radius=5, fill=col)
        d.text((w - legend_w + 82, y - 4), str(m.get("label", m["name"])), font=F(27), fill=INK)
        note = str(m.get("note", ""))
        if note:
            d.text((w - legend_w + 82, y + 28), note, font=F(21, 600), fill=INK_SUB)
        y += 76
    _credit(d, fig.get("credit", "地図: dataofjapan/land"), w, h)
    return im


def waterfall(fig: dict) -> Image.Image:
    """増減の内訳。何が上げ、何が下げたか。最後に合計。"""
    items = fig["items"]
    w, h = 1180, 520
    im, d, top = _panel(w, h, fig.get("title", ""), band=fig.get("band", (20, 34, 64)))
    base = float(fig.get("base", 0))
    running = base
    tops = [base]
    for it in items:
        running += float(it["value"])
        tops.append(running)
    mx = max(max(tops), base) or 1
    n = len(items) + 2          # もと／各項目／合計
    cw = (w - 120 - (n - 1) * 40) // max(n, 1)
    plot_t, plot_b = top + 30, h - 140
    def ypos(v):
        return plot_b - (v / mx) * (plot_b - plot_t)
    x = 60
    prev = base
    # はじまり
    bar = _bar((cw, int(plot_b - ypos(base))), GRAY_D, GRAY_L)
    im.alpha_composite(bar, (x, int(ypos(base))))
    d = ImageDraw.Draw(im)
    d.text((x, plot_b + 16), str(fig.get("base_label", "もと")), font=F(26, 800), fill=INK_SUB)
    put_number(d, str(fig.get("base_note", base)), x, plot_b + 54, 34, fill=INK_SUB)
    x += cw + 40
    for it in items:
        v = float(it["value"])
        up = v >= 0
        y0, y1 = ypos(prev), ypos(prev + v)
        topy, hgt = min(y0, y1), abs(y1 - y0)
        dark, light = (RED_D, RED_L) if up else (BLUE_D, BLUE_L)
        bar = _bar((cw, max(int(hgt), 6)), dark, light)
        im.alpha_composite(bar, (x, int(topy)))
        d = ImageDraw.Draw(im)
        d.line([(x - 40, y0), (x, y0)], fill="#C9CDD3", width=3)
        d.text((x, plot_b + 16), str(it["label"]), font=F(26, 800), fill=INK_SUB)
        mark = "＋" if up else "−"
        put_number(d, mark + str(it.get("note", abs(v))), x, int(topy) - 48, 34,
                   fill=(176, 40, 32) if up else (24, 86, 170))
        prev += v
        x += cw + 40
    # 合計
    bar = _bar((cw, int(plot_b - ypos(prev))), AMBER_D, AMBER_L)
    im.alpha_composite(bar, (x, int(ypos(prev))))
    d = ImageDraw.Draw(im)
    d.text((x, plot_b + 16), str(fig.get("total_label", "いま")), font=F(26, 800), fill=INK)
    put_number(d, str(fig.get("total_note", prev)), x, plot_b + 50, 40, fill=INK)
    _credit(d, fig.get("credit", ""), w, h)
    return im


KINDS = {"line": line, "people": people, "japan": japan, "waterfall": waterfall}


def draw(fig: dict, out: Path) -> Path:
    kind = fig.get("kind")
    if kind not in KINDS:
        raise SystemExit("知らない種類です: {}（使えるのは {}）".format(kind, " / ".join(KINDS)))
    im = KINDS[kind](fig)
    out.parent.mkdir(parents=True, exist_ok=True)
    im.save(out)
    return out
