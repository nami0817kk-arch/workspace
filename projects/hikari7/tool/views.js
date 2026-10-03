// 試作の画面をブラウザなしで全部描いて、描くときにエラーが出ないかを確かめる（フェーズ46・47）。
//   node tool/views.js           … 男女・難しさ・チャレンジを変えて数シーズン通し、全画面を描く
// DOM は描くのに要る分だけの仮のものを置く。見た目は確かめない（そこはブラウザで見る）。
const fs = require('fs'), vm = require('vm'), path = require('path');
const src = fs.readFileSync(path.join(__dirname, '..', 'prototype', 'game.html'), 'utf8');
const code = src.slice(src.lastIndexOf('<script>') + 8, src.lastIndexOf('</script>'));

function el() {
  return {
    innerHTML: '', innerText: '', style: {}, dataset: {}, children: [],
    classList: { add() {}, remove() {}, toggle() {}, contains() { return false; } },
    setAttribute() {}, getAttribute() { return null; }, removeAttribute() {}, hasAttribute() { return false; },
    addEventListener() {}, appendChild() {}, scrollIntoView() {}, focus() {},
    getBoundingClientRect() { return { top: 0, left: 0, width: 375, height: 40 }; },
    querySelector() { return el(); }, querySelectorAll() { return []; }, closest() { return null; },
    offsetHeight: 800, offsetTop: 0,
  };
}
const app = el();
const store = new Map();
// 前に保存した設定が、開き直したあとも効いているか（読む順番の取り違えで初期値に戻ったことがある）
store.set('hikari7_set', JSON.stringify({ fs: 'l', bgm: 0, voice: 0, theme: 'dark' }));
const ctx = {
  console, Math, Date, JSON, Object, Array, String, Number, Boolean, RegExp, Error, Map, Set, Uint8Array, Promise,
  setTimeout: () => 0, clearTimeout() {}, setInterval: () => 0, clearInterval() {},
  requestAnimationFrame: () => 0, cancelAnimationFrame() {},
  atob: (s) => Buffer.from(s, 'base64').toString('binary'),
  URL: { createObjectURL: () => 'blob:x' }, Blob: function () {},
  localStorage: { getItem: (k) => (store.has(k) ? store.get(k) : null), setItem: (k, v) => store.set(k, String(v)), removeItem: (k) => store.delete(k) },
  navigator: {}, performance: { now: () => Date.now() },
};
ctx.window = ctx;
ctx.matchMedia = () => ({ matches: false, addEventListener() {} });
ctx.document = {
  querySelector: (s) => (s === '#app' ? app : el()), querySelectorAll: () => [], getElementById: () => el(),
  addEventListener() {}, createElement: () => el(), body: el(), documentElement: el(), hidden: false,
};
vm.createContext(ctx);
vm.runInContext(code, ctx);
const run = (js) => vm.runInContext(js, ctx);
const setOk = run('ui.set.fs==="l"&&ui.set.bgm===0&&ui.set.voice===0&&ui.set.theme==="dark"');

const errs = [], seen = {}, times = [];
ctx.__shot = () => {
  const t0 = Date.now();
  try { run('render()'); } catch (e) { errs.push(run('S?S.phase:"title"') + ': ' + e.message); }
  times.push(Date.now() - t0);
  if (app.innerHTML.length < 80) errs.push(run('S?S.phase:"title"') + ': 画面が空');
  if (app.innerHTML.includes('表示中に問題が起きました')) errs.push(run('S?S.phase:"title"') + ': 復帰の画面が出た');
  seen[run('S?S.phase:"title"')] = 1;
};

