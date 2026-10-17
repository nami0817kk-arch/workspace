"""ひかりの指名のアプリアイコン（1024px）を作り、iOS の AppIcon に置く。

元の絵は art/icon_src.jpg（2026-10-04、Cloudflare Workers AI の FLUX.1 schnell で作った10案からユーザーが選んだ「指名」の案：
3人の練習生のうち、真ん中の子だけにスポットライトが当たる）。FLUX.1 schnell は Apache 2.0。
小さく表示しても真ん中の光が立つよう、少しだけ明るさとくっきりさを足す。
App Store は透過のあるアイコンを断るので RGB で保存する。
使い方: python tool/make_icon.py   （projects/hikari7 で実行）
"""
from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter

HERE = Path(__file__).resolve().parent.parent
SRC = HERE / 'art' / 'icon_src.jpg'


def main():
    img = Image.open(SRC).convert('RGB').resize((1024, 1024), Image.LANCZOS)
    img = ImageEnhance.Contrast(img).enhance(1.08)
    img = ImageEnhance.Brightness(img).enhance(1.04)
    img = img.filter(ImageFilter.UnsharpMask(radius=2, percent=60, threshold=2))
    icon_dir = HERE / 'app' / 'ios' / 'Runner' / 'Assets.xcassets' / 'AppIcon.appiconset'
    img.save(icon_dir / 'Icon-1024.png', optimize=True)
    print('saved', icon_dir / 'Icon-1024.png')


if __name__ == '__main__':
    main()
