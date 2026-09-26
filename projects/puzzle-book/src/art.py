"""表紙と本文の飾り（絵文字の図版・丸ゴシックの題字）。

図版は Google の Noto Emoji の SVG（`assets/emoji/`、SIL OFL 1.1。README では画像は Apache 2.0）。
生成AIの絵ではないので、KDP の「AI 生成の画像」には当たらない。奥付に出典を書く。
題字の書体は M PLUS Rounded 1c ExtraBold（`assets/fonts/`、SIL OFL 1.1）。

表紙は CMYK が求められるので、SVG から読んだ色は CMYK に置き換えて描く。
"""

from __future__ import annotations

from functools import lru_cache
from pathlib import Path

from reportlab.graphics import renderPDF
from reportlab.graphics.shapes import Drawing, Group
from reportlab.lib.colors import CMYKColor, Color
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas
from svglib.svglib import svg2rlg

_ASSETS = Path(__file__).resolve().parent.parent / "assets"
FONT_ROUNDED = "MPLUSRounded1c-ExtraBold"
pdfmetrics.registerFont(TTFont(FONT_ROUNDED, str(_ASSETS / "fonts" / "MPLUSRounded1c-ExtraBold.ttf")))

ICON_CREDIT = "イラスト: Noto Emoji（Google、SIL Open Font License 1.1）"


def _to_cmyk(color):
    if color is None or isinstance(color, CMYKColor) or not isinstance(color, Color):
        return color
    r, g, b = color.red, color.green, color.blue
    k = 1 - max(r, g, b)
    if k >= 1:
        return CMYKColor(0, 0, 0, 1, alpha=getattr(color, "alpha", 1))
    return CMYKColor((1 - r - k) / (1 - k), (1 - g - k) / (1 - k), (1 - b - k) / (1 - k), k)


def _convert(node) -> None:
    for attr in ("fillColor", "strokeColor"):
        if hasattr(node, attr):
            setattr(node, attr, _to_cmyk(getattr(node, attr)))
    if isinstance(node, (Group, Drawing)):
        for child in node.contents:
            _convert(child)


@lru_cache(maxsize=None)
def _load(code: str) -> Drawing:
    path = _ASSETS / "emoji" / f"emoji_u{code}.svg"
    d = svg2rlg(str(path))
    if d is None:
        raise FileNotFoundError(path)
    _convert(d)
    return d


def draw_icon(c: canvas.Canvas, code: str, x: float, y: float, size: float, *, rotate: float = 0) -> None:
    """(x, y) を左下とする size 四方に絵文字の図版を描く。"""
    d = _load(code)
    s = size / max(d.width, d.height)
    c.saveState()
    c.translate(x + size / 2, y + size / 2)
    if rotate:
        c.rotate(rotate)
    c.translate(-d.width * s / 2, -d.height * s / 2)
    c.scale(s, s)
    renderPDF.draw(d, c, 0, 0)
    c.restoreState()


def outlined_text(
    c: canvas.Canvas,
    text: str,
    x: float,
    y: float,
    *,
    font: str,
    size: float,
    fill,
    outline,
    outline_width: float,
    centred: bool = True,
) -> None:
    """縁取りつきの文字（縁を先に太く描き、その上に塗りを重ねる）。"""
    w = pdfmetrics.stringWidth(text, font, size)
    x0 = x - w / 2 if centred else x
    # 文字の描き方（Tr）は BT/ET をまたいで残るので、縁の段は q/Q で閉じる。
    # 閉じないと塗りの段も縁だけで描かれ、題字が白く抜けた（2026-09-26）
    c.saveState()
    c.setLineJoin(1)
    c.setLineWidth(outline_width)
    t = c.beginText(x0, y)
    t.setFont(font, size)
    t.setStrokeColor(outline)
    t.setTextRenderMode(1)  # 縁だけ
    t.textOut(text)
    c.drawText(t)
    c.restoreState()
    c.saveState()
    t = c.beginText(x0, y)
    t.setFont(font, size)
    t.setFillColor(fill)
    t.setTextRenderMode(0)  # 塗りだけ
    t.textOut(text)
    c.drawText(t)
    c.restoreState()
