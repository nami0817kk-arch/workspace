"""欧州組の日本人選手を数える（2026-09-28、10月のシリーズ1「欧州組の1週間」の道具）。

数えるのは Transfermarkt の試合記録（tmapi-alpha.transfermarkt.technology）。
**推測で埋めない。**出場時間・得点・アシスト・評価点は1試合ずつの記録を足したもの。

    python tools/japan_abroad.py roster                 # 名簿を作る → config/japan_abroad.yaml
    python tools/japan_abroad.py week --to 2026-09-28   # その日までの1週間を数える → research/weekly/2026-09-28.json
    python tools/japan_abroad.py week --to 2026-09-28 --note research/20260929_weekly.yaml   # 取材メモの雛形も書く

名簿の元は Wikidata（日本国籍・男子・Transfermarkt の番号あり・海外クラブ所属）の一覧
（research/_japan_abroad_candidates.json）と、抜けていた人の番号（EXTRA）。
名簿に入るのは、今季の記録の主なクラブが**日本の外**の人だけ。
"""
from __future__ import annotations

import argparse
import collections
import datetime
import json
import sys
import time
from pathlib import Path

import requests
import yaml

ROOT = Path(__file__).resolve().parents[1]
API = "https://tmapi-alpha.transfermarkt.technology"
HEADERS = {"User-Agent": "Mozilla/5.0"}
ROSTER = ROOT / "config" / "japan_abroad.yaml"
CANDIDATES = ROOT / "research" / "_japan_abroad_candidates.json"
WEEKLY_DIR = ROOT / "research" / "weekly"
SEASON = 2026
JAPAN = 77          # Transfermarkt の国番号
# Wikidata の一覧に無かった人（Transfermarkt の検索ページで番号を確かめた 2026-09-28）
EXTRA = {"146310": "遠藤航", "165793": "南野拓実", "668606": "鈴木唯人", "489463": "古橋亨梧"}
# 名簿に入れる大会（主要リーグの1部・2部と、日本人の多いベルギー・スコットランド）。
# 3部以下や欧州外（ポーランド・インドネシア…）は、名簿に入れない
MAJOR = {"GB1", "GB2", "ES1", "ES2", "L1", "L2", "IT1", "IT2", "FR1", "FR2", "NL1", "PO1", "BE1", "SC1"}
# 大会の番号 → 日本語（記録に出てくるものだけ足していく）
COMPETITIONS = {
    "GB1": "プレミアリーグ", "GB2": "チャンピオンシップ", "CGB": "リーグカップ", "FAC": "FAカップ",
    "ES1": "ラ・リーガ", "ES2": "ラ・リーガ2", "CDR": "国王杯",
    "L1": "ブンデスリーガ", "L2": "2.ブンデスリーガ", "L3": "3.リーガ", "DFB": "DFBポカール",
    "IT1": "セリエA", "IT2": "セリエB", "CIT": "コッパ・イタリア",
    "FR1": "リーグ・アン", "FR2": "リーグ・ドゥ", "FR3": "ナシオナル",
    "NL1": "エールディビジ", "NL2": "エールステ・ディビジ", "NLSC": "ヨハン・クライフ・スハール",
    "PO1": "リーガ・ポルトガル", "PO2": "リーガ・ポルトガル2",
    "BE1": "ジュピラー・プロ・リーグ", "BE2": "チャレンジャー・プロ・リーグ",
    "SC1": "スコティッシュ・プレミアシップ",
    "CL": "チャンピオンズリーグ", "CLQ": "チャンピオンズリーグ予選", "EL": "ヨーロッパリーグ",
    "ELQ": "ヨーロッパリーグ予選", "UCOL": "カンファレンスリーグ", "ECLQ": "カンファレンスリーグ予選",
    # 代表戦（代表ウィークに --national で数えるとき）
    "UNLA": "ネーションズリーグA", "UNLB": "ネーションズリーグB", "WMQE": "W杯予選（欧州）",
    "WMQA": "W杯予選（アジア）", "AM": "アジアカップ", "FS": "国際親善試合", "FSFS": "国際親善試合",
}


def _get(path: str, tries: int = 3) -> dict:
    for attempt in range(tries):
        try:
            got = requests.get(f"{API}{path}", headers=HEADERS, timeout=30)
            if got.status_code == 200:
                return got.json().get("data") or {}
        except requests.RequestException:
            pass
        time.sleep(1.5 * (attempt + 1))
    return {}


