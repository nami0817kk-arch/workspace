"""チャンネル名 → /videos の新しい順(最大 pages ページ)と人気順 30 本を JSON に書く。python ytch2.py 名前の一覧.txt out.json [pages]"""
import re, json, sys, time, urllib.request, urllib.parse
H = {"User-Agent": "Mozilla/5.0", "Accept-Language": "ja"}
def page(url):
    html = urllib.request.urlopen(urllib.request.Request(url, headers=H), timeout=30).read().decode("utf-8")
    d = json.loads(re.search(r"var ytInitialData = (\{.*?\});</script>", html).group(1))
    key = re.search(r'"INNERTUBE_API_KEY":"([^"]+)"', html).group(1)
    ver = re.search(r'"INNERTUBE_CLIENT_VERSION":"([^"]+)"', html).group(1)
    return d, key, ver
def cont(token, key, ver):
    body = json.dumps({"context": {"client": {"clientName": "WEB", "clientVersion": ver, "hl": "ja", "gl": "JP"}}, "continuation": token}).encode()
    req = urllib.request.Request("https://www.youtube.com/youtubei/v1/browse?prettyPrint=false&key=" + key, data=body, headers={**H, "Content-Type": "application/json"})
    return json.loads(urllib.request.urlopen(req, timeout=30).read().decode("utf-8"))
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
def days(ago):
    m = re.match(r"(\d+)\s*(分|時間|日|週間|か月|年)", ago)
    if not m: return None
    k = int(m.group(1))
    return {"分": 0, "時間": 0, "日": k, "週間": 7 * k, "か月": 30 * k, "年": 365 * k}[m.group(2)]
def rows_of(d):
    out = []
    for m in find(d, "lockupMetadataViewModel", []):
        parts = [p for r in m.get("metadata", {}).get("contentMetadataViewModel", {}).get("metadataRows", []) for p in r.get("metadataParts", [])]
        lab = [p.get("accessibilityLabel") or p.get("text", {}).get("content", "") for p in parts]
        n = next((num(x) for x in lab if "視聴" in x and re.search(r"\d", x)), None)
        ago = next((x for x in lab if re.search(r"(分|時間|日|週間|か月|年)前", x)), "")
        if n is not None: out.append(dict(t=m["title"]["content"], n=n, ago=ago, d=days(ago)))
    return out
def next_token(d):
    for c in find(d, "continuationItemRenderer", []):
        t = find(c, "token", [])
        if t: return t[0]
names = [l.strip() for l in open(sys.argv[1], encoding="utf-8") if l.strip()]
pages = int(sys.argv[3]) if len(sys.argv) > 3 else 3
res = {}
for name in names:
    try:
        d, _, _ = page("https://www.youtube.com/results?search_query=" + urllib.parse.quote(name) + "&sp=EgIQAg%3D%3D")
        ch = find(d, "channelRenderer", [])
        c = next((x for x in ch if name[:5] in x["title"]["simpleText"]), ch[0])
        base = c["navigationEndpoint"]["browseEndpoint"].get("canonicalBaseUrl") or "/channel/" + c["channelId"]
        v, key, ver = page("https://www.youtube.com" + base + "/videos")
        new = rows_of(v); tok = next_token(v)
        for _ in range(pages - 1):
            if not tok: break
            x = cont(tok, key, ver); new += rows_of(x); tok = next_token(x); time.sleep(0.4)
        pop = []
        chips = find(v, "chipViewModel", [])
        pc = next((ch_ for ch_ in chips if "人気" in ch_.get("text", "")), None)
        if pc:
            t = find(pc, "token", [])
            if t: pop = rows_of(cont(t[0], key, ver))
        res[c["title"]["simpleText"]] = dict(base=base, subs=c.get("videoCountText", {}).get("simpleText", ""), new=new, pop=pop)
        print(name, len(new), len(pop), flush=True)
    except Exception as e:
        print("err", name, repr(e)[:120], flush=True)
    time.sleep(0.6)
json.dump(res, open(sys.argv[2], "w", encoding="utf-8"), ensure_ascii=False, indent=0)
