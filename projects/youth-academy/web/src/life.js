// 中身の厚み 6段目：指導の方針（6つの軸）と「流儀」、監督自身・保護者・地域・お金・メディア・規律・トップ・世代・偶然の出来事。
(function () {
  'use strict';
  const YA = (globalThis.YA = globalThis.YA || {});
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const all = (w) => Object.values(w.players);
  const A = (w) => all(w).filter((p) => p.team === 'A');
  const conf = (p, d) => { if (p) p.conf = clamp((p.conf || 50) + d, 0, 100); };
  const run = (label, fn) => ({ label, kind: null, run: (w) => { const r = fn(w) || {}; return { line: r.line || '', small: r.small || '' }; } });
  const rep = (w, d) => { if (YA.addRep) YA.addRep(w, d); };
  const trust = (w, d) => { if (w.club) w.club.trust = clamp(w.club.trust + d, 0, 100); };
  const disc = (w, d) => { w.disc = clamp((w.disc || 60) + d, 0, 100); };

  // ---------- 方針 ----------
  YA.POLICY_AXES = [['aim', '目的', '勝つ', '育てる'], ['play', '戦い方', '攻撃', '守備'], ['ctrl', '管理', '管理', '自主性'], ['tone', '接し方', '厳しさ', '寄り添い'], ['use', '起用', '若手', '上級生'], ['grow', '伸ばすもの', '技術', '体']];
  YA.policyOf = function (w) {
    if (!w.policy) { w.policy = {}; for (const [k] of YA.POLICY_AXES) w.policy[k] = YA.hash(String(w.seed) + k) % 2; }
    return w.policy;
  };
  YA.policyOpen = (w) => w.week <= 4;
  YA.setCoachPolicy = function (w, k, v) {
    if (!YA.policyOpen(w)) return { ok: false, msg: '方針を変えられるのは年度はじめ（4週まで）です' };
    YA.policyOf(w)[k] = v ? 1 : 0;
    return { ok: true, msg: '方針を変えました' };
  };
  YA.policyText = (w) => YA.POLICY_AXES.map(([k, n, a, b]) => (YA.policyOf(w)[k] ? b : a)).join('・');
  // 流儀：長く貫いた方針（年度はじめに控える）
  YA.styleOf = function (w) {
    const log = w.styleLog || [];
    if (log.length < 3) return null;
    const out = [];
    for (const [k, n, a, b] of YA.POLICY_AXES) {
      const c1 = log.filter((x) => x[k]).length;
      if (c1 / log.length >= 0.75) out.push(b); else if (c1 / log.length <= 0.25) out.push(a);
    }
    return out.length >= 2 ? out.join('・') : null;
  };
  const ys0 = YA.yearStart;
  YA.yearStart = function (w) {
    const r = ys0.apply(this, arguments);
    const pol = YA.policyOf(w);
    if (w.year > 1) w.styleLog = (w.styleLog || []).concat([Object.assign({ y: w.year - 1 }, pol)]).slice(-20);
    w.policyDev = 0; w.policyWarned = false;
    const st = YA.styleOf(w);
    if (st && w.styleSaid !== st) { w.styleSaid = st; YA.noteTier(w, 2, `周りから「${w.coachName}監督の流儀は、${st}だ」と言われるようになった`); }
    return r;
  };
  // 方針の効き目（小さく）
  const rw0 = YA.rivalWeek;
  YA.rivalWeek = function (w) {
    const res = rw0 ? rw0.apply(this, arguments) : undefined;
    const key = w.year * 100 + w.week;
    if (w.polKey === key) return res;
    w.polKey = key;
    const pol = YA.policyOf(w);
    if (!pol.aim) for (const p of A(w)) conf(p, 0.15);
    if (!pol.ctrl) disc(w, 0.15); else { disc(w, -0.08); for (const p of all(w)) conf(p, 0.05); }
    for (const p of all(w)) if ((pol.use ? p.grade === 3 : p.grade === 1)) conf(p, 0.15);
    YA.lifeEventWeek(w);
    return res;
  };
  const sm0 = YA.staffMult;
  if (sm0) YA.staffMult = function (w, p, a) {
    const m = sm0.apply(this, arguments);
    const pol = YA.policyOf(w);
    let k = pol.aim ? 1.02 : 1;
    const tech = YA.AB_TECH && YA.AB_TECH.indexOf(a) >= 0, phys = YA.AB_PHYS && YA.AB_PHYS.indexOf(a) >= 0;
    if ((!pol.grow && tech) || (pol.grow && phys)) k *= 1.02;
    return m * k;
  };
  // 接し方の方針と食い違う選び方が続くと、チームが戸惑う
  const r0 = YA.resolveEvent;
  YA.resolveEvent = function (w, e, idx) {
    const def = YA.EVENTS.find((x) => x.id === e.id);
    const o = def && def.opts && def.opts[idx];
    const out = r0.apply(this, arguments);
    if (o && (o.kind === 'firm' || o.kind === 'warm')) {
      const want = YA.policyOf(w).tone ? 'warm' : 'firm';
      if (o.kind !== want) {
        w.policyDev = (w.policyDev || 0) + 1;
        if (w.policyDev >= 6 && !w.policyWarned) {
          w.policyWarned = true;
          for (const p of A(w)) conf(p, -2);
          YA.noteTier(w, 1, `方針は「${YA.policyOf(w).tone ? '寄り添い' : '厳しさ'}」なのに、逆の接し方が続いている。子どもたちが戸惑っている（Aの自信 −2）`);
        }
      }
    }
    return out;
  };
  // OBコーチは、監督の流儀を受け継ぐ
  const ob0 = YA.obJoin;
  if (ob0) YA.obJoin = function (w, a, why) {
    const s = ob0.apply(this, arguments);
    if (s) { s.pers = YA.policyOf(w).tone ? '面倒見' : '厳格'; s.style = YA.styleOf(w) || YA.policyText(w); }
    return s;
  };
  // 方針の画面（クラブ → 概要）
  YA.policyCard = function (w) {
    const U = YA._ui;
    if (!U) return null;
    const h = U.h;
    const pol = YA.policyOf(w);
    const open = YA.policyOpen(w);
    const st = YA.styleOf(w);
    return h('div', { class: 'card', style: 'padding:9px 11px;margin-bottom:6px' },
      h('div', { class: 'h' }, '指導の方針'),
      h('div', { class: 'note' }, open ? '年度はじめ（4週まで）に決めます。方針と逆の接し方が続くと、子どもたちが戸惑います。' : '方針を変えられるのは、年度はじめ（4週まで）です。'),
      ...YA.POLICY_AXES.map(([k, n, a, b]) => h('div', { class: 'row', style: 'gap:4px;margin-top:3px' }, h('span', { class: 'note', style: 'width:64px' }, n),
        h('button', { class: 'btn sm' + (!pol[k] ? ' on' : ''), disabled: !open, why: '方針を変えられるのは、年度はじめ（4週まで）です', onclick: () => { YA.setCoachPolicy(w, k, 0); YA.saveWorld && YA.saveWorld(); U.render(); } }, a),
        h('button', { class: 'btn sm' + (pol[k] ? ' on' : ''), disabled: !open, why: '方針を変えられるのは、年度はじめ（4週まで）です', onclick: () => { YA.setCoachPolicy(w, k, 1); YA.saveWorld && YA.saveWorld(); U.render(); } }, b))),
      h('div', { class: 'note', style: 'margin-top:4px;color:var(--ink)' }, st ? `あなたの流儀：${st}（指導者になった卒業生が受け継ぎます）` : '3年続けると、あなたの「流儀」が見えてきます'));
  };

  // ---------- 出来事（監督自身・保護者・地域・お金・メディア・規律・トップ・世代・偶然）----------
  const LE = [
    // 監督自身
    { id: 'license', g: '監督', name: '指導者講習会', c: (w) => w.week >= 30 && w.week <= 38, t: () => '上の指導者ライセンスの講習会の案内が来た。2週間、現場を空けることになる。', o: () => [run('受ける', (w) => { if (w.coach) w.coach.tactic = Math.min(20, w.coach.tactic + 1); for (const p of A(w)) conf(p, -1); return { line: '', small: '戦術+1・Aの自信 −1（不在）' }; }), run('来年にする', () => ({ line: '' })), run('スタッフに任せて受ける', (w) => { if (w.coach) w.coach.tactic = Math.min(20, w.coach.tactic + 1); return { line: 'スタッフがしっかり留守を守った。' }; })] },
    { id: 'book', g: '監督', name: '本の依頼', c: (w) => w.year >= 4 && (w.alumni || []).filter((a) => a.status === 'pro').length >= 5, t: () => '出版社から「育成の本を書きませんか」と依頼が来た。', o: () => [run('書く', (w) => { rep(w, 3); return { line: '本は地味に売れた。', small: '評判 +3' }; }), run('卒業生の話を中心に書く', (w) => { rep(w, 2); for (const a of (w.alumni || []).slice(-5)) if (a.bond != null) a.bond = Math.min(6, a.bond + 1); return { line: '卒業生から感想が届いた。' }; }), run('断る', () => ({ line: '' }))] },
    { id: 'gaffe', g: '監督', name: '取材での失言', c: (w) => w.week >= 5 && YA.hash('gf' + w.year) % 3 === 0, t: () => '取材で口を滑らせた。「相手は大したことない」という一言が記事になった。', o: () => [run('すぐに謝る', (w) => { trust(w, -1); return { line: '騒ぎは小さく済んだ。' }; }), run('本音だと言い切る', (w) => { for (const p of A(w)) conf(p, 2); trust(w, -3); return { line: '子どもたちは燃えている。クラブは困っている。' }; }), run('黙っている', (w) => { trust(w, -2); return { line: '' }; })] },
    { id: 'offer', g: '監督', name: '他クラブからの誘い', c: (w) => w.year >= 3 && w.club && w.club.trust >= 60 && w.week === 32, t: () => '他のクラブの関係者から、こっそり「うちに来ませんか」と声をかけられた。', o: () => [run('今のクラブで続けると伝える', (w) => { trust(w, 3); return { line: '話は、どこからか部長の耳にも入ったらしい。' }; }), run('話だけ聞く', () => ({ line: '条件は悪くなかった。' })), run('子どもたちの顔を思い浮かべる', (w) => { for (const p of all(w)) conf(p, 1); return { line: '' }; })] },
    { id: 'origin', g: '監督', name: '経歴の因縁', c: (w) => w.year >= 2 && w.week === 7, t: (w) => w.career === 'pro' || (w.coach && w.coach.exp >= 4) ? '現役時代の古巣のクラブから、試合の後に挨拶に来た人がいた。' : '高校の先生だったころの教え子が、相手チームのコーチになっていた。', o: () => [run('昔話をする', (w) => { rep(w, 1); return { line: '' }; }), run('今は敵だと言う', (w) => { for (const p of A(w)) conf(p, 1); return { line: '' }; }), run('礼を言って別れる', () => ({ line: '' }))] },
    { id: 'health', g: '監督', name: '監督の体調', c: (w) => w.week >= 15 && w.week <= 30 && YA.hash('hl' + w.year) % 3 === 0, t: () => '最近、寝不足が続いている。スタッフが「少し休んでください」と言う。', o: () => [run('1週だけ休む', (w) => { for (const s of (w.club && w.club.staff) || []) if (s.rel != null) s.rel = Math.min(100, s.rel + 3); return { line: 'スタッフが練習を回してくれた。' }; }), run('大丈夫だと続ける', () => ({ line: '' })), run('練習を短くする', (w) => { for (const p of all(w)) p.fat = clamp((p.fat || 0) - 4, 0, 100); return { line: '' }; })] },
    { id: 'familyday', g: '監督', name: '家族の行事', c: (w) => w.week === 11 || w.week === 29, t: () => '家族の大事な行事と、大会の日が重なった。', o: () => [run('大会に行く', () => ({ line: '家族には、あとで謝った。' })), run('家族の行事に行く', (w) => { for (const p of A(w)) conf(p, -1); return { line: 'スタッフがベンチに入った。' }; }), run('どちらにも顔を出す', () => ({ line: '一日中走り回った。' }))] },
    { id: 'bday', g: '監督', name: '寄せ書き', c: (w) => w.week === 20 && all(w).some((p) => (p.tr || 50) >= 70), t: () => '監督の誕生日に、子どもたちから寄せ書きが届いた。', o: () => [run('皆の前で礼を言う', (w) => { for (const p of all(w)) conf(p, 2); return { line: '' }; }), run('一人ずつに礼を言う', (w) => { for (const p of all(w).filter((x) => x.star)) if (YA.addTr) YA.addTr(w, p, 1); return { line: '' }; }), run('照れて何も言えない', () => ({ line: '子どもたちが笑っていた。' }))] },
    // 保護者
    { id: 'pta', g: '保護者', name: '保護者会', c: (w) => w.week === 5, t: () => '年に一度の保護者会。役員を誰にお願いするか決める。', o: () => [run('熱心な保護者に頼む', (w) => { for (const p of all(w).filter((x) => x.bg === 'eager')) conf(p, -2); return { line: '会は活気づいた。' }; }), run('くじで決める', () => ({ line: '' })), run('クラブに任せる', () => ({ line: '' }))] },
    { id: 'sashiire', g: '保護者', name: '差し入れ', c: (w) => w.week >= 13 && w.week <= 18, t: () => '保護者から、練習のあとに冷えたスイカの差し入れが届いた。', o: () => [run('皆で礼を言いに行く', (w) => { for (const p of all(w)) conf(p, 1); return { line: '' }; }), run('寮に運ぶ', () => ({ line: '寮が盛り上がった。' })), run('礼状を書く', () => ({ line: '' }))] },
    { id: 'thanks', g: '保護者', name: '感謝の手紙', c: (w) => w.week === 39, t: () => '卒業する子の保護者から、長い手紙が届いた。', o: () => [run('大事にしまっておく', () => ({ line: '' })), run('スタッフにも読んでもらう', (w) => { for (const s of (w.club && w.club.staff) || []) if (s.rel != null) s.rel = Math.min(100, s.rel + 2); return { line: '' }; }), run('返事を書く', () => ({ line: '' }))] },
    // 地域とファン
    { id: 'shotengai', g: '地域', name: '商店街の応援', c: (w) => w.week === 8, t: () => '商店街に、ユースの選手のポスターが貼られることになった。誰を載せるか聞かれた。', o: () => [run('主将', (w) => { const c = w.captain && w.players[w.captain]; conf(c, 4); return { line: '' }; }), run('地元出身の子', (w) => { rep(w, 1); return { line: '' }; }), run('全員の集合写真', (w) => { for (const p of all(w)) conf(p, 1); return { line: '' }; })] },
    { id: 'oldman', g: '地域', name: '常連のおじいさん', c: (w) => w.week >= 10 && w.year >= 2, t: () => '毎試合来るおじいさんが、今日は来ていない。子どもたちが気にしている。', o: () => [run('様子を聞いてみる', () => ({ line: 'しばらく入院しているらしい。子どもたちが寄せ書きを作った。' })), run('勝って届けようと言う', (w) => { for (const p of A(w)) conf(p, 2); return { line: '' }; }), run('そっとしておく', () => ({ line: '' }))] },
    { id: 'fanletter', g: '地域', name: 'ファンレター', c: (w) => A(w).some((p) => p.st && p.st.goals >= 1), t: () => '小学生から、ユースの選手宛てのファンレターが届いた。', o: () => [run('返事を書かせる', (w) => { for (const p of A(w)) conf(p, 1); return { line: '' }; }), run('ロッカーに貼る', () => ({ line: '' })), run('本人に渡すだけ', () => ({ line: '' }))] },
    { id: 'localjob', g: '地域', name: '地元企業の話', c: (w) => w.week === 36, t: () => '地元の企業から「サッカーを続けながら働ける枠があります」と話が来た。', o: () => [run('高3に紹介する', (w) => { for (const p of all(w).filter((x) => x.grade === 3)) conf(p, 1); return { line: '' }; }), run('進路の選択肢として覚えておく', () => ({ line: '' })), run('断る', () => ({ line: '' }))] },
    // お金
    { id: 'crowdf', g: 'お金', name: 'クラウドファンディング', c: (w) => w.year >= 2 && w.week === 14, t: () => '保護者会から「遠征費をクラウドファンディングで集めませんか」と提案があった。', o: () => [run('やってみる', (w) => { const n = 100 + (w.alumni || []).filter((a) => (a.bond || 0) >= 4).length * 20; w.fund = (w.fund || 0) + n; w.fundIn = (w.fundIn || 0) + n; return { line: `卒業生からの支援も集まった。`, small: `育成基金 +${n}万円` }; }), run('クラブに任せる', () => ({ line: '' })), run('やめておく', () => ({ line: '' }))] },
    { id: 'gear', g: 'お金', name: '用具の支給', c: (w) => w.week === 4, t: () => 'スパイクの支給を、全員同じにするか、選ばせるかで意見が割れている。', o: () => [run('全員同じにする', (w) => disc(w, 2) || { line: '' }), run('選ばせる', (w) => { for (const p of all(w)) conf(p, 1); return { line: '' }; }), run('家庭の事情に合わせる', (w) => { for (const p of all(w).filter((x) => x.bg === 'poor')) conf(p, 4); return { line: '' }; })] },
    { id: 'alumgift', g: 'お金', name: '卒業生の寄付', c: (w) => (w.alumni || []).some((a) => a.status === 'pro' && (a.bond || 0) >= 5 && !a.gave), t: (w) => { const a = (w.alumni || []).find((x) => x.status === 'pro' && (x.bond || 0) >= 5 && !x.gave); return `卒業生の${a.name}から「古巣に恩返しがしたい」と寄付の申し出があった。`; }, o: () => [run('ありがたく受ける', (w) => { const a = (w.alumni || []).find((x) => x.status === 'pro' && (x.bond || 0) >= 5 && !x.gave); if (a) a.gave = w.year; w.fund = (w.fund || 0) + 300; w.fundIn = (w.fundIn || 0) + 300; return { line: '', small: '育成基金 +300万円' }; }), run('ボールとビブスにしてもらう', (w) => { const a = (w.alumni || []).find((x) => x.status === 'pro' && (x.bond || 0) >= 5 && !x.gave); if (a) a.gave = w.year; for (const p of all(w)) conf(p, 2); return { line: '卒業生の名前入りのボールが届いた。' }; }), run('気持ちだけ受け取る', (w) => { const a = (w.alumni || []).find((x) => x.status === 'pro' && (x.bond || 0) >= 5 && !x.gave); if (a) a.gave = w.year; return { line: '' }; })] },
    // メディア
    { id: 'ranking', g: 'メディア', name: 'ユースのランキング', c: (w) => w.week === 23, t: (w) => `サッカー雑誌の「育成クラブランキング」に、${w.clubName}が載った。`, o: () => [run('子どもたちに見せる', (w) => { for (const p of all(w)) conf(p, 2); return { line: '' }; }), run('浮かれるなと言う', (w) => disc(w, 1) || { line: '' }), run('スカウトに使う', (w) => { rep(w, 1); return { line: '' }; })] },
    { id: 'misreport', g: 'メディア', name: '誤報', c: (w) => all(w).some((p) => YA.rate && YA.rate(YA.ovr(p)) >= 120), t: (w) => { const p = all(w).sort((a, b) => YA.ovr(b) - YA.ovr(a))[0]; return `「${p.name}、海外クラブへ移籍か」という誤報が出た。本人は戸惑っている。`; }, o: () => [run('本人と一緒に否定する', (w) => { const p = all(w).sort((a, b) => YA.ovr(b) - YA.ovr(a))[0]; conf(p, 2); return { line: '' }; }), run('放っておく', (w) => { const p = all(w).sort((a, b) => YA.ovr(b) - YA.ovr(a))[0]; p.unrest = (p.unrest || 0) + 1; return { line: '' }; }), run('クラブに対応を頼む', () => ({ line: '' }))] },
    { id: 'documentary', g: 'メディア', name: '密着取材', c: (w) => w.year >= 3 && w.week === 6 && YA.hash('dc' + w.year) % 3 === 0, t: () => 'テレビ局から、1年間の密着取材の申し込みが来た。', o: () => [run('受ける', (w) => { rep(w, 3); for (const p of all(w).filter((x) => x.bg === 'shy')) conf(p, -4); return { line: '', small: '評判 +3' }; }), run('練習の一部だけ受ける', (w) => { rep(w, 1); return { line: '' }; }), run('断る', () => ({ line: '' }))] },
    { id: 'viral', g: 'メディア', name: '動画が広まる', c: (w) => A(w).some((p) => p.st && p.st.goals >= 1), t: () => '練習中のスーパーゴールの動画が、ネットで広まっている。', o: () => [run('喜ぶ', (w) => { rep(w, 1); return { line: '' }; }), run('練習に集中させる', (w) => disc(w, 1) || { line: '' }), run('クラブの宣伝に使う', (w) => { rep(w, 2); trust(w, 1); return { line: '' }; })] },
    // 規律
    { id: 'fairplay', g: '規律', name: 'フェアプレー賞', c: (w) => w.week === 38 && (w.disc || 60) >= 70, t: () => '今年のリーグのフェアプレー賞に選ばれた。', o: () => [run('皆で喜ぶ', (w) => { rep(w, 2); for (const p of all(w)) conf(p, 1); return { line: '' }; }), run('当たり前だと言う', (w) => disc(w, 2) || { line: '' }), run('審判に礼を言いに行く', (w) => { rep(w, 1); return { line: '' }; })] },
    { id: 'regmistake', g: '規律', name: '登録の手違い', c: (w) => w.week === 3 && YA.hash('rg' + w.year) % 4 === 0, t: () => '選手登録の書類に不備が見つかった。今日が締め切りだ。', o: () => [run('徹夜で直す', () => ({ line: 'なんとか間に合った。' })), run('スタッフに任せる', (w) => { const s = (w.club && w.club.staff || [])[0]; if (s && s.rel != null) s.rel = Math.min(100, s.rel + 3); return { line: '' }; }), run('協会に事情を話す', (w) => { trust(w, -1); return { line: '' }; })] },
    { id: 'abuse', g: '規律', name: '暴言の動画', c: (w) => (w.disc || 60) < 50 && w.week >= 8, t: () => '試合中に選手が相手に暴言を吐いた動画が、出回っている。', o: () => [run('本人と一緒に謝罪する', (w) => { disc(w, 4); return { line: '' }; }), run('出場停止にする', (w) => { disc(w, 6); for (const p of A(w)) conf(p, -1); return { line: '' }; }), run('クラブに任せる', (w) => { trust(w, -3); return { line: '' }; })] },
    // トップ
    { id: 'ballboy', g: 'トップ', name: 'ボールボーイ', c: (w) => !!w.top && w.week >= 3 && w.week <= 20, t: () => 'トップの試合のボールボーイを、ユースが務めることになった。', o: () => [run('高1に行かせる', (w) => { for (const p of all(w).filter((x) => x.grade === 1)) conf(p, 2); return { line: 'プロの速さに、目を丸くして帰ってきた。' }; }), run('全員で行く', (w) => { for (const p of all(w)) conf(p, 1); return { line: '' }; }), run('練習を優先する', () => ({ line: '' }))] },
    { id: 'toptalk', g: 'トップ', name: 'トップの選手が教えに来る', c: (w) => !!w.top && w.week >= 30 && w.week <= 38, t: () => 'トップの選手が、オフにユースの練習に顔を出してくれた。', o: () => [run('紅白戦に入ってもらう', (w) => { for (const p of A(w)) { p.prog = p.prog || {}; p.prog.判断 = (p.prog.判断 || 0) + 0.15; } return { line: '' }; }), run('高3と話してもらう', (w) => { for (const p of all(w).filter((x) => x.grade === 3)) conf(p, 2); return { line: '' }; }), run('見学だけ', () => ({ line: '' }))] },
    // 世代
    { id: 'reunion', g: '世代', name: '同窓会', c: (w) => w.year >= 6 && w.week === 37 && w.year % 3 === 0, t: (w) => `${w.year - 5}年目の卒業生から、同窓会に呼ばれた。`, o: () => [run('行く', (w) => { for (const a of (w.alumni || []).filter((x) => x.year === w.year - 5)) if (a.bond != null) a.bond = Math.min(6, a.bond + 1); return { line: '懐かしい顔ぶれだった。' }; }), run('ビデオで挨拶を送る', () => ({ line: '' })), run('練習があると断る', () => ({ line: '' }))] },
    { id: 'meikan', g: '世代', name: '記念誌', c: (w) => w.year === 10 || w.year === 20, t: (w) => `クラブのユースの${w.year}年をまとめた記念誌を作ることになった。`, o: () => [run('卒業生全員に原稿を頼む', (w) => { for (const a of w.alumni || []) if (a.bond != null && a.bond >= 3) a.bond = Math.min(6, a.bond + 1); return { line: '' }; }), run('写真を中心にする', () => ({ line: '' })), run('任せる', () => ({ line: '' }))] },
    { id: 'meimon', g: '世代', name: '名門の称号', c: (w) => (w.alumni || []).filter((a) => a.status === 'pro').length >= 30 && !w.meimon, t: () => '雑誌が、このクラブを「育成の名門」と書いた。', o: () => [run('胸を張る', (w) => { w.meimon = w.year; rep(w, 3); return { line: '', small: '評判 +3' }; }), run('まだまだだと言う', (w) => { w.meimon = w.year; disc(w, 2); return { line: '' }; }), run('卒業生のおかげだと言う', (w) => { w.meimon = w.year; for (const a of w.alumni || []) if (a.bond != null) a.bond = Math.min(6, a.bond + 0); return { line: '' }; })] },
    // 偶然と不運
    { id: 'typhoon', g: '偶然', name: '台風', c: (w) => w.week >= 18 && w.week <= 24 && YA.hash('ty' + w.year + w.week) % 4 === 0, t: () => '台風が近づいている。週末の試合をどうするか、相手と相談になった。', o: () => [run('延期を申し出る', () => ({ line: '' })), run('予定どおりやる', (w) => { for (const p of A(w)) p.fat = clamp((p.fat || 0) + 4, 0, 100); return { line: '' }; }), run('協会に任せる', () => ({ line: '' }))] },
    { id: 'blackout', g: '偶然', name: '停電', c: (w) => YA.hash('bo' + w.year + w.week) % 25 === 0, t: () => '夜の練習中に停電した。グラウンドが真っ暗だ。', o: () => [run('走り込みに切り替える', (w) => { for (const p of all(w)) { p.prog = p.prog || {}; p.prog.スタミナ = (p.prog.スタミナ || 0) + 0.1; } return { line: '' }; }), run('ミーティングにする', (w) => { for (const p of A(w)) { p.prog = p.prog || {}; p.prog.判断 = (p.prog.判断 || 0) + 0.1; } return { line: '' }; }), run('解散する', () => ({ line: '' }))] },
    { id: 'busbreak', g: '偶然', name: 'バスの故障', c: (w) => YA.SCHED && YA.SCHED(w.week).t === 'cup' && YA.hash('bb' + w.year + w.week) % 5 === 0, t: () => '遠征のバスが、高速道路で故障した。試合に間に合うか分からない。', o: () => [run('タクシーに分乗する', (w) => { if (w.club) w.club.spent.camp = (w.club.spent.camp || 0) + 20; return { line: '', small: '経費 20万円' }; }), run('相手に事情を話して待ってもらう', () => ({ line: '' })), run('バスの中でミーティングする', (w) => { for (const p of A(w)) conf(p, 1); return { line: '' }; })] },
    { id: 'epidemic', g: '偶然', name: '感染症', c: (w) => w.week >= 31 && w.week <= 36 && YA.hash('ep' + w.year) % 3 === 0, t: () => '感染症で、寮生の何人かが寝込んだ。', o: () => [run('練習を休みにする', (w) => { for (const p of all(w)) p.fat = clamp((p.fat || 0) - 10, 0, 100); return { line: '' }; }), run('元気な子だけで続ける', (w) => { for (const p of all(w).filter((x) => x.dorm !== false)) { if (YA.hash(p.id + w.week) % 4 === 0) p.inj = Math.max(p.inj || 0, 1); } return { line: '' }; }), run('寮を分けて対応する', () => ({ line: '' }))] },
    { id: 'theft', g: '偶然', name: '用具の盗難', c: (w) => YA.hash('th' + w.year + w.week) % 30 === 0, t: () => '倉庫からボールとビブスがなくなった。', o: () => [run('警察に届ける', () => ({ line: '' })), run('子どもたちに鍵の管理を任せる', (w) => disc(w, 2) || { line: '' }), run('予算で買い直す', (w) => { if (w.club) w.club.spent.scout = (w.club.spent.scout || 0) + 10; return { line: '' }; })] },
    { id: 'lost', g: '偶然', name: '遠征先で迷子', c: (w) => YA.SCHED && YA.SCHED(w.week).t === 'camp', t: () => '合宿先で、高1の子が一人、宿に戻ってこない。', o: () => [run('皆で探す', (w) => { for (const p of all(w).filter((x) => x.grade === 1)) conf(p, 1); return { line: '駅前の本屋で見つかった。' }; }), run('スタッフに探させる', () => ({ line: '' })), run('戻ってきたら叱る', (w) => disc(w, 2) || { line: '' })] },
  ];
  YA.LIFE_EVENTS = LE.map((x) => x.id);
  YA.EVENTS.push({ id: 'lifeev', name: '出来事', weight: 0, pick: () => null, text: () => '', opts: [] });
  YA.EVENT_ABOUT = YA.EVENT_ABOUT || {};
  YA.EVENT_ABOUT.lifeev = '監督自身・保護者・地域・お金・メディア・規律・トップ・卒業生の世代・偶然の出来事です。';
  function lprep(w, e) {
    const d = LE.find((x) => x.id === e.lk);
    const def = YA.EVENTS.find((x) => x.id === 'lifeev');
    if (!d || !def) return false;
    let body = '';
    try { body = d.t(w); } catch (er) { return false; }
    def.name = `${d.g}：${d.name}`;
    def.text = () => body;
    def.opts = d.o();
    return true;
  }
  const v0 = YA.eventView;
  YA.eventView = function (w, e) { if (e.id === 'lifeev' && !lprep(w, e)) return null; return v0.apply(this, arguments); };
  const r1 = YA.resolveEvent;
  YA.resolveEvent = function (w, e, idx) { if (e.id === 'lifeev') lprep(w, e); return r1.apply(this, arguments); };
  YA.LIFE_EV_P = 0.05;
  YA.lifeEventWeek = function (w) {
    if (!w.club || w.week >= YA.WEEKS) return;
    const r = YA.rngOf((w.seed | 0) * 67 + w.year * 40 + w.week);
    w.lifeDone = w.lifeDone && w.lifeDone.y === w.year ? w.lifeDone : { y: w.year, ids: [] };
    if (!r.chance(YA.LIFE_EV_P)) return; // 2026-11-15「★以外のイベントが多発する」で 0.18→0.05
    const cands = LE.filter((d) => w.lifeDone.ids.indexOf(d.id) < 0 && (() => { try { return !!d.c(w); } catch (er) { return false; } })());
    if (!cands.length) return;
    const d = cands[r.int(0, cands.length - 1)];
    w.lifeDone.ids.push(d.id);
    w.forced = (w.forced || []).concat([{ id: 'lifeev', lk: d.id, pid: null, x: null, week: w.week, year: w.year }]);
  };
})();
