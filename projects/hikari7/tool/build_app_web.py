# アプリに入れるゲーム本体を1枚のページに組み立てる（通信なしで動くように）。
#   prototype/game.html と顔の絵 → app/assets/web/index.html
# - Google Fonts は読まない。見出し書体（Dela Gothic One・OFL）は使う字だけに絞って埋め込む。
#   本文の丸ゴシックは iOS にある「ヒラギノ丸ゴ」に任せる（game.html の font-family に入っている）
# - 検索よけ・テスト版の札は入れない（それは Web のテスト版だけのもの）
# 使い方: python tool/build_app_web.py   （projects/hikari7 で実行。fonttools が要る）
import base64
import io
import os
import re
import shutil
import sys

from fontTools import subset

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tool'))
from build_web_test import face_block, put_bg, put_voice  # noqa: E402

SRC = os.path.join(ROOT, 'prototype', 'game.html')
FONT = os.path.join(ROOT, 'fonts', 'DelaGothicOne-Regular.ttf')
OUT = os.path.join(ROOT, 'app', 'assets', 'web', 'index.html')
LIC = os.path.join(ROOT, 'app', 'assets', 'licenses', 'OFL-DelaGothicOne.txt')


def dela_face(text):
    opts = subset.Options()
    opts.layout_features = ['*']
    font = subset.load_font(FONT, opts)
    sub = subset.Subsetter(opts)
    sub.populate(text=''.join(sorted(set(text))))
    sub.subset(font)
    buf = io.BytesIO()
    font.save(buf)
    b64 = base64.b64encode(buf.getvalue()).decode('ascii')
    return ('@font-face{font-family:"Dela Gothic One";font-display:block;'
            'src:url(data:font/ttf;base64,' + b64 + ') format("truetype")}'), len(buf.getvalue())


def main():
    s = io.open(SRC, encoding='utf-8').read()
    a = s.index('/*FACEDATA-START*/')
    b = s.index('/*FACEDATA-END*/') + len('/*FACEDATA-END*/')
    block, nm, nf = face_block()
    s = s[:a] + block + s[b:]
    s = put_bg(s)
    s = put_voice(s)
    # 外のフォントを読みに行く行を外す
    s = re.sub(r'<link rel="preconnect"[^>]*>\s*', '', s)
    s = re.sub(r'<link href="https://fonts\.googleapis\.com[^>]*>\s*', '', s)
    face, size = dela_face(io.open(SRC, encoding='utf-8').read())
    s = s.replace('<style>', '<style>\n' + face + '\n', 1)
    i = s.index('<div id="app">')
    html = ('<!doctype html>\n<html lang="ja">\n<head>\n<meta charset="utf-8">\n'
            '<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover,user-scalable=no">\n'
            '<style>html,body{margin:0;-webkit-user-select:none;user-select:none;-webkit-touch-callout:none}</style>\n'
            + s[:i] + '</head>\n<body>\n' + s[i:] + '\n</body>\n</html>\n')
    # 通信なしで動くことの確かめ：外へ読みに行く要素が残っていないか
    bad = re.findall(r'<(?:link|script|img)[^>]+(?:href|src)="https?://', html)
    assert not bad, '外のファイルを読みに行く要素が残っている: %r' % bad[:3]
    assert 'fonts.googleapis.com' not in html
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    io.open(OUT, 'w', encoding='utf-8', newline='\n').write(html)
    os.makedirs(os.path.dirname(LIC), exist_ok=True)
    shutil.copy(os.path.join(ROOT, 'fonts', 'OFL-DelaGothicOne.txt'), LIC)
    print('built app index.html (%d bytes, font %d bytes, faces m=%d f=%d)' % (len(html.encode('utf-8')), size, nm, nf))


if __name__ == '__main__':
    main()
