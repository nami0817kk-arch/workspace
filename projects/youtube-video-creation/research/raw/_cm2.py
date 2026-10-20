import requests,sys
sys.stdout.reconfigure(encoding='utf-8')
H={'User-Agent':'yt-research/1.0 (nami.0817.kk@gmail.com)'}
d=requests.get('https://commons.wikimedia.org/w/api.php',params=dict(action='query',titles=sys.argv[1],prop='imageinfo',iiprop='size|extmetadata',format='json'),headers=H).json()
for p in d['query']['pages'].values():
    ii=p['imageinfo'][0]; print(ii['width'],ii['height'],ii['extmetadata'].get('LicenseShortName',{}).get('value'),ii['extmetadata'].get('ImageDescription',{}).get('value','')[:200],ii['extmetadata'].get('DateTimeOriginal',{}).get('value'))
