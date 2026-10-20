import requests,re,sys,html
sys.stdout.reconfigure(encoding='utf-8')
H={'User-Agent':'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/124 Safari/537.36'}
t=html.unescape(requests.get('https://www.jfa.jp/samuraiblue/news/',headers=H,timeout=30).text)
for m in re.findall(r'href="(/samuraiblue/news/[^"]+)"[^>]*>([\s\S]{0,200}?)</a>',t)[:30]: print(m[0],re.sub(r'\s+',' ',re.sub('<[^>]+>','',m[1]))[:80])
