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

import warnings
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


def _note(d, text: str, x: int, y: int, room: int | None = None) -> None:
    """板の下の添え。**折り返さないので、長いと右端で黙って切れる。**

    2026-10-09 に compare の添え（75字）が切れていたのに気づかなかった。
    縮めても 28px が下限で足りないので、直すのは呼ぶ側（添えを短くする）。
    ここでは気づけるように言うだけにする。

    `room` は使える幅。**箱の中に置く添えは板の幅ではない**ので、flow の
    ように箱ごとに置くときは箱の幅を渡す。
    """
    if not text:
        return
    f = F(typo.NOTE, 600)
    limit = room if room is not None else typo.PANEL_W - x - 40
    if d.textlength(text, font=f) > limit:
        warnings.warn("添えが入りません（{}字・幅{}）: {}…".format(len(text), int(limit), text[:24]))
    d.text((x, y), text, font=f, fill=INK_SUB)


def stack(fig: dict) -> Image.Image:
    """積み上げの帯。**ひとつの量が何でできているか**を、割合の長さで見せる。

    金額の明細なら `charts5.receipt`、割合を円で見せるなら `charts4.donut`。
    """
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
            # 琥珀の棒のうえは白が浮きにくいので、細い縁で担保する
            d.text((x + 18, y + 26), label, font=f, fill="white",
                   stroke_width=3, stroke_fill=(32, 24, 6))
        else:
            d.text((x + max(bw, 6) + 16, y + 26), label, font=f, fill=col)
        note, nf = str(it.get("note", "")), F(typo.VALUE)
        if note:
            d.text((w - d.textlength(note, font=nf) + 10, y + 22), note, font=nf, fill=INK)
        y += 104
    _note(d, fig.get("note", ""), 58, h - 4)
    return im


def compare(fig: dict) -> Image.Image:
    """横棒で比べる。項目を並べて、長さで大小を見せる。

    ニュース調にするなら `news.ranking`（注目の1本だけ色が付く）。
    """
    items = fig["items"]
    focus = str(fig.get("focus", items[0]["label"]))
    w, h = typo.PANEL_W, 140 + len(items) * 92
    im, d, top = _card(w, h, fig.get("title", ""))
    mx = max(float(i["value"]) for i in items) or 1
    y = top
    bx = int(w * 0.26)
    nf = F(typo.BODY, 800)
    # **棒の右に置く添えの幅を、実際に測って空ける。** 300px 固定だったため、
    # 「127億9780万円（3割引いた後）」が右端で切れていた（2026-10-09）
    room = max(d.textlength(str(i.get("note", i["value"])), font=nf) for i in items) + 40
    span = max(int(w - bx - room), 200)
    for it in items:
        is_focus = str(it["label"]) == focus
        col = SERIES[0] if is_focus else MUTED
        d.text((58, y + 14), str(it["label"]), font=F(30, 900 if is_focus else 700), fill=INK)
        bw = int(span * float(it["value"]) / mx)
        d.rounded_rectangle([bx, y + 8, bx + max(bw, 4), y + 66], radius=6, fill=col)
        note = str(it.get("note", it["value"]))
        d.text((bx + max(bw, 4) + 20, y + 14), note, font=F(typo.BODY, 800),
               fill=INK if is_focus else INK_SUB)
        y += 92
    _note(d, fig.get("note", ""), 58, h - 4)
    return im


def timeline(fig: dict) -> Image.Image:
    """年表。横一本の線に、**過去の**出来事を並べる。

    これからの予定なら `charts4.schedule`。
    """
    items = fig["items"]
    # **note を書いても黙って消えていた**（2026-10-09）。書いたときだけ板を伸ばす
    _extra = 36 if fig.get("note") else 0
    w, h = typo.PANEL_W, 400 + _extra
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
            nf = F(typo.NOTE, 600)
            # **文字数だけで切ると、行頭に「）」や「。」が来る**（2026-10-09 に年表で踏んだ）。
            # 折り返しは typo.wrap に一本化する決まりなのに、ここだけ守っていなかった
            lines = typo.wrap(d, note, nf, width, 4)
            for i, ln in enumerate(lines):
                tw = d.textlength(ln, font=nf)
                d.text((x - tw / 2, y - 54 - (len(lines) - 1 - i) * 30), ln,
                       font=nf, fill=INK_SUB)
    _note(d, fig.get("note", ""), 58, h - 4)
    return im


