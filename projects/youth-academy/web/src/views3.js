// 新しく始める画面（指導者の作成・クラブ選び）、おまかせ進行の操作と結果、設定（セーブ枠・書き出し・復元・効果音）。
(function () {
  'use strict';
  const YA = (globalThis.YA = globalThis.YA || {});
  const U = () => YA._ui;
  const V = () => YA._v;
  const h = (...a) => U().h(...a);
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const rerender = () => U().render();

  // ---------- 新しく始める：指導者を作る・最初のクラブを選ぶ ----------
  YA.views = YA.views || {};
  YA.views.newgame = function (main) {
    const app = U().app;
    app.ng = app.ng || { name: '', career: 'grind', club: 2, points: { teach: 0, eye: 0, talk: 0, tactic: 0 }, noFire: false };
    const f = app.ng;
    const used = () => Object.values(f.points).reduce((a, b) => a + b, 0);
    const career = YA.CAREERS.find((c) => c.k === f.career);
    const coachNow = (k) => 8 + (career.coach[k] || 0) + f.points[k];
    const left = h('div', { class: 'card pbody', style: 'flex:1.1;min-width:0' });
    const input = h('input', { type: 'text', maxlength: 12, placeholder: '名前（空なら「監督」）', value: f.name, style: 'width:100%;padding:7px 9px;border:1px solid #b9c7de;border-radius:8px;font:inherit;font-weight:700' });
    input.addEventListener('input', () => (f.name = input.value));
    input.addEventListener('pointerdown', (e) => e.stopPropagation());
    left.append(h('div', { class: 'h', style: 'font-size:15px' }, '指導者を作る'), h('div', { class: 'note', style: 'margin:6px 0 2px' }, '名前'), input);
    left.append(h('div', { class: 'note', style: 'margin:8px 0 3px' }, '経歴（最初の能力・資格・評判が変わります）'));
    for (const c of YA.CAREERS) left.append(h('button', { class: 'rolecard' + (f.career === c.k ? ' on' : ''), onclick: () => { f.career = c.k; rerender(); } }, h('div', { class: 'grow' }, h('b', {}, c.name), h('div', {}, h('span', { class: 'd' }, c.note)))));
    left.append(h('div', { class: 'note', style: 'margin:8px 0 3px' }, `自由に振り分ける点数：あと${YA.CAREER_POINTS - used()}`));
    left.append(h('div', { style: 'display:grid;grid-template-columns:1fr 1fr;gap:5px' }, YA.COACH_ABS.map(([k, n, note]) => h('div', { class: 'card', style: 'padding:5px 8px;display:flex;align-items:center;gap:6px' }, h('div', { class: 'grow' }, h('b', {}, n), h('div', { class: 'note' }, note)), h('button', { class: 'btn sm', disabled: f.points[k] <= 0, onclick: () => { f.points[k]--; rerender(); } }, '−'), h('b', { style: 'width:20px;text-align:center' }, coachNow(k)), h('button', { class: 'btn sm', disabled: used() >= YA.CAREER_POINTS, onclick: () => { f.points[k]++; rerender(); } }, '＋')))));
    const right = h('div', { class: 'card pbody', style: 'flex:1;min-width:0' });
    right.append(h('div', { class: 'h', style: 'font-size:15px' }, '最初のクラブを選ぶ'), h('div', { class: 'note', style: 'margin:3px 0 5px' }, '部が上のクラブほど予算が大きく、素質のある選手が集まりますが、評価の目も厳しくなります。'));
    YA.START_CLUBS.forEach((c, i) => right.append(h('button', { class: 'rolecard' + (f.club === i ? ' on' : ''), onclick: () => { f.club = i; rerender(); } }, h('div', { class: 'grow' }, h('b', {}, c.name), h('div', {}, h('span', { class: 'd' }, c.note))), h('span', { class: 'chip ' + (c.tier === 1 ? 'trait' : c.tier === 2 ? 'pers' : 'gray') }, YA.TIER_NAME[c.tier]))));
    right.append(h('div', { class: 'row', style: 'margin-top:8px' }, h('span', { class: 'grow' }, '解任'), h('button', { class: 'btn sm' + (f.noFire ? ' on' : ''), onclick: () => { f.noFire = !f.noFire; rerender(); } }, f.noFire ? '解任なし' : '解任あり')), h('div', { class: 'note' }, '「解任なし」でも、評価が悪いと予算と信頼度は下がります。'));
    main.append(h('div', { style: 'flex:1;min-height:0;display:flex;flex-direction:column;gap:6px' },
      h('div', { class: 'row', style: 'gap:8px' }, h('div', { class: 'h grow', style: 'font-size:17px' }, 'ユースの系譜　新しく始める'), h('button', { class: 'btn pri', style: 'min-width:150px;min-height:38px;font-size:14px', onclick: () => { const opts = YA.makeStart({ name: f.name, career: f.career, club: f.club, points: f.points, noFire: f.noFire }); app.w = YA.newWorld((Date.now() % 90000) + 7, opts); app.ng = null; app.tab = 'home'; app.view = 'pre'; YA.saveWorld(true); YA.sfx.play('whistle'); rerender(); } }, 'この指導者で始める')),
      h('div', { style: 'flex:1;min-height:0;display:flex;gap:8px' }, left, right)));
  };

  // ---------- おまかせ進行（1週・次の試合・1年）----------
  YA.simCard = function () {
    const app = U().app;
    const w = app.w;
    const stop = app.simStop !== false;
    const row = h('div', { class: 'card', style: 'padding:6px 8px;background:#f5f8fd' });
    const run = (until) => {
      const btns = row.querySelectorAll('button');
      btns.forEach((b) => (b.disabled = true));
      row.querySelector('.simmsg').textContent = '進めています…';
      setTimeout(() => {
        const rep = YA.simulate(w, { until, stopOnImportant: stop });
        YA.saveWorld(true);
        showSimReport(rep);
      }, 40);
    };
    row.append(h('div', { class: 'row', style: 'gap:4px;flex-wrap:wrap' }, h('b', { style: 'font-size:11px' }, 'おまかせ進行'), h('button', { class: 'btn sm', onclick: () => run('week') }, '1週'), h('button', { class: 'btn sm', onclick: () => run('match') }, '次の試合まで'), h('button', { class: 'btn sm', onclick: () => run('year') }, '1年'), h('span', { class: 'grow' }), h('button', { class: 'btn sm' + (stop ? ' on' : ''), onclick: () => { app.simStop = !stop; rerender(); } }, stop ? '大事な所で止まる' : '止まらない')), h('div', { class: 'simmsg note', style: 'margin-top:2px' }, '練習・起用・出来事は自動で選びます（テスト用）'));
    return row;
  };
  function showSimReport(rep) {
    V().modal((close) => {
      const bx = h('div', { class: 'sheet-in', style: 'flex:none;align-self:center;margin:auto;width:min(680px,97%);max-height:96%;padding:12px;gap:6px;overflow:auto' });
      bx.append(h('div', { class: 'h', style: 'font-size:15px' }, rep.title), h('div', { class: 'note' }, rep.span));
      for (const l of rep.lines) bx.append(h('div', { class: 'insight' + (l.k === 'stop' ? ' bad' : '') }, l.t));
      if (rep.big && rep.big.length) bx.append(h('div', { class: 'h', style: 'margin-top:4px' }, '主な出来事'), ...rep.big.map((t) => h('div', { class: 'note', style: 'color:var(--ink)' }, '・' + t)));
      bx.append(h('button', { class: 'btn pri', onclick: () => { close(); rerender(); } }, '閉じる'));
      return bx;
    });
  }

  // ---------- 設定：自動停止・効果音・セーブ枠・書き出し・復元 ----------
  YA.settingsBlock = function (body) {
    const app = U().app;
    const store = U().store;
    body.append(h('div', { class: 'h' }, '設定'));
    body.append(h('div', { class: 'row', style: 'margin:6px 0' }, h('span', { class: 'grow' }, '試合の自動停止（前半終了・得点・失点・残り15分）'), h('button', { class: 'btn sm' + (app.autoStop ? ' on' : ''), onclick: () => { app.autoStop = !app.autoStop; store.set('autoStop', app.autoStop); rerender(); } }, app.autoStop ? 'ON' : 'OFF')));
    body.append(h('div', { class: 'row', style: 'margin:6px 0' }, h('span', { class: 'grow' }, '効果音'), h('button', { class: 'btn sm' + (YA.sfx.on ? ' on' : ''), onclick: () => { YA.sfx.on = !YA.sfx.on; store.set('sfx', YA.sfx.on); YA.sfx.play('tap'); rerender(); } }, YA.sfx.on ? 'ON' : 'OFF')));
    // セーブ枠
    body.append(h('div', { class: 'h', style: 'margin-top:10px' }, `セーブ枠（無料${YA.SLOT_COUNT}つ）`), h('div', { class: 'note' }, '1つの遊びに自動セーブが1つ。枠ごとに別のクラブで遊べます。'));
    for (let i = 0; i < YA.SLOT_COUNT; i++) {
      const cur = app.slot === i;
      const w = cur ? app.w : store.get(YA.slotKey(i), null);
      const sum = w ? YA.slotSummary(w) : null;
      body.append(h('div', { class: 'card', style: 'padding:6px 9px;margin:4px 0;display:flex;align-items:center;gap:6px' },
        h('span', { class: 'chip ' + (cur ? 'trait' : 'gray') }, `枠${i + 1}${cur ? '（いま）' : ''}`),
        h('span', { class: 'grow', style: 'font-size:11.5px' }, sum || '空き'),
        !cur && sum ? h('button', { class: 'btn sm', onclick: () => switchSlot(i) }, 'この枠で遊ぶ') : null,
        !cur && !sum ? h('button', { class: 'btn sm', onclick: () => switchSlot(i) }, '新しく始める') : null,
        sum && !cur ? h('button', { class: 'btn sm', style: 'color:#b02020', onclick: () => confirmBox('枠' + (i + 1) + 'を削除しますか', () => { store.set(YA.slotKey(i), null); rerender(); }) }, '削除') : null));
    }
    // 書き出し・復元・控え
    body.append(h('div', { class: 'h', style: 'margin-top:8px' }, '書き出し・復元'), h('div', { class: 'row', style: 'gap:5px;flex-wrap:wrap;margin-top:3px' },
      h('button', { class: 'btn sm', onclick: exportBox }, '書き出す（コピーして保管）'),
      h('button', { class: 'btn sm', onclick: importBox }, '復元する（貼り付け）'),
      store.get(YA.slotKey(app.slot) + '_bak', null) ? h('button', { class: 'btn sm', onclick: () => confirmBox('年度はじめの控えに戻しますか（いまの進み具合は消えます）', () => { app.w = store.get(YA.slotKey(app.slot) + '_bak', null); YA.saveWorld(true); rerender(); }) }, '控え（年度はじめ）に戻す') : null));
    body.append(h('div', { class: 'h', style: 'margin-top:10px' }, 'この枠を最初からやり直す'), h('div', { class: 'note' }, '36人も成績も消えて、新しい指導者から始まります。'), h('button', { class: 'btn', style: 'margin-top:5px;color:#b02020', onclick: () => confirmBox('本当に最初からやり直しますか', () => { app.w = null; app.ng = null; store.set(YA.slotKey(app.slot), null); rerender(); }) }, '最初からやり直す'));
  };
  function confirmBox(text, ok) {
    V().modal((close) => h('div', { class: 'sheet-in', style: 'flex:none;align-self:center;margin:auto;width:min(420px,95%);padding:12px;gap:8px' }, h('div', { class: 'h' }, text), h('div', { class: 'row' }, h('button', { class: 'btn', onclick: close }, 'やめる'), h('button', { class: 'btn pri', onclick: () => { close(); ok(); } }, 'はい'))));
  }
  function switchSlot(i) {
    const app = U().app;
    YA.saveWorld(true);
    app.slot = i;
    U().store.set('slot', i);
    const w = U().store.get(YA.slotKey(i), null);
    app.w = w && w.v >= 3 ? w : null;
    app.ng = null;
    app.tab = 'home';
    app.view = 'pre';
    rerender();
  }
  function exportBox() {
    const app = U().app;
    const text = YA.exportWorld(app.w);
    V().modal((close) => {
      const ta = h('textarea', { readonly: true, style: 'width:100%;height:150px;font:10px monospace;border:1px solid #b9c7de;border-radius:8px;padding:6px' });
      ta.value = text;
      const msg = h('div', { class: 'note' }, `${(text.length / 1024).toFixed(0)}KB。全部選んでコピーして、メモなどに貼って保管してください。`);
      return h('div', { class: 'sheet-in', style: 'flex:none;align-self:center;margin:auto;width:min(680px,97%);padding:12px;gap:6px' }, h('div', { class: 'h' }, 'セーブデータの書き出し'), ta, msg,
        h('div', { class: 'row' }, h('button', { class: 'btn', onclick: () => { ta.select(); try { if (navigator.clipboard) navigator.clipboard.writeText(text).then(() => (msg.textContent = 'コピーしました')).catch(() => document.execCommand('copy')); else document.execCommand('copy'); } catch (e) {} } }, 'コピー'), h('button', { class: 'btn pri', onclick: close }, '閉じる')));
    });
  }
  function importBox() {
    const app = U().app;
    V().modal((close) => {
      const ta = h('textarea', { placeholder: '書き出したセーブデータを貼り付けます', style: 'width:100%;height:130px;font:10px monospace;border:1px solid #b9c7de;border-radius:8px;padding:6px' });
      const msg = h('div', { class: 'note' }, 'いまの枠のデータは、置き換わります。');
      return h('div', { class: 'sheet-in', style: 'flex:none;align-self:center;margin:auto;width:min(680px,97%);padding:12px;gap:6px' }, h('div', { class: 'h' }, 'セーブデータの復元'), ta, msg,
        h('div', { class: 'row' }, h('button', { class: 'btn', onclick: close }, 'やめる'), h('button', { class: 'btn pri', onclick: () => { const r = YA.importWorld(ta.value.trim()); if (!r.ok) { msg.textContent = r.msg; return; } app.w = r.world; YA.saveWorld(true); close(); rerender(); } }, '復元する')));
    });
  }
})();
