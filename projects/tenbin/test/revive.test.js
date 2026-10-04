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

// てんびんでつづけても、台が空にならない（軽い側の字を取って偏りが増え、全部消していた: 2026-10-04 の見直しで発見）
var empties = 0, kept = 0, runs = 0;
for (var r = 1; r <= 20; r++) {
  s = C.create(r, 'seesaw');
  for (t = 0; t < 20000 && !s.failed; t++) { if (C.canDrop(s) && !s.pendingScore) C.drop(s, 200 + ((t * 53) % 260 - 130), 0); C.step(s); s.events.length = 0; }
  if (!s.failed || s.cargo.length < 4) continue;
  runs++; for (var k = 0; k < 55; k++) C.physics(s);
  C.revive(s); kept += s.cargo.length; if (!s.cargo.length) empties++;
}
assert.ok(runs >= 5, '試せた回数が少ない: ' + runs);
assert.strictEqual(empties, 0, 'つづけたら台が空になった回: ' + empties + '/' + runs);
// つづけた直後の待ちの間は落とせない（落としても数えられないまま次を落とせていた）
s = C.create(3, 'flat');
for (t = 0; t < 20000 && !s.failed; t++) { if (C.canDrop(s) && !s.pendingScore) C.drop(s, 200 + ((t * 53) % 300 - 150), 0); C.step(s); s.events.length = 0; }
C.revive(s);
assert.ok(!C.canDrop(s), 'つづけた直後に落とせてしまう');
var before = s.score; for (t = 0; t < 100; t++) { C.step(s); s.events.length = 0; }
assert.ok(C.canDrop(s), '待ちのあとに落とせない');
C.drop(s, 200, 0); for (t = 0; t < 300; t++) { C.step(s); s.events.length = 0; }
assert.strictEqual(s.score, before + 1, 'つづけたあと落とした字が数えられない');
console.log('revive keeps letters ok (平均 ' + (kept / runs).toFixed(1) + ' 字のこる)');
