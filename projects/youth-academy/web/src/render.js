// 見せ方：試合の場面を、斜め上から見下ろす仮想3D（2.5D）で描く。
// engine.js が返した座標を絵にするだけで、試合の中身には口を出さない。
// あとで three.js などの本物の3Dに替えるときは、このファイルだけを入れ替える。
(function () {
  'use strict';
  const YA = (globalThis.YA = globalThis.YA || {});
  const W = 68;
  const L = 105;
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const lerp = (a, b, t) => a + (b - a) * t;
  const ease = (t) => t * t * (3 - 2 * t);

  class Renderer {
    constructor(canvas) {
      this.cv = canvas;
      this.ctx = canvas.getContext('2d');
      this.match = null;
      this.scene = null;
      this.t = 0;
      this.disp = {}; // pid -> [x,y]
      this.prev = {};
      this.ball = [34, 52, 0];
      this.camY = 50;
      this.camTarget = 50;
      this.poss = 'home';
      this.idleT = 0;
      this.idleTarget = [34, 52];
      this.focus = []; // 強調する選手
      this.labels = {};
      this.flash = 0;
      this.vel = {};
      this.trail = [];
      this.dpr = 1;
      this.resize();
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
      this.disp = {};
      this.scene = null;
      this.base = {};
      this.kits = null;
      this._tex = null;
      this.trail = [];
      this.vel = {};
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
          out[s.pid] = flip ? [W - x, L - y, t, i] : [x, y, t, i];
        });
      }
      return out;
    }

    startScene(sc) {
      this.scene = sc;
      this.t = 0;
      this.focus = [];
      for (const k of Object.keys(sc.actors || {})) this.focus.push(sc.actors[k]);
      this.defFocus = sc.defs || [];
      this.flash = 0;
    }
    endScene() {
      this.scene = null;
      this.focus = [];
      this.defFocus = [];
    }

    // frames から時刻 t の位置を取る
    sceneState(sc, t) {
      const fr = sc.frames;
      const pos = {};
      let ball = fr[0].ball;
      // ボール
      if (t <= fr[0].t) ball = fr[0].ball;
      else if (t >= fr[fr.length - 1].t) ball = fr[fr.length - 1].ball;
      else {
        for (let i = 1; i < fr.length; i++) {
          if (t <= fr[i].t) {
            const a = fr[i - 1];
            const b = fr[i];
            const u = (t - a.t) / Math.max(0.001, b.t - a.t);
            const e = ease(u);
            const arc = Math.max(0, Math.min(a.ball[2], b.ball[2]) * 0 + Math.sin(u * Math.PI) * Math.min(3.2, Math.hypot(b.ball[0] - a.ball[0], b.ball[1] - a.ball[1]) * 0.06));
            ball = [lerp(a.ball[0], b.ball[0], e), lerp(a.ball[1], b.ball[1], e), lerp(a.ball[2], b.ball[2], e) + arc];
            break;
          }
        }
      }
      // 選手：出てくる各フレームで補間
      const ids = {};
      for (const f of fr) for (const k of Object.keys(f.pos)) ids[k] = 1;
      for (const id of Object.keys(ids)) {
        let a = null;
        let b = null;
        for (const f of fr) {
          if (!f.pos[id]) continue;
          if (f.t <= t) a = f;
          else if (!b) b = f;
        }
        if (a && b) {
          const u = ease((t - a.t) / Math.max(0.001, b.t - a.t));
          pos[id] = [lerp(a.pos[id][0], b.pos[id][0], u), lerp(a.pos[id][1], b.pos[id][1], u)];
        } else if (a) pos[id] = a.pos[id];
        else if (b) pos[id] = null; // まだ出番前＝基本位置から動き始める
        if (pos[id] === null) {
          const first = b.pos[id];
          const base = this.base[id];
          if (base) {
            const u = ease(clamp(t / Math.max(0.2, b.t), 0, 1));
            pos[id] = [lerp(base[0], first[0], u), lerp(base[1], first[1], u)];
          } else pos[id] = first;
        }
      }
      const cap = (() => {
        let c = null;
        for (const f of fr) if (f.t <= t && f.cap) c = f.cap;
        return c;
      })();
      return { pos, ball, cap };
    }

    update(dt) {
      const m = this.match;
      if (!m) return;
      this.clock = (this.clock || 0) + dt;
      this.base = this.basePositions();
      let ball;
      let scenePos = null;
      if (this.scene) {
        this.t += dt;
        const st = this.sceneState(this.scene, this.t);
        ball = st.ball;
        scenePos = st.pos;
        this.cap = st.cap;
        const last = this.scene.frames[this.scene.frames.length - 1].t;
        if (this.t > last - 0.2 && this.scene.outcome === 'goal') this.flash = Math.min(1, this.flash + dt * 2);
      } else {
        // 見どころの合間：ボールはゆるく動く
        this.idleT -= dt;
        if (this.idleT <= 0) {
          this.idleT = 1.2 + Math.random() * 1.2;
          const atk = this.poss === 'home' ? 1 : -1;
          this.idleTarget = [14 + Math.random() * 40, 52 + atk * (4 + Math.random() * 14)];
        }
        const k = 1 - Math.exp(-dt * 1.6);
        this.ball = [lerp(this.ball[0], this.idleTarget[0], k), lerp(this.ball[1], this.idleTarget[1], k), 0];
        ball = this.ball;
        this.cap = null;
        this.flash = 0;
      }
      this.ball = ball;
      // パスの軌跡：場面のあいだのボールの通り道（場面が変わったら消す）
      if (this.scene !== this._trailScene) { this._trailScene = this.scene; this.trail = []; }
      if (this.scene) {
        const tr = this.trail;
        const last = tr[tr.length - 1];
        if (!last || Math.hypot(ball[0] - last[0], ball[1] - last[1]) > 0.4) tr.push([ball[0], ball[1]]);
        // ボールが止まったら（持たれたら）軌跡を短くしていく
        if (last && Math.hypot(ball[0] - last[0], ball[1] - last[1]) < 0.05 && tr.length) tr.shift();
        if (tr.length > 22) tr.shift();
      } else this.trail = [];
      const away = this.scene && this.scene.flip;
      this.camTarget = away ? clamp(ball[1] - 3, 8, 92) : clamp(ball[1] + 4, 34, 92);
      this.camY = lerp(this.camY, this.camTarget, 1 - Math.exp(-dt * (this.scene ? 3.5 : 1.5)));
      // 選手
      const ballY = ball[1];
      for (const id of Object.keys(this.base)) {
        const b = this.base[id];
        const gk = b[3] === 0;
        // 基本位置：ボールの位置にチーム全体が寄る
        const shift = gk ? 0 : (ballY - 52) * 0.28;
        const tx = lerp(b[0], ball[0], gk ? 0 : 0.08);
        const ty = clamp(b[1] + shift, 2, 103);
        let target = [tx, ty];
        let direct = false;
        if (scenePos && scenePos[id]) {
          target = scenePos[id];
          direct = true;
        }
        const cur = this.disp[id] || [tx, ty];
        const k = direct ? 1 : 1 - Math.exp(-dt * 2.4);
        const nx = lerp(cur[0], target[0], k);
        const ny = lerp(cur[1], target[1], k);
        this.prev[id] = cur;
        this.disp[id] = [nx, ny];
        this.speed = this.speed || {};
        this.speed[id] = dt > 0 ? Math.hypot(nx - cur[0], ny - cur[1]) / dt : 0;
        if (dt > 0) {
          const v0 = this.vel[id] || [0, 0];
          const kv = 1 - Math.exp(-dt * 6);
          this.vel[id] = [lerp(v0[0], (nx - cur[0]) / dt, kv), lerp(v0[1], (ny - cur[1]) / dt, kv)];
        }
      }
    }

    // ----- 投影 -----
    // 中継の高いカメラ：斜め上からのぞき込む（選手は小さく、ピッチが広く見える）
    cam() {
      const cy = this.camY;
      const pos = [34, cy - 27, 43];
      const tgt = [34, cy + 5, 0];
      const d = [tgt[0] - pos[0], tgt[1] - pos[1], tgt[2] - pos[2]];
      const n = Math.hypot(d[0], d[1], d[2]);
      const f = [d[0] / n, d[1] / n, d[2] / n];
      const r = [1, 0, 0];
      const u = [0, -f[2], f[1]];
      return { pos, f, r, u };
    }
    proj(c, x, y, z) {
      const dx = x - c.pos[0];
      const dy = y - c.pos[1];
      const dz = z - c.pos[2];
      const zc = dx * c.f[0] + dy * c.f[1] + dz * c.f[2];
      const xc = dx * c.r[0] + dy * c.r[1] + dz * c.r[2];
      const yc = dx * c.u[0] + dy * c.u[1] + dz * c.u[2];
      const F = this.w * 0.92;
      const s = F / Math.max(1, zc);
      return { x: this.w / 2 + xc * s, y: this.h * 0.5 - yc * s, s, z: zc };
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
    // 芝の目と観客席の模様（最初に1回だけ作る）
    tex(kind) {
      this._tex = this._tex || {};
      if (this._tex[kind] !== undefined) return this._tex[kind];
      this._tex[kind] = null;
      if (typeof document === 'undefined' || !this.ctx || !this.ctx.createPattern) return null;
      const c = document.createElement('canvas');
      const S = kind === 'grass' ? 256 : 120;
      c.width = S;
      c.height = S;
      const x = c.getContext && c.getContext('2d');
      if (!x) return null;
      let seed = kind === 'grass' ? 7 : 11;
      const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
      if (kind === 'grass') {
        // 細い縦の筋（刈った芝の目）と細かい粒
        for (let i = 0; i < 3200; i++) {
          x.fillStyle = rnd() > 0.5 ? 'rgba(255,255,255,0.06)' : 'rgba(0,30,0,0.08)';
          x.fillRect(rnd() * S, rnd() * S, 1, 2 + rnd() * 6);
        }
      } else {
        // 観客：暗い席に、クラブの色と白と肌の点
        const k = this.kitsOf();
        const cols = [k ? k.home.shirt : '#c8102e', k ? k.home.shirt : '#c8102e', '#e8e8e8', '#f1c9a5', '#2a2f3d', k ? k.away.shirt : '#1d2a4d'];
        x.fillStyle = '#1b2030';
        x.fillRect(0, 0, S, S);
        for (let yy = 0; yy < S; yy += 5) {
          x.fillStyle = 'rgba(255,255,255,0.04)';
          x.fillRect(0, yy + 4, S, 1);
          for (let xx = 0; xx < S; xx += 3) {
            if (rnd() < 0.18) continue;
            x.fillStyle = cols[Math.floor(rnd() * cols.length)];
            x.fillRect(xx + rnd(), yy + rnd(), 2, 2.5);
          }
        }
      }
      this._tex[kind] = this.ctx.createPattern(c, 'repeat');
      return this._tex[kind];
    }

    draw() {
      const ctx = this.ctx;
      ctx.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);
      const w = this.w;
      const h = this.h;
      const c = this.cam();
      const P = (x, y, z) => this.proj(c, x, y, z || 0);
      const kits = this.kitsOf();
      // 観客席（ピッチの外は全部スタンド）
      ctx.fillStyle = this.tex('crowd') || '#1b2030';
      ctx.fillRect(0, 0, w, h);
      const path = (pts, z) => {
        ctx.beginPath();
        pts.forEach((p, i) => {
          const q = P(p[0], p[1], z || 0);
          i ? ctx.lineTo(q.x, q.y) : ctx.moveTo(q.x, q.y);
        });
        ctx.closePath();
      };
      const poly = (pts, fill) => {
        path(pts);
        ctx.fillStyle = fill;
        ctx.fill();
      };
      // ピッチの外の芝（タッチラインの外にも芝が続く）
      const OUT = [[-7, -6], [W + 7, -6], [W + 7, L + 6], [-7, L + 6]];
      poly(OUT, '#3a8534');
      // 刈り目：ゴールラインと平行の太い帯
      const bands = 18;
      for (let i = 0; i < bands; i++) {
        const y0 = (L / bands) * i;
        const y1 = (L / bands) * (i + 1);
        poly([[-7, y0], [W + 7, y0], [W + 7, y1], [-7, y1]], i % 2 ? '#3f923a' : '#4aa043');
      }
      // 芝の目（模様は地面に貼りつくよう、カメラに合わせてずらす）
      const gt = this.tex('grass');
      if (gt) {
        ctx.save();
        path(OUT);
        ctx.clip();
        const o = P(0, 0, 0);
        if (gt.setTransform && typeof DOMMatrix !== 'undefined') gt.setTransform(new DOMMatrix().translateSelf(0, o.y % 256));
        ctx.fillStyle = gt;
        ctx.fillRect(0, 0, w, h);
        // 奥ほどわずかに暗く（空気の厚み）
        const lg = ctx.createLinearGradient(0, 0, 0, h);
        lg.addColorStop(0, 'rgba(0,25,10,0.22)');
        lg.addColorStop(0.5, 'rgba(0,0,0,0)');
        lg.addColorStop(1, 'rgba(255,255,220,0.05)');
        ctx.fillStyle = lg;
        ctx.fillRect(0, 0, w, h);
        ctx.restore();
      }
      // 広告板（タッチラインとゴールラインの外。クラブの色と白・紺）
      const boardCols = [kits ? kits.home.shirt : '#1f5fd1', '#f4f4f4', '#1d2a4d', '#f2c200'];
      const board = (x0, y0, x1, y1, idx) => {
        const a = P(x0, y0, 0), b = P(x1, y1, 0), b2 = P(x1, y1, 0.9), a2 = P(x0, y0, 0.9);
        ctx.beginPath();
        ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); ctx.lineTo(b2.x, b2.y); ctx.lineTo(a2.x, a2.y);
        ctx.closePath();
        ctx.fillStyle = boardCols[idx % boardCols.length];
        ctx.fill();
        ctx.strokeStyle = 'rgba(0,0,0,.25)';
        ctx.lineWidth = 1;
        ctx.stroke();
      };
      for (let i = 0; i < 10; i++) {
        const y0 = -4 + i * 11.3, y1 = y0 + 11.3;
        board(-6.5, y0, -6.5, y1, i);
        board(W + 6.5, y0, W + 6.5, y1, i + 2);
      }
      for (let i = 0; i < 6; i++) board(-4 + i * 12.6, L + 5, 8.6 + i * 12.6, L + 5, i + 1);
      // 線：細く、少し透ける白
      const mid = P(34, this.camY, 0);
      ctx.strokeStyle = 'rgba(255,255,255,.88)';
      ctx.lineWidth = clamp(mid.s * 0.12, 1, 2.2);
      ctx.lineCap = 'butt';
      const line = (pts, close) => {
        ctx.beginPath();
        pts.forEach((p, i) => {
          const q = P(p[0], p[1], 0);
          i ? ctx.lineTo(q.x, q.y) : ctx.moveTo(q.x, q.y);
        });
        if (close) ctx.closePath();
        ctx.stroke();
      };
      const arc = (cx, cy, r, a0, a1, n) => {
        const pts = [];
        for (let k = 0; k <= n; k++) { const a = a0 + ((a1 - a0) * k) / n; pts.push([cx + r * Math.cos(a), cy + r * Math.sin(a)]); }
        line(pts);
      };
      const dot = (x, y, r) => { const q = P(x, y, 0); ctx.fillStyle = 'rgba(255,255,255,.9)'; ctx.beginPath(); ctx.ellipse(q.x, q.y, r * q.s, r * q.s * 0.6, 0, 0, Math.PI * 2); ctx.fill(); };
      line([[0, 0], [W, 0], [W, L], [0, L]], true);
      line([[0, L / 2], [W, L / 2]]);
      arc(34, L / 2, 9.15, 0, Math.PI * 2, 40);
      dot(34, L / 2, 0.3);
      for (const sgn of [0, 1]) {
        const y = (v) => (sgn ? L - v : v);
        line([[13.84, y(0)], [13.84, y(16.5)], [54.16, y(16.5)], [54.16, y(0)]]);
        line([[24.84, y(0)], [24.84, y(5.5)], [43.16, y(5.5)], [43.16, y(0)]]);
        dot(34, y(11), 0.25);
        // ペナルティアーク（エリアの外に出る部分だけ）
        const a = Math.acos(5.5 / 9.15);
        if (sgn) arc(34, y(11), 9.15, -Math.PI / 2 - a, -Math.PI / 2 + a, 16);
        else arc(34, y(11), 9.15, Math.PI / 2 - a, Math.PI / 2 + a, 16);
      }
      for (const [cx, cy, a0] of [[0, 0, 0], [W, 0, Math.PI / 2], [W, L, Math.PI], [0, L, -Math.PI / 2]]) arc(cx, cy, 1, a0, a0 + Math.PI / 2, 6);
      // ゴール（枠とネット）
      const goal = (yy, dir) => {
        const x0 = 34 - 3.66;
        const x1 = 34 + 3.66;
        const back = yy + dir * 2.2;
        // ネットの面
        const n1 = P(x0, yy, 2.44), n2 = P(x1, yy, 2.44), n3 = P(x1, back, 2.0), n4 = P(x0, back, 2.0);
        ctx.fillStyle = 'rgba(255,255,255,.12)';
        ctx.beginPath(); ctx.moveTo(n1.x, n1.y); ctx.lineTo(n2.x, n2.y); ctx.lineTo(n3.x, n3.y); ctx.lineTo(n4.x, n4.y); ctx.closePath(); ctx.fill();
        ctx.strokeStyle = 'rgba(255,255,255,.3)';
        ctx.lineWidth = 0.8;
        for (let i = 1; i < 10; i++) {
          const xx = lerp(x0, x1, i / 10);
          const q1 = P(xx, yy, 2.44), q2 = P(xx, back, 2.0), q3 = P(xx, back, 0);
          ctx.beginPath(); ctx.moveTo(q1.x, q1.y); ctx.lineTo(q2.x, q2.y); ctx.lineTo(q3.x, q3.y); ctx.stroke();
        }
        for (let j = 1; j < 5; j++) {
          const zz = (2.0 * j) / 5;
          const q1 = P(x0, back, zz), q2 = P(x1, back, zz);
          ctx.beginPath(); ctx.moveTo(q1.x, q1.y); ctx.lineTo(q2.x, q2.y); ctx.stroke();
        }
        ctx.strokeStyle = 'rgba(255,255,255,.98)';
        ctx.lineWidth = clamp(mid.s * 0.16, 1.5, 3);
        const a = P(x0, yy, 0), b = P(x0, yy, 2.44), c2 = P(x1, yy, 2.44), d = P(x1, yy, 0);
        ctx.beginPath();
        ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); ctx.lineTo(c2.x, c2.y); ctx.lineTo(d.x, d.y);
        ctx.stroke();
      };
      goal(L, 1);
      // パスの軌跡（緑の線）。ボールが速く動いているあいだだけ
      const tr = this.trail || [];
      if (tr.length > 2) {
        const a = tr[0], b = tr[tr.length - 1];
        if (Math.hypot(b[0] - a[0], b[1] - a[1]) > 4) {
          const qa = P(a[0], a[1], 0), qb = P(b[0], b[1], 0);
          const g = ctx.createLinearGradient(qa.x, qa.y, qb.x, qb.y);
          g.addColorStop(0, 'rgba(120,255,110,0)');
          g.addColorStop(1, 'rgba(120,255,110,.75)');
          ctx.strokeStyle = g;
          ctx.lineWidth = 2.2;
          ctx.lineCap = 'round';
          ctx.beginPath();
          tr.forEach((p, i) => { const q = P(p[0], p[1], 0); i ? ctx.lineTo(q.x, q.y) : ctx.moveTo(q.x, q.y); });
          ctx.stroke();
        }
      }
      // 描く対象を奥から
      const items = [];
      const m = this.match;
      if (m) {
        for (const id of Object.keys(this.base)) {
          const b = this.base[id];
          const t = b[2];
          const p = t.players[id];
          const d = this.disp[id] || b;
          items.push({ kind: 'p', id, p, t, d, z: P(d[0], d[1], 0).z, isHome: t === m.home, gk: b[3] === 0 });
        }
        items.push({ kind: 'b', z: P(this.ball[0], this.ball[1], 0).z - 0.01 });
      }
      // 影は先にまとめて（体の上に影が乗らないように）
      for (const it of items) if (it.kind === 'p') this.drawShadow(ctx, P, it);
      items.sort((a, b) => b.z - a.z);
      for (const it of items) {
        if (it.kind === 'b') this.drawBall(ctx, P);
        else this.drawPlayer(ctx, P, it);
      }
      goal(0, -1);
      // 縁を少し暗く（中継の画のように中央へ目が行く）
      const vg = ctx.createRadialGradient(w / 2, h / 2, Math.min(w, h) * 0.45, w / 2, h / 2, Math.max(w, h) * 0.75);
      vg.addColorStop(0, 'rgba(0,0,0,0)');
      vg.addColorStop(1, 'rgba(0,0,0,.28)');
      ctx.fillStyle = vg;
      ctx.fillRect(0, 0, w, h);
      if (this.flash > 0) {
        ctx.fillStyle = 'rgba(255,255,255,' + 0.25 * Math.sin(this.flash * 3) + ')';
        ctx.fillRect(0, 0, w, h);
      }
    }

    // 選手の向き（動いていればその向き、止まっていればボールの方）
    dirOf(it) {
      const v = (this.vel && this.vel[it.id]) || [0, 0];
      const sp = Math.hypot(v[0], v[1]);
      if (sp > 0.6) return [v[0] / sp, v[1] / sp];
      const dx = this.ball[0] - it.d[0], dy = this.ball[1] - it.d[1];
      const n = Math.hypot(dx, dy) || 1;
      return [dx / n, dy / n];
    }
    drawShadow(ctx, P, it) {
      // 日差しは左上から：影は右手前へ長く伸びる
      const d = it.d;
      const K = 1.45;
      const a = P(d[0], d[1], 0);
      const b = P(d[0] + 1.05 * K, d[1] - 1.35 * K, 0);
      ctx.strokeStyle = 'rgba(10,35,10,.32)';
      ctx.lineCap = 'round';
      ctx.lineWidth = a.s * K * 0.34;
      ctx.beginPath();
      ctx.moveTo(a.x, a.y);
      ctx.lineTo(b.x, b.y);
      ctx.stroke();
      ctx.fillStyle = 'rgba(10,35,10,.3)';
      ctx.beginPath();
      ctx.ellipse(a.x, a.y, a.s * K * 0.28, a.s * K * 0.12, 0, 0, Math.PI * 2);
      ctx.fill();
    }

    drawPlayer(ctx, P, it) {
      const d = it.d;
      const K = 1.45;
      const kits = this.kitsOf() || { home: { shirt: it.t.color, shorts: '#fff', socks: it.t.color, acc: '#fff', gk: '#f39c12' }, away: { shirt: it.t.color, shorts: '#fff', socks: it.t.color, acc: '#fff', gk: '#8e44ad' } };
      const kit = it.isHome ? kits.home : kits.away;
      const shirt = it.gk ? kit.gk : kit.shirt;
      const shorts = it.gk ? '#1b1b1b' : kit.shorts;
      const socks = it.gk ? kit.gk : kit.socks;
      const look = YA.lookOf ? YA.lookOf(it.p) : { skin: '#f1c9a5', hair: '#2b2118' };
      const sp = (this.speed && this.speed[it.id]) || 0;
      const dir = this.dirOf(it);
      const side = [-dir[1], dir[0]];
      const run = clamp(sp / 5.5, 0, 1);
      const ph = (this.clock || 0) * (7 + run * 5) + (YA.hash ? YA.hash(String(it.id)) % 7 : 0);
      const sw = Math.sin(ph) * 0.42 * run;
      const lift = Math.abs(Math.cos(ph)) * 0.12 * run;
      // 体の点：f＝前後、s＝左右、z＝高さ（m）
      const at = (f, s, z) => P(d[0] + (dir[0] * f + side[0] * s) * K, d[1] + (dir[1] * f + side[1] * s) * K, z * K);
      const foot = P(d[0], d[1], 0);
      const S = foot.s * K;
      const isFocus = this.focus.indexOf(it.id) >= 0;
      const isDef = this.defFocus && this.defFocus.indexOf(it.id) >= 0;
      if (isFocus || isDef) {
        ctx.strokeStyle = isFocus ? 'rgba(110,255,120,.95)' : 'rgba(255,255,255,.8)';
        ctx.lineWidth = isFocus ? 2.2 : 1.3;
        ctx.beginPath();
        ctx.ellipse(foot.x, foot.y, S * 0.62, S * 0.3, 0, 0, Math.PI * 2);
        ctx.stroke();
      }
      ctx.lineCap = 'round';
      const seg = (a, b, col, wd) => {
        ctx.strokeStyle = col;
        ctx.lineWidth = wd;
        ctx.beginPath();
        ctx.moveTo(a.x, a.y);
        ctx.lineTo(b.x, b.y);
        ctx.stroke();
      };
      const dark = 'rgba(15,20,30,.55)';
      // 脚（ソックス＋もも）。走っているときは前後に振る
      for (const sd of [-1, 1]) {
        const st = sw * sd;
        const ft = at(st, 0.11 * sd, sd > 0 ? lift : 0.02);
        const kn = at(st * 0.55 + 0.05, 0.11 * sd, 0.5);
        const hp = at(0, 0.11 * sd, 0.9);
        seg(ft, kn, dark, S * 0.15);
        seg(ft, kn, socks, S * 0.11);
        seg(kn, hp, look.skin, S * 0.11);
        ctx.fillStyle = '#151515';
        ctx.beginPath();
        ctx.arc(ft.x, ft.y, S * 0.065, 0, Math.PI * 2);
        ctx.fill();
      }
      // パンツ
      seg(at(0, -0.12, 0.88), at(0, 0.12, 0.88), dark, S * 0.27);
      seg(at(0, -0.11, 0.88), at(0, 0.11, 0.88), shorts, S * 0.23);
      // 腕（脚と逆に振る）。後ろの腕を先に
      const arm = (sd) => {
        const sh = at(0, 0.22 * sd, 1.38);
        const el = at(-sw * sd * 0.5, 0.27 * sd, 1.13);
        const hd = at(-sw * sd * 0.9 + 0.08, 0.27 * sd, 0.92);
        seg(sh, el, shirt, S * 0.1);
        seg(el, hd, look.skin, S * 0.08);
      };
      const backSd = side[0] * 1 > 0 ? -1 : 1;
      arm(backSd);
      // 胴（縁取りで芝の上でも見分けやすく）
      const hipC = at(0, 0, 0.92);
      const chest = at(0, 0, 1.38);
      seg(hipC, chest, dark, S * 0.44);
      seg(hipC, chest, shirt, S * 0.38);
      if (kit.k === 'redblack' && !it.gk) {
        // 縦じま
        for (const o of [-0.08, 0.08]) seg(at(0, o, 0.95), at(0, o, 1.36), '#111111', S * 0.07);
      }
      // 肩の差し色
      seg(at(0, -0.19, 1.4), at(0, 0.19, 1.4), it.gk ? 'rgba(255,255,255,.7)' : kit.acc, S * 0.06);
      arm(-backSd);
      // 頭（上から見えるので髪が大きく、顔はこちら向きのときだけ見える）
      const head = at(0, 0, 1.64);
      const hr = S * 0.13;
      ctx.fillStyle = look.skin;
      ctx.beginPath();
      ctx.arc(head.x, head.y, hr, 0, Math.PI * 2);
      ctx.fill();
      const back = at(-0.05, 0, 1.7);
      ctx.fillStyle = look.hair;
      ctx.beginPath();
      ctx.arc(back.x, back.y, hr * 0.92, 0, Math.PI * 2);
      ctx.fill();
      // 背番号
      if (S > 16) {
        ctx.fillStyle = YA.colorDist && YA.colorDist(shirt, '#ffffff') < 120 ? '#1b2438' : '#ffffff';
        ctx.font = '800 ' + Math.max(7, S * 0.22) + 'px system-ui, sans-serif';
        ctx.textAlign = 'center';
        ctx.fillText(String(it.p.num), (hipC.x + chest.x) / 2, (hipC.y + chest.y) / 2 + S * 0.08);
      }
      // 場面の主役には名前の札
      if (isFocus && this.scene) {
        const label = it.p.num + ' ' + it.p.name.split(' ')[0];
        ctx.font = '800 11px system-ui, sans-serif';
        const tw = ctx.measureText(label).width + 10;
        const x = clamp(head.x - tw / 2, 2, this.w - tw - 2);
        const y = head.y - hr - 20;
        ctx.fillStyle = 'rgba(15,25,40,.82)';
        this.rr(ctx, x, y, tw, 16, 5);
        ctx.fill();
        ctx.fillStyle = '#ffffff';
        ctx.textAlign = 'left';
        ctx.fillText(label, x + 5, y + 12);
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

    drawBall(ctx, P) {
      const b = this.ball;
      const z = Math.max(0, b[2]);
      // 影：ボールが高いほど右手前へずれて薄くなる
      const g = P(b[0] + z * 0.5, b[1] - z * 0.65, 0);
      const a = P(b[0], b[1], z + 0.22);
      const r = Math.max(2.6, a.s * 0.24);
      ctx.fillStyle = 'rgba(10,35,10,' + clamp(0.38 - z * 0.03, 0.12, 0.38) + ')';
      ctx.beginPath();
      ctx.ellipse(g.x, g.y, r * 1.1, r * 0.55, 0, 0, Math.PI * 2);
      ctx.fill();
      const rg = ctx.createRadialGradient(a.x - r * 0.35, a.y - r * 0.35, r * 0.1, a.x, a.y, r);
      rg.addColorStop(0, '#ffffff');
      rg.addColorStop(1, '#cfd3d6');
      ctx.fillStyle = rg;
      ctx.beginPath();
      ctx.arc(a.x, a.y, r, 0, Math.PI * 2);
      ctx.fill();
      // 五角形の模様（転がると回る）
      const rot = (b[0] + b[1]) * 1.3;
      ctx.fillStyle = '#2a2a2a';
      for (let i = 0; i < 3; i++) {
        const an = rot + (i * Math.PI * 2) / 3;
        ctx.beginPath();
        ctx.arc(a.x + Math.cos(an) * r * 0.5, a.y + Math.sin(an) * r * 0.5, r * 0.2, 0, Math.PI * 2);
        ctx.fill();
      }
      ctx.strokeStyle = 'rgba(0,0,0,.35)';
      ctx.lineWidth = 0.8;
      ctx.beginPath();
      ctx.arc(a.x, a.y, r, 0, Math.PI * 2);
      ctx.stroke();
    }
  }
  YA.Renderer = Renderer;
})();
