"""「日本のことわざ、世界ではこう言う」の本文PDFと表紙PDFを組む（A5・プレミアムカラー）。

1句1ページ。日本のことわざ・読み・意味・絵、英語・フランス語・中国語・韓国語の言い方
（原文・読み・直訳）、ひとくち話。外国語の言い方はすべて books/sekai-kotowaza-verified.json の
ものだけを使う（2つ以上の出典で実在と意味を確かめた結果。出典の URL もそこにある）。
ここでは文を足さない。句ごとの読み・意味・ひとくち話は books/sekai-kotowaza-vol1.json。
"""

from __future__ import annotations

import argparse
import io
import json
import re
from dataclasses import dataclass
from pathlib import Path

from reportlab.lib.colors import CMYKColor
from reportlab.lib.units import inch
from reportlab.lib.utils import ImageReader
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas

import kdp_spec
from art import FONT_ROUNDED, draw_icon, outlined_text
from build_book import FONT_BOLD, FONT_REGULAR, _Pager
from build_kotoba import CMYK, _seal

_ROOT = Path(__file__).resolve().parent.parent
_F = _ROOT / "assets" / "fonts"
for _name, _file in (("KR", "NanumGothic-Regular"), ("KR-B", "NanumGothic-Bold"),
                     ("LAT", "NotoSans-Regular"), ("LAT-B", "NotoSans-Bold"),
                     ("TC", "NotoSansTC-Regular"), ("TC-B", "NotoSansTC-Bold")):
    pdfmetrics.registerFont(TTFont(_name, str(_F / f"{_file}.ttf")))

LANGS = [("en", "英語"), ("fr", "フランス語"), ("zh", "中国語"), ("ko", "韓国語")]
FONT = {"en": ("LAT-B", "LAT"), "fr": ("LAT-B", "LAT"), "zh": ("TC-B", "TC"), "ko": ("KR-B", "KR")}
READ_FONT = {"zh": "LAT", "ko": FONT_REGULAR}
COLORS: dict[str, tuple[CMYK, CMYK]] = {
    "orange": ((0.0, 0.55, 0.95, 0.0), (0.0, 0.08, 0.18, 0.0)),
    "green": ((0.70, 0.0, 0.80, 0.10), (0.10, 0.0, 0.14, 0.0)),
    "blue": ((0.85, 0.45, 0.0, 0.10), (0.12, 0.04, 0.0, 0.0)),
    "pink": ((0.0, 0.70, 0.20, 0.0), (0.0, 0.10, 0.02, 0.0)),
    "purple": ((0.55, 0.75, 0.0, 0.05), (0.07, 0.10, 0.0, 0.0)),
}
INK: CMYK = (0.75, 0.55, 0.35, 0.65)
GROUND: CMYK = (0.0, 0.02, 0.06, 0.0)
WHITE: CMYK = (0, 0, 0, 0)
NAVY: CMYK = (0.95, 0.75, 0.10, 0.45)
FRONT_PAGES = 4  # 表題・はじめに・この本の見方・もくじ
BACK_PAGES = 3  # さくいん・参考にした資料・奥付
REFERENCES = [
    ("英語", "Wiktionary（英語版）、Cambridge Dictionary、Longman Dictionary of Contemporary English、"
             "The Phrase Finder、Oxford Dictionary of Proverbs、The Free Dictionary（Farlex・McGraw-Hill）、"
             "W. Preston『A Dictionary of English Proverbs』（1880）ほか"),
    ("フランス語", "Wiktionnaire（フランス語版）、Wiktionary（英語版）、Expressio、Linternaute、Larousse、"
                  "リトレ辞典、アカデミー・フランセーズ辞典ほか"),
    ("中国語", "漢典（zdic.net）、教育部《重編國語辭典修訂本》《成語典》（台湾）、Wiktionary（英語版）、"
              "Wikisource の原典（論語・史記・孟子など）ほか"),
    ("韓国語", "国立国語院『標準国語大辞典』、高麗大学校『韓国語大辞典』、国立国語院『ウリマルセム』、Wiktionary、新聞記事ほか"),
    ("日本語", "コトバンク（デジタル大辞泉ほか）、国立国会図書館レファレンス協同データベースほか"),
]
FONT_CREDIT = ["書体: Noto Sans JP、Noto Sans、Noto Sans TC、Nanum Gothic、M PLUS Rounded 1c（SIL Open Font License 1.1）",
               "イラスト: Noto Emoji（Google、SIL Open Font License 1.1）"]


