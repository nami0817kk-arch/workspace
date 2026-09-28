"""5大リーグの順位表と「今週の1つ」（火曜のシリーズ、10月の案3。2026-09-28）。

    python tools/standings_week.py --date 2026-09-29            # 取って控えて、取材メモの雛形まで
    python tools/standings_week.py --date 2026-09-29 --no-fetch # その日の控えから作り直す

やること
1. 5リーグ（イングランド・スペイン・ドイツ・イタリア・フランス）の順位表を FotMob から取る（`src.standings`）
2. `research/standings/<日付>.json` に控える。**前の週の控えと比べて「先週比」を出す**（順位表そのものは
   毎週ほぼ同じ絵なので、動きが無いと話にならない）
3. 「今週の1つ」の候補を並べる（首位交代・大きく上がった／落ちた・無敗・未勝利・独走）。**選ぶのは人**。
   雛形の頭にコメントで出すので、1つ選んで `pick` の節を書く
4. 5枚の板（`assets/stats/standings_<日付>_<リーグ>.png`）と取材メモの雛形（`research/<日付>_standings.yaml`）を書く

決まり（CLAUDE.md「10月のシリーズ」）：本編4〜6分、他人の声は無くてよい、自作の表が主役、見立ての節。
1リーグ1節で上位6行だけ表にする（20行は動画では読めない）。読み上げは首位・2位との差・今週の動きの3行まで。
"""

from __future__ import annotations

import argparse
import datetime
import json
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from src import standings as standings_mod  # noqa: E402

LEAGUES = ["england", "spain", "germany", "italy", "france"]
SNAP_DIR = ROOT / "research" / "standings"
BOARD_DIR = ROOT / "assets" / "stats"
TOP = 6          # 表に載せる行数
BIG_MOVE = 3     # 「大きく動いた」と言う順位の差
RUNAWAY = 5      # 「独走」と言う首位と2位の差


def snapshot(tables: list) -> dict:
    """取った順位表を、控えに残す形（JSON にできる辞書）にする。"""
    out = {}
    for table in tables:
        out[table.league] = {
            "name_ja": table.name_ja,
            "matchweek": table.matchweek,
            "rows": [dict(rank=r.rank, team=r.team, team_ja=standings_mod.japanese(r.team),
                          played=r.played, win=r.win, draw=r.draw, lose=r.lose,
                          diff=r.diff, points=r.points) for r in table.rows],
        }
    return out


def previous_snapshot(day: datetime.date, snap_dir: Path = SNAP_DIR) -> tuple[datetime.date, dict] | None:
    """その日より前で、いちばん新しい控え。無ければ None（初回は先週比を出さない）。"""
    best = None
    for path in sorted(snap_dir.glob("*.json")) if snap_dir.exists() else []:
        try:
            when = datetime.date.fromisoformat(path.stem)
        except ValueError:
            continue
        if when < day and (best is None or when > best[0]):
            best = (when, path)
    if best is None:
        return None
    return best[0], json.loads(best[1].read_text(encoding="utf-8"))


def moves(current: dict, previous: dict | None) -> dict[str, dict[str, int]]:
    """リーグごと・クラブごとの順位の動き（正なら上がった）。前の控えに無いクラブは 0。"""
    out: dict[str, dict[str, int]] = {}
    for league, table in current.items():
        before = {r["team"]: r["rank"] for r in ((previous or {}).get(league) or {}).get("rows", [])}
        out[league] = {r["team"]: (before[r["team"]] - r["rank"]) if r["team"] in before else 0
                       for r in table["rows"]}
    return out


def arrow(delta: int, known: bool) -> str:
    if not known:
        return "―"
    if delta > 0:
        return f"↑{delta}"
    if delta < 0:
        return f"↓{-delta}"
    return "→"


def table_rows(table: dict, delta: dict[str, int], known: bool, top: int = TOP) -> list[list[str]]:
    """表の行。順位・クラブ・試合・勝点・先週比の5列（8列は「試合勝」がくっついた。2026-09-07）。"""
    return [[str(r["rank"]), r["team_ja"], str(r["played"]), str(r["points"]),
             arrow(delta.get(r["team"], 0), known)] for r in table["rows"][:top]]