def games_of(player_id: str, season: int = SEASON, national: bool = False) -> list[dict]:
    """その季の試合記録（記録の無い行は飛ばす）。

    代表戦は既定で除く。**代表ウィーク**（9/22〜28 のようにクラブの試合が無い週）は
    `national=True` で代表戦も数える（2026-09-28）。季の合計はクラブの試合だけで数える。
    """
    perf = _get(f"/player/{player_id}/performance-game?season={season}").get("performance") or []
    return split_games(perf, season, national)


def split_games(perf: list, season: int = SEASON, national: bool = False) -> list[dict]:
    out = []
    for p in perf:
        if not isinstance(p, dict):
            continue
        info = p.get("gameInformation") or {}
        if (info.get("season") or {}).get("id") != season:
            continue
        if info.get("isNationalGame") and not national:
            continue
        out.append(p)
    return out


def summarize(games: list[dict]) -> dict:
    """試合の並びから、出場・先発・出場時間・得点・アシスト・評価点の平均を数える。"""
    played = [g for g in games if ((g.get("statistics") or {}).get("generalStatistics") or {}).get("participationState") == "played"]
    minutes = goals = assists = starts = 0
    grades: list[float] = []
    for g in played:
        st = g.get("statistics") or {}
        pt = st.get("playingTimeStatistics") or {}
        gl = st.get("goalStatistics") or {}
        ge = st.get("generalStatistics") or {}
        minutes += int(pt.get("playedMinutes") or 0)
        starts += 1 if pt.get("isStarting") else 0
        goals += int(gl.get("goalsScoredTotal") or 0)
        assists += int(gl.get("assists") or 0)
        if ge.get("grade"):
            grades.append(float(ge["grade"]))
    bench = sum(1 for g in games if ((g.get("statistics") or {}).get("generalStatistics") or {}).get("participationState") == "on_bench")
    injured = sum(1 for g in games if ((g.get("statistics") or {}).get("generalStatistics") or {}).get("participationState") == "injured")
    return dict(games=len(games), played=len(played), starts=starts, minutes=minutes, goals=goals,
                assists=assists, grade=round(sum(grades) / len(grades), 2) if grades else None,
                bench=bench, injured=injured)


def in_window(games: list[dict], start: datetime.date, end: datetime.date) -> list[dict]:
    out = []
    for g in games:
        when = ((g.get("gameInformation") or {}).get("date") or {}).get("dateTimeUTC") or ""
        try:
            day = datetime.datetime.fromisoformat(when.replace("Z", "+00:00")).astimezone(
                datetime.timezone(datetime.timedelta(hours=9))).date()
        except ValueError:
            continue
        if start <= day <= end:
            out.append(g)
    return out


_club_cache: dict[str, dict] = {}
_club_ja: dict[str, str] | None = None


def club_ja(name: str) -> str:
    """Transfermarkt の英語名を、config/clubs.yaml の別名辞書で日本語にする。無ければそのまま。"""
    global _club_ja
    if _club_ja is None:
        _club_ja = {}
        book = yaml.safe_load((ROOT / "config" / "clubs.yaml").read_text(encoding="utf-8")) or {}
        for club in book.get("clubs") or []:
            for aka in [club.get("canonical", "")] + list(club.get("aka") or []):
                _club_ja[str(aka).lower()] = club["canonical"]
    low = name.lower()
    if low in _club_ja:
        return _club_ja[low]
    for aka, canon in _club_ja.items():
        if len(aka) >= 6 and aka in low:
            return canon
    return name


def clean_name(passport: str, fallback: str) -> str:
    """パスポート名にローマ字や記号が混ざるときは、Wikidata の日本語名を使う。"""
    passport = (passport or "").replace(" ", "").replace("　", "")
    if passport and not any(ch.isascii() for ch in passport):
        return passport
    return fallback.replace(" ", "") or passport


def club_info(club_id: str) -> dict:
    if club_id not in _club_cache:
        data = _get(f"/club/{club_id}")
        base = data.get("baseDetails") or {}
        _club_cache[club_id] = dict(name=data.get("name") or "", country=base.get("countryId"),
                                    competition=base.get("primaryCompetitionId") or "")
    return _club_cache[club_id]


