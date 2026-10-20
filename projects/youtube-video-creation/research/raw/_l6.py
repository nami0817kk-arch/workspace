import requests,re,sys,html
sys.stdout.reconfigure(encoding='utf-8')
H={'User-Agent':'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/124 Safari/537.36'}
seen=set()
for u in ["https://www.scfreiburg.com/aktuell/nachrichten/profis/galerien/","https://www.scfreiburg.com/aktuell/nachrichten/profis/galerien/?page=1","https://www.scfreiburg.com/aktuell/nachrichten/profis/"]:
    t=html.unescape(requests.get(u,headers=H,timeout=30).text)
    for m in sorted(set(re.findall(r'href="(/aktuell/nachrichten/profis/galerien/[^"]+)"',t))):
        if m not in seen: seen.add(m); print(m)
