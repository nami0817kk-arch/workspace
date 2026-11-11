// 1段目「芯」（決定85・101〜110・113）：★注目の上限、覚醒の鍵とヒント、覚醒の形と特性、★の子ごとの信頼5段階、節目の会話。
// 覚醒は★の子だけが、隠れた鍵2〜3個を満たして起こす（年1〜2人の運任せはやめた）。見せ方に依存しない。
(function () {
  'use strict';
  const YA = (globalThis.YA = globalThis.YA || {});
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const first = (p) => p.name.split(' ')[1] || p.name;
  const fam = (p) => p.name.split(' ')[0];
  const ST = (p, g, v) => p.pers && p.pers[g] === v;
  const abs = (w) => w.year * 100 + w.week;

  // ---------- ★注目（決定85）：各学年4人まで、いつでも付け替えられる ----------
  YA.STAR_MAX = 4;
  YA.starsIn = (w, grade) => Object.values(w.players).filter((p) => p.star && p.grade === grade);
  YA.setStar = function (w, p, on) {
    if (!on) {
      p.star = false;
      return { ok: true, msg: `${p.name}の★を外しました（鍵の進み具合と信頼は残ります）` };
    }
    if (p.star) return { ok: true, msg: '' };
    if (YA.starsIn(w, p.grade).length >= YA.STAR_MAX) return { ok: false, msg: `★は各学年${YA.STAR_MAX}人までです。高${p.grade}のだれかの★を外してください` };
    p.star = true;
    YA.keysOf(w, p);
    if (p.tr == null) p.tr = 50;
    if (!p.ms || !p.ms.star) milestone(w, p, 'star');
    return { ok: true, msg: `${p.name}に★を付けました。面談や試合で、覚醒の鍵のヒントが少しずつ見えてきます` };
  };
  // おまかせ進行・最初の4週の勧め：伸びしろの星が高い子から、空いている枠に★を付ける
  YA.starPick = (w, grade) => Object.values(w.players).filter((p) => p.grade === grade && !p.star && !(p.aw && !(p.keys || []).length)).sort((a, b) => YA.coachStars(w, b) - YA.coachStars(w, a) || (b.fast ? 1 : 0) - (a.fast ? 1 : 0) || YA.rating(b) - YA.rating(a));
  YA.autoStars = function (w) {
    for (const g of [1, 2, 3]) {
      let n = YA.starsIn(w, g).length;
      for (const p of YA.starPick(w, g)) {
        if (n >= YA.STAR_MAX) break;
        p.star = true;
        YA.keysOf(w, p);
        if (p.tr == null) p.tr = 50;
        if (!p.ms) p.ms = { star: abs(w) };
        n++;
      }
    }
  };

  // ---------- 伸びしろの星と幅（決定91）----------
  // 一覧：コーチの見立ての星1〜5。見る目が低いと1つ外れることがある（同じ子・同じ年なら同じ外れ方）
  YA.coachStars = function (w, p) {
    const s = YA.potStars(p);
    const eye = w && w.coach ? w.coach.eye : 10;
    const r = YA.rngOf((w ? w.seed | 0 : 0) * 11 + YA.hash(p.id) + (w ? w.year : 0) * 97);
    const miss = clamp(0.42 - eye * 0.018 - (p.grade - 1) * 0.08 - (p.star ? 0.1 : 0), 0.03, 0.5);
    return clamp(s + (r.chance(miss) ? (r.chance(0.5) ? 1 : -1) : 0), 1, 5);
  };
  // 詳細：将来の総合力の幅と水準名。見る目・学年・★で見た長さ（careOf）で狭まる。見抜く目（課金）は w.sharpEye
  YA.futureRange = function (w, p) {
    const list = p.pos === 'GK' ? YA.AB_GK : YA.AB_FIELD;
    const room = Math.max(0, p.pot - YA.abSum(p)) / list.length;
    const mid = YA.rate(Math.min(20, YA.ovr(p) + room * 0.75));
    const eye = w && w.coach ? w.coach.eye : 10;
    const care = w && YA.careOf ? Math.min(30, YA.careOf(w, p)) : 0;
    let half = (34 - (p.grade - 1) * 10) * (1.25 - eye * 0.025) * (1 - care / 60) * (w && w.sharpEye ? 0.55 : 1);
    half = Math.max(4, Math.round(half));
    // 見え方は真ん中から少しずれる（見る目が低いほど）
    const off = Math.round((YA.rngOf((w ? w.seed | 0 : 0) + YA.hash(p.id) * 5)() - 0.5) * half * (1.1 - eye * 0.04));
    const lo = Math.max(YA.rating(p), mid - half + off);
    const hi = Math.max(lo + 2, mid + half + off);
    const nm = (v) => YA.levelOf(v).replace(/（.*）/, '');
    return { lo, hi, text: `将来 ${lo}〜${hi}（${nm(lo) === nm(hi) ? nm(lo) : nm(lo) + '〜' + nm(hi)}）` };
  };

  // ---------- 練習の伸びの見せ方（決定90）：★の子は「パス 11→12」、ほかは矢印。コーチの一言を添える ----------
  const train0 = YA.runTraining;
  YA.runTraining = function (w) {
    const gains = train0(w);
    const star = [];
    const others = [];
    for (const p of Object.values(w.players)) {
      const g = Object.entries(p.gain || {}).filter(([, v]) => v > 0);
      if (!g.length) continue;
      if (p.star) star.push({ id: p.id, items: g.map(([a, v]) => [a, p.ab[a] - v, p.ab[a]]) });
      else others.push({ id: p.id, n: g.reduce((s, [, v]) => s + v, 0), abs: g.map(([a]) => a) });
    }
    others.sort((a, b) => b.n - a.n);
    // コーチの一言：いちばん伸びた子（★を優先）の、いちばん伸びた能力
    const pickC = star.length ? star.map((x) => ({ id: x.id, a: x.items[0][0], n: x.items.length })).sort((a, b) => b.n - a.n)[0] : others[0] && { id: others[0].id, a: others[0].abs[0], n: others[0].n };
    let coach = '';
    if (pickC && w.players[pickC.id]) {
      const p = w.players[pickC.id];
      const L = [`${fam(p)}の${pickC.a}が良くなってきました`, `${fam(p)}、${pickC.a}で一皮むけそうです`, `今週は${fam(p)}の${pickC.a}が目立っていました`];
      coach = L[(w.week + YA.hash(p.id)) % L.length];
    }
    w.growth = { y: w.year, w: w.week, star, others: others.slice(0, 8), more: Math.max(0, others.length - 8), coach };
    return gains;
  };

  // ---------- 試合のあとの数字（決定89）：要点の数字・効いた戦術の一言・選手ごとの主な数字・攻めた方向 ----------
  // 試合の中身は見どころの場面だけなので、合間のパスやタックルは出場時間・能力・流れから見積もる（同じ試合なら同じ数）
  YA.matchNumbers = function (m) {
    const hs = typeof m.homeShare === 'function' ? m.homeShare() : 0.5;
    const mine = m.scenes.filter((sc) => sc.side === 'home');
    const theirs = m.scenes.filter((sc) => sc.side === 'away');
    const poss = clamp(Math.round(100 * (0.65 * hs + 0.35 * (mine.length / Math.max(1, m.scenes.length)))), 25, 75);
    const pg = (id) => (m.home.players[id] ? m.home.players[id].pos : null);
    const won = theirs.filter((sc) => ['dispossessed', 'intercepted'].includes(sc.outcome) && (sc.defs || []).some((d) => pg(d) === 'MF' || pg(d) === 'FW')).length + mine.filter((sc) => sc.type === 'steal').length;
    // 攻めた方向：自分の見どころの最初のボールの横の位置（0〜68m）
    const dir = { 左: 0, 中央: 0, 右: 0 };
    for (const sc of mine) {
      const fs = (sc.frames || []).filter((f) => f.ball);
      if (!fs.length) continue;
      const x0 = fs.reduce((t, f) => t + f.ball[0], 0) / fs.length;
      const x = sc.flip ? 68 - x0 : x0;
      dir[x < 23 ? '左' : x > 45 ? '右' : '中央']++;
    }
    const nd = Math.max(1, dir.左 + dir.中央 + dir.右);
    const dirPct = { 左: Math.round((dir.左 / nd) * 100), 中央: Math.round((dir.中央 / nd) * 100), 右: Math.round((dir.右 / nd) * 100) };
    const players = [];
    for (const p of Object.values(m.home.players)) {
      const st = p.st || {};
      if (!(st.minutes > 0)) continue;
      const r = YA.rngOf(m.scenes.length * 131 + YA.hash(p.id) * 17 + m.score.home * 7 + m.score.away);
      const k = st.minutes / 90;
      const ab = (n) => (p.ab && p.ab[n] != null ? p.ab[n] : 10);
      const base = { GK: 22, DF: 42, MF: 52, FW: 24 }[p.pos] || 35;
      const passes = Math.round(k * base * (0.6 + hs * 0.8) * (0.85 + r() * 0.3));
      const pct = clamp(Math.round(58 + ((ab('パス') + ab('視野') + ab('判断')) / 3) * 1.6 + (hs - 0.5) * 18 + (r() - 0.5) * 8), 50, 96);
      const tw = theirs.filter((sc) => (sc.defs || []).includes(p.id) && ['dispossessed', 'intercepted', 'stopped', 'blocked', 'cleared'].includes(sc.outcome)).length;
      const tk = p.pos === 'GK' ? 0 : Math.round(k * ({ DF: 3, MF: 2.4, FW: 0.9 }[p.pos] || 1.5) * (1.4 - hs) * (ab('タックル') / 11) * (0.7 + r() * 0.6)) + (tw ? 1 : 0);
      const steal = p.pos === 'GK' ? 0 : Math.round(k * ({ DF: 2.6, MF: 2.2, FW: 0.8 }[p.pos] || 1.5) * (1.4 - hs) * (ab('予測') / 11) * (0.7 + r() * 0.6)) + tw;
      players.push({ id: p.id, num: p.num, name: p.name, pos: p.pos, mins: st.minutes, rating: st.rating, passes, pct, shots: st.shots || 0, goals: st.goals || 0, tackles: tk, steals: steal, saves: st.saves || 0 });
    }
    players.sort((a, b) => b.rating - a.rating);
    // 効いた戦術の一言（決定114）
    const type = (m.home.tactic && m.home.tactic.type) || '戦い方';
    const good = mine.filter((sc) => sc.goal || sc.outcome === 'saved').length;
    const topDir = Object.entries(dirPct).sort((a, b) => b[1] - a[1])[0];
    const sh = m.stats.home;
    let tactic;
    if (good >= 3 && topDir[1] >= 45) tactic = `「${type}」がはまった。${topDir[0]}から崩す形が${dir[topDir[0]]}回できた`;
    else if (won >= 4) tactic = `「${type}」で前から奪えた。相手陣で${won}回ボールを取った`;
    else if (poss <= 40 && m.score.home >= m.score.away) tactic = `ボールは持たれたが、「${type}」で耐えて勝ち点を取った`;
    else if (sh.shots <= 3) tactic = `「${type}」では崩しきれなかった。シュートは${sh.shots}本だけ`;
    else tactic = `「${type}」は五分。${topDir[0]}からの攻めが多かった（${topDir[1]}%）`;
    return { poss, shots: sh.shots, onTarget: sh.onTarget, oppShots: m.stats.away.shots, won, dir: dirPct, players, tactic };
  };

  // ---------- 練習の1枚（決定143）：チームの重点1つ・この週の見込み ----------
  YA.TEAM_FOCUS = {
    攻撃の形: ['オフザボール', 'パス', 'ファーストタッチ'],
    守備の連係: ['ポジショニング', 'マーク', 'チームワーク'],
    セットプレー: ['プレースキック', 'ヘディング', 'ジャンプ'],
    走り込み: ['スタミナ', '運動量', '加速'],
    '1対1': ['ドリブル', 'タックル', '敏しょう性'],
    判断: ['判断', '予測', '視野'],
  };
  YA.weekOutlook = function (w) {
    const days = (w.plan && w.plan.days) || [];
    const k = { light: 0.65, normal: 1, hard: 1.3 };
    const tr = days.filter((d) => YA.MENUS[d.menu] && YA.MENUS[d.menu].fat > 0);
    const g = tr.reduce((s, d) => s + (k[d.int] || 1), 0);
    const f = tr.reduce((s, d) => s + YA.MENUS[d.menu].fat * (k[d.int] || 1), 0);
    const rest = Object.values(w.players).filter((p) => p.rest === 'rest').length;
    const growth = g >= 5.5 ? '多い' : g >= 4 ? 'ふつう' : '少なめ';
    const fatigue = f >= 34 ? '高い' : f >= 22 ? 'ふつう' : '低い';
    const tired = Object.values(w.players).filter((p) => p.inj <= 0 && p.fat >= 70 && p.rest !== 'rest');
    const wall = Object.values(w.players).filter((p) => p.state && p.state.k === 'wall' && p.state.w > 0);
    const tip = tired.length >= 2 ? `疲れ70以上が${tired.length}人。休ませると怪我が減る` : fatigue === '高い' ? 'きつい週。怪我のおそれが上がる（きつい日は約2倍）' : wall.length ? `${wall[0].name.split(' ')[0]}が壁に当たっている。面談や重点の見直しを` : rest ? `休み${rest}人で疲れが抜ける` : '先週の組み方のままでよさそうだ';
    return { growth, fatigue, tip };
  };

  // ---------- 教え方（決定128）----------
  YA.INTRO = [
    ['ユースの指導者になった', '高1〜高3の36人を預かり、3年かけて育てて送り出します。勝つことと、育てること。その両方を任されています。'],
    ['★注目の子を選ぶ', '★は各学年4人まで。★の子だけが「覚醒の鍵」を持っています。面談や試合で鍵のヒントを見つけ、満たすと覚醒します。'],
    ['毎週やること', '練習の画面を確かめて「この週で行く」。試合の週は布陣と戦い方を決めてキックオフ。出来事が起きたら、言葉をかけて選びます。'],
    ['系譜を伸ばす', '卒業した子がプロや代表で活躍すると、あなたの系譜が伸びます。大きな移籍では連帯貢献金も入ります。'],
  ];
  // 画面を初めて開いたときだけ、アシスタントコーチが1〜2行で教える。二度目からは出ない
  YA.COACH_TIPS = {
    home: '左が今週やることです。困ったら右の「今週気にかけたい子」から見てください。',
    players: '★を付けた子は、詳しい画面に覚醒の鍵が出ます。最初は「？」ですが、面談で少しずつ見えてきます。',
    train: '7マスを押すとメニューが替わります。疲れの高い子は右下で休ませられます。決まったら「この週で行く」。',
    match: '試合の前は相手の分析を見てから、並びと戦い方を。試合中は「止める」で交代と指示ができます。',
    club: '予算・スタッフ・スカウトなど、クラブのことはここです。最初はクラブとコーチが決めてくれます。',
    more: '卒業生の名鑑と記録はここです。育てた子のその後を追えます。',
  };
  YA.coachTip = function (w, tab) {
    if (!w || !YA.COACH_TIPS[tab]) return null;
    w.coachSeen = w.coachSeen || {};
    if (w.coachSeen[tab]) return null;
    let t = YA.COACH_TIPS[tab];
    if (tab === 'players') { const r = YA.starRecommend(w); if (r) t += ' ' + r; }
    return t;
  };
  // 最初の4週：鍵の短い子（見た目では分からない）に★を勧める
  YA.starRecommend = function (w) {
    if (!w || w.year > 1 || w.week > 4) return null;
    const p = Object.values(w.players).find((q) => q.fast && !q.star);
    if (!p) return null;
    return `高${p.grade}の${p.name}は、何かきっかけがあれば早く化けそうです。★を付けてみては。`;
  };

  // ---------- 信頼（決定110）：★の子ごとに5段階 ----------
  YA.TRUST_NAME = ['', '心を閉ざす', 'よそよそしい', 'ふつう', '信じている', '深く信頼'];
  YA.trustLv = (p) => 1 + Math.min(4, Math.floor(clamp(p.tr == null ? 50 : p.tr, 0, 100) / 20));
  YA.addTr = function (w, p, d, why) {
    if (!p) return;
    const lv0 = YA.trustLv(p);
    p.tr = clamp((p.tr == null ? 50 : p.tr) + d, 0, 100);
    const lv1 = YA.trustLv(p);
    if (lv1 !== lv0 && p.star) YA.noteTier(w, 2, `${p.num}番 ${p.name}の信頼が「${YA.TRUST_NAME[lv1]}」（${lv1}/5）に${lv1 > lv0 ? '上がった' : '下がった'}${why ? '（' + why + '）' : ''}`, p.id);
  };

  // ---------- 覚醒の鍵（決定102・106・107）----------
  // sys は5つの系統（試合・育て方・人・心・外）。need は回数、due は期限（通しの年×100＋週）。h はヒントの段（0＝？／1＝ぼんやり／2＝はっきり）
  const GROUP = (p) => p.pos;
  const KEYS = {
    bigGoal: { sys: '試合', ok: (p) => GROUP(p) === 'FW' || GROUP(p) === 'MF', need: 1, vague: '大舞台で何かをつかみそうだ', clear: (k) => '大会（夏・冬）の試合で得点する', due: 'g2' },
    bigClean: { sys: '試合', ok: (p) => GROUP(p) === 'GK' || GROUP(p) === 'DF', need: 1, vague: '大舞台で守り切ることが、きっかけになりそうだ', clear: () => '大会（夏・冬）の試合で、出場して無失点に抑える', due: 'g2' },
    goals: { sys: '試合', ok: (p) => GROUP(p) === 'FW' || p.main === 'AM' || p.main === 'SS', need: 5, vague: 'ゴールを重ねるほど、何かが変わりそうだ', clear: (k) => `Aの試合で${k.need}点取る` },
    clean: { sys: '試合', ok: (p) => GROUP(p) === 'GK' || GROUP(p) === 'DF', need: 4, vague: '失点しない試合を重ねると、自信になりそうだ', clear: (k) => `Aの試合に出て、無失点を${k.need}回` },
    shine: { sys: '試合', ok: () => true, need: 3, vague: '試合で目立つ活躍が続くと、殻を破りそうだ', clear: (k) => `Aの試合で採点7.5以上を${k.need}回` },
    convert: { sys: '育て方', ok: (p) => p.pos !== 'GK', need: 8, vague: '今の場所とは違う所で、新しい自分に出会いそうだ', clear: (k) => `登録（${YA.POS_NAME15 ? YA.POS_NAME15[k.from] || k.from : k.from}）と違うポジションで、Aに${k.need}試合出る` },
    starter: { sys: '育て方', ok: () => true, need: 10, vague: '試合に出続けることで、何かがつながりそうだ', clear: (k) => `Aで${k.need}試合先発する` },
    senpai: { sys: '人', ok: () => true, need: 6, vague: '慕っている先輩の背中から、何かを学びそうだ', clear: (k, w) => `${k.withName || '先輩'}（高3）と同じAの試合に${k.need}回出る`, due: 'y' },
    captain: { sys: '人', ok: (p) => p.grade >= 2, need: 8, vague: '人の上に立つことで、ひと皮むけそうだ', clear: (k) => `キャプテンか副キャプテンを${k.need}週任せる` },
    trust: { sys: '人', ok: () => true, need: 1, vague: '監督との関係が、鍵を握っていそうだ', clear: () => '監督への信頼が「深く信頼」（5/5）になる' },
    conf: { sys: '心', ok: () => true, need: 5, vague: '自信を持ち続けられれば、化けそうだ', clear: (k) => `自信70以上を${k.need}週続ける` },
    wall: { sys: '心', ok: () => true, need: 1, vague: '一度つまずいて、それを越えることが大事そうだ', clear: () => '壁（伸び悩み）に当たり、それを越える' },
    top: { sys: '外', ok: (p) => p.grade >= 2, need: 1, vague: '上の世界を肌で知ることが、刺激になりそうだ', clear: () => 'トップチームの練習に参加する', due: 'g3' },
    away: { sys: '外', ok: () => true, need: 3, vague: '知らない相手、知らない土地での経験が効きそうだ', clear: (k) => `大会でAに${k.need}試合出る（夏・冬の大会）` },
  };
  YA.KEY_DEF = KEYS;
  const SYS = ['試合', '育て方', '人', '心', '外'];
  // 覚醒の回数（決定103）：多くは1回・何人かは2回・まれに3回。本人も監督も知らない
  function awakeTimes(r) {
    const x = r();
    return x < 0.7 ? 1 : x < 0.95 ? 2 : 3;
  }
  // 期限：g2＝高2の冬まで、g3＝高3の冬まで、y＝今年度の終わり（先輩の卒業）まで
  function dueOf(w, p, d) {
    if (!d) return null;
    const endOf = (grade) => (w.year + Math.max(0, grade - p.grade)) * 100 + YA.WEEKS;
    if (d === 'g2') return p.grade <= 2 ? endOf(2) : null;
    if (d === 'g3') return endOf(3);
    return w.year * 100 + YA.WEEKS;
  }
  function makeKey(w, p, r, id, mult) {
    const d = KEYS[id];
    const k = { id, sys: d.sys, need: Math.max(1, Math.round(d.need * mult)), have: 0, h: 0, at: abs(w) };
    if (id === 'convert') k.from = p.main;
    if (id === 'senpai') {
      const s = Object.values(w.players).filter((q) => q.grade === 3 && q.id !== p.id && q.pos === p.pos).sort((a, b) => YA.rating(b) - YA.rating(a))[0];
      if (!s) return null;
      k.with = s.id;
      k.withName = s.name;
    }
    const due = dueOf(w, p, d.due);
    if (d.due && due == null) return null;
    if (due != null) k.due = due;
    return k;
  }
  function rollKeys(w, p, r, n, mult, avoid) {
    const out = [];
    const sysUsed = new Set();
    for (let tries = 0; out.length < n && tries < 40; tries++) {
      const ids = Object.keys(KEYS).filter((id) => KEYS[id].ok(p) && !(avoid || []).includes(id) && !out.some((k) => k.id === id) && !sysUsed.has(KEYS[id].sys));
      if (!ids.length) break;
      const k = makeKey(w, p, r, r.pick(ids), mult);
      if (!k) continue;
      out.push(k);
      sysUsed.add(k.sys);
    }
    return out;
  }
  // ★を付けたときに初めて鍵が決まる（同じ子なら同じ鍵）。鍵の短い子（fast）は2個・軽い
  YA.keysOf = function (w, p) {
    if (p.keys) return p.keys;
    const r = YA.rngOf((w.seed | 0) * 13 + YA.hash(p.id) * 7 + 5);
    if (p.awN == null) p.awN = awakeTimes(r);
    p.awDone = p.awDone || 0;
    const n = p.fast ? 2 : r.chance(0.5) ? 2 : 3;
    p.keys = rollKeys(w, p, r, n, p.fast ? 0.5 : 1);
    return p.keys;
  };
  YA.keyText = function (w, p, k) {
    const d = KEYS[k.id];
    if (!d) return '？';
    const due = k.due ? `（期限：${k.due % 100 === YA.WEEKS ? (Math.floor(k.due / 100) === w.year ? '今年度の終わり' : `${Math.floor(k.due / 100) - w.year}年後の冬`) : ''}まで）` : '';
    if (k.done) return '✓ ' + d.clear(k, w);
    if (k.h >= 2) return d.clear(k, w) + (d.need > 1 || k.need > 1 ? `　${k.have}/${k.need}` : '') + due;
    if (k.h >= 1) return d.vague + (k.due ? '（急いだほうがよさそうだ）' : '');
    return '？（' + k.sys + 'に関わる何か）';
  };
  // ヒントを1段進める。信頼が低いと本音を話さず進みにくい（決定110）。見る目で早まる
  function hintUp(w, p, chance, why) {
    const ks = (p.keys || []).filter((k) => !k.done && k.h < 2);
    if (!ks.length) return false;
    const lv = YA.trustLv(p);
    const eye = w.coach ? w.coach.eye / 10 : 1;
    const c = chance * (lv <= 2 ? 0.45 : lv >= 4 ? 1.35 : 1) * (0.8 + 0.2 * eye);
    const r = YA.rngOf((w.seed | 0) + abs(w) * 3 + YA.hash(p.id + why));
    if (!r.chance(c)) return false;
    const k = ks.sort((a, b) => b.have / b.need - a.have / a.need || a.h - b.h)[0];
    k.h++;
    if (k.h === 2) milestone(w, p, 'hint', { key: k.id });
    else YA.noteTier(w, 2, `${p.num}番 ${p.name}：覚醒の鍵のヒント「${KEYS[k.id].vague}」（${why}）`, p.id);
    return true;
  }
  YA.hintUp = hintUp;
  function progress(w, p, id, x) {
    for (const k of p.keys || []) {
      if (k.done || k.id !== id) continue;
      k.have = Math.min(k.need, k.have + x);
      if (k.h === 0) k.h = 1; // 動きがあれば、ぼんやり見える
      if (k.have >= k.need) {
        k.done = abs(w);
        p.hist.unshift({ y: w.year, w: w.week, t: '覚醒の鍵を1つ満たした：' + KEYS[id].clear(k, w) });
        YA.noteTier(w, 1, `${p.num}番 ${p.name}が覚醒の鍵を1つ満たした（${KEYS[id].clear(k, w)}）`, p.id);
        k.h = 2;
      }
    }
  }
  YA.keyProgress = progress;

  // ---------- 試合のあと：鍵の進み・信頼 ----------
  const applyMatch0 = YA.applyMatch;
  YA.applyMatch = function (w, m, which, opp, scheduled) {
    applyMatch0(w, m, which, opp, scheduled);
    if (which !== 'A' || !scheduled) return;
    const team = m.home;
    const big = opp && opp.kindLabel && !/^リーグ/.test(opp.kindLabel);
    const ga = m.score.away;
    const startIds = new Set(team.lineup.map((s) => s.pid));
    const played = new Set(Object.keys(team.players).filter((id) => team.players[id].st && team.players[id].st.minutes > 0));
    for (const id of played) {
      const p = w.players[id];
      if (!p) continue;
      p._weekMinsA = (p._weekMinsA || 0) + team.players[id].st.minutes;
      // 初出場の節目（★の子だけ）
      if (p.star && !(p.ms && p.ms.debut)) milestone(w, p, 'debut');
      if (!p.keys) continue;
      const st = p.st;
      if (big && st.goals > 0) progress(w, p, 'bigGoal', 1);
      if (big && ga === 0 && st.minutes >= 60) progress(w, p, 'bigClean', 1);
      if (st.goals > 0) progress(w, p, 'goals', st.goals);
      if (ga === 0 && st.minutes >= 60) progress(w, p, 'clean', 1);
      if (st.rating >= 7.5) progress(w, p, 'shine', 1);
      if (startIds.has(id)) progress(w, p, 'starter', 1);
      if (big) progress(w, p, 'away', 1);
      const k = (p.keys || []).find((x) => x.id === 'convert' && !x.done);
      const slot = team.startSlot && team.startSlot[id];
      if (k && slot && slot !== k.from) progress(w, p, 'convert', 1);
      const ks = (p.keys || []).find((x) => x.id === 'senpai' && !x.done);
      if (ks && played.has(ks.with)) progress(w, p, 'senpai', 1);
      // 試合での気づき（決定106）：活躍した試合ではヒントが進みやすい
      if (p.star && st.rating >= 7) hintUp(w, p, 0.3, '試合での気づき');
    }
  };

  // ---------- 出来事・面談のあと：信頼 ----------
  const resolve0 = YA.resolveEvent;
  YA.resolveEvent = function (w, e, idx) {
    const def = YA.EVENTS.find((x) => x.id === e.id);
    const p = e.pid ? w.players[e.pid] : null;
    const o = def && def.opts[idx];
    let rr = null;
    if (p && o && o.kind && !o.run && YA.react) rr = YA.react(p, o.kind);
    const res = resolve0(w, e, idx);
    if (p && w.players[p.id]) {
      if (rr) YA.addTr(w, p, rr.c >= 4 || rr.f >= 1 ? 6 : rr.c < 0 || rr.f < 0 ? -7 : 2);
      if (e.id === 'top' && idx === 0) progress(w, p, 'top', 1);
      if (p.star && e.id !== 'ms' && e.id !== 'awake') hintUp(w, p, 0.25, '話の中で');
    }
    return res;
  };
  const talk0 = YA.talk;
  YA.talk = function (w, pid, k) {
    const p = w.players[pid];
    const t = YA.TALKS.find((x) => x.k === k);
    const rr = p && t && YA.react ? YA.react(p, t.kind) : null;
    const res = talk0(w, pid, k);
    if (res.ok && p) {
      if (rr) YA.addTr(w, p, rr.c >= 4 || rr.f >= 1 ? 7 : rr.c < 0 || rr.f < 0 ? -8 : 3);
      if (p.star && hintUp(w, p, 0.55, '面談で')) res.extra = (res.extra ? res.extra + '　' : '') + '覚醒の鍵のヒントが見えた';
    }
    return res;
  };

  // ---------- 毎週：鍵の進み・期限・覚醒（club.js の awakeWeek を置き換える）----------
  YA.awakeWeek = function (w) {
    if (w.autoStar) YA.autoStars(w);
    const capIds = new Set([w.captain, w.vice].filter(Boolean));
    for (const p of Object.values(w.players)) {
      if (p.star) YA.addCare(w, p, 1);
      if (p.star && p.tr == null) p.tr = 50;
      if (!p.keys) continue;
      // 壁の始まりと終わり
      const wall = p.state && p.state.k === 'wall' && p.state.w > 0;
      // 壁の鍵を持つ子は、いずれ一度つまずく（決定102「壁を越える」）
      if (!wall && !p._inWall && p.star && (p.keys || []).some((k) => k.id === 'wall' && !k.done) && !(p.state && p.state.w > 0) && YA.rngOf((w.seed | 0) + abs(w) * 7 + YA.hash(p.id))() < 0.04) {
        p.state = { k: 'wall', w: 5 };
        YA.noteTier(w, 2, `${p.num}番 ${p.name}が壁に当たっている（しばらく伸びにくい）`, p.id);
      }
      const wall2 = p.state && p.state.k === 'wall' && p.state.w > 0;
      if (wall2 && !p._inWall) {
        p._inWall = true;
        if (p.star) milestone(w, p, 'wall');
      } else if (!wall2 && p._inWall) {
        p._inWall = false;
        if (p.conf >= 45) progress(w, p, 'wall', 1);
      }
      p._confRun = p.conf >= 70 ? (p._confRun || 0) + 1 : 0;
      for (const k of p.keys) if (k.id === 'conf' && !k.done) { k.have = Math.min(k.need, p._confRun); if (p._confRun) k.h = Math.max(k.h, 1); if (k.have >= k.need) progress(w, p, 'conf', 0); }
      if (capIds.has(p.id)) progress(w, p, 'captain', 1);
      if (YA.trustLv(p) >= 5) progress(w, p, 'trust', 1);
      // 不満が溜まったまま放っておくと、信頼が少しずつ下がる
      if (p.star && p.unrest >= 3) YA.addTr(w, p, -1.5);
      // Aで使い続けると、少しずつ信頼が積み上がる
      else if (p.star && (p._weekMinsA || 0) > 0) YA.addTr(w, p, 1.2);
      p._weekMinsA = 0;
      // コーチの報告（決定106）
      if (p.star) hintUp(w, p, 0.035, 'コーチの報告');
      // 期限切れの鍵は、別の鍵に替わって遠回りになる（決定107）
      for (let i = 0; i < p.keys.length; i++) {
        const k = p.keys[i];
        const gone = k.id === 'senpai' && !w.players[k.with];
        if (k.done || !((k.due && abs(w) > k.due) || gone)) continue;
        const r = YA.rngOf((w.seed | 0) + abs(w) + YA.hash(p.id) + i);
        const nk = rollKeys(w, p, r, 1, 1.4, p.keys.map((x) => x.id))[0];
        if (!nk) { k.due = null; continue; }
        nk.h = 1;
        p.keys[i] = nk;
        YA.noteTier(w, 1, `${p.num}番 ${p.name}：覚醒の鍵の期限が過ぎた。道は閉じていないが、別の形で遠回りになりそうだ（新しいヒント「${KEYS[nk.id].vague}」）`, p.id);
      }
      // 鍵が全部そろったら覚醒（★の子だけ）
      if (p.star && p.keys.length && p.keys.every((k) => k.done) && !(p.inj > 0) && !(p.away > 0)) YA.awaken(w, p);
    }
    return null;
  };

  // ---------- 覚醒の形と特性（決定108）----------
  // as は試合の中で同じ働きをする元の特性（engine の has がこれも見る）。覚醒でしか手に入らない名前で札に出る
  YA.AWAKE_FORMS = [
    { k: 'conductor', name: '司令塔として目覚める', pos: ['DM', 'CM', 'AM'], abs: ['パス', '視野', '判断', 'テクニック'], trait: '王様のパス', as: ['スルーパス', 'サイドチェンジ'] },
    { k: 'wall', name: '最終ラインの壁になる', pos: ['CB'], abs: ['タックル', 'マーク', 'ヘディング', '強さ', 'ポジショニング'], trait: '鉄壁', as: ['空中戦の競り', 'シュートブロック', '1対1の粘り'] },
    { k: 'scorer', name: '点取り屋として目覚める', pos: ['ST', 'SS'], abs: ['フィニッシュ', 'オフザボール', '冷静さ', 'ファーストタッチ'], trait: '決定力の怪物', as: ['こぼれ球への嗅覚', 'ニアへの飛び込み', '巻いて流し込むシュート'] },
    { k: 'flash', name: '韋駄天になる', pos: ['LW', 'RW', 'LM', 'RM', 'LWB', 'RWB', 'LB', 'RB', 'ST'], abs: ['加速', 'スピード', 'ドリブル', '敏しょう性'], trait: '置き去りの加速', as: ['縦への突破', '裏への抜け出し'] },
    { k: 'keeper', name: '守護神になる', pos: ['GK'], abs: ['反応', '1対1', 'ハンドリング', '集中'], trait: '神の手', as: ['PKストップ', '前に出るGK'] },
    { k: 'magic', name: 'ドリブルの魔術師になる', pos: ['LW', 'RW', 'AM', 'SS'], abs: ['ドリブル', 'テクニック', '敏しょう性', 'バランス'], trait: '魔法のドリブル', as: ['カットイン', 'ひらめき'] },
    { k: 'hunter', name: 'ボールの狩人になる', pos: ['DM', 'CM', 'CB'], abs: ['タックル', '予測', '運動量', 'マーク'], trait: '刈り取る者', as: ['ボール奪取', '読みのインターセプト', '即時奪回'] },
    { k: 'sky', name: '空の王になる', pos: ['CB', 'ST'], abs: ['ヘディング', 'ジャンプ', '強さ'], trait: '空の支配者', as: ['空中戦の競り', 'ヘディングシュート'] },
    { k: 'cannon', name: '大砲を手に入れる', pos: ['DM', 'CM', 'AM', 'SS', 'ST'], abs: ['ロングシュート', 'テクニック', '強さ'], trait: '大砲', as: ['弾丸ミドル'] },
    { k: 'crosser', name: 'クロスの職人になる', pos: ['LB', 'RB', 'LWB', 'RWB', 'LM', 'RM', 'LW', 'RW'], abs: ['クロス', 'パス', 'スタミナ'], trait: '針の穴のクロス', as: ['アーリークロス', '曲がるCK'] },
    { k: 'engine', name: '走る心臓になる', pos: ['DM', 'CM', 'LM', 'RM', 'LWB', 'RWB'], abs: ['運動量', 'スタミナ', 'チームワーク'], trait: '無尽蔵', as: ['オーバーラップ', '前線からの守備'] },
    { k: 'leader', name: '最後尾の指揮官になる', pos: ['CB', 'DM', 'GK'], abs: ['判断', '集中', 'チームワーク', 'ポジショニング'], trait: '最後尾の指揮官', as: ['ラインコントロール', '声で味方を動かす'] },
    { k: 'fighter', name: '闘将になる', pos: ['CB', 'LB', 'RB', 'LWB', 'RWB', 'DM', 'CM', 'LM', 'RM', 'AM', 'LW', 'RW', 'SS', 'ST'], abs: ['強さ', '運動量', '冷静さ'], trait: '燃える闘将', as: ['声で味方を動かす', '1対1の粘り'] },
    { k: 'fantasista', name: 'ファンタジスタになる', pos: ['AM', 'SS'], abs: ['視野', 'テクニック', 'ファーストタッチ'], trait: '異次元の視野', as: ['ひらめき', 'スルーパス', 'ワンツー'] },
    { k: 'post', name: '前線の柱になる', pos: ['ST'], abs: ['強さ', 'バランス', 'ファーストタッチ'], trait: '背中の壁', as: ['ポストプレー', '背負ってからのターン', 'タメを作る'] },
    { k: 'setpiece', name: 'セットプレーの名手になる', pos: ['CM', 'AM', 'LM', 'RM', 'LW', 'RW', 'LB', 'RB'], abs: ['プレースキック', 'テクニック', 'クロス'], trait: '魔法の右足', as: ['直接FK', '曲がるCK'] },
    { k: 'wing', name: 'サイドの翼になる', pos: ['LB', 'RB', 'LWB', 'RWB'], abs: ['スピード', 'クロス', 'オフザボール', 'スタミナ'], trait: '翼', as: ['オーバーラップ', 'アーリークロス'] },
    { k: 'reader', name: '読みの名手になる', pos: ['CB', 'LB', 'RB', 'DM'], abs: ['予測', 'ポジショニング', '集中'], trait: '未来を読む', as: ['読みのインターセプト', 'カバーリング'] },
    { k: 'sweeperk', name: '攻撃の起点になるGKへ', pos: ['GK'], abs: ['配球', '飛び出し', 'エリアの支配'], trait: '最初の攻撃者', as: ['速い配球', '足元のうまいGK'] },
    { k: 'ice', name: '氷の心臓を持つ', pos: ['SS', 'AM', 'LW', 'RW', 'ST'], abs: ['冷静さ', 'フィニッシュ', '判断'], trait: '氷の心臓', as: ['巻いて流し込むシュート', 'ループシュート'] },
  ];
  function formFor(p, r) {
    const pos = p.best || p.main;
    const done = (p.awHist || []).map((x) => x.k);
    let c = YA.AWAKE_FORMS.filter((f) => (f.pos.includes(pos) || f.pos.includes(p.main)) && !done.includes(f.k));
    if (!c.length) c = YA.AWAKE_FORMS.filter((f) => f.pos.includes(p.main) || f.pos.includes(pos));
    return r.weighted(c, (f) => Math.pow(f.abs.reduce((s, a) => s + (p.ab[a] || 6), 0) / f.abs.length, 2));
  }
  YA.awaken = function (w, p, r) {
    r = r || YA.rngOf((w.seed | 0) * 3 + abs(w) + YA.hash(p.id));
    const from = YA.rating(p);
    const f = formFor(p, r);
    const n = (p.awDone || 0) + 1;
    // 回数が多い子ほど1回ごとの伸びは控えめ（決定103。卒業時の平均90前後を崩さない）
    const big = n === 1 ? 2 : 1;
    for (const a of f.abs) if (p.ab[a] != null) p.ab[a] = Math.min(20, p.ab[a] + big + (r.chance(0.3) ? 1 : 0));
    p.pot += n === 1 ? 60 : 30;
    p.awDone = n;
    p.awHist = (p.awHist || []).concat([{ k: f.k, y: w.year, w: w.week }]);
    p.aw = { k: f.k, form: f.name, trait: f.trait, as: f.as.slice() };
    p.awake = { y: w.year, w: w.week, from, to: YA.rating(p), why: 'star', form: f.name, trait: f.trait, n };
    p.state = { k: 'peak', w: 12 };
    p.conf = clamp(p.conf + 15, 0, 100);
    p.hist.unshift({ y: w.year, w: w.week, t: `覚醒した：${f.name}（特性「${f.trait}」・総合力 ${from}→${p.awake.to}）` });
    w.awakeN = { y: w.year, n: (w.awakeN && w.awakeN.y === w.year ? w.awakeN.n : 0) + 1 };
    // 次の覚醒が残っている子には、次の鍵が現れる
    p.keys = n < (p.awN || 1) ? rollKeys(w, p, r, 2, 1.3, (p.keys || []).map((k) => k.id)) : [];
    YA.addTr(w, p, 10);
    w.forced = (w.forced || []).concat([{ id: 'awake', pid: p.id, week: w.week, year: w.year }]);
    return p;
  };
  YA.EVENT_ABOUT = YA.EVENT_ABOUT || {};
  YA.EVENT_ABOUT.awake = '★の子が、覚醒の鍵をすべて満たしました。形に合った能力がまとめて上がり、覚醒でしか手に入らない特性が付きます。';
  const ev = YA.EVENTS.find((e) => e.id === 'awake');
  if (ev) ev.text = (p) => {
    const a = p.awake || {};
    return `${p.name}（高${p.grade}・${YA.POS_NAME15 ? YA.POS_NAME15[p.main] || p.main : p.main}）が覚醒した――${a.form || ''}。総合力 ${a.from}→${a.to}。覚醒の特性「${a.trait || ''}」が付いた。${(p.keys || []).length ? 'まだ先がありそうだ。新しい鍵の気配がする' : ''}`;
  };

  // ---------- 節目の会話（決定109）：★の子に、3年間の節目ごとに来る ----------
  const LINES = {
    star: [
      (p) => `${p.name}を呼んで、これから特に見ていくと伝えた。「えっ、自分ですか……がんばります」`,
      (p) => `${p.name}に、これから目をかけていくと伝えた。「はい。期待に応えます」まっすぐこちらを見た`,
      (p) => `${p.name}に声をかけた。「……なんで俺なんすか」照れくさそうに目をそらした`,
    ],
    debut: [
      (p) => `${p.name}がAの試合に初めて出た。試合のあと、まだ息を弾ませている。「やっと、ここまで来ました」`,
      (p) => `Aでの初めての試合を終えた${p.name}が、黙ってこちらに頭を下げた`,
      (p) => `${p.name}のAでの初出場。「緊張で、あんまり覚えてないです」と笑った`,
    ],
    wall: [
      (p) => `${p.name}が伸び悩んでいる。練習のあと、一人で残っていた。「最近、何をやってもうまくいかなくて」`,
      (p) => `${p.name}の表情が硬い。「前はできていたことが、できなくなった気がします」`,
      (p) => `${p.name}が珍しく弱音を吐いた。「自分、ここまでなのかなって」`,
    ],
    hint: [
      (p, w, x) => `${p.name}と話していて、はっきり見えた。この子が化けるには――「${KEYS[x.key].clear((p.keys || []).find((k) => k.id === x.key) || { need: KEYS[x.key].need }, w)}」`,
      (p, w, x) => `コーチが言った。「${fam(p)}は、${KEYS[x.key].clear((p.keys || []).find((k) => k.id === x.key) || { need: KEYS[x.key].need }, w)}――それが、きっかけになりそうです」`,
    ],
    grad: [
      (p) => `卒業式の朝、${p.name}が来た。「3年間、ありがとうございました。監督に見てもらえて、よかったです」`,
      (p) => `${p.name}が最後の練習のあと、しばらくグラウンドを見ていた。「ここで、全部教わりました」`,
      (p) => `卒業式。${p.name}は泣かないと決めていたらしいが、最後の礼で声が詰まった`,
    ],
  };
  const NAMES = { star: '★注目：最初の話', debut: '節目：初めての出場', wall: '節目：壁', hint: '節目：鍵が見えた', grad: '節目：卒業式' };
  function milestone(w, p, kind, x) {
    p.ms = p.ms || {};
    if (kind !== 'hint' && p.ms[kind]) return;
    p.ms[kind] = abs(w);
    w.forced = (w.forced || []).concat([{ id: 'ms', pid: p.id, x: null, ms: kind, key: x && x.key, week: w.week, year: w.year }]);
  }
  YA.milestone = milestone;
  const msOpt = (label, kind, d) => ({ label, kind, extra: (w, p) => { if (d) YA.addTr(w, p, d); } });
  const MS_OPTS = {
    star: [msOpt('「三年間で、必ず化けさせる」と約束する', 'push', 3), msOpt('「焦らず、一緒にやっていこう」と伝える', 'warm', 2), msOpt('「まだ何も決まっていない。結果で見せろ」と突き放す', 'firm')],
    debut: [msOpt('「よくやった」と肩をたたく', 'warm'), msOpt('「ここからが本番だ」と次を求める', 'push'), msOpt('良かった所と課題を一つずつ伝える', 'firm')],
    wall: [msOpt('「必ず越えられる」と信じて待つ', 'warm'), msOpt('一緒に原因を探し、練習を組み直す', 'push'), msOpt('「誰でも通る道だ」とあえて厳しくする', 'firm')],
    hint: [msOpt('本人に「ここが鍵だ」と伝える', 'push', 2), msOpt('伝えずに、そうなる場を作ってやる', 'wait')],
    grad: [msOpt('「お前は、ここからだ」と送り出す', 'push'), msOpt('「三年間、ありがとう」と握手する', 'warm'), msOpt('黙ってうなずく', 'wait')],
  };
  YA.EVENTS.push({ id: 'ms', name: '節目の会話', weight: 0, pick: () => null, text: () => '', opts: MS_OPTS.debut });
  YA.EVENT_ABOUT.ms = '★の子との節目の会話です。どう返すかで、その子の信頼（5段階）が動きます。信頼が高いほど、覚醒の鍵のヒントが早く見えます。';
  // 節目の会話は種類ごとに選択肢が違うので、eventView / resolveEvent の前に差し替える
  const view0 = YA.eventView;
  YA.eventView = function (w, e) {
    if (e.id !== 'ms') return view0(w, e);
    const p = w.players[e.pid];
    if (!p) return null;
    const def = YA.EVENTS.find((x) => x.id === 'ms');
    def.opts = MS_OPTS[e.ms] || MS_OPTS.debut;
    def.name = NAMES[e.ms] || '節目の会話';
    const list = LINES[e.ms] || LINES.debut;
    def.text = (q, ww) => list[YA.hash(q.id + e.ms) % list.length](q, ww, { key: e.key }) + `（信頼 ${YA.trustLv(q)}/5：${YA.TRUST_NAME[YA.trustLv(q)]}）`;
    return view0(w, e);
  };
  const res1 = YA.resolveEvent;
  YA.resolveEvent = function (w, e, idx) {
    if (e.id === 'ms') {
      const def = YA.EVENTS.find((x) => x.id === 'ms');
      def.opts = MS_OPTS[e.ms] || MS_OPTS.debut;
      def.name = NAMES[e.ms] || '節目の会話';
      if (e.ms === 'hint' && idx === 0) { const p = w.players[e.pid]; if (p) for (const k of p.keys || []) if (k.id === e.key && !k.done) k.told = true; }
    }
    return res1(w, e, idx);
  };
  // 卒業式の前の週（39週）に、★の高3と最後の会話
  YA.gradTalks = function (w) {
    if (w.week !== YA.WEEKS - 1) return;
    for (const p of Object.values(w.players)) if (p.star && p.grade === 3) milestone(w, p, 'grad');
  };
  const aw0 = YA.awakeWeek;
  YA.awakeWeek = function (w) {
    YA.gradTalks(w);
    return aw0(w);
  };

  // 最初の36人に、鍵の短い子を1〜2人混ぜておく（決定113。見た目では分からない）
  const nw0 = YA.newWorld;
  YA.newWorld = function (seed, opts) {
    const w = nw0(seed, opts);
    const r = YA.rngOf((seed | 0) * 29 + 3);
    const c = Object.values(w.players).filter((p) => p.grade <= 2);
    const n = r.chance(0.5) ? 1 : 2;
    for (let i = 0; i < n && c.length; i++) c.splice(r.int(0, c.length - 1), 1)[0].fast = true;
    return w;
  };

  // おまかせ進行では、★を自動で付ける（暦の判断と同じ扱い）
  const autoScout0 = YA.autoScout;
  if (autoScout0) YA.autoScout = function (w) {
    YA.autoStars(w);
    return autoScout0(w);
  };
  YA.EXTRA_SIM_IMPORTANT = ['ms'];
})();