def build_roster() -> list[dict]:
    ids: dict[str, str] = dict(EXTRA)
    if CANDIDATES.exists():
        for name, tm, _clubs in json.loads(CANDIDATES.read_text(encoding="utf-8")):
            ids.setdefault(str(tm), name)
    rows = []
    for tm, fallback in ids.items():
        profile = _get(f"/player/{tm}")
        games = games_of(tm)
        if not games:
            continue
        club_id = collections.Counter(
            str(((g.get("statistics") or {}).get("generalStatistics") or {}).get("primaryClubId") or "")
            for g in games).most_common(1)[0][0]
        club = club_info(club_id) if club_id else {}
        if not club or club.get("country") == JAPAN or str(club.get("competition", "")) not in MAJOR:
            continue
        passport = (profile.get("nationalityDetails") or {}).get("passportName") or ""
        attrs = profile.get("attributes") or {}
        rows.append(dict(
            name=clean_name(passport, fallback), tm=str(tm), club=club_ja(club["name"]), club_en=club["name"], club_id=club_id,
            competition=club.get("competition", ""),
            position=((attrs.get("position") or {}).get("category") or ""),
            dob=((profile.get("lifeDates") or {}).get("dateOfBirth") or ""),
            **summarize(games)))
        time.sleep(0.2)
    rows.sort(key=lambda r: -r["minutes"])
    return rows


def week_rows(roster: list[dict], end: datetime.date, days: int = 7, national: bool = False) -> list[dict]:
    start = end - datetime.timedelta(days=days - 1)
    out = []
    for r in roster:
        perf = _get(f"/player/{r['tm']}/performance-game?season={SEASON}").get("performance") or []
        games = split_games(perf, SEASON, national=False)
        week = in_window(split_games(perf, SEASON, national=national), start, end)
        item = dict(name=r["name"], club=r["club"], competition=r.get("competition", ""),
                    week=summarize(week), season=summarize(games),
                    matches=[_match_line(g) for g in week])
        out.append(item)
        time.sleep(0.2)
    out.sort(key=lambda x: (-x["week"]["minutes"], -x["season"]["minutes"]))
    return out


def _match_line(g: dict) -> dict:
    info = g.get("gameInformation") or {}
    clubs = g.get("clubsInformation") or {}
    own = clubs.get("club") or {}
    st = g.get("statistics") or {}
    ge = st.get("generalStatistics") or {}
    pt = st.get("playingTimeStatistics") or {}
    gl = st.get("goalStatistics") or {}
    return dict(date=((info.get("date") or {}).get("dateTimeUTC") or "")[:10],
                competition=COMPETITIONS.get(info.get("competitionId", ""), info.get("competitionId", "")),
                score=f"{own.get('goalsTotal')}-{own.get('opponentGoalsTotal')}" if own else "",
                venue=own.get("venue", ""), state=ge.get("participationState"),
                minutes=int(pt.get("playedMinutes") or 0), starting=bool(pt.get("isStarting")),
                goals=int(gl.get("goalsScoredTotal") or 0), assists=int(gl.get("assists") or 0),
                grade=ge.get("grade"))


def table_rows(rows: list[dict], limit: int = 12) -> list[list[str]]:
    """取材メモの表（選手・所属・今週・出場時間・得点／アシスト）。出た人だけ。"""
    out = []
    for r in rows[:limit]:
        w = r["week"]
        if w["games"] == 0:
            continue
        shown = f"{w['played']}試合（先発{w['starts']}）" if w["played"] else ("けが" if w["injured"] else "出番なし")
        out.append([r["name"], r["club"], shown, f"{w['minutes']}分", f"{w['goals']}G {w['assists']}A"])
    return out


