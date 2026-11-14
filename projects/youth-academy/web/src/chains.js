// 中身の厚み 1段目（仕様書「ユースの系譜 中身の厚み仕様」）：
// ・事情（38種。入団時に1人1つ。監督は面談や出来事で少しずつ知る p.bg / p.bgKnow）
// ・続き物（2話で1本、15本。結末は良い・ふつう・悪い＋隠れた4つ目。結末はその子の記憶に残る）
// ・前回を覚える（同じ子に同じ出来事が来たら、前回を踏まえた文。同じ言葉は2回目に響きにくい）
// ・掛け算（事情・信頼・季節で、よくある出来事の文を変える）
(function () {
  'use strict';
  const YA = (globalThis.YA = globalThis.YA || {});
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const sur = (p) => String(p.name).split(' ')[0];
  const absW = (w) => w.year * 40 + w.week;

  // ---------- 事情（38種）----------
  // [key, 系統, 名前]
  const BG = [
    ['poor', '家族', '片親で家計が苦しい'], ['move', '家族', '親の転勤が決まりそう'], ['siblings', '家族', '弟や妹の面倒を見ている'], ['carer', '家族', '祖父母の介護を手伝っている'],
    ['dadfan', '家族', '親がサッカー経験者で口を出す'], ['divorce', '家族', '親が離婚の話し合い中'], ['away', '家族', '親が単身赴任中'], ['familybiz', '家族', '家業を継ぐよう言われている'],
    ['brosame', '家族', '兄弟が同じクラブにいる'], ['eager', '家族', '親が熱心すぎて練習を見に来る'],
    ['bropro', '比べられる', '兄がプロ'], ['dadpro', '比べられる', '父が元プロ'], ['localstar', '比べられる', '地元で有名だった'], ['rejected', '比べられる', '他クラブのセレクションに落ちてきた'],
    ['twin', '比べられる', '双子のもう1人が別のクラブにいる'], ['rivalfriend', '比べられる', '中学の同級生が高校サッカーで有名になった'],
    ['oldinj', '体', '大きな怪我の過去がある'], ['small', '体', '体が小さい'], ['growth', '体', '急に背が伸びて膝が痛む'], ['asthma', '体', '喘息がある'],
    ['eyes', '体', '視力が弱い'], ['weight', '体', '体重の管理が苦手'], ['lefty', '体', '左利きを右に直されてきた'],
    ['convert', '生き方', '他の競技から転向してきた'], ['bench', '生き方', '中学では控えだった'], ['coach', '生き方', '指導者になりたい'], ['abroad', '生き方', '海外志向が強い'],
    ['exgk', '生き方', 'もとはGKだった'], ['returnee', '生き方', '帰国子女で言葉の壁がある'],
    ['childhood', '人', '幼なじみと一緒に入団した'], ['idol', '人', '憧れの卒業生がいる'], ['shy', '人', '内気で人前が苦手'], ['hot', '人', '負けず嫌いすぎて審判に食ってかかる'],
    ['helper', '人', '人の世話を焼きすぎる'], ['writer', '人', '口下手だが文章はうまい'],
    ['job', '危うい', '夜にアルバイトをしている'], ['sns', '危うい', 'SNSで目立つ'], ['agent', '危うい', '代理人を名乗る大人が近づいている'],
  ];
  YA.BG = BG;
  YA.BG_NAME = Object.fromEntries(BG.map((x) => [x[0], x[2]]));
  YA.BG_SYS = Object.fromEntries(BG.map((x) => [x[0], x[1]]));
  const SYS_HINT = { 家族: '家のことで何か抱えていそうだ', 比べられる: '誰かと比べられるのを気にしている', 体: '体のことで何かありそうだ', 生き方: 'サッカーの先のことを考えていそうだ', 人: '人との関わりに何かありそうだ', 危うい: '練習の外で何か起きていそうだ' };
  YA.bgOf = function (w, p) {
    if (p.bg) return p.bg;
    let list = BG.map((x) => x[0]);
    if (p.pos === 'GK') list = list.filter((k) => k !== 'exgk');
    if (!(w && (w.alumni || []).some((a) => a.status === 'pro'))) list = list.filter((k) => k !== 'idol');
    p.bg = list[YA.hash(String(p.id) + p.name + 'bg') % list.length];
    if (p.bgKnow == null) p.bgKnow = 0;
    return p.bg;
  };
  YA.bgText = function (w, p) {
    const k = YA.bgOf(w, p);
    const n = p.bgKnow || 0;
    return n >= 2 ? YA.BG_NAME[k] : n === 1 ? `うすうす：${SYS_HINT[YA.BG_SYS[k]]}` : 'まだ分からない（面談や出来事で分かってくる）';
  };
  YA.bgReveal = function (w, p, to) {
    YA.bgOf(w, p);
    const before = p.bgKnow || 0;
    p.bgKnow = Math.max(before, Math.min(2, to == null ? before + 1 : to));
    if (before < 2 && p.bgKnow === 2 && p.hist) p.hist.unshift({ y: w.year, w: w.week, t: `事情が分かった：${YA.BG_NAME[p.bg]}` });
  };
  // 面談：信頼が「ふつう」以上なら、事情が一段わかる
  const talk0 = YA.talk;
  YA.talk = function (w, pid, k) {
    const r = talk0.apply(this, arguments);
    const p = w.players[pid];
    if (p && YA.trustLv(p) >= 3) YA.bgReveal(w, p);
    return r;
  };
  // スカウトで会って入った子は「うすうす」から
  const intake0 = YA.intake;
  YA.intake = function (w) {
    const S = w.scouting;
    const met = new Set(S ? S.cands.filter((c) => c.status === 'signed' && c.seen >= 1).map((c) => c.p.id) : []);
    const r = intake0.apply(this, arguments);
    for (const p of Object.values(w.players)) if (met.has(p.id)) { YA.bgOf(w, p); p.bgKnow = Math.max(p.bgKnow || 0, 1); }
    return r;
  };

  // ---------- 本人の言葉（丁寧／くだけた）----------
  const CASUAL = new Set(['元気', '熱血', 'お調子者', '生意気', 'ぶっきらぼう']);
  const casual = (p) => YA.toneOf && CASUAL.has(YA.toneOf(p));
  const casualize = (s) => s.replace(/ありがとうございました/g, 'あざした').replace(/でした([。」]|$)/g, 'だったっす$1').replace(/ました([。」]|$)/g, 'たっす$1').replace(/です([。」]|$)/g, 'っす$1');
  YA.voice = function (p, s) {
    let t = casual(p) ? casualize(s) : s;
    if (YA.toneOf && YA.toneOf(p) === '無口') t = '……' + t;
    if (YA.toneOf && YA.toneOf(p) === '弱気') t = t.replace(/^/, 'あの……');
    return t;
  };
  const say = (p, s) => `${sur(p)}「${YA.voice(p, s)}」`;

  // ---------- 続き物（15本）----------
  // 各話：text(p,w,st) と opts [ラベル, 接し方, 点, 効き目(w,p,st)]。点の合計で結末（2以上=良・0〜1=ふつう・負=悪）。hidden は条件がそろったときの4つ目
  const conf = (p, d) => { p.conf = clamp((p.conf || 50) + d, 0, 100); };
  const unrest = (p, d) => { p.unrest = Math.max(0, (p.unrest || 0) + d); };
  const ab = (p, a, d) => { if (p.ab && p.ab[a] != null) p.ab[a] = clamp(p.ab[a] + d, 1, 20); };
  const proAlum = (w) => (w.alumni || []).filter((a) => a.status === 'pro' && !a.retired).sort((a, b) => (b.bond || 3) - (a.bond || 3) || b.ovr - a.ovr)[0];
  const CH = {
    poor: { name: '家計', eps: [
      { t: (p) => `${p.name}が、練習のあと残っていた。${say(p, '遠征費のこと、親が気にしてて……。行かなくてもいいですか')}`,
        o: [['じっくり話を聞く', 'warm', 1], ['クラブに相談してみる、と約束する', 'push', 2, (w, p, st) => { st.club = 1; }], ['今は様子を見る', 'wait', -1]] },
      { t: (p, w, st) => `${p.name}の家計の話の続き。${st.club ? 'クラブから「遠征費を減らせる制度がある」と返事が来た。' : '最近、練習を休む日が出てきた。'}${say(p, '続けたいんです。でも、家のことも')}`,
        o: [['寮に入ることを勧める', 'push', 1, (w, p, st) => { st.dorm = 1; }], ['遠征費の免除をクラブに掛け合う', 'warm', 2], ['本人の判断に任せる', 'wait', -1]] }],
      ends: {
        hidden: { if: (w, p, st) => st.sc >= 3 && proAlum(w) && (proAlum(w).bond || 3) >= 4, t: (w, p) => `卒業生の${proAlum(w).name}が「後輩の遠征費は自分が出します」と申し出てくれた。`, fx: (w, p) => { conf(p, 12); unrest(p, -3); }, m: '先輩が遠征費を出してくれて、続けられました。いつか自分も同じことをします。' },
        good: { t: '続けられることになった。', fx: (w, p) => { conf(p, 8); unrest(p, -3); }, m: '監督がクラブに掛け合ってくれたから、続けられました。' },
        mid: { t: '寮に入って、家の負担を減らして続けることになった。', fx: (w, p) => { conf(p, 3); }, m: '寮に入れてもらって、家の負担が減りました。' },
        bad: { t: 'チームを離れることになった。', fx: (w, p) => { p._leave = true; p._qr = '家庭'; }, m: 'あのとき、続けられませんでした。' } } },
    move: { name: '転勤', eps: [
      { t: (p) => `${say(p, '親の転勤が決まりそうなんです。ここを離れたくないです')}`, o: [['寮に残る道を一緒に考える', 'warm', 2], ['親を説得しに行く', 'push', 1], ['家族で決めることだと伝える', 'wait', -1]] },
      { t: (p) => `${p.name}の家で話し合いがあったらしい。${say(p, '親は、来てほしいって')}`, o: [['寮母さんに後見を頼む', 'warm', 1, (w, p, st) => { st.mom = 1; }], ['週末だけ家に帰る形を作る', 'push', 1], ['送り出す準備をする', 'wait', -2]] }],
      ends: {
        hidden: { if: (w, p, st) => st.sc >= 3 && st.mom, t: '寮母さんが「この子はうちで預かります」と親を説得してくれた。', fx: (w, p) => { conf(p, 10); }, m: '寮母さんが親を説得してくれたこと、一生忘れません。' },
        good: { t: 'ここに残ることになった。', fx: (w, p) => { conf(p, 6); }, m: '転勤のとき、残る道を一緒に探してもらいました。' },
        mid: { t: '残ることにはなったが、気持ちは揺れている。', fx: (w, p) => { conf(p, -3); }, m: '家族と離れて、寂しい時期もありました。' },
        bad: { t: '家族と一緒に、遠くへ移ることになった。', fx: (w, p) => { p._leave = true; p._qr = '家庭'; }, m: '親の転勤で、ここを離れました。' } } },
    bropro: { name: '兄との比較', eps: [
      { t: (p) => `${p.name}の兄の活躍がニュースになった。練習のあと、${say(p, 'また兄のことを聞かれました')}`, o: [['兄の試合を一緒に見に行く', 'push', 2], ['「比べるな。お前はお前だ」と言う', 'warm', 1], ['何も言わない', 'wait', -1]] },
      { t: (p) => `${p.name}に兄から電話があったらしい。表情が読めない。`, o: [['自分の武器を一緒に探す', 'push', 2], ['兄に相談してみろと言う', 'warm', 1], ['黙って見守る', 'wait', 0]] }],
      ends: {
        hidden: { if: (w, p, st) => st.sc >= 4, t: (w, p) => `${p.name}の兄が、オフに練習へ来てくれた。チーム中が沸いた。`, fx: (w, p) => { conf(p, 10); for (const q of Object.values(w.players)) if (q.team === 'A') conf(q, 2); }, m: '兄が練習に来てくれた日、やっと兄と比べなくなりました。' },
        good: { t: '吹っ切れたようだ。動きが軽くなった。', fx: (w, p) => { conf(p, 8); p.spurt = Math.max(p.spurt || 0, 2); }, m: '兄と比べなくていいって、やっと思えました。' },
        mid: { t: 'まだ少し引きずっている。', fx: (w, p) => { conf(p, -2); }, m: 'ずっと兄と比べられて、苦しかったです。' },
        bad: { t: 'こじれてしまった。練習で荒れている。', fx: (w, p) => { unrest(p, 3); conf(p, -6); }, m: '兄のことで、監督ともぶつかりました。' } } },
    localstar: { name: '期待の重さ', eps: [
      { t: (p) => `地元の新聞から、${p.name}に取材の依頼が来た。中学のころから名の知れた子だ。`, o: [['受けさせる', 'push', 0, (w, p, st) => { st.media = 1; if (YA.addRep) YA.addRep(w, 1); }], ['今は断る', 'warm', 2], ['本人に決めさせる', 'wait', 1]] },
      { t: (p) => `${p.name}が伸び悩んでいる。${say(p, '最近、何をやってもうまくいかないです')}`, o: [['試合から外して休ませる', 'warm', 1], ['あえて使い続ける', 'push', 1], ['「期待に応えろ」と言う', 'firm', -1]] }],
      ends: {
        hidden: { if: (w, p, st) => st.media && st.sc >= 2, t: '取材した記者が「重圧の中で戦う17歳」という記事を書き、応援の手紙が届くようになった。', fx: (w, p) => { conf(p, 10); if (YA.addRep) YA.addRep(w, 2); }, m: '記事が出てから、応援の手紙が支えになりました。' },
        good: { t: '吹っ切れて、また伸び始めた。', fx: (w, p) => { conf(p, 8); p.spurt = Math.max(p.spurt || 0, 2); }, m: '期待に押しつぶされそうなとき、守ってもらいました。' },
        mid: { t: '波のある日々が続いている。', fx: (w, p) => { conf(p, -2); }, m: '期待されるのが、ずっと重かったです。' },
        bad: { t: '自信を大きくなくしてしまった。', fx: (w, p) => { conf(p, -12); }, m: 'あのころは、期待に潰れていました。' } } },
    job: { name: 'アルバイト', eps: [
      { t: (p) => `トレーナーが気づいた。${p.name}が夜にアルバイトをしているらしい。疲れが抜けていない。`, o: [['事情を聞く', 'warm', 2], ['規則だからやめさせる', 'firm', -1], ['見なかったことにする', 'wait', 0, (w) => { w.disc = clamp((w.disc || 60) - 2, 0, 100); }]] },
      { t: (p) => `${say(p, '家に少しでも入れたくて……')}`, o: [['昼の手伝いに替えられないか探す', 'push', 2], ['クラブに相談する', 'warm', 1, (w, p, st) => { st.club = 1; }], ['本人に任せる', 'wait', -1]] }],
      ends: {
        hidden: { if: (w, p, st) => st.sc >= 3 && st.club, t: 'クラブのスポンサーが、練習のない日の仕事を世話してくれた。', fx: (w, p) => { conf(p, 10); p.fat = clamp((p.fat || 0) - 10, 0, 100); }, m: 'スポンサーさんの店で働かせてもらって、練習に集中できました。' },
        good: { t: '夜の仕事をやめて、昼の手伝いに替えた。', fx: (w, p) => { conf(p, 6); p.fat = clamp((p.fat || 0) - 8, 0, 100); }, m: '夜のアルバイトのこと、怒らずに聞いてもらえました。' },
        mid: { t: 'アルバイトは続いている。疲れは残ったままだ。', fx: (w, p) => { p.fat = clamp((p.fat || 0) + 6, 0, 100); }, m: '夜も働きながら、なんとか続けていました。' },
        bad: { t: '練習に来なくなった。', fx: (w, p) => { p._leave = true; p._qr = '家庭'; }, m: '働くことを選びました。' } } },
    growth: { name: '成長期', eps: [
      { t: (p) => `${say(p, '膝が痛くて……。背が急に伸びてるんです')}`, o: [['しっかり休ませる', 'warm', 2, (w, p) => { p.rest = 'rest'; }], ['軽めのメニューにする', 'wait', 1, (w, p) => { p.rest = 'light'; }], ['このまま続けさせる', 'push', -2]] },
      { t: (p) => `${p.name}の膝の具合の続き。トレーナーは「体ができるまで、もう少し」と言う。`, o: [['体ができるまで待つ', 'warm', 1], ['別の位置を試してみる', 'push', 1, (w, p, st) => { st.pos = 1; }], ['手術も考えるよう勧める', 'firm', -1]] }],
      ends: {
        hidden: { if: (w, p, st) => st.pos && st.sc >= 2, t: (w, p) => `試しに置いた位置で、${p.name}が見違えるように動いた。新しい居場所が見つかったかもしれない。`, fx: (w, p) => { p.pot += 25; conf(p, 8); }, m: '膝を痛めたときに試した位置が、自分の居場所になりました。' },
        good: { t: '痛みが引き、体が大きくなって一気に伸び始めた。', fx: (w, p) => { p.pot += 30; p.spurt = Math.max(p.spurt || 0, 3); }, m: '膝が痛かった時期に、待ってもらえたから今の体があります。' },
        mid: { t: '痛みが長引いている。', fx: (w, p) => { conf(p, -3); }, m: '成長痛が長引いて、焦った時期がありました。' },
        bad: { t: '無理がたたって、しばらく離脱することになった。', fx: (w, p) => { p.inj = Math.max(p.inj || 0, 6); }, m: '膝を無理して、長く離れました。' } } },
    idol: { name: '憧れの卒業生', eps: [
      { t: (p, w) => { const a = proAlum(w); return `${say(p, `${a ? a.name + 'さん' : '先輩'}みたいになりたいんです`)}（${a ? a.club : ''}）`; }, o: [['会わせる約束をする', 'push', 2, (w, p, st) => { const a = proAlum(w); st.who = a ? a.name : null; }], ['応援すると伝える', 'warm', 1], ['「自分の道を行け」と言う', 'firm', 0]] },
      { t: (p, w, st) => `${st.who ? st.who + 'が、約束どおり練習場に来てくれた。' : '憧れの先輩の話の続き。'}${p.name}は緊張で固まっている。`, o: [['一緒に練習してもらう', 'push', 1], ['二人で話す時間を作る', 'warm', 1], ['顔を見せてもらうだけにする', 'wait', -1]] }],
      ends: {
        hidden: { if: (w, p, st) => st.who && st.sc >= 3, t: (w, p, st) => `${st.who}が、自分のユース時代の背番号のことを${p.name}に話して帰っていった。「この番号、いつか着けてくれ」`, fx: (w, p) => { conf(p, 12); p.pot += 15; }, m: '憧れの先輩に「この番号を着けてくれ」と言われた日のこと、覚えています。' },
        good: { t: 'はっきりした目標ができたようだ。', fx: (w, p) => { conf(p, 10); }, m: '憧れの先輩に会わせてもらって、目標ができました。' },
        mid: { t: '刺激にはなったようだ。', fx: (w, p) => { conf(p, 3); }, m: '先輩に会って、まだ遠いと思いました。' },
        bad: { t: '思っていた人と違ったらしい。少し気落ちしている。', fx: (w, p) => { conf(p, -6); }, m: '憧れの人に会って、少しがっかりしたこともありました。' } } },
    oldinj: { name: '古傷', eps: [
      { t: (p) => `${say(p, '前に痛めたところが、また少し……')}`, o: [['すぐ医者に診てもらう', 'warm', 2, (w, p) => { p.rest = 'rest'; }], ['本人の感覚を尊重する', 'wait', 0], ['大事な試合だから出す', 'push', -2]] },
      { t: (p) => `${p.name}の復帰の時期。トレーナーは「もう一週あれば確実です」と言う。`, o: [['少しずつ試合に戻す', 'warm', 1], ['もう一週待つ', 'wait', 1], ['先発で戻す', 'push', 0]] }],
      ends: {
        hidden: { if: (w, p, st) => st.sc >= 3, t: (w, p) => `休んでいるあいだ、${p.name}はずっと試合を外から見ていた。戻ってきたら、周りがよく見えるようになっていた。`, fx: (w, p) => { ab(p, '判断', 1); ab(p, '視野', 1); }, m: '怪我で外から見ていた時期に、サッカーの見え方が変わりました。' },
        good: { t: '完全に戻ってきた。', fx: (w, p) => { conf(p, 6); }, m: '古傷が痛んだとき、焦らせないでもらえました。' },
        mid: { t: 'まだ少しかばって走っている。', fx: (w, p) => { conf(p, -2); }, m: '古傷とずっと付き合ってきました。' },
        bad: { t: '再発してしまった。', fx: (w, p) => { p.inj = Math.max(p.inj || 0, 5); conf(p, -6); }, m: '無理をして、また痛めてしまいました。' } } },
    dadpro: { name: '元プロの父', eps: [
      { t: (p) => `${say(p, '父が、監督の練習は甘いって言ってて……')}`, o: [['父と話す場を作る', 'push', 2], ['本人に任せる', 'wait', 0], ['練習に口を出さないよう伝えてもらう', 'firm', -1]] },
      { t: (p) => `${p.name}の父が練習を見に来た。腕を組んで、じっと見ている。`, o: [['ゲストとして一言お願いする', 'warm', 1, (w, p, st) => { st.guest = 1; }], ['練習の狙いを説明しに行く', 'push', 1], ['気にせず続ける', 'firm', -1]] }],
      ends: {
        hidden: { if: (w, p, st) => st.guest && st.sc >= 3, t: (w, p) => `${p.name}の父が、元プロとして子どもたちに話をしてくれた。帰りぎわ「いいチームですね」と頭を下げていった。`, fx: (w) => { for (const q of Object.values(w.players)) if (q.team === 'A') conf(q, 3); }, m: '父がチームの前で話した日、初めて父と監督が並んで見えました。' },
        good: { t: '父も納得したようだ。本人の顔が明るい。', fx: (w, p) => { conf(p, 6); unrest(p, -2); }, m: '父と監督の間で悩んでいたとき、間に入ってもらいました。' },
        mid: { t: '板挟みは続いている。', fx: (w, p) => { conf(p, -2); }, m: '父と監督の間で、ずっと迷っていました。' },
        bad: { t: '父との関係がこじれ、本人も荒れている。', fx: (w, p) => { unrest(p, 4); }, m: '父のことで、チームにも迷惑をかけました。' } } },
    agent: { name: '代理人', eps: [
      { t: (p) => `${say(p, '代理人だという人に、早くプロと契約しようと言われて……')}`, o: [['クラブとして間に入る', 'push', 2], ['自分で断れるよう一緒に考える', 'warm', 1], ['本人に任せる', 'wait', -2]] },
      { t: (p) => `例の大人が、また${p.name}に接触してきたらしい。今度は親にも連絡が来た。`, o: [['両親とも話す', 'warm', 1], ['クラブの弁護士に相談する', 'push', 1, (w, p, st) => { st.law = 1; }], ['何もしない', 'wait', -2]] }],
      ends: {
        hidden: { if: (w, p, st) => st.law && st.sc >= 2 && YA.rate(YA.ovr(p)) >= 100, t: '調べてみると、本物の代理人だった。海外のクラブが本当に興味を持っているらしい。', fx: (w, p) => { conf(p, 10); p.pot += 10; }, m: '怪しいと思った人が本物の代理人で、守ってもらいながら話を聞けました。' },
        good: { t: 'クラブが間に入り、話は収まった。', fx: (w, p) => { conf(p, 5); }, m: '怪しい大人から、クラブが守ってくれました。' },
        mid: { t: '自分で断った。少し疲れた顔をしている。', fx: (w, p) => { conf(p, -1); }, m: '代理人の話を、自分で断りました。' },
        bad: { t: '話に乗ってしまい、チームを去ることになった。', fx: (w, p) => { p._leave = true; p._qr = '不満'; }, m: '大人の話に乗って、ここを出ました。' } } },
    familybiz: { name: '家業', eps: [
      { t: (p) => `${say(p, '卒業したら、家の店を継ぐことになってて')}`, o: [['両立できる道を一緒に考える', 'warm', 2], ['「プロを目指せ」と言う', 'push', 1], ['家の判断を尊重する', 'wait', 0]] },
      { t: (p) => `${p.name}の家族と話す機会ができた。店の話になると、父親の顔が固くなる。`, o: [['家族と面談する', 'push', 2], ['本人とだけ話す', 'warm', 1], ['何もしない', 'wait', -1]] }],
      ends: {
        hidden: { if: (w, p, st) => st.sc >= 4, t: (w, p) => `${p.name}の家の店が、クラブのスポンサーになってくれた。「息子が世話になってますから」`, fx: (w) => { w.fund = (w.fund || 0) + 200; w.fundIn = (w.fundIn || 0) + 200; }, m: '家の店がクラブのスポンサーになって、親も応援してくれるようになりました。' },
        good: { t: '家族も、サッカーを続けることを認めてくれた。', fx: (w, p) => { conf(p, 6); }, m: '家業のことを、家族と一緒に考えてもらいました。' },
        mid: { t: '話は先送りになった。', fx: () => {}, m: '店を継ぐかどうか、ずっと迷っていました。' },
        bad: { t: '家族とぶつかってしまった。', fx: (w, p) => { conf(p, -6); unrest(p, 2); }, m: '家とぶつかって、苦しい時期がありました。' } } },
    asthma: { name: '喘息', eps: [
      { t: (p) => `${say(p, '最近、走ると息が苦しくなることがあって')}`, o: [['病院に連れていく', 'warm', 2, (w, p) => { p.rest = 'light'; }], ['練習量を減らす', 'wait', 1], ['気持ちで乗り越えさせる', 'firm', -2]] },
      { t: (p) => `${p.name}の薬が決まった。走る量をどうするか、トレーナーが相談してきた。`, o: [['薬と付き合い方を一緒に決める', 'warm', 1], ['走るメニューを外す', 'wait', 0], ['元のメニューに戻す', 'push', -1]] }],
      ends: {
        hidden: { if: (w, p, st) => st.sc >= 3, t: (w, p) => `${p.name}は自分の体を自分で管理できるようになった。試合でも落ち着いている。`, fx: (w, p) => { ab(p, '集中', 1); ab(p, '冷静さ', 1); }, m: '喘息と付き合ううちに、自分の体を自分で管理できるようになりました。' },
        good: { t: '息苦しさが落ち着いた。', fx: (w, p) => { conf(p, 5); }, m: '喘息のとき、すぐ病院に連れていってもらいました。' },
        mid: { t: 'うまく付き合いながら続けている。', fx: () => {}, m: '喘息とは今も付き合っています。' },
        bad: { t: '走る量が落ちてしまった。', fx: (w, p) => { ab(p, 'スタミナ', -1); }, m: '喘息で、走れなくなった時期がありました。' } } },
    weight: { name: '体重', eps: [
      { t: (p) => `${p.name}の体が重そうだ。${say(p, '食べるの、やめられなくて')}`, o: [['栄養の指導を受けさせる', 'warm', 2], ['走らせて絞る', 'firm', 0], ['本人に任せる', 'wait', -1]] },
      { t: (p) => `${p.name}の食事の続き。寮の夕食をどうするか。`, o: [['寮母さんに頼む', 'warm', 1, (w, p, st) => { st.mom = 1; }], ['毎週体重を計る', 'push', 1], ['何もしない', 'wait', -1]] }],
      ends: {
        hidden: { if: (w, p, st) => st.mom && st.sc >= 3, t: '寮母さんが考えた献立が、寮の名物になった。', fx: (w) => { for (const q of Object.values(w.players)) q.fat = clamp((q.fat || 0) - 4, 0, 100); }, m: '寮母さんの献立のおかげで、体が変わりました。' },
        good: { t: '体が絞れて、動きが速くなった。', fx: (w, p) => { ab(p, 'スピード', 1); ab(p, '加速', 1); }, m: '体重のこと、一緒に向き合ってもらいました。' },
        mid: { t: '体重は横ばいのままだ。', fx: () => {}, m: '体重とはずっと戦っていました。' },
        bad: { t: '体が重く、走れなくなっている。', fx: (w, p) => { ab(p, 'スタミナ', -1); }, m: '体重のことで、悔しい思いをしました。' } } },
    coach: { name: '指導者志望', eps: [
      { t: (p) => `${p.name}が、高1に身ぶりで何か教えている。${say(p, '教えるの、好きなんです')}`, o: [['後輩の練習を任せてみる', 'push', 2, (w, p) => { const k = Object.values(w.players).filter((q) => q.grade === 1 && q.pos === p.pos); for (const q of k.slice(0, 2)) { q.prog = q.prog || {}; q.prog.判断 = (q.prog.判断 || 0) + 0.6; } }], ['まず自分を磨けと言う', 'firm', 0], ['応援する', 'warm', 1]] },
      { t: (p) => `${say(p, '将来、ここでコーチをやりたいんです')}`, o: [['コーチの補佐をさせる', 'push', 2], ['指導の本を貸す', 'warm', 1], ['今は選手に集中させる', 'wait', -1]] }],
      ends: {
        hidden: { if: (w, p, st) => st.sc >= 4, t: (w, p) => `${p.name}の教えた高1が、目に見えて伸びた。コーチ陣が「あれは本物だ」と言っている。`, fx: (w, p) => { p.coachPath = 2; }, m: '後輩を任せてもらったのが、指導者になる始まりでした。いつか、ここに戻ります。' },
        good: { t: '指導者の道を、本気で考え始めた。', fx: (w, p) => { p.coachPath = 1; }, m: '後輩に教えさせてもらって、指導者になりたいと思いました。' },
        mid: { t: 'まずは選手として頑張るらしい。', fx: () => {}, m: 'コーチになりたい気持ちは、今もあります。' },
        bad: { t: '教えることに自信をなくしたようだ。', fx: (w, p) => { conf(p, -4); }, m: '教えるのは難しいと知りました。' } } },
    hot: { name: '審判への抗議', eps: [
      { t: (p) => `${p.name}が審判に食ってかかり、退場になった。ロッカーで黙り込んでいる。`, o: [['厳しく叱る', 'firm', 1], ['まず気持ちを聞く', 'warm', 1], ['次の試合は外す', 'push', 0]] },
      { t: (p) => `${p.name}の退場の件の続き。主将が「自分が見ておきます」と言ってきた。`, o: [['冷静さの練習を一緒に組む', 'warm', 2], ['主将に見張らせる', 'push', 1], ['放っておく', 'wait', -1]] }],
      ends: {
        hidden: { if: (w, p, st) => st.sc >= 4, t: (w, p) => `${p.name}が、地域のフェアプレー賞に選ばれた。あの退場から半年だ。`, fx: (w, p) => { ab(p, '冷静さ', 2); if (YA.addRep) YA.addRep(w, 2); }, m: '退場した自分が、フェアプレー賞をもらいました。' },
        good: { t: '試合で熱くなっても、踏みとどまれるようになった。', fx: (w, p) => { ab(p, '冷静さ', 2); }, m: '審判に食ってかかった僕を、見捨てないでもらいました。' },
        mid: { t: 'ときどき、まだ熱くなる。', fx: (w, p) => { ab(p, '冷静さ', 1); }, m: '熱くなりやすいのは、今も直っていません。' },
        bad: { t: 'また同じことを繰り返した。', fx: (w, p) => { w.disc = clamp((w.disc || 60) - 3, 0, 100); conf(p, -4); }, m: '退場を繰り返して、迷惑をかけました。' } } },
  };
  YA.CHAINS = CH;
  YA.CHAIN_NAME = Object.fromEntries(Object.entries(CH).map(([k, c]) => [k, c.name]));

  YA.EVENTS.push({ id: 'chain', name: '続き物', weight: 0, pick: () => null, text: () => '', opts: [] });
  YA.EVENT_ABOUT = YA.EVENT_ABOUT || {};
  YA.EVENT_ABOUT.chain = 'その子の事情から始まる、数週にわたる話です。どう向き合ったかの積み重ねで結末が変わり、条件がそろうと思わぬ結末もあります。結末はその子の記憶に残ります。';
  const chainOf = (w, e) => (w.chains || []).find((c) => c.id === e.cid);
  function endOf(w, p, c) {
    const d = CH[c.k];
    if (d.ends.hidden && d.ends.hidden.if(w, p, c.st) && YA.hash(c.id + 'hid') % 2 === 0) return 'hidden';
    return c.st.sc >= 2 ? 'good' : c.st.sc >= 0 ? 'mid' : 'bad';
  }
  const txt = (f, w, p, st) => (typeof f === 'function' ? f(w, p, st) : f);
  function chainPrep(w, e) {
    const c = chainOf(w, e);
    const def = YA.EVENTS.find((x) => x.id === 'chain');
    const p = w.players[e.pid];
    if (!c || !def || !p) return;
    const d = CH[c.k];
    const ep = d.eps[c.ep];
    const last = c.ep === d.eps.length - 1;
    def.name = `${d.name}（${c.ep + 1}/${d.eps.length}）`;
    def.text = () => ep.t(p, w, c.st);
    const order = ep.o.map((x, i) => i).sort((a, b) => (YA.hash(c.id + c.ep + a) % 97) - (YA.hash(c.id + c.ep + b) % 97));
    def.opts = order.map((i) => ep.o[i]).map(([label, kind, sc, fx], j) => ({ label, kind, extra: (ww, q) => {
      const i = order[j];
      c.st.sc += sc;
      c.st.picks.push(i);
      if (fx) fx(ww, q, c.st);
      if (!last) { c.ep++; c.due = absW(ww) + 2 + (YA.hash(c.id + c.ep) % 2); return; }
      const end = endOf(ww, q, c);
      const E = d.ends[end];
      c.done = true;
      c.end = end;
      E.fx(ww, q, c.st);
      c.line = txt(E.t, ww, q, c.st);
      q.chainDone = Object.assign({}, q.chainDone, { [c.k]: end });
      YA.bgReveal(ww, q, 2);
      if (YA.memAdd) YA.memAdd(ww, q, 'chain', kind, YA.voice(q, E.m), { ch: c.k, end });
      YA.noteTier(ww, end === 'hidden' ? 1 : 2, `${q.name}の「${d.name}」：${c.line}`, q.id);
    } }));
  }
  const v0 = YA.eventView;
  YA.eventView = function (w, e) { if (e.id === 'chain') chainPrep(w, e); return v0.apply(this, arguments); };
  const r0 = YA.resolveEvent;
  YA.resolveEvent = function (w, e, idx) {
    if (e.id !== 'chain') return r0.apply(this, arguments);
    chainPrep(w, e);
    const c = chainOf(w, e);
    const out = r0.apply(this, arguments);
    if (c && c.done && out) out.line = c.line + (out.line ? `（${out.line}）` : '');
    else if (c && out) out.small = (out.small ? out.small + '・' : '') + '話は続く（数週あとに）';
    return out;
  };

  // 始める・次の話を出す（毎週）
  YA.CHAIN_MAX = 2;
  YA.chainWeek = function (w) {
    w.chains = (w.chains || []).filter((c) => !c.done && w.players[c.pid]);
    const now = absW(w);
    for (const c of w.chains) {
      if (c.due <= now && c.shown !== c.ep) {
        c.shown = c.ep;
        w.forced = (w.forced || []).concat([{ id: 'chain', cid: c.id, pid: c.pid, week: w.week, year: w.year }]);
      }
    }
    if (w.chains.length >= YA.CHAIN_MAX || w.week >= YA.WEEKS - 2) return;
    const r = YA.rngOf((w.seed | 0) * 41 + now * 7);
    if (!r.chance(0.16)) return;
    const busy = new Set(w.chains.map((c) => c.pid));
    const recent = w.chainRecent || [];
    const all = Object.values(w.players).filter((p) => !busy.has(p.id) && CH[YA.bgOf(w, p)] && !(p.chainDone || {})[p.bg] && !(p.inj > 0) && (p.bg !== 'idol' || proAlum(w)));
    const fresh = all.filter((p) => recent.indexOf(p.bg) < 0);
    const cands = fresh.length ? fresh : all;
    if (!cands.length) return;
    const p = cands[r.int(0, cands.length - 1)];
    w.chainRecent = recent.concat([p.bg]).slice(-6);
    const c = { id: 'ch' + now + '_' + p.id, k: p.bg, pid: p.id, ep: 0, due: now, shown: 0, st: { sc: 0, picks: [] } };
    w.chains.push(c);
    YA.bgReveal(w, p, 2);
    w.forced = (w.forced || []).concat([{ id: 'chain', cid: c.id, pid: p.id, week: w.week, year: w.year }]);
  };
  const rw0 = YA.rivalWeek;
  YA.rivalWeek = function (w) {
    const res = rw0 ? rw0.apply(this, arguments) : undefined;
    const key = w.year * 100 + w.week;
    if (w.chainKey !== key) { w.chainKey = key; YA.chainWeek(w); }
    return res;
  };

  // ---------- 前回を覚える・掛け算（よくある出来事）----------
  const COMMON = new Set(['unrest', 'lowconf', 'injury', 'quit', 'hot', 'rival', 'rivalry', 'family', 'homesick', 'parent', 'tired']);
  // 事情ごとの、悩みの中身（知っていれば文に出る）
  const BG_FLAVOR = {
    poor: '家のお金のことも、頭から離れないらしい', move: '親の転勤の話も重なっている', siblings: '家で弟や妹の面倒を見る日が続いている', carer: '祖父母の介護で、寝不足が続いている',
    dadfan: '家に帰ると、父親に試合のことを言われるらしい', divorce: '家の中が落ち着かないらしい', away: '父親が単身赴任で、相談できる人がいない', familybiz: '家業のことも、心のどこかにある',
    brosame: '同じクラブの兄弟と比べられている', eager: '親が毎回、練習を見に来ている', bropro: 'プロの兄と、また比べられたらしい', dadpro: '元プロの父親の目が気になっている',
    localstar: '地元の期待が重い', rejected: '落ちたクラブを見返したい気持ちが空回りしている', twin: '別のクラブにいる双子が活躍している', rivalfriend: '中学の同級生がテレビに出ていた',
    oldinj: '古傷をかばう癖が抜けない', small: '体の大きな相手に当たり負けしている', growth: '膝の痛みが気になっている', asthma: '息苦しさを隠していた', eyes: 'ボールが見えにくい日があるらしい',
    weight: '体の重さを気にしている', lefty: '本当は左で蹴りたいらしい', convert: '前の競技のほうが向いていたのでは、と迷っている', bench: '中学で控えだったころを思い出している',
    coach: '自分より後輩のことを気にしている', abroad: '海外のことばかり考えている', exgk: 'GKに戻りたい気持ちもあるらしい', returnee: '言葉の壁で、うまく伝えられない',
    childhood: '幼なじみと差がついてきた', idol: '憧れの先輩との差を感じている', shy: '人前で話すのが苦手で、言い出せずにいた', hot: '気持ちを抑えきれずにいる',
    helper: '人の世話ばかりで、自分のことが後回しになっている', writer: '口では言えないことを、ノートに書いていた', job: '夜のアルバイトで疲れが抜けない', sns: 'SNSの書き込みを気にしている', agent: '怪しい大人の言葉が頭から離れない',
  };
  const SEASON = (w) => (w.week >= 31 && w.week <= 36 ? '雪の残るグラウンドで。' : w.week >= 13 && w.week <= 18 ? '蒸し暑い練習のあと。' : w.week >= 6 && w.week <= 9 ? '雨の日の練習のあと。' : '');
  const quoteOf = (label) => { const m = /「([^」]+)」/.exec(label || ''); return m ? m[1] : String(label || '').replace(/（[^）]*）/g, '').trim(); };
  const ev1 = YA.eventView;
  YA.eventView = function (w, e) {
    const v = ev1.apply(this, arguments);
    if (!v || !COMMON.has(e.id) || !e.pid) return v;
    const p = w.players[e.pid];
    if (!p) return v;
    const pre = [];
    const last = (p.mem || []).filter((m) => m.k === e.id).slice(-1)[0];
    if (last) pre.push(last.y === w.year ? `（${last.w}週にも同じことがあった。そのときは「${last.q}」）` : `（${w.year - last.y}年前、高${last.g || '?'}のときにも同じことがあった。そのときは「${last.q}」）`);
    const s = SEASON(w);
    const lv = YA.trustLv(p);
    let tail = '';
    if (lv <= 2) tail = '本音は話してくれなかった。';
    else if ((p.bgKnow || 0) >= 2) tail = BG_FLAVOR[YA.bgOf(w, p)] ? `${BG_FLAVOR[p.bg]}。` : '';
    else if ((p.bgKnow || 0) === 1) tail = `${SYS_HINT[YA.BG_SYS[YA.bgOf(w, p)]]}。`;
    if (last && lv >= 4) tail += say(p, 'また同じことで、すみません');
    v.text = pre.join('') + s + v.text + (tail ? ' ' + tail : '');
    return v;
  };
  const r1 = YA.resolveEvent;
  YA.resolveEvent = function (w, e, idx) {
    const p = e.pid ? w.players[e.pid] : null;
    if (!p || !COMMON.has(e.id)) return r1.apply(this, arguments);
    const def = YA.EVENTS.find((x) => x.id === e.id);
    const o = def && def.opts[idx];
    const last = (p.mem || []).filter((m) => m.k === e.id).slice(-1)[0];
    const out = r1.apply(this, arguments);
    if (o && o.kind && w.players[p.id]) {
      if (last && last.c === o.kind && o.kind !== 'wait') {
        conf(p, -3);
        if (out) out.small = (out.small ? out.small + '・' : '') + '前と同じ言葉は、響きにくかった（自信 −3）';
      }
      // ★でない子も、よくある出来事は記憶に残す（★の子は memory.js が残す）
      if (!p.star && YA.memAdd) YA.memAdd(w, p, e.id, o.kind, quoteOf(o.label));
      if (YA.trustLv(p) >= 3 && YA.hash(p.id + w.week) % 3 === 0) YA.bgReveal(w, p);
    }
    return out;
  };
  // 年度はじめ：信頼の深い子は、事情を自分から話す
  const ys0 = YA.yearStart;
  YA.yearStart = function (w) {
    const r = ys0.apply(this, arguments);
    for (const p of Object.values(w.players)) { YA.bgOf(w, p); if (YA.trustLv(p) >= 4) YA.bgReveal(w, p); }
    return r;
  };
  YA.EXTRA_SIM_IMPORTANT = YA.EXTRA_SIM_IMPORTANT || [];
})();
