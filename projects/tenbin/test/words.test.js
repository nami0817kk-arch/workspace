// ことばの一覧が、ゲームにある字（清音46字）だけで書けていて、段ごとの字数が合っているか
var assert = require('assert');
var W = require('../prototype/words.js'), G = require('../prototype/glyphs.js');
var ok = new Set(Object.keys(G.chars)), seen = new Set();
[['short', 2, 2], ['middle', 3, 3], ['long', 4, 6]].forEach(function (t) {
  W[t[0]].forEach(function (w) {
    assert.ok(typeof w === 'string' && w.length >= t[1] && w.length <= t[2], t[0] + ' の字数が合わない: ' + w);
    for (var ch of w) assert.ok(ok.has(ch), '使えない字が入っている: ' + w + '（' + ch + '）');
    assert.ok(!seen.has(w), '重複: ' + w); seen.add(w);
  });
});
console.log('words ok', W.short.length, W.middle.length, W.long.length);
