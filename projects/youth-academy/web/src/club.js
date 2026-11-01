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
  // 評判：高いほど上がりにくい（90を超えるのは一握り）。下がるのはそのまま
  YA.addRep = function (w, d) {
    const r = w.club.rep;
    w.club.rep = clamp(r + (d > 0 ? d * Math.max(0.1, (100 - r) / 60) : d), 0, 100);
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
    develop: { label: '育成', text: (g) => `全選手の能力の合計を平均+${g.x}以上伸ばす`, opts: [18, 22, 28], key: 'x' },
    promise: { label: '約束', text: (g) => `高1がAチームで合計${g.t}分以上出る`, opts: [1200, 2400, 4000], key: 't' },
  };
  YA.GOAL_DEF = GOAL_DEF;
  YA.makeGoals = function (w) {
    const c = w.club;
    const lv = w.league ? w.league.level : 2;
    c.goals = [{ k: 'result', n: lv === 1 ? 8 : 6 }, { k: 'develop', x: 22 }, { k: 'promise', t: 2400 }];
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
  YA.RULES = ['挨拶と片付けを徹底する', '練習は全力で走る', 'SNSは控える', '試合の日は早く寝る'];

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
    // 連帯貢献金は予算に足すが、クラブの本体にも回るので、育成の予算に入るのは基本予算の6割まで
    c.solidarityIn = Math.round(Math.min(c.solidarity || 0, TIER_BASE[c.tier] * 0.6));
    c.total = Math.round(TIER_BASE[c.tier] * (0.85 + c.rep / 300) * (1 + (c.budgetAdj || 0)) + c.solidarityIn);
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
    const d = score - 1.9; // B評価（2つ達成）はほぼ現状維持、A以上で信頼が上がり、C以下で下がる
    c.trust = clamp(c.trust + d * 9, 0, 100);
    c.trust += (50 - c.trust) * 0.15; // 信頼度は、少しずつ真ん中へ戻る（張り付かないように）
    YA.addRep(w, d * 3 + (w.leagueEndMove === -1 ? 4 : w.leagueEndMove === 1 ? -4 : 0));
    c.rep += (50 - c.rep) * 0.08; // 評判も、何もしなければ少しずつ真ん中へ戻る
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
    // 一つ上・同じ・一つ下の部から1つずつ（端の部では同じ部が2つになるので、クラブの色で差をつける）
    const tiers = [clamp(base - 1, 1, 3), base, clamp(base + 1, 1, 3)];
    const FLAVOR = [['予算が多い', 0.15], ['予算はふつう', 0], ['予算は少なめ（そのぶん期待も低い）', -0.12]];
    const names = ['横浜', '川崎', '大宮', '千葉', '東京', '名古屋', '大阪', '神戸', '広島', '福岡', '仙台', '札幌', '静岡', '新潟'];
    const nick = ['ブルーウィング', 'シルバーホーク', 'アルバトロス', 'サンライズ', 'レッドフォックス', 'ノースウィンド', 'ミストラル', 'クレセント'];
    const seen = new Set();
    const out = [];
    tiers.forEach((t, i) => {
      let n;
      do n = r.pick(names) + ' ' + r.pick(nick) + 'U-18';
      while (seen.has(n));
      seen.add(n);
      const [note, adj] = FLAVOR[i];
      out.push({ tier: t, name: n, note, budgetAdj: adj, budget: Math.round(TIER_BASE[t] * (0.85 + rep / 300) * (1 + adj)) });
    });
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
    w.scouting = YA.newScouting();
    const keepEval = w.club.eval;
    const rep = w.club.rep;
    const noFire = w.club.noFire;
    w.club = { rep, noFire, eval: keepEval, careerClubs: w.club.careerClubs };
    YA.newClub(w, offer.tier, offer.name);
    w.club.rep = rep;
    w.club.eval = keepEval;
    if (offer.budgetAdj) w.club.budgetAdj = offer.budgetAdj;
    YA.initTop(w);
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
    text: (p, w) => `トップチーム（${w.top ? w.top.name + '・' + YA.J_NAME[w.top.j] : 'トップ'}）の監督から連絡があった。「${pname(p)}（総合力${YA.rating(p)}）を、今週の練習に参加させてほしい」`,
    opts: [
      o('応じる（今週は不在。本人は大きく伸びる）', 'push', (w, p) => { p.away = 1; p.conf = clamp(p.conf + 6, 0, 100); for (const a of ['判断', '予測', 'ファーストタッチ', 'パス']) p.prog[a] = (p.prog[a] || 0) + 0.9; YA.addTrust(w, 3, 'トップへの協力'); YA.addRep(w, 1); }),
      o('断る（試合を優先する）', 'firm', (w, p) => { YA.addTrust(w, -7, 'トップの打診を断った'); p.conf = clamp(p.conf - 3, 0, 100); }),
    ] });
  E.push({ id: 'nat', name: '代表への招集', weight: 0,
    pick: (w, r) => { const p = best(w, (q) => q.grade >= 2 && !away(q) && YA.ovr(q) >= 11.8 && !q.natThisYear); return p && r.chance(0.5) ? p : null; },
    text: (p) => `${pname(p)}にU-18代表から招集がかかった。2週間チームを離れることになる`,
    opts: [
      o('送り出す（本人は伸び、クラブの評判が上がる）', 'push', (w, p) => { p.away = 2; p.natThisYear = true; p.nat = (p.nat || 0) + 1; p.conf = clamp(p.conf + 8, 0, 100); p.spurt = Math.max(p.spurt, 6); YA.addRep(w, 2); p.hist.unshift({ y: w.year, w: w.week, t: 'U-18代表に招集された' }); YA.noteTier(w, 1, pname(p) + ' がU-18代表に招集された（2週間不在）', p.id); }),
      o('「大一番に必要だ」と断る', 'firm', (w, p) => { p.conf = clamp(p.conf - 6, 0, 100); p.unrest += 1.5; YA.addRep(w, -1); }),
    ] });
  // 年代別の日本代表（U-16＝高1・U-17＝高2・U-18＝高3）。年に3回の活動で、選考ライン（総合力）を超えた子が選ばれる
  YA.YOUTH_NAT = { 1: ['U-16日本代表', 100], 2: ['U-17日本代表', 110], 3: ['U-18日本代表', 118] };
  YA.NAT_WEEKS = [7, 17, 33];
  YA.natPicks = (w) => Object.values(w.players).filter((p) => p.inj <= 0 && YA.YOUTH_NAT[p.grade] && YA.rating(p) >= YA.YOUTH_NAT[p.grade][1]).sort((a, b) => YA.rating(b) - YA.rating(a)).slice(0, 5);
  const natSend = (w, p) => {
    const [team] = YA.YOUTH_NAT[p.grade];
    p.away = 1;
    p.youthCaps = (p.youthCaps || 0) + 1;
    p.youthTeam = team;
    p.conf = clamp(p.conf + 6, 0, 100);
    p.spurt = Math.max(p.spurt, 4);
    p.hist.unshift({ y: w.year, w: w.week, t: team + 'に選ばれた' });
  };
  E.push({ id: 'natcall', name: '年代別日本代表の招集', weight: 0, club: true,
    pick: () => null,
    text: (p, w) => {
      const ids = (w._natCall || []).filter((id) => w.players[id]);
      return '年代別の日本代表から招集が届いた（1週間チームを離れる）。' + ids.map((id) => { const q = w.players[id]; return `${q.num}番 ${q.name}（${YA.YOUTH_NAT[q.grade][0]}・総合力${YA.rating(q)}）`; }).join('、') + `。選考ラインは U-16 ${YA.YOUTH_NAT[1][1]}・U-17 ${YA.YOUTH_NAT[2][1]}・U-18 ${YA.YOUTH_NAT[3][1]}`;
    },
    opts: [
      o('全員送り出す（本人は伸び、クラブの評判が上がる）', 'push', null, (w) => { const ids = (w._natCall || []).filter((id) => w.players[id]); for (const id of ids) natSend(w, w.players[id]); YA.addRep(w, ids.length); return { line: `${ids.length}人を送り出した。それぞれ1週間チームを離れる`, small: `評判 +${ids.length}・自信 +6` }; }),
      o('Aの先発の子だけ残し、ほかは送り出す', 'wait', null, (w) => { const ids = (w._natCall || []).filter((id) => w.players[id]); const st = new Set((w.lineupA || []).map((x) => x.pid)); const go = ids.filter((id) => !st.has(id)); for (const id of go) natSend(w, w.players[id]); for (const id of ids.filter((x) => st.has(x))) { w.players[id].unrest += 1.5; w.players[id].conf = clamp(w.players[id].conf - 4, 0, 100); } YA.addRep(w, go.length - (ids.length - go.length) * 0.5); return { line: `${go.length}人を送り出し、${ids.length - go.length}人を残した。残った子は少し不満そうだ`, small: '' }; }),
      o('全員断る（試合を優先する）', 'firm', null, (w) => { const ids = (w._natCall || []).filter((id) => w.players[id]); for (const id of ids) { w.players[id].unrest += 1.5; w.players[id].conf = clamp(w.players[id].conf - 6, 0, 100); } YA.addRep(w, -ids.length); return { line: '代表の招集を断った。協会からの評判と、本人たちの気持ちが下がった', small: `評判 -${ids.length}` }; }),
    ] });
  YA.EVENT_ABOUT = YA.EVENT_ABOUT || {};
  YA.EVENT_ABOUT.natcall = '年に3回（5月・7月・1月）、選考ラインを超えた子が年代別の代表に選ばれます。送り出すと本人は伸び、クラブの評判が上がります。';
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
  const DISC = (id, name, text, rule, weightPick, wt) => ({ id, name, weight: wt || 0.9,
    pick: (w, r) => { const c = Object.values(w.players).filter(weightPick); return c.length ? r.pick(c) : null; },
    text, opts: [
      o('見逃す', 'wait', (w, p) => { w.disc = clamp((w.disc == null ? 60 : w.disc) - 4, 0, 100); p.conf = clamp(p.conf + 1, 0, 100); }),
      o('注意する', 'firm', (w) => { w.disc = clamp((w.disc == null ? 60 : w.disc) + 2, 0, 100); }),
      o('次の試合から外す', 'firm', (w, p) => { p.suspend = 1; w.disc = clamp((w.disc == null ? 60 : w.disc) + 5, 0, 100); if (p.team === 'A') p.unrest += 1.5; }),
      o('練習を厳しくする（全員）', 'wait', (w) => { for (const q of Object.values(w.players)) { q.fat = clamp(q.fat + 5, 0, 100); } w.disc = clamp((w.disc == null ? 60 : w.disc) + 4, 0, 100); }),
      o('約束どおり処分する', 'firm', (w, p) => { const has = (w.rules || []).indexOf(rule) >= 0; w.disc = clamp((w.disc == null ? 60 : w.disc) + (has ? 8 : 3), 0, 100); if (has) YA.addTrust(w, 1); if (p.team === 'A' && YA.ovr(p) > 11.5) p.suspend = 1; }),
    ] });
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

  // ---------- 自分のクラブのトップチーム（Jリーグ）----------
  // 名前はユースの名前から「U-18」を除いたもの。部はユースの部に合わせて始まり、毎年の順位で昇格・降格する
  const J_NAME = { 1: 'J1リーグ', 2: 'J2リーグ', 3: 'J3リーグ' };
  YA.J_NAME = J_NAME;
  const J_AVG = { 1: 138, 2: 122, 3: 108 }; // その部の選手の総合力のめやす（200点）
  YA.topName = (w) => String(w.clubName || '').replace(/U-18$/, '').trim();
  function proPlayer(w, r, j, pos, used, age) {
    const name = YA.randName(r, used);
    const a = age || r.int(19, 33);
    const rating = Math.round(clamp(J_AVG[j] + (r() - 0.5) * 30 - (a <= 21 ? 8 : 0) - (a >= 32 ? 5 : 0), 80, 175));
    return { name, pos, age: a, rating, academy: false };
  }
  const TOP_POS = ['GK', 'GK', 'GK', 'CB', 'CB', 'CB', 'CB', 'LB', 'RB', 'LB', 'RB', 'DM', 'DM', 'CM', 'CM', 'CM', 'AM', 'AM', 'LW', 'RW', 'LW', 'RW', 'ST', 'ST', 'ST', 'SS'];
  YA.initTop = function (w) {
    const r = YA.rngOf(w.seed * 31 + w.year * 7 + 5);
    const pc = YA.proClubOf(w.clubName);
    const j = pc ? pc.tier : w.club ? w.club.tier : 2;
    const used = new Set(Object.values(w.players).map((p) => p.name));
    w.top = { name: YA.topName(w), j, squad: TOP_POS.map((pos) => proPlayer(w, r, j, pos, used)), hist: [] };
    return w.top;
  };
  // ユースから上がった子（卒業生のうち、いまトップにいる子）
  YA.topAcademy = (w) => (w.alumni || []).filter((a) => !a.retired && a.status === 'pro' && w.top && a.club === w.top.name);
  // トップの顔ぶれ：生え抜き（卒業生）と、ほかから来たプロ。総合力の順
  YA.topSquad = function (w) {
    if (!w.top) YA.initTop(w);
    const ac = YA.topAcademy(w).map((a) => ({ name: a.name, pos: a.main || a.pos, age: a.age, rating: YA.rate(a.ovr), academy: true, ref: a }));
    return w.top.squad.concat(ac).sort((a, b) => b.rating - a.rating);
  };
  YA.J_GAMES = 38;
  // 今の節（ユースの1年＝40週で、Jリーグの38節を進める）
  YA.topRound = (w) => Math.min(YA.J_GAMES, Math.round((Math.min(w.week, 40) / 40) * YA.J_GAMES));
  YA.topStrength = function (w) {
    const sq = YA.topSquad(w);
    return sq.slice(0, 14).reduce((s2, x) => s2 + x.rating, 0) / Math.min(14, sq.length || 1);
  };
  YA.topTable = function (w, games) {
    if (!w.top) YA.initTop(w);
    const t = w.top;
    const k = games == null ? YA.topRound(w) : games;
    const others = YA.PRO_CLUBS.filter((c) => c.tier === t.j && c.name !== t.name).map((c) => c.name);
    const TOWNS = ['青森', '富山', '福井', '佐賀', '和歌山', '島根', '香川', '沖縄', '八戸', '浜松', '静岡', '岩手'];
    for (let i = 0; others.length < 19 && i < TOWNS.length; i++) others.push(TOWNS[i] + ' FC');
    const teams = others.slice(0, 19).map((name) => ({ name, str: J_AVG[t.j] + ((YA.hash(name + w.year) % 100) / 100 - 0.5) * 22 }));
    teams.push({ name: t.name, str: YA.topStrength(w), me: true });
    const rows = teams.map((tm) => {
      const r = YA.rngOf(YA.hash(tm.name) * 7 + w.year * 131 + t.j);
      const dev = (r() - 0.5) * 16; // その年のぶれ（勝点、38節あたり）
      const ppg = clamp(1.35 + (tm.str - J_AVG[t.j]) * 0.055, 0.45, 2.5);
      let pts = Math.max(0, Math.round(ppg * k + dev * (k / YA.J_GAMES)));
      const d = Math.round(k * (0.22 + r() * 0.08));
      let wn = Math.max(0, Math.min(k - d, Math.round((pts - d) / 3)));
      const dd = clamp(pts - wn * 3, 0, k - wn);
      pts = wn * 3 + dd;
      const gf = Math.round(k * (1.1 + (tm.str - J_AVG[t.j]) * 0.03 + r() * 0.3));
      const ga = Math.max(0, Math.round(gf - (wn - (k - wn - dd)) * 1.05));
      return { name: tm.name, me: !!tm.me, p: k, w: wn, d: dd, l: k - wn - dd, gf, ga, gd: gf - ga, pts };
    });
    rows.sort((a, b) => b.pts - a.pts || b.gd - a.gd || b.gf - a.gf);
    rows.forEach((x, i) => (x.rank = i + 1));
    return rows;
  };
  YA.topNow = function (w) {
    const rows = YA.topTable(w);
    const me = rows.find((x) => x.me);
    return { j: w.top.j, league: J_NAME[w.top.j], round: YA.topRound(w), rank: me.rank, pts: me.pts, rows };
  };
  // 1年の終わり：トップの順位（38節の順位表）、昇格・降格、年齢と入れ替わり
  YA.topSeason = function (w) {
    if (!w.top) YA.initTop(w);
    const t = w.top;
    const r = YA.rngOf(w.seed * 43 + w.year * 19 + 3);
    const str = YA.topStrength(w);
    const teams = 20;
    const fin = YA.topTable(w, YA.J_GAMES).find((x) => x.me);
    const rank = fin.rank;
    let move = 0;
    if (t.j > 1 && rank <= 2) move = -1;
    else if (t.j < 3 && rank >= teams - 2) move = 1;
    t.hist.push({ y: w.year, j: t.j, rank, str: Math.round(str), pts: fin.pts });
    YA.noteTier(w, 1, `トップチーム（${t.name}）は${J_NAME[t.j]}で${rank}位（勝点${fin.pts}）` + (move < 0 ? `。${J_NAME[t.j - 1]}へ昇格します` : move > 0 ? `。${J_NAME[t.j + 1]}へ降格します` : ''));
    t.j += move;
    // 年齢と力の変化、引退・移籍
    const used = new Set(t.squad.map((x) => x.name));
    for (const x of t.squad) {
      x.age++;
      x.rating = Math.round(clamp(x.rating + (x.age <= 24 ? r.int(0, 6) : x.age >= 31 ? -r.int(1, 6) : r.int(-3, 3)), 70, 185));
    }
    t.squad = t.squad.filter((x) => !(x.age >= 35 || (x.age >= 31 && r() < 0.25) || r() < 0.08));
    // 生え抜きは12人まで。あふれた子（力の下の子から）は、出場の機会を求めてほかのJクラブへ移る
    const ac = YA.topAcademy(w).sort((a, b) => b.ovr - a.ovr);
    for (const a of ac.slice(12)) {
      const rt = YA.rate(a.ovr);
      const tier = rt >= 125 ? 1 : rt >= 112 ? 2 : 3;
      const pool = YA.PRO_CLUBS.filter((c) => c.tier === tier && c.name !== t.name);
      a.club = (pool.length ? r.pick(pool) : r.pick(YA.PRO_CLUBS)).name;
      a.league = J_NAME[tier];
      a.transfers = (a.transfers || 0) + 1;
      YA.noteTier(w, 2, `生え抜きの${a.name}が、出場の機会を求めて${a.club}（${a.league}）へ移籍しました`);
    }
    // 足りない枠は、その部の水準の選手を取る（ユースから上がった子がいれば、その分は取らない）
    const need = 26 - YA.topAcademy(w).length;
    const cnt = (pos) => t.squad.filter((x) => x.pos === pos).length + YA.topAcademy(w).filter((a) => (a.main || a.pos) === pos).length;
    let g = 0;
    while (t.squad.length < need && g++ < 60) {
      const pos = TOP_POS.find((p, i) => cnt(p) < TOP_POS.filter((q) => q === p).length) || r.pick(TOP_POS);
      t.squad.push(proPlayer(w, r, t.j, pos, used));
    }
    while (t.squad.length > need) t.squad.splice(t.squad.reduce((m, x, i, arr) => (x.rating < arr[m].rating ? i : m), 0), 1);
    return { rank, move };
  };
  // トップの登録に入れる力（26人の中で下から5番目の子と並ぶ）
  YA.topCutLine = function (w) {
    const sq = YA.topSquad(w);
    const k = Math.max(0, sq.length - 5);
    return sq[k] ? sq[k].rating : J_AVG[w.top.j] - 12;
  };
  // いまのユースの子が、トップの中で何番目くらいか（同じポジション）
  YA.topRankFor = function (w, p) {
    const sq = YA.topSquad(w).filter((x) => YA.GROUP[x.pos] === p.pos);
    const r0 = YA.rating(p);
    return { n: sq.filter((x) => x.rating > r0).length + 1, of: sq.length + 1 };
  };
  // 在学中のプロ契約（トップ昇格）：トップの主力と並ぶ力の子は、早めにトップが取りにくる
  YA.earlyProLine = (w) => {
    if (!w.top) YA.initTop(w);
    const sq = YA.topSquad(w);
    const k = Math.min(5, sq.length - 1); // トップの主力（上位6人）と並ぶ力
    // J1でやれる〜主力の水準（132〜140）。トップが強くても、日本代表に近い子をユースに置いたままにはしない
    return clamp(sq[k] ? sq[k].rating : J_AVG[w.top.j] + 10, 132, 140);
  };
  YA.earlyPro = function (w, pid) {
    const p = w.players[pid];
    if (!p) return null;
    if (!w.top) YA.initTop(w);
    const a = YA.alumniEntry(w, Object.assign({}, p, { _path: 'pro' }), `プロ契約（高${p.grade}でトップ昇格）`);
    a.age = 15 + p.grade;
    a.grade = p.grade;
    a.club = w.top.name;
    a.league = J_NAME[w.top.j];
    a.abroad = false;
    w.alumni.push(a);
    delete w.players[pid];
    YA.autoTeamsKeep(w);
    w._earlyN = w._earlyY === w.year ? (w._earlyN || 0) + 1 : 1;
    w._earlyY = w.year;
    YA.addRep(w, 2);
    YA.addTrust(w, 2, 'ユースからトップへ選手を送り出した');
    return a;
  };

  // 出来事：トップチームからのプロ契約の打診（トップの主力と並ぶ力の子。高1はさらに上の子だけ）
  YA.EVENTS.push({ id: 'early', name: 'トップチームからのプロ契約の打診', weight: 3,
    pick: (w, r) => {
      if (!w.top) return null;
      const line = YA.earlyProLine(w);
      // 在学中の契約はふつう1年に1人まで。主力をはっきり上回る子（+12）は、いつでも取りにくる
      const c = Object.values(w.players).filter((p) => !(p.away > 0) && p.inj <= 0 && YA.rating(p) >= line + (p.grade >= 2 ? 0 : 12) + ((w._earlyN || 0) >= 2 && w._earlyY === w.year ? 12 : 0) && !(p._earlyNo && w.year * 100 + w.week - p._earlyNo < 10));
      return c.length ? c.sort((a, b) => YA.rating(b) - YA.rating(a))[0] : null;
    },
    text: (p, w) => `トップチーム（${w.top.name}・${YA.J_NAME[w.top.j]}）が、${p.num}番 ${p.name}（高${p.grade}・総合力${YA.rating(p)}）にプロ契約を打診してきた。トップの主力と並ぶ力だ`,
    opts: [
      { label: '送り出す（プロ契約。ユースからは抜ける）', kind: 'push', run: (w, p, r) => { YA.earlyPro(w, p.id); const fill = Object.keys(w.players).length < 36; if (fill) YA.newcomer(w, r, 1); return { line: 'プロ契約を結び、トップチームへ上がった' + (fill ? '。空いた枠には、U-15から1人上がった' : ''), small: '評判 +2・信頼度 +2' }; } },
      { label: '卒業まではユースで育てる', kind: 'firm', run: (w, p) => { p.unrest += 2; p._earlyNo = w.year * 100 + w.week; YA.addTrust(w, -2, 'トップの打診を断った'); return { line: '残ることになった。本人は少し不満そうだ', small: '信頼度 -2・不満 +2' }; } },
    ] });
  YA.EVENT_ABOUT = YA.EVENT_ABOUT || {};
  YA.EVENT_ABOUT.early = 'トップの主力と並ぶ力の子は、卒業を待たずにトップが取りにきます。送り出すと評判と信頼度が上がり、ユースの戦力は下がります。';
})();
