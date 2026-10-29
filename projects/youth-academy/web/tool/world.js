// 育成の中身の点検：2〜3年を通して回し、人数・成長・怪我・出来事・卒業と入学・保存が崩れないかを確かめる
'use strict';
const path = require('path');
require(path.join(__dirname, '../src/data.js'));
require(path.join(__dirname, '../src/engine.js'));
require(path.join(__dirname, '../src/world.js'));
require(path.join(__dirname, '../src/league.js'));
require(path.join(__dirname, '../src/club.js'));
require(path.join(__dirname, '../src/scout.js'));
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
  let matches = 0;
  while (w.year === y && guard++ < 200) {
    if (opts.auto !== false) YA.autoPlan(w);
    if (opts.talk) { const p = Object.values(w.players)[w.week % 30]; YA.talk(w, p.id, 'praise'); }
    if (w.week === 26 && opts.camp) w.campChoice = opts.camp;
    // スカウト：候補に声をかける・セレクション・内部昇格
    if (opts.scout && w.scouting) {
      const S = w.scouting;
      for (const c of S.cands.filter((x) => x.kind === 'scout' && x.status === 'open').slice(0, 2)) YA.signCand(w, c.id);
      if (S.selOpen && !S.testsDone) YA.runSelection(w, ['紅白戦', '面接']);
      if (S.selOpen) for (const c of S.cands.filter((x) => x.kind === 'sel' && x.status === 'open').slice(0, 4)) YA.signCand(w, c.id);
      if (S.intOpen) for (const c of S.cands.filter((x) => x.kind === 'int' && x.status === 'open').slice(0, 5)) YA.signCand(w, c.id);
    }
    YA.startWeek(w);
    injuries += w.inbox.filter((n) => n.week === w.week && n.year === w.year && /怪我/.test(n.text)).length;
    for (const e of w.events.slice()) {
      const v = YA.eventView(w, e);
      ok(v && v.text && v.opts.length >= 2, '出来事の表示 ' + e.id);
      const r = YA.resolveEvent(w, e, ((e.pid ? e.pid.length : 3) + w.week) % v.opts.length);
      ok(r && typeof r.line === 'string', '出来事の結果 ' + e.id);
      events++;
    }
    YA.afterEvents(w);
    const mt = YA.matchOf(w);
    ok((w.phase === 'match') === !!mt, '試合の週の判定');
    if (mt) {
      const home = YA.teamFromWorld(w, 'A');
      const opp = YA.opponentOf(w);
      ok(opp && opp.name && opp.lvl > 5, '今週の相手');
      const away = YA.makeOpponent(opp, w.seed + w.week);
      const m = new YA.Match({ seed: w.seed + w.week * 3 + w.year, home, away, settings: { autoStop: false } });
      let g = 0;
      while (!m.finished && g++ < 2000) m.step();
      YA.applyMatch(w, m, 'A', opp, true);
      matches++;
    }
    YA.endWeek(w);
    if (w.pendingContract) YA.renewContract(w);
    check(w);
  }
  const stay = Object.values(w.players).filter((p) => before[p.id] != null);
  const startAvg = stay.reduce((s, p) => s + before[p.id], 0) / stay.length;
  const endAvg = stay.reduce((s, p) => s + YA.abSum(p), 0) / stay.length;
  return { startAvg, endAvg, events, injuries, matches };
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
    ok(w.players[ids[0]].pos === 'GK', lk + ' のGK w' + w.week + ' y' + w.year + ' ' + w.players[ids[0]].pos + ' inj' + w.players[ids[0]].inj + ' away' + w.players[ids[0]].away + ' GKs ' + JSON.stringify(Object.values(w.players).filter((q) => q.pos === 'GK').map((q) => [q.id, q.team, q.grade, q.inj, q.away])));
  }
  ok(JSON.stringify(w).length > 1000 && JSON.parse(JSON.stringify(w)).year === w.year, '保存できる');
}

