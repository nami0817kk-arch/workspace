"""heredoc 経由で化けた制御文字が、ソースに残っていないか探す。

2026-09-07 に、Bash ツールの heredoc で Python を書いたとき、
正規表現の単語境界がバックスペース1文字（0x08）に化けた。
**エラーは出ない。**テストが通ったまま、条件だけが黙って効かなくなる。

同じ日に3回踏んだので、目で気をつけるのをやめて探せるようにした。
書き方そのものの回避策は docs/session-faq.md を参照。

    python scripts/find-mangled-chars.py [対象ディレクトリ...]

見つかれば 1 を返すので、CI からも使える。
"""

from __future__ import annotations

import sys
from pathlib import Path

# タブ(0x09)・改行(0x0a)・復帰(0x0d)はソースに出てよい。それ以外は化けを疑う。
SUSPECT = {
    0x00: "NUL",
    0x07: "ベル",
    0x08: "バックスペース（単語境界の化け）",
    0x0b: "垂直タブ",
    0x0c: "改ページ",
    0x1b: "エスケープ",
}
SUFFIXES = {".py", ".md", ".yaml", ".yml", ".ps1", ".sh",
            ".dart", ".ts", ".js", ".json", ".txt"}
SKIP = {".venv", "node_modules", ".git", "output", "build", "dist", "__pycache__"}
DEFAULT_ROOTS = ("projects", "libs", "platform", "scripts", "docs", "templates")


def scan(root: Path) -> list[tuple[Path, int, str]]:
    found = []
    for path in root.rglob("*"):
        if not path.is_file() or path.suffix not in SUFFIXES:
            continue
        if any(part in SKIP for part in path.parts):
            continue
        try:
            raw = path.read_bytes()
        except OSError:
            continue
        for code, name in SUSPECT.items():
            at = raw.find(bytes([code]))
            if at >= 0:
                found.append((path, raw[:at].count(b"\n") + 1, name))
    return found


def main(argv: list[str]) -> int:
    roots = [Path(a) for a in argv[1:]] or [Path(r) for r in DEFAULT_ROOTS]
    found, looked = [], 0
    for root in roots:
        if not root.exists():
            continue
        looked += 1
        found += scan(root)
    for path, line, name in sorted(found):
        print(f"{path.as_posix()}:{line}  {name}")
    if found:
        print(f"\n{len(found)} 件。**その場を直すだけでなく、"
              "どう書いたかを見直すこと**（docs/session-faq.md）")
        return 1
    print(f"化けた制御文字は見つかりませんでした（{looked} か所を確認）")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
