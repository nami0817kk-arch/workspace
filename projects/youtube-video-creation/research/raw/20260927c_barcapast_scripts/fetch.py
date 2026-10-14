import json, re, requests, time, sys
PJ = r"C:\Users\なみ\dev\wt-yt-0906\projects\youtube-video-creation\research\ll_data"
UA = {"User-Agent": "tsuruhashi-research/0.1 (contact via github)"}
clubs = json.load(open(PJ + r"\clubs.json", encoding="utf-8"))["clubs"]
players = []
for cl in clubs:
    if cl["key"] == "barcelona": continue
    r = json.load(open(PJ + "\\" + cl["key"] + "_raw.json", encoding="utf-8"))
    for p in r["squad"]:
        players.append(dict(club=cl["key"], **p))
titles = sorted(set(p["page"] for p in players if p.get("page")))
print(len(players), len(titles), "no page:", [p["name"] for p in players if not p.get("page")])
out = {}
for i in range(0, len(titles), 50):
    batch = titles[i:i+50]
    resp = requests.get("https://en.wikipedia.org/w/api.php", params=dict(action="query", prop="revisions", rvprop="content|timestamp", rvslots="main", format="json", formatversion=2, redirects=1, titles="|".join(batch)), headers=UA, timeout=60).json()
    q = resp["query"]
    norm = {n["from"]: n["to"] for n in q.get("normalized", [])}
    redir = {n["from"]: n["to"] for n in q.get("redirects", [])}
    pages = {pg["title"]: pg for pg in q["pages"]}
    for t in batch:
        t2 = norm.get(t, t); t3 = redir.get(t2, t2)
        pg = pages.get(t3)
        if not pg or pg.get("missing"):
            out[t] = None; continue
        rv = pg["revisions"][0]
        out[t] = {"resolved": t3, "ts": rv["timestamp"], "text": rv["slots"]["main"]["content"]}
    time.sleep(1)
json.dump({"players": players, "pages": out}, open("pages.json", "w", encoding="utf-8"), ensure_ascii=False)
print("missing:", [t for t, v in out.items() if v is None])
