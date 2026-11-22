"""App Store の掲載画像を撮る（iPhone 中型 1206×2622、日本語、5枚）。

ゲーム本体は HTML（assets/game/index.html）なので、Flutter のゴールデンではなく、手元の Edge を
画面なし（headless）で動かして開き、テスト用の口 window.__t で場面を作って撮る。
アプリの窓口（window.TouApp）は置かないので、ゲームはブラウザで開いたとみなし、
「広告を消す（値段）」の売り場は写らない。乱数は種を固定して、毎回同じ絵にする。

撮ったあと、白紙・値段・読み込み中・差し込みの漏れが写っていないかを確かめる
（docs/app-pitfalls.md 項目4「掲載画像が白紙のままストアに出ていた」）。
それでも最後は Read で1枚ずつ目で見る。

使い方（projects/tounoishi で）:
    python tool/screenshots/capture.py [出力先]
既定の出力先は ~/Downloads/塔の意志_掲載画像/1_iPhone_日本語
要るもの: Edge、Python の websockets と Pillow
"""
import asyncio
import base64
import functools
import http.server
import json
import os
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import urllib.request
from pathlib import Path

import websockets
from PIL import Image

HERE = Path(__file__).resolve().parents[2]
WEB = HERE / 'assets' / 'game'
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.home() / 'Downloads' / '塔の意志_掲載画像' / '1_iPhone_日本語'
EDGE = r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
PORT, DEBUG = 8951, 9351

# Dynamic Island 搭載 iPhone（中型）＝ App Store の必須の枠。CSS 402×874 を 3倍で 1206×2622
W, H, DPR = 402, 874, 3

# 開く前に入れておくもの：乱数の種・ヒントは見た扱い・自己ベストと図鑑が少し埋まった状態
BOOT = r"""
(function(){
 var s=20261123;Math.random=function(){s=(s*1664525+1013904223)>>>0;return s/4294967296;};
 try{
  window.__shot=true;
  localStorage.setItem('tou-tut','1');
  localStorage.removeItem('tou-save');
  localStorage.setItem('tou-best',JSON.stringify({easy:18420,normal:12960,hard:7350}));
 }catch(_){}
})();
"""

# 場面づくりの道具（ページの中で使う）
HELP = r"""
var T=window.__t;
// (x,y) から (dx,dy) の向きに len マス掘る。nuts[i] があれば、掘る前にその土の養分を入れておく（生まれる魔物が決まる）
function __br(f,x,y,dx,dy,len,nuts,mag){
 for(var i=1;i<=len;i++){var cx=x+dx*i,cy=y+dy*i,c=T.cell(f,cx,cy);if(!c)break;
  if(nuts&&nuts[i-1]!=null){c.nut=nuts[i-1];c.mag=0;}
  if(mag&&mag[i-1]!=null){c.mag=mag[i-1];c.nut=0;}
  T.g().dp=999;T.dig(f,cx,cy);}
}
function __run(sec){for(var i=0;i<sec*10;i++){T.step(0.1);if(T.over())break;}}
// cond(g) が成り立つまで 0.1 秒ずつ進める（成り立った瞬間で止めるので、戦いの最中が撮れる）
function __until(cond,sec){for(var i=0;i<sec*10;i++){T.step(0.1);if(T.over())return false;if(cond(T.g()))return true;}return false;}
// 冒険者 e の距離 d 以内に魔物がいるか
function __near(g,e,d){return g.cr.some(function(m){return m.f==e.f&&Math.abs(m.x-e.x)+Math.abs(m.y-e.y)<=d;});}
// 1階の強い魔物から、種の違うものを順に主役にする
function __heroes(whys){var g=T.g(),seen={},n=0;
 g.cr.filter(function(m){return m.f==0;}).sort(function(a,b){return b.t-a.t;}).forEach(function(m){
  if(n<whys.length&&!seen[m.sp]){seen[m.sp]=1;T.promote(m,whys[n++]);}});}
function __fin(dp){var g=T.g();g.dp=dp;g.bub=[];}
// 1階（入口の階）に枝道を掘って、いろいろな魔物を生ませる
function __floor0(){
 __br(0,10,15,1,0,5,[1,2,0,3,4]);
 __br(0,3,12,-1,0,2,[5,1]);
 __br(0,3,10,1,0,4,[0,2,0,6]);
 __br(0,8,8,0,1,3,[1,0,7],null);
 __br(0,12,8,0,-1,4,[2,0,null,3],[null,null,4,null]);
 __br(0,16,4,-1,0,4,[0,8,1,0]);
 __br(0,16,6,1,0,2,[3,1]);
}
"""

