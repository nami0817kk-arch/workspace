"""1週間の実績から、収益化までの道のりを測る。
再生数は videos.list で1本ずつ取る（channels.list の合計は遅れるので使わない）。
登録者と視聴時間の日次は Analytics（枠が別）。"""
import sys, json, io, datetime
sys.path.insert(0, ".")
from src.upload import get_service
from src import quota
JST = datetime.timezone(datetime.timedelta(hours=9))
api = quota.counted(get_service())

ch = api.channels().list(part="contentDetails,statistics,snippet", mine=True).execute()["items"][0]
pl = ch["contentDetails"]["relatedPlaylists"]["uploads"]
ids, token = [], None
while True:
    r = api.playlistItems().list(part="contentDetails", playlistId=pl, maxResults=50, pageToken=token).execute()
    ids += [i["contentDetails"]["videoId"] for i in r["items"]]
    token = r.get("nextPageToken")
    if not token:
        break

vids = []
for i in range(0, len(ids), 50):
    r = api.videos().list(part="snippet,statistics,contentDetails,status",
                          id=",".join(ids[i:i+50]), maxResults=50).execute()
    for v in r["items"]:
        st = v["statistics"]
        dur = v["contentDetails"]["duration"]
        import re
        m = re.match(r"PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?", dur)
        secs = int(m.group(1) or 0)*3600 + int(m.group(2) or 0)*60 + int(m.group(3) or 0)
        pub = datetime.datetime.fromisoformat(v["snippet"]["publishedAt"].replace("Z","+00:00")).astimezone(JST)
        vids.append(dict(id=v["id"], title=v["snippet"]["title"], at=pub.isoformat(),
                         secs=secs, views=int(st.get("viewCount",0)),
                         likes=int(st.get("likeCount",0)),
                         comments=int(st.get("commentCount",0)),
                         privacy=v["status"]["privacyStatus"],
                         short=secs <= 60))
out = dict(channel=dict(title=ch["snippet"]["title"],
                        subs=int(ch["statistics"].get("subscriberCount",0)),
                        views=int(ch["statistics"].get("viewCount",0)),
                        videos=int(ch["statistics"].get("videoCount",0)),
                        started=ch["snippet"]["publishedAt"]),
           videos=vids)
io.open(sys.argv[1], "w", encoding="utf-8").write(json.dumps(out, ensure_ascii=False, indent=1))
print("動画", len(vids), "本 / 登録", out["channel"]["subs"])
