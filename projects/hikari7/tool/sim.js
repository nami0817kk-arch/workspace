// 試作のエンジンを自動で通しプレイして、つり合いを測る。
//   node tool/sim.js          … 3通りの遊び方 × 男女で各200シーズン
//   node tool/sim.js --quick  … 各20シーズン（CI で「最後まで止まらない」ことだけ見る）
// 遊び方: naive=いつも最初の選択肢・何も使わない / random=でたらめ / good=状況を見て選ぶ
const fs = require('fs'), vm = require('vm'), path = require('path');
const src = fs.readFileSync(path.join(__dirname, '..', 'prototype', 'game.html'), 'utf8');
const cut = (a, b) => src.split(a)[1].split(b)[0];
vm.runInThisContext('var FACE_IMG={m:new Array(46).fill("x"),f:new Array(71).fill("x")};var FACE_GRP={m:[...Array(46).keys()],f:[...Array(71).keys()]};' + cut('/*ENGINE-START*/', '/*ENGINE-END*/'));
const N = process.argv.includes('--quick') ? 20 : 200;

function pickIdx(pol, n) { return pol === 'random' ? ri(0, n - 1) : 0; }
function play(g, pol) {
  const S = newGame(g, process.env.DIFF || 'normal');
  let c = S.tr.slice();
  if (pol === 'good') { c.sort((a, b) => (HINT_LINES.includes(b.line) - HINT_LINES.includes(a.line)) || b.popStar - a.popStar); if (typeof watchVideo === 'function') c.slice(0, 3).forEach(t => watchVideo(S, t.id)); c.sort((a, b) => ((b.potRev && b.pot >= 1.3) - (a.potRev && a.pot >= 1.3)) || (HINT_LINES.includes(b.line) - HINT_LINES.includes(a.line)) || b.popStar - a.popStar); }
  else shuffle(c);
  S.sel = c.slice(0, S.caps.sel).map(t => t.id); confirmSelect(S);
  if (pol === 'random') S.fmt = shuffle(FMT_KEYS.filter(k => !S.locked || !S.locked[k]).slice()).slice(0, 4);
  startSeason(S);
  for (let r = 1; r <= NROUND; r++) {
    if (S.phase !== 'plan') throw new Error('plan? ' + S.phase);
    if (pol !== 'naive') {
      const A = alive(S);
      if (r >= 2) S.plan.center = (pol === 'good' ? A.slice().sort((a, b) => b.lastP - a.lastP)[0] : pick(A)).id;
      if (S.budget >= 15) S.plan.acts.meal = true;
      if (pol === 'good' && S.budget >= 55) { S.plan.acts.coach = true; S.plan.coachK = 'e'; }
      if (pol === 'random' && S.budget >= 40 && R() < .5) S.plan.acts.stage = true;
    }
    applyPlan(S);
    const A = alive(S).sort((a, b) => b.lastP - a.lastP); let u = 0;
    if (pol === 'good' && typeof autoLesson === 'function') autoLesson(S);
    else if (pol !== 'naive') for (const t of A) { if (u >= slotsOf(S)) break; S.lesson.train[t.id] = [t.spec === 't' ? 'e' : t.spec]; u++; }
    applyLesson(S);
    S.reqs.forEach((q, qi) => answerReq(S, qi, pol === 'good' ? (q.type === 'tired' || q.type === 'anxious' || q.type === 'grief' ? (q.type === 'grief' ? 1 : 0) : 1) : pickIdx(pol, 2)));
    while (S.ap > 0 && pol !== 'naive') {
      const t = pol === 'good' ? alive(S).sort((a, b) => b.trust - a.trust)[0] : pick(alive(S));
      if (pol === 'good' && t.likeRev && S.ap === 1) { doGift(S, t.id, t.gift); S.talk = null; continue; }
      doTalk(S, t.id);
      if (S.talk.kind === 'arc') talkChoose(S, pol === 'good' ? bestArc(S, t) : ri(0, 2));
      else if (S.talk.kind === 'honne') honneChoose(S, 0);
      S.talk = null;
    }
    afterTalk(S);
    if (S.phase === 'interview') applyInterview(S);
    while (S.phase === 'event') { resolveEvent(S, pickIdx(pol, EV[S.events[S.evIdx].type].choices(S, S.events[S.evIdx], S.tr[S.events[S.evIdx].ids[0]], S.events[S.evIdx].ids[1] != null ? S.tr[S.events[S.evIdx].ids[1]] : null).length)); nextEvent(S); }
    if (S.phase !== 'show') throw new Error('show? ' + S.phase);
    S.phase = 'stage';
    if (ROUNDS[r].crit) { if (pol === 'random') alive(S).forEach(t => S.crit[t.id] = ri(0, 2)); applyCritique(S); }
    applyFeature(S);
    const B = alive(S), res = S.stage.res;
    let n = ROUNDS[r].fin ? Math.min(6, S.caps.finMax, B.length) : capOf(S);
    let order = B.slice().sort((a, b) => res[b.id].sc - res[a.id].sc);
    if (pol === 'good' && ROUNDS[r].fin) {
      const pick_ = [], need = { v: 2, d: 2, r: 1 };
      for (const role of ['v', 'd', 'r']) for (const t of order) if (pick_.length < n && bestVDR(t)[0] === role && pick_.filter(x => bestVDR(x)[0] === role).length < need[role] && !pick_.includes(t)) pick_.push(t);
      for (const t of order) if (pick_.length < n && !pick_.includes(t)) pick_.push(t);
      order = pick_;
    }
    order.slice(0, n).forEach(t => S.pass[t.id] = true);
    decide(S);
    if (!ROUNDS[r].fin) nextRound(S);
  }
  applyFarewell(S); startPrep(S);
  const D = S.tr.filter(t => t.status === 'debut');
  S.prep.leader = (pol === 'good' ? D.slice().sort((a, b) => b.trust - a.trust)[0] : D[0]).id;
  if (pol === 'good') { const cnt = { v: 0, d: 0, r: 0 }; D.forEach(t => cnt[bestVDR(t)[0]]++); S.prep.dir = ['v', 'd', 'r'].indexOf(Object.keys(cnt).sort((a, b) => cnt[b] - cnt[a])[0]); S.prep.act = 2; }
  if (pol === 'random') { S.prep.dir = ri(0, 2); S.prep.act = ri(0, 2); }
  if (typeof startMonth === 'function') { startMonth(S);
    const plan = pol === 'good' ? ['tv', S.budget >= 30 ? 'mv' : 'stream', 'rest', 'tv'] : pol === 'random' ? [0, 1, 2, 3].map(() => pick(WEEK_ACTS).k) : ['tv', 'tv', 'tv', 'tv'];
    plan.forEach(k => { if (S.phase === 'month') { const b = S.budget; weekDo(S, k); if (S.month.w === 0 || (S.budget === b && k === 'mv' && S.phase === 'month' && S.month.log.length === 0)) weekDo(S, 'tv'); } });
    while (S.phase === 'month') weekDo(S, 'rest'); }
  const E = finalEval(S);
  return { E, S };
}
function bestArc(S, t) { // 気質が分かっていれば、合う語りかけを選ぶ
  const tones = ARC_TONE[t.arc.k][t.arc.step], sc = ARCS[t.arc.k].sc[t.arc.step];
  let best = 0, bv = -1e9;
  sc.ch.forEach((c, i) => { const tone = tones.charAt(i); let v = c[3] * 3;
    if (t.temperRev) { if (t.temper === 'sensai' && tone === 'h') v -= 5; if (t.temper === 'makezu' && (tone === 'h' || tone === 'f')) v += 1; if (t.temper === 'sensai' && tone === 's') v += 1; }
    if (v > bv) { bv = v; best = i; } });
  return best;
}
const out = {};
for (const pol of ['naive', 'random', 'good']) for (const g of ['m', 'f']) {
  let tot = 0, gr = {}, bud = 0, mis = 0, err = 0;
  for (let i = 0; i < N; i++) {
    let o; try { o = play(g, pol); } catch (e) { err++; if (err === 1) console.error(pol, g, e.stack); continue; }
    tot += o.E.total; gr[o.E.grade] = (gr[o.E.grade] || 0) + 1; bud += o.S.budget; mis += (o.E.missions || []).filter(x => x.ok).length;
  }
  if (err) { console.error('失敗 ' + err + '件'); process.exitCode = 1; }
  const k = N - err;
  console.log(pol.padEnd(6), g, '平均', (tot / k).toFixed(1), '評価', JSON.stringify(gr), '残り制作費', Math.round(bud / k), '依頼達成', (mis / k).toFixed(2));
}
