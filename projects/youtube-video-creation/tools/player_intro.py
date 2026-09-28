"""有名選手の紹介（毎日1人、10月の案21）の取材メモの雛形。2026-09-28。

    python tools/player_intro.py 342229 --date 2026-10-01     # Transfermarkt の番号（player_pool.py list に出る）

材料は Transfermarkt（詳細・市場価値の推移・今季の大会別の数字）と Wikidata の日本語名。
節は「基礎DATA（表）→ 歩んできた道（季ごとの所属と市場価値の表）→ 今季の数字（大会別の表、main）
→ 見立て」。**紹介ものなので他人の声は無くてよい。**顔写真は記事か Commons から人が取る
（`tools/articlephoto.py` → `portrait`）。雛形の `thumbnail.photos` は空で出す。

- 選手名の日本語は `player_pool.py` と同じ（Wikidata → `research/kana/players.json` で上書き）
- クラブ名は `config/clubs.yaml` の日本語（無ければ Transfermarkt の英語のまま。雛形の頭に出る）
- 数字はすべて Transfermarkt のものなので、出典はその選手のページ1本。**成績の節は 報道 で書く**
"""

from __future__ import annotations

import argparse
import datetime
import importlib.util
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

_spec = importlib.util.spec_from_file_location("player_pool", ROOT / "tools" / "player_pool.py")
pool_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(pool_mod)
ja_mod = pool_mod.ja_mod

TM_URL = "https://www.transfermarkt.jp/{slug}/profil/spieler/{id}"
FOOT_JA = {"right": "右", "left": "左", "both": "両足"}
# 代表の大会など、japan_abroad の一覧に無い大会の番号
COMPETITIONS_EXTRA = {"UNLA": "ネーションズリーグA", "UNLB": "ネーションズリーグB", "WMQE": "W杯予選（欧州）",
                      "EMQ": "ユーロ予選", "USC": "UEFAスーパーカップ", "KLUB": "クラブワールドカップ",
                      "SUC": "スペイン・スーパーカップ", "CDR": "国王杯", "FRC": "フランス・スーパーカップ",
                      "GBCS": "コミュニティ・シールド", "DFL": "DFLスーパーカップ", "ISC": "イタリア・スーパーカップ"}


def competition_ja(comp: str) -> str:
    return ja_mod.COMPETITIONS.get(comp) or COMPETITIONS_EXTRA.get(comp) or comp


def compact_value(value: int) -> str:
    """市場価値を「2億ユーロ」「3500万ユーロ」の形に。"""
    if value >= 100_000_000:
        oku = value / 100_000_000
        return f"{oku:.1f}".rstrip("0").rstrip(".") + "億ユーロ"
    if value >= 10_000:
        return f"{value // 10_000}万ユーロ"
    return f"{value}ユーロ"


def club_ja(club_id: str) -> str:
    return ja_mod.club_ja(ja_mod.club_info(str(club_id)).get("name") or str(club_id))


def career_rows(history: list[dict]) -> list[list[str]]:
    """市場価値の推移から、季ごとの所属を1クラブ1行にまとめる（季・クラブ・年齢・市場価値）。"""
    rows: list[list[str]] = []
    runs: list[dict] = []
    for e in sorted(history, key=lambda x: (int(x.get("seasonId") or 0), str(x.get("marketValue", {}).get("determined") or ""))):
        club = str(e.get("clubId") or "")
        season = int(e.get("seasonId") or 0)
        value = int((e.get("marketValue") or {}).get("value") or 0)
        club_name = club_ja(club)
        if runs and runs[-1]["name"] == club_name:
            runs[-1]["to"] = season
            runs[-1]["peak"] = max(runs[-1]["peak"], value)
            runs[-1]["last"] = value
            runs[-1]["age_to"] = e.get("age")
        else:
            runs.append(dict(club=club, name=club_name, frm=season, to=season, peak=value, last=value,
                             age_from=e.get("age"), age_to=e.get("age")))
    for r in runs:
        seasons = f"{r['frm'] % 100:02d}/{(r['frm'] + 1) % 100:02d}" + (f"〜{r['to'] % 100:02d}/{(r['to'] + 1) % 100:02d}" if r["to"] != r["frm"] else "")
        ages = f"{r['age_from']}歳" + (f"〜{r['age_to']}歳" if r["age_to"] != r["age_from"] else "")
        rows.append([seasons, r["name"], ages, f"最高 {compact_value(r['peak'])}"])
    return rows


