// 報酬広告の「つづける」: 落ちた字を取り除き、点はそのまま、1回だけ
var assert = require('assert'), C = require('../prototype/core.js');
var s = C.create(3, 'flat');
for (var t = 0; t < 20000 && !s.failed; t++) { if (C.canDrop(s) && !s.pendingScore) C.drop(s, 200 + ((t * 53) % 300 - 150), 0); C.step(s); s.events.length = 0; }
assert.ok(s.failed, '崩れなかった');
var pts = s.points, n = s.cargo.length, fb = s.failedBody;
assert.strictEqual(C.revive(s), true);
assert.ok(!s.failed && s.cargo.indexOf(fb) < 0 && s.cargo.length < n, '落ちた字が残っている');
assert.strictEqual(s.points, pts, '点が変わった');
for (t = 0; t < 300; t++) { C.step(s); s.events.length = 0; }
assert.ok(!s.failed, 'つづけた直後にまた失敗した');
assert.ok(C.canDrop(s), 'つづけたあと落とせない');
s.failed = 'fall'; assert.strictEqual(C.revive(s), false, '2回つづけられてしまう');
// てんびん: 床に着いたあとでも、板が戻って続けられる
s = C.create(4, 'seesaw');
// 左端に重い字を4つ置いて、わざと板を床に着ける
['ぬ', 'め', 'ほ', 'ね'].forEach(function (ch, i) { var b = C.build(ch, 60, 500 - i * 75, 0); s.cargo.push(b); s.last = b; C.M.Composite.add(s.engine.world, b); });
for (t = 0; t < 600 && !s.failed; t++) { C.step(s); s.events.length = 0; }
assert.ok(s.failed, 'てんびんが崩れない');
C.revive(s); for (t = 0; t < 200; t++) { C.step(s); s.events.length = 0; }
assert.ok(!s.failed, 'つづけたあと、てんびんがすぐまた失敗する: ' + s.failed);
console.log('revive ok');
