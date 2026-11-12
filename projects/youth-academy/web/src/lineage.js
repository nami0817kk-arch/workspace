// 2段目「続ける理由」その1（決定133〜135・139・140・147）：系譜タブ（系譜図・名鑑・殿堂・実績・年表）、
// 殿堂の2段、実績66個（5分野・銅銀金）、育成基金。見せ方は下の views の部分（画面を持たない点検では使わない）。
(function () {
  'use strict';
  const YA = (globalThis.YA = globalThis.YA || {});
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

  // ---------- 実績：22の物差し × 銅銀金 = 66個（決定134）----------
  const sum = (al, f) => al.reduce((s, a) => s + f(a), 0);
  const cnt = (al, f) => al.filter(f).length;
  const wcN = (a) => (a.awards || []).filter((x) => /W杯/.test(x.name)).length;
  YA.ACH_FIELDS = ['育成', '試合と大会', '卒業生', 'クラブ', '系譜'];
  YA.ACH_TIERS = ['銅', '銀', '金'];
  // [key, 分野, 名前（{n}に目標の数が入る）, 目標3つ, 数え方]
  const METRICS = [
    ['pro', 0, 'プロ入りした卒業生が{n}人', [5, 15, 40], (w) => cnt(w.alumni, (a) => a.status === 'pro')],
    ['r125', 0, 'J1級（総合力125）に届いた卒業生が{n}人', [1, 5, 15], (w) => cnt(w.alumni, (a) => YA.rate(a.ovr) >= 125)],
    ['r155', 0, '日本代表級（総合力155）に届いた卒業生が{n}人', [1, 3, 8], (w) => cnt(w.alumni, (a) => YA.rate(a.ovr) >= 155)],
    ['grads', 0, '送り出した卒業生が{n}人', [36, 108, 360], (w) => w.alumni.length],
    ['trophy', 1, '大会で優勝を{n}回', [1, 5, 15], (w) => (w.trophies || []).length],
    ['lwin', 1, 'リーグ優勝を{n}回', [1, 3, 8], (w) => (w.leagueHist || []).filter((x) => x.rank === 1).length],
    ['wins', 1, 'Aチームで通算{n}勝', [20, 100, 300], (w) => (w.rec && w.rec.w) || 0],
    ['top1', 1, '1部で戦った年が{n}年', [1, 5, 10], (w) => (w.leagueHist || []).filter((x) => x.level === 1).length],
    ['nat', 2, '代表経験者が{n}人', [1, 5, 15], (w) => cnt(w.alumni, (a) => a.nat > 0)],
    ['abroad', 2, '海外のクラブへ行った卒業生が{n}人', [1, 5, 15], (w) => cnt(w.alumni, (a) => a.abroad)],
    ['u21', 2, 'U-21代表を出す（{n}人）', [1, 3, 10], (w) => cnt(w.alumni, (a) => a.u21 > 0)],
    ['apps', 2, '卒業生のプロでの通算出場が{n}試合', [100, 1000, 5000], (w) => sum(w.alumni, (a) => (a.status === 'pro' ? a.apps : 0))],
    ['titles', 2, '卒業生が獲ったタイトルが{n}個', [1, 10, 40], (w) => sum(w.alumni, (a) => (a.titles || []).length)],
    ['wc', 2, 'W杯に出た卒業生が{n}人', [1, 5, 15], (w) => cnt(w.alumni, (a) => wcN(a) > 0)],
    ['hof', 2, '殿堂入りが{n}人', [1, 3, 8], (w) => cnt(w.alumni, (a) => a.hof === 'full')],
    ['years', 3, '{n}年指導する', [3, 10, 20], (w) => Math.max(0, w.year - 1)],
    ['fund', 3, '育成基金に累計{n}万円', [500, 2000, 7500], (w) => w.fundIn || 0],
    ['fac', 3, '施設レベル{n}', [1, 3, 6], (w) => YA.facilityLevel(w)],
    ['clubs', 3, '{n}つのクラブを指導する', [2, 3, 5], (w) => ((w.club && w.club.careerClubs) || []).length + 1],
    ['long', 4, '10年以上プレーした卒業生が{n}人', [1, 3, 8], (w) => cnt(w.alumni, (a) => (a.seasons || []).length >= 10)],
    ['ret', 4, '現役を引退した卒業生が{n}人', [1, 10, 30], (w) => cnt(w.alumni, (a) => a.retired)],
    ['cand', 4, '殿堂候補になった卒業生が{n}人', [1, 5, 15], (w) => cnt(w.alumni, (a) => !!a.hof)],
  ];
  YA.ACH_COUNT = METRICS.length * 3;
  YA.achievements = function (w) {
    const out = [];
    for (const [k, f, name, goals, fn] of METRICS) {
      const cur = fn(w);
      goals.forEach((g, i) => out.push({ k: k + i, name: name.replace('{n}', g.toLocaleString('en-US')), field: YA.ACH_FIELDS[f], tier: YA.ACH_TIERS[i], cur, goal: g, done: cur >= g }));
    }
    return out;
  };
  // 次に届きそうな実績を1つ（決定134）。進み具合がいちばん大きく、まだ届いていないもの
  YA.nextAchievement = function (w) {
    let best = null;
    for (const a of YA.achievements(w)) {
      if (a.done) continue;
      const r = a.cur / a.goal;
      if (!best || r > best.r) best = { a, r };
    }
    return best ? best.a : null;
  };
  // 新しく届いた実績を知らせる（毎週の進行のあとに呼ぶ）
  YA.achieveCheck = function (w) {
    const seen = (w.achSeen = w.achSeen || {});
    const firstRun = !w.achInit;
    w.achInit = true;
    const got = [];
    for (const a of YA.achievements(w)) {
      if (!a.done || seen[a.k]) continue;
      seen[a.k] = w.year;
      got.push(a);
    }
    if (!firstRun) for (const a of got) YA.noteTier(w, a.tier === '金' ? 1 : 2, `実績「${a.name}」（${a.tier}）に届きました`);
    return got;
  };

  // ---------- 殿堂の2段（決定133）----------
  // 条件に届いた瞬間に「殿堂候補」（銀）。引退のときに生涯の成績で正式に殿堂入り（金）
  const hofScore = YA.hofScore = (a) => (a.nat || 0) * 2 + (a.titles || []).length * 2 + (a.awards || []).length + Math.floor((a.apps || 0) / 150) + (a.abroad ? 1 : 0);
  YA.hofCondition = (a) => a.status === 'pro' && (a.nat > 0 || (a.abroad && a.ovr >= 14.5 && a.apps >= 80) || (a.club && /J1/.test(a.league || '') && a.apps >= 200) || (a.transfers >= 3 && a.ovr >= 14.4));
  YA.hofFull = (a) => hofScore(a) >= 4;
  const HOF_WORDS = ['あの頃から、ひたむきな子でした。', 'いちばん最初に練習に来て、最後まで残る子でした。', '背中を押しただけです。歩いたのは本人です。', '卒業の日の顔を、いまも覚えています。', 'ここから世界へ行ったのだと思うと、誇らしい。'];
  YA.hofWord = (w, a) => HOF_WORDS[(a.name.length + a.year) % HOF_WORDS.length];
  const tickBase = YA.alumniTick;
  YA.alumniTick = function (w) {
    const was = new Set(w.alumni.filter((a) => a.retired).map((a) => a));
    const contrib = tickBase(w);
    for (const a of w.alumni) {
      if (!a.hof && YA.hofCondition(a)) {
        a.hof = 'cand';
        a.hofY = w.year;
        YA.noteTier(w, 2, `卒業生の${a.name}が殿堂候補になりました（${a.club}）`);
      }
      if (a.hof === 'cand' && ((a.retired && !was.has(a) && YA.hofFull(a)) || (!a.retired && a.age >= 31 && hofScore(a) >= 6))) {
        a.hof = 'full';
        a.hofY = w.year;
        YA.noteTier(w, 1, `卒業生の${a.name}が殿堂入りしました。「${YA.hofWord(w, a)}」`);
      }
    }
    YA.achieveCheck(w);
    return contrib;
  };
  const newWorldBase = YA.newWorld;
  YA.newWorld = function (...a) {
    const w = newWorldBase.apply(this, a);
    w.achInit = true; // 新しい世界は最初から知らせる。古いセーブは最初の1回だけ黙って記録する
    return w;
  };

  // ---------- 育成基金（決定135）：連帯貢献金はクラブ予算と別に貯まる。使い道は自分で決める ----------
  YA.FUND_USES = [
    { k: 'facility', name: '施設の建て増し', cost: 800, note: '施設の積み立てが600万円（施設1段ぶん）進みます' },
    { k: 'trip', name: '海外遠征', cost: 600, note: '全員の自信が上がり、★の子との信頼が深まります' },
    { k: 'scout', name: '腕の良いスカウトを雇う', cost: 700, note: '今年は、月ごとに見に行ける回数が1回増えます' },
  ];
  YA.fundUse = function (w, k) {
    const u = YA.FUND_USES.find((x) => x.k === k);
    if (!u) return { ok: false, msg: '使い道がありません' };
    if ((w.fund || 0) < u.cost) return { ok: false, msg: `育成基金が足りません（${u.cost}万円）` };
    w.fund -= u.cost;
    if (k === 'facility') w.club.facPts = (w.club.facPts || 0) + 600;
    else if (k === 'trip') {
      for (const p of Object.values(w.players)) p.conf = clamp((p.conf || 50) + 5, 0, 100);
      for (const p of Object.values(w.players)) if (p.star && YA.addTr) YA.addTr(w, p, 1);
    } else if (k === 'scout') w.scoutPlus = 1;
    (w.fundLog = w.fundLog || []).push({ y: w.year, k, cost: u.cost });
    return { ok: true, msg: `${u.name}に${u.cost}万円を使いました` };
  };
  // 年度はじめ：前の年の連帯貢献金を育成基金へ（予算には入れない）
  const yearStartBase = YA.yearStart;
  YA.yearStart = function (w) {
    const got = (w.club && w.club.solidarity) || 0;
    const add = Math.round(got * 0.5); // 決定：連帯貢献金の5割が基金、残りはクラブ本体へ（予算には入れない）
    if (w.club) w.club.solidarity = 0;
    yearStartBase(w);
    w.fund = (w.fund || 0) + add;
    w.fundIn = (w.fundIn || 0) + add;
    w.club.solidarityLast = add;
    w.scoutPlus = 0;
  };

  // ---------- 系譜図（決定147）：アカデミー長を根にした、横に伸びる木 ----------
  const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
  YA.lineageData = function (w) {
    const years = {};
    for (const a of w.alumni) (years[a.year] = years[a.year] || []).push(a);
    const ys = Object.keys(years).map(Number).sort((a, b) => a - b);
    return { ys, years };
  };
  // mini=true なら名前なしの小窓。戻りは SVG の文字列
  YA.lineageSvg = function (w, opt) {
    const mini = !!(opt && opt.mini);
    const { ys, years } = YA.lineageData(w);
    const colW = mini ? 26 : 150, rowH = mini ? 7 : 19, x0 = mini ? 14 : 70;
    const rows = Math.max(1, ...ys.map((y) => years[y].length));
    const H = rows * rowH + (mini ? 14 : 34);
    const W = x0 + Math.max(1, ys.length) * colW + (mini ? 6 : 30);
    const my = H / 2;
    let s = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}" width="${W}" height="${H}" font-family="sans-serif">`;
    s += `<circle cx="${x0 - (mini ? 8 : 40)}" cy="${my}" r="${mini ? 4 : 11}" fill="#1f6feb"/>`;
    if (!mini) s += `<text x="${x0 - 40}" y="${my + 3}" font-size="9" text-anchor="middle" fill="#fff">長</text>`;
    ys.forEach((y, i) => {
      const x = x0 + i * colW;
      const list = years[y].slice().sort((a, b) => b.ovr - a.ovr);
      s += `<line x1="${i ? x - colW : x0 - (mini ? 8 : 40)}" y1="${my}" x2="${x}" y2="${my}" stroke="#9db4d6" stroke-width="2"/>`;
      list.forEach((a, j) => {
        const yy = my + (j - (list.length - 1) / 2) * rowH;
        const pro = a.status === 'pro';
        const hof = a.hof === 'full', cand = a.hof === 'cand';
        const col = hof ? '#d9a400' : cand ? '#9aa6b8' : pro ? '#1f6feb' : '#c3cedf';
        s += `<line x1="${x}" y1="${my}" x2="${x + (mini ? 8 : 16)}" y2="${yy}" stroke="${col}" stroke-width="${pro ? 2.4 : 1}"/>`;
        const cx = x + (mini ? 10 : 20);
        s += `<circle cx="${cx}" cy="${yy}" r="${mini ? 2 : 4.5}" fill="${col}"${hof || cand ? ` stroke="${hof ? '#a37b00' : '#6b7587'}" stroke-width="1.5"` : ''}/>`;
        if (a.nat > 0) s += `<circle cx="${cx}" cy="${yy}" r="${mini ? 1 : 2}" fill="#ffd34d"/>`;
        if (!mini) s += `<text x="${cx + 8}" y="${yy + 3}" font-size="9" fill="#2b3a55">${esc(a.name.split(' ')[0])}</text>`;
      });
      if (!mini) s += `<text x="${x}" y="${H - 4}" font-size="9" fill="#6b7a93">${y}年目</text>`;
    });
    return s + '</svg>';
  };

  // ---------- 年表（卒業・大会・リーグ・殿堂）----------
  YA.chronicle = function (w) {
    const rows = [];
    for (const x of w.leagueHist || []) rows.push({ y: x.year, t: `${YA.levelNames(w)[x.level - 1]} ${x.rank}位`, k: x.rank === 1 ? 'gold' : '' });
    for (const t of w.trophies || []) rows.push({ y: t.year, t: `${t.name} ${t.rank || ''}`.trim(), k: 'gold' });
    const { ys, years } = YA.lineageData(w);
    for (const y of ys) {
      const al = years[y];
      rows.push({ y, t: `${al.length}人が卒業（プロ入り${al.filter((a) => a.status === 'pro').length}人）`, k: '' });
    }
    for (const a of w.alumni) if (a.hof) rows.push({ y: a.hofY || a.year, t: `${a.name}が殿堂${a.hof === 'full' ? '入り' : '候補に'}`, k: a.hof === 'full' ? 'gold' : '' });
    return rows.sort((a, b) => a.y - b.y);
  };

  // ---------- 見せ方 ----------
  const U = () => YA._ui;
  const V = () => YA._v;
  const h = (...a) => U().h(...a);
  const rerender = () => U().render();
  const svgBox = (svg, scale, tall) => {
    const d = document.createElement('div');
    d.className = 'lin-svg';
    d.style.cssText = `overflow:auto;${tall ? 'flex:1;min-height:0;' : ''}background:#f7f9fd;border-radius:8px`;
    d.innerHTML = svg;
    const el = d.firstChild;
    if (el && scale) { el.setAttribute('width', String(Math.round(el.getAttribute('width') * scale))); el.setAttribute('height', String(Math.round(el.getAttribute('height') * scale))); }
    return d;
  };
  YA.lineageMiniCard = function (w) {
    const na = YA.nextAchievement(w);
    return h('div', { class: 'card', style: 'padding:6px 8px;margin-top:6px' },
      h('div', { class: 'row' }, h('div', { class: 'h grow' }, '系譜'), h('button', { class: 'btn sm', onclick: () => { U().app.tab = 'lineage'; U().app.lt = 'tree'; rerender(); } }, '開く')),
      w.alumni.length ? svgBox(YA.lineageSvg(w, { mini: true }), 1) : h('div', { class: 'note' }, '最初の卒業式のあとに、ここへ枝が伸びます'),
      na ? h('div', { class: 'note', style: 'margin-top:4px' }, `次の実績：${na.name}（${Math.min(na.cur, na.goal)}/${na.goal}）`) : null);
  };
  function achTab(body, w) {
    const ui = U().app;
    ui.af2 = ui.af2 || 0;
    const all = YA.achievements(w);
    body.append(h('div', { class: 'row', style: 'gap:4px;flex-wrap:wrap' }, h('div', { class: 'h grow' }, `実績 ${all.filter((a) => a.done).length}/${all.length}`), ...['すべて'].concat(YA.ACH_FIELDS).map((n, i) => h('button', { class: 'btn sm' + (ui.af2 === i ? ' on' : ''), onclick: () => { ui.af2 = i; rerender(); } }, n))));
    const list = all.filter((a) => !ui.af2 || a.field === YA.ACH_FIELDS[ui.af2 - 1]);
    const tcol = { 銅: '#b5733b', 銀: '#8d99ab', 金: '#d9a400' };
    body.append(h('div', { class: 'plist', style: 'margin-top:5px' }, list.map((a) => h('div', { class: 'pitem', style: 'cursor:default;gap:6px;' + (a.done ? '' : 'opacity:.6') },
      h('span', { class: 'chip', style: `background:${tcol[a.tier]};color:#fff` }, a.tier),
      h('span', { class: 'grow', style: 'font-size:12px' }, a.name),
      h('span', { class: 'note' }, a.done ? '達成' : `${Math.min(a.cur, a.goal)}/${a.goal}`)))));
  }
  function hallTab(body, w) {
    const hof = w.alumni.filter((a) => a.hof).sort((a, b) => (b.hof === 'full') - (a.hof === 'full') || b.ovr - a.ovr);
    body.append(h('div', { class: 'h' }, `殿堂（正式 ${hof.filter((a) => a.hof === 'full').length}人・候補 ${hof.filter((a) => a.hof === 'cand').length}人）`),
      h('div', { class: 'note' }, 'フル代表・J1で長く主力・海外で活躍・大きな移籍に届くと「候補」。引退のときに生涯の成績で正式に殿堂入りします。'));
    body.append(h('div', { class: 'plist', style: 'margin-top:5px' }, hof.map((a) => h('div', { class: 'pitem', style: `cursor:default;align-items:flex-start;gap:6px;border-left:4px solid ${a.hof === 'full' ? '#d9a400' : '#9aa6b8'}` },
      h('span', { class: 'chip', style: `background:${a.hof === 'full' ? '#d9a400' : '#9aa6b8'};color:#fff` }, a.hof === 'full' ? '殿堂入り' : '候補'),
      h('div', { class: 'grow' }, h('b', {}, a.name), h('div', { class: 'note' }, `${a.year}年卒・${a.club}（${a.league}）・通算${a.apps}試合${a.goals}得点・代表${a.nat || 0}・タイトル${(a.titles || []).length}`), a.hof === 'full' ? h('div', { class: 'note', style: 'color:var(--ink)' }, `恩師のひとこと：「${YA.hofWord(w, a)}」`) : null)))));
    if (!hof.length) body.append(h('div', { class: 'note', style: 'margin-top:6px' }, 'まだ殿堂入りした卒業生はいません。'));
  }
  function chronTab(body, w) {
    const rows = YA.chronicle(w);
    body.append(h('div', { class: 'h' }, '年表'), h('div', { class: 'plist', style: 'margin-top:5px' }, rows.map((r) => h('div', { class: 'pitem', style: 'cursor:default;gap:6px' }, h('span', { class: 'sub', style: 'width:54px' }, `${r.y}年目`), h('span', { class: 'grow', style: r.k ? 'font-weight:800;color:#a37b00' : '' }, r.t)))));
    if (!rows.length) body.append(h('div', { class: 'note' }, 'まだ記録はありません。'));
  }
  function treeTab(body, w) {
    const ui = U().app;
    ui.lz = ui.lz || 1;
    body.append(h('div', { class: 'row', style: 'gap:4px' }, h('div', { class: 'h grow' }, `系譜図（${w.alumni.length}人）`), h('button', { class: 'btn sm', onclick: () => { ui.lz = Math.max(0.6, ui.lz - 0.2); rerender(); } }, '－'), h('button', { class: 'btn sm', onclick: () => { ui.lz = Math.min(2, ui.lz + 0.2); rerender(); } }, '＋')),
      h('div', { class: 'note' }, '青い枝はプロ入り。金の丸は代表経験、金の縁は殿堂入り、銀の縁は殿堂候補。'));
    body.append(w.alumni.length ? svgBox(YA.lineageSvg(w), ui.lz, true) : h('div', { class: 'note', style: 'margin-top:6px' }, '最初の卒業式（1年目の終わり）のあとに、ここへ枝が伸びます。'));
  }
  function fundTab(body, w) {
    body.append(h('div', { class: 'h' }, `育成基金 ${w.fund || 0}万円`), h('div', { class: 'note' }, '卒業生の大きな移籍で入る連帯貢献金の半分が貯まります。クラブの予算とは別で、使い道は自分で決めます（赤字にはできません）。'));
    for (const u of YA.FUND_USES) body.append(h('div', { class: 'pitem', style: 'cursor:default;gap:6px;margin-top:4px' }, h('div', { class: 'grow' }, h('b', {}, `${u.name}（${u.cost}万円）`), h('div', { class: 'note' }, u.note)), h('button', { class: 'btn sm', disabled: (w.fund || 0) < u.cost, onclick: () => { const r = YA.fundUse(w, u.k); YA.saveWorld(); rerender(); } }, '使う')));
  }
  function viewLineage(main) {
    const w = U().app.w;
    const ui = U().app;
    ui.lt = ui.lt || 'tree';
    const EXTRA = YA.lineageExtraTabs || [];
    const TABS = [['tree', '系譜図'], ['alumni', '卒業生名鑑'], ['hall', '殿堂'], ['ach', '実績'], ['chron', '年表'], ['fund', '育成基金']].concat(EXTRA.map((x) => [x[0], x[1]]));
    const tabs = h('div', { class: 'tabs', style: 'flex-wrap:wrap;gap:3px;max-width:100%' }, TABS.map(([k, n]) => h('button', { class: 'btn' + (ui.lt === k ? ' on' : ''), onclick: () => { ui.lt = k; rerender(); } }, n)));
    const body = h('div', { class: 'card pbody', style: 'flex:1;min-height:0;display:flex;flex-direction:column' });
    if (ui.lt === 'tree') treeTab(body, w);
    else if (ui.lt === 'hall') hallTab(body, w);
    else if (ui.lt === 'ach') achTab(body, w);
    else if (ui.lt === 'chron') chronTab(body, w);
    else if (ui.lt === 'fund') fundTab(body, w);
    else if (EXTRA.some((x) => x[0] === ui.lt)) EXTRA.find((x) => x[0] === ui.lt)[2](body, w);
    else { ui.mt = 'alumni'; const inner = h('div', { style: 'flex:1;min-height:0;display:flex;flex-direction:column' }); YA.views.more(inner); const card = inner.querySelector('.card'); body.append(card || inner); if (inner.querySelector('.tabs')) inner.querySelector('.tabs').remove(); }
    main.append(h('div', { style: 'flex:1;min-height:0;display:flex;flex-direction:column;gap:6px' }, tabs, body));
  }
  YA.views = YA.views || {};
  YA.views.lineage = viewLineage;
  // ホームの右列に系譜の小窓を足す
  const homeBase = YA.views.home;
  if (homeBase && !homeBase._lin) {
    const home2 = function (main) {
      homeBase(main);
      const right = main.querySelector('.card.pbody[style*="210px"]');
      if (right && U().app.w) right.append(YA.lineageMiniCard(U().app.w));
    };
    home2._lin = true;
    YA.views.home = home2;
  }
})();
