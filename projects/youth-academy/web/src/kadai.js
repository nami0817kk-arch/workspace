// 課題（2026-11-26 ユーザーと会話で確定。仕様「★をやめて全員を見る・課題の仕組み」）
// ★注目と覚醒の鍵をやめ、指導者が子の武器と弱点を見抜いて課題を出す → 苦しむ → 試合の一場面で気づいて化ける、にした。
// ・一人ひとりに「合う課題」（種類と中身）が隠れている（入団のときに、選手ごとの乱数で決まる。p.kf）
// ・手がかりは3つ（コーチの見立て・本人の言葉・試合の場面。p.kc）。答えは画面に出さない
// ・課題を出せるのは同時に5人まで（YA.KADAI_MAX）。課題中の子は p.star=true（信頼・働きかけ・日誌・節目の会話・進路面談がこの子たちに効く）
// ・合っていれば、期間の後半に来る「気づきの場面」（試合・練習・日常。kizuki.js）で正しい手を選ぶと覚醒する（2026-11-27 段3。前は試合で確率で気づいていた）
// ・外れはあきらめ（期間の1/3〜半分）、種類だけ合うと少し伸びる。終わった子に次の課題を出せるのは4週あけてから
(function () {
  'use strict';
  const YA = (globalThis.YA = globalThis.YA || {});
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const wk = (w) => w.year * (YA.WEEKS || 40) + w.week;
  const fam = (p) => String(p.name).split(' ')[0];
  const all = (w) => Object.values(w.players || {});
  const A = (p, n) => (p.ab && p.ab[n] != null ? p.ab[n] : 0);
  const avg = (p, ns) => { const v = ns.filter((n) => p.ab && p.ab[n] != null); return v.length ? v.reduce((s, n) => s + p.ab[n], 0) / v.length : 0; };
  const hasP = (p, ...vs) => { const xs = Object.values(p.pers || {}); return vs.some((v) => xs.indexOf(v) >= 0); };
  const GRP_WORD = { DF: '守る', MF: 'つなぐ', FW: '点を取る', GK: '守る' };
  const WIDE = new Set(['LB', 'RB', 'LWB', 'RWB', 'LM', 'RM', 'LW', 'RW']);
  const zone = (c) => (WIDE.has(c) ? 'サイド' : '真ん中');
  const posName = (c) => (YA.POS_LABEL && YA.POS_LABEL[c]) || c;
  const pname = (w, id) => (w.players[id] ? w.players[id].name : '');
  const pfam = (w, id) => (w.players[id] ? fam(w.players[id]) : '');
  const addTrait = (p, t) => { if (t && YA.TRAITS && YA.TRAITS.indexOf(t) >= 0 && (p.traits || []).indexOf(t) < 0) { p.traits = (p.traits || []).concat([t]); return t; } return null; };
  const up = (p, n, d) => { if (p.ab && p.ab[n] != null) p.ab[n] = Math.min(20, p.ab[n] + d); };

  YA.KADAI_MAX = 5;
  YA.KADAI_GAP = 4;

  // ---------- 10種類 ----------
  // score(w,p)：その子にどれだけ合いそうか（0〜1）。best(w,p)：合う中身。opts(w,p)：選べる中身（なしは null）
  // why(w,p)：この子には出せない理由。cw：コーチの見立て（はっきり／ぼんやり）。self：本人の言葉。scene：試合の場面。weak：苦しんでいるときの弱音。want：あきらめたときの打ち明け
  const SEAL_AB = ['ドリブル', 'フィニッシュ', 'ロングシュート', 'スピード'];
  const ROLE_C = ['守備の合図役', 'セットプレーのキッカー', '前線の守備の先頭', '声出し役'];
  const sameGrp = (p, q) => YA.GROUP[q.main] === YA.GROUP[p.main];
  const rivalCands = (w, p) => all(w).filter((q) => q.id !== p.id && sameGrp(p, q)).sort((a, b) => Math.abs(YA.rating(a) - YA.rating(p)) - Math.abs(YA.rating(b) - YA.rating(p)));
  const compat = (p, q) => (YA.persCompat ? YA.persCompat(p, q).s : 0);
  const pairCands = (w, p) => all(w).filter((q) => q.id !== p.id && q.pos !== 'GK').sort((a, b) => compat(p, b) - compat(p, a) || YA.rating(b) - YA.rating(a));
  const altPos = (p) => {
    if (p.best && p.best !== p.main && p.best !== 'GK') return p.best;
    let bp = null, bv = -1;
    for (const q of YA.POS15) { if (q === 'GK' || q === p.main) continue; const v = YA.ovrAt(p, q); if (v > bv) { bv = v; bp = q; } }
    return bp;
  };
  const weaponCands = (p) => Object.keys(YA.TRAIT_AFF || {}).filter((t) => (p.traits || []).indexOf(t) < 0 && YA.TRAIT_AFF[t].every((n) => p.ab && p.ab[n] != null)).sort((a, b) => avg(p, YA.TRAIT_AFF[b]) - avg(p, YA.TRAIT_AFF[a]) || (a < b ? -1 : 1));
  const techTop = (p) => { const v = YA.AB_TECH.concat(YA.AB_PHYS).filter((n) => p.ab[n] != null).map((n) => p.ab[n]).sort((a, b) => b - a).slice(0, 5); return v.length ? v.reduce((s, x) => s + x, 0) / v.length : 0; };

  YA.KADAI = [
    { k: 'convert', name: 'コンバート', short: '転向', about: '別のポジションへ移す。慣れるまでは試合の評価が落ちる', len: [12, 16], pick: 'どの位置へ',
      why: (w, p) => (p.pos === 'GK' ? 'GK は位置を変えません' : null),
      score: (w, p) => { if (p.pos === 'GK') return 0; if (p.best && p.best !== p.main && p.best !== 'GK') return 0.85; const a = altPos(p); return a ? clamp((YA.ovrAt(p, a) - YA.ovrAt(p, p.main) - 0.5) / 2.5, 0, 0.7) : 0; },
      best: (w, p) => altPos(p),
      opts: (w, p) => { const near = (YA.NEAR_POS && YA.NEAR_POS[p.main]) || []; const xs = [altPos(p)].concat(near, YA.POS15.slice().sort((a, b) => YA.ovrAt(p, b) - YA.ovrAt(p, a))).filter((q) => q && q !== 'GK' && q !== p.main); return [...new Set(xs)].slice(0, 5); },
      label: (w, c) => posName(c),
      cw: (w, p, c) => [`今の${posName(p.main)}では埋もれている。${zone(c)}で${GRP_WORD[YA.GROUP[c]] || '別の'}場面のほうが、目が生きている`, '今の場所が合っているのか、少し気になる子'],
      self: (w, p, c) => ({ DF: 'ボールを奪ったときが、いちばん気持ちいいんです', MF: 'パスが通ったときが、いちばん気持ちいいんです', FW: 'ゴール前に入っていくと、わくわくするんです' }[YA.GROUP[c]] || '今のポジション、正直ちょっと窮屈で'),
      scene: (w, p, c) => ({ DF: `${fam(p)}は前では消えていたが、自陣で相手を止めた場面だけは鋭かった`, MF: `${fam(p)}は中盤に下りて受けたとき、いちばん生き生きしていた`, FW: `${fam(p)}はゴール前に飛び込んだ一度だけ、迫力があった` }[YA.GROUP[c]] || `${fam(p)}は持ち場から離れたときのほうが良かった`),
      weak: () => '慣れない位置で、何をしたらいいか分からないです',
      want: (w, p, c) => `本当は、${GRP_WORD[YA.GROUP[c]] || '違う'}ほうをやってみたいんです`,
      form: [] },
    { k: 'seal', name: '封印', short: '封印', about: '頼りすぎている得意を、しばらく使わせない', len: [8, 12], pick: 'どの得意を',
      why: (w, p) => (p.pos === 'GK' ? 'GK には封じる得意がありません' : null),
      score: (w, p) => (p.pos === 'GK' ? 0 : clamp((Math.max(...SEAL_AB.map((n) => A(p, n))) - avg(p, ['判断', '視野']) - 1.5) / 4, 0, 0.9)),
      best: (w, p) => SEAL_AB.slice().sort((a, b) => A(p, b) - A(p, a))[0],
      opts: () => SEAL_AB.slice(),
      label: (w, c) => c,
      cw: (w, p, c) => [`${c}に頼りすぎている。でも、周りを見る力は眠っている子`, 'ボールを持つと、一本調子になる子'],
      self: () => 'ボールを持つと、つい前しか見てないんです',
      scene: (w, p, c) => (c === 'ドリブル' || c === 'スピード' ? `${fam(p)}は3人に囲まれても仕掛け、奪われた` : `${fam(p)}は空いた味方がいるのに、遠くから打ち続けた`),
      weak: (w, p, c) => `${c}を使えないと、自分が何もできない気がして`,
      want: () => '本当は、いつもの得意に頼らずにやってみたいんです',
      form: ['conductor', 'fantasista', 'ice', 'reader'] },
    { k: 'role', name: '役割を任せる', short: '役割', about: 'チームの仕事を一つ任せる。最初は仕事に追われる', len: [8, 12], pick: 'どの仕事を',
      why: () => null,
      score: (w, p) => (hasP(p, '人見知り', '寡黙', '繊細', 'プレッシャーに弱い') ? 0.35 : 0) + clamp((YA.ovr(p) - avg(p, ['オフザボール', '運動量']) - 0.5) / 4, 0, 0.5),
      best: (w, p) => (p.pos === 'GK' || p.pos === 'DF' ? '守備の合図役' : A(p, 'プレースキック') >= Math.max(A(p, 'パス'), 9) ? 'セットプレーのキッカー' : p.pos === 'FW' ? '前線の守備の先頭' : '声出し役'),
      opts: (w, p) => (p.pos === 'GK' ? ['守備の合図役', '声出し役'] : ROLE_C.slice()),
      label: (w, c) => c,
      cw: () => ['力はあるのに、試合で消える時間が長い。何か任せると変わるかもしれない', '試合になると、どこにいるのか分からなくなる子'],
      self: (w, p, c) => (c === 'セットプレーのキッカー' ? '蹴るのは好きなんです。でも、自分から言い出せなくて' : '試合だと、自分が何をしたらいいか分からなくなる時があって'),
      scene: (w, p) => `${fam(p)}は試合の大半、ボールに触らなかった`,
      weak: () => '仕事のことばかり考えて、自分のプレーができないです',
      want: () => '本当は、何か任せてもらえたら変われる気がするんです',
      form: ['leader', 'setpiece', 'engine', 'fighter'] },
    { k: 'stage', name: '舞台を変える', short: '舞台', about: 'A へ上げる、または B へ落とす。上げた子は通用せず、落とした子は不満を持つ', len: [8, 12], pick: 'どちらへ',
      why: () => null,
      score: (w, p) => (hasP(p, '自信家', '目立ちたがり', '大舞台に強い', '野心家') || hasP(p, '繊細', 'プレッシャーに弱い', '慎重') ? 0.55 : 0.05),
      best: (w, p) => (hasP(p, '繊細', 'プレッシャーに弱い', '慎重') && !hasP(p, '自信家', '目立ちたがり', '大舞台に強い') ? 'B' : 'A'),
      opts: () => ['A', 'B'],
      label: (w, c) => (c === 'A' ? 'A へ上げる' : 'B へ落とす'),
      cw: (w, p, c) => (c === 'A' ? ['B では余裕がありすぎる。上で揉まれたほうが伸びそうだ', '今いる場所の空気が、合っていないように見える'] : ['重圧に押しつぶされかけている。一度、気楽な場所に置きたい', '今いる場所の空気が、合っていないように見える']),
      self: (w, p, c) => (c === 'A' ? 'B の試合、正直ちょっと物足りないです' : '大事な試合の前の日は、眠れないんです'),
      scene: (w, p, c) => (c === 'A' ? `${fam(p)}は相手が物足りないのか、途中から流していた` : `${fam(p)}は大事な場面で、パスを怖がった`),
      weak: (w, p, c) => (c === 'A' ? '上の試合、全然通用しないです' : 'なんで自分が下なんですか'),
      want: (w, p, c) => (c === 'A' ? '本当は、もっと上でやってみたいんです' : '本当は、一度気楽な所で自分を取り戻したいんです'),
      form: ['ice', 'fighter', 'leader'] },
    { k: 'weapon', name: '新しい武器を足す', short: '武器', about: '新しい特性を一つ身につけさせる。慣れない武器で失敗が続く', len: [12, 16], pick: 'どの特性を',
      why: () => null,
      score: (w, p) => ((p.traits || []).length <= 1 ? 0.45 + ((p.traits || []).length === 0 ? 0.1 : 0) : 0.08),
      best: (w, p) => weaponCands(p)[0],
      opts: (w, p) => weaponCands(p).slice(0, 4),
      label: (w, c) => `「${c}」`,
      cw: () => ['武器が一つしかなく、相手に読まれている。もう一つ欲しい', 'いつも同じ形で止められている子'],
      self: () => '最近、同じ止められ方ばかりしてて……',
      scene: (w, p) => `${fam(p)}は同じ形で仕掛け、3度とも読まれた`,
      weak: () => '新しいこと、全然うまくいかないです',
      want: () => '本当は、新しい武器を身につけたいんです',
      form: ['magic', 'cannon', 'flash', 'crosser', 'setpiece'] },
    { k: 'rival', name: '競わせる', short: '競争', about: '同じ位置の子と競わせる。先発争いで不満がたまる', len: [8, 12], pick: '相手',
      why: (w, p) => (rivalCands(w, p).length ? null : '同じ位置の相手がいません'),
      score: (w, p) => { const q = rivalCands(w, p)[0]; const near = q && Math.abs(YA.rating(q) - YA.rating(p)) <= 8; return hasP(p, '負けず嫌い', '反骨心', '闘争的', '野心家') && near ? 0.75 : near ? 0.1 : 0; },
      best: (w, p) => { const q = rivalCands(w, p)[0]; return q ? q.id : null; },
      opts: (w, p) => rivalCands(w, p).slice(0, 4).map((q) => q.id),
      label: (w, c) => pname(w, c),
      cw: () => ['負けず嫌いなのに、張り合う相手がいなくて退屈している', 'どこか物足りなさそうにしている子'],
      self: (w, p, c) => `${pfam(w, c) || '同じ位置のあいつ'}には、絶対負けたくないんです`,
      scene: (w, p, c) => `${fam(p)}は、${pfam(w, c) || '同じ位置の子'}が一緒に出た試合だけ目の色が違った`,
      weak: (w, p, c) => `${pfam(w, c) || 'あいつ'}に負けてるのが、悔しくて`,
      want: (w, p, c) => `本当は、${pfam(w, c) || '同じ位置のあいつ'}と競わせてほしいんです`,
      form: ['fighter', 'hunter', 'scorer', 'flash'] },
    { k: 'pair', name: '組ませる', short: '相棒', about: '相棒と組ませる。最初はかみ合わず衝突する', len: [8, 12], pick: '相棒',
      why: (w, p) => (pairCands(w, p).length ? null : '組ませる相手がいません'),
      score: (w, p) => { const q = pairCands(w, p)[0]; if (!q || compat(p, q) < 1) return 0; return clamp((hasP(p, '一匹狼', '寡黙', 'マイペース', '人見知り') ? 0.4 : 0) + clamp((10 - A(p, 'チームワーク')) / 10, 0, 0.3) + 0.1, 0, 1); },
      best: (w, p) => { const q = pairCands(w, p)[0]; return q ? q.id : null; },
      opts: (w, p) => pairCands(w, p).slice(0, 4).map((q) => q.id),
      label: (w, c) => pname(w, c),
      cw: () => ['一人で何とかしようとしすぎる。合う相棒がいれば変わる', '周りとの間に、少し壁がある子'],
      self: (w, p, c) => `${pfam(w, c) || 'あいつ'}とは、なんか話が合うんです`,
      scene: (w, p, c) => `${fam(p)}は、${pfam(w, c) || 'ある味方'}とのパス交換だけ息が合っていた`,
      weak: (w, p, c) => `${pfam(w, c) || 'あいつ'}とは、合わないです`,
      want: (w, p, c) => `本当は、${pfam(w, c) || 'あいつ'}と組んでみたいんです`,
      form: ['conductor', 'engine', 'fantasista', 'wing'] },
    { k: 'eye', name: '見る目を鍛える', short: '視野', about: '見ること・考えることを徹底させる。考えすぎてプレーが遅れる', len: [12, 16], pick: null,
      why: () => null,
      score: (w, p) => clamp((techTop(p) - avg(p, ['視野', '判断', '予測']) - 1.5) / 4, 0, 0.9),
      best: () => null, opts: () => null, label: () => '',
      cw: () => ['体も技術もある。足りないのは、見ること・考えること', 'うまいのに、プレーの選び方がもったいない子'],
      self: () => '考える前に体が動いちゃうんです。それで失敗して',
      scene: (w, p) => `${fam(p)}は空いている味方に気づかず、無理に打った`,
      weak: () => '考えてたら、ボールを取られちゃって',
      want: () => '本当は、頭を使うサッカーを覚えたいんです',
      form: ['reader', 'conductor', 'fantasista', 'leader'] },
    { k: 'captain', name: '主将を任せる', short: '主将', about: 'キャプテンを任せる。まとめられず、自分のプレーも落ちる', len: [12, 16], pick: null,
      why: () => null,
      score: (w, p) => (hasP(p, 'リーダー気質', '世話好き') ? 0.7 : hasP(p, '仲間思い') ? 0.25 : 0),
      best: () => null, opts: () => null, label: () => '',
      cw: () => ['周りを引っ張る素質があるのに、本人が気づいていない', '練習で、ときどき人に声をかけている子'],
      self: () => 'みんなが困ってると、つい口を出しちゃうんです',
      scene: (w, p) => `${fam(p)}が声をかけたあと、守備がそろった`,
      weak: () => 'みんな言うこと聞いてくれなくて……',
      want: () => '本当は、チームをまとめる役をやってみたいんです',
      form: ['leader', 'fighter', 'engine'] },
    { k: 'body', name: '体を作る', short: '体', about: '筋力と走る力を鍛える。しばらくは試合の動きが重い', len: [12, 16], pick: null,
      why: () => null,
      score: (w, p) => { const t = p.pos === 'GK' ? avg(p, ['ハンドリング', '反応']) : avg(p, ['テクニック', 'ファーストタッチ', 'パス']); return clamp((t - avg(p, ['強さ', 'スタミナ', 'バランス']) - 1.5) / 4, 0, 0.9); },
      best: () => null, opts: () => null, label: () => '',
      cw: () => ['技術は十分。当たり負けと、後半の足の止まりが課題', 'うまいが、試合の終わりに消える子'],
      self: () => '後半になると、足が言うこと聞かなくて',
      scene: (w, p) => `${fam(p)}は当たられて倒れる場面が多く、後半は足が止まった`,
      weak: () => '体が重くて、試合で動けないです',
      want: () => '本当は、体を一から作り直したいんです',
      form: ['wall', 'post', 'sky', 'engine', 'fighter'] },
  ];
  const DEF = (k) => YA.KADAI.find((d) => d.k === k);
  YA.kadaiDef = DEF;
  YA.kadaiLabel = function (w, t, c) {
    const d = DEF(t);
    if (!d) return '';
    return d.pick && c != null ? `${d.name}（${d.label(w, c)}）` : d.name;
  };

  // ---------- 合う課題を決める（入団のとき・覚醒のあと）。選手ごとの乱数で、ゲームの乱数の流れは変えない ----------
  const rngP = (w, p, salt) => YA.rngOf((w.seed | 0) * 7 + YA.hash(String(p.id) + salt));
  function rollFit(w, p, g, avoid) {
    const r = rngP(w, p, 'kf' + g);
    let bt = null, bv = -1, sec = null, sv = -1;
    for (const d of YA.KADAI) {
      if (d.why(w, p) || (avoid || []).indexOf(d.k) >= 0) continue;
      if (d.pick && d.best(w, p) == null) continue;
      const v = d.score(w, p) + r() * 0.3;
      if (v > bv) { sec = bt; sv = bv; bt = d.k; bv = v; } else if (v > sv) { sec = d.k; sv = v; }
    }
    if (!bt) bt = 'eye';
    const d = DEF(bt);
    return { t: bt, c: d.pick ? d.best(w, p) : null, g, sec: sec || 'body' };
  }
  // コーチの見立て（手がかり1）：見る目が高いほどはっきり。低いとぼんやり、5回に1回ほど外れた見立て
  function coachClue(w, p) {
    const f = p.kf;
    const r = rngP(w, p, 'kc' + f.g);
    // 見る目は指導者とスカウト担当の平均（scout.js の YA.eyeLevel。3〜18）
    const eye = YA.eyeLevel ? YA.eyeLevel(w) : w.coach ? w.coach.eye || 8 : 8;
    const miss = r.chance(eye >= 14 ? 0.04 : eye >= 10 ? 0.1 : 0.2);
    const t = miss ? f.sec : f.t;
    const d = DEF(t);
    const c = t === f.t ? f.c : d.pick ? d.best(w, p) : null;
    const lines = d.cw(w, p, c);
    const clear = !miss && r() < clamp(0.35 + (eye - 8) * 0.08, 0.2, 0.95);
    return { k: t, t: clear ? lines[0] : lines[1], s: miss ? 'miss' : clear ? 'clear' : 'vague' };
  }
  function freshClues(w, p) {
    p.kc = { coach: coachClue(w, p), self: null, match: null, more: [] };
    p.kSelfAt = wk(w) + rngP(w, p, 'ks' + p.kf.g).int(8, 12);
  }
  // 古い世界・新入生・途中加入の子に、合う課題と手がかりを持たせる
  YA.kadaiEnsure = function (w, p) {
    if (!p || p.kf) return p;
    p.kf = rollFit(w, p, 0);
    freshClues(w, p);
    return p;
  };
  // 相手が抜けた（卒業・退団）中身は、同じ種類のまま選び直す
  function fixFit(w, p) {
    const f = p.kf;
    if (!f) return;
    const d = DEF(f.t);
    if (d && d.pick && (f.t === 'rival' || f.t === 'pair') && !w.players[f.c]) {
      const c = d.best(w, p);
      if (c != null) f.c = c; else { p.kf = rollFit(w, p, f.g, [f.t]); }
    }
  }

  // ---------- 課題を出す・やめる ----------
  YA.kadaiActive = (w) => all(w).filter((p) => p.kd);
  YA.kadaiLeft = (w) => YA.KADAI_MAX - YA.kadaiActive(w).length;
  YA.kadaiWhy = function (w, p, t) {
    if (!p) return 'できません';
    if (p.kd) return 'いま課題に取り組んでいます';
    if (YA.kadaiLeft(w) <= 0) return `課題を出せるのは同時に${YA.KADAI_MAX}人までです`;
    if (p.kEnd != null && wk(w) - p.kEnd < YA.KADAI_GAP) return `前の課題が終わってから${YA.KADAI_GAP}週あけます（あと${YA.KADAI_GAP - (wk(w) - p.kEnd)}週）`;
    if (p.away > 0) return 'いまチームを離れています';
    if (t) { const d = DEF(t); const why = d && d.why(w, p); if (why) return why; }
    return null;
  };
  YA.kadaiOpts = function (w, p, t) {
    const d = DEF(t);
    if (!d || !d.pick) return null;
    YA.kadaiEnsure(w, p);
    fixFit(w, p);
    const xs = (d.opts(w, p) || []).filter((x) => x != null);
    if (p.kf && p.kf.t === t && p.kf.c != null && xs.indexOf(p.kf.c) < 0) xs.splice(rngP(w, p, 'ko').int(0, xs.length), 0, p.kf.c);
    return xs;
  };
  // 舞台を変える：同じ括りの子と入れ替える（並び・ベンチの場所ごと）
  function swapPlaces(w, p, q) {
    for (const k of ['lineupA', 'lineupB']) (w[k] || []).forEach((s, i) => { if (s.pid === p.id) s.pid = q.id; else if (s.pid === q.id) s.pid = p.id; else return; if (YA.fixSlotRole) YA.fixSlotRole(s, i); });
    for (const k of ['benchA', 'benchB']) w[k] = (w[k] || []).map((id) => (id === p.id ? q.id : id === q.id ? p.id : id));
    const t = p.team; p.team = q.team; q.team = t;
  }
  function moveStage(w, p, to) {
    if (p.team === to) return '';
    const q = all(w).filter((x) => x.id !== p.id && x.team === to && x.pos === p.pos && !(x.kd && x.kd.t === 'stage')).sort((a, b) => (to === 'A' ? YA.ovr(a) - YA.ovr(b) : YA.ovr(b) - YA.ovr(a)))[0];
    if (!q) return '';
    swapPlaces(w, p, q);
    return `（${q.name}と入れ替えて${to}へ）`;
  }
  YA.kadaiGive = function (w, p, t, c, o) {
    const why = YA.kadaiWhy(w, p, t);
    if (why) return { ok: false, msg: why };
    YA.kadaiEnsure(w, p);
    fixFit(w, p);
    const d = DEF(t);
    if (d.pick && c == null) return { ok: false, msg: `${d.pick}を選んでください` };
    const f = p.kf;
    const fit = f.t === t ? (!d.pick || f.c === c ? (f.done ? 'half' : 'yes') : 'half') : 'no';
    const r = rngP(w, p, 'kg' + wk(w));
    const len = r.int(d.len[0], d.len[1]);
    const w0 = wk(w);
    p.kd = { t, c: d.pick ? c : null, w0, len, fit, give: fit === 'no' ? w0 + Math.round(len * (1 / 3 + r() / 6)) : null };
    p.star = true;
    p.kEver = true;
    if (p.tr == null) p.tr = 50;
    let extra = '';
    if (t === 'stage') extra = moveStage(w, p, c);
    if (t === 'captain' && YA.setCaptain && w.captain !== p.id) { YA.setCaptain(w, p.id, 'captain'); extra = '（キャプテンに指名した）'; }
    if (t === 'convert' && YA.startConvert && p.apt && p.apt[c] != null) YA.startConvert(w, p, c);
    p.hist.unshift({ y: w.year, w: w.week, t: `課題：${YA.kadaiLabel(w, t, c)}` });
    if (YA.memAdd) YA.memAdd(w, p, 'kadai', null, YA.kadaiLabel(w, t, c));
    // 初めての課題は最初の話（節目の会話）。おまかせで出したときは会話を挟まない（おまかせが止まらないように）
    if (!p.ms || !p.ms.star) { if (o && o.auto) { p.ms = p.ms || {}; p.ms.star = w.year * 100 + w.week; } else if (YA.milestone) YA.milestone(w, p, 'star'); }
    return { ok: true, msg: `${p.name}に課題「${YA.kadaiLabel(w, t, c)}」を出しました（${len}週）${extra}` };
  };
  function endKadai(w, p, res) {
    const k = p.kd;
    if (!k) return;
    p.kHist = (p.kHist || []).concat([{ t: k.t, c: k.c, y: w.year, w: w.week, r: res, fit: k.fit, n: k.sc || 0 }]).slice(-8); // n＝来た気づきの場面の数
    if (k.t === 'convert' && p.convert && p.convert.pos === k.c && res !== 'awake') p.convert = null;
    p.kd = null;
    p.star = false;
    p.kEnd = wk(w);
    if (p._sealV) unseal(p);
  }
  YA.kadaiStop = function (w, p) {
    if (!p || !p.kd) return { ok: false, msg: '課題に取り組んでいません' };
    const nm = YA.kadaiLabel(w, p.kd.t, p.kd.c);
    YA.addTr(w, p, -3, '課題を途中でやめた');
    endKadai(w, p, 'stop');
    return { ok: true, msg: `${p.name}の課題「${nm}」をやめました（信頼が少し下がった）` };
  };

  // ---------- いまの様子（合っているかは出さない）----------
  YA.kadaiState = function (w, p) {
    const k = p.kd;
    if (!k) return null;
    const e = wk(w) - k.w0;
    const half = e >= k.len / 2;
    const word = !half ? (p.conf < 35 ? '自信をなくしている' : '苦しんでいる') : p.conf < 35 ? 'もがいている' : '慣れてきた';
    return { e: Math.min(k.len, e), len: k.len, half, word, name: YA.kadaiLabel(w, k.t, k.c), short: DEF(k.t).short };
  };

  // ---------- 手がかり ----------
  function revealSelf(w, p, via) {
    if (!p.kf || !p.kc || p.kc.self) return null;
    const f = p.kf;
    p.kc.self = DEF(f.t).self(w, p, f.c);
    if (via === 'diary') p.diary = (p.diary || []).concat([{ y: w.year, w: w.week, t: p.kc.self + '。' }]).slice(-10);
    return p.kc.self;
  }
  function revealScene(w, p) {
    if (!p.kf || !p.kc || p.kc.match) return null;
    p.kc.match = DEF(p.kf.t).scene(w, p, p.kf.c);
    return p.kc.match;
  }
  // 働きかけ・合宿・OBの話などで、まだの手がかりが早く見えることがある（前の hintUp の呼び口をそのまま使う）
  YA.hintUp = function (w, p, chance, why) {
    if (!p) return false;
    YA.kadaiEnsure(w, p);
    if (!p.kc || (p.kc.self && p.kc.match)) return false;
    const lv = YA.trustLv ? YA.trustLv(p) : 3;
    const c = chance * (lv <= 2 ? 0.45 : lv >= 4 ? 1.35 : 1);
    const r = YA.rngOf((w.seed | 0) + wk(w) * 3 + YA.hash(p.id + why));
    if (!r.chance(c)) return false;
    const t = !p.kc.self ? revealSelf(w, p) : revealScene(w, p);
    if (t && YA.noteTier) YA.noteTier(w, 2, `${p.num}番 ${p.name}の手がかりが見えた（${why}）：「${t}」`, p.id);
    return !!t;
  };
  // 詳しい画面の「手がかり」欄（未は「？」）
  YA.kadaiClues = function (w, p) {
    YA.kadaiEnsure(w, p);
    const c = p.kc || {};
    return [
      ['コーチの見立て', c.coach ? c.coach.t : '？'],
      ['本人の言葉', c.self ? `「${c.self}」` : '？'],
      ['試合の場面', c.match || '？'],
    ].concat((c.more || []).map((t) => ['打ち明けた', `「${t}」`]));
  };
  // コーチのおすすめ（いちばん有力な見立て）：見立ての種類と、その種類で合いそうな中身
  YA.kadaiRec = function (w, p) {
    YA.kadaiEnsure(w, p);
    fixFit(w, p);
    let t = p.kc && p.kc.coach ? p.kc.coach.k : p.kf.t;
    // あきらめた種類は外す（打ち明けた言葉があれば、それに合わせる）
    const gave = (p.kHist || []).filter((x) => x.r === 'gaveup').map((x) => x.t);
    if (gave.indexOf(t) >= 0) t = (p.kc.more || []).length ? p.kf.t : (YA.KADAI.find((d) => gave.indexOf(d.k) < 0 && !d.why(w, p) && (!d.pick || d.best(w, p) != null)) || DEF('eye')).k;
    const d = DEF(t);
    if (d.why(w, p)) return null;
    // 中身：見立てどおりの種類なら合う中身。前に試して「少し伸びた」だけの中身は避ける
    const tried = (x) => (p.kHist || []).some((h) => h.t === t && h.c === x && h.r === 'half');
    let c = null;
    if (d.pick) {
      c = t === p.kf.t ? p.kf.c : d.best(w, p);
      if (tried(c)) c = YA.kadaiOpts(w, p, t).find((x) => !tried(x)) || c;
    }
    if (d.pick && c == null) return null;
    return { t, c };
  };

  // ---------- 気づき（2026-11-27 段3）：課題の後半に来る「気づきの場面」で選ぶ（kizuki.js）----------
  // おまかせ進行のときに、場面で正しい手を選ぶ確率（前は後半に出た試合1つで気づく確率だった）
  YA.KADAI_SPARK = 0.4;
  // 正しい手を選んだが課題が合っていなかったとき：まだの手がかりを1つ見せる（出そろっていれば、本当はどうしたいかを打ち明ける）
  YA.kadaiClueUp = function (w, p) {
    YA.kadaiEnsure(w, p);
    if (!p.kc) return null;
    if (!p.kc.self) return revealSelf(w, p);
    if (!p.kc.match) return revealScene(w, p);
    const f = p.kf;
    const t = DEF(f.t).want(w, p, f.c);
    if (p.kc.more.indexOf(t) >= 0) return null;
    p.kc.more.push(t);
    return t;
  };

  // 覚醒のときの課題ごとの伸び
  function payoff(w, p, k) {
    const out = [];
    const t = k.t, c = k.c;
    if (t === 'convert' && c && c !== 'GK') {
      p.p20 = (p.p20 || []).concat(p.p20 && p.p20.indexOf(c) >= 0 ? [] : [c]);
      if (YA.refreshApt) YA.refreshApt(p);
      if (p.main !== c) {
        p.main = c; p.pos = YA.GROUP[c]; p.bestKnown = true;
        for (const kk of ['lineupA', 'lineupB']) (w[kk] || []).forEach((sl, i) => { if (sl.pid === p.id && YA.fixSlotRole) YA.fixSlotRole(sl, i); });
      }
      p.convert = null;
      out.push(`${posName(c)}が本職になった`);
    } else if (t === 'seal') { up(p, '判断', 2); up(p, '視野', 2); if (c) up(p, c, 1); out.push(`判断・視野が上がり、封じていた${c || '得意'}も前より効く`); }
    else if (t === 'role') { up(p, 'チームワーク', 2); up(p, '集中', 2); const tr = addTrait(p, { 守備の合図役: p.pos === 'GK' ? 'コーチングの声' : 'ラインコントロール', セットプレーのキッカー: '直接FK', 前線の守備の先頭: 'ハイプレスの先頭', 声出し役: '声で味方を動かす' }[c]); out.push('チームワーク・集中が上がった' + (tr ? `。特性「${tr}」` : '')); }
    else if (t === 'stage') { up(p, '冷静さ', 2); up(p, '集中', 1); p.conf = clamp(p.conf + 10, 0, 100); const tr = addTrait(p, c === 'A' ? '大観衆を力に' : 'ミスを引きずらない'); out.push('冷静さと自信が上がった' + (tr ? `。特性「${tr}」` : '')); }
    else if (t === 'weapon') { const tr = addTrait(p, c); if (tr && YA.TRAIT_AFF[tr]) for (const n of YA.TRAIT_AFF[tr]) up(p, n, 1); out.push(tr ? `特性「${tr}」を身につけた` : '新しい武器が形になった'); }
    else if (t === 'rival') { const q = w.players[c]; const ns = (YA.POS_ABS15[p.main] || []).slice().sort((a, b) => A(p, a) - A(p, b)).slice(0, 2); for (const n of ns) up(p, n, 2); if (q) { const n2 = (YA.POS_ABS15[q.main] || [])[YA.hash(q.id + w.year) % ((YA.POS_ABS15[q.main] || []).length || 1)]; if (n2) up(q, n2, 1); q.conf = clamp(q.conf + 4, 0, 100); } out.push(`${ns.join('・')}が伸びた${q ? `。${fam(q)}も伸びた` : ''}`); }
    else if (t === 'pair') { const q = w.players[c]; up(p, 'チームワーク', 3); const tr = addTrait(p, p.pos === 'GK' ? 'チームの潤滑油' : 'ワンツー'); if (q) { up(q, 'チームワーク', 1); addTrait(q, q.pos === 'GK' ? 'チームの潤滑油' : 'ワンツー'); } out.push('チームワークが上がった' + (tr ? `。${q ? fam(q) + 'と二人で' : ''}特性「${tr}」` : '')); }
    else if (t === 'eye') { up(p, '視野', 3); up(p, '判断', 3); up(p, '予測', 2); up(p, 'ポジショニング', 2); out.push('視野・判断・予測・ポジショニングが大きく上がった'); }
    else if (t === 'captain') { const tr = addTrait(p, '味方を鼓舞する'); for (const q of all(w)) q.conf = clamp(q.conf + (q === p ? 6 : 3), 0, 100); out.push('チーム全体の気持ちが上がった' + (tr ? `。特性「${tr}」` : '')); }
    else if (t === 'body') { up(p, '強さ', 3); up(p, 'スタミナ', 3); up(p, 'バランス', 2); out.push('強さ・スタミナ・バランスが大きく上がった'); }
    return out.join('');
  }
  function sparkAwaken(w, p, where) {
    const k = p.kd;
    const nm = YA.kadaiLabel(w, k.t, k.c);
    p._kPref = DEF(k.t).form;
    const got = payoff(w, p, k);
    endKadai(w, p, 'awake');
    YA.awaken(w, p);
    p._kPref = null;
    if (p.awake) p.awake.kadai = nm;
    w.kadaiN = { y: w.year, n: (w.kadaiN && w.kadaiN.y === w.year ? w.kadaiN.n : 0) + 1, give: w.kadaiN && w.kadaiN.y === w.year ? w.kadaiN.give || 0 : 0 };
    YA.noteTier(w, 1, `${p.num}番 ${p.name}が${where || '試合の中で'}気づいた――課題「${nm}」が実を結んだ。${got}`, p.id);
    // 次の覚醒が残っていれば、次の合う課題が決まる（手がかりも新しく）
    p.kf = rollFit(w, p, (p.kf ? p.kf.g : 0) + 1, [k.t]);
    if ((p.awDone || 0) >= (p.awN || 1)) p.kf.done = true;
    freshClues(w, p);
  }

  YA.kadaiAwakenNow = sparkAwaken; // 気づいたときの処理（kizuki.js の場面で正しい手を選んだとき）

  // ---------- 試合のあと ----------
  function unseal(p) {
    if (!p._sealV) return;
    if (p.ab && p.ab[p._sealV.a] != null) p.ab[p._sealV.a] = Math.min(20, p.ab[p._sealV.a] + p._sealV.d);
    p._sealV = null;
  }
  YA.kadaiUnseal = unseal;
  // 封印の前半は、試合でその得意が出ない（試合のあいだだけ能力を下げ、試合のあとに戻す）
  const tf0 = YA.teamFromWorld;
  YA.teamFromWorld = function (w, which) {
    const t = tf0.apply(this, arguments);
    for (const p of Object.values(t.players)) {
      const k = p.kd;
      if (!k || k.t !== 'seal' || p._sealV || !k.c || !p.ab || p.ab[k.c] == null) continue;
      if (wk(w) - k.w0 >= k.len / 2) continue;
      const d = Math.min(3, p.ab[k.c] - 1);
      p.ab[k.c] -= d;
      p._sealV = { a: k.c, d };
    }
    return t;
  };
  const am0 = YA.applyMatch;
  YA.applyMatch = function (w, m, which, opp, scheduled) {
    // 苦しむ時期は試合の評価が少し落ちる
    for (const id of Object.keys((m.home && m.home.players) || {})) {
      const p = w.players[id];
      if (!p) continue;
      unseal(p);
      const st = m.home.players[id].st;
      if (p.kd && st && st.minutes > 0 && wk(w) - p.kd.w0 < p.kd.len / 2 && st.rating != null) st.rating = Math.max(3, Math.round((st.rating - 0.3) * 10) / 10);
    }
    const res = am0.apply(this, arguments);
    if (which !== 'A' && which !== 'B') return res;
    const played = [];
    for (const id of Object.keys((m.home && m.home.players) || {})) {
      const p = w.players[id];
      const st = m.home.players[id].st;
      if (!p || !st || !(st.minutes > 0)) continue;
      YA.kadaiEnsure(w, p);
      played.push(p);
    }
    // 試合の場面の手がかり（1試合に1人まで）
    const r = YA.rngOf((w.seed | 0) * 3 + wk(w) * 17 + (which === 'B' ? 5 : 0));
    const cand = played.filter((p) => p.kc && !p.kc.match && wk(w) - (p.kJoin || 0) >= 3);
    if (cand.length && r.chance(0.6)) {
      const p = cand[Math.floor(r() * cand.length)];
      const t = revealScene(w, p);
      if (t) YA.noteTier(w, 2, `試合の手がかり：${t}`, p.id);
    }
    return res;
  };

  // ---------- 毎週（core.js の awakeWeek から呼ぶ）----------
  YA.kadaiWeek = function (w) {
    const now = wk(w);
    for (const p of all(w)) {
      unseal(p);
      if (!p.kf) { YA.kadaiEnsure(w, p); p.kJoin = now; }
      if (p.kJoin == null) p.kJoin = now;
      fixFit(w, p);
      // 全員の記憶：スカウトの見立てを出会いとして残す（前は★を付けたときだけ）
      if (!p._memScout && p.scoutNote && p.scoutNote.hunch && YA.memAdd) {
        p._memScout = true;
        if (!(p.mem || []).some((m) => m.k === 'scout')) { p.mem = p.mem || []; p.mem.unshift({ y: w.year, w: w.week, g: p.grade, k: 'scout', c: null, q: p.scoutNote.hunch.text, ok: p.scoutNote.hunch.true }); }
      }
      const k = p.kd;
      if (!k) continue;
      // 課題中の子は、日誌に本人の言葉が出る（入団から2〜3か月たってから）
      if (p.kc && !p.kc.self && now >= p.kSelfAt) revealSelf(w, p, 'diary');
      const e = now - k.w0;
      const d = DEF(k.t);
      // 前半（苦しむ時期）：自信が少し下がる。2週目に本人の弱音
      if (e < k.len / 2) {
        p.conf = clamp(p.conf - 1.2, 0, 100);
        if (k.t === 'rival' || k.t === 'stage') p.unrest = (p.unrest || 0) + 0.25;
        if (e === 2) YA.noteTier(w, 2, `${p.num}番 ${p.name}（課題「${d.name}」）：「${d.weak(w, p, k.c)}」`, p.id);
      }
      // 外れ：期間の1/3〜半分のあいだに、本人があきらめる
      if (k.fit === 'no' && k.give != null && now >= k.give) {
        const nm = YA.kadaiLabel(w, k.t, k.c);
        YA.addTr(w, p, -8, '課題をあきらめた');
        p.conf = clamp(p.conf - 8, 0, 100);
        endKadai(w, p, 'gaveup');
        const f = p.kf;
        const t = DEF(f.t).want(w, p, f.c);
        if (p.kc && p.kc.more.indexOf(t) < 0) p.kc.more.push(t);
        w.kadaiN = { y: w.year, n: w.kadaiN && w.kadaiN.y === w.year ? w.kadaiN.n : 0, give: (w.kadaiN && w.kadaiN.y === w.year ? w.kadaiN.give || 0 : 0) + 1 };
        YA.noteTier(w, 1, `${p.num}番 ${p.name}が課題「${nm}」をあきらめた。信頼と自信が下がった。話の終わりに、ぽつりと言った。「${t}」`, p.id);
        if (YA.memAdd) YA.memAdd(w, p, 'kgive', null, t);
        continue;
      }
      // 期間の終わり（気づきの場面がまだ残っていれば、その場面のあと）
      if (e >= k.len && !(YA.kizukiPending && YA.kizukiPending(w, p))) {
        const nm = YA.kadaiLabel(w, k.t, k.c);
        if (k.fit === 'half') {
          const ns = (YA.POS_ABS15[p.main] || []).slice().sort((a, b) => A(p, a) - A(p, b)).slice(0, 2);
          for (const n of ns) up(p, n, 1);
          YA.addTr(w, p, 2);
          endKadai(w, p, 'half');
          YA.noteTier(w, 2, `${p.num}番 ${p.name}の課題「${nm}」が終わった。${ns.join('・')}が少し伸びたが、化けるところまではいかなかった。何かが少し違ったのかもしれない`, p.id);
        } else {
          endKadai(w, p, 'miss');
          YA.noteTier(w, 2, `${p.num}番 ${p.name}の課題「${nm}」の期間が終わった。気づく場面で正しい手を選べないまま終わった（同じ課題を、${YA.KADAI_GAP}週あけてもう一度出せる）`, p.id);
        }
      }
    }
  };

  // 面談：入団から2〜3か月たつと、本人の言葉が手がかりに加わる（全員）
  const talk0 = YA.talk;
  YA.talk = function (w, pid, k) {
    const res = talk0.apply(this, arguments);
    const p = w.players[pid];
    if (res && res.ok && p) {
      YA.kadaiEnsure(w, p);
      if (p.kc && !p.kc.self && wk(w) >= p.kSelfAt) { const t = revealSelf(w, p, 'talk'); if (t) res.extra = (res.extra ? res.extra + '　' : '') + `手がかり「${t}」`; }
    }
    return res;
  };

  // ---------- おまかせ進行：コーチのおすすめどおりに、空いた枠へ課題を出す ----------
  YA.autoKadai = function (w) {
    let left = YA.kadaiLeft(w);
    if (left <= 0) return 0;
    const cand = all(w).filter((p) => !YA.kadaiWhy(w, p) && !(p.inj > 2) && !(p.grade === 3 && w.week >= 26) && !(p.kf && p.kf.done))
      .sort((a, b) => (YA.coachStars(w, b) - YA.coachStars(w, a)) || a.grade - b.grade || YA.rating(b) - YA.rating(a));
    let n = 0;
    for (const p of cand) {
      if (left <= 0) break;
      const rec = YA.kadaiRec(w, p);
      if (!rec) continue;
      const r = YA.kadaiGive(w, p, rec.t, rec.c, { auto: true });
      if (r.ok) { left--; n++; }
    }
    return n;
  };

  // 新しい世界：全員に合う課題と手がかり
  const nw0 = YA.newWorld;
  YA.newWorld = function (seed, opts) {
    const w = nw0.apply(this, arguments);
    for (const p of all(w)) { YA.kadaiEnsure(w, p); p.kJoin = wk(w); }
    return w;
  };

  // ---------- 画面 ----------
  const U = () => YA._ui;
  // 詳しい画面（コーチの報告の一番上）：手がかり欄と、課題を出す／進み具合とやめる
  YA.kadaiBox = function (w, p, rerender) {
    const h = U().h;
    YA.kadaiEnsure(w, p);
    const lv = YA.trustLv(p);
    const box = h('div', { class: 'card kadaibox', style: 'padding:6px 9px;margin:2px 0 6px;background:#fffaf0;border-color:#f0cf55' });
    box.append(h('div', { class: 'row', style: 'gap:8px;flex-wrap:wrap' }, h('b', {}, '手がかり'), h('span', { class: 'chip gray' }, `信頼 ${'●'.repeat(lv)}${'○'.repeat(5 - lv)} ${YA.TRUST_NAME[lv]}`),
      p.aw ? h('span', { class: 'chip trait' }, `覚醒 ${p.aw.form}・特性「${p.aw.trait}」`) : null));
    for (const [k, t] of YA.kadaiClues(w, p)) box.append(h('div', { class: 'kclue', style: 'font-size:12px;line-height:1.5;display:flex;gap:6px' }, h('span', { class: 'sub', style: 'flex:none;width:84px;font-size:11px;font-weight:800' }, k), h('span', { style: t === '？' ? 'color:#9aa8be;font-weight:800' : '' }, t)));
    const st = YA.kadaiState(w, p);
    if (st) {
      box.append(h('div', { class: 'row', style: 'gap:6px;margin-top:5px;flex-wrap:wrap;border-top:1px dashed var(--line);padding-top:5px' },
        h('b', {}, '課題：' + st.name), h('span', { class: 'chip gray' }, `${st.e}/${st.len}週`), h('span', { class: 'chip ' + (st.half ? 'pers' : 'gray') }, st.word), h('span', { class: 'grow' }),
        h('button', { class: 'btn sm', onclick: () => YA.confirmBox(`${p.name}の課題をやめますか（信頼が少し下がります）`, () => { const r = YA.kadaiStop(w, p); U().app.starMsg = r.msg; YA.saveWorld(); rerender(); }, { yes: 'やめる', danger: true }) }, 'やめる')));
      box.append(h('div', { class: 'note' }, st.half ? '期間の後半です。試合・練習・日常のどこかで、気づきの場面が来ます。正しい見え方を選べれば、化けるかもしれません。' : '前半は苦しむ時期です。自信と試合の評価が少し落ちます。後半に入ると、気づきの場面が来ます。'));
    } else {
      const why = YA.kadaiWhy(w, p);
      const rec = !why ? YA.kadaiRec(w, p) : null;
      box.append(h('div', { class: 'row', style: 'gap:6px;margin-top:5px;flex-wrap:wrap;border-top:1px dashed var(--line);padding-top:5px' },
        h('button', { class: 'btn pri sm', disabled: !!why, why: why || '', onclick: () => YA.kadaiPicker(w, p, rerender) }, '課題を出す'),
        h('span', { class: 'sub', style: 'font-size:11px' }, why || `課題を出せる枠 あと${YA.kadaiLeft(w)}つ${rec ? `・コーチのおすすめ「${YA.kadaiLabel(w, rec.t, rec.c)}」` : ''}`)));
      const last = (p.kHist || []).slice(-1)[0];
      if (last) box.append(h('div', { class: 'note' }, `前の課題：${YA.kadaiLabel(w, last.t, last.c)}（${{ awake: '覚醒した', gaveup: 'あきらめた', miss: '気づけずに終わった', half: '少し伸びた', stop: '途中でやめた' }[last.r] || ''}）`));
    }
    return box;
  };
  // 課題を出す画面：10種類の札 → 中身 → 確認
  YA.kadaiPicker = function (w, p, rerender, step) {
    const h = U().h;
    const modal = YA._v.modal;
    const rec = YA.kadaiRec(w, p);
    modal((close) => {
      const body = h('div', { class: 'kpick', style: 'display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:5px;overflow:auto;min-height:0' });
      const done = (t, c) => { close(); YA.confirmBox(`${p.name}に課題「${YA.kadaiLabel(w, t, c)}」を出しますか`, () => { const r = YA.kadaiGive(w, p, t, c); U().app.starMsg = r.msg; YA.saveWorld(); rerender(); }, { yes: '課題を出す', note: '合っているかは、本人の様子と試合で分かってきます。' }); };
      const pickC = (d) => {
        body.replaceChildren(...YA.kadaiOpts(w, p, d.k).map((c) => h('button', { class: 'btn kopt', style: 'min-height:42px', onclick: () => done(d.k, c) }, d.label(w, c))));
        head.replaceChildren(h('div', { class: 'h grow' }, `${d.name}：${d.pick}`), h('button', { class: 'btn sm', onclick: () => { close(); YA.kadaiPicker(w, p, rerender); } }, '‹ 戻る'), h('button', { class: 'btn sm', onclick: close }, '閉じる'));
      };
      const head = h('div', { class: 'row', style: 'gap:6px' }, h('div', { class: 'h grow' }, `${p.name}に出す課題`), h('button', { class: 'btn sm', onclick: close }, '閉じる'));
      for (const d of YA.KADAI) {
        const why = YA.kadaiWhy(w, p, d.k);
        body.append(h('button', { class: 'btn kcard', style: 'flex-direction:column;align-items:flex-start;text-align:left;white-space:normal;min-height:52px;gap:1px;padding:4px 8px', disabled: !!why, why: why || '', onclick: () => (d.pick ? pickC(d) : done(d.k, null)) },
          h('span', { class: 'row', style: 'gap:5px;width:100%' }, h('b', {}, d.name), h('span', { class: 'chip gray', style: 'font-size:11px;padding:0 5px' }, `${d.len[0]}〜${d.len[1]}週`), rec && rec.t === d.k ? h('span', { class: 'chip trait', style: 'font-size:11px;padding:0 5px' }, 'コーチのおすすめ') : null),
          h('small', { style: 'font-weight:600;font-size:11.5px;line-height:1.35;opacity:.85' }, d.about)));
      }
      if (step) { const d = DEF(step); if (d && d.pick) pickC(d); }
      return h('div', { class: 'sheet-in', style: 'flex:none;align-self:center;margin:auto;width:min(720px,97%);max-height:94%;padding:10px;gap:6px;display:flex;flex-direction:column' }, head, body,
        h('div', { class: 'note' }, '手がかり（コーチの見立て・本人の言葉・試合の場面）から、この子に合う課題を考えます。外れると、本人が途中であきらめます。'));
    });
  };
  // ホーム：「課題の5人」の帯
  YA.kadaiBand = function (w, rerender) {
    const h = U().h;
    const act = YA.kadaiActive(w).sort((a, b) => a.kd.w0 - b.kd.w0);
    const left = YA.KADAI_MAX - act.length;
    const go = (p) => { const app = U().app; app.pSel = p.id; app.tab = 'players'; app.pOpen = true; app.pTab = 'rep'; rerender(); };
    return h('div', { class: 'card kband', style: 'flex:none;display:flex;align-items:center;gap:6px;padding:4px 8px;overflow-x:auto;overflow-y:hidden' },
      h('div', { style: 'flex:none;display:flex;flex-direction:column;line-height:1.3' }, h('b', { style: 'font-size:12px;color:var(--navy)' }, '課題の5人'),
        left > 0 ? h('span', { class: 'sub kfree', style: 'font-size:10.5px;max-width:86px;white-space:normal' }, `課題を出せる枠があと${left}つ`) : null),
      ...act.map((p) => { const s = YA.kadaiState(w, p); return h('button', { class: 'pitem kslot', style: 'flex:none;width:auto;min-height:40px;padding:2px 6px;gap:4px;align-items:center', onclick: () => go(p) }, YA.faceEl(w, p, 26), h('span', { style: 'display:flex;flex-direction:column;align-items:flex-start;line-height:1.25' }, h('b', { style: 'font-size:12px' }, fam(p) + ' ', h('span', { class: 'chip trait', style: 'font-size:10.5px;padding:0 5px' }, DEF(p.kd.t).short)), h('span', { class: 'sub', style: 'font-size:10.5px' }, `${s.e}/${s.len}週・${s.word}`))); }),
      act.length ? null : h('span', { class: 'sub', style: 'flex:none;font-size:11.5px' }, '手がかりを見て、選手の詳しい画面（コーチの報告）から課題を出します'));
  };
})();
