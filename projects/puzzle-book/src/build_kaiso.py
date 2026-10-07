"""「思い出ばなし 12か月」（回想の問いかけ集）の本文PDFと表紙PDFを組む。

聞き手（家族・介護の職員）が、季節に沿って昔の話を引き出すための本。1か月に8つの話題、
1つの話題に「問いかけ」1つと「話のたね」（聞き足す問い）3つ、聞いたことを書きとめる欄。
パズルではないので生成器は使わない。問いかけは books/kaiso-*.json に Claude が書いた
（KDP の AI 申告はテキスト「はい」）。回想法の作法に合わせ、戦争・病気・死別には触れない。
紙面の部品（色帯・丸い札・絵・余白）はことば探しの本と共通。
"""

from __future__ import annotations

import argparse
import io
import json
from dataclasses import dataclass
from pathlib import Path

from reportlab.lib.colors import CMYKColor
from reportlab.lib.units import inch
from reportlab.lib.utils import ImageReader
from reportlab.pdfgen import canvas

import kdp_spec
from art import FONT_ROUNDED, ICON_CREDIT, draw_icon, outlined_text
from build_book import FONT_BOLD, FONT_REGULAR, _Pager
from build_cover import NAVY, ORANGE, WHITE
from build_kotoba import BLACK, COPY_PERMISSION, CMYK, _seal

# 月ごとの色（濃い色＝帯・見出し、淡い色＝地）
MONTH_COLORS: dict[str, tuple[CMYK, CMYK]] = {
    "red": ((0.0, 0.80, 0.70, 0.05), (0.0, 0.10, 0.08, 0.0)),
    "blue": ((0.85, 0.45, 0.0, 0.10), (0.12, 0.04, 0.0, 0.0)),
    "pink": ((0.0, 0.65, 0.20, 0.0), (0.0, 0.10, 0.02, 0.0)),
    "green": ((0.70, 0.0, 0.80, 0.10), (0.10, 0.0, 0.14, 0.0)),
    "orange": ((0.0, 0.55, 0.95, 0.0), (0.0, 0.08, 0.16, 0.0)),
}
LINE: CMYK = (0, 0, 0, 0.35)
FRONT_PAGES = 4  # 表題・使い方（2ページ）・もくじ
PAGES_PER_MONTH = 5  # 月の扉＋話題2つずつ4ページ
BACK_PAGES = 2  # 思い出メモ・奥付


@dataclass
class KaisoSpec:
    title: str
    subtitle: str
    months: list[dict]
    publisher: str = "つるはし社"
    trim: str = "a4"
    ink: str = "premium"
    copy_ok: bool = False
    edition_date: str = ""

    @classmethod
    def load(cls, path: str | Path) -> "KaisoSpec":
        return cls(**json.loads(Path(path).read_text(encoding="utf-8")))

    @property
    def topics(self) -> list[dict]:
        return [t for m in self.months for t in m["topics"]]


def page_count(spec: KaisoSpec) -> int:
    total = FRONT_PAGES + PAGES_PER_MONTH * len(spec.months) + BACK_PAGES
    return total + (total % 2)


def month_first_page(spec: KaisoSpec, index: int) -> int:
    """index 番目（0始まり）の月の扉のページ番号（1始まり）。"""
    return FRONT_PAGES + 1 + PAGES_PER_MONTH * index


def topic_page(spec: KaisoSpec, month_index: int, topic_index: int) -> int:
    return month_first_page(spec, month_index) + 1 + topic_index // 2


def wrap(c: canvas.Canvas, text: str, font: str, size: float, width: float) -> list[str]:
    """日本語を幅で折り返す。句読点・閉じかっこが行頭に来ないようにする。"""
    lines, cur = [], ""
    for ch in text:
        if c.stringWidth(cur + ch, font, size) > width and cur:
            if ch in "、。」）？！":
                cur, ch = cur[:-1], cur[-1] + ch
            lines.append(cur)
            cur = ch
        else:
            cur += ch
    if cur:
        lines.append(cur)
    if len(lines) > 1 and len(lines[-1]) <= 2:
        lines[-2], lines[-1] = lines[-2][:-3], lines[-2][-3:] + lines[-1]
    return lines