# launch() は時間を ×1 で動かし始めるので、撮るまでの間に戦いが終わらないよう止めておく
PAUSE = "document.getElementById('sp0').click();"

# 場面: (ファイル名, 場面を作る JS, 撮る直前の JS)
SCENES = [
    # 1. 掘っているところ（最上階・コアのある階。準備の時間で止まっている）
    ('01_dig', r"""
T.reset('normal');
var f=2;
__br(f,3,17,1,0,4,[1,2,0,3]);
__br(f,3,15,-1,0,2,[1,0]);
__br(f,15,12,1,0,3,[2,0,5]);
__br(f,15,9,-1,0,4,[1,0,null,2],[null,null,3,null]);
__br(f,10,4,1,0,4,[0,4,0,1]);
__br(f,10,2,-1,0,3,[6,0,2]);
__run(6);T.view(f);__fin(64);
""", ''),
    # 2. 冒険者と戦っているところ（1階。2つの波を続けて呼び、魔物とぶつかった瞬間で止める）
    ('02_battle', r"""
T.reset('normal');__floor0();__run(4);
T.launch();__run(3);T.launch();
__until(function(g){var e=g.en.filter(function(e){return e.f==0;});return e.length>=2&&e.some(function(e){return __near(g,e,1);});},60);
T.view(0);__fin(52);
""", PAUSE),
    # 3. 主役と勇者（第6波の勇者が主役に迫った所で止める）
    ('03_hero', r"""
T.reset('normal');__floor0();__run(4);
__heroes(['kill','eat']);
var g=T.g();g.wave=5;g.cd=0;T.launch();
__until(function(g){var y=g.en.filter(function(e){return e.yu&&e.f==0;})[0];return y&&g.cr.some(function(m){return m.hero&&m.f==0&&Math.abs(m.x-y.x)+Math.abs(m.y-y.y)<=3;});},120);
T.view(0);__fin(41);
""", PAUSE),
    # 4. 一覧のシート（主役・勇者・系統の強化）
    ('04_list', r"""
T.reset('normal');__floor0();__run(4);
__heroes(['kill','big','eat']);
T.view(0);__fin(73);
""", "document.getElementById('blist').click();var sb=document.querySelector('.sbox');if(sb)sb.scrollTop=0;"),
    # 5. タイトル
    ('05_title', '', ''),
]

# 写ってはいけない文字（値段・読み込み中・差し込みの漏れ・課金の売り場）
NG = ['¥', '円', '読み込', 'undefined', 'NaN', 'null', '広告を消す', '購入を復元', 'Error']

# 課金アイテムの審査用（--iap）: アプリの中と同じく「広告を消す（¥370）」の売り場が写ったタイトル。
# アプリの窓口 TouApp を置いた形にして、値段はストアの表示と同じ文字を渡す。
if '--iap' in sys.argv:
    sys.argv.remove('--iap')
    OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.home() / 'Downloads' / '塔の意志_掲載画像' / '課金の審査用'
    BOOT = BOOT + "window.TouApp={postMessage:function(){}};"
    SCENES = [('iap_review', '', "touSetApp({adFree:false,price:'¥370',canBuy:true,storeOk:true});")]
    NG = ['読み込', 'undefined', 'NaN', 'Error']


def serve():
    class Quiet(http.server.SimpleHTTPRequestHandler):
        def log_message(self, *a):
            pass

    h = functools.partial(Quiet, directory=str(WEB))
    class Server(http.server.ThreadingHTTPServer):
        def handle_error(self, request, client_address):
            pass  # Edge が読み込みの途中で接続を切ったときの ConnectionResetError を黙らせる

    srv = Server(('127.0.0.1', PORT), h)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    return srv


class Tab:
    def __init__(self, ws):
        self.ws, self.n = ws, 0

    async def call(self, method, **params):
        self.n += 1
        mid = self.n
        await self.ws.send(json.dumps({'id': mid, 'method': method, 'params': params}))
        while True:
            m = json.loads(await self.ws.recv())
            if m.get('id') == mid:
                if 'error' in m:
                    raise RuntimeError(m['error'])
                return m.get('result', {})

    async def js(self, code):
        r = await self.call('Runtime.evaluate', expression=code, awaitPromise=True, returnByValue=True)
        if r.get('exceptionDetails'):
            raise RuntimeError(r['exceptionDetails'].get('exception', {}).get('description', r['exceptionDetails']))
        return r.get('result', {}).get('value')


