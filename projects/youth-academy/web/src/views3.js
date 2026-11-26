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
    // セーブはあるのに読めなかった：黙って新しく始めず、控えに戻すか新しく始めるかを選ばせる
    if (app.loadErr) return loadErrView(main);
    app.ng = app.ng || { name: '', career: 'grind', club: 2, points: { teach: 0, eye: 0, talk: 0, tactic: 0 }, noFire: false, legacy: null };
    const f = app.ng;
    const used = () => Object.values(f.points).reduce((a, b) => a + b, 0);
    const career = YA.CAREERS.find((c) => c.k === f.career);
    const coachNow = (k) => 8 + (career.coach[k] || 0) + f.points[k];
    const left = h('div', { class: 'card pbody', style: 'flex:1.1;min-width:0' });
    const input = h('input', { type: 'text', maxlength: 12, placeholder: '名前（空なら「監督」）', value: f.name, style: 'width:100%;padding:7px 9px;border:1px solid #b9c7de;border-radius:8px;font:inherit;font-weight:700' });
    input.addEventListener('input', () => (f.name = input.value));
    input.addEventListener('pointerdown', (e) => e.stopPropagation());
    if (app.oldSave) left.append(h('div', { class: 'note oldsave', style: 'color:#8a5a00;background:#fff8e1;border-radius:6px;padding:4px 8px;margin-bottom:4px' }, '前の版のセーブは、育て方の仕組み（★と覚醒の鍵→課題）を作り替えたため読み込めません。新しく始めてください。'));
    left.append(h('div', { class: 'h', style: 'font-size:15px' }, '指導者を作る'), h('div', { class: 'note', style: 'margin:6px 0 2px' }, '名前'), input);
    left.append(h('div', { class: 'note', style: 'margin:8px 0 3px' }, '経歴（最初の能力・資格・評判が変わります）'));
    for (const c of YA.CAREERS) left.append(h('button', { class: 'rolecard' + (f.career === c.k ? ' on' : ''), onclick: () => { f.career = c.k; rerender(); } }, h('div', { class: 'grow' }, h('b', {}, c.name), h('div', {}, h('span', { class: 'd' }, c.note)))));
    left.append(h('div', { class: 'note', style: 'margin:8px 0 3px' }, `自由に振り分ける点数：あと${YA.CAREER_POINTS - used()}`));
    left.append(h('div', { style: 'display:grid;grid-template-columns:1fr 1fr;gap:5px' }, YA.COACH_ABS.map(([k, n, note]) => h('div', { class: 'card', style: 'padding:5px 8px;display:flex;align-items:center;gap:6px' }, h('div', { class: 'grow' }, h('b', {}, n), h('div', { class: 'note' }, note)), h('button', { class: 'btn sm', disabled: f.points[k] <= 0, why: 'これ以上は減らせません', onclick: () => { f.points[k]--; rerender(); } }, '−'), h('b', { style: 'width:20px;text-align:center' }, coachNow(k)), h('button', { class: 'btn sm', disabled: used() >= YA.CAREER_POINTS, onclick: () => { f.points[k]++; rerender(); } }, '＋')))));
    const right = h('div', { class: 'card pbody', style: 'flex:1;min-width:0' });
    right.append(h('div', { class: 'h', style: 'font-size:15px' }, '最初のクラブを選ぶ'), h('div', { class: 'note', style: 'margin:3px 0 5px' }, '部が上のクラブほど予算が大きく、素質のある選手が集まりますが、評価の目も厳しくなります。'));
    YA.START_CLUBS.forEach((c, i) => right.append(h('button', { class: 'rolecard' + (f.club === i ? ' on' : ''), onclick: () => { f.club = i; rerender(); } }, h('div', { class: 'grow' }, h('b', {}, c.name), h('div', {}, h('span', { class: 'd' }, c.note))), h('span', { class: 'chip ' + (c.tier === 1 ? 'trait' : c.tier === 2 ? 'pers' : 'gray') }, YA.TIER_NAME[c.tier]))));
    right.append(h('div', { class: 'row', style: 'margin-top:8px' }, h('span', { class: 'grow' }, '解任'), h('button', { class: 'btn sm' + (f.noFire ? ' on' : ''), onclick: () => { f.noFire = !f.noFire; rerender(); } }, f.noFire ? '解任なし' : '解任あり')), h('div', { class: 'note' }, '「解任なし」でも、評価が悪いと予算と信頼度は下がります。'));
    const ppl = YA.legacyPeople(U().store);
    if (ppl.length) {
      right.append(h('div', { class: 'h', style: 'margin-top:10px' }, '前の人生の教え子'), h('div', { class: 'note' }, '絆の深かった教え子の卒業生が、コーチとして付いてきてくれます。1人だけ連れていけます（同じ役のコーチと入れ替わり、毎月、課題中の子に自分の経験を話します）。'));
      for (const q of ppl) {
        const on = f.legacy === q.name;
        const m = YA.definingMem ? YA.definingMem(q) : null;
        right.append(h('div', { class: 'pitem', style: 'cursor:default;gap:6px;margin-top:3px' }, h('div', { class: 'grow' }, h('b', {}, `${q.name}（${q.from || ''} ${q.year}年目卒・${YA.obRoleOf(q)}）`), h('div', { class: 'note' }, m && YA.recallMem ? `「${YA.recallMem(q, m)}」` : `${q.club || ''}`)),
          h('button', { class: 'btn sm' + (on ? ' on' : ''), onclick: () => { f.legacy = on ? null : q.name; rerender(); } }, on ? '連れていく' : '連れていかない')));
      }
    }
    main.append(h('div', { style: 'flex:1;min-height:0;display:flex;flex-direction:column;gap:6px' },
      h('div', { class: 'row', style: 'gap:8px;padding:14px 12px;border-radius:12px;color:#fff;background:linear-gradient(90deg,rgba(8,16,36,.7),rgba(8,16,36,.15)),' + (YA.titleSrc() ? `url(${YA.titleSrc()}) center/cover` : '#223') }, h('div', { class: 'h grow', style: 'font-size:19px;color:#fff;text-shadow:0 1px 4px rgba(0,0,0,.6)' }, 'ユースの系譜　新しく始める'),
        // 空き枠で始めかけたときは、前の枠に戻れる
        app.prevSlot != null && app.prevSlot !== app.slot && U().store.get(YA.slotKey(app.prevSlot), null) ? h('button', { class: 'btn', style: 'min-height:38px', onclick: () => { const i = app.prevSlot; app.prevSlot = null; switchSlot(i); } }, `やめて前の枠（枠${app.prevSlot + 1}）に戻る`) : null,
        h('button', { class: 'btn pri', style: 'min-width:150px;min-height:38px;font-size:14px', onclick: () => { const opts = YA.makeStart({ name: f.name, career: f.career, club: f.club, points: f.points, noFire: f.noFire }); if (f.legacy) opts.legacy = YA.legacyTake(U().store, f.legacy);
 app.w =YA.newWorld((Date.now() % 90000) + 7, opts); app.ng = null; app.tab = 'home'; app.view = 'pre'; YA.saveWorld(true); YA.sfx.play('whistle'); rerender(); } }, 'この指導者で始める')),
      h('div', { style: 'flex:1;min-height:0;display:flex;gap:8px' }, left, right)));
  };

  function loadErrView(main) {
    const app = U().app;
    const store = U().store;
    const key = YA.slotKey(app.slot || 0);
    const bak = store.get(key + '_bak', null);
    const bakOk = bak && bak.v >= YA.SAVE_V && bak.players && bak.lineupA;
    const box = h('div', { class: 'card', style: 'margin:auto;max-width:520px;padding:16px;display:flex;flex-direction:column;gap:8px' });
    box.append(h('div', { class: 'h', style: 'font-size:16px' }, 'セーブを読めませんでした'), h('div', { class: 'note', style: 'color:var(--ink)' }, `枠${(app.slot || 0) + 1}のセーブが壊れているか、読めない形でした。年度はじめの控えに戻すか、新しく始めるかを選んでください。書き出したセーブがあれば、新しく始めたあと設定の「復元する」で戻せます。`));
    box.append(h('div', { class: 'row', style: 'gap:6px;flex-wrap:wrap' },
      h('button', { class: 'btn pri', disabled: !bakOk, why: 'この枠には年度はじめの控えがありません', onclick: () => { app.loadErr = null; app.w = bak; app.tab = 'home'; app.view = 'pre'; YA.saveWorld(true); rerender(); } }, bakOk ? `控え（年度はじめ）に戻す：${YA.slotSummary(bak) || ''}` : '控え（年度はじめ）に戻す'),
      h('button', { class: 'btn', onclick: () => confirmBox('新しく始めますか（読めなかったセーブは、新しく始めた時点で上書きされます）', () => { app.loadErr = null; rerender(); }, { yes: '新しく始める', danger: true }) }, '新しく始める')));
    main.append(box);
  }

  // ---------- おまかせ進行（1週・次の試合・1年）----------
  // 開発用の道具（おまかせ進行・点検用シミュレーション）は、遊ぶ人には見せない。URL に ?dev を付けたときだけ出す
  YA.devOn = () => {
    try {
      return globalThis.YA_DEV === true || /[?&]dev/.test(globalThis.location.search);
    } catch (e) {
      return false;
    }
  };
  YA.simCard = function () {
    if (!YA.devOn()) return null;
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
  // 最初の説明（決定128）。飛ばせる・設定から読み返せる
  YA.showIntro = function () {
    const app = U().app;
    if (!app.w || document.querySelector('.sheet.intro')) return;
    let i = 0;
    const main = document.getElementById('main');
    const sheet = h('div', { class: 'sheet intro', style: 'z-index:30' });
    const done = () => { app.w.introSeen = true; YA.saveWorld(); sheet.remove(); };
    const draw = () => {
      const [t, b] = YA.INTRO[i];
      sheet.replaceChildren(h('div', { class: 'sheet-in', style: 'flex:none;align-self:center;margin:auto;width:min(520px,94%);padding:16px 18px;gap:10px' },
        h('div', { class: 'sub' }, `はじめに ${i + 1}/${YA.INTRO.length}`), h('div', { class: 'h', style: 'font-size:18px' }, t), h('div', { style: 'font-size:13.5px;line-height:1.6' }, b),
        h('div', { class: 'row', style: 'gap:6px' }, h('button', { class: 'btn', onclick: done }, '飛ばす'), h('span', { class: 'grow' }), i > 0 ? h('button', { class: 'btn', onclick: () => { i--; draw(); } }, '戻る') : null,
          h('button', { class: 'btn pri', onclick: () => { if (i < YA.INTRO.length - 1) { i++; draw(); } else done(); } }, i < YA.INTRO.length - 1 ? '次へ' : 'はじめる'))));
    };
    draw();
    main.append(sheet);
  };
  YA.settingsBlock = function (body) {
    const app = U().app;
    const store = U().store;
    // 1本の長い画面だったので4つに分ける（2026-11-18 ユーザビリティ16）
    const ST = [['disp', '表示と音'], ['notice', 'お知らせ'], ['name', '名前'], ['save', 'セーブ']]; // ショップは 2026-11-25 に「ほか」の小タブへ
    app.st = ST.some((x) => x[0] === app.st) ? app.st : 'disp';
    body.append(h('div', { class: 'row', style: 'gap:6px' }, h('div', { class: 'h' }, '設定'), h('div', { class: 'tabs settabs', style: 'flex:1;min-width:0' }, ST.map(([k, n]) => h('button', { class: 'btn sm' + (app.st === k ? ' on' : ''), onclick: () => { app.st = k; rerender(); } }, n)))));
    if (app.st === 'notice') { fontAndNotices(body, 'notice'); return; }
    if (app.st === 'name') { YA.nameBlock(body); if (!app.w || !app.w.league) body.append(h('div', { class: 'note' }, '遊んでいる枠があると、クラブ名を変えられます')); return; }
    if (app.st === 'save') return saveShop(body);
    body.append(h('div', { class: 'row', style: 'margin:6px 0' }, h('span', { class: 'grow' }, '最初の説明・コーチの一言'), h('button', { class: 'btn sm', onclick: () => { if (app.w) { app.w.coachSeen = {}; app.w.introSeen = false; YA.saveWorld(); rerender(); } } }, '読み返す')));
    body.append(h('div', { class: 'row', style: 'margin:6px 0' }, h('span', { class: 'grow' }, '試合の自動停止（前半終了・得点・失点・残り15分）'), h('button', { class: 'btn sm' + (app.autoStop ? ' on' : ''), onclick: () => { app.autoStop = !app.autoStop; store.set('autoStop', app.autoStop); rerender(); } }, app.autoStop ? 'ON' : 'OFF')));
    body.append(h('div', { class: 'row', style: 'margin:6px 0' }, h('span', { class: 'grow' }, '効果音'), h('button', { class: 'btn sm' + (YA.sfx.on ? ' on' : ''), onclick: () => { YA.sfx.on = !YA.sfx.on; store.set('sfx', YA.sfx.on); YA.sfx.play('tap'); rerender(); } }, YA.sfx.on ? 'ON' : 'OFF')));
    body.append(h('div', { class: 'row', style: 'margin:6px 0' }, h('span', { class: 'grow' }, 'BGM（ホームと試合で曲が変わります）'), h('button', { class: 'btn sm' + (YA.bgm.on ? ' on' : ''), onclick: () => { YA.bgm.setOn(!YA.bgm.on); store.set('bgm', YA.bgm.on); rerender(); } }, YA.bgm.on ? 'ON' : 'OFF')));
    for (const [k, n] of YA.ASK_SKIPS || []) {
      const on = store.get('ask.' + k, true) !== false;
      body.append(h('div', { class: 'row', style: 'margin:6px 0' }, h('span', { class: 'grow' }, n), h('button', { class: 'btn sm' + (on ? ' on' : ''), 'data-ask': k, onclick: () => { store.set('ask.' + k, !on); rerender(); } }, on ? '出す' : '出さない')));
    }
    fontAndNotices(body, 'font');
  };
  function saveShop(body) {
    const app = U().app;
    const store = U().store;
    // セーブ枠（ショップは 2026-11-25 に「ほか」→ ショップへ移した）
    YA.slotBlock(body);
    // 最後に保存できた時刻（保存に失敗し続けていないかを見られるように）
    const ss = YA.saveState || {};
    const hm = (t) => { const d = new Date(t); return `${d.getMonth() + 1}/${d.getDate()} ${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`; };
    body.append(h('div', { class: 'note', style: 'margin-top:2px' + (ss.lastFail && (!ss.lastOk || ss.lastFail > ss.lastOk) ? ';color:#b02020' : '') }, ss.lastOk ? `最後に保存できた時刻：${hm(ss.lastOk)}` + (ss.lastFail && ss.lastFail > ss.lastOk ? `（${hm(ss.lastFail)}に保存できませんでした）` : '') : ss.lastFail ? `保存できていません（${hm(ss.lastFail)}）` : 'この起動ではまだ保存していません'));
    // 書き出し・復元・控え
    body.append(h('div', { class: 'h', style: 'margin-top:8px' }, '書き出し・復元'), h('div', { class: 'row', style: 'gap:5px;flex-wrap:wrap;margin-top:3px' },
      h('button', { class: 'btn sm', onclick: exportBox }, '書き出す（コピーして保管）'),
      h('button', { class: 'btn sm', onclick: importBox }, '復元する（貼り付け）'),
      store.get(YA.slotKey(app.slot) + '_bak', null) ? h('button', { class: 'btn sm', onclick: () => confirmBox('年度はじめの控えに戻しますか（いまの進み具合は消えます。' + ORIG_NOTE + '）', () => { app.w = store.get(YA.slotKey(app.slot) + '_bak', null); YA.saveWorld(true); rerender(); }, { yes: '控えに戻す', danger: true }) }, '控え（年度はじめ）に戻す') : null));
    if (YA.devOn()) testBlock(body);
    body.append(h('div', { class: 'h', style: 'margin-top:10px' }, 'この枠を最初からやり直す'), h('div', { class: 'note' }, '33人も成績も消えて、新しい指導者から始まります。'), h('button', { class: 'btn', style: 'margin-top:5px;color:#b02020', onclick: () => confirmBox('本当に最初からやり直しますか', () => { app.w = null; app.ng = null; store.set(YA.slotKey(app.slot), null); rerender(); }, { yes: 'やり直す', danger: true, note: '33人も成績も消えて、元に戻せません。' }) }, '最初からやり直す'));
  };
  // 控えに戻す・復元で、予約したオリジナル選手がどうなるか
  const ORIG_NOTE = '予約したオリジナル選手も戻ります（使ったチケットは戻りません）';
  // セーブ枠の一覧（設定と、引退後の画面から）
  YA.slotBlock = function (body) {
    const app = U().app;
    const store = U().store;
    body.append(h('div', { class: 'h slothead', style: 'margin-top:10px' }, `セーブ枠（いま${YA.SLOT_COUNT}枠・無料は1枠）`), h('div', { class: 'note' }, '1つの遊びに自動セーブが1つ。枠ごとに別のクラブで遊べます。'));
    for (let i = 0; i < YA.SLOT_COUNT; i++) {
      const cur = app.slot === i;
      const w = cur ? app.w : store.get(YA.slotKey(i), null);
      const sum = w ? YA.slotSummary(w) : null;
      body.append(h('div', { class: 'card', style: 'padding:6px 9px;margin:4px 0;display:flex;align-items:center;gap:6px' },
        h('span', { class: 'chip ' + (cur ? 'trait' : 'gray') }, `枠${i + 1}${cur ? '（いま）' : ''}`),
        h('span', { class: 'grow', style: 'font-size:11.5px' }, sum || '空き'),
        !cur && sum ? h('button', { class: 'btn sm', onclick: () => switchSlot(i) }, 'この枠で遊ぶ') : null,
        !cur && !sum ? h('button', { class: 'btn sm', onclick: () => switchSlot(i) }, '新しく始める') : null,
        sum && !cur ? h('button', { class: 'btn sm', style: 'color:#b02020', onclick: () => confirmBox('枠' + (i + 1) + 'を削除しますか', () => { store.set(YA.slotKey(i), null); rerender(); }, { yes: '削除する', danger: true, note: '消した枠は元に戻せません。' }) }, '削除') : null));
    }
  };
  // ---------- 点検用：新しい世界でNか年シミュレーション（いまの遊びには影響しない）----------
  function testBlock(body) {
    const app = U().app;
    const f = (app.tt = app.tt || { seed: 1, years: 1, tier: 2 });
    body.append(h('div', { class: 'h', style: 'margin-top:10px' }, '点検用：新しい世界でシミュレーション'), h('div', { class: 'note' }, 'いまの遊びには影響しません。同じシードなら同じ結果になります。1年に数秒〜十数秒かかります（10年は数分）。'));
    const seed = h('input', { type: 'number', min: 1, max: 99999, value: f.seed, style: 'width:90px;padding:5px 7px;border:1px solid #b9c7de;border-radius:8px;font:inherit;font-weight:700' });
    seed.addEventListener('input', () => (f.seed = clamp(parseInt(seed.value, 10) || 1, 1, 99999)));
    body.append(h('div', { class: 'row', style: 'gap:5px;flex-wrap:wrap;margin-top:4px' },
      h('span', { class: 'sub' }, 'シード'), seed,
      h('span', { class: 'sub', style: 'margin-left:6px' }, '年数'), ...[1, 3, 10].map((y) => h('button', { class: 'btn sm' + (f.years === y ? ' on' : ''), onclick: () => { f.years = y; rerender(); } }, y + '年')),
      h('span', { class: 'sub', style: 'margin-left:6px' }, 'クラブ'), ...[1, 2, 3].map((t) => h('button', { class: 'btn sm' + (f.tier === t ? ' on' : ''), onclick: () => { f.tier = t; rerender(); } }, YA.TIER_NAME[t])),
      h('button', { class: 'btn pri sm', onclick: () => runTestUi(f) }, '実行')));
  }
  function runTestUi(f) {
    const st = YA.testStart({ seed: f.seed, years: f.years, tier: f.tier });
    const msg = h('div', { class: 'note' }, '進めています…');
    const bx = h('div', { class: 'sheet-in', style: 'flex:none;align-self:center;margin:auto;width:min(760px,98%);max-height:97%;padding:12px;gap:6px;overflow:auto' }, h('div', { class: 'h', style: 'font-size:15px' }, `点検用シミュレーション（シード${f.seed}・${f.years}年・${YA.TIER_NAME[f.tier]}）`), msg);
    let closeFn = null;
    V().modal((close) => {
      closeFn = close;
      return bx;
    });
    const next = () => {
      if (st.done < f.years) {
        msg.textContent = `進めています… ${st.done + 1}/${f.years}年目`;
        setTimeout(() => {
          YA.testYear(st);
          next();
        }, 30);
        return;
      }
      const sm = YA.testSummary(st);
      msg.remove();
      const cell = (t, wd, strong) => h('span', { style: `width:${wd}px;flex:none;text-align:right;${strong ? 'font-weight:900' : ''}` }, t);
      const head = h('div', { class: 'pitem', style: 'background:none;font-size:10.5px;color:var(--sub);font-weight:800;gap:2px' }, cell('年', 24), cell('順位', 46), cell('評価', 28), cell('信頼', 34), cell('予算', 42), cell('成長', 32), cell('怪我', 28), cell('退団', 28), cell('プロ', 28), cell('①/②/③', 62), cell('選ぶ/週', 46), cell('分/週', 36));
      bx.append(head);
      st.years.forEach((r, i) => {
        const m = r.metrics;
        bx.append(h('div', { class: 'pitem', style: 'cursor:default;font-size:11.5px;gap:2px' }, cell(i + 1, 24, true), cell(`${m.rank}位${m.move < 0 ? '↑' : m.move > 0 ? '↓' : ''}`, 46), cell(m.letter, 28, true), cell(`${m.trustBefore}→${m.trustAfter}`, 34), cell(m.budget, 42), cell('+' + m.growthAvg, 32), cell(m.injuries, 28), cell(m.quits, 28), cell(m.gradPaths.pro, 28), cell(`${m.noticesByTier[1]}/${m.noticesByTier[2]}/${m.noticesByTier[3]}`, 62), cell(m.picksPerWeek, 46), cell(m.minutesPerWeek, 36)));
      });
      bx.append(h('div', { class: 'insight' }, `平均：順位${sm.avgRank}位・成長+${sm.growthAvg}/年・怪我${sm.injuries}件/年・プロ入り${sm.pro}人/年・選ぶ回数${sm.picks}回/週・想定${sm.minutes}分/週（目標は1週8〜10分）`), h('div', { class: 'insight' }, '評価の内訳：' + Object.entries(sm.letters).map(([k, v]) => `${k}×${v}`).join('、') + `／予算の平均${sm.budget}万円／在籍${sm.players}人`));
      const last = st.years[st.years.length - 1];
      bx.append(h('div', { class: 'h', style: 'margin-top:4px' }, `最後の年（${st.years.length}年目）の報告`), ...last.lines.map((l) => h('div', { class: 'note', style: 'color:var(--ink)' }, '・' + l.t)));
      bx.append(h('button', { class: 'btn pri', onclick: () => closeFn() }, '閉じる'));
    };
    next();
  }
  // ---------- 文字の大きさ・お知らせの3段（決定76） ----------
  function fontAndNotices(body, part) {
    const app = U().app;
    const store = U().store;
    const cur = store.get('fs', 1);
    if (part !== 'notice') body.append(h('div', { class: 'h', style: 'margin-top:10px' }, '文字の大きさ'), h('div', { class: 'row', style: 'gap:5px;margin-top:3px' },
      ...YA.FONT_SCALES.map(([name], i) => h('button', { class: 'btn sm' + (cur === i ? ' on' : ''), onclick: () => { store.set('fs', i); YA.applyFontScale(i); rerender(); } }, name))));
    if (!app.w || part === 'font') return;
    const w = app.w;
    w.noticeTier = w.noticeTier || {};
    body.append(h('div', { class: 'row', style: 'margin-top:8px' }, h('div', { class: 'h grow' }, 'お知らせの重さ'), h('button', { class: 'btn sm', disabled: !Object.keys(w.noticeTier).length, why: 'いまは全部おすすめ（お知らせ）のままです', onclick: () => { w.noticeTier = {}; YA.saveWorld(true); rerender(); if (YA.toast) YA.toast('お知らせの重さを、全部おすすめに戻しました'); } }, '全部おすすめに戻す')), h('div', { class: 'note' }, '項目ごとに選べます。「必ず止める」はおまかせ進行でも止まります。「記録だけ」は出来事の記録にだけ残ります。'));
    const kinds = YA.NOTICE_KINDS.map((x) => x[0]).concat(['そのほか']);
    const grid = h('div', { style: 'display:grid;grid-template-columns:1fr 1fr;gap:3px 14px' });
    body.append(grid);
    for (const k of kinds) {
      const t = w.noticeTier[k] || 2;
      grid.append(h('div', { class: 'row', style: 'gap:3px' }, h('span', { class: 'grow', style: 'font-size:11.5px' }, k),
        ...[1, 2, 3].map((n) => h('button', { class: 'btn sm' + (t === n ? ' on' : ''), style: 'padding:3px 8px;min-height:34px;font-size:11.5px', onclick: () => { w.noticeTier[k] = n; YA.saveWorld(true); rerender(); } }, YA.NOTICE_TIER_NAME[n]))));
    }
  }

  // ---------- 実績と引退（決定51） ----------
  YA.achBlock = function (body, o) {
    const app = U().app;
    const w = app.w;
    if (o && o.retireOnly) {
      // 実績の一覧は系譜タブの「記録」にある。ここは引退だけ
      const done = YA.achievements(w).filter((a) => a.done).length;
      body.append(h('div', { class: 'row' }, h('div', { class: 'h grow' }, `実績 ${done}/${YA.achievements(w).length}`), h('button', { class: 'btn sm', onclick: () => { app.tab = 'lineage'; app.lt = 'ach'; rerender(); } }, '記録タブで実績を見る')));
    } else body.append(h('div', { class: 'h' }, '実績'));
    if (!(o && o.retireOnly)) for (const a of YA.achievements(w)) {
      body.append(h('div', { class: 'pitem', style: 'cursor:default;gap:6px' },
        h('span', { class: 'chip ' + (a.done ? 'trait' : 'gray') }, a.done ? '達成' : '未達'),
        h('span', { class: 'grow', style: 'font-size:12px' }, a.name + (a.goal ? `（${Math.min(a.cur, a.goal)}/${a.goal}）` : '')),
        a.note ? h('span', { class: 'note' }, a.note) : null));
    }
    body.append(h('div', { class: 'h', style: 'margin-top:10px' }, '引退'), h('div', { class: 'note' }, '指導者を引退して、ここまでの歩みをまとめます。引退すると続きは遊べません（書き出しで残せます）。'),
      h('button', { class: 'btn', style: 'margin-top:5px;color:#b02020', onclick: () => confirmBox('指導者を引退しますか', () => { YA.retire(w); YA.saveWorld(true); rerender(); }, { yes: '引退する', danger: true, note: '引退すると、この指導者の人生はここで終わります。' }) }, '引退する'));
  };
  YA.views = YA.views || {};
  YA.views.retired = function (main) {
    const app = U().app;
    // 引退後も名鑑・系譜は見られる（行き止まりにしない）
    if (app.retBrowse && YA.views[app.retBrowse]) {
      main.append(h('div', { class: 'row', style: 'gap:6px;margin:6px 8px 0' }, h('button', { class: 'btn sm', onclick: () => { app.retBrowse = null; rerender(); } }, '← まとめに戻る'),
        h('button', { class: 'btn sm' + (app.retBrowse === 'more' ? ' on' : ''), onclick: () => { app.retBrowse = 'more'; app.mt = 'alumni'; rerender(); } }, '卒業生名鑑'),
        h('button', { class: 'btn sm' + (app.retBrowse === 'lineage' ? ' on' : ''), onclick: () => { app.retBrowse = 'lineage'; rerender(); } }, '記録')));
      YA.views[app.retBrowse](main);
      return;
    }
    const s = YA.careerSummary(app.w);
    const box = h('div', { class: 'card', style: 'margin:10px;padding:12px' });
    box.append(h('div', { class: 'h', style: 'font-size:16px' }, `指導者人生のまとめ（${s.years}年）`));
    box.append(h('div', { class: 'note' }, (app.w.coachName || '指導者') + 'さんの歩み'));
    const lg = YA.legacyBank(U().store, app.w);
    box.append(h('div', { class: 'insight' }, lg.length ? `次の人生に付いてきてくれる教え子：${lg.join('・')}（新しく始めるときに1人選べます）` : '次の人生に付いてきてくれる教え子は、いません（絆の深い教え子の卒業生が付いてきます）'));
    box.append(h('div', { class: 'insight' }, `プロ入りした卒業生 ${s.pros}人／代表経験者 ${s.nats}人／連帯貢献金 ${YA.yen(s.solid)}`));
    if (s.best.length) box.append(h('div', { class: 'h', style: 'margin-top:4px' }, '育てた主な子'), ...s.best.map((a) => h('div', { class: 'note', style: 'color:var(--ink)' }, `・${a.name}（${a.pos}・総合力${YA.rate(a.ovr)}・${a.club || ''}）`)));
    if (s.trophies.length) box.append(h('div', { class: 'h', style: 'margin-top:4px' }, '獲ったもの'), ...s.trophies.map((t) => h('div', { class: 'note', style: 'color:var(--ink)' }, `・${t.year || ''}年 ${t.name}`)));
    box.append(h('div', { class: 'h', style: 'margin-top:4px' }, '実績'), ...s.ach.map((a) => h('div', { class: 'note', style: 'color:var(--ink)' }, (a.done ? '◎ ' : '・') + a.name)));
    box.append(h('div', { class: 'row', style: 'margin-top:8px;gap:6px' },
      h('button', { class: 'btn', onclick: () => { app.retBrowse = 'more'; app.mt = 'alumni'; rerender(); } }, '名鑑・記録を見る'),
      h('button', { class: 'btn', onclick: () => V().modal((close) => { const bx = h('div', { class: 'sheet-in', style: 'flex:none;align-self:center;margin:auto;width:min(560px,96%);max-height:94%;padding:12px;gap:6px;overflow:auto' }); YA.slotBlock(bx); bx.append(h('button', { class: 'btn', onclick: close }, '閉じる')); return bx; }) }, 'セーブ枠'),
      h('button', { class: 'btn', onclick: exportBox }, 'セーブを書き出す'),
      h('button', { class: 'btn pri', onclick: () => confirmBox(`枠${(app.slot || 0) + 1}のセーブを消して新しく始めますか（この指導者人生の記録はこの枠から消えます。残したいときは先に「セーブを書き出す」か、別の枠で始めてください）`, () => { const st = U().store; st.set(YA.slotKey(app.slot), null); app.w = null; app.ng = null; app.retBrowse = null; rerender(); }) }, '新しく始める')));
    main.append(box);
  };
  // ---------- 名前の書き換え（決定52・54） ----------
  YA.renameBox = function (p) {
    const app = U().app;
    const pid = p.id;
    V().modal((close) => {
      const inp = h('input', { type: 'text', value: p.name, maxlength: 14, style: 'width:100%;padding:6px 8px;border:1px solid #b9c7de;border-radius:8px;font:inherit;font-weight:700' });
      const msg = h('div', { class: 'note' }, '1〜14文字で入れてください');
      return h('div', { class: 'sheet-in', style: 'flex:none;align-self:center;margin:auto;width:min(420px,95%);padding:12px;gap:8px' }, h('div', { class: 'h' }, '名前を変える'), inp, msg,
        h('div', { class: 'row' }, h('button', { class: 'btn', onclick: close }, 'やめる'), h('button', { class: 'btn pri', onclick: () => {
          const r = YA.renamePlayer(app.w, pid, inp.value);
          if (!r.ok) { msg.textContent = r.msg; return; }
          close();
          YA.saveWorld(true);
          rerender();
        } }, '決める')));
    });
  };
  // ---------- Bチームの指揮（決定30） ----------
  YA.bBlock = function (body) {
    const app = U().app;
    const w = app.w;
    const c = Object.assign({ form: '4-3-3', tactic: null, policy: 'best' }, w.bCtl || {});
    const set = (p) => { YA.setBCtl(w, p); YA.saveWorld(true); rerender(); };
    body.append(h('div', { class: 'h' }, 'Bチームの指揮'), h('div', { class: 'note' }, 'Bの試合は毎週、結果だけ自動で回ります。布陣・戦い方・誰を使うかをここで決めます（Aの並びは変わりません）。'));
    body.append(h('div', { class: 'h', style: 'margin-top:8px' }, '布陣'), h('div', { class: 'row', style: 'gap:5px;flex-wrap:wrap;margin-top:3px' }, ...Object.keys(YA.FORMATIONS).map((f) => h('button', { class: 'btn sm' + (c.form === f ? ' on' : ''), onclick: () => set({ form: f }) }, f))));
    body.append(h('div', { class: 'h', style: 'margin-top:8px' }, '戦い方'), h('div', { class: 'row', style: 'gap:5px;flex-wrap:wrap;margin-top:3px' }, h('button', { class: 'btn sm' + (!c.tactic ? ' on' : ''), onclick: () => set({ tactic: null }) }, 'Aと同じ'), ...Object.keys(YA.TACTICS).map((t) => h('button', { class: 'btn sm' + (c.tactic === t ? ' on' : ''), onclick: () => set({ tactic: t }) }, t))));
    body.append(h('div', { class: 'h', style: 'margin-top:8px' }, '起用方針'), h('div', { class: 'row', style: 'gap:5px;flex-wrap:wrap;margin-top:3px' }, ...YA.B_POLICY.map(([k, n]) => h('button', { class: 'btn sm' + (c.policy === k ? ' on' : ''), onclick: () => set({ policy: k }) }, n))));
    if (c.policy === 'manual') {
      const ui = app;
      const slotName = (s, i) => YA.pos15OfSlot(s, i);
      body.append(h('div', { class: 'h', style: 'margin-top:8px' }, 'Bの先発と控え'), h('div', { class: 'note' }, ui.bSel == null ? '入れ替えたい先発をタップ → 入れる選手をタップ' : '入れる選手（先発・控え）をタップ'));
      const chip = (p, on, fn) => h('button', { class: 'btn sm' + (on ? ' on' : ''), style: 'min-height:34px;padding:4px 6px;font-size:11.5px', onclick: fn }, `${p.name.split(' ')[0]} ${YA.ovr(p).toFixed(0)}${p.inj > 0 ? '＊' : ''}`);
      body.append(h('div', { class: 'row', style: 'gap:4px;flex-wrap:wrap;margin-top:3px' }, ...w.lineupB.map((s, i) => { const p = w.players[s.pid]; return h('span', { style: 'display:flex;flex-direction:column;align-items:center;gap:1px' }, h('span', { class: 'note', style: 'font-size:10.5px' }, slotName(s, i)), chip(p, ui.bSel === i, () => { if (ui.bSel == null) ui.bSel = i; else if (ui.bSel === i) ui.bSel = null; else { YA.swapB(w, ui.bSel, s.pid); ui.bSel = null; YA.saveWorld(true); } rerender(); })); })));
      body.append(h('div', { class: 'note', style: 'margin-top:5px' }, '控え'), h('div', { class: 'row', style: 'gap:4px;flex-wrap:wrap;margin-top:3px' }, ...(w.benchB || []).map((id) => w.players[id]).filter(Boolean).map((p) => chip(p, false, () => { if (ui.bSel == null) return; YA.swapB(w, ui.bSel, p.id); ui.bSel = null; YA.saveWorld(true); rerender(); }))));
    }
    // いまのBの先発（自分で決める以外のときも見えるように。2026-11-16 誰が出ているか見えなかった）
    if (c.policy !== 'manual' && (w.lineupB || []).length) {
      body.append(h('div', { class: 'h', style: 'margin-top:8px' }, 'Bの先発（いま）'), h('div', { style: 'display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:3px;margin-top:3px' },
        ...w.lineupB.map((sl, i) => { const p = w.players[sl.pid]; if (!p) return null; const p15 = YA.pos15OfSlot(sl, i); return h('div', { class: 'pitem', style: 'cursor:default;gap:5px;padding:3px 6px;min-height:0' }, h('span', { class: 'pos ' + YA.posOfSlot(sl, i) }, YA.POS_LABEL[p15] || p15), h('span', { class: 'grow', style: 'min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;font-size:12px' }, `${p.num} ${p.name}`), h('span', { class: 'sub', style: 'font-size:11px' }, '高' + p.grade), h('b', { style: 'font-size:12px' }, YA.rating(p))); })));
    }
    // 結果は勝ち・引き分け・負けで色を分ける
    const rs = (w.resultsB || []).slice(-8).reverse();
    const wdl = (r) => (r.gf > r.ga ? ['勝', '#1e6b37', '#e6f5ea'] : r.gf < r.ga ? ['負', '#b02020', '#fdeaea'] : ['分', '#5b6b85', '#eef2f8']);
    body.append(h('div', { class: 'h', style: 'margin-top:8px' }, 'Bの最近の結果'), ...(rs.length ? [h('div', { class: 'plist', style: 'gap:2px;margin-top:3px' }, rs.map((r) => { const [t, fg, bg] = wdl(r); return h('div', { class: 'pitem', style: 'cursor:default;gap:8px;padding:3px 8px;min-height:0;font-size:12px' }, h('span', { style: `background:${bg};color:${fg};font-weight:900;border-radius:5px;padding:0 6px;flex:none` }, t), h('b', { style: `color:${fg};width:34px;flex:none` }, `${r.gf}-${r.ga}`), h('span', { class: 'grow' }, `vs ${r.opp}`), h('span', { class: 'sub' }, YA.ywName(r.year, r.week))); }))] : [h('div', { class: 'note' }, 'まだ試合がありません')]));
  };
  YA.nameBlock = function (body) {
    const app = U().app;
    const w = app.w;
    if (!w || !w.league) return;
    const ask = (title, cur, fn) => V().modal((close) => {
      const inp = h('input', { type: 'text', value: cur, maxlength: 14, style: 'width:100%;padding:6px 8px;border:1px solid #b9c7de;border-radius:8px;font:inherit;font-weight:700' });
      const msg = h('div', { class: 'note' }, '1〜14文字で入れてください');
      return h('div', { class: 'sheet-in', style: 'flex:none;align-self:center;margin:auto;width:min(420px,95%);padding:12px;gap:8px' }, h('div', { class: 'h' }, title), inp, msg,
        h('div', { class: 'row' }, h('button', { class: 'btn', onclick: close }, 'やめる'), h('button', { class: 'btn pri', onclick: () => { const r = fn(inp.value); if (!r.ok) { msg.textContent = r.msg; return; } close(); YA.saveWorld(true); rerender(); } }, '決める')));
    });
    body.append(h('div', { class: 'h', style: 'margin-top:10px' }, '名前の書き換え'), h('div', { class: 'note' }, '自分のクラブと、今年戦う相手クラブの名前を好きに変えられます（相手は翌年以降も同じ名前で出ます）。'));
    body.append(h('div', { class: 'row', style: 'margin:3px 0' }, h('span', { class: 'grow' }, w.clubName), h('button', { class: 'btn sm', onclick: () => ask('クラブ名を変える', w.clubName, (v) => YA.renameClub(w, v)) }, '変更')));
    for (const t of w.league.teams.filter((x) => !x.me)) body.append(h('div', { class: 'row', style: 'margin:3px 0' }, h('span', { class: 'grow', style: 'font-size:11.5px' }, t.name), h('button', { class: 'btn sm', onclick: () => ask('相手クラブの名前を変える', t.name, (v) => YA.renameTeam(w, t.id, v)) }, '変更')));
  };
  // 確認の窓。o.yes＝確定のボタンの言葉（動詞で。「はい」にしない）、o.danger＝取り返せない操作（確定は赤、「やめる」を主ボタンに）、o.note＝添え書き
  // o.skip＝「次回から聞かない」を付ける鍵（取り返せる操作だけ。端末の store に 'ask.<鍵>'=false で残る）。o.no＝やめたときの関数
  function confirmBox(text, ok, o, no) {
    // 試合の画面は (文, 確定の言葉, 関数, やめたとき) の形で呼ぶ（試合の直しと画面の直しを合わせた）
    if (typeof ok === 'string') { const yes = ok; ok = o; o = { yes, no }; }
    o = o || {};
    const danger = !!o.danger;
    const store = U().store;
    const skip = o.skip && !danger ? 'ask.' + o.skip : null;
    if (skip && store.get(skip, true) === false) { ok(); return; }
    let quiet = false;
    const box = skip ? h('input', { type: 'checkbox', onchange: (e) => { quiet = !!e.target.checked; } }) : null;
    V().modal((close) => h('div', { class: 'sheet-in', style: 'flex:none;align-self:center;margin:auto;width:min(420px,95%);padding:12px;gap:8px' }, h('div', { class: 'h' }, text), o.note ? h('div', { class: 'note' }, o.note) : null,
      box ? h('label', { class: 'row', style: 'gap:6px;font-size:12.5px;cursor:pointer;min-height:30px' }, box, '次回から聞かない（設定の「表示と音」で戻せます）') : null,
      h('div', { class: 'row' }, h('button', { class: 'btn' + (danger ? ' pri' : ''), onclick: () => { close(); if (o.no) o.no(); } }, 'やめる'), h('button', { class: 'btn ' + (danger ? 'danger' : 'pri'), onclick: () => { if (skip && quiet) store.set(skip, false); close(); ok(); } }, o.yes || '決める'))));
  }
  // 「次回から聞かない」にした確認（設定の「表示と音」で戻す）
  YA.ASK_SKIPS = [['skipmatch', '試合を見ずに「結果まで」進めるときの確認']];
  YA.confirmBox = confirmBox;
  function switchSlot(i) {
    const app = U().app;
    YA.saveWorld(true);
    // 空き枠へ移るときは、前の枠を覚えておく（新しく始める画面から戻れるように）
    if (app.w && i !== app.slot) app.prevSlot = app.slot;
    app.loadErr = null;
    app.retBrowse = null;
    app.slot = i;
    U().store.set('slot', i);
    const w = U().store.get(YA.slotKey(i), null);
    app.w = w && w.v >= YA.SAVE_V ? w : null;
    app.oldSave = !app.w && YA.isOldSave(w);
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
        h('div', { class: 'row' }, h('button', { class: 'btn', onclick: close }, 'やめる'), h('button', { class: 'btn pri', onclick: () => {
          const r = YA.importWorld(ta.value.trim());
          if (!r.ok) { msg.textContent = r.msg; return; }
          // いまの進み具合を上書きする前に確かめる
          confirmBox(`枠${(app.slot || 0) + 1}を、貼り付けたセーブ（${YA.slotSummary(r.world) || ''}）で置き換えますか（いまの進み具合は消えます。${ORIG_NOTE}）`, () => {
            // 書き出しの時点で予約していたオリジナル選手は、チケットの使用の記録と合うものだけ戻す（同じチケットで二度迎えない）
            const before = (r.world.originals || []).length;
            r.world.originals = YA.origFilter ? YA.origFilter(r.world.originals, YA.ent, false) : [];
            const dropped = before - r.world.originals.length;
            app.w = r.world;
            app.loadErr = null;
            YA.saveWorld(true);
            close();
            rerender();
            if (dropped > 0) { try { YA.toast(`予約していたオリジナル選手のうち${dropped}人は、チケットの記録と合わないので戻しませんでした`); } catch (e) { /* 画面なし */ } }
          }, { yes: '置き換える', danger: true });
        } }, '復元する')));
    });
  }
})();
