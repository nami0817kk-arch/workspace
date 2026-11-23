// 一続きの試合（2026-11-23「やはり試合の動きがおかしい。容量増えてもいいから、ちゃんとサッカーの試合なるようにして」）。
// 90分を、22人の頭とボールの物理で一続きに動かす。パス・ドリブル・シュート・タックル・セーブの成否は、
// その場の位置と選手の能力（engine の eff。疲れ・調子・役割の合い方込み）から決まり、得点もその中から生まれる。
// 見せ方には依存しない（座標は m。ピッチは横 W=68・縦 L=105。ホームは +y へ攻める）。
// 記録（record）を付けると 10コマ/秒で全員とボールの位置を残す。画面はそれを再生する。
(function () {
  'use strict';
  const YA = (globalThis.YA = globalThis.YA || {});
  const W = 68;
  const L = 105;
  const GW = 3.66; // ゴールの幅の半分
  const GH = 2.44; // ゴールの高さ
  const DT = 0.1; // 物理の刻み（秒）。ボールの当たりは刻みの間の通り道で見る
  const G = 9.8;
  const FRIC = 3.6; // 地を這う球の減速（m/s²）
  const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
  const hyp = (a, b) => Math.sqrt(a * a + b * b); // Math.hypot は遅い
  const nvSlow = (b) => b.vx * b.vx + b.vy * b.vy < 2.5 * 2.5;

  // 点 p から線分 a→b までの距離と、線分上の位置（0〜1）
  // （配列を作らないように、位置 t は segT に置く）
  let segT = 0;
  function segD(px, py, ax, ay, bx, by) {
    const vx = bx - ax;
    const vy = by - ay;
    const l2 = vx * vx + vy * vy || 1e-6;
    const t = clamp(((px - ax) * vx + (py - ay) * vy) / l2, 0, 1);
    segT = t;
    return hyp(px - (ax + vx * t), py - (ay + vy * t));
  }

  // 能力の名前 → 短い鍵（0〜1 に直して持つ）
  const AB = {
    spd: 'スピード', acc: '加速', agi: '敏しょう性', bal: 'バランス', str: '強さ', jmp: 'ジャンプ', sta: 'スタミナ',
    ft: 'ファーストタッチ', pas: 'パス', dri: 'ドリブル', fin: 'フィニッシュ', lsh: 'ロングシュート', crs: 'クロス', hea: 'ヘディング',
    tck: 'タックル', mrk: 'マーク', tec: 'テクニック', set: 'プレースキック', pk: 'PK',
    ant: '予測', dec: '判断', vis: '視野', pos: 'ポジショニング', off: 'オフザボール', tw: 'チームワーク', wr: '運動量', con: '集中', cmp: '冷静さ',
    han: 'ハンドリング', ref: '反応', ovo: '1対1', rush: '飛び出し', air: '空中戦', dist: '配球',
  };

  class Live {
    // m：engine の Match（チーム・並び・戦術・疲れ・カードはそちらが持つ）。opts.record＝位置を残す
    constructor(m, opts) {
      opts = opts || {};
      this.m = m;
      this.rng = YA.rngOf(((m._seed | 0) * 7919 + 101) | 0);
      this.record = !!opts.record;
      this.t = 0; // 試合の時計（秒。前半0〜、後半は 45分から）
      this.half = 1;
      this.P = [];
      this.byId = {};
      this.who = {}; // 一度でも出た子（記録の再生で、交代で下がった子も描けるように）
      this.fx = []; // 効いた特性 { t, pid, tag }
      this.ball = { x: W / 2, y: L / 2, z: 0, vx: 0, vy: 0, vz: 0, px: null, py: null, owner: null, last: null, lastTeam: null };
      this.events = []; // { t, k, ... }（試合の出来事。engine の側が拾う）
      this.frames = []; // 記録：{ t, b:[x,y,z], o:持っている子の番号, p:Float32Array(22*2) }
      this.roster = []; // 記録の番号 → pid
      this.state = 'dead';
      this.restart = null;
      this.passes = { home: 0, away: 0, homeOk: 0, awayOk: 0 };
      this.poss = { home: 0, away: 0 };
      this.tick = 0;
      this.sync();
      this.kickoff(m.kickoffSide || 'home', true);
    }

    // ---------- 選手 ----------
    teamOf(sd) {
      return sd === 'home' ? this.m.home : this.m.away;
    }
    // 並びと出ている子を engine に合わせる（交代・退場のあと）。位置は pid で引き継ぐ
    sync() {
      const old = this.byId;
      const P = [];
      const byId = {};
      for (const sd of ['home', 'away']) {
        const t = this.teamOf(sd);
        const dir = sd === 'home' ? 1 : -1;
        t.lineup.forEach((s, i) => {
          const p = t.players[s.pid];
          if (!p) return;
          const o = old[s.pid];
          const gk = i === 0;
          const depth = (YA.DUTY && YA.DUTY[s.duty] ? YA.DUTY[s.duty].depth : 0) * 60;
          const bu = gk ? 1.5 : clamp(6 + s.y * 80 + depth, 6, 96); // 自陣のゴールからの深さ（4-4-2 で最終ライン約 20m・前線約 75m）
          const bx = s.x * W;
          // 項目はすべて同じ順で先に作る（あとから足すと V8 の形が揃わず、遅くなる）
          const q = o || { id: null, p: null, s: null, i: 0, sd: '', dir: 1, gk: false, bu: 0, bx: 0, team: null, k: 0, a: null, vmax: 0, amax: 0, tr: null,
            x: 0, y: 0, vx: 0, vy: 0, tx: 0, ty: 0, urg: 0.6, cool: 0, stun: 0, think: 0, ox: 0, oy: 0, press: 0, dx: null, dy: null, carry: 0.7, hold: 0, nd: 99,
            run: 0, trk: null, trkT: -9, marked: null, markT: -9, blocked: 0, dive: -9 };
          Object.assign(q, { id: s.pid, p, s, i, sd, dir, gk, bu, bx, team: t });
          if (!o) {
            const [x, y] = this.abs(q, bx, Math.min(bu * 0.5, 48));
            q.x = x;
            q.y = y;
            q.tx = x;
            q.ty = y;
            q.cool = 0;
            q.stun = 0;
            q.think = 0;
            q.ox = 0;
            q.oy = 0;
          }
          q.k = P.length;
          P.push(q);
          byId[s.pid] = q;
          this.who[s.pid] = { sd, gk };
        });
      }
      this.P = P;
      this.byId = byId;
      this.roster = P.map((q) => q.id);
      this.rosterV = (this.rosterV || 0) + 1;
      if (this.ball.owner && !byId[this.ball.owner.id]) this.ball.owner = null;
      this.refreshAb();
    }
    // 能力を 0〜1 で持ち直す（疲れは engine が毎分 p.stam を減らすので、毎分呼ぶ）
    refreshAb() {
      for (const q of this.P) {
        const a = {};
        for (const k in AB) {
          const v = YA.eff ? YA.eff(q.p, AB[k], this.m) : q.p.ab[AB[k]] || 10;
          a[k] = clamp(((v || 10) - 1) / 19, 0, 1.1);
        }
        q.a = a;
        q.vmax = 5.9 + a.spd * 3.1; // 5.9〜9.0 m/s
        q.amax = 3.6 + a.acc * 3.6;
        const tr = q.p.traits || [];
        q.tr = new Set(tr.concat(q.p.aw && q.p.aw.as ? q.p.aw.as : [], q.p.aw2 && q.p.aw2.as ? q.p.aw2.as : []));
      }
    }
    // チームの向きの座標（u＝自陣のゴールからの深さ、x）→ 絶対座標
    abs(q, x, u) {
      return q.dir > 0 ? [x, u] : [W - x, L - u];
    }
    uOf(q, y) {
      return q.dir > 0 ? y : L - y;
    }
    xOf(q, x) {
      return q.dir > 0 ? x : W - x;
    }
    mates(q) {
      return this.P.filter((r) => r.sd === q.sd && r !== q);
    }
    opps(sd) {
      return this.P.filter((r) => r.sd !== sd);
    }
    gkOf(sd) {
      return this.P.find((r) => r.sd === sd && r.gk) || null;
    }
    has(q, tr) {
      return q.tr.has(tr);
    }
    // 特性が効いた（金の特性の数え方。engine の _use と同じ）
    useTr(q, tr) {
      if (this.m._use) this.m._use(q.p, tr);
      this.fx.push({ t: this.t, pid: q.id, tag: tr, sd: q.sd });
    }
    ev(k, o) {
      const e = Object.assign({ t: this.t, k }, o || {});
      this.events.push(e);
      return e;
    }
    // 守り手の後ろから2人目（オフサイドの線）を、攻める側の深さ u で
    offLine(sd) {
      const us = [];
      for (const r of this.P) if (r.sd !== sd) us.push(L - this.uOf(r, r.y));
      // 攻める側から見た深さに直す（相手の u は相手のゴールから。攻める側の u = L - 相手の u）
      us.sort((a, b) => b - a);
      const ball = this.uOfSide(sd, this.ball.y);
      return Math.max(us[1] != null ? us[1] : L - 1, ball, L / 2);
    }
    uOfSide(sd, y) {
      return sd === 'home' ? y : L - y;
    }

    // ---------- 時計 ----------
    // 試合の時計を toSec まで進める（物理を 1/20 秒ずつ）
    runTo(toSec) {
      while (this.t < toSec - 1e-9) this.step();
    }
    step() {
      const b = this.ball;
      if (this.state === 'dead') this.stepDead();
      else this.stepPlay();
      this.moveAll();
      this.moveBall();
      if (b.owner) this.poss[b.owner.sd] += DT;
      this.t += DT;
      this.tick++;
      if (this.record) this.snap();
    }
    snap() {
      const b = this.ball;
      const ps = new Float32Array(this.P.length * 2);
      this.P.forEach((q, i) => {
        ps[i * 2] = q.x;
        ps[i * 2 + 1] = q.y;
      });
      this.frames.push({ t: this.t, b: [b.x, b.y, b.z], o: b.owner ? b.owner.k : -1, p: ps, rv: this.rosterV, ro: this.roster, st: this.state });
    }

    // ---------- 止まっているとき（再開の準備） ----------
    setDead(type, sd, x, y, wait, extra) {
      const b = this.ball;
      b.owner = null;
      b.vx = b.vy = b.vz = 0;
      b.z = 0;
      this.state = 'dead';
      this.flight = null;
      this.restart = Object.assign({ type, sd, x: clamp(x, 0, W), y: clamp(y, 0, L), at: this.t + wait, taker: null, placed: false }, extra || {});
      this.ev('dead', { type, sd, x, y });
    }
    kickoff(sd, first) {
      this.ball.x = W / 2;
      this.ball.y = L / 2;
      this.setDead('kickoff', sd, W / 2, L / 2, first ? 0.5 : 5);
      if (first) for (const q of this.P) {
        const [tx, ty] = this.setPos(q);
        q.x = tx;
        q.y = ty;
      }
    }
    // 再開のときの立ち位置
    setPos(q) {
      const r = this.restart;
      const own = q.sd === r.sd;
      const ru = this.uOf(q, r.y);
      const rx = this.xOf(q, r.x);
      if (r.type === 'kickoff') {
        if (q.gk) return this.abs(q, W / 2, 4);
        const u = clamp(q.bu * 0.55, 8, 50.5);
        let x = q.bx;
        if (own && q === r.taker) return this.abs(q, W / 2 - 0.5, L / 2 - 0.4);
        if (!own) {
          // 相手はセンターサークルの外
          const d = hyp(x - W / 2, u - L / 2);
          if (d < 9.6) return this.abs(q, x, Math.min(u, L / 2 - 9.6));
        }
        return this.abs(q, x, u);
      }
      if (r.type === 'pk') {
        if (q === r.taker) return [r.x, r.y + (r.y > L / 2 ? -1 : 1)];
        if (q.gk && !own) return this.abs(q, W / 2, 0.2);
        const [x, u] = [clamp(q.bx, 14, 54), own ? 84 : 84];
        return this.abs(q, x, Math.min(this.uOf(q, this.abs(q, x, u)[1]), q.gk ? 30 : 86.5));
      }
      if (r.type === 'corner') {
        if (q === r.taker) return [r.x + (r.x < W / 2 ? -0.4 : 0.4), r.y + (r.y < L / 2 ? -0.4 : 0.4)];
        if (q.gk) return own ? this.abs(q, W / 2, 30) : this.abs(q, W / 2, 0.8);
        // 攻める側は箱の中へ、守る側は箱の中で人とゾーン
        const slot = (q.i * 37) % 7;
        const xs = [27, 30, 34, 38, 41, 31, 37];
        const us = own ? [93, 95, 98, 96, 92, 88, 85] : [97, 99, 100, 99, 97, 94, 91];
        if (own && (q.s.y < 0.25)) return this.abs(q, q.bx * 0.6 + 13, 55 + q.s.y * 40);
        if (!own && q.s.y > 0.75) return this.abs(q, W / 2 + (q.bx - W / 2) * 0.4, 70);
        const u = own ? us[slot] : L - us[slot] + 0;
        return own ? this.abs(q, xs[slot], u) : this.abs(q, xs[slot], clamp(105 - us[slot], 4, 16));
      }
      if (r.type === 'goalkick') {
        if (own && q.gk) return [r.x, r.y];
        if (!own) {
          // 蹴る側の箱の外（ゴールラインから18m より前）まで下がる
          const [sx, sy] = this.shapeTarget(q, false, r.x, r.y);
          const ku = this.uOfSide(r.sd, sy); // 蹴る側から見た深さ
          return [sx, ku < 18 ? (r.sd === 'home' ? 18 : L - 18) : sy];
        }
        return this.abs(q, q.bx, clamp(q.bu * 0.75, 12, 60));
      }
      // スローイン・FK：蹴る子は球へ、ほかは形（ボールの位置を見て）
      if (q === r.taker) return [r.x, r.y];
      const [sx, sy] = this.shapeTarget(q, own, r.x, r.y);
      if (r.type === 'fk' && !own) {
        // 9.15m 離れる
        const d = hyp(sx - r.x, sy - r.y);
        if (d < 9.2) {
          const k = 9.2 / (d || 1);
          return [clamp(r.x + (sx - r.x) * k, 0.5, W - 0.5), clamp(r.y + (sy - r.y) * k, 0.5, L - 0.5)];
        }
      }
      return [sx, sy];
    }
    stepDead() {
      const r = this.restart;
      const b = this.ball;
      if (!r.taker) r.taker = this.pickTaker(r);
      if (!r.placed) {
        // ボールは置き場所へ（転がして戻す絵は画面の側。ここでは置く）
        b.x = r.x;
        b.y = r.y;
        r.placed = true;
      }
      for (const q of this.P) {
        const [tx, ty] = this.setPos(q);
        q.tx = tx;
        q.ty = ty;
        q.urg = q === r.taker ? 0.85 : 0.55;
      }
      if (this.t < r.at) return;
      const tk = r.taker;
      if (!tk || hyp(tk.x - r.x, tk.y - r.y) > 1.6) return;
      // 相手が近すぎる再開は待つ（キックオフ・FK）
      this.state = 'play';
      b.owner = tk;
      b.last = tk;
      b.lastTeam = tk.sd;
      tk.hold = 0;
      const type = r.type;
      this.restart = null;
      this.setPiece = { type, t: this.t, sd: tk.sd };
      this.ev('restart', { type, sd: tk.sd, pid: tk.id });
      if (type === 'pk') return this.shoot(tk, { pk: true });
      if (type === 'corner') return this.cross(tk, true);
      if (type === 'kickoff') {
        const back = this.mates(tk).filter((q) => !q.gk && this.uOf(q, q.y) < L / 2 - 1).sort((a, c) => hyp(a.x - tk.x, a.y - tk.y) - hyp(c.x - tk.x, c.y - tk.y))[0];
        if (back) return this.pass(tk, back, { safe: true });
      }
      if (type === 'throw') {
        const tgt = this.bestPass(tk, { maxD: 22, throwIn: true });
        if (tgt) return this.pass(tk, tgt.q, { throwIn: true, lead: tgt.lead });
        return;
      }
      if (type === 'fk') {
        const du = L - this.uOf(tk, r.y);
        const dx = Math.abs(r.x - W / 2);
        if (du < 30 && du > 16 && dx < 20 && this.rng() < 0.75) return this.shoot(tk, { fk: true });
        if (du < 40 && this.rng() < 0.6) return this.cross(tk, true);
      }
      // 自由に（判断に任せる）
      tk.think = 0.4;
    }
    pickTaker(r) {
      const own = this.P.filter((q) => q.sd === r.sd);
      if (!own.length) return null;
      if (r.type === 'goalkick') return own.find((q) => q.gk) || own[0];
      const field = own.filter((q) => !q.gk);
      if (r.type === 'pk' || r.type === 'corner' || (r.type === 'fk' && L - this.uOf(field[0] || own[0], r.y) < 40)) {
        const key = r.type === 'pk' ? 'pk' : 'set';
        const tac = this.teamOf(r.sd).tactic || {};
        const pick = r.type === 'pk' ? tac.pk : r.type === 'corner' ? tac.ck : tac.fk;
        const named = pick && this.byId[pick] && this.byId[pick].sd === r.sd && !this.byId[pick].gk ? this.byId[pick] : null;
        return named || field.slice().sort((a, c) => c.a[key] - a.a[key])[0];
      }
      if (r.type === 'kickoff') return field.slice().sort((a, c) => c.bu - a.bu)[0];
      // いちばん近い子
      return field.slice().sort((a, c) => hyp(a.x - r.x, a.y - r.y) - hyp(c.x - r.x, c.y - r.y))[0] || own[0];
    }

    // ---------- 動いているとき ----------
    stepPlay() {
      const b = this.ball;
      const own = b.owner;
      const attSd = own ? own.sd : b.lastTeam || 'home';
      this.attSd = attSd;
      // 守りの寄せ役（プレス）：持っている子に近い順
      if (this.tick % 2 === 0 || attSd !== this._pdSd) this.planDefense(attSd);
      this._pdSd = attSd;
      for (const q of this.P) {
        q.think -= DT;
        if (q.stun > 0) q.stun -= DT;
        if (q.cool > 0) q.cool -= DT;
        if (q === own) continue;
        if (q.think <= 0) {
          // GK は立ち位置を毎刻み直す（シュートの角度に遅れない）
          q.think = q.gk ? 0 : 0.4 + (1 - q.a.dec) * 0.45 + this.rng() * 0.3;
          this.offBall(q, attSd);
        }
        this.steer(q, attSd);
      }
      if (own) this.ownerAct(own);
      else if (this.tick % 2 === 0 || !this._looseOk) { this.loose(); this._looseOk = true; }
    }
    // 守る側の役：寄せる子（1〜3人）・その後ろでパスの線を切る子
    planDefense(attSd) {
      const b = this.ball;
      const defSd = attSd === 'home' ? 'away' : 'home';
      const tac = this.teamOf(defSd).tactic || {};
      const ds = this.P.filter((q) => q.sd === defSd && !q.gk);
      for (const q of this.P) q.press = 0;
      if (!b.owner && !this.flight) return;
      const bx = this.flight ? this.flight.tx : b.x;
      const by = this.flight ? this.flight.ty : b.y;
      ds.sort((a, c) => hyp(a.x - bx, a.y - by) - hyp(c.x - bx, c.y - by));
      // 寄せる人数は戦術のプレスと、ボールのある所（相手陣の奥ほど前から行くかは press で決まる）
      const bu = this.uOfSide(defSd, by); // 守る側から見たボールの深さ
      const high = bu > 60 ? tac.press : 1; // 相手陣のボールに行くかはプレス次第
      const n = bu < 40 ? 2 : 1 + (this.rng() < (tac.press || 0.5) * high ? 1 : 0);
      for (let k = 0; k < Math.min(n, ds.length); k++) ds[k].press = k + 1;
    }
    // 形：チームの立ち位置（ボールの位置・攻守・戦術から）
    shapeTarget(q, attacking, bx0, by0) {
      const t = q.team;
      const tac = t.tactic || {};
      const bx = this.xOf(q, bx0);
      const bu = this.uOf(q, by0);
      if (q.gk) {
        if (attacking) return this.abs(q, W / 2 + (bx - W / 2) * 0.15, clamp(bu * 0.22, 4, 16 + (tac.line || 0.5) * 10));
        // ゴールとボールを結ぶ線の上、ボールが近いほど前へ
        const gx = W / 2;
        const d = hyp(bx - gx, bu);
        let out = clamp(1.2 + d * 0.05 + (q.a.rush || 0.5) * 1.2, 1, 5.5);
        // 相手が持ってゴールに迫ったら、角度を狭めに出る（飛び出し・1対1）
        if (this.ball.owner && this.ball.owner.sd !== q.sd && d < 17) out = clamp(Math.min(d - 1.8, 2.5 + q.a.rush * 3 + q.a.ovo * 1.5), 1, 7);
        return this.abs(q, gx + ((bx - gx) / (d || 1)) * out * 0.9, ((bu) / (d || 1)) * out + 0.3);
      }
      const f = (q.bu - 18) / 58; // 0＝最終ライン〜1＝最前線
      let x;
      let u;
      if (attacking) {
        const width = tac.width == null ? 0.5 : tac.width;
        const lineU = clamp(bu - 30 + (tac.line || 0.5) * 8, 14, 62);
        const opLine = this.offLineU || 70;
        const frontU = clamp(Math.max(bu + 6, opLine - 1.2), lineU + 26, 101);
        u = lineU + clamp(f, -0.1, 1.05) * (frontU - lineU);
        // オフサイドの線より前に出ない（走り出しは頭が決める）
        u = Math.min(u, opLine - 0.8);
        x = W / 2 + (q.bx - W / 2) * (0.9 + width * 0.55) + (bx - W / 2) * 0.12;
        const duty = q.s.duty;
        if (duty === 'att') u += 3;
        else if (duty === 'def') u -= 4;
      } else {
        const press = tac.press == null ? 0.5 : tac.press;
        const lineMax = 24 + (tac.line == null ? 0.5 : tac.line) * 24; // 最終ラインのいちばん高い所
        const lineU = clamp(bu - 22 - (1 - press) * 6, bu < 18 ? 5 : 9, lineMax);
        const span = 24 + (1 - press) * 2 - (bu < 32 ? 6 : 0);
        u = lineU + clamp(f, 0, 1) * span;
        // ゴールに近いほど中へ絞る
        const nar = bu < 30 ? 0.55 : bu < 45 ? 0.65 : 0.74;
        x = W / 2 + (q.bx - W / 2) * nar + (bx - W / 2) * (bu < 30 ? 0.35 : 0.55);
        if (q.s.duty === 'att') u += 3;
      }
      return this.abs(q, clamp(x, 1.5, W - 1.5), clamp(u, 2, L - 2));
    }
    // ボールを持っていない子の頭（行き先を選ぶ）
    offBall(q, attSd) {
      const b = this.ball;
      const attacking = q.sd === attSd;
      const bx = this.flight ? this.flight.tx : b.x;
      const by = this.flight ? this.flight.ty : b.y;
      this.offLineU = this._olT === this.tick && this._olSd === q.sd ? this._olV : (this._olV = this.offLine(q.sd));
      this._olT = this.tick;
      this._olSd = q.sd;
      let [tx, ty] = this.shapeTarget(q, attacking, bx, by);
      q.urg = 0.6 + q.a.wr * 0.25;
      if (attacking && !q.gk && b.owner && b.owner !== q && hyp(q.x - b.x, q.y - b.y) < 45) {
        // 空いた所・パスの線が通る所・前（オフザボール・視野）を、立ち位置のまわりで探す
        let best = null;
        let bestV = -1e9;
        const own = b.owner;
        const opLine = this.offLineU;
        const dB = hyp(q.x - own.x, q.y - own.y);
        const R = 7 + q.a.off * 5;
        for (let k = 0; k < 9; k++) {
          const ang = (k / 8) * Math.PI * 2;
          const rr = k === 8 ? 0 : R;
          let cx = clamp(tx + Math.cos(ang) * rr, 1, W - 1);
          let cy = clamp(ty + Math.sin(ang) * rr, 1, L - 1);
          const cu = this.uOf(q, cy);
          let v = 0;
          // 空き：いちばん近い相手との距離
          let near = 99;
          for (const o of this.P) if (o.sd !== q.sd) near = Math.min(near, hyp(o.x - cx, o.y - cy));
          v += Math.min(near, 10) * (0.5 + q.a.off * 0.6);
          // パスの線（持っている子から）に相手がいない
          let lane = 99;
          for (const o of this.P) if (o.sd !== q.sd) lane = Math.min(lane, segD(o.x, o.y, own.x, own.y, cx, cy));
          v += Math.min(lane, 5) * (0.6 + q.a.vis * 0.4) * 0.8;
          // 前へ（テンポ・任務）
          const tempo = (q.team.tactic && q.team.tactic.tempo) || 0.5;
          v += (cu - this.uOf(q, ty)) * (0.25 + tempo * 0.35 + (q.s.duty === 'att' ? 0.25 : 0) + (this.has(q, '裏への抜け出し') ? 0.3 : 0));
          // 持っている子から遠すぎない・近すぎない
          const dd = hyp(cx - own.x, cy - own.y);
          if (dd < 7) v -= (7 - dd) * 1.2;
          if (dd > 38) v -= (dd - 38) * 0.6;
          // オフサイド
          if (cu > opLine - 0.5) v -= 30;
          // 味方と重ならない
          for (const r of this.P) if (r.sd === q.sd && r !== q && r !== own && hyp(r.x - cx, r.y - cy) < 6) v -= (6 - hyp(r.x - cx, r.y - cy)) * (0.8 + q.a.tw * 0.4);
          // 判断の低い子は外れを選ぶ
          v += (this.rng() - 0.5) * (1 - q.a.dec) * 8;
          if (v > bestV) {
            bestV = v;
            best = [cx, cy];
          }
        }
        // 裏へ抜ける：最前線の子は、持っている子が前を向いたら線の裏へ走る（走り出しはオフサイドの線の手前から）
        const qu = this.uOf(q, q.y);
        if (q.bu > 60 && Math.abs(qu - opLine) < 4 && dB < 40 && this.uOf(q, own.y) > 35 && this.rng() < 0.25 + q.a.off * 0.35 + (this.has(q, '裏への抜け出し') ? 0.2 : 0)) {
          const [rx, ry] = this.abs(q, clamp(this.xOf(q, q.x) + (this.rng() - 0.5) * 8, 4, W - 4), Math.min(opLine + 14, 100));
          best = [rx, ry];
          q.run = this.t + 2.2;
          q.urg = 1;
        }
        if (best) {
          tx = best[0];
          ty = best[1];
        }
      } else if (!attacking && !q.gk) {
        // マーク：立ち位置の近く（12m）にいる相手を、ゴール側から捕まえる。ボールに近い相手ほど強く
        let tgt = null;
        let td = 1e9;
        for (const o of this.P) {
          if (o.sd === q.sd || o.gk) continue;
          const d = hyp(o.x - tx, o.y - ty);
          const db = hyp(o.x - bx, o.y - by);
          if (d < 13 && db < 30 && d < td && !(o.marked && o.marked !== q && o.markT === this.tick)) {
            td = d;
            tgt = o;
          }
        }
        if (tgt) {
          const [gx, gy] = q.dir > 0 ? [W / 2, 0] : [W / 2, L];
          const dg = hyp(gx - tgt.x, gy - tgt.y) || 1;
          const mx = tgt.x + ((gx - tgt.x) / dg) * 1.6;
          const my = tgt.y + ((gy - tgt.y) / dg) * 1.6;
          tgt.marked = q;
          tgt.markT = this.tick;
          const nearGoal = this.uOf(q, by) < 30;
          const w = clamp(0.35 + q.a.mrk * 0.45 - hyp(tgt.x - bx, tgt.y - by) / 60 + (nearGoal ? 0.3 : 0), 0.15, 0.92);
          tx = tx + (mx - tx) * w;
          ty = ty + (my - ty) * w;
        }
        // 最終ラインの裏へ抜けた相手は、後ろの子がゴール側から追う（集中・ポジショニング）
        q.urg = 0.62 + q.a.wr * 0.2;
        if (q.bu < 40) {
          const myU = this.uOf(q, q.y);
          let run = null;
          let rd = 1e9;
          for (const o of this.P) {
            if (o.sd === q.sd || o.gk) continue;
            const ou = this.uOf(q, o.y);
            const d = hyp(o.x - q.x, o.y - q.y);
            if (ou < myU + 1.5 && ou < 40 && d < 16 && d < rd && !(o.trk && o.trk !== q && o.trkT > this.t - 0.6)) {
              rd = d;
              run = o;
            }
          }
          if (run && this.rng() < 0.6 + q.a.con * 0.25 + q.a.pos * 0.15) {
            run.trk = q;
            run.trkT = this.t;
            const [gx, gy] = q.dir > 0 ? [W / 2, 0] : [W / 2, L];
            const dg = hyp(gx - run.x, gy - run.y) || 1;
            tx = run.x + ((gx - run.x) / dg) * 1.4 + run.vx * 0.3;
            ty = run.y + ((gy - run.y) / dg) * 1.4 + run.vy * 0.3;
            q.urg = 1;
          }
        }
      }
      if (q.gk && !attacking) q.urg = 0.75 + q.a.pos * 0.25;
      // 持ち場が遠いと急ぐ
      const far = hyp(tx - q.x, ty - q.y);
      if (far > 12) q.urg = Math.max(q.urg, 0.85);
      q.tx = tx;
      q.ty = ty;
    }
    // 走る向きと速さを決める（寄せ役・球を追う子は上書き）
    steer(q, attSd) {
      const b = this.ball;
      if (q.press && q.sd !== attSd && b.owner) {
        // 寄せる：持っている子とゴールの間へ。1人目は詰める、2人目は少し後ろ
        const o = b.owner;
        const [gx, gy] = q.dir > 0 ? [W / 2, 0] : [W / 2, L];
        const dg = hyp(gx - o.x, gy - o.y) || 1;
        const gap = q.press === 1 ? 1.9 + (1 - ((q.team.tactic && q.team.tactic.press) || 0.5)) * 1.8 - Math.min(o.hold || 0, 2) * 0.3 : 6;
        q.tx = o.x + ((gx - o.x) / dg) * gap;
        q.ty = o.y + ((gy - o.y) / dg) * gap;
        q.urg = q.press === 1 ? 0.95 : 0.75;
      }
      if (this.flight && this.flight.chasers && this.flight.chasers.indexOf(q) >= 0) {
        q.tx = this.flight.mx;
        q.ty = this.flight.my;
        q.urg = 1;
        if (q === this.flight.to) {
          q.tx = this.flight.tx;
          q.ty = this.flight.ty;
        }
      }
    }
    moveAll() {
      for (const q of this.P) {
        let tx = q.tx;
        let ty = q.ty;
        if (q === this.ball.owner && this.state === 'play') {
          tx = q.dx != null ? q.dx : q.x;
          ty = q.dy != null ? q.dy : q.y;
        }
        const dx = tx - q.x;
        const dy = ty - q.y;
        const d = hyp(dx, dy);
        let vmax = q.vmax * (q.urg || 0.6);
        if (q === this.ball.owner) {
          vmax = q.vmax * (0.68 + q.a.dri * 0.2) * (q.carry || 0.7);
          // 前に相手が立っていると進めない（体で止められる）
          if (d > 0.3) for (const o of this.P) {
            if (o.sd === q.sd || o.stun > 0) continue;
            const ox = o.x - q.x;
            const oy = o.y - q.y;
            const od = hyp(ox, oy);
            if (od < 1.6 && (ox * dx + oy * dy) / (od * d) > 0.5) { vmax *= 0.35; q.blocked = (q.blocked || 0) + DT; break; }
          }
        }
        if (q.stun > 0) vmax *= 0.3;
        // 着く前に減速
        const want = Math.min(vmax, Math.sqrt(2 * q.amax * Math.max(0, d - 0.2)) + 0.05);
        let wx = d > 0.05 ? (dx / d) * want : 0;
        let wy = d > 0.05 ? (dy / d) * want : 0;
        // 近すぎる子から離れる
        for (const r of this.P) {
          if (r === q) continue;
          const ex = q.x - r.x;
          const ey = q.y - r.y;
          if (ex > 1.3 || ex < -1.3 || ey > 1.3 || ey < -1.3) continue;
          const e = ex * ex + ey * ey;
          if (e < 1.6 && e > 1e-4) {
            const k = (1.27 - Math.sqrt(e)) * 2.5;
            wx += (ex / Math.sqrt(e)) * k;
            wy += (ey / Math.sqrt(e)) * k;
          }
        }
        let ax = (wx - q.vx) / DT;
        let ay = (wy - q.vy) / DT;
        const am = hyp(ax, ay);
        if (am > q.amax) {
          ax *= q.amax / am;
          ay *= q.amax / am;
        }
        q.vx += ax * DT;
        q.vy += ay * DT;
        q.x = clamp(q.x + q.vx * DT, -3, W + 3);
        q.y = clamp(q.y + q.vy * DT, -3, L + 3);
      }
    }

    // ---------- 持っている子 ----------
    ownerAct(q) {
      const b = this.ball;
      q.hold = (q.hold || 0) + DT;
      // 一番近い相手
      let nd = 99;
      let no = null;
      for (const o of this.P) if (o.sd !== q.sd) {
        const d = hyp(o.x - q.x, o.y - q.y);
        if (d < nd) {
          nd = d;
          no = o;
        }
      }
      q.nd = nd;
      // タックル：寄せた相手がすぐ近くにいる
      if (no && nd < 1.5 && no.cool <= 0 && no.stun <= 0 && !no.gk && this.state === 'play') {
        no.cool = 0.6;
        // 飛び込むか、間合いを取って待つか（タックル・判断。自陣の箱の中は慎重に）
        const box = this.inOwnBox(no);
        const go = (0.3 + no.a.tck * 0.25 + no.a.dec * 0.1 + ((no.team.tactic && no.team.tactic.intensity) || 0.5) * 0.1) * (box ? 0.6 : 1) * (q.hold > 1.2 ? 1.4 : 1);
        if (this.rng() < go && this.tackle(no, q)) return;
      }
      // GK が自分の箱の中で足元に飛び込む（1対1・飛び出し）
      if (no && no.gk && nd < 2.0 && no.cool <= 0 && this.inOwnBox(no) && this.state === 'play') {
        no.cool = 0.8;
        const pg = clamp(0.3 + no.a.ovo * 0.35 + no.a.rush * 0.1 - q.a.dri * 0.22 - q.a.cmp * 0.08, 0.1, 0.7);
        if (this.rng() < pg) {
          if (this.has(no, '1対1の間合い')) this.useTr(no, '1対1の間合い');
          this.ev('save', { pid: no.id, sd: no.sd, vs: q.id, catch: true, smother: true });
          b.owner = no;
          b.last = no;
          b.lastTeam = no.sd;
          no.hold = 0;
          q.stun = 0.5;
          return;
        }
        no.stun = 0.6;
      }
      // GK がエリアの中で持ったら、少し持ってから配る
      if (q.gk) {
        q.dx = q.x;
        q.dy = q.y;
        if (q.hold < 1.6 + this.rng() * 1.2) return;
        return this.distribute(q);
      }
      q.think -= DT;
      if (q.think > 0 && !(nd < 1.6 && q.hold > 0.5)) {
        this.carryOn(q);
        return;
      }
      q.think = 0.35 + (1 - q.a.dec) * 0.35 + this.rng() * 0.35;
      this.decide(q, nd);
    }
    carryOn(q) {
      // 決めた向きへ運ぶ（ラインの内側）
      if (q.dx == null) {
        q.dx = q.x;
        q.dy = q.y;
      }
      q.dx = clamp(q.dx, 1.2, W - 1.2);
      q.dy = clamp(q.dy, 1.2, L - 1.2);
    }
    // 攻める側から見た、その場所の危なさ（得点に近いほど高い）
    threat(sd, x, y) {
      const u = this.uOfSide(sd, y);
      const d = hyp(x - W / 2, L - u);
      const ang = Math.abs(Math.atan2(x - W / 2, Math.max(L - u, 0.5)));
      return 0.5 * Math.exp(-d / 10) * (1 - ang * 0.35) + 0.11 * (u / L) * (u / L) + 0.012;
    }
    // シュートの決まりやすさ（xG のような数）
    xg(q, x, y, opt) {
      const u = this.uOfSide(q.sd, y);
      const du = L - u;
      const dx = x - W / 2;
      const d = hyp(dx, du);
      const ang = Math.atan2(GW * 2 * du, du * du + dx * dx - GW * GW); // ゴールの見える角度
      let v = clamp(ang, 0, 1.6) * 0.42 * Math.exp(-d / 26);
      if (opt && opt.head) v *= 0.55;
      // 前に相手がいる・GK が前に出ている
      let block = 0;
      const gx = W / 2;
      const gy = q.dir > 0 ? L : 0;
      for (const o of this.P) if (o.sd !== q.sd) {
        const sd = segD(o.x, o.y, x, y, gx, gy);
        const tt = segT;
        if (o.gk) {
          // GK が近くで角度を消している
          const dg = hyp(o.x - x, o.y - y);
          if (dg < 9) block += clamp((9 - dg) / 9, 0, 1) * clamp(1.6 - sd, 0, 1) * 0.55;
        } else if (sd < 1.2 && tt > 0.02) block += 0.3;
      }
      const sk = opt && opt.head ? q.a.hea : d > 20 ? q.a.lsh : q.a.fin;
      return clamp(v * (0.6 + sk * 0.8) * (1 - Math.min(block, 0.75)), 0, 0.8);
    }
    decide(q, nd) {
      const b = this.ball;
      const sd = q.sd;
      const tac = q.team.tactic || {};
      const tempo = tac.tempo == null ? 0.5 : tac.tempo;
      const here = this.threat(sd, q.x, q.y);
      const opts = [];
      // 1. シュート
      const u = this.uOfSide(sd, q.y);
      if (L - u < 34) {
        const xg = this.xg(q, q.x, q.y);
        const press = nd < 2 ? 0.75 : 1;
        // 打つ気（ためらい）：冷静さ・フィニッシュ
        if (xg > 0.058 - q.a.lsh * 0.03 - (nd > 3 ? 0.008 : 0) || (xg > 0.025 && this.has(q, '弾丸ミドル'))) opts.push({ k: 'shoot', v: xg * press * (0.9 + q.a.fin * 0.1) + (L - u < 9 ? 0.02 : 0) });
      }
      // 2. パス
      const lanes = this.passOptions(q);
      for (const o of lanes) opts.push(o);
      // 3. クロス（相手の箱の横から）
      const xside = Math.abs(q.x - W / 2);
      if (L - u < 30 && xside > 16) {
        const hs = this.P.filter((r) => r.sd === sd && !r.gk && L - this.uOfSide(sd, r.y) < 20 && Math.abs(r.x - W / 2) < 12).length;
        if (hs) opts.push({ k: 'cross', v: 0.03 + hs * 0.018 + q.a.crs * 0.03 + (tac.width || 0.5) * 0.015 });
      }
      // 4. 運ぶ：前・斜め・横
      const dirs = [[0, 1], [0.6, 0.8], [-0.6, 0.8], [1, 0], [-1, 0], [0.7, -0.7], [-0.7, -0.7]];
      for (const [ex, eu] of dirs) {
        const step = 6;
        const nx = clamp(q.x + ex * step * (q.dir > 0 ? 1 : -1), 1.5, W - 1.5);
        const ny = clamp(q.y + eu * step * q.dir, 1.5, L - 1.5);
        let oppNear = 99;
        for (const o of this.P) if (o.sd !== sd) oppNear = Math.min(oppNear, segD(o.x, o.y, q.x, q.y, nx, ny) + 0.0);
        const ps = clamp(-0.12 + oppNear * 0.2 + q.a.dri * 0.25 + q.a.agi * 0.08 + (this.has(q, '縦への突破') && eu > 0.5 ? 0.06 : 0), 0.02, 0.97);
        const gain = this.threat(sd, nx, ny);
        opts.push({ k: 'carry', x: nx, y: ny, v: ps * gain - (1 - ps) * this.threat(sd === 'home' ? 'away' : 'home', q.x, q.y) * 0.8 + (eu > 0.5 ? 0.002 : 0), ps });
      }
      // 5. 持つ（相手が遠いときだけ。テンポが遅いほど）
      if (nd > 5) opts.push({ k: 'hold', v: here * 0.95 + (1 - tempo) * 0.004 });
      // 選ぶ：判断の良い子ほど一番良いものを選ぶ
      const temp = 0.004 + (1 - q.a.dec) * 0.012;
      let best = opts[0];
      let bestS = -1e9;
      for (const o of opts) {
        const s = o.v + -Math.log(-Math.log(this.rng() * 0.999 + 0.0005)) * temp;
        if (s > bestS) {
          bestS = s;
          best = o;
        }
      }
      if (!best) return;
      if (best.k === 'shoot') return this.shoot(q, {});
      if (best.k === 'pass') return this.pass(q, best.q, { lead: best.lead, loft: best.loft, through: best.through });
      if (best.k === 'cross') return this.cross(q, false);
      if (best.k === 'carry') {
        q.dx = best.x;
        q.dy = best.y;
        q.carry = 0.8 + tempo * 0.2;
        return;
      }
      q.dx = q.x;
      q.dy = q.y;
      q.carry = 0.4;
    }
    // パスの候補（受け手ごと）：通る見込み × 受けた所の危なさ − 失ったときの痛さ
    passOptions(q) {
      const out = [];
      const sd = q.sd;
      const here = this.threat(sd, q.x, q.y);
      const tac = q.team.tactic || {};
      const tempo = tac.tempo == null ? 0.5 : tac.tempo;
      const opLine = this.offLine(sd);
      const range = 22 + q.a.vis * 22 + q.a.pas * 8;
      for (const r of this.P) {
        if (r.sd !== sd || r === q || r.stun > 0) continue;
        const d0 = hyp(r.x - q.x, r.y - q.y);
        if (d0 < 3 || d0 > range + 10) continue;
        // 受け手の動きを先取り（走っている子の前へ）
        const T = d0 / 15;
        let lx = clamp(r.x + r.vx * T * 0.8, 1, W - 1);
        let ly = clamp(r.y + r.vy * T * 0.8, 1, L - 1);
        // GK へは足元へ。自分のゴールの近く（7m）へ転がすパスは出さない
        if (r.gk) {
          lx = r.x;
          ly = r.y;
          if (Math.abs(r.x - W / 2) < 5 && this.uOfSide(sd, r.y) < 3) continue;
        } else if (this.uOfSide(sd, ly) < 7 && Math.abs(lx - W / 2) < 12) continue;
        const ru = this.uOfSide(sd, ly);
        // オフサイドの位置の子へは出さない（見落とすこともある）
        if (this.uOfSide(sd, r.y) > opLine + 0.3 && this.rng() > (1 - q.a.dec) * 0.2) continue;
        const d = hyp(lx - q.x, ly - q.y);
        // 通り道の相手（切られる見込み）：球がその点に着く時間と、相手がそこへ届く時間を比べる
        const vAvg = 11 + q.a.pas * 3;
        let keep = 1;
        for (const o of this.P) {
          if (o.sd === sd) continue;
          const sdist = segD(o.x, o.y, q.x, q.y, lx, ly);
          const tt = segT;
          const ballT = (tt * d) / vAvg;
          const oppT = Math.max(0, sdist - 0.9) / (o.vmax * 0.9) + 0.32 - o.a.ant * 0.18;
          let r = clamp((ballT - oppT) * 1.6 + 0.35, 0, 0.95);
          if (tt > 0.97) r *= 0.75; // 受け手の所は受け手と競る
          keep *= 1 - r * (0.75 - q.a.pas * 0.2);
        }
        const risk = 1 - keep;
        const errP = clamp(0.03 + (1 - q.a.pas) * 0.05 + d * (0.0028 - q.a.pas * 0.0016) + (q.nd < 2 ? 0.05 : 0), 0.01, 0.4);
        let ps = clamp((1 - risk) * (1 - errP), 0.02, 0.98);
        // 浮かせる（通り道に相手がいて、遠い）
        let loft = false;
        if (risk > 0.5 && d > 18) {
          // 球が落ちるまで（約1.5〜2秒）に相手が寄れる分を引いた空き
          const Tf = d / clamp(10 + d * 0.38, 12, 26);
          let near = 99;
          for (const o of this.P) if (o.sd !== sd) near = Math.min(near, hyp(o.x - lx, o.y - ly) - o.vmax * Tf * 0.7);
          const pl = clamp(0.25 + q.a.pas * 0.2 + clamp(near, -4, 6) * 0.06 - d * 0.004 + r.a.ft * 0.05, 0.03, 0.8);
          if (pl > ps + 0.12) {
            ps = pl;
            loft = true;
          }
        }
        const gain = this.threat(sd, lx, ly) * (0.85 + r.a.ft * 0.15);
        const fwd = ru - this.uOfSide(sd, q.y);
        const lose = this.threat(sd === 'home' ? 'away' : 'home', lx, ly);
        const v = ps * gain - (1 - ps) * lose * 0.8 + fwd * tempo * 0.0003 + (d < 25 ? (1 - tempo) * 0.003 : 0);
        out.push({ k: 'pass', q: r, lead: [lx, ly], loft, v, ps, through: fwd > 12 });
      }
      return out;
    }
    bestPass(q, o) {
      const ps = this.passOptions(q).filter((x) => !o.maxD || hyp(x.lead[0] - q.x, x.lead[1] - q.y) < o.maxD);
      ps.sort((a, b) => b.ps * 2 + b.v - (a.ps * 2 + a.v));
      return ps[0] || null;
    }
    distribute(q) {
      const tac = q.team.tactic || {};
      const opts = this.passOptions(q);
      const safe = opts.filter((o) => o.ps > 0.8 && hyp(o.lead[0] - q.x, o.lead[1] - q.y) < 35);
      if (safe.length && this.rng() < 0.4 + (1 - (tac.tempo || 0.5)) * 0.4 + q.a.dist * 0.15) {
        safe.sort((a, b) => b.v - a.v);
        return this.pass(q, safe[0].q, { lead: safe[0].lead });
      }
      // 前へ蹴る
      const fw = this.P.filter((r) => r.sd === q.sd && !r.gk).sort((a, b) => this.uOf(b, b.y) - this.uOf(a, a.y)).slice(0, 4);
      const r = fw[Math.floor(this.rng() * fw.length)];
      if (r) return this.pass(q, r, { lead: [r.x, r.y], loft: true, long: true });
    }
    // ---------- 蹴る ----------
    kick(q, tx, ty, opt) {
      const b = this.ball;
      opt = opt || {};
      const dx = tx - b.x;
      const dy = ty - b.y;
      const d = hyp(dx, dy) || 0.1;
      let ang = Math.atan2(dy, dx);
      const err = opt.err || 0;
      ang += (this.rng() + this.rng() + this.rng() - 1.5) * err * 1.15;
      let dd = d * (1 + (this.rng() - 0.5) * err * 0.8);
      b.owner = null;
      b.last = q;
      b.lastTeam = q.sd;
      q.cool = 0.35;
      q.dx = q.dy = null;
      if (opt.loft) {
        const vh = opt.vh || clamp(10 + dd * 0.38, 12, 26);
        const T = dd / vh;
        b.vx = Math.cos(ang) * vh;
        b.vy = Math.sin(ang) * vh;
        b.vz = (G * T) / 2;
        b.z = 0.1;
      } else {
        const vEnd = opt.vEnd == null ? 6 : opt.vEnd;
        const v0 = opt.v || Math.min(Math.sqrt(vEnd * vEnd + 2 * FRIC * dd), 28);
        b.vx = Math.cos(ang) * v0;
        b.vy = Math.sin(ang) * v0;
        b.vz = opt.vz || 0;
        b.z = opt.vz ? 0.05 : 0;
      }
      this.lock = { q, until: this.t + 0.25 };
      this.ev('kick', { pid: q.id, sd: q.sd, kind: opt.kind || 'pass', x: b.x, y: b.y, tx, ty, loft: !!opt.loft });
    }
    pass(q, r, o) {
      o = o || {};
      const [lx, ly] = o.lead || [r.x, r.y];
      const d = hyp(lx - q.x, ly - q.y);
      const press = q.nd != null && q.nd < 2 ? 0.05 : 0;
      // 自陣の深い所では丁寧に蹴る
      const careful = this.uOf(q, q.y) < 30 ? 0.55 : 1;
      const err = ((o.throwIn ? 0.04 : 0.012) + (1 - q.a.pas) * 0.06 + press + d * 0.0006 * (1.2 - q.a.pas) + (o.long ? 0.05 : 0)) * careful;
      this.passes[q.sd]++;
      this.flight = { from: q, to: r, tx: lx, ty: ly, t0: this.t, sd: q.sd, kind: o.throwIn ? 'throw' : 'pass', offside: this.uOfSide(q.sd, r.y) > this.offLine(q.sd) + 0.2 && !o.throwIn, chasers: [r], tried: new Set() };
      this.setPiece = o.throwIn ? this.setPiece : null;
      if (o.loft || o.throwIn) this.kick(q, lx, ly, { loft: true, err, vh: o.throwIn ? 11 : null, kind: o.throwIn ? 'throw' : o.long ? 'long' : 'loft' });
      else this.kick(q, lx, ly, { err: r.gk ? err * 0.5 : err, vEnd: r.gk ? 5 : 8 + q.a.pas * 4, kind: o.through ? 'through' : 'pass' });
      this.flight.mx = lx;
      this.flight.my = ly;
      this.assist = { pid: q.id, sd: q.sd, t: this.t };
    }
    cross(q, setPiece) {
      // 箱の中の味方（いちばん競り勝てそうな所）へ浮き球
      const sd = q.sd;
      const box = this.P.filter((r) => r.sd === sd && !r.gk && L - this.uOfSide(sd, r.y) < 22 && Math.abs(r.x - W / 2) < 14);
      let tgt = null;
      let tv = -1;
      for (const r of box) {
        let near = 99;
        for (const o of this.P) if (o.sd !== sd) near = Math.min(near, hyp(o.x - r.x, o.y - r.y));
        const v = r.a.hea * 0.6 + r.a.jmp * 0.3 + Math.min(near, 4) * 0.2 + this.rng() * 0.3;
        if (v > tv) {
          tv = v;
          tgt = r;
        }
      }
      const gy = q.dir > 0 ? L : 0;
      const [tx, ty] = tgt ? [tgt.x, tgt.y] : [W / 2 + (this.rng() - 0.5) * 10, gy - q.dir * (7 + this.rng() * 6)];
      const err = 0.04 + (1 - (setPiece ? q.a.set : q.a.crs)) * 0.1;
      this.passes[sd]++;
      this.flight = { from: q, to: tgt, tx, ty, t0: this.t, sd, kind: 'cross', chasers: tgt ? [tgt] : [], tried: new Set() };
      this.kick(q, tx, ty, { loft: true, err, vh: 17 + q.a.crs * 4, kind: 'cross' });
      this.flight.mx = tx;
      this.flight.my = ty;
      this.assist = { pid: q.id, sd, t: this.t };
      if (this.has(q, setPiece ? '曲がるCK' : 'アーリークロス')) this.useTr(q, setPiece ? '曲がるCK' : 'アーリークロス');
    }
    shoot(q, o) {
      o = o || {};
      const b = this.ball;
      const sd = q.sd;
      const gy = q.dir > 0 ? L + 0.5 : -0.5;
      const gk = this.gkOf(sd === 'home' ? 'away' : 'home');
      const u = this.uOfSide(sd, b.y);
      const d = hyp(b.x - W / 2, L - u);
      const head = b.z > 1.0;
      // 狙う所：GK のいない側の隅
      const side = gk ? (gk.x < W / 2 ? 1 : -1) : this.rng() < 0.5 ? 1 : -1;
      const aimX = W / 2 + side * (GW - 0.35 - this.rng() * 0.9);
      const sk = o.pk ? q.a.pk : o.fk ? q.a.set : head ? q.a.hea : d > 20 ? q.a.lsh : q.a.fin;
      const press = q.nd != null && q.nd < 1.8 ? 0.03 : 0;
      const err = clamp((o.pk ? 0.03 : 0.055) + (1 - sk) * 0.08 + press * 1.5 + (1 - q.a.cmp) * 0.03 + (head ? 0.06 : 0), 0.02, 0.25) * (o.pk ? 0.8 : 1);
      const v = o.pk ? 24 : head ? 13 + q.a.str * 3 : 22 + q.a.str * 4 + (d > 20 ? q.a.lsh * 4 : 0);
      const xgv = o.pk ? 0.76 : this.xg(q, b.x, b.y, { head });
      this.shotN = (this.shotN || 0) + 1;
      const assist = this.assist && this.assist.sd === sd && this.assist.pid !== q.id && this.t - this.assist.t < 8 ? this.assist.pid : null;
      this.shot = { q, sd, t0: this.t, xg: xgv, head, pk: !!o.pk, fk: !!o.fk, assist, gk: gk || null, decided: false, from: [b.x, b.y] };
      this.flight = null;
      // 高さ：低めが基本、下手ほど浮く
      const lift = o.pk ? 0.3 + this.rng() * 1.3 : head ? 0.2 + this.rng() * 1.2 : this.rng() * 1.5 + (1 - sk) * this.rng() * 3.6 + (press ? this.rng() * 1.5 : 0) + (d > 18 ? this.rng() * 1.2 : 0);
      const T = hyp(aimX - b.x, gy - b.y) / v;
      this.kick(q, aimX, gy, { v, err: err * (o.pk ? 2 : 4.2), vz: (lift + 0.5 * G * T * T) / Math.max(T, 0.15), kind: 'shot' });
      const se = this.ev('shot', { pid: q.id, sd, xg: xgv, x: b.x, y: b.y, head, pk: !!o.pk, fk: !!o.fk, assist });
      this.decideSave();
      const ss = this.shot;
      if (ss) { se.onT = !!ss.onT; se.save = !!ss.save; se.need = ss.need; se.reach = ss.reach; se.pSave = ss.pSave; se.meet = ss.meet; se.gkx = ss.gk ? ss.gk.x : null; se.cross = ss.cross; }
    }
    // シュートが枠に向かうなら、GK が届くかを決めておく（届く子は飛ぶ）
    decideSave() {
      const s = this.shot;
      const b = this.ball;
      if (!s || !s.gk) return;
      const gk = s.gk;
      const gy = s.q.dir > 0 ? L : 0;
      const T = (gy - b.y) / (b.vy || 1e-6);
      if (T <= 0) return;
      const cx = b.x + b.vx * T;
      // 高さ（ざっくり：空気の抵抗は無視）
      const cz = b.z + b.vz * T - 0.5 * G * T * T;
      s.cross = [cx, cz, T];
      s.onT = Math.abs(cx - W / 2) < GW && cz < GH && cz > -0.3;
      if (!s.onT) return;
      // GK の飛べる距離：反応・1対1・敏しょう性
      const react = 0.26 - gk.a.ref * 0.12;
      const reach = 1.0 + clamp(T - react, 0, 1.2) * (4.2 + gk.a.agi * 1.8 + gk.a.ref * 1.6);
      const gkLineX = gk.x; // GK のいる横の位置
      // GK が前に出ていれば角度が狭い（ボールの通り道で止める）
      const tMeet = clamp((this.uOfSide(s.sd, gk.y) - this.uOfSide(s.sd, b.y)) / (Math.abs(b.vy) || 1), 0, T);
      const mx = b.x + b.vx * tMeet;
      const need = Math.abs(mx - gkLineX) + Math.max(0, cz - 1.9) * 0.8;
      let pSave = need < 1.0 ? 0.97 : need < reach ? 0.96 - Math.pow(need / reach, 2.2) * 0.45 : 0.06;
      pSave *= 0.85 + gk.a.han * 0.1 + gk.a.ref * 0.1;
      if (s.pk) pSave = clamp(0.18 + gk.a.ref * 0.12 - s.q.a.pk * 0.08, 0.08, 0.32);
      if (this.has(gk, 'シュートへの反応')) pSave += 0.04;
      s.save = this.rng() < clamp(pSave, 0, 0.95);
      s.need = need;
      s.reach = reach;
      s.pSave = pSave;
      s.meet = [mx, this.uOfSide(s.sd, b.y) + Math.abs(b.vy) * tMeet, tMeet];
      s.catchIt = s.save && this.rng() < 0.25 + gk.a.han * 0.45 - Math.max(0, hyp(b.vx, b.vy) - 22) * 0.03;
    }
    // 球が誰のものでもないとき：各チームで一番早く着く子が追う
    loose() {
      const b = this.ball;
      const bs = hyp(b.vx, b.vy);
      for (const sd of ['home', 'away']) {
        let best = null;
        let bt = 1e9;
        for (const q of this.P) {
          if (q.sd !== sd) continue;
          // 球の行き先（転がって止まる所までを何点か）で、早く着ける所
          const t = this.reachTime(q);
          if (t < bt) {
            bt = t;
            best = q;
          }
        }
        if (best && !(this.flight && this.flight.to === best && this.flight.kind !== 'shot')) {
          const T = Math.min(bt, 2.5);
          const [px, py] = this.ballAt(T);
          best.tx = px;
          best.ty = py;
          best.urg = 1;
        }
      }
      void bs;
    }
    // その子が球に届くまでの時間（だいたい）
    reachTime(q) {
      let best = 9;
      for (let T = 0; T <= 2.4; T += 0.3) {
        const [px, py, pz] = this.ballAt(T);
        if (pz > 2.2) continue;
        const d = hyp(px - q.x, py - q.y) - 1;
        const t = Math.max(0, d) / q.vmax + 0.15;
        if (t <= T + 0.05) return T;
        best = Math.min(best, t + 0.3);
      }
      return best;
    }
    ballAt(T) {
      const b = this.ball;
      const v = hyp(b.vx, b.vy);
      if (b.z > 0.05 || b.vz > 0) {
        // 浮いている：落ちるまでは真っすぐ
        const x = b.x + b.vx * T;
        const y = b.y + b.vy * T;
        const z = Math.max(0, b.z + b.vz * T - 0.5 * G * T * T);
        return [clamp(x, 0, W), clamp(y, 0, L), z];
      }
      if (v < 0.05) return [b.x, b.y, 0];
      const tStop = v / FRIC;
      const tt = Math.min(T, tStop);
      const s = v * tt - 0.5 * FRIC * tt * tt;
      return [clamp(b.x + (b.vx / v) * s, 0, W), clamp(b.y + (b.vy / v) * s, 0, L), 0];
    }
    // タックル（d＝守り手、q＝持っている子）。奪えたら true
    tackle(d, q) {
      let p = 0.42 + d.a.tck * 0.4 - q.a.dri * 0.26 - q.a.bal * 0.08 - q.a.str * 0.05 + d.a.str * 0.05;
      if (this.has(d, 'ボール奪取')) { p += 0.06; this.useTr(d, 'ボール奪取'); }
      if (this.has(q, '粘り腰のキープ')) { p -= 0.05; this.useTr(q, '粘り腰のキープ'); }
      p = clamp(p, 0.12, 0.82);
      const b = this.ball;
      if (this.rng() < p) {
        // 突いて転がす（近い所に）
        b.owner = null;
        const a = Math.atan2(d.y - q.y, d.x - q.x) + (this.rng() - 0.5) * 2;
        const v = 2 + this.rng() * 4;
        b.vx = Math.cos(a) * v;
        b.vy = Math.sin(a) * v;
        b.last = d;
        b.lastTeam = d.sd;
        q.stun = 0.4;
        q.cool = 0.4;
        this.lock = { q, until: this.t + 0.35 };
        this.ev('tackle', { pid: d.id, sd: d.sd, vs: q.id, ok: true });
        return true;
      }
      // ファウル（下手なほど・後ろから）
      const foulP = clamp(0.1 + (1 - d.a.tck) * 0.14 + ((d.team.tactic && d.team.tactic.intensity) || 0.5) * 0.06 - d.a.con * 0.05, 0.04, 0.3) * (this.inOwnBox(d) ? 0.35 : 1);
      if (this.rng() < foulP) {
        const inBox = L - this.uOfSide(q.sd, q.y) < 16.5 && Math.abs(q.x - W / 2) < 20.16;
        this.ev('foul', { pid: d.id, sd: d.sd, vs: q.id, x: q.x, y: q.y, pk: inBox });
        if (inBox) this.setDead('pk', q.sd, W / 2, q.dir > 0 ? L - 11 : 11, 3.5, { foul: d.id });
        else this.setDead('fk', q.sd, q.x, q.y, 1.5 + this.rng() * 2.5, { foul: d.id });
        return true;
      }
      d.stun = 0.3 + q.a.dri * 0.35;
      this.ev('tackle', { pid: d.id, sd: d.sd, vs: q.id, ok: false });
      return false;
    }

    // ---------- ボールの物理 ----------
    moveBall() {
      const b = this.ball;
      if (this.state === 'dead') return;
      if (b.owner) {
        const q = b.owner;
        const sp = hyp(q.vx, q.vy);
        const fx = sp > 0.3 ? q.vx / sp : q.dir > 0 ? 0 : 0;
        const fy = sp > 0.3 ? q.vy / sp : q.dir;
        b.x = q.x + fx * 0.55;
        b.y = q.y + fy * 0.55;
        b.z = 0;
        b.vx = q.vx;
        b.vy = q.vy;
        b.vz = 0;
        b.px = null;
        return;
      }
      // 動かす
      const px = b.x;
      const py = b.y;
      b.px = px;
      b.py = py;
      if (b.z > 0 || b.vz > 0) {
        b.vz -= G * DT;
        b.z += b.vz * DT;
        b.x += b.vx * DT;
        b.y += b.vy * DT;
        if (b.z <= 0) {
          b.z = 0;
          // 芝に落ちると勢いが死ぬ（浮き球は落ちた所の近くで止まる）
          if (b.vz < -2.5) b.vz = -b.vz * 0.3;
          else b.vz = 0;
          b.vx *= 0.5;
          b.vy *= 0.5;
        }
      } else {
        const v = hyp(b.vx, b.vy);
        if (v > 0) {
          const nv = Math.max(0, v - FRIC * DT);
          b.vx *= nv / v;
          b.vy *= nv / v;
        }
        b.x += b.vx * DT;
        b.y += b.vy * DT;
        // ほぼ止まった球は誰のものでもない（パスの受け手が触れなかった）
        if (nvSlow(b) && this.flight) this.flight = null;
      }
      // シュート：GK が止める所
      const s = this.shot;
      if (s && !s.decided && s.meet && s.onT) {
        const gk = s.gk;
        const T = this.t - s.t0;
        // GK は飛ぶ
        if (T > s.meet[2] - 0.35) {
          gk.tx = s.meet[0];
          gk.ty = gk.y;
          gk.urg = 1;
          gk.dive = this.t;
        }
        if (T >= s.meet[2] - 0.06) {
          s.decided = true;
          if (s.save) {
            this.ev('save', { pid: gk.id, sd: gk.sd, vs: s.q.id, catch: s.catchIt, xg: s.xg });
            if (s.catchIt) {
              b.owner = gk;
              b.last = gk;
              b.lastTeam = gk.sd;
              gk.hold = 0;
              this.shot = null;
              return;
            }
            // 弾く：横へ
            const a = (gk.dir > 0 ? 1 : -1) * (Math.PI / 2) + (this.rng() - 0.5) * 1.6 + (this.rng() < 0.5 ? 0 : Math.PI);
            const v = 5 + this.rng() * 6;
            b.vx = Math.cos(a) * v * (b.x < W / 2 ? -1 : 1);
            b.vy = Math.abs(Math.sin(a)) * v * gk.dir;
            b.vz = 1 + this.rng() * 2;
            b.last = gk;
            b.lastTeam = gk.sd;
            this.lock = { q: gk, until: this.t + 0.4 };
            this.shot = null;
          }
        }
      }
      // 外に出た・ゴール
      if (b.y < 0 || b.y > L) {
        const end = b.y < 0 ? 0 : L;
        // ゴールの線を越えた所の横の位置（この刻みで越えた）
        const k = (end - py) / ((b.y - py) || 1e-6);
        const cx = px + (b.x - px) * k;
        if (Math.abs(cx - W / 2) < GW && b.z < GH) return this.goal(end === L ? 'home' : 'away');
        const defSd = end === L ? 'away' : 'home';
        if (this.shot) this.ev('miss', { pid: this.shot.q.id, sd: this.shot.sd, xg: this.shot.xg });
        this.shot = null;
        if (b.lastTeam === defSd) this.setDead('corner', defSd === 'home' ? 'away' : 'home', cx < W / 2 ? 0 : W, end, 6 + this.rng() * 6);
        else this.setDead('goalkick', defSd, W / 2 + (cx < W / 2 ? -9 : 9), end === L ? L - 5.5 : 5.5, 6 + this.rng() * 6);
        return;
      }
      if (b.x < 0 || b.x > W) {
        const sd = b.lastTeam === 'home' ? 'away' : 'home';
        this.shot = null;
        this.setDead('throw', sd, b.x < 0 ? 0 : W, b.y, 3 + this.rng() * 4);
        return;
      }
      this.touch();
    }
    // 球に触れる（受ける・切る・拾う・頭で合わせる）
    touch() {
      const b = this.ball;
      const bs = hyp(b.vx, b.vy);
      if (b.z > 2.6) return;
      let best = null;
      let bd = 1e9;
      for (const q of this.P) {
        if (this.lock && this.lock.q === q && this.t < this.lock.until) continue;
        if (q.stun > 0.3) continue;
        const d = b.px != null ? segD(q.x, q.y, b.px, b.py, b.x, b.y) : hyp(q.x - b.x, q.y - b.y);
        const reach = q.gk && this.inOwnBox(q) ? 1.6 + q.a.han * 0.4 : 0.85 + q.a.agi * 0.3;
        if (d < reach && d < bd) {
          // 高い球は頭か GK の手
          if (b.z > 1.2 && !(q.gk && this.inOwnBox(q)) && b.z > 1.6 + q.a.jmp * 0.7) continue;
          bd = d;
          best = q;
        }
      }
      if (!best) return;
      let q = best;
      const f = this.flight;
      const s = this.shot;
      // 浮き球の競り合い：近くの子どうし（1.8m 以内）で、頭・跳ぶ力・強さ（GK は自分の箱で手を使う）
      if (f && !s && b.z > 0.3 && (f.kind === 'cross' || f.kind === 'pass' || f.kind === 'throw')) {
        let bestS = -1;
        for (const r of this.P) {
          if (this.lock && this.lock.q === r && this.t < this.lock.until) continue;
          if (r.stun > 0.3 || hyp(r.x - b.x, r.y - b.y) > 1.8) continue;
          const gkHand = r.gk && this.inOwnBox(r);
          const sc = gkHand ? 0.75 + r.a.air * 0.4 + r.a.han * 0.2 : r.a.hea * 0.4 + r.a.jmp * 0.35 + r.a.str * 0.25 + (this.has(r, '空中戦の競り') ? 0.1 : 0);
          const v = sc + this.rng() * 0.45;
          if (v > bestS) {
            bestS = v;
            q = r;
          }
        }
        if (q !== best && this.has(q, '空中戦の競り')) this.useTr(q, '空中戦の競り');
      }
      // シュートの通り道の守り手は体で止める
      if (s && q.sd !== s.sd && !q.gk) {
        if (this.rng() < 0.55 + q.a.pos * 0.25) {
          this.ev('block', { pid: q.id, sd: q.sd, vs: s.q.id });
          if (this.has(q, 'シュートブロック')) this.useTr(q, 'シュートブロック');
          const a = Math.atan2(b.vy, b.vx) + Math.PI + (this.rng() - 0.5) * 2.4;
          const v = 3 + this.rng() * 7;
          b.vx = Math.cos(a) * v;
          b.vy = Math.sin(a) * v;
          b.vz = this.rng() * 3;
          b.last = q;
          b.lastTeam = q.sd;
          this.shot = null;
          this.lock = { q, until: this.t + 0.3 };
        }
        return;
      }
      if (s && (q === s.q)) return;
      if (s && q.gk && q.sd !== s.sd && !s.decided) return; // GK は決めた所で
      // 一度試して取れなかった子は、同じ球にもう一度は触らない
      if (f && f.tried.has(q)) return;
      // 受ける・切る
      const mine = f && q.sd === f.sd;
      let p;
      if (q.gk && this.inOwnBox(q)) p = b.z > 0.3 ? 0.55 + q.a.han * 0.4 - (bs > 18 ? 0.15 : 0) : 0.95;
      else if (b.z > 1.0) p = 0.5 + q.a.hea * 0.4; // 頭
      else if (mine && q === f.to) {
        p = clamp(0.97 - Math.max(0, bs - 9) * 0.04 * (1.2 - q.a.ft), 0.4, 0.99);
        // 落ちてくる球・相手を背負っての受け
        if (f.kind !== 'pass' || b.z > 0.2) {
          let near = 99;
          for (const o of this.P) if (o.sd !== q.sd) near = Math.min(near, hyp(o.x - q.x, o.y - q.y));
          p = clamp(0.5 + q.a.ft * 0.4 + q.a.tec * 0.08 - (near < 1.8 ? 0.22 : 0), 0.2, 0.95);
        }
      }
      else if (mine) p = 0.85;
      else if (!f) p = clamp(0.95 - Math.max(0, bs - 6) * 0.05, 0.4, 0.97); // 転がっている球を拾う
      else p = clamp(0.25 + q.a.ant * 0.35 - Math.max(0, bs - 8) * 0.025 + (this.has(q, '読みのインターセプト') ? 0.1 : 0), 0.08, 0.75); // 切る
      if (f) f.tried.add(q);
      if (this.rng() > p) {
        // 触ったが取れない：少しそれる
        if (bd < 0.45) {
          // 自分のゴールの近くでは、横へこぼす（そのままゴールへ向かわない）
          const nearOwn = this.uOf(q, q.y) < 14;
          const a = nearOwn ? (this.rng() < 0.5 ? 0 : Math.PI) + (this.rng() - 0.5) * 0.8 : Math.atan2(b.vy, b.vx) + (this.rng() - 0.5) * 1.4;
          const v = bs * (0.4 + this.rng() * 0.4);
          b.vx = Math.cos(a) * v;
          b.vy = Math.sin(a) * v;
          b.last = q;
          b.lastTeam = q.sd;
          this.lock = { q, until: this.t + 0.3 };
        }
        return;
      }
      // 頭で合わせる（相手の箱の中・味方のクロス）
      if (b.z > 1.0 && !(q.gk && this.inOwnBox(q))) {
        const du = L - this.uOfSide(q.sd, q.y);
        if ((q.sd === (b.lastTeam || q.sd) && du < 16 && Math.abs(q.x - W / 2) < 14) || (du < 12 && Math.abs(q.x - W / 2) < 10)) {
          this.ball.owner = null;
          this.flight = null;
          this.ev('header', { pid: q.id, sd: q.sd });
          q.nd = 3;
          return this.shoot(q, {});
        }
        // はね返す
        const a = Math.atan2(q.dir, (this.rng() - 0.5) * 1.5);
        const v = 8 + q.a.hea * 6;
        b.vx = Math.cos(a) * v * 0.6;
        b.vy = Math.sin(a) * v;
        b.vz = 3 + this.rng() * 3;
        b.last = q;
        b.lastTeam = q.sd;
        this.flight = null;
        this.lock = { q, until: this.t + 0.4 };
        this.ev('header', { pid: q.id, sd: q.sd, clear: true });
        return;
      }
      // オフサイド
      if (f && f.offside && q === f.to) {
        this.ev('offside', { pid: q.id, sd: q.sd });
        this.flight = null;
        return this.setDead('fk', q.sd === 'home' ? 'away' : 'home', q.x, q.y, 2 + this.rng() * 2, { offside: true });
      }
      if (f && f.kind !== 'shot') {
        if (q.sd === f.sd) this.passes[f.sd + 'Ok']++;
        else this.ev('intercept', { pid: q.id, sd: q.sd, vs: f.from.id });
      }
      b.owner = q;
      b.last = q;
      b.lastTeam = q.sd;
      b.z = 0;
      b.vz = 0;
      q.hold = 0;
      q.think = 0.7 + (1 - q.a.dec) * 0.4 + this.rng() * 0.8 - ((q.team.tactic && q.team.tactic.tempo) || 0.5) * 0.4;
      q.dx = q.x;
      q.dy = q.y;
      this.flight = null;
      this.shot = null;
      this.ev('ctrl', { pid: q.id, sd: q.sd });
    }
    inOwnBox(q) {
      const u = this.uOf(q, q.y);
      return u < 16.5 && Math.abs(q.x - W / 2) < 20.16;
    }
    goal(sd) {
      const s = this.shot;
      const scorer = s && s.sd === sd ? s.q : this.ball.last && this.ball.last.sd === sd ? this.ball.last : null;
      const og = !scorer && this.ball.last;
      this.ev('goal', { sd, pid: scorer ? scorer.id : null, assist: s && s.sd === sd ? s.assist : null, og: og ? og.id : null, xg: s ? s.xg : 0, pk: s && s.pk });
      this.shot = null;
      this.flight = null;
      this.ball.owner = null;
      this.ball.vx *= 0.2;
      this.ball.vy *= 0.2;
      // キックオフは失点した側
      this.kickoff(sd === 'home' ? 'away' : 'home', false);
      this.restart.at = this.t + 30; // 喜び・並び直し（時計は進む）
    }
    // 後半の始め（前半のキックオフでなかった側）
    // 時計は前半の追加時間のあとも続けて数える（記録の時刻が戻らないように。engine が分に直す）
    secondHalf(sd) {
      this.half = 2;
      this.shot = null;
      this.flight = null;
      this.kickoff(sd, true);
    }
  }
  YA.Live = Live;
  YA.LIVE = { W, L, DT };
})();
