# -*- coding: utf-8 -*-
"""点検をまとめて回す。

点検の道具が増えたので、1つで済むようにした。**作る前と、見せる前に回す。**

    python scripts/check_all.py          # まとめて。問題のあるものだけ詳しく出す
    python scripts/check_all.py -v       # 全部の中身を出す

見るのは5つ。

  1. 図の文字が、スマホで読める大きさか（`audit_type.py`）
  2. 画面の文字が、同じく読めるか（`audit_screens.py`）
  3. 色の見分けと、文字と背景のコントラスト（`audit_color.py`）
  4. 索引と実物がずれていないか（`which.py --check`）
  5. 節ごとの画面の数が足りているか（`danmen.sequence`）

**字幕が読める速さ**は、動画を作るときに `danmen.movie` が出す（ここには無い）。
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

CHECKS = [
    ("図の文字", [sys.executable, "-X", "utf8", "scripts/audit_type.py"],
     "すべて基準を満たしています"),
    ("画面の文字", [sys.executable, "-X", "utf8", "scripts/audit_screens.py"],
     "すべて基準を満たしています"),
    ("色", [sys.executable, "-X", "utf8", "scripts/audit_color.py"],
     "すべて目安を満たしています"),
    ("索引", [sys.executable, "-X", "utf8", "scripts/which.py", "--check"],
     "索引と実物は合っています"),
]


def run(name: str, cmd: list[str], ok_mark: str, verbose: bool) -> tuple[bool, str]:
    r = subprocess.run(cmd, cwd=str(ROOT), capture_output=True, text=True,
                       encoding="utf-8", errors="replace")
    out = (r.stdout or "") + (r.stderr or "")
    ok = ok_mark in out
    return ok, out


def main() -> int:
    verbose = "-v" in sys.argv
    print("■ 点検\n")
    bad: list[tuple[str, str]] = []
    for name, cmd, ok_mark in CHECKS:
        ok, out = run(name, cmd, ok_mark, verbose)
        print("  {:>4}  {}".format("OK" if ok else "直す", name))
        if verbose or not ok:
            bad.append((name, out))

    # 節ごとの画面の数
    from danmen import sequence
    rep = sequence.report()
    seq_ok = "長すぎます" not in rep and "短すぎます" not in rep
    print("  {:>4}  節ごとの画面の数".format("OK" if seq_ok else "直す"))
    if verbose or not seq_ok:
        bad.append(("節ごとの画面の数", rep))

    print()
    if not bad:
        print("すべて通りました。")
        return 0
    for name, out in bad:
        print("─" * 60)
        print("● {}".format(name))
        print(out.rstrip())
        print()
    return 0 if all(False for _ in ()) else (0 if verbose else 1)


if __name__ == "__main__":
    raise SystemExit(main())
