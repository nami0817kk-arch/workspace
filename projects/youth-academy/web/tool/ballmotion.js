// 試合の絵の点検：ボールと選手の動きが物理として筋が通っているか。
// 画面と同じ順で、試合を進めながら Renderer.update を60コマ/秒で回す。canvas は空の代用品。
// - ボールは誰かが蹴る・触るときだけ向きと速さが変わる（勝手に曲がらない・ワープしない）
// - 持っているボールは足元にある
// - 選手は加速の上限を超えない（瞬間移動しない）。暗転の切り替えのコマは数えない
// - 場面は受け手が届いて最後まで進む（詰まって打ち切る場面がほとんど無い）
'use strict';
// 合間の動きは Math.random を使うので、点検では毎回同じ乱数にして結果を揺らさない
{ let r = 12345; Math.random = () => ((r = (r * 1103515245 + 12345) % 2147483648) / 2147483648); }
for (const f of ['data', 'engine', 'world', 'league', 'club', 'scout', 'extra', 'more', 'render']) require('../src/' + f + '.js');
const YA = globalThis.YA;
// 入学時の水準を下げた（決定100）ので、動きの点検は昔の水準（能力+1）の世界で回す。動きの筋が通っているかを見る点検で、世界の強さを見るものではない
const lift = (w) => { for (const p of Object.values(w.players)) for (const k of Object.keys(p.ab)) p.ab[k] = Math.min(20, p.ab[k] + (+process.env.YA_LIFT || 1)); return w; };
const cv = { getBoundingClientRect: () => ({ width: 844, height: 330 }), getContext: () => null, width: 0, height: 0 };
let fails = 0;
const ok = (c, msg) => { if (!c) { fails++; console.log('FAIL: ' + msg); } };
const st = { goals: 0, goalIn: 0, missIn: 0, frames: 0, scenes: 0, ballMax: 0, jerk: 0, farFoot: 0, pMax: 0, accOver: 0, kicks: 0, stuck: 0, long: 0, places: 0, ffT: 0, overlap: 0, ovScene: 0, measured: 0, tackles: 0, cuts: 0 };
for (const seed of (process.env.YA_SEEDS ? process.env.YA_SEEDS.split(',').map(Number) : [3, 8, 21, 4, 9, 22])) { // 42場面ほどの標本は揺れが大きい（master でも置き直しは 5〜7 回）ので、6シード・上限2割で見る
  const w = lift(YA.newWorld(seed));
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
    const cut = R.cut > 0.05 || R.ff; // 早送りのコマは物理の速さで測らない
    if (R.ff) st.ffT += dt;
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
      const ids0 = Object.keys(R.disp);
      for (let i = 0; i < ids0.length; i++) for (let j = i + 1; j < ids0.length; j++) if (Math.hypot(R.disp[ids0[i]][0] - R.disp[ids0[j]][0], R.disp[ids0[i]][1] - R.disp[ids0[j]][1]) < 1.0) { st.overlap++; if (R.scene) st.ovScene++; }
      st.measured++;
      for (const id of Object.keys(R.disp)) {
        const p = R.disp[id];
        if (!prevP[id]) continue;
        if (R.dive && R.dive.id === id && R.dive.t >= R.dive.t0 && R.dive.t < R.dive.end + 0.1) { delete prevPV[id]; continue; } // シュートに飛ぶ GK は走りではない（一瞬で飛びつく）
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
  st.places += R.places || 0;
  st.celebs = (st.celebs || 0) + (R.celebs || 0);
  st.dives = (st.dives || 0) + (R.dives || 0);
  st.saves = (st.saves || 0) + (R.saves || 0);
  st.catches = (st.catches || 0) + (R.catches || 0);
  st.tackles += R.tackles || 0;
  st.cuts += R.cuts || 0;
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
// セットプレー（ライン際から始まる場面）と、誰も持っていない球から始まる場面は置き直してよい。残りはボールをつないで入る
ok(st.places <= st.scenes * 0.2, '場面の入りで暗転して置き直した回数 ' + st.places + '／場面 ' + st.scenes);
// 離れる動きを入れる前は 0.109
ok(st.overlap / st.measured < 0.07, '選手どうしが1m未満に重なった組（1コマあたり ' + (st.overlap / st.measured).toFixed(3) + '）');
ok(st.tackles + st.cuts > 4, '合間のタックル・パスカット ' + st.tackles + '・' + st.cuts);
ok(st.ffT / st.scenes < 3, '場面の入りの早送りは1場面あたり3秒未満（' + (st.ffT / st.scenes).toFixed(2) + '秒）');
ok(st.goals > 0 && st.goalIn === st.goals, '得点の場面でボールが網に入る ' + st.goalIn + '／' + st.goals);
ok(st.missIn === 0, '外れの場面で網に入った ' + st.missIn);
ok(st.celebs === st.goals, '得点のたびに喜ぶ ' + st.celebs + '／' + st.goals);
ok(st.dives >= st.goals, 'シュートに GK が飛ぶ ' + st.dives);
ok(st.saves > 0 && st.catches >= st.saves * 0.8, '止める場面で GK が飛びついてつかむ ' + st.catches + '／' + st.saves);
console.log(fails ? '失敗 ' + fails : 'ボールの動きの点検: すべて通過');
process.exit(fails ? 1 : 0);
