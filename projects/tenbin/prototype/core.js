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
    flat:   { name: 'ふつう',   boards: [{ x: 200, w: 340 }] },
    seesaw: { name: 'てんびん', boards: [{ x: 200, w: 370 }], seesaw: true },
    sway:   { name: 'ゆらゆら', boards: [{ x: 200, w: 290 }], sway: { amp: 45, period: 480 } },
    slope:  { name: 'さか',     boards: [{ x: 200, w: 340, a: -0.12 }] },
    narrow: { name: 'せまい',   boards: [{ x: 200, w: 210 }] },
    twin:   { name: 'ふたつ',   boards: [{ x: 108, w: 160 }, { x: 292, w: 160 }] }
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
      queue: [], made: [], madeBodies: [], points: 0, height: 0, events: [], last: null };
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

  // 字はばらばらに来る。ただし完全なでたらめだと言葉がほとんどできないので、
  // いくつかのことばの字を混ぜた袋から出す（ことばに使う字が多めに来る）
  function rng(seed) { var x = seed >>> 0 || 1; return function () { x ^= x << 13; x >>>= 0; x ^= x >>> 17; x ^= x << 5; x >>>= 0; return x / 4294967296; }; }
  function pick(s, list) { return list[(s.rng() * list.length) | 0]; }
  function fillQueue(s) {
    var bag = [];
    for (var n = 0; n < 3; n++) {
      var r = s.rng(), tier = r < 0.6 ? WORDS.short : r < 0.9 ? WORDS.middle : WORDS.long;
      bag = bag.concat(pick(s, tier).split(''));
    }
    bag.push(pick(s, KINDS));
    for (var i = bag.length - 1; i > 0; i--) { var j = (s.rng() * (i + 1)) | 0; var t = bag[i]; bag[i] = bag[j]; bag[j] = t; }
    // 同じ字が続かないように
    for (var k = 1; k < bag.length; k++) if (bag[k] === bag[k - 1]) { var m = (k + 2) % bag.length; t = bag[k]; bag[k] = bag[m]; bag[m] = t; }
    if (s.queue.length && s.queue[s.queue.length - 1] === bag[0]) bag.push(bag.shift());
    s.queue = s.queue.concat(bag);
  }
  function current(s) { return s.queue[0]; }
  function next(s) { return s.queue[1]; }

  // --- くっついている字で、ことばができているか ---
  // 縦（上から下へ）か横（左から右へ）に、触れ合っている字をたどって読めればことば
  var TRIE = {};
  WORDS.short.concat(WORDS.middle, WORDS.long).forEach(function (w) {
    var n = TRIE; for (var i = 0; i < w.length; i++) n = n[w[i]] = n[w[i]] || {}; n.$ = w;
  });
  // 持っている字とつながりそうな字: 2字のことばになる（強い）／長いことばの一部になる（弱い）
  var PAIRS = {};
  WORDS.short.concat(WORDS.middle, WORDS.long).forEach(function (w) {
    for (var i = 0; i + 1 < w.length; i++) { var k = w[i] + w[i + 1]; PAIRS[k] = Math.max(PAIRS[k] || 0, w.length === 2 ? 2 : 1); }
  });
  function partners(s, ch) {
    var out = [];
    s.cargo.forEach(function (c) { var a = PAIRS[ch + c.kind] || 0, b = PAIRS[c.kind + ch] || 0; if (a || b) out.push({ body: c, strong: Math.max(a, b) === 2 }); });
    return out;
  }
  // 字の中心（重心ではなく、字の外枠の中心）
  function centre(b) { return { x: (b.bounds.min.x + b.bounds.max.x) / 2, y: (b.bounds.min.y + b.bounds.max.y) / 2 }; }
  function step2(a, b, dir) {
    var A = centre(a), B = centre(b), dx = B.x - A.x, dy = B.y - A.y;
    return dir === 'tate' ? dy >= 10 && Math.abs(dx) <= Math.max(40, dy * 1.1) : dx >= 10 && Math.abs(dy) <= Math.max(40, dx * 1.1);
  }
  // 触れ合い = 物理で当たっている、または輪郭どうしが NEAR px 以内。
  // 重力は下向きなので、横に並べた字は少しすき間が空く。それも「くっついた」とみなす
  // （2026-10-04「言葉として反応しない時がある」: 4px では見た目にくっついた字の多くを取りこぼしていた）
  var NEAR = 10;   // 字には縁取りがあるので、輪郭が 10px 離れていても画面ではくっついて見える
  function segDist(px, py, ax, ay, bx, by) {
    var dx = bx - ax, dy = by - ay, L = dx * dx + dy * dy, t = L ? Math.max(0, Math.min(1, ((px - ax) * dx + (py - ay) * dy) / L)) : 0;
    return Math.hypot(px - ax - t * dx, py - ay - t * dy);
  }
  function partsOf(b) { return b.parts.length > 1 ? b.parts.slice(1) : [b]; }
  function near(a, b) {
    if (a.bounds.min.x - NEAR > b.bounds.max.x || b.bounds.min.x - NEAR > a.bounds.max.x ||
        a.bounds.min.y - NEAR > b.bounds.max.y || b.bounds.min.y - NEAR > a.bounds.max.y) return false;
    var pa = partsOf(a), pb = partsOf(b);
    for (var i = 0; i < pa.length; i++) for (var j = 0; j < pb.length; j++) {
      var P = pa[i], Q = pb[j];
      if (P.bounds.min.x - NEAR > Q.bounds.max.x || Q.bounds.min.x - NEAR > P.bounds.max.x ||
          P.bounds.min.y - NEAR > Q.bounds.max.y || Q.bounds.min.y - NEAR > P.bounds.max.y) continue;
      if (M.Collision.collides(P, Q)) return true;
      for (var pass = 0; pass < 2; pass++) {
        var U = pass ? Q : P, V = pass ? P : Q;
        for (var u = 0; u < U.vertices.length; u++) for (var v = 0; v < V.vertices.length; v++) {
          var v1 = V.vertices[v], v2 = V.vertices[(v + 1) % V.vertices.length];
          if (segDist(U.vertices[u].x, U.vertices[u].y, v1.x, v1.y, v2.x, v2.y) <= NEAR) return true;
        }
      }
    }
    return false;
  }
  function touching(s) {
    var nb = new Map(), cs = s.cargo;
    cs.forEach(function (c) { nb.set(c, []); });
    for (var i = 0; i < cs.length; i++) for (var j = i + 1; j < cs.length; j++)
      if (near(cs[i], cs[j])) { nb.get(cs[i]).push(cs[j]); nb.get(cs[j]).push(cs[i]); }
    return nb;
  }
  // 点: 字を1つ積むと10点。ことばは (字数-1)の2乗×100点（2字100・3字400・4字900・5字1600）
  var LETTER_PTS = 10;
  function wordPoints(w) { return 100 * (w.length - 1) * (w.length - 1); }
  function findWords(s) {
    var nb = touching(s), found = [];
    s.cargo.forEach(function (start) {
      ['tate', 'yoko'].forEach(function (dir) {
        (function walk(b, node, path) {
          node = node[b.kind]; if (!node) return;
          path = path.concat([b]);
          if (node.$ && path.length >= 2) found.push({ text: node.$, bodies: path, dir: dir });
          nb.get(b).forEach(function (o) { if (path.indexOf(o) < 0 && step2(b, o, dir)) walk(o, node, path); });
        })(start, TRIE, []);
      });
    });
    return found;
  }

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

  // 持っている字をこのまま落としたら、どこに着きそうか（真下にある字・台の上面）。狙いの目安の影に使う
  // 字の幅に縦の線を何本か下ろし、いちばん上で当たる高さを返す（転がりや跳ねは考えない）
  function landingY(s, kind, ang, x) {
    var e = extent(kind, ang), y0 = holdY(s, kind, ang) + e.maxY, best = GROUND;
    var bodies = s.boards.concat(s.cargo), parts = [];
    bodies.forEach(function (b) { (b.parts.length > 1 ? b.parts.slice(1) : [b]).forEach(function (p) { parts.push(p); }); });
    for (var i = 0; i < 7; i++) {
      var cx = x + e.minX + 3 + (e.maxX - e.minX - 6) * i / 6;
      parts.forEach(function (p) {
        if (cx < p.bounds.min.x || cx > p.bounds.max.x || p.bounds.max.y < y0) return;
        var vs = p.vertices;
        for (var k = 0; k < vs.length; k++) {
          var a = vs[k], b = vs[(k + 1) % vs.length];
          if ((a.x - cx) * (b.x - cx) > 0 || a.x === b.x) continue;
          var y = a.y + (b.y - a.y) * (cx - a.x) / (b.x - a.x);
          if (y >= y0 && y < best) best = y;
        }
      });
    }
    return best;
  }

  function drop(s, x, ang) {
    if (s.failed || !canDrop(s)) return null;
    var kind = s.queue[0];
    var b = build(kind, clampX(kind, ang, x), holdY(s, kind, ang), ang);
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
    // つづけた直後は、板が戻り字が落ち着くまで失敗を数えない
    if (s.grace > 0) { s.grace--; return; }
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
      s.points += LETTER_PTS;
      s.events.push({ type: 'score', kind: s.last.kind, pts: LETTER_PTS });
      checkWords(s);
    } else if (!s.pendingScore && s.t % 15 === 0 && s.cargo.length > 1 && settled(s)) {
      // 字があとからずれてくっついた場合も、落ち着いたところで拾う
      checkWords(s);
    }
  }

  // くっついてできたことばを数える。長いことばから。
  // 同じことばでも、別の字で作れば何度でも数える。1字で同時にいくつもできたら、その数だけ倍（2つなら2倍）
  function checkWords(s) {
    var fresh = [];
    findWords(s).sort(function (a, b) { return b.text.length - a.text.length; }).forEach(function (f) {
      // 長いことばの一部（あさひ の中の あさ）は数えない。字を分け合う別のことば（十字に交わる）は数える。
      // 前にできたことばと同じ字・その一部も数えない（あとから別の字を置いたときに あさ を数え直さない）
      var inside = function (bs) { return f.bodies.every(function (b) { return bs.indexOf(b) >= 0; }); };
      if (fresh.some(function (x) { return inside(x.bodies); }) || s.madeBodies.some(inside)) return;
      fresh.push(f);
    });
    fresh.forEach(function (f) {
      var pts = wordPoints(f.text) * fresh.length;
      s.made.push(f.text); s.madeBodies.push(f.bodies); s.points += pts;
      s.events.push({ type: 'word', text: f.text, bodies: f.bodies, dir: f.dir, pts: pts, mult: fresh.length });
    });
  }

  // 報酬広告で「つづける」: 落ちた字（床より下・台より下・画面の外）を取り除き、点はそのままで続きから。
  // てんびんが床に着いたときは、最後に置いた字も取り除いて、板が戻るまで待つ
  function revive(s) {
    if (!s.failed || s.revived) return false;
    var boardTop = Infinity; s.boards.forEach(function (b) { boardTop = Math.min(boardTop, b.bounds.min.y); });
    // 台の上に重心がない字（はみ出して落ちかけている）
    var offBoard = function (b) { return !s.boards.some(function (bd) { return b.position.x >= bd.bounds.min.x - 4 && b.position.x <= bd.bounds.max.x + 4; }); };
    var drop = s.cargo.filter(function (b) {
      return b === s.failedBody || b.bounds.min.y > boardTop + PLANK_T || b.bounds.max.y >= GROUND - 1 ||
        b.position.x < -40 || b.position.x > W + 40 || b.speed > 1.2 || offBoard(b);
    });
    if (s.failed === 'ground' && s.last && drop.indexOf(s.last) < 0) drop.push(s.last);
    drop.forEach(function (b) { M.Composite.remove(s.engine.world, b); });
    s.cargo = s.cargo.filter(function (b) { return drop.indexOf(b) < 0; });
    // てんびんは、片側に重さが偏ったままだとすぐまた傾く。つり合うまで新しい字から取り除く
    // （広告を見たのにすぐ負けるのがいちばんいやな体験）
    if (s.def.seesaw) {
      var lean = function () { return s.cargo.reduce(function (t, b) { return t + b.mass * (b.position.x - W / 2); }, 0); };
      while (s.cargo.length && Math.abs(lean()) > 220) { var b = s.cargo.pop(); M.Composite.remove(s.engine.world, b); }
      M.Body.setAngle(s.plank, s.plank.angle * 0.5);
    }
    s.cargo.forEach(function (b) { M.Body.setVelocity(b, { x: 0, y: 0 }); M.Body.setAngularVelocity(b, 0); });
    if (s.def.seesaw) M.Body.setAngularVelocity(s.plank, 0);
    s.failed = null; s.failedBody = null; s.revived = true; s.pendingScore = false; s.grace = 90; s.lastDropT = s.t;
    return true;
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
    PLATFORMS: PLATFORMS, PLATFORM_KEYS: PLATFORM_KEYS, settled: settled, canDrop: canDrop, current: current, next: next, WORDS: WORDS, findWords: findWords, partners: partners, revive: revive, landingY: landingY, wordPoints: wordPoints, LETTER_PTS: LETTER_PTS, topY: topY, holdY: holdY, clampX: clampX, tilt: tilt };
})();
if (typeof module !== 'undefined') module.exports = TenbinCore;
