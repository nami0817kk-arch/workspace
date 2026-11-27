// 釣り合いの点検：複数のシードで数年ずつおまかせで回し、例外・異常な数・人数の減少・予算の暴走・評価の張り付き・
// 昇降格の偏り・プロ級の割合（決定75：1学年11人中2〜3人）・課題と覚醒の数（年5〜7人前後）・1週の想定時間を調べる。
//   node tool/balance.js            … CI と同じ（6シード×3年＋1部と3部）
//   node tool/balance.js 10 20      … シード10個×20年（長い試し）
'use strict';
const path = require('path');
for (const f of ['data', 'engine', 'world', 'league', 'club', 'scout', 'extra', 'more', 'core', 'lineage', 'rivals', 'story', 'memory', 'chains', 'chains2', 'events2', 'staff', 'scout2', 'club5', 'life', 'func', 'pronews', 'staracts', 'shop', 'body', 'pos2', 'traits2', 'persona', 'cond2', 'stars2', 'kadai', 'kizuki', 'team2', 'records', 'paper', 'finish']) require(path.join(__dirname, '../src/' + f + '.js'));
const YA = globalThis.YA;
let fails = 0;
const ok = (c, m) => {
  if (!c) {
    fails++;
    console.log('FAIL:', m);
  }
};
// 2026-11-17：育成・クラブの釣り合いの直し（42〜62）に合わせて、疲れ・怪我・退団の理由・接し方・卒業時の平均・基金・大会も見る
const G = { fat: [], tired: 0, kinds: {}, injLong: 0, injAll: 0, matchInj: 0, maxKadai: 0, kadaiWeeks: 0, kzAt: {}, kzKind: {}, kzN: [], kzMiss: [] };
{
  // 気づきの場面（2026-11-27）：場所ごとの数・選んだ結果
  const ks = YA.kizukiSettle;
  YA.kizukiSettle = function (w, e, role) {
    const r = ks.apply(this, arguments);
    if (r.kind !== 'gone') { G.kzAt[e.at] = (G.kzAt[e.at] || 0) + 1; G.kzKind[r.kind] = (G.kzKind[r.kind] || 0) + 1; }
    return r;
  };
  const ew = YA.endWeek;
  YA.endWeek = function (w) {
    const ps = Object.values(w.players);
    G.fat.push(ps.reduce((a, p) => a + p.fat, 0) / ps.length);
    const nk = ps.filter((p) => p.kd).length;
    G.maxKadai = Math.max(G.maxKadai, nk);
    G.kadaiWeeks++;
    return ew.apply(this, arguments);
  };
  const re = YA.resolveEvent;
  YA.resolveEvent = function (w, e, i) {
    const d = YA.EVENTS.find((x) => x.id === e.id);
    const o = d && d.opts[i];
    if (o && o.kind && YA.KIND_LABEL[o.kind]) G.kinds[o.kind] = (G.kinds[o.kind] || 0) + 1;
    if (e.id === 'tired') G.tired++;
    return re.apply(this, arguments);
  };
}
const seeds = +process.argv[2] || 6;
const years = +process.argv[3] || 3;