def _band(c: canvas.Canvas, left: float, right: float, top: float, color: CMYK, left_text: str, right_text: str) -> float:
    h = 36
    c.setFillColorCMYK(*color)
    c.roundRect(left, top - h, right - left, h, 8, stroke=0, fill=1)
    c.setFillColorCMYK(*WHITE)
    c.setFont(FONT_ROUNDED, 20)
    c.drawString(left + 14, top - h + 11, left_text)
    c.setFont(FONT_BOLD, 14)
    c.drawRightString(right - 14, top - h + 12, right_text)
    return top - h


# --- 話題1つ（紙面の半分） ------------------------------------------------------


def draw_topic(c: canvas.Canvas, topic: dict, no: str, *, left: float, right: float, top: float, bottom: float,
               main: CMYK, tint: CMYK) -> None:
    w = right - left
    # 絵と話題の名前
    ico = 64
    c.setFillColorCMYK(*tint)
    c.circle(left + ico / 2 + 4, top - ico / 2 - 4, ico / 2 + 6, stroke=0, fill=1)
    draw_icon(c, topic["icon"], left + 4 + ico * 0.1, top - 4 - ico * 0.9, ico * 0.8)
    x0 = left + ico + 22
    c.setFillColorCMYK(*main)
    c.setFont(FONT_BOLD, 13)
    c.drawString(x0, top - 16, no)
    c.setFont(FONT_ROUNDED, 22)
    c.drawString(x0 + c.stringWidth(no, FONT_BOLD, 13) + 8, top - 18, topic["label"])
    # 問いかけ（大きな字）
    c.setFillColorCMYK(*BLACK)
    qfs = 21
    y = top - 50
    for line in wrap(c, topic["q"], FONT_BOLD, qfs, right - x0):
        c.setFont(FONT_BOLD, qfs)
        c.drawString(x0, y, line)
        y -= qfs * 1.35
    # 話のたね
    y = min(y + 4, top - ico - 16) - 4
    box_h = 3 * 21 + 28
    c.setFillColorCMYK(*tint)
    c.roundRect(left, y - box_h, w, box_h, 10, stroke=0, fill=1)
    c.setFillColorCMYK(*main)
    c.setFont(FONT_BOLD, 12)
    c.drawString(left + 14, y - 18, "話のたね（聞き足してみましょう）")
    c.setFillColorCMYK(*BLACK)
    c.setFont(FONT_REGULAR, 15)
    for k, t in enumerate(topic["tane"]):
        assert left + 34 + c.stringWidth(t, FONT_REGULAR, 15) <= right - 10, t
        c.drawString(left + 20, y - 40 - k * 21, "・")
        c.drawString(left + 34, y - 40 - k * 21, t)
    y -= box_h + 20
    # 書きとめる欄
    c.setFillColorCMYK(*main)
    c.setFont(FONT_BOLD, 12)
    c.drawString(left, y, "聞いたこと・思い出したこと")
    c.setFillColorCMYK(*BLACK)
    c.setFont(FONT_REGULAR, 12)
    c.drawRightString(right, y, "話した日　　　年　　月　　日")
    c.setStrokeColorCMYK(*LINE)
    c.setLineWidth(0.8)
    c.setDash(2, 3)
    ly = y - 26
    while ly >= bottom - 8:
        c.line(left, ly, right, ly)
        ly -= 26
    c.setDash()


def draw_topic_page(c: canvas.Canvas, month: dict, pair: list[tuple[int, dict]], *, left: float, right: float,
                    top: float, bottom: float) -> None:
    main, tint = MONTH_COLORS[month["color"]]
    band = _band(c, left, right, top, main, f"{month['month']}月　{month['season']}", month["old_name"])
    half = (band - 16 - bottom) / 2
    for k, (i, topic) in enumerate(pair):
        t0 = band - 16 - k * half
        draw_topic(c, topic, f"{month['month']}-{i + 1}", left=left, right=right, top=t0, bottom=t0 - half + 26,
                   main=main, tint=tint)
        if k == 0:
            c.setStrokeColorCMYK(*tint)
            c.setLineWidth(2)
            c.line(left, t0 - half + 8, right, t0 - half + 8)


