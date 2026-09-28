"""収益化の審査の目でチャンネルを点検する（2026-09-28 ユーザー決定「収益化することが目的」）。

審査は「再生回数の多い動画・総再生時間の多い部分・最新の動画」を重く見る（公式ヘルプ）。
そこに「他人の声（発言＋ネットの反応）が半分以上」の動画が集まっていないかを数える。
9/28 の初回は、本編の視聴時間の 66% がそういう動画から来ていた。

    python tools/metrics/road.py research/metrics/<日付>/road.json
    python tools/metrics/watchtime.py research/metrics/<日付>/watch.json research/metrics/<日付>/road.json
    python tools/ypp_audit.py research/metrics/<日付>/road.json research/metrics/<日付>/watch.json

月に1回回して、新しい形の本が上位に入れ替わってきたかを見る。
"""
from __future__ import annotations

import collections
import json
import os
import sys
from pathlib import Path

sys.path.insert(0, ".")

NARRATORS = {"キャスター", "解説", "ナレーター"}
CROWD = {"ネット民", "現地サポ", "海外のファン"}


def mix(build: str) -> tuple[dict, int] | None:
    """書き出した script.json から、語り・発言・反応の秒数の割合。"""
    path = Path("output") / build / "script.json"
    if not path.exists():
        return None
    data = json.loads(path.read_text(encoding="utf-8"))
    secs: collections.Counter = collections.Counter()
    for scene in data.get("scenes", []):
        for line in scene.get("lines", []):
            who = line.get("speaker") or ""
            kind = "narr" if who in NARRATORS else ("crowd" if who in CROWD else "quote")
            secs[kind] += line.get("duration") or 0
    total = sum(secs.values()) or 1
    return {k: round(100 * secs[k] / total) for k in ("narr", "quote", "crowd")}, round(total)


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__)
        return 2
    road = json.loads(Path(argv[0]).read_text(encoding="utf-8"))
    watch = json.loads(Path(argv[1]).read_text(encoding="utf-8"))
    posted = json.loads(Path("research/posted.json").read_text(encoding="utf-8"))
    build_of = {row["video_id"]: row["build"] for row in posted}
    minutes = {vid: m for vid, _, m in watch.get("rows", [])}

    rows = []
    for v in road["videos"]:
        if v.get("privacy") != "public":
            continue
        got = mix(build_of.get(v["id"], ""))
        rows.append(dict(v, mins=round(minutes.get(v["id"], 0)), mix=got[0] if got else None))

    def others(r) -> int:
        return (r["mix"]["quote"] + r["mix"]["crowd"]) if r["mix"] else -1

    def show(title, rs):
        print(f"## {title}")
        for r in rs:
            m = r["mix"]
            tag = f"他人の声{others(r):3d}%" if m else "控え無し    "
            print(f"  {r['views']:6d}回 {r['mins']:5d}分 {'S' if r['short'] else 'M'} {tag}  {r['title'][:36]}")

    show("再生上位20", sorted(rows, key=lambda r: -r["views"])[:20])
    show("視聴時間上位15", sorted(rows, key=lambda r: -r["mins"])[:15])
    show("最新20", sorted(rows, key=lambda r: r["at"], reverse=True)[:20])

    mains = [r for r in rows if not r["short"]]
    total = sum(r["mins"] for r in mains) or 1
    heavy = [r for r in mains if others(r) >= 50]
    print("## まとめ")
    print(f"  本編 {len(mains)}本のうち、他人の声が半分以上: {len(heavy)}本")
    print(f"  本編の視聴時間のうち、その動画が占める割合: {100 * sum(r['mins'] for r in heavy) // total}%")
    per_day = collections.Counter(r["at"][:10] for r in rows)
    recent = sorted(per_day.items())[-14:]
    print(f"  1日の公開本数（直近14日）: 中央値 {sorted(c for _, c in recent)[len(recent) // 2]}本、最大 {max(c for _, c in recent)}本")
    src: collections.Counter = collections.Counter()
    for f in Path("assets/images").glob("*/credits.json"):
        try:
            rows_c = json.loads(f.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            continue
        for row in (rows_c if isinstance(rows_c, list) else [rows_c]):
            s = str(row.get("source", "?"))
            src["press" if s == "press" else ("commons" if "wikimedia" in s.lower() or "commons" in s.lower() else "other")] += 1
    print(f"  写真の出どころ: 報道 {src['press']} / Commons {src['commons']} / その他 {src['other']}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
