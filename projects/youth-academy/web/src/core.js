// 1段目「芯」（決定85・101〜110・113）：覚醒の形と特性、課題中の子ごとの信頼5段階、節目の会話。
// 2026-11-26 ★注目と覚醒の鍵をやめ、課題（kadai.js）に置き換えた。p.star は「いま課題に取り組んでいる」の意味。見せ方に依存しない。
(function () {
  'use strict';
  const YA = (globalThis.YA = globalThis.YA || {});
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const first = (p) => p.name.split(' ')[1] || p.name;
  const fam = (p) => p.name.split(' ')[0];
  const ST = (p, g, v) => p.pers && p.pers[g] === v;
  const abs = (w) => w.year * 100 + w.week;

  // ---------- 伸びしろの星と幅（決定91）----------
  // 一覧：コーチの見立ての星1〜5。見る目が低いと1つ外れることがある（同じ子・同じ年なら同じ外れ方）
  YA.coachStars = function (w, p) {
    const s = YA.potStars(p);
    const eye = w && w.coach ? w.coach.eye : 10;
    const r = YA.rngOf((w ? w.seed | 0 : 0) * 11 + YA.hash(p.id) + (w ? w.year : 0) * 97);
    const miss = clamp(0.42 - eye * 0.018 - (p.grade - 1) * 0.08 - (p.star ? 0.1 : 0), 0.03, 0.5);
    return clamp(s + (r.chance(miss) ? (r.chance(0.5) ? 1 : -1) : 0), 1, 5);
  };
  // 詳細：将来の総合力の幅と水準名。見る目・学年・課題で見た長さ（careOf）で狭まる。見抜く目（課金）は w.sharpEye
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
    // 総合力は200が上限（200＝歴史上No.1）。見立ての幅を足しても200を超えて見せない
    const hi = Math.min(200, Math.max(YA.rating(p) + 2, mid + half + off));
    const lo = Math.min(hi - 2, Math.max(YA.rating(p), mid - half + off));
    const nm = (v) => YA.levelOf(v).replace(/（.*）/, '');
    return { lo, hi, text: `将来 ${lo}〜${hi}（${nm(lo) === nm(hi) ? nm(lo) : nm(lo) + '〜' + nm(hi)}）` };
  };

  // ---------- 練習の伸びの見せ方（決定90）：課題中の子は「パス 11→12」、ほかは矢印。コーチの一言を添える ----------
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
    // コーチの一言：いちばん伸びた子（課題中の子を優先）の、いちばん伸びた能力
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
    const lvP = m.live && m.live.poss ? m.live.poss : null;
    const poss = lvP && lvP.home + lvP.away > 0 ? Math.round((100 * lvP.home) / (lvP.home + lvP.away)) : clamp(Math.round(100 * (0.65 * hs + 0.35 * (mine.length / Math.max(1, m.scenes.length)))), 25, 75);
    // 相手陣で奪った回数＝高い位置での奪取の場面で奪えた回数＋合間の相手陣での奪取（下の選手ごとの奪取のうち、前の子ほど相手陣で取る割合が高い）。
    // 2026-11-17：前は自陣で止めた場面（DF 以外が絡んだもの）を数えていて、名前と中身がずれ、ほぼ0だった
    const stealWon = mine.filter((sc) => sc.type === 'steal' && sc.outcome !== 'escaped').length;
    // 攻めた方向：自分の見どころの最初のボールの横の位置（0〜68m）
    const dir = { 左: 0, 中央: 0, 右: 0 };
    if (m.live) {
      // 一続きの試合：こちらのシュートの前にボールがあった横の位置（シュートを打った所）
      for (const e of m.live.events) if (e.k === 'shot' && e.sd === 'home') dir[e.x < 23 ? '左' : e.x > 45 ? '右' : '中央']++;
    }
    for (const sc of m.live ? [] : mine) {
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
      // 一続きの試合（live）は本当の数（パス・タックル・奪取）を使う
      const lvN = m.live && st.pa != null;
      players.push({ id: p.id, num: p.num, name: p.name, pos: p.pos, mins: st.minutes, rating: st.rating, passes: lvN ? st.pa : passes, pct: lvN ? Math.round((100 * (st.pc || 0)) / Math.max(1, st.pa)) : pct, shots: st.shots || 0, goals: st.goals || 0, tackles: m.live ? st.ta || 0 : tk, steals: m.live ? (st.tk || 0) + (st.ic || 0) : steal, saves: st.saves || 0, yellow: p.yellow || 0, red: !!p.sentOff });
    }
    const highShare = { FW: 0.7, MF: 0.3, DF: 0.05, GK: 0 };
    let won = stealWon + Math.round(players.reduce((t, x) => t + x.steals * (highShare[x.pos] || 0), 0) * (0.6 + hs * 0.8));
    if (m.live) {
      // 相手陣（ホームは y が 52.5 より先）で奪った本当の回数。奪った子の位置で数える
      won = 0;
      const lv = m.live;
      for (const e of lv.events) {
        if (e.sd !== 'home' || !(e.k === 'intercept' || (e.k === 'tackle' && e.ok))) continue;
        const q = lv.byId[e.pid];
        const y = e.y != null ? e.y : q ? q.y : 0;
        if (y > 52.5) won++;
      }
    }
    players.sort((a, b) => b.rating - a.rating);
    // 効いた戦術の一言（決定114）
    const type = (m.home.tactic && m.home.tactic.type) || '戦い方';
    const good = mine.filter((sc) => sc.goal || sc.outcome === 'saved').length;
    const topDir = Object.entries(dirPct).sort((a, b) => b[1] - a[1])[0];
    const sh = m.stats.home;
    let tactic;
    if (good >= 3 && topDir[1] >= 45) tactic = `「${type}」がはまった。${topDir[0]}から崩す形が${dir[topDir[0]]}回できた`;
    else if (stealWon >= 2 || won >= 7) tactic = `「${type}」で前から奪えた。相手陣で${won}回ボールを取った`;
    else if (poss <= 40 && m.score.home >= m.score.away) tactic = `ボールは持たれたが、「${type}」で耐えて勝ち点を取った`;
    else if (sh.shots <= 3) tactic = `「${type}」では崩しきれなかった。シュートは${sh.shots}本だけ`;
    else tactic = `「${type}」は五分。${topDir[0]}からの攻めが多かった（${topDir[1]}%）`;
    return { poss, shots: sh.shots, onTarget: sh.onTarget, oppShots: m.stats.away.shots, oppOnTarget: m.stats.away.onTarget, won, stealWon, cards: (m.cards || []).slice(), dir: dirPct, players, tactic };
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
    ['ユースの指導者になった', '高1〜高3の33人を預かり、3年かけて育てて送り出します。勝つことと、育てること。その両方を任されています。'],
    ['全員を見て、課題を出す', '一人ひとりに、化けるための「合う課題」が隠れています。コーチの見立て・本人の言葉・試合の場面の手がかりから見抜いて、課題を出します（同時に5人まで）。合っていれば、苦しんだ末に試合の一場面で気づいて覚醒します。'],
    ['毎週やること', '練習の画面を確かめて「この週で行く」。試合の週は布陣と戦い方を決めてキックオフ。出来事が起きたら、言葉をかけて選びます。'],
    ['系譜を伸ばす', '卒業した子がプロや代表で活躍すると、あなたの系譜が伸びます。大きな移籍では連帯貢献金も入ります。'],
  ];
  // 画面を初めて開いたときだけ、アシスタントコーチが1〜2行で教える。二度目からは出ない
  YA.COACH_TIPS = {
    home: '左が今週やることです。困ったら右の「今週気にかけたい子」から見てください。',
    players: '選手を押すと、コーチの報告の一番上に手がかりが出ます。手がかりから合う課題を考えて「課題を出す」。',
    train: '7マスを押すとメニューが替わります。疲れの高い子は右下で休ませられます。決まったら「この週で行く」。',
    match: '試合の前は相手の分析を見てから、並びと戦い方を。試合中は「止める」で交代と指示ができます。',
    club: '予算・スタッフ・スカウトなど、クラブのことはここです。最初はクラブとコーチが決めてくれます。',
    more: 'クラブ史・Bチーム・引退・用語集・設定はここです。卒業生の名鑑と実績は「記録」にあります。',
  };
  // 「ほか」は開いている小タブに合わせる（2026-11-16 設定を開いても「名鑑と記録はここです」と出ていた）
  YA.COACH_TIPS_MORE = {
    alumni: '卒業生の名鑑です。押すと、その後の年表と経歴が見られます。追う・連絡する・試合を観に行くもここから。',
    rec: 'Aチームの戦績・獲った大会・リーグの履歴・最近の試合です。',
    bteam: 'Bチームの並び・戦い方・起用の方針です。Aの並びは変わりません。',
    ach: '監督を引退するときの画面です。実績の一覧は「記録」タブにあります。',
    help: '言葉の意味はここで引けます。',
    set: '効果音・BGM・文字の大きさ・お知らせの重さ・セーブ枠はここで変えられます。',
  };
  YA.coachKey = (tab) => (tab === 'more' && YA._ui && YA._ui.app ? 'more:' + (YA._ui.app.mt || 'alumni') : tab);
  YA.coachTip = function (w, tab) {
    if (!w || !YA.COACH_TIPS[tab]) return null;
    w.coachSeen = w.coachSeen || {};
    const key = YA.coachKey(tab);
    if (w.coachSeen[key]) return null;
    let t = tab === 'more' ? YA.COACH_TIPS_MORE[key.slice(5)] || YA.COACH_TIPS.more : YA.COACH_TIPS[tab];
    return t;
  };
  // ---------- 信頼（決定110）：課題を出した子ごとに5段階（課題が終わっても値は残る）----------
  YA.TRUST_NAME = ['', '心を閉ざす', 'よそよそしい', 'ふつう', '信じている', '深く信頼'];
  YA.trustLv = (p) => 1 + Math.min(4, Math.floor(clamp(p.tr == null ? 50 : p.tr, 0, 100) / 20));
  YA.addTr = function (w, p, d, why) {
    if (!p) return;
    const lv0 = YA.trustLv(p);
    p.tr = clamp((p.tr == null ? 50 : p.tr) + d, 0, 100);
    const lv1 = YA.trustLv(p);
    if (lv1 !== lv0 && p.star) YA.noteTier(w, 2, `${p.num}番 ${p.name}の信頼が「${YA.TRUST_NAME[lv1]}」（${lv1}/5）に${lv1 > lv0 ? '上がった' : '下がった'}${why ? '（' + why + '）' : ''}`, p.id);
  };

  // 覚醒の回数（決定103。2026-11-26 から1〜2回）：本人も監督も知らない
  function awakeTimes(r) {
    return r() < 0.72 ? 1 : 2;
  }
  YA.awakeTimesOf = function (w, p) {
    if (p.awN == null) p.awN = awakeTimes(YA.rngOf((w.seed | 0) * 13 + YA.hash(p.id) * 7 + 5));
    p.awDone = p.awDone || 0;
    return p.awN;
  };

  // ---------- 上位の特性（金）：効いた試合の数を数え、条件がそろえば金に変わる ----------
  // 2026-11-23：前は効いた回数を数えていて、GK のセーブの特性などは1試合で6回に届き、1試合目で金に変わっていた。1試合で何回効いても1と数える
  YA.goldReady = function (p, t) {
    const aff = YA.TRAIT_AFF[t] || [];
    const ab = aff.length ? aff.reduce((s, n) => s + (p.ab[n] || 0), 0) / aff.length : 0;
    const used = (p.trUse && p.trUse[t]) || 0;
    return { used, ab: Math.round(ab * 10) / 10, ok: used >= YA.GOLD_USES && ab >= YA.GOLD_AB };
  };
  YA.goldCheck = function (w, p) {
    for (const t of p.traits) {
      if (!YA.GOLD[t] || YA.isGold(p, t) || !YA.goldReady(p, t).ok) continue;
      p.gold = (p.gold || []).concat([t]);
      p.hist.unshift({ y: w.year, w: w.week, t: `特性「${t}」が金の特性「${YA.GOLD[t]}」に変わった` });
      YA.noteTier(w, 1, `${p.num}番 ${p.name}の「${t}」が、金の特性「${YA.GOLD[t]}」に変わった（効きが${YA.GOLD_MULT}倍）`, p.id);
    }
  };
  YA.traitUse = function (w, m) {
    const seen = new Set();
    for (const [k, n] of Object.entries(m.trUse || {})) {
      const i = k.indexOf('|');
      const p = w.players[k.slice(0, i)];
      if (!p) continue;
      const t = k.slice(i + 1);
      p.trUse = p.trUse || {};
      if (n > 0) p.trUse[t] = (p.trUse[t] || 0) + 1;
      seen.add(p);
    }
    for (const p of seen) YA.goldCheck(w, p);
  };

  // ---------- 試合のあと：信頼・初出場（課題の気づきは kadai.js）----------
  const applyMatch0 = YA.applyMatch;
  YA.applyMatch = function (w, m, which, opp, scheduled) {
    applyMatch0(w, m, which, opp, scheduled);
    YA.traitUse(w, m);
    if (which !== 'A' || !scheduled) return;
    const team = m.home;
    for (const id of Object.keys(team.players)) {
      const p = w.players[id];
      const st = team.players[id].st;
      if (!p || !st || !(st.minutes > 0)) continue;
      p._weekMinsA = (p._weekMinsA || 0) + st.minutes;
      // 初出場の節目（課題中の子）
      if (p.star && !(p.ms && p.ms.debut)) milestone(w, p, 'debut');
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
    if (p && w.players[p.id] && rr) YA.addTr(w, p, rr.c >= 4 || rr.f >= 1 ? 6 : rr.c < 0 || rr.f < 0 ? -7 : 2);
    return res;
  };
  const talk0 = YA.talk;
  YA.talk = function (w, pid, k) {
    const p = w.players[pid];
    const t = YA.TALKS.find((x) => x.k === k);
    const rr = p && t && YA.react ? YA.react(p, t.kind) : null;
    const res = talk0(w, pid, k);
    if (res.ok && p && rr) YA.addTr(w, p, rr.c >= 4 || rr.f >= 1 ? 7 : rr.c < 0 || rr.f < 0 ? -8 : 3);
    return res;
  };

  // ---------- 毎週：信頼・壁の節目・課題（club.js の awakeWeek を置き換える）----------
  YA.awakeWeek = function (w) {
    for (const p of Object.values(w.players)) {
      YA.awakeTimesOf(w, p);
      if (!p.star) { p._weekMinsA = 0; continue; }
      YA.addCare(w, p, 1);
      if (p.tr == null) p.tr = 50;
      // 壁の始まり（課題中の子は節目の会話）
      const wall = p.state && p.state.k === 'wall' && p.state.w > 0;
      if (wall && !p._inWall) { p._inWall = true; milestone(w, p, 'wall'); } else if (!wall && p._inWall) p._inWall = false;
      // 不満が溜まったまま放っておくと、信頼が少しずつ下がる
      if (p.unrest >= 3) YA.addTr(w, p, -1.5);
      // Aで使い続けると、少しずつ信頼が積み上がる
      else if ((p._weekMinsA || 0) > 0) YA.addTr(w, p, 1.2);
      p._weekMinsA = 0;
    }
    if (YA.kadaiWeek) YA.kadaiWeek(w);
    return null;
  };

  // ---------- 覚醒の形と特性（決定108）----------
  // as は試合の中で同じ働きをする元の特性（engine の has がこれも見る）。覚醒でしか手に入らない名前で札に出る
  // 覚醒の特性は、ひとつの名前に4つの特性が入る（2026-11-15「もう少し特性の数増やして」で2〜3個から4個に）
  YA.AWAKE_FORMS = [
    { k: 'conductor', name: '司令塔として目覚める', pos: ['DM', 'CM', 'AM'], abs: ['パス', '視野', '判断', 'テクニック'], trait: '王様のパス', as: ['スルーパス', 'サイドチェンジ', '下がって受ける', '試合を落ち着かせる'] },
    { k: 'wall', name: '最終ラインの壁になる', pos: ['CB'], abs: ['タックル', 'マーク', 'ヘディング', '強さ', 'ポジショニング'], trait: '鉄壁', as: ['空中戦の競り', 'シュートブロック', '1対1の粘り', 'カバーリング'] },
    { k: 'scorer', name: '点取り屋として目覚める', pos: ['ST', 'SS'], abs: ['フィニッシュ', 'オフザボール', '冷静さ', 'ファーストタッチ'], trait: '決定力の怪物', as: ['こぼれ球への嗅覚', 'ニアへの飛び込み', '巻いて流し込むシュート', '裏への抜け出し'] },
    { k: 'flash', name: '韋駄天になる', pos: ['LW', 'RW', 'LM', 'RM', 'LWB', 'RWB', 'LB', 'RB', 'ST'], abs: ['加速', 'スピード', 'ドリブル', '敏しょう性'], trait: '置き去りの加速', as: ['縦への突破', '裏への抜け出し', 'ボールを運ぶ', 'カットイン'] },
    { k: 'keeper', name: '守護神になる', pos: ['GK'], abs: ['反応', '1対1', 'ハンドリング', '集中'], trait: '神の手', as: ['PKストップ', '前に出るGK', 'パンチング', 'クロスへの強さ'] },
    { k: 'magic', name: 'ドリブルの魔術師になる', pos: ['LW', 'RW', 'AM', 'SS'], abs: ['ドリブル', 'テクニック', '敏しょう性', 'バランス'], trait: '魔法のドリブル', as: ['カットイン', 'ひらめき', 'ファウルをもらう', 'ボールを運ぶ'] },
    { k: 'hunter', name: 'ボールの狩人になる', pos: ['DM', 'CM', 'CB'], abs: ['タックル', '予測', '運動量', 'マーク'], trait: '刈り取る者', as: ['ボール奪取', '読みのインターセプト', '即時奪回', 'スライディング'] },
    { k: 'sky', name: '空の王になる', pos: ['CB', 'ST'], abs: ['ヘディング', 'ジャンプ', '強さ'], trait: '空の支配者', as: ['空中戦の競り', 'ヘディングシュート', 'ニアへの飛び込み', 'シュートブロック'] },
    { k: 'cannon', name: '大砲を手に入れる', pos: ['DM', 'CM', 'AM', 'SS', 'ST'], abs: ['ロングシュート', 'テクニック', '強さ'], trait: '大砲', as: ['弾丸ミドル', 'こぼれ球への嗅覚', '直接FK', 'ボールを運ぶ'] },
    { k: 'crosser', name: 'クロスの職人になる', pos: ['LB', 'RB', 'LWB', 'RWB', 'LM', 'RM', 'LW', 'RW'], abs: ['クロス', 'パス', 'スタミナ'], trait: '針の穴のクロス', as: ['アーリークロス', '曲がるCK', 'サイドチェンジ', 'オーバーラップ'] },
    { k: 'engine', name: '走る心臓になる', pos: ['DM', 'CM', 'LM', 'RM', 'LWB', 'RWB'], abs: ['運動量', 'スタミナ', 'チームワーク'], trait: '無尽蔵', as: ['オーバーラップ', '前線からの守備', '即時奪回', 'ボールを運ぶ'] },
    { k: 'leader', name: '最後尾の指揮官になる', pos: ['CB', 'DM', 'GK'], abs: ['判断', '集中', 'チームワーク', 'ポジショニング'], trait: '最後尾の指揮官', as: ['ラインコントロール', '声で味方を動かす', '試合を落ち着かせる', 'カバーリング'] },
    { k: 'fighter', name: '闘将になる', pos: ['CB', 'LB', 'RB', 'LWB', 'RWB', 'DM', 'CM', 'LM', 'RM', 'AM', 'LW', 'RW', 'SS', 'ST'], abs: ['強さ', '運動量', '冷静さ'], trait: '燃える闘将', as: ['声で味方を動かす', '1対1の粘り', 'ボール奪取', 'スライディング'] },
    { k: 'fantasista', name: 'ファンタジスタになる', pos: ['AM', 'SS'], abs: ['視野', 'テクニック', 'ファーストタッチ'], trait: '異次元の視野', as: ['ひらめき', 'スルーパス', 'ワンツー', '下がって受ける'] },
    { k: 'post', name: '前線の柱になる', pos: ['ST'], abs: ['強さ', 'バランス', 'ファーストタッチ'], trait: '背中の壁', as: ['ポストプレー', '背負ってからのターン', 'タメを作る', 'ヘディングシュート'] },
    { k: 'setpiece', name: 'セットプレーの名手になる', pos: ['CM', 'AM', 'LM', 'RM', 'LW', 'RW', 'LB', 'RB'], abs: ['プレースキック', 'テクニック', 'クロス'], trait: '魔法の右足', as: ['直接FK', '曲がるCK', 'サイドチェンジ', 'アーリークロス'] },
    { k: 'wing', name: 'サイドの翼になる', pos: ['LB', 'RB', 'LWB', 'RWB'], abs: ['スピード', 'クロス', 'オフザボール', 'スタミナ'], trait: '翼', as: ['オーバーラップ', 'アーリークロス', '縦への突破', '即時奪回'] },
    { k: 'reader', name: '読みの名手になる', pos: ['CB', 'LB', 'RB', 'DM'], abs: ['予測', 'ポジショニング', '集中'], trait: '未来を読む', as: ['読みのインターセプト', 'カバーリング', 'ラインコントロール', 'ボール奪取'] },
    { k: 'sweeperk', name: '攻撃の起点になるGKへ', pos: ['GK'], abs: ['配球', '飛び出し', 'エリアの支配'], trait: '最初の攻撃者', as: ['速い配球', '足元のうまいGK', '前に出るGK', '試合を落ち着かせる'] },
    { k: 'ice', name: '氷の心臓を持つ', pos: ['SS', 'AM', 'LW', 'RW', 'ST'], abs: ['冷静さ', 'フィニッシュ', '判断'], trait: '氷の心臓', as: ['巻いて流し込むシュート', 'ループシュート', '試合を落ち着かせる', 'ファウルをもらう'] },
  ];
  function formFor(p, r) {
    const pos = p.best || p.main;
    const done = (p.awHist || []).map((x) => x.k);
    // オリジナル選手で決めた形（1回目の覚醒はこの形で目覚める）
    if (p.formPick && !done.includes(p.formPick)) { const pick = YA.AWAKE_FORMS.find((f) => f.k === p.formPick); if (pick) return pick; }
    let c =YA.AWAKE_FORMS.filter((f) => (f.pos.includes(pos) || f.pos.includes(p.main)) && !done.includes(f.k));
    if (!c.length) c = YA.AWAKE_FORMS.filter((f) => f.pos.includes(p.main) || f.pos.includes(pos));
    return r.weighted(c, (f) => Math.pow(f.abs.reduce((s, a) => s + (p.ab[a] || 6), 0) / f.abs.length, 2) * (YA.formLean ? YA.formLean(p, f) : 1));
  }
  // ---------- 覚醒の図鑑：形20種のうち、あなたの子が目覚めた形（やり込み）----------
  // w.dex[形のk] = { y:年目, name:最初の子, n:回数 }。5・10・20種で育成基金のごほうび
  YA.DEX_REWARD = { 5: 300, 10: 600, 20: 1000 };
  YA.dexCount = (w) => Object.keys(w.dex || {}).length;
  YA.dexAdd = function (w, p, f) {
    const d = (w.dex = w.dex || {});
    if (d[f.k]) { d[f.k].n++; return; }
    d[f.k] = { y: w.year, name: p.name, n: 1 };
    const c = YA.dexCount(w);
    const gift = YA.DEX_REWARD[c];
    if (gift) {
      w.fund = (w.fund || 0) + gift;
      w.fundIn = (w.fundIn || 0) + gift;
      if (YA.noteTier) YA.noteTier(w, 1, `覚醒の図鑑が${c}種になりました。育成基金に${gift}万円が届きました`);
    } else if (YA.noteTier) YA.noteTier(w, 2, `覚醒の図鑑に「${f.name}」が載りました（${c}/${YA.AWAKE_FORMS.length}）`);
  };
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
    p.awake = { y: w.year, w: w.week, from, to: YA.rating(p), why: 'kadai', form: f.name, trait: f.trait, n };
    p.state = { k: 'peak', w: 12 };
    p.conf = clamp(p.conf + 15, 0, 100);
    p.hist.unshift({ y: w.year, w: w.week, t: `覚醒した：${f.name}（特性「${f.trait}」・総合力 ${from}→${p.awake.to}）` });
    w.awakeN = { y: w.year, n: (w.awakeN && w.awakeN.y === w.year ? w.awakeN.n : 0) + 1 };
    YA.dexAdd(w, p, f);
    YA.addTr(w, p, 10);
    w.forced = (w.forced || []).concat([{ id: 'awake', pid: p.id, week: w.week, year: w.year }]);
    return p;
  };
  YA.EVENT_ABOUT = YA.EVENT_ABOUT || {};
  YA.EVENT_ABOUT.awake = '課題に取り組んでいた子が、試合の中で気づきました。形に合った能力がまとめて上がり、覚醒でしか手に入らない特性が付きます。';
  const ev = YA.EVENTS.find((e) => e.id === 'awake');
  if (ev) ev.text = (p) => {
    const a = p.awake || {};
    return `${p.name}（高${p.grade}・${YA.POS_NAME15 ? YA.POS_NAME15[p.main] || p.main : p.main}）が覚醒した――${a.form || ''}。${a.from === a.to ? `総合力 ${a.to}（数字は変わらないが、特性の効きが増す）` : `総合力 ${a.from}→${a.to}`}。覚醒の特性「${a.trait || ''}」が付いた。${(p.awDone || 0) < (p.awN || 1) ? 'まだ先がありそうだ' : ''}`;
  };

  // ---------- 節目の会話（決定109）：課題中の子に、節目ごとに来る ----------
  // 課題中の子の、この一年の伸び（年度はじめの総合力 p.o0 から）
  const termGrow = (p) => {
    if (p.o0 == null) return 'ここまで頑張ってきた';
    const a = YA.rate(p.o0);
    const b = YA.rate(YA.ovr(p));
    return b > a ? `${a}から${b}へ伸びた` : `${b}のまま、土台を固めた`;
  };
  const LINES = {
    star: [
      (p) => `${p.name}を呼んで、初めての課題を伝えた。「えっ、自分ですか……がんばります」`,
      (p) => `${p.name}に、課題を出した。「はい。やってみます」まっすぐこちらを見た`,
      (p) => `${p.name}に課題を伝えた。「……なんで俺なんすか」照れくさそうに目をそらした`,
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
    term: [
      (p, w) => `${p.name}と、この一年を振り返った。総合力は${termGrow(p)}。「来年は、もっと上を目指します」`,
      (p, w) => `年度末、${p.name}が自分から話しかけてきた。「一年で、${termGrow(p)}。自分でも驚いてます」`,
      (p, w) => `${p.name}に、この一年のことを聞いた。${termGrow(p)}。「見てもらえて、よかったです」`,
    ],
    grad: [
      (p) => `卒業式の前の日、${p.name}が来た。「3年間、ありがとうございました。監督に見てもらえて、よかったです」`,
      (p) => `${p.name}が最後の練習のあと、しばらくグラウンドを見ていた。「ここで、全部教わりました」`,
      (p) => `卒業式の前の日。${p.name}は泣かないと決めていたらしいが、最後の練習の礼で声が詰まった。`,
    ],
  };
  const NAMES = { star: '課題：最初の話', debut: '節目：初めての出場', wall: '節目：壁', term: '節目：この一年', grad: '節目：卒業式' };
  function milestone(w, p, kind, x) {
    p.ms = p.ms || {};
    if (kind !== 'hint' && kind !== 'term' && p.ms[kind]) return;
    p.ms[kind] = abs(w);
    w.forced = (w.forced || []).concat([{ id: 'ms', pid: p.id, x: null, ms: kind, key: x && x.key, week: w.week, year: w.year }]);
  }
  YA.milestone = milestone;
  const msOpt = (label, kind, d) => ({ label, kind, extra: (w, p) => { if (d) YA.addTr(w, p, d); } });
  const MS_OPTS = {
    star: [msOpt('「三年間で、必ず化けさせる」と約束する', 'push', 3), msOpt('「焦らず、一緒にやっていこう」と伝える', 'warm', 2), msOpt('「まだ何も決まっていない。結果で見せろ」と突き放す', 'firm')],
    debut: [msOpt('「よくやった」と肩をたたく', 'warm'), msOpt('「ここからが本番だ」と次を求める', 'push'), msOpt('良かった所と課題を一つずつ伝える', 'firm')],
    wall: [msOpt('「必ず越えられる」と信じて待つ', 'warm'), msOpt('一緒に原因を探し、練習を組み直す', 'push'), msOpt('「誰でも通る道だ」とあえて厳しくする', 'firm')],
    term: [msOpt('「この調子で行こう」と次の一年を任せる', 'push', 1), msOpt('伸びを一緒に喜ぶ', 'warm', 1), msOpt('「まだまだ足りない」とあえて締める', 'firm')],
    grad: [msOpt('「お前は、ここからだ」と送り出す', 'push'), msOpt('「三年間、ありがとう」と握手する', 'warm'), msOpt('黙ってうなずく', 'wait')],
  };
  YA.EVENTS.push({ id: 'ms', name: '節目の会話', weight: 0, pick: () => null, text: () => '', opts: MS_OPTS.debut });
  YA.EVENT_ABOUT.ms = '課題に取り組んでいる子との節目の会話です。どう返すかで、その子の信頼（5段階）が動きます。信頼が高いほど本音を話し、手がかりが早く見えます。';
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
    }
    return res1(w, e, idx);
  };
  // 卒業式の前の週（39週）に、課題中の高3と最後の会話。高1・高2の「この一年」は35〜38週に散らす
  //（2026-11-17 直し：前は39週に★の子（いまの課題中の子）全員の会話がまとめて来て、1週に8件ほど重なっていた）
  YA.TERM_WEEKS = [35, 36, 37, 38];
  YA.termWeekOf = (w, p) => YA.TERM_WEEKS[YA.hash(String(p.id) + w.year) % YA.TERM_WEEKS.length];
  YA.gradTalks = function (w) {
    for (const p of Object.values(w.players)) {
      if (!p.star) continue;
      if (p.grade === 3 && w.week === YA.WEEKS - 1) milestone(w, p, 'grad');
      else if (p.grade < 3) {
        // 同じ週に重ならないよう、その週の「この一年」は2人まで（あふれた子は次の週へ）
        const due = YA.termWeekOf(w, p);
        if (w.week < due || w.week > YA.WEEKS - 1 || (p.ms && p.ms.termY === w.year)) continue;
        const n = (w.forced || []).filter((f) => f.id === 'ms' && f.ms === 'term').length;
        if (n >= 2 && w.week < YA.WEEKS - 1) continue;
        p.ms = p.ms || {};
        p.ms.termY = w.year;
        milestone(w, p, 'term');
      }
    }
  };
  // 年度はじめの総合力を控える（この一年の伸びを、年度末の会話で見せるため）
  const ys0 = YA.yearStart;
  YA.yearStart = function (w) {
    const r = ys0.apply(this, arguments);
    for (const p of Object.values(w.players)) p.o0 = Math.round(YA.ovr(p) * 10) / 10;
    return r;
  };
  const aw0 = YA.awakeWeek;
  YA.awakeWeek = function (w) {
    YA.gradTalks(w);
    return aw0(w);
  };

  // おまかせ進行では、コーチのおすすめどおりに課題を出す（暦の判断と同じ扱い）
  const autoScout0 = YA.autoScout;
  if (autoScout0) YA.autoScout = function (w) {
    if (YA.autoKadai) YA.autoKadai(w);
    return autoScout0(w);
  };
  YA.EXTRA_SIM_IMPORTANT = ['ms'];
})();
