# アプリに入れるゲーム本体を1枚のページに組み立てる（通信なしで動くように）。
#   prototype/index.html と、そこから読むファイル全部 → app/assets/web/index.html
# - Google Fonts は読まない。画面の丸ゴシックは iOS にある「ヒラギノ丸ゴ」に任せる（index.html の font-family に入っている）。
#   積む字の書体（TenbinKana = M PLUS Rounded 1c Black のひらがなだけ）は当たり判定と同じ形なので、必ず埋め込む
# - matter.js は CDN ではなく node_modules から埋め込む（先に projects/tenbin で npm ci）
# - ライセンス文を app/assets/licenses/ に置く（アプリの「ライセンス一覧」に出す）
# 使い方: python tool/build_app_web.py   （projects/tenbin で実行。追加の部品は要らない）
import base64
import io
import os
import re
import shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROTO = os.path.join(ROOT, 'prototype')
OUT = os.path.join(ROOT, 'app', 'assets', 'web', 'index.html')
LIC = os.path.join(ROOT, 'app', 'assets', 'licenses')
MATTER = os.path.join(ROOT, 'node_modules', 'matter-js', 'build', 'matter.min.js')

WORDS_LICENSE = '''もじつみ の「ことば」の一覧（words.js）

wordfreq（Robyn Speer, https://github.com/rspeer/wordfreq）の日本語の頻度データで選び、
UniDic（UniDic Consortium, BSD License）で品詞と読みを確かめて作った。
wordfreq のデータは Creative Commons Attribution-ShareAlike 4.0（CC BY-SA 4.0）で配布されているため、
この一覧も CC BY-SA 4.0 で扱う。 https://creativecommons.org/licenses/by-sa/4.0/
'''


def read(p):
    return io.open(p, encoding='utf-8').read()


def script(src):
    # </script> で閉じられないように
    return '<script>\n' + src.replace('</script', '<\\/script') + '\n</script>'


def main():
    s = read(os.path.join(PROTO, 'index.html'))
    s = re.sub(r'<link rel="preconnect"[^>]*>\s*', '', s)
    s = re.sub(r'<link href="https://fonts\.googleapis\.com[^>]*>\s*', '', s)
    # 積む字の書体を埋め込む
    css = read(os.path.join(PROTO, 'fonts', 'kana.css'))

    def font(m):
        b = open(os.path.join(PROTO, 'fonts', m.group(1)), 'rb').read()
        return 'url(data:font/woff2;base64,' + base64.b64encode(b).decode('ascii') + ')'
    css = re.sub(r'url\(([^)]+\.woff2)\)', font, css)
    s = s.replace('<link href="fonts/kana.css" rel="stylesheet">', '<style>\n' + css + '\n</style>')
    # スクリプトを埋め込む
    def put(m):
        src = m.group(1)
        if src.startswith('https://cdnjs.cloudflare.com/ajax/libs/matter-js/'):
            return script(read(MATTER))
        return script(read(os.path.join(PROTO, src)))
    s = re.sub(r'<script src="([^"]+)"></script>', put, s)
    s = s.replace('initial-scale=1,viewport-fit=cover', 'initial-scale=1,viewport-fit=cover,user-scalable=no', 1)
    # 長押しで文字が選ばれたり、拡大鏡が出たりしないように
    s = s.replace('<style>\n:root{', '<style>\nhtml,body{-webkit-touch-callout:none}\n:root{', 1)
    # 通信なしで動くことの確かめ：外へ読みに行く要素が残っていないか
    bad = re.findall(r'<(?:link|script|img)[^>]+(?:href|src)="https?://', s)
    assert not bad, '外のファイルを読みに行く要素が残っている: %r' % bad[:3]
    assert 'fonts.googleapis.com' not in s
    for need in ('TenbinCore', 'TenbinMoney', 'TenbinGlyphs', 'TenbinWords', 'window.__TENBIN_APP', 'data:font/woff2;base64,'):
        assert need in s, need + ' が入っていない'
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    io.open(OUT, 'w', encoding='utf-8', newline='\n').write(s)
    os.makedirs(LIC, exist_ok=True)
    shutil.copy(os.path.join(PROTO, 'fonts', 'OFL.txt'), os.path.join(LIC, 'OFL-MPLUSRounded1c.txt'))
    shutil.copy(os.path.join(ROOT, 'node_modules', 'matter-js', 'LICENSE'), os.path.join(LIC, 'matter-js.txt'))
    shutil.copy(os.path.join(ROOT, 'node_modules', 'poly-decomp', 'LICENSE'), os.path.join(LIC, 'poly-decomp.txt'))
    io.open(os.path.join(LIC, 'words.txt'), 'w', encoding='utf-8', newline='\n').write(WORDS_LICENSE)
    print('built app index.html (%d bytes)' % len(s.encode('utf-8')))


if __name__ == '__main__':
    main()
