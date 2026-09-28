"""日本人の次の相手（試合の2日前、10月の案14）。2026-09-28。

    python tools/next_opponent.py --date 2026-10-01              # 翌日から3日のあいだの、日本人のいるクラブの試合を並べる
    python tools/next_opponent.py --date 2026-10-01 --match 5881180   # 1試合の雛形を書く

材料は FotMob（日程・直近5試合・過去の対戦・スタジアム）と、欧州組の名簿（`config/japan_abroad.yaml`。
そのクラブにいる日本人と今季の数字）。5大リーグは `research/standings/` の控えから順位と勝点も出す。
節は「相手はどんなクラブか（表）→ 直近5試合（両クラブの表）→ 過去の対戦（表）→ この試合の日本人（main）→ 見立て」。
**選ぶのは人**（一覧の中から1試合）。
"""

from __future__ import annotations

import argparse
import datetime
import importlib.util
import json
import sys
from pathlib import Path

import requests
import yaml

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from src import standings as standings_mod  # noqa: E402

_spec = importlib.util.spec_from_file_location("standings_week", ROOT / "tools" / "standings_week.py")
sw = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(sw)

# 日本人のいるリーグの FotMob 番号（5大＋エールディビジ・ベルギー・ポルトガル・スコットランド・チャンピオンシップ）
LEAGUE_IDS = {**standings_mod.LEAGUE_IDS, "belgium": 40, "portugal": 61, "scotland": 64, "championship": 48}
# 欧州カップ（前日の相手紹介、案18）。--all で日本人のいないクラブの試合も並ぶ
CUP_IDS = {"cl": 42, "el": 73, "ecl": 10216}
LEAGUE_JA = {**standings_mod.LEAGUE_NAMES_JA, "belgium": "ベルギー1部", "portugal": "ポルトガル1部",
             "scotland": "スコットランド1部", "championship": "イングランド2部",
             "cl": "チャンピオンズリーグ", "el": "ヨーロッパリーグ", "ecl": "カンファレンスリーグ"}
ROSTER = ROOT / "config" / "japan_abroad.yaml"
JST = datetime.timezone(datetime.timedelta(hours=9))


def _get(path: str, params: dict) -> dict:
    got = requests.get(f"{standings_mod.BASE}/{path}", params=params, headers={"User-Agent": standings_mod.UA},
                       timeout=standings_mod.TIMEOUT)
    got.raise_for_status()
    return got.json()


def roster() -> list[dict]:
    return (yaml.safe_load(ROSTER.read_text(encoding="utf-8")) or {}).get("players") or []


def same_club(fotmob_name: str, player: dict) -> bool:
    """FotMob のクラブ名と名簿のクラブが同じか（日本語の正規名で比べ、無ければ英語の部分一致）。"""
    ja = standings_mod.japanese(fotmob_name)
    if ja == player.get("club") and not ja.isascii():
        return True
    en = str(player.get("club_en") or "").lower()
    fm = fotmob_name.lower()
    return bool(en) and (en in fm or fm in en)


def fixtures(day: datetime.date, days: int = 3, cups: bool = True, everyone: bool = False) -> list[dict]:
    """翌日から days 日のあいだの、日本人のいるクラブの試合（everyone なら全部）。cups で欧州カップも見る。"""
    players = roster()
    start, end = day + datetime.timedelta(days=1), day + datetime.timedelta(days=days)
    out = []
    pool = {**LEAGUE_IDS, **(CUP_IDS if cups else {})}
    for league, lid in pool.items():
        payload = _get("leagues", {"id": lid})
        for m in ((payload.get("fixtures") or {}).get("allMatches") or []):
            when = str((m.get("status") or {}).get("utcTime") or "")[:10]
            if not when or not (start.isoformat() <= when <= end.isoformat()) or (m.get("status") or {}).get("finished"):
                continue
            home, away = (m.get("home") or {}).get("name", ""), (m.get("away") or {}).get("name", "")
            who = {"home": [p["name"] for p in players if same_club(home, p)],
                   "away": [p["name"] for p in players if same_club(away, p)]}
            if who["home"] or who["away"] or everyone:
                out.append(dict(id=str(m.get("id")), league=league, utc=str((m.get("status") or {}).get("utcTime") or ""),
                                home=home, away=away, home_ja=standings_mod.japanese(home), away_ja=standings_mod.japanese(away),
                                japanese=who))
    return sorted(out, key=lambda x: x["utc"])


