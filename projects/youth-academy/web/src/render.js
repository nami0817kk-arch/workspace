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
  // 点 p と線分 a→c の距離（パスの通り道に相手がいるか）
  // 点 p から線分 a→c に下ろした、線分上のいちばん近い点
  const segPt = (p, a, c) => {
    const vx = c[0] - a[0];
    const vy = c[1] - a[1];
    const l2 = vx * vx + vy * vy || 1;
    const t = clamp(((p[0] - a[0]) * vx + (p[1] - a[1]) * vy) / l2, 0, 1);
    return [a[0] + vx * t, a[1] + vy * t];
  };
  const segDist = (p, a, c) => {
    const vx = c[0] - a[0];
    const vy = c[1] - a[1];
    const l2 = vx * vx + vy * vy || 1;
    const t = clamp(((p[0] - a[0]) * vx + (p[1] - a[1]) * vy) / l2, 0, 1);
    return Math.hypot(p[0] - (a[0] + vx * t), p[1] - (a[1] + vy * t));
  };

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
    ff: 1, // 場面の入りの早送りの倍率（2026-11-22 早送りをやめた。前は 3.4 倍で、1試合に約19回、急に速くなっていた）
    ffSet: 1, // セットプレー・再開の早送りの上乗せ（前は 1.6）
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
      // 守る側は、パスが飛んでいるあいだは落ちる所を見て先にずれる（2026-11-23：ボールが着いてから動き出していて、
      // 向かう先は縦23m・寄り0.56倍なのに、実際は縦34m・寄り0.33倍と遅れていた）
      const bb = !mine && this.fl && this.fl.kind !== 'shot' && this.fl.to ? this.fl.to : this.ball;
      // 自分のゴールからの深さで考える
      const br = away ? L - bb[1] : bb[1];
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
        yr = lineD + u * (19 + (1 - tc.press) * 5); // 2026-11-22「現実に近いポジショニング」：守りの縦は37m と間延びしていた。30〜34m に詰める。2026-11-23：まだ35m あったので 22+6 → 19+5
      }
      if (mine) {
        // 攻め：幅は戦い方の広さ（サイド攻撃は外に張る）
        x = 34 + (x - 34) * (0.84 + tc.width * 0.76); // 2026-11-22：持っている側の横幅を45m→50m前後に少し広げた（本物は45〜55m）。2026-11-23：サイド攻撃と堅守の幅の差が3〜8m しかなかったので、戦い方の幅が効く傾きを上げた（幅0.5は前とほぼ同じ）
        if (s.duty === 'att') yr += has('wide') ? 10 : 5; // 攻撃の任務のサイドは追い越して上がる
        if (s.duty === 'def' || has('stay')) yr -= 5; // 守備の任務は残る
        if (has('run')) yr += 4; // 裏を狙う
        if (has('post')) yr -= 6; // 降りて受ける
        if (has('cutin')) x = lerp(x, 34, 0.3);
        if (has('wide') && s.duty === 'att') x = 34 + (x - 34) * 1.15;
        x = lerp(x, this.ball[0], 0.08);
      } else {
        // 守り：横はボールへ絞る
        if (s.duty === 'att') yr += 2; // 攻撃の任務は戻りが遅い（2026-11-23 4→2：前線が残りすぎて縦が間延びしていた）
        x = 34 + (x - 34) * 0.72 + (bb[0] - 34) * 0.6; // 2026-11-23：横幅を保ったまま全体をボール側へずらす（前の lerp(絞り, ボール, 0.6) は横幅が約16m まで縮み、ボールのそばに塊になっていた。本物は横35〜40m で、ボールが寄った分の半分ほど寄る）
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
        // ラインの高さは、ボールにすぐは合わせず、4人がそろって動ける速さ（約5m/秒）で上げ下げする（2026-11-22：ボールが速く動くと選手が追いつけず、ばらばらに遅れてラインが崩れていた）
        {
          const k = away ? 'away' : 'home';
          const raw = sd.reduce((a, x) => a + x, 0) / sd.length;
          const ls = (this._lineS = this._lineS || {});
          const dtl = ls.t != null ? clamp((this.clock || 0) - ls.t, 0, 0.5) : 0;
          ls[k] = ls[k] == null || dtl === 0 && ls.t == null ? raw : ls[k] + clamp(raw - ls[k], -5.2 * dtl, 5.2 * dtl);
          out.lineD[k] = ls[k];
        }
        // 相手から見たこのチームの最後の守り手の位置（オフサイドの線）。いまの位置で見る
        out.last[away ? 'away' : 'home'] = Math.min(...ids.map((id) => dep(this.disp[id][1])));
      }
      if (this._lineS) this._lineS.t = this.clock || 0;
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
          if (!(this.fl && this.expect === id)) d = Math.min(d, lastOpp - 1.4); // 2026-11-22 0.6→1.4：守りが下がると追い越していた
        }
      } else {
        // マーク：自分の持ち場の近くの相手を、ゴール側から捕まえる
        const km = this.ab01(id, 'マーク');
        const kp = this.ab01(id, 'ポジショニング');
        let tgt = null;
        let bd = 12 + kp * 4;
        for (const o of opp) {
          if (o === this.owner) continue; // 持っている子はプレスの子が見る
          if (dist(this.disp[o], this.ball) > 22) continue; // 2026-11-22：ボールから遠い相手は捕まえず、ボール側を固める（前は遠いサイドの相手に引っぱられて、守りが寄らず縦に間延びした）
          const r = Math.hypot(this.disp[o][0] - x, dep(this.disp[o][1]) - d);
          if (r < bd) { bd = r; tgt = o; }
        }
        if (tgt) {
          const q = this.disp[tgt];
          const qd = dep(q[1]);
          const gx = 34 - q[0];
          const gd = -qd;
          const gl = Math.hypot(gx, gd) || 1;
          const gap = 2.2 + (1 - km) * 2.6; // マークのうまい子ほど近くにつく
          const mx = q[0] + (gx / gl) * gap;
          const md = qd + (gd / gl) * gap;
          const wgt = (this.scene ? 0.45 : 0.58) + km * 0.3; // 2026-11-23 0.45→0.55：守りがボール側に固まり、近くの相手を捕まえない子が増えた。 2026-11-22：攻める子が空きを探すようになったので、守りも付いていく
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
          const lim = 2.6 - kp * 2.2; // 2026-11-22：前後に7.6m 凸凹していた。ポジショニングの高い子ほどそろう
          d = clamp(d, li.lineD[key] - lim, li.lineD[key] + lim * 0.6);
        }
      }
      return [clamp(x, 2, W - 2), away ? L - clamp(d, 3, L - 3) : clamp(d, 3, L - 3)];
    }

    // ----- 選手の頭（2026-11-22「試合の動きを AI に」） -----
    // 一人ひとりが、立ち位置（offballPos／場面の台本の位置）のまわりの候補地に点数を付けて、いちばん良い所へ向かう。
    //   攻め：空いているか・持っている子からパスの線が通るか・前へ進めるか・役割の好み（外・裏・降りる・中）・オフサイド
    //   守り：パスの通り道を切る・ボールより後ろ・最終ラインの高さ
    //   どちらも：持ち場から離れすぎない（ポジショニング・任務）・味方と重ならない（チームワーク）
    // 選び直す間隔は判断・予測、見る広さは視野、選ぶ正確さは判断（低い子はときどき外れた所を選ぶ）、走る量は運動量。
    // 選んだ所は立ち位置からのずれとして持つので、選び直すまでのあいだもボールと一緒に動く。着いても小さく合わせ続ける（止まらない）
    think(id, anchor, opt) {
      opt = opt || {};
      const B = (this.brain = this.brain || {});
      const now = this.clock || 0;
      let s = B[id];
      if (!s) s = B[id] = { off: [0, 0], next: 0, ph: Math.random() * 6.283, tight: false };
      if (now >= s.next || !!opt.tight !== s.tight) {
        s.off = this.choose(id, anchor, opt);
        s.tight = !!opt.tight;
        const quick = (this.ab01(id, '判断') + this.ab01(id, '予測')) / 2;
        s.next = now + (0.2 + (1 - quick) * 0.45) * (0.85 + Math.random() * 0.3);
        // ポジショニングの低い子は、ラインの高さを読み違える（選び直すたびに少しずつ変わる）
        s.err = (s.err || 0) * 0.5 + (Math.random() - 0.5) * 2 * (1 - this.ab01(id, 'ポジショニング')) * 3.2;
      }
      // 読みの速さ：持ち場が動いたのに気づいて動き出すまでの遅れ（予測・ポジショニングの高い子ほど早い。低い子は1人だけ遅れる）
      {
        const tau = opt.tight ? 0.05 : 0.06 + (1 - (this.ab01(id, '予測') + this.ab01(id, 'ポジショニング')) / 2) * 0.6;
        const dtt = s.pt != null ? Math.max(0, now - s.pt) : 1;
        if (!s.sa || dist(s.sa, anchor) > 25) s.sa = anchor.slice();
        else { const a = 1 - Math.exp(-dtt / tau); s.sa = [lerp(s.sa[0], anchor[0], a), lerp(s.sa[1], anchor[1], a)]; }
      }
      anchor = s.sa;
      const me = this.disp[id] || anchor;
      const back = this.lineInfo().back[id] && this.poss !== (this.teamOf(id) === this.match.away ? 'away' : 'home');
      // 見ながら合わせる：持ち場の上で小さく体の位置を直し続ける（最終ラインは前後には揺れない）
      const amp = opt.tight ? 0.6 : 0.9;
      const tg = [anchor[0] + s.off[0] + Math.cos(now * 0.9 + s.ph) * amp, anchor[1] + s.off[1] + Math.sin(now * 1.3 + s.ph) * amp * (back ? 0.25 : 0.7) + (back && !opt.tight ? s.err || 0 : 0)];
      // 味方のすぐそば（1.6m 以内）へは行かない：向かう先を味方から離す（2026-11-23：守りを詰めて、味方どうしが1m 未満に重なる組が増えた。
      // 台本の子は台本の位置を優先する）
      if (!opt.tight) {
        const myT = this.teamOf(id);
        for (const o of Object.keys(this.disp)) {
          if (o === id || this.teamOf(o) !== myT) continue;
          const q = this.disp[o];
          const dd = dist(tg, q);
          if (dd < 1.6) { const ux = dd > 0.01 ? (tg[0] - q[0]) / dd : (me[0] - q[0]) / Math.max(0.01, dist(me, q)); const uy = dd > 0.01 ? (tg[1] - q[1]) / dd : (me[1] - q[1]) / Math.max(0.01, dist(me, q)); tg[0] = q[0] + ux * 1.6; tg[1] = q[1] + uy * 1.6; }
        }
      }
      const d = dist(tg, me);
      const work = 0.8 + this.ab01(id, '運動量') * 0.35;
      // 遠い・急ぐ所へは走り、近ければジョグ、合わせるだけなら歩く
      let v = d > 6 ? MOVE.sprint * (0.75 + work * 0.12) : d > 2.5 ? MOVE.jog * work : Math.max(1.6, MOVE.jog * work * 0.5);
      // 持ち場が動いている（ボールが動いてラインや形がずれる）ときは、その速さについていく。前は「近いから歩く」で遅れ、最終ラインが4m ずれていた
      if (s.pa && now > s.pt) {
        const av = dist(anchor, s.pa) / (now - s.pt);
        v = Math.min(MOVE.sprint, Math.max(v, av * 1.15 + d * 1.2));
      }
      s.pa = anchor.slice();
      s.pt = now;
      return [[clamp(tg[0], 0.5, W - 0.5), clamp(tg[1], 0.5, L - 0.5)], v];
    }
    choose(id, anchor, opt) {
      const b = this.base[id];
      if (!b || b[3] === 0 || !this.match) return [0, 0];
      const my = b[2];
      const away = my === this.match.away;
      const key = away ? 'away' : 'home';
      const dep = (y) => (away ? L - y : y);
      const mine = this.poss === key;
      const tc = this.tacOf(id);
      const s = b[4] || {};
      const tags = (YA.ROLE_DEF && YA.ROLE_DEF[s.role] && YA.ROLE_DEF[s.role].tags) || [];
      const has = (k) => tags.indexOf(k) >= 0;
      const k = (n) => this.ab01(id, n);
      const kPos = k('ポジショニング');
      const kTeam = k('チームワーク');
      const kOff = k('オフザボール');
      const kVis = k('視野');
      const kDec = k('判断');
      const kAnt = k('予測');
      const pl = this.teamOf(id) && this.teamOf(id).players && this.teamOf(id).players[id];
      const tr = (n) => !!pl && ((pl.traits || []).indexOf(n) >= 0 || !!(pl.aw && pl.aw.as && pl.aw.as.indexOf(n) >= 0) || !!(pl.aw2 && pl.aw2.as && pl.aw2.as.indexOf(n) >= 0)); // 覚醒の中身の特性も（engine の has と同じ）
      const ids = Object.keys(this.disp).filter((o) => this.base[o] && this.base[o][3] !== 0 && o !== id);
      const opp = ids.filter((o) => this.base[o][2] !== my);
      const mates = ids.filter((o) => this.base[o][2] === my);
      const li = this.lineInfo();
      const okey = away ? 'home' : 'away';
      const lastOpp = li.last[okey] != null ? L - li.last[okey] : null;
      const own = this.owner && this.base[this.owner] ? this.owner : null;
      const ownMine = own && this.base[own][2] === my;
      const oq = own ? this.disp[own] : null;
      // 候補：立ち位置のまわりの輪。視野の広い子ほど遠くまで見る
      const rings = opt.tight ? [1.5, 3] : [2.5, 5, 5 + kVis * 4];
      const cands = [[0, 0]];
      for (const r of rings) for (let a = 0; a < 8; a++) cands.push([Math.cos((a * Math.PI) / 4) * r, Math.sin((a * Math.PI) / 4) * r]);
      // 持ち場を守る強さ：ポジショニングの高い子、守備の任務、守っているとき、場面の台本の子は強く
      let keep = (mine ? 0.75 - kOff * 0.35 : (0.6 + kPos * 0.8) * 1.6) * (opt.tight ? 2.5 : 1); // 攻めは空きを探して動き回り、守りはポジショニングの高い子ほど持ち場を守る
      if (mine && (s.duty === 'def' || has('stay'))) keep *= 1.5;
      if (mine && s.duty === 'att') keep *= 0.75;
      const segD = segDist;
      let best = cands[0];
      let bs = -1e9;
      for (const o of cands) {
        const c = [anchor[0] + o[0], anchor[1] + o[1]];
        if (c[0] < 1 || c[0] > W - 1 || c[1] < 1 || c[1] > L - 1) continue;
        const r = Math.hypot(o[0], o[1]);
        let sc = -keep * (r / 4) * (r / 4);
        // 味方と重ならない・相手の真上に立たない
        for (const m of mates) { const d = dist(c, this.disp[m]); if (d < 7) sc -= ((7 - d) / 7) * (0.6 + kTeam * 0.9); if (d < 1.6) sc -= (1.6 - d) * 3; } // 2026-11-23：守りを詰めて味方どうしが1m 未満に寄ることが増えたので、すぐそばは強く避ける
        if (!opt.tight) for (const q of opp) { const d = dist(c, this.disp[q]); if (d < 2) sc -= (2 - d) * 1.5; } // 台本の子は台本の位置を優先する（競り合いは台本どおり）
        // 味方がもう向かっている所には行かない（2人が同じ相手・同じ所へ寄って重なっていた）
        if (!opt.tight) for (const m of mates) { const t = this.brain && this.brain[m]; if (!t || !t.sa) continue; const d = dist(c, [t.sa[0] + t.off[0], t.sa[1] + t.off[1]]); if (d < 4) sc -= (4 - d) * 1.5; }
        const cd = dep(c[1]);
        if (mine) {
          // 空き：いちばん近い相手から離れているほど良い
          let near = 99;
          for (const q of opp) near = Math.min(near, dist(c, this.disp[q]));
          sc += (Math.min(near, 12) / 12) * (0.1 + kOff * 3.4);
          // パスの線：持っている味方から、相手に切られずに通るか（視野の広い子ほど遠くの線まで見る）
          if (ownMine && own !== id && oq) {
            const pl = dist(c, oq);
            if (pl > 6 && pl < 18 + kVis * 20) {
              let clr = 5;
              for (const q of opp) clr = Math.min(clr, segD(this.disp[q], oq, c));
              sc += (clr / 5) * (0.5 + kVis * 0.9);
            }
          }
          // 前へ：役割で好みが違う（裏を狙う・攻撃の任務は前、降りる・残るは後ろ）
          let fw = 0.15 + tc.tempo * 0.25 + (this.shareOf(id) - 0.5) * 1.2 + (this.surgeOf(id) ? 0.4 : 0); // 押している側・見どころの前は前へ
          if (has('run') || s.duty === 'att') fw += 0.45;
          if (tr('裏への抜け出し') || tr('二列目からの飛び出し') || tr('斜めの走り込み')) fw += 0.35;
          if (has('post') || tr('下がって受ける')) fw -= 0.55;
          if (s.duty === 'def' || has('stay')) fw -= 0.45;
          sc += ((cd - dep(anchor[1])) / 8) * fw;
          // 外へ：サイドの役割・広い戦い方は外、中へ入る役割は内側
          const wide = (has('wide') ? 0.8 : 0) + (tc.width - 0.5) * 2.4 + (tr('オーバーラップ') ? 0.3 : 0);
          const inn = has('cutin') || tr('カットイン') ? 0.5 : 0;
          sc += ((Math.abs(c[0] - 34) - Math.abs(anchor[0] - 34)) / 8) * (wide - inn);
          // オフサイドの線は越えない
          if (lastOpp != null && cd > lastOpp - 1.8 && !(this.fl && this.expect === id)) sc -= 8;
        } else {
          // 守り：持っている相手から、近くの相手へのパスの通り道を切る（予測の高い子ほど）
          if (own && oq) {
            for (const q of opp) {
              if (q === own) continue;
              const qd = dist(this.disp[q], oq);
              if (qd > 30) continue;
              const g = segD(c, oq, this.disp[q]);
              if (g < 3.5) sc += (1 - g / 3.5) * (0.25 + kAnt * 0.45);
            }
            // ボールより前に出ない（ボールの後ろで守る）
            if (cd > dep(oq[1]) + 2) sc -= 1.2;
          }
          // マーク：近くの相手に、ゴール側から付く（マークの高い子ほど近く）
          {
            let mq = null;
            let md = 9;
            for (const q of opp) { if (q === own || dist(this.disp[q], this.ball) > 24) continue; const d = dist(c, this.disp[q]); if (d < md) { md = d; mq = q; } }
            const gap = 1.6 + (1 - k('マーク')) * 2.4; // 相手の上には立たず、間合いをとって付く
            if (mq && dep(this.disp[mq][1]) >= cd - 0.5) sc += (1 - Math.min(Math.abs(md - gap), 7) / 7) * (0.6 + k('マーク') * 0.9);
          }
          // 最終ラインの子は、ラインの高さから前後にずれない
          if (li.back[id] && li.lineD[key] != null) sc -= Math.abs(cd - li.lineD[key]) * (0.6 + kPos * 0.8);
        }
        // 場面の台本のパスが転がっている間は、通り道に立たない（台本では切らない球を、体が通り抜けて見えていた）
        if (this.scene && this.fl && this.fl.kind === 'ground' && this.fl.by && this.base[this.fl.by] && this.base[this.fl.by][2] !== my && this.fl.icpt !== id && segDist(c, this.ball, this.fl.to) < 1.8) sc -= 6;
        // 判断が低い子は、ときどき外れた所を選ぶ
        sc += Math.random() * (1 - kDec) * 1.4;
        if (sc > bs) { bs = sc; best = o; }
      }
      return best;
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
      // PK：倒れた所から「PKを蹴る」のコマへは、蹴って転がすのではなく、笛のあと一瞬暗くしてボールをスポットに置き直す（2026-11-23）
      if (sc.type === 'pk' && sc.actors && sc.actors.kicker) {
        for (const e of ev) if (e.b && e.b.cap && /PKを蹴る/.test(e.b.cap)) { e.kind = 'place'; e.who = sc.actors.kicker; e.recv = null; }
      }
      // 蹴る子が決まらない蹴り（PK など、ボールが置かれてから蹴る）：攻める側でボールにいちばん近い子（6m 以内）が蹴る。
      // その前の球の受け手にもして、持ってから蹴る（2026-11-23：PK の場面でキッカーがいず、シュートが「待つ」になって打たれないまま「得点」で終わっていた）
      {
        const atkTeam = sc.side === 'away' ? this.match && this.match.away : this.match && this.match.home;
        for (let i = 0; i < ev.length; i++) {
          const e = ev[i];
          if (e.kind !== 'kick' || e.who || !atkTeam) continue;
          let best = null;
          let bd = 6;
          for (const id of Object.keys(e.a.pos || {})) {
            if (!this.base[id] || this.base[id][2] !== atkTeam) continue;
            const dd = dist(e.a.pos[id], e.a.ball);
            if (dd < bd) { bd = dd; best = id; }
          }
          if (!best) continue;
          e.who = best;
          if (e.recv === best) e.recv = null;
          const pv = ev[i - 1];
          if (pv && pv.kind === 'kick' && !pv.recv) pv.recv = best; // 同じ子なら「自分へのパス」＝運ぶ動きになる
        }
      }
      // 奪われるパス（相手の選手が受け手の地を這う球）：前は相手の足元へ蹴っていて、相手へのパスに見えた（2026-11-22）。
      // いまは同じ向きに少し先（味方のいる方）を狙って蹴り、相手が台本の位置で足を出して切る
      for (const e of ev) {
        if (e.kind !== 'kick' || !e.recv || !e.who || !this.base[e.recv] || !this.base[e.who]) continue;
        if (this.base[e.recv][2] === this.base[e.who][2]) continue; // GK が取る球も、GK の足元へは蹴らない
        if ((e.b.ball[2] || 0) > 0.5 || e.b.ball[1] < 1 || e.b.ball[1] > L - 1) continue;
        const d = dist(e.a.ball, e.b.ball);
        if (d < 4) { e.tackle = true; continue; } // すぐ隣の相手へ渡る球は、パスではなく奪われた（相手が足で突いて奪う）
        const ext = Math.min(6, 51 - d);
        if (ext < 2) continue;
        const ux = (e.b.ball[0] - e.a.ball[0]) / d;
        const uy = (e.b.ball[1] - e.a.ball[1]) / d;
        e.ip = [e.b.ball[0], e.b.ball[1]];
        e.to = [clamp(e.b.ball[0] + ux * ext, 1, W - 1), clamp(e.b.ball[1] + uy * ext, 1, L - 1), 0];
        e.icpt = true;
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
      const h0 = this.holderOf(f0);
      // 相手が持っているのに場面がこちらのボールで始まるときは、近くても入りで奪ってから（2026-11-21「いきなり、こっちボールになる」）
      const flip = !!(this.owner && h0 && this.teamOf(this.owner) && this.teamOf(this.owner) !== this.teamOf(h0));
      if (far > 7 || flip || !Object.keys(this.disp).length) {
        // つなげるのは、受け手と主役が3秒ほどで最初の位置に着けるとき。ライン際の球（セットプレー）は置き直す
        const edge = f0.ball[0] < 1.5 || f0.ball[0] > W - 1.5 || f0.ball[1] < 1.5 || f0.ball[1] > L - 1.5 || sc.type === 'fk'; // 直接FK もボールを置いて始める（2026-11-17 ファウルからの FK が増えた）
        let eta = 0;
        for (const id of Object.keys(f0.pos)) if (this.disp[id]) eta = Math.max(eta, dist(this.disp[id], f0.pos[id]) / MOVE.sprint);
        const reachable = h0 && this.disp[h0] && dist(this.disp[h0], f0.ball) / MOVE.sprint < 9 && eta < 10;
        // セットプレー：ボールをその場に置き、蹴る子と主役が持ち場へ走る（暗転しない）
        const setOk = h0 && this.disp[h0] && dist(this.disp[h0], f0.ball) / MOVE.sprint < 14 && eta < 15; // セットプレーは速めの早送りなので遠くからでも間に合う
        if (Object.keys(this.disp).length && this.cut <= 0 && setOk && edge && (f0.ball[2] || 0) < 0.5) {
          this.pre = { t: 0, f0, h0, kicked: true, set: true };
          this.cut = Math.max(this.cut || 0, 0.3); // ボールを置き直す一瞬は暗くする（前は早送りの中で見えなかった。等倍ではボールが飛んで見える）
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
      // 外に出て止まりかけた球のまま入りが始まったら、ラインの内側に置き直す（2026-11-23：ライン際へのパスが転がり出たまま入りになり、
      // 主役が外の球を拾ってラインの外を運んでいた）
      {
        const b = this.ball;
        if (!this.owner && !this.fl && (b[0] < -0.3 || b[0] > W + 0.3 || b[1] < -0.3 || b[1] > L + 0.3) && !(Math.abs(b[0] - 34) < 3.7 && (b[1] < 0 || b[1] > L))) {
          this.ball = [clamp(b[0], 0.8, W - 0.8), clamp(b[1], 0.8, L - 0.8), 0];
          this.bv = [0, 0];
          this.cut = Math.max(this.cut || 0, 0.3);
          this.places = (this.places || 0) + 1;
        }
      }
      const fr = this.scene.frames;
      if (!p.kicked) {
        // 相手が持っている：前は相手がこちらの主役へパスを出していて、急にこちらのボールになった。
        // いちばん近い味方が寄せて奪い、その子が拾ってから場面へつなぐ（GK が持っているときは蹴り出しのまま）
        if (this.owner && this.teamOf(this.owner) !== this.teamOf(p.h0) && this.base[this.owner] && this.base[this.owner][3] !== 0) {
          // 2026-11-22：前は必ず近い子が走って奪っていて、急に奪ったように見えた。寄せられる子が近く（7m 以内）にいなければ、
          // 相手が味方へ出すパスを、通り道の近くの子が読んで切る
          if (!p.plan) {
            p.plan = 'chase';
            const my = this.teamOf(p.h0);
            const o = this.owner;
            const oq = this.disp[o];
            const ours = Object.keys(this.disp).filter((id) => this.teamOf(id) === my && this.base[id] && this.base[id][3] !== 0);
            const near = Math.min(...ours.map((id) => dist(this.disp[id], oq)));
            if (near > 7) {
              let bs = 5;
              for (const mt of Object.keys(this.disp)) {
                if (mt === o || this.teamOf(mt) !== this.teamOf(o) || !this.base[mt] || this.base[mt][3] === 0) continue;
                const md = dist(this.disp[mt], oq);
                if (md < 8 || md > 30) continue;
                for (const u of ours) {
                  const pt = segPt(this.disp[u], oq, this.disp[mt]);
                  const du = dist(this.disp[u], pt);
                  if (dist(pt, oq) > 5 && du < bs) { bs = du; p.plan = { mate: mt, u, pt }; }
                }
              }
            }
          }
          if (p.plan !== 'chase') {
            const pl = p.plan;
            if (!pl.passed) {
              if (p.t > 0.6 && !(this.lock[this.owner] > 0) && this.disp[pl.mate]) {
                pl.passed = true;
                const by = this.owner;
                this.kick([this.disp[pl.mate][0], this.disp[pl.mate][1], 0], pl.mate, by);
                if (this.fl) { this.fl.icpt = pl.u; this.fl.ip = pl.pt; }
              }
              return;
            }
            if (this.fl) return;
            if (this.owner && this.teamOf(this.owner) === this.teamOf(p.h0)) {
              const sp = this.teamOf(this.owner).players[this.owner];
              if (sp) this.capText = { text: sp.num + '番 ' + String(sp.name).split(' ')[0].split('・').pop() + ' パスカット', t: 0 };
              this.steals = (this.steals || 0) + 1; // 点検用
              p.plan = null;
              p.t = 0;
              return;
            }
            p.plan = 'chase'; // 切れなかった：寄せて奪いに行く
            p.t = 0;
            return;
          }
          if (!p.steal || !this.disp[p.steal]) {
            const my = this.teamOf(p.h0);
            let bd = 1e9;
            for (const id of Object.keys(this.disp)) {
              if (this.teamOf(id) !== my || !this.base[id] || this.base[id][3] === 0) continue;
              const d = dist(this.disp[id], this.disp[this.owner]);
              if (d < bd) { bd = d; p.steal = id; }
            }
          }
          if (p.steal && dist(this.disp[p.steal], this.disp[this.owner]) < MOVE.tackle) {
            const r = this.disp[p.steal];
            const b = this.ball;
            const d = Math.max(0.3, dist(r, b));
            this.lock[this.owner] = 0.9;
            this.lock[p.steal] = 0.18; // 突いた球が足元へ転がってから持つ（その場で持ち主が入れ替わって見えないように）
            this.owner = null;
            this.idle = null;
            this.bv = [((r[0] - b[0]) / d) * 3, ((r[1] - b[1]) / d) * 3];
            this.expect = p.steal;
            this.kicked = true; // 触った
            this.lastTouch = this.teamOf(p.steal);
            const sp = this.teamOf(p.steal).players[p.steal];
            if (sp) this.capText = { text: sp.num + '番 ' + String(sp.name).split(' ')[0].split('・').pop() + ' 奪った', t: 0 };
            this.steals = (this.steals || 0) + 1; // 点検用
            p.t = 0;
          } else if (p.t > 7 || !p.steal) return this.endPre(true);
          return;
        }
        if (this.owner) {
          if (this.owner === p.h0) p.kicked = true; // もう持っている：そこまで運ぶ
          else if (!(this.lock[this.owner] > 0)) {
            // 受け手が落ちる所に間に合う時に蹴る（それまでは持って運ぶ）
            const d = dist(this.ball, p.f0.ball);
            const tFly = d > 30 ? d / MOVE.loft + 0.25 : d / 11;
            const eta = dist(this.disp[p.h0], p.f0.ball) / (MOVE.sprint * 0.85);
            if (eta > tFly - 0.2 && p.t < 5) return; // 受け手が先に着いて待つ（届く球が転がり過ぎない）
            p.kicked = true;
            if (this.teamOf(this.owner) !== this.teamOf(p.h0) && this.base[this.owner][3] !== 0) this.gifts = (this.gifts || 0) + 1; // 点検用：相手へ渡すつなぎ（GK の蹴り出しだけのはず）
            if (this.teamOf(this.owner) !== this.teamOf(p.h0)) {
              // 相手の GK の蹴り出し：前の味方へ大きく蹴った球を、こちらの主役が競り勝って拾う（2026-11-22：前はこちらの主役へまっすぐ蹴っていた）
              const by = this.owner;
              const d0 = Math.max(1, dist(this.ball, p.f0.ball));
              const ux = (p.f0.ball[0] - this.ball[0]) / d0;
              const uy = (p.f0.ball[1] - this.ball[1]) / d0;
              let mate = null;
              let md = 1e9;
              for (const o of Object.keys(this.disp)) if (o !== by && this.teamOf(o) === this.teamOf(by) && this.base[o] && this.base[o][3] !== 0) { const dd = dist(this.disp[o], p.f0.ball); if (dd < md) { md = dd; mate = o; } }
              this.kick([clamp(p.f0.ball[0] + ux * 5, 1, W - 1), clamp(p.f0.ball[1] + uy * 5, 1, L - 1), 0], mate, by);
              if (this.fl) { this.fl.icpt = p.h0; this.fl.ip = [p.f0.ball[0], p.f0.ball[1]]; }
            } else {
              this.kick([p.f0.ball[0], p.f0.ball[1], 0], p.h0, this.owner);
              if (this.fl && this.fl.kind === 'ground') { const f = this.fl; f.vEnd = 0.5; f.v0 = Math.sqrt(0.25 + 2 * MOVE.fric * f.d); f.T = Math.max(0.15, (f.v0 - 0.5) / MOVE.fric); } // 2026-11-23：受け手を待つ球なので、落ちる所でほぼ止める（前は普通のパスの速さで10m 以上転がり、ライン際では外へ出て、外で拾っていた）
            }
          }
        } else if (p.t > 4) return this.endPre(true);
        return;
      }
      const got = !this.fl && this.owner === p.h0 && dist(this.ball, p.f0.ball) < 4;
      let ready = got;
      for (const id of Object.keys(p.f0.pos)) if (this.disp[id] && dist(this.disp[id], p.f0.pos[id]) > 3) ready = false;
      // 受け手が持てば、主役が少し遅れていても始める（台本のあいだに追いつく）。ただし攻める側の主役が
      // 10m 以上離れていれば待ち、それでも間に合わなければ暗転して置き直す（2026-11-17：40m 先の受け手へクロスを上げて、
      // 得点の場面でボールが網に入らないことがあった）
      let lag = 0;
      for (const id of Object.values(this.scene.actors || {})) if (this.disp[id] && p.f0.pos[id]) lag = Math.max(lag, dist(this.disp[id], p.f0.pos[id]));
      const timeUp = p.t > (p.set ? 16 : 10);
      if (ready || (got && p.t > 1.2 && (lag < 10 || p.t > 6)) || timeUp) this.endPre(this.owner !== p.h0 || dist(this.ball, p.f0.ball) > 8 || lag >= 10);
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
      if (e.kind === 'place') {
        if (!e.done) {
          e.done = true;
          const spot = [e.to[0], e.to[1]];
          const end = spot[1] > L / 2 ? L : 0;
          const sgn = end === L ? 1 : -1; // ゴールへ向かう向き
          const kid = e.who;
          this.cut = 0.4;
          this.fl = null;
          this.bv = [0, 0];
          this.ball = [spot[0], spot[1], 0];
          for (const id of Object.keys(this.disp)) {
            const fp = e.b.pos && e.b.pos[id];
            if (id === kid) this.disp[id] = [spot[0], spot[1] - sgn * 0.7];
            else if (fp) this.disp[id] = fp.slice(0, 2);
            else {
              // ペナルティエリアの外へ（ゴールラインから17.5m）
              const q = this.disp[id];
              const depth = Math.abs(end - q[1]);
              if (Math.abs(q[0] - 34) < 21 && depth < 17.5) this.disp[id] = [q[0], end - sgn * (17.5 + Math.random() * 2)];
            }
            this.vel[id] = [0, 0];
            if (this.brain && this.brain[id]) this.brain[id].next = 0;
            this.stgt[id] = this.disp[id].slice(); // 蹴るまでその場で待つ（キッカーがボールを持って助走の位置へ下がり、ほかの子がエリアへ戻っていた）
          }
          this.owner = kid;
          this.expect = kid;
          this.lastTouch = this.teamOf(kid);
          this.places = (this.places || 0) + 1;
        }
        if (e.t >= 1.1) this.nextEvent();
        return;
      }
      if (e.kind === 'wait') {
        // 台本の「待つ」の受け手が持ち主の相手なら、その子が奪う（2026-11-23：最後の2コマでボールが少ししか動かない奪われ方は
        // 「待つ」になっていて、相手が取らないまま場面が終わり、攻めた側が持ち続けていた）
        const holder = this.owner || e.who;
        if (!e.taken && e.recv && holder && this.disp[e.recv] && this.teamOf(e.recv) !== this.teamOf(holder)) {
          const r = this.disp[e.recv];
          const b = this.ball;
          if (this.owner && dist(r, b) < MOVE.tackle * 1.5) {
            e.taken = true;
            const dd = Math.max(0.3, dist(r, b));
            this.lock[this.owner] = 0.9;
            this.lock[e.recv] = 0.18;
            this.owner = null;
            this.bv = [((r[0] - b[0]) / dd) * 3.5, ((r[1] - b[1]) / dd) * 3.5];
            this.lastTouch = this.teamOf(e.recv);
            this.kicked = true;
          } else this.stgt[e.recv] = [b[0], b[1]];
          this.expect = e.recv;
          e.turn = true;
        }
        if ((e.t >= e.minDur && (!e.turn || e.taken || this.owner === e.recv)) || e.t > (e.turn ? 3.5 : 2.5)) this.nextEvent(); // 相手が奪う「待つ」は、奪うまで（3.5秒まで）
        return;
      }
      if (e.phase === 'reach') {
        // 蹴る・運ぶ子がボールに触れるまで（たいていはもう持っている）
        if (has || !e.kicker || e.t > 2.6) {
          // 自分への「パス」は、受けて運ぶだけ
          if (e.kind === 'kick' && e.recv && e.recv === e.kicker) { e.kind = 'dribble'; e.phase = 'dribble'; e.t = 0; return; }
          // 誰も触れていないボールは蹴れない（外へ出た球・こぼれ球）：そのまま転がして待つ
          if (e.kind === 'kick' && (!e.kicker || dist(this.disp[e.kicker] || [1e9, 1e9], this.ball) > MOVE.reach * 1.6)) {
            e.kind = 'wait';
            e.t = 0;
            // 相手に渡るはずの球（奪われる・切られる）なら、受け手の相手がこぼれ球を取りに行く（2026-11-23：取りに行かないまま場面が終わり、
            // 「奪われた」のに攻めた側が持ち続けていた）
            if (e.recv && this.disp[e.recv] && this.teamOf(e.recv) !== this.teamOf(e.kicker || this.owner || e.recv)) { this.expect = e.recv; this.stgt[e.recv] = [this.ball[0], this.ball[1]]; e.minDur = Math.max(e.minDur || 0, 1.2); }
            return;
          }
          e.phase = e.kind;
          e.t = 0;
          if (e.kind === 'kick' && e.tackle && this.disp[e.recv] && this.owner === e.kicker) {
            // 奪われる：相手が足で突いて、ボールがその子の足元へ転がる
            const r = this.disp[e.recv];
            const b = this.ball;
            const dd = Math.max(0.3, dist(r, b));
            this.lock[e.kicker] = 0.9;
            this.lock[e.recv] = 0.18;
            this.owner = null;
            this.bv = [((r[0] - b[0]) / dd) * 3.5, ((r[1] - b[1]) / dd) * 3.5];
            this.expect = e.recv;
            this.lastTouch = this.teamOf(e.recv);
            this.kicked = true;
          } else if (e.kind === 'kick') {
            this.kick(e.to, e.recv, e.kicker);
            if (e.icpt && this.fl) { this.fl.icpt = e.recv; this.fl.ip = e.ip; }
          }
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
      // ごく短い転がるパスは、届く時間を 0.15 秒にそろえる。そのときは初速も合わせ直す
      // （2026-11-18：時間だけ延ばしていて、球が先に着いて1コマ止まり、また転がり出していた。through の場面のシード3）
      let vEnd = MOVE.passEnd;
      if (kind === 'ground' && T < 0.15) {
        T = 0.15;
        v0 = (d + 0.5 * MOVE.fric * T * T) / T;
        vEnd = Math.max(0, v0 - MOVE.fric * T);
      }
      this.fl = { by, from, to: [to[0], to[1], Math.max(0, to[2] || 0)], d: Math.max(0.5, dist(from, to)), T: Math.max(0.15, T), t: 0, kind, v0, vEnd, h, z0: from[2] || 0, save, recv: recv || null };
      if (by) this.lock[by] = 0.3;
      if (by && this.teamOf(by)) this.lastTouch = this.teamOf(by); // 最後に触ったチーム（外に出たときの再開に使う）
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
      // 場面の台本のパス：通り道の近くの相手（台本の子のほか）は、すぐに選び直して通り道から外れる（受け手のほかは触らないので、体を通り抜けて見えていた）
      if (this.scene && kind === 'ground' && by && this.base[by] && this.brain) {
        for (const o of Object.keys(this.disp)) {
          if (o === recv || !this.base[o] || this.base[o][2] === this.base[by][2] || !this.brain[o]) continue;
          if (segDist(this.disp[o], from, to) < 2) this.brain[o].next = 0;
        }
      }
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
        // 場面の台本の地を這う球（受け手のほかは触らない）：相手の足元を通る所だけ、少し浮いて足を越える（届く時間は変えない）
        // 合間の「足の間を通す」うまいパス（fl.thread）も同じく足を越える（2026-11-23：体のすぐそばを触られずに通り、体を通り抜けて見えた）
        if ((this.scene || fl.thread) && fl.kind === 'ground' && fl.by && this.base[fl.by]) {
          let hop = 0;
          for (const o of Object.keys(this.disp)) {
            if (o === fl.recv || o === fl.icpt || !this.base[o] || this.base[o][2] === this.base[fl.by][2]) continue;
            const d = dist(this.disp[o], this.ball);
            if (d < 1.1) hop = Math.max(hop, 0.6 * (1 - d / 1.1) + 0.15);
          }
          if (hop > 0) this.ball[2] = Math.max(this.ball[2], hop);
        }
        // パスカット：決まった子（fl.icpt）が通り道に足を出して止める（場面の「奪われる」パス・合間の失敗・場面の入りで相手のパスを切る）
        if (fl.icpt && this.disp[fl.icpt] && this.ball[2] < (fl.kind === 'loft' ? 3 : 1.3) && dist(this.disp[fl.icpt], this.ball) < MOVE.reach * (fl.kind === 'loft' ? 1.4 : 1)) {
          const id = fl.icpt;
          this.fl = null;
          this.bv = [0, 0];
          this.owner = id;
          this.lastTouch = this.teamOf(id);
          this.poss = this.teamOf(id) === this.match.home ? 'home' : 'away';
          this.expect = this.scene && !this.pre ? this.expect : null; // 場面の入りでは、合間のパスの受け手が残っていると、切った直後に突いて取り返していた（2026-11-23）
          this.idle = null;
          this.kicked = true;
          if (!this.scene) this.cuts = (this.cuts || 0) + 1;
          return;
        }
        if (u >= 1) {
          // 届いた：そのまま少し転がる（シュートはネットか、ラインの外へ）
          // 浮き球は弾んで少し遅くなるだけ（急に止まらない）
          // GK が止めた球は手の中で止まる（触った扱い）
          const vEnd = fl.save ? 0.8 : fl.kind === 'ground' ? (fl.vEnd != null ? fl.vEnd : MOVE.passEnd) : fl.kind === 'loft' ? MOVE.loft * 0.72 : MOVE.shot * 0.95;
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
        const tgt = [clamp(p[0] + f[0] * 0.65, Math.min(p[0], 0.3), Math.max(p[0], W - 0.3)), clamp(p[1] + f[1] * 0.65, Math.min(p[1], 0.3), Math.max(p[1], L - 0.3))]; // ライン際では球を外へ出さない
        const k = 1 - Math.exp(-dt * 12);
        const nb = [lerp(this.ball[0], tgt[0], k), lerp(this.ball[1], tgt[1], k), Math.max(0, (this.ball[2] || 0) - dt * 7)];
        this.bv = [(nb[0] - this.ball[0]) / Math.max(dt, 1e-3), (nb[1] - this.ball[1]) / Math.max(dt, 1e-3)];
        this.ball = nb;
        return;
      }
      // 再開の置き直し：ボールを置く所までゆっくり戻す
      if (this.setup && this.setup.spot) {
        const g = this.setup.spot;
        const d = dist(this.ball, g);
        const v = Math.min(2.5, d / Math.max(dt, 1e-3));
        if (d > 0.01) { this.bv = [((g[0] - this.ball[0]) / d) * v, ((g[1] - this.ball[1]) / d) * v]; this.ball = [this.ball[0] + this.bv[0] * dt, this.ball[1] + this.bv[1] * dt, 0]; } else this.bv = [0, 0];
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
      if (this.owner && this.teamOf(this.owner) !== this.teamOf(best)) {
        // 場面で、持っている相手から奪う：足元から突いてこぼし、奪った子の足元へ転がってから持つ（前は持ち主がその場で入れ替わっていた）
        const r = this.disp[best];
        const d = Math.max(0.3, dist(r, b));
        this.lock[this.owner] = 0.9;
        this.lock[best] = 0.18;
        this.owner = null;
        this.bv = [((r[0] - b[0]) / d) * 3, ((r[1] - b[1]) / d) * 3];
        this.lastTouch = this.teamOf(best);
        this.kicked = true;
        return;
      }
      this.owner = best;
      this.lastTouch = this.teamOf(best);
      if (this.setup) this.setup = null;
      this.poss = this.teamOf(best) === this.match.home ? 'home' : 'away';
      if (!this.scene && this.idle && this.idle.recv === best) this.idle = null;
    }

    // ----- 合間：持っている子が運び、味方へつなぐ -----
    idlePlay(dt) {
      const ids = Object.keys(this.base);
      const b = this.ball;
      const out = b[0] < -0.3 || b[0] > W + 0.3 || b[1] < -0.3 || b[1] > L + 0.3; // 拾える範囲（pickup）と同じ線
      if (this.setup && !this.base[this.setup.who]) this.setup = null; // 取りに行く子が交代・退場で抜けた
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
          if (this.teamOf(id) === my || this.base[id][3] === 0) continue;
          const d = dist(this.disp[id], b);
          if (d > MOVE.reach) continue;
          if (!fl.tried[id]) {
            fl.tried[id] = true;
            if (Math.random() < 0.4 * (0.4 + this.shareOf(id) * 1.2) * (1.35 + this.ab01(id, '予測') - this.ab01(fl.by, 'パス') * 2.3)) { // 読みのいい子ほど止め、うまいパスほど通る（2026-11-23：パスのうまさの効きを約2倍に。通る割合の差が数ポイントしかなかった）
              this.lastTouch = this.teamOf(id);
              this.fl = null;
              this.bv = [0, 0];
              this.idle = null;
              this.cuts = (this.cuts || 0) + 1;
              this.kicked = true; // 触った
              return;
            }
          }
          // 止められなくても、体のすぐ近く（0.6m 以内）を通る球には当たる：向きが変わって弱まり、こぼれ球になる
          // （2026-11-22：前は止め損ねると球が体を通り抜けていた）
          if (d < (fl.thread ? 0.5 : 0.8)) { // 1コマで球は 0.2m ほど進むので、少し手前で当てる
            const sp = Math.max(3, fl.v0 ? fl.v0 - MOVE.fric * fl.t : MOVE.passEnd) * 0.45;
            const a0 = Math.atan2(fl.to[1] - fl.from[1], fl.to[0] - fl.from[0]) + (Math.random() < 0.5 ? -1 : 1) * (0.6 + Math.random() * 0.7);
            this.fl = null;
            this.bv = [Math.cos(a0) * sp, Math.sin(a0) * sp];
            this.lastTouch = this.teamOf(id);
            this.idle = null;
            this.lock[id] = 0.25;
            this.kicked = true;
            this.deflects = (this.deflects || 0) + 1; // 点検用
            return;
          }
        }
      }
      if (this.fl) return;
      // タックル：寄せた子が間合いに入って少しすると、突いてボールを奪う（ボールは奪った子の足元へ転がる）
      if (this.owner && this.pressers && this.base[this.owner] && this.base[this.owner][3] !== 0) { // GK からは奪わない
        const q = this.disp[this.owner];
        let near = null;
        for (const id of Object.keys(this.pressers)) if (this.disp[id] && dist(this.disp[id], q) < MOVE.tackle) near = id; // 交代・退場で抜けた子は飛ばす
        if (near) {
          this.duel = this.duel && this.duel.id === near && this.duel.on === this.owner ? this.duel : { id: near, on: this.owner, t: 0 };
          this.duel.t += dt;
          if (this.duel.t > 0.5 && Math.random() < dt * (0.4 + this.tacOf(near).press * 1.2) * (0.4 + this.shareOf(near) * 1.2) * (0.4 + this.ab01(near, 'タックル') * 1.2) * (1.6 - (this.ab01(this.owner, 'ドリブル') + this.ab01(this.owner, 'バランス') + this.ab01(this.owner, '強さ')) / 3 * 1.2)) {
            const r = this.disp[near];
            this.lastTouch = this.teamOf(near);
            const d = Math.max(0.3, dist(r, b));
            this.lock[this.owner] = 0.9;
            this.lock[near] = 0.18; // 突いた球が足元へ転がってから持つ
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
      // パスの失敗：相手の陣の深くほど引っかかる（守りが固まっていて通らない）。パスのうまい子・押している側はミスが少ない
      // 2026-11-22「いきなり相手にパスする」：前は失敗のときに相手の選手を受け手にして足元へ蹴っていた。いまは必ず味方を狙い、
      // 通り道の相手に切られるか、球がそれて相手に拾われる形で失う
      const miss = Math.random() < (0.06 + 0.25 * clamp((depth - 60) / 40, 0, 1)) * clamp(2.8 - this.shareOf(me) * 3.6, 0.3, 2.4) * clamp(2.6 - this.ab01(me, 'パス') * 4, 0.2, 2.4); // 2026-11-23 パスの効きを強めた（うまい子と下手な子の通る割合の差が数ポイントしかなかった。本物は 88% と 75% ほど）。 押している側はミスが少ない（2026-11-22 失い方を切る・それるに変えて流れの差が縮んだので強めた）
      {
        // オフサイドの線：相手の後ろから2人目（GK を含む）。その先にいる味方へは出さない（2026-11-23：1試合0.2回出ていた）
        const offY = ids.filter((o) => this.teamOf(o) !== my && this.disp[o]).map((o) => this.disp[o][1] * atk).sort((u, v) => v - u)[1];
        const half = atk > 0 ? L / 2 : -L / 2;
        const pick = (bk, fr) => ids.filter((id) => {
          if (id === me || this.teamOf(id) !== my) return false;
          const r = this.disp[id];
          if (offY != null && r[1] * atk > offY + 0.2 && r[1] * atk > half && r[1] * atk > q[1] * atk) return false;
          const d = dist(r, q);
          return d > 7 && d < fr && (r[1] - q[1]) * atk > -bk;
        });
        let c = pick(back, far);
        if (!c.length) c = pick(20, 30); // 前に出せる味方がいなければ戻してでもつなぐ
        if (!c.length) c = pick(30, 65); // それでもいなければ大きく蹴る
        // 受け手を比べて選ぶ（2026-11-22「AI に」）：前へ進めるか（速い攻めほど重く）・空いているか・パスの線が切られていないか。
        // 視野の広い子は空きと線をよく見る。判断の高い子ほど良い受け手を選ぶ（低い子は迷って外す）
        const kv = this.ab01(me, '視野');
        const kd = this.ab01(me, '判断');
        const opps = ids.filter((id) => this.teamOf(id) !== my && this.base[id][3] !== 0);
        const wt = c.map((id) => {
          const r = this.disp[id];
          const fwd = 1 + Math.max(0, (r[1] - q[1]) * atk) * Math.max(tc.tempo + (this.surgeOf(me) ? 0.6 : 0) + Math.max(0, this.shareOf(me) - 0.5) * 3, depth < 30 ? 0.9 : 0) * 0.2; // 押している側は前へつなぐ（2026-11-23 1.5→3：押している側が前で戦う差が揺れに負けていた） // 自陣の深くからは前へ逃がす。見どころの前は前へ
          let open = 10;
          let lane = 4;
          for (const o of opps) { open = Math.min(open, dist(this.disp[o], r)); lane = Math.min(lane, segDist(this.disp[o], q, r)); }
          // 相手のほうが先に着く所への球は出さない（判断の低い子だけ、ときどき見落とす）
          const at = [r[0] + (this.vel[id] || [0, 0])[0] * 0.6, r[1] + (this.vel[id] || [0, 0])[1] * 0.6];
          let race = 1;
          for (const o of opps) if (dist(this.disp[o], at) + 2 < dist(r, at) + 1) race = 0.03 + (1 - kd) * 0.25;
          return race * fwd * Math.pow(Math.exp((open / 10) * (0.4 + kv * 0.8) + (lane / 4) * (0.4 + kv * 0.8)), 0.6 + kd * 1.4);
        });
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
      // 失敗のとき：通り道の近く（6m 以内）の相手が先回りして切る。いなければ球がそれる
      let icpt = null;
      if (miss && this.teamOf(tgt) === my) {
        let bd = 7;
        for (const o of ids) {
          if (this.teamOf(o) === my || this.base[o][3] === 0) continue;
          const pt = segPt(this.disp[o], q, to);
          const d = dist(this.disp[o], pt);
          if (d < bd && dist(pt, q) > 3) { bd = d; icpt = { id: o, ip: pt }; }
        }
        if (!icpt) {
          // それる：狙いから横へ 25〜45 度、少し長く
          const ang = (Math.random() < 0.5 ? -1 : 1) * (0.45 + Math.random() * 0.35);
          const vx = to[0] - q[0];
          const vy = to[1] - q[1];
          const k = 1.1 + Math.random() * 0.25;
          to = [clamp(q[0] + (vx * Math.cos(ang) - vy * Math.sin(ang)) * k, 1, W - 1), clamp(q[1] + (vx * Math.sin(ang) + vy * Math.cos(ang)) * k, 1, L - 1), 0];
          this.astray = (this.astray || 0) + 1; // 点検用
        }
      }
      // 通り道に相手の足がある：うまい子ほど浮かせて越える（2026-11-23：うまい子ほど前へ・裏へ出すので、体に当たってこぼれる球が
      // 下手な子より多く、パスのうまさで通る割合がほとんど変わらなかった）。下手な子はそのまま転がして当てられやすい
      if (!miss && this.teamOf(tgt) === my && dist(q, to) > 10) {
        let blk = false;
        for (const o of ids) {
          if (this.teamOf(o) === my || this.base[o][3] === 0 || !this.disp[o]) continue;
          if (segDist(this.disp[o], q, to) < 1.2 && dist(this.disp[o], q) > 2.5 && dist(this.disp[o], to) > 2) blk = true;
        }
        if (blk && Math.random() < clamp((this.ab01(me, 'パス') - 0.3) * 1.8, 0, 0.9)) to = [to[0], to[1], 0.85];
      }
      this.kick(to, tgt, me);
      if (icpt && this.fl) { this.fl.icpt = icpt.id; this.fl.ip = icpt.ip; }
      else if (this.fl && Math.random() < clamp((this.ab01(me, 'パス') - 0.2) * 1.4, 0, 0.9)) this.fl.thread = true; // うまい子の球は足の間を通す（体に当たらない）
      this.idle = { recv: tgt, to };
    }
    // キックオフ：両チームとも自分の陣地に並び、team の最前の子が真ん中で持つ（試合の始め・後半・得点のあと）
    kickoff(team) {
      const m = this.match;
      this.poss = null;
      // 並びはボールの位置で決まるので、先に真ん中へ置く（2026-11-22：網の中の球で並べていて、
      // 決めた側の守りが真ん中の線に押しつけられ、サイドバックと中盤が重なっていた）
      this.ball = [34, L / 2, 0];
      this.owner = null;
      this.fl = null; // 2026-11-23：飛んでいる球（入ったシュート）が残っていると、守る側が落ちる所を見て並んでしまう
      for (const id of Object.keys(this.base)) {
        const q = this.shapePos(id);
        const home = this.teamOf(id) === m.home;
        this.disp[id] = [q[0], home ? Math.min(q[1], L / 2 - 1.5) : Math.max(q[1], L / 2 + 1.5)];
        this.vel[id] = [0, 0];
      }
      const pos = [34, L / 2];
      const dir = team === m.home ? 1 : -1;
      const who = Object.keys(this.base).filter((id) => this.base[id][2] === team && this.base[id][3] !== 0).sort((x, y) => (this.base[y][1] - this.base[x][1]) * dir)[0];
      this.ball = [pos[0], pos[1], 0];
      this.bv = [0, 0];
      this.fl = null;
      this.idle = null;
      this.setup = null;
      if (who) {
        this.disp[who] = [pos[0], pos[1] - dir * 0.6];
        this.owner = who;
        this.lastTouch = team;
        this.poss = team === m.home ? 'home' : 'away';
      }
    }
    // ボールが外に出た：再開。得点ならキックオフ。ゴールラインは最後に触ったのが攻める側ならゴールキック、守る側ならコーナーキック。
    // 横はスローインで、最後に触ったのと逆のチームの近い子が投げる（2026-11-17：前はゴールラインは必ずゴールキック、
    // スローインはどちらのチームでも近い子だった）
    restart() {
      const b = this.ball;
      const m = this.match;
      this.celeb = null;
      this.cut = 0;
      this.bv = [0, 0];
      this.fl = null;
      this.idle = null;
      const goal = Math.abs(b[0] - 34) < 3.7 && ((b[1] < 0 && b[1] > -2.3) || (b[1] > L && b[1] < L + 2.3));
      if (goal) {
        // 得点のあとだけ暗転して並び直す
        this.cut = 0.5;
        this.kickoff(b[1] < 0 ? m.home : m.away); // y=0 側はホームのゴール。決められた側が蹴る
        this.restarts = this.restarts || { gk: 0, ck: 0, throw: 0 };
        return;
      }
      let pos;
      let who = null;
      let kind;
      const outfield = (t) => Object.keys(this.base).filter((id) => this.base[id][2] === t && this.base[id][3] !== 0);
      const nearest = (ids, p) => { let bd = 1e9; let w = null; for (const id of ids) { const d = dist(this.disp[id] || p, p); if (d < bd) { bd = d; w = id; } } return w; };
      if (b[1] < 0 || b[1] > L) {
        const defT = b[1] < 0 ? m.home : m.away; // このゴールラインを守るチーム
        const attT = defT === m.home ? m.away : m.home;
        if (this.lastTouch === defT) {
          // 守る側が出した → 攻める側のコーナーキック
          kind = 'ck';
          pos = [b[0] < 34 ? 0.6 : W - 0.6, b[1] < 0 ? 0.6 : L - 0.6];
          who = nearest(outfield(attT), pos);
        } else {
          kind = 'gk';
          pos = [34, b[1] < 0 ? 6 : L - 6];
          who = Object.keys(this.base).find((id) => this.base[id][2] === defT && this.base[id][3] === 0);
        }
      } else {
        kind = 'throw';
        pos = [clamp(b[0], 0.6, W - 0.6), clamp(b[1], 2, L - 2)];
        const t = this.lastTouch === m.home ? m.away : this.lastTouch === m.away ? m.home : null;
        who = nearest(t ? outfield(t) : Object.keys(this.base).filter((id) => this.base[id][3] !== 0), pos);
      }
      this.restarts = this.restarts || { gk: 0, ck: 0, throw: 0 };
      this.restarts[kind]++;
      this.lastRestart = { kind, team: who ? this.teamOf(who) : null };
      const slide = kind === 'throw' && dist(b, pos) <= 3; // スローインの近い置き直しは、ボールを転がして戻す（ぱっと動かさない）
      if (!slide) {
        if (dist(b, pos) > 0.8) this.cut = 0.25; // ゴールキックなど、ボールを離れた所に置くときは一瞬暗くする（等倍ではボールが飛んで見える）
        this.ball = [pos[0], pos[1], 0];
      }
      if (who) {
        // ボールを置いて蹴る子が取りに走る（早送り）
        this.owner = null;
        this.setup = { who, t: 0, spot: slide ? pos : null };
        this.ff = true; // 点検用：ボールを置き直したコマ
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
        // 運ぶ先はラインの内側 0.9m まで（足元の球は 0.65m 前にあるので、ライン際まで運ぶと球が外へ出ていた）
        const inside = (q) => [clamp(q[0], 0.9, W - 0.9), clamp(q[1], 0.9, L - 0.9)];
        if (this.pre && this.pre.kicked && id === this.pre.h0) return [inside(this.pre.f0.ball), MOVE.dribble];
        if (e && (e.phase === 'dribble' || e.phase === 'reach') && e.kind === 'dribble' && e.kicker === id) return [inside(e.to), MOVE.dribble, true];
        if (e && this.stgt[id] && e.kind !== 'kick') return [inside(this.stgt[id]), MOVE.dribble];
        if (!this.scene) {
          const q = this.disp[id];
          const atk = this.atkDir(id)[1];
          return [[clamp(q[0] + (34 - q[0]) * 0.05, 4, W - 4), clamp(q[1] + atk * 3, 6, L - 6)], 2.8 + this.tacOf(id).tempo * 2.4];
        }
        return [this.disp[id], 0];
      }
      // パスを切る子：通り道の切る所へ
      if (this.fl && this.fl.icpt === id && this.fl.ip) return [this.fl.ip, MOVE.sprint];
      // 次に触る子：ボールの行く先（飛んでいれば落ちる所、転がっていればボール）へ。ラインの外1m より先までは追わない
      if (this.expect === id) {
        if (this.fl) return [[clamp(this.fl.to[0], -1, W + 1), clamp(this.fl.to[1], -1, L + 1)], MOVE.sprint];
        return [[clamp(ball[0], -1, W + 1), clamp(ball[1], -1, L + 1)], MOVE.sprint];
      }
      if (this.pre && this.pre.steal === id && this.owner && this.disp[this.owner]) return [this.disp[this.owner], MOVE.sprint];
      if (this.pre && this.pre.plan && this.pre.plan.u === id && this.pre.plan.pt) return [this.pre.plan.pt, MOVE.sprint * 0.9]; // 相手のパスを読んで通り道へ
      if (this.scene && this.chaser === id) return [[ball[0], ball[1]], MOVE.sprint];
      if (this.scene) {
        // 台本の子：遠ければ台本の位置へ走り、着いたらそのまわりで頭を使って合わせる（前は着くと次に触るまで立ち止まっていた）
        if (this.stgt[id]) return dist(this.stgt[id], this.disp[id] || this.stgt[id]) > 3 ? [this.stgt[id], MOVE.sprint] : this.think(id, this.stgt[id], { tight: true });
        return this.think(id, this.offballPos(id));
      }
      // 合間：パスを受ける子は落ちる所へ。誰も持っていなければ、いちばん近い子が拾いに行く
      if (this.idle && this.idle.recv === id && this.fl) return [[this.fl.to[0], this.fl.to[1]], MOVE.sprint];
      if (this.setup && this.setup.who === id) return [[ball[0], ball[1]], MOVE.sprint];
      if (!this.owner && !this.fl && this.chaser === id) return [[ball[0], ball[1]], MOVE.sprint];
      // プレス：持っている相手へ寄せる（1人目は正面、2人目は内側を切る）。奪いはしない
      const pr = this.pressers && this.pressers[id];
      if (pr) return pr;
      // 裏へ抜ける子・寄る子は少し速く
      return this.think(id, this.offballPos(id));
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
        // 動ける範囲の端（縦 -2.5〜L+2.5・横 -3〜W+3）の手前で止まれる速さまで落とす（端で急に止まると加速の上限を超える。2026-11-17）
        {
          const stopV = (gap) => Math.sqrt(2 * MOVE.acc * mk.acc * Math.max(0, gap)) * 0.9;
          if (des[1] < 0) des[1] = Math.max(des[1], -stopV(p[1] + 2.5)); else des[1] = Math.min(des[1], stopV(L + 2.5 - p[1]));
          if (des[0] < 0) des[0] = Math.max(des[0], -stopV(p[0] + 3)); else des[0] = Math.min(des[0], stopV(W + 3 - p[0]));
        }
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
      // 2026-11-22「急なスピードアップはやめて」：場面の入り・再開の早送りをやめ、いつも等倍で見せる（MOVE.ff は 1）
      const ff = this.scene && this.pre ? (this.pre.set ? MOVE.ff * MOVE.ffSet : MOVE.ff) : this.setup && !this.scene ? MOVE.ff * MOVE.ffSet : 1;
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
      // 交代で入った子は、いまの持ち場から（相手の交代は試合の途中に起きる。2026-11-17）
      for (const id of Object.keys(this.base)) if (!this.disp[id] && Object.keys(this.disp).length) { this.disp[id] = [this.base[id][0], this.base[id][1]]; this.vel[id] = [0, 0]; }
      // 試合の始めと後半の頭はキックオフ（前半に蹴った側の逆が後半に蹴る）
      if (!this._ko1 && !this.scene) { this._ko1 = true; if (m.kickoffSide) this.kickoff(m.kickoffSide === 'away' ? m.away : m.home); }
      if (!this._ko2 && !this.scene && m.halfDone && m.ti > 44 + (m.add1 || 0)) { this._ko2 = true; this.cut = 0.35; this.kickoff(m.kickoffSide === 'away' ? m.home : m.away); }
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
      const fit = Math.min((w - 12) / (L + 6), (h - 4) / (W + 3)); // 余白を詰めてボードを大きく（2026-11-16）
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
        const R = Math.max(8.5, s * 2); // 2026-11-16 画面の点検：iPhone の横向きで丸と背番号が小さかった（7→8.5px以上）
        const order = Object.keys(this.base).sort((a, b) => (this.focus.includes(a) ? 1 : 0) - (this.focus.includes(b) ? 1 : 0));
        const labels = [];
        const sq = this.spread(order, P, R);
        this.sq = sq;
        for (const id of order) {
          const b = this.base[id];
          const t = b[2];
          const p = t.players[id];
          const gk = b[3] === 0;
          const kit = kits ? (t === m.home ? kits.home : kits.away) : { shirt: t.color || '#888', shorts: '#fff', gk: '#f39c12' };
          const fill = gk ? kit.gk : kit.shirt;
          const q = sq[id];
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
          // 名字の札：場面の主役と、ボールを持っている子（2026-11-21「今の形を向上」：番号だけでは誰か分からなかった）
          if (((isF && this.scene) || cb || id === this.owner) && p) labels.push({ q, text: (cb ? '⚽ ' : '') + p.num + ' ' + String(p.name).split(' ')[0].split('・').pop(), gold: cb }); // 外国籍の子は最後の部分
        }
        // ボール（高いほど影から離れて大きく見える）
        const b = this.ball;
        const z = Math.max(0, b[2] || 0);
        let g = P(b[0], b[1]);
        const br = Math.max(5.5, s * 0.9) * (1 + z * 0.06); // 2026-11-21：4px では目で追いにくかった
        // 足元の球は丸の下に隠れるので、進む向きの丸の縁に見せる
        if (this.owner && this.disp[this.owner] && !this.fl) {
          const oq = sq[this.owner] || P(this.disp[this.owner][0], this.disp[this.owner][1]);
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
        ctx.lineWidth = 2;
        ctx.stroke();
        // 黒い五角の模様（白い縁の丸と見分ける）
        ctx.fillStyle = '#1b1b1b';
        ctx.beginPath();
        ctx.arc(bq[0], bq[1], br * 0.38, 0, Math.PI * 2);
        ctx.fill();
        // 名前の札（主役）
        ctx.font = '800 11px system-ui, sans-serif';
        ctx.textBaseline = 'alphabetic';
        const placed = [];
        for (const lb of labels) {
          const tw = ctx.measureText(lb.text).width + 10;
          const x = clamp(lb.q[0] - tw / 2, 2, w - tw - 2);
          let y = clamp(lb.q[1] - R - 22, 2, h - 18);
          // 札どうしが重なるときは丸の下へ
          if (placed.some((o) => x < o[0] + o[2] && o[0] < x + tw && Math.abs(o[1] - y) < 17)) y = clamp(lb.q[1] + R + 5, 2, h - 18);
          placed.push([x, y, tw]);
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
      // 2026-11-21：字が9pxで細く、読みにくかった。字はバーの左に置き、バーを太く
      if (kits && this.flow != null) {
        const bw = Math.min(170, w * 0.3);
        const bx = (w - bw) / 2 + 14;
        const by = 6;
        const bh2 = 9;
        const fh = bw * this.flow;
        // 帯の下（名前の札の高さぶん下まで）に選手かボールがいるときは薄くして、下が見えるようにする（2026-11-23：タッチライン際の子と名前が隠れていた）
        let under = false;
        for (const id of Object.keys(this.disp)) { const q = P(this.disp[id][0], this.disp[id][1]); if (q[0] > bx - 50 && q[0] < bx + bw + 16 && q[1] < by + bh2 + 30) { under = true; break; } }
        { const q = P(this.ball[0], this.ball[1]); if (q[0] > bx - 50 && q[0] < bx + bw + 16 && q[1] < by + bh2 + 20) under = true; }
        const fa = (this._flowA = (this._flowA == null ? 1 : this._flowA) + ((under ? 0.3 : 1) - (this._flowA == null ? 1 : this._flowA)) * 0.2);
        ctx.globalAlpha = fa;
        ctx.fillStyle = 'rgba(10,18,30,.75)';
        this.rr(ctx, bx - 36, by - 4, bw + 40, bh2 + 8, 8);
        ctx.fill();
        ctx.font = '800 11px system-ui, sans-serif';
        ctx.textAlign = 'left';
        ctx.textBaseline = 'middle';
        ctx.fillStyle = '#ffffff';
        ctx.fillText('流れ', bx - 31, by + bh2 / 2 + 0.5);
        ctx.fillStyle = kits.home.shirt;
        ctx.fillRect(bx, by, fh, bh2);
        ctx.fillStyle = kits.away.shirt;
        ctx.fillRect(bx + fh, by, bw - fh, bh2);
        ctx.fillStyle = '#ffffff';
        ctx.fillRect(bx + bw / 2 - 0.75, by - 2, 1.5, bh2 + 4);
        ctx.textBaseline = 'alphabetic';
        ctx.globalAlpha = 1;
      }
      if (m) this.drawSides(ctx, P, kits);
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
    // 重なった丸を描く位置だけずらす（動きと試合の結果は変えない。2026-11-21：真ん中で番号が隠れていた）
    spread(ids, P, R) {
      const q = {};
      for (const id of ids) {
        const d = this.disp[id] || this.base[id];
        q[id] = P(d[0], d[1]);
      }
      const min = R * 1.75;
      for (let it = 0; it < 3; it++) {
        for (let i = 0; i < ids.length; i++) {
          for (let j = i + 1; j < ids.length; j++) {
            const a = q[ids[i]];
            const b = q[ids[j]];
            const dx = b[0] - a[0];
            const dy = b[1] - a[1];
            const dd = Math.hypot(dx, dy);
            if (dd >= min) continue;
            const k = (min - dd) / 2;
            const ux = dd > 0.01 ? dx / dd : 0;
            const uy = dd > 0.01 ? dy / dd : 1;
            q[ids[i]] = [a[0] - ux * k, a[1] - uy * k];
            q[ids[j]] = [b[0] + ux * k, b[1] + uy * k];
          }
        }
      }
      return q;
    }
    // ピッチの左右の空き：左にホーム、右にアウェイの出ている11人（番号・名字・疲れ）。場面の主役は黄色、持っている子は白の縁
    drawSides(ctx, P, kits) {
      const m = this.match;
      const w = this.w;
      const h = this.h;
      const lx = Math.min(P(0, -3)[0], P(0, L + 3)[0]);
      const rx = Math.max(P(0, -3)[0], P(0, L + 3)[0]);
      const room = Math.min(lx, w - rx) - 10;
      this.sideW = room >= 110 ? room : 0;
      if (room < 110) return;
      const pw = Math.min(170, room);
      for (const [t, x0] of [[m.home, (lx - pw) / 2], [m.away, rx + (w - rx - pw) / 2]]) {
        const kit = kits ? (t === m.home ? kits.home : kits.away) : { shirt: t.color || '#888', shorts: '#fff', gk: '#f39c12' };
        const ids = Object.keys(this.base).filter((id) => this.base[id][2] === t).sort((a, b) => this.base[a][3] - this.base[b][3]);
        const rowH = Math.min(21, (h - 40) / Math.max(11, ids.length));
        const y0 = 6;
        ctx.fillStyle = 'rgba(8,16,26,.55)';
        this.rr(ctx, x0, y0, pw, 26 + rowH * ids.length + 4, 9);
        ctx.fill();
        ctx.fillStyle = kit.shirt;
        ctx.beginPath();
        ctx.arc(x0 + 13, y0 + 13, 5.5, 0, Math.PI * 2);
        ctx.fill();
        ctx.font = '800 12px system-ui, sans-serif';
        ctx.textAlign = 'left';
        ctx.textBaseline = 'middle';
        ctx.fillStyle = '#ffffff';
        ctx.fillText(String(t.short || t.name || '').slice(0, 10), x0 + 24, y0 + 13.5);
        ids.forEach((id, i) => {
          const p = t.players[id];
          if (!p) return;
          const y = y0 + 26 + i * rowH;
          const cy2 = y + rowH / 2;
          if (this.focus.includes(id)) {
            ctx.fillStyle = 'rgba(255,225,74,.28)';
            this.rr(ctx, x0 + 3, y + 1, pw - 6, rowH - 2, 5);
            ctx.fill();
          }
          if (id === this.owner) {
            ctx.strokeStyle = 'rgba(255,255,255,.9)';
            ctx.lineWidth = 1.2;
            this.rr(ctx, x0 + 3, y + 1, pw - 6, rowH - 2, 5);
            ctx.stroke();
          }
          const gk = this.base[id][3] === 0;
          const fill = gk ? kit.gk : kit.shirt;
          ctx.fillStyle = fill;
          ctx.beginPath();
          ctx.arc(x0 + 15, cy2, Math.min(8.5, rowH / 2 - 1), 0, Math.PI * 2);
          ctx.fill();
          ctx.font = '800 10.5px system-ui, sans-serif';
          ctx.textAlign = 'center';
          ctx.fillStyle = YA.colorDist && YA.colorDist(fill, '#ffffff') < 140 ? '#1b2438' : '#ffffff';
          ctx.fillText(String(p.num), x0 + 15, cy2 + 0.5);
          ctx.textAlign = 'left';
          ctx.font = '700 11.5px system-ui, sans-serif';
          ctx.fillStyle = '#ffffff';
          const nm = String(p.name).split(' ')[0].split('・').pop();
          const sl = this.base[id][4];
          const pk = sl && YA.pos15OfSlot ? YA.pos15OfSlot(sl, this.base[id][3]) : '';
          const pos = pk ? ((YA.POS_LABEL && YA.POS_LABEL[pk]) || pk) + ' ' : '';
          ctx.fillText(pos + nm, x0 + 28, cy2 + 0.5, pw - 70);
          // 疲れ：残りの体力のバー
          const st = clamp(p.stam == null ? 100 : p.stam, 0, 100);
          const bw = 30;
          const bx = x0 + pw - bw - 8;
          ctx.fillStyle = 'rgba(255,255,255,.18)';
          ctx.fillRect(bx, cy2 - 2.5, bw, 5);
          ctx.fillStyle = st >= 70 ? '#5fd17a' : st >= 45 ? '#f2c94c' : '#eb5757';
          ctx.fillRect(bx, cy2 - 2.5, bw * st / 100, 5);
        });
      }
      ctx.textBaseline = 'alphabetic';
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
