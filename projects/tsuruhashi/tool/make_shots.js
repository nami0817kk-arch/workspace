// App Store の掲載画像（6.7インチ 1290×2796）を作る。上に見出し、下にゲームの画面。
//   node tool/make_shots.js   → store/screenshots/01〜06.png
// ゲームは prototype/game.html をそのまま開き、状態だけ差し替えて撮る（撮るための写しを一時フォルダに置く）。
// docs/app-pitfalls.md 4番: タイトル画面は撮らない。撮るたびに「中身が写っているか」を確かめる（白紙・読み込み中は止める）。
const fs = require('fs'), os = require('os'), path = require('path');
let pw;
try { pw = require('playwright'); } catch (e) { pw = require('/opt/node22/lib/node_modules/playwright'); }

const ROOT = path.join(__dirname, '..');
const OUT = path.join(ROOT, 'store', 'screenshots');
fs.mkdirSync(OUT, { recursive: true });
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'tsuru-shots-'));
const game = fs.readFileSync(path.join(ROOT, 'prototype', 'game.html'), 'utf8')
  .replace('requestAnimationFrame(frame);\n})();', 'window.__ev = c => eval(c);\nrequestAnimationFrame(frame);\n})();');
if (!game.includes('window.__ev')) throw new Error('撮るための口を差し込めなかった（game.html の終わりの形が変わった？）');
fs.writeFileSync(path.join(tmp, 'game.html'), game);
fs.cpSync(path.join(ROOT, 'prototype', 'audio'), path.join(tmp, 'audio'), { recursive: true });
if (fs.existsSync(path.join(ROOT, 'prototype', 'art'))) fs.cpSync(path.join(ROOT, 'prototype', 'art'), path.join(tmp, 'art'), { recursive: true });

// 撮る場面。setup は game.html の中で動く式、after は撮る直前に動く式、wait はその間の待ち（ミリ秒）
const BASE = "S.tut=99;S.sound=false;S.bgm=0;S.amb=false;S.notifAsked=true;bannerT=9;document.getElementById('hint').style.opacity='0';";
const found = n => `S.found={};ITEMS.slice(0,${n}).forEach(it=>S.found[it.id]=1);`;
const SHOTS = [
  { id: '01', h1: '仲間を雇って、\n地の底まで掘り進め', sub: '放っておいても、仲間が掘り続ける', bg: ['#5a3a8a', '#1c1028'],
    setup: BASE + found(18) + "S.depth=340;camY=340;S.genDepth=340;S.best=340;S.pick=82;S.w=[5,3,2,2,1,0,0];S.ore=8.6e6;startBoost(S);startBoost(S);", tab: 'crew', wait: 2600,
    after: "cheer();" },
  { id: '02', h1: '10の地層に\n50のお宝', sub: '化石・宝石・古代の遺物を図鑑に集めよう', bg: ['#6a4a1e', '#1c130a'],
    setup: BASE + found(31) + "S.depth=530;camY=530;S.genDepth=530;S.best=530;S.pick=122;S.w=[5,3,2,2,1,1,0];S.ore=3.2e9;", tab: 'book', wait: 1800,
    after: "FX.find(ITEMS.find(i=>i.id==='kanmuri'), true); document.querySelectorAll('#pBook .lsec')[1].scrollIntoView({block:'start'});" },
  { id: '03', h1: '岩盤を割れ！', sub: 'つるはしを鍛えて、層の壁を打ち破る', bg: ['#2d4f6a', '#0d1820'],
    setup: BASE + found(24) + "S.depth=401;camY=401;S.genDepth=401;S.best=401;S.pick=79;S.w=[5,3,3,2,1,0,0];S.ore=1.2e8;", tab: 'tool', wait: 1500,
    after: "FX.brk(400, 4.2e7, false);", afterWait: 260 },
  { id: '04', h1: '先代の家宝を受け継ぎ\n次の代へ', sub: '代替わりで、会社はもっと強くなる', bg: ['#2d5a3a', '#0a1a0e'],
    setup: BASE + found(29) + "S.gen=3;S.fame=46;S.creed=['b','b'];S.heir=[{k:'map',lv:1},{k:'pick',lv:2}];S.history=[{gen:1,depth:655,fame:5,species:20,start:NOW()-2e8,end:NOW()-1e8,creed:[],heir:{k:'map',lv:1}},{gen:2,depth:710,fame:12,species:26,start:NOW()-1e8,end:NOW()-4e6,creed:['b'],heir:{k:'pick',lv:2}}];S.depth=758;camY=758;S.genDepth=758;S.best=758;S.pick=160;S.w=[6,4,3,2,2,1,1];S.ore=4e11;",
    tab: 'co', wait: 1500, after: "openRebirth(); rbChoice=rbChoice.map(c=>c||'b'); rbHeir=heirCands(S)[0].k; renderRebirth(); document.querySelector('#rbBody .heirs').scrollIntoView({block:'center'});" },
  { id: '05', h1: '寝ている間も\n掘り進む', sub: '戻ったら、留守の間の鉱石とお宝を受け取ろう', bg: ['#7a3a22', '#1e0e08'],
    setup: BASE + found(14) + "S.depth=210;camY=210;S.genDepth=210;S.best=210;S.pick=46;S.w=[6,4,3,2,0,0,0];S.ore=3.1e5;", tab: 'tool', wait: 1500,
    after: "S.last=NOW()-8*3600e3; showAway(8*3600, true, false);", afterWait: 1600 },
  { id: '06', h1: '地底湖、菌糸の森、\n星の核――', sub: '深く掘るほど、見たことのない景色が広がる', bg: ['#3a1e5a', '#0a0612'],
    setup: BASE + found(44) + "S.gen=5;S.fame=120;S.history=[{gen:4,depth:825,fame:30,species:40,start:NOW()-1e8,end:NOW()-4e6,creed:[],heir:null}];S.depth=930;camY=930;S.genDepth=930;S.best=930;S.pick=196;S.w=[6,4,3,2,2,1,1];S.ore=8e13;",
    tab: 'tool', wait: 1500, after: "{const sw=shaftW(),sx=cx()-sw/2,fy=rowY(S.depth);startSight(sx,sw,fy);const d=SIGHTS.find(x=>x.k==='star');sight.k='star';sight.dur=d.dur;sight.line='流れ星！';}", afterWait: 900 },
];