def jst(utc: str) -> str:
    try:
        t = datetime.datetime.fromisoformat(utc.replace("Z", "+00:00")).astimezone(JST)
        return f"{t.month}月{t.day}日 {t.hour}:{t.minute:02d}"
    except ValueError:
        return utc


def form_rows(entries: list[dict], side_id: str) -> list[list[str]]:
    """直近5試合（日付・相手・スコア・結果）。"""
    rows = []
    for e in entries or []:
        tip = e.get("tooltipText") or {}
        home_is_me = str(tip.get("homeTeamId")) == str(side_id)
        opp = tip.get("awayTeam") if home_is_me else tip.get("homeTeam")
        score = f"{tip.get('homeScore')}-{tip.get('awayScore')}" if home_is_me else f"{tip.get('awayScore')}-{tip.get('homeScore')}"
        date = str(tip.get("utcTime") or "")[:10]
        rows.append([f"{int(date[5:7])}/{int(date[8:10])}" if len(date) == 10 else date, standings_mod.japanese(str(opp or "")),
                     score, {"W": "○", "D": "△", "L": "●"}.get(str(e.get("resultString")), str(e.get("resultString")))])
    return rows


def h2h_rows(h2h: dict, limit: int = 5) -> tuple[list[list[str]], list[int]]:
    rows = []
    for m in h2h.get("matches") or []:
        st = m.get("status") or {}
        if not st.get("finished"):
            continue
        date = str(st.get("utcTime") or "")[:10]
        rows.append([date[:4] + "/" + str(int(date[5:7])) + "/" + str(int(date[8:10])) if len(date) == 10 else date,
                     standings_mod.japanese((m.get("home") or {}).get("name", "")), str(st.get("scoreStr") or ""),
                     standings_mod.japanese((m.get("away") or {}).get("name", ""))])
        if len(rows) >= limit:
            break
    return rows, list(h2h.get("summary") or [0, 0, 0])


def standing_of(league: str, team: str, day: datetime.date) -> dict | None:
    """5大リーグなら控えの順位表から順位と勝点。"""
    if league not in sw.LEAGUES:
        return None
    got = sw.previous_snapshot(day + datetime.timedelta(days=1))
    if not got:
        return None
    for r in (got[1].get(league) or {}).get("rows", []):
        if r["team"] == team:
            return r
    return None


def gather(match_id: str, league: str, day: datetime.date) -> dict:
    payload = _get("matchDetails", {"matchId": match_id})
    g = payload.get("general") or {}
    c = payload.get("content") or {}
    mf = c.get("matchFacts") or {}
    home, away = g.get("homeTeam") or {}, g.get("awayTeam") or {}
    players = roster()
    form = mf.get("teamForm") or [[], []]
    rows, summary = h2h_rows(c.get("h2h") or {})
    return dict(
        id=str(match_id), league=league, utc=str(g.get("matchTimeUTCDate") or ""),
        home=home.get("name", ""), away=away.get("name", ""), home_id=str(home.get("id")), away_id=str(away.get("id")),
        home_ja=standings_mod.japanese(home.get("name", "")), away_ja=standings_mod.japanese(away.get("name", "")),
        stadium=((mf.get("infoBox") or {}).get("Stadium") or {}).get("name", ""),
        japanese={"home": [p for p in players if same_club(home.get("name", ""), p)],
                  "away": [p for p in players if same_club(away.get("name", ""), p)]},
        form={"home": form_rows(form[0] if len(form) > 0 else [], str(home.get("id"))),
              "away": form_rows(form[1] if len(form) > 1 else [], str(away.get("id")))},
        h2h=rows, h2h_summary=summary,
        standing={"home": standing_of(league, home.get("name", ""), day), "away": standing_of(league, away.get("name", ""), day)},
    )


