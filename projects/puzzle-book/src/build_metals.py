"""金属・レアメタルの図鑑（A5・裁ち落としあり・オールカラー）。

1ページに1種。元素のタイル・実物の写真・特徴・使われ方・産出国の棒グラフ・日本との関わり・豆知識。
データは books/metals-data.json（2つ以上の出典で確かめたもの。産出国は USGS Mineral Commodity Summaries）。
写真は assets/metals-photos/（Wikimedia Commons の自由なライセンスのもの。作者とライセンスは credits.json）。
紙面の部品（ページ枠・折り返し・見出し・CMYK 変換）は build_sekai と共通。
"""

from __future__ import annotations

import argparse
import io
import json
import re
from dataclasses import dataclass, field
from pathlib import Path

from reportlab.lib.colors import CMYKColor
from reportlab.lib.units import inch
from reportlab.lib.utils import ImageReader
from reportlab.pdfgen import canvas

import kdp_spec
from art import FONT_ROUNDED, outlined_text
from build_book import FONT_BOLD, FONT_REGULAR
from build_kotoba import CMYK
from build_sekai import (BLEED, GOLD, INK, NAVY, PAPER, SUB, WHITE, Frame, _heading, _para, fill_page, folio, frame,
                         kana_key, to_cmyk, wrap, wrap_even)

_ROOT = Path(__file__).resolve().parent.parent
PHOTO_DIR = _ROOT / "assets" / "metals-photos"

# 章（金属のなかま）と色
GROUPS = [
    ("身近な金属", "くらしを支える、量の多い金属", (0.62, 0.40, 0.0, 0.25), (0.08, 0.04, 0.0, 0.0)),
    ("貴金属", "さびにくく、値打ちの高い金属", (0.0, 0.25, 0.95, 0.10), (0.0, 0.04, 0.14, 0.0)),
    ("レアメタル", "量は少ないが、ハイテクに欠かせない金属", (0.70, 0.0, 0.45, 0.15), (0.08, 0.0, 0.05, 0.0)),
    ("レアアース", "強い磁石や光る材料をつくる17元素", (0.45, 0.80, 0.0, 0.05), (0.05, 0.09, 0.0, 0.0)),
    ("その他", "注意して使う、特別な金属", (0.0, 0.0, 0.0, 0.55), (0.0, 0.0, 0.0, 0.07)),
]
GROUP_COLOR = {g: (c, t) for g, _, c, t in GROUPS}
FRONT_PAGES = 6  # 表題・はじめに・この本の見方・周期表・レアメタルとは・もくじ
BACK_PAGES = 4  # さくいん・参考にした資料・写真の出典・奥付


@dataclass
class MetalsSpec:
    title: str
    subtitle: str
    data: str
    publisher: str = "つるはし社"
    trim: str = "a5"
    ink: str = "premium"
    edition_date: str = ""
    extra: dict = field(default_factory=dict)

    @classmethod
    def load(cls, path: str | Path) -> "MetalsSpec":
        return cls(**json.loads(Path(path).read_text(encoding="utf-8")))


def load_metals(spec: MetalsSpec) -> tuple[list[dict], dict]:
    """章の順（GROUPS）、章の中は原子番号の順。全体の項目（レアアース全体など）は章の最後。"""
    d = json.loads((_ROOT / spec.data).read_text(encoding="utf-8"))
    order = {g: i for i, (g, *_r) in enumerate(GROUPS)}
    ms = sorted(d["metals"], key=lambda m: (order[m["group"]], m["z"] or 999))
    return ms, d["meta"]


def chapters(ms: list[dict]) -> list[tuple[str, list[int]]]:
    out = []
    for g, *_r in GROUPS:
        idx = [k for k, m in enumerate(ms) if m["group"] == g]
        if idx:
            out.append((g, idx))
    return out


def page_count(ms: list[dict]) -> int:
    return FRONT_PAGES + sum(1 + len(i) for _, i in chapters(ms)) + BACK_PAGES


def item_page(ms: list[dict], k: int) -> int:
    p = FRONT_PAGES
    for _, idx in chapters(ms):
        p += 1
        for j in idx:
            p += 1
            if j == k:
                return p
    raise IndexError(k)


