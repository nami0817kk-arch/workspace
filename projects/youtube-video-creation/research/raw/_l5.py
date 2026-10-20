import requests,re,sys,html
sys.stdout.reconfigure(encoding='utf-8')
H={'User-Agent':'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/124 Safari/537.36'}
for u in sys.argv[1:]:
    t=html.unescape(requests.get(u,headers=H,timeout=30).text)
    open('research/raw/_page.html','w',encoding='utf-8').write(t)
    print('##',u,len(t))
    for m in sorted(set(re.findall(r'(fileadmin/[^&"\' ?)]+\.(?:jpg|jpeg|png|webp))',t))): print('  ',m)
    for m in re.findall(r'(?i)(?:foto|credit|bild)[^<>]{0,40}:?[^<>]{0,60}',t)[:8]: print('  cr',m)
