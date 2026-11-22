// 試合の絵の点検：選手の頭（2026-11-22「試合の動きを AI に」）。
// - 止まっている子がいない（場面・合間とも）、2秒以上止まったままがほとんど無い
// - 早送りが無い（「急なスピードアップはやめて」）
// - 守りのブロックが現実に近い：縦は30〜34m前後、ボール側へ寄る
// - 能力で動きが変わる：頭の能力（ポジショニング・オフザボール・判断・視野・マーク…）が高いチームほど、
//   最終ラインがそろい、攻める子が空いた所に立つ
'use strict';
{ let r = 12345; Math.random = () => ((r = (r * 1103515245 + 12345) % 2147483648) / 2147483648); }
for (const f of ['data', 'engine', 'world', 'league', 'club', 'scout', 'extra', 'more', 'render']) require('../src/' + f + '.js');
const YA = globalThis.YA;
const L = 105;
const cv = { getBoundingClientRect: () => ({ width: 844, height: 330 }), getContext: () => null, width: 0, height: 0 };
let fails = 0;
const ok = (c, msg) => { if (!c) { fails++; console.log('FAIL: ' + msg); } };
const med = (a) => { const s = a.filter(isFinite).sort((x, y) => x - y); return s.length ? s[Math.floor(s.length / 2)] : NaN; };
const avg = (a) => a.reduce((x, y) => x + y, 0) / Math.max(1, a.length);
const dist = (a, b) => Math.hypot(a[0] - b[0], a[1] - b[1]);

// 1. 試合を通して：止まっている子・早送り・守りの形
const st = { sS: 0, nS: 0, sI: 0, nI: 0, long2: 0, ffT: 0, t: 0, dl: [], side: [], games: 0 };
for (const seed of [3, 8, 21]) {
  const w = YA.newWorld(seed);
  const m = new YA.Match({ seed, home: YA.teamFromWorld(w, 'A'), away: YA.makeOpponent(YA.opponentOf(w), seed * 7), settings: { autoStop: false } });
  const R = new YA.Renderer(cv);
  R.setMatch(m);
  st.games++;
  const dt = 1 / 60;
  let prev = {};
  const still = {};
  let k = 0;
  const step = () => {
    R.update(dt);
    st.t += dt;
    if (R.ff && !R.cut) st.ffT += dt;
    const cut = R.cut > 0.05;
    for (const id of Object.keys(R.disp)) {
      const p = R.disp[id];
      if (!prev[id] || cut || R.celeb || !R.base[id] || R.base[id][3] === 0) continue;
      const s = Math.hypot(p[0] - prev[id][0], p[1] - prev[id][1]) / dt < 0.4;
      if (R.scene) { st.nS++; if (s) st.sS++; } else { st.nI++; if (s) st.sI++; }
      if (s) still[id] = (still[id] || 0) + dt;
      else { if ((still[id] || 0) > 2) st.long2++; still[id] = 0; }
    }
    prev = {};
    for (const id of Object.keys(R.disp)) prev[id] = R.disp[id].slice();
    // 守る側の形（場面の外、持ち主がいるとき）
    if (!R.scene && !cut && !R.celeb && R.owner && R.teamOf(R.owner) && !(k++ % 15)) {
      const at = R.teamOf(R.owner);
      const dir = R.atkDir(R.owner)[1];
      const dep = (y) => (dir > 0 ? y : L - y);
      const D = Object.keys(R.base).filter((id) => R.base[id][3] !== 0 && R.teamOf(id) !== at);
      const ys = D.map((id) => dep(R.disp[id][1]));
      st.dl.push(Math.max(...ys) - Math.min(...ys));
      const bx = R.ball[0] - 34;
      if (Math.abs(bx) > 8) st.side.push((avg(D.map((id) => R.disp[id][0])) - 34) / bx);
    }
  };
  let g = 0;
  while (!m.finished && g++ < 4000) {
    const e = m.step();
    if (e.type === 'scene') { R.startScene(e.scene); let n = 0; while (R.t < e.scene.dur && n++ < 1200) step(); for (let i = 0; i < 40; i++) step(); R.endScene(); }
    for (let i = 0; i < 48; i++) step(); // 合間は画面と同じ 0.8 秒ずつ（ui.js の need）
  }
}
const r1 = { scene: st.sS / st.nS, idle: st.sI / st.nI, long2: st.long2 / st.games, ff: st.ffT, len: med(st.dl), side: med(st.side) };
console.log('止まっている子 場面 ' + (r1.scene * 100).toFixed(1) + '%・合間 ' + (r1.idle * 100).toFixed(1) + '%　2秒以上止まったまま 1試合 ' + r1.long2.toFixed(1) + '回　早送り ' + r1.ff.toFixed(1) + '秒　守りの縦 ' + r1.len.toFixed(1) + 'm　ボール側への寄り ' + r1.side.toFixed(2));
// 入れる前（2026-11-22）：場面 21%・合間 8%・2秒以上 63回/試合・早送り 23秒/試合・縦 39m・寄り 0.13（合間を0.8秒ずつで測った値）
ok(r1.scene < 0.08, '場面のあいだ止まっている子が少ない');
ok(r1.idle < 0.05, '合間に止まっている子が少ない');
ok(r1.long2 < 10, '2秒以上止まったままの子がほとんどいない');
ok(r1.ff < 0.5, '早送りが無い');
ok(r1.len > 26 && r1.len < 35, '守りの縦の長さが現実に近い'); // 2026-11-23：パスの落ちる所を見て先にずれるようにして 35→31m
ok(r1.side > 0.38, '守りがボール側へ寄る'); // 2026-11-23：0.33→0.47 倍

