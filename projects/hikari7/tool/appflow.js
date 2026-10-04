// アプリとしてのつなぎ（広告・追加パック）を、ブラウザなしで確かめる（2026-10-04 品質点検）。
//   node tool/appflow.js
// ゲーム本体に「アプリの中にいる」ふりの値（window.__HIKARI_APP）を渡し、アプリへ送る頼みごとと、
// アプリからの返事（hikariAdResult など）への反応を見る。どれか外れたら exit 1。
const fs = require('fs'), vm = require('vm'), path = require('path');
const src = fs.readFileSync(path.join(__dirname, '..', 'prototype', 'game.html'), 'utf8');
const code = src.slice(src.lastIndexOf('<script>') + 8, src.lastIndexOf('</script>'));

function el(attrs) {
  return {
    innerHTML: '', innerText: '', style: {}, dataset: {}, children: [],
    classList: { add() {}, remove() {}, toggle() {}, contains() { return false; } },
    setAttribute() {}, getAttribute: (k) => (attrs && k in attrs ? attrs[k] : null), removeAttribute() {},
    hasAttribute: (k) => !!(attrs && k in attrs),
    addEventListener() {}, appendChild() {}, scrollIntoView() {}, focus() {},
    getBoundingClientRect() { return { top: 0, left: 0, width: 375, height: 40 }; },
    querySelector() { return el(); }, querySelectorAll() { return []; }, closest() { return null; },
    offsetHeight: 800, offsetTop: 0,
  };
}

let fails = 0;
const ok = (c, msg) => { if (!c) { fails++; console.error('NG: ' + msg); } else console.log('ok: ' + msg); };

function boot(appVals) {
  const posts = [], timers = [];
  let click = null;
  const app = el();
  const ctx = {
    console, Math, Date, JSON, Object, Array, String, Number, Boolean, RegExp, Error, Map, Set, Uint8Array, Promise,
    setTimeout: (f) => { timers.push(f); return timers.length; }, clearTimeout: (i) => { if (i) timers[i - 1] = null; },
    setInterval: () => 0, clearInterval() {}, requestAnimationFrame: () => 0, cancelAnimationFrame() {},
    atob: (s) => Buffer.from(s, 'base64').toString('binary'),
    URL: { createObjectURL: () => 'blob:x' }, Blob: function () {},
    localStorage: { getItem: () => null, setItem() {}, removeItem() {} },
    navigator: {}, performance: { now: () => Date.now() },
    HikariApp: { postMessage: (s) => posts.push(JSON.parse(s)) },
    __HIKARI_APP: appVals,
  };
  ctx.window = ctx;
  ctx.scrollTo = () => {};
  ctx.matchMedia = () => ({ matches: false, addEventListener() {} });
  ctx.document = {
    querySelector: (s) => (s === '#app' ? app : el()), querySelectorAll: () => [], getElementById: () => el(),
    addEventListener: (t, f) => { if (t === 'click') click = f; }, createElement: () => el(), body: el(), documentElement: el(), hidden: false,
  };
  vm.createContext(ctx);
  vm.runInContext(code, ctx);
  const run = (js) => vm.runInContext(js, ctx);
  const press = (a, v) => {
    const attrs = { 'data-a': a };
    if (v != null) attrs['data-v'] = String(v);
    const t = el(attrs);
    click({ target: { closest: () => t }, preventDefault() {} });
  };
  return { run, press, posts, timers, ctx };
}

// 1シーズン目を合否まで進める（tool/views.js と同じ進め方を短くしたもの）
const PLAY_ROUND = `applyPlan(S);applyLesson(S);S.ap=0;afterTalk(S);if(S.phase==='interview')applyInterview(S);
  while(S.phase==='event'){resolveEvent(S,0);nextEvent(S);}
  S.phase='stage';if(ROUNDS[S.rnd].crit){S.phase='critique';applyCritique(S);}
  applyFeature(S);toNight(S);if(S.phase==='night'){nightSkip(S);S.phase='judge';}
  var B=alive(S),res=S.stage.res,n=capOf(S);B.sort(function(a,b){return res[b.id].sc-res[a.id].sc;}).slice(0,n).forEach(function(t){S.pass[t.id]=true;});decide(S);`;
const START = `S=newGame('m','normal',null);var c=S.tr.slice();S.sel=c.slice(0,S.caps.sel).map(function(t){return t.id;});confirmSelect(S);startSeason(S);`;

