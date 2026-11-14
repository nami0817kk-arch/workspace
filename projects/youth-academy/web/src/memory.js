// 記憶（決定153〜155）：★の子との大事な場面で何を選んだかを、その子ごとに残す（p.mem）。
// 残した記憶は、あとの場面が引用する：年度末・卒業式の言葉、卒業後の便り、殿堂入りの言葉。
// 選び方は覚醒の形の出やすさ（育て方の傾き）と、卒業後の絆（a.bond）に効く。
// 絆の深い卒業生は「人」として返ってくる：引退後にコーチとして戻る・中学生を紹介する・次の人生へ付いてくる。
(function () {
  'use strict';
  const YA = (globalThis.YA = globalThis.YA || {});
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const sur = (n) => String(n).split(' ')[0];

  // ---------- 記憶を残す ----------
  YA.MEM_NAME = { scout: 'スカウトの見立て', star: '★を付けた日', debut: '初めての出場', wall: '壁', hint: '鍵が見えた', term: '年度末', grad: '卒業式', awake: '覚醒', path: '進路面談', ref: '紹介で来た',
    unrest: '出番の不満', lowconf: '自信をなくした', injury: '怪我', quit: '辞めたいと言った', hot: '絶好調', rival: '張り合い', rivalry: '先発争い', family: '家庭の事情', homesick: 'ホームシック', parent: '保護者の相談', tired: '疲れ' };
  const MEM_EVENTS = new Set(['unrest', 'lowconf', 'injury', 'quit', 'hot', 'rival', 'rivalry', 'family', 'homesick', 'parent', 'tired']);
  const quoteOf = (label) => {
    const m = /「([^」]+)」/.exec(label || '');
    return m ? m[1] : String(label || '').replace(/【[^】]*】/g, '').replace(/（[^）]*）/g, '').trim();
  };
  YA.memAdd = function (w, p, k, c, q, extra) {
    if (!p) return;
    p.mem = p.mem || [];
    p.mem.push(Object.assign({ y: w.year, w: w.week, g: p.grade, k, c: c || null, q: q || '' }, extra || {}));
    if (p.mem.length > 30) p.mem.splice(1, 1); // いちばん古い1件（出会い）は残す
  };
  YA.memOf = (p, k, c) => (p.mem || []).filter((m) => m.k === k && (c == null || m.c === c));
  YA.memLines = (p) => (p.mem || []).slice().reverse().map((m) => `${m.y}年目${m.g ? ' 高' + m.g : ''}：${YA.MEM_NAME[m.k] || m.k}${m.c && YA.KIND_LABEL && YA.KIND_LABEL[m.c] ? '（' + YA.KIND_LABEL[m.c] + '）' : ''}${m.q ? '「' + m.q + '」' : ''}`);

  const res0 = YA.resolveEvent;
  YA.resolveEvent = function (w, e, idx) {
    const p = e.pid ? w.players[e.pid] : null;
    const out = res0.apply(this, arguments);
    if (!p || !(p.star || p.mem)) return out;
    const def = YA.EVENTS.find((x) => x.id === e.id);
    const o = def && def.opts && def.opts[idx];
    if (!o) return out;
    if (e.id === 'ms') YA.memAdd(w, p, e.ms, o.kind, quoteOf(o.label));
    else if (e.id === 'path') YA.memAdd(w, p, 'path', o.k, quoteOf(o.label), { wish: p.wish || YA.wishOf(p) });
    else if (MEM_EVENTS.has(e.id)) YA.memAdd(w, p, e.id, o.kind, quoteOf(o.label));
    return out;
  };
  const aw0 = YA.awaken;
  YA.awaken = function (w, p) {
    const r = aw0.apply(this, arguments);
    YA.memAdd(w, p, 'awake', null, (p.aw && p.aw.form) || '');
    return r;
  };
  // ★を付けたとき、スカウトの見立てがあれば出会いとして残す
  const ss0 = YA.setStar;
  YA.setStar = function (w, p, on) {
    const r = ss0.apply(this, arguments);
    if (r && r.ok !== false && on && p.star && !YA.memOf(p, 'scout').length && p.scoutNote && p.scoutNote.hunch) {
      p.mem = p.mem || [];
      p.mem.unshift({ y: w.year, w: w.week, g: p.grade, k: 'scout', c: null, q: p.scoutNote.hunch.text, ok: p.scoutNote.hunch.true });
    }
    return r;
  };

  // ---------- 育て方の傾き：接し方で、覚醒の形の出やすさが変わる ----------
  YA.FORM_LEAN = {
    firm: ['fighter', 'ice', 'leader', 'wall', 'hunter'],
    push: ['scorer', 'cannon', 'flash', 'conductor', 'sky', 'post'],
    warm: ['fantasista', 'magic', 'reader', 'engine', 'wing', 'crosser'],
    wait: ['setpiece', 'sweeperk', 'keeper', 'reader', 'ice', 'conductor'],
  };
  YA.leanOf = function (p) {
    const cnt = { warm: 0, push: 0, firm: 0, wait: 0 };
    let n = 0;
    for (const m of p.mem || []) if (cnt[m.c] != null) { cnt[m.c]++; n++; }
    return { cnt, n };
  };
  // 形の重みに掛ける倍率（1〜3倍）。記憶が無ければ1
  YA.formLean = function (p, f) {
    const { cnt, n } = YA.leanOf(p);
    if (!n) return 1;
    let s = 0;
    for (const k of Object.keys(YA.FORM_LEAN)) if (YA.FORM_LEAN[k].includes(f.k)) s += cnt[k] / n;
    return 1 + 2 * s;
  };
  YA.leanWord = (k) => (YA.KIND_LABEL ? YA.KIND_LABEL[k] : k);

  // ---------- 本人の希望（進路）----------
  YA.WISH_WORD = { abroad: '海外', pro: 'プロ', univ: '大学', corp: '社会人', quit: '別の道' };
  YA.wishOf = function (p) {
    if (p.wish) return p.wish;
    const v = Object.values(p.pers || {});
    const has = (...n) => n.some((x) => v.indexOf(x) >= 0);
    if (has('野心家', '自信家', '反骨心', '負けず嫌い')) return YA.ovr(p) >= 12.5 ? 'abroad' : 'pro';
    if (has('家族思い')) return 'corp';
    if (has('勉強家', '慎重', '真面目')) return 'univ';
    return 'pro';
  };
  const ev0 = YA.eventView;
  YA.eventView = function (w, e) {
    const v = ev0.apply(this, arguments);
    if (!v) return v;
    const p = e.pid ? w.players[e.pid] : null;
    if (e.id === 'path' && p) {
      p.wish = YA.wishOf(p);
      v.text += ` 本人の希望は「${YA.WISH_WORD[p.wish]}」。希望に沿えば信頼が深まり、沿わなければ信頼が下がります（コーチのおすすめに沿うと、大学なら遅咲きの目があります）。`;
    }
    if (e.id === 'ms' && p && (e.ms === 'grad' || e.ms === 'term')) {
      const tail = (/（信頼 [^）]*）$/.exec(v.text) || [''])[0];
      const line = e.ms === 'grad' ? YA.recall(w, p, 'grad') : YA.recall(w, p, 'term');
      if (line) v.text = line + tail;
    }
    return v;
  };
  // 進路：希望に沿ったか（記録は上の resolveEvent が残す）
  const res1 = YA.resolveEvent;
  YA.resolveEvent = function (w, e, idx) {
    const p = e.id === 'path' && e.pid ? w.players[e.pid] : null;
    const k = p ? (YA.pathOptions(p)[idx] || {}).k : null;
    const out = res1.apply(this, arguments);
    if (p && k) {
      const wish = YA.wishOf(p);
      if (k === wish) YA.addTr(w, p, 3, '進路：希望を聞いてもらえた');
      else YA.addTr(w, p, -3, `進路：本当は${YA.WISH_WORD[wish]}に行きたかった`);
    }
    return out;
  };

  // ---------- 引用：本人の言葉（丁寧／くだけた の2通り）----------
  const CASUAL = new Set(['元気', '熱血', 'お調子者', '生意気', 'ぶっきらぼう']);
  const reg = (p) => (YA.toneOf && CASUAL.has(YA.toneOf(p)) ? 1 : 0);
  // [丁寧, くだけた]。x: { awake, form, hi(信頼4以上), m(記憶) }
  const SAY_MEM = {
    'star:push': (x) => (x.awake
      ? [`「三年間で、必ず化けさせる」――あの日の約束、本当に守ってもらいました。`, `「必ず化けさせる」って、あれマジだったんすね。……ほんとに、そうなりました。`]
      : [`「必ず化けさせる」と言ってもらったのに、届きませんでした。すみません。`, `化けさせるって言ってくれたのに、俺が届かなかったっす。……すんません。`]),
    'star:warm': () => [`「焦らず、一緒にやっていこう」と言ってもらえたから、最後まで焦らずにいられました。`, `焦んなくていいって言われたの、けっこう効いてたんすよ。`],
    'star:firm': (x) => (x.awake
      ? [`「結果で見せろ」と言われて、ずっと悔しかったんです。見せられましたか。`, `「結果で見せろ」って言われたの、ずっと根に持ってました。見せたっすよね？`]
      : [`「結果で見せろ」と言われたのに、見せきれませんでした。`, `結果で見せろって言われたのに、見せきれなかったっす。`]),
    'wall:warm': () => [`伸び悩んでいたとき、信じて待ってもらえたから、やめずに済みました。`, `伸び悩んでたとき、待っててくれたじゃないすか。あれがなかったら、やめてました。`],
    'wall:push': () => [`壁にぶつかったとき、一緒に練習を組み直してもらったこと、忘れません。`, `壁のとき、一緒に練習を組み直してくれたの、忘れないっす。`],
    'wall:firm': (x) => (x.hi
      ? [`壁のとき「誰でも通る道だ」と突き放されて、腹が立ちました。でも、あれで目が覚めました。`, `壁のとき突き放されて、正直ムカつきました。でも、あれで目ぇ覚めたっす。`]
      : [`壁のとき厳しくされたのは、正直、つらかったです。`, `壁のとき、厳しくされたのはキツかったっす。`]),
    'awake': (x) => [`「${x.form}」――あの日から、見える景色が変わりました。`, `あの日（${x.form}）から、世界が変わったっす。`],
    'quit:warm': () => [`辞めようとしたとき、本気で引き止めてもらったから、今日ここにいます。`, `辞めるって言ったとき、本気で止めてくれたから、今ここにいるんすよ。`],
    'quit:push': () => [`辞めようとしたとき、もう一度チャンスをもらえました。あれが全部でした。`, `辞めるって言ったとき、チャンスくれたっすよね。あれがデカかった。`],
    'injury:warm': () => [`怪我のとき、無理をさせないでもらえたから、今も体が動きます。`, `怪我のとき無理させないでくれて、助かりました。`],
    'injury:push': () => [`怪我を押して出たあの試合、今でも覚えています。`, `怪我押して出たあの試合、今でも覚えてるっす。`],
    'lowconf:warm': () => [`自信をなくしていたとき、話を聞いてもらえて救われました。`, `自信なくしてたとき、話聞いてくれたの、救われたっす。`],
    'lowconf:push': () => [`自信をなくしていたとき、できていることを示してもらえて、前を向けました。`, `自信なくしてたとき、できてるとこ言ってくれたっすよね。あれで前向けた。`],
    'debut:warm': () => [`初めてAに出た日、肩をたたいてもらったのがうれしくて。`, `初めてAに出た日、肩たたいてくれたの、うれしかったっす。`],
    'debut:push': () => [`「ここからが本番だ」と言われた初出場の日を、まだ覚えています。`, `「ここからが本番だ」って言われた初出場、まだ覚えてるっす。`],
    'debut:firm': () => [`初出場のあとに課題を言われたのが悔しくて、ずっとノートに書いていました。`, `初出場のあと課題言われて、悔しくてずっとメモってました。`],
    'unrest:warm': () => [`出番がなくて腐りかけたとき、約束してもらえたのがうれしかったです。`, `出番なくて腐ってたとき、約束してくれたっすよね。`],
    'hot:push': () => [`調子のいいときに、もっと上を求めてもらえたのが良かったです。`, `調子いいときに「もっと上」って言ってくれたの、良かったっす。`],
    'scout': (x) => [`スカウトの人が「${x.m.q}」と言っていたって、あとで聞きました。`, `スカウトの人に「${x.m.q}」って言われてたらしいっすね。`],
    'ref': (x) => [`${x.m.q}さんの紹介でここに来て、本当によかったです。`, `${x.m.q}さんに紹介してもらって、マジでよかったっす。`],
  };
  const PRI = ['star:push', 'wall', 'quit', 'awake', 'star', 'injury', 'lowconf', 'debut', 'unrest', 'hot', 'ref', 'scout'];
  // その子を形づくった記憶を1つ（約束を最優先。次に壁・辞めかけ・覚醒…）
  YA.definingMem = function (p) {
    const mem = p.mem || [];
    for (const key of PRI) {
      const [k, c] = key.split(':');
      const hit = mem.filter((m) => m.k === k && (!c || m.c === c)).find((m) => SAY_MEM[m.k + ':' + m.c] || SAY_MEM[m.k]);
      if (hit) return hit;
    }
    return null;
  };
  const sayMem = (p, m) => {
    const f = SAY_MEM[m.k + ':' + m.c] || SAY_MEM[m.k];
    if (!f) return null;
    const x = { awake: (p.awDone || 0) > 0, form: (p.aw && p.aw.form) || '', hi: YA.trustLv(p) >= 4, m };
    let s = f(x)[reg(p)];
    if (YA.toneOf && YA.toneOf(p) === '無口') s = '……' + s;
    return s;
  };
  YA.recallMem = sayMem;
  YA.recall = function (w, p, scene) {
    const sn = sur(p.name);
    if (scene === 'grad') {
      const m = YA.definingMem(p);
      if (!m) return null;
      const promise = YA.memOf(p, 'star', 'push').length > 0;
      const broken = promise && !(p.awDone > 0);
      const head = broken ? `卒業式の朝、${sn}がうつむいたまま来た。` : `卒業式の朝、${sn}が来た。`;
      return `${head}「${sayMem(p, m)}${YA.trustLv(p) >= 4 ? reg(p) ? '　……三年間、あざっした。' : '　三年間、ありがとうございました。' : ''}」`;
    }
    // 年度末：この一年の記憶から
    const ys = (p.mem || []).filter((m) => m.y === w.year && m.k !== 'term' && m.k !== 'scout');
    const g = p.o0 == null ? '' : (() => { const a = YA.rate(p.o0), b = YA.rate(YA.ovr(p)); return b > a ? `総合力は${a}から${b}へ伸びた。` : `総合力は${b}のまま、土台を固めた。`; })();
    if (!ys.length) return `${sn}と、この一年を振り返った。${g}「来年は、もっと話しに来ます」`;
    const m = ys[ys.length - 1];
    const s = sayMem(p, m);
    return `${sn}と、この一年を振り返った。${g}${s ? `「${s}」` : `${YA.MEM_NAME[m.k] || ''}のことを、本人もよく覚えていた。`}`;
  };
  // 卒業式の場面の挨拶：★の子は記憶から
  const say0 = YA.say;
  YA.say = function (w, p, scene) {
    if (scene === 'thanks' && p && p.star && p.mem) {
      const m = YA.definingMem(p);
      const s = m && sayMem(p, m);
      if (s) return s;
    }
    return say0.apply(this, arguments);
  };

  // ---------- 卒業：記憶と絆を持って出ていく ----------
  YA.bondOf = function (p) {
    const promise = YA.memOf(p, 'star', 'push').length > 0;
    const pathM = YA.memOf(p, 'path')[0];
    let b = YA.trustLv(p);
    if (promise) b += p.awDone > 0 ? 1 : -2;
    if (pathM && pathM.c === pathM.wish) b += 1;
    return clamp(b, 0, 6);
  };
  const ae0 = YA.alumniEntry;
  YA.alumniEntry = function (w, p) {
    const a = ae0.apply(this, arguments);
    if (p.mem && p.mem.length) {
      a.mem = p.mem.slice();
      a.bond = YA.bondOf(p);
      a.form = (p.aw && p.aw.form) || null;
      a.tone = YA.toneOf ? YA.toneOf(p) : null;
    }
    return a;
  };

  // ---------- 便り：その年に起きたことと、記憶から書く（数字の一行をやめる）----------
  const HEAD_RE = /^卒業生の(.+)★（(\d+)年目卒）：/;
  YA.letterOf = function (w, a) {
    const ss = a.seasons || [];
    const s = ss[ss.length - 1];
    const prev = ss[ss.length - 2];
    const parts = [];
    const first = !prev;
    const pm = (a.mem || []).find((m) => m.k === 'path');
    if (first) {
      if (pm && pm.c === pm.wish) parts.push(`希望どおりの道に進ませてもらって、${a.club}で一年目を終えました。`);
      else if (pm) parts.push(`正直、面談のあとは迷いました。でも${a.club}で一年やって、あのときの話の意味が少し分かった気がします。`);
      else parts.push(`${a.club}での一年目が終わりました。`);
    } else if (s && prev && s.club !== prev.club) parts.push(a.abroad && !(prev.club || '').match(/FC|U-|大学/) ? `${s.club}へ移りました。言葉も食べ物も違いますが、やっています。` : `${s.club}へ移りました。`);
    if (s) {
      if (s.apps === 0) parts.push('今年は試合に出られませんでした。悔しいですが、腐らずにやっています。');
      else if (s.apps >= 25) parts.push(`${s.apps}試合に出${s.goals ? `て、${s.goals}点取りました` : 'ました'}。ほぼ全部の試合に出られました。`);
      else parts.push(`${s.apps}試合に出${s.goals ? `て${s.goals}点` : 'ました'}${s.goals ? 'でした' : ''}。`);
      for (const t of s.titles || []) parts.push(`${t}です！`);
      for (const x of s.awards || []) parts.push(`${x}に選ばれました。`);
    }
    const yrs = w.year - a.year;
    const b = a.bond == null ? 3 : a.bond;
    if (b >= 4 && yrs % 3 === 1) {
      const m = YA.definingMem(a);
      if (m && m.q && m.k !== 'scout' && m.k !== 'ref' && m.k !== 'awake') parts.push(`監督に言われた「${m.q}」は、今も大事にしています。`);
      else if (a.form) parts.push(`あの日の覚醒（${a.form}）が、今も自分の土台です。`);
    }
    if (b <= 1) return parts.slice(0, 1).join('') + '（短い便りだった）';
    if (a.tone === '無口') return parts.slice(0, 2).join('');
    return parts.join('');
  };
  const nt0 = YA.noteTier;
  YA.noteTier = function (w, tier, text, pid) {
    if (w && typeof text === 'string') {
      const m = HEAD_RE.exec(text);
      if (m) {
        const a = (w.alumni || []).find((x) => x.name === m[1] && String(x.year) === m[2]);
        if (a && a.mem) return nt0.call(this, w, tier, `卒業生の${a.name}★（${a.year}年目卒）より：「${YA.letterOf(w, a)}」`, pid);
      }
    }
    return nt0.apply(this, arguments);
  };

  // ---------- 殿堂入りの言葉：恩師（あなた）の側から、その子の記憶で ----------
  const COACH_MEM = {
    'star:push': (a) => (a.form ? '「必ず化けさせる」と約束した子です。約束を守らせてくれたのは、本人でした。' : '「必ず化けさせる」と約束して、守れなかった子です。それでも、ここまで来た。'),
    'star:warm': () => '「焦らず行こう」と言った子が、いちばん遠くまで行きました。',
    'star:firm': () => '「結果で見せろ」と突き放した子が、本当に結果で見せてくれました。',
    'wall:warm': () => '伸び悩んでいたあの冬を、自分の足で越えた子です。',
    'wall:push': () => '壁にぶつかったとき、一緒に練習を組み直した日のことを覚えています。',
    'wall:firm': () => '壁の前で、あえて突き放しました。あの子は怒って、そして越えていった。',
    'quit:warm': () => '一度は辞めると言った子です。引き止めてよかった、と心から思います。',
    'quit:push': () => '辞めかけた子に、もう一度だけ機会を渡しました。それを掴んだのは本人です。',
    'awake': (a) => `あの日、「${a.form || '覚醒'}」の瞬間を間近で見られたのは、指導者の幸運でした。`,
    'injury:warm': () => '怪我のとき、無理をさせなかった。それだけは正しかったと思います。',
    'lowconf:warm': () => '自信をなくして下を向いていた子が、こんなに大きくなりました。',
    'debut:warm': () => '初めての試合のあと、息を弾ませていた顔を覚えています。',
  };
  const hw0 = YA.hofWord;
  YA.hofWord = function (w, a) {
    const m = a && a.mem ? YA.definingMem(a) : null;
    const f = m && (COACH_MEM[m.k + ':' + m.c] || COACH_MEM[m.k]);
    return f ? f(a) : hw0.apply(this, arguments);
  };

  // ---------- 人として返ってくる：OBコーチ・紹介 ----------
  YA.EVENTS.push({ id: 'obret', name: '卒業生が戻ってきた', weight: 0, pick: () => null, text: () => '', opts: [] });
  YA.EVENTS.push({ id: 'ref', name: '卒業生からの紹介', weight: 0, pick: () => null, text: () => '', opts: [] });
  YA.EVENT_ABOUT = YA.EVENT_ABOUT || {};
  YA.EVENT_ABOUT.obret = '現役を終えた★の卒業生が、コーチとして戻りたいと言ってきました。迎えると、その役のコーチと入れ替わり、毎月★の子に自分の経験を話します（鍵のヒントが進む）。';
  YA.EVENT_ABOUT.ref = '★の卒業生が、地元の中学生を紹介してくれました。会いに行くと、スカウトの候補に「よく見えている」状態で入ります。';
  const PHYS_FORMS = new Set(['flash', 'engine', 'sky', 'fighter', 'wing']);
  YA.obRoleOf = function (a) {
    if (a.pos === 'GK') return 'GKコーチ';
    const fk = a.form ? (YA.AWAKE_FORMS.find((f) => f.name === a.form) || {}).k : null;
    if (fk && PHYS_FORMS.has(fk)) return '体コーチ';
    if (a.pos === 'DF' || a.main === 'DM') return '戦術コーチ';
    return '技術コーチ';
  };
  YA.obAbOf = (a) => clamp(Math.round(8 + ((a.ovr || 11) - 11) * 1.3 + (a.bond == null ? 3 : a.bond) * 0.6), 8, 17);
  // 卒業生をコーチに迎える（同じ役のコーチと入れ替わる）
  YA.obJoin = function (w, a, why) {
    const role = YA.obRoleOf(a);
    const ab = YA.obAbOf(a);
    const s = { id: 'ob' + YA.hash(a.name + a.year + w.year), name: a.name, role, ab, salary: Math.round(YA.salaryOf(ab) * 0.7), ob: true, alumniRef: a.name, mentor: true, pos: a.pos, mem: (a.mem || []).slice(-6), bond: a.bond };
    const i = w.club.staff.findIndex((x) => x.role === role);
    const old = i >= 0 ? w.club.staff[i] : null;
    if (i >= 0) w.club.staff[i] = s;
    else w.club.staff.push(s);
    a.coached = true;
    YA.noteTier(w, 1, `${a.name}が${role}になりました${why ? '（' + why + '）' : ''}${old ? `。${old.name}さんとは、ここでお別れです` : ''}`);
    return s;
  };
  function obPrep(w, e) {
    const a = (w.alumni || []).find((x) => x.name === e.who && x.year === e.ay);
    const def = YA.EVENTS.find((x) => x.id === e.id);
    if (!a || !def) return;
    const run = (label, fn) => ({ label, kind: null, run: (ww) => fn(ww) });
    if (e.id === 'obret') {
      const role = YA.obRoleOf(a);
      const cur = w.club.staff.find((x) => x.role === role);
      const m = YA.definingMem(a);
      def.text = () => `${a.year}年目に送り出した${a.name}★が、現役を終えて訪ねてきた。「${m ? YA.recallMem(a, m) + '　' : ''}今度は、自分が教える側をやらせてもらえませんか」（${role}・腕前${YA.obAbOf(a)}／いまの${role}は${cur ? cur.name + '・腕前' + cur.ab : 'いない'}）`;
      def.opts = [
        run(`${role}として迎える`, (ww) => { YA.obJoin(ww, a); return { line: `${sur(a.name)}が、グラウンドに戻ってきた。`, small: `${role}が${a.name}に替わった。毎月、★の子に自分の経験を話す` }; }),
        run('今は枠がないと伝える', (ww) => { a.coached = true; a.bond = Math.max(0, (a.bond || 3) - 1); return { line: '「そうですよね。また顔を出します」と笑って帰っていった。', small: '' }; }),
      ];
    } else {
      def.text = () => `卒業生の${a.name}★（${a.club}）から電話があった。「地元に、ちょっと見てほしい中学生がいるんです。昔の自分みたいな子で」`;
      def.opts = [
        run('会いに行く（スカウトの候補に入る）', (ww) => { const c = YA.refCand(ww, a); return { line: c ? `${c.p.name}（${c.p.pos}）に会った。${sur(a.name)}の言うとおり、目が違った。` : '今回は都合が合わなかった。', small: c ? 'スカウトの候補に入った（よく見えている）' : '' }; }),
        run('今年は見送ると伝える', () => ({ line: '「分かりました。また、いい子がいたら連絡します」', small: '' })),
      ];
    }
  }
  YA.refCand = function (w, a) {
    if (!w.scouting || !YA._genCand) return null;
    const r = YA.rngOf(YA.hash(a.name) + w.year * 7);
    const c = YA._genCand(w, r, 'scout', null);
    c.seen = Math.max(c.seen, 2);
    c.ref = a.name;
    c.p.pot += 25;
    c.p.mem = [{ y: w.year, w: w.week, g: 0, k: 'ref', c: null, q: a.name }];
    a.refDone = (a.refDone || 0) + 1;
    return c;
  };
  for (const id of ['obret', 'ref']) {
    const v0 = YA.eventView;
    YA.eventView = function (w, e) { if (e.id === id) obPrep(w, e); return v0.apply(this, arguments); };
    const r0 = YA.resolveEvent;
    YA.resolveEvent = function (w, e, idx) { if (e.id === id) obPrep(w, e); return r0.apply(this, arguments); };
  }
  YA.EXTRA_SIM_IMPORTANT = (YA.EXTRA_SIM_IMPORTANT || []).concat(['obret', 'ref']);

  // 引退した年を控える（戻ってくるのは引退から3年のうち）
  const at0 = YA.alumniTick;
  YA.alumniTick = function (w) {
    const was = new Set((w.alumni || []).filter((a) => a.retired));
    const r = at0.apply(this, arguments);
    for (const a of w.alumni || []) if (a.retired && !was.has(a) && a.retY == null) a.retY = w.year;
    return r;
  };
  // 毎週：OBコーチが★の子に話す（月1回）・戻りたい卒業生（3週）・紹介（10週）
  const fw = (w, ev) => { w.forced = (w.forced || []).concat([Object.assign({ pid: null, x: null, week: w.week, year: w.year }, ev)]); };
  const rw0 = YA.rivalWeek;
  YA.rivalWeek = function (w) {
    const res = rw0 ? rw0.apply(this, arguments) : undefined;
    const key = w.year * 100 + w.week;
    if (w.memKey === key) return res;
    w.memKey = key;
    if (w.week % 4 === 2) {
      for (const s of (w.club && w.club.staff) || []) {
        if (!s.mentor) continue;
        const stars = Object.values(w.players).filter((p) => p.star);
        if (!stars.length) continue;
        const same = stars.filter((p) => p.pos === s.pos);
        const p = (same.length ? same : stars)[YA.hash(s.name + key) % (same.length || stars.length)];
        YA.hintUp(w, p, 0.35, `${s.role}の${s.name}の話`);
        YA.keyProgress(w, p, 'alum', 1);
        p.hist.unshift({ y: w.year, w: w.week, t: `${s.role}の${s.name}（卒業生）が、自分の経験を話してくれた` });
      }
    }
    if (w.week === 3) {
      const a = (w.alumni || []).find((x) => x.mem && x.star && x.retired && !x.coached && (x.bond == null ? 3 : x.bond) >= 3 && x.retY != null && w.year - x.retY <= 3 && x.status !== 'left' && x.path2 !== 'quit');
      if (a) fw(w, { id: 'obret', who: a.name, ay: a.year });
    }
    if (w.week === 10) {
      const a = (w.alumni || []).find((x) => x.mem && x.star && !x.retired && x.status === 'pro' && (x.bond == null ? 3 : x.bond) >= 4 && (x.refDone || 0) < 2 && w.year - x.year >= 2 && (w.year + YA.hash(x.name)) % 3 === 0);
      if (a) fw(w, { id: 'ref', who: a.name, ay: a.year });
    }
    return res;
  };
})();
