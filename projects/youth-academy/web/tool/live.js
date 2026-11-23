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
  if (opt.tactic) Object.assign(home.tactic, opt.tactic);
  const m = new YA.Match({ seed, home, away, settings: { autoStop: false, live: true, record: !!opt.record } });
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
// 強い側が勝つ：こちらの能力を全部 +BOOST にして、勝ち点の割合が上がる
if (process.env.BOOST !== '0') {
  const B = +(process.env.BOOST || 3);
  let pts = 0;
  let gf = 0;
  let ga = 0;
  const NB = +(process.env.NB || 8);
  for (let s = 1; s <= NB; s++) {
    const lv = play(100 + s, s % 3, { boost: B });
    gf += lv.m.score.home;
    ga += lv.m.score.away;
    pts += lv.m.score.home > lv.m.score.away ? 3 : lv.m.score.home === lv.m.score.away ? 1 : 0;
  }
  console.log('能力+' + B + 'のとき：勝ち点 ' + (pts / NB).toFixed(2) + '/試合', '得点 ' + (gf / NB).toFixed(1) + ' 失点 ' + (ga / NB).toFixed(1));
  ok(pts / NB > 1.9, '強いチームが勝ちきれない');
}
// 戦い方が動きに出る：幅（持っているときの横の広がり）・プレス（相手が持っているときの寄せの近さと奪う回数）
if (process.env.TAC !== '0') {
  const meas = (tac) => {
    let spread = 0;
    let ns = 0;
    let near = 0;
    let nn = 0;
    let won = 0;
    for (let s = 1; s <= 3; s++) {
      const lv = play(300 + s, 1, { tactic: tac, record: true });
      for (const f of lv.frames) {
        if (f.o < 0) continue;
        const ownHome = f.ro[f.o] && lv.who[f.ro[f.o]].sd === 'home';
        const xs = [];
        let dmin = 99;
        const bo = [f.p[f.o * 2], f.p[f.o * 2 + 1]];
        for (let j = 0; j < f.ro.length; j++) {
          const w = lv.who[f.ro[j]];
          if (w.sd !== 'home' || w.gk) continue;
          if (ownHome) xs.push(f.p[j * 2]);
          else dmin = Math.min(dmin, Math.hypot(f.p[j * 2] - bo[0], f.p[j * 2 + 1] - bo[1]));
        }
        if (ownHome && xs.length) { spread += Math.max(...xs) - Math.min(...xs); ns++; }
        if (!ownHome && dmin < 99) { near += dmin; nn++; }
      }
      for (const e of lv.events) if (e.sd === 'home' && (e.k === 'intercept' || (e.k === 'tackle' && e.ok))) won++;
    }
    return { spread: spread / ns, near: near / nn, won: won / 3 };
  };
  const wide = meas({ width: 0.9 });
  const narrow = meas({ width: 0.1 });
  const hp = meas({ press: 0.95, line: 0.85 });
  const lp = meas({ press: 0.1, line: 0.2 });
  console.log('横の広がり 幅0.9:', wide.spread.toFixed(1) + 'm', '幅0.1:', narrow.spread.toFixed(1) + 'm');
  console.log('寄せの近さ プレス強:', hp.near.toFixed(1) + 'm', '弱:', lp.near.toFixed(1) + 'm', '奪った回数', hp.won.toFixed(0), lp.won.toFixed(0));
  ok(wide.spread > narrow.spread + 4, '幅の戦術が横の広がりに出ない');
  ok(hp.near < lp.near - 0.3, 'プレスの戦術が寄せの近さに出ない');
}
process.exitCode = fails ? 1 : 0;
