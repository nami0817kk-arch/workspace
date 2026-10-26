"""本編のサムネイル(1280×720)。動画の 1 コマを下地に、大きな問いの字を左に重ねる。

python -m naze.thumb 下地.png out.jpg "1行目" "【強調】の2行目" [--sub "小さな添え書き"] [--circle x,y,半径]
--circle は見てほしい場所に赤い丸(1280×720 での位置)。型は docs/titles.md。
字は【】で囲んだところが黄色。左 6 割に収め、右は下地の絵を見せる。
下地は字幕の入っていないコマを使う(地形の回なら out/<回>/stills/s_####.png。stills の手順で描いたもの)。
"""
from __future__ import annotations

import argparse

from PIL import Image, ImageDraw

from . import overlay as ov

TW, TH = 1280, 720


def make(base: str, out: str, lines, sub: str = "", circle=None, focus=None, zoom: float = 1.0) -> str:
    """focus=(fx, fy) は下地の中の主役の位置(0〜1)。そこが右寄り(72%, 50%)に来るように切り出す。"""
    img = Image.open(base).convert("RGB")
    s = max(TW / img.width, TH / img.height) * zoom
    img = img.resize((round(img.width * s), round(img.height * s)), Image.LANCZOS)
    x0, y0 = (img.width - TW) // 2, (img.height - TH) // 2
    if focus:
        x0 = int(min(max(0, focus[0] * img.width - TW * 0.72), img.width - TW))
        y0 = int(min(max(0, focus[1] * img.height - TH * 0.5), img.height - TH))
    img = img.crop((x0, y0, x0 + TW, y0 + TH)).convert("RGBA")
    # 左から右へ薄れる紺の帯で字を立たせる
    grad = Image.new("L", (TW, 1))
    for x in range(TW):
        grad.putpixel((x, 0), int(230 * max(0.0, 1 - x / (TW * 0.72))))
    shade = Image.new("RGBA", (TW, TH), ov.NAVY + (0,))
    shade.putalpha(grad.resize((TW, TH)))
    img.alpha_composite(shade)
    dr = ImageDraw.Draw(img)
    if circle:
        cx, cy, r = circle
        dr.ellipse([cx - r - 3, cy - r - 3, cx + r + 3, cy + r + 3], outline=ov.NAVY, width=14)
        dr.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(235, 45, 45), width=9)
    text = "\n".join(lines)
    ov.rows(dr, text, TH * 0.47, 120, maxw=int(TW * 0.58), stroke=10, cx=TW * 0.32)
    if sub:
        ov.rows(dr, sub, TH * 0.88, 40, maxw=int(TW * 0.58), color=ov.DIM, stroke=6, cx=TW * 0.32)
    img.convert("RGB").save(out, quality=92)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("base")
    ap.add_argument("out")
    ap.add_argument("lines", nargs="+")
    ap.add_argument("--sub", default="")
    ap.add_argument("--circle", default="")
    ap.add_argument("--focus", default="", help="主役の位置 fx,fy(下地の 0〜1)。右寄りに来るように切り出す")
    ap.add_argument("--zoom", type=float, default=1.0)
    a = ap.parse_args()
    c = tuple(float(v) for v in a.circle.split(",")) if a.circle else None
    f = tuple(float(v) for v in a.focus.split(",")) if a.focus else None
    print(make(a.base, a.out, a.lines, a.sub, c, f, a.zoom))


if __name__ == "__main__":
    main()
