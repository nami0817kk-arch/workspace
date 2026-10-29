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
    fontAndNotices(body);
    YA.nameBlock(body);
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
    testBlock(body);
    body.append(h('div', { class: 'h', style: 'margin-top:10px' }, 'この枠を最初からやり直す'), h('div', { class: 'note' }, '36人も成績も消えて、新しい指導者から始まります。'), h('button', { class: 'btn', style: 'margin-top:5px;color:#b02020', onclick: () => confirmBox('本当に最初からやり直しますか', () => { app.w = null; app.ng = null; store.set(YA.slotKey(app.slot), null); rerender(); }) }, '最初からやり直す'));
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
      const head = h('div', { class: 'pitem', style: 'background:none;font-size:9.5px;color:var(--sub);font-weight:800;gap:2px' }, cell('年', 24), cell('順位', 46), cell('評価', 28), cell('信頼', 34), cell('予算', 42), cell('成長', 32), cell('怪我', 28), cell('退団', 28), cell('プロ', 28), cell('①/②/③', 62), cell('選ぶ/週', 46), cell('分/週', 36));
      bx.append(head);
      st.years.forEach((r, i) => {
        const m = r.metrics;
        bx.append(h('div', { class: 'pitem', style: 'cursor:default;font-size:10.5px;gap:2px' }, cell(i + 1, 24, true), cell(`${m.rank}位${m.move < 0 ? '↑' : m.move > 0 ? '↓' : ''}`, 46), cell(m.letter, 28, true), cell(`${m.trustBefore}→${m.trustAfter}`, 34), cell(m.budget, 42), cell('+' + m.growthAvg, 32), cell(m.injuries, 28), cell(m.quits, 28), cell(m.gradPaths.pro, 28), cell(`${m.noticesByTier[1]}/${m.noticesByTier[2]}/${m.noticesByTier[3]}`, 62), cell(m.picksPerWeek, 46), cell(m.minutesPerWeek, 36)));
      });
      bx.append(h('div', { class: 'insight' }, `平均：順位${sm.avgRank}位・成長+${sm.growthAvg}/年・怪我${sm.injuries}件/年・プロ入り${sm.pro}人/年・選ぶ回数${sm.picks}回/週・想定${sm.minutes}分/週（目標は1週8〜10分）`), h('div', { class: 'insight' }, '評価の内訳：' + Object.entries(sm.letters).map(([k, v]) => `${k}×${v}`).join('、') + `／予算の平均${sm.budget}万円／在籍${sm.players}人`));
      const last = st.years[st.years.length - 1];
      bx.append(h('div', { class: 'h', style: 'margin-top:4px' }, `最後の年（${st.years.length}年目）の報告`), ...last.lines.map((l) => h('div', { class: 'note', style: 'color:var(--ink)' }, '・' + l.t)));
      bx.append(h('button', { class: 'btn pri', onclick: () => closeFn() }, '閉じる'));
    };
    next();
  }
  // ---------- 文字の大きさ・お知らせの3段（決定76） ----------
  function fontAndNotices(body) {
    const app = U().app;
    const store = U().store;
    const cur = store.get('fs', 1);
    body.append(h('div', { class: 'h', style: 'margin-top:10px' }, '文字の大きさ'), h('div', { class: 'row', style: 'gap:5px;margin-top:3px' },
      ...YA.FONT_SCALES.map(([name], i) => h('button', { class: 'btn sm' + (cur === i ? ' on' : ''), onclick: () => { store.set('fs', i); YA.applyFontScale(i); rerender(); } }, name))));
    if (!app.w) return;
    const w = app.w;
    w.noticeTier = w.noticeTier || {};
    body.append(h('div', { class: 'h', style: 'margin-top:10px' }, 'お知らせの重さ'), h('div', { class: 'note' }, '項目ごとに選べます。「必ず止める」はおまかせ進行でも止まります。「記録だけ」は出来事の記録にだけ残ります。'));
    const kinds = YA.NOTICE_KINDS.map((x) => x[0]).concat(['そのほか']);
    for (const k of kinds) {
      const t = w.noticeTier[k] || 2;
      body.append(h('div', { class: 'row', style: 'margin:3px 0;gap:4px' }, h('span', { class: 'grow', style: 'font-size:11.5px' }, k),
        ...[1, 2, 3].map((n) => h('button', { class: 'btn sm' + (t === n ? ' on' : ''), onclick: () => { w.noticeTier[k] = n; YA.saveWorld(true); rerender(); } }, YA.NOTICE_TIER_NAME[n]))));
    }
  }

  // ---------- 実績と引退（決定51） ----------
  YA.achBlock = function (body) {
    const app = U().app;
    const w = app.w;
    body.append(h('div', { class: 'h' }, '実績'));
    for (const a of YA.achievements(w)) {
      body.append(h('div', { class: 'pitem', style: 'cursor:default;gap:6px' },
        h('span', { class: 'chip ' + (a.done ? 'trait' : 'gray') }, a.done ? '達成' : '未達'),
        h('span', { class: 'grow', style: 'font-size:12px' }, a.name + (a.goal ? `（${Math.min(a.cur, a.goal)}/${a.goal}）` : '')),
        a.note ? h('span', { class: 'note' }, a.note) : null));
    }
    body.append(h('div', { class: 'h', style: 'margin-top:10px' }, '引退'), h('div', { class: 'note' }, '指導者を引退して、ここまでの歩みをまとめます。引退すると続きは遊べません（書き出しで残せます）。'),
      h('button', { class: 'btn', style: 'margin-top:5px;color:#b02020', onclick: () => confirmBox('指導者を引退しますか', () => { YA.retire(w); YA.saveWorld(true); rerender(); }) }, '引退する'));
  };
  YA.views = YA.views || {};
  YA.views.retired = function (main) {
    const app = U().app;
    const s = YA.careerSummary(app.w);
    const box = h('div', { class: 'card', style: 'margin:10px;padding:12px' });
    box.append(h('div', { class: 'h', style: 'font-size:16px' }, `指導者人生のまとめ（${s.years}年）`));
    box.append(h('div', { class: 'note' }, (app.w.coachName || '指導者') + 'さんの歩み'));
    box.append(h('div', { class: 'insight' }, `プロ入りした卒業生 ${s.pros}人／代表経験者 ${s.nats}人／連帯貢献金 ${s.solid}万円`));
    if (s.best.length) box.append(h('div', { class: 'h', style: 'margin-top:4px' }, '育てた主な子'), ...s.best.map((a) => h('div', { class: 'note', style: 'color:var(--ink)' }, `・${a.name}（${a.pos}・能力${a.ovr.toFixed(1)}・${a.club || ''}）`)));
    if (s.trophies.length) box.append(h('div', { class: 'h', style: 'margin-top:4px' }, '獲ったもの'), ...s.trophies.map((t) => h('div', { class: 'note', style: 'color:var(--ink)' }, `・${t.year || ''}年 ${t.name}`)));
    box.append(h('div', { class: 'h', style: 'margin-top:4px' }, '実績'), ...s.ach.map((a) => h('div', { class: 'note', style: 'color:var(--ink)' }, (a.done ? '◎ ' : '・') + a.name)));
    box.append(h('div', { class: 'row', style: 'margin-top:8px;gap:6px' },
      h('button', { class: 'btn', onclick: exportBox }, 'セーブを書き出す'),
      h('button', { class: 'btn pri', onclick: () => { const st = U().store; st.set(YA.slotKey(app.slot), null); app.w = null; app.ng = null; rerender(); } }, '新しく始める')));
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
      body.append(h('div', { class: 'row', style: 'gap:4px;flex-wrap:wrap;margin-top:3px' }, ...w.lineupB.map((s, i) => { const p = w.players[s.pid]; return h('span', { style: 'display:flex;flex-direction:column;align-items:center;gap:1px' }, h('span', { class: 'note', style: 'font-size:9.5px' }, slotName(s, i)), chip(p, ui.bSel === i, () => { if (ui.bSel == null) ui.bSel = i; else if (ui.bSel === i) ui.bSel = null; else { YA.swapB(w, ui.bSel, s.pid); ui.bSel = null; YA.saveWorld(true); } rerender(); })); })));
      body.append(h('div', { class: 'note', style: 'margin-top:5px' }, '控え'), h('div', { class: 'row', style: 'gap:4px;flex-wrap:wrap;margin-top:3px' }, ...(w.benchB || []).map((id) => w.players[id]).filter(Boolean).map((p) => chip(p, false, () => { if (ui.bSel == null) return; YA.swapB(w, ui.bSel, p.id); ui.bSel = null; YA.saveWorld(true); rerender(); }))));
    }
    const rs = (w.resultsB || []).slice(-8).reverse();
    body.append(h('div', { class: 'h', style: 'margin-top:8px' }, 'Bの最近の結果'), ...(rs.length ? rs.map((r) => h('div', { class: 'note', style: 'color:var(--ink)' }, `${r.year}年目${r.week}週　${r.gf}-${r.ga}　vs ${r.opp}`)) : [h('div', { class: 'note' }, 'まだ試合がありません')]));
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
