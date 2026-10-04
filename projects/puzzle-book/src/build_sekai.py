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
import functools
import io
import json
import re
from dataclasses import dataclass, field
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
                     ("TC", "NotoSansTC-Regular"), ("TC-B", "NotoSansTC-Bold"),
                     ("SC", "NotoSansSC-Regular"), ("SC-B", "NotoSansSC-Bold")):  # SC は本の簡体字だけに絞った書体（tools/subset_sc.py）
    pdfmetrics.registerFont(TTFont(_name, str(_F / f"{_file}.ttf")))

BLEED = kdp_spec.COVER_BLEED_IN * inch  # 本文の裁ち落としも 0.125 in
MARGIN_IN = 0.55 * inch  # ノド側（KDP の最小 0.375 in より広く）
MARGIN_OUT = 0.45 * inch
MARGIN_TOP = 0.45 * inch
MARGIN_BOTTOM = 0.62 * inch  # ページ番号の分を空ける
SAFE = 0.375 * inch  # 文字は仕上がり線からこれ以上内側（裁ち落としありの最小）

# 挿絵（画像生成AI の FLUX.1 [schnell] で描き、1枚ずつ目で選んだもの）。置いてあれば絵文字の代わりに丸く切り抜いて使う。
# 名前: item01〜item50（各句）、chapter1〜5（章扉）、cover（表紙）、title（表題・おわりに）
ART_DIR = _ROOT / "assets" / "sekai-art"
ART_CREDIT = "挿絵: FLUX.1 [schnell]（Black Forest Labs、Apache License 2.0）で生成"


def art_path(key: str) -> Path | None:
    for ext in (".png", ".jpg", ".jpeg", ".webp"):
        path = ART_DIR / f"{key}{ext}"
        if path.exists():
            return path
    return None


def has_art() -> bool:
    return ART_DIR.exists() and any(ART_DIR.iterdir())


