// くっついた字でことばができるか: 「ね」を上、「こ」を下に積めば縦の「ねこ」、並べれば横の「ねこ」。
// 逆の順（こ→ね）や、離れて置いた字ではできない
var assert = require('assert'), C = require('../prototype/core.js');
function settle(s) { for (var i = 0; i < 400; i++) C.step(s); }
function place(s, ch, x, y) { var b = C.build(ch, x, y, 0); s.cargo.push(b); C.M.Composite.add(s.engine.world, b); return b; }
function words(s) { settle(s); return C.findWords(s).map(function (f) { return f.text; }); }

var s = C.create(1, 'flat'); place(s, 'こ', 200, 505); place(s, 'ね', 200, 430);
assert.ok(words(s).indexOf('ねこ') >= 0, '縦の ねこ ができない: ' + words(s));

s = C.create(1, 'flat'); var a = C.extent('ね', 0), b = C.extent('こ', 0); place(s, 'ね', 166, 505); place(s, 'こ', 166 + a.maxX - b.minX + 3, 505);
assert.ok(words(s).indexOf('ねこ') >= 0, '横の ねこ ができない: ' + words(s));

s = C.create(1, 'flat'); var a2 = C.extent('こ', 0), b2 = C.extent('ね', 0); place(s, 'こ', 166, 505); place(s, 'ね', 166 + a2.maxX - b2.minX - 6, 505);
// 向きは問わない: 右から左（こ・ね の並び）でも ねこ
assert.ok(words(s).indexOf('ねこ') >= 0, '右から左の ねこ ができない: ' + words(s));

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

// 下から上（こ が上・ね が下）でも ねこ
s = C.create(1, 'flat'); place(s, 'ね', 200, 505); place(s, 'こ', 200, 430);
assert.ok(words(s).indexOf('ねこ') >= 0, '下から上の ねこ ができない: ' + words(s));
// 間に別の字が挟まると、つながっていないので ねこ にならない
s = C.create(1, 'flat'); var e3 = C.extent('ね', 0), e4 = C.extent('ら', 0), e5 = C.extent('こ', 0);
var x2 = 100 + e3.maxX - e4.minX + 2, x3 = x2 + e4.maxX - e5.minX + 2;
place(s, 'ね', 100, 505); place(s, 'ら', x2, 505); place(s, 'こ', x3, 505);
assert.ok(words(s).indexOf('ねこ') < 0, '間に字が挟まっても ねこ になる: ' + words(s));

// 2026-10-04「言葉として反応しない時がある」の見直し
// 横に 8px あけて並べても くっついたとみなす（字の縁取りで、画面ではくっついて見える）
s = C.create(1, 'flat'); var e1 = C.extent('ね', 0), e2 = C.extent('こ', 0);
place(s, 'ね', 150, 505); place(s, 'こ', 150 + e1.maxX - e2.minX + 8, 505);
assert.ok(words(s).indexOf('ねこ') >= 0, '8px あけた横の ねこ ができない');
// 同じことばでも、別の字で作れば2度目も数える
s = C.create(1, 'flat'); s.queue.splice(0, 4, 'こ', 'ね', 'こ', 'ね');
C.drop(s, 120, 0); for (i = 0; i < 400; i++) C.step(s);
C.drop(s, 120, 0); for (i = 0; i < 400; i++) C.step(s);
C.drop(s, 290, 0); for (i = 0; i < 400; i++) C.step(s);
C.drop(s, 290, 0); for (i = 0; i < 400; i++) C.step(s);
assert.strictEqual(s.made.filter(function (w) { return w === 'ねこ'; }).length, 2, '2度目の ねこ を数えない: ' + s.made);
console.log('gap/repeat ok');
