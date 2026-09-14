"""**絵が何回入れ替わるか**を台本の組み立てから数える（2026-09-14）。

画素を比べるとカードやテロップの差まで拾ってしまうので、
`script.json` の各行が持つ「下地」と「写真」の組み合わせを順に見る。
これが変わった回数が、見ている人にとっての「背景が変わった回数」。

    python scan_switch.py output/20260914b_ueda output/20260914b_ueda_short ...
"""
from __future__ import annotations

import io
import json
import sys
from pathlib import Path


def switches(build: Path) -> tuple[int, list[str]]:
    data = json.load(io.open(build / "script.json", encoding="utf-8"))
    seen: list[tuple[str, str]] = []
    background = ""
    for scene in data["scenes"]:
        background = scene.get("background") or background
        for line in scene["lines"]:
            image = line.get("image") or ""
            seen.append((background, image))
    changes = []
    for index in range(1, len(seen)):
        if seen[index] != seen[index - 1]:
            before, after = seen[index - 1], seen[index]
            changes.append(f"{_name(before)} → {_name(after)}")
    return len(changes), changes


def _name(pair: tuple[str, str]) -> str:
    background, image = pair
    if image:
        return Path(image).parent.name + "/" + Path(image).name
    return Path(background).name or "（下地なし）"


def main() -> int:
    bad = 0
    for target in sys.argv[1:]:
        build = Path(target)
        try:
            count, changes = switches(build)
        except FileNotFoundError:
            print(f"{build.name:28} script.json がありません")
            continue
        mark = "  " if count <= 1 else "× "
        print(f"{mark}{build.name:28} 入れ替え {count}回")
        for row in changes:
            print(f"      {row}")
        if count > 1:
            bad += 1
    print(f"\n2回以上入れ替わっている動画: {bad}本")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
