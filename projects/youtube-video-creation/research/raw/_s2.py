import requests,json,sys
sys.stdout.reconfigure(encoding='utf-8')
H={'User-Agent':'Mozilla/5.0'}
d=requests.get('https://site.api.espn.com/apis/site/v2/sports/soccer/eng.1/summary?event=401879257',headers=H,timeout=30).json()
open('research/raw/20261019_sakamoto_summary.json','w',encoding='utf-8').write(json.dumps(d,ensure_ascii=False))
for g in d['standings']['groups']:
    for e in g['standings']['entries']:
        s={x['name']:x['displayValue'] for x in e['stats']}
        print(s.get('rank'),e['team'],s.get('gamesPlayed'),s.get('wins'),s.get('losses'),s.get('points'),s.get('pointDifferential'))
cid=[c['team']['id'] for c in d['header']['competitions'][0]['competitors'] if 'Coventry' in c['team']['displayName']][0]
print(cid)
sc=requests.get(f'https://site.api.espn.com/apis/site/v2/sports/soccer/eng.1/teams/{cid}/schedule',headers=H,timeout=30).json()
open('research/raw/20261019_cov_schedule.json','w',encoding='utf-8').write(json.dumps(sc,ensure_ascii=False))
for e in sc['events']:
    c=e['competitions'][0]
    print(e['date'][:10],e['name'],[ (x['team']['abbreviation'],x.get('score',{}).get('displayValue') if isinstance(x.get('score'),dict) else x.get('score')) for x in c['competitors']],c['status']['type']['description'])
