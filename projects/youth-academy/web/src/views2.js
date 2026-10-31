// クラブ運営・スカウト・順位と日程・年度はじめの画面・選手の追加操作・名鑑と記録・映像ミーティング。
(function () {
  'use strict';
  const YA = (globalThis.YA = globalThis.YA || {});
  const U = () => YA._ui;
  const V = () => YA._v;
  const h = (...a) => U().h(...a);
  const W = () => U().app.w;
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const save = () => YA.saveWorld();
  const rerender = () => U().render();

  const meter = (v, color) => h('div', { class: 'bar', style: 'height:9px;width:100%' }, h('i', { style: `width:${clamp(v, 0, 100)}%;background:${color || '#1f6feb'}` }));
  const card = (...k) => h('div', { class: 'card', style: 'padding:9px 11px;margin-bottom:6px' }, ...k);
  const title = (t) => h('div', { class: 'h', style: 'margin-bottom:4px' }, t);

  // ---------- 年度はじめ・契約・指導者の成長（ホームで出す画面）----------
  YA.promptsFor = function () {
    const w = W();
    if (w.pendingContract) return contractModal();
    if (w.pendingCoach) return coachModal();
    if (w.yearIntro) return yearIntroModal();
  };
  function box(inner) {
    return h('div', { class: 'sheet-in', style: 'flex:none;align-self:center;margin:auto;width:min(700px,97%);max-height:96%;padding:12px;gap:7px;overflow:auto' }, ...inner);
  }
  function contractModal() {
    const w = W();
    const last = w.club.eval[w.club.eval.length - 1];
    const refuse = w.club.trust < 30 || (last && last.letter === 'D');
    V().modal(() => box([
      h('div', { class: 'h', style: 'font-size:16px' }, '契約満了：これからのこと'),
      h('div', { class: 'note' }, `直近の評価は ${last ? last.letter : '-'}、信頼度は ${Math.round(w.club.trust)}。` + (refuse ? 'クラブは更新に消極的です。' : 'クラブは更新を前向きに考えています。')),
      h('button', { class: 'btn pri', style: 'padding:9px', disabled: refuse, onclick: () => { YA.renewContract(w); save(); rerender(); } }, `${w.clubName}と契約を更新する（3年）`),
      h('div', { class: 'h', style: 'margin-top:4px' }, '他のクラブからの誘い（移ると、36人を一から知ることになります）'),
      ...w.pendingContract.offers.map((o) => h('button', { class: 'btn', style: 'justify-content:space-between;padding:9px', onclick: () => { YA.moveTo(w, o, '契約満了で移りました。'); save(); rerender(); } }, h('b', {}, o.name), h('span', {}, `${YA.TIER_NAME[o.tier]}・予算およそ${o.budget}万円`))),
    ]));
  }
  function coachModal() {
    const w = W();
    V().modal(() => box([
      h('div', { class: 'h', style: 'font-size:16px' }, '指導者としての成長'),
      h('div', { class: 'note' }, `指導者の経験が積み上がりました（いま${YA.licenseOf(w)}）。伸ばす力を1つ選んでください。`),
      ...YA.COACH_ABS.map(([k, n, note]) => h('button', { class: 'btn', style: 'justify-content:space-between;padding:9px', onclick: () => { w.coach[k] = Math.min(20, w.coach[k] + 1); w.pendingCoach = false; save(); rerender(); } }, h('span', {}, h('b', {}, n), '　', h('span', { class: 'sub', style: 'font-weight:600' }, note)), h('b', {}, `${w.coach[k]} → ${w.coach[k] + 1}`))),
    ]));
  }
  function yearIntroModal() {
    const w = W();
    const c = w.club;
    V().modal((close) => {
      const bx = box([]);
      const draw = () => {
        const lv = YA.trustLevel(w);
        bx.replaceChildren(
          h('div', { class: 'h', style: 'font-size:16px' }, `${w.year}年目の始まり：クラブの目標と、チームの約束事`),
          h('div', { class: 'note' }, `${w.clubName}（${YA.TIER_NAME[c.tier]}・${YA.LEVEL_NAMES[w.league.level - 1]}）。信頼度は${YA.TRUST_NAME[lv]}（${Math.round(c.trust)}）。目標を変えられる数：あと${c.goalChanges}つ`),
          ...c.goals.map((g, i) => h('div', { class: 'card', style: 'padding:4px 10px;display:flex;align-items:center;gap:6px' }, h('span', { class: 'chip trait' }, YA.GOAL_DEF[g.k].label), h('span', { class: 'grow', style: 'font-weight:700' }, YA.goalText(g)), h('button', { class: 'btn sm', disabled: c.goalChanges <= 0, onclick: () => { YA.changeGoal(w, i, -1); draw(); } }, '易しく'), h('button', { class: 'btn sm', disabled: c.goalChanges <= 0, onclick: () => { YA.changeGoal(w, i, 1); draw(); } }, '難しく'))),
          h('div', { class: 'note' }, '難しい目標を達成すると評価が上がります。信頼度が低いと、目標はそのまま受け入れるしかありません。'),
          h('div', { class: 'h', style: 'margin-top:4px' }, `チームの約束事（3つまで：${w.rules.length}）`),
          h('div', { class: 'fm-row' }, YA.RULES.map((r) => h('button', { class: 'btn sm' + (w.rules.indexOf(r) >= 0 ? ' on' : ''), onclick: () => { const i = w.rules.indexOf(r); if (i >= 0) w.rules.splice(i, 1); else if (w.rules.length < 3) w.rules.push(r); draw(); } }, r))),
          h('div', { class: 'note' }, '約束を守ると規律が上がります。違反した子を「約束どおり」に処分すると、規律がより上がります。'),
          h('button', { class: 'btn pri', style: 'padding:9px;margin-top:4px', onclick: () => { w.yearIntro = false; save(); close(); rerender(); } }, 'この1年を始める'),
        );
      };
      draw();
      return bx;
    });
  }

  // ---------- ホームの追加カード（合宿・セレクションの案内）----------
  YA.homeExtra = function () {
    const w = W();
    const s = YA.SCHED(w.week);
    if (w.phase !== 'plan') return null;
    if (s.t === 'camp') {
      const opts = YA.campOptions(w);
      const cur = w.campChoice || 'none';
      return h('div', { class: 'card', style: 'padding:7px 9px;background:#fff7d6' }, h('div', { class: 'h' }, '夏合宿・遠征の週'), ...opts.map((o) => h('button', { class: 'btn sm' + (cur === o.k ? ' on' : ''), style: 'width:100%;justify-content:space-between;margin-top:3px', disabled: !o.ok, onclick: () => { w.campChoice = o.k; save(); rerender(); } }, o.label, h('span', { class: 'sub', style: cur === o.k ? 'color:#fff' : '' }, o.ok ? `費用${o.cost}万` : o.why))));
    }
    if (s.t === 'selection' || s.t === 'internal') return h('div', { class: 'card', style: 'padding:7px 9px;background:#eaf2ff' }, h('div', { class: 'h' }, s.t === 'selection' ? 'セレクションの週' : 'U-15の内部昇格の相談'), h('div', { class: 'note' }, 'クラブ → スカウト で、入れる子を選べます。'), h('button', { class: 'btn sm', onclick: () => { U().app.tab = 'club'; U().app.ct = 'scout'; rerender(); } }, 'スカウトを開く'));
    return null;
  };

  // ---------- クラブ ----------
  const SUBS = [['over', '概要'], ['money', '予算と施設'], ['staff', 'スタッフ'], ['scout', 'スカウト'], ['table', '順位と日程']];
  function viewClub(main) {
    const w = W();
    const ui = U().app;
    ui.ct = ui.ct || 'over';
    const tabs = h('div', { class: 'tabs', style: 'flex:none' }, SUBS.map(([k, n]) => h('button', { class: 'btn' + (ui.ct === k ? ' on' : ''), onclick: () => { ui.ct = k; rerender(); } }, n)));
    const body = h('div', { class: 'card pbody', style: 'flex:1;min-height:0' });
    ({ over: over, money: money, staff: staff, scout: scout, table: table })[ui.ct](body, w);
    main.append(h('div', { style: 'flex:1;min-height:0;display:flex;flex-direction:column;gap:6px' }, tabs, body));
  }

  function over(body, w) {
    const c = w.club;
    const lv = YA.trustLevel(w);
    const rank = YA.myRank(w);
    const ps = Object.values(w.players).filter((p) => p.sum0 != null);
    const avg = ps.length ? ps.reduce((s, p) => s + (YA.abSum(p) - p.sum0), 0) / ps.length : 0;
    const g1 = Object.values(w.players).filter((p) => p.grade === 1).reduce((s, p) => s + (p.minsA || 0), 0);
    const left = h('div', { style: 'flex:1;min-width:0' });
    left.append(
      card(h('div', { class: 'row' }, h('b', { class: 'grow' }, w.clubName), h('span', { class: 'chip gray' }, `${YA.TIER_NAME[c.tier]} / ${YA.LEVEL_NAMES[w.league.level - 1]}`)),
        h('div', { class: 'note', style: 'margin-top:5px' }, `クラブからの信頼度：${YA.TRUST_NAME[lv]}（${Math.round(c.trust)}）`), meter(c.trust, c.trust >= 70 ? '#1a9d57' : c.trust >= 40 ? '#1f6feb' : '#d63a3a'),
        h('div', { class: 'note', style: 'margin-top:5px' }, `クラブの評判：${Math.round(c.rep)}`), meter(c.rep, '#e6a800'),
        h('div', { class: 'note', style: 'margin-top:6px' }, `契約：あと${c.contract.left}年 ／ 指導者 ${YA.licenseOf(w)}（教える${w.coach.teach}・見る目${w.coach.eye}・話す${w.coach.talk}・戦術${w.coach.tactic}）`),
        h('div', { class: 'note' }, '信頼度が高いと、スタッフと予算の配分を自分で決められます。低いとクラブが決めます。'),
        h('div', { class: 'row', style: 'margin-top:5px' }, h('span', { class: 'note grow' }, '解任'), h('button', { class: 'btn sm' + (c.noFire ? ' on' : ''), disabled: !(w.year === 1 && w.week <= 2), onclick: () => { c.noFire = !c.noFire; save(); rerender(); } }, c.noFire ? '解任なし' : '解任あり'), h('span', { class: 'sub', style: 'font-size:10px' }, '最初の2週だけ切り替えられます'))),
      card(title(`今年の目標（${w.year}年目）`),
        ...c.goals.map((g) => {
          const now = g.k === 'result' ? `いま${rank}位` : g.k === 'develop' ? `いま平均+${avg.toFixed(1)}` : `いま${Math.round(g1)}分`;
          return h('div', { class: 'row', style: 'padding:3px 0' }, h('span', { class: 'chip trait' }, YA.GOAL_DEF[g.k].label), h('span', { class: 'grow', style: 'font-size:11.5px' }, YA.goalText(g)), h('span', { class: 'sub' }, now));
        })));
    const right = h('div', { style: 'flex:1;min-width:0' });
    right.append(card(title('評価の履歴'), ...(c.eval.length ? c.eval.slice().reverse().map((e) => h('div', { class: 'row', style: 'padding:3px 0' }, h('span', { class: 'chip ' + (e.letter <= 'A' ? 'trait' : 'gray'), style: 'font-size:13px;min-width:26px;justify-content:center' }, e.letter), h('span', { class: 'sub' }, `${e.year}年目`), h('span', { class: 'grow', style: 'font-size:11px' }, e.goals.map((g) => `${g.label}${g.ok ? '○' : g.score ? '△' : '×'}`).join(' ')), h('span', { class: 'sub' }, `${e.rank}位`))) : [h('div', { class: 'note' }, 'まだ評価はありません（年度末に出ます）')])),
      card(title('クラブの要望・約束'), h('div', { class: 'note' }, c.reqYoung > 0 ? `若手を使う約束があと${c.reqYoung}週ある` : '今は特にありません。要望は出来事として届きます。')));
    body.append(h('div', { style: 'display:flex;gap:8px;align-items:flex-start' }, left, right));
  }

  function money(body, w) {
    const c = w.club;
    const b = YA.budget(w);
    const lv = YA.trustLevel(w);
    const info = { low: '信頼度が低いので、配分はクラブが決めています（要望を出せるだけ）', mid: '信頼度が中くらいなので、スカウトと遠征の配分だけ変えられます', high: '信頼度が高いので、配分を自分で決められます' }[lv];
    const left = h('div', { style: 'flex:1;min-width:0' });
    left.append(card(h('div', { class: 'row' }, h('b', { class: 'grow' }, `今年の予算 ${b.total}万円`), h('span', { class: 'chip gray' }, `連帯貢献金 ${c.solidarityLast || 0}万円を含む`)),
      h('div', { class: 'note' }, `スタッフの給料 ${b.salaries}万円 → 残り ${b.free}万円を配分`), h('div', { class: 'note', style: 'color:var(--blue-d);margin-top:3px' }, info)));
    for (const [k, n, note] of [['scout', 'スカウト', '候補の報告が増え、見に行ける'], ['camp', '合宿・遠征', '夏の合宿（26週）に使う'], ['facility', '施設・寮', '積み立てて寮の定員と回復力が上がる']]) {
      const can = YA.canAlloc(w, k);
      const inp = h('input', { type: 'range', min: 0, max: 60, value: c.alloc[k], disabled: !can, style: 'flex:1' });
      const lab = h('b', { style: 'width:62px;text-align:right' }, `${b[k]}万`);
      inp.addEventListener('input', () => { YA.setAlloc(w, k, +inp.value); lab.textContent = YA.budget(w)[k] + '万'; });
      inp.addEventListener('change', () => { save(); rerender(); });
      left.append(card(h('div', { class: 'row' }, h('b', { style: 'width:72px' }, n), inp, h('span', { class: 'sub', style: 'width:34px' }, c.alloc[k] + '%'), lab), h('div', { class: 'note' }, note + (can ? '' : '（変更不可）'))));
    }
    const dorm = Object.values(w.players).filter((p) => p.dorm).length;
    const fl = YA.facilityLevel(w);
    const right = h('div', { style: 'flex:1;min-width:0' });
    right.append(card(title('施設と寮'), h('div', { class: 'note' }, `施設レベル ${fl}（積み立て ${Math.round(c.facPts)}万円／600万円で次のレベル）`), meter(((c.facPts || 0) % 600) / 6, '#16a34a'),
      h('div', { class: 'note', style: 'margin-top:6px' }, `寮：${dorm}人 / 定員${YA.dormCap(w)}人（残り${YA.dormCap(w) - dorm}）`), h('div', { class: 'note' }, '寮生は体を作りやすいがホームシックがある。自宅生は家庭の出来事と通学の疲れがある。'),
      h('div', { class: 'note', style: 'margin-top:6px' }, `今年の合宿費：${c.spent.camp || 0}万 / ${b.camp}万。スカウトの経費：${c.spent.scout || 0}万 / ${b.scout}万`)));
    body.append(h('div', { style: 'display:flex;gap:8px;align-items:flex-start' }, left, right));
  }

  function staff(body, w) {
    const c = w.club;
    const left = h('div', { style: 'flex:1;min-width:0' });
    left.append(title(`いまのスタッフ（給料の合計 ${c.staff.reduce((s, x) => s + x.salary, 0)}万円）`));
    for (const role of YA.ROLES_STAFF) {
      const s = c.staff.find((x) => x.role === role);
      left.append(card(h('div', { class: 'row' }, h('span', { class: 'chip pers', style: 'min-width:78px;justify-content:center' }, role), s ? h('b', { class: 'grow' }, s.name + (s.ob ? '（OB）' : '')) : h('span', { class: 'grow sub' }, '不在'), s ? h('span', { class: 'chip trait' }, '能力 ' + s.ab) : null, s ? h('span', { class: 'sub' }, s.salary + '万') : null), h('div', { class: 'note' }, YA.STAFF_NOTE[role])));
    }
    const right = h('div', { style: 'flex:1;min-width:0' });
    const lv = YA.trustLevel(w);
    const left2 = YA.staffChangesLeft(w);
    right.append(title('スタッフ候補'), h('div', { class: 'note', style: 'margin-bottom:5px' }, lv === 'low' ? '信頼度が低いので、スタッフはクラブが決めます' : lv === 'mid' ? `信頼度が中くらいなので、今年あと${left2}人だけ入れ替えられます` : '信頼度が高いので、自由に入れ替えられます'));
    const msg = h('div', { class: 'msglog' });
    for (const m of w.market) right.append(card(h('div', { class: 'row' }, h('span', { class: 'chip pers', style: 'min-width:78px;justify-content:center' }, m.role), h('b', { class: 'grow' }, m.name + (m.ob ? '（OB）' : '')), h('span', { class: 'chip trait' }, '能力 ' + m.ab), h('span', { class: 'sub' }, m.salary + '万'), h('button', { class: 'btn sm', disabled: left2 <= 0, onclick: () => { const r = YA.hire(w, m.id); if (r.ok) { save(); rerender(); } else { msg.replaceChildren(h('div', {}, r.msg)); } } }, '採用'))));
    right.append(msg);
    body.append(h('div', { style: 'display:flex;gap:8px;align-items:flex-start' }, left, right));
  }

  // ---------- スカウト ----------
  function candCard(w, c, actions) {
    const v = YA.candView(w, c);
    return h('div', { class: 'card', style: 'padding:7px 9px;margin-bottom:5px' },
      h('div', { class: 'row' }, h('span', { class: 'pos ' + v.pos }, v.label || v.pos), YA.faceEl(w, c.p, 28), h('b', { class: 'grow' }, v.name), h('span', { class: 'chip gray' }, YA.CAND_KIND[c.kind]), c.rival && c.status === 'open' ? h('span', { class: 'fit bad' }, YA.rivalLabel(w, c)) : null, v.nation ? h('span', { class: 'chip trait' }, v.nation) : null),
      h('div', { class: 'row', style: 'flex-wrap:wrap;gap:5px;margin-top:3px' }, h('span', { class: 'chip trait' }, `能力 ${v.ovr[0]}〜${v.ovr[1]}`), h('span', { class: 'chip gray' }, '伸びしろ ', YA.starsEl(v.stars)), h('span', { class: 'chip gray' }, `${v.height}cm`), v.traits ? (v.traits.length ? v.traits.map((t) => h('span', { class: 'chip trait' }, t)) : h('span', { class: 'sub' }, '特性なし')) : h('span', { class: 'sub' }, '特性：?'), v.pers ? Object.values(v.pers).filter((x) => x !== 'ふつう').slice(0, 4).map((x) => h('span', { class: 'chip pers' }, x)) : h('span', { class: 'sub' }, '性格：?')),
      h('div', { class: 'row', style: 'margin-top:4px' }, h('span', { class: 'sub grow' }, '見えている度合い：' + '●'.repeat(c.seen) + '○'.repeat(3 - c.seen)), c.rival && (c.status === 'open' || c.status === 'offered') && !c.rivalBeat ? h('button', { class: 'btn sm', onclick: () => { const r = YA.rivalFight(w, c.id); if (r.ok) { save(); rerender(); } } }, '先に会う（15万）') : null, c.rivalBeat && c.status !== 'signed' ? h('span', { class: 'chip trait' }, '先に会った') : null, actions));
  }
  function scout(body, w) {
    const S = w.scouting;
    const msg = h('div', { class: 'msglog' });
    const say = (r) => { msg.replaceChildren(h('div', {}, r.msg)); if (r.ok) { save(); rerender(); } };
    const b = YA.budget(w);
    const signed = S.cands.filter((c) => c.status === 'signed' || c.status === 'offered');
    body.append(h('div', { class: 'row', style: 'flex-wrap:wrap;gap:6px;margin-bottom:6px' }, h('span', { class: 'chip trait' }, `${w.firstSel ? '今年の高1' : '来年の入団予定'} ${signed.length}/12人`), h('span', { class: 'chip gray' }, `スカウト経費 ${w.club.spent.scout || 0}/${b.scout}万`), h('span', { class: 'chip gray' }, `見る目 ${Math.round(YA.eyeLevel(w))}`), h('span', { class: 'sub grow' }, '足りない分は一般入団で埋まります。内部昇格8人 → スカウト3人 → セレクション3人の順に決めます（合わせて12人まで）')));
    const sec = (t, k, list, mk) => { body.append(title(t)); if (!list.length) body.append(h('div', { class: 'note', style: 'margin-bottom:6px' }, k)); list.forEach((c) => body.append(mk(c))); };
    // 内部昇格
    if (S.intOpen) sec('U-15の内部昇格の候補（申し送り：性格と今の力がある程度わかる）', '', S.cands.filter((c) => c.kind === 'int'), (c) => candCard(w, c, c.status === 'signed' ? h('button', { class: 'btn sm on', onclick: () => { YA.unsign(w, c.id); save(); rerender(); } }, '昇格させる（取り消す）') : h('button', { class: 'btn sm', disabled: c.status !== 'open', onclick: () => say(YA.signCand(w, c.id)) }, '昇格させる')));
    // スカウトの報告
    sec('スカウトの報告（見に行くと、見える範囲が広がります）', 'まだ候補はいません。4週ごとに報告が届きます（4〜32週）', S.cands.filter((c) => c.kind === 'scout' && c.status !== 'declined' || (c.kind === 'scout' && c.status === 'declined')), (c) => candCard(w, c, h('div', { class: 'row' },
      c.status === 'declined' ? h('span', { class: 'fit bad' }, '断られた') : null,
      c.status === 'signed' ? h('span', { class: 'fit good' }, '入団決定') : null,
      c.status === 'offered' ? h('button', { class: 'btn sm on', onclick: () => { YA.unsign(w, c.id); save(); rerender(); } }, w.firstSel ? '声をかけた（返事は決めるとき）' : '声をかけた（返事は来週）') : null,
      c.status === 'open' ? h('button', { class: 'btn sm', onclick: () => say(YA.scoutVisit(w, c.id)) }, '見に行く（15万）') : null,
      c.status === 'open' ? h('button', { class: 'btn sm pri', onclick: () => say(YA.signCand(w, c.id)) }, '声をかける') : null)));
    // セレクション
    if (S.selOpen) {
      const tests = h('div', { class: 'card', style: 'padding:7px 9px;margin-bottom:5px;background:#eaf2ff' });
      const picked = S.testsPick || [];
      tests.append(h('div', { class: 'h' }, `セレクション：テストの内容を決める（${YA.testDays(w)}つまで）`));
      if (S.testsDone) tests.append(h('div', { class: 'note' }, `実施済み：${S.tests.join('・')}。見える情報が増えました`));
      else {
        tests.append(h('div', { class: 'fm-row', style: 'margin:4px 0' }, YA.TESTS.map(([k, n]) => h('button', { class: 'btn sm' + (picked.indexOf(k) >= 0 ? ' on' : ''), onclick: () => { const i = picked.indexOf(k); if (i >= 0) picked.splice(i, 1); else if (picked.length < YA.testDays(w)) picked.push(k); S.testsPick = picked; rerender(); } }, k, h('span', { class: 'sub', style: 'font-weight:600;font-size:9.5px' }, n)))));
        tests.append(h('button', { class: 'btn pri sm', disabled: !picked.length, onclick: () => { YA.runSelection(w, picked); save(); rerender(); } }, 'セレクションを実施する'));
      }
      body.append(tests);
      sec(`セレクションの応募者（${S.cands.filter((c) => c.kind === 'sel').length}人）`, '', S.cands.filter((c) => c.kind === 'sel'), (c) => candCard(w, c, c.status === 'signed' ? h('button', { class: 'btn sm on', onclick: () => { YA.unsign(w, c.id); save(); rerender(); } }, '合格（取り消す）') : h('button', { class: 'btn sm', disabled: c.status !== 'open', onclick: () => say(YA.signCand(w, c.id)) }, '合格にする')));
    }
    body.append(msg);
  }

  // ---------- 順位と日程 ----------
  function table(body, w) {
    const rows = YA.standings(w);
    const L = w.league;
    const left = h('div', { style: 'flex:1.3;min-width:0' });
    left.append(title(`${YA.LEVEL_NAMES[L.level - 1]}　${w.year}年目（${L.done}/22節）`));
    left.append(h('div', { class: 'pitem', style: 'background:none;font-size:10px;color:var(--sub);font-weight:800' }, h('span', { style: 'width:20px' }, '順'), h('span', { class: 'grow' }, 'チーム'), ...['勝', '分', '敗', '得失', '点'].map((x) => h('span', { style: 'width:32px;text-align:right' }, x))));
    for (const r of rows) left.append(h('div', { class: 'pitem', style: 'cursor:default;' + (r.me ? 'background:#fff7d6;border-color:#f0cf55' : '') }, h('b', { style: 'width:20px' }, r.rank), YA.emblemEl(w, r.name, 16), h('span', { class: 'nm grow', style: 'overflow:hidden;text-overflow:ellipsis;white-space:nowrap' }, r.name), ...[r.w, r.d, r.l, r.gd, r.p].map((x, i) => h(i === 4 ? 'b' : 'span', { style: 'width:32px;text-align:right' }, x))));
    left.append(h('div', { class: 'note', style: 'margin-top:4px' }, '上位2チームは翌年に一つ上のリーグへ、下位2チームは一つ下のリーグへ。'));
    const right = h('div', { style: 'flex:1;min-width:0' });
    const cupRow = (name, c) => h('div', { class: 'row', style: 'padding:3px 0' }, h('b', { style: 'width:104px' }, name), h('span', { class: 'grow' }, c.result ? c.result : c.alive ? (c.round ? `${c.round}回戦を突破中` : 'これから') : ''));
    right.append(card(title('大会'), cupRow('夏の全国大会', w.cup.summer), cupRow('冬のカップ戦', w.cup.winter), h('div', { class: 'note' }, '負けたら終わりのトーナメントです（10〜12週・27〜30週）。')));
    right.append(card(title('今年の日程'), h('div', { class: 'note', style: 'line-height:1.7' }, '1〜9週 リーグ前半／10〜12週 夏の全国大会／13〜25週 リーグ後半／26週 夏合宿・遠征／27〜30週 冬のカップ戦／33週 セレクション／34週 中3の練習参加／36週 U-15の内部昇格／40週 卒業式')));
    right.append(card(title('通算の対戦成績'), ...(Object.keys(w.h2h || {}).length ? Object.entries(w.h2h).slice(-6).map(([n, v]) => h('div', { class: 'row', style: 'padding:2px 0;font-size:11px' }, h('span', { class: 'grow' }, n), h('span', { class: 'sub' }, `${v[0]}勝${v[1]}分${v[2]}敗`))) : [h('div', { class: 'note' }, 'まだありません')])));
    body.append(h('div', { style: 'display:flex;gap:8px;align-items:flex-start' }, left, right));
  }

  // ---------- 選手の追加操作 ----------
  YA.playerExtras = function (w, sel) {
    const wrap = h('div', { style: 'margin-top:8px;border-top:1px dashed var(--line);padding-top:6px' });
    const msg = h('div', { class: 'msglog' });
    const say = (t) => { msg.replaceChildren(h('div', {}, t)); save(); };
    wrap.append(h('div', { class: 'h' }, 'チームでの役割'));
    wrap.append(h('div', { class: 'row', style: 'flex-wrap:wrap;gap:4px;margin:4px 0' },
      h('span', { class: 'chip gray' }, sel.dorm ? '寮生' : '自宅生'),
      h('button', { class: 'btn sm' + (w.captain === sel.id ? ' on' : ''), onclick: () => { say(YA.setCaptain(w, sel.id, 'captain')); rerender(); } }, w.captain === sel.id ? 'キャプテン' : 'キャプテンにする'),
      h('button', { class: 'btn sm' + (w.vice === sel.id ? ' on' : ''), onclick: () => { say(YA.setCaptain(w, sel.id, 'vice')); rerender(); } }, w.vice === sel.id ? '副キャプテン' : '副キャプテンにする'),
      sel.nat ? h('span', { class: 'chip trait' }, `代表 ${sel.nat}回`) : null));
    // ポジション変更（15個から選ぶ。向いていない位置にも変えられる）
    const POSG = [['守備', ['CB', 'LB', 'RB', 'LWB', 'RWB']], ['中盤', ['DM', 'CM', 'LM', 'RM', 'AM']], ['攻撃', ['LW', 'RW', 'SS', 'ST']]];
    wrap.append(h('div', { class: 'row', style: 'flex-wrap:wrap;gap:4px;margin:4px 0' }, h('span', { class: 'sub' }, `登録：${YA.POS_LABEL[sel.main]}／向いているポジション：` + (sel.bestKnown || sel.pos === 'GK' ? YA.POS_LABEL[sel.best] : '？（見る目や試合で分かってきます）')), sel.adapt > 0 ? h('span', { class: 'fit bad' }, `慣れるまで${sel.adapt}週`) : null));
    if (sel.pos !== 'GK') for (const [gn, list] of POSG) wrap.append(h('div', { class: 'row', style: 'flex-wrap:wrap;gap:3px;margin:2px 0' }, h('span', { class: 'sub', style: 'width:30px' }, gn), list.filter((x) => x !== sel.main).map((x) => h('button', { class: 'btn sm', style: 'padding:2px 7px', onclick: () => { const r = YA.changePos(w, sel.id, x); say(r.msg); rerender(); } }, YA.POS_LABEL[x]))));
    // 関係
    const rel = YA.relOf(w, sel.id);
    if (rel.length) wrap.append(h('div', { class: 'row', style: 'flex-wrap:wrap;gap:4px' }, h('span', { class: 'sub' }, '関係：'), rel.map((x) => h('span', { class: 'chip ' + (x.k === 'friend' ? 'trait' : 'instr') }, (x.k === 'friend' ? '仲良し ' : 'ライバル ') + x.other.name.split(' ')[0]))));
    wrap.append(h('div', { class: 'row', style: 'margin-top:4px' }, h('button', { class: 'btn sm', onclick: () => YA.renameBox(sel) }, '名前を変える')));
    wrap.append(msg);
    return wrap;
  };

  // ---------- 映像ミーティング（試合のあと）----------
  YA.videoButton = function (m) {
    const w = W();
    return h('button', { class: 'btn', onclick: () => {
      const opts = YA.videoOptions(w, m);
      V().modal((close) => {
        const picks = [];
        const bx = box([]);
        const draw = (done) => {
          bx.replaceChildren(
            h('div', { class: 'h', style: 'font-size:15px' }, '映像ミーティング：取り上げる場面を2つまで'),
            h('div', { class: 'note' }, '成功の場面を褒めると自信が上がります。失敗の場面は課題が見えて戦術の理解が伸びますが、自信が下がることもあります（性格しだい）。'),
            ...(done ? done.map((t) => h('div', { class: 'insight' }, t)) : opts.map((o) => { const p = w.players[o.pid]; const on = picks.indexOf(o) >= 0; return h('button', { class: 'btn' + (on ? ' on' : ''), style: 'justify-content:flex-start;text-align:left;gap:8px', onclick: () => { if (on) picks.splice(picks.indexOf(o), 1); else if (picks.length < 2) picks.push(o); draw(); } }, h('span', { class: 'chip ' + (o.good ? 'trait' : 'instr') }, o.good ? '成功' : '課題'), h('b', {}, o.minute + "'"), h('span', {}, `${p ? p.num + '番 ' + p.name.split(' ')[0] : ''}：${o.text}`)); })),
            done ? h('button', { class: 'btn pri', onclick: () => { close(); rerender(); } }, '閉じる') : h('div', { class: 'row' }, h('button', { class: 'btn', onclick: close }, 'やめる'), h('button', { class: 'btn pri', disabled: !picks.length, onclick: () => { m.videoDone = true; const r = YA.videoApply(w, picks); save(); draw(r); } }, 'この場面を共有する')),
          );
        };
        draw();
        return bx;
      });
    } }, '映像ミーティング');
  };

  // ---------- ほか：名鑑・記録・設定 ----------
  function viewMore(main) {
    const w = W();
    const ui = U().app;
    ui.mt = ui.mt || 'alumni';
    const tabs = h('div', { class: 'tabs', style: 'width:420px' }, [['alumni', '卒業生名鑑'], ['rec', '記録'], ['bteam', 'Bチーム'], ['ach', '実績と引退'], ['set', '設定']].map(([k, n]) => h('button', { class: 'btn' + (ui.mt === k ? ' on' : ''), onclick: () => { ui.mt = k; rerender(); } }, n)));
    const body = h('div', { class: 'card pbody', style: 'flex:1;min-height:0' });
    if (ui.mt === 'alumni') {
      body.append(h('div', { class: 'h' }, `卒業生と退団者（${w.alumni.length}人）`));
      const al = w.alumni.slice().reverse();
      body.append(h('div', { class: 'plist', style: 'margin-top:5px' }, al.map((a) => h('div', { class: 'pitem', style: 'cursor:default;align-items:flex-start' }, h('span', { class: 'pos ' + a.pos }, a.pos), h('div', { class: 'grow' }, h('b', {}, a.name), h('div', { class: 'note' }, (a.status === 'left' ? '退団' : `${a.year}年卒・${a.age}歳`) + (a.club ? `・${a.club}` : '') + (a.u21 ? `・U-21代表${a.u21}回` : '') + (a.nat ? `・代表${a.nat}回` : '') + (a.retired ? '（引退）' : ''))), a.status === 'pro' ? h('span', { class: 'sub', style: 'font-size:10.5px' }, `出場${a.apps}・${a.goals}得点${a.transfers ? '・移籍' + a.transfers : ''}${a.nat ? '・代表' + a.nat : ''}`) : null, h('span', { class: 'chip gray' }, '能力 ' + a.ovr), h('span', { class: 'chip ' + (a.status === 'pro' ? 'trait' : 'gray') }, a.status === 'pro' ? 'プロ' : a.status === 'univ' ? '大学' : a.status === 'left' ? '退団' : '社会人')))));
      if (!al.length) body.append(h('div', { class: 'note', style: 'margin-top:6px' }, '最初の卒業式（1年目の終わり）で、ここに並びます。卒業後も毎年、活躍が更新されます。'));
    } else if (ui.mt === 'rec') {
      body.append(title('主な記録'), h('div', { class: 'row', style: 'flex-wrap:wrap;gap:5px;margin-bottom:6px' }, h('span', { class: 'chip trait' }, `Aチーム ${w.rec.w}勝${w.rec.d}分${w.rec.l}敗`), h('span', { class: 'chip gray' }, `プロ入り ${w.alumni.filter((a) => a.status === 'pro').length}人`), h('span', { class: 'chip gray' }, `代表経験 ${w.alumni.filter((a) => a.nat).length}人`), h('span', { class: 'chip gray' }, `連帯貢献金 ${w.club.solidarityLast || 0}万円（今年）`)));
      body.append(title('獲得した大会'), ...(w.trophies && w.trophies.length ? w.trophies.map((t) => h('div', { class: 'pitem', style: 'cursor:default' }, h('span', { class: 'chip trait' }, t.rank), h('span', { class: 'nm grow' }, t.name), h('span', { class: 'sub' }, `${t.year}年目`))) : [h('div', { class: 'note' }, 'まだありません')]));
      body.append(title('リーグの履歴'), ...((w.leagueHist || []).slice().reverse().map((x) => h('div', { class: 'pitem', style: 'cursor:default' }, h('span', { class: 'sub', style: 'width:54px' }, `${x.year}年目`), h('span', { class: 'nm grow' }, YA.LEVEL_NAMES[x.level - 1]), h('b', {}, `${x.rank}位（勝点${x.pts}）`)))));
      body.append(title('最近の試合'), ...w.results.slice(-10).reverse().map((r) => h('div', { class: 'pitem', style: 'cursor:default' }, h('span', { class: 'sub', style: 'width:68px' }, `${r.year}年目${r.week}週`), h('span', { class: 'nm grow' }, (r.kind ? r.kind + ' ' : '') + r.opp), h('b', { style: `color:${r.gf > r.ga ? '#1a9d57' : r.gf < r.ga ? '#d63a3a' : 'inherit'}` }, `${r.gf}-${r.ga}`))));
    } else if (ui.mt === 'bteam') {
      YA.bBlock(body);
    } else if (ui.mt === 'ach') {
      YA.achBlock(body);
    } else if (typeof YA.settingsBlock === 'function') {
      YA.settingsBlock(body);
    } else {
      body.append(h('div', { class: 'h' }, '設定'));
      body.append(h('div', { class: 'row', style: 'margin:6px 0' }, h('span', { class: 'grow' }, '試合の自動停止（前半終了・得点・失点・残り15分）'), h('button', { class: 'btn sm' + (ui.autoStop ? ' on' : ''), onclick: () => { ui.autoStop = !ui.autoStop; U().store.set('autoStop', ui.autoStop); rerender(); } }, ui.autoStop ? 'ON' : 'OFF')));
      body.append(h('div', { class: 'h', style: 'margin-top:12px' }, '最初からやり直す'), h('div', { class: 'note' }, '36人も成績も消えて、新しい世界が始まります。'), h('button', { class: 'btn', style: 'margin-top:5px;color:#b02020', onclick: () => V().modal((close) => h('div', { class: 'sheet-in', style: 'flex:none;align-self:center;margin:auto;width:min(420px,95%);padding:12px;gap:8px' }, h('div', { class: 'h' }, '本当に最初からやり直しますか'), h('div', { class: 'row' }, h('button', { class: 'btn', onclick: close }, 'やめる'), h('button', { class: 'btn pri', onclick: () => { ui.w = YA.newWorld((Date.now() % 90000) + 7); ui.view = 'pre'; ui.pSel = null; ui.tab = 'home'; save(); close(); rerender(); } }, 'やり直す')))) }, '最初からやり直す'));
    }
    main.append(h('div', { style: 'flex:1;min-height:0;display:flex;flex-direction:column;gap:6px' }, tabs, body));
  }

  YA.views = Object.assign(YA.views || {}, { club: viewClub, more: viewMore });
})();
