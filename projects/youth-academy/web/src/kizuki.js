// 気づきの場面（2026-11-27 ユーザーと会話で確定。段3「選手の目・練習・日常」）
// 課題の後半（期間の半分を過ぎた）の子に、プレイヤーが選ぶ場面が来る。前の「試合で確率で気づく」（YA.kadaiSpark）を置き換えた。
// ・場所は3つ：試合（出た試合で1試合に1回まで）・練習（紅白戦の一場面。週1回まで）・日常（寮・帰り道・ロッカーでの会話）
// ・課題ごとに気づきやすい場所が決まっている（YA.KZ_AT）。1人週1回まで・全員で週2回まで
// ・試合と練習は「選手の目」：時間を止めた上から見た図で、正しい見え方・無難な手・ありがちな間違いの3つと、課題で禁じた手（鍵つき）から選ぶ。
//   時間の制限はない。正解の場所と A〜C の並びは毎回変わる。ふだんの試合画面には図を出さない（止まった図はこの山場だけ）。動く絵・表情の顔は作らない
// ・日常は今の出来事の窓（左に人と台詞・右に選ぶボタン）で、正しい言葉／無難な言葉／間違った言葉
// ・選んだあと：正しい→課題が合っていれば覚醒（今の覚醒の流れのまま）、合っていなければ「何かが違う」＝手がかり+1・少し伸びる。
//   無難→持ち越し。間違い→悔しい（自信が少し下がる）・持ち越し。試合の点・結果には関わらない（その子の採点だけ上下）
// ・A の試合を画面で見ているときは、試合の途中で時間が止まって出る（選んだ中身は試合が終わってから反映するので、結果は変わらない）。
//   B の試合・「結果まで」・おまかせは、試合のあとに「（Bの）試合の一場面」として出る（w.kzNow）
// ・おまかせ進行は自動で選ぶ（YA.KADAI_SPARK の確率で正しい手）。止めない
(function () {
  'use strict';
  const YA = (globalThis.YA = globalThis.YA || {});
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const wk = (w) => w.year * (YA.WEEKS || 40) + w.week;
  const sur = (p) => String((p && p.name) || '').split(' ')[0];
  const all = (w) => Object.values(w.players || {});
  const posName = (c) => (YA.POS_LABEL && YA.POS_LABEL[c]) || c;
  const oppName = (m) => { const a = m && m.away; if (!a) return ''; return String(a.name || a.short || '').replace(/\s*U-?\d*$/, '').trim() || a.short || ''; };
  const sub = (s, o) => String(s).replace(/\{(\w)\}/g, (m, k) => (o[k] != null ? o[k] : ''));

  // ---------- 決まり ----------
  // 課題ごとの気づきやすい場所（match=試合・prac=練習の紅白戦・talk=日常の会話）
  YA.KZ_AT = {
    seal: ['match', 'prac'], eye: ['match', 'prac'], convert: ['match', 'prac'], weapon: ['match', 'prac'], body: ['match', 'prac'],
    role: ['match', 'talk'], stage: ['match', 'talk'], captain: ['match', 'talk'],
    pair: ['prac', 'talk'], rival: ['prac', 'talk'],
  };
  YA.KZ_WEEK_MAX = 2; // 全員合わせて週2回まで（1人は週1回まで）
  // 場面が来る確率：試合（後半の子が出た試合1つ）・練習（週1回の紅白戦）・日常（週1回まで）
  // 合う課題の後半（4〜8週）に場面が2〜4回来るように合わせた（tool/balance.js が測る）
  YA.KZ_RATE = { match: 0.8, prac: 0.6, talk: 0.55 };
  // おまかせで正しい手を選ぶ確率は YA.KADAI_SPARK（kadai.js。前は後半に出た試合1つで気づく確率だった）
  const RDELTA = { ok: 0.5, safe: 0, bad: -0.4 }; // 試合の場面：その子の採点だけ上下

  const half = (w, p) => { const k = p && p.kd; if (!k) return false; const e = wk(w) - k.w0; return e >= k.len / 2 && e < k.len; };
  const weekBox = (w) => { if (!w.kzW || w.kzW.k !== wk(w)) w.kzW = { k: wk(w), n: 0, ids: [] }; return w.kzW; };
  YA.kizukiPending = (w, p) => [w.kzNow, w.forced, w.events].some((q) => (q || []).some((e) => e && e.id === 'kizuki' && e.pid === p.id));
  // その子に、いま場面を出せるか（at: match / prac / talk）
  YA.kizukiCan = function (w, p, at) {
    if (!p || !p.kd || !half(w, p) || p.kd.ng) return false;
    if ((YA.KZ_AT[p.kd.t] || []).indexOf(at) < 0) return false;
    const b = weekBox(w);
    if (b.n >= YA.KZ_WEEK_MAX || b.ids.indexOf(p.id) >= 0) return false;
    if (YA.kizukiPending(w, p)) return false;
    if (at === 'prac' && (p.inj > 0 || p.away > 0)) return false;
    return true;
  };

  // ---------- 選手の目の場面（課題ごとに2つ・計20）----------
  // fam：図の型（pass=持っている／run=持っていない／mark=守り／duel=競り合い／hold=背負う／say=声）
  // ok/safe/bad：[図の上の場所の種類, ボタンの文]。lock：[場所の種類 or null, 文, 押したときの理由]
  // {n}=その子 {m}=その場所の味方 {d}=向き {c}=課題の中身 {o}=元の位置 {r}=相棒・競う相手
  const R_SAFE = '無理をせず、無難に終えた。悪くはないが、気づきは起きなかった。';
  const R_BAD = 'うまくいかなかった。相手に読まれていた。';
  const SAY_SAFE = ['……これで、いいのか', 'とりあえず、しのいだ……', '……悪くは、なかったはず'];
  const SAY_BAD = ['くそっ、見えてなかった', '……また、やっちまった', '悔しい……なんでだ'];
  const sealLock = (c) => (c === 'ドリブル' ? ['ahead', '縦へ仕掛ける（ドリブルを封印中）'] : c === 'スピード' ? ['ahead', 'スピードで振り切る（スピードを封印中）'] : ['shot', 'そのまま打つ（' + c + 'を封印中）']);
  YA.KZ_EYE = [
    { id: 'seal1', k: 'seal', fam: 'pass', sit: '相手の DF が寄せてくる', think: '{c}は使えない……。顔を上げろ。どこが空いてる？', hint: '得意を封じたときこそ、周りが見える。',
      ok: ['gap', '{d}へ走る{m}へ、DF の間を通す'], safe: ['back', '後ろの{m}へ戻して、作り直す'], bad: ['wide', '逆サイドの{m}へ大きく蹴る'],
      lock: (c) => sealLock(c).concat([`いまは「{c}」を封印する課題中。その手は使えない`]),
      res: { ok: '{n}は顔を上げ、DF の間へ通した。{m}が抜け出す。', safe: '後ろへ戻して、攻めを作り直した。悪くはないが、気づきは起きなかった。', bad: '大きく蹴ったが、相手に読まれて奪われた。' },
      say: { ok: '{c}に頼らなくても、崩せるんだ' } },
    { id: 'seal2', k: 'seal', fam: 'pass', sit: 'ゴールの近くで、ボールが足元に来た', think: 'いつもなら{c}で行く場面だ。でも――', hint: '打つ前に、一つだけ周りを見ろ。',
      ok: ['square', '横で待つ{m}へ、落とす'], safe: ['back', '下がって、{m}に預け直す'], bad: ['near', '囲まれた{m}へ、無理に通す'],
      lock: (c) => sealLock(c).concat([`いまは「{c}」を封印する課題中。その手は使えない`]),
      res: { ok: '{n}は一つ顔を上げ、横の{m}へ落とした。完全に崩した。', safe: '預け直して、攻めは仕切り直し。気づきは起きなかった。', bad: '{m}への球は、間の足に引っかかった。' },
      say: { ok: '見えてる。全部、見えてる' } },
    { id: 'eye1', k: 'eye', fam: 'pass', sit: '中盤でボールを受けた', think: '考えろ……。どこが空いてる？', hint: '受ける前に、二回首を振れ。',
      ok: ['gap', '{d}の{m}へ、DF の間を通す'], safe: ['back', '後ろの{m}に預ける'], bad: ['shot', '遠くから、そのまま打つ'],
      lock: () => ['ahead', '考えずに前へ運ぶ', 'いまは「見る目を鍛える」課題中。考えずに運ぶ手は封じている'],
      res: { ok: '{n}は首を振り、空いた{m}へ通した。相手の守りが割れた。', safe: '後ろへ預けた。安全だが、気づきは起きなかった。', bad: '遠くからのシュートは、大きく外れた。空いた味方がいた。' },
      say: { ok: 'こういうことか。見てから、蹴るんだ' } },
    { id: 'eye2', k: 'eye', fam: 'mark', sit: '相手が攻めてくる。守りの数が足りない', think: 'ボールだけ見るな。危ないのは、どこだ', hint: 'ボールじゃない。ボールのない所を見ろ。',
      ok: ['free', '後ろから入ってくる相手を捕まえる'], safe: ['zone', 'いまの持ち場に残る'], bad: ['carrier', 'ボールを持つ相手へ飛び込む'],
      lock: () => [null, '何も考えずに走り回る', 'いまは「見る目を鍛える」課題中。考えずに動く手は封じている'],
      res: { ok: '{n}は誰もいない所から来る相手に気づき、先に捕まえた。', safe: '持ち場は守った。気づきは起きなかった。', bad: '飛び込んだ裏を、別の相手に使われた。' },
      say: { ok: '見えた……ボールのない所が' } },
    { id: 'conv1', k: 'convert', fam: 'mark', sit: '{c}に入って、最初の大きな場面', think: '{c}なら、ここで誰を見る？', hint: '前の位置の癖を捨てろ。{c}の目で見ろ。',
      ok: ['free', '空いている相手のランナーを捕まえる'], safe: ['zone', '{c}の持ち場で待つ'], bad: ['carrier', 'ボールへ寄って、{o}のように追い回す'],
      lock: () => [null, '{o}の位置へ戻る', 'いまは{c}へ転向中。{o}の動きには戻れない'],
      res: { ok: '{n}は{c}の目で、空いたランナーを捕まえた。', safe: '持ち場で待った。気づきは起きなかった。', bad: '追い回した裏を、使われた。{o}の癖が抜けていない。' },
      say: { ok: 'ここからだと、こう見えるのか' } },
    { id: 'conv2', k: 'convert', fam: 'run', sit: '{c}で、味方がボールを持った', think: '{c}なら、どこで受ける？', hint: '新しい位置には、新しい受け方がある。',
      ok: ['space', '{d}の空いた所へ入る'], safe: ['short', '{m}の近くへ寄って受ける'], bad: ['offside', '{o}のときのように、最終ラインへ張りつく'],
      lock: () => [null, '{o}の位置へ戻る', 'いまは{c}へ転向中。{o}の動きには戻れない'],
      res: { ok: '{n}は{c}にしかない空きを見つけ、そこで受けた。', safe: '近くで受けた。安全だが、気づきは起きなかった。', bad: '張りついた所は、オフサイドの位置だった。' },
      say: { ok: 'この場所、なんか……しっくりくる' } },
    { id: 'weap1', k: 'weapon', fam: 'pass', sit: 'いつもの形を、相手が待ち構えている', think: 'また読まれる……。新しいのを試すなら、今だ', hint: '{c}を使う場面は、自分で見つけるものだ。',
      ok: ['gap', '{d}の{m}へ、{c}で崩しにいく'], safe: ['back', 'いつも通り、後ろへ預ける'], bad: ['near', '読まれている{m}へ、いつもの形で出す'],
      lock: () => ['ahead', 'いつもの形だけで行く', 'いまは新しい武器を足す課題中。いつもの形だけには戻らない'],
      res: { ok: '{n}の{c}が、初めて形になった。{m}へ通った。', safe: 'いつも通り預けた。気づきは起きなかった。', bad: 'いつもの形は、やはり読まれていた。' },
      say: { ok: 'これだ。これが、新しい武器だ' } },
    { id: 'weap2', k: 'weapon', fam: 'run', sit: '味方がボールを持った。相手は{n}の得意を知っている', think: '同じ動きじゃ、止められる', hint: '{c}が生きる場所はどこか、考えろ。',
      ok: ['space', '{d}の空いた所へ、新しい動きで入る'], safe: ['short', '{m}の近くで、いつも通り受ける'], bad: ['offside', 'いつも通り、裏へ一直線に走る'],
      lock: () => [null, 'いつもの形だけで行く', 'いまは新しい武器を足す課題中。いつもの形だけには戻らない'],
      res: { ok: '{n}は新しい動きで、相手の読みを外した。', safe: 'いつも通り受けた。気づきは起きなかった。', bad: 'いつもの走りは、待ち伏せされていた。' },
      say: { ok: '読まれない。……こういうことか' } },
    { id: 'body1', k: 'body', fam: 'duel', sit: '相手の FW と競り合う', think: '当たり負けるな。どこに体を入れる？', hint: '先に体を入れたほうが勝つ。',
      ok: ['inside', '相手とゴールの間に、先に体を入れる'], safe: ['apart', '一歩下がって、間合いを取る'], bad: ['behind', '後ろから足を出す'],
      lock: () => [null, '当たりを避けて逃げる', 'いまは体を作る課題中。当たりからは逃げない'],
      res: { ok: '{n}が先に体を入れた。相手が弾かれる。', safe: '間合いを取って、しのいだ。気づきは起きなかった。', bad: '後ろから出した足は、ファウルを取られた。' },
      say: { ok: '……当たれる。この体なら、当たれる' } },
    { id: 'body2', k: 'body', fam: 'hold', sit: '背中に DF を背負って、縦パスを受ける', think: '体で守れ。どこで受ける？', hint: '腕と背中で、相手との距離を作れ。',
      ok: ['shield', '体を入れて、相手を背負って受ける'], safe: ['drop', '下がって、相手から離れて受ける'], bad: ['turn', '無理に前を向く'],
      lock: () => [null, '当たりを避けて逃げる', 'いまは体を作る課題中。当たりからは逃げない'],
      res: { ok: '{n}は背中で相手を止め、ボールを収めた。', safe: '下がって受けた。気づきは起きなかった。', bad: '前を向いたところを、後ろから突かれた。' },
      say: { ok: 'びくともしない……。前の自分とは違う' } },
    { id: 'role1', k: 'role', fam: 'say', sit: 'ラインがそろわない。相手は裏を狙っている', think: '{c}は自分だ。誰に、何を言う？', hint: '任された仕事は、声を出すところから始まる。',
      ok: ['down', '遅れている{m}に「上げろ」と声をかけ、ラインをそろえる'], safe: ['all', '全体に「集中！」とだけ叫ぶ'], bad: ['blame', 'ずれた{m}を責める'],
      lock: () => [null, '仕事を忘れて、自分のプレーだけする', 'いまは「{c}」を任されている。仕事は放り出せない'],
      res: { ok: '{n}の声で、ラインが一つにそろった。相手の裏への球が、オフサイドになる。', safe: '叫んだが、誰に届いたかは分からない。気づきは起きなかった。', bad: '責められた{m}は黙りこみ、ラインはずれたままだった。' },
      say: { ok: '自分の声で、チームが動いた' } },
    { id: 'role2', k: 'role', fam: 'mark', sit: '相手のボール。ここから守備が始まる', think: '{c}として、どこから行く？', hint: '任された仕事の意味を考えろ。',
      ok: ['free', '空いた相手へのパスコースを切りながら寄せる'], safe: ['zone', '持ち場に戻って待つ'], bad: ['carrier', '一人でボールへ突っ込む'],
      lock: () => [null, '仕事を忘れて、自分のプレーだけする', 'いまは「{c}」を任されている。仕事は放り出せない'],
      res: { ok: '{n}が道を切ったところへ、味方が奪いに行けた。', safe: '持ち場で待った。気づきは起きなかった。', bad: '一人で突っ込んだ裏を、通された。' },
      say: { ok: '仕事って、こういうことか' } },
    { id: 'stage1', k: 'stage', fam: 'pass', sit: (c) => (c === 'A' ? '格上の相手。寄せが速い' : '大事な場面。ボールが回ってきた'), think: (c) => (c === 'A' ? '速い……。でも、ここで逃げたら同じだ' : '怖い。でも、ここは自分の場所だ'), hint: (c) => (c === 'A' ? '上の速さには、頭で先回りしろ。' : '失敗してもいい。自分のプレーをしろ。'),
      ok: ['gap', '{d}の{m}へ、逃げずに縦パスを入れる'], safe: ['back', '後ろの{m}へ、すぐに戻す'], bad: ['near', '慌てて、目の前の{m}へ出す'],
      lock: () => [null, 'ボールを受けるのを避ける', 'いまは舞台を変えて試している。ここで逃げたら課題の意味がない'],
      res: { ok: '{n}は逃げずに縦へ入れた。{m}が前を向く。', safe: 'すぐに戻した。気づきは起きなかった。', bad: '慌てて出した球は、相手に引っかかった。' },
      say: { ok: 'ここでも、やれる' } },
    { id: 'stage2', k: 'stage', fam: 'run', sit: '味方がボールを持った', think: 'ボールを、もらいにいくか……', hint: (c) => (c === 'A' ? '上でやれるかは、受ける勇気で決まる。' : 'ここでなら、思い切って受けられるはずだ。'),
      ok: ['space', '{d}の空いた所で、自分から受けに行く'], safe: ['short', '{m}の近くで、安全に受ける'], bad: ['hide', '隠れるように、相手の陰に止まる'],
      lock: () => [null, 'ボールを受けるのを避ける', 'いまは舞台を変えて試している。ここで逃げたら課題の意味がない'],
      res: { ok: '{n}は自分から空きへ入り、ボールを呼んだ。', safe: '近くで受けた。気づきは起きなかった。', bad: '相手の陰に隠れて、ボールは来なかった。' },
      say: { ok: '……自分から行けば、こんなに違うのか' } },
    { id: 'cap1', k: 'captain', fam: 'say', sit: '失点した直後。みんなの顔が下を向いている', think: '主将は自分だ。何を言う？', hint: '主将の仕事は、うまいことを言うことじゃない。',
      ok: ['down', 'うつむく{m}に「次だ、切り替えろ」と声をかける'], safe: ['all', '「集中しよう」と全体に言う'], bad: ['blame', 'ミスした{m}を責める'],
      lock: () => [null, '黙って、自分のプレーだけする', 'いまは主将を任されている。黙ってはいられない'],
      res: { ok: '{n}が{m}の背中をたたいた。チームの顔が上がる。', safe: '声は出した。気づきは起きなかった。', bad: '{m}はうつむいたまま。空気が重くなった。' },
      say: { ok: '全員じゃなくていい。一人ずつでいいんだ' } },
    { id: 'cap2', k: 'captain', fam: 'say', sit: '残り10分。押し込まれている', think: 'このままじゃ崩れる……', hint: '声で、チームの形を戻せ。',
      ok: ['down', '下がりすぎた{m}に「一緒に前へ出よう」と言う'], safe: ['all', '「耐えろ！」と叫ぶ'], bad: ['blame', '前の{m}に「戻ってこい」と怒鳴る'],
      lock: () => [null, '黙って、自分のプレーだけする', 'いまは主将を任されている。黙ってはいられない'],
      res: { ok: '{n}と{m}が前へ出て、チームの形が戻った。', safe: '叫んで耐えた。気づきは起きなかった。', bad: '怒鳴られた{m}が戻り、前に誰もいなくなった。' },
      say: { ok: 'みんなを動かすって、こういうことか' } },
    { id: 'pair1', k: 'pair', fam: 'run', mateR: 'ball', sit: '{r}がボールを持った', think: '{r}は、次にどこへ出す？', hint: '相棒の目を見ろ。言葉より先に動け。',
      ok: ['space', '{r}の目線の先、{d}の空いた所へ走る'], safe: ['short', '{r}の近くへ寄って受ける'], bad: ['offside', '自分の好きなように、裏へ一直線'],
      lock: () => [null, '{r}を無視して、一人で持ち込む', 'いまは{r}と組む課題中。一人では行かない'],
      res: { ok: '{r}の球が、{n}の走る先へぴたりと来た。', safe: '近くで受けた。気づきは起きなかった。', bad: '{r}の見ていた所と、まるで違う所へ走っていた。' },
      say: { ok: '{r}の見てる景色が、分かった' } },
    { id: 'pair2', k: 'pair', fam: 'pass', mateR: 'ok', sit: '{r}が前で動き出した', think: '{r}なら、どこへ走る？', hint: '相棒の癖を思い出せ。',
      ok: ['gap', '{r}の走る先へ、DF の間を通す'], safe: ['back', '後ろの{m}へ預ける'], bad: ['wide', '{r}を見ずに、逆サイドの{m}へ蹴る'],
      lock: () => ['ahead', '{r}を無視して、一人で行く', 'いまは{r}と組む課題中。一人では行かない'],
      res: { ok: '{n}の球に、{r}が走りこんでいた。言葉はいらなかった。', safe: '後ろへ預けた。気づきは起きなかった。', bad: '{r}は手を挙げていたが、球は反対へ行った。' },
      say: { ok: '……通じた。{r}と、通じた' } },
    { id: 'riv1', k: 'rival', fam: 'duel', oppR: true, sit: '紅白戦。{r}と1対1になった', think: '{r}には負けたくない。でも、熱くなるな', hint: '勝ち負けより、何で勝つかを考えろ。',
      ok: ['inside', '先に体を入れて、{r}のコースを切る'], safe: ['apart', '間合いを取って、味方を待つ'], bad: ['behind', 'カッとなって、後ろから足を出す'],
      lock: () => [null, '{r}を避けて、別の相手につく', 'いまは{r}と競う課題中。逃げない'],
      res: { ok: '{n}は{r}の得意な形を先に消した。{r}が顔をしかめる。', safe: '間合いを取って、しのいだ。気づきは起きなかった。', bad: '後ろから出した足で、{r}を倒した。笛が鳴る。' },
      say: { ok: '{r}に勝つ方法、一つ見つけた' } },
    { id: 'riv2', k: 'rival', fam: 'pass', oppR: true, sit: '{r}が寄せてくる', think: '{r}は、こっちの癖を知ってる', hint: '相手を知っているのは、お前も同じだ。',
      ok: ['gap', '{r}が寄せた裏、{d}の{m}へ通す'], safe: ['back', '後ろの{m}へ逃がす'], bad: ['ahead', '意地になって、{r}を抜きにかかる'],
      lock: () => [null, '{r}との勝負を避けて、すぐ下げる', 'いまは{r}と競う課題中。勝負からは逃げない'],
      res: { ok: '{r}が寄せた瞬間、その裏へ通した。{r}が振り返る。', safe: '後ろへ逃がした。気づきは起きなかった。', bad: '抜きにかかったところを、{r}に読まれた。' },
      say: { ok: '{r}が見えてれば、{r}の裏も見える' } },
  ];

  // ---------- 日常の会話（気持ちの課題：役割・舞台・主将・組ませる・競わせる。2つずつ）----------
  YA.KZ_TALK = [
    { id: 'roleT1', k: 'role', place: '帰り道', text: '{n}と帰り道が一緒になった。しばらく黙って歩いたあと、ぽつりと言った。', line: '{c}のことばっかり考えて、自分のプレーができないんです',
      ok: '「仕事をこなすことが、お前のプレーだ。そこに答えがある」', safe: '「慣れれば、そのうちうまくいく」', bad: '「じゃあ、仕事は誰かに代わってもらうか」', say: '仕事が、自分のプレー……。そうか、見えました' },
    { id: 'roleT2', k: 'role', place: 'ロッカー', text: '練習のあと、ロッカーで{n}が一人残っていた。', line: 'みんなに声をかけても、うまく伝わらなくて',
      ok: '「伝える相手を一人に絞れ。誰に一番届けたい？」', safe: '「声は出し続ければいい」', bad: '「伝わらないなら、言わなくていい」', say: '一人に……。そうか、それなら届く' },
    { id: 'stageT1', k: 'stage', place: '寮', text: '夜、寮の食堂で{n}がぼんやりしていた。', line: (c) => (c === 'A' ? '上の試合、全然通用しないです' : 'なんで自分が下なんですか'),
      ok: (c) => (c === 'A' ? '「通用しないのは、上で考える速さがまだないだけだ。体じゃない」' : '「下は落とされた場所じゃない。自分を取り戻す場所だ」'), safe: '「今は我慢の時期だ」', bad: (c) => (c === 'A' ? '「無理なら、B に戻るか」' : '「結果を出さないお前が悪い」'), say: '……そういうことか。分かりました' },
    { id: 'stageT2', k: 'stage', place: '帰り道', text: '帰り道、{n}が足を止めた。', line: (c) => (c === 'A' ? '周りがみんな、うまく見えて' : 'B の試合が楽しいのが、逆に悔しくて'),
      ok: (c) => (c === 'A' ? '「うまく見えるのは、お前が見えるようになった証拠だ」' : '「楽しいと思えたなら、それが戻ってきた証拠だ」'), safe: '「焦らなくていい」', bad: '「そんなことを気にしている暇はない」', say: '見えるようになった、か……。はい' },
    { id: 'capT1', k: 'captain', place: 'ロッカー', text: '試合のあと、ロッカーで{n}がうつむいていた。', line: 'みんな、言うことを聞いてくれなくて……',
      ok: '「聞かせなくていい。お前が一番走れば、みんな見ている」', safe: '「主将はそういうものだ」', bad: '「主将なんだから、もっと強く言え」', say: '自分が一番走る……。それなら、できます' },
    { id: 'capT2', k: 'captain', place: '寮', text: '寮の廊下で、{n}に呼び止められた。', line: '自分のプレーまで、悪くなってる気がします',
      ok: '「全員を見ようとするな。一番近くの一人を見ろ」', safe: '「気にするな」', bad: '「主将を降りるか？」', say: '一番近くの一人……。見えました' },
    { id: 'pairT1', k: 'pair', place: '寮', text: '{n}が寮の廊下で、{r}の部屋の前を素通りした。', line: '{r}とは、やっぱり合わないです',
      ok: '「合わせなくていい。{r}が何を見ているかだけ、聞いてこい」', safe: '「時間がかかるものだ」', bad: '「なら、無理に組まなくていい」', say: '{r}が見てるもの……。聞いてみます' },
    { id: 'pairT2', k: 'pair', place: '帰り道', text: '帰り道、{n}が不満そうに石を蹴った。', line: '{r}、自分にパスを出してくれないんです',
      ok: '「出したくなる所に、お前がいないだけかもしれない」', safe: '「そのうち出てくる」', bad: '「{r}が悪いな。言っておく」', say: '出したくなる所……。そうか' },
    { id: 'rivT1', k: 'rival', place: 'ロッカー', text: '練習のあと、ロッカーで{n}が{r}の背中を見ていた。', line: '{r}に負けてるのが、悔しくて',
      ok: '「{r}にあって、お前にないものは何だ。一つだけ言ってみろ」', safe: '「悔しいなら練習しろ」', bad: '「{r}のほうが上だ。認めろ」', say: '一つだけ……。それなら、分かります' },
    { id: 'rivT2', k: 'rival', place: '帰り道', text: '帰り道、{n}が珍しく自分から話しかけてきた。', line: '{r}ばっかり見てたら、自分のプレーが分からなくなって',
      ok: '「{r}を見るのは、自分を映す鏡だからだ。何が映った？」', safe: '「気にしすぎるな」', bad: '「なら、{r}のことは忘れろ」', say: '鏡……。映ってたのは、自分の足りない所だ' },
  ];
  const TALK_SAY_SAFE = ['……はい', 'そう、ですよね', '……分かりました'];
  const TALK_SAY_BAD = ['……そう、ですよね', '……はい', '……やっぱり、そうなんですね'];

  // ---------- 場面を作る ----------
  const ROLES = ['ok', 'safe', 'bad'];
  function partnerOf(w, p) { const k = p.kd; return k && (k.t === 'pair' || k.t === 'rival') ? w.players[k.c] || null : null; }
  function makeScene(w, p, at, ex) {
    const k = p.kd;
    const b = weekBox(w);
    b.n++;
    b.ids.push(p.id);
    k.sc = (k.sc || 0) + 1;
    const r = YA.rngOf((w.seed | 0) * 23 + wk(w) * 101 + YA.hash(p.id + at + k.sc));
    const talk = at === 'talk';
    const list = (talk ? YA.KZ_TALK : YA.KZ_EYE).filter((x) => x.k === k.t);
    // 同じ課題の中では、前と違う型から（2つを交互に）
    const last = talk ? k.kzT : k.kzE;
    let tp = list[r.int(0, list.length - 1)].id;
    if (list.length > 1 && tp === last) tp = list.find((x) => x.id !== last).id;
    if (talk) k.kzT = tp; else k.kzE = tp;
    return Object.assign({ id: 'kizuki', pid: p.id, at, tp, seed: r.int(1, 1e9), week: w.week, year: w.year, x: null }, ex || {});
  }
  YA.kizukiMake = makeScene;

  // 図の型ごとの配置（0〜1。上が相手のゴール。守りの型は下が自分のゴール）
  // 場所の種類ごとに候補を作り、毎回の乱数と左右の反転で、正解の場所が変わる
  function layout(fam, r) {
    const J = (v) => v + (r() - 0.5) * 0.06;
    const L = { half: 'att', kid: null, ball: null, mates: [], opps: [], spots: {} };
    const mate = (x, y, tag) => { L.mates.push({ x, y, tag }); return L.mates.length - 1; };
    const opp = (x, y, tag) => { L.opps.push({ x, y, tag }); return L.opps.length - 1; };
    const spot = (k, x, y, m, o) => { L.spots[k] = { x: clamp(x, 0.05, 0.95), y: clamp(y, 0.04, 0.96), m: m == null ? null : m, o: o == null ? null : o }; };
    if (fam === 'pass' || fam === 'run') {
      const line = [0.2, 0.4, 0.6, 0.8].map((x) => J(x));
      const ly = J(0.3);
      line.forEach((x) => opp(x, ly + (r() - 0.5) * 0.03));
      opp(0.5, 0.035, 'gk');
      const g = r.int(0, 2); // DF の間のどこが空くか
      const gx = (line[g] + line[g + 1]) / 2;
      if (fam === 'pass') {
        const K = { x: J(r() < 0.5 ? 0.36 : 0.64), y: J(0.64) };
        L.kid = K; L.ball = { x: K.x + 0.012, y: K.y - 0.025 };
        const pr = opp(K.x + (gx > K.x ? -0.05 : 0.05), K.y - 0.09, 'press');
        spot('gap', gx, ly + 0.07, mate(gx, ly + 0.07, 'run'));
        const bs = r() < 0.5 ? -1 : 1;
        spot('back', K.x + bs * 0.17, Math.min(0.94, K.y + 0.25), mate(K.x + bs * 0.17, Math.min(0.94, K.y + 0.25)));
        const far = K.x > 0.5 ? 0.08 : 0.92;
        const wm = mate(far, J(0.47));
        opp(far + (far < 0.5 ? 0.05 : -0.05), L.mates[wm].y - 0.05);
        spot('wide', far, L.mates[wm].y, wm);
        const nx = clamp(K.x + (K.x > 0.5 ? -0.24 : 0.24), 0.1, 0.9);
        const nm = mate(nx, K.y - 0.14);
        opp(nx + 0.03, K.y - 0.16);
        opp(nx - 0.035, K.y - 0.11);
        spot('near', nx, K.y - 0.14, nm);
        const sx = clamp(K.x + (K.x > 0.5 ? -0.3 : 0.3), 0.12, 0.88);
        spot('square', sx, ly - 0.02, mate(sx, ly - 0.02, 'run'));
        spot('shot', 0.5, 0.05);
        spot('ahead', K.x, K.y - 0.22, null, pr);
        opp(J(0.3), J(0.5)); opp(J(0.7), J(0.52));
      } else {
        const B = { x: J(r() < 0.5 ? 0.32 : 0.68), y: J(0.64) };
        const bm = mate(B.x, B.y, 'ball');
        L.ball = { x: B.x + 0.012, y: B.y - 0.025 };
        L.ballMate = bm;
        opp(B.x + 0.05, B.y - 0.08);
        const K = { x: clamp(J(1 - B.x), 0.15, 0.85), y: J(0.45) };
        L.kid = K;
        opp(K.x + (K.x > 0.5 ? 0.05 : -0.05), K.y - 0.06);
        spot('space', gx, ly - 0.12);
        spot('short', B.x + (K.x > B.x ? 0.14 : -0.14), B.y - 0.1, bm);
        const dx = line[g === 0 ? 3 : 0];
        spot('offside', dx, ly - 0.08, null, 0);
        spot('hide', K.x + (K.x > 0.5 ? 0.07 : -0.07), K.y - 0.12);
        mate(J(0.5), J(0.82)); mate(gx > 0.5 ? J(0.15) : J(0.85), J(0.38));
        opp(J(0.5), J(0.5));
      }
    } else if (fam === 'mark' || fam === 'duel') {
      L.half = 'def';
      const line = [0.2, 0.4, 0.6, 0.8].map((x) => J(x));
      const ly = J(0.8);
      mate(0.5, 0.965, 'gk'); // 自分の GK
      if (fam === 'mark') {
        const C = { x: J(r() < 0.5 ? 0.35 : 0.65), y: J(0.46) };
        const ci = opp(C.x, C.y, 'ball');
        L.ball = { x: C.x + 0.012, y: C.y + 0.03 };
        const K = { x: clamp(J(1 - C.x), 0.2, 0.8), y: J(0.66) };
        L.kid = K;
        line.forEach((x, i) => { if (Math.abs(x - K.x) > 0.12) mate(x, ly); });
        const fx = clamp(K.x + (K.x > 0.5 ? 0.17 : -0.17) * (r() < 0.5 ? 1 : -1), 0.1, 0.9);
        spot('free', fx, ly - 0.12, null, opp(fx, ly - 0.12, 'run'));
        spot('zone', K.x, K.y + 0.11);
        spot('carrier', C.x, C.y, null, ci);
        const mx = clamp(C.x + (C.x > 0.5 ? -0.25 : 0.25), 0.1, 0.9);
        opp(mx, J(0.6)); mate(mx + 0.03, 0.64);
        opp(J(0.5), J(0.3));
      } else {
        const O = { x: J(r() < 0.5 ? 0.4 : 0.6), y: J(0.62) };
        const oi = opp(O.x, O.y, 'ball');
        L.ball = { x: O.x + 0.012, y: O.y + 0.035 };
        const s = r() < 0.5 ? -1 : 1;
        const K = { x: O.x + s * 0.12, y: O.y + 0.1 };
        L.kid = K;
        L.duelOpp = oi;
        line.forEach((x) => { if (Math.abs(x - O.x) > 0.15) mate(x, ly); });
        spot('inside', O.x - s * 0.02, O.y + 0.16, null);
        spot('apart', K.x + s * 0.12, K.y + 0.16);
        spot('behind', O.x - s * 0.1, O.y - 0.1);
        opp(J(1 - O.x), J(0.5)); opp(J(0.5), J(0.35));
      }
    } else if (fam === 'hold') {
      const line = [0.25, 0.45, 0.65, 0.8].map((x) => J(x));
      opp(0.5, 0.035, 'gk');
      const K = { x: J(r() < 0.5 ? 0.42 : 0.58), y: J(0.42) };
      L.kid = K;
      line.forEach((x) => { if (Math.abs(x - K.x) > 0.1) opp(x, 0.3); });
      const di = opp(K.x + 0.01, K.y - 0.07, 'press');
      L.duelOpp = di;
      const B = { x: J(K.x + (r() < 0.5 ? -0.12 : 0.12)), y: J(0.75) };
      mate(B.x, B.y, 'ball');
      L.ball = { x: B.x + 0.012, y: B.y - 0.025 };
      const s = r() < 0.5 ? -1 : 1;
      spot('shield', K.x + s * 0.12, K.y + 0.08);
      spot('drop', K.x - s * 0.1, K.y + 0.2);
      spot('turn', K.x + s * 0.03, K.y - 0.18);
      mate(J(0.15), J(0.5)); mate(J(0.85), J(0.5)); opp(J(0.5), J(0.6));
    } else {
      // say：声。図には味方の並びと、声をかける相手
      L.half = 'def';
      const K = { x: J(0.5), y: J(0.6) };
      L.kid = K;
      mate(0.5, 0.965, 'gk');
      const xs = [0.15, 0.38, 0.62, 0.85].map((x) => J(x));
      const ids = xs.map((x) => mate(x, J(0.8)));
      const ms = [mate(J(0.25), J(0.55)), mate(J(0.75), J(0.55))];
      const fw = mate(J(0.5), J(0.3));
      const pool = ids.concat(ms, [fw]);
      // 声をかける2人（うつむく子・責める先）は毎回入れ替える
      const a = pool.splice(r.int(0, pool.length - 1), 1)[0];
      const b = pool.splice(r.int(0, pool.length - 1), 1)[0];
      spot('down', L.mates[a].x, L.mates[a].y, a);
      spot('blame', L.mates[b].x, L.mates[b].y, b);
      spot('all', K.x + (r() < 0.5 ? -0.1 : 0.1), K.y - 0.12);
      for (let i = 0; i < 4; i++) opp(J(0.2 + i * 0.2), J(0.35 + (i % 2) * 0.12));
      L.ball = { x: 0.5, y: 0.5 };
      L.noBall = true;
    }
    // 左右を反転して、正解の場所をもう一段ばらす
    if (r() < 0.5) {
      const f = (o) => { if (o) o.x = 1 - o.x; };
      f(L.kid); f(L.ball); L.mates.forEach(f); L.opps.forEach(f); Object.values(L.spots).forEach(f);
      L.mirror = true;
    }
    return L;
  }

  // 場面の中身（場所の種類 → 図の上の位置・ボタンの文）
  const tpOf = (e) => (e.at === 'talk' ? YA.KZ_TALK : YA.KZ_EYE).find((x) => x.id === e.tp);
  const fn = (v, c) => (typeof v === 'function' ? v(c) : v);
  function ctxOf(w, p, e) {
    const k = p.kd || {};
    const q = partnerOf(w, p);
    const cLabel = k.t === 'convert' ? posName(k.c) : k.t === 'rival' || k.t === 'pair' ? sur(q) : k.c != null ? (YA.kadaiDef(k.t).label(w, k.c) || '').replace(/^「|」$/g, '') : '';
    return { n: sur(p), c: k.t === 'stage' ? k.c : cLabel, cl: cLabel, o: posName(p.main), r: q ? sur(q) : '相棒' };
  }
  const dirWord = (L, s) => { const dx = s.x - L.kid.x; return Math.abs(dx) < 0.09 ? '正面' : dx < 0 ? '左' : '右'; };
  // 名前：図の味方には同じチームの子の名字を付ける（相棒・競う相手は本人）
  function nameMates(w, p, e, L, T) {
    const team = all(w).filter((q) => q.id !== p.id && q.team === p.team && q.pos !== 'GK');
    const pool = team.length >= 6 ? team : all(w).filter((q) => q.id !== p.id && q.pos !== 'GK');
    const r = YA.rngOf(e.seed + 7);
    const used = new Set();
    const q = partnerOf(w, p);
    if (q) used.add(q.id);
    const names = L.mates.map((m) => {
      if (m.tag === 'gk') return '';
      let c = null;
      for (let i = 0; i < 8 && pool.length; i++) { const x = pool[r.int(0, pool.length - 1)]; if (!used.has(x.id)) { c = x; break; } }
      if (c) used.add(c.id);
      return c ? sur(c) : '';
    });
    if (q && T.mateR === 'ball' && L.ballMate != null) names[L.ballMate] = sur(q);
    if (q && T.mateR === 'ok') { const s = L.spots[T.ok[0]]; if (s && s.m != null) names[s.m] = sur(q); }
    return names;
  }
  // 選手の目の場面の中身。戻り値：見出し・状況・心の声・ヒント・3つの選択肢（A〜C、並びは毎回入れ替え）・鍵つきの手・図
  YA.kizukiView = function (w, e) {
    const p = w.players[e.pid];
    const T = tpOf(e);
    if (!p || !p.kd || !T) return null;
    const cx = ctxOf(w, p, e);
    const r = YA.rngOf(e.seed);
    const L = layout(T.fam, r);
    const names = nameMates(w, p, e, L, T);
    const order = ROLES.slice();
    for (let i = order.length - 1; i > 0; i--) { const j = r.int(0, i); const t = order[i]; order[i] = order[j]; order[j] = t; }
    const optOf = (role) => {
      const [kind, txt] = T[role];
      const s = L.spots[kind] || { x: 0.5, y: 0.5, m: null };
      const m = s.m != null ? names[s.m] || '味方' : '';
      const o = Object.assign({}, cx, { m, d: dirWord(L, s) });
      return { role, kind, text: sub(txt, o), x: s.x, y: s.y, mate: m, ctx: o };
    };
    const opts = order.map((role, i) => Object.assign(optOf(role), { key: 'ABC'[i] }));
    const lk = T.lock(p.kd.c != null ? cx.c : '') || [];
    const ls = lk[0] ? L.spots[lk[0]] : null;
    const lock = { key: 'D', text: sub(lk[1] || '', cx), why: sub(lk[2] || '', cx), x: ls ? ls.x : null, y: ls ? ls.y : null };
    // 鍵の手が選択肢と同じ場所なら、図には出さない（ボタンだけ）
    if (ls && opts.some((o) => Math.abs(o.x - ls.x) < 0.06 && Math.abs(o.y - ls.y) < 0.06)) { lock.x = null; lock.y = null; }
    if (T.oppR && cx.r) { const oi = L.duelOpp != null ? L.duelOpp : L.opps.findIndex((o) => o.tag === 'press'); if (oi >= 0) L.opps[oi].name = cx.r; }
    const st = YA.kadaiState ? YA.kadaiState(w, p) : null;
    return {
      p, e, T, L, names, opts, lock,
      sit: sub(fn(T.sit, cx.c), cx), think: YA.voice ? YA.voice(p, sub(fn(T.think, cx.c), cx)) : sub(fn(T.think, cx.c), cx), hint: sub(fn(T.hint, cx.c), cx),
      kadai: YA.kadaiLabel(w, p.kd.t, p.kd.c), weeks: st ? `${st.e + 1}週目` : '', place: e.at,
    };
  };
  // 日常の会話の中身
  YA.kizukiTalkView = function (w, e) {
    const p = w.players[e.pid];
    const T = tpOf(e);
    if (!p || !p.kd || !T) return null;
    const cx = ctxOf(w, p, e);
    const r = YA.rngOf(e.seed);
    const order = ROLES.slice();
    for (let i = order.length - 1; i > 0; i--) { const j = r.int(0, i); const t = order[i]; order[i] = order[j]; order[j] = t; }
    const line = sub(fn(T.line, cx.c), cx);
    return { p, T, place: T.place, text: `${sub(T.text, cx)} ${p.name}「${YA.voice ? YA.voice(p, line) : line}」`, opts: order.map((role) => ({ role, text: sub(fn(T[role], cx.c), cx) })) };
  };

  // ---------- 選んだあと ----------
  // 正しい手のときに、何が起きるか（変えずに見るだけ）：awake＝覚醒 / clue＝何かが違う
  YA.kizukiPreview = function (w, e, role) {
    const p = w.players[e.pid];
    if (!p || !p.kd) return 'gone';
    if (role === 'ok') return p.kd.fit === 'yes' ? 'awake' : 'clue';
    return role;
  };
  const PLACE_WORD = { match: '試合の中で', matchB: 'B の試合の中で', live: '試合の中で', prac: '練習の紅白戦で', talk: '' };
  // 画面に出す言葉（kind：awake / clue / safe / bad。x：反映したあとに分かること＝覚醒の形・見えた手がかり・伸びた能力。
  // 試合の途中の場面は反映が試合のあとなので、x なしで作る）
  function describe(w, e, role, kind, x) {
    const p = w.players[e.pid];
    const T = tpOf(e);
    const cx = e._cx || ctxOf(w, p, e);
    const talk = e.at === 'talk';
    const o = Object.assign({}, cx, { m: e._m || '味方', d: e._d || '' });
    const resT = talk ? '' : sub((T.res || {})[role] || '', o);
    const V = (s) => (YA.voice ? YA.voice(p, s) : s);
    const out = { kind, head: '', text: '', say: '', tag: '' };
    if (kind === 'awake') {
      out.head = '見えた。';
      out.text = talk ? `${sur(p)}は、しばらく黙っていた。それから、顔を上げた。` : resT;
      out.say = V(sub(talk ? T.say : (T.say || {}).ok || '見えた', o));
      out.tag = x ? `覚醒：${x.form}（課題「${x.nm}」が実を結んだ）` : `覚醒――課題「${YA.kadaiLabel(w, p.kd.t, p.kd.c)}」が実を結んだ`;
    } else if (kind === 'clue') {
      out.head = '何かが違う';
      out.text = (talk ? `${sur(p)}は、うなずいた。` : resT) + 'でも、どこかしっくりこない。この課題では、化けるところまではいかないのかもしれない。';
      out.say = V('できた……。でも、なんか違う気がする');
      // 数字は出さない（2026-11-27 段5）
      out.tag = x ? (x.clue ? `新しい手がかり：「${x.clue}」` : '手がかりは出そろっている') + (x.ab ? `・${x.ab}が少し伸びた` : '') : '新しい手がかりが見える（試合のあとに）・少し伸びる';
    } else if (kind === 'safe') {
      out.head = talk ? 'その場は収まった' : '無難な一手';
      out.text = talk ? `${sur(p)}は小さくうなずいた。話はそれで終わった。` : resT || R_SAFE;
      out.say = V(talk ? TALK_SAY_SAFE[e.seed % 3] : SAY_SAFE[e.seed % 3]);
      out.tag = '気づきは次の機会へ持ち越し';
    } else {
      out.head = '悔しい';
      out.text = talk ? `${sur(p)}は黙りこんだ。言葉が届かなかった。` : resT || R_BAD;
      out.say = V(talk ? TALK_SAY_BAD[e.seed % 3] : SAY_BAD[e.seed % 3]);
      out.tag = '気づきは次の機会へ持ち越し';
    }
    return out;
  }
  // 変えずに、選んだときの言葉だけ（試合の途中の場面）
  YA.kizukiDescribe = function (w, e, role) {
    const kind = YA.kizukiPreview(w, e, role);
    if (kind === 'gone') return { kind, head: '', text: '', say: '', tag: '' };
    return describe(w, e, role, kind, null);
  };
  // 反映する。戻り値：{ kind, head, text, say, tag }
  YA.kizukiSettle = function (w, e, role) {
    const p = w.players[e.pid];
    if (!p || !p.kd) return { kind: 'gone', head: '', text: '', say: '', tag: '' };
    const k = p.kd;
    const T = tpOf(e);
    const talk = e.at === 'talk';
    // 採点（試合のあとに出た場面は、残っている直近の採点を直す。試合の途中の場面は applyMatch の前に直す）
    if ((e.at === 'match' || e.at === 'matchB') && RDELTA[role]) {
      const rl = (p.rl || [])[(p.rl || []).length - 1];
      if (rl && rl.y === e.year && rl.w === e.week && rl.t === (e.at === 'matchB' ? 'B' : 'A')) rl.r = Math.round(clamp(rl.r + RDELTA[role], 3, 10) * 10) / 10;
    }
    k.kzN = (k.kzN || 0) + 1;
    e._cx = ctxOf(w, p, e); // 覚醒すると課題が閉じるので、言葉の材料は先に取っておく
    const kind = YA.kizukiPreview(w, e, role);
    let x = null;
    if (kind === 'awake') {
      const nm = YA.kadaiLabel(w, k.t, k.c);
      YA.kadaiAwakenNow(w, p, talk ? `${T.place}での会話で` : PLACE_WORD[e.at] || '試合の中で');
      x = { nm, form: p.aw ? p.aw.form : '' };
    } else if (kind === 'clue') {
      // 合っていない：何かが違う → 手がかり +1・少し伸びる。この課題では、もう場面は来ない
      k.ng = true;
      const clue = YA.kadaiClueUp ? YA.kadaiClueUp(w, p) : null;
      const ns = (YA.POS_ABS15[p.main] || []).filter((n) => p.ab[n] != null).sort((a, b) => p.ab[a] - p.ab[b]).slice(0, 1);
      for (const n of ns) p.ab[n] = Math.min(20, p.ab[n] + 1);
      x = { clue, ab: ns[0] || null };
      YA.noteTier(w, 2, `${p.num}番 ${p.name}（課題「${YA.kadaiLabel(w, k.t, k.c)}」）：正しい手を選べたが、何かが違うようだ。${clue ? `手がかり「${clue}」` : ''}`, p.id);
    } else if (kind === 'bad') p.conf = clamp((p.conf || 50) - 4, 0, 100);
    // 記録（点検と、あとで見返すため）
    w.kzLog = (w.kzLog || []).concat([{ y: e.year, w: e.week, pid: p.id, at: e.at, tp: e.tp, role, kind, fit: k.fit }]).slice(-60);
    return describe(w, e, role, kind, x);
  };

  // おまかせ：KADAI_SPARK の確率で正しい手、外れたら7割は無難・3割は間違い
  YA.kizukiAutoRole = function (w, e) {
    const r = YA.rngOf((e.seed | 0) * 3 + 11);
    if (r() < YA.KADAI_SPARK) return 'ok';
    return r() < 0.7 ? 'safe' : 'bad';
  };
  // 覚醒の窓（forced の 'awake'）を、いまの列へ移す（すぐに見せる）
  YA.kizukiTakeAwake = function (w, pid) {
    const i = (w.forced || []).findIndex((f) => f.id === 'awake' && f.pid === pid);
    if (i < 0) return null;
    return w.forced.splice(i, 1)[0];
  };
  // 試合のあとの場面（w.kzNow）を、おまかせで済ませる
  YA.kizukiAuto = function (w, log) {
    let n = 0;
    while (w.kzNow && w.kzNow.length) {
      const e = w.kzNow.shift();
      if (!e) continue;
      // 画面で見た試合で覚醒した窓などは、ふだんの出来事へ回す
      if (e.id !== 'kizuki') { w.forced = (w.forced || []).concat([e]); continue; }
      const r = YA.kizukiSettle(w, e, YA.kizukiAutoRole(w, e));
      if (r.kind !== 'gone') { n++; if (log) log.events.push('気づきの場面'); }
    }
    return n;
  };

  // ---------- 出来事の仕組みに乗せる（練習・日常は週の進行の中で。試合の場面が残っていたときも）----------
  YA.EVENTS.push({ id: 'kizuki', name: '気づきの場面', weight: 0, pick: () => null, text: () => '', opts: [] });
  YA.EVENT_ABOUT.kizuki = '課題の後半の子に来る、気づきの場面です。正しい見え方・言葉を選ぶと、課題が合っていれば覚醒します。無難な手や間違いは、次の機会へ持ち越し。';
  const TITLE = { match: '試合の一場面', matchB: 'B の試合の一場面', live: '試合の一場面', prac: '練習：紅白戦の一場面' };
  YA.kizukiTitle = (e, v) => (e.at === 'talk' ? `日常：${v && v.place ? v.place : ''}で` : TITLE[e.at] || '気づきの場面');
  const view0 = YA.eventView;
  YA.eventView = function (w, e) {
    if (e.id !== 'kizuki') return view0(w, e);
    const p = w.players[e.pid];
    if (!p || !p.kd) return null;
    if (e.at === 'talk') {
      const v = YA.kizukiTalkView(w, e);
      if (!v) return null;
      return { name: YA.kizukiTitle(e, v), text: v.text, p, opts: v.opts.map((o) => o.text), info: v.opts.map((o) => ({ label: o.text, kind: null, hint: '' })), roles: v.opts.map((o) => o.role), about: '課題の後半の子との会話です。正しい言葉を返すと、気づくことがあります。', kizuki: true };
    }
    const v = YA.kizukiView(w, e);
    if (!v) return null;
    return { name: YA.kizukiTitle(e), text: `${v.sit}。${p.name}の心の声「${v.think}」`, p, opts: v.opts.map((o) => `${o.key} ${o.text}`), info: v.opts.map((o) => ({ label: `${o.key} ${o.text}`, kind: null, hint: '' })), roles: v.opts.map((o) => o.role), about: YA.EVENT_ABOUT.kizuki, kizuki: true, eye: true };
  };
  const res0 = YA.resolveEvent;
  YA.resolveEvent = function (w, e, idx) {
    if (e.id !== 'kizuki') return res0(w, e, idx);
    const v = YA.eventView(w, e);
    if (!v) return { line: '', small: '' };
    const role = v.roles[Math.max(0, Math.min(v.roles.length - 1, idx | 0))];
    const r = YA.kizukiSettle(w, e, role);
    // 出来事の窓の結果は「名字は、」で始まるので、それに続く形にする
    return { line: `${r.head}――${r.text.replace(new RegExp('^' + sur(v.p) + 'は、?'), '')}${r.say ? `「${r.say}」` : ''}`, small: r.tag, kz: r };
  };
  const ap0 = YA.autoPick;
  YA.autoPick = function (w, e, v) {
    if (e.id !== 'kizuki' || !v || !v.roles) return ap0(w, e, v);
    return Math.max(0, v.roles.indexOf(YA.kizukiAutoRole(w, e)));
  };

  // ---------- 毎週：練習の紅白戦と、日常の会話（出来事と同じように週の進行の中で）----------
  const kw0 = YA.kadaiWeek;
  YA.kadaiWeek = function (w) {
    // 試合のあとの場面が見ないまま残っていたら、今週の出来事へ回す（課題の終わりはその場面のあと）
    if (w.kzNow && w.kzNow.length) { w.forced = (w.forced || []).concat(w.kzNow.filter(Boolean)); w.kzNow = []; }
    const res = kw0.apply(this, arguments);
    const r = YA.rngOf((w.seed | 0) * 41 + wk(w) * 7 + 3);
    const few = (xs) => xs.slice().sort((a, b) => (a.kd.sc || 0) - (b.kd.sc || 0) || (r() - 0.5))[0];
    // 練習：紅白戦の一場面は週1回まで
    const pc = all(w).filter((p) => YA.kizukiCan(w, p, 'prac'));
    if (pc.length && r.chance(YA.KZ_RATE.prac)) { const p = few(pc); w.forced = (w.forced || []).concat([makeScene(w, p, 'prac')]); }
    // 日常：会話は週1回まで
    const tc = all(w).filter((p) => YA.kizukiCan(w, p, 'talk'));
    if (tc.length && r.chance(YA.KZ_RATE.talk)) { const p = few(tc); w.forced = (w.forced || []).concat([makeScene(w, p, 'talk')]); }
    return res;
  };

  // ---------- 試合：画面で見る A の試合は途中で止める。それ以外は試合のあと ----------
  const gate = (w, which) => YA.rngOf((w.seed | 0) * 13 + wk(w) * 31 + (which === 'B' ? 7 : 0)).chance(YA.KZ_RATE.match);
  const pickOne = (w, which, xs) => { const r = YA.rngOf((w.seed | 0) * 17 + wk(w) * 37 + (which === 'B' ? 5 : 0)); return xs.slice().sort((a, b) => (a.kd.sc || 0) - (b.kd.sc || 0) || (a.id < b.id ? -1 : 1))[r.int(0, Math.min(1, xs.length - 1))]; };
  // 画面で見る A の試合のはじめに、止める子と時間を決める（決まらなければ null）
  YA.kizukiPlan = function (w, m) {
    if (!w || !m || !gate(w, 'A')) return null;
    const ids = (m.home.lineup || []).map((s) => s.pid);
    const c = ids.map((id) => w.players[id]).filter((p) => p && YA.kizukiCan(w, p, 'match'));
    if (!c.length) return null;
    const p = pickOne(w, 'A', c);
    const r = YA.rngOf((w.seed | 0) * 19 + wk(w) * 43);
    return { pid: p.id, min: r.int(25, 80) };
  };
  // 試合の途中：その子がまだピッチにいれば、場面を作る（数はここで数える）
  YA.kizukiLiveScene = function (w, m, P) {
    const p = w.players[P.pid];
    const t = m.home;
    if (!p || !t.onPitch || !t.onPitch.has(P.pid) || (t.players[P.pid] && t.players[P.pid].sentOff)) return null;
    if (!YA.kizukiCan(w, p, 'match')) return null;
    return makeScene(w, p, 'live', { min: m.min, ml: m.minLabel ? m.minLabel() : String(m.min), gf: m.score.home, ga: m.score.away, opp: oppName(m) });
  };
  const am0 = YA.applyMatch;
  YA.applyMatch = function (w, m, which, opp, scheduled) {
    const kz = m && m._kz;
    if (kz && which === 'A') {
      const mp = m.home.players[kz.e.pid];
      if (mp && mp.st && mp.st.rating != null && RDELTA[kz.role]) mp.st.rating = Math.round(clamp(mp.st.rating + RDELTA[kz.role], 3, 10) * 10) / 10;
    }
    const res = am0.apply(this, arguments);
    if (which !== 'A' && which !== 'B') return res;
    w.kzNow = w.kzNow || [];
    if (kz && which === 'A') {
      // 試合の途中で選んだ中身は、試合が終わってから反映する（結果を変えないため）
      kz.out = YA.kizukiSettle(w, kz.e, kz.role);
      if (kz.out.kind === 'awake') { const a = YA.kizukiTakeAwake(w, kz.e.pid); if (a) w.kzNow.push(a); }
      return res;
    }
    if (!gate(w, which)) return res;
    const played = Object.keys((m.home && m.home.players) || {}).map((id) => w.players[id]).filter((p) => p && p.st && p.st.minutes >= 20);
    let c = played.filter((p) => YA.kizukiCan(w, p, 'match'));
    const plan = m._kzPlan;
    if (plan && c.some((p) => p.id === plan.pid)) c = c.filter((p) => p.id === plan.pid);
    if (!c.length) return res;
    const p = pickOne(w, which, c);
    const r = YA.rngOf((w.seed | 0) * 19 + wk(w) * 43 + (which === 'B' ? 3 : 0));
    const mins = Math.max(20, Math.min(90, p.st.minutes | 0));
    w.kzNow.push(makeScene(w, p, which === 'B' ? 'matchB' : 'match', { min: plan && plan.pid === p.id ? plan.min : r.int(Math.max(10, 90 - mins + 5), 88), gf: m.score.home, ga: m.score.away, opp: oppName(m) }));
    return res;
  };

  // ---------- 画面：選手の目 ----------
  const PW = 500, PH = 340;
  const px = (L, o) => [Math.round(14 + o.x * (PW - 28)), Math.round(12 + o.y * (PH - 24))];
  const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
  function pitchSvg(v, picked) {
    const L = v.L;
    const out = [];
    out.push(`<svg class="kzsvg" viewBox="0 0 ${PW} ${PH}" preserveAspectRatio="xMidYMid meet" xmlns="http://www.w3.org/2000/svg">`);
    out.push('<defs><pattern id="kzst" width="500" height="40" patternUnits="userSpaceOnUse"><rect width="500" height="20" fill="#3d8c4d"/><rect y="20" width="500" height="20" fill="#38834a"/></pattern>'
      + '<filter id="kzgl"><feGaussianBlur stdDeviation="3" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>'
      + '<radialGradient id="kzfl"><stop offset="0" stop-color="#f5c518" stop-opacity=".55"/><stop offset="1" stop-color="#f5c518" stop-opacity="0"/></radialGradient></defs>');
    out.push(`<rect width="${PW}" height="${PH}" fill="url(#kzst)"/>`);
    // 線：攻めの型は上に相手のゴール、守りの型は下に自分のゴール
    const g = L.half === 'def';
    out.push('<g stroke="#fff" stroke-width="2" fill="none" opacity=".8">');
    out.push(`<rect x="14" y="${g ? -40 : 12}" width="${PW - 28}" height="${PH + 28}"/>`);
    out.push(g ? `<rect x="140" y="${PH - 82}" width="220" height="70"/><rect x="200" y="${PH - 38}" width="100" height="26"/><circle cx="250" cy="0" r="50"/>` : `<rect x="140" y="12" width="220" height="70"/><rect x="200" y="12" width="100" height="26"/><circle cx="250" cy="${PH}" r="50"/>`);
    out.push('</g>');
    const [kx, ky] = px(L, L.kid);
    // 覚醒の光（選手の下に敷く）
    if (picked && picked.kind === 'awake') { const [x, y] = px(L, picked.opt); out.push(`<circle cx="${x}" cy="${y}" r="130" fill="url(#kzfl)"/>`); }
    // 視野の扇（前方を広く。正解の向きには寄せない）
    const fwd = g ? (L.opps.find((o) => o.tag === 'ball') || { x: 0.5, y: 0.3 }) : { x: L.kid.x, y: 0 };
    const [fx, fy] = px(L, fwd);
    const ang = Math.atan2(fy - ky, fx - kx);
    const R = 330;
    const a1 = ang - 0.95, a2 = ang + 0.95;
    out.push(`<path d="M${kx} ${ky} L${Math.round(kx + R * Math.cos(a1))} ${Math.round(ky + R * Math.sin(a1))} A${R} ${R} 0 0 1 ${Math.round(kx + R * Math.cos(a2))} ${Math.round(ky + R * Math.sin(a2))} Z" fill="#fff" opacity=".08"/>`);
    // 相手（白）・味方（青）
    for (const o of L.opps) { const [x, y] = px(L, o); out.push(`<circle cx="${x}" cy="${y}" r="9" fill="${o.tag === 'gk' ? '#ffd27a' : '#fff'}" stroke="#14284b" stroke-width="2"/>`); if (o.name) out.push(`<text x="${x + 11}" y="${y - 9}" class="kznm">${esc(o.name)}</text>`); }
    L.mates.forEach((m, i) => { const [x, y] = px(L, m); out.push(`<circle cx="${x}" cy="${y}" r="9" fill="${m.tag === 'gk' ? '#7fb0ff' : '#2f7ed8'}" stroke="#fff" stroke-width="2"/>`); if (v.names[i]) out.push(`<text x="${x + 11}" y="${y + 14}" class="kznm">${esc(v.names[i])}</text>`); });
    // その子（黄色の縁）とボール
    out.push(`<circle cx="${kx}" cy="${ky}" r="11" fill="#2f7ed8" stroke="#f5c518" stroke-width="3"/>`);
    if (!L.noBall) { const [bx, by] = px(L, L.ball); out.push(`<circle cx="${bx}" cy="${by}" r="4" fill="#ffd400" stroke="#000"/>`); }
    out.push(`<text x="${kx + 13}" y="${ky + 20}" class="kznm kzme">${esc(sur(v.p))}</text>`);
    // 選択肢：選ぶ前は3つが光る。選んだあとは、選んだ線だけ
    const from = L.ballMate != null && v.T.fam === 'run' ? [kx, ky] : [kx, ky];
    if (!picked) {
      for (const o of v.opts) { const [x, y] = px(L, o); out.push(`<path d="M${from[0]} ${from[1]} L${x} ${y}" stroke="#f5c518" stroke-width="2.5" fill="none" stroke-dasharray="6 5" filter="url(#kzgl)"/><circle cx="${x}" cy="${y}" r="16" fill="none" stroke="#f5c518" stroke-width="3" filter="url(#kzgl)"/>`); }
      if (v.lock.x != null) { const [x, y] = px(L, v.lock); out.push(`<path d="M${kx} ${ky} L${x} ${y}" stroke="#9aa" stroke-width="2.5" fill="none" stroke-dasharray="3 5"/>`); }
      for (const o of v.opts) { const [x, y] = px(L, o); const lx = x + (x > PW - 40 ? -20 : 18), ly = y - 18 < 14 ? y + 18 : y - 18; out.push(`<g class="kzpin" data-k="${o.key}"><circle cx="${lx}" cy="${ly}" r="15" fill="#f5c518"/><text x="${lx}" y="${ly + 5}" text-anchor="middle" class="kzlt">${o.key}</text></g>`); }
      if (v.lock.x != null) { const [x, y] = px(L, v.lock); out.push(`<g class="kzpin kzlockpin" data-k="D"><circle cx="${x}" cy="${y}" r="12" fill="#8a94a8"/><text x="${x}" y="${y + 4}" text-anchor="middle" class="kzlt" fill="#fff">D</text></g>`); }
    } else {
      const o = picked.opt;
      const [x, y] = px(L, o);
      const good = picked.kind === 'awake' || picked.kind === 'clue';
      out.push(`<path d="M${from[0]} ${from[1]} L${x} ${y}" stroke="${good ? '#f5c518' : '#cfd6e2'}" stroke-width="4" fill="none" ${picked.role === 'bad' ? 'stroke-dasharray="8 6"' : ''}/>`);
      if (picked.role === 'bad') out.push(`<text x="${x}" y="${y + 6}" text-anchor="middle" class="kzx">×</text>`);
    }
    out.push('</svg>');
    return out.join('');
  }
  // 選手の目の画面。o = { live: true（試合の途中）, onPick(role) → 結果 { kind, head, text, say, tag }, onDone(結果) }
  YA.kizukiScreen = function (w, e, o) {
    const h = YA._ui.h;
    const v = YA.kizukiView(w, e);
    if (!v) return null;
    const p = v.p;
    const box = h('div', { class: 'kzbox' });
    const pitch = h('div', { class: 'kzpitch' });
    const side = h('div', { class: 'kzside' });
    const lockMsg = h('div', { class: 'kzlockmsg', hidden: true });
    const ourName = (w.clubName || '').replace(/U-18$/, '').trim() || 'こちら';
    const bar = h('div', { class: 'kzbar' });
    const stopTx = h('span', { class: 'kzstop' }, `⏸ 時間が止まった ─ ${sur(p)}の目で選ぶ`);
    if (e.at === 'prac') bar.append(h('span', {}, '紅白戦'), h('span', { class: 'kzmin' }, '練習の一場面'), stopTx);
    else bar.append(h('span', { class: 'kztn' }, ourName), h('span', { class: 'kzsc' }, `${e.gf != null ? e.gf : 0} - ${e.ga != null ? e.ga : 0}`), h('span', { class: 'kztn' }, e.opp || ''), h('span', { class: 'kzmin' }, (e.at === 'live' ? '' : e.at === 'matchB' ? 'B の試合 ' : '試合の一場面 ') + (e.min ? (e.min > 45 ? `後半${e.min - 45}分` : `前半${e.min}分`) : '')), stopTx);
    let done = false;
    const pick = (opt) => {
      if (done) return;
      done = true;
      lockMsg.hidden = true;
      e._m = opt.mate; e._d = opt.ctx.d;
      const res = o.onPick(opt.role);
      pitch.innerHTML = pitchSvg(v, { opt, role: opt.role, kind: res.kind });
      if (res.kind === 'awake') { box.classList.add('kzawake'); if (YA.kzFlash) YA.kzFlash(); } // 段5：「見えた。」で画面が一瞬白く光る
      stopTx.textContent = o.live ? `▶ 再開 ─ ${res.kind === 'awake' ? sur(p) + 'が化けた' : '試合に戻る'}` : res.kind === 'awake' ? `${sur(p)}が化けた` : '気づきの場面';
      side.replaceChildren(h('div', { class: 'kzres' },
        h('div', { class: 'kzrtop' }, YA.faceEl(w, p, 64), h('h2', { class: res.kind === 'awake' ? '' : 'grey' }, res.head)),
        h('p', {}, res.text),
        res.say ? h('div', { class: 'kzsay' }, `「${res.say}」`) : null,
        h('p', { class: 'kztag' + (res.kind === 'awake' ? ' gold' : '') }, res.tag),
        o.live && res.kind === 'awake' ? h('p', { class: 'kznote' }, '覚醒は試合のあとに反映されます（この試合の結果は変わりません）') : null,
        h('button', { class: 'kzgo', onclick: () => o.onDone(res) }, o.live ? '▶ 再開' : '次へ')));
    };
    const tryLock = () => { lockMsg.textContent = v.lock.why; lockMsg.hidden = false; };
    pitch.innerHTML = pitchSvg(v, null);
    pitch.addEventListener('click', (ev) => {
      const g = ev.target && ev.target.closest ? ev.target.closest('.kzpin') : null;
      if (!g) return;
      const k = g.getAttribute('data-k');
      if (k === 'D') return tryLock();
      const opt = v.opts.find((x) => x.key === k);
      if (opt) pick(opt);
    });
    side.append(
      h('div', { class: 'kzwho' }, YA.faceEl(w, p, 58), h('div', {}, h('b', {}, `${p.name}（高${p.grade}・${posName(p.main)}）`), h('small', {}, `課題：${v.kadai}　${v.weeks}`), h('small', {}, v.sit))),
      h('div', { class: 'kzthink' }, v.think),
      h('div', { class: 'kzhint' }, `コーチ：「${v.hint}」`),
      ...v.opts.map((opt) => h('button', { class: 'kzopt', 'data-k': opt.key, onclick: () => pick(opt) }, h('i', {}, opt.key), h('span', {}, opt.text))),
      h('button', { class: 'kzopt lock', 'data-k': 'D', onclick: tryLock }, h('i', {}, 'D'), h('span', {}, v.lock.text)));
    box.append(bar, h('div', { class: 'kzmain' }, pitch, side), lockMsg);
    box._view = v;
    return box;
  };
})();