function season(g, diff, chal) {
  run(`S=newGame('${g}','${diff}',${chal ? `'${chal}'` : 'null'});__shot();
  var c=S.tr.slice();watchVideo(S,c[0].id);S.sel=c.slice(0,S.caps.sel).map(function(t){return t.id;});confirmSelect(S);__shot();startSeason(S);
  alive(S).forEach(function(t,i){if(i%2)t.temperRev=true;});
  for(var r=1;r<=NROUND;r++){__shot();S.plan.acts.stage=S.budget>=60;applyPlan(S);__shot();applyLesson(S);S.phase='talk';__shot();
    ui.tfilter='story';__shot();ui.tsort='pop';__shot();ui.tfilter='all';ui.tsort='story';
    S.reqs.forEach(function(q,qi){answerReq(S,qi,qi%2);});__shot();
    var t=alive(S)[0];doTalk(S,t.id);__shot();if(S.talk){if(S.talk.kind==='arc')talkChoose(S,0);else if(S.talk.kind==='honne')honneChoose(S,0);else if(S.talk.kind==='free')freeChoose(S,1);__shot();S.talk=null;}
    if(S.ap>0){doOut(S,alive(S)[1].id,0);__shot();if(S.talk){outChoose(S,0);__shot();S.talk=null;}}
    var pl=pairList(S)[0];if(pl&&S.ap>0){doPair(S,pl.a,pl.b);__shot();S.talk=null;}
    S.ap=0;afterTalk(S);__shot();if(S.phase==='interview'){__shot();applyInterview(S);}
    while(S.phase==='event'){__shot();resolveEvent(S,r%3);__shot();nextEvent(S);}
    __shot();S.phase='stage';__shot();if(ROUNDS[r].crit){S.phase='critique';__shot();applyCritique(S);__shot();}
    applyFeature(S);toNight(S);if(S.phase==='night'){__shot();nightSkip(S);S.phase='judge';}
    var B=alive(S),res=S.stage.res,n=ROUNDS[r].fin?Math.min(6,S.caps.finMax,B.length):capOf(S);
    B.sort(function(a,b){return res[b.id].sc-res[a.id].sc;}).slice(0,n).forEach(function(t){S.pass[t.id]=true;});__shot();
    decide(S);__shot();S.call.n=S.call.order.length;S.call.done=true;__shot();if(!ROUNDS[r].fin)nextRound(S);}
  applyFarewell(S);startPrep(S);__shot();S.prep.color=2;S.prep.song=1;var D=S.tr.filter(function(t){return t.status==='debut';});S.prep.leader=D[0].id;
  startMonth(S);__shot();['tv','mv','rest','tv'].forEach(function(k){weekDo(S,k);});__shot();finishMonth(S);__shot();
  S.ending=false;__shot();ui.prof=D[0].id;__shot();ui.prof=null;S.bursts=[];__shot();`);
}
const cases = [['m', 'normal', null], ['f', 'hard', 'poor'], ['m', 'easy', 'small'], ['f', 'normal', 'busy'], ['m', 'normal', null]];
for (const [g, d, c] of cases) season(g, d, c);
run(`S=null;ui.settings=true;__shot();ui.settings=false;ui.gloss=true;__shot();ui.gloss=false;ui.hallAll=true;ui.meikanAll=true;__shot();`);
run(`S=newGame('m','normal',null,todayKey());__shot();S=null;`);

const need = ['title', 'select', 'format', 'plan', 'lesson', 'talk', 'interview', 'event', 'stage', 'critique', 'judge', 'call', 'prep', 'month', 'result'];
const miss = need.filter((p) => !seen[p]);
const avg = times.reduce((a, b) => a + b, 0) / times.length, max = Math.max(...times);
console.log('描いた回数', times.length, '・平均', avg.toFixed(1) + 'ms', '・最大', max + 'ms', '・描いた画面', Object.keys(seen).length + '種');
if (!setOk) { console.error('保存した設定が、開き直すと初期値に戻っている'); process.exitCode = 1; }
if (miss.length) { console.error('描けていない画面:', miss.join(' ')); process.exitCode = 1; }
if (errs.length) { console.error('エラー', errs.length + '件'); errs.slice(0, 10).forEach((e) => console.error('  ' + e)); process.exitCode = 1; }
else console.log('エラー 0件');
