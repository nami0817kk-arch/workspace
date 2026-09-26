"""日ごとの登録者・再生・視聴時間（Analytics。Data API の枠は使わない）"""
import sys, json, io, datetime
sys.path.insert(0, ".")
from src import insights
api = insights.service()
today = datetime.date.today()
start = today - datetime.timedelta(days=21)
r = api.reports().query(
    ids="channel==MINE", startDate=start.isoformat(), endDate=today.isoformat(),
    dimensions="day",
    metrics="views,estimatedMinutesWatched,subscribersGained,subscribersLost,likes,comments",
).execute()
rows = r.get("rows", [])
print("day       views  minutes  +sub -sub  likes cmts")
for d, v, m, sg, sl, lk, cm in rows:
    print(f"{d}  {v:>5}  {m:>7.0f}  {sg:>4} {sl:>4}  {lk:>5} {cm:>4}")
io.open(sys.argv[1], "w", encoding="utf-8").write(json.dumps(rows, ensure_ascii=False))
