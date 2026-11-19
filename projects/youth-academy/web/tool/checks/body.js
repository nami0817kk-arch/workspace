// 選手を構成する要素 段階1（body.js）：身長・誕生日・体重と体型・出身地・隠れた能力・成長の型・GK の伸びしろ
'use strict';
module.exports = (YA, ok) => {
  const ws = [1, 2, 3, 4, 5, 6].map((s) => YA.newWorld(500 + s));
  const ps = ws.flatMap((w) => Object.values(w.players));
  ok(ps.every((p) => p.bd && p.bday && p.gt && p.hid && p.born && p.body), '全員に誕生日・成長の型・隠れた能力・出身・体型がある');
  ok(ps.every((p) => p.height >= YA.H_MIN && p.height <= YA.H_MAX && p.hFin >= p.height), `身長は${YA.H_MIN}〜${YA.H_MAX}cm、行き着く背はいま以上`);
  const hs = ps.map((p) => p.height).sort((a, b) => a - b);
  ok(hs[0] < 162 || hs[hs.length - 1] > 191, `身長の幅が前（164〜191）より広い（${hs[0]}〜${hs[hs.length - 1]}）`);
  const avg = hs.reduce((a, b) => a + b, 0) / hs.length;
  ok(avg > 168 && avg < 180, `身長の平均は 168〜180（${avg.toFixed(1)}）`);
  const wts = ps.map((p) => YA.weightOf(p));
  ok(wts.every((x) => x >= 40 && x <= 110), '体重は 40〜110kg');
  const solid = ps.filter((p) => p.body === 'solid'), slim = ps.filter((p) => p.body === 'slim');
  ok(solid.length > 5 && slim.length > 5, `体型がばらける（がっしり${solid.length}・細身${slim.length}）`);
  ok(solid.reduce((s, p) => s + p.ab['強さ'], 0) / solid.length > slim.reduce((s, p) => s + p.ab['強さ'], 0) / slim.length, 'がっしりの子は細身の子より強さが高い');
  // 早生まれは晩成が多い
  const eb = ps.filter((p) => YA.isEarlyBorn(p));
  const lateShare = (xs) => xs.filter((p) => p.gt === 'late').length / Math.max(1, xs.length);
  ok(eb.length > 10 && lateShare(eb) > lateShare(ps.filter((p) => !YA.isEarlyBorn(p))), `早生まれは晩成が多い（${(lateShare(eb) * 100).toFixed(0)}%）`);
  ok(new Set(ps.map((p) => p.gt)).size === 3, '成長の型が3つとも出る');
  // 年齢：高1の4月は15歳、3月は16歳
  const w0 = ws[0];
  const p1 = Object.values(w0.players).find((p) => p.grade === 1);
  ok(YA.ageOf({ week: 1 }, Object.assign({}, p1, { bday: { m: 5, d: 20 } })) === 15 && YA.ageOf({ week: 39 }, Object.assign({}, p1, { bday: { m: 5, d: 20 } })) === 16, '高1は4月に15歳、年度末に16歳');
  ok(YA.ageOf({ week: 30 }, Object.assign({}, p1, { bday: { m: 3, d: 10 } })) === 15, '早生まれは1月でもまだ15歳');
  // 出身：遠い子は寮
  ok(ps.filter((p) => p.far).every((p) => p.dorm === true), '遠くから来た子は寮生');
  ok(new Set(ps.map((p) => p.born)).size >= 20, '出身地がばらける');
  // 隠れた能力：性格で傾く
  const hidAvg = (xs, k) => xs.reduce((s, p) => s + p.hid[k], 0) / Math.max(1, xs.length);
  const big = ps.filter((p) => p.pers['大舞台'] === '大舞台に強い'), weak = ps.filter((p) => p.pers['大舞台'] === 'プレッシャーに弱い');
  ok(big.length && weak.length && hidAvg(big, '大一番の強さ') > hidAvg(weak, '大一番の強さ') + 5, '大舞台に強い子は大一番の強さが高い');
  ok(ps.every((p) => YA.HID.every((k) => p.hid[k] >= 1 && p.hid[k] <= 20)), '隠れた能力は 1〜20');
  // 効き目の向き
  const q = Object.assign({}, p1, { hid: Object.assign({}, p1.hid, { 怪我のしにくさ: 20, 適応力: 20, プロ意識: 20 }) });
  const r = Object.assign({}, p1, { hid: Object.assign({}, p1.hid, { 怪我のしにくさ: 1, 適応力: 1, プロ意識: 1 }) });
  ok(YA.injK(q) < 0.7 && YA.injK(r) > 1.3, '怪我のしにくさで怪我のおそれが変わる');
  ok(YA.adaptK(q) > YA.adaptK(r), '適応力で慣れる速さが変わる');
  ok(YA.growK(q) > YA.growK(r), 'プロ意識で伸びが変わる');
  ok(YA.growK(Object.assign({}, q, { gt: 'early', grade: 1 })) > YA.growK(Object.assign({}, q, { gt: 'late', grade: 1 })) && YA.growK(Object.assign({}, q, { gt: 'late', grade: 3 })) > YA.growK(Object.assign({}, q, { gt: 'early', grade: 3 })), '早熟は高1で、晩成は高3で伸びる');
  ok(YA.isBigWeek(15) && YA.isBigWeek(31) && !YA.isBigWeek(5), '大一番の週（夏の決勝・プレーオフ）');
  // GK の伸びしろ：能力1つあたりの伸びしろがフィールドと同じくらい
  const per = (xs) => xs.reduce((s, p) => s + (p.pot - YA.abSum(p)) / (p.pos === 'GK' ? YA.AB_GK : YA.AB_FIELD).length, 0) / Math.max(1, xs.length);
  const gk = ps.filter((p) => p.pos === 'GK'), fd = ps.filter((p) => p.pos !== 'GK');
  ok(per(gk) < per(fd) * 1.5, `GK の伸びしろは能力1つあたりでフィールドと同じ物差し（GK ${per(gk).toFixed(1)}・FP ${per(fd).toFixed(1)}）`);
  ok(gk.every((p) => YA.futurePoint(p) <= 200), 'GK の将来は200まで');
  // 古い保存：bd の無い子に足す。いまの背は変えない・GK の伸びしろを直す
  const old = JSON.parse(JSON.stringify(ws[1]));
  for (const p of Object.values(old.players)) { const h0 = p.height; delete p.bd; delete p.bday; delete p.gt; delete p.hid; delete p.born; delete p.potFix; p._h0 = h0; if (p.pos === 'GK') p.pot = YA.abSum(p) + 150; }
  YA.ensureBody(old);
  ok(Object.values(old.players).every((p) => p.bd && p.hid && p.born && p.height === p._h0), '古い保存の子にも足す（背は変えない）');
  ok(Object.values(old.players).filter((p) => p.pos === 'GK').every((p) => p.pot - YA.abSum(p) < 60), '古い保存の GK の伸びしろを直す');
  // 1年進めると背が伸びる・卒業生に引き継ぐ
  const w = YA.newWorld(77);
  const hStart = {};
  for (const p of Object.values(w.players)) hStart[p.id] = p.height;
  YA.simulate(w, { until: 'year', stopOnImportant: false });
  const grads = (w.alumni || []).filter((a) => a.year === 1 && a.status !== 'left');
  ok(grads.length && grads.every((a) => a.height && a.born && a.gt && a.hid), '卒業生に身長・出身・成長の型・隠れた能力が残る');
  ok(grads.filter((a) => a.gt === 'late').every((a) => a.late), '晩成の卒業生は遅咲き扱い');
  const stay = Object.values(w.players).filter((p) => p.grade >= 2);
  const grew = stay.filter((p) => p.height > hStart[p.id]).length;
  ok(grew >= stay.length * 0.3, `1年で背が伸びた子がいる（${grew}/${stay.length}）`);
};
