// 試合の数字の点検（2026-11-17「試合の直し」）：PK・直接FK・GK の採点・カードと退場・相手の交代と戦い方・再開・追加時間・
// 自動停止・実況の繰り返し・守備の手柄・札の出し方・つまみと型・相手陣での奪取
'use strict';
const path = require('path');
module.exports = (YA, ok) => {
  if (!YA.Renderer) require(path.join(__dirname, '../../src/render.js'));
  const N = 300;
  const mk = (s, opts) => new YA.Match(Object.assign({ seed: s, home: YA.makeOurs(1), away: YA.makeOpponent(YA.OPPONENTS[s % 3], s * 7 + 3), settings: { autoStop: false } }, opts || {}));
  const run = (m) => { let g = 0; const ev = []; while (!m.finished && g++ < 3000) ev.push(m.step()); return ev; };
  const c = { goals: 0, pk: 0, pkGoal: 0, pkOff: 0, fk: 0, fkGoal: 0, gkR: 0, gkN: 0, csR: 0, csN: 0, fR: 0, fN: 0, y: 0, r: 0, redOk: 0, oppSubs: 0, oppTac: 0, oppRmax: 0, extraScenes: 0, labels: 0, sideOpp: 0, sideN: 0, mf: 0, defN: 0, saved: 0, savedGkFx: 0, atkFx: 0, rep: 0, won: 0, carryHit: 0, carryN: 0, add1: true, add2: true };
  for (let s = 1; s <= N; s++) {
    const m = mk(s);
    const ev = run(m);
    c.goals += m.score.home + m.score.away;
    if (!(m.add1 >= 1 && m.add1 <= 3)) c.add1 = false;
    if (!(m.add2 >= 2 && m.add2 <= 5)) c.add2 = false;
    // 同じ実況が直近3行のうちに二度出ない
    const fl = ev.filter((e) => e.type === 'tick' && e.text && !e.key && !e.card).map((e) => e.text);
    for (let i = 1; i < fl.length; i++) if (fl.slice(Math.max(0, i - 3), i).indexOf(fl[i]) >= 0 && !/追加時間|交代|戦い方/.test(fl[i])) c.rep++;
    for (const sc of m.scenes) {
      if (sc.extra || /\+/.test(sc.ml || '')) c.extraScenes++;
      if (sc.type === 'pk') { c.pk++; if (sc.goal) c.pkGoal++; if (sc.outcome === 'missed' || sc.outcome === 'post') c.pkOff++; }
      if (sc.type === 'fk') { c.fk++; if (sc.goal) c.fkGoal++; }
      const att = sc.side === 'home' ? m.home : m.away;
      const def = sc.side === 'home' ? m.away : m.home;
      if (sc.outcome === 'saved') { c.saved++; if (sc.fxShow.some((f) => f.pid === sc.gk)) c.savedGkFx++; }
      if (['intercepted', 'cleared', 'stopped', 'blocked', 'offside', 'dispossessed', 'escaped', 'saved'].indexOf(sc.outcome) >= 0 && sc.fxShow.some((f) => att.players[f.pid])) c.atkFx++;
      if (sc.type === 'dribble' && sc.defs && sc.defs[0] && sc.outcome === 'dispossessed') {
        const ai = att.lineup.findIndex((x) => x.pid === sc.actors.dribbler);
        const di = def.lineup.findIndex((x) => x.pid === sc.defs[0]);
        // 攻める側の左（s.x<0.5）を止めに来るのは、守る側の右（s.x>=0.5）。同じ側の数字なら反対側
        if (ai >= 0 && di >= 0) { c.sideN++; if ((att.lineup[ai].x < 0.5) === (def.lineup[di].x < 0.5)) c.sideOpp++; }
      }
      for (const d of sc.defs || []) { const p = def.players[d]; if (p) { c.defN++; if (p.pos === 'MF') c.mf++; } }
      if (sc.type === 'counter' && sc.actors.carrier) {
        const i = att.lineup.findIndex((x) => x.pid === sc.actors.carrier);
        if (i >= 0) { c.carryN++; const rd = YA.ROLE_DEF[att.lineup[i].role]; if (rd && rd.tags.some((tg) => tg === 'carry' || tg === 'run')) c.carryHit++; }
      }
    }
    c.labels += m.log.filter((l) => l.ml && l.ml.indexOf('+') > 0).length;
    for (const t of [m.home, m.away]) {
      for (const p of Object.values(t.players)) {
        if (!(p.st && p.st.minutes > 0)) continue;
        if (t === m.away) c.oppRmax = Math.max(c.oppRmax, p.st.rating);
        if (p.pos === 'GK') {
          c.gkR += p.st.rating; c.gkN++;
          if (!(t === m.home ? m.score.away : m.score.home)) { c.csR += p.st.rating; c.csN++; }
        } else { c.fR += p.st.rating; c.fN++; }
        c.y += p.yellow ? 1 : 0;
        if (p.sentOff) { c.r++; if (!t.lineup.some((x) => x.pid === p.id) && !t.onPitch.has(p.id)) c.redOk++; }
      }
    }
    c.oppSubs += m.away.subsUsed;
    c.oppTac += m.log.filter((l) => l.side === 'away' && /戦い方/.test(l.text)).length;
    c.won += YA.matchNumbers ? YA.matchNumbers(m).won : 0;
  }
  const f2 = (x) => x.toFixed(2);
  console.log('  試合の数字（' + N + '試合）：得点' + f2(c.goals / N) + '　PK ' + f2(c.pk / N) + '本・決まる' + f2(c.pkGoal / c.pk) + '・枠外' + f2(c.pkOff / c.pk) + '　直接FK決まる' + f2(c.fkGoal / c.fk) +
    '　GK採点' + f2(c.gkR / c.gkN) + '（無失点' + f2(c.csR / c.csN) + '・フィールド' + f2(c.fR / c.fN) + '）　イエロー' + f2(c.y / N) + '・退場' + f2(c.r / N) + '　相手の交代' + f2(c.oppSubs / N) + '・戦い方' + f2(c.oppTac / N) + '　相手陣で奪った' + f2(c.won / N));
  ok(c.pk / N >= 0.18 && c.pk / N <= 0.38, 'PK は1試合0.2〜0.3本ほど（' + f2(c.pk / N) + '）');
  ok(c.pkGoal / c.pk >= 0.65 && c.pkGoal / c.pk <= 0.85 && c.pkOff / c.pk <= 0.16, 'PK は約75%決まり、枠外は15%まで（' + f2(c.pkGoal / c.pk) + '・' + f2(c.pkOff / c.pk) + '）');
  ok(c.fkGoal / c.fk >= 0.03 && c.fkGoal / c.fk <= 0.11, '直接FKが決まるのは5〜10%ほど（' + f2(c.fkGoal / c.fk) + '）');
  ok(c.gkR / c.gkN >= c.fR / c.fN - 0.1 && c.csR / c.csN >= 7, 'GK の採点がフィールドより下に張りつかず、無失点なら7以上（' + f2(c.gkR / c.gkN) + '・' + f2(c.csR / c.csN) + '）');
  ok(c.oppRmax <= 10, '相手の採点も10を超えない（' + c.oppRmax.toFixed(1) + '）');
  ok(c.y / N >= 0.8 && c.y / N <= 3.5, 'イエローカードが出る（1試合' + f2(c.y / N) + '枚）');
  ok(c.r > 0 && c.r / N < 0.25 && c.redOk === c.r, '退場は時々、退場した子はピッチから外れる（' + c.r + '人）');
  ok(c.oppSubs / N >= 1 && c.oppSubs / N <= 5 && c.oppTac > 0, '相手も交代し、点差で戦い方を変える');
  ok(c.add1 && c.add2 && c.extraScenes > 0 && c.labels > 0, '追加時間（前半1〜3分・後半2〜5分）があり、「45+2」の形で出る');
  ok(c.rep === 0, '場面の外の実況は、直近3行と同じ文を出さない（' + c.rep + '回）');
  ok(c.sideN > 50 && c.sideOpp / c.sideN < 0.1, 'ドリブルを止めに来るのは同じサイドの守り手（反対側 ' + f2(c.sideOpp / c.sideN) + '）');
  ok(c.mf / c.defN > 0.03, '守備の手柄に MF も入る（' + f2(c.mf / c.defN) + '）');
  ok(c.saved > 50 && c.savedGkFx / c.saved > 0.1, 'セーブの場面で GK の特性の札が出る（' + f2(c.savedGkFx / c.saved) + '）');
  ok(c.atkFx === 0, '守備の成功・オフサイド・セーブで攻める側の札を出さない（' + c.atkFx + '）');
  ok(c.carryN > 50 && c.carryHit / c.carryN > 0.3, 'カウンターの運ぶ役に、運ぶ・走る役割の子が選ばれる（' + f2(c.carryHit / c.carryN) + '）');
  ok(c.won / N > 0.5, '相手陣で奪った回数が数えられる（' + f2(c.won / N) + '）');

  // 自動停止：既定は自分の得点で止まらない。「得点でも止める」で止まる
  {
    let sc0 = 0, sc1 = 0, conc = 0;
    for (let s = 1; s <= 60; s++) {
      for (const on of [false, true]) {
        const m = mk(s, { settings: { autoStop: true, stopOnScore: on } });
        for (const e of run(m)) if (e.type === 'stop') { if (e.reason === 'scored') on ? sc1++ : sc0++; if (e.reason === 'conceded' && !on) conc++; }
      }
    }
    ok(sc0 === 0 && sc1 > 10 && conc > 5, '自動停止は既定で失点と節目だけ、設定で得点でも止まる（' + sc0 + '/' + sc1 + '）');
  }
  // 交代：一度下げた子はもう出られない
  {
    const m = mk(2);
    const t = m.home;
    m.min = 30;
    ok(m.substitute(t, 'me_9', 'me_17').ok, '交代できる');
    m.closeWindow(t);
    const r = m.canSub(t, 'me_17', 'me_9');
    ok(!r.ok && /もう出られません/.test(r.msg), '一度下げた子は戻せない');
  }
  // 型を替えても、攻める方向・クロスの種類・キッカーは残る。つまみを動かしても元の型で相性を見る
  {
    const m = mk(3);
    const t = m.home;
    const ids = Object.keys(t.players);
    Object.assign(t.tactic, { dir: 1, crossType: 'low', fk: ids[5], ck: ids[6], pk: ids[7] });
    m.setType(t, 'カウンター');
    ok(t.tactic.type === 'カウンター' && t.tactic.dir === 1 && t.tactic.crossType === 'low' && t.tactic.fk === ids[5] && t.tactic.ck === ids[6] && t.tactic.pk === ids[7], '型を替えてもキッカー・クロス・方向が残る');
    m.setType(t, 'ポゼッション');
    const f0 = m.tacticFit(t);
    YA.setKnob(t.tactic, 'tempo', 0.26);
    ok(t.tactic.type === 'カスタム' && t.tactic.baseType === 'ポゼッション' && Math.abs(m.tacticFit(t) - f0) < 1e-9 && f0 !== 0, 'つまみを1つ動かしても、元の型の相性が残る');
  }
  // 再開：最後に触ったチームで、ゴールキックかコーナーキック、スローインは相手ボール。キックオフは蹴る側から
  {
    const cv = { getBoundingClientRect: () => ({ width: 844, height: 330 }), getContext: () => null, width: 0, height: 0 };
    const m = mk(5);
    const R = new YA.Renderer(cv);
    R.setMatch(m);
    R.update(1 / 60);
    const ko = m.kickoffSide === 'away' ? m.away : m.home;
    ok(R.owner && R.teamOf(R.owner) === ko, '試合の始めは、キックオフの組がボールを持つ');
    const setOut = (b, last) => { R.scene = null; R.owner = null; R.setup = null; R.fl = null; R.ball = b; R.lastTouch = last; R.restart(); };
    setOut([20, 106, 0], m.away); // ホームが攻める側のゴールライン（y=105）を、守るアウェイが出した
    ok(R.lastRestart.kind === 'ck' && R.lastRestart.team === m.home && (R.ball[0] < 1 || R.ball[0] > 67), '守る側が出したらコーナーキック');
    setOut([20, 106, 0], m.home);
    ok(R.lastRestart.kind === 'gk' && R.lastRestart.team === m.away, '攻める側が出したらゴールキック');
    setOut([-1, 50, 0], m.home);
    ok(R.lastRestart.kind === 'throw' && R.lastRestart.team === m.away, 'スローインは最後に触ったのと逆のチーム');
    // 後半のキックオフは前半に蹴らなかった組
    let g = 0;
    while (!(m.halfDone && m.min >= 46) && g++ < 400) m.step();
    R.scene = null;
    R.update(1 / 60);
    const ko2 = m.kickoffSide === 'away' ? m.home : m.away;
    ok(R.owner && R.teamOf(R.owner) === ko2, '後半は前半に蹴らなかった組のキックオフ');
  }
};
