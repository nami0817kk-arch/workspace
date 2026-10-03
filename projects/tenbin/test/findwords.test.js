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
