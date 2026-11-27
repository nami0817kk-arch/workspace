// 段4 試合後のスポーツ新聞（paper.js。2026-11-27）：A の公式戦のあとだけ・大見出しの優先・記録と食い違わない・同じ見出しが続かない・
// 経歴に残り卒業後も読める・保存が膨らまない・おまかせで止まらない
'use strict';
module.exports = (YA, ok) => {
  let nChk = 0;
  const OK = (c, m) => { nChk++; ok(c, '新聞：' + m); };
  const sur = (n) => String(n || '').split(' ')[0];

  // ---- 1. 大見出しの優先順（材料から。覚醒＞決勝点/ハットトリック＞大勝/大敗＞初出場/初ゴール＞ふつう）----
  {
    const R = (id, g, r, extra) => [id, id + ' 太郎', 'ST', r || 6.5, 90, g || 0, 0, 0].concat(extra || []);
    const base = (o) => Object.assign({ gf: 1, ga: 1, gl: [], rt: [R('a'), R('b'), R('c')], fg: [], db: [] }, o);
    const K = (o) => YA.paperDecide(base(o)).kind;
    const gl = (seq) => seq.map((s, i) => [10 + i * 10, s[0], s[1] ? s[1] + ' 太郎' : '相手 一郎', '', s[0] ? s[1] : null, null, null]);
    OK(K({ gf: 4, ga: 0, rt: [R('a', 3), R('b', 1), R('c')], gl: gl([[1, 'a'], [1, 'a'], [1, 'b'], [1, 'a']]), kz: { kind: 'awake', pid: 'c' }, db: ['b'] }) === 'awake', '覚醒はハットトリック・大勝・初出場より上');
    OK(K({ gf: 4, ga: 0, rt: [R('a', 3), R('b', 1), R('c')], gl: gl([[1, 'a'], [1, 'a'], [1, 'b'], [1, 'a']]), db: ['b'] }) === 'hat', 'ハットトリックは大勝より上');
    OK(K({ gf: 2, ga: 1, rt: [R('a', 1), R('b', 1), R('c')], gl: gl([[1, 'a'], [0, null], [1, 'b']]), fg: ['b'], db: ['c'] }) === 'win1', '決勝点は初ゴール・初出場より上');
    OK(YA.paperDecide(base({ gf: 2, ga: 1, rt: [R('a', 1), R('b', 1), R('c')], gl: gl([[1, 'a'], [0, null], [1, 'b']]) })).main === 'b', '決勝点の主役は「相手の得点+1本目」を決めた子');
    OK(K({ gf: 3, ga: 0, rt: [R('a', 1), R('b', 1), R('c', 1)], gl: gl([[1, 'a'], [1, 'b'], [1, 'c']]), fg: ['a'] }) === 'rout', '大勝は初ゴールより上');
    OK(K({ gf: 0, ga: 3, gl: gl([[0], [0], [0]]), db: ['a'] }) === 'crush', '大敗は初出場より上');
    OK(K({ gf: 1, ga: 1, rt: [R('a', 1), R('b'), R('c')], gl: gl([[1, 'a'], [0, null]]), fg: ['a'], db: ['b'] }) === 'firstG', '初ゴールは初出場より上');
    OK(K({ gf: 0, ga: 0, db: ['b'] }) === 'debut', '初出場はふつうより上');
    OK(K({ gf: 1, ga: 0, rt: [R('a', 1), R('b'), R('c')], gl: gl([[1, 'a']]) }) === 'win1' && K({ gf: 2, ga: 0, rt: [R('a', 2), R('b'), R('c')], gl: gl([[1, 'a'], [1, 'a']]) }) === 'nw' && K({ gf: 0, ga: 0 }) === 'nd' && K({ gf: 0, ga: 2 }) === 'nl', 'ふつうの試合は勝ち・引き分け・負けで型が分かれる');
    OK(Object.values(YA.PAPER_HL).every((l) => l.length >= 3), '見出しは型ごとに3通り以上');
  }

  // ---- 2. 2年半おまかせで回す：試合ごとに、新聞の有無・優先・記録との食い違いを見る ----
  const w = YA.newWorld(2711);
  const am = YA.applyMatch;
  const seen = []; // { which, scheduled, official, made, P, real }
  YA.applyMatch = function (ww, m, which, opp, scheduled) {
    const n0 = ww.paperN || 0;
    const official = !!YA.paperOfficial(ww);
    const res = am.apply(this, arguments);
    if (ww !== w) return res;
    const made = (ww.paperN || 0) > n0;
    const rec = { which, scheduled, official, made, week: ww.week };
    if (made) {
      const P = ww.papers[ww.papers.length - 1];
      const H = m.home;
      // 試合から別に数えた事実（材料を使わずに）
      const ours = Object.entries(H.players).filter(([, mp]) => mp.st && mp.st.minutes > 0);
      const goalsBy = {};
      for (const [id, mp] of ours) if (mp.st.goals) goalsBy[mp.name] = mp.st.goals;
      rec.P = P;
      rec.real = { gf: m.score.home, ga: m.score.away, goalsBy, hat: ours.some(([, mp]) => mp.st.goals >= 3), ratings: Object.fromEntries(ours.map(([id, mp]) => [id, Math.round(mp.st.rating * 10) / 10])), nScenesGoals: (m.scenes || []).filter((sc) => sc.goal).length };
      rec.T = YA.paperText(ww, P);
    }
    seen.push(rec);
    return res;
  };
  let stops = 0;
  try {
    for (let y = 0; y < 2; y++) { const r = YA.simulate(w, { until: 'year', stopOnImportant: false }); if (r && r.stopped) stops++; }
    for (let k = 0; k < 20; k++) { const r = YA.simulate(w, { until: 'week', stopOnImportant: false }); if (r && r.stopped) stops++; } // 3年目の途中まで（在籍の子の記事と紙面を見るため）
  } finally { YA.applyMatch = am; }
  OK(!YA._paperErr, '作るときに例外が出ない ' + (YA._paperErr || []).slice(0, 1).join(''));
  const A = seen.filter((x) => x.which === 'A' && x.scheduled);
  const offi = A.filter((x) => x.official);
  OK(offi.length >= 50 && offi.every((x) => x.made), `A の公式戦のあとは毎回新聞が出る（${offi.filter((x) => x.made).length}/${offi.length}）`);
  const friendly = A.filter((x) => !x.official);
  OK(friendly.length >= 4 && friendly.every((x) => !x.made), `練習試合・フェスティバルでは出ない（${friendly.length}試合）`);
  const bs = seen.filter((x) => x.which === 'B');
  OK(bs.length >= 15 && bs.every((x) => !x.made), `B の試合では出ない（${bs.length}試合）`);
  // 優先：試合から数えた事実と、選ばれた型の段が合う
  const made = A.filter((x) => x.made);
  let badRank = [];
  for (const x of made) {
    const { real, P } = x;
    const awake = P.kz && P.kz.kind === 'awake';
    const exp = awake ? 1 : real.hat || (real.gf - real.ga === 1 && P.k === 'win1') ? 2 : Math.abs(real.gf - real.ga) >= 3 ? 3 : null;
    const r = YA.PAPER_RANK[P.k];
    if (exp != null && r !== exp && !(exp === 2 && real.gf - real.ga === 1 && r === 3)) badRank.push(`${P.k}:${real.gf}-${real.ga}`);
    if (exp == null && r < 4 && !(r === 2 && real.gf - real.ga === 1)) badRank.push(`${P.k}?${real.gf}-${real.ga}`);
    if (real.hat && P.k !== 'hat' && !awake) badRank.push('hat無視');
  }
  OK(!badRank.length, `大見出しの優先順が試合の事実と合う（${made.length}試合） ` + badRank.slice(0, 4).join(' '));
  const kinds = {};
  for (const x of made) kinds[x.P.k] = (kinds[x.P.k] || 0) + 1;
  console.log('新聞の大見出しの型（2年半）', JSON.stringify(kinds));
  OK(['nw', 'nd', 'nl'].filter((k) => kinds[k]).length >= 2 && (kinds.win1 || 0) + (kinds.hat || 0) > 0 && Object.keys(kinds).length >= 6, '大見出しの型がばらける（6種類以上）');
  // 記録と食い違わない：スコア・得点者・得点の数・採点
  let badRec = [];
  for (const x of made) {
    const { real, P, T } = x;
    if (P.gf !== real.gf || P.ga !== real.ga) badRec.push('score');
    if (P.gl.length !== P.gf + P.ga) badRec.push(`goals ${P.gl.length}/${P.gf + P.ga}`);
    const by = {};
    for (const g of P.gl) if (g[1] === 1 && g[2]) by[g[2]] = (by[g[2]] || 0) + 1;
    if (JSON.stringify(Object.keys(by).sort().map((k) => k + by[k])) !== JSON.stringify(Object.keys(real.goalsBy).sort().map((k) => k + real.goalsBy[k]))) badRec.push('scorers ' + JSON.stringify(by) + ' vs ' + JSON.stringify(real.goalsBy));
    for (const nm of Object.keys(real.goalsBy)) if (T.paras[0].indexOf(sur(nm)) < 0) badRec.push('本文に得点者がいない ' + nm);
    if (T.paras[0].indexOf(`${P.gf}-${P.ga}`) < 0) badRec.push('本文のスコア');
    for (const r of P.rt) if (real.ratings[r[0]] != null && Math.abs(real.ratings[r[0]] - r[3]) > 0.55) badRec.push('rating');
    if (T.rates.length !== Object.keys(real.ratings).length && T.rates.length < 16) badRec.push('rates数');
    if (/undefined|NaN|null|\[object/.test(T.hd + T.sub + T.paras.join('') + JSON.stringify(T.side) + T.rates.map((r) => r.note).join(''))) badRec.push('文が崩れた: ' + T.hd + T.paras.join('').slice(0, 60));
    if (T.paras.length < 3 || T.paras.length > 4) badRec.push('段落の数 ' + T.paras.length);
    if (!T.side.length) badRec.push('小さな記事が無い');
  }
  OK(!badRec.length, `記事が試合の記録と食い違わない（${made.length}試合） ` + badRec.slice(0, 4).join(' / '));
  // 採点（試合のあとの気づきの場面で直したものも）が選手の直近の記録と同じ
  {
    let n = 0, bad = 0;
    for (const P of w.papers) for (const r of P.rt) { const p = w.players[r[0]]; if (!p) continue; const rl = (p.rl || []).find((x) => x.y === P.y && x.w === P.wk && x.t !== 'B'); if (!rl) continue; n++; if (Math.abs(rl.r - r[3]) > 0.051) bad++; }
    OK(n >= 8 && bad === 0, `紙面の採点が選手の試合の記録と同じ（${n}人中 違い${bad}）`);
  }
  // 同じ見出しが続かない（同じ型の直近の言い回しも避ける）
  {
    let same = 0, sameV = 0;
    const last = {};
    for (let i = 0; i < made.length; i++) {
      if (i && made[i].T.hd === made[i - 1].T.hd) same++;
      const P = made[i].P;
      if (last[P.k] != null && last[P.k] === P.hv) sameV++;
      last[P.k] = P.hv;
    }
    OK(same === 0 && sameV === 0, `同じ見出しが続かない（続いた ${same}・同じ型で同じ言い回しが続いた ${sameV}）`);
  }
  // 経歴に残る・卒業生にも残る
  {
    const ps = Object.values(w.players);
    const withP = ps.filter((p) => (p.press || []).length);
    OK(withP.length >= 10 && ps.every((p) => (p.press || []).length <= YA.PRESS_MAX), `在籍の子の経歴に記事が残る（${withP.length}人・1人${YA.PRESS_MAX}件まで）`);
    const al = (w.alumni || []).filter((a) => (a.press || []).length);
    OK(al.length >= 5 && (w.alumni || []).every((a) => (a.press || []).length <= YA.PRESS_ALUMNI) && al.every((a) => a.press.every((e) => e.h && e.y && e.w && e.o && e.s)), `卒業しても記事が読める（${al.length}人・1人${YA.PRESS_ALUMNI}件まで）`);
    OK(al.some((a) => a.press.some((e) => e.m)), '卒業生に主役の記事が残る');
    // 主役の記事の見出しが、その試合の紙面の見出しと同じ（紙面が残っているもの）
    let bad = 0, n = 0;
    for (const p of ps) for (const e of p.press || []) { const P = w.papers.find((q) => q.id === e.i && q.y === e.y); if (!P) continue; n++; if (YA.paperText(w, P).hd !== e.h) bad++; if (e.m && P.main !== p.id) bad++; }
    OK(n > 0 && bad === 0, `経歴の記事が紙面と同じ（${n}件中 違い${bad}）`);
  }
  // おまかせで止まらない・お知らせを増やさない
  OK(stops === 0 && w.year === 3, 'おまかせ進行は新聞で止まらない');
  OK(!(w.forced || []).some((e) => /paper/.test(e.id)) && !(w.inbox || []).some((n) => /新聞/.test(String(n.text))), '新聞は出来事・お知らせを増やさない');
  // 保存の大きさ：紙面は直近だけ・記事は件数の上限。年を重ねても新聞の分は小さいまま
  {
    const size = (x) => JSON.stringify(x || []).length;
    const pp = size(w.papers), pl = size(Object.values(w.players).map((p) => p.press || []));
    const al = w.alumni || [];
    const pa = size(al.map((a) => a.press || []));
    const all = JSON.stringify(w).length;
    console.log('新聞の保存（2年半）', '紙面', pp, '在籍の記事', pl, '卒業生の記事', pa, '卒業生', al.length, '全体', all);
    OK(w.papers.length <= YA.PAPER_KEEP && pp < 16000, `紙面の材料は直近${YA.PAPER_KEEP}試合だけ（${pp}字）`);
    OK(pa / Math.max(1, al.length) < 900 && (pp + pl + pa) / all < 0.08, `新聞の分は保存全体の8%未満（${(((pp + pl + pa) / all) * 100).toFixed(1)}%・卒業生1人 ${(pa / Math.max(1, al.length)).toFixed(0)}字）`);
  }

  // ---- 3. 気づきの場面で覚醒した試合は、大見出しが覚醒に（試合の途中＝作る前、試合のあと＝作ったあとに直す）----
  {
    const w2 = YA.newWorld(3301);
    for (let i = 0; i < 6; i++) YA.simulate(w2, { until: 'week', stopOnImportant: false });
    while (!YA.paperOfficial(w2) || w2.phase === 'after') YA.simulate(w2, { until: 'week', stopOnImportant: false });
    const now = w2.year * 40 + w2.week;
    const t = YA.teamFromWorld(w2, 'A');
    const kidId = t.lineup.map((s) => s.pid).find((id) => w2.players[id] && w2.players[id].pos !== 'GK');
    const kid = w2.players[kidId];
    for (const x of YA.kadaiActive(w2)) { x.kd = null; x.star = false; }
    kid.kd = { t: 'eye', c: null, w0: now - 8, len: 12, fit: 'yes' }; kid.star = true; kid.kEnd = null;
    w2.kzW = null;
    const opp = YA.opponentOf(w2);
    const m = new YA.Match({ seed: 77, home: t, away: YA.makeOpponent(opp, 5), settings: { autoStop: false } });
    m.opp = opp; m.scheduled = true;
    let g = 0; while (!m.finished && g++ < 3000) m.step();
    const e = YA.kizukiMake(w2, kid, 'live', { min: 60, gf: 0, ga: 0, opp: opp.name });
    m._kz = { e, role: 'ok' };
    m.applied = true;
    YA.applyMatch(w2, m, 'A', opp, true);
    const P = YA.paperOfMatch(w2, m);
    OK(P && P.k === 'awake' && P.main === kid.id && YA.paperText(w2, P).hd.indexOf(sur(kid.name)) >= 0, '試合の途中の気づきの場面で覚醒 → 大見出しはその子の覚醒 ' + (P ? P.k : 'なし'));
    OK((kid.press || []).some((x) => x.i === P.id && x.m), '覚醒した子の経歴に主役の記事');
    // 試合のあと（結果まで・おまかせ）：作ったあとで見出しを直す
    const w3 = YA.newWorld(3302);
    for (let i = 0; i < 6; i++) YA.simulate(w3, { until: 'week', stopOnImportant: false });
    while (!YA.paperOfficial(w3) || w3.phase === 'after') YA.simulate(w3, { until: 'week', stopOnImportant: false });
    const t3 = YA.teamFromWorld(w3, 'A');
    const k3 = w3.players[t3.lineup.map((s) => s.pid).find((id) => w3.players[id] && w3.players[id].pos !== 'GK')];
    for (const x of YA.kadaiActive(w3)) { x.kd = null; x.star = false; }
    k3.kd = { t: 'eye', c: null, w0: w3.year * 40 + w3.week - 8, len: 12, fit: 'yes' }; k3.star = true; k3.kEnd = null; w3.kzW = null;
    const o3 = YA.opponentOf(w3);
    const m3 = new YA.Match({ seed: 78, home: t3, away: YA.makeOpponent(o3, 6), settings: { autoStop: false } });
    m3.opp = o3; m3.scheduled = true;
    g = 0; while (!m3.finished && g++ < 3000) m3.step();
    m3.applied = true;
    YA.applyMatch(w3, m3, 'A', o3, true);
    const P3 = YA.paperOfMatch(w3, m3);
    const k0 = P3 && P3.k;
    const e3 = YA.kizukiMake(w3, k3, 'match', { min: 70, gf: m3.score.home, ga: m3.score.away, opp: o3.name });
    YA.kizukiSettle(w3, e3, 'ok');
    OK(P3 && k0 !== 'awake' && P3.k === 'awake' && P3.main === k3.id && (k3.press || []).some((x) => x.i === P3.id && x.m && x.h === YA.paperText(w3, P3).hd), `試合のあとの場面で覚醒 → 紙面と経歴の見出しを直す（${k0}→${P3 && P3.k}）`);
  }
  console.log('新聞の点検', nChk, '件');
};