@dataclass
class SekaiSpec:
    title: str
    subtitle: str
    chapters: list[dict]
    verified: str
    publisher: str = "つるはし社"
    trim: str = "a5"
    ink: str = "premium"
    edition_date: str = ""

    @classmethod
    def load(cls, path: str | Path) -> "SekaiSpec":
        return cls(**json.loads(Path(path).read_text(encoding="utf-8")))


def load_items(spec: SekaiSpec) -> list[dict]:
    """章ごとの句に、確かめた4言語の言い方を結びつけて、本の順に並べる。"""
    ver = {r["no"]: r for r in json.loads((_ROOT / spec.verified).read_text(encoding="utf-8"))}
    out = []
    for ci, ch in enumerate(spec.chapters):
        for it in ch["items"]:
            v = ver[it["src"]]
            item = dict(it, jp=v["jp"], chapter=ci, color=ch["color"])
            for k, _ in LANGS:
                x = v[k]
                item[k] = {"text": x["text"], "read": x["read"], "near": x["match"] != "同じ",
                           "lit": literal(x["note"]), "sources": x["sources"]}
            out.append(item)
    return out


def literal(note: str) -> str:
    """確認の記録から直訳を取り出す。無ければ漢字の書き方（韓国語の四字成語など）。"""
    m = re.search(r"直訳「(.+?)」", note)
    if m:
        return "直訳「" + m.group(1) + "」"
    m = re.match(r"([^。「」]{2,8})。", note)
    if m:  # 韓国語の漢字語（四字熟語など）。旧字体は日本の字体に直して見せる
        return "漢字で書くと「" + m.group(1).translate(str.maketrans("步鷄", "歩鶏")) + "」"
    raise ValueError(f"直訳が見つからない: {note[:30]}")


def page_count(spec: SekaiSpec) -> int:
    total = FRONT_PAGES + sum(1 + len(ch["items"]) for ch in spec.chapters) + BACK_PAGES
    return total + (total % 2)


def item_page(spec: SekaiSpec, index: int) -> int:
    """index 番目（0始まり）の句のページ番号（1始まり）。"""
    p, k = FRONT_PAGES, 0
    for ch in spec.chapters:
        p += 1
        for _ in ch["items"]:
            p += 1
            if k == index:
                return p
            k += 1
    raise IndexError(index)


def chapter_page(spec: SekaiSpec, ci: int) -> int:
    return FRONT_PAGES + 1 + sum(1 + len(ch["items"]) for ch in spec.chapters[:ci])


def wrap(c: canvas.Canvas, text: str, font: str, size: float, width: float, by_word: bool) -> list[str]:
    if c.stringWidth(text, font, size) <= width:
        return [text]
    lines, cur = [], ""
    tokens = re.split(r"(\s+)", text) if by_word == True else re.split(r"(?<=、)", text) if by_word == "list" else list(text)
    for tok in tokens:
        if c.stringWidth((cur + tok).rstrip(), font, size) > width and cur.strip():
            if not by_word and tok in "，。、」）？！":
                cur, tok = cur[:-1], cur[-1] + tok
            lines.append(cur.rstrip())
            cur = tok.lstrip()
        else:
            cur += tok
    if cur.strip():
        lines.append(cur.strip())
    return lines


def _setup_pager(c: canvas.Canvas, spec: SekaiSpec) -> _Pager:
    pg = _Pager(c, kdp_spec.TRIMS[spec.trim], page_count(spec))
    # A5 は小さいので、KDP の最小値（外 0.25 in）より広く、A4 より少し詰める
    pg.outside, pg.top, pg.bottom = 0.45 * inch, 0.5 * inch, 0.5 * inch
    return pg


