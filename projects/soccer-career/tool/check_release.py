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
    """dart2js が出す形にする。

    **ASCII はそのまま**残る。全部をエスケープすると、英数字を含む文字列が
    永久に当たらなくなる——つまり「入っていない」と誤って報告する。
    実際に "今season の残りを消化する" と "…1試合に入る。" の2つが
    死んだ needle になっていた。
    """
    return "".join(
        ch if ord(ch) < 128 else BACKSLASH + "u{:04x}".format(ord(ch))
        for ch in text)


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else "build/web/main.dart.js"
    if not os.path.exists(path):
        print("先に flutter build web --release を実行してください:", path)
        return 2

    js = io.open(path, encoding="utf-8", errors="replace").read()
    # needle が壊れていないかを先に見る。ASCII を含む文字列を全部
    # エスケープしていた頃は、何を入れても「入っていない」と出ていた。
    broken = [t for t in ADMIN_ONLY if escaped(t) == t or BACKSLASH not in escaped(t)]
    if broken:
        print("needle が日本語を含んでいません（検査になりません）:", broken)
        return 2

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