def flow(fig: dict) -> Image.Image:
    """流れ図。箱を矢印でつなぐ。

    アイコンを使って作り込むなら `charts6.icon_flow`。
    """
    items = fig["items"]
    n = len(items)
    # **note を書いても黙って消えていた**（2026-10-09）。書いたときだけ板を伸ばす
    _extra = 36 if fig.get("note") else 0
    w, h = typo.PANEL_W, 420 + _extra
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
            d.text((x + 20, y + 88), str(it["label"]), font=F(typo.BODY), fill="white",
                   stroke_width=3, stroke_fill=(16, 20, 28))
        else:
            d.text((x + 20, y + 52), str(it["label"]), font=F(typo.BODY), fill="white",
                   stroke_width=3, stroke_fill=(16, 20, 28))
        _note(d, str(it.get("note", "")), x, y + 170, bw + 60)
        if i < n - 1:
            ax = x + bw + 16
            d.line([(ax, y + 76), (ax + 44, y + 76)], fill=INK_SUB, width=5)
            d.polygon([(ax + 44, y + 62), (ax + 44, y + 90), (ax + 68, y + 76)], fill=INK_SUB)
        x += bw + 80
    _note(d, fig.get("note", ""), 58, h - 4)
    return im


def bars(fig: dict) -> Image.Image:
    """番号つきの箇条書き。理由や条件を順に並べる。

    アイコンを添えるなら `charts6.icon_list`。
    """
    items = fig["items"]
    # **note を書いても黙って消えていた**（2026-10-09）。書いたときだけ板を伸ばす
    _extra = 36 if fig.get("note") else 0
    w, h = typo.PANEL_W, 120 + len(items) * 116 + _extra
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
    _note(d, fig.get("note", ""), 58, h - 4)
    return im


def hero(fig: dict) -> Image.Image:
    """ひとつの数字を大きく見せる。山場で使う。

    ニュース調にするなら `news.big_number`、画面いっぱいなら `fullscreen.number`。
    """
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
    """比べる表。items は {label, values:[...]}、cols は見出しの並び。

    値ではなく ◎○△× で比べるなら `charts5.verdict`。
    """
    cols = fig.get("cols", [])
    items = fig["items"]
    w, h = typo.PANEL_W, 180 + len(items) * (typo.ROW + 14) + (36 if fig.get("note") else 0)
    im, d, top = _card(w, h, fig.get("title", ""))
    # **見出しの列が広すぎて、値の列が 371px しかなかった**（2026-10-09）。
    # 値が 28px まで縮んで、見出しだけ 48px という不揃いな表になっていた
    label_w = int(w * 0.28)
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
            weight = 900 if strong else 700
            # **列の幅を超えた値が、隣の列に重なって読めなくなっていた**（2026-10-09）。
            # 入るまで下げる。28px でも入らないなら、言葉のほうが長すぎる
            size = typo.BODY + (4 if strong else 0)
            while size > 28 and d.textlength(str(v), font=F(size, weight)) > cw - 20:
                size -= 2
            if d.textlength(str(v), font=F(size, weight)) > cw - 20:
                warnings.warn("表の値が列に入りません（幅{}）: {}".format(int(cw - 20), v))
            d.text((label_w + i * cw, y + 2), str(v), font=F(size, weight),
                   fill=SERIES[1] if strong else INK)
        y += typo.ROW + 14
    # **table だけ添えを描いていなかった**（2026-10-09）。台本に書いた note が黙って消えていた
    _note(d, fig.get("note", ""), 58, h - 4)
    return im


def pie(fig: dict) -> Image.Image:
    """円グラフ。割合をひと目で。

    真ん中に数字を置きたいなら `charts4.donut`（そちらのほうが使いでがある）。
    """
    items = fig["items"][:5]
    # **note を書いても黙って消えていた**（2026-10-09）。書いたときだけ板を伸ばす
    _extra = 36 if fig.get("note") else 0
    w, h = typo.PANEL_W, 460 + _extra
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
    _note(d, fig.get("note", ""), 58, h - 4)
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
    """世界地図。marks に {name, color, note} を書くと、その国が塗られる。

    日本の都道府県なら `charts2.japan`。
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
    """写真を板に載せ、下に説明を置く。出典を必ず添える。"""
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
    """言い換え。「1リットルで70.6円」を「1年で4万円」に置き直す。

    同じ数字を、見る人の暮らしの単位に直して見せるための図。
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
