// 選手を構成する要素 段階6（stars2.js）：信頼で開くもの・働きかけ12・日誌・課題中の子どうしの関係（2026-11-26 から★の子＝課題中の子）
'use strict';
module.exports = (YA, ok) => {
  const w = YA.newWorld(1401);
  const g1 = Object.values(w.players).filter((p) => p.grade === 1);
  const a = g1.find((p) => p.pos !== 'GK'), b = g1.find((p) => p !== a && p.pos !== 'GK' && YA.GROUP[p.main] === YA.GROUP[a.main]) || g1.find((p) => p !== a && p.pos !== 'GK');
  ok(YA.kadaiGive(w, a, a.kf.t, a.kf.c).ok && YA.kadaiGive(w, b, b.kf.t, b.kf.c).ok && a.star && b.star, '課題を出すと課題中の子になる');
  a.kd.fit = b.kd.fit = 'half'; // この点検のあいだは覚醒させずに課題中のまま（日誌・信頼を見る）
  ok(YA.STAR_ACTS.length === 12 && new Set(YA.STAR_ACTS.map((d) => d.k)).size === 12, '働きかけは12');
  a.tr = 30; // 信頼2
  ok(/信頼が/.test(YA.starActWhy(w, a, 'book') || ''), '信頼が足りない働きかけは理由つきで押せない');
  a.tr = 65; // 信頼4
  w.saUsed = null; a.sa = {};
  for (const k of ['menu', 'family', 'book']) { w.saUsed = null; const r = YA.starAct(w, a, k); ok(r.ok && r.msg && r.line, '働きかけ ' + k); }
  w.saUsed = null;
  a.fat = 60;
  const f0 = a.fat;
  ok(YA.starAct(w, a, 'rest').ok && a.fat <= f0 - 19, '休ませて話を聞くと疲れが抜ける');
  w.saUsed = null;
  const r = YA.starAct(w, a, 'pos');
  ok(r.ok && /立たせてみた/.test(r.msg), '別の位置を試させる');
  // 関係
  const rels = YA.starRels(w, a);
  ok(rels.some((x) => x.q === b), '課題中の子どうしの関係が分かる（' + rels.map((x) => YA.STAR_REL[x.k]).join('・') + '）');
  // 日誌・信頼で開くもの
  // 4週進める（前は until: 'month' で、simulate に無い区切りのため5年分回っていた）
  for (let i = 0; i < 4; i++) YA.simulate(w, { until: 'week', stopOnImportant: false });
  ok(a.star && a.kd, '4週たっても課題中（課題は8週以上）');
  ok((a.diary || []).length >= 2 && a.diary.every((e) => e.t && e.t.length >= 3), '課題中の子の日誌が毎週たまる');
  ok(YA.trustOpen(a, 'diary') && !YA.trustOpen(Object.assign({}, a, { tr: 10 }), 'diary'), '日誌は信頼2から');
  const hw = YA.hidWords(w, Object.assign({}, a, { tr: 70 }));
  ok(hw.length === 5, '信頼4で隠れた力が全部言葉で分かる');
  ok(YA.hidWords(w, Object.assign({}, a, { tr: 30 })).length <= 5, '信頼が低いときは目立つものだけ');
};