def write_note(m: dict, day: datetime.date, path: Path) -> None:
    ours = "home" if m["japanese"]["home"] or not m["japanese"]["away"] else "away"
    theirs = "away" if ours == "home" else "home"
    us, them = m[f"{ours}_ja"], m[f"{theirs}_ja"]
    jp = m["japanese"][ours]
    # 日本人がいない試合（欧州カップの相手紹介）は、クラブそのものを主役にする
    lead = jp[0] if jp else dict(name=us, tm="", played=0, starts=0, minutes=0, goals=0, assists=0)
    st = m["standing"][theirs]
    st_us = m["standing"][ours]
    league_ja = LEAGUE_JA.get(m["league"], m["league"])
    url = f"https://www.fotmob.com/matches/x/{m['id']}"
    wins = sum(1 for r in m["form"][theirs] if r[3] == "○")
    who = f"{lead['name']}の{us}" if jp else us   # 日本人がいなければクラブ名だけ（同じ名前を二度言わない）
    opp_rows = [["リーグ", league_ja]] + ([["順位", f"{st['rank']}位（勝点{st['points']}）"]] if st else []) \
        + [["直近5試合", f"{wins}勝{sum(1 for r in m['form'][theirs] if r[3] == '△')}分{sum(1 for r in m['form'][theirs] if r[3] == '●')}敗"],
           ["会場", m["stadium"] or "（未取得）"]]
    ws, ds, ls = m["h2h_summary"]
    # summary は「ホーム側の勝ち・引き分け・アウェイ側の勝ち」
    our_wins, their_wins = (ws, ls) if ours == "home" else (ls, ws)
    sections = [
        {"id": "opponent", "heading": f"相手の{them}はいま", "tier": "確定", "official": True, "telop": f"次の相手 {them}", "narrator": "キャスター",
         "card": {"type": "table", "title": f"{them}の今", "columns": ["項目", "内容"], "rows": opp_rows, "source": "FotMob"},
         "say": [f"{jst(m['utc'])}、{who}は{them}と対戦します。"]
                + ([f"{them}はいま{league_ja}{st['rank']}位、勝点{st['points']}。"] if st else [f"{them}は{league_ja}のクラブです。"])
                + ([f"こちらの{us}は{st_us['rank']}位、勝点{st_us['points']}です。"] if st_us else []),
         "sources": [url]},
        {"id": "form", "heading": "直近5試合", "tier": "確定", "official": True, "telop": f"{them}の直近5試合", "narrator": "解説",
         # 直近の記録が無い試合（欧州カップの初戦など）は表を出さない（空の表は draft が止める）
         **({"card": {"type": "table", "title": f"{them}の直近5試合", "columns": ["日付", "相手", "スコア", "結果"],
                      "rows": m["form"][theirs], "source": "FotMob"}} if m["form"][theirs] else {}),
         "say": [f"{who}が当たる{them}、直近5試合は{wins}勝。", "（表の上から、勝ち方と負け方を1つずつ）"],
         "sources": [url]},
        {"id": "h2h", "heading": "過去の対戦", "tier": "確定", "official": True, "telop": f"{us}対{them}の過去", "narrator": "解説",
         **({"card": {"type": "table", "title": "過去の対戦", "columns": ["日付", "ホーム", "スコア", "アウェイ"], "rows": m["h2h"],
                      "source": "FotMob"}} if m["h2h"] else {}),
         "say": [f"{who}と{them}、過去の対戦は{our_wins}勝{ds}分{their_wins}敗です。", "（直近の1試合で何が起きたか）"],
         "sources": [url]},
        # 日本人のいない試合（欧州カップの相手紹介）は、主役のクラブが勝つための数字の節にする
        {"id": "keys", "heading": f"{us}が{them}に勝つには", "tier": "報道", "main": True, "telop": f"{us}の勝ち筋", "narrator": "解説",
         "say": [{"text": f"（前置き1行：{us}の次は{them}戦）", "short_only": True},
                 "（相手の弱点と自分の強みを、数字で2〜3行。得点王の控えも使える）"],
         "sources": [url]} if not jp else {
         "id": "japan", "heading": f"{lead['name']}の今季", "tier": "報道", "main": True, "telop": f"{lead['name']}（{us}）", "narrator": "解説",
         "card": {"type": "table", "title": f"{us}の日本人 今季", "columns": ["選手", "試合（先発）", "出場時間", "得点"],
                  "rows": [[p["name"], f"{p.get('played', 0)}試合（先発{p.get('starts', 0)}）", f"{p.get('minutes', 0)}分",
                            f"{p.get('goals', 0)}G {p.get('assists', 0)}A"] for p in jp], "source": "Transfermarkt"},
         "say": [{"text": f"（前置き1行：{lead['name']}の{us}、次は{them}戦）", "short_only": True},
                 f"{lead['name']}は今季{lead.get('played', 0)}試合で{lead.get('minutes', 0)}分、{lead.get('goals', 0)}得点{lead.get('assists', 0)}アシスト。",
                 "（この相手に対して何が鍵か。相手の弱点と本人の役割を数字で）"],
         "sources": [f"https://www.transfermarkt.jp/-/leistungsdaten/spieler/{lead.get('tm', '')}"]},
        {"id": "view", "heading": "見立て", "tier": "背景", "viewpoint": True, "narrator": "解説", "telop": "この試合で見るところ",
         "say": [f"（{lead['name']}がこの試合で何をすれば勝てるか。数字を1つ）"],
         "sources": [url]},
    ]
    note = {
        "date": day.strftime("%Y年%m月%d日"), "slot": "japanese_1" if jp else "other_1", "format": "news",
        "series": "日本人の次の相手" if jp else "欧州カップの相手紹介",
        "people": [p["name"] for p in jp],
        "theme": {"id": f"next_{m['id']}", "league": m["league"] if m["league"] in standings_mod.LEAGUE_NAMES_JA else "england",
                  "league_name": league_ja, "kind": "preview", "topic": us,
                  "title": (f"{lead['name']}の{us}、次は{them}。相手はいまどんな状態か" if jp
                      else f"{us}の次は{them}。数字で見ると、どんな相手か"),
                  "question": f"{us}が次に当たる{them}は、数字で見るとどんな相手か",
                  "takeaway": "（相手の数字から見えることを1文で）"},
        "short_title": f"{lead['name']}、次は{them}戦",
        "thumbnail": {"line1": f"{lead['name']}の次の相手", "line2": f"{them}の●●", "tags": [us, them], "photos": []},
        "sections": sections,
    }
    head = [f"# {us} 対 {them}（{jst(m['utc'])} 日本時間、{league_ja}）。数字は FotMob、日本人の今季は Transfermarkt。",
            "# 顔写真は記事か Commons から（thumbnail.photos）。相手の得点王は tools/scorers.py の控えで足せる。"]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(head) + "\n" + yaml.safe_dump(note, allow_unicode=True, sort_keys=False, width=100), encoding="utf-8")


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--date", default=datetime.date.today().isoformat())
    ap.add_argument("--days", type=int, default=3)
    ap.add_argument("--match")
    ap.add_argument("--league", help="--match のリーグ（一覧に出る鍵。省略すると5大リーグから探す）")
    ap.add_argument("--all", action="store_true", help="日本人のいないクラブの試合も並べる（欧州カップの相手紹介用）")
    args = ap.parse_args(argv)
    day = datetime.date.fromisoformat(args.date)
    if not args.match:
        found = fixtures(day, args.days, everyone=args.all)
        print(f"{day} の翌日から{args.days}日、{'全部の' if args.all else '日本人のいるクラブの'}試合 {len(found)}（--match <id> --league <鍵> で雛形）")
        for f in found:
            who = "・".join(f["japanese"]["home"] + f["japanese"]["away"])
            print(f"  {f['id']}  {jst(f['utc'])}  {f['home_ja']} 対 {f['away_ja']}（{LEAGUE_JA.get(f['league'], f['league'])}）  {who}  [{f['league']}]")
        return 0
    league = args.league or ""
    if not league:
        for f in fixtures(day, 14):
            if f["id"] == args.match:
                league = f["league"]
                break
    m = gather(args.match, league or "england", day)
    m["league"] = league or m["league"]
    if not (m["japanese"]["home"] or m["japanese"]["away"]) and not args.all:
        print("この試合に日本人のいるクラブが見つかりません（--all なら相手紹介として書きます）", file=sys.stderr)
        return 1
    path = ROOT / "research" / f"{day.strftime('%Y%m%d')}_next_{args.match}.yaml"
    write_note(m, day, path)
    print(f"取材メモ → {path}")
    print(f"  {m['home_ja']} 対 {m['away_ja']}  {jst(m['utc'])}  {m['stadium']}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
