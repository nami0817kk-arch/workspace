// 試作のエンジンを自動で通しプレイして、つり合いを測る。
//   node tool/sim.js          … 3通りの遊び方 × 男女で各200シーズン
//   node tool/sim.js --quick  … 各20シーズン（CI で「最後まで止まらない」ことだけ見る）
// 遊び方: naive=いつも最初の選択肢・何も使わない / random=でたらめ / good=状況を見て選ぶ
const fs = require('fs'), vm = require('vm'), path = require('path');
const src = fs.readFileSync(path.join(__dirname, '..', 'prototype', 'game.html'), 'utf8');
const cut = (a, b) => src.split(a)[1].split(b)[0];
vm.runInThisContext('var FACE_IMG={m:new Array(46).fill("x"),f:new Array(71).fill("x")};var FACE_GRP={m:[...Array(46).keys()],f:[...Array(71).keys()]};' + cut('/*ENGINE-START*/', '/*ENGINE-END*/'));
const N = +(process.env.SIMN || (process.argv.includes('--quick') ? 20 : 200));
// TUNE=ARC_GOOD=4,CROSS_BIG=7 で、つり合いの数を変えて試せる
(process.env.TUNE || '').split(',').filter(Boolean).forEach((x) => { const [k, v] = x.split('='); vm.runInThisContext(k + '=' + (+v)); });
// PERKS=all で心得を全部解放した状態、CHAL=poor などでチャレンジを付けて測れる
if (process.env.PERKS === 'all') loadPerks = () => Object.fromEntries(PERKS.map((p) => [p.k, p.max]));
// ABL=talk,event,... でその仕組みを切って測る（仕組みが最終評価にどれだけ効いているかを見る。2026-10-04）
const ABL = (process.env.ABL || '').split(',').filter(Boolean);
const OFF = {
  talk: () => { apMax = () => 0; },                 // 関わる時間
  event: () => { genEvents = () => []; },          // 出来事
  trait: () => { gainTrait = () => ''; traitPerf = () => 1; },   // 特性
  awaken: () => { awaken = () => {}; },            // 覚醒
  bond: () => { addBond = () => {}; },             // 絆（ふたりの物語・コンビにも効く）
  combo: () => { formCombo = () => {}; comboMul = () => 1; },
  crit: () => { applyCritique = () => {}; },       // 講評
  feat: () => { applyFeature = () => {}; },        // 大きく映す
  center: () => { centersOf = () => []; },         // センター
  tone: () => { applyTone = () => ''; },           // 気質による効き方
  mission: () => { MISSION_PT = 0; },              // 依頼
};
ABL.forEach((k) => { if (!OFF[k]) throw new Error('ABL の名前が違う: ' + k); OFF[k](); });

