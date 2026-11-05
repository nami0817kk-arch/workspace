"""チャンネル名 → 検索でチャンネルの URL を取り、/videos の新しい順(題名・再生数・日)を書き出す。"""
import re, json, sys, time, urllib.request, urllib.parse
H = {"User-Agent": "Mozilla/5.0", "Accept-Language": "ja"}
def get(url):
    html = urllib.request.urlopen(urllib.request.Request(url, headers=H), timeout=30).read().decode("utf-8")
    return json.loads(re.search(r"var ytInitialData = (\{.*?\});</script>", html).group(1))
def find(o, key, out):
    if isinstance(o, dict):
        if key in o: out.append(o[key])
        for x in o.values(): find(x, key, out)
    elif isinstance(o, list):
        for x in o: find(x, key, out)
    return out
def num(s):
    m = re.search(r"([\d.,]+)\s*(万|億)?", s)
    return int(float(m.group(1).replace(",", "")) * {"万": 1e4, "億": 1e8, None: 1}[m.group(2)])
names = [l.strip() for l in open(sys.argv[1], encoding="utf-8") if l.strip()]
with open(sys.argv[2], "w", encoding="utf-8") as f:
    for name in names:
        try:
            d = get("https://www.youtube.com/results?search_query=" + urllib.parse.quote(name) + "&sp=EgIQAg%3D%3D")
            ch = find(d, "channelRenderer", [])
            c = next((x for x in ch if name[:5] in x["title"]["simpleText"]), ch[0])
            base = c["navigationEndpoint"]["browseEndpoint"].get("canonicalBaseUrl") or "/channel/" + c["channelId"]
            subs = c.get("videoCountText", {}).get("simpleText", "")
            v = get("https://www.youtube.com" + base + "/videos")
            rows = []
            for m in find(v, "lockupMetadataViewModel", []):
                parts = [p for r in m.get("metadata", {}).get("contentMetadataViewModel", {}).get("metadataRows", []) for p in r.get("metadataParts", [])]
                lab = [p.get("accessibilityLabel") or p.get("text", {}).get("content", "") for p in parts]
                n = next((num(x) for x in lab if "視聴" in x and re.search(r"\d", x)), 0)
                ago = next((x for x in lab if re.search(r"(分|時間|日|週間|か月|年)前", x)), "")
                rows.append((n, ago, m["title"]["content"]))
            f.write(f"\n## {c['title']['simpleText']}（{subs}）{base}\n")
            for n, ago, t in rows:
                f.write(f"{n:>9,} | {ago:<7} | {t[:80]}\n")
            print(name, len(rows))
        except Exception as e:
            print("err", name, repr(e)[:100])
        time.sleep(0.8)
