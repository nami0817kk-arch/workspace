"""App Store の掲載画像を撮る（iPhone 6.9インチ 1290×2796・iPad 13インチ 2064×2752、日本語）。

アプリのゲーム本体（app/assets/web/index.html。先に python tool/build_app_web.py）を、手元の Edge を
画面なし（headless）で動かして開き、場面ごとにゲームの状態を作って撮る。アプリの中にいるふり
（window.__HIKARI_APP）をして開くので、「テスト版」の札や Web 版の説明は写らない。
撮ったあと、白紙・値段・読み込み中の文字が写っていないかを確かめる（docs/app-pitfalls.md の掲載画像の項）。

使い方: python tool/screenshots.py [出力先]   （projects/hikari7 で実行。既定の出力先は build/screenshots）
"""
import asyncio
import base64
import functools
import http.server
import json
import subprocess
import sys
import tempfile
import threading
import time
import urllib.request
from pathlib import Path

import websockets
from PIL import Image

HERE = Path(__file__).resolve().parent.parent
WEB = HERE / 'app' / 'assets' / 'web'
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else HERE / 'build' / 'screenshots'
EDGE = r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
PORT, DEBUG = 8941, 9341

# 端末: (フォルダ名, CSS の幅, 高さ, 倍率, 文字の大きさ) → 1290×2796 と 2064×2752
# iPad は広い画面で下が空くので、ゲームの設定「文字の大きさ：とても大きい」で撮る（実際に選べる見え方）
DEVICES = [('1_iPhone_6.9', 430, 932, 3, 'n'), ('2_iPad_13', 1032, 1376, 2, 'xl')]

# 1シーズンを途中まで進める共通の下ごしらえ（tool/views.js と同じ進め方）
PLAY = """
function __start(g){S=newGame(g,'normal',null);var c=S.tr.slice();S.sel=c.slice(0,S.caps.sel).map(function(t){return t.id;});confirmSelect(S);startSeason(S);}
function __round(){var r=S.rnd;applyPlan(S);applyLesson(S);S.ap=0;afterTalk(S);if(S.phase==='interview')applyInterview(S);
  while(S.phase==='event'){resolveEvent(S,0);nextEvent(S);}S.phase='stage';if(ROUNDS[r].crit){S.phase='critique';applyCritique(S);}
  applyFeature(S);toNight(S);if(S.phase==='night'){nightSkip(S);}S.phase='judge';}
function __judge(){var r=S.rnd,B=alive(S),res=S.stage.res,n=ROUNDS[r].fin?Math.min(6,S.caps.finMax,B.length):capOf(S);
  B.sort(function(a,b){return res[b.id].sc-res[a.id].sc;}).slice(0,n).forEach(function(t){S.pass[t.id]=true;});decide(S);}
"""
# 場面: (ファイル名, ゲームの状態を作る JS)。最後に render() してから撮る
SCENES = [
    ('01_title', "S=null;ui.tsub=null;"),
    ('02_select', "S=newGame('f','normal',null);"),
    ('03_plan', "__start('m');__round();__judge();nextRound(S);"),
    ('04_talk', "__start('f');applyPlan(S);applyLesson(S);S.phase='talk';"),
    ('05_stage', "__start('m');__round();__judge();nextRound(S);applyPlan(S);applyLesson(S);S.ap=0;afterTalk(S);if(S.phase==='interview')applyInterview(S);"
                 "while(S.phase==='event'){resolveEvent(S,0);nextEvent(S);}S.phase='stage';ui.showFast=false;"),
    ('06_call', "__start('f');__round();__judge();S.call.n=Math.min(6,S.call.order.length);"),
    ('07_result', "__start('m');for(var r=1;r<=NROUND;r++){__round();__judge();S.call.n=S.call.order.length;S.call.done=true;if(!ROUNDS[r].fin)nextRound(S);}"
                  "applyFarewell(S);startPrep(S);S.prep.leader=S.tr.filter(function(t){return t.status==='debut';})[0].id;startMonth(S);"
                  "['tv','mv','rest','tv'].forEach(function(k){weekDo(S,k);});finishMonth(S);S.ending=false;"),
]
BOOT = ("window.__HIKARI_APP={adFree:false,store:{hikari7_tips:'{}'},owned:{},storeOk:true,canBuy:true,price:null,prices:{}};"
        "window.HikariApp={postMessage:function(){}};")


def serve():
    h = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(WEB))
    h.log_message = lambda *a: None
    srv = http.server.ThreadingHTTPServer(('127.0.0.1', PORT), h)
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


async def shoot():
    prof = tempfile.mkdtemp(prefix='hikari-shots-')
    edge = subprocess.Popen([EDGE, '--headless=new', f'--remote-debugging-port={DEBUG}', f'--user-data-dir={prof}',
                             '--hide-scrollbars', '--mute-audio', 'about:blank'])
    try:
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
            for dev, w, h, dpr, fs in DEVICES:
                (OUT / dev).mkdir(parents=True, exist_ok=True)
                await tab.call('Emulation.setDeviceMetricsOverride', width=w, height=h, deviceScaleFactor=dpr, mobile=True)
                for name, setup in SCENES:
                    await tab.call('Page.navigate', url=f'http://127.0.0.1:{PORT}/index.html')
                    for _ in range(100):
                        if await tab.js("typeof render==='function'&&document.readyState==='complete'"):
                            break
                        await asyncio.sleep(.1)
                    await tab.js("ui.tipsOff=true;ui.quick=false;ui.set.fs='%s';applySet();" % fs + PLAY + setup + "render();window.scrollTo(0,0);true")
                    await asyncio.sleep(2.2)  # 入りの動き・アイキャッチ・顔の絵が落ち着くまで
                    bad = await tab.js("var t=document.body.innerText;['テスト版','読み込んでいます','問題が起きました','undefined','NaN','¥','円で買う'].filter(function(x){return t.indexOf(x)>=0;})")
                    if bad:
                        raise SystemExit(f'{dev}/{name}: 写ってはいけない文字 {bad}')
                    shot = await tab.call('Page.captureScreenshot', format='png')
                    p = OUT / dev / f'{name}.png'
                    p.write_bytes(base64.b64decode(shot['data']))
                    im = Image.open(p).convert('RGB')
                    assert im.size == (w * dpr, h * dpr), (p, im.size)
                    im.save(p)  # 透過なし
                    lo, hi = im.convert('L').getextrema()
                    if hi - lo < 40:
                        raise SystemExit(f'{p}: ほぼ単色（白紙）')
                    print('ok', dev, name, im.size)
    finally:
        edge.terminate()


if __name__ == '__main__':
    if not (WEB / 'index.html').exists():
        raise SystemExit('先に python tool/build_app_web.py')
    srv = serve()
    try:
        asyncio.run(shoot())
    finally:
        srv.shutdown()
