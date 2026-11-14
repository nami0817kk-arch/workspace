// 中身の厚み 3段目：スタッフを「人」にする。性格12・出身6・得意13・監督との関係（5段）・年ごとの成長、
// 出来事30種（週に1回まで・約1割）、よくある出来事で担当のコーチが意見を言う（聞くと関係が深まり、退け続けると辞める）。
(function () {
  'use strict';
  const YA = (globalThis.YA = globalThis.YA || {});
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const all = (w) => Object.values(w.players);
  const conf = (p, d) => { if (p) p.conf = clamp((p.conf || 50) + d, 0, 100); };
  const sur = (n) => String(n).split(' ')[0];

  YA.STAFF_PERS = {
    厳格: { kind: 'firm', mult: 1.06, note: '伸びは大きいが、繊細な子は自信を落とす', say: '甘やかすと伸びません' },
    情熱: { kind: 'push', mult: 1.02, note: '試合前にチームを乗せる', say: '気持ちで負けたら終わりです' },
    理論派: { kind: 'push', mult: 1.03, note: '戦術が浸透しやすい', say: '数字を見れば答えは出ています' },
    面倒見: { kind: 'warm', mult: 0.98, note: '子の不満が溜まりにくい', say: 'まず話を聞いてやりましょう' },
    職人: { kind: 'wait', mult: 1.05, note: '担当の能力を深く伸ばす', say: '黙って続けさせれば、身につきます' },
    ムードメーカー: { kind: 'warm', mult: 1.0, note: 'チームの空気が明るい', say: '笑ってりゃ何とかなりますよ' },
    野心家: { kind: 'push', mult: 1.05, note: '腕は良いが、引き抜かれやすい', say: '勝つためなら、使うべきです' },
    古株: { kind: 'wait', mult: 1.0, note: 'クラブ愛が強く、辞めにくい', say: 'このクラブのやり方で行きましょう' },
    寡黙: { kind: 'wait', mult: 1.03, note: '口は出さないが、結果で語る', say: '……任せてください' },
    頑固: { kind: 'firm', mult: 1.02, note: '練習法を変えない。合う子には強い', say: '昔から、こうと決まっています' },
    新人: { kind: 'warm', mult: 0.95, note: '今は弱いが、年ごとに伸びる', say: 'あの、僕なら……' },
    元代表: { kind: 'push', mult: 1.03, note: '名前だけで子が憧れる', say: '世界はもっと厳しいですよ' },
  };
  YA.STAFF_ORIGIN = ['元プロ', '大学の研究者', '高校の先生', '海外帰り', 'クラブの元職員', '一般企業から転職'];
  YA.STAFF_SPEC = ['若手', '守備', '攻撃', 'GK', '心の面', '怪我の予防', 'セットプレー', 'データ', '走り', '体の測定', '心のケア', '栄養', '映像の分析'];
  const PK = Object.keys(YA.STAFF_PERS);
  // 足りない属性を名前から決める（古いセーブ・市場の候補にも）
  YA.staffInfo = function (s) {
    if (!s) return s;
    if (!s.pers) s.pers = s.ob ? '古株' : PK[YA.hash(s.name + s.role + 'p') % PK.length];
    if (!s.origin) s.origin = s.ob ? '元プロ' : YA.STAFF_ORIGIN[YA.hash(s.name + 'o') % YA.STAFF_ORIGIN.length];
    if (!s.spec) s.spec = s.role === 'GKコーチ' ? 'GK' : YA.STAFF_SPEC[YA.hash(s.name + 'sp') % YA.STAFF_SPEC.length];
    if (s.rel == null) s.rel = s.ob ? 70 : 50;
    if (s.yrs == null) s.yrs = 0;
    return s;
  };
  YA.staffRelLv = (s) => 1 + Math.min(4, Math.floor(clamp(s.rel == null ? 50 : s.rel, 0, 100) / 20));
  YA.STAFF_REL_NAME = ['', '冷えきっている', 'ぎこちない', 'ふつう', '信頼している', '右腕'];
  YA.staffLine = (s) => { YA.staffInfo(s); return `${s.pers}・${s.origin}・得意は${s.spec}／監督との関係：${YA.STAFF_REL_NAME[YA.staffRelLv(s)]}`; };
  const addRel = (s, d) => { s.rel = clamp((s.rel == null ? 50 : s.rel) + d, 0, 100); };
  const staffOf = (w) => ((w.club && w.club.staff) || []).map(YA.staffInfo);
  // 伸びに性格が効く
  const sm0 = YA.staffMult;
  if (sm0) YA.staffMult = function (w, p, a) {
    const m = sm0.apply(this, arguments);
    if (m === 1) return m;
    const role = YA.AB_GK && YA.AB_GK.indexOf(a) >= 0 ? 'GKコーチ' : YA.AB_TECH && YA.AB_TECH.indexOf(a) >= 0 ? '技術コーチ' : YA.AB_MENTAL && YA.AB_MENTAL.indexOf(a) >= 0 ? '戦術コーチ' : '体コーチ';
    const s = staffOf(w).find((x) => x.role === role);
    const pm = s ? (YA.STAFF_PERS[s.pers] || {}).mult || 1 : 1;
    return m * pm * (s && s.away > 0 ? 0.92 : 1);
  };

  // ---------- 担当のコーチの意見 ----------
  const OPINION = { injury: 'トレーナー', tired: 'トレーナー', lowconf: '戦術コーチ', unrest: '技術コーチ', quit: '戦術コーチ', rival: '技術コーチ', family: '戦術コーチ', homesick: '体コーチ', hot: '技術コーチ', rivalry: '技術コーチ', parent: '戦術コーチ' };
  YA.staffOpinion = function (w, e) {
    const role = OPINION[e.id];
    if (!role || !w.club) return null;
    const s = staffOf(w).find((x) => x.role === role && !(x.away > 0));
    if (!s) return null;
    const def = YA.EVENTS.find((x) => x.id === e.id);
    if (!def || !def.opts) return null;
    const want = (YA.STAFF_PERS[s.pers] || {}).kind;
    let idx = def.opts.findIndex((o) => o.kind === want);
    if (idx < 0) idx = YA.hash(s.name + e.id) % def.opts.length;
    return { s, idx };
  };
  const v0 = YA.eventView;
  YA.eventView = function (w, e) {
    const v = v0.apply(this, arguments);
    if (!v) return v;
    const op = YA.staffOpinion(w, e);
    if (op && v.opts[op.idx]) { v.text += ` ${op.s.role}の${sur(op.s.name)}：「${YA.STAFF_PERS[op.s.pers].say}。私なら『${v.opts[op.idx]}』です」`; v.staffRec = op.idx; }
    return v;
  };
  const r0 = YA.resolveEvent;
  YA.resolveEvent = function (w, e, idx) {
    const op = YA.staffOpinion(w, e);
    const out = r0.apply(this, arguments);
    if (op) {
      addRel(op.s, op.idx === idx ? 5 : -4);
      if (out && op.idx !== idx && YA.staffRelLv(op.s) <= 2) out.small = (out.small ? out.small + '・' : '') + `${sur(op.s.name)}は不満そうだ`;
    }
    return out;
  };

  // ---------- 入れ替え（辞める・独立する）----------
  const NAMES = ['久保 誠', '梅田 健二', '岩崎 浩', '大石 裕二', '平野 哲也', '谷口 博之', '千葉 賢', '菅原 隆', '野村 正樹', '松井 修'];
  YA.staffLeave = function (w, s, why) {
    const c = w.club;
    const i = c.staff.indexOf(s);
    if (i < 0) return null;
    const m = (w.market || []).find((x) => x.role === s.role);
    const n = m ? Object.assign({}, m) : { id: 's' + YA.hash(s.id + w.year), name: NAMES[YA.hash(s.name + w.year) % NAMES.length], role: s.role, ab: Math.max(5, s.ab - 3), salary: YA.salaryOf(Math.max(5, s.ab - 3)) };
    if (m) w.market = w.market.filter((x) => x !== m);
    n.rel = 50; n.yrs = 0;
    YA.staffInfo(n);
    c.staff[i] = n;
    (w.exStaff = w.exStaff || []).push({ name: s.name, role: s.role, y: w.year, why: why || '', pers: s.pers });
    YA.noteTier(w, 1, `${s.role}の${s.name}がクラブを去りました${why ? '（' + why + '）' : ''}。後任は${n.name}です`);
    return n;
  };
  // 年度はじめ：在籍年数・新人の成長・関係が冷えきった人は辞める
  const ys0 = YA.yearStart;
  YA.yearStart = function (w) {
    const r = ys0.apply(this, arguments);
    for (const s of staffOf(w).slice()) {
      s.yrs = (s.yrs || 0) + 1;
      if (s.pers === '新人' && s.ab < 16) { s.ab++; s.salary = YA.salaryOf(s.ab); if (s.yrs >= 3) s.pers = YA.hash(s.name) % 2 ? '情熱' : '理論派'; }
      else if (s.yrs % 3 === 0 && s.ab < 15 && YA.hash(s.name + w.year) % 2 === 0) s.ab++;
      if (YA.staffRelLv(s) <= 1 && s.pers !== '古株') YA.staffLeave(w, s, `「${YA.STAFF_PERS[s.pers].say}」と言い残して`);
    }
    return r;
  };
  // 毎週：性格の効き目（小さく）
  const rw0 = YA.rivalWeek;
  YA.rivalWeek = function (w) {
    const res = rw0 ? rw0.apply(this, arguments) : undefined;
    const key = w.year * 100 + w.week;
    if (w.staffKey === key || !w.club) return res;
    w.staffKey = key;
    for (const s of staffOf(w)) {
      if (s.away > 0) { s.away--; continue; }
      if (s.pers === 'ムードメーカー') for (const p of all(w)) conf(p, 0.2);
      if (s.pers === '面倒見') for (const p of all(w)) p.unrest = Math.max(0, (p.unrest || 0) - 0.05);
      if (s.pers === '厳格') for (const p of all(w)) if (p.pers && Object.values(p.pers).indexOf('繊細') >= 0) conf(p, -0.3);
    }
    YA.staffEventWeek(w);
    return res;
  };

  // ---------- 出来事（30種）----------
  const pick = (w, f) => staffOf(w).filter((s) => !(s.away > 0) && f(s));
  const one = (list, salt) => (list.length ? list[YA.hash(salt) % list.length] : null);
  const run = (label, fn) => ({ label, kind: null, run: (w) => { const r = fn(w) || {}; return { line: r.line || '', small: r.small || '' }; } });
  const SE = [
    { id: 'clash', name: '意見がぶつかる', c: (w) => one(pick(w, (s) => /コーチ/.test(s.role)), w.week + 'cl'), t: (w, s) => `${s.role}の${s.name}が、練習の組み方に異を唱えてきた。「${YA.STAFF_PERS[s.pers].say}」`,
      o: (s) => [run('任せてみる', () => { addRel(s, 8); return { line: `${sur(s.name)}が張り切っている。`, small: '関係が深まった' }; }), run('自分のやり方を通す', () => { addRel(s, -6); return { line: '少し気まずい空気が流れた。', small: '関係が冷えた' }; }), run('二人で間を取る', () => { addRel(s, 3); return { line: '折り合いがついた。' }; })] },
    { id: 'feud', name: 'コーチどうしの対立', c: (w) => { const l = pick(w, (s) => /コーチ/.test(s.role)); return l.length >= 2 ? l[0] : null; }, t: (w, s) => { const b = pick(w, (x) => /コーチ/.test(x.role) && x !== s)[0]; return `${s.name}と${b ? b.name : '別のコーチ'}が、指導の考え方で言い争っている。`; },
      o: (s) => [run(`${sur(s.name)}の側に立つ`, (w) => { addRel(s, 6); const b = pick(w, (x) => /コーチ/.test(x.role) && x !== s)[0]; if (b) addRel(b, -6); return { line: '一方は満足し、一方は黙り込んだ。' }; }), run('二人で話し合わせる', (w) => { for (const x of pick(w, () => true)) addRel(x, 1); return { line: '時間はかかったが、話はまとまった。' }; }), run('放っておく', () => ({ line: 'ぎくしゃくした空気が続いている。' }))] },
    { id: 'recommend', name: 'コーチの推し', c: (w) => (all(w).some((p) => p.team === 'B' && p.grade >= 2) ? one(pick(w, (s) => /コーチ/.test(s.role)), w.week + 'rc') : null), t: (w, s) => { const p = all(w).filter((x) => x.team === 'B').sort((a, b) => YA.ovr(b) - YA.ovr(a))[0]; return `${s.name}が言ってきた。「${p ? p.name : 'Bのあの子'}を、一度Aで使ってみませんか」`; },
      o: (s) => [run('次の試合で使うと約束する', (w) => { const p = all(w).filter((x) => x.team === 'B').sort((a, b) => YA.ovr(b) - YA.ovr(a))[0]; if (p && YA.addPromise) YA.addPromise(w, p, 3, 'Aで使う'); conf(p, 5); addRel(s, 6); return { line: `${sur(s.name)}はうれしそうだ。` }; }), run('まだ早いと見送る', () => { addRel(s, -3); return { line: '「そうですか」と引き下がった。' }; }), run('練習で見てから決める', () => { addRel(s, 1); return { line: '次の練習で見ることにした。' }; })] },
    { id: 'course', name: '研修に行きたい', c: (w) => one(pick(w, (s) => s.ab < 15), w.year + 'cs'), t: (w, s) => `${s.name}が「2週間、海外の研修に行かせてほしい」と言ってきた。`,
      o: (s) => [run('行かせる', () => { s.away = 2; s.ab = Math.min(18, s.ab + 1); addRel(s, 8); return { line: `${sur(s.name)}は研修に出かけた。戻れば腕が上がっているはずだ。`, small: '2週間不在・腕前+1' }; }), run('今は困ると断る', () => { addRel(s, -6); return { line: '残念そうだった。' }; }), run('オフになったらと約束する', () => { addRel(s, 2); return { line: '「約束ですよ」と笑った。' }; })] },
    { id: 'sfamily', name: 'スタッフの家庭の事情', c: (w) => one(pick(w, () => true), w.week + 'sf'), t: (w, s) => `${s.name}が、家庭の事情で少し休みたいと言ってきた。`,
      o: (s) => [run('休ませる', () => { s.away = 2; addRel(s, 8); return { line: '「ありがとうございます」と頭を下げた。', small: '2週間不在' }; }), run('できるだけ来てほしいと頼む', () => { addRel(s, -6); return { line: '無理をして来ている。' }; }), run('仕事を減らす', () => { s.away = 1; addRel(s, 4); return { line: '少し肩の荷が下りたようだ。' }; })] },
    { id: 'indep', name: '独立の相談', c: (w) => one(pick(w, (s) => s.ab >= 14 && (s.yrs || 0) >= 3 && /コーチ/.test(s.role) && s.pers !== '古株'), w.year + 'id'), t: (w, s) => `${s.name}が「よそのクラブから、監督の話をもらっています」と相談に来た。`,
      o: (s) => [run('背中を押して送り出す', (w) => { (w.rivalCoachesEx = w.rivalCoachesEx || []).push({ name: s.name, y: w.year }); YA.staffLeave(w, s, '他クラブの監督に就任'); if (YA.addRep) YA.addRep(w, 1); return { line: `${sur(s.name)}は「次は敵として会いましょう」と笑って去った。` }; }), run('給料を上げて引き止める', () => { s.salary = Math.round(s.salary * 1.25); addRel(s, 3); return { line: '残ってくれることになった。', small: '給料が上がった' }; }), run('本人に決めさせる', (w) => { if (YA.staffRelLv(s) >= 4) { addRel(s, 4); return { line: '「やっぱり、ここでやります」' }; } YA.staffLeave(w, s, '他クラブの監督に就任'); return { line: 'よそへ行くことを選んだ。' }; })] },
    { id: 'report', name: 'コーチからの報告', c: (w) => (all(w).some((p) => (p.bgKnow || 0) < 2) ? one(pick(w, (s) => s.pers === '面倒見' || s.pers === 'ムードメーカー' || YA.staffRelLv(s) >= 4), w.week + 'rp') : null), t: (w, s) => { const p = all(w).find((x) => (x.bgKnow || 0) < 2); return `${s.name}が報告に来た。「${p ? p.name : 'ある子'}から、相談を受けていました」`; },
      o: (s) => [run('詳しく聞く', (w) => { const p = all(w).find((x) => (x.bgKnow || 0) < 2); if (p && YA.bgReveal) YA.bgReveal(w, p, 2); addRel(s, 4); return { line: p ? `${p.name}の事情が分かった：${YA.BG_NAME[YA.bgOf(w, p)]}` : '' }; }), run('本人から聞くまで待つ', () => { addRel(s, 1); return { line: '「それがいいかもしれません」' }; }), run('任せる', () => { addRel(s, 3); return { line: `${sur(s.name)}に任せることにした。` }; })] },
    { id: 'burnout', name: '燃え尽きかけ', c: (w) => one(pick(w, (s) => s.pers === '情熱' || s.pers === '職人' || s.pers === '新人'), w.week + 'bo'), t: (w, s) => `${s.name}が毎晩遅くまで残っている。目の下にくまができている。`,
      o: (s) => [run('今週は休ませる', () => { s.away = 1; addRel(s, 5); return { line: '「すみません」と言いながら、ほっとした顔をした。' }; }), run('仕事を分ける', () => { addRel(s, 3); return { line: '少し顔色が戻った。' }; }), run('本人に任せる', () => { if (YA.hash(s.name) % 3 === 0) { s.away = 3; return { line: `${sur(s.name)}が倒れて、しばらく休むことになった。`, small: '3週間不在' }; } return { line: 'なんとか持ちこたえている。' }; })] },
    { id: 'wedding', name: 'コーチの結婚', c: (w) => one(pick(w, (s) => !s.wed && (s.yrs || 0) >= 1), w.year + 'wd'), t: (w, s) => `${s.name}が結婚することになった。子どもたちが寄せ書きを用意している。`,
      o: (s) => [run('皆で祝う', (w) => { s.wed = 1; addRel(s, 8); for (const p of all(w)) conf(p, 1); return { line: '練習のあと、大きな拍手が起きた。' }; }), run('監督から贈り物をする', () => { s.wed = 1; addRel(s, 6); return { line: '照れくさそうに受け取った。' }; }), run('おめでとうとだけ言う', () => { s.wed = 1; addRel(s, 2); return { line: '「ありがとうございます」' }; })] },
    { id: 'party', name: 'スタッフの親睦会', c: (w) => (w.week % 10 === 5 ? staffOf(w)[0] : null), t: () => `スタッフから「たまには親睦会をやりませんか」と声が上がった。`,
      o: () => [run('開く', (w) => { for (const s of staffOf(w)) addRel(s, 4); return { line: '久しぶりに、皆で笑った。', small: 'スタッフ全員との関係が深まった' }; }), run('練習の振り返り会にする', (w) => { for (const s of staffOf(w)) addRel(s, 1); return { line: '真面目な会になった。' }; }), run('今は忙しいと断る', (w) => { for (const s of staffOf(w)) addRel(s, -2); return { line: '少しがっかりされた。' }; })] },
    { id: 'ambition', name: '監督の座を狙う気配', c: (w) => one(pick(w, (s) => s.pers === '野心家' && s.ab >= 12), w.year + 'am'), t: (w, s) => `クラブの人から耳打ちされた。「${s.name}さん、監督の座を狙っているみたいですよ」`,
      o: (s) => [run('本人と腹を割って話す', () => { addRel(s, 6); return { line: '「いつかは、と思っています。今はあなたの下で学びます」' }; }), run('気にしない', () => ({ line: '何事もなかったように日々が過ぎる。' })), run('距離を置く', () => { addRel(s, -10); return { line: '二人の間に、冷たい空気が流れ始めた。' }; })] },
    { id: 'scandal', name: '不祥事の疑い', c: (w) => (YA.hash('sc' + w.year + w.week) % 5 === 0 ? one(pick(w, () => true), w.week + 'sd') : null), t: (w, s) => `${s.name}について、保護者から苦情の手紙が届いた。「子どもに暴言を吐いていた」とある。`,
      o: (s) => [run('きちんと調べる', (w) => { if (YA.hash(s.name + 'x') % 3 === 0) { YA.staffLeave(w, s, '暴言が事実だった'); return { line: '事実だった。去ってもらうことになった。' }; } addRel(s, 2); return { line: '誤解だと分かった。本人もほっとしている。' }; }), run('かばう', (w) => { addRel(s, 6); if (w.club) w.club.trust = clamp(w.club.trust - 2, 0, 100); return { line: 'クラブの目が少し厳しくなった。' }; }), run('クラブに任せる', () => { addRel(s, -4); return { line: '本人は「見捨てられた」と感じたようだ。' }; })] },
    { id: 'tears', name: '教え子のデビュー', c: (w) => ((w.alumni || []).some((a) => a.status === 'pro' && a.year === w.year - 1) ? one(pick(w, (s) => (s.yrs || 0) >= 2 && /コーチ/.test(s.role)), w.year + 'te') : null), t: (w, s) => { const a = (w.alumni || []).find((x) => x.status === 'pro' && x.year === w.year - 1); return `${a ? a.name : '卒業生'}のプロデビューの中継を見ながら、${s.name}が泣いていた。`; },
      o: (s) => [run('一緒に喜ぶ', (w) => { addRel(s, 6); for (const p of all(w)) conf(p, 1); return { line: 'グラウンドに、いい空気が流れた。' }; }), run('子どもたちにも見せる', (w) => { for (const p of all(w)) conf(p, 2); return { line: '後輩たちの目が輝いた。' }; }), run('そっとしておく', () => { addRel(s, 2); return { line: '' }; })] },
    { id: 'method', name: '新しい練習法', c: (w) => one(pick(w, (s) => (s.pers === '理論派' || s.origin === '大学の研究者' || s.origin === '海外帰り') && /コーチ/.test(s.role)), w.year + 'me'), t: (w, s) => `${s.name}が「海外で流行っている練習法を試したい」と資料を持ってきた。`,
      o: (s) => [run('試す', (w) => { w.method = { y: w.year, by: s.name, ok: YA.hash(s.name + w.year) % 3 !== 0 }; addRel(s, 8); return { line: w.method.ok ? '子どもたちが新鮮そうに取り組んでいる。' : '最初は戸惑いが多いようだ。', small: w.method.ok ? '今年の伸びが少し上がる' : '' }; }), run('一部だけ取り入れる', () => { addRel(s, 3); return { line: '少しずつ試すことにした。' }; }), run('今のやり方を続ける', () => { addRel(s, -5); return { line: '残念そうに資料をしまった。' }; })] },
    { id: 'oldstory', name: '昔話', c: (w) => one(pick(w, (s) => s.origin === '元プロ' || s.pers === '元代表'), w.year + 'os'), t: (w, s) => `${s.name}が、子どもたちに現役時代の話をしてほしいと頼まれている。`,
      o: (s) => [run('話してもらう', (w) => { for (const p of all(w)) conf(p, 2); addRel(s, 4); return { line: '子どもたちが身を乗り出して聞いていた。' }; }), run('失敗した話を頼む', (w) => { for (const p of all(w)) if ((p.conf || 50) < 45) conf(p, 5); addRel(s, 3); return { line: '自信をなくしていた子が、何度もうなずいていた。' }; }), run('練習を優先する', () => ({ line: '' }))] },
    { id: 'license', name: '資格の勉強', c: (w) => one(pick(w, (s) => s.ab < 16 && /コーチ/.test(s.role)), w.year + 'lc'), t: (w, s) => `${s.name}が、上の指導者資格を取るために勉強している。講習の費用がかかる。`,
      o: (s) => [run('クラブで費用を出す', (w) => { s.ab = Math.min(18, s.ab + 1); s.salary = YA.salaryOf(s.ab); addRel(s, 6); return { line: '資格を取った。', small: '腕前+1・給料が上がった' }; }), run('自費で頑張れと言う', () => { addRel(s, -2); if (YA.hash(s.name + 'l') % 2) s.ab = Math.min(18, s.ab + 1); return { line: '時間はかかったが、取ったらしい。' }; }), run('今は現場に集中してほしいと頼む', () => { addRel(s, -4); return { line: '' }; })] },
    { id: 'shurt', name: 'コーチの怪我', c: (w) => one(pick(w, (s) => s.role === '体コーチ' || s.role === '技術コーチ'), w.week + 'sh'), t: (w, s) => `${s.name}が、デモンストレーション中に足を痛めた。`,
      o: (s) => [run('しっかり治させる', () => { s.away = 2; addRel(s, 4); return { line: '', small: '2週間不在' }; }), run('座ったまま指導してもらう', () => { addRel(s, 1); return { line: '椅子から声を張り上げている。' }; }), run('子どもたちに見本を任せる', (w) => { for (const p of all(w).filter((x) => x.grade === 3)) conf(p, 2); return { line: '高3が張り切って見本を見せた。' }; })] },
    { id: 'baby', name: '子どもが生まれた', c: (w) => one(pick(w, (s) => s.wed && !s.baby), w.year + 'bb'), t: (w, s) => `${s.name}に子どもが生まれた。`,
      o: (s) => [run('しばらく休ませる', () => { s.baby = 1; s.away = 1; addRel(s, 8); return { line: '写真を見せて回っている。' }; }), run('皆で祝う', (w) => { s.baby = 1; addRel(s, 5); for (const p of all(w)) conf(p, 1); return { line: '' }; }), run('おめでとうと伝える', () => { s.baby = 1; addRel(s, 2); return { line: '' }; })] },
    { id: 'carer', name: '親の介護', c: (w) => one(pick(w, (s) => (s.yrs || 0) >= 4 && s.pers !== '新人'), w.year + 'ca'), t: (w, s) => `${s.name}が「親の介護で、続けるのが難しくなりそうです」と打ち明けた。`,
      o: (s) => [run('しばらく休んで戻れるようにする', () => { s.away = 4; addRel(s, 10); return { line: '「戻ってきます」と言って、帰っていった。', small: '4週間不在' }; }), run('送り出す', (w) => { YA.staffLeave(w, s, '親の介護のため'); return { line: '「お世話になりました」' }; }), run('通える形を一緒に考える', () => { addRel(s, 6); return { line: '週に何日かだけ来ることになった。' }; })] },
    { id: 'mediate', name: '間を取り持つ', c: (w) => (all(w).some((p) => (p.unrest || 0) >= 3) ? one(pick(w, (s) => s.pers === '面倒見' || s.pers === 'ムードメーカー'), w.week + 'md') : null), t: (w, s) => { const p = all(w).filter((x) => (x.unrest || 0) >= 3)[0]; return `${s.name}が「${p.name}と監督の間に、私が入りましょうか」と言ってきた。`; },
      o: (s) => [run('頼む', (w) => { const p = all(w).filter((x) => (x.unrest || 0) >= 3)[0]; if (p) p.unrest = Math.max(0, p.unrest - 2); addRel(s, 5); return { line: '少し空気がやわらいだ。' }; }), run('自分で話す', () => ({ line: '「分かりました」と引いた。' })), run('放っておく', () => { addRel(s, -2); return { line: '' }; })] },
    { id: 'defend', name: '同僚をかばう', c: (w) => (staffOf(w).some((s) => YA.staffRelLv(s) <= 2) ? one(pick(w, (s) => YA.staffRelLv(s) >= 4), w.week + 'df') : null), t: (w, s) => { const b = staffOf(w).find((x) => YA.staffRelLv(x) <= 2); return `${s.name}が「${b ? b.name : 'あの人'}は、悪い人じゃないんです」とかばいに来た。`; },
      o: (s) => [run('話を聞いて、関係を立て直す', (w) => { const b = staffOf(w).find((x) => YA.staffRelLv(x) <= 2); if (b) addRel(b, 10); addRel(s, 3); return { line: '二人で食事に行くことにした。' }; }), run('考えておくと言う', () => ({ line: '' })), run('口を出すなと言う', () => { addRel(s, -6); return { line: '' }; })] },
    { id: 'propose', name: 'クラブへの提言', c: (w) => one(pick(w, (s) => s.pers === '理論派' || s.pers === '野心家' || s.pers === '古株'), w.year + 'pp'), t: (w, s) => `${s.name}が、クラブに出す提言書を書いた。「育成の予算を増やすべきです」`,
      o: (s) => [run('連名で出す', (w) => { addRel(s, 6); if (w.club) w.club.trust = clamp(w.club.trust + (YA.hash(s.name + w.year) % 2 ? 2 : -2), 0, 100); return { line: 'クラブの反応は、半々だった。' }; }), run('本人の名前で出させる', () => { addRel(s, 2); return { line: '' }; }), run('今は出さないよう頼む', () => { addRel(s, -4); return { line: '' }; })] },
    { id: 'research', name: '研究の発表', c: (w) => one(pick(w, (s) => s.origin === '大学の研究者' || s.spec === 'データ' || s.spec === '映像の分析'), w.year + 'rs'), t: (w, s) => `${s.name}が、うちの練習のデータを学会で発表したいと言ってきた。`,
      o: (s) => [run('発表させる', (w) => { if (YA.addRep) YA.addRep(w, 2); addRel(s, 6); return { line: '発表は評判になった。', small: '評判+2' }; }), run('名前を伏せて発表させる', () => { addRel(s, 2); return { line: '' }; }), run('手の内は見せないと断る', () => { addRel(s, -5); return { line: '' }; })] },
    { id: 'nickname', name: 'あだ名', c: (w) => one(pick(w, (s) => s.pers === 'ムードメーカー' || s.pers === '情熱'), w.week + 'nn'), t: (w, s) => { const p = all(w).find((x) => x.grade === 1); return `${s.name}が、高1の${p ? p.name : '子'}にあだ名を付けた。チームに一気に広まっている。`; },
      o: (s) => [run('笑って見守る', (w) => { for (const p of all(w).filter((x) => x.grade === 1)) conf(p, 2); return { line: '' }; }), run('本人が嫌がっていないか確かめる', () => { addRel(s, 1); return { line: '本人もまんざらでもないらしい。' }; }), run('やめさせる', () => { addRel(s, -4); return { line: '' }; })] },
    { id: 'oldpupil', name: '昔の教え子', c: (w) => one(pick(w, (s) => s.origin === '高校の先生' || (s.yrs || 0) >= 5), w.year + 'op'), t: (w, s) => `${s.name}の昔の教え子が、練習場に挨拶に来た。今は小学校の先生をしているらしい。`,
      o: (s) => [run('子どもたちの前で話してもらう', (w) => { for (const p of all(w)) conf(p, 1); addRel(s, 4); return { line: '' }; }), run('二人の時間を作る', () => { addRel(s, 5); return { line: `${sur(s.name)}が、珍しく照れていた。` }; }), run('挨拶だけで帰ってもらう', () => ({ line: '' }))] },
    { id: 'teinen', name: '定年', c: (w) => one(pick(w, (s) => (s.yrs || 0) >= 10), w.year + 'tn'), t: (w, s) => `${s.name}が、今年度かぎりで退くと言ってきた。${s.yrs}年、このクラブにいた。`,
      o: (s) => [run('引退式を開く', (w) => { for (const p of all(w)) conf(p, 3); YA.staffLeave(w, s, `${s.yrs}年の勤めを終えて`); return { line: '卒業生たちも駆けつけた。' }; }), run('相談役として残ってもらう', () => { s.pers = '古株'; addRel(s, 6); return { line: '「まだまだ口を出しますよ」' }; }), run('静かに送り出す', (w) => { YA.staffLeave(w, s, '定年'); return { line: '' }; })] },
    { id: 'scoutfind', name: 'スカウトの掘り出し', c: (w) => (YA.scoutWindow && w.scouting ? one(pick(w, (s) => s.role === 'スカウト'), w.week + 'sf2') : null), t: (w, s) => `スカウトの${s.name}が「名前の知られていない中学に、面白い子がいます」と言ってきた。`,
      o: (s) => [run('一緒に見に行く', (w) => { if (YA._genCand && w.scouting) { const r = YA.rngOf(YA.hash(s.name) + w.year * 3 + w.week); const c = YA._genCand(w, r, 'scout', null); c.seen = Math.max(c.seen, 2); c.byStaff = s.name; } addRel(s, 6); return { line: '候補が一人増えた。', small: 'スカウトの候補に入った' }; }), run('任せる', () => { addRel(s, 3); return { line: '' }; }), run('今は他を当たると言う', () => { addRel(s, -3); return { line: '' }; })] },
    { id: 'trainerwarn', name: 'トレーナーの警告', c: (w) => (all(w).some((p) => (p.fat || 0) >= 70) ? one(pick(w, (s) => s.role === 'トレーナー'), w.week + 'tw') : null), t: (w, s) => { const n = all(w).filter((p) => (p.fat || 0) >= 70).length; return `トレーナーの${s.name}が言ってきた。「疲れが溜まった子が${n}人います。練習を落としましょう」`; },
      o: (s) => [run('今週は軽めにする', (w) => { for (const p of all(w)) p.fat = clamp((p.fat || 0) - 8, 0, 100); addRel(s, 6); return { line: '', small: '全員の疲れ −8' }; }), run('試合が近いので続ける', () => { addRel(s, -5); return { line: '「怪我人が出ても知りませんよ」' }; }), run('疲れた子だけ休ませる', (w) => { for (const p of all(w)) if ((p.fat || 0) >= 70) p.rest = 'rest'; addRel(s, 4); return { line: '' }; })] },
    { id: 'analyst', name: '分析の提案', c: (w) => one(pick(w, (s) => s.role === '分析'), w.week + 'an'), t: (w, s) => `分析の${s.name}が「次の相手の弱点が見えました」と資料を持ってきた。`,
      o: (s) => [run('戦い方に取り入れる', (w) => { for (const p of all(w).filter((x) => x.team === 'A')) conf(p, 2); addRel(s, 6); return { line: '準備に手応えを感じている。', small: 'Aの自信 +2' }; }), run('選手にも見せる', (w) => { for (const p of all(w).filter((x) => x.team === 'A')) p.prog = Object.assign(p.prog || {}, { 判断: ((p.prog || {}).判断 || 0) + 0.1 }); addRel(s, 4); return { line: '' }; }), run('自分たちのサッカーをすると言う', () => { addRel(s, -4); return { line: '' }; })] },
    { id: 'gkcoach', name: 'GKコーチの居残り', c: (w) => one(pick(w, (s) => s.role === 'GKコーチ'), w.week + 'gk'), t: (w, s) => `GKコーチの${s.name}が、控えのGKと日が暮れるまで居残りをしている。`,
      o: (s) => [run('明かりを点けて付き合う', (w) => { for (const p of all(w).filter((x) => x.pos === 'GK')) { p.prog = p.prog || {}; p.prog.反応 = (p.prog.反応 || 0) + 0.3; } addRel(s, 5); return { line: '' }; }), run('ほどほどにと言う', () => ({ line: '' })), run('帰らせる', () => { addRel(s, -3); return { line: '' }; })] },
  ];
  YA.STAFF_EVENTS = SE.map((x) => x.id);
  YA.EVENTS.push({ id: 'staffev', name: 'スタッフの出来事', weight: 0, pick: () => null, text: () => '', opts: [] });
  YA.EVENT_ABOUT = YA.EVENT_ABOUT || {};
  YA.EVENT_ABOUT.staffev = 'スタッフも一人ひとりの人です。どう向き合うかで監督との関係が動き、関係が冷えきると辞めてしまいます。関係が深いと、意見がよく当たり、引き抜きも断ってくれます。';
  function sprep(w, e) {
    const d = SE.find((x) => x.id === e.sk);
    const s = staffOf(w).find((x) => x.id === e.sid);
    const def = YA.EVENTS.find((x) => x.id === 'staffev');
    if (!d || !s || !def) return false;
    let body = '';
    try { body = d.t(w, s); } catch (er) { return false; } // 出す前に状況が変わった（不満の子がもういない等）なら出さない
    def.name = d.name;
    def.text = () => `${body}（${s.role}・${s.pers}／関係：${YA.STAFF_REL_NAME[YA.staffRelLv(s)]}）`;
    def.opts = d.o(s);
    return true;
  }
  const v1 = YA.eventView;
  YA.eventView = function (w, e) { if (e.id === 'staffev' && !sprep(w, e)) return null; return v1.apply(this, arguments); };
  const r1 = YA.resolveEvent;
  YA.resolveEvent = function (w, e, idx) { if (e.id === 'staffev') sprep(w, e); return r1.apply(this, arguments); };
  YA.staffEventWeek = function (w) {
    if (!w.club || w.week >= YA.WEEKS - 1) return;
    const r = YA.rngOf((w.seed | 0) * 53 + w.year * 40 + w.week);
    if (!r.chance(0.1)) return;
    const recent = w.staffEvRecent || [];
    const order = SE.slice().sort((a, b) => (YA.hash(a.id + w.year + w.week) % 101) - (YA.hash(b.id + w.year + w.week) % 101));
    for (const d of order) {
      if (recent.indexOf(d.id) >= 0) continue;
      let s = null;
      try { s = d.c(w); } catch (er) { s = null; }
      if (!s) continue;
      w.staffEvRecent = recent.concat([d.id]).slice(-8);
      w.forced = (w.forced || []).concat([{ id: 'staffev', sk: d.id, sid: s.id, pid: null, x: null, week: w.week, year: w.year }]);
      return d.id;
    }
  };
  // 新しい練習法：うまく合えば今年の伸びが少し上がる
  const sm1 = YA.staffMult;
  if (sm1) YA.staffMult = function (w, p, a) { const m = sm1.apply(this, arguments); return w.method && w.method.y === w.year && w.method.ok ? m * 1.03 : m; };
})();
