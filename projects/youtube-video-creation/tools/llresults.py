"""ラ・リーガの今季の試合結果を、ESPN の試合データからまとめて取る（2026-09-27）。

    CLUB_LEAGUE=laliga python tools/llresults.py            # 開幕から昨日まで
    CLUB_LEAGUE=laliga python tools/llresults.py --since 2026-08-14

**なぜ要るか。**「今季のここまで」の節は、各クラブの英語版シーズン記事の試合の箱から
組み立てている（`plsquad.results`）。ところがラ・リーガは**シーズン記事が無いクラブがある**
（エスパニョール・アラベスなど）うえ、あっても試合を書き足していない記事がある。
そのクラブの試合は、相手の記事に載っているものしか拾えず、「1試合を終えて1敗」のような
誤った文になっていた（エスパニョール・バレンシア・アトレティコの台本で発覚）。

ESPN の試合データには**節の番号が無い**。そこで節は次の順で決める。
各クラブの `<key>_raw.json` の results の番号を票にして、`assign` が決める（そちらの説明を参照）

書き出し先は `research/ll_data/results.json`（`[日付, 節, ホーム, スコア, アウェー]` の並び。
クラブ名は clubs.json の英語版記事名）。`plbuild.pl_games` が raw と合わせて読む。
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import sys
import time
from collections import Counter
from pathlib import Path

import requests

sys.path.insert(0, str(Path(__file__).resolve().parent))
import clubleague  # noqa: E402

DATA = clubleague.data_dir()
URL = "https://site.api.espn.com/apis/site/v2/sports/soccer/esp.1/scoreboard?dates={day}"
# ESPN の表記 → clubs.json の英語版記事名（名前の合わないものだけ）
ESPN_TO_WIKI = {
    "Athletic Club": "Athletic Bilbao",
    "Celta Vigo": "RC Celta de Vigo",
    "Alavés": "Deportivo Alavés",
    "Racing Santander": "Racing de Santander",
    "Deportivo": "Deportivo de A Coruña",
    "Deportivo La Coruña": "Deportivo de A Coruña",
    "Deportivo A Coruña": "Deportivo de A Coruña",
    "Espanyol": "RCD Espanyol",
    "Real Madrid": "Real Madrid CF",
    "Barcelona": "FC Barcelona",
    "Atlético Madrid": "Atlético Madrid",
    "Sevilla": "Sevilla FC",
    "Valencia": "Valencia CF",
    "Villarreal": "Villarreal CF",
    "Getafe": "Getafe CF",
    "Elche": "Elche CF",
    "Levante": "Levante UD",
    "Málaga": "Málaga CF",
    "Osasuna": "CA Osasuna",
}


def _wiki_titles() -> list[str]:
    got = json.loads((DATA / "clubs.json").read_text(encoding="utf-8"))
    rows = got.get("clubs", got) if isinstance(got, dict) else got
    return [r["wiki_title"] for r in rows]


def to_wiki(name: str, titles: list[str]) -> str:
    if name in ESPN_TO_WIKI:
        return ESPN_TO_WIKI[name]
    for t in titles:
        if name == t or name in t or t in name:
            return t
    raise SystemExit(f"■ ESPN の「{name}」が clubs.json のどのクラブか分かりません。ESPN_TO_WIKI に足してください")


def fetch(since: dt.date, until: dt.date, titles: list[str]) -> list[dict]:
    games, day = [], since
    while day <= until:
        for attempt in range(3):
            try:
                ev = requests.get(URL.format(day=day.strftime("%Y%m%d")), timeout=30).json().get("events", [])
                break
            except (requests.RequestException, ValueError):
                time.sleep(5)
        else:
            raise SystemExit(f"■ {day} の試合が取れません")
        for e in ev:
            c = e["competitions"][0]
            if c["status"]["type"]["name"] != "STATUS_FULL_TIME":
                continue
            side = {t["homeAway"]: t for t in c["competitors"]}
            games.append({"when": e["date"], "day": day.isoformat(),
                          "home": to_wiki(side["home"]["team"]["displayName"], titles),
                          "away": to_wiki(side["away"]["team"]["displayName"], titles),
                          "score": f"{side['home']['score']}–{side['away']['score']}"})
        day += dt.timedelta(days=1)
    return sorted(games, key=lambda g: g["when"])


def known_rounds(titles: list[str]) -> dict:
    """raw の results から、(日付, ホーム, アウェー) → 節の票（Counter）。

    **日付まで合わせる。**親善試合にも `round=` を振る記事があり、同じ組み合わせの
    親善試合の番号を拾うと節がずれた（アスレティック対アトレティコが「第6節」になった）
    """
    import plbuild  # noqa: E402  （clubleague を読むので遅らせる）
    out: dict = {}
    for p in DATA.glob("*_raw.json"):
        for date, rnd, t1, score, t2 in json.loads(p.read_text(encoding="utf-8")).get("results", []):
            if not str(rnd).strip().isdigit():
                continue
            h = next((t for t in titles if plbuild.club_matches(t1, t)), None)
            a = next((t for t in titles if plbuild.club_matches(t2, t)), None)
            if h and a:
                out.setdefault((str(date).split("|")[0].strip(), h, a), Counter())[int(rnd)] += 1
    return out


def _label(iso: str) -> str:
    return f"{int(iso[8:10])} {dt.date.fromisoformat(iso).strftime('%B')} {iso[:4]}"


def _key(g: dict) -> tuple:
    return (_label(g["day"]), g["home"], g["away"])


def assign(games: list[dict], known: dict) -> None:
    """節を決める。**1節に1クラブ1試合**と、節ごとの日付の真ん中を使う（2026-09-27）。

    記事の番号は1試合ずつだと当てにならない（レアル・マドリードの記事は「そのクラブの
    何試合目か」を書いていて、エスパニョール戦が「1」）。日付順に塊で切る形も、延期で
    早めに消化した試合が1つ混ざると区切りが崩れた（ソシエダ対セルタの9月3日）。
    1. 票の節の日付の真ん中から4日以内なら、その節
    2. 残りは、票の節か、日付の近い節から順に、両クラブともまだその節に試合が無いところ
    """
    for g in games:
        g["date"] = dt.date.fromisoformat(g["day"])
        votes = known.get(_key(g))
        g["vote"] = votes.most_common(1)[0][0] if votes else None
    by_round: dict = {}
    for g in games:
        if g["vote"]:
            by_round.setdefault(g["vote"], []).append(g["date"].toordinal())
    med = {r: sorted(v)[len(v) // 2] for r, v in by_round.items()}
    taken: set = set()

    def put(g, r):
        g["round"] = r
        taken.update({(r, g["home"]), (r, g["away"])})

    rest = []
    for g in games:
        v = g["vote"]
        if v and abs(g["date"].toordinal() - med[v]) <= 4 and not {(v, g["home"]), (v, g["away"])} & taken:
            put(g, v)
        else:
            rest.append(g)
    for g in rest:
        order = ([g["vote"]] if g["vote"] else []) + sorted(med, key=lambda r: abs(med[r] - g["date"].toordinal()))
        r = next((r for r in order if not {(r, g["home"]), (r, g["away"])} & taken), None)
        if r is None:
            raise SystemExit(f"■ 節が決まりません: {_key(g)}")
        put(g, r)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--since", default="2026-08-14")
    ap.add_argument("--until", default=(dt.date.today() - dt.timedelta(days=1)).isoformat())
    args = ap.parse_args()
    titles = _wiki_titles()
    games = fetch(dt.date.fromisoformat(args.since), dt.date.fromisoformat(args.until), titles)
    assign(games, known_rounds(titles))
    rows = [[_label(g["day"]), str(g["round"]), g["home"], g["score"], g["away"]] for g in games]
    (DATA / "results.json").write_text(json.dumps({"source": "ESPN scoreboard (esp.1)",
                                                   "fetched": dt.date.today().isoformat(),
                                                   "results": rows}, ensure_ascii=False, indent=1),
                                       encoding="utf-8")
    per = Counter(t for r in rows for t in (r[2], r[4]))
    print(f"{len(rows)}試合 / 節 {sorted(set(int(r[1]) for r in rows))}")
    print("  クラブごとの試合数:", dict(sorted(per.items())))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
