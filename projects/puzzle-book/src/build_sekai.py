"""「日本のことわざ、世界ではこう言う」の本文PDFと表紙PDFを組む（A5・プレミアムカラー・裁ち落としあり）。

1句1ページ。日本のことわざ・読み・意味・絵、英語・フランス語・中国語・韓国語の言い方
（原文・読み・直訳）、ひとくち話。外国語の言い方はすべて books/sekai-kotowaza-verified.json の
ものだけを使う（2つ以上の出典で実在と意味を確かめた結果。出典の URL もそこにある）。
ここでは文を足さない。句ごとの読み・意味・ひとくち話は books/sekai-kotowaza-vol1.json。

本文は裁ち落としあり（色を紙の端まで入れるため）。KDP の決まり（topic/GVBQ3CMEQW3W2VL6）:
ページは 判型の幅 + 0.125 in、高さ + 0.25 in。外側に裁ち落としが付くので、奇数ページは右、
偶数ページは左に 0.125 in 余分がある。文字は仕上がり線から 0.375 in 以上内側。
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
from build_book import FONT_BOLD, FONT_REGULAR
from build_kotoba import CMYK, _seal

_ROOT = Path(__file__).resolve().parent.parent
_F = _ROOT / "assets" / "fonts"
for _name, _file in (("KR", "NanumGothic-Regular"), ("KR-B", "NanumGothic-Bold"),
                     ("LAT", "NotoSans-Regular"), ("LAT-B", "NotoSans-Bold"),
                     ("TC", "NotoSansTC-Regular"), ("TC-B", "NotoSansTC-Bold")):
    pdfmetrics.registerFont(TTFont(_name, str(_F / f"{_file}.ttf")))

BLEED = kdp_spec.COVER_BLEED_IN * inch  # 本文の裁ち落としも 0.125 in
MARGIN_IN = 0.55 * inch  # ノド側（KDP の最小 0.375 in より広く）
MARGIN_OUT = 0.45 * inch
MARGIN_TOP = 0.45 * inch
MARGIN_BOTTOM = 0.62 * inch  # ページ番号の分を空ける
SAFE = 0.375 * inch  # 文字は仕上がり線からこれ以上内側（裁ち落としありの最小）

# 挿絵（Gemini で描いたもの）。置いてあれば絵文字の代わりに丸く切り抜いて使う。
# 名前: item01〜item50（各句）、chapter1〜5（章扉）、cover（表紙）、title（表題・おわりに）
ART_DIR = _ROOT / "assets" / "sekai-art"
ART_CREDIT = "挿絵: Google Gemini で生成"


def art_path(key: str) -> Path | None:
    for ext in (".png", ".jpg", ".jpeg", ".webp"):
        path = ART_DIR / f"{key}{ext}"
        if path.exists():
            return path
    return None


def has_art() -> bool:
    return ART_DIR.exists() and any(ART_DIR.iterdir())


def draw_art(c: canvas.Canvas, key: str, cx: float, cy: float, r: float) -> bool:
    """挿絵を中心 (cx, cy)・半径 r の丸に切り抜いて置く。四隅（Gemini の透かしが入る所）は丸の外に落ちる。"""
    path = art_path(key)
    if path is None:
        return False
    from PIL import Image

    img = Image.open(path).convert("RGB")
    side = min(img.size)
    img = img.crop(((img.width - side) // 2, (img.height - side) // 2,
                    (img.width + side) // 2, (img.height + side) // 2))
    need = int(2 * r / 72 * 300) + 1
    assert side >= need, f"{path.name} は {side}px。この大きさ（{2 * r / 72:.2f}in）には {need}px 以上が要る"
    out = io.BytesIO()
    img.convert("CMYK").save(out, "JPEG", quality=94)
    out.seek(0)
    c.saveState()
    clip = c.beginPath()
    clip.circle(cx, cy, r)
    c.clipPath(clip, stroke=0, fill=0)
    c.drawImage(ImageReader(out), cx - r, cy - r, 2 * r, 2 * r)
    c.restoreState()
    return True

# 言語ごとの色と、その言語の文字での名前（本全体で同じ）
LANGS = [("en", "英語"), ("fr", "フランス語"), ("zh", "中国語"), ("ko", "韓国語")]
NATIVE = {"en": ("English", "LAT-B"), "fr": ("Français", "LAT-B"), "zh": ("中文", "TC-B"), "ko": ("한국어", "KR-B")}
LANG_COLOR: dict[str, CMYK] = {
    "en": (0.90, 0.55, 0.0, 0.15),
    "fr": (0.55, 0.80, 0.0, 0.05),
    "zh": (0.0, 0.85, 0.75, 0.05),
    "ko": (0.85, 0.05, 0.45, 0.10),
}
LANG_TINT: dict[str, CMYK] = {k: tuple(round(v * 0.1, 3) for v in c) for k, c in LANG_COLOR.items()}
FONT = {"en": ("LAT-B", "LAT"), "fr": ("LAT-B", "LAT"), "zh": ("TC-B", "TC"), "ko": ("KR-B", "KR")}
READ_FONT = {"zh": "LAT", "ko": FONT_REGULAR}
COLORS: dict[str, tuple[CMYK, CMYK]] = {
    "orange": ((0.0, 0.58, 0.95, 0.0), (0.0, 0.07, 0.16, 0.0)),
    "green": ((0.72, 0.0, 0.85, 0.12), (0.09, 0.0, 0.12, 0.0)),
    "blue": ((0.88, 0.45, 0.0, 0.12), (0.11, 0.04, 0.0, 0.0)),
    "pink": ((0.0, 0.72, 0.25, 0.0), (0.0, 0.09, 0.03, 0.0)),
    "purple": ((0.58, 0.78, 0.0, 0.05), (0.07, 0.09, 0.0, 0.0)),
}
INK: CMYK = (0.72, 0.55, 0.35, 0.70)
SUB: CMYK = (0.35, 0.25, 0.20, 0.35)
PAPER: CMYK = (0.0, 0.015, 0.05, 0.0)
WHITE: CMYK = (0, 0, 0, 0)
NAVY: CMYK = (0.95, 0.75, 0.10, 0.45)
GOLD: CMYK = (0.0, 0.18, 0.85, 0.0)
FRONT_PAGES = 5  # 表題・はじめに・この本の見方・4つのことば・もくじ
BACK_PAGES = 4  # おわりに・さくいん・参考にした資料・奥付
REGIONS = {
    "en": "イギリス・アメリカ・カナダ・オーストラリアなど",
    "fr": "フランス・ベルギー・スイス・カナダ（ケベック州）など",
    "zh": "中国・台湾・シンガポールなど",
    "ko": "韓国・北朝鮮",
}
READ_NOTE = {
    "en": "原文のあとに、直訳をつけています。",
    "fr": "原文のあとに、直訳をつけています。",
    "zh": "台湾などで使う繁体字で書き、ピンイン（ローマ字の読み）をつけています。",
    "ko": "ハングルに、カタカナのおよその読みをつけています。",
}
REFERENCES = [
    ("英語", "Wiktionary（英語版）、Cambridge Dictionary、Longman Dictionary of Contemporary English、"
             "The Phrase Finder、Oxford Dictionary of Proverbs、The Free Dictionary（Farlex・McGraw-Hill）、"
             "W. Preston『A Dictionary of English Proverbs』（1880）ほか"),
    ("フランス語", "Wiktionnaire（フランス語版）、Wiktionary（英語版）、Expressio、Linternaute、Larousse、"
                  "リトレ辞典、アカデミー・フランセーズ辞典ほか"),
    ("中国語", "漢典（zdic.net）、教育部《重編國語辭典修訂本》、教育部《成語典》（台湾）、Wiktionary（英語版）、"
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
            item = dict(it, jp=v["jp"], chapter=ci, color=ch["color"], chapter_title=ch["title"])
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


_KINSOKU_HEAD = "，。、」）？！・ー』"


def wrap(c: canvas.Canvas, text: str, font: str, size: float, width: float, by_word=False) -> list[str]:
    """by_word=True は欧文（空白で折る）、"list" は「、」の区切りで折る、False は1字ずつ（行頭禁則つき）。"""
    if c.stringWidth(text, font, size) <= width:
        return [text]
    lines, cur = [], ""
    if by_word is True:
        tokens = re.split(r"(\s+)", text)
    elif by_word == "list":
        tokens = re.split(r"(?<=、)", text)
    else:
        tokens = list(text)
    for tok in tokens:
        if c.stringWidth((cur + tok).rstrip(), font, size) > width and cur.strip():
            if by_word is False and tok in _KINSOKU_HEAD:
                cur, tok = cur[:-1], cur[-1] + tok
            lines.append(cur.rstrip())
            cur = tok.lstrip()
        else:
            cur += tok
    if cur.strip():
        lines.append(cur.strip())
    return lines


# --- ページの枠（裁ち落としあり） ---------------------------------------------------


@dataclass
class Frame:
    """1ページの寸法。x0..x1 / y0..y1 が仕上がり線、left..right / bottom..top が本文の枠。"""
    number: int
    pw: float
    ph: float
    x0: float
    x1: float
    y0: float
    y1: float

    @property
    def odd(self) -> bool:
        return self.number % 2 == 1

    @property
    def left(self) -> float:
        return self.x0 + (MARGIN_IN if self.odd else MARGIN_OUT)

    @property
    def right(self) -> float:
        return self.x1 - (MARGIN_OUT if self.odd else MARGIN_IN)

    @property
    def top(self) -> float:
        return self.y1 - MARGIN_TOP

    @property
    def bottom(self) -> float:
        return self.y0 + MARGIN_BOTTOM

    @property
    def width(self) -> float:
        return self.right - self.left


def frame(spec: SekaiSpec, number: int) -> Frame:
    t = kdp_spec.TRIMS[spec.trim]
    tw, th = t.width_in * inch, t.height_in * inch
    x0 = 0.0 if number % 2 == 1 else BLEED  # 奇数ページは右、偶数ページは左に裁ち落とし
    return Frame(number, tw + BLEED, th + 2 * BLEED, x0, x0 + tw, BLEED, BLEED + th)


def fill_page(c: canvas.Canvas, f: Frame, color: CMYK) -> None:
    c.setFillColorCMYK(*color)
    c.rect(0, 0, f.pw, f.ph, stroke=0, fill=1)


def folio(c: canvas.Canvas, f: Frame, label: str = "") -> None:
    """ページ番号と柱。外側（奇数は右、偶数は左）に置く。"""
    y = f.y0 + 0.40 * inch
    c.setFillColorCMYK(*SUB)
    c.setFont(FONT_BOLD, 9)
    num = str(f.number)
    if f.odd:
        c.drawRightString(f.right, y, num)
        if label:
            c.setFont(FONT_REGULAR, 7.5)
            c.drawRightString(f.right - c.stringWidth(num, FONT_BOLD, 9) - 10, y + 0.5, label)
    else:
        c.drawString(f.left, y, num)
        if label:
            c.setFont(FONT_REGULAR, 7.5)
            c.drawString(f.left + c.stringWidth(num, FONT_BOLD, 9) + 10, y + 0.5, label)


def lang_badge(c: canvas.Canvas, k: str, x: float, y: float, w: float, h: float) -> None:
    """言語の札（その言語の文字での名前と、日本語の名前）。(x, y) は左下。"""
    c.setFillColorCMYK(*LANG_COLOR[k])
    c.roundRect(x, y, w, h, 7, stroke=0, fill=1)
    name, font = NATIVE[k]
    c.setFillColorCMYK(*WHITE)
    fs = 12.5
    while c.stringWidth(name, font, fs) > w - 10:
        fs -= 0.5
    if h < 30:
        c.setFont(font, min(fs, h * 0.5))
        c.drawCentredString(x + w / 2, y + h / 2 - min(fs, h * 0.5) * 0.35, name)
        return
    c.setFont(font, fs)
    c.drawCentredString(x + w / 2, y + h / 2 + 1, name)
    c.setFont(FONT_REGULAR, 7.5)
    c.drawCentredString(x + w / 2, y + h / 2 - 10.5, dict(LANGS)[k])


# --- 句のページ -----------------------------------------------------------------


# 1ページに収まらないときに、字を一段ずつ小さくする段階
DENSITY = [
    {"ofs": 14.0, "lit": 10.0, "litg": 14.0, "story": 10.0, "storyg": 15.5, "gap": 6, "band": 128, "mean": 10.0, "read": 9.0, "readg": 14},
    {"ofs": 13.0, "lit": 9.5, "litg": 13.5, "story": 9.5, "storyg": 14.5, "gap": 4, "band": 122, "mean": 9.5, "read": 8.5, "readg": 13},
    {"ofs": 12.5, "lit": 9.0, "litg": 12.5, "story": 9.0, "storyg": 13.5, "gap": 3, "band": 118, "mean": 9.0, "read": 8.5, "readg": 12},
]


def _card_layout(c: canvas.Canvas, x: dict, k: str, avail: float, P: dict) -> tuple[list[str], float, list[str]]:
    bf, _ = FONT[k]
    ofs = P["ofs"]
    room = avail - (56 if x["near"] else 0)
    lines = wrap(c, x["text"], bf, ofs, room, k in ("en", "fr", "ko"))
    while len(lines) > 2 and ofs > 10:
        ofs -= 0.5
        lines = wrap(c, x["text"], bf, ofs, room, k in ("en", "fr", "ko"))
    lit = wrap(c, x["lit"], FONT_REGULAR, P["lit"], avail, False)
    return lines, ofs, lit


def draw_item(c: canvas.Canvas, f: Frame, it: dict, no: int) -> dict:
    """1句のページ。標準の字の大きさで収まらなければ、一段ずつ小さくして組む。"""
    for dense in range(len(DENSITY)):
        try:
            _draw_item(canvas.Canvas(io.BytesIO(), pagesize=(f.pw, f.ph)), f, it, no, DENSITY[dense])
        except AssertionError:
            continue
        return _draw_item(c, f, it, no, DENSITY[dense])
    raise AssertionError(f"1ページに収まらない: {it['jp']}")


def _draw_item(c: canvas.Canvas, f: Frame, it: dict, no: int, P: dict) -> dict:
    """1句のページ。「この本の見方」で指し示す位置（anchors）を返す。"""
    col, tint = COLORS[it["color"]]
    L, R, w = f.left, f.right, f.width
    anchors: dict[str, tuple[float, float]] = {}
    fill_page(c, f, PAPER)
    # 上の色帯（紙の端まで）
    band_bottom = f.top - P["band"]
    c.setFillColorCMYK(*col)
    c.rect(0, band_bottom, f.pw, f.ph - band_bottom, stroke=0, fill=1)
    # 番号と章
    c.setFillColorCMYK(*WHITE)
    c.circle(L + 13, f.top - 11, 13, stroke=0, fill=1)
    c.setFillColorCMYK(*col)
    c.setFont(FONT_ROUNDED, 12)
    c.drawCentredString(L + 13, f.top - 15.5, f"{no:02d}")
    c.setFillColorCMYK(*WHITE)
    c.setFont(FONT_BOLD, 8.5)
    c.drawString(L + 32, f.top - 14, f"第{it['chapter'] + 1}章　{it['chapter_title']}")
    anchors["no"] = (L + 13, f.top - 11)
    # ことわざ（白抜き）
    ic_r = 48
    tw = w - 2 * ic_r - 14
    c.setFont(FONT_REGULAR, 9.5)
    c.drawString(L + 1, f.top - 40, it["kana"])
    anchors["kana"] = (L + 40, f.top - 37)
    fs = 29
    while c.stringWidth(it["jp"], FONT_ROUNDED, fs) > tw and fs > 17:
        fs -= 0.5
    c.setFont(FONT_ROUNDED, fs)
    c.drawString(L, f.top - 44 - fs, it["jp"])
    anchors["jp"] = (L + min(tw, c.stringWidth(it["jp"], FONT_ROUNDED, fs)) * 0.5, f.top - 44 - fs * 0.6)
    y = f.top - 44 - fs - 17
    c.setFont(FONT_REGULAR, P["mean"])
    mean = wrap(c, it["mean"], FONT_REGULAR, P["mean"], tw, False)
    assert y - 14 * (len(mean) - 1) >= band_bottom + 8, it["jp"]
    for line in mean:
        c.drawString(L, y, line)
        y -= 14
    anchors["mean"] = (L + 60, y + 16)
    # 絵（帯の下の縁にかかる白い丸）
    cx, cy = R - ic_r, band_bottom + 18
    c.setFillColorCMYK(*col)
    c.circle(cx, cy, ic_r + 3, stroke=0, fill=1)
    c.setFillColorCMYK(*WHITE)
    c.circle(cx, cy, ic_r, stroke=0, fill=1)
    if not draw_art(c, f"item{no:02d}", cx, cy, ic_r):
        draw_icon(c, it["icon"], cx - ic_r * 0.72, cy - ic_r * 0.72, ic_r * 1.44)
        if it.get("icon2"):
            draw_icon(c, it["icon2"], cx + ic_r * 0.25, cy - ic_r * 0.95, ic_r * 0.62)
    anchors["icon"] = (cx, cy)
    # 見出し
    y = band_bottom - 26
    c.setFillColorCMYK(*col)
    c.setFont(FONT_ROUNDED, 12.5)
    c.drawString(L, y, "世界では、こう言う")
    c.setStrokeColorCMYK(*col)
    c.setLineWidth(1.2)
    c.line(L + c.stringWidth("世界では、こう言う", FONT_ROUNDED, 12.5) + 8, y + 4, R - 2 * ic_r - 6, y + 4)
    y -= 12
    # 4言語の枠（余った高さはふり分ける）
    badge_w = 70
    tx = L + badge_w + 12
    avail = R - tx - 8
    lays = [_card_layout(c, it[k], k, avail, P) for k, _ in LANGS]
    base = [18 + (lo[1] + 3.5) * len(lo[0]) + (P["readg"] if it[k]["read"] else 0) + P["litg"] * len(lo[2]) + 4
            for (k, _), lo in zip(LANGS, lays)]
    story = wrap(c, it["story"], FONT_REGULAR, P["story"], w - 30, False)
    story_h = 34 + P["storyg"] * len(story)
    gap = P["gap"]
    free = (y - f.bottom) - sum(base) - 3 * gap - 14 - story_h
    assert free >= 0, (it["jp"], free)
    pad = min(free / 5, 16)
    for (k, _), (lines, ofs, lit), h in zip(LANGS, lays, base):
        h += pad
        x = it[k]
        c.setFillColorCMYK(*WHITE)
        c.roundRect(L, y - h, w, h, 8, stroke=0, fill=1)
        lang_badge(c, k, L + 4, y - h + 4, badge_w, h - 8)
        yy = y - pad / 2 - 20
        bf = FONT[k][0]
        c.setFillColorCMYK(*INK)
        for li, line in enumerate(lines):
            c.setFont(bf, ofs)
            c.drawString(tx, yy, line)
            if li == 0 and x["near"]:
                nx = tx + c.stringWidth(line, bf, ofs) + 6
                c.setFillColorCMYK(*LANG_TINT[k])
                c.roundRect(nx, yy - 2.5, 50, 13, 6.5, stroke=0, fill=1)
                c.setFillColorCMYK(*LANG_COLOR[k])
                c.setFont(FONT_BOLD, 7.5)
                c.drawCentredString(nx + 25, yy + 1, "近い言い方")
                c.setFillColorCMYK(*INK)
                anchors.setdefault("near", (nx + 25, yy + 4))
            yy -= ofs + 3.5
        if x["read"]:
            c.setFillColorCMYK(*SUB)
            c.setFont(READ_FONT[k], P["read"])
            c.drawString(tx, yy + 1, x["read"])
            anchors.setdefault("read", (tx + 40, yy + 4))
            yy -= P["readg"]
        c.setFillColorCMYK(*INK)
        c.setFont(FONT_REGULAR, P["lit"])
        for line in lit:
            c.drawString(tx, yy, line)
            yy -= P["litg"]
        anchors.setdefault("badge", (L + 4 + badge_w / 2, y - h / 2))
        anchors.setdefault("orig", (tx + 50, y - pad / 2 - 16))
        anchors.setdefault("lit", (tx + 40, yy + 18))
        y -= h + gap
    # ひとくち話
    y -= 8 - gap
    sh = story_h + pad
    c.setFillColorCMYK(*tint)
    c.roundRect(L, y - sh, w, sh, 10, stroke=0, fill=1)
    draw_icon(c, "1f4ac", L + 10, y - 26, 17)
    c.setFillColorCMYK(*col)
    c.setFont(FONT_ROUNDED, 11)
    c.drawString(L + 32, y - 20, "ひとくち話")
    c.setFillColorCMYK(*INK)
    c.setFont(FONT_REGULAR, P["story"])
    for k, line in enumerate(story):
        c.drawString(L + 14, y - 40 - k * P["storyg"], line)
    anchors["story"] = (L + 90, y - 18)
    assert y - sh >= f.bottom - 0.5, (it["jp"], y - sh - f.bottom)
    folio(c, f, f"第{it['chapter'] + 1}章　{it['chapter_title']}")
    return anchors


def draw_chapter(c: canvas.Canvas, f: Frame, spec: SekaiSpec, items: list[dict], ci: int) -> None:
    ch = spec.chapters[ci]
    col, tint = COLORS[ch["color"]]
    L, R, w = f.left, f.right, f.width
    fill_page(c, f, tint)
    top_h = 210
    c.setFillColorCMYK(*col)
    c.rect(0, f.y1 - top_h, f.pw, top_h + BLEED, stroke=0, fill=1)
    c.setFillColorCMYK(*WHITE)
    c.setFont(FONT_ROUNDED, 70)
    c.drawString(L, f.y1 - 120, f"{ci + 1:02d}")
    c.setFont(FONT_BOLD, 11)
    c.drawString(L + c.stringWidth(f"{ci + 1:02d}", FONT_ROUNDED, 70) + 10, f.y1 - 70, f"第{ci + 1}章")
    c.setFont(FONT_ROUNDED, 30)
    c.drawString(L, f.y1 - 168, ch["title"])
    if art_path(f"chapter{ci + 1}"):
        ar = 74
        acx, acy = R - ar, f.y1 - top_h + 18
        c.setFillColorCMYK(*WHITE)
        c.circle(acx, acy, ar + 4, stroke=0, fill=1)
        draw_art(c, f"chapter{ci + 1}", acx, acy, ar)
    mine = [(k, it) for k, it in enumerate(items) if it["chapter"] == ci]
    # 10句のカード（2列×5段）
    cw = (w - 10) / 2
    chh = (f.y1 - top_h - 22 - f.bottom) / 5 - 8
    for j, (k, it) in enumerate(mine):
        x = L + (j % 2) * (cw + 10)
        y = f.y1 - top_h - 22 - (j // 2) * (chh + 8)
        c.setFillColorCMYK(*WHITE)
        c.roundRect(x, y - chh, cw, chh, 9, stroke=0, fill=1)
        ic = min(34, chh - 14)
        draw_icon(c, it["icon"], x + 8, y - chh / 2 - ic / 2, ic)
        c.setFillColorCMYK(*col)
        c.setFont(FONT_ROUNDED, 10)
        c.drawString(x + ic + 16, y - 17, f"{k + 1:02d}")
        c.setFillColorCMYK(*SUB)
        c.setFont(FONT_REGULAR, 8)
        c.drawRightString(x + cw - 8, y - 17, f"{item_page(spec, k)}ページ")
        c.setFillColorCMYK(*INK)
        name = it["jp"]
        room = cw - ic - 24
        nfs = 10.5
        lines = wrap(c, name, FONT_BOLD, nfs, room, False)
        while len(lines) > 1 and len(lines[-1]) <= 2 and nfs > 8.5:
            nfs -= 0.25
            lines = wrap(c, name, FONT_BOLD, nfs, room, False)
        for li, line in enumerate(lines[:2]):
            c.setFont(FONT_BOLD, nfs)
            c.drawString(x + ic + 16, y - 33 - li * 13, line)


# --- 前付け・後付け ---------------------------------------------------------------


def _heading(c: canvas.Canvas, f: Frame, text: str, color: CMYK = NAVY) -> float:
    """ページの見出し（紙の端までの細い帯つき）。本文を書き始める y を返す。"""
    c.setFillColorCMYK(*color)
    c.rect(0, f.y1 - 0.22 * inch, f.pw, 0.22 * inch + BLEED, stroke=0, fill=1)
    c.setFont(FONT_ROUNDED, 20)
    c.drawString(f.left, f.top - 32, text)
    c.setStrokeColorCMYK(*GOLD)
    c.setLineWidth(3)
    c.line(f.left, f.top - 42, f.left + 36, f.top - 42)
    return f.top - 70


def _para(c: canvas.Canvas, f: Frame, text: str, y: float, fs: float = 10.5, gap: float = 18,
          x: float | None = None, width: float | None = None) -> float:
    c.setFillColorCMYK(*INK)
    c.setFont(FONT_REGULAR, fs)
    x = f.left if x is None else x
    for line in wrap(c, text, FONT_REGULAR, fs, width or f.width, False):
        c.drawString(x, y, line)
        y -= gap
    return y


def _item_image(spec: SekaiSpec, it: dict, no: int, width_pt: float, dpi: int = 300) -> tuple[ImageReader, dict, Frame]:
    """1句のページを画像にする（「この本の見方」と裏表紙の見本）。仕上がりの範囲だけを切り出す。"""
    import pypdfium2

    f = frame(spec, 1)
    buf = io.BytesIO()
    pc = canvas.Canvas(buf, pagesize=(f.pw, f.ph), initialFontName=FONT_REGULAR)
    anchors = draw_item(pc, f, it, no)
    pc.save()
    scale = dpi / 72 * (width_pt / (f.x1 - f.x0))
    img = pypdfium2.PdfDocument(buf.getvalue())[0].render(scale=scale).to_pil()
    k = img.width / f.pw
    img = img.crop((int(f.x0 * k), int((f.ph - f.y1) * k), int(f.x1 * k), int((f.ph - f.y0) * k))).convert("CMYK")
    out = io.BytesIO()
    img.save(out, "JPEG", quality=95)
    out.seek(0)
    return ImageReader(out), anchors, f


def build_pdf(spec: SekaiSpec, output_path: str) -> int:
    total = page_count(spec)
    items = load_items(spec)
    f = frame(spec, 1)
    c = canvas.Canvas(output_path, pagesize=(f.pw, f.ph), initialFontName=FONT_REGULAR)
    c.setTitle(spec.title)
    c.setAuthor(spec.publisher)
    c.setCreator(spec.publisher)
    n = 1
    sample_i = next(k for k, it in enumerate(items) if it["jp"] == "猿も木から落ちる")
    sample = items[sample_i]

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
    c.rect(0, f.y0 + (f.y1 - f.y0) * 0.42, f.pw, f.ph, stroke=0, fill=1)
    mid = (f.left + f.right) / 2
    c.setFillColorCMYK(*GOLD)
    c.setFont(FONT_BOLD, 10)
    c.drawCentredString(mid, f.top - 60, "英語・フランス語・中国語・韓国語で読む")
    outlined_text(c, "日本のことわざ、", mid, f.top - 120, font=FONT_ROUNDED, size=26,
                  fill=CMYKColor(*WHITE), outline=CMYKColor(*NAVY), outline_width=1)
    outlined_text(c, "世界ではこう言う", mid, f.top - 172, font=FONT_ROUNDED, size=34,
                  fill=CMYKColor(*GOLD), outline=CMYKColor(*NAVY), outline_width=1)
    if art_path("title"):
        c.setFillColorCMYK(*GOLD)
        c.circle(mid, f.y0 + (f.y1 - f.y0) * 0.42, 66, stroke=0, fill=1)
        draw_art(c, "title", mid, f.y0 + (f.y1 - f.y0) * 0.42, 62)
    else:
        draw_icon(c, "1f30f", mid - 42, f.y0 + (f.y1 - f.y0) * 0.42 - 42, 84)
    bx = f.left
    bw = (f.width - 18) / 4
    for j, (k, _) in enumerate(LANGS):
        lang_badge(c, k, bx + j * (bw + 6), f.y0 + (f.y1 - f.y0) * 0.24, bw, 34)
    c.setFillColorCMYK(*INK)
    c.setFont(FONT_BOLD, 11)
    c.drawCentredString(mid, f.bottom + 10, spec.publisher)
    turn()

    # 2. はじめに
    f = page()
    fill_page(c, f, PAPER)
    y = _heading(c, f, "はじめに")
    for text in [
        "「猿も木から落ちる」は、英語では「ホメロスでさえ居眠りをする」、フランス語では「つまずかないほど良い馬はいない」。"
        "韓国語では、日本と同じ「猿も木から落ちる」です。",
        "同じ気持ちを、国によってちがうものにたとえている。そのちがいを見くらべるのが、この本の楽しみ方です。",
    ]:
        y = _para(c, f, text, y) - 10
    # 絵: 猿と4つのふきだし
    y -= 6
    draw_icon(c, "1f412", f.left, y - 70, 66)
    by = y - 4
    for k, _ in LANGS:
        bw = f.width - 84
        c.setFillColorCMYK(*WHITE)
        c.roundRect(f.left + 80, by - 24, bw, 24, 12, stroke=0, fill=1)
        c.setFillColorCMYK(*LANG_COLOR[k])
        c.roundRect(f.left + 80, by - 24, 58, 24, 12, stroke=0, fill=1)
        c.setFillColorCMYK(*WHITE)
        name, font = NATIVE[k]
        c.setFont(font, 9.5)
        c.drawCentredString(f.left + 109, by - 16, name)
        c.setFillColorCMYK(*INK)
        bf = FONT[k][0]
        fs = 10
        while c.stringWidth(sample[k]["text"], bf, fs) > bw - 70:
            fs -= 0.5
        c.setFont(bf, fs)
        c.drawString(f.left + 146, by - 16, sample[k]["text"])
        by -= 30
    y = by - 16
    for text in [
        "日本のよく知られたことわざを50選び、英語・フランス語・中国語・韓国語で同じ意味の言い方を並べました。"
        "外国語の言い方は、どれも2つ以上の辞書や資料で、実際に使われていることと意味を確かめたものです。",
        "ぴったり同じ意味の言い方がない言語は、意味の近い言い方に「近い言い方」の札をつけて載せています。",
    ]:
        y = _para(c, f, text, y) - 10
    folio(c, f)
    turn()

    # 3. この本の見方（見本ページの縮小と番号つきの説明）
    f = page()
    fill_page(c, f, PAPER)
    y = _heading(c, f, "この本の見方")
    mini_w = f.width * 0.6
    guide_i = next(k for k, it in enumerate(items) if it["jp"] == "猫に小判")  # 近い言い方と読み方がそろう句
    img, anc, sf = _item_image(spec, items[guide_i], guide_i + 1, mini_w)
    mini_h = mini_w * (sf.y1 - sf.y0) / (sf.x1 - sf.x0)
    mx, my = f.left, y - mini_h + 6
    c.setFillColorCMYK(0.0, 0.08, 0.2, 0.15)
    c.rect(mx + 3, my - 3, mini_w, mini_h, stroke=0, fill=1)
    c.drawImage(img, mx, my, mini_w, mini_h)
    s = mini_w / (sf.x1 - sf.x0)
    notes = [
        ("jp", "日本のことわざ", "読みがなと意味つき"),
        ("icon", "絵", "ことわざを1枚の絵で"),
        ("badge", "4つのことば", "英・仏・中・韓の順"),
        ("orig", "原文", "その国の文字で"),
        ("read", "読み方", "ピンイン・カタカナ"),
        ("lit", "直訳", "ことばどおりの訳"),
        ("near", "近い言い方", "少し意味がずれるもの"),
        ("story", "ひとくち話", "出どころや、たとえのちがい"),
    ]
    tx = mx + mini_w + 16
    ny = y - 4
    step = (mini_h - 10) / len(notes)
    for j, (key, head, sub) in enumerate(notes):
        ax, ay = anc[key]
        px, py = mx + (ax - sf.x0) * s, my + (ay - sf.y0) * s
        c.setFillColorCMYK(*GOLD)
        c.setStrokeColorCMYK(*NAVY)
        c.setLineWidth(0.9)
        c.circle(px, py, 6.5, stroke=1, fill=1)
        c.setFillColorCMYK(*NAVY)
        c.setFont(FONT_BOLD, 8)
        c.drawCentredString(px, py - 2.8, str(j + 1))
        yy = ny - j * step
        c.setFillColorCMYK(*NAVY)
        c.circle(tx + 7, yy + 3, 7, stroke=0, fill=1)
        c.setFillColorCMYK(*WHITE)
        c.setFont(FONT_BOLD, 8.5)
        c.drawCentredString(tx + 7, yy, str(j + 1))
        c.setFillColorCMYK(*INK)
        c.setFont(FONT_BOLD, 10)
        c.drawString(tx + 19, yy, head)
        c.setFillColorCMYK(*SUB)
        c.setFont(FONT_REGULAR, 8)
        c.drawString(tx + 19, yy - 12, sub)
    folio(c, f)
    turn()

    # 4. 4つのことば
    f = page()
    fill_page(c, f, PAPER)
    y = _heading(c, f, "この本の4つのことば")
    ch_h = (y - f.bottom - 3 * 10) / 4
    for k, jp in LANGS:
        c.setFillColorCMYK(*WHITE)
        c.roundRect(f.left, y - ch_h, f.width, ch_h, 10, stroke=0, fill=1)
        c.setFillColorCMYK(*LANG_COLOR[k])
        c.roundRect(f.left, y - ch_h, 8, ch_h, 4, stroke=0, fill=1)
        name, font = NATIVE[k]
        c.setFont(font, 22)
        c.drawString(f.left + 22, y - 36, name)
        c.setFillColorCMYK(*INK)
        c.setFont(FONT_BOLD, 11)
        c.drawString(f.left + 30 + c.stringWidth(name, font, 22), y - 35, jp)
        c.setFillColorCMYK(*SUB)
        c.setFont(FONT_REGULAR, 8.5)
        c.drawString(f.left + 22, y - 56, "おもに使われているところ")
        c.setFillColorCMYK(*INK)
        c.setFont(FONT_REGULAR, 10)
        c.drawString(f.left + 22, y - 71, REGIONS[k])
        c.setFillColorCMYK(*SUB)
        c.setFont(FONT_REGULAR, 8.5)
        for li, line in enumerate(wrap(c, READ_NOTE[k], FONT_REGULAR, 8.5, f.width - 40, False)):
            c.drawString(f.left + 22, y - 90 - li * 12, line)
        y -= ch_h + 10
    folio(c, f)
    turn()

    # 5. もくじ
    f = page()
    fill_page(c, f, PAPER)
    y = _heading(c, f, "もくじ")
    for ci, ch in enumerate(spec.chapters):
        col, tint = COLORS[ch["color"]]
        names = "・".join(it["jp"] for it in items if it["chapter"] == ci)
        lines = wrap(c, names, FONT_REGULAR, 8.5, f.width - 48, False)
        bh = 30 + 12 * len(lines)
        c.setFillColorCMYK(*WHITE)
        c.roundRect(f.left, y - bh, f.width, bh, 8, stroke=0, fill=1)
        c.setFillColorCMYK(*col)
        c.roundRect(f.left, y - bh, 36, bh, 8, stroke=0, fill=1)
        c.setFillColorCMYK(*WHITE)
        c.setFont(FONT_ROUNDED, 16)
        c.drawCentredString(f.left + 18, y - bh / 2 - 6, f"{ci + 1}")
        c.setFillColorCMYK(*col)
        c.setFont(FONT_ROUNDED, 12.5)
        c.drawString(f.left + 46, y - 18, ch["title"])
        c.setFillColorCMYK(*SUB)
        c.setFont(FONT_BOLD, 9.5)
        c.drawRightString(f.right - 10, y - 18, str(chapter_page(spec, ci)))
        c.setFillColorCMYK(*INK)
        c.setFont(FONT_REGULAR, 8.5)
        for li, line in enumerate(lines):
            c.drawString(f.left + 46, y - 33 - li * 12, line)
        y -= bh + 8
    for label, pno in (("おわりに", total - 3), ("さくいん", total - 2), ("参考にした資料", total - 1)):
        c.setFillColorCMYK(*NAVY)
        c.setFont(FONT_ROUNDED, 11)
        c.drawString(f.left + 4, y - 12, label)
        c.setFillColorCMYK(*SUB)
        c.setFont(FONT_BOLD, 9.5)
        c.drawRightString(f.right - 10, y - 12, str(pno))
        y -= 20
    assert y >= f.bottom
    folio(c, f)
    turn()

    # 6. 各章
    for ci in range(len(spec.chapters)):
        assert n == chapter_page(spec, ci)
        draw_chapter(c, page(), spec, items, ci)
        turn()
        for k, it in enumerate(items):
            if it["chapter"] != ci:
                continue
            assert n == item_page(spec, k)
            draw_item(c, page(), it, k + 1)
            turn()

    # 7. おわりに
    f = page()
    fill_page(c, f, PAPER)
    y = _heading(c, f, "おわりに")
    for text in [
        "50のことわざを、4つのことばで見くらべてきました。",
        "「火のない所に煙は立たぬ」のように、どの国でもほとんど同じ言い方をするものがあれば、"
        "「犬猿の仲」が「犬と猫」になるように、たとえがすっかり変わるものもありました。",
        "ことわざは、その土地の暮らしや、身近な生きもの、食べもの、昔の書物から生まれます。"
        "ちがうたとえの向こうに、よく似た気持ちが見えてくる。それが、世界のことわざを並べる楽しさです。",
        "気になった言い方があれば、ぜひ声に出して読んでみてください。",
    ]:
        y = _para(c, f, text, y) - 12
    mid = (f.left + f.right) / 2
    if not draw_art(c, "title", mid, f.bottom + 95, 85):
        draw_icon(c, "1f30f", mid - 45, f.bottom + 90, 90)
        icons = [it["icon"] for it in items[::5]]
        for j, code in enumerate(icons):
            draw_icon(c, code, f.left + j * (f.width - 30) / (len(icons) - 1), f.bottom + 30, 30)
    folio(c, f)
    turn()

    # 8. さくいん（五十音順）
    f = page()
    fill_page(c, f, PAPER)
    y = _heading(c, f, "さくいん")
    order = sorted(range(len(items)), key=lambda k: items[k]["kana"])
    col_w = (f.width - 12) / 2
    per = 25
    row = (y - f.bottom) / per
    for m, k in enumerate(order):
        x0 = f.left + (m // per) * (col_w + 12)
        yy = y - (m % per) * row
        c.setFillColorCMYK(*COLORS[items[k]["color"]][0])
        c.circle(x0 + 3, yy + 3, 2.2, stroke=0, fill=1)
        c.setFillColorCMYK(*INK)
        name = items[k]["jp"]
        fs = 8.5
        while c.stringWidth(name, FONT_REGULAR, fs) > col_w - 32:
            fs -= 0.25
        c.setFont(FONT_REGULAR, fs)
        c.drawString(x0 + 10, yy, name)
        c.setFillColorCMYK(*SUB)
        c.setFont(FONT_BOLD, 8.5)
        c.drawRightString(x0 + col_w, yy, str(item_page(spec, k)))
    folio(c, f)
    turn()

    # 9. 参考にした資料
    f = page()
    fill_page(c, f, PAPER)
    y = _heading(c, f, "参考にした資料")
    y = _para(c, f, "外国語の言い方は、1つずつ、次のような辞書や資料のうち2つ以上で確かめました。", y, fs=9.5, gap=15) - 10
    for lang, text in REFERENCES:
        c.setFillColorCMYK(*NAVY)
        c.setFont(FONT_BOLD, 10)
        c.drawString(f.left, y, lang)
        c.setFillColorCMYK(*INK)
        c.setFont(FONT_REGULAR, 9)
        y -= 16
        for line in wrap(c, text, FONT_REGULAR, 9, f.width, "list"):
            c.drawString(f.left, y, line)
            y -= 14
        y -= 8
    assert y >= f.bottom
    folio(c, f)
    turn()

    # 10. 奥付
    while n < total:
        fill_page(c, page(), PAPER)
        turn()
    f = page()
    fill_page(c, f, PAPER)
    c.setFillColorCMYK(*INK)
    y = f.bottom + 150
    c.setStrokeColorCMYK(*NAVY)
    c.setLineWidth(1)
    c.line(f.left, y + 22, f.right, y + 22)
    c.setFont(FONT_BOLD, 12)
    c.drawString(f.left, y, spec.title)
    c.setFont(FONT_REGULAR, 9)
    y -= 20
    if spec.edition_date:
        c.drawString(f.left, y, f"{spec.edition_date}　初版発行")
        y -= 15
    c.drawString(f.left, y, f"発行　{spec.publisher}")
    y -= 15
    year = spec.edition_date[:4] if spec.edition_date[:4].isdigit() else ""
    c.drawString(f.left, y, " ".join(t for t in ("Copyright", year, spec.publisher) if t))
    y -= 20
    c.setFont(FONT_REGULAR, 7.5)
    for line in FONT_CREDIT + ([ART_CREDIT] if has_art() else []):
        for part in wrap(c, line, FONT_REGULAR, 7.5, f.width, "list"):
            c.drawString(f.left, y, part)
            y -= 11
    c.line(f.left, y + 2, f.right, y + 2)
    turn()
    c.save()
    assert n - 1 == total, (n - 1, total)
    return total


# --- 表紙 ---------------------------------------------------------------------


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
    sample_i = next(k for k, it in enumerate(items) if it["jp"] == "猿も木から落ちる")
    sample = items[sample_i]

    c = canvas.Canvas(output_path, pagesize=(W, H), initialFontName=FONT_REGULAR)
    c.setTitle(f"{spec.title}（表紙）")
    c.setAuthor(spec.publisher)
    c.setFillColorCMYK(*PAPER)
    c.rect(0, 0, W, H, stroke=0, fill=1)
    spine_x0, fx = b + tw, b + tw + sp
    cx, top = fx + tw / 2, b + th
    # 紺の上半分（背から表まで）
    cover_art = art_path("cover") is not None
    art_r = 0.95 * inch if cover_art else 0.62 * inch
    band = top - (3.0 if cover_art else 2.6) * inch
    c.setFillColorCMYK(*NAVY)
    c.rect(0, band, W, H - band, stroke=0, fill=1)
    c.rect(spine_x0, 0, sp, H, stroke=0, fill=1)
    # 表表紙
    c.setFillColorCMYK(*GOLD)
    c.setFont(FONT_BOLD, 11)
    c.drawCentredString(cx, top - 0.62 * inch, "英語・フランス語・中国語・韓国語で読む")
    outlined_text(c, "日本のことわざ、", cx, top - 1.12 * inch, font=FONT_ROUNDED, size=26,
                  fill=CMYKColor(*WHITE), outline=CMYKColor(*NAVY), outline_width=1)
    outlined_text(c, "世界ではこう言う", cx, top - 1.78 * inch, font=FONT_ROUNDED, size=35,
                  fill=CMYKColor(*GOLD), outline=CMYKColor(*NAVY), outline_width=1)
    # 猿の絵（紺と生成りの境目）
    c.setFillColorCMYK(*GOLD)
    c.circle(cx, band, art_r + 3, stroke=0, fill=1)
    c.setFillColorCMYK(*WHITE)
    c.circle(cx, band, art_r, stroke=0, fill=1)
    if not draw_art(c, "cover", cx, band, art_r):
        draw_icon(c, "1f412", cx - 0.45 * inch, band - 0.45 * inch, 0.9 * inch)
    c.setFillColorCMYK(*COLORS["green"][0])
    c.setFont(FONT_ROUNDED, 18)
    c.drawCentredString(cx, band - art_r - 0.36 * inch, sample["jp"])
    y = band - art_r - 0.56 * inch
    card_w = tw - 2 * safe - 16
    for k, _ in LANGS:
        c.setFillColorCMYK(*WHITE)
        c.roundRect(cx - card_w / 2, y - 29, card_w, 29, 8, stroke=0, fill=1)
        lang_badge(c, k, cx - card_w / 2 + 3, y - 26, 64, 23)
        c.setFillColorCMYK(*INK)
        bf = FONT[k][0]
        fs = 11.5
        while c.stringWidth(sample[k]["text"], bf, fs) > card_w - 82:
            fs -= 0.5
        c.setFont(bf, fs)
        c.drawString(cx - card_w / 2 + 76, y - 18.5, sample[k]["text"])
        y -= 34
    seals = [((0.0, 0.80, 0.70, 0.05), ["50の", "ことわざ"]), (COLORS["green"][0], ["4つの", "ことば"]),
             (COLORS["blue"][0], ["辞書で", "確かめた"]), (COLORS["pink"][0], ["オール", "カラー"])]
    r = 0.36 * inch
    gap = (tw - 2 * safe - 2 * r * len(seals)) / (len(seals) + 1)
    for k, (col, lines) in enumerate(seals):
        _seal(c, fx + safe + gap * (k + 1) + r * (2 * k + 1), b + safe + 0.62 * inch, r, col, lines)
    c.setFillColorCMYK(*NAVY)
    c.setFont(FONT_BOLD, 11)
    c.drawCentredString(cx, b + safe + 4, spec.publisher)
    # 裏表紙
    bx0 = b + safe + 10
    c.setFillColorCMYK(*WHITE)
    c.setFont(FONT_ROUNDED, 15)
    c.drawString(bx0, top - safe - 26, spec.title)
    c.setFillColorCMYK(*GOLD)
    c.setFont(FONT_BOLD, 9)
    c.drawString(bx0, top - safe - 44, spec.subtitle)
    c.setFillColorCMYK(*WHITE)
    c.setFont(FONT_REGULAR, 9.5)
    yy = top - safe - 70
    for line in ["「猫に小判」は、英語では「豚に真珠」。",
                 "「犬猿の仲」は、フランス語では「犬と猫」。",
                 "同じ気持ちを、国ごとにちがうものにたとえる。",
                 "そのちがいを見くらべる、50のことわざの本です。"]:
        c.drawString(bx0, yy, line)
        yy -= 15
    bw, bh = (v * inch for v in kdp_spec.BARCODE_BOX_IN)
    sf = frame(spec, 1)
    ratio = (sf.y1 - sf.y0) / (sf.x1 - sf.x0)
    # 見本は紺の帯とバーコード欄の間に収まる大きさまで
    mini_w = min(tw * 0.41, (band - 0.12 * inch - (b + safe + bh + 31)) / ratio)
    img, _, sf = _item_image(spec, items[30], 31, mini_w)
    mini_h = mini_w * ratio
    mx = b + (tw - mini_w) / 2
    my = band - 0.12 * inch - mini_h
    c.setFillColorCMYK(0.0, 0.10, 0.25, 0.15)
    c.rect(mx + 4, my - 4, mini_w, mini_h, stroke=0, fill=1)
    c.drawImage(img, mx, my, mini_w, mini_h)
    c.setFillColorCMYK(*INK)
    c.setFont(FONT_REGULAR, 8.5)
    note = "外国語の言い方は、どれも2つ以上の辞書や資料で確かめました。"
    c.drawString(bx0, my - 20, note)
    assert my - 24 >= b + safe + bh + 6, my
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
