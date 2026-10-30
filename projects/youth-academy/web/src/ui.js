// 画面。試合前の布陣・戦い方、試合中の進行と停止中の操作、試合後のふり返り。
(function () {
  'use strict';
  const YA = (globalThis.YA = globalThis.YA || {});
  const W = 68;
  const L = 105;
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const POSN = { GK: 'GK', DF: 'DF', MF: 'MF', FW: 'FW' };
  // ポジションの札（色は大きな括り、文字は15個のうちの名前）
  const posChip = (p, label) => h('span', { class: 'pos ' + p.pos }, label || YA.POS_LABEL[p.main] || p.pos);
  // 適性の見え方：確かめていないうちは幅だけ（決定10）。向いている位置に気づいたら正確に出る
  function aptText(p, pos15) {
    const v = p.apt[pos15];
    if (p.bestKnown || pos15 === p.main) return String(Math.round(v));
    return Math.max(1, Math.round(v - 2)) + '〜' + Math.min(20, Math.round(v + 2));
  }
  function aptBlock(p) {
    if (p.pos === 'GK') return h('div', { class: 'note' }, 'GK（ほかのポジションの適性は、この版では見ません）');
    const list = YA.POS15.filter((q) => q !== 'GK').sort((a, b) => p.apt[b] - p.apt[a]);
    const top = list.slice(0, 3);
    if (top.indexOf(p.main) < 0) top.push(p.main);
    const row = h('div', { class: 'aptrow' }, top.map((q) => h('span', { class: 'aptchip' + (q === p.main ? ' cur' : '') + (p.bestKnown && q === p.best ? ' best' : '') }, YA.POS_LABEL[q], h('b', {}, aptText(p, q)), q === p.main ? h('span', { class: 'sub' }, '登録') : null)));
    const more = h('button', { class: 'btn sm', onclick: () => { if (YA._v) YA._v.modal((close) => aptModal(p, close)); } }, '全ポジション');
    return h('div', {}, h('div', { class: 'row', style: 'gap:5px;flex-wrap:wrap' }, row, more), h('div', { class: 'note', style: 'margin-top:2px' }, `利き足：${p.foot === 'R' ? '右' : p.foot === 'L' ? '左' : '両足'}（逆足の精度 ${p.ab['逆足の精度']}）` + (p.bestKnown ? `　向いているポジション：${YA.POS_LABEL[p.best]}` : '　本当に向いているポジションは、まだ分かっていません')));
  }
  function aptModal(p, close) {
    const g = h('div', { style: 'display:grid;grid-template-columns:repeat(5,1fr);gap:4px' }, YA.POS15.filter((q) => q !== 'GK').map((q) => h('div', { class: 'aptchip' + (q === p.main ? ' cur' : '') + (p.bestKnown && q === p.best ? ' best' : ''), style: 'justify-content:space-between;padding:6px 8px' }, YA.POS_LABEL[q], h('b', {}, aptText(p, q)))));
    return h('div', { class: 'sheet-in', style: 'flex:none;align-self:center;margin:auto;width:min(620px,96%);padding:12px;gap:7px' },
      h('div', { class: 'h' }, `${p.name} のポジション適性（1〜20）`), g,
      h('div', { class: 'note' }, '「〜」の幅は、まだ確かめていないという意味です。見る目の高い指導者や、試合での気づきで、本当に向いているポジションが分かってきます。向いていないポジションにも置けますが、力が出にくく、慣れるまで数か月かかります。'),
      h('button', { class: 'btn pri', onclick: close }, '閉じる'));
  }
  YA._apt = { posChip, aptBlock };

  // ---------- 小さな道具 ----------
  function h(tag, attrs, ...kids) {
    const e = document.createElement(tag);
    for (const [k, v] of Object.entries(attrs || {})) {
      if (v == null || v === false) continue;
      if (k === 'class') e.className = v;
      else if (k === 'style') e.style.cssText = v;
      else if (k.startsWith('on')) e.addEventListener(k.slice(2), v);
      else if (k === 'html') e.innerHTML = v;
      else e.setAttribute(k, v === true ? '' : v);
    }
    for (const c of kids.flat()) if (c != null && c !== false) e.append(c.nodeType ? c : document.createTextNode(String(c)));
    return e;
  }
  const svgNS = 'http://www.w3.org/2000/svg';
  function s(tag, attrs, ...kids) {
    const e = document.createElementNS(svgNS, tag);
    for (const [k, v] of Object.entries(attrs || {})) e.setAttribute(k, v);
    for (const c of kids.flat()) if (c != null) e.append(c.nodeType ? c : document.createTextNode(String(c)));
    return e;
  }

  // ---------- 保存（端末内。Flutter があればそちらにも写す） ----------
  const mem = {};
  const store = {
    get(k, d) {
      if (mem[k] != null) return mem[k];
      try {
        if (globalThis.__BOOT && globalThis.__BOOT.store && globalThis.__BOOT.store[k] != null) return JSON.parse(globalThis.__BOOT.store[k]);
      } catch (e) {}
      try {
        const v = localStorage.getItem('ya_' + k);
        if (v != null) return JSON.parse(v);
      } catch (e) {}
      return mem[k] != null ? mem[k] : d;
    },
    set(k, v) {
      mem[k] = v;
      const j = JSON.stringify(v);
      try {
        localStorage.setItem('ya_' + k, j);
      } catch (e) {}
      try {
        if (globalThis.YouthApp) globalThis.YouthApp.postMessage(JSON.stringify({ k, v: j }));
      } catch (e) {}
    },
  };

  // ---------- アプリの状態 ----------
  const app = {
    tab: 'home',
    view: 'pre', // pre | play | result
    opp: 0,
    seed: (Date.now() % 100000) + 1,
    cfg: null, // 保存した布陣・役割・戦い方
    autoStop: true,
    speed: '1',
    selected: 0,
    ptab: 'tactic',
    match: null,
    last: null,
  };

  function newOurs() {
    if (app.w) return YA.teamFromWorld(app.w, 'A');
    const t = YA.makeOurs(1);
    if (app.cfg) applyCfg(t, app.cfg);
    return t;
  }
  // 試合前の布陣・役割・戦い方の変更を、名簿（世界）に書き戻す
  function persistTeam(t) {
    const w = app.w;
    if (!w) return;
    w.lineupA = JSON.parse(JSON.stringify(t.lineup));
    w.benchA = t.bench.slice();
    w.tactic = JSON.parse(JSON.stringify(t.tactic));
    w.formation = t.formation;
    YA.saveWorld();
  }
  function snapCfg(t) {
    return JSON.parse(JSON.stringify({ lineup: t.lineup, bench: t.bench, tactic: t.tactic, formation: t.formation }));
  }
  function applyCfg(t, c) {
    t.lineup = JSON.parse(JSON.stringify(c.lineup));
    t.bench = c.bench.slice();
    t.tactic = JSON.parse(JSON.stringify(c.tactic));
    t.formation = c.formation;
  }
  function loadCfg() {
    const c = store.get('cfg', null);
    app.cfg = c && c.lineup && c.lineup.length === 11 && c.bench && c.bench.length === 9 ? c : null;
    app.autoStop = store.get('autoStop', true);
    app.slot = store.get('slot', 0);
    YA.sfx.on = store.get('sfx', true) !== false;
    const sw = store.get(YA.slotKey(app.slot), null);
    // 保存がなければ「新しく始める」画面（指導者の作成）から
    app.w = sw && sw.v >= 3 && sw.players && sw.lineupA ? sw : null;
    if (app.w) {
      if (!app.w.tut) app.w.tut = { on: false };
      [app.w.lineupA, app.w.lineupB].forEach((l) => l.forEach((sl, i) => YA.fixSlotRole(sl, i)));
      YA.saveWorld();
    }
  }

  // ---------- 選手の表示 ----------
  const surname = (p) => p.name.split(' ')[0];
  function persText(p) {
    const keys = Object.keys(p.pers).filter((g) => p.pers[g] !== 'ふつう');
    return keys.map((g) => p.pers[g]).join('・') || 'ふつう';
  }
  function persChips(p, all) {
    const keys = Object.keys(p.pers).filter((g) => all || p.pers[g] !== 'ふつう');
    return keys.map((g) => h('span', { class: 'chip pers' }, p.pers[g]));
  }
  // 棒の濃い部分＝いまの値、薄い緑＝次の+1までの進み。右の緑＝今月の伸び、灰＝今年の伸び
  function abBar(name, v, gain, prog, yr) {
    const c = v >= 15 ? '#1a9d57' : v >= 11 ? '#2f7ed8' : v >= 8 ? '#8fa3c4' : '#c7d0e0';
    const pg = prog && v < 20 ? Math.min(0.99, prog) : 0;
    const bar = h('div', { class: 'bar', style: 'position:relative' }, h('i', { style: `width:${(v / 20) * 100}%;background:${c}` }));
    if (pg > 0.05) bar.append(h('i', { style: `position:absolute;left:${(v / 20) * 100}%;top:0;height:100%;width:${(pg / 20) * 100}%;background:#9bdcb4;border-radius:0 3px 3px 0` }));
    return h('div', { class: 'ab' }, h('b', {}, name), bar, h('em', { style: `color:${v >= 15 ? '#1a9d57' : 'inherit'}` }, v),
      gain ? h('span', { style: 'color:#1a9d57;font-weight:900;font-size:10px;width:18px' }, '+' + gain) : h('span', { style: 'width:18px' }),
      yr ? h('span', { style: 'color:#7b879b;font-weight:700;font-size:9.5px;width:20px' }, (yr > 0 ? '+' : '') + yr) : h('span', { style: 'width:20px' }));
  }
  function playerCard(t, p, opts) {
    opts = opts || {};
    const idx = t.lineup.findIndex((x) => x.pid === p.id);
    const posKey = p.pos;
    const isGK = p.pos === 'GK';
    const top = (isGK ? YA.AB_GK : YA.AB_FIELD).map((n) => [n, p.ab[n]]).sort((a, b) => b[1] - a[1]);
    const wrap = h('div', {});
    wrap.append(
      h('div', { class: 'row' }, posChip(p), h('div', { class: 'grow' }, h('div', { class: 'h' }, `${p.num}  ${p.name}`), h('div', { class: 'sub' }, `${p.height}cm  /  調子 ${p.form > 0 ? '+' : ''}${p.form}  /  自信 ${Math.round(p.conf)}  /  戦術理解 ${Math.round(p.tu == null ? 40 : p.tu)}` + (p.nation && p.nation !== '日本' ? `  /  ${p.nation}` : '')))),
      h('div', { style: 'margin-top:5px' }, h('div', { class: 'note' }, 'ポジションの適性'), aptBlock(p)),
      h('div', { style: 'margin-top:5px' }, h('div', { class: 'note' }, '性格'), h('div', { class: 'row', style: 'flex-wrap:wrap;gap:3px' }, persChips(p, false))),
      h('div', { style: 'margin-top:5px' }, h('div', { class: 'note' }, '特性'), h('div', { class: 'row', style: 'flex-wrap:wrap;gap:3px' }, p.traits.length ? p.traits.map((x) => h('span', { class: 'chip trait' }, x)) : h('span', { class: 'sub' }, 'なし'))),
    );
    const notes = [];
    for (const g of Object.keys(p.pers)) if (YA.PERS_NOTE[p.pers[g]]) notes.push(`${p.pers[g]}：${YA.PERS_NOTE[p.pers[g]]}`);
    if (notes.length) wrap.append(h('div', { class: 'note', style: 'margin-top:4px' }, notes.join(' / ')));
    const list = opts.all ? (isGK ? YA.AB_GK.concat(['フィールド']) : YA.AB_FIELD) : top.slice(0, 8).map((x) => x[0]);
    if (opts.all) {
      const groups = isGK ? [['GK', YA.AB_GK]] : [['技術', YA.AB_TECH], ['頭', YA.AB_MENTAL], ['体', YA.AB_PHYS]];
      for (const [gn, ns] of groups) wrap.append(h('div', { class: 'note', style: 'margin:6px 0 2px;font-weight:800;color:var(--navy)' }, gn), h('div', { class: 'abg' }, ns.map((n) => abBar(n, p.ab[n], (YA.growthOf(p).month[n]) || (p.gain && p.gain[n]), p.prog && p.prog[n], YA.growthOf(p).year[n]))));
    } else {
      wrap.append(h('div', { class: 'note', style: 'margin:6px 0 2px;font-weight:800;color:var(--navy)' }, '目立つ能力'), h('div', { class: 'abg' }, list.map((n) => abBar(n, p.ab[n], (YA.growthOf(p).month[n]) || (p.gain && p.gain[n]), p.prog && p.prog[n], YA.growthOf(p).year[n]))));
    }
    return wrap;
  }

  // ---------- 布陣ボード（指で動かす・升目に吸い付く） ----------
  const GX = 4;
  const GY = 5;
  function boardEl(t, opts) {
    const wrap = h('div', { class: 'board' });
    const svg = s('svg', { viewBox: '-3 -3 74 118', preserveAspectRatio: 'xMidYMid meet' });
    const stripes = 10;
    for (let i = 0; i < stripes; i++) svg.append(s('rect', { x: -3, y: -3 + (111 / stripes) * i, width: 74, height: 111 / stripes + 0.1, fill: i % 2 ? '#2f9a5f' : '#37a869' }));
    const ln = { stroke: 'rgba(255,255,255,.9)', 'stroke-width': 0.5, fill: 'none' };
    svg.append(s('rect', Object.assign({ x: 0, y: 0, width: W, height: L }, ln)), s('line', Object.assign({ x1: 0, y1: L / 2, x2: W, y2: L / 2 }, ln)), s('circle', Object.assign({ cx: 34, cy: L / 2, r: 9.15 }, ln)));
    for (const [y0, dir] of [[0, 1], [L, -1]]) {
      svg.append(s('rect', Object.assign({ x: 13.84, y: dir > 0 ? y0 : y0 - 16.5, width: 40.32, height: 16.5 }, ln)), s('rect', Object.assign({ x: 24.84, y: dir > 0 ? y0 : y0 - 5.5, width: 18.32, height: 5.5 }, ln)));
    }
    // 升目の点
    const grid = s('g', { opacity: 0.0, id: 'gridDots' });
    for (let gx = 0; gx <= W; gx += GX) for (let gy = 0; gy <= L; gy += GY) grid.append(s('circle', { cx: gx, cy: gy, r: 0.35, fill: '#fff' }));
    svg.append(grid);
    const layer = s('g', {});
    svg.append(layer);
    wrap.append(svg);
    const toM = (i) => ({ mx: t.lineup[i].x * W, my: 4 + t.lineup[i].y * 78 });
    const colors = { GK: '#f39c12', DF: '#2f7ed8', MF: '#16a34a', FW: '#e0453a' };
    let drag = null;
    function draw() {
      layer.replaceChildren();
      t.lineup.forEach((sl, i) => {
        const p = t.players[sl.pid];
        const { mx, my } = toM(i);
        const sx = mx;
        const sy = L - my; // 上へ攻める
        const pos = YA.posOfSlot(sl, i);
        const p15 = YA.pos15OfSlot(sl, i);
        const pen = YA.slotPenalty(p, p15);
        const sel = opts.selected && opts.selected() === i;
        const g = s('g', { transform: `translate(${sx} ${sy})`, style: 'cursor:grab' });
        if (sel) g.append(s('circle', { r: 6.4, fill: 'none', stroke: '#ffd54a', 'stroke-width': 1.1 }));
        const fit = YA.Match.prototype.roleFit.call(null, t, i);
        g.append(s('circle', { r: 4.6, cx: 0.4, cy: 0.9, fill: 'rgba(0,0,0,.3)' }), s('circle', { r: 4.6, fill: colors[pos], stroke: '#fff', 'stroke-width': 0.9 }), s('text', { y: 1.6, 'text-anchor': 'middle', fill: '#fff', 'font-size': 5, 'font-weight': 900 }, p.num));
        g.append(s('text', { y: -6.2, 'text-anchor': 'middle', fill: '#fff6c2', 'font-size': 3.3, 'font-weight': 900, stroke: 'rgba(0,0,0,.5)', 'stroke-width': 0.7, 'paint-order': 'stroke' }, YA.POS_LABEL[p15]));
        g.append(s('text', { y: 9.4, 'text-anchor': 'middle', fill: '#fff', 'font-size': 3.5, 'font-weight': 800, stroke: 'rgba(0,0,0,.45)', 'stroke-width': 0.7, 'paint-order': 'stroke' }, surname(p)));
        g.append(s('text', { y: 13, 'text-anchor': 'middle', fill: fit < 0 || pen > 0.06 ? '#ffb3b3' : fit > 0 ? '#fff3b0' : '#e8f5ec', 'font-size': 3, 'font-weight': 700, stroke: 'rgba(0,0,0,.45)', 'stroke-width': 0.6, 'paint-order': 'stroke' }, (sl.role.length > 6 ? sl.role.slice(0, 6) + '…' : sl.role) + '(' + (YA.DUTY[sl.duty] ? YA.DUTY[sl.duty].short : '') + ')' + (fit > 0 ? ' ◎' : fit < 0 ? ' ×' : '') + (pen > 0.06 ? ' ▽' : '')));
        g.addEventListener('pointerdown', (ev) => {
          ev.preventDefault();
          g.setPointerCapture(ev.pointerId);
          drag = { i, g, moved: false };
          opts.onSelect && opts.onSelect(i);
          grid.setAttribute('opacity', 0.55);
        });
        g.addEventListener('pointermove', (ev) => {
          if (!drag || drag.i !== i) return;
          const pt = svg.createSVGPoint();
          pt.x = ev.clientX;
          pt.y = ev.clientY;
          const q = pt.matrixTransform(svg.getScreenCTM().inverse());
          const gx = clamp(Math.round(q.x / GX) * GX, 4, W - 4);
          const gy = clamp(Math.round((L - q.y) / GY) * GY, 5, L - 8);
          drag.gx = gx;
          drag.gy = gy;
          drag.moved = true;
          g.setAttribute('transform', `translate(${gx} ${L - gy})`);
        });
        const up = () => {
          if (!drag || drag.i !== i) return;
          grid.setAttribute('opacity', 0);
          if (drag.moved && drag.gx != null) {
            const nx = drag.gx / W;
            const ny = (drag.gy - 4) / 78;
            const other = t.lineup.findIndex((x, j) => j !== i && Math.abs(x.x - nx) < 0.02 && Math.abs(x.y - ny) < 0.02);
            if (other >= 0) {
              t.lineup[other].x = t.lineup[i].x;
              t.lineup[other].y = t.lineup[i].y;
              fixRole(t, other);
            }
            t.lineup[i].x = nx;
            t.lineup[i].y = clamp(ny, 0.01, 0.97);
            fixRole(t, i);
            t.formation = 'カスタム';
            opts.onChange && opts.onChange();
          }
          drag = null;
          draw();
        };
        g.addEventListener('pointerup', up);
        g.addEventListener('pointercancel', up);
        layer.append(g);
      });
    }
    draw();
    wrap.redraw = draw;
    return wrap;
  }
  function fixRole(t, i) {
    YA.fixSlotRole(t.lineup[i], i);
  }

  // 定番の形を当てはめる。近い選手が近い位置に入る
  function applyFormation(t, name) {
    const fm = YA.FORMATIONS[name];
    const cur = t.lineup.map((s2, i) => ({ i, pid: s2.pid, p: t.players[s2.pid], role: s2.role }));
    const left = cur.slice();
    const out = new Array(11);
    // GKを先に。ほかは、その位置の適性が一番高い選手を置く
    const order = fm.map((_, k) => k).sort((a1, b1) => (YA.pos15OfSlot(fm[a1], a1) === 'GK' ? -1 : 0) - (YA.pos15OfSlot(fm[b1], b1) === 'GK' ? -1 : 0));
    for (const k of order) {
      const p15 = YA.pos15OfSlot(fm[k], k);
      let bi = -1;
      let bv = -1e9;
      left.forEach((c, j) => {
        if ((c.p.pos === 'GK') !== (p15 === 'GK')) return;
        const v = (c.p.apt ? c.p.apt[p15] : 10) + (c.p.main === p15 ? 0.4 : 0);
        if (v > bv) { bv = v; bi = j; }
      });
      if (bi < 0) bi = 0;
      const c = left.splice(bi, 1)[0];
      out[k] = { pid: c.pid, x: fm[k].x, y: fm[k].y, role: c.role };
    }
    t.lineup = out;
    t.lineup.forEach((_, i) => fixRole(t, i));
    t.formation = name;
  }

  // ---------- 戦術パネル（試合前と停止中で共通） ----------
  function tacticPanel(t, o) {
    const root = h('div', { class: o.sheet ? 'sheet-body' : 'pre-body' });
    const st = { tab: o.tabs[0][0], sel: 0, subOut: null, subIn: null, instrTarget: null, shoutTarget: 'team', msgs: [] };
    if (o.state) Object.assign(st, o.state);
    let board;
    const right = h('div', { class: 'panel' });
    const tabs = h('div', { class: 'tabs' });
    const body = h('div', { class: 'card pbody' });
    right.append(tabs, body);

    const leftWrap = h('div', { class: 'boardwrap' });
    const fmRow = h('div', { class: 'fm-row' });
    const saveRow = h('div', { class: 'fm-row' });
    function onChange() {
      o.onChange && o.onChange();
      renderBody();
      renderFm();
    }
    board = boardEl(t, { selected: () => st.sel, onSelect: (i) => { st.sel = i; if (o.tabs.some((x) => x[0] === 'role') && st.tab !== 'role' && st.tab !== 'sub') { st.tab = 'role'; renderTabs(); } renderBody(); board.redraw(); }, onChange });
    leftWrap.append(board, fmRow, saveRow);
    let slotSel = 0;
    function renderFm() {
      fmRow.replaceChildren(
        ...Object.keys(YA.FORMATIONS).map((n) => h('button', { class: 'btn sm' + (t.formation === n ? ' on' : ''), onclick: () => { applyFormation(t, n); onChange(); board.redraw(); } }, n)),
      );
      const saved = store.get('forms', [null, null, null]);
      saveRow.replaceChildren(
        h('span', { class: 'sub', style: 'align-self:center;font-weight:800' }, '保存'),
        ...[0, 1, 2].map((k) => h('button', { class: 'btn sm' + (slotSel === k ? ' on' : ''), onclick: () => { slotSel = k; renderFm(); } }, saved[k] ? `型${k + 1}●` : `型${k + 1}`)),
        h('button', { class: 'btn sm', onclick: () => { const sv = store.get('forms', [null, null, null]); sv[slotSel] = { slots: t.lineup.map((x) => ({ x: x.x, y: x.y, role: x.role, duty: x.duty })) }; store.set('forms', sv); st.msgs = ['型' + (slotSel + 1) + 'に保存しました']; renderFm(); renderBody(); } }, '保存'),
        h('button', { class: 'btn sm', onclick: () => { const sv = store.get('forms', [null, null, null]); const f2 = sv[slotSel]; if (!f2) { st.msgs = ['型' + (slotSel + 1) + 'はまだ空です']; renderBody(); return; } f2.slots.forEach((x, i) => { t.lineup[i].x = x.x; t.lineup[i].y = x.y; if (x.role) { t.lineup[i].role = x.role; t.lineup[i].duty = x.duty; } fixRole(t, i); }); t.formation = 'カスタム'; board.redraw(); onChange(); } }, '呼出'),
      );
    }

    function renderTabs() {
      tabs.replaceChildren(...o.tabs.map(([k, label]) => h('button', { class: 'btn' + (st.tab === k ? ' on' : ''), onclick: () => { st.tab = k; renderTabs(); renderBody(); } }, label)));
    }
    const msgBox = () => (st.msgs.length ? h('div', { class: 'msglog' }, st.msgs.slice(-4).map((m) => h('div', {}, m))) : null);

    function renderBody() {
      body.replaceChildren();
      const sl = t.lineup[st.sel];
      const p = t.players[sl.pid];
      if (st.tab === 'tactic') {
        body.append(h('div', { class: 'h' }, '戦い方の型'), h('div', { class: 'fm-row', style: 'margin:4px 0 6px' }, Object.keys(YA.TACTICS).map((n) => h('button', { class: 'btn sm' + (t.tactic.type === n ? ' on' : ''), onclick: () => { o.match ? o.match.setType(t, n) : (t.tactic = Object.assign({ type: n, dir: t.tactic.dir || 0 }, YA.TACTICS[n])); onChange(); } }, n + ' ' + YA.tacticFitOf(t, n).mark))));
        {
          const cur = YA.tacticFitOf(t, t.tactic.type);
          const pf = YA.TAC_PROFILE[t.tactic.type];
          if (pf) {
            const wk = cur.abs.slice().sort((x, y) => x[1] - y[1]).slice(0, 2).map((x) => `${x[0]}${x[1].toFixed(1)}`).join('・');
            body.append(h('div', { class: 'insight', style: 'margin-bottom:6px' }, h('b', {}, `いまのスタメンとの相性 ${cur.mark}`), `　${pf.why}。大事な能力：${pf.abs.join('・')}（先発の平均で低いのは ${wk}）。この戦術で練習すると、その能力が少し伸びやすくなります。◎○△✕は、各戦術とスタメンの相性です。`));
          }
        }
        for (const [k, label, lo, hi] of YA.KNOBS) {
          const inp = h('input', { type: 'range', min: 0, max: 100, value: Math.round(t.tactic[k] * 100) });
          inp.addEventListener('input', () => { t.tactic[k] = inp.value / 100; t.tactic.type = 'カスタム'; o.onChange && o.onChange(); });
          inp.addEventListener('change', () => renderBody());
          body.append(h('div', { class: 'knob' }, h('label', {}, label), h('span', { class: 'l' }, lo), inp, h('span', {}, hi)));
        }
        body.append(h('div', { class: 'h', style: 'margin-top:6px' }, '攻める方向'), h('div', { class: 'fm-row', style: 'margin-top:3px' }, [['左中心', -1], ['両サイド', 0], ['右中心', 1]].map(([n, v]) => h('button', { class: 'btn sm' + ((t.tactic.dir || 0) === v ? ' on' : ''), onclick: () => { t.tactic.dir = v; onChange(); } }, n))));
        // クロスの種類・セットプレーのキッカー（決定38）
        body.append(h('div', { class: 'h', style: 'margin-top:6px' }, 'クロスの種類'), h('div', { class: 'fm-row', style: 'margin-top:3px' }, [['', '標準'], ['high', '高い（長身が生きる）'], ['early', '早い（アーリー）'], ['low', '低い（ニアに合わせる）']].map(([k, n]) => h('button', { class: 'btn sm' + ((t.tactic.crossType || '') === k ? ' on' : ''), onclick: () => { t.tactic.crossType = k; onChange(); } }, n))));
        const onPitch = t.lineup.map((x) => t.players[x.pid]);
        const sel = (key, label) => h('div', { class: 'row', style: 'gap:6px;margin:3px 0' }, h('span', { style: 'width:78px;font-weight:800' }, label), (() => { const s2 = h('select', { style: 'flex:1;padding:5px;border:1px solid #b9c7de;border-radius:8px;font:inherit' }, h('option', { value: '' }, '自動（得意な選手）'), onPitch.map((p) => h('option', { value: p.id }, `${p.num} ${p.name}`))); s2.value = t.tactic[key] && onPitch.some((p) => p.id === t.tactic[key]) ? t.tactic[key] : ''; s2.addEventListener('change', () => { t.tactic[key] = s2.value || null; o.onChange && o.onChange(); }); return s2; })());
        body.append(h('div', { class: 'h', style: 'margin-top:6px' }, 'セットプレーのキッカー'), sel('fk', 'フリーキック'), sel('ck', 'コーナー'), sel('pk', 'PK'));
        const rep = t.tactRep != null ? t.tactRep : 1;
        body.append(h('div', { class: 'note', style: 'margin-top:8px' }, `戦い方の浸透：${Math.round(rep * 100)}%。同じ戦い方を続けるほど、つまみどおりに動きます（変えると下がります）。守備のマークは「指示」で、相手の1人に付かせられます。`));
      } else if (st.tab === 'role') {
        const p15 = YA.pos15OfSlot(sl, st.sel);
        body.append(h('div', { class: 'row', style: 'gap:6px;margin-bottom:4px' }, posChip(p), h('b', {}, `${p.num} ${p.name}`), h('span', { class: 'sub grow' }, `${p.height}cm ／ 自信 ${Math.round(p.conf)} ／ 利き足 ${p.foot === 'R' ? '右' : p.foot === 'L' ? '左' : '両'}`)), aptBlock(p));
        body.append(h('div', { class: 'h', style: 'margin-top:8px' }, `いまの位置：${YA.POS_LABEL[p15]}（${YA.POS_NAME[p15]}）の役割`));
        const pen0 = YA.slotPenalty(p, p15);
        if (p.main !== p15) body.append(h('div', { class: 'note', style: 'color:' + (pen0 > 0.06 ? '#b02020' : 'var(--sub)') }, `この選手の登録は${YA.POS_LABEL[p.main]}。${YA.POS_LABEL[p15]}の適性は${aptText(p, p15)}` + (pen0 > 0.06 ? 'で、力が出にくい配置です（慣れるまで時間がかかります）' : pen0 < -0.01 ? '。向いている配置で、少し力が出ます' : '。')));
        // 任務（2段目）：選んだ役割で選べるものだけ押せる
        const curRd = YA.ROLE_DEF[sl.role];
        const dutyBox = h('div', { class: 'card', style: 'padding:6px 8px;margin:4px 0 6px;background:#f5f8fd' });
        dutyBox.append(h('div', { class: 'row', style: 'gap:5px;flex-wrap:wrap' }, h('b', {}, '任務'), ['def', 'sup', 'att', 'stop', 'cover'].filter((k) => curRd.duties.indexOf(k) >= 0 || (k !== 'stop' && k !== 'cover')).map((k) => {
          const allowed = curRd.duties.indexOf(k) >= 0;
          return h('button', { class: 'btn sm' + (sl.duty === k ? ' on' : ''), disabled: !allowed, onclick: () => { sl.duty = k; board.redraw(); onChange(); } }, YA.DUTY[k].label);
        }), h('span', { class: 'grow' })), h('div', { class: 'note', style: 'margin-top:3px' }, (YA.DUTY[sl.duty] || YA.DUTY.sup).note + '。（深さ・戻り・場面の出やすさが変わります）'));
        body.append(dutyBox);
        body.append(h('div', { class: 'h' }, '役割'));
        for (const r of YA.ROLES15[p15]) {
          const save = sl.role;
          const saveD = sl.duty;
          sl.role = r;
          const rdr = YA.ROLE_DEF[r];
          if (!sl.duty || rdr.duties.indexOf(sl.duty) < 0) sl.duty = YA.defaultDuty(r);
          const fit = YA.Match.prototype.roleFit.call(null, t, st.sel);
          sl.role = save;
          sl.duty = saveD;
          const rd = rdr;
          body.append(h('button', { class: 'rolecard' + (save === r ? ' on' : ''), onclick: () => { if (sl.role !== r) YA.setRole(sl, st.sel, r); board.redraw(); onChange(); } },
            h('div', { class: 'grow' }, h('b', {}, r), h('div', {}, h('span', { class: 'd' }, rd.note)), h('div', {}, h('span', { class: 'd' }, '任務：' + rd.duties.map((k) => YA.DUTY[k].label).join('・') + ' ／ 合う特性：' + rd.traits.slice(0, 3).join('・')))),
            fit > 0 ? h('span', { class: 'fit good' }, 'ハマる') : fit < 0 ? h('span', { class: 'fit bad' }, '合わない') : null));
        }
        body.append(h('div', { class: 'note', style: 'margin-top:5px' }, '役割が特性や能力と合うと力が出て、合わない役割を続けると不満が出ます。役割をこなすうちに、戦術の理解が伸びます。'));
        body.append(h('div', { style: 'margin-top:8px;border-top:1px dashed var(--line);padding-top:6px' }, playerCard(t, p)));
        if (!o.sheet) {
          body.append(h('div', { class: 'h', style: 'margin-top:8px' }, 'ベンチと入れ替える'));
          body.append(h('div', { class: 'plist' }, t.bench.map((bid) => {
            const bp = t.players[bid];
            const ok2 = (bp.pos === 'GK') === (p.pos === 'GK') && !(bp.inj > 0);
            return h('button', { class: 'pitem', style: ok2 ? '' : 'opacity:.35', onclick: () => { if (!ok2) return; const bi = t.bench.indexOf(bid); t.bench[bi] = sl.pid; sl.pid = bid; fixRole(t, st.sel); board.redraw(); onChange(); } }, posChip(bp), h('span', { class: 'num' }, bp.num), h('span', { class: 'nm grow' }, bp.name), bp.inj > 0 ? h('span', { class: 'fit bad' }, '怪我' + bp.inj + '週') : h('span', { class: 'sub' }, bp.traits.slice(0, 2).join('・')));
          })));
        }
      } else if (st.tab === 'sub') {
        const m = o.match;
        const left = 5 - t.subsUsed;
        const win = 3 - t.windowsUsed + (t._winOpen ? 1 : 0);
        body.append(h('div', { class: 'row' }, h('div', { class: 'h grow' }, `交代  あと${left}人 / 機会あと${m && m.isHalf() ? '（ハーフタイムは数えない）' : win + '回'}`), h('button', { class: 'btn pri sm', disabled: !(st.subOut && st.subIn), onclick: () => { const r = m.substitute(t, st.subOut, st.subIn); if (!r.ok) st.msgs = [r.msg]; else { st.msgs = ['交代しました']; st.subOut = st.subIn = null; board.redraw(); o.onChange && o.onChange(); } renderTabs(); renderBody(); } }, '交代する')));
        const cols = h('div', { class: 'row', style: 'align-items:flex-start;gap:8px;margin-top:6px' });
        const lo = h('div', { class: 'grow plist' }, h('div', { class: 'note' }, '下げる選手（ピッチ）'));
        t.lineup.forEach((x, i) => {
          const q = t.players[x.pid];
          const pc = YA.posOfSlot(x, i);
          lo.append(h('button', { class: 'pitem' + (st.subOut === q.id ? ' on' : ''), onclick: () => { st.subOut = q.id; renderBody(); } }, posChip(q, YA.POS_LABEL[YA.pos15OfSlot(x, i)]), h('span', { class: 'num' }, q.num), h('span', { class: 'nm grow' }, surname(q)), h('div', { class: 'bar stam' }, h('i', { style: `width:${q.stam}%;background:${q.stam < 45 ? '#d63a3a' : q.stam < 70 ? '#f0a020' : '#1a9d57'}` }))));
        });
        const li = h('div', { class: 'grow plist' }, h('div', { class: 'note' }, '入れる選手（ベンチ）'));
        t.bench.forEach((bid) => {
          const q = t.players[bid];
          li.append(h('button', { class: 'pitem' + (st.subIn === q.id ? ' on' : ''), onclick: () => { st.subIn = q.id; renderBody(); } }, posChip(q), h('span', { class: 'num' }, q.num), h('span', { class: 'nm grow' }, surname(q)), h('span', { class: 'sub', style: 'font-size:9.5px' }, q.traits.slice(0, 1).join(''))));
        });
        cols.append(lo, li);
        body.append(cols);
        const sel = st.subIn ? t.players[st.subIn] : null;
        if (sel) body.append(h('div', { style: 'margin-top:6px;border-top:1px dashed var(--line);padding-top:6px' }, playerCard(t, sel)));
      } else if (st.tab === 'instr') {
        const m = o.match;
        const on = t.lineup.map((x, i) => ({ p: t.players[x.pid], i }));
        body.append(h('div', { class: 'h' }, '1人への指示'), h('div', { class: 'note' }, '選手を選んで指示します。頑固な子やマイペースな子は聞き流すことがあります。'));
        const tgt = st.instrTarget || on[8].p.id;
        body.append(h('div', { class: 'fm-row', style: 'margin:5px 0' }, on.map(({ p: q }) => h('button', { class: 'btn sm' + (tgt === q.id ? ' on' : ''), onclick: () => { st.instrTarget = q.id; renderBody(); } }, q.num + ' ' + surname(q)))));
        const q = t.players[tgt];
        const cur = t.instr[tgt];
        body.append(h('div', { class: 'row' }, h('div', { class: 'grow' }, h('b', {}, `${q.num} ${q.name}`), h('div', { class: 'row', style: 'gap:3px;flex-wrap:wrap;margin-top:2px' }, persChips(q, false))), cur ? h('span', { class: 'chip instr' }, '指示中：' + (cur.dribble ? '仕掛けろ' : cur.back ? '下がって守れ' : cur.shoot ? 'シュートを打て' : cur.mark ? '付け' : '')) : null));
        const give = (k, target) => { const r = m.instruct(t, tgt, k, target); st.msgs.push(r.msg); renderBody(); };
        body.append(h('div', { class: 'fm-row', style: 'margin-top:6px' }, [['dribble', '仕掛けろ'], ['back', '下がって守れ'], ['shoot', 'シュートを打て'], ['clear', '指示を外す']].map(([k, n]) => h('button', { class: 'btn', onclick: () => give(k) }, n))));
        body.append(h('div', { class: 'note', style: 'margin-top:8px' }, '相手の1人に付かせる'));
        const opp = m.other(t);
        body.append(h('div', { class: 'fm-row', style: 'margin-top:3px' }, opp.lineup.slice(1).map((x) => { const z = opp.players[x.pid]; return h('button', { class: 'btn sm', onclick: () => give('mark', z.id) }, z.num + ' ' + surname(z)); })));
        body.append(msgBox());
      } else if (st.tab === 'shout') {
        const m = o.match;
        body.append(h('div', { class: 'h' }, '声かけ'), h('div', { class: 'note' }, '性格しだいで調子や自信が上がったり下がったりします。同じ相手には8分あけます。'));
        const tg = st.shoutTarget;
        body.append(h('div', { class: 'fm-row', style: 'margin:5px 0' }, h('button', { class: 'btn sm' + (tg === 'team' ? ' on' : ''), onclick: () => { st.shoutTarget = 'team'; renderBody(); } }, 'チーム全体'), t.lineup.map((x) => { const q = t.players[x.pid]; return h('button', { class: 'btn sm' + (tg === q.id ? ' on' : ''), onclick: () => { st.shoutTarget = q.id; renderBody(); } }, q.num + ' ' + surname(q)); })));
        if (tg !== 'team') { const q = t.players[tg]; body.append(h('div', { class: 'row', style: 'gap:3px;flex-wrap:wrap' }, h('b', {}, q.name), persChips(q, false), h('span', { class: 'sub' }, `自信 ${Math.round(q.conf)}`))); }
        const say = (k) => { const r = m.shout(t, tg === 'team' ? null : tg, k); st.msgs.push(r.msg); o.onChange && o.onChange(); renderBody(); };
        body.append(h('div', { class: 'fm-row', style: 'margin-top:6px' }, [['fire', '激励'], ['calm', '落ち着け'], ['praise', '褒める'], ['scold', '叱る']].map(([k, n]) => h('button', { class: 'btn', onclick: () => say(k) }, n))));
        body.append(msgBox());
      } else if (st.tab === 'opp') {
        body.append(h('div', { class: 'h' }, '相手の分析'));
        const oo = o.opp;
        body.append(h('div', { class: 'note', style: 'margin:3px 0 6px' }, oo.desc));
        const ot = o.oppTeam;
        const lvl = app.w && YA.analysisLevel ? YA.analysisLevel(app.w) : 2;
        const lines = app.w && YA.analysis ? YA.analysis(app.w, ot, oo) : [`型：${ot.tactic.type} / 布陣：${ot.formation}`];
        body.append(h('div', { class: 'plist' }, lines.map((l) => h('div', { class: 'insight', style: 'margin-bottom:3px' }, l))));
        body.append(h('div', { class: 'plist', style: 'margin-top:6px' }, ot.lineup.map((x) => { const q = ot.players[x.pid]; return h('div', { class: 'pitem' }, h('span', { class: 'num' }, q.num), h('span', { class: 'nm' }, q.name), h('span', { class: 'sub grow' }, lvl >= 2 ? q.traits.join('・') : '')); })));
      }
      if (st.tab !== 'instr' && st.tab !== 'shout' && st.msgs.length) body.append(msgBox());
    }
    renderTabs();
    renderFm();
    renderBody();
    root.append(leftWrap, right);
    root.refresh = () => { board.redraw(); renderTabs(); renderBody(); };
    root.state = st;
    return root;
  }

  // ---------- 画面の枠（左の縦タブ） ----------
  const TABS = [['home', 'ホーム', '⌂'], ['players', '選手', '☺'], ['train', '練習', '✎'], ['match', '試合', '⚽'], ['club', 'クラブ', '▦'], ['more', 'ほか', '⋯']];
  function renderRail() {
    const rail = document.getElementById('rail');
    rail.replaceChildren(h('div', { class: 'logo' }, 'ユースの', h('br'), '系譜'), ...TABS.map(([k, n, ic]) => h('button', { class: 'tab' + (app.tab === k ? ' on' : ''), onclick: () => { if (app.view === 'play') return; app.tab = k; render(); } }, h('i', {}, ic), n)));
  }
  function render() {
    const root = document.getElementById('app');
    root.classList.toggle('full', app.view === 'play');
    renderRail();
    const main = document.getElementById('main');
    main.replaceChildren();
    cleanupPlay();
    if (!app.w) {
      root.classList.add('full');
      YA.views.newgame(main);
      return;
    }
    if (app.w.retired) {
      root.classList.add('full');
      YA.views.retired(main);
      return;
    }
    if (app.tab === 'match') {
      if (app.view === 'pre') viewPre(main);
      else if (app.view === 'play') viewPlay(main);
      else viewResult(main);
    } else if (YA.views && YA.views[app.tab]) YA.views[app.tab](main);
    else viewPlaceholder(main);
    // 最初の1か月の案内（決定77）
    const tt = app.view !== 'play' ? YA.tutorialText(app.w) : null;
    if (tt) main.prepend(h('div', { class: 'tut' }, h('span', { class: 'tutb' }, '案内'), h('span', { class: 'grow' }, tt), h('button', { class: 'btn sm', onclick: () => { app.w.tut.on = false; YA.saveWorld(); render(); } }, '消す')));
  }

  function viewPlaceholder(main) {
    const info = {
      home: ['ホーム', '今週やること・お知らせ・会話・日程。「次の週へ」「次の試合まで」で進めます。'],
      train: ['練習', '曜日ごとのメニュー、選手ごとの重点と特性練習、休ませる、練習試合。'],
      club: ['クラブ', '予算・スタッフ・施設と寮・信頼度・契約・トップ・スカウトとセレクション・U-15。'],
      more: ['ほか', '名鑑・記録・年表・ショップ・設定。'],
    }[app.tab];
    main.append(h('div', { class: 'card big-note grow' }, h('div', { class: 'h', style: 'font-size:16px' }, info[0]), h('p', {}, info[1]), h('p', { class: 'sub' }, 'この試作は「試合」だけを遊べます。ほかの画面は、試合が面白いと分かってから作ります。'), h('button', { class: 'btn pri', onclick: () => { app.tab = 'match'; render(); } }, '試合へ')));
  }

  // ---------- 選手一覧 ----------
  function viewPlayers(main) {
    const t = newOurs();
    const all = t.lineup.map((x) => t.players[x.pid]).concat(t.bench.map((id) => t.players[id]));
    const sel = clamp(app.pSel || 0, 0, all.length - 1);
    const list = h('div', { class: 'card pbody scroll', style: 'width:200px;flex:none;padding:6px' }, h('div', { class: 'plist' }, all.map((q, i) => h('button', { class: 'pitem' + (i === sel ? ' on' : ''), onclick: () => { app.pSel = i; render(); } }, posChip(q), h('span', { class: 'num' }, q.num), h('span', { class: 'nm grow' }, q.name), i < 11 ? h('span', { class: 'chip gray' }, 'A') : null))));
    const detail = h('div', { class: 'card pbody' }, playerCard(t, all[sel], { all: true }));
    main.append(h('div', { class: 'row', style: 'flex:1;min-height:0;align-items:stretch' }, list, detail));
  }

  // ---------- 試合前 ----------
  let preState = null;
  function viewPre(main) {
    const t = newOurs();
    const w = app.w;
    const sched = !!(w && w.phase === 'match' && !app.free);
    const opp = sched ? YA.opponentOf(w) : YA.OPPONENTS[app.opp];
    const oppTeam = YA.makeOpponent(opp, sched ? w.seed + w.week * 7 + w.year : app.seed * 3 + app.opp);
    const wrap = h('div', { class: 'pre' });
    const top = h('div', { class: 'pre-top' });
    if (sched) {
      const cal = YA.calendar(w.week);
      top.append(h('div', { class: 'opp on', style: 'cursor:default' }, h('b', {}, h('span', { class: 'sw', style: 'background:' + opp.color }), `${opp.kindLabel || ''}  ${opp.home ? 'ホーム' : 'アウェイ'}  vs ${opp.name}`), h('span', {}, opp.desc + '（フリー対戦に切り替えると成績に残りません）')));
      top.append(h('button', { class: 'btn sm', style: 'align-self:center', onclick: () => { app.free = true; render(); } }, 'フリー対戦'));
    } else if (app.free && w && w.phase === 'match') top.append(h('button', { class: 'btn sm', style: 'align-self:center', onclick: () => { app.free = false; render(); } }, '今週の試合へ戻る'));
    if (!sched) YA.OPPONENTS.forEach((o2, i) => top.append(h('button', { class: 'opp' + (i === app.opp ? ' on' : ''), onclick: () => { persistTeam(t); app.opp = i; render(); } }, h('b', {}, h('span', { class: 'sw', style: 'background:' + o2.color }), o2.name), h('span', {}, o2.desc))));
    const kick = h('div', { class: 'kick' },
      h('button', { class: 'btn pri', style: 'flex:1;font-size:14px', onclick: () => { persistTeam(t); startMatch(t, oppTeam, opp, sched); } }, 'キックオフ'),
      h('button', { class: 'btn sm', onclick: () => { persistTeam(t); simulateAll(t, oppTeam, opp, sched); } }, '全シミュレーション'));
    top.append(kick);
    const panel = tacticPanel(t, { tabs: [['tactic', '戦い方'], ['role', '選手と役割'], ['opp', '相手の分析']], opp, oppTeam, onChange: () => { persistTeam(t); }, state: preState || {} });
    preState = panel.state;
    wrap.append(top, panel);
    main.append(wrap);
  }

  // ---------- 試合中 ----------
  let play = null;
  function cleanupPlay() {
    if (play && play.raf) cancelAnimationFrame(play.raf);
    if (play) globalThis.removeEventListener('resize', play.onResize);
    play = null;
  }
  function finishMatch(m, e) {
    const summary = e && e.summary ? e.summary : m.summary();
    if (m.scheduled && !m.applied && app.w) {
      m.applied = true;
      YA.applyMatch(app.w, m, 'A', m.opp, true);
      app.w.phase = 'after';
      app.w.matchDone = true;
      YA.saveWorld();
    }
    app.last = { m, summary };
  }
  function startMatch(t, oppTeam, opp, sched) {
    app.seed = (app.seed * 1103515245 + 12345) % 2147483647;
    const m = new YA.Match({ seed: sched ? app.w.seed + app.w.week * 3 + app.w.year : app.seed, home: t, away: oppTeam, settings: { autoStop: app.autoStop } });
    m.opp = opp;
    m.scheduled = !!sched;
    app.match = m;
    app.view = 'play';
    render();
  }

  // 見ずに最後まで回す。止まる節目は無視し、交代・指示はしない（布陣と戦い方は試合前のまま）
  function simulateAll(t, oppTeam, opp, sched) {
    app.seed = (app.seed * 1103515245 + 12345) % 2147483647;
    const m = new YA.Match({ seed: sched ? app.w.seed + app.w.week * 3 + app.w.year : app.seed, home: t, away: oppTeam, settings: { autoStop: false } });
    m.opp = opp;
    m.scheduled = !!sched;
    let e;
    let g = 0;
    while (!m.finished && g++ < 5000) {
      const ev = m.step();
      if (ev.type === 'full') e = ev;
    }
    app.match = m;
    finishMatch(m, e);
    app.view = 'result';
    render();
  }

  function viewPlay(main) {
    const m = app.match;
    const wrap = h('div', { class: 'play' });
    const scoreHome = h('span', { class: 'sc' }, '0');
    const scoreAway = h('span', { class: 'sc' }, '0');
    const clock = h('div', { class: 'clock' }, "0'");
    const stopBtn = h('button', { class: 'btn pri sm', style: 'min-height:34px;min-width:76px' }, '止める');
    const autoBtn = h('button', { class: 'btn sm', style: 'min-height:34px' });
    const skipBtn = h('button', { class: 'btn sm', style: 'min-height:34px', onclick: () => { cleanupPlay(); let e; let g = 0; while (!m.finished && g++ < 5000) { const ev = m.step(); if (ev.type === 'full') e = ev; } finishMatch(m, e); app.view = 'result'; render(); } }, '結果まで');
    const top = h('div', { class: 'topbar' }, h('div', { class: 'scoreboard' }, h('span', { class: 'tn' }, m.home.short), scoreHome, h('span', { style: 'color:#8fa3c4' }, '-'), scoreAway, h('span', { class: 'tn' }, m.away.short)), clock, h('div', { class: 'grow' }), skipBtn, autoBtn, stopBtn);
    const stage = h('div', { class: 'stage' });
    const cv = h('canvas', {});
    const sceneHead = h('div', { class: 'scene-head' });
    const ctl = h('div', { class: 'ctl' });
    const speeds = h('div', { class: 'speeds' });
    ctl.append(speeds);
    const bannerBox = h('div', {});
    stage.append(cv, sceneHead, ctl, bannerBox);
    const commMin = h('span', { class: 'min' }, "0'");
    const commTx = h('span', { class: 'tx' }, 'キックオフ。レガーレの攻撃で試合が始まります');
    const comm = h('div', { class: 'comm' }, commMin, commTx, h('span', { class: 'grow' }), h('span', { class: 'sub', style: 'font-size:10px' }, 'タップで経過'));
    wrap.append(top, stage, comm);
    main.append(wrap);

    const R = new YA.Renderer(cv);
    R.setMatch(m);
    const S = (play = { m, R, mode: 'idle', clock: 0, paused: false, sheet: null, raf: 0, last: 0, shown: 0, pendingStop: false, speed: app.speed });
    S.onResize = () => R.resize();
    globalThis.addEventListener('resize', S.onResize);
    setTimeout(() => R.resize(), 0);

    function refreshSpeeds() {
      speeds.replaceChildren(...[['1', '1×'], ['2', '2×'], ['hl', '見どころ']].map(([k, n]) => h('button', { class: S.speed === k ? 'on' : '', onclick: () => { S.speed = k; app.speed = k; refreshSpeeds(); } }, n)));
    }
    refreshSpeeds();
    function refreshAuto() {
      autoBtn.textContent = '自動停止 ' + (m.settings.autoStop ? 'ON' : 'OFF');
      autoBtn.classList.toggle('on', m.settings.autoStop);
    }
    autoBtn.onclick = () => { m.settings.autoStop = !m.settings.autoStop; app.autoStop = m.settings.autoStop; store.set('autoStop', app.autoStop); refreshAuto(); };
    refreshAuto();
    const setComm = (min, tx) => { commMin.textContent = min + "'"; commTx.textContent = tx; };
    const logBox = () => {
      const ex = stage.querySelector('.logpop');
      if (ex) return ex.remove();
      stage.append(h('div', { class: 'logpop', onclick: (e) => e.currentTarget.remove() }, m.log.slice(-10).reverse().map((l) => h('div', {}, h('b', {}, l.minute + "'"), l.text))));
    };
    comm.onclick = logBox;
    const upd = () => {
      scoreHome.textContent = m.score.home;
      scoreAway.textContent = m.score.away;
      clock.textContent = m.min + "'";
    };

    function openSheet(reason) {
      S.paused = true;
      stopBtn.textContent = '再開';
      const titles = { half: '前半終了。ハーフタイム', conceded: '失点。立て直す', scored: '得点。流れを保つ', late: '残り15分', user: '試合を止めています' };
      const sheet = h('div', { class: 'sheet' });
      const inn = h('div', { class: 'sheet-in' });
      const panelBox = h('div', { style: 'flex:1;min-height:0;display:flex' });
      const close = () => { m.closeWindow(m.home); sheet.remove(); S.sheet = null; S.paused = false; S.stopWait = false; stopBtn.textContent = '止める'; stopBtn.disabled = false; };
      const subChip = h('span', { class: 'chip gray' }, `交代 あと${5 - m.home.subsUsed}人`);
      const head = h('div', { class: 'sheet-top' }, h('div', { class: 'reason' }, `${m.min}'  ${titles[reason] || ''}   ${m.score.home} - ${m.score.away}`), subChip, h('button', { class: 'btn pri', style: 'min-width:92px', onclick: close }, '再開'));
      const panel = tacticPanel(m.home, { sheet: true, match: m, tabs: [['sub', '交代'], ['role', '布陣・役割'], ['tactic', '戦い方'], ['instr', '指示'], ['shout', '声かけ']], onChange: () => { upd(); subChip.textContent = `交代 あと${5 - m.home.subsUsed}人`; S.R.base = S.R.basePositions(); }, state: S.panelState });
      S.panelState = panel.state;
      panelBox.append(panel);
      panel.style.cssText = 'flex:1;min-height:0';
      inn.append(head, panelBox);
      sheet.append(inn);
      stage.parentElement.parentElement.append(sheet);
      S.sheet = sheet;
    }

    stopBtn.onclick = () => {
      if (S.sheet) return;
      if (S.paused) return;
      if (S.mode === 'scene') {
        m.requestStop();
        S.stopWait = true;
        stopBtn.textContent = '場面のあとで…';
        stopBtn.disabled = true;
      } else {
        m.requestStop();
        S.stopWait = true;
        S.acc = 99;
      }
    };

    // 場面の再生
    function playScene(sc) {
      S.mode = 'scene';
      S.sc = sc;
      S.tagShown = 0;
      S.beatShown = -1;
      R.startScene(sc);
      R.poss = sc.side;
      sceneHead.replaceChildren(h('div', { class: 'scene-title' }, h('b', {}, sc.minute + "'"), sc.typeName), h('div', { class: 'tagrow' }));
      const tags = fxToShow(sc);
      S.tags = tags;
      bannerBox.replaceChildren();
    }
    function fxToShow(sc) {
      return sc.fxShow;
    }
    function endScene() {
      const sc = S.sc;
      S.mode = 'idle';
      const lastBeat = sc.beats[sc.beats.length - 1].text;
      setComm(sc.minute, lastBeat);
      upd();
      if (sc.goal) {
        const sp = (sc.side === 'home' ? m.home : m.away).players[sc.scorer];
        const asp = sc.assist ? (sc.side === 'home' ? m.home : m.away).players[sc.assist] : null;
        bannerBox.replaceChildren(h('div', { class: 'banner' + (sc.side === 'away' ? ' opp' : '') }, h('div', { class: 'big' }, sc.side === 'home' ? 'GOAL!' : '失点'), h('div', { class: 'small' }, `${sp.num}番 ${sp.name}` + (asp ? `（アシスト ${surname(asp)}）` : ''))));
        S.hold = 1.4;
        YA.sfx.play(sc.side === 'home' ? 'goal' : 'concede');
      } else {
        S.hold = 0.5;
        YA.sfx.play(sc.outcome === 'saved' ? 'save' : sc.outcome === 'missed' || sc.outcome === 'post' ? 'miss' : null);
      }
      S.holdScene = true;
    }

    function handle(e) {
      if (e.type === 'tick') {
        upd();
        if (e.text) setComm(e.minute, e.text);
        else commMin.textContent = e.minute + "'";
        if (e.text && e.key) {
          S.hold = 0.6;
          YA.sfx.play('whistle');
        }
      } else if (e.type === 'scene') {
        upd();
        playScene(e.scene);
      } else if (e.type === 'stop') {
        upd();
        R.endScene();
        sceneHead.replaceChildren();
        openSheet(e.reason);
      } else if (e.type === 'full') {
        upd();
        YA.sfx.play('whistle');
        finishMatch(m, e);
        app.view = 'result';
        render();
      }
    }

    S.acc = 0;
    function frame(ts) {
      S.raf = requestAnimationFrame(frame);
      const dt = Math.min(0.05, ((ts - (S.last || ts)) / 1000) || 0.016);
      S.last = ts;
      if (!S.paused) {
        if (S.mode === 'scene') {
          const k = S.speed === '2' ? 1.7 : 1;
          const dts = dt * k;
          R.update(dts);
          const sc = S.sc;
          // 実況の進み
          for (let i = S.beatShown + 1; i < sc.beats.length; i++) if (R.t >= sc.beats[i].at) { setComm(sc.minute, sc.beats[i].text); S.beatShown = i; }
          // 効いた特性・性格の札（少し遅れて出す）
          const row = sceneHead.querySelector('.tagrow');
          while (S.tagShown < S.tags.length && R.t >= 1.3 + S.tagShown * 0.55) {
            const f = S.tags[S.tagShown++];
            row.append(h('div', { class: 'tag' }, h('span', { class: 'chip ' + f.kind }, f.kind === 'trait' ? '特性' : f.kind === 'pers' ? '性格' : '指示'), h('span', {}, f.tag), h('small', {}, `${f.num}番 ${surname({ name: f.name })}：${f.text}`)));
          }
          if (R.t >= sc.dur) endScene();
        } else {
          R.update(dt);
          if (S.hold > 0) S.hold -= dt;
          else {
            if (S.holdScene) {
              S.holdScene = false;
              R.endScene();
              sceneHead.replaceChildren();
              bannerBox.replaceChildren();
            }
            S.acc += dt;
            const need = S.speed === '1' ? 0.8 : S.speed === '2' ? 0.4 : 0.035;
            if (S.acc >= need) {
              S.acc = 0;
              handle(m.step());
            }
          }
        }
      } else R.update(0.0001);
      R.draw();
    }
    S.raf = requestAnimationFrame(frame);
    YA.sfx.play('whistle');
    // 場面のあとで止める：場面が終わったら次の step が stop を返す
    setComm(0, 'キックオフ。レガーレの攻撃で試合が始まります');
  }

  // ---------- 試合後 ----------
  function viewResult(main) {
    const { m, summary } = app.last;
    const wrap = h('div', { class: 'result' });
    const win = summary.score.home > summary.score.away;
    const draw = summary.score.home === summary.score.away;
    wrap.append(
      h('div', { class: 'res-top' }, h('div', { class: 'res-score' }, h('span', {}, m.home.short), h('b', {}, `${summary.score.home} - ${summary.score.away}`), h('span', {}, m.away.short)), h('div', { class: 'h grow', style: 'font-size:15px' }, win ? '勝利' : draw ? '引き分け' : '敗戦'), m.scheduled && !m.videoDone && YA.videoButton ? YA.videoButton(m) : null, m.scheduled ? h('button', { class: 'btn pri', style: 'min-width:110px', onclick: () => { app.view = 'pre'; preState = null; app.tab = 'home'; render(); } }, 'ホームへ（次の週へ）') : h('button', { class: 'btn', onclick: () => { app.view = 'pre'; preState = null; render(); } }, '戦術を直す'), m.scheduled ? null : h('button', { class: 'btn pri', onclick: () => { const t = newOurs(); startMatch(t, YA.makeOpponent(YA.OPPONENTS[app.opp], app.seed * 3 + app.opp + 1), YA.OPPONENTS[app.opp], false); } }, '同じ設定でもう一度')),
    );
    const left = h('div', { class: 'card pbody grow' });
    const hasExp = !!(m.scheduled && app.w);
    const lpane = h('div', {});
    const showL = (k) => {
      left.replaceChildren(h('div', { class: 'row', style: 'margin-bottom:5px;gap:5px' }, h('button', { class: 'btn sm' + (k === 'tl' ? ' on' : ''), onclick: () => showL('tl') }, '見どころ'), hasExp ? h('button', { class: 'btn sm' + (k === 'xp' ? ' on' : ''), onclick: () => showL('xp') }, '試合の経験') : null), k === 'xp' ? expPane() : lpane);
    };
    // 試合でもらった経験：出場した選手ごとに、何がどれだけ増えたかを並べる
    function expPane() {
      const box = h('div', {});
      box.append(h('div', { class: 'note', style: 'margin-bottom:4px' }, '出た時間と採点で、自信・戦術理解・頭の経験値が増えます。頭の経験値は、次の週の成長（判断・予測など）に入ります。'));
      const rows = Object.keys(m.home.players).map((id) => app.w.players[id]).filter((p) => p && p.lm && p.lm.y === app.w.year && p.lm.w === app.w.week).sort((a, b) => b.lm.mins - a.lm.mins || b.lm.rating - a.lm.rating);
      if (!rows.length) box.append(h('div', { class: 'note' }, '経験の記録がありません'));
      const sg = (v, u) => (v > 0 ? '+' : '') + v + (u || '');
      box.append(h('div', { class: 'plist' }, rows.map((p) => h('div', { class: 'pitem', style: 'cursor:default;gap:5px;font-size:11px' }, posChip(p), h('span', { class: 'nm grow', style: 'min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap' }, `${p.num} ${surname(p)}`), h('span', { class: 'sub', style: 'width:34px' }, p.lm.mins + '分'), h('b', { style: 'width:26px' }, p.lm.rating.toFixed(1)), h('span', { class: 'chip trait', style: 'font-size:10px' }, '頭 +' + p.lm.xp), h('span', { class: 'sub', style: 'width:50px' }, '自信' + sg(p.lm.conf)), h('span', { class: 'sub', style: 'width:54px' }, '戦術' + sg(p.lm.tu)), p.lm.state ? h('span', { class: 'fit ' + (p.lm.state === 'peak' ? 'good' : 'bad') }, p.lm.state === 'peak' ? '伸び盛り' : '壁') : null))));
      return box;
    }
    const tl = h('div', { class: 'tl' });
    for (const sc of m.scenes) {
      const who = (sc.side === 'home' ? m.home : m.away);
      const sh = sc.shooter ? who.players[sc.shooter] : null;
      const lastBeat = sc.beats[sc.beats.length - 1].text;
      const tags = sc.fxShow.map((f) => h('span', { class: 'chip ' + f.kind }, `${f.num}番 ${f.tag}`));
      tl.append(h('div', { class: 'it' + (sc.goal ? (sc.side === 'home' ? ' goal' : ' ogoal') : '') }, h('div', { class: 'm' }, sc.minute + "'"), h('div', { class: 'tx' }, h('span', { class: 'nm' }, (sc.side === 'home' ? m.home.short : m.away.short) + ' ' + sc.typeName), ' ', lastBeat, h('div', { class: 'tags' }, tags))));
    }
    lpane.append(tl);
    showL('tl');
    const right = h('div', { class: 'card pbody', style: 'width:250px;flex:none' });
    right.append(h('div', { class: 'h' }, '気づき'));
    // 特性・性格が効いた回数
    const cnt = {};
    for (const sc of m.scenes) {
      for (const f of sc.fx) {
        const t = m.home.players[f.pid] ? 'h' : 'a';
        if (t !== 'h') continue;
        const k = f.pid + '|' + f.tag + '|' + f.kind;
        cnt[k] = cnt[k] || { f, n: 0, g: 0 };
        cnt[k].n++;
        if (sc.goal && sc.side === 'home') cnt[k].g++;
      }
    }
    const ins = Object.values(cnt).sort((a, b) => b.g - a.g || b.n - a.n).slice(0, 5);
    if (!ins.length) right.append(h('div', { class: 'note' }, 'この試合は、特性や性格が目立つ場面がありませんでした。'));
    for (const c of ins) right.append(h('div', { class: 'insight' }, h('span', { class: 'chip ' + c.f.kind }, c.f.kind === 'trait' ? '特性' : c.f.kind === 'pers' ? '性格' : '指示'), ` ${c.f.num}番 ${surname({ name: c.f.name })}の「${c.f.tag}」が${c.n}回効いた` + (c.g ? `（うち得点${c.g}）` : '')));
    for (const n of summary.notes) right.append(h('div', { class: 'insight bad' }, n.text));
    const sh = m.stats.home;
    const sa = m.stats.away;
    right.append(h('div', { class: 'h', style: 'margin-top:8px' }, 'シュート'), h('div', { class: 'note' }, `${m.home.short} ${sh.shots}（枠内${sh.onTarget}）  -  ${m.away.short} ${sa.shots}（枠内${sa.onTarget}）`));
    right.append(h('div', { class: 'h', style: 'margin-top:8px' }, '採点（上位）'));
    right.append(h('div', { class: 'plist' }, summary.rated.slice(0, 6).map((p, i) => h('div', { class: 'pitem' }, posChip(p), h('span', { class: 'nm grow' }, `${p.num} ${surname(p)}`), p.st.goals ? h('span', { class: 'chip gray' }, `${p.st.goals}得点`) : null, h('b', {}, p.st.rating.toFixed(1))))));
    wrap.append(h('div', { class: 'res-body' }, left, right));
    main.append(wrap);
  }

  YA.start = function () {
    loadCfg();
    // ボタンを押したときの小さな音
    YA.applyFontScale(store.get('fs', 1));
    document.addEventListener('click', (e) => { if (e.target.closest && e.target.closest('button')) YA.sfx.play('tap'); });
    render();
  };
  YA._ui = { app, render, store, h, playerCard, persChips, abBar, surname, persText, newOurs, persistTeam };
})();
