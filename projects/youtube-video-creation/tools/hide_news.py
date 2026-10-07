"""収益化の審査の前に、ニュースの動画をまとめて非公開にする（2026-10-07 決定）。

ニュースの動画は宣伝（登録者を集める）に使い、審査の前に引っ込める運用にした。
審査は再生の多い動画を重く見るが、再生上位にニュースの反応読み上げ型が残っていて、
そこで落ちる恐れが高いため。

    python tools/hide_news.py               # 何を引っ込めるかを並べるだけ（既定）
    python tools/hide_news.py --hours       # 残る側・引っ込める側の視聴時間も出す
    python tools/hide_news.py --apply       # 非公開にする（控えは research/hidden.json）
    python tools/hide_news.py --restore     # 控えにあるものを元の公開状態に戻す

**残すのはシリーズだけ**（台本の front matter に `series:` があるもの。
クラブ紹介・クラブ同士の比較など）。`format:` では分けない。シリーズの回も
`format: news` になっているため。ショート（`_short` / `_tiktok`）は元の台本で決める。

- **削除はしない。**非公開にするだけ。戻せるように、変える前の状態を控えに残す
- 非公開・限定公開・削除した動画の視聴時間は、収益化の条件に数えられない
  （support.google.com/youtube/answer/72851）。引っ込めた分の時間は消える
- 台本が見つからない動画は、シリーズと確かめられないので引っ込める側に入れ、一覧で分けて見せる。
  残したいものは `--keep <video_id>` で外す
"""
from __future__ import annotations

import argparse
import datetime
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

POSTED = ROOT / "research" / "posted.json"
HIDDEN = ROOT / "research" / "hidden.json"
SCRIPTS = ROOT / "scripts"

_SUFFIX = re.compile(r"_(short|tiktok)$")
_FRONT = re.compile(r"\A---\n(.*?)\n---\n", re.S)


def base_build(build: str) -> str:
    """ショートの出力先名から、元の台本の名前を出す。"""
    return _SUFFIX.sub("", Path(str(build)).name)


def front_matter(build: str, scripts: Path | None = None) -> dict | None:
    """台本の front matter。台本が無ければ None、読めなければ空の dict。"""
    path = (scripts or SCRIPTS) / f"{base_build(build)}.md"
    if not path.exists():
        return None
    import yaml

    match = _FRONT.match(path.read_text(encoding="utf-8").replace("\r\n", "\n"))
    if not match:
        return {}
    try:
        return yaml.safe_load(match.group(1)) or {}
    except yaml.YAMLError:
        return {}


def classify(build: str, scripts: Path | None = None) -> str:
    """"keep"（シリーズ）／"hide"（ニュース）／"noscript"（台本なし＝引っ込める側）。"""
    fm = front_matter(build, scripts)
    if fm is None:
        return "noscript"
    return "keep" if fm.get("series") else "hide"


def plan(rows: list[dict], scripts: Path | None = None, keep: set[str] = frozenset()) -> dict[str, list[dict]]:
    """控えの1行ずつを3つに分ける。同じ動画が二重に控えてあれば1つにまとめる。"""
    out: dict[str, list[dict]] = {"keep": [], "hide": [], "noscript": []}
    seen: set[str] = set()
    for row in rows:
        vid = str(row.get("video_id") or "")
        if not vid or vid in seen:
            continue
        seen.add(vid)
        kind = "keep" if vid in keep else classify(str(row.get("build", "")), scripts)
        out[kind].append({"video_id": vid, "build": base_build(row.get("build", "")),
                          "short": bool(_SUFFIX.search(Path(str(row.get("build", ""))).name))})
    return out


def _statuses(service, ids: list[str]) -> dict[str, dict]:
    got: dict[str, dict] = {}
    for i in range(0, len(ids), 50):
        res = service.videos().list(part="status", id=",".join(ids[i:i + 50])).execute()
        for item in res.get("items") or []:
            got[item["id"]] = dict(item["status"])
    return got


def _set_privacy(service, video_id: str, status: dict, privacy: str) -> None:
    """**status は部分更新できない**ので、取った status を詰め直して送る。"""
    body = dict(status)
    body["privacyStatus"] = privacy
    body.pop("publishAt", None)       # 予約は外す（予約が残ると勝手に公開される）
    body.pop("publishTime", None)
    service.videos().update(part="status", body={"id": video_id, "status": body}).execute()


