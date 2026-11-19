// 選手を構成する要素 段階4（persona.js）：分かるまで・経験で変わる・相性・効き目
'use strict';
module.exports = (YA, ok) => {
  const w = YA.newWorld(1201);
  const ps = Object.values(w.players);
  const nz = (p) => Object.keys(p.pers).filter((g) => p.pers[g] !== 'ふつう');
  ok(ps.filter((p) => p.grade >= 2).every((p) => YA.persHidden(p).length === 0), '始めた年の高2・高3の性格は分かっている');
  const g1 = ps.filter((p) => p.grade === 1 && nz(p).length);
  ok(g1.some((p) => YA.persHidden(p).length > 0), '高1にはまだ見えていない性格がある');
  ok(g1.every((p) => Object.values(YA.persVisible(p)).every((t) => t === 'ふつう' || nz(p).some((g) => p.pers[g] === t))), '見えている性格だけを見せる');
  const hid0 = g1.reduce((s, p) => s + YA.persHidden(p).length, 0);
  YA.simulate(w, { until: 'year', stopOnImportant: false });
  const left = Object.values(w.players).filter((p) => p.grade === 2).reduce((s, p) => s + YA.persHidden(p).length, 0);
  ok(left < hid0 * 0.6, `1年で性格が見えてくる（${hid0}→${left}）`);
  // 経験で変わる
  const p = Object.values(w.players).find((x) => (x.pers['人との関わり'] || 'ふつう') === 'ふつう');
  p.px = { cap: 25 }; p.pxY = null;
  YA.persTryGrow(w, p);
  ok(p.pers['人との関わり'] === 'リーダー気質' && (p.persCh || []).length === 1, '主将を続けるとリーダー気質が出てくる');
  p.px = { bigok: 3 };
  const before = p.pers['大舞台'];
  YA.persTryGrow(w, p);
  ok(p.pers['大舞台'] === before, '性格が変わるのは1年に1回まで');
  // 相性
  const a = { pers: { 人との関わり: 'リーダー気質' } }, b = { pers: { 教えの受け止め方: '素直' } }, c = { pers: { 感情の波: '短気' } };
  ok(YA.persCompat(a, b).s > 0 && YA.persCompat(c, Object.assign({}, c)).s < 0, '相性：リーダー気質と素直は合う・短気どうしは合わない');
  const t = YA.teamFromWorld(w, 'A');
  ok(Object.values(t.players).every((x) => x._cg != null && x._cb != null), '試合のチームに相性の数が入る');
  ok(YA.compatMod({ _cg: 2, _cb: 0 }) > 0 && YA.compatMod({ _cg: 0, _cb: 2 }) < 0, '相性が試合の力に効く');
  // 古い保存
  const old = JSON.parse(JSON.stringify(w));
  for (const x of Object.values(old.players)) delete x.pk;
  YA.ensurePersona(old);
  ok(Object.values(old.players).every((x) => YA.persHidden(x).length === 0), '古い保存の子は性格が分かっている');
};
