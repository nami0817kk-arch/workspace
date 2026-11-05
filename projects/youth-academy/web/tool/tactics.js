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
    m.homeShare = () => 0.5; // 力の差による「流れ」は切り離して、戦い方の差だけを見る
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
// 守りのブロックがボールの近くに固まるので、堅守でも持っている子の近くには誰かがいる（差は 1.5m を見る）
ok(r['堅守'].press - r['ハイプレス'].press > 1.5, 'ハイプレスは持っている相手に堅守より 1.5m 以上近い（' + (r['堅守'].press - r['ハイプレス'].press).toFixed(1) + 'm）');
ok(r['ポゼッション'].hold > r['縦に速い'].hold * 1.4, 'ポゼッションは縦に速いより長く持つ（' + r['ポゼッション'].hold.toFixed(2) + '秒 / ' + r['縦に速い'].hold.toFixed(2) + '秒）');
// 試合の流れ：押している側（homeShare が高い）ほどボールを持ち、相手陣にいる
const flowOf = (share) => {
  let poss = 0, n = 0, deep = 0, fr = 0;
  for (const seed of [3, 8, 21]) {
    const w = YA.newWorld(seed);
    const home = YA.teamFromWorld(w, 'A');
    const away = YA.makeOpponent(YA.opponentOf(w), seed * 7);
    const m = new YA.Match({ seed, home, away, settings: { autoStop: false } });
    m.homeShare = () => share;
    const R = new YA.Renderer(cv);
    R.setMatch(m);
    for (let i = 0; i < 60 * 90; i++) {
      R.update(1 / 60);
      fr++;
      if (R.owner) { n++; if (R.base[R.owner][2] === home) poss++; }
      if (R.ball[1] > 70) deep++;
    }
  }
  return { poss: poss / n, deep: deep / fr };
};
const lo = flowOf(0.3);
const hi = flowOf(0.7);
console.log('流れ 0.3：保持 ' + (lo.poss * 100).toFixed(0) + '% 相手陣の奥 ' + (lo.deep * 100).toFixed(0) + '%　流れ 0.7：保持 ' + (hi.poss * 100).toFixed(0) + '% 相手陣の奥 ' + (hi.deep * 100).toFixed(0) + '%');
ok(hi.poss - lo.poss > 0.1, '押している側がボールを長く持つ');
ok(hi.deep > lo.deep * 1.5, '押している側は相手陣の奥にいる時間が長い');
// 能力：速い子ほど速く走り、パスのうまい子ほどパスが通る
{
  const top = {};
  const sp = {};
  const pass = { hi: [0, 0], lo: [0, 0] };
  for (const seed of [3, 8, 21, 34]) {
    const w = YA.newWorld(seed);
    const home = YA.teamFromWorld(w, 'A');
    const away = YA.makeOpponent(YA.opponentOf(w), seed * 7);
    const m = new YA.Match({ seed, home, away, settings: { autoStop: false } });
    const R = new YA.Renderer(cv);
    R.setMatch(m);
    let lastFl = null;
    let by = null;
    for (let i = 0; i < 60 * 120; i++) {
      R.update(1 / 60);
      for (const id of Object.keys(R.disp)) {
        const k = seed + ':' + id;
        top[k] = Math.max(top[k] || 0, R.speed[id] || 0);
        sp[k] = R.abOf(id, 'スピード');
      }
      if (R.fl && R.fl !== lastFl && R.fl.by) by = R.fl.by;
      lastFl = R.fl;
      if (by && R.owner && !R.fl) {
        const pv = R.abOf(by, 'パス');
        const okPass = R.teamOf(R.owner) === R.teamOf(by);
        const g = pv >= 12 ? pass.hi : pv <= 9 ? pass.lo : null;
        if (g) { g[0]++; if (okPass) g[1]++; }
        by = null;
      }
    }
  }
  const ks = Object.keys(top).filter((k) => top[k] > 3);
  const xs = ks.map((k) => sp[k]);
  const ys = ks.map((k) => top[k]);
  const mx = avg(xs);
  const my = avg(ys);
  const cov = xs.reduce((a, x, i) => a + (x - mx) * (ys[i] - my), 0);
  const corr = cov / Math.sqrt(xs.reduce((a, x) => a + (x - mx) ** 2, 0) * ys.reduce((a, y) => a + (y - my) ** 2, 0));
  const rHi = pass.hi[1] / Math.max(1, pass.hi[0]);
  const rLo = pass.lo[1] / Math.max(1, pass.lo[0]);
  console.log('スピードと最高速の相関 ' + corr.toFixed(2) + '　パスが通った割合 パス12以上 ' + (rHi * 100).toFixed(0) + '%（' + pass.hi[0] + '本） パス9以下 ' + (rLo * 100).toFixed(0) + '%（' + pass.lo[0] + '本）');
  // スピードの上位4分の1と下位4分の1で、出した最高速の平均を比べる
  const srt = ks.slice().sort((p, q) => sp[p] - sp[q]);
  const qn = Math.max(1, Math.floor(srt.length / 4));
  const loTop = avg(srt.slice(0, qn).map((k) => top[k]));
  const hiTop = avg(srt.slice(-qn).map((k) => top[k]));
  console.log('最高速の平均 スピード上位 ' + hiTop.toFixed(2) + 'm/秒 下位 ' + loTop.toFixed(2) + 'm/秒');
  ok(corr > 0.3 && hiTop > loTop + 0.6, 'スピードの高い子ほど速く走る');
  ok(rHi > rLo + 0.04, 'パスのうまい子ほどパスが通る');
}
console.log(fails ? '失敗 ' + fails : '戦い方の動きの点検: すべて通過');
process.exit(fails ? 1 : 0);
