# -*- coding: utf-8 -*-
"""候補に点を付けて並べる。どれを作るかを決めるための道具。

    python scripts/pick.py research/candidates/20261006b.json

点の付け方は danmen/pick.py の表のとおり。○× を付けるのはユーザー。
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from danmen import pick  # noqa: E402


def bar(n: int, mx: int = 5) -> str:
    return "■" * n + "□" * (mx - n)


def main() -> int:
    ap = argparse.ArgumentParser(description="候補に点を付けて並べる")
    ap.add_argument("candidates", help="gather.py が書いた JSON")
    ap.add_argument("--no-ai", action="store_true", help="断面が立つかの確認を省く（速い）")
    ap.add_argument("--top", type=int, default=5, help="上から何件出すか")
    args = ap.parse_args()

    rows = json.loads(Path(args.candidates).read_text(encoding="utf-8"))
    print(f"候補 {len(rows)} 件に点を付けています…", file=sys.stderr)
    ranked = pick.rank(rows, ask_ai=not args.no_ai)

    print("\n■ 点の付け方　検索の広さ5／問いの濃さ5／原典の堅さ5／30分もつか5／新しさ3　＝ 23点\n")
    for i, s in enumerate(ranked[:args.top], 1):
        print(f"{i}. {s.row.get('title')}")
        print(f"   合計 {s.total:>2}/23")
        print(f"     検索の広さ  {bar(s.breadth)}  「{s.word}」で補完 {len(s.suggests)} 件")
        print(f"     問いの濃さ  {bar(s.depth)}")
        print(f"     原典の堅さ  {bar(s.source)}  {s.row.get('source')}")
        print(f"     30分もつか  {bar(s.length)}  断面 {len(s.cuts)} つ")
        print(f"     新しさ      {bar(s.fresh, 3)}  {s.row.get('source_feed')}")
        if s.suggests:
            print(f"     検索の上位: " + " / ".join(s.suggests[:5]))
        if s.cuts:
            for n, c in enumerate(s.cuts, 1):
                print(f"       {n}の断面: {c}")
        print()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
