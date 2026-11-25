// 字の来かた: 同じ種（seed）なら同じ順に来る（記録の再現・不具合の再現に要る）。同じ字は続けて来ない。字は74字のどれか
var assert = require('assert'), C = require('../prototype/core.js');
var a = C.create(7, 'flat'), b = C.create(7, 'flat');
assert.deepStrictEqual(a.queue, b.queue, '同じ種で順が違う');
assert.notDeepStrictEqual(C.create(8, 'flat').queue, a.queue, '種を変えても同じ順');
// 落として補充していっても、同じ字が続かない
// （2026-10-05 の見直しで、混ぜてから入れ替える形では続くことがあったのを見つけた）
var seen, all = {};
for (var seed = 1; seed <= 20; seed++) {
  var s = C.create(seed, 'flat'); seen = [];
  for (var i = 0; i < 300; i++) { seen.push(C.current(s)); all[C.current(s)] = 1; C.drop(s, 200, 0); s.cargo.forEach(function (x) { C.M.Composite.remove(s.engine.world, x); }); s.cargo.length = 0; s.lastDropT = -999; }
  for (i = 1; i < seen.length; i++) assert.notStrictEqual(seen[i], seen[i - 1], '種' + seed + ' の ' + i + '字目で同じ字が続いた: ' + seen[i]);
}
seen.forEach(function (k) { assert.ok(C.KINDS.indexOf(k) >= 0, '知らない字: ' + k); });
// 74字のうち、ほとんどの字が来る（偏りすぎない）。濁点・小さい字も来る
var kinds = {}; seen.forEach(function (k) { kinds[k] = 1; });
assert.ok(Object.keys(kinds).length >= 50, '来る字が偏っている: ' + Object.keys(kinds).length + '種');
// 20種×300字では、74字が全部来る（ことばの少ない ぴ・ぷ・ぺ も。2026-11-25）
var never = C.KINDS.filter(function (k) { return !all[k]; });
assert.deepStrictEqual(never, [], '一度も来ない字: ' + never.join(''));
console.log('queue ok');
