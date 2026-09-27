import requests,re,json,time
PJ = r"C:\Users\なみ\dev\wt-yt-0906\projects\youtube-video-creation\research\ll_data"
UA={"User-Agent":"tsuruhashi-research/0.1"}
clubs=[c for c in json.load(open(PJ+r"\clubs.json",encoding="utf-8"))["clubs"] if c["key"]!="barcelona"]
d=json.load(open("pages.json",encoding="utf-8"))
insq={(p["club"],p["page"]) for p in d["players"]}
r=requests.get("https://en.wikipedia.org/w/api.php",params=dict(action="query",prop="revisions",rvprop="content|timestamp",rvslots="main",format="json",formatversion=2,redirects=1,titles="|".join(c["wiki_title"] for c in clubs)),headers=UA).json()
q=r["query"]; red={x["from"]:x["to"] for x in q.get("redirects",[])+q.get("normalized",[])}
pages={p["title"]:p for p in q["pages"]}
cand=[]
for c in clubs:
    t=pages[red.get(c["wiki_title"],c["wiki_title"])]["revisions"][0]["slots"]["main"]["content"]
    sec=""
    for line in t.split("\n"):
        h=re.match(r"^(=+)\s*(.*?)\s*=+\s*$",line)
        if h: sec=h.group(2); continue
        for m in re.finditer(r"\{\{[Ff]s player\|([^}]*)\}\}",line):
            nm=re.search(r"name=\s*\[\[([^|\]]+)",m.group(1))
            if not nm: continue
            pg=nm.group(1).strip()
            if (c["key"],pg) in insq: continue
            cand.append(dict(club=c["key"],page=pg,section=sec,raw=m.group(1)))
print(len(cand))
titles=sorted(set(x["page"] for x in cand))
txt={}
for i in range(0,len(titles),50):
    rr=requests.get("https://en.wikipedia.org/w/api.php",params=dict(action="query",prop="revisions",rvprop="content",rvslots="main",format="json",formatversion=2,redirects=1,titles="|".join(titles[i:i+50])),headers=UA).json()["query"]
    rd={x["from"]:x["to"] for x in rr.get("redirects",[])+rr.get("normalized",[])}
    pp={p["title"]:p for p in rr["pages"]}
    for t in titles[i:i+50]:
        p=pp.get(rd.get(t,t))
        txt[t]=None if (not p or p.get("missing")) else p["revisions"][0]["slots"]["main"]["content"]
    time.sleep(1)
for x in cand:
    t=txt.get(x["page"])
    if t is None: continue
    ib=re.findall(r"\|\s*(youthclubs\d+|clubs\d+)\s*=\s*([^\n|]*\[\[FC Barcelona[^\]]*\]\][^\n|]*)",t)
    if ib: print(x["club"],"|",x["section"],"|",x["page"],"|",ib)