def write_note(rows: list[dict], end: datetime.date, path: Path) -> None:
    start = end - datetime.timedelta(days=6)
    top = [r for r in rows if r["week"]["games"]][:3]
    note = {
        "date": end.strftime("%Y年%m月%d日"),
        "slot": "japanese_1",
        "format": "news",
        "series": "欧州組の1週間",
        "people": [r["name"] for r in top],
        "theme": {
            "id": f"weekly_{end.strftime('%m%d')}",
            "league": "england", "league_name": "欧州各リーグ", "kind": "other", "topic": "日本代表",
            "title": f"欧州組の1週間（{start.month}月{start.day}日〜{end.month}月{end.day}日）。いちばん出た日本人は",
            "question": "この1週間、欧州の日本人選手は誰がどれだけ出て、何が変わったのか",
            "takeaway": "（数字で比べて分かったことを1文で）",
        },
        "short_title": f"欧州組の1週間 {start.month}/{start.day}〜{end.month}/{end.day}",
        "thumbnail": {"line1": "欧州組の1週間", "line2": "いちばん出たのは●●", "photos": []},
        "sections": [
            {"id": "table", "heading": "今週の出場", "tier": "報道", "main": True,
             "telop": "この1週間の出場時間と得点",
             "narrator": "キャスター",
             "card": {"type": "table", "title": f"欧州組の1週間（{start.month}/{start.day}〜{end.month}/{end.day}）",
                      "columns": ["選手", "所属", "今週", "出場時間", "得点"],
                      "rows": table_rows(rows)},
             "say": [{"text": "（ショート用の前置き1行）", "short_only": True},
                     "（表の上から順に、数字を読む。3〜5行）"],
             "sources": [f"https://www.transfermarkt.jp/{r['name']}/leistungsdaten/spieler/{r.get('tm', '')}" for r in rows[:1]] or ["https://www.transfermarkt.jp/"]},
        ] + [
            {"id": f"deep{i + 1}", "heading": f"{r['name']}", "tier": "報道",
             "telop": f"{r['name']}（{r['club']}）", "narrator": "解説",
             "say": [f"（{r['name']}の今週：{r['week']['played']}試合 {r['week']['minutes']}分 {r['week']['goals']}G{r['week']['assists']}A。今季 {r['season']['minutes']}分。何が変わったかを数字で）"],
             "sources": ["https://www.transfermarkt.jp/"]}
            for i, r in enumerate(top)
        ] + [
            {"id": "view", "heading": "見立て", "tier": "背景", "viewpoint": True, "narrator": "解説",
             "say": ["（数字で比べて分かったこと・次の1週間で何を見るか）"],
             "sources": ["https://www.transfermarkt.jp/"]},
        ],
    }
    path.write_text(yaml.safe_dump(note, allow_unicode=True, sort_keys=False), encoding="utf-8")


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("roster")
    w = sub.add_parser("week")
    w.add_argument("--to", required=True, help="週の最後の日（YYYY-MM-DD）")
    w.add_argument("--days", type=int, default=7)
    w.add_argument("--note", help="取材メモの雛形を書く先")
    w.add_argument("--national", action="store_true", help="代表戦も数える（代表ウィーク用）")
    args = ap.parse_args(argv)
    if args.cmd == "roster":
        rows = build_roster()
        ROSTER.parent.mkdir(parents=True, exist_ok=True)
        ROSTER.write_text(yaml.safe_dump({"season": SEASON, "players": rows}, allow_unicode=True, sort_keys=False),
                          encoding="utf-8")
        print(f"名簿 {len(rows)}人 → {ROSTER}")
        for r in rows[:40]:
            print(f"  {r['minutes']:5}分 {r['played']:2}試合 {r['goals']}G{r['assists']}A  {r['name']}（{r['club']}／{COMPETITIONS.get(r['competition'], r['competition'])}）")
        return 0
    roster = (yaml.safe_load(ROSTER.read_text(encoding="utf-8")) or {}).get("players") or []
    end = datetime.date.fromisoformat(args.to)
    rows = week_rows(roster, end, args.days, national=args.national)
    WEEKLY_DIR.mkdir(parents=True, exist_ok=True)
    out = WEEKLY_DIR / f"{args.to}.json"
    out.write_text(json.dumps(rows, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"■ 欧州組の1週間（〜{args.to}）→ {out}")
    for r in rows:
        w = r["week"]
        if not w["games"]:
            continue
        print(f"  {w['minutes']:4}分 {w['played']}試合(先発{w['starts']}) {w['goals']}G{w['assists']}A 評価{w['grade'] or '-'}  {r['name']}（{r['club']}）")
    if args.note:
        write_note(rows, end, Path(args.note))
        print(f"取材メモの雛形: {args.note}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
