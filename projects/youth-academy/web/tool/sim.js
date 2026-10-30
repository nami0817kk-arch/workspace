// 試合エンジンの点検：落ちない・釣り合う・特性や性格が結果に効く・操作の決まりが守られる
'use strict';
const path = require('path');
require(path.join(__dirname, '../src/data.js'));
require(path.join(__dirname, '../src/engine.js'));
const YA = globalThis.YA;
let fails = 0;
const ok = (c, m) => {
  if (!c) {
    fails++;
    console.log('FAIL:', m);
  }
};
const mk = (seed, opp, auto) => new YA.Match({ seed, home: YA.makeOurs(1), away: YA.makeOpponent(YA.OPPONENTS[opp], seed * 7 + 3), settings: { autoStop: !!auto } });
function run(seed, opp) {
  const m = mk(seed, opp, false);
  let guard = 0;
  while (!m.finished && guard++ < 1000) m.step();
  return m;
}

// 1. 通し：300試合が最後まで進み、場面の形が正しい
const types = {};
let goals = 0;
let scenes = 0;
const wins = [0, 0, 0];
const N = 300;
for (let s = 1; s <= N; s++) {
  const m = run(s, s % 3);
  goals += m.score.home + m.score.away;
  scenes += m.scenes.length;
  wins[m.score.home > m.score.away ? 0 : m.score.home === m.score.away ? 1 : 2]++;
  ok(m.finished && m.min === 90, 'finish ' + s);
  ok(m.scenes.length >= 13 && m.scenes.length <= 15, 'scene count ' + m.scenes.length);
  for (const sc of m.scenes) {
    types[sc.type] = (types[sc.type] || 0) + 1;
    ok(sc.frames && sc.frames.length >= 3, 'frames ' + sc.type);
    ok(sc.beats.length >= 2, 'beats ' + sc.type);
    for (let i = 1; i < sc.frames.length; i++) ok(sc.frames[i].t >= sc.frames[i - 1].t, 'frame order ' + sc.type + ' ' + i);
    for (const fr of sc.frames) {
      ok(fr.ball.every(Number.isFinite), 'ball finite ' + sc.type);
      for (const p of Object.values(fr.pos)) ok(p.every(Number.isFinite), 'pos finite ' + sc.type);
    }
    ok(sc.dur >= 3.5 && sc.dur <= 7, 'dur ' + sc.dur);
  }
  ok(m.scenes.filter((x) => x.goal).length === m.score.home + m.score.away, 'goal count');
}
console.log('平均得点', (goals / N).toFixed(2), '平均場面', (scenes / N).toFixed(1), '勝/分/負', wins.join('/'));
console.log('場面の種類', JSON.stringify(types));
ok(goals / N > 1.6 && goals / N < 4.2, '得点の平均が範囲外 ' + goals / N);
for (const t of ['through', 'cross', 'dribble', 'longshot', 'fk', 'ck', 'counter', 'onetwo', 'steal', 'pk']) ok(types[t] > 0, '出ない場面 ' + t);

// 2. 特性が効く：同じ相手・同じ種まきで、特性を外すと裏抜けの成功が減る
function throughStats(strip) {
  let g = 0;
  let tot = 0;
  for (let s = 1; s <= 600; s++) {
    const home = YA.makeOurs(1);
    if (strip) for (const p of Object.values(home.players)) p.traits = p.traits.filter((t) => t !== '裏への抜け出し' && t !== 'スルーパス');
    const m = new YA.Match({ seed: s, home, away: YA.makeOpponent(YA.OPPONENTS[1], s), settings: { autoStop: false } });
    while (!m.finished) m.step();
    for (const sc of m.scenes)
      if (sc.type === 'through' && sc.side === 'home') {
        tot++;
        if (sc.goal || sc.outcome === 'saved' || sc.outcome === 'missed' || sc.outcome === 'blocked' || sc.outcome === 'post') g++;
      }
  }
  return { g, tot };
}
const a = throughStats(false);
const b = throughStats(true);
console.log('裏抜けで1対1まで持ち込めた割合 特性あり', (a.g / a.tot).toFixed(2), '特性なし', (b.g / b.tot).toFixed(2));
ok(a.g / a.tot > b.g / b.tot + 0.03, '特性が裏抜けの成功率に効いていない');

