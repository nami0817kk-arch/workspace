# -*- coding: utf-8 -*-
"""アプリのアイコンを、1枚の絵から全サイズ書き出す。

    python tool/make_icons.py

出力先:
    web/favicon.png, web/icons/*.png
    android/app/src/main/res/mipmap-*/ic_launcher.png
    ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png

**元の絵は `tool/icon_source.png`（1024x1024）。** ここを差し替えれば
全サイズが付いてくる。各サイズの PNG を手で置くと、サイズを足すたびに
作り直すことになる。

2026-10-01 に、コードで描いたユニフォームから**1枚の絵**へ替えた
（ユーザーが用意したもの）。**「画像素材は持たない」という決まりは
ここには掛からない**——あれはアプリの中の絵の話で、同梱しているのは
フォントとランチャーアイコンだけ、と CLAUDE.md にある。
元の絵は `tool/` に置いてあるので、アプリのバンドルには入らない。

絵を差し替えるときに、**必ず拡大して確かめること**:

- **実在のブランドのマーク。** 最初に受け取った絵は胸にスポーツ用品
  メーカーのロゴが入っていた。そのまま出すと審査のガイドライン 5.2.1
  （第三者の知的財産）で却下される。クラブ名もリーグ名も架空にしてきたのは
  同じ線を踏まないため。
- 実在のクラブのエンブレム、実在の選手に似た顔。
- 文字・数字（ストアのアイコンに言葉を入れない）。
- 角丸・透過・余白。**iOS が自分で角を丸める**ので、こちらで丸めると二重になる。
- **44px に縮めて読めるか。** ホーム画面ではそこまで小さくなる。
"""

import json
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "tool", "icon_source.png")

# 実際の書き出しサイズの4倍から縮める。小さいサイズでも輪郭が荒れない。
SCALE = 4

_art = None


def art():
    """元の絵。1024x1024 の正方形で、透過を持たないこと。"""
    global _art
    if _art is None:
        if not os.path.exists(SOURCE):
            raise SystemExit("元の絵が見つからない: " + SOURCE)
        img = Image.open(SOURCE).convert("RGB")
        if img.size != (1024, 1024):
            raise SystemExit("元の絵は 1024x1024 で用意する（いまは %s）" % (img.size,))
        _art = img
    return _art


def _vertical(size, top, bottom):
    """上から下へのグラデーション。"""
    grad = Image.new("RGB", (1, size))
    px = grad.load()
    for y in range(size):
        t = y / max(size - 1, 1)
        px[0, y] = tuple(round(a + (b - a) * t) for a, b in zip(top, bottom))
    return grad.resize((size, size), Image.BILINEAR)


def _edge(box):
    """絵の端の平均色。安全域を埋めるときに、絵の調子と揃えるため。"""
    return art().crop(box).resize((1, 1), Image.BOX).getpixel((0, 0))


def draw(size, *, padding=0.0, rounded=True):
    """アイコンを1枚書き出す。

    padding は安全域。maskable アイコンは端が丸く切られるので、絵を縮めて
    中身を内側へ寄せる。**周りを単色で埋めない**——この絵は上が暗く下が
    緑なので、一色だと境目に帯が出る。端の色から作ったグラデーションで埋める。
    """
    s = size * SCALE

    if padding > 0:
        k = 1.0 - padding * 2
        inner = round(s * k)
        base = _vertical(
            s,
            _edge((0, 0, 1024, 40)),
            _edge((0, 1024 - 40, 1024, 1024)),
        )
        base.paste(
            art().resize((inner, inner), Image.LANCZOS), ((s - inner) // 2,) * 2
        )
        img = base.convert("RGBA")
    else:
        img = art().resize((s, s), Image.LANCZOS).convert("RGBA")

    if rounded:
        # web と Android の従来アイコンだけ。**iOS では丸めない。**
        mask = Image.new("L", (s, s), 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            [0, 0, s - 1, s - 1], radius=s * 0.22, fill=255
        )
        img.putalpha(mask)

    return img.resize((size, size), Image.LANCZOS)


def save(img, *parts):
    path = os.path.join(ROOT, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print("wrote", os.path.relpath(path, ROOT))


def main():
    save(draw(16), "web", "favicon.png")
    for size in (192, 512):
        save(draw(size), "web", "icons", "Icon-%d.png" % size)
        # maskable は端が丸く切られる。中身を1割ぶん内側へ。
        save(
            draw(size, padding=0.10, rounded=False),
            "web",
            "icons",
            "Icon-maskable-%d.png" % size,
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
            "mipmap-" + bucket,
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
