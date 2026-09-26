"""予約公開の時刻だけを変える（2026-09-24 指示「30分おきにしよう」）。

**入れ直さない。**同じ動画を上げ直すと二重投稿になるうえ、投稿の枠も食う。
YouTube の `status.publishAt` だけを更新する。

    python tools/reschedule.py output/20260920_pl04_brentford 13:20
    python tools/reschedule.py --from 12:20 --step 30 output/A output/B ...

`--from` と `--step` を渡すと、並べた順に等間隔で振り直す。
**公開済みの動画は触らない**（`publishAt` は非公開の予約にしか効かない）。
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from src import upload as upload_mod  # noqa: E402

POSTED = ROOT / "research" / "posted.json"


def video_id_of(build_dir: str) -> str:
    """その出力先で投稿した動画のID。控え（posted.json）から引く。"""
    name = Path(build_dir).name
    rows = json.loads(POSTED.read_text(encoding="utf-8"))
    for row in reversed(rows):
        if Path(str(row.get("build", ""))).name == name:
            return str(row.get("video_id") or "")
    return ""


def move(service, video_id: str, clock: str) -> str:
    """予約時刻を変える。**status は部分更新できない**ので取ってから詰め直す。"""
    got = service.videos().list(part="status", id=video_id).execute()
    items = got.get("items") or []
    if not items:
        raise SystemExit(f"見つかりません: {video_id}")
    status = dict(items[0]["status"])
    if status.get("privacyStatus") != "private":
        return "公開済み（触らない）"
    status["publishAt"] = upload_mod.when_to_publish(clock)
    status.pop("publishTime", None)
    service.videos().update(part="status",
                            body={"id": video_id, "status": status}).execute()
    _note(video_id, status["publishAt"])
    return clock


def _note(video_id: str, publish_at: str) -> None:
    """**控え（posted.json）の予約時刻も書き換える**（2026-09-26）。

    YouTube 側だけ動かしていたので、`tools/slots.py` が古い時刻を出し、
    本編とショートが同じ時刻に並んで見えた。
    """
    rows = json.loads(POSTED.read_text(encoding="utf-8"))
    for row in rows:
        if str(row.get("video_id")) == video_id:
            row["publish_at"] = publish_at
    POSTED.write_text(json.dumps(rows, ensure_ascii=False, indent=2) + "
", encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("targets", nargs="+", help="出力先（--from を使わないときは 出力先 時刻 の順）")
    ap.add_argument("--from", dest="start", help="1本目の時刻（HH:MM）")
    ap.add_argument("--step", type=int, default=30, help="間隔（分）")
    args = ap.parse_args()

    service = upload_mod.get_service()
    if args.start:
        hour, minute = (int(x) for x in args.start.split(":"))
        plan = []
        for index, build in enumerate(args.targets):
            total = hour * 60 + minute + index * args.step
            plan.append((build, f"{total // 60:02d}:{total % 60:02d}"))
    else:
        plan = list(zip(args.targets[0::2], args.targets[1::2]))

    for build, clock in plan:
        video_id = video_id_of(build)
        if not video_id:
            print(f"■ 控えにありません: {build}")
            continue
        print(f"{Path(build).name:34} {move(service, video_id, clock)}  "
              f"https://youtu.be/{video_id}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
