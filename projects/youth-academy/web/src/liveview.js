// 一続きの試合（live.js）の見せ方（2026-11-24 作り直し）。
// 「試合の動き変だよ」→ 動きで見せるのをやめ、実況と場面の図で見せる（ユーザー決定）。
// 22人が本物らしく動く絵は作りきれなかった。試合の中身（結果・成績・特性・戦術の効き）は live.js のまま。
//   見どころ：シュートの瞬間の全員の位置を止めた図に、攻めの道筋（パス＝実線・浮き球＝破線・運んだ所＝点線・シュート＝黄色）を
//            順に引く。ボールは線の上を進む。選手は動かさない。
//   合間：両チームの並びを止めた図（ボールは出さない）。試合の流れは上のバーと実況で伝える。
// 描き方は render.js の draw をそのまま使う（disp・trails・focus を置くだけ）。
(function () {
  'use strict';
  const YA = globalThis.YA;
  if (!YA.Renderer) return;
  const R = YA.Renderer.prototype;
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const L = 105;
  const W = 68;
  const baseUpdate = R.update;
  const baseStart = R.startScene;
  const baseEnd = R.endScene;
  const baseDraw = R.draw;
  const isLive = (r) => !!(r.match && r.match.live);
  const OFF = [-200, -200, 0]; // ボールを出さないときの置き場（画面の外）
  R.update = function (dt) {
    if (!isLive(this)) return baseUpdate.call(this, dt);
    this.liveStep(dt);
  };
  R.startScene = function (sc) {
    if (!isLive(this) || !sc.live) return baseStart.call(this, sc);
    this.scene = sc;
    this.t = 0;
    this.pre = null;
    this.celeb = null;
    this.flash = 0;
    this.cut = 0.3;
    this.trails = [];
    this._step = 0;
    this._seg = null;
    this.focus = [sc.shooter, sc.assist].filter(Boolean);
    this.defFocus = [];
    this.capText = null;
    // 選手はシュートの瞬間の位置で止める
    const m = this.match;
    const lv = m.live;
    const disp = {};
    const base = {};
    for (const [id, x, y] of sc.live.snap || []) {
      const w = lv.who[id] || { sd: 'home', gk: false };
      const cur = lv.byId[id];
      disp[id] = [x, y];
      base[id] = [x, y, w.sd === 'home' ? m.home : m.away, cur ? cur.i : w.gk ? 0 : 50, cur ? cur.s : null];
    }
    this.disp = disp;
    this.base = base;
    this.vel = {};
    this.owner = null;
    this.fl = {};
    const p0 = sc.live.path && sc.live.path[0];
    this.ball = p0 ? [p0.from[0], p0.from[1], 0] : OFF.slice();
    this.bh = [];
    this.poss = sc.side;
    // 見る場所：道筋とゴールが入る所
    const ys = (sc.live.path || []).reduce((a, s) => a.concat([s.from[1], s.to[1]]), [sc.side === 'home' ? L : 0]);
    this._camY = clamp((Math.min(...ys) + Math.max(...ys)) / 2, 26, L - 26);
  };
  R.endScene = function () {
    if (!isLive(this)) return baseEnd.call(this);
    this.scene = null;
    this.focus = [];
    this.defFocus = [];
    this.celeb = null;
    this.capText = null;
    this.trails = [];
    this.cut = 0.25;
    this._idle = false;
  };
  // 合間：並びを止めた図
  R.liveIdle = function () {
    const m = this.match;
    const bp = this.basePositions();
    const disp = {};
    const base = {};
    for (const id of Object.keys(bp)) {
      const b = bp[id];
      const home = b[2] === m.home;
      // 両チームが重ならないよう、自陣側へ寄せて置く（ホームは左、アウェイは右）
      const y = home ? 4 + (b[1] - 4) * 0.56 : L - 4 - (L - 4 - b[1]) * 0.56;
      disp[id] = [b[0], y];
      base[id] = [b[0], y, b[2], b[3], b[4]];
    }
    this.disp = disp;
    this.base = base;
    this.vel = {};
    this.owner = null;
    this.fl = {};
    this.ball = OFF.slice();
    this.bh = [];
    this.trails = [];
    this._idle = true;
    this._idleKey = m.home.lineup.map((s) => s.pid + ':' + s.x + ':' + s.y).join() + '|' + m.away.lineup.map((s) => s.pid).join();
  };
  R.liveStep = function (dt) {
    const m = this.match;
    this.clock = (this.clock || 0) + dt;
    if (this.cut > 0) this.cut = Math.max(0, this.cut - dt);
    const c = this.cam;
    const sc = this.scene && this.scene.live ? this.scene : null;
    if (!sc) {
      const key = m.home.lineup.map((s) => s.pid + ':' + s.x + ':' + s.y).join() + '|' + m.away.lineup.map((s) => s.pid).join();
      if (!this._idle || key !== this._idleKey) this.liveIdle();
      // 流れのバー：直近（20秒ぶんの保持）のボールの持ち方
      const ps = m.live.poss;
      const tot = ps.home + ps.away;
      const last = this._ps || { h: 0, t: 0 };
      if (tot - last.t > 20) {
        this._flowT = clamp((ps.home - last.h) / Math.max(1, tot - last.t), 0.2, 0.8);
        this._ps = { h: ps.home, t: tot };
      }
      const want = this._flowT == null ? 0.5 : this._flowT;
      this.flow = this.flow == null ? 0.5 : this.flow + (want - this.flow) * (1 - Math.exp(-dt / 1.5));
      this.flash = 0;
      c.zoom += (1 - c.zoom) * (1 - Math.exp(-dt * 3));
      c.cy += (L / 2 - c.cy) * (1 - Math.exp(-dt * 3));
      c.cx += (W / 2 - c.cx) * (1 - Math.exp(-dt * 3));
      return;
    }
    this.t += dt;
    const path = sc.live.path || [];
    // 線を順に引く
    while (this._step < path.length && this.t >= path[this._step].at) {
      const st = path[this._step++];
      this.trails.push({ from: st.from, to: st.to, kind: st.type === 'shot' ? 'shot' : st.type === 'loft' ? 'loft' : st.type === 'carry' ? 'carry' : 'pass', life: 1, keep: true });
      const p = m.home.players[st.pid] || m.away.players[st.pid];
      if (p && st.type !== 'carry') this.capText = { text: p.num + '番 ' + (st.type === 'shot' ? 'シュート' : st.kind === 'cross' ? 'クロス' : st.kind === 'through' ? 'スルーパス' : st.type === 'loft' ? '浮き球' : 'パス'), t: 0 };
      this._seg = { st, t0: this.t, done: false };
    }
    // ボールは、いま引いた線の上を進む（0.6秒。シュートは0.4秒）
    if (this._seg) {
      const g = this._seg;
      const k = clamp((this.t - g.t0) / (g.st.type === 'shot' ? 0.4 : 0.6), 0, 1);
      const z = g.st.type === 'loft' ? Math.sin(k * Math.PI) * 3 : 0;
      this.ball = [g.st.from[0] + (g.st.to[0] - g.st.from[0]) * k, g.st.from[1] + (g.st.to[1] - g.st.from[1]) * k, z];
      if (k >= 1 && g.st.type === 'shot' && !g.done) {
        g.done = true;
        if (g.st.res === 'goal') {
          this.flash = 1;
          this.noteNet();
          if (sc.scorer) this.celeb = { scorer: sc.scorer, spot: this.disp[sc.scorer] || [34, 52], mates: [], t: 0 };
        }
      }
    }
    if (this.celeb) this.celeb.t += dt;
    if (this.capText) this.capText.t += dt;
    this.flash = Math.max(0, (this.flash || 0) - dt * 0.6);
    // 見る場所はピッチ全体のまま動かさない（寄ると、外へ開いたパスが画面から切れた）
    c.zoom = 1;
    c.cy = L / 2;
    c.cx = W / 2;
  };
  // 図の上に、パスを出した所の番号を小さく添える（選手はシュートの瞬間の位置に止めてあるので、出した所は別に示す）
  R.draw = function () {
    baseDraw.call(this);
    if (!isLive(this) || !this.scene || !this.scene.live || !this.ctx) return;
    const ctx = this.ctx;
    const { s, P } = this.view();
    const m = this.match;
    const path = this.scene.live.path || [];
    ctx.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);
    for (let i = 0; i < Math.min(this._step || 0, path.length); i++) {
      const st = path[i];
      if (st.type === 'carry') continue;
      const p = m.home.players[st.pid] || m.away.players[st.pid];
      if (!p) continue;
      const cur = this.disp[st.pid];
      // 出した所が、いまの位置（シュートの瞬間）から離れているときだけ
      if (cur && Math.hypot(cur[0] - st.from[0], cur[1] - st.from[1]) < 3) continue;
      const q = P(st.from[0], st.from[1]);
      const r = Math.max(7, s * 1.5);
      ctx.fillStyle = 'rgba(15,25,40,.82)';
      ctx.beginPath();
      ctx.arc(q[0], q[1], r, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = 'rgba(255,255,255,.9)';
      ctx.lineWidth = 1.2;
      ctx.stroke();
      ctx.fillStyle = '#ffffff';
      ctx.font = '800 ' + Math.round(r * 1.05) + 'px system-ui, sans-serif';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(String(p.num), q[0], q[1] + 0.5);
      ctx.textBaseline = 'alphabetic';
    }
  };
})();