// 2. 能力で頭の選び方が変わる：試合の同じ瞬間に、1つの能力だけを高く（18）／低く（4）したと仮定して、頭が選ぶ場所を比べる
//    （試合まるごとで比べると、選び方が変わるたびに展開がずれて、乱数の揺れに埋もれる）
{
  const w = YA.newWorld(8);
  const home = YA.teamFromWorld(w, 'A');
  const m = new YA.Match({ seed: 8, home, away: YA.makeOpponent(YA.opponentOf(w), 56), settings: { autoStop: false } });
  m.homeShare = () => 0.5;
  const R = new YA.Renderer(cv);
  R.setMatch(m);
  const ab0 = R.ab01.bind(R);
  const with1 = (name, v, fn) => { R.ab01 = (id, n) => (n === name ? (v - 1) / 19 : ab0(id, n)); try { return fn(); } finally { R.ab01 = ab0; } };
  const r2 = { spHi: [], spLo: [], lnHi: [], lnLo: [], mkHi: [], mkLo: [] };
  for (let i = 0; i < 60 * 240; i++) {
    R.update(1 / 60);
    if (i % 20 || !R.owner || R.cut > 0 || R.fl || !R.teamOf(R.owner)) continue;
    const at = R.teamOf(R.owner);
    const key = at === m.away ? 'away' : 'home';
    const okey = key === 'away' ? 'home' : 'away';
    const li = R.lineInfo();
    for (const id of Object.keys(R.disp)) {
      if (!R.base[id] || R.base[id][3] === 0 || id === R.owner || (R.pressers && R.pressers[id])) continue;
      const mine = R.teamOf(id) === at;
      const an = R.offballPos(id);
      const opp = Object.keys(R.disp).filter((o) => R.base[o] && R.base[o][3] !== 0 && R.teamOf(o) !== R.teamOf(id));
      const pick = (name, v) => with1(name, v, () => { const o = R.choose(id, with1(name, v, () => R.offballPos(id)), {}); const a = with1(name, v, () => R.offballPos(id)); return [a[0] + o[0], a[1] + o[1]]; });
      if (mine) {
        // 空き：選んだ所のいちばん近い相手までの距離（オフザボール）
        const sp = (c) => Math.min(...opp.map((o) => dist(c, R.disp[o])));
        if (sp(an) > 10) continue; // 相手が近くにいて、外す動きが要るときだけ比べる
        // 相手の最終ラインに張りつく子（裏を狙う子）は、うまいほど線ぎりぎり＝相手の近くに立つので除く
        const dA = (y) => (key === 'home' ? y : 105 - y);
        if (dA(an[1]) > Math.max(...opp.map((o) => dA(R.disp[o][1]))) - 12) continue;
        if (process.env.DBG) { const ah = with1('オフザボール', 18, () => R.offballPos(id)); const al = with1('オフザボール', 4, () => R.offballPos(id)); const ph = pick('オフザボール', 18), pl = pick('オフザボール', 4); (r2.dbg = r2.dbg || []).push([sp(ah), sp(ph), sp(al), sp(pl), dist(ah, ph), dist(al, pl)]); }
        r2.spHi.push(sp(pick('オフザボール', 18)));
        r2.spLo.push(sp(pick('オフザボール', 4)));
      } else if (li.back[id]) {
        // 最終ライン：選んだ所とラインの高さの差（ポジショニング。読み違えのずれも足す）
        const dep = (y) => (key === 'away' ? y : 105 - y); // 守る側（okey）から見た深さ
        const ln = (v) => with1('ポジショニング', v, () => { const c = pick('ポジショニング', v); const e = (Math.random() - 0.5) * 2 * (1 - (v - 1) / 19) * 3.2; return Math.abs(dep(c[1]) + e - li.lineD[okey]); });
        r2.lnHi.push(ln(18));
        r2.lnLo.push(ln(4));
      } else {
        // マーク：選んだ所のいちばん近い相手までの距離（マーク）
        const mk = (c) => Math.min(...opp.filter((o) => o !== R.owner).map((o) => dist(c, R.disp[o])));
        r2.mkHi.push(mk(pick('マーク', 18)));
        r2.mkLo.push(mk(pick('マーク', 4)));
      }
    }
  }
  const sHi = avg(r2.spHi), sLo = avg(r2.spLo), lHi = avg(r2.lnHi), lLo = avg(r2.lnLo), mHi = avg(r2.mkHi), mLo = avg(r2.mkLo);
  console.log('オフザボール 18／4：空き ' + sHi.toFixed(2) + '／' + sLo.toFixed(2) + 'm　ポジショニング 18／4：ラインとの差 ' + lHi.toFixed(2) + '／' + lLo.toFixed(2) + 'm　マーク 18／4：相手との距離 ' + mHi.toFixed(2) + '／' + mLo.toFixed(2) + 'm（標本 ' + r2.spHi.length + '・' + r2.lnHi.length + '・' + r2.mkHi.length + '）');
  if (r2.dbg) console.log('立ち位置の空き 高 ' + avg(r2.dbg.map((x) => x[0])).toFixed(2) + ' 選んだ所 ' + avg(r2.dbg.map((x) => x[1])).toFixed(2) + ' 動いた距離 ' + avg(r2.dbg.map((x) => x[4])).toFixed(2) + '　低 ' + avg(r2.dbg.map((x) => x[2])).toFixed(2) + ' ' + avg(r2.dbg.map((x) => x[3])).toFixed(2) + ' ' + avg(r2.dbg.map((x) => x[5])).toFixed(2));
  ok(sHi > sLo + 0.3, 'オフザボールの高い子ほど空いた所を選ぶ');
  ok(lLo > lHi + 0.5, 'ポジショニングの高い子ほどラインの高さに立つ');
  ok(mLo > mHi + 0.3, 'マークの高い子ほど相手の近くに付く');
}
console.log(fails ? '失敗 ' + fails : '選手の頭の点検: すべて通過');
process.exit(fails ? 1 : 0);
