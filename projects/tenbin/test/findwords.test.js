// くっついた字でことばができるか: 「ね」を上、「こ」を下に積めば縦の「ねこ」、並べれば横の「ねこ」。
// 逆の順（こ→ね）や、離れて置いた字ではできない
var assert = require('assert'), C = require('../prototype/core.js');
function settle(s) { for (var i = 0; i < 400; i++) C.step(s); }
function place(s, ch, x, y) { var b = C.build(ch, x, y, 0); s.cargo.push(b); C.M.Composite.add(s.engine.world, b); return b; }
function words(s) { settle(s); return C.findWords(s).map(function (f) { return f.text + ':' + f.dir; }); }

var s = C.create(1, 'flat'); place(s, 'こ', 200, 505); place(s, 'ね', 200, 430);
assert.ok(words(s).indexOf('ねこ:tate') >= 0, '縦の ねこ ができない: ' + words(s));

s = C.create(1, 'flat'); var a = C.extent('ね', 0), b = C.extent('こ', 0); place(s, 'ね', 166, 505); place(s, 'こ', 166 + a.maxX - b.minX + 3, 505);
assert.ok(words(s).indexOf('ねこ:yoko') >= 0, '横の ねこ ができない: ' + words(s));

s = C.create(1, 'flat'); var a2 = C.extent('こ', 0), b2 = C.extent('ね', 0); place(s, 'こ', 166, 505); place(s, 'ね', 166 + a2.maxX - b2.minX + 3, 505);
assert.ok(words(s).indexOf('ねこ:yoko') < 0, '右から左に読んで ねこ になってしまう');

s = C.create(1, 'flat'); place(s, 'ね', 110, 505); place(s, 'こ', 290, 505);
assert.deepStrictEqual(words(s), [], '離れた字で ことば ができてしまう');
console.log('findWords ok');

// 点: 字10点、ことばは (字数-1)^2×100
assert.deepStrictEqual(['ねこ', 'さくら', 'ひまわり', 'かたつむり'].map(C.wordPoints), [100, 400, 900, 1600]);
// 実際に積んで「ねこ」ができたら、字2つ(20)＋ことば(100)＝120点
s = C.create(1, 'flat'); s.queue[0] = 'こ'; s.queue[1] = 'ね';
C.drop(s, 200, 0); for (var i = 0; i < 400; i++) C.step(s);
C.drop(s, 200, 0); for (i = 0; i < 400; i++) C.step(s);
assert.ok(s.made.indexOf('ねこ') >= 0, '積んだ ねこ ができない: ' + s.made);
assert.strictEqual(s.points, 120);
console.log('points ok');

// 長いことばの一部は数えない: 縦に あ・さ・ひ と積むと「あさひ」だけ（「あさ」は数えない）
s = C.create(1, 'flat'); s.queue.splice(0, 3, 'ひ', 'さ', 'あ');
for (var n = 0; n < 3; n++) { C.drop(s, 200, 0); for (i = 0; i < 400; i++) C.step(s); }
assert.ok(s.made.indexOf('あさひ') >= 0, 'あさひ ができない: ' + s.made);
assert.ok(s.made.indexOf('あさ') < 0, 'あさひ の一部の あさ まで数えている: ' + s.made);
assert.strictEqual(s.points, 30 + 400);
console.log('subword ok');
// そのあと、離れた所に字を置いても「あさ」を数え直さない
s.queue[0] = 'ろ'; C.drop(s, 90, 0); for (i = 0; i < 400; i++) C.step(s);
assert.ok(s.made.indexOf('あさ') < 0, 'あとから あさ を数え直している: ' + s.made);
console.log('subword later ok');
