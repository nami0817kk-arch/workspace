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
    }

    // 並びからの基本位置（絶対座標）
    basePositions() {
      const m = this.match;
      const out = {};
      for (const [t, flip] of [[m.home, false], [m.away, true]]) {
        t.lineup.forEach((s, i) => {
          const x = s.x * W;
          const y = 4 + s.y * 78;
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
      }
    }

    // ----- 投影 -----
    cam() {
      const cy = this.camY;
      const pos = [34, cy - 46, 40];
      const tgt = [34, cy + 2, 0];
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

    draw() {
      const ctx = this.ctx;
      ctx.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);
      const w = this.w;
      const h = this.h;
      // 背景（観客席の落ち着いた色。緑はピッチにだけ使う）
      const g = ctx.createLinearGradient(0, 0, 0, h);
      g.addColorStop(0, '#2b3d63');
      g.addColorStop(1, '#4a5d86');
      ctx.fillStyle = g;
      ctx.fillRect(0, 0, w, h);
      const c = this.cam();
      const P = (x, y, z) => this.proj(c, x, y, z || 0);
      // 芝
      const poly = (pts, fill) => {
        ctx.beginPath();
        pts.forEach((p, i) => {
          const q = P(p[0], p[1], 0);
          i ? ctx.lineTo(q.x, q.y) : ctx.moveTo(q.x, q.y);
        });
        ctx.closePath();
        ctx.fillStyle = fill;
        ctx.fill();
      };
      // ピッチの外の舗装（わずかに広く）
      poly([[-6, -6], [W + 6, -6], [W + 6, L + 6], [-6, L + 6]], '#3a4a6e');
      const bands = 14;
      for (let i = 0; i < bands; i++) {
        const y0 = (L / bands) * i;
        const y1 = (L / bands) * (i + 1);
        poly([[0, y0], [W, y0], [W, y1], [0, y1]], i % 2 ? '#2f9a5f' : '#37a869');
      }
      // 線
      ctx.strokeStyle = 'rgba(255,255,255,.9)';
      ctx.lineWidth = 1.6;
      const line = (pts, close) => {
        ctx.beginPath();
        pts.forEach((p, i) => {
          const q = P(p[0], p[1], 0);
          i ? ctx.lineTo(q.x, q.y) : ctx.moveTo(q.x, q.y);
        });
        if (close) ctx.closePath();
        ctx.stroke();
      };
      line([[0, 0], [W, 0], [W, L], [0, L]], true);
      line([[0, L / 2], [W, L / 2]]);
      for (const sgn of [0, 1]) {
        const y = (v) => (sgn ? L - v : v);
        line([[13.84, y(0)], [13.84, y(16.5)], [54.16, y(16.5)], [54.16, y(0)]]);
        line([[24.84, y(0)], [24.84, y(5.5)], [43.16, y(5.5)], [43.16, y(0)]]);
      }
      const circ = [];
      for (let a = 0; a <= 32; a++) circ.push([34 + 9.15 * Math.cos((a / 32) * Math.PI * 2), L / 2 + 9.15 * Math.sin((a / 32) * Math.PI * 2)]);
      line(circ);
      // ゴール（枠とネット）
      const goal = (yy, dir) => {
        const x0 = 34 - 3.66;
        const x1 = 34 + 3.66;
        const back = yy + dir * 2.2;
        ctx.strokeStyle = 'rgba(255,255,255,.95)';
        ctx.lineWidth = 2.2;
        const a = P(x0, yy, 0), b = P(x0, yy, 2.44), c2 = P(x1, yy, 2.44), d = P(x1, yy, 0);
        ctx.beginPath();
        ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); ctx.lineTo(c2.x, c2.y); ctx.lineTo(d.x, d.y);
        ctx.stroke();
        ctx.strokeStyle = 'rgba(255,255,255,.35)';
        ctx.lineWidth = 1;
        const bb = P(x0, back, 2.0), bc = P(x1, back, 2.0), ba = P(x0, back, 0), bd = P(x1, back, 0);
        ctx.beginPath();
        ctx.moveTo(b.x, b.y); ctx.lineTo(bb.x, bb.y); ctx.lineTo(bc.x, bc.y); ctx.lineTo(c2.x, c2.y);
        ctx.moveTo(bb.x, bb.y); ctx.lineTo(ba.x, ba.y); ctx.moveTo(bc.x, bc.y); ctx.lineTo(bd.x, bd.y);
        ctx.stroke();
        for (let i = 1; i < 6; i++) {
          const xx = lerp(x0, x1, i / 6);
          const q1 = P(xx, yy, 2.44), q2 = P(xx, back, 2.0);
          ctx.beginPath(); ctx.moveTo(q1.x, q1.y); ctx.lineTo(q2.x, q2.y); ctx.stroke();
        }
      };
      goal(L, 1);
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
      items.sort((a, b) => b.z - a.z);
      for (const it of items) {
        if (it.kind === 'b') this.drawBall(ctx, P);
        else this.drawPlayer(ctx, P, it);
      }
      goal(0, -1);
      // 手前側のゴールは前に描いたもの（上書きで見えるよう再描画）
      if (this.flash > 0) {
        ctx.fillStyle = 'rgba(255,255,255,' + 0.25 * Math.sin(this.flash * 3) + ')';
        ctx.fillRect(0, 0, w, h);
      }
    }

    drawPlayer(ctx, P, it) {
      const d = it.d;
      const foot = P(d[0], d[1], 0);
      const sp = (this.speed && this.speed[it.id]) || 0;
      const bob = sp > 1.2 ? Math.abs(Math.sin((this.t + d[0]) * 11)) * 0.18 : 0;
      const K = 1.45;
      const head = P(d[0], d[1], (1.7 + bob) * K);
      const body = P(d[0], d[1], (0.95 + bob) * K);
      const s = foot.s * K;
      const isFocus = this.focus.indexOf(it.id) >= 0;
      const isDef = this.defFocus && this.defFocus.indexOf(it.id) >= 0;
      const col = it.gk ? (it.isHome ? '#f39c12' : '#8e44ad') : it.t.color;
      // 影
      ctx.fillStyle = 'rgba(0,0,0,.28)';
      ctx.beginPath();
      ctx.ellipse(foot.x + s * 0.12, foot.y, s * 0.46, s * 0.17, 0, 0, Math.PI * 2);
      ctx.fill();
      if (isFocus || isDef) {
        ctx.strokeStyle = isFocus ? '#ffd54a' : 'rgba(255,255,255,.85)';
        ctx.lineWidth = isFocus ? 2.4 : 1.4;
        ctx.beginPath();
        ctx.ellipse(foot.x, foot.y, s * 0.7, s * 0.26, 0, 0, Math.PI * 2);
        ctx.stroke();
      }
      // 体
      ctx.lineCap = 'round';
      ctx.strokeStyle = '#1b2438';
      ctx.lineWidth = s * 0.3;
      ctx.beginPath();
      ctx.moveTo(foot.x - s * 0.1, foot.y);
      ctx.lineTo(body.x - s * 0.08, body.y + s * 0.2);
      ctx.moveTo(foot.x + s * 0.1, foot.y);
      ctx.lineTo(body.x + s * 0.08, body.y + s * 0.2);
      ctx.stroke();
      ctx.strokeStyle = col;
      ctx.lineWidth = s * 0.68;
      ctx.beginPath();
      ctx.moveTo(body.x, body.y + s * 0.1);
      ctx.lineTo(head.x, head.y + s * 0.38);
      ctx.stroke();
      // 顔
      ctx.fillStyle = '#f1c9a5';
      ctx.beginPath();
      ctx.arc(head.x, head.y, s * 0.24, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = '#2b2118';
      ctx.beginPath();
      ctx.arc(head.x, head.y - s * 0.07, s * 0.25, Math.PI, Math.PI * 2);
      ctx.fill();
      // 背番号
      if (s > 7) {
        ctx.fillStyle = '#fff';
        ctx.font = '800 ' + Math.max(8, s * 0.42) + 'px system-ui, sans-serif';
        ctx.textAlign = 'center';
        ctx.fillText(String(it.p.num), body.x, body.y + s * 0.18);
      }
      // 場面の主役には名前の札
      if (isFocus && this.scene) {
        const label = it.p.num + ' ' + it.p.name.split(' ')[0];
        ctx.font = '800 11px system-ui, sans-serif';
        const tw = ctx.measureText(label).width + 10;
        const x = clamp(head.x - tw / 2, 2, this.w - tw - 2);
        const y = head.y - s * 0.5 - 18;
        ctx.fillStyle = '#ffd54a';
        this.rr(ctx, x, y, tw, 16, 5);
        ctx.fill();
        ctx.fillStyle = '#1b2438';
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
      const g = P(b[0], b[1], 0);
      const a = P(b[0], b[1], Math.max(0, b[2]) + 0.3);
      const r = Math.max(3, g.s * 0.34);
      ctx.fillStyle = 'rgba(0,0,0,.3)';
      ctx.beginPath();
      ctx.ellipse(g.x, g.y, r * (1 + Math.min(1, b[2] * 0.1)), r * 0.45, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = '#fff';
      ctx.strokeStyle = '#222';
      ctx.lineWidth = 1.2;
      ctx.beginPath();
      ctx.arc(a.x, a.y, r, 0, Math.PI * 2);
      ctx.fill();
      ctx.stroke();
    }
  }
  YA.Renderer = Renderer;
})();
