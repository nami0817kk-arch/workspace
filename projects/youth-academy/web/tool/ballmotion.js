// 試合の絵の点検：ボールが瞬間移動しないか（1コマごとの速さを測る）。
// 画面と同じ順で、試合を進めながら Renderer.update を60コマ/秒で回す。canvas は空の代用品。
'use strict';
for (const f of ['data', 'engine', 'world', 'league', 'club', 'scout', 'extra', 'more', 'render']) require('../src/' + f + '.js');
const YA = globalThis.YA;
const cv = { getBoundingClientRect: () => ({ width: 844, height: 330 }), getContext: () => null, width: 0, height: 0 };
let fails = 0;
const ok = (c, msg) => { if (!c) { fails++; console.log('FAIL: ' + msg); } };
let worst = 0, cuts = 0, scenes = 0, frames = 0, over = 0, pWorst = 0, pOver = 0;
for (const seed of [3, 8, 21]) {
  const w = YA.newWorld(seed);
  const home = YA.teamFromWorld(w, 'A');
  const away = YA.makeOpponent(YA.opponentOf(w), seed * 7);
  const m = new YA.Match({ seed, home, away, settings: { autoStop: false } });
  const R = new YA.Renderer(cv);
  R.setMatch(m);
  const dt = 1 / 60;
  let g = 0;
  let prev = R.ball.slice();
  const step = () => {
    R.update(dt);
    frames++;
    const v = Math.hypot(R.ball[0] - prev[0], R.ball[1] - prev[1]) / dt;
    // 画面が暗いあいだ（場面の切り替え）は数えない
    if (!(R.cut > 0.05)) { worst = Math.max(worst, v); if (v > 45) over++; }
    prev = R.ball.slice();
    // 選手：全力疾走は 9〜10m/s。切り替えの直後は数えない
    if (!(R.cut > 0.05)) for (const id of Object.keys(R.speed || {})) { const v2 = R.speed[id]; pWorst = Math.max(pWorst, v2); if (v2 > 14) pOver++; }
  };
  while (!m.finished && g++ < 4000) {
    const e = m.step();
    if (e.type === 'scene') {
      scenes++;
      R.startScene(e.scene);
      if (R.cut > 0) cuts++;
      while (R.t < e.scene.dur) step();
      R.endScene();
    }
    for (let i = 0; i < 30; i++) step(); // 合間 0.5 秒
  }
}
console.log('選手の最大の速さ', pWorst.toFixed(1) + 'm/s', '14m/s 超え', pOver);
console.log('コマ', frames, '場面', scenes, '切り替え', cuts, 'ボールの最大の速さ', worst.toFixed(1) + 'm/s', '45m/s 超え', over);
ok(scenes > 10, '場面が出る');
ok(worst < 50, 'ボールが瞬間移動しない（最大 ' + worst.toFixed(1) + 'm/s）');
ok(over <= frames * 0.002, '速すぎるコマがほとんど無い ' + over);
ok(pWorst < 30 && pOver <= frames * 22 * 0.002, '選手が瞬間移動しない ' + pOver + '（最大 ' + pWorst.toFixed(1) + 'm/s）');
console.log(fails ? '失敗 ' + fails : 'ボールの動きの点検: すべて通過');
process.exit(fails ? 1 : 0);
