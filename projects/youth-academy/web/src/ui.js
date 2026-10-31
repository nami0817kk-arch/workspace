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
    if (p.bestKnown || pos15 === p.main || (p.subs && p.subs.indexOf(pos15) >= 0)) return YA.aptGrade(v) + Math.round(v);
    return Math.max(1, Math.round(v - 2)) + '〜' + Math.min(20, Math.round(v + 2));
  }
  // こなせるポジション（○以上）の札：登録・こなせる・（気づいていれば）本当に向いている
  function goodPosRow(p) {
    const list = YA.goodPositions(p).filter((q) => q === p.main || (p.subs && p.subs.indexOf(q) >= 0) || (p.bestKnown && q === p.best));
    if (list.indexOf(p.main) < 0) list.unshift(p.main);
    return h('span', { class: 'row', style: 'gap:3px;flex-wrap:wrap' }, list.map((q) => h('span', { class: 'aptchip' + (q === p.main ? ' cur' : ''), style: 'padding:1px 6px;font-size:10.5px' }, YA.POS_LABEL[q], h('b', {}, YA.aptLabel(p.apt[q])))));
  }
  function aptBlock(p) {
    if (p.pos === 'GK') return h('div', { class: 'note' }, 'GK（ほかのポジションの適性は、この版では見ません）');
    const top = [p.main].concat((p.subs || []).filter((q) => q !== p.main));
    if (p.bestKnown && top.indexOf(p.best) < 0) top.push(p.best);
    const row = h('div', { class: 'aptrow' }, top.map((q) => h('span', { class: 'aptchip' + (q === p.main ? ' cur' : '') + (p.bestKnown && q === p.best ? ' best' : '') }, YA.POS_LABEL[q], h('b', {}, aptText(p, q)), q === p.main ? h('span', { class: 'sub' }, '登録') : null)));
    const more = h('button', { class: 'btn sm', onclick: () => { if (YA._v) YA._v.modal((close) => aptModal(p, close)); } }, '全ポジション');
    return h('div', {}, h('div', { class: 'row', style: 'gap:5px;flex-wrap:wrap' }, row, more), h('div', { class: 'note', style: 'margin-top:2px' }, `利き足：${p.foot === 'R' ? '右' : p.foot === 'L' ? '左' : '両足'}（逆足の精度 ${p.ab['逆足の精度']}）` + (p.bestKnown ? `　向いているポジション：${YA.POS_LABEL[p.best]}` : '　本当に向いているポジションは、まだ分かっていません')));
  }
  function aptModal(p, close) {
    const g = h('div', { style: 'display:grid;grid-template-columns:repeat(5,1fr);gap:4px' }, YA.POS15.filter((q) => q !== 'GK').map((q) => h('div', { class: 'aptchip' + (q === p.main ? ' cur' : '') + (p.bestKnown && q === p.best ? ' best' : ''), style: 'justify-content:space-between;padding:6px 8px' }, YA.POS_LABEL[q], h('b', {}, aptText(p, q)))));
    return h('div', { class: 'sheet-in', style: 'flex:none;align-self:center;margin:auto;width:min(620px,96%);padding:12px;gap:7px' },
      h('div', { class: 'h' }, `${p.name} のポジション適性（1〜20）`), g,
      h('div', { class: 'note' }, '◎ 本職（17以上）・○ こなせる（14以上）・△ 不慣れ（10以上）・× 不向き。「〜」の幅は、まだ確かめていないという意味です。見る目の高い指導者や、試合での気づきで、本当に向いているポジションが分かってきます。向いていないポジションにも置けますが、力が出にくく、慣れるまで数か月かかります。'),
      h('button', { class: 'btn pri', onclick: close }, '閉じる'));
  }
  YA._apt = { posChip, aptBlock, goodPosRow };

  // DOM の append・prepend・replaceChildren は、null を「null」という文字にして画面に出してしまう。
  // 画面の組み立てでは「条件 ? 部品 : null」を多用するので、null・undefined・false は黙って捨てる
  if (globalThis.Element && !Element.prototype._yaSafe) {
    for (const k of ['append', 'prepend', 'replaceChildren']) {
      const orig = Element.prototype[k];
      Element.prototype[k] = function (...a) {
        return orig.apply(this, a.filter((x) => x != null && x !== false));
      };
    }
    Element.prototype._yaSafe = true;
  }

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
  // 学年の印（自分のチームの選手だけ。相手は学年を持たない）
  const gtag = (p) => (p && p.grade ? h('span', { class: 'gtag g' + p.grade }, '高' + p.grade) : null);
  function persText(p) {
    const keys = Object.keys(p.pers).filter((g) => p.pers[g] !== 'ふつう');
    return keys.map((g) => p.pers[g]).join('・') || 'ふつう';
  }
  function persChips(p, all) {
    const keys = Object.keys(p.pers).filter((g) => all || p.pers[g] !== 'ふつう');
    if (!keys.length) return [h('span', { class: 'chip gray' }, '性格：ふつう')];
    return keys.map((g) => h('span', { class: 'chip pers', title: YA.PERS_NOTE[p.pers[g]] || '' }, p.pers[g]));
  }
  // 性格と、その意味（1行ずつ）
  function persExplain(p) {
    const keys = Object.keys(p.pers).filter((g) => p.pers[g] !== 'ふつう');
    if (!keys.length) return h('div', { class: 'note' }, 'ふつう（目立った癖はない）');
    return h('div', {}, keys.map((g) => h('div', { class: 'row', style: 'gap:5px;margin-top:2px' }, h('span', { class: 'chip pers' }, p.pers[g]), h('span', { class: 'note' }, YA.PERS_NOTE[p.pers[g]] || ''))));
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
      h('div', { class: 'row' }, posChip(p), h('div', { class: 'grow' }, h('div', { class: 'h' }, `${p.num}  ${p.name}`, p.grade ? `  （高${p.grade}）` : ''), h('div', { class: 'sub' }, `${p.height}cm  /  調子 ${p.form > 0 ? '+' : ''}${p.form}  /  自信 ${Math.round(p.conf)}  /  戦術理解 ${Math.round(p.tu == null ? 40 : p.tu)}` + (p.nation && p.nation !== '日本' ? `  /  ${p.nation}` : '')))),
      h('div', { style: 'margin-top:5px' }, h('div', { class: 'note' }, 'ポジションの適性'), aptBlock(p)),
      h('div', { style: 'margin-top:5px' }, h('div', { class: 'note' }, '性格'), persExplain(p)),
      h('div', { style: 'margin-top:5px' }, h('div', { class: 'note' }, '特性'), h('div', { class: 'row', style: 'flex-wrap:wrap;gap:3px' }, p.traits.length ? p.traits.map((x) => h('span', { class: 'chip trait' }, x)) : h('span', { class: 'sub' }, 'なし'))),
    );
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
  // 横向き（右へ攻める）。左サイドが上。相手陣の奥（92m より先）は使わないので切り落として、そのぶん大きく見せる
  const VIEW_LEN = 92;
  function boardEl(t, opts) {
    const wrap = h('div', { class: 'board' });
    const svg = s('svg', { viewBox: `-3 -3 ${VIEW_LEN + 3} ${W + 6}`, preserveAspectRatio: 'xMidYMid meet' });
    const stripes = 9;
    for (let i = 0; i < stripes; i++) svg.append(s('rect', { x: -3 + ((VIEW_LEN + 3) / stripes) * i, y: -3, width: (VIEW_LEN + 3) / stripes + 0.1, height: W + 6, fill: i % 2 ? '#2f9a5f' : '#37a869' }));
    const ln = { stroke: 'rgba(255,255,255,.9)', 'stroke-width': 0.5, fill: 'none' };
    svg.append(s('rect', Object.assign({ x: 0, y: 0, width: L, height: W }, ln)), s('line', Object.assign({ x1: L / 2, y1: 0, x2: L / 2, y2: W }, ln)), s('circle', Object.assign({ cx: L / 2, cy: W / 2, r: 9.15 }, ln)));
    svg.append(s('rect', Object.assign({ x: 0, y: 13.84, width: 16.5, height: 40.32 }, ln)), s('rect', Object.assign({ x: 0, y: 24.84, width: 5.5, height: 18.32 }, ln)));
    svg.append(s('text', { x: VIEW_LEN - 1, y: 2.4, 'text-anchor': 'end', fill: 'rgba(255,255,255,.8)', 'font-size': 3, 'font-weight': 800 }, '攻める方向 ▶'));
    // 横の位置 x（0=左サイド）と縦の位置 y（0=自陣ゴール）→ 画面の座標
    const at = (x, y) => ({ sx: 4 + y * 78, sy: x * W });
    // 置ける立ち位置（定番の布陣の位置を集めたもの）。動かしている間だけ、ポジション名つきで見える
    const grid = s('g', { opacity: 0.0, id: 'gridDots' });
    for (const sp of spots()) {
      const { sx, sy } = at(sp.x, sp.y);
      grid.append(s('circle', { cx: sx, cy: sy, r: 3.6, fill: 'rgba(255,255,255,.18)', stroke: '#fff', 'stroke-width': 0.35, 'stroke-dasharray': '1 0.8' }), s('text', { x: sx, y: sy + 1.1, 'text-anchor': 'middle', fill: '#fff', 'font-size': 2.8, 'font-weight': 800 }, YA.POS_LABEL[YA.pos15OfPoint(sp.x, sp.y)]));
    }
    svg.append(grid);
    const layer = s('g', {});
    svg.append(layer);
    wrap.append(svg);
    const colors = { GK: '#f39c12', DF: '#2f7ed8', MF: '#16a34a', FW: '#e0453a' };
    const lab = (y, fill, size, str) => s('text', { y, 'text-anchor': 'middle', fill, 'font-size': size, 'font-weight': 900, stroke: 'rgba(0,0,0,.55)', 'stroke-width': 0.8, 'paint-order': 'stroke' }, str);
    let drag = null;
    function draw() {
      layer.replaceChildren();
      t.lineup.forEach((sl, i) => {
        const p = t.players[sl.pid];
        const { sx, sy } = at(sl.x, sl.y);
        const pos = YA.posOfSlot(sl, i);
        const p15 = YA.pos15OfSlot(sl, i);
        const grade = YA.aptGrade(p.apt ? p.apt[p15] : 17);
        const sel = opts.selected && opts.selected() === i;
        const g = s('g', { transform: `translate(${sx} ${sy})`, style: 'cursor:grab' });
        if (sel) g.append(s('circle', { r: 6.6, fill: 'none', stroke: '#ffd54a', 'stroke-width': 1.2 }));
        // 適性が合っていない枠は、丸のふちを黄（△）・赤（×）にする
        const ring = grade === '×' ? '#ff4d4d' : grade === '△' ? '#ffd54a' : '#fff';
        g.append(s('circle', { r: 4.6, cx: 0.4, cy: 0.9, fill: 'rgba(0,0,0,.3)' }), s('circle', { r: 4.6, fill: colors[pos], stroke: ring, 'stroke-width': ring === '#fff' ? 0.9 : 1.5 }), s('text', { y: 1.7, 'text-anchor': 'middle', fill: '#fff', 'font-size': 4.6, 'font-weight': 900 }, p.num));
        g.append(lab(-5.8, '#fff', 3.4, surname(p)));
        // ポジション名と適性は丸の右に（縦に並ぶ最終ラインでも、名前と重ならない）
        if (p15 !== 'GK') g.append(s('text', { x: 5.3, y: 1.1, 'text-anchor': 'start', fill: ring === '#fff' ? '#fff6c2' : ring, 'font-size': 2.8, 'font-weight': 900, stroke: 'rgba(0,0,0,.55)', 'stroke-width': 0.8, 'paint-order': 'stroke' }, YA.POS_LABEL[p15] + (p15 === 'GK' ? '' : YA.aptLabel(p.apt ? p.apt[p15] : 17))));
        if ((opts.showRole && opts.showRole()) || sel) {
          const fit = YA.Match.prototype.roleFit.call(null, t, i);
          g.append(s('text', { x: 5.3, y: p15 === 'GK' ? 1.1 : 4.3, 'text-anchor': 'start', fill: fit < 0 ? '#ffb3b3' : fit > 0 ? '#fff3b0' : '#e8f5ec', 'font-size': 2.3, 'font-weight': 800, stroke: 'rgba(0,0,0,.55)', 'stroke-width': 0.7, 'paint-order': 'stroke' }, (sl.role.length > 4 ? sl.role.slice(0, 4) + '…' : sl.role) + (YA.DUTY[sl.duty] ? '・' + YA.DUTY[sl.duty].short : '')));
        }
        g.addEventListener('pointerdown', (ev) => {
          ev.preventDefault();
          g.setPointerCapture(ev.pointerId);
          drag = { i, g, moved: false };
          opts.onSelect && opts.onSelect(i);
          grid.setAttribute('opacity', 0.6);
        });
        g.addEventListener('pointermove', (ev) => {
          if (!drag || drag.i !== i) return;
          const pt = svg.createSVGPoint();
          pt.x = ev.clientX;
          pt.y = ev.clientY;
          const q = pt.matrixTransform(svg.getScreenCTM().inverse());
          // いちばん近い立ち位置に吸い付く
          let best = null;
          let bd = 1e9;
          for (const sp of spots()) {
            const a2 = at(sp.x, sp.y);
            const d = Math.hypot(a2.sx - q.x, a2.sy - q.y);
            if (d < bd) { bd = d; best = sp; }
          }
          if (!best) return;
          drag.sp = best;
          drag.moved = true;
          const a3 = at(best.x, best.y);
          g.setAttribute('transform', `translate(${a3.sx} ${a3.sy})`);
        });
        const up = () => {
          if (!drag || drag.i !== i) return;
          grid.setAttribute('opacity', 0);
          if (drag.moved && drag.sp) {
            const nx = drag.sp.x;
            const ny = drag.sp.y;
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
  // 置ける立ち位置：定番の布陣の位置（GKを除く）を重ならないよう集めたもの
  let SPOTS = null;
  function spots() {
    if (SPOTS) return SPOTS;
    SPOTS = [];
    for (const fm of Object.values(YA.FORMATIONS)) for (const sp of fm) {
      if (sp.y < 0.08) continue;
      if (!SPOTS.some((q) => Math.abs(q.x - sp.x) < 0.06 && Math.abs(q.y - sp.y) < 0.05)) SPOTS.push({ x: sp.x, y: sp.y });
    }
    return SPOTS;
  }
  // その枠で、いちばんハマる役割を選ぶ
  function bestRoles(t) {
    t.lineup.forEach((sl, i) => {
      const p15 = YA.pos15OfSlot(sl, i);
      let best = sl.role;
      let bv = -1e9;
      for (const r of YA.ROLES15[p15]) {
        const sr = sl.role;
        const sd = sl.duty;
        sl.role = r;
        sl.duty = YA.defaultDuty(r);
        const v = YA.Match.prototype.roleFit.call(null, t, i);
        sl.role = sr;
        sl.duty = sd;
        if (v > bv) { bv = v; best = r; }
      }
      if (best !== sl.role) YA.setRole(sl, i, best);
    });
  }
  // おまかせ編成：いまの布陣の枠に、Aの動ける選手から「力×その位置の適性」で11人を選び、役割も合わせる
  function autoSquad(t) {
    const ok = (p) => p.inj <= 0 && !(p.away > 0) && !(p.suspend > 0);
    const fm = t.lineup.map((s2) => ({ x: s2.x, y: s2.y }));
    const w = app.w;
    // Aの20人から選ぶ（Bは入れない）
    const all = w ? Object.values(w.players).filter((p) => p.team === 'A') : Object.values(t.players);
    const pool = all.filter(ok);
    if (!pool.some((p) => p.pos === 'GK')) {
      const g = all.filter((p) => p.pos === 'GK')[0];
      if (g) pool.push(g);
    }
    const lineup = YA.fillSlots(fm, pool);
    const rest = all.filter((p) => !lineup.some((l) => l && l.pid === p.id)).sort((a, b) => ok(b) - ok(a) || YA.ovr(b) - YA.ovr(a));
    // ベンチ9人：控えのGKを1人は入れる
    const gk = rest.find((p) => p.pos === 'GK' && ok(p));
    const bench = (gk ? [gk] : []).concat(rest.filter((p) => p !== gk)).slice(0, 9).map((p) => p.id);
    if (w) {
      persistTeam(t);
      w.lineupA = lineup;
      w.benchA = bench;
      const tmp = YA.teamFromWorld(w, 'A');
      bestRoles(tmp);
      tmp.lineup.forEach((sl, i) => { w.lineupA[i].role = sl.role; w.lineupA[i].duty = sl.duty; });
      YA.saveWorld();
    } else {
      t.lineup = lineup;
      t.bench = bench;
      bestRoles(t);
    }
  }
  // 適性の合っていない先発（○未満）
  function offPos(t) {
    return t.lineup.map((sl, i) => ({ i, p: t.players[sl.pid], p15: YA.pos15OfSlot(sl, i) })).filter((x) => x.p && x.p.apt && x.p.apt[x.p15] < 14);
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
    const st = { tab: o.tabs[0][0], sel: 0, pick: null, subOut: null, subIn: null, instrTarget: null, shoutTarget: 'team', msgs: [] };
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
      st.pick = null; // ドラッグで動かしたあとは選択を外す
      o.onChange && o.onChange();
      renderBody();
      renderFm();
    }
    board = boardEl(t, { selected: () => st.sel, showRole: () => !!st.showRole, onSelect: (i) => { if (st.tab === 'squad') { handlePick({ k: 'L', i }); return; } st.sel = i; if (o.tabs.some((x) => x[0] === 'role') && st.tab !== 'role' && st.tab !== 'sub') { st.tab = 'role'; renderTabs(); } renderBody(); board.redraw(); }, onChange });
    leftWrap.append(board, fmRow, saveRow);
    let slotSel = 0;
    function renderFm() {
      fmRow.replaceChildren(
        h('button', { class: 'btn sm pri', onclick: () => { autoSquad(t); st.pick = null; st.msgs = ['おまかせで11人と役割を決めました（力とポジションの適性から）']; if (app.w) { render(); return; } onChange(); board.redraw(); } }, 'おまかせ編成'),
        ...Object.keys(YA.FORMATIONS).map((n) => h('button', { class: 'btn sm' + (t.formation === n ? ' on' : ''), onclick: () => { applyFormation(t, n); onChange(); board.redraw(); } }, n)),
      );
      const saved = store.get('forms', [null, null, null]);
      saveRow.replaceChildren(
        h('button', { class: 'btn sm' + (st.showRole ? ' on' : ''), onclick: () => { st.showRole = !st.showRole; renderFm(); board.redraw(); } }, '役割'),
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
            body.append(h('div', { class: 'insight', style: 'margin-bottom:4px;padding:5px 8px;font-size:11px;line-height:1.4' }, h('b', {}, `スタメンとの相性 ${cur.mark}`), `　${pf.why}。大事な能力：${pf.abs.join('・')}（先発で低いのは ${wk}）。練習するとこの能力が伸びやすくなります。`));
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
      } else if (st.tab === 'squad') {
        renderSquad();
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
        const roleGrid = h('div', { class: 'rolegrid' });
        body.append(roleGrid);
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
          roleGrid.append(h('button', { class: 'rolecard' + (save === r ? ' on' : ''), onclick: () => { if (sl.role !== r) YA.setRole(sl, st.sel, r); board.redraw(); onChange(); } },
            h('div', { class: 'grow' }, h('b', {}, r), h('div', {}, h('span', { class: 'd' }, rd.note)), h('div', {}, h('span', { class: 'd' }, '任務：' + rd.duties.map((k) => YA.DUTY[k].label).join('・') + ' ／ 合う特性：' + rd.traits.slice(0, 3).join('・')))),
            fit > 0 ? h('span', { class: 'fit good' }, 'ハマる') : fit < 0 ? h('span', { class: 'fit bad' }, '合わない') : null));
        }
        body.append(h('div', { class: 'note', style: 'margin-top:5px' }, '役割が特性や能力と合うと力が出て、合わない役割を続けると不満が出ます。役割をこなすうちに、戦術の理解が伸びます。'));
        body.append(h('div', { style: 'margin-top:8px;border-top:1px dashed var(--line);padding-top:6px' }, playerCard(t, p)));
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
          lo.append(h('button', { class: 'pitem' + (st.subOut === q.id ? ' on' : ''), onclick: () => { st.subOut = q.id; renderBody(); } }, posChip(q, YA.POS_LABEL[YA.pos15OfSlot(x, i)]), h('span', { class: 'num' }, q.num), h('span', { class: 'nm grow' }, surname(q)), gtag(q), h('div', { class: 'bar stam' }, h('i', { style: `width:${q.stam}%;background:${q.stam < 45 ? '#d63a3a' : q.stam < 70 ? '#f0a020' : '#1a9d57'}` }))));
        });
        const li = h('div', { class: 'grow plist' }, h('div', { class: 'note' }, '入れる選手（ベンチ）'));
        // 下げる選手を選ぶと、その位置への適性が高い順にベンチを並べる（FM風）
        const outI = st.subOut ? t.lineup.findIndex((x) => x.pid === st.subOut) : -1;
        const outP15 = outI >= 0 ? YA.pos15OfSlot(t.lineup[outI], outI) : null;
        const outGK = outP15 === 'GK';
        const benchP = t.bench.map((bid) => t.players[bid]);
        if (outP15) benchP.sort((a, b) => ((b.pos === 'GK') === outGK) - ((a.pos === 'GK') === outGK) || ((b.apt && b.apt[outP15]) || 0) - ((a.apt && a.apt[outP15]) || 0));
        benchP.forEach((q) => {
          const ok = !outP15 || (q.pos === 'GK') === outGK;
          const aptv = outP15 && q.apt ? q.apt[outP15] : null;
          li.append(h('button', { class: 'pitem' + (st.subIn === q.id ? ' on' : ''), style: ok ? '' : 'opacity:.35', onclick: () => { st.subIn = q.id; renderBody(); } }, posChip(q), h('span', { class: 'num' }, q.num), h('span', { class: 'nm grow' }, surname(q)), gtag(q),
            aptv != null ? h('span', { class: 'chip ' + (aptv >= 14 ? 'trait' : 'gray'), style: 'font-size:9.5px' }, '適' + aptv) : h('span', { class: 'sub', style: 'font-size:9.5px' }, q.traits.slice(0, 1).join('')),
            q.inj > 0 ? h('span', { class: 'fit bad' }, '怪') : null));
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
    // ---------- 編成（FM風）：ピッチの先発・ベンチ・控え外を、タップで入れ替える ----------
    const slotIsGK = (i) => YA.pos15OfSlot(t.lineup[i], i) === 'GK';
    function pickPlayer(x) {
      return x.k === 'L' ? t.players[t.lineup[x.i].pid] : x.k === 'B' ? t.players[x.id] : app.w && app.w.players[x.id];
    }
    function say(msg) {
      st.msgs = [msg];
    }
    const samePick = (a, x) => a.k === x.k && a.i === x.i && a.id === x.id;
    function handlePick(x) {
      const a = st.pick;
      if (!a) {
        st.pick = x;
        if (x.k === 'L') st.sel = x.i;
        renderBody();
        board.redraw();
        return;
      }
      if (samePick(a, x)) {
        st.pick = null;
        renderBody();
        board.redraw();
        return;
      }
      const order = { B: 0, L: 1, R: 2 };
      const [P, Q] = order[a.k] <= order[x.k] ? [a, x] : [x, a];
      const pp = pickPlayer(P);
      const pq = pickPlayer(Q);
      const bad = (slotX, pl) => slotX && slotX.k === 'L' && (slotIsGK(slotX.i) !== (pl.pos === 'GK') || pl.inj > 0 || pl.away > 0);
      if (P.k === 'B' && Q.k === 'B') {
        const i1 = t.bench.indexOf(P.id);
        const i2 = t.bench.indexOf(Q.id);
        t.bench[i1] = Q.id;
        t.bench[i2] = P.id;
      } else if (P.k === 'B' && Q.k === 'L') {
        if (bad(Q, pp)) {
          say(pp.inj > 0 ? `${pp.name}は怪我で出られません` : 'GKの枠はGKと入れ替えてください');
          renderBody();
          return;
        }
        const bi = t.bench.indexOf(P.id);
        t.bench[bi] = t.lineup[Q.i].pid;
        t.lineup[Q.i].pid = P.id;
        fixRole(t, Q.i);
        say(`${pp.name} ⇄ ${pq.name}`);
      } else if (P.k === 'L' && Q.k === 'L') {
        if (slotIsGK(P.i) !== slotIsGK(Q.i)) {
          say('GKの枠は、GKどうしでだけ入れ替えられます');
          renderBody();
          return;
        }
        const tmp = t.lineup[P.i].pid;
        t.lineup[P.i].pid = t.lineup[Q.i].pid;
        t.lineup[Q.i].pid = tmp;
        fixRole(t, P.i);
        fixRole(t, Q.i);
        say(`${pp.name} ⇄ ${pq.name}`);
      } else if (Q.k === 'R' && app.w) {
        // 控え外の選手を、ベンチか先発に入れる（名簿の側を書き換えて作り直す）
        const slot = P;
        const w = app.w;
        const r = w.players[Q.id];
        if (slot.k === 'L' && (slotIsGK(slot.i) !== (r.pos === 'GK') || r.inj > 0)) {
          say(r.inj > 0 ? `${r.name}は怪我で出られません` : 'GKの枠はGKと入れ替えてください');
          renderBody();
          return;
        }
        persistTeam(t);
        let d;
        if (slot.k === 'L') {
          const s2 = w.lineupA[slot.i];
          d = w.players[s2.pid];
          s2.pid = r.id;
        } else {
          const bi = w.benchA.indexOf(slot.id);
          d = w.players[slot.id];
          w.benchA[bi] = r.id;
        }
        if (r.team === 'B') {
          const li = w.lineupB.findIndex((s2) => s2.pid === r.id);
          if (li >= 0) {
            w.lineupB[li].pid = d.id;
            YA.fixSlotRole(w.lineupB[li], li);
          }
          const bi2 = (w.benchB || []).indexOf(r.id);
          if (bi2 >= 0) w.benchB[bi2] = d.id;
          else if (li < 0) w.benchB = (w.benchB || []).concat([d.id]);
          r.team = 'A';
          d.team = 'B';
        }
        w.lineupA.forEach((s2, i2) => YA.fixSlotRole(s2, i2));
        YA.saveWorld();
        st.pick = null;
        say(`${r.name}を${slot.k === 'L' ? '先発' : 'ベンチ'}に入れました（${d.name}は控え外）`);
        render();
        return;
      } else {
        st.pick = x;
        renderBody();
        return;
      }
      st.pick = null;
      board.redraw();
      onChange();
    }
    function cell(p, x, p15) {
      const on = st.pick && samePick(st.pick, x);
      const compat = !st.pick || st.pick.k !== 'L' || slotIsGK(st.pick.i) === (p.pos === 'GK');
      const aptv = p15 && p.apt ? p.apt[p15] : null;
      const tired = Math.round(p.fat || 0);
      return h('button', { class: 'pitem sq' + (on ? ' on' : ''), style: compat ? '' : 'opacity:.3', onclick: () => handlePick(x) },
        posChip(p), h('span', { class: 'num' }, p.num), h('span', { class: 'nm grow', style: 'overflow:hidden;text-overflow:ellipsis;white-space:nowrap;min-width:2.6em' }, surname(p)), gtag(p),
        aptv != null ? h('span', { class: 'chip ' + (aptv >= 14 ? 'trait' : 'gray'), style: 'font-size:9.5px' }, YA.aptLabel(aptv)) : null,
        h('b', { style: 'width:26px;text-align:right' }, YA.ovr(p).toFixed(1)),
        p.inj > 0 ? h('span', { class: 'fit bad' }, '怪') : h('div', { class: 'bar stam', style: 'width:22px' }, h('i', { style: `width:${100 - tired}%;background:${tired > 60 ? '#d63a3a' : tired > 40 ? '#f0a020' : '#1a9d57'}` })));
    }
    function renderSquad() {
      const pk = st.pick;
      const pp = pk ? pickPlayer(pk) : null;
      const p15 = pk && pk.k === 'L' ? YA.pos15OfSlot(t.lineup[pk.i], pk.i) : null;
      const top = h('div', { class: 'card', style: 'padding:5px 8px;margin-bottom:5px;background:#f5f8fd' });
      if (pp) {
        const sl2 = pk.k === 'L' ? t.lineup[pk.i] : null;
        top.append(h('div', { class: 'row', style: 'gap:6px' }, posChip(pp), h('b', {}, `${pp.num} ${pp.name}`), gtag(pp), h('span', { class: 'sub' }, `能力${YA.ovr(pp).toFixed(1)}／疲れ${Math.round(pp.fat || 0)}`), sl2 ? h('span', { class: 'chip trait' }, `${sl2.role}・${(YA.DUTY[sl2.duty] || YA.DUTY.sup).label}`) : null, h('span', { class: 'grow' }),
          sl2 ? h('button', { class: 'btn sm', onclick: () => { st.sel = pk.i; st.tab = 'role'; renderTabs(); renderBody(); } }, '役割・任務') : null,
          h('button', { class: 'btn sm', onclick: () => { st.pick = null; renderBody(); board.redraw(); } }, '解除')));
        top.append(h('div', { class: 'note', style: 'margin-top:2px' }, '入れ替える相手（ピッチの選手・ベンチ・控え外）をタップ'));
      } else top.append(h('div', { class: 'note' }, 'ピッチの先発・ベンチ・控え外の選手を1人タップ → 入れ替える相手をタップ。迷ったら左下の「おまかせ編成」。'));
      const off = offPos(t);
      if (off.length) top.append(h('div', { class: 'note', style: 'color:#b02020;margin-top:2px' }, '適性の合っていない先発：' + off.map((x) => `${x.p.num} ${surname(x.p)}（${YA.POS_LABEL[x.p15]}${YA.aptLabel(x.p.apt[x.p15])}・本職${YA.POS_LABEL[x.p.main]}）`).join('、')));
      if (st.msgs.length) top.append(h('div', { class: 'note', style: 'color:var(--ink);margin-top:2px' }, st.msgs[st.msgs.length - 1]));
      body.append(top);
      const bench = t.bench.map((id) => t.players[id]).filter(Boolean);
      if (pk && pk.k === 'L') {
        const want = slotIsGK(pk.i) ? 0 : 1;
        const g = (p) => (p.pos === 'GK' ? 0 : 1);
        bench.sort((a, b) => (g(b) === want) - (g(a) === want) || ((b.apt && b.apt[p15]) || 0) - ((a.apt && a.apt[p15]) || 0));
      }
      body.append(h('div', { class: 'h' }, `ベンチ（${bench.length}人）`), h('div', { class: 'sqgrid' }, bench.map((p) => cell(p, { k: 'B', id: p.id }, p15))));
      if (app.w) {
        const inSq = new Set(t.lineup.map((s2) => s2.pid).concat(t.bench));
        const rest = Object.values(app.w.players).filter((p) => !inSq.has(p.id)).sort((a, b) => (a.team === 'A' ? 0 : 1) - (b.team === 'A' ? 0 : 1) || YA.ovr(b) - YA.ovr(a));
        st.resF = st.resF || 'all';
        body.append(h('div', { class: 'row', style: 'margin-top:6px;gap:5px' }, h('div', { class: 'h grow' }, `控え外（${rest.length}人）`), ...[['all', '全員'], ['A', 'A'], ['B', 'B']].map(([k, n]) => h('button', { class: 'btn sm' + (st.resF === k ? ' on' : ''), onclick: () => { st.resF = k; renderBody(); } }, n))));
        const shown = rest.filter((p) => st.resF === 'all' || p.team === st.resF);
        body.append(h('div', { class: 'sqgrid' }, shown.map((p) => cell(p, { k: 'R', id: p.id }, p15))));
        body.append(h('div', { class: 'note', style: 'margin-top:3px' }, 'Bの選手を入れると、入れ替わった選手はBチームに回ります。'));
      }
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
  let renderKey = '';
  function render() {
    const root = document.getElementById('app');
    root.classList.toggle('full', app.view === 'play');
    renderRail();
    const main = document.getElementById('main');
    // 同じ画面のまま作り直すとき（ボタンを押した直後など）は、スクロール位置を覚えておいて戻す
    const sameView = renderKey === app.tab + '|' + app.view + '|' + (app.ct || '');
    const scrollers = () => [...main.querySelectorAll('.pbody, .scroll, .plist, .sheet-in')].filter((e) => e.scrollHeight > e.clientHeight + 2 && /auto|scroll/.test(getComputedStyle(e).overflowY));
    const keep = sameView ? scrollers().map((e) => e.scrollTop) : [];
    renderKey = app.tab + '|' + app.view + '|' + (app.ct || '');
    const restore = () => { if (keep.length) scrollers().forEach((e, i) => { if (keep[i]) e.scrollTop = keep[i]; }); };
    main.replaceChildren();
    cleanupPlay();
    if (!app.w) {
      root.classList.add('full');
      YA.views.newgame(main);
      restore();
      return;
    }
    if (app.w.retired) {
      root.classList.add('full');
      YA.views.retired(main);
      restore();
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
    restore();
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
    const list = h('div', { class: 'card pbody scroll', style: 'width:200px;flex:none;padding:6px' }, h('div', { class: 'plist' }, all.map((q, i) => h('button', { class: 'pitem' + (i === sel ? ' on' : ''), onclick: () => { app.pSel = i; render(); } }, posChip(q), h('span', { class: 'num' }, q.num), h('span', { class: 'nm grow' }, q.name), gtag(q), i < 11 ? h('span', { class: 'chip gray' }, 'A') : null))));
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
      top.append(h('div', { class: 'opp on', style: 'cursor:default' }, h('b', { style: 'display:flex;align-items:center;gap:5px' }, YA.emblemEl(app.w, opp.name, 20) || h('span', { class: 'sw', style: 'background:' + opp.color }), `${opp.kindLabel || ''}  ${opp.home ? 'ホーム' : 'アウェイ'}  vs ${opp.name}`), h('span', {}, opp.desc + '（フリー対戦に切り替えると成績に残りません）')));
      top.append(h('button', { class: 'btn sm', style: 'align-self:center', onclick: () => { app.free = true; render(); } }, 'フリー対戦'));
    } else if (app.free && w && w.phase === 'match') top.append(h('button', { class: 'btn sm', style: 'align-self:center', onclick: () => { app.free = false; render(); } }, '今週の試合へ戻る'));
    if (!sched) YA.OPPONENTS.forEach((o2, i) => top.append(h('button', { class: 'opp' + (i === app.opp ? ' on' : ''), onclick: () => { persistTeam(t); app.opp = i; render(); } }, h('b', {}, h('span', { class: 'sw', style: 'background:' + o2.color }), o2.name), h('span', {}, o2.desc))));
    const kick = h('div', { class: 'kick' },
      h('button', { class: 'btn pri', style: 'flex:1;font-size:14px', onclick: () => { persistTeam(t); startMatch(t, oppTeam, opp, sched); } }, 'キックオフ'),
      h('button', { class: 'btn sm', onclick: () => { persistTeam(t); simulateAll(t, oppTeam, opp, sched); } }, '全シミュレーション'));
    top.append(kick);
    const panel = tacticPanel(t, { tabs: [['squad', '編成'], ['tactic', '戦い方'], ['role', '選手と役割'], ['opp', '相手の分析']], opp, oppTeam, onChange: () => { persistTeam(t); }, state: preState || {} });
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
    const top = h('div', { class: 'topbar' }, h('div', { class: 'scoreboard' }, YA.emblemEl(app.w, m.home.name, 18), h('span', { class: 'tn' }, m.home.short), scoreHome, h('span', { style: 'color:#8fa3c4' }, '-'), scoreAway, h('span', { class: 'tn' }, m.away.short), YA.emblemEl(app.w, m.away.name, 18)), clock, h('div', { class: 'grow' }), skipBtn, autoBtn, stopBtn);
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
      h('div', { class: 'res-top' }, h('div', { class: 'res-score' }, YA.emblemEl(app.w, m.home.name, 24), h('span', {}, m.home.short), h('b', {}, `${summary.score.home} - ${summary.score.away}`), h('span', {}, m.away.short), YA.emblemEl(app.w, m.away.name, 24)), h('div', { class: 'h grow', style: 'font-size:15px' }, win ? '勝利' : draw ? '引き分け' : '敗戦'), m.scheduled && !m.videoDone && YA.videoButton ? YA.videoButton(m) : null, m.scheduled ? h('button', { class: 'btn pri', style: 'min-width:110px', onclick: () => { app.view = 'pre'; preState = null; app.tab = 'home'; render(); } }, 'ホームへ（次の週へ）') : h('button', { class: 'btn', onclick: () => { app.view = 'pre'; preState = null; render(); } }, '戦術を直す'), m.scheduled ? null : h('button', { class: 'btn pri', onclick: () => { const t = newOurs(); startMatch(t, YA.makeOpponent(YA.OPPONENTS[app.opp], app.seed * 3 + app.opp + 1), YA.OPPONENTS[app.opp], false); } }, '同じ設定でもう一度')),
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
