// 選手を構成する要素 段階1「土台」（2026-11-19〜20 の会話で決めたもの。記憶 youth-player-elements）
// ① 基本：身長の幅を 144〜206cm に広げ、年齢で伸びる。誕生日（早生まれ）・体重と体型・出身地（遠い子は寮）。
//    名前は書き換えられない（選手の「…」から外した。オリジナル選手は作るときに名付ける）
// ② 隠れた能力5つ（1〜20・数字は見せない。見抜く目なら見える）：安定感・大一番の強さ・怪我のしにくさ・適応力・プロ意識
// ③ 成長の型（早熟・ふつう・晩成。誕生日と結ぶ）・伸びやすさをコーチの言葉で・GK の伸びしろ（world.js の genPlayer で直した）
// 値は選手ごとの乱数（id と名前から）で決めるので、ゲームの乱数の流れは変えない。古い保存の子にも、開いたときに足す。
(function () {
  const YA = globalThis.YA;
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const all = (w) => Object.values(w.players || {});

  // ---------- 表 ----------
  YA.HID = ['安定感', '大一番の強さ', '怪我のしにくさ', '適応力', 'プロ意識'];
  // 高い子・低い子へのコーチの言葉（数字の代わり）
  YA.HID_WORDS = {
    安定感: ['毎試合、計算できる出来を見せる', '日によって出来が大きく変わる'],
    大一番の強さ: ['大きな試合ほど力を出せる', '大きな試合で固くなりやすい'],
    怪我のしにくさ: ['体が頑丈で、休まずに戦える', '怪我をしやすい体質'],
    適応力: ['新しい環境や役割にすぐ慣れる', '環境や役割が変わると時間がかかる'],
    プロ意識: ['食事や休み方まで自分を律している', '練習の外の過ごし方に甘さがある'],
  };
  YA.GT_NAME = { early: '早熟', normal: 'ふつう', late: '晩成' };
  // 学年ごとの伸びの倍率（成長の型）
  YA.GT_GROW = { early: [1.2, 1.0, 0.8], normal: [1, 1, 1], late: [0.82, 1.0, 1.18] };
  // 高1の初めから伸びる背の合計（cm）と、学年ごとの割合（晩成は卒業のあとにも残る）
  YA.GT_HEIGHT = { early: [1, 3, [0.7, 0.25, 0.05]], normal: [3, 7, [0.45, 0.35, 0.2]], late: [7, 15, [0.3, 0.3, 0.3]] };
  YA.H_MIN = 144;
  YA.H_MAX = 206;
  YA.BODY = { slim: ['細身', 19.2], normal: ['ふつう', 20.8], solid: ['がっしり', 22.8] };
  // 都道府県（地域は YA.REGIONS の番号：0 北海道・東北 1 関東 2 中部 3 関西 4 中国・四国 5 九州）
  YA.PREFS = [
    ['北海道', 0], ['青森', 0], ['岩手', 0], ['宮城', 0], ['秋田', 0], ['山形', 0], ['福島', 0],
    ['茨城', 1], ['栃木', 1], ['群馬', 1], ['埼玉', 1], ['千葉', 1], ['東京', 1], ['神奈川', 1],
    ['新潟', 2], ['富山', 2], ['石川', 2], ['福井', 2], ['山梨', 2], ['長野', 2], ['岐阜', 2], ['静岡', 2], ['愛知', 2],
    ['三重', 3], ['滋賀', 3], ['京都', 3], ['大阪', 3], ['兵庫', 3], ['奈良', 3], ['和歌山', 3],
    ['鳥取', 4], ['島根', 4], ['岡山', 4], ['広島', 4], ['山口', 4], ['徳島', 4], ['香川', 4], ['愛媛', 4], ['高知', 4],
    ['福岡', 5], ['佐賀', 5], ['長崎', 5], ['熊本', 5], ['大分', 5], ['宮崎', 5], ['鹿児島', 5], ['沖縄', 5],
  ];
  const PREF_W = { 東京: 3, 神奈川: 2.2, 埼玉: 2, 千葉: 1.8, 大阪: 2.4, 愛知: 2, 兵庫: 1.6, 福岡: 1.6, 北海道: 1.4, 静岡: 1.4 };
  const prefRegion = (n) => { const x = YA.PREFS.find((q) => q[0] === n); return x ? x[1] : -1; };
  YA.prefRegion = prefRegion;

  // ---------- 選手ごとの乱数 ----------
  const rngP = (p, salt) => YA.rngOf(YA.hash(String(p.id) + '|' + p.name + '|' + (salt || 'body')));
  const pers = (p, g, v) => p.pers && p.pers[g] === v;
  const norm = (r) => (r() + r() + r() + r() - 2) * 1.7; // だいたい標準正規

  // 誕生日（学年の中の月日。4/2〜翌4/1）。早生まれ＝1/1〜4/1
  YA.isEarlyBorn = (p) => !!p.bday && (p.bday.m <= 3 || (p.bday.m === 4 && p.bday.d === 1));
  function initBirth(p, r) {
    const days = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    // 4/2 から 365 日のどこか（同じ学年の中で月ごとに少し偏る：4〜6月生まれがやや多い）
    let k = Math.floor(r() * 365);
    if (r() < 0.12) k = Math.floor(r() * 91); // 4〜6月
    let m = 4;
    let d = 2 + k;
    while (d > days[m - 1]) { d -= days[m - 1]; m = m % 12 + 1; }
    p.bday = { m, d };
  }
  function initType(p, r) {
    const eb = YA.isEarlyBorn(p);
    const spring = p.bday.m >= 4 && p.bday.m <= 6;
    const [e, n] = eb ? [0.15, 0.4] : spring ? [0.35, 0.5] : [0.25, 0.55];
    const x = r();
    p.gt = x < e ? 'early' : x < e + n ? 'normal' : 'late';
  }
  // 背：大人になったときの背（hFin）を先に決め、いまの背は残りの伸びを引いたもの
  function heightLeft(p) {
    const t = YA.GT_HEIGHT[p.gt] || YA.GT_HEIGHT.normal;
    const sh = t[2];
    const g = clamp(p.grade || 1, 1, 3);
    let share = 0;
    for (let i = g - 1; i < 3; i++) share += sh[i];
    return { total: p.hTot, share };
  }
  function initHeight(p, r, fresh) {
    const t = YA.GT_HEIGHT[p.gt];
    p.hTot = Math.round((t[0] + r() * (t[1] - t[0])) * 10) / 10;
    if (fresh) {
      const mean = 176 + (p.pos === 'GK' ? 6 : p.main === 'CB' ? 4 : p.main === 'ST' ? 1 : /^(LW|RW|AM|SS)$/.test(p.main || '') ? -2 : 0);
      // 幅を上下20cm広げた（前は 164〜191）。ほとんどは 165〜188、まれに 150cm台・200cm超え
      const fin = clamp(Math.round(mean + norm(r) * 6.5 + (r() < 0.04 ? (r() < 0.5 ? -1 : 1) * (8 + r() * 10) : 0)), YA.H_MIN + 6, YA.H_MAX);
      const { share } = heightLeft(p);
      p.height = clamp(Math.round(fin - p.hTot * share), YA.H_MIN, YA.H_MAX);
      p.hFin = fin;
    } else {
      // 古い保存の子は、いまの背を変えずに、これから伸びる分を足す
      const { share } = heightLeft(p);
      p.hFin = clamp(Math.round(p.height + p.hTot * share), p.height, YA.H_MAX);
    }
    p.hAcc = 0;
  }
  function initBody(p, r) {
    const ab = (n) => (p.ab && p.ab[n]) || 10;
    const s = ab('強さ') - (ab('スピード') + ab('敏しょう性')) / 2 + norm(r) * 1.6;
    p.body = s > 2.2 ? 'solid' : s < -2.2 ? 'slim' : 'normal';
    p.bmi = Math.round((YA.BODY[p.body][1] + norm(r) * 0.5) * 10) / 10;
  }
  YA.weightOf = function (p) {
    if (!p.height) return null;
    const b = p.bmi || 20.8;
    return Math.round(b * Math.pow(p.height / 100, 2) + (((p.ab && p.ab['強さ']) || 10) - 10) * 0.35 + ((p.grade || 1) - 1) * 0.8);
  };
  // 隠れた能力：性格が傾きを決める
  function initHid(p, r) {
    const base = () => clamp(Math.round(10 + norm(r) * 3.2), 1, 20);
    const h = {};
    for (const k of YA.HID) h[k] = base();
    const add = (k, v) => { h[k] = clamp(h[k] + v, 1, 20); };
    if (pers(p, '感情の波', '安定型')) add('安定感', 4);
    if (pers(p, '感情の波', '気分屋')) add('安定感', -4);
    if (pers(p, '感情の波', '短気')) add('安定感', -2);
    if (pers(p, '大舞台', '大舞台に強い')) add('大一番の強さ', 5);
    if (pers(p, '大舞台', '目立ちたがり')) add('大一番の強さ', 2);
    if (pers(p, '大舞台', 'プレッシャーに弱い')) add('大一番の強さ', -5);
    if (pers(p, '大舞台', '慎重')) add('大一番の強さ', -1);
    if (pers(p, '気持ちの強さ', '繊細')) add('大一番の強さ', -2);
    if (p.body === 'solid') add('怪我のしにくさ', 2);
    if (p.body === 'slim') add('怪我のしにくさ', -1);
    if (pers(p, '人との関わり', 'お調子者') || pers(p, '人との関わり', '世話好き')) add('適応力', 2);
    if (pers(p, '人との関わり', '人見知り')) add('適応力', -3);
    if (pers(p, '人との関わり', '一匹狼')) add('適応力', -1);
    if (pers(p, '教えの受け止め方', '素直')) add('適応力', 2);
    if (pers(p, '教えの受け止め方', '頑固')) add('適応力', -2);
    if (pers(p, '練習への向き合い', '真面目')) add('プロ意識', 4);
    if (pers(p, '練習への向き合い', '勉強家')) add('プロ意識', 3);
    if (pers(p, '練習への向き合い', '練習嫌い')) add('プロ意識', -5);
    if (pers(p, '目指すもの', '野心家')) add('プロ意識', 2);
    p.hid = h;
  }
  function initPlace(w, p, r) {
    const my = YA.regionOf ? YA.regionOf(w.clubName) : 1;
    const x = r();
    // 6割は同じ地域、2割5分は隣の地域、残りは全国から
    const want = x < 0.6 ? (q) => q[1] === my : x < 0.85 ? (q) => Math.abs(q[1] - my) === 1 : () => true;
    let pool = YA.PREFS.filter(want);
    if (!pool.length) pool = YA.PREFS;
    p.born = r.weighted(pool, (q) => PREF_W[q[0]] || 1)[0];
    // 外国籍の子は出身地を国にする
    if (p.nation && p.nation !== '日本') p.born = p.nation;
    // 遠い子（地域が2つ以上離れている・外国籍）は寮へ
    const rg = prefRegion(p.born);
    if (rg < 0 || Math.abs(rg - my) >= 2) p.dorm = true;
    p.far = rg < 0 || Math.abs(rg - my) >= 2;
  }

  // 生まれたときに決まるもの（w が無くてもよいもの）
  YA.bodyInit = function (p, fresh) {
    if (p.bd) return p;
    const r = rngP(p);
    initBirth(p, r);
    initType(p, r);
    initHeight(p, r, fresh);
    initBody(p, r);
    initHid(p, r);
    p.bd = 1;
    return p;
  };
  // 古い保存の子・出身地の無い子に足す
  YA.ensureBody = function (w) {
    if (!w || !w.players) return;
    for (const p of all(w)) {
      if (!p.bd) YA.bodyInit(p, false);
      if (!p.born) initPlace(w, p, rngP(p, 'place'));
      // GK の伸びしろを同じ物差しへ（2026-11-20 より前に入った GK）
      if (!p.potFix) {
        if (p.pos === 'GK') {
          const k = YA.AB_GK.length / YA.AB_FIELD.length;
          const s = YA.abSum(p);
          p.pot = Math.round(s + Math.max(0, p.pot - s) * k);
        }
        p.potFix = 1;
      }
    }
  };

  const gp0 = YA.genPlayer;
  YA.genPlayer = function () {
    const p = gp0.apply(this, arguments);
    YA.bodyInit(p, true);
    return p;
  };
  const nw0 = YA.newWorld;
  YA.newWorld = function () {
    const w = nw0.apply(this, arguments);
    YA.ensureBody(w);
    return w;
  };

  // ---------- 年齢 ----------
  // 4月に高1は15歳。誕生日が来ると16歳（早生まれは1〜3月）
  const MONTH_OF_WEEK = (week) => { const m = YA.calendar ? YA.calendar(week).month : '4月'; return parseInt(m, 10) || 4; };
  YA.ageOf = function (w, p) {
    const g = p.grade || 1;
    if (!p.bday) return 15 + g;
    const mNow = MONTH_OF_WEEK(w ? w.week : 1);
    const ord = (m) => (m + 8) % 12; // 4月=0 … 3月=11
    const passed = ord(mNow) > ord(p.bday.m) || (ord(mNow) === ord(p.bday.m) && 15 >= p.bday.d);
    return 14 + g + (passed ? 1 : 0);
  };
  YA.bdayText = (p) => (p.bday ? `${p.bday.m}月${p.bday.d}日生まれ` : '');

  // ---------- 効き目 ----------
  // 伸び：成長の型（学年ごと）×プロ意識
  YA.growK = function (p) {
    const g = clamp(p.grade || 1, 1, 3);
    const t = (YA.GT_GROW[p.gt] || YA.GT_GROW.normal)[g - 1];
    const pro = p.hid ? 0.94 + ((p.hid['プロ意識'] || 10) - 1) * (0.12 / 19) : 1;
    return t * pro;
  };
  // 怪我のおそれ：怪我のしにくさ 1 で 1.35倍、20 で 0.65倍
  YA.injK = function (p) {
    if (!p.hid) return 1;
    return 1.35 - ((p.hid['怪我のしにくさ'] || 10) - 1) * (0.7 / 19);
  };
  // 慣れる速さ：適応力 1 で 0.7倍、20 で 1.35倍（外国籍の適応・位置の転向）
  YA.adaptK = function (p) {
    if (!p.hid) return 1;
    return 0.7 + ((p.hid['適応力'] || 10) - 1) * (0.65 / 19);
  };
  // 大一番：試合の終盤の競った場面と、大会の決勝・プレーオフ（engine の persMod から呼ぶ）
  YA.bigGameMod = function (p, close, big) {
    if (!p.hid || !(close || big)) return 0;
    return ((p.hid['大一番の強さ'] || 10) - 10) * (big ? 0.16 : 0.1);
  };
  // 大一番＝夏の大会の決勝（15週）・冬の大会の準決勝と決勝（29・30週）・プレーオフ（31週）
  YA.isBigWeek = function (week) {
    const s = YA.SCHED ? YA.SCHED(week) : null;
    return !!s && s.t === 'cup' && ((s.cup === 'summer' && s.round === 3) || (s.cup === 'winter' && s.round >= 3) || s.cup === 'post');
  };
  const tf0 = YA.teamFromWorld;
  YA.teamFromWorld = function (w, which) {
    const t = tf0.apply(this, arguments);
    if (which === 'A' && YA.isBigWeek(w.week)) t.big = true;
    return t;
  };
  // 安定感：試合のあとの自信の上下を、安定感が高いほど小さく（低いほど大きく）
  const am0 = YA.applyMatch;
  YA.applyMatch = function (w, m, which) {
    const before = {};
    for (const p of all(w)) before[p.id] = p.conf;
    const r = am0.apply(this, arguments);
    for (const p of all(w)) {
      if (!p.hid || before[p.id] == null || p.conf === before[p.id]) continue;
      const k = 1.3 - ((p.hid['安定感'] || 10) - 1) * (0.6 / 19); // 1.3〜0.7
      p.conf = clamp(before[p.id] + (p.conf - before[p.id]) * k, 0, 100);
    }
    return r;
  };

  // ---------- 毎週：背が伸びる ----------
  const ew0 = YA.endWeek;
  YA.endWeek = function (w) {
    YA.ensureBody(w);
    const res = ew0.apply(this, arguments);
    YA.ensureBody(w); // 年度末の入団で入った子にも、その週のうちに出身地を（2026-11-20：次の週まで空いていた）
    for (const p of all(w)) {
      if (!p.gt || p.height >= (p.hFin || 0)) continue;
      const sh = (YA.GT_HEIGHT[p.gt] || YA.GT_HEIGHT.normal)[2][clamp(p.grade || 1, 1, 3) - 1];
      p.hAcc = (p.hAcc || 0) + (p.hTot * sh) / (YA.WEEKS || 40);
      while (p.hAcc >= 1 && p.height < p.hFin) { p.height += 1; p.hAcc -= 1; }
    }
    return res;
  };
  // 成長期で背が伸びたら、行き着く背も少し上へ
  const st0 = YA.startWeek;
  YA.startWeek = function (w) {
    YA.ensureBody(w);
    const res = st0.apply(this, arguments);
    for (const p of all(w)) if (p.hFin && p.height > p.hFin) p.hFin = Math.min(YA.H_MAX, p.height);
    return res;
  };

  // ---------- 卒業生へ引き継ぐ ----------
  const ae0 = YA.alumniEntry;
  YA.alumniEntry = function (w, p) {
    const a = ae0.apply(this, arguments);
    if (p.height) a.height = p.height;
    if (p.born) a.born = p.born;
    if (p.bday) a.bday = p.bday;
    if (p.gt) a.gt = p.gt;
    if (p.hid) a.hid = Object.assign({}, p.hid);
    // 晩成の子は、卒業してからも伸びる（大学の遅咲きと同じ扱い）
    if (p.gt === 'late' && a.status !== 'left') a.late = true;
    return a;
  };
  // 早熟の子は、卒業してからの伸びが鈍い
  const at0 = YA.alumniTick;
  YA.alumniTick = function (w) {
    const res = at0.apply(this, arguments);
    for (const a of w.alumni || []) if (a.gt === 'early' && !a.retired && a.age != null && a.age <= 23 && a.status === 'pro') a.ovr = Math.round((a.ovr - 0.12) * 10) / 10;
    return res;
  };

  // ---------- 言葉 ----------
  // 隠れた能力を、コーチの言葉で（目立つものだけ。見抜く目なら数字も）
  YA.hidWords = function (w, p) {
    if (!p.hid) return [];
    const out = [];
    for (const k of YA.HID) {
      const v = p.hid[k];
      if (v >= 15) out.push({ k, v, good: true, t: YA.HID_WORDS[k][0] });
      else if (v <= 6) out.push({ k, v, good: false, t: YA.HID_WORDS[k][1] });
    }
    return out;
  };
  // 伸び方の言葉：成長の型と伸びる速さ（p.rate）
  YA.growWords = function (w, p) {
    const t = [];
    const g = p.grade || 1;
    if (p.gt === 'early') t.push(g === 1 ? '体ができるのが早く、いまが伸び盛り' : g === 2 ? '早くから体ができていて、伸びは落ち着いてきた' : '伸びのピークはもう過ぎたかもしれない');
    else if (p.gt === 'late') t.push(g === 1 ? '体ができるのはこれから。伸びるのは先になりそう' : g === 2 ? '少しずつ体ができてきた' : 'いまになって伸びてきた。卒業してからも伸びそう');
    if (p.rate >= 1.15) t.push('教えたことの飲み込みが早い');
    else if (p.rate <= 0.88) t.push('身につくまでに時間がかかる');
    return t;
  };

  // 概要のプロフィールと見立てに足す
  const ov0 = YA.playerOverview;
  if (ov0) {
    YA.playerOverview = function (w, p) {
      YA.ensureBody(w);
      const el = ov0.apply(this, arguments);
      try {
        const doc = el.ownerDocument;
        const eye = !!(YA.ent && YA.ent.eye);
        // プロフィール：学年の行に年齢と誕生日、身長の行に体重と体型、出身地
        const rows = el.querySelectorAll('.ovrow');
        const mk = (k, v) => { const r = doc.createElement('div'); r.className = 'ovrow'; const a = doc.createElement('span'); a.className = 'k'; a.textContent = k; const b = doc.createElement('span'); b.className = 'v'; b.textContent = v; r.append(a, b); return r; };
        for (const r of rows) {
          const k = r.querySelector('.k');
          const v = r.querySelector('.v');
          if (!k || !v) continue;
          if (k.textContent === '学年') v.textContent = `高${p.grade}（${YA.ageOf(w, p)}歳）・${p.team}チーム`;
          if (k.textContent === '利き足') {
            const foot = v.textContent.split('・')[0];
            v.textContent = foot;
            r.after(mk('体格', `${p.height}cm・${YA.weightOf(p)}kg・${(YA.BODY[p.body] || YA.BODY.normal)[0]}`));
            r.after(mk('誕生日', YA.bdayText(p) + (YA.isEarlyBorn(p) ? '（早生まれ）' : '')));
            if (p.born) r.after(mk('出身', p.born + (p.dorm !== false ? '・寮生' : '・自宅から')));
          }
        }
        // 見立て：伸び方と隠れた能力の言葉
        const rep = el.querySelector('.ovtext');
        const gw = YA.growWords(w, p);
        const hw = YA.hidWords(w, p);
        if (rep && (gw.length || hw.length)) {
          const box = doc.createElement('div');
          box.className = 'ovhid';
          box.style.cssText = 'display:flex;flex-wrap:wrap;gap:3px 6px;margin-top:3px';
          for (const t of gw) { const s = doc.createElement('span'); s.className = 'chip'; s.textContent = t; box.append(s); }
          for (const x of hw) { const s = doc.createElement('span'); s.className = 'chip ' + (x.good ? 'trait' : x.mid ? 'gray' : 'bad'); s.textContent = (x.good ? '＋' : x.mid ? '・' : '－') + x.t + (eye ? `（${x.k} ${x.v}）` : ''); box.append(s); }
          rep.after(box);
        }
        // 見抜く目：隠れた能力5つと成長の型を数字で
        if (eye && p.hid) {
          const sec = doc.createElement('div');
          sec.className = 'ovsec ovhidsec';
          const hd = doc.createElement('div');
          hd.className = 'ovh';
          hd.textContent = '隠れた力（見抜く目）';
          const line = doc.createElement('div');
          line.className = 'ovtext';
          line.textContent = YA.HID.map((k) => `${k} ${p.hid[k]}`).join('・') + `／成長の型：${YA.GT_NAME[p.gt] || 'ふつう'}`;
          sec.append(hd, line);
          const col = el.querySelector('.ovcol');
          if (col) col.append(sec);
        }
      } catch (e) { /* 形の違う画面 */ }
      return el;
    };
  }
})();
