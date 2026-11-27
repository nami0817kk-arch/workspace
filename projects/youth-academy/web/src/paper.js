// 段4「試合後のスポーツ新聞」（2026-11-27 ユーザーと会話で確定。仕様は「ユースの系譜：段4 試合後のスポーツ新聞」）
// ・A の公式戦（リーグ・夏と冬の大会・プレーオフ／ファイナル）のあと毎回、一面を作る。練習試合・新春フェスティバル（friendly）・B の試合では作らない
// ・大見出しは その試合の一番の出来事：覚醒 ＞ 決勝点・ハットトリック ＞ 大勝・大敗 ＞ 初ゴール・初出場 ＞ ふつう。
//   見出しは型ごとに3〜4通りの言い回しを持ち、同じ型で直近に使ったものは避ける（w.paperHv）
// ・材料（w.papers）は試合の実際の記録（得点者・時間・アシスト・採点・効いた特性・気づきの場面の結果）だけ。文は材料から毎回作り直す（YA.paperText）。
//   紙面の材料は直近 YA.PAPER_KEEP 試合ぶんだけ持つ。選手の経歴には「記事」（見出し・小見出し・日付・試合・主役か）を1人 YA.PRESS_MAX 件まで残し、
//   卒業生には YA.PRESS_ALUMNI 件まで（主役の記事を先に）持たせる
// ・試合後の画面の最初のページ（ui.js の viewResult の「新聞」）。おまかせ進行でも記事は作って残す（画面は出さない・止めない）
(function () {
  'use strict';
  const YA = (globalThis.YA = globalThis.YA || {});
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const sur = (n) => String(n || '').split(' ')[0];
  YA.PAPER_NAME = 'ユース蹴球新聞'; // 架空の新聞（実在の新聞名に似せない）
  YA.PAPER_KEEP = 12; // 紙面の材料を持つ試合の数（約3か月ぶん）
  YA.PRESS_MAX = 10; // 在籍中の子の記事の上限
  YA.PRESS_ALUMNI = 6; // 卒業生の記事の上限（主役の記事を先に残す）

  const clubOf = (w) => YA.shortName ? YA.shortName(w.clubName) : String(w.clubName || '').replace(/U-18$/, '');
  const oppShort = (n) => String(n || '').replace(/U-18$/, '').trim();
  // 時間の言い方：「前半12分」「後半追加時間」
  const minWord = (ml) => {
    const s = String(ml == null ? '' : ml);
    const [a, b] = s.split('+');
    const x = +a || 0;
    if (b) return x <= 45 ? '前半追加時間' : '後半追加時間';
    return x <= 45 ? `前半${Math.max(1, x)}分` : `後半${x - 45}分`;
  };
  const minNum = (ml) => { const [a, b] = String(ml).split('+'); return (+a || 0) + (+b || 0) / 100; };

  // A の公式戦か（練習試合・新春フェスティバルは friendly）
  YA.paperOfficial = function (w) {
    const s = YA.SCHED ? YA.SCHED(w.week) : null;
    if (!s) return null;
    if (s.t === 'league') return s;
    if (s.t === 'cup' && w.cup && w.cup[s.cup] && !w.cup[s.cup].friendly) return s;
    return null;
  };

  // ---------- 見出しの言い回し（型ごとに3〜4通り）----------
  // c = { S: 主役の名字, club, opp, gf, ga, n: 得点数, mw: 時間, kn: 課題の名前, form: 覚醒の形 }
  const HL = {
    awake: [
      (c) => `${c.S}、${c.kn}の先に見えた`,
      (c) => `化けた！${c.S}　${c.kn}を越えて`,
      (c) => `${c.S}覚醒　もがいた日々が実を結ぶ`,
      (c) => `${c.S}、殻を破る　目覚めた「${c.form}」`,
    ],
    hat: [
      (c) => `${c.S}、${c.n}発の大暴れ`,
      (c) => `${c.S}ハットトリック！　ゴールを量産`,
      (c) => `止まらない${c.S}　${c.n}得点で圧倒`,
    ],
    win1: [
      (c) => `${c.S}弾で競り勝つ`,
      (c) => `${c.S}、${c.mw}の決勝点`,
      (c) => `決めたのは${c.S}　${c.gf}-${c.ga}の接戦制す`,
      (c) => `${c.S}の一撃、${c.club}を勝利へ`,
    ],
    rout: [
      (c) => `${c.club}、${c.gf}発の快勝`,
      (c) => `${c.club}大勝　${c.opp}を${c.gf}-${c.ga}`,
      (c) => `攻撃陣が爆発　${c.gf}ゴールで圧倒`,
    ],
    crush: [
      (c) => `${c.club}、${c.ga}失点の完敗`,
      (c) => `${c.opp}に${c.gf}-${c.ga}　力の差を突きつけられる`,
      (c) => `大敗の${c.club}　立て直しが急務`,
    ],
    firstG: [
      (c) => `${c.S}、待望の初ゴール`,
      (c) => `うれしい初得点　${c.S}がネットを揺らす`,
      (c) => `${c.S}、Aで初ゴール　${c.mw}に決めた`,
    ],
    debut: [
      (c) => `${c.S}、Aで初陣`,
      (c) => `新顔${c.S}、公式戦デビュー`,
      (c) => `${c.S}がデビュー　${c.mins}分間ピッチに立つ`,
    ],
    nw: [
      (c) => `${c.club}、${c.opp}を下す`,
      (c) => `${c.club}が白星　${c.gf}-${c.ga}`,
      (c) => `${c.S}が躍動、${c.club}勝利`,
      (c) => `${c.club}、手堅く勝ち切る`,
    ],
    nd: [
      (c) => `${c.club}、${c.opp}と痛み分け`,
      (c) => `${c.gf}-${c.ga}、決着つかず`,
      (c) => `${c.club}、あと一歩届かずドロー`,
      (c) => `${c.S}奮闘も、${c.club}は引き分け`,
    ],
    nl: [
      (c) => `${c.club}、${c.opp}に屈する`,
      (c) => `${c.club}黒星　${c.gf}-${c.ga}`,
      (c) => `${c.S}の奮闘も実らず`,
      (c) => `${c.club}、悔しい敗戦`,
    ],
    pkw: [
      (c) => `${c.club}、PK戦で突破`,
      (c) => `PK戦を制す　${c.club}が次へ`,
      (c) => `${c.gf}-${c.ga}からのPK戦、${c.club}が競り勝つ`,
    ],
    pkl: [
      (c) => `${c.club}、PK戦に散る`,
      (c) => `PK戦で涙　${c.club}`,
      (c) => `${c.gf}-${c.ga}、PK戦で力尽きる`,
    ],
  };
  YA.PAPER_HL = HL;
  // 大見出しの優先の段（1が一番上）。点検用
  YA.PAPER_RANK = { awake: 1, hat: 2, win1: 2, rout: 3, crush: 3, firstG: 4, debut: 4, nw: 5, nd: 5, nl: 5, pkw: 5, pkl: 5 };
  // 本人の一言（YA.voice で口調に寄せる）
  const SAYS = {
    awake: ['やっと、見えた気がします', '今日は、迷わずにやれました', 'ずっと苦しかったけど、今日で変われた気がします'],
    hat: ['今日は何を打っても入る気がしました', 'みんながいいボールをくれたおかげです', '3点取れたのは、自信になります'],
    win1: ['最後に決められて、よかったです', 'あの場面は、絶対に決めるつもりでした', 'チームを勝たせられて、うれしいです'],
    firstG: ['やっと決められました。ほっとしています', '初ゴールは、一生忘れません', 'ずっと狙っていたので、うれしいです'],
    debut: ['緊張しましたけど、楽しかったです', 'ここからが、スタートです', 'もっとやれました。次はもっと出たいです'],
    win: ['勝ててよかったです。次も勝ちます', 'チーム全員でつかんだ勝ちです', 'まだまだ、良くなれると思います'],
    draw: ['勝ちきれなかったのが、悔しいです', '次は決めきります', '悪くはなかったです。でも、もっとやれました'],
    loss: ['悔しいです。次は必ずやり返します', '自分のところで、もっとやれました', 'この負けを忘れずに、練習します'],
  };
  const sayKind = (k, P) => (SAYS[k] ? k : k === 'rout' || k === 'nw' || k === 'pkw' ? 'win' : k === 'nd' ? 'draw' : P.gf > P.ga ? 'win' : P.gf === P.ga ? 'draw' : 'loss');
  // 相手の監督（名物監督でないとき）。勝った・負けた・引き分けは相手から見て
  const OPP_SAY = {
    they_lost: ['「完敗です。若い選手たちの勢いを止められなかった」', '「切り替えます。この悔しさを次に」', '「うちの課題がはっきり出た試合でした」'],
    they_won: ['「狙いどおりの試合ができた」', '「相手もいいチームでした。勝てたのは粘りです」', '「まだ満足はしていません」'],
    draw: ['「勝ちたかったが、内容は悪くない」', '「お互いに譲らない試合でした」', '「最後の精度だけですね」'],
  };

  // ---------- 材料を作る ----------
  function pickHv(w, kind, seed) {
    const n = HL[kind].length;
    w.paperHv = w.paperHv || {};
    const used = w.paperHv[kind] || [];
    const r = YA.rngOf(seed | 0);
    const st = r.int(0, n - 1);
    let pick = st;
    for (let i = 0; i < n; i++) { const c = (st + i) % n; if (used.indexOf(c) < 0) { pick = c; break; } }
    w.paperHv[kind] = used.concat([pick]).slice(-Math.min(n - 1, 3)); // 同じ型で直近に使った言い回しは避ける
    return pick;
  }
  // 主役と見出しの型を決める（材料から）
  function decide(P) {
    const ours = P.rt.slice();
    const byR = ours.slice().sort((a, b) => b[3] - a[3] || b[4] - a[4]);
    if (P.kz && P.kz.kind === 'awake' && ours.some((x) => x[0] === P.kz.pid)) return { kind: 'awake', main: P.kz.pid };
    const hat = ours.filter((x) => x[5] >= 3).sort((a, b) => b[5] - a[5] || b[3] - a[3])[0];
    if (hat) return { kind: 'hat', main: hat[0] };
    if (P.gf - P.ga === 1) {
      const mine = P.gl.filter((g) => g[1] === 1);
      const g = mine[P.ga]; // ga+1 本目のこちらの得点が決勝点
      if (g && g[4] && ours.some((x) => x[0] === g[4])) return { kind: 'win1', main: g[4], g };
    }
    if (P.gf - P.ga >= 3) { const top = ours.slice().sort((a, b) => b[5] - a[5] || b[3] - a[3])[0]; return { kind: 'rout', main: top ? top[0] : null }; }
    if (P.ga - P.gf >= 3) return { kind: 'crush', main: byR[0] ? byR[0][0] : null };
    const fg = (P.fg || []).map((id) => ours.find((x) => x[0] === id)).filter(Boolean).sort((a, b) => b[3] - a[3])[0];
    if (fg) return { kind: 'firstG', main: fg[0] };
    const db = (P.db || []).map((id) => ours.find((x) => x[0] === id)).filter(Boolean).sort((a, b) => b[3] - a[3])[0];
    if (db) return { kind: 'debut', main: db[0] };
    const kind = P.pk ? (P.pk === 'w' ? 'pkw' : 'pkl') : P.gf > P.ga ? 'nw' : P.gf === P.ga ? 'nd' : 'nl';
    return { kind, main: byR[0] ? byR[0][0] : null };
  }
  YA.paperDecide = decide; // 点検用
  function settleHead(w, P) {
    const d = decide(P);
    P.k = d.kind;
    P.main = d.main;
    P.hv = pickHv(w, d.kind, (w.seed | 0) * 7 + P.id * 131 + P.y);
    // 本人の一言
    const p = d.main && w.players[d.main];
    const row = P.rt.find((x) => x[0] === d.main);
    if (row) {
      const list = SAYS[sayKind(d.kind, P)];
      const base = list[(YA.hash(String(P.id) + d.main) >>> 0) % list.length];
      P.q = p && YA.voice ? YA.voice(p, base) : base;
    } else P.q = '';
  }
  // 記事に名前が出た子（主役・得点・アシスト・課題の子）
  function namedIds(P) {
    const s = new Set();
    if (P.main) s.add(P.main);
    for (const g of P.gl) if (g[1] === 1) { if (g[4]) s.add(g[4]); if (g[6]) s.add(g[6]); }
    if (P.kd && P.kd.pid) s.add(P.kd.pid);
    if (P.kz && P.kz.pid) s.add(P.kz.pid);
    return [...s];
  }
  function pressPush(list, e, max) {
    const i = list.findIndex((x) => x.i === e.i && x.y === e.y);
    if (i >= 0) list.splice(i, 1);
    list.push(e);
    while (list.length > max) {
      const j = list.findIndex((x) => !x.m); // 名前が出ただけの記事から消す
      list.splice(j >= 0 ? j : 0, 1);
    }
    return list;
  }
  function filePress(w, P) {
    const T = YA.paperText(w, P);
    for (const id of namedIds(P)) {
      const p = w.players[id];
      if (!p) continue;
      p.press = pressPush(p.press || [], { i: P.id, y: P.y, w: P.wk, h: T.hd, b: T.sub, o: P.opp, s: `${P.gf}-${P.ga}${P.pk ? '（PK）' : ''}`, c: P.lab, m: id === P.main ? 1 : 0 }, YA.PRESS_MAX);
    }
    // 見出しが変わったとき（試合のあとの場面で覚醒した）、前の主役の記事も直す
    for (const p of Object.values(w.players)) for (const e of p.press || []) if (e.i === P.id && e.y === P.y) { e.h = T.hd; e.b = T.sub; e.m = p.id === P.main ? 1 : 0; }
  }

  function before(w) {
    const L = w.league;
    const s = YA.paperOfficial(w);
    if (!s) return null;
    const o = { s };
    if (s.t === 'league' && L && L.table && L.done === s.n - 1) o.tbl = JSON.parse(JSON.stringify(L.table));
    return o;
  }
  function makePaper(w, m, opp, pre) {
    const H = m.home, AW = m.away;
    const gf = m.score.home, ga = m.score.away;
    const s = pre.s;
    w.paperN = (w.paperN || 0) + 1;
    const P = { id: w.paperN, y: w.year, wk: w.week, comp: YA.compOf ? YA.compOf(w, 'A') : '', lab: (opp && opp.kindLabel) || (YA.weekLabel ? YA.weekLabel(w) : ''), opp: oppShort(opp && opp.name), home: !!(opp && opp.home), gf, ga };
    // 得点：[時間, こちら1/相手0, 得点者の名前, アシストの名前, 得点者のid（こちら）, 効いた特性, アシストのid（こちら）]
    P.gl = (m.scenes || []).filter((sc) => sc.goal).map((sc) => {
      const t = sc.side === 'home' ? H : AW;
      const sp = t.players[sc.scorer];
      const ap = sc.assist ? t.players[sc.assist] : null;
      const fx = (sc.fx || []).find((f) => sp && f.pid === sp.id && (f.kind === 'trait' || f.kind === 'gold' || f.kind === 'awake'));
      return [sc.ml || sc.minute, sc.side === 'home' ? 1 : 0, sp ? sp.name : '', ap ? ap.name : '', sc.side === 'home' && sp ? sp.id : null, fx ? fx.tag : null, sc.side === 'home' && ap ? ap.id : null];
    }).sort((a, b) => minNum(a[0]) - minNum(b[0]));
    // 採点：[id, 名前, 位置, 採点, 分, 得点, アシスト, セーブ]
    const order = { GK: 0, DF: 1, MF: 2, FW: 3 };
    P.rt = Object.entries(H.players).filter(([, mp]) => mp.st && mp.st.minutes > 0).map(([id, mp]) => {
      const p = w.players[id];
      const pos = (H.startSlot && H.startSlot[id]) || (p && p.main) || mp.pos;
      return [id, mp.name, pos, Math.round(mp.st.rating * 10) / 10, Math.round(mp.st.minutes), mp.st.goals || 0, mp.st.assists || 0, mp.st.saves || 0, mp.pos];
    }).sort((a, b) => (order[a[8]] - order[b[8]]) || b[4] - a[4]).slice(0, 16);
    for (const r of P.rt) r.pop();
    P.st = [m.stats ? m.stats.home.shots : 0, m.stats ? m.stats.away.shots : 0, m.live && m.live.poss && m.live.poss.home + m.live.poss.away > 0 ? Math.round((m.live.poss.home / (m.live.poss.home + m.live.poss.away)) * 100) : null];
    // 初ゴール・初出場（A の公式戦の通算から。練習試合・フェスティバルは数えない）
    const FR = [YA.CUP_NAME && YA.CUP_NAME.tm, YA.CUP_NAME && YA.CUP_NAME.fest, 'Bチーム', 'その他'];
    const tot = (p) => { let n = 0, g = 0; for (const c of Object.values(p.comp || {})) if (FR.indexOf(c.c) < 0) { n += c.n; g += c.gl; } return { n, g }; };
    P.fg = []; P.db = [];
    for (const r of P.rt) {
      const p = w.players[r[0]];
      if (!p) continue;
      const t = tot(p);
      if (r[5] > 0 && t.g === r[5]) P.fg.push(r[0]);
      if (t.n === 1) P.db.push(r[0]);
    }
    // PK 戦（勝ち抜きの大会で引き分け）
    if (s.t === 'cup' && gf === ga) {
      const c = w.cup[s.cup];
      if (c && !c.group) P.pk = c.alive || c.result === '優勝' || c.result === '昇格' || c.finalPending ? 'w' : 'l';
    }
    // 気づきの場面（試合の途中で選んだもの）
    if (w._pKz && w._pKz.y === w.year && w._pKz.wk === w.week) P.kz = w._pKz;
    // 課題中の子の様子（出た子のうち、主役でない子を1人）
    const kp = P.rt.map((r) => w.players[r[0]]).filter((p) => p && p.kd && YA.kadaiState).sort((a, b) => (P.kz && a.id === P.kz.pid ? -1 : 0) - (P.kz && b.id === P.kz.pid ? -1 : 0) || a.kd.w0 - b.kd.w0);
    if (kp.length) { const p = kp[0]; const ks = YA.kadaiState(w, p); P.kd = { pid: p.id, n: p.name, lab: ks.name, word: ks.word, half: ks.half ? 1 : 0, g: p.grade }; }
    // 相手の監督
    const rc = (w.rivalCoaches || []).find((x) => x.teamName === (opp && opp.name));
    const d = rc && (YA.RIVAL_COACHES || []).find((x) => x.k === rc.k);
    if (d && YA.rivalPostText) P.rv = { n: d.name, t: d.title, line: YA.rivalPostText(rc.k, d.name, gf, ga, w.year, w.week + 1) };
    else if (opp && opp.coach && opp.coach.name) {
      const L = gf > ga ? OPP_SAY.they_lost : gf < ga ? OPP_SAY.they_won : OPP_SAY.draw;
      P.rv = { n: String(opp.coach.name).replace(/\s*(監督|コーチ)$/, ''), line: L[(YA.hash(String(P.id) + opp.name) >>> 0) % L.length] };
    }
    // ほかの会場と順位
    if (s.t === 'league' && w.league && pre.tbl) {
      const L = w.league;
      const ot = [];
      for (const [a, b] of L.rounds[s.n - 1] || []) {
        if (a === 'me' || b === 'me') continue;
        const t0 = pre.tbl[a], t1 = L.table[a];
        if (!t0 || !t1) continue;
        const ta = L.teams.find((x) => x.id === a), tb = L.teams.find((x) => x.id === b);
        ot.push([oppShort(ta && ta.name), oppShort(tb && tb.name), t1.gf - t0.gf, t1.ga - t0.ga]);
      }
      ot.sort((x, y) => y[2] + y[3] - (x[2] + x[3]) || Math.abs(y[2] - y[3]) - Math.abs(x[2] - x[3]));
      P.ot = ot.slice(0, 1);
    }
    if (w.league && YA.standings) {
      const st = YA.standings(w);
      const me = st.find((x) => x.me);
      const top = st[0];
      P.lg = w.league.level && YA.levelNames ? YA.levelNames(w)[w.league.level - 1] : P.comp;
      if (me && top) P.rk = [me.rank, st.length, me.p, oppShort(top.name), top.p, top.me ? 1 : 0, (w.league.done || 0)];
    }
    if (s.t === 'cup') {
      const c = w.cup[s.cup];
      const nm = s.cup === 'post' ? (c && c.kind === 'final' ? 'プレミアリーグ ファイナル' : '昇格のプレーオフ') : YA.CUP_NAME[s.cup];
      let t = '';
      if (c && c.group) t = c.groupDone ? (c.result || (c.finalPending ? `グループ${c.grank}位から勝ち上がり、決勝へ進んだ` : '')) : `グループ戦は残り${Math.max(0, (c.gopps || []).length - (c.gdone || 0))}試合`;
      else if (c && c.alive) t = `次は${YA.cupLabel(w, { cup: s.cup, round: s.round + 1 })}`;
      else if (c) t = c.result === '優勝' ? '優勝を決めた' : c.result || '';
      if (t) P.cp = [nm, t];
    }
    settleHead(w, P);
    w.papers = (w.papers || []).concat([P]).slice(-YA.PAPER_KEEP);
    filePress(w, P);
    return P;
  }

  // ---------- 試合のあと ----------
  const am0 = YA.applyMatch;
  YA.applyMatch = function (w, m, which, opp, scheduled) {
    let pre = null;
    try { if (which === 'A' && scheduled && m && m.home && m.score) pre = before(w); } catch (e) { pre = null; }
    const res = am0.apply(this, arguments);
    if (pre) {
      try { const P = makePaper(w, m, opp, pre); if (m) m._paper = P.id; } catch (e) { YA._paperErr = (YA._paperErr || []).concat([String(e && e.stack || e)]).slice(-5); }
    }
    delete w._pKz;
    return res;
  };
  // 気づきの場面の結果を紙面に：試合の途中（live）は作る前に、試合のあと（match）は作ったあとに直す
  const st0 = YA.kizukiSettle;
  if (st0) {
    YA.kizukiSettle = function (w, e, role) {
      const p = e && w.players[e.pid];
      const kn = p && p.kd && YA.kadaiDef ? (YA.kadaiDef(p.kd.t) || {}).name : '';
      const lab = p && p.kd && YA.kadaiLabel ? YA.kadaiLabel(w, p.kd.t, p.kd.c) : '';
      const r = st0.apply(this, arguments);
      try {
        if (r && p && r.kind !== 'gone' && (e.at === 'live' || e.at === 'match')) {
          const info = { y: e.year, wk: e.week, pid: p.id, n: p.name, kn, lab, form: p.aw ? p.aw.form : '', kind: r.kind, role, min: e.min || null, g: p.grade };
          if (e.at === 'live') w._pKz = info;
          else {
            const P = (w.papers || []).find((x) => x.y === e.year && x.wk === e.week);
            if (P) {
              const row = P.rt.find((x) => x[0] === p.id);
              const rl = (p.rl || [])[(p.rl || []).length - 1];
              if (row && rl && rl.y === e.year && rl.w === e.week && rl.r != null) row[3] = Math.round(rl.r * 10) / 10; // 試合のあとの場面で直した採点に合わせる
              if (!P.kz || P.kz.kind !== 'awake') {
                const was = P.k;
                P.kz = info;
                if (r.kind === 'awake' || was !== decide(P).kind) settleHead(w, P);
                filePress(w, P);
              }
            }
          }
        }
      } catch (er) { /* 形の違う場面 */ }
      return r;
    };
  }

  // ---------- 文を作る（材料から。毎回同じ文になる）----------
  YA.paperText = function (w, P) {
    const club = clubOf(w);
    const opp = P.opp || '相手';
    const rowOf = (id) => P.rt.find((x) => x[0] === id);
    const main = rowOf(P.main);
    const mainP = P.main && w.players[P.main];
    // 同じ名字の子が出ていたら、名前の1字を足す（「松田律」）。課題の名前の中のかぎかっこは外す
    const sc0 = {};
    for (const r of P.rt) sc0[sur(r[1])] = (sc0[sur(r[1])] || 0) + 1;
    const ownN = new Set(P.rt.map((r) => r[1]));
    const nm = (n) => { const s = sur(n); return ownN.has(n) && sc0[s] > 1 ? s + (String(n).split(' ')[1] || '').slice(0, 1) : s; };
    const L0 = (s) => String(s || '').replace(/[「」]/g, '');
    // 相手の得点者：こちらに同じ名字の子がいたら、相手のチーム名を添える
    const oppNm = (n) => (sc0[sur(n)] ? `${opp}の${sur(n)}` : sur(n));
    const S = main ? nm(main[1]) : club;
    const mineG = P.gl.filter((g) => g[1] === 1);
    const wg = P.k === 'win1' ? mineG[P.ga] : null;
    const firstOf = (id) => P.gl.find((g) => g[1] === 1 && g[4] === id);
    const c = { S, club, opp, gf: P.gf, ga: P.ga, n: main ? main[5] : 0, mw: wg ? minWord(wg[0]) : P.k === 'firstG' && firstOf(P.main) ? minWord(firstOf(P.main)[0]) : '', kn: P.kz ? P.kz.kn : '', form: P.kz ? P.kz.form : '', mins: main ? main[4] : 0 };
    const list = HL[P.k] || HL.nw;
    const hd = list[(P.hv | 0) % list.length](c);
    const grade = (id) => { const p = w.players[id]; return p ? p.grade : (P.kz && P.kz.pid === id ? P.kz.g : null); };
    const who = (row) => (row ? `${row[1]}${grade(row[0]) ? `（高${grade(row[0])}・${row[2]}）` : `（${row[2]}）`}` : '');
    const score = `${P.gf}-${P.ga}${P.pk ? `（PK戦で${P.pk === 'w' ? '勝利' : '敗退'}）` : ''}`;
    const SUB = {
      awake: () => `課題「${L0(P.kz.lab)}」から「${P.kz.form}」へ`,
      hat: () => `${c.n}得点・採点${main[3].toFixed(1)}`,
      win1: () => `${c.mw}に決勝点　${P.gf}-${P.ga}`,
      rout: () => `${P.gf}-${P.ga}　${opp}を圧倒`,
      crush: () => `${P.gf}-${P.ga}　${opp}に完敗`,
      firstG: () => `${grade(P.main) ? `高${grade(P.main)}・` : ''}${main[2]}　Aの公式戦で初ゴール`,
      debut: () => `${grade(P.main) ? `高${grade(P.main)}・` : ''}${main[2]}　Aの公式戦に初出場`,
    };
    // ふつうの試合の小見出しは、見出しとスコアが重ならないよう、チームでいちばんの採点の子
    const sub = SUB[P.k] && main ? SUB[P.k]() : main ? `チーム最高点は${S}（${main[3].toFixed(1)}）` : `${P.lab}　${score}`;
    // 1段落目：得点の流れ
    const flow = [];
    const where = P.home ? 'ホーム' : 'アウェイ';
    let a = 0, b = 0;
    const parts = [];
    for (const g of P.gl) {
      const before0 = a - b;
      if (g[1] === 1) a++; else b++;
      const mw = minWord(g[0]);
      if (g[1] === 1) {
        const v = a + b === 1 ? '先制' : before0 === 0 ? '勝ち越し' : before0 < 0 && a === b ? '同点に追いついた' : before0 < 0 ? '1点を返した' : 'リードを広げた';
        parts.push(`${mw}に${g[2] ? nm(g[2]) : 'オウンゴールで'}${g[2] ? 'が' : ''}${v === '同点に追いついた' || v === '1点を返した' ? '決めて' : ''}${v}${g[3] ? `（${nm(g[3])}のアシスト）` : ''}`);
      } else {
        const v = a + b === 1 ? '先制された' : before0 === 0 ? '勝ち越された' : before0 > 0 && a === b ? '同点にされた' : before0 > 0 ? '1点を返された' : '突き放された';
        parts.push(`${mw}に${g[2] ? `${oppNm(g[2])}に` : ''}${v}`);
      }
    }
    flow.push(`${P.lab}、${opp}戦（${where}）。`);
    if (!parts.length) flow.push('両チームとも最後まで点が入らなかった。');
    else if (parts.length <= 3) flow.push(parts.join('。') + '。');
    else {
      // 点が多い試合は、決めた子ごとにまとめる（紙面に収めるため）
      const by = (side) => { const o = []; for (const g of P.gl.filter((x) => x[1] === side)) { const k = g[2] ? (side ? nm(g[2]) : oppNm(g[2])) : 'オウンゴール'; let e = o.find((x) => x.k === k); if (!e) o.push((e = { k, t: [] })); e.t.push(minWord(g[0]).replace(/^(前半|後半)/, (s) => s.slice(0, 1))); } return o; };
      const mine = by(1), theirs = by(0);
      if (mine.length) flow.push(`得点は${mine.map((e) => `${e.k}（${e.t.join('・')}）`).join('、')}。`);
      if (theirs.length) flow.push(`失点は${theirs.map((e) => `${e.k}（${e.t.join('・')}）`).join('、')}。`);
    }
    const endW = P.gf > P.ga ? '勝った' : P.gf < P.ga ? '敗れた' : P.pk ? (P.pk === 'w' ? '引き分け、PK戦で勝ち上がった' : '引き分け、PK戦で敗れた') : '引き分けた';
    flow.push(`${club}は${P.gf}-${P.ga}で${endW}。`);
    if (P.st && P.st[0] != null) flow.push(`シュート${P.st[0]}本対${P.st[1]}本${P.st[2] != null ? `、保持${P.st[2]}%` : ''}。`);
    // 2段落目：主役
    const mp = [];
    if (main) {
      const fxs = P.gl.filter((g) => g[1] === 1 && g[4] === P.main && g[5]).map((g) => g[5]);
      if (P.k === 'awake') mp.push(`課題「${L0(P.kz.lab)}」に取り組んできた${who(main)}が、${P.kz.min ? minWord(P.kz.min) + 'の場面で' : '試合の中で'}目を覚ました。覚醒の形は「${P.kz.form}」。`);
      else if (P.k === 'hat') mp.push(`${who(main)}が${main[5]}得点。採点は${main[3].toFixed(1)}。`);
      else if (P.k === 'win1') mp.push(`決勝点は${minWord(wg[0])}、${who(main)}。${wg[3] ? `${nm(wg[3])}のパスを` : ''}決めきった。`);
      else if (P.k === 'firstG') mp.push(`${who(main)}が、Aの公式戦で初めてゴールを決めた（${minWord(firstOf(P.main)[0])}）。`);
      else if (P.k === 'debut') mp.push(`${who(main)}が、Aの公式戦に初めて出た。出場は${main[4]}分、採点は${main[3].toFixed(1)}。`);
      else if (P.k === 'crush') mp.push(`苦しい試合で気を吐いたのは${who(main)}（採点${main[3].toFixed(1)}）。`);
      else mp.push(`${main[3] >= 7 ? 'この試合で光ったのは' : 'チームで最も採点が高かったのは'}${who(main)}。採点は${main[3].toFixed(1)}${main[5] ? `、${main[5]}得点` : ''}${main[6] ? `、${main[6]}アシスト` : ''}${main[7] && main[2] === 'GK' ? `、セーブ${main[7]}本` : ''}。`);
      if (fxs.length) mp.push(`特性「${fxs[0]}」がゴールを生んだ。`);
      if (P.q) mp.push(`試合のあと、${nm(main[1])}は「${P.q}」と話した。`);
    }
    // 3段落目：課題中の子
    const kd = [];
    const kz = P.kz && P.kz.kind !== 'awake' ? P.kz : null;
    if (kz) {
      const S2 = nm(kz.n);
      const at = kz.min ? `${minWord(kz.min)}、` : '';
      kd.push(`課題「${L0(kz.lab)}」に取り組む${kz.n}（高${kz.g}）は、` + (kz.kind === 'clue' ? `${at}正しい選択をしたが、本人は首をかしげた。何かが違うらしい。` : kz.kind === 'safe' ? `${at}無難な選択でしのいだ。まだ殻は破れていない。` : `${at}判断を誤った。課題の壁は厚い。`) + (kz.kind === 'bad' ? `${S2}の顔は険しかった。` : ''));
    } else if (P.kd && P.kd.pid !== P.main && !(P.kz && P.kz.pid === P.kd.pid)) {
      kd.push(`課題「${L0(P.kd.lab)}」に取り組む${P.kd.n}（高${P.kd.g}）は${P.kd.word === '慣れてきた' ? '少しずつ慣れてきた様子だ' : P.kd.word === 'もがいている' ? 'まだもがいている' : P.kd.word === '自信をなくしている' ? '自信をなくしているように見えた' : '苦しんでいる'}。${P.kd.half ? '気づきの時は近いのか。' : 'まだ課題の前半だ。'}`);
    }
    // 4段落目：相手の監督
    const rv = [];
    if (P.rv) rv.push(P.rv.t ? `${P.rv.line.replace(/（[^）]*との関係[^）]*）$/, '')}` : `${opp}の${P.rv.n}監督は${P.rv.line}と話した。`);
    const paras = [flow.join(''), mp.join(''), kd.join(''), rv.join('')].filter(Boolean);
    // 採点の表と寸評
    const note = (r) => {
      if (r[5] >= 3) return `${r[5]}得点`;
      if (r[5] === 2) return r[6] ? '2得点1アシスト' : '2得点';
      if (r[5] === 1) return r[6] ? '1得点1アシスト' : '1得点';
      if (r[6]) return r[6] > 1 ? `${r[6]}アシスト` : 'アシスト';
      if (r[2] === 'GK') { if (P.ga === 0 && r[4] >= 60) return '完封'; if (r[7] >= 4) return `${r[7]}セーブ`; }
      if (P.kz && P.kz.kind === 'awake' && P.kz.pid === r[0]) return '覚醒';
      if (r[4] < 30) return '途中出場';
      const v = r[3];
      return v >= 8 ? '圧巻' : v >= 7.2 ? '存在感' : v >= 6.5 ? '堅実' : v >= 6 ? '及第点' : v >= 5.4 ? '精彩欠く' : '苦戦';
    };
    const rates = P.rt.map((r) => ({ id: r[0], name: nm(r[1]), pos: r[2], r: r[3], note: note(r), main: r[0] === P.main }));
    // 小さな記事
    const side = [];
    if (P.ot && P.ot[0]) { const o = P.ot[0]; side.push({ h: 'ほかの会場', t: `${o[0]} ${o[2]}-${o[3]} ${o[1]}` }); }
    if (P.cp) side.push({ h: P.cp[0], t: P.cp[1] });
    if (P.rk && side.length < 2) side.push({ h: P.lg || P.comp || 'リーグ', t: P.rk[5] ? `${club}が首位（勝ち点${P.rk[2]}）` : `${club}は${P.rk[0]}位（勝ち点${P.rk[2]}）。首位は${P.rk[3]}（${P.rk[4]}）` });
    return { hd, sub, paras, rates, side: side.slice(0, 2), date: YA.ywName ? YA.ywName(P.y, P.wk) : `${P.y}年目`, comp: P.comp, lab: P.lab, score, kind: P.k };
  };

  // ---------- 見せ方 ----------
  const faceOf = (w, id, px) => {
    try {
      const p = (w.players && w.players[id]) || (w.alumni || []).find((a) => a.id === id);
      return p && YA.faceEl ? YA.faceEl(w, p, px) : null;
    } catch (e) { return null; }
  };
  // 大見出し：全角の空きで行を分け、いちばん長い行が左の段（約205px）に収まる大きさにする
  const hdEl = (h, hd) => {
    const len = (s) => [...s].reduce((a, ch) => a + (/[\x20-\x7e]/.test(ch) ? 0.58 : 1), 0);
    // 長い行は「、」「！」のあとで折る
    const segs = [];
    for (const s of String(hd).split('　').filter(Boolean)) {
      const m = len(s) > 10 ? /^(.+?[、！])(.+)$/.exec(s) : null;
      if (m) segs.push(m[1], m[2]); else segs.push(s);
    }
    const L = Math.max(...segs.map(len));
    const fs = clamp(Math.floor(200 / L), 17, 25);
    return h('div', { class: 'np-hd', style: `font-size:${fs}px` }, ...segs.map((s) => h('span', {}, s)));
  };
  // 紙面（P は w.papers の1件）
  YA.paperEl = function (w, P) {
    const h = YA._ui.h;
    const T = YA.paperText(w, P);
    const main = P.rt.find((x) => x[0] === P.main);
    const ph = h('div', { class: 'np-photo' + (P.k === 'awake' ? ' gold' : '') },
      h('div', { class: 'np-face' }, faceOf(w, P.main, 70) || h('span', { class: 'np-noface' }, '写真なし')),
      h('div', { class: 'np-sc' }, h('b', {}, `${P.gf}-${P.ga}`), h('small', {}, clubOf(w)), h('small', {}, `対 ${P.opp}`), P.pk ? h('em', {}, P.pk === 'w' ? 'PK戦で勝利' : 'PK戦で敗退') : null, main ? h('small', { class: 'np-cap' }, `写真：${main[1]}（${main[2]}）`) : null));
    // 小さな記事（ほかの会場・順位・大会の進み）は記事の下に横並び
    const smalls = h('div', { class: 'np-smalls' }, ...T.side.map((s) => h('div', { class: 'np-small' }, h('b', {}, s.h), h('span', {}, s.t))));
    const left = h('div', { class: 'np-left' },
      h('div', { class: 'np-kick' }, T.lab),
      hdEl(h, T.hd),
      h('div', { class: 'np-sub' }, T.sub),
      ph);
    const body = h('div', { class: 'np-mid' }, h('div', { class: 'np-body' }, ...T.paras.map((t, i) => h('p', { class: i === 0 ? 'np-lead' : '' }, t))), smalls);
    const rate = h('div', { class: 'np-rate' }, h('div', { class: 'np-bh' }, '採点（10点満点）'),
      ...T.rates.map((r) => h('div', { class: 'np-rr' + (r.main ? ' main' : '') }, h('i', {}, r.pos), h('span', {}, r.name), h('b', {}, r.r.toFixed(1)), h('small', {}, r.note))));
    const side = h('div', { class: 'np-side' }, rate);
    return h('div', { class: 'np' + (P.k === 'awake' ? ' awake' : '') },
      h('div', { class: 'np-mast' }, h('b', { class: 'np-name' }, YA.PAPER_NAME), h('span', { class: 'np-no' }, `第${P.id}号`), h('span', { class: 'np-date' }, `${T.date}　${T.comp || ''}`)),
      h('div', { class: 'np-main' }, left, body, side));
  };
  // その試合の紙面（試合後の画面から）
  YA.paperOfMatch = (w, m) => (w && m && m._paper ? (w.papers || []).find((x) => x.id === m._paper) : null);
  // 紙面を窓で開く
  YA.paperModal = function (w, P) {
    const h = YA._ui.h;
    YA._v.modal((close) => h('div', { class: 'sheet-in np-win' }, YA.paperEl(w, P), h('div', { class: 'row', style: 'justify-content:flex-end;gap:6px' }, h('button', { class: 'btn pri sm', onclick: close }, '閉じる'))));
  };
  // 記事の一覧（選手の経歴・卒業生の経歴のページ）
  YA.pressEl = function (w, x) {
    const h = YA._ui && YA._ui.h;
    const list = (x.press || []).slice().reverse();
    if (!h || !list.length) return null;
    return h('div', { class: 'np-list' }, ...list.map((e) => {
      const P = (w.papers || []).find((q) => q.id === e.i && q.y === e.y);
      const dup = e.c && String(e.b || '').indexOf(e.c) === 0; // 小見出しが「節　スコア」だけなら出さない
      return h('div', { class: 'np-item' + (e.m ? ' main' : '') },
        h('div', { class: 'np-it' },
          h('small', {}, `${YA.ywName ? YA.ywName(e.y, e.w) : e.y + '年目'}　${e.c || ''}　${e.o}戦 ${e.s}　`, h('span', { class: 'np-tag' + (e.m ? ' main' : '') }, e.m ? '主役' : '名前が出た')),
          h('b', {}, e.h),
          dup ? null : h('div', { class: 'np-ib' }, e.b)),
        P ? h('button', { class: 'btn sm', onclick: () => YA.paperModal(w, P) }, '紙面を開く') : h('span', { class: 'np-old' }, '紙面は残っていません'));
    }));
  };

  // ---------- 卒業生へ ----------
  const ae0 = YA.alumniEntry;
  if (ae0) {
    YA.alumniEntry = function (w, p) {
      const a = ae0.apply(this, arguments);
      try {
        const ls = (p.press || []).slice();
        if (ls.length) {
          const mains = ls.filter((e) => e.m);
          const keep = mains.slice(-YA.PRESS_ALUMNI);
          for (const e of ls.slice().reverse()) { if (keep.length >= YA.PRESS_ALUMNI) break; if (!e.m) keep.push(e); }
          a.press = keep.sort((x, y) => x.y - y.y || x.w - y.w);
        }
      } catch (e) { /* 形の違う子 */ }
      return a;
    };
  }
  // 経歴のページ（卒業生）に「記事」を足す。窓（YA._v.modal）で開くので、窓の中身を作るところで足す（records.js と同じ形）
  const cp0 = YA.careerPage;
  if (cp0) {
    YA.careerPage = function (w, a) {
      const v = YA._v;
      const m0 = v && v.modal;
      if (m0 && (a.press || []).length) v.modal = (build) => m0((close) => {
        const el = build(close);
        try {
          const h = YA._ui.h;
          const pe = YA.pressEl(w, a);
          if (pe) el.append(h('div', { class: 'careerpress', style: 'display:flex;flex-direction:column;gap:4px;margin-top:6px' }, h('div', { class: 'h' }, `新聞の記事（${YA.PAPER_NAME}）`), pe));
        } catch (e) { /* 形の違う画面 */ }
        return el;
      });
      try { return cp0.apply(this, arguments); } finally { if (m0) v.modal = m0; }
    };
  }
})();
