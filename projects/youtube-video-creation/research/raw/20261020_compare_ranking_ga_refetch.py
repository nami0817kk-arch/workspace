"""比べる（ランキング）前線8人の今季リーグ戦の得点＋アシストを ESPN 公開API から取り直して並べる（2026-10-19 作成）。

    python research/raw/20261020_compare_ranking_ga_refetch.py

出力: 出場時間・得点・アシスト・PK得点、自分で割った90分あたり、合計と90分あたりと「PK抜き」の順位。
台本（research/20261020_compare_ranking_ga.yaml）の数字と突き合わせる。**公開の朝にもう1回流す**。
ESPN の選手の今季成績（statistics/0）の値。試合ごとの記録（keyEvents・rosters）で確かめ済みの選手は、その旨を控え
（research/raw/20261020_compare_ranking_ga.md）に書いた。Sergio Camello だけ ESPN の集計（8試合495分）が
リーグ戦7試合の記録（470分）と合わない。
"""
import json
import time
import urllib.request

PLAYERS = [
    ("ラフィーニャ", "esp.1", 231050),
    ("ヤマル", "esp.1", 362150),
    ("エムバペ", "esp.1", 231388),
    ("トーヴァン", "fra.1", 156898),
    ("シナヨコ", "fra.1", 271137),
    ("ハーランド", "eng.1", 253989),
    ("カメージョ", "esp.1", 276652),
    ("ジョアン・ペドロ", "eng.1", 284960),
    ("（外した）ケイン", "ger.1", 142200),
    ("（外した）デンベレ", "fra.1", 229744),
]


def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    return json.load(urllib.request.urlopen(req, timeout=30))


rows = []
for name, league, pid in PLAYERS:
    st = get(f"https://sports.core.api.espn.com/v2/sports/soccer/leagues/{league}/seasons/2026/types/1/athletes/{pid}/statistics/0")
    f = {s["name"]: s["value"] for c in st["splits"]["categories"] for s in c["stats"]}
    m, g, a, pk, ap = f["minutes"], f["totalGoals"], f["goalAssists"], f["penaltyKickGoals"], f["appearances"]
    rows.append(dict(name=name, apps=ap, min=m, g=g, a=a, pk=pk, ga=g + a, per90=(g + a) * 90 / m,
                     nopk=g + a - pk, nopk90=(g + a - pk) * 90 / m))
    time.sleep(0.3)

main = [r for r in rows if not r["name"].startswith("（")]
print("名前 試合 分 得点 ア PK 合計 90分あたり PK抜き PK抜き90")
for r in rows:
    print(f"{r['name']} {r['apps']:.0f} {r['min']:.0f} {r['g']:.0f} {r['a']:.0f} {r['pk']:.0f} {r['ga']:.0f} {r['per90']:.2f} {r['nopk']:.0f} {r['nopk90']:.2f}")
for key, label in (("ga", "合計"), ("per90", "90分あたり"), ("nopk", "PK抜き合計"), ("nopk90", "PK抜き90分あたり")):
    order = sorted(main, key=lambda r: -r[key])
    print(label, [r["name"] for r in order])
