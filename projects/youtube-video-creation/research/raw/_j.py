import requests,re,sys,html
sys.stdout.reconfigure(encoding='utf-8')
H={'User-Agent':'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/124 Safari/537.36'}
for u in sys.argv[1:]:
    t=html.unescape(requests.get(u,headers=H,timeout=30).text)
    print(u,len(t))
    for m in re.findall(r'<a [^>]*href="([^"]+)"[^>]*>([^<]{4,80})</a>',t):
        if re.search(r'後藤|ニュージーランド|キリン|スコットランド|日本代表.*(試合|結果|メンバー)',m[1]): print(m)