def chapter_page(ms: list[dict], ci: int) -> int:
    return FRONT_PAGES + 1 + sum(1 + len(i) for _, i in chapters(ms)[:ci])


# --- 書体にない字（³ ℃ など）は欧文の書体で -----------------------------------------


def _has(font: str, ch: str) -> bool:
    from reportlab.pdfbase import pdfmetrics

    return ord(ch) in pdfmetrics.getFont(font).face.charToGlyph


def draw_mix(c: canvas.Canvas, x: float, y: float, text: str, font: str, size: float) -> None:
    """日本語の書体に無い字（³ ℃ など）だけ欧文の書体（LAT）に切り替えて描く。"""
    run, run_font = "", font
    for ch in text:
        f = font if _has(font, ch) or not _has("LAT", ch) else "LAT"
        if f != run_font and run:
            c.setFont(run_font, size)
            c.drawString(x, y, run)
            x += c.stringWidth(run, run_font, size)
            run = ""
        run_font = f
        run += ch
    if run:
        c.setFont(run_font, size)
        c.drawString(x, y, run)


# --- 写真 ------------------------------------------------------------------------


def photo_path(m: dict) -> Path | None:
    key = m["symbol"] or "REE"
    for ext in (".jpg", ".jpeg", ".png"):
        p = PHOTO_DIR / f"{key}{ext}"
        if p.exists():
            return p
    return None


_PHOTO_CACHE: dict[str, bytes] = {}


