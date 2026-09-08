# -*- coding: utf-8 -*-
"""アプリのアイコンを作る。

Flutter の雛形のまま（水色の Flutter ロゴ）だったものを差し替えるために書いた。
手で描いた PNG を置くと、サイズを足すたびに作り直すことになる。

    python tool/make_icons.py

出力先:
    web/favicon.png, web/icons/*.png
    android/app/src/main/res/mipmap-*/ic_launcher.png
    ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png

図案は幾何学的なものだけにしてある（実在クラブのエンブレムを想起させない）。
"""

import json
import math
import os

from PIL import Image, ImageDraw

# アプリのテーマ色。lib/main.dart の seedColor と揃える。
GREEN = (27, 94, 63)
DARK = (11, 45, 30)
WHITE = (245, 246, 243)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# 実際の書き出しサイズの4倍で描いてから縮める。小さいサイズでも輪郭が荒れない。
SCALE = 4


def _pentagon(center, radius, rotation=-math.pi / 2):
    cx, cy = center
    return [
        (
            cx + radius * math.cos(rotation + i * 2 * math.pi / 5),
            cy + radius * math.sin(rotation + i * 2 * math.pi / 5),
        )
        for i in range(5)
    ]


def draw(size, *, padding=0.0, rounded=True, transparent=False):
    """ボールを1つ描く。

    padding は安全域。maskable アイコンは端が切られるので内側に寄せる。
    """
    s = size * SCALE
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    if not transparent:
        if rounded:
            d.rounded_rectangle([0, 0, s - 1, s - 1], radius=s * 0.22, fill=GREEN)
        else:
            d.rectangle([0, 0, s - 1, s - 1], fill=GREEN)

    # ボール。
    inset = s * (0.18 + padding)
    ball = [inset, inset, s - inset, s - inset]
    d.ellipse(ball, fill=WHITE)

    cx = cy = s / 2
    r = (s - 2 * inset) / 2
    core = r * 0.42
    d.polygon(_pentagon((cx, cy), core), fill=DARK)

    # 五角形の頂点から外へ伸びる継ぎ目。
    width = max(1, int(s * 0.016))
    for x, y in _pentagon((cx, cy), core):
        dx, dy = x - cx, y - cy
        length = math.hypot(dx, dy) or 1
        d.line(
            [(x, y), (cx + dx / length * r * 0.92, cy + dy / length * r * 0.92)],
            fill=DARK,
            width=width,
        )

    return img.resize((size, size), Image.LANCZOS)


def save(img, *parts):
    path = os.path.join(ROOT, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print("wrote", os.path.relpath(path, ROOT))


def main():
    save(draw(16), "web", "favicon.png")
    for size in (192, 512):
        save(draw(size), "web", "icons", f"Icon-{size}.png")
        # maskable は端が丸く切られる。中身を1割ぶん内側へ。
        save(
            draw(size, padding=0.10, rounded=False),
            "web",
            "icons",
            f"Icon-maskable-{size}.png",
        )

    android = {
        "mdpi": 48,
        "hdpi": 72,
        "xhdpi": 96,
        "xxhdpi": 144,
        "xxxhdpi": 192,
    }
    for bucket, size in android.items():
        save(
            draw(size),
            "android",
            "app",
            "src",
            "main",
            "res",
            f"mipmap-{bucket}",
            "ic_launcher.png",
        )

    # iOS は Contents.json に並んでいるファイル名をそのまま使う。
    icon_set = os.path.join(
        ROOT, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset"
    )
    with open(os.path.join(icon_set, "Contents.json"), encoding="utf-8") as f:
        contents = json.load(f)
    for image in contents["images"]:
        filename = image.get("filename")
        if not filename:
            continue
        base = float(image["size"].split("x")[0])
        scale = int(image["scale"].rstrip("x"))
        # iOS のアイコンは角丸も透過も持てない。
        save(
            draw(round(base * scale), rounded=False),
            "ios",
            "Runner",
            "Assets.xcassets",
            "AppIcon.appiconset",
            filename,
        )


if __name__ == "__main__":
    main()
