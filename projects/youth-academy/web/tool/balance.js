// 釣り合いの点検：複数のシードで数年ずつおまかせで回し、例外・異常な数・人数の減少・予算の暴走・評価の張り付き・
// 昇降格の偏り・プロ級の割合（決定75：12人中2〜3人）・1週の想定時間を調べる。
//   node tool/balance.js            … CI と同じ（6シード×3年＋1部と3部）
//   node tool/balance.js 10 20      … シード10個×20年（長い試し）
'use strict';
const path = require('path');
for (const f of ['data', 'engine', 'world', 'league', 'club', 'scout', 'extra', 'more']) require(path.join(__dirname, '../src/' + f + '.js'));
const YA = globalThis.YA;
let fails = 0;
const ok = (c, m) => {
  if (!c) {
    fails++;
    console.log('FAIL:', m);
  }
};
const seeds = +process.argv[2] || 6;
const years = +process.argv[3] || 3;

const all = [];
const t0 = Date.now();
const runs = [];
for (let sd = 1; sd <= seeds; sd++) runs.push({ seed: sd, tier: 2, years });
runs.push({ seed: 101, tier: 1, years: Math.min(2, years) }, { seed: 102, tier: 3, years: Math.min(2, years) });
for (const r of runs) {
  const st = YA.testStart(r);
  for (let y = 0; y < r.years; y++) {
    let rep;
    try {
      rep = YA.testYear(st);
    } catch (e) {
      ok(false, `例外 seed${r.seed} 年${y + 1}: ${e && e.stack ? e.stack.split('\n').slice(0, 3).join(' | ') : e}`);
      break;
    }
    const m = rep.metrics;
    all.push(Object.assign({ seed: r.seed }, m));
    const bad = YA.findBadNumber(st.w);
    ok(!bad, `数の異常 seed${r.seed} 年${y + 1}: ${bad}`);
    ok(m.players >= 34 && m.players <= 44, `人数 seed${r.seed} 年${y + 1}: ${m.players}`);
    ok(m.budget >= 500 && m.budget <= 9000 && m.salaries <= m.budget, `予算 seed${r.seed} 年${y + 1}: ${m.budget}（給料${m.salaries}）`);
    ok(m.trustAfter >= 0 && m.trustAfter <= 100 && m.repAfter >= 0 && m.repAfter <= 100, '信頼度・評判の範囲');
  }
  ok(st.w.alumni.length >= 12 * Math.min(2, r.years), `卒業生が積み上がる seed${r.seed}`);
}
console.log(`回した年数 ${all.length}（${((Date.now() - t0) / 1000).toFixed(0)}秒）`);

// 1週ごとの点検（1つのシード）：人数・異常な数・止まらない
{
  const st = YA.testStart({ seed: 7, years: 1 });
  let weeks = 0;
  while (st.w.year === 1 && weeks < 60) {
    const rep = YA.simulate(st.w, { until: 'week', stopOnImportant: false });
    weeks++;
    const n = Object.keys(st.w.players).length;
    ok(n >= 30 && n <= 44, `週ごとの人数 ${weeks}週: ${n}`);
    const bad = YA.findBadNumber(st.w);
    if (bad) {
      ok(false, `週ごとの数の異常 ${weeks}週: ${bad}`);
      break;
    }
    ok(rep.weeks === 1, '1週ずつ進む');
  }
  ok(weeks === 40, `1年は40週 ${weeks}`);
}

// 同じシードなら同じ結果
{
  const a = YA.runTest({ seed: 9, years: 1 });
  const b = YA.runTest({ seed: 9, years: 1 });
  ok(JSON.stringify(a.years[0].metrics) === JSON.stringify(b.years[0].metrics) && JSON.stringify(a.years[0].lines) === JSON.stringify(b.years[0].lines), '同じシードで同じ結果');
  const c = YA.runTest({ seed: 10, years: 1 });
  ok(JSON.stringify(a.years[0].metrics) !== JSON.stringify(c.years[0].metrics), '違うシードで違う結果');
}

// 集計
const n = all.length;
const share = (f) => all.filter(f).length / n;
const mean = (f) => all.reduce((a, m) => a + f(m), 0) / n;
const letters = {};
for (const m of all) letters[m.letter] = (letters[m.letter] || 0) + 1;
const maxLetter = Math.max(...Object.values(letters)) / n;
ok(Object.keys(letters).length >= 3 && maxLetter <= 0.8, `評価が張り付いていない ${JSON.stringify(letters)}`);
const moves = { up: all.filter((m) => m.move < 0).length, down: all.filter((m) => m.move > 0).length, stay: all.filter((m) => m.move === 0).length };
// 小さい標本（6シード×3年）では揺れる。長い試し（10シード×3年）では維持が4割前後
ok(moves.stay / n >= 0.25, `昇降格が多すぎない ${JSON.stringify(moves)}`);
ok(moves.up + moves.down >= 2, `昇降格がまったく無いのは偏り ${JSON.stringify(moves)}`);
if (moves.up + moves.down >= 6) ok(Math.min(moves.up, moves.down) / (moves.up + moves.down) >= 0.15, `昇格・降格の偏り ${JSON.stringify(moves)}`);
const pro = mean((m) => m.gradPaths.pro);
ok(pro >= 1.2 && pro <= 4, `プロ級の割合が決定75の目安（12人中2〜3人）から離れすぎない: ${pro.toFixed(2)}人/年`);
ok(share((m) => m.trustAfter >= 99 || m.trustAfter <= 1) <= 0.4, '信頼度が上限・下限に張り付いていない');
const minutes = mean((m) => m.minutesPerWeek);
ok(minutes >= 1.5 && minutes <= 10, `1週の想定時間が目標（8〜10分以内）: ${minutes.toFixed(1)}分`);
ok(mean((m) => m.growthAvg) >= 8 && mean((m) => m.growthAvg) <= 40, `成長の速さが妥当: +${mean((m) => m.growthAvg).toFixed(1)}/年`);
ok(mean((m) => m.injuries) >= 1 && mean((m) => m.injuries) <= 30, `怪我の件数が妥当: ${mean((m) => m.injuries).toFixed(1)}件/年`);

console.log('評価', JSON.stringify(letters), '昇降格', JSON.stringify(moves), `プロ入り ${pro.toFixed(2)}人/年`, `成長 +${mean((m) => m.growthAvg).toFixed(1)}`, `怪我 ${mean((m) => m.injuries).toFixed(1)}`, `予算 ${mean((m) => m.budget).toFixed(0)}万`, `信頼度 ${mean((m) => m.trustAfter).toFixed(0)}`, `選ぶ回数/週 ${mean((m) => m.picksPerWeek).toFixed(1)}`, `想定 ${minutes.toFixed(1)}分/週`);
console.log(fails ? '失敗 ' + fails : '釣り合いの点検: すべて通過');
process.exit(fails ? 1 : 0);
