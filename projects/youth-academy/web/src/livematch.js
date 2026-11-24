// 一続きの試合（live.js）と engine（Match）のつなぎ（2026-11-23）。
// engine は今までどおり1分ずつ step する。live のときは、その1分を live.js で動かし、起きた出来事を成績・実況・カードに移す。
// 見どころは、実際に起きた得点と大きな場面（シュートの決まりやすさ xG が高いもの・PK）を拾い、その攻めの始まりからの記録を再生する。
(function () {
  'use strict';
  const YA = globalThis.YA;
  if (!YA.Match) return;
  const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
  const pers = (p, g, v) => p.pers && p.pers[g] === v;
  YA.SCENE_NAMES.build = 'パスでの崩し';
  YA.SCENE_NAMES.scramble = 'ゴール前の混戦';
  const nm = (p) => (p ? p.num + '番 ' + String(p.name).split(' ')[0] : '');
  const M = YA.Match.prototype;
  M._lvP = function (pid) {
    return this.home.players[pid] || this.away.players[pid] || null;
  };
  M._lvTeam = function (sd) {
    return sd === 'home' ? this.home : this.away;
  };
  // この1分を動かして、出来事を成績・実況に移す。見どころがあれば場面を返す
  M._liveMinute = function () {
    const lv = this.live;
    const off = this.ti > 44 + this.add1 ? this.add1 * 60 : 0;
    const end = (this.min + this.extra) * 60 + off;
    const last = this.ti >= this.timeline.length - 1;
    lv.runTo(end);
    if (!last) lv.runTo(end + 6); // 場面のあと（シュートの結末）まで見せるので、少し先まで動かしておく
    lv.refreshAb(); // 疲れ（engine が毎分 stam を減らす）を動きに映す
    const E = lv.events;
    this._lvDone = this._lvDone || new Set();
    let best = null;
    while (this._lvI < E.length && E[this._lvI].t < end) {
      const i = this._lvI++;
      const e = E[i];
      if (this._lvDone.has(e)) continue;
      const c = this._lvEvent(e, i);
      if (c && (!best || c.score > best.score)) best = c;
    }
    if (!best) return null;
    // 見どころは1試合15前後。時間に合わせて配る（前半で上限に届き、終盤の場面が出なかった）。得点はいつも出す
    const quota = 2 + Math.floor((13 * this.min) / 90);
    if (!best.goal && (this.scenes.length >= quota || best.score < 0.11)) return null;
    return this._lvScene(best);
  };
  // 出来事を1つ反映する。見どころの候補なら { score, ... } を返す
  M._lvEvent = function (e, i) {
    const lv = this.live;
    const E = lv.events;
    const p = e.pid ? this._lvP(e.pid) : null;
    const st = this.stats;
    // 試合中の画面に出す細かい数（数えるだけ。結果は変えない）
    if (e.sd && st[e.sd]) {
      if (e.k === 'foul') st[e.sd].fouls = (st[e.sd].fouls || 0) + 1;
      else if (e.k === 'offside') st[e.sd].offside = (st[e.sd].offside || 0) + 1;
      else if (e.k === 'restart' && e.type === 'corner') st[e.sd].corners = (st[e.sd].corners || 0) + 1;
    }
    if (e.k === 'shot') {
      if (p) p.st.shots++;
      st[e.sd].shots++;
      if (e.onT) st[e.sd].onTarget++;
      // 結末を先読み（4秒以内）
      let res = 'other';
      let re = null;
      for (let j = i + 1; j < E.length && E[j].t < e.t + 4; j++) {
        const x = E[j];
        if (x.k === 'goal') {
          res = x.sd === e.sd ? 'goal' : 'other';
          re = x;
          break;
        }
        if (x.k === 'save') { res = 'saved'; re = x; break; }
        if (x.k === 'block') { res = 'blocked'; re = x; break; }
        if (x.k === 'miss') { res = 'missed'; re = x; break; }
        if (x.k === 'shot' || x.k === 'dead') break;
      }
      if (res === 'goal') {
        this._lvDone.add(re);
        this._lvGoal(re);
      }
      return { score: res === 'goal' ? 10 : e.xg + (e.pk ? 1 : 0) + (res === 'saved' ? 0.03 : 0), shot: e, res, goal: res === 'goal', ge: res === 'goal' ? re : null, i };
    }
    if (e.k === 'goal') {
      // シュートの無い得点（オウンゴール・こぼれ）
      this._lvGoal(e);
      return { score: 10, shot: null, res: 'goal', goal: true, ge: e, i };
    }
    if (e.k === 'save') {
      if (p) {
        p.st.saves++;
        p.st.rating += e.smother ? 0.15 : 0.25;
      }
      const sh = e.vs ? this._lvP(e.vs) : null;
      if (sh && !e.smother) sh.conf = clamp(sh.conf - 1, 0, 100);
    } else if (e.k === 'miss') {
      if (p) {
        p.st.rating -= 0.15;
        p.conf = clamp(p.conf - (pers(p, '気持ちの強さ', '繊細') ? 3 : 1), 0, 100);
      }
    } else if (e.k === 'block') {
      if (p) p.st.rating += 0.3;
    } else if (e.k === 'tackle' && e.ok) {
      if (p) {
        p.st.rating += 0.02;
        p.st.tk = (p.st.tk || 0) + 1;
      }
    } else if (e.k === 'intercept') {
      if (p) {
        p.st.rating += 0.015;
        p.st.ic = (p.st.ic || 0) + 1;
      }
    } else if (e.k === 'foul') {
      const t = this._lvTeam(e.sd);
      if (p && t) {
        const pk = !!e.pk;
        const res = this._foul(t, p, pk ? 0.3 : p.yellow ? 0.04 : 0.13, pk ? 0.03 : 0.002); // 1枚もらった子は気をつける（2枚目の退場が多かった）
        const v = e.vs ? this._lvP(e.vs) : null;
        if (pk) this.log.push({ minute: this.min, ml: this.minLabel(), text: nm(p) + 'がエリアの中で倒した。PK' + (res.txt || ''), kind: 'scene' });
        else if (res.card && v) this.log.push({ minute: this.min, ml: this.minLabel(), text: nm(p) + 'が' + nm(v) + 'を倒した', kind: 'flow' });
      }
    } else if (e.k === 'offside') {
      if (p) this.log.push({ minute: this.min, ml: this.minLabel(), text: nm(p) + 'はオフサイド', kind: 'flow' });
    }
    return null;
  };
  M._lvGoal = function (e) {
    const sd = e.sd;
    const att = this._lvTeam(sd);
    const def = this._lvTeam(sd === 'home' ? 'away' : 'home');
    this.score[sd]++;
    const p = e.pid ? att.players[e.pid] : null;
    const a = e.assist ? att.players[e.assist] : null;
    if (p) {
      p.st.goals++;
      p.st.rating += 1.2;
    }
    if (a && a !== p) {
      a.st.assists++;
      a.st.rating += 0.6;
    }
    if (e.og) {
      const o = def.players[e.og];
      if (o) o.st.rating -= 0.6;
    }
    for (const pl of Object.values(def.players)) {
      if (!def.onPitch.has(pl.id)) continue;
      pl.conf = clamp(pl.conf - 1.5, 0, 100);
      if (pers(pl, '気持ちの強さ', '繊細')) pl.conf = clamp(pl.conf - 2, 0, 100);
      if (pers(pl, '気持ちの強さ', '負けず嫌い')) pl.form = clamp(pl.form + 0.5, -3, 3);
    }
    for (const pl of Object.values(att.players)) if (att.onPitch.has(pl.id)) pl.conf = clamp(pl.conf + 2, 0, 100);
    if (sd === 'away' && this.settings.autoStop) this.pendingStop = 'conceded';
    if (sd === 'home' && this.settings.autoStop && this.settings.stopOnScore) this.pendingStop = 'scored';
  };
  // 場面の図の道筋：攻めのパス（最後の4本まで）・運んだ所・シュート
  M._lvPath = function (c, t0, sd) {
    const lv = this.live;
    const E = lv.events;
    const sh = c.shot;
    const end = c.i;
    const steps = [];
    let recv = null; // 直前に受けた所
    let i0 = end;
    while (i0 > 0 && E[i0 - 1].t >= t0) i0--;
    for (let j = i0; j < end; j++) {
      const e = E[j];
      if (e.sd !== sd) {
        if (e.k === 'ctrl' || e.k === 'intercept' || (e.k === 'tackle' && e.ok)) { steps.length = 0; recv = null; }
        continue;
      }
      if (e.k === 'ctrl') recv = [e.x, e.y, e.pid];
      if (e.k !== 'kick' || e.kind === 'shot' || e.kind === 'clear') continue;
      // 受けた所（次にこの側が触った所。無ければ狙った所）
      let to = [e.tx, e.ty];
      for (let q = j + 1; q < end && E[q].t < e.t + 5; q++) {
        if (E[q].k === 'ctrl' && E[q].sd === sd) { to = [E[q].x, E[q].y]; break; }
        if (E[q].k === 'kick') break;
      }
      if (recv && Math.hypot(recv[0] - e.x, recv[1] - e.y) > 3.5) steps.push({ type: 'carry', from: [recv[0], recv[1]], to: [e.x, e.y], pid: e.pid });
      steps.push({ type: e.loft ? 'loft' : 'pass', from: [e.x, e.y], to, pid: e.pid, kind: e.kind });
      recv = null;
    }
    // 最後の4本のパスまで
    let np = 0;
    let cut = 0;
    for (let k = steps.length - 1; k >= 0; k--) if (steps[k].type !== 'carry' && ++np > 4) { cut = k + 1; break; }
    const out = steps.slice(cut);
    if (sh) {
      if (recv && Math.hypot(recv[0] - sh.x, recv[1] - sh.y) > 3.5) out.push({ type: 'carry', from: [recv[0], recv[1]], to: [sh.x, sh.y], pid: sh.pid });
      const gy = sd === 'home' ? 105 : 0;
      const o = sd === 'home' ? 1 : -1;
      const snap = sh.snap || [];
      const at = (pid) => { const r = snap.find((x) => x[0] === pid); return r ? [r[1], r[2]] : null; };
      let to;
      const cx = sh.cross ? sh.cross[0] : 34;
      if (c.res === 'goal') to = [Math.max(31, Math.min(37, cx)), gy + o * 1.4];
      else if (c.res === 'saved') to = at(this.gk(this._lvTeam(sd === 'home' ? 'away' : 'home')).id) || [34, gy - o * 1.5];
      else if (c.res === 'blocked') { const bl = E.slice(end + 1, end + 12).find((x) => x.k === 'block'); to = (bl && at(bl.pid)) || [(sh.x + 34) / 2, (sh.y + gy) / 2]; }
      else if (c.res === 'missed') to = [Math.abs(cx - 34) < 4.2 ? 34 + (cx < 34 ? -5 : 5) : Math.max(24, Math.min(44, cx)), gy + o * 2];
      else to = [(sh.x + 34) / 2, (sh.y + gy) / 2];
      out.push({ type: 'shot', from: [sh.x, sh.y], to, pid: sh.pid, res: c.res });
    }
    return out;
  };
  // 見どころの場面（記録の再生の区切りと実況）
  M._lvScene = function (c) {
    const lv = this.live;
    const E = lv.events;
    const sh = c.shot;
    const anchor = sh || c.ge;
    const tA = anchor.t;
    const sd = anchor.sd;
    const other = sd === 'home' ? 'away' : 'home';
    // 攻めの始まり：その側がボールを持ち始めた所（相手が持った・再開）から。長ければ16秒前まで
    let t0 = tA - 12;
    let setType = null;
    for (let j = c.i - 1; j >= 0 && E[j].t > tA - 25; j--) {
      const x = E[j];
      if (x.k === 'restart') {
        if (x.sd === sd && tA - x.t < 10) setType = x.type;
        t0 = x.t - 1.5;
        break;
      }
      if ((x.k === 'ctrl' || x.k === 'intercept' || (x.k === 'tackle' && x.ok)) && x.sd !== sd) {
        t0 = x.t - 1;
        break;
      }
    }
    t0 = clamp(t0, tA - 16, tA - 4);
    const t1 = tA + (c.goal ? 4.5 : 2.2);
    const shooter = sh ? this._lvP(sh.pid) : null;
    // 型（チームの重点の得点の数え方 club5.js が使う）
    let type = 'build';
    if (setType === 'pk') type = 'pk';
    else if (setType === 'corner') type = 'ck';
    else if (setType === 'fk') type = 'fk';
    else if (setType === 'throw' && sh && sh.head) type = 'longthrow';
    else if (sh) {
      const u = sd === 'home' ? sh.y : 105 - sh.y;
      const dd = Math.hypot(sh.x - 34, 105 - u);
      let ak = null;
      for (let j = c.i - 1; j >= 0 && E[j].t > tA - 6; j--) {
        if (E[j].k === 'kick' && E[j].sd === sd && E[j].pid !== sh.pid) {
          ak = E[j].kind;
          break;
        }
      }
      let won = null;
      for (let j = c.i - 1; j >= 0 && E[j].t > tA - 14; j--) {
        const x = E[j];
        if (x.sd === sd && (x.k === 'intercept' || (x.k === 'tackle' && x.ok))) {
          won = x;
          break;
        }
        if (x.k === 'ctrl' && x.sd !== sd) break;
      }
      const wonU = won && won.y != null ? (sd === 'home' ? won.y : 105 - won.y) : null;
      if (sh.head || ak === 'cross') type = 'cross';
      else if (dd > 19) type = 'longshot';
      else if (won && wonU != null && wonU > 60) type = 'steal';
      else if (won) type = 'counter';
      else if (ak === 'through') type = 'through';
      else if (!ak) type = 'dribble';
      else if (ak === 'pass') type = 'onetwo';
    } else type = 'scramble';
    const ml = this.minLabel();
    const sc = { id: this.scenes.length + 1, minute: this.min, ml, type, typeName: YA.SCENE_NAMES[type], side: sd, actors: {}, fx: [], beats: [], outcome: 'none', goal: !!c.goal, dur: t1 - t0, flip: sd === 'away', live: { t0, t1, tA } };
    if (shooter) sc.actors.shooter = shooter.id;
    const assist = sh && sh.assist ? this._lvP(sh.assist) : null;
    const startTx = setType === 'pk' ? 'PK。キッカーは' + nm(shooter) : setType === 'corner' ? 'コーナーキック' : setType === 'fk' ? 'フリーキック' : (sd === 'home' ? this.home.short : this.away.short) + 'の攻め';
    sc.beats.push({ at: 0, text: startTx });
    const gk = this.gk(this._lvTeam(other));
    if (sh) {
      const tS = tA - t0;
      if (assist && !setType) sc.beats.push({ at: Math.max(0.3, tS - 1.6), text: nm(assist) + (type === 'cross' ? 'のクロス' : type === 'through' ? 'のスルーパス' : 'からのパス') });
      sc.beats.push({ at: tS, text: nm(shooter) + (sh.head ? 'のヘディング！' : sh.pk ? 'が蹴った！' : 'のシュート！') });
      const txt = c.res === 'goal' ? 'ゴール！ ' + nm(shooter) + 'が決めた' + (assist && !setType ? '（アシスト ' + nm(assist) + '）' : '') : c.res === 'saved' ? 'GK ' + nm(gk) + 'が止めた' : c.res === 'blocked' ? '守りが体で止めた' : c.res === 'missed' ? '枠の外' : 'こぼれ球になった';
      sc.beats.push({ at: tS + 0.7, text: txt });
      sc.outcome = c.res === 'goal' ? 'goal' : c.res === 'saved' ? 'saved' : c.res === 'blocked' ? 'blocked' : c.res === 'missed' ? 'missed' : 'cleared';
      sc.shooter = shooter ? shooter.id : null;
    } else {
      const g = c.ge;
      const og = g.og ? this._lvP(g.og) : null;
      sc.beats.push({ at: tA - t0, text: og ? 'オウンゴール。' + nm(og) + 'に当たって入った' : 'ゴール！ こぼれ球が入った' });
      sc.outcome = 'goal';
      sc.shooter = g.pid || null;
    }
    if (c.goal) {
      sc.scorer = (c.ge && c.ge.pid) || null;
      sc.assist = c.ge && c.ge.assist && c.ge.assist !== sc.scorer ? c.ge.assist : null;
      if (c.ge && c.ge.og) sc.og = c.ge.og;
    }
    sc.gk = gk ? gk.id : null;
    // 場面の図（2026-11-24：動きで見せるのをやめ、止めた図にパスとシュートの線を順に引く）
    sc.live.path = this._lvPath(c, t0, sd);
    sc.live.snap = sh && sh.snap ? sh.snap : lv.P.map((r) => [r.id, r.x, r.y]);
    {
      const n = sc.live.path.length;
      const stepT = (i) => 0.7 + i * 0.85;
      sc.live.path.forEach((st, i) => { st.at = stepT(i); });
      const tShot = n ? stepT(n - 1) : 0.7;
      // 実況の時刻を線の出る時刻に合わせる
      const bs = sc.beats;
      bs[bs.length - 1].at = tShot + 0.9;
      if (bs.length >= 3) bs[bs.length - 2].at = tShot;
      if (bs.length >= 4) bs[bs.length - 3].at = Math.max(0.3, tShot - 0.85);
      sc.dur = tShot + 2.6;
    }
    // 効いた特性（この場面のあいだ）
    const kr = { trait: 0, gold: 0, awake: 0 };
    for (const f of lv.fx) {
      if (f.t < t0 || f.t > t1) continue;
      const p = this._lvP(f.pid);
      if (!p || sc.fx.some((x) => x.pid === f.pid && x.tag === f.tag)) continue;
      const kind = p.gold && p.gold.indexOf && p.gold.indexOf(f.tag) >= 0 ? 'gold' : p.aw && p.aw.as && p.aw.as.indexOf(f.tag) >= 0 ? 'awake' : 'trait';
      sc.fx.push({ pid: f.pid, num: p.num, name: p.name, tag: f.tag, kind, text: '' });
      if (this._use) this._use(p, f.tag); // 金の特性の回数（場面に出たものだけ）
    }
    sc.fxShow = sc.fx.slice().sort((a, b) => kr[a.kind] - kr[b.kind]).slice(0, 3);
    this.scenes.push(sc);
    this.stats[sd].scenes++;
    this.log.push({ minute: this.min, ml, text: sc.beats[sc.beats.length - 1].text, kind: sc.goal ? 'goal' : 'scene', scene: sc.id });
    this._afterScene(sc, this._lvTeam(sd), this._lvTeam(other));
    return sc;
  };
})();