// 3. 場面に効いた特性・性格が記録される
let fxTraits = 0;
let fxPers = 0;
for (let s = 1; s <= 100; s++) {
  const m = run(s, 0);
  for (const sc of m.scenes) for (const f of sc.fx) f.kind === 'trait' ? fxTraits++ : f.kind === 'pers' ? fxPers++ : 0;
}
console.log('効いた特性の記録', fxTraits, '性格', fxPers);
ok(fxTraits > 200 && fxPers > 20, 'fx が少ない');

// 4. 交代の決まり：5人まで・窓3回・GK同士
{
  const m2 = mk(2, 0);
  const t = m2.home;
  m2.min = 30;
  ok(!m2.substitute(t, 'me_9', 'me_12').ok, 'GKとFWの交代は不可');
  ok(m2.substitute(t, 'me_9', 'me_17').ok, '交代1');
  ok(m2.substitute(t, 'me_11', 'me_16').ok, '同じ窓で交代2');
  ok(t.windowsUsed === 1, '窓は1');
  m2.closeWindow(t);
  ok(m2.substitute(t, 'me_7', 'me_20').ok && t.windowsUsed === 2, '窓2');
  m2.closeWindow(t);
  ok(m2.substitute(t, 'me_6', 'me_19').ok && t.windowsUsed === 3, '窓3');
  ok(m2.substitute(t, 'me_8', 'me_14').ok, '5人目（同じ窓）');
  ok(!m2.substitute(t, 'me_10', 'me_15').ok, '6人目は不可');
  const m3 = mk(2, 0);
  m3.min = 30;
  for (const [o, i] of [['me_9', 'me_17'], ['me_11', 'me_16'], ['me_7', 'me_20']]) {
    ok(m3.substitute(m3.home, o, i).ok, 'x');
    m3.closeWindow(m3.home);
  }
  ok(!m3.substitute(m3.home, 'me_6', 'me_19').ok, '4回目の窓は不可');
  ok(m3.home.players.me_9.off, '交代した選手が下がる');
  ok(m3.home.lineup.some((s) => s.pid === 'me_17') && !m3.home.lineup.some((s) => s.pid === 'me_9'), '入れ替わる');
}

// 5. 自動停止：前半終了・残り15分・設定で切れる／ユーザー停止
{
  const m = mk(11, 0, true);
  const reasons = [];
  let g = 0;
  while (!m.finished && g++ < 2000) {
    const e = m.step();
    if (e.type === 'stop') reasons.push(e.reason);
  }
  ok(reasons.indexOf('half') >= 0 && reasons.indexOf('late') >= 0, '節目で止まる ' + reasons);
  const m2 = mk(11, 0, false);
  g = 0;
  let st = 0;
  while (!m2.finished && g++ < 2000) if (m2.step().type === 'stop') st++;
  ok(st === 0, '設定で自動停止を切れる');
  const m3 = mk(3, 1, false);
  m3.step();
  m3.requestStop();
  ok(m3.step().type === 'stop', 'ユーザー停止');
  ok(m3.step().type !== 'stop', '停止のあと再開できる');
  // 失点で止まる
  let conceded = 0;
  for (let s = 1; s <= 60; s++) {
    const mm = mk(s, 0, true);
    let k = 0;
    while (!mm.finished && k++ < 2000) {
      const e = mm.step();
      if (e.type === 'stop' && e.reason === 'conceded') conceded++;
    }
  }
  ok(conceded > 5, '失点で止まる ' + conceded);
}

// 6. 声かけ・指示：性格で反応が分かれる
{
  const m = mk(4, 0, false);
  const t = m.home;
  const c0 = t.players.me_11.conf;
  m.shout(t, 'me_11', 'scold'); // 繊細
  ok(t.players.me_11.conf < c0 - 5, '繊細は叱られて大きく落ちる');
  m.min = 5;
  ok(!m.shout(t, 'me_11', 'scold').ok, '連続の声かけは止める');
  const mm = mk(4, 0, false);
  const c9 = mm.home.players.me_7.conf;
  mm.shout(mm.home, 'me_7', 'praise');
  ok(mm.home.players.me_7.conf > c9, '褒めると自信が上がる');
  let follow = 0;
  let follow2 = 0;
  for (let i = 0; i < 200; i++) {
    const q = mk(i + 1, 0, false);
    if (q.instruct(q.home, 'me_9', 'dribble').followed) follow++;
    if (q.instruct(q.home, 'me_3', 'dribble').followed) follow2++;
  }
  console.log('頑固な9番が従う割合', (follow / 200).toFixed(2), '素直な3番', (follow2 / 200).toFixed(2));
  ok(follow / 200 > 0.5 && follow / 200 < 0.7, '頑固は4割ほど聞き流す');
  ok(follow2 === 200, '素直は必ず従う');
}

