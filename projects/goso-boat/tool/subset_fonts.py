"""同梱フォントを、アプリで使う字だけに絞る。

画面の文言は lib/l10n/*.arb に全部あり、利用者が文字を入力する所は無い。
だから ARB に出てくる字＋英数字・記号だけに絞れる（元は2書体で約6MB → 数百KB）。

    python tool/subset_fonts.py          … 絞り込んで assets/fonts/ に書き出す
    python tool/subset_fonts.py --check  … ARB の字がすべて入っているかだけ調べる（CI 用）

元のフォントは projects/puzzle-book と projects/soccer-manager にある OFL 1.1 のもの。
ARB に字を足したら、このスクリプトを回し直す（--check が CI で落ちて気づける）。
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont

HERE = Path(__file__).resolve().parent.parent
REPO = HERE.parent.parent
SOURCES = {
    # 見出し・ボタン（太字）は丸ゴシック、説明の本文はゴシック
    "GosoRounded-ExtraBold.ttf": REPO / "projects/puzzle-book/assets/fonts/MPLUSRounded1c-ExtraBold.ttf",
    "GosoSans-Regular.ttf": REPO / "projects/soccer-manager/assets/fonts/NotoSansJP-Regular.ttf",
}
OUT = HERE / "assets/fonts"

# 数字・英字・よく使う記号は ARB に無くても（面の番号・回数など）出るので必ず入れる
BASE = "".join(chr(c) for c in range(0x20, 0x7F)) + "×＋・↑↓★☆…—•「」『』（）、。！？：〜ー 　"


def used_chars() -> set[str]:
    chars = set(BASE)
    for arb in (HERE / "lib/l10n").glob("*.arb"):
        data = json.loads(arb.read_text(encoding="utf-8"))
        for k, v in data.items():
            if not k.startswith("@") and isinstance(v, str):
                chars.update(v)
    chars.discard("\n")
    return chars


def missing(font_path: Path, chars: set[str]) -> list[str]:
    cmap = TTFont(font_path).getBestCmap()
    return sorted(c for c in chars if ord(c) not in cmap and not c.isspace())


def main() -> int:
    chars = used_chars()
    if "--check" in sys.argv:
        bad = False
        for name in SOURCES:
            lack = missing(OUT / name, chars)
            if lack:
                bad = True
                print(f"{name} に無い字: {''.join(lack)}  → python tool/subset_fonts.py を回し直す")
        return 1 if bad else 0

    OUT.mkdir(parents=True, exist_ok=True)
    text = "".join(sorted(chars))
    for name, src in SOURCES.items():
        opts = subset.Options()
        opts.layout_features = ["*"]
        opts.name_IDs = ["*"]
        opts.notdef_outline = True
        font = subset.load_font(str(src), opts)
        s = subset.Subsetter(opts)
        s.populate(text=text)
        s.subset(font)
        dst = OUT / name
        subset.save_font(font, str(dst), opts)
        print(f"{name}: {dst.stat().st_size // 1024}KB（{len(chars)}字）")
    for lic in ("OFL-MPLUSRounded1c.txt",):
        (OUT / lic).write_bytes((REPO / "projects/puzzle-book/assets/fonts" / lic).read_bytes())
    (OUT / "OFL-NotoSansJP.txt").write_bytes((REPO / "projects/soccer-manager/assets/fonts/OFL-NotoSansJP.txt").read_bytes())
    return 0


if __name__ == "__main__":
    sys.exit(main())