# --- 句のページ -----------------------------------------------------------------


def draw_item(c: canvas.Canvas, it: dict, no: int, *, left: float, right: float, top: float, bottom: float) -> None:
    col, tint = COLORS[it["color"]]
    w = right - left
    c.setFillColorCMYK(*col)
    c.roundRect(left, top - 24, w, 24, 6, stroke=0, fill=1)
    c.setFillColorCMYK(*WHITE)
    c.setFont(FONT_BOLD, 10.5)
    c.drawString(left + 10, top - 16, f"世界のことわざ　{no:02d}")
    # ことわざと絵
    ic = 70
    c.setFillColorCMYK(*tint)
    c.circle(right - ic / 2 - 2, top - 34 - ic / 2, ic / 2 + 4, stroke=0, fill=1)
    draw_icon(c, it["icon"], right - ic - 2 + ic * 0.1, top - 34 - ic * 0.92, ic * 0.8)
    if it.get("icon2"):
        draw_icon(c, it["icon2"], right - 32, top - 34 - ic - 4, 30)
    tw = w - ic - 16
    c.setFillColorCMYK(*INK)
    c.setFont(FONT_REGULAR, 9.5)
    c.drawString(left + 2, top - 44, it["kana"])
    fs = 27
    while c.stringWidth(it["jp"], FONT_ROUNDED, fs) > tw:
        fs -= 0.5
    c.setFillColorCMYK(*col)
    c.setFont(FONT_ROUNDED, fs)
    c.drawString(left, top - 44 - fs - 2, it["jp"])
    y = top - 44 - fs - 20
    c.setFillColorCMYK(*INK)
    c.setFont(FONT_REGULAR, 10.5)
    for line in wrap(c, it["mean"], FONT_REGULAR, 10.5, tw, False):
        c.drawString(left, y, line)
        y -= 16
    y = min(y, top - 34 - ic - 12) - 10
    c.setFillColorCMYK(*col)
    c.setFont(FONT_ROUNDED, 13)
    c.drawString(left, y, "世界では、こう言う")
    c.setStrokeColorCMYK(*col)
    c.setLineWidth(1.4)
    c.line(left, y - 6, right, y - 6)
    y -= 14
    tx = left + 70
    avail = right - tx - 8
    for k, lang in LANGS:
        x = it[k]
        bf, rf = FONT[k]
        ofs = 13.5
        lines = wrap(c, x["text"], bf, ofs, avail - (58 if x["near"] else 0), k in ("en", "fr", "ko"))
        while len(lines) > 2:
            ofs -= 0.5
            lines = wrap(c, x["text"], bf, ofs, avail - (58 if x["near"] else 0), k in ("en", "fr", "ko"))
        lit_lines = wrap(c, x["lit"], FONT_REGULAR, 10, avail, False)
        rh = 16 + 17 * len(lines) + (14 if x["read"] else 0) + 14.5 * len(lit_lines) + 4
        c.setFillColorCMYK(*WHITE)
        c.roundRect(left, y - rh, w, rh, 7, stroke=0, fill=1)
        c.setFillColorCMYK(*tint)
        c.roundRect(left, y - rh, 60, rh, 7, stroke=0, fill=1)
        c.setFillColorCMYK(*col)
        c.setFont(FONT_BOLD, 10)
        c.drawCentredString(left + 30, y - rh / 2 - 3.5, lang)
        c.setFillColorCMYK(*INK)
        yy = y - 19
        for li, line in enumerate(lines):
            c.setFont(bf, ofs)
            c.drawString(tx, yy, line)
            if li == 0 and x["near"]:
                nx = tx + c.stringWidth(line, bf, ofs) + 6
                c.setFillColorCMYK(0, 0, 0, 0.12)
                c.roundRect(nx, yy - 3, 50, 13, 6.5, stroke=0, fill=1)
                c.setFillColorCMYK(0, 0, 0, 0.72)
                c.setFont(FONT_BOLD, 7.5)
                c.drawCentredString(nx + 25, yy + 0.5, "近い言い方")
                c.setFillColorCMYK(*INK)
            yy -= 17
        if x["read"]:
            c.setFillColorCMYK(0, 0, 0, 0.58)
            c.setFont(READ_FONT[k], 9.5)
            c.drawString(tx, yy + 2, x["read"])
            yy -= 14
        c.setFillColorCMYK(*INK)
        c.setFont(FONT_REGULAR, 10)
        for line in lit_lines:
            c.drawString(tx, yy + 1, line)
            yy -= 14.5
        y -= rh + 4
    # ひとくち話
    y -= 3
    story = wrap(c, it["story"], FONT_REGULAR, 10, w - 24, False)
    sh = 28 + 15.5 * len(story)
    assert y - sh >= bottom, (it["jp"], y - sh - bottom)
    c.setFillColorCMYK(*tint)
    c.roundRect(left, y - sh, w, sh, 8, stroke=0, fill=1)
    c.setFillColorCMYK(*col)
    c.setFont(FONT_BOLD, 9.5)
    c.drawString(left + 12, y - 15, "ひとくち話")
    c.setFillColorCMYK(*INK)
    c.setFont(FONT_REGULAR, 10)
    for k, line in enumerate(story):
        c.drawString(left + 12, y - 32 - k * 15.5, line)


