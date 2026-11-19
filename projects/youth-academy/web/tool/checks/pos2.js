// 選手を構成する要素 段階2（pos2.js）：必ず20・まれに複数・左右の得手・得意な役割・出た試合で適性が育つ・気づき方
'use strict';
module.exports = (YA, ok) => {
  const ws = [1, 2, 3, 4, 5, 6, 7, 8].map((s) => YA.newWorld(700 + s));
  const ps = ws.flatMap((w) => Object.values(w.players));
  const n20 = (p) => YA.POS15.filter((q) => p.apt[q] >= 20).length;
  ok(ps.every((p) => n20(p) >= 1), 'どの子もどこかのポジションが20');
  const two = ps.filter((p) => n20(p) >= 2).length / ps.length;
  ok(two > 0.04 && two < 0.2, `20が2つ以上の子は約1割（${(two * 100).toFixed(1)}%）`);
  ok(ps.filter((p) => p.pos === 'GK').every((p) => p.apt.GK === 20 && n20(p) === 1), 'GK は GK が20');
  const fp = ps.filter((p) => p.pos !== 'GK');
  ok(fp.every((p) => p.favRole && YA.ROLE_DEF[p.favRole]), '得意な役割がある');
  ok(fp.filter((p) => p.sideP === 'L').length > 20 && fp.filter((p) => p.sideP === 'R').length > 20, '左右の得手がばらける');
  // 得意な側のほうが適性が高い（同じ子で左右を比べる）
  const lw = fp.filter((p) => p.sideP && p.best !== 'LM' && p.best !== 'RM' && p.best !== 'LW' && p.best !== 'RW' && (p.p20 || []).every((q) => !/^[LR]/.test(q)));
  const better = lw.filter((p) => (p.sideP === 'L' ? p.apt.LM - p.apt.RM : p.apt.RM - p.apt.LM) > 0).length;
  ok(better > lw.length * 0.6, `得意な側の適性が高い（${better}/${lw.length}）`);
  // 試合に出ると適性が育つ（17まで）
  const w = ws[0];
  const p = Object.values(w.players).find((x) => x.pos !== 'GK' && x.apt.CM < 14 && x.apt.CM > 6);
  if (p) {
    const a0 = p.apt.CM;
    for (let k = 0; k < 10; k++) { p.aptX.CM = (p.aptX.CM || 0) + YA.APT_MATCH; YA.refreshApt(p); }
    ok(p.apt.CM > a0 && p.apt.CM <= 17, `出た試合で適性が育つ（${a0}→${p.apt.CM}）`);
    for (let k = 0; k < 200; k++) { p.aptX.CM += YA.APT_MATCH; YA.refreshApt(p); }
    ok(p.apt.CM <= 17, '試合で育つ適性は17まで');
  }
  // 1年回すと、本当の向きに気づく子が出る（試合・コーチ・申し出）
  const w2 = YA.newWorld(711);
  const hidden0 = Object.values(w2.players).filter((x) => x.pos !== 'GK' && !x.bestKnown && x.best !== x.main).length;
  YA.simulate(w2, { until: 'year', stopOnImportant: false });
  const notes = (w2.inbox || []).filter((n) => /本当に向いているポジションのよう/.test(n.text)).length;
  ok(hidden0 === 0 || notes >= 1, `1年で本当の向きに気づく（${notes}件／ずれていた子${hidden0}人）`);
  ok(Object.values(w2.players).some((x) => Object.values(x.aptX || {}).some((v) => v > 0)), '1年で試合に出た位置の適性が育った子がいる');
  // 古い保存
  const old = JSON.parse(JSON.stringify(ws[2]));
  for (const x of Object.values(old.players)) { delete x.pz; delete x.p20; delete x.favRole; delete x.sideP; }
  YA.ensurePos(old);
  ok(Object.values(old.players).every((x) => x.pz && n20(x) >= 1), '古い保存の子にも足す');
};
