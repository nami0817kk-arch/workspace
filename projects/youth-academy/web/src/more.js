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

  // ---------- 名前の書き換え（決定52・54）----------
  YA.renamePlayer = function (w, pid, name) {
    const p = w.players[pid];
    const t = String(name || '').replace(/\s+/g, ' ').trim();
    if (!p || !t || t.length > 14) return { ok: false, msg: '1〜14文字で入れてください' };
    p.name = t;
    return { ok: true };
  };
})();
