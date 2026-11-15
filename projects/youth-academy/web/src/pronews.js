// プロの卒業生からの知らせ（2026-11-15「プロからの情報をもっと増やして・パターンふやして」）。
// これまでは年度末にまとめて（移籍・優勝・賞・代表）だけだった。シーズン中も毎週、プロの卒業生の近況が届く。
// 種類ごとに文は3〜5通り。同じ子・同じ種類が続かないようにする。追っている子（a.fav）と絆の深い子は届きやすい。
// 効き目は小さく（評判・育成基金・★の子の自信）。シーズン中のゴールは年度末の成績の最低の数になる（a._ytdG）。
(function () {
  const YA = (globalThis.YA = globalThis.YA || {});
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const sur = (a) => (a.name || '').split(' ')[0];
  const posOf = (a) => (a.pos === 'GK' ? 'GK' : a.pos === 'DF' ? 'DF' : a.pos === 'FW' ? 'FW' : 'MF');
  const OPP_J = ['浦和', '鹿島', '川崎', '横浜', '名古屋', 'ガンバ', 'セレッソ', '広島', '神戸', '福岡', '札幌', '仙台', '新潟', '柏', '湘南', '京都', '磐田', '清水', '長崎', '岡山'];
  const OPP_A = ['ライバルの名門', '首位のチーム', '昇格組', '同じ町のクラブ', '強豪', '降格争いの相手'];
  const MIN = [12, 23, 37, 44, 51, 58, 66, 71, 78, 84, 89, '90+2'];

  // 種類：when（いつ届くか）、ok（届く子の条件）、w（重み）、tier（お知らせの段）、t（文の候補）、fx（効き目）
  // 文の関数は (a, x) を受ける。x は乱数から作った小道具（相手・分・数）
  const N = [
    { k: 'goal', when: 'season', ok: (a) => posOf(a) !== 'GK', w: (a) => (posOf(a) === 'FW' ? 3 : posOf(a) === 'MF' ? 1.6 : 0.5), tier: 3, ytd: 1,
      t: [(a, x) => `卒業生の${a.name}（${a.club}）が${x.opp}戦で${x.min}分にゴール`, (a, x) => `${a.club}の${sur(a)}が、${x.opp}戦で今季${x.n}点目を決めた`, (a, x) => `${a.name}がゴール。${x.opp}戦の${x.min}分、こぼれ球を押し込んだ（${a.club}）`, (a, x) => `${a.club}の${a.name}が${x.opp}戦で得点。ユースのころと同じ形だった`, (a, x) => `卒業生の${a.name}、${x.opp}戦で頭で合わせて今季${x.n}点目（${a.club}）`] },
    { k: 'winner', when: 'season', ok: (a) => posOf(a) !== 'GK', w: (a) => (posOf(a) === 'FW' ? 1 : 0.5), tier: 2, ytd: 1,
      t: [(a, x) => `卒業生の${a.name}（${a.club}）が${x.opp}戦の${x.late}分に決勝点！`, (a, x) => `${a.club}の${sur(a)}が終了間際に決勝ゴール。${x.opp}を1-0で破った`, (a, x) => `${a.name}の一撃で${a.club}が勝利。${x.opp}戦の${x.late}分だった`, (a, x) => `劇的。${a.name}が${x.opp}戦の${x.late}分に決めて、${a.club}が勝ち点3`] },
    { k: 'brace', when: 'season', ok: (a) => posOf(a) === 'FW' || (posOf(a) === 'MF' && a.ovr >= 13), w: () => 0.6, tier: 2, ytd: 2,
      t: [(a, x) => `卒業生の${a.name}が${x.opp}戦で2得点（${a.club}）`, (a, x) => `${a.club}の${sur(a)}が1試合2ゴール。${x.opp}を相手に大当たり`, (a, x) => `${a.name}、${x.opp}戦で2点。地元紙に「止められない」と書かれた`] },
    { k: 'assist', when: 'season', ok: (a) => posOf(a) === 'MF' || posOf(a) === 'FW' || (posOf(a) === 'DF' && /B$/.test(a.pos15 || '')), w: () => 1.4, tier: 3,
      t: [(a, x) => `卒業生の${a.name}（${a.club}）が${x.opp}戦でアシスト`, (a, x) => `${a.club}の${sur(a)}が${x.opp}戦で決定的なパス。今季${x.n}アシスト目`, (a, x) => `${a.name}のスルーパスから先制点。${x.opp}戦（${a.club}）`, (a, x) => `${a.name}がクロスで1アシスト。${x.opp}戦の${x.min}分`] },
    { k: 'clean', when: 'season', ok: (a) => posOf(a) === 'DF' || posOf(a) === 'GK', w: () => 1.4, tier: 3,
      t: [(a, x) => `卒業生の${a.name}（${a.club}）が${x.opp}戦で無失点に貢献`, (a, x) => `${a.club}の${sur(a)}、${x.opp}を完封。体を張って守り切った`, (a, x) => `${a.name}が${x.opp}戦にフル出場して完封勝ち（${a.club}）`, (a, x) => `${x.opp}の攻撃を${a.name}が封じた。${a.club}は無失点`] },
    { k: 'save', when: 'season', ok: (a) => posOf(a) === 'GK', w: () => 1.2, tier: 2,
      t: [(a, x) => `卒業生の${a.name}（${a.club}）が${x.opp}戦でPKを止めた！`, (a, x) => `${a.club}の守護神${sur(a)}がビッグセーブ連発。${x.opp}戦で勝ち点をもぎ取った`, (a, x) => `${a.name}、${x.opp}戦で1対1を3度止めて試合の最優秀選手に`] },
    { k: 'mom', when: 'season', ok: () => true, w: (a) => clamp(a.ovr - 12, 0.3, 2), tier: 3,
      t: [(a, x) => `卒業生の${a.name}が${x.opp}戦の最優秀選手に選ばれた（${a.club}）`, (a, x) => `${a.club}の${sur(a)}が${x.opp}戦でチーム最高の採点${x.score}`, (a, x) => `現地の採点で${a.name}が${x.score}。${x.opp}戦の主役だった`, (a, x) => `${a.name}が${x.opp}戦のマン・オブ・ザ・マッチ。監督も名前を挙げてほめた`] },
    { k: 'start', when: 'season', ok: (a) => a.age <= 22, w: () => 0.8, tier: 3,
      t: [(a, x) => `卒業生の${a.name}（${a.club}）が${x.opp}戦で先発。${x.full ? 'フル出場' : x.min + '分まで'}プレー`, (a, x) => `${a.club}の若手${sur(a)}が${x.opp}戦で先発の座をつかんだ`, (a, x) => `${a.name}、${x.opp}戦で3試合続けての先発（${a.club}）`] },
    { k: 'debut', when: 'season', ok: (a) => !a.pnDebut && a.age <= 20, w: () => 2.5, tier: 2, once: 'pnDebut',
      t: [(a, x) => `卒業生の${a.name}が${a.club}でプロデビュー！${x.opp}戦の${x.min}分から出場`, (a, x) => `${a.name}がついにデビュー。${a.club}の${x.opp}戦、背番号${x.num}で途中から入った`, (a, x) => `${a.club}の${sur(a)}がプロ初出場。「ユースの仲間に見てほしかった」`] },
    { k: 'firstgoal', when: 'season', ok: (a) => !a.pnFirst && a.pnDebut && posOf(a) !== 'GK', w: () => 2.5, tier: 2, once: 'pnFirst', ytd: 1,
      t: [(a, x) => `卒業生の${a.name}がプロ初ゴール！${x.opp}戦の${x.min}分（${a.club}）`, (a, x) => `${a.name}、待望のプロ初得点。ボールは記念に家に飾るそうだ`, (a, x) => `${a.club}の${sur(a)}がプロ初ゴール。試合のあと、真っ先にユースの監督の名前を出した`] },
    { k: 'sub', when: 'season', ok: () => true, w: () => 0.9, tier: 3,
      t: [(a, x) => `卒業生の${a.name}が${x.opp}戦で途中出場。流れを変えた（${a.club}）`, (a, x) => `${a.club}の${sur(a)}、${x.opp}戦の後半から入って同点に追いつくきっかけを作った`, (a, x) => `${a.name}がベンチから出て${x.min}分の勝ち越し点に絡んだ`] },
    { k: 'bench', when: 'season', ok: (a) => a.ovr < 15, w: () => 0.8, tier: 3,
      t: [(a) => `卒業生の${a.name}（${a.club}）はここ3試合ベンチ外。練習では手応えがあるという`, (a) => `${a.club}の${sur(a)}が出番を減らしている。監督の方針が変わったらしい`, (a) => `${a.name}、ポジション争いで苦しんでいる。それでも居残り練習は欠かさない`, (a) => `${a.name}は今季まだ先発がない。「ユースのときより、1本のパスが重い」`] },
    { k: 'injury', when: 'season', ok: () => true, w: () => 0.6, tier: 2, set: (a, x) => { a.pnInj = x.wk; },
      t: [(a, x) => `卒業生の${a.name}（${a.club}）がけがで離脱。全治およそ${x.wk}週間`, (a, x) => `${a.club}の${sur(a)}が練習中に足を痛めた。復帰まで${x.wk}週間ほど`, (a, x) => `${a.name}が${x.opp}戦で負傷交代。${x.wk}週間の離脱になる見込み`] },
    { k: 'back', when: 'season', ok: (a) => a.pnInj > 0, w: () => 4, tier: 3, set: (a) => { a.pnInj = 0; },
      t: [(a) => `けがをしていた卒業生の${a.name}が、${a.club}で復帰した`, (a, x) => `${a.name}がけがから戻ってきた。${x.opp}戦で途中出場`, (a) => `${a.club}の${sur(a)}が全体練習に復帰。「リハビリ中、ユースの映像を見ていた」`] },
    { k: 'red', when: 'season', ok: (a) => posOf(a) !== 'GK', w: () => 0.25, tier: 3,
      t: [(a, x) => `卒業生の${a.name}（${a.club}）が${x.opp}戦で退場。2枚目のイエローだった`, (a, x) => `${a.name}、${x.opp}戦で一発退場。次節は出場停止`, (a) => `${a.club}の${sur(a)}がレッドカード。試合のあと、チームメイトに頭を下げた`] },
    { k: 'captain', when: 'season', ok: (a) => a.age >= 23 && a.ovr >= 13, w: () => 0.6, tier: 2,
      t: [(a, x) => `卒業生の${a.name}が${x.opp}戦で${a.club}のキャプテンマークを巻いた`, (a) => `${a.name}が${a.club}の副キャプテンに。「ユースで任されたときのことを思い出した」`, (a) => `${a.club}の${sur(a)}がキャプテンとして初めての試合。声でチームを動かした`] },
    { k: 'derby', when: 'season', ok: (a) => !a.abroad, w: () => 0.5, tier: 3,
      t: [(a) => `卒業生の${a.name}（${a.club}）がダービーに出場。スタジアムは満員だった`, (a) => `${a.club}の${sur(a)}、ダービーで先発。勝って地元のニュースになった`, (a) => `${a.name}がダービーで決定機を作った。「ユースのダービーより、何倍も緊張した」`] },
    { k: 'vsTop', when: 'season', ok: (a, w) => !!(w.top && a.club !== w.top.name && !a.abroad), w: () => 0.5, tier: 2,
      t: [(a, x, w) => `卒業生の${a.name}（${a.club}）が古巣の${w.top.name}と対戦。${x.win ? '勝って' : '負けて'}も、試合のあとユース時代の仲間とあいさつした`, (a, x, w) => `${w.top.name}戦で${a.name}が先発。古巣のサポーターから拍手が起きた`, (a, x, w) => `${a.club}の${sur(a)}が古巣${w.top.name}相手に${x.win ? '決勝点' : '奮闘'}。「育ててもらった場所なので複雑です」`] },
    { k: 'abroadPress', when: 'season', ok: (a) => a.abroad, w: () => 1.4, tier: 3,
      t: [(a, x) => `${a.league}の地元紙が卒業生の${a.name}（${a.club}）に${x.score}点。「東洋から来た頭脳」`, (a) => `${a.club}の${sur(a)}の特集が現地のテレビで流れた`, (a) => `${a.name}が${a.club}のファン投票で今月の最優秀選手に`, (a) => `現地の記者が${a.name}を「この冬いちばんの掘り出し物」と書いた`] },
    { k: 'abroadLife', when: 'any', ok: (a) => a.abroad, w: () => 0.8, tier: 3,
      t: [(a) => `${a.club}にいる卒業生の${a.name}から近況。「言葉はまだ半分。でもピッチの上では通じます」`, (a) => `${a.name}（${a.club}）が現地で語学学校に通い始めたそうだ`, (a) => `${a.name}から写真が届いた。雪のグラウンドで、ユースのジャージを着ていた`, (a) => `${a.club}の${sur(a)}は日本食が恋しいらしい。「みそ汁が飲みたい」`] },
    { k: 'coachChange', when: 'season', ok: () => true, w: () => 0.4, tier: 3,
      t: [(a, x) => `${a.club}で監督が交代。卒業生の${a.name}は新監督のもとで${x.win ? '出番が増えそうだ' : '一からのアピールになる'}`, (a) => `${a.name}のいる${a.club}に新しい監督が来た。最初の練習で名前を呼ばれたという`, (a) => `${a.club}の監督交代。${sur(a)}は「どの監督でも、やることは同じ」と話した`] },
    { k: 'rumor', when: 'any', ok: (a) => a.ovr >= 13.5 && a.age <= 28, w: (a) => clamp((a.ovr - 13) * 0.5, 0.2, 1), tier: 2,
      t: [(a) => `卒業生の${a.name}（${a.club}）に、${a.abroad ? '別のクラブ' : '海外のクラブ'}が興味を示しているといううわさ`, (a) => `${a.name}の移籍のうわさが出ている。本人は「今は目の前の試合だけ」`, (a) => `スカウトが${a.club}の試合に来ていた。お目当ては${sur(a)}らしい`, (a) => `${a.name}に${a.abroad ? 'ステップアップ' : '海外移籍'}の話。決まれば、ここにも連帯貢献金が入る`] },
    { k: 'extend', when: 'any', ok: (a) => a.ovr >= 11.5, w: () => 0.5, tier: 3,
      t: [(a, x) => `卒業生の${a.name}が${a.club}と契約を${x.yr}年延長`, (a) => `${a.club}が${sur(a)}との契約延長を発表。「このクラブで上を目指したい」`, (a) => `${a.name}の契約延長が決まった。背番号も若い番号に変わる`] },
    { k: 'natCamp', when: 'any', ok: (a) => a.nat > 0 || a.u21 > 0 || a.ovr >= 15, w: (a) => (a.nat ? 1.6 : 0.8), tier: 2,
      t: [(a) => `卒業生の${a.name}が${a.nat ? '日本代表' : 'U-21日本代表'}の合宿に呼ばれた`, (a) => `${a.nat ? '日本代表' : 'U-21代表'}の候補に${a.name}の名前。${a.club}で好調が続いている`, (a) => `${a.name}が${a.nat ? '代表' : 'U-21代表'}の練習で目立っていたと、記者が書いていた`] },
    { k: 'natGoal', when: 'any', ok: (a) => a.nat > 0 && posOf(a) !== 'GK', w: () => 0.6, tier: 1,
      t: [(a) => `卒業生の${a.name}が日本代表でゴール！`, (a) => `日本代表の試合で${a.name}が得点。ユースの練習場でも見ていた子どもたちが沸いた`, (a) => `${a.name}、代表戦で決めた。「最初に教わったのは、ここのグラウンドでした」`] },
    { k: 'interview', when: 'any', ok: () => true, w: (a) => 0.3 + (a.bond || 2) * 0.15, tier: 3, fx: (w) => { YA.addRep && YA.addRep(w, 1); },
      t: [(a, x, w) => `卒業生の${a.name}がインタビューで${w.clubName}のことを話した。「あそこで、サッカーが仕事になった」（評判 +1）`, (a) => `${a.name}（${a.club}）がテレビで「ユースの監督に言われたことを今も守っている」と話した（評判 +1）`, (a) => `雑誌の取材で${a.name}が恩師としてユースの監督の名前を挙げた（評判 +1）`, (a) => `${a.club}の公式サイトに${sur(a)}のインタビュー。半分がユース時代の話だった（評判 +1）`] },
    { k: 'kids', when: 'any', ok: (a) => a.age >= 22, w: () => 0.5, tier: 3, fx: (w) => { YA.addRep && YA.addRep(w, 1); },
      t: [(a) => `卒業生の${a.name}が地元で子ども向けのサッカー教室を開いた（評判 +1）`, (a, x, w) => `${a.name}が${w.clubName}の名前を出して、小学生の大会を応援した（評判 +1）`, (a) => `${a.name}がオフに母校の小学校を訪ね、ボールを30個寄付した（評判 +1）`] },
    { k: 'gift', when: 'any', ok: (a) => a.ovr >= 12.5, w: () => 0.35, tier: 2, fx: (w, a, x) => { w.fund = (w.fund || 0) + x.gift; w.fundIn = (w.fundIn || 0) + x.gift; },
      t: [(a, x) => `卒業生の${a.name}から、後輩たちにスパイクが届いた（育成基金 +${x.gift}万円ぶん）`, (a, x) => `${a.name}（${a.club}）がユースに練習用のボールとビブスを贈ってくれた（育成基金 +${x.gift}万円）`, (a, x) => `${a.name}が試合の賞金の一部をユースに寄付した（育成基金 +${x.gift}万円）`] },
    { k: 'advice', when: 'any', ok: (a, w) => !!kidFor(w, a), w: (a) => 0.5 + (a.bond || 2) * 0.3, tier: 2,
      fx: (w, a, x) => { const p = x.kid; if (p) { p.conf = clamp((p.conf || 50) + 4, 0, 100); if (YA.addTr) YA.addTr(w, p, 1, '先輩の言葉'); } },
      t: [(a, x) => `卒業生の${a.name}（${a.club}）から、同じ${x.pos}の${x.kid.name}へ一言。「1年目は焦らなくていい」（${x.kid.name}の自信 +4）`, (a, x) => `${a.name}が${x.kid.name}の試合の映像を見て、メッセージをくれた。「体の向きがいい。それは武器になる」（自信 +4）`, (a, x) => `${a.name}から${x.kid.name}へ。「俺も高${x.kid.grade}のときは同じことで悩んでた」（自信 +4）`, (a, x) => `${a.name}が${x.kid.name}にスパイクを1足送ってきた。「履きつぶしてくれ」（自信 +4）`] },
    { k: 'compare', when: 'any', ok: (a, w) => !!kidFor(w, a), w: () => 0.4, tier: 3,
      t: [(a, x) => `${a.club}の${a.name}が取材で「ユースに${x.kid.name}って子がいて、俺より上手い」と話していた`, (a, x) => `${a.name}が${x.kid.name}のことを気にかけている。「あいつはプロになる」`, (a, x) => `${a.name}いわく、${x.kid.name}は「自分の高${x.kid.grade}のころより落ち着いている」`] },
    { k: 'milestone', when: 'season', ok: (a) => (a.apps || 0) >= 40, w: () => 0.5, tier: 2,
      t: [(a) => `卒業生の${a.name}がプロ通算${Math.floor(((a.apps || 0) + 10) / 50) * 50 || 50}試合出場を達成（${a.club}）`, (a) => `${a.name}、プロでの節目の試合。記念のユニフォームをユースに送ると言っている`, (a) => `${a.club}の${sur(a)}が節目の出場。試合後、ベンチで少し泣いていた`] },
    { k: 'veteran', when: 'any', ok: (a) => a.age >= 30, w: () => 0.6, tier: 3,
      t: [(a) => `ベテランになった卒業生の${a.name}（${a.club}）。「あと何年できるかより、今日の練習」`, (a) => `${a.name}が若手に囲まれて練習している。いつの間にか、教える側になっていた`, (a) => `${a.name}が引退後のことを聞かれて、「指導者もいいかも」と笑った`] },
  ];
  YA.PRO_NEWS = N;

  // 同じ位置のいまの子（★を優先）。先輩から一言が届く相手
  function kidFor(w, a) {
    const ps = Object.values(w.players || {}).filter((p) => p.pos === a.pos);
    if (!ps.length) return null;
    ps.sort((p, q) => (q.star ? 1 : 0) - (p.star ? 1 : 0) || YA.hash(a.name + p.id) % 7 - YA.hash(a.name + q.id) % 7);
    return ps[0];
  }

  YA.proNewsWeek = function (w) {
    const key = w.year * 100 + w.week;
    if (w.pnKey === key) return [];
    w.pnKey = key;
    const pros = (w.alumni || []).filter((a) => a.status === 'pro' && !a.retired && a.club);
    if (!pros.length) return [];
    const r = YA.rngOf((w.seed | 0) * 41 + key * 13);
    const season = w.week <= 30;
    w.pnRecent = (w.pnRecent || []).filter((x) => key - x.at < 6);
    // 1週に届く数：プロが多いほど多い（1〜3）
    const n = (r() < clamp(0.25 + pros.length * 0.12, 0, 0.92) ? 1 : 0) + (pros.length >= 4 && r() < 0.35 ? 1 : 0) + (pros.length >= 8 && r() < 0.25 ? 1 : 0);
    const out = [];
    if (season) for (const a of pros) if (a.pnInj > 0) a.pnInjW = (a.pnInjW || 0) + 1;
    for (let i = 0; i < n; i++) {
      const cand = [];
      for (const a of pros) {
        if (w.pnRecent.some((x) => x.a === a.name && key - x.at < 3)) continue;
        for (const d of N) {
          if (d.when === 'season' && !season) continue;
          if (d.once && a[d.once]) continue;
          if (a.pnInj > 0 && d.k !== 'back' && d.when === 'season' && d.k !== 'abroadLife') continue;
          if (d.k === 'back' && !(a.pnInj > 0 && (a.pnInjW || 0) >= a.pnInj)) continue;
          if (!d.ok(a, w)) continue;
          if (w.pnRecent.some((x) => x.k === d.k && key - x.at < 4)) continue;
          const wt = d.w(a, w) * (a.fav ? 3 : 1) * (0.7 + (a.bond || 2) * 0.15) * clamp(0.6 + (a.ovr - 11) * 0.12, 0.4, 1.6);
          if (wt > 0) cand.push([a, d, wt]);
        }
      }
      if (!cand.length) break;
      const tot = cand.reduce((s, c) => s + c[2], 0);
      let x = r() * tot;
      let pick = cand[0];
      for (const c of cand) { x -= c[2]; if (x <= 0) { pick = c; break; } }
      const [a, d] = pick;
      const kid = kidFor(w, a);
      const pr = {
        opp: a.abroad ? r.pick(OPP_A) : r.pick(OPP_J), min: r.pick(MIN), late: r.pick([85, 88, 89, '90+1', '90+3', '90+4']), n: (a._ytdG || 0) + (d.ytd || 1),
        score: (7 + r() * 1.5).toFixed(1), full: r() < 0.5, num: r.int(24, 44), wk: r.int(2, 8), yr: r.int(1, 3), win: r() < 0.5, gift: r.pick([30, 50, 80, 100]),
        kid, pos: { GK: 'GK', DF: 'DF', MF: 'MF', FW: 'FW' }[a.pos] || a.pos,
      };
      if (d.k === 'assist') pr.n = r.int(2, 9);
      const ti = YA.hash(a.name + d.k + key) % d.t.length;
      const text = d.t[ti](a, pr, w);
      if (d.ytd) a._ytdG = (a._ytdG || 0) + d.ytd;
      if (d.once) a[d.once] = key;
      if (d.set) d.set(a, pr);
      if (d.fx) d.fx(w, a, pr);
      a.news = (a.news || []).concat([{ y: w.year, w: w.week, k: d.k, t: text }]).slice(-30);
      w.pnRecent.push({ a: a.name, k: d.k, at: key });
      if (YA.noteTier) YA.noteTier(w, d.tier, text, d.k === 'advice' && kid ? kid.id : undefined);
      out.push(text);
    }
    return out;
  };

  // 毎週：ライバルの週の処理（週ごとに1回呼ばれる）に乗せる
  const rw0 = YA.rivalWeek;
  YA.rivalWeek = function (w) {
    const r = rw0 ? rw0.apply(this, arguments) : undefined;
    try { YA.proNewsWeek(w); } catch (e) { /* 知らせが出せなくても週は進める */ }
    return r;
  };

  // 系譜タブの小タブ「クラブ」：卒業生が行きうるクラブと強さ（2026-11-15「クラブごとの強さ見せて」）
  YA.lineageExtraTabs = YA.lineageExtraTabs || [];
  function clubsTab(body, w) {
    const h = YA._ui.h;
    const now = {}, ever = {};
    for (const a of w.alumni || []) {
      if (a.status === 'pro' && !a.retired && a.club) now[a.club] = (now[a.club] || []).concat([a.name]);
      for (const c of new Set((a.seasons || []).map((s) => s.club).filter(Boolean))) ever[c] = (ever[c] || 0) + 1;
    }
    const groups = [['J1リーグ', 1], ['J2リーグ', 2], ['J3リーグ', 3]].map(([lg, t]) => [lg, (YA.PRO_CLUBS || []).filter((c) => (w.top && c.name === w.top.name ? w.top.j : c.tier) === t).map((c) => [c.name + (w.top && c.name === w.top.name ? '（自分のクラブのトップ）' : ''), YA.clubStr(c.name, w)])])
      .concat(YA.ABROAD_LEAGUES.map((x) => [x[1] + '（' + x[0] + '）', YA.ABROAD_CLUBS[x[1]].map((c) => [c[0], c[1]]), x[1]]));
    const total = groups.reduce((n, g) => n + g[1].length, 0);
    body.append(h('div', { class: 'h' }, `移籍先のクラブ（${total}）`), h('div', { class: 'note' }, '数字はクラブの強さ（選手の総合力と同じ0〜200の物差し）。卒業生は、自分の総合力より少し上のクラブへ移りやすい。強いクラブほど優勝しやすい。'));
    const list = h('div', { class: 'scroll', style: 'flex:1;min-height:0;margin-top:4px' });
    for (const [title, clubs, key] of groups) {
      const lgR = YA.rate((YA.LEAGUE_LV || {})[key || title] || 12);
      list.append(h('div', { class: 'h', style: 'margin-top:6px;font-size:13px' }, `${title}　リーグの水準 ${lgR}`));
      for (const [name, str] of clubs.slice().sort((x, y) => y[1] - x[1])) {
        const ours = now[name.replace('（自分のクラブのトップ）', '')] || [];
        list.append(h('div', { class: 'pitem', style: 'cursor:default;gap:6px;align-items:center' },
          h('span', { style: 'width:42px;flex:none;text-align:right;font-weight:800' }, String(str)),
          h('div', { style: 'width:90px;flex:none;height:6px;border-radius:3px;background:var(--line);overflow:hidden' }, h('div', { style: `width:${Math.max(4, Math.min(100, ((str - 90) / 95) * 100))}%;height:100%;background:${str >= 165 ? '#d9a400' : str >= 145 ? 'var(--acc,#1f6feb)' : '#7a8aa0'}` })),
          h('span', { class: 'grow' }, name),
          ours.length ? h('span', { class: 'chip trait' }, `卒業生 ${ours.length}人`) : ever[name] ? h('span', { class: 'sub' }, `かつて${ever[name]}人`) : null));
      }
    }
    body.append(list);
  }
  YA.lineageExtraTabs.push(['clubs', 'クラブ', clubsTab]);

  // 年度末：シーズン中に知らせたゴールは、その年の成績の最低の数にする（ゴールの知らせと成績が食い違わない）
  const at0 = YA.alumniTick;
  YA.alumniTick = function (w) {
    const before = new Map((w.alumni || []).map((a) => [a, { g: a._ytdG || 0, n: (a.seasons || []).length }]));
    const r = at0.apply(this, arguments);
    for (const [a, b] of before) {
      const s = (a.seasons || [])[b.n];
      if (s && b.g > s.goals) { a.goals += b.g - s.goals; s.goals = b.g; }
      a._ytdG = 0;
      a.pnInjW = 0;
    }
    return r;
  };
})();
