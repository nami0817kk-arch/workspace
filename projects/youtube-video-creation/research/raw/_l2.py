import requests,re,sys
sys.stdout.reconfigure(encoding='utf-8')
H={'User-Agent':'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/124 Safari/537.36'}
u=sys.argv[1]
t=requests.get(u,headers=H,timeout=30).text
for m in sorted(set(re.findall(r'["\(\' ]([^"\(\' ]*fileadmin[^"\)\' ]+\.(?:jpg|jpeg|png|webp))',t)))[:60]: print(m)
print('---links')
for m in sorted(set(re.findall(r'href="(/[^"]*(?:nachrichten|news)[^"]*)"',t)))[:60]: print(m)
