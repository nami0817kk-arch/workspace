// 選手を構成する要素 段階8（records.js）：大会ごとの成績・名場面・伸びの推移
'use strict';
module.exports = (YA, ok) => {
  const w = YA.newWorld(1701);
  YA.simulate(w, { until: 'year', stopOnImportant: false });
  const ps = Object.values(w.players);
  const comps = new Set(ps.flatMap((p) => YA.compRows(p).map((c) => c.c)));
  ok(comps.has('Bチーム') && comps.size >= 3, '大会ごと（B チームも分けて）に成績が残る：' + [...comps].join('・'));
  const rows = ps.flatMap((p) => YA.compRows(p));
  ok(rows.every((c) => c.n >= 1 && c.rs >= c.n * 3 && c.rs <= c.n * 10), '平均採点が 3〜10 の間');
  ok(rows.some((c) => c.mom > 0), '試合の最優秀が数えられる');
  ok(ps.filter((p) => p.pos === 'GK').every((p) => YA.compRows(p).every((c) => c.gl === 0)), 'GK は得点しない');
  const sc = ps.flatMap((p) => p.scenes || []);
  const kinds = new Set(sc.map((x) => x.k));
  console.log('名場面', [...kinds].join(','), sc.length);
  ok(kinds.has('debut') && kinds.has('first') && sc.length >= 10, '名場面（初出場・初ゴールなど）が残る');
  ok(ps.every((p) => (p.scenes || []).filter((x) => x.k === 'debut').length <= 1), '初出場は1回だけ');
  { const g2 = ps.filter((p) => p.grade >= 2); ok(g2.filter((p) => (p.rtH || []).length >= 10).length >= g2.length * 0.9, '伸びの推移が月ごとに残る'); }
  const grads = (w.alumni || []).filter((a) => a.year === 1 && a.status !== 'left');
  ok(grads.length && grads.every((a) => a.rtH && a.rtH.length >= 5), '卒業生に伸びの推移が残る');
  ok(grads.some((a) => (a.comp || []).length && (a.scenes || []).length), '卒業生に大会ごとの成績と名場面が残る');
};
