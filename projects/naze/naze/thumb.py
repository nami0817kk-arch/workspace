"""本編のサムネイル(1280×720)。動画の 1 コマを下地に、大きな問いの字を左に重ねる。

python -m naze.thumb 下地.png out.jpg "1行目" "【強調】の2行目" [--sub "小さな添え書き"]
字は【】で囲んだところが黄色。左 6 割に収め、右は下地の絵を見せる。
下地は字幕の入っていないコマを使う(地形の回なら out/<回>/stills/s_####.png。stills の手順で描いたもの)。
"""
from __future__ import annotations

import argparse

from PIL import Image, ImageDraw

from . import overlay as ov

TW, TH = 1280, 720


def make(base: str, out: str, lines, sub: str = "") -> str:
    img = Image.open(base).convert("RGB")
    s = max(TW / img.width, TH / img.height)
    img = img.resize((round(img.width * s), round(img.height * s)), Image.LANCZOS)
    x0, y0 = (img.width - TW) // 2, (img.height - TH) // 2
    img = img.crop((x0, y0, x0 + TW, y0 + TH)).convert("RGBA")
    # 左から右へ薄れる紺の帯で字を立たせる
    grad = Image.new("L", (TW, 1))
    for x in range(TW):
        grad.putpixel((x, 0), int(230 * max(0.0, 1 - x / (TW * 0.72))))
    shade = Image.new("RGBA", (TW, TH), ov.NAVY + (0,))
    shade.putalpha(grad.resize((TW, TH)))
    img.alpha_composite(shade)
    dr = ImageDraw.Draw(img)
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
    a = ap.parse_args()
    print(make(a.base, a.out, a.lines, a.sub))


if __name__ == "__main__":
    main()