// FIX=arc:0 などで、good の遊び方のうち1種類の選択だけを「いつも同じもの」に固定して測る（2026-11-14）
//   arc:0|1|2（物語の3択の表示の何番目か）・ev:0|1|2（出来事）・month:tv など（4週とも同じ）・crit:0〜7（選ぶ子の講評）・fw:0|1|2（不合格の子への言葉）
let FIX = {};
function parseFix(v) { const o = {}; (v || '').split(',').filter(Boolean).forEach((x) => { const [k, w] = x.split(':'); o[k] = isNaN(+w) ? w : +w; }); return o; }
FIX = parseFix(process.env.FIX);
// --choices では、物語の続きがあるデビュー候補と先に話す（物語の選び方の差を測るため。TALK8=1 で通常の試算にも）
let TALK8 = process.env.TALK8 ? process.env.TALK8 !== '0' : process.argv.includes('--choices');
function pickIdx(pol, n) { return pol === 'random' ? ri(0, n - 1) : 0; }
function goodEv(S, e, n) { // good の出来事の選び方：分かれ道は足りない項目、仲間割れは話し合い、ほかは最初
  if (e.type === 'cross') { const w = crossWeak(S); return w ? CROSS_K.indexOf(w) : 0; }
  return 0;
}
function goodFw(S) { let nl = 0; // 人気の子には「また会おう」、大きく伸びた子は「誇って」、残りは課題を2人まで
  S.call.failed.forEach((id) => { const t = S.tr[id]; S.farewell[id] = t.pop >= FW_POP ? 2 : fwGrow(t) >= 15 ? 0 : nl++ < 2 ? 1 : 0; });
}
function play(g, pol, seed) {
  if (seed != null) seedRng(seed); // 応募者も同じにする（newGame の終わりで乱数が戻るので、あとでもう一度）
  const S = newGame(g, process.env.DIFF || 'normal', process.env.CHAL || null);
  if (seed != null) seedRng(seed * 7 + 3);
  let c = S.tr.slice();
  if (pol === 'good') { c.sort((a, b) => (HINT_LINES.includes(b.line) - HINT_LINES.includes(a.line)) || b.popStar - a.popStar); if (typeof watchVideo === 'function') c.slice(0, 3).forEach(t => watchVideo(S, t.id)); c.sort((a, b) => ((b.potRev && b.pot >= 1.3) - (a.potRev && a.pot >= 1.3)) || (HINT_LINES.includes(b.line) - HINT_LINES.includes(a.line)) || b.popStar - a.popStar); }
  else shuffle(c);
  S.sel = c.slice(0, S.caps.sel).map(t => t.id); confirmSelect(S);
  if (pol === 'random') S.fmt = shuffle((typeof fmtKeys==='function'?fmtKeys():FMT_KEYS).filter(k => !S.locked || !S.locked[k]).slice()).slice(0, 4);
  startSeason(S);
  for (let r = 1; r <= NROUND; r++) {
    if (S.phase !== 'plan') throw new Error('plan? ' + S.phase);
    if (r === 3 && typeof forecast === 'function') { const F = forecast(S); S._fc = F ? F.total : null; }
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
    if (pol === 'good' && typeof pairList === 'function') { const pr = pairList(S)[0]; if (pr && S.ap > 1) { doPair(S, pr.a, pr.b); S.talk = null; } }
    if (pol !== 'naive' && typeof doOut === 'function' && S.ap > 1 && R() < .5) { const ot = pick(alive(S)); doOut(S, ot.id, ri(0, OUTS.length - 1)); if (S.talk) { outChoose(S, ri(0, 2)); S.talk = null; } }
    while (S.ap > 0 && pol !== 'naive') {
      // good：デビューしそうな子（出来の上位8人）の物語を先に進める。無ければ信頼のいちばん高い子
      const top8 = alive(S).sort((a, b) => b.lastP - a.lastP).slice(0, 8).filter((x) => x.arc && x.arc.step < 3 && S.talked.indexOf(x.id) < 0);
      const t = pol === 'good' ? ((TALK8 && top8[0]) || alive(S).sort((a, b) => b.trust - a.trust)[0]) : pick(alive(S));
      if (pol === 'good' && t.likeRev && S.ap === 1) { doGift(S, t.id, t.gift); S.talk = null; continue; }
      doTalk(S, t.id);
      if (S.talk.kind === 'arc') talkChoose(S, pol === 'good' ? (FIX.arc != null ? FIX.arc : bestArc(S, t)) : ri(0, 2));
      else if (S.talk.kind === 'honne') honneChoose(S, 0);
      else if (S.talk.kind === 'free') freeChoose(S, pol === 'good' ? (t.temper === 'sensai' ? 0 : t.temper === 'mypace' || t.temper === 'ochoshi' ? 2 : 1) : ri(0, 2));
      S.talk = null;
    }
    afterTalk(S);
    if (S.phase === 'interview') applyInterview(S);
    while (S.phase === 'event') { const e = S.events[S.evIdx], eA = S.tr[e.ids[0]], eB = e.ids[1] != null ? S.tr[e.ids[1]] : null;
      const nCh = EV[e.type].choices(S, e, eA, eB).length;
      let ci = pol === 'good' ? (e.type === 'arc' ? (FIX.arc != null ? FIX.arc : bestArc(S, eA)) : FIX.ev != null ? Math.min(FIX.ev, nCh - 1) : goodEv(S, e, nCh)) : pickIdx(pol, nCh);
      if (e.type === 'bond') { S._bev = (S._bev || 0) + 1; if (pol === 'good' && FIX.ev == null && eA.temperRev && eB.temperRev) ci = EV.bond.tones(S, e, eA, eB).indexOf(bondRight(S, eA, eB)); }
      resolveEvent(S, ci); nextEvent(S); }
    if (S.phase !== 'show') throw new Error('show? ' + S.phase);
    S.phase = 'stage';
    if (ROUNDS[r].crit) { if (pol === 'random') alive(S).forEach(t => S.crit[t.id] = ri(0, CRIT.length - 1));
      if (pol === 'good') { const cs = critSet(S); alive(S).forEach((t) => { if (!cs[t.id]) return; if (FIX.crit != null) S.crit[t.id] = FIX.crit; else S.crit[t.id] = t.temperRev ? critFit(t, S) : 1; }); }
      applyCritique(S); }
    if (pol !== 'naive') { S.feat = {}; const pr = popRankMap(S), B = alive(S), res = S.stage.res;
      const cand = pol === 'good' ? B.filter((x) => pr[x.id] > 3).sort((x, y) => res[y.id].sc - res[x.id].sc) : shuffle(B.slice());
      cand.slice(0, 3).forEach((x) => { S.feat[x.id] = true; }); }
    applyFeature(S);
    if (typeof toNight === 'function') { toNight(S); if (S.phase === 'night') { if (pol === 'naive') nightSkip(S); else answerReq(S, 0, pol === 'good' ? 1 : ri(0, 1)); S.phase = 'judge'; } }
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
    S._mf = Math.max(S._mf || 0, ...alive(S).map(t => t.fat)); S._inj = (S._inj || 0) + alive(S).filter(t => t.inj).length;
    decide(S);
    if (pol === 'good') { if (FIX.fw != null) S.call.failed.forEach((id) => { S.farewell[id] = FIX.fw; }); else goodFw(S); }
    if (!ROUNDS[r].fin) nextRound(S);
  }
  applyFarewell(S); startPrep(S);
  const D = S.tr.filter(t => t.status === 'debut');
  S.prep.leader = (pol === 'good' ? D.slice().sort((a, b) => b.trust - a.trust)[0] : D[0]).id;
  if (pol === 'good') { const cnt = { v: 0, d: 0, r: 0 }; D.forEach(t => cnt[bestVDR(t)[0]]++); S.prep.dir = ['v', 'd', 'r'].indexOf(Object.keys(cnt).sort((a, b) => cnt[b] - cnt[a])[0]); }
  if (pol === 'random') { S.prep.dir = ri(0, 2); }
  if (typeof startMonth === 'function') { startMonth(S);
    const plan = pol === 'good' ? (FIX.month ? [FIX.month, FIX.month, FIX.month, FIX.month] : ['tv', S.budget >= 30 ? 'mv' : 'stream', 'rest', D.some((t) => t.spec === 't') ? 'radio' : 'meet']) : pol === 'random' ? [0, 1, 2, 3].map(() => pick(WEEK_ACTS).k) : ['tv', 'tv', 'tv', 'tv'];
    plan.forEach(k => { if (S.phase === 'month') { const b = S.budget; weekDo(S, k); if (S.month.w === 0 || (S.budget === b && k === 'mv' && S.phase === 'month' && S.month.log.length === 0)) weekDo(S, 'tv'); } });
    while (S.phase === 'month' && S.month.w < 4) weekDo(S, 'rest'); finishMonth(S); }
  const E = finalEval(S);
  return { E, S };
}
function bestArc(S, t) { // 場面を読んで選ぶ。気質が分かっていれば、気質に合う語りかけを選ぶ（返すのは画面の並びの番号）
  const tones = ARC_TONE[t.arc.k][t.arc.step], sc = ARCS[t.arc.k].sc[t.arc.step], perm = arcPerm(t);
  let best = 0, bv = -1e9;
  perm.forEach((oi, i) => { const c = sc.ch[oi], tone = tones.charAt(oi); const v = t.temperRev ? arcFit(t, c, tone) * 3 + c[3] : c[3] * 3;
    if (v > bv) { bv = v; best = i; } });
  return best;
}
// --choices：選択の差が残っているかを測る（2026-11-14）。good と、1種類の選択だけを固定した遊び方を
// 同じ乱数の種で回して比べる。CI では少ない回数で「good が固定より下回っていない」ことだけ見る
const CHOICES = [
  ['arc', ['arc:0', 'arc:1', 'arc:2']],
  ['ev', ['ev:0', 'ev:1', 'ev:2']],
  ['month', ['month:tv', 'month:radio', 'month:stream', 'month:meet']],
  ['crit', ['crit:1', 'crit:7', 'crit:0']],
  ['fw', ['fw:0', 'fw:1', 'fw:2']],
];
function avgOf(spec, n) { FIX = parseFix(spec); let tot = 0, k = 0;
  for (let i = 0; i < n; i++) for (const g of ['m', 'f']) { try { tot += play(g, 'good', 1000 + i * 2 + (g === 'f')).E.total; k++; } catch (e) { console.error(spec, e.stack); process.exitCode = 1; } }
  FIX = {}; return tot / k; }