const w = YA.newWorld(42);
check(w);
const cnt = { 1: 0, 2: 0, 3: 0 };
Object.values(w.players).forEach((p) => cnt[p.grade]++);
ok(cnt[1] === 12 && cnt[2] === 12 && cnt[3] === 12, '各学年12人 ' + JSON.stringify(cnt));
ok(Object.values(w.players).filter((p) => p.team === 'A').length === 20, 'Aは20人');
const a0 = playYear(w, { talk: true, camp: 'domestic', scout: true });
console.log('1年目 能力の合計の平均', a0.startAvg.toFixed(0), '->', a0.endAvg.toFixed(0), '出来事', a0.events, '怪我', a0.injuries);
ok(a0.endAvg > a0.startAvg + 12, '1年で能力が伸びる');
ok(w.year === 2 && w.week === 1, '卒業式で次の年へ');
ok(w.alumni.length >= 12, '卒業生が名鑑へ');
const cnt2 = { 1: 0, 2: 0, 3: 0 };
Object.values(w.players).forEach((p) => cnt2[p.grade]++);
ok(cnt2[1] === 12 && cnt2[3] >= 10, '学年が上がり新しい高1 ' + JSON.stringify(cnt2));
ok(a0.events >= 12, '出来事が起きる ' + a0.events);
ok(w.club.eval.length === 1 && 'SABCD'.includes(w.club.eval[0].letter), '年末の評価 ' + JSON.stringify(w.club.eval[0] && w.club.eval[0].letter));
ok(w.rec.w + w.rec.d + w.rec.l >= 22 && w.rec.w + w.rec.d + w.rec.l <= 29, 'Aの試合は22〜29 ' + (w.rec.w + w.rec.d + w.rec.l));
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
// ---- リーグ・大会・クラブ・スカウト・キャプテン・ポジション・卒業生 ----
{
  const w8 = YA.newWorld(11);
  ok(w8.league && w8.league.teams.length === 12 && w8.league.rounds.length === 22, '12チーム・22節');
  // 総当たり：どのチームも他の11チームと2回ずつ当たる
  const cnt = {};
  for (const rd of w8.league.rounds) for (const [a, b] of rd) { const k = [a, b].sort().join('|'); cnt[k] = (cnt[k] || 0) + 1; }
  ok(Object.keys(cnt).length === 66 && Object.values(cnt).every((n) => n === 2), '総当たりが2回ずつ');
  for (const rd of w8.league.rounds) ok(new Set(rd.flat()).size === 12, '1節に全チームが1回ずつ');
  const a1 = playYear(w8, { scout: true, camp: 'domestic' });
  ok(w8.leagueHist.length === 1, 'リーグの最終順位が残る');
  ok(w8.lastStandings.length === 12 && w8.lastStandings.every((t) => t.w + t.d + t.l === 22), '各チーム22試合 ' + JSON.stringify(w8.lastStandings[0]));
  ok(w8.club.eval.length === 1, '評価が残る');
  ok(Object.values(w8.players).some((p) => p.hist.some((h) => /で入団/.test(h.t))), 'スカウトなどで入団した子がいる');
  ok(w8.alumni.some((a) => a.age >= 18) && w8.alumni.length >= 12, '卒業生が追跡される');
  ok(w8.cup.summer && w8.cup.winter, '大会が毎年作られる');
}
{
  const w9 = YA.newWorld(5);
  // スタッフと信頼度
  w9.club.trust = 20;
  ok(!YA.hire(w9, w9.market[0].id).ok, '信頼度が低いとスタッフは選べない');
  ok(!YA.canAlloc(w9, 'scout'), '信頼度が低いと配分は変えられない');
  w9.club.trust = 80;
  ok(YA.canAlloc(w9, 'facility') && YA.setAlloc(w9, 'scout', 30), '信頼度が高いと配分を変えられる');
  const cand = w9.market.find((c) => c.salary < 300) || w9.market[0];
  const h1 = YA.hire(w9, cand.id);
  ok(h1.ok || /給料/.test(h1.msg), '信頼度が高いと雇える ' + h1.msg);
  const pl = Object.values(w9.players)[3];
  const abName = YA.AB_TECH[0];
  w9.club.staff.find((s) => s.role === '技術コーチ').ab = 18;
  ok(YA.staffMult(w9, pl, abName) > 1.15, '腕のいい技術コーチは伸びを増やす');
  w9.club.staff.find((s) => s.role === '技術コーチ').ab = 4;
  ok(YA.staffMult(w9, pl, abName) < 1, '弱いコーチは伸びを減らす');
  // 目標の交渉：変えられる数は信頼度しだい
  w9.club.trust = 20; YA.makeGoals(w9);
  ok(w9.club.goalChanges === 0 && !YA.changeGoal(w9, 0, 1), '信頼度が低いと目標は変えられない');
  w9.club.trust = 80; YA.makeGoals(w9);
  ok(w9.club.goalChanges === 2 && YA.changeGoal(w9, 1, -1) && YA.changeGoal(w9, 2, 1) && !YA.changeGoal(w9, 0, 1), '信頼度が高いと2つ変えられる');
  // 夏合宿
  w9.club.trust = 80;
  const co = YA.campOptions(w9);
  ok(co.length === 3 && co[0].ok, '合宿の選択肢');
  // キャプテン・副キャプテン
  const ps = Object.values(w9.players);
  const lead = ps.find((p) => p.pers['人との関わり'] === 'リーダー気質') || ps[0];
  YA.setCaptain(w9, lead.id, 'captain');
  YA.setCaptain(w9, ps[1].id, 'vice');
  ok(w9.captain === lead.id && w9.vice === ps[1].id, 'キャプテンを指名できる');
  const t = YA.teamFromWorld(w9, 'A');
  ok(Object.values(t.players).some((p) => p.isCap) || !t.players[lead.id], 'キャプテンの印が試合に渡る');
  // ポジション変更
  const mf = ps.find((p) => p.pos === 'MF');
  let changed = null;
  for (const pos of ['FW', 'DF']) { const r = YA.changePos(w9, mf.id, pos); if (r.ok) { changed = pos; break; } }
  ok(changed ? mf.pos === changed && mf.adapt === 12 : true, 'ポジション変更と慣れる期間');
  // 関係
  ok(w9.rel.filter((x) => x.k === 'friend').length === 8 && w9.rel.filter((x) => x.k === 'rival').length === 6, '関係が作られる');
  // 移籍（解任・契約満了）：36人を一から知る
  YA.moveTo(w9, { tier: 3, name: '大阪 サンライズU-18', budget: 1000 }, 'テスト');
  ok(Object.keys(w9.players).length === 36 && w9.clubName === '大阪 サンライズU-18' && w9.club.tier === 3 && w9.league.level === 3, '新しいクラブで新しい36人');
  check(w9);
  // 古い保存データの移行
  const old = YA.newWorld(21);
  for (const k of ['club', 'coach', 'scouting', 'league', 'cup', 'rel', 'rules']) delete old[k];
  old.v = 1; old.week = 14;
  YA.migrate(old);
  ok(old.club && old.league && old.coach && old.v === 2, '育成だけのデータを移せる');
  const hv = YA.SCHED(14); ok(hv.t === 'league', '14週はリーグ戦');
  YA.startWeek(old); YA.afterEvents(old);
  ok(old.phase === 'match' || old.phase === 'after', '移したあとも週が進む');
}
{
  // 分析と映像ミーティング
  const wA = YA.newWorld(31);
  const opp = YA.opponentOf(wA);
  const oppTeam = YA.makeOpponent(opp, 5);
  wA.club.staff.find((s) => s.role === '分析') ? (wA.club.staff.find((s) => s.role === '分析').ab = 15) : wA.club.staff.push({ role: '分析', ab: 15, salary: 200, name: 'x', id: 'x' });
  const an = YA.analysis(wA, oppTeam, opp);
  ok(an.length >= 6 && an.some((l) => /要注意/.test(l)) && an.some((l) => /おすすめ/.test(l)), '分析担当が良いと深く分かる ' + an.length);
  const m = new YA.Match({ seed: 4, home: YA.teamFromWorld(wA, 'A'), away: oppTeam, settings: { autoStop: false } });
  while (!m.finished) m.step();
  const vo = YA.videoOptions(wA, m);
  ok(vo.length >= 1, '映像の候補');
  const msgs = YA.videoApply(wA, vo.slice(0, 2));
  ok(msgs.length >= 1, '映像ミーティングの反応');
}
console.log(fails ? '失敗 ' + fails : '育成の点検: すべて通過');
process.exit(fails ? 1 : 0);
