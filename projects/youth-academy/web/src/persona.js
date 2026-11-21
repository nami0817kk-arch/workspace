// 選手を構成する要素 段階4「性格」（2026-11-19 ⑥）
// ・分かるまでに時間がかかる（p.pk：分かった性格の括り。新入生は1つだけ見えていて、週ごと・試合・面談で見えてくる）
// ・経験で変わる（主将を続ける・大一番で活躍・長い怪我から戻る・深い信頼・不満が続く…で変わる。1人1年に1回まで）
// ・性格どうしの相性（YA.persCompat。試合で同じピッチにいると少し上下する。段階7の仲良しの輪にも使う）
// ・効き目を見せる（概要の「性格」の欄に、効き目・まだ見えていない数・相性のいい子と合わない子）
(function () {
  const YA = globalThis.YA;
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const all = (w) => Object.values(w.players || {});
  const rngP = (p, salt) => YA.rngOf(YA.hash(String(p.id) + '|' + p.name + '|' + salt));
  const on = (p) => Object.keys(p.pers || {}).filter((g) => p.pers[g] && p.pers[g] !== 'ふつう');

  // ---------- 分かるまで ----------
  YA.PERS_REVEAL = 0.045; // 1週に1つの括りが見えてくる割合（試合に出た週・★の子は上がる）
  YA.persKnown = (p, g) => !p.pk || !!p.pk[g];
  YA.persHidden = (p) => on(p).filter((g) => !YA.persKnown(p, g));
  // 見えている性格だけの写し（見えていない括りは入れない）
  YA.persVisible = function (p) {
    const o = {};
    for (const g of Object.keys(p.pers || {})) if (p.pers[g] === 'ふつう' || YA.persKnown(p, g)) o[g] = p.pers[g];
    return o;
  };
  function reveal(w, p, g, how) {
    if (!p.pk || p.pk[g]) return false;
    p.pk[g] = 1;
    if (w && YA.noteTier) YA.noteTier(w, 3, `${p.name}の性格が見えてきた：「${p.pers[g]}」${how ? '（' + how + '）' : ''}`, p.id);
    if (p.hist && w) p.hist.unshift({ y: w.year, w: w.week, t: `性格「${p.pers[g]}」が見えてきた` });
    return true;
  }
  YA.persReveal = reveal;
  YA.persInit = function (p, known) {
    if (p.pk) return p;
    p.pk = {};
    const xs = on(p);
    if (known) for (const g of xs) p.pk[g] = 1;
    else if (xs.length) {
      // 目に見えやすい括り（人との関わり・プレーの気質）を先に1つ
      const vis = xs.filter((g) => g === '人との関わり' || g === 'プレーの気質');
      const r = rngP(p, 'pk');
      if (r() < 0.6) p.pk[(vis.length ? vis : xs)[Math.floor(r() * (vis.length ? vis : xs).length)]] = 1;
    }
    return p;
  };
  const gp0 = YA.genPlayer;
  YA.genPlayer = function () { return YA.persInit(gp0.apply(this, arguments), false); };
  const nw0 = YA.newWorld;
  YA.newWorld = function () {
    const w = nw0.apply(this, arguments);
    // 始めた年の高2・高3は、前の指導者のもとで過ごしてきた子なので分かっている。高1も半分くらいは見えている
    for (const p of all(w)) if (p.grade >= 2) for (const g of on(p)) p.pk[g] = 1;
    return w;
  };
  // 古い保存の子は、すべて分かっていることにする
  YA.ensurePersona = function (w) { for (const p of all(w)) if (!p.pk) YA.persInit(p, true); };
  // 面談をすると1つ見えやすい
  const tk0 = YA.talk;
  YA.talk = function (w, pid) {
    const res = tk0.apply(this, arguments);
    const p = w.players[pid];
    if (res && res.ok !== false && p) { const hid = YA.persHidden(p); if (hid.length && rngP(p, 'talk' + w.year + w.week)() < 0.6) reveal(w, p, hid[0], '面談で'); }
    return res;
  };

  // ---------- 経験で変わる ----------
  // [括り, 変わる先, 変わる前に許す値（null＝何でも）, 経験の鍵, 要る回数, 理由]
  YA.PERS_GROW = [
    ['人との関わり', 'リーダー気質', ['ふつう', '人見知り', '寡黙', 'お調子者', '仲間思い'], 'cap', 20, '主将を続けてきた'],
    ['大舞台', '大舞台に強い', ['ふつう', 'プレッシャーに弱い', '慎重'], 'bigok', 2, '大一番で活躍した'],
    ['大舞台', 'プレッシャーに弱い', ['ふつう'], 'bigng', 2, '大一番で力を出せなかった'],
    ['気持ちの強さ', '粘り強い', ['ふつう', '繊細'], 'injback', 1, '長い怪我から戻ってきた'],
    ['教えの受け止め方', '素直', ['ふつう', '頑固', '反骨心', 'マイペース'], 'trust', 12, '監督を深く信頼している'],
    ['プレーの気質', '自信家', ['ふつう'], 'hot', 8, '乗っている時期が続いた'],
    ['教えの受け止め方', '反骨心', ['ふつう', '素直'], 'unrest', 8, '不満を抱えた日々が続いた'],
    ['練習への向き合い', '真面目', ['ふつう', '練習嫌い'], 'grind', 12, '居残りと練習を重ねてきた'],
  ];
  function bump(p, k, n) { p.px = p.px || {}; p.px[k] = (p.px[k] || 0) + (n || 1); }
  function tryGrow(w, p) {
    if (p.pxY === w.year) return;
    for (const [g, to, from, k, need, why] of YA.PERS_GROW) {
      if (!p.px || (p.px[k] || 0) < need) continue;
      const cur = p.pers[g] || 'ふつう';
      if (cur === to || from.indexOf(cur) < 0) { p.px[k] = 0; continue; }
      p.pers[g] = to;
      if (p.pk) p.pk[g] = 1;
      p.px[k] = 0;
      p.pxY = w.year;
      const txt = cur === 'ふつう' ? `${p.name}に「${to}」な面が出てきた（${why}）` : `${p.name}の性格が変わった：「${cur}」→「${to}」（${why}）`;
      if (cur === 'ふつう' && YA.noteMinor) YA.noteMinor(w, p, `${p.num}番 ${String(p.name).split(' ')[0]}に「${to}」な面`, txt);
      else if (YA.noteTier) YA.noteTier(w, 2, txt, p.id);
      if (p.hist) p.hist.unshift({ y: w.year, w: w.week, t: `性格が「${to}」に（${why}）` });
      p.persCh = (p.persCh || []).concat([{ y: w.year, g, from: cur, to, why }]);
      return;
    }
  }
  YA.persTryGrow = tryGrow;
  YA.persBump = bump;

  // ---------- 相性 ----------
  const GOOD = [['リーダー気質', '素直'], ['世話好き', '人見知り'], ['世話好き', '寂しがり'], ['安定型', '気分屋'], ['献身的', '自信家'], ['真面目', '勉強家'], ['仲間思い', '人見知り'], ['寡黙', '献身的'], ['楽天家', '繊細'], ['リーダー気質', '仲間思い'], ['勇敢', '闘争的']];
  const BAD = [['短気', '短気'], ['頑固', '頑固'], ['自信家', '自信家'], ['お調子者', '寡黙'], ['一匹狼', '構ってほしい'], ['練習嫌い', '真面目'], ['野心家', '野心家'], ['短気', 'お調子者'], ['目立ちたがり', '目立ちたがり'], ['完璧主義', '練習嫌い'], ['頑固', 'リーダー気質']];
  YA.PERS_GOOD = GOOD;
  YA.PERS_BAD = BAD;
  YA.persCompat = function (a, b) {
    if (!a || !b || a === b) return { s: 0, why: [] };
    const va = Object.values(a.pers || {}), vb = Object.values(b.pers || {});
    let s = 0;
    const why = [];
    const has = (xs, v) => xs.indexOf(v) >= 0;
    for (const [x, y] of GOOD) if ((has(va, x) && has(vb, y)) || (has(va, y) && has(vb, x))) { s += 1; why.push(`${x}×${y}`); }
    for (const [x, y] of BAD) if ((has(va, x) && has(vb, y)) || (has(va, y) && has(vb, x))) { s -= 1; why.push(`${x}×${y}`); }
    if (has(va, '仲間思い') || has(vb, '仲間思い')) s += 0.3;
    return { s: Math.max(-2, Math.min(2, s)), why };
  };
  // 試合：同じピッチにいる相性のいい子・合わない子（チームを作るときに数えておく。engine の persMod が使う）
  const tf0 = YA.teamFromWorld;
  YA.teamFromWorld = function (w, which) {
    const t = tf0.apply(this, arguments);
    const ids = t.lineup.map((s) => s.pid);
    for (const id of Object.keys(t.players)) {
      const p = t.players[id];
      let g = 0, b = 0;
      for (const j of ids) { if (j === id || !w.players[j]) continue; const c = YA.persCompat(p, w.players[j]).s; if (c >= 1) g++; else if (c <= -1) b++; }
      p._cg = Math.min(2, g);
      p._cb = Math.min(2, b);
    }
    return t;
  };
  YA.compatMod = (p) => (p._cg ? p._cg * 0.2 : 0) - (p._cb ? p._cb * 0.25 : 0);

  // ---------- 毎週 ----------
  const am0 = YA.applyMatch;
  YA.applyMatch = function (w, m, which) {
    const res = am0.apply(this, arguments);
    try {
      const big = YA.isBigWeek && YA.isBigWeek(w.week) && which === 'A';
      for (const [id, mp] of Object.entries((m && m.home && m.home.players) || {})) {
        const p = w.players[id];
        if (!p || !mp.st || !(mp.st.minutes > 0)) continue;
        p._played = w.year * 100 + w.week;
        if (big && mp.st.rating >= 7.3) bump(p, 'bigok');
        if (big && mp.st.rating <= 5.6) bump(p, 'bigng');
      }
    } catch (e) { /* 形の違う試合 */ }
    return res;
  };
  const ew0 = YA.endWeek;
  YA.endWeek = function (w) {
    YA.ensurePersona(w);
    const injBefore = {};
    for (const p of all(w)) injBefore[p.id] = p.inj || 0;
    const res = ew0.apply(this, arguments);
    const r = YA.rngOf((w.seed | 0) * 17 + w.year * 211 + w.week * 13 + 9);
    for (const p of all(w)) {
      // 見えてくる
      const hid = YA.persHidden(p);
      if (hid.length) {
        const played = p._played === w.year * 100 + w.week;
        const k = YA.PERS_REVEAL * (played ? 1.8 : 1) * (p.star ? 1.5 : 1) * (w.coach ? (w.coach.eye || 10) / 10 : 1);
        if (r() < k) reveal(w, p, hid[Math.floor(r() * hid.length)], played ? '試合で' : '');
      }
      // 経験を数える
      if (w.captain === p.id) bump(p, 'cap');
      if (injBefore[p.id] > 0 && !(p.inj > 0) && (p._injLen || 0) >= 8) bump(p, 'injback');
      if (p.star && (p.tr || 0) >= 80) bump(p, 'trust');
      if (p.conf >= 72) bump(p, 'hot'); else if (p.px && p.px.hot) p.px.hot = Math.max(0, p.px.hot - 1);
      if ((p.unrest || 0) > 3) bump(p, 'unrest'); else if (p.px && p.px.unrest) p.px.unrest = Math.max(0, p.px.unrest - 1);
      if (p.hid && p.hid['プロ意識'] >= 14 && !(p.inj > 0)) bump(p, 'grind', 0.5);
      tryGrow(w, p);
    }
    return res;
  };

  // ---------- 見せ方 ----------
  YA.compatBest = function (w, p) {
    const me = Object.assign({}, p, { pers: YA.persVisible(p) });
    const xs = all(w).filter((q) => q.id !== p.id).map((q) => ({ q, c: YA.persCompat(me, Object.assign({}, q, { pers: YA.persVisible(q) })) })).filter((x) => x.c.s !== 0);
    xs.sort((a, b) => b.c.s - a.c.s);
    return { good: xs.filter((x) => x.c.s >= 1).slice(0, 2), bad: xs.filter((x) => x.c.s <= -1).slice(-2).reverse() };
  };
  const ov0 = YA.playerOverview;
  if (ov0) {
    YA.playerOverview = function (w, p) {
      YA.ensurePersona(w);
      const el = ov0.apply(this, arguments);
      try {
        const doc = el.ownerDocument;
        // プロフィールの「性格」の行は、見えている性格だけ
        for (const r of el.querySelectorAll('.ovrow')) {
          const k = r.querySelector('.k');
          if (k && k.textContent === '性格') {
            const vis = Object.values(YA.persVisible(p)).filter((t) => t !== 'ふつう');
            const hid = YA.persHidden(p).length;
            r.querySelector('.v').textContent = (vis.length ? vis.join('・') : hid ? 'まだよく分からない' : 'おだやか') + (hid && vis.length ? '・？' : '');
          }
        }
        // 性格の欄：効き目・まだ見えていない数・相性
        const sec = doc.createElement('div');
        sec.className = 'ovsec ovpers';
        const hd = doc.createElement('div');
        hd.className = 'ovh';
        hd.textContent = '性格と相性';
        sec.append(hd);
        const add = (txt, cls) => { const d = doc.createElement('div'); d.className = 'ovinfo'; d.style.cssText = 'font-size:11.5px;line-height:1.45' + (cls ? ';' + cls : ''); d.textContent = txt; sec.append(d); };
        const vis = Object.entries(YA.persVisible(p)).filter(([, t]) => t !== 'ふつう');
        for (const [, t] of vis) add(`${t}：${YA.PERS_NOTE[t] || ''}`);
        const hid = YA.persHidden(p).length;
        if (hid) add(`まだ見えていない性格が${hid}つある（試合・面談・一緒に過ごす時間で見えてくる）`, 'color:var(--sub)');
        if (!vis.length && !hid) add('目立った癖のない、おだやかな子');
        for (const c of p.persCh || []) add(`${c.y}年目に「${c.from}」→「${c.to}」（${c.why}）`, 'color:#6b4e00');
        const cb = YA.compatBest(w, p);
        if (cb.good.length) add('相性がいい：' + cb.good.map((x) => `${x.q.name}（${x.c.why[0] || '仲間思い'}）`).join('・'), 'color:#0f6b3a');
        if (cb.bad.length) add('合わない：' + cb.bad.map((x) => `${x.q.name}（${x.c.why[0]}）`).join('・'), 'color:#8a2a20');
        const col = el.querySelectorAll('.ovcol')[0];
        if (col) col.append(sec);
      } catch (e) { /* 形の違う画面 */ }
      return el;
    };
  }
})();