// ===== 全画面広告 =====
{
  const g = boot({ adFree: false, store: { hikari7_career: JSON.stringify({ seasons: 1, points: 0, hall: [] }) }, owned: {} });
  g.run(START);
  const between = () => g.posts.filter((p) => p.type === 'between');
  const seen = [];
  for (let r = 1; r <= 4; r++) {
    g.run(PLAY_ROUND);
    const before = between().length;
    g.press('nextround');
    const asked = between().length > before;
    seen.push(asked);
    if (asked) {
      ok(g.run('S.rnd') === r, `第${r}審査の後: 広告を出し終えるまで次の審査に進まない`);
      g.run('hikariBetweenDone()');
    }
    ok(g.run('S.rnd') === r + 1, `第${r}審査の後: 次の審査へ進んだ`);
  }
  ok(JSON.stringify(seen) === '[false,true,true,false]', '2シーズン目以降は第2・第3審査の後の2回だけ出す（' + JSON.stringify(seen) + '）');
  ok(g.posts.some((p) => p.type === 'prepInter'), '出しそうな審査に入ったら、そのときだけ読み込みを頼む');

  const h = boot({ adFree: false, store: {}, owned: {} });
  h.run(START);
  for (let r = 1; r <= 4; r++) { h.run(PLAY_ROUND); h.press('nextround'); }
  ok(!h.posts.some((p) => p.type === 'between' || p.type === 'prepInter'), 'はじめてのシーズンには出さず、読み込みも頼まない');

  const k = boot({ adFree: false, store: { hikari7_career: JSON.stringify({ seasons: 1, points: 0, hall: [] }) }, owned: {} });
  k.run(START);
  k.run(PLAY_ROUND); k.press('nextround'); k.run(PLAY_ROUND); k.press('nextround');
  ok(k.run('S.rnd') === 2, '返事が来ないうちは進まない');
  k.timers.filter(Boolean).forEach((f) => f());
  ok(k.run('S.rnd') === 3, 'アプリから返事が来なくても、少し待てば次の審査へ進む（固まらない）');
}

// ===== 動画の特典 =====
{
  const g = boot({ adFree: false, store: {}, owned: {} });
  g.run(START);
  g.run(`withAd(function(){S.__got=(S.__got||0)+1;})`);
  const req = g.posts.filter((p) => p.type === 'reward').pop();
  ok(req && req.id === 1, '動画の頼みに番号が付く');
  g.press('adcancel');
  ok(g.posts.some((p) => p.type === 'rewardCancel' && p.id === 1), '「やめる」はアプリにも伝える');
  g.run(`withAd(function(){S.__got=(S.__got||0)+1;})`);
  g.run('hikariAdResult(true,null,1)');
  ok(!g.run('S.__got'), 'やめた動画の結果は、次の特典に入らない');
  g.run('hikariAdShowing(2)');
  g.timers.filter(Boolean).forEach((f) => f());
  ok(g.run('!!pendingAd'), '動画の表示が始まったら、90秒の打ち切りで取り消さない');
  g.run('hikariAdResult(true,null,2)');
  ok(g.run('S.__got') === 1, '見終えた返事で特典が入る');
}

// ===== 追加パック =====
{
  const g = boot({ adFree: false, store: {}, owned: { story: false, audition: false } });
  g.run(START);
  ok(g.run('packArcKeys().length') === 0 && g.run("fmtKeys().indexOf('acap')") < 0, '買っていないパックの中身は出ない');
  g.run("hikariSetApp({owned:{story:true,audition:true},storeOk:true,prices:{story:'¥320',audition:'¥320'}})");
  ok(g.run('packArcKeys().length') === 6 && g.run("fmtKeys().indexOf('acap')") >= 0, '買ったらその場で中身が入る');
  g.run('hikariSetApp({owned:{story:false,audition:false}})');
  ok(g.run('packArcKeys().length') === 0 && g.run("fmtKeys().indexOf('acap')") < 0, '返金されたら、新しく始める中身から外す');
  g.press('tsub', 'shop');
  ok(g.posts.some((p) => p.type === 'refresh'), '追加パックの画面を開いたら、最新の値段を取りに行く');
  g.run('hikariSetApp({storeOk:true,prices:{story:null,audition:"¥320"}})');
  const shop = g.run('vTitleShop()');
  ok(/data-v="story" disabled/.test(shop) && !/data-v="audition" disabled/.test(shop), '値段が読めていないパックは押せず、読めたパックは押せる');

  const b = boot({ adFree: false, store: {}, owned: { story: true, audition: false } });
  ok(b.run('packArcKeys().length') === 6, '起動の時点で、買ったパックが入っている（ストアの返事を待たない）');
  ok(/data-v="story"/.test(b.run('vTitleShop()')) === false || /入っています/.test(b.run('vTitleShop()')), '持っているパックは「入っています」');
}

// ===== 保存と審査の型 =====
{
  const g = boot({ adFree: false, store: {}, owned: { story: false, audition: false } });
  g.run('parseSave(JSON.stringify({rnd:2,ev:{xid:"blackout"}}))');
  ok(g.run('!!packDone.story'), 'パックの出来事の途中の保存は、持っていなくても中身を足して読む（落ちない）');
  const w = g.run("JSON.stringify(teamW(PACK_AUDITION.acap,TEAM_CONCEPTS[0]))");
  ok(JSON.parse(w).v >= 0.36, 'アカペラ審査は、曲の方向を選んでも歌の重みが主になる（' + w + '）');
}

if (fails) { console.error(fails + '件 外れ'); process.exitCode = 1; } else console.log('すべて通った');
