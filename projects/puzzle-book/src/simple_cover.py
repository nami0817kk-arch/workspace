"""図鑑・辞典の表紙（表・背・裏を1枚に）。金属の図鑑と通貨辞典で共通の型。

表: 紺の上半分に副題と題名、中ほどに絵（呼び出し側が描く）、下に一言の帯と発行者。
裏: 題名・副題・紹介文・「こんな人に」・「この本の中身」、右下にバーコード欄（白い四角）。
背: 66〜79ページは KDP で背に文字を入れられないので、色だけ。
"""

from __future__ import annotations

from typing import Callable

from reportlab.lib.colors import CMYKColor
from reportlab.lib.units import inch
from reportlab.pdfgen import canvas

import kdp_spec
from art import FONT_ROUNDED, outlined_text
from build_book import FONT_BOLD, FONT_REGULAR
from build_sekai import GOLD, INK, NAVY, WHITE, wrap_even

COVER_BG = (0.0, 0.04, 0.13, 0.0)


def build_cover(spec, pages: int, output_path: str, draw_visual: Callable, tagline: str,
                blurb: list[str], examples: list[tuple[str, str]], for_whom: list[str], contents: list[str],
                *, paper: str = "white") -> tuple[float, float]:
    trim = kdp_spec.TRIMS[spec.trim]
    spine = kdp_spec.spine_width_in(pages, paper, spec.ink)
    bleed = kdp_spec.COVER_BLEED_IN
    total_w, total_h = bleed * 2 + trim.width_in * 2 + spine, bleed * 2 + trim.height_in
    W, H = total_w * inch, total_h * inch
    tw, th, sp, b = trim.width_in * inch, trim.height_in * inch, spine * inch, bleed * inch
    safe = kdp_spec.COVER_SAFE_IN * inch
    c = canvas.Canvas(output_path, pagesize=(W, H), initialFontName=FONT_REGULAR)
    c.setTitle(f"{spec.title}（表紙）")
    c.setAuthor(spec.publisher)
    c.setFillColorCMYK(*COVER_BG)
    c.rect(0, 0, W, H, stroke=0, fill=1)
    spine_x0, fx = b + tw, b + tw + sp
    cx, top = fx + tw / 2, b + th
    band = top - 2.35 * inch
    c.setFillColorCMYK(*NAVY)
    c.rect(0, band, W, H - band, stroke=0, fill=1)
    # 表
    c.setFillColorCMYK(*GOLD)
    sfs = 12
    while c.stringWidth(spec.subtitle, FONT_BOLD, sfs) > tw - 2 * safe and sfs > 8:
        sfs -= 0.25
    c.setFont(FONT_BOLD, sfs)
    c.drawCentredString(cx, top - 0.62 * inch, spec.subtitle)
    tfs = 40
    while c.stringWidth(spec.title, FONT_ROUNDED, tfs) > tw - 2 * safe - 8 and tfs > 20:
        tfs -= 1
    outlined_text(c, spec.title, cx, top - 1.45 * inch, font=FONT_ROUNDED, size=tfs,
                  fill=CMYKColor(*WHITE), outline=CMYKColor(*NAVY), outline_width=1)
    # 絵（呼び出し側）。帯の下端から一言の帯の上まで
    vis_top = band - 0.18 * inch
    vis_bottom = b + safe + 0.95 * inch
    draw_visual(c, fx + safe, vis_bottom, tw - 2 * safe, vis_top - vis_bottom)
    c.setFillColorCMYK(*NAVY)
    bw = tw - 2 * safe - 16
    bb = b + safe + 0.32 * inch
    c.roundRect(cx - bw / 2, bb, bw, 0.46 * inch, 0.23 * inch, stroke=0, fill=1)
    c.setFillColorCMYK(*WHITE)
    tgs = 15
    while c.stringWidth(tagline, FONT_ROUNDED, tgs) > bw - 20:
        tgs -= 0.5
    c.setFont(FONT_ROUNDED, tgs)
    c.drawCentredString(cx, bb + 0.16 * inch, tagline)
    c.setFillColorCMYK(*NAVY)
    c.setFont(FONT_BOLD, 11)
    c.drawCentredString(cx, b + safe + 4, spec.publisher)
    # 裏
    bx0 = b + safe + 10
    colw = tw - 2 * safe - 20
    c.setFillColorCMYK(*WHITE)
    c.setFont(FONT_ROUNDED, 16)
    c.drawString(bx0, top - safe - 26, spec.title)
    c.setFillColorCMYK(*GOLD)
    c.setFont(FONT_BOLD, 8.5)
    c.drawString(bx0, top - safe - 44, spec.subtitle)
    yy = top - safe - 70
    for left, right in examples:
        c.setFillColorCMYK(*WHITE)
        c.setFont(FONT_BOLD, 10.5)
        c.drawString(bx0, yy, left)
        c.setFillColorCMYK(*GOLD)
        c.drawString(bx0 + c.stringWidth(left, FONT_BOLD, 10.5) + 6, yy, right)
        yy -= 18
    assert yy > band + 6, yy - band
    ly = band - 0.32 * inch
    c.setFillColorCMYK(*INK)
    for para in blurb:
        for ln in wrap_even(c, para, FONT_REGULAR, 9.5, colw, False):
            c.setFont(FONT_REGULAR, 9.5)
            c.drawString(bx0, ly, ln)
            ly -= 15
        ly -= 6
    bw_, bh_ = (v * inch for v in kdp_spec.BARCODE_BOX_IN)
    for head, rows in (("こんな人に", for_whom), ("この本の中身", contents)):
        ly -= 6
        c.setFillColorCMYK(*NAVY)
        c.setFont(FONT_ROUNDED, 12)
        c.drawString(bx0, ly, head)
        ly -= 17
        for row in rows:
            room = colw - 12 if ly > b + safe + bh_ + 10 else colw - bw_ - 24
            parts = wrap_even(c, row, FONT_REGULAR, 9, room, False)
            c.setFillColorCMYK(*GOLD)
            c.circle(bx0 + 3, ly + 3, 2.6, stroke=0, fill=1)
            c.setFillColorCMYK(*INK)
            c.setFont(FONT_REGULAR, 9)
            for part in parts:
                c.drawString(bx0 + 11, ly, part)
                ly -= 13
            ly -= 3
    assert ly > b + safe, ly
    c.setFillColorCMYK(*WHITE)
    c.rect(spine_x0 - safe - bw_, b + safe, bw_, bh_, stroke=0, fill=1)
    c.save()
    return total_w, total_h
