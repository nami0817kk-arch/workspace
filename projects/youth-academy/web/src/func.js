// 機能面（仕様書「機能面」）：比べる画面・PK戦の順番・育成計画・伸び悩みの診断・先輩との比較・師弟を付ける・位置の転向練習・
// 展開ごとの指示・戦術理解の内訳・クラブの記録帳・中長期の計画・海外移籍の交渉・卒業生を追う/連絡/観に行く/年表・用語集。
(function () {
  'use strict';
  const YA = (globalThis.YA = globalThis.YA || {});
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const all = (w) => Object.values(w.players);
  const sur = (n) => String(n).split(' ')[0];
  const H = () => YA._ui.h;
  const rer = () => YA._ui.render();
  const save = () => { if (YA.saveWorld) YA.saveWorld(); };
  const conf = (p, d) => { if (p) p.conf = clamp((p.conf || 50) + d, 0, 100); };
  const CATS = { 体: () => YA.AB_PHYS || [], 技術: () => YA.AB_TECH || [], 頭: () => YA.AB_MENTAL || [] };
  const catSum = (p, k) => CATS[k]().reduce((s, a) => s + (p.ab[a] || 0), 0);

  // ---------- 記録の土台：クラブでの通算（Aの公式戦）と、学年ごとの総合力 ----------
  const am0 = YA.applyMatch;
  YA.applyMatch = function (w, m, which, opp, scheduled) {
    const r = am0.apply(this, arguments);
    try {
      if (which === 'A' && scheduled && m && m.home && m.home.players) {
        for (const [id, mp] of Object.entries(m.home.players)) {
          const p = w.players[id];
          if (!p || !mp.st || !(mp.st.minutes > 0 || (p.lm && p.lm.w === w.week && p.lm.mins > 0))) continue;
          p.cs = p.cs || { apps: 0, goals: 0, assists: 0 };
          p.cs.apps++; p.cs.goals += mp.st.goals || 0; p.cs.assists += mp.st.assists || 0;
        }
      }
    } catch (er) { /* 形の違う試合 */ }
    return r;
  };
  const ys0 = YA.yearStart;
  YA.yearStart = function (w) {
    // 前の年の育成計画の答え合わせ（年度はじめの前に）
    for (const p of all(w)) if (p.yplan && p.yplan.y === w.year - 1 && !p.yplan.done) YA.planCheck(w, p);
    const r = ys0.apply(this, arguments);
    for (const p of all(w)) { p.rHist = (p.rHist || []).filter((x) => x.g !== p.grade).concat([{ g: p.grade, r: YA.rate(YA.ovr(p)), y: w.year }]); }
    w.plans = (w.plans || []).filter((x) => !x.done || x.y >= w.year - 3);
    YA.planUpdate(w);
    return r;
  };
  const ae0 = YA.alumniEntry;
  YA.alumniEntry = function (w, p) {
    const a = ae0.apply(this, arguments);
    if (p.cs) a.cs = Object.assign({}, p.cs);
    if (p.rHist) a.rHist = p.rHist.slice();
    if (p.num10) a.num10 = p.num10;
    return a;
  };

  // ---------- 比べる画面 ----------
  YA.compareRows = function (w, a, b) {
    const key = (YA.ROLE_KEY && YA.ROLE_KEY[a.pos]) || (a.pos === 'GK' ? ['反応', '1対1', 'ハンドリング', '飛び出し'] : a.pos === 'DF' ? ['タックル', 'マーク', 'ヘディング', 'ポジショニング'] : a.pos === 'MF' ? ['パス', '視野', '判断', 'スタミナ'] : ['フィニッシュ', 'オフザボール', 'ドリブル', 'スピード']);
    const rows = [['総合力', YA.rating(a), YA.rating(b)], ['学年', '高' + a.grade, '高' + b.grade], ['伸びしろ', '★'.repeat(YA.coachStars(w, a)), '★'.repeat(YA.coachStars(w, b))],
      [`適性（${YA.POS_LABEL[a.main] || a.main}）`, Math.round(a.apt[a.main] || 0), Math.round(b.apt[a.main] || 0)]];
    for (const k of key) rows.push([k, a.ab[k] != null ? a.ab[k] : '-', b.ab[k] != null ? b.ab[k] : '-']);
    rows.push(['自信', Math.round(a.conf), Math.round(b.conf)], ['疲れ', Math.round(a.fat), Math.round(b.fat)], ['今年のAの出場', `${Math.round(a.minsA || 0)}分`, `${Math.round(b.minsA || 0)}分`], ['信頼', YA.trustLv(a) + '/5', YA.trustLv(b) + '/5']);
    return rows;
  };
  YA.compareModal = function (w, a) {
    const h = H();
    YA._v.modal((close) => {
      const box = h('div', { class: 'sheet-in', style: 'flex:none;align-self:center;margin:auto;width:min(620px,96%);padding:12px;gap:6px;max-height:92%;overflow:auto' });
      const draw = (b) => {
        box.replaceChildren(h('div', { class: 'row' }, h('div', { class: 'h grow' }, b ? `${a.name} と ${b.name}` : `${a.name} と比べる子を選ぶ`), h('button', { class: 'btn sm', onclick: close }, '閉じる')));
        if (!b) {
          const cands = all(w).filter((x) => x.id !== a.id).sort((x, y) => (x.pos === a.pos ? 0 : 1) - (y.pos === a.pos ? 0 : 1) || YA.ovr(y) - YA.ovr(x)).slice(0, 18);
          box.append(h('div', { class: 'plist' }, cands.map((x) => h('button', { class: 'pitem', onclick: () => draw(x) }, h('span', { class: 'pos ' + x.pos }, YA.POS_LABEL[x.main] || x.pos), h('span', { class: 'nm grow' }, x.name), h('span', { class: 'sub' }, `高${x.grade}${x.team}`), h('b', {}, YA.rating(x))))));
          return;
        }
        const rows = YA.compareRows(w, a, b);
        box.append(h('div', { class: 'plist' }, rows.map(([k, x, y]) => {
          const nx = +x, ny = +y;
          const low = k === '疲れ'; // 疲れは少ないほうが良い
          const bx = !isNaN(nx) && !isNaN(ny) && (low ? nx < ny : nx > ny), by = !isNaN(nx) && !isNaN(ny) && (low ? ny < nx : ny > nx);
          return h('div', { class: 'pitem', style: 'cursor:default;gap:6px' }, h('b', { style: `width:80px;text-align:right;${bx ? 'color:#1a9d57' : ''}` }, String(x)), h('span', { class: 'grow', style: 'text-align:center;font-size:11.5px' }, k), h('b', { style: `width:80px;${by ? 'color:#1a9d57' : ''}` }, String(y)));
        })), h('button', { class: 'btn sm', onclick: () => draw(null) }, '別の子と比べる'));
      };
      draw(null);
      return box;
    });
  };

  // ---------- PK戦の順番（大会の引き分けで効く）----------
  YA.pkToggle = function (w, p) {
    w.pkOrder = (w.pkOrder || []).filter((id) => w.players[id]);
    const i = w.pkOrder.indexOf(p.id);
    if (i >= 0) { w.pkOrder.splice(i, 1); return { ok: true, msg: `${p.name}をPK戦のキッカーから外しました` }; }
    if (w.pkOrder.length >= 5) return { ok: false, msg: 'PK戦のキッカーは5人までです' };
    w.pkOrder.push(p.id);
    return { ok: true, msg: `${p.name}をPK戦の${w.pkOrder.length}番目に入れました` };
  };
  YA.pkBonus = function (w) {
    const ks = (w.pkOrder || []).map((id) => w.players[id]).filter(Boolean);
    if (!ks.length) return 0;
    const v = ks.reduce((s, p) => s + ((p.ab['フィニッシュ'] || 8) + (p.ab['冷静さ'] || 8)) / 2, 0) / ks.length;
    return clamp((v - 10) * 0.015, -0.06, 0.08) * (ks.length / 5);
  };

  // ---------- 育成計画・伸び悩みの診断・先輩との比較・師弟・転向 ----------
  YA.setYPlan = function (w, p, k) {
    if (!CATS[k] && k !== '心') return { ok: false, msg: '' };
    if (p.yplan && p.yplan.y === w.year && w.week > 4) return { ok: false, msg: '今年の計画は年度はじめ（4週まで）にしか変えられません' };
    p.yplan = { y: w.year, k, base: k === '心' ? Math.round(p.conf) : catSum(p, k), others: Object.keys(CATS).filter((x) => x !== k).reduce((s, x) => s + catSum(p, x), 0) };
    return { ok: true, msg: `${p.name}の今年の計画：${k}を伸ばす` };
  };
  YA.planCheck = function (w, p) {
    const pl = p.yplan;
    pl.done = true;
    const gain = pl.k === '心' ? Math.round(p.conf) - pl.base : catSum(p, pl.k) - pl.base;
    const ok = pl.k === '心' ? gain >= 8 : gain >= CATS[pl.k]().length * 0.6;
    pl.ok = ok;
    if (YA.addTr) YA.addTr(w, p, ok ? 3 : -1, ok ? '育成計画をやり遂げた' : '');
    YA.noteTier(w, 2, `${p.name}の育成計画「${pl.k}」：${ok ? 'やり遂げた' : '届かなかった'}（${pl.k === '心' ? '自信' : pl.k + 'の能力'} ${gain >= 0 ? '+' : ''}${gain}）`, p.id);
    if (YA.memAdd && (p.star || p.mem)) YA.memAdd(w, p, 'yplan', ok ? 'push' : 'wait', `${pl.k}を伸ばす一年`, { ok });
  };
  const sm0 = YA.staffMult;
  if (sm0) YA.staffMult = function (w, p, a) {
    const m = sm0.apply(this, arguments);
    const pl = p && p.yplan && p.yplan.y === w.year ? p.yplan.k : null;
    return pl && CATS[pl] && CATS[pl]().indexOf(a) >= 0 ? m * 1.04 : m;
  };
  YA.diagnose = function (w, p) {
    const out = [];
    const fA = p.train && p.train.focus;
    const weak = Object.keys(CATS).sort((x, y) => catSum(p, x) / (CATS[x]().length || 1) - catSum(p, y) / (CATS[y]().length || 1))[0];
    if ((p.minsA || 0) < 90 && p.team === 'A' && w.week > 10) out.push('Aにいるのに、試合の出場が少ない（試合の経験で頭の能力が伸びる）');
    if (p.team === 'B' && (p.mins || 0) < 200 && w.week > 10) out.push('Bでも出場が少ない');
    if ((p.fat || 0) >= 65) out.push('疲れが溜まっていて、練習の伸びが落ちている');
    if ((p.conf || 50) < 40) out.push('自信が低く、試合で力を出せていない');
    if (p.state && p.state.k === 'wall') out.push('壁にぶつかっている時期（しばらくは伸びにくい）');
    if (fA && YA.AB_TECH && weak === '技術' && YA.AB_TECH.indexOf(fA) < 0) out.push(`一番弱いのは技術だが、個別の重点は「${fA}」になっている`);
    const role = weak === '体' ? '体コーチ' : weak === '技術' ? '技術コーチ' : '戦術コーチ';
    if (w.club && YA.staffAb(w, role) <= 9) out.push(`一番弱い「${weak}」を見る${role}の腕前が低い`);
    if ((YA.potStars ? YA.potStars(p) : 3) <= 2 && p.grade === 3) out.push('伸びしろ自体が小さくなっている（完成形に近い）');
    return out.length ? out : ['目立った原因は見当たらない。今のまま続けてよさそうだ'];
  };
  YA.seniorCompare = function (w, p) {
    const now = YA.rate(YA.ovr(p));
    const al = (w.alumni || []).filter((a) => a.main === p.main && (a.rHist || []).some((x) => x.g === p.grade));
    if (!al.length) return null;
    const pts = al.map((a) => ({ a, r: a.rHist.find((x) => x.g === p.grade).r })).sort((x, y) => y.r - x.r);
    const above = pts.filter((x) => x.r > now).slice(-1)[0];
    const below = pts.find((x) => x.r <= now);
    const best = pts[0];
    const t = [];
    if (below) t.push(`高${p.grade}のときの${below.a.name}先輩（${below.r}）より上`);
    if (above) t.push(`${above.a.name}先輩（${above.r}、のちに${above.a.club || '…'}）にはまだ届かない`);
    if (best && best !== above && best.r > now) t.push(`同じ位置の最高は${best.a.name}先輩の${best.r}`);
    return `いま${now}。` + t.join('。');
  };
  YA.setMentor = function (w, p, q) {
    w.rel = (w.rel || []).filter((x) => !(x.k === 'mentor' && (x.b === p.id)));
    w.rel.push({ a: q.id, b: p.id, k: p.pos === 'GK' ? 'gk' : 'mentor' });
    if (YA.memAdd) YA.memAdd(w, p, 'mentorset', 'warm', `${q.name}先輩に付いて学ぶ`);
    return { ok: true, msg: `${q.name}を${p.name}の師匠にしました` };
  };
  YA.startConvert = function (w, p, pos) {
    if (!p.apt || p.apt[pos] == null) return { ok: false, msg: '' };
    p.convert = { pos, from: Math.round(p.apt[pos] * 10) / 10, y: w.year, w: w.week };
    return { ok: true, msg: `${p.name}の${YA.POS_LABEL[pos] || pos}への転向練習を始めました（適性${p.convert.from}）` };
  };
  const rw0 = YA.rivalWeek;
  YA.rivalWeek = function (w) {
    const res = rw0 ? rw0.apply(this, arguments) : undefined;
    const key = w.year * 100 + w.week;
    if (w.funcKey === key) return res;
    w.funcKey = key;
    for (const p of all(w)) {
      const c = p.convert;
      if (!c || !p.apt) continue;
      if (p.apt[c.pos] < 17) p.apt[c.pos] = Math.min(17, p.apt[c.pos] + 0.09 + (p.ab['判断'] || 8) * 0.002);
      else if (!c.doneSaid) { c.doneSaid = true; YA.noteTier(w, 2, `${p.name}の${YA.POS_LABEL[c.pos] || c.pos}への転向が身についた（適性${Math.round(p.apt[c.pos])}）`, p.id); }
    }
    YA.planUpdate(w);
    return res;
  };
  // 選手画面（様子）に足す
  const px0 = YA.playerExtras;
  YA.playerExtras = function (w, sel) {
    const base = px0 ? px0.apply(this, arguments) : null;
    const h = H();
    const box = h('div', {});
    if (base) box.append(base);
    const card = (...k) => h('div', { class: 'card', style: 'padding:6px 9px;margin:4px 0;background:#f5f8fd' }, ...k);
    // 比べる・PK
    const pkIdx = (w.pkOrder || []).indexOf(sel.id);
    box.append(card(h('div', { class: 'row', style: 'gap:5px;flex-wrap:wrap' }, h('button', { class: 'btn sm', onclick: () => YA.compareModal(w, sel) }, '他の子と比べる'),
      h('button', { class: 'btn sm' + (pkIdx >= 0 ? ' on' : ''), onclick: () => { const r = YA.pkToggle(w, sel); YA._ui.app.starMsg = r.msg; save(); rer(); } }, pkIdx >= 0 ? `PK戦のキッカー ${pkIdx + 1}番目（外す）` : `PK戦のキッカーに入れる（${(w.pkOrder || []).filter((id) => w.players[id]).length}/5）`))));
    // 育成計画
    const pl = sel.yplan && sel.yplan.y === w.year ? sel.yplan.k : null;
    box.append(card(h('div', { class: 'h' }, '今年の育成計画'), h('div', { class: 'note' }, '1つ選ぶと、その分野の伸びが少し上がります。年度末に、やり遂げたかを答え合わせします（変えられるのは4週まで）。'),
      h('div', { class: 'row', style: 'gap:4px;margin-top:3px' }, ...['体', '技術', '頭', '心'].map((k) => h('button', { class: 'btn sm' + (pl === k ? ' on' : ''), onclick: () => { const r = YA.setYPlan(w, sel, k); YA._ui.app.starMsg = r.msg; save(); rer(); } }, k)))));
    // 診断・先輩との比較
    const sc = YA.seniorCompare(w, sel);
    box.append(card(h('div', { class: 'h' }, 'コーチの見立て（伸び悩みの診断）'), ...YA.diagnose(w, sel).map((t) => h('div', { class: 'note', style: 'color:var(--ink)' }, '・' + t)), sc ? h('div', { class: 'note', style: 'margin-top:3px;color:var(--ink)' }, '先輩との比較：' + sc) : null));
    // 師弟（高1・高2）・転向
    if (sel.grade <= 2) {
      const cur = (w.rel || []).find((x) => (x.k === 'mentor' || x.k === 'gk') && x.b === sel.id);
      const cands = all(w).filter((q) => q.grade === 3 && (q.main === sel.main || q.pos === sel.pos)).slice(0, 4);
      if (cands.length) box.append(card(h('div', { class: 'h' }, '師匠を付ける'), h('div', { class: 'note' }, cur && w.players[cur.a] ? `いまの師匠：${w.players[cur.a].name}` : '同じ位置の高3を付けると、毎週少しずつ頭の能力が伸びます。'),
        h('div', { class: 'row', style: 'gap:4px;flex-wrap:wrap;margin-top:3px' }, ...cands.map((q) => h('button', { class: 'btn sm' + (cur && cur.a === q.id ? ' on' : ''), onclick: () => { const r = YA.setMentor(w, sel, q); YA._ui.app.starMsg = r.msg; save(); rer(); } }, q.name)))));
    }
    const cv = sel.convert;
    const near = Object.entries(sel.apt || {}).filter(([k, v]) => k !== sel.main && v >= 8 && v < 16).sort((a, b) => b[1] - a[1]).slice(0, 4);
    box.append(card(h('div', { class: 'h' }, '位置の転向練習'), cv ? h('div', { class: 'note', style: 'color:var(--ink)' }, `${YA.POS_LABEL[cv.pos] || cv.pos}：適性 ${cv.from} → ${Math.round(sel.apt[cv.pos] * 10) / 10}（17で身につく）`) : h('div', { class: 'note' }, '近い位置の適性を、練習で少しずつ上げます。'),
      h('div', { class: 'row', style: 'gap:4px;flex-wrap:wrap;margin-top:3px' }, ...near.map(([k, v]) => h('button', { class: 'btn sm' + (cv && cv.pos === k ? ' on' : ''), onclick: () => { const r = YA.startConvert(w, sel, k); YA._ui.app.starMsg = r.msg; save(); rer(); } }, `${YA.POS_LABEL[k] || k}（${Math.round(v)}）`)))));
    return box;
  };

  // ---------- 展開ごとの指示（試合の後半、点差で戦い方を切り替える）----------
  YA.condOf = (w) => (w.cond = w.cond || { lose: '', win: '' });
  const M = YA.Match;
  if (M && !M.prototype._condWrapped) {
    const st0 = M.prototype.step;
    M.prototype.step = function () {
      const r = st0.apply(this, arguments);
      try {
        const rules = this.condRules;
        if (rules && this.min >= 60 && !this._condDone) {
          const me = this.home && this.home.isUser ? this.home : this.away && this.away.isUser ? this.away : null;
          if (me) {
            const mine = me === this.home ? this.score.home : this.score.away;
            const theirs = me === this.home ? this.score.away : this.score.home;
            const t = mine < theirs ? rules.lose : mine > theirs ? rules.win : '';
            if (t && YA.TACTICS && YA.TACTICS[t] && me.tactic.type !== t) {
              this.setType(me, t);
              this._condDone = true;
              this.log.push({ minute: this.min, text: `決めておいた指示どおり、戦い方を「${YA.TACTICS[t].name || t}」に切り替えた`, kind: 'info' });
            }
          }
        }
      } catch (er) { /* 試合を止めない */ }
      return r;
    };
    M.prototype._condWrapped = true;
  }
  const tf0 = YA.teamFromWorld;
  if (tf0) YA.teamFromWorld = function (w, which) { const t = tf0.apply(this, arguments); if (which === 'A' && t) t._cond = Object.assign({}, YA.condOf(w)); return t; };
  if (M && !M.prototype._condCtor) {
    // 試合が作られた最初の step で、ユーザーの組の指示を読む
    const st1 = M.prototype.step;
    M.prototype.step = function () {
      if (this.condRules === undefined) { const me = this.home && this.home.isUser ? this.home : this.away && this.away.isUser ? this.away : null; this.condRules = me && me._cond && (me._cond.lose || me._cond.win) ? me._cond : null; }
      return st1.apply(this, arguments);
    };
    M.prototype._condCtor = true;
  }

  // ---------- 戦術理解の内訳・展開ごとの指示（練習の画面）----------
  YA.tacticReport = function (w) {
    const ps = (w.lineupA || []).map((s) => w.players[s.pid]).filter(Boolean);
    const tu = (p) => (p.tu == null ? 40 : p.tu);
    const lines = { GK: [], DF: [], MF: [], FW: [] };
    for (const p of ps) lines[p.pos].push(tu(p));
    const avg = (l) => (l.length ? Math.round(l.reduce((a, b) => a + b, 0) / l.length) : null);
    const low = ps.slice().sort((a, b) => tu(a) - tu(b)).slice(0, 3);
    const weeks = w.tactMem && w.tactic && w.tactMem.type === w.tactic.type ? w.tactMem.weeks : 0;
    return { rep: YA.tactRepOf ? YA.tactRepOf(w) : 1, weeks, lines: Object.fromEntries(Object.entries(lines).map(([k, l]) => [k, avg(l)])), low };
  };
  const vt0 = YA.views && YA.views.train;
  if (vt0) YA.views.train = function (main) {
    vt0.apply(this, arguments);
    const w = YA._ui.app.w;
    if (!w) return;
    const h = H();
    const t = YA.tacticReport(w);
    const c = YA.condOf(w);
    const types = Object.keys(YA.TACTICS || {});
    const sel = (k, label) => { const s = h('select', { style: 'flex:1;padding:4px;min-height:34px;border:1px solid #b9c7de;border-radius:8px;font:inherit' }, h('option', { value: '' }, 'そのまま'), ...types.map((x) => h('option', { value: x, selected: c[k] === x }, (YA.TACTICS[x] && YA.TACTICS[x].name) || x))); s.addEventListener('change', () => { c[k] = s.value; save(); }); return h('div', { class: 'row', style: 'gap:6px;margin-top:3px' }, h('span', { class: 'note', style: 'width:150px' }, label), s); };
    const card = h('div', { class: 'card', style: 'padding:7px 10px;margin-top:6px' },
      h('div', { class: 'h' }, '戦術理解の内訳'),
      h('div', { class: 'note', style: 'color:var(--ink)' }, `戦い方の浸透 ${Math.round(t.rep * 100)}%（同じ戦い方を${t.weeks}週続けている。12週で最大）`),
      h('div', { class: 'note', style: 'color:var(--ink)' }, '線ごとの戦術理解：' + Object.entries(t.lines).filter(([, v]) => v != null).map(([k, v]) => `${k} ${v}`).join('・')),
      h('div', { class: 'note' }, '理解が足りない子：' + t.low.map((p) => `${p.name}（${Math.round(p.tu == null ? 40 : p.tu)}）`).join('・') + '。重点「判断」や試合の出場で上がります。'),
      h('div', { class: 'h', style: 'margin-top:6px' }, '展開ごとの指示（後半、点差で切り替える）'), sel('lose', '負けていたら'), sel('win', '勝っていたら'));
    (main.querySelector('.pbody') || main).append(card);
  };

  // ---------- クラブの記録帳 ----------
  YA.recordBook = function (w) {
    const pool = all(w).filter((p) => p.cs).map((p) => ({ name: p.name, cs: p.cs, now: true })).concat((w.alumni || []).filter((a) => a.cs).map((a) => ({ name: a.name, cs: a.cs, y: a.year })));
    const top = (k) => pool.slice().sort((a, b) => b.cs[k] - a.cs[k]).slice(0, 5).filter((x) => x.cs[k] > 0);
    const res = w.results || [];
    let best = 0, cur = 0;
    for (const r of res) { if (r.gf >= r.ga) { cur++; best = Math.max(best, cur); } else cur = 0; }
    const big = res.slice().sort((a, b) => b.gf - b.ga - (a.gf - a.ga))[0];
    const years = {};
    for (const r of res) { years[r.year] = years[r.year] || { w: 0, n: 0 }; years[r.year].n++; if (r.gf > r.ga) years[r.year].w++; }
    const by = Object.entries(years).sort((a, b) => b[1].w - a[1].w)[0];
    return { goals: top('goals'), apps: top('apps'), assists: top('assists'), unbeaten: best, big, bestYear: by ? { y: by[0], w: by[1].w, n: by[1].n } : null };
  };
  YA.recordBookEl = function (w) {
    const h = H();
    const rb = YA.recordBook(w);
    const list = (title, xs, k, unit) => h('div', { class: 'card', style: 'padding:6px 9px;margin:4px 0' }, h('div', { class: 'h' }, title), ...(xs.length ? xs.map((x, i) => h('div', { class: 'note', style: 'color:var(--ink)' }, `${i + 1}. ${x.name}${x.now ? '（在籍）' : `（${x.y}年目卒）`} ${x.cs[k]}${unit}`)) : [h('div', { class: 'note' }, 'まだ記録がありません')]));
    return h('div', {}, h('div', { class: 'h', style: 'margin-top:8px' }, 'クラブの記録帳（Aの公式戦）'), list('通算得点', rb.goals, 'goals', '点'), list('通算出場', rb.apps, 'apps', '試合'), list('通算アシスト', rb.assists, 'assists', ''),
      h('div', { class: 'card', style: 'padding:6px 9px;margin:4px 0' }, h('div', { class: 'h' }, 'チームの記録'), h('div', { class: 'note', style: 'color:var(--ink)' }, `最長の無敗：${rb.unbeaten}試合`), rb.big ? h('div', { class: 'note', style: 'color:var(--ink)' }, `最大の勝ち：${rb.big.gf}-${rb.big.ga}（${rb.big.year}年目・${rb.big.opp}）`) : null, rb.bestYear ? h('div', { class: 'note', style: 'color:var(--ink)' }, `最多勝の年：${rb.bestYear.y}年目（${rb.bestYear.n}試合で${rb.bestYear.w}勝）`) : null));
  };

  // ---------- 中長期の計画 ----------
  YA.PLAN_DEF = [
    { k: 'tier1', name: '1部に上がる', yrs: 3, cur: (w) => (w.leagueHist || []).some((x) => x.level === 1 && x.year >= (w._pf || 0)) || (w.league && w.league.level === 1) ? 1 : 0, goal: 1 },
    { k: 'pro10', name: 'プロを10人送り出す', yrs: 5, cur: (w, p) => (w.alumni || []).filter((a) => a.status === 'pro' && a.year >= p.from).length, goal: 10 },
    { k: 'nat', name: '日本代表を出す', yrs: 8, cur: (w, p) => (w.alumni || []).filter((a) => a.nat > 0 && a.year >= p.from - 0).length, goal: 1 },
    { k: 'cup', name: '大会で優勝する', yrs: 3, cur: (w, p) => (w.trophies || []).filter((t) => t.year >= p.from && /優勝/.test(t.rank || '優勝')).length, goal: 1 },
    { k: 'hof', name: '殿堂入りを出す', yrs: 10, cur: (w) => (w.alumni || []).filter((a) => a.hof === 'full').length, goal: 1 },
    { k: 'awake5', name: '覚醒の図鑑を5種にする', yrs: 4, cur: (w) => (YA.dexCount ? YA.dexCount(w) : 0), goal: 5 },
  ];
  YA.addPlan = function (w, k) {
    const d = YA.PLAN_DEF.find((x) => x.k === k);
    w.plans = w.plans || [];
    if (!d || w.plans.some((x) => x.k === k && !x.done)) return { ok: false, msg: 'もう立てています' };
    if (w.plans.filter((x) => !x.done).length >= 3) return { ok: false, msg: '計画は同時に3つまでです' };
    w.plans.push({ k, from: w.year, by: w.year + d.yrs - 1, done: false });
    return { ok: true, msg: `計画「${d.name}」を立てました（${d.yrs}年以内）` };
  };
  YA.planUpdate = function (w) {
    for (const p of w.plans || []) {
      if (p.done) continue;
      const d = YA.PLAN_DEF.find((x) => x.k === p.k);
      if (!d) continue;
      p.cur = d.cur(w, p);
      if (p.cur >= d.goal) { p.done = true; p.ok = true; p.y = w.year; if (YA.addRep) YA.addRep(w, 3); if (w.club) w.club.trust = clamp(w.club.trust + 4, 0, 100); YA.noteTier(w, 1, `計画「${d.name}」を達成した（評判 +3・信頼度 +4）`); }
      else if (w.year > p.by) { p.done = true; p.ok = false; p.y = w.year; YA.noteTier(w, 2, `計画「${d.name}」は期限までに届かなかった`); }
    }
  };
  YA.plansCard = function (w) {
    const h = H();
    const act = (w.plans || []).filter((x) => !x.done);
    return h('div', { class: 'card', style: 'padding:9px 11px;margin-bottom:6px' }, h('div', { class: 'h' }, '中長期の計画（3つまで）'),
      ...act.map((p) => { const d = YA.PLAN_DEF.find((x) => x.k === p.k); return h('div', { class: 'note', style: 'color:var(--ink)' }, `・${d.name}：${p.cur || 0}/${d.goal}（${p.by}年目まで）`); }),
      act.length ? null : h('div', { class: 'note' }, '自分で立てる目標です。達成すると評判と信頼度が上がります。'),
      h('div', { class: 'row', style: 'gap:4px;flex-wrap:wrap;margin-top:4px' }, ...YA.PLAN_DEF.filter((d) => !act.some((p) => p.k === d.k)).map((d) => h('button', { class: 'btn sm', onclick: () => { YA.addPlan(w, d.k); save(); rer(); } }, `${d.name}（${d.yrs}年）`))));
  };

  // ---------- 海外移籍の交渉（卒業生が海外へ動くとき）----------
  const at0 = YA.alumniTick;
  YA.alumniTick = function (w) {
    const before = new Map((w.alumni || []).map((a) => [a, !!a.abroad]));
    const r = at0.apply(this, arguments);
    for (const a of w.alumni || []) if (!before.get(a) && a.abroad && before.has(a) && !a.dealt) {
      a.dealt = true;
      w.forced = (w.forced || []).concat([{ id: 'abroaddeal', who: a.name, ay: a.year, pid: null, x: null, week: w.week, year: w.year }]);
    }
    return r;
  };
  YA.EVENTS.push({ id: 'abroaddeal', name: '海外移籍の相談', weight: 0, pick: () => null, text: () => '', opts: [] });
  YA.EVENT_ABOUT = YA.EVENT_ABOUT || {};
  YA.EVENT_ABOUT.abroaddeal = '卒業生が海外のクラブへ移ります。恩師として相談に乗ると、育成基金や本人との絆に響きます。';
  const run = (label, fn) => ({ label, kind: null, run: (w) => { const r = fn(w) || {}; return { line: r.line || '', small: r.small || '' }; } });
  function dealPrep(w, e) {
    const a = (w.alumni || []).find((x) => x.name === e.who && x.year === e.ay);
    const def = YA.EVENTS.find((x) => x.id === 'abroaddeal');
    if (!a || !def) return false;
    def.text = () => `卒業生の${a.name}から電話があった。「${a.club}（${a.league}）から話が来ています。どうしたらいいでしょうか」`;
    def.opts = [
      run('出場できるクラブを選べと助言する', () => { a.bond = Math.min(6, (a.bond == null ? 3 : a.bond) + 1); a.ovr = Math.round((a.ovr + 0.2) * 10) / 10; return { line: '「試合に出られる所にします」', small: '本人との絆 +1' }; }),
      run('移籍金がきちんと入る形にしてもらう', (ww) => { ww.fund = (ww.fund || 0) + 150; ww.fundIn = (ww.fundIn || 0) + 150; return { line: '育成クラブへの分配が、きちんと入ることになった。', small: '育成基金 +150万円' }; }),
      run('本人の夢を応援する', () => { a.bond = Math.min(6, (a.bond == null ? 3 : a.bond) + 1); return { line: '「行ってきます」' }; }),
    ];
    return true;
  }
  const v0 = YA.eventView;
  YA.eventView = function (w, e) { if (e.id === 'abroaddeal' && !dealPrep(w, e)) return null; return v0.apply(this, arguments); };
  const r0 = YA.resolveEvent;
  YA.resolveEvent = function (w, e, idx) { if (e.id === 'abroaddeal') dealPrep(w, e); return r0.apply(this, arguments); };

  // ---------- 卒業生：追う・連絡する・観に行く・年表 ----------
  YA.alumniTimeline = function (w, a) {
    const t = [];
    for (const x of a.rHist || []) t.push({ y: x.y, t: `高${x.g}：総合力${x.r}` });
    for (const m of a.mem || []) if (['chain', 'awake', 'path', 'wall', 'star', 'pitch', 'quit'].indexOf(m.k) >= 0) t.push({ y: m.y, t: `${(YA.MEM_NAME || {})[m.k] || m.k}${m.q ? '：「' + m.q + '」' : ''}` });
    t.push({ y: a.year, t: `卒業 → ${a.club || ''}${a.league ? '（' + a.league + '）' : ''}` });
    for (const s of a.seasons || []) t.push({ y: s.y, t: `${s.club}：${YA.statLine(s, a.pos === 'GK')}${(s.titles || []).length ? '・' + s.titles.join('・') : ''}${(s.awards || []).length ? '・' + s.awards.join('・') : ''}` });
    if (a.hof) t.push({ y: a.hofY || a.year, t: a.hof === 'full' ? '殿堂入り' : '殿堂候補' });
    if (a.retired) t.push({ y: a.retY || w.year, t: '現役を引退' });
    if (a.coached) t.push({ y: w.year, t: 'コーチとして戻った' });
    return t.sort((x, y) => x.y - y.y);
  };
  YA.alumniContact = function (w, a) {
    a.contactY = a.contactY || 0;
    if (a.contactY === w.year) return { ok: false, msg: `${a.name}には今年もう連絡しました` };
    a.contactY = w.year;
    const b0 = a.bond == null ? 3 : a.bond;
    if (b0 < 6) a.bond = b0 + (b0 <= 2 ? 1 : YA.hash(a.name + w.year) % 2);
    const line = b0 <= 1 ? '電話はつながったが、話は短かった。' : a.retired ? '「今は地元で子どもに教えてます」と、うれしそうに話してくれた。' : (a.seasons || []).slice(-1)[0] && (a.seasons || []).slice(-1)[0].apps < 8 ? '「出られなくて、正直しんどいです。でも、監督の声を聞けてよかった」' : '「監督、元気ですか。こっちは順調です」';
    return { ok: true, msg: `${a.name}に電話した。${line}` };
  };
  YA.alumniWatch = function (w, a) {
    if (a.watchY === w.year) return { ok: false, msg: `${a.name}の試合は今年もう観に行きました` };
    if (a.retired || a.status === 'left') return { ok: false, msg: '現役ではありません' };
    a.watchY = w.year;
    const s = (a.seasons || []).slice(-1)[0];
    const fan = all(w).filter((p) => p.star && p.pos === a.pos);
    for (const p of fan) conf(p, 3);
    const play = !s ? 'ベンチから声を出していた' : s.goals >= 5 ? 'ゴール前で何度も相手を脅かしていた' : s.apps >= 20 ? '中心選手として90分走り切った' : '途中から出て、短い時間で見せ場を作った';
    return { ok: true, msg: `${a.club}の試合を観に行った。${a.name}は${play}。${fan.length ? `一緒に行った★の子${fan.length}人が、目を輝かせていた（自信 +3）` : ''}` };
  };
  // 卒業生の成績の表（2026-11-15「バロンドールとかの要素・ゴール数やアシスト、出場数」）。GK は得点・アシストの代わりに完封
  YA.alumniStats = function (w, a) {
    const h = H();
    const ss = (a.seasons || []).filter((x) => x.apps != null);
    if (!ss.length) return null;
    const gk = a.pos === 'GK';
    const aw = (a.awards || []).map((x) => x.name);
    const n = (re) => aw.filter((x) => re.test(x)).length;
    const big = [['バロンドール', n(/^バロンドール$/)], ['ゴールデンシュー', n(/ゴールデンシュー/)], ['ヤシン・トロフィー', n(/ヤシン/)], ['コパ・トロフィー', n(/コパ・トロフィー/)], ['得点王', n(/得点王$/)], ['アシスト王', n(/アシスト王$/)], ['最優秀GK', n(/最優秀GK$/)], ['年間MVP', n(/年間MVP$/)], ['ベストイレブン', n(/ベストイレブン$/)]].filter((x) => x[1]);
    const cell = (v, wd) => h('span', { style: `width:${wd || 38}px;text-align:right;flex:none` }, v);
    const head = (v, wd) => h('span', { style: `width:${wd || 38}px;text-align:right;flex:none;font-size:10px;color:var(--sub);font-weight:800` }, v);
    return h('div', {},
      h('div', { class: 'h', style: 'margin-top:4px' }, '成績'),
      h('div', { class: 'row', style: 'flex-wrap:wrap;gap:4px' },
        h('span', { class: 'chip trait' }, `出場 ${a.apps || 0}`),
        gk ? h('span', { class: 'chip trait' }, `完封 ${a.cleans || 0}`) : h('span', { class: 'chip trait' }, `得点 ${a.goals || 0}`),
        gk ? null : h('span', { class: 'chip trait' }, `アシスト ${a.assists || 0}`),
        h('span', { class: 'chip gray' }, `タイトル ${(a.titles || []).length}`),
        a.nat ? h('span', { class: 'chip gray' }, `日本代表 ${a.nat}回${a.natGoals ? '・' + a.natGoals + '得点' : ''}`) : null,
        a.bdBest ? h('span', { class: 'chip pers' }, a.bdBest === 1 ? `バロンドール ${n(/^バロンドール$/)}回` : `バロンドール 最高${a.bdBest}位`) : null,
        ...big.filter((x) => x[0] !== 'バロンドール').map((x) => h('span', { class: 'chip pers' }, x[0] + (x[1] > 1 ? ` ×${x[1]}` : '')))),
      h('div', { class: 'plist', style: 'margin-top:4px' },
        h('div', { class: 'pitem', style: 'cursor:default;background:none;gap:4px' }, h('span', { style: 'width:44px;flex:none;font-size:10px;color:var(--sub);font-weight:800' }, '年'), h('span', { class: 'grow', style: 'font-size:10px;color:var(--sub);font-weight:800' }, 'クラブ'), head('出場'), ...(gk ? [head('完封')] : [head('得点'), head('アシスト', 44)]), head('バロンドール', 70)),
        ss.slice().reverse().map((x) => h('div', { class: 'pitem', style: 'cursor:default;gap:4px;font-size:11.5px' },
          h('span', { class: 'sub', style: 'width:44px;flex:none' }, `${x.y}年目`),
          h('span', { class: 'grow', style: 'min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap' }, `${x.club}（${x.league}）`),
          cell(x.apps), ...(gk ? [cell(x.cleans != null ? x.cleans : '―')] : [cell(x.goals), cell(x.assists != null ? x.assists : '―', 44)]),
          cell(x.bd ? (x.bd === 1 ? '受賞' : x.bd + '位') : '―', 70)))));
  };
  // 選手の経歴をまとめたページ（2026-11-15「選手の経歴をまとめたページも欲しい」）。
  // ユース時代（高1〜高3の総合力・Aの公式戦の成績・覚醒・特性）→ 卒業 → プロの年ごとの成績と市場価値 → 移籍と移籍金 → タイトルと賞 → 思い出
  YA.careerPage = function (w, a) {
    const h = H();
    const gk = a.pos === 'GK';
    const count = (list) => { const m = {}; for (const x of list || []) m[x.name] = (m[x.name] || 0) + 1; return Object.entries(m).map(([k, n]) => k + (n > 1 ? ` ×${n}` : '')); };
    const sec = (t, ...kids) => h('div', { style: 'display:flex;flex-direction:column;gap:4px;margin-top:6px' }, h('div', { class: 'h' }, t), ...kids);
    const th = (v, wd, left) => h('span', { style: `width:${wd}px;flex:none;text-align:${left ? 'left' : 'right'};font-size:10px;color:var(--sub);font-weight:800` }, v);
    const td = (v, wd, left) => h('span', { style: `width:${wd}px;flex:none;text-align:${left ? 'left' : 'right'}` }, v);
    const ss = (a.seasons || []).filter((x) => x.apps != null);
    const moves = a.moves || [];
    const val = YA.marketValue ? YA.marketValue(a) : 0;
    const status = a.status === 'pro' ? (a.retired ? '引退' : `${a.club}（${a.league}）`) : a.status === 'univ' ? `${a.club}（大学）` : a.status === 'left' ? '在学中に退団' : `${a.club || '社会人'}`;
    const first = a.status === 'pro' ? (moves.length ? moves[0].from : a.club) : a.club || '社会人';
    YA._v.modal((close) => h('div', { class: 'sheet-in', style: 'flex:none;align-self:center;margin:auto;width:min(860px,98%);max-height:96%;padding:12px;gap:4px;overflow:auto' },
      h('div', { class: 'row', style: 'gap:6px' },
        h('span', { class: 'pos ' + a.pos }, (YA.POS_LABEL && YA.POS_LABEL[a.main]) || a.pos),
        h('b', { style: 'font-size:16px' }, a.name + (a.star ? ' ★' : '')),
        h('span', { class: 'sub grow' }, `${a.year}年目卒・${a.age != null ? a.age + '歳' : ''}・いま ${status}`),
        h('button', { class: 'btn sm', onclick: close }, '閉じる')),
      h('div', { class: 'note' }, `総合力 ${YA.rate(a.ovr)}（${YA.levelOf ? YA.levelOf(YA.rate(a.ovr)) : ''}）` + (a.status === 'pro' && !a.retired ? `・市場価値 ${YA.yen(val)}` : '') + (a.valueMax ? `・最高 ${YA.yen(a.valueMax)}` : '') + (a.hof ? `・${a.hof === 'full' ? '殿堂入り' : '殿堂候補'}` : '')),
      h('div', { class: 'row', style: 'flex-wrap:wrap;gap:4px' },
        h('span', { class: 'chip trait' }, `出場 ${a.apps || 0}`),
        gk ? h('span', { class: 'chip trait' }, `完封 ${a.cleans || 0}`) : h('span', { class: 'chip trait' }, `得点 ${a.goals || 0}`),
        gk ? null : h('span', { class: 'chip trait' }, `アシスト ${a.assists || 0}`),
        h('span', { class: 'chip gray' }, `タイトル ${(a.titles || []).length}`),
        h('span', { class: 'chip gray' }, `移籍 ${a.transfers || 0}回・移籍金の合計 ${YA.yen(a.feeTotal || 0)}`),
        a.nat ? h('span', { class: 'chip gray' }, `日本代表 ${a.nat}回${a.natGoals ? '・' + a.natGoals + '得点' : ''}`) : null,
        a.bdBest ? h('span', { class: 'chip pers' }, a.bdBest === 1 ? `バロンドール ${(a.awards || []).filter((x) => x.name === 'バロンドール').length}回` : `バロンドール 最高${a.bdBest}位`) : null),
      sec('ユース時代',
        h('div', { class: 'note' }, [
          (a.rHist || []).length ? '総合力 ' + a.rHist.map((x) => `高${x.g} ${x.r}`).join(' → ') + ` → 卒業時 ${YA.rate(a.ovr0 || a.ovr)}` : `卒業時の総合力 ${YA.rate(a.ovr0 || a.ovr)}`,
          a.cs ? `Aの公式戦 ${a.cs.apps}試合` + (gk ? '' : `・${a.cs.goals}得点・${a.cs.assists}アシスト`) : null,
          a.form ? `覚醒：${a.form}` : null,
          a.youthCaps ? `年代別の代表 ${a.youthCaps}回` : null,
          a.note ? `卒業：${a.note}` : null,
        ].filter(Boolean).join('　／　')),
        (a.traits || []).length ? h('div', { class: 'row', style: 'flex-wrap:wrap;gap:3px' }, a.traits.map((t) => h('span', { class: 'chip trait' }, t))) : null),
      sec('年ごとの成績',
        ss.length ? h('div', { style: 'overflow-x:auto' }, h('div', { class: 'plist', style: 'min-width:640px' },
          h('div', { class: 'pitem', style: 'cursor:default;background:none;gap:4px' }, th('年', 44, 1), th('年齢', 32, 1), h('span', { class: 'grow', style: 'font-size:10px;color:var(--sub);font-weight:800' }, 'クラブ（リーグ）'), th('出場', 32), ...(gk ? [th('完封', 32), th('', 40)] : [th('得点', 32), th('アシスト', 40)]), th('市場価値', 64), th('タイトル・賞', 180, 1)),
          ss.slice().reverse().map((x) => h('div', { class: 'pitem', style: 'cursor:default;gap:4px;font-size:11px' },
            td(`${x.y}年目`, 44, 1), td(`${x.age}歳`, 32, 1),
            h('span', { class: 'grow', style: 'min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap' }, `${x.club}（${x.league}）`),
            td(x.apps, 32), ...(gk ? [td(x.cleans != null ? x.cleans : '―', 32), td('', 40)] : [td(x.goals, 32), td(x.assists != null ? x.assists : '―', 40)]),
            td(x.value ? YA.yen(x.value) : '―', 64),
            h('span', { style: 'width:180px;flex:none;font-size:10px' }, (x.titles || []).concat(x.awards || []).join('・') || '―')))))
          : h('div', { class: 'note' }, 'まだ記録はありません。卒業から1年たつと、ここに年ごとの成績が並びます。')),
      sec('移籍の歴史',
        h('div', { class: 'plist' },
          h('div', { class: 'pitem', style: 'cursor:default;gap:6px;font-size:11px' }, td(`${a.year}年目`, 44, 1), h('span', { class: 'grow' }, `ユース → ${first}${a.status === 'univ' ? '（大学）' : ''}`), td(a.status === 'pro' || moves.length ? 'プロ契約' : '―', 90)),
          moves.map((m) => h('div', { class: 'pitem', style: 'cursor:default;gap:6px;font-size:11px' }, td(`${m.y}年目`, 44, 1), h('span', { class: 'grow', style: 'min-width:0' }, `${m.from} → ${m.to}（${m.toLg}）${m.abroad ? '・海外' : ''}`), h('b', { style: 'width:90px;flex:none;text-align:right' }, YA.yen(m.fee))))),
        moves.length ? h('div', { class: 'note' }, `連帯貢献金（育成基金へ）の合計 ${YA.yen(moves.reduce((t, m) => t + (m.share || 0), 0))}`) : h('div', { class: 'note' }, (a.transfers || 0) > 0 ? '前の移籍は記録の形が古く、移籍金が残っていません。' : 'まだ移籍していません。')),
      (a.titles || []).length || (a.awards || []).length ? sec('タイトルと賞',
        (a.titles || []).length ? h('div', { class: 'row', style: 'flex-wrap:wrap;gap:4px' }, count(a.titles).map((x) => h('span', { class: 'chip trait' }, x))) : null,
        (a.awards || []).length ? h('div', { class: 'row', style: 'flex-wrap:wrap;gap:4px' }, count(a.awards).map((x) => h('span', { class: 'chip pers' }, x))) : null) : null,
      (a.mem || []).some((m) => m.q) ? sec('ユースでの思い出', h('div', { class: 'plist' }, a.mem.filter((m) => m.q).slice(0, 6).map((m) => h('div', { class: 'pitem', style: 'cursor:default;gap:6px;font-size:11px' }, td(`${m.y}年目`, 44, 1), h('span', { class: 'grow' }, `${(YA.MEM_NAME || {})[m.k] || ''}：「${m.q}」`))))) : null));
  };
  YA.alumniModal = function (w, a) {
    if (YA.fixClubNames) YA.fixClubNames(w);
    const h = H();
    YA._v.modal((close) => {
      const box = h('div', { class: 'sheet-in', style: 'flex:none;align-self:center;margin:auto;width:min(640px,96%);padding:12px;gap:6px;max-height:92%;overflow:auto' });
      const msg = h('div', { class: 'note', style: 'color:var(--ink)' });
      const draw = () => {
        box.replaceChildren(
          h('div', { class: 'row' }, h('div', { class: 'h grow' }, `${a.name}（${a.year}年目卒${a.age ? '・' + a.age + '歳' : ''}）`), h('button', { class: 'btn sm', onclick: close }, '閉じる')),
          h('div', { class: 'note' }, `${a.club || ''}${a.league ? '（' + a.league + (YA.clubStr && YA.clubStr(a.club, w) != null ? '・クラブの強さ ' + YA.clubStr(a.club, w) : '') + '）' : ''}・本人 ${YA.rate(a.ovr)}・通算${YA.statLine(a, a.pos === 'GK')}${a.bdBest ? '・バロンドール最高' + a.bdBest + '位' : ''}・絆 ${a.bond == null ? '-' : a.bond}/6`),
          h('div', { class: 'row', style: 'gap:5px;flex-wrap:wrap;margin:4px 0' },
            h('button', { class: 'btn sm' + (a.fav ? ' on' : ''), onclick: () => { a.fav = !a.fav; save(); draw(); } }, a.fav ? '★ 追っている（外す）' : '☆ この子を追う'),
            h('button', { class: 'btn sm', onclick: () => { const r = YA.alumniContact(w, a); msg.textContent = r.msg; save(); draw(); } }, '連絡する（年1回）'),
            h('button', { class: 'btn sm', onclick: () => { const r = YA.alumniWatch(w, a); msg.textContent = r.msg; save(); draw(); } }, '試合を観に行く（年1回）'),
            h('button', { class: 'btn sm pri', onclick: () => YA.careerPage(w, a) }, '経歴をまとめて見る')),
          msg,
          YA.alumniStats(w, a),
          (a.news || []).length ? h('div', { class: 'h', style: 'margin-top:4px' }, '最近の知らせ') : null,
          (a.news || []).length ? h('div', { class: 'plist' }, a.news.slice(-8).reverse().map((x) => h('div', { class: 'pitem', style: 'cursor:default;gap:6px' }, h('span', { class: 'sub', style: 'width:72px;flex:none' }, `${x.y}年目 ${x.w}週`), h('span', {}, x.t)))) : null,
          h('div', { class: 'h', style: 'margin-top:4px' }, 'その後の年表'),
          h('div', { class: 'plist' }, YA.alumniTimeline(w, a).map((x) => h('div', { class: 'pitem', style: 'cursor:default;gap:6px' }, h('span', { class: 'sub', style: 'width:54px' }, `${x.y}年目`), h('span', { class: 'grow', style: 'font-size:11.5px' }, x.t)))));
      };
      draw();
      return box;
    });
  };
  // 追っている子は、毎年の成績を必ず知らせる
  const at1 = YA.alumniTick;
  YA.alumniTick = function (w) {
    const r = at1.apply(this, arguments);
    for (const a of (w.alumni || []).filter((x) => x.fav && !x.retired)) {
      const s = (a.seasons || []).slice(-1)[0];
      if (s && s.y === w.year) YA.noteTier(w, 2, `追っている${a.name}：${s.club}で${YA.statLine(s, a.pos === 'GK')}${(s.titles || []).length ? '・' + s.titles.join('・') : ''}`);
    }
    return r;
  };

  // ---------- 用語集 ----------
  YA.GLOSSARY = [
    ['総合力', '能力をまとめた数字（0〜200）。100がプロ入りの目安、155が日本代表級'],
    ['伸びしろ（★）', 'コーチの見立てで、どこまで伸びそうか。見る目が良いほど確か'],
    ['★注目', '特に目をかける子。高1にだけ、入団から4週のうちに決める。覚醒するのは★の子だけ'],
    ['覚醒の鍵', '★の子が化けるためのきっかけ。そろうと覚醒し、能力と特別な特性が付く'],
    ['覚醒の図鑑', '目覚めた形の一覧。接し方（寄り添う・厳しく・背中を押す・任せる）で出やすい形が変わる'],
    ['信頼（5段階）', '★の子との信頼。高いほど鍵のヒントが早く見え、卒業後の絆も深くなる'],
    ['絆', '卒業生との結びつき（0〜6）。高いと便りが温かく、コーチとして戻ったり、中学生を紹介したりする'],
    ['事情', 'その子の背景。面談や出来事で少しずつ分かり、出来事の中身が変わる'],
    ['続き物', '2話にわたる出来事。どう向き合ったかで結末が変わる。条件がそろうと思わぬ結末も'],
    ['浸透', '同じ戦い方を続けるほど、チームがつまみどおりに動く（12週で最大）'],
    ['役割と任務', '選手ごとの動き方。役割は何をするか、任務は攻撃・守備のどちらに重心を置くか'],
    ['適性', 'ポジションごとの向き不向き（1〜20）。◎17以上・○14以上・△10以上'],
    ['連帯貢献金', '卒業生が移籍したとき、育てたクラブに入るお金。半分が育成基金に貯まる'],
    ['育成基金', 'クラブの予算とは別のお金。施設・遠征・スカウトに使い道を自分で決める'],
    ['信頼度（クラブ）', 'クラブからの信頼。高いとスタッフや予算の配分を自分で決められる'],
    ['方針と流儀', '年度はじめに決める6つの軸。3年以上貫くと「流儀」になり、教え子の指導者が受け継ぐ'],
    ['殿堂', '大きな活躍をした卒業生。条件で候補（銀）、引退のときに生涯の成績で正式に入る（金）'],
    ['系譜', '育てた子のつながり。卒業生の子や、教え子の教え子も系譜に入る'],
  ];
  YA.glossaryEl = function () {
    const h = H();
    return h('div', {}, h('div', { class: 'h' }, '用語集'), h('div', { class: 'plist', style: 'margin-top:4px' }, YA.GLOSSARY.map(([k, v]) => h('div', { class: 'pitem', style: 'cursor:default;align-items:flex-start;gap:6px' }, h('b', { style: 'width:110px;flex:none' }, k), h('span', { class: 'grow', style: 'font-size:11.5px' }, v)))));
  };
})();
