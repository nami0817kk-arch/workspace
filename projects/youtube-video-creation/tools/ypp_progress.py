"""収益化までの道のりを1コマンドで測る（2026-09-28 収益化の整理 10）。

    python tools/ypp_progress.py            # 今日の控えを取って、進み具合と審査の目の点検を出す
    python tools/ypp_progress.py --no-fetch # 手元の控えだけで計算する

やること:
1. `tools/metrics/road.py`（登録者・動画ごとの再生）と `tools/metrics/watchtime.py`（視聴時間）を
   `research/metrics/<今日>/` に取る。Data API は road.py の分（十数ユニット）だけ
2. 条件（登録1,000人・本編4,000時間）までの残りと、いまのペースで届く日を出す。
   ペースは**前回の控えとの差**で測る（推測ではなく実測。控えが1つしか無ければ出さない）
3. `tools/ypp_audit.py` を回して、審査が重く見る所（再生上位・視聴時間上位・最新）の中身を出す

条件は公式ヘルプ（チャンネル収益化ポリシー）の「登録1,000人＋直近12か月の有効な公開動画の
総再生時間4,000時間」。ショートの視聴時間は数えられない。
"""
from __future__ import annotations

import datetime
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
METRICS = ROOT / "research" / "metrics"
SUBS_GOAL = 1000
HOURS_GOAL = 4000
JST = datetime.timezone(datetime.timedelta(hours=9))


def snapshots() -> list[Path]:
    """road.json と watch.json がそろった控えを日付順に。"""
    out = []
    for d in sorted(METRICS.glob("2*")):
        if (d / "road.json").exists() and (d / "watch.json").exists():
            out.append(d)
    return out


def main_hours(road: dict, watch: dict) -> float:
    kinds = {v["id"]: v["short"] for v in road["videos"]}
    return sum(m for vid, _, m in watch.get("rows", []) if kinds.get(vid) is False) / 60


def eta(now_value: float, goal: float, per_day: float) -> str:
    """いまの値とペースから、届く日。ペースが無ければ「測れない」。"""
    if now_value >= goal:
        return "届いている"
    if per_day <= 0:
        return "測れない（ペースが0以下）"
    days = (goal - now_value) / per_day
    when = datetime.date.today() + datetime.timedelta(days=days)
    return f"あと約{days:,.0f}日（{when.strftime('%Y年%m月%d日')}ごろ）"


def report(latest: Path, earlier: Path | None) -> list[str]:
    road = json.loads((latest / "road.json").read_text(encoding="utf-8"))
    watch = json.loads((latest / "watch.json").read_text(encoding="utf-8"))
    subs = int(road["channel"]["subs"])
    hours = main_hours(road, watch)
    lines = [f"■ 収益化までの道のり（{latest.name}）",
             f"  登録者　　　{subs:,}人 / {SUBS_GOAL:,}人（残り {max(0, SUBS_GOAL - subs):,}人）",
             f"  本編の視聴時間　{hours:,.0f}時間 / {HOURS_GOAL:,}時間（残り {max(0, HOURS_GOAL - hours):,.0f}時間）"]
    if earlier is not None:
        road0 = json.loads((earlier / "road.json").read_text(encoding="utf-8"))
        watch0 = json.loads((earlier / "watch.json").read_text(encoding="utf-8"))
        d0 = datetime.date.fromisoformat(f"{earlier.name[:4]}-{earlier.name[4:6]}-{earlier.name[6:8]}")
        d1 = datetime.date.fromisoformat(f"{latest.name[:4]}-{latest.name[4:6]}-{latest.name[6:8]}")
        days = max(1, (d1 - d0).days)
        subs_pace = (subs - int(road0["channel"]["subs"])) / days
        hours_pace = (hours - main_hours(road0, watch0)) / days
        lines += [f"  ペース（{earlier.name} から {days}日）　登録 {subs_pace:+.1f}人/日、本編 {hours_pace:+.1f}時間/日",
                  f"  登録1,000人まで　{eta(subs, SUBS_GOAL, subs_pace)}",
                  f"  本編4,000時間まで　{eta(hours, HOURS_GOAL, hours_pace)}",
                  "  ※ 視聴時間は「直近12か月」で数えるので、1年たつと古い分が抜ける"]
    else:
        lines.append("  ペース: 控えが1つしか無いので測れません（次に回したときに出ます）")
    return lines


def main(argv: list[str]) -> int:
    today = datetime.datetime.now(JST).strftime("%Y%m%d")
    target = METRICS / today
    if "--no-fetch" not in argv:
        target.mkdir(parents=True, exist_ok=True)
        for tool, args in (("tools/metrics/road.py", [str(target / "road.json")]),
                           ("tools/metrics/watchtime.py", [str(target / "watch.json"), str(target / "road.json")])):
            done = subprocess.run([sys.executable, tool, *args], cwd=ROOT, capture_output=True,
                                  text=True, encoding="utf-8", errors="replace")
            if done.returncode != 0:
                print(f"■ {tool} が失敗しました:\n{done.stdout}\n{done.stderr}")
                return 1
    snaps = snapshots()
    if not snaps:
        print("控えがありません")
        return 1
    latest = snaps[-1]
    earlier = next((s for s in reversed(snaps[:-1]) if s.name != latest.name), None)
    print("\n".join(report(latest, earlier)))
    print()
    done = subprocess.run([sys.executable, "tools/ypp_audit.py", str(latest / "road.json"), str(latest / "watch.json")],
                          cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
    tail = done.stdout.strip().splitlines()
    start = next((i for i, line in enumerate(tail) if line.startswith("## まとめ")), 0)
    print("\n".join(tail[start:]))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
