"""欧州5大リーグの今季リーグ戦 得点+アシストの単純ランキング（2026-10-20）。ESPN 公開API。
python research/raw/20261020_compare_ranking_ga_top.py
各リーグの得点上位50・アシスト上位50を読み、選手ごとに合計を自分で足す。足切りなし。
上位選手は選手の今季成績（statistics/0）で出場試合・分・PK得点を取り直す。"""
import json, time, urllib.request
LG = ["esp.1", "eng.1", "ger.1", "ita.1", "fra.1"]
def get(u):
    return json.load(urllib.request.urlopen(urllib.request.Request(u, headers={"User-Agent": "Mozilla/5.0"}), timeout=30))
P = {}
for lg in LG:
    j = get(f"https://site.web.api.espn.com/apis/site/v2/sports/soccer/{lg}/statistics")
    print(lg, j["timestamp"])
    for blk in j["stats"]:
        for e in blk["leaders"]:
            a = e["athlete"]
            d = P.setdefault((lg, a["id"]), dict(name=a["displayName"], lg=lg, id=a["id"], club=a.get("team", {}).get("displayName", "") if isinstance(a.get("team"), dict) else "", g=None, a=None))
            v = e.get("value", e.get("displayValue"))
            d["g" if blk["name"] == "goalsLeaders" else "a"] = v
rows = []
for d in P.values():
    # 片方の上位50に入らなかった側は、選手の成績で補う（上位候補だけ）
    rows.append(d)
def stat(d):
    st = get(f"https://sports.core.api.espn.com/v2/sports/soccer/leagues/{d['lg']}/seasons/2026/types/1/athletes/{d['id']}/statistics/0")
    f = {s["name"]: s["value"] for c in st["splits"]["categories"] for s in c["stats"]}
    d.update(apps=f.get("appearances", 0), min=f.get("minutes", 0), G=f.get("totalGoals", 0), A=f.get("goalAssists", 0), PK=f.get("penaltyKickGoals", 0))
    time.sleep(.2)
# 粗い合計で上位40を候補にして、全員の成績を取り直す
def rough(d): return (d["g"] or 0) + (d["a"] or 0)
cand = sorted(rows, key=rough, reverse=True)[:40]
for d in cand: stat(d)
cand.sort(key=lambda d: (-(d["G"] + d["A"]), d["min"]))
print("順位 名前 リーグ 試合 分 得点 ア PK 合計")
for d in cand[:20]:
    print(d["name"], d["lg"], d["club"], int(d["apps"]), int(d["min"]), int(d["G"]), int(d["A"]), int(d["PK"]), int(d["G"] + d["A"]))
json.dump(cand, open("research/raw/20261020_compare_ranking_ga_top.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
