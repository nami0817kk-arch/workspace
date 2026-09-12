"""ショートと本編を分けて、日ごとの再生と視聴時間を出す（収益化の条件が別なので）"""
import sys, datetime
sys.path.insert(0, ".")
from src import insights
api = insights.service()
today = datetime.date.today()
start = today - datetime.timedelta(days=30)
r = api.reports().query(
    ids="channel==MINE", startDate=start.isoformat(), endDate=today.isoformat(),
    dimensions="day,creatorContentType",
    metrics="views,estimatedMinutesWatched",
).execute()
print("day        type              views  minutes")
tot = {}
for d, t, v, m in r.get("rows", []):
    print(f"{d}  {t:<16} {v:>6}  {m:>7.0f}")
    a = tot.setdefault(t, [0, 0.0]); a[0] += v; a[1] += m
print()
for t, (v, m) in tot.items():
    print(f"合計 {t:<16} 再生{v:>7}  視聴{m/60:>8.1f}時間")
