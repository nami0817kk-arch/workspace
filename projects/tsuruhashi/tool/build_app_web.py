# アプリに入れるゲーム本体を組み立てる（通信なしで動くように）。
#   prototype/game.html → app/assets/web/index.html
#   prototype/audio/*.mp3 → app/assets/audio/bgm/
#   prototype/art/（Gemini の絵）→ index.html に data URI で埋め込む（window.__TSURU_ART。WebView は loadHtmlString なので相対パスの画像を読めない）
# - Google Fonts は読まない。本文の丸ゴシックは iOS にある「ヒラギノ丸ゴ」に任せる（game.html の font-family に入っている）
# 使い方: python tool/build_app_web.py   （projects/tsuruhashi で実行。依存なし）
import base64
import io
import os
import re
import shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'prototype', 'game.html')
OUT = os.path.join(ROOT, 'app', 'assets', 'web', 'index.html')
AUD_SRC = os.path.join(ROOT, 'prototype', 'audio')
AUD_OUT = os.path.join(ROOT, 'app', 'assets', 'audio', 'bgm')
ART = os.path.join(ROOT, 'prototype', 'art')
TRACKS = ('surface', 'mine', 'deep')   # tool/make_bgm.py の TRACKS・bridge.dart の bgmKeys と同じ


def main():
    s = io.open(SRC, encoding='utf-8').read()
    # 外のフォントを読みに行く行を外す
    s = re.sub(r'<link rel="preconnect"[^>]*>\s*', '', s)
    s = re.sub(r'<link href="https://fonts\.googleapis\.com[^>]*>\s*', '', s)
    # 拡大させない・長押しの選択を出さない
    s = s.replace('content="width=device-width,initial-scale=1,viewport-fit=cover"', 'content="width=device-width,initial-scale=1,viewport-fit=cover,user-scalable=no"', 1)
    s = s.replace('<style>', '<style>\nhtml,body{-webkit-touch-callout:none}\n', 1)
    # 通信なしで動くことの確かめ：外へ読みに行く要素が残っていないか
    bad = re.findall(r'<(?:link|script|img|audio)[^>]+(?:href|src)="https?://', s)
    assert not bad, '外のファイルを読みに行く要素が残っている: %r' % bad[:3]
    assert 'fonts.googleapis.com' not in s
    for name in ('window.__TSURU_APP', 'TsuruApp.postMessage', 'window.tsuruAdResult', 'window.tsuruSetApp', 'window.tsuruPause', 'window.tsuruResume', 'TStore'):
        assert name in s, 'つなぎの口が無い: ' + name
    # 絵を埋め込む（title.jpg・scene0〜9.jpg・items/・crew/・heirs/・shop/。check/ は除く）。無い物はゲームが図形で描く
    art = {}
    mime = {'.webp': 'image/webp', '.jpg': 'image/jpeg', '.png': 'image/png'}
    subs = [('', ART)] + [(d + '/', os.path.join(ART, d)) for d in sorted(os.listdir(ART)) if os.path.isdir(os.path.join(ART, d)) and d != 'check'] if os.path.isdir(ART) else []
    for sub, folder in subs:
        for n in sorted(os.listdir(folder)):
            ext = os.path.splitext(n)[1].lower()
            if ext not in mime or n.startswith('_'):
                continue
            if os.path.isdir(os.path.join(folder, n)):
                continue
            b = open(os.path.join(folder, n), 'rb').read()
            art[sub + n] = 'data:%s;base64,%s' % (mime[ext], base64.b64encode(b).decode('ascii'))
    if art:
        import json
        s = s.replace('<head>', '<head>\n<script>window.__TSURU_ART=%s;</script>' % json.dumps(art), 1)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    io.open(OUT, 'w', encoding='utf-8', newline='\n').write(s)
    os.makedirs(AUD_OUT, exist_ok=True)
    for k in TRACKS:
        shutil.copy(os.path.join(AUD_SRC, k + '.mp3'), os.path.join(AUD_OUT, k + '.mp3'))
    print('built app index.html (%d bytes, art %d) and %d BGM' % (len(s.encode('utf-8')), len(art), len(TRACKS)))


if __name__ == '__main__':
    main()
