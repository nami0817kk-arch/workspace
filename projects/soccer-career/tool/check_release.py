# -*- coding: utf-8 -*-
"""公開ビルドに管理画面が入っていないかを見る。

    flutter build web --release
    python tool/check_release.py

Dart の web ビルドは日本語を \\uXXXX に落とすので、そのまま grep しても当たらない。
ここでは管理画面にしか出てこない文字列を、その形に直してから探す。

**入口を1か所でも kAdmin の外に置くと、画面ごと残る。** 実際に、メニュー項目だけを
`if (kAdmin)` で囲み、`switch` の `case 'admin':` を囲み忘れていたことがあり、
そのときは公開ビルドに管理画面の文字列がそのまま入っていた（テストでは気付けない）。
"""
import io
import os
import sys

BACKSLASH = chr(92)

# 管理画面にしか出てこない文字列。
ADMIN_ONLY = [
    "選ぶと、その局面だけで1試合に入る。",
    "全部外す",
    "年進める",
    "今season の残りを消化する",
]

# 遊ぶ側にも出る文字列。ここが消えていたら、検査そのものが壊れている。
CONTROL = ["ポテンシャル", "今週の練習"]


def escaped(text):
    return "".join(BACKSLASH + "u{:04x}".format(ord(ch)) for ch in text)


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else "build/web/main.dart.js"
    if not os.path.exists(path):
        print("先に flutter build web --release を実行してください:", path)
        return 2

    js = io.open(path, encoding="utf-8", errors="replace").read()
    leaked = [t for t in ADMIN_ONLY if escaped(t) in js]
    missing = [t for t in CONTROL if escaped(t) not in js]

    if missing:
        print("検査が壊れています。遊ぶ側の文字列が見つかりません:", missing)
        return 2
    if leaked:
        print("公開ビルドに管理画面が入っています:")
        for text in leaked:
            print("  -", text)
        return 1
    print("公開ビルドに管理画面は入っていません（{:.1f} MB）".format(
        len(js) / 1024 / 1024))
    return 0


sys.exit(main())