def _hours(ids: list[str]) -> float:
    """本編の視聴時間（9/1〜今日）。ショートの時間は条件に入らないので、渡すのは本編だけ。"""
    if not ids:
        return 0.0
    from src import insights

    api = insights.service()
    today = datetime.date.today().isoformat()
    minutes = 0.0
    # video の次元で一覧にすると上位200本で切られる。filters で全件を足し上げる
    for i in range(0, len(ids), 200):
        res = api.reports().query(ids="channel==MINE", startDate="2026-09-01", endDate=today,
                                  metrics="estimatedMinutesWatched",
                                  filters="video==" + ",".join(ids[i:i + 200])).execute()
        minutes += sum(r[0] for r in res.get("rows") or [])
    return minutes / 60


def _future(stamp: str) -> bool:
    when = datetime.datetime.fromisoformat(stamp.replace("Z", "+00:00"))
    return when > datetime.datetime.now(datetime.timezone.utc)


def _load_hidden() -> list[dict]:
    return json.loads(HIDDEN.read_text(encoding="utf-8")) if HIDDEN.exists() else []


def _save_hidden(rows: list[dict]) -> None:
    HIDDEN.write_text(json.dumps(rows, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def show(groups: dict[str, list[dict]], hours: bool) -> None:
    label = {"keep": "残す（シリーズ）", "hide": "引っ込める（ニュース）",
             "noscript": "引っ込める（台本が見つからない）"}
    for kind in ("keep", "hide", "noscript"):
        items = groups[kind]
        mains = [x for x in items if not x["short"]]
        line = f"{label[kind]:22} 本編 {len(mains):4} 本 / ショート {len(items) - len(mains):4} 本"
        if hours:
            line += f" / 本編の視聴時間 {_hours([x['video_id'] for x in mains]):8.1f} 時間"
        print(line)
    print()
    for x in groups["noscript"]:
        print(f"  台本なし  {x['build']:40} https://youtu.be/{x['video_id']}")


def apply(service, groups: dict[str, list[dict]]) -> int:
    targets = groups["hide"] + groups["noscript"]
    status = _statuses(service, [x["video_id"] for x in targets])
    hidden = _load_hidden()
    done = {h["video_id"] for h in hidden}
    count = 0
    for x in targets:
        st = status.get(x["video_id"])
        if st is None:
            print(f"  見つからない（削除済み？） {x['build']}")
            continue
        if st.get("privacyStatus") == "private" and not st.get("publishAt"):
            continue                  # もう非公開
        _set_privacy(service, x["video_id"], st, "private")
        if x["video_id"] not in done:
            hidden.append({"video_id": x["video_id"], "build": x["build"], "short": x["short"],
                           "was": st.get("privacyStatus"), "publish_at": st.get("publishAt"),
                           "at": datetime.datetime.now().astimezone().isoformat(timespec="seconds")})
        _save_hidden(hidden)          # 1本ごとに残す。途中で止まっても戻せるように
        count += 1
        print(f"  非公開にした  {x['build']}")
    return count


def restore(service) -> int:
    hidden = _load_hidden()
    status = _statuses(service, [h["video_id"] for h in hidden])
    count = 0
    for h in hidden:
        st = status.get(h["video_id"])
        if st is None:
            continue
        if h.get("publish_at") and _future(h["publish_at"]):   # 予約の途中だったものは予約に戻す
            body = dict(st)
            body["privacyStatus"] = "private"
            body["publishAt"] = h["publish_at"]
            service.videos().update(part="status", body={"id": h["video_id"], "status": body}).execute()
        else:
            # 予約の時刻が過ぎていたら、そのまま公開に戻す
            was = "public" if h.get("publish_at") else (h.get("was") or "public")
            _set_privacy(service, h["video_id"], st, was)
        count += 1
        print(f"  戻した  {h['build']}")
    return count


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--apply", action="store_true", help="非公開にする（無ければ並べるだけ）")
    ap.add_argument("--restore", action="store_true", help="控えにあるものを元に戻す")
    ap.add_argument("--hours", action="store_true", help="本編の視聴時間も出す")
    ap.add_argument("--keep", action="append", default=[], metavar="VIDEO_ID", help="残す動画（何度でも）")
    args = ap.parse_args(argv)

    if args.restore:
        from src import upload as upload_mod

        print(f"戻した: {restore(upload_mod.get_service())} 本")
        return 0

    rows = json.loads(POSTED.read_text(encoding="utf-8"))
    groups = plan(rows, keep=set(args.keep))
    show(groups, args.hours)
    if not args.apply:
        print("\n（並べただけ。非公開にするには --apply）")
        return 0
    from src import upload as upload_mod

    print(f"\n非公開にした: {apply(upload_mod.get_service(), groups)} 本（控え: {HIDDEN.relative_to(ROOT)}）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