@functools.lru_cache(maxsize=None)
def _art_cmyk(path: str) -> tuple[int, bytes]:
    """挿絵を正方形に切り、CMYK の JPEG にする（1枚1回だけ）。"""
    from PIL import Image

    img = Image.open(path)
    side = min(img.size)
    img = img.crop(((img.width - side) // 2, (img.height - side) // 2,
                    (img.width + side) // 2, (img.height + side) // 2))
    out = io.BytesIO()
    to_cmyk(img).save(out, "JPEG", quality=94)
    return side, out.getvalue()


_SWOP = Path(r"C:\Windows\System32\spool\drivers\color\RSWOP.icm")


@functools.lru_cache(maxsize=1)
def _swop_transform():
    from PIL import ImageCms

    if not _SWOP.exists():
        return None
    return ImageCms.buildTransform(ImageCms.createProfile("sRGB"), ImageCms.getOpenProfile(str(_SWOP)),
                                   "RGB", "CMYK", renderingIntent=ImageCms.Intent.PERCEPTUAL)


def to_cmyk(img):
    """RGB を印刷用の CMYK にする。Windows の SWOP（RSWOP.icm）があればそれで（黒版を使い、総インク量を抑える）。
    挿絵（assets/sekai-art）は変換済みの CMYK で置いてあるので、そのまま通す。"""
    from PIL import ImageCms

    if img.mode == "CMYK":
        return img
    t = _swop_transform()
    return ImageCms.applyTransform(img.convert("RGB"), t) if t else img.convert("CMYK")


def draw_art(c: canvas.Canvas, key: str, cx: float, cy: float, r: float) -> bool:
    """挿絵を中心 (cx, cy)・半径 r の丸に切り抜いて置く。四隅は丸の外に落ちる。"""
    path = art_path(key)
    if path is None:
        return False
    side, data = _art_cmyk(str(path))
    need = int(2 * r / 72 * 300) + 1
    assert side >= need, f"{path.name} は {side}px。この大きさ（{2 * r / 72:.2f}in）には {need}px 以上が要る"
    out = io.BytesIO(data)
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
FONT = {"en": ("LAT-B", "LAT"), "fr": ("LAT-B", "LAT"), "zh": ("SC-B", "SC"), "ko": ("KR-B", "KR")}
READ_FONT = {"en": FONT_REGULAR, "fr": FONT_REGULAR, "zh": "LAT", "ko": FONT_REGULAR}
COLORS: dict[str, tuple[CMYK, CMYK]] = {
    "orange": ((0.0, 0.62, 1.0, 0.08), (0.0, 0.07, 0.16, 0.0)),
    "green": ((0.72, 0.0, 0.85, 0.12), (0.09, 0.0, 0.12, 0.0)),
    "blue": ((0.88, 0.45, 0.0, 0.12), (0.11, 0.04, 0.0, 0.0)),
    "pink": ((0.0, 0.80, 0.30, 0.08), (0.0, 0.09, 0.03, 0.0)),
    "purple": ((0.58, 0.78, 0.0, 0.05), (0.07, 0.09, 0.0, 0.0)),
}
INK: CMYK = (0.0, 0.0, 0.0, 0.88)  # 本文の文字は黒1色（4色重ねは小さい字がにじむ）
SUB: CMYK = (0.0, 0.0, 0.0, 0.66)
PAPER: CMYK = (0.0, 0.015, 0.05, 0.0)
WHITE: CMYK = (0, 0, 0, 0)
NAVY: CMYK = (0.95, 0.75, 0.10, 0.45)
GOLD: CMYK = (0.0, 0.18, 0.85, 0.0)
FRONT_PAGES = 5  # 表題・はじめに・この本の見方・4つのことば・もくじ
BACK_PAGES = 7  # おわりに・書きとめメモ・さくいん・英語から引くさくいん・フランス語から引くさくいん・参考にした資料・奥付
REGIONS = {
    "en": "イギリス・アメリカ・カナダ・オーストラリアなど",
    "fr": "フランス・ベルギー・スイス・カナダ（ケベック州）など",
    "zh": "中国・台湾・シンガポールなど",
    "ko": "韓国・北朝鮮",
}
READ_NOTE = {
    "en": "原文に、カタカナのおよその読みと、直訳をつけています。",
    "fr": "原文に、カタカナのおよその読みと、直訳をつけています。",
    "zh": "簡体字で書き、繁体字（台湾などの字）を右上に添えています。ピンインとカタカナの読みつき。",
    "ko": "ハングルに、カタカナのおよその読みをつけています。語頭の「ッ」は、詰まった強い音（濃音）の印です。漢字語は、漢字での書き方を添えています。",
}
REFERENCES = [  # 紙・公的な辞典を先に、Web の資料を後に
    ("英語", "Oxford Dictionary of Proverbs、Longman Dictionary of Contemporary English、Cambridge Dictionary、"
             "W. Preston『A Dictionary of English Proverbs』（1880）、The Free Dictionary（Farlex・McGraw-Hill）、"
             "The Phrase Finder、Wiktionary（英語版）ほか"),
    ("フランス語", "Larousse、アカデミー・フランセーズ辞典、リトレ辞典、Wiktionnaire（フランス語版）、"
                  "Expressio、Linternaute、Wiktionary（英語版）ほか"),
    ("中国語", "教育部『重編國語辭典修訂本』、教育部『成語典』（台湾）、漢典（zdic.net）、"
              "Wikisource の原典（論語・史記・孟子など）、新聞記事、Wiktionary（英語版）ほか"),
    ("韓国語", "国立国語院『標準国語大辞典』、高麗大学校『韓国語大辞典』、国立国語院『ウリマルセム』、新聞記事、Wiktionary ほか"),
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
    kindle_toc: list = field(default_factory=list)  # Kindle 版のもくじ（tools/make_kindle_epub.py）

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
                # 中国語は簡体字を大きく載せ、繁体字（確かめた記録の形）を小さく添える
                item[k] = {"text": x.get("simp") or x["text"], "trad": x["text"] if x.get("simp") else "",
                           "read": x["read"], "kana": x.get("kana", ""), "near": x["match"] != "同じ",
                           "lit": _drop_same_gloss(literal(x["note"], k), v["jp"]), "sources": x["sources"]}
            out.append(item)
    return out


def _drop_same_gloss(lit: str, jp: str) -> str:
    """「漢字で書くと「…」（意味）」の（意味）が日本語の題とほぼ同じなら、くり返さない。"""
    m = re.match(r"(漢字で書くと「[^」]+」)（(.+)）$", lit)
    if not m:
        return lit
    gloss = m.group(2)
    same = sum(ch in jp for ch in gloss) / max(1, len(gloss))
    return m.group(1) if same >= 0.6 else lit


def literal(note: str, lang: str = "") -> str:
    """確認の記録から直訳を取り出す。韓国語の漢字語（記録の先頭が漢字）は、漢字の書き方を見せる。"""
    m = re.match(r"([一-龥가-힣 ]{2,10})。", note) if lang == "ko" else None
    if m and re.search(r"[一-龥]{2}", m.group(1)):
        hanja = re.sub(r"[가-힣 ]", "", m.group(1)).translate(str.maketrans("步鷄從傳", "歩鶏従伝"))
        lit = re.search(r"直訳「(.+?)」", note)
        extra = f"（{lit.group(1)}）" if lit and lit.group(1) != hanja and len(lit.group(1)) <= 16 else ""
        return "漢字で書くと「" + hanja + "」" + extra
    m = re.search(r"直訳「(.+?)」", note)
    if m:
        return "直訳「" + m.group(1) + "」"
    m = re.match(r"([^。「」]{2,8})。", note)
    if m:  # 韓国語の漢字語（四字熟語など）。旧字体は日本の字体に直して見せる
        return "漢字で書くと「" + m.group(1).translate(str.maketrans("步鷄", "歩鶏")) + "」"
    raise ValueError(f"直訳が見つからない: {note[:30]}")


_DAKUTEN = str.maketrans("がぎぐげござじずぜぞだぢづでどばびぶべぼぱぴぷぺぽゔ",
                         "かきくけこさしすせそたちつてとはひふへほはひふへほう")


def kana_key(kana: str) -> tuple[str, str]:
    """五十音順の並べ方（濁点・半濁点をはずして比べ、同じなら清音が先）。"""
    return kana.translate(_DAKUTEN), kana


def foreign_key(text: str) -> str:
    """英語・フランス語のさくいんの並べ方（アクセントと記号をはずし、大文字小文字を区別しない）。"""
    import unicodedata

    t = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode().lower()
    return re.sub(r"[^a-z ]", "", t).strip()


def page_count(spec: SekaiSpec) -> int:
    total = FRONT_PAGES + sum(2 + len(ch["items"]) for ch in spec.chapters) + BACK_PAGES  # 章扉・各句・おさらい
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
        p += 1  # 章のおさらい
    raise IndexError(index)


def review_page(spec: SekaiSpec, ci: int) -> int:
    """ci 章のおさらい（章の最後のページ）。"""
    return chapter_page(spec, ci) + len(spec.chapters[ci]["items"]) + 1


def chapter_page(spec: SekaiSpec, ci: int) -> int:
    return FRONT_PAGES + 1 + sum(2 + len(ch["items"]) for ch in spec.chapters[:ci])


_KINSOKU_HEAD = "，。、」）？！・ー』"
_KINSOKU_TAIL = "「（『"  # 行末に置かない（次の行へ送る）


def wrap(c: canvas.Canvas, text: str, font: str, size: float, width: float, by_word=False) -> list[str]:
    """by_word=True は欧文（空白で折る）、"list" は「、」の区切りで折る、False は1字ずつ（行頭禁則つき）。"""
    return list(_wrap(text, font, size, round(width, 2), by_word))


@functools.lru_cache(maxsize=None)
def _wrap(text: str, font: str, size: float, width: float, by_word) -> tuple[str, ...]:
    c = pdfmetrics  # 幅は書体だけで決まる（キャンバスに依らない）ので、結果を使い回す
    if c.stringWidth(text, font, size) <= width:
        return (text,)
    lines, cur = [], ""
    if by_word is True:
        tokens = re.split(r"(\s+)", text)
    elif by_word == "list":
        tokens = re.split(r"(?<=、)", text)
    else:
        # 日本語は文節（BudouX）の切れ目で折る。1文節が1行に収まらないときだけ1字ずつ
        tokens = []
        for ph in _phrases(text):
            if pdfmetrics.stringWidth(ph, font, size) > width:
                tokens += re.findall(r"[0-9]+[つ人個匹章]?|.", ph)
            else:
                tokens.append(ph)
    for tok in tokens:
        if c.stringWidth((cur + tok).rstrip(), font, size) > width and cur.strip():
            if by_word is False and tok in _KINSOKU_HEAD:
                cur, tok = cur[:-1], cur[-1] + tok
            while by_word is False and len(cur) > 1 and cur[-1] in _KINSOKU_TAIL:
                cur, tok = cur[:-1], cur[-1] + tok
            lines.append(cur.rstrip())
            cur = tok.lstrip()
        else:
            cur += tok
    if cur.strip():
        lines.append(cur.strip())
    return tuple(lines)


@functools.lru_cache(maxsize=1)
def _budoux():
    import budoux

    return budoux.load_default_japanese_parser()


def _phrases(text: str) -> list[str]:
    """文節に区切る。行頭に来てはいけない字（、。」など）は前の文節につける。
    短いかぎかっこ（「犬と猫」）と読みがなの括弧（李逵（りき））は、途中で割らない。"""
    out: list[str] = []
    for ph in _budoux().parse(text):
        while ph and out and ph[0] in _KINSOKU_HEAD:
            out[-1] += ph[0]
            ph = ph[1:]
        if ph:
            out.append(ph)
    keep = [(m.start(), m.end()) for m in re.finditer(r"「[^「」]{1,10}」|\S（[^（）]{1,9}）", text)]
    if not keep:
        return out
    merged, pos = [], 0
    for ph in out:
        a, b = pos, pos + len(ph)
        pos = b
        # この文節の始まりが、割ってはいけない範囲の内側なら、前の文節につなげる
        if merged and any(s0 < a < e0 for s0, e0 in keep):
            merged[-1] += ph
        else:
            merged.append(ph)
    return merged


def wrap_even(c: canvas.Canvas, text: str, font: str, size: float, width: float, by_word=False,
              always: bool = False) -> list[str]:
    """wrap と同じ行数のまま、行の長さをそろえる。最後の行だけが極端に短い（数字だけ残る）のを防ぐ。
    always=False なら、最後の行が幅の3割に満たないときだけそろえる。"""
    lines = wrap(c, text, font, size, width, by_word)
    if len(lines) < 2:
        return lines
    if not always:
        # 最後の行が幅の3割に届くまで、行数を変えずに少しずつ幅を狭める（段落の形は崩さない）
        if c.stringWidth(lines[-1], font, size) >= width * 0.3:
            return lines
        w2 = width
        while w2 > width * 0.75:
            w2 -= 2
            trial = wrap(c, text, font, size, w2, by_word)
            if len(trial) != len(lines):
                break
            if c.stringWidth(trial[-1], font, size) >= width * 0.3:
                return trial
        return lines
    lo, hi = width * 0.5, width
    for _ in range(14):
        mid = (lo + hi) / 2
        if len(wrap(c, text, font, size, mid, by_word)) == len(lines):
            hi = mid
        else:
            lo = mid
    return wrap(c, text, font, size, hi, by_word)


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
    {"ofs": 15.0, "lit": 10.0, "litg": 14.0, "story": 10.0, "storyg": 15.5, "gap": 6, "band": 122, "mean": 10.0, "read": 9.0, "readg": 14},
    {"ofs": 14.0, "lit": 9.5, "litg": 13.5, "story": 9.5, "storyg": 14.5, "gap": 4, "band": 122, "mean": 9.5, "read": 8.5, "readg": 13},
    {"ofs": 13.0, "lit": 9.0, "litg": 12.5, "story": 9.0, "storyg": 13.5, "gap": 3, "band": 122, "mean": 9.0, "read": 8.5, "readg": 12},
    {"ofs": 12.0, "lit": 8.5, "litg": 11.5, "story": 8.5, "storyg": 12.5, "gap": 2, "band": 122, "mean": 8.5, "read": 7.5, "readg": 10},
    {"ofs": 12.0, "lit": 8.5, "litg": 11.0, "story": 8.5, "storyg": 12.0, "gap": 1, "band": 122, "mean": 8.5, "read": 7.5, "readg": 9.5},
]


def _card_layout(c: canvas.Canvas, x: dict, k: str, avail: float, P: dict) -> tuple[list[str], float, list[str], list[str]]:
    bf, _ = FONT[k]
    ofs = P["ofs"]
    room = avail
    lines = wrap(c, x["text"], bf, ofs, room, k in ("en", "fr", "ko"))
    while len(lines) > 2 and ofs > 10:
        ofs -= 0.5
        lines = wrap(c, x["text"], bf, ofs, room, k in ("en", "fr", "ko"))
    if len(lines) == 2 and " " not in lines[1].strip():  # 2行目が1語だけ（ぶら下がり）
        for trial in (ofs - 0.5, ofs - 1.0, ofs - 1.5):
            if c.stringWidth(x["text"], bf, trial) <= room:
                ofs, lines = trial, [x["text"]]
                break
    lit = wrap_even(c, x["lit"], FONT_REGULAR, P["lit"], avail, False, always=True)
    rd = [(ln, READ_FONT[k]) for ln in wrap_even(c, x["read"], READ_FONT[k], P["read"], avail, True, always=True)] if x["read"] else []
    if x.get("kana"):  # 中国語は、ピンインの下にカタカナのおよその読み
        rd += [(ln, FONT_REGULAR) for ln in wrap_even(c, x["kana"], FONT_REGULAR, P["read"], avail, True, always=True)]
    return lines, ofs, lit, rd


def draw_item(c: canvas.Canvas, f: Frame, it: dict, no: int) -> dict:
    """1句のページ。標準の字の大きさで収まらなければ、一段ずつ小さくして組む。"""
    for dense in range(len(DENSITY)):
        try:
            _draw_item(canvas.Canvas(io.BytesIO(), pagesize=(f.pw, f.ph)), f, it, no, DENSITY[dense])
        except AssertionError as e:
            last = e
            continue
        return _draw_item(c, f, it, no, DENSITY[dense])
    raise AssertionError(f"1ページに収まらない: {it['jp']} {last}")


def _draw_item(c: canvas.Canvas, f: Frame, it: dict, no: int, P: dict) -> dict:
    """1句のページ。「この本の見方」で指し示す位置（anchors）を返す。"""
    col, tint = COLORS[it["color"]]
    L, R, w = f.left, f.right, f.width
    anchors: dict[str, tuple[float, float]] = {}
    fill_page(c, f, PAPER)
    # 上の色帯（紙の端まで）
    band_h = P["band"]
    if not band_h:  # 0 は「題と意味がちょうど収まる高さ」（いちばん詰めた段階だけ）
        fs0 = 29
        while c.stringWidth(it["jp"], FONT_ROUNDED, fs0) > w - 2 * 48 - 14 and fs0 > 17:
            fs0 -= 0.5
        n_mean = len(wrap_even(c, it["mean"], FONT_BOLD, P["mean"], w - 2 * 48 - 14, False, always=True))
        band_h = 44 + fs0 + 17 + 14 * (n_mean - 1) + 12
    band_bottom = f.top - band_h
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
    pass  # 章名はページ下の柱に出す（色帯では繰り返さない）
    anchors["no"] = (L + 13, f.top - 11)
    # ことわざ（白抜き）
    ic_r = 48
    tw = w - 2 * ic_r - 14
    c.setFont(FONT_BOLD, 9.5)
    c.drawString(L + 1, f.top - 40, it["kana"])
    anchors["kana"] = (L + 40, f.top - 37)
    fs = 29
    while c.stringWidth(it["jp"], FONT_ROUNDED, fs) > tw and fs > 17:
        fs -= 0.5
    c.setFont(FONT_ROUNDED, fs)
    c.drawString(L, f.top - 44 - fs, it["jp"])
    anchors["jp"] = (L + min(tw, c.stringWidth(it["jp"], FONT_ROUNDED, fs)) * 0.5, f.top - 44 - fs * 0.6)
    y = f.top - 44 - fs - 17
    c.setFont(FONT_BOLD, P["mean"])
    mean = wrap_even(c, it["mean"], FONT_BOLD, P["mean"], tw, False, always=True)
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
    c.setFillColorCMYK(*NAVY)
    c.setFont(FONT_ROUNDED, 12.5)
    c.drawString(L, y, "世界では、こう言う")
    c.setStrokeColorCMYK(*NAVY)
    c.setLineWidth(1.2)
    c.line(L + c.stringWidth("世界では、こう言う", FONT_ROUNDED, 12.5) + 8, y + 4, R - 2 * ic_r - 6, y + 4)
    y -= 12
    # 4言語の枠（左端に言語の色の帯。余った高さはふり分ける）
    LABEL = 11  # 言語名の行
    tx = L + 16
    avail = R - tx - 10
    lays = [_card_layout(c, it[k], k, avail, P) for k, _ in LANGS]
    base = [12 + LABEL + (lo[1] + 3.5) * len(lo[0]) + (P["readg"] - 1.5) * len(lo[3]) + 2 * bool(lo[3])
            + P["litg"] * len(lo[2]) + 4 for (k, _), lo in zip(LANGS, lays)]
    story = wrap_even(c, it["story"], FONT_REGULAR, P["story"], w - 30, False)
    story_h = 34 + P["storyg"] * len(story)
    gap = P["gap"]
    free = (y - f.bottom) - sum(base) - 3 * gap - 14 - story_h
    assert free >= 0, (it["jp"], free)
    pad = min(free / 5, 20)
    gap += (free - 5 * pad) / 4  # 残りは枠の間へ（ひとくち話の下端が本文の枠の下にそろう）
    for (k, _), (lines, ofs, lit, rd), h in zip(LANGS, lays, base):
        h += pad
        x = it[k]
        c.setFillColorCMYK(*WHITE)
        c.rect(L, y - h, w, h, stroke=0, fill=1)
        c.setFillColorCMYK(*LANG_COLOR[k])
        c.rect(L, y - h, 3, h, stroke=0, fill=1)
        yy = y - pad / 2 - 15
        # 言語名（その言語の文字 ＋ 日本語）
        name, nfont = NATIVE[k]
        c.setFillColorCMYK(*LANG_COLOR[k])
        c.setFont(nfont, 9.5)
        c.drawString(tx, yy, name)
        nw = c.stringWidth(name, nfont, 9.5)
        c.setFont(FONT_BOLD, 7.5)
        c.drawString(tx + nw + 5, yy, dict(LANGS)[k])
        lab_end = tx + nw + 5 + c.stringWidth(dict(LANGS)[k], FONT_BOLD, 7.5)
        anchors.setdefault("badge", (tx + nw / 2, yy + 3))
        if x.get("trad"):
            c.setFillColorCMYK(*SUB)
            c.setFont("TC", 8)
            tw_ = c.stringWidth(x["trad"], "TC", 8)
            c.drawRightString(R - 10, yy, x["trad"])
            c.setFont(FONT_BOLD, 7)
            c.drawRightString(R - 14 - tw_, yy, "繁体字")
        if x["near"]:
            nx = lab_end + 8
            c.setFillColorCMYK(*LANG_TINT[k])
            c.roundRect(nx, yy - 2.5, 50, 12, 6, stroke=0, fill=1)
            c.setFillColorCMYK(*LANG_COLOR[k])
            c.setFont(FONT_BOLD, 7.5)
            c.drawCentredString(nx + 25, yy + 0.5, "近い言い方")
            anchors.setdefault("near", (nx + 25, yy + 3))
        yy -= LABEL + ofs * 0.45
        bf = FONT[k][0]
        c.setFillColorCMYK(*INK)
        anchors.setdefault("orig", (tx + 50, yy + 4))
        for line in lines:
            c.setFont(bf, ofs)
            c.drawString(tx, yy, line)
            yy -= ofs + 3.5
        if rd:
            c.setFillColorCMYK(*SUB)
            anchors.setdefault("read", (tx + 40, yy + 4))
            for line, rfont in rd:
                c.setFont(rfont, P["read"])
                c.drawString(tx, yy + 1, line)
                yy -= P["readg"] - 1.5
            yy -= 2
        c.setFillColorCMYK(*INK)
        c.setFont(FONT_REGULAR, P["lit"])
        for line in lit:
            c.drawString(tx, yy, line)
            yy -= P["litg"]
        anchors.setdefault("lit", (tx + 40, yy + P["litg"] + 4))
        y -= h + gap
    # ひとくち話
    y -= 8 - gap
    sh = story_h + pad
    c.setFillColorCMYK(*tint)
    c.roundRect(L, y - sh, w, sh, 3, stroke=0, fill=1)
    c.setFillColorCMYK(*col)
    c.rect(L + 14, y - 21, 7, 7, stroke=0, fill=1)
    c.setFillColorCMYK(*NAVY)
    c.setFont(FONT_ROUNDED, 11)
    c.drawString(L + 27, y - 20, "ひとくち話")
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
    c.setFont(FONT_ROUNDED, 46)
    c.drawString(L, f.y1 - 112, f"第{ci + 1}章")
    c.setFont(FONT_ROUNDED, 30)
    c.drawString(L, f.y1 - 168, ch["title"])
    if art_path(f"chapter{ci + 1}"):
        ar = 64
        acx, acy = R - ar, f.y1 - top_h / 2 - 4
        assert acx - ar > L + c.stringWidth(ch["title"], FONT_ROUNDED, 30) + 6, ch["title"]
        c.setFillColorCMYK(*WHITE)
        c.circle(acx, acy, ar + 4, stroke=0, fill=1)
        draw_art(c, f"chapter{ci + 1}", acx, acy, ar)
    # 章の導入
    y = f.y1 - top_h - 24
    intro = wrap_even(c, ch.get("intro", ""), FONT_REGULAR, 10.5, w - 32, False)
    bh = 26 + 17 * len(intro)
    c.setFillColorCMYK(*WHITE)
    c.roundRect(L, y - bh, w, bh, 10, stroke=0, fill=1)
    c.setFillColorCMYK(*INK)
    c.setFont(FONT_REGULAR, 10.5)
    for li, line in enumerate(intro):
        c.drawString(L + 16, y - 22 - li * 17, line)
    y -= bh + 22
    # どこの国の言い方？（3問）
    c.setFillColorCMYK(*col)
    c.setFont(FONT_ROUNDED, 14)
    c.drawString(L, y, "どこの国の言い方？")
    c.setFillColorCMYK(*SUB)
    c.setFont(FONT_REGULAR, 8.5)
    c.drawString(L + c.stringWidth("どこの国の言い方？", FONT_ROUNDED, 14) + 10, y + 1, "日本のことわざでいうと、どれでしょう。")
    y -= 14
    qs = chapter_quiz(items, ci)
    qh = (y - f.bottom - 34) / len(qs) - 8
    for j, (k, lang, lit) in enumerate(qs):
        c.setFillColorCMYK(*WHITE)
        c.roundRect(L, y - qh, w, qh, 9, stroke=0, fill=1)
        c.setFillColorCMYK(*col)
        c.circle(L + 20, y - qh / 2, 11, stroke=0, fill=1)
        c.setFillColorCMYK(*WHITE)
        c.setFont(FONT_ROUNDED, 12)
        c.drawCentredString(L + 20, y - qh / 2 - 4.2, str(j + 1))
        c.setFillColorCMYK(*LANG_COLOR[lang])
        c.setFont(FONT_BOLD, 8.5)
        c.drawString(L + 42, y - qh / 2 + 9, f"{dict(LANGS)[lang]}では")
        c.setFillColorCMYK(*INK)
        fs = 12.5
        text = f"「{lit}」"
        while c.stringWidth(text, FONT_BOLD, fs) > w - 56 and fs > 9:
            fs -= 0.25
        c.setFont(FONT_BOLD, fs)
        c.drawString(L + 42, y - qh / 2 - 9, text)
        y -= qh + 8
    # こたえ
    c.setFillColorCMYK(*SUB)
    c.setFont(FONT_REGULAR, 8)
    # こたえは逆さまに組む（問いを読む前に目に入らないように）
    c.saveState()
    c.translate(R, f.bottom + 2)
    c.rotate(180)
    c.setFont(FONT_BOLD, 8)
    c.drawString(0, -8, "こたえ")
    c.setFont(FONT_REGULAR, 8)
    for j, (k, _, _) in enumerate(qs):
        c.drawString(34, -8 - j * 11, f"{j + 1}　{items[k]['jp']}（{item_page(spec, k)}ページ）")
    c.restoreState()


def review_quiz(items: list[dict], ci: int, n: int = 6) -> list[tuple[int, str, str]]:
    """章のおさらいの問い。章扉のクイズに出した句と QUIZ_SKIP を除き、直訳から当てる問いを1句1問で選ぶ。"""
    used = {k for k, _, _ in chapter_quiz(items, ci)}
    cands = []
    for k, it in enumerate(items):
        if it["chapter"] != ci or k in used or it["jp"] in QUIZ_SKIP:
            continue
        best = None
        for lang, _ in LANGS:
            m = re.fullmatch(r"直訳「(.+)」", it[lang]["lit"])
            if not m or not 5 <= len(m.group(1)) <= 26:
                continue
            body = m.group(1)
            overlap = sum(ch in it["jp"] for ch in set(body) if re.match(r"[一-龥ぁ-んァ-ン]", ch))
            if best is None or overlap < best[0]:
                best = (overlap, k, lang, body)
        if best:
            cands.append(best)
    cands.sort()
    return sorted((k, lang, body) for _, k, lang, body in cands[:n])


def draw_review(c: canvas.Canvas, f: Frame, spec: SekaiSpec, items: list[dict], ci: int) -> None:
    """章の最後のおさらい。外国語の直訳から、この章のことわざを当てる。こたえは逆さまに。"""
    ch = spec.chapters[ci]
    col, tint = COLORS[ch["color"]]
    L, R, w = f.left, f.right, f.width
    fill_page(c, f, tint)
    c.setFillColorCMYK(*col)
    c.rect(0, f.y1 - 70, f.pw, 70 + BLEED, stroke=0, fill=1)
    c.setFillColorCMYK(*WHITE)
    c.setFont(FONT_BOLD, 9)
    c.drawString(L, f.top - 6, f"第{ci + 1}章　{ch['title']}")
    c.setFont(FONT_ROUNDED, 18)
    c.drawString(L, f.top - 30, "おさらい　どこの国の言い方？")
    y = f.y1 - 70 - 22
    c.setFillColorCMYK(*INK)
    c.setFont(FONT_REGULAR, 9)
    c.drawString(L, y, "外国語の直訳を読んで、この章のどのことわざか当ててみましょう。")
    y -= 16
    qs = review_quiz(items, ci)
    qh = (y - f.bottom - 84) / max(1, len(qs)) - 6
    for j, (k, lang, lit) in enumerate(qs):
        c.setFillColorCMYK(*WHITE)
        c.roundRect(L, y - qh, w, qh, 3, stroke=0, fill=1)
        c.setFillColorCMYK(*col)
        c.circle(L + 16, y - qh / 2, 9, stroke=0, fill=1)
        c.setFillColorCMYK(*WHITE)
        c.setFont(FONT_ROUNDED, 10)
        c.drawCentredString(L + 16, y - qh / 2 - 3.5, str(j + 1))
        c.setFillColorCMYK(*LANG_COLOR[lang])
        c.setFont(FONT_BOLD, 8)
        c.drawString(L + 34, y - 14, f"{dict(LANGS)[lang]}では")
        c.setFillColorCMYK(*INK)
        text = f"「{lit}」"
        fs = 11
        while c.stringWidth(text, FONT_BOLD, fs) > w - 46 and fs > 8:
            fs -= 0.25
        c.setFont(FONT_BOLD, fs)
        c.drawString(L + 34, y - 30, text)
        c.setStrokeColorCMYK(0, 0, 0, 0.3)
        c.setLineWidth(0.75)
        c.line(L + 34, y - qh + 9, R - 10, y - qh + 9)
        y -= qh + 6
    c.saveState()
    c.translate(R, f.bottom + 2)
    c.rotate(180)
    c.setFillColorCMYK(*SUB)
    c.setFont(FONT_BOLD, 8)
    c.drawString(0, -8, "こたえ")
    c.setFont(FONT_REGULAR, 8)
    for j, (k, _, _) in enumerate(qs):
        c.drawString(34, -8 - j * 11, f"{j + 1}　{items[k]['jp']}（{item_page(spec, k)}ページ）")
    c.restoreState()
    folio(c, f, f"第{ci + 1}章　{ch['title']}")


# クイズに出さない句（手がかりが「青天の霹靂」など別の日本語に読める／はじめに・章の導入で答えを見せている）
QUIZ_SKIP = {"寝耳に水", "犬猿の仲", "猿も木から落ちる", "猫に小判"}


def chapter_quiz(items: list[dict], ci: int, n: int = 3) -> list[tuple[int, str, str]]:
    """章扉のクイズ。日本語のことわざと字がいちばん重ならない外国語の直訳を、言語が偏らないように選ぶ。"""
    cands = []
    for k, it in enumerate(items):
        if it["chapter"] != ci or it["jp"] in QUIZ_SKIP:
            continue
        for lang, _ in LANGS:
            lit = it[lang]["lit"]
            m = re.fullmatch(r"直訳「(.+)」", lit)
            if not m or not 5 <= len(m.group(1)) <= 22:
                continue
            body = m.group(1)
            overlap = sum(ch in it["jp"] for ch in set(body) if re.match(r"[一-龥ぁ-んァ-ン]", ch))
            cands.append((overlap, k, lang, body))
    cands.sort()
    out, used_k, used_lang = [], set(), {}
    for overlap, k, lang, body in cands:
        if k in used_k or used_lang.get(lang, 0) >= 1 and len(used_lang) < 3:
            continue
        out.append((k, lang, body))
        used_k.add(k)
        used_lang[lang] = used_lang.get(lang, 0) + 1
        if len(out) == n:
            break
    assert len(out) == n, ci
    return sorted(out)


# --- 前付け・後付け ---------------------------------------------------------------


def _heading(c: canvas.Canvas, f: Frame, text: str, color: CMYK = NAVY) -> float:
    """ページの見出し（紙の端までの細い帯つき）。本文を書き始める y を返す。"""
    c.setFillColorCMYK(*color)
    c.rect(0, f.y1 - 0.07 * inch, f.pw, 0.07 * inch + BLEED, stroke=0, fill=1)
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
    for line in wrap_even(c, text, FONT_REGULAR, fs, width or f.width, False):
        c.drawString(x, y, line)
        y -= gap
    return y


def _item_image(spec: SekaiSpec, it: dict, no: int, width_pt: float, dpi: int = 300) -> tuple[ImageReader, dict, Frame]:
    """1句のページを画像にする（「この本の見方」と裏表紙の見本）。仕上がりの範囲だけを切り出す。"""
    import pypdfium2

    f = frame(spec, item_page(spec, no - 1))
    buf = io.BytesIO()
    pc = canvas.Canvas(buf, pagesize=(f.pw, f.ph), initialFontName=FONT_REGULAR)
    anchors = draw_item(pc, f, it, no)
    pc.save()
    scale = dpi / 72 * (width_pt / (f.x1 - f.x0))
    img = pypdfium2.PdfDocument(buf.getvalue())[0].render(scale=scale).to_pil()
    k = img.width / f.pw
    img = to_cmyk(img.crop((int(f.x0 * k), int((f.ph - f.y1) * k), int(f.x1 * k), int((f.ph - f.y0) * k))))
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
    intro_i = next(k for k, it in enumerate(items) if it["jp"] == "犬猿の仲")
    intro_s = items[intro_i]
    for text in [
        "「犬猿の仲」を、英語とフランス語では「犬と猫のように仲が悪い」と言います。中国語では「水と火」。"
        "韓国語は、日本語と同じ「犬と猿」です。",
        "同じ気持ちを、国によってちがうものにたとえている。そのちがいを見くらべるのが、この本の楽しみ方です。",
    ]:
        y = _para(c, f, text, y, gap=17) - 7
    # 絵: 猿と4つのふきだし
    y -= 6
    if not draw_art(c, f"item{intro_i + 1:02d}", f.left + 33, y - 37, 33):
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
        while c.stringWidth(intro_s[k]["text"], bf, fs) > bw - 70:
            fs -= 0.5
        c.setFont(bf, fs)
        c.drawString(f.left + 146, by - 16, intro_s[k]["text"])
        by -= 28
    y = by - 12
    for text in [
        "日本でよく知られたことわざを50選び（慣用句や四字熟語、西洋から入った言い方も含みます）、英語・フランス語・中国語・韓国語で同じ意味の言い方を並べました。"
        "外国語の言い方は、どれも2つ以上の辞書や資料で、実際に使われていることと意味を確かめたものです。",
        "ぴったり同じ意味の言い方がない言語は、意味の近い言い方に「近い言い方」の札をつけて載せています。",
    ]:
        y = _para(c, f, text, y, gap=17) - 7
    # この本の楽しみ方（3つ）
    tips = [
        ("たとえを見くらべる", "同じ意味でも、国ごとにたとえるものがちがいます。"),
        ("声に出して読む", "読み方つき。ぜひ声に出して読んでみてください。"),
        ("どこから読んでもよい", "1ページに1つ。もくじやさくいんで引けます。"),
    ]
    col_w = (f.width - 28 - 2 * 8) / 3
    bodies = [wrap_even(c, body, FONT_REGULAR, 8.5, col_w - 4, False, always=True) for _, body in tips]
    box_h = 40 + 18 + 12.5 * max(len(b) for b in bodies)
    y -= 2
    c.setFillColorCMYK(*WHITE)
    c.roundRect(f.left, y - box_h, f.width, box_h, 10, stroke=0, fill=1)
    c.setFillColorCMYK(*NAVY)
    c.setFont(FONT_ROUNDED, 12)
    c.drawString(f.left + 14, y - 20, "この本の楽しみ方")
    for j, ((head, _), body) in enumerate(zip(tips, bodies)):
        x = f.left + 14 + j * (col_w + 8)
        ty = y - 41
        c.setFillColorCMYK(*GOLD)
        c.circle(x + 7, ty + 3.5, 7.5, stroke=0, fill=1)
        c.setFillColorCMYK(*NAVY)
        c.setFont(FONT_BOLD, 9)
        c.drawCentredString(x + 7, ty + 0.5, str(j + 1))
        fs = 9.5
        while c.stringWidth(head, FONT_BOLD, fs) > col_w - 20:
            fs -= 0.25
        c.setFont(FONT_BOLD, fs)
        c.drawString(x + 19, ty, head)
        c.setFillColorCMYK(*INK)
        c.setFont(FONT_REGULAR, 8.5)
        for li, line in enumerate(body):
            c.drawString(x, ty - 18 - li * 12.5, line)
    assert y - box_h >= f.bottom, y - box_h
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
        yy = ny - j * step
        c.setStrokeColorCMYK(*NAVY)
        c.setLineWidth(0.8)
        c.line(px, py, mx + mini_w + 4, py)
        c.line(mx + mini_w + 4, py, tx, yy + 3)
        c.setFillColorCMYK(*GOLD)
        c.circle(px, py, 3.2, stroke=1, fill=1)
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
    # 章の色
    y = my - 34
    c.setFillColorCMYK(*NAVY)
    c.setFont(FONT_ROUNDED, 12)
    c.drawString(f.left, y, "5つの章は、色で分けています")
    y -= 14
    chip_w = (f.width - 4 * 6) / 5
    for ci, ch in enumerate(spec.chapters):
        col = COLORS[ch["color"]][0]
        x = f.left + ci * (chip_w + 6)
        c.setFillColorCMYK(*col)
        c.roundRect(x, y - 46, chip_w, 46, 8, stroke=0, fill=1)
        c.setFillColorCMYK(*WHITE)
        c.setFont(FONT_BOLD, 8)
        c.drawCentredString(x + chip_w / 2, y - 16, f"第{ci + 1}章")
        fs = 10
        while c.stringWidth(ch["title"], FONT_BOLD, fs) > chip_w - 8:
            fs -= 0.5
        c.setFont(FONT_BOLD, fs)
        c.drawCentredString(x + chip_w / 2, y - 34, ch["title"])
    y -= 64
    y = _para(c, f, "ページの上の色帯と「ひとくち話」の枠は、その章の色です。"
              "どの章も、10のことわざを1ページに1つずつ載せています。", y, fs=9.5, gap=15)
    assert y >= f.bottom, y
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
        c.drawString(f.left + 22, y - 32, name)
        c.setFillColorCMYK(*INK)
        c.setFont(FONT_BOLD, 11)
        c.drawString(f.left + 30 + c.stringWidth(name, font, 22), y - 31, jp)
        c.setFillColorCMYK(*SUB)
        c.setFont(FONT_REGULAR, 8.5)
        c.drawString(f.left + 22, y - 50, "おもに使われているところ")
        c.setFillColorCMYK(*INK)
        c.setFont(FONT_REGULAR, 10)
        c.drawString(f.left + 22, y - 64, REGIONS[k])
        c.setFillColorCMYK(*SUB)
        c.setFont(FONT_REGULAR, 8.5)
        for li, line in enumerate(wrap_even(c, READ_NOTE[k], FONT_REGULAR, 8.5, f.width - 40, False)):
            c.drawString(f.left + 22, y - 81 - li * 11.5, line)
        y -= ch_h + 10
    folio(c, f)
    turn()

    # 5. もくじ（1行に1つ、2段組み）
    f = page()
    fill_page(c, f, PAPER)
    y0 = _heading(c, f, "もくじ") + 6
    col_w = (f.width - 16) / 2
    rows = []
    for ci, ch in enumerate(spec.chapters):
        rows.append(("ch", ci, ch["title"], chapter_page(spec, ci)))
        rows += [("it", k + 1, it["jp"], item_page(spec, k)) for k, it in enumerate(items) if it["chapter"] == ci]
    rows += [("end", -1, label, pno) for label, pno in
             (("おわりに", total - 6), ("さくいん", total - 4), ("英語から引くさくいん", total - 3),
              ("フランス語から引くさくいん", total - 2), ("参考にした資料", total - 1))]
    split = next(i for i, r in enumerate(rows) if r[0] == "ch" and r[1] == 3)  # 第4章から右の段
    LH = 12.2
    for half, part in enumerate((rows[:split], rows[split:])):
        x = f.left + half * (col_w + 16)
        y = y0
        for kind, ci, label, pno in part:
            if kind == "ch":
                col = COLORS[spec.chapters[ci]["color"]][0]
                y -= 6
                c.setFillColorCMYK(*col)
                c.roundRect(x, y - 6, col_w, 20, 6, stroke=0, fill=1)
                c.setFillColorCMYK(*WHITE)
                c.setFont(FONT_ROUNDED, 11)
                c.drawString(x + 8, y, f"第{ci + 1}章　{label}")
                c.setFont(FONT_BOLD, 9)
                c.drawRightString(x + col_w - 8, y, str(pno))
                y -= 22
            elif kind == "it":
                c.setFillColorCMYK(*COLORS[items[ci - 1]["color"]][0])
                c.setFont(FONT_ROUNDED, 8)
                c.drawString(x + 6, y, f"{ci:02d}")
                c.setFillColorCMYK(*INK)
                fs = 9
                while c.stringWidth(label, FONT_REGULAR, fs) > col_w - 56:
                    fs -= 0.25
                c.setFont(FONT_REGULAR, fs)
                c.drawString(x + 24, y, label)
                c.setFillColorCMYK(*SUB)
                c.setFont(FONT_REGULAR, 8.5)
                c.drawRightString(x + col_w - 8, y, str(pno))
                y -= LH
            else:
                y -= 6
                c.setFillColorCMYK(*NAVY)
                c.setFont(FONT_ROUNDED, 10.5)
                c.drawString(x + 4, y, label)
                c.setFillColorCMYK(*SUB)
                c.setFont(FONT_BOLD, 9)
                c.drawRightString(x + col_w - 8, y, str(pno))
                y -= 16
        assert y >= f.bottom - 4, (half, y - f.bottom)
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
        assert n == review_page(spec, ci)
        draw_review(c, page(), spec, items, ci)
        turn()

    # 7. おわりに
    f = page()
    fill_page(c, f, PAPER)
    y = _heading(c, f, "おわりに")
    for text in [
        "50のことわざを、4つのことばで見くらべてきました。",
        "「氷山の一角」のように、どの国でもほとんど同じ言い方をするものもあれば、"
        "「猫に小判」が「豚に真珠」になるように、たとえがすっかり変わるものもありました。",
        "ことわざは、その土地の暮らしや、身近な生きもの、食べもの、昔の書物から生まれます。"
        "ちがうたとえの向こうに、よく似た気持ちが見えてくる。それが、世界のことわざを並べる楽しさです。",
    ]:
        y = _para(c, f, text, y, gap=17) - 10
    # 見くらべてわかったこと
    finds = [
        ("動物が入れかわる", "「犬猿の仲」は英語とフランス語では犬と猫。「馬の耳に念仏」は、中国語と韓国語では牛です。"),
        ("正反対に見えるもの", "フランス語の「僧衣が修道士をつくるのではない」と、英語の「服が人をつくる」。見た目について、逆のことを言っています。"),
        ("同じ出どころ", "「百聞は一見にしかず」「鶏口となるも牛後となるなかれ」は、中国の古い書物から日本と韓国へ広まったことばです。"),
    ]
    rows = [(h, wrap_even(c, t, FONT_REGULAR, 9, f.width - 40, False)) for h, t in finds]
    bh = 30 + sum(16 + 13 * len(r) + 6 for _, r in rows)
    y -= 2
    c.setFillColorCMYK(*WHITE)
    c.roundRect(f.left, y - bh, f.width, bh, 3, stroke=0, fill=1)
    c.setFillColorCMYK(*NAVY)
    c.setFont(FONT_ROUNDED, 12)
    c.drawString(f.left + 14, y - 20, "見くらべて、わかったこと")
    ty = y - 40
    for head, lines in rows:
        c.setFillColorCMYK(*GOLD)
        c.rect(f.left + 14, ty + 1, 6, 6, stroke=0, fill=1)
        c.setFillColorCMYK(*NAVY)
        c.setFont(FONT_BOLD, 9.5)
        c.drawString(f.left + 26, ty, head)
        ty -= 15
        c.setFillColorCMYK(*INK)
        c.setFont(FONT_REGULAR, 9)
        for line in lines:
            c.drawString(f.left + 26, ty, line)
            ty -= 13
        ty -= 7
    y -= bh + 16
    y = _para(c, f, "気になった言い方があれば、ぜひ声に出して読んでみてください。", y, gap=17)
    mid = (f.left + f.right) / 2
    art_r = min(60, (y - f.bottom - 10) / 2)
    if art_r > 25:
        draw_art(c, "title", mid, f.bottom + art_r + 2, art_r)
    folio(c, f)
    turn()

    # 7b. 書きとめメモ
    f = page()
    fill_page(c, f, PAPER)
    y = _heading(c, f, "書きとめておこう")
    y = _para(c, f, "気に入った言い方や、ほかの国でも探してみたいことわざを書きとめておきましょう。", y, fs=9.5, gap=15) - 10
    c.setStrokeColorCMYK(0, 0, 0, 0.25)
    c.setLineWidth(0.75)
    while y - 26 >= f.bottom:
        y -= 26
        c.line(f.left, y, f.right, y)
    folio(c, f)
    turn()

    # 8. さくいん（五十音順）
    f = page()
    fill_page(c, f, PAPER)
    y = _heading(c, f, "さくいん")
    order = sorted(range(len(items)), key=lambda k: kana_key(items[k]["kana"]))
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

    # 8b. 英語・フランス語から引くさくいん（アルファベット順）
    for lang, title in (("en", "英語から引くさくいん"), ("fr", "フランス語から引くさくいん")):
        f = page()
        fill_page(c, f, PAPER)
        y = _heading(c, f, title)
        c.setFillColorCMYK(*SUB)
        c.setFont(FONT_REGULAR, 7.5)
        c.drawRightString(f.right, f.top - 32, "点の色は章を表します")
        order = sorted(range(len(items)), key=lambda k: foreign_key(items[k][lang]["text"]))
        row = (y - f.bottom + 4) / len(order)
        for m, k in enumerate(order):
            yy = y - m * row
            c.setFillColorCMYK(*COLORS[items[k]["color"]][0])
            c.circle(f.left + 3, yy + 2.8, 2.2, stroke=0, fill=1)
            text = items[k][lang]["text"]
            c.setFillColorCMYK(*INK)
            fs = 8.5
            while c.stringWidth(text, "LAT", fs) > f.width - 40 and fs > 7:
                fs -= 0.25
            c.setFont("LAT", fs)
            c.drawString(f.left + 10, yy, text)
            c.setFillColorCMYK(*SUB)
            c.setFont(FONT_BOLD, 8.5)
            pg = str(item_page(spec, k))
            c.drawRightString(f.right, yy, pg)
            assert c.stringWidth(text, "LAT", fs) < f.width - 36, text
            # 原文とページ番号の間の点線
            x_a = f.left + 10 + c.stringWidth(text, "LAT", fs) + 4
            x_b = f.right - c.stringWidth(pg, FONT_BOLD, 8.5) - 4
            if x_b - x_a > 8:
                c.saveState()
                c.setStrokeColorCMYK(0, 0, 0, 0.35)
                c.setLineWidth(0.75)
                c.setDash(0.8, 2.4)
                c.line(x_a, yy + 2, x_b, yy + 2)
                c.restoreState()
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
        y -= 15
        for line in wrap(c, text, FONT_REGULAR, 9, f.width, "list"):
            c.drawString(f.left, y, line)
            y -= 13.5
        y -= 5
    y -= 4
    for head, body in [
        ("「近い言い方」の札について",
         "たとえがちがっても、意味が日本のことわざと同じものには札をつけていません（「猫に小判」と「豚に真珠」など）。"
         "意味の範囲や使う場面が少しずれるものに、「近い言い方」の札をつけました。"),
        ("読み方について",
         "中国語は中国大陸の簡体字で書き、繁体字を添えて、ピンイン（ローマ字の読み）をつけました。"
         "英語・フランス語・韓国語のカタカナは、およその音です。韓国語の語頭の「ッ」は、詰まった強い音（濃音）の印です。"),
    ]:
        c.setFillColorCMYK(*NAVY)
        c.setFont(FONT_BOLD, 10)
        c.drawString(f.left, y, head)
        y = _para(c, f, body, y - 15, fs=9, gap=13.5) - 6
    assert y >= f.bottom, y - f.bottom
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
    # © は Noto Sans JP に無いので、欧文の書体で描く
    c.setFont("LAT", 9)
    c.drawString(f.left, y, "©")
    c.setFont(FONT_REGULAR, 9)
    c.drawString(f.left + c.stringWidth("© ", "LAT", 9), y, " ".join(t for t in (year, spec.publisher) if t))
    y -= 20
    c.setFont(FONT_REGULAR, 7.5)
    for line in (FONT_CREDIT[:1] + [ART_CREDIT]) if has_art() else FONT_CREDIT:
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
    c.setFillColorCMYK(0.0, 0.04, 0.13, 0.0)  # 本文の生成りより少し濃く（Amazon の白い背景に溶けないように）
    c.rect(0, 0, W, H, stroke=0, fill=1)
    spine_x0, fx = b + tw, b + tw + sp
    cx, top = fx + tw / 2, b + th
    # 紺の上半分（背から表まで）
    cover_art = art_path("cover") is not None
    art_r = 0.95 * inch if cover_art else 0.62 * inch
    band = top - (3.2 if cover_art else 2.8) * inch
    c.setFillColorCMYK(*NAVY)
    c.rect(0, band, W, H - band, stroke=0, fill=1)
    # 表表紙（小さなサムネイルでも読めるよう、題名を大きく）
    c.setFillColorCMYK(*GOLD)
    c.setFont(FONT_BOLD, 12.5)
    c.drawCentredString(cx, top - 0.6 * inch, "英語・フランス語・中国語・韓国語で読む")
    outlined_text(c, "日本のことわざ、", cx, top - 1.2 * inch, font=FONT_ROUNDED, size=31,
                  fill=CMYKColor(*WHITE), outline=CMYKColor(*NAVY), outline_width=1)
    t2 = 42
    while c.stringWidth("世界ではこう言う", FONT_ROUNDED, t2) > tw - 2 * safe - 10:
        t2 -= 1
    outlined_text(c, "世界ではこう言う", cx, top - 1.98 * inch, font=FONT_ROUNDED, size=t2,
                  fill=CMYKColor(*GOLD), outline=CMYKColor(*NAVY), outline_width=1)
    # 猿の絵（紺と生成りの境目）
    c.setFillColorCMYK(*GOLD)
    c.circle(cx, band, art_r + 3, stroke=0, fill=1)
    c.setFillColorCMYK(*WHITE)
    c.circle(cx, band, art_r, stroke=0, fill=1)
    if not draw_art(c, "cover", cx, band, art_r):
        draw_icon(c, "1f412", cx - 0.45 * inch, band - 0.45 * inch, 0.9 * inch)
    c.setFillColorCMYK(*COLORS["green"][0])
    c.setFont(FONT_ROUNDED, 20)
    c.drawCentredString(cx, band - art_r - 0.38 * inch, sample["jp"])
    # 英語とフランス語では、どう言う？（直訳を大きく、原文を小さく）
    y = band - art_r - 0.6 * inch
    card_w = tw - 2 * safe - 16
    for k in ("en", "fr", "ko"):
        ch_h = 0.6 * inch
        c.setFillColorCMYK(*LANG_COLOR[k])
        c.roundRect(cx - card_w / 2, y - ch_h, card_w, ch_h, 9, stroke=0, fill=1)
        c.setFillColorCMYK(*WHITE)
        c.roundRect(cx - card_w / 2 + 6, y - ch_h, card_w - 6, ch_h, 9, stroke=0, fill=1)
        c.rect(cx - card_w / 2 + 6, y - ch_h, 10, ch_h, stroke=0, fill=1)
        lx = cx - card_w / 2 + 18
        c.setFillColorCMYK(*LANG_COLOR[k])
        c.setFont(FONT_BOLD, 10)
        c.drawString(lx, y - 15, f"{dict(LANGS)[k]}では")
        lit = "「" + re.sub(r"^直訳「(.*)」$", lambda m: m.group(1), sample[k]["lit"]) + "」"
        fs = 17
        while c.stringWidth(lit, FONT_BOLD, fs) > card_w - 34:
            fs -= 0.5
        c.setFillColorCMYK(*INK)
        c.setFont(FONT_BOLD, fs)
        c.drawString(lx - 4, y - 34, lit)
        c.setFillColorCMYK(*SUB)
        c.setFont(FONT[k][1], 8.5)
        c.drawRightString(cx + card_w / 2 - 10, y - 15, sample[k]["text"])
        y -= ch_h + 8
    # 下の帯（ひとことで何の本か）
    c.setFillColorCMYK(*NAVY)
    bb = b + safe + 0.32 * inch
    c.roundRect(cx - card_w / 2, bb, card_w, 0.46 * inch, 0.23 * inch, stroke=0, fill=1)
    c.setFillColorCMYK(*WHITE)
    c.setFont(FONT_ROUNDED, 15)
    c.drawCentredString(cx, bb + 0.16 * inch, "4つのことばで見くらべる、50のことわざ")
    assert y > bb + 0.46 * inch + 6, (y, bb)
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
    yy = top - safe - 74
    for jp, lang, said in [("猫に小判", "英語", "豚に真珠"), ("犬猿の仲", "フランス語", "犬と猫"),
                           ("泣きっ面に蜂", "韓国語", "雪の上に霜")]:
        c.setFillColorCMYK(*WHITE)
        c.setFont(FONT_BOLD, 11)
        c.drawString(bx0, yy, f"「{jp}」")
        w1 = c.stringWidth(f"「{jp}」", FONT_BOLD, 11)
        c.setFont(FONT_REGULAR, 9.5)
        c.drawString(bx0 + w1, yy, f"は、{lang}では")  # 」の字幅にもう空きがあるので、間を足さない
        w2 = c.stringWidth(f"は、{lang}では", FONT_REGULAR, 9.5)
        c.setFillColorCMYK(*GOLD)
        c.setFont(FONT_BOLD, 11)
        c.drawString(bx0 + w1 + w2, yy, f"「{said}」")
        yy -= 19
    c.setFillColorCMYK(*WHITE)
    c.setFont(FONT_REGULAR, 9.5)
    yy -= 4
    for line in ["同じ気持ちを、国ごとにちがうものにたとえる。", "そのちがいを見くらべる、50のことわざの本です。"]:
        c.drawString(bx0, yy, line)
        yy -= 15
    assert yy > band + 4, yy - band
    bw, bh = (v * inch for v in kdp_spec.BARCODE_BOX_IN)
    sf = frame(spec, 1)
    ratio = (sf.y1 - sf.y0) / (sf.x1 - sf.x0)
    # 見本ページ（右）。紺の帯とバーコード欄の間に収める
    mini_w = min(tw * 0.38, (band - 0.16 * inch - (b + safe + bh + 14)) / ratio)
    img, _, sf = _item_image(spec, items[30], 31, mini_w)
    mini_h = mini_w * ratio
    mx = spine_x0 - safe - 8 - mini_w
    my = band - 0.16 * inch - mini_h
    assert my >= b + safe + bh + 12, my
    c.setFillColorCMYK(0.0, 0.10, 0.25, 0.15)
    c.rect(mx + 4, my - 4, mini_w, mini_h, stroke=0, fill=1)
    c.drawImage(img, mx, my, mini_w, mini_h)
    # 左の段: こんな人に・この本の中身
    colw = mx - 18 - bx0
    ly = band - 0.3 * inch
    for head, rows in [("こんな人に", ["英語・フランス語・中国語・韓国語を学んでいる人", "ことわざや、ことばの雑学が好きな人",
                                      "国ごとのものの見方のちがいを楽しみたい人"]),
                       ("この本の中身", ["1ページに1つ、オールカラーの挿絵つき", "4つのことばの原文・読み方・直訳",
                                         "外国語の言い方は、すべて出典を確かめています"])]:
        c.setFillColorCMYK(*NAVY)
        c.setFont(FONT_ROUNDED, 12)
        c.drawString(bx0, ly, head)
        ly -= 17
        for row in rows:
            parts = wrap_even(c, row, FONT_REGULAR, 9, colw - 12, False)
            c.setFillColorCMYK(*GOLD)
            c.circle(bx0 + 3, ly + 3, 2.6, stroke=0, fill=1)
            c.setFillColorCMYK(*INK)
            c.setFont(FONT_REGULAR, 9)
            for part in parts:
                c.drawString(bx0 + 11, ly, part)
                ly -= 13
            ly -= 4
        ly -= 10
    assert ly > b + safe, ly
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