(async () => {
  const b = await pw.chromium.launch();
  const p = await b.newPage({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 3 });
  // アプリの中と同じ見た目で撮る（ブラウザの試作だけの文言「試作は即効果」などを出さない）
  await p.addInitScript(() => { window.__TSURU_APP = { store: {}, owned: [], got: { bento: 0 }, prices: {}, canBuy: true }; });
  const errs = []; p.on('pageerror', e => errs.push(e.message));
  for (const s of SHOTS) {
    await p.goto('file://' + path.join(tmp, 'game.html'));
    await p.waitForTimeout(400);
    await p.click('#titleGo'); await p.waitForTimeout(400);
    await p.evaluate(c => __ev(c), s.setup + 'checkAch(S);buildPanels();updateUI(true);');
    await p.click(`.tabs [data-tab="${s.tab}"]`);
    await p.waitForTimeout(s.wait);
    await p.evaluate(() => { document.getElementById('toasts').innerHTML = ''; });
    if (s.after) { await p.evaluate(c => __ev(c), s.after); await p.waitForTimeout(s.afterWait || 400); }
    await p.evaluate(() => { document.getElementById('hint').style.opacity = '0'; });
    const shot = await p.screenshot({ type: 'png' });
    // 中身が写っているか（白紙・単色の画面を出さない）
    const ok = await p.evaluate(() => document.getElementById('sDepth').textContent.length > 0 && document.querySelectorAll('.panel:not([hidden]) *').length > 5 && !/試作/.test(document.body.innerText));
    if (!ok || shot.length < 150000) throw new Error(`${s.id} の画面に中身が写っていない（${shot.length} バイト）`);
    // 見出しを付けて 1290×2796 に組む（setContent の頁からは file:// を読めないので、画面は data URI で埋める）
    const page = `<html><head><link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=M+PLUS+Rounded+1c:wght@800&display=swap"></head>
      <body style="margin:0;width:1290px;height:2796px;overflow:hidden;background:linear-gradient(180deg,${s.bg[0]},${s.bg[1]});font-family:'M PLUS Rounded 1c','Hiragino Maru Gothic ProN',sans-serif;color:#fff">
      <div style="height:610px;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;gap:26px;padding:0 60px">
        <div style="font-size:104px;font-weight:800;line-height:1.18;letter-spacing:.02em;text-shadow:0 8px 0 rgba(0,0,0,.35);white-space:pre-line">${s.h1}</div>
        <div style="font-size:46px;font-weight:800;color:#ffe2a8;opacity:.95">${s.sub}</div></div>
      <div style="display:flex;justify-content:center"><img src="data:image/png;base64,${shot.toString('base64')}" style="width:1000px;height:2164px;border-radius:64px;box-shadow:0 30px 80px rgba(0,0,0,.55),0 0 0 14px rgba(255,255,255,.12)"></div>
      </body></html>`;
    const q = await b.newPage({ viewport: { width: 1290, height: 2796 }, deviceScaleFactor: 1 });
    await q.setContent(page, { waitUntil: 'networkidle' }).catch(() => q.setContent(page));
    await q.waitForTimeout(300);
    const out = path.join(OUT, s.id + '.png');
    await q.screenshot({ path: out, clip: { x: 0, y: 0, width: 1290, height: 2796 } });
    await q.close();
    const size = fs.statSync(out).size;
    if (size < 300000) throw new Error(`${s.id}.png が小さすぎる（${size} バイト）。白紙で撮れていないか見る`);
    console.log(`${s.id}.png  ${(size / 1024).toFixed(0)}KB  ${s.h1.replace(/\n/g, '')}`);
  }
  await b.close();
  fs.rmSync(tmp, { recursive: true, force: true });
  if (errs.length) { console.error('画面のエラー:', errs); process.exit(1); }
})();
