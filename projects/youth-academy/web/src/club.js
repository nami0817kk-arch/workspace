// クラブ運営：信頼度・評判・予算・スタッフ・施設と寮・年度はじめの目標と約束事・年末の評価・契約と解任・
// トップ／代表／クラブの要望／規律の出来事・夏合宿と遠征。状態は w.club に入れる。
(function () {
  'use strict';
  const YA = (globalThis.YA = globalThis.YA || {});
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

  // ---------- 信頼度 ----------
  YA.trustLevel = (w) => (w.club.trust >= 70 ? 'high' : w.club.trust >= 40 ? 'mid' : 'low');
  YA.TRUST_NAME = { low: '低い', mid: '中くらい', high: '高い' };
  YA.addTrust = function (w, d, why) {
    const c = w.club;
    const before = c.trust;
    c.trust = clamp(c.trust + d, 0, 100);
    if (why && Math.abs(c.trust - before) >= 1) YA.noteTier(w, 2, `クラブからの信頼度が${c.trust > before ? '上がりました' : '下がりました'}（${Math.round(before)}→${Math.round(c.trust)}）：${why}`);
  };
  YA.addRep = function (w, d) {
    w.club.rep = clamp(w.club.rep + d, 0, 100);
    w.rep = w.club.rep;
  };

  // ---------- スタッフ ----------
  YA.ROLES_STAFF = ['技術コーチ', '戦術コーチ', '体コーチ', 'GKコーチ', 'トレーナー', 'スカウト', '分析'];
  YA.STAFF_NOTE = {
    技術コーチ: '技術の能力が伸びやすくなる', 戦術コーチ: '頭の能力が伸びやすくなる', 体コーチ: '体の能力が伸び、怪我もしにくくなる',
    GKコーチ: 'GKの能力が伸びやすくなる', トレーナー: '疲れが抜けやすく、怪我が減る', スカウト: '候補の報告が増え、目が確かになる', 分析: '相手の分析が深くなる',
  };
  const SN = ['久保', '梅田', '岩崎', '大石', '平野', '谷口', '千葉', '菅原', '野村', '松井', '河野', '田村', '今井', '武田', '杉山', '小野', '丸山', '内山', '島田', '上野'];
  const SG = ['誠', '健二', '浩', '裕二', '哲也', '博之', '賢', '隆', '正樹', '修', '勇', '剛'];
  YA.salaryOf = (ab) => Math.round(40 + ab * ab * 1.2);
  function genStaff(rng, role, lo, hi, ob) {
    const ab = rng.int(lo, hi);
    return { id: 's' + rng.int(1000, 99999), name: rng.pick(SN) + ' ' + rng.pick(SG), role, ab, salary: YA.salaryOf(ab), ob: !!ob };
  }
  YA.staffAb = function (w, role) {
    const s = w.club.staff.find((x) => x.role === role);
    return s ? s.ab : 4;
  };
  const TECH = new Set(YA.AB_TECH);
  const MENT = new Set(YA.AB_MENTAL);
  const PHYS = new Set(YA.AB_PHYS);
  const GKS = new Set(YA.AB_GK);
  // 練習での伸びに掛ける倍率
  YA.staffMult = function (w, p, a) {
    const role = GKS.has(a) ? 'GKコーチ' : TECH.has(a) ? '技術コーチ' : MENT.has(a) ? '戦術コーチ' : PHYS.has(a) ? '体コーチ' : null;
    if (!role) return 1;
    const ab = YA.staffAb(w, role);
    return clamp(1 + (ab - 10) * 0.028, 0.8, 1.3);
  };
  YA.trainerFx = function (w) {
    const t = YA.staffAb(w, 'トレーナー');
    const b = YA.staffAb(w, '体コーチ');
    const fac = w.club.facility || 0;
    return { recover: (t - 10) * 0.45 + fac * 1.2, inj: clamp(1 - (t - 10) * 0.035 - (b - 10) * 0.015 - fac * 0.04, 0.5, 1.25) };
  };

  YA.genMarket = function (w) {
    const r = YA.rngOf(w.seed * 3 + w.year * 17);
    const list = [];
    for (let i = 0; i < 7; i++) list.push(genStaff(r, r.pick(YA.ROLES_STAFF), 6, 16));
    // 卒業生が引退して戻ってくる
    for (const a of w.alumni) if (a.retired && !a.coached && a.ovr >= 11 && r.chance(0.5)) {
      const s = genStaff(r, r.pick(YA.ROLES_STAFF), 9, 15, true);
      s.name = a.name;
      s.ob = true;
      s.alumniRef = a.name;
      list.push(s);
      a.coached = true;
    }
    w.market = list;
  };
  YA.staffChangesLeft = (w) => {
    const lv = YA.trustLevel(w);
    return lv === 'high' ? 99 : lv === 'mid' ? w.club.staffChanges : 0;
  };
  YA.hire = function (w, id) {
    const c = w.market.find((x) => x.id === id);
    if (!c) return { ok: false, msg: '候補がいません' };
    if (YA.staffChangesLeft(w) <= 0) return { ok: false, msg: YA.trustLevel(w) === 'low' ? '信頼度が低いので、スタッフはクラブが決めます' : '今年の入れ替えの枠を使い切りました' };
    const old = w.club.staff.find((x) => x.role === c.role);
    const sal = w.club.staff.reduce((s, x) => s + x.salary, 0) - (old ? old.salary : 0) + c.salary;
    if (sal > YA.budget(w).total * 0.85) return { ok: false, msg: '給料が予算の大半を占めてしまいます' };
    w.club.staff = w.club.staff.filter((x) => x.role !== c.role).concat([c]);
    w.market = w.market.filter((x) => x.id !== id);
    if (YA.trustLevel(w) === 'mid') w.club.staffChanges--;
    return { ok: true, msg: `${c.name}（${c.role}）を迎えました` };
  };

  // ---------- 予算 ----------
  const TIER_BASE = { 1: 4000, 2: 2000, 3: 1000 };
  YA.TIER_NAME = { 1: '1部', 2: '2部', 3: '3部' };
  YA.budget = function (w) {
    const c = w.club;
    const salaries = c.staff.reduce((s, x) => s + x.salary, 0);
    const free = Math.max(0, c.total - salaries);
    const a = c.alloc;
    const amt = (k) => Math.round((free * a[k]) / 100);
    return { total: c.total, salaries, free, scout: amt('scout'), camp: amt('camp'), facility: amt('facility'), reserve: free - amt('scout') - amt('camp') - amt('facility') };
  };
  // 配分を変えられるか（信頼度が低いとクラブが決める。中くらいは一部だけ）
  YA.canAlloc = function (w, k) {
    const lv = YA.trustLevel(w);
    return lv === 'high' || (lv === 'mid' && k !== 'facility');
  };
  YA.setAlloc = function (w, k, v) {
    if (!YA.canAlloc(w, k)) return false;
    const a = w.club.alloc;
    a[k] = clamp(Math.round(v), 0, 60);
    const tot = a.scout + a.camp + a.facility;
    if (tot > 95) a[k] -= tot - 95;
    return true;
  };
  YA.facilityLevel = (w) => Math.floor((w.club.facPts || 0) / 600);
  YA.dormCap = (w) => 10 + YA.facilityLevel(w) * 4;

  // ---------- クラブを作る ----------
  YA.newClub = function (w, tier, name) {
    const r = YA.rngOf(w.seed * 5 + w.year * 11 + tier);
    const lo = tier === 1 ? 9 : tier === 2 ? 7 : 5;
    const staff = YA.ROLES_STAFF.map((role) => genStaff(r, role, lo, lo + 4));
    if (tier === 3) staff.pop(); // 3部は分析担当がいない
    w.clubName = name || w.clubName;
    const c = { tier, rep: (w.club && w.club.rep) || 40, trust: 50, total: TIER_BASE[tier], alloc: { scout: 18, camp: 14, facility: 8 }, staff, contract: { left: 3, years: 3 }, noFire: !!(w.club && w.club.noFire), goals: [], goalChanges: 0, eval: (w.club && w.club.eval) || [], bad: 0, staffChanges: 1, facPts: 0, facility: 0, solidarity: 0, spent: { scout: 0, camp: 0 }, careerClubs: (w.club && w.club.careerClubs) || [] };
    c.careerClubs.push({ name: w.clubName, from: w.year });
    w.club = c;
    w.rep = c.rep;
    w.leagueLevel = tier;
    YA.genMarket(w);
    return c;
  };

  // ---------- 年度はじめ：目標・約束事 ----------
  const GOAL_DEF = {
    result: { label: '成績', text: (g) => `リーグで${g.n}位以内`, opts: [4, 6, 8], key: 'n' },
    develop: { label: '育成', text: (g) => `全選手の能力の合計を平均+${g.x}以上伸ばす`, opts: [8, 12, 16], key: 'x' },
    promise: { label: '約束', text: (g) => `高1がAチームで合計${g.t}分以上出る`, opts: [500, 900, 1600], key: 't' },
  };
  YA.GOAL_DEF = GOAL_DEF;
  YA.makeGoals = function (w) {
    const c = w.club;
    const lv = w.league ? w.league.level : 2;
    c.goals = [{ k: 'result', n: lv === 1 ? 8 : 6 }, { k: 'develop', x: 12 }, { k: 'promise', t: 900 }];
    c.goalChanges = { low: 0, mid: 1, high: 2 }[YA.trustLevel(w)];
  };
  YA.goalText = (g) => GOAL_DEF[g.k].text(g);
  // dir = +1 難しく（評価は高く出る）/ -1 易しく
  YA.changeGoal = function (w, i, dir) {
    const c = w.club;
    if (c.goalChanges <= 0) return false;
    const g = c.goals[i];
    const d = GOAL_DEF[g.k];
    const at = d.opts.indexOf(g[d.key]);
    // result は数字が小さいほど難しい
    const step = g.k === 'result' ? -dir : dir;
    const nx = clamp(at + step, 0, d.opts.length - 1);
    if (nx === at) return false;
    g[d.key] = d.opts[nx];
    g.bonus = (g.bonus || 0) + dir;
    c.goalChanges--;
    return true;
  };
  YA.RULES = ['遅刻をしない', '挨拶と片付けを徹底する', '練習は全力で走る', 'SNSは控える', '試合の日は早く寝る'];

  // 年度はじめ（4月）に呼ぶ
  YA.yearStart = function (w) {
    const c = w.club;
    for (const p of Object.values(w.players)) {
      p.sum0 = YA.abSum(p);
      p.minsA = 0;
      p.minsYr = 0;
    }
    c.staffChanges = 1;
    c.alloc = Object.assign({ scout: 18, camp: 14, facility: 8 }, c.alloc);
    // 前の年の連帯貢献金などを予算に
    c.total = Math.round(TIER_BASE[c.tier] * (0.85 + c.rep / 300) * (1 + (c.budgetAdj || 0)) + (c.solidarity || 0));
    c.solidarityLast = c.solidarity || 0;
    c.solidarity = 0;
    c.facPts += YA.budget(w).facility;
    c.spent = { scout: 0, camp: 0 };
    c.facility = YA.facilityLevel(w);
    YA.genMarket(w);
    YA.newLeague(w);
    YA.newCup(w);
    YA.makeGoals(w);
    w.rules = [];
    w.campChoice = null;
    w.yearIntro = true; // ホームで目標と約束事の画面を出す
    // 寮
    const dorm = Object.values(w.players).filter((p) => p.dorm).length;
    const cap = YA.dormCap(w);
    const r = YA.rngOf(w.seed + w.year * 41);
    let left = cap - dorm;
    for (const p of Object.values(w.players)) if (p.dorm == null) {
      p.dorm = left > 0 && r.chance(0.5);
      if (p.dorm) left--;
    }
  };

  // ---------- 年末の評価 ----------
  YA.evaluate = function (w) {
    const c = w.club;
    const rank = YA.myRank(w);
    const ps = Object.values(w.players).filter((p) => p.sum0 != null);
    const avg = ps.length ? ps.reduce((s, p) => s + (YA.abSum(p) - p.sum0), 0) / ps.length : 0;
    const g1 = Object.values(w.players).filter((p) => p.grade === 1).reduce((s, p) => s + (p.minsA || 0), 0);
    const res = c.goals.map((g) => {
      let val;
      let ok;
      let part;
      if (g.k === 'result') { val = `${rank}位`; ok = rank <= g.n; part = rank <= g.n + 2 ? 0.5 : 0; }
      else if (g.k === 'develop') { val = `平均+${avg.toFixed(1)}`; ok = avg >= g.x; part = avg >= g.x * 0.7 ? 0.5 : 0; }
      else { val = `${Math.round(g1)}分`; ok = g1 >= g.t; part = g1 >= g.t * 0.7 ? 0.5 : 0; }
      return { k: g.k, label: GOAL_DEF[g.k].label, text: YA.goalText(g), val, ok, score: ok ? 1 + (g.bonus > 0 ? 0.2 : 0) : part };
    });
    const score = res.reduce((s, x) => s + x.score, 0);
    const letter = score >= 3 ? 'S' : score >= 2.3 ? 'A' : score >= 1.5 ? 'B' : score >= 0.8 ? 'C' : 'D';
    const d = score - 1.5;
    c.trust = clamp(c.trust + d * 9, 0, 100);
    c.rep = clamp(c.rep + d * 3 + (w.leagueEndMove === -1 ? 4 : w.leagueEndMove === 1 ? -4 : 0), 0, 100);
    c.budgetAdj = clamp((c.budgetAdj || 0) + d * 0.05, -0.3, 0.4);
    w.rep = c.rep;
    const rec = { year: w.year, letter, score: Math.round(score * 10) / 10, rank, level: w.league ? w.league.level : 2, goals: res };
    c.eval.push(rec);
    let dismissed = false;
    if (letter === 'D') c.bad++;
    else c.bad = 0;
    if (c.bad >= 2) {
      if (c.noFire) {
        c.trust = clamp(c.trust - 12, 0, 100);
        c.budgetAdj = clamp((c.budgetAdj || 0) - 0.1, -0.3, 0.4);
        c.bad = 1;
        YA.noteTier(w, 1, 'D評価が続きました。解任はありませんが、信頼度と予算が大きく下がりました');
      } else dismissed = true;
    }
    c.contract.left--;
    return { rec, dismissed };
  };

  // ---------- 契約・移籍・解任 ----------
  YA.moveOffers = function (w) {
    const r = YA.rngOf(w.seed * 71 + w.year * 9);
    const rep = w.club.rep;
    const base = rep >= 75 ? 1 : rep >= 50 ? 2 : 3;
    const tiers = [base, clamp(base + 1, 1, 3), clamp(base - (r.chance(0.5) ? 1 : 0), 1, 3)];
    const names = ['横浜', '川崎', '大宮', '千葉', '東京', '名古屋', '大阪', '神戸', '広島', '福岡', '仙台', '札幌', '静岡', '新潟'];
    const nick = ['ブルーウィング', 'シルバーホーク', 'アルバトロス', 'サンライズ', 'レッドフォックス', 'ノースウィンド', 'ミストラル', 'クレセント'];
    const seen = new Set();
    const out = [];
    for (const t of tiers) {
      let n;
      do n = r.pick(names) + ' ' + r.pick(nick) + 'U-18';
      while (seen.has(n));
      seen.add(n);
      out.push({ tier: t, name: n, budget: Math.round(TIER_BASE[t] * (0.85 + rep / 300)) });
    }
    return out;
  };
  YA.renewContract = function (w) {
    w.club.contract = { left: 3, years: 3 };
    w.pendingContract = null;
    YA.noteTier(w, 1, '契約を更新しました（3年）');
  };
  // 新しいクラブへ：36人を一から知る。指導者の評判・卒業生の名鑑は引き継ぐ
  YA.moveTo = function (w, offer, reason) {
    const rng = YA.rngOf(w.seed * 13 + w.year * 77);
    for (const id of Object.keys(w.players)) delete w.players[id];
    w.nextId += 100;
    const used = new Set();
    for (const g of [1, 2, 3]) YA._genGrade(rng, w, g, used);
    YA._numbers(w);
    YA.autoTeams(w, true);
    w.rec = { w: 0, d: 0, l: 0, gf: 0, ga: 0 };
    w.results = [];
    w.h2h = {};
    w.captain = null;
    w.vice = null;
    w.rel = [];
    w.scouting = null;
    const keepEval = w.club.eval;
    const rep = w.club.rep;
    const noFire = w.club.noFire;
    w.club = { rep, noFire, eval: keepEval, careerClubs: w.club.careerClubs };
    YA.newClub(w, offer.tier, offer.name);
    w.club.rep = rep;
    w.club.eval = keepEval;
    w.pendingContract = null;
    w.plan = YA.defaultPlan();
    YA.autoPlan(w);
    YA.relations && YA.relations(w);
    YA.yearStart(w);
    YA.noteTier(w, 1, `${offer.name}（${YA.TIER_NAME[offer.tier]}）に移りました。${reason || ''}新しい36人を一から知りましょう`);
  };

  // ---------- 出来事の追加：トップ・代表・クラブの要望・取材・規律・引き抜き ----------
  const E = YA.EVENTS;
  const pname = (p) => p.num + '番 ' + p.name;
  const o = (label, kind, extra, run) => ({ label, kind, extra, run });
  const best = (w, f) => Object.values(w.players).filter(f).sort((a, b) => YA.ovr(b) - YA.ovr(a))[0] || null;
  const away = (p) => p.away > 0 || p.inj > 0;

  E.push({ id: 'top', name: 'トップチームの打診', weight: 0.9,
    pick: (w, r) => { const p = best(w, (q) => q.grade >= 2 && !away(q) && q.team === 'A' && YA.ovr(q) >= 10.8); return p && r.chance(0.7) ? p : null; },
    text: (p, w) => `トップチームの監督から連絡があった。「${pname(p)}を練習に参加させてほしい」（好みの型：${w.top ? w.top.likes : '技術のある選手'}）`,
    opts: [
      o('応じる（今週は不在。本人は大きく伸びる）', 'push', (w, p) => { p.away = 1; p.conf = clamp(p.conf + 6, 0, 100); for (const a of ['判断', '予測', 'ファーストタッチ', 'パス']) p.prog[a] = (p.prog[a] || 0) + 0.9; YA.addTrust(w, 3, 'トップへの協力'); YA.addRep(w, 1); }),
      o('断る（試合を優先する）', 'firm', (w, p) => { YA.addTrust(w, -7, 'トップの打診を断った'); p.conf = clamp(p.conf - 3, 0, 100); }),
    ] });
  E.push({ id: 'nat', name: '代表への招集', weight: 0.55,
    pick: (w, r) => { const p = best(w, (q) => q.grade >= 2 && !away(q) && YA.ovr(q) >= 11.8 && !q.natThisYear); return p && r.chance(0.5) ? p : null; },
    text: (p) => `${pname(p)}にU-18代表から招集がかかった。2週間チームを離れることになる`,
    opts: [
      o('送り出す（本人は伸び、クラブの評判が上がる）', 'push', (w, p) => { p.away = 2; p.natThisYear = true; p.nat = (p.nat || 0) + 1; p.conf = clamp(p.conf + 8, 0, 100); p.spurt = Math.max(p.spurt, 6); YA.addRep(w, 2); p.hist.unshift({ y: w.year, w: w.week, t: 'U-18代表に招集された' }); YA.noteTier(w, 1, pname(p) + ' がU-18代表に招集された（2週間不在）', p.id); }),
      o('「大一番に必要だ」と断る', 'firm', (w, p) => { p.conf = clamp(p.conf - 6, 0, 100); p.unrest += 1.5; YA.addRep(w, -1); }),
    ] });
  const CLUB_REQ = [
    { text: 'クラブから要望が届いた。「若手を育てる方針のため、高1をもっと試合で使ってほしい」', yes: (w) => { w.club.reqYoung = 6; }, yesMsg: '今後6週、高1を使う約束', trust: [4, -6] },
    { text: 'クラブから要望が届いた。「スポンサー行事に、主力を2人出してほしい」', yes: (w) => { const ps = Object.values(w.players).filter((p) => p.team === 'A' && !away(p)).sort((a, b) => YA.ovr(b) - YA.ovr(a)).slice(0, 2); ps.forEach((p) => (p.away = 1)); }, yesMsg: '主力2人が今週は不在になる', trust: [5, -5] },
    { text: 'クラブから要望が届いた。「地元の中学生向けの体験練習会を開きたい。練習を1日使えるか」', yes: (w) => { w.plan.days[4] = { menu: '回復', int: 'light' }; YA.addRep(w, 2); }, yesMsg: '金曜が体験練習会になり、評判が上がる', trust: [3, -4] },
  ];
  E.push({ id: 'club', name: 'クラブの要望', weight: 0.8, club: true,
    pick: (w, r) => ({ id: '', _club: r.int(0, CLUB_REQ.length - 1) }),
    text: (p, w) => CLUB_REQ[w._clubReq || 0].text,
    opts: [
      o('応じる', 'warm', null, (w) => { const q = CLUB_REQ[w._clubReq || 0]; q.yes(w); YA.addTrust(w, q.trust[0], '要望に応えた'); return { line: q.yesMsg, small: '信頼度 +' + q.trust[0] }; }),
      o('断る', 'firm', null, (w) => { const q = CLUB_REQ[w._clubReq || 0]; YA.addTrust(w, q.trust[1], '要望を断った'); return { line: '要望を断った', small: '信頼度 ' + q.trust[1] }; }),
    ] });
  E.push({ id: 'media', name: '取材', weight: 0.5,
    pick: (w, r) => { const c = Object.values(w.players).filter((p) => YA.ovr(p) > 11 && !away(p)); return c.length ? r.pick(c) : null; },
    text: (p) => `地元の雑誌から${pname(p)}への取材依頼が届いた`,
    opts: [o('受けさせる', 'push', (w, p) => { YA.addRep(w, 1.5); if (p.pers['大舞台'] === '目立ちたがり') p.conf = clamp(p.conf + 6, 0, 100); }), o('断る（練習に集中させる）', 'wait')] });
  E.push({ id: 'poach', name: 'スタッフの引き抜き', weight: 0.35, club: true,
    pick: (w, r) => ({ id: '', _staff: r.int(0, w.club.staff.length - 1) }),
    text: (p, w) => { const s = w.club.staff[w._staffIdx || 0]; return `他のクラブが${s.name}（${s.role}）を引き抜こうとしている。本人は迷っているようだ`; },
    opts: [
      o('給料を上げて引き止める', 'warm', null, (w) => { const s = w.club.staff[w._staffIdx || 0]; s.salary = Math.round(s.salary * 1.2); return { line: s.name + 'は残ることになった（給料 +20%）', small: '' }; }),
      o('送り出す（後任はクラブが決める）', 'wait', null, (w, p, r) => { const s = w.club.staff[w._staffIdx || 0]; const n = YA.genStaffPublic(r, s.role); w.club.staff[w._staffIdx || 0] = n; return { line: `${s.name}は去った。後任は${n.name}（能力${n.ab}）`, small: '' }; }),
    ] });
  YA.genStaffPublic = (r, role) => genStaff(r, role, 5, 12);

  // 規律（決定46・47）
  const DISC = (id, name, text, rule, weightPick) => ({ id, name, weight: 0.9,
    pick: (w, r) => { const c = Object.values(w.players).filter(weightPick); return c.length ? r.pick(c) : null; },
    text, opts: [
      o('見逃す', 'wait', (w, p) => { w.disc = clamp((w.disc == null ? 60 : w.disc) - 4, 0, 100); p.conf = clamp(p.conf + 1, 0, 100); }),
      o('注意する', 'firm', (w) => { w.disc = clamp((w.disc == null ? 60 : w.disc) + 2, 0, 100); }),
      o('次の試合から外す', 'firm', (w, p) => { p.suspend = 1; w.disc = clamp((w.disc == null ? 60 : w.disc) + 5, 0, 100); if (p.team === 'A') p.unrest += 1.5; }),
      o('練習を厳しくする（全員）', 'wait', (w) => { for (const q of Object.values(w.players)) { q.fat = clamp(q.fat + 5, 0, 100); } w.disc = clamp((w.disc == null ? 60 : w.disc) + 4, 0, 100); }),
      o('約束どおり処分する', 'firm', (w, p) => { const has = (w.rules || []).indexOf(rule) >= 0; w.disc = clamp((w.disc == null ? 60 : w.disc) + (has ? 8 : 3), 0, 100); if (has) YA.addTrust(w, 1); if (p.team === 'A' && YA.ovr(p) > 11.5) p.suspend = 1; }),
    ] });
  E.push(DISC('late', '遅刻', (p) => `${pname(p)}が練習に遅刻してきた。理由は寝坊だという`, '遅刻をしない', (p) => p.pers['練習への向き合い'] === '練習嫌い' || p.pers['人との関わり'] === 'お調子者' || p.pers['感情の波'] === '気分屋'));
  E.push(DISC('fight', 'もめごと', (p) => `${pname(p)}が練習中に仲間と言い合いになった。周りが止めに入った`, '挨拶と片付けを徹底する', (p) => p.pers['感情の波'] === '短気' || p.pers['プレーの気質'] === '闘争的' || p.pers['気持ちの強さ'] === '負けず嫌い'));
  E.push(DISC('slack', '練習の手抜き', (p) => `${pname(p)}の練習が明らかに手抜きになっている。コーチが指摘してきた`, '練習は全力で走る', (p) => p.pers['練習への向き合い'] === '練習嫌い' || p.unrest > 2));

  // 設定：同じ events に載せた 'club' 系の p は null として扱う
  YA.EVENT_NULL = new Set(['club', 'poach']);

  // ---------- 夏合宿・遠征（26週）----------
  YA.campOptions = function (w) {
    const b = YA.budget(w);
    const spent = w.club.spent.camp || 0;
    const left = b.camp - spent;
    const trust = w.club.trust;
    return [
      { k: 'none', label: '行かない', cost: 0, ok: true, note: '通常どおり練習する' },
      { k: 'domestic', label: '国内の合宿（練習1.3倍）', cost: 150, ok: left >= 150, note: '全員の自信 +2。疲れが溜まる' },
      { k: 'overseas', label: '海外遠征（練習1.6倍・評判が上がる）', cost: 320, ok: left >= 320 && trust >= 50, note: '費用大。信頼度50以上が必要。疲れ・怪我のおそれも大きい' },
    ].map((x) => Object.assign(x, { why: x.ok ? '' : trust < 50 && x.k === 'overseas' ? '信頼度が足りません' : '遠征費の配分が足りません' }));
  };
  YA.applyCamp = function (w) {
    const ch = w.campChoice || 'none';
    w.campMult = 1;
    if (ch === 'domestic') {
      w.campMult = 1.3;
      w.club.spent.camp += 150;
      for (const p of Object.values(w.players)) p.conf = clamp(p.conf + 2, 0, 100);
      YA.noteTier(w, 2, '夏合宿で全員が鍛えられた（練習1.3倍）');
    } else if (ch === 'overseas') {
      w.campMult = 1.6;
      w.club.spent.camp += 320;
      YA.addRep(w, 3);
      for (const p of Object.values(w.players)) { p.conf = clamp(p.conf + 4, 0, 100); p.fat = clamp(p.fat + 12, 0, 100); }
      YA.noteTier(w, 1, '海外遠征で大きな経験を積んだ（練習1.6倍・評判 +3）');
    }
  };
})();