if (process.argv.includes('--choices')) {
  // CI（--quick）は種類ごとの下限（2026-11-14 の手元の200回で arc +6.8・ev +1.5・month +2.5・crit +0.4・fw +2.4）
  const quick = process.argv.includes('--quick'), n = +(process.env.SIMN || (quick ? 30 : 200));
  const QMIN = { arc: 3, ev: 0.5, month: 1, crit: 0, fw: 1 }, gapMin = (k) => (process.env.MINGAP != null ? +process.env.MINGAP : quick ? QMIN[k] : 1.5);
  const base = avgOf('', n); console.log('good（よく考える）', base.toFixed(2), '（' + n * 2 + 'シーズン、同じ種）');
  for (const [k, fixes] of CHOICES.filter(([k]) => !process.env.ONLY || process.env.ONLY.split(',').includes(k))) {
    const r = fixes.map((f) => [f, avgOf(f, n)]), worst = Math.max(...r.map((x) => x[1])), gap = base - worst;
    console.log(k.padEnd(6), r.map(([f, v]) => f + ' ' + v.toFixed(2)).join(' / '), '→ good との差（いちばん良い固定と比べて）', (gap >= 0 ? '+' : '') + gap.toFixed(2), '下限 +' + gapMin(k), gap >= gapMin(k) ? 'ok' : 'NG');
    if (gap < gapMin(k)) process.exitCode = 1;
  }
  if (process.exitCode) console.error('選択の差が足りない');
  process.exit();
}
const out = {};
for (const pol of (process.env.POLS || 'naive,random,good').split(',')) for (const g of ['m', 'f']) {
  let cs = 0, cc = 0, cf = 0, cw = 0, tot = 0, gr = {}, bud = 0, mis = 0, err = 0, tg = 0, tb = 0, nd = 0, fe = 0, fn = 0, bev = 0, cmb = 0, cmbD = 0, awk = 0, mf = 0, inj = 0;
  for (let i = 0; i < N; i++) {
    let o; try { o = play(g, pol); } catch (e) { err++; if (err === 1) console.error(pol, g, e.stack); continue; }
    cs += o.E.song; cc += o.E.coh; cf += o.E.fanScore; cw += o.E.show; tot += o.E.total; gr[o.E.grade] = (gr[o.E.grade] || 0) + 1; bud += o.S.budget; mis += (o.E.missions || []).filter(x => x.ok).length;
    o.S.tr.filter(t => t.status === 'debut').forEach(t => { nd++; (t.traits || []).forEach(x => TRAITS[x].g ? tg++ : tb++); });
    mf += o.S._mf || 0; inj += o.S._inj || 0;
    bev += o.S._bev || 0; for (const k in (o.S.bond || {})) if (o.S.bond[k].combo) cmb++; cmbD += (o.E.combos || []).length; awk += o.S.tr.filter(t => t.awoke).length;
    if (o.S._fc != null) { fe += (o.E.total - o.S._fc); fn++; }
  }
  if (err) { console.error('失敗 ' + err + '件'); process.exitCode = 1; }
  const k = N - err;
  console.log(pol.padEnd(6), g, '平均', (tot / k).toFixed(1), '内訳(曲/まとまり/ファン/視聴率)', [cs, cc, cf, cw].map((x) => (x / k).toFixed(0)).join('/'), '評価', JSON.stringify(gr), '残り制作費', Math.round(bud / k), '依頼達成', (mis / k).toFixed(2),
    '特性(デビュー組1人あたり 良/悪)', (tg / nd).toFixed(2) + '/' + (tb / nd).toFixed(2), '第3審査時点の評価からの伸び', fn ? (fe / fn).toFixed(1) : '-',
    'ふたりの物語', (bev / k).toFixed(1), 'コンビ(結成/デビュー)', (cmb / k).toFixed(2) + '/' + (cmbD / k).toFixed(2), '覚醒', (awk / k).toFixed(2), '疲れの最大', (mf / k).toFixed(0), 'けが', (inj / k).toFixed(2));
}
