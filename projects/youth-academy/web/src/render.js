// 見せ方：試合を上から見た戦術ボードで描く（Football Manager の2D表示の形）。
// engine.js が返した場面のコマは「誰がどこでボールに触るか」の台本として読み、
// 位置そのものは物理で決める：ボールは蹴られたら転がって減速する物、選手は目標へ加速・減速して走る人。
// ボールは誰かが触らないと向きも速さも変わらない。選手は瞬間移動しない（暗転の切り替えのときだけ置き直す）。
(function () {
  'use strict';
  const YA = (globalThis.YA = globalThis.YA || {});
  const W = 68;
  const L = 105;
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const lerp = (a, b, t) => a + (b - a) * t;
  const dist = (a, b) => Math.hypot(a[0] - b[0], a[1] - b[1]);

  // 動きの決まり（m・秒）
  const MOVE = {
    sprint: 8.4, // 場面の主役の全力
    jog: 6.0, // 並びを保つ動き
    dribble: 7.2, // ボールを運ぶ速さ
    acc: 7.5, // 加速・減速の強さ（m/s²）
    reach: 1.15, // この距離でボールに触れる
    fric: 3.2, // 転がるボールの減速（m/s²）
    passEnd: 3.4, // 地を這うパスが受け手に届くときの速さ
    loft: 19.5, // 浮き球の横の速さ
    shot: 25, // シュートの速さ
    maxGround: 23, // これより強く蹴らないと届かないなら浮かせる
  };
  YA.MOVE = MOVE;

  class Renderer {
    constructor(canvas) {
      this.cv = canvas;
      this.ctx = canvas.getContext('2d');
      this.match = null;
      this.scene = null;
      this.t = 0;
      this.dpr = 1;
      this.reset();
      this.resize();
    }

    reset() {
      this.disp = {}; // pid -> [x,y]（いまの位置）
      this.vel = {}; // pid -> [vx,vy]
      this.speed = {};
      this.ball = [34, L / 2, 0];
      this.bv = [0, 0]; // 転がるボールの速さ
      this.owner = null; // 足元に持っている子
      this.fl = null; // 蹴られて飛んでいるボール
      this.expect = null; // 場面で次にボールに触る子（ほかの子は拾わない）
      this.lock = {}; // 蹴った直後の子は 0.3 秒触らない
      this.idle = null;
      this.focus = [];
      this.defFocus = [];
      this.flash = 0;
      this.cut = 0;
      this.kicks = 0; // 点検用：蹴った回数
      this.stuck = 0; // 点検用：受け手が届かず先へ進めた回数
      this.kicked = false; // 点検用：このコマで蹴った
      this.cam = { cy: L / 2, cx: W / 2, zoom: 1 };
      this.trails = [];
    }

    resize() {
      const r = this.cv.getBoundingClientRect();
      this.dpr = Math.min(2, globalThis.devicePixelRatio || 1);
      const w = Math.max(100, Math.round(r.width));
      const h = Math.max(60, Math.round(r.height));
      this.cv.width = w * this.dpr;
      this.cv.height = h * this.dpr;
      this.w = w;
      this.h = h;
    }

    setMatch(m) {
      this.match = m;
      this.scene = null;
      this.base = {};
      this.kits = null;
      this.reset();
    }

    // 並びからの基本位置（絶対座標）
    basePositions() {
      const m = this.match;
      const out = {};
      for (const [t, flip] of [[m.home, false], [m.away, true]]) {
        t.lineup.forEach((s, i) => {
          const x = s.x * W;
          // 任務で立つ位置の深さが変わる（攻撃は高く、守備は低く）
          const dep = (YA.DUTY[s.duty] ? YA.DUTY[s.duty].depth : 0) * 78;
          const y = clamp(4 + s.y * 78 + (i === 0 ? 0 : dep), 2, 100);
          out[s.pid] = flip ? [W - x, L - y, t, i, s] : [x, y, t, i, s];
        });
      }
      return out;
    }
    teamOf(id) {
      return this.base[id] && this.base[id][2];
    }
    tacOf(id) {
      const t = this.teamOf(id);
      return Object.assign({ tempo: 0.5, width: 0.5, line: 0.5, press: 0.5 }, t && t.tactic);
    }
    // ボールの位置に合わせてチーム全体が寄る位置。戦い方と役割で、持っているときと守るときの形が変わる
    shapePos(id) {
      const b = this.base[id];
      const t = b[2];
      const away = this.match && t === this.match.away;
      const gk = b[3] === 0;
      const tc = this.tacOf(id);
      const mine = this.poss === (away ? 'away' : 'home');
      // 自分のゴールからの深さで考える
      const br = away ? L - this.ball[1] : this.ball[1];
      let yr = away ? L - b[1] : b[1];
      if (gk) {
        const gy = clamp(yr + (mine ? 4 : 0) + (tc.line - 0.5) * 8, 2, 16); // ラインが高いと GK も前に出る
        return [lerp(34, this.ball[0], 0.12), away ? L - gy : gy];
      }
      const s = b[4] || {};
      const tags = (YA.ROLE_DEF && YA.ROLE_DEF[s.role] && YA.ROLE_DEF[s.role].tags) || [];
      const has = (k) => tags.indexOf(k) >= 0;
      let x = b[0];
      if (mine) {
        // 攻め：全体が押し上げ、幅は戦い方の広さ（サイド攻撃は外に張る）
        yr += 3 + tc.tempo * 4;
        x = 34 + (x - 34) * (0.8 + tc.width * 0.6);
        if (s.duty === 'att') yr += has('wide') ? 10 : 5; // 攻撃の任務のサイドは追い越して上がる
        if (s.duty === 'def' || has('stay')) yr -= 5; // 守備の任務は残る
        if (has('run')) yr += 4; // 裏を狙う
        if (has('post')) yr -= 6; // 降りて受ける
        if (has('cutin')) x = lerp(x, 34, 0.3);
        if (has('wide') && s.duty === 'att') x = 34 + (x - 34) * 1.15;
        x = lerp(x, this.ball[0], 0.1);
      } else {
        // 守り：最終ラインの高さは戦い方で決まる（ハイプレスは高く、堅守は低く）。横はボールへ絞る
        yr += (tc.line - 0.5) * 18;
        if (s.duty === 'att') yr += 4; // 攻撃の任務は戻りが遅い
        x = lerp(34 + (x - 34) * 0.85, this.ball[0], 0.22);
      }
      const y = clamp(yr + (br - 52) * 0.3, mine ? 3 : 8, L - 6); // 守っていてもゴール前に張り付かない
      return [clamp(x, 2, W - 2), away ? L - y : y];
    }

    // ----- 場面：コマを台本にする -----
    // そのコマでボールに触っている子（air: 頭で触れる高さまで見る）
    holderOf(f, air) {
      let best = null;
      let bd = 2.6;
      if ((f.ball[2] || 0) > (air ? 3.6 : 1.6)) return null;
      for (const id of Object.keys(f.pos)) {
        const d = dist(f.pos[id], f.ball);
        if (d < bd) { bd = d; best = id; }
      }
      return best;
    }
    startScene(sc) {
      const fr = sc.frames || [];
      this.scene = sc;
      this.t = 0;
      this.idle = null;
      this.focus = Object.values(sc.actors || {});
      this.defFocus = sc.defs || [];
      this.flash = 0;
      this.trails = [];
      this.stgt = {};
      if (!fr.length) { sc.dur = 0.5; return; }
      // 台本：コマ k → k+1 を1つの出来事に
      const ev = [];
      for (let k = 0; k + 1 < fr.length; k++) {
        const a = fr[k];
        const b = fr[k + 1];
        const ha = this.holderOf(a, true);
        let hb = this.holderOf(b, true);
        // 少し離れていても、落ちる所のいちばん近くにいる子が受け手（走り込んで合わせる）
        if (!hb && (b.ball[2] || 0) <= 3.6 && b.ball[1] > 0 && b.ball[1] < L) {
          let bd = 4.5;
          for (const id of Object.keys(b.pos)) { const dd = dist(b.pos[id], b.ball); if (id !== ha && dd < bd) { bd = dd; hb = id; } }
        }
        // 落ちた所に誰もいなければ、次のコマでその近くで触る子が受け手（こぼれ球・カット）
        if (!hb && fr[k + 2]) {
          const hc = this.holderOf(fr[k + 2], true);
          if (hc && hc !== ha && dist(fr[k + 2].ball, b.ball) < 6) hb = hc;
        }
        const d = dist(a.ball, b.ball);
        let kind = 'kick';
        if (d < 1.2) kind = 'wait';
        else if (ha && (hb === ha || (!hb && d < 10 && (b.ball[2] || 0) < 0.5))) kind = 'dribble';
        ev.push({ k, kind, a, b, who: ha, recv: hb && hb !== ha ? hb : null, to: b.ball, minDur: Math.max(0.35, b.t - a.t) });
      }
      this.ev = ev;
      this.evI = -1;
      // 実況：元の時刻から、どのコマのあいだかを覚えておき、そのコマの出来事が始まったら出す
      for (const bt of sc.beats || []) {
        if (bt.at0 == null) bt.at0 = bt.at;
        let k = 0;
        for (let i = 0; i < fr.length; i++) if (fr[i].t <= bt.at0 + 1e-6) k = i;
        bt.k = Math.min(k, Math.max(0, ev.length - 1));
        bt.late = k >= ev.length && ev.length > 0; // 最後のコマのあと
        bt.at = bt.at0 <= 0 ? 0 : 1e9;
      }
      sc.dur = 1e9; // 終わりは動きが終わってから決める
      // つなぎ方：場面の最初の位置が遠ければ、一瞬暗くして置き直す
      const f0 = fr[0];
      let far = dist(f0.ball, this.ball);
      for (const id of Object.keys(f0.pos)) if (this.disp[id]) far = Math.max(far, dist(f0.pos[id], this.disp[id]) * 0.8);
      if (far > 7 || !Object.keys(this.disp).length) {
        this.cut = 0.5;
        this.ball = [f0.ball[0], f0.ball[1], f0.ball[2] || 0];
        this.bv = [0, 0];
        this.fl = null;
        this.base = this.basePositions();
        for (const id of Object.keys(this.base)) {
          this.disp[id] = f0.pos[id] ? f0.pos[id].slice() : this.shapePos(id);
          this.vel[id] = [0, 0];
        }
        // あとのコマで初めて出てくる子（カットに来る守備者など）は、そこへ走って間に合う所に置く
        const seen = new Set(Object.keys(f0.pos));
        for (const f of fr) {
          for (const id of Object.keys(f.pos)) {
            if (seen.has(id) || !this.base[id]) continue;
            seen.add(id);
            const sh = this.disp[id];
            const tgt = f.pos[id];
            const d = dist(sh, tgt);
            const can = MOVE.sprint * 0.7 * Math.max(0.6, f.t);
            if (d > can) this.disp[id] = [tgt[0] + ((sh[0] - tgt[0]) * can) / d, tgt[1] + ((sh[1] - tgt[1]) * can) / d];
          }
        }
        this.owner = this.holderOf(f0);
      }
      this.capText = null;
      this.nextEvent();
    }
    endScene() {
      this.scene = null;
      this.ev = null;
      this.expect = null;
      this.focus = [];
      this.defFocus = [];
      this.capText = null;
      this.idle = null; // 合間は、ボールのいちばん近くの子が続ける
    }
    nextEvent() {
      const sc = this.scene;
      this.evI++;
      const e = this.ev[this.evI];
      if (!e) {
        // 台本の終わり：ボールが落ち着くのを少し待って場面を閉じる
        this.settle = 0.9;
        for (const bt of sc.beats || []) if (bt.at >= 1e9) bt.at = this.t;
        return;
      }
      e.t = 0;
      e.phase = 'reach';
      if (e.a.cap) this.capText = { text: e.a.cap, t: 0 };
      for (const bt of sc.beats || []) if (bt.k === e.k && !bt.late && bt.at >= 1e9) bt.at = this.t;
      // 主役の行き先：このあとのコマで最初に出てくる所（まだ先の出番でも、そこへ向かって走り出す）
      const fr = sc.frames;
      const set = new Set();
      for (let j = e.k + 1; j < fr.length; j++) for (const id of Object.keys(fr[j].pos)) if (!set.has(id)) { set.add(id); this.stgt[id] = fr[j].pos[id]; }
      for (const id of Object.keys(e.a.pos)) if (!set.has(id) && !this.stgt[id]) this.stgt[id] = e.a.pos[id];
      // 触る子：コマで持っている子。いなければ（こぼれ球など）、いまの持ち主
      e.kicker = e.who || this.owner;
      this.expect = e.kicker;
    }
    // 1つの出来事を進める
    runEvent(dt) {
      const e = this.ev && this.ev[this.evI];
      if (!e) {
        this.settle -= dt;
        if (this.settle <= 0 || this.t > 16) this.scene.dur = this.t;
        return;
      }
      e.t += dt;
      if (this.t > 16) { this.stuck++; this.ev.length = this.evI; return; } // 念のため（動きが詰まったとき）
      const has = e.kicker && this.owner === e.kicker;
      if (e.kind === 'wait') {
        if (e.t >= e.minDur || e.t > 2.5) this.nextEvent();
        return;
      }
      if (e.phase === 'reach') {
        // 蹴る・運ぶ子がボールに触れるまで（たいていはもう持っている）
        if (has || !e.kicker || e.t > 2.6) {
          // 自分への「パス」は、受けて運ぶだけ
          if (e.kind === 'kick' && e.recv && e.recv === e.kicker) { e.kind = 'dribble'; e.phase = 'dribble'; e.t = 0; return; }
          // 誰も触れていないボールは蹴れない（外へ出た球・こぼれ球）：そのまま転がして待つ
          if (e.kind === 'kick' && (!e.kicker || dist(this.disp[e.kicker] || [1e9, 1e9], this.ball) > MOVE.reach * 1.6)) { e.kind = 'wait'; e.t = 0; return; }
          e.phase = e.kind;
          e.t = 0;
          if (e.kind === 'kick') this.kick(e.to, e.recv, e.kicker);
        }
        return;
      }
      if (e.phase === 'dribble') {
        const p = this.disp[e.kicker];
        if (!p || dist(p, e.to) < 1.8 || e.t > 4) this.nextEvent();
        return;
      }
      // 蹴ったあと：届いて受け手が触る（受け手がいなければ落ち着くまで）
      if (this.fl) return;
      if (e.recv) {
        if (this.owner === e.recv) this.nextEvent();
        else if (e.t > 6) { this.stuck++; this.expect = null; this.nextEvent(); }
        return;
      }
      if (Math.hypot(this.bv[0], this.bv[1]) < 2 || e.t > 4) this.nextEvent();
    }

    // ----- ボール -----
    // to に向けて蹴る。届く時刻は物理で決まる（転がる・浮かす・シュート）
    kick(to, recv, by) {
      const from = this.ball.slice();
      const d = Math.max(0.5, dist(from, to));
      const z1 = Math.max(0, to[2] || 0);
      const shotLike = to[1] < 0.5 || to[1] > L - 0.5;
      let kind = 'ground';
      let T;
      let v0 = 0;
      if (shotLike) {
        kind = 'shot';
        // 結果に合わせて狙いを枠に収める：得点は枠の中、外れは枠の外（横か上）
        const oc = this.scene && this.scene.outcome;
        if (oc === 'goal') { to = [clamp(to[0], 34 - 2.6, 34 + 2.6), to[1] < L / 2 ? -1.8 : L + 1.8, Math.min(z1, 2.1)]; } // 網の奥まで
        else if (oc === 'missed' && Math.abs(to[0] - 34) < 3.9 && z1 < 2.6) to = [to[0], to[1], 2.9];
        T = dist(from, to) / MOVE.shot;
      } else {
        v0 = Math.sqrt(MOVE.passEnd * MOVE.passEnd + 2 * MOVE.fric * d);
        if (z1 > 0.8 || v0 > MOVE.maxGround) {
          kind = 'loft';
          T = d / MOVE.loft + 0.25;
        } else T = (v0 - MOVE.passEnd) / MOVE.fric;
      }
      const h = kind === 'loft' ? Math.min(9, 1.2 + d * 0.16) : kind === 'shot' ? Math.min(1.4, d * 0.04) : 0;
      this.fl = { from, to: [to[0], to[1], Math.max(0, to[2] || 0)], d: Math.max(0.5, dist(from, to)), T: Math.max(0.15, T), t: 0, kind, v0, h, z0: from[2] || 0 };
      if (by) this.lock[by] = 0.3;
      this.owner = null;
      this.expect = recv || null;
      this.kicks++;
      this.kicked = true;
      this.trails.push({ from: from.slice(0, 2), to: [to[0], to[1]], life: 1, kind });
      if (this.trails.length > 4) this.trails.shift();
    }
    stepBall(dt) {
      const fl = this.fl;
      if (fl) {
        fl.t += dt;
        const u = clamp(fl.t / fl.T, 0, 1);
        const dx = (fl.to[0] - fl.from[0]) / fl.d;
        const dy = (fl.to[1] - fl.from[1]) / fl.d;
        let s;
        if (fl.kind === 'ground') {
          const tt = Math.min(fl.t, fl.T);
          s = Math.min(fl.d, fl.v0 * tt - 0.5 * MOVE.fric * tt * tt);
        } else s = fl.d * u;
        const z = fl.kind === 'ground' ? 0 : lerp(fl.z0, fl.to[2], u) + fl.h * 4 * u * (1 - u);
        this.ball = [fl.from[0] + dx * s, fl.from[1] + dy * s, Math.max(0, z)];
        if (u >= 1) {
          // 届いた：そのまま少し転がる（シュートはネットか、ラインの外へ）
          // 浮き球は弾んで少し遅くなるだけ（急に止まらない）
          const vEnd = fl.kind === 'ground' ? MOVE.passEnd : fl.kind === 'loft' ? MOVE.loft * 0.72 : MOVE.shot * 0.95;
          this.bv = [dx * vEnd, dy * vEnd];
          this.ball[2] = fl.kind === 'shot' ? fl.to[2] : 0;
          this.fl = null;
          // 届いたあとの残りの時間は転がす（届いたコマで止まって見えないように）
          const over = fl.t - fl.T;
          if (over > 0) this.roll(over);
        }
        return;
      }
      if (this.owner && this.disp[this.owner]) {
        // 足元：進む向きの少し前。触った瞬間に飛ばないよう、寄せて合わせる
        const p = this.disp[this.owner];
        const v = this.vel[this.owner] || [0, 0];
        const sp = Math.hypot(v[0], v[1]);
        const f = sp > 0.5 ? [v[0] / sp, v[1] / sp] : this.atkDir(this.owner);
        const tgt = [p[0] + f[0] * 0.65, p[1] + f[1] * 0.65];
        const k = 1 - Math.exp(-dt * 12);
        const nb = [lerp(this.ball[0], tgt[0], k), lerp(this.ball[1], tgt[1], k), Math.max(0, (this.ball[2] || 0) - dt * 7)];
        this.bv = [(nb[0] - this.ball[0]) / Math.max(dt, 1e-3), (nb[1] - this.ball[1]) / Math.max(dt, 1e-3)];
        this.ball = nb;
        return;
      }
      this.roll(dt);
    }
    // 転がる：だんだん遅くなる。ゴールの中ではネットで止まる
    roll(dt) {
      const sp = Math.hypot(this.bv[0], this.bv[1]);
      const b0 = this.ball;
      const inNet = Math.abs(b0[0] - 34) < 3.66 && ((b0[1] < 0 && b0[1] > -2.2) || (b0[1] > L && b0[1] < L + 2.2));
      if (sp > 0) {
        // ネットに入った球は網に受け止められて、すぐに止まる
        const outside = b0[0] < -0.5 || b0[0] > W + 0.5 || b0[1] < -0.5 || b0[1] > L + 0.5;
        const ns = Math.max(0, sp - (inNet ? 60 : outside ? 30 : MOVE.fric * 1.4) * dt); // 外は看板の手前で止まる
        this.bv = [(this.bv[0] / sp) * ns, (this.bv[1] / sp) * ns];
      }
      const b = this.ball;
      let nx = b[0] + this.bv[0] * dt;
      let ny = b[1] + this.bv[1] * dt;
      const inMouth = Math.abs(b[0] - 34) < 3.66;
      if (inMouth && ((b[1] >= -2 && ny < -2) || (b[1] <= L + 2 && ny > L + 2))) {
        ny = ny < 0 ? -2 : L + 2; // 網の奥
        this.bv = [0, 0];
      }
      const z = Math.max(0, (b[2] || 0) - dt * 6);
      this.ball = [nx, ny, z];
    }
    atkDir(id) {
      const t = this.teamOf(id);
      return [0, t && this.match && t === this.match.away ? -1 : 1];
    }
    // ボールに触れる子がいれば持たせる
    pickup() {
      if (this.fl) return;
      const zMax = this.scene && this.expect ? 3.6 : 1.3; // 場面の受け手は頭でも触る
      const b = this.ball;
      const out = b[0] < -0.3 || b[0] > W + 0.3 || b[1] < -0.3 || b[1] > L + 0.3;
      if (out) return;
      let best = null;
      let bd = MOVE.reach;
      for (const id of Object.keys(this.disp)) {
        if (this.lock[id] > 0 || id === this.owner) continue;
        if (this.scene && id !== this.expect) continue; // 場面では台本の子だけが触る
        if ((b[2] || 0) > zMax) continue;
        const d = dist(this.disp[id], b);
        if (d < bd) { bd = d; best = id; }
      }
      if (!best) return;
      if (this.owner && !this.scene) return; // 合間は奪い合わない（相手に渡るのはパスの失敗だけ）
      this.owner = best;
      this.poss = this.teamOf(best) === this.match.home ? 'home' : 'away';
      if (!this.scene && this.idle && this.idle.recv === best) this.idle = null;
    }

    // ----- 合間：持っている子が運び、味方へつなぐ -----
    idlePlay(dt) {
      const ids = Object.keys(this.base);
      const b = this.ball;
      const out = b[0] < -0.5 || b[0] > W + 0.5 || b[1] < -0.5 || b[1] > L + 0.5;
      if (out && !this.fl && this.cut <= 0) return this.restart();
      if (this.fl) return;
      if (!this.owner) return; // 誰かが拾いに行く（targets で）
      // 持ってから出すまでの時間は攻めの速さで決まる（縦に速いは早く、ポゼッションはためる）
      const tc = this.tacOf(this.owner);
      const s = (this.idle = this.idle && this.idle.carrier === this.owner ? this.idle : { carrier: this.owner, t: 0, dur: 0.5 + (1 - tc.tempo) * 1.6 + Math.random() * (0.6 + (1 - tc.tempo) * 1.2) });
      s.t += dt;
      if (s.t < s.dur) return;
      const me = this.owner;
      const my = this.teamOf(me);
      const q = this.disp[me];
      const atk = this.atkDir(me)[1];
      const back = 4 + (1 - tc.tempo) * 16; // 後ろへ戻してよい距離
      const far = 22 + tc.tempo * 14; // 速い攻めほど遠くへ蹴る
      let tgt = null;
      if (Math.random() < 0.14) {
        // 相手に渡ってしまうパス
        let bd = 30;
        for (const id of ids) if (this.teamOf(id) !== my && this.base[id][3] !== 0) { const d = dist(this.disp[id], q); if (d < bd && d > 5) { bd = d; tgt = id; } }
      } else {
        const pick = (bk, fr) => ids.filter((id) => {
          if (id === me || this.teamOf(id) !== my) return false;
          const r = this.disp[id];
          const d = dist(r, q);
          return d > 7 && d < fr && (r[1] - q[1]) * atk > -bk;
        });
        let c = pick(back, far);
        if (!c.length) c = pick(20, 30); // 前に出せる味方がいなければ戻してでもつなぐ
        // 前の味方ほど選ばれやすい（速い攻めほど強く）
        const wt = c.map((id) => 1 + Math.max(0, (this.disp[id][1] - q[1]) * atk) * tc.tempo * 0.2);
        let r0 = Math.random() * wt.reduce((a, x) => a + x, 0);
        for (let i = 0; i < c.length && !tgt; i++) if ((r0 -= wt[i]) <= 0) tgt = c[i];
        if (!tgt && c.length) tgt = c[c.length - 1];
      }
      if (!tgt) { s.t = 0; return; }
      // 受け手の少し前（走り込む先）へ
      const r = this.disp[tgt];
      const v = this.vel[tgt] || [0, 0];
      const to = [clamp(r[0] + v[0] * 0.6, 1, W - 1), clamp(r[1] + v[1] * 0.6, 1, L - 1), 0];
      this.kick(to, tgt, me);
      this.idle = { recv: tgt, to };
    }
    // ボールが外に出た：一瞬暗くして再開（ゴールなら真ん中、ゴールラインならゴールキック、横ならスローイン）
    restart() {
      const b = this.ball;
      const m = this.match;
      this.cut = 0.5;
      this.bv = [0, 0];
      this.fl = null;
      this.idle = null;
      let pos;
      let who = null;
      const goal = Math.abs(b[0] - 34) < 3.7 && ((b[1] < 0 && b[1] > -2.3) || (b[1] > L && b[1] < L + 2.3));
      for (const id of Object.keys(this.base)) { this.disp[id] = this.shapePos(id); this.vel[id] = [0, 0]; }
      if (goal) {
        pos = [34, L / 2];
        const conceded = b[1] < 0 ? m.home : m.away; // y=0 側はホームのゴール
        who = Object.keys(this.base).filter((id) => this.base[id][2] === conceded).sort((x, y) => this.base[y][1] * (conceded === m.home ? 1 : -1) - this.base[x][1] * (conceded === m.home ? 1 : -1))[0];
      } else if (b[1] < 0 || b[1] > L) {
        const t = b[1] < 0 ? m.home : m.away;
        pos = [34, b[1] < 0 ? 6 : L - 6];
        who = Object.keys(this.base).find((id) => this.base[id][2] === t && this.base[id][3] === 0);
      } else {
        pos = [clamp(b[0], 0.6, W - 0.6), clamp(b[1], 2, L - 2)];
        let bd = 1e9;
        for (const id of Object.keys(this.base)) { const d = dist(this.disp[id], pos); if (d < bd && this.base[id][3] !== 0) { bd = d; who = id; } }
      }
      this.ball = [pos[0], pos[1], 0];
      if (who) {
        this.disp[who] = [pos[0] + (pos[0] < 1 ? -0.6 : pos[0] > W - 1 ? 0.6 : 0), pos[1] - this.atkDir(who)[1] * 0.6];
        this.owner = who;
        this.poss = this.teamOf(who) === m.home ? 'home' : 'away';
      }
    }

    // ----- 選手：目標へ加速・減速して走る -----
    targetOf(id) {
      const e = this.scene && this.ev && this.ev[this.evI];
      const ball = this.ball;
      // ボールを持っている子
      if (id === this.owner) {
        if (e && (e.phase === 'dribble' || e.phase === 'reach') && e.kind === 'dribble' && e.kicker === id) return [e.to, MOVE.dribble, true];
        if (e && this.stgt[id] && e.kind !== 'kick') return [this.stgt[id], MOVE.dribble];
        if (!this.scene) {
          const q = this.disp[id];
          const atk = this.atkDir(id)[1];
          return [[clamp(q[0] + (34 - q[0]) * 0.05, 4, W - 4), clamp(q[1] + atk * 3, 6, L - 6)], 2.8 + this.tacOf(id).tempo * 2.4];
        }
        return [this.disp[id], 0];
      }
      // 次に触る子：ボールの行く先（飛んでいれば落ちる所、転がっていればボール）へ
      if (this.expect === id) {
        if (this.fl) return [[this.fl.to[0], this.fl.to[1]], MOVE.sprint];
        return [[ball[0], ball[1]], MOVE.sprint];
      }
      if (this.scene) {
        if (this.stgt[id]) return [this.stgt[id], MOVE.sprint];
        return [this.shapePos(id), MOVE.jog * 0.85];
      }
      // 合間：パスを受ける子は落ちる所へ。誰も持っていなければ、いちばん近い子が拾いに行く
      if (this.idle && this.idle.recv === id && this.fl) return [[this.fl.to[0], this.fl.to[1]], MOVE.sprint];
      if (!this.owner && !this.fl && this.chaser === id) return [[ball[0], ball[1]], MOVE.sprint];
      // プレス：持っている相手へ寄せる（1人目は正面、2人目は内側を切る）。奪いはしない
      const pr = this.pressers && this.pressers[id];
      if (pr) return pr;
      return [this.shapePos(id), MOVE.jog];
    }
    // 守る側の誰が、どこまで寄せるか。プレスが強いほど遠くから・速く・2人で行く
    pressPlan() {
      const me = this.owner;
      const q = this.disp[me];
      if (!q) return null;
      const my = this.teamOf(me);
      const ids = Object.keys(this.base).filter((id) => this.teamOf(id) !== my && this.base[id][3] !== 0 && this.disp[id]);
      if (!ids.length) return null;
      const tc = this.tacOf(ids[0]);
      const reach = 4 + tc.press * 30;
      const gap = 1.6 + (1 - tc.press) * 3; // 弱いプレスは間合いを取って待つ
      const n = tc.press >= 0.7 ? 2 : 1;
      const score = (id) => {
        const s = this.base[id][4] || {};
        const tags = (YA.ROLE_DEF && YA.ROLE_DEF[s.role] && YA.ROLE_DEF[s.role].tags) || [];
        return dist(this.disp[id], q) - (tags.indexOf('press') >= 0 ? 5 : 0) - (s.duty === 'stop' ? 3 : 0) + (s.duty === 'def' || s.duty === 'cover' ? 3 : 0);
      };
      const near = ids.filter((id) => dist(this.disp[id], q) < reach).sort((a, b) => score(a) - score(b)).slice(0, n);
      if (!near.length) return null;
      const g = this.atkDir(me)[1]; // 持っている子が攻める向き＝守る側のゴールの向き
      const v = MOVE.jog * 0.8 + tc.press * (MOVE.sprint - MOVE.jog * 0.8);
      const out = {};
      near.forEach((id, i) => {
        // 1人目は正面、2人目は内側（中央寄り）を 4m 後ろで切る
        const tg = i === 0 ? [q[0], q[1] + g * gap] : [lerp(q[0], 34, 0.35), q[1] + g * 4];
        out[id] = [[clamp(tg[0], 1, W - 1), clamp(tg[1], 1, L - 1)], v];
      });
      return out;
    }
    stepPlayers(dt) {
      // 誰も持っていない転がるボールを追う子（合間だけ）
      this.chaser = null;
      if (!this.scene && !this.owner) {
        let bd = 1e9;
        for (const id of Object.keys(this.disp)) { const d = dist(this.disp[id], this.ball); if (d < bd && this.base[id] && this.base[id][3] !== 0) { bd = d; this.chaser = id; } }
      }
      this.pressers = this.scene || !this.owner || this.fl ? null : this.pressPlan();
      for (const id of Object.keys(this.base)) {
        if (!this.disp[id]) { this.disp[id] = this.shapePos(id); this.vel[id] = [0, 0]; }
        const p = this.disp[id];
        const v = this.vel[id] || [0, 0];
        const [tg, vmax, thru] = this.targetOf(id);
        const dx = tg[0] - p[0];
        const dy = tg[1] - p[1];
        const dd = Math.hypot(dx, dy);
        // 着く前に減速する（止まりたい所で止まれる速さ）
        const want = dd > 0.05 ? (thru ? vmax : Math.min(vmax, Math.sqrt(2 * MOVE.acc * 0.85 * dd))) : 0; // thru：通り道の点では止まらない
        const dv = [(dd > 0.05 ? (dx / dd) * want : 0) - v[0], (dd > 0.05 ? (dy / dd) * want : 0) - v[1]];
        const dvn = Math.hypot(dv[0], dv[1]);
        const mx = MOVE.acc * dt;
        if (dvn > mx) { dv[0] *= mx / dvn; dv[1] *= mx / dvn; }
        const nv = [v[0] + dv[0], v[1] + dv[1]];
        this.vel[id] = nv;
        this.disp[id] = [clamp(p[0] + nv[0] * dt, -3, W + 3), clamp(p[1] + nv[1] * dt, -2.5, L + 2.5)];
        this.speed[id] = Math.hypot(nv[0], nv[1]);
        if (this.lock[id] > 0) this.lock[id] -= dt;
      }
    }

    update(dt) {
      const m = this.match;
      if (!m) return;
      this.kicked = false;
      this.clock = (this.clock || 0) + dt;
      this.base = this.basePositions();
      for (const id of Object.keys(this.disp)) if (!this.base[id]) { delete this.disp[id]; delete this.vel[id]; if (this.owner === id) this.owner = null; }
      if (this.scene) {
        this.t += dt;
        this.runEvent(dt);
        if (this.scene && this.scene.outcome === 'goal' && (this.ball[1] < -0.2 || this.ball[1] > L + 0.2)) this.flash = Math.min(1, this.flash + dt * 2);
      } else {
        this.idlePlay(dt);
        this.flash = 0;
      }
      if (this.cut > 0) this.cut = Math.max(0, this.cut - dt);
      this.stepPlayers(dt);
      this.stepBall(dt);
      this.pickup();
      for (const tr of this.trails) tr.life -= dt * (this.fl ? 0.25 : 1.2);
      this.trails = this.trails.filter((tr) => tr.life > 0);
      if (this.capText) this.capText.t += dt;
      // 見る場所：場面では少し寄って、ボールを追う
      const c = this.cam;
      const k = 1 - Math.exp(-dt * 2.2);
      const zw = this.scene ? 1.45 : 1;
      c.zoom += (zw - c.zoom) * (1 - Math.exp(-dt * 1.6));
      c.cy += (this.ball[1] - c.cy) * k;
      c.cx += (this.ball[0] - c.cx) * k;
      if (this.cut > 0.3) { c.cy = this.ball[1]; c.cx = this.ball[0]; }
    }

    // 両チームのユニフォーム（クラブ名から。色が近ければアウェイが替えを着る）
    kitsOf() {
      if (this.kits || !this.match) return this.kits;
      const m = this.match;
      const def = (t, gk) => ({ shirt: t.color, shorts: '#ffffff', socks: t.color, acc: '#ffffff', gk });
      const h = YA.kitOf ? YA.kitOf(m.home.name) : def(m.home, '#f39c12');
      let a = YA.kitOf ? YA.kitOf(m.away.name) : def(m.away, '#8e44ad');
      if (YA.awayKit) a = YA.awayKit(h, a);
      if (YA.colorDist && YA.colorDist(a.gk, h.gk) < 90) a = Object.assign({}, a, { gk: h.gk === '#222222' ? '#f2a900' : '#222222' });
      m.home.color = h.shirt;
      m.away.color = a.shirt;
      this.kits = { home: h, away: a };
      return this.kits;
    }

    // ----- 絵：ピッチを横に寝かせる（ホームは右へ攻める）。画面の横＝縦の長さ y、画面の縦＝幅 x -----
    view() {
      const w = this.w;
      const h = this.h;
      const fit = Math.min((w - 16) / (L + 8), (h - 10) / (W + 6));
      const s = fit * this.cam.zoom;
      // 見える範囲がピッチからはみ出しすぎないように中心を寄せる
      const halfX = w / 2 / s;
      const halfY = h / 2 / s;
      const cy = halfX * 2 >= L + 8 ? L / 2 : clamp(this.cam.cy, halfX - 4, L + 4 - halfX);
      const cx = halfY * 2 >= W + 6 ? W / 2 : clamp(this.cam.cx, halfY - 3, W + 3 - halfY);
      return { s, P: (x, y) => [w / 2 + (y - cy) * s, h / 2 + (x - cx) * s] };
    }
    draw() {
      const ctx = this.ctx;
      if (!ctx) return;
      ctx.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);
      const w = this.w;
      const h = this.h;
      const { s, P } = this.view();
      const kits = this.kitsOf();
      ctx.fillStyle = '#16301f';
      ctx.fillRect(0, 0, w, h);
      // 芝：ゴールラインと平行の帯
      const rect = (x0, y0, x1, y1) => { const a = P(x0, y0); const b = P(x1, y1); return [Math.min(a[0], b[0]), Math.min(a[1], b[1]), Math.abs(b[0] - a[0]), Math.abs(b[1] - a[1])]; };
      ctx.fillStyle = '#2f7a3b';
      ctx.fillRect(...rect(-3, -3, W + 3, L + 3));
      for (let i = 0; i < 14; i++) {
        if (i % 2) continue;
        ctx.fillStyle = '#358544';
        ctx.fillRect(...rect(0, (L / 14) * i, W, (L / 14) * (i + 1)));
      }
      // 線
      ctx.strokeStyle = 'rgba(255,255,255,.85)';
      ctx.lineWidth = Math.max(1, s * 0.14);
      const line = (pts, close) => {
        ctx.beginPath();
        pts.forEach((p, i) => { const q = P(p[0], p[1]); i ? ctx.lineTo(q[0], q[1]) : ctx.moveTo(q[0], q[1]); });
        if (close) ctx.closePath();
        ctx.stroke();
      };
      const circ = (x, y, r, a0, a1) => { const q = P(x, y); ctx.beginPath(); ctx.arc(q[0], q[1], r * s, a0 || 0, a1 == null ? Math.PI * 2 : a1); ctx.stroke(); };
      const spot = (x, y) => { const q = P(x, y); ctx.fillStyle = 'rgba(255,255,255,.85)'; ctx.beginPath(); ctx.arc(q[0], q[1], Math.max(1.2, s * 0.25), 0, Math.PI * 2); ctx.fill(); };
      line([[0, 0], [W, 0], [W, L], [0, L]], true);
      line([[0, L / 2], [W, L / 2]]);
      circ(34, L / 2, 9.15);
      spot(34, L / 2);
      for (const sg of [0, 1]) {
        const y = (v) => (sg ? L - v : v);
        line([[13.84, y(0)], [13.84, y(16.5)], [54.16, y(16.5)], [54.16, y(0)]]);
        line([[24.84, y(0)], [24.84, y(5.5)], [43.16, y(5.5)], [43.16, y(0)]]);
        spot(34, y(11));
        const a = Math.acos(5.5 / 9.15);
        // 画面では y が横なので、アークは左右を向く
        if (sg) circ(34, y(11), 9.15, Math.PI - a, Math.PI + a);
        else circ(34, y(11), 9.15, -a, a);
        // ゴール：枠の外に少し出た網
        const g0 = P(34 - 3.66, y(0));
        const g1 = P(34 + 3.66, y(sg ? -2 : -2));
        ctx.fillStyle = 'rgba(255,255,255,.16)';
        ctx.fillRect(Math.min(g0[0], g1[0]), Math.min(g0[1], g1[1]), Math.abs(g1[0] - g0[0]), Math.abs(g1[1] - g0[1]));
        ctx.strokeStyle = 'rgba(255,255,255,.95)';
        ctx.lineWidth = Math.max(1.5, s * 0.22);
        line([[34 - 3.66, y(0)], [34 - 3.66, y(-2)], [34 + 3.66, y(-2)], [34 + 3.66, y(0)]]);
        ctx.strokeStyle = 'rgba(255,255,255,.85)';
        ctx.lineWidth = Math.max(1, s * 0.14);
      }
      // パスの線：蹴った所から行き先へ（ボードの矢印のように）
      for (const tr of this.trails) {
        const a = P(tr.from[0], tr.from[1]);
        const b = P(tr.to[0], tr.to[1]);
        ctx.strokeStyle = tr.kind === 'shot' ? 'rgba(255,214,80,' + 0.85 * tr.life + ')' : 'rgba(255,255,255,' + 0.6 * tr.life + ')';
        ctx.lineWidth = Math.max(1.2, s * 0.22);
        if (ctx.setLineDash) ctx.setLineDash(tr.kind === 'loft' ? [s * 0.9, s * 0.7] : []);
        ctx.beginPath();
        ctx.moveTo(a[0], a[1]);
        ctx.lineTo(b[0], b[1]);
        ctx.stroke();
        if (ctx.setLineDash) ctx.setLineDash([]);
        ctx.fillStyle = ctx.strokeStyle;
        ctx.beginPath();
        ctx.arc(b[0], b[1], Math.max(2, s * 0.45), 0, Math.PI * 2);
        ctx.fill();
      }
      // 選手
      const m = this.match;
      if (m) {
        const R = Math.max(7, s * 1.65);
        const order = Object.keys(this.base).sort((a, b) => (this.focus.includes(a) ? 1 : 0) - (this.focus.includes(b) ? 1 : 0));
        const labels = [];
        for (const id of order) {
          const b = this.base[id];
          const t = b[2];
          const p = t.players[id];
          const d = this.disp[id] || b;
          const gk = b[3] === 0;
          const kit = kits ? (t === m.home ? kits.home : kits.away) : { shirt: t.color || '#888', shorts: '#fff', gk: '#f39c12' };
          const fill = gk ? kit.gk : kit.shirt;
          const q = P(d[0], d[1]);
          const isF = this.focus.includes(id);
          const isD = this.defFocus && this.defFocus.includes(id);
          // 影
          ctx.fillStyle = 'rgba(0,0,0,.25)';
          ctx.beginPath();
          ctx.arc(q[0] + R * 0.18, q[1] + R * 0.22, R, 0, Math.PI * 2);
          ctx.fill();
          // 向き（走っている向きに小さな三角）
          const v = this.vel[id] || [0, 0];
          const sp = Math.hypot(v[0], v[1]);
          const f = sp > 0.4 ? [v[1] / sp, v[0] / sp] : this.atkDir(id).slice().reverse();
          ctx.fillStyle = fill;
          ctx.beginPath();
          ctx.moveTo(q[0] + f[0] * R * 1.55, q[1] + f[1] * R * 1.55);
          ctx.lineTo(q[0] - f[1] * R * 0.7, q[1] + f[0] * R * 0.7);
          ctx.lineTo(q[0] + f[1] * R * 0.7, q[1] - f[0] * R * 0.7);
          ctx.closePath();
          ctx.fill();
          // 体（シャツの色）と縁（パンツの色）
          ctx.beginPath();
          ctx.arc(q[0], q[1], R, 0, Math.PI * 2);
          ctx.fill();
          ctx.strokeStyle = gk ? '#1b1b1b' : kit.shorts || '#ffffff';
          ctx.lineWidth = Math.max(1.5, R * 0.22);
          ctx.stroke();
          if (isF || isD || id === this.owner) {
            ctx.strokeStyle = isF ? '#ffe14a' : id === this.owner ? 'rgba(255,255,255,.95)' : 'rgba(255,255,255,.6)';
            ctx.lineWidth = isF ? 2.4 : 1.4;
            ctx.beginPath();
            ctx.arc(q[0], q[1], R + 3, 0, Math.PI * 2);
            ctx.stroke();
          }
          // 背番号
          ctx.fillStyle = YA.colorDist && YA.colorDist(fill, '#ffffff') < 140 ? '#1b2438' : '#ffffff';
          ctx.font = '800 ' + Math.round(R * 1.05) + 'px system-ui, sans-serif';
          ctx.textAlign = 'center';
          ctx.textBaseline = 'middle';
          ctx.fillText(String(p ? p.num : ''), q[0], q[1] + 0.5);
          if (isF && this.scene && p) labels.push({ q, text: p.num + ' ' + String(p.name).split(' ')[0] });
        }
        // ボール（高いほど影から離れて大きく見える）
        const b = this.ball;
        const z = Math.max(0, b[2] || 0);
        const g = P(b[0], b[1]);
        const br = Math.max(3, s * 0.55) * (1 + z * 0.06);
        ctx.fillStyle = 'rgba(0,0,0,' + clamp(0.4 - z * 0.03, 0.12, 0.4) + ')';
        ctx.beginPath();
        ctx.arc(g[0] + 1.5, g[1] + 1.5, br * 0.9, 0, Math.PI * 2);
        ctx.fill();
        const bq = [g[0], g[1] - z * s * 0.55];
        ctx.fillStyle = '#ffffff';
        ctx.beginPath();
        ctx.arc(bq[0], bq[1], br, 0, Math.PI * 2);
        ctx.fill();
        ctx.strokeStyle = '#111';
        ctx.lineWidth = 1.2;
        ctx.stroke();
        // 名前の札（主役）
        ctx.font = '800 11px system-ui, sans-serif';
        ctx.textBaseline = 'alphabetic';
        for (const lb of labels) {
          const tw = ctx.measureText(lb.text).width + 10;
          const x = clamp(lb.q[0] - tw / 2, 2, w - tw - 2);
          const y = clamp(lb.q[1] - R - 22, 2, h - 18);
          ctx.fillStyle = 'rgba(15,25,40,.85)';
          this.rr(ctx, x, y, tw, 16, 5);
          ctx.fill();
          ctx.fillStyle = '#ffffff';
          ctx.textAlign = 'left';
          ctx.fillText(lb.text, x + 5, y + 12);
        }
      }
      // その瞬間のひとこと（「6番 スルーパス」など）
      const cp = this.capText;
      if (cp && this.scene && cp.t < 2.2) {
        ctx.font = '800 13px system-ui, sans-serif';
        const tw = ctx.measureText(cp.text).width + 18;
        const x = (w - tw) / 2;
        const y = h - 30;
        ctx.globalAlpha = clamp(Math.min(cp.t * 5, (2.2 - cp.t) * 3), 0, 1);
        ctx.fillStyle = 'rgba(15,25,40,.88)';
        this.rr(ctx, x, y, tw, 22, 11);
        ctx.fill();
        ctx.fillStyle = '#ffe14a';
        ctx.textAlign = 'center';
        ctx.fillText(cp.text, w / 2, y + 16);
        ctx.globalAlpha = 1;
      }
      if (this.flash > 0) {
        ctx.fillStyle = 'rgba(255,255,255,' + 0.22 * Math.sin(this.flash * 3) + ')';
        ctx.fillRect(0, 0, w, h);
      }
      // 場面の切り替え・再開は一瞬暗くする
      if (this.cut > 0) {
        ctx.fillStyle = 'rgba(8,12,20,' + clamp(this.cut / 0.3, 0, 1) + ')';
        ctx.fillRect(0, 0, w, h);
      }
    }
    rr(ctx, x, y, w, h, r) {
      ctx.beginPath();
      ctx.moveTo(x + r, y);
      ctx.arcTo(x + w, y, x + w, y + h, r);
      ctx.arcTo(x + w, y + h, x, y + h, r);
      ctx.arcTo(x, y + h, x, y, r);
      ctx.arcTo(x, y, x + w, y, r);
      ctx.closePath();
    }
  }
  YA.Renderer = Renderer;
})();
