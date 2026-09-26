"""総再生時間を測る（2026-09-15）。

**収益化で効くのは本編の視聴時間だけ。**ショートの視聴時間は
4,000時間の条件に数えられない（別枠の「90日で1,000万回」を見る）。
だから合計だけ出しても意味が無く、**本編とショートに割って**出す。

割り方は動画の尺。60秒以下をショートとみなす（`road.py` と同じ物差し）。
Analytics には creatorContentType という分け方もあるが、
**このチャンネルの尺の基準と食い違うことがある**ので、自前の印を使う。

    python tools/metrics/watchtime.py research/metrics/<日付>/watch.json

Analytics は **Data API とは別の枠**なので、ここは枠を食わない。
ただし **分析は2〜3日遅れる**ので、今日ぶんは入らない。
"""
import datetime
import io
import json
import sys

sys.path.insert(0, ".")

from src import insights  # noqa: E402

api = insights.service()
today = datetime.date.today()
START = "2026-09-01"          # チャンネルの最初の投稿より前

# 動画ごとの視聴時間。**本編とショートを分けるために1本ずつ取る**
rows, token = [], None
while True:
    r = api.reports().query(
        ids="channel==MINE", startDate=START, endDate=today.isoformat(),
        dimensions="video", metrics="views,estimatedMinutesWatched",
        maxResults=200, sort="-estimatedMinutesWatched",
        startIndex=len(rows) + 1,
    ).execute()
    got = r.get("rows", [])
    rows += got
    if len(got) < 200:
        break

# 尺の印は road.py の控えから借りる。無ければ全部まとめて出す
kinds = {}
try:
    book = json.load(io.open(sys.argv[2] if len(sys.argv) > 2
                             else "research/metrics/20260914/raw_videos.json",
                             encoding="utf-8"))
    kinds = {v["id"]: v["short"] for v in book["videos"]}
except (OSError, KeyError, IndexError):
    pass

short_min = sum(m for vid, _, m in rows if kinds.get(vid))
main_min = sum(m for vid, _, m in rows if kinds.get(vid) is False)
unknown_min = sum(m for vid, _, m in rows if vid not in kinds)

print(f"期間　　　{START} 〜 {today}（分析は2〜3日遅れる）")
print(f"動画　　　{len(rows)}本ぶんの記録")
print()
print(f"本編　　　{main_min / 60:9.1f} 時間　← **収益化に数えられるのはここだけ**")
print(f"ショート　{short_min / 60:9.1f} 時間　（4,000時間には数えられない）")
if unknown_min:
    print(f"不明　　　{unknown_min / 60:9.1f} 時間　（尺の控えに無い動画）")
print(f"合計　　　{(main_min + short_min + unknown_min) / 60:9.1f} 時間")
print()
need = 4000 - main_min / 60
if main_min:
    days = need / (main_min / 60 / 10)        # 10日ぶんの実績から
    print(f"4,000時間まで あと {need:,.0f} 時間。いまのペースだと約 {days:,.0f} 日")

if len(sys.argv) > 1:
    io.open(sys.argv[1], "w", encoding="utf-8").write(json.dumps(
        dict(start=START, end=today.isoformat(),
             main_minutes=main_min, short_minutes=short_min,
             unknown_minutes=unknown_min, rows=rows),
        ensure_ascii=False))
