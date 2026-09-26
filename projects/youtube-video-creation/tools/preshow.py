# -*- coding: utf-8 -*-
"""台本を見せる前に通す道具（2026-09-22 指示「しっかりとルール化して」）。

CLAUDE.md「見せる前の決まり」の表を、機械で見られるぶんは回し、
手で見るぶんは一覧で出す。**見せるのは、全部に答えてから。**

使い方:
    python tools/preshow.py scripts/20260922_*.md

回すもの:
  1. 1本ずつ `draft` の点検（取材メモから作り直しはしない。`check` 相当）
  2. `variety`（並べて見る。結び方・本のあいだの重なり）
  3. `tools/flow.py`（流れの点検。控えが台本より新しければ飛ばす）
最後に、手で見る決まりを表で出す。
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

HAND_CHECKS = [
    ("1本に問いは1つ", "それに答えない節・数字・順位が入っていないか（09-22 日本代表の順位表）"),
    ("書き出しが日本語として自然か", "冒頭3行を声に出して読む（09-21 ボーンマス）"),
    ("群れの回は群れが主語か", "タイトルが1人の名前で始まっていないか。サムネは並べているか（09-17／09-22）"),
    ("反応に国の札が無いか", "全部「ネット民」。海外の声は混ざっているか（09-21／09-17）"),
    ("流れの点検の指摘を直したか", "output/flow/<台本>.md の①〜⑤とショートの判定を読んだか"),
    ("前の日と同じ写真を使っていないか", "assets/images の日付フォルダを見る（09-17）"),
    ("ページを自分で開いて見たか", "CSS が生で出ていないか、スマホ幅で読めるか（09-22「変だよ」）"),
    ("直した台本を同じURLで出し直したか", "（09-17）"),
]


def _run(*cmd: str) -> int:
    done = subprocess.run([sys.executable, *cmd], cwd=ROOT)
    return done.returncode


def main(argv: list[str]) -> int:
    scripts = [Path(a) for a in argv]
    if not scripts:
        print(__doc__)
        return 2
    missing = [s for s in scripts if not s.exists()]
    if missing:
        print("台本がありません: " + ", ".join(str(m) for m in missing), file=sys.stderr)
        return 1

    bad = 0
    print("■ 1本ずつの点検")
    for script in scripts:
        if _run("-m", "src.cli", "check", str(script)) != 0:
            bad += 1

    print("\n■ 並べて点検")
    if _run("-m", "src.cli", "variety", *map(str, scripts)) != 0:
        bad += 1

    print("\n■ 流れの点検")
    for script in scripts:
        record = ROOT / "output" / "flow" / (script.stem + ".md")
        if record.exists() and record.stat().st_mtime >= script.stat().st_mtime:
            print(f"  {script.name}: 控えあり（{record.relative_to(ROOT)}）")
            continue
        if _run("tools/flow.py", str(script)) != 0:
            bad += 1

    print("\n■ 手で見る決まり（1つずつ答えてから見せる）")
    for index, (rule, how) in enumerate(HAND_CHECKS, start=1):
        print(f"  {index}. {rule}　— {how}")
    print()
    if bad:
        print(f"■ 機械の点検で {bad} 件止まっています。直してから見せてください")
        return 1
    print("■ 機械の点検は通っています。上の表に答えてから見せてください")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
