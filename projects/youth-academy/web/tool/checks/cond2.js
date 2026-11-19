// 選手を構成する要素 段階5（cond2.js）：怪我の部位と重さ・ぶり返し・成長痛・心の状態・8週のグラフ
'use strict';
module.exports = (YA, ok) => {
  const w = YA.newWorld(1301);
  YA.simulate(w, { until: 'year', stopOnImportant: false });
  const ps = Object.values(w.players).concat([]);
  const logs = ps.flatMap((p) => p.injLog || []);
  ok(logs.length >= 5 && logs.every((x) => x.part && x.sev), `怪我に部位と重さが付く（${logs.length}件）`);
  ok(new Set(logs.map((x) => x.part)).size >= 3, '怪我の部位がばらける');
  ok(ps.filter((p) => p.inj > 0).every((p) => p.injPart), 'いま怪我の子には部位がある');
  ok(ps.filter((p) => p.grade >= 2).every((p) => (p.wk8 || []).length === 8), '8週の記録が残る');
  const minds = ps.flatMap((p) => p.mindLog || []);
  console.log('心の状態', minds.map((x) => x.k).join(','), '／成長痛', w.inbox.filter((n) => /成長痛を訴え/.test(n.text)).length, '／再発', logs.filter((x) => x.re).length);
  ok(minds.length >= 2 && minds.length <= 18, `1年で心の状態に陥る子がいる・多すぎない（${minds.length}件）`);
  // ぶり返し：戻って6週は怪我をしやすい
  const p = ps.find((x) => x.pos !== 'GK');
  const k0 = YA.injK(Object.assign({}, p, { relapseW: 0, gpain: 0, mind: null }));
  ok(YA.injK(Object.assign({}, p, { relapseW: 3, gpain: 0, mind: null })) >= k0 * 1.9, '戻ってすぐは怪我をしやすい');
  ok(YA.injK(Object.assign({}, p, { relapseW: 0, gpain: 3, mind: null })) > k0, '成長痛の子は怪我をしやすい');
  ok(YA.growK(Object.assign({}, p, { gpain: 3, mind: null })) < YA.growK(Object.assign({}, p, { gpain: 0, mind: null })), '成長痛の子は伸びが鈍い');
  ok(YA.growK(Object.assign({}, p, { gpain: 0, mind: { k: 'burnout', w: 3 } })) < YA.growK(Object.assign({}, p, { gpain: 0, mind: null })) * 0.8, '燃え尽きの子は伸びが鈍い');
  // 再発：同じ所
  const q = Object.assign(JSON.parse(JSON.stringify(p)), { inj: 0, injPart: null, relapseW: 5, lastPart: '膝' });
  const ww = { seed: 3, year: 1, week: 5, players: { [q.id]: q }, inbox: [] };
  let same = 0;
  for (let i = 0; i < 30; i++) { q.inj = 3; q.injPart = null; q.relapseW = 5; ww.week = i + 1; YA.scanInj(ww); if (q.injPart === '膝' && q.injRe) same++; }
  ok(same >= 10, `ぶり返すと同じ所を痛める（30回中${same}回）`);
  // 面談で抜ける
  const r = ps.find((x) => !x.mind && x.grade <= 2);
  r.talk = -99;
  YA.setMind(w, r, 'homesick', 3);
  YA.talk(w, r.id, 'listen');
  ok(!r.mind, 'ホームシックは悩みを聞くと抜ける');
  ok(YA.stateWords(Object.assign({}, p, { inj: 3, injPart: '足首', injSev: '中程度' })).some(([t]) => /足首（中程度/.test(t)), '状態に怪我の部位と重さが出る');
};
