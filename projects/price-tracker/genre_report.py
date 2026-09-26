#!/usr/bin/env python3
"""ジャンルごとに「価格が動くか」を自分の記録から数える。通信しない。

どのジャンルを厚く追うかは、報酬額でも件数でもなく実際の値動きで決める。
値動きは履歴でしか測れないので、explore.py（楽天に問い合わせる調査）では
出せない。ここは data/ にためた記録だけを読む。

    python genre_report.py

記録が7日に満たないジャンルは「判定不可」と出す。追加した翌日に0%と出るのは
動かないからではなく、比べる相手がまだ無いからで、それを見て切ると
中身を見ずに捨てることになる（2026-09-26 に実際にそう見えた）。
"""
import argparse
import collections
import statistics
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))

from src import analyze, store  # noqa: E402

# 動いたかどうかを言うのに要る日数。最安値の判定と同じ基準にそろえる。
MIN_DAYS = analyze.MIN_DAYS_FOR_LOW


def collect(root: Path) -> list[dict]:
    site = store.load_json(root / "config.json", {})
    rows = analyze.evaluate_all(
        store.load_json(root / "data" / "summary.json", {}),
        store.load_json(root / "data" / "items.json", {}),
        site.get("drop_threshold", 0.05), site.get("near_low_threshold", 0.02))
    names = {str(g["genre_id"]): g.get("name", "") for g in site.get("genres", [])
             if isinstance(g, dict)}
    hits = {str(g["genre_id"]): g.get("hits", site.get("hits_per_genre", 0))
            for g in site.get("genres", []) if isinstance(g, dict)}

    grouped = collections.defaultdict(list)
    for row in rows:
        grouped[str(row.get("source_genre") or "")].append(row)

    out = []
    for gid, items in grouped.items():
        if not gid or gid not in names:
            continue   # 追跡をやめたジャンルの残り。判断には使わない
        changes = [analyze.change_count(r) for r in items]
        days = max((r.get("days") or 0) for r in items)
        rates = [int(r.get("point_rate") or 1) for r in items]
        out.append({
            "genre_id": gid, "name": names[gid], "hits": hits.get(gid, 0),
            "items": len(items), "days": days,
            "judgeable": days >= MIN_DAYS,
            "moved": sum(1 for c in changes if c >= 1) / len(items),
            "twice": sum(1 for c in changes if c >= 2) / len(items),
            "pointed": sum(1 for x in rates if x > 1) / len(items),
            "ending": sum(1 for r in items
                          if (r.get("point_until") or "").strip()) / len(items),
            "median_price": statistics.median([r["price"] for r in items]),
        })
    return sorted(out, key=lambda r: (-r["judgeable"], -r["moved"]))


def render(report: list[dict]) -> str:
    head = (f'{"ジャンル":22}{"取得":>7}{"記録":>6}{"動いた":>8}'
            f'{"2回以上":>8}{"倍率>1":>8}{"期限付き":>8}{"中央価格":>10}')
    lines = [head, "-" * len(head)]
    for r in report:
        if r["judgeable"]:
            moved = f'{r["moved"] * 100:6.1f}%'
            twice = f'{r["twice"] * 100:6.1f}%'
        else:
            moved = twice = "   ---"
        lines.append(
            f'{r["name"][:20]:22}{r["hits"]:6,}{r["days"]:5}日{moved:>8}{twice:>8}'
            f'{r["pointed"] * 100:7.1f}%{r["ending"] * 100:7.1f}%'
            f'{r["median_price"]:9,.0f}円')
    waiting = [r for r in report if not r["judgeable"]]
    if waiting:
        lines.append("")
        lines.append(f'記録が{MIN_DAYS}日に満たないジャンルは "---"。'
                     f'あと{max(MIN_DAYS - r["days"] for r in waiting)}日で判定できる:')
        lines.append("  " + " / ".join(f'{r["name"]}（{r["days"]}日）' for r in waiting))
    return "\n".join(lines)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=str(ROOT))
    args = parser.parse_args(argv)
    report = collect(Path(args.root))
    if not report:
        print("記録がありません。fetch.py を動かしてからにしてください。")
        return 1
    print(render(report))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
