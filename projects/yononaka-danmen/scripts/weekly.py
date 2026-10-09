# -*- coding: utf-8 -*-
"""毎週土曜に、翌週1週間ぶん（7本）の題材を決める。

    python scripts/weekly.py                    # 候補を集めて点を付け、20件を番号付きで出す
    python scripts/weekly.py --fix 3,7,1,12,5,9,14   # 選んだ番号を、月〜日に割り当てて保存

割り当ての決まり:
  ・今日のニュース・はてブ由来は**週の前半**に置く（1週間で古くなるため）
  ・いつ検索されている疑問は**週の後半**に置く（いつ出しても効く）
○× を付けるのはユーザー。ここは並べて提案するところまで。
"""
from __future__ import annotations

import argparse
import json
import sys
from datetime import date, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from danmen import pick, sources  # noqa: E402

PLAN_DIR = Path("research/plan")
CAND_DIR = Path("research/candidates")
WEEKDAYS = ["月", "火", "水", "木", "金", "土", "日"]


def next_monday(today: date | None = None) -> date:
    d = today or date.today()
    return d + timedelta(days=(7 - d.weekday()) % 7 or 7)


def week_id(monday: date) -> str:
    return f"{monday.isocalendar().year}-W{monday.isocalendar().week:02d}"


def too_similar(a: str, b: str) -> bool:
    """同じ題材かどうか。2回集めると言い回し違いの重複が出るため。"""
    import re
    norm = lambda t: set(re.findall(r"[一-龥ァ-ヶーA-Za-z0-9]{2,}", re.sub(r"なぜ|どうして|のか|？|\?", "", t)))
    sa, sb = norm(a), norm(b)
    if not sa or not sb:
        return False
    return len(sa & sb) / min(len(sa), len(sb)) >= 0.6


def collect(n_rounds: int = 2) -> list[dict]:
    """1週間ぶん選ぶには候補が要るので、少し多めに集める。"""
    from danmen import judge
    from scripts.gather import rough_score  # type: ignore
    rows: list[dict] = []
    seen: set[str] = set()
    for _ in range(n_rounds):
        items = sources.gather_all()
        for it in items:
            it.score, it.hits = rough_score(it.text)
        # **枠を分けて取る。** まとめて上位を取ると、ニュースが補完に埋もれて
        # 時事が1件も残らなかった（2026-10-09。ニュース388件中42件に点が付いたのに0件）。
        # ニュースの見出しは「なぜ」と書かないので、言葉での点が低く出る。
        pos = [i for i in items if i.score > 0]
        news_like = [i for i in pos if getattr(i, "kind", "") in ("news", "hatena")]
        rest = [i for i in pos if getattr(i, "kind", "") not in ("news", "hatena")]
        rough = (sorted(news_like, key=lambda i: -i.score)[:35]
                 + sorted(rest, key=lambda i: -i.score)[:35])
        for r in judge.judge(rough):
            t = str(r.get("title") or "")
            if not t or t in seen:
                continue
            if any(too_similar(t, str(x.get("title", ""))) for x in rows):
                continue        # 言い回し違いの同じ題材
            seen.add(t)
            rows.append(r)
    return rows


def main() -> int:
    ap = argparse.ArgumentParser(description="1週間ぶんの題材を決める")
    ap.add_argument("--fix", help="選んだ番号をカンマ区切りで（7つ）")
    ap.add_argument("--from-file", help="集め直さず、この候補ファイルを使う")
    ap.add_argument("--top", type=int, default=20)
    args = ap.parse_args()

    monday = next_monday()
    wid = week_id(monday)
    cand_path = CAND_DIR / f"{wid}.json"

    if args.fix:
        rows = json.loads(cand_path.read_text(encoding="utf-8"))
        nums = [int(x) for x in args.fix.replace(" ", "").split(",")]
        if len(nums) != 7:
            raise SystemExit(f"7つ選んでください（いまは {len(nums)} つ）")
        chosen = [rows[n - 1] for n in nums]
        # 時事を前半、常在を後半へ
        def is_news(r: dict) -> bool:
            f = str(r.get("source_feed", ""))
            return bool(f) and "サジェスト" not in f and "YouTube" not in f
        chosen.sort(key=lambda r: (not is_news(r)))
        plan = {"week": wid, "monday": monday.isoformat(), "days": []}
        for i, r in enumerate(chosen):
            d = monday + timedelta(days=i)
            plan["days"].append({"date": d.isoformat(), "weekday": WEEKDAYS[i],
                                 "title": r.get("title"), "source": r.get("source"),
                                 "queries": r.get("queries", []), "why": r.get("why"),
                                 "from": r.get("source_feed"), "status": "未着手"})
        PLAN_DIR.mkdir(parents=True, exist_ok=True)
        out = PLAN_DIR / f"{wid}.json"
        out.write_text(json.dumps(plan, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"■ {wid}（{monday.month}月{monday.day}日の週）の予定を決めました\n")
        for d in plan["days"]:
            mark = "時事" if "サジェスト" not in str(d["from"]) and "YouTube" not in str(d["from"]) else "常在"
            print(f"  {d['weekday']}  {d['date'][5:]}  [{mark}] {d['title']}")
        print(f"\n控え: {out}")
        return 0

    # 候補を集めて点を付ける
    if args.from_file:
        rows = json.loads(Path(args.from_file).read_text(encoding="utf-8"))
    else:
        print("1週間ぶんの候補を集めています（2回ぶん回します）…", file=sys.stderr)
        rows = collect()
        CAND_DIR.mkdir(parents=True, exist_ok=True)
        cand_path.write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding="utf-8")

    ranked = pick.rank(rows)
    # 並べ替えた順で控え直す（--fix の番号と合わせるため）
    cand_path.write_text(json.dumps([s.row for s in ranked], ensure_ascii=False, indent=2),
                         encoding="utf-8")

    print(f"\n■ {wid}（{monday.month}月{monday.day}日の週）の候補　{len(ranked)} 件から上位 {args.top} 件\n")
    for i, s in enumerate(ranked[:args.top], 1):
        f = str(s.row.get("source_feed", ""))
        mark = "常在" if ("サジェスト" in f or "YouTube" in f) else "時事"
        print(f"{i:>2}. [{mark}] {s.row.get('title')}")
        print(f"     {s.total}/23　検索{s.breadth} 問い{s.depth} 原典{s.source} 尺{s.length} 新しさ{s.fresh}"
              f"　／ 原典: {s.row.get('source')}")
    print(f"\n7つ選んで、こう打ってください:")
    print(f"  python scripts/weekly.py --fix 1,2,3,4,5,6,7")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
