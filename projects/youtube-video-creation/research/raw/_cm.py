import requests,sys,json
sys.stdout.reconfigure(encoding='utf-8')
H={'User-Agent':'yt-research/1.0 (nami.0817.kk@gmail.com)'}
for q in sys.argv[1:]:
    d=requests.get('https://commons.wikimedia.org/w/api.php',params=dict(action='query',list='search',srsearch=q,srnamespace=6,srlimit=30,format='json'),headers=H,timeout=30).json()
    print('##',q)
    for s in d['query']['search']: print(s['title'])
