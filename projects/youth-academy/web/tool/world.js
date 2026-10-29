// 育成の中身の点検：2〜3年を通して回し、人数・成長・怪我・出来事・卒業と入学・保存が崩れないかを確かめる
'use strict';
const path = require('path');
require(path.join(__dirname, '../src/data.js'));
require(path.join(__dirname, '../src/engine.js'));
require(path.join(__dirname, '../src/world.js'));
const YA = globalThis.YA;
let fails = 0;
const ok = (c, m) => { if (!c) { fails++; console.log('FAIL:', m); } };

function playYear(w, opts) {
  opts = opts || {};
  const all0 = Object.values(w.players);
  const before = {};
  all0.forEach((p) => (before[p.id] = YA.abSum(p)));
  const y = w.year;
  let guard = 0;
  let events = 0;
  let injuries = 0;
  while (w.year === y && guard++ < 200) {
    if (opts.auto !== false) YA.autoPlan(w);
    // 面談
    if (opts.talk) { const p = Object.values(w.players)[w.week % 30]; YA.talk(w, p.id, 'praise'); }
    YA.startWeek(w);
    injuries += w.inbox.filter((n) => n.week === w.week && n.year === w.year && /怪我/.test(n.text)).length;
    for (const e of w.events.slice()) {
      const v = YA.eventView(w, e);
      ok(v && v.text && v.opts.length >= 2, '出来事の表示 ' + e.id);
      const r = YA.resolveEvent(w, e, (e.pid.length + w.week) % v.opts.length);
      ok(r && typeof r.line === 'string', '出来事の結果');
      events++;
    }
    w.events = [];
    if (YA.hasMatch(w.week)) {
      YA.repairLineup(w, 'A');
      const home = YA.teamFromWorld(w, 'A');
      const opp = YA.opponentOf(w);
      const away = YA.makeOpponent(opp, w.seed + w.week);
      const m = new YA.Match({ seed: w.seed + w.week * 3 + w.year, home, away, settings: { autoStop: false } });
      let g = 0;
      while (!m.finished && g++ < 2000) m.step();
      YA.applyMatch(w, m, 'A', opp, true);
    }
    YA.endWeek(w);
    check(w);
  }
  // 同じ年に在籍し続けた選手の、能力の合計の伸び
  const stay = Object.values(w.players).filter((p) => before[p.id] != null);
  const startAvg = stay.reduce((s, p) => s + before[p.id], 0) / stay.length;
  const endAvg = stay.reduce((s, p) => s + YA.abSum(p), 0) / stay.length;
  return { startAvg, endAvg, events, injuries };
}
function check(w) {
  const ps = Object.values(w.players);
  ok(ps.length >= 34 && ps.length <= 40, '人数 ' + ps.length);
  const nums = ps.map((p) => p.num);
  ok(new Set(nums).size === nums.length, '背番号が重ならない');
  for (const p of ps) {
    const list = p.pos === 'GK' ? YA.AB_GK.concat(YA.AB_MENTAL, YA.AB_PHYS) : YA.AB_FIELD;
    for (const n of list) if (!(p.ab[n] >= 1 && p.ab[n] <= 20)) { ok(false, '能力の範囲 ' + p.name + n + p.ab[n]); break; }
    ok(p.fat >= 0 && p.fat <= 100 && p.conf >= 0 && p.conf <= 100, '疲れ・自信の範囲');
    ok(p.traits.length <= 5, '特性は5つまで');
  }
  for (const [lk, bk] of [['lineupA', 'benchA'], ['lineupB', 'benchB']]) {
    const ids = w[lk].map((s) => s.pid);
    ok(ids.length === 11 && new Set(ids).size === 11 && ids.every((id) => w.players[id]), lk + ' の11人');
    ok(w[bk].every((id) => w.players[id]) && !w[bk].some((id) => ids.includes(id)), bk + ' が正しい');
    ok(w.players[ids[0]].pos === 'GK', lk + ' のGK');
  }
  ok(JSON.stringify(w).length > 1000 && JSON.parse(JSON.stringify(w)).year === w.year, '保存できる');
}