def draw_month_cover(c: canvas.Canvas, spec: KaisoSpec, mi: int, *, left: float, right: float, top: float,
                     bottom: float) -> None:
    month = spec.months[mi]
    main, tint = MONTH_COLORS[month["color"]]
    w = right - left
    cx = (left + right) / 2
    # 大きな月の数字と季節
    c.setFillColorCMYK(*tint)
    c.roundRect(left, top - 250, w, 250, 18, stroke=0, fill=1)
    c.setFillColorCMYK(*main)
    c.setFont(FONT_ROUNDED, 120)
    num = str(month["month"])
    nw = c.stringWidth(num, FONT_ROUNDED, 120)
    c.drawString(cx - (nw + 70) / 2, top - 150, num)
    c.setFont(FONT_ROUNDED, 60)
    c.drawString(cx - (nw + 70) / 2 + nw + 6, top - 150, "月")
    c.setFont(FONT_BOLD, 22)
    c.drawCentredString(cx, top - 195, f"{month['old_name']}（{month['season']}）")
    for k, t in enumerate(month["topics"][:3]):
        draw_icon(c, t["icon"], left + 24 + k * 6, top - 70 - k * 58, 50)
    for k, t in enumerate(month["topics"][3:6]):
        draw_icon(c, t["icon"], right - 74 - k * 6, top - 70 - k * 58, 50)
    # この月の話題（8つ）
    y = top - 300
    c.setFillColorCMYK(*main)
    c.setFont(FONT_ROUNDED, 22)
    c.drawString(left, y, "この月の話題")
    c.setStrokeColorCMYK(*main)
    c.setLineWidth(2)
    c.line(left, y - 12, right, y - 12)
    col_w = w / 2
    row_h = min(120, (y - 30 - bottom) / 4)
    card_h = row_h - 14
    ico = min(72, card_h - 20)
    for k, t in enumerate(month["topics"]):
        col, row = k % 2, k // 2
        x0 = left + col * col_w
        yy = y - 26 - row * row_h  # カードの上端
        c.setFillColorCMYK(*tint)
        c.roundRect(x0 + 4, yy - card_h, col_w - 12, card_h, 12, stroke=0, fill=1)
        draw_icon(c, t["icon"], x0 + 16, yy - card_h / 2 - ico / 2, ico)
        tx = x0 + 28 + ico
        c.setFillColorCMYK(*main)
        c.setFont(FONT_BOLD, 13)
        c.drawString(tx, yy - 24, f"{month['month']}-{k + 1}")
        c.setFillColorCMYK(*BLACK)
        c.setFont(FONT_REGULAR, 12)
        c.drawRightString(x0 + col_w - 20, yy - 24, f"{topic_page(spec, mi, k)}ページ")
        # 話題の名前は、カードの幅に収まる大きさで
        room = x0 + col_w - 20 - tx
        fs = 24
        while c.stringWidth(t["label"], FONT_ROUNDED, fs) > room:
            fs -= 1
        c.setFont(FONT_ROUNDED, fs)
        c.drawString(tx, yy - card_h / 2 - 16, t["label"])


# --- 本文 ---------------------------------------------------------------------


HOWTO_FAMILY = [
    "ご家族の方へ",
    "ページを開いて、問いかけを読んであげてください。",
    "答えが出たら、下の「話のたね」で少しずつ聞き足します。",
    "聞いた話は、下の欄に書きとめておくと、あとで読み返せます。",
    "1日1つ、10分くらいでじゅうぶんです。",
    "どの月から始めても、同じ話題を何度話してもかまいません。",
]
HOWTO_FACILITY = [
    "介護施設・デイサービスの方へ",
    "月ごとに8つの話題があります。",
    "その月の行事やレクリエーションに合わせてお使いください。",
    "問いかけのページは、コピーして配ることができます",
    "（くわしくは奥付の「コピーについて」をご覧ください）。",
    "数人で話すときは、1つの話題を順番に聞いていくと、",
    "話が広がります。",
]
MANNERS = [
    "思い出せなくてもだいじょうぶ。急がず、次の問いへ。",
    "話したくなさそうな話題は、無理に聞かずに変えましょう。",
    "話の中身を、正しいか間違いかで決めつけないように。",
    "つらい話が出たら、しずかに聞いて、明るい話で終わりに。",
    "聞いた話はご本人の大切な思い出。人にむやみに話さずに。",
]