def season_rows(performance: list[dict]) -> list[list[str]]:
    """今季の大会別の数字（大会・試合・得点・アシスト・出場時間）。"""
    rows = []
    for p in performance:
        info = p.get("generalInformation") or {}
        st = p.get("statistics") or {}
        goals, play = st.get("goalStatistics") or {}, st.get("playingTimeStatistics") or {}
        comp = info.get("competitionId") or ""
        rows.append([competition_ja(comp), str(play.get("appearancesCount") or 0),
                     str(goals.get("goalsSum") or 0), str(goals.get("assistsSum") or 0), f"{play.get('playedMinutesSum') or 0}分"])
    return rows


def totals(aggregated: dict) -> dict:
    goals, play = aggregated.get("goalStatistics") or {}, aggregated.get("playingTimeStatistics") or {}
    return dict(apps=int(play.get("appearancesCount") or 0), goals=int(goals.get("goalsSum") or 0),
                assists=int(goals.get("assistsSum") or 0), minutes=int(play.get("playedMinutesSum") or 0))


def gather(player_id: str) -> dict:
    data = pool_mod.profile(player_id)
    attrs = data.get("attributes") or {}
    life = data.get("lifeDates") or {}
    current = next((c for c in data.get("clubAssignments") or [] if c.get("type") == "current"), {})
    club = club_ja(current.get("clubId")) if current.get("clubId") else ""
    history = ja_mod._get(f"/player/{player_id}/market-value-history").get("history") or []
    season = ja_mod._get(f"/player/{player_id}/performance-season?season={ja_mod.SEASON}")
    labels = pool_mod.japanese_names([player_id])
    name_ja = pool_mod.overrides().get(data.get("name", "")) or labels.get(player_id, "")
    return dict(
        id=player_id, name=str(data.get("name") or ""), ja=name_ja, club=club, club_id=str(current.get("clubId") or ""),
        shirt=current.get("shirtNumber"), captain=bool(current.get("isCaptain")),
        age=life.get("age"), birth=life.get("dateOfBirth"), height=attrs.get("height"),
        foot=FOOT_JA.get((attrs.get("preferredFoot") or {}).get("name", ""), ""),
        position=pool_mod.POSITION_JA.get((attrs.get("position") or {}).get("name", ""), (attrs.get("position") or {}).get("name", "")),
        contract=attrs.get("contractUntil"), value=int(((data.get("marketValueDetails") or {}).get("current") or {}).get("value") or 0),
        value_prev=int(((data.get("marketValueDetails") or {}).get("previous") or {}).get("value") or 0),
        history=history, season=season.get("performance") or [], aggregated=season.get("aggregated") or {},
        url=str(data.get("relativeUrl") or ""),
    )


