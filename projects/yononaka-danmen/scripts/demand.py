# -*- coding: utf-8 -*-
"""その言葉に、動画としての需要があるか見る。

    python scripts/demand.py ガソリン税

Google（記事で済む疑問も混ざる）と YouTube（動画で見たい疑問）を並べて出す。
題材を決める前に、これで確かめる。
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from danmen import sources  # noqa: E402

if len(sys.argv) < 2:
    raise SystemExit("調べたい言葉を渡してください　例: python scripts/demand.py ガソリン税")

word = " ".join(sys.argv[1:])
d = sources.demand(word)
print(f"■ 「{word}」で検索されていること\n")
for name, items in d.items():
    print(f"  【{name}】")
    for s in items[:10]:
        print(f"    ・{s}")
    print()
