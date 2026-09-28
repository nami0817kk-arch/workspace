"""月間まとめ（月初のシリーズ、10月の案16）の取材メモの雛形。2026-09-28。

    python tools/monthly.py --month 2026-09 --date 2026-10-01

材料は手元にあるものを寄せ集める（新しく取りに行くのは日本人の1か月ぶんだけ）。
- 順位表: `research/standings/` のその月いちばん新しい控え（無ければ取る）
- 得点王: `research/scorers/` の同じく控え
- 日本人の1か月: `tools/japan_abroad.py` の名簿で、月の窓の出場・得点（表、main）
- 今月の出来事: `research/covered.yaml`（扱った話題の記録）からその月の見出しを雛形の頭に並べる。**3〜5本を人が選ぶ**

節は「5リーグの首位（表）→ 得点王（表）→ 日本人の1か月（表、main）→ 今月の出来事 → 見立て」。
"""

from __future__ import annotations

import argparse
import datetime
import importlib.util
import json
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from src import standings as standings_mod  # noqa: E402


def _load(name: str):
    spec = importlib.util.spec_from_file_location(name, ROOT / "tools" / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


sw = _load("standings_week")
sc = _load("scorers")
ja = _load("japan_abroad")

LEAGUES = sw.LEAGUES


def month_range(month: str) -> tuple[datetime.date, datetime.date]:
    first = datetime.date.fromisoformat(month + "-01")
    nxt = (first.replace(day=28) + datetime.timedelta(days=4)).replace(day=1)
    return first, nxt - datetime.timedelta(days=1)


def latest_snapshot(snap_dir: Path, end: datetime.date) -> dict | None:
    got = sw.previous_snapshot(end + datetime.timedelta(days=1), snap_dir)
    return got[1] if got else None


def leaders_rows(standings: dict) -> list[list[str]]:
    """リーグ・首位・勝点・2位との差。"""
    rows = []
    for league in LEAGUES:
        t = standings.get(league)
        if not t:
            continue
        first, second = t["rows"][0], t["rows"][1]
        rows.append([t["name_ja"], first["team_ja"], str(first["points"]), str(first["points"] - second["points"])])
    return rows


def scorer_rows(scorers: dict, wd: dict[str, str]) -> list[list[str]]:
    rows = []
    for league in LEAGUES:
        t = scorers.get(league)
        if not t:
            continue
        first = t["rows"][0]
        rows.append([t["name_ja"], sc.name_ja(first["name"], wd), first["team_ja"], str(first["goals"])])
    return rows


def japan_rows(month_rows: list[dict], top: int = 8) -> list[list[str]]:
    """選手・所属・試合（先発）・出場時間・得点。出た人だけ、出場時間の順。"""
    out = []
    for r in sorted(month_rows, key=lambda x: -x["week"]["minutes"]):
        w = r["week"]
        if not w["games"]:
            continue
        out.append([r["name"], r["club"], f"{w['played']}試合（先発{w['starts']}）", f"{w['minutes']}分", f"{w['goals']}G {w['assists']}A"])
        if len(out) >= top:
            break
    return out


def covered_in(month: str, path: Path = ROOT / "research" / "covered.yaml") -> list[dict]:
    try:
        items = (yaml.safe_load(path.read_text(encoding="utf-8")) or {}).get("covered") or []
    except OSError:
        return []
    return [it for it in items if str(it.get("at", "")).startswith(month)]


def write_note(month: str, day: datetime.date, standings: dict, scorers: dict, wd: dict[str, str],
               japan: list[dict], topics: list[dict], path: Path) -> None:
    first, last = month_range(month)
    label = f"{first.year}年{first.month}月"
    jrows = japan_rows(japan)
    best = jrows[0] if jrows else None
    fotmob = [standings_mod.FOTMOB_LEAGUE.format(id=standings_mod.LEAGUE_IDS[lg]) for lg in LEAGUES[:2]]
    sections = [
        {"id": "leaders", "heading": f"{first.month}月を終えた首位", "tier": "確定", "official": True,
         "telop": f"{label}末の首位", "narrator": "キャスター",
         "card": {"type": "table", "title": f"{label}末 5リーグの首位", "columns": ["リーグ", "首位", "勝点", "2位との差"],
                  "rows": leaders_rows(standings), "source": "FotMob"},
         "say": [f"{label}を終えて、5大リーグの首位はこの5クラブです。",
                 "（表の上から、差の大きいところと並んでいるところを1つずつ）"],
         "sources": [standings_mod.OFFICIAL_TABLES.get(lg, "") for lg in LEAGUES if standings_mod.OFFICIAL_TABLES.get(lg)]},
        {"id": "scorers", "heading": "得点王レースの先頭", "tier": "確定", "official": True,
         "telop": f"{label}末の得点ランキング首位", "narrator": "キャスター",
         "card": {"type": "table", "title": f"{label}末 得点ランキングの首位", "columns": ["リーグ", "選手", "クラブ", "得点"],
                  "rows": scorer_rows(scorers, wd), "source": "FotMob"},
         "say": ["得点ランキングの先頭も並べます。", "（いちばん点を取っている人と、PKや試合数の違いを1つ）"],
         "sources": [u.replace("/table", "/stats") for u in fotmob]},
        {"id": "japan", "heading": f"日本人の{first.month}月", "tier": "報道", "main": True,
         "telop": f"{label}の欧州組", "narrator": "解説",
         "card": {"type": "table", "title": f"{label} 欧州組の出場と得点", "columns": ["選手", "所属", "試合", "出場時間", "得点"],
                  "rows": jrows, "source": "Transfermarkt"},
         "say": [{"text": f"（前置き1行：{first.month}月の欧州組、いちばん出たのは●●）", "short_only": True},
                 (f"{first.month}月にいちばん長く出たのは{best[0]}、{best[3]}。" if best else "（出場時間の1位）"),
                 "（表の上から3〜5人を、数字で）"],
         "sources": ["https://www.transfermarkt.jp/"]},
        {"id": "events", "heading": f"{first.month}月の出来事", "tier": "報道", "telop": f"{label}に起きたこと", "narrator": "解説",
         "say": ["（雛形の頭の一覧から3〜5本を選び、1本1〜2行で。日付とクラブ名を入れる）"],
         "sources": [str(t.get("sources", [""])[0]) for t in topics[:3] if t.get("sources")] or ["https://www.transfermarkt.jp/"]},
        {"id": "view", "heading": "見立て", "tier": "背景", "viewpoint": True, "narrator": "解説", "telop": f"{first.month + 1 if first.month < 12 else 1}月に見るところ",
         "say": [f"（{label}の数字を並べて分かったこと・来月どこを見るか）"],
         "sources": fotmob[:1]},
    ]
    note = {
        "date": day.strftime("%Y年%m月%d日"), "slot": "other_1", "format": "news", "series": "月間まとめ",
        # 5リーグと日本人をまとめて見る回なので主役は置かない（置くと他の節が「主役の名前が出ない」で鳴る）
        "people": [],
        "theme": {"id": f"monthly_{month.replace('-', '')}", "league": "england", "league_name": "欧州5大リーグ", "kind": "other",
                  "topic": "日本代表",
                  # 題は言い切らない。頭に人名（いちばん出た日本人）を置き、問いの形で終える
                  "title": (f"{best[0]}と、" if best else "") + f"5大リーグの{first.month}月。数字で振り返ると何が見えるか",
                  "question": f"{label}の欧州サッカーは、順位・得点・日本人の数字でどう見えるのか",
                  "takeaway": "（1か月の数字を並べて分かったことを1文で）"},
        "short_title": f"{first.month}月の欧州サッカーを数字で",
        "thumbnail": {"line1": f"{first.month}月の欧州サッカー", "line2": f"{best[0] if best else '●●'}が●●", "tags": ["月間まとめ"], "photos": []},
        "sections": sections,
    }
    head = [f"# {label}の月間まとめ（{first.isoformat()}〜{last.isoformat()}）。順位と得点は FotMob の控え、日本人は Transfermarkt。",
            f"# {first.month}月に扱った話題（{len(topics)}本）。3〜5本を選んで events の節に書く:"]
    # draft のたびに記録されるので数が多い（9月は505本）。同じ見出しは1回、リーグごとに新しい順で12本まで
    seen: set[str] = set()
    per_league: dict[str, int] = {}
    for t in sorted(topics, key=lambda x: str(x.get("at", "")), reverse=True):
        head_line, league = str(t.get("headline", "")), str(t.get("league", "") or "other")
        if head_line in seen or per_league.get(league, 0) >= 12:
            continue
        seen.add(head_line)
        per_league[league] = per_league.get(league, 0) + 1
        head.append(f"#   {str(t.get('at', ''))[5:10]} [{league}] {head_line}")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(head) + "\n" + yaml.safe_dump(note, allow_unicode=True, sort_keys=False, width=100), encoding="utf-8")


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--month", required=True, help="YYYY-MM")
    ap.add_argument("--date", default=datetime.date.today().isoformat())
    ap.add_argument("--no-japan", action="store_true", help="日本人の1か月を取りに行かない")
    args = ap.parse_args(argv)
    day = datetime.date.fromisoformat(args.date)
    first, last = month_range(args.month)
    standings = latest_snapshot(sw.SNAP_DIR, last)
    if not standings:
        standings = sw.snapshot([standings_mod.fetch(lg) for lg in LEAGUES])
    scorers = latest_snapshot(sc.SNAP_DIR, last)
    if not scorers:
        scorers = sc.snapshot()
    wd = sc.wikidata_names([t["rows"][0]["name"] for t in scorers.values()])
    japan = []
    if not args.no_japan:
        roster = (yaml.safe_load(ja.ROSTER.read_text(encoding="utf-8")) or {}).get("players") or []
        japan = ja.week_rows(roster, last, days=(last - first).days + 1, national=True)
    topics = covered_in(args.month)
    path = ROOT / "research" / f"{day.strftime('%Y%m%d')}_monthly.yaml"
    write_note(args.month, day, standings, scorers, wd, japan, topics, path)
    print(f"取材メモ → {path}")
    for row in leaders_rows(standings):
        print("   " + "  ".join(row))
    for row in japan_rows(japan):
        print("   " + "  ".join(row))
    print(f"扱った話題: {len(topics)}本")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
