// 試合の絵の点検：ボールを持っていない子の動き（オフザボール）。
// 数字：攻める側の空き（持っていない子の、いちばん近い相手までの距離）、守る側のマーク（いちばん近い相手までの距離）、オフサイドの位置にいるコマ、最終ラインのばらつき
{ let r = 4242; Math.random = () => ((r = (r * 1103515245 + 12345) % 2147483648) / 2147483648); }
for (const f of ['data', 'engine', 'world', 'league', 'club', 'scout', 'extra', 'more', 'render']) require('../src/' + f + '.js');
const YA = globalThis.YA;
const cv = { getBoundingClientRect: () => ({ width: 844, height: 330 }), getContext: () => null };
const st = { space: [], mark: [], off: 0, n: 0, lineSd: [], kicks: 0, through: 0 };
for (const seed of [3, 8, 21]) {
  const w = YA.newWorld(seed); const home = YA.teamFromWorld(w, 'A'); const away = YA.makeOpponent(YA.opponentOf(w), seed * 7);
  const m = new YA.Match({ seed, home, away, settings: { autoStop: false } }); m.homeShare = () => 0.5;
  const R = new YA.Renderer(cv); R.setMatch(m);
  for (let i = 0; i < 60 * 120; i++) {
    R.update(1 / 60);
    if (!R.owner || R.cut > 0 || R.ff) continue;
    const at = R.teamOf(R.owner);
    const dir = R.atkDir(R.owner)[1];
    const dep = (y) => (dir > 0 ? y : 105 - y); // 攻める側から見た深さ
    const A = Object.keys(R.disp).filter((id) => R.teamOf(id) === at && R.base[id][3] !== 0);
    const D = Object.keys(R.disp).filter((id) => R.teamOf(id) !== at && R.base[id][3] !== 0);
    const last = Math.max(...D.map((id) => dep(R.disp[id][1])));
    const dd = (a, b) => Math.hypot(R.disp[a][0] - R.disp[b][0], R.disp[a][1] - R.disp[b][1]);
    for (const a of A) {
      if (a === R.owner) continue;
      st.space.push(Math.min(...D.map((d) => dd(a, d))));
      if (dep(R.disp[a][1]) > last + 1 && dep(R.disp[a][1]) > 52.5 && !(R.fl && R.expect === a)) st.off++;
      st.n++;
    }
    for (const d of D) st.mark.push(Math.min(...A.map((a) => dd(a, d))));
    // 守る側の最終ライン（深い4人）の深さのばらつき
    const ds = D.map((id) => dep(R.disp[id][1])).sort((x, y) => y - x).slice(0, 4);
    const mu = ds.reduce((x, y) => x + y, 0) / 4;
    st.lineSd.push(Math.sqrt(ds.reduce((x, y) => x + (y - mu) ** 2, 0) / 4));
  }
  st.kicks += R.kicks; st.through += R.throughs || 0;
}
const avg = (a) => a.reduce((x, y) => x + y, 0) / a.length;
const r = { space: avg(st.space), mark: avg(st.mark), off: st.off / st.n, line: avg(st.lineSd) };
console.log('攻める子の空き ' + r.space.toFixed(2) + 'm　守る子のマーク ' + r.mark.toFixed(2) + 'm　オフサイドの位置 ' + (r.off * 100).toFixed(1) + '%　最終ラインのばらつき ' + r.line.toFixed(2) + 'm　スルーパス ' + st.through + '/' + st.kicks);
// 入れる前（2026-11-05）：空き 10.8・マーク 9.6・オフサイド 5.1%・ばらつき 3.8・スルーパス 0
let fails = 0;
const ok = (c, msg) => { if (!c) { fails++; console.log('FAIL: ' + msg); } };
ok(r.mark < 8.5, '守る子が近くの相手を捕まえる');
ok(r.off < 0.01, '攻める子がオフサイドの位置に立たない');
ok(r.line < 3, '最終ラインが横一列にそろう');
ok(r.space > 9.5, '攻める子が相手のいない所に立つ');
ok(st.through >= 3, 'ラインの裏へのスルーパスが出る');
console.log(fails ? '失敗 ' + fails : 'オフザボールの点検: すべて通過');
process.exit(fails ? 1 : 0);
