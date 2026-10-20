import requests,json,sys
sys.stdout.reconfigure(encoding='utf-8')
H={'User-Agent':'Mozilla/5.0'}
sc=json.load(open('research/raw/20261019_cov_schedule.json',encoding='utf-8'))
for e in sc['events']:
    if e['date'].startswith(('2026-10-12','2026-08-29','2026-09-19','2026-09-13','2026-09-05','2026-08-21')):
        d=requests.get('https://site.api.espn.com/apis/site/v2/sports/soccer/eng.1/summary?event='+e['id'],headers=H,timeout=30).json()
        for r in d['rosters']:
            for p in r['roster']:
                if 'Sakamoto' in p['athlete']['displayName']:
                    print(e['date'][:10],e['name'],'START' if p.get('starter') else 'bench','in' if p.get('subbedIn') else '', 'out' if p.get('subbedOut') else '')
        for k in d['keyEvents']:
            if k.get('type',{}).get('text')=='Substitution' and 'Sakamoto' in k.get('text',''): print('   ',k['clock']['displayValue'],k['text'])