def open_edge(prefix='tounoishi-shots-', port=DEBUG):
    """画面なしの Edge を一時の作業フォルダで開く。終わったら必ず close_edge(edge, prof) で閉じる
    （projects/hikari7/tool/screenshots.py と同じ作り）。"""
    prof = tempfile.mkdtemp(prefix=prefix)
    edge = subprocess.Popen([EDGE, '--headless=new', f'--remote-debugging-port={port}', f'--user-data-dir={prof}',
                             '--hide-scrollbars', '--mute-audio', '--autoplay-policy=user-gesture-required', 'about:blank'])
    return edge, prof


def close_edge(edge, prof):
    """開いた Edge を子のプロセスごと閉じる。terminate() だけだと Windows では本体と子が残る（2026-11-15 に 26 個・4.5GB 残った）。"""
    if os.name == 'nt':
        subprocess.run(['taskkill', '/PID', str(edge.pid), '/T', '/F'], capture_output=True)
        ps = ("Get-CimInstance Win32_Process -Filter \"Name='msedge.exe'\" | "
              "Where-Object { $_.CommandLine -and $_.CommandLine.Contains($env:EDGE_PROF) } | "
              "ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }")
        subprocess.run(['powershell', '-NoProfile', '-Command', ps], capture_output=True, env={**os.environ, 'EDGE_PROF': prof})
    else:
        edge.terminate()
    try:
        edge.wait(5)
    except Exception:
        edge.kill()
    for _ in range(10):
        shutil.rmtree(prof, ignore_errors=True)
        if not os.path.exists(prof):
            break
        time.sleep(.3)


async def shoot():
    OUT.mkdir(parents=True, exist_ok=True)
    edge, prof = open_edge()
    try:
        tabs = None
        for _ in range(50):
            try:
                tabs = json.load(urllib.request.urlopen(f'http://127.0.0.1:{DEBUG}/json'))
                break
            except Exception:
                time.sleep(.2)
        url = next(t['webSocketDebuggerUrl'] for t in tabs if t.get('type') == 'page')
        async with websockets.connect(url, max_size=2 ** 28) as ws:
            tab = Tab(ws)
            await tab.call('Page.enable')
            await tab.call('Page.addScriptToEvaluateOnNewDocument', source=BOOT)
            await tab.call('Emulation.setDeviceMetricsOverride', width=W, height=H, deviceScaleFactor=DPR, mobile=True)
            for name, setup, after in SCENES:
                await tab.call('Page.navigate', url=f'http://127.0.0.1:{PORT}/index.html')
                for _ in range(100):
                    if await tab.js("!!window.__t&&document.readyState==='complete'"):
                        break
                    await asyncio.sleep(.1)
                await asyncio.sleep(.5)
                await tab.js(HELP + setup + ';window.scrollTo(0,0);true')
                if after:
                    await tab.js(after + ';true')
                await asyncio.sleep(1.5)  # 描き直しと入りの動きが落ち着くまで
                text = await tab.js('document.body.innerText')
                bad = [x for x in NG if x in text]
                if bad:
                    raise SystemExit(f'{name}: 写ってはいけない文字 {bad}')
                if len(text.strip()) < 30:
                    raise SystemExit(f'{name}: 文字がほとんど無い（描画を待たずに撮っている）')
                shot = await tab.call('Page.captureScreenshot', format='png')
                p = OUT / f'{name}.png'
                p.write_bytes(base64.b64decode(shot['data']))
                im = Image.open(p).convert('RGB')
                assert im.size == (W * DPR, H * DPR), (p, im.size)
                im.save(p)  # 透過なし
                lo, hi = im.convert('L').getextrema()
                if hi - lo < 40:
                    raise SystemExit(f'{p}: ほぼ単色（白紙）')
                print('ok', name, im.size, p.stat().st_size, 'bytes')
    finally:
        close_edge(edge, prof)


if __name__ == '__main__':
    if not (WEB / 'index.html').exists():
        raise SystemExit(f'{WEB / "index.html"} が無い')
    srv = serve()
    try:
        asyncio.run(shoot())
    finally:
        srv.shutdown()
