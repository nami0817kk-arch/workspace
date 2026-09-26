"""表紙PDF（裏表紙・背・表表紙を1枚）を組む。

寸法の式は KDP の表紙ガイド（topic/G201953020）どおり:
  幅 = 裁ち落とし + 裏表紙 + 背 + 表表紙 + 裁ち落とし
  高さ = 裁ち落とし + 判型の高さ + 裁ち落とし
横書き（左綴じ）の本なので、左が裏表紙・右が表表紙。

色は CMYK で指定する（表紙の画像は CMYK が必須。ベクターの塗りもそろえておく）。
表紙の絵は生成AIを使わず、本文と同じ生成器の迷路を描いている。
KDP の「AI 生成コンテンツ」の申告対象にならないようにするため。
"""

from __future__ import annotations

import argparse
from pathlib import Path

from puzzle_generator import build_puzzle
from reportlab.lib.units import inch
from reportlab.pdfgen import canvas

import kdp_spec
from build_book import (
    DIFFICULTY_LABEL_JA,
    DIFFICULTY_STARS,
    FONT_BOLD,
    FONT_REGULAR,
    BookSpec,
    _draw_arrow_label,
    draw_maze,
    page_count,
)

NAVY = (0.95, 0.72, 0.0, 0.35)
CREAM = (0.0, 0.03, 0.12, 0.0)
ORANGE = (0.0, 0.62, 0.92, 0.0)
WHITE = (0.0, 0.0, 0.0, 0.0)

# 表紙の飾りに使う迷路。本文の問題と seed が重ならない帯から取る。
_COVER_SEED = 9_000_000


def cover_size_in(spec: BookSpec, pages: int, paper: str = "white") -> tuple[float, float, float]:
    """(全体の幅, 全体の高さ, 背幅) をインチで返す。"""
    trim = kdp_spec.TRIMS[spec.trim]
    spine = kdp_spec.spine_width_in(pages, paper)
    bleed = kdp_spec.COVER_BLEED_IN
    return bleed * 2 + trim.width_in * 2 + spine, bleed * 2 + trim.height_in, spine


