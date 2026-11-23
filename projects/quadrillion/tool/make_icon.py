"""アプリのアイコン（ドット絵の摩天楼）を描いて、iOS の AppIcon.appiconset を作り直す。

64×64 の点で描き、16倍に拡大して 1024×1024 にする。App Store は透過のある 1024 を弾くので、
すべて RGB（アルファなし）で書き出す。

    python tool/make_icon.py

Pillow を使う。
"""

import json
import os
import random

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ICONSET = os.path.join(HERE, '..', 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')

N = 64  # 点の数（1辺）
SCALE = 1024 // N


def hexc(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def draw():
    px = [[(0, 0, 0)] * N for _ in range(N)]

    def put(x, y, c):
        if 0 <= x < N and 0 <= y < N:
            px[y][x] = c

    def rect(x, y, w, h, c):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                put(xx, yy, c)

    # 昼の青空。上が濃く、地平線に向けて明るくなる。段を付けてドット絵らしくする
    top, bottom = hexc('#2f86e6'), hexc('#bfe6ff')
    bands = 8
    for y in range(N):
        t = min(1.0, y / 50)
        k = int(t * bands) / bands
        c = lerp(top, bottom, k)
        for x in range(N):
            # 段の境目は市松で混ぜる
            k2 = min(1.0, k + 1 / bands)
            if int(t * bands * 2) % 2 == 1 and (x + y) % 2 == 0:
                put(x, y, lerp(top, bottom, k2))
            else:
                put(x, y, c)

    # 太陽（右上）
    sun, sun_hi = hexc('#ffd75e'), hexc('#fff2b0')
    cx, cy, r = 50, 11, 5
    for y in range(cy - r, cy + r + 1):
        for x in range(cx - r, cx + r + 1):
            d = (x - cx) ** 2 + (y - cy) ** 2
            if d <= r * r:
                put(x, y, sun_hi if d <= 6 else sun)

    # 雲
    white, shade = hexc('#ffffff'), hexc('#dcefff')

    def cloud(x, y):
        rect(x + 2, y, 6, 1, white)
        rect(x, y + 1, 11, 2, white)
        rect(x + 1, y + 3, 9, 1, shade)

    cloud(5, 8)
    cloud(37, 19)

    # 遠くのビル（うすい青灰）
    far = hexc('#9fb2cc')
    far_win = hexc('#d7e3f2')
    for x0, w, h in [(0, 6, 22), (7, 5, 28), (24, 5, 25), (40, 6, 30), (57, 7, 24)]:
        y0 = 56 - h
        rect(x0, y0, w, h, far)
        for yy in range(y0 + 2, 54, 3):
            for xx in range(x0 + 1, x0 + w - 1, 2):
                put(xx, yy, far_win)

    # 手前の摩天楼。金色の窓
    gold, gold_hi, gold_dim = hexc('#f2c14e'), hexc('#ffe9a0'), hexc('#b8862a')
    rnd = random.Random(8)

    def tower(x0, w, h, body, edge, crown=None):
        y0 = 56 - h
        rect(x0, y0, w, h, body)
        rect(x0, y0, 1, h, edge)  # 光の当たる左の縁
        rect(x0 + w - 1, y0, 1, h, lerp(body, (0, 0, 0), .25))
        for yy in range(y0 + 2, 55, 3):
            for xx in range(x0 + 2, x0 + w - 2, 2):
                v = rnd.random()
                put(xx, yy, gold_hi if v < .2 else gold if v < .8 else gold_dim)
                put(xx, yy + 1, gold_dim if v < .8 else lerp(body, (0, 0, 0), .2))
        if crown:
            crown(x0, y0, w)

    def spire(x0, y0, w):
        mid = x0 + w // 2
        rect(x0 + 1, y0 - 2, w - 2, 2, hexc('#3a4a78'))
        rect(mid - 1, y0 - 5, 3, 3, gold)
        rect(mid, y0 - 12, 1, 7, hexc('#cfd6e6'))
        put(mid, y0 - 13, hexc('#ff5a5a'))

    def step_top(x0, y0, w):
        rect(x0 + 2, y0 - 3, w - 4, 3, hexc('#34406a'))
        rect(x0 + 4, y0 - 5, w - 8, 2, gold)

    tower(3, 10, 26, hexc('#2a3456'), hexc('#4a5a8c'))
    tower(13, 9, 34, hexc('#323e66'), hexc('#53649a'), step_top)
    tower(23, 14, 41, hexc('#25304f'), hexc('#4b5d94'), spire)  # いちばん高い
    tower(38, 9, 30, hexc('#2e3a60'), hexc('#4f6094'))
    tower(48, 12, 22, hexc('#283252'), hexc('#475788'), step_top)

    # 地面：芝・道・土
    rect(0, 56, N, 2, hexc('#5cb85c'))
    rect(0, 57, N, 1, hexc('#3f9a48'))
    rect(0, 58, N, 4, hexc('#4a4f5c'))
    for x in range(2, N, 8):
        rect(x, 59, 4, 1, hexc('#f2c14e'))
    rect(0, 62, N, 2, hexc('#7a5a3a'))
    return px


def to_image(px):
    img = Image.new('RGB', (N, N))
    img.putdata([c for row in px for c in row])
    return img.resize((N * SCALE, N * SCALE), Image.NEAREST)


def main():
    big = to_image(draw())
    with open(os.path.join(ICONSET, 'Contents.json'), encoding='utf-8') as f:
        contents = json.load(f)
    written = set()
    for im in contents['images']:
        size = float(im['size'].split('x')[0])
        scale = int(im['scale'].rstrip('x'))
        px = round(size * scale)
        name = im['filename']
        if name in written:
            continue
        out = big if px == 1024 else big.resize((px, px), Image.LANCZOS)
        out.convert('RGB').save(os.path.join(ICONSET, name), 'PNG', optimize=True)
        written.add(name)
        print(f'{name}: {px}x{px}')


if __name__ == '__main__':
    main()
