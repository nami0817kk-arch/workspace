import requests,re,sys,html
sys.stdout.reconfigure(encoding='utf-8')
H={'User-Agent':'Mozilla/5.0'}
t=requests.get('https://www.scfreiburg.com/api/feed/news/rss_feed',headers=H,timeout=30).text
print(len(t))
for it in re.findall(r'<item>[\s\S]*?</item>',t):
    ti=re.search(r'<title>(.*?)</title>',it,re.S); l=re.search(r'<link>(.*?)</link>',it,re.S)
    im=re.findall(r'(?:url|src)="([^"]+\.(?:jpg|png))',it)
    print(html.unescape(ti.group(1))[:70],l.group(1) if l else '',im[:1], 'GOTO' if 'oto' in it else '')