def build_cover(spec: BookSpec, output_path: str, *, paper: str = "white", blurb: list[str]) -> tuple[float, float]:
    pages = page_count(spec)
    total_w, total_h, spine = cover_size_in(spec, pages, paper)
    trim = kdp_spec.TRIMS[spec.trim]
    bleed = kdp_spec.COVER_BLEED_IN * inch
    safe = kdp_spec.COVER_SAFE_IN * inch
    W, H = total_w * inch, total_h * inch
    tw, th = trim.width_in * inch, trim.height_in * inch
    sp = spine * inch

    c = canvas.Canvas(output_path, pagesize=(W, H))
    c.setTitle(f"{spec.title}（表紙）")
    c.setAuthor(spec.publisher)

    # 地の色は裁ち落としまで塗る
    c.setFillColorCMYK(*CREAM)
    c.rect(0, 0, W, H, stroke=0, fill=1)

    back_x0 = bleed
    spine_x0 = bleed + tw
    front_x0 = bleed + tw + sp
    trim_y0 = bleed

    # --- 背 ---
    c.setFillColorCMYK(*NAVY)
    c.rect(spine_x0, 0, sp, H, stroke=0, fill=1)
    # 背の文字は 80 ページ以上でのみ可。左右 1/16 in の余白を引いた幅に、
    # 9pt 以上の文字が入らないときも入れない（KDP の最小は 7pt。読めない大きさで入れても意味が無い）。
    usable = sp - 2 * kdp_spec.SPINE_TEXT_SIDE_MARGIN_IN * inch
    spine_font = min(usable * 0.8, 14)
    if pages >= kdp_spec.SPINE_TEXT_MIN_PAGES and spine_font >= 9:
        c.saveState()
        c.setFillColorCMYK(*WHITE)
        c.translate(spine_x0 + sp / 2, trim_y0 + th / 2)
        c.rotate(-90)
        c.setFont(FONT_BOLD, spine_font)
        c.drawCentredString(0, -spine_font / 3, f"{spec.title}　{spec.publisher}")
        c.restoreState()

    # --- 表表紙 ---
    band_h = th * 0.30
    c.setFillColorCMYK(*NAVY)
    c.rect(front_x0, trim_y0 + th - band_h, tw + bleed, band_h + bleed, stroke=0, fill=1)
    cx = front_x0 + tw / 2
    c.setFillColorCMYK(*WHITE)
    c.setFont(FONT_BOLD, 58)
    title_main, _, title_count = spec.title.rpartition(" ")
    c.drawCentredString(cx, trim_y0 + th - band_h * 0.48, title_main or spec.title)
    c.setFont(FONT_REGULAR, 20)
    c.drawCentredString(cx, trim_y0 + th - band_h * 0.80, spec.subtitle)

    # 問題数のバッジ
    if title_count:
        bx, by, r = front_x0 + tw - safe - 58, trim_y0 + th - band_h - 20, 54
        c.setFillColorCMYK(*ORANGE)
        c.circle(bx, by, r, stroke=0, fill=1)
        c.setFillColorCMYK(*WHITE)
        c.setFont(FONT_BOLD, 34)
        c.drawCentredString(bx, by - 12, title_count)

    # 見本の迷路（白い台の上に）
    panel_w = tw - 2 * safe - 60
    panel_h = th - band_h - 2.4 * inch
    px = front_x0 + (tw - panel_w) / 2
    py = trim_y0 + 1.3 * inch
    c.setFillColorCMYK(*WHITE)
    c.roundRect(px, py, panel_w, panel_h, 14, stroke=0, fill=1)
    sample = build_puzzle("easy", seed=_COVER_SEED)
    pad = 48
    draw_maze(c, sample, x=px + pad, y=py + pad, w=panel_w - 2 * pad, h=panel_h - 2 * pad,
              show_solution=False, line_width=3)
    _draw_arrow_label(c, sample, x=px + pad, y=py + pad, w=panel_w - 2 * pad, h=panel_h - 2 * pad,
                      font_size=15)

    c.setFillColorCMYK(*NAVY)
    c.setFont(FONT_BOLD, 18)
    c.drawCentredString(cx, trim_y0 + 0.62 * inch, spec.publisher)

    # --- 裏表紙 ---
    c.setFillColorCMYK(*NAVY)
    c.setFont(FONT_BOLD, 20)
    y = trim_y0 + th - safe - 60
    c.drawString(back_x0 + safe + 20, y, spec.title)
    c.setFont(FONT_REGULAR, 14)
    y -= 44
    for line in blurb:
        c.drawString(back_x0 + safe + 20, y, line)
        y -= 28

    # バーコードの白い箱（Amazon がここに ISBN のバーコードを置く）。
    # 何も描かず白で空けておく。位置は裏表紙の右下、背と下端から 0.25 in 以上離す。
    bw, bh = (v * inch for v in kdp_spec.BARCODE_BOX_IN)
    c.setFillColorCMYK(*WHITE)
    c.rect(spine_x0 - safe - bw, trim_y0 + safe, bw, bh, stroke=0, fill=1)

    c.save()
    return total_w, total_h


def main() -> None:
    parser = argparse.ArgumentParser(description="迷路パズル本の表紙PDFを作る")
    parser.add_argument("spec", help="本の設計書（books/*.json）")
    parser.add_argument("--paper", choices=["white", "cream"], default="white")
    parser.add_argument("--out", default=None)
    args = parser.parse_args()

    spec = BookSpec.load(args.spec)
    out = Path(args.out or f"output/{Path(args.spec).stem}-cover.pdf")
    out.parent.mkdir(parents=True, exist_ok=True)
    blurb = spec_blurb(spec)
    w, h = build_cover(spec, str(out), paper=args.paper, blurb=blurb)
    print(f"{w:.4f} x {h:.4f} in ({w * 25.4:.1f} x {h * 25.4:.1f} mm) -> {out}")


def spec_blurb(spec: BookSpec) -> list[str]:
    lines = [
        "A4の大きな紙面に、1ページ1問。",
        "太い線と広い通路で、えんぴつでなぞりやすい迷路です。",
        "",
    ]
    for difficulty, count in spec.sections:
        lines.append(f"{DIFFICULTY_STARS[difficulty]} {DIFFICULTY_LABEL_JA[difficulty]}　{count}問")
    lines += [
        "",
        "どの問題も、ゴールまでの道は1本だけ。",
        "答えは巻末にまとめてあります。",
    ]
    return lines


if __name__ == "__main__":
    main()
