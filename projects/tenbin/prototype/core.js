// てんびんタワー 物理コア。ブラウザと node で共用
// どうぶつタワーの積み方を、ばね付きのてんびんの上でやる。
// 動物は凸の部品を組んだでこぼこの形。重さは面積に比例（大きいほど重い）。
var TenbinCore = (function () {
  var M = (typeof Matter !== 'undefined') ? Matter : require('matter-js');
  var env = (typeof process !== 'undefined' && process.env) || {};
  var W = 400, GROUND = 600, PIVOT_Y = 556, PLANK_T = 14, PLANK_L = 300;
  var DT = 1000 / 60, SUB = 4, SDT = DT / SUB;
  var CAT_STATIC = 1, CAT_PLANK = 2, CAT_CARGO = 4;
  var DENSITY = 0.0015, ROT_STEP = Math.PI / 4;
  var FR = +(env.FR || 1.0), FRS = +(env.FRS || 2.0), ADAMP = +(env.AD || 0.97), GAP = +(env.GAP || 40);
  var K_SPRING = +(env.K || 1.5e-4), C_DAMP = +(env.CD || 0.007);

  // 部品: c=[x,y,r] 円 / r=[x,y,w,h,角度(度)] 角丸の四角 / p=[[x,y],...] 凸多角形（時計回りでも反時計回りでも可）
  // 座標は絵を描くときの原点から。y は下向き
  var ANIMALS = {
    bear: { name: 'くま', col: ['#a87449', '#e8c9a0'], parts: [
      { c: [0, 10, 22] }, { c: [0, -22, 16] }, { c: [-12, -34, 6] }, { c: [12, -34, 6] }] },
    giraffe: { name: 'きりん', col: ['#f2c14e', '#b9772f'], parts: [
      { r: [-6, 0, 52, 20] }, { r: [16, -28, 10, 40, 12] }, { r: [24, -50, 24, 12] },
      { r: [-26, 20, 6, 24] }, { r: [-14, 20, 6, 24] }, { r: [6, 20, 6, 24] }, { r: [16, 20, 6, 24] }] },
    elephant: { name: 'ぞう', col: ['#a9b3c2', '#c8d0db'], parts: [
      { r: [8, 0, 70, 42] }, { c: [-30, -10, 20] }, { r: [-44, 14, 9, 28, 10] },
      { r: [-14, 26, 14, 14] }, { r: [30, 26, 14, 14] }] },
    penguin: { name: 'ペンギン', col: ['#3a4250', '#f5f1ea'], parts: [
      { c: [0, -18, 14] }, { r: [0, 6, 30, 38] }, { p: [[-15, 0], [-22, 16], [-15, 18]] }, { p: [[15, 0], [22, 16], [15, 18]] }] },
    croc: { name: 'わに', col: ['#6aa36f', '#3e7a48'], parts: [
      { r: [0, 0, 84, 16] }, { p: [[42, -8], [66, -2], [66, 6], [42, 8]] }, { p: [[-42, -6], [-62, 4], [-42, 8]] },
      { r: [-26, 11, 8, 8] }, { r: [24, 11, 8, 8] }] },
    rabbit: { name: 'うさぎ', col: ['#f3eee8', '#f2b6c0'], parts: [
      { c: [0, 6, 17] }, { r: [-7, -20, 8, 28, -8] }, { r: [7, -20, 8, 28, 8] }] },
    cat: { name: 'ねこ', col: ['#f0a54a', '#fbe3c2'], parts: [
      { r: [0, -6, 56, 14] }, { r: [-24, 8, 8, 18] }, { r: [24, 8, 8, 18] }, { c: [30, -16, 11] }, { r: [-32, -16, 5, 18, -20] }] },
    pig: { name: 'ぶた', col: ['#f4b7b5', '#e48f8f'], parts: [
      { c: [0, 0, 22] }, { r: [-12, 22, 7, 8] }, { r: [12, 22, 7, 8] }] },
    sheep: { name: 'ひつじ', col: ['#f6f1e6', '#5a4a40'], parts: [
      { c: [-14, 0, 13] }, { c: [6, -6, 13] }, { c: [16, 6, 12] }, { c: [-2, 10, 12] }, { c: [-26, -8, 10] }] },
    turtle: { name: 'かめ', col: ['#7fae6a', '#4d7a3c'], parts: [
      { p: [[-28, 6], [-22, -8], [-10, -16], [10, -16], [22, -8], [28, 6]] }, { c: [34, 0, 7] }, { r: [-18, 10, 9, 8] }, { r: [18, 10, 9, 8] }] }
  };
  var KINDS = Object.keys(ANIMALS);

  function partBody(pt, x, y, opt) {
    if (pt.c) return M.Bodies.circle(x + pt.c[0], y + pt.c[1], pt.c[2], opt);
    if (pt.r) {
      var o = Object.assign({ chamfer: { radius: Math.min(5, Math.min(pt.r[2], pt.r[3]) * 0.3) } }, opt);
      var b = M.Bodies.rectangle(x + pt.r[0], y + pt.r[1], pt.r[2], pt.r[3], o);
      if (pt.r[4]) M.Body.rotate(b, pt.r[4] * Math.PI / 180);
      return b;
    }
    var vs = pt.p.map(function (q) { return { x: q[0], y: q[1] }; });
    var c = M.Vertices.centre(M.Vertices.clockwiseSort(vs.slice()));
    return M.Bodies.fromVertices(x + c.x, y + c.y, [vs], opt);
  }

  // 絵の原点から重心までのずれ（角度0のとき）。描くときに使う
  var OFFSET = {};
  KINDS.forEach(function (k) { var b = build(k, 0, 0, 0); OFFSET[k] = { x: b.position.x, y: b.position.y }; });

  // 絵の原点を (x,y) に置き、ang だけ回した体を作る
  function build(kind, x, y, ang) {
    var A = ANIMALS[kind];
    var filter = { category: CAT_CARGO, mask: CAT_CARGO | CAT_PLANK | CAT_STATIC, group: 0 };
    var parts = A.parts.map(function (pt) { return partBody(pt, 0, 0, { density: DENSITY, collisionFilter: filter }); });
    var b = M.Body.create({ parts: parts, friction: FR, frictionStatic: FRS, restitution: 0.02, collisionFilter: filter });
    M.Body.rotate(b, ang, { x: 0, y: 0 });
    M.Body.translate(b, { x: x, y: y });
    b.kind = kind;
    return b;
  }

  // 回したときの絵の原点からの上下左右のはみ出し
  var EXT = {};
  function extent(kind, ang) {
    var key = kind + ':' + ang.toFixed(4);
    if (!EXT[key]) { var b = build(kind, 0, 0, ang); EXT[key] = { minX: b.bounds.min.x, maxX: b.bounds.max.x, minY: b.bounds.min.y, maxY: b.bounds.max.y }; }
    return EXT[key];
  }

  function create(seed) {
    var engine = M.Engine.create({ positionIterations: 12, velocityIterations: 10, constraintIterations: 6 });
    var world = engine.world;
    var ground = M.Bodies.rectangle(W / 2, GROUND + 40, W * 4, 80, { isStatic: true, label: 'ground',
      collisionFilter: { category: CAT_STATIC, mask: CAT_CARGO } });
    var py = PIVOT_Y - PLANK_T / 2;
    var plank = M.Bodies.rectangle(W / 2, py, PLANK_L, PLANK_T, { density: 0.0005, label: 'plank', friction: 0.9, frictionStatic: 1.2,
      collisionFilter: { category: CAT_PLANK, mask: CAT_CARGO } });
    var pin = M.Constraint.create({ pointA: { x: W / 2, y: py }, bodyB: plank, pointB: { x: 0, y: 0 }, stiffness: 1, length: 0 });
    M.Composite.add(world, [ground, plank, pin]);
    var s = { engine: engine, plank: plank, cargo: [], t: 0, failed: null, failedBody: null,
      lastDropT: -999, score: 0, pendingScore: false, rng: rng(seed == null ? (Math.random() * 1e9) | 0 : seed), queue: [] };
    fillQueue(s); fillQueue(s);
    return s;
  }

  // 同じ動物が続きすぎないよう、全種類を混ぜた袋から順に出す
  function rng(seed) { var x = seed >>> 0 || 1; return function () { x ^= x << 13; x >>>= 0; x ^= x >>> 17; x ^= x << 5; x >>>= 0; return x / 4294967296; }; }
  function fillQueue(s) {
    var bag = KINDS.slice();
    for (var i = bag.length - 1; i > 0; i--) { var j = (s.rng() * (i + 1)) | 0; var t = bag[i]; bag[i] = bag[j]; bag[j] = t; }
    if (s.queue.length && s.queue[s.queue.length - 1] === bag[0]) bag.push(bag.shift());
    s.queue = s.queue.concat(bag);
  }
  function current(s) { return s.queue[0]; }
  function next(s) { return s.queue[1]; }

  // いちばん高い所（y が小さいほど高い）
  function topY(s) {
    var top = s.plank.bounds.min.y;
    s.cargo.forEach(function (b) { top = Math.min(top, b.bounds.min.y); });
    return top;
  }

  // 持っている動物の高さ: 積んだ山の上 60px に、体の下端が来るように
  function holdY(s, kind, ang) { var e = extent(kind, ang); return Math.min(PIVOT_Y - 140, topY(s) - GAP) - e.maxY; }
  function clampX(kind, ang, x) { var e = extent(kind, ang); return Math.max(4 - e.minX, Math.min(W - 4 - e.maxX, x)); }

  function drop(s, x, ang) {
    if (s.failed || !canDrop(s)) return null;
    var kind = current(s);
    var b = build(kind, clampX(kind, ang, x), holdY(s, kind, ang), ang);
    s.cargo.push(b);
    s.queue.shift(); if (s.queue.length < KINDS.length) fillQueue(s);
    s.lastDropT = s.t; s.pendingScore = true;
    M.Composite.add(s.engine.world, b);
    return b;
  }

  // 物理だけ1コマ進める（失敗のあとの落ちていく様子にも使う）
  function physics(s) {
    var p = s.plank, g = s.engine.gravity.y * s.engine.gravity.scale;
    for (var k = 0; k < SUB; k++) {
      var w = (p.angle - p.anglePrev) / SDT;
      p.force.y -= p.mass * g;
      p.torque = (-K_SPRING * p.angle - C_DAMP * w) * p.inertia;
      // ころがりにくく（実物の毛や手足の引っかかりの代わり）
      for (var c = 0; c < s.cargo.length; c++) { var cb = s.cargo[c]; M.Body.setAngularVelocity(cb, cb.angularVelocity * ADAMP); }
      M.Engine.update(s.engine, SDT);
    }
    s.t++;
  }

  function step(s) {
    if (s.failed) return;
    physics(s);
    var p = s.plank, vs = p.vertices;
    for (var i = 0; i < vs.length; i++) if (vs[i].y >= GROUND - 0.5) { s.failed = 'ground'; return; }
    for (var j = 0; j < s.cargo.length; j++) {
      var b = s.cargo[j];
      if (b.bounds.max.y >= GROUND - 1 || b.position.x < -60 || b.position.x > W + 60) { s.failed = 'fall'; s.failedBody = b; return; }
    }
    // 落とした動物が落ち着いたら1匹ぶん数える
    if (s.pendingScore && canDrop(s)) { s.pendingScore = false; s.score++; }
  }

  function settled(s) {
    if (Math.abs(s.plank.angularVelocity) > 0.0008) return false;
    for (var j = 0; j < s.cargo.length; j++) if (s.cargo[j].speed > 0.08 || Math.abs(s.cargo[j].angularVelocity) > 0.005) return false;
    return true;
  }
  function canDrop(s) { var d = s.t - s.lastDropT; return !s.failed && d >= 30 && (settled(s) || d >= 300); }

  // 板の傾き。-1..1（端が地面に着くと ±1）
  function tilt(s) {
    var low = s.plank.vertices.reduce(function (m, v) { return v.y > m.y ? v : m; }, { y: -1e9 });
    var r = (low.y - PIVOT_Y) / (GROUND - PIVOT_Y);
    return Math.max(0, Math.min(1, r)) * (low.x < W / 2 ? -1 : 1);
  }

  return { M: M, W: W, GROUND: GROUND, PIVOT_Y: PIVOT_Y, PLANK_T: PLANK_T, PLANK_L: PLANK_L, DT: DT, ROT_STEP: ROT_STEP,
    ANIMALS: ANIMALS, KINDS: KINDS, OFFSET: OFFSET, create: create, build: build, extent: extent, drop: drop, step: step, physics: physics,
    settled: settled, canDrop: canDrop, current: current, next: next, topY: topY, holdY: holdY, clampX: clampX, tilt: tilt };
})();
if (typeof module !== 'undefined') module.exports = TenbinCore;
