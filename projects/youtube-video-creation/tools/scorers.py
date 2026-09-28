"""5大リーグの得点王レース（木曜のシリーズ、10月の案5・11）。2026-09-28。

    python tools/scorers.py --date 2026-10-01            # 5リーグの得点ランキングを控えて、雛形と板を書く
    python tools/scorers.py --date 2026-10-01 --no-fetch # その日の控えから作り直す

材料は FotMob のリーグ統計（`stats/<リーグ>/season/<季>/goals.json`。公開ドキュメントの無い内部API）。
1人ぶんに得点・PKの内訳・試合数・出場時間が入っているので、**得点の数だけでなく「PK抜き」と
「90分あたり」を並べる**（数字を自分で数えて比べる、が10月の型）。控え（`research/scorers/<日付>.json`）を
前の週と比べて、順位の動きと「今週の1つ」の候補を出す。**選ぶのは人。**

選手名の日本語は `research/*/kana.json` → `research/kana/players.json` → Wikidata（英語名で引き、
`research/kana/wikidata_by_name.json` に控える）。残った英語名は雛形の頭に出る。
"""

from __future__ import annotations

import argparse
import datetime
import importlib.util
import json
import sys
import time
from pathlib import Path

import requests
import yaml

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from src import standings as standings_mod  # noqa: E402

_spec = importlib.util.spec_from_file_location("match_numbers", ROOT / "tools" / "match_numbers.py")
mn = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(mn)

LEAGUES = ["england", "spain", "germany", "italy", "france"]
SNAP_DIR = ROOT / "research" / "scorers"
BOARD_DIR = ROOT / "assets" / "stats"
WIKIDATA = "https://query.wikidata.org/sparql"
WD_CACHE = ROOT / "research" / "kana" / "wikidata_by_name.json"
TOP = 5


def fetch_league(league: str) -> list[dict]:
    """1リーグの得点ランキング（上から順）。"""
    payload = requests.get(f"{standings_mod.BASE}/leagues", params={"id": standings_mod.LEAGUE_IDS[league]},
                           headers={"User-Agent": standings_mod.UA}, timeout=standings_mod.TIMEOUT).json()
    entry = next((p for p in ((payload.get("stats") or {}).get("players") or []) if p.get("header") == "Top scorer"), None)
    if not entry:
        raise standings_mod.StandingsError(f"得点ランキングが見つかりません（{league}）。FotMob の作りが変わった可能性があります")
    full = requests.get(entry["fetchAllUrl"], headers={"User-Agent": standings_mod.UA}, timeout=standings_mod.TIMEOUT).json()
    lists = full.get("TopLists") or []
    rows = []
    for item in (lists[0].get("StatList") if lists else []) or []:
        rows.append(dict(rank=int(item.get("Rank") or 0), name=str(item.get("ParticipantName") or ""),
                         team=str(item.get("TeamName") or ""), team_ja=standings_mod.japanese(str(item.get("TeamName") or "")),
                         goals=int(item.get("StatValue") or 0), penalties=int(item.get("SubStatValue") or 0),
                         minutes=int(item.get("MinutesPlayed") or 0), games=int(item.get("MatchesPlayed") or 0),
                         country=str(item.get("ParticipantCountryCode") or "")))
    if not rows:
        raise standings_mod.StandingsError(f"得点ランキングが空です（{league}）")
    return rows


def snapshot() -> dict:
    out = {}
    for league in LEAGUES:
        out[league] = {"name_ja": standings_mod.LEAGUE_NAMES_JA[league], "rows": fetch_league(league)}
        time.sleep(0.5)
    return out


def previous_snapshot(day: datetime.date, snap_dir: Path = SNAP_DIR):
    best = None
    for path in sorted(snap_dir.glob("*.json")) if snap_dir.exists() else []:
        try:
            when = datetime.date.fromisoformat(path.stem)
        except ValueError:
            continue
        if when < day and (best is None or when > best[0]):
            best = (when, path)
    return (best[0], json.loads(best[1].read_text(encoding="utf-8"))) if best else None


