// 選手を構成する要素 段階6「★の子」（2026-11-19 ⑨）。2026-11-26 から★の子＝いま課題に取り組んでいる子（p.star）
// ・信頼の段階で開くもの（YA.TRUST_UNLOCK：日誌・本音・働きかけ・隠れた力・覚醒の鍵）
// ・働きかけ 6→12（staracts.js の6つに、ここの6つを足す。信頼の段階で開く）
// ・★の子の日誌（毎週1行。信頼2から読める）
// ・★の子どうしの関係（同じ位置の★はライバル＝一緒に伸びる、同じ学年の★は同期＝支え合う、同じ位置の先輩後輩）
(function () {
  const YA = globalThis.YA;
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const all = (w) => Object.values(w.players || {});
  const wk = (w) => w.year * 40 + w.week;
  const first = (p) => p.name.split(' ')[1] || p.name;
  const say = (p, s) => (YA.voice ? YA.voice(p, s) : s);
  const lvOf = (p) => (YA.trustLv ? YA.trustLv(p) : 3);
  const pick = (w, p, k, list) => list[YA.hash(p.id + k + w.year + w.week) % list.length];

  // ---------- 信頼で開くもの ----------
  YA.TRUST_UNLOCK = [
    { lv: 2, k: 'diary', t: '日誌が読める' },
    { lv: 2, k: 'acts2', t: '働きかけ「家族と話す」「試合前に声をかける」' },
    { lv: 3, k: 'honest', t: '本音（進路の希望と、いまの悩み）が分かる' },
    { lv: 3, k: 'acts3', t: '働きかけ「別の位置を試させる」「本を薦める」' },
    { lv: 4, k: 'hidden', t: '隠れた力がコーチの言葉で全部分かる' },
    { lv: 5, k: 'key', t: '手がかりが毎月ひとつ見えやすくなる' },
  ];
  YA.trustOpen = (p, k) => { const u = YA.TRUST_UNLOCK.find((x) => x.k === k); return !!u && p.star && lvOf(p) >= u.lv; };

  // ---------- 働きかけ 6→12 ----------
  const hasMatch = (w) => (YA.hasMatch ? YA.hasMatch(w.week, w) : true);
  YA.STAR_ACTS.push(
    { k: 'menu', name: '自主練のメニューを一緒に作る', cd: 4, lv: 1, about: '苦手な能力2つに合わせた自主練を一緒に考える。少しずつ伸びる。少し疲れる',
      need: (w, p) => (p.inj > 0 ? '怪我が治ってからにしましょう' : p.fat >= 80 ? '疲れが溜まっています' : null) },
    { k: 'rest', name: '休ませて話を聞く', cd: 3, lv: 1, about: '練習を一日休ませて、ゆっくり話を聞く。疲れが大きく抜け、燃え尽き・ホームシックが和らぐ',
      need: (w, p) => (p.fat < 25 && !p.mind ? '疲れも悩みも少なく、休ませる必要はなさそうです' : null) },
    { k: 'family', name: '家族と話す', cd: 8, lv: 2, about: '保護者に連絡して、本人の様子を伝え合う。不満が和らぎ、ホームシックが抜けやすい', need: () => null },
    { k: 'pregame', name: '試合前に声をかける', cd: 2, lv: 2, about: '今週の試合の前に、二人で話す。その試合だけ自信が上がり、プレッシャーが抜ける',
      need: (w) => (hasMatch(w) ? null : '今週は試合がありません') },
    { k: 'pos', name: '別の位置を試させる', cd: 6, lv: 3, about: '練習で、いつもと違う位置に立たせてみる。本当に向いている位置に気づくことがあり、こなせる位置の適性が上がる',
      need: (w, p) => (p.pos === 'GK' ? 'GK は位置を試しません' : null) },
    { k: 'book', name: '本を薦める', cd: 6, lv: 3, about: 'サッカーの本や試合の記録を薦める。判断・冷静さ・集中が少しずつ伸び、戦術理解が上がる', need: () => null },
  );
  Object.assign(YA.STAR_ACT_TAGS, { menu: ['苦手2つ↑', '疲れ'], rest: ['疲れ↓↓', '心の状態↓'], family: ['不満↓', 'ホームシック↓', '信頼2'], pregame: ['その試合の自信↑', '信頼2'], pos: ['本当の向き', '適性↑', '信頼3'], book: ['頭の能力↑', '戦術理解↑', '信頼3'] });
  const NEW = new Set(['menu', 'rest', 'family', 'pregame', 'pos', 'book']);
  const why0 = YA.starActWhy;
  YA.starActWhy = function (w, p, k) {
    const d = YA.STAR_ACTS.find((x) => x.k === k);
    if (d && d.lv && p && p.star && lvOf(p) < d.lv) return `信頼が「${YA.TRUST_NAME[d.lv]}」（${d.lv}/5）になると、できるようになります`;
    return why0.apply(this, arguments);
  };
  const act0 = YA.starAct;
  YA.starAct = function (w, p, k) {
    if (!NEW.has(k)) return act0.apply(this, arguments);
    const why = YA.starActWhy(w, p, k);
    if (why) return { ok: false, msg: why };
    const d = YA.STAR_ACTS.find((x) => x.k === k);
    const r = YA.rngOf((w.seed | 0) * 37 + wk(w) * 11 + YA.hash(p.id + k));
    let msg = '';
    let q = '';
    if (k === 'menu') {
      const list = (YA.POS_ABS15[p.main] || Object.keys(p.ab)).filter((a) => p.ab[a] != null && p.ab[a] < 20).sort((a, b) => p.ab[a] - p.ab[b]).slice(0, 2);
      for (const a of list) p.prog[a] = (p.prog[a] || 0) + 0.45 + (lvOf(p) >= 4 ? 0.15 : 0);
      p.fat = clamp(p.fat + 5, 0, 100);
      YA.addTr(w, p, 2);
      msg = `${first(p)}と、「${list.join('」「')}」を伸ばす自主練のメニューを作った。少しずつ伸びていく。疲れ+5`;
      q = pick(w, p, k, ['これなら毎日続けられそうです', '自分の弱いところ、ちゃんと見てくれてたんですね', '一か月後、見ていてください']);
    } else if (k === 'rest') {
      p.fat = clamp(p.fat - 20, 0, 100);
      p.unrest = Math.max(0, (p.unrest || 0) - 1);
      p.rest = 'rest';
      if (p.mind) { p.mind.w -= 2; if (p.mind.w <= 0 && YA.endMind) YA.endMind(w, p, '休んで話をして'); }
      YA.addTr(w, p, 3);
      msg = `${first(p)}を一日休ませて、ゆっくり話を聞いた。疲れ-20${p.mind ? '' : '・気持ちも少し軽くなったようだ'}`;
      q = pick(w, p, k, ['休むのも練習なんですね', '正直、少し疲れてました', 'ちゃんと寝ます']);
    } else if (k === 'family') {
      p.unrest = Math.max(0, (p.unrest || 0) - 2);
      YA.addTr(w, p, 5);
      if (p.mind && p.mind.k === 'homesick' && YA.endMind) YA.endMind(w, p, '家族と話して');
      msg = `${first(p)}の保護者に連絡して、最近の様子を伝え合った。信頼+5・不満が和らいだ`;
      q = pick(w, p, k, ['親から電話がありました。ちょっと照れくさいです', '家のこと、気にかけてくれてありがとうございます', '母が、監督によろしくって']);
    } else if (k === 'pregame') {
      p._pg = wk(w);
      p.conf = clamp(p.conf + 4, 0, 100);
      if (p.mind && p.mind.k === 'pressure' && YA.endMind) YA.endMind(w, p, '試合前に話して');
      YA.addTr(w, p, 2);
      msg = `試合の前に、${first(p)}と二人で話した。今週の試合は、気持ちよく入れそうだ（その試合の自信+8）`;
      q = pick(w, p, k, ['いつも通りやってきます', '楽しんできます', '見ててください']);
    } else if (k === 'pos') {
      YA.addTr(w, p, 2);
      const best = p.best && p.best !== 'GK' ? p.best : p.main;
      if (!p.bestKnown && best !== p.main && r() < 0.5 + (lvOf(p) >= 4 ? 0.2 : 0) && YA.posNotice) {
        YA.posNotice(w, p, '練習で別の位置に立たせてみたら');
        msg = `${first(p)}を練習で${YA.POS_LABEL[best]}に立たせてみた。動きが見違えた。本当に向いている位置かもしれない`;
      } else {
        const subs = (p.subs || []).concat(YA.NEAR_POS[best] || []).filter((x) => x !== p.main && x !== 'GK');
        const q2 = subs.length ? subs[Math.floor(r() * subs.length)] : null;
        if (q2) { p.aptX = p.aptX || {}; p.aptX[q2] = (p.aptX[q2] || 0) + 0.6; YA.refreshApt(p); }
        msg = q2 ? `${first(p)}を練習で${YA.POS_LABEL[q2]}に立たせてみた。少しずつ慣れてきた` : `${first(p)}を別の位置に立たせてみた。`;
      }
      q = pick(w, p, k, ['こっちの景色も、悪くないです', '新しい自分が見えた気がします', '慣れるまで付き合ってください']);
    } else if (k === 'book') {
      for (const a of ['判断', '冷静さ', '集中']) if (p.ab[a] != null) p.prog[a] = (p.prog[a] || 0) + 0.3;
      p.tu = clamp((p.tu == null ? 40 : p.tu) + 3, 0, 100);
      YA.addTr(w, p, 2);
      msg = `${first(p)}にサッカーの本を薦めた。判断・冷静さ・集中が少しずつ伸びる。戦術理解+3`;
      q = pick(w, p, k, ['一晩で読みました', '線を引きながら読んでます', 'あの監督の考え方、真似してみます']);
    }
    w.saUsed = w.saUsed && w.saUsed.k === wk(w) ? w.saUsed : { k: wk(w), n: 0 };
    w.saUsed.n++;
    p.sa = p.sa || {};
    p.sa[k] = wk(w);
    p.hist.unshift({ y: w.year, w: w.week, t: d.name });
    if (YA.memAdd) YA.memAdd(w, p, 'sa', null, say(p, q), { sa: k });
    p._actWk = { k, wk: wk(w) };
    return { ok: true, msg, line: say(p, q) };
  };
  // 試合前に声をかけた試合は自信が上がる
  const tf0 = YA.teamFromWorld;
  YA.teamFromWorld = function (w, which) {
    const t = tf0.apply(this, arguments);
    for (const p of Object.values(t.players)) if (p._pg === wk(w) && !p._pgUsed) { p._pgUsed = wk(w); p.conf = clamp(p.conf + 8, 0, 100); }
    return t;
  };

  // ---------- ★の子どうしの関係 ----------
  YA.STAR_REL = { rival: 'ライバル', mate: '同期の課題仲間', line: '同じ位置の先輩後輩' };
  YA.starRels = function (w, p) {
    if (!p.star) return [];
    const out = [];
    for (const q of all(w)) {
      if (q === p || !q.star) continue;
      const sameGrp = YA.GROUP[q.main] === YA.GROUP[p.main];
      if (sameGrp && q.grade === p.grade) out.push({ q, k: 'rival' });
      else if (sameGrp) out.push({ q, k: 'line' });
      else if (q.grade === p.grade) out.push({ q, k: 'mate' });
    }
    return out;
  };
  // ライバルが同じチームで出ていると、二人とも伸びが少し上がる
  const gk0 = YA.growK || (() => 1);
  YA.growK = function (p) { return gk0(p) * (p._rivalOn ? 1.05 : 1); };

  // ---------- 日誌 ----------
  function diaryLine(w, p) {
    const lv = lvOf(p);
    const rl = (p.rl || []).slice(-1)[0];
    const played = rl && rl.y === w.year && rl.w === w.week;
    const opts = [];
    if (p.inj > 0) opts.push(lv >= 3 ? `${p.injPart || '足'}が痛い。早く戻りたいけど、焦ったら負けだ。` : '怪我。今は治すしかない。');
    if (p.mind) opts.push({ slump: '何をやってもうまくいかない。どうしたらいいんだろう。', burnout: '体が重い。サッカーが少しだけ、しんどい。', homesick: '家のご飯が食べたい。電話で声を聞いたら、泣きそうになった。', pressure: 'みんなの期待が重い。眠れない夜がある。' }[p.mind.k]);
    if (played && rl.r >= 7.3) opts.push(rl.g ? `今日は${rl.g}点取れた。あの感覚を忘れたくない。` : '今日は自分でも驚くくらい体が動いた。');
    else if (played && rl.r <= 5.8) opts.push('今日の試合は悔しい。もっと練習しないと。');
    else if (played) opts.push('試合に出た。まだまだやれることがある。');
    const gained = Object.entries(p.gain || {}).filter(([, v]) => v > 0).map(([k]) => k);
    if (gained.length) opts.push(`最近「${gained[0]}」が少し良くなってきた気がする。`);
    if (p._actWk && p._actWk.wk === wk(w)) opts.push({ menu: '監督と作った自主練、続けてみる。', rest: '今日は休んだ。監督とたくさん話した。', family: '親と監督が話したらしい。ちょっと恥ずかしい。', pregame: '試合前に監督と話した。いつも通りやればいい。', pos: '違う位置をやってみた。新しい景色だった。', book: '薦められた本、思ったより面白い。' }[p._actWk.k]);
    const rels = YA.starRels(w, p).filter((x) => x.k === 'rival');
    if (rels.length) opts.push(`${rels[0].q.name.split(' ')[0]}には負けたくない。`);
    if (!opts.length) opts.push(lv >= 4 ? '今日も練習。監督に言われたこと、少しずつ分かってきた。' : '今日も練習。');
    // 信頼が低いうちは、短く本音を書かない
    let t = opts[YA.hash(p.id + w.year + w.week) % opts.length];
    if (lv <= 2) t = t.split('。')[0] + '。';
    return t;
  }
  const ew0 = YA.endWeek;
  YA.endWeek = function (w) {
    // ライバルが二人とも A にいるか
    const inA = new Set((w.lineupA || []).map((s) => s.pid));
    for (const p of all(w)) p._rivalOn = p.star && inA.has(p.id) && YA.starRels(w, p).some((x) => x.k === 'rival' && inA.has(x.q.id));
    const res = ew0.apply(this, arguments);
    for (const p of all(w)) {
      if (!p.star) continue;
      p.diary = (p.diary || []).concat([{ y: w.year, w: w.week, t: diaryLine(w, p) }]).slice(-10);
      // 同期の課題中の子がいると支え合う
      if (YA.starRels(w, p).some((x) => x.k === 'mate' && !(x.q.inj > 0))) p.conf = clamp(p.conf + 0.5, 0, 100);
      // 深い信頼：月のはじめに手がかり
      if (lvOf(p) >= 5 && YA.calendar && YA.calendar(w.week).nth === 1 && YA.hintUp) YA.hintUp(w, p, 0.9, '深い信頼で');
    }
    return res;
  };

  // ---------- 隠れた力：信頼4で全部を言葉に ----------
  const HW = {
    安定感: ['出来に波がない', '出来はまずまず安定している', '出来に波がある'],
    大一番の強さ: ['大きな試合で力を出す', '大きな試合でもいつも通り', '大きな試合で硬くなる'],
    怪我のしにくさ: ['体が頑丈', '体はふつう', '怪我をしやすい'],
    適応力: ['慣れるのが早い', '慣れるのはふつう', '慣れるのに時間がかかる'],
    プロ意識: ['自分を律している', '生活はふつう', '練習の外に甘さがある'],
  };
  const hw0 = YA.hidWords;
  YA.hidWords = function (w, p) {
    if (!YA.trustOpen(p, 'hidden') || !p.hid) return hw0.apply(this, arguments);
    return YA.HID.map((k) => { const v = p.hid[k]; const i = v >= 14 ? 0 : v >= 8 ? 1 : 2; return { k, v, good: i === 0, mid: i === 1, t: HW[k][i] }; });
  };

  // ---------- 概要の★の欄 ----------
  const ov0 = YA.playerOverview;
  if (ov0) {
    YA.playerOverview = function (w, p) {
      const el = ov0.apply(this, arguments);
      if (!p.star) return el;
      try {
        const doc = el.ownerDocument;
        const sec = Array.from(el.querySelectorAll('.ovsec')).find((s) => s.querySelector('.ovh') && /課題中/.test(s.querySelector('.ovh').textContent));
        if (!sec) return el;
        const add = (txt, css) => { const d = doc.createElement('div'); d.className = 'ovinfo'; d.style.cssText = 'font-size:11.5px;line-height:1.45' + (css ? ';' + css : ''); d.textContent = txt; sec.append(d); return d; };
        const lv = lvOf(p);
        add('信頼で開くもの：' + YA.TRUST_UNLOCK.map((u) => (lv >= u.lv ? `✓${u.t}` : `（信頼${u.lv}で）${u.t}`)).join('／'), 'color:var(--sub)');
        if (YA.trustOpen(p, 'honest')) {
          const wish = YA.WISH_WORD ? YA.WISH_WORD[YA.wishOf(p)] : null;
          const worry = p.mind ? YA.MIND[p.mind.k].name : p.unrest > 1.5 ? '出番のこと' : p.inj > 0 ? '怪我のこと' : 'とくになし';
          add(`本音：進路は「${wish || '未定'}」を望んでいる。いまの悩みは「${worry}」`, 'color:#6b4e00');
        }
        const rels = YA.starRels(w, p);
        if (rels.length) add('課題中の子どうし：' + rels.map((x) => `${x.q.name}（${YA.STAR_REL[x.k]}）`).join('・'), 'color:#0d4a72');
        if (YA.trustOpen(p, 'diary') && (p.diary || []).length) {
          const d = add('', 'background:#fffaf0;border-radius:6px;padding:4px 7px;margin-top:3px');
          const hd = doc.createElement('b'); hd.textContent = '日誌'; hd.style.fontSize = '11px'; d.append(hd);
          for (const e of p.diary.slice(-3).reverse()) { const x = doc.createElement('div'); x.textContent = `${YA.ywName(e.y, e.w)}：${e.t}`; d.append(x); }
        } else if (p.star) add('日誌は、信頼が「よそよそしい」（2/5）になると読めます', 'color:var(--sub)');
      } catch (e) { /* 形の違う画面 */ }
      return el;
    };
  }
})();
