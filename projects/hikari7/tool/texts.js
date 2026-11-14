// 文章の点検：ブラウザなしで何シーズンも遊ばせ、画面に出た文を集めて、
//   ・差し込みの漏れ（{A}・undefined・NaN など）
//   ・同じ文が何度も出ていないか（1シーズンに3回以上出る文）
//   ・合格のひと言・世間の声・不合格の子の最後のひと言が、1シーズンの中で重なっていないか（重なれば失敗）
// を数える。  node tool/texts.js [シーズン数=12] [--dump 出力先]
// 文の中身は確かめない（それは人が読む）。漏れがあれば失敗で終わる。
const fs = require('fs'), vm = require('vm'), path = require('path');
const src = fs.readFileSync(path.join(__dirname, '..', 'prototype', 'game.html'), 'utf8');
const code = src.slice(src.lastIndexOf('<script>') + 8, src.lastIndexOf('</script>'));
const N = +(process.argv[2] || 12);
const di = process.argv.indexOf('--dump'), dumpTo = di > 0 ? process.argv[di + 1] : null;

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
const app = el(), store = new Map();
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

// 物語の文だけを拾う（ボタンや見出しの決まり文句は数えない）
const NARR = ['event', 'talk', 'show', 'night', 'interview', 'month', 'result'];
const LEAK = /\{[A-Z]\}|undefined|NaN|\bnull\b|\[object|function ?\(|「「|」」|。。|、、/;
const strip = (h) => h.replace(/<(script|style)[\s\S]*?<\/\1>/g, '').replace(/<[^>]+>/g, '\n').replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"');
let season = 0;
// 合格のひと言（デビュー発表も）と世間の声は、1シーズンに同じ文を出さない（2026-11-14）。名前を伏せて比べる
// 不合格の子の最後のひと言も（2026-11-15）。描き直しても同じ文のままかも見る
const dupSeen = new Set(), dups = [];
let dupN = 0, lwN = 0;
ctx.__chk = () => {
  const names = run('S.tr.map(function(t){return [t.name,t.giv];})').flat().filter(Boolean).sort((a, b) => b.length - a.length);
  const mask = (x) => { let k = String(x); names.forEach((n) => { k = k.split(n).join('〇'); }); return k; };
  const lines = run('Object.keys(S.call.lines).map(function(k){return S.call.lines[k];})'), cmts = run('S.comments.map(function(x){return x.t;})');
  const lw = run('S.call.failed.map(function(id){return lastWords(S,S.tr[id]);})');
  if (run('S.call.failed.some(function(id){return lastWords(S,S.tr[id])!==S.tr[id].lw.s;})')) dups.push('不合格のひと言が描き直しで変わった'); lwN += lw.length;
  [['合格のひと言', lines], ['世間の声', cmts], ['不合格のひと言', lw]].forEach(([kind, arr]) => arr.forEach((x) => {
    const key = season + '\t' + kind + '\t' + mask(x); dupN++;
    if (dupSeen.has(key)) dups.push(`シーズン${season} ${kind}: ${x}`); else dupSeen.add(key);
  }));
};
const per = new Map(), leaks = [], all = [];
ctx.__shot = () => {
  try { run('render()'); } catch (e) { return; }
  const ph = run('S?S.phase:"title"');
  // 漏れはどの画面でも見る。繰り返しを数えるのは物語の文だけ
  const txt = strip(app.innerHTML);
  if (LEAK.test(txt)) { const h = app.innerHTML, m = h.search(LEAK); leaks.push(ph + ': ' + h.slice(Math.max(0, m - 160), m + 60).replace(/\s+/g, ' ')); }
  if (NARR.indexOf(ph) < 0) return;
  // 名前は人ごとに違うので、文を比べるときは名前を伏せる
  const names = run('S?S.tr.map(function(t){return [t.name,t.giv];}):[]').flat().filter(Boolean).sort((a, b) => b.length - a.length);
  txt.split(/\n+|(?<=[。！？」])/).map((x) => x.trim()).filter((x) => x.length >= 12 && /[。！？」]$/.test(x)).forEach((x) => {
    let k = x; names.forEach((n) => { k = k.split(n).join('〇'); });
    all.push(ph + '\t' + x);
    const m = per.get(k) || { n: 0, s: new Set(), ph };
    m.n++; m.s.add(season); per.set(k, m);
  });
};

// 遊び方は毎回ばらばらに（選ぶ番号も、話す相手も）
function play(g, diff) {
  run(`S=newGame('${g}','${diff}',null);__shot();
  var c=S.tr.slice();S.sel=c.slice(0,S.caps.sel).map(function(t){return t.id;});confirmSelect(S);startSeason(S);
  for(var r=1;r<=NROUND;r++){__shot();applyPlan(S);__shot();applyLesson(S);S.phase='talk';__shot();
    for(var k=0;k<4&&S.ap>0;k++){var A=alive(S),t=A[ri(0,A.length-1)];
      if(k===1){doOut(S,t.id,ri(0,OUTS.length-1));__shot();if(S.talk&&!S.talk.res){outChoose(S,ri(0,2));__shot();}S.talk=null;continue;}
      doTalk(S,t.id);__shot();if(S.talk&&!S.talk.res){if(S.talk.kind==='arc')talkChoose(S,ri(0,2));else if(S.talk.kind==='honne')honneChoose(S,ri(0,2));else if(S.talk.kind==='free')freeChoose(S,ri(0,2));__shot();}S.talk=null;}
    S.ap=0;afterTalk(S);if(S.phase==='interview'){__shot();applyInterview(S);}
    while(S.phase==='event'){__shot();resolveEvent(S,ri(0,2));__shot();nextEvent(S);}
    S.phase='show';__shot();if(S.show){S.show.seq=showSeq(S,'all');for(var q=0;q<S.show.seq.length;q++){S.show.pos=q;__shot();}}
    S.phase='stage';if(ROUNDS[r].crit){S.phase='critique';alive(S).forEach(function(t){S.crit[t.id]=ri(0,CRIT.length-1);});__shot();applyCritique(S);__shot();}
    applyFeature(S);toNight(S);if(S.phase==='night'){__shot();nightSkip(S);S.phase='judge';}
    var B=alive(S),res=S.stage.res,n=ROUNDS[r].fin?Math.min(6,S.caps.finMax,B.length):capOf(S);
    B.sort(function(a,b){return res[b.id].sc-res[a.id].sc;}).slice(0,n).forEach(function(t){S.pass[t.id]=true;});
    decide(S);__chk();S.call.n=S.call.order.length;S.call.done=true;if(!ROUNDS[r].fin)nextRound(S);}
  applyFarewell(S);startPrep(S);S.prep.color=ri(0,5);S.prep.song=0;var D=S.tr.filter(function(t){return t.status==='debut';});S.prep.leader=D[0].id;
  startMonth(S);__shot();['tv','mv','rest','tv'].forEach(function(k){weekDo(S,k);__shot();});finishMonth(S);__shot();`);
}
for (season = 0; season < N; season++) {
  try { play(season % 2 ? 'f' : 'm', ['normal', 'easy', 'hard'][season % 3]); } catch (e) { console.error('シーズン', season, 'で止まった:', e.message); process.exitCode = 1; }
}

const rows = [...per.entries()].map(([k, m]) => ({ k, n: m.n, s: m.s.size, ph: m.ph }));
const heavy = rows.filter((r) => r.n / N >= 3).sort((a, b) => b.n - a.n);
console.log(`${N}シーズン・文 ${all.length}件・違う文 ${rows.length}種`);
console.log('1シーズンに3回以上出る文（名前は〇）:');
heavy.slice(0, 40).forEach((r) => console.log(`  ${(r.n / N).toFixed(1)}回  [${r.ph}] ${r.k.slice(0, 70)}`));
if (dumpTo) fs.writeFileSync(dumpTo, all.join('\n'));
console.log(`シーズン内の重なり（合格のひと言・世間の声・不合格のひと言 ${dupN}件を確かめた。うち不合格のひと言 ${lwN}件）: ${dups.length}件`);
if (!lwN) { console.error('不合格のひと言を1件も確かめていない'); process.exitCode = 1; }
if (dups.length) { [...new Set(dups)].slice(0, 15).forEach((x) => console.error('  ' + x)); process.exitCode = 1; }
if (leaks.length) { console.error('差し込みの漏れ', leaks.length + '件'); [...new Set(leaks)].slice(0, 15).forEach((x) => console.error('  ' + x)); process.exitCode = 1; }
else console.log('差し込みの漏れ 0件');
