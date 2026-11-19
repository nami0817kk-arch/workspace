// 選手を構成する要素 段階8「記録」（2026-11-20 ⑪「1.2.3」）
// ・ユース時代の成績を大会ごとに（出場・得点・アシスト・平均採点・試合の最優秀。B チームの分も分ける）p.comp
// ・名場面（初出場・初ゴール・ハットトリック・決勝点・大一番のゴール・大一番の完封・覚醒・金特性）p.scenes
// ・伸びの推移（月ごとの総合力と身長）p.rtH。卒業生にも残し、経歴のページで読み返せる
(function () {
  const YA = globalThis.YA;
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const all = (w) => Object.values(w.players || {});

  // 大会の名前（その週の日程から）
  YA.compOf = function (w, which) {
    if (which === 'B') return 'Bチーム';
    const s = YA.SCHED ? YA.SCHED(w.week) : null;
    if (!s || s.t === 'league') return (w.league && YA.levelNames ? YA.levelNames(w)[(w.league.level || 1) - 1] : null) || 'リーグ';
    if (s.t === 'cup') return (YA.CUP_NAME && YA.CUP_NAME[s.cup]) || '大会';
    return 'その他';
  };
  function addScene(w, p, k, t) {
    p.scenes = p.scenes || [];
    if (['debut', 'first', 'firstA'].indexOf(k) >= 0 && p.scenes.some((x) => x.k === k)) return;
    p.scenes.push({ y: w.year, w: w.week, g: p.grade, k, t });
    if (p.scenes.length > 30) p.scenes.splice(0, p.scenes.length - 30);
  }
  YA.addScene = addScene;

  // ---------- 試合のあと ----------
  const am0 = YA.applyMatch;
  YA.applyMatch = function (w, m, which, opp, scheduled) {
    const res = am0.apply(this, arguments);
    try {
      if (!(scheduled || which === 'B') || !m || !m.home || !m.home.players) return res;
      const comp = YA.compOf(w, which);
      const oppName = typeof opp === 'string' ? opp : opp && opp.name ? opp.name : '';
      const gf = m.score ? m.score.home : 0, ga = m.score ? m.score.away : 0;
      const big = which === 'A' && YA.isBigWeek && YA.isBigWeek(w.week);
      // 試合の最優秀：両チームでいちばん採点の高い子
      let topR = -1, topId = null;
      for (const t of [m.home, m.away]) for (const [id, mp] of Object.entries(t.players || {})) if (mp.st && mp.st.minutes > 0 && mp.st.rating > topR) { topR = mp.st.rating; topId = t === m.home ? id : null; }
      for (const [id, mp] of Object.entries(m.home.players)) {
        const p = w.players[id];
        if (!p || !mp.st || !(mp.st.minutes > 0)) continue;
        const st = mp.st;
        const key = w.year + '|' + comp;
        p.comp = p.comp || {};
        const c = (p.comp[key] = p.comp[key] || { y: w.year, c: comp, g9: p.grade, n: 0, gl: 0, as: 0, rs: 0, mom: 0, cs: 0 });
        c.n++;
        c.gl += st.goals || 0;
        c.as += st.assists || 0;
        c.rs = Math.round((c.rs + st.rating) * 10) / 10;
        if (topId === id) c.mom++;
        if (p.pos === 'GK' && ga === 0 && st.minutes >= 60) c.cs++;
        // 名場面（A の公式戦）
        if (which !== 'A') continue;
        const vs = oppName ? `${oppName}戦` : '試合';
        addScene(w, p, 'debut', `Aの公式戦に初出場（${vs}）`);
        if (st.goals > 0 && !(p.scenes || []).some((x) => x.k === 'first')) addScene(w, p, 'first', `Aの公式戦で初ゴール（${vs}）`);
        if (st.goals >= 3) addScene(w, p, 'hat', `ハットトリック（${vs}・${st.goals}得点）`);
        if (st.goals > 0 && gf - ga === 1) addScene(w, p, 'win', `決勝点になるゴール（${vs} ${gf}-${ga}）`);
        if (big && st.goals > 0) addScene(w, p, 'big', `${comp}の大一番でゴール（${vs}）`);
        if (big && p.pos === 'GK' && ga === 0 && st.minutes >= 60) addScene(w, p, 'bigcs', `${comp}の大一番で完封（${vs}）`);
        if (big && topId === id) addScene(w, p, 'bigmom', `${comp}の大一番で試合の最優秀（採点${st.rating.toFixed(1)}）`);
      }
    } catch (e) { /* 形の違う試合 */ }
    return res;
  };
  // 覚醒・金特性も名場面に
  const aw0 = YA.awaken;
  YA.awaken = function (w, p) {
    const res = aw0.apply(this, arguments);
    try { addScene(w, p, 'awake', `覚醒した：${p.aw ? p.aw.form : ''}（特性「${p.aw ? p.aw.trait : ''}」）${p.aw2 && p.aw2.double ? `・もう一つ「${p.aw2.trait}」` : ''}`); } catch (e) { /* 図鑑など */ }
    return res;
  };

  // ---------- 毎週：金特性・伸びの推移 ----------
  const ew0 = YA.endWeek;
  YA.endWeek = function (w) {
    const gold0 = {};
    for (const p of all(w)) gold0[p.id] = (p.gold || []).length;
    const res = ew0.apply(this, arguments);
    const first = YA.calendar && YA.calendar(w.week).nth === 1;
    for (const p of all(w)) {
      if ((p.gold || []).length > (gold0[p.id] || 0)) { const t = p.gold[p.gold.length - 1]; addScene(w, p, 'gold', `特性「${t}」が金特性「${YA.GOLD[t] || t}」に`); }
      if (first || !(p.rtH || []).length) {
        const last = (p.rtH || []).slice(-1)[0];
        if (!last || last.y !== w.year || last.w !== w.week) p.rtH = (p.rtH || []).concat([{ y: w.year, w: w.week, g: p.grade, r: YA.rating(p), h: p.height }]).slice(-40);
      }
    }
    return res;
  };

  // ---------- 卒業生へ ----------
  const ae0 = YA.alumniEntry;
  YA.alumniEntry = function (w, p) {
    const a = ae0.apply(this, arguments);
    if (p.comp) a.comp = Object.values(p.comp);
    if (p.scenes) a.scenes = p.scenes.slice();
    if (p.rtH) a.rtH = p.rtH.slice();
    return a;
  };

  // ---------- 見せ方 ----------
  YA.compRows = function (x) {
    const list = Array.isArray(x.comp) ? x.comp : Object.values(x.comp || {});
    return list.slice().sort((a, b) => a.y - b.y || (a.c === 'Bチーム') - (b.c === 'Bチーム'));
  };
  function table(h, rows, gk) {
    const th = (v, wd, l) => h('span', { style: `width:${wd}px;flex:none;text-align:${l ? 'left' : 'right'};font-size:10.5px;color:var(--sub);font-weight:800` }, v);
    const td = (v, wd, l) => h('span', { style: `width:${wd}px;flex:none;text-align:${l ? 'left' : 'right'};font-size:11.5px` }, v);
    return h('div', { style: 'overflow-x:auto' },
      h('div', { class: 'row', style: 'gap:4px' }, th('年', 30, true), th('大会', 128, true), th('出場', 30), gk ? th('完封', 30) : th('得点', 30), gk ? null : th('アシ', 30), th('採点', 32), th('最優秀', 38)),
      ...rows.map((c) => h('div', { class: 'row', style: 'gap:4px;border-top:1px solid var(--line);padding:1px 0' }, td(`高${c.g9}`, 30, true), td(c.c, 128, true), td(c.n, 30), gk ? td(c.cs, 30) : td(c.gl, 30), gk ? null : td(c.as, 30), td(c.n ? (c.rs / c.n).toFixed(2) : '-', 32), td(c.mom || '', 38))));
  }
  YA.compTableEl = function (x) {
    const U = YA._ui;
    if (!U) return null;
    const rows = YA.compRows(x);
    if (!rows.length) return null;
    return table(U.h, rows, x.pos === 'GK');
  };
  // 伸びの推移のグラフ（総合力と身長）。卒業生は年ごとの総合力もつなげる
  YA.growthGraphEl = function (x, doc) {
    doc = doc || (typeof document !== 'undefined' ? document : null);
    if (!doc) return null;
    const pts = (x.rtH || []).map((e) => ({ t: e.y + e.w / 40, r: e.r, h: e.h, lab: `高${e.g}` }));
    for (const s of x.seasons || []) if (s && s.y != null && s.ovr != null) pts.push({ t: s.y + 0.95, r: YA.rate(s.ovr), h: null, lab: '' });
    if (pts.length < 2) return null;
    pts.sort((a, b) => a.t - b.t);
    const NS = 'http://www.w3.org/2000/svg';
    const s = (tag, at, txt) => { const e = doc.createElementNS(NS, tag); for (const k in at) e.setAttribute(k, at[k]); if (txt != null) e.textContent = txt; return e; };
    const W = 220, H = 70;
    const t0 = pts[0].t, t1 = pts[pts.length - 1].t;
    const rMin = Math.max(0, Math.min(...pts.map((p) => p.r)) - 10), rMax = Math.min(200, Math.max(...pts.map((p) => p.r)) + 10);
    const X = (t) => 16 + ((t - t0) / Math.max(0.01, t1 - t0)) * (W - 24);
    const Y = (r) => H - 6 - ((r - rMin) / Math.max(1, rMax - rMin)) * (H - 14);
    const svg = s('svg', { viewBox: `0 0 ${W} ${H + 10}`, width: '100%', class: 'gr8', style: 'max-width:440px;display:block;margin-top:3px' });
    svg.append(s('rect', { x: 0, y: 0, width: W, height: H, fill: '#f5f8fd', rx: 3 }));
    svg.append(s('polyline', { points: pts.map((p) => `${X(p.t).toFixed(1)},${Y(p.r).toFixed(1)}`).join(' '), fill: 'none', stroke: '#1f6feb', 'stroke-width': 1.6 }));
    const hs = pts.filter((p) => p.h != null);
    if (hs.length >= 2) {
      const hMin = Math.min(...hs.map((p) => p.h)) - 2, hMax = Math.max(...hs.map((p) => p.h)) + 2;
      const YH = (v) => H - 6 - ((v - hMin) / Math.max(1, hMax - hMin)) * (H - 14);
      svg.append(s('polyline', { points: hs.map((p) => `${X(p.t).toFixed(1)},${YH(p.h).toFixed(1)}`).join(' '), fill: 'none', stroke: '#9aa8bd', 'stroke-width': 1, 'stroke-dasharray': '2 2' }));
    }
    svg.append(s('text', { x: 2, y: 9, 'font-size': 7, fill: '#1f6feb' }, String(pts[0].r)), s('text', { x: W - 18, y: Y(pts[pts.length - 1].r) - 2, 'font-size': 7, fill: '#1f6feb', 'font-weight': 700 }, String(pts[pts.length - 1].r)));
    svg.append(s('text', { x: 2, y: H + 8, 'font-size': 6.5, fill: '#4a5a72' }, `総合力の推移（青）・身長（点線 ${hs.length ? hs[0].h + '→' + hs[hs.length - 1].h + 'cm' : ''}）`));
    return svg;
  };
  YA.scenesEl = function (x) {
    const U = YA._ui;
    if (!U || !(x.scenes || []).length) return null;
    const h = U.h;
    return h('div', { style: 'display:flex;flex-direction:column;gap:1px' }, x.scenes.slice().reverse().slice(0, 8).map((e) => h('div', { style: 'font-size:11.5px' }, h('span', { class: 'sub' }, `${e.y}年目 高${e.g} `), e.t)));
  };
  const ov0 = YA.playerOverview;
  if (ov0) {
    YA.playerOverview = function (w, p) {
      const el = ov0.apply(this, arguments);
      try {
        const doc = el.ownerDocument;
        const h = YA._ui && YA._ui.h;
        if (!h) return el;
        const kids = [YA.growthGraphEl(p, doc), YA.compTableEl(p), YA.scenesEl(p)].filter(Boolean);
        if (!kids.length) return el;
        const sec = h('div', { class: 'ovsec ovrec' }, h('div', { class: 'ovh' }, '記録（伸び・大会ごと・名場面）'), ...kids);
        el.append(sec);
      } catch (e) { /* 形の違う画面 */ }
      return el;
    };
  }
  // 経歴のページは窓（YA._v.modal）で開くので、窓の中身を作るところで足す
  const cp0 = YA.careerPage;
  if (cp0) {
    YA.careerPage = function (w, a) {
      const v = YA._v;
      const m0 = v && v.modal;
      if (m0) v.modal = (build) => m0((close) => {
        const el = build(close);
        try {
          const h = YA._ui && YA._ui.h;
          const kids = [];
          const g = YA.growthGraphEl(a, el.ownerDocument);
          if (g) kids.push(h('div', { class: 'h' }, '伸びの推移'), g);
          const t = YA.compTableEl(a);
          if (t) kids.push(h('div', { class: 'h' }, 'ユース時代の成績（大会ごと）'), t);
          const sc = YA.scenesEl(a);
          if (sc) kids.push(h('div', { class: 'h' }, '名場面'), sc);
          if (kids.length) el.append(h('div', { class: 'careerrec', style: 'display:flex;flex-direction:column;gap:4px;margin-top:6px' }, ...kids));
        } catch (e) { /* 形の違う画面 */ }
        return el;
      });
      try { return cp0.apply(this, arguments); } finally { if (m0) v.modal = m0; }
    };
  }
  // 卒業生の年ごとの成績に、その年の総合力を残す（伸びの推移のグラフに使う）
  const at0 = YA.alumniTick;
  YA.alumniTick = function (w) {
    const res = at0.apply(this, arguments);
    for (const a of w.alumni || []) { const s = (a.seasons || [])[(a.seasons || []).length - 1]; if (s && s.y === w.year && s.ovr == null && a.ovr != null) s.ovr = a.ovr; }
    return res;
  };
})();
