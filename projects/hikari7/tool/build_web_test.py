# テスト用Web版を1枚のページに組み立てる。
#   prototype/game.html（試作の本体。顔の絵は入っていない）
#   prototype/faces/pool.json と *.jpg（男女の顔。同じ group は同じ顔の着せ替えなので1枚だけ使う）
# から build/web/index.html を作り、web-test/ の _headers・robots.txt を添える。
#
# 検索に出さない（meta robots・X-Robots-Tag・robots.txt）、画面に「テスト版」の札を出す。
# 使い方: python tool/build_web_test.py   （projects/hikari7 で実行）
import base64
import io
import json
import os
import shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'prototype', 'game.html')
FACES = os.path.join(ROOT, 'prototype', 'faces')
OUT = os.path.join(ROOT, 'build', 'web')

HEAD = (
    '<!doctype html>\n<html lang="ja">\n<head>\n<meta charset="utf-8">\n'
    '<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">\n'
    '<meta name="robots" content="noindex,nofollow">\n'
    '<meta name="description" content="ひかりの七席（テスト版）">\n'
    '<style>html,body{margin:0}'
    ' #test-badge{position:fixed;left:6px;bottom:calc(76px + env(safe-area-inset-bottom,0px));z-index:60;'
    'font:700 10.5px/1.6 sans-serif;color:#fff;background:rgba(194,56,72,.85);border-radius:6px;padding:0 7px;'
    'pointer-events:none}</style>\n'
)
BADGE = '<div id="test-badge">テスト版</div>\n'


def bg_block():
    """背景の絵（prototype/bg/*.jpg）を data URI にして BGDATA の区間に入れる。"""
    d = os.path.join(ROOT, 'prototype', 'bg')
    img = {}
    for f in sorted(os.listdir(d)):
        if f.endswith('.jpg'):
            img[f[:-4]] = 'data:image/jpeg;base64,' + base64.b64encode(open(os.path.join(d, f), 'rb').read()).decode('ascii')
    return '/*BGDATA-START*/var BG_IMG=' + json.dumps(img, separators=(',', ':')) + ';/*BGDATA-END*/'


def put_bg(s):
    a = s.index('/*BGDATA-START*/')
    b = s.index('/*BGDATA-END*/') + len('/*BGDATA-END*/')
    return s[:a] + bg_block() + s[b:]


def face_block():
    pool = json.load(io.open(os.path.join(FACES, 'pool.json'), encoding='utf-8'))
    img, grp = {}, {}
    for g in ('m', 'f'):
        seen = set()
        img[g], grp[g] = [], []
        for it in pool[g]:
            if it['group'] in seen:
                continue
            seen.add(it['group'])
            raw = open(os.path.join(FACES, it['file']), 'rb').read()
            img[g].append('data:image/jpeg;base64,' + base64.b64encode(raw).decode('ascii'))
            grp[g].append(it['group'])
    return ('/*FACEDATA-START*/var FACE_IMG=' + json.dumps(img, separators=(',', ':')) +
            ';var FACE_GRP=' + json.dumps(grp, separators=(',', ':')) + ';/*FACEDATA-END*/'), len(img['m']), len(img['f'])


def main():
    s = io.open(SRC, encoding='utf-8').read()
    a = s.index('/*FACEDATA-START*/')
    b = s.index('/*FACEDATA-END*/') + len('/*FACEDATA-END*/')
    block, nm, nf = face_block()
    s = s[:a] + block + s[b:]
    s = put_bg(s)
    title = '<title>ひかりの七席</title>'
    assert title in s, 'game.html の <title> が見つからない'
    s = s.replace(title, '<title>ひかりの七席（テスト版）</title>', 1)
    # 本体は <title> と <style> から始まる断片なので、head の中に続けて置き、札は本文の頭に入れる
    i = s.index('<div id="app">')
    html = HEAD + s[:i] + '</head>\n<body>\n' + BADGE + s[i:] + '\n</body>\n</html>\n'
    if os.path.isdir(OUT):
        shutil.rmtree(OUT)
    os.makedirs(OUT)
    io.open(os.path.join(OUT, 'index.html'), 'w', encoding='utf-8').write(html)
    for f in ('_headers', 'robots.txt'):
        shutil.copy(os.path.join(ROOT, 'web-test', f), os.path.join(OUT, f))
    print('built index.html (%d bytes, faces m=%d f=%d)' % (len(html.encode('utf-8')), nm, nf))


if __name__ == '__main__':
    main()
