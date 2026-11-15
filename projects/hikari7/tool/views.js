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
// 札の色分けに使う名前（class="tag ○○"）が、ほかの部品の見た目の指定に単独で使われていないか
// （2026-10-03：レッスンの行の .lt に付けた格子の指定が、札の .tag.lt にも当たって崩れた）
const css = src.slice(src.indexOf('<style'), src.indexOf('</style>'));
const tagMods = [...new Set([...src.matchAll(/class=\\?"tag ([a-z][\w-]*)/g)].map((m) => m[1]))];
const clash = tagMods.filter((k) => new RegExp('(^|[}\\s,])\\.' + k + '(?=[\\s{>:])').test(css));
// 12px 未満の字の指定が無いか（2026-11-14：<small> の既定の縮みで 10px 台が出ていた。計算後の大きさは見られないので、指定の値で見る）
const tinyFs = [];
for (const m of src.matchAll(/font-size:\s*([\d.]+)px/g)) if (+m[1] < 12) tinyFs.push(m[0]);
for (const m of src.matchAll(/font-size="([\d.]+)"/g)) if (+m[1] < 12) tinyFs.push(m[0]);
for (const m of css.matchAll(/font-size:\s*(smaller|x-small|xx-small|small)/g)) tinyFs.push(m[0]);
const smallRule = /(^|[}\s])small\{font-size:max\(12px,/m.test(css);
// 押せる範囲を44ptまで広げる指定（2026-11-15：見た目はそのままで、発表の席の顔・合格発表の🔊・特性の札・狭い画面のレッスンの担当）
const hitRules = { '発表の席の顔': /\.cshit\{[^}]*min-width:44px;min-height:44px/, '合格発表の台詞': /\.call \.who>\[data-a=say\]\{padding:12px 0;margin:-12px 0\}/,
  '特性の札': /\.trt\[data-a\]::after\{[^}]*top:-12px;bottom:-12px/, '狭い画面のレッスンの担当': /body\.nar \.lpick\{flex-wrap:wrap\}/ };
const hitMiss = Object.keys(hitRules).filter((k) => !hitRules[k].test(css));
const setOk = run('ui.set.fs==="l"&&ui.set.bgm===0&&ui.set.voice===0&&ui.set.theme==="dark"');

const errs = [], seen = {}, times = [];
ctx.__shot = () => {
  const t0 = Date.now();
  try { run('render()'); } catch (e) { errs.push(run('S?S.phase:"title"') + ': ' + e.message); }
  times.push(Date.now() - t0);
  if (app.innerHTML.length < 80) errs.push(run('S?S.phase:"title"') + ': 画面が空');
  if (app.innerHTML.includes('表示中に問題が起きました')) errs.push(run('S?S.phase:"title"') + ': 復帰の画面が出た');
  seen[run('S?S.phase:"title"')] = 1;
  if (run('!!(S&&S.phase==="result")')) shareChk();
};

// 結果をシェアの画像（2026-11-15）：結果の画面を描くたびに、シェアの画像も仮の canvas に描く。
// 例外・座標の NaN・字の undefined/NaN・中身の欠け（題名・評価・デビュー組の名前）を数える
let shareN = 0;
function shareChk() {
  const texts = [], bad = [];
  const c2d = new Proxy({ measureText: (t) => ({ width: String(t).length * 20 }), createLinearGradient: () => ({ addColorStop() {} }), createRadialGradient: () => ({ addColorStop() {} }) }, {
    get: (o, k) => (k in o ? o[k] : (...a) => {
      if (k === 'fillText') texts.push(String(a[0]));
      if (a.some((x) => typeof x === 'number' && !isFinite(x))) bad.push(k + '(' + a.join(',') + ')');
    }),
    set: (o, k, v) => { o[k] = v; return true; },
  });
  ctx.__c2d = c2d;
  const ph = run('S.phase+(S.ending?"(ending)":"")');
  try { run('(function(){var E=finalEval(S),P=S.prep||{names:["x"],name:0};drawShare(__c2d,S,E,P,shareMembers(E).map(function(){return null;}));})()'); }
  catch (e) { errs.push('share ' + ph + ': ' + e.message); return; }
  shareN++;
  const need = ['ひかりの', '指名', run('finalEval(S).grade'), run('finalEval(S).total.toFixed(1)')].concat(JSON.parse(run('JSON.stringify(finalEval(S).D.map(function(t){return t.name;}))')));
  const miss = need.filter((x) => !texts.includes(x));
  if (miss.length) errs.push('share: 描いていない ' + miss.join('・'));
  if (bad.length) errs.push('share: 数でない座標 ' + bad.slice(0, 2).join(' '));
  const ng = texts.filter((t) => /undefined|NaN|null|アイドル/.test(t));
  if (ng.length) errs.push('share: 字の漏れ ' + ng[0]);
}

// 講評の画面（2026-11-15）：選ぶ子は1人1行、押すと8択のシート。前の「1人に8つのボタン」の列が戻っていないか
let critChk = 0;
ctx.__critChk = (sheet) => {
  const h = app.innerHTML, n = run('Object.keys(critSet(S)).length'), rows = (h.match(/class="crrow/g) || []).length;
  if (rows !== n) errs.push('critique: 行が ' + rows + '（選ぶ子は ' + n + '人）');
  if (/class="seg crg|data-a="crit" /.test(h) && !sheet) errs.push('critique: シートの外に講評のボタンが並んでいる');
  if (sheet && (h.match(/class="crop/g) || []).length !== run('CRIT.length')) errs.push('critique: シートの選択肢が ' + (h.match(/class="crop/g) || []).length + '個');
  critChk++;
};

function season(g, diff, chal) {
  run(`S=newGame('${g}','${diff}',${chal ? `'${chal}'` : 'null'});__shot();
  var c=S.tr.slice();watchVideo(S,c[0].id);S.sel=c.slice(0,S.caps.sel).map(function(t){return t.id;});confirmSelect(S);__shot();startSeason(S);
  alive(S).forEach(function(t,i){if(i%2)t.temperRev=true;});
  for(var r=1;r<=NROUND;r++){__shot();ui.planTab={r:S.rnd,v:'use'};__shot();ui.planTab=null;ui.tipOpen=S.phase;__shot();ui.tipOpen=null;S.plan.acts.stage=S.budget>=60;applyPlan(S);__shot();applyLesson(S);S.phase='lres';__shot();S.phase='talk';__shot();
    ui.tfilter='story';__shot();ui.tsort='pop';__shot();ui.tfilter='all';ui.tsort='story';
    S.reqs.forEach(function(q,qi){answerReq(S,qi,qi%2);});__shot();
    var t=alive(S)[0];doTalk(S,t.id);__shot();if(S.talk){if(S.talk.kind==='arc')talkChoose(S,0);else if(S.talk.kind==='honne')honneChoose(S,0);else if(S.talk.kind==='free')freeChoose(S,1);__shot();S.talk=null;}
    if(S.ap>0){doOut(S,alive(S)[1].id,0);__shot();if(S.talk){outChoose(S,0);__shot();S.talk=null;}}
    var pl=pairList(S)[0];if(pl&&S.ap>0){doPair(S,pl.a,pl.b);__shot();S.talk=null;}
    S.ap=0;afterTalk(S);__shot();if(S.phase==='interview'){__shot();applyInterview(S);}
    while(S.phase==='event'){__shot();resolveEvent(S,r%3);__shot();nextEvent(S);}
    __shot();S.phase='stage';__shot();if(ROUNDS[r].crit){S.phase='critique';__shot();__critChk(false);var cs=Object.keys(critSet(S));ui.critOpen=+cs[0];__shot();__critChk(true);ui.critOpen=+cs[cs.length-1];__shot();__critChk(true);ui.critOpen=null;
      alive(S).forEach(function(t){S.crit[t.id]=ri(0,CRIT.length-1);});__shot();__critChk(false);applyCritique(S);__shot();}
    applyFeature(S);toNight(S);if(S.phase==='night'){__shot();nightSkip(S);S.phase='judge';}
    var B=alive(S),res=S.stage.res,n=ROUNDS[r].fin?Math.min(6,S.caps.finMax,B.length):capOf(S);
    B.sort(function(a,b){return res[b.id].sc-res[a.id].sc;}).slice(0,n).forEach(function(t){S.pass[t.id]=true;});__shot();
    decide(S);__shot();S.call.n=S.call.order.length-1;ui.lastRoll={i:0};__shot();ui.lastRoll=null;S.call.n=S.call.order.length;__shot();S.call.done=true;__shot();if(!ROUNDS[r].fin)nextRound(S);}
  applyFarewell(S);startPrep(S);__shot();S.prep.color=2;S.prep.song=1;var D=S.tr.filter(function(t){return t.status==='debut';});S.prep.leader=D[0].id;
  startMonth(S);__shot();['tv','mv','rest','tv'].forEach(function(k){weekDo(S,k);});__shot();finishMonth(S);__shot();
  S.ending=false;__shot();ui.prof=D[0].id;__shot();ui.prof=null;S.bursts=[];__shot();`);
}
const cases = [['m', 'normal', null], ['f', 'hard', 'poor'], ['m', 'easy', 'small'], ['f', 'normal', 'busy'], ['m', 'normal', null]];
for (const [g, d, c] of cases) season(g, d, c);
// 結末の筋（C・D の解散・休止）のエンドロールと結果の画面も描く
run(`['S','B','C','D','C','D'].forEach(function(gr){S.future=makeFuture(S,Object.assign({},finalEval(S),{grade:gr}));S.ending=true;__shot();S.ending=false;__shot();});`);
run(`S=null;ui.tsub='new';__shot();ui.tsub='rec';__shot();ui.tsub=null;ui.settings=true;__shot();ui.settings=false;ui.gloss=true;__shot();ui.gloss=false;ui.hallAll=true;ui.meikanAll=true;__shot();`);
run(`S=newGame('m','normal',null,todayKey());__shot();S=null;`);
// アプリの中の画面（2026-11-15）：タイトルの「広告を消す」・動画の特典に添える一言・全画面広告のあとの案内
run(`APP={adFree:false,canBuy:true,price:'¥370',store:{},owned:{},prices:{}};S=null;__shot();
  S=newGame('f','normal',null);var c=S.tr.slice();S.sel=c.slice(0,S.caps.sel).map(function(t){return t.id;});confirmSelect(S);startSeason(S);applyPlan(S);__shot();
  S.tr.slice(0,6).forEach(function(t){t.status='debut';});startPrep(S);S.prep.leader=S.tr[0].id;startMonth(S);__shot();
  ui.upsell=1;__shot();APP.price=null;__shot();APP.adFree=true;__shot();ui.upsell=0;S=null;__shot();APP=null;`);
if (!/class="tbuy"/.test(run(`(function(){APP={adFree:false,canBuy:true,price:'¥370'};var h=vTitle();APP=null;return h;})()`))) errs.push('title: アプリの「広告を消す」が描けていない');

const need = ['title', 'select', 'format', 'plan', 'lesson', 'lres', 'talk', 'interview', 'event', 'stage', 'critique', 'judge', 'call', 'prep', 'month', 'result'];
const miss = need.filter((p) => !seen[p]);
const avg = times.reduce((a, b) => a + b, 0) / times.length, max = Math.max(...times);
console.log('描いた回数', times.length, '・平均', avg.toFixed(1) + 'ms', '・最大', max + 'ms', '・描いた画面', Object.keys(seen).length + '種');
if (clash.length) { console.error('札の名前が、ほかの部品の見た目にも使われている: ' + clash.join(' ')); process.exitCode = 1; }
if (tinyFs.length) { console.error('12px 未満の字の指定: ' + [...new Set(tinyFs)].join(' ')); process.exitCode = 1; }
if (!smallRule) { console.error('<small> を12px未満にしない指定（small{font-size:max(12px,…)}）が無い'); process.exitCode = 1; }
else console.log('字の大きさの指定: 12px 未満 ' + tinyFs.length + '件');
if (!shareN) { console.error('シェアの画像の点検が1回も走っていない'); process.exitCode = 1; } else console.log('シェアの画像の点検 ' + shareN + '回（描くときのエラー・字の漏れ・中身の欠け）');
if (!critChk) { console.error('講評の画面の点検が1回も走っていない'); process.exitCode = 1; } else console.log('講評の画面の点検 ' + critChk + '回（1人1行・8択のシート）');
if (hitMiss.length) { console.error('押せる範囲の指定が無い: ' + hitMiss.join('・')); process.exitCode = 1; }
else console.log('押せる範囲の指定: ' + Object.keys(hitRules).length + '件あり');
if (!setOk) { console.error('保存した設定が、開き直すと初期値に戻っている'); process.exitCode = 1; }
if (miss.length) { console.error('描けていない画面:', miss.join(' ')); process.exitCode = 1; }
if (errs.length) { console.error('エラー', errs.length + '件'); errs.slice(0, 10).forEach((e) => console.error('  ' + e)); process.exitCode = 1; }
else console.log('エラー 0件');
