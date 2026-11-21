# Cloudflare Workers AI の FLUX.2 [klein] で、顔の絵の表情だけを変える試作
# 使い方: python cf_expr.py <顔のフォルダ> <出力フォルダ> <cry|joy> <ファイル名...>
import sys, os, base64, json, io
import requests
from PIL import Image

ENV = r'C:\Users\なみ\dev\workspace\platform\ai-lab\.env'
env = {}
for line in open(ENV, encoding='utf-8'):
    if '=' in line and not line.lstrip().startswith('#'):
        k, v = line.split('=', 1)
        env[k.strip()] = v.strip().strip('"').strip("'")
ACC, TOK = env['CLOUDFLARE_ACCOUNT_ID'], env['CLOUDFLARE_API_TOKEN']
MODEL = '@cf/black-forest-labs/flux-2-klein-4b'
URL = 'https://api.cloudflare.com/client/v4/accounts/%s/ai/run/%s' % (ACC, MODEL)

KEEP = ('Keep the exact same person and age (young), same eye color, hairstyle, hair color, clothes, background color, framing '
        'and flat anime illustration style with clean black lineart. No wrinkles.')
PROMPT = {
    'cry': ('Edit this illustration: change only the facial expression to quietly sad and holding back tears. '
            'Eyebrows slightly raised in sadness, eyes a little watery with a faint shine, lips pressed together. '
            'At most one tiny teardrop at the corner of one eye, no streams of tears. ' + KEEP),
    'joy': ('Edit this illustration: change only the facial expression to moved and overjoyed. '
            'Big relieved smile, eyes slightly watery with a faint shine, light blush on the cheeks. '
            'At most one tiny teardrop at the corner of one eye, no streams of tears. ' + KEEP),
}

src, out, expr = sys.argv[1], sys.argv[2], sys.argv[3]
os.makedirs(out, exist_ok=True)
names = sys.argv[4:]
if names and names[0].startswith('@'):
    names = open(names[0][1:]).read().split()
LIMIT = int(os.environ.get('LIMIT', '9999'))
done = 0
for name in names:
    if os.path.exists(os.path.join(out, expr + '_' + name)):
        continue
    if done >= LIMIT:
        print('limit reached'); break
    done += 1
    im = Image.open(os.path.join(src, name)).convert('RGB').resize((512, 512), Image.LANCZOS)
    buf = io.BytesIO(); im.save(buf, 'PNG')
    files = {'input_image_0': ('face.png', buf.getvalue(), 'image/png')}
    data = {'prompt': PROMPT[expr], 'width': '512', 'height': '512'}
    r = requests.post(URL, headers={'Authorization': 'Bearer ' + TOK}, files=files, data=data, timeout=180)
    if r.status_code != 200:
        print(name, r.status_code, r.text[:500]); continue
    j = r.json()
    img = (j.get('result') or {}).get('image')
    if not img:
        print(name, 'no image', json.dumps(j)[:300]); continue
    o = Image.open(io.BytesIO(base64.b64decode(img))).convert('RGB').resize((480, 480), Image.LANCZOS)
    o.save(os.path.join(out, expr + '_' + name), quality=90)
    print(name, 'ok', flush=True)
