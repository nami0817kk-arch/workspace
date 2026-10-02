"""ひかりの七席のアプリアイコン（1024px）を描いて、iOS の AppIcon に置く。

夜のステージに7つの椅子。真ん中の1つだけがスポットライトを浴びて金色に光る（タイトル画面と同じ絵柄）。
大きく描いてから縮めて、線のギザギザを消す。App Store は透過のあるアイコンを断るので RGB で保存する。
使い方: python tool/make_icon.py   （projects/hikari7 で実行）
"""
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent.parent
N = 2048  # 描く大きさ（最後に 1024 に縮める）


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def chair(d, cx, base_y, s, back, seat, leg):
    """椅子1脚。cx=中心、base_y=脚の下端、s=大きさ。"""
    w = 200 * s
    bh = 190 * s
    sh = 52 * s
    lh = 120 * s
    r = 34 * s
    top = base_y - lh - sh - bh
    d.rounded_rectangle([cx - w / 2, top, cx + w / 2, top + bh], radius=r, fill=back)
    d.rounded_rectangle([cx - w * 0.6, top + bh - 4 * s, cx + w * 0.6, top + bh + sh], radius=r * 0.6, fill=seat)
    lw = 26 * s
    for x in (cx - w * 0.5, cx + w * 0.5 - lw):
        d.rounded_rectangle([x, top + bh + sh - 2 * s, x + lw, base_y], radius=lw / 3, fill=leg)


def main():
    img = Image.new('RGB', (N, N))
    px = ImageDraw.Draw(img)
    top, bottom = (58, 34, 110), (16, 10, 34)
    for y in range(N):
        px.line([(0, y), (N, y)], fill=lerp(top, bottom, y / N))

    # スポットライト（上から差す光の筋）
    light = Image.new('L', (N, N), 0)
    ld = ImageDraw.Draw(light)
    ld.polygon([(N * 0.43, 0), (N * 0.57, 0), (N * 0.80, N * 0.86), (N * 0.20, N * 0.86)], fill=150)
    for cx in (0.12, 0.88):
        ld.polygon([(N * (cx - 0.03), 0), (N * (cx + 0.03), 0), (N * (cx + 0.12), N * 0.9), (N * (cx - 0.12), N * 0.9)], fill=45)
    light = light.filter(ImageFilter.GaussianBlur(N * 0.03))
    # 下に行くほど薄く
    fade = Image.new('L', (N, N))
    fd = ImageDraw.Draw(fade)
    for y in range(N):
        fd.line([(0, y), (N, y)], fill=int(255 * max(0.0, 1 - y / (N * 0.95)) ** 0.7))
    light = Image.composite(light, Image.new('L', (N, N), 0), fade)
    img = Image.composite(Image.new('RGB', (N, N), (255, 240, 200)), img, light)

    # 床の照り返し
    glow = Image.new('L', (N, N), 0)
    ImageDraw.Draw(glow).ellipse([N * 0.18, N * 0.74, N * 0.82, N * 0.90], fill=120)
    glow = glow.filter(ImageFilter.GaussianBlur(N * 0.04))
    img = Image.composite(Image.new('RGB', (N, N), (233, 186, 75)), img, glow)

    d = ImageDraw.Draw(img)
    base = N * 0.80
    # 両脇の6脚（暗い紫）。外側ほど小さく、奥に見せる
    for i, (dx, s) in enumerate([(0.355, 0.62), (0.575, 0.52), (0.78, 0.42)]):
        for sign in (-1, 1):
            cx = N / 2 + sign * N * dx * 0.52
            chair(d, cx, base - N * 0.03 * (i + 1), s * N / 1024 * 0.95,
                  back=(84, 64, 140), seat=(100, 80, 160), leg=(44, 32, 82))
    # 真ん中の金の椅子
    chair(d, N / 2, base, 1.05 * N / 1024, back=(238, 188, 72), seat=(250, 214, 122), leg=(150, 104, 24))

    # 金の椅子の上の光の粒（星）
    def star(cx, cy, r, col):
        pts = []
        for k in range(8):
            rr = r if k % 2 == 0 else r * 0.22
            ang = k * 3.14159265 / 4
            from math import cos, sin
            pts.append((cx + rr * sin(ang), cy - rr * cos(ang)))
        d.polygon(pts, fill=col)
    star(N / 2, N * 0.27, N * 0.075, (255, 236, 170))
    star(N * 0.36, N * 0.36, N * 0.028, (255, 226, 150))
    star(N * 0.645, N * 0.33, N * 0.022, (255, 226, 150))

    out = img.resize((1024, 1024), Image.LANCZOS).convert('RGB')
    icon_dir = HERE / 'app/ios/Runner/Assets.xcassets/AppIcon.appiconset'
    for old in icon_dir.glob('*.png'):
        old.unlink()
    out.save(icon_dir / 'Icon-1024.png', optimize=True)
    (icon_dir / 'Contents.json').write_text(json.dumps({
        'images': [{'filename': 'Icon-1024.png', 'idiom': 'universal', 'platform': 'ios', 'size': '1024x1024'}],
        'info': {'author': 'xcode', 'version': 1},
    }, indent=2) + '\n', encoding='utf-8')
    out.resize((180, 180), Image.LANCZOS).save(HERE / 'build' / 'icon-preview-180.png') if (HERE / 'build').exists() else None
    print('AppIcon を置いた', (icon_dir / 'Icon-1024.png').stat().st_size // 1024, 'KB')


if __name__ == '__main__':
    main()