def draw_photo(c: canvas.Canvas, m: dict, x: float, y: float, w: float, h: float, radius: float = 6) -> bool:
    """写真を枠いっぱいに（はみ出しは切って）角丸で置く。無ければ灰色の枠に元素記号。"""
    p = photo_path(m)
    c.saveState()
    clip = c.beginPath()
    clip.roundRect(x, y, w, h, radius)
    c.clipPath(clip, stroke=0, fill=0)
    if p is None:
        c.setFillColorCMYK(0, 0, 0, 0.12)
        c.rect(x, y, w, h, stroke=0, fill=1)
        c.setFillColorCMYK(0, 0, 0, 0.45)
        c.setFont("LAT-B", h * 0.32)
        c.drawCentredString(x + w / 2, y + h * 0.38, m["symbol"] or "REE")
        c.restoreState()
        return False
    from PIL import Image

    key = str(p)
    img = Image.open(p)
    iw, ih = img.size
    # 枠の縦横比に合わせて中央を切り出す
    want = w / h
    if iw / ih > want:
        nw = int(ih * want)
        box = ((iw - nw) // 2, 0, (iw + nw) // 2, ih)
    else:
        nh = int(iw / want)
        box = (0, (ih - nh) // 2, iw, (ih + nh) // 2)
    if key not in _PHOTO_CACHE:
        crop = img.crop(box)
        need_w = int(w / 72 * 300)
        if crop.width > need_w * 1.5:  # 300dpi の1.5倍より大きければ縮める（PDF を重くしない）
            crop = crop.resize((int(need_w * 1.5), int(need_w * 1.5 * crop.height / crop.width)))
        out = io.BytesIO()
        to_cmyk(crop.convert("RGB")).save(out, "JPEG", quality=92)
        _PHOTO_CACHE[key] = out.getvalue()
    c.drawImage(ImageReader(io.BytesIO(_PHOTO_CACHE[key])), x, y, w, h)
    c.restoreState()
    return True


# --- 1種のページ ------------------------------------------------------------------


def element_tile(c: canvas.Canvas, x: float, y: float, s: float, m: dict, col: CMYK) -> None:
    """周期表のタイル（左上に原子番号、真ん中に記号、下に名前）。(x, y) は左下、s は一辺。"""
    c.setFillColorCMYK(*WHITE)
    c.roundRect(x, y, s, s, s * 0.08, stroke=0, fill=1)
    c.setFillColorCMYK(*col)
    c.setFont(FONT_BOLD, max(7, s * 0.15))
    c.drawString(x + s * 0.09, y + s * 0.78, str(m["z"]) if m["z"] else "")
    sym = m["symbol"] or "REE"
    fs = s * 0.46
    while c.stringWidth(sym, "LAT-B", fs) > s * 0.86:
        fs -= 0.5
    c.setFont("LAT-B", fs)
    c.drawCentredString(x + s / 2, y + s * 0.34, sym)
    c.setFont(FONT_BOLD, s * 0.13)
    nm = m["name"]
    nfs = max(7, s * 0.13)
    while c.stringWidth(nm, FONT_BOLD, nfs) > s * 0.94 and nfs > 7:
        nfs -= 0.25
    if c.stringWidth(nm, FONT_BOLD, nfs) > s * 0.94:  # 7pt でも入らない長い名前は（ ）を外す
        nm = re.sub(r"（.*?）", "", nm)
    c.setFont(FONT_BOLD, nfs)
    c.drawCentredString(x + s / 2, y + s * 0.1, nm)


def _split_use(u: str) -> tuple[str, str]:
    """「製品：説明」を分ける。"""
    if "：" in u:
        a, b = u.split("：", 1)
        return a.strip(), b.strip()
    return u, ""


# 1ページに収まらないときに、字と間隔を一段ずつ詰める段階
METAL_DENSITY = [
    {"feat": 9.0, "featg": 12.5, "use": 8.5, "useg": 11.5, "box": 8.5, "boxg": 12.0, "bar": 13, "gap": 3},
    {"feat": 8.5, "featg": 11.5, "use": 8.0, "useg": 10.5, "box": 8.0, "boxg": 11.0, "bar": 12, "gap": 2},
    {"feat": 8.0, "featg": 10.5, "use": 7.5, "useg": 9.8, "box": 7.5, "boxg": 10.0, "bar": 11, "gap": 1.5},
]


def draw_metal(c: canvas.Canvas, f: Frame, m: dict, no: int, chapter_label: str) -> None:
    last = None
    for P in METAL_DENSITY:
        try:
            _draw_metal(canvas.Canvas(io.BytesIO(), pagesize=(f.pw, f.ph)), f, m, no, chapter_label, P)
        except AssertionError as e:
            last = e
            continue
        return _draw_metal(c, f, m, no, chapter_label, P)
    raise AssertionError(f"1ページに収まらない: {m['name']} {last}")


def _draw_metal(c: canvas.Canvas, f: Frame, m: dict, no: int, chapter_label: str, P: dict) -> None:
    col, tint = GROUP_COLOR[m["group"]]
    L, R, w = f.left, f.right, f.width
    fill_page(c, f, PAPER)
    band_h = 150
    band_bottom = f.top - band_h + 20
    c.setFillColorCMYK(*col)
    c.rect(0, band_bottom, f.pw, f.ph - band_bottom, stroke=0, fill=1)
    # 元素のタイル
    ts = 74
    element_tile(c, L, f.top - ts - 4, ts, m, col)
    # 名前と仲間
    nx = L + ts + 14
    c.setFillColorCMYK(*WHITE)
    c.setFont(FONT_BOLD, 9)
    c.drawString(nx, f.top - 16, f"{no:02d}　{m['group']}")
    fs = 30
    photo_w = 128
    room = R - photo_w - 10 - nx
    while c.stringWidth(m["name"], FONT_ROUNDED, fs) > room and fs > 18:
        fs -= 0.5
    c.setFont(FONT_ROUNDED, fs)
    c.drawString(nx, f.top - 18 - fs, m["name"])
    sub = m.get("reading") or ""
    if sub:
        c.setFont(FONT_REGULAR, 9)
        c.drawString(nx, f.top - 28 - fs, sub)
    # 写真（帯にかかる）
    ph_h = 104
    px, py = R - photo_w, band_bottom - ph_h / 2
    c.setFillColorCMYK(*WHITE)
    c.roundRect(px - 3, py - 3, photo_w + 6, ph_h + 6, 8, stroke=0, fill=1)
    draw_photo(c, m, px, py, photo_w, ph_h)
    # 特徴（帯の下、写真の左）
    y = band_bottom - 20
    c.setFillColorCMYK(*NAVY)
    c.setFont(FONT_ROUNDED, 11.5)
    c.drawString(L, y, "どんな金属？")
    y -= 15
    feat_w = px - 12 - L
    c.setFont(FONT_REGULAR, P["feat"])
    for ft in m["features"]:
        lines = wrap_even(c, ft, FONT_REGULAR, P["feat"], feat_w - 10, False)
        c.setFillColorCMYK(*col)
        c.rect(L + 1, y + 2, 4, 4, stroke=0, fill=1)
        c.setFillColorCMYK(*INK)
        for ln in lines:
            draw_mix(c, L + 10, y, ln, FONT_REGULAR, P["feat"])
            y -= P["featg"]
        y -= 2
    y = min(y, py - 14)
    # 何に使われている？
    c.setFillColorCMYK(*NAVY)
    c.setFont(FONT_ROUNDED, 11.5)
    c.drawString(L, y - 4, "何に使われている？")
    y -= 14
    for u in m["uses"]:
        head, body = _split_use(u)
        lines = wrap_even(c, body, FONT_REGULAR, P["use"], w - 110, False) if body else []
        h = max(P["useg"] + 8, 8 + P["useg"] * max(1, len(lines)))
        c.setFillColorCMYK(*WHITE)
        c.rect(L, y - h, w, h, stroke=0, fill=1)
        c.setFillColorCMYK(*col)
        c.rect(L, y - h, 3, h, stroke=0, fill=1)
        c.setFillColorCMYK(*INK)
        hfs = 9
        while c.stringWidth(head, FONT_BOLD, hfs) > 88 and hfs > 7:
            hfs -= 0.25
        c.setFont(FONT_BOLD, hfs)
        c.drawString(L + 9, y - 13, head)
        c.setFont(FONT_REGULAR, P["use"])
        for li, ln in enumerate(lines):
            draw_mix(c, L + 100, y - 13 - li * P["useg"], ln, FONT_REGULAR, P["use"])
        y -= h + P["gap"]
    # どこで採れる？（上位3か国の棒）
    pr = m.get("producers") or {}
    top = (pr.get("top3") or [])[:4]
    y -= 16
    c.setFillColorCMYK(*NAVY)
    c.setFont(FONT_ROUNDED, 11.5)
    c.drawString(L, y, "どこで採れる？")
    c.setFillColorCMYK(*SUB)
    c.setFont(FONT_REGULAR, 7)
    basis = pr.get("basis", "")
    note_src = f"{pr.get('year', '')}年・{basis}" if basis else ""
    c.drawRightString(R, y + 1, note_src + "（USGS ほか）" if note_src else "")
    y -= 6
    if top:
        bar_w = w - 120
        for t in top:
            y -= P["bar"]
            c.setFillColorCMYK(*INK)
            c.setFont(FONT_REGULAR, 8.5)
            cname = t["country"]
            c.drawString(L, y, cname)
            share = float(t.get("share_percent") or 0)
            c.setFillColorCMYK(*tint)
            c.rect(L + 76, y - 1, bar_w, 9, stroke=0, fill=1)
            c.setFillColorCMYK(*col)
            c.rect(L + 76, y - 1, bar_w * min(share, 100) / 100, 9, stroke=0, fill=1)
            c.setFillColorCMYK(*INK)
            c.setFont(FONT_BOLD, 8.5)
            c.drawRightString(R, y, f"{share:g}%")
        if pr.get("note"):
            y -= 11
            c.setFillColorCMYK(*SUB)
            c.setFont(FONT_REGULAR, 7)
            for ln in wrap_even(c, pr["note"], FONT_REGULAR, 7, w, False)[:2]:
                c.drawString(L, y, ln)
                y -= 9
            y += 9
    else:
        y -= 13
        c.setFillColorCMYK(*SUB)
        c.setFont(FONT_REGULAR, 8)
        for ln in wrap_even(c, pr.get("note") or "国別の統計がありません。", FONT_REGULAR, 8, w, False)[:2]:
            c.drawString(L, y, ln)
            y -= 10.5
        y += 10.5
    # 日本とのつながり・豆知識（2つの枠を下にそろえる）
    boxes = [("日本とのつながり", m.get("japan", "")), ("豆知識", m.get("trivia", ""))]
    lays = [(t, wrap_even(c, s, FONT_REGULAR, P["box"], w - 24, False)) for t, s in boxes if s]
    need = sum(22 + P["boxg"] * len(ls) + 6 for _, ls in lays)
    y_box = f.bottom + need
    assert y - 10 >= y_box, (m["name"], y - 10 - y_box)
    yy = y_box
    for title, ls in lays:
        bh = 22 + P["boxg"] * len(ls)
        c.setFillColorCMYK(*tint)
        c.roundRect(L, yy - bh, w, bh, 3, stroke=0, fill=1)
        c.setFillColorCMYK(*col)
        c.rect(L + 10, yy - 15, 6, 6, stroke=0, fill=1)
        c.setFillColorCMYK(*NAVY)
        c.setFont(FONT_BOLD, 9)
        c.drawString(L + 21, yy - 15, title)
        c.setFillColorCMYK(*INK)
        c.setFont(FONT_REGULAR, P["box"])
        for li, ln in enumerate(ls):
            draw_mix(c, L + 12, yy - 29 - li * P["boxg"], ln, FONT_REGULAR, P["box"])
        yy -= bh + 6
    folio(c, f, chapter_label)


# --- 周期表 ----------------------------------------------------------------------

SYMBOLS = ("H He Li Be B C N O F Ne Na Mg Al Si P S Cl Ar K Ca Sc Ti V Cr Mn Fe Co Ni Cu Zn Ga Ge As Se Br Kr "
           "Rb Sr Y Zr Nb Mo Tc Ru Rh Pd Ag Cd In Sn Sb Te I Xe Cs Ba La Ce Pr Nd Pm Sm Eu Gd Tb Dy Ho Er Tm Yb Lu "
           "Hf Ta W Re Os Ir Pt Au Hg Tl Pb Bi Po At Rn Fr Ra Ac Th Pa U").split()


def pt_position(z: int) -> tuple[int, int]:
    """原子番号 → (行, 列)。行0〜6が本体、7・8がランタノイド・アクチノイド。列は0〜17。"""
    if z <= 2:
        return 0, 0 if z == 1 else 17
    starts = [(3, 1), (11, 2), (19, 3), (37, 4), (55, 5), (87, 6)]
    for s, row in reversed(starts):
        if z >= s:
            break
    i = z - s
    if row in (1, 2):
        return row, i if i < 2 else i + 10
    if row in (5, 6):
        if 57 <= z <= 71:
            return 7, z - 57 + 2
        if 89 <= z <= 103:
            return 8, z - 89 + 2
        if i < 2:
            return row, i
        return row, i - 14 if (row == 5 and z > 71) or (row == 6 and z > 103) else i
    return row, i


# --- 本文 ------------------------------------------------------------------------


def build_pdf(spec: MetalsSpec, output_path: str) -> int:
    ms, meta = load_metals(spec)
    chs = chapters(ms)
    total = page_count(ms)
    t = kdp_spec.TRIMS[spec.trim]
    pw, ph = t.width_in * inch + BLEED, t.height_in * inch + 2 * BLEED
    c = canvas.Canvas(output_path, pagesize=(pw, ph), initialFontName=FONT_REGULAR)
    c.setTitle(spec.title)
    c.setAuthor(spec.publisher)
    c.setCreator(spec.publisher)
    n = 1

    def page() -> Frame:
        return frame(spec, n)

    def turn() -> None:
        nonlocal n
        c.showPage()
        n += 1

    # 1. 表題
    f = page()
    fill_page(c, f, PAPER)
    c.setFillColorCMYK(*NAVY)
    c.rect(0, f.y0 + (f.y1 - f.y0) * 0.45, f.pw, f.ph, stroke=0, fill=1)
    mid = (f.left + f.right) / 2
    outlined_text(c, spec.title, mid, f.top - 150, font=FONT_ROUNDED, size=27,
                  fill=CMYKColor(*WHITE), outline=CMYKColor(*NAVY), outline_width=1)
    c.setFillColorCMYK(*GOLD)
    c.setFont(FONT_BOLD, 10.5)
    c.drawCentredString(mid, f.top - 185, spec.subtitle)
    c.setFillColorCMYK(*INK)
    c.setFont(FONT_BOLD, 11)
    c.drawCentredString(mid, f.bottom + 10, spec.publisher)
    turn()

    # 2. はじめに
    f = page()
    fill_page(c, f, PAPER)
    y = _heading(c, f, "はじめに")
    for text in spec.extra.get("intro", []):
        y = _para(c, f, text, y, gap=17) - 8
    folio(c, f)
    turn()

    # 3. この本の見方
    f = page()
    fill_page(c, f, PAPER)
    y = _heading(c, f, "この本の見方")
    for text in spec.extra.get("howto", []):
        y = _para(c, f, text, y, fs=9.5, gap=15) - 6
    folio(c, f)
    turn()

    # 4. 周期表
    f = page()
    fill_page(c, f, PAPER)
    y = _heading(c, f, "周期表で見る、この本の金属")
    inbook = {m["z"]: m for m in ms if m["z"]}
    cell = f.width / 18
    gy = y - 6
    for z, sym in enumerate(SYMBOLS, start=1):
        r, col_ = pt_position(z)
        x = f.left + col_ * cell
        yy = gy - r * cell - (6 if r >= 7 else 0)
        if z in inbook:
            gc, _ = GROUP_COLOR[inbook[z]["group"]]
            c.setFillColorCMYK(*gc)
        else:
            c.setFillColorCMYK(0, 0, 0, 0.08)
        c.rect(x + 0.6, yy - cell + 0.6, cell - 1.2, cell - 1.2, stroke=0, fill=1)
        c.setFillColorCMYK(*(WHITE if z in inbook else (0, 0, 0, 0.45)))
        c.setFont("LAT-B", cell * 0.38)
        c.drawCentredString(x + cell / 2, yy - cell * 0.62, sym)
    ly = gy - 9 * cell - 22
    lx = f.left
    for g, desc, gc, _t in GROUPS:
        if not any(m["group"] == g for m in ms):
            continue
        c.setFillColorCMYK(*gc)
        c.rect(lx, ly, 9, 9, stroke=0, fill=1)
        c.setFillColorCMYK(*INK)
        c.setFont(FONT_BOLD, 8.5)
        c.drawString(lx + 13, ly + 1, g)
        lx += 13 + c.stringWidth(g, FONT_BOLD, 8.5) + 14
    y = ly - 22
    for text in spec.extra.get("table_note", []):
        y = _para(c, f, text, y, fs=9, gap=14) - 4
    folio(c, f)
    turn()

    # 5. レアメタルとは
    f = page()
    fill_page(c, f, PAPER)
    y = _heading(c, f, "レアメタルとは")
    for text in spec.extra.get("raremetal", []):
        y = _para(c, f, text, y, fs=10, gap=16.5) - 8
    assert y >= f.bottom, y
    folio(c, f)
    turn()

    # 6. もくじ（1行に1種、2段組み）
    f = page()
    fill_page(c, f, PAPER)
    y0 = _heading(c, f, "もくじ") + 6
    col_w = (f.width - 16) / 2
    rows = []
    for ci, (g, idx) in enumerate(chs):
        rows.append(("ch", g, chapter_page(ms, ci)))
        rows += [("it", ms[k], item_page(ms, k)) for k in idx]
    half = (len(rows) + 1) // 2
    split = half  # 章の途中でも右の段へ続ける（レアメタルの章が長いため）
    LH = 11.4
    for hi, part in enumerate((rows[:split], rows[split:])):
        x = f.left + hi * (col_w + 16)
        y = y0
        for kind, obj, pno in part:
            if kind == "ch":
                gc, _ = GROUP_COLOR[obj]
                y -= 4
                c.setFillColorCMYK(*gc)
                c.roundRect(x, y - 5, col_w, 17, 5, stroke=0, fill=1)
                c.setFillColorCMYK(*WHITE)
                c.setFont(FONT_ROUNDED, 10)
                c.drawString(x + 7, y, obj)
                c.setFont(FONT_BOLD, 8.5)
                c.drawRightString(x + col_w - 7, y, str(pno))
                y -= 18
            else:
                c.setFillColorCMYK(*SUB)
                c.setFont("LAT-B", 8)
                c.drawString(x + 5, y, obj["symbol"] or "")
                c.setFillColorCMYK(*INK)
                c.setFont(FONT_REGULAR, 8.5)
                c.drawString(x + 26, y, obj["name"])
                c.setFillColorCMYK(*SUB)
                c.drawRightString(x + col_w - 7, y, str(pno))
                y -= LH
        assert y >= f.bottom - 4, (hi, y - f.bottom)
    folio(c, f)
    turn()

    # 7. 章と各種
    no = 0
    for ci, (g, idx) in enumerate(chs):
        f = page()
        gc, gt = GROUP_COLOR[g]
        fill_page(c, f, gt)
        c.setFillColorCMYK(*gc)
        TOP = 180
        c.rect(0, f.y1 - TOP, f.pw, TOP + BLEED, stroke=0, fill=1)
        c.setFillColorCMYK(*WHITE)
        c.setFont(FONT_ROUNDED, 42)
        c.drawString(f.left, f.y1 - 96, f"第{ci + 1}章")
        c.setFont(FONT_ROUNDED, 26)
        c.drawString(f.left, f.y1 - 140, g)
        desc = next(d for gg, d, *_r in GROUPS if gg == g)
        c.setFont(FONT_BOLD, 10)
        c.drawString(f.left, f.y1 - 162, desc)
        # この章の金属のタイル
        per_row = 5 if len(idx) <= 15 else 6
        ts = (f.width - (per_row - 1) * 6) / per_row
        rows_ = (len(idx) + per_row - 1) // per_row
        ts = min(ts, (f.y1 - TOP - 20 - f.bottom) / rows_ - 16)
        for j, k in enumerate(idx):
            x = f.left + (j % per_row) * (ts + 6)
            yy = f.y1 - TOP - 20 - ts - (j // per_row) * (ts + 16)
            element_tile(c, x, yy, ts, ms[k], gc)
            c.setFillColorCMYK(*SUB)
            c.setFont(FONT_REGULAR, 7)
            c.drawCentredString(x + ts / 2, yy - 10, f"{item_page(ms, k)}ページ")
        turn()
        for k in idx:
            no += 1
            draw_metal(c, page(), ms[k], no, f"第{ci + 1}章　{g}")
            turn()

    # 8. さくいん（五十音順）
    f = page()
    fill_page(c, f, PAPER)
    y = _heading(c, f, "さくいん")
    order = sorted(range(len(ms)), key=lambda k: kana_key(ms[k].get("kana") or ms[k]["name"]))
    col_w = (f.width - 12) / 2
    per = (len(order) + 1) // 2
    row = (y - f.bottom) / per
    for mm, k in enumerate(order):
        x0 = f.left + (mm // per) * (col_w + 12)
        yy = y - (mm % per) * row
        c.setFillColorCMYK(*GROUP_COLOR[ms[k]["group"]][0])
        c.circle(x0 + 3, yy + 3, 2.2, stroke=0, fill=1)
        c.setFillColorCMYK(*INK)
        c.setFont(FONT_REGULAR, 8.5)
        c.drawString(x0 + 10, yy, ms[k]["name"])
        c.setFillColorCMYK(*SUB)
        c.setFont("LAT", 8)
        c.drawString(x0 + 90, yy, ms[k]["symbol"] or "")
        c.setFont(FONT_BOLD, 8.5)
        c.drawRightString(x0 + col_w, yy, str(item_page(ms, k)))
    folio(c, f)
    turn()

    # 9. 参考にした資料
    f = page()
    fill_page(c, f, PAPER)
    y = _heading(c, f, "参考にした資料")
    for text in spec.extra.get("references", []):
        y = _para(c, f, text, y, fs=9, gap=14) - 6
    folio(c, f)
    turn()

    # 10. 写真の出典
    f = page()
    fill_page(c, f, PAPER)
    y = _heading(c, f, "写真の出典")
    credits = []
    cfile = PHOTO_DIR / "credits.json"
    if cfile.exists():
        credits = json.loads(cfile.read_text(encoding="utf-8"))
    y = _para(c, f, "写真はすべて Wikimedia Commons のものです（作者・ライセンスの順）。", y, fs=8.5, gap=13) - 4
    c.setFont(FONT_REGULAR, 6.8)
    col_w = (f.width - 10) / 2
    per = (len(credits) + 1) // 2 or 1
    for i, cr in enumerate(credits):
        x = f.left + (i // per) * (col_w + 10)
        yy = y - (i % per) * 9.2
        c.setFillColorCMYK(*INK)
        text = f"{cr.get('element', '')}: {cr.get('author', '')} / {cr.get('license', '')}"
        while c.stringWidth(text, FONT_REGULAR, 6.8) > col_w and len(text) > 10:
            text = text[:-2] + "…"
        c.drawString(x, yy, text)
    folio(c, f)
    turn()

    # 11. 奥付
    f = page()
    fill_page(c, f, PAPER)
    y = f.bottom + 150
    c.setStrokeColorCMYK(*NAVY)
    c.setLineWidth(0.8)
    c.line(f.left, y + 18, f.right, y + 18)
    c.setFillColorCMYK(*INK)
    c.setFont(FONT_BOLD, 11)
    c.drawString(f.left, y, spec.title)
    c.setFont(FONT_REGULAR, 9)
    y -= 20
    if spec.edition_date:
        c.drawString(f.left, y, f"{spec.edition_date}　初版発行")
        y -= 15
    c.drawString(f.left, y, f"発行　{spec.publisher}")
    y -= 15
    year = spec.edition_date[:4] if spec.edition_date[:4].isdigit() else ""
    c.setFont("LAT", 9)
    c.drawString(f.left, y, "©")
    c.setFont(FONT_REGULAR, 9)
    c.drawString(f.left + c.stringWidth("© ", "LAT", 9), y, " ".join(t for t in (year, spec.publisher) if t))
    y -= 20
    c.setFont(FONT_REGULAR, 7.5)
    for line in spec.extra.get("credits", []):
        for part in wrap(c, line, FONT_REGULAR, 7.5, f.width, "list"):
            c.drawString(f.left, y, part)
            y -= 11
    c.line(f.left, y + 2, f.right, y + 2)
    turn()
    c.save()
    return n - 1


COVER_PICKS = ["Au", "Cu", "Li", "Nd", "Fe", "Pt", "Co", "Ga", "Ti", "Ag", "In", "W"]


def build_cover(spec: MetalsSpec, output_path: str) -> tuple[float, float]:
    from simple_cover import build_cover as _bc

    ms, _ = load_metals(spec)
    by = {m["symbol"]: m for m in ms if m["symbol"]}

    def visual(c, x, y, w, h):
        cols, rows = 4, 3
        gap = 7
        s_ = min((w - gap * (cols - 1)) / cols, (h - gap * (rows - 1)) / rows)
        x0 = x + (w - (s_ * cols + gap * (cols - 1))) / 2
        y0 = y + (h - (s_ * rows + gap * (rows - 1))) / 2
        for i, sym in enumerate(COVER_PICKS[: cols * rows]):
            m = by[sym]
            gc, _t = GROUP_COLOR[m["group"]]
            xx = x0 + (i % cols) * (s_ + gap)
            yy = y0 + (rows - 1 - i // cols) * (s_ + gap)
            c.setFillColorCMYK(*WHITE)
            c.roundRect(xx - 2, yy - 2, s_ + 4, s_ + 4, 7, stroke=0, fill=1)
            draw_photo(c, m, xx, yy + s_ * 0.26, s_, s_ * 0.74, radius=5)
            c.setFillColorCMYK(*gc)
            c.roundRect(xx, yy, s_, s_ * 0.26, 4, stroke=0, fill=1)
            c.setFillColorCMYK(*WHITE)
            c.setFont("LAT-B", s_ * 0.14)
            c.drawString(xx + 6, yy + s_ * 0.075, sym)
            c.setFont(FONT_BOLD, s_ * 0.1)
            c.drawRightString(xx + s_ - 6, yy + s_ * 0.085, re.sub(r"（.*?）", "", m["name"]))

    ex = spec.extra.get("cover", {})
    return _bc(spec, page_count(ms), output_path, visual, ex.get("tagline", ""), ex.get("blurb", []),
               [tuple(e) for e in ex.get("examples", [])], ex.get("for_whom", []), ex.get("contents", []))


def main() -> None:
    parser = argparse.ArgumentParser(description="金属・レアメタルの図鑑の本文PDFを作る")
    parser.add_argument("spec")
    args = parser.parse_args()
    spec = MetalsSpec.load(args.spec)
    stem = Path(args.spec).stem
    Path("output").mkdir(exist_ok=True)
    total = build_pdf(spec, f"output/{stem}-interior.pdf")
    cost = kdp_spec.print_cost_jpy(total, spec.ink, spec.trim)
    print(f"{total}ページ（印刷代 {cost}円）-> output/{stem}-interior.pdf")
    w, h = build_cover(spec, f"output/{stem}-cover.pdf")
    print(f"表紙 {w:.4f} x {h:.4f} in -> output/{stem}-cover.pdf")


if __name__ == "__main__":
    main()