def draw_chapter(c: canvas.Canvas, spec: SekaiSpec, items: list[dict], ci: int, *, left: float, right: float,
                 top: float, bottom: float) -> None:
    ch = spec.chapters[ci]
    col, tint = COLORS[ch["color"]]
    w = right - left
    c.setFillColorCMYK(*tint)
    c.roundRect(left, top - 190, w, 190, 14, stroke=0, fill=1)
    c.setFillColorCMYK(*col)
    c.setFont(FONT_BOLD, 13)
    c.drawCentredString((left + right) / 2, top - 40, f"第{ci + 1}章")
    c.setFont(FONT_ROUNDED, 34)
    c.drawCentredString((left + right) / 2, top - 86, ch["title"])
    mine = [(k, it) for k, it in enumerate(items) if it["chapter"] == ci]
    for j, (_, it) in enumerate(mine):
        draw_icon(c, it["icon"], left + 18 + j * (w - 36 - 26) / 9, top - 150, 26)
    y = top - 222
    for j, (k, it) in enumerate(mine):
        c.setFillColorCMYK(*col)
        c.setFont(FONT_BOLD, 10)
        c.drawString(left + 6, y, f"{k + 1:02d}")
        c.setFillColorCMYK(*INK)
        c.setFont(FONT_REGULAR, 11.5)
        c.drawString(left + 34, y, it["jp"])
        c.setFont(FONT_REGULAR, 10)
        c.drawRightString(right - 6, y, f"{item_page(spec, k)}")
        c.setStrokeColorCMYK(*tint)
        c.setLineWidth(0.8)
        c.line(left, y - 8, right, y - 8)
        y -= 27
    assert y >= bottom


# --- 本文 ---------------------------------------------------------------------


def _heading(c: canvas.Canvas, pg: _Pager, text: str, color: CMYK = NAVY) -> float:
    top = pg.page_h - pg.top
    c.setFillColorCMYK(*color)
    c.setFont(FONT_ROUNDED, 20)
    c.drawString(pg.left, top - 22, text)
    c.setStrokeColorCMYK(*color)
    c.setLineWidth(1.5)
    c.line(pg.left, top - 32, pg.right, top - 32)
    return top - 32


def _para(c: canvas.Canvas, pg: _Pager, text: str, y: float, fs: float = 10.5, gap: float = 17) -> float:
    c.setFillColorCMYK(*INK)
    c.setFont(FONT_REGULAR, fs)
    for line in wrap(c, text, FONT_REGULAR, fs, pg.content_w, False):
        c.drawString(pg.left, y, line)
        y -= gap
    return y


