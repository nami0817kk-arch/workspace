import requests,json,sys
sys.stdout.reconfigure(encoding='utf-8')
H={'User-Agent':'Mozilla/5.0'}
for dt in ('20261019',):
    d=requests.get('https://site.api.espn.com/apis/site/v2/sports/soccer/eng.1/scoreboard?dates='+dt,headers=H,timeout=30).json()
    open('research/raw/20261019_sakamoto_scoreboard.json','w',encoding='utf-8').write(json.dumps(d,ensure_ascii=False))
    for e in d['events']: print(e['id'],e['name'],e['date'],e['status']['type']['description'])
