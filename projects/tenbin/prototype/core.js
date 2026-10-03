// てんびんタワー 物理コア。ブラウザと node で共用
// どうぶつタワーの積み方を、ばね付きのてんびんの上でやる。
// 動物は横向きのシルエット（animals.js）。重さは面積に比例（大きいほど重い）。
var TenbinCore = (function () {
  var M = (typeof Matter !== 'undefined') ? Matter : require('matter-js');
  var env = (typeof process !== 'undefined' && process.env) || {};
  var W = 400, GROUND = 600, PIVOT_Y = 556, PLANK_T = 14, PLANK_L = 320;
  var DT = 1000 / 60, SUB = 4, SDT = DT / SUB;
  var CAT_STATIC = 1, CAT_PLANK = 2, CAT_CARGO = 4;
  var DENSITY = 0.0015, ROT_STEP = Math.PI / 4;
  var FR = +(env.FR || 1.0), FRS = +(env.FRS || 2.0), ADAMP = +(env.AD || 0.97), GAP = +(env.GAP || 40);
  var K_SPRING = +(env.K || 2.2e-4), C_DAMP = +(env.CD || 0.007);

  var ANIMALS = (typeof TenbinAnimals !== 'undefined') ? TenbinAnimals : require('./animals.js');
  // 写真の動物（tool/trace.js が作る photos.js）があれば、同じ種類のシルエットを置き換える
  var PHOTOS = (typeof TenbinPhotos !== 'undefined') ? TenbinPhotos : (function () { try { return require('./photos.js'); } catch (e) { return {}; } })();
  Object.keys(PHOTOS).forEach(function (k) { ANIMALS[k] = PHOTOS[k]; });
  var decomp = (typeof window !== 'undefined' && window.decomp) || (typeof require !== 'undefined' ? require('poly-decomp') : null);
  M.Common.setDecomp(decomp);
  var KINDS = Object.keys(ANIMALS);

  // 輪郭の点列。写真から取った poly があればそれ、無ければ path（M L C Q Z）をなぞって点にする
  function outline(kind) {
    var A = ANIMALS[kind];
    if (A._pts) return A._pts;
    var pts = A.poly ? A.poly.map(function (q) { return { x: q[0], y: q[1] }; }) : samplePath(A.path);
    A._pts = simplify(pts, 0.6);
    return A._pts;
  }
  function samplePath(d) {
    var tk = d.match(/[MLCQZ]|-?[\d.]+/g), i = 0, pts = [], cx = 0, cy = 0, cmd = null;
    function num() { return +tk[i++]; }
    while (i < tk.length) {
      if (/[MLCQZ]/.test(tk[i])) cmd = tk[i++];
      if (cmd === 'Z') continue;
      if (cmd === 'M' || cmd === 'L') { cx = num(); cy = num(); pts.push({ x: cx, y: cy }); }
      else if (cmd === 'Q') {
        var qx = num(), qy = num(), ex = num(), ey = num();
        for (var t = 1; t <= 8; t++) { var u = t / 8, v = 1 - u; pts.push({ x: v * v * cx + 2 * v * u * qx + u * u * ex, y: v * v * cy + 2 * v * u * qy + u * u * ey }); }
        cx = ex; cy = ey;
      } else if (cmd === 'C') {
        var x1 = num(), y1 = num(), x2 = num(), y2 = num(), x3 = num(), y3 = num();
        for (var t2 = 1; t2 <= 10; t2++) { var u2 = t2 / 10, v2 = 1 - u2;
          pts.push({ x: v2 * v2 * v2 * cx + 3 * v2 * v2 * u2 * x1 + 3 * v2 * u2 * u2 * x2 + u2 * u2 * u2 * x3,
                     y: v2 * v2 * v2 * cy + 3 * v2 * v2 * u2 * y1 + 3 * v2 * u2 * u2 * y2 + u2 * u2 * u2 * y3 }); }
        cx = x3; cy = y3;
      }
    }
    var f = pts[0], l = pts[pts.length - 1];
    if (Math.hypot(f.x - l.x, f.y - l.y) < 0.01) pts.pop();
    return pts;
  }
  // 細かすぎる点を間引く（ダグラス・ポーカー）
  function simplify(pts, tol) {
    if (pts.length < 8) return pts;
    var keep = new Array(pts.length).fill(false); keep[0] = keep[pts.length - 1] = true;
    (function rdp(a, b) {
      var A = pts[a], B = pts[b], dx = B.x - A.x, dy = B.y - A.y, L = Math.hypot(dx, dy) || 1, md = 0, mi = -1;
      for (var k = a + 1; k < b; k++) { var d = Math.abs((pts[k].x - A.x) * dy - (pts[k].y - A.y) * dx) / L; if (d > md) { md = d; mi = k; } }
      if (md > tol) { keep[mi] = true; rdp(a, mi); rdp(mi, b); }
    })(0, pts.length - 1);
    return pts.filter(function (_, k) { return keep[k]; });
  }

  // 絵の原点から重心までのずれ（角度0のとき）。描くときに使う
  var OFFSET = {};
  KINDS.forEach(function (k) { var b = build(k, 0, 0, 0); OFFSET[k] = { x: b.position.x, y: b.position.y }; });

  // 絵の原点を (x,y) に置き、ang だけ回した体を作る
  function build(kind, x, y, ang) {
    var pts = outline(kind);
    var filter = { category: CAT_CARGO, mask: CAT_CARGO | CAT_PLANK | CAT_STATIC, group: 0 };
    var b = M.Bodies.fromVertices(0, 0, [pts.map(function (q) { return { x: q.x, y: q.y }; })],
      { density: DENSITY, friction: FR, frictionStatic: FRS, restitution: 0.02, collisionFilter: filter }, true, 0.01, 2);
    b.parts.forEach(function (pt) { pt.collisionFilter = filter; pt.friction = FR; pt.frictionStatic = FRS; });
    // fromVertices は重心を (0,0) に置くので、絵の座標に合うよう外枠でそろえる
    var minX = Infinity, minY = Infinity;
    pts.forEach(function (q) { minX = Math.min(minX, q.x); minY = Math.min(minY, q.y); });
    M.Body.translate(b, { x: minX - b.bounds.min.x, y: minY - b.bounds.min.y });
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
    ANIMALS: ANIMALS, KINDS: KINDS, OFFSET: OFFSET, outline: outline, create: create, build: build, extent: extent, drop: drop, step: step, physics: physics,
    settled: settled, canDrop: canDrop, current: current, next: next, topY: topY, holdY: holdY, clampX: clampX, tilt: tilt };
})();
if (typeof module !== 'undefined') module.exports = TenbinCore;
