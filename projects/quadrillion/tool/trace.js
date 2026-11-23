// 試作の仕組みを、決まった乱数（Park-Miller）と決まった手順で動かし、毎月の数字を JSON に書き出す。
// Dart 側の test/prototype_trace_test.dart が同じ乱数・同じ手順で動かして突き合わせる。
// 使い方: node tool/trace.js <prototype.html> > test/fixtures/trace.json
const fs = require('fs'), vm = require('vm');
const html = fs.readFileSync(process.argv[2], 'utf8');
let code = html.match(/<script id="logic">([\s\S]*?)<\/script>/)[1];
const swap = (a, b) => { if (!code.includes(a)) throw new Error('置き換え元が見つからない: ' + a); code = code.replace(a, b); };
// 乱数を差し替える（Dart の ParkMiller と同じ）
swap('const R=()=>Math.random();', 'let SEED=1;const R=()=>{SEED=SEED*16807%2147483647;return (SEED-1)/2147483646};function shuf(a){for(let i=a.length-1;i>0;i--){const j=Math.floor(R()*(i+1));const t=a[i];a[i]=a[j];a[j]=t}return a}');
// sort(()=>R()-.5) は Dart と同じ入れ替え方にそろえる
swap('[...RIVALS].sort(()=>R()-.5)', 'shuf([...RIVALS])');
swap('mgrs.slice().sort(()=>R()-.5)', 'shuf(mgrs.slice())');
const ctx = { console, Math, JSON, Object, Array, Set, String, Number, isFinite, RegExp }; vm.createContext(ctx);
vm.runInContext(code + ';this.api={setSeed:s=>{SEED=s},CTRY,ctryOf,cw,entryModes,entryCost,enterCountry,newGame,nextQuarter,startBiz,develop,build,addCrew,crewEff,hire,ipo,canIPO,liveInds,capexOf,INDM,rankList,tob,tobChance,tobCost,merge,canMerge,subs,vcRaise,publicOffer,doWhiteKnight,doBuyback,get S(){return S}}', ctx);
const A = ctx.api;
const CHOICE = /断る|謝罪|送り出す|上げる|自社株|ホワイト/;

function run(seed, cfg, months) {
  A.setSeed(seed);
  A.newGame(cfg); const S = A.S;
  const rows = [];
  const tot = p => p.ab.tou + p.ab.kai + p.ab.ei + p.ab.zai;
  for (let t = 0; t < months && !S.over; t++) {
    while (S.events.length) { const e = S.events.shift(); const ch = e.choices.find(c => CHOICE.test(c.l)) || e.choices[e.choices.length - 1]; ch.f() }
    if (!S.biz.length) { const first = A.liveInds().filter(i => A.capexOf(i) <= S.cash).sort((a, b) => b.mg - a.mg)[0]; if (first) A.startBiz(first.id) }
    if (S.staff.length < S.biz.length && S.cands.length && S.pre > S.cands[0].salary * 3) A.hire(S.cands.slice().sort((a, b) => tot(b) - tot(a))[0]);
    for (const b of S.biz) if (!b.mgr) { const free = S.staff.find(p => !S.biz.some(x => x.mgr === p.id)); if (free && S.biz.filter(x => !x.mgr).length > 2) b.mgr = free.id }
    if (A.canIPO()) A.ipo();
    if (!S.listed && S.sh.own > 60 && S.cap > S.cash * 20 && S.ap > 0) A.vcRaise();
    if (S.listed && S.sh.own > 45 && S.cap > S.cash * 15 && S.ap > 0) A.publicOffer();
    const top = S.biz.slice().sort((x, y) => y.rev - x.rev)[0];
    if (top && S.ap > 0) { const cs = A.CTRY.filter(x => !A.ctryOf(top).includes(x.c)).sort((p, q) => A.cw(q.c, S.year) - A.cw(p.c, S.year)); for (const x of cs.slice(0, 3)) { const ms = A.entryModes(top, x.c); const m = ms.includes('solo') ? 'solo' : ms[0]; if (m && S.cash > A.entryCost(top, x.c, m) * 2) { A.enterCountry(top, x.c, m); break } } }
    const cand = A.liveInds().filter(i => !S.biz.some(b => b.ind === i.id) && A.capexOf(i) < S.cash * .8).sort((a, b) => b.mg * b.size - a.mg * a.size);
    if (cand.length && S.ap > 0 && S.biz.length < 12) A.startBiz(cand[0].id);
    for (let k = 0; k < 3 && S.ap > 0; k++) { const b = S.biz.slice().sort((x, y) => (y.profit / (y.rev + 1)) * (1 - y.share) - (x.profit / (x.rev + 1)) * (1 - x.share))[0]; if (!b) break;
      if (S.cash > A.capexOf(A.INDM[b.ind]) * .3) { if (A.crewEff(b) < b.power * 1.05) A.addCrew(b, .2); else if (k == 0) A.build(b, .4); else A.develop(b, .2) } else break }
    if (S.ap > 0 && S.cash > S.cap * .3) { const tg = S.cos.filter(c => c.alive && c.parent !== 'player' && A.tobCost(c, 50.1) < S.cash * .7 && A.tobChance(c, 50.1) > .4).sort((a, b) => b.cap - a.cap)[0]; if (tg) A.tob(tg, 50.1) }
    for (const c of A.subs()) if (A.canMerge(c) && S.ap > 0) A.merge(c);
    if (Math.max(0, ...Object.values(S.sh.riv)) > 20 && S.ap > 0) A.doWhiteKnight();
    A.nextQuarter();
    rows.push([S.year, S.q, S.cash, S.cap, S.rev, S.pre, S.debt, S.biz.length, S.staff.length, S.cos.filter(c => c.alive).length, S.ap, S.rank, S.biz.reduce((s, b) => s + b.power, 0), S.log.length, S.sh.own]);
  }
  return rows;
}
const cases = [
  { seed: 12345, cfg: { mode: 'world', year: 1980, traits: ['charm', 'gambler'], home: 'jp' } },
  { seed: 777, cfg: { mode: 'quad', year: 2000, traits: ['tech', 'noble'], home: 'us' } },
  { seed: 4242, cfg: { mode: 'endless', year: 2025, traits: ['oneman', 'careful'], home: 'in' } },
];
const months = +(process.argv[3] || 48);
console.log(JSON.stringify(cases.map(c => ({ ...c, months, rows: run(c.seed, c.cfg, months) }))));
