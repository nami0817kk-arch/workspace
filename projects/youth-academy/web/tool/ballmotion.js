// 試合の絵の点検：ボールと選手の動きが物理として筋が通っているか。
// 画面と同じ順で、試合を進めながら Renderer.update を60コマ/秒で回す。canvas は空の代用品。
// - ボールは誰かが蹴る・触るときだけ向きと速さが変わる（勝手に曲がらない・ワープしない）
// - 持っているボールは足元にある
// - 選手は加速の上限を超えない（瞬間移動しない）。暗転の切り替えのコマは数えない
// - 場面は受け手が届いて最後まで進む（詰まって打ち切る場面がほとんど無い）
'use strict';
for (const f of ['data', 'engine', 'world', 'league', 'club', 'scout', 'extra', 'more', 'render']) require('../src/' + f + '.js');
const YA = globalThis.YA;
const cv = { getBoundingClientRect: () => ({ width: 844, height: 330 }), getContext: () => null, width: 0, height: 0 };
let fails = 0;
const ok = (c, msg) => { if (!c) { fails++; console.log('FAIL: ' + msg); } };
const st = { goals: 0, goalIn: 0, missIn: 0, frames: 0, scenes: 0, ballMax: 0, jerk: 0, farFoot: 0, pMax: 0, accOver: 0, kicks: 0, stuck: 0, long: 0 };
for (const seed of [3, 8, 21]) {
  const w = YA.newWorld(seed);
  const home = YA.teamFromWorld(w, 'A');
  const away = YA.makeOpponent(YA.opponentOf(w), seed * 7);
  const m = new YA.Match({ seed, home, away, settings: { autoStop: false } });
  const R = new YA.Renderer(cv);
  R.setMatch(m);
  const dt = 1 / 60;
  let prevB = R.ball.slice();
  let prevV = [0, 0];
  let prevOwner = null;
  let prevP = {};
  let prevPV = {};
  let wasCut = false;
  const step = () => {
    R.update(dt);
    st.frames++;
    const v = [(R.ball[0] - prevB[0]) / dt, (R.ball[1] - prevB[1]) / dt];
    const cut = R.cut > 0.05;
    const afterCut = wasCut;
    wasCut = cut;
    if (!cut) {
      const sp = Math.hypot(v[0], v[1]);
      st.ballMax = Math.max(st.ballMax, sp);
      // 速さ・向きが急に変わったコマ：蹴った・触った（持ち主が替わった・持っている）のどれでもなければ不自然
      const dv = Math.hypot(v[0] - prevV[0], v[1] - prevV[1]);
      const touched = R.kicked || R.owner !== prevOwner || R.owner || prevOwner;
      const inNet = Math.abs(R.ball[0] - 34) < 3.7 && (R.ball[1] < 0 || R.ball[1] > 105); // 網に受け止められる
      if (dv > 6 && !touched && !afterCut && !inNet) st.jerk++;
      if (R.owner && R.disp[R.owner] && Math.hypot(R.disp[R.owner][0] - R.ball[0], R.disp[R.owner][1] - R.ball[1]) > 1.8 && R.owner === prevOwner) st.farFoot++;
      for (const id of Object.keys(R.disp)) {
        const p = R.disp[id];
        if (!prevP[id]) continue;
        const pv = [(p[0] - prevP[id][0]) / dt, (p[1] - prevP[id][1]) / dt];
        st.pMax = Math.max(st.pMax, Math.hypot(pv[0], pv[1]));
        if (prevPV[id]) { const a = Math.hypot(pv[0] - prevPV[id][0], pv[1] - prevPV[id][1]) / dt; if (a > YA.MOVE.acc * 1.6) st.accOver++; }
        prevPV[id] = pv;
      }
    } else prevPV = {};
    prevB = R.ball.slice();
    prevV = cut ? [0, 0] : v;
    prevOwner = R.owner;
    prevP = {};
    for (const id of Object.keys(R.disp)) prevP[id] = R.disp[id].slice();
  };
  let g = 0;
  while (!m.finished && g++ < 4000) {
    const e = m.step();
    if (e.type === 'scene') {
      st.scenes++;
      R.startScene(e.scene);
      let n = 0;
      while (R.t < e.scene.dur && n++ < 60 * 20) step();
      if (R.t > 14) st.long++;
      // 得点の場面はボールが網の中で終わり、外れの場面は網に入らない
      const inNet = Math.abs(R.ball[0] - 34) < 3.66 && ((R.ball[1] < 0 && R.ball[1] > -2.3) || (R.ball[1] > 105 && R.ball[1] < 107.3));
      if (e.scene.outcome === 'goal') { st.goals++; if (inNet) st.goalIn++; }
      if (e.scene.outcome === 'missed' && inNet) st.missIn++;
      for (let i = 0; i < 40; i++) step(); // 得点・終わりの余韻
      R.endScene();
    }
    for (let i = 0; i < 30; i++) step(); // 合間 0.5 秒
  }
  st.kicks += R.kicks;
  st.stuck += R.stuck;
}
console.log(JSON.stringify(st));
ok(st.scenes > 30, '場面が出る');
ok(st.ballMax < 30, 'ボールが速すぎない（最大 ' + st.ballMax.toFixed(1) + 'm/s）');
ok(st.jerk === 0, '誰も触らずにボールの向き・速さが変わったコマ ' + st.jerk);
ok(st.farFoot <= st.frames * 0.001, '持っているボールが足元から離れたコマ ' + st.farFoot);
ok(st.pMax < 9.5, '選手の速さは全力疾走まで（最大 ' + st.pMax.toFixed(1) + 'm/s）');
ok(st.accOver === 0, '選手の加速の上限を超えたコマ ' + st.accOver);
ok(st.stuck <= st.scenes * 0.08, '受け手が届かず進めた回数 ' + st.stuck + '／場面 ' + st.scenes);
ok(st.long <= st.scenes * 0.05, '長すぎる場面 ' + st.long);
ok(st.goals > 0 && st.goalIn === st.goals, '得点の場面でボールが網に入る ' + st.goalIn + '／' + st.goals);
ok(st.missIn === 0, '外れの場面で網に入った ' + st.missIn);
console.log(fails ? '失敗 ' + fails : 'ボールの動きの点検: すべて通過');
process.exit(fails ? 1 : 0);
