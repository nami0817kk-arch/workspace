// 選手を構成する要素 段階3（traits2.js・data.js の TRAIT_X/HABITS/TRAIT_COMBO・engine の traitXMod）
'use strict';
module.exports = (YA, ok) => {
  ok(YA.TRAITS.length === 100 && new Set(YA.TRAITS).size === 100, `特性は100個で重なりがない（${YA.TRAITS.length}）`);
  ok(YA.TRAITS.every((t) => YA.GOLD[t] && YA.TRAIT_AFF[t]), 'どの特性にも金と覚えやすさ（関わる能力）がある');
  ok(new Set(Object.values(YA.GOLD)).size === Object.keys(YA.GOLD).length, '金の名前が重ならない');
  ok(Object.values(YA.TRAIT_AFF).every((a) => a.every((n) => YA.AB_FIELD.concat(YA.AB_GK).indexOf(n) >= 0)), '関わる能力の名前が正しい');
  ok(YA.AWAKE_FORMS.length === 40, '覚醒の形は40種');
  ok(YA.TRAIT_COMBO.every(([a, b]) => YA.TRAITS.indexOf(a) >= 0 && YA.TRAITS.indexOf(b) >= 0), '組み合わせの特性が一覧にある');
  // 新しい30個・悪い癖・組み合わせが試合で効く（両チームの全員に持たせて回す）
  const NEW = Object.keys(YA.TRAIT_X);
  const seen = new Set();
  const habitSeen = new Set();
  const comboSeen = new Set();
  const P = YA.Match.prototype, tb0 = P.traitBonus, fx0 = P._fx;
  P.traitBonus = function (sc, p, t) { const v = tb0.apply(this, arguments); if (v > 0) seen.add(t); return v; };
  P._fx = function (sc, p, kind, tag) { if (kind === 'habit') habitSeen.add(tag); if (kind === 'combo') comboSeen.add(tag); return fx0.apply(this, arguments); };
  const habits = Object.keys(YA.HABITS);
  try {
    for (let s = 1; s <= 40 && NEW.some((t) => !seen.has(t)); s++) {
      const m = new YA.Match({ seed: s, home: YA.makeOurs(1), away: YA.makeOpponent(YA.OPPONENTS[s % 3], s * 7 + 3), settings: { autoStop: false } });
      let k = s;
      for (const t of [m.home, m.away]) for (const p of Object.values(t.players)) {
        const isGK = p.pos === 'GK';
        p.traits = p.traits.concat(NEW.filter((x) => !!YA.TRAIT_X[x].gk === isGK && p.traits.indexOf(x) < 0)).concat(isGK ? [] : YA.TRAIT_COMBO[k++ % YA.TRAIT_COMBO.length].slice(0, 2));
        p.habits = habits.filter((x) => !!YA.HABITS[x].gk === isGK);
        p.conf = 75;
      }
      let g = 0;
      while (!m.finished && g++ < 1000) m.step();
    }
  } finally { P.traitBonus = tb0; P._fx = fx0; }
  const miss = NEW.filter((t) => !seen.has(t));
  ok(miss.length <= 2, '新しい特性30個が試合で効く（効かなかったもの：' + miss.join('・') + '）');
  ok(habitSeen.size >= 5, '悪い癖が試合で出る（' + [...habitSeen].join('・') + '）');
  ok(comboSeen.size >= 4, '特性の組み合わせが試合で出る（' + [...comboSeen].join('・') + '）');
  // 悪い癖：約3割が持つ・直せる
  const ps = [1, 2, 3, 4].flatMap((s) => Object.values(YA.newWorld(950 + s).players));
  const share = ps.filter((p) => p.habits.length).length / ps.length;
  ok(share > 0.18 && share < 0.42, `悪い癖を持つ子は約3割（${(share * 100).toFixed(0)}%）`);
  ok(ps.every((p) => p.habits.every((h) => !!YA.HABITS[h].gk === (p.pos === 'GK'))), 'GK の癖と FP の癖が分かれている');
  const w = YA.newWorld(960);
  const p = Object.values(w.players).find((x) => x.habits.length);
  if (p) {
    const hk = p.habits[0];
    ok(YA.setHabitFix(w, p, hk).ok && p.train.habit === hk && !p.train.trait, '癖を直す練習を選べる（特性の練習は外れる）');
    for (let k = 0; k < 25 && p.habits.indexOf(hk) >= 0; k++) { w.week = k + 1; p.inj = 0; YA.runTraining(w); }
    ok(p.habits.indexOf(hk) < 0, '練習を続けると癖が直る');
  }
  // 出どころ：先輩が持っている特性は「先輩から」・覚えるのが速い
  const w2 = YA.newWorld(961);
  const kid = Object.values(w2.players).find((x) => x.grade === 1 && x.pos !== 'GK');
  const sen = Object.values(w2.players).find((x) => x.grade === 3 && x.pos !== 'GK');
  const t = YA.learnable(kid).map((x) => x.t).find((x) => sen.traits.indexOf(x) < 0);
  if (t) {
    sen.traits = sen.traits.slice(0, 4).concat([t]);
    const te = YA.traitTeacher(w2, kid, t);
    ok(te && te.k === 'senior', '先輩の特性は先輩から覚える');
  }
  // 金までの道のり
  const gp = Object.values(w2.players).find((x) => x.traits.length && !YA.isGold(x, x.traits[0]));
  if (gp) { const g = YA.goldProgress(gp, gp.traits[0]); ok(g && g.need === YA.GOLD_USES && g.name === YA.GOLD[gp.traits[0]], '金までの道のりが分かる'); }
  // 覚醒：2回目でも前の特性が残る・まれに2つ
  const w3 = YA.newWorld(962);
  const st = Object.values(w3.players).find((x) => x.pos !== 'GK');
  st.awN = 2;
  YA.awaken(w3, st);
  const first = st.aw.trait;
  YA.awaken(w3, st);
  ok(st.aw2 && st.aw2.trait === first && st.aw.trait !== first, '2回目の覚醒でも前の覚醒の特性が残る');
  let doubles = 0;
  for (let s = 0; s < 300; s++) {
    const w4 = { seed: s, year: 1, week: 10, players: {}, dex: {}, inbox: [], forced: [] };
    const q = JSON.parse(JSON.stringify(st));
    delete q.aw; delete q.aw2; q.awHist = []; q.awDone = 0; q.id = 'x' + s; q.hist = [];
    w4.players[q.id] = q;
    try { YA.awaken(w4, q); } catch (e) { /* 図鑑などの付属 */ }
    if (q.aw2) doubles++;
  }
  ok(doubles >= 8 && doubles <= 45, `覚醒の特性が2つになるのはまれ（300回中${doubles}回）`);
};
