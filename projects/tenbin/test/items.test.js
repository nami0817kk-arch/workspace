// アイテム: のり・いた・とりけし・こおり。アイテムなしでは使えない
var assert = require('assert'), C = require('../prototype/core.js');
function run(s, n) { for (var i = 0; i < n; i++) { C.step(s); s.events.length = 0; } }
var s = C.create(1, 'flat');
assert.strictEqual(C.useItem(s, 'glue'), false, 'アイテムなしで使えてしまう');
s = C.create(1, 'flat', { items: true });
assert.deepStrictEqual([s.items.glue, s.items.undo], [1, 1], 'はじめの手持ちが違う');
// とりけし: 最後の字を取り除く
C.drop(s, 200, 0); run(s, 300); var n = s.cargo.length;
assert.ok(C.useItem(s, 'undo')); assert.strictEqual(s.cargo.length, n - 1);
assert.strictEqual(C.useItem(s, 'undo'), false, '持っていないのに使えた');
// のり: 板の端からはみ出して置いても、くっついて落ちない
C.drop(s, 200, 0); run(s, 300);
assert.ok(C.useItem(s, 'glue'));
var g = C.drop(s, 200, 0); run(s, 400);
assert.ok(C.M.Composite.allConstraints(s.engine.world).some(function (c) { return c.label === 'weld' && (c.bodyA === g || c.bodyB === g); }), 'のりでくっつかない');
// いた: 次に板が来て、字としては数えない
s.items.board = 1; var sc = s.score; assert.ok(C.useItem(s, 'board')); assert.strictEqual(C.current(s), C.BOARD);
C.drop(s, 200, 0); run(s, 300); assert.strictEqual(s.score, sc, '板を字として数えた');
// こおり: 触れ合う字と台がつながる
s.items.freeze = 1; assert.ok(C.useItem(s, 'freeze'));
var welds = C.M.Composite.allConstraints(s.engine.world).filter(function (c) { return c.label === 'weld'; }).length;
assert.ok(welds >= 4, 'こおりで固まらない: ' + welds);
run(s, 300); assert.ok(!s.failed, '固めたあと崩れた');
// 字を8つ積むとアイテムが1つ増える
s = C.create(2, 'flat', { items: true }); var before = Object.keys(s.items).reduce(function (t, k) { return t + s.items[k]; }, 0), got = 0;
for (var t = 0; t < 30000 && s.placed < 8 && !s.failed; t++) { if (C.canDrop(s) && !s.pendingScore) C.drop(s, 200 + ((t * 37) % 60 - 30), 0); C.step(s); s.events.forEach(function (e) { if (e.type === 'item') got++; }); s.events.length = 0; }
assert.ok(s.failed || got >= 1, '8字積んでもアイテムが増えない');
console.log('items ok');

// 2026-10-04「アイテム使用時の運動力学がおかしいときがある」の見直し
// のり: ぶつかった勢いのままつながず、落ち着いてからくっつく。くっつけたときに字がはじけない
var maxSp = 0;
s = C.create(5, 'sway', { items: true });
for (t = 0; t < 30000 && s.placed < 10 && !s.failed; t++) {
  if (C.canDrop(s) && !s.pendingScore) { s.items.glue = 1; C.useItem(s, 'glue'); C.drop(s, 200 + ((t * 37) % 100 - 50), 0); }
  C.step(s); s.events.length = 0;
  s.cargo.forEach(function (b) { if (b.landed && b.speed > maxSp) maxSp = b.speed; });
}
assert.ok(maxSp < 13, 'のりで字がはじけた（速さ ' + maxSp.toFixed(1) + '）');
// くっついた字どうしは同じかたまり（互いにぶつからない）
var grouped = s.cargo.filter(function (b) { return b.weldGroup; }).length;
assert.ok(grouped >= 2, 'のりでくっついた字が かたまりになっていない: ' + grouped);
// つづける・とりけし で取り除いた字の拘束が残らない（残ると、ほかの字が空中に引っぱられて止まる）
s = C.create(3, 'flat', { items: true });
for (t = 0; t < 30000 && !s.failed; t++) {
  if (C.canDrop(s) && !s.pendingScore) { if (s.placed % 3 === 2) { s.items.freeze = 1; C.useItem(s, 'freeze'); } C.drop(s, 200 + ((t * 53) % 300 - 150), 0); }
  C.step(s); s.events.length = 0;
}
for (t = 0; t < 55; t++) C.physics(s);
C.revive(s);
var ghosts = C.M.Composite.allConstraints(s.engine.world).filter(function (c) {
  return c.label === 'weld' && [c.bodyA, c.bodyB].some(function (b) { return s.cargo.indexOf(b) < 0 && s.boards.indexOf(b) < 0; });
}).length;
assert.strictEqual(ghosts, 0, '消えた字につながったままの拘束が残っている: ' + ghosts);
console.log('item physics ok (のりの最大の速さ ' + maxSp.toFixed(1) + ')');
