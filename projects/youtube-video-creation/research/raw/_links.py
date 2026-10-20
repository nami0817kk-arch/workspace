import requests,re,sys
sys.stdout.reconfigure(encoding='utf-8')
H={'User-Agent':'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/124 Safari/537.36'}
for u in sys.argv[1:]:
    try:
        r=requests.get(u,headers=H,timeout=30); print('##',u,r.status_code,len(r.text))
        for m in sorted(set(re.findall(r'(?:href|src|content)="([^"]+\.(?:jpg|jpeg|png|webp)[^"]*)"',r.text)))[:25]: print('  img',m)
        for m in sorted(set(re.findall(r'href="([^"]*(?:goto|sakamoto)[^"]*)"',r.text,re.I)))[:15]: print('  link',m)
    except Exception as e: print('##',u,e)
