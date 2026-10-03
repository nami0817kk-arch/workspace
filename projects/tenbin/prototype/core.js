// ひらがなてんびん 物理コア。ブラウザと node で共用
// ばね付きのてんびんの上に、ひらがなを1字ずつ積んでいく。
// 字の形がそのまま当たり判定。重さは面積に比例（画の多い字ほど重い）。
var TenbinCore = (function () {
  var M = (typeof Matter !== 'undefined') ? Matter : require('matter-js');
  var env = (typeof process !== 'undefined' && process.env) || {};
  var W = 400, GROUND = 600, PIVOT_Y = 556, PLANK_T = 14, PLANK_L = 320;
  var DT = 1000 / 60, SUB = 4, SDT = DT / SUB;
  var CAT_STATIC = 1, CAT_PLANK = 2, CAT_CARGO = 4;
  var DENSITY = 0.0015, ROT_STEP = Math.PI / 4;
  var FR = +(env.FR || 1.0), FRS = +(env.FRS || 2.0), ADAMP = +(env.AD || 0.97), GAP = +(env.GAP || 40);
  var K_SPRING = +(env.K || 1.4e-4), C_DAMP = +(env.CD || 0.007);

  // 積むもの = ひらがな1字。輪郭は tool/glyphs.js が字形から取ったもの（字の中心が原点）
  var GLYPHS = (typeof TenbinGlyphs !== 'undefined') ? TenbinGlyphs : require('./glyphs.js');
  var decomp = (typeof window !== 'undefined' && window.decomp) || (typeof require !== 'undefined' ? require('poly-decomp') : null);
  M.Common.setDecomp(decomp);
  var KINDS = Object.keys(GLYPHS.chars);
  var WORDS = (typeof TenbinWords !== 'undefined') ? TenbinWords : require('./words.js');

  // 字ごとの部品（離れた画は別の輪郭）。点の少ない輪郭は捨てない
  function outlines(kind) { return GLYPHS.chars[kind].map(function (poly) { return poly.map(function (q) { return { x: q[0], y: q[1] }; }); }); }

  // 字の中心を (x,y) に置き、ang だけ回した体を作る。離れた画も1つの硬い体にまとめる
  function build(kind, x, y, ang) {
    var filter = { category: CAT_CARGO, mask: CAT_CARGO | CAT_PLANK | CAT_STATIC, group: 0 };
    var opt = { density: DENSITY, friction: FR, frictionStatic: FRS, restitution: 0.02, collisionFilter: filter };
    var parts = [];
    outlines(kind).forEach(function (pts) {
      var minX = Infinity, minY = Infinity;
      pts.forEach(function (q) { minX = Math.min(minX, q.x); minY = Math.min(minY, q.y); });
      var b = M.Bodies.fromVertices(0, 0, [pts], opt, true, 0.01, 1);
      // fromVertices は重心を (0,0) に置くので、字の座標に合うよう外枠でそろえる
      M.Body.translate(b, { x: minX - b.bounds.min.x, y: minY - b.bounds.min.y });
      (b.parts.length > 1 ? b.parts.slice(1) : [b]).forEach(function (pt) { pt.parent = pt; parts.push(pt); });
    });
    parts.forEach(function (pt) { pt.collisionFilter = filter; pt.friction = FR; pt.frictionStatic = FRS; });
    var body = M.Body.create(Object.assign({ parts: parts }, opt));
    // matter は部品をまとめた体の慣性を「部品ごとの慣性の和」で済ませ、重心からの距離の分を足さない。
    // そのままだと字が回りやすすぎて、動かない台に当たると勢いよく回って飛ぶ。平行軸の分を足して直す
    var I = 0;
    parts.forEach(function (pt) { var dx = pt.position.x - body.position.x, dy = pt.position.y - body.position.y;
      I += pt.inertia + M.Body._inertiaScale * pt.mass * (dx * dx + dy * dy); });
    M.Body.setInertia(body, I);
    M.Body.rotate(body, ang, { x: 0, y: 0 });
    M.Body.translate(body, { x: x, y: y });
    body.kind = kind;
    return body;
  }

  // 字の中心から重心までのずれ（角度0のとき）。描くときに使う
  var OFFSET = {};
  KINDS.forEach(function (k) { var b = build(k, 0, 0, 0); OFFSET[k] = { x: b.position.x, y: b.position.y }; });

  // 回したときの絵の原点からの上下左右のはみ出し
  var EXT = {};
  function extent(kind, ang) {
    var key = kind + ':' + ang.toFixed(4);
    if (!EXT[key]) { var b = build(kind, 0, 0, ang); EXT[key] = { minX: b.bounds.min.x, maxX: b.bounds.max.x, minY: b.bounds.min.y, maxY: b.bounds.max.y }; }
    return EXT[key];
  }

  // 台の種類。てんびんはその1つ。boards は板（中心x・幅・傾き）。どれも同じ高さに置く
  var PLATFORMS = {
    flat:   { name: 'ふつう',   boards: [{ x: 200, w: 280 }] },
    seesaw: { name: 'てんびん', boards: [{ x: 200, w: 320 }], seesaw: true },
    sway:   { name: 'ゆらゆら', boards: [{ x: 200, w: 240 }], sway: { amp: 55, period: 480 } },
    slope:  { name: 'さか',     boards: [{ x: 200, w: 280, a: -0.12 }] },
    narrow: { name: 'せまい',   boards: [{ x: 200, w: 170 }] },
    twin:   { name: 'ふたつ',   boards: [{ x: 118, w: 130 }, { x: 282, w: 130 }] }
  };
  var PLATFORM_KEYS = Object.keys(PLATFORMS);

  function create(seed, platform) {
    var def = PLATFORMS[platform] || PLATFORMS.flat;
    var engine = M.Engine.create({ positionIterations: 12, velocityIterations: 10, constraintIterations: 6 });
    var world = engine.world;
    var ground = M.Bodies.rectangle(W / 2, GROUND + 40, W * 4, 80, { isStatic: true, label: 'ground',
      collisionFilter: { category: CAT_STATIC, mask: CAT_CARGO } });
    var py = PIVOT_Y - PLANK_T / 2;
    var boards = def.boards.map(function (bd) {
      var b = M.Bodies.rectangle(bd.x, py, bd.w, PLANK_T, { density: 0.0005, label: 'plank', friction: 0.9, frictionStatic: 1.2,
        isStatic: !def.seesaw, collisionFilter: { category: CAT_PLANK, mask: CAT_CARGO } });
      if (bd.a) M.Body.setAngle(b, bd.a);
      b.baseX = bd.x; b.boardW = bd.w;
      return b;
    });
    M.Composite.add(world, [ground].concat(boards));
    if (def.seesaw) M.Composite.add(world, M.Constraint.create({ pointA: { x: W / 2, y: py }, bodyB: boards[0], pointB: { x: 0, y: 0 }, stiffness: 1, length: 0 }));
    var s = { engine: engine, def: def, platform: PLATFORMS[platform] ? platform : 'flat', boards: boards, plank: boards[0], cargo: [], t: 0, sub: 0,
      failed: null, failedBody: null, lastDropT: -999, score: 0, pendingScore: false, rng: rng(seed == null ? (Math.random() * 1e9) | 0 : seed),
      queue: [], made: [], height: 0, events: [], last: null };
    fillQueue(s); fillQueue(s);
    // 落とした字が最初に何かへ当たった瞬間を「着地」として知らせる（音・粒・弾みに使う）
    M.Events.on(engine, 'collisionStart', function (e) {
      var b = s.last; if (!b || b.landed) return;
      for (var i = 0; i < e.pairs.length; i++) {
        var A = e.pairs[i].bodyA.parent, B = e.pairs[i].bodyB.parent;
        if (A !== b && B !== b) continue;
        b.landed = true;
        s.events.push({ type: 'land', kind: b.kind, x: b.position.x, y: b.bounds.max.y, speed: b.speed, mass: b.mass });
        return;
      }
    });
    return s;
  }

  // 字は「ことば」の順に来る。積んだ字数が増えるほど長いことばが混ざる
  function rng(seed) { var x = seed >>> 0 || 1; return function () { x ^= x << 13; x >>>= 0; x ^= x >>> 17; x ^= x << 5; x >>>= 0; return x / 4294967296; }; }
  function pick(s, list) { return list[(s.rng() * list.length) | 0]; }
  function fillQueue(s) {
    var n = s.score + s.queue.length, tier;
    var r = s.rng();
    if (n < 8) tier = r < 0.75 ? WORDS.short : WORDS.middle;
    else if (n < 24) tier = r < 0.35 ? WORDS.short : r < 0.85 ? WORDS.middle : WORDS.long;
    else tier = r < 0.2 ? WORDS.short : r < 0.6 ? WORDS.middle : WORDS.long;
    var w = pick(s, tier), prev = s.queue.length ? s.queue[s.queue.length - 1].word : null;
    if (prev && prev.text === w) w = pick(s, tier);
    var word = { text: w, got: 0 };
    for (var i = 0; i < w.length; i++) s.queue.push({ ch: w[i], word: word, pos: i });
  }
  function current(s) { return s.queue[0].ch; }
  function next(s) { return s.queue[1].ch; }
  // いま積んでいることばと、何字目か
  function currentWord(s) { var q = s.queue[0]; return { text: q.word.text, pos: q.pos, got: q.word.got }; }

  // いちばん高い所（y が小さいほど高い）
  function topY(s) {
    var top = Infinity;
    s.boards.forEach(function (b) { top = Math.min(top, b.bounds.min.y); });
    s.cargo.forEach(function (b) { top = Math.min(top, b.bounds.min.y); });
    return top;
  }

  // 持っている動物の高さ: 積んだ山の上 60px に、体の下端が来るように
  function holdY(s, kind, ang) { var e = extent(kind, ang); return Math.min(PIVOT_Y - 140, topY(s) - GAP) - e.maxY; }
  function clampX(kind, ang, x) { var e = extent(kind, ang); return Math.max(4 - e.minX, Math.min(W - 4 - e.maxX, x)); }

  function drop(s, x, ang) {
    if (s.failed || !canDrop(s)) return null;
    var q = s.queue[0], kind = q.ch;
    var b = build(kind, clampX(kind, ang, x), holdY(s, kind, ang), ang);
    b.word = q.word;
    s.cargo.push(b); s.last = b;
    s.queue.shift(); while (s.queue.length < 8) fillQueue(s);
    s.lastDropT = s.t; s.pendingScore = true;
    M.Composite.add(s.engine.world, b);
    return b;
  }

  // 物理だけ1コマ進める（失敗のあとの落ちていく様子にも使う）
  function physics(s) {
    var p = s.plank, g = s.engine.gravity.y * s.engine.gravity.scale, def = s.def;
    for (var k = 0; k < SUB; k++) {
      if (def.seesaw) {
        var w = (p.angle - p.anglePrev) / SDT;
        p.force.y -= p.mass * g;
        p.torque = (-K_SPRING * p.angle - C_DAMP * w) * p.inertia;
      }
      if (def.sway) {
        // 左右にゆっくり往復。速さも渡して、上の字が板と一緒に運ばれるようにする
        s.sub++;
        var x = p.baseX + def.sway.amp * Math.sin(2 * Math.PI * s.sub / (def.sway.period * SUB));
        M.Body.setPosition(p, { x: x, y: p.position.y }, true);
      }
      // ころがりにくく（字の角の引っかかりの代わり）
      for (var c = 0; c < s.cargo.length; c++) { var cb = s.cargo[c]; M.Body.setAngularVelocity(cb, cb.angularVelocity * ADAMP); }
      M.Engine.update(s.engine, SDT);
    }
    s.t++;
  }

  function step(s) {
    if (s.failed) return;
    physics(s);
    if (s.def.seesaw) { var vs = s.plank.vertices;
      for (var i = 0; i < vs.length; i++) if (vs[i].y >= GROUND - 0.5) { s.failed = 'ground'; return; } }
    for (var j = 0; j < s.cargo.length; j++) {
      var b = s.cargo[j];
      if (b.bounds.max.y >= GROUND - 1 || b.position.x < -60 || b.position.x > W + 60) { s.failed = 'fall'; s.failedBody = b; return; }
    }
    // 落とした字が落ち着いたら1字ぶん数える。ことばの最後の字なら、ことばができた
    if (s.pendingScore && canDrop(s)) {
      s.pendingScore = false; s.score++;
      var top = Infinity; s.cargo.forEach(function (c) { top = Math.min(top, c.bounds.min.y); });
      s.height = Math.max(s.height, PIVOT_Y - PLANK_T - top);
      s.events.push({ type: 'score', kind: s.last.kind });
      var w = s.last.word; w.got++;
      if (w.got === w.text.length) {
        s.made.push(w.text);
        s.events.push({ type: 'word', text: w.text, bodies: s.cargo.filter(function (c) { return c.word === w; }) });
      }
    }
  }

  function settled(s) {
    if (s.def.seesaw && Math.abs(s.plank.angularVelocity) > 0.0008) return false;
    // ゆらゆらの台では、板と一緒に動いている分は数えない
    var vx = s.def.sway ? s.plank.velocity.x : 0;
    for (var j = 0; j < s.cargo.length; j++) { var c = s.cargo[j];
      if (Math.hypot(c.velocity.x - vx, c.velocity.y) > 0.12 || Math.abs(c.angularVelocity) > 0.008) return false; }
    return true;
  }
  function canDrop(s) { var d = s.t - s.lastDropT; return !s.failed && d >= 20 && (settled(s) || d >= 180); }

  // 板の傾き。-1..1（端が地面に着くと ±1）
  function tilt(s) {
    if (!s.def.seesaw) return 0;
    var low = s.plank.vertices.reduce(function (m, v) { return v.y > m.y ? v : m; }, { y: -1e9 });
    var r = (low.y - PIVOT_Y) / (GROUND - PIVOT_Y);
    return Math.max(0, Math.min(1, r)) * (low.x < W / 2 ? -1 : 1);
  }

  return { M: M, W: W, GROUND: GROUND, PIVOT_Y: PIVOT_Y, PLANK_T: PLANK_T, PLANK_L: PLANK_L, DT: DT, ROT_STEP: ROT_STEP,
    GLYPHS: GLYPHS, KINDS: KINDS, OFFSET: OFFSET, outlines: outlines, create: create, build: build, extent: extent, drop: drop, step: step, physics: physics,
    PLATFORMS: PLATFORMS, PLATFORM_KEYS: PLATFORM_KEYS, settled: settled, canDrop: canDrop, current: current, next: next, currentWord: currentWord, WORDS: WORDS, topY: topY, holdY: holdY, clampX: clampX, tilt: tilt };
})();
if (typeof module !== 'undefined') module.exports = TenbinCore;
