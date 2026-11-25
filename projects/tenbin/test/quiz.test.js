// おさらい（ことば帳の小テスト）の問題の作り方: index.html の quizRound を取り出して動かす
var assert = require('assert'), fs = require('fs'), path = require('path');
var W = require('../prototype/words.js'), M = require('../prototype/meanings.js');
var all = W.short.concat(W.middle, W.long);
var html = fs.readFileSync(path.join(__dirname, '../prototype/index.html'), 'utf8');
var a = html.indexOf('function quizRound('), b = html.indexOf('window.__quizRound');
assert.ok(a > 0 && b > a, 'quizRound が見つからない');
var quizRound = new Function(html.slice(a, b) + 'return quizRound;')();
function mean(w) { return M[w] ? M[w][1] : ''; }
function rngOf(seed) { return function () { seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648; }; }

for (var seed = 1; seed <= 30; seed++) {
  var rng = rngOf(seed), got = all.filter(function () { return rng() < 0.01; }).concat(['ねこ', 'いぬ', 'とり', 'うみ']);
  var qs = quizRound(got, all, mean, rng, 10);
  assert.strictEqual(qs.length, Math.min(10, got.length), '問題の数');
  var seen = {};
  qs.forEach(function (q) {
    assert.ok(got.indexOf(q.word) >= 0, '集めていないことばが出た: ' + q.word);
    assert.ok(!seen[q.word], '同じことばが2度出た: ' + q.word); seen[q.word] = 1;
    assert.strictEqual(q.meaning, mean(q.word));
    assert.strictEqual(q.choices.length, 3, '選択肢は3つ');
    assert.strictEqual(q.choices.filter(function (c) { return c === q.word; }).length, 1, '正解がちょうど1つ');
    assert.strictEqual(new Set(q.choices).size, 3, '選択肢が重なっている');
    q.choices.forEach(function (c) {
      assert.strictEqual(c.length, q.word.length, '字数がそろっていない: ' + q.word + ' / ' + c);
      if (c !== q.word) assert.notStrictEqual(mean(c), q.meaning, '同じ意味のまちがいの選択肢: ' + c);
    });
  });
}
// 集めたことばが少なくても（4語）、まちがいの選択肢は全部のことばから補える
var few = quizRound(['ねこ', 'いぬ', 'さくら', 'がっこう'], all, mean, rngOf(7), 10);
assert.strictEqual(few.length, 4);
// 正解の位置が偏らない（いつも1つめ、にならない）
var pos = [0, 0, 0], r = rngOf(3);
for (var k = 0; k < 300; k++) { var q = quizRound(['ねこ'], all, mean, r, 1)[0]; pos[q.choices.indexOf('ねこ')]++; }
assert.ok(pos.every(function (n) { return n > 60; }), '正解の位置が偏っている: ' + pos);
// 画面: ことば帳に おさらい のボタン、4語に足りないときは押せない
assert.ok(/id="quiz"/.test(html) && /QUIZ_MIN = 4/.test(html), 'ことば帳に おさらい が無い');
// 落ちてくる字の読み上げ: 落としたあと・始めたときに次の字を読む。ことばを読んでいる間は読まない
assert.ok(/speakKana\(C\.current\(s\)\)/.test(html), '落ちてくる字を読んでいない');
assert.ok(/synth\.speaking \|\| synth\.pending\) return/.test(html), '字の読み上げがことばの読み上げを邪魔する');
console.log('quiz ok');
