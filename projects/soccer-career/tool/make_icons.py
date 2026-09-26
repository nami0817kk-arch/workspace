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
背番号入りのユニフォームにしてあるのは、**一覧でサッカーゲームと見分ける**ため
（緑地に白いボールは同じ棚に大量にあり、44px では区別が付かない）。
番号の書体はアプリの同梱フォントなので、ストアの絵と中の書体が揃う。
"""

import json
import os

from PIL import Image, ImageDraw, ImageFont

# アプリのテーマ色。lib/main.dart の seedColor と揃える。
GREEN = (27, 94, 63)
DARK = (11, 45, 30)
WHITE = (245, 246, 243)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# 実際の書き出しサイズの4倍で描いてから縮める。小さいサイズでも輪郭が荒れない。
SCALE = 4


# 背番号。10 は「その選手」を指す番号として一番読みやすい2桁。
NUMBER = "10"

# ここより小さいと、2桁の数字が潰れて滲みにしか見えない。
# 小さいほうは布の形だけで見せる（実測で 40px を下回ると読めない）。
NUMBER_MIN = 40


def _font(px):
    """同梱フォントを使う。アプリの中と書体を揃えるため。"""
    path = os.path.join(ROOT, "assets", "fonts", "NotoSansJP-Bold.ttf")
    if not os.path.exists(path):
        raise SystemExit(f"同梱フォントが見つからない: {path}")
    return ImageFont.truetype(path, px)


def draw(size, *, padding=0.0, rounded=True, transparent=False):
    """ユニフォームを1枚描く。

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

    # 安全域のぶんだけ内側へ寄せる（中心から縮める）。
    def at(x, y):
        k = 1.0 - padding * 2
        return (s * (0.5 + (x - 0.5) * k), s * (0.5 + (y - 0.5) * k))

    # 肩 → 右袖 → 裾 → 左袖 の順に一周する。
    body = [
        at(0.37, 0.24), at(0.63, 0.24),
        at(0.75, 0.35), at(0.67, 0.41),
        at(0.66, 0.82), at(0.34, 0.82),
        at(0.33, 0.41), at(0.25, 0.35),
    ]
    d.polygon(body, fill=WHITE)

    # 襟。地の色で V を抜く（透過のときは布に穴が空かないよう濃い色で描く）。
    collar = [at(0.445, 0.24), at(0.555, 0.24), at(0.50, 0.325)]
    d.polygon(collar, fill=DARK if transparent else GREEN)

    if size >= NUMBER_MIN:
        # **布の幅に収める。** 大きさを決め打ちにしていたら、2桁の番号が
        # 布から横へはみ出して緑の上に乗っていた（1024 と maskable で出た）。
        # 安全域で布が縮むぶんも、ここで自動的に付いてくる。
        left, _ = at(0.34, 0.5)
        right, _ = at(0.66, 0.5)
        limit = (right - left) * 0.78
        px = int(s * 0.32 * (1.0 - padding * 2))
        while px > 4:
            font = _font(px)
            box = d.textbbox((0, 0), NUMBER, font=font)
            if box[2] - box[0] <= limit:
                break
            px -= 1
        # 縦は脇下から裾までの真ん中に置く（襟と裾のどちらにも触れない）。
        _, top = at(0.5, 0.41)
        _, bottom = at(0.5, 0.82)
        x, _ = at(0.5, 0.5)
        d.text(
            (
                x - (box[2] - box[0]) / 2 - box[0],
                (top + bottom) / 2 - (box[3] - box[1]) / 2 - box[1],
            ),
            NUMBER,
            font=font,
            fill=DARK,
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
        # **`convert("RGB")` を忘れない。** 角を四角くしただけでは
        # アルファチャンネルは残る。Apple はそれをアップロードの時点で
        # 弾く（"can't be transparent nor contain an alpha channel"）ので、
        # 気付くのは提出しようとした日になる。
        save(
            draw(round(base * scale), rounded=False).convert("RGB"),
            "ios",
            "Runner",
            "Assets.xcassets",
            "AppIcon.appiconset",
            filename,
        )


if __name__ == "__main__":
    main()
