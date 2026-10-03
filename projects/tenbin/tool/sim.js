// 自動で積んで、何匹積めるかと物理の破綻（めり込み・はじけ）を見る
// node tool/sim.js [回数] [rand|center]
var path = require('path');
process.env.NODE_PATH = path.join(__dirname, '../node_modules');
require('module').Module._initPaths();
var C = require('../prototype/core.js');
var N = +process.argv[2] || 20, mode = process.argv[3] || 'center';
var scores = [], maxSpeed = 0, steps = 0, why = {};
// 上手な人の代わり: いちばん平たくなる向きで、傾きを打ち消す側へ置く
function smart(s) {
  var kind = C.current(s), best = null;
  for (var i = 0; i < 8; i++) { var a = i * C.ROT_STEP, e = C.extent(kind, a), h = e.maxY - e.minY;
    if (!best || h < best.h - 0.5) best = { ang: a, h: h, e: e }; }
  var m = 0, mx = 0; s.cargo.forEach(function (b) { m += b.mass; mx += b.mass * (b.position.x - C.W / 2); });
  var o = C.OFFSET[kind], ox = o.x * Math.cos(best.ang) - o.y * Math.sin(best.ang);
  var want = m ? -mx / m * 0.6 : 0;
  return { ang: best.ang, x: C.W / 2 + Math.max(-60, Math.min(60, want)) - ox };
}
for (var run = 0; run < N; run++) {
  var s = C.create(run + 1), r = mulberry(run + 7);
  while (!s.failed && s.score < 60 && s.t < 60 * 60 * 10) {
    if (C.canDrop(s) && !s.pendingScore) {
      var ang, x;
      if (mode === 'smart') { var pk = smart(s); ang = pk.ang; x = pk.x; }
      else {
        ang = Math.round(r() * 7) * C.ROT_STEP * (mode === 'center' ? 0 : 1);
        x = mode === 'center' ? C.W / 2 + (r() - 0.5) * 40 : C.W / 2 + (r() - 0.5) * 200;
      }
      C.drop(s, x, ang);
    }
    C.step(s); steps++;
    s.cargo.forEach(function (b) { if (b.speed > maxSpeed) maxSpeed = b.speed; });
  }
  var wk = (s.failed || 'none') + (s.failedBody ? ':' + s.failedBody.kind : ''); why[wk] = (why[wk] || 0) + 1;
  scores.push(s.score + (s.failed ? '' : '+'));
}
console.log(mode, 'scores', scores.join(' '), 'maxSpeed', maxSpeed.toFixed(1), 'steps', steps, JSON.stringify(why));
function mulberry(a) { return function () { a |= 0; a = a + 0x6D2B79F5 | 0; var t = Math.imul(a ^ a >>> 15, 1 | a); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }
