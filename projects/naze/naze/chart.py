"""計算の回のグラフ・数字・カウンター(PIL)。座標は画素。グラフは Axes が値→画素を受け持つ。"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable, Sequence, Tuple

from PIL import Image, ImageDraw

from . import overlay as ov

GRID = (40, 52, 84)
AXIS = (150, 160, 190)


@dataclass
class Axes:
    x0: int
    y0: int
    x1: int
    y1: int               # 画素の枠(左上 x0,y0 / 右下 x1,y1)
    vx: Tuple[float, float]
    vy: Tuple[float, float]

    def px(self, x: float, y: float) -> Tuple[float, float]:
        fx = (x - self.vx[0]) / (self.vx[1] - self.vx[0])
        fy = (y - self.vy[0]) / (self.vy[1] - self.vy[0])
        return self.x0 + fx * (self.x1 - self.x0), self.y1 - fy * (self.y1 - self.y0)

    def frame(self, dr: ImageDraw.ImageDraw, xt: Iterable[float], yt: Iterable[float], xlab: str = "", ylab: str = "", fmt="{:g}") -> None:
        f = ov.font(30)
        for y in yt:
            _, py = self.px(self.vx[0], y)
            dr.line([(self.x0, py), (self.x1, py)], fill=GRID, width=2)
            s = fmt.format(y)
            dr.text((self.x0 - 14 - f.getlength(s), py - 18), s, font=f, fill=AXIS)
        for x in xt:
            px, _ = self.px(x, self.vy[0])
            s = fmt.format(x)
            dr.text((px - f.getlength(s) / 2, self.y1 + 10), s, font=f, fill=AXIS)
        dr.line([(self.x0, self.y0), (self.x0, self.y1), (self.x1, self.y1)], fill=AXIS, width=3)
        if ylab:
            dr.text((self.x0, self.y0 - 50), ylab, font=ov.font(32), fill=ov.DIM)
        if xlab:
            dr.text(((self.x0 + self.x1) / 2 - ov.font(32).getlength(xlab) / 2, self.y1 + 52), xlab, font=ov.font(32), fill=ov.DIM)

    def curve(self, dr: ImageDraw.ImageDraw, pts: Sequence[Tuple[float, float]], color, width: int = 6, upto: float = 1.0) -> None:
        n = max(2, int(len(pts) * max(0.0, min(1.0, upto))))
        xy = [self.px(x, y) for x, y in pts[:n]]
        if len(xy) >= 2:
            dr.line(xy, fill=color, width=width, joint="curve")

    def band(self, img: Image.Image, y0: float, y1: float, color, alpha: float = 0.35, label: str = "") -> None:
        layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        _, a = self.px(self.vx[0], y1)
        _, b = self.px(self.vx[0], y0)
        d.rectangle([self.x0, a, self.x1, b], fill=tuple(color) + (int(255 * alpha),))
        d.line([(self.x0, a), (self.x1, a)], fill=tuple(color) + (255,), width=3)
        d.line([(self.x0, b), (self.x1, b)], fill=tuple(color) + (255,), width=3)
        img.alpha_composite(layer)
        if label:
            f = ov.font(32)
            ImageDraw.Draw(img).text((self.x1 - f.getlength(label) - 8, a - 44), label, font=f, fill=tuple(color))

    def dot(self, dr: ImageDraw.ImageDraw, x: float, y: float, color, r: int = 12) -> None:
        px, py = self.px(x, y)
        dr.ellipse([px - r, py - r, px + r, py + r], fill=color, outline=(255, 255, 255), width=3)


def counter(dr: ImageDraw.ImageDraw, x: int, y: int, label: str, n: int, total: int, mark: str = "×", size: int = 56) -> None:
    """失敗のカウンター: 「label □□□」の □ を n 個まで × で埋める。"""
    f = ov.font(40)
    dr.text((x, y + 6), label, font=f, fill=ov.DIM)
    bx = x + f.getlength(label) + 20
    for i in range(total):
        x0 = bx + i * (size + 14)
        filled = i < n
        dr.rounded_rectangle([x0, y, x0 + size, y + size], 10, fill=(150, 40, 40) if filled else (30, 40, 70), outline=ov.RED if filled else (70, 80, 120), width=3)
        if filled:
            ff = ov.font(44)
            dr.text((x0 + size / 2 - ff.getlength(mark) / 2, y + 2), mark, font=ff, fill=ov.WHITE)


def big(dr: ImageDraw.ImageDraw, x: float, y: float, text: str, color=ov.YEL, size: int = 110, sub: str = "", sub_color=ov.WHITE) -> None:
    f = ov.font(size)
    dr.text((x - f.getlength(text) / 2, y), text, font=f, fill=color, stroke_width=6, stroke_fill=ov.NAVY)
    if sub:
        g = ov.font(46)
        dr.text((x - g.getlength(sub) / 2, y + size + 14), sub, font=g, fill=sub_color, stroke_width=4, stroke_fill=ov.NAVY)
