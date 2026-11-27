// 段5「文章と演出の仕上げ」（2026-11-27 ユーザー「この案」。仕様は side-session-notes の youth-finish-spec.md）
// 文章：
//  ・台詞を本人の口調に（story.js の YA.TONES 10通り）。出来事・面談の反応に口調の一言を添える（YA.toneLine・YA.reactSay）
//  ・会話から数字を外す：答えを選んだあとの「自信 +3」「信頼+8」のような人の数字を、会話の画面とお知らせの本文に出さない（YA.fxStrip）。
//    代わりに本人の反応で見せる（効き目の向き＝良い・ふつう・悪い × 口調）。能力・信頼などの数字そのものは選手の画面に残す
//  ・大事なお知らせに、コーチか本人の一言（YA.noteSay → お知らせの n.say。同じ言い回しは続けない）。月ごとのまとめは短いまま
// 演出（CSS のアニメーションだけ。動く絵・表情の顔は足さない。おまかせ進行では出さない）：
//  ・覚醒を画面いっぱいに（YA.awakeShow：暗い背景 → 大きく「覚醒」→ 形の名前 → 覚醒の特性 → 本人の一言。タップで飛ばせる）
//  ・気づきの「見えた。」で画面が一瞬白く光る（YA.kzFlash）
//  ・課題を出したとき・あきらめたときの、本人の顔と一言の短い場面（YA.fxScene・あきらめは週の中で起きるので w.fxQ に積む）
//  ・新聞は出るときに紙が広がる（style.css の .np の animation）
// 音：気づき・覚醒・あきらめ（extra.js の YA.sfx）
(function () {
  'use strict';
  const YA = (globalThis.YA = globalThis.YA || {});
  const sur = (p) => String(p.name).split(' ')[0];
  const toneOf = (p) => (YA.toneOf ? YA.toneOf(p) : '丁寧');
  const hash = (s) => (YA.hash ? YA.hash(String(s)) : 0);

  // ---------- 会話から数字を外す ----------
  // 人の数字（自信・調子・信頼（クラブの「信頼度」は除く）・疲れ・不満・戦術理解・雰囲気・〜との関係）を外す。
  // クラブの数（予算・評判・信頼度・規律・育成基金・施設）と「伸び盛り 16週」「2週間不在」は残す
  const KEY = '(?:自信|調子|信頼(?!度)|疲れ|不満|戦術理解|雰囲気|(?:[^\\s・。、（）「」/]{1,6}\\s)?[^\\s・。、（）「」/]{1,8}との関係)';
  const WHO = '(?:[^・。、（）「」/\\s]{1,6}\\s[^・。、（）「」/\\s]{1,6}の|[^・。、（）「」/\\s]{0,10}?の)?';
  const TOK = new RegExp(WHO + KEY + '\\s*[+＋−\\-]\\s*\\d+(?:\\.\\d+)?', 'g');
  YA.FX_NUM = new RegExp(KEY + '\\s*[+＋−\\-]\\s*\\d'); // 点検用：人の数字が残っていないか
  YA.fxStrip = function (s) {
    if (!s || typeof s !== 'string') return { text: s, hit: false };
    let hit = false;
    let t = s.replace(TOK, () => { hit = true; return ''; });
    if (!hit) return { text: s, hit: false };
    t = t.replace(/（[\s・、/]*）/g, '')
      .replace(/（[・\s/、]+/g, '（').replace(/[・\s/、]+）/g, '）')
      .replace(/\s*\/\s*(\s*\/\s*)+/g, ' / ')
      .replace(/・{2,}/g, '・')
      .replace(/。[・、\s/]+/g, '。')
      .replace(/^[・、\s/]+|[・、\s/]+$/g, '')
      .replace(/。。/g, '。');
    return { text: t, hit: true };
  };

  // ---------- 反応：効き目の向き × 口調 × 3通り ----------
  YA.REACT = {
    good: {
      元気: ['はいっ！　やってみます！', 'ありがとうございます！　元気出ました！', 'よーし、やるぞ！'],
      クール: ['……悪くないですね', '分かりました。やります', 'その言葉、覚えておきます'],
      丁寧: ['ありがとうございます。励みになります', 'お言葉、胸に刻みます', 'はい。期待に応えられるよう努めます'],
      ぶっきらぼう: ['……うす', 'まあ、やるっす', '……ども'],
      おっとり: ['えへへ、うれしいです', 'なんだか、がんばれそうです', 'ありがとうございます〜。ほっとしました'],
      熱血: ['燃えてきました！', 'やってやります！　見ててください！', '絶対に結果で返します！'],
      弱気: ['あの……ありがとうございます。少し、楽になりました', '……がんばってみます', 'そう言ってもらえると、ほっとします'],
      生意気: ['まあ、当然っすね', 'やっと分かってくれました？', '見ててください。期待以上にやるんで'],
      無口: ['……はい', '……ん。やります', '……どうも'],
      お調子者: ['マジっすか！　やる気出ました！', 'へへっ、任せてください！', 'よっしゃ、乗ってきたっす！'],
    },
    mid: {
      元気: ['はい！　考えてみます！', '分かりました！', 'とりあえず、やってみます！'],
      クール: ['……そうですか', '分かりました', '考えておきます'],
      丁寧: ['承知しました', 'はい、分かりました', '少し、考えてみます'],
      ぶっきらぼう: ['……ふーん', 'あっそ', '……分かった'],
      おっとり: ['そうですねえ……', 'はーい。ゆっくり考えます', 'うーん、なるほどです'],
      熱血: ['……分かりました。やるだけです', 'はい！　次に向けてやります', 'とにかく走ります！'],
      弱気: ['……はい', 'あの……分かりました', '……やってみます'],
      生意気: ['はいはい', 'ま、いいっすけど', '……一応、聞いときます'],
      無口: ['……', '……ん', '……分かった'],
      お調子者: ['りょーかいっす！', 'まあ、なんとかなるっす！', 'ういっす！'],
    },
    bad: {
      元気: ['……はい。すみません', 'う……はい……', '……分かり、ました'],
      クール: ['……納得はしていません', '……そういうことですか', '……もういいです'],
      丁寧: ['……申し訳ありません', '……失礼します', '……はい。気をつけます'],
      ぶっきらぼう: ['……ちっ', '……知らねえよ', '……別に'],
      おっとり: ['……そうですか', 'うう……', '……ちょっと、へこみました'],
      熱血: ['……くそっ', '……納得いきません！', '……悔しいです'],
      弱気: ['……すみません、すみません', '……やっぱり、自分なんか', 'あの……ごめんなさい'],
      生意気: ['……はあ？', '……意味わかんないっす', 'そっちの見る目がないんすよ'],
      無口: ['…………', '……いえ', '……もう、いい'],
      お調子者: ['……えー、それはないっすよ', 'あ、あはは……', 'うわ、へこむっす……'],
    },
  };
  // 向き：react の点（自信 c・調子 f）から
  YA.reactDir = (res) => { const s = (res.c || 0) + (res.f || 0) * 4; return s >= 4 ? 'good' : s <= -3 ? 'bad' : 'mid'; };
  // 直近に出した台詞は避ける（w.reactH）
  function pickAvoid(w, list, salt, histKey, keep) {
    if (!list || !list.length) return '';
    const H = w ? (w[histKey] = w[histKey] || []) : [];
    const start = hash(salt) % list.length;
    // まだ使っていないものを先に。全部使っていれば、いちばん前に使ったもの
    let pick = null, old = Infinity;
    for (let i = 0; i < list.length; i++) {
      const c = list[(start + i) % list.length];
      const at = H.lastIndexOf(c);
      if (at < 0) { pick = c; break; }
      if (at < old) { old = at; pick = c; }
    }
    if (w) { H.push(pick); if (H.length > (keep || 12)) H.splice(0, H.length - (keep || 12)); }
    return pick;
  }
  YA.reactSay = function (w, p, dir) {
    const list = (YA.REACT[dir] || YA.REACT.mid)[toneOf(p)] || YA.REACT.mid.丁寧;
    return pickAvoid(w, list, String(p.id) + dir + (w ? (w.year || 0) * 100 + (w.week || 0) : 0) + ((p.hist || []).length), 'reactH', 12);
  };
  // 決まった台詞を本人の口調に（無口の「……」は重ねない）
  const V = (p, s) => (toneOf(p) === '無口' && /^…/.test(s) ? s : YA.voice ? YA.voice(p, s) : s);
  // 出来事・面談の反応の文（world.js の react）：かぎかっこの中を口調に通し、かぎかっこが無ければ口調の一言を添える。
  // 「任せる・見守る」は言葉をかけていないので、様子の文のまま
  YA.toneLine = function (w, p, res, kind) {
    const line = String(res.line || '');
    if (!p) return line;
    if (/「/.test(line)) return line.replace(/「([^」]*)」/g, (m, s) => `「${V(p, s)}」`);
    if (kind === 'wait' || !w) return line;
    return `${line}。「${YA.reactSay(w, p, YA.reactDir(res))}」`;
  };
  // 選んだあとの本人の変化から向きを決める（数字は見せない）
  const snapP = (p) => ({ c: p.conf || 0, t: p.tr == null ? 50 : p.tr, u: p.unrest || 0, f: p.form || 0 });
  const dirOfSnap = (a, b) => { const s = (b.c - a.c) + (b.t - a.t) * 0.8 - (b.u - a.u) * 3 + (b.f - a.f) * 3; return s >= 3 ? 'good' : s <= -3 ? 'bad' : 'mid'; };
  const TEAM_REACT = { good: ['選手たちの顔が明るくなった', 'グラウンドに声が戻った', '子どもたちの表情が引き締まった'], bad: ['少し空気が重くなった', '何人かがうつむいていた', '選手たちは黙りこんでいた'] };

  // 出来事の結果（全部の包みの外側。finish.js は最後に読む）
  const res0 = YA.resolveEvent;
  YA.resolveEvent = function (w, e, idx) {
    const p = e && e.pid ? w.players[e.pid] : null;
    const b = p ? snapP(p) : null;
    const ps = Object.values(w.players || {});
    const c0 = ps.reduce((s, q) => s + (q.conf || 0), 0) / Math.max(1, ps.length);
    const r = res0.apply(this, arguments);
    if (!r || typeof r !== 'object') return r;
    const cut = YA.fxStrip(r.small || '');
    r.small = cut.text || '';
    if (r.line) r.line = YA.fxStrip(r.line).text;
    if (!cut.hit || (e && e.id === 'kizuki') || r.toned || r.leave) return r;
    if (p && w.players[p.id]) {
      // その子の反応：かぎかっこが無い文にだけ、口調の一言を添える（続き物など、もう本人が話している文には足さない）
      if (!/「/.test(r.line || '')) {
        const d = dirOfSnap(b, snapP(p));
        const say = YA.reactSay(w, p, d);
        r.line = (r.line ? r.line.replace(/[。\s]*$/, '。') : `${sur(p)}は、少し考えてから答えた。`) + `「${say}」`;
      }
    } else if (!p && !r.line) {
      const ps2 = Object.values(w.players || {});
      const c1 = ps2.reduce((s, q) => s + (q.conf || 0), 0) / Math.max(1, ps2.length);
      const d = c1 - c0 >= 0.5 ? 'good' : c1 - c0 <= -0.5 ? 'bad' : null;
      if (d) r.line = TEAM_REACT[d][hash((w.year || 0) * 100 + (w.week || 0) + (e && e.id)) % 3] + '。';
    }
    return r;
  };
  // 働きかけ（課題中の子と過ごす・チームへの働きかけ）の結果の文も、数字を外す
  for (const k of ['starAct', 'teamAct']) {
    const f0 = YA[k];
    if (typeof f0 !== 'function') continue;
    YA[k] = function () { const r = f0.apply(this, arguments); if (r && r.msg) r.msg = YA.fxStrip(r.msg).text; return r; };
  }

  // ---------- 大事なお知らせに一言 ----------
  // kind：re（本文）・who（self＝本人／coach＝コーチ／both）・tier（その段より大事なものだけ）。本人の言葉は口調に通す
  const NOTE_SAY = [
    { k: 'awake', re: /気づいた――課題「/, who: 'both',
      self: ['見えたんです。ずっと探していたものが', 'やっと、分かった気がします', '自分でも、まだ信じられません', 'ここからです。もっと上に行きます'],
      coach: ['あいつ、顔つきが変わりましたね', '見ていましたか。別人ですよ', '長かったですね。でも、待った甲斐がありました', 'ああいう瞬間があるから、この仕事はやめられません'] },
    { k: 'clue', re: /正しい手を選べたが、何かが違うようだ/, who: 'both',
      self: ['できたのに、なんか違うんです', 'うまく言えないけど、しっくりこなくて'],
      coach: ['形にはなりました。でも、あいつの本当の道は別にある気がします', '課題の中身、もう一度考えてみませんか', '惜しいところまで来ています'] },
    { k: 'giveup', re: /課題「[^」]+」をあきらめた/, who: 'coach',
      coach: ['無理をさせすぎたかもしれません', '本人の言葉、覚えておきましょう。次の手がかりです', '今はそっとしておきましょう', '外れたなら、次を探すだけです'] },
    { k: 'kend', re: /課題「[^」]+」(が終わった|の期間が終わった)/, who: 'coach',
      coach: ['次の一手を、一緒に考えましょう', '無駄にはなっていません。土台は残ります', '時間をおいて、もう一度見てみましょう'] },
    { k: 'injury', re: /怪我。全治|怪我が再発/, who: 'both', tier: 1,
      self: ['すみません……すぐ戻ります', '悔しいです。でも、焦らず治します', 'こんな時に……', '早く、ボールを蹴りたいです'],
      coach: ['しっかり治させましょう。焦りは禁物です', 'リハビリの組み方は、こちらで考えます', '戻ってきたときのために、席は空けておきます', '心のほうも、見ておきます'], staff: 'トレーナー' },
    { k: 'leave', re: /チームを去った/, who: 'coach',
      coach: ['寂しくなりますね', 'あいつの決めたことです。背中を押してやりましょう', 'どこへ行っても、うちの子です'] },
    { k: 'first', re: /Aの公式戦で初ゴール/, who: 'both',
      self: ['入った瞬間、頭が真っ白になりました', '練習してきた形でした', 'この1点、一生忘れません', 'やっと、決められました'],
      coach: ['ずっと狙っていましたからね', 'あの一本で、顔つきが変わりました', '次は2点目ですね'] },
    { k: 'gold', re: /金の特性「/, who: 'both',
      self: ['体が勝手に動くんです', '何百回も繰り返してきましたから'],
      coach: ['あれはもう、あいつだけの武器です', '積み重ねが形になりましたね'] },
    { k: 'pact', re: /約束の目標に届いた/, who: 'self',
      self: ['約束、守りました', '言ったからには、やらないと', '見ていてくれて、ありがとうございます'] },
    { k: 'red', re: /が退場。次の試合は出場停止/, who: 'both',
      self: ['……チームに迷惑をかけました', '頭に血が上りました。すみません'],
      coach: ['次の試合で取り返させましょう', '熱くなるのは悪くない。使いどころです'] },
    { k: 'nat', re: /日本代表に初めて選ばれ|U-21日本代表/, who: 'coach',
      coach: ['ユースの頃を思い出しますね', 'あいつなら、やってくれますよ', 'うちから代表か……。うれしいですね'] },
  ];
  YA.NOTE_SAY = NOTE_SAY;
  const coachOf = (w, role) => {
    const st = (w.club && w.club.staff) || [];
    const s = st.find((x) => x.role === role) || st.find((x) => /戦術コーチ|技術コーチ/.test(x.role)) || null;
    if (!s) return 'コーチ';
    const n = String(s.name).split(' ')[0];
    return s.role === 'トレーナー' ? `トレーナーの${n}` : `${n}コーチ`;
  };
  YA.noteSay = function (w, tier, text, pid) {
    const d = NOTE_SAY.find((x) => x.re.test(text));
    if (!d || (d.tier && tier > d.tier)) return null;
    const p = pid && w.players ? w.players[pid] : null;
    let who = d.who === 'both' ? (p && hash(text + (w.inboxN || 0)) % 2 === 0 ? 'self' : 'coach') : d.who;
    if (who === 'self' && !p) who = d.coach ? 'coach' : null;
    if (!who) return null;
    const line = pickAvoid(w, d[who], text + (w.year || 0) * 100 + (w.week || 0), 'noteSayH', 14);
    return who === 'self' ? `${sur(p)}「${V(p, line)}」` : `${coachOf(w, d.staff)}「${line}」`;
  };

  // 初ゴール（A の公式戦）もお知らせに（records.js の名場面 'first' が付いたとき）
  const am0 = YA.applyMatch;
  if (am0) YA.applyMatch = function (w, m, which) {
    const had = new Set();
    if (which === 'A') for (const p of Object.values(w.players || {})) if ((p.scenes || []).some((x) => x.k === 'first')) had.add(p.id);
    const res = am0.apply(this, arguments);
    if (which === 'A') for (const p of Object.values(w.players || {})) {
      if (had.has(p.id)) continue;
      const sc = (p.scenes || []).find((x) => x.k === 'first');
      if (sc && sc.y === w.year && sc.w === w.week && YA.noteTier) YA.noteTier(w, 2, `${p.num}番 ${p.name}が${sc.t}`, p.id);
    }
    return res;
  };

  // ---------- 演出 ----------
  // 課題を出したとき・あきらめたときの一言（口調ごと）
  const GIVE_SAY = {
    元気: ['はい！　やってみます！', '任せてください！　全力でやります！'], クール: ['……分かりました。やってみます', '意味があるなら、やります'],
    丁寧: ['承知しました。精一杯取り組みます', 'ありがとうございます。必ず形にします'], ぶっきらぼう: ['……うす。やるっす', '……まあ、やってみる'],
    おっとり: ['えっと、がんばってみます', 'ゆっくりでも、ものにします'], 熱血: ['燃えてきました！　絶対にものにします！', 'やらせてください！'],
    弱気: ['自分に、できるでしょうか……。でも、やってみます', 'あの……がんばります'], 生意気: ['へえ。面白いじゃないっすか', 'すぐ結果出してみせますよ'],
    無口: ['……はい', '……やります'], お調子者: ['おっ、いいっすね！　やるっす！', '任せてくださいって！'],
  };
  const GIVEUP_SAY = {
    元気: ['すみません……。今の自分には、無理でした', '……ごめんなさい。続けられませんでした'], クール: ['……これ以上は、意味がないと思います', '……すみません。降ります'],
    丁寧: ['申し訳ありません。期待に応えられませんでした', '……力不足でした。すみません'], ぶっきらぼう: ['……もう、無理っす', '……やめる'],
    おっとり: ['ごめんなさい……ちょっと、つかれちゃいました', '……うまく、できなかったです'], 熱血: ['……悔しいです。でも、もう気持ちが続きません', 'くそっ……すみません！'],
    弱気: ['やっぱり、自分には無理でした……', '……ごめんなさい、ごめんなさい'], 生意気: ['……これ、俺に合ってないっすよ', '向いてないもんは、向いてないんで'],
    無口: ['……すみません', '……無理です'], お調子者: ['いやー……さすがに、きついっす', 'あはは……今回は、ダメでした'],
  };
  const AWAKE_SAY = {
    元気: ['見えました！　ずっと探してたものが！', 'なんか、全部つながった気がします！'], クール: ['……ようやく、見えました', 'これが、自分のサッカーです'],
    丁寧: ['ご指導のおかげです。やっと、分かりました', '見える景色が、変わりました'], ぶっきらぼう: ['……分かった。こういうことか', '……やっと、つかんだ'],
    おっとり: ['あ……なんだか、すっと分かりました', 'ふしぎです。体が勝手に動きました'], 熱血: ['これだ！　これなんです！', 'もう止まりません！　見ててください！'],
    弱気: ['あの……自分でも、できたんです', '……信じられないです。でも、見えました'], 生意気: ['ほら、言ったでしょ。これが俺です', 'ここからっすよ。見ててください'],
    無口: ['……見えた', '……ここだ'], お調子者: ['え、今の俺っすか！？　やばいっす！', 'きたきたきた！　覚醒っすよ！'],
  };
  YA.GIVE_SAY = GIVE_SAY; YA.GIVEUP_SAY = GIVEUP_SAY; YA.AWAKE_SAY = AWAKE_SAY;
  YA.fxSay = (w, p, table) => pickAvoid(w, table[toneOf(p)] || table.丁寧, String(p.id) + (w ? (w.year || 0) * 100 + (w.week || 0) : 0), 'reactH', 12);

  const H = () => (YA._ui && YA._ui.h) || null;
  const sfx = (k) => { try { if (YA.sfx) YA.sfx.play(k); } catch (er) { /* 音が出せない環境 */ } };
  const mount = (el) => { (document.body || document.documentElement).append(el); return el; };
  // 覚醒：画面いっぱい。1回目のタップは途中でも全部を出し、もう一度タップで閉じる（数秒で全部出る）
  YA.AWAKE_ALL_MS = 2900;
  YA.awakeShow = function (w, p, onDone) {
    const h = H();
    if (!h || typeof document === 'undefined' || document.querySelector('.fxov.awk')) return null;
    const aw = p.aw || {};
    const say = YA.fxSay(w, p, AWAKE_SAY);
    // 出る順（秒）：覚醒 → 形の名前 → 覚醒の特性 → 本人の一言 → 「タップで続ける」
    const at = (s) => `animation-delay:${s}s`;
    const root = h('div', { class: 'fxov awk', role: 'dialog', 'aria-label': '覚醒' },
      h('div', { class: 'awk-in' },
        h('div', { class: 'awk-big', style: at(0.15) }, '覚醒'),
        h('div', { class: 'awk-form', style: at(0.85) }, aw.form || (p.awake && p.awake.form) || ''),
        h('div', { class: 'awk-trait', style: at(1.45) }, h('small', {}, '覚醒の特性'), h('b', {}, `「${aw.trait || (p.awake && p.awake.trait) || ''}」`)),
        h('div', { class: 'awk-say', style: at(2.05) }, YA.faceEl ? YA.faceEl(w, p, 60) : null, h('div', {}, h('b', {}, `${p.name}（高${p.grade}）`), h('span', {}, `「${say}」`))),
        h('div', { class: 'awk-tap', style: at(2.7) }, 'タップで続ける')));
    let all = false;
    const showAll = () => { all = true; root.classList.add('all'); };
    const tm = setTimeout(showAll, YA.AWAKE_ALL_MS);
    root.addEventListener('click', () => {
      if (!all) return showAll();
      clearTimeout(tm);
      root.remove();
      if (onDone) onDone();
    });
    sfx('awake');
    return mount(root);
  };
  // 気づきの「見えた。」：画面が一瞬白く光る
  YA.kzFlash = function () {
    sfx('kizuki');
    if (typeof document === 'undefined') return null;
    const el = document.createElement('div');
    el.className = 'fxflash';
    setTimeout(() => el.remove(), 900);
    return mount(el);
  };
  // 課題を出したとき・あきらめたときの短い場面（数秒で閉じる・タップでも閉じる）
  YA.FX_SCENE_MS = 4200;
  YA.fxScene = function (w, s, onDone) {
    const h = H();
    const p = s && w.players ? w.players[s.pid] : null;
    if (!h || !p || typeof document === 'undefined' || document.querySelector('.fxov.kzs')) return null;
    const give = s.k === 'give';
    const say = YA.fxSay(w, p, give ? GIVE_SAY : GIVEUP_SAY);
    const root = h('div', { class: 'fxov kzs ' + (give ? 'give' : 'gaveup'), role: 'dialog' },
      h('div', { class: 'kzs-in' },
        YA.faceEl ? YA.faceEl(w, p, 84) : null,
        h('div', { class: 'kzs-tx' },
          h('small', {}, give ? '課題を出した' : '課題をあきらめた'),
          h('b', {}, `${p.name}　課題「${s.nm || ''}」`),
          h('div', { class: 'kzs-say' }, `「${say}」`),
          !give && s.t ? h('div', { class: 'kzs-note' }, `打ち明けた言葉：「${s.t}」`) : null,
          h('div', { class: 'kzs-tap' }, 'タップで閉じる'))));
    let done = false;
    const close = () => { if (done) return; done = true; clearTimeout(tm); root.remove(); if (onDone) onDone(); };
    const tm = setTimeout(close, YA.FX_SCENE_MS);
    root.addEventListener('click', close);
    if (!give) sfx('giveup');
    return mount(root);
  };
  // 週の中で起きた場面（あきらめ）を積む。ホームを開いたときに1つずつ見せる
  YA.fxPush = function (w, s) {
    w.fxQ = (w.fxQ || []).concat([Object.assign({ y: w.year, wk: w.week }, s)]).slice(-3);
  };
  YA.fxScenePlay = function (w) {
    if (typeof document === 'undefined' || document.querySelector('.fxov.kzs')) return;
    while (w.fxQ && w.fxQ.length) {
      const s = w.fxQ.shift();
      if (!s || !w.players[s.pid] || (w.year * 100 + w.week) - (s.y * 100 + s.wk) > 2) continue; // 古いものは見せない
      YA.fxScene(w, s, () => { if (w.fxQ && w.fxQ.length) YA.fxScenePlay(w); });
      return;
    }
  };
  // おまかせ進行では演出を出さない（止めない）：おまかせのあいだに積んだ場面は捨て、覚醒の窓は演出なしで出す
  const sim0 = YA.simulate;
  if (sim0) YA.simulate = function (w) {
    const n0 = (w.fxQ || []).length;
    const r = sim0.apply(this, arguments);
    if (w.fxQ) w.fxQ = w.fxQ.slice(0, n0);
    for (const e of (w.events || []).concat(w.forced || [], w.kzNow || [])) if (e && e.id === 'awake') e._fx = 1;
    return r;
  };
})();
