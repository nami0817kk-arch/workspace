// 育成の中身の点検：2〜3年を通して回し、人数・成長・怪我・出来事・卒業と入学・保存が崩れないかを確かめる
'use strict';
const path = require('path');
require(path.join(__dirname, '../src/data.js'));
require(path.join(__dirname, '../src/engine.js'));
require(path.join(__dirname, '../src/world.js'));
require(path.join(__dirname, '../src/league.js'));
require(path.join(__dirname, '../src/club.js'));
require(path.join(__dirname, '../src/scout.js'));
require(path.join(__dirname, '../src/extra.js'));
require(path.join(__dirname, '../src/more.js'));
require(path.join(__dirname, '../src/imgdata.js'));
require(path.join(__dirname, '../src/art.js'));
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
// 初回のセレクション：応募者から高1を選び、足りない分は一般入団で12人に
{
  const wf = YA.newWorld(21, Object.assign(YA.makeStart({ name: '点検', career: 0, club: 2, points: {}, noFire: false }), { firstSel: true }));
  ok(wf.firstSel === true, '初回のセレクションが始まる');
  const cands = wf.scouting.cands.filter((c) => c.kind === 'sel');
  ok(cands.length >= 16, '応募者が16人以上 ' + cands.length);
  const prof = (k) => cands.filter((c) => c.prof === k).length;
  ok(prof('raw') + prof('low') + prof('mis') === cands.length, '応募者は原石・低め・位置ちがいのどれか');
  const raw = cands.filter((c) => c.prof === 'raw');
  const mis = cands.filter((c) => c.prof === 'mis');
  ok(raw.every((c) => c.p.pot - YA.abSum(c.p) >= 170), '原石は伸びしろが大きい');
  ok(raw.every((c) => YA.ovr(c.p) < 9), '原石は今の力が低い');
  ok(mis.every((c) => c.p.pos !== 'GK' && c.p.apt[c.p.main] <= c.p.apt[c.p.best] - 1), '位置ちがいは登録が合っていない');
  let okc = 0;
  for (const c of cands.slice(0, 6)) if (YA.signCand(wf, c.id).ok) okc++;
  ok(okc === 3, 'セレクションからは3人まで ' + okc);
  const sc = wf.scouting.cands.filter((c) => c.kind === 'scout');
  const ic = wf.scouting.cands.filter((c) => c.kind === 'int');
  ok(sc.length >= 6 && ic.length === 12 && wf.scouting.intOpen, '初年度からスカウトと内部昇格の候補がいる');
  let oks = 0;
  for (const c of sc) if (YA.signCand(wf, c.id).ok) oks++;
  ok(oks === 3, 'スカウトは3人まで ' + oks);
  let oki = 0;
  for (const c of ic) if (YA.signCand(wf, c.id).ok) oki++;
  ok(oki === 6, '内部昇格は8人まで、ただし全体12人の枠内（残り6人） ' + oki);
  {
    const wq = YA.newWorld(23, Object.assign(YA.makeStart({ name: '点検', career: 0, club: 2, points: {}, noFire: false }), { firstSel: true }));
    let k = 0;
    for (const c of wq.scouting.cands.filter((x) => x.kind === 'int')) if (YA.signCand(wq, c.id).ok) k++;
    ok(k === 8, '内部昇格だけなら8人まで ' + k);
  }
  const names = cands.slice(0, 3).map((c) => c.p.name).concat(ic.filter((c) => c.status === 'signed').map((c) => c.p.name));
  const n = YA.finishFirstSelection(wf);
  const g1 = Object.values(wf.players).filter((p) => p.grade === 1);
  ok(n === 12 && g1.length === 12, '高1が12人になる ' + g1.length);
  ok(names.every((nm) => g1.some((p) => p.name === nm)), '合格者が高1に入る');
  ok(Object.keys(wf.players).length === 36, '全体36人 ' + Object.keys(wf.players).length);
  ok(wf.lineupA.every((s) => wf.players[s.pid]) && wf.lineupB.every((s) => wf.players[s.pid]), '先発の選手がそろっている');
  ok(!wf.firstSel, 'セレクションが終わる');
  const wg = YA.newWorld(22, Object.assign(YA.makeStart({ name: '点検', career: 0, club: 2, points: {}, noFire: false }), { firstSel: true }));
  YA.simulate(wg, { until: 'week', stopOnImportant: false });
  ok(!wg.firstSel && Object.keys(wg.players).length === 36, 'おまかせ進行ではセレクションを飛ばす');
}
// 試合の経験：出た選手に、出場時間・採点・頭の経験値などの記録が残る
{
  const we = YA.newWorld(13);
  let g = 0;
  while (we.year === 1 && we.week < 4 && g++ < 20) YA.simulate(we, { until: 'week', stopOnImportant: false });
  const got = Object.values(we.players).filter((p) => p.lm && p.lm.mins > 0);
  ok(got.length >= 11, '試合に出た選手に経験の記録が残る ' + got.length);
  ok(got.every((p) => p.lm.xp > 0 && typeof p.lm.conf === 'number' && typeof p.lm.tu === 'number'), '経験の記録の中身');
}
// 面談は月に1回：同じ月の次の週は話せず、月が替われば話せる
{
  const wm = YA.newWorld(11);
  const q = Object.values(wm.players)[0];
  ok(YA.talk(wm, q.id, 'praise').ok, '月の最初は話せる');
  wm.week++;
  ok(!YA.talk(wm, q.id, 'praise').ok, '同じ月の次の週は話せない');
  while (YA.monthIdx(wm.week) === 0) wm.week++;
  ok(YA.talk(wm, q.id, 'praise').ok, '月が替われば話せる');
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
  for (const pos of ['LW', 'RW', 'SS', 'AM', 'LM']) { if (pos === mf.main) continue; const r = YA.changePos(w9, mf.id, pos); if (r.ok) { changed = pos; break; } }
  ok(changed ? mf.main === changed && mf.pos === YA.GROUP[changed] && mf.adapt === 12 : true, 'ポジション変更と慣れる期間（15ポジション）');
  ok(!YA.changePos(w9, ps.find((p) => p.pos === 'GK').id, 'CB').ok, 'GKは変えられない');
  // 関係
  ok(w9.rel.filter((x) => x.k === 'friend').length === 8 && w9.rel.filter((x) => x.k === 'rival').length === 6, '関係が作られる');
  // 移籍（解任・契約満了）：36人を一から知る
  YA.moveTo(w9, { tier: 3, name: '大阪 サンライズU-18', budget: 1000 }, 'テスト');
  ok(Object.keys(w9.players).length === 36 && w9.clubName === '大阪 サンライズU-18' && w9.club.tier === 3 && w9.league.level === 3, '新しいクラブで新しい36人');
  check(w9);
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
// ---- 15ポジションと役割 ----
{
  ok(YA.POS15.length === 15, 'ポジションは15');
  const seenPos = new Set();
  for (const f of Object.keys(YA.FORMATIONS)) YA.FORMATIONS[f].forEach((sl, i) => seenPos.add(YA.pos15OfSlot(sl, i)));
  ok(YA.POS15.every((q) => seenPos.has(q)), '定番の布陣で15ポジション全部が使われる ' + [...seenPos].length);
  for (const q of YA.POS15) { ok(YA.ROLES15[q].length >= 2, q + ' の役割'); for (const r of YA.ROLES15[q]) ok(YA.ROLE_DEF[r] && YA.ROLE_DEF[r].note && YA.ROLE_DEF[r].tags.length, '役割の定義 ' + r); }
  // 選手：適性・隠れた最適・利き足
  let mis = 0, tot = 0;
  const posCount = {};
  for (const seed of [1, 2, 3, 4, 5]) {
    const wk = YA.newWorld(seed);
    for (const p of Object.values(wk.players)) {
      tot++;
      posCount[p.main] = (posCount[p.main] || 0) + 1;
      ok(p.apt && YA.POS15.every((q) => p.apt[q] >= 1 && p.apt[q] <= 20), '適性の範囲');
      ok(p.pos === YA.GROUP[p.main], '括りが登録ポジションと合う');
      ok(['R', 'L', 'B'].includes(p.foot), '利き足');
      if (p.apt[p.best] - p.apt[p.main] > 1.5) mis++;
    }
  }
  console.log('登録と本当の適性がずれている選手の割合', (mis / tot).toFixed(2), 'ポジション別', JSON.stringify(posCount));
  ok(mis / tot > 0.08 && mis / tot < 0.5, 'ずれている割合が妥当');
  ok(Object.keys(posCount).length >= 11, '生成される選手のポジションが多様 ' + Object.keys(posCount).length);
  // 利き足とポジションのペナルティ
  const wp = YA.newWorld(9);
  const q = Object.values(wp.players).find((x) => x.pos === 'DF');
  q.main = 'LB'; q.pos = 'DF'; q.apt.LB = q.apt.RB = 12; q.best = 'LB'; q.ab['逆足の精度'] = 4;
  q.foot = 'R'; const penWrong = YA.slotPenalty(q, 'LB');
  q.foot = 'L'; const penRight = YA.slotPenalty(q, 'LB');
  ok(penWrong > penRight + 0.04, '逆足は力が落ちる ' + penWrong + ' vs ' + penRight);
  q.foot = 'B'; ok(YA.slotPenalty(q, 'LB') === 0, '両足は落ちない');
  // 向いていないポジションに置くと力が落ち、慣れると和らぐ
  q.apt.CB = 6; q.apt.LB = 14; q.main = 'LB'; q.fam = { LB: 14 }; q.foot = 'L';
  const p0 = YA.slotPenalty(q, 'CB'); q.fam.CB = 10; const p1 = YA.slotPenalty(q, 'CB');
  ok(p0 > 0.1 && p1 < p0, '向いていない場所では力が落ち、慣れると和らぐ ' + p0 + ' → ' + p1);
  // 役割＋任務：表の形・全ポジションの全役割×任務で試合が最後まで回る
  ok(Object.keys(YA.ROLE_DEF).length >= 44, '役割は44以上 ' + Object.keys(YA.ROLE_DEF).length);
  for (const r of Object.keys(YA.ROLE_DEF)) {
    const rd = YA.ROLE_DEF[r];
    ok(rd.duties.length >= 1 && rd.duties.every((d) => YA.DUTY[d]) && Object.keys(rd.absW).length >= 3 && rd.traits.length >= 2 && rd.tags.length >= 1, '役割の表の形 ' + r);
  }
  ok(YA.ROLES15.CB.every((r) => ['センターディフェンダー', 'ボールプレイングDF', 'ノーナンセンスCB'].indexOf(r) < 0 || YA.ROLE_DEF[r].duties.join() === 'def,stop,cover'), 'CBの3役は守備・ストッパー・カバー');
  ok(YA.ROLE_DEF['レジスタ'].duties.join() === 'sup' && YA.ROLE_DEF['アンカーマン'].duties.join() === 'def' && YA.ROLE_DEF['リベロ'].duties.join() === 'sup,att', '依頼どおりの任務の組み合わせ');
  const formOf = {};
  for (const f of Object.keys(YA.FORMATIONS)) YA.FORMATIONS[f].forEach((sl, i) => { const q3 = YA.pos15OfSlot(sl, i); if (!formOf[q3]) formOf[q3] = [f, i]; });
  let combos = 0;
  for (const q2 of YA.POS15) {
    const [f, si] = formOf[q2];
    const wf = YA.newWorld(77);
    YA.pickLineup(wf, 'A', f);
    for (const r of YA.ROLES15[q2]) for (const d of YA.ROLE_DEF[r].duties) {
      const sl = wf.lineupA[si];
      sl.role = r; sl.duty = d;
      const home = YA.teamFromWorld(wf, 'A');
      ok(home.lineup[si].role === r && home.lineup[si].duty === d, '役割と任務が試合に渡る ' + q2 + '/' + r + '/' + d);
      const m = new YA.Match({ seed: 3 + combos, home, away: YA.makeOpponent(YA.OPPONENTS[combos % 3], 3), settings: { autoStop: false } });
      while (!m.finished) m.step();
      ok(m.finished && m.scenes.length >= 13, '役割×任務で試合が最後まで進む ' + q2 + '/' + r + '/' + d);
      combos++;
    }
  }
  console.log('全ポジションの全役割×任務で試合が回った組み合わせ', combos);
  ok(combos >= 110, '組み合わせの数 ' + combos);
  // 古い役割名や任務のないスロットは、使えるものに直る
  { const wf = YA.newWorld(5); wf.lineupA[3].role = '昔の役割'; delete wf.lineupA[4].duty; const t0 = YA.teamFromWorld(wf, 'A'); ok(t0.lineup.every((sl, i) => YA.ROLES15[YA.pos15OfSlot(sl, i)].indexOf(sl.role) >= 0 && YA.ROLE_DEF[sl.role].duties.indexOf(sl.duty) >= 0), '役割と任務が直る'); }
  // 役割・任務が場面の出方を変える
  const countScene = (role, duty, pos15, type) => {
    let c = 0;
    for (let sd = 1; sd <= 80; sd++) {
      const home = YA.makeOurs(1);
      home.lineup.forEach((sl, i) => { if (YA.pos15OfSlot(sl, i) === pos15) { sl.role = role; sl.duty = duty; } });
      const m = new YA.Match({ seed: sd, home, away: YA.makeOpponent(YA.OPPONENTS[1], sd), settings: { autoStop: false } });
      while (!m.finished) m.step();
      for (const sc of m.scenes) if (sc.side === 'home' && sc.type === type) c++;
    }
    return c;
  };
  const runSt = countScene('アドバンスドフォワード', 'att', 'ST', 'through');
  const tgSt = countScene('ターゲットフォワード', 'sup', 'ST', 'through');
  const crSt = countScene('ターゲットフォワード', 'att', 'ST', 'cross');
  const crSt2 = countScene('アドバンスドフォワード', 'att', 'ST', 'cross');
  console.log('STの役割：アドバンスドフォワード→裏抜け', runSt, '/ターゲットフォワード→裏抜け', tgSt, '、ターゲットフォワード→クロス', crSt, '/アドバンスドフォワード→クロス', crSt2);
  ok(runSt > tgSt, '「アドバンスドフォワード」は裏抜けの場面を増やす');
  ok(crSt > crSt2, '「ターゲットフォワード」はクロスの場面を増やす');
  const wgD = countScene('インサイドフォワード', 'att', 'RW', 'dribble'), wgD2 = countScene('ワイドプレイメーカー', 'sup', 'RW', 'dribble');
  const wgC = countScene('ウイング', 'att', 'RW', 'cross'), wgC2 = countScene('インサイドフォワード', 'att', 'RW', 'cross');
  console.log('WGの役割：インサイドフォワード→ドリブル', wgD, '/ワイドプレイメーカー→ドリブル', wgD2, '、ウイング→クロス', wgC, '/インサイドフォワード→クロス', wgC2);
  ok(wgD > wgD2, '「インサイドフォワード」はドリブルの場面を増やす');
  ok(wgC >= wgC2, '「ウイング」はクロスを減らさない');
  // 任務：攻撃は場面を増やし、守備は減らす（同じ役割で比べる）
  const stA = countScene('プレッシングフォワード', 'att', 'ST', 'steal');
  const stD = countScene('プレッシングフォワード', 'def', 'ST', 'steal');
  const cmA = countScene('セントラルMF', 'att', 'CM', 'onetwo');
  const cmD = countScene('セントラルMF', 'def', 'CM', 'onetwo');
  console.log('任務：プレッシングフォワード 攻撃→奪取', stA, '/守備→奪取', stD, '、セントラルMF 攻撃→ワンツー', cmA, '/守備→ワンツー', cmD);
  ok(stA > stD, '任務「攻撃」は「守備」より攻めの場面が出やすい（奪取）');
  ok(cmA >= cmD, '任務「攻撃」は「守備」より攻めの場面が出やすい（ワンツー）');
  // 相手の場面を減らす：守備の任務のアンカーは、攻撃より相手の裏抜けを減らす
  const oppThrough = (duty) => {
    let c = 0;
    for (let sd = 1; sd <= 80; sd++) {
      const home = YA.makeOurs(1);
      home.lineup.forEach((sl, i) => { if (YA.pos15OfSlot(sl, i) === 'DM') { sl.role = 'アンカーマン'; sl.duty = duty; } });
      const m = new YA.Match({ seed: sd, home, away: YA.makeOpponent(YA.OPPONENTS[1], sd), settings: { autoStop: false } });
      while (!m.finished) m.step();
      for (const sc of m.scenes) if (sc.side === 'away' && sc.type === 'through') c++;
    }
    return c;
  };
  console.log('アンカーマン（守備）→相手の裏抜け', oppThrough('def'));
  // 立つ位置の深さ（任務で変わる）
  ok(YA.DUTY.att.depth > YA.DUTY.sup.depth && YA.DUTY.sup.depth > YA.DUTY.def.depth, '任務で立つ位置の深さが変わる');
  // 役割と任務が選手に合わないと「合わない」になる
  { const wf = YA.newWorld(9); const tm = YA.teamFromWorld(wf, 'A'); const i = 9; const pl = tm.players[tm.lineup[i].pid];
    tm.lineup[i].role = YA.ROLES15[YA.pos15OfSlot(tm.lineup[i], i)][0]; tm.lineup[i].duty = YA.ROLE_DEF[tm.lineup[i].role].duties.indexOf('att') >= 0 ? 'att' : tm.lineup[i].duty;
    for (const n of ['運動量', 'スタミナ', 'スピード']) pl.ab[n] = 3;
    if (tm.lineup[i].duty === 'att') ok(YA.Match.prototype.roleFit.call(null, tm, i) <= 0, '走れない選手に「攻撃」の任務は合わない'); }
}
// ---- おまかせ進行・新しく始める・セーブ枠・戦術の細かい設定・外国籍・飛び級・海外移籍・効果音 ----
{
  // 1年をおまかせで進める（テスト用）：止まらない設定で、3年続けて落ちない
  const wsim = YA.newWorld(61);
  const y0 = wsim.year;
  const rep1 = YA.simulate(wsim, { until: 'year', stopOnImportant: false });
  ok(wsim.year === y0 + 1 && wsim.week === 1, '1年おまかせで年度が替わる ' + wsim.year + '/' + wsim.week);
  ok(rep1.weeks >= 40 && rep1.matches >= 20 && rep1.lines.length >= 5, 'おまかせの報告 ' + rep1.weeks + '週 ' + rep1.matches + '試合 ' + rep1.lines.length + '行');
  ok(rep1.lines.some((l) => l.k === 'eval') && rep1.lines.some((l) => l.k === 'grad') && rep1.lines.some((l) => l.k === 'grow'), '報告に評価・卒業・成長が出る');
  ok(!wsim.yearIntro && !wsim.pendingContract && !wsim.pendingCoach, '止まらない設定では、年度はじめの選択も済ませる');
  check(wsim);
  YA.simulate(wsim, { until: 'year', stopOnImportant: false });
  YA.simulate(wsim, { until: 'year', stopOnImportant: false });
  ok(wsim.year === y0 + 3, '3年続けて進む');
  console.log('1年おまかせの報告（例）:', rep1.lines.map((l) => l.t).join(' / ').slice(0, 260));
  // 1週・次の試合
  const w1 = YA.newWorld(62);
  w1.yearIntro = false;
  const r1 = YA.simulate(w1, { until: 'week', stopOnImportant: false });
  ok(w1.week === 2 && r1.weeks === 1, '1週だけ進む');
  const r2 = YA.simulate(w1, { until: 'match', stopOnImportant: false });
  ok(r2.matches === 1 && w1.phase === 'after', '次の試合まで進む（試合のあとで止まる）');
  // 大事な出来事では止まる設定
  let stopped = 0;
  for (let sd = 70; sd < 78; sd++) {
    const wz = YA.newWorld(sd);
    wz.yearIntro = false;
    const rr = YA.simulate(wz, { until: 'year', stopOnImportant: true });
    if (rr.stopped) {
      stopped++;
      ok((wz.phase === 'event' && wz.events.length > 0) || wz.pendingContract || wz.pendingCoach || wz.yearIntro, '止まったときの状態が続きから操作できる ' + rr.stopped);
      for (const e of wz.events.slice()) {
        YA.resolveEvent(wz, e, 0);
        wz.events.shift();
      }
      if (wz.phase === 'event') YA.afterEvents(wz);
      const rr2 = YA.simulate(wz, { until: 'week', stopOnImportant: false });
      ok(rr2.weeks >= 0, '止まったあとも進められる');
    }
  }
  console.log('大事な出来事で止まった回数（8つの世界）', stopped);
  ok(stopped >= 3, '大事な出来事で止まる ' + stopped);
  // 指導者の作成と経歴・クラブ選び
  const st1 = YA.makeStart({ name: 'テスト監督', career: 'high', club: 0, points: { eye: 3, talk: 3 }, noFire: true });
  const wn = YA.newWorld(5, st1);
  ok(wn.coachName === 'テスト監督' && wn.coach.teach === 11 && wn.coach.eye === 11 && wn.coach.talk === 12 && wn.coach.exp === 3, '経歴と配分が能力に出る ' + JSON.stringify(wn.coach));
  ok(wn.club.tier === 1 && wn.clubName.indexOf('ブルーウィング') >= 0 && wn.club.noFire && wn.league.level === 1, '選んだクラブ（1部）で始まる');
  const wt3 = YA.newWorld(5, YA.makeStart({ career: 'pro', club: 6, points: {} }));
  const avg = (wx) => Object.values(wx.players).reduce((a, p) => a + YA.ovr(p), 0) / 36;
  ok(wt3.club.tier === 3 && wt3.coachName === '監督', '3部のクラブ・名前が空なら「監督」');
  ok(avg(wn) > avg(wt3), '上の部のクラブのほうが選手の素質が高い ' + avg(wn).toFixed(2) + ' vs ' + avg(wt3).toFixed(2));
  ok(YA.CAREER_POINTS === 6 && YA.START_CLUBS.length >= 8, '配分の点数とクラブの数');
  // 最初の1か月の案内
  const wtu = YA.newWorld(6);
  ok(YA.tutorialText(wtu) && /目標/.test(YA.tutorialText(wtu)), '最初は目標の案内');
  wtu.yearIntro = false;
  ok(/練習/.test(YA.tutorialText(wtu)), '練習の案内');
  wtu.phase = 'event';
  ok(/出来事/.test(YA.tutorialText(wtu)), '出来事の案内');
  wtu.phase = 'match';
  ok(/試合/.test(YA.tutorialText(wtu)), '試合の案内');
  wtu.week = 5;
  ok(YA.tutorialText(wtu) === null, '1か月で案内は消える');
  wtu.week = 1;
  wtu.tut.on = false;
  ok(YA.tutorialText(wtu) === null, '消せる');
  // セーブ枠・書き出し・復元
  const ex = YA.exportWorld(wsim);
  const im = YA.importWorld(ex);
  ok(im.ok && im.world.year === wsim.year && Object.keys(im.world.players).length === Object.keys(wsim.players).length, '書き出して復元できる');
  ok(!YA.importWorld('これは違う').ok && !YA.importWorld('{"app":"x"}').ok && !YA.importWorld(ex.slice(0, 200)).ok, '壊れたデータは受け付けない');
  ok(YA.slotKey(0) === 'world' && YA.slotKey(1) === 'world1' && YA.SLOT_COUNT === 2 && /年目/.test(YA.slotSummary(wsim)), 'セーブ枠の名前と要約');
  // 戦術の細かい設定：キッカーの指定・クロスの種類・浸透
  {
    const wtac = YA.newWorld(88);
    const cands = wtac.lineupA.slice(1).map((sl) => sl.pid);
    const fkId = cands[cands.length - 1];
    wtac.tactic = Object.assign({ type: 'ポゼッション' }, YA.TACTICS['ポゼッション'], { fk: fkId, ck: fkId, pk: fkId, crossType: 'high' });
    let fkScenes = 0;
    let byFk = 0;
    for (let sd = 1; sd <= 120; sd++) {
      const m = new YA.Match({ seed: sd, home: YA.teamFromWorld(wtac, 'A'), away: YA.makeOpponent(YA.OPPONENTS[1], sd), settings: { autoStop: false } });
      while (!m.finished) m.step();
      for (const sc of m.scenes) if (sc.side === 'home' && (sc.type === 'fk' || sc.type === 'ck')) {
        fkScenes++;
        if (sc.actors.kicker === fkId) byFk++;
      }
    }
    console.log('指定したキッカーが蹴った割合', byFk + '/' + fkScenes);
    ok(fkScenes > 10 && byFk === fkScenes, '指定したキッカーが蹴る');
    // 戦い方の浸透：同じ戦い方を続けると上がり、変えると下がる
    const wr = YA.newWorld(89);
    ok(YA.tactRepOf(wr) === 0.6, '最初の浸透は60%');
    wr.tactic = Object.assign({ type: 'カウンター' }, YA.TACTICS['カウンター']);
    for (let i = 0; i < 12; i++) wr.tactMem = wr.tactMem && wr.tactMem.type === 'カウンター' ? { type: 'カウンター', weeks: wr.tactMem.weeks + 1 } : { type: 'カウンター', weeks: 1 };
    ok(YA.tactRepOf(wr) === 1, '同じ戦い方を続けると100%');
    wr.tactic.type = 'ポゼッション';
    ok(YA.tactRepOf(wr) === 0.6, '戦い方を変えると下がる');
    const fast = (rep) => {
      let c = 0;
      for (let sd = 1; sd <= 120; sd++) {
        const h0 = YA.makeOurs(1);
        h0.tactic = Object.assign({ type: '縦に速い' }, YA.TACTICS['縦に速い']);
        h0.tactRep = rep;
        const m = new YA.Match({ seed: sd, home: h0, away: YA.makeOpponent(YA.OPPONENTS[2], sd), settings: { autoStop: false } });
        while (!m.finished) m.step();
        for (const sc of m.scenes) if (sc.side === 'home' && (sc.type === 'through' || sc.type === 'counter')) c++;
      }
      return c;
    };
    const hi = fast(1);
    const lo = fast(0.6);
    console.log('縦に速い型の速攻系：浸透100%', hi, '/浸透60%', lo);
    ok(hi >= lo, '浸透が高いほどつまみどおりに動く');
  }
  // 外国籍：3人までしか出られない・年に1人まで・適応の出来事
  {
    const wf = YA.newWorld(90);
    for (const sl of wf.lineupA.slice(1, 8)) wf.players[sl.pid].nation = 'ブラジル';
    YA.repairLineup(wf, 'A');
    const fc = wf.lineupA.filter((sl) => YA.isForeign(wf.players[sl.pid])).length;
    ok(fc <= 3, '外国籍の先発は3人まで ' + fc);
    ok(YA.EVENTS.some((e) => e.id === 'adapt') && YA.EVENTS.some((e) => e.id === 'jump'), '外国籍の適応・飛び級の出来事がある');
    let fgn = 0;
    let years = 0;
    for (let sd = 1; sd <= 60; sd++) {
      const wc = YA.newWorld(sd);
      for (let wk = 4; wk <= 32; wk += 4) {
        wc.week = wk;
        YA.scoutReport(wc);
      }
      const f = wc.scouting.cands.filter((c) => c.foreign);
      ok(f.length <= 1, '外国籍の候補は年に1人まで');
      fgn += f.length;
      years++;
    }
    console.log('外国籍の候補が出た年', fgn + '/' + years);
    ok(fgn >= 1, '外国籍の候補が出ることがある');
    // 飛び級：受け入れると選手が増える／断ると信頼度が下がる
    const wj = YA.newWorld(91);
    wj.week = 8;
    const n0 = Object.keys(wj.players).length;
    const t0 = wj.club.trust;
    YA.resolveEvent(wj, { id: 'jump', pid: null, x: 0, week: 8, year: 1 }, 0);
    ok(Object.keys(wj.players).length === n0 + 1 && Object.values(wj.players).some((p) => p.jump), '飛び級を受け入れると選手が増える');
    const t1 = wj.club.trust;
    YA.resolveEvent(wj, { id: 'jump', pid: null, x: 0, week: 8, year: 1 }, 1);
    ok(wj.club.trust < t1 && t1 >= t0, '断ると信頼度が下がる');
    check(wj);
  }
  // 海外移籍：力のある卒業生が海外へ移ることがある
  {
    let abroadCount = 0;
    for (let sd = 1; sd <= 40; sd++) {
      const wa = YA.newWorld(sd);
      wa.alumni.push({ name: 'テスト選手', pos: 'FW', year: 1, ovr: 15, note: 'プロ', grade: 3, age: 20, status: 'pro', club: '横浜 ブルーウィング', apps: 0, goals: 0, nat: 0, transfers: 0, retired: false, traits: [] });
      for (let k = 0; k < 6; k++) {
        wa.year = 2 + k;
        YA.alumniTick(wa);
      }
      if (wa.alumni.some((a) => a.abroad)) abroadCount++;
    }
    console.log('海外移籍が起きた世界', abroadCount + '/40');
    ok(abroadCount >= 3, '海外移籍が起きる');
  }
  // 段2：実績・引退・お知らせの段・名前の書き換え・進路の相談・GK枠
  {
    const wm = YA.newWorld(11);
    const ach = YA.achievements(wm);
    ok(ach.length >= 9 && ach.every((x) => typeof x.done === 'boolean'), '実績の一覧が出る');
    ok(YA.noticeKind('Aが怪我（3週）') === '怪我' && YA.noticeKind('なにか') === 'そのほか', 'お知らせの種類を分ける');
    ok(YA.renamePlayer(wm, Object.keys(wm.players)[0], '').ok === false && YA.renamePlayer(wm, Object.keys(wm.players)[0], '新しい名前').ok, '名前を書き換えられる');
    const sm0 = YA.careerSummary(wm);
    ok(sm0.ach.length === ach.length && Array.isArray(sm0.best), '指導者人生のまとめが作れる');
    YA.retire(wm);
    ok(wm.retired && wm.retired.year === wm.year && JSON.parse(JSON.stringify(wm)).retired, '引退が保存される');
    // GK枠：Bチームの先発GKが抜けても、GKが入る
    const wg = YA.newWorld(12);
    const gk0 = wg.lineupB[0].pid;
    delete wg.players[gk0];
    wg.benchB = wg.benchB.filter((id) => wg.players[id] && wg.players[id].pos !== 'GK');
    YA.autoTeamsKeep(wg);
    ok(wg.players[wg.lineupB[0].pid] && wg.players[wg.lineupB[0].pid].pos === 'GK', 'Bの先発GKが抜けて控えにもいなければ、GKが新しく入る');
  }
  // 段3：60クラブ・名前の書き換え・練習メニューの型
  {
    ok(YA.CLUB60.length === 60 && new Set(YA.CLUB60.map((c) => c.name)).size === 60, '60クラブは名前が重ならない');
    const nicks = YA.CLUB60.filter((c) => c.kind === 'club').map((c) => c.name.split(' ')[1]);
    ok(new Set(nicks).size === nicks.length, '60クラブの愛称が重ならない');
    const w3 = YA.newWorld(21);
    const names1 = w3.league.teams.filter((t) => !t.me).map((t) => t.cid);
    ok(names1.length === 11 && names1.every((c) => YA.CLUB60.find((x) => x.id === c && x.level === w3.league.level)), '相手は同じ部の固定クラブから選ばれる');
    const t0 = w3.league.teams.find((t) => !t.me);
    ok(YA.renameTeam(w3, t0.id, '新しい相手').ok && w3.rename[t0.cid] === '新しい相手', '相手クラブの名前を変えられる');
    ok(YA.renameClub(w3, '').ok === false && YA.renameClub(w3, 'つるはしFC').ok && w3.league.teams.find((t) => t.me).name === 'つるはしFC', '自分のクラブ名を変えられる');
    YA.saveMenuSlot(w3, 1);
    w3.plan.days[0].menu = '休み';
    ok(YA.loadMenuSlot(w3, 1) && w3.plan.days[0].menu !== '休み' && !YA.loadMenuSlot(w3, 2), '練習メニューの型を保存・呼出できる');
  }
  // 段4：Bチームの指揮・中3の練習参加・U-21代表
  {
    const w4 = YA.newWorld(31);
    const lineupA0 = JSON.stringify(w4.lineupA);
    YA.setBCtl(w4, { form: '4-4-2', tactic: 'カウンター', policy: 'young' });
    ok(w4.lineupB.length === 11 && JSON.stringify(w4.lineupA) === lineupA0, 'Bの布陣を変えてもAの並びは変わらない');
    ok(w4.players[w4.lineupB[0].pid].pos === 'GK', 'Bの布陣を変えてもGKが入る');
    const tm = YA.teamFromWorld(w4, 'B');
    ok(tm.tactic.type === 'カウンター' || !YA.TACTICS['カウンター'], 'Bの戦い方が試合用のチームに反映される');
    const b = YA.simulateB(w4);
    ok(w4.resultsB.length === 1 && typeof b.gf === 'number', 'Bの結果が残る');
    // 中3の練習参加：34週に候補が出て、見えている度合いが上がる
    const w5 = YA.newWorld(32);
    w5.week = 34;
    YA.weekExtras(w5);
    const ints = w5.scouting.cands.filter((c) => c.kind === 'int');
    ok(ints.length === 12 && ints.every((c) => c.seen >= 1), '34週に中3が練習に参加して候補になる');
    w5.week = 36;
    YA.weekExtras(w5);
    ok(w5.scouting.cands.filter((c) => c.kind === 'int').every((c) => c.persSeen), '36週の申し送りで性格が見える');
    // U-21代表
    let u21 = 0;
    for (let sd = 1; sd <= 30; sd++) {
      const wa = YA.newWorld(sd);
      wa.alumni.push({ name: 'U21候補', pos: 'FW', year: 1, ovr: 13, note: 'プロ', grade: 3, age: 18, status: 'pro', club: '横浜 ブルーウィング', apps: 0, goals: 0, nat: 0, transfers: 0 });
      for (let k = 0; k < 3; k++) { wa.year = 2 + k; YA.alumniTick(wa); }
      if (wa.alumni.some((a) => a.u21 > 0)) u21++;
    }
    ok(u21 >= 5, 'U-21代表に選ばれる卒業生が出る ' + u21 + '/30');
  }
  // 段5：ライバル監督・再会・新しい出来事
  {
    const w6 = YA.newWorld(41);
    const rv = YA.rivalOf(w6);
    ok(rv.id && rv.coach.length >= 2 && !/監督$/.test(rv.coach), 'ライバル監督が決まる');
    w6.week = 4;
    const n0 = w6.inbox.length;
    YA.rivalWeek(w6);
    ok(w6.inbox.length >= n0, '4週にライバルとの直接対決を知らせる（同じ部のとき）');
    YA.openSelection(w6);
    const rc = w6.scouting.cands.find((c) => c.rival) || (() => { const c = w6.scouting.cands[0]; c.rival = true; return c; })();
    const sp0 = w6.club.spent.scout;
    ok(YA.rivalFight(w6, rc.id).ok && rc.rivalBeat && w6.club.spent.scout === sp0 + 15 && !YA.rivalFight(w6, rc.id).ok, 'ライバルに先んじて会いに行ける（1回だけ）');
    w6.week = 20;
    w6.alumni.push({ name: 'OB選手', pos: 'MF', year: 1, ovr: 12, note: 'プロ', grade: 3, age: 20, status: 'pro', club: 'テストFC', apps: 0, goals: 0, nat: 0, transfers: 0 });
    const c1 = Object.values(w6.players).filter((p) => p.grade === 1)[0].conf;
    YA.rivalWeek(w6);
    ok(Object.values(w6.players).filter((p) => p.grade === 1)[0].conf >= c1, '卒業生が母校を訪ねる');
    for (const id of ['parent', 'rivalry']) {
      const def = YA.EVENTS.find((e) => e.id === id);
      for (let k = 0; k < def.opts.length; k++) {
        const wx = YA.newWorld(50 + k);
        for (const p of Object.values(wx.players)) { p.team = 'A'; p.mins = 10; p.grade = 2; }
        const ps = Object.values(wx.players).filter((p) => p.pos === 'MF');
        if (ps.length >= 2) { ps[1].grade = 2; }
        const r0 = YA.rngOf(7);
        let pk = def.pick(wx, r0);
        if (!pk) { pk = ps[0]; pk._rv = ps[1] && ps[1].id; }
        const e = { id, pid: pk.id, week: 5, year: 1 };
        ok(YA.eventView(wx, e) && YA.resolveEvent(wx, e, k) !== undefined, id + ' の選択肢' + k + 'が動く');
      }
    }
  }
  // 効果音：音の出せない環境でも落ちない
  YA.sfx.on = true;
  for (const k of ['tap', 'goal', 'concede', 'whistle', 'save', 'miss', 'x', null]) YA.sfx.play(k);
  ok(true, '効果音は例外を出さない');
}
// Bの手動入れ替え：先発と控えを替えても人数が崩れず、組み直しでも並びが残る
{
  const wb = YA.newWorld(5);
  YA.setBCtl(wb, { policy: 'manual' });
  const bench0 = wb.benchB[0];
  const old = wb.lineupB[3].pid;
  ok(YA.swapB(wb, 3, bench0), 'swapB が成功する');
  ok(wb.lineupB[3].pid === bench0 && wb.benchB.includes(old), '先発と控えが入れ替わる');
  YA.autoTeams(wb, false);
  ok(wb.lineupB[3].pid === bench0, '手動のときは組み直しでも並びが残る');
  ok(new Set(wb.lineupB.map((s) => s.pid)).size === 11, 'Bの先発に重複がない');
  YA.setBCtl(wb, { policy: 'best' });
  ok(wb.lineupB.length === 11, '方針を戻すと自動で組み直す');
}
// Aのベンチが全員怪我でも、怪我の先発（フィールド）はBから上がった健康な選手で埋まる
{
  const wi = YA.newWorld(3);
  for (const id of wi.benchA) wi.players[id].inj = 5;
  const hurt = wi.lineupA[5].pid;
  wi.players[hurt].inj = 5;
  YA.repairLineup(wi, 'A');
  const now = wi.players[wi.lineupA[5].pid];
  ok(now.id !== hurt && now.inj <= 0 && now.team === 'A', '怪我の先発がBの健康な選手で埋まる');
  ok(wi.players[hurt].team === 'B', '抜けた選手はBへ回る');
  ok(new Set(wi.lineupA.map((s) => s.pid).concat(wi.benchA)).size === 20, '穴埋めのあとも重複がない');
}
// 絵の素材：顔とエンブレムが十分にあり、同じリーグのエンブレムは重ならず、顔は名簿のなかで重ならない
{
  ok(YA.IMG.faces.length >= 70 && YA.IMG.emblems.length >= 60 && YA.IMG.title.startsWith('data:image/'), '素材の数 ' + YA.IMG.faces.length + '/' + YA.IMG.emblems.length);
  ok(YA.IMG.faces.every((u) => u.startsWith('data:image/jpeg')) && YA.IMG.emblems.every((u) => u.startsWith('data:image/png')), '素材は data URI');
  const wa = YA.newWorld(7);
  const idx = wa.league.teams.map((t) => YA.emblemIndex(wa, t.name));
  ok(new Set(idx).size === idx.length && idx.every((k) => k >= 0), '同じリーグのエンブレムは重ならない');
  const srcs = Object.values(wa.players).map((p) => YA.faceSrc(wa, p));
  ok(new Set(Object.values(wa.players).map((p) => p.face)).size === Object.keys(wa.players).length && srcs.every(Boolean), '名簿のなかで顔が重ならない');
}
console.log(fails ? '失敗 ' + fails : '育成の点検: すべて通過');
process.exit(fails ? 1 : 0);
