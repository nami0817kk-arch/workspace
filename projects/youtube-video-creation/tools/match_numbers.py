"""数字で振り返る注目試合（試合の翌日のシリーズ、10月の案9。2026-09-28）。

    python tools/match_numbers.py --date 2026-09-27                 # その日の試合を注目度の順に並べる
    python tools/match_numbers.py --date 2026-09-27 --match 5868072 # 1試合の板と取材メモの雛形を書く

材料は `results` と同じ FotMob の試合詳細（公開ドキュメントの無い内部API。壊れたら例外で止まる）。
1試合から取るのは、得点の流れ（分・得点者・スコア）、両チームの数字（支配率・xG・シュート・枠内・
決定機・パス成功率・走行距離・デュエル）、採点の高い選手。**スコアと得点者は台本にする段でリーグ公式まで
辿る**（`results` の約束と同じ。雛形は 報道 で書き、公式の試合記録のURLを足して 確定 に上げる）。

決まり（CLAUDE.md「10月のシリーズ」）：本編4〜6分、自作の表が主役、見立ての節。
数字が3行以上並ぶ節には表を出す（2026-09-15）。選手名は `research/*/kana.json` でカタカナにし、
辞書に無い名前は雛形の頭に並べる（アルファベットを読み上げに残さない）。
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

from src import clubs as clubs_mod  # noqa: E402
from src import results as results_mod  # noqa: E402
from src import standings as standings_mod  # noqa: E402

LEAGUES = ["england", "spain", "germany", "italy", "france"]
BOARD_DIR = ROOT / "assets" / "stats"
MATCH_URL = "https://www.fotmob.com/matches/x/{id}"
# FotMob の大会名 → 設定のリーグキー
LEAGUE_BY_NAME = {"Premier League": "england", "LaLiga": "spain", "Bundesliga": "germany",
                  "Serie A": "italy", "Ligue 1": "france", "Eredivisie": "netherlands"}

# FotMob の「Top stats」の見出し → 表の項目名。この順で表に出す
STAT_ROWS = [
    ("Ball possession", "ボール支配率", "%"),
    ("Expected goals (xG)", "xG（ゴール期待値）", ""),
    ("Total shots", "シュート", ""),
    ("Shots on target", "枠内シュート", ""),
    ("Big chances", "決定機", ""),
    ("Accurate passes", "パス成功", ""),
    ("Distance covered", "走行距離", "km"),
    ("Duels won", "デュエル勝ち", ""),
]

_kana: dict[str, str] | None = None


def kana(name: str) -> str:
    """選手名をカタカナに。辞書に無ければ英語のまま返す（雛形の頭で知らせる）。

    辞書は `research/*/kana.json`（クラブ紹介の登録選手）と `research/kana/players.json`
    （このシリーズで足していく分）。新しい名前は players.json に足す。
    """
    global _kana
    if _kana is None:
        _kana = {}
        for path in sorted(ROOT.glob("research/*/kana.json")) + [ROOT / "research" / "kana" / "players.json"]:
            try:
                _kana.update(json.loads(path.read_text(encoding="utf-8")))
            except (OSError, ValueError):
                continue
    return _kana.get(name, name)


def is_big(team: str) -> bool:
    found = clubs_mod.find(standings_mod.FOTMOB_LONG.get(team, team))
    return bool(found and found[0].big)


def parse_stats(payload: dict) -> dict[str, tuple]:
    """試合詳細の `content.stats` から、表に出す数字を (home, away) で。無い項目は入れない。"""
    out: dict[str, tuple] = {}
    periods = ((payload.get("content") or {}).get("stats") or {}).get("Periods") or {}
    for group in (periods.get("All") or {}).get("stats") or []:
        for item in group.get("stats") or []:
            title = str(item.get("title") or "")
            values = item.get("stats") or [None, None]
            if title in dict((k, v) for k, v, _ in STAT_ROWS) and title not in out and values[0] is not None:
                out[title] = (values[0], values[1])
    return out


def parse_goals(payload: dict) -> list[dict]:
    """得点の流れ。分・得点者・どちらの得点か・そのときのスコア・PK/ヘディング/OG。"""
    events = (((payload.get("content") or {}).get("matchFacts") or {}).get("events") or {}).get("events") or []
    goals = []
    for e in events:
        if str(e.get("type")) != "Goal":
            continue
        player = e.get("player") or {}
        name = str(e.get("fullName") or e.get("nameStr") or player.get("name") or "")
        minute = int(e.get("time") or 0)
        extra = e.get("overloadTime")
        goals.append(dict(minute=minute, extra=int(extra) if extra else 0, player=name,
                          home=bool(e.get("isHome")), score=list(e.get("newScore") or []),
                          kind=str(e.get("goalDescription") or ""), own=bool(e.get("ownGoal")),
                          assist=str(e.get("assistStr") or "").replace("assist by ", "")))
    return goals


def parse_players(payload: dict) -> dict:
    """採点の高い選手（両チーム3人ずつ）と、その試合のMVP。年齢も控える（表に出すときに要る）。"""
    lineup = (payload.get("content") or {}).get("lineup") or {}
    sides = {}
    for key, side in (("home", "homeTeam"), ("away", "awayTeam")):
        rows = []
        for p in (lineup.get(side) or {}).get("starters") or []:
            rating = (p.get("performance") or {}).get("rating")
            if rating is None:
                continue
            rows.append(dict(name=str(p.get("name") or ""), rating=float(rating), age=p.get("age"),
                             country=str(p.get("countryCode") or "")))
        sides[key] = sorted(rows, key=lambda r: -r["rating"])[:3]
    potm = ((payload.get("content") or {}).get("matchFacts") or {}).get("playerOfTheMatch") or {}
    name = potm.get("name") or {}
    sides["potm"] = dict(name=str(name.get("fullName") or ""), rating=str((potm.get("rating") or {}).get("num") or ""))
    return sides


def fetch(match_id: str) -> dict:
    payload = results_mod._get("matchDetails", {"matchId": str(match_id)})
    general = payload.get("general") or {}
    facts = (payload.get("content") or {}).get("matchFacts") or {}
    home, away = (general.get("homeTeam") or {}).get("name", ""), (general.get("awayTeam") or {}).get("name", "")
    goals = parse_goals(payload)
    score = goals[-1]["score"] if goals else [0, 0]
    return dict(
        id=str(match_id), home=home, away=away, home_ja=standings_mod.japanese(home),
        away_ja=standings_mod.japanese(away), score=score, league_name=str(general.get("leagueName") or ""),
        round=general.get("matchRound"), date=str(general.get("matchTimeUTCDate") or "")[:10],
        attendance=(facts.get("infoBox") or {}).get("Attendance"),
        stats=parse_stats(payload), goals=goals, players=parse_players(payload),
    )


def fmt(title: str, value) -> str:
    if title == "Distance covered":
        try:
            return f"{float(value) / 1000:.1f}km"
        except (TypeError, ValueError):
            return str(value)
    if title == "Ball possession":
        return f"{value}%"
    return str(value)


def numbers_rows(match: dict) -> list[list[str]]:
    rows = []
    for key, label, _ in STAT_ROWS:
        if key in match["stats"]:
            h, a = match["stats"][key]
            rows.append([label, fmt(key, h), fmt(key, a)])
    return rows


def score_rows(match: dict) -> list[list[str]]:
    rows = []
    for g in match["goals"]:
        minute = f"{g['minute']}+{g['extra']}分" if g["extra"] else f"{g['minute']}分"
        who = kana(g["player"]) + ("（OG）" if g["own"] else "（PK）" if g["kind"] == "Penalty" else "")
        side = match["home_ja"] if g["home"] else match["away_ja"]
        rows.append([minute, side, who, f"{g['score'][0]}-{g['score'][1]}" if g["score"] else ""])
    return rows


def flow_lines(match: dict) -> list[str]:
    """得点の流れの読み上げ。「1対0」の数字だけを並べない（draft の「スコアだけで勝敗を言っていません」）。

    先制・追加点・1点返す・同点・逆転、の言い方で追う。
    """
    lines = []
    prev = [0, 0]
    for g in match["goals"]:
        side = match["home_ja"] if g["home"] else match["away_ja"]
        cur = g["score"] or prev
        mine, theirs = (cur[0], cur[1]) if g["home"] else (cur[1], cur[0])
        before_mine, before_theirs = (prev[0], prev[1]) if g["home"] else (prev[1], prev[0])
        if before_mine == 0 and before_theirs == 0:
            what = "先制"
        elif mine == theirs:
            what = "同点に追いつく"
        elif before_mine < before_theirs and mine > theirs:
            what = "逆転"
        elif before_mine > before_theirs:
            what = "追加点"
        else:
            what = "1点返す"
        minute = f"{g['minute']}+{g['extra']}分" if g["extra"] else f"{g['minute']}分"
        who = kana(g["player"])
        how = "、PKで" if g["kind"] == "Penalty" else "、ヘディングで" if g["kind"] == "Header" else "、オウンゴールで" if g["own"] else ""
        lines.append(f"{minute}、{who}{how}。{side}が{what}。")
        prev = cur
    return lines


def _num(value) -> float:
    try:
        return float(str(value).split(" ")[0].replace("%", ""))
    except (TypeError, ValueError):
        return 0.0


def say_numbers(match: dict) -> list[str]:
    """数字の節の読み上げ（表の上から順。1行40字まで）。"""
    s = match["stats"]
    h, a = match["home_ja"], match["away_ja"]
    lines = []
    if "Ball possession" in s:
        lines.append(f"ボール支配率は{h}が{s['Ball possession'][0]}%、{a}が{s['Ball possession'][1]}%。")
    if "Expected goals (xG)" in s:
        xh, xa = s["Expected goals (xG)"]
        lines.append("ゴール期待値、xGを見ます。")
        lines.append(f"{h}が{xh}、{a}が{xa}でした。")
    if "Total shots" in s and "Shots on target" in s:
        lines.append(f"シュートは{s['Total shots'][0]}本と{s['Total shots'][1]}本、"
                     f"枠内は{s['Shots on target'][0]}本と{s['Shots on target'][1]}本。")
    if "Big chances" in s:
        lines.append(f"決定機は{s['Big chances'][0]}回と{s['Big chances'][1]}回です。")
    return lines


def upset(match: dict) -> str:
    """xG と結果の食い違い。見立ての種。"""
    s = match["stats"].get("Expected goals (xG)")
    if not s:
        return ""
    xh, xa = _num(s[0]), _num(s[1])
    gh, ga = match["score"]
    if gh > ga and xa - xh >= 0.8:
        return f"{match['away_ja']}のほうが xG で{xa - xh:.1f}上回りながら負けた（押していたのは負けた側）"
    if ga > gh and xh - xa >= 0.8:
        return f"{match['home_ja']}のほうが xG で{xh - xa:.1f}上回りながら負けた（押していたのは負けた側）"
    if gh == ga and abs(xh - xa) >= 1.0:
        side = match["home_ja"] if xh > xa else match["away_ja"]
        return f"引き分けだが xG は{side}が{abs(xh - xa):.1f}上（勝ち点を取り損ねた側がある）"
    return ""


def attention(match: dict) -> tuple[int, list[str]]:
    """注目度。ビッグクラブ・得点の多さ・日本人・xG の逆転・大観衆。**選ぶのは人。**"""
    score, why = 0, []
    for team in (match["home"], match["away"]):
        if is_big(team):
            score += 3
            why.append(f"{standings_mod.japanese(team)}")
    goals = sum(match["score"])
    if goals >= 4:
        score += 2
        why.append(f"{goals}ゴール")
    if any(p.get("country") == "JPN" for side in ("home", "away") for p in match["players"].get(side, [])):
        score += 3
        why.append("日本人が上位の採点")
    if upset(match):
        score += 2
        why.append("xG と結果が逆")
    if (match.get("attendance") or 0) >= 60000:
        score += 1
        why.append(f"観衆{match['attendance']:,}")
    if goals == 0:
        score -= 1
    return score, why


def board(match: dict, out: Path, config) -> Path:
    """両チームの数字の表を1枚の板に。サムネの下地（review は自作の図を顔の代わりに認める）。"""
    from src import statboard

    spec = {"type": "table", "title": f"{match['home_ja']} {match['score'][0]}-{match['score'][1]} {match['away_ja']}",
            "columns": ["", match["home_ja"], match["away_ja"]], "rows": numbers_rows(match)[:6], "source": "FotMob"}
    statboard.build_spec(spec, out, config)
    statboard._write_mark(out, spec["title"], "", [(r[0], _num(r[1])) for r in spec["rows"]], "FotMob")
    return out


def write_note(match: dict, day: datetime.date, path: Path, board_path: Path | None = None) -> list[str]:
    """取材メモの雛形。得点の流れ → 数字（main）→ 光った選手 → 見立て。英語のままの名前を返す。"""
    h, a = match["home_ja"], match["away_ja"]
    gh, ga = match["score"]
    url = MATCH_URL.format(id=match["id"])
    league = LEAGUE_BY_NAME.get(match["league_name"], "england")
    players = match["players"]
    potm = players.get("potm") or {}
    other_side = "away" if any(p["name"] == potm.get("name") for p in players.get("home", [])) else "home"
    other = (players.get(other_side) or [{}])[0]
    names = [g["player"] for g in match["goals"]] + [potm.get("name", ""), other.get("name", "")]
    unknown = sorted({n for n in names if n and kana(n) == n})
    seed = upset(match)
    sections = [
        {"id": "score", "heading": "得点の流れ", "tier": "報道", "telop": f"{h} {gh}-{ga} {a}", "narrator": "キャスター",
         "card": {"type": "table", "title": f"{h} {gh}-{ga} {a}", "columns": ["分", "クラブ", "得点者", "スコア"],
                  "rows": score_rows(match), "source": "FotMob"},
         "say": [f"{h}対{a}は、{h}が{gh}対{ga}で勝ちました。" if gh > ga
                 else f"{h}対{a}は、{a}が{ga}対{gh}で勝ちました。" if ga > gh
                 else f"{h}対{a}は、{gh}対{ga}の引き分けでした。"]
                + flow_lines(match)[:5],
         "sources": [url]},
        {"id": "numbers", "heading": "数字で見る", "tier": "報道", "main": True,
         "telop": "両チームの数字", "narrator": "解説",
         "card": {"type": "table", "title": "両チームの数字", "columns": ["", h, a], "rows": numbers_rows(match),
                  "source": "FotMob"},
         "say": [{"text": "（前置き1行：結果を一言で。数字で見ると、と続ける）", "short_only": True}]
                + say_numbers(match),
         "sources": [url]},
        {"id": "players", "heading": "光った選手", "tier": "報道", "telop": "採点の高かった選手", "narrator": "解説",
         "say": [f"この試合の最高評価は{kana(potm.get('name', ''))}、採点{potm.get('rating', '')}。"
                 if potm.get("name") else "（採点が取れませんでした。消すか、選手の話を1つ書く）",
                 f"相手側で高かったのは{kana(other.get('name', ''))}の{other.get('rating', '')}です。"
                 if other.get("name") else "（相手側の選手）"],
         "sources": [url]},
        {"id": "view", "heading": "見立て", "tier": "背景", "viewpoint": True, "narrator": "解説",
         "telop": "数字が示していること",
         "say": [f"（{seed}。ここから何が言えるか）" if seed else "（数字と結果を並べて分かったこと・次の試合で見るところ）"],
         "sources": [url]},
    ]
    note = {
        "date": day.strftime("%Y年%m月%d日"),
        "slot": "results_1",
        "format": "news",
        "series": "数字で見る注目試合",
        "theme": {
            "id": f"match_{match['id']}", "league": league, "kind": "match", "topic": h,
            # 題は言い切らない（答えを隠す）。問いの形で終える
            "title": f"{h}対{a}、{gh}対{ga}の中身。数字はどう見たか",
            "question": f"{h}対{a}の{gh}対{ga}は、数字ではどう見えるのか",
            "takeaway": f"（{seed}）" if seed else "（数字と結果を並べて分かったことを1文で）",
        },
        "short_title": f"{h} {gh}-{ga} {a} を数字で",
        # サムネの1行目は14字くらいまで。勝った側の名前とスコアだけ置く
        "thumbnail": {"line1": (f"{h}が{gh}-{ga}" if gh >= ga else f"{a}が{ga}-{gh}"), "line2": "数字で見ると●●",
                      "tags": [h, a],
                      **({"board": str(board_path.relative_to(ROOT)).replace("\\", "/")} if board_path else {})},
        "sections": sections,
    }
    head = [f"# {h} {gh}-{ga} {a}（{match['date']}、{match['league_name']} 第{match['round']}節）。数字は FotMob。",
            "# スコアと得点者はリーグ公式の試合記録まで辿り、URLを sources に足して tier を 確定 に上げる。"]
    if unknown:
        head.append("# カタカナにする（辞書に無い名前）: " + "、".join(unknown))
    if seed:
        head.append(f"# 見立ての種: {seed}")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(head) + "\n" + yaml.safe_dump(note, allow_unicode=True, sort_keys=False, width=100),
                    encoding="utf-8")
    return unknown


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--date", default=(datetime.date.today() - datetime.timedelta(days=1)).isoformat(),
                    help="試合の日（既定は昨日）")
    ap.add_argument("--match", help="この試合の雛形と板を書く（FotMob の matchId）")
    ap.add_argument("--no-board", action="store_true")
    args = ap.parse_args(argv)
    day = datetime.date.fromisoformat(args.date)

    if not args.match:
        matches = [m for m in results_mod.fetch_day(day) if m.finished and m.league in LEAGUES]
        ranked = []
        for m in matches:
            detail = fetch(m.match_id)
            ranked.append((attention(detail), detail))
        ranked.sort(key=lambda x: -x[0][0])
        print(f"{day} の試合 {len(ranked)}（注目度の順。--match <id> で雛形を書く）")
        for (score, why), d in ranked:
            print(f"  {score:>2}  {d['id']}  {d['home_ja']} {d['score'][0]}-{d['score'][1]} {d['away_ja']}"
                  f"（{d['league_name']}）  {'・'.join(why)}")
        return 0

    match = fetch(args.match)
    board_path = None
    if not args.no_board:
        from src.config import load_config

        board_path = board(match, BOARD_DIR / f"match_{match['date'].replace('-', '')}_{match['id']}.png", load_config())
        print(f"板 → {board_path}")
    note_path = ROOT / "research" / f"{day.strftime('%Y%m%d')}_match_{match['id']}.yaml"
    unknown = write_note(match, day, note_path, board_path)
    print(f"取材メモ → {note_path}")
    for row in numbers_rows(match):
        print(f"   {row[0]:<12} {row[1]:>10} {row[2]:>10}")
    if unknown:
        print("カタカナにする: " + "、".join(unknown))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
