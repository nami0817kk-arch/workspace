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
      // 育った分は p.aptX に残す（毎週の YA.refreshApt が適性を作り直しても消えないように。2026-11-20 直し）
      if (p.apt[c.pos] < 17) { p.aptX = p.aptX || {}; p.aptX[c.pos] = (p.aptX[c.pos] || 0) + (0.09 + (p.ab['判断'] || 8) * 0.002) * (YA.adaptK ? YA.adaptK(p) : 1); YA.refreshApt(p); }
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
    const card = (...k) => h('div', { class: 'card', 'data-grp': 'grow', style: 'padding:6px 9px;margin:4px 0;background:#f5f8fd' }, ...k);
    // 比べる・PK・名前は選手の画面の右上「…」へ移した（2026-11-18 ユーザビリティ11）。下の4つは「育て方」の小タブに出す
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
    // 右の欄（スクロールする）に入れる。main に直接足すと、曜日の欄に重なって描かれていた（2026-11-16 画面の点検）
    card.style.flex = 'none';
    (main.querySelector('[data-train-right]') || main.querySelector('.pbody') || main).append(card);
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
  YA.EVENT_ABOUT.abroaddeal = '卒業生の海外移籍が決まりました。送り出すときのひとことが、育成基金や本人との絆に響きます。';
  const run = (label, fn) => ({ label, kind: null, run: (w) => { const r = fn(w) || {}; return { line: r.line || '', small: r.small || '' }; } });
  function dealPrep(w, e) {
    const a = (w.alumni || []).find((x) => x.name === e.who && x.year === e.ay);
    const def = YA.EVENTS.find((x) => x.id === 'abroaddeal');
    if (!a || !def) return false;
    // 移籍は年度末に決まっている（この出来事はそのあと）。決まったあとの電話にする（2026-11-16「話が来ています」と食い違っていた）
    def.text = () => `卒業生の${a.name}から電話があった。「${a.club}（${a.league}）への移籍が決まりました。行く前に、ひとこともらえますか」`;
    def.opts = [
      run('「まず試合に出ることだけ考えろ」と送り出す', () => { a.bond = Math.min(6, (a.bond == null ? 3 : a.bond) + 1); a.ovr = Math.round((a.ovr + 0.2) * 10) / 10; return { line: '「はい。向こうで一から見せて、出られるようにします」', small: '本人との絆 +1' }; }),
      run('育成クラブへの分配をきちんと確かめておく', (ww) => { ww.fund = (ww.fund || 0) + 150; ww.fundIn = (ww.fundIn || 0) + 150; return { line: '育成クラブへの分配が、きちんと入ることになった。', small: '育成基金 +150万円' }; }),
      run('「夢をかなえてこい」と背中を押す', () => { a.bond = Math.min(6, (a.bond == null ? 3 : a.bond) + 1); return { line: '「行ってきます」' }; }),
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
    // 卒業の行は最初の行き先（2026-11-17 点検：今のクラブが出ていて、大学経由も消えていた）
    const c0 = a.club0 != null ? a.club0 : a.club, l0 = a.club0 != null ? a.league0 : a.league;
    t.push({ y: a.year, t: `卒業 → ${c0 || ''}${l0 ? '（' + l0 + '）' : ''}` });
    for (const m of a.moves || []) if (m.join) t.push({ y: m.y, t: `大学 → ${m.to}（${m.toLg}）でプロに` });
    for (const s of a.seasons || []) t.push({ y: s.y, t: `${s.club}：${YA.statLine(s, a.pos === 'GK')}${(s.titles || []).length ? '・' + s.titles.join('・') : ''}${(s.awards || []).length ? '・' + s.awards.join('・') : ''}` });
    if (a.hof) t.push({ y: a.hofY || a.year, t: a.hof === 'full' ? '殿堂入り' : '殿堂候補' });
    if (a.retired) t.push({ y: a.retY || w.year, t: a.quit ? 'サッカーをやめた' : '現役を引退' });
    if (a.coachY) t.push({ y: a.coachY, t: 'コーチとして戻った' }); // 雇った年だけ（市場に並んだ・断ったときは出さない）
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
    const head = (v, wd) => h('span', { style: `width:${wd || 38}px;text-align:right;flex:none;font-size:11px;color:var(--sub);font-weight:800` }, v);
    return h('div', {},
      h('div', { class: 'h', style: 'margin-top:4px' }, '成績'),
      h('div', { class: 'row', style: 'flex-wrap:wrap;gap:4px' },
        h('span', { class: 'chip trait' }, `出場 ${a.apps || 0}`),
        gk ? h('span', { class: 'chip trait' }, `完封 ${a.cleans || 0}`) : h('span', { class: 'chip trait' }, `得点 ${a.goals || 0}`),
        gk ? null : h('span', { class: 'chip trait' }, `アシスト ${a.assists || 0}`),
        h('span', { class: 'chip gray' }, `タイトル ${(a.titles || []).length}`),
        a.nat ? h('span', { class: 'chip gray' }, `日本代表 ${a.caps != null ? a.caps : a.nat * 5}試合${a.natGoals ? '・' + a.natGoals + '得点' : ''}`) : null,
        a.bdBest ? h('span', { class: 'chip pers' }, a.bdBest === 1 ? `バロンドール ${n(/^バロンドール$/)}回` : `バロンドール 最高${a.bdBest}位`) : null,
        ...big.filter((x) => x[0] !== 'バロンドール').map((x) => h('span', { class: 'chip pers' }, x[0] + (x[1] > 1 ? ` ×${x[1]}` : '')))),
      h('div', { class: 'plist', style: 'margin-top:4px' },
        h('div', { class: 'pitem', style: 'cursor:default;background:none;gap:4px' }, h('span', { style: 'width:44px;flex:none;font-size:11px;color:var(--sub);font-weight:800' }, '年'), h('span', { class: 'grow', style: 'font-size:11px;color:var(--sub);font-weight:800' }, 'クラブ'), head('出場'), ...(gk ? [head('完封')] : [head('得点'), head('アシスト', 44)]), head('バロンドール', 70)),
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
    const th = (v, wd, left) => h('span', { style: `width:${wd}px;flex:none;text-align:${left ? 'left' : 'right'};font-size:11px;color:var(--sub);font-weight:800` }, v);
    const td = (v, wd, left) => h('span', { style: `width:${wd}px;flex:none;text-align:${left ? 'left' : 'right'}` }, v);
    const ss = (a.seasons || []).filter((x) => x.apps != null);
    const moves = a.moves || [];
    const val = YA.marketValue ? YA.marketValue(a) : 0;
    const status = a.status === 'pro' ? (a.retired ? YA.retireWord(a) : `${a.club}（${a.league}）`) : a.status === 'univ' ? `${a.club}（大学）` : a.status === 'left' ? '在学中に退団' : `${a.club || '社会人'}`;
    // 卒業して最初に入ったところ（a.club0）。古い保存は最初の移籍の元から
    const first = a.club0 != null ? a.club0 || '社会人' : a.status === 'pro' ? (moves.length ? moves[0].from : a.club) : a.club || '社会人';
    const firstLg = a.club0 != null ? a.league0 : moves.length ? moves[0].fromLg : a.league;
    const firstPro = !/大学|社会人/.test(firstLg || '') && (a.status === 'pro' || moves.length > 0);
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
        a.nat ? h('span', { class: 'chip gray' }, `日本代表 ${a.caps != null ? a.caps : a.nat * 5}試合${a.natGoals ? '・' + a.natGoals + '得点' : ''}`) : null,
        a.bdBest ? h('span', { class: 'chip pers' }, a.bdBest === 1 ? `バロンドール ${(a.awards || []).filter((x) => x.name === 'バロンドール').length}回` : `バロンドール 最高${a.bdBest}位`) : null),
      YA.alumniStoryEl(w, a),
      sec('ユース時代',
        h('div', { class: 'note' }, [
          (a.rHist || []).length ? '総合力 ' + a.rHist.map((x) => `高${x.g} ${x.r}`).join(' → ') + ` → 卒業時 ${YA.rate(a.ovr0 || a.ovr)}` : `卒業時の総合力 ${YA.rate(a.ovr0 || a.ovr)}`,
          a.cs ? `Aの公式戦 ${a.cs.apps}試合` + (gk ? '' : `・${a.cs.goals}得点・${a.cs.assists}アシスト`) : null,
          a.form ? `覚醒：${a.form}` : null,
          a.youthCaps ? `年代別の代表 ${a.youthCaps}回` : null,
          a.note0 || a.note ? `卒業：${a.note0 || a.note}` : null,
        ].filter(Boolean).join('　／　')),
        (a.traits || []).length ? h('div', { class: 'row', style: 'flex-wrap:wrap;gap:3px' }, a.traits.map((t) => h('span', { class: 'chip trait' }, t))) : null),
      sec('年ごとの成績',
        ss.length ? h('div', { style: 'overflow-x:auto' }, h('div', { class: 'plist', style: 'min-width:640px' },
          h('div', { class: 'pitem', style: 'cursor:default;background:none;gap:4px' }, th('年', 44, 1), th('年齢', 32, 1), h('span', { class: 'grow', style: 'font-size:11px;color:var(--sub);font-weight:800' }, 'クラブ（リーグ）'), th('出場', 32), ...(gk ? [th('完封', 32), th('', 40)] : [th('得点', 32), th('アシスト', 40)]), th('市場価値', 64), th('タイトル・賞', 180, 1)),
          ss.slice().reverse().map((x) => h('div', { class: 'pitem', style: 'cursor:default;gap:4px;font-size:11px' },
            td(`${x.y}年目`, 44, 1), td(`${x.age}歳`, 32, 1),
            h('span', { class: 'grow', style: 'min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap' }, `${x.club}（${x.league}）`),
            td(x.apps, 32), ...(gk ? [td(x.cleans != null ? x.cleans : '―', 32), td('', 40)] : [td(x.goals, 32), td(x.assists != null ? x.assists : '―', 40)]),
            td(x.value ? YA.yen(x.value) : '―', 64),
            h('span', { style: 'width:180px;flex:none;font-size:11px' }, (x.titles || []).concat(x.awards || []).join('・') || '―')))))
          : h('div', { class: 'note' }, 'まだ記録はありません。卒業から1年たつと、ここに年ごとの成績が並びます。')),
      sec('移籍の歴史',
        h('div', { class: 'plist' },
          h('div', { class: 'pitem', style: 'cursor:default;gap:6px;font-size:11px' }, td(`${a.year}年目`, 44, 1), h('span', { class: 'grow' }, `ユース → ${first}${/大学/.test(firstLg || '') ? '（大学）' : ''}`), td(firstPro ? 'プロ契約' : '―', 90)),
          moves.map((m) => h('div', { class: 'pitem', style: 'cursor:default;gap:6px;font-size:11px' }, td(`${m.y}年目`, 44, 1), h('span', { class: 'grow', style: 'min-width:0' }, `${m.from} → ${m.to}（${m.toLg}）${m.join ? '・加入' : m.abroad ? '・海外' : ''}`), h('b', { style: 'width:90px;flex:none;text-align:right' }, m.join ? 'プロ契約・0円' : YA.yen(m.fee))))),
        moves.length ? h('div', { class: 'note' }, `連帯貢献金の合計 ${YA.yen(moves.reduce((t, m) => t + (m.share || 0), 0))}（国をまたぐ移籍だけ。半分が育成基金へ）`) : h('div', { class: 'note' }, (a.transfers || 0) > 0 ? '前の移籍は記録の形が古く、移籍金が残っていません。' : 'まだ移籍していません。')),
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
          h('div', { class: 'note' }, `${a.club || ''}${a.league ? '（' + a.league + (YA.clubStr && YA.clubStr(a.club, w) != null ? '・クラブの強さ ' + YA.clubStr(a.club, w) : '') + '）' : ''}・本人 ${YA.rate(a.ovr)}・通算${YA.statLine(a, a.pos === 'GK')}${a.bdBest ? '・バロンドール最高' + a.bdBest + '位' : ''}${a.bond == null ? '' : `・絆 ${a.bond}/6`}`),
          h('div', { class: 'row', style: 'gap:5px;flex-wrap:wrap;margin:4px 0' },
            h('button', { class: 'btn sm' + (a.fav ? ' on' : ''), onclick: () => { a.fav = !a.fav; save(); draw(); } }, a.fav ? '★ 追っている（外す）' : '☆ この子を追う'),
            h('button', { class: 'btn sm', onclick: () => { const r = YA.alumniContact(w, a); msg.textContent = r.msg; save(); draw(); } }, '連絡する（年1回）'),
            h('button', { class: 'btn sm', onclick: () => { const r = YA.alumniWatch(w, a); msg.textContent = r.msg; save(); draw(); } }, '試合を観に行く（年1回）'),
            h('button', { class: 'btn sm pri', onclick: () => YA.careerPage(w, a) }, '経歴をまとめて見る')),
          msg,
          YA.alumniStoryEl(w, a),
          YA.alumniStats(w, a),
          (a.news || []).length ? h('div', { class: 'h', style: 'margin-top:4px' }, '最近の知らせ') : null,
          (a.news || []).length ? h('div', { class: 'plist' }, a.news.slice(-8).reverse().map((x) => h('div', { class: 'pitem', style: 'cursor:default;gap:6px' }, h('span', { class: 'sub', style: 'width:104px;flex:none' }, YA.ywName(x.y, x.w)), h('span', {}, x.t)))) : null,
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
  // ---------- やり残し（2026-11-18「操作を忘れることとかあるので、直したい」）----------
  // 期限のある操作を、期限の近い順に並べる。hard＝この週を過ぎると決められない（「次の週へ」の前に一度止める）
  YA.todoList = function (w) {
    if (!w || w.retired || !w.players) return [];
    const out = [];
    const wk = w.week;
    const monthEnds = wk < YA.WEEKS && YA.monthIdx(wk + 1) !== YA.monthIdx(wk);
    const toPlayer = (id, pTab) => (app) => { app.tab = 'players'; if (id) app.pSel = id; app.pTab = pTab; };
    const toClub = (ct) => (app) => { app.tab = 'club'; app.ct = ct; };
    // ★注目：高1に、入団から4週のうち。過ぎると付けられない
    if (YA.STAR_WEEKS && wk <= YA.STAR_WEEKS) {
      const n = YA.starsIn(w, 1).length;
      const nx = YA.starPick(w, 1)[0];
      if (n < YA.STAR_MAX && nx) out.push({ id: 'star', tab: 'players', go: toPlayer(nx.id, 'info'), t: `高1の★注目を決める（${n}/${YA.STAR_MAX}人）`, left: YA.STAR_WEEKS - wk, hard: true, after: '★は付けられなくなり、空いた枠はこの学年のあいだ空いたままです' });
    }
    const S = w.scouting;
    if (S) {
      const wn = YA.scoutWindow(w);
      const held = (k) => S.cands.filter((c) => (!k || c.kind === k) && (c.status === 'signed' || c.status === 'offered')).length;
      const seats = `来年の高1 ${held()}/12人`;
      if (wn.int && held() < 12) out.push({ id: 'int', tab: 'club', go: toClub('int'), t: `内部昇格を決める（${seats}）`, left: 27 - wk, hard: true, after: '内部昇格は決められなくなり、空いた枠は一般入団（見ていない子）で埋まります' });
      if (wn.sel && held() < 12) out.push({ id: 'sel', tab: 'club', go: toClub('sel'), t: `セレクションの合否を決める（${seats}）`, left: 34 - wk, hard: true, after: 'セレクションは締め切られ、空いた枠は一般入団（見ていない子）で埋まります' });
      const open = S.cands.filter((c) => c.kind === 'scout' && c.status === 'open' && !c.next).length;
      if (wn.scout && open && held('scout') < 3 && held() < 12) out.push({ id: 'offer', tab: 'club', go: toClub('scout'), t: `スカウトした子に声をかける（${held('scout')}/3人・11月まで）`, left: 27 - wk, hard: true, after: '声をかけられるのは11月までです。会った子には、もう声をかけられません' });
      const acts = YA.scoutActsLeft(w);
      if (monthEnds && wn.explore && acts > 0) out.push({ id: 'scoutact', tab: 'club', go: toClub('scout'), t: `スカウトに出る（今月あと${acts}回）`, left: 0, hard: false, tag: '今月まで' });
    }
    // 年度はじめ（4週まで）：方針・★の子の育成計画
    if (wk <= 4) {
      if (YA.policyCard && w.policySeenY !== w.year) out.push({ id: 'policy', tab: 'club', go: toClub('over'), t: '指導の方針を見直す', left: 4 - wk, hard: false });
      const np = all(w).filter((p) => p.star && !(p.yplan && p.yplan.y === w.year));
      if (np.length) out.push({ id: 'yplan', tab: 'players', go: toPlayer(np[0].id, 'grow'), t: `★の子の育成計画を立てる（まだ${np.length}人）`, left: 4 - wk, hard: false });
    }
    // 面談は1人と月1回：月の最後の週に、まだ話していない★の子
    if (monthEnds && YA.canTalk) {
      const nt = all(w).filter((p) => p.star && YA.canTalk(w, p));
      if (nt.length) out.push({ id: 'talk', tab: 'players', go: toPlayer(nt[0].id, 'talk'), t: `★の子と今月の面談（まだ${nt.length}人）`, left: 0, hard: false, tag: '今月まで' });
    }
    return out.sort((a, b) => a.left - b.left || (b.hard ? 1 : 0) - (a.hard ? 1 : 0));
  };
  // この週を過ぎると決められなくなるもの
  YA.todoDue = (w) => YA.todoList(w).filter((x) => x.hard && x.left <= 0);
  YA.todoTabs = (w) => new Set(YA.todoList(w).map((x) => x.tab));
  // クラブの小タブごとのやり残し（2026-11-21：左の帯のクラブに赤い点が付いても、どの小タブか分からなかった）
  const TODO_SUB = { int: 'int', sel: 'sel', offer: 'scout', scoutact: 'scout', policy: 'over' };
  YA.todoSubs = (w) => { const m = {}; for (const x of YA.todoList(w)) if (x.tab === 'club' && TODO_SUB[x.id] && !m[TODO_SUB[x.id]]) m[TODO_SUB[x.id]] = x.t; return m; };
  // 方針の画面を開いたら、その年は見たことにする
  const pc0 = YA.policyCard;
  if (pc0) YA.policyCard = function (w) {
    if (w && YA.policyOpen(w)) w.policySeenY = w.year;
    return pc0.apply(this, arguments);
  };
  // ホームの「やり残し」の欄
  YA.todoCard = function (w) {
    const list = YA.todoList(w);
    if (!list.length) return null;
    const h = H();
    const app = YA._ui.app;
    const when = (x) => x.tag || (x.left <= 0 ? '今週まで' : `あと${x.left + 1}週`);
    return h('div', { class: 'card todo', style: 'padding:5px 8px;background:#fff8e1;border-color:#f0d58a;box-shadow:none;flex:none' },
      h('div', { class: 'row', style: 'gap:5px' }, h('b', { style: 'font-size:12px;color:#7a5a00' }, 'やり残し'), h('span', { class: 'sub', style: 'font-size:11px' }, '押すとその画面へ')),
      h('div', { style: 'display:flex;flex-direction:column;gap:3px;margin-top:3px' }, list.slice(0, 3).map((x) => h('button', { class: 'pitem', 'data-todo': x.id, style: 'min-height:34px;padding:3px 6px;gap:5px;background:#fff', onclick: () => { x.go(app); rer(); } },
        h('span', { class: 'grow', style: 'font-size:12px;text-align:left;line-height:1.35' }, x.t),
        h('span', { class: 'chip', style: 'flex:none;font-size:11px;' + (x.hard && x.left <= 0 ? 'background:#d63a3a;color:#fff' : 'background:#eef2f8;color:#5b6a85') }, when(x))))),
      list.length > 3 ? h('div', { class: 'sub', style: 'font-size:11px;margin-top:2px' }, `ほか${list.length - 3}件`) : null);
  };
  // 「次の週へ」の前の確かめ：この週で締め切られるものが残っていたら、一度だけ止める
  YA.todoGate = function (w, go) {
    const due = YA.todoDue(w);
    const key = w.year * 100 + w.week;
    if (!due.length || w.todoPassed === key) return false;
    const h = H();
    const app = YA._ui.app;
    YA._v.modal((close) => h('div', { class: 'sheet-in', style: 'flex:none;align-self:center;margin:auto;width:min(560px,96%);padding:12px;gap:6px' },
      h('div', { class: 'h' }, 'この週で締め切られるものがあります'),
      h('div', { class: 'plist' }, due.map((x) => h('div', { class: 'pitem', style: 'cursor:default;align-items:flex-start;flex-direction:column;gap:1px' }, h('b', { style: 'font-size:12.5px' }, x.t), h('span', { class: 'sub', style: 'font-size:11.5px' }, '進むと、' + x.after)))),
      h('div', { class: 'row', style: 'gap:6px;margin-top:4px' },
        h('button', { class: 'btn pri grow', style: 'min-height:42px', onclick: () => { close(); due[0].go(app); rer(); } }, '戻って決める'),
        h('button', { class: 'btn grow', style: 'min-height:42px', onclick: () => { w.todoPassed = key; save(); close(); go(); } }, 'このまま進む'))));
    return true;
  };

  // ---------- 卒業生の紹介文（2026-11-18「卒業した選手の概要欄が薄い、もっと文章でも表現したい」）----------
  // ユース時代の段落（卒業のときの記録から）と、その後の段落（毎年の成績・移籍・代表から）
  const ROUTE_WORD = { スカウト: 'スカウトで声をかけて来てもらった', セレクション: 'セレクションを勝ち抜いて入ってきた', '内部昇格（U-15）': 'U-15から上がってきた', 一般入団: '一般入団で入ってきた' };
  const ae1 = YA.alumniEntry;
  YA.alumniEntry = function (w, p) {
    const a = ae1.apply(this, arguments);
    if (p.route) a.route = p.route;
    if (p.joinY != null) a.joinY = p.joinY;
    a.pers = Object.values(p.pers || {}).filter(Boolean);
    if (p.awake && p.awake.y) a.awY = p.awake.y;
    if (w.captain === p.id) a.capt = true;
    if (p.bg) a.bg = p.bg;
    return a;
  };
  const posWord = (a) => (YA.POS_LABEL && YA.POS_LABEL[a.main]) || a.pos;
  const lgShort = (lg) => String(lg || '').replace(/リーグ$/, '').split('・')[0];
  YA.alumniStory = function (w, a) {
    const gk = a.pos === 'GK';
    const y = [];
    const route = a.route ? ROUTE_WORD[a.route] || a.route + 'で入ってきた' : null;
    y.push(`${route ? `${a.joinY ? a.joinY + '年目に' : ''}${route}` : '監督が来たときには、もうチームにいた'}${posWord(a)}${a.star ? '（★注目）' : ''}${a.capt ? '。最後の年はキャプテンを務めた' : ''}。`);
    const pv = (a.pers || []).find((v) => YA.PERS_NOTE && YA.PERS_NOTE[v]);
    if (pv) y.push(`性格は${pv}。${YA.PERS_NOTE[pv].replace(/（.*?）/g, '')}子だった。`);
    if (a.bg && YA.BG_NAME && YA.BG_NAME[a.bg]) y.push(`じつは「${YA.BG_NAME[a.bg]}」という事情を抱えていた。`);
    const r1 = (a.rHist || []).slice().sort((x, z) => x.g - z.g).filter((x) => x.g < 3)[0];
    const rEnd = YA.rate(a.ovr0 || a.ovr);
    if (r1) { const d = rEnd - r1.r; y.push(`高${r1.g}で${r1.r}だった総合力は、卒業のときには${rEnd}${d >= 30 ? 'まで大きく伸びた' : d >= 10 ? 'まで伸びた' : d > 0 ? 'と、少しずつ伸びた' : 'のまま、伸び悩んだ'}。`); }
    else y.push(`卒業のときの総合力は${rEnd}${YA.levelOf ? '（' + YA.levelOf(rEnd) + '）' : ''}。`);
    if (a.form) y.push(`${a.awY ? a.awY + '年目に' : ''}「${a.form}」に目覚めた。`);
    if (a.cs && a.cs.apps) y.push(`Aの公式戦には${a.cs.apps}試合に出て${gk ? '、ゴールを守った' : `、${a.cs.goals}得点・${a.cs.assists}アシスト`}。`);
    else y.push('Aの公式戦に出ることはなかった。');
    const tr = (a.traits || []).slice(0, 2);
    if (tr.length) y.push(`持ち味は${tr.map((t) => `「${t}」`).join('と')}。`);
    if (a.youthCaps) y.push(`年代別の代表にも${a.youthCaps}回呼ばれた。`);
    const pm = (a.mem || []).find((m) => m.k === 'path');
    const WW = YA.WISH_WORD || {};
    if (pm && pm.wish && WW[pm.wish]) y.push(pm.c === pm.wish ? `進路の面談では${WW[pm.wish]}を望み、その道を選ばせた。` : `進路の面談では${WW[pm.wish]}を望んだが、${WW[pm.c] ? WW[pm.c] + 'の道' : '別の道'}を選ばせた。`);
    if (a.status === 'left') y.push(`在学中にチームを去った（${String(a.note || '退団').replace(/^退団（?|）$/g, '') || '事情'}）。`);
    else {
      const c0 = a.club0 != null ? a.club0 : a.club, l0 = a.club0 != null ? a.league0 : a.league;
      y.push(!c0 || c0 === '社会人' ? '卒業後は、社会人チームでサッカーを続ける道へ進んだ。' : c0 === '一般企業' ? '卒業後は、サッカーを離れて働き始めた。' : `卒業後は${c0}${l0 && !/大学|社会人/.test(l0) ? '（' + l0 + '）' : ''}へ進んだ。`);
    }
    const gq = (a.mem || []).filter((m) => m.q && m.k === 'grad').slice(-1)[0] || (a.mem || []).filter((m) => m.q).slice(-1)[0];
    if (gq) y.push(`${gq.k === 'grad' ? '卒業の日には' : '最後の頃、'}「${gq.q}」と言っていた。`);
    if (a.bond != null) y.push(a.bond >= 5 ? '監督との絆は深い。' : a.bond <= 1 ? '監督とは、最後まで打ち解けきれなかった。' : '');
    // その後
    const s = [];
    const ss = (a.seasons || []).filter((x) => x.apps != null);
    const moves = a.moves || [];
    if (a.status !== 'left') {
      if (ss.length) {
        const clubs = [...new Set(ss.map((x) => x.club))];
        s.push(`卒業から${ss.length}年。${clubs.slice(0, 3).map((c) => (c === '社会人' ? '社会人チーム' : c)).join('・')}${clubs.length > 3 ? `など${clubs.length}つのクラブ` : ''}で、通算${YA.statLine(a, gk)}。`);
        const best = ss.slice().sort((p1, p2) => (gk ? (p2.cleans || 0) - (p1.cleans || 0) : p2.goals - p1.goals) || p2.apps - p1.apps)[0];
        if (best && (gk ? best.cleans : best.goals) >= 5) s.push(`いちばんの年は${best.y}年目の${best.club}で、${gk ? best.cleans + '試合を完封した' : best.goals + '点を取った'}。`);
      } else if (a.status === 'univ') s.push(`いまは${a.club}で、大学の4年間を戦っている。`);
      else if (!a.retired) s.push('卒業して、まだ最初のシーズンを戦っている。');
      for (const m of moves.slice(0, 2)) s.push(m.join ? `${m.y}年目に大学から${m.to}（${lgShort(m.toLg)}）でプロになった。` : `${m.y}年目に${m.to}（${m.toLg}）へ移った${m.fee ? `（移籍金 ${YA.yen(m.fee)}）` : ''}。`);
      if (moves.length > 2) s.push(`ほかにも${moves.length - 2}回移籍している。`);
      if (a.nat) s.push(`日本代表には${a.caps != null ? a.caps : a.nat * 5}試合${a.natGoals ? `、${a.natGoals}得点` : ''}。`);
      if ((a.titles || []).length) s.push(`手にしたタイトルは${a.titles.length}つ。`);
      if (a.bdBest) s.push(a.bdBest === 1 ? 'バロンドールにも輝いた。' : `バロンドールの投票で最高${a.bdBest}位に入った。`);
      if (a.hof) s.push(a.hof === 'full' ? 'クラブの殿堂に入った。' : '殿堂の候補に名前が挙がっている。');
      if (a.retired) s.push(`${a.retY ? a.retY + '年目に' : ''}${a.quit ? 'サッカーをやめた' : '現役を引退した'}。`);
      if (a.coachY) s.push(`${a.coachY}年目に、コーチとしてこのクラブへ戻ってきた。`);
    }
    return { youth: y.filter(Boolean).join(''), after: s.join('') };
  };
  // 名鑑の一覧に出す、ひとことの紹介
  YA.alumniTagline = function (a) {
    if (a.status === 'left') return null;
    const lg = a.status === 'pro' ? lgShort(a.league) : a.status === 'univ' ? '大学' : '社会人';
    const head = a.form ? `「${a.form}」に目覚めた、` : a.capt ? '元キャプテンの、' : a.star ? '★注目だった、' : (a.traits || [])[0] ? `「${a.traits[0]}」の、` : '';
    return `${head}${a.retired ? '元' : ''}${lg}の${posWord(a)}`;
  };
  YA.alumniStoryEl = function (w, a) {
    const h = H();
    const st = YA.alumniStory(w, a);
    return h('div', { class: 'card story', style: 'padding:7px 10px;margin:2px 0;background:#f8f6ef;box-shadow:none;display:flex;flex-direction:column;gap:4px' },
      h('div', {}, h('b', { style: 'font-size:11.5px;color:var(--sub)' }, 'どんな子だったか'), h('div', { style: 'font-size:12.5px;line-height:1.65' }, st.youth)),
      st.after ? h('div', {}, h('b', { style: 'font-size:11.5px;color:var(--sub)' }, '卒業してから'), h('div', { style: 'font-size:12.5px;line-height:1.65' }, st.after)) : null);
  };

  YA.glossaryEl = function () {
    const h = H();
    return h('div', {}, h('div', { class: 'h' }, '用語集'), h('div', { class: 'plist', style: 'margin-top:4px' }, YA.GLOSSARY.map(([k, v]) => h('div', { class: 'pitem', style: 'cursor:default;align-items:flex-start;gap:6px' }, h('b', { style: 'width:110px;flex:none' }, k), h('span', { class: 'grow', style: 'font-size:11.5px' }, v)))));
  };
  // ---------- 選手の概要（2026-11-19「能力値とかはいらない。FM の選手概要欄を参考にして」） ----------
  // 選手を開いて最初に出る小タブ。能力の数字は出さず、コーチの見立て（文と長所・短所）・プロフィール・
  // ポジションの図・状態・特性・試合の数字を言葉と絵で見せる。能力の数字は「能力」タブに残す。
  // 直近の試合の採点：A・B の公式戦で出た試合を5つまで（p.rl）。この版から残す
  const am1 = YA.applyMatch;
  YA.applyMatch = function (w, m, which, opp, scheduled) {
    const r = am1.apply(this, arguments);
    try {
      // B の試合は日程の外（scheduled=false）で回るので、B はいつも数える
      if ((scheduled || which === 'B') && m && m.home && m.home.players) {
        for (const [id, mp] of Object.entries(m.home.players)) {
          const p = w.players[id];
          if (!p || !mp.st || !(mp.st.minutes > 0)) continue;
          const on = typeof opp === 'string' ? opp : opp && opp.name ? opp.name : '';
          p.rl = (p.rl || []).concat([{ y: w.year, w: w.week, t: which, r: Math.round(mp.st.rating * 10) / 10, g: mp.st.goals || 0, a: mp.st.assists || 0, o: on }]).slice(-5);
        }
      }
    } catch (er) { /* 形の違う試合 */ }
    return r;
  };
  // 能力ごとの「長所の言い方」と「短所の言い方」
  YA.AB_WORDS = {
    ファーストタッチ: ['止める技術が高い', 'トラップが乱れやすい'], パス: ['パスの精度が高い', 'パスがずれやすい'], ドリブル: ['ドリブルで運べる', '持ち運ぶのがうまくない'],
    フィニッシュ: ['決定力がある', '決めきれない場面が多い'], ロングシュート: ['遠目からも狙える', 'ミドルシュートは少ない'], クロス: ['クロスの質が高い', 'クロスの精度が低い'],
    ヘディング: ['空中戦に強い', '頭での競り合いに弱い'], タックル: ['奪い切る守備ができる', 'タックルが軽い'], マーク: ['マークを外さない', 'マークを見失いやすい'],
    テクニック: ['足もとの技術が光る', '技術はまだ粗い'], プレースキック: ['セットプレーのキッカーを任せられる', '止まった球を蹴るのがうまくない'], PK: ['PKに強い', 'PKに弱い'],
    逆足の精度: ['両足を使える', '逆足はほとんど使えない'], 予測: ['先を読む力がある', '読みが遅れやすい'], 判断: ['判断が速く正しい', '判断に迷いが出る'],
    視野: ['周りがよく見えている', '視野が狭くなりやすい'], ポジショニング: ['立ち位置が良い', '立ち位置がずれやすい'], オフザボール: ['ボールのない所の動きが良い', 'ボールのない所で止まりやすい'],
    チームワーク: ['チームのために走れる', '自分のプレーに寄りやすい'], 運動量: ['よく走る', '運動量が少ない'], 集中: ['最後まで集中が切れない', '集中が途切れることがある'],
    冷静さ: ['大事な場面でも落ち着いている', '大事な場面で慌てやすい'], 加速: ['出足が速い', '出足が遅い'], スピード: ['足が速い', 'スピードが足りない'],
    敏しょう性: ['身のこなしが軽い', '切り返しについていけない'], バランス: ['当たられても倒れない', '体勢を崩しやすい'], ジャンプ: ['高く跳べる', '跳ぶ高さが足りない'],
    スタミナ: ['90分走りきれる', '後半に足が止まる'], 強さ: ['体の強さがある', '当たり負けしやすい'],
    ハンドリング: ['キャッチが安定している', 'ボールをこぼしやすい'], 反応: ['反応が鋭い', '反応が遅れる'], '1対1': ['1対1に強い', '1対1で先に倒れてしまう'],
    飛び出し: ['飛び出しの判断が良い', '飛び出しをためらう'], 空中戦: ['ハイボールに強い', 'クロスの処理が安定しない'], エリアの支配: ['ゴール前を仕切れる', 'ゴール前で存在感が薄い'],
    コーチング: ['声で守備を動かせる', '声が少ない'], 配球: ['配球で攻撃を始められる', '配球が粗い'],
  };
  // 長所3つ・短所2つ（数字は出さない）。長所は位置に効く能力と全体で目立つもの、短所は位置に効く能力の低いもの
  YA.prosCons = function (p) {
    const isGK = p.pos === 'GK';
    const key = (YA.POS_ABS15[p.main] || (isGK ? YA.AB_GK : [])).filter((n) => YA.AB_WORDS[n]);
    const pool = isGK ? YA.AB_GK : YA.AB_FIELD.filter((n) => n !== 'PK' && n !== 'プレースキック');
    const v = (n) => p.ab[n] || 0;
    const avg = pool.reduce((s, n) => s + v(n), 0) / pool.length;
    // 位置に効く能力は少し上に見る（同じくらいなら位置の持ち味を先に）
    const pros = pool.slice().sort((a, b) => v(b) + (key.indexOf(b) >= 0 ? 1.5 : 0) - (v(a) + (key.indexOf(a) >= 0 ? 1.5 : 0))).filter((n) => v(n) >= avg).slice(0, 3);
    // 短所が無い子でも、位置に効く能力でいちばん低いものを1つは挙げる（FM の見立ても必ず課題を書く）
    const rest = key.filter((n) => pros.indexOf(n) < 0).sort((a, b) => v(a) - v(b));
    let cons = rest.filter((n) => v(n) < avg + 0.5).slice(0, 2);
    if (!cons.length && rest.length) cons = [rest[0]];
    return { pros, cons };
  };
  // 同じ学年の中での位置（言葉で）
  const gradeWord = (w, p) => {
    const mates = all(w).filter((q) => q.grade === p.grade).sort((a, b) => YA.ovr(b) - YA.ovr(a));
    const k = mates.indexOf(p) / Math.max(1, mates.length - 1);
    return k <= 0.15 ? '学年で指折りの力がある' : k <= 0.5 ? '学年では上のほう' : k <= 0.8 ? '学年では真ん中くらい' : '学年ではまだ下のほう';
  };
  const lvName = (v) => YA.levelOf(v).replace(/（.*?）/, '');
  // 将来の見立てを水準の名前だけで（数字は出さない）
  YA.futureWords = function (w, p) {
    const f = YA.futureRange(w, p);
    const a = lvName(f.lo);
    const b = lvName(f.hi);
    return a === b ? `「${a}」くらい` : `「${a}」〜「${b}」`;
  };
  // コーチの見立ての文（2〜3文）
  YA.coachReport = function (w, p) {
    const pc = YA.prosCons(p);
    const W2 = YA.AB_WORDS;
    const pos = YA.POS_NAME[p.main] || p.main;
    const s1 = pc.pros.length >= 2 ? `${W2[pc.pros[0]][0]}${pos}。${W2[pc.pros[1]][0]}のも持ち味。` : pc.pros.length ? `${W2[pc.pros[0]][0]}${pos}。` : `目立った武器はまだ無い${pos}。`;
    const s2 = pc.cons.length ? '課題は、' + pc.cons.map((n) => W2[n][1] + 'こと').join('と、') + '。' : '';
    const st = YA.coachStars(w, p);
    const s3 = `いまは${gradeWord(w, p)}。${p.grade < 3 ? (st >= 4 ? 'まだ大きく伸びそう。' : st >= 3 ? 'まだ伸びる余地がある。' : '伸びはゆるやかになりそう。') : ''}`;
    return (s1 + s2 + s3).replace(/。。/g, '。');
  };
  // 状態を言葉で
  YA.stateWords = function (p) {
    const out = [];
    if (p.inj > 0) out.push(['怪我 あと' + p.inj + '週', 'bad']);
    out.push(p.conf >= 70 ? ['乗っている', 'good'] : p.conf <= 35 ? ['自信をなくしている', 'bad'] : ['落ち着いている', '']);
    out.push(p.fat >= 70 ? ['疲れが溜まっている', 'bad'] : p.fat >= 40 ? ['少し疲れている', ''] : ['元気', 'good']);
    out.push(p.unrest > 3 ? ['不満が溜まっている', 'bad'] : p.unrest > 1.5 ? ['気にしていることがある', ''] : ['不満はなさそう', 'good']);
    if (p.suspend > 0) out.push(['出場停止 ' + p.suspend + '試合', 'bad']);
    return out;
  };
  // ポジションの図（FM の位置の図）。横向きで右へ攻める。分かっている位置だけ丸を置く
  const PXY = { GK: [7, 32], CB: [21, 32], LB: [23, 9], RB: [23, 55], LWB: [38, 8], RWB: [38, 56], DM: [36, 32], CM: [52, 32], LM: [58, 9], RM: [58, 55], AM: [68, 32], LW: [79, 10], RW: [79, 54], SS: [80, 32], ST: [92, 32] };
  YA.posMapEl = function (p) {
    const NS = 'http://www.w3.org/2000/svg';
    const s = (tag, at, txt) => { const e = document.createElementNS(NS, tag); for (const k in at) e.setAttribute(k, at[k]); if (txt != null) e.textContent = txt; return e; };
    const svg = s('svg', { viewBox: '-2 -2 104 68', class: 'posmap' });
    const ln = { stroke: 'rgba(255,255,255,.75)', 'stroke-width': 0.6, fill: 'none' };
    svg.append(s('rect', { x: -2, y: -2, width: 104, height: 68, fill: '#2f9a5f', rx: 3 }), s('rect', Object.assign({ x: 0, y: 0, width: 100, height: 64 }, ln)), s('line', Object.assign({ x1: 50, y1: 0, x2: 50, y2: 64 }, ln)), s('circle', Object.assign({ cx: 50, cy: 32, r: 8 }, ln)), s('rect', Object.assign({ x: 0, y: 16, width: 14, height: 32 }, ln)), s('rect', Object.assign({ x: 86, y: 16, width: 14, height: 32 }, ln)));
    const known = p.pos === 'GK' ? ['GK'] : [p.main].concat(p.subs || []).concat(p.bestKnown && p.best ? [p.best] : []).filter((q, i, a) => a.indexOf(q) === i && PXY[q]);
    const COL = { '◎': '#0f7a3d', '○': '#7dd49b', '△': '#f2c94c', '×': '#e07a7a' };
    for (const q of known) {
      const g = YA.aptGrade(p.apt[q] || 0);
      const [x, y] = PXY[q];
      svg.append(s('circle', { cx: x, cy: y, r: q === p.main ? 6.2 : 5.2, fill: COL[g], stroke: q === p.main ? '#fff' : 'rgba(0,0,0,.25)', 'stroke-width': q === p.main ? 1.2 : 0.5 }));
      svg.append(s('text', { x, y: y + 1.6, 'text-anchor': 'middle', 'font-size': 4.4, 'font-weight': 900, fill: g === '◎' ? '#fff' : '#14284b' }, YA.POS_LABEL[q]));
    }
    return svg;
  };
  const foot = (p) => (p.foot === 'R' ? '右' : p.foot === 'L' ? '左' : '両足');
  YA.playerOverview = function (w, p) {
    const h = H();
    const sec = (title, ...kids) => h('div', { class: 'ovsec' }, h('div', { class: 'ovh' }, title), ...kids);
    const pc = YA.prosCons(p);
    // コーチの見立て（横いっぱい）
    const report = sec('コーチの見立て',
      h('div', { class: 'ovtext' }, YA.coachReport(w, p)),
      h('div', { class: 'ovpc' },
        ...pc.pros.map((n) => h('div', { class: 'pro' }, h('b', {}, '＋'), YA.AB_WORDS[n][0])),
        ...pc.cons.map((n) => h('div', { class: 'con' }, h('b', {}, '－'), YA.AB_WORDS[n][1]))),
      h('div', { class: 'ovline' }, h('span', { class: 'sub' }, 'いま'), h('b', {}, (YA.ent && YA.ent.eye ? YA.rating(p) + '（' + lvName(YA.rating(p)) + '）' : lvName(YA.rating(p)))), h('span', { class: 'sub' }, '将来'), YA.starsEl([YA.coachStars(w, p), YA.coachStars(w, p)]), h('b', {}, YA.futureWords(w, p))));
    // プロフィール
    const persAll = Object.values(p.pers || {}).filter((t) => t && t !== 'ふつう').slice(0, 3);
    const rows = [
      ['学年', `高${p.grade}（${15 + p.grade}歳）・${p.team}チーム`],
      ['利き足', foot(p) + (p.height ? `・${p.height}cm` : '')],
      p.nation && p.nation !== '日本' ? ['国籍', p.nation] : null,
      p.joinY ? ['入団', `${p.joinY}年目・${p.route || '一般入団'}`] : null,
      ['性格', persAll.length ? persAll.join('・') : 'おだやか'],
      YA.bgText && p.bgKnow ? ['事情', YA.bgText(w, p)] : null,
    ].filter(Boolean);
    const prof = sec('プロフィール', h('div', { class: 'ovdl' }, ...rows.map(([k, v]) => h('div', { class: 'ovrow' }, h('span', { class: 'k' }, k), h('span', { class: 'v' }, v)))));
    const pos = sec('ポジション', YA.posMapEl(p), h('div', { class: 'ovnote' }, h('span', { class: 'dot g1' }), '本職 ', h('span', { class: 'dot g2' }), 'こなせる ', h('span', { class: 'dot g3' }), '不慣れ'));
    // 状態
    const state = sec('状態', h('div', { class: 'ovchips' }, ...YA.stateWords(p).map(([t, k]) => h('span', { class: 'fit ' + (k || 'mid') }, t))));
    // 特性（金・覚醒は色を変える）
    const tr = (p.traits || []).map((x) => (YA.isGold && YA.isGold(p, x) ? h('span', { class: 'chip gold' }, '金 ' + YA.GOLD[x]) : h('span', { class: 'chip trait' }, x)));
    if (p.aw && p.aw.trait) tr.unshift(h('span', { class: 'chip awk' }, '覚醒 ' + p.aw.trait));
    const traits = sec('特性', h('div', { class: 'ovchips' }, ...(tr.length ? tr : [h('span', { class: 'sub' }, 'まだ特性はありません')])));
    // 試合
    const cs = p.cs || { apps: 0, goals: 0, assists: 0 };
    const rl = (p.rl || []).slice(-5);
    const isGK = p.pos === 'GK';
    const games = sec('試合',
      h('div', { class: 'ovstats' }, h('div', {}, h('b', {}, cs.apps), h('small', {}, 'A出場')), isGK ? null : h('div', {}, h('b', {}, cs.goals), h('small', {}, '得点')), isGK ? null : h('div', {}, h('b', {}, cs.assists), h('small', {}, 'アシスト')), rl.length ? h('div', {}, h('b', {}, (rl.reduce((a, x) => a + x.r, 0) / rl.length).toFixed(1)), h('small', {}, '採点')) : null),
      rl.length
        ? h('div', { class: 'ovform' }, ...rl.map((x) => h('div', { class: 'fbar', tip: `${YA.ywName(x.y, x.w)}（${x.t}）${x.o ? '・' + x.o : ''}${x.g ? `・${x.g}得点` : ''}${x.a ? `・${x.a}アシスト` : ''}` }, h('i', { style: `height:${Math.round(clamp((x.r - 4) / 5, 0.08, 1) * 100)}%;background:${x.r >= 7.5 ? '#1a9d57' : x.r >= 6.5 ? '#7dbf3f' : x.r >= 5.8 ? '#f2b84c' : '#e06a5a'}` }), h('span', {}, x.r.toFixed(1)), h('small', {}, x.t))))
        : h('div', { class: 'sub', style: 'font-size:11.5px' }, 'まだ記録した試合がありません（これからの試合が5つまで並びます）'));
    // ★の子：信頼と覚醒の鍵の近さ
    let star = null;
    if (p.star && YA.keysOf) {
      const ks = YA.keysOf(w, p);
      const done = ks.filter((k) => k.done).length;
      star = sec('★ この子と', h('div', { class: 'ovtext' }, `信頼：${YA.TRUST_NAME[YA.trustLv(p)]}　／　${p.aw ? `覚醒した（${p.aw.form}）` : ks.length ? `覚醒の鍵 ${done}/${ks.length} がそろった` : '覚醒の鍵はまだ見えない'}`));
    }
    return h('div', { class: 'overview' }, report, h('div', { class: 'ovcols' }, h('div', { class: 'ovcol' }, prof, pos), h('div', { class: 'ovcol' }, state, games, traits, star)));
  };
})();
