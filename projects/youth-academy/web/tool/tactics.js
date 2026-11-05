// 試合の絵の点検：戦い方で、画面の選手の動きが変わるか。
// 合間の動きだけを60コマ/秒で回し、ホームの戦い方ごとに次を測って比べる。
// - 守るときの最終ラインの高さ（ハイプレスは高く、堅守は低い）
// - 攻めるときの横の広がり（サイド攻撃は広い）
// - 持っている相手にいちばん近い守り手との距離（ハイプレスは近い）
// - 持ってから出すまでの時間（縦に速い・カウンターは短く、ポゼッションは長い）
'use strict';
// 合間の動きは Math.random を使うので、点検では毎回同じ乱数にして結果を揺らさない
{ let r = 12345; Math.random = () => ((r = (r * 1103515245 + 12345) % 2147483648) / 2147483648); }
for (const f of ['data', 'engine', 'world', 'league', 'club', 'scout', 'extra', 'more', 'render']) require('../src/' + f + '.js');
const YA = globalThis.YA;
const cv = { getBoundingClientRect: () => ({ width: 844, height: 330 }), getContext: () => null, width: 0, height: 0 };
let fails = 0;
const ok = (c, msg) => { if (!c) { fails++; console.log('FAIL: ' + msg); } };
const avg = (a) => a.reduce((x, y) => x + y, 0) / Math.max(1, a.length);

const measure = (type) => {
  const out = { line: [], width: [], press: [], hold: [] };
  for (const seed of [3, 8, 21]) {
    const w = YA.newWorld(seed);
    const home = YA.teamFromWorld(w, 'A');
    const away = YA.makeOpponent(YA.opponentOf(w), seed * 7);
    home.tactic = Object.assign({ type }, YA.TACTICS[type]);
    away.tactic = Object.assign({ type: 'ポゼッション' }, YA.TACTICS['ポゼッション']);
    const m = new YA.Match({ seed, home, away, settings: { autoStop: false } });
    const R = new YA.Renderer(cv);
    R.setMatch(m);
    let held = 0;
    let prevOwner = null;
    for (let i = 0; i < 60 * 90; i++) {
      R.update(1 / 60);
      if (R.cut > 0) continue;
      const ids = Object.keys(R.base).filter((id) => R.base[id][2] === home && R.base[id][3] !== 0);
      const ownerHome = R.owner && R.base[R.owner] && R.base[R.owner][2] === home;
      if (R.owner && !ownerHome && !R.fl) {
        if (R.ball[1] > 40 && R.ball[1] < 65) out.line.push(Math.min(...ids.map((id) => R.disp[id][1]))); // ボールが真ん中にあるとき
        const q = R.disp[R.owner];
        out.press.push(Math.min(...ids.map((id) => Math.hypot(R.disp[id][0] - q[0], R.disp[id][1] - q[1]))));
      }
      if (ownerHome && !R.fl) {
        const xs = ids.map((id) => R.disp[id][0]);
        out.width.push(Math.max(...xs) - Math.min(...xs));
      }
      // ホームの子が持ち続けた時間（持ち主が替わるかパスが出るまで）
      if (R.owner && R.owner === prevOwner && ownerHome) held += 1 / 60;
      else if (prevOwner && R.base[prevOwner] && R.base[prevOwner][2] === home && held > 0) { out.hold.push(held); held = 0; }
      prevOwner = R.owner;
    }
  }
  return { line: avg(out.line), width: avg(out.width), press: avg(out.press), hold: avg(out.hold) };
};

const r = {};
for (const t of Object.keys(YA.TACTICS)) {
  r[t] = measure(t);
  console.log(t.padEnd(8, '　'), 'ライン ' + r[t].line.toFixed(1) + 'm', '幅 ' + r[t].width.toFixed(1) + 'm', '寄せ ' + r[t].press.toFixed(1) + 'm', '持つ ' + r[t].hold.toFixed(2) + '秒');
}
ok(r['ハイプレス'].line - r['堅守'].line > 8, 'ハイプレスの最終ラインが堅守より 8m 以上高い（' + (r['ハイプレス'].line - r['堅守'].line).toFixed(1) + 'm）');
ok(r['サイド攻撃'].width - r['堅守'].width > 5, 'サイド攻撃の幅が堅守より 5m 以上広い（' + (r['サイド攻撃'].width - r['堅守'].width).toFixed(1) + 'm）');
ok(r['堅守'].press - r['ハイプレス'].press > 2, 'ハイプレスは持っている相手に堅守より 2m 以上近い（' + (r['堅守'].press - r['ハイプレス'].press).toFixed(1) + 'm）');
ok(r['ポゼッション'].hold > r['縦に速い'].hold * 1.4, 'ポゼッションは縦に速いより長く持つ（' + r['ポゼッション'].hold.toFixed(2) + '秒 / ' + r['縦に速い'].hold.toFixed(2) + '秒）');
console.log(fails ? '失敗 ' + fails : '戦い方の動きの点検: すべて通過');
process.exit(fails ? 1 : 0);
