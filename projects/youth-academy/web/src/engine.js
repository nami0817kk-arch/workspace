// 試合の中身（位置と出来事を出す部分）。見せ方には一切依存しない。
// 画面（render.js / ui.js）はここが返す scene を絵にするだけ。あとで本物の3Dや
// 「常に22人が動く」形に育てるときも、ここは作り直さない。
//
// 座標は m（ピッチ 横68×縦105）。attacker frame＝攻める側が +y（相手ゴール y=105）に向かう向き。
// scene.frames は絶対座標（ホーム＝あなたは +y へ攻める）に直してある。
(function () {
  'use strict';
  const YA = (globalThis.YA = globalThis.YA || {});
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const sig = (x) => 1 / (1 + Math.exp(-x));
  const W = 68;
  const L = 105;

  const SCENE_NAMES = {
    through: '裏への抜け出し',
    cross: 'クロスからヘディング',
    dribble: 'ドリブル突破',
    longshot: 'ミドルシュート',
    fk: 'フリーキック',
    ck: 'コーナーキック',
    counter: 'カウンター',
    onetwo: 'ワンツー突破',
    steal: '高い位置での奪取',
    pk: 'PK',
    longthrow: 'ロングスローの混戦',
  };
  YA.SCENE_NAMES = SCENE_NAMES;

  const has = (p, t) => p.traits.indexOf(t) >= 0;
  const pers = (p, g, v) => p.pers[g] === v;
  const anyPers = (p, v) => Object.values(p.pers).indexOf(v) >= 0;

  // 調子・自信・疲れをまとめた補正
  function cond(p, m) {
    let c = 1 + p.form * 0.035 + (p.conf - 50) / 400 - (Math.max(0, 60 - p.stam) / 60) * (anyPers(p, '粘り強い') ? 0.15 : 0.3);
    return clamp(c, 0.6, 1.3);
  }
  const eff = (p, n, m) => p.ab[n] * cond(p, m);
  const effAvg = (p, ns, m) => ns.reduce((a, n) => a + eff(p, n, m), 0) / ns.length;

  function slotPos(i, s) {
    return YA.posOfSlot(s, i);
  }

  class Match {
    constructor(opts) {
      this.rng = YA.rngOf(opts.seed);
      this.home = opts.home; // あなた（+y へ攻める）
      this.away = opts.away;
      this.settings = Object.assign({ autoStop: true }, opts.settings || {});
      this.min = 0;
      this.score = { home: 0, away: 0 };
      this.log = []; // 実況・出来事
      this.scenes = [];
      this.halfDone = false;
      this.finished = false;
      this.pendingStop = null;
      this.userStop = false;
      this.lateDone = false;
      this.shoutLog = {};
      this.stats = { home: { shots: 0, onTarget: 0, scenes: 0 }, away: { shots: 0, onTarget: 0, scenes: 0 } };
      this.notes = []; // 試合後に出す「気づき」
      this.discontent = {}; // 役割が合わず不満が溜まった選手
      for (const t of [this.home, this.away]) {
        for (const p of Object.values(t.players)) {
          p.stam = 100;
          p.st = { goals: 0, assists: 0, shots: 0, rating: 6.0, minutes: 0, saves: 0 };
          p.yellow = 0;
          p.off = false;
          // 気分屋は試合ごとに調子が大きく振れる
          if (pers(p, '感情の波', '気分屋')) p.form = clamp(p.form + this.rng.int(-2, 2), -3, 3);
        }
        t.subsUsed = 0;
        t.windowsUsed = 0;
        t.instr = {};
        t.onPitch = new Set(t.lineup.map((s) => s.pid));
      }
      this.keyMinutes = this._pickMinutes();
    }

    _pickMinutes() {
      const n = 13 + this.rng.int(0, 2);
      const out = [];
      let guard = 0;
      while (out.length < n && guard++ < 500) {
        const m = this.rng.int(3, 89);
        if (out.every((x) => Math.abs(x - m) >= 3) && m !== 45 && m !== 75) out.push(m);
      }
      return out.sort((a, b) => a - b);
    }

    side(t) {
      return t === this.home ? 'home' : 'away';
    }
    other(t) {
      return t === this.home ? this.away : this.home;
    }

    // ---------- 選手の取り出し ----------
    onPitch(t) {
      return t.lineup.map((s, i) => ({ s, i, p: t.players[s.pid], pos: slotPos(i, s) }));
    }
    byPos(t, pos) {
      return this.onPitch(t).filter((x) => x.pos === pos);
    }
    gk(t) {
      return this.byPos(t, 'GK')[0] ? this.byPos(t, 'GK')[0].p : t.players[t.lineup[0].pid];
    }

    // ---------- チームの強さ ----------
    attPower(t) {
      const xs = this.onPitch(t).filter((x) => x.pos === 'FW' || x.pos === 'MF');
      return xs.reduce((a, x) => a + (effAvg(x.p, ['パス', 'ドリブル', 'フィニッシュ', 'スピード', '視野', 'オフザボール'], this) + this.teamBonus(t, x.p)), 0) / Math.max(1, xs.length);
    }
    defPower(t) {
      const xs = this.onPitch(t).filter((x) => x.pos === 'DF' || x.pos === 'MF');
      const g = this.gk(t);
      const d = xs.reduce((a, x) => a + effAvg(x.p, ['タックル', 'マーク', 'ポジショニング', '予測', '運動量'], this), 0) / Math.max(1, xs.length);
      return d * 0.85 + effAvg(g, ['反応', '1対1', 'ハンドリング'], this) * 0.15;
    }
    // リーダーがいるとまとまる／チームワーク
    teamBonus(t, p) {
      let b = 0;
      if (this.onPitch(t).some((x) => pers(x.p, '人との関わり', 'リーダー気質') && x.p !== p)) b += 0.3;
      if (this.onPitch(t).some((x) => has(x.p, '声で味方を動かす') && x.p !== p)) b += 0.3;
      return b;
    }

    // ---------- 効いた特性・性格の記録 ----------
    _fx(sc, p, kind, tag, text) {
      // 守る側の特性・性格は、守備が実際に成功したときだけ札に出す（出来事のあとで flushDef）
      const defTeam = sc.side === 'home' ? this.away : this.home;
      const list = defTeam.players[p.id] ? (sc._pend = sc._pend || []) : sc.fx;
      if (list.some((f) => f.pid === p.id && f.tag === tag)) return;
      list.push({ pid: p.id, num: p.num, name: p.name, kind, tag, text });
    }
    // 性格による補正。戻り値は能力値に足す数
    persMod(sc, t, p, kind) {
      const diff = this.score[this.side(t)] - this.score[this.side(this.other(t))];
      const close = this.min >= 70 && Math.abs(diff) <= 1;
      let b = 0;
      if (close && pers(p, '大舞台', '大舞台に強い')) {
        b += 2;
        this._fx(sc, p, 'pers', '大舞台に強い', '終盤の競った場面で力が出た');
      }
      if (close && pers(p, '大舞台', 'プレッシャーに弱い')) {
        b -= 2;
        this._fx(sc, p, 'pers', 'プレッシャーに弱い', '終盤の競った場面で固くなった');
      }
      if (diff < 0 && pers(p, '気持ちの強さ', '負けず嫌い')) {
        b += 1.5;
        this._fx(sc, p, 'pers', '負けず嫌い', 'リードされて火が付いた');
      }
      if (p.conf < 40 && pers(p, '気持ちの強さ', '繊細')) {
        b -= 1.5;
        this._fx(sc, p, 'pers', '繊細', '自信を失って縮こまった');
      }
      if (kind === 'shot' && p.conf >= 65 && pers(p, 'プレーの気質', '自信家')) {
        b += 1.5;
        this._fx(sc, p, 'pers', '自信家', '自信を持って振り抜いた');
      }
      if (kind === 'duel' && pers(p, 'プレーの気質', '闘争的')) {
        b += 1.5;
        this._fx(sc, p, 'pers', '闘争的', '激しく当たりにいった');
      }
      if (kind === 'duel' && pers(p, 'プレーの気質', '勇敢')) {
        b += 1;
        this._fx(sc, p, 'pers', '勇敢', '恐れず踏み込んだ');
      }
      if (kind === 'defend' && pers(p, 'プレーの気質', '献身的')) {
        b += 1.2;
        this._fx(sc, p, 'pers', '献身的', '最後まで戻って体を張った');
      }
      return b;
    }
    traitBonus(sc, p, trait, amount, text) {
      if (!has(p, trait)) return 0;
      this._fx(sc, p, 'trait', trait, text);
      return amount;
    }
    // 守る側に特性持ちがいれば、その人を使って止める
    defTrait(sc, def, trait, amount, text, pos) {
      const xs = this.onPitch(def).filter((x) => has(x.p, trait) && (!pos || pos.indexOf(x.pos) >= 0));
      if (!xs.length) return { b: 0, p: null };
      const x = xs[0];
      this._fx(sc, x.p, 'trait', trait, text);
      return { b: amount, p: x.p };
    }
    instr(t, p) {
      return t.instr[p.id] || {};
    }

    // 役割が選手に合うか
    roleFit(t, i) {
      const s = t.lineup[i];
      const p = t.players[s.pid];
      const tr = YA.ROLE_TRAITS[s.role] || [];
      const hit = tr.filter((x) => has(p, x)).length;
      if (hit) return 1;
      const abs = YA.ROLE_ABS[s.role];
      if (!abs) return 0;
      const avg = abs.reduce((a, n) => a + p.ab[n], 0) / abs.length;
      return avg < 8.5 ? -1 : 0;
    }
    roleOf(t, p) {
      const i = t.lineup.findIndex((s) => s.pid === p.id);
      return i < 0 ? null : t.lineup[i].role;
    }

    // ---------- 場面の重み ----------
    sceneWeights(att, def) {
      const tc = att.tactic;
      const dt = def.tactic;
      const w = { through: 0.5, cross: 1, dribble: 0.9, longshot: 0.5, fk: 0.35, ck: 0.4, counter: 0.6, onetwo: 0.6, steal: 0.5, longthrow: 0 };
      w.through *= 0.6 + 0.8 * tc.tempo;
      w.counter *= 0.4 + 1.4 * tc.tempo;
      w.onetwo *= 1.4 - 0.8 * tc.tempo;
      w.cross *= 0.5 + 1.0 * tc.width;
      w.dribble *= 0.8 + 0.4 * tc.width;
      w.steal *= 0.3 + 1.4 * tc.press;
      w.through *= 0.75 + 0.7 * dt.line;
      w.counter *= 0.75 + 0.6 * dt.line;
      w.fk *= 0.7 + 0.6 * dt.intensity;
      const on = this.onPitch(att);
      const add = {
        裏への抜け出し: ['through', 0.35], スルーパス: ['through', 0.3], アーリークロス: ['cross', 0.3], オーバーラップ: ['cross', 0.2], カットイン: ['dribble', 0.3], 縦への突破: ['dribble', 0.25],
        弾丸ミドル: ['longshot', 0.5], ワンツー: ['onetwo', 0.35], 直接FK: ['fk', 0.4], 曲がるCK: ['ck', 0.4], 前線からの守備: ['steal', 0.2], 即時奪回: ['steal', 0.2], ロングスロー: ['longthrow', 0.45], ボールを運ぶ: ['counter', 0.15], ヘディングシュート: ['cross', 0.15],
      };
      for (const x of on) {
        for (const t of x.p.traits) if (add[t]) w[add[t][0]] += add[t][1];
        const role = att.lineup[x.i].role;
        const rb = { 上がる: ['cross', 0.3], 裏を狙う: ['through', 0.3], 飛び出す: ['through', 0.2], 配る: ['through', 0.25], 運ぶ: ['dribble', 0.2], ゴール前: ['cross', 0.2], 潰す: ['steal', 0.15], ポスト: ['onetwo', 0.2], 下がって受ける: ['onetwo', 0.2] }[role];
        if (rb) w[rb[0]] += rb[1];
        const ins = this.instr(att, x.p);
        if (ins.dribble) w.dribble += 0.5;
        if (ins.shoot) w.longshot += 0.5;
      }
      // 攻める方向の指定で左右を決める。ここでは重みだけ（左右は場面の中で）
      return w;
    }

    pickAttacker() {
      const h = this.home;
      const a = this.away;
      let d = this.attPower(h) - this.defPower(a) - (this.attPower(a) - this.defPower(h));
      d += (h.tactic.tempo - a.tactic.tempo) * 0.2 + (h.tactic.press - a.tactic.press) * 0.4;
      // 負けているほうが押し込む
      const sc = this.score.home - this.score.away;
      d += -sc * 0.3 * (this.min / 90);
      const pHome = clamp(0.5 + d * 0.055, 0.22, 0.78);
      return this.rng() < pHome ? h : a;
    }

    // 攻撃側の選手を、能力・特性・役割・指示で重み付けして選ぶ
    pickActor(att, positions, abs, traits, exclude, sc, roles) {
      const cands = this.onPitch(att).filter((x) => positions.indexOf(x.pos) >= 0 && !(exclude || []).includes(x.p.id));
      if (!cands.length) return this.onPitch(att).filter((x) => x.pos !== 'GK')[0].p;
      return this.rng.weighted(cands, (x) => {
        let w = Math.pow(effAvg(x.p, abs, this) / 10, 2.2);
        for (const t of traits || []) if (has(x.p, t)) w *= 2.1;
        if (roles && roles.indexOf(att.lineup[x.i].role) >= 0) w *= 1.6;
        const ins = this.instr(att, x.p);
        if (ins.back) w *= 0.2;
        if (ins.dribble && abs.indexOf('ドリブル') >= 0) w *= 2.5;
        if (ins.shoot && abs.indexOf('フィニッシュ') >= 0) w *= 1.8;
        return w;
      }).p;
    }

    // 守備側の「止める人」
    pickDefender(def, side, sc) {
      const ds = this.onPitch(def).filter((x) => x.pos === 'DF');
      const cands = ds.filter((x) => (side === 'L' ? x.s.x < 0.5 : side === 'R' ? x.s.x >= 0.5 : true));
      const xs = cands.length ? cands : ds;
      return this.rng.pick(xs.length ? xs : this.onPitch(def).filter((x) => x.pos !== 'GK')).p;
    }

    markPenalty(att, def, shooter, sc) {
      // 相手に「〇番に付け」と指示されているか
      const ins = def.instr;
      for (const pid of Object.keys(ins)) {
        if (ins[pid].mark === shooter.id && def.onPitch.has(pid)) {
          const m = def.players[pid];
          this._fx(sc, m, 'instr', 'マーク', shooter.num + '番に付いて自由にさせなかった');
          return 2.5;
        }
      }
      return 0;
    }

    // ---------- シュートの判定 ----------
    // q: 打つ人の質、diff: 場面の難しさ、戻り値は {result, ...}
    shot(sc, att, def, shooter, q, diff, kind, opt) {
      const rng = this.rng;
      opt = opt || {};
      const gkp = this.gk(def);
      let gq = effAvg(gkp, ['反応', '1対1', 'ハンドリング', '飛び出し'], this);
      if (opt.oneOnOne) {
        const g = this.traitBonus(sc, gkp, '前に出るGK', 2, '飛び出して間合いを詰めた');
        gq += g;
      }
      if (opt.cross) gq += this.traitBonus(sc, gkp, 'クロスへの強さ', 2, '高いボールに強く出た') + this.traitBonus(sc, gkp, 'パンチング', 1, 'パンチングで逃れた');
      if (opt.fk || opt.pk) gq += 0;
      gq += this.persMod(sc, def, gkp, 'defend') * 0.5;
      const sq = q - diff + this.persMod(sc, att, shooter, 'shot') + this.markPenalty(att, def, shooter, sc) * -1;
      const onP = clamp(0.58 + (sq - 8) * 0.032, 0.25, 0.92);
      att.players[shooter.id].st.shots++;
      this.stats[this.side(att)].shots++;
      // 守備のブロック
      const blk = this.defTrait(sc, def, 'シュートブロック', 0.14, '体を投げ出して止めにいった', ['DF', 'MF']);
      if (!opt.pk && rng() < 0.06 + blk.b + (opt.crowd ? 0.08 : 0)) {
        return { result: 'blocked', blocker: blk.p || this.pickDefender(def, 'C', sc) };
      }
      if (rng() > onP) return { result: rng() < 0.18 ? 'post' : 'missed' };
      this.stats[this.side(att)].onTarget++;
      const saveP = clamp(0.33 + (gq - sq) * 0.04, 0.12, 0.8);
      if (opt.pk) {
        const stop = this.traitBonus(sc, gkp, 'PKストップ', 0.14, 'コースを読んで止めにいった');
        if (rng() < clamp(0.2 + (gq - sq) * 0.015 + stop, 0.08, 0.5)) return { result: 'saved', gk: gkp };
        return { result: 'goal' };
      }
      if (rng() < saveP) return { result: 'saved', gk: gkp };
      return { result: 'goal' };
    }

    // ---------- 場面の組み立て ----------
    makeScene(att, def, type) {
      const rng = this.rng;
      const sc = { id: this.scenes.length + 1, minute: this.min, type, typeName: SCENE_NAMES[type], side: this.side(att), actors: {}, fx: [], beats: [], outcome: 'none', goal: false, dur: 6.4 };
      const f = this['_' + type];
      f.call(this, sc, att, def);
      sc.flip = att === this.away;
      // 絶対座標へ（アウェイは向きを反転）
      if (sc.flip) {
        for (const fr of sc.frames) {
          for (const k of Object.keys(fr.pos)) fr.pos[k] = [W - fr.pos[k][0], L - fr.pos[k][1]];
          fr.ball = [W - fr.ball[0], L - fr.ball[1], fr.ball[2]];
        }
      }
      sc.goal = sc.outcome === 'goal';
      if (['intercepted', 'cleared', 'stopped', 'blocked', 'offside', 'dispossessed', 'escaped'].indexOf(sc.outcome) >= 0 && sc._pend) {
        for (const f of sc._pend.slice(0, 2)) if (!sc.fx.some((x) => x.pid === f.pid && x.tag === f.tag)) sc.fx.push(f);
      }
      delete sc._pend;
      // 画面に出す札：結果を決めたほうの特性・性格を先に、最大3つ
      const defSucc = ['intercepted', 'cleared', 'stopped', 'blocked', 'offside', 'dispossessed', 'escaped'].indexOf(sc.outcome) >= 0;
      const kr = { trait: 0, instr: 1, pers: 2 };
      sc.fxShow = sc.fx
        .filter((f) => sc.outcome !== 'offside' || f.tag === 'ラインコントロール' || !def.players[f.pid])
        .slice()
        .sort((a, b) => ((att.players[a.pid] ? 1 : 0) - (att.players[b.pid] ? 1 : 0)) * (defSucc ? 1 : -1) || kr[a.kind] - kr[b.kind])
        .slice(0, 3);
      return sc;
    }

    // 並びの位置（attacker frame）
    pos(t, p, dy) {
      const i = t.lineup.findIndex((s) => s.pid === p.id);
      const s = t.lineup[i];
      return [s.x * W, 4 + s.y * 78 + (dy || 0)];
    }
    defLineY(def) {
      return 80 - def.tactic.line * 18;
    }

    finish(sc, att, def, res, shooter, assist, x, goalX) {
      // 結果を記録して、最後のコマと実況を作る
      const r = res.result;
      const gx = goalX != null ? goalX : 34 + (this.rng() - 0.5) * 8;
      sc.outcome = r;
      sc.shooter = shooter ? shooter.id : null;
      if (r === 'goal') {
        att.players[shooter.id].st.goals++;
        att.players[shooter.id].st.rating += 1.2;
        if (assist && assist !== shooter) {
          att.players[assist.id].st.assists++;
          att.players[assist.id].st.rating += 0.6;
        }
        this.score[this.side(att)]++;
        this.gkOf(def).st.rating -= 0.3;
        sc.scorer = shooter.id;
        sc.assist = assist && assist !== shooter ? assist.id : null;
        for (const pl of Object.values(def.players)) if (def.onPitch.has(pl.id)) pl.conf = clamp(pl.conf - 1.5, 0, 100);
        for (const pl of Object.values(att.players)) if (att.onPitch.has(pl.id)) pl.conf = clamp(pl.conf + 2, 0, 100);
        // 失点した側の性格の反応
        for (const pl of Object.values(def.players)) {
          if (!def.onPitch.has(pl.id)) continue;
          if (pers(pl, '気持ちの強さ', '繊細')) pl.conf = clamp(pl.conf - 2, 0, 100);
          if (pers(pl, '気持ちの強さ', '負けず嫌い')) pl.form = clamp(pl.form + 0.5, -3, 3);
        }
      } else if (r === 'saved') {
        res.gk.st.saves++;
        res.gk.st.rating += 0.5;
        if (shooter) att.players[shooter.id].conf = clamp(att.players[shooter.id].conf - 1, 0, 100);
      } else if (r === 'missed' || r === 'post') {
        if (shooter) {
          const s = att.players[shooter.id];
          s.st.rating -= 0.2;
          s.conf = clamp(s.conf - (pers(s, '気持ちの強さ', '繊細') ? 4 : 1.5), 0, 100);
          if (pers(s, '気持ちの強さ', '負けず嫌い')) s.conf = clamp(s.conf + 2.5, 0, 100);
        }
      } else if (r === 'blocked' && res.blocker) {
        res.blocker.st.rating += 0.4;
      }
      sc.gk = this.gk(def).id;
    }
    gkOf(t) {
      return this.gk(t);
    }

    // 最後の数コマ：シュートからの結末
    endFrames(sc, res, shooterPos, gkPid, gkPos, t0, goalX) {
      const gx = goalX != null ? goalX : 34 + (this.rng() - 0.5) * 7;
      const r = res.result;
      const fr = [];
      const gkx = clamp(gx + (this.rng() - 0.5) * 8, 28, 40);
      if (r === 'goal') {
        fr.push({ t: t0, pos: { [gkPid]: [gkx, 102] }, ball: [gx, 105.4, 1.0], cap: 'ゴール' });
        fr.push({ t: t0 + 0.8, pos: { [gkPid]: [gkx, 103] }, ball: [gx, 106.2, 0.4] });
      } else if (r === 'saved') {
        fr.push({ t: t0, pos: { [gkPid]: [clamp(gx, 29, 39), 103] }, ball: [clamp(gx, 29, 39), 103, 0.9] });
        fr.push({ t: t0 + 0.8, pos: { [gkPid]: [clamp(gx, 29, 39), 103] }, ball: [clamp(gx, 29, 39), 103.5, 0.5] });
      } else if (r === 'post') {
        fr.push({ t: t0, pos: { [gkPid]: [gkx, 102] }, ball: [37.4, 105.2, 1.0] });
        fr.push({ t: t0 + 0.8, pos: { [gkPid]: [gkx, 102] }, ball: [38.5, 100, 0.2] });
      } else if (r === 'blocked') {
        fr.push({ t: t0 - 0.2, pos: {}, ball: [shooterPos[0] + 1, shooterPos[1] + 3, 0.6] });
        fr.push({ t: t0 + 0.4, pos: {}, ball: [shooterPos[0] + (this.rng() - 0.5) * 8, shooterPos[1] - 4, 0.3] });
        fr.push({ t: t0 + 0.9, pos: {}, ball: [shooterPos[0] + (this.rng() - 0.5) * 10, shooterPos[1] - 8, 0.0] });
      } else {
        fr.push({ t: t0, pos: { [gkPid]: [gkx, 102] }, ball: [gx + (this.rng() < 0.5 ? 11 : -11), 107.5, 2.5] });
        fr.push({ t: t0 + 0.8, pos: {}, ball: [gx + (this.rng() < 0.5 ? 12 : -12), 112, 0.2] });
      }
      return fr;
    }

    result_text(att, sc, res, shooter) {
      const n = shooter ? shooter.name : '';
      const nm = shooter ? shooter.num + '番 ' + n.split(' ')[0] : '';
      switch (res.result) {
        case 'goal':
          return nm + ' ゴール！';
        case 'saved':
          return nm + 'のシュートは ' + res.gk.name.split(' ')[0] + ' がセーブ';
        case 'post':
          return nm + 'のシュートは枠に当たった！';
        case 'blocked':
          return nm + 'のシュートは ' + res.blocker.name.split(' ')[0] + ' がブロック';
        default:
          return nm + 'のシュートは枠の外';
      }
    }

    // ===== 場面ごとの組み立て =====
    // 裏への抜け出し
    _through(sc, att, def) {
      const rng = this.rng;
      const passer = this.pickActor(att, ['MF', 'FW'], ['パス', '視野', 'テクニック'], ['スルーパス', 'ひらめき'], [], sc, ['配る']);
      const runner = this.pickActor(att, ['FW', 'MF'], ['オフザボール', '加速', 'スピード'], ['裏への抜け出し'], [passer.id], sc, ['裏を狙う', '飛び出す']);
      const dl = this.defLineY(def);
      const d1 = this.pickDefender(def, 'L', sc);
      const d2 = this.pickDefender(def, 'R', sc);
      sc.actors = { passer: passer.id, runner: runner.id };
      sc.defs = [d1.id, d2.id];
      let P = effAvg(passer, ['パス', '視野', 'テクニック'], this) + this.traitBonus(sc, passer, 'スルーパス', 3, '一瞬の隙間を見つけて通した') + this.traitBonus(sc, passer, 'ひらめき', 1.5, '誰も予想しないパスを出した');
      P += this.persMod(sc, att, passer, 'pass');
      let R = effAvg(runner, ['オフザボール', '加速', 'スピード'], this) + this.traitBonus(sc, runner, '裏への抜け出し', 3.5, '最終ラインの背中を取った');
      R += this.persMod(sc, att, runner, 'duel');
      const rr = this.roleOf(att, runner);
      let D = (effAvg(d1, ['ポジショニング', '予測', 'スピード'], this) + effAvg(d2, ['ポジショニング', '予測', 'スピード'], this)) / 2 - (def.tactic.line - 0.5) * 4;
      const lc = this.defTrait(sc, def, 'ラインコントロール', 2.5, 'ラインを揃えて網を張った', ['DF']);
      D += lc.b;
      const cov = this.defTrait(sc, def, 'カバーリング', 2, '後ろからカバーに走った', ['DF']);
      D += cov.b;
      const x = clamp(this.pos(att, runner)[0] + (rng() - 0.5) * 14, 12, 56);
      const px = clamp(this.pos(att, passer)[0] + (rng() - 0.5) * 8, 14, 54);
      const gkp = this.gk(def);
      const base = (extra) => [
        { t: 0, pos: { [passer.id]: [px, 50], [runner.id]: [x, dl - 1.5], [d1.id]: [x - 6, dl], [d2.id]: [x + 6, dl] }, ball: [px, 50.5, 0] },
        { t: 0.9, pos: { [passer.id]: [px, 52], [runner.id]: [x, dl + 3], [d1.id]: [x - 6, dl - 0.5], [d2.id]: [x + 6, dl - 0.5] }, ball: [px, 51, 0.1], cap: passer.num + '番 スルーパス' },
      ].concat(extra);
      // offside
      const offP = clamp(0.13 - (R - D) / 45 + (def.tactic.line - 0.5) * 0.12 + (lc.b ? 0.1 : 0) - (has(runner, '裏への抜け出し') ? 0.07 : 0), 0.03, 0.5);
      if (rng() < offP) {
        sc.frames = base([
          { t: 1.9, pos: { [runner.id]: [x, dl + 5], [d1.id]: [x - 6, dl - 0.5], [d2.id]: [x + 6, dl - 0.5], [passer.id]: [px, 52] }, ball: [x, dl + 9, 1.5] },
          { t: 3.0, pos: { [runner.id]: [x, dl + 8] }, ball: [x, dl + 8, 0], cap: 'オフサイド' },
        ]);
        sc.outcome = 'offside';
        sc.beats = [{ at: 0.1, text: passer.num + '番 ' + passer.name.split(' ')[0] + ' がスルーパスを狙う' }, { at: 2.1, text: runner.num + '番 ' + runner.name.split(' ')[0] + ' が抜け出す…が、旗が上がった。オフサイド' }];
        sc.dur = 4;
        return;
      }
      if (rng() > sig(((P + R) / 2 - D - 1.5) * 0.28) * 0.95 + 0.04) {
        const who = cov.p || lc.p || d1;
        sc.frames = base([
          { t: 1.8, pos: { [runner.id]: [x, dl + 6], [who.id]: [x + 1, dl + 5], [d1.id]: [x - 5, dl + 2], [d2.id]: [x + 6, dl + 1] }, ball: [x, dl + 9, 1.2] },
          { t: 2.6, pos: { [who.id]: [x + 1, dl + 8] }, ball: [x + 2, dl + 7.5, 0], cap: who.name.split(' ')[0] + ' が先に触った' },
        ]);
        sc.outcome = 'intercepted';
        who.st.rating += 0.4;
        sc.beats = [{ at: 0.1, text: passer.num + '番 ' + passer.name.split(' ')[0] + ' がスルーパス' }, { at: 2.0, text: '…守備がうまく処理した（' + who.name.split(' ')[0] + '）' }];
        sc.dur = 4.6;
        return;
      }
      // 抜け出して1対1
      const Fq = effAvg(runner, ['フィニッシュ', '冷静さ', '判断'], this) + (rr === 'ゴール前' ? 1 : 0);
      const loop = this.traitBonus(sc, runner, 'ループシュート', 1.5, '前に出たGKの頭上を狙った');
      const res = this.shot(sc, att, def, runner, Fq + loop, 1.5, 'through', { oneOnOne: true });
      this.finish(sc, att, def, res, runner, passer);
      const gx = res.result === 'goal' ? (rng() < 0.5 ? 30.5 : 37.5) : 34;
      sc.frames = base([
        { t: 1.8, pos: { [runner.id]: [x, dl + 9], [d1.id]: [x - 5, dl + 3], [d2.id]: [x + 5, dl + 3] }, ball: [x, dl + 12, 1.6] },
        { t: 2.7, pos: { [runner.id]: [x * 0.7 + 34 * 0.3, 92], [gkp.id]: [34, 98], [d1.id]: [x - 4, 80], [d2.id]: [x + 4, 80] }, ball: [x * 0.7 + 34 * 0.3, 93, 0], cap: runner.num + '番 独走' },
        { t: 3.4, pos: { [runner.id]: [x * 0.6 + 34 * 0.4, 95], [gkp.id]: [34, 100] }, ball: [x * 0.6 + 34 * 0.4, 96, 0.2], cap: 'シュート' },
      ].concat(this.endFrames(sc, res, [x * 0.6 + 34 * 0.4, 95], gkp.id, null, 3.9, gx)));
      sc.beats = [
        { at: 0.1, text: passer.num + '番 ' + passer.name.split(' ')[0] + ' が前を向く' },
        { at: 1.2, text: runner.num + '番 ' + runner.name.split(' ')[0] + ' が最終ラインの裏へ！' },
        { at: 3.1, text: '1対1！' },
        { at: 4.2, text: this.result_text(att, sc, res, runner) },
      ];
      sc.dur = 6;
    }

    // クロスからヘディング
    _cross(sc, att, def) {
      const rng = this.rng;
      const left = rng() < 0.5 - (att.tactic.dir || 0) * 0.3;
      const crosser = this.pickActor(att, ['DF', 'MF', 'FW'], ['クロス', 'ドリブル', 'スタミナ'], ['アーリークロス', 'オーバーラップ'], [], sc, ['上がる']);
      const header = this.pickActor(att, ['FW', 'MF', 'DF'], ['ヘディング', 'ジャンプ', 'ポジショニング'], ['ヘディングシュート', 'ニアへの飛び込み'], [crosser.id], sc, ['ゴール前']);
      const dEnd = this.pickDefender(def, 'C', sc);
      sc.actors = { crosser: crosser.id, header: header.id };
      sc.defs = [dEnd.id];
      const early = has(crosser, 'アーリークロス');
      let C = effAvg(crosser, ['クロス', 'テクニック', 'ファーストタッチ'], this) + this.traitBonus(sc, crosser, 'アーリークロス', 2.5, '早いタイミングでゴール前に送った') + this.traitBonus(sc, crosser, 'オーバーラップ', 1.5, '外を駆け上がって深くえぐった');
      C += this.persMod(sc, att, crosser, 'pass');
      let H = effAvg(header, ['ヘディング', 'ジャンプ', 'ポジショニング', '強さ'], this) + this.traitBonus(sc, header, 'ヘディングシュート', 3, '競り勝って叩きつけた') + this.traitBonus(sc, header, 'ニアへの飛び込み', 2, 'ニアに飛び込んだ');
      H += (header.height - 178) * 0.12 + this.persMod(sc, att, header, 'duel');
      const aer = this.defTrait(sc, def, '空中戦の競り', 2.5, '体をぶつけて競り合った', ['DF']);
      let D = effAvg(dEnd, ['ヘディング', 'ジャンプ', 'ポジショニング', '強さ'], this) + aer.b + (dEnd.height - 178) * 0.12 + this.persMod(sc, def, dEnd, 'duel');
      const fx = left ? 4 : 64;
      const hx = 34 + (rng() - 0.5) * 6;
      const gkp = this.gk(def);
      const mk = (end) => [
        { t: 0, pos: { [crosser.id]: [fx, 74], [header.id]: [34 + (rng() - 0.5) * 8, 88], [dEnd.id]: [33, 90] }, ball: [fx + (left ? 1 : -1), 74.5, 0] },
        { t: 0.8, pos: { [crosser.id]: [fx, 82], [header.id]: [hx + 3, 92], [dEnd.id]: [hx - 2, 94] }, ball: [fx + (left ? 1 : -1), 83, 0], cap: crosser.num + '番 クロス' },
        { t: 1.8, pos: { [header.id]: [hx, 96], [dEnd.id]: [hx - 1.4, 96] }, ball: [hx, 97, 3.4], cap: '空中戦' },
      ].concat(end);
      if (rng() > sig((C * 0.3 + H * 0.7 - D) * 0.22 - 0.2) * 0.92 + 0.04) {
        const cl = rng() < 0.5;
        sc.frames = mk([{ t: 2.5, pos: { [dEnd.id]: [hx - 1, 96] }, ball: [hx + 2, 100, 3.2] }, { t: 3.4, pos: { [dEnd.id]: [hx - 2, 94] }, ball: [hx + 6, 88, 0.2], cap: '跳ね返された' }]);
        sc.outcome = 'cleared';
        dEnd.st.rating += 0.4;
        sc.beats = [{ at: 0.1, text: crosser.num + '番 ' + crosser.name.split(' ')[0] + ' が' + (left ? '左' : '右') + 'から上げる' }, { at: 2.2, text: dEnd.name.split(' ')[0] + ' がヘディングで跳ね返した' }];
        sc.dur = 4.6;
        return;
      }
      const res = this.shot(sc, att, def, header, effAvg(header, ['ヘディング', 'フィニッシュ', '冷静さ'], this) + this.traitBonus(sc, header, 'ヘディングシュート', 2, '競り勝って叩きつけた') + (header.height - 178) * 0.1, 1.5, 'head', { cross: true, crowd: true });
      this.finish(sc, att, def, res, header, crosser);
      sc.frames = mk(this.endFrames(sc, res, [hx, 96], gkp.id, null, 2.6, hx > 34 ? 36.5 : 31.5));
      sc.beats = [
        { at: 0.1, text: crosser.num + '番 ' + crosser.name.split(' ')[0] + ' が' + (left ? '左' : '右') + 'サイドから' + (early ? '早めに' : '') + 'クロス' },
        { at: 1.7, text: header.num + '番 ' + header.name.split(' ')[0] + ' が飛び込む！' },
        { at: 3.2, text: this.result_text(att, sc, res, header) },
      ];
      sc.dur = 5.4;
    }

    // ドリブル突破（カットイン／縦への突破）
    _dribble(sc, att, def) {
      const rng = this.rng;
      const d = this.pickActor(att, ['FW', 'MF'], ['ドリブル', 'テクニック', 'スピード', 'バランス'], ['カットイン', '縦への突破'], [], sc, ['運ぶ']);
      const left = this.pos(att, d)[0] < 34;
      const df = this.pickDefender(def, left ? 'L' : 'R', sc);
      sc.actors = { dribbler: d.id };
      sc.defs = [df.id];
      const cut = has(d, 'カットイン') && (!has(d, '縦への突破') || rng() < 0.55);
      let Q = effAvg(d, ['ドリブル', 'テクニック', '敏しょう性', 'バランス'], this);
      Q += cut ? this.traitBonus(sc, d, 'カットイン', 3, '中へ切れ込んだ') : this.traitBonus(sc, d, '縦への突破', 3, '縦に仕掛けて抜き去った');
      Q += this.persMod(sc, att, d, 'duel') + (this.instr(att, d).dribble ? 1.2 : 0);
      if (this.instr(att, d).dribble) this._fx(sc, d, 'instr', '仕掛けろ', '指示どおり1対1を仕掛けた');
      Q += this.markPenalty(att, def, d, sc) * -1;
      const pr = this.defTrait(sc, def, '1対1の粘り', 2.5, '足を出させず粘り強く対応した', ['DF', 'MF']);
      let D = effAvg(df, ['タックル', 'マーク', '敏しょう性', '予測'], this) + pr.b + this.persMod(sc, def, df, 'defend');
      const sx = left ? 8 : 60;
      const ix = left ? 24 : 44;
      const gkp = this.gk(def);
      const mk = (end) => [
        { t: 0, pos: { [d.id]: [sx, 62], [df.id]: [sx + (left ? 5 : -5), 70] }, ball: [sx, 62.5, 0] },
        { t: 1.0, pos: { [d.id]: [sx + (left ? 2 : -2), 72], [df.id]: [sx + (left ? 4 : -4), 74] }, ball: [sx + (left ? 2 : -2), 72.5, 0], cap: d.num + '番 仕掛ける' },
        { t: 1.7, pos: { [d.id]: [cut ? ix : sx, cut ? 77 : 82], [df.id]: [sx + (left ? 5 : -5), cut ? 80 : 79] }, ball: [cut ? ix : sx, cut ? 77.5 : 82.5, 0] },
      ].concat(end);
      const fouled = rng() < 0.1 + (anyPers(d, 'ずる賢い') ? 0.06 : 0) + (has(d, 'ファウルをもらう') ? 0.1 : 0);
      if (rng() > sig((Q - D - 0.5) * 0.3) * 0.92 + 0.04) {
        const pnl = df.pers['感情の波'] === '短気' && rng() < 0.3;
        sc.frames = mk([{ t: 2.4, pos: { [d.id]: [cut ? ix : sx, 78], [df.id]: [cut ? ix + 1 : sx, 78] }, ball: [cut ? ix + 3 : sx, 76, 0.3], cap: df.name.split(' ')[0] + ' が止めた' }]);
        sc.outcome = 'dispossessed';
        df.st.rating += 0.4;
        d.conf = clamp(d.conf - 1, 0, 100);
        sc.beats = [{ at: 0.1, text: d.num + '番 ' + d.name.split(' ')[0] + ' が' + (left ? '左' : '右') + 'で持つ' }, { at: 1.6, text: '仕掛けた！しかし ' + df.name.split(' ')[0] + ' が体を寄せて奪った' }];
        sc.dur = 4.4;
        return;
      }
      if (fouled && !cut) {
        // ペナルティエリア内で倒された
        this._fx(sc, d, d.traits.indexOf('ファウルをもらう') >= 0 ? 'trait' : 'pers', d.traits.indexOf('ファウルをもらう') >= 0 ? 'ファウルをもらう' : 'ずる賢い', '体を入れてファウルを誘った');
        const k = this.pickActor(att, ['MF', 'FW'], ['PK', 'フィニッシュ', '冷静さ'], [], [], sc);
        const res = this.shot(sc, att, def, k, effAvg(k, ['PK', '冷静さ', 'フィニッシュ'], this), 0, 'pk', { pk: true });
        sc.actors.kicker = k.id;
        this.finish(sc, att, def, res, k, null);
        const gx = res.result === 'goal' ? (rng() < 0.5 ? 31 : 37) : 34;
        sc.frames = mk([{ t: 2.4, pos: { [d.id]: [sx + (left ? 6 : -6), 90], [df.id]: [sx + (left ? 7 : -7), 91] }, ball: [sx + (left ? 6 : -6), 90, 0], cap: 'ファウル！PK' }, { t: 3.4, pos: { [k.id]: [34, 90], [gkp.id]: [34, 104.5] }, ball: [34, 94, 0], cap: k.num + '番がPKを蹴る' }].concat(this.endFrames(sc, res, [34, 94], gkp.id, null, 4.2, gx)));
        sc.type = 'pk';
        sc.typeName = SCENE_NAMES.pk;
        sc.beats = [{ at: 0.1, text: d.num + '番 ' + d.name.split(' ')[0] + ' が仕掛ける' }, { at: 2.2, text: 'エリア内で倒された！PK' }, { at: 3.6, text: k.num + '番 ' + k.name.split(' ')[0] + ' が蹴る' }, { at: 4.8, text: this.result_text(att, sc, res, k) }];
        sc.dur = 6.4;
        return;
      }
      const sq = effAvg(d, ['フィニッシュ', 'テクニック', '冷静さ'], this) + (cut ? this.traitBonus(sc, d, '巻いて流し込むシュート', 3, 'ファーサイドへ巻いて流し込んだ') : 0) + (cut && d.traits.indexOf('逆足') >= 0 ? 0 : 0) + (cut ? (d.ab['逆足の精度'] - 10) * 0.15 : 0);
      const res = this.shot(sc, att, def, d, sq, cut ? 0.5 : 1.8, 'dribble', {});
      this.finish(sc, att, def, res, d, null);
      const px = cut ? ix : sx;
      const gx = res.result === 'goal' ? (left ? 38 : 30) : 34;
      sc.frames = mk([
        { t: 2.3, pos: { [d.id]: [cut ? ix + (left ? 4 : -4) : sx + (left ? 4 : -4), cut ? 86 : 88], [df.id]: [px, 80], [gkp.id]: [34, 101] }, ball: [cut ? ix + (left ? 4 : -4) : sx + (left ? 4 : -4), cut ? 86.5 : 88.5, 0], cap: cut ? 'カットイン' : '縦へ抜けた' },
      ].concat(this.endFrames(sc, res, [px, 86], gkp.id, null, 3.0, gx)));
      sc.beats = [
        { at: 0.1, text: d.num + '番 ' + d.name.split(' ')[0] + ' が' + (left ? '左' : '右') + 'サイドで持つ' },
        { at: 1.4, text: (cut ? '中へカットイン！' : '縦に仕掛けて抜いた！') },
        { at: 3.1, text: this.result_text(att, sc, res, d) },
      ];
      sc.dur = 5.4;
    }

    // ミドルシュート
    _longshot(sc, att, def) {
      const rng = this.rng;
      const s = this.pickActor(att, ['MF', 'FW', 'DF'], ['ロングシュート', 'フィニッシュ', 'テクニック'], ['弾丸ミドル'], [], sc);
      const gkp = this.gk(def);
      sc.actors = { shooter: s.id };
      let q = effAvg(s, ['ロングシュート', 'テクニック', '冷静さ'], this) + this.traitBonus(sc, s, '弾丸ミドル', 3.5, '迷わず振り抜いた弾丸ミドル');
      if (this.instr(att, s).shoot) {
        q += 1;
        this._fx(sc, s, 'instr', 'シュートを打て', '指示どおり積極的に打った');
      }
      const res = this.shot(sc, att, def, s, q, 3.5, 'long', {});
      this.finish(sc, att, def, res, s, null);
      const x0 = clamp(this.pos(att, s)[0] + (rng() - 0.5) * 10, 18, 50);
      const gx = res.result === 'goal' ? (rng() < 0.5 ? 30 : 38) : 34;
      sc.frames = [
        { t: 0, pos: { [s.id]: [x0 - 6, 70] }, ball: [x0 - 6, 70.5, 0] },
        { t: 0.9, pos: { [s.id]: [x0, 76] }, ball: [x0, 76.5, 0.1], cap: s.num + '番 持ち出す' },
        { t: 1.5, pos: { [s.id]: [x0, 77.5], [gkp.id]: [34, 101] }, ball: [x0, 77.8, 0], cap: 'ミドルシュート' },
      ].concat(this.endFrames(sc, res, [x0, 77.5], gkp.id, null, 2.5, gx));
      sc.beats = [{ at: 0.1, text: s.num + '番 ' + s.name.split(' ')[0] + ' がボールを持つ' }, { at: 1.4, text: '距離はあるが…打った！' }, { at: 2.9, text: this.result_text(att, sc, res, s) }];
      sc.dur = 4.8;
    }

    // フリーキック
    _fk(sc, att, def) {
      const rng = this.rng;
      const k = this.pickActor(att, ['MF', 'FW', 'DF'], ['プレースキック', 'テクニック', 'フィニッシュ'], ['直接FK'], [], sc);
      const gkp = this.gk(def);
      const kx = 34 + (rng() - 0.5) * 16;
      sc.actors = { kicker: k.id };
      const wall = this.onPitch(def).filter((x) => x.pos === 'DF' || x.pos === 'MF').slice(0, 4).map((x) => x.p.id);
      let q = effAvg(k, ['プレースキック', 'テクニック', 'フィニッシュ'], this) + this.traitBonus(sc, k, '直接FK', 4, '壁を越えて曲げた直接FK') + this.persMod(sc, att, k, 'shot');
      const res = this.shot(sc, att, def, k, q, 3.2, 'fk', { fk: true });
      this.finish(sc, att, def, res, k, null);
      const wallPos = {};
      wall.forEach((id, i) => (wallPos[id] = [kx + (i - 1.5) * 1.4 + (34 - kx) * 0.35, 90]));
      const gx = res.result === 'goal' ? (kx > 34 ? 30.6 : 37.4) : 34;
      sc.frames = [
        { t: 0, pos: Object.assign({ [k.id]: [kx - 3, 76] }, wallPos), ball: [kx, 80, 0] },
        { t: 1.2, pos: Object.assign({ [k.id]: [kx - 2, 78.5] }, wallPos), ball: [kx, 80, 0], cap: k.num + '番 直接FK' },
        { t: 1.8, pos: Object.assign({ [k.id]: [kx, 79.5], [gkp.id]: [34, 102] }, wallPos), ball: [kx, 80, 0] },
      ].concat(this.endFrames(sc, res, [kx, 80], gkp.id, null, 2.6, gx));
      sc.beats = [{ at: 0.1, text: 'ゴール正面でFKのチャンス' }, { at: 1.3, text: k.num + '番 ' + k.name.split(' ')[0] + ' が蹴る！' }, { at: 3.0, text: this.result_text(att, sc, res, k) }];
      sc.dur = 5;
    }

    // コーナーキック
    _ck(sc, att, def) {
      const rng = this.rng;
      const k = this.pickActor(att, ['MF', 'FW', 'DF'], ['プレースキック', 'クロス', 'テクニック'], ['曲がるCK'], [], sc);
      const h = this.pickActor(att, ['DF', 'FW', 'MF'], ['ヘディング', 'ジャンプ', '強さ'], ['ヘディングシュート', '空中戦の競り'], [k.id], sc);
      const dd = this.pickDefender(def, 'C', sc);
      const gkp = this.gk(def);
      sc.actors = { kicker: k.id, header: h.id };
      sc.defs = [dd.id];
      const right = rng() < 0.5;
      const cx = right ? 68 : 0;
      let K = effAvg(k, ['プレースキック', 'クロス', 'テクニック'], this) + this.traitBonus(sc, k, '曲がるCK', 3, '狙いすました曲がるボールを送った');
      let H = effAvg(h, ['ヘディング', 'ジャンプ', '強さ', 'ポジショニング'], this) + this.traitBonus(sc, h, 'ヘディングシュート', 2.5, '高い打点で合わせた') + this.traitBonus(sc, h, '空中戦の競り', 2, 'ぶつかり合いに競り勝った') + (h.height - 178) * 0.12;
      const aer = this.defTrait(sc, def, '空中戦の競り', 2.5, '体を当てて競り合った', ['DF']);
      let D = effAvg(dd, ['ヘディング', 'ジャンプ', '強さ', 'マーク'], this) + aer.b + (dd.height - 178) * 0.12 + 1;
      const hx = 34 + (rng() - 0.5) * 8;
      const mk = (end) => [
        { t: 0, pos: { [k.id]: [cx + (right ? -1 : 1), 104], [h.id]: [hx + 2, 97], [dd.id]: [hx, 98] }, ball: [cx, 105, 0] },
        { t: 1.2, pos: { [k.id]: [cx + (right ? -1 : 1), 104.2], [h.id]: [hx + 1, 97.5], [dd.id]: [hx - 0.5, 98] }, ball: [cx, 105, 0], cap: k.num + '番 コーナーキック' },
        { t: 2.3, pos: { [h.id]: [hx, 98], [dd.id]: [hx - 1.2, 98] }, ball: [hx, 98.2, 3.4], cap: '競り合い' },
      ].concat(end);
      if (rng() > sig(((K * 0.35 + H * 0.65) - D) * 0.22 - 0.1) * 0.9 + 0.04) {
        sc.frames = mk([{ t: 3.2, pos: { [dd.id]: [hx - 1, 98] }, ball: [hx - 5, 90, 2.4], cap: 'クリアされた' }, { t: 4.0, pos: {}, ball: [hx - 8, 80, 0.1] }]);
        sc.outcome = 'cleared';
        dd.st.rating += 0.3;
        sc.beats = [{ at: 0.1, text: '左右どちらかのコーナーキック' }, { at: 1.3, text: k.num + '番 ' + k.name.split(' ')[0] + ' が蹴る' }, { at: 3.0, text: dd.name.split(' ')[0] + ' が先に触ってクリア' }];
        sc.dur = 5.2;
        return;
      }
      const res = this.shot(sc, att, def, h, effAvg(h, ['ヘディング', 'フィニッシュ', '冷静さ'], this) + this.traitBonus(sc, h, 'ヘディングシュート', 2, '高い打点で合わせた') + (h.height - 178) * 0.1, 1.8, 'head', { cross: true, crowd: true });
      this.finish(sc, att, def, res, h, k);
      sc.frames = mk(this.endFrames(sc, res, [hx, 98], gkp.id, null, 3.0, hx > 34 ? 36.5 : 31.5));
      sc.beats = [{ at: 0.1, text: 'コーナーキック' }, { at: 1.3, text: k.num + '番 ' + k.name.split(' ')[0] + ' が蹴る' }, { at: 2.2, text: h.num + '番 ' + h.name.split(' ')[0] + ' が競り勝った！' }, { at: 3.4, text: this.result_text(att, sc, res, h) }];
      sc.dur = 5.8;
    }

    // ロングスローからの混戦
    _longthrow(sc, att, def) {
      const rng = this.rng;
      const t = this.onPitch(att).filter((x) => has(x.p, 'ロングスロー'))[0];
      const thrower = t ? t.p : this.pickActor(att, ['DF', 'MF'], ['強さ'], [], [], sc);
      const h = this.pickActor(att, ['DF', 'FW'], ['ヘディング', 'ジャンプ', '強さ'], ['ヘディングシュート', 'こぼれ球への嗅覚'], [thrower.id], sc);
      const dd = this.pickDefender(def, 'C', sc);
      const gkp = this.gk(def);
      sc.actors = { thrower: thrower.id, header: h.id };
      sc.defs = [dd.id];
      this.traitBonus(sc, thrower, 'ロングスロー', 0, '長い距離をゴール前まで投げ込んだ');
      const H = effAvg(h, ['ヘディング', 'ジャンプ', '強さ'], this) + this.traitBonus(sc, h, 'こぼれ球への嗅覚', 2, 'こぼれ球にいち早く反応した') + this.traitBonus(sc, h, 'ヘディングシュート', 2, '押し込んだ') + has(thrower, 'ロングスロー') * 1.5;
      const D = effAvg(dd, ['ヘディング', 'ジャンプ', '強さ', 'マーク'], this) + 1.5;
      const hx = 34 + (rng() - 0.5) * 6;
      const tx = rng() < 0.5 ? 1 : 67;
      const mk = (end) => [
        { t: 0, pos: { [thrower.id]: [tx, 94], [h.id]: [hx + 2, 99], [dd.id]: [hx, 99] }, ball: [tx, 94, 1.8] },
        { t: 1.0, pos: { [thrower.id]: [tx, 94] }, ball: [tx, 94, 2.2], cap: thrower.num + '番 ロングスロー' },
        { t: 2.0, pos: { [h.id]: [hx, 99], [dd.id]: [hx - 1, 99] }, ball: [hx, 99, 2.6], cap: '混戦' },
      ].concat(end);
      if (rng() > sig((H - D) * 0.3) * 0.9 + 0.05) {
        sc.frames = mk([{ t: 3.0, pos: { [dd.id]: [hx - 1, 99] }, ball: [hx - 6, 92, 1.6], cap: 'クリア' }, { t: 3.8, pos: {}, ball: [hx - 9, 82, 0.1] }]);
        sc.outcome = 'cleared';
        sc.beats = [{ at: 0.1, text: thrower.num + '番 ' + thrower.name.split(' ')[0] + ' のロングスロー！' }, { at: 2.4, text: '混戦になったが ' + dd.name.split(' ')[0] + ' がクリア' }];
        sc.dur = 4.8;
        return;
      }
      const res = this.shot(sc, att, def, h, effAvg(h, ['フィニッシュ', 'ヘディング', '冷静さ'], this), 1.2, 'scramble', { crowd: true, cross: true });
      this.finish(sc, att, def, res, h, thrower);
      sc.frames = mk(this.endFrames(sc, res, [hx, 99], gkp.id, null, 2.9, hx > 34 ? 36 : 32));
      sc.beats = [{ at: 0.1, text: thrower.num + '番 ' + thrower.name.split(' ')[0] + ' のロングスロー！' }, { at: 2.0, text: 'ゴール前の混戦…' }, { at: 3.3, text: this.result_text(att, sc, res, h) }];
      sc.dur = 5.6;
    }

    // カウンター
    _counter(sc, att, def) {
      const rng = this.rng;
      const c = this.pickActor(att, ['MF', 'FW'], ['ドリブル', 'スピード', '判断', '加速'], ['ボールを運ぶ', '縦への突破', '裏への抜け出し'], [], sc, ['運ぶ', '裏を狙う']);
      const f = this.pickActor(att, ['FW', 'MF'], ['フィニッシュ', 'オフザボール', 'スピード'], ['裏への抜け出し', 'ニアへの飛び込み'], [c.id], sc, ['裏を狙う', 'ゴール前']);
      const reb = this.pickActor(att, ['MF', 'DF'], ['タックル', '予測', 'ポジショニング'], ['ボール奪取', '読みのインターセプト', '即時奪回'], [c.id, f.id], sc, ['潰す']);
      this.traitBonus(sc, reb, 'ボール奪取', 0, 'ボールを奪い取った');
      this.traitBonus(sc, reb, '読みのインターセプト', 0, '縦パスを読んでカット');
      this.traitBonus(sc, reb, '即時奪回', 0, '失ってすぐ奪い返した');
      const d1 = this.pickDefender(def, 'L', sc);
      const d2 = this.pickDefender(def, 'R', sc);
      const gkp = this.gk(def);
      sc.actors = { winner: reb.id, carrier: c.id, finisher: f.id };
      sc.defs = [d1.id, d2.id];
      let Q = (effAvg(c, ['ドリブル', 'スピード', '判断'], this) + effAvg(f, ['オフザボール', 'スピード', '加速'], this)) / 2 + this.traitBonus(sc, c, 'ボールを運ぶ', 2.5, 'ボールを持って一気に運んだ') + this.traitBonus(sc, f, '裏への抜け出し', 2, '並走して裏を狙った');
      Q += this.persMod(sc, att, c, 'duel') + (att.tactic.tempo - 0.5) * 2;
      const rec = this.defTrait(sc, def, 'スライディング', 2.5, '追いついてスライディングで止めにいった', ['DF', 'MF']);
      const cov = this.defTrait(sc, def, 'カバーリング', 1.5, '戻って守備のカバーに入った', ['DF']);
      let D = (effAvg(d1, ['スピード', 'ポジショニング', '予測'], this) + effAvg(d2, ['スピード', 'ポジショニング', '予測'], this)) / 2 + rec.b + cov.b - (def.tactic.line - 0.4) * 3;
      const cx = 34 + (rng() - 0.5) * 18;
      const mk = (end) => [
        { t: 0, pos: { [reb.id]: [cx, 36], [c.id]: [cx + 4, 40], [f.id]: [cx - 8, 52], [d1.id]: [cx - 9, 64], [d2.id]: [cx + 9, 64] }, ball: [cx, 36, 0], cap: reb.num + '番 ボール奪取' },
        { t: 0.8, pos: { [reb.id]: [cx, 37], [c.id]: [cx + 3, 44], [f.id]: [cx - 8, 58] }, ball: [cx + 3, 44, 0.8] },
        { t: 1.8, pos: { [c.id]: [cx + 2, 62], [f.id]: [cx - 9, 70], [d1.id]: [cx - 8, 68], [d2.id]: [cx + 8, 67] }, ball: [cx + 2, 62.3, 0], cap: c.num + '番 運ぶ' },
        { t: 2.6, pos: { [c.id]: [cx, 78], [f.id]: [cx - 8, 84], [d1.id]: [cx - 6, 78], [d2.id]: [cx + 6, 76] }, ball: [cx, 78.2, 0], cap: 'カウンター！' },
      ].concat(end);
      if (rng() > sig((Q - D) * 0.3 + 0.25) * 0.93 + 0.04) {
        const who = rec.p || cov.p || d1;
        sc.frames = mk([{ t: 3.2, pos: { [c.id]: [cx, 81], [who.id]: [cx + 1, 80] }, ball: [cx + 2, 80, 0.3], cap: who.name.split(' ')[0] + ' が止めた' }]);
        sc.outcome = 'stopped';
        who.st.rating += 0.4;
        sc.beats = [{ at: 0.1, text: reb.num + '番 ' + reb.name.split(' ')[0] + ' がボールを奪った！' }, { at: 1.4, text: 'カウンター発動…しかし ' + who.name.split(' ')[0] + ' が止めた' }];
        sc.dur = 4.8;
        return;
      }
      const res = this.shot(sc, att, def, f, effAvg(f, ['フィニッシュ', '冷静さ', '判断'], this) + this.traitBonus(sc, f, 'ニアへの飛び込み', 1, '素早く前に入った'), 1.8, 'counter', { oneOnOne: true });
      this.finish(sc, att, def, res, f, c);
      const gx = res.result === 'goal' ? (rng() < 0.5 ? 31 : 37) : 34;
      sc.frames = mk([
        { t: 3.3, pos: { [c.id]: [cx - 2, 86], [f.id]: [cx - 7, 90], [gkp.id]: [34, 100] }, ball: [cx - 6, 89, 0.6], cap: c.num + '番 → ' + f.num + '番' },
        { t: 3.8, pos: { [f.id]: [cx - 7, 91] }, ball: [cx - 7, 91, 0] },
      ].concat(this.endFrames(sc, res, [cx - 7, 91], gkp.id, null, 4.2, gx)));
      sc.beats = [
        { at: 0.1, text: reb.num + '番 ' + reb.name.split(' ')[0] + ' がボールを奪った！' },
        { at: 1.4, text: c.num + '番 ' + c.name.split(' ')[0] + ' が一気に運ぶ' },
        { at: 3.2, text: f.num + '番 ' + f.name.split(' ')[0] + ' へ渡して…' },
        { at: 4.5, text: this.result_text(att, sc, res, f) },
      ];
      sc.dur = 6.6;
    }

    // ワンツー突破
    _onetwo(sc, att, def) {
      const rng = this.rng;
      const a = this.pickActor(att, ['MF', 'FW'], ['パス', 'ドリブル', 'オフザボール'], ['ワンツー', 'ひらめき'], [], sc, ['飛び出す']);
      const b = this.pickActor(att, ['FW', 'MF'], ['ファーストタッチ', 'パス', 'テクニック'], ['ポストプレー', '下がって受ける', 'タメを作る', 'ワンツー'], [a.id], sc, ['ポスト', '下がって受ける']);
      const d1 = this.pickDefender(def, 'C', sc);
      const d2 = this.pickDefender(def, 'C', sc);
      const gkp = this.gk(def);
      sc.actors = { runner: a.id, wall: b.id };
      sc.defs = [d1.id, d2.id];
      let Q = effAvg(a, ['パス', 'オフザボール', '判断'], this) + effAvg(b, ['ファーストタッチ', 'パス', 'テクニック'], this) * 0.8 + this.traitBonus(sc, a, 'ワンツー', 2.5, '壁に当てて素早く走り直した') + this.traitBonus(sc, b, 'ポストプレー', 1.5, '体で収めて落とした') + this.traitBonus(sc, b, '下がって受ける', 1.5, '下がって受けて落とした') + this.traitBonus(sc, b, 'タメを作る', 1.5, '一呼吸おいて時間を作った') + this.traitBonus(sc, b, '背負ってからのターン', 0, '');
      Q = Q / 1.8;
      const pr = this.defTrait(sc, def, 'ボール奪取', 2, '間に入ってボールを奪いにいった', ['DF', 'MF']);
      let D = (effAvg(d1, ['マーク', '予測', 'ポジショニング'], this) + effAvg(d2, ['マーク', '予測', 'ポジショニング'], this)) / 2 + pr.b;
      const ax = clamp(this.pos(att, a)[0] + (rng() - 0.5) * 8, 16, 52);
      const bx = ax + (rng() < 0.5 ? -7 : 7);
      const mk = (end) => [
        { t: 0, pos: { [a.id]: [ax, 68], [b.id]: [bx, 76], [d1.id]: [ax - 2, 77], [d2.id]: [bx, 82] }, ball: [ax, 68.4, 0] },
        { t: 0.8, pos: { [a.id]: [ax, 70], [b.id]: [bx, 76] }, ball: [bx, 76, 0.2], cap: a.num + '番 → ' + b.num + '番' },
        { t: 1.6, pos: { [a.id]: [ax + (34 - ax) * 0.3, 80], [b.id]: [bx, 76.5], [d1.id]: [ax - 1, 80] }, ball: [bx, 76.5, 0.2], cap: 'ワンツー' },
        { t: 2.3, pos: { [a.id]: [ax + (34 - ax) * 0.5, 87], [d1.id]: [ax + 1, 83], [d2.id]: [bx, 84] }, ball: [ax + (34 - ax) * 0.5, 87.3, 0] },
      ].concat(end);
      if (rng() > sig((Q - D) * 0.3 + 0.1) * 0.93 + 0.04) {
        sc.frames = mk([{ t: 3.0, pos: { [d1.id]: [ax + 2, 87] }, ball: [ax + 3, 88, 0.3], cap: d1.name.split(' ')[0] + ' が読んだ' }]);
        sc.outcome = 'intercepted';
        d1.st.rating += 0.3;
        sc.beats = [{ at: 0.1, text: a.num + '番 ' + a.name.split(' ')[0] + ' と ' + b.num + '番 ' + b.name.split(' ')[0] + ' のワンツー' }, { at: 2.3, text: '…惜しくも ' + d1.name.split(' ')[0] + ' がカット' }];
        sc.dur = 4.4;
        return;
      }
      const res = this.shot(sc, att, def, a, effAvg(a, ['フィニッシュ', '冷静さ', 'テクニック'], this), 1.5, 'onetwo', {});
      this.finish(sc, att, def, res, a, b);
      const gx = res.result === 'goal' ? (rng() < 0.5 ? 31 : 37) : 34;
      sc.frames = mk([{ t: 2.9, pos: { [a.id]: [ax + (34 - ax) * 0.6, 91], [gkp.id]: [34, 100] }, ball: [ax + (34 - ax) * 0.6, 91.3, 0], cap: 'シュート' }].concat(this.endFrames(sc, res, [ax + (34 - ax) * 0.6, 91], gkp.id, null, 3.4, gx)));
      sc.beats = [{ at: 0.1, text: a.num + '番 ' + a.name.split(' ')[0] + ' と ' + b.num + '番 ' + b.name.split(' ')[0] + ' が壁パスで崩す' }, { at: 2.3, text: '抜け出した！' }, { at: 3.5, text: this.result_text(att, sc, res, a) }];
      sc.dur = 5.4;
    }

    // 高い位置での奪取からのショートカウンター
    _steal(sc, att, def) {
      const rng = this.rng;
      const p = this.pickActor(att, ['FW', 'MF'], ['タックル', '運動量', '予測', 'ポジショニング'], ['前線からの守備', '即時奪回', 'ボール奪取'], [], sc, ['潰す']);
      const f = this.pickActor(att, ['FW', 'MF'], ['フィニッシュ', 'オフザボール'], [], [p.id], sc, ['ゴール前']);
      const victim = this.pickDefender(def, 'C', sc);
      const gkp = this.gk(def);
      sc.actors = { presser: p.id, finisher: f.id };
      sc.defs = [victim.id];
      let P = effAvg(p, ['タックル', '運動量', '予測'], this) + this.traitBonus(sc, p, '前線からの守備', 3, '前から追いかけて圧力をかけた') + this.traitBonus(sc, p, '即時奪回', 2, '失った直後に奪い返した') + this.traitBonus(sc, p, 'ボール奪取', 2, '体を入れて奪い取った') + this.persMod(sc, att, p, 'duel') + att.tactic.press * 2;
      let V = effAvg(victim, ['ファーストタッチ', 'テクニック', '冷静さ', 'パス'], this) + this.persMod(sc, def, victim, 'defend') - 1;
      const px = 34 + (rng() - 0.5) * 24;
      const mk = (end) => [
        { t: 0, pos: { [victim.id]: [px, 87], [p.id]: [px + 6, 80], [f.id]: [px - 8, 82], [gkp.id]: [34, 101] }, ball: [px, 87, 0], cap: '相手が自陣でつなぐ' },
        { t: 0.9, pos: { [victim.id]: [px, 87], [p.id]: [px + 2, 85] }, ball: [px, 87, 0], cap: p.num + '番 プレス' },
      ].concat(end);
      if (rng() > sig((P - V) * 0.3) * 0.9 + 0.05) {
        sc.frames = mk([{ t: 1.8, pos: { [victim.id]: [px - 3, 89], [p.id]: [px + 1, 86] }, ball: [px - 8, 90, 0.8], cap: 'かわされた' }]);
        sc.outcome = 'escaped';
        sc.beats = [{ at: 0.1, text: p.num + '番 ' + p.name.split(' ')[0] + ' が前から追う' }, { at: 1.3, text: victim.name.split(' ')[0] + ' が冷静にかわした' }];
        sc.dur = 3.8;
        return;
      }
      const res = this.shot(sc, att, def, f, effAvg(f, ['フィニッシュ', '冷静さ'], this) + 0.5, 1.2, 'steal', { oneOnOne: true });
      this.finish(sc, att, def, res, f, p);
      const gx = res.result === 'goal' ? (rng() < 0.5 ? 31 : 37) : 34;
      sc.frames = mk([
        { t: 1.6, pos: { [p.id]: [px, 86], [victim.id]: [px - 2, 88] }, ball: [px, 86.3, 0], cap: '奪った！' },
        { t: 2.3, pos: { [p.id]: [px - 4, 90], [f.id]: [px - 8, 91] }, ball: [px - 8, 91, 0.4] },
        { t: 2.9, pos: { [f.id]: [px - 8 + (34 - px) * 0.1, 92], [gkp.id]: [34, 100] }, ball: [px - 8, 92, 0] },
      ].concat(this.endFrames(sc, res, [px - 8, 92], gkp.id, null, 3.4, gx)));
      sc.beats = [{ at: 0.1, text: '相手が自陣でボールをつなぐ' }, { at: 0.9, text: p.num + '番 ' + p.name.split(' ')[0] + ' が猛然とプレス！' }, { at: 1.8, text: 'ボールを奪った！' }, { at: 3.6, text: this.result_text(att, sc, res, f) }];
      sc.dur = 5.4;
    }

    // ---------- 実況（見どころ以外） ----------
    flavor() {
      const h = this.home;
      const a = this.away;
      const r = this.rng;
      const L1 = [];
      const diff = this.score.home - this.score.away;
      const ph = this.attPower(h) - this.defPower(a);
      const pa = this.attPower(a) - this.defPower(h);
      if (ph - pa > 1.5) L1.push('レガーレがボールを保持して試合を進める');
      else if (pa - ph > 1.5) L1.push(a.short + 'がペースを握っている');
      else L1.push('中盤での攻防が続く');
      if (h.tactic.press > 0.7) L1.push('レガーレの前線からのプレスがはまる');
      if (a.tactic.press > 0.7) L1.push(a.short + 'の激しいプレスにパスコースを探す');
      if (h.tactic.tempo > 0.7) L1.push('縦に速く入れるレガーレ');
      if (a.tactic.line < 0.3) L1.push(a.short + 'は自陣に引いて守りを固める');
      if (a.tactic.line > 0.75) L1.push(a.short + 'は最終ラインを高く保つ');
      if (this.min > 75 && diff === 0) L1.push('残り時間が少なくなり、一つのミスが命取りになる');
      if (this.min > 75 && diff > 0) L1.push('レガーレがリードを守りにかかる');
      if (this.min > 75 && diff < 0) L1.push('レガーレは同点を目指して前がかりになる');
      const tired = this.onPitch(h).filter((x) => x.p.stam < 45);
      if (tired.length) L1.push(tired[0].p.num + '番 ' + tired[0].p.name.split(' ')[0] + ' の足が止まり始めている');
      const fire = this.onPitch(h).filter((x) => has(x.p, '声で味方を動かす'));
      if (fire.length && r() < 0.4) L1.push(fire[0].p.num + '番 ' + fire[0].p.name.split(' ')[0] + ' の声で守備の陣形が整う');
      const calm = this.onPitch(h).filter((x) => has(x.p, '試合を落ち着かせる'));
      if (calm.length && r() < 0.4) L1.push(calm[0].p.num + '番 ' + calm[0].p.name.split(' ')[0] + ' が試合を落ち着かせる');
      return r.pick(L1);
    }

    // ---------- 時間の進行 ----------
    requestStop() {
      this.userStop = true;
    }
    cancelStop() {
      this.userStop = false;
    }

    // 次の出来事を1つ進めて返す
    step() {
      if (this.finished) return { type: 'full' };
      if (this.pendingStop) {
        const reason = this.pendingStop;
        this.pendingStop = null;
        this.userStop = false;
        return { type: 'stop', reason, minute: this.min };
      }
      if (this.userStop && !this._justStopped) {
        this.userStop = false;
        return { type: 'stop', reason: 'user', minute: this.min };
      }
      this._justStopped = false;
      if (this.min >= 90) {
        this.finished = true;
        return { type: 'full', summary: this.summary() };
      }
      this.min++;
      this._tickPlayers();
      if (this.min === 45 && !this.halfDone) {
        this.halfDone = true;
        if (this.settings.autoStop) this.pendingStop = 'half';
        this.log.push({ minute: 45, text: '前半終了', kind: 'info' });
        return { type: 'tick', minute: 45, text: '前半終了。' + this.score.home + ' - ' + this.score.away, key: true };
      }
      if (this.min === 75 && !this.lateDone) {
        this.lateDone = true;
        if (this.settings.autoStop) this.pendingStop = 'late';
        return { type: 'tick', minute: 75, text: '残り15分。', key: true };
      }
      if (this.keyMinutes.indexOf(this.min) >= 0) {
        const att = this.pickAttacker();
        const def = this.other(att);
        const w = this.sceneWeights(att, def);
        const types = Object.keys(w).filter((k) => w[k] > 0);
        const type = this.rng.weighted(types, (k) => w[k]);
        const sc = this.makeScene(att, def, type);
        this.scenes.push(sc);
        this.stats[sc.side].scenes++;
        this.log.push({ minute: this.min, text: sc.beats[sc.beats.length - 1].text, kind: sc.goal ? 'goal' : 'scene', scene: sc.id });
        if (sc.goal && sc.side === 'away' && this.settings.autoStop) this.pendingStop = 'conceded';
        if (sc.goal && sc.side === 'home' && this.settings.autoStop) this.pendingStop = 'scored';
        this._afterScene(sc, att, def);
        return { type: 'scene', scene: sc, minute: this.min };
      }
      const text = this.min % 4 === 0 || this.rng() < 0.1 ? this.flavor() : null;
      if (text) this.log.push({ minute: this.min, text, kind: 'flow' });
      return { type: 'tick', minute: this.min, text };
    }

    _afterScene(sc, att, def) {
      // 役割が合わない選手の不満、短気のファウルなど
      for (const t of [this.home]) {
        t.lineup.forEach((s, i) => {
          const fit = this.roleFit(t, i);
          if (fit < 0) this.discontent[s.pid] = (this.discontent[s.pid] || 0) + 1;
        });
      }
      // 当事者の評価
      for (const k of Object.keys(sc.actors)) {
        const p = att.players[sc.actors[k]];
        if (p && sc.outcome !== 'none') p.st.rating += 0.05;
      }
    }

    _tickPlayers() {
      for (const t of [this.home, this.away]) {
        for (const x of this.onPitch(t)) {
          const p = x.p;
          p.st.minutes++;
          const base = 0.5 + t.tactic.intensity * 0.3 + t.tactic.press * 0.25 + (t.tactic.line - 0.5) * 0.1;
          const f = clamp(1.25 - p.ab['スタミナ'] / 22, 0.45, 1.2);
          p.stam = clamp(p.stam - base * f * (x.pos === 'GK' ? 0.3 : 1) * (pers(p, '気持ちの強さ', '粘り強い') ? 0.9 : 1), 0, 100);
        }
      }
    }

    // ---------- 止めたときの操作 ----------
    isHalf() {
      return this.min === 45 && this.halfDone;
    }
    subsLeft(t) {
      return 5 - t.subsUsed;
    }
    windowsLeft(t) {
      return 3 - t.windowsUsed;
    }
    canSub(t, outPid, inPid) {
      if (t.subsUsed >= 5) return { ok: false, msg: '交代は5人までです' };
      if (!t.onPitch.has(outPid)) return { ok: false, msg: 'ピッチにいない選手です' };
      if (t.bench.indexOf(inPid) < 0) return { ok: false, msg: 'ベンチにいない選手です' };
      const gkOut = YA.posOfSlot(t.lineup[t.lineup.findIndex((s) => s.pid === outPid)], t.lineup.findIndex((s) => s.pid === outPid)) === 'GK';
      const gkIn = t.players[inPid].pos === 'GK';
      if (gkOut !== gkIn) return { ok: false, msg: 'GK はGKと交代します' };
      return { ok: true };
    }
    // 交代。窓（止めている間にまとめて）は 3 回まで。ハーフタイムは数えない
    substitute(t, outPid, inPid) {
      const c = this.canSub(t, outPid, inPid);
      if (!c.ok) return c;
      if (!t._winOpen && !this.isHalf()) {
        if (t.windowsUsed >= 3) return { ok: false, msg: '交代の機会は3回までです' };
        t.windowsUsed++;
        t._winOpen = true;
      }
      const i = t.lineup.findIndex((s) => s.pid === outPid);
      t.lineup[i].pid = inPid;
      t.bench[t.bench.indexOf(inPid)] = outPid;
      t.onPitch.delete(outPid);
      t.onPitch.add(inPid);
      t.players[outPid].off = true;
      t.players[inPid].stam = 100;
      t.subsUsed++;
      // 役割は新しい選手に合う初期へ
      const pos = slotPos(i, t.lineup[i]);
      if (YA.ROLES[pos].indexOf(t.lineup[i].role) < 0) t.lineup[i].role = YA.ROLES[pos][0];
      // 出番がなくて不満だった子
      this.log.push({ minute: this.min, text: '交代：' + t.players[outPid].num + '番 ' + t.players[outPid].name.split(' ')[0] + ' → ' + t.players[inPid].num + '番 ' + t.players[inPid].name.split(' ')[0], kind: 'sub' });
      return { ok: true };
    }
    // 止めている間の操作を締める（窓を閉じる）
    closeWindow(t) {
      t._winOpen = false;
    }
    setRole(t, pid, role) {
      const i = t.lineup.findIndex((s) => s.pid === pid);
      if (i < 0) return;
      t.lineup[i].role = role;
    }
    moveSlot(t, i, x, y) {
      t.lineup[i].x = clamp(x, 0.04, 0.96);
      t.lineup[i].y = clamp(y, 0.02, 0.96);
      const pos = slotPos(i, t.lineup[i]);
      if (YA.ROLES[pos].indexOf(t.lineup[i].role) < 0) t.lineup[i].role = YA.ROLES[pos][0];
    }
    swapSlots(t, i, j) {
      const a = t.lineup[i].pid;
      t.lineup[i].pid = t.lineup[j].pid;
      t.lineup[j].pid = a;
    }
    setTactic(t, patch) {
      Object.assign(t.tactic, patch);
    }
    setType(t, type) {
      t.tactic = Object.assign({ type, dir: t.tactic.dir || 0 }, YA.TACTICS[type]);
    }

    // 1人への指示。性格しだいで聞き流す
    instruct(t, pid, kind, target) {
      const p = t.players[pid];
      const rng = this.rng;
      const ignoreP = pers(p, '教えの受け止め方', '頑固') ? 0.4 : pers(p, '教えの受け止め方', 'マイペース') ? 0.25 : pers(p, '教えの受け止め方', '素直') ? 0 : 0.08;
      const label = { dribble: '仕掛けろ', back: '下がって守れ', shoot: 'シュートを打て', mark: '付け', clear: '指示なし' }[kind];
      if (kind === 'clear') {
        delete t.instr[pid];
        return { ok: true, followed: true, msg: p.num + '番 ' + p.name.split(' ')[0] + '：指示を外した' };
      }
      if (rng() < ignoreP) {
        const why = pers(p, '教えの受け止め方', '頑固') ? '頑固で、自分のやり方を変えなかった' : pers(p, '教えの受け止め方', 'マイペース') ? '聞こえていないような顔をしている' : 'うまく伝わらなかった';
        return { ok: true, followed: false, msg: p.num + '番 ' + p.name.split(' ')[0] + ' に「' + label + '」と伝えた…が、' + why };
      }
      t.instr[pid] = Object.assign({}, kind === 'mark' ? { mark: target } : { [kind]: true });
      const res = pers(p, '教えの受け止め方', '素直') ? '素直にうなずいた' : '了解した';
      return { ok: true, followed: true, msg: p.num + '番 ' + p.name.split(' ')[0] + ' に「' + label + '」：' + res };
    }

    // 声かけ。kind: fire 激励 / calm 落ち着け / praise 褒める / scold 叱る
    shout(t, target, kind) {
      const key = (target || 'team') + kind;
      if (this.shoutLog[key] != null && this.min - this.shoutLog[key] < 8) return { ok: false, msg: 'さっき声をかけたばかりです（8分あける）' };
      this.shoutLog[key] = this.min;
      const apply = (p, scale) => {
        let dc = 0;
        let df = 0;
        let note = '';
        const P = (g, v) => pers(p, g, v);
        if (kind === 'fire') {
          dc = 4;
          note = '気合が入った';
          if (P('気持ちの強さ', '負けず嫌い')) {
            dc += 3;
            df += 0.5;
            note = '闘志に火が付いた';
          }
          if (P('気持ちの強さ', '繊細') || P('大舞台', 'プレッシャーに弱い')) {
            dc -= 6;
            note = '重圧を感じて固くなった';
          }
          if (P('気持ちの強さ', '楽天家')) note = '「任せてください」と笑った';
        } else if (kind === 'calm') {
          dc = 1;
          note = '落ち着きを取り戻した';
          if (P('感情の波', '気分屋')) {
            df += p.form > 0 ? -1 : 1;
            note = '浮き沈みが収まった';
          }
          if (P('感情の波', '短気')) {
            dc += 3;
            note = '頭が冷えた';
          }
          if (P('感情の波', '安定型')) note = 'もともと落ち着いている';
        } else if (kind === 'praise') {
          dc = 5;
          note = '自信を持った';
          if (P('教えの受け止め方', '構ってほしい')) {
            dc += 4;
            df += 1;
            note = '目を輝かせた';
          }
          if (P('プレーの気質', '自信家')) {
            dc -= 2;
            note = '当然という顔をした';
          }
          if (P('気持ちの強さ', '完璧主義')) {
            dc -= 3;
            note = '満足していない様子';
          }
        } else {
          dc = -3;
          note = '表情が曇った';
          if (P('教えの受け止め方', '反骨心')) {
            dc = 3;
            df += 1;
            note = '悔しさを力に変えた';
          } else if (P('教えの受け止め方', '素直')) {
            dc = 1;
            note = '引き締まった';
          } else if (P('気持ちの強さ', '繊細')) {
            dc = -8;
            df -= 1;
            note = 'ひどく落ち込んだ';
          } else if (P('感情の波', '短気')) {
            dc = -4;
            df -= 1;
            note = 'ふてくされた';
          } else if (P('教えの受け止め方', '頑固')) {
            dc = 0;
            note = '聞き流した';
          }
        }
        p.conf = clamp(p.conf + dc * scale, 0, 100);
        p.form = clamp(p.form + df * scale, -3, 3);
        return note;
      };
      const label = { fire: '激励', calm: '落ち着け', praise: '褒める', scold: '叱る' }[kind];
      if (target && target !== 'team') {
        const p = t.players[target];
        const note = apply(p, 1);
        return { ok: true, msg: p.num + '番 ' + p.name.split(' ')[0] + ' に「' + label + '」：' + note };
      }
      const on = this.onPitch(t).map((x) => x.p);
      const res = on.map((p) => ({ p, note: apply(p, 0.5) }));
      const hot = res.filter((r) => /火|気合|力に/.test(r.note)).length;
      const bad = res.filter((r) => /固く|落ち込|ふてくされ|曇/.test(r.note)).slice(0, 2);
      let msg = 'チーム全体に「' + label + '」';
      if (bad.length) msg += '。' + bad.map((b) => b.p.num + '番は' + b.note).join('、');
      else msg += '。チームが' + (kind === 'calm' ? '落ち着いた' : '引き締まった');
      return { ok: true, msg };
    }

    // ---------- 試合後 ----------
    summary() {
      const sh = this.score.home;
      const sa = this.score.away;
      const notes = [];
      const traitGoals = {};
      for (const sc of this.scenes) {
        if (sc.side !== 'home') continue;
        for (const f of sc.fx) {
          if (sc.goal || sc.outcome === 'saved' || sc.outcome === 'intercepted' || sc.outcome === 'cleared') {
            const k = f.pid + '|' + f.kind + '|' + f.tag;
            traitGoals[k] = (traitGoals[k] || 0) + 1;
          }
        }
      }
      const seen = {};
      for (const sc of this.scenes) {
        for (const f of sc.fx) {
          const t = sc.side === 'home' ? this.home : this.away;
          const key = f.pid + f.tag;
          if (seen[key]) continue;
          seen[key] = 1;
        }
      }
      for (const [pid, n] of Object.entries(this.discontent)) {
        const p = this.home.players[pid];
        if (p && n >= 8) notes.push({ kind: 'bad', text: p.num + '番 ' + p.name.split(' ')[0] + '：今の役割「' + this.roleOf(this.home, p) + '」が合っておらず、不満を感じている' });
      }
      for (const t of [this.home]) {
        for (const p of Object.values(t.players)) {
          if (p.off === false && !t.onPitch.has(p.id)) continue;
        }
      }
      const rated = Object.values(this.home.players).filter((p) => p.st.minutes > 0);
      for (const p of rated) {
        p.st.rating = clamp(p.st.rating + (sh > sa ? 0.3 : sh < sa ? -0.3 : 0), 3, 10);
      }
      rated.sort((a, b) => b.st.rating - a.st.rating);
      return { score: { home: sh, away: sa }, mvp: rated[0] || null, rated, notes };
    }
  }

  YA.Match = Match;
  YA.eff = eff;
  YA.cond = cond;
  YA.slotPos = slotPos;
})();
