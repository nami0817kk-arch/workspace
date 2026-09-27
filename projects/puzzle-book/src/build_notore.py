"""「あたまの体操 30日」（高齢者向けの脳トレ詰め合わせ）の本文PDFと表紙PDFを組む。

1日2ページ×30日。左のページは計算と数字さがし、右のページはことば探し（奇数日）か
同じ絵さがし（偶数日）と、時計の読み取り、思い出トーク。難しさは10日ごとに上げる。
パズルの生成と検証は libs/puzzle-generator（drills と wordsearch）。ここは紙面だけ。
紙面の部品（色・見出しの帯・盤面・絵・余白）はことば探しの本（build_kotoba.py）と共通。
"""

from __future__ import annotations

import argparse
import io
import json
import math
from dataclasses import dataclass
from pathlib import Path

from puzzle_generator import (
    build_arithmetic,
    build_clock,
    build_number_search,
    build_pair_search,
    build_wordsearch,
    validate_record,
)
from reportlab.lib.colors import CMYKColor
from reportlab.lib.units import inch
from reportlab.lib.utils import ImageReader
from reportlab.pdfgen import canvas

import kdp_spec
from art import FONT_ROUNDED, ICON_CREDIT, draw_icon, outlined_text
from build_book import DIFFICULTY_LABEL_JA, DIFFICULTY_STARS, FONT_BOLD, FONT_REGULAR, _Pager
from build_cover import CREAM, NAVY, ORANGE, WHITE
from build_kotoba import BLACK, COLOR, COPY_PERMISSION, GRAY, CMYK, Palette, _draw_label, _header_band, _seal, draw_grid

_ASSETS = Path(__file__).resolve().parent.parent / "assets"
# 同じ絵さがしに使う絵（Noto Emoji）。題名や表紙の飾りで意味を持つもの（虫めがね・吹き出し）は除く
PAIR_ICONS = sorted(p.stem.removeprefix("emoji_u") for p in (_ASSETS / "emoji").glob("emoji_u*.svg")
                    if p.stem not in ("emoji_u1f50d", "emoji_u1f4ac"))

LEVEL_PARAMS = {
    # 数字さがしの大きさ、同じ絵さがしの盤面、ことば探しの盤面と向き
    "easy": {"number": 4, "pair": (4, 5), "ws_size": 7, "ws_dirs": ["E", "S"]},
    "medium": {"number": 5, "pair": (5, 6), "ws_size": 7, "ws_dirs": ["E", "S"]},
    "hard": {"number": 6, "pair": (6, 6), "ws_size": 8, "ws_dirs": ["E", "S", "SE"]},
}
PUZZLE_NAMES = ["計算", "数字さがし", "ことば探し", "同じ絵さがし", "時計"]


@dataclass
class NotoreSpec:
    title: str
    subtitle: str
    days: list[dict]
    seed_start: int
    trim: str = "a4"
    publisher: str = "つるはし社"
    edition_date: str = ""
    ink: str = "premium"
    copy_ok: bool = False

    @classmethod
    def load(cls, path: str | Path) -> "NotoreSpec":
        return cls(**json.loads(Path(path).read_text(encoding="utf-8")))

    @property
    def palette(self) -> Palette:
        return COLOR if self.ink == "premium" else GRAY


def generate_days(spec: NotoreSpec) -> list[dict]:
    """1日分ずつ、計算・数字さがし・右のパズル・時計を作って検証する。"""
    out = []
    for d in spec.days:
        seed = spec.seed_start + d["day"] * 100
        lv = d["difficulty"]
        p = LEVEL_PARAMS[lv]
        right = d["right"]
        if right["kind"] == "wordsearch":
            r = build_wordsearch(right["words"], lv, seed + 3, theme=right["theme"],
                                 size=p["ws_size"], directions=p["ws_dirs"])
        else:
            rows, cols = p["pair"]
            r = build_pair_search(PAIR_ICONS, rows, cols, seed + 3, lv)
        day = {
            "day": d["day"],
            "difficulty": lv,
            "talk": d.get("talk", ""),
            "icon": right.get("icon"),
            "arithmetic": build_arithmetic(lv, seed + 1),
            "number": build_number_search(p["number"], seed + 2, lv),
            "right": r,
            "clock": build_clock(lv, seed + 4),
        }
        for key in ("arithmetic", "number", "right", "clock"):
            validate_record(day[key])
        out.append(day)
    return out