def write_note(p: dict, day: datetime.date, path: Path) -> list[str]:
    """雛形を書く。返すのは、英語のまま残った名前（選手・クラブ）。"""
    name = p["ja"] or p["name"]
    url = "https://www.transfermarkt.com" + p["url"] if p["url"].startswith("/") else "https://www.transfermarkt.com/"
    tot = totals(p["aggregated"])
    birth = p["birth"] or ""
    birth_ja = f"{birth[:4]}年{int(birth[5:7])}月{int(birth[8:10])}日" if len(birth) == 10 else birth
    data_rows = [["所属", p["club"] + (f"（{p['shirt']}番）" if p["shirt"] else "")],
                 ["ポジション", p["position"]],
                 ["生年月日", f"{birth_ja}（{p['age']}歳）"],
                 ["身長", f"{p['height']}m" if p["height"] else ""],
                 ["利き足", p["foot"]],
                 ["契約", f"{p['contract'][:4]}年まで" if p["contract"] else ""],
                 ["市場価値", compact_value(p["value"])]]
    data_rows = [r for r in data_rows if r[1]]
    career = career_rows(p["history"])
    season = season_rows(p["season"])
    value_move = ""
    if p["value_prev"] and p["value"] != p["value_prev"]:
        value_move = f"市場価値は前回の{compact_value(p['value_prev'])}から{compact_value(p['value'])}に{'上がりました' if p['value'] > p['value_prev'] else '下がりました'}。"
    sections = [
        {"id": "data", "heading": "基礎DATA", "tier": "報道", "telop": f"{name}の基礎DATA", "narrator": "キャスター",
         "card": {"type": "table", "title": f"{name}（{p['club']}）", "columns": ["項目", "内容"], "rows": data_rows,
                  "source": "Transfermarkt"},
         "say": [f"{name}、{p['age']}歳。{p['club']}の{p['position']}です。"]
                + ([f"身長{p['height']}m、利き足は{p['foot']}。"] if p["height"] and p["foot"] else [])
                + ([f"市場価値は{compact_value(p['value'])}。"] if p["value"] else [])
                + ([value_move] if value_move else []),
         "sources": [url]},
        {"id": "career", "heading": "歩んできた道", "tier": "報道", "telop": "季ごとの所属と市場価値", "narrator": "解説",
         "card": {"type": "table", "title": "歩んできた道", "columns": ["季", "クラブ", "年齢", "市場価値"], "rows": career[-6:],
                  "source": "Transfermarkt"},
         "say": [f"（{name}が{len(career)}クラブを渡ってきた道を、表の上から順に。どこで値が跳ねたか）"],
         "sources": [url]},
        {"id": "season", "heading": "今季の数字", "tier": "報道", "main": True, "telop": "今季ここまで", "narrator": "解説",
         "card": {"type": "table", "title": f"{name} 今季の数字", "columns": ["大会", "試合", "得点", "アシスト", "出場時間"],
                  "rows": season, "source": "Transfermarkt"},
         "say": [{"text": f"（前置き1行：{name}はいまどういう選手か、を一言で）", "short_only": True},
                 f"今季はここまで{tot['apps']}試合で{tot['goals']}得点{tot['assists']}アシスト、{tot['minutes']}分です。"]
                + [f"{r[0]}は{r[1]}試合で{r[2]}得点{r[3]}アシスト。" for r in season[:3]],
         "sources": [url]},
        {"id": "view", "heading": "見立て", "tier": "背景", "viewpoint": True, "narrator": "解説", "telop": "この選手の見どころ",
         "say": [f"（{name}の数字から見えること・次に何を見るか。同じ位置の選手と比べる数字を1つ）"],
         "sources": [url]},
    ]
    note = {
        "date": day.strftime("%Y年%m月%d日"),
        "slot": "other_1",
        "format": "news",
        "series": "有名選手の紹介",
        "people": [name],
        "theme": {
            "id": f"player_{p['id']}", "league": next((r["league"] for r in _pool_rows() if r["id"] == p["id"]), "england"),
            "kind": "other", "topic": p["club"],
            "title": f"{name}ってどんな選手？数字で見る",
            "question": f"{name}はどんな選手で、いま数字はどうなっているのか",
            "takeaway": "（数字で分かったことを1文で）",
        },
        "short_title": f"{name}ってどんな選手？",
        "thumbnail": {"line1": name, "line2": "●●の数字", "tags": [p["club"]], "photos": []},
        "sections": sections,
    }
    unknown = [n for n in [p["name"] if not p["ja"] else ""] + [r[1] for r in career if r[1].isascii()] if n]
    head = [f"# {name}（{p['club']}）の紹介。数字は Transfermarkt（{url}）。",
            "# 顔写真は記事か Commons から取って thumbnail.photos に置く（tools/articlephoto.py → portrait）。"]
    if unknown:
        head.append("# 日本語にする（辞書に無い名前）: " + "、".join(dict.fromkeys(unknown)))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(head) + "\n" + yaml.safe_dump(note, allow_unicode=True, sort_keys=False, width=100),
                    encoding="utf-8")
    return unknown


def _pool_rows() -> list[dict]:
    import json

    try:
        return json.loads(pool_mod.POOL.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return []


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("player_id")
    ap.add_argument("--date", default=datetime.date.today().isoformat())
    args = ap.parse_args(argv)
    day = datetime.date.fromisoformat(args.date)
    p = gather(args.player_id)
    path = ROOT / "research" / f"{day.strftime('%Y%m%d')}_player_{args.player_id}.yaml"
    unknown = write_note(p, day, path)
    print(f"取材メモ → {path}")
    print(f"  {p['ja'] or p['name']}（{p['club']}／{p['position']}／{p['age']}歳／{compact_value(p['value'])}）")
    for r in career_rows(p["history"]):
        print("   ", "  ".join(r))
    if unknown:
        print("日本語にする: " + "、".join(dict.fromkeys(unknown)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
