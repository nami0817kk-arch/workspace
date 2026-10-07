# -*- coding: utf-8 -*-
"""どの図・どの画面を使うかを引く。

    python scripts/which.py            # 全部を用途ごとに
    python scripts/which.py 内訳       # その言葉に当たるものだけ
    python scripts/which.py --check    # 索引と実物がずれていないか見る

同じことができるものが複数あるときは、**先に書いてあるものを使う**。
"""
from __future__ import annotations

import importlib
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from danmen import catalog


def show(use: str, items) -> None:
    print("■ {}".format(use))
    for i, (call, what, when) in enumerate(items):
        mark = "→" if i == 0 else " "
        print("  {} {:24s} {:28s} {}".format(mark, call, what, when))
    print()


def check() -> int:
    """索引に載っているものが実物にあるか、実物で載っていないものがないか。"""
    listed = set()
    missing = []
    for items in catalog.CATALOG.values():
        for call, _, _ in items:
            listed.add(call)
            mod, kind = call.split(".")
            try:
                m = importlib.import_module("danmen." + mod)
            except Exception as e:
                missing.append("{}（読めない: {}）".format(call, e))
                continue
            if kind not in getattr(m, "KINDS", {}):
                missing.append("{}（実物にない）".format(call))
    # 実物にあるのに索引に無いもの
    extra = []
    for mod in ("figures", "news", "charts2", "charts3", "charts4", "charts5",
                "charts6", "screens", "studio", "news2", "news3", "news4",
                "talk", "fullscreen"):
        m = importlib.import_module("danmen." + mod)
        for kind in getattr(m, "KINDS", {}):
            call = "{}.{}".format(mod, kind)
            if call not in listed:
                extra.append(call)
    if missing:
        print("索引にあるのに実物に無い（{}件）:".format(len(missing)))
        for x in missing:
            print("  " + x)
    if extra:
        print("実物にあるのに索引に無い（{}件）:".format(len(extra)))
        for x in extra:
            print("  " + x)
    if not missing and not extra:
        print("索引と実物は合っています（{}種）。".format(len(listed)))
    return 1 if (missing or extra) else 0


def main() -> int:
    args = [a for a in sys.argv[1:] if a]
    if args and args[0] in ("--check", "-c"):
        return check()
    if args:
        hits = catalog.find(args[0])
        if not hits:
            print("「{}」に当たるものはありません。".format(args[0]))
            print("用途の見出し: " + " / ".join(catalog.CATALOG))
            return 1
        print("「{}」に当たるもの（{}件）\n".format(args[0], len(hits)))
        last = None
        for use, it in hits:
            if use != last:
                print("■ {}".format(use))
                last = use
            print("    {:24s} {:28s} {}".format(*it))
        return 0
    total = 0
    for use, items in catalog.CATALOG.items():
        show(use, items)
        total += len(items)
    print("■ 仕上げに掛けるもの")
    for call, what, when in catalog.FINISH:
        print("    {:30s} {:26s} {}".format(call, what, when))
    print()
    print("図と画面は {} 種。→ の付いたものが、その用途でまず使うもの。".format(total))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