def page_count(spec: NotoreSpec) -> int:
    front = 3  # 表題・遊び方（2ページ）
    back = 2  # 30日の記録・奥付
    total = front + 2 * len(spec.days) + -(-len(spec.days) // 2) + back
    return total + (total % 2)


# --- 部品 ---------------------------------------------------------------------


def _section_title(c: canvas.Canvas, x: float, y: float, no: str, name: str, note: str, color: CMYK) -> None:
    c.setFillColorCMYK(*color)
    c.circle(x + 12, y + 7, 12, stroke=0, fill=1)
    c.setFillColorCMYK(*WHITE)
    c.setFont(FONT_BOLD, 14)
    c.drawCentredString(x + 12, y + 2, no)
    c.setFillColorCMYK(*color)
    c.setFont(FONT_ROUNDED, 20)
    c.drawString(x + 32, y, name)
    c.setFillColorCMYK(*BLACK)
    c.setFont(FONT_REGULAR, 13)
    c.drawString(x + 36 + c.stringWidth(name, FONT_ROUNDED, 20), y + 2, note)


def draw_arithmetic(c: canvas.Canvas, rec: dict, *, x: float, top: float, w: float, answers: bool = False,
                    fs: float = 24, cols: int = 2) -> float:
    probs = rec["board"]["problems"]
    rows = -(-len(probs) // cols)
    col_w = w / cols
    row_h = fs * 2.0
    for k, p in enumerate(probs):
        col, row = k // rows, k % rows
        lx = x + col * col_w
        yy = top - (row + 1) * row_h + fs * 0.5
        c.setFillColorCMYK(*BLACK)
        c.setFont(FONT_REGULAR, fs * 0.55)
        c.drawString(lx, yy + fs * 0.1, f"({k + 1})")
        c.setFont(FONT_BOLD, fs)
        expr = f"{p['a']} {p['op'].replace('+', '＋').replace('-', '－')} {p['b']} ＝"
        c.drawString(lx + fs * 1.3, yy, expr)
        bx = lx + fs * 1.3 + c.stringWidth(expr, FONT_BOLD, fs) + 8
        c.setStrokeColorCMYK(0, 0, 0, 0.5)
        c.setLineWidth(1.2)
        c.roundRect(bx, yy - fs * 0.3, fs * 2.6, fs * 1.35, 4, stroke=1, fill=0)
        if answers:
            c.setFillColorCMYK(0.9, 0.55, 0, 0.1)
            c.drawCentredString(bx + fs * 1.3, yy, str(rec["solution"]["answers"][k]))
    return rows * row_h


def draw_number_search(c: canvas.Canvas, rec: dict, *, x: float, top: float, w: float, pal: Palette,
                       d: str) -> float:
    size = rec["board"]["size"]
    cell = w / size
    c.setFillColorCMYK(*pal.tint[d])
    c.rect(x, top - w, w, w, stroke=0, fill=1)
    c.setStrokeColorCMYK(*pal.line)
    c.setLineWidth(max(kdp_spec.MIN_LINE_PT, cell * 0.03))
    for i in range(1, size):
        c.line(x + i * cell, top, x + i * cell, top - w)
        c.line(x, top - i * cell, x + w, top - i * cell)
    c.setStrokeColorCMYK(*pal.main[d])
    c.setLineWidth(1.6)
    c.rect(x, top - w, w, w, stroke=1, fill=0)
    fs = cell * 0.46
    c.setFillColorCMYK(*BLACK)
    c.setFont(FONT_BOLD, fs)
    for gy, row in enumerate(rec["board"]["grid"]):
        for gx, v in enumerate(row):
            c.drawCentredString(x + (gx + 0.5) * cell, top - (gy + 0.5) * cell - fs * 0.36, str(v))
    return w


def draw_clock(c: canvas.Canvas, h: int, m: int, cx: float, cy: float, r: float, color: CMYK) -> None:
    c.saveState()
    c.setFillColorCMYK(*WHITE)
    c.setStrokeColorCMYK(*color)
    c.setLineWidth(r * 0.06)
    c.circle(cx, cy, r, stroke=1, fill=1)
    c.setStrokeColorCMYK(*BLACK)
    for k in range(60):  # 目盛り
        a = math.radians(90 - k * 6)
        inner = r * (0.84 if k % 5 == 0 else 0.9)
        c.setLineWidth(max(kdp_spec.MIN_LINE_PT, r * (0.03 if k % 5 == 0 else 0.012)))
        c.line(cx + inner * math.cos(a), cy + inner * math.sin(a), cx + r * 0.95 * math.cos(a), cy + r * 0.95 * math.sin(a))
    c.setFillColorCMYK(*BLACK)
    fs = r * 0.2
    c.setFont(FONT_BOLD, fs)
    for n in range(1, 13):
        a = math.radians(90 - n * 30)
        c.drawCentredString(cx + r * 0.7 * math.cos(a), cy + r * 0.7 * math.sin(a) - fs * 0.35, str(n))
    # 針（短針は分に合わせて少し進める）
    ha = math.radians(90 - (h % 12) * 30 - m * 0.5)
    ma = math.radians(90 - m * 6)
    c.setLineCap(1)
    c.setLineWidth(r * 0.08)
    c.line(cx, cy, cx + r * 0.45 * math.cos(ha), cy + r * 0.45 * math.sin(ha))
    c.setLineWidth(r * 0.045)
    c.line(cx, cy, cx + r * 0.72 * math.cos(ma), cy + r * 0.72 * math.sin(ma))
    c.setFillColorCMYK(*color)
    c.circle(cx, cy, r * 0.06, stroke=0, fill=1)
    c.restoreState()


def draw_pair_search(c: canvas.Canvas, rec: dict, *, x: float, top: float, w: float, h: float, pal: Palette,
                     d: str, answers: bool = False) -> tuple[float, float]:
    rows, cols = rec["board"]["rows"], rec["board"]["cols"]
    cell = min(w / cols, h / rows)
    gw, gh = cell * cols, cell * rows
    ox = x + (w - gw) / 2
    c.setFillColorCMYK(*pal.tint[d])
    c.roundRect(ox - 6, top - gh - 6, gw + 12, gh + 12, 10, stroke=0, fill=1)
    pair = {tuple(p) for p in rec["solution"]["pair"]}
    for gy, row in enumerate(rec["board"]["grid"]):
        for gx, code in enumerate(row):
            px, py = ox + gx * cell, top - (gy + 1) * cell
            if answers and (gx, gy) in pair:
                c.setStrokeColorCMYK(0, 0.85, 0.75, 0)
                c.setLineWidth(max(1.5, cell * 0.07))
                c.circle(px + cell / 2, py + cell / 2, cell * 0.48, stroke=1, fill=0)
            draw_icon(c, code, px + cell * 0.14, py + cell * 0.14, cell * 0.72)
    return gw, gh


# --- ページ -------------------------------------------------------------------


def draw_day_left(c: canvas.Canvas, day: dict, *, left: float, right: float, top: float, bottom: float,
                  pal: Palette) -> None:
    d = day["difficulty"]
    w = right - left
    band = _header_band(c, left, right, top, pal.main[d], f"{day['day']}日目",
                        f"{DIFFICULTY_STARS[d]} {DIFFICULTY_LABEL_JA[d]}　　　月　　日")
    y = band - 40
    _section_title(c, left, y, "1", "計算", "答えを□に書きましょう", pal.main[d])
    used = draw_arithmetic(c, day["arithmetic"], x=left + 10, top=y - 14, w=w - 10)
    y = y - 14 - used - 36
    _section_title(c, left, y, "2", "数字さがし", "1から順に、数字を指でたどりましょう", pal.main[d])
    size = min(w, y - 14 - (bottom + 40))
    gx = left + (w - size) / 2
    draw_number_search(c, day["number"], x=gx, top=y - 14, w=size, pal=pal, d=d)
    c.setFillColorCMYK(*BLACK)
    c.setFont(FONT_REGULAR, 12)
    c.drawRightString(right, bottom + 6, "かかった時間　　　分　　　秒")


def draw_day_right(c: canvas.Canvas, day: dict, *, left: float, right: float, top: float, bottom: float,
                   pal: Palette) -> None:
    d = day["difficulty"]
    w = right - left
    r = day["right"]
    band = _header_band(c, left, right, top, pal.main[d], f"{day['day']}日目（つづき）",
                        f"{DIFFICULTY_STARS[d]} {DIFFICULTY_LABEL_JA[d]}")
    y = band - 40
    clock_h = 210
    talk_h = 50
    avail = y - 14 - (bottom + 30 + talk_h + clock_h + 40)
    if r["type"] == "wordsearch":
        dirs = "よこ・たて" + ("・ななめ" if "SE" in r["params"]["directions"] else "")
        _section_title(c, left, y, "3", "ことば探し", f"テーマ「{r['board']['theme']}」（{dirs}）", pal.main[d])
        if day.get("icon"):
            draw_icon(c, day["icon"], right - 30, y - 6, 28)
        labels = [wd["label"] for wd in r["board"]["words"]]
        list_h = 3 * 19 * 1.75
        gsize = min(w * 0.62, avail - list_h - 10)
        gx = left + (w - gsize) / 2
        gh = draw_grid(c, r, x=gx, y=y - 14, w=gsize, show_answer=False, palette=pal)
        ly = y - 14 - gh - 28
        col_w = w / 2
        c.setLineWidth(1.4)
        for k, label in enumerate(labels):
            col, row = k % 2, k // 2
            lx = left + 20 + col * col_w
            yy = ly - row * 19 * 1.75
            c.setStrokeColorCMYK(*pal.main[d])
            c.setFillColorCMYK(*WHITE)
            c.roundRect(lx, yy - 2, 15, 15, 2, stroke=1, fill=1)
            c.setFillColorCMYK(*BLACK)
            _draw_label(c, label, lx + 23, yy, col_w - 40, 19)
    else:
        _section_title(c, left, y, "3", "同じ絵さがし", "同じ絵が2つあります。丸でかこみましょう", pal.main[d])
        draw_pair_search(c, r, x=left, top=y - 20, w=w, h=avail - 10, pal=pal, d=d)
    # 時計
    cy_top = bottom + 30 + talk_h + clock_h
    _section_title(c, left, cy_top, "4", "時計", "何時何分でしょう", pal.main[d])
    times = day["clock"]["board"]["times"]
    rr = 58
    for k, (hh, mm) in enumerate(times):
        cx = left + w * (k + 0.5) / len(times)
        draw_clock(c, hh, mm, cx, cy_top - 30 - rr, rr, pal.main[d])
        c.setFillColorCMYK(*BLACK)
        c.setFont(FONT_REGULAR, 15)
        c.drawCentredString(cx, cy_top - 30 - 2 * rr - 26, "（　　）時（　　）分")
    # 思い出トーク
    if day.get("talk"):
        ty = bottom + 30 + talk_h - 6
        c.setFillColorCMYK(*(pal.tint[d] if pal is COLOR else (0, 0, 0, 0.06)))
        c.roundRect(left, ty - 36, w, 38, 10, stroke=0, fill=1)
        draw_icon(c, "1f4ac", left + 10, ty - 29, 24)
        c.setFillColorCMYK(*pal.main[d])
        c.setFont(FONT_ROUNDED, 14)
        c.drawString(left + 42, ty - 22, "思い出トーク")
        c.setFillColorCMYK(*BLACK)
        room = w - 142 - 12
        c.setFont(FONT_REGULAR, min(15, 15 * room / c.stringWidth(day["talk"], FONT_REGULAR, 15)))
        c.drawString(left + 142, ty - 23, day["talk"])
    c.setFillColorCMYK(*BLACK)
    c.setFont(FONT_REGULAR, 12)
    c.drawRightString(right - 62, bottom + 6, "できた日　　月　　日")
    c.setStrokeColorCMYK(*pal.main[d])
    c.setLineWidth(1.2)
    c.setDash(3, 3)
    c.circle(right - 24, bottom + 14, 22, stroke=1, fill=0)
    c.setDash()
    c.setFillColorCMYK(*pal.main[d])
    c.setFont(FONT_REGULAR, 7)
    c.drawCentredString(right - 24, bottom + 11, "はなまる")


def draw_answers_block(c: canvas.Canvas, day: dict, *, left: float, right: float, top: float, height: float,
                       pal: Palette) -> None:
    """答えのページの1日分（上下2段の1段）。"""
    d = day["difficulty"]
    w = right - left
    c.setFillColorCMYK(*pal.main[d])
    c.setFont(FONT_ROUNDED, 16)
    c.drawString(left, top - 16, f"{day['day']}日目")
    # 計算の答え
    c.setFillColorCMYK(*BLACK)
    c.setFont(FONT_BOLD, 12)
    c.drawString(left, top - 40, "1 計算")
    ans = day["arithmetic"]["solution"]["answers"]
    c.setFont(FONT_REGULAR, 13)
    for k, a in enumerate(ans):
        col, row = k // 5, k % 5
        c.drawString(left + 8 + col * 90, top - 62 - row * 20, f"({k + 1}) {a}")
    # 時計の答え
    c.setFont(FONT_BOLD, 12)
    c.drawString(left, top - 175, "4 時計")
    c.setFont(FONT_REGULAR, 13)
    for k, a in enumerate(day["clock"]["solution"]["answers"]):
        c.drawString(left + 8, top - 197 - k * 20, f"({k + 1}) {a}")
    # 右のパズルの答え
    r = day["right"]
    rx = left + 200
    rw = w - 200
    c.setFont(FONT_BOLD, 12)
    c.setFillColorCMYK(*BLACK)
    c.drawString(rx, top - 40, "3 " + ("ことば探し" if r["type"] == "wordsearch" else "同じ絵さがし"))
    size = min(rw, height - 70)
    if r["type"] == "wordsearch":
        draw_grid(c, r, x=rx + (rw - size) / 2, y=top - 52, w=size, show_answer=True, palette=pal, bold=True)
    else:
        draw_pair_search(c, r, x=rx, top=top - 56, w=rw, h=size - 8, pal=pal, d=d, answers=True)
    # 数字さがしの答えは無い（たどれたら正解）ことを、左の列の時計の答えの下に書く
    c.setFont(FONT_BOLD, 12)
    c.setFillColorCMYK(*BLACK)
    c.drawString(left, top - 275, "2 数字さがし")
    c.setFont(FONT_REGULAR, 12)
    c.drawString(left + 8, top - 295, "1から順にたどれたら正解")


def _page_preview(spec: NotoreSpec, day: dict, side: str, width_pt: float, dpi: int = 300) -> ImageReader:
    """見本ページを CMYK の画像に（表紙の文字は 7pt 以上という KDP の決まりのため）。"""
    import pypdfium2

    trim = kdp_spec.TRIMS[spec.trim]
    pw, ph = trim.width_in * inch, trim.height_in * inch
    buf = io.BytesIO()
    pc = canvas.Canvas(buf, pagesize=(pw, ph), initialFontName=FONT_REGULAR)
    m = 0.6 * inch
    fn = draw_day_left if side == "L" else draw_day_right
    fn(pc, day, left=m, right=pw - m, top=ph - m, bottom=m, pal=spec.palette)
    pc.save()
    img = pypdfium2.PdfDocument(buf.getvalue())[0].render(scale=dpi / 72 * (width_pt / pw)).to_pil().convert("CMYK")
    out = io.BytesIO()
    img.save(out, "JPEG", quality=95)
    out.seek(0)
    return ImageReader(out)


# --- 本文 ---------------------------------------------------------------------


def build_pdf(days: list[dict], output_path: str, spec: NotoreSpec) -> int:
    trim = kdp_spec.TRIMS[spec.trim]
    total = page_count(spec)
    pal = spec.palette
    c = canvas.Canvas(output_path, pagesize=(trim.width_in * inch, trim.height_in * inch), initialFontName=FONT_REGULAR)
    c.setTitle(spec.title)
    c.setAuthor(spec.publisher)
    c.setCreator(spec.publisher)
    pg = _Pager(c, trim, total)
    mid = lambda: (pg.left + pg.right) / 2  # noqa: E731
    title_main, _, count = spec.title.rpartition(" ")
    lead, _, main_word = title_main.partition(" ")

    # 1. 表題
    c.setFillColorCMYK(*ORANGE)
    c.setFont(FONT_ROUNDED, 44)
    c.drawCentredString(mid(), pg.page_h * 0.66, lead)
    c.setFillColorCMYK(*pal.accent)
    c.setFont(FONT_ROUNDED, 76)
    c.drawCentredString(mid(), pg.page_h * 0.66 - 92, main_word)
    c.setFont(FONT_ROUNDED, 34)
    c.drawCentredString(mid(), pg.page_h * 0.66 - 140, count)
    c.setFont(FONT_BOLD, 16)
    c.drawCentredString(mid(), pg.page_h * 0.66 - 180, spec.subtitle)
    row = ["1f338", "1f33b", "1f341", "26c4", "1f361"]
    for k, code in enumerate(row):
        draw_icon(c, code, mid() - 165 + k * 66, pg.page_h * 0.66 - 260, 46)
    c.setFillColorCMYK(*BLACK)
    c.setFont(FONT_REGULAR, 14)
    c.drawCentredString(mid(), pg.page_h * 0.18, spec.publisher)
    pg.next(folio=False)

    # 2〜3. 遊び方（5種類）
    howto = [
        ("1", "計算", "たし算・ひき算（むずかしい日は、かけ算も）の答えを□に書きます。"),
        ("2", "数字さがし", "ます目の中から、1、2、3…と順番に数字をさがし、指でたどります。\n時間をはかって、日ごとの記録をくらべるのも楽しみです。"),
        ("3", "ことば探し", "ます目の中から、下にならんだ言葉をさがして丸でかこみます。\n言葉は「よこ（左から右）」と「たて（上から下）」にならびます。\nむずかしい日は「ななめ（左上から右下）」も加わります。\n逆向きにはならびません。"),
        ("3", "同じ絵さがし", "絵がたくさんならんでいます。その中に、同じ絵が2つだけあります。\nさがして、2つとも丸でかこみます（ことば探しと1日おきです）。"),
        ("4", "時計", "時計の針を読んで、何時何分かを書きます。\nやさしい日は30分ごと、ふつうは15分ごと、\nむずかしい日は5分ごとです。"),
    ]
    for page_no, page_items in enumerate((howto[:3], howto[3:])):
        top = pg.page_h - pg.top
        c.setFillColorCMYK(*pal.accent)
        c.setFont(FONT_BOLD, 28)
        c.drawString(pg.left, top - 30, "遊び方" if page_no == 0 else "遊び方（つづき）")
        c.setStrokeColorCMYK(*pal.accent)
        c.setLineWidth(2)
        c.line(pg.left, top - 42, pg.right, top - 42)
        y = top - 90
        for no, name, text in page_items:
            _section_title(c, pg.left, y, no, name, "", pal.main["easy"])
            y -= 34
            c.setFillColorCMYK(*BLACK)
            c.setFont(FONT_REGULAR, 16)
            for line in text.split("\n"):
                c.drawString(pg.left + 20, y, line)
                y -= 26
            y -= 26
        if page_no == 1:
            c.setFont(FONT_REGULAR, 16)
            for line in [
                "1日2ページずつ、30日分あります。",
                "10日ごとに、やさしい → ふつう → むずかしい と進みます。",
                "右のページの下の「思い出トーク」は、",
                "解いたあとの会話のきっかけにどうぞ。",
                "答えは本のうしろにまとめてあります。",
            ]:
                c.drawString(pg.left, y, line)
                y -= 28
        pg.next()

    # 4. 30日分
    for day in days:
        m = dict(left=pg.left, right=pg.right, top=pg.page_h - pg.top, bottom=pg.bottom, pal=pal)
        draw_day_left(c, day, **m)
        pg.next()
        m = dict(left=pg.left, right=pg.right, top=pg.page_h - pg.top, bottom=pg.bottom, pal=pal)
        draw_day_right(c, day, **m)
        pg.next()

    # 5. 答え（1ページに2日分）
    for i in range(0, len(days), 2):
        top = pg.page_h - pg.top
        band = _header_band(c, pg.left, pg.right, top, pal.accent, "答え", f"{i + 1}日目〜{min(i + 2, len(days))}日目")
        half = (band - 10 - pg.bottom) / 2
        for k, day in enumerate(days[i:i + 2]):
            draw_answers_block(c, day, left=pg.left, right=pg.right, top=band - 10 - k * half, height=half - 10, pal=pal)
        pg.next()

    # 6. 30日の記録
    top = pg.page_h - pg.top
    c.setFillColorCMYK(*pal.accent)
    c.setFont(FONT_ROUNDED, 26)
    c.drawString(pg.left, top - 30, "30日の記録")
    c.setStrokeColorCMYK(*pal.accent)
    c.setLineWidth(2)
    c.line(pg.left, top - 42, pg.right, top - 42)
    c.setFillColorCMYK(*BLACK)
    c.setFont(FONT_REGULAR, 12)
    c.drawString(pg.left, top - 64, "できた日と、数字さがしにかかった時間を書きましょう。")
    per_col, col_w = 15, (pg.right - pg.left) / 2
    row_h = (top - 96 - pg.bottom - 10) / per_col
    for k, day in enumerate(days):
        col, row = k // per_col, k % per_col
        x0 = pg.left + col * col_w
        yy = top - 100 - row * row_h
        d = day["difficulty"]
        c.setFillColorCMYK(*(pal.tint[d] if spec.ink == "premium" else (0, 0, 0, 0.06)))
        c.roundRect(x0 + 2, yy - 8, col_w - 8, row_h - 6, 4, stroke=0, fill=1)
        c.setFillColorCMYK(*pal.main[d])
        c.setFont(FONT_BOLD, 13)
        c.drawString(x0 + 10, yy, f"{day['day']}日目")
        c.setFillColorCMYK(*BLACK)
        c.setFont(FONT_REGULAR, 12)
        c.drawString(x0 + 70, yy, "月　　日")
        c.drawRightString(x0 + col_w - 16, yy, "数字さがし　　分　　秒")
    pg.next()

    # 7. 奥付
    while pg.number < total:
        pg.next(folio=False)
    if spec.copy_ok:
        box_top = pg.bottom + 330
        box_h = 22 + 17 * len(COPY_PERMISSION)
        c.setStrokeColorCMYK(*pal.accent)
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


def build_cover(spec: NotoreSpec, days: list[dict], output_path: str, *, paper: str = "white") -> tuple[float, float]:
    pages = page_count(spec)
    trim = kdp_spec.TRIMS[spec.trim]
    spine = kdp_spec.spine_width_in(pages, paper, spec.ink)
    bleed = kdp_spec.COVER_BLEED_IN
    total_w, total_h = bleed * 2 + trim.width_in * 2 + spine, bleed * 2 + trim.height_in
    W, H = total_w * inch, total_h * inch
    tw, th, sp, b = trim.width_in * inch, trim.height_in * inch, spine * inch, bleed * inch
    safe = kdp_spec.COVER_SAFE_IN * inch
    warm: CMYK = (0.0, 0.03, 0.14, 0.0)
    shadow: CMYK = (0.0, 0.10, 0.25, 0.12)
    green: CMYK = (0.70, 0.0, 0.80, 0.10)
    blue: CMYK = (0.90, 0.55, 0.0, 0.10)
    red: CMYK = (0.0, 0.85, 0.75, 0.0)
    pink: CMYK = (0.0, 0.55, 0.0, 0.0)

    c = canvas.Canvas(output_path, pagesize=(W, H), initialFontName=FONT_REGULAR)
    c.setTitle(f"{spec.title}（表紙）")
    c.setAuthor(spec.publisher)
    c.setFillColorCMYK(*warm)
    c.rect(0, 0, W, H, stroke=0, fill=1)
    spine_x0, fx = b + tw, b + tw + sp
    cx, top = fx + tw / 2, b + th
    c.setFillColorCMYK(*green)
    c.rect(spine_x0, 0, sp, H, stroke=0, fill=1)

    title_main, _, count = spec.title.rpartition(" ")
    lead, _, main_word = title_main.partition(" ")
    # 表表紙
    c.setFillColorCMYK(0.12, 0.0, 0.18, 0.0)
    c.circle(fx + tw * 0.9, top - th * 0.07, tw * 0.28, stroke=0, fill=1)
    c.circle(fx + tw * 0.08, b + th * 0.32, tw * 0.22, stroke=0, fill=1)
    c.setFillColorCMYK(*NAVY)
    c.setFont(FONT_BOLD, 20)
    cap = "1日2ページ、毎日の頭の体操"
    c.drawCentredString(cx, top - 0.8 * inch, cap)
    white = CMYKColor(0, 0, 0, 0)
    outlined_text(c, lead, cx, top - 1.85 * inch, font=FONT_ROUNDED, size=60, fill=CMYKColor(*ORANGE), outline=white, outline_width=10)
    outlined_text(c, main_word, cx, top - 3.25 * inch, font=FONT_ROUNDED, size=min(104, (tw - 2 * safe - 30) / len(main_word)),
                  fill=CMYKColor(*green), outline=white, outline_width=14)
    rib_w, rib_h, rib_y = tw * 0.84, 40, top - 4.0 * inch
    c.setFillColorCMYK(*ORANGE)
    c.roundRect(cx - rib_w / 2, rib_y, rib_w, rib_h, rib_h / 2, stroke=0, fill=1)
    c.setFillColorCMYK(*WHITE)
    c.setFont(FONT_BOLD, 18)
    c.drawCentredString(cx, rib_y + 13, spec.subtitle)

    # 見本: 左に計算のカード、右に時計、下に数字さがし（少しずつ重ねる）
    ccy = top - 6.55 * inch
    card_w, card_h = 3.2 * inch, 2.45 * inch
    c.saveState()
    c.translate(fx + tw * 0.34, ccy + 0.35 * inch)
    c.rotate(3)
    c.setFillColorCMYK(*shadow)
    c.roundRect(-card_w / 2 + 6, -card_h / 2 - 8, card_w, card_h, 14, stroke=0, fill=1)
    c.setFillColorCMYK(*WHITE)
    c.roundRect(-card_w / 2, -card_h / 2, card_w, card_h, 14, stroke=0, fill=1)
    sample = build_arithmetic("medium", spec.seed_start + 9_000_001, count=3)
    draw_arithmetic(c, sample, x=-card_w / 2 + 16, top=card_h / 2 - 10, w=card_w - 32, fs=26, cols=1)
    c.restoreState()
    draw_clock(c, 10, 15, fx + tw * 0.72, ccy + 0.55 * inch, 1.05 * inch, blue)
    ns = build_number_search(4, spec.seed_start + 9_000_002)
    nsw = 2.2 * inch
    c.saveState()
    c.translate(fx + tw * 0.62, ccy - 1.35 * inch)
    c.rotate(-4)
    c.setFillColorCMYK(*shadow)
    c.roundRect(-nsw / 2 - 12 + 6, -nsw / 2 - 12 - 8, nsw + 24, nsw + 24, 12, stroke=0, fill=1)
    c.setFillColorCMYK(*WHITE)
    c.roundRect(-nsw / 2 - 12, -nsw / 2 - 12, nsw + 24, nsw + 24, 12, stroke=0, fill=1)
    draw_number_search(c, ns, x=-nsw / 2, top=nsw / 2, w=nsw, pal=COLOR, d="easy")
    c.restoreState()
    ico = 0.9 * inch
    draw_icon(c, "1f338", fx + safe + 28, top - 1.95 * inch, ico * 0.9, rotate=-12)
    draw_icon(c, "1f341", fx + tw - safe - ico * 0.9 - 28, top - 1.95 * inch, ico * 0.9, rotate=15)
    draw_icon(c, "1f361", fx + safe + 6, ccy - 1.6 * inch, ico)
    draw_icon(c, "1f375", fx + tw * 0.30, ccy - 1.75 * inch, ico * 0.9)

    seals = [(red, ["30日分"]), (pink, ["思い出", "トーク"]), (green, ["5種類の", "パズル"]),
             (ORANGE, ["オール", "カラー"]), (blue, ["答え", "つき"])]
    r = 0.50 * inch
    gap = (tw - 2 * safe - 2 * r * len(seals)) / (len(seals) + 1)
    for k, (col, lines) in enumerate(seals):
        _seal(c, fx + safe + gap * (k + 1) + r * (2 * k + 1), b + 1.45 * inch, r, col, lines)
    c.setFillColorCMYK(*NAVY)
    c.setFont(FONT_BOLD, 16)
    c.drawCentredString(cx, b + 0.5 * inch, spec.publisher)

    # 裏表紙
    bx0 = b + safe + 24
    c.setFillColorCMYK(*NAVY)
    c.setFont(FONT_ROUNDED, 30)
    c.drawString(bx0, top - safe - 50, title_main)
    c.setFont(FONT_BOLD, 15)
    c.drawString(bx0, top - safe - 80, f"{count}　{spec.subtitle}")
    lines = [
        "A4の大きな紙面に、1日2ページずつ30日分。",
        "計算・数字さがし・ことば探し・同じ絵さがし・時計の5種類を、毎日少しずつ。",
        "10日ごとに、やさしい → ふつう → むずかしい と進みます。",
        "毎日の「思い出トーク」で、解いたあとは会話に花を。",
    ]
    c.setFont(FONT_REGULAR, 13)
    y = top - safe - 120
    for line in lines:
        c.drawString(bx0, y, line)
        y -= 24
    scale = 0.36
    mini_w, mini_h = tw * scale, th * scale
    mgap = 22
    mx0 = b + (tw - 2 * mini_w - mgap) / 2
    my0 = y - 20 - mini_h
    for k, side in enumerate(("L", "R")):
        px = mx0 + k * (mini_w + mgap)
        c.setFillColorCMYK(*shadow)
        c.rect(px + 5, my0 - 5, mini_w, mini_h, stroke=0, fill=1)
        c.drawImage(_page_preview(spec, days[10], side, mini_w), px, my0, mini_w, mini_h)
    yy = my0 - 34
    c.setFont(FONT_BOLD, 14)
    for d, label in (("easy", "1〜10日目"), ("medium", "11〜20日目"), ("hard", "21〜30日目")):
        c.setFillColorCMYK(*spec.palette.main[d])
        c.drawString(bx0, yy, f"{DIFFICULTY_STARS[d]} {DIFFICULTY_LABEL_JA[d]}　{label}")
        yy -= 22
    if spec.copy_ok:
        tx0 = b + tw / 2 + 10
        tw0 = (b + tw - safe - 14) - tx0
        ttop = my0 - 22
        c.setFillColorCMYK(*ORANGE)
        c.roundRect(tx0, ttop - 30, tw0, 30, 15, stroke=0, fill=1)
        c.setFillColorCMYK(*WHITE)
        c.setFont(FONT_ROUNDED, 15)
        c.drawCentredString(tx0 + tw0 / 2, ttop - 20, "施設内のコピーOK")
        c.setFillColorCMYK(*NAVY)
        c.setFont(FONT_REGULAR, 11)
        for k, line in enumerate(["介護施設・デイサービスなどで、", "利用者さまへの配布にお使いいただけます。"]):
            c.drawString(tx0 + 6, ttop - 48 - k * 17, line)
    bw, bh = (v * inch for v in kdp_spec.BARCODE_BOX_IN)
    c.setFillColorCMYK(*WHITE)
    c.rect(spine_x0 - safe - bw, b + safe, bw, bh, stroke=0, fill=1)
    c.save()
    return total_w, total_h


def main() -> None:
    parser = argparse.ArgumentParser(description="あたまの体操の本の本文・表紙PDFを作る")
    parser.add_argument("spec", help="books/notore-*.json")
    args = parser.parse_args()
    spec = NotoreSpec.load(args.spec)
    stem = Path(args.spec).stem
    Path("output").mkdir(exist_ok=True)
    days = generate_days(spec)
    total = build_pdf(days, f"output/{stem}-interior.pdf", spec)
    w, h = build_cover(spec, days, f"output/{stem}-cover.pdf")
    print(f"{len(days)}日・{total}ページ（印刷代 {kdp_spec.print_cost_jpy(total, spec.ink)}円）-> output/{stem}-interior.pdf")
    print(f"表紙 {w:.4f} x {h:.4f} in -> output/{stem}-cover.pdf")


if __name__ == "__main__":
    main()
