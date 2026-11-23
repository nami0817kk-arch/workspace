// 一続きの試合（src/live.js）の点検：落ちない・得点とシュートの数・保持・パスの成功・強い側が勝つ割合・速さ
'use strict';
const path = require('path');
require(path.join(__dirname, '../src/data.js'));
require(path.join(__dirname, '../src/engine.js'));
require(path.join(__dirname, '../src/live.js'));
require(path.join(__dirname, '../src/livematch.js'));
const YA = globalThis.YA;
let fails = 0;
const ok = (c, m) => {
  if (!c) {
    fails++;
    console.log('FAIL:', m);
  }
};
const N = +(process.env.N || 24);
function play(seed, opp, opt) {
  opt = opt || {};
  const home = YA.makeOurs(1);
  const away = YA.makeOpponent(YA.OPPONENTS[opp], seed * 7 + 3);
  if (opt.boost) for (const p of Object.values(home.players)) for (const k of Object.keys(p.ab)) p.ab[k] = Math.min(20, p.ab[k] + opt.boost);
  const m = new YA.Match({ seed, home, away, settings: { autoStop: false, live: true } });
  let g = 0;
  while (!m.finished && g++ < 2000) m.step();
  ok(m.finished, '最後まで進まない ' + seed);
  m.live.m = m;
  return m.live;
}
const sum = { goals: 0, shots: 0, onT: 0, xg: 0, pass: 0, passOk: 0, tackles: 0, tackOk: 0, fouls: 0, corners: 0, offside: 0, saves: 0, pk: 0, throws: 0, gk: 0, intercept: 0 };
const res = [0, 0, 0];
let possH = 0;
const t0 = Date.now();
for (let s = 1; s <= N; s++) {
  const lv = play(s, s % 3);
  const g = { home: 0, away: 0 };
  for (const e of lv.events) {
    if (e.k === 'goal') { sum.goals++; g[e.sd]++; }
    if (e.k === 'shot') { sum.shots++; sum.xg += e.xg; if (e.onT) sum.onT++; }
    if (e.k === 'save') sum.saves++;
    if (e.k === 'tackle') { sum.tackles++; if (e.ok) sum.tackOk++; }
    if (e.k === 'foul') sum.fouls++;
    if (e.k === 'offside') sum.offside++;
    if (e.k === 'intercept') sum.intercept++;
    if (e.k === 'dead' && e.type === 'corner') sum.corners++;
    if (e.k === 'dead' && e.type === 'pk') sum.pk++;
    if (e.k === 'dead' && e.type === 'throw') sum.throws++;
    if (e.k === 'dead' && e.type === 'goalkick') sum.gk++;
  }
  sum.pass += lv.passes.home + lv.passes.away;
  sum.passOk += lv.passes.homeOk + lv.passes.awayOk;
  possH += lv.poss.home / (lv.poss.home + lv.poss.away);
  res[g.home > g.away ? 0 : g.home === g.away ? 1 : 2]++;
  if (process.env.V) console.log(s, g.home + '-' + g.away, 'shots', lv.events.filter((e) => e.k === 'shot').length, '見どころ', lv.m.scenes.length, '記録の点', lv.m.score.home + '-' + lv.m.score.away);
  ok(lv.m.score.home === g.home && lv.m.score.away === g.away, '得点の数が記録と合わない ' + s);
  ok(lv.m.scenes.filter((sc) => sc.goal).length === g.home + g.away, '得点の見どころが得点の数と合わない ' + s);
}
const per = (k) => (sum[k] / N).toFixed(1);
const ms = (Date.now() - t0) / N;
console.log('1試合あたり: 得点', per('goals'), 'シュート', per('shots'), '枠内', per('onT'), 'xG', per('xg'), 'セーブ', per('saves'), 'パス', per('pass'), '成功', ((sum.passOk / sum.pass) * 100).toFixed(0) + '%', 'カット', per('intercept'));
console.log('タックル', per('tackles'), '成功', ((sum.tackOk / Math.max(1, sum.tackles)) * 100).toFixed(0) + '%', 'ファウル', per('fouls'), 'CK', per('corners'), 'PK', per('pk'), 'スロー', per('throws'), 'GK', per('gk'), 'オフサイド', per('offside'));
console.log('ホームの保持', ((possH / N) * 100).toFixed(0) + '%', '勝分負', res.join('/'), '1試合', ms.toFixed(0) + 'ms');
ok(sum.goals / N > 1.6 && sum.goals / N < 3.8, '得点が多すぎ・少なすぎ');
// 強い側が勝つ：こちら