// 7. 戦い方の型が場面の出方に効く
{
  const cnt = (type, want) => {
    let c = 0;
    for (let s = 1; s <= 200; s++) {
      const h = YA.makeOurs(1);
      const m0 = new YA.Match({ seed: s, home: h, away: YA.makeOpponent(YA.OPPONENTS[2], s), settings: { autoStop: false } });
      m0.setType(h, type);
      while (!m0.finished) m0.step();
      for (const sc of m0.scenes) if (sc.side === 'home' && want.indexOf(sc.type) >= 0) c++;
    }
    return c;
  };
  const a2 = cnt('カウンター', ['counter', 'through']);
  const b2 = cnt('ポゼッション', ['counter', 'through']);
  const c2 = cnt('サイド攻撃', ['cross']);
  const d2 = cnt('縦に速い', ['cross']);
  console.log('カウンター型の速攻系', a2, 'ポゼッション型', b2, 'サイド攻撃のクロス', c2, '縦に速いのクロス', d2);
  ok(a2 > b2, '戦い方の型が場面の出方に効く');
  ok(c2 > d2, '幅のつまみがクロスに効く');
}

// 8. 決定的：同じ種なら同じ試合
{
  const x = run(9, 1);
  const y = run(9, 1);
  ok(JSON.stringify(x.scenes.map((s) => [s.type, s.outcome, s.minute])) === JSON.stringify(y.scenes.map((s) => [s.type, s.outcome, s.minute])), '同じ種で同じ試合');
}
// 9. 戦術・役割が結果に効く：戦術に合う能力を高めると得失点差が上がり、役割をでたらめにすると下がる
{
  const gd = (mod, tac) => {
    let g = 0;
    for (let sd = 1; sd <= 200; sd++) {
      const home = YA.makeOurs(1);
      if (tac) home.tactic = Object.assign({ type: tac }, YA.TACTICS[tac]);
      if (mod) mod(home);
      const m = new YA.Match({ seed: sd, home, away: YA.makeOpponent(YA.OPPONENTS[2], sd), settings: { autoStop: false } });
      let n = 0;
      while (!m.finished && n++ < 1000) m.step();
      g += m.score.home - m.score.away;
    }
    return g / 200;
  };
  const rel = (tac) => (h) => { for (const p of Object.values(h.players)) for (const n of YA.TAC_PROFILE[tac].abs) p.ab[n] = Math.min(20, p.ab[n] + 3); };
  const irr = (h) => { for (const p of Object.values(h.players)) for (const n of ['ヘディング', 'ジャンプ', 'バランス', 'プレースキック', 'PK']) p.ab[n] = Math.min(20, p.ab[n] + 3); };
  const a = gd(rel('ポゼッション'), 'ポゼッション');
  const b = gd(irr, 'ポゼッション');
  console.log('戦術に合う能力+3', a.toFixed(2), '無関係な能力+3', b.toFixed(2));
  ok(a > b + 0.2, '戦術に合う能力を上げたほうが強い');
  const base = gd(null);
  const bad = gd((h) => h.lineup.forEach((s, i) => { const pos = YA.pos15OfSlot(s, i); const alt = Object.keys(YA.ROLE_DEF).filter((r) => YA.ROLES15[pos] && YA.ROLES15[pos].indexOf(r) >= 0); if (alt.length) { s.role = alt[(i * 7) % alt.length]; YA.fixSlotRole(s, i); } }));
  console.log('役割 基準', base.toFixed(2), 'でたらめ', bad.toFixed(2));
  ok(bad < base - 0.1, '役割をでたらめにすると弱くなる');
  const home = YA.makeOurs(1);
  const f = YA.tacticFitOf(home, 'ポゼッション');
  ok(typeof f.fit === 'number' && ['◎', '○', '△', '✕'].includes(f.mark) && f.abs.length === 5, '戦術の相性が出る');
}
console.log(fails ? '失敗 ' + fails : 'すべて通過');
process.exit(fails ? 1 : 0);