def build_pdf(spec: SekaiSpec, output_path: str) -> int:
    trim = kdp_spec.TRIMS[spec.trim]
    total = page_count(spec)
    items = load_items(spec)
    c = canvas.Canvas(output_path, pagesize=(trim.width_in * inch, trim.height_in * inch), initialFontName=FONT_REGULAR)
    c.setTitle(spec.title)
    c.setAuthor(spec.publisher)
    c.setCreator(spec.publisher)
    pg = _setup_pager(c, spec)
    mid = lambda: (pg.left + pg.right) / 2  # noqa: E731

    # 1. 表題
    c.setFillColorCMYK(*NAVY)
    c.setFont(FONT_ROUNDED, 22)
    c.drawCentredString(mid(), pg.page_h * 0.66, "日本のことわざ、")
    c.setFont(FONT_ROUNDED, 30)
    c.drawCentredString(mid(), pg.page_h * 0.66 - 44, "世界ではこう言う")
    c.setFont(FONT_BOLD, 10.5)
    c.drawCentredString(mid(), pg.page_h * 0.66 - 76, spec.subtitle)
    draw_icon(c, "1f30f", mid() - 40, pg.page_h * 0.66 - 180, 80)
    c.setFont(FONT_REGULAR, 11)
    c.drawCentredString(mid(), pg.page_h * 0.14, spec.publisher)
    pg.next(folio=False)

    # 2. はじめに
    y = _heading(c, pg, "はじめに") - 30
    for text in [
        "「猿も木から落ちる」は、英語では「ホメロスでさえ居眠りをする」、フランス語では「つまずかないほど良い馬はいない」。"
        "韓国語では、日本と同じ「猿も木から落ちる」です。",
        "同じ気持ちを、国によってちがうものにたとえている。そのちがいを見くらべるのが、この本の楽しみ方です。",
        "日本のよく知られたことわざ50を選び、英語・フランス語・中国語・韓国語で同じ意味の言い方を並べました。"
        "外国語の言い方は、どれも2つ以上の辞書や資料で、実際に使われていることと意味を確かめたものです。",
        "ぴったり同じ意味の言い方がない言語は、意味の近い言い方に「近い言い方」の札をつけて載せています。",
    ]:
        y = _para(c, pg, text, y) - 12
    pg.next()

    # 3. この本の見方
    y = _heading(c, pg, "この本の見方") - 30
    for head, text in [
        ("4つのことば", "どのページも、英語・フランス語・中国語・韓国語の順に並んでいます。"),
        ("原文", "それぞれの国のことばで書いたものです。中国語は台湾などで使う繁体字で書いています。"),
        ("読み方", "中国語はピンイン（ローマ字の読み）、韓国語はカタカナの読みをつけました。カタカナは、およその音です。"),
        ("直訳", "原文をことばどおりに訳したものです。たとえに使われているものの、国によるちがいがわかります。"),
        ("近い言い方", "日本のことわざと少し意味がずれるものにつけています。"),
        ("ひとくち話", "ことわざの出どころや、国ごとのたとえのちがいを紹介します。"),
    ]:
        c.setFillColorCMYK(*COLORS["orange"][0])
        c.setFont(FONT_BOLD, 11)
        c.drawString(pg.left, y, head)
        y = _para(c, pg, text, y - 18, fs=10, gap=15) - 10
    pg.next()

    # 4. もくじ
    y = _heading(c, pg, "もくじ") - 26
    for ci, ch in enumerate(spec.chapters):
        col = COLORS[ch["color"]][0]
        c.setFillColorCMYK(*col)
        c.setFont(FONT_ROUNDED, 12)
        c.drawString(pg.left, y, f"第{ci + 1}章　{ch['title']}")
        c.setFont(FONT_REGULAR, 10)
        c.drawRightString(pg.right, y, str(chapter_page(spec, ci)))
        y -= 17
        c.setFillColorCMYK(*INK)
        c.setFont(FONT_REGULAR, 8.5)
        names = "・".join(it["jp"] for it in items if it["chapter"] == ci)
        for line in wrap(c, names, FONT_REGULAR, 8.5, pg.content_w - 10, False):
            c.drawString(pg.left + 10, y, line)
            y -= 13
        y -= 12
    for label, page in (("さくいん", total - 2), ("参考にした資料", total - 1)):
        c.setFillColorCMYK(*NAVY)
        c.setFont(FONT_ROUNDED, 12)
        c.drawString(pg.left, y, label)
        c.setFont(FONT_REGULAR, 10)
        c.drawRightString(pg.right, y, str(page))
        y -= 20
    assert y >= pg.bottom
    pg.next()

    # 5. 各章
    for ci in range(len(spec.chapters)):
        assert pg.number == chapter_page(spec, ci)
        draw_chapter(c, spec, items, ci, left=pg.left, right=pg.right, top=pg.page_h - pg.top, bottom=pg.bottom + 14)
        pg.next()
        for k, it in enumerate(items):
            if it["chapter"] != ci:
                continue
            assert pg.number == item_page(spec, k)
            draw_item(c, it, k + 1, left=pg.left, right=pg.right, top=pg.page_h - pg.top, bottom=pg.bottom + 14)
            pg.next()

    # 6. さくいん（五十音順）
    y = _heading(c, pg, "さくいん") - 22
    order = sorted(range(len(items)), key=lambda k: items[k]["kana"])
    col_w = pg.content_w / 2
    per = 25
    for n, k in enumerate(order):
        x0 = pg.left + (n // per) * col_w
        yy = y - (n % per) * 17.5
        c.setFillColorCMYK(*INK)
        c.setFont(FONT_REGULAR, 8.5)
        name = items[k]["jp"]
        fs = 8.5
        while c.stringWidth(name, FONT_REGULAR, fs) > col_w - 30:
            fs -= 0.25
        c.setFont(FONT_REGULAR, fs)
        c.drawString(x0, yy, name)
        c.setFont(FONT_REGULAR, 8.5)
        c.drawRightString(x0 + col_w - 8, yy, str(item_page(spec, k)))
    pg.next()

    # 7. 参考にした資料
    y = _heading(c, pg, "参考にした資料") - 26
    y = _para(c, pg, "外国語の言い方は、1つずつ、次のような辞書や資料のうち2つ以上で確かめました。", y, fs=9.5, gap=15) - 8
    for lang, text in REFERENCES:
        c.setFillColorCMYK(*COLORS["blue"][0])
        c.setFont(FONT_BOLD, 10)
        c.drawString(pg.left, y, lang)
        c.setFillColorCMYK(*INK)
        c.setFont(FONT_REGULAR, 9)
        y -= 16
        for line in wrap(c, text, FONT_REGULAR, 9, pg.content_w, "list"):
            c.drawString(pg.left, y, line)
            y -= 14
        y -= 8
    assert y >= pg.bottom
    pg.next()

    # 8. 奥付
    while pg.number < total:
        pg.next(folio=False)
    c.setFillColorCMYK(*INK)
    y = pg.bottom + 150
    c.setFont(FONT_BOLD, 12)
    c.drawString(pg.left, y, spec.title)
    c.setFont(FONT_REGULAR, 9)
    y -= 20
    if spec.edition_date:
        c.drawString(pg.left, y, f"{spec.edition_date}　初版発行")
        y -= 15
    c.drawString(pg.left, y, f"発行　{spec.publisher}")
    y -= 15
    year = spec.edition_date[:4] if spec.edition_date[:4].isdigit() else ""
    c.drawString(pg.left, y, " ".join(t for t in ("Copyright", year, spec.publisher) if t))
    y -= 20
    c.setFont(FONT_REGULAR, 7.5)
    for line in FONT_CREDIT:
        for part in wrap(c, line, FONT_REGULAR, 7.5, pg.content_w, False):
            c.drawString(pg.left, y, part)
            y -= 11
    pg.next(folio=False)
    c.save()
    return total


# --- 表紙 ---------------------------------------------------------------------


def _page_preview(spec: SekaiSpec, index: int, width_pt: float, dpi: int = 300) -> ImageReader:
    import pypdfium2

    trim = kdp_spec.TRIMS[spec.trim]
    pw, ph = trim.width_in * inch, trim.height_in * inch
    buf = io.BytesIO()
    pc = canvas.Canvas(buf, pagesize=(pw, ph), initialFontName=FONT_REGULAR)
    pc.setFillColorCMYK(*GROUND)
    pc.rect(0, 0, pw, ph, stroke=0, fill=1)
    m = 0.45 * inch
    draw_item(pc, load_items(spec)[index], index + 1, left=m, right=pw - m, top=ph - m, bottom=m)
    pc.save()
    img = pypdfium2.PdfDocument(buf.getvalue())[0].render(scale=dpi / 72 * (width_pt / pw)).to_pil().convert("CMYK")
    out = io.BytesIO()
    img.save(out, "JPEG", quality=95)
    out.seek(0)
    return ImageReader(out)


def build_cover(spec: SekaiSpec, output_path: str, *, paper: str = "white") -> tuple[float, float]:
    pages = page_count(spec)
    trim = kdp_spec.TRIMS[spec.trim]
    spine = kdp_spec.spine_width_in(pages, paper, spec.ink)
    bleed = kdp_spec.COVER_BLEED_IN
    total_w, total_h = bleed * 2 + trim.width_in * 2 + spine, bleed * 2 + trim.height_in
    W, H = total_w * inch, total_h * inch
    tw, th, sp, b = trim.width_in * inch, trim.height_in * inch, spine * inch, bleed * inch
    safe = kdp_spec.COVER_SAFE_IN * inch
    items = load_items(spec)
    cream: CMYK = (0.0, 0.03, 0.10, 0.0)

    c = canvas.Canvas(output_path, pagesize=(W, H), initialFontName=FONT_REGULAR)
    c.setTitle(f"{spec.title}（表紙）")
    c.setAuthor(spec.publisher)
    c.setFillColorCMYK(*cream)
    c.rect(0, 0, W, H, stroke=0, fill=1)
    spine_x0, fx = b + tw, b + tw + sp
    cx, top = fx + tw / 2, b + th
    c.setFillColorCMYK(*NAVY)
    c.rect(spine_x0, 0, sp, H, stroke=0, fill=1)
    # 表表紙
    c.setFillColorCMYK(*NAVY)
    c.rect(fx, top - 2.05 * inch, tw + b, 2.05 * inch + b, stroke=0, fill=1)
    white = CMYKColor(0, 0, 0, 0)
    c.setFillColorCMYK(*WHITE)
    c.setFont(FONT_BOLD, 12)
    c.drawCentredString(cx, top - 0.62 * inch, "英語・フランス語・中国語・韓国語で読む")
    outlined_text(c, "日本のことわざ、", cx, top - 1.1 * inch, font=FONT_ROUNDED, size=24,
                  fill=CMYKColor(0.0, 0.10, 0.85, 0.0), outline=CMYKColor(*NAVY), outline_width=4)
    outlined_text(c, "世界ではこう言う", cx, top - 1.72 * inch, font=FONT_ROUNDED, size=33,
                  fill=white, outline=CMYKColor(*NAVY), outline_width=4)
    # 見本: 猿も木から落ちる を4言語で
    sample = items[10]
    assert sample["jp"] == "猿も木から落ちる"
    draw_icon(c, "1f412", cx - 0.55 * inch, top - 3.3 * inch, 1.1 * inch)
    c.setFillColorCMYK(*COLORS["orange"][0])
    c.setFont(FONT_ROUNDED, 20)
    c.drawCentredString(cx, top - 3.72 * inch, sample["jp"])
    y = top - 4.05 * inch
    card_w = tw - 2 * safe - 20
    for k, lang in LANGS:
        col = [COLORS["orange"], COLORS["green"], COLORS["blue"], COLORS["pink"]][[x for x, _ in LANGS].index(k)]
        c.setFillColorCMYK(*WHITE)
        c.roundRect(cx - card_w / 2, y - 26, card_w, 26, 8, stroke=0, fill=1)
        c.setFillColorCMYK(*col[1])
        c.roundRect(cx - card_w / 2, y - 26, 62, 26, 8, stroke=0, fill=1)
        c.setFillColorCMYK(*col[0])
        c.setFont(FONT_BOLD, 9)
        c.drawCentredString(cx - card_w / 2 + 31, y - 16.5, lang)
        c.setFillColorCMYK(*INK)
        bf = FONT[k][0]
        fs = 11
        while c.stringWidth(sample[k]["text"], bf, fs) > card_w - 76:
            fs -= 0.5
        c.setFont(bf, fs)
        c.drawString(cx - card_w / 2 + 70, y - 17, sample[k]["text"])
        y -= 32
    seals = [((0.0, 0.80, 0.70, 0.05), ["50の", "ことわざ"]), (COLORS["green"][0], ["4つの", "ことば"]),
             (COLORS["blue"][0], ["辞書で", "確かめた"]), (COLORS["pink"][0], ["オール", "カラー"])]
    r = 0.38 * inch
    gap = (tw - 2 * safe - 2 * r * len(seals)) / (len(seals) + 1)
    for k, (col, lines) in enumerate(seals):
        _seal(c, fx + safe + gap * (k + 1) + r * (2 * k + 1), b + 0.95 * inch, r, col, lines)
    c.setFillColorCMYK(*NAVY)
    c.setFont(FONT_BOLD, 11)
    c.drawCentredString(cx, b + safe + 6, spec.publisher)
    # 裏表紙
    bx0 = b + safe + 14
    c.setFillColorCMYK(*NAVY)
    c.setFont(FONT_ROUNDED, 16)
    c.drawString(bx0, top - safe - 30, spec.title)
    c.setFont(FONT_REGULAR, 9.5)
    y = top - safe - 54
    for line in ["「猫に小判」は、英語では「豚に真珠」。",
                 "「犬猿の仲」は、フランス語では「犬と猫」。",
                 "同じ気持ちを、国ごとにちがうものにたとえる。",
                 "そのちがいを見くらべる、50のことわざの本です。",
                 "外国語の言い方は、どれも辞書や資料で確かめました。"]:
        c.drawString(bx0, y, line)
        y -= 16
    mini_w = tw * 0.46
    mini_h = th * 0.46
    mx = b + (tw - mini_w) / 2
    my = y - 14 - mini_h
    c.setFillColorCMYK(0.0, 0.10, 0.25, 0.12)
    c.rect(mx + 4, my - 4, mini_w, mini_h, stroke=0, fill=1)
    c.drawImage(_page_preview(spec, 30, mini_w), mx, my, mini_w, mini_h)
    bw, bh = (v * inch for v in kdp_spec.BARCODE_BOX_IN)
    assert my >= b + safe + bh + 8, my
    c.setFillColorCMYK(*WHITE)
    c.rect(spine_x0 - safe - bw, b + safe, bw, bh, stroke=0, fill=1)
    c.save()
    return total_w, total_h


def main() -> None:
    parser = argparse.ArgumentParser(description="世界のことわざの本の本文・表紙PDFを作る")
    parser.add_argument("spec", help="books/sekai-kotowaza-*.json")
    args = parser.parse_args()
    spec = SekaiSpec.load(args.spec)
    stem = Path(args.spec).stem
    Path("output").mkdir(exist_ok=True)
    total = build_pdf(spec, f"output/{stem}-interior.pdf")
    w, h = build_cover(spec, f"output/{stem}-cover.pdf")
    cost = kdp_spec.print_cost_jpy(total, spec.ink, spec.trim)
    print(f"{total}ページ（印刷代 {cost}円）-> output/{stem}-interior.pdf")
    print(f"表紙 {w:.4f} x {h:.4f} in -> output/{stem}-cover.pdf")


if __name__ == "__main__":
    main()
