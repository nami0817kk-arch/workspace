// 日程・リーグ（12チームの総当たり22試合）・夏と冬の大会・順位表・相手の分析・映像ミーティング。
// 状態は w.league / w.cup / w.h2h に入れ、JSON でそのまま保存できる。
(function () {
  'use strict';
  const YA = (globalThis.YA = globalThis.YA || {});
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

  // ---------- 1年の日程（40週）----------
  // 1〜9週 リーグ前半／10〜12週 夏の全国大会／13〜25週 リーグ後半／26週 夏合宿／27〜30週 冬の大会
  // 33週 セレクション／36週 U-15の内部昇格の相談／40週 卒業式
  YA.SCHED = function (week) {
    if (week <= 9) return { t: 'league', n: week };
    if (week <= 12) return { t: 'cup', cup: 'summer', round: week - 9 };
    if (week <= 25) return { t: 'league', n: week - 3 };
    if (week === 26) return { t: 'camp' };
    if (week >= 27 && week <= 30) return { t: 'cup', cup: 'winter', round: week - 26 };
    if (week === 33) return { t: 'selection' };
    if (week === 36) return { t: 'internal' };
    if (week === 40) return { t: 'ceremony' };
    return { t: 'none' };
  };
  YA.weekLabel = function (w) {
    const s = YA.SCHED(w.week);
    if (s.t === 'league') return `リーグ第${s.n}節`;
    if (s.t === 'cup') return (s.cup === 'summer' ? '夏の全国大会' : '冬のカップ戦') + ` ${s.round}回戦`;
    return { camp: '夏合宿・遠征', selection: 'セレクション', internal: 'U-15の内部昇格', ceremony: '卒業式', none: '' }[s.t];
  };
  // 今週あるA戦。なければ null
  YA.matchOf = function (w) {
    const s = YA.SCHED(w.week);
    if (s.t === 'league') return s;
    if (s.t === 'cup' && w.cup && w.cup[s.cup] && w.cup[s.cup].alive) return s;
    return null;
  };
  YA.hasMatch = (week, w) => (w ? !!YA.matchOf(w) : week <= 30);

  // ---------- リーグ ----------
  const AREAS = ['横浜', '川崎', '相模原', '千葉', '埼玉', '東京', '茨城', '静岡', '山梨', '栃木', '群馬', '長野', '船橋', '柏', '浦和', '藤沢'];
  const NICK = ['ブルーウィング', 'シルバーホーク', 'アルバトロス', 'グリーンリーフ', 'ノースウィンド', 'サンライズ', 'レッドフォックス', 'ブラックベアーズ', 'ホワイトタイガース', 'ゴールデンイーグル', 'ミストラル', 'クレセント'];
  const HS = ['学院高校', '第一高校', '東高校', '南高校', '北高校', '工業高校', '大付属高校', '商業高校'];
  const COACH_SUR = ['久保田', '榊原', '宮本', '日高', '三宅', '桐生', '黒川', '森山', '柳', '神崎', '藤堂', '西園寺'];
  const COACH_KIND = [
    ['戦術家', '細かい戦術で相手の弱点を突く'],
    ['熱血', '前から激しく、最後まで走らせる'],
    ['守備固め', 'まず失点しない。引いて守って一発を狙う'],
    ['育成派', '若手を積極的に使い、技術で崩す'],
    ['勝負師', '終盤の采配で勝ちを拾いにくる'],
  ];
  const STYLE_DESC = { power: '体が強く、前から奪いにくる', tech: 'つないで崩す技術派', defend: '堅守速攻。裏抜けに注意' };

  function levelBase(level) {
    return [12.4, 11.3, 10.2][level - 1];
  }
  YA.LEVEL_NAMES = ['全国リーグ', '地域リーグ', '県リーグ'];
  YA.LEVEL_EXP = [1, 0.8, 0.6]; // 試合の経験値（決定62：全国＞地域＞県）

  YA.newLeague = function (w) {
    const r = YA.rngOf(w.seed * 91 + w.year * 313 + (w.level || 2) * 7);
    const level = w.leagueLevel || 2;
    const used = new Set();
    const teams = [];
    for (let i = 0; i < 11; i++) {
      const kind = r.chance(0.55) ? 'club' : 'high';
      let name;
      do name = kind === 'club' ? r.pick(AREAS) + ' ' + r.pick(NICK) + 'ユース' : r.pick(AREAS) + r.pick(HS);
      while (used.has(name));
      used.add(name);
      const style = r.pick(['power', 'tech', 'defend']);
      const ck = r.pick(COACH_KIND);
      teams.push({
        id: 't' + i, name, short: name.length > 9 ? name.slice(0, 9) : name, kind, style,
        lvl: Math.round((levelBase(level) + w.year * 0.12 + (r() - 0.5) * 1.8 + (kind === 'club' ? 0.3 : 0)) * 10) / 10,
        formation: r.pick(['4-4-2', '4-3-3', '5-3-2', '4-2-3-1']), tactic: { power: 'ハイプレス', tech: 'ポゼッション', defend: '堅守' }[style],
        color: r.pick(['#c0392b', '#2c3e50', '#7f8c8d', '#8e44ad', '#d35400', '#16a085']),
        coach: { name: r.pick(COACH_SUR) + ' ' + r.pick(['監督', 'コーチ']), kind: ck[0], note: ck[1] },
      });
    }
    teams.push({ id: 'me', name: w.clubName, short: 'レガーレ', me: true });
    // 総当たり（サークル法）。22節
    const ids = teams.map((t) => t.id);
    const rounds = [];
    const arr = ids.slice();
    for (let k = 0; k < 11; k++) {
      const pairs = [];
      for (let i = 0; i < 6; i++) {
        const a = arr[i];
        const b = arr[11 - i];
        pairs.push(k % 2 === 0 ? [a, b] : [b, a]);
      }
      rounds.push(pairs);
      arr.splice(1, 0, arr.pop());
    }
    const second = rounds.map((rd) => rd.map(([a, b]) => [b, a]));
    const order = rounds.concat(second);
    // 自分が毎節ホームの偏りにならないよう、並びをかき混ぜる（節の順番だけ）
    const tbl = {};
    for (const t of teams) tbl[t.id] = { p: 0, w: 0, d: 0, l: 0, gf: 0, ga: 0 };
    w.league = { level, teams, rounds: order, table: tbl, done: 0, year: w.year };
  };

  YA.newCup = function (w) {
    const r = YA.rngOf(w.seed * 57 + w.year * 211);
    const mk = (n, base) => Array.from({ length: n }, (_, i) => {
      const name = r() < 0.5 ? r.pick(AREAS) + r.pick(HS) : r.pick(AREAS) + ' ' + r.pick(NICK) + 'ユース';
      const style = r.pick(['power', 'tech', 'defend']);
      return { id: 'c' + i, name, short: name.length > 9 ? name.slice(0, 9) : name, style, lvl: Math.round((base + i * 0.55 + (r() - 0.5)) * 10) / 10, formation: r.pick(['4-4-2', '4-3-3', '5-3-2']), tactic: { power: 'ハイプレス', tech: 'ポゼッション', defend: '堅守' }[style], color: r.pick(['#c0392b', '#2c3e50', '#8e44ad', '#d35400']), coach: { name: r.pick(COACH_SUR) + ' 監督', kind: r.pick(COACH_KIND)[0], note: '' } };
    });
    const base = levelBase(w.leagueLevel || 2) - 0.3 + w.year * 0.12;
    w.cup = { summer: { alive: true, round: 0, opps: mk(3, base), result: null }, winter: { alive: true, round: 0, opps: mk(4, base - 0.2), result: null } };
  };

  // 今週の相手（試合用の定義）
  YA.opponentOf = function (w) {
    const s = YA.matchOf(w);
    if (!s || !w.league) {
      // 旧データの互換：週ごとに作る
      const r = YA.rngOf(w.seed * 31 + w.year * 1000 + w.week * 7);
      const style = r.pick(['power', 'tech', 'defend']);
      return { id: 'o' + w.week, name: r.pick(AREAS) + r.pick(HS), short: '相手', color: '#c0392b', lvl: 10 + w.year * 0.3, formation: '4-4-2', tactic: { power: 'ハイプレス', tech: 'ポゼッション', defend: '堅守' }[style], desc: STYLE_DESC[style], style, home: r.chance(0.5) };
    }
    let t;
    let home = true;
    if (s.t === 'league') {
      const pair = w.league.rounds[s.n - 1].find((p) => p.indexOf('me') >= 0);
      const oid = pair[0] === 'me' ? pair[1] : pair[0];
      home = pair[0] === 'me';
      t = w.league.teams.find((x) => x.id === oid);
    } else {
      t = w.cup[s.cup].opps[s.round - 1];
      home = s.round % 2 === 1;
    }
    return Object.assign({}, t, { id: t.id + '_' + w.year + '_' + w.week, desc: STYLE_DESC[t.style] + (t.coach && t.coach.note ? '／' + t.coach.name + '：' + t.coach.note : ''), home, kindLabel: s.t === 'league' ? `リーグ第${s.n}節` : (s.cup === 'summer' ? '夏の全国大会' : '冬のカップ戦') + ` ${s.round}回戦` });
  };

  // ポアソン風の得点（他クラブ同士の試合用）
  function goalsOf(r, att, def, home) {
    const lam = clamp(1.25 + (att - def) * 0.3 + (home ? 0.18 : 0), 0.25, 4);
    let g = 0;
    let p = Math.exp(-lam);
    let s = p;
    const u = r();
    while (u > s && g < 8) {
      g++;
      p *= lam / g;
      s += p;
    }
    return g;
  }
  function addTable(tbl, a, b, ga, gb) {
    const t = tbl[a];
    const u = tbl[b];
    t.gf += ga; t.ga += gb; u.gf += gb; u.ga += ga;
    if (ga > gb) { t.w++; t.p += 3; u.l++; } else if (ga < gb) { u.w++; u.p += 3; t.l++; } else { t.d++; u.d++; t.p++; u.p++; }
  }
  // 自分の試合のあと、同じ節の他の試合を回して順位表を進める
  YA.leagueAdvance = function (w, n, myScore) {
    const L = w.league;
    if (!L || L.done >= n) return;
    // 飛ばした節（途中からのデータ）は、他クラブ同士だけ先に回す
    for (let k = L.done + 1; k < n; k++) YA.leagueAdvance(w, k, null);
    const r = YA.rngOf(w.seed * 19 + w.year * 101 + n);
    for (const [a, b] of L.rounds[n - 1]) {
      if (a === 'me' || b === 'me') {
        if (myScore) {
          if (a === 'me') addTable(L.table, 'me', b, myScore[0], myScore[1]);
          else addTable(L.table, a, 'me', myScore[1], myScore[0]);
        }
        continue;
      }
      const ta = L.teams.find((x) => x.id === a);
      const tb = L.teams.find((x) => x.id === b);
      addTable(L.table, a, b, goalsOf(r, ta.lvl, tb.lvl, true), goalsOf(r, tb.lvl, ta.lvl, false));
    }
    L.done = n;
  };
  YA.standings = function (w) {
    const L = w.league;
    const rows = L.teams.map((t) => Object.assign({ id: t.id, name: t.name, me: !!t.me }, L.table[t.id]));
    rows.forEach((x) => (x.gd = x.gf - x.ga));
    rows.sort((a, b) => b.p - a.p || b.gd - a.gd || b.gf - a.gf);
    rows.forEach((x, i) => (x.rank = i + 1));
    return rows;
  };
  YA.myRank = (w) => (w.league ? YA.standings(w).find((x) => x.me).rank : 6);

  // A戦の結果を、順位表・大会・対戦成績に反映する
  YA.recordMatch = function (w, m, opp) {
    const s = YA.matchOf(w);
    if (!s) return;
    const gf = m.score.home;
    const ga = m.score.away;
    const oid = (opp.id || '').split('_')[0];
    w.h2h = w.h2h || {};
    const key = opp.name;
    const h = (w.h2h[key] = w.h2h[key] || [0, 0, 0]);
    if (gf > ga) h[0]++;
    else if (gf === ga) h[1]++;
    else h[2]++;
    if (s.t === 'league') YA.leagueAdvance(w, s.n, opp.home ? [gf, ga] : [gf, ga]);
    else {
      const c = w.cup[s.cup];
      let win = gf > ga;
      let pk = '';
      if (gf === ga) {
        const r = YA.rngOf(w.seed * 7 + w.week * 13 + w.year);
        win = r() < 0.5 + (w.rep || 40) / 1000;
        pk = win ? '（PK戦で勝利）' : '（PK戦で敗退）';
      }
      c.round = s.round;
      if (!win) {
        c.alive = false;
        c.result = `${s.round}回戦で敗退${pk}`;
        w.inbox.push({ week: w.week, year: w.year, tier: 2, text: (s.cup === 'summer' ? '夏の全国大会' : '冬のカップ戦') + `は${s.round}回戦で敗退。` });
      } else if (s.round >= c.opps.length) {
        c.alive = false;
        c.result = '優勝';
        w.trophies = (w.trophies || []).concat([{ year: w.year, name: s.cup === 'summer' ? '夏の全国大会' : '冬のカップ戦', rank: '優勝' }]);
        w.inbox.push({ week: w.week, year: w.year, tier: 1, text: (s.cup === 'summer' ? '夏の全国大会' : '冬のカップ戦') + 'で優勝しました！' });
        if (w.club) w.club.rep = clamp(w.club.rep + 4, 0, 100);
      } else w.inbox.push({ week: w.week, year: w.year, tier: 3, text: (s.cup === 'summer' ? '夏の全国大会' : '冬のカップ戦') + `の${s.round}回戦を突破${pk}` });
    }
  };

  // リーグの終わり（25週の節のあと）に昇格・降格を決める
  YA.leagueEnd = function (w) {
    const L = w.league;
    if (!L || L.ended) return null;
    // 残りの節を回して閉じる
    for (let n = L.done + 1; n <= 22; n++) YA.leagueAdvance(w, n, null);
    const rows = YA.standings(w);
    const me = rows.find((x) => x.me);
    L.ended = true;
    let move = 0;
    if (me.rank <= 2 && L.level > 1) move = -1;
    if (me.rank >= 11 && L.level < 3) move = 1;
    L.finalRank = me.rank;
    w.lastStandings = rows;
    w.leagueHist = (w.leagueHist || []).concat([{ year: w.year, level: L.level, rank: me.rank, pts: me.p }]);
    w.nextLevel = L.level + move;
    w.leagueEndMove = move;
    return { rank: me.rank, move };
  };

  // ---------- 相手の分析（分析担当の力で深さが変わる）----------
  YA.analysisLevel = function (w) {
    const a = YA.staffAb ? YA.staffAb(w, '分析') : 5;
    return a >= 14 ? 3 : a >= 10 ? 2 : a >= 6 ? 1 : 0;
  };
  YA.analysis = function (w, oppTeam, opp) {
    const lv = YA.analysisLevel(w);
    const out = [];
    out.push(`型：${oppTeam.tactic.type} / 布陣：${oppTeam.formation}`);
    if (opp.coach) out.push(`指導者：${opp.coach.name}（${opp.coach.kind}）${opp.coach.note ? '：' + opp.coach.note : ''}`);
    const h = w.h2h && w.h2h[opp.name];
    if (h) out.push(`通算の対戦成績：${h[0]}勝 ${h[1]}分 ${h[2]}敗`);
    if (lv >= 1) {
      const key = oppTeam.lineup.slice(1).map((s) => oppTeam.players[s.pid]).sort((a, b) => YA.ovr(b) - YA.ovr(a)).slice(0, lv >= 2 ? 3 : 1);
      for (const p of key) out.push(`要注意：${p.num}番 ${p.name}（${p.pos}）${p.traits.length ? '特性「' + p.traits.join('・') + '」' : ''}`);
    }
    if (lv >= 2) {
      const t = oppTeam.tactic;
      if (t.line > 0.7) out.push('最終ラインが高い。裏への抜け出しが効く');
      else if (t.line < 0.3) out.push('引いて守る。クロスやミドルシュートが有効');
      if (t.press > 0.7) out.push('前から激しく来る。ロングボールやサイドチェンジで外したい');
      const gk = oppTeam.players[oppTeam.lineup[0].pid];
      out.push(`GK ${gk.name}：` + (YA.ovr(gk) < 10 ? '安定感に欠ける。遠めからも打っていい' : '手堅い'));
    }
    if (lv >= 3) {
      const mine = YA.teamFromWorld(w, 'A');
      const sug = oppTeam.tactic.line > 0.6 ? 'カウンター' : oppTeam.tactic.press > 0.7 ? 'ポゼッション' : oppTeam.tactic.line < 0.3 ? 'サイド攻撃' : 'ハイプレス';
      out.push(`おすすめの戦い方：${sug}（分析担当の提案）`);
    }
    if (lv === 0) out.push('分析担当がいないため、深い分析はできません（クラブ→スタッフ）');
    return out;
  };

  // ---------- 映像ミーティング（試合のあと。取り上げた場面で伸び方が変わる）----------
  YA.videoOptions = function (w, m) {
    const out = [];
    for (const sc of m.scenes) {
      const mine = sc.side === 'home';
      const ids = [];
      if (mine && sc.shooter && m.home.players[sc.shooter]) ids.push(sc.shooter);
      for (const k of Object.keys(sc.actors || {})) if (mine && m.home.players[sc.actors[k]] && ids.indexOf(sc.actors[k]) < 0) ids.push(sc.actors[k]);
      if (!mine) for (const d of sc.defs || []) if (m.home.players[d] && ids.indexOf(d) < 0) ids.push(d);
      if (!ids.length) continue;
      const good = mine ? sc.goal || sc.outcome === 'saved' : ['intercepted', 'cleared', 'stopped', 'dispossessed', 'escaped', 'offside', 'blocked'].indexOf(sc.outcome) >= 0;
      const text = sc.beats[sc.beats.length - 1].text;
      out.push({ id: sc.id, minute: sc.minute, text, good, pid: ids[0], name: sc.typeName });
    }
    return out.slice(0, 10);
  };
  YA.videoApply = function (w, picks) {
    const msgs = [];
    for (const v of picks) {
      const p = w.players[v.pid];
      if (!p) continue;
      const ab = ['判断', '予測', 'ポジショニング', 'チームワーク'];
      const amt = v.good ? 0.5 : 0.9;
      for (const a of ab) p.prog[a] = (p.prog[a] || 0) + amt / 2;
      if (v.good) {
        p.conf = clamp(p.conf + 3, 0, 100);
        msgs.push(`${p.num}番 ${p.name.split(' ')[0]}：いい場面を共有。自信 +3、戦術の理解が少し深まった`);
      } else {
        const sensitive = p.pers['気持ちの強さ'] === '繊細';
        const fighter = p.pers['教えの受け止め方'] === '反骨心' || p.pers['気持ちの強さ'] === '負けず嫌い';
        const d = fighter ? 2 : sensitive ? -6 : -2;
        p.conf = clamp(p.conf + d, 0, 100);
        msgs.push(`${p.num}番 ${p.name.split(' ')[0]}：失敗の場面を振り返った。` + (fighter ? '悔しさをバネにした（自信 +2）' : sensitive ? '強く落ち込んだ（自信 -6）' : '課題は見えた（自信 -2）') + '。戦術の理解は大きく深まった');
      }
    }
    return msgs;
  };
})();
