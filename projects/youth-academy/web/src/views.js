// 育成の画面：ホーム・選手・練習・クラブ・ほか。中身は world.js、ここは見せ方と操作だけ。
(function () {
  'use strict';
  const YA = (globalThis.YA = globalThis.YA || {});
  const U = () => YA._ui;
  const h = (...a) => U().h(...a);
  const W = () => U().app.w;
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

  // 保存は少しまとめて（操作のたびに全部は書かない）。now ならすぐ書く（年度はじめの控えも同じ道で書く）
  let saveT = null;
  // 保存の成否（続けて失敗したら知らせる・設定に最後に保存できた時刻を出す）
  YA.saveState = { fails: 0, lastOk: null, lastFail: null, warned: false };
  YA.saveResult = function (ok) {
    const st = YA.saveState;
    if (ok) {
      st.fails = 0;
      st.lastOk = Date.now();
      st.warned = false;
      return;
    }
    st.fails++;
    st.lastFail = Date.now();
    if (st.fails >= 2 && !st.warned) {
      st.warned = true;
      try { YA.toast('保存できませんでした。端末の空きを確かめてください（設定に最後に保存できた時刻があります）'); } catch (e) { /* 画面なし */ }
    }
  };
  // Flutter 側で書けなかった（store.set の後から届く）。成功の知らせは来ないので、こちらは失敗だけを数える
  YA.saveFailed = function () {
    const st = YA.saveState;
    st.nativeFails = (st.nativeFails || 0) + 1;
    st.lastFail = Date.now();
    if (st.nativeFails >= 2 && !st.warned) {
      st.warned = true;
      try { YA.toast('保存できませんでした。端末の空きを確かめてください（設定に最後に保存できた時刻があります）'); } catch (e) { /* 画面なし */ }
    }
  };
  function writeWorld() {
    const A = U().app;
    if (!A.w) return;
    let ok = false;
    try {
      const key = YA.slotKey(A.slot || 0);
      ok = U().store.set(key, A.w) !== false;
      // 年度はじめの控え（決定78：壊れたときのために）
      if (A.w.week === 1 && A.w.phase === 'plan') U().store.set(key + '_bak', A.w);
    } catch (e) {
      ok = false;
    }
    YA.saveResult(ok);
  }
  YA.saveWorld = function (now) {
    clearTimeout(saveT);
    saveT = null;
    if (now) return writeWorld();
    saveT = setTimeout(() => {
      saveT = null;
      writeWorld();
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
  const posc = (p) => YA._apt.posChip(p);
  const gradeName = (g) => '高' + g;
  const fatColor = (v) => (v > 75 ? '#d63a3a' : v > 50 ? '#f0a020' : '#1a9d57');
  const fatBar = (p, wd) => h('div', { class: 'bar', style: `width:${wd || 40}px` }, h('i', { style: `width:${p.fat}%;background:${fatColor(p.fat)}` }));
  const flags = (p) => [p.inj > 0 ? h('span', { class: 'fit bad' }, '怪我' + p.inj + '週') : null, p.spurt > 0 ? h('span', { class: 'fit good' }, '成長期') : null, p.state && p.state.w > 0 ? h('span', { class: 'fit ' + (p.state.k === 'peak' ? 'good' : 'bad') }, p.state.k === 'peak' ? '伸び盛り' : '壁') : null, p.kd && YA.kadaiDef ? h('span', { class: 'chip trait' }, '課題：' + YA.kadaiDef(p.kd.t).name) : null, p.awake ? h('span', { class: 'fit good' }, `覚醒（${p.awake.y}年目）`) : null, p.youthCaps ? h('span', { class: 'chip pers' }, `${p.youthTeam || '年代別代表'} ${p.youthCaps}回`) : null, p.unrest >= 3 ? h('span', { class: 'fit bad' }, '不満') : null];

  // 週を進めるボタン（ホームと練習で同じ言葉・同じ大きさ）
  const WEEK_GO = 'この週で行く ▶';
  const WEEK_GO_STYLE = 'min-height:42px;font-size:14px';
  YA.WEEK_GO = WEEK_GO;
  // お知らせの重要度の札（色だけにしない）
  const NOTICE_TAG = { 1: ['大事', '#d63a3a', '#fff'], 2: ['通常', '#dbe9ff', '#134a9e'], 3: ['記録', '#eef2f8', '#5b6a85'] };
  const noticeTag = (et) => { const t = NOTICE_TAG[et] || NOTICE_TAG[3]; return h('span', { class: 'ntag', style: `flex:none;font-size:11px;font-weight:800;line-height:1.5;padding:0 4px;border-radius:5px;margin-top:1px;background:${t[1]};color:${t[2]}` }, t[0]); };
  YA.noticeTagText = (et) => (NOTICE_TAG[et] || NOTICE_TAG[3])[0];

  // ---------- ホーム ----------
  // 2026-11-25「各画面の構成について会話したい」→ ホームは「今週やること」に絞る（ユーザー決定）。
  //   上：お知らせを1行だけ（大事な知らせ＋新しい件数）。押すと一覧の窓
  //   左：週の表示と大きなボタン、今週の試合　真ん中：やり残し　右：今週気にかけたい子
  //   外したもの：次の実績（→記録）・今週の伸び（→選手）・トップの順位（→クラブ）・ご褒美の動画（→ほかのショップ）
  const nkey = (n) => `${n.year || 0}-${n.week || 0}-${String(n.text).slice(0, 24)}`;
  const nNew = (w, n) => ((n.year || 0) * 100 + (n.week || 0)) > (w.readAt || 0) && YA.noticeTier(w, n) <= 2;
  // お知らせの一覧（窓の中身）
  function noticeList(w, close) {
    const showLog = !!U().app.showLog;
    const box = h('div', { style: 'display:flex;flex-direction:column;min-height:0;flex:1' });
    const list = h('div', { class: 'plist scroll', style: 'margin-top:4px;flex:1;min-height:0;overflow:auto' });
    w.pins = (w.pins || []).filter((k) => w.inbox.some((n) => nkey(n) === k));
    const pinned = w.inbox.filter((n) => w.pins.indexOf(nkey(n)) >= 0);
    const redraw = () => { close(); openNotices(); };
    for (const n of pinned) list.append(h('div', { class: 'pitem', style: 'cursor:default;align-items:flex-start;background:#fff8e1' }, h('b', { style: 'font-size:11px;color:#a37b00;flex:none' }, '留'), h('span', { class: 'grow', style: 'font-size:11.5px;line-height:1.4' }, (n.week ? `${YA.wkName(n.week)} ` : '') + n.text), h('button', { class: 'btn sm', style: 'min-height:32px;padding:0 9px', onclick: () => { w.pins = w.pins.filter((k) => k !== nkey(n)); YA.saveWorld(); redraw(); } }, '外す')));
    const items = w.inbox.filter((n) => (showLog || YA.noticeTier(w, n) <= 2) && w.pins.indexOf(nkey(n)) < 0).slice(-40).reverse();
    for (const n of items) {
      const et = YA.noticeTier(w, n);
      const isNew = nNew(w, n);
      // 重要度は色の点だけでなく短い札で（2026-11-17 点検）。選手につながるお知らせには「›」
      const go = n.pid && w.players[n.pid];
      // 留めるのは行の長押しで（2026-11-18 ユーザビリティ17）
      const row = h('div', { class: 'pitem', style: 'align-items:flex-start;cursor:' + (go ? 'pointer' : 'default') + (isNew ? ';font-weight:700' : '') }, noticeTag(et), h('span', { class: 'grow ' + (et === 3 ? 'sub' : ''), style: 'font-size:12px;line-height:1.45' }, (n.week ? `${YA.wkName(n.week)} ` : '') + n.text, go ? h('b', { class: 'goarrow', style: 'color:var(--blue-d);margin-left:4px;font-size:13px' }, '›') : null));
      let lp = null, held = false;
      if (et <= 2) {
        row.addEventListener('pointerdown', () => { held = false; lp = setTimeout(() => { held = true; w.pins = (w.pins || []).concat([nkey(n)]).slice(-5); YA.saveWorld(); if (YA.toast) YA.toast('上に留めました（外すときは「外す」）'); redraw(); }, 550); });
        for (const ev of ['pointerup', 'pointerleave', 'pointercancel']) row.addEventListener(ev, () => clearTimeout(lp));
      }
      row.addEventListener('click', () => { if (held) return; if (go) { close(); U().app.pSel = n.pid; U().app.tab = 'players'; rerender(); } });
      list.append(row);
    }
    if (!items.length && !pinned.length) list.append(h('div', { class: 'note' }, 'お知らせはありません'));
    const unread = w.inbox.filter((n) => nNew(w, n)).length;
    box.append(list, h('div', { class: 'note', style: 'margin-top:3px' }, '大事・通常のお知らせは、長押しで上に留められます（5件まで）'), h('div', { class: 'row', style: 'gap:5px;margin-top:5px' }, h('button', { class: 'btn sm', onclick: () => { U().app.showLog = !showLog; redraw(); } }, showLog ? '記録だけのものを隠す' : 'すべてのお知らせ'), unread ? h('button', { class: 'btn sm', onclick: () => { w.readAt = w.year * 100 + w.week; YA.saveWorld(); close(); rerender(); } }, 'すべて読んだ') : null));
    return box;
  }
  function openNotices() {
    const w = W();
    modal((close) => h('div', { class: 'sheet-in noticewin', style: 'flex:none;align-self:center;margin:auto;width:min(680px,96%);max-height:92%;padding:10px 12px;display:flex;flex-direction:column' },
      h('div', { class: 'row', style: 'gap:6px' }, h('div', { class: 'h grow' }, 'お知らせ'), h('button', { class: 'btn sm', onclick: () => { close(); rerender(); } }, '閉じる')),
      noticeList(w, close)));
  }
  YA.openNotices = openNotices;
  // 今週気にかけたい子：理由を短く添える。課題中の子は期限の近さも
  function careList(w, S) {
    const why = new Map();
    const add = (p, t) => { if (!why.has(p)) why.set(p, t); };
    for (const p of S.injured) add(p, '怪我 ' + p.inj + '週');
    for (const p of Object.values(w.players)) if (p.unrest >= 3) add(p, '不満');
    for (const p of S.tired) add(p, '疲れ ' + Math.round(p.fat));
    for (const p of S.lowconf) add(p, '自信なし');
    for (const p of Object.values(w.players)) {
      const ks = p.kd && YA.kadaiState ? YA.kadaiState(w, p) : null;
      if (ks && ks.len - ks.e <= 2) add(p, '課題の期間が残りわずか');
    }
    for (const p of S.hot) add(p, p.spurt > 0 ? '成長期' : '好調');
    return [...why.entries()];
  }
  function viewHome(main) {
    const w = W();
    const cal = YA.calendar(w.week);
    const opp = YA.matchOf(w) ? YA.opponentOf(w) : null;
    // ホームを開いたら、その週より前のお知らせは既読にする（2026-11-16 案A）。数は今週の分だけ
    w.readAt = Math.max(w.readAt || 0, w.year * 100 + w.week - 1);
    const page = h('div', { class: 'home', style: 'flex:1;min-height:0;display:flex;flex-direction:column;gap:6px' });
    // 上：お知らせを1行
    const unread = w.inbox.filter((n) => nNew(w, n));
    const top = unread.filter((n) => YA.noticeTier(w, n) === 1).pop() || unread.pop() || w.inbox.filter((n) => YA.noticeTier(w, n) <= 2).slice(-1)[0];
    // 行全体を押せるようにするが、button にはしない（中の文がほかのボタン探しに紛れないように）
    page.append(h('div', { class: 'card nbar', role: 'button', tabindex: '0', style: 'flex:none;display:flex;align-items:center;gap:7px;padding:5px 10px;min-height:36px;text-align:left;cursor:pointer;border:1px solid var(--line)', onclick: openNotices },
      h('b', { style: 'flex:none;font-size:12px;color:var(--navy)' }, 'お知らせ'),
      unread.length ? h('span', { class: 'nbadge', style: 'flex:none;background:#d63a3a;color:#fff;border-radius:9px;padding:0 7px;font-size:11px;font-weight:800;line-height:18px' }, '新しい' + unread.length + '件') : null,
      top ? noticeTag(YA.noticeTier(w, top)) : null,
      h('span', { class: 'grow', style: 'min-width:0;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;font-size:12px' }, top ? (top.week ? `${YA.wkName(top.week)} ` : '') + top.text : 'お知らせはありません'),
      h('b', { style: 'flex:none;color:var(--blue-d)' }, '一覧 ›')));
    const wrap = h('div', { style: 'flex:1;min-height:0;display:flex;gap:8px' });
    // 左：週と大きなボタン、今週の試合
    const left = h('div', { class: 'card home-left', style: 'width:36%;min-width:250px;padding:10px;display:flex;flex-direction:column;gap:6px;overflow-y:auto;overflow-x:hidden' });
    const prom = (w.promises || []).filter((x) => w.players[x.pid]);
    left.append(h('div', { class: 'row', style: 'gap:6px' }, YA.emblemEl(w, w.clubName, 24), h('div', { class: 'sub' }, w.clubName)),
      h('div', { class: 'h', style: 'font-size:19px' }, `${w.year}年目  ${cal.month}第${cal.nth}週`),
      h('div', { class: 'note' }, `${YA.weekLabel(w) || '育成の週'} ／ ${YA.levelNames(w)[w.league.level - 1]} ${YA.myRank(w)}位 ／ ${w.rec.w}勝${w.rec.d}分${w.rec.l}敗`));
    const ex = YA.homeExtra();
    const act = h('div', { style: 'display:flex;flex-direction:column;gap:5px' });
    if (w.phase === 'plan') {
      // 練習は月に1回組めばよい。同じ月の残りの週は、組んだメニューのまま1タップで進める
      const mk = w.year * 100 + YA.monthIdx(w.week);
      const set = w.planMonth === mk;
      // 「週を進める」は練習の画面と同じ言葉・同じ大きさ（2026-11-17 点検）
      act.append(h('button', { class: 'btn pri', style: WEEK_GO_STYLE, onclick: () => { runWeek(); } }, WEEK_GO));
      act.append(h('div', { class: 'note', style: 'margin-top:-3px' }, set ? `${cal.month}に組んだ練習のまま進みます` : 'いまの練習で確定して進みます'));
      act.append(h('button', { class: 'btn', onclick: () => { U().app.tab = 'train'; rerender(); } }, set ? '今月の練習を組み直す' : `練習を組む（${cal.month}のメニュー）`));
    } else if (w.phase === 'event') {
      act.append(h('button', { class: 'btn pri', style: 'min-height:42px', onclick: () => rerender() }, '出来事を確認する'));
    } else if (w.phase === 'match') {
      act.append(h('button', { class: 'btn pri', style: 'min-height:42px;font-size:14px', onclick: () => { U().app.tab = 'match'; U().app.free = false; U().app.view = 'pre'; rerender(); } }, '試合へ（布陣と戦い方を決める）'));
    } else {
      // 同じ月のうちは「次の週へ」1回で、練習はそのまま出来事・試合まで進む（2026-11-18 ユーザビリティ9）
      const chain = YA.weekChainable(w);
      act.append(h('div', { class: 'note' }, w.matchDone ? '試合が終わりました。Bチームの試合も済んでいます。' : '今週はここまで。'), h('button', { class: 'btn pri', style: 'min-height:42px;font-size:14px', onclick: () => endWeek(chain) }, w.week >= YA.WEEKS ? '卒業式へ' : chain ? '次の週へ ▶' : '次の週へ（練習を組む）'));
      if (chain) act.append(h('div', { class: 'note', style: 'margin-top:-3px' }, `${cal.month}の練習のまま進みます`), h('button', { class: 'btn sm', onclick: () => endWeek(false) }, '練習やスカウトを見てから進む'));
    }
    left.append(act);
    // 今週の試合：相手・大会・相手の型
    const S = YA.summaryOf(w);
    left.append(h('div', { class: 'card hmatch', style: 'padding:6px 9px;background:#f5f8fd;box-shadow:none;flex:none' },
      h('div', { class: 'sub', style: 'font-size:11px;font-weight:800' }, '今週の試合'),
      opp ? h('div', { class: 'row', style: 'gap:5px;margin-top:2px' }, h('span', { class: 'chip ' + (opp.home ? 'pers' : 'gray'), style: 'flex:none' }, opp.home ? 'ホーム' : 'アウェイ'), h('b', { style: 'min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap' }, `vs ${opp.name}`)) : h('div', { class: 'sub' }, '今週は試合なし。育成に集中できます'),
      opp ? h('div', { class: 'note' }, YA.weekLabel(w) || 'リーグ戦') : null,
      opp && opp.desc ? h('div', { class: 'note', style: 'display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden' }, opp.desc) : null));
    for (const x of prom) left.append(h('div', { class: 'fit bad', style: 'align-self:flex-start' }, `約束：${x.name.split(' ')[0]}を${x.why.replace('保護者に、', '')}（あと${Math.max(0, x.until - w.week + 1)}週）`));
    if (ex) left.append(ex);
    const simc = YA.simCard();
    if (simc) left.append(simc);
    // 真ん中：やり残し（期限の近い順。全部）
    const mid = h('div', { class: 'card pbody home-mid', style: 'flex:1;min-width:0' });
    mid.append(h('div', { class: 'row', style: 'gap:6px' }, h('div', { class: 'h' }, 'やり残し'), h('span', { class: 'sub', style: 'font-size:11px' }, '期限の近い順。押すとその画面へ')));
    const hint = w.phase === 'plan' ? YA.scoutHint(w) : null;
    const todo = YA.todoCard ? YA.todoCard(w, 20, true) : null;
    if (todo) mid.append(todo);
    if (hint) {
      const m = String(hint).match(/^(.*?）)(（.*）)$/);
      mid.append(h('button', { class: 'pitem', style: 'margin-top:5px;min-height:36px', onclick: () => { const wn = YA.scoutWindow(w); U().app.tab = 'club'; U().app.ct = wn.int ? 'int' : wn.sel ? 'sel' : 'scout'; rerender(); } }, h('span', { class: 'grow', style: 'font-size:12px;text-align:left' }, m ? m[1] : hint, m ? h('div', { class: 'sub', style: 'font-size:11px' }, m[2].slice(1, -1)) : null), h('b', { style: 'color:#7a8aa6' }, '›')));
    }
    if (!todo && !hint) mid.append(h('div', { class: 'note' }, 'いま決めることはありません。「この週で行く」で進めます'));
    // 右：今週気にかけたい子
    const right = h('div', { class: 'card pbody home-right', style: 'width:230px;flex:none' });
    right.append(h('div', { class: 'h' }, '今週気にかけたい子'));
    const care = careList(w, S);
    right.append(h('div', { class: 'plist', style: 'margin-top:4px' }, care.slice(0, 8).map(([p, t]) => h('button', { class: 'pitem', onclick: () => { U().app.pSel = p.id; U().app.tab = 'players'; rerender(); } }, posc(p), h('span', { class: 'nm grow' }, p.name.split(' ')[0]), h('span', { class: 'sub', style: 'font-size:11px;flex:none' }, t), h('b', { style: 'color:#7a8aa6;flex:none', 'aria-hidden': 'true' }, '›')))));
    if (!care.length) right.append(h('div', { class: 'note' }, '大きな心配はありません'));
    if (care.length > 8) right.append(h('div', { class: 'sub', style: 'font-size:11px' }, `ほか${care.length - 8}人`));
    wrap.append(left, mid, right);
    page.append(wrap);
    if (YA.kadaiBand) page.append(YA.kadaiBand(w, rerender));
    main.append(page);
    if (w.phase === 'event' && w.events.length) showEvent();
    else if (w.kzNow && w.kzNow.length) showEvent('kzNow'); // 試合のあとの気づきの場面と、そこで覚醒した窓（2026-11-27）
    else if (!U().app.holdPrompts) YA.promptsFor();
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
    YA.afterEvents(W());
  }
  // 「次の週へ」1回で練習まで進めてよいか：同じ年度の同じ月で、その月の練習を組んである
  YA.weekChainable = function (w) {
    if (!w || w.phase !== 'after' || w.week >= YA.WEEKS) return false;
    return w.planMonth === w.year * 100 + YA.monthIdx(w.week + 1);
  };
  // 週のはじめに決めることがなければ、続けて今週の練習へ進める（契約・年度はじめ・合宿や入団の時期・出来事で止まる）
  const canChain = (w) => w.phase === 'plan' && w.planMonth === w.year * 100 + YA.monthIdx(w.week) && !w.pendingContract && !w.pendingCoach && !w.yearIntro && !(YA.homeExtra && YA.homeExtra());
  function endWeek(go) {
    const w = W();
    if (YA.todoGate && YA.todoGate(w, () => endWeek(go))) return;
    const wasEnd = w.week >= YA.WEEKS;
    const res = YA.endWeek(w);
    YA.saveWorld();
    // B の試合の一場面が来たら、先にそれを見せる（見終えたら続けて進む）
    if (go && !wasEnd && w.kzNow && w.kzNow.length) { U().app._kzGo = true; U().app.tab = 'home'; return rerender(); }
    if (go && !wasEnd && canChain(w)) {
      U().app.tab = 'home';
      return runWeek();
    }
    if (wasEnd && res) {
      U().app.holdPrompts = true;
      rerender();
      modal((close) => h('div', { class: 'sheet-in', style: 'align-self:center;max-height:92%;flex:none;width:min(640px,96%);margin:auto;padding:12px' },
        h('div', { class: 'h', style: 'font-size:16px' }, '卒業式'),
        h('div', { class: 'note', style: 'margin:4px 0' }, `${res.out.length}人が巣立ち、新しい高1の${res.entered}人が入団しました（卒業生は「記録」の名鑑で追えます）` + (res.contrib ? `　連帯貢献金が${YA.yen(res.contrib)}入りました。` : '')),
        res.eval ? h('div', { class: 'card', style: 'padding:7px 10px;font-size:12px' }, h('b', {}, `今年の評価：${res.eval.letter}`), '　', res.eval.goals.map((g) => `${g.label}：${g.text}（${g.val}）${g.ok ? '達成' : g.score ? '惜しい' : '届かず'}`).join(' ／ ')) : null,
        res.dismissed ? h('div', { class: 'insight bad' }, `解任されました。${res.dismissed.name}（${YA.TIER_NAME[res.dismissed.tier]}）の指導者になります`) : null,
        h('div', { class: 'pbody scroll', style: 'max-height:210px;padding:4px 6px' }, h('div', { class: 'plist' }, res.out.map((o) => h('div', { class: 'pitem' }, h('span', { class: 'pos ' + o.pos }, YA.POS_LABEL[o.main] || o.pos), h('span', { class: 'nm grow' }, o.name), h('span', { class: 'chip gray' }, '総合力 ' + YA.rate(o.ovr)), h('span', { class: 'sub' }, o.note))))),
        h('button', { class: 'btn pri', style: 'margin-top:8px', onclick: () => { U().app.holdPrompts = false; close(); rerender(); } }, '新しい年度へ')));
    } else rerender();
  }

  // 出来事の会話。qk：'events'（週の出来事）か 'kzNow'（試合のあとの気づきの場面と、そこで覚醒した窓）
  function showEvent(qk) {
    const w = W();
    const Q = qk === 'kzNow' ? w.kzNow : w.events;
    // 列の先頭を済ませた：週の出来事が尽きたら試合へ。試合のあとの列が尽きたら、止めていた「次の週へ」の続き
    const next = () => {
      Q.shift();
      if (Q === w.events && !w.events.length) afterEvents();
      if (Q === w.kzNow && !w.kzNow.length && U().app._kzGo) { U().app._kzGo = false; YA.saveWorld(); if (canChain(w)) return runWeek(); }
      YA.saveWorld();
      rerender();
    };
    const e = Q[0];
    const v = YA.eventView(w, e);
    if (!v) return next();
    // 選手の目（試合・練習の気づきの場面）は、時間を止めた図の画面で選ぶ
    if (e.id === 'kizuki' && v.eye && YA.kizukiScreen) {
      modal((close) => {
        const box = YA.kizukiScreen(w, e, {
          onPick: (role) => YA.kizukiSettle(w, e, role),
          onDone: (res) => {
            // 覚醒したら、今の覚醒の窓をすぐ次に見せる
            if (res.kind === 'awake') { const a = YA.kizukiTakeAwake(w, e.pid); if (a) Q.splice(1, 0, a); }
            close();
            next();
          },
        });
        return box || h('div', {});
      });
      return;
    }
    modal((close) => {
      const p = v.p;
      const box = h('div', { class: 'sheet-in evbox', style: 'align-self:center;flex:none;width:min(780px,98%);max-height:100%;margin:auto;padding:10px 12px;gap:6px' });
      // 横向きの低い画面に合わせて、左に人と台詞、右に選ぶボタン（2026-11-18 ユーザビリティ10：窓が画面の高さを超え、選ぶボタンが下に隠れていた）
      const render1 = () => {
        const leftCol = h('div', { class: 'scroll', style: 'flex:1.15;min-width:0;min-height:0;display:flex;flex-direction:column;gap:6px;overflow-y:auto' },
          p ? h('div', { class: 'row', style: 'gap:7px' }, YA.faceEl(w, p, 38), h('div', { style: 'min-width:0' }, h('div', { class: 'row', style: 'gap:5px' }, posc(p), h('b', { style: 'white-space:nowrap;font-size:13.5px' }, `${p.num}番 ${p.name}`), h('span', { class: 'sub' }, gradeName(p.grade))), h('div', { class: 'row', style: 'gap:3px;flex-wrap:wrap;margin-top:2px' }, U().persChips(p).slice(0, 3)))) : h('div', { class: 'row' }, h('span', { class: 'chip gray' }, w.clubName)),
          h('div', { class: 'card', style: 'padding:8px 10px;font-size:13px;line-height:1.6;box-shadow:none' }, v.text),
          v.staffNote ? h('div', { class: 'row', style: 'gap:6px;align-items:flex-start' }, h('span', { class: 'chip trait', style: 'flex:none' }, 'コーチ'), h('span', { style: 'font-size:12px;line-height:1.5' }, v.staffNote)) : null);
        const rightCol = h('div', { class: 'scroll', style: 'flex:1;min-width:0;min-height:0;display:flex;flex-direction:column;gap:5px;overflow-y:auto' },
          v.about ? h('div', { class: 'note' }, v.about) : null,
          ...v.info.map((o, i) => h('button', { class: 'btn', style: 'justify-content:flex-start;text-align:left;padding:7px 10px;gap:6px;flex:none;flex-wrap:wrap', onclick: () => choose(i) },
            o.kind ? h('span', { class: 'chip gray', style: 'font-size:11px;flex:none' }, YA.KIND_LABEL[o.kind]) : null,
            h('span', { class: 'grow' }, o.label),
            o.rec ? h('span', { class: 'chip trait', style: 'flex:none;font-size:11px' }, o.rec) : null,
            o.hint === 'good' ? h('span', { class: 'fit good', style: 'flex:none' }, '響きそう') : o.hint === 'bad' ? h('span', { class: 'fit bad', style: 'flex:none' }, '逆効果かも') : null)),
          p && v.info.some((x) => x.hint) ? h('button', { class: 'note', style: 'text-align:left;text-decoration:underline dotted;align-self:flex-start', onclick: () => YA.toast && YA.toast('「響きそう」「逆効果かも」は、見えている性格からの目安です。同じ言葉でも、性格で受け止め方が変わります。') }, '？「響きそう」の目安とは') : null);
        box.replaceChildren(
          h('div', { class: 'row' }, h('span', { class: 'chip pers' }, v.kizuki ? '気づき' : '出来事'), h('b', {}, v.name), h('span', { class: 'grow' }), h('span', { class: 'sub' }, `残り${Q.length}件`)),
          h('div', { class: 'evcols', style: 'display:flex;gap:10px;min-height:0;flex:1' }, leftCol, rightCol),
        );
      };
      const choose = (i) => {
        const r = YA.resolveEvent(w, e, i);
        // 日常の会話で覚醒したら、今の覚醒の窓をすぐ次に見せる
        if (r.kz && r.kz.kind === 'awake') { const a = YA.kizukiTakeAwake(w, e.pid); if (a) Q.splice(1, 0, a); }
        box.replaceChildren(
          r.kz ? h('div', { class: 'h kzhead' + (r.kz.kind === 'awake' ? ' gold' : '') }, `${v.name}　${r.kz.head}`) : h('div', { class: 'h' }, v.name),
          h('div', { class: 'card', style: 'padding:9px 11px;font-size:13px;line-height:1.6' }, r.kz ? r.kz.text + (r.kz.say ? `「${r.kz.say}」` : '') : (p ? `${p.name.split(' ')[0]}は、` : '') + r.line),
          r.small ? h('div', { class: 'chip trait', style: 'align-self:flex-start' }, r.small) : null,
          r.small && /自信|調子/.test(r.small) ? h('div', { class: 'note' }, '自信：高いほど試合で力を出せる（低いと出来事が起きやすい）。調子：ここ数週の出来。') : null,
          r.leave ? h('div', { class: 'insight bad' }, r.leave) : null,
          h('button', { class: 'btn pri', onclick: () => { close(); next(); } }, Q.length > 1 ? '次へ' : '閉じる'),
        );
      };
      render1();
      return box;
    });
  }

  // ---------- 練習 ----------
  // 2026-11-25 画面の構成の作り直し（ユーザー決定・FM 寄り）：小タブ 予定／チーム／個人／コーチ。下の帯（見込みと「この週で行く」）はいつも出す
  //   予定：月〜日の予定表（1日1コマ。土は試合、日は休み）と、見込み・疲れの高い子
  //   チーム：チームの重点、戦術理解の内訳と展開ごとの指示
  //   個人：選手ごとの重点・特性練習・今週の休み（まとめて操作も）
  //   コーチ：練習に関わるスタッフの顔ぶれと腕前・効き方
  const DAYS = ['月', '火', '水', '木', '金'];
  const TT = [['plan', '予定'], ['team', 'チーム'], ['ind', '個人'], ['coach', 'コーチ']];
  function viewTrain(main) {
    const w = W();
    const ui = U().app;
    if (ui.trainDetail) { ui.trt = 'ind'; ui.trainDetail = false; }
    ui.trt = ui.trt || 'plan'; // app.tt は点検用シミュレーションの設定が使っている
    const wrap = h('div', { style: 'flex:1;min-height:0;display:flex;flex-direction:column;gap:6px' });
    const tabs = h('div', { class: 'tabs ttabs' }, TT.map(([k, n]) => h('button', { class: 'btn sm' + (ui.trt === k ? ' on' : ''), onclick: () => { ui.trt = k; rerender(); } }, n)));
    const body = h('div', { style: 'flex:1;min-height:0;display:flex;gap:10px' });
    if (ui.trt === 'team') trainTeam(w, body);
    else if (ui.trt === 'ind') trainInd(w, ui, body);
    else if (ui.trt === 'coach') trainCoach(w, body);
    else trainPlan(w, body);
    // 下：この週の見込みと勧め（決定86：確かめて1押しで進む）
    const ex = YA.weekOutlook(w);
    const foot = h('div', { class: 'row', style: 'gap:10px;background:#26385d;color:#fff;border-radius:10px;padding:5px 12px;min-height:40px' },
      h('b', {}, 'この週の見込み'), h('span', {}, '伸び ', h('b', { style: 'color:#ffd25e' }, ex.growth)), h('span', {}, '疲れ ', h('b', { style: 'color:#ffb08a' }, ex.fatigue)),
      h('span', { class: 'grow', style: 'font-size:11px;opacity:.9' }, ex.tip),
      // ホームの同じボタンと同じ言葉・大きさ。ほかのボタンと押し違えないよう間を空ける（2026-11-17 点検）
      w.phase === 'plan' ? h('button', { class: 'btn pri', style: WEEK_GO_STYLE + ';margin-left:14px;flex:none', onclick: () => { ui.tab = 'home'; runWeek(); } }, WEEK_GO) : null);
    wrap.append(tabs, body, foot);
    main.append(wrap);
  }
  const menuSlotBtn = (w) => h('button', { class: 'btn sm', onclick: () => YA.slotModal({ title: '1週間のメニューの型', filled: [0, 1, 2].map((i) => !!(w.menuSlots && w.menuSlots[i])), onLoad: (i) => { YA.loadMenuSlot(w, i); YA.saveWorld(); rerender(); }, onSave: (i) => { YA.saveMenuSlot(w, i); YA.saveWorld(); rerender(); } }) }, '型' + (w.menuSlots && w.menuSlots.some(Boolean) ? '（' + w.menuSlots.filter(Boolean).length + '）' : '') + ' ▾');
  // 予定：月〜日。押すとメニューと強さを選ぶ
  function trainPlan(w, body) {
    const left = h('div', { style: 'width:360px;flex:none;display:flex;flex-direction:column;gap:4px;min-height:0;overflow-y:auto' }, h('div', { class: 'row', style: 'gap:4px' }, h('div', { class: 'h grow' }, '今週の予定', h('span', { class: 'sub', 'data-int-legend': '', style: 'font-weight:600;margin-left:6px;font-size:11px' }, '●＝強さ')), sameAsLast(w), h('button', { class: 'btn sm', onclick: () => { YA.autoPlan(w); YA.saveWorld(); rerender(); } }, 'おまかせ'), menuSlotBtn(w)));
    const LOAD = { light: 1, normal: 2, hard: 3 };
    w.plan.days.forEach((d, i) => {
      const m = YA.MENUS[d.menu];
      const lv = m && m.fat > 0 ? LOAD[d.int] || 2 : 0;
      left.append(h('button', { class: 'card', style: 'padding:4px 8px;display:flex;align-items:center;gap:8px;text-align:left;min-height:36px', onclick: () => pickMenu(i) },
        h('b', { style: 'width:22px;height:22px;border-radius:6px;background:var(--navy,#26385d);color:#fff;display:flex;align-items:center;justify-content:center;font-size:12px;flex:none' }, DAYS[i]),
        h('span', { class: 'chip ' + (d.menu === '休み' || d.menu === '回復' ? 'gray' : d.menu === '練習試合' ? 'instr' : 'pers'), style: 'font-size:11.5px' }, d.menu),
        h('span', { class: 'grow sub', style: 'font-size:11.5px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis' }, m ? m.note : ''),
        h('span', { style: 'font-size:11px;letter-spacing:1px;color:' + (lv === 3 ? '#c43c32' : lv === 0 ? '#9aa8be' : '#e0702a') }, '●'.repeat(lv) + '○'.repeat(3 - lv))));
    });
    // 土日：試合と休み（決めることはない）
    const opp = YA.matchOf(w) ? YA.opponentOf(w) : null;
    for (const [dn, mn, note] of [['土', opp ? '試合' : '休み', opp ? `vs ${opp.name}` : '試合のない週'], ['日', '休み', '']]) left.append(h('div', { class: 'card', style: 'padding:4px 8px;display:flex;align-items:center;gap:8px;min-height:32px;opacity:.85' }, h('b', { style: 'width:22px;height:22px;border-radius:6px;background:var(--navy,#26385d);color:#fff;display:flex;align-items:center;justify-content:center;font-size:12px;flex:none' }, dn), h('span', { class: 'chip ' + (mn === '試合' ? 'instr' : 'gray'), style: 'font-size:11.5px' }, mn), h('span', { class: 'grow sub', style: 'font-size:11.5px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis' }, note)));
    const right = h('div', { style: 'flex:1;min-width:0;min-height:0;overflow-y:auto;display:flex;flex-direction:column;gap:8px' });
    // 見込みの中身（伸び・疲れ・怪我のおそれ・コーチの一言）
    const ex = YA.weekOutlook(w);
    const hard = w.plan.days.filter((d) => d.int === 'hard' && YA.MENUS[d.menu] && YA.MENUS[d.menu].fat > 0).length;
    right.append(h('div', { class: 'card', style: 'padding:7px 10px;display:flex;flex-direction:column;gap:3px' }, h('b', {}, '見込み'),
      h('div', { class: 'note', style: 'color:var(--ink)' }, `伸び：${ex.growth} ／ 疲れ：${ex.fatigue} ／ 怪我のおそれ：${hard >= 3 ? '高い' : hard >= 1 ? 'ふつうより高い' : 'ふつう'}`),
      h('div', { class: 'note', style: 'color:var(--ink)' }, 'コーチ：' + ex.tip),
      w.plan.teamFocus ? h('div', { class: 'note' }, `チームの重点：${w.plan.teamFocus}（${YA.TEAM_FOCUS[w.plan.teamFocus].join('・')}）`) : h('div', { class: 'note' }, 'チームの重点はまだ選んでいません（チームの小タブ）')));
    // 疲れの高い子（押すとこの週は休み → 軽め → 通常）
    const tired = Object.values(w.players).filter((p) => p.inj <= 0 && (p.fat >= 55 || p.rest)).sort((a, b) => b.fat - a.fat).slice(0, 6);
    const tb = h('div', { class: 'card', style: 'flex:none;padding:7px 10px;display:flex;flex-direction:column;gap:3px' }, h('div', {}, h('b', {}, '疲れの高い子 '), h('span', { class: 'sub', style: 'font-size:11.5px' }, '押すと この週は休み → 軽め → 通常')));
    if (!tired.length) tb.append(h('div', { class: 'note' }, '疲れが溜まっている子はいません'));
    for (const p of tired) tb.append(h('div', { class: 'pitem', role: 'button', style: 'cursor:pointer', onclick: () => { p.rest = p.rest === null || p.rest === undefined ? 'rest' : p.rest === 'rest' ? 'light' : null; YA.saveWorld(); rerender(); } },
      posc(p), h('span', { class: 'nm', style: 'width:92px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap' }, p.name), fatBar(p, 80), h('b', { style: 'width:26px;text-align:right;color:#c43c32' }, Math.round(p.fat)), h('span', { class: 'chip ' + (p.rest === 'rest' ? 'instr' : p.rest === 'light' ? 'pers' : 'gray'), style: 'width:40px;justify-content:center' }, p.rest === 'rest' ? '休み' : p.rest === 'light' ? '軽め' : '練習')));
    right.append(tb);
    body.append(left, right);
  }
  // チーム：重点・戦術理解の内訳・展開ごとの指示
  function trainTeam(w, body) {
    const right = h('div', { 'data-train-right': '', style: 'flex:1;min-width:0;min-height:0;overflow-y:auto;display:flex;flex-direction:column;gap:8px' });
    const tf = w.plan.teamFocus || null;
    right.append(h('div', { class: 'card', style: 'padding:7px 10px;display:flex;flex-direction:column;gap:5px' }, h('b', {}, 'チームの重点（1つ）'),
      h('div', { class: 'row', style: 'flex-wrap:wrap;gap:4px' }, ...Object.keys(YA.TEAM_FOCUS).map((k) => h('button', { class: 'btn sm' + (tf === k ? ' on' : ''), onclick: () => { w.plan.teamFocus = tf === k ? null : k; YA.saveWorld(); rerender(); } }, k))),
      h('div', { class: 'sub', style: 'font-size:11.5px' }, tf ? `全員の ${YA.TEAM_FOCUS[tf].join('・')} が少し伸びやすくなる` : '選ぶと、全員のその分野が少し伸びやすくなる')));
    if (YA.trainTactEl) right.append(YA.trainTactEl(w));
    body.append(right);
  }
  // 個人：選手ごとの重点・特性練習・今週の休み
  function trainInd(w, ui, body) {
    ui.tf = ui.tf || 'all';
    const col = h('div', { style: 'flex:1;min-width:0;min-height:0;display:flex;flex-direction:column;gap:4px' });
    const strip = 'display:flex;gap:4px;align-items:center;flex-wrap:nowrap;overflow-x:auto;scrollbar-width:none;flex:none';
    const flat = (el) => { for (const c of [...el.querySelectorAll('button, b, .sub, .note')]) { c.style.flex = 'none'; c.style.whiteSpace = 'nowrap'; } return el; };
    const inTarget = (p) => ui.tf === 'all' || p.team === ui.tf || String(p.grade) === ui.tf || p.pos === ui.tf;
    const targets = Object.values(w.players).filter(inTarget);
    col.append(flat(h('div', { class: 'row bulk', style: strip },
      sameAsLast(w),
      h('button', { class: 'btn sm', onclick: () => { YA.autoPlan(w); YA.saveWorld(); rerender(); } }, 'おまかせ'),
      h('button', { class: 'btn sm', onclick: () => { for (const p of Object.values(w.players)) if (p.fat > 60 && p.inj <= 0) p.rest = 'rest'; YA.saveWorld(); rerender(); } }, '疲れた子を休ます'),
      h('button', { class: 'btn sm', onclick: () => { for (const p of Object.values(w.players)) p.rest = null; YA.saveWorld(); rerender(); } }, '休み解除'),
      h('span', { style: 'width:8px;flex:none' }),
      h('b', { style: 'font-size:11px' }, '対象'),
      ...[['all', '全員'], ['A', 'A'], ['B', 'B'], ['1', '高1'], ['2', '高2'], ['3', '高3'], ['GK', 'GK'], ['DF', 'DF'], ['MF', 'MF'], ['FW', 'FW']].map(([k, n]) => h('button', { class: 'btn sm' + (ui.tf === k ? ' on' : ''), onclick: () => { ui.tf = k; rerender(); } }, n)),
      h('span', { class: 'sub' }, `${targets.length}人`))));
    col.append(flat(h('div', { class: 'card', style: strip + ';padding:3px 6px', title: '方針を決めた子は、伸びに合わせて重点が毎週選び直されます' },
      h('b', { style: 'font-size:11px' }, 'まとめて：重点'),
      ...Object.entries(YA.FOCUS_POLICY).map(([k, n]) => h('button', { class: 'btn sm' + (targets.length && targets.every((p) => p.train.policy === k) ? ' on' : ''), onclick: () => { for (const p of targets) YA.setPolicy(p, k); YA.saveWorld(); rerender(); } }, n)),
      h('span', { class: 'sub', style: 'margin-left:6px' }, '今週'),
      ...[[null, '通常'], ['light', '軽め'], ['rest', '休み']].map(([k, n]) => h('button', { class: 'btn sm', onclick: () => { for (const p of targets) if (p.inj <= 0) p.rest = k; YA.saveWorld(); rerender(); } }, n)))));
    const rows = targets.sort((a, b) => (a.team === b.team ? 0 : a.team === 'A' ? -1 : 1) || YA.POS15.indexOf(a.main) - YA.POS15.indexOf(b.main) || b.grade - a.grade);
    const table = h('div', { class: 'card pbody scroll', style: 'flex:1;min-height:0;padding:4px 6px' });
    table.append(h('div', { class: 'pitem', style: 'background:none;font-size:11px;color:var(--sub);font-weight:800' }, h('span', { style: 'width:22px' }), h('span', { style: 'width:20px' }), h('span', { class: 'grow' }, '選手'), h('span', { style: 'width:42px' }, '疲れ'), h('span', { style: 'width:116px' }, '重点にする能力'), h('span', { style: 'width:150px' }, '特性練習'), h('span', { style: 'width:52px' }, '今週')));
    for (const p of rows) {
      const tp = p.train.trait;
      const lt = tp ? YA.learnable(p).find((x) => x.t === tp) : null;
      const wk = tp ? Math.max(1, Math.ceil((100 - (p.tprog[tp] || 0)) / (lt ? 100 / lt.weeks : 1))) : 0;
      table.append(h('div', { class: 'pitem trainrow', style: 'cursor:default' },
        posc(p),
        YA.faceEl(W(), p, 22),
        h('span', { class: 'num' }, p.num),
        h('span', { class: 'nm grow', style: 'min-width:0;overflow:hidden;text-overflow:ellipsis' }, p.name, ' ', h('span', { class: 'sub', style: 'font-weight:600' }, gradeName(p.grade) + (p.team === 'A' ? ' A' : ' B')), ' ', flags(p)),
        fatBar(p, 42),
        h('button', { class: 'btn sm', style: 'width:116px;justify-content:space-between;gap:2px', onclick: () => pickFocus(p) }, p.train.policy && p.train.policy !== 'manual' ? h('span', { class: 'chip gray', style: 'font-size:10.5px;padding:0 3px' }, { strong: '得', weak: '苦', pos: '位' }[p.train.policy]) : null, h('span', { class: 'grow', style: 'text-align:left;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;min-width:0' }, p.train.focus || '未設定'), p.train.focus ? h('span', { class: 'sub' }, p.ab[p.train.focus]) : null),
        h('button', { class: 'btn sm', style: 'width:150px;justify-content:space-between;white-space:nowrap;gap:2px', onclick: () => pickTrait(p) }, h('span', { style: 'overflow:hidden;text-overflow:ellipsis' }, tp || '未設定'), tp ? h('span', { class: 'sub' }, wk + '週') : null),
        h('button', { class: 'btn sm' + (p.rest ? ' on' : ''), style: 'width:52px', disabled: p.inj > 0, why: '怪我をしている子は、休ませ方を変えられません', onclick: () => { p.rest = p.rest === null ? 'light' : p.rest === 'light' ? 'rest' : null; YA.saveWorld(); const st = table.scrollTop; rerender(); const t2 = document.querySelector('.card.pbody.scroll'); if (t2) t2.scrollTop = st; } }, p.inj > 0 ? '療養' : p.rest === 'rest' ? '休み' : p.rest === 'light' ? '軽め' : '通常')));
    }
    col.append(table);
    body.append(col);
  }
  // コーチ：練習に関わるスタッフ（技術・戦術・体・GK コーチ、トレーナー）
  function trainCoach(w, body) {
    const box = h('div', { class: 'card pbody', style: 'flex:1;min-width:0' });
    box.append(h('div', { class: 'row', style: 'gap:6px' }, h('div', { class: 'h' }, '練習のコーチ'), h('span', { class: 'sub', style: 'font-size:11px' }, '腕前が高いほど、その分野が伸びやすい。入れ替えはクラブ → 人 → スタッフ')));
    const roles = ['技術コーチ', '戦術コーチ', '体コーチ', 'GKコーチ', 'トレーナー'];
    for (const role of roles) {
      const s = (w.club.staff || []).find((x) => x.role === role);
      box.append(h('div', { class: 'pitem', style: 'cursor:default;align-items:flex-start;gap:8px' },
        h('b', { style: 'width:84px;flex:none' }, role),
        s ? h('span', { class: 'grow', style: 'min-width:0' }, h('b', {}, s.name), h('span', { class: 'sub', style: 'margin-left:6px' }, YA.staffLine ? YA.staffLine(s) : ''), h('div', { class: 'note' }, (YA.STAFF_NOTE && YA.STAFF_NOTE[role]) || '')) : h('span', { class: 'grow sub' }, 'いません（伸びが少し鈍ります）'),
        s ? h('span', { style: 'flex:none;text-align:right' }, h('div', { class: 'sub', style: 'font-size:11px' }, '腕前'), h('b', { style: 'font-size:15px' }, s.ab)) : null));
    }
    body.append(box);
  }
  // 「先週と同じ」：まだ先週が無ければ押せず、理由を出す（2026-11-17 点検：最初の週に押しても何も起きなかった）
  function sameAsLast(w) {
    return h('button', { class: 'btn sm', disabled: !w.lastPlan, why: 'まだ先週の練習がありません（1週進めると使えます）', onclick: () => { w.plan = JSON.parse(JSON.stringify(w.lastPlan)); YA.saveWorld(); rerender(); if (YA.toast) YA.toast('先週と同じ練習にしました'); } }, '先週と同じ');
  }
  function pickMenu(i) {
    const w = W();
    modal((close) => h('div', { class: 'sheet-in', style: 'flex:none;align-self:center;margin:auto;width:min(680px,97%);padding:10px;gap:7px' },
      h('div', { class: 'h' }, DAYS[i] + '曜日のメニュー'),
      h('div', { style: 'display:grid;grid-template-columns:repeat(4,1fr);gap:5px' }, YA.MENU_NAMES.map((n) => h('button', { class: 'btn' + (w.plan.days[i].menu === n ? ' on' : ''), style: 'flex-direction:column;align-items:flex-start;padding:6px 8px;text-align:left', onclick: () => { w.plan.days[i].menu = n; YA.saveWorld(); close(); rerender(); } }, h('b', {}, n), h('span', { style: 'font-weight:600;font-size:11px;opacity:.8' }, YA.MENUS[n].note)))),
      h('div', { class: 'row' }, h('span', { class: 'sub' }, '強さ'), ...['light', 'normal', 'hard'].map((k) => h('button', { class: 'btn sm' + (w.plan.days[i].int === k ? ' on' : ''), onclick: () => { w.plan.days[i].int = k; YA.saveWorld(); close(); rerender(); } }, YA.INTENS_NAMES[k])), h('span', { class: 'grow' }), h('button', { class: 'btn sm', onclick: close }, '閉じる')),
      h('div', { class: 'note' }, 'きついほど伸びますが、疲れが溜まり怪我もしやすくなります。「回復」は疲れを抜く日です。GKはGKコーチが別メニューで見ます。')));
  }
  function pickFocus(p) {
    const list = p.pos === 'GK' ? YA.AB_GK.concat(YA.AB_MENTAL, YA.AB_PHYS) : YA.AB_FIELD;
    modal((close) => h('div', { class: 'sheet-in', style: 'flex:none;align-self:center;margin:auto;width:min(680px,97%);max-height:94%;padding:10px;gap:6px' },
      h('div', { class: 'row' }, h('div', { class: 'h grow' }, `${p.name} の重点（今の値）`), h('button', { class: 'btn sm', onclick: () => { p.train.focus = null; p.train.policy = 'manual'; YA.saveWorld(); close(); rerender(); } }, '外す'), h('button', { class: 'btn sm', onclick: close }, '閉じる')),
      h('div', { class: 'scroll', style: 'display:grid;grid-template-columns:repeat(5,1fr);gap:4px;overflow:auto' }, list.map((n) => h('button', { class: 'btn sm' + (p.train.focus === n ? ' on' : ''), style: 'justify-content:space-between', onclick: () => { p.train.focus = n; p.train.policy = 'manual'; YA.saveWorld(); close(); rerender(); } }, n, h('b', {}, p.ab[n])))),
      h('div', { class: 'row', style: 'gap:4px' }, h('span', { class: 'sub' }, '方針で決める：'), ...Object.entries(YA.FOCUS_POLICY).map(([k, n]) => h('button', { class: 'btn sm' + (p.train.policy === k ? ' on' : ''), onclick: () => { YA.setPolicy(p, k); YA.saveWorld(); close(); rerender(); } }, n))),
      h('div', { class: 'note' }, '重点にした能力は、ほかより多く伸びます。手で選ぶと、その能力のまま固定します（方針を選ぶと、伸びに合わせて毎週選び直します）。')));
  }
  function pickTrait(p) {
    const list = YA.learnable(p);
    modal((close) => h('div', { class: 'sheet-in', style: 'flex:none;align-self:center;margin:auto;width:min(680px,97%);max-height:94%;padding:10px;gap:6px' },
      h('div', { class: 'row' }, h('div', { class: 'h grow' }, `${p.name} の特性練習（習得の目安）`), h('button', { class: 'btn sm', onclick: () => { p.train.trait = null; YA.saveWorld(); close(); rerender(); } }, '外す'), h('button', { class: 'btn sm', onclick: close }, '閉じる')),
      h('div', { class: 'scroll', style: 'display:grid;grid-template-columns:repeat(4,1fr);gap:4px;overflow:auto' }, list.map((x) => h('button', { class: 'btn sm' + (p.train.trait === x.t ? ' on' : ''), style: 'flex-direction:column;align-items:flex-start;gap:0', onclick: () => { p.train.trait = x.t; YA.saveWorld(); close(); rerender(); } }, h('b', {}, x.t), h('span', { style: 'font-weight:600;font-size:11px;opacity:.85' }, x.weeks <= 40 ? `約${x.weeks}週` : '1年では届かない')))),
      h('div', { class: 'note' }, '覚えやすさは、その特性に効く能力2つで決まります。向いていない子は時間がかかります。')));
  }

  // ---------- 選手 ----------
  // 伸びしろの星：5つのうち黒がいくつか（黒＝確実にある分、灰＝あるかもしれない分、白抜き＝なさそう）
  YA.starsEl = (r) => h('span', { class: 'stars' }, ...[0, 1, 2, 3, 4].map((i) => h('span', { class: i < r[0] ? 'on' : i < r[1] ? 'mid' : 'off' }, i < r[1] ? '★' : '☆')));
  // ---------- 選手 ----------
  // 2026-11-25 画面の構成の作り直し（ユーザー決定・FM 寄り）：一覧を全面に出し、押すと詳しい画面を全面で開く。
  //   一覧の列：印・位置・名前・学年とチーム・総合・伸び（見抜く目なら将来）・調子・疲れ・今季（A の出場・得点・平均採点）・今週の伸び
  //   詳しい画面：上の帯（顔・名前・位置・学年とチーム・総合と伸び・性格・利き足・身長・★・Bに回す・…・前後・一覧へ）と、
  //   小タブ プロフィール（能力の数字の表・ポジションの図・情報・特性・直近の採点・状態）／育成／コーチの報告／成績／経歴
  const SORTV = { pos: null, ovr: (p) => YA.ovr(p), grow: (p) => Object.values(p.gain || {}).reduce((a, b) => a + b, 0), trust: (p) => (p.tr == null ? 50 : p.tr), fat: (p) => p.fat || 0, mins: (p) => p.minsA || 0, conf: (p) => p.conf || 0, form: (p) => p.form || 0, wk: (p) => weekGain(W(), p) };
  // 今週の伸び（ホームから移した 2026-11-25）：課題中の子は伸びた能力の数、ほかは矢印の数
  function weekGain(w, p) {
    const G = w.growth && w.growth.y === w.year && w.week - w.growth.w <= 1 ? w.growth : null;
    if (!G) return 0;
    const s = (G.star || []).find((x) => x.id === p.id);
    if (s) return s.items.length;
    const o = (G.others || []).find((x) => x.id === p.id);
    return o ? o.n : 0;
  }
  // 今季の A の数字（出場・得点・平均採点）。記録 p.comp から
  function seasonA(w, p) {
    let gp = 0, g = 0, rs = 0, rn = 0;
    for (const c of Object.values(p.comp || {})) {
      if (!c || c.y !== w.year || c.c === 'Bチーム') continue;
      gp += c.n || 0;
      g += c.gl || 0;
      rs += c.rs || 0;
      rn += c.n || 0;
    }
    if (!gp) {
      const rl = (p.rl || []).filter((x) => x.y === w.year && x.t === 'A');
      gp = rl.length;
      g = rl.reduce((a, x) => a + (x.g || 0), 0);
      rs = rl.reduce((a, x) => a + x.r, 0);
      rn = rl.length;
    }
    return { gp, g, avg: rn ? rs / rn : null };
  }
  const formArrow = (p) => { const f = p.form || 0; return f >= 1 ? h('b', { style: 'color:#1a8a4a' }, '↑') : f <= -1 ? h('b', { style: 'color:#c8402f' }, '↓') : h('span', { class: 'sub' }, '→'); };
  function playerRows(w, ui) {
    const all = Object.values(w.players);
    const f2 = (p, k) => k === 'all' || k === p.team || k === String(p.grade) || k === p.pos || (k === 'star' && !!p.kd) || (k === 'inj' && p.inj > 0);
    const sv = SORTV[ui.psort];
    return all.filter((p) => f2(p, ui.pf)).sort((a, b) => (sv ? (ui.pdesc === false ? -1 : 1) * (sv(b) - sv(a)) : 0) || YA.POS15.indexOf(a.main) - YA.POS15.indexOf(b.main) || b.grade - a.grade || YA.ovr(b) - YA.ovr(a));
  }
  function viewPlayers(main) {
    const w = W();
    const ui = U().app;
    ui.pf = ui.pf || 'all';
    ui.psort = ui.psort || 'pos';
    // ほかの画面から選手を指して来たとき（pSel が変わったとき）は詳しい画面を開く。左の帯の「選手」を押したときは一覧
    if (ui.pSel && ui.pSel !== ui._pSeen && w.players[ui.pSel]) ui.pOpen = true;
    ui._pSeen = ui.pSel;
    if (ui.pOpen && ui.pSel && w.players[ui.pSel]) return playerDetail(main, w, ui);
    ui.pOpen = false;
    const all = Object.values(w.players);
    const filtered = playerRows(w, ui);
    const f2 = (p, k) => k === 'all' || k === p.team || k === String(p.grade) || k === p.pos || (k === 'star' && !!p.kd) || (k === 'inj' && p.inj > 0);
    const FILT = [['all', '全員'], ['A', 'Aチーム'], ['B', 'Bチーム'], ['1', '高1'], ['2', '高2'], ['3', '高3'], ['GK', 'GK'], ['DF', 'DF'], ['MF', 'MF'], ['FW', 'FW'], ['star', '課題中'], ['inj', '怪我']];
    const selStyle = 'padding:3px 4px;min-height:34px;border:1px solid #b9c7de;border-radius:8px;font:inherit;font-size:12px;min-width:0';
    const chips = h('select', { title: '絞り込み', style: selStyle }, ...FILT.map(([k, n]) => h('option', { value: k, selected: ui.pf === k }, (k === 'all' ? '絞り：' : '') + n + (k === 'all' ? '' : `（${all.filter((p) => f2(p, k)).length}）`))));
    chips.addEventListener('change', () => { ui.pf = chips.value; rerender(); });
    chips.addEventListener('pointerdown', (e) => e.stopPropagation());
    const sorts = h('select', { title: '並び替え', style: selStyle }, ...[['pos', '並び：位置'], ['ovr', '並び：総合力'], ['grow', '並び：伸び'], ['trust', '並び：信頼'], ['conf', '並び：自信'], ['fat', '並び：疲れ'], ['mins', '並び：出場']].map(([k, n]) => h('option', { value: k, selected: ui.psort === k }, n)));
    sorts.addEventListener('change', () => { ui.psort = sorts.value; ui.pdesc = true; rerender(); });
    sorts.addEventListener('pointerdown', (e) => e.stopPropagation());
    const eye = YA.ent && YA.ent.eye && YA.futurePoint;
    // 列（見出しを押すと並べ替え。同じ見出しをもう一度押すと逆順）
    const COLS = [
      ['印', 52, null], ['位置', 40, 'pos'], ['名前', 0, null], ['学年', 44, null], ['総合', 38, 'ovr'], [eye ? '将来' : '伸び', 44, 'grow'],
      ['調子', 34, 'form'], ['疲れ', 46, 'fat'], ['今季', 92, 'mins'], ['今週', 40, 'wk'],
    ];
    const cell = (wd, kid, st) => h('span', { style: (wd ? `flex:none;width:${wd}px;` : 'flex:1;min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;') + 'text-align:' + (wd ? 'center' : 'left') + ';font-size:12px;' + (st || '') }, kid);
    const lhead = h('div', { class: 'row plhead', style: 'gap:4px;padding:2px 8px;font-size:10.5px;color:#7a8aa6;font-weight:800;border-bottom:1px solid var(--line)' },
      COLS.map(([n, wd, k]) => k ? h('button', { class: 'phbtn' + (ui.psort === k ? ' on' : ''), style: (wd ? `flex:none;width:${wd}px;` : 'flex:1;') + 'border:none;background:none;font:inherit;color:' + (ui.psort === k ? 'var(--navy)' : 'inherit') + ';padding:0;min-height:26px;cursor:pointer', onclick: () => { if (ui.psort === k) ui.pdesc = ui.pdesc === false; else { ui.psort = k; ui.pdesc = true; } rerender(); } }, n + (ui.psort === k && k !== 'pos' ? (ui.pdesc === false ? '▲' : '▼') : '')) : h('span', { style: wd ? `flex:none;width:${wd}px;text-align:center` : 'flex:1' }, n)));
    const marks = (p) => h('span', { style: 'display:inline-flex;gap:1px' }, p.kd && YA.kadaiDef ? h('span', { class: 'chip trait kchip', style: 'font-size:10.5px;padding:0 4px;line-height:16px' }, YA.kadaiDef(p.kd.t).short) : null, w.captain === p.id ? h('b', { style: 'color:var(--navy)', title: '' }, 'C') : null, p.inj > 0 ? h('span', { class: 'fit bad', style: 'padding:0 2px' }, '怪') : null, p.unrest >= 3 ? h('span', { class: 'fit bad', style: 'padding:0 2px' }, '不') : null);
    const list = h('div', { class: 'plist scroll ptable', style: 'flex:1;min-height:0' }, filtered.map((p) => {
      const sa = seasonA(w, p);
      const wg = weekGain(w, p);
      return h('button', { class: 'pitem prow', onclick: () => { ui.pSel = p.id; ui._pSeen = p.id; ui.pOpen = true; ui.pTab = ui.pTab || 'prof'; ui._plistTop = list.scrollTop; rerender(); } },
        cell(52, marks(p)), cell(40, posc(p)),
        cell(0, h('span', {}, h('span', { class: 'num', style: 'margin-right:4px' }, p.num), h('span', { class: 'nm' }, p.name))),
        cell(44, gradeName(p.grade) + p.team, 'color:#5a6a84'),
        cell(38, h('b', {}, YA.rating(p))),
        cell(44, eye ? '→' + YA.futurePoint(p) : '伸' + YA.coachStars(w, p), 'color:#7a8aa6;font-weight:800'),
        cell(34, formArrow(p)),
        cell(46, fatBar(p, 40)),
        cell(92, sa.gp ? `${sa.gp}試合 ${sa.g}点${sa.avg != null ? ' ' + sa.avg.toFixed(1) : ''}` : '—', 'color:#5a6a84;font-size:11px'),
        cell(40, wg ? h('b', { style: 'color:#1e6b37' }, '+' + wg) : h('span', { class: 'sub' }, '—')));
    }));
    const head = h('div', { class: 'row', style: 'gap:6px;flex-wrap:wrap' }, h('div', { class: 'h', style: 'margin-right:4px' }, `選手（${filtered.length}人）`), sorts, chips, h('span', { class: 'sub', style: 'font-size:11px' }, '見出しを押すと並べ替え。選手を押すと詳しい画面'));
    const card = h('div', { class: 'card pbody', style: 'flex:1;min-height:0;display:flex;flex-direction:column;padding:6px 8px;gap:4px' }, head, lhead, list);
    main.append(h('div', { style: 'flex:1;min-height:0;display:flex' }, card));
    if (ui._plistTop) list.scrollTop = ui._plistTop;
  }
  // 能力の数字の表（FM のプロフィール：技術・頭・体の3列。GK は GK の能力）
  function abTable(p) {
    const isGK = p.pos === 'GK';
    const groups = isGK ? [['GK', YA.AB_GK], ['頭', YA.AB_MENTAL], ['体', YA.AB_PHYS]] : [['技術', YA.AB_TECH], ['頭', YA.AB_MENTAL], ['体', YA.AB_PHYS]];
    const col = (v) => (v >= 16 ? '#1a8a4a' : v >= 12 ? 'var(--navy)' : v >= 8 ? '#5a6a84' : '#c8402f');
    const up = (n) => (YA.growthOf(p).month[n]) || (p.gain && p.gain[n]) || 0;
    return h('div', { class: 'abtable', style: 'display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:2px 10px' }, groups.map(([gn, ns]) => h('div', { class: 'abcol', style: 'min-width:0' },
      h('div', { style: 'font-size:11px;font-weight:900;color:var(--navy);border-bottom:1px solid var(--line);margin-bottom:2px' }, gn),
      (ns || []).filter((n) => p.ab[n] != null).map((n) => h('div', { class: 'abrow', style: 'display:flex;justify-content:space-between;gap:3px;font-size:11px;line-height:1.6' }, h('span', { style: 'min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap' }, n), h('b', { style: 'flex:none;color:' + col(p.ab[n]) }, String(Math.round(p.ab[n])), up(n) > 0 ? h('small', { style: 'color:#1e6b37;margin-left:1px' }, '▲') : null))))));
  }
  function profileEl(w, p) {
    const box = h('div', { class: 'pprof', style: 'display:grid;grid-template-columns:minmax(0,1.7fr) minmax(0,0.85fr) minmax(0,1fr);gap:10px;align-items:start' });
    const sec = (t, ...kids) => h('div', { class: 'psec' }, h('div', { style: 'font-size:11px;font-weight:900;color:#7a8aa6;margin-bottom:2px' }, t), ...kids);
    // 左：能力の表
    box.append(sec('能力', abTable(p)));
    // 真ん中：ポジションの図と得意な役割
    const mid = h('div', {});
    if (YA.posMapEl) { try { mid.append(sec('ポジション', YA.posMapEl(p))); } catch (e) { /* 図が作れない子 */ } }
    if (p.favRole) mid.append(h('div', { class: 'note', style: 'color:var(--ink)' }, '得意な役割：' + p.favRole));
    mid.append(h('div', { class: 'note', style: 'color:var(--ink)' }, '利き足：' + (p.foot === 'L' ? '左' : p.foot === 'B' ? '両足' : '右')));
    box.append(mid);
    // 右：情報・特性・直近の採点・状態
    const right = h('div', { style: 'display:flex;flex-direction:column;gap:6px' });
    const info = [];
    if (p.bday && YA.ageOf) info.push(`${YA.ageOf(w, p)}歳（${p.bday.m}月${p.bday.d}日生まれ）`);
    if (p.born) info.push(`出身：${p.born}` + (p.dorm !== false ? '・寮生' : '・自宅から'));
    if (p.height) info.push(`${p.height}cm` + (YA.weightOf ? ` / ${YA.weightOf(p)}kg` : ''));
    right.append(sec('情報', h('div', { class: 'note', style: 'color:var(--ink);line-height:1.55' }, info.map((t) => h('div', {}, t)))));
    const tr = (p.traits || []).map((x) => (YA.isGold && YA.isGold(p, x) ? h('span', { class: 'chip gold', tip: '金の特性（もとは「' + x + '」・効き' + YA.GOLD_MULT + '倍）' }, '金 ' + ((YA.GOLD && YA.GOLD[x]) || x)) : h('span', { class: 'chip trait', tip: YA.GOLD && YA.GOLD[x] ? `${x}：使い込むと金の特性「${YA.GOLD[x]}」になれる` : '' }, x)));
    const hb = (p.habits || []).map((x) => h('span', { class: 'chip', style: 'background:#fdecea;color:#a83224' }, '癖 ' + x));
    right.append(sec('特性', tr.length || hb.length ? h('div', { class: 'row', style: 'flex-wrap:wrap;gap:3px' }, ...tr, ...hb) : h('div', { class: 'note' }, 'まだありません'), U().goldHint ? U().goldHint(p) : null));
    const rl = (p.rl || []).slice(-5);
    right.append(sec('直近の試合', rl.length ? h('div', { class: 'row', style: 'gap:3px;flex-wrap:wrap' }, rl.map((x) => h('span', { class: 'chip', style: 'font-weight:800;' + (x.r >= 7 ? 'background:#e6f5ec;color:#1a8a4a' : x.r < 6 ? 'background:#fdecea;color:#a83224' : 'background:#eef2f8;color:var(--navy)') }, x.r.toFixed(1) + (x.t === 'B' ? 'B' : '')))) : h('div', { class: 'note' }, 'まだ出ていません')));
    const st = [];
    if (p.inj > 0) st.push(h('span', { class: 'fit bad' }, `怪我 あと${p.inj}週`));
    st.push(h('span', { class: 'chip gray' }, `疲れ ${Math.round(p.fat || 0)}`), h('span', { class: 'chip gray' }, `自信 ${Math.round(p.conf || 0)}`));
    if (p.mind && p.mind.k && YA.MIND && YA.MIND[p.mind.k]) st.push(h('span', { class: 'fit bad' }, YA.MIND[p.mind.k].name));
    right.append(sec('状態', h('div', { class: 'row', style: 'flex-wrap:wrap;gap:3px' }, ...st)));
    box.append(right);
    return box;
  }
  function playerDetail(main, w, ui) {
    const sel = w.players[ui.pSel];
    const rows = playerRows(w, ui);
    const ix = rows.findIndex((p) => p.id === sel.id);
    const go = (d) => { const n = rows[(ix + d + rows.length) % rows.length]; if (n) { ui.pSel = n.id; ui._pSeen = n.id; rerender(); const d2 = document.querySelector('#main .pdetail'); if (d2) d2.scrollTop = 0; } };
    const persTop = Object.values(YA.persVisible ? YA.persVisible(sel) : sel.pers || {}).filter((t) => t && t !== 'ふつう').slice(0, 2);
    const head = h('div', { class: 'row phead', style: 'flex-wrap:wrap;gap:5px;padding:2px 2px 0' },
      h('button', { class: 'btn sm', onclick: () => { ui.pOpen = false; rerender(); } }, '‹ 一覧'),
      YA.faceEl(W(), sel, 40),
      posc(sel), h('b', { class: 'pname', style: 'font-size:15px;color:var(--navy);white-space:nowrap' }, `${sel.num} ${sel.name}`),
      h('span', { class: 'chip gray' }, `${gradeName(sel.grade)} / ${sel.team}チーム`),
      h('span', { class: 'chip', style: 'background:var(--navy);color:#fff;font-weight:800' }, '総合 ' + YA.rating(sel)),
      (YA.ent && YA.ent.eye && YA.futurePoint) ? h('span', { class: 'chip trait', tip: '見抜く目：' + YA.futureRange(w, sel).text }, '将来 ' + YA.futurePoint(sel)) : h('span', { class: 'chip trait', tip: '伸びしろ：' + YA.futureRange(w, sel).text }, '伸びしろ ', YA.starsEl([YA.coachStars(w, sel), YA.coachStars(w, sel)])),
      persTop.length ? h('span', { class: 'chip pers' }, persTop.join('・')) : null,
      h('span', { class: 'sub', style: 'font-size:11px' }, `${sel.foot === 'L' ? '左足' : sel.foot === 'B' ? '両足' : '右足'}・${sel.height}cm`),
      ...flags(sel).filter(Boolean),
      h('button', { class: 'btn sm', onclick: () => swapTeam(sel) }, sel.team === 'A' ? 'Bに回す' : 'Aに上げる'),
      h('button', { class: 'btn sm', 'aria-label': 'ほかの操作', style: 'min-width:38px;padding:4px 8px', onclick: () => playerMenu(w, sel) }, '…'),
      h('span', { class: 'grow' }),
      h('button', { class: 'btn sm', 'aria-label': '前の選手', onclick: () => go(-1) }, '◀'),
      h('span', { class: 'sub', style: 'font-size:11px' }, `${ix + 1}/${rows.length}`),
      h('button', { class: 'btn sm', 'aria-label': '次の選手', onclick: () => go(1) }, '▶'));
    const right = h('div', { class: 'card pbody pdetail', style: 'flex:1;min-width:0' });
    const starMsg0 = ui.starMsg;
    ui.starMsg = null;
    // 育成：育て方（計画・診断・師匠・転向）・面談・進路・課題中の子と過ごす
    const growT = h('div', {});
    const ex = YA.playerExtras(w, sel);
    for (const c of [...ex.querySelectorAll('[data-grp="grow"]')]) growT.append(c);
    const talk = h('div', { style: 'margin-top:4px' });
    {
      const o = YA.ovr(sel);
      const wish = o >= 12 ? 'プロを目指したい' : o >= 10.5 ? '大学でサッカーを続けたい' : 'サッカーは続けたいが、進路に迷っている';
      const rk = YA.topRankFor ? YA.topRankFor(w, sel) : null;
      const cut = YA.topCutLine ? YA.topCutLine(w) : 999;
      const near = YA.rating(sel) >= cut ? 'トップの登録に入れる力があります' : `登録の目安まであと総合力${Math.max(1, Math.round(cut - YA.rating(sel)))}`;
      const path = { abroad: '海外へ挑戦', pro: '他のプロへ', univ: '大学へ', corp: '社会人として続ける', quit: 'サッカーはやめる' }[sel._p2];
      talk.append(h('div', { class: 'card', style: 'padding:6px 9px;margin:4px 0;background:#f5f8fd' },
        h('div', { class: 'h' }, '進路'),
        h('div', { class: 'note', style: 'color:var(--ink)' }, `本人の希望：${wish}`),
        h('div', { class: 'note', style: 'color:var(--ink)' }, `トップへの近さ：${near}${rk ? `（同じポジションで${rk.n}番目くらい／${rk.of}人中）` : ''}`),
        path ? h('div', { class: 'note', style: 'color:var(--ink)' }, `進路面談で選んだ道：${path}`) : null));
    }
    talk.append(h('div', { class: 'h', style: 'border-top:1px dashed var(--line);padding-top:6px' }, '面談（1人とは月1回まで）'));
    const res = h('div', { class: 'msglog' });
    const can = YA.canTalk(w, sel);
    const su = YA.talkSetup(w, sel);
    const talkBtns = () => { for (const b of talk.querySelectorAll('button')) b.disabled = true; };
    talk.append(h('div', { class: 'card', style: 'padding:6px 9px;margin:4px 0;background:#f5f8fd' }, h('b', {}, sel.name.split(' ')[0] + '：'), `「${su.line}」`));
    talk.append(h('div', { class: 'fm-row', style: 'margin-top:4px' }, su.opts.map((t) => h('button', { class: 'btn', disabled: !can, why: '面談は1人と月1回までです。来月また話せます', onclick: () => { const r = YA.talk(w, sel.id, t.k); res.replaceChildren(h('div', {}, r.ok ? `${sel.name.split(' ')[0]}は、${r.line}${r.small ? '（' + r.small + '）' : ''}${r.extra ? ' / ' + r.extra : ''}` : r.msg)); YA.saveWorld(); talkBtns(); } }, t.label))));
    talk.append(res);
    if (YA.starActsEl) { const sa = YA.starActsEl(w, sel, rerender); if (sa) talk.append(sa); }
    growT.append(talk);
    // コーチの報告：見立て（概要）・伸びのグラフ・調子と性格・事情・キャプテンとポジション（様子）
    const rep = h('div', {});
    const ov = YA.playerOverview ? YA.playerOverview(w, sel) : h('div', {});
    // 手がかり欄と「課題を出す」（2026-11-26 課題の仕組み：コーチの報告の一番上）
    if (starMsg0) rep.append(h('div', { class: 'note', style: 'color:var(--ink)' }, starMsg0));
    if (YA.kadaiBox) rep.append(YA.kadaiBox(w, sel, rerender));
    rep.append(ov, growthBox(sel));
    {
      const g = (v, lo, hi) => (v >= hi ? '良い' : v <= lo ? '低い' : 'ふつう');
      const unrest = sel.unrest > 3 ? '不満が溜まっている' : sel.unrest > 1.5 ? '少し気にしていることがある' : '不満はなさそう';
      const persAll = Object.values(YA.persVisible ? YA.persVisible(sel) : sel.pers || {}).filter(Boolean);
      const pers = persAll.filter((t) => t !== 'ふつう').slice(0, 8);
      const persNorm = persAll.length - pers.length;
      const tip = sel.inj > 0 ? '怪我の回復が先です。無理に出さないで、完治を待ちましょう。' : sel.fat >= 70 ? '疲れが溜まっています。今週は休ませるか、軽めにしたほうがよさそうです。' : sel.unrest > 3 ? 'ひとこと声をかけてあげてください（育成タブの面談）。' : sel.conf < 35 ? '自信を失っています。出番か、励ましの言葉が効きそうです。' : sel.conf >= 70 ? '乗っています。この流れを切らさずに使いたい子です。' : '目立った心配はありません。';
      rep.append(h('div', { class: 'card', style: 'padding:6px 9px;margin:4px 0;background:#f5f8fd' },
        h('div', { class: 'h' }, '調子'),
        h('div', { class: 'row', style: 'flex-wrap:wrap;gap:5px;margin:3px 0' }, h('span', { class: 'chip gray' }, `自信 ${Math.round(sel.conf)}（${g(sel.conf, 35, 70)}）`), h('span', { class: 'chip gray' }, `疲れ ${Math.round(sel.fat)}`), h('span', { class: 'chip gray' }, unrest), sel.inj > 0 ? h('span', { class: 'fit bad' }, `怪我 あと${sel.inj}週`) : null),
        h('div', { class: 'row', style: 'flex-wrap:wrap;gap:4px;margin:3px 0' }, h('span', { class: 'sub' }, '性格：'), ...pers.map((t) => h('span', { class: 'chip gray' }, t)), persNorm ? h('span', { class: 'sub', style: 'font-size:11px' }, pers.length ? 'ほかはふつう' : 'どれもふつう') : null),
        h('div', { class: 'note', style: 'color:var(--ink)' }, 'コーチの一言：' + tip)));
      rep.append(ex);
      if (YA.bgText) rep.append(h('div', { class: 'note', style: 'margin-top:6px;color:var(--ink)' }, '事情：' + YA.bgText(YA._ui.app.w, sel)));
    }
    // 成績：今季と通算・大会ごと・直近の採点
    const stats = h('div', {});
    {
      const sa = seasonA(w, sel);
      stats.append(h('div', { class: 'card', style: 'padding:6px 9px;margin:4px 0;background:#f5f8fd' }, h('div', { class: 'h' }, '今季の A'), h('div', { class: 'note', style: 'color:var(--ink)' }, sa.gp ? `${sa.gp}試合 ${sa.g}得点` + (sa.avg != null ? ` ／ 平均採点 ${sa.avg.toFixed(2)}` : '') : 'まだ A の公式戦に出ていません')));
      const ct = YA.compTableEl ? YA.compTableEl(sel) : null;
      if (ct) stats.append(h('div', { class: 'h', style: 'margin-top:6px' }, '大会ごと（通算）'), ct);
      const rl = (sel.rl || []).slice().reverse();
      stats.append(h('div', { class: 'h', style: 'margin-top:6px' }, '直近の試合'), rl.length ? h('div', { class: 'plist' }, rl.map((x) => h('div', { class: 'pitem', style: 'cursor:default' }, h('span', { class: 'sub', style: 'width:110px;flex:none' }, YA.ywName(x.y, x.w)), h('span', { class: 'chip gray', style: 'flex:none' }, x.t === 'B' ? 'B' : 'A'), h('span', { class: 'grow' }, (x.g ? x.g + '得点 ' : '') + (x.a ? x.a + 'アシスト' : '')), h('b', {}, x.r.toFixed(1))))) : h('div', { class: 'note' }, 'まだ試合に出ていません'));
    }
    // 経歴：入団の経路・名場面・思い出・最近のこと
    const mem = h('div', {});
    if (sel.route) mem.append(h('div', { class: 'note', style: 'color:var(--ink)' }, `入団：${sel.route}${sel.joinY ? `（${sel.joinY}年目）` : ''}`));
    if (YA.scenesEl) { const sc = YA.scenesEl(sel); if (sc) mem.append(h('div', { class: 'h', style: 'margin-top:6px' }, '名場面'), sc); }
    if (YA.pressEl) { const pe = YA.pressEl(w, sel); if (pe) mem.append(h('div', { class: 'h', style: 'margin-top:6px' }, `新聞の記事（${YA.PAPER_NAME}）`), pe); }
    if (!(sel.mem && sel.mem.length) && !sel.hist.length) mem.append(h('div', { class: 'note' }, 'まだ思い出はありません。出来事や試合で選んだことが、ここに残ります。'));
    if (sel.mem && sel.mem.length && YA.memLines) mem.append(h('div', { class: 'h', style: 'margin-top:8px' }, 'この子との記憶'), h('div', { class: 'note', style: 'color:var(--ink)' }, YA.memLines(sel).slice(0, 8).map((t) => h('div', {}, t))), YA.leanOf && YA.leanOf(sel).n ? h('div', { class: 'note' }, '育て方の傾き：' + Object.entries(YA.leanOf(sel).cnt).filter((x) => x[1]).sort((a, b) => b[1] - a[1]).map(([k, n]) => `${YA.KIND_LABEL[k]}${n}`).join('・') + '（覚醒の形の出やすさに効く）') : null);
    if (sel.hist.length) mem.append(h('div', { class: 'h', style: 'margin-top:8px' }, '最近のこと'), h('div', { class: 'note', style: 'color:var(--ink)' }, sel.hist.slice(0, 10).map((x) => h('div', {}, `${YA.ywName(x.y, x.w)}：${x.t}`))));
    const prof = h('div', {});
    if (starMsg0) prof.append(h('div', { class: 'note', style: 'color:var(--ink)' }, starMsg0));
    prof.append(profileEl(w, sel));
    // 2026-11-25 の小タブ。前の名前（ov/info/ops/grow/mem/talk）で来たときは近いものへ
    const OLD = { ov: 'rep', info: 'prof', ops: 'rep', grow: 'grow', mem: 'hist', talk: 'grow' };
    if (OLD[ui.pTab]) ui.pTab = OLD[ui.pTab];
    ui.pTab = ui.pTab || 'prof';
    const PT = [['prof', 'プロフィール'], ['grow', '育成'], ['rep', 'コーチの報告'], ['stats', '成績'], ['hist', '経歴']];
    const tabsEl = h('div', { class: 'tabs ptabs' });
    const show = () => {
      tabsEl.replaceChildren(...PT.map(([k, n]) => h('button', { class: 'btn sm' + (ui.pTab === k ? ' on' : ''), onclick: () => { ui.pTab = k; show(); } }, n)));
      right.replaceChildren({ prof, grow: growT, rep, stats, hist: mem }[ui.pTab] || prof);
      right.scrollTop = 0;
    };
    show();
    main.append(h('div', { style: 'flex:1;min-width:0;display:flex;flex-direction:column;gap:4px;min-height:0' }, head, tabsEl, right));
  }
  // 選手の「…」：比べる・PK戦のキッカー（名前は 2026-11-20 から変えられない。オリジナル選手は作るときに名付ける）
  function playerMenu(w, sel) {
    const pkIdx = (w.pkOrder || []).indexOf(sel.id);
    const pkN = (w.pkOrder || []).filter((id) => w.players[id]).length;
    modal((close) => h('div', { class: 'sheet-in', style: 'flex:none;align-self:center;margin:auto;width:min(420px,95%);padding:12px;gap:7px' },
      h('div', { class: 'row' }, h('div', { class: 'h grow' }, `${sel.num} ${sel.name}`), h('button', { class: 'btn sm', onclick: close }, '閉じる')),
      h('button', { class: 'btn', onclick: () => { close(); YA.compareModal(w, sel); } }, '他の子と比べる'),
      h('button', { class: 'btn' + (pkIdx >= 0 ? ' on' : ''), disabled: pkIdx < 0 && pkN >= 5, why: 'PK戦のキッカーは5人までです。先にだれかを外してください', onclick: () => { const r = YA.pkToggle(w, sel); U().app.starMsg = r.msg; YA.saveWorld(); close(); rerender(); } }, pkIdx >= 0 ? `PK戦のキッカー ${pkIdx + 1}番目（外す）` : `PK戦のキッカーに入れる（${pkN}/5）`)));
  }
  // 総合力の水準の表（200＝歴史上No.1）
  function levelTable(now) {
    modal((close) => h('div', { class: 'sheet-in', style: 'flex:none;align-self:center;margin:auto;width:min(460px,95%);max-height:94%;padding:10px 12px;gap:4px;overflow:auto' },
      h('div', { class: 'row' }, h('div', { class: 'h grow' }, '総合力の水準（0〜200）'), h('button', { class: 'btn sm', onclick: close }, '閉じる')),
      ...YA.LEVELS.map(([t, n], i) => h('div', { class: 'pitem', style: 'cursor:default;' + (YA.levelOf(now) === n ? 'background:#fff7d6;border-color:#f0cf55' : '') }, h('b', { style: 'width:44px;text-align:right' }, i === 0 ? '200' : t + '〜'), h('span', { class: 'grow' }, n))),
      h('div', { class: 'note' }, '総合力は、いまのポジションに要る能力から出します。200は歴史上No.1の選手で、まず届きません。')));
  }
  // 総合力の月ごとの推移（折れ線）と、今月・今年の伸びの要約
  function growthBox(p) {
    const G = YA.growthOf(p);
    const log = G.log.slice();
    const now = YA.rating(p);
    log.push([-1, now]);
    const sum = (o) => Object.values(o).reduce((a, b) => a + b, 0);
    const top = (o) => Object.entries(o).sort((a, b) => b[1] - a[1]).filter((x) => x[1] > 0).slice(0, 3).map(([a, v]) => `${a}+${v}`).join(' ');
    const box = h('div', { class: 'card', style: 'padding:6px 9px;margin:4px 0;background:#f5f8fd;display:flex;gap:10px;align-items:center' });
    const NS = 'http://www.w3.org/2000/svg';
    const W0 = 150;
    const H0 = 44;
    const vals = log.map((x, i) => (i === log.length - 1 ? x[1] : YA.rate(x[1])));
    const lo = Math.min(...vals) - 1.5;
    const hi = Math.max(...vals) + 1.5;
    const pts = vals.map((v, i) => `${(vals.length === 1 ? W0 : (i / (vals.length - 1)) * (W0 - 6)) + 3},${H0 - 4 - ((v - lo) / (hi - lo)) * (H0 - 8)}`);
    const svg = document.createElementNS(NS, 'svg');
    svg.setAttribute('viewBox', `0 0 ${W0} ${H0}`);
    svg.style.cssText = `width:${W0}px;height:${H0}px;flex:none`;
    const pl = document.createElementNS(NS, 'polyline');
    pl.setAttribute('points', pts.join(' '));
    pl.setAttribute('fill', 'none');
    pl.setAttribute('stroke', '#1f6feb');
    pl.setAttribute('stroke-width', '2');
    svg.append(pl);
    const last = pts[pts.length - 1].split(',');
    const dot = document.createElementNS(NS, 'circle');
    dot.setAttribute('cx', last[0]); dot.setAttribute('cy', last[1]); dot.setAttribute('r', '3'); dot.setAttribute('fill', '#1f6feb');
    svg.append(dot);
    const d0 = now - vals[0];
    if (vals.length > 1) box.append(svg);
    box.append(h('div', { style: 'font-size:11px;line-height:1.5' },
      h('div', {}, h('b', {}, `総合力 ${now}`), h('span', { class: 'note' }, `／200　${YA.levelOf(now)} `), h('button', { class: 'btn sm', style: 'min-height:32px;padding:0 10px;font-size:11px', onclick: () => levelTable(now) }, '水準の表'), h('span', { class: 'note' }, '' + (vals.length > 1 ? `（${d0 >= 0 ? '+' : ''}${d0}／記録の最初から）` : ''))),
      h('div', {}, '今月 ', h('b', { style: 'color:#1a9d57' }, sum(G.month) ? '+' + sum(G.month) : '伸びなし'), ' ', h('span', { class: 'note' }, top(G.month))),
      h('div', {}, '今年 ', h('b', {}, sum(G.year) ? '+' + sum(G.year) : '伸びなし'), ' ', h('span', { class: 'note' }, top(G.year))),
      (() => { const tb = YA.tacticTrainBonus(W(), p); const parts = []; if (tb.tactic) parts.push(`戦術「${tb.tactic}」：${tb.tabs.join('・')}`); if (tb.role) parts.push(`役割「${tb.role}」：${tb.rabs.slice(0, 4).join('・')}`); return parts.length ? h('div', { class: 'note', style: 'color:var(--ink)' }, '練習で伸びやすい ', parts.join(' ／ ')) : null; })(),
      h('div', { class: 'note', style: 'font-size:11px' }, '棒の薄い緑＝次の+1までの進み／右の緑＝今月・灰＝今年の伸び')));
    return box;
  }
  // Aの先発をBに下げる：その位置に入る子を、先に選んでもらう（Aのベンチ・Bから。位置の適性の順）
  function demoteStarter(p) {
    const w = W();
    const i = w.lineupA.findIndex((s) => s.pid === p.id);
    const sl = w.lineupA[i];
    const p15 = YA.pos15OfSlot(sl, i);
    const can = (q) => q.inj <= 0 && !(q.suspend > 0) && !(q.away > 0) && (q.pos === 'GK') === (p15 === 'GK');
    const cands = Object.values(w.players).filter((q) => q.id !== p.id && !w.lineupA.some((s) => s.pid === q.id) && can(q)).sort((a, b) => YA.slotValue(b, p15) - YA.slotValue(a, p15)).slice(0, 12);
    const pick = (q, close) => {
      sl.pid = q.id;
      YA.fixSlotRole(sl, i);
      const bi = w.benchA.indexOf(q.id);
      if (bi >= 0) {
        // Aのベンチから先発へ。空いたベンチには、Bのいちばん力のある控えを上げる
        const fill = Object.values(w.players).filter((x) => x.team === 'B' && x.id !== p.id && x.inj <= 0 && !w.lineupB.some((s) => s.pid === x.id)).sort((a, b) => YA.ovr(b) - YA.ovr(a))[0];
        if (fill) { w.benchA[bi] = fill.id; fill.team = 'A'; w.benchB = (w.benchB || []).filter((id) => id !== fill.id); } else w.benchA.splice(bi, 1);
        w.benchB = (w.benchB || []).concat([p.id]);
      } else {
        // Bから上げる。Bでその子がいた場所に、下げた子が入る
        q.team = 'A';
        const lb = w.lineupB.findIndex((s) => s.pid === q.id);
        if (lb >= 0) { w.lineupB[lb].pid = p.id; YA.fixSlotRole(w.lineupB[lb], lb); } else { const k = (w.benchB || []).indexOf(q.id); if (k >= 0) w.benchB[k] = p.id; else w.benchB = (w.benchB || []).concat([p.id]); }
      }
      p.team = 'B';
      YA.saveWorld();
      close();
      rerender();
    };
    modal((close) => h('div', { class: 'sheet-in', style: 'flex:none;align-self:center;margin:auto;width:min(560px,96%);max-height:94%;padding:10px 12px;gap:5px;overflow:auto' },
      h('div', { class: 'row' }, h('div', { class: 'h grow' }, `${p.name}をBに下げる：${YA.POS_LABEL[p15]}の先発に入る子を選ぶ`), h('button', { class: 'btn sm', onclick: close }, 'やめる')),
      h('div', { class: 'note' }, '適性の高い順に並べています。Aのベンチから選ぶと、空いたベンチにはBのいちばん力のある子が上がります。'),
      ...cands.map((q) => h('button', { class: 'pitem', onclick: () => pick(q, close) }, posc(q), YA.faceEl(w, q, 22), h('span', { class: 'nm grow', style: 'text-align:left' }, `${q.num} ${q.name}`), h('span', { class: 'sub' }, (w.benchA.indexOf(q.id) >= 0 ? 'Aのベンチ' : 'B') + '・' + gradeName(q.grade)), h('span', { class: 'chip ' + (q.apt[p15] >= 14 ? 'trait' : 'gray') }, YA.POS_LABEL[p15] + YA.aptLabel(q.apt[p15])), h('b', { style: 'width:30px;text-align:right' }, YA.rating(q)))),
      cands.length ? null : h('div', { class: 'note' }, '入れられる子がいません（怪我や出場停止）。')));
  }
  function swapTeam(p) {
    const w = W();
    const bi = w.lineupB.findIndex((s) => s.pid === p.id);
    if (bi >= 0 && p.team === 'B') {
      // Bの先発をAに上げるときは、先にBのベンチの同じ位置の選手を先発に回す
      const r = (w.benchB || []).map((id) => w.players[id]).filter((q) => q && q.inj <= 0).sort((a, b) => (b.pos === p.pos) - (a.pos === p.pos) || YA.ovr(b) - YA.ovr(a))[0];
      if (!r) { modal((close) => h('div', { class: 'sheet-in', style: 'flex:none;align-self:center;margin:auto;width:min(420px,95%);padding:12px;gap:8px' }, h('div', { class: 'h' }, 'Bの控えがいません'), h('button', { class: 'btn pri', onclick: close }, '閉じる'))); return; }
      YA.swapB(w, bi, r.id);
    }
    if (w.lineupA.some((s) => s.pid === p.id)) return demoteStarter(p);
    if (w.lineupB.some((s) => s.pid === p.id)) {
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
      h('div', { class: 'card pbody', style: 'flex:1' }, h('div', { class: 'h' }, 'Aチームの試合結果'), h('div', { class: 'plist', style: 'margin-top:5px' }, rows.map((r) => h('div', { class: 'pitem', style: 'cursor:default' }, h('span', { class: 'sub', style: 'width:104px;flex:none' }, YA.ywName(r.year, r.week)), h('span', { class: 'nm grow' }, r.opp), h('b', { style: `color:${r.gf > r.ga ? '#1a9d57' : r.gf < r.ga ? '#d63a3a' : 'inherit'}` }, `${r.gf} - ${r.ga}`)))), !rows.length ? h('div', { class: 'note' }, 'まだ試合がありません') : null),
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
      body.append(h('div', { class: 'plist', style: 'margin-top:5px' }, al.map((a) => h('div', { class: 'pitem', style: 'cursor:default' }, h('span', { class: 'pos ' + a.pos }, a.pos), h('span', { class: 'nm grow' }, a.name), h('span', { class: 'sub' }, `${a.year}年目`), h('span', { class: 'chip gray' }, '総合力 ' + YA.rate(a.ovr)), h('span', { class: 'sub', style: 'width:150px' }, a.note)))));
      if (!al.length) body.append(h('div', { class: 'note', style: 'margin-top:6px' }, '最初の卒業式（1年目の終わり）で、ここに並びます。'));
    } else {
      body.append(h('div', { class: 'h' }, '設定'));
      body.append(h('div', { class: 'row', style: 'margin:6px 0' }, h('span', { class: 'grow' }, '試合の自動停止（前半終了・得点・失点・残り15分）'), h('button', { class: 'btn sm' + (ui.autoStop ? ' on' : ''), onclick: () => { ui.autoStop = !ui.autoStop; U().store.set('autoStop', ui.autoStop); rerender(); } }, ui.autoStop ? 'ON' : 'OFF')));
      body.append(h('div', { class: 'h', style: 'margin-top:12px' }, '最初からやり直す'), h('div', { class: 'note' }, '36人も成績も消えて、新しい世界が始まります。'), h('button', { class: 'btn', style: 'margin-top:5px;color:#b02020', onclick: () => modal((close) => h('div', { class: 'sheet-in', style: 'flex:none;align-self:center;margin:auto;width:min(420px,95%);padding:12px;gap:8px' }, h('div', { class: 'h' }, '本当に最初からやり直しますか'), h('div', { class: 'row' }, h('button', { class: 'btn', onclick: close }, 'やめる'), h('button', { class: 'btn pri', onclick: () => { ui.w = YA.newWorld((Date.now() % 90000) + 7); ui.view = 'pre'; ui.pSel = null; ui.tab = 'home'; YA.saveWorld(); close(); rerender(); } }, 'やり直す')))) }, '最初からやり直す'));
    }
    main.append(h('div', { style: 'flex:1;min-height:0;display:flex;flex-direction:column;gap:6px' }, tabs, body));
  }

  YA._v = { modal, rerender, flags, pcls, gradeName };
  YA.views = { home: viewHome, train: viewTrain, players: viewPlayers, club: viewClub, more: viewMore };
})();
