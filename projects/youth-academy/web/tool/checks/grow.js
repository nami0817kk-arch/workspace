// 育成・クラブ運営・リーグの釣り合いの点検（2026-11-17 の直し 42〜62 と、おまかせの選び方・途中加入）。
// 長い年数で見る数字（卒業時の平均・疲れ・評価の偏りなど）は tool/balance.js が見る。ここは仕組みを短く確かめる
'use strict';
module.exports = (YA, ok) => {
  const clone = (w) => JSON.parse(JSON.stringify(w));
  // 能力の合計に、まだ1に届いていない伸び（p.prog）も足した、なめらかな物差し
  const sumAll = (w) => Object.values(w.players).reduce((s, p) => s + YA.abSum(p) + Object.values(p.prog || {}).reduce((a, b) => a + b, 0), 0);

  // 45 練習の強さ：きつい＝伸び約1.3倍・軽め＝伸び少なめ／疲れはきついほどたまる
  {
    const base = YA.newWorld(31);
    const run = (int) => {
      const w = clone(base);
      w.plan = { days: YA.defaultPlan().days.map((d) => (d.menu === '回復' ? d : { menu: d.menu, int })) };
      for (const p of Object.values(w.players)) { p.train.trait = null; p.fat = 20; }
      const s0 = sumAll(w);
      let inj = 0;
      for (let k = 0; k < 12; k++) {
        w.week = k + 1;
        YA.runTraining(w);
        for (const p of Object.values(w.players)) { if (p.inj > 0 && p._injLen === p.inj) inj++; p.inj = 0; }
      }
      return { g: sumAll(w) - s0, fat: Object.values(w.players).reduce((s, p) => s + p.fat, 0) / 36, inj };
    };
    const L = run('light'), N = run('normal'), H = run('hard');
    ok(H.g > N.g * 1.15 && H.g < N.g * 1.5, `きつい練習は伸び約1.3倍（普通${N.g.toFixed(0)}・きつい${H.g.toFixed(0)}）`);
    ok(L.g < N.g * 0.92, `軽めは伸びが少なめ（軽め${L.g.toFixed(0)}・普通${N.g.toFixed(0)}）`);
    ok(L.fat < N.fat && N.fat < H.fat, `疲れは 軽め<普通<きつい（${L.fat.toFixed(0)}/${N.fat.toFixed(0)}/${H.fat.toFixed(0)}）`);
  }

  // 44 疲れ：試合1回で10〜20たまる
  {
    const w = YA.newWorld(32);
    for (const p of Object.values(w.players)) p.fat = 10;
    const ids = w.lineupA.map((s) => s.pid);
    YA.playAuto(w);
    const add = ids.map((id) => w.players[id]).filter((p) => p && p.lm && p.lm.mins >= 85).map((p) => p.fat - 10);
    const avg = add.reduce((a, b) => a + b, 0) / (add.length || 1);
    ok(add.length >= 6 && avg >= 10 && avg <= 20, `試合1回の疲れは10〜20（平均 ${avg.toFixed(1)}）`);
  }

  // 46 おまかせの練習は週ごとに回る（アジリティ・フィジカル・クロスも入る）
  {
    const w = YA.newWorld(33);
    const seen = new Set();
    const plans = new Set();
    for (let k = 1; k <= 12; k++) {
      w.week = k;
      const pl = YA.autoPlan(w);
      pl.days.forEach((d) => seen.add(d.menu));
      plans.add(pl.days.map((d) => d.menu).join(','));
    }
    ok(['アジリティ', 'フィジカル', 'クロスと合わせ', '対人', '守備の組織', 'シュート'].every((m) => seen.has(m)) && plans.size >= 5, 'おまかせの練習は週ごとに回る ' + [...seen].join('・'));
  }

  // 47 目標：値は選択肢から。「難しく」で難しく、「易しく」で易しく。信頼度80でも成績の目標を易しくできる
  {
    const w = YA.newWorld(34);
    for (const tr of [20, 50, 80, 95]) {
      w.club.trust = tr;
      YA.makeGoals(w);
      ok(w.club.goals.every((g) => YA.goalOpts(w, g.k).indexOf(g[YA.GOAL_DEF[g.k].key]) >= 0), `目標の値は選択肢の中から（信頼度${tr}）`);
    }
    w.club.trust = 50; YA.makeGoals(w); w.club.goalChanges = 9;
    const g0 = JSON.parse(JSON.stringify(w.club.goals));
    YA.changeGoal(w, 0, 1); YA.changeGoal(w, 1, 1); YA.changeGoal(w, 2, 1);
    ok(w.club.goals[0].n < g0[0].n && w.club.goals[1].x > g0[1].x && w.club.goals[2].t > g0[2].t, '「難しく」で目標が難しくなる');
    w.club.trust = 80; YA.makeGoals(w);
    const n0 = w.club.goals[0].n;
    ok(YA.changeGoal(w, 0, -1) && w.club.goals[0].n > n0, '信頼度80でも成績の目標を易しくできる');
    // 60 育成の目標は総合力の伸びで数え、部で目安が変わる
    w.league.level = 1; const o1 = YA.goalOpts(w, 'develop');
    w.league.level = 3; const o3 = YA.goalOpts(w, 'develop');
    ok(o1[2] > o3[2] && /総合力/.test(YA.goalText({ k: 'develop', x: 8 })), `育成の目標は部で変わり、総合力の伸びで数える（1部${o1[2]}・3部${o3[2]}）`);
  }

  // 50・61 予算：合宿費は部の予算に比例・予備から回せる・いまのリーグの部が予算に混ざる
  {
    const w3 = YA.testStart({ seed: 35, tier: 3 }).w;
    const w1 = YA.testStart({ seed: 35, tier: 1 }).w;
    ok(YA.campCost(w3, 'domestic') < YA.campCost(w1, 'domestic'), `合宿費は部の予算に比例（3部${YA.campCost(w3, 'domestic')}万・1部${YA.campCost(w1, 'domestic')}万）`);
    ok(YA.campOptions(w3).find((x) => x.k === 'domestic').ok, '3部でも国内の合宿に行ける');
    const b0 = YA.budget(w3);
    ok(b0.camp >= b0.campBase + b0.reserveLeft - 1 && b0.reserveLeft > 0, '予備の残りを合宿に回せる');
    w3.club.spent.scout = b0.scoutBase + 50;
    const b1 = YA.budget(w3);
    ok(b1.reserveLeft === Math.max(0, b0.reserveLeft - 50) && b1.camp - w3.club.spent.camp === b1.campBase + b1.reserveLeft, 'スカウトで予備を使うと、合宿に回せる額が減る');
    const t0 = YA.tierBase(w3);
    w3.leagueLevel = 2;
    ok(YA.tierBase(w3) > t0, `昇格するといまのリーグの部が予算に混ざる（${t0}→${YA.tierBase(w3)}）`);
  }

  // 62 クラブ移籍の誘いは YA.PRO_CLUBS から
  {
    const w = YA.newWorld(36);
    const names = new Set(YA.PRO_CLUBS.map((c) => c.name + 'U-18'));
    let all = [];
    for (let y = 1; y <= 6; y++) { w.year = y; all = all.concat(YA.moveOffers(w)); }
    ok(all.every((o) => names.has(o.name) && YA.PRO_CLUBS.find((c) => c.name + 'U-18' === o.name).tier === o.tier), 'クラブ移籍の誘いは表のクラブで、部も合う');
  }

  // 51 育成基金：くり返し使える使い道（1年に1回）と、おまかせで使う
  {
    const w = YA.newWorld(37);
    w.fund = 5000;
    ok(YA.fundUse(w, 'medical').ok && !YA.fundUse(w, 'medical').ok && YA.fundWhy(w, 'medical'), '医療の体制は1年に1回まで（押せない理由つき）');
    const t0 = w.club.total;
    ok(YA.fundUse(w, 'staff').ok && w.club.total === t0 + 500, '給料に回すと今年の予算が増える');
    ok(YA.trainerFx(w).inj < 1.25 && YA.fundOn(w, 'medical'), '医療の体制は怪我を減らす');
    w.fund = 6000; w.fundYr = {};
    YA.fundAuto(w, []);
    ok(w.fund < 1500, `おまかせでも基金を使う（残り${w.fund}万）`);
  }

  // 52 信頼度：70を超えると上がり幅が小さい
  {
    const w = YA.newWorld(38);
    w.club.trust = 50; YA.addTrust(w, 6); const d1 = w.club.trust - 50;
    w.club.trust = 88; YA.addTrust(w, 6); const d2 = w.club.trust - 88;
    ok(d2 < d1 * 0.6, `信頼度は高いほど上がりにくい（50から+${d1.toFixed(1)}・88から+${d2.toFixed(1)}）`);
  }

  // 42 在学中のトップ昇格は年1人まで・高3は内定で卒業まで残る
  {
    const w = YA.newWorld(39);
    const line = YA.earlyProLine(w);
    const g3 = Object.values(w.players).filter((p) => p.grade === 3).slice(0, 3);
    for (const p of g3) for (const a of Object.keys(p.ab)) p.ab[a] = 19;
    YA.naiteiCheck(w); YA.naiteiCheck(w); YA.naiteiCheck(w);
    const nt = g3.filter((p) => p.naitei && w.players[p.id]);
    ok(nt.length === 2 && YA.rating(g3[0]) >= line, '高3はトップの内定（抜けずに残る）。内定は1年に2人まで');
    const g2 = Object.values(w.players).filter((p) => p.grade === 2).slice(0, 2);
    for (const p of g2) for (const a of Object.keys(p.ab)) p.ab[a] = 19;
    const ev = YA.EVENTS.find((e) => e.id === 'early');
    const r = YA.rngOf(5);
    const c1 = ev.pick(w, r);
    ok(c1 && c1.grade === 2, '在学中の打診は高1・高2');
    YA.earlyPro(w, c1.id);
    ok(!ev.pick(w, r), '在学中のトップ昇格は1年に1人まで');
    w.week = 40;
    const res = YA.graduate(w);
    const pros = w.alumni.filter((a) => a.year === 1 && a.status === 'pro');
    ok(nt.every((p) => pros.some((a) => a.name === p.name)), '内定の子は卒業と同時にプロ');
    ok(res.entered === Object.values(w.players).filter((p) => p.grade === 1).length, '卒業式の知らせは実際に入った人数');
  }

  // 49・途中加入：退団の穴は高1で埋める
  {
    const w = YA.newWorld(40);
    const p = Object.values(w.players).find((q) => q.grade === 3);
    p._qr = '不満';
    const n1 = Object.values(w.players).filter((q) => q.grade === 1).length;
    const n3 = Object.values(w.players).filter((q) => q.grade === 3).length;
    const r = YA.resolveEvent(w, { id: 'quit', pid: p.id, week: 1, year: 1 }, 1);
    ok(r.leave && Object.values(w.players).filter((q) => q.grade === 1).length === n1 + 1 && Object.values(w.players).filter((q) => q.grade === 3).length === n3 - 1, '途中加入は高1だけ');
    // 不満は Aの出場で見る：Bで出ていても Aに出ていない高3はたまる
    const q = Object.values(w.players).find((x) => x.grade === 3 && x.team === 'B');
    q.unrest = 0; q.minsA = 0; q.mins = 900; w.week = 20;
    for (let k = 0; k < 6; k++) YA.runTraining(w);
    ok(q.unrest > 0.4, `Aに出ていない高3は、Bで出ていても不満がたまる（${q.unrest.toFixed(2)}）`);
  }

  // 48 試合の怪我：出た子が試合で怪我をすることがある・まれに長い
  {
    // 1年で数件なので、1つのシードでは0件の年もある（2026-11-18 退場の直しで乱数がずれて seed 41 が0件）。2つのシードで見る
    let txt = '';
    let st = null;
    for (const sd of [41, 42]) { st = YA.testStart({ seed: sd, tier: 2 }); YA.testYear(st); txt += st.w.inbox.map((n) => n.text).join('\n') + '\n'; }
    ok(/試合で怪我/.test(txt), '試合でも怪我をする');
  }

  // おまかせの接し方：方針（厳しさ／寄り添い）で選び方が変わる
  {
    const w = YA.newWorld(42);
    const count = (tone) => {
      YA.policyOf(w).tone = tone;
      const c = { warm: 0, firm: 0, push: 0, wait: 0 };
      const ps = Object.values(w.players);
      for (let k = 0; k < 120; k++) {
        const p = ps[k % ps.length];
        w.week = 1 + (k % 39);
        const e = { id: k % 2 ? 'lowconf' : 'rival', pid: p.id, week: w.week, year: w.year };
        const v = YA.eventView(w, e);
        const i = YA.autoPick(w, e, v);
        c[YA.EVENTS.find((x) => x.id === e.id).opts[i].kind]++;
      }
      return c;
    };
    const hard = count(0), soft = count(1);
    ok(hard.firm + hard.push > hard.warm && soft.warm > soft.firm && hard.warm < soft.warm, `おまかせの接し方は方針に合わせる（厳しさ${JSON.stringify(hard)}・寄り添い${JSON.stringify(soft)}）`);
  }

  // 53〜57 リーグと大会
  {
    const east = YA.clubPool(1).filter((c) => c.level === 1 && c.kind === 'club');
    const west = YA.clubPool(5).filter((c) => c.level === 1 && c.kind === 'club');
    const rgOf = (n) => YA.PRO_CLUBS.find((c) => c.name + 'U-18' === n).region;
    ok(east.length >= 8 && east.every((c) => YA.sideOf(rgOf(c.name)) === 0) && west.every((c) => YA.sideOf(rgOf(c.name)) === 1), 'プレミアは EAST と WEST で相手が分かれる');
    const w3 = YA.testStart({ seed: 43, tier: 3 }).w;
    const w1 = YA.testStart({ seed: 43, tier: 1 }).w;
    const avgL = (o) => o.reduce((s, x) => s + x.lvl, 0) / o.length;
    const names = new Set(YA.PRO_CLUBS.map((c) => c.name + 'U-18'));
    for (const w of [w3, w1]) {
      const all = w.cup.summer.gopps.concat(w.cup.summer.opps, w.cup.winter.opps, w.cup.fest.opps);
      ok(all.every((o) => o.kind === 'club' && names.has(o.name)), '大会の相手はJクラブのユースだけ（高校は出ない）');
    }
    ok(Math.abs(avgL(w3.cup.winter.opps) - avgL(w1.cup.winter.opps)) < 0.6 && avgL(w3.cup.winter.opps) > YA.levelBase(2), `大会の相手の強さは自分の部によらず全国の水準（3部${avgL(w3.cup.winter.opps).toFixed(2)}・1部${avgL(w1.cup.winter.opps).toFixed(2)}）`);
    ok(w1.cup.summer.gopps.length === 3 && w1.cup.summer.group, '夏の大会はグループ戦3試合');
    // 相手は評判で少し強くなる
    w1.club.rep = 20; const a1 = YA.oppAdj(w1);
    w1.club.rep = 90; const a2 = YA.oppAdj(w1);
    ok(a2 > a1 + 0.3, '評判が高いと相手が少し強く当たってくる');
    // 暦：1〜3月にも試合がある
    const wk = []; for (let k = 31; k <= 39; k++) { const s = YA.SCHED(k); if (s.t === 'cup') wk.push(k); }
    ok(wk.length >= 4, '1〜3月にも試合がある ' + wk.join(','));
    // 2部で1位ならプレーオフ（すぐには昇格しない）・最下位は降格
    const w = YA.testStart({ seed: 44, tier: 2 }).w;
    for (let n = 1; n <= 22; n++) YA.leagueAdvance(w, n, [5, 0]);
    const le = YA.leagueEnd(w);
    ok(le.rank === 1 && le.move === 0 && w.cup.post.alive && w.cup.post.kind === 'playoff', '2部の上位はプレーオフ（勝てば昇格）');
    w.week = 31; w.phase = 'match';
    ok(YA.matchOf(w) && /プレーオフ/.test(YA.weekLabel(w)), 'プレーオフは31週');
    YA.recordMatch(w, { score: { home: 2, away: 0 } }, YA.opponentOf(w));
    ok(w.nextLevel === 1 && w.leagueEndMove === -1, 'プレーオフに勝つと昇格');
    const wl = YA.testStart({ seed: 45, tier: 2 }).w;
    for (let n = 1; n <= 22; n++) YA.leagueAdvance(wl, n, [0, 5]);
    ok(YA.leagueEnd(wl).move === 1 && !wl.cup.post.alive, '最下位は降格');
    // 夏のグループ戦が終わると順位と勝ち上がりが決まる
    const ws = YA.testStart({ seed: 46, tier: 2 }).w;
    for (let k = 13; k <= 15; k++) { ws.week = k; YA.recordMatch(ws, { score: { home: 3, away: 0 } }, YA.opponentOf(ws)); }
    ok(ws.cup.summer.groupDone && ws.cup.summer.grank === 1 && !ws.cup.summer.alive && ws.cup.summer.result, '夏はグループ1位で決勝トーナメントへ（結果 ' + ws.cup.summer.result + '）');
  }

  // 59 ★の約束は、期限までに残っているAの試合が足りないと組めない
  {
    const w = YA.newWorld(47);
    const p = Object.values(w.players).find((q) => q.grade === 1);
    p.star = true;
    w.week = 37;
    const why = YA.starActWhy(w, p, 'pact');
    ok(why && /試合/.test(why), '試合の残っていない時期は約束を組めない：' + why);
    w.week = 5;
    ok(!YA.starActWhy(w, p, 'pact'), 'リーグの時期は約束を組める');
  }

  // 58 「この一年」の会話は35〜38週に散らす（1週に2人まで）
  {
    const w = YA.newWorld(48);
    const ps = Object.values(w.players).filter((q) => q.grade < 3).slice(0, 8);
    for (const p of ps) p.star = true;
    const per = {};
    for (let k = 34; k <= 39; k++) {
      w.week = k; w.forced = [];
      YA.gradTalks(w);
      per[k] = w.forced.filter((f) => f.ms === 'term').length;
    }
    ok(Object.values(per).reduce((a, b) => a + b, 0) === 8 && Object.values(per).every((n) => n <= 2) && per[34] === 0, '「この一年」の会話は35〜38週に散らす ' + JSON.stringify(per));
  }
};
