import re,html,sys,requests
u,out=sys.argv[1],sys.argv[2]
r=requests.get(u,headers={'User-Agent':'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/124 Safari/537.36'},timeout=30)
r.encoding=r.apparent_encoding if r.encoding in (None,'ISO-8859-1') else r.encoding
t=r.text
open(out+'.html','w',encoding='utf-8').write(t)
t=re.sub(r'<(script|style)[\s\S]*?</\1>','',t)
t=re.sub(r'<[^>]+>','\n',t);t=html.unescape(t)
t='\n'.join(l.strip() for l in t.split('\n') if l.strip())
open(out,'w',encoding='utf-8').write(t)
print(r.status_code,len(t))
