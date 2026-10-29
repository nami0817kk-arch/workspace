// 画面。試合前の布陣・戦い方、試合中の進行と停止中の操作、試合後のふり返り。
(function () {
  'use strict';
  const YA = (globalThis.YA = globalThis.YA || {});
  const W = 68;
  const L = 105;
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const POSN = { GK: 'GK', DF: 'DF', MF: 'MF', FW: 'FW' };

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
    tab: 'match',
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
    const t = YA.makeOurs(1);
    if (app.cfg) applyCfg(t, app.cfg);
    return t;
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
  function abBar(name, v) {
    const c = v >= 15 ? '#1a9d57' : v >= 11 ? '#2f7ed8' : v >= 8 ? '#8fa3c4' : '#c7d0e0';
    return h('div', { class: 'ab' }, h('b', {}, name), h('div', { class: 'bar' }, h('i', { style: `width:${(v / 20) * 100}%;background:${c}` })), h('em', { style: `color:${v >= 15 ? '#1a9d57' : 'inherit'}` }, v));
  }
  function playerCard(t, p, opts) {
    opts = opts || {};
    const idx = t.lineup.findIndex((x) => x.pid === p.id);
    const posKey = idx >= 0 ? YA.posOfSlot(t.lineup[idx], idx) : p.pos;
    const isGK = p.pos === 'GK';
    const top = (isGK ? YA.AB_GK : YA.AB_FIELD).map((n) => [n, p.ab[n]]).sort((a, b) => b[1] - a[1]);
    const wrap = h('div', {});
    wrap.append(
      h('div', { class: 'row' }, h('span', { class: 'pos ' + posKey }, posKey), h('div', { class: 'grow' }, h('div', { class: 'h' }, `${p.num}  ${p.name}`), h('div', { class: 'sub' }, `${p.height}cm  /  調子 ${p.form > 0 ? '+' : ''}${p.form}  /  自信 ${Math.round(p.conf)}`))),
      h('div', { style: 'margin-top:5px' }, h('div', { class: 'note' }, '性格'), h('div', { class: 'row', style: 'flex-wrap:wrap;gap:3px' }, persChips(p, false))),
      h('div', { style: 'margin-top:5px' }, h('div', { class: 'note' }, '特性'), h('div', { class: 'row', style: 'flex-wrap:wrap;gap:3px' }, p.traits.length ? p.traits.map((x) => h('span', { class: 'chip trait' }, x)) : h('span', { class: 'sub' }, 'なし'))),
    );
    const notes = [];
    for (const g of Object.keys(p.pers)) if (YA.PERS_NOTE[p.pers[g]]) notes.push(`${p.pers[g]}：${YA.PERS_NOTE[p.pers[g]]}`);
    if (notes.length) wrap.append(h('div', { class: 'note', style: 'margin-top:4px' }, notes.join(' / ')));
    const list = opts.all ? (isGK ? YA.AB_GK.concat(['フィールド']) : YA.AB_FIELD) : top.slice(0, 8).map((x) => x[0]);
    if (opts.all) {
      const groups = isGK ? [['GK', YA.AB_GK]] : [['技術', YA.AB_TECH], ['頭', YA.AB_MENTAL], ['体', YA.AB_PHYS]];
      for (const [gn, ns] of groups) wrap.append(h('div', { class: 'note', style: 'margin:6px 0 2px;font-weight:800;color:var(--navy)' }, gn), h('div', { class: 'abg' }, ns.map((n) => abBar(n, p.ab[n]))));
    } else {
      wrap.append(h('div', { class: 'note', style: 'margin:6px 0 2px;font-weight:800;color:var(--navy)' }, '目立つ能力'), h('div', { class: 'abg' }, list.map((n) => abBar(n, p.ab[n]))));
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
        const sel = opts.selected && opts.selected() === i;
        const g = s('g', { transform: `translate(${sx} ${sy})`, style: 'cursor:grab' });
        if (sel) g.append(s('circle', { r: 6.4, fill: 'none', stroke: '#ffd54a', 'stroke-width': 1.1 }));
        const fit = YA.Match.prototype.roleFit.call(null, t, i);
        g.append(s('circle', { r: 4.6, cx: 0.4, cy: 0.9, fill: 'rgba(0,0,0,.3)' }), s('circle', { r: 4.6, fill: colors[pos], stroke: '#fff', 'stroke-width': 0.9 }), s('text', { y: 1.6, 'text-anchor': 'middle', fill: '#fff', 'font-size': 5, 'font-weight': 900 }, p.num));
        g.append(s('text', { y: 9.4, 'text-anchor': 'middle', fill: '#fff', 'font-size': 3.5, 'font-weight': 800, stroke: 'rgba(0,0,0,.45)', 'stroke-width': 0.7, 'paint-order': 'stroke' }, surname(p)));
        g.append(s('text', { y: 13, 'text-anchor': 'middle', fill: fit < 0 ? '#ffb3b3' : fit > 0 ? '#fff3b0' : '#e8f5ec', 'font-size': 3, 'font-weight': 700, stroke: 'rgba(0,0,0,.45)', 'stroke-width': 0.6, 'paint-order': 'stroke' }, sl.role + (fit > 0 ? ' ◎' : fit < 0 ? ' ×' : '')));
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
    const pos = YA.posOfSlot(t.lineup[i], i);
    if (YA.ROLES[pos].indexOf(t.lineup[i].role) < 0) t.lineup[i].role = YA.ROLES[pos][0];
  }

  // 定番の形を当てはめる。近い選手が近い位置に入る
  function applyFormation(t, name) {
    const fm = YA.FORMATIONS[name];
    const cur = t.lineup.map((s2, i) => ({ i, pid: s2.pid, x: s2.x, y: s2.y, role: s2.role, g: t.players[s2.pid].pos }));
    const gk = cur.find((c) => c.g === 'GK');
    const used = new Set([gk.i]);
    const out = new Array(11);
    out[0] = { pid: gk.pid, x: fm[0].x, y: fm[0].y };
    const slots = fm.map((f2, k) => ({ k, f: f2 })).slice(1).sort((a, b) => a.f.y - b.f.y);
    for (const sl of slots) {
      let best = null;
      let bd = 1e9;
      for (const c of cur) {
        if (used.has(c.i)) continue;
        const d = Math.hypot((c.x - sl.f.x) * 1, (c.y - sl.f.y) * 1.6);
        if (d < bd) {
          bd = d;
          best = c;
        }
      }
      used.add(best.i);
      out[sl.k] = { pid: best.pid, x: sl.f.x, y: sl.f.y };
    }
    const roleOf = {};
    cur.forEach((c) => (roleOf[c.pid] = c.role));
    t.lineup = out.map((o, i) => ({ pid: o.pid, x: o.x, y: o.y, role: roleOf[o.pid] }));
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
    board = boardEl(t, { selected: () => st.sel, onSelect: (i) => { st.sel = i; if (st.tab === 'role') renderBody(); else if (st.tab !== 'tactic' && st.tab !== 'sub') renderBody(); board.redraw(); }, onChange });
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
        h('button', { class: 'btn sm', onclick: () => { const sv = store.get('forms', [null, null, null]); sv[slotSel] = { slots: t.lineup.map((x) => ({ x: x.x, y: x.y, role: x.role })) }; store.set('forms', sv); st.msgs = ['型' + (slotSel + 1) + 'に保存しました']; renderFm(); renderBody(); } }, '保存'),
        h('button', { class: 'btn sm', onclick: () => { const sv = store.get('forms', [null, null, null]); const f2 = sv[slotSel]; if (!f2) { st.msgs = ['型' + (slotSel + 1) + 'はまだ空です']; renderBody(); return; } f2.slots.forEach((x, i) => { t.lineup[i].x = x.x; t.lineup[i].y = x.y; fixRole(t, i); }); t.formation = 'カスタム'; board.redraw(); onChange(); } }, '呼出'),
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
        body.append(h('div', { class: 'h' }, '戦い方の型'), h('div', { class: 'fm-row', style: 'margin:4px 0 6px' }, Object.keys(YA.TACTICS).map((n) => h('button', { class: 'btn sm' + (t.tactic.type === n ? ' on' : ''), onclick: () => { o.match ? o.match.setType(t, n) : (t.tactic = Object.assign({ type: n, dir: t.tactic.dir || 0 }, YA.TACTICS[n])); onChange(); } }, n))));
        for (const [k, label, lo, hi] of YA.KNOBS) {
          const inp = h('input', { type: 'range', min: 0, max: 100, value: Math.round(t.tactic[k] * 100) });
          inp.addEventListener('input', () => { t.tactic[k] = inp.value / 100; t.tactic.type = 'カスタム'; o.onChange && o.onChange(); });
          inp.addEventListener('change', () => renderBody());
          body.append(h('div', { class: 'knob' }, h('label', {}, label), h('span', { class: 'l' }, lo), inp, h('span', {}, hi)));
        }
        body.append(h('div', { class: 'h', style: 'margin-top:6px' }, '攻める方向'), h('div', { class: 'fm-row', style: 'margin-top:3px' }, [['左中心', -1], ['両サイド', 0], ['右中心', 1]].map(([n, v]) => h('button', { class: 'btn sm' + ((t.tactic.dir || 0) === v ? ' on' : ''), onclick: () => { t.tactic.dir = v; onChange(); } }, n))));
        body.append(h('div', { class: 'note', style: 'margin-top:8px' }, '型を選ぶとつまみが動きます。つまみは細かく変えられます。再現度は選手の戦術理解で決まる想定です（試作では未反映）。'));
      } else if (st.tab === 'role') {
        const pos = YA.posOfSlot(sl, st.sel);
        body.append(playerCard(t, p));
        body.append(h('div', { class: 'h', style: 'margin-top:8px' }, '役割（' + pos + '）'));
        const roles = YA.ROLES[pos];
        body.append(
          h('div', { class: 'fm-row', style: 'margin-top:3px' }, roles.map((r) => {
            const save = sl.role;
            sl.role = r;
            const fit = YA.Match.prototype.roleFit.call(null, t, st.sel);
            sl.role = save;
            return h('button', { class: 'btn sm' + (save === r ? ' on' : ''), onclick: () => { sl.role = r; board.redraw(); onChange(); } }, r, fit > 0 ? h('span', { class: 'fit good' }, 'ハマる') : fit < 0 ? h('span', { class: 'fit bad' }, '合わない') : null);
          })),
        );
        body.append(h('div', { class: 'note', style: 'margin-top:5px' }, '役割が特性と合うと場面で力が出ます。合わない役割を続けると、不満が溜まります。'));
        if (!o.sheet) {
          body.append(h('div', { class: 'h', style: 'margin-top:8px' }, 'ベンチと入れ替える'));
          body.append(h('div', { class: 'plist' }, t.bench.map((bid) => {
            const bp = t.players[bid];
            const ok2 = (bp.pos === 'GK') === (p.pos === 'GK');
            return h('button', { class: 'pitem', style: ok2 ? '' : 'opacity:.35', onclick: () => { if (!ok2) return; const bi = t.bench.indexOf(bid); t.bench[bi] = sl.pid; sl.pid = bid; fixRole(t, st.sel); board.redraw(); onChange(); } }, h('span', { class: 'pos ' + bp.pos }, bp.pos), h('span', { class: 'num' }, bp.num), h('span', { class: 'nm grow' }, bp.name), h('span', { class: 'sub' }, bp.traits.slice(0, 2).join('・')));
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
          lo.append(h('button', { class: 'pitem' + (st.subOut === q.id ? ' on' : ''), onclick: () => { st.subOut = q.id; renderBody(); } }, h('span', { class: 'pos ' + pc }, pc), h('span', { class: 'num' }, q.num), h('span', { class: 'nm grow' }, surname(q)), h('div', { class: 'bar stam' }, h('i', { style: `width:${q.stam}%;background:${q.stam < 45 ? '#d63a3a' : q.stam < 70 ? '#f0a020' : '#1a9d57'}` }))));
        });
        const li = h('div', { class: 'grow plist' }, h('div', { class: 'note' }, '入れる選手（ベンチ）'));
        t.bench.forEach((bid) => {
          const q = t.players[bid];
          li.append(h('button', { class: 'pitem' + (st.subIn === q.id ? ' on' : ''), onclick: () => { st.subIn = q.id; renderBody(); } }, h('span', { class: 'pos ' + q.pos }, q.pos), h('span', { class: 'num' }, q.num), h('span', { class: 'nm grow' }, surname(q)), h('span', { class: 'sub', style: 'font-size:9.5px' }, q.traits.slice(0, 1).join(''))));
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
        body.append(h('div', { class: 'note' }, `型：${ot.tactic.type} / 布陣：${ot.formation}`));
        body.append(h('div', { class: 'plist', style: 'margin-top:6px' }, ot.lineup.map((x) => { const q = ot.players[x.pid]; return h('div', { class: 'pitem' }, h('span', { class: 'num' }, q.num), h('span', { class: 'nm' }, q.name), h('span', { class: 'sub grow' }, q.traits.join('・'))); })));
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
    if (app.tab === 'match') {
      if (app.view === 'pre') viewPre(main);
      else if (app.view === 'play') viewPlay(main);
      else viewResult(main);
    } else if (app.tab === 'players') viewPlayers(main);
    else viewPlaceholder(main);
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
    const list = h('div', { class: 'card pbody scroll', style: 'width:200px;flex:none;padding:6px' }, h('div', { class: 'plist' }, all.map((q, i) => h('button', { class: 'pitem' + (i === sel ? ' on' : ''), onclick: () => { app.pSel = i; render(); } }, h('span', { class: 'pos ' + q.pos }, q.pos), h('span', { class: 'num' }, q.num), h('span', { class: 'nm grow' }, q.name), i < 11 ? h('span', { class: 'chip gray' }, 'A') : null))));
    const detail = h('div', { class: 'card pbody' }, playerCard(t, all[sel], { all: true }));
    main.append(h('div', { class: 'row', style: 'flex:1;min-height:0;align-items:stretch' }, list, detail));
  }

  // ---------- 試合前 ----------
  let preState = null;
  function viewPre(main) {
    const t = newOurs();
    const opp = YA.OPPONENTS[app.opp];
    const oppTeam = YA.makeOpponent(opp, app.seed * 3 + app.opp);
    const wrap = h('div', { class: 'pre' });
    const top = h('div', { class: 'pre-top' });
    YA.OPPONENTS.forEach((o2, i) => top.append(h('button', { class: 'opp' + (i === app.opp ? ' on' : ''), onclick: () => { app.cfg = snapCfg(t); store.set('cfg', app.cfg); app.opp = i; render(); } }, h('b', {}, h('span', { class: 'sw', style: 'background:' + o2.color }), o2.name), h('span', {}, o2.desc))));
    top.append(h('button', { class: 'btn pri', style: 'min-width:92px;font-size:14px', onclick: () => { app.cfg = snapCfg(t); store.set('cfg', app.cfg); startMatch(t, oppTeam, opp); } }, 'キックオフ'));
    const panel = tacticPanel(t, { tabs: [['tactic', '戦い方'], ['role', '選手と役割'], ['opp', '相手の分析']], opp, oppTeam, onChange: () => { app.cfg = snapCfg(t); store.set('cfg', app.cfg); }, state: preState || {} });
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
  function startMatch(t, oppTeam, opp) {
    app.seed = (app.seed * 1103515245 + 12345) % 2147483647;
    const m = new YA.Match({ seed: app.seed, home: t, away: oppTeam, settings: { autoStop: app.autoStop } });
    m.opp = opp;
    app.match = m;
    app.view = 'play';
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
    const top = h('div', { class: 'topbar' }, h('div', { class: 'scoreboard' }, h('span', { class: 'tn' }, m.home.short), scoreHome, h('span', { style: 'color:#8fa3c4' }, '-'), scoreAway, h('span', { class: 'tn' }, m.away.short)), clock, h('div', { class: 'grow' }), autoBtn, stopBtn);
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
      } else S.hold = 0.5;
      S.holdScene = true;
    }

    function handle(e) {
      if (e.type === 'tick') {
        upd();
        if (e.text) setComm(e.minute, e.text);
        else commMin.textContent = e.minute + "'";
        if (e.text && e.key) S.hold = 0.6;
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
        app.last = { m, summary: e.summary };
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
      h('div', { class: 'res-top' }, h('div', { class: 'res-score' }, h('span', {}, m.home.short), h('b', {}, `${summary.score.home} - ${summary.score.away}`), h('span', {}, m.away.short)), h('div', { class: 'h grow', style: 'font-size:15px' }, win ? '勝利' : draw ? '引き分け' : '敗戦'), h('button', { class: 'btn', onclick: () => { app.view = 'pre'; preState = null; render(); } }, '戦術を直す'), h('button', { class: 'btn pri', onclick: () => { const t = newOurs(); startMatch(t, YA.makeOpponent(YA.OPPONENTS[app.opp], app.seed * 3 + app.opp + 1), YA.OPPONENTS[app.opp]); } }, '同じ設定でもう一度')),
    );
    const left = h('div', { class: 'card pbody grow' }, h('div', { class: 'h', style: 'margin-bottom:5px' }, '見どころ'));
    const tl = h('div', { class: 'tl' });
    for (const sc of m.scenes) {
      const who = (sc.side === 'home' ? m.home : m.away);
      const sh = sc.shooter ? who.players[sc.shooter] : null;
      const lastBeat = sc.beats[sc.beats.length - 1].text;
      const tags = sc.fxShow.map((f) => h('span', { class: 'chip ' + f.kind }, `${f.num}番 ${f.tag}`));
      tl.append(h('div', { class: 'it' + (sc.goal ? (sc.side === 'home' ? ' goal' : ' ogoal') : '') }, h('div', { class: 'm' }, sc.minute + "'"), h('div', { class: 'tx' }, h('span', { class: 'nm' }, (sc.side === 'home' ? m.home.short : m.away.short) + ' ' + sc.typeName), ' ', lastBeat, h('div', { class: 'tags' }, tags))));
    }
    left.append(tl);
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
    right.append(h('div', { class: 'plist' }, summary.rated.slice(0, 6).map((p, i) => h('div', { class: 'pitem' }, h('span', { class: 'pos ' + p.pos }, p.pos), h('span', { class: 'nm grow' }, `${p.num} ${surname(p)}`), p.st.goals ? h('span', { class: 'chip gray' }, `${p.st.goals}得点`) : null, h('b', {}, p.st.rating.toFixed(1))))));
    wrap.append(h('div', { class: 'res-body' }, left, right));
    main.append(wrap);
  }

  YA.start = function () {
    loadCfg();
    render();
  };
  YA._ui = { app, render, store, h };
})();
