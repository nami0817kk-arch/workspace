// 選手を構成する要素 段階7「関係：グループとチームの雰囲気」（2026-11-19 ⑩「4だけ」）
// ・グループ：学年・寮生と自宅生・仲良しの輪（w.circles。学年・寮か自宅か・友達や同室・性格の相性でまとまる）
// ・輪が割れると雰囲気が悪くなる（w.split。A と B に分かれた輪どうし・相性の悪い輪の中心どうし）
// ・主将の性格でまとまりやすさが変わる
// ・チームの雰囲気 w.atmo（0〜100）は試合の力と伸びに少し効く。クラブ → 概要 に「チームの雰囲気」
(function () {
  const YA = globalThis.YA;
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const all = (w) => Object.values(w.players || {});
  const sur = (p) => p.name.split(' ')[0];

  YA.ATMO_WORD = (v) => (v >= 80 ? '最高' : v >= 65 ? '良い' : v >= 50 ? 'ふつう' : v >= 35 ? 'ぎくしゃく' : '悪い');
  // 主将の性格ごとのまとまり（雰囲気の目標に足す・割れにくさ）
  YA.CAP_PERS = { リーダー気質: [6, 0.5], 世話好き: [4, 0.7], 仲間思い: [3, 0.8], お調子者: [2, 1], 寡黙: [0, 1], 人見知り: [-2, 1.2], 短気: [-4, 1.4], 一匹狼: [-5, 1.5] };
  YA.capEffect = function (w) {
    const c = w.captain && w.players[w.captain];
    if (!c) return { v: -3, k: 1.3, why: '主将がいない' };
    const t = (c.pers && c.pers['人との関わり']) || 'ふつう';
    const e = YA.CAP_PERS[t] || [0, 1];
    const ex = c.pers && c.pers['感情の波'] === '短気' ? [-3, 1.2] : [0, 1];
    return { v: e[0] + ex[0], k: e[1] * ex[1], why: `主将 ${c.name}（${t === 'ふつう' ? 'おだやか' : t}）` };
  };

  // ---------- 仲良しの輪 ----------
  function affinity(w, a, b) {
    let s = 0;
    if (a.grade === b.grade) s += 2;
    if ((a.dorm !== false) === (b.dorm !== false)) s += 1;
    for (const x of w.rel || []) if ((x.a === a.id && x.b === b.id) || (x.a === b.id && x.b === a.id)) s += x.k === 'friend' ? 3 : x.k === 'room' ? 2 : x.k === 'samejh' || x.k === 'child' ? 2 : x.k === 'rival' ? -1 : 0.5;
    if (YA.persCompat) s += YA.persCompat(a, b).s * 1.5;
    if (YA.GROUP[a.main] === YA.GROUP[b.main]) s += 0.5;
    return s;
  }
  YA.affinity = affinity;
  const presence = (p) => (YA.ovr ? YA.ovr(p) : 10) + p.grade * 1.5 + (p.pers && /リーダー気質|世話好き|お調子者/.test(Object.values(p.pers).join()) ? 3 : 0) - (p.pers && p.pers['人との関わり'] === '一匹狼' ? 6 : 0);
  YA.makeCircles = function (w) {
    const ps = all(w);
    if (!ps.length) { w.circles = []; return; }
    // 学年ごとに2人ずつ、輪の中心を選ぶ（存在感の大きい子）
    const leads = [];
    for (const g of [1, 2, 3]) leads.push(...ps.filter((p) => p.grade === g).sort((a, b) => presence(b) - presence(a)).slice(0, 2));
    const circles = leads.map((l) => ({ id: 'c' + l.id, lead: l.id, ids: [l.id] }));
    for (const p of ps) {
      if (leads.indexOf(p) >= 0) continue;
      let best = null, bs = -1e9;
      for (const c of circles) { const s = affinity(w, p, w.players[c.lead]) + c.ids.reduce((t, id) => t + affinity(w, p, w.players[id]) * 0.25, 0) / Math.max(1, c.ids.length) - (c.ids.length >= 8 ? 2 : 0); if (s > bs) { bs = s; best = c; } }
      // 一匹狼・相性の悪い子は、どの輪にも入らない
      if (bs < 1.5 || (p.pers && p.pers['人との関わり'] === '一匹狼' && bs < 4)) { p.circle = null; continue; }
      best.ids.push(p.id);
    }
    w.circles = circles.filter((c) => c.ids.length >= 2).map((c) => {
      const ms = c.ids.map((id) => w.players[id]);
      const dorm = ms.filter((p) => p.dorm !== false).length;
      const g = ms.map((p) => p.grade).sort();
      return Object.assign(c, { name: `${sur(w.players[c.lead])}の輪`, kind: dorm >= ms.length * 0.7 ? '寮' : dorm <= ms.length * 0.3 ? '自宅' : '寮と自宅', grade: g[Math.floor(g.length / 2)] });
    });
    for (const p of ps) p.circle = null;
    for (const c of w.circles) for (const id of c.ids) w.players[id].circle = c.id;
    w.circleKey = ps.map((p) => p.id).sort().join(',').length + ':' + ps.length + ':' + w.year;
  };
  YA.circleOf = (w, p) => (w.circles || []).find((c) => c.id === p.circle) || null;

  // 輪どうしのきしみ：中心どうしの相性と、A と B に分かれていること
  YA.tension = function (w, c1, c2) {
    const inA = new Set((w.lineupA || []).map((s) => s.pid));
    const share = (c) => c.ids.filter((id) => inA.has(id)).length / Math.max(1, c.ids.length);
    const l1 = w.players[c1.lead], l2 = w.players[c2.lead];
    const comp = l1 && l2 && YA.persCompat ? YA.persCompat(l1, l2).s : 0;
    return Math.abs(share(c1) - share(c2)) * 3 - comp * 1.5 + (c1.grade === c2.grade ? 0.8 : 0) + (c1.kind !== c2.kind && c1.kind !== '寮と自宅' && c2.kind !== '寮と自宅' ? 0.6 : 0);
  };

  // ---------- 毎週 ----------
  YA.ATMO_START = 60;
  YA.SPLIT_P = 0.08; // 月のはじめに、きしみの大きい輪どうしが割れる割合（主将の性格で上下）
  const ew0 = YA.endWeek;
  YA.endWeek = function (w) {
    const res = ew0.apply(this, arguments);
    try { teamWeek(w); } catch (e) { /* 古い保存 */ }
    return res;
  };
  function teamWeek(w) {
    if (w.atmo == null) w.atmo = YA.ATMO_START;
    const ps = all(w);
    // 顔ぶれが変わったら輪を作り直す（年度はじめ・入団・退団）
    const key = ps.map((p) => p.id).sort().join(',').length + ':' + ps.length + ':' + w.year;
    if (!w.circles || w.circleKey !== key) YA.makeCircles(w);
    const r = YA.rngOf((w.seed | 0) * 23 + w.year * 307 + w.week * 19 + 3);
    const cap = YA.capEffect(w);
    // 割れる・戻る（月のはじめ）
    const first = YA.calendar && YA.calendar(w.week).nth === 1;
    if (w.split && !(w.circles || []).some((c) => c.id === w.split.a) ) w.split = null;
    if (w.split && !(w.circles || []).some((c) => c.id === w.split.b)) w.split = null;
    if (w.split) {
      w.split.w = (w.split.w || 0) + 1;
      // 時間がたつと自然に戻ることもある（主将しだい）
      if (w.split.w >= 3 && r() < 0.3 / cap.k) endSplit(w, '時間がたって');
    } else if (first && (w.circles || []).length >= 2 && !(w.year === 1 && w.week <= 5)) {
      let best = null, bt = 0;
      for (let i = 0; i < w.circles.length; i++) for (let j = i + 1; j < w.circles.length; j++) { const t = YA.tension(w, w.circles[i], w.circles[j]); if (t > bt) { bt = t; best = [w.circles[i], w.circles[j]]; } }
      if (best && bt >= 1.8 && r() < YA.SPLIT_P * cap.k * (bt / 2.5)) {
        w.split = { a: best[0].id, b: best[1].id, y: w.year, s: w.week, w: 0 };
        w.atmo = clamp(w.atmo - 8, 0, 100);
        if (YA.noteTier) YA.noteTier(w, 1, `ロッカーの空気が割れている：「${best[0].name}」と「${best[1].name}」がぎくしゃくしている。雰囲気が悪くなっています（クラブ → 概要 の「チームの雰囲気」）`);
      }
    }
    // 雰囲気の目標と、そこへの寄り方
    const last = (w.results || []).slice(-1)[0];
    const res = last && last.week === w.week && last.year === w.year ? (last.gf > last.ga ? 4 : last.gf < last.ga ? -4 : 0) : 0;
    const inA = (w.lineupA || []).map((s) => w.players[s.pid]).filter(Boolean);
    let comp = 0, n = 0;
    for (let i = 0; i < inA.length; i++) for (let j = i + 1; j < inA.length; j++) { comp += YA.persCompat ? YA.persCompat(inA[i], inA[j]).s : 0; n++; }
    const target = 63 + cap.v + (n ? (comp / n) * 20 : 0) + (w.split ? -12 : 0) + ((w.disc == null ? 60 : w.disc) - 60) * 0.1 + (w.recentForm || 0);
    w.recentForm = clamp((w.recentForm || 0) * 0.8 + res, -10, 10);
    w.atmo = Math.round(clamp(w.atmo + (target - w.atmo) * 0.15, 0, 100) * 10) / 10;
    w.atmoHist = (w.atmoHist || []).concat([Math.round(w.atmo)]).slice(-12);
    if (w.atmo < 40) for (const p of ps) p.unrest = (p.unrest || 0) + 0.08;
  }
  YA.teamWeek = teamWeek;
  function endSplit(w, why) {
    if (!w.split) return;
    w.split = null;
    w.atmo = clamp(w.atmo + 5, 0, 100);
    if (YA.noteTier) YA.noteTier(w, 2, `輪のぎくしゃくがおさまった${why ? '（' + why + '）' : ''}`);
  }
  YA.endSplit = endSplit;
  // 監督が手を打つ（月1回）
  YA.TEAM_ACTS = [
    { k: 'talk', name: '二つの輪の中心と話す', about: '割れている輪の中心の二人と話す。おさまりやすい', p: 0.6, atmo: 4 },
    { k: 'meet', name: 'チーム全員で話す', about: '全員を集めて話す。雰囲気が少し上がり、割れていればおさまることがある', p: 0.35, atmo: 5 },
    { k: 'event', name: '寮と自宅の子を混ぜて食事会', about: 'グループをまたいで食事をする。雰囲気が上がる', p: 0.25, atmo: 6 },
  ];
  YA.teamActWhy = (w) => (w.teamActM === w.year * 100 + (YA.monthIdx ? YA.monthIdx(w.week) : 0) ? 'チームへの働きかけは月1回です。来月またできます' : null);
  YA.teamAct = function (w, k) {
    const why = YA.teamActWhy(w);
    if (why) return { ok: false, msg: why };
    const d = YA.TEAM_ACTS.find((x) => x.k === k);
    w.teamActM = w.year * 100 + (YA.monthIdx ? YA.monthIdx(w.week) : 0);
    w.atmo = clamp((w.atmo == null ? YA.ATMO_START : w.atmo) + d.atmo, 0, 100);
    const r = YA.rngOf((w.seed | 0) * 41 + w.year * 97 + w.week + YA.hash(k));
    let msg = `${d.name}。雰囲気+${d.atmo}`;
    if (w.split && r() < d.p * (YA.capEffect(w).k <= 0.7 ? 1.3 : 1)) { endSplit(w, d.name); msg += '。ぎくしゃくがおさまった'; } else if (w.split) msg += '。まだぎくしゃくは残っている';
    return { ok: true, msg };
  };

  // ---------- 効き目 ----------
  const tf0 = YA.teamFromWorld;
  YA.teamFromWorld = function (w, which) {
    const t = tf0.apply(this, arguments);
    t.atmo = w.atmo == null ? YA.ATMO_START : w.atmo;
    return t;
  };
  YA.atmoMod = (t) => (t && t.atmo != null ? clamp((t.atmo - 60) / 40, -1.5, 1) * 0.6 : 0);
  const gk0 = YA.growK || (() => 1);
  YA.growK = function (p) { return gk0(p) * (YA._atmoNow != null ? 0.97 + YA._atmoNow * 0.0006 : 1); };
  const rt0 = YA.runTraining;
  YA.runTraining = function (w) { YA._atmoNow = w.atmo == null ? YA.ATMO_START : w.atmo; try { return rt0.apply(this, arguments); } finally { YA._atmoNow = null; } };

  // ---------- 見せ方 ----------
  YA.teamCardEl = function (w) {
    const U = YA._ui;
    if (!U) return null;
    const h = U.h;
    if (w.atmo == null) w.atmo = YA.ATMO_START;
    if (!w.circles) YA.makeCircles(w);
    const cap = YA.capEffect(w);
    const v = Math.round(w.atmo);
    const col = v >= 65 ? '#1a9d57' : v >= 50 ? '#7dbf3f' : v >= 35 ? '#f0a020' : '#d63a3a';
    const why = YA.teamActWhy(w);
    const msg = U.app && U.app.teamMsg;
    const split = w.split ? [w.circles.find((c) => c.id === w.split.a), w.circles.find((c) => c.id === w.split.b)].filter(Boolean) : [];
    return h('div', { class: 'card teamcard', style: 'padding:6px 9px;margin:6px 0' },
      h('div', { class: 'h' }, 'チームの雰囲気'),
      h('div', { class: 'row', style: 'gap:6px;margin:3px 0' }, h('b', { style: `color:${col};font-size:15px` }, YA.ATMO_WORD(v)), h('div', { style: 'flex:1;height:7px;border-radius:4px;background:var(--line);overflow:hidden' }, h('div', { style: `width:${v}%;height:100%;background:${col}` })), h('span', { class: 'sub' }, String(v))),
      h('div', { class: 'note' }, `${cap.why}：${cap.v >= 3 ? 'まとまりやすい' : cap.v <= -3 ? 'まとまりにくい' : 'ふつう'}。雰囲気が良いと試合で少し力が出て、伸びも少し良くなります。`),
      split.length === 2 ? h('div', { class: 'note', style: 'color:#8a2a20;font-weight:700' }, `「${split[0].name}」と「${split[1].name}」がぎくしゃくしている`) : null,
      h('div', { class: 'plist', style: 'margin-top:4px' }, (w.circles || []).map((c) => h('div', { class: 'pitem', style: 'cursor:default;gap:6px' + (split.indexOf(c) >= 0 ? ';border-color:#eba79d;background:#fff6f4' : '') }, h('b', { style: 'width:96px;flex:none' }, c.name), h('span', { class: 'sub' }, `高${c.grade}中心・${c.kind}`), h('span', { class: 'grow', style: 'font-size:11px' }, c.ids.map((id) => w.players[id] && sur(w.players[id])).filter(Boolean).join('・'))))),
      (() => { const lone = all(w).filter((p) => !p.circle); return lone.length ? h('div', { class: 'note' }, `どの輪にも入っていない：${lone.map(sur).join('・')}`) : null; })(),
      h('div', { class: 'row', style: 'gap:5px;flex-wrap:wrap;margin-top:4px' }, YA.TEAM_ACTS.map((d) => h('button', { class: 'btn sm', disabled: !!why, why: why || '', title: d.about, onclick: () => { const r = YA.teamAct(w, d.k); if (U.app) U.app.teamMsg = r.msg; if (YA.saveWorld) YA.saveWorld(); U.render(); } }, d.name))),
      msg ? h('div', { class: 'note', style: 'color:var(--ink)' }, msg) : null);
  };
  const pc0 = YA.policyCard;
  YA.policyCard = function (w) {
    const el = pc0 ? pc0.apply(this, arguments) : null;
    const t = YA.teamCardEl(w);
    if (!t) return el;
    const box = YA._ui.h('div', {});
    if (el) box.append(el);
    box.append(t);
    return box;
  };
  const ov0 = YA.playerOverview;
  if (ov0) {
    YA.playerOverview = function (w, p) {
      const el = ov0.apply(this, arguments);
      try {
        if (!w.circles) YA.makeCircles(w);
        const c = YA.circleOf(w, p);
        const doc = el.ownerDocument;
        for (const r of el.querySelectorAll('.ovrow')) {
          const k = r.querySelector('.k');
          if (k && k.textContent === '性格') {
            const row = doc.createElement('div'); row.className = 'ovrow';
            const a = doc.createElement('span'); a.className = 'k'; a.textContent = '仲間';
            const b = doc.createElement('span'); b.className = 'v'; b.textContent = c ? `${c.name}（${c.kind}・${c.ids.length}人）${c.lead === p.id ? '・輪の中心' : ''}` : 'どの輪にも入っていない';
            row.append(a, b);
            r.after(row);
          }
        }
      } catch (e) { /* 形の違う画面 */ }
      return el;
    };
  }
})();
