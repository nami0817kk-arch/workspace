import json,sys
sys.stdout.reconfigure(encoding='utf-8')
d=json.load(open('research/raw/20261019_goto_summary.json',encoding='utf-8'))
for r_ in d['rosters']:
    print(r_['team']['displayName'])
    for p in r_['roster']:
        print('  ',p['athlete']['displayName'],'START' if p.get('starter') else '-', 'out' if p.get('subbedOut') else '', 'in' if p.get('subbedIn') else '')
for k in d['keyEvents']:
    print(k.get('clock',{}).get('displayValue'),k.get('type',{}).get('text'),k.get('text','')[:120])
st=d.get('standings')
print(json.dumps(st,ensure_ascii=False)[:300])
for g in st.get('groups',[]):
    for e in g['standings']['entries']:
        print(e['team'], {x['name']:x['displayValue'] for x in e['stats'] if x['name'] in('rank','points','gamesPlayed','wins','losses','draws','pointDifferential')})
