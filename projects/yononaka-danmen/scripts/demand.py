# -*- coding: utf-8 -*-
"""その言葉が、YouTube でどれだけ検索されているかを見る。

    python scripts/demand.py ガソリン税
    python scripts/demand.py ガソリン税 --deep     # 2段階まで広げる

補完に出る順番が、だいたい検索の多い順。1番目がいちばん打たれている。
**他人の動画の再生数は見ない。** それを基準にすると、既にある動画の後追いになる。
ここで見るのは「人が何を知りたがっているか」だけ。
"""
from __future__ import annotations

import argparse
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from danmen import sources  # noqa: E402


def main() -> int:
    ap = argparse.ArgumentParser(description="YouTube でどれだけ検索されているかを見る")
    ap.add_argument("word", nargs="+", help="調べたい言葉")
    ap.add_argument("--deep", action="store_true", help="出てきた言葉をもう一段引く")
    args = ap.parse_args()
    word = " ".join(args.word)

    yt = sources.suggest(word, youtube=True)
    gg = sources.suggest(word, youtube=False)

    print(f"■ 「{word}」で検索されていること\n")
    print("  【YouTube】　上ほど多く打たれている")
    for i, s in enumerate(yt[:10], 1):
        mark = "★" if i <= 3 else "  "
        print(f"   {mark}{i:>2}位  {s}")
    print()
    print("  【Google】　（記事で済む疑問も混ざる。比べる用）")
    for i, s in enumerate(gg[:6], 1):
        print(f"     {i:>2}位  {s}")
    print()

    if not args.deep:
        print("  （もう一段広げるには --deep）")
        return 0

    print("  【広げて見る】　上位の言葉を、それぞれもう一度引く\n")
    counts: Counter[str] = Counter()
    for s in yt[:6]:
        kids = sources.suggest(s, youtube=True)
        print(f"   ・{s}")
        for k in kids[:6]:
            if k != s:
                print(f"       └ {k}")
                for w in k.replace(word, "").split():
                    counts[w] += 1
        print()
    if counts:
        print("  【よく一緒に打たれている言葉】　関心が集まっているところ")
        for w, n in counts.most_common(10):
            print(f"     {n:>2}回  {w}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
