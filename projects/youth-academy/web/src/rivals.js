// 2段目「続ける理由」その2（決定30・117〜120・149）：名物のライバル監督、トップ監督の注文、クラブ移籍。
// 画面は系譜タブの追加の小タブ（YA.lineageExtraTabs）として足す。画面を持たない点検では見せ方の部分は使わない。
(function () {
  'use strict';
  const YA = (globalThis.YA = globalThis.YA || {});
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

  // ---------- 名物のライバル監督（決定30・119）：3〜4人だけ ----------
  YA.RIVAL_COACHES = [
    { k: 'wall', name: '鬼頭 玄道', title: '守りの老将', kind: '堅守', line: '「一点もやらん。それだけだ」', note: '守りを固めて、少ない好機を決めてくる' },
    { k: 'poach', name: '氷室 蓮', title: '引き抜き上手の若手', kind: 'ハイプレス', line: '「いい子は、先に声をかけた者のものです」', note: '有望な子を先に口説きに来る' },
    { k: 'teach', name: '御園 静', title: '育成の名伯楽', kind: 'ポゼッション', line: '「結果は、あとからついてきます」', note: '育てながら勝つ。卒業生が多い' },
    { k: 'tact', name: '九条 戒', title: '戦術の奇才', kind: 'カウンター', line: '「相手の癖は、試合前に全部見ました」', note: '相手に合わせて戦い方を変えてくる' }
  ];
  const rcDef = (k) => YA.RIVAL_COACHES.find((d) => d.k === k);

  // 同じ部の強いクラブの監督として、名物の4人を割り当てる（毎年・毎週ようすを見て、いなければ割り直す）
  YA.rivalSync = function (w) {
    if (!w.league || !w.league.teams) return [];
    if (!w.rivalCoaches) {
      const r = YA.rngOf(w.seed * 11 + 5);
      w.rivalCoaches = YA.RIVAL_COACHES.map((d) => ({ k: d.k, team: null, teamName: '', rec: { w: 0, d: 0, l: 0 }, lin: r.int(24, 48) + (d.k === 'teach' ? 12 : 0), linY: 0 }));
    }
    const teams = w.league.teams.filter((t) => !t.me);
    const used = new Set();
    for (const rc of w.rivalCoaches) {
      const t = teams.find((x) => x.id === rc.team && !used.has(x.id));
      if (t) used.add(t.id);
      else rc.team = null;
    }
    const pool = teams.filter((t) => !used.has(t.id)).sort((a, b) => b.lvl - a.lvl);
    for (const rc of w.rivalCoaches) {
      if (rc.team) continue;
      const t = pool.shift();
      if (!t) continue;
      rc.team = t.id;
      used.add(t.id);
    }
    for (const rc of w.rivalCoaches) {
      const t = teams.find((x) => x.id === rc.team);
      const d = rcDef(rc.k);
      if (!t || !d) { rc.teamName = ''; continue; }
      rc.teamName = t.name;
      t.coach = { name: d.name + ' 監督', kind: d.kind, note: d.title + '。' + d.line + d.note, named: d.k };
    }
    // 因縁の一戦：前に率いたクラブ（決定118）
    if (w.formerClub) {
      let t = teams.find((x) => x.name === w.formerClub.name);
      if (!t) {
        t = teams.filter((x) => !used.has(x.id)).sort((a, b) => Math.abs(a.lvl - 6) - Math.abs(b.lvl - 6))[0];
        if (t) { t.name = w.formerClub.name; t.short = w.formerClub.name.length > 9 ? w.formerClub.name.slice(0, 9) : w.formerClub.name; }
      }
      if (t) {
        t.grudge = true;
        t.coach = { name: '前のクラブ', kind: t.coach ? t.coach.kind : '堅守', note: '前に率いたクラブ。因縁の一戦' };
      }
    }
    return w.rivalCoaches;
  };
  YA.rivalOfNamed = function (w) {
    const rcs = YA.rivalSync(w).filter((c) => c.team);
    return rcs.find((c) => c.k === 'poach') || rcs[0] || null;
  };
  const rivalOfBase = YA.rivalOf;
  YA.rivalOf = function (w) {
    const rc = YA.rivalOfNamed ? YA.rivalOfNamed(w) : null;
    if (!rc) return rivalOfBase(w);
    return { coach: rcDef(rc.k).name.split(' ')[0], club: rc.teamName, id: rc.team, key: rc.k };
  };
  // 対戦成績を数える（毎週。ことしの試合のうち、まだ数えていないもの）
  function countRivalGames(w) {
    if (w.rivalIdxY !== w.year) { w.rivalIdx = 0; w.rivalIdxY = w.year; }
    const rs = w.results || [];
    for (; w.rivalIdx < rs.length; w.rivalIdx++) {
      const m = rs[w.rivalIdx];
      const rc = (w.rivalCoaches || []).find((c) => c.teamName && c.teamName === m.opp);
      if (!rc) continue;
      if (m.gf > m.ga) rc.rec.w++;
      else if (m.gf === m.ga) rc.rec.d++;
      else rc.rec.l++;
    }
  }
  const meetRounds = (w, id) => {
    const ks = [];
    if (w.league && w.league.rounds) w.league.rounds.forEach((rd, k) => { if (rd.some(([a, b]) => (a === 'me' && b === id) || (b === 'me' && a === id))) ks.push(k + 1); });
    return ks;
  };

  // ---------- トップ監督の注文（決定25・120）----------
  YA.TOP_TASTES = [
    { k: 'young', name: '若手を育てたい', note: '若いうちから使う。伸びしろのある子を好む', poss: null },
    { k: 'ready', name: '即戦力が欲しい', note: 'すぐ戦える子を好む', poss: null },
    { k: 'def', name: '守りを固めたい', note: '守備の選手を求めがち', poss: ['GK', 'CB', 'LB', 'RB', 'DM'] },
    { k: 'atk', name: '攻めを厚くしたい', note: '攻撃の選手を求めがち', poss: ['ST', 'LW', 'RW', 'AM', 'CM'] }
  ];
  const TOP_SUR = ['黒田', '長谷川', '藤原', '桐生', '三宅', '八代', '白石', '宇佐美'];
  const POS_JA = { GK: 'ゴールキーパー', CB: 'センターバック', LB: '左サイドバック', RB: '右サイドバック', LWB: '左ウイングバック', RWB: '右ウイングバック', DM: '守備的MF', CM: '中盤', AM: 'トップ下', LM: '左MF', RM: '右MF', LW: '左ウイング', RW: '右ウイング', SS: 'セカンドトップ', ST: 'ストライカー' };
  YA.posJa = (p) => POS_JA[p] || p;
  const POS_GROUP = { GK: 'GK', CB: 'CB', LB: 'SB', RB: 'SB', LWB: 'SB', RWB: 'SB', DM: 'MF', CM: 'MF', LM: 'MF', RM: 'MF', AM: 'AM', LW: 'W', RW: 'W', SS: 'FW', ST: 'FW' };
  const grp = (p) => POS_GROUP[p] || p;
  YA.topCoachOf = function (w) {
    const r = YA.rngOf(w.seed * 31 + w.year * 7);
    if (!w.topCoach || w.year >= w.topCoach.until) {
      const prev = w.topCoach;
      const taste = r.pick(YA.TOP_TASTES.filter((t) => !prev || t.k !== prev.taste));
      w.topCoach = { name: r.pick(TOP_SUR.filter((n) => !prev || n !== prev.name)) + ' 監督', taste: taste.k, since: w.year, until: w.year + 3 + r.int(0, 2), fav: 0 };
      if (prev) YA.noteTier(w, 1, `トップチームの監督が${w.topCoach.name}に替わりました。好みが変わります（${taste.name}）`);
    }
    return w.topCoach;
  };
  const tasteOf = (k) => YA.TOP_TASTES.find((t) => t.k === k) || YA.TOP_TASTES[0];
  // 年に1〜2回、トップ監督からの注文（来年は〇〇が欲しい）
  YA.topRequest = function (w) {
    if (!w.top) return null;
    const tc = YA.topCoachOf(w);
    const ts = tasteOf(tc.taste);
    const sq = YA.topSquad(w);
    const all = Object.keys(POS_GROUP);
    // 応えられる注文にする：在学中の高2・高3にその位置の子がいる位置から選ぶ。前回と同じ位置は避ける
    // 注文の位置は、今年卒業する高3で、トップの登録に近い力の子がいる位置から選ぶ（応えようがない注文は出さない）
    const line = YA.topCutLine(w) - 8;
    const have = new Set(Object.values(w.players).filter((p) => p.grade === 3 && YA.rate(YA.ovr(p)) >= line).map((p) => grp(p.main || p.pos)));
    if (!have.size) return null;
    const last = (w.topReq || []).length ? w.topReq[w.topReq.length - 1].pos : null;
    let cands = (ts.poss || all).filter((p) => have.has(grp(p)) && !(last && grp(p) === grp(last)));
    if (!cands.length) cands = all.filter((p) => have.has(grp(p)));
    if (!cands.length) return null;
    const count = (p) => sq.filter((x) => grp(x.pos) === grp(p)).length;
    const min = Math.min(...cands.map(count));
    const r = YA.rngOf(w.seed * 13 + w.year * 17 + w.week);
    const pos = r.pick(cands.filter((p) => count(p) === min));
    const q = { y: w.year, w: w.week, pos, coach: tc.name, taste: tc.taste, done: false, res: null };
    (w.topReq = w.topReq || []).push(q);
    YA.noteTier(w, 1, `トップの${tc.name}から注文：「来年は${YA.posJa(pos)}が欲しい」。この位置の子をトップに送り出せば、信頼度が上がります`);
    return q;
  };
  // 注文の結果：ユースから上がった卒業生で、同じ位置の子がトップにいれば応えたことになる
  function resolveRequests(w) {
    for (const q of w.topReq || []) {
      if (q.done || w.year <= q.y) continue;
      const hit = (w.alumni || []).some((a) => a.status === 'pro' && w.top && a.club === w.top.name && grp(a.main || a.pos) === grp(q.pos) && a.year >= q.y);
      q.done = true;
      q.res = hit ? 'ok' : 'ng';
      if (hit) {
        YA.addTrust(w, 3, 'トップ監督の注文に応えた');
        if (w.topCoach) w.topCoach.fav++;
        YA.noteTier(w, 2, `トップの${q.coach}は、${YA.posJa(q.pos)}の注文に応えたユースを喜んでいます`);
      } else {
        YA.addTrust(w, -2, 'トップ監督の注文に応えられなかった');
      }
    }
  }

  // ---------- クラブ移籍（決定118・149）：系譜と実績だけ持って行く ----------
  YA.moveOfferCheck = function (w) {
    if (w.moveOffer && w.moveOffer.y >= w.year) return w.moveOffer;
    w.moveOffer = null;
    if (w.year < 4 || !w.club || w.club.trust < 55) return null;
    const r = YA.rngOf(w.seed * 97 + w.year * 19);
    if (r() > 0.3) return null;
    const cs = (YA.START_CLUBS || []).filter((c) => c.name !== w.clubName && c.tier <= w.club.tier && (c.tier < w.club.tier ? w.club.rep >= 55 : true) && !(w.formerClub && w.formerClub.name === c.name));
    if (!cs.length) return null;
    const c = r.pick(cs);
    w.moveOffer = { club: c.name, tier: c.tier, note: c.note, y: w.year };
    YA.noteTier(w, 1, `${c.name}から、監督就任の打診が来ています。受けると、系譜と実績だけ持って移ります（系譜タブの「クラブ移籍」）`);
    return w.moveOffer;
  };
  // 移る。新しい世界を返す（呼び出し側が差し替える）。★の子は卒業生の枠で系譜に残る
  YA.clubMove = function (w) {
    const offer = w.moveOffer;
    if (!offer) return null;
    const from = w.clubName;
    for (const a of w.alumni) a.origin = a.origin || from;
    const farewell = [];
    for (const p of Object.values(w.players)) {
      if (!p.star) continue;
      const o = YA.ovr(p);
      const a = YA.alumniEntry(w, Object.assign({}, p, { _path: o >= 13.2 ? 'pro' : 'univ' }), `お別れ（${from}の注目の子。系譜の中で育ち続ける）`);
      a.age = 15 + p.grade;
      a.grade = p.grade;
      a.origin = from;
      a.moved = true;
      w.alumni.push(a);
      farewell.push(p.name);
    }
    const nw = YA.newWorld(w.seed * 3 + w.year + 1, { coach: w.coach, coachName: w.coachName, tier: offer.tier, clubName: offer.club, noFire: !!w.club.noFire, tutorial: false });
    nw.year = w.year;
    nw.week = 1;
    nw.alumni = w.alumni;
    nw.trophies = w.trophies || [];
    nw.leagueHist = w.leagueHist || [];
    nw.rec = Object.assign({}, w.rec);
    nw.achSeen = w.achSeen;
    nw.achInit = true;
    nw.solidTotal = w.solidTotal || 0;
    nw.fundIn = w.fundIn || 0;
    nw.moves = (w.moves || []).concat([{ y: w.year, from, to: offer.club }]);
    nw.formerClub = { name: from, tier: w.club.tier };
    nw.rivalCoaches = (w.rivalCoaches || []).map((c) => Object.assign({}, c, { team: null, teamName: '' }));
    nw.club.rep = w.club.rep;
    nw.rep = w.club.rep;
    nw.club.careerClubs = (w.club.careerClubs || []).concat([{ name: offer.club, from: w.year }]);
    YA.yearStart(nw);
    YA.autoPlan(nw);
    nw.inbox.push({ week: 0, year: nw.year, tier: 1, text: `${from}から${offer.club}へ移りました。系譜・殿堂・実績・評判は持ってきました。選手・スタッフ・施設は置いてきました。` + (farewell.length ? `注目の子（${farewell.slice(0, 4).join('・')}${farewell.length > 4 ? 'ほか' : ''}）は、系譜の中で育ち続けます。` : '') + '前のクラブの卒業生の連帯貢献金は、前のクラブに入ります。' });
    return nw;
  };

  // 前のクラブの卒業生の連帯貢献金は、いまのクラブに入らない（決定149）。育ち方と移籍は、いまの卒業生と同じに進める
  const tickPrev = YA.alumniTick;
  YA.alumniTick = function (w) {
    const former = (w.alumni || []).filter((a) => a.origin && a.origin !== w.clubName);
    if (!former.length) return tickPrev(w);
    const cur = w.alumni.filter((a) => !(a.origin && a.origin !== w.clubName));
    const all = w.alumni;
    let c = 0;
    w.alumni = cur;
    try { c = tickPrev(w); } finally { w.alumni = all; }
    const w2 = Object.create(w);
    w2.alumni = former;
    w2.club = { solidarity: 0 };
    w2.solidTotal = 0;
    tickPrev(w2);
    return c;
  };

  // 年度はじめと毎週の手入れ
  const yearStartPrev = YA.yearStart;
  YA.yearStart = function (w) {
    countRivalGames(w);
    resolveRequests(w);
    yearStartPrev(w);
    YA.rivalSync(w);
    for (const rc of w.rivalCoaches || []) {
      if (rc.linY === w.year) continue;
      rc.linY = w.year;
      rc.lin += YA.rngOf(w.seed * 7 + w.year * 3 + rc.k.length).int(7, 12) + (rc.k === 'teach' ? 2 : 0);
    }
    YA.topCoachOf(w);
    YA.moveOfferCheck(w);
  };
  const weekPrev = YA.rivalWeek;
  YA.rivalWeek = function (w) {
    YA.rivalSync(w);
    countRivalGames(w);
    if (weekPrev) weekPrev(w);
    if (w.week === 10 || (w.week === 30 && w.year >= 3)) YA.topRequest(w);
    if (w.week === 4 && w.formerClub) {
      const t = (w.league ? w.league.teams : []).find((x) => x.grudge);
      const ks = t ? meetRounds(w, t.id) : [];
      if (ks.length) YA.noteTier(w, 2, `前に率いた${t.name}との因縁の一戦は第${ks.join('節と第')}節です`);
    }
  };

  // 見せ方（系譜タブの追加の小タブ）
  YA.lineageExtraTabs = YA.lineageExtraTabs || [];
  const U = () => YA._ui;
  const h = (...a) => U().h(...a);
  const rerender = () => U().render();
  function rivalTab(body, w) {
    const rcs = YA.rivalSync(w);
    body.append(h('div', { class: 'h' }, '名物のライバル監督'), h('div', { class: 'note' }, '同じリーグに顔と名前のある監督が4人います。対戦成績と、卒業生を送り出した数（系譜の大きさ）を比べられます。'));
    body.append(h('div', { class: 'pitem', style: 'cursor:default;gap:6px;margin-top:4px;border:1px solid #b08a00' }, h('div', { class: 'grow' }, h('b', {}, `あなた（${w.coachName}）`), h('div', { class: 'note' }, `系譜の大きさ ${w.alumni.length}人`))));
    const list = h('div', { class: 'scroll', style: 'flex:1;min-height:0;margin-top:4px' });
    for (const rc of rcs) {
      const d = rcDef(rc.k);
      list.append(h('div', { class: 'pitem', style: 'cursor:default;gap:6px;margin-top:4px;flex-wrap:wrap' }, h('div', { class: 'grow' }, h('b', {}, `${d.name}（${d.title}）`), h('div', { class: 'note' }, rc.teamName ? `${rc.teamName}／${d.line}` : '今年は別のリーグ'), h('div', { class: 'note' }, `対戦成績 ${rc.rec.w}勝${rc.rec.d}分${rc.rec.l}敗／系譜の大きさ ${rc.lin}人`))));
    }
    body.append(list);
  }
  function topTab(body, w) {
    const tc = YA.topCoachOf(w);
    const ts = tasteOf(tc.taste);
    body.append(h('div', { class: 'h' }, 'トップ監督の注文'), h('div', { class: 'note' }, `${tc.name}（${ts.name}。${ts.note}）。年に1〜2回、「来年はこの位置が欲しい」と注文が来ます。合う子をトップに送り出せば信頼度が上がり、外すと下がります。監督が替わると好みも変わります。`));
    const reqs = (w.topReq || []).slice().reverse();
    const list = h('div', { class: 'scroll', style: 'flex:1;min-height:0;margin-top:4px' });
    if (!reqs.length) list.append(h('div', { class: 'note' }, 'まだ注文は来ていません（毎年10週ごろに来ます）。'));
    for (const q of reqs) list.append(h('div', { class: 'pitem', style: 'cursor:default;gap:6px;margin-top:3px' }, h('span', { class: 'sub', style: 'width:54px' }, `${q.y}年目`), h('div', { class: 'grow' }, h('b', {}, `${YA.posJa(q.pos)}が欲しい`), h('div', { class: 'note' }, q.coach)), h('span', { class: 'chip ' + (q.res === 'ok' ? 'trait' : 'gray') }, q.res === 'ok' ? '応えた' : q.res === 'ng' ? '応えられず' : '返事待ち')));
    body.append(list);
  }
  function moveTab(body, w) {
    const ui = U().app;
    const o = YA.moveOfferCheck(w);
    body.append(h('div', { class: 'h' }, 'クラブ移籍'), h('div', { class: 'note' }, '別のクラブから監督の打診が来ることがあります。受けると、系譜・殿堂・実績・評判だけ持って移ります。選手・スタッフ・施設は置いていき、注目の子は系譜の中で育ち続けます。前のクラブの卒業生の連帯貢献金は、前のクラブに入ります。'));
    if (o) {
      body.append(h('div', { class: 'pitem', style: 'cursor:default;gap:6px;margin-top:6px' }, h('div', { class: 'grow' }, h('b', {}, o.club), h('div', { class: 'note' }, o.note)), ui.mvOk
        ? h('button', { class: 'btn sm pri', onclick: () => { const nw = YA.clubMove(w); if (!nw) return; ui.mvOk = false; ui.app = ui.app; U().app.w = nw; U().app.tab = 'home'; U().app.view = 'pre'; YA.saveWorld(true); rerender(); } }, 'ほんとうに移る')
        : h('button', { class: 'btn sm', onclick: () => { ui.mvOk = true; rerender(); } }, '受ける')));
      if (ui.mvOk) body.append(h('div', { class: 'note', style: 'color:#c0392b;margin-top:4px' }, 'もう一度押すと移ります。元には戻せません。'));
    } else body.append(h('div', { class: 'note', style: 'margin-top:6px' }, 'いま打診は来ていません（4年目以降、信頼度が高いと来ることがあります）。'));
    const mv = (w.moves || []).slice().reverse();
    for (const m of mv) body.append(h('div', { class: 'note', style: 'margin-top:3px' }, `${m.y}年目：${m.from} → ${m.to}`));
  }
  YA.lineageExtraTabs.push(['rival', 'ライバル', rivalTab], ['top', 'トップ', topTab], ['move', '移籍', moveTab]);
})();
