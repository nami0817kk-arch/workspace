// 進路の相談・お知らせの3段・実績と引退・文字の大きさ・面談の会話・名前の書き換え。見せ方は views3.js。
(function () {
  'use strict';
  const YA = (globalThis.YA = globalThis.YA || {});

  // ---------- 卒業後の進路の相談（決定15）：推す・大学を勧める・他のクラブへ売り込む ----------
  YA.EVENTS.push({
    id: 'career', name: '卒業後の進路の相談', weight: 0,
    pick: () => null,
    text: (p) => {
      const o = YA.ovr(p);
      const wish = o >= 12 ? 'プロを目指したい' : o >= 10.5 ? '大学でサッカーを続けたい' : 'サッカーは続けたいが、進路に迷っている';
      return `${p.num}番 ${p.name}（高3・能力${o.toFixed(1)}）が、卒業後の進路を相談に来た。「${wish}と思っています。監督はどう思いますか」`;
    },
    opts: [
      { label: 'トップ昇格・プロ入りを推す（クラブにかけ合う。力が足りないと通らない）', kind: 'push', extra: (w, p) => { p._push = 'top'; } },
      { label: '大学に進んで、じっくり伸ばすことを勧める（のちにプロ入りしやすい）', kind: 'warm', extra: (w, p) => { p._push = 'univ'; } },
      { label: '他のクラブ（海外も）へ売り込む（決まれば評判が上がる）', kind: 'push', extra: (w, p) => { p._push = 'sell'; } },
    ],
  });

  // ---------- お知らせの3段（決定76）：必ず止める・お知らせ・記録だけ。項目ごとに段を変えられる ----------
  YA.NOTICE_KINDS = [
    ['怪我', /怪我/], ['成長期', /成長期/], ['特性の習得', /身につけた/], ['性格の変化', /性格が変わった/], ['伸び盛り・壁', /伸び盛り|壁に/], ['能力の低下', /能力が下が/],
    ['退団', /去った|退団/], ['卒業生の活躍', /卒業生/], ['クラブからの連絡', /信頼度|要望|契約/], ['スカウト', /入団を決め|断られ|候補/], ['試合・大会', /リーグ|大会|優勝|敗退/], ['よく伸びた', /よく伸びた/],
  ];
  YA.noticeKind = (text) => {
    for (const [k, re] of YA.NOTICE_KINDS) if (re.test(text)) return k;
    return 'そのほか';
  };
  YA.NOTICE_TIER_NAME = { 1: '必ず止める', 2: 'お知らせ', 3: '記録だけ' };
  // 設定で段を決めていれば、それを使う
  YA.noticeTier = (w, n) => (w.noticeTier && w.noticeTier[YA.noticeKind(n.text)]) || n.tier;

  // ---------- 実績と引退（決定51）----------
  YA.achievements = function (w) {
    const al = w.alumni;
    const list = [
      { k: 'champ', name: '全国リーグで優勝', note: '1部（全国リーグ）で1位', done: (w.leagueHist || []).some((x) => x.level === 1 && x.rank === 1) },
      { k: 'summer', name: '夏の全国大会で優勝', done: (w.trophies || []).some((t) => t.name === '夏の全国大会') },
      { k: 'winter', name: '冬のカップ戦で優勝', done: (w.trophies || []).some((t) => t.name === '冬のカップ戦') },
      { k: 'nat10', name: '代表経験者を10人出す', cur: al.filter((a) => a.nat > 0).length, goal: 10 },
      { k: 'u21', name: 'U-21代表を出す', note: '卒業生がU-21日本代表に選ばれる', done: al.some((a) => a.u21 > 0) },
      { k: 'full', name: 'フル代表を出す', note: '卒業生が日本代表に選ばれる', done: al.some((a) => a.status === 'pro' && a.nat > 0 && a.ovr >= 14) },
      { k: 'abroad', name: '卒業生が海外のクラブへ', done: al.some((a) => a.abroad) },
      { k: 'pro20', name: 'プロ入りした卒業生が20人', cur: al.filter((a) => a.status === 'pro').length, goal: 20 },
      { k: 'solid', name: '連帯貢献金の累計1,000万円', cur: w.solidTotal || 0, goal: 1000 },
      { k: 'years10', name: '10年指導する', cur: Math.max(0, w.year - 1), goal: 10 },
    ];
    for (const a of list) {
      if (a.done == null) a.done = a.cur >= a.goal;
    }
    return list;
  };
  YA.retire = function (w) {
    w.retired = { year: w.year, week: w.week };
  };
  // 指導者人生のまとめ（年表・育てた子・獲ったもの）
  YA.careerSummary = function (w) {
    const best = w.alumni.filter((a) => a.status !== 'left').slice().sort((a, b) => b.ovr - a.ovr).slice(0, 5);
    return {
      years: w.year - (w.week === 1 ? 1 : 0) || 1,
      clubs: (w.club.careerClubs || []).slice(),
      evals: w.club.eval.slice(),
      trophies: (w.trophies || []).slice(),
      best,
      pros: w.alumni.filter((a) => a.status === 'pro').length,
      nats: w.alumni.filter((a) => a.nat > 0).length,
      solid: w.solidTotal || 0,
      record: Object.assign({}, w.rec),
      ach: YA.achievements(w),
      coach: w.coach ? Object.assign({}, w.coach) : null,
    };
  };

  // ---------- 文字の大きさ（3段）----------
  YA.FONT_SCALES = [['小', 0.9], ['標準', 1], ['大', 1.14]];
  YA.applyFontScale = function (i) {
    const k = (YA.FONT_SCALES[i] || YA.FONT_SCALES[1])[1];
    try {
      const el = document.getElementById('app');
      if (el) el.style.zoom = k === 1 ? '' : String(k);
    } catch (e) {}
  };

  // ---------- 面談の会話（決定71）：相手の一言 → 言葉の違う選択肢3つ ----------
  YA.talkSetup = function (w, p) {
    if (p.inj > 0) return { line: '怪我がなかなか治らなくて、不安です', opts: [{ k: 'listen', label: '不安をゆっくり聞く' }, { k: 'push', label: '焦らず、必ず戻れると励ます' }, { k: 'issue', label: '今できることを具体的に示す' }] };
    if (p.conf < 40) return { line: '最近、自分に自信が持てなくて…', opts: [{ k: 'listen', label: '悩みを聞く' }, { k: 'praise', label: 'できていることを褒める' }, { k: 'push', label: '背中を押す' }] };
    if (p.unrest >= 2) return { line: 'もっと試合に出たいです。何が足りませんか', opts: [{ k: 'issue', label: '足りない点を伝える' }, { k: 'push', label: '練習で見せてほしいと求める' }, { k: 'praise', label: '期待していると伝える' }] };
    if (p.state && p.state.k === 'wall') return { line: '最近、伸び悩んでいる気がします', opts: [{ k: 'listen', label: '焦らなくていいと聞く' }, { k: 'issue', label: '課題を一緒に整理する' }, { k: 'push', label: '乗り越えろと背中を押す' }] };
    if (p.form >= 1 || (p.state && p.state.k === 'peak')) return { line: '今、調子がいいです！', opts: [{ k: 'praise', label: '褒める' }, { k: 'push', label: 'さらに上を求める' }, { k: 'issue', label: '気を引き締める' }] };
    if (p.pers['教えの受け止め方'] === '構ってほしい') return { line: '監督、見てくれていますか？', opts: [{ k: 'praise', label: 'しっかり見ていると伝える' }, { k: 'listen', label: '話を聞く' }, { k: 'issue', label: '課題を伝える' }] };
    return { line: '何かお話ですか？', opts: [{ k: 'praise', label: '褒める' }, { k: 'issue', label: '課題を伝える' }, { k: 'listen', label: '悩みを聞く' }] };
  };

  // ---------- ライバル監督：同じ部でいちばん強いクラブの監督。候補の取り合いと、直接対決の予告・卒業生の再会 ----------
  YA.rivalOf = function (w) {
    const ts = (w.league ? w.league.teams : []).filter((t) => !t.me);
    const best = ts.slice().sort((a, b) => b.lvl - a.lvl)[0];
    return best ? { coach: best.coach.name.replace(/ (監督|コーチ)$/, ''), club: best.name, id: best.id } : { coach: '？', club: '他のクラブ', id: null };
  };
  YA.rivalLabel = (w, c) => `${YA.rivalOf(w).coach}監督（${YA.rivalOf(w).club}）も注目`;
  // 15の手間（スカウト経費）で先に会いに行き、取り合いの不利を消す
  YA.rivalFight = function (w, id) {
    const c = w.scouting.cands.find((x) => x.id === id);
    const b = YA.budget(w);
    if (!c || !c.rival || c.rivalBeat) return { ok: false, msg: '対抗できません' };
    if (b.scout - w.club.spent.scout < 15) return { ok: false, msg: 'スカウトの配分が足りません' };
    w.club.spent.scout += 15;
    c.rivalBeat = true;
    return { ok: true, msg: `${YA.rivalOf(w).coach}監督より先に会いに行きました` };
  };
  // 毎年4週に、ライバルとの直接対決の節を知らせる。20週に卒業生が母校を訪ねる（再会）
  YA.rivalWeek = function (w) {
    const r = YA.rngOf(w.seed * 73 + w.year * 37 + w.week);
    if (w.week === 4 && w.league) {
      const rv = YA.rivalOf(w);
      const ks = [];
      w.league.rounds.forEach((rd, k) => { if (rd.some(([a, b]) => (a === 'me' && b === rv.id) || (b === 'me' && a === rv.id))) ks.push(k + 1); });
      if (ks.length) YA.noteTier(w, 2, `今年のライバルは${rv.club}の${rv.coach}監督。直接対決は第${ks.join('節と第')}節です`);
    }
    if (w.week === 20) {
      const c = w.alumni.filter((a) => a.status === 'pro' && !a.retired && a.ovr >= 11);
      if (c.length) {
        const a = r.pick(c);
        for (const p of Object.values(w.players)) if (p.grade === 1) p.conf = Math.min(100, p.conf + 4);
        YA.noteTier(w, 2, `卒業生の${a.name}（${a.club}）が母校を訪ね、後輩に話をしてくれた。高1の自信が少し上がった`);
      }
    }
  };

  // 足りなかった出来事：保護者の相談・選手同士のライバル意識
  YA.EVENTS.push({
    id: 'parent', name: '保護者の相談', weight: 0.6,
    pick: (w, r) => { const c = Object.values(w.players).filter((p) => p.team === 'B' && p.mins < 200 && p.grade >= 2); return c.length ? r.pick(c) : null; },
    text: (p) => `${p.num}番 ${p.name}の保護者から、「もう少し試合に出られないでしょうか」と連絡が来た。`,
    opts: [
      { label: '現状と課題を丁寧に説明する', kind: 'warm', extra: (w, p) => { p.unrest = Math.max(0, p.unrest - 0.5); } },
      { label: '起用を約束する', kind: 'push', extra: (w, p) => { p.train.promise = true; YA.addTrust && YA.addTrust(w, -1, '保護者に起用を約束した'); } },
      { label: '一律の方針だと断る', kind: 'firm', extra: (w, p) => { p.unrest += 1; w.disc = Math.min(100, (w.disc == null ? 60 : w.disc) + 1); } },
    ],
  });
  YA.EVENTS.push({
    id: 'rivalry', name: '同じ位置のライバル意識', weight: 0.6,
    pick: (w, r) => {
      const ps = Object.values(w.players).filter((p) => p.team === 'A' && p.grade <= 2);
      const pair = [];
      for (const p of ps) { const q = ps.find((x) => x.id !== p.id && x.pos === p.pos && Math.abs(YA.ovr(x) - YA.ovr(p)) < 0.5 && x.id > p.id); if (q) pair.push([p, q]); }
      if (!pair.length) return null;
      const [p, q] = r.pick(pair);
      p._rv = q.id;
      return p;
    },
    text: (p, w) => `${p.num}番 ${p.name}と${(w.players[p._rv] || {}).name || '同じ位置の仲間'}が、先発の座を争って火花を散らしている。`,
    opts: [
      { label: '競わせて伸ばす（全力でぶつかれ）', kind: 'push', extra: (w, p, r) => { const q = w.players[p._rv]; if (q) { p.conf = Math.min(100, p.conf + 3); q.conf = Math.min(100, q.conf + 3); if (r() < 0.25) { p.unrest += 1; q.unrest += 1; } } } },
      { label: '互いの良さを認め合わせる', kind: 'warm', extra: (w, p) => { const q = w.players[p._rv]; if (q) { p.unrest = Math.max(0, p.unrest - 0.5); q.unrest = Math.max(0, q.unrest - 0.5); } } },
      { label: '何も言わず見守る', kind: 'wait', extra: () => {} },
    ],
  });

  // ---------- Bチームの指揮（決定30）：布陣・戦い方・起用方針。試合は結果だけ自動で回る ----------
  YA.B_POLICY = [['best', '力の順'], ['young', '下級生を優先'], ['rest', '疲れの少ない順'], ['manual', '自分で決める']];
  YA.setBCtl = function (w, patch) {
    w.bCtl = Object.assign({ form: '4-3-3', tactic: null, policy: 'best' }, w.bCtl || {}, patch);
    if (!YA.FORMATIONS[w.bCtl.form]) w.bCtl.form = '4-3-3';
    const keep = w.bCtl.policy === 'manual' && !('form' in patch);
    if (!keep) w.bCtl.formKept = null;
    YA.pickLineup(w, 'B', w.bCtl.form); // Aの並びは触らない
    if (w.bCtl.policy === 'manual') w.bCtl.formKept = w.bCtl.form;
  };
  // Bの先発の枠 i と、Bの別の選手（先発の別の枠か控え）を入れ替える
  YA.swapB = function (w, slotI, pid) {
    const s = w.lineupB[slotI];
    if (!s || !w.players[pid] || w.players[pid].team !== 'B') return false;
    const j = w.lineupB.findIndex((x) => x.pid === pid);
    if (j >= 0) { const t = s.pid; s.pid = pid; w.lineupB[j].pid = t; YA.fixSlotRole(w.lineupB[j], j); } else {
      const k = (w.benchB || []).indexOf(pid);
      if (k >= 0) w.benchB[k] = s.pid; else w.benchB = (w.benchB || []).concat([s.pid]);
      s.pid = pid;
    }
    YA.fixSlotRole(s, slotI);
    w.bCtl = Object.assign({ form: '4-3-3', tactic: null, policy: 'manual' }, w.bCtl || {}, { policy: 'manual' });
    w.bCtl.formKept = w.bCtl.form;
    return true;
  };

  // ---------- クラブ名・相手クラブ名の書き換え（決定52・54）----------
  const okName = (t) => t && t.length <= 14;
  YA.renameClub = function (w, name) {
    const t = String(name || '').replace(/\s+/g, ' ').trim();
    if (!okName(t)) return { ok: false, msg: '1〜14文字で入れてください' };
    w.clubName = t;
    const me = w.league && w.league.teams.find((x) => x.me);
    if (me) me.name = t;
    return { ok: true };
  };
  // 相手は60クラブの固定名（w.rename に残るので、翌年以降も同じ名前で出る）
  YA.renameTeam = function (w, id, name) {
    const t = String(name || '').replace(/\s+/g, ' ').trim();
    const tm = w.league && w.league.teams.find((x) => x.id === id && !x.me);
    if (!tm || !okName(t)) return { ok: false, msg: '1〜14文字で入れてください' };
    tm.name = t;
    tm.short = t.length > 9 ? t.slice(0, 9) : t;
    if (tm.cid) (w.rename = w.rename || {})[tm.cid] = t;
    return { ok: true };
  };

  // ---------- 練習メニューの型（3つ保存・呼び出し）----------
  YA.saveMenuSlot = function (w, i) {
    (w.menuSlots = w.menuSlots || [null, null, null])[i] = JSON.parse(JSON.stringify(w.plan));
  };
  YA.loadMenuSlot = function (w, i) {
    const s = w.menuSlots && w.menuSlots[i];
    if (!s) return false;
    w.plan = JSON.parse(JSON.stringify(s));
    return true;
  };

  // ---------- 名前の書き換え（決定52・54）----------
  YA.renamePlayer = function (w, pid, name) {
    const p = w.players[pid];
    const t = String(name || '').replace(/\s+/g, ' ').trim();
    if (!p || !t || t.length > 14) return { ok: false, msg: '1〜14文字で入れてください' };
    p.name = t;
    return { ok: true };
  };
})();
