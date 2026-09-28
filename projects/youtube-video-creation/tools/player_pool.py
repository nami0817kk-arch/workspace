"""有名選手の紹介（毎日1人、10月の案21）の人選一覧を作る。2026-09-28。

    python tools/player_pool.py build                 # 5大リーグの上位・ビッグクラブの選手を控える（10分ほど。控えは使い回す）
    python tools/player_pool.py list --count 31       # 市場価値の順に、リーグとクラブをばらして並べる（○×はユーザー）

人選の物差しは **Transfermarkt の市場価値**（好き嫌いで選ばない。プレミア紹介の「有名」を代表出場数で
決めたのと同じ筋）。日本語名は Wikidata の日本語ラベル（Transfermarkt の番号 P2446 で引く）。
呼び方が日本の媒体とちがう人（ホランド → ハーランド）は `research/kana/players.json` が上書きする。

- 控え: `research/player_pool/profiles/<id>.json`（1人1つ。2回目からは取りに行かない）と `research/player_pool.json`
- 一覧に入れるクラブ: 各リーグの順位表で **6位まで**か、`config/clubs.yaml` で `big: true` のクラブ
- バロンドール候補は API に無い（`nominees` は golden_boy だけ）。候補の一覧は手で書く
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import sys
import time
from pathlib import Path

import requests

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from src import clubs as clubs_mod  # noqa: E402

_spec = importlib.util.spec_from_file_location("japan_abroad", ROOT / "tools" / "japan_abroad.py")
ja_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(ja_mod)

COMPETITIONS = {"GB1": "england", "ES1": "spain", "L1": "germany", "IT1": "italy", "FR1": "france"}
TOP_RANK = 6
POOL = ROOT / "research" / "player_pool.json"
PROFILES = ROOT / "research" / "player_pool" / "profiles"
KANA_OVERRIDE = ROOT / "research" / "kana" / "players.json"
WIKIDATA = "https://query.wikidata.org/sparql"

POSITION_JA = {
    "Goalkeeper": "GK", "Centre-Back": "センターバック", "Left-Back": "左サイドバック", "Right-Back": "右サイドバック",
    "Defensive Midfield": "守備的MF", "Central Midfield": "セントラルMF", "Attacking Midfield": "攻撃的MF",
    "Left Midfield": "左MF", "Right Midfield": "右MF", "Left Winger": "左ウイング", "Right Winger": "右ウイング",
    "Centre-Forward": "センターフォワード", "Second Striker": "セカンドストライカー",
}


def league_clubs(competition: str) -> list[dict]:
    """順位表からクラブ番号と順位。"""
    tables = ja_mod._get(f"/competition/{competition}/table").get("tables") or []
    out = []
    for row in (tables[0].get("clubs") if tables else []) or []:
        out.append(dict(club_id=str(row.get("clubId")), rank=int((row.get("ranking") or {}).get("current") or 99)))
    return out


def club_name(club_id: str) -> str:
    data = ja_mod._get(f"/club/{club_id}")
    return str(data.get("name") or club_id)


def is_big(name_ja: str) -> bool:
    found = clubs_mod.find(name_ja)
    return bool(found and found[0].big)


def profile(player_id: str) -> dict:
    """選手の詳細。控えがあればそれを読む。"""
    PROFILES.mkdir(parents=True, exist_ok=True)
    path = PROFILES / f"{player_id}.json"
    if path.exists():
        return json.loads(path.read_text(encoding="utf-8"))
    data = ja_mod._get(f"/player/{player_id}")
    if data:
        path.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
        time.sleep(0.15)
    return data


def row_of(data: dict, club: str, club_id: str, league: str) -> dict | None:
    attrs = data.get("attributes") or {}
    mv = ((data.get("marketValueDetails") or {}).get("current") or {}).get("value") or 0
    life = data.get("lifeDates") or {}
    position = (attrs.get("position") or {}).get("name") or ""
    if not data.get("name"):
        return None
    return dict(id=str(data["id"]), name=str(data["name"]), ja="", club=club, club_id=club_id, league=league,
                age=life.get("age"), birth=life.get("dateOfBirth"), position=POSITION_JA.get(position, position),
                value=int(mv), contract=attrs.get("contractUntil"), captain=False)


def japanese_names(ids: list[str]) -> dict[str, str]:
    """Wikidata の日本語ラベルを、Transfermarkt の番号で100人ずつ引く。"""
    out: dict[str, str] = {}
    for at in range(0, len(ids), 100):
        chunk = " ".join(f'"{i}"' for i in ids[at:at + 100])
        query = ('SELECT ?tm ?ja WHERE { VALUES ?tm { ' + chunk + ' } ?p wdt:P2446 ?tm . '
                 '?p rdfs:label ?ja FILTER(lang(?ja)="ja") }')
        try:
            got = requests.get(WIKIDATA, params={"query": query, "format": "json"},
                               headers={"User-Agent": "yt-video-creation/1.0 (research)"}, timeout=60)
            for b in got.json().get("results", {}).get("bindings", []):
                out[b["tm"]["value"]] = b["ja"]["value"]
        except (requests.RequestException, ValueError):
            pass
        time.sleep(1)
    return out


def overrides() -> dict[str, str]:
    """日本の媒体の呼び方（英語名 → カタカナ）。Wikidata のラベルより優先。"""
    try:
        return json.loads(KANA_OVERRIDE.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def build() -> list[dict]:
    rows: list[dict] = []
    for competition, league in COMPETITIONS.items():
        for entry in league_clubs(competition):
            name = ja_mod.club_ja(club_name(entry["club_id"]))
            if entry["rank"] > TOP_RANK and not is_big(name):
                continue
            squad = ja_mod._get(f"/club/{entry['club_id']}/squad?season={ja_mod.SEASON}").get("squad") or []
            print(f"{league:>8} {entry['rank']:>2}位 {name}: {len(squad)}人", flush=True)
            for member in squad:
                data = profile(str(member.get("playerId")))
                row = row_of(data, name, entry["club_id"], league)
                if row:
                    row["captain"] = bool(member.get("isCaptain"))
                    rows.append(row)
    labels = japanese_names([r["id"] for r in rows])
    over = overrides()
    for r in rows:
        r["ja"] = over.get(r["name"]) or labels.get(r["id"], "")
    rows.sort(key=lambda r: -r["value"])
    POOL.write_text(json.dumps(rows, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"{len(rows)}人 → {POOL}（日本語名あり {sum(1 for r in rows if r['ja'])}人）")
    return rows


def pick(rows: list[dict], count: int, per_club: int = 2, per_league_run: int = 1) -> list[dict]:
    """市場価値の順に、同じリーグが続かず・同じクラブは2人までになるよう並べる。"""
    chosen: list[dict] = []
    used_club: dict[str, int] = {}
    pool = sorted(rows, key=lambda r: -r["value"])
    last_league = ""
    while pool and len(chosen) < count:
        for i, r in enumerate(pool):
            if used_club.get(r["club"], 0) >= per_club:
                continue
            if r["league"] == last_league and any(x["league"] != last_league and used_club.get(x["club"], 0) < per_club for x in pool):
                continue
            chosen.append(pool.pop(i))
            used_club[r["club"]] = used_club.get(r["club"], 0) + 1
            last_league = r["league"]
            break
        else:
            break
    return chosen


LEAGUE_JA = {"england": "プレミア", "spain": "ラ・リーガ", "germany": "ブンデス", "italy": "セリエA", "france": "リーグ・アン"}


def page_spec(rows: list[dict], key: str, title: str) -> dict:
    """○×のページ（tools/pages.py topics）に渡す一覧。番号だけ振って出す（○×はユーザー）。"""
    items = []
    for i, r in enumerate(rows, 1):
        why = f"{r['position']}・{r['age']}歳・市場価値 €{r['value'] / 1e6:.0f}M"
        if r.get("contract"):
            why += f"・契約 {str(r['contract'])[:4]}年まで"
        if r.get("captain"):
            why += "・主将"
        items.append(dict(num=i, head=f"{r['ja'] or r['name']}（{r['club']}）", slot=LEAGUE_JA.get(r["league"], r["league"]),
                          fmt="紹介", why=why, url=f"https://www.transfermarkt.com/-/profil/spieler/{r['id']}",
                          src="Transfermarkt"))
    return dict(title=title, lead="市場価値の順にリーグとクラブをばらして並べた。○を付けた人から毎日1人",
                labels=["○ 作る", "△ 保留", "✖ 外す"], legend=False,
                note="数字は Transfermarkt（市場価値・年齢・契約）。日本語名は Wikidata。呼び方が違えば直す", items=items)


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("build")
    lp = sub.add_parser("list")
    lp.add_argument("--count", type=int, default=31)
    lp.add_argument("--per-club", type=int, default=2)
    pg = sub.add_parser("page", help="○×のページの元（tools/pages.py topics に渡す yaml）を書く")
    pg.add_argument("--count", type=int, default=31)
    pg.add_argument("--per-club", type=int, default=2)
    pg.add_argument("--key", default="players202610")
    args = ap.parse_args(argv)
    if args.cmd == "build":
        build()
        return 0
    rows = json.loads(POOL.read_text(encoding="utf-8"))
    # 呼び方の上書きとクラブ名の辞書は、控えを作り直さなくても読むときに当てる
    over = overrides()
    for r in rows:
        r["ja"] = over.get(r["name"]) or r["ja"]
        r["club"] = ja_mod.club_ja(r["club"])
    if args.cmd == "page":
        import yaml

        spec = page_spec(pick(rows, args.count, args.per_club), args.key, "有名選手の紹介・10月の人選")
        out = ROOT / "research" / f"_{args.key}.yaml"
        out.write_text(yaml.safe_dump(spec, allow_unicode=True, sort_keys=False), encoding="utf-8")
        print(f"{out}"); print(f"次: python tools/pages.py topics {args.key} {out}")
        return 0
    for i, r in enumerate(pick(rows, args.count, args.per_club), 1):
        print(f"{i:>2}. {r['ja'] or r['name']}（{r['club']}／{r['position']}／{r['age']}歳／€{r['value'] / 1e6:.0f}M）")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