const all = [];
const yrs = []; // 年ごとの控え（卒業時の平均・在学中のプロ・大会・基金・退団の理由）
const t0 = Date.now();
const runs = [];
for (let sd = 1; sd <= seeds; sd++) runs.push({ seed: sd, tier: 2, years });
runs.push({ seed: 101, tier: 1, years: years >= 6 ? years : Math.min(2, years) }, { seed: 102, tier: 3, years: years >= 6 ? years : Math.min(2, years) });
for (const r of runs) {
  const st = YA.testStart(r);
  for (let y = 0; y < r.years; y++) {
    let rep;
    const lv0 = st.w.leagueLevel;
    const al0 = st.w.alumni.length;
    const tr0 = (st.w.trophies || []).length;
    const yy = st.w.year;
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
    ok(m.players >= 31 && m.players <= 41, `人数 seed${r.seed} 年${y + 1}: ${m.players}`);
    ok(m.budget >= 500 && m.budget <= 9000 && m.salaries <= m.budget, `予算 seed${r.seed} 年${y + 1}: ${m.budget}（給料${m.salaries}）`);
    ok(m.trustAfter >= 0 && m.trustAfter <= 100 && m.repAfter >= 0 && m.repAfter <= 100, '信頼度・評判の範囲');
    const nw = st.w.alumni.slice(al0);
    const gr = nw.filter((a) => a.status !== 'left' && !/高.でトップ昇格/.test(a.note || '')).map((a) => YA.rate(a.ovr));
    yrs.push({ seed: r.seed, tier: r.tier, y: y + 1, level: lv0, gradAvg: gr.length ? gr.reduce((a, b) => a + b, 0) / gr.length : null, early: nw.filter((a) => /高.でトップ昇格/.test(a.note || '')).length,
      pro: m.gradPaths.pro, quits: nw.filter((a) => a.status === 'left').map((a) => (/退団（(.+)）/.exec(a.note || '') || [])[1] || '?'),
      cups: (st.w.trophies || []).slice(tr0).length, fund: st.w.fund || 0, total: st.w.club.total, injLong: st.w.inbox.filter((n) => n.year === y + 1 && /全治(\d+)週/.test(n.text) && +/全治(\d+)週/.exec(n.text)[1] >= 8).length,
      matchInj: st.w.inbox.filter((n) => n.year === y + 1 && /試合で怪我/.test(n.text)).length,
      awake: st.w.awakeN && st.w.awakeN.y === yy ? st.w.awakeN.n : 0, kgive: st.w.kadaiN && st.w.kadaiN.y === yy ? st.w.kadaiN.give || 0 : 0 });
    // 合う課題の後半に来た気づきの場面の数（覚醒まで／最後まで選べなかった課題）
    for (const p of Object.values(st.w.players)) for (const hh of p.kHist || []) if (hh.y === yy && hh.fit === 'yes') { if (hh.r === 'awake' || hh.r === 'miss') G.kzN.push(hh.n || 0); if (hh.r === 'miss') G.kzMiss.push(hh.n || 0); }
  }
  ok(st.w.alumni.length >= (YA.GRADE_N || 11) * Math.min(2, r.years), `卒業生が積み上がる seed${r.seed}（${st.w.alumni.length}人）`);
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
ok(Object.keys(letters).length >= 3 && maxLetter <= 0.7, `評価が張り付いていない ${JSON.stringify(letters)}`);
const moves = { up: all.filter((m) => m.move < 0).length, down: all.filter((m) => m.move > 0).length, stay: all.filter((m) => m.move === 0).length };
// 小さい標本（6シード×3年）では揺れる。長い試し（10シード×3年）では維持が4割前後
ok(moves.stay / n >= 0.25, `昇降格が多すぎない ${JSON.stringify(moves)}`);
ok(moves.up + moves.down >= 2, `昇降格がまったく無いのは偏り ${JSON.stringify(moves)}`);
if (moves.up + moves.down >= 6) ok(Math.min(moves.up, moves.down) / (moves.up + moves.down) >= 0.15, `昇格・降格の偏り ${JSON.stringify(moves)}`);
const pro = mean((m) => m.gradPaths.pro);
ok(pro >= 1.2 && pro <= 4, `プロ級の割合が決定75の目安（11人中2〜3人）から離れすぎない: ${pro.toFixed(2)}人/年`);
// 課題（2026-11-26）：おまかせで回すと、同時5人まで・覚醒はならして年5〜7人前後・外れたらあきらめもある
{
  const awY = yrs.reduce((a, x) => a + x.awake, 0) / yrs.length;
  const gvY = yrs.reduce((a, x) => a + x.kgive, 0) / yrs.length;
  console.log(`課題：覚醒 ${awY.toFixed(2)}人/年・あきらめ ${gvY.toFixed(2)}件/年・同時の最大 ${G.maxKadai}人（${G.kadaiWeeks}週を見た）`);
  ok(G.kadaiWeeks > 100 && G.maxKadai <= YA.KADAI_MAX && G.maxKadai >= 4, `課題は同時に5人まで（最大${G.maxKadai}人）`);
  ok(awY >= 4 && awY <= 8.5, `覚醒はならして年5〜7人前後: ${awY.toFixed(2)}人/年`);
  ok(gvY > 0, `外れた課題はあきらめになる: ${gvY.toFixed(2)}件/年`);
  const av = (xs) => (xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : 0);
  const kzY = Object.values(G.kzAt).reduce((a, b) => a + b, 0) / n;
  console.log(`気づきの場面：${kzY.toFixed(1)}回/年（場所 ${JSON.stringify(G.kzAt)}・結果 ${JSON.stringify(G.kzKind)}）・合う課題の後半に 平均${av(G.kzN).toFixed(2)}回（覚醒まで含む・${G.kzN.length}件）／最後まで選べなかった課題では 平均${av(G.kzMiss).toFixed(2)}回（${G.kzMiss.length}件）`);
  ok(kzY > 5 && (G.kzAt.match || 0) + (G.kzAt.matchB || 0) > 0 && G.kzAt.prac > 0 && G.kzAt.talk > 0, `気づきの場面が試合・練習・日常で来る: ${JSON.stringify(G.kzAt)}`);
  ok(G.kzMiss.length < 3 || (av(G.kzMiss) >= 1.6 && av(G.kzMiss) <= 4.5), `合う課題の後半いっぱいで、場面は2〜4回ほど: ${av(G.kzMiss).toFixed(2)}`);
}
ok(share((m) => m.trustAfter >= 99 || m.trustAfter <= 1) <= 0.4, '信頼度が上限・下限に張り付いていない');
// 60 評価：育成の目標は部と施設に合わせ、約束の目標はおまかせでも届くことがある（B に偏らない）
const minutes = mean((m) => m.minutesPerWeek);
ok(minutes >= 1.5 && minutes <= 10, `1週の想定時間が目標（8〜10分以内）: ${minutes.toFixed(1)}分`);
ok(mean((m) => m.growthAvg) >= 8 && mean((m) => m.growthAvg) <= 40, `成長の速さが妥当: +${mean((m) => m.growthAvg).toFixed(1)}/年`);
ok(mean((m) => m.injuries) >= 1 && mean((m) => m.injuries) <= 30, `怪我の件数が妥当: ${mean((m) => m.injuries).toFixed(1)}件/年`);

// 42 プロ入り：在学中のトップ昇格も年の目安に数える（前は年4〜5人が在学中に抜けていた）
ok(Math.max(...yrs.map((x) => x.pro)) <= 5 && yrs.reduce((a, x) => a + x.early, 0) / yrs.length <= 1, `在学中のトップ昇格は年1人まで・1年のプロ入りは5人まで（最大${Math.max(...yrs.map((x) => x.pro))}人）`);
// 43 卒業時の総合力：平均90前後（2部）。1部は少し高く、3部は少し低い。長い試しでは10年たっても大きくずれない
const gAvg = (f) => { const v = yrs.filter((x) => x.gradAvg != null && f(x)).map((x) => x.gradAvg); return v.length ? v.reduce((a, b) => a + b, 0) / v.length : null; };
const g2 = gAvg((x) => x.level === 2 && x.y >= 2);
ok(g2 == null || (g2 >= 80 && g2 <= 106), `2部の卒業時の平均が90前後: ${g2 && g2.toFixed(1)}`);
ok(yrs.filter((x) => x.gradAvg != null).every((x) => x.gradAvg >= 70 && x.gradAvg <= 125), '卒業時の平均が極端でない ' + yrs.map((x) => Math.round(x.gradAvg || 0)).join(','));
if (years >= 8) {
  const early3 = gAvg((x) => x.y >= 3 && x.y <= 4), late3 = gAvg((x) => x.y >= years - 1);
  ok(late3 - early3 <= 12, `卒業時の平均が年々上がり続けない（3〜4年目 ${early3.toFixed(1)} → 最後の2年 ${late3.toFixed(1)}）`);
}
// 44 疲れ：たまる（平均が張り付かない）が、上限に張り付きもしない。疲れの出来事は年に数回
const fatAvg = G.fat.reduce((a, b) => a + b, 0) / G.fat.length;
ok(fatAvg >= 15 && fatAvg <= 50, `疲れの平均が妥当: ${fatAvg.toFixed(1)}`);
ok(G.tired / n >= 0.3 && G.tired / n <= 8, `疲れの出来事は年に数回: ${(G.tired / n).toFixed(1)}回/年`);
// 48 怪我：試合でも起き、まれに長い怪我がある
const mInj = yrs.reduce((a, x) => a + x.matchInj, 0), longInj = yrs.reduce((a, x) => a + x.injLong, 0);
ok(mInj / n >= 1 && longInj >= 1, `試合の怪我 ${(mInj / n).toFixed(1)}件/年・長い怪我（8週以上）${longInj}件`);
// 49 退団の理由が1つに偏らない
const qr = {};
for (const x of yrs) for (const k of x.quits) qr[k] = (qr[k] || 0) + 1;
const qn = Object.values(qr).reduce((a, b) => a + b, 0);
if (qn >= 8) ok(Math.max(...Object.values(qr)) / qn <= 0.85, '退団の理由が1つに偏らない ' + JSON.stringify(qr));
// おまかせの接し方が1つに偏らない
const kn = Object.values(G.kinds).reduce((a, b) => a + b, 0);
ok(kn > 0 && Math.max(...Object.values(G.kinds)) / kn <= 0.6 && Object.keys(G.kinds).length >= 3, 'おまかせの接し方が偏らない ' + JSON.stringify(G.kinds));
// 52 信頼度が上に張り付かない
ok(share((m) => m.trustAfter >= 85) <= 0.25, `信頼度が85以上に張り付かない（${(share((m) => m.trustAfter >= 85) * 100).toFixed(0)}%）`);
// 51 育成基金がたまる一方にならない
ok(yrs.every((x) => x.fund <= x.total * 1.2 + 1000), '育成基金がたまる一方にならない（最大' + Math.max(...yrs.map((x) => x.fund)) + '万）');
// 55 大会：3部から毎年のように全国優勝しない
const cups = yrs.reduce((a, x) => a + x.cups, 0) / n;
ok(cups <= 0.7 && yrs.filter((x) => x.level === 3).reduce((a, x) => a + x.cups, 0) <= Math.max(2, yrs.filter((x) => x.level === 3).length * 0.3), `大会の優勝が多すぎない（${cups.toFixed(2)}回/年）`);
// 54 3部から5年以内にプレミアへ届かない（長い試しのとき）
if (years >= 6) {
  const fast = runs.filter((r) => r.tier === 3).map((r) => yrs.filter((x) => x.seed === r.seed).findIndex((x) => x.level === 1)).filter((k) => k >= 0 && k < 5).length;
  ok(fast === 0, '3部から5年以内にプレミアへ届かない');
}
console.log('評価', JSON.stringify(letters), '昇降格', JSON.stringify(moves), `プロ入り ${pro.toFixed(2)}人/年`, `成長 +${mean((m) => m.growthAvg).toFixed(1)}`, `怪我 ${mean((m) => m.injuries).toFixed(1)}`, `予算 ${mean((m) => m.budget).toFixed(0)}万`, `信頼度 ${mean((m) => m.trustAfter).toFixed(0)}`, `選ぶ回数/週 ${mean((m) => m.picksPerWeek).toFixed(1)}`, `想定 ${minutes.toFixed(1)}分/週`);
console.log(`卒業時の平均（2部）${g2 && g2.toFixed(1)}`, `疲れ ${fatAvg.toFixed(1)}`, `疲れの出来事 ${(G.tired / n).toFixed(1)}/年`, `試合の怪我 ${(mInj / n).toFixed(1)}/年`, '退団', JSON.stringify(qr), '接し方', JSON.stringify(G.kinds), `大会の優勝 ${cups.toFixed(2)}/年`);
console.log(fails ? '失敗 ' + fails : '釣り合いの点検: すべて通過');
process.exit(fails ? 1 : 0);
