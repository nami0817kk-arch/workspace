// このまま落としたらできそうなことば（previewWords）: 「ね」の真上に「こ」を持てば ねこ、離れた所では何も出ない
var assert = require('assert'), C = require('../prototype/core.js');
function settle(s) { for (var i = 0; i < 400; i++) C.step(s); }
function place(s, ch, x, y) { var b = C.build(ch, x, y, 0); s.cargo.push(b); C.M.Composite.add(s.engine.world, b); return b; }
var s = C.create(1, 'flat'); place(s, 'ね', 200, 505); settle(s);
assert.ok(C.previewWords(s, 'こ', 0, 200).indexOf('ねこ') >= 0, '真上で ねこ が出ない: ' + C.previewWords(s, 'こ', 0, 200));
assert.deepStrictEqual(C.previewWords(s, 'こ', 0, 60), [], '離れた所でも ことば が出る');
assert.deepStrictEqual(C.previewWords(s, C.BOARD, 0, 200), [], '板でことばが出る');
// 仮の字は残さない
assert.strictEqual(s.cargo.length, 1); assert.strictEqual(C.M.Composite.allBodies(s.engine.world).length, 3);
// 長いことばの一部は出さない: 下から あ・さ と積んで ひ を持つと あさひ（さひ・あさ は出さない）
s = C.create(1, 'flat'); s.queue.splice(0, 2, 'あ', 'さ');
for (var n = 0; n < 2; n++) { C.drop(s, 200, 0); settle(s); }
var pv = C.previewWords(s, 'ひ', 0, 200);
assert.ok(pv.indexOf('あさひ') >= 0, 'あさひ が出ない: ' + pv);
assert.ok(pv.indexOf('あさ') < 0, 'すでにできた あさ が出る: ' + pv);
// 台の外（落ちる所）では何も出ない
assert.deepStrictEqual(C.previewWords(s, 'ひ', 0, 5), []);
console.log('preview ok');
