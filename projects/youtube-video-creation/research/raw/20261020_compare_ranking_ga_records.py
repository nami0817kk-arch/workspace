"""試合ごとの記録（ESPN summary の keyEvents・rosters）から、選手の試合数・出場時間・得点・アシスト・PKを数え直す（2026-10-19）。
ESPN の今季成績の集計と突き合わせるための道具。python でそのまま流す。"""
import json,urllib.request,time,re
def j(u):
    return json.load(urllib.request.urlopen(urllib.request.Request(u,headers={'User-Agent':'Mozilla/5.0'}),timeout=30))
T=[('Raphinha','esp.1',83,'231050'),('Yamal','esp.1',83,'362150'),('Mbappe','esp.1',86,'231388'),('Thauvin','fra.1',175,'156898'),('Sinayoko','fra.1',6851,'271137'),('Haaland','eng.1',382,'253989'),('Camello','esp.1',101,'276652'),('JoaoPedro','eng.1',363,'284960')]
cache={}; res={}
def clk(c):
    m=re.match(r"(\d+)'(?:\+(\d+))?",c); return int(m.group(1))+(int(m.group(2)) if m.group(2) else 0)
for n,L,t,pid in T:
    key=(L,t)
    if key not in cache:
        sch=j(f"https://site.api.espn.com/apis/site/v2/sports/soccer/{L}/teams/{t}/schedule")
        evs=[]
        for e in sch['events']:
            c=e['competitions'][0]
            if not c['status']['type']['completed']: continue
            s=j(f"https://site.api.espn.com/apis/site/v2/sports/soccer/{L}/summary?event={e['id']}")
            sc={x['team']['id']:int(float(x['score']['value'] if isinstance(x.get('score'),dict) else x.get('score',0))) for x in c['competitors']}
            ks=[dict(type=k['type']['text'],clock=k['clock']['displayValue'],ps=[a['athlete']['id'] for a in k.get('participants',[]) if 'athlete' in a],names=[a['athlete']['displayName'] for a in k.get('participants',[]) if 'athlete' in a]) for k in s.get('keyEvents',[]) if k.get('scoringPlay') or 'ubst' in k['type']['text']]
            ros={}
            for r in s['rosters']:
                for p in r['roster']:
                    ros[p['athlete']['id']]=(p['starter'],p['subbedIn'],p['subbedOut'])
            evs.append(dict(id=e['id'],date=e['date'][:10],name=e['shortName'],scores=sc,keys=ks,ros=ros))
            time.sleep(.25)
        cache[key]=evs
    evs=cache[key]
    apps=starts=0; mins=0; G=A=PK=0; rows=[]; gfp=0
    for e in evs:
        ro=e['ros'].get(pid)
        played=bool(ro and (ro[0] or ro[1]))
        if played:
            apps+=1; starts+=ro[0]
            off=[clk(k['clock']) for k in e['keys'] if 'ubst' in k['type'] and k['ps'] and k['ps'][1:] and pid==k['ps'][-1] and False]
            # substitution participants: [in, out]? find by id
            mm=90
            for k in e['keys']:
                if 'ubst' in k['type'] and pid in k['ps']:
                    idx=k['ps'].index(pid)
                    tm=clk(k['clock'])
                    # participants order observed: [on, off]
                    if idx==0: mm=90-tm
                    else: mm=tm
            mins+=mm; gfp+=e['scores'].get(str(t),0)
        for k in e['keys']:
            if 'ubst' in k['type']: continue
            if k['ps'] and k['ps'][0]==pid and 'Own' not in k['type']:
                G+=1; PK+= 'Penalty' in k['type']; rows.append((e['date'],e['name'],k['clock'],k['type'],'G'))
            elif pid in k['ps'][1:]:
                A+=1; rows.append((e['date'],e['name'],k['clock'],k['type'],'A'))
    res[n]=dict(apps=apps,starts=starts,mins_est=mins,G=G,A=A,PK=PK,team_games=len(evs),team_gf_in_played=gfp,rows=rows)
    print(n,res[n]['apps'],res[n]['starts'],mins,G,A,PK,len(evs),gfp,flush=True)
json.dump(res,open('full2.json','w',encoding='utf-8'),ensure_ascii=False,indent=1)