def _heading(c: canvas.Canvas, pg: _Pager, text: str, color: CMYK) -> float:
    top = pg.page_h - pg.top
    c.setFillColorCMYK(*color)
    c.setFont(FONT_ROUNDED, 28)
    c.drawString(pg.left, top - 30, text)
    c.setStrokeColorCMYK(*color)
    c.setLineWidth(2)
    c.line(pg.left, top - 42, pg.right, top - 42)
    return top - 42


def _lines(c: canvas.Canvas, pg: _Pager, lines: list[str], y: float, color: CMYK, fs: float = 15) -> float:
    c.setFillColorCMYK(*color)
    c.setFont(FONT_ROUNDED, 20)
    c.drawString(pg.left, y, lines[0])
    y -= 34
    c.setFillColorCMYK(*BLACK)
    c.setFont(FONT_REGULAR, fs)
    for line in lines[1:]:
        assert pg.left + 12 + c.stringWidth(line, FONT_REGULAR, fs) <= pg.right, line
        c.drawString(pg.left + 12, y, line)
        y -= fs * 1.75
    return y


def build_pdf(spec: KaisoSpec, output_path: str) -> int:
    trim = kdp_spec.TRIMS[spec.trim]
    total = page_count(spec)
    c = canvas.Canvas(output_path, pagesize=(trim.width_in * inch, trim.height_in * inch), initialFontName=FONT_REGULAR)
    c.setTitle(spec.title)
    c.setAuthor(spec.publisher)
    c.setCreator(spec.publisher)
    pg = _Pager(c, trim, total)
    mid = lambda: (pg.left + pg.right) / 2  # noqa: E731
    title_main, _, count = spec.title.rpartition(" ")
    lead, _, main_word = title_main.partition(" ")
    accent = MONTH_COLORS["blue"][0]

    # 1. 表題
    c.setFillColorCMYK(*ORANGE)
    c.setFont(FONT_ROUNDED, 44)
    c.drawCentredString(mid(), pg.page_h * 0.68, lead)
    c.setFillColorCMYK(*accent)
    c.setFont(FONT_ROUNDED, 70)
    c.drawCentredString(mid(), pg.page_h * 0.68 - 88, main_word)
    c.setFont(FONT_ROUNDED, 34)
    c.drawCentredString(mid(), pg.page_h * 0.68 - 136, count)
    c.setFont(FONT_BOLD, 18)
    c.drawCentredString(mid(), pg.page_h * 0.68 - 176, spec.subtitle)
    icons = [m["cover_icon"] for m in spec.months]
    for k, code in enumerate(icons):
        draw_icon(c, code, mid() - 6 * 44 + (k % 6) * 88 + 22, pg.page_h * 0.68 - 270 - (k // 6) * 70, 44)
    c.setFillColorCMYK(*BLACK)
    c.setFont(FONT_REGULAR, 14)
    c.drawCentredString(mid(), pg.page_h * 0.16, spec.publisher)
    pg.next(folio=False)

    # 2. この本の使い方
    y = _heading(c, pg, "この本の使い方", accent) - 50
    y = _lines(c, pg, HOWTO_FAMILY, y, MONTH_COLORS["orange"][0]) - 24
    y = _lines(c, pg, HOWTO_FACILITY, y, MONTH_COLORS["green"][0]) - 24
    c.setFillColorCMYK(*BLACK)
    c.setFont(FONT_REGULAR, 13)
    for line in ["1つの話題は、「問いかけ」と、聞き足すための「話のたね」3つ、",
                 "聞いたことを書きとめる欄でできています。"]:
        c.drawString(pg.left, y, line)
        y -= 22
    pg.next()

    # 3. 話をするときの心がけ
    y = _heading(c, pg, "話をするときの心がけ", accent) - 50
    c.setFont(FONT_REGULAR, 15)
    for k, line in enumerate(MANNERS):
        c.setFillColorCMYK(*MONTH_COLORS["pink"][1])
        c.roundRect(pg.left, y - 20, pg.content_w, 44, 10, stroke=0, fill=1)
        c.setFillColorCMYK(*MONTH_COLORS["pink"][0])
        c.circle(pg.left + 22, y + 2, 12, stroke=0, fill=1)
        c.setFillColorCMYK(*WHITE)
        c.setFont(FONT_BOLD, 14)
        c.drawCentredString(pg.left + 22, y - 3, str(k + 1))
        c.setFillColorCMYK(*BLACK)
        c.setFont(FONT_REGULAR, 14)
        assert pg.left + 44 + c.stringWidth(line, FONT_REGULAR, 14) <= pg.right - 8, line
        c.drawString(pg.left + 44, y - 3, line)
        y -= 62
    y -= 10
    c.setFont(FONT_REGULAR, 13)
    for line in ["この本の問いかけは、戦争・病気・お別れなど、つらくなりやすい話題を",
                 "さけて作ってあります。それでも人によって感じ方はちがいます。",
                 "ご本人の様子を見ながら、楽しく話せる話題を選んでください。"]:
        c.drawString(pg.left, y, line)
        y -= 22
    pg.next()

    # 4. もくじ
    y = _heading(c, pg, "もくじ", accent) - 44
    row_h = (y - pg.bottom - 20) / 12
    for mi, month in enumerate(spec.months):
        main, tint = MONTH_COLORS[month["color"]]
        yy = y - mi * row_h
        c.setFillColorCMYK(*tint)
        c.roundRect(pg.left, yy - row_h + 8, pg.content_w, row_h - 6, 8, stroke=0, fill=1)
        c.setFillColorCMYK(*main)
        c.setFont(FONT_ROUNDED, 20)
        c.drawString(pg.left + 12, yy - row_h / 2 - 4, f"{month['month']}月")
        c.setFont(FONT_BOLD, 13)
        c.drawString(pg.left + 70, yy - row_h / 2 - 3, month["season"])
        c.setFillColorCMYK(*BLACK)
        c.setFont(FONT_REGULAR, 11)
        room = pg.right - 50 - (pg.left + 170)
        names = [t["label"] for t in month["topics"]]
        while c.stringWidth("・".join(names) + "など", FONT_REGULAR, 11) > room:
            names.pop()
        c.drawString(pg.left + 170, yy - row_h / 2 - 3, "・".join(names) + ("など" if len(names) < 8 else ""))
        c.setFont(FONT_BOLD, 13)
        c.drawRightString(pg.right - 12, yy - row_h / 2 - 3, str(month_first_page(spec, mi)))
    pg.next()

    # 5. 12か月
    for mi, month in enumerate(spec.months):
        assert pg.number == month_first_page(spec, mi)
        draw_month_cover(c, spec, mi, left=pg.left, right=pg.right, top=pg.page_h - pg.top, bottom=pg.bottom)
        pg.next()
        topics = list(enumerate(month["topics"]))
        for p in range(0, len(topics), 2):
            draw_topic_page(c, month, topics[p:p + 2], left=pg.left, right=pg.right, top=pg.page_h - pg.top,
                            bottom=pg.bottom + 12)
            pg.next()

    # 6. 思い出メモ
    y = _heading(c, pg, "思い出メモ", accent) - 34
    c.setFillColorCMYK(*BLACK)
    c.setFont(FONT_REGULAR, 13)
    c.drawString(pg.left, y, "問いかけから広がった話や、また聞きたい話を書いておきましょう。")
    c.setStrokeColorCMYK(*LINE)
    c.setLineWidth(0.8)
    c.setDash(2, 3)
    ly = y - 40
    while ly >= pg.bottom + 30:
        c.line(pg.left, ly, pg.right, ly)
        ly -= 32
    c.setDash()
    pg.next()

    # 7. 奥付
    while pg.number < total:
        pg.next(folio=False)
    if spec.copy_ok:
        box_top = pg.bottom + 330
        box_h = 22 + 17 * len(COPY_PERMISSION)
        c.setStrokeColorCMYK(*accent)
        c.setLineWidth(1)
        c.roundRect(pg.left, box_top - box_h, pg.content_w, box_h, 8, stroke=1, fill=0)
        c.setFillColorCMYK(*BLACK)
        for k, line in enumerate(COPY_PERMISSION):
            c.setFont(FONT_BOLD if k == 0 else FONT_REGULAR, 10.5 if k == 0 else 9.5)
            c.drawString(pg.left + 14, box_top - 20 - k * 17, line)
    c.setFillColorCMYK(*BLACK)
    y = pg.bottom + 190
    c.setFont(FONT_BOLD, 16)
    c.drawString(pg.left, y, title_main)
    c.setFont(FONT_REGULAR, 11)
    y -= 26
    if spec.edition_date:
        c.drawString(pg.left, y, f"{spec.edition_date}　初版発行")
        y -= 20
    c.drawString(pg.left, y, f"発行　{spec.publisher}")
    y -= 20
    year = spec.edition_date[:4] if spec.edition_date[:4].isdigit() else ""
    c.drawString(pg.left, y, " ".join(t for t in ("Copyright", year, spec.publisher) if t))
    y -= 20
    c.setFont(FONT_REGULAR, 9)
    c.drawString(pg.left, y, ICON_CREDIT)
    pg.next(folio=False)
    c.save()
    return total


# --- 表紙 ---------------------------------------------------------------------


def _page_preview(spec: KaisoSpec, kind: str, width_pt: float, dpi: int = 300) -> ImageReader:
    import pypdfium2

    trim = kdp_spec.TRIMS[spec.trim]
    pw, ph = trim.width_in * inch, trim.height_in * inch
    buf = io.BytesIO()
    pc = canvas.Canvas(buf, pagesize=(pw, ph), initialFontName=FONT_REGULAR)
    m = 0.6 * inch
    mi = 3  # 4月
    if kind == "cover":
        draw_month_cover(pc, spec, mi, left=m, right=pw - m, top=ph - m, bottom=m)
    else:
        month = spec.months[mi]
        draw_topic_page(pc, month, list(enumerate(month["topics"]))[:2], left=m, right=pw - m, top=ph - m, bottom=m + 12)
    pc.save()
    img = pypdfium2.PdfDocument(buf.getvalue())[0].render(scale=dpi / 72 * (width_pt / pw)).to_pil().convert("CMYK")
    out = io.BytesIO()
    img.save(out, "JPEG", quality=95)
    out.seek(0)
    return ImageReader(out)


def build_cover(spec: KaisoSpec, output_path: str, *, paper: str = "white") -> tuple[float, float]:
    import math

    pages = page_count(spec)
    trim = kdp_spec.TRIMS[spec.trim]
    spine = kdp_spec.spine_width_in(pages, paper, spec.ink)
    bleed = kdp_spec.COVER_BLEED_IN
    total_w, total_h = bleed * 2 + trim.width_in * 2 + spine, bleed * 2 + trim.height_in
    W, H = total_w * inch, total_h * inch
    tw, th, sp, b = trim.width_in * inch, trim.height_in * inch, spine * inch, bleed * inch
    safe = kdp_spec.COVER_SAFE_IN * inch
    cream: CMYK = (0.0, 0.03, 0.12, 0.0)
    shadow: CMYK = (0.0, 0.10, 0.25, 0.12)
    red, blue, pink, green, orange = (MONTH_COLORS[k][0] for k in ("red", "blue", "pink", "green", "orange"))

    c = canvas.Canvas(output_path, pagesize=(W, H), initialFontName=FONT_REGULAR)
    c.setTitle(f"{spec.title}（表紙）")
    c.setAuthor(spec.publisher)
    c.setFillColorCMYK(*cream)
    c.rect(0, 0, W, H, stroke=0, fill=1)
    spine_x0, fx = b + tw, b + tw + sp
    cx, top = fx + tw / 2, b + th
    c.setFillColorCMYK(*blue)
    c.rect(spine_x0, 0, sp, H, stroke=0, fill=1)

    title_main, _, count = spec.title.rpartition(" ")
    lead, _, main_word = title_main.partition(" ")
    white = CMYKColor(0, 0, 0, 0)
    # 表表紙: 題字
    c.setFillColorCMYK(*NAVY)
    c.setFont(FONT_BOLD, 20)
    c.drawCentredString(cx, top - 0.8 * inch, "家族と、施設で。季節の話がはずむ本")
    outlined_text(c, lead, cx, top - 1.8 * inch, font=FONT_ROUNDED, size=58, fill=CMYKColor(*ORANGE), outline=white,
                  outline_width=10)
    outlined_text(c, main_word, cx, top - 3.05 * inch, font=FONT_ROUNDED,
                  size=min(96, (tw - 2 * safe - 30) / len(main_word)), fill=CMYKColor(*blue), outline=white,
                  outline_width=14)
    rib_w, rib_h, rib_y = tw * 0.66, 40, top - 3.8 * inch
    c.setFillColorCMYK(*ORANGE)
    c.roundRect(cx - rib_w / 2, rib_y, rib_w, rib_h, rib_h / 2, stroke=0, fill=1)
    c.setFillColorCMYK(*WHITE)
    c.setFont(FONT_BOLD, 19)
    c.drawCentredString(cx, rib_y + 13, f"{count}・{spec.subtitle}")

    # 12か月の輪（月ごとの最初の話題の絵を時計の文字盤のように並べる）
    ry = top - 6.55 * inch
    R = 1.85 * inch
    c.setFillColorCMYK(0.0, 0.06, 0.20, 0.0)
    c.circle(cx, ry, R + 0.62 * inch, stroke=0, fill=1)
    c.setFillColorCMYK(*WHITE)
    c.circle(cx, ry, R - 0.55 * inch, stroke=0, fill=1)
    ico = 0.78 * inch
    for k, month in enumerate(spec.months):
        a = math.radians(90 - (k + 1) * 30)
        px, py = cx + R * math.cos(a), ry + R * math.sin(a)
        col = MONTH_COLORS[month["color"]][0]
        c.setFillColorCMYK(*WHITE)
        c.circle(px, py, ico * 0.62, stroke=0, fill=1)
        draw_icon(c, month["cover_icon"], px - ico / 2, py - ico / 2 + 6, ico)
        c.setFillColorCMYK(*col)
        c.setFont(FONT_BOLD, 13)
        c.drawCentredString(px, py - ico / 2 - 6, f"{month['month']}月")
    c.setFillColorCMYK(*NAVY)
    c.setFont(FONT_ROUNDED, 22)
    c.drawCentredString(cx, ry + 16, "どの月の")
    c.drawCentredString(cx, ry - 14, "話をしよう？")
    draw_icon(c, "1f375", cx - 0.35 * inch, ry - 0.95 * inch, 0.7 * inch)

    seals = [(red, ["12か月"]), (orange, ["96の", "問いかけ"]), (green, ["話の", "たねつき"]),
             (pink, ["書きこみ", "欄つき"]), (blue, ["オール", "カラー"])]
    r = 0.50 * inch
    gap = (tw - 2 * safe - 2 * r * len(seals)) / (len(seals) + 1)
    for k, (col, lines) in enumerate(seals):
        _seal(c, fx + safe + gap * (k + 1) + r * (2 * k + 1), b + 1.25 * inch, r, col, lines)
    c.setFillColorCMYK(*NAVY)
    c.setFont(FONT_BOLD, 16)
    c.drawCentredString(cx, b + 0.45 * inch, spec.publisher)

    # 裏表紙
    bx0 = b + safe + 24
    c.setFillColorCMYK(*NAVY)
    c.setFont(FONT_ROUNDED, 30)
    c.drawString(bx0, top - safe - 50, title_main)
    c.setFont(FONT_BOLD, 15)
    c.drawString(bx0, top - safe - 80, f"{count}　{spec.subtitle}")
    lines = [
        "1月のおせちから、12月の大みそかまで。",
        "季節の話題を1か月に8つ、1年で96の問いかけにしました。",
        "聞き足すための「話のたね」と、聞いた話を書きとめる欄つき。",
        "ご家族との会話にも、施設の回想のレクリエーションにも。",
    ]
    c.setFont(FONT_REGULAR, 13)
    y = top - safe - 120
    for line in lines:
        c.drawString(bx0, y, line)
        y -= 24
    scale = 0.32
    mini_w, mini_h = tw * scale, th * scale
    mgap = 22
    mx0 = b + (tw - 2 * mini_w - mgap) / 2
    my0 = y - 20 - mini_h
    for k, kind in enumerate(("cover", "topics")):
        px = mx0 + k * (mini_w + mgap)
        c.setFillColorCMYK(*shadow)
        c.rect(px + 5, my0 - 5, mini_w, mini_h, stroke=0, fill=1)
        c.drawImage(_page_preview(spec, kind, mini_w), px, my0, mini_w, mini_h)
    if spec.copy_ok:
        tx0 = bx0
        tw0 = tw / 2 - 30
        ttop = b + safe + 80  # 左下、バーコード欄の横
        c.setFillColorCMYK(*ORANGE)
        c.roundRect(tx0, ttop - 30, tw0, 30, 15, stroke=0, fill=1)
        c.setFillColorCMYK(*WHITE)
        c.setFont(FONT_ROUNDED, 15)
        c.drawCentredString(tx0 + tw0 / 2, ttop - 20, "施設内のコピーOK")
        c.setFillColorCMYK(*NAVY)
        c.setFont(FONT_REGULAR, 11)
        for k, line in enumerate(["介護施設・デイサービスなどで、", "利用者さまとの話の時間にお使いいただけます。"]):
            c.drawString(tx0 + 6, ttop - 48 - k * 17, line)
    # 問いかけの例（3つ）
    bw, bh = (v * inch for v in kdp_spec.BARCODE_BOX_IN)
    ey = my0 - 36
    ex_w = tw - 2 * safe - 48
    assert ey - 124 - 10 >= b + safe + bh + 12, ey  # 例はバーコード欄より上に収める
    c.setFillColorCMYK(*NAVY)
    c.setFont(FONT_ROUNDED, 17)
    c.drawString(bx0, ey, "たとえば、こんな問いかけ")
    for k, (mi, ti) in enumerate(((0, 0), (6, 0), (9, 1))):
        month = spec.months[mi]
        topic = month["topics"][ti]
        yy = ey - 44 - k * 40
        col, tint = MONTH_COLORS[month["color"]]
        c.setFillColorCMYK(*tint)
        c.roundRect(bx0, yy - 10, ex_w, 34, 10, stroke=0, fill=1)
        assert bx0 + 80 + c.stringWidth(topic["q"], FONT_BOLD, 13) <= bx0 + ex_w - 6, topic["q"]
        draw_icon(c, topic["icon"], bx0 + 8, yy - 6, 26)
        c.setFillColorCMYK(*col)
        c.setFont(FONT_BOLD, 12)
        c.drawString(bx0 + 42, yy + 3, f"{month['month']}月")
        c.setFillColorCMYK(*BLACK)
        c.setFont(FONT_BOLD, 13)
        c.drawString(bx0 + 80, yy + 2, topic["q"])
    c.setFillColorCMYK(*WHITE)
    c.rect(spine_x0 - safe - bw, b + safe, bw, bh, stroke=0, fill=1)
    c.save()
    return total_w, total_h


def main() -> None:
    parser = argparse.ArgumentParser(description="思い出ばなしの本の本文・表紙PDFを作る")
    parser.add_argument("spec", help="books/kaiso-*.json")
    args = parser.parse_args()
    spec = KaisoSpec.load(args.spec)
    stem = Path(args.spec).stem
    Path("output").mkdir(exist_ok=True)
    total = build_pdf(spec, f"output/{stem}-interior.pdf")
    w, h = build_cover(spec, f"output/{stem}-cover.pdf")
    print(f"{len(spec.topics)}の話題・{total}ページ（印刷代 {kdp_spec.print_cost_jpy(total, spec.ink)}円）-> output/{stem}-interior.pdf")
    print(f"表紙 {w:.4f} x {h:.4f} in -> output/{stem}-cover.pdf")


if __name__ == "__main__":
    main()
