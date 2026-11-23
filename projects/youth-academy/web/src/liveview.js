// 一続きの試合（live.js）の再生（2026-11-23）。描き方は render.js の draw をそのまま使い、
// 位置は live.js が残した記録（10コマ/秒）を補間して置く。動きを作り足すことはしない。
//   合間：記録を等倍で流す（試合の時計は先に進むので、合間の絵は少し前の本当のプレー）。
//   見どころ：その攻めの始まりへ切り替えて（一瞬暗く）、シュートの結末まで流す。終わったらその続きから流す。
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
  const isLive = (r) => !!(r.match && r.match.live && r.match.live.record);
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
    if (Math.abs((this.fc || 0) - sc.live.t0) > 0.6) this.cut = 0.35;
    this.fc = sc.live.t0;
    this._ei = null; // 出来事の位置は場面の頭に合わせ直す（飛ばした間の線や動きを描かない）
    this.focus = [sc.shooter, sc.assist].filter(Boolean);
    this.defFocus = sc.gk ? [sc.gk] : [];
    this.trails = [];
  };
  R.endScene = function () {
    if (!isLive(this)) return baseEnd.call(this);
    this.scene = null;
    this.focus = [];
    this.defFocus = [];
    this.celeb = null;
    this.capText = null;
  };
  // 記録の中の時刻 fc の位置へ
  R.liveFrameAt = function (fc) {
    const F = this.match.live.frames;
    if (!F.length) return null;
    let i = this._fi || 0;
    if (i >= F.length) i = F.length - 1;
    while (i > 0 && F[i].t > fc) i--;
    while (i < F.length - 1 && F[i + 1].t <= fc) i++;
    this._fi = i;
    return i;
  };
  R.liveStep = function (dt) {
    const m = this.match;
    const lv = m.live;
    const F = lv.frames;
    this.clock = (this.clock || 0) + dt;
    if (!F.length) return;
    const prev = this.fc == null ? F[0].t : this.fc;
    if (this.scene && this.scene.live) {
      this.t += dt;
      this.fc = this.scene.live.t0 + this.t;
    } else {
      this.fc = prev + dt;
      // 合間：絵が試合の時計から5分より遅れたら、いまの時間帯（動かし終えた所の約50秒前）へ飛ぶ。
      // 合間の絵はいつも「いまの数分」の本当のプレーになる（2026-11-24：前は見どころの続きを流し続け、時計と絵が離れていった）
      const now = F[F.length - 1].t;
      if (now - this.fc > 300 && !this.celeb) {
        this.fc = Math.max(F[0].t, now - 50);
        this.cut = 0.3;
        this.trails = [];
        this._ei = null;
      }
    }
    // 記録の先（まだ動かしていない所）へは行かない
    const lastT = F[F.length - 1].t;
    if (this.fc > lastT - 0.05) this.fc = lastT - 0.05;
    if (this.fc < F[0].t) this.fc = F[0].t;
    const fc = this.fc;
    // 見終わった記録は捨てる（iPhone のメモリのため。全90分を残すと約17MB）。見どころは今より先の攻めの始まりから
    // 再生するので、40秒より前は二度と使わない
    if (F.length > 1200 && F[600].t < fc - 40) {
      F.splice(0, 600);
      this._fi = Math.max(0, (this._fi || 0) - 600);
    }
    const i = this.liveFrameAt(fc);
    const f0 = F[i];
    const f1 = F[Math.min(i + 1, F.length - 1)];
    const span = f1.t - f0.t;
    const k = span > 1e-6 && f0.rv === f1.rv ? clamp((fc - f0.t) / span, 0, 1) : 0;
    // 置き直し（再開・後半・交代）で位置が大きく飛ぶ所は一瞬暗くする
    if (f0.rv !== this._rv) {
      this._rv = f0.rv;
      this.cut = Math.max(this.cut || 0, 0.25);
    }
    const disp = {};
    const vel = {};
    const base = {};
    const ro = f0.ro;
    for (let j = 0; j < ro.length; j++) {
      const id = ro[j];
      const x = f0.p[j * 2] + (f1.p[j * 2] - f0.p[j * 2]) * k;
      const y = f0.p[j * 2 + 1] + (f1.p[j * 2 + 1] - f0.p[j * 2 + 1]) * k;
      disp[id] = [x, y];
      vel[id] = span > 1e-6 ? [(f1.p[j * 2] - f0.p[j * 2]) / span, (f1.p[j * 2 + 1] - f0.p[j * 2 + 1]) / span] : [0, 0];
      const w = lv.who[id] || { sd: 'home', gk: false };
      const cur = lv.byId[id];
      base[id] = [x, y, w.sd === 'home' ? m.home : m.away, cur ? cur.i : w.gk ? 0 : 50, cur ? cur.s : null]; // [3] は並びの番号（0＝GK。横の名簿の順）
      // 大きく飛んだ（置き直し）
      const o = this.disp && this.disp[id];
      if (o && Math.hypot(o[0] - x, o[1] - y) > 6 && !this.scene) this.cut = Math.max(this.cut || 0, 0.3);
    }
    this.disp = disp;
    this.vel = vel;
    this.base = base;
    const b0 = f0.b;
    const b1 = f1.b;
    this.ball = [b0[0] + (b1[0] - b0[0]) * k, b0[1] + (b1[1] - b0[1]) * k, Math.max(0, b0[2] + (b1[2] - b0[2]) * k)];
    this.owner = f0.o >= 0 ? ro[f0.o] : null;
    this.fl = this.owner ? null : {};
    this.poss = this.owner ? lv.who[this.owner] && lv.who[this.owner].sd : this.poss;
    // 出来事：蹴った線・体の動き・GK の飛びつき（前のコマから今までに起きたもの）
    const E = lv.events;
    let ei = this._ei || 0;
    if (this._ei == null) {
      // 飛んだ直後：出来事の位置をいまの時刻へ合わせる（間の出来事は描かない）
      ei = 0;
      while (ei < E.length && E[ei].t <= fc) ei++;
    } else if (fc < prev - 0.01) {
      // 戻った（見どころの頭へ）：その時刻の出来事の位置まで戻す
      while (ei > 0 && E[ei - 1].t > fc) ei--;
    } else {
      while (ei < E.length && E[ei].t <= fc) {
        const e = E[ei++];
        if (e.t <= prev) continue;
        this.liveEvent(e);
      }
    }
    this._ei = ei;
    for (const tr of this.trails) tr.life -= dt * (this.owner ? 1.2 : 0.35);
    this.trails = this.trails.filter((tr) => tr.life > 0);
    if (this.dive) {
      this.dive.t += dt;
      if (this.dive.t > this.dive.end + 0.3) this.dive = null;
    }
    if (this.celeb) this.celeb.t += dt;
    if (this.cut > 0) this.cut = Math.max(0, this.cut - dt);
    if (this.flash > 0 && !(this.scene && this.scene.goal)) this.flash = Math.max(0, this.flash - dt);
    this.noteNet();
    // 流れのバー：直近のボールの持ち方
    const own = this.owner ? (lv.who[this.owner] && lv.who[this.owner].sd === 'home' ? 1 : 0) : null;
    this.flow = this.flow == null ? 0.5 : this.flow;
    if (own != null) this.flow = clamp(this.flow + (own - this.flow) * (1 - Math.exp(-dt / 25)), 0.2, 0.8);
    const sd = (this.strd = this.strd || {});
    for (const id of Object.keys(vel)) sd[id] = (sd[id] || 0) + Math.hypot(vel[id][0], vel[id][1]) * dt;
    this.stepRefs(dt);
    this.bh = this.bh || [];
    this.bh.push(this.ball.slice());
    if (this.bh.length > 6) this.bh.shift();
    if (this.cut > 0.3) this.bh = [];
    // 見る場所
    const c = this.cam;
    const kk = 1 - Math.exp(-dt * 2.2);
    const zw = this.scene ? 1.45 : 1;
    c.zoom += (zw - c.zoom) * (1 - Math.exp(-dt * 1.6));
    c.cy += (this.ball[1] - c.cy) * kk;
    c.cx += (this.ball[0] - c.cx) * kk;
    if (this.cut > 0.3) {
      c.cy = this.ball[1];
      c.cx = this.ball[0];
    }
    if (this.capText) this.capText.t += dt;
  };
  R.liveEvent = function (e) {
    const d = this.disp || {};
    const m = this.match;
    const P = (pid) => (m.home.players[pid] || m.away.players[pid] || null);
    if (e.k === 'kick') {
      if (e.kind !== 'shot') this.trails.push({ from: [e.x, e.y], to: [e.tx, e.ty], kind: e.loft ? 'loft' : 'pass', life: 1 });
      else this.trails.push({ from: [e.x, e.y], to: [e.tx, e.ty], kind: 'shot', life: 1 });
      if (d[e.pid]) this.pose(e.pid, 'kick', [e.tx - d[e.pid][0], e.ty - d[e.pid][1]]);
      if (this.scene && (e.kind === 'through' || e.kind === 'cross')) {
        const p = P(e.pid);
        if (p) this.capText = { text: p.num + '番 ' + (e.kind === 'cross' ? 'クロス' : 'スルーパス'), t: 0 };
      }
    } else if (e.k === 'header') {
      if (d[e.pid]) this.pose(e.pid, 'jump', [0, 1]);
    } else if (e.k === 'tackle' && e.ok) {
      const v = d[e.vs];
      if (d[e.pid] && v) this.pose(e.pid, 'slide', [v[0] - d[e.pid][0], v[1] - d[e.pid][1]]);
    } else if (e.k === 'save') {
      const g = d[e.pid];
      if (g) this.dive = { id: e.pid, t: 0, t0: 0, dur: 0.22, end: 0.65, from: g.slice(), tgt: [this.ball[0], this.ball[1]] };
    } else if (e.k === 'shot') {
      const p = P(e.pid);
      if (p && this.scene) this.capText = { text: p.num + '番 ' + (e.head ? 'ヘディング' : 'シュート'), t: 0 };
    } else if (e.k === 'goal') {
      this.flash = 1;
      const sc = this.scene;
      const sid = (sc && sc.scorer) || e.pid;
      if (sid && d[sid]) this.celeb = { scorer: sid, spot: d[sid], mates: [], t: 0 };
    }
  };
  void L;
  void W;
})();
