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
    fric: 4, // 転がるボールの減速（m/s²）
    passEnd: 11, // 地を這うパスが受け手に届くときの速さ（20m を約1.5秒で通す）
    loft: 19.5, // 浮き球の横の速さ
    shot: 25, // シュートの速さ
    maxGround: 23, // これより強く蹴らないと届かないなら浮かせる
    ff: 2.6, // 場面の入りの早送りの倍率
    space: 2.2, // これより近づくと離れようとする
    tackle: 2.4, // 寄せた子がこの距離に入ると、奪いにいく
    celeb: 3.2, // 得点の喜びの長さ（秒。ボールが網に入ってから再開まで）
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
      this.dive = null; // シュートに飛ぶ GK
      this.celeb = null; // 得点の喜び
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
    // 試合の流れ：そのチームが押している割合（0.2〜0.8）。エンジンの力の差・得点差・時間に、直前の場面の勢いを足す
    shareOf(id) {
      const t = this.teamOf(id);
      const f = this.flow == null ? 0.5 : this.flow;
      return t && this.match && t === this.match.away ? 1 - f : f;
    }
    // 次の見どころが近い（2分以内）とき、押している側が攻め上がる
    surgeOf(id) {
      return this.surge && this.shareOf(id) > 0.5;
    }
    // 選手の能力（1〜20）。疲れ・調子・役割の合い方を含んだ試合での値（エンジンの eff と同じ）
    abOf(id, n) {
      const t = this.teamOf(id);
      const p = t && t.players && t.players[id];
      if (!p || !p.ab) return 10;
      return YA.eff ? YA.eff(p, n, this.match) : p.ab[n] || 10;
    }
    // 能力から決まる動きの倍率（10 が基準）。最高速はスピード、加速は加速、運ぶ速さはドリブル
    moveK(id) {
      const c = (this._mk = this._mk || {});
      const e = c[id];
      if (e) return e; // 30 コマごとに読み直す（step1）
      const k = (n, lo, hi) => clamp(lo + ((this.abOf(id, n) - 1) / 19) * (hi - lo), lo, hi);
      const out = { run: k('スピード', 0.72, 1.12), acc: k('加速', 0.75, 1.2), drib: k('ドリブル', 0.78, 1.12) };
      c[id] = out;
      return out;
    }
    // 能力を 0〜1 に（1→0、20→1）
    ab01(id, n) {
      return clamp((this.abOf(id, n) - 1) / 19, 0, 1);
    }
    tacOf(id) {
      const t = this.teamOf(id);
      return Object.assign({ tempo: 0.5, width: 0.5, line: 0.5, press: 0.5 }, t && t.tactic);
    }
    // ボールの位置に合わせてチーム全体が寄る位置。戦い方と役割で、持っているときと守るときの形が変わる
    // チームの並びの前後の幅（GK を除く、自分のゴールからの深さ）
    spanOf(t) {
      const c = (this._span = this._span && this._span.at === this.clockI ? this._span : { at: this.clockI });
      const k = t === this.match.away ? 'away' : 'home';
      if (c[k]) return c[k];
      const away = k === 'away';
      const ds = Object.keys(this.base).filter((id) => this.base[id][2] === t && this.base[id][3] !== 0).map((id) => (away ? L - this.base[id][1] : this.base[id][1]));
      c[k] = { lo: Math.min(...ds), hi: Math.max(...ds) };
      return c[k];
    }
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
      // 縦の位置：並びの前後（0＝最終ライン、1＝最前線）を、ボールの位置で決まる「ブロック」に当てはめる。
      //   守り：最終ラインはボールの 18〜34m 後ろ（ラインが高い戦い方ほど近い）、前後 26〜30m に固まる
      //   攻め：最終ラインはボールの 18〜30m 後ろ、前は相手の最終ラインまで伸びる
      const sp = this.spanOf(t);
      const u = clamp((yr - sp.lo) / Math.max(1, sp.hi - sp.lo), 0, 1);
      const fs = this.shareOf(id) - 0.5; // 押している側は全体が高い
      if (mine) {
        const lineD = clamp(br - 30 + tc.line * 12 + fs * 12 + (this.surgeOf(id) ? 5 : 0), 12, 58);
        yr = lineD + u * clamp(62 - lineD * 0.35 + tc.tempo * 6, 30, 50);
      } else {
        const lineD = clamp(br - 18 - (1 - tc.line) * 16 + fs * 10, 9, 46);
        yr = lineD + u * (26 + (1 - tc.press) * 4);
      }
      if (mine) {
        // 攻め：幅は戦い方の広さ（サイド攻撃は外に張る）
        x = 34 + (x - 34) * (0.8 + tc.width * 0.6);
        if (s.duty === 'att') yr += has('wide') ? 10 : 5; // 攻撃の任務のサイドは追い越して上がる
        if (s.duty === 'def' || has('stay')) yr -= 5; // 守備の任務は残る
        if (has('run')) yr += 4; // 裏を狙う
        if (has('post')) yr -= 6; // 降りて受ける
        if (has('cutin')) x = lerp(x, 34, 0.3);
        if (has('wide') && s.duty === 'att') x = 34 + (x - 34) * 1.15;
        x = lerp(x, this.ball[0], 0.1);
      } else {
        // 守り：横はボールへ絞る
        if (s.duty === 'att') yr += 4; // 攻撃の任務は戻りが遅い
        x = lerp(34 + (x - 34) * 0.85, this.ball[0], 0.22);
      }
      const y = clamp(yr, mine ? 3 : 8, L - 6); // 守っていてもゴール前に張り付かない
      return [clamp(x, 2, W - 2), away ? L - y : y];
    }

    // ----- ボールを持っていない子の動き（オフザボール） -----
    // 立ち位置（shapePos）に、そのときの相手と味方を見た動きを重ねる。
    //   攻め：相手のいない所へずれる（オフザボール）・持っている子の近くで受ける・裏を狙う・オフサイドにならない
    //   守り：近くの相手をゴール側から捕まえる（マーク）・最終ラインを横一列にそろえる（ポジショニング）
    lineInfo() {
      if (this._li && this._li.at === this.clockI) return this._li;
      const m = this.match;
      const out = { at: this.clockI, back: {}, lineD: {}, last: {} };
      for (const t of [m.home, m.away]) {
        const away = t === m.away;
        const dep = (y) => (away ? L - y : y);
        const ids = Object.keys(this.base).filter((id) => this.base[id][2] === t && this.base[id][3] !== 0 && this.disp[id]);
        if (!ids.length) continue;
        // 最終ライン：並びでいちばん後ろの子から 9m 以内（4バックなら4人、3バックなら3人）
        const bd = ids.map((id) => [id, dep(this.base[id][1])]).sort((a, b) => a[1] - b[1]);
        const back = bd.filter((x) => x[1] < bd[0][1] + 9).map((x) => x[0]);
        for (const id of back) out.back[id] = true;
        const sd = back.map((id) => dep(this.shapePos(id)[1]));
        out.lineD[away ? 'away' : 'home'] = sd.reduce((a, x) => a + x, 0) / sd.length;
        // 相手から見たこのチームの最後の守り手の位置（オフサイドの線）。いまの位置で見る
        out.last[away ? 'away' : 'home'] = Math.min(...ids.map((id) => dep(this.disp[id][1])));
      }
      this._li = out;
      return out;
    }
    offballPos(id) {
      const base = this.shapePos(id);
      const b = this.base[id];
      if (!b || b[3] === 0 || !this.match) return base;
      const my = b[2];
      const away = my === this.match.away;
      const key = away ? 'away' : 'home';
      const okey = away ? 'home' : 'away';
      const dep = (y) => (away ? L - y : y);
      const li = this.lineInfo();
      const opp = Object.keys(this.disp).filter((o) => this.base[o] && this.base[o][2] !== my && this.base[o][3] !== 0);
      let x = base[0];
      let d = dep(base[1]);
      const mine = this.poss === key;
      if (mine) {
        const ko = this.ab01(id, 'オフザボール');
        // 相手のいない所へ：近い相手から離れる（うまい子ほど大きく、横に多く動く）
        for (const o of opp) {
          const q = this.disp[o];
          const dx = x - q[0];
          const dd = d - dep(q[1]);
          const r = Math.hypot(dx, dd);
          if (r < 8 && r > 0.01) {
            const f = ((8 - r) / 8) * (2.5 + ko * 5);
            x += (dx / r) * f;
            d += (dd / r) * f * 0.45;
          }
        }
        // 持っている子の近くの2人は、パスを受けられる距離（10〜16m）まで寄る
        const own = this.owner && this.base[this.owner] && this.base[this.owner][2] === my ? this.owner : null;
        if (own && own !== id) {
          const c = this.disp[own];
          const mates = Object.keys(this.disp).filter((o) => o !== own && this.base[o] && this.base[o][2] === my && this.base[o][3] !== 0);
          mates.sort((u, v) => dist(this.disp[u], c) - dist(this.disp[v], c));
          if (mates.indexOf(id) >= 0 && mates.indexOf(id) < 2) {
            const cd = Math.hypot(x - c[0], d - dep(c[1]));
            const want = 13;
            if (cd > 16 || cd < 8) {
              const k = (cd - want) / Math.max(1, cd) * 0.7;
              x -= (x - c[0]) * k;
              d -= (d - dep(c[1])) * k;
            }
          }
        }
        // 裏を狙う：前の子は、相手の最終ラインの上に張りつく（オフザボールが高いほどぎりぎりまで）
        const lastOpp = L - li.last[okey]; // 自分のゴールから見た、相手の最後の守り手の深さ
        if (li.last[okey] != null) {
          const runner = d > lastOpp - 14;
          if (runner) d = Math.max(d, lastOpp - 3.5 + ko * 2.5);
          // オフサイドにならない（パスが自分に出ていなければ、線より前に出ない）
          if (!(this.fl && this.expect === id)) d = Math.min(d, lastOpp - 0.6);
        }
      } else {
        // マーク：自分の持ち場の近くの相手を、ゴール側から捕まえる
        const km = this.ab01(id, 'マーク');
        const kp = this.ab01(id, 'ポジショニング');
        let tgt = null;
        let bd = 12 + kp * 4;
        for (const o of opp) {
          if (o === this.owner) continue; // 持っている子はプレスの子が見る
          const r = Math.hypot(this.disp[o][0] - x, dep(this.disp[o][1]) - d);
          if (r < bd) { bd = r; tgt = o; }
        }
        if (tgt) {
          const q = this.disp[tgt];
          const qd = dep(q[1]);
          const gx = 34 - q[0];
          const gd = -qd;
          const gl = Math.hypot(gx, gd) || 1;
          const gap = 1.4 + (1 - km) * 2.6; // マークのうまい子ほど近くにつく
          const mx = q[0] + (gx / gl) * gap;
          const md = qd + (gd / gl) * gap;
          const wgt = 0.4 + km * 0.35;
          x = lerp(x, mx, wgt);
          d = lerp(d, md, wgt);
        }
        // 持っている相手には、プレスの子のほかは寄りすぎない（プレスの弱い戦い方ほど間を空けて待つ）
        if (this.owner && this.disp[this.owner] && this.base[this.owner][2] !== my) {
          const c = this.disp[this.owner];
          const keep = 3 + (1 - this.tacOf(id).press) * 5;
          const r = Math.hypot(x - c[0], d - dep(c[1]));
          if (r < keep && r > 0.01) { const k = keep / r; x = c[0] + (x - c[0]) * k; d = dep(c[1]) + (d - dep(c[1])) * k; }
        }
        // 最終ラインは横一列にそろえる（ポジショニングが高いほどそろう）
        if (li.back[id] && li.lineD[key] != null) {
          const lim = 3.2 - kp * 2.2;
          d = clamp(d, li.lineD[key] - lim, li.lineD[key] + lim * 0.6);
        }
      }
      return [clamp(x, 2, W - 2), away ? L - clamp(d, 3, L - 3) : clamp(d, 3, L - 3)];
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
      if (this.celeb) this.restart(); // 喜びの途中で次の場面が来たら、並び直してから
      this.dive = null;
      this.scene = sc;
      this.setup = null;
      this.mom = clamp((this.mom || 0) + (sc.side === 'away' ? -0.12 : 0.12) * (sc.goal ? 1.6 : 1), -0.25, 0.25);
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
        // 触る子：コマで持っている子。いなければ、ひとつ前の出来事の受け手（少し離れた所で合わせるヘディングなど）
        const ha = this.holderOf(a, true) || (ev.length && ev[ev.length - 1].kind === 'kick' && ev[ev.length - 1].recv) || null;
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
      // つなぎ方：場面の最初の位置が遠ければ、そこまでボールをつないで主役を走らせる（つなげないときだけ暗転して置き直す）
      const f0 = fr[0];
      let far = dist(f0.ball, this.ball);
      for (const id of Object.keys(f0.pos)) if (this.disp[id]) far = Math.max(far, dist(f0.pos[id], this.disp[id]) * 0.8);
      this.pre = null;
      this.capText = null;
      if (far > 7 || !Object.keys(this.disp).length) {
        const h0 = this.holderOf(f0);
        // つなげるのは、受け手と主役が3秒ほどで最初の位置に着けるとき。ライン際の球（セットプレー）は置き直す
        const edge = f0.ball[0] < 1.5 || f0.ball[0] > W - 1.5 || f0.ball[1] < 1.5 || f0.ball[1] > L - 1.5;
        let eta = 0;
        for (const id of Object.keys(f0.pos)) if (this.disp[id]) eta = Math.max(eta, dist(this.disp[id], f0.pos[id]) / MOVE.sprint);
        const reachable = h0 && this.disp[h0] && dist(this.disp[h0], f0.ball) / MOVE.sprint < 9 && eta < 10;
        // セットプレー：ボールをその場に置き、蹴る子と主役が持ち場へ走る（暗転しない）
        const setOk = h0 && this.disp[h0] && dist(this.disp[h0], f0.ball) / MOVE.sprint < 14 && eta < 15; // セットプレーは速めの早送りなので遠くからでも間に合う
        if (Object.keys(this.disp).length && this.cut <= 0 && setOk && edge && (f0.ball[2] || 0) < 0.5) {
          this.pre = { t: 0, f0, h0, kicked: true, set: true };
          this.ball = [f0.ball[0], f0.ball[1], 0];
          this.bv = [0, 0];
          this.fl = null;
          this.owner = null;
          this.expect = h0;
          const set = new Set();
          for (const f of fr) for (const id of Object.keys(f.pos)) if (!set.has(id)) { set.add(id); this.stgt[id] = f.pos[id]; }
          return;
        }
        if (Object.keys(this.disp).length && this.cut <= 0 && reachable && !edge && (f0.ball[2] || 0) < 0.5 && dist(f0.ball, this.ball) < 75) {
          this.pre = { t: 0, f0, h0, kicked: false };
          // 主役は場面に最初に出てくる所へ走り出す
          const set = new Set();
          for (const f of fr) for (const id of Object.keys(f.pos)) if (!set.has(id)) { set.add(id); this.stgt[id] = f.pos[id]; }
          // いま転がっている・飛んでいるボールは、受けるはずだった子が拾う
          if (!this.owner) {
            let best = this.idle && this.idle.recv;
            const at = this.fl ? this.fl.to : this.ball;
            if (!best || !this.disp[best]) { let bd = 1e9; for (const id of Object.keys(this.disp)) { const d = dist(this.disp[id], at); if (d < bd && this.base[id] && this.base[id][3] !== 0) { bd = d; best = id; } } }
            this.expect = best;
          }
          return;
        }
        this.place(fr);
      }
      this.nextEvent();
    }
    // 場面の入り：持っている子が、場面の最初にボールがある所の子へ蹴る。届いて主役がそろえば台本を始める
    runPre(dt) {
      const p = this.pre;
      p.t += dt;
      const fr = this.scene.frames;
      if (!p.kicked) {
        if (this.owner) {
          if (this.owner === p.h0) p.kicked = true; // もう持っている：そこまで運ぶ
          else if (!(this.lock[this.owner] > 0)) {
            // 受け手が落ちる所に間に合う時に蹴る（それまでは持って運ぶ）
            const d = dist(this.ball, p.f0.ball);
            const tFly = d > 30 ? d / MOVE.loft + 0.25 : d / 11;
            const eta = dist(this.disp[p.h0], p.f0.ball) / (MOVE.sprint * 0.85);
            if (eta > tFly - 0.2 && p.t < 5) return; // 受け手が先に着いて待つ（届く球が転がり過ぎない）
            p.kicked = true;
            this.kick([p.f0.ball[0], p.f0.ball[1], 0], p.h0, this.owner);
          }
        } else if (p.t > 4) return this.endPre(true);
        return;
      }
      const got = !this.fl && this.owner === p.h0 && dist(this.ball, p.f0.ball) < 4;
      let ready = got;
      for (const id of Object.keys(p.f0.pos)) if (this.disp[id] && dist(this.disp[id], p.f0.pos[id]) > 3) ready = false;
      // 受け手が持てば、主役が少し遅れていても始める（台本のあいだに追いつく）
      if (ready || (got && p.t > 1.2) || p.t > (p.set ? 16 : 10)) this.endPre(this.owner !== p.h0 || dist(this.ball, p.f0.ball) > 8);
    }
    endPre(cut) {
      this.pre = null;
      if (cut) this.place(this.scene.frames);
      this.nextEvent();
    }
    place(fr) {
      const f0 = fr[0];
      this.places = (this.places || 0) + 1; // 点検用：暗転して置き直した回数
      {
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
    }
    endScene() {
      this.scene = null;
      this.pre = null;
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
        this.settle = 0.6;
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
      // 受け手がいるはずの球がラインを割った：待たずに次へ
      const outB = this.ball[0] < -1.5 || this.ball[0] > W + 1.5 || this.ball[1] < -0.3 || this.ball[1] > L + 0.3;
      if (outB && e.recv && this.owner !== e.recv) { this.expect = null; this.nextEvent(); return; }
      if (e.recv) {
        if (this.owner === e.recv) this.nextEvent();
        else if (e.t > 6) { this.stuck++; this.expect = null; this.nextEvent(); }
        return;
      }
      if (Math.hypot(this.bv[0], this.bv[1]) < 2 || e.t > 1.6) this.nextEvent();
    }

    // ----- ボール -----
    // to に向けて蹴る。届く時刻は物理で決まる（転がる・浮かす・シュート）
    kick(to, recv, by) {
      const from = this.ball.slice();
      const d = Math.max(0.5, dist(from, to));
      const z1 = Math.max(0, to[2] || 0);
      const shotLike = to[1] < 0.5 || to[1] > L - 0.5;
      // GK が止めるシュート：台本では GK の所へ蹴るだけなので、浮き球のパスに見えないようシュートの速さで飛ばす
      const lastKick = this.ev && this.ev.slice(this.evI + 1).every((x) => x.kind !== 'kick');
      const save = !shotLike && this.scene && this.scene.outcome === 'saved' && lastKick && recv && by && this.base[recv] && this.base[recv][3] === 0 && this.teamOf(recv) !== this.teamOf(by) && (to[1] < 7 || to[1] > L - 7) && dist(from, to) > 4;
      let kind = 'ground';
      let T;
      let v0 = 0;
      if (save) {
        // 正面に蹴ると GK が前へ倒れるだけに見えるので、GK の左右どちらかへ少しずらして横っ飛びで止めさせる
        const g = this.disp[recv];
        if (g && Math.abs(to[0] - g[0]) < 1.4) to = [clamp(g[0] + (to[0] >= g[0] ? 1 : -1) * 1.7, 31, 37), to[1], to[2]];
        kind = 'shot';
        T = dist(from, to) / (MOVE.shot * 0.92);
      } else if (shotLike) {
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
      this.fl = { by, from, to: [to[0], to[1], Math.max(0, to[2] || 0)], d: Math.max(0.5, dist(from, to)), T: Math.max(0.15, T), t: 0, kind, v0, h, z0: from[2] || 0, save };
      if (by) this.lock[by] = 0.3;
      // シュートには守る側の GK が飛ぶ：止める場面は落ちる所へ届き、決まる場面は手が届かない（6割まで）
      if (kind === 'shot' && by && this.base[by]) {
        const gk = Object.keys(this.base).find((id) => this.base[id][3] === 0 && this.teamOf(id) !== this.teamOf(by));
        const g = gk && this.disp[gk];
        if (g) {
          const gy = to[1] < L / 2 ? 0.8 : L - 0.8;
          const u = Math.abs(to[1] - from[1]) > 0.5 ? clamp((gy - from[1]) / (to[1] - from[1]), 0, 1) : 1;
          const cross = save ? [to[0], to[1]] : [from[0] + (to[0] - from[0]) * u, gy];
          const reach = save ? 1 : 0.6;
          // 飛ぶのは一瞬：球が着く少し前に伸びきるように飛び出し（早くても蹴られて 0.12 秒あと）、0.5 秒倒れている
          const dur = clamp(T - 0.2, 0.18, 0.38);
          const t0 = Math.max(0.12, T - dur - 0.06);
          this.dive = { id: gk, from: g.slice(), tgt: [g[0] + (cross[0] - g[0]) * reach, g[1] + (cross[1] - g[1]) * reach], t: 0, t0, dur, end: t0 + dur + 0.5 };
          this.dives = (this.dives || 0) + 1;
        }
      }
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
          // GK が止めた球は手の中で止まる（触った扱い）
          const vEnd = fl.save ? 0.8 : fl.kind === 'ground' ? MOVE.passEnd : fl.kind === 'loft' ? MOVE.loft * 0.72 : MOVE.shot * 0.95;
          this.bv = [dx * vEnd, dy * vEnd];
          this.ball[2] = fl.kind === 'shot' && !fl.save ? fl.to[2] : 0;
          this.fl = null;
          if (fl.save) {
            // 飛びついた GK がつかむ。届いていなければ手で弾く（どちらも触った扱い）
            const gk = this.expect;
            this.kicked = true;
            this.kickHold = 2;
            this.saves = (this.saves || 0) + 1;
            if (gk && this.disp[gk] && dist(this.disp[gk], this.ball) < 1.6) {
              this.catches = (this.catches || 0) + 1; // 点検用
              this.owner = gk;
              this.poss = this.teamOf(gk) === this.match.home ? 'home' : 'away';
            }
            return;
          }
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
      const mg = this.scene && this.expect ? 1.5 : 0.3; // 場面の受け手は、ラインを少し越えた球にも足を伸ばす
      const out = b[0] < -mg || b[0] > W + mg || b[1] < -0.3 || b[1] > L + 0.3;
      if (out) return;
      let best = null;
      let bd = MOVE.reach;
      for (const id of Object.keys(this.disp)) {
        if (this.lock[id] > 0 || id === this.owner) continue;
        if (this.setup && id !== this.setup.who) continue; // 再開はボールを取りに来た子だけ
        if (this.scene && id !== this.expect && !(id === this.chaser && this.ev && this.evI >= this.ev.length)) continue; // 場面では台本の子だけが触る（台本が終わったあとの球は追った子が拾う）
        if ((b[2] || 0) > zMax) continue;
        const d = dist(this.disp[id], b);
        if (d < bd) { bd = d; best = id; }
      }
      if (!best) return;
      if (this.owner && !this.scene) return; // 合間は奪い合わない（相手に渡るのはパスの失敗だけ）
      this.owner = best;
      if (this.setup) this.setup = null;
      this.poss = this.teamOf(best) === this.match.home ? 'home' : 'away';
      if (!this.scene && this.idle && this.idle.recv === best) this.idle = null;
    }

    // ----- 合間：持っている子が運び、味方へつなぐ -----
    idlePlay(dt) {
      const ids = Object.keys(this.base);
      const b = this.ball;
      const out = b[0] < -0.3 || b[0] > W + 0.3 || b[1] < -0.3 || b[1] > L + 0.3; // 拾える範囲（pickup）と同じ線
      if (this.setup) {
        this.setup.t += dt;
        if (this.setup.t > 10 && this.disp[this.setup.who]) { this.disp[this.setup.who] = [b[0], b[1] - this.atkDir(this.setup.who)[1] * 0.6]; this.cut = 0.5; } // 念のため
        return;
      }
      if (this.celeb && this.celeb.t < MOVE.celeb) return; // 喜んでいるあいだは再開しない
      if (out && !this.fl && this.cut <= 0) return this.restart();
      // パスカット：地を這うパスの通り道にいる相手が、足を出して止める（1本につき1人1回だけ試す）
      const fl = this.fl;
      if (fl && fl.kind === 'ground' && fl.by && this.base[fl.by]) {
        const my = this.teamOf(fl.by);
        fl.tried = fl.tried || {};
        for (const id of ids) {
          if (this.teamOf(id) === my || fl.tried[id] || this.base[id][3] === 0) continue;
          if (dist(this.disp[id], b) > MOVE.reach) continue;
          fl.tried[id] = true;
          if (Math.random() < 0.4 * (0.4 + this.shareOf(id) * 1.2) * (0.5 + this.ab01(id, '予測') + this.ab01(fl.by, 'パス') * -0.4 + 0.2)) { // 読みのいい子ほど止め、うまいパスほど通る
            this.fl = null;
            this.bv = [0, 0];
            this.idle = null;
            this.cuts = (this.cuts || 0) + 1;
            this.kicked = true; // 触った
            return;
          }
        }
      }
      if (this.fl) return;
      // タックル：寄せた子が間合いに入って少しすると、突いてボールを奪う（ボールは奪った子の足元へ転がる）
      if (this.owner && this.pressers && this.base[this.owner] && this.base[this.owner][3] !== 0) { // GK からは奪わない
        const q = this.disp[this.owner];
        let near = null;
        for (const id of Object.keys(this.pressers)) if (dist(this.disp[id], q) < MOVE.tackle) near = id;
        if (near) {
          this.duel = this.duel && this.duel.id === near && this.duel.on === this.owner ? this.duel : { id: near, on: this.owner, t: 0 };
          this.duel.t += dt;
          if (this.duel.t > 0.5 && Math.random() < dt * (0.4 + this.tacOf(near).press * 1.2) * (0.4 + this.shareOf(near) * 1.2) * (0.4 + this.ab01(near, 'タックル') * 1.2) * (1.6 - (this.ab01(this.owner, 'ドリブル') + this.ab01(this.owner, 'バランス') + this.ab01(this.owner, '強さ')) / 3 * 1.2)) {
            const r = this.disp[near];
            const d = Math.max(0.3, dist(r, b));
            this.lock[this.owner] = 0.9;
            this.owner = null;
            this.idle = null;
            this.bv = [((r[0] - b[0]) / d) * 4.5, ((r[1] - b[1]) / d) * 4.5];
            this.tackles = (this.tackles || 0) + 1;
            this.kicked = true; // 触った
            this.duel = null;
            return;
          }
        } else this.duel = null;
      }
      if (!this.owner) return; // 誰かが拾いに行く（targets で）
      // 持ってから出すまでの時間は攻めの速さで決まる（縦に速いは早く、ポゼッションはためる）
      const tc = this.tacOf(this.owner);
      const s = (this.idle = this.idle && this.idle.carrier === this.owner ? this.idle : { carrier: this.owner, t: 0, dur: (0.35 + (1 - tc.tempo) * 1.0 + Math.random() * (0.4 + (1 - tc.tempo) * 0.8)) * (this.surgeOf(this.owner) ? 0.7 : 1) * (1.3 - this.ab01(this.owner, '判断') * 0.6) }); // 判断の速い子は早く出す
      s.t += dt;
      if (s.t < s.dur) return;
      const me = this.owner;
      const my = this.teamOf(me);
      const q = this.disp[me];
      const atk = this.atkDir(me)[1];
      const depth = atk > 0 ? q[1] : L - q[1]; // 自分のゴールからの深さ
      const back = depth < 30 ? 2 : 4 + (1 - tc.tempo) * 16; // 後ろへ戻してよい距離（自陣の深くでは戻さない）
      const far = (depth < 30 ? 45 : 22 + tc.tempo * 14) + (this.ab01(me, '視野') - 0.5) * 16; // 速い攻めほど遠くへ蹴る。自陣の深くからは大きく蹴り出す。視野の広い子は遠くの味方を見つける
      let tgt = null;
      // 相手の陣の深くほど、相手に引っかかる（守りが固まっていて通らない）
      if (Math.random() < (0.06 + 0.25 * clamp((depth - 60) / 40, 0, 1)) * clamp(1.9 - this.shareOf(me) * 1.8, 0.5, 1.6) * (1.6 - this.ab01(me, 'パス') * 1.2)) { // パスのうまい子はミスが少ない // 押している側はミスが少ない
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
        if (!c.length) c = pick(30, 65); // それでもいなければ大きく蹴る
        // 前の味方ほど選ばれやすい（速い攻めほど強く）
        const wt = c.map((id) => 1 + Math.max(0, (this.disp[id][1] - q[1]) * atk) * Math.max(tc.tempo + (this.surgeOf(me) ? 0.6 : 0), depth < 30 ? 0.9 : 0) * 0.2); // 自陣の深くからは前へ逃がす。見どころの前は前へ
        let r0 = Math.random() * wt.reduce((a, x) => a + x, 0);
        for (let i = 0; i < c.length && !tgt; i++) if ((r0 -= wt[i]) <= 0) tgt = c[i];
        if (!tgt && c.length) tgt = c[c.length - 1];
      }
      if (!tgt) { s.t = 0; return; }
      // 受け手の少し前（走り込む先）へ
      const r = this.disp[tgt];
      const v = this.vel[tgt] || [0, 0];
      let to = [clamp(r[0] + v[0] * 0.6, 1, W - 1), clamp(r[1] + v[1] * 0.6, 1, L - 1), 0];
      // スルーパス：相手の最終ラインに張りついた味方へは、ラインの裏のスペースへ出す（視野の広い子ほど狙う）
      if (this.teamOf(tgt) === my) {
        const li = this.lineInfo();
        const okey = this.teamOf(me) === this.match.home ? 'away' : 'home';
        const lastOpp = li.last[okey] != null ? L - li.last[okey] : null; // 攻める側のゴールから見た相手の最後の守り手
        const rd = atk > 0 ? r[1] : L - r[1];
        if (lastOpp != null && rd > lastOpp - 6 && rd < L - 10 && Math.random() < 0.2 + this.ab01(me, '視野') * 0.4) {
          const lead = 7 + this.ab01(tgt, 'オフザボール') * 5;
          const ty = clamp(rd + lead, rd, L - 6);
          to = [clamp(r[0] + (34 - r[0]) * 0.15, 3, W - 3), atk > 0 ? ty : L - ty, 0];
          this.throughs = (this.throughs || 0) + 1;
        }
      }
      this.kick(to, tgt, me);
      this.idle = { recv: tgt, to };
    }
    // ボールが外に出た：一瞬暗くして再開（ゴールなら真ん中、ゴールラインならゴールキック、横ならスローイン）
    restart() {
      const b = this.ball;
      const m = this.match;
      this.celeb = null;
      this.cut = 0.5;
      this.bv = [0, 0];
      this.fl = null;
      this.idle = null;
      let pos;
      let who = null;
      const goal = Math.abs(b[0] - 34) < 3.7 && ((b[1] < 0 && b[1] > -2.3) || (b[1] > L && b[1] < L + 2.3));
      // 得点のあとだけ暗転して並び直す。ゴールキック・スローインは、ボールを置いて蹴る子が取りに走る（早送り）
      if (!goal) this.cut = 0;
      else {
        // キックオフ：両チームとも自分の陣地に並ぶ
        this.poss = null;
        for (const id of Object.keys(this.base)) {
          const q = this.shapePos(id);
          const home = this.teamOf(id) === m.home;
          this.disp[id] = [q[0], home ? Math.min(q[1], L / 2 - 1.5) : Math.max(q[1], L / 2 + 1.5)];
          this.vel[id] = [0, 0];
        }
      }
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
      if (!goal && who) {
        this.owner = null;
        this.setup = { who, t: 0 };
        this.ff = true; // 点検用：ボールを置き直したコマ
        return;
      }
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
      // シュートに飛ぶ GK
      if (this.dive && this.dive.id === id && this.dive.t < this.dive.end) return [this.disp[id], 0]; // 飛ぶ動きは stepPlayers で決める
      // 得点の喜び：決めた子はコーナーの方へ走り、味方が集まる。失点した側は持ち場へ歩いて戻る
      const cb = this.celeb;
      if (cb && this.base[cb.scorer]) {
        const sp = this.disp[cb.scorer];
        if (id === cb.scorer) return [cb.spot, MOVE.sprint * 0.9];
        const mine = this.teamOf(id) === this.teamOf(cb.scorer);
        if (mine && this.base[id][3] !== 0) {
          const i = cb.mates.indexOf(id);
          if (i >= 0) {
            const a = (i / Math.max(1, cb.mates.length)) * Math.PI * 2 + 0.6;
            return [[sp[0] + Math.cos(a) * 3, sp[1] + Math.sin(a) * 3], MOVE.sprint * 0.85];
          }
          return [this.shapePos(id), MOVE.jog * 0.6];
        }
        if (this.base[id][3] === 0) return [[34, this.atkDir(id)[1] > 0 ? 1.5 : L - 1.5], MOVE.jog * 0.35];
        return [this.shapePos(id), MOVE.jog * 0.4];
      }
      // ボールを持っている子
      if (id === this.owner) {
        if (this.pre && this.pre.kicked && id === this.pre.h0) return [[this.pre.f0.ball[0], this.pre.f0.ball[1]], MOVE.dribble];
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
      if (this.scene && this.chaser === id) return [[ball[0], ball[1]], MOVE.sprint];
      if (this.scene) {
        if (this.stgt[id]) return [this.stgt[id], MOVE.sprint];
        return [this.offballPos(id), MOVE.jog * 0.85];
      }
      // 合間：パスを受ける子は落ちる所へ。誰も持っていなければ、いちばん近い子が拾いに行く
      if (this.idle && this.idle.recv === id && this.fl) return [[this.fl.to[0], this.fl.to[1]], MOVE.sprint];
      if (this.setup && this.setup.who === id) return [[ball[0], ball[1]], MOVE.sprint];
      if (!this.owner && !this.fl && this.chaser === id) return [[ball[0], ball[1]], MOVE.sprint];
      // プレス：持っている相手へ寄せる（1人目は正面、2人目は内側を切る）。奪いはしない
      const pr = this.pressers && this.pressers[id];
      if (pr) return pr;
      // 裏へ抜ける子・寄る子は少し速く
      const ob = this.offballPos(id);
      return [ob, dist(ob, this.disp[id] || ob) > 6 ? MOVE.sprint * 0.85 : MOVE.jog];
    }
    // 守る側の誰が、どこまで寄せるか。プレスが強いほど遠くから・速く・2人で行く
    pressPlan() {
      // 持っている子へ。相手へのパスが出ていれば、受ける所へ先回りする（パスが合図）
      const me = this.owner || (this.fl && this.idle && this.idle.recv);
      const q = this.owner ? this.disp[me] : this.fl && [this.fl.to[0], this.fl.to[1]];
      if (!me || !q || !this.disp[me]) return null;
      const my = this.teamOf(me);
      const ids = Object.keys(this.base).filter((id) => this.teamOf(id) !== my && this.base[id][3] !== 0 && this.disp[id]);
      if (!ids.length) return null;
      const tc = this.tacOf(ids[0]);
      const reach = 4 + tc.press * 30;
      const gap = 1.6 + (1 - tc.press) * 4.5; // 弱いプレスは間合いを取って待つ
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
      // 場面でも、台本の受け手がいない転がる球（クリア・こぼれ球）は、いちばん近い子が追う。GK は自分のゴール前の球だけ
      this.chaser = null;
      const bOut = this.ball[0] < -0.3 || this.ball[0] > W + 0.3 || this.ball[1] < -0.3 || this.ball[1] > L + 0.3;
      if (!this.owner && !(this.scene && (this.expect || this.fl || this.pre || bOut))) { // 場面で外へ出た球（網の中など）は追わない
        let bd = 1e9;
        for (const id of Object.keys(this.disp)) {
          const b = this.base[id];
          if (!b) continue;
          if (b[3] === 0 && Math.abs(this.ball[1] - (this.atkDir(id)[1] > 0 ? 0 : L)) > 16) continue;
          const d = dist(this.disp[id], this.ball);
          if (d < bd) { bd = d; this.chaser = id; }
        }
      }
      this.pressers = this.scene ? null : this.pressPlan();
      for (const id of Object.keys(this.base)) {
        if (!this.disp[id]) { this.disp[id] = this.shapePos(id); this.vel[id] = [0, 0]; }
        const p = this.disp[id];
        const v = this.vel[id] || [0, 0];
        const mk = this.moveK(id);
        const [tg, vmax0, thru] = this.targetOf(id);
        const vmax = vmax0 * (id === this.owner ? mk.drib : mk.run); // 速い子は速く、運ぶのがうまい子は速く運ぶ
        const dx = tg[0] - p[0];
        const dy = tg[1] - p[1];
        const dd = Math.hypot(dx, dy);
        // 着く前に減速する（止まりたい所で止まれる速さ）
        const want = dd > 0.05 ? (thru ? vmax : Math.min(vmax, Math.sqrt(2 * MOVE.acc * mk.acc * 0.85 * dd))) : 0; // thru：通り道の点では止まらない
        const des = [dd > 0.05 ? (dx / dd) * want : 0, dd > 0.05 ? (dy / dd) * want : 0];
        // 近すぎる子からは離れる（体が重ならない）。ボールに向かう子は押されにくい
        const soft = id === this.owner || id === this.expect || (this.pressers && this.pressers[id]) ? 0.4 : 1;
        for (const o of Object.keys(this.disp)) {
          if (o === id || !this.base[o]) continue;
          const q = this.disp[o];
          const ox = p[0] - q[0];
          const oy = p[1] - q[1];
          const od = Math.hypot(ox, oy);
          if (od < MOVE.space && od > 1e-3) { const f = ((MOVE.space - od) / MOVE.space) * 7 * soft; des[0] += (ox / od) * f; des[1] += (oy / od) * f; }
        }
        // シュートに飛ぶ GK：走るのではなく、0.12 秒おいて決まった時間で飛びつき、伸びたまま少し倒れている
        const dvI = this.dive && this.dive.id === id && this.dive.t >= this.dive.t0 && this.dive.t < this.dive.end ? this.dive : null;
        if (dvI) {
          if (!dvI.go) { dvI.go = true; dvI.from = p.slice(); } // 飛び出す所
          const u = clamp((dvI.t - dvI.t0) / dvI.dur, 0, 1);
          const sm = u * u * (3 - 2 * u);
          const np = [lerp(dvI.from[0], dvI.tgt[0], sm), lerp(dvI.from[1], dvI.tgt[1], sm)];
          this.vel[id] = [(np[0] - p[0]) / Math.max(dt, 1e-3), (np[1] - p[1]) / Math.max(dt, 1e-3)];
          this.disp[id] = np;
          this.speed[id] = 0;
          continue;
        }
        const dsp = Math.hypot(des[0], des[1]);
        const vtop = MOVE.sprint * mk.run;
        if (dsp > vtop) { des[0] *= vtop / dsp; des[1] *= vtop / dsp; } // 押されても全力より速くは走らない
        const dv = [des[0] - v[0], des[1] - v[1]];
        const dvn = Math.hypot(dv[0], dv[1]);
        const mx = MOVE.acc * mk.acc * dt;
        if (dvn > mx) { dv[0] *= mx / dvn; dv[1] *= mx / dvn; }
        const nv = [v[0] + dv[0], v[1] + dv[1]];
        this.vel[id] = nv;
        this.disp[id] = [clamp(p[0] + nv[0] * dt, -3, W + 3), clamp(p[1] + nv[1] * dt, -2.5, L + 2.5)];
        this.speed[id] = Math.hypot(nv[0], nv[1]);
        if (this.lock[id] > 0) this.lock[id] -= dt;
      }
    }

    // 場面の入り（ボールを最初の位置へつなぐあいだ）は早送りで見せる。中身は同じ物理を細かく刻んで進める
    update(dt) {
      if (!this.match) return;
      this.kicked = this.kickHold > 0; // GK が止めた直後の数コマも触った扱い
      if (this.kickHold > 0) this.kickHold--;
      const ff = this.scene && this.pre ? (this.pre.set ? MOVE.ff * 1.6 : MOVE.ff) : this.setup && !this.scene ? MOVE.ff * 1.6 : 1;
      this.ff = ff > 1;
      const n = ff > 1 ? 3 : 1;
      for (let i = 0; i < n; i++) this.step1((dt * ff) / n);
    }
    step1(dt) {
      const m = this.match;
      this.clockI = (this.clockI || 0) + 1;
      if (this.clockI % 30 === 0) this._mk = {}; // 疲れで変わるので時々読み直す
      const share = m.homeShare ? m.homeShare() : 0.5;
      this.mom = (this.mom || 0) * Math.exp(-dt / 8); // 場面の勢いは8秒ほどで薄れる
      const want = clamp(share + this.mom, 0.2, 0.8);
      this.flow = this.flow == null ? want : this.flow + (want - this.flow) * (1 - Math.exp(-dt / 2));
      const nk = (m.keyMinutes || []).find((k) => k > m.min);
      this.surge = !this.scene && nk != null && nk - m.min <= 2;
      this.clock = (this.clock || 0) + dt;
      this.base = this.basePositions();
      for (const id of Object.keys(this.disp)) if (!this.base[id]) { delete this.disp[id]; delete this.vel[id]; if (this.owner === id) this.owner = null; }
      if (this.scene) {
        if (this.pre) this.runPre(dt);
        else {
          this.t += dt;
          this.runEvent(dt);
        }
        if (this.scene && this.scene.outcome === 'goal' && Math.abs(this.ball[0] - 34) < 3.7 && (this.ball[1] < -0.2 || this.ball[1] > L + 0.2)) { // 網の中（コーナーの球では喜ばない）
          this.flash = Math.min(1, this.flash + dt * 2);
          const sc = this.scene;
          if (!this.celeb && sc.scorer && this.disp[sc.scorer]) {
            // 決めた子は近いほうのコーナーの手前へ。近くの味方から5人が駆け寄る
            const p = this.disp[sc.scorer];
            const end = this.ball[1] < 0 ? 0 : L;
            const spot = [p[0] < 34 ? 5 : W - 5, end === 0 ? 9 : L - 9];
            const mates = Object.keys(this.base).filter((id) => id !== sc.scorer && this.base[id][3] !== 0 && this.teamOf(id) === this.teamOf(sc.scorer)).sort((a, b) => dist(this.disp[a] || spot, p) - dist(this.disp[b] || spot, p)).slice(0, 5);
            this.celeb = { scorer: sc.scorer, spot, mates, t: 0 };
            this.celebs = (this.celebs || 0) + 1;
          }
        }
      } else {
        this.idlePlay(dt);
        this.flash = 0;
      }
      if (this.cut > 0) this.cut = Math.max(0, this.cut - dt);
      if (this.dive && (this.dive.t += dt) > this.dive.end + 0.3) this.dive = null;
      if (this.celeb) this.celeb.t += dt;
      this.stepPlayers(dt);
      this.stepBall(dt);
      // 絵の尾のためのボールの少し前の位置（約0.1秒分）
      this.bh = this.bh || [];
      this.bh.push(this.ball.slice());
      if (this.bh.length > 6) this.bh.shift();
      if (this.cut > 0.3) this.bh = [];
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
          // 体（シャツの色）と縁（パンツの色）。飛んでいる GK は飛ぶ向きに伸びる
          const dv = this.dive && this.dive.id === id && this.dive.t >= this.dive.t0 && this.dive.t < this.dive.end ? this.dive : null;
          ctx.beginPath();
          if (dv && ctx.ellipse) {
            const st = Math.sin(clamp((dv.t - dv.t0) / dv.dur, 0, 1) * Math.PI / 2) * clamp((dv.end - dv.t) / 0.25, 0, 1); // 伸びて、倒れたまま、起き上がる
            const dq = P(dv.tgt[0], dv.tgt[1]);
            const d0 = P(dv.from[0], dv.from[1]); // 向きは飛び出した所から
            ctx.ellipse(q[0], q[1], R * (1 + st * 0.75), R * (1 - st * 0.25), Math.atan2(dq[1] - d0[1], dq[0] - d0[0]), 0, Math.PI * 2);
          } else ctx.arc(q[0], q[1], R, 0, Math.PI * 2);
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
          const cb = this.celeb && this.celeb.scorer === id;
          if (cb) {
            // 決めた子：広がる輪
            const k = (this.celeb.t % 0.8) / 0.8;
            ctx.strokeStyle = 'rgba(255,225,74,' + (1 - k) + ')';
            ctx.lineWidth = 2.5;
            ctx.beginPath();
            ctx.arc(q[0], q[1], R + 3 + k * R * 1.6, 0, Math.PI * 2);
            ctx.stroke();
          }
          if (((isF && this.scene) || cb) && p) labels.push({ q, text: (cb ? '⚽ ' : '') + p.num + ' ' + String(p.name).split(' ')[0], gold: cb });
        }
        // ボール（高いほど影から離れて大きく見える）
        const b = this.ball;
        const z = Math.max(0, b[2] || 0);
        let g = P(b[0], b[1]);
        const br = Math.max(4, s * 0.68) * (1 + z * 0.06);
        // 足元の球は丸の下に隠れるので、進む向きの丸の縁に見せる
        if (this.owner && this.disp[this.owner] && !this.fl) {
          const oq = P(this.disp[this.owner][0], this.disp[this.owner][1]);
          const ox = g[0] - oq[0];
          const oy = g[1] - oq[1];
          const od = Math.hypot(ox, oy);
          const want = R + br * 0.35;
          if (od < want) {
            const v = this.vel[this.owner] || [0, 0];
            const sp = Math.hypot(v[0], v[1]);
            const f = od > 0.5 ? [ox / od, oy / od] : sp > 0.4 ? [v[1] / sp, v[0] / sp] : this.atkDir(this.owner).slice().reverse();
            g = [oq[0] + f[0] * want, oq[1] + f[1] * want];
          }
        }
        // 速い球（シュート・強いパス）は少しの尾を引く
        const bh = this.bh || [];
        if (bh.length > 2 && !this.cut) {
          const o = bh[0];
          const sp = dist(o, b) / Math.max(0.02, (bh.length - 1) / 50);
          if (sp > 12) {
            const a = P(o[0], o[1]);
            const gr = ctx.createLinearGradient ? ctx.createLinearGradient(a[0], a[1], g[0], g[1] - z * s * 0.55) : null;
            if (gr) { gr.addColorStop(0, 'rgba(255,255,255,0)'); gr.addColorStop(1, 'rgba(255,255,255,.7)'); ctx.strokeStyle = gr; }
            ctx.lineWidth = br * 1.3;
            ctx.lineCap = 'round';
            ctx.beginPath();
            ctx.moveTo(a[0], a[1] - (o[2] || 0) * s * 0.55);
            ctx.lineTo(g[0], g[1] - z * s * 0.55);
            ctx.stroke();
            ctx.lineCap = 'butt';
          }
        }
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
        ctx.lineWidth = 1.6;
        ctx.stroke();
        // 黒い五角の模様（白い縁の丸と見分ける）
        ctx.fillStyle = '#1b1b1b';
        ctx.beginPath();
        ctx.arc(bq[0], bq[1], br * 0.38, 0, Math.PI * 2);
        ctx.fill();
        // 名前の札（主役）
        ctx.font = '800 11px system-ui, sans-serif';
        ctx.textBaseline = 'alphabetic';
        for (const lb of labels) {
          const tw = ctx.measureText(lb.text).width + 10;
          const x = clamp(lb.q[0] - tw / 2, 2, w - tw - 2);
          const y = clamp(lb.q[1] - R - 22, 2, h - 18);
          ctx.fillStyle = lb.gold ? 'rgba(255,214,60,.95)' : 'rgba(15,25,40,.85)';
          this.rr(ctx, x, y, tw, 16, 5);
          ctx.fill();
          ctx.fillStyle = lb.gold ? '#1b2438' : '#ffffff';
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
      // 流れのバー（上の真ん中）：左がホーム、右がアウェイ。押している側が長い
      if (kits && this.flow != null) {
        const bw = Math.min(160, w * 0.3);
        const bx = (w - bw) / 2;
        const by = 6;
        const fh = bw * this.flow;
        ctx.fillStyle = 'rgba(10,18,30,.7)';
        this.rr(ctx, bx - 3, by - 3, bw + 6, 12, 6);
        ctx.fill();
        ctx.fillStyle = kits.home.shirt;
        ctx.fillRect(bx, by, fh, 6);
        ctx.fillStyle = kits.away.shirt;
        ctx.fillRect(bx + fh, by, bw - fh, 6);
        ctx.fillStyle = '#ffffff';
        ctx.fillRect(bx + bw / 2 - 0.5, by - 2, 1, 10);
        ctx.font = '700 9px system-ui, sans-serif';
        ctx.textAlign = 'center';
        ctx.fillStyle = 'rgba(255,255,255,.85)';
        ctx.fillText('流れ', w / 2, by + 17);
      }
      // 早送りの印（場面の入り）
      if (this.ff) {
        ctx.font = '800 12px system-ui, sans-serif';
        const tx = this.scene ? '▶▶ 場面へ' : '▶▶ 再開';
        const tw = ctx.measureText(tx).width + 16;
        ctx.fillStyle = 'rgba(15,25,40,.8)';
        this.rr(ctx, (w - tw) / 2, h - 30, tw, 20, 10);
        ctx.fill();
        ctx.fillStyle = '#ffffff';
        ctx.textAlign = 'center';
        ctx.fillText(tx, w / 2, h - 16);
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
