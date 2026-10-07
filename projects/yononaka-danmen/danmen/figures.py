# -*- coding: utf-8 -*-
"""台本の figure から、画面の真ん中に出す「白い板」を描く。

種類は8つ。
    stack    … 積み上げ（何でできているか）
    compare  … 比べる（よその国はどうか）
    timeline … 年表（いつ、誰が決めたか）
    flow     … 流れ図（誰が払い、どこへ行くか）
    bars     … まとめの板（理由を番号で）
    hero     … ひとつの数字を大きく見せる（山場で使う）
    table    … 比べる表（1974年と2026年、日本と他国）
    pie      … 割合（3〜5個まで）

意匠の決まり（2026-10-06 に固めた）
  ・板は白、角丸18、金の細線1本、落ち影つき
  ・書体は Noto Sans JP の可変フォント。見出しは 900、添えは 500
  ・色は並び順で固定（dataviz の検証を通したもの）。番号で色を変えない
  ・項目に icon を書くと、assets/icons の絵を左に添える
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

from danmen import typo

CARD = (255, 255, 255, 248)
INK = "#141C26"
INK_SUB = "#6B7684"
RULE = "#E4E7EB"
GOLD = "#E7B93F"
SERIES = ["#0E8C77", "#C07A0C", "#4A63D0"]
MUTED = "#B6B0A3"

FONT_PATH = "C:/Windows/Fonts/NotoSansJP-VF.ttf"
ICON_DIR = Path(r"C:/Users/なみ/dev/output/yononaka-danmen/assets/icons")


def F(size: int, weight: int = 900) -> ImageFont.FreeTypeFont:
    # 読めない大きさは作らない。1920 の画面での 28px が、スマホで 5.7pt の下限
    size = max(int(size), typo.MIN_PX)
    f = ImageFont.truetype(FONT_PATH, size)
    try:
        f.set_variation_by_axes([weight])
    except Exception:
        pass
    return f


def _icon(name: str, box: int):
    if not name:
        return None
    p = ICON_DIR / (name + ".png")
    if not p.exists():
        return None
    im = Image.open(p).convert("RGBA")
    im.thumbnail((box, box))
    return im


def _card(w: int, h: int, title: str):
    """板。**news の板と同じ作りに揃えた**（2026-10-07）。

    もとは白地に細い罫線の見出しで、他の図（濃紺の帯＋金の線）と見た目が
    違っていた。同じ動画の中に2種類の板が出ると、作りが揃っていないと感じる。
    戻り値は (画像, 描くもの, 中身を始める y)。
    """
    from danmen.news import _panel
    # 帯のぶん中身が下がるので、高さを 34 だけ足す（元の見出しとの差）
    return _panel(w, h + 34, title)


def _note(d, text: str, x: int, y: int) -> None:
    if text:
        d.text((x, y), text, font=F(typo.NOTE, 600), fill=INK_SUB)


def stack(fig: dict) -> Image.Image:
    items = fig["items"]
    w, h = typo.PANEL_W, 150 + len(items) * 104
    im, d, top = _card(w, h, fig.get("title", ""))
    total = max(float(i["value"]) for i in items) or 1
    y = top
    for n, it in enumerate(items):
        col = SERIES[n % len(SERIES)]
        ic = _icon(str(it.get("icon", "")), 84)
        x = 58
        if ic:
            im.alpha_composite(ic, (x, y + (92 - ic.height) // 2))
            x += 106
        bw = int((w - x - 420) * float(it["value"]) / total)
        d.rounded_rectangle([x, y + 8, x + max(bw, 6), y + 84], radius=8, fill=col)
        label, f = str(it["label"]), F(typo.BODY)
        if d.textlength(label, font=f) + 36 <= bw:
            d.text((x + 18, y + 26), label, font=f, fill="white")
        else:
            d.text((x + max(bw, 6) + 16, y + 26), label, font=f, fill=col)
        note, nf = str(it.get("note", "")), F(typo.VALUE)
        if note:
            d.text((w - d.textlength(note, font=nf) + 10, y + 22), note, font=nf, fill=INK)
        y += 104
    _note(d, fig.get("note", ""), 58, h - 4)
    return im


def compare(fig: dict) -> Image.Image:
    items = fig["items"]
    focus = str(fig.get("focus", items[0]["label"]))
    w, h = typo.PANEL_W, 140 + len(items) * 92
    im, d, top = _card(w, h, fig.get("title", ""))
    mx = max(float(i["value"]) for i in items) or 1
    y = top
    for it in items:
        is_focus = str(it["label"]) == focus
        col = SERIES[0] if is_focus else MUTED
        d.text((58, y + 14), str(it["label"]), font=F(30, 900 if is_focus else 700), fill=INK)
        bx = int(w * 0.26)
        bw = int((w - bx - 300) * float(it["value"]) / mx)
        d.rounded_rectangle([bx, y + 8, bx + max(bw, 4), y + 66], radius=6, fill=col)
        note = str(it.get("note", it["value"]))
        d.text((bx + max(bw, 4) + 20, y + 14), note, font=F(typo.BODY, 800),
               fill=INK if is_focus else INK_SUB)
        y += 92
    _note(d, fig.get("note", ""), 58, h - 4)
    return im


def timeline(fig: dict) -> Image.Image:
    items = fig["items"]
    w, h = typo.PANEL_W, 400
    im, d, top = _card(w, h, fig.get("title", ""))
    y = top + 160
    x0, x1 = 150, w - 110
    d.line([(x0, y), (x1, y)], fill=RULE, width=5)
    step = (x1 - x0) / max(len(items) - 1, 1)
    for n, it in enumerate(items):
        x = int(x0 + step * n)
        col = SERIES[n % len(SERIES)]
        d.ellipse([x - 13, y - 13, x + 13, y + 13], fill=col)
        lab, f = str(it["label"]), F(31)
        d.text((x - d.textlength(lab, font=f) / 2, y + 26), lab, font=f, fill=INK)
        note = str(it.get("note", ""))
        if note:
            width = min(step - 40, 210)
            lines, cur = [], ""
            for ch in note:
                cur += ch
                if d.textlength(cur, font=F(typo.NOTE, 600)) > width:
                    lines.append(cur)
                    cur = ""
            if cur:
                lines.append(cur)
            for i, ln in enumerate(lines[:4]):
                tw = d.textlength(ln, font=F(typo.NOTE, 600))
                d.text((x - tw / 2, y - 54 - (len(lines[:4]) - 1 - i) * 30), ln,
                       font=F(typo.NOTE, 600), fill=INK_SUB)
    return im


def flow(fig: dict) -> Image.Image:
    items = fig["items"]
    n = len(items)
    w, h = typo.PANEL_W, 420
    im, d, top = _card(w, h, fig.get("title", ""))
    bw = max((w - 140 - (n - 1) * 80) // max(n, 1), 220)
    y = top + 16
    x = 58
    for i, it in enumerate(items):
        col = SERIES[i % len(SERIES)]
        d.rounded_rectangle([x, y, x + bw, y + 152], radius=12, fill=col)
        ic = _icon(str(it.get("icon", "")), 60)
        if ic:
            im.alpha_composite(ic, (x + 20, y + 10))
            d.text((x + 20, y + 88), str(it["label"]), font=F(typo.BODY), fill="white")
        else:
            d.text((x + 20, y + 52), str(it["label"]), font=F(typo.BODY), fill="white")
        _note(d, str(it.get("note", "")), x, y + 170)
        if i < n - 1:
            ax = x + bw + 16
            d.line([(ax, y + 76), (ax + 44, y + 76)], fill=INK_SUB, width=5)
            d.polygon([(ax + 44, y + 62), (ax + 44, y + 90), (ax + 68, y + 76)], fill=INK_SUB)
        x += bw + 80
    return im


def bars(fig: dict) -> Image.Image:
    items = fig["items"]
    w, h = typo.PANEL_W, 120 + len(items) * 116
    im, d, top = _card(w, h, fig.get("title", ""))
    y = top
    for n, it in enumerate(items, 1):
        col = SERIES[(n - 1) % len(SERIES)]
        d.ellipse([58, y, 112, y + 54], fill=col)
        num, f = str(n), F(30)
        d.text((58 + 27 - d.textlength(num, font=f) / 2, y + 8), num, font=f, fill="white")
        d.text((140, y - 2), str(it["label"]), font=F(typo.BODY), fill=INK)
        _note(d, str(it.get("note", "")), 140, y + 54)
        y += 116
    return im


def hero(fig: dict) -> Image.Image:
    """ひとつの数字を大きく見せる。山場で使う。"""
    w, h = typo.PANEL_W, 360
    im, d, top = _card(w, h, fig.get("title", ""))
    value = str(fig.get("value", ""))
    f = F(130)
    d.text(((w - d.textlength(value, font=f)) / 2 + 24, top + 10), value, font=f, fill=SERIES[1])
    sub = str(fig.get("sub", ""))
    if sub:
        sf = F(34, 800)
        d.text(((w - d.textlength(sub, font=sf)) / 2 + 24, top + 170), sub, font=sf, fill=INK)
    _note(d, fig.get("note", ""), 58, h - 4)
    return im


def table(fig: dict) -> Image.Image:
    """比べる表。items は {label, values:[...]}、cols は見出しの並び。"""
    cols = fig.get("cols", [])
    items = fig["items"]
    w, h = typo.PANEL_W, 180 + len(items) * (typo.ROW + 14)
    im, d, top = _card(w, h, fig.get("title", ""))
    label_w = int(w * 0.32)
    cw = (w - label_w - 80) // max(len(cols), 1)
    for i, c in enumerate(cols):
        d.text((label_w + i * cw, top), str(c), font=F(typo.NOTE + 4, 800), fill=INK_SUB)
    top += 44
    d.line([(58, top), (w, top)], fill=RULE, width=2)
    y = top + 14
    for n, it in enumerate(items):
        if n % 2 == 0:
            d.rectangle([48, y - 10, w + 10, y + typo.ROW], fill="#F2F4F7")
        d.text((58, y + 4), str(it["label"]), font=F(typo.BODY, 800), fill=INK)
        for i, v in enumerate(it.get("values", [])):
            strong = bool(it.get("strong")) and i == len(it.get("values", [])) - 1
            d.text((label_w + i * cw, y + 2), str(v),
                   font=F(typo.BODY + (4 if strong else 0), 900 if strong else 700),
                   fill=SERIES[1] if strong else INK)
        y += typo.ROW + 14
    return im


def pie(fig: dict) -> Image.Image:
    items = fig["items"][:5]
    w, h = typo.PANEL_W, 460
    im, d, top = _card(w, h, fig.get("title", ""))
    total = sum(float(i["value"]) for i in items) or 1
    cx, cy, r = int(w * 0.21), top + 160, 150
    start = -90.0
    for n, it in enumerate(items):
        ang = 360 * float(it["value"]) / total
        d.pieslice([cx - r, cy - r, cx + r, cy + r], start, start + ang,
                   fill=SERIES[n % len(SERIES)], outline=(255, 255, 255), width=4)
        start += ang
    y = top + 20
    for n, it in enumerate(items):
        col = SERIES[n % len(SERIES)]
        lx = int(w * 0.44)
        d.rounded_rectangle([lx, y + 4, lx + 30, y + 34], radius=6, fill=col)
        d.text((lx + 52, y - 2), str(it["label"]), font=F(typo.BODY), fill=INK)
        pct = "{:.0f}%".format(float(it["value"]) / total * 100)
        pf = F(typo.BODY)
        d.text((w - d.textlength(pct, font=pf) + 10, y - 2), pct, font=pf, fill=INK_SUB)
        _note(d, str(it.get("note", "")), lx + 52, y + 46)
        y += 92
    return im


KINDS = {"stack": stack, "compare": compare, "timeline": timeline, "flow": flow,
         "bars": bars, "hero": hero, "table": table, "pie": pie}


def draw(fig: dict, out: Path) -> Path:
    kind = fig.get("kind")
    if kind not in KINDS:
        raise SystemExit("図の種類「{}」は知りません。使えるのは {}".format(kind, " / ".join(KINDS)))
    im = KINDS[kind](fig)
    out.parent.mkdir(parents=True, exist_ok=True)
    im.save(out)
    return out


# --- 地図（Natural Earth・パブリックドメイン） -----------------------------

GEO = Path(r"C:/Users/なみ/dev/output/yononaka-danmen/assets/geo/ne_110m_admin_0_countries.geojson")
_geo_cache: dict | None = None


def _geo() -> dict:
    global _geo_cache
    if _geo_cache is None:
        import json
        _geo_cache = json.loads(GEO.read_text(encoding="utf-8"))
    return _geo_cache


def world(fig: dict) -> Image.Image:
    """世界地図。marks に {name, color, note} を書くと、その国を塗って札を出す。

    name は Natural Earth の英語名（Japan / United States of America / Germany …）。
    投影は正距円筒（素直に経度緯度を置く）。南極は切る。
    """
    w, h = typo.PANEL_W, 620
    im, d, top = _card(w, h, fig.get("title", ""))
    marks = {str(m["name"]): m for m in fig.get("marks", [])}

    # 描く範囲（南極を除く）
    lon0, lon1, lat0, lat1 = -180.0, 180.0, -58.0, 84.0
    legend_w = 330
    mw, mh = w - 80 - legend_w, h - top - 40
    ox, oy = 58, top

    def xy(lon: float, lat: float) -> tuple[float, float]:
        return (ox + (lon - lon0) / (lon1 - lon0) * mw,
                oy + (lat1 - lat) / (lat1 - lat0) * mh)

    for feat in _geo()["features"]:
        name = feat["properties"].get("NAME")
        mark = marks.get(name)
        fill = mark.get("color", SERIES[0]) if mark else "#D7D2C6"
        geom = feat["geometry"]
        polys = geom["coordinates"] if geom["type"] == "MultiPolygon" else [geom["coordinates"]]
        for poly in polys:
            ring = poly[0]
            pts = [xy(float(a), float(b)) for a, b in ring
                   if -180 <= float(a) <= 180 and lat0 <= float(b) <= lat1]
            if len(pts) >= 3:
                d.polygon(pts, fill=fill, outline="#FFFFFF")
                if mark:
                    d.line(pts + [pts[0]], fill="#FFFFFF", width=3)

    # 札（塗った国の名前と数字）
    y = top + 10
    for m in fig.get("marks", []):
        label = str(m.get("label", m["name"]))
        col = m.get("color", SERIES[0])
        d.rounded_rectangle([w - legend_w + 40, y, w - legend_w + 66, y + 24], radius=5, fill=col)
        d.text((w - legend_w + 82, y - 4), label, font=F(typo.NOTE), fill=INK)
        note = str(m.get("note", ""))
        if note:
            d.text((w - legend_w + 82, y + 28), note, font=F(typo.NOTE, 600), fill=INK_SUB)
        y += 72
    _note(d, fig.get("note", "地図: Natural Earth（パブリックドメイン）"), 58, h - 4)
    return im


KINDS["world"] = world


# --- 足した板（2026-10-06 夜） --------------------------------------------

RED = "#C0392B"          # 問題・警告のときだけ使う。系列の色としては使わない


def photo(fig: dict) -> Image.Image:
    """写真を1枚、札つきで見せる板。人物や現場を出すときに使う。"""
    src = Path(str(fig.get("src", "")))
    w, h = typo.PANEL_W, 620
    im, d, top = _card(w, h, fig.get("title", ""))
    if src.exists():
        pic = Image.open(src).convert("RGB")
        bw, bh = w - 116, h - top - 120
        pic.thumbnail((bw, bh))
        x = (w - pic.width) // 2 + 24
        im.paste(pic, (x, top + 10))
        d.rectangle([x, top + 10, x + pic.width, top + 10 + pic.height], outline="#D9DCE1", width=2)
        cap = str(fig.get("caption", ""))
        if cap:
            d.text((x, top + 24 + pic.height), cap, font=F(typo.NOTE, 800), fill=INK)
        src_note = str(fig.get("credit", ""))
        if src_note:
            d.text((x, top + 64 + pic.height), src_note, font=F(typo.NOTE, 500), fill=INK_SUB)
    else:
        d.text((58, top + 20), "（写真が見つかりません: {}）".format(src), font=F(typo.NOTE, 600), fill=RED)
    return im


def convert(fig: dict) -> Image.Image:
    """換算の板。「1回ぶん」を「1年ぶん」に直して、自分ごとに引き戻す。

    items は {label, value, note} を2〜3個。矢印でつなぐ。
    """
    items = fig["items"]
    w, h = typo.PANEL_W, 380
    im, d, top = _card(w, h, fig.get("title", ""))
    n = len(items)
    bw = (w - 120 - (n - 1) * 90) // max(n, 1)
    x, y = 58, top + 20
    for i, it in enumerate(items):
        last = i == n - 1
        col = SERIES[1] if last else "#8C97A4"
        d.rounded_rectangle([x, y, x + bw, y + 170], radius=14,
                            fill=(255, 255, 255, 0), outline=col, width=3)
        lab = str(it["label"])
        d.text((x + 24, y + 20), lab, font=F(typo.NOTE, 800), fill=INK_SUB)
        val = str(it["value"])
        f = F(54 if last else 46)
        d.text((x + 24, y + 58), val, font=f, fill=col)
        _note(d, str(it.get("note", "")), x + 24, y + 126)
        if not last:
            ax = x + bw + 20
            d.line([(ax, y + 85), (ax + 40, y + 85)], fill=INK_SUB, width=5)
            d.polygon([(ax + 40, y + 72), (ax + 40, y + 98), (ax + 62, y + 85)], fill=INK_SUB)
        x += bw + 90
    _note(d, fig.get("note", ""), 58, h - 4)
    return im


KINDS["photo"] = photo
KINDS["convert"] = convert
