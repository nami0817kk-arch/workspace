// App Store の掲載画像を撮る（iPhone 6.9インチ 1320×2868、5枚）。アプリに入れるのと同じ本体（app/assets/web/index.html）を、
// アプリの中にいるふり（window.__TENBIN_APP）で開いて撮り、上に見出しを付ける。
// 使い方: 先に python tool/build_app_web.py。PLAYWRIGHT=<playwright の場所> CHROMIUM=<chromium> node tool/screenshots.js
//   → marketing/screenshots/ja-1.png …。SHOT_LANG=en で英語の画面（日本語を学ぶ人向け）を en-1.png … に撮る
// 大きさは 1206×2622（App Store Connect の iPhone の枠「中型ディスプレイ」が受け付ける大きさ。1320×2868 は入らなかった。2026-11-25）
// docs/app-pitfalls.md 4番: 撮るたびに「撮れていること」を確かめる（読み込み中のまま・白紙のまま出さない）。
// 検索結果に出るのは先頭3枚なので、はじめの画面・起動画面は撮らず、遊んでいる絵から並べる
var path = require('path'), fs = require('fs');
var pw = require(process.env.PLAYWRIGHT || 'playwright');
var ROOT = path.join(__dirname, '..'), PAGE = path.join(ROOT, 'app/assets/web/index.html'), OUT = path.join(ROOT, 'marketing/screenshots');
var W = 402, H = 874, SCALE = 3, TOP = 154;   // TOP は見出しの帯の高さ（CSS px）
var EN = process.env.SHOT_LANG === 'en';
var SHOTS = [
  { name: 'ja-1', title: '字を くっつけて<br>ことばに しよう', sub: 'ひらがなを積む ことばパズル' },
  { name: 'ja-2', title: 'たて・よこ・逆さでも<br>読めたら ことば', sub: '落とす前に できそうなことばが出る' },
  { name: 'ja-3', title: '台は6種類', sub: 'てんびん・ゆらゆら・ふたつ…景色もそれぞれ' },
  { name: 'ja-4', title: '高く積むほど<br>空が 夕焼けから夜へ', sub: 'のり・いた・こおり のアイテムも' },
  { name: 'ja-5', title: '集めたことばで<br>台と字の色が ひらく', sub: 'ことば帳 約4,000語' }
];
// 英語（日本語を学ぶ人向け）。ローマ字・意味の札・おさらいを見せる
var SHOTS_EN = [
  { name: 'en-1', title: 'Stack hiragana,<br>spell Japanese words', sub: 'Romaji on every letter' },
  { name: 'en-2', title: 'Any direction counts', sub: 'See the word before you drop' },
  { name: 'en-3', title: 'Tap a word: meaning,<br>kanji and voice', sub: 'Nearly 4,000 everyday words' },
  { name: 'en-4', title: 'Review the words<br>you collected', sub: 'See the meaning, pick the hiragana' },
  { name: 'en-5', title: 'Six stages with<br>Japanese scenery', sub: 'Garden, shrine, river, sea, snowy mountain' }
];
if (EN) SHOTS = SHOTS_EN;
function sleep(ms) { return new Promise(function (r) { setTimeout(r, ms); }); }
(async function () {
  if (!fs.existsSync(PAGE)) throw new Error('先に python tool/build_app_web.py');
  fs.mkdirSync(OUT, { recursive: true });
  var b = await pw.chromium.launch(process.env.CHROMIUM ? { executablePath: process.env.CHROMIUM } : {});
  // ことば帳を集めた人の状態（台と色がひらいている）。2〜4枚目で使う
  var words = Object.values(require(path.join(ROOT, 'prototype/words.js'))).flat();
  var many = {}; words.slice(0, 420).forEach(function (w) { many[w] = 1; });
  async function open(dict, extra) {
    var ctx = await b.newContext({ viewport: { width: W, height: H - TOP }, deviceScaleFactor: SCALE });
    var p = await ctx.newPage();
    var errs = []; p.on('pageerror', function (e) { errs.push(e.message); });
    await p.route('**/*', function (r) { return r.request().url().startsWith('file:') ? r.continue() : r.abort(); });
    var st = { 'tenbin-kana-coached': 'true', 'tenbin-kana-muted': 'true', 'tenbin-kana-dict': JSON.stringify(dict || {}), 'tenbin-kana-lang': JSON.stringify(EN ? 'en' : 'ja') };
    Object.assign(st, extra || {});
    await p.addInitScript(function (st) { window.TenbinApp = { postMessage: function () {} }; window.__TENBIN_APP = { store: st, adFree: false }; }, st);
    await p.goto('file://' + PAGE); await sleep(900);
    await p.evaluate(function () { window.tenbinSetApp({ price: '¥370', canBuy: true }); });
    p.errs = errs; p.ctx = ctx; return p;
  }
  // 字を順に落とす（落とせるようになるまで待つ）。x は台の座標（真ん中が200）
  async function drops(p, letters, xs) {
    await p.evaluate(function (l) { var s = window.__state(); s.queue.splice.apply(s.queue, [0, l.length].concat(l)); }, letters);
    for (var i = 0; i < letters.length; i++) {
      await p.waitForFunction(function () { var s = window.__state(); return window.TenbinCore.canDrop(s) && !s.pendingScore; }, null, { timeout: 15000 });
      await p.evaluate(function (x) { window.__dropAt(x); }, 200 + (xs ? xs[i] : 0));
      await sleep(250);
    }
  }
  async function settle(p) { await p.waitForFunction(function () { var s = window.__state(); return !s.pendingScore && window.TenbinCore.settled(s); }, null, { timeout: 15000 }); }
  async function pick(p, plat) { await p.click('[data-plat="' + plat + '"]'); await sleep(200); await p.click('#go'); await sleep(400); }
  async function shot(p, i, check) {
    var raw = path.join(OUT, '.raw-' + i + '.png');
    // 撮れていることの確かめ（読み込み中・はじめの画面・エラーのまま撮らない）
    var ok = await p.evaluate(check || function () { return !document.querySelector('.ad') && window.__state() && window.__state().cargo.length > 0; });
    if (!ok) throw new Error(SHOTS[i].name + ' が撮りたい場面になっていない');
    if (p.errs.length) throw new Error(SHOTS[i].name + ' でエラー: ' + p.errs.join(' / '));
    await p.screenshot({ path: raw });
    await p.ctx.close();
    return raw;
  }
  var raws = [];
  // 1: ことばができた瞬間（ふつうの台）
  var p = await open({});
  await p.click('#go'); await sleep(300);
  await drops(p, ['さ', 'く', 'ら'], [30, 30, 30]); await settle(p);
  await drops(p, ['ね'], [-80]); await settle(p);
  await drops(p, ['こ'], [-80]);
  await sleep(300);
  if (process.env.DEBUG) console.log(await p.evaluate(function () { var s = window.__state(); return JSON.stringify({ made: s.made, failed: s.failed, c: s.cargo.map(function (b) { return b.kind + Math.round(b.position.x) + ',' + Math.round(b.position.y); }) }); }));
  await p.waitForFunction(function () { return window.__state().made.length >= 2; }, null, { timeout: 15000 }); await sleep(450);
  raws.push(await shot(p, 0, function () { return window.__state().made.length >= 2; }));
  // 2: できそうなことばの案内（「う」「み」を横に並べて うみ を作り、「ね」の上に「こ」を持つ）
  p = await open({});
  await p.click('#go'); await sleep(300);
  await drops(p, ['み', 'う', 'ね'], [-60, -118, 70]); await settle(p);   // う・み を横に並べる（上に重ねると、取り直した輪郭では傾いて揺れ続けた）
  await p.evaluate(function () { var s = window.__state(); s.queue[0] = 'こ'; window.__moveTo(270); });
  // 落とせるようになってから（待ちの輪のあいだは案内が出ない）
  await p.waitForFunction(function () { return window.TenbinCore.canDrop(window.__state()); }, null, { timeout: 15000 });
  await sleep(900);
  raws.push(await shot(p, 1, function () { var s = window.__state(); return s.made.length >= 1 && window.TenbinCore.previewWords(s, 'こ', 0, 270).indexOf('ねこ') >= 0; }));
  if (EN) {
    var learn = Object.assign({}, many); ['ねこ', 'がっこう', 'さくら', 'うみ', 'きょう', 'まっちゃ', 'いぬ', 'やま'].forEach(function (w) { learn[w] = 1; });
    // 3: ことばを押すと出る意味の札（がっこう）
    p = await open(learn);
    await p.click('#dictBtn'); await sleep(400);
    await p.evaluate(function () { document.querySelector('[data-say="がっこう"]').click(); }); await sleep(500);
    raws.push(await shot(p, 2, function () { var d = document.getElementById('wordDetail'); return !!d && /school/.test(d.textContent); }));
    // 4: おさらい（答えたところ）
    p = await open(learn);
    await p.click('#dictBtn'); await sleep(300); await p.click('#quiz'); await sleep(400);
    await p.evaluate(function () { var m = document.querySelector('.qm').textContent, M = window.TenbinMeanings;
      // 正解を押す（出ている意味と同じ意味のことば）
      [].slice.call(document.querySelectorAll('[data-pick]')).filter(function (el) { var x = M[el.getAttribute('data-pick')]; return x && x[1] === m; })[0].click(); });
    await sleep(500);
    raws.push(await shot(p, 3, function () { return !!document.querySelector('.qc .right') && !document.querySelector('.qc .wrong') && !document.getElementById('qNext').hidden; }));
    // 5: てんびん（じんじゃ）
    p = await open(many);
    await pick(p, 'seesaw');
    await drops(p, ['た', 'け', 'の', 'こ', 'は', 'な'], [-60, -60, 60, 60, 0, 0]); await settle(p);
    await sleep(300);
    raws.push(await shot(p, 4));
  } else {
  // 3: てんびん（じんじゃ）
  p = await open(many);
  await pick(p, 'seesaw');
  await drops(p, ['た', 'け', 'の', 'こ', 'は', 'な'], [-60, -60, 60, 60, 0, 0]); await settle(p);
  await sleep(300);
  raws.push(await shot(p, 2));
  // 4: 高く積んだ（夕焼け）。崩れない塔を台の上に置いてから撮る
  p = await open(many);
  await pick(p, 'flat');
  await p.evaluate(function () {
    var C = window.TenbinCore, s = window.__state(), seq = 'そらほしつきあかねゆきはなうみ'.split('');
    var y = C.PIVOT_Y - C.PLANK_T - 40;
    seq.forEach(function (ch, i) { if (C.KINDS.indexOf(ch) < 0) return; var e = C.extent(ch, 0); var b = C.build(ch, 200 + ((i % 3) - 1) * 22, y - e.maxY, ((i % 2) - 0.5) * 0.12); C.M.Body.setStatic(b, true); s.cargo.push(b); C.M.Composite.add(s.engine.world, b); y -= (e.maxY - e.minY) + 4; });
    s.height = C.PIVOT_Y - C.PLANK_T - C.topY(s); s.score = seq.length; s.points = 2380; s.made.push('そら', 'ほし', 'つき', 'あかね');
  });
  await sleep(2600);
  raws.push(await shot(p, 3));
  // 5: ことば帳（集めたことばと、次にひらくもの）
  p = await open(many);
  await p.click('#dictBtn'); await sleep(400);
  raws.push(await shot(p, 4, function () { return !!document.querySelector('.dict') && document.querySelectorAll('.dict .w').length > 50; }));
  }
  // 見出しを付けて 1320×2868 に
  var c = await b.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: SCALE });
  var q = await c.newPage();
  for (var i = 0; i < SHOTS.length; i++) {
    var html = '<!doctype html><html><head><meta charset="utf-8"><style>body{margin:0;width:' + W + 'px;height:' + H + 'px;overflow:hidden;background:linear-gradient(#f4b893,#f8e0c2 18%,#f4ede1 30%);font-family:"Hiragino Maru Gothic ProN","M PLUS Rounded 1c",sans-serif;color:#3b2f24}' + (EN ? '.cap b{font-size:28px !important}' : '') +
      '.cap{height:' + TOP + 'px;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center}' +
      '.cap b{font-size:31px;line-height:1.25;font-weight:900;letter-spacing:.03em;text-shadow:0 2px 0 rgba(255,255,255,.6)}.cap span{margin-top:8px;font-size:15px;font-weight:700;color:#8a4a2a}' +
      'img{display:block;width:' + W + 'px}</style></head><body><div class="cap"><b>' + SHOTS[i].title + '</b><span>' + SHOTS[i].sub + '</span></div><img src="file://' + raws[i] + '"></body></html>';
    var tmp = path.join(OUT, '.cap.html'); fs.writeFileSync(tmp, html);
    await q.goto('file://' + tmp); await sleep(300);
    var out = path.join(OUT, SHOTS[i].name + '.png');
    await q.screenshot({ path: out });
    var size = fs.statSync(out).size;
    // 白紙は小さい（app-pitfalls 4番: 白紙は約22KB、中身のある画像は100KBを超える）
    if (size < 150 * 1024) throw new Error(SHOTS[i].name + ' が小さすぎる（' + size + ' バイト）。白紙か読み込み中のまま撮っていないか');
    console.log(SHOTS[i].name, size, 'bytes');
  }
  raws.forEach(function (r) { fs.unlinkSync(r); }); fs.unlinkSync(path.join(OUT, '.cap.html'));
  await b.close();
})().catch(function (e) { console.error(e); process.exit(1); });
