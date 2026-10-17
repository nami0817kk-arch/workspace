// つり合いを測る: ことばを狙う人の代わり（落とす前の「できそうなことば」を見て置く）に遊ばせ、
// 1回の遊びの 点・字数・ことばの数・点の内訳（字／ことば）・ことばの長さ・アイテムを数える。
// node tool/balance.js [回数] [台]   例: node tool/balance.js 10 flat   （ITEMS=0 でアイテムなし）
var path = require('path');
process.env.NODE_PATH = path.join(__dirname, '../node_modules');
require('module').Module._initPaths();
var C = require('../prototype/core.js');
var N = +process.argv[2] || 10, PLAT = process.argv[3] || 'flat', ITEMS = process.env.ITEMS !== '0', CAP = +(process.env.CAP || 80);
function flatAng(kind) { var best = null; for (var i = 0; i < 8; i++) { var a = i * C.ROT_STEP, e = C.extent(kind, a), h = e.maxY - e.minY; if (!best || h < best.h - 0.5) best = { a: a, h: h }; } return best.a; }
function choose(s) {
  var kind = C.current(s), fa = flatAng(kind), m = 0, mx = 0;
  s.cargo.forEach(function (b) { m += b.mass; mx += b.mass * (b.position.x - C.W / 2); });
  var center = C.W / 2 + (m ? Math.max(-60, Math.min(60, -mx / m * 0.6)) : 0), best = null;
  [0, fa].forEach(function (a) {
    for (var dx = -90; dx <= 90; dx += 22) {
      var x = center + dx, w = C.previewWords(s, kind, a, x), len = w.reduce(function (t, x) { return Math.max(t, x.length); }, 0);
      var sc = len * 10 + w.length * 3 - Math.abs(dx) / 30 - (a === fa ? 0 : 1);
      if (!best || sc > best.sc) best = { sc: sc, a: a, x: x };
    }
  });
  return best;
}
var rows = [];
for (var run = 0; run < N; run++) {
  var s = C.create(run + 101, PLAT, { items: ITEMS }), got = 0, used = 0, byLen = {}, wordPts = 0, t0 = Date.now();
  while (!s.failed && s.placed < CAP && s.t < 60 * 60 * 15) {
    if (C.canDrop(s) && !s.pendingScore) {
      if (ITEMS && s.items.freeze > 0 && s.cargo.length >= 5 && s.placed % 5 === 0) { if (C.useItem(s, 'freeze')) used++; }
      var c = choose(s); C.drop(s, c.x, c.a);
    }
    C.step(s);
    s.events.forEach(function (e) {
      if (e.type === 'item') got++;
      if (e.type === 'word') { byLen[e.text.length] = (byLen[e.text.length] || 0) + 1; wordPts += e.pts; }
    });
    s.events.length = 0;
  }
  rows.push({ pts: s.points, letters: s.placed, words: s.made.length, wordPts: wordPts, byLen: byLen, items: got, used: used, end: s.failed || 'cap', sec: s.t / 60 });
}
function avg(f) { return rows.reduce(function (t, r) { return t + f(r); }, 0) / rows.length; }
var lens = {}; rows.forEach(function (r) { for (var k in r.byLen) lens[k] = (lens[k] || 0) + r.byLen[k]; });
console.log(PLAT + (ITEMS ? '+items' : ''), 'n=' + N,
  '点', Math.round(avg(function (r) { return r.pts; })), '字', avg(function (r) { return r.letters; }).toFixed(1),
  'ことば', avg(function (r) { return r.words; }).toFixed(1), 'ことばの点の割合', (100 * avg(function (r) { return r.wordPts / Math.max(1, r.pts); })).toFixed(0) + '%',
  '長さ', JSON.stringify(lens), 'もらったアイテム', avg(function (r) { return r.items; }).toFixed(1), '遊んだ時間(秒)', avg(function (r) { return r.sec; }).toFixed(0),
  '終わり', JSON.stringify(rows.reduce(function (o, r) { o[r.end] = (o[r.end] || 0) + 1; return o; }, {})));
