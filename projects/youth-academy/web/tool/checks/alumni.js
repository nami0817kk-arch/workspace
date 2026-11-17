// 卒業生の点検（2026-11-17 の点検役の報告 63〜81 を直したあと）。
// 作った卒業生を20年ぶん回し（毎週の知らせ→年度末の alumniTick）、引退の年齢・大学からプロ・1年目の出場・優勝クラブ・個人の賞・
// 殿堂・知らせと記録・連帯貢献金・代表の試合数・コーチの印を確かめる。
'use strict';
module.exports = (YA, ok) => {
  const med = (xs) => { const s = xs.slice().sort((a, b) => a - b); return s.length ? s[Math.floor(s.length / 2)] : null; };
  const isPro = (s) => !/大学|社会人/.test(s.league || '');
  const J = (YA.PRO_CLUBS || []).filter((c) => c.tier === 2);
  const POS = [['FW', 'ST'], ['MF', 'CM'], ['DF', 'CB'], ['GK', 'GK'], ['MF', 'AM'], ['FW', 'LW']];
  const all = [];
  for (const seed of [11, 12]) {
    const w = YA.newWorld(seed);
    w.alumni = [];
    for (let y = 1; y <= 20; y++) {
      w.year = y;
      // 毎年12人が卒業：プロ3人・大学5人・社会人4人（力は 10〜15.5）
      if (y <= 12) for (let i = 0; i < 12; i++) {
        const [pos, main] = POS[(i + y) % POS.length];
        const st = i < 3 ? 'pro' : i < 8 ? 'univ' : 'amateur';
        const ovr = st === 'pro' ? 13.2 + ((i * 7 + y * 3) % 23) / 10 : st === 'univ' ? 10.8 + ((i * 5 + y) % 22) / 10 : 9.8 + (i % 6) / 10;
        const c = J[(i * 3 + y) % J.length];
        w.alumni.push({ name: `卒業 ${seed}-${y}-${i}`, pos, main, year: y, ovr, ovr0: ovr, note: '卒業', grade: 3, age: 18, status: st,
          club: st === 'pro' ? c.name : st === 'univ' ? '関東の強豪大学' : '社会人', league: st === 'pro' ? 'J2リーグ' : st === 'univ' ? '大学リーグ' : '社会人リーグ',
          apps: 0, goals: 0, nat: 0, natGoals: 0, transfers: 0, retired: false, traits: [], seasons: [], titles: [], awards: [] });
      }
      for (let wk = 1; wk <= 40; wk++) { w.week = wk; YA.proNewsWeek(w); }
      w.week = 40;
      YA.alumniTick(w);
    }
    all.push(w);
  }
  const AL = all.flatMap((w) => w.alumni);

  // 63 引退の年齢：33歳ちょうどに固まらない・30〜40歳・GK は遅め
  const ret = AL.filter((a) => a.retired && !a.quit && a.seasons.some(isPro) && a.note !== '指導者に転身');
  const byAge = {};
  for (const a of ret) byAge[a.age] = (byAge[a.age] || 0) + 1;
  const top = Math.max(0, ...Object.values(byAge));
  ok(ret.length >= 20 && top / ret.length < 0.4 && Object.keys(byAge).length >= 4, '引退の年齢がばらける ' + JSON.stringify(byAge));
  ok(ret.every((a) => a.age >= 30 && a.age <= (a.pos === 'GK' ? 40 : 38)), '引退は30〜38歳（GK は40歳まで）');
  ok(YA.retireChance({ age: 31, pos: 'GK' }, 30, 38) === 0 && YA.retireChance({ age: 38, pos: 'MF' }, 30, 38) === 1 && YA.retireChance({ age: 32, pos: 'MF' }, 5, 38) > YA.retireChance({ age: 32, pos: 'MF' }, 35, 38), '引退の確率：GK は遅く、出場が少ないと早い');

  // 64・65 大学：23歳以上で大学のままの子はいない。大学からプロは4割未満、機会は22歳だけ
  const u23 = AL.filter((a) => a.status === 'univ' && a.age >= 23);
  ok(!u23.length, '23歳以上で大学のままの子はいない ' + u23.slice(0, 2).map((a) => a.name + ':' + a.age + ':' + a.retired).join(' '));
  const uni = AL.filter((a) => a.league0 === '大学リーグ' || (a.moves || []).some((m) => m.join) || (a.seasons[0] && a.seasons[0].league === '大学リーグ'));
  const uniDone = uni.filter((a) => a.age >= 23 || a.retired);
  const uniPro = uniDone.filter((a) => (a.moves || []).some((m) => m.join));
  ok(uniDone.length >= 40 && uniPro.length / uniDone.length < 0.4, `大学からプロは4割未満 ${uniPro.length}/${uniDone.length}`);
  ok(uniPro.every((a) => a.moves.find((m) => m.join).age === 22), '大学からプロに入るのは22歳');
  // 73 大学からプロは「大学→クラブ（加入・0円）」の1行で残り、最初の行き先も控える
  ok(uniPro.every((a) => { const m = a.moves.find((x) => x.join); return m.fee === 0 && m.fromLg === '大学リーグ' && a.club0 === '関東の強豪大学'; }), '大学からプロの記録（加入・0円・最初の行き先）');

  // 66 高卒1年目の出場
  const first = AL.filter((a) => a.league0 === 'J2リーグ').map((a) => a.seasons[0]).filter((s) => s && s.age <= 19);
  ok(first.length >= 20 && med(first.map((s) => s.apps)) <= 20, '高卒1年目の出場の中央値は20試合以下 ' + med(first.map((s) => s.apps)));

  // 67・68 市場価値：J→海外の移籍金は海外→J より安くならない。ピークは21〜26歳
  const mv = AL.flatMap((a) => a.moves || []).filter((m) => !m.join);
  const jToA = mv.filter((m) => /^J/.test(m.fromLg) && !/^J/.test(m.toLg) && m.fee > 0).map((m) => m.fee);
  const aToJ = mv.filter((m) => !/^J/.test(m.fromLg) && /^J/.test(m.toLg) && m.fee > 0).map((m) => m.fee);
  ok(!aToJ.length || med(jToA) >= med(aToJ), `J→海外の移籍金は海外→J より安くない ${med(jToA)} / ${med(aToJ)}`);
  const v = (age, lg) => YA.marketValue({ status: 'pro', ovr: 15, age, league: lg });
  ok(v(24, 'J1リーグ') > v(20, 'J1リーグ') && v(20, 'J1リーグ') > v(29, 'J1リーグ') && v(29, 'J1リーグ') > v(31, 'J1リーグ'), '市場価値のピークは21〜26歳でなだらか');
  ok(v(24, 'プレミアリーグ') / v(24, 'J1リーグ') <= 3 && v(24, 'プレミアリーグ') > v(24, 'エールディビジ'), '市場価値のリーグ差は格の掛け目（3倍まで）');
  // 69 30歳を過ぎても移籍がある・海外の28〜29歳は海外どうしも
  ok(mv.some((m) => m.age > 30), '30歳を過ぎても移籍する');

  // 70 優勝クラブは年×リーグで1つ
  for (const [label, re] of [['リーグ', null], ['CL', /チャンピオンズリーグ/]]) {
    const g = {};
    all.forEach((w, wi) => w.alumni.forEach((a) => a.seasons.forEach((s) => s.titles.forEach((t) => {
      if (re ? !re.test(t) : t !== s.league + '優勝') return;
      const k = wi + '|' + s.y + '|' + (re ? 'CL' : s.league);
      (g[k] = g[k] || new Set()).add(s.club);
    }))));
    ok(Object.values(g).every((x) => x.size === 1), `優勝クラブは年×${label}で1つ（${Object.keys(g).length}件）`);
  }
  ok(AL.every((a) => a.seasons.every((s) => !s.titles.length || s.apps >= 10)), '優勝メンバーは10試合以上出た子だけ');
  // 71 個人の賞は年×リーグ×賞で1人（ベストイレブンを除く）
  const aw = {};
  all.forEach((w, wi) => w.alumni.forEach((a) => a.seasons.forEach((s) => s.awards.forEach((x) => { if (/ (得点王|アシスト王|最優秀GK|年間MVP|新人王)$/.test(x)) { const k = wi + '|' + s.y + '|' + x; aw[k] = (aw[k] || 0) + 1; } }))));
  ok(Object.values(aw).every((n) => n === 1), '個人の賞は年×リーグ×賞で1人');

  // 72 殿堂：大学・社会人のタイトルと出場は数えない。候補・殿堂入りは一部だけ
  const uniOnly = { status: 'univ', seasons: [{ league: '大学リーグ', apps: 400 }], titles: [{ name: '大学リーグ優勝' }, { name: '大学リーグ優勝' }], awards: [], apps: 400 };
  ok(!YA.hofCondition(uniOnly) && YA.hofScore(uniOnly) === 0, '殿堂：大学のタイトルと出場は数えない');
  const j1 = { status: 'pro', seasons: [{ league: 'J1リーグ', apps: 300 }], titles: [{ name: 'J1リーグ優勝' }, { name: '天皇杯優勝' }], awards: [], apps: 300, caps: 0 };
  ok(!YA.hofCondition(j1) && !YA.hofFull(j1), '殿堂：J1優勝1回と300試合では候補にならない');
  ok(YA.hofCondition(Object.assign({}, j1, { caps: 3 })) && YA.hofCondition(Object.assign({}, j1, { titles: [{ name: 'セリエA優勝' }] })), '殿堂の候補：日本代表・5大リーグの優勝');
  ok(AL.filter((a) => a.hof).length / AL.length < 0.2, '殿堂候補は卒業生の2割未満 ' + AL.filter((a) => a.hof).length + '/' + AL.length);
  ok(AL.filter((a) => a.hof === 'full').length / AL.length < 0.1, '殿堂入りは卒業生の1割未満 ' + AL.filter((a) => a.hof === 'full').length + '/' + AL.length);

  // 74・75 連帯貢献金は国をまたぐ移籍だけ。知らせは「半分を育成基金へ」
  ok(mv.every((m) => (/^J/.test(m.fromLg) && /^J/.test(m.toLg) ? !m.share : m.share === (m.sale ? 0 : Math.round(m.fee * 0.015)))), '連帯貢献金は国をまたぐ移籍だけ（1.5%）');
  const inbox = all.flatMap((w) => (w.inbox || []).map((n) => n.text || ''));
  ok(!inbox.some((t) => /連帯貢献金 \+\d+万円が育成基金に入ります/.test(t)) && (!inbox.some((t) => /連帯貢献金 \d+万円/.test(t)) || inbox.some((t) => /半分を育成基金へ/.test(t))), '連帯貢献金の知らせは実際の流れ（半分を育成基金へ）');

  // 76 知らせと記録の一致
  let bad = [];
  for (const a of AL) {
    for (const n of a.news || []) {
      const s = a.seasons.find((x) => x.y === n.y);
      const prev = a.seasons.filter((x) => x.y < n.y && isPro(x));
      const m = /今季(\d+)アシスト目/.exec(n.t);
      if (m && s && +m[1] > s.assists) bad.push('アシスト ' + n.t);
      const g = /今季(\d+)点目/.exec(n.t);
      if (g && s && +g[1] > s.goals) bad.push('ゴール ' + n.t);
      if (n.k === 'debut' && prev.some((x) => x.apps > 0)) bad.push('デビュー ' + n.t);
      if (n.k === 'firstgoal' && prev.some((x) => x.goals > 0)) bad.push('初ゴール ' + n.t);
      const ms = /通算(\d+)試合/.exec(n.t);
      if (ms && s) { const before = prev.reduce((t, x) => t + x.apps, 0); if (!(before < +ms[1] && before + s.apps >= +ms[1])) bad.push('節目 ' + n.t); }
      // 77 延長の年に移籍しない
      if (n.k === 'extend' && (a.moves || []).some((x) => x.y === n.y && !x.join)) bad.push('延長して移籍 ' + n.t);
      // 78 相手が自分のクラブ・実在の愛称でない
      if (/(ガンバ|セレッソ)(?!ーレ)/.test(n.t)) bad.push('実在の愛称 ' + n.t);
    }
    const ng = (a.news || []).filter((n) => n.k === 'natGoal').length;
    if ((a.natGoals || 0) < ng) bad.push('代表のゴール ' + a.name);
  }
  for (const a of AL) for (const s of a.seasons) if (s.goals > s.apps * 1.5 && s.apps > 0) bad.push('1試合2点 ' + a.name);
  ok(!bad.length, '知らせと記録が合う ' + bad.slice(0, 3).join(' / '));
  ok(AL.some((a) => (a.news || []).length), '知らせが届いている');

  // 81 日本代表は試合数（年に2〜10試合＋W杯）
  const nat = AL.filter((a) => a.nat > 0);
  ok(nat.every((a) => a.caps >= a.nat * 2), '日本代表は試合数で数える（選ばれた年×2以上）');

  // 79・80 コーチの印：市場に並べただけでは付かない。雇うと付き、現役のプロは引退して指導者に
  {
    const w = all[0];
    const r0 = AL.filter((a) => a.retired && a.ovr >= 11 && !a.mem).length;
    YA.genMarket(w);
    ok(!w.alumni.some((a) => a.coached) && (r0 === 0 || w.alumni.some((a) => a.offered)), '市場に並べただけでは「コーチとして戻った」にならない');
    const ob = w.market.find((s) => s.ob);
    if (ob) {
      w.club.trust = 100;
      const res = YA.hire(w, ob.id);
      const a = w.alumni.find((x) => x.name === ob.alumniRef);
      ok(!res.ok || (a.coached && a.coachY === w.year), '雇ったときだけコーチの印（a.coachY）');
    }
    const p = w.alumni.find((a) => a.status === 'pro' && !a.retired);
    if (p) {
      YA.obJoin(w, p);
      ok(p.retired && p.note === '指導者に転身' && p.coachY === w.year && YA.retireWord(p) === '指導者に転身', '現役のプロを OB コーチにすると引退扱い');
      ok(YA.alumniTimeline(w, p).some((x) => x.t === 'コーチとして戻った' && x.y === w.year), '年表の「コーチとして戻った」は雇った年');
    }
  }
};