# 首位と2位の言い方。5リーグで同じ文を繰り返すと `draft` の重複（8字）で止まるので、リーグごとに変える
GAP_LINES = [
    lambda f, s, g: f"首位は{f}、勝点{g[0]}です。2位の{s}とは{g[1]}点差。",
    lambda f, s, g: f"{f}が首位で勝点{g[0]}。{s}が{g[1]}点差で追います。",
    lambda f, s, g: f"上にいるのは{f}。勝点{g[0]}で、{s}を{g[1]}点引き離しています。",
    lambda f, s, g: f"首位に立つのは{f}、勝点は{g[0]}。追う{s}との開きは{g[1]}。",
    lambda f, s, g: f"{f}が勝点{g[0]}でトップ。2番手は{s}で、その差は{g[1]}点です。",
]
TIE_LINES = [
    lambda f, s, g: f"首位は{f}、勝点{g[0]}です。2位の{s}と勝点で並んでいます。",
    lambda f, s, g: f"{f}が首位で勝点{g[0]}。{s}が同じ勝点で続きます。",
    lambda f, s, g: f"上にいるのは{f}。勝点{g[0]}で、{s}と並んでいます。",
    lambda f, s, g: f"首位に立つのは{f}、勝点は{g[0]}。{s}も同じ数字です。",
    lambda f, s, g: f"{f}が勝点{g[0]}でトップ。2番手の{s}も勝点は同じです。",
]


def say_league(table: dict, delta: dict[str, int], known: bool, index: int = 0) -> list[str]:
    """1リーグの読み上げ（4行まで）。1行は40字以内（6行の表とテロップが重なる）。

    首位と2位の差の言い方は `index`（リーグの順）で変える。5リーグとも同じ文だと
    `draft` の重複の点検（8字）で止まるうえ、続けて見ると同じに聞こえる。
    """
    rows = table["rows"]
    first, second = rows[0], rows[1]
    gap = first["points"] - second["points"]
    pool = GAP_LINES if gap else TIE_LINES
    lines = [f"{table['name_ja']}は第{table['matchweek']}節まで。",
             pool[index % len(pool)](first["team_ja"], second["team_ja"], (first["points"], gap))]
    if known:
        up = max(rows, key=lambda r: delta.get(r["team"], 0))
        down = min(rows, key=lambda r: delta.get(r["team"], 0))
        if delta.get(up["team"], 0) > 0:
            lines.append(f"今週いちばん上がったのは{up['team_ja']}、{up['rank'] + delta[up['team']]}位から{up['rank']}位です。")
        if delta.get(down["team"], 0) < 0:
            lines.append(f"落ちたのは{down['team_ja']}、{down['rank'] + delta[down['team']]}位から{down['rank']}位。")
    return lines


