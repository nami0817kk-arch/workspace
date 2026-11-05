"""YouTube の検索(今年・長さ20分超/4〜20分・再生数順)を語ごとに取って、直近の当たりを並べる。"""
import re, json, sys, time, urllib.request, urllib.parse
SP = {"long": "CAMSBAgFGAI%3D", "mid": "CAMSBAgFGAM%3D"}
def search(q, sp):
    url = "https://www.youtube.com/results?search_query=" + urllib.parse.quote(q) + "&sp=" + sp
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0", "Accept-Language": "ja"})
    html = urllib.request.urlopen(req, timeout=30).read().decode("utf-8")
    data = json.loads(re.search(r"var ytInitialData = (\{.*?\});</script>", html).group(1))
    out = []
    def walk(o):
        if isinstance(o, dict):
            if "videoRenderer" in o:
                v = o["videoRenderer"]
                n = int(re.sub(r"\D", "", v.get("viewCountText", {}).get("simpleText", "")) or 0)
                out.append(dict(id=v["videoId"], t="".join(r["text"] for r in v["title"]["runs"]), n=n,
                                ago=v.get("publishedTimeText", {}).get("simpleText", ""), len=v.get("lengthText", {}).get("simpleText", ""),
                                ch=v.get("ownerText", {}).get("runs", [{}])[0].get("text", ""), q=q))
            for x in o.values(): walk(x)
        elif isinstance(o, list):
            for x in o: walk(x)
    walk(data)
    return out
def months(ago):
    m = re.match(r"(\d+)\s*(分|時間|日|週間|か月|年)", ago)
    if not m: return 99
    k, u = int(m.group(1)), m.group(2)
    return {"分": 0, "時間": 0, "日": k / 30, "週間": k / 4.3, "か月": k, "年": 12 * k}[u]
Q = [l.strip() for l in open(sys.argv[1], encoding="utf-8") if l.strip()]
allv = {}
for q in Q:
    for kind, sp in SP.items():
        try:
            for r in search(q, sp):
                if months(r["ago"]) <= 3 and r["id"] not in allv:
                    allv[r["id"]] = r
        except Exception as e:
            print("err", q, e)
        time.sleep(0.6)
rows = sorted(allv.values(), key=lambda r: -r["n"])
json.dump(rows, open(sys.argv[2], "w", encoding="utf-8"), ensure_ascii=False, indent=0)
print(len(rows))
