// 育成の画面：ホーム・選手・練習・クラブ・ほか。中身は world.js、ここは見せ方と操作だけ。
(function () {
  'use strict';
  const YA = (globalThis.YA = globalThis.YA || {});
  const U = () => YA._ui;
  const h = (...a) => U().h(...a);
  const W = () => U().app.w;
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

  // 保存は少しまとめて（操作のたびに全部は書かない）
  let saveT = null;
  YA.saveWorld = function () {
    clearTimeout(saveT);
    saveT = setTimeout(() => {
      try {
        U().store.set('world', U().app.w);
      } catch (e) {}
    }, 250);
  };
  const rerender = () => U().render();

  function modal(build) {
    const main = document.getElementById('main');
    const sheet = h('div', { class: 'sheet', style: 'z-index:20' });
    const close = () => sheet.remove();
    sheet.append(build(close));
    main.append(sheet);
    return close;
  }
  const pcls = (p) => 'pos ' + p.pos;
  const gradeName = (g) => '高' + g;
  const fatColor = (v) => (v > 75 ? '#d63a3a' : v > 50 ? '#f0a020' : '#1a9d57');
  const fatBar = (p, wd) => h('div', { class: 'bar', style: `width:${wd || 40}px` }, h('i', { style: `width:${p.fat}%;background:${fatColor(p.fat)}` }));
  const flags = (p) => [p.inj > 0 ? h('span', { class: 'fit bad' }, '怪我' + p.inj + '週') : null, p.spurt > 0 ? h('span', { class: 'fit good' }, '成長期') : null, p.star ? h('span', { class: 'chip trait' }, '★注目') : null, p.unrest >= 3 ? h('span', { class: 'fit bad' }, '不満') : null];

  // ---------- ホーム ----------
  function viewHome(main) {
    const w = W();
    const cal = YA.calendar(w.week);
    const opp = YA.hasMatch(w.week) ? YA.opponentOf(w) : null;
    const wrap = h('div', { class: 'home' });
    // 左：今週
    const left = h('div', { class: 'card', style: 'width:36%;min-width:250px;padding:10px;display:flex;flex-direction:column;gap:6px' });
    left.append(h('div', { class: 'sub' }, w.clubName), h('div', { class: 'h', style: 'font-size:19px' }, `${w.year}年目  ${cal.month}第${cal.nth}週`), h('div', { class: 'note' }, `Aチーム ${w.rec.w}勝 ${w.rec.d}分 ${w.rec.l}敗  得点${w.rec.gf} 失点${w.rec.ga}`));
    left.append(h('div', { style: 'border-top:1px dashed var(--line);padding-top:6px' }, h('div', { class: 'note' }, '今週の試合'), opp ? h('div', {}, h('b', {}, `${opp.home ? 'ホーム' : 'アウェイ'} vs ${opp.name}`), h('div', { class: 'note' }, opp.desc)) : h('div', { class: 'sub' }, 'なし（試合のない期間）。育成に集中できます')));
    const S = YA.summaryOf(w);
    left.append(h('div', { class: 'row', style: 'flex-wrap:wrap;gap:4px' }, S.injured.length ? h('span', { class: 'fit bad' }, '怪我 ' + S.injured.length + '人') : null, S.tired.length ? h('span', { class: 'fit bad' }, '疲れ ' + S.tired.length + '人') : null, S.lowconf.length ? h('span', { class: 'fit bad' }, '自信なし ' + S.lowconf.length + '人') : null, S.hot.length ? h('span', { class: 'fit good' }, '好調・成長期 ' + S.hot.length + '人') : null));
    left.append(h('div', { class: 'grow' }));
    const act = h('div', { style: 'display:flex;flex-direction:column;gap:5px' });
    if (w.phase === 'plan') {
      act.append(h('button', { class: 'btn', onclick: () => { U().app.tab = 'train'; rerender(); } }, '練習を組む（今週のメニュー）'));
      act.append(h('button', { class: 'btn pri', style: 'min-height:42px;font-size:14px', onclick: () => { runWeek(); } }, '練習を確定して週を進める'));
    } else if (w.phase === 'event') {
      act.append(h('button', { class: 'btn pri', style: 'min-height:42px', onclick: () => rerender() }, '出来事を確認する'));
    } else if (w.phase === 'match') {
      act.append(h('button', { class: 'btn pri', style: 'min-height:42px;font-size:14px', onclick: () => { U().app.tab = 'match'; U().app.free = false; U().app.view = 'pre'; rerender(); } }, '試合へ（布陣と戦い方を決める）'));
    } else {
      act.append(h('div', { class: 'note' }, w.matchDone ? '試合が終わりました。Bチームの試合も済んでいます。' : '今週はここまで。'), h('button', { class: 'btn pri', style: 'min-height:42px;font-size:14px', onclick: () => endWeek() }, w.week >= YA.WEEKS ? '卒業式へ' : '次の週へ'));
    }
    left.append(act);
    // 中：お知らせ＋先週の伸び
    const mid = h('div', { class: 'card pbody', style: 'flex:1;min-width:0' });
    mid.append(h('div', { class: 'h' }, 'お知らせ'));
    const list = h('div', { class: 'plist', style: 'margin-top:4px' });
    const items = w.inbox.slice(-14).reverse();
    for (const n of items) {
      const dot = n.tier === 1 ? '#d63a3a' : n.tier === 2 ? '#1f6feb' : '#b9c7de';
      list.append(h('button', { class: 'pitem', style: 'align-items:flex-start;cursor:default', onclick: () => { if (n.pid && w.players[n.pid]) { U().app.pSel = n.pid; U().app.tab = 'players'; rerender(); } } }, h('span', { style: `width:8px;height:8px;border-radius:50%;background:${dot};margin-top:4px;flex:none` }), h('span', { style: 'font-size:11.5px;line-height:1.4', class: n.tier === 3 ? 'sub' : '' }, (n.week ? `${n.week}週 ` : '') + n.text)));
    }
    mid.append(list);
    // 右：気にかけたい子
    const right = h('div', { class: 'card pbody', style: 'width:210px;flex:none' });
    right.append(h('div', { class: 'h' }, '今週気にかけたい子'));
    const pick = [];
    for (const p of S.injured.concat(S.tired, S.lowconf, Object.values(w.players).filter((q) => q.unrest >= 3), S.hot)) if (pick.indexOf(p) < 0) pick.push(p);
    const gainers = Object.values(w.players).filter((p) => Object.keys(p.gain || {}).length).sort((a, b) => Object.values(b.gain).reduce((x, y) => x + y, 0) - Object.values(a.gain).reduce((x, y) => x + y, 0)).slice(0, 4);
    right.append(h('div', { class: 'plist', style: 'margin-top:4px' }, pick.slice(0, 6).map((p) => h('button', { class: 'pitem', onclick: () => { U().app.pSel = p.id; U().app.tab = 'players'; rerender(); } }, h('span', { class: pcls(p) }, p.pos), h('span', { class: 'nm grow' }, p.name.split(' ')[0]), flags(p)))));
    if (!pick.length) right.append(h('div', { class: 'note' }, '大きな心配はありません'));
    right.append(h('div', { class: 'h', style: 'margin-top:10px' }, '先週の伸び'));
    right.append(h('div', { class: 'plist', style: 'margin-top:4px' }, gainers.map((p) => h('div', { class: 'note', style: 'color:var(--ink)' }, h('b', {}, p.name.split(' ')[0]), ' ', Object.entries(p.gain).map(([a, g]) => `${a}+${g}`).join(' ')))));
    if (!gainers.length) right.append(h('div', { class: 'note' }, 'まだ伸びた能力はありません'));
    wrap.append(left, mid, right);
    wrap.style.cssText = 'flex:1;min-height:0;display:flex;gap:8px';
    main.append(wrap);
    if (w.phase === 'event' && w.events.length) showEvent();
  }

  function runWeek() {
    const w = W();
    w.lastPlan = JSON.parse(JSON.stringify(w.plan));
    YA.startWeek(w);
    if (!w.events.length) afterEvents();
    YA.saveWorld();
    rerender();
  }
  function afterEvents() {
    const w = W();
    w.events = [];
    w.phase = YA.hasMatch(w.week) ? 'match' : 'after';
  }
  function endWeek() {
    const w = W();
    const wasEnd = w.week >= YA.WEEKS;
    const res = YA.endWeek(w);
    YA.saveWorld();
    if (wasEnd && res) {
      rerender();
      modal((close) => h('div', { class: 'sheet-in', style: 'align-self:center;max-height:92%;flex:none;width:min(640px,96%);margin:auto;padding:12px' },
        h('div', { class: 'h', style: 'font-size:16px' }, '卒業式'),
        h('div', { class: 'note', style: 'margin:4px 0' }, `${res.out.length}人が巣立ち、新しい高1の${res.entered}人が入団しました（卒業生は「ほか」の名鑑で追えます）`),
        h('div', { class: 'pbody scroll', style: 'max-height:210px;padding:4px 6px' }, h('div', { class: 'plist' }, res.out.map((o) => h('div', { class: 'pitem' }, h('span', { class: 'pos ' + o.pos }, o.pos), h('span', { class: 'nm grow' }, o.name), h('span', { class: 'chip gray' }, '能力 ' + o.ovr), h('span', { class: 'sub' }, o.note))))),
        h('button', { class: 'btn pri', style: 'margin-top:8px', onclick: close }, '新しい年度へ')));
    } else rerender();
  }

  // 出来事の会話
  function showEvent() {
    const w = W();
    const e = w.events[0];
    const v = YA.eventView(w, e);
    if (!v) {
      w.events.shift();
      if (!w.events.length) afterEvents();
      return rerender();
    }
    modal((close) => {
      const p = v.p;
      const box = h('div', { class: 'sheet-in', style: 'align-self:center;flex:none;width:min(660px,96%);margin:auto;padding:12px;gap:7px' });
      const render1 = () => {
        box.replaceChildren(
          h('div', { class: 'row' }, h('span', { class: 'chip pers' }, '出来事'), h('b', {}, v.name), h('span', { class: 'grow' }), h('span', { class: 'sub' }, `残り${w.events.length}件`)),
          h('div', { class: 'row', style: 'gap:8px' }, h('span', { class: pcls(p) }, p.pos), h('b', { style: 'white-space:nowrap' }, `${p.num}番 ${p.name}`), h('span', { class: 'sub' }, gradeName(p.grade)), U().persChips(p).slice(0, 4)),
          h('div', { class: 'card', style: 'padding:9px 11px;font-size:13px;line-height:1.6' }, v.text),
          ...v.opts.map((label, i) => h('button', { class: 'btn', style: 'justify-content:flex-start;text-align:left;padding:9px 12px', onclick: () => choose(i) }, label)),
        );
      };
      const choose = (i) => {
        const r = YA.resolveEvent(w, e, i);
        box.replaceChildren(
          h('div', { class: 'h' }, v.name),
          h('div', { class: 'card', style: 'padding:9px 11px;font-size:13px;line-height:1.6' }, `${p.name.split(' ')[0]}は、${r.line}`),
          r.small ? h('div', { class: 'chip trait', style: 'align-self:flex-start' }, r.small) : null,
          r.leave ? h('div', { class: 'insight bad' }, r.leave) : null,
          h('button', { class: 'btn pri', onclick: () => { w.events.shift(); if (!w.events.length) afterEvents(); YA.saveWorld(); close(); rerender(); } }, w.events.length > 1 ? '次へ' : '閉じる'),
        );
      };
      render1();
      return box;
    });
  }

  // ---------- 練習 ----------
  const DAYS = ['月', '火', '水', '木', '金'];
  function viewTrain(main) {
    const w = W();
    const ui = U().app;
    ui.tf = ui.tf || 'all';
    const wrap = h('div', { style: 'flex:1;min-height:0;display:flex;flex-direction:column;gap:6px' });
    // 曜日
    const days = h('div', { style: 'display:flex;gap:5px' });
    w.plan.days.forEach((d, i) => {
      const m = YA.MENUS[d.menu];
      days.append(h('button', { class: 'card', style: 'flex:1;padding:6px 8px;text-align:left;min-width:0', onclick: () => pickMenu(i) }, h('div', { class: 'row' }, h('b', { style: 'color:var(--blue-d)' }, DAYS[i]), h('span', { class: 'grow' }), h('span', { class: 'chip ' + (d.int === 'hard' ? 'instr' : d.int === 'light' ? 'gray' : 'pers') }, YA.INTENS_NAMES[d.int])), h('div', { class: 'h', style: 'font-size:13px;margin-top:1px' }, d.menu), h('div', { class: 'note' }, m.note)));
    });
    const bulk = h('div', { class: 'row', style: 'flex-wrap:wrap;gap:4px' },
      h('button', { class: 'btn sm', onclick: () => { if (w.lastPlan) { w.plan = JSON.parse(JSON.stringify(w.lastPlan)); YA.saveWorld(); rerender(); } } }, '先週と同じ'),
      h('button', { class: 'btn sm', onclick: () => { YA.autoPlan(w); YA.saveWorld(); rerender(); } }, 'おまかせ（弱点を重点に・疲れた子は休み）'),
      h('button', { class: 'btn sm', onclick: () => { for (const p of Object.values(w.players)) if (p.fat > 60 && p.inj <= 0) p.rest = 'rest'; YA.saveWorld(); rerender(); } }, '疲れている子を休ませる'),
      h('button', { class: 'btn sm', onclick: () => { for (const p of Object.values(w.players)) p.rest = null; YA.saveWorld(); rerender(); } }, '休みを全部外す'),
      h('span', { class: 'grow' }),
      ...[['all', '全員'], ['A', 'A'], ['B', 'B'], ['1', '高1'], ['2', '高2'], ['3', '高3']].map(([k, n]) => h('button', { class: 'btn sm' + (ui.tf === k ? ' on' : ''), onclick: () => { ui.tf = k; rerender(); } }, n)));
    // 選手の表
    const rows = Object.values(w.players).filter((p) => ui.tf === 'all' || p.team === ui.tf || String(p.grade) === ui.tf).sort((a, b) => (a.team === b.team ? 0 : a.team === 'A' ? -1 : 1) || ['GK', 'DF', 'MF', 'FW'].indexOf(a.pos) - ['GK', 'DF', 'MF', 'FW'].indexOf(b.pos) || b.grade - a.grade);
    const table = h('div', { class: 'card pbody scroll', style: 'flex:1;min-height:0;padding:4px 6px' });
    table.append(h('div', { class: 'pitem', style: 'background:none;font-size:10px;color:var(--sub);font-weight:800' }, h('span', { style: 'width:22px' }), h('span', { style: 'width:20px' }), h('span', { class: 'grow' }, '選手'), h('span', { style: 'width:42px' }, '疲れ'), h('span', { style: 'width:116px' }, '重点にする能力'), h('span', { style: 'width:150px' }, '特性練習'), h('span', { style: 'width:52px' }, '今週')));
    for (const p of rows) {
      const tp = p.train.trait;
      const lt = tp ? YA.learnable(p).find((x) => x.t === tp) : null;
      const wk = tp ? Math.max(1, Math.ceil((100 - (p.tprog[tp] || 0)) / (lt ? 100 / lt.weeks : 1))) : 0;
      table.append(h('div', { class: 'pitem', style: 'cursor:default' },
        h('span', { class: pcls(p) }, p.pos),
        h('span', { class: 'num' }, p.num),
        h('span', { class: 'nm grow', style: 'min-width:0;overflow:hidden;text-overflow:ellipsis' }, p.name, ' ', h('span', { class: 'sub', style: 'font-weight:600' }, gradeName(p.grade) + (p.team === 'A' ? ' A' : ' B')), ' ', flags(p)),
        fatBar(p, 42),
        h('button', { class: 'btn sm', style: 'width:116px;justify-content:space-between', onclick: () => pickFocus(p) }, p.train.focus || '未設定', p.train.focus ? h('span', { class: 'sub' }, p.ab[p.train.focus]) : null),
        h('button', { class: 'btn sm', style: 'width:150px;justify-content:space-between', onclick: () => pickTrait(p) }, tp || '未設定', tp ? h('span', { class: 'sub' }, '残り約' + wk + '週') : null),
        h('button', { class: 'btn sm' + (p.rest ? ' on' : ''), style: 'width:52px', disabled: p.inj > 0, onclick: () => { p.rest = p.rest === null ? 'light' : p.rest === 'light' ? 'rest' : null; YA.saveWorld(); const st = table.scrollTop; rerender(); const t2 = document.querySelector('.card.pbody.scroll'); if (t2) t2.scrollTop = st; } }, p.inj > 0 ? '療養' : p.rest === 'rest' ? '休み' : p.rest === 'light' ? '軽め' : '通常')));
    }
    wrap.append(days, bulk, table);
    main.append(wrap);
  }
  function pickMenu(i) {
    const w = W();
    modal((close) => h('div', { class: 'sheet-in', style: 'flex:none;align-self:center;margin:auto;width:min(680px,97%);padding:10px;gap:7px' },
      h('div', { class: 'h' }, DAYS[i] + '曜日のメニュー'),
      h('div', { style: 'display:grid;grid-template-columns:repeat(4,1fr);gap:5px' }, YA.MENU_NAMES.map((n) => h('button', { class: 'btn' + (w.plan.days[i].menu === n ? ' on' : ''), style: 'flex-direction:column;align-items:flex-start;padding:6px 8px;text-align:left', onclick: () => { w.plan.days[i].menu = n; YA.saveWorld(); close(); rerender(); } }, h('b', {}, n), h('span', { style: 'font-weight:600;font-size:10px;opacity:.8' }, YA.MENUS[n].note)))),
      h('div', { class: 'row' }, h('span', { class: 'sub' }, '強さ'), ...['light', 'normal', 'hard'].map((k) => h('button', { class: 'btn sm' + (w.plan.days[i].int === k ? ' on' : ''), onclick: () => { w.plan.days[i].int = k; YA.saveWorld(); close(); rerender(); } }, YA.INTENS_NAMES[k])), h('span', { class: 'grow' }), h('button', { class: 'btn sm', onclick: close }, '閉じる')),
      h('div', { class: 'note' }, 'きついほど伸びますが、疲れが溜まり怪我もしやすくなります。「回復」は疲れを抜く日です。GKはGKコーチが別メニューで見ます。')));
  }
  function pickFocus(p) {
    const list = p.pos === 'GK' ? YA.AB_GK.concat(YA.AB_MENTAL, YA.AB_PHYS) : YA.AB_FIELD;
    modal((close) => h('div', { class: 'sheet-in', style: 'flex:none;align-self:center;margin:auto;width:min(680px,97%);max-height:94%;padding:10px;gap:6px' },
      h('div', { class: 'row' }, h('div', { class: 'h grow' }, `${p.name} の重点（今の値）`), h('button', { class: 'btn sm', onclick: () => { p.train.focus = null; YA.saveWorld(); close(); rerender(); } }, '外す'), h('button', { class: 'btn sm', onclick: close }, '閉じる')),
      h('div', { class: 'scroll', style: 'display:grid;grid-template-columns:repeat(5,1fr);gap:4px;overflow:auto' }, list.map((n) => h('button', { class: 'btn sm' + (p.train.focus === n ? ' on' : ''), style: 'justify-content:space-between', onclick: () => { p.train.focus = n; YA.saveWorld(); close(); rerender(); } }, n, h('b', {}, p.ab[n])))),
      h('div', { class: 'note' }, '重点にした能力は、ほかより多く伸びます。')));
  }
  function pickTrait(p) {
    const list = YA.learnable(p);
    modal((close) => h('div', { class: 'sheet-in', style: 'flex:none;align-self:center;margin:auto;width:min(680px,97%);max-height:94%;padding:10px;gap:6px' },
      h('div', { class: 'row' }, h('div', { class: 'h grow' }, `${p.name} の特性練習（習得の目安）`), h('button', { class: 'btn sm', onclick: () => { p.train.trait = null; YA.saveWorld(); close(); rerender(); } }, '外す'), h('button', { class: 'btn sm', onclick: close }, '閉じる')),
      h('div', { class: 'scroll', style: 'display:grid;grid-template-columns:repeat(4,1fr);gap:4px;overflow:auto' }, list.map((x) => h('button', { class: 'btn sm' + (p.train.trait === x.t ? ' on' : ''), style: 'flex-direction:column;align-items:flex-start;gap:0', onclick: () => { p.train.trait = x.t; YA.saveWorld(); close(); rerender(); } }, h('b', {}, x.t), h('span', { style: 'font-weight:600;font-size:10px;opacity:.85' }, x.weeks <= 40 ? `約${x.weeks}週` : '1年では届かない')))),
      h('div', { class: 'note' }, '覚えやすさは、その特性に効く能力2つで決まります。向いていない子は時間がかかります。')));
  }

  // ---------- 選手 ----------
  function viewPlayers(main) {
    const w = W();
    const ui = U().app;
    ui.pf = ui.pf || 'all';
    const all = Object.values(w.players);
    const f = ui.pf;
    const filtered = all.filter((p) => f === 'all' || f === p.team || f === String(p.grade) || f === p.pos || (f === 'star' && p.star) || (f === 'inj' && p.inj > 0)).sort((a, b) => ['GK', 'DF', 'MF', 'FW'].indexOf(a.pos) - ['GK', 'DF', 'MF', 'FW'].indexOf(b.pos) || b.grade - a.grade || YA.ovr(b) - YA.ovr(a));
    if (!ui.pSel || !w.players[ui.pSel]) ui.pSel = (filtered[0] || all[0]).id;
    const sel = w.players[ui.pSel];
    const left = h('div', { class: 'card', style: 'width:262px;flex:none;display:flex;flex-direction:column;min-height:0;padding:5px' });
    const chips = h('div', { class: 'fm-row', style: 'margin-bottom:4px' }, [['all', '全員'], ['A', 'A'], ['B', 'B'], ['1', '高1'], ['2', '高2'], ['3', '高3'], ['GK', 'GK'], ['DF', 'DF'], ['MF', 'MF'], ['FW', 'FW'], ['star', '★'], ['inj', '怪我']].map(([k, n]) => h('button', { class: 'btn sm' + (f === k ? ' on' : ''), style: 'padding:2px 6px;min-height:22px;font-size:10.5px', onclick: () => { ui.pf = k; rerender(); } }, n)));
    const list = h('div', { class: 'plist scroll', style: 'flex:1;min-height:0' }, filtered.map((p) => h('button', { class: 'pitem' + (p.id === sel.id ? ' on' : ''), onclick: () => { ui.pSel = p.id; const st = list.scrollTop; rerender(); const l2 = document.querySelector('.plist.scroll'); if (l2) l2.scrollTop = st; } }, h('span', { class: pcls(p) }, p.pos), h('span', { class: 'num' }, p.num), h('span', { class: 'nm grow', style: 'overflow:hidden;text-overflow:ellipsis' }, p.name), h('span', { class: 'sub', style: 'font-size:10px' }, gradeName(p.grade) + p.team), h('b', { style: 'width:26px;text-align:right' }, YA.ovr(p).toFixed(1)), p.inj > 0 ? h('span', { class: 'fit bad' }, '怪') : null, p.star ? h('span', { style: 'color:#e6a800' }, '★') : null)));
    left.append(chips, list);
    const right = h('div', { class: 'card pbody', style: 'flex:1;min-width:0' });
    right.append(U().playerCard({ lineup: w.lineupA }, sel, { all: true }));
    // 追加の情報（伸びしろの目安・状態・履歴）
    const stars = YA.starsOf(sel);
    right.prepend(h('div', { class: 'row', style: 'flex-wrap:wrap;gap:5px;margin-bottom:6px' },
      h('span', { class: 'chip gray' }, `${gradeName(sel.grade)} / ${sel.team}チーム`), h('span', { class: 'chip gray' }, `疲れ ${Math.round(sel.fat)}`), h('span', { class: 'chip gray' }, `出場 ${sel.mins}分`),
      h('span', { class: 'chip trait' }, '伸びしろ ' + '★'.repeat(stars[0]) + '☆'.repeat(stars[1] - stars[0]) + '（目安）'), ...flags(sel),
      h('button', { class: 'btn sm', onclick: () => { sel.star = !sel.star; YA.saveWorld(); rerender(); } }, sel.star ? '★ を外す' : '★ 注目の印'),
      h('button', { class: 'btn sm', onclick: () => swapTeam(sel) }, sel.team === 'A' ? 'Bに回す' : 'Aに上げる')));
    // 面談
    const talk = h('div', { style: 'margin-top:8px;border-top:1px dashed var(--line);padding-top:6px' }, h('div', { class: 'h' }, '面談（1人とは週1回まで）'));
    const res = h('div', { class: 'msglog' });
    const can = YA.canTalk(w, sel);
    talk.append(h('div', { class: 'fm-row', style: 'margin-top:4px' }, YA.TALKS.map((t) => h('button', { class: 'btn', disabled: !can, onclick: () => { const r = YA.talk(w, sel.id, t.k); res.replaceChildren(h('div', {}, r.ok ? `${sel.name.split(' ')[0]}は、${r.line}${r.small ? '（' + r.small + '）' : ''}${r.extra ? ' / ' + r.extra : ''}` : r.msg)); YA.saveWorld(); talkBtns(); } }, t.label))));
    talk.append(res);
    const talkBtns = () => { for (const b of talk.querySelectorAll('button')) b.disabled = true; };
    right.append(talk);
    // 履歴
    if (sel.hist.length) right.append(h('div', { class: 'h', style: 'margin-top:8px' }, '最近のこと'), h('div', { class: 'note', style: 'color:var(--ink)' }, sel.hist.slice(0, 6).map((x) => h('div', {}, `${x.y}年目 ${x.w}週：${x.t}`))));
    main.append(h('div', { style: 'flex:1;min-height:0;display:flex;gap:8px' }, left, right));
  }
  function swapTeam(p) {
    const w = W();
    if (w.lineupA.some((s) => s.pid === p.id) || w.lineupB.some((s) => s.pid === p.id)) {
      modal((close) => h('div', { class: 'sheet-in', style: 'flex:none;align-self:center;margin:auto;width:min(420px,95%);padding:12px;gap:8px' }, h('div', { class: 'h' }, '先発にいる選手です'), h('div', { class: 'note' }, 'まず試合の「選手と役割」で、ベンチと入れ替えてから動かしてください。'), h('button', { class: 'btn pri', onclick: close }, '閉じる')));
      return;
    }
    const toA = p.team === 'B';
    if (toA) {
      // Aのベンチから、同じ位置の一番下の選手と入れ替える
      const k = w.benchA.map((id) => w.players[id]).filter((q) => q && q.pos === p.pos).sort((a, b) => YA.ovr(a) - YA.ovr(b))[0] || w.benchA.map((id) => w.players[id]).sort((a, b) => YA.ovr(a) - YA.ovr(b))[0];
      if (!k) return;
      w.benchA[w.benchA.indexOf(k.id)] = p.id;
      k.team = 'B';
      p.team = 'A';
      w.benchB = (w.benchB || []).filter((id) => id !== p.id).concat([k.id]);
    } else {
      const k = Object.values(w.players).filter((q) => q.team === 'B' && q.pos === p.pos && !w.lineupB.some((s) => s.pid === q.id) && q.inj <= 0).sort((a, b) => YA.ovr(b) - YA.ovr(a))[0];
      if (!k) return;
      w.benchA[w.benchA.indexOf(p.id)] = k.id;
      p.team = 'B';
      k.team = 'A';
    }
    YA.saveWorld();
    rerender();
  }

  // ---------- クラブ・ほか ----------
  function viewClub(main) {
    const w = W();
    const rows = w.results.slice(-12).reverse();
    main.append(h('div', { style: 'flex:1;min-height:0;display:flex;gap:8px' },
      h('div', { class: 'card pbody', style: 'flex:1' }, h('div', { class: 'h' }, 'Aチームの試合結果'), h('div', { class: 'plist', style: 'margin-top:5px' }, rows.map((r) => h('div', { class: 'pitem', style: 'cursor:default' }, h('span', { class: 'sub', style: 'width:68px' }, `${r.year}年目 ${r.week}週`), h('span', { class: 'nm grow' }, r.opp), h('b', { style: `color:${r.gf > r.ga ? '#1a9d57' : r.gf < r.ga ? '#d63a3a' : 'inherit'}` }, `${r.gf} - ${r.ga}`)))), !rows.length ? h('div', { class: 'note' }, 'まだ試合がありません') : null),
      h('div', { class: 'card big-note', style: 'width:260px;flex:none;padding:10px' }, h('div', { class: 'h' }, 'クラブ運営'), h('p', { class: 'note' }, '予算・スタッフ・信頼度・契約・スカウトは、この版にはまだありません。育成を遊んで、手応えを見てから足します。'))));
  }
  function viewMore(main) {
    const w = W();
    const ui = U().app;
    ui.mt = ui.mt || 'alumni';
    const tabs = h('div', { class: 'tabs', style: 'width:300px' }, [['alumni', '卒業生名鑑'], ['set', '設定']].map(([k, n]) => h('button', { class: 'btn' + (ui.mt === k ? ' on' : ''), onclick: () => { ui.mt = k; rerender(); } }, n)));
    const body = h('div', { class: 'card pbody', style: 'flex:1;min-height:0' });
    if (ui.mt === 'alumni') {
      body.append(h('div', { class: 'h' }, '卒業生と退団者'));
      const al = w.alumni.slice().reverse();
      body.append(h('div', { class: 'plist', style: 'margin-top:5px' }, al.map((a) => h('div', { class: 'pitem', style: 'cursor:default' }, h('span', { class: 'pos ' + a.pos }, a.pos), h('span', { class: 'nm grow' }, a.name), h('span', { class: 'sub' }, `${a.year}年目`), h('span', { class: 'chip gray' }, '能力 ' + a.ovr), h('span', { class: 'sub', style: 'width:150px' }, a.note)))));
      if (!al.length) body.append(h('div', { class: 'note', style: 'margin-top:6px' }, '最初の卒業式（1年目の終わり）で、ここに並びます。'));
    } else {
      body.append(h('div', { class: 'h' }, '設定'));
      body.append(h('div', { class: 'row', style: 'margin:6px 0' }, h('span', { class: 'grow' }, '試合の自動停止（前半終了・得点・失点・残り15分）'), h('button', { class: 'btn sm' + (ui.autoStop ? ' on' : ''), onclick: () => { ui.autoStop = !ui.autoStop; U().store.set('autoStop', ui.autoStop); rerender(); } }, ui.autoStop ? 'ON' : 'OFF')));
      body.append(h('div', { class: 'h', style: 'margin-top:12px' }, '最初からやり直す'), h('div', { class: 'note' }, '36人も成績も消えて、新しい世界が始まります。'), h('button', { class: 'btn', style: 'margin-top:5px;color:#b02020', onclick: () => modal((close) => h('div', { class: 'sheet-in', style: 'flex:none;align-self:center;margin:auto;width:min(420px,95%);padding:12px;gap:8px' }, h('div', { class: 'h' }, '本当に最初からやり直しますか'), h('div', { class: 'row' }, h('button', { class: 'btn', onclick: close }, 'やめる'), h('button', { class: 'btn pri', onclick: () => { ui.w = YA.newWorld((Date.now() % 90000) + 7); ui.view = 'pre'; ui.pSel = null; ui.tab = 'home'; YA.saveWorld(); close(); rerender(); } }, 'やり直す')))) }, '最初からやり直す'));
    }
    main.append(h('div', { style: 'flex:1;min-height:0;display:flex;flex-direction:column;gap:6px' }, tabs, body));
  }

  YA.views = { home: viewHome, train: viewTrain, players: viewPlayers, club: viewClub, more: viewMore };
})();
