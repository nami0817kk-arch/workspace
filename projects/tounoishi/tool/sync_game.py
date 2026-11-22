# 試作の HTML（正は game-assets/fukaana/prototype-v*.html、リポジトリの外）を、
# アプリに同梱する assets/game/index.html へ写す。
# 試作は Artifact に載せる前提で <!doctype>・<head>・charset を持たないので、ここで足す。
#
# 使い方: python tool/sync_game.py C:/Users/なみ/dev/game-assets/fukaana/prototype-v9.html
import io
import os
import sys

HEAD = '''<!doctype html>
<html lang="ja">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no,viewport-fit=cover">
<style>:root{padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}*{-webkit-tap-highlight-color:transparent}</style>
'''

def main():
    if len(sys.argv) < 2:
        sys.exit('使い方: python tool/sync_game.py <試作の HTML>')
    src = io.open(sys.argv[1], encoding='utf-8').read()
    if '<!doctype' in src.lower():
        sys.exit('すでに <!doctype> を持つ HTML です。試作の元ファイルを渡してください。')
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'game', 'index.html')
    io.open(out, 'w', encoding='utf-8', newline='\n').write(HEAD + src + '\n</html>\n')
    print('写しました:', os.path.normpath(out), len(src), '文字')

if __name__ == '__main__':
    main()