const w = YA.newWorld(42);
check(w);
const cnt = { 1: 0, 2: 0, 3: 0 };
Object.values(w.players).forEach((p) => cnt[p.grade]++);
ok(cnt[1] === 12 && cnt[2] === 12 && cnt[3] === 12, '各学年12人 ' + JSON.stringify(cnt));
ok(Object.values(w.players).filter((p) => p.team === 'A').length === 20, 'Aは20人');
const a0 = playYear(w, { talk: true });
console.log('1年目 能力の合計の平均', a0.startAvg.toFixed(0), '->', a0.endAvg.toFixed(0), '出来事', a0.events, '怪我', a0.injuries);
ok(a0.endAvg > a0.startAvg + 12, '1年で能力が伸びる');
ok(w.year === 2 && w.week === 1, '卒業式で次の年へ');
ok(w.alumni.length >= 12, '卒業生が名鑑へ');
const cnt2 = { 1: 0, 2: 0, 3: 0 };
Object.values(w.players).forEach((p) => cnt2[p.grade]++);
ok(cnt2[1] === 12 && cnt2[3] >= 10, '学年が上がり新しい高1 ' + JSON.stringify(cnt2));
ok(a0.events >= 12, '出来事が起きる ' + a0.events);
ok(w.rec.w + w.rec.d + w.rec.l === 30, 'Aの試合は30');
const a1 = playYear(w, {});
console.log('2年目', a1.startAvg.toFixed(0), '->', a1.endAvg.toFixed(0));
const a2 = playYear(w, {});
ok(w.year === 4, '3年通せる');
// 上限（伸びしろ）を超えない
for (const p of Object.values(w.players)) ok(YA.abSum(p) <= p.pot + 6, '伸びしろを大きく超えない ' + p.name);
// 特性練習で習得できる
{
  const w2 = YA.newWorld(7);
  const p = Object.values(w2.players).find((q) => q.pos === 'MF');
  const t = YA.learnable(p)[0];
  p.train.trait = t.t;
  let learned = false;
  console.log('rate', p.rate, p.grade, p.pos); for (let i = 0; i < 40 && !learned; i++) { YA.autoPlan(w2); p.train.trait = t.t; YA.startWeek(w2); w2.events = []; YA.endWeek(w2); if (p.traits.includes(t.t)) learned = true; if (w2.year > 1) break; }
  console.log('特性練習', t.t, '予想', t.weeks, '週', learned ? '習得' : '未習得');
  ok(learned || t.weeks > 38, '特性練習で習得できる');
}
// 練習の重点が効く
{
  const gainOf = (focus) => {
    const w3 = YA.newWorld(9);
    const p = Object.values(w3.players).find((q) => q.pos === 'FW' && q.grade === 1);
    const before = p.ab['フィニッシュ'] + (p.prog['フィニッシュ'] || 0);
    for (let i = 0; i < 20; i++) { YA.autoPlan(w3); p.train.focus = focus; p.rest = null; p.fat = 20; YA.startWeek(w3); w3.events = []; YA.endWeek(w3); }
    return p.ab['フィニッシュ'] + (p.prog['フィニッシュ'] || 0) - before;
  };
  const a = gainOf('フィニッシュ'), b = gainOf('タックル');
  console.log('フィニッシュの伸び 重点あり', a.toFixed(2), 'なし', b.toFixed(2));
  ok(a > b, '重点にした能力が伸びやすい');
}
// 休ませると疲れが減る・きつい練習は疲れる
{
  const w4 = YA.newWorld(3);
  const p = Object.values(w4.players)[5];
  p.fat = 60; p.rest = 'rest';
  YA.startWeek(w4);
  ok(p.fat < 60, '休むと疲れが抜ける');
  const w5 = YA.newWorld(3);
  const q = Object.values(w5.players)[5];
  q.fat = 10; q.rest = null; w5.plan = { days: Array(5).fill({ menu: 'フィジカル', int: 'hard' }) };
  YA.startWeek(w5);
  const w7 = YA.newWorld(3);
  const q2 = Object.values(w7.players)[5];
  q2.fat = 10; q2.rest = null; w7.plan = { days: Array(5).fill({ menu: 'フィジカル', int: 'light' }) };
  YA.startWeek(w7);
  ok(q.fat > q2.fat + 8, 'きつい練習は軽めより疲れる ' + q.fat + ' vs ' + q2.fat);
}
// 面談：週1回・性格で反応が違う
{
  const w6 = YA.newWorld(5);
  const ps = Object.values(w6.players);
  const sen = ps.find((p) => p.pers['気持ちの強さ'] === '繊細');
  const ban = ps.find((p) => p.pers['教えの受け止め方'] === '反骨心');
  if (sen && ban) {
    sen.conf = 50; ban.conf = 50;
    YA.talk(w6, sen.id, 'issue'); YA.talk(w6, ban.id, 'issue');
    ok(sen.conf < 50 && ban.conf > 50, '厳しい言葉：繊細は落ち込み、反骨心は奮起');
    ok(!YA.talk(w6, sen.id, 'praise').ok, '同じ週に2回は話せない');
  }
}
console.log(fails ? '失敗 ' + fails : '育成の点検: すべて通過');
process.exit(fails ? 1 : 0);