def wikidata_names(names: list[str]) -> dict[str, str]:
    """英語名 → 日本語名。Wikidata を職業=サッカー選手で引き、控えに残す。"""
    try:
        cache = json.loads(WD_CACHE.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        cache = {}
    todo = [n for n in names if n and n not in cache]
    for at in range(0, len(todo), 50):
        chunk = " ".join('"' + n.replace('"', "") + '"@en' for n in todo[at:at + 50])
        query = ('SELECT ?en ?ja WHERE { VALUES ?en { ' + chunk + ' } ?p rdfs:label ?en ; wdt:P106 wd:Q937857 ; '
                 'rdfs:label ?ja FILTER(lang(?ja)="ja") }')
        try:
            got = requests.get(WIKIDATA, params={"query": query, "format": "json"},
                               headers={"User-Agent": "yt-video-creation/1.0 (research)"}, timeout=60)
            found = {}
            for b in got.json().get("results", {}).get("bindings", []):
                found.setdefault(b["en"]["value"], b["ja"]["value"])
            for n in todo[at:at + 50]:
                cache[n] = found.get(n, "")
        except (requests.RequestException, ValueError):
            pass
        time.sleep(1)
    WD_CACHE.parent.mkdir(parents=True, exist_ok=True)
    WD_CACHE.write_text(json.dumps(cache, ensure_ascii=False, indent=1, sort_keys=True), encoding="utf-8")
    return cache


def name_ja(name: str, wd: dict[str, str]) -> str:
    """辞書 → 上書き → Wikidata の順。無ければ英語のまま。"""
    got = mn.kana(name)
    if got != name:
        return got
    return wd.get(name) or name


def per90(row: dict) -> float:
    return row["goals"] * 90 / row["minutes"] if row["minutes"] else 0.0


def table_rows(rows: list[dict], wd: dict[str, str], previous_rows: list[dict] | None, top: int = TOP) -> list[list[str]]:
    """順位・選手・クラブ・得点（PK）・先週比。"""
    before = {r["name"]: r["rank"] for r in previous_rows or []}
    out = []
    for r in rows[:top]:
        goals = f"{r['goals']}" + (f"（PK{r['penalties']}）" if r["penalties"] else "")
        if previous_rows is None:
            move = "―"
        elif r["name"] not in before:
            move = "new"
        else:
            d = before[r["name"]] - r["rank"]
            move = f"↑{d}" if d > 0 else f"↓{-d}" if d < 0 else "→"
        out.append([str(r["rank"]), name_ja(r["name"], wd), r["team_ja"], goals, move])
    return out


LEAD_LINES = [
    lambda n, r, g2: f"首位は{n}、{r['games']}試合で{r['goals']}得点。2位とは{r['goals'] - g2}点差です。",
    lambda n, r, g2: f"{n}が{r['goals']}点でトップ。{r['games']}試合での数字で、2位に{r['goals'] - g2}点差。",
    lambda n, r, g2: f"いちばん上は{n}の{r['goals']}点。2位が{g2}点なので、差は{r['goals'] - g2}。",
    lambda n, r, g2: f"{r['goals']}点で{n}がトップに立っています。2位との差は{r['goals'] - g2}点。",
    lambda n, r, g2: f"トップは{n}で{r['goals']}点、{r['games']}試合。2番手は{g2}点です。",
]
TIE_LINES = [
    lambda n, r, g2: f"首位は{n}、{r['games']}試合で{r['goals']}得点。2位と並んでいます。",
    lambda n, r, g2: f"{n}が{r['goals']}点でトップ。ただし2位も同じ{g2}点です。",
    lambda n, r, g2: f"いちばん上は{n}の{r['goals']}点。2位も{g2}点で並びます。",
    lambda n, r, g2: f"{r['goals']}点で{n}がトップですが、2位と同じ数字です。",
    lambda n, r, g2: f"トップは{n}で{r['goals']}点。2番手も{g2}点で並んでいます。",
]


def say_league(league_ja: str, rows: list[dict], wd: dict[str, str], index: int) -> list[str]:
    first, second = rows[0], rows[1] if len(rows) > 1 else rows[0]
    n = name_ja(first["name"], wd)
    pool = LEAD_LINES if first["goals"] != second["goals"] else TIE_LINES
    intros = [f"{league_ja}の得点ランキングです。", f"続いて{league_ja}。", f"{league_ja}はこちら。", f"{league_ja}に移ります。", f"最後は{league_ja}。"]
    lines = [intros[index % len(intros)], pool[index % len(pool)](n, first, second["goals"])]
    if first["penalties"]:
        lines.append(f"{first['goals']}点のうちPKが{first['penalties']}本。PKを抜くと{first['goals'] - first['penalties']}点です。")
    return lines


def candidates(current: dict, previous: dict | None, wd: dict[str, str] | None = None) -> list[dict]:
    wd = wd or {}
    ja = lambda n: name_ja(n, wd)  # noqa: E731
    out = []
    for league, table in current.items():
        rows = table["rows"]
        name = table["name_ja"]
        first = rows[0]
        before = ((previous or {}).get(league) or {}).get("rows") or []
        if before and before[0]["name"] != first["name"]:
            out.append(dict(league=league, kind="首位交代", score=10, name=first["name"],
                            text=f"{name}：得点王レースの首位が{ja(before[0]['name'])}から{ja(first['name'])}に"))
        gap = first["goals"] - (rows[1]["goals"] if len(rows) > 1 else 0)
        if gap >= 3:
            out.append(dict(league=league, kind="独走", score=4 + gap, name=first["name"],
                            text=f"{name}：{ja(first['name'])}が2位に{gap}点差"))
        # 90分あたりがいちばん高い人（上位10人、270分以上）
        eligible = [r for r in rows[:10] if r["minutes"] >= 270]
        if eligible:
            best = max(eligible, key=per90)
            if best["rank"] != 1 and per90(best) > per90(first):
                out.append(dict(league=league, kind="効率", score=5, name=best["name"],
                                text=f"{name}：90分あたりは{ja(best['name'])}（{per90(best):.2f}）が首位の{ja(first['name'])}（{per90(first):.2f}）より上"))
        heavy = [r for r in rows[:5] if r["goals"] >= 4 and r["penalties"] * 2 >= r["goals"]]
        for r in heavy:
            out.append(dict(league=league, kind="PK頼み", score=4, name=r["name"],
                            text=f"{name}：{ja(r['name'])}は{r['goals']}点のうちPKが{r['penalties']}本"))
        newcomers = [r for r in rows[:5] if before and r["name"] not in {b["name"] for b in before[:5]}]
        for r in newcomers:
            out.append(dict(league=league, kind="急浮上", score=6, name=r["name"],
                            text=f"{name}：{ja(r['name'])}が5位以内に入ってきた（{r['goals']}点）"))
        # 日本人が上位にいれば、それだけで1本になる（登録者を増やす柱は日本人。9/28 の整理1）
        for r in rows[:5]:
            if r.get("country") == "JPN":
                out.append(dict(league=league, kind="日本人", score=8, name=r["name"],
                                text=f"{name}：{ja(r['name'])}が{r['rank']}位（{r['goals']}点、{r['games']}試合）"))
    return sorted(out, key=lambda c: -c["score"])


def write_note(current: dict, previous: dict | None, day: datetime.date, path: Path, wd: dict[str, str],
               board: Path | None = None, top: int = TOP) -> list[str]:
    picks = candidates(current, previous, wd)
    lead = picks[0]["league"] if picks else LEAGUES[0]
    sections = []
    unknown: list[str] = []
    for i, league in enumerate(LEAGUES):
        table = current[league]
        prev_rows = ((previous or {}).get(league) or {}).get("rows") if previous else None
        rows = table_rows(table["rows"], wd, prev_rows, top)
        unknown += [r["name"] for r in table["rows"][:top] if name_ja(r["name"], wd) == r["name"]]
        fotmob = standings_mod.FOTMOB_LEAGUE.format(id=standings_mod.LEAGUE_IDS[league]).replace("/table", "/stats")
        sections.append({
            "id": league, "heading": f"{table['name_ja']}の得点王レース", "tier": "確定", "official": True,
            "telop": f"{table['name_ja']} 得点ランキング", "narrator": "キャスター",
            "card": {"type": "table", "title": f"{table['name_ja']} 得点ランキング", "columns": ["順位", "選手", "クラブ", "得点", "先週比"],
                     "rows": rows, "source": "FotMob"},
            "say": say_league(table["name_ja"], table["rows"], wd, i),
            "sources": [standings_mod.OFFICIAL_TABLES.get(league, ""), fotmob],
        })
    sections.append({
        "id": "pick", "heading": "今週の1つ", "tier": "確定", "official": True, "main": True, "telop": "今週の1つ", "narrator": "解説",
        "say": [{"text": "（前置き1行：5大リーグの得点王レースから、今週は●●の話）", "short_only": True},
                "（候補から1つ選んで、PK抜き・90分あたり・試合数で掘る。3〜6行。表かグラフを1枚）"],
        "sources": [standings_mod.FOTMOB_LEAGUE.format(id=standings_mod.LEAGUE_IDS[lead]).replace("/table", "/stats")],
    })
    sections.append({
        "id": "view", "heading": "見立て", "tier": "背景", "viewpoint": True, "narrator": "解説", "telop": "来週どこを見るか",
        "say": ["（5つのランキングを並べて分かったこと・来週どこを見るか）"],
        "sources": [standings_mod.FOTMOB_LEAGUE.format(id=standings_mod.LEAGUE_IDS[lead]).replace("/table", "/stats")],
    })
    lead_name = name_ja(picks[0]["name"], wd) if picks else name_ja(current[lead]["rows"][0]["name"], wd)
    note = {
        "date": day.strftime("%Y年%m月%d日"), "slot": "other_1", "format": "news", "series": "5大リーグの得点王レース",
        "people": [],
        "theme": {"id": f"scorers_{day.strftime('%m%d')}", "league": lead, "league_name": "欧州5大リーグ", "kind": "other",
                  "topic": "得点ランキング",
                  "title": f"{lead_name}{'の' + picks[0]['kind'] if picks else ''}。5大リーグの得点王レース（{day.month}月{day.day}日）、今週動いたのは",
                  "question": "5大リーグの得点王レースは今週どう動いて、その中の1つは何を示しているのか",
                  "takeaway": "（5つのランキングを並べて分かったことを1文で）"},
        "short_title": f"5大リーグの得点王レース {day.month}/{day.day}",
        "thumbnail": {"line1": "5大リーグ得点王レース", "line2": f"{lead_name}が●●", "tags": ["得点王"],
                      **({"board": str(board.relative_to(ROOT)).replace("\\", "/")} if board else {})},
        "sections": sections,
    }
    head = [f"# 5大リーグの得点王レース（{day.isoformat()}）。数字は FotMob。"
            + (f"先週比は前の控えと比べた。" if previous else "先週の控えが無いので先週比は「―」。"),
            "# 「今週の1つ」の候補（点の高い順。1つ選んで pick の節を書く）:"]
    head += [f"#   [{c['kind']}] {c['text']}" for c in picks[:8]] or ["#   （機械で拾える動きは無し）"]
    unknown = list(dict.fromkeys(unknown))
    if unknown:
        head.append("# カタカナにする（辞書に無い名前）: " + "、".join(unknown))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(head) + "\n" + yaml.safe_dump(note, allow_unicode=True, sort_keys=False, width=100), encoding="utf-8")
    return unknown


def board(current: dict, league: str, day: datetime.date, wd: dict[str, str], config) -> Path:
    """先頭のリーグの得点ランキングを棒グラフの板に（サムネの下地）。"""
    from src import statboard

    # 板は姓だけ（フルネームだと棒に重なる。ロベルト・フェルナンデスで実際に重なった）
    rows = [(name_ja(r["name"], wd).split("・")[-1], float(r["goals"])) for r in current[league]["rows"][:TOP]]
    out = BOARD_DIR / f"scorers_{day.strftime('%Y%m%d')}_{league}.png"
    return statboard.build(rows, out, config, title=f"{current[league]['name_ja']} 得点ランキング", unit="点", note="FotMob")


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--date", default=datetime.date.today().isoformat())
    ap.add_argument("--no-fetch", action="store_true")
    ap.add_argument("--no-board", action="store_true")
    args = ap.parse_args(argv)
    day = datetime.date.fromisoformat(args.date)
    snap_path = SNAP_DIR / f"{day.isoformat()}.json"
    if args.no_fetch:
        current = json.loads(snap_path.read_text(encoding="utf-8"))
    else:
        current = snapshot()
        SNAP_DIR.mkdir(parents=True, exist_ok=True)
        snap_path.write_text(json.dumps(current, ensure_ascii=False, indent=1), encoding="utf-8")
        print(f"控え → {snap_path}")
    prev = previous_snapshot(day)
    previous = prev[1] if prev else None
    names = [r["name"] for t in current.values() for r in t["rows"][:10]]
    wd = wikidata_names([n for n in names if mn.kana(n) == n])
    picks = candidates(current, previous, wd)
    board_path = None
    if not args.no_board:
        from src.config import load_config

        board_path = board(current, picks[0]["league"] if picks else LEAGUES[0], day, wd, load_config())
        print(f"板 → {board_path}")
    note_path = ROOT / "research" / f"{day.strftime('%Y%m%d')}_scorers.yaml"
    unknown = write_note(current, previous, day, note_path, wd, board_path)
    print(f"取材メモ → {note_path}")
    for league in LEAGUES:
        t = current[league]
        print(f"■ {t['name_ja']}")
        for row in table_rows(t["rows"], wd, ((previous or {}).get(league) or {}).get("rows") if previous else None):
            print("   " + "  ".join(row))
    print("今週の1つ の候補:")
    for c in picks[:8]:
        print(f"  [{c['kind']}] {c['text']}")
    if unknown:
        print("カタカナにする: " + "、".join(unknown))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
