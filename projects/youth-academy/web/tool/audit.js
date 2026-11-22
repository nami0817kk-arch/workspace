// 試合の絵の点検：おかしな動きを種類ごとに数える（2026-11-22「いきなり相手にパスするとか色々ある」「他にも似たバグがないか探して」）。
// 23種類を見張り、出てはいけないものは0回、まれに起きてよいものは上限で止める。node tool/audit.js（SEEDS=1,2,3 で試合を変えられる）
'use strict';
const path = require('path'); const dir = path.join(__dirname, '..');
{ let r = 12345; Math.random = () => ((r = (r * 1103515245 + 12345) % 2147483648) / 2147483648); }
for (const f of ['data', 'engine', 'world', 'league', 'club', 'scout', 'extra', 'more', 'render']) require(path.join(dir, 'src/' + f + '.js'));
const YA = globalThis.YA; const cv = { getBoundingClientRect: () => ({ width: 844, height: 330 }), getContext: () => null, width: 0, height: 0 };
const L = 105, W = 68;
const c = {}; const ex = {};
const add = (k, e) => { c[k] = (c[k] || 0) + 1; if (e && (!ex[k] || ex[k].length < 2)) (ex[k] = ex[k] || []).push(e); };
const SEEDS = (process.env.SEEDS || '3,8,21,5').split(',').map(Number);
for (const seed of SEEDS) {
  const w = YA.newWorld(seed);
  const m = new YA.Match({ seed, home: YA.teamFromWorld(w, 'A'), away: YA.makeOpponent(YA.opponentOf(w), seed * 7), settings: { autoStop: false } });
  const R = new YA.Renderer(cv); R.setMatch(m);
  let T = 0; const tag = () => 's' + seed + ' ' + T.toFixed(1) + '秒 ' + (R.pre ? '入り' : R.scene ? '場面(' + R.scene.type + ')' : '合間');
  const dep = (id, y) => (R.atkDir(id)[1] > 0 ? y : L - y); // その子の攻める向きでの深さ
  const ko0 = R.kickoff.bind(R); R.kickoff = function (t) { ko0(t); this._koCheck = true; };
  let pp = [];
  const k0 = R.kick.bind(R);
  R.kick = function (to, recv, by) {
    const src = this.pre ? '入り' : this.scene ? '場面' : '合間';
    if (recv && recv === by) add('自分へのパス', tag());
    if (!this.scene && recv && by) { pp.push(by + '>' + recv); if (pp.length > 4) pp.shift(); if (pp.length === 4 && pp[0] === pp[2] && pp[1] === pp[3] && pp[0].split('>')[0] === pp[1].split('>')[1]) { add('同じ2人で2往復のパス(合間)', tag()); pp = []; } }
    const shot = by && dep(by, to[1]) > L - 3;
    if (recv && by && this.teamOf(recv) !== this.teamOf(by) && !shot && this.disp[recv] && Math.hypot(to[0] - this.disp[recv][0], to[1] - this.disp[recv][1]) < 3) if (recv && by && this.teamOf(recv) !== this.teamOf(by) && !shot && this.disp[recv] && Math.hypot(to[0] - this.disp[recv][0], to[1] - this.disp[recv][1]) < 3) add('相手の足元を狙ったパス(' + src + (this.base[by] && this.base[by][3] === 0 ? '・GK' : '') + ')', tag());
    if (by && this.disp[by]) {
      const len = Math.hypot(to[0] - this.disp[by][0], to[1] - this.disp[by][1]);
      if (src === '合間' && len > 55) add('合間の55m超のパス', tag() + ' ' + len.toFixed(0) + 'm');
      // 味方へのパスで、蹴った時に相手の方が落ちる所に近い（届く前に取られる球）
      if (recv && this.teamOf(recv) === this.teamOf(by) && this.disp[recv]) {
        const dr = Math.hypot(to[0] - this.disp[recv][0], to[1] - this.disp[recv][1]);
        let dop = 99; for (const o of Object.keys(this.disp)) if (this.base[o] && this.teamOf(o) !== this.teamOf(by)) dop = Math.min(dop, Math.hypot(to[0] - this.disp[o][0], to[1] - this.disp[o][1]));
        if (dop + 2 < dr) add('相手の方が先に着く所へのパス(' + src + ')', tag());
        // オフサイドの位置の味方へ（合間）
        if (src === '合間') {
          const opp = Object.keys(this.disp).filter((o) => this.base[o] && this.teamOf(o) !== this.teamOf(by));
          const ds = opp.map((o) => dep(by, this.disp[o][1])).sort((a, b) => b - a);
          const rd = dep(by, this.disp[recv][1]);
          if (ds.length > 1 && rd > ds[1] + 0.5 && rd > L / 2 && rd > dep(by, this.ball[1])) add('オフサイドの位置の味方へのパス', tag());
        }
        // 後ろへの長いパス
        if (src === '合間' && dep(by, to[1]) < dep(by, this.disp[by][1]) - 30) add('後ろへの30m超のパス', tag());
      }
    }
    return k0(to, recv, by);
  };
  let prev = {}, prevOwner = null, prevBall = R.ball.slice(), holdT = 0, outT = 0, wasCut = false, prevScene = null, lastGoalSide = null, firstAfterGoal = false;
  const step = () => {
    R.update(1 / 60); T += 1 / 60;
    const cut = R.cut > 0.05 || wasCut; wasCut = R.cut > 0.05;
    // 持ち主が相手に直接替わった（ボールが離れていないのに）
    if (R.owner && prevOwner && R.owner !== prevOwner && R.teamOf(R.owner) !== R.teamOf(prevOwner) && !cut) add('持ち主が相手へ直接替わった(' + (R.pre ? '入り' : R.scene ? '場面' : '合間') + ')', tag());
    // 持ち主が遠いのにボールが付いている
    if (R.owner && R.disp[R.owner] && Math.hypot(R.disp[R.owner][0] - R.ball[0], R.disp[R.owner][1] - R.ball[1]) > 3 && !cut) add('持ち主から3m 以上離れたボール', tag());
    // 選手の瞬間移動
    for (const id of Object.keys(R.disp)) { if (prev[id] && !cut && !(R.dive && R.dive.id === id)) { const d = Math.hypot(R.disp[id][0] - prev[id][0], R.disp[id][1] - prev[id][1]); if (d > 0.4) add('選手の瞬間移動(1コマ0.4m超)', tag() + ' ' + d.toFixed(1) + 'm'); } }
    // ボールの瞬間移動
    if (!cut && Math.hypot(R.ball[0] - prevBall[0], R.ball[1] - prevBall[1]) > 0.8) add('ボールの瞬間移動(1コマ0.8m超)', tag() + ' ' + prevBall.slice(0, 2).map((x) => x.toFixed(1)).join(',') + '→' + R.ball.slice(0, 2).map((x) => x.toFixed(1)).join(',') + ' cut' + R.cut.toFixed(2) + ' setup' + !!R.setup + ' 持' + R.owner + ' 前' + prevOwner);
    // GK が自陣ゴールから遠い
    for (const id of Object.keys(R.disp)) if (R.base[id] && R.base[id][3] === 0) { const g = R.atkDir(id)[1] > 0 ? R.disp[id][1] : L - R.disp[id][1]; if (g > 30 && !cut) add('GK がゴールから30m 以上', tag()); }
    // ピッチの外
    for (const id of Object.keys(R.disp)) { const p = R.disp[id]; if ((p[0] < -2 || p[0] > W + 2 || p[1] < -2 || p[1] > L + 2) && !cut && !R.celeb) add('選手がピッチの外2m 以上', tag() + ' ' + id + ' ' + p.map((x) => x.toFixed(1)).join(',') + ' 台本' + (R.stgt && R.stgt[id] ? R.stgt[id].map((x) => x.toFixed(1)).join(',') : '-') + (R.owner === id ? ' 持ち主' : '') + (R.expect === id ? ' 受け手' : '')); }
    // 外に出たボールを持ったまま
    const out = R.ball[0] < -1 || R.ball[0] > W + 1 || R.ball[1] < -1 || R.ball[1] > L + 1;
    if (out && R.owner && !(R._outOwn)) add('外に出たボールを持っている(回)', tag() + ' 球' + R.ball.slice(0, 2).map((x) => x.toFixed(1)).join(',') + (R.scene ? ' ' + R.scene.type : ''));
    R._outOwn = out && R.owner;
    if (out && !R.scene && !cut) outT += 1 / 60; else outT = 0; if (outT > 1.5) { add('外に出たボールが1.5秒以上そのまま(合間)', tag()); outT = -99; }
    // 長く持ちすぎ（合間）
    if (!R.scene && R.owner && R.owner === prevOwner) { holdT += 1 / 60; if (holdT > 6) { add('合間に6秒以上持ち続ける', tag()); holdT = -99; } } else if (R.owner !== prevOwner) holdT = 0;
    // 得点のあとのキックオフは決められた側
    if (firstAfterGoal && R.owner && !R.scene) { const t = R.teamOf(R.owner); if ((lastGoalSide === 'home' && t === m.home) || (lastGoalSide === 'away' && t === m.away)) add('得点した側がキックオフ', tag()); firstAfterGoal = false; }
    // GK がペナルティエリアの外でボールを持つ
    if (R.owner && R.base[R.owner] && R.base[R.owner][3] === 0 && !cut) { const p = R.disp[R.owner]; const gd = R.atkDir(R.owner)[1] > 0 ? p[1] : L - p[1]; if ((gd > 16.5 || Math.abs(p[0] - 34) > 20.2) && !R._gkOut) add('GK がエリアの外でボールを持つ(回)', tag()); R._gkOut = gd > 16.5 || Math.abs(p[0] - 34) > 20.2; } else R._gkOut = false;
    // 合間にボールがゴールに入る
    if (!R.scene && !cut && Math.abs(R.ball[0] - 34) < 3.66 && (R.ball[1] < -0.3 || R.ball[1] > L + 0.3) && !R._gIdle && !R.celeb) { add('合間にボールがゴールの中へ', tag()); R._gIdle = true; } else if (Math.abs(R.ball[1] - L / 2) < 40) R._gIdle = false;
    // 誰も拾わない止まった球（合間）
    const bs = Math.hypot(R.ball[0] - prevBall[0], R.ball[1] - prevBall[1]) * 60;
    if (!R.scene && !R.owner && !R.fl && !cut && !R.setup && bs < 0.3) { R._idleBall = (R._idleBall || 0) + 1 / 60; if (R._idleBall > 3) { add('誰も拾わない止まった球が3秒以上(合間)', tag()); R._idleBall = -99; } } else if (R.owner) R._idleBall = 0;
    // 地を這う球が相手の体を通り抜ける（0.5m 以内を通っても触らない）
    if (!R.owner && R.fl && R.fl.kind === 'ground' && R.fl.by && !cut) { for (const o of Object.keys(R.disp)) { if (!R.base[o] || R.teamOf(o) === R.teamOf(R.fl.by) || R.fl.recv === o) continue; const d = Math.hypot(R.disp[o][0] - R.ball[0], R.disp[o][1] - R.ball[1]); if (d < 0.5 && Math.hypot(R.ball[0] - R.fl.from[0], R.ball[1] - R.fl.from[1]) > 2) { R.fl._thru = R.fl._thru || {}; if (!R.fl._thru[o]) { R.fl._thru[o] = 1; add('地を這う球が相手の体を通り抜ける(' + (R.scene ? '場面' : '合間') + ')', tag() + ' 誰' + o + (R.stgt && R.stgt[o] ? '台本' : '') + ' icpt' + R.fl.icpt + ' recv' + R.fl.recv + ' 蹴' + R.fl.by + ' 距離' + R.fl.d.toFixed(1) + ' t' + R.fl.t.toFixed(2)); } } } }
    // キックオフで相手陣に立つ
    if (R._koCheck) { R._koCheck = false; for (const id of Object.keys(R.disp)) { if (!R.base[id] || id === R.owner) continue; const dd = R.atkDir(id)[1] > 0 ? R.disp[id][1] : L - R.disp[id][1]; if (dd > L / 2 + 0.5) add('キックオフで相手陣に立つ', tag()); } }
    // 同じ2人の往復パス
    prev = {}; for (const id of Object.keys(R.disp)) prev[id] = R.disp[id].slice();
    prevOwner = R.owner; prevBall = R.ball.slice();
  };
  let g = 0;
  while (!m.finished && g++ < 4000) {
    const e = m.step();
    if (e.type === 'scene') {
      const sc = e.scene; const side = sc.side;
      const ot = R.owner ? R.teamOf(R.owner) : null;
      if (ot && ((side === 'home') !== (ot === m.home))) add('場面の入りで攻める側と持っている側が逆', 's' + seed + ' ' + T.toFixed(1));
      R.startScene(sc); let n = 0; while (R.t < sc.dur && n++ < 1200) step();
      for (let i = 0; i < 40; i++) step();
      if (sc.outcome === 'goal') { lastGoalSide = side; firstAfterGoal = true; }
      if (sc.outcome === 'saved' || sc.outcome === 'missed' || sc.outcome === 'lost' || sc.outcome === 'cleared') { const ot2 = R.owner ? R.teamOf(R.owner) : null; if (ot2 && ((side === 'home') === (ot2 === m.home)) && sc.outcome === 'saved') add('GK が止めたのに攻めた側が持っている', tag()); }
      if (sc.outcome === 'intercepted' || sc.outcome === 'stopped') { const ot3 = R.owner ? R.teamOf(R.owner) : null; if (ot3 && ((side === 'home') === (ot3 === m.home))) add('奪われた場面のあと攻めた側が持っている(' + sc.outcome + ')', tag()); }
      add('(参考)場面の結果:' + sc.outcome);
      R.endScene();
    }
    for (let i = 0; i < 48; i++) step();
  }
  add('(参考)場面の数'); c['(参考)場面の数'] += (m.scenes ? m.scenes.length : 0) - 1;
  c['(参考)入りで奪った'] = (c['(参考)入りで奪った'] || 0) + (R.steals || 0);
  c['(参考)暗転して置き直した'] = (c['(参考)暗転して置き直した'] || 0) + (R.places || 0);
}
console.log('試合 ' + SEEDS.length + ' つ'); if (process.env.OUT) require('fs').writeFileSync(process.env.OUT, JSON.stringify({ n: SEEDS.length, c, ex }));
for (const k of Object.keys(c).sort()) console.log((c[k] / SEEDS.length).toFixed(1).padStart(6) + ' /試合  ' + k + (ex[k] ? '   例: ' + ex[k].join(' | ') : ''));
// 上限（1試合あたり）。0 のものは出たら落とす。場面の台本どおりに動かす所（受け手のほかはボールに触らない）は少し残る
const LIMIT = {
  '自分へのパス': 0,
  '選手の瞬間移動(1コマ0.4m超)': 0,
  'GK がゴールから30m 以上': 0,
  '外に出たボールが1.5秒以上そのまま(合間)': 0,
  '合間に6秒以上持ち続ける': 0,
  '合間の55m超のパス': 0,
  '後ろへの30m超のパス': 0,
  'キックオフで相手陣に立つ': 0,
  '合間にボールがゴールの中へ': 0,
  '得点した側がキックオフ': 0,
  'ボールの瞬間移動(1コマ0.8m超)': 0.3,
  'GK がエリアの外でボールを持つ(回)': 0.3,
  '外に出たボールを持っている(回)': 0.6,
  '持ち主が相手へ直接替わった(合間)': 0.8,
  '持ち主が相手へ直接替わった(入り)': 0.5,
  '持ち主が相手へ直接替わった(場面)': 0.3,
  '地を這う球が相手の体を通り抜ける(合間)': 0.8,
  '地を這う球が相手の体を通り抜ける(場面)': 2.5,
  '相手の方が先に着く所へのパス(合間)': 2,
  'オフサイドの位置の味方へのパス': 0.5,
  '誰も拾わない止まった球が3秒以上(合間)': 0.3,
  '同じ2人で2往復のパス(合間)': 0.5,
  '選手がピッチの外2m 以上': 0,
};
let fails = 0;
for (const k of Object.keys(c)) {
  if (k.indexOf('相手の足元を狙ったパス') === 0 && c[k] > 0) { fails++; console.log('FAIL: ' + k + ' ' + c[k] + '回（パスは味方を狙い、失うのは切られる・それる・奪われるで）'); }
  if (LIMIT[k] != null && c[k] / SEEDS.length > LIMIT[k]) { fails++; console.log('FAIL: ' + k + ' 1試合 ' + (c[k] / SEEDS.length).toFixed(2) + '回（上限 ' + LIMIT[k] + '）'); }
}
console.log(fails ? '失敗 ' + fails : 'おかしな動きの点検: すべて通過');
process.exit(fails ? 1 : 0);
