"""動画ごとの成績（Analytics。Data API の枠は使わない）"""
import sys, json, io, datetime
sys.path.insert(0, ".")
from src import insights
api = insights.service()
today = datetime.date.today()
start = today - datetime.timedelta(days=30)
rows, tok = [], 0
while True:
    r = api.reports().query(
        ids="channel==MINE", startDate=start.isoformat(), endDate=today.isoformat(),
        dimensions="video", maxResults=200, startIndex=tok+1, sort="-views",
        metrics="views,estimatedMinutesWatched,averageViewDuration,averageViewPercentage,subscribersGained,likes",
    ).execute()
    got = r.get("rows", [])
    rows += got
    if len(got) < 200:
        break
    tok += 200
print("Analytics で測れた本数:", len(rows))
io.open(sys.argv[1], "w", encoding="utf-8").write(json.dumps(rows, ensure_ascii=False))
