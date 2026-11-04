"""選手の動きの絵(Gemini で作った、マゼンタ背景に3人並んだ1枚)から、ポーズごとの PNG を作る。

    python tool/make_sprites.py <元の絵> <kid|adult> <ポーズ名1> <ポーズ名2> <ポーズ名3>

- マゼンタ(#FF00FF)を抜いて透明にし、縁のマゼンタのかぶりを落とす(足元の影もマゼンタ寄りなので一緒に消える)。
- 何も無い縦の列で区切って、左から3人を切り出す。高さ360pxにそろえる。
- 青いユニフォームを色相で替えて7色にする(`assets/art/players/<kid|adult>_<ポーズ>_<色>.png`)。
  色は既存の絵(`adult_<色>.png`)のユニフォームの色相に合わせた。dark はライバル用の黒っぽい色。
- 最後に各ポーズの幅÷高さを出す(`court.dart` の `poseAspect` に写す)。
"""
import colorsys
import sys
from pathlib import Path

from PIL import Image

HUES = {'blue': None, 'yellow': 42, 'red': 356, 'green': 132, 'teal': 184, 'purple': 282, 'dark': 'dark'}
OUT = Path(__file__).resolve().parent.parent / 'assets' / 'art' / 'players'


def key_out(im: Image.Image) -> Image.Image:
    im = im.convert('RGBA')
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, _ = px[x, y]
            m = min(r, b) - g  # マゼンタらしさ
            if m > 90:
                px[x, y] = (0, 0, 0, 0)
            elif m > 40:
                # 縁: 半透明にして、赤と青のかぶりを落とす
                a = int(255 * (90 - m) / 50)
                px[x, y] = (min(r, g + 40), g, min(b, g + 40), a)
    return im


def split3(im: Image.Image):
    w, h = im.size
    alpha = im.getchannel('A')
    cols = [any(alpha.getpixel((x, y)) > 40 for y in range(0, h, 2)) for x in range(w)]
    segs, start = [], None
    for x, c in enumerate(cols + [False]):
        if c and start is None:
            start = x
        elif not c and start is not None:
            if x - start > 8:
                segs.append((start, x))
            start = None
    segs = sorted(sorted(segs, key=lambda s: s[1] - s[0], reverse=True)[:3])
    if len(segs) != 3:
        raise SystemExit(f'3人に分けられない: {segs}')
    out = []
    for a, b in segs:
        part = im.crop((a, 0, b, h))
        out.append(part.crop(part.getbbox()))
    return out


def recolor(im: Image.Image, target):
    if target is None:
        return im
    im = im.copy()
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            H, S, V = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if 0.52 < H < 0.72 and S > 0.3:  # 青いユニフォーム
                if target == 'dark':
                    S, V = S * 0.15, V * 0.42
                else:
                    H = target / 360
                rr, gg, bb = colorsys.hsv_to_rgb(H, S, V)
                px[x, y] = (int(rr * 255), int(gg * 255), int(bb * 255), a)
    return im


def main():
    src, kind, *poses = sys.argv[1:]
    if len(poses) != 3:
        raise SystemExit('ポーズ名を3つ')
    parts = split3(key_out(Image.open(src)))
    for pose, part in zip(poses, parts):
        part = part.resize((round(part.width * 360 / part.height), 360), Image.LANCZOS)
        for name, hue in HUES.items():
            out = recolor(part, hue).quantize(colors=96, method=Image.Quantize.FASTOCTREE)
            out.save(OUT / f'{kind}_{pose}_{name}.png', optimize=True)
        print(f'{kind}_{pose}: aspect {part.width / part.height:.3f}')


if __name__ == '__main__':
    main()
