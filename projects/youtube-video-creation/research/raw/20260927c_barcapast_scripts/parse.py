import json, re
d = json.load(open("pages.json", encoding="utf-8"))
def infobox(text):
    i = text.lower().find("{{infobox football biography")
    if i < 0:
        i = text.lower().find("{{infobox")
        if i < 0: return None
    depth = 0; j = i
    while j < len(text):
        if text.startswith("{{", j): depth += 1; j += 2; continue
        if text.startswith("}}", j):
            depth -= 1; j += 2
            if depth == 0: break
            continue
        j += 1
    return text[i:j]
def params(ib):
    body = ib[2:-2]
    parts=[]; depth=0; cur=[]; i=0
    while i < len(body):
        two = body[i:i+2]
        if two in ("{{","[["): depth+=1; cur.append(two); i+=2; continue
        if two in ("}}","]]"): depth-=1; cur.append(two); i+=2; continue
        ch=body[i]
        if ch=="|" and depth==0:
            parts.append("".join(cur)); cur=[]; i+=1; continue
        cur.append(ch); i+=1
    parts.append("".join(cur))
    res={}
    for p in parts[1:]:
        if "=" in p:
            k,v=p.split("=",1); res[k.strip()]=re.sub(r"<!--.*?-->","",v,flags=re.S).strip()
    return res
BAR = re.compile(r"barcelona|barça|barca", re.I)
EXC = re.compile(r"guayaquil|barcelona s\.?c\b|barcelona sc|espanyol|sporting club barcelona|barcelona \(ecuador|ce europa|sant andreu|barcelona dragons|jabac|damm", re.I)
rows = []
for p in d["players"]:
    pg = d["pages"].get(p["page"])
    if not pg:
        rows.append(dict(p, status="nopage")); continue
    ib = infobox(pg["text"])
    if not ib:
        rows.append(dict(p, status="noinfobox")); continue
    pr = params(ib)
    hits = []
    for k, v in pr.items():
        m = re.fullmatch(r"(youthclubs|clubs)(\d+)", k)
        if not m: continue
        if BAR.search(v) and not EXC.search(v.split("|")[0] if "[[" in v else v):
            n = m.group(2)
            yrs = pr.get(("youthyears" if m.group(1) == "youthclubs" else "years") + n, "")
            caps = pr.get("caps" + n, "") if m.group(1) == "clubs" else ""
            hits.append(dict(kind=m.group(1), club=v, years=yrs, caps=caps))
    # also check body text mention of Barcelona academy (La Masia) for possible missed youth
    body_hint = bool(re.search(r"La Masia|FC Barcelona'?s? (youth|academy)|youth (system|ranks|setup|academy) of FC Barcelona|joined (FC )?Barcelona", pg["text"]))
    rows.append(dict(p, status="ok", hits=hits, body_hint=body_hint, ts=pg["ts"], resolved=pg["resolved"]))
json.dump(rows, open("rows.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
from collections import Counter
c = Counter(r["club"] for r in rows if r.get("hits"))
print(c, sum(c.values()))
for r in rows:
    if r.get("hits"):
        print(r["club"], "|", r["name"], "|", r["page"], "|", "; ".join(f'{h["kind"]}:{h["club"][:60]} {h["years"]} {h["caps"]}' for h in r["hits"]))
print("--- body hint but no infobox hit")
for r in rows:
    if r.get("status") == "ok" and not r["hits"] and r["body_hint"]:
        print(r["club"], r["name"], r["page"])
print("--- problems", [(r["club"], r["name"], r["status"]) for r in rows if r["status"] != "ok"])