def candidates(current: dict, previous: dict | None) -> list[dict]:
    """「今週の1つ」の候補。点の高い順。**選ぶのは人**（雛形の頭に並べる）。"""
    out: list[dict] = []
    delta = moves(current, previous)
    for league, table in current.items():
        rows = table["rows"]
        name = table["name_ja"]
        first, second = rows[0], rows[1]
        before = ((previous or {}).get(league) or {}).get("rows") or []
        if before and before[0]["team"] != first["team"]:
            out.append(dict(league=league, kind="首位交代", score=10, team=first["team_ja"],
                            text=f"{name}：首位が{before[0]['team_ja']}から{first['team_ja']}に替わった"))
        gap = first["points"] - second["points"]
        if gap >= RUNAWAY:
            out.append(dict(league=league, kind="独走", score=4 + gap, team=first["team_ja"],
                            text=f"{name}：{first['team_ja']}が2位に{gap}点差"))
        for r in rows:
            d = delta[league].get(r["team"], 0)
            if d >= BIG_MOVE:
                out.append(dict(league=league, kind="上昇", score=3 + d, team=r["team_ja"],
                                text=f"{name}：{r['team_ja']}が{r['rank'] + d}位から{r['rank']}位へ（↑{d}）"))
            elif d <= -BIG_MOVE:
                out.append(dict(league=league, kind="下落", score=3 - d, team=r["team_ja"],
                                text=f"{name}：{r['team_ja']}が{r['rank'] + d}位から{r['rank']}位へ（↓{-d}）"))
        played = max(r["played"] for r in rows)
        if played >= 5:
            unbeaten = [r["team_ja"] for r in rows if r["lose"] == 0 and r["played"] >= played - 1]
            winless = [r["team_ja"] for r in rows if r["win"] == 0 and r["played"] >= played - 1]
            if 0 < len(unbeaten) <= 2:
                out.append(dict(league=league, kind="無敗", score=5, team=unbeaten[0],
                                text=f"{name}：{played}試合を終えて無敗は{'・'.join(unbeaten)}だけ"))
            if 0 < len(winless) <= 2:
                out.append(dict(league=league, kind="未勝利", score=4, team=winless[0],
                                text=f"{name}：{played}試合で未勝利は{'・'.join(winless)}"))
    return sorted(out, key=lambda c: -c["score"])


def write_note(current: dict, previous: dict | None, day: datetime.date, path: Path,
               boards: dict[str, Path] | None = None, top: int = TOP) -> list[dict]:
    """取材メモの雛形。5リーグの節 → 今週の1つ（main）→ 見立て。候補は頭のコメントに並べる。"""
    delta = moves(current, previous)
    known = previous is not None
    picks = candidates(current, previous)
    lead_league = picks[0]["league"] if picks else LEAGUES[0]
    boards = boards or {}
    sections = []
    for league in LEAGUES:
        table = current[league]
        official = standings_mod.OFFICIAL_TABLES.get(league, "")
        fotmob = standings_mod.FOTMOB_LEAGUE.format(id=standings_mod.LEAGUE_IDS[league])
        sections.append({
            "id": league, "heading": f"{table['name_ja']} 第{table['matchweek']}節", "tier": "確定",
            "telop": f"{table['name_ja']} 第{table['matchweek']}節終了時点", "narrator": "キャスター",
            "official": True,
            "card": {"type": "table", "title": f"{table['name_ja']} 第{table['matchweek']}節終了時点",
                     "columns": ["順位", "クラブ", "試合", "勝点", "先週比"],
                     "rows": table_rows(table, delta[league], known, top), "source": "FotMob"},
            "say": say_league(table, delta[league], known, LEAGUES.index(league)),
            "sources": [u for u in (official, fotmob) if u],
        })
    sections.append({
        "id": "pick", "heading": "今週の1つ", "tier": "確定", "main": True, "official": True,
        "telop": "今週の1つ", "narrator": "解説",
        "say": [{"text": "（ショート用の前置き1行：5大リーグの順位表から、今週は●●の話）", "short_only": True},
                "（候補から1つ選んで、数字で掘る。3〜6行。表かグラフを1枚）"],
        "sources": [standings_mod.OFFICIAL_TABLES.get(lead_league, "")],
    })
    sections.append({
        "id": "view", "heading": "見立て", "tier": "背景", "viewpoint": True, "narrator": "解説",
        "telop": "来週どこを見るか",
        "say": ["（5つの表を並べて分かったこと・来週どこを見るか）"],
        "sources": [standings_mod.FOTMOB_LEAGUE.format(id=standings_mod.LEAGUE_IDS[lead_league])],
    })
    note = {
        "date": day.strftime("%Y年%m月%d日"),
        "slot": "other_1",
        "format": "news",
        "series": "5大リーグの順位表",
        "theme": {
            "id": f"standings_{day.strftime('%m%d')}",
            "league": lead_league, "league_name": "欧州5大リーグ", "kind": "match", "topic": "順位表",
            # 題の頭はクラブ名（「タイトルの主語」の点検）。1つめの候補のクラブを仮に置く。選び直したら書き換える
            "title": (f"{picks[0]['team']}の{picks[0]['kind']}と、" if picks else "")
                     + f"5大リーグの順位表（{day.month}月{day.day}日）。今週いちばん動いたのは",
            "question": "5大リーグの順位表は今週どう動いて、その中の1つは何を示しているのか",
            "takeaway": "（5つの表を並べて分かったことを1文で）",
        },
        "short_title": f"5大リーグの順位表 {day.month}/{day.day}",
        # サムネの文字にはクラブ名を入れる（2026-09-25）。1つめの候補のクラブを仮に置く
        "thumbnail": {"line1": "5大リーグ順位表",
                      "line2": f"{picks[0]['team']}の{picks[0]['kind']}" if picks else "今週動いたのは●●",
                      "tags": ["順位表"],
                      **({"board": str(boards[lead_league].relative_to(ROOT)).replace("\\", "/")}
                         if lead_league in boards else {})},
        "sections": sections,
    }
    head = [f"# 5大リーグの順位表（{day.isoformat()}）。数字は FotMob と各リーグ公式。"
            + ("先週比は " + previous_date_text(day) + " の控えと比べた。" if known else "先週の控えが無いので先週比は出していない。")]
    head.append("# 「今週の1つ」の候補（点の高い順。1つ選んで pick の節を書く）:")
    for c in picks[:8]:
        head.append(f"#   [{c['kind']}] {c['text']}")
    if not picks:
        head.append("#   （機械で拾える動きは無し。表を見て自分で1つ選ぶ）")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(head) + "\n" + yaml.safe_dump(note, allow_unicode=True, sort_keys=False, width=100),
                    encoding="utf-8")
    return picks


def previous_date_text(day: datetime.date) -> str:
    prev = previous_snapshot(day)
    return prev[0].isoformat() if prev else "?"


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--date", default=datetime.date.today().isoformat())
    ap.add_argument("--top", type=int, default=TOP)
    ap.add_argument("--no-fetch", action="store_true", help="その日の控えから作り直す")
    ap.add_argument("--no-board", action="store_true")
    args = ap.parse_args(argv)
    day = datetime.date.fromisoformat(args.date)
    snap_path = SNAP_DIR / f"{day.isoformat()}.json"

    tables = []
    if args.no_fetch:
        current = json.loads(snap_path.read_text(encoding="utf-8"))
    else:
        for league in LEAGUES:
            tables.append(standings_mod.fetch(league))
        current = snapshot(tables)
        SNAP_DIR.mkdir(parents=True, exist_ok=True)
        snap_path.write_text(json.dumps(current, ensure_ascii=False, indent=1), encoding="utf-8")
        print(f"控え → {snap_path}")
    prev = previous_snapshot(day)
    previous = prev[1] if prev else None

    boards: dict[str, Path] = {}
    if tables and not args.no_board:
        from src.config import load_config

        config = load_config()
        for table in tables:
            out = BOARD_DIR / f"standings_{day.strftime('%Y%m%d')}_{table.league}.png"
            boards[table.league] = standings_mod.board(table, out, config, args.top)
            print(f"板 → {out}")

    if not boards:
        # --no-fetch のときは、その日にすでに描いた板を拾う（無ければサムネの板は書かない）
        for league in LEAGUES:
            out = BOARD_DIR / f"standings_{day.strftime('%Y%m%d')}_{league}.png"
            if out.exists():
                boards[league] = out

    note_path = ROOT / "research" / f"{day.strftime('%Y%m%d')}_standings.yaml"
    picks = write_note(current, previous, day, note_path, boards, args.top)
    print(f"取材メモ → {note_path}")
    delta = moves(current, previous)
    for league in LEAGUES:
        t = current[league]
        print(f"■ {t['name_ja']} 第{t['matchweek']}節")
        for row in table_rows(t, delta[league], previous is not None, args.top):
            print("   " + "  ".join(f"{c:>4}" if i != 1 else f"{c:<14}" for i, c in enumerate(row)))
    print("今週の1つ の候補:")
    for c in picks[:8]:
        print(f"  [{c['kind']}] {c['text']}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
