import json,sys
sys.stdout.reconfigure(encoding='utf-8')
d=json.load(open('research/raw/20261019_goto_summary.json',encoding='utf-8'))
for k in d['keyEvents']:
    if k.get('type',{}).get('text')=='Goal': print(k['text'])
for t in d['boxscore']['teams']:
    print(t['team']['displayName'],{s['name']:s['displayValue'] for s in t['statistics']})
print(d['gameInfo'].get('venue',{}).get('fullName'), d['gameInfo'].get('attendance'))
for r in d['rosters']:
    for p in r['roster']:
        if 'Goto' in p['athlete']['displayName'] or 'Yamamoto' in p['athlete']['displayName']:
            print(p['athlete']['displayName'], p.get('formationPlace'), {s['name']:s['displayValue'] for s in p.get('stats',[])})
