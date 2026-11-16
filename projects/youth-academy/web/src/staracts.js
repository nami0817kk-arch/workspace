// ★の子に自分からできること（2026-11-16「★の選手に自分からできるアクションを増やしたい」）。
// これまで★の子に自分から働きかけられるのは面談（月1回・全員共通）だけだった。
// ★の子にだけ、6つの働きかけを足す。★の子全体で1週に YA.STAR_ACT_WEEK 回まで、同じ働きかけは同じ子に間をあける。
// 効き目は信頼・自信・不満・能力・戦術理解・覚醒の鍵のヒント。目標の約束は4週のうちに届くかで結果が分かれる。
// おまかせ進行は使わない（自分で手をかけるための道具）。
(function () {
  const YA = (globalThis.YA = globalThis.YA || {});
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const wk = (w) => w.year * 40 + w.week;
  const first = (p) => p.name.split(' ')[1] || p.name;
  const say = (p, s) => (YA.voice ? YA.voice(p, s) : s);
  const pick = (w, p, k, list) => list[YA.hash(p.id + k + w.year + w.week) % list.length];
  const scorer = (p) => p.pos === 'FW' || ['AM', 'SS', 'LW', 'RW'].indexOf(p.main) >= 0;

  YA.STAR_ACT_WEEK = 2;
  YA.PACT_WEEKS = 4;
  YA.pactLine = function (w, p) {
    const pc = p.pact;
    if (!pc) return null;
    const cs = p.cs || { apps: 0, goals: 0 };
    const have = Math.max(0, (cs[pc.t] || 0) - pc.base);
    return `約束：${pc.t === 'goals' ? `Aの公式戦で${pc.need}点` : `Aの公式戦に${pc.need}試合出る`}（いま ${have}/${pc.need}・あと${Math.max(0, pc.due - wk(w))}週）`;
  };
  // プロの卒業生（同じ位置・絆の深い子を先に）
  const obFor = (w, p) => (w.alumni || []).filter((a) => a.status === 'pro' && !a.retired).sort((a, b) => (b.pos === p.pos ? 1 : 0) - (a.pos === p.pos ? 1 : 0) || (b.bond || 0) - (a.bond || 0) || b.ovr - a.ovr)[0] || null;

  YA.STAR_ACTS = [
    { k: 'stay', name: '居残り練習に付き合う', cd: 3, about: '苦手な能力を1つ一緒に鍛える。伸びることがある（信頼が高いほど伸びやすい）。少し疲れる',
      need: (w, p) => (p.inj > 0 ? '怪我が治ってからにしましょう' : p.fat >= 80 ? '疲れが溜まっています。今週は休ませましょう' : null) },
    { k: 'video', name: '試合の映像を一緒に見る', cd: 3, about: '最近の試合を一緒に見返す。戦術理解と自信が上がり、覚醒の鍵のヒントが見えることがある',
      need: (w, p) => (p.lm && wk(w) - (p.lm.y * 40 + p.lm.w) <= 3 ? null : '最近（3週以内）の試合に出ていません') },
    { k: 'hint', name: '覚醒の手がかりを話し合う', cd: 4, about: 'まだ見えていない覚醒の鍵のヒントを一緒に探す。信頼が高いほど見つかりやすい',
      need: (w, p) => (p.aw ? 'もう覚醒しています' : (p.keys || []).some((k) => !k.done && k.h < 2) ? null : '見えていない鍵がありません') },
    { k: 'meal', name: 'ご飯に連れて行く', cd: 4, about: 'ゆっくり話を聞く。信頼が大きく上がり、不満が和らぐ' },
    { k: 'pact', name: '目標を約束する', cd: 6, about: `${YA.PACT_WEEKS}週のうちの目標を一緒に決める（点を取る子は「Aで2点」、ほかは「Aに3試合出る」）。届けば自信と信頼が上がって能力が伸びる。届かないと少し下がる`,
      need: (w, p) => (p.pact ? 'いま約束している目標があります' : w.week > 36 ? '年度の終わりが近いので、来年度に約束しましょう' : null) },
    { k: 'ob', name: '卒業生に会わせる', cd: 40, about: 'プロになった卒業生と話す機会を作る（同じポジションの先輩を先に）。自信が上がり、鍵のヒントが見えることがある。1人の子に年1回',
      need: (w, p) => (obFor(w, p) ? null : 'プロになった卒業生がまだいません') },
  ];
  const def = (k) => YA.STAR_ACTS.find((x) => x.k === k);
  YA.starActLeft = (w) => YA.STAR_ACT_WEEK - (w.saUsed && w.saUsed.k === wk(w) ? w.saUsed.n : 0);
  // 押せない理由（押せるなら null）
  YA.starActWhy = function (w, p, k) {
    const d = def(k);
    if (!d || !p) return 'できません';
    if (!p.star) return '★の子だけにできることです';
    if (p.away > 0) return 'いまチームを離れています';
    const last = (p.sa || {})[k];
    if (last != null && wk(w) - last < d.cd) return `${d.name}は同じ子に${d.cd >= 40 ? '年1回' : d.cd + '週に1回'}です（あと${d.cd - (wk(w) - last)}週）`;
    if (YA.starActLeft(w) <= 0) return `今週の分（${YA.STAR_ACT_WEEK}回）を使いました。来週またできます`;
    return d.need ? d.need(w, p) : null;
  };

  YA.starAct = function (w, p, k) {
    const why = YA.starActWhy(w, p, k);
    if (why) return { ok: false, msg: why };
    const d = def(k);
    const r = YA.rngOf((w.seed | 0) * 31 + wk(w) * 7 + YA.hash(p.id + k));
    const lv = YA.trustLv ? YA.trustLv(p) : 3;
    let msg = '';
    let q = '';
    if (k === 'stay') {
      const list = (YA.POS_ABS15[p.main] || Object.keys(p.ab)).filter((a) => p.ab[a] != null && p.ab[a] < 20);
      const a = list.sort((x, y) => p.ab[x] - p.ab[y])[0];
      p.fat = clamp(p.fat + 10, 0, 100);
      YA.addTr(w, p, 2);
      if (a && r.chance(0.45 + (lv >= 4 ? 0.15 : lv <= 2 ? -0.15 : 0))) {
        p.ab[a] = Math.min(20, p.ab[a] + 1);
        msg = `${first(p)}の居残り練習に付き合った。苦手だった「${a}」が少し伸びた（${p.ab[a] - 1}→${p.ab[a]}）。疲れ+10`;
      } else msg = `${first(p)}の居残り練習に付き合った。「${a || '基礎'}」を繰り返した。すぐには伸びないが、続ければ形になりそうだ。疲れ+10`;
      q = pick(w, p, k, ['最後まで付き合ってくれて、ありがとうございます', '明日も、もう少しだけやっていいですか', '一人じゃ、ここまでできませんでした']);
    } else if (k === 'video') {
      p.tu = clamp((p.tu == null ? 40 : p.tu) + 4, 0, 100);
      p.conf = clamp(p.conf + 3, 0, 100);
      YA.addTr(w, p, 2);
      const seen = YA.hintUp ? YA.hintUp(w, p, 0.35, '映像を見て') : false;
      msg = `${first(p)}と、この前の試合の映像を見返した。戦術理解+4・自信+3${seen ? '。覚醒の鍵のヒントが見えた' : ''}`;
      q = pick(w, p, k, ['あの場面、もう半歩前にいればよかったんですね', '自分のプレーを外から見るの、初めてでした', '次は、ここで顔を上げます']);
    } else if (k === 'hint') {
      YA.addTr(w, p, 2);
      const seen = YA.hintUp ? YA.hintUp(w, p, 0.85, '話し合って') : false;
      msg = seen ? `${first(p)}と、これからのことを話し合った。覚醒の鍵のヒントが見えた` : `${first(p)}と、これからのことを話し合った。まだはっきりしないが、本人は何かを感じているようだ（信頼が高いほど見つかりやすい）`;
      q = pick(w, p, k, ['何が足りないのか、少し分かってきた気がします', '自分でも、まだ言葉にできないんです', '監督に話したら、すっきりしました']);
    } else if (k === 'meal') {
      YA.addTr(w, p, 8);
      p.unrest = Math.max(0, (p.unrest || 0) - 1.5);
      p.conf = clamp(p.conf + 3, 0, 100);
      msg = `${first(p)}をご飯に連れて行った。サッカー以外の話もたくさんした。信頼+8・自信+3・不満が和らいだ`;
      q = pick(w, p, k, ['ごちそうさまでした。また話を聞いてください', '家族の話、誰かにしたのは初めてです', '監督も、高校のころは悩んでたんですね']);
    } else if (k === 'pact') {
      const cs = p.cs || (p.cs = { apps: 0, goals: 0, assists: 0 });
      const t = scorer(p) ? 'goals' : 'apps';
      const need = t === 'goals' ? 2 : 3;
      p.pact = { t, need, base: cs[t] || 0, w0: wk(w), due: wk(w) + YA.PACT_WEEKS };
      YA.addTr(w, p, 1);
      msg = `${first(p)}と目標を約束した：${YA.PACT_WEEKS}週のうちに${t === 'goals' ? `Aの公式戦で${need}点` : `Aの公式戦に${need}試合出る`}。Aで使うかどうかは、あなたの起用しだい`;
      q = pick(w, p, k, ['約束します。絶対に届かせます', '言ったからには、やります', '見ていてください']);
    } else if (k === 'ob') {
      const a = obFor(w, p);
      p.conf = clamp(p.conf + 6, 0, 100);
      YA.addTr(w, p, 3);
      a.bond = a.bond == null ? a.bond : Math.min(6, a.bond + 0.2);
      const seen = YA.hintUp ? YA.hintUp(w, p, 0.5, '卒業生と話して') : false;
      msg = `卒業生の${a.name}（${a.club}）に、${first(p)}と会ってもらった。プロの話に目を輝かせていた。自信+6${seen ? '。覚醒の鍵のヒントが見えた' : ''}`;
      q = pick(w, p, k, [`${a.name.split(' ')[1] || a.name}さんみたいになりたいです`, 'プロの世界のこと、もっと知りたくなりました', '同じユースから、あそこまで行けるんですね']);
    }
    w.saUsed = w.saUsed && w.saUsed.k === wk(w) ? w.saUsed : { k: wk(w), n: 0 };
    w.saUsed.n++;
    p.sa = p.sa || {};
    p.sa[k] = wk(w);
    p.hist.unshift({ y: w.year, w: w.week, t: d.name });
    if (YA.memAdd) YA.memAdd(w, p, 'sa', null, say(p, q), { sa: k });
    return { ok: true, msg, line: say(p, q) };
  };

  // 約束の答え合わせ（毎週）
  const rw0 = YA.rivalWeek;
  YA.rivalWeek = function (w) {
    const res = rw0 ? rw0.apply(this, arguments) : undefined;
    if (w.saKey === wk(w)) return res;
    w.saKey = wk(w);
    for (const p of Object.values(w.players || {})) {
      const pc = p.pact;
      if (!pc) continue;
      const have = Math.max(0, ((p.cs || {})[pc.t] || 0) - pc.base);
      if (have >= pc.need) {
        delete p.pact;
        p.conf = clamp(p.conf + 8, 0, 100);
        YA.addTr(w, p, 6, '約束を果たした');
        const list = (YA.POS_ABS15[p.main] || []).filter((a) => p.ab[a] != null && p.ab[a] < 20);
        const a = list.length ? list[YA.hash(p.id + w.year + w.week) % list.length] : null;
        if (a) p.ab[a]++;
        YA.noteTier(w, 1, `${p.num}番 ${p.name}が約束の目標に届いた（${pc.t === 'goals' ? pc.need + '点' : pc.need + '試合'}）。自信+8${a ? `・「${a}」が伸びた` : ''}`, p.id);
        if (YA.memAdd) YA.memAdd(w, p, 'sa', 'good', say(p, '約束、守れました'), { sa: 'pactok' });
      } else if (wk(w) >= pc.due) {
        delete p.pact;
        p.conf = clamp(p.conf - 4, 0, 100);
        YA.addTr(w, p, -4, '約束に届かなかった');
        YA.noteTier(w, 2, `${p.num}番 ${p.name}は約束の目標に届かなかった（${have}/${pc.need}）。自信-4`, p.id);
      }
    }
    return res;
  };

  if (YA.MEM_NAME) YA.MEM_NAME.sa = '二人の時間';

  // 選手の画面（★の子だけ）：6つの働きかけと結果
  YA.starActsEl = function (w, p, rerender) {
    if (!p || !p.star || !YA._ui) return null;
    const h = YA._ui.h;
    const app = YA._ui.app || {};
    const left = YA.starActLeft(w);
    const msg = app.saMsg && app.saMsg.pid === p.id ? app.saMsg : null;
    return h('div', { class: 'card', style: 'padding:6px 9px;margin:6px 0;background:#fff8e1;border-color:#e6c200' },
      h('div', { class: 'h' }, `★の子と過ごす（今週あと${Math.max(0, left)}回・★の子全体で週${YA.STAR_ACT_WEEK}回）`),
      p.pact ? h('div', { class: 'note', style: 'color:var(--ink)' }, YA.pactLine(w, p)) : null,
      h('div', { style: 'display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:5px;margin-top:4px' },
        YA.STAR_ACTS.map((d) => {
          const why = YA.starActWhy(w, p, d.k);
          return h('button', { class: 'btn sm', style: 'flex-direction:column;align-items:flex-start;text-align:left;white-space:normal;min-height:44px', disabled: !!why, why: why || '', title: d.about,
            onclick: () => { const r = YA.starAct(w, p, d.k); app.saMsg = { pid: p.id, t: r.msg, line: r.line }; if (YA.saveWorld) YA.saveWorld(); if (rerender) rerender(); } },
          h('b', {}, d.name), h('small', { style: 'font-weight:600;opacity:.8' }, d.about.split('。')[0]));
        })),
      msg ? h('div', { class: 'card', style: 'padding:5px 8px;margin-top:5px;background:#fff' }, msg.line ? h('div', {}, h('b', {}, first(p) + '：'), `「${msg.line}」`) : null, h('div', { class: 'note', style: 'color:var(--ink)' }, msg.t)) : null);
  };
})();
