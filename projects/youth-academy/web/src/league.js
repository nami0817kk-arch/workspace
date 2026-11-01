// 日程・リーグ（12チームの総当たり22試合）・夏と冬の大会・順位表・相手の分析・映像ミーティング。
// 状態は w.league / w.cup / w.h2h に入れ、JSON でそのまま保存できる。
(function () {
  'use strict';
  const YA = (globalThis.YA = globalThis.YA || {});
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

  // ---------- 1年の日程（40週）----------
  // 1〜9週 リーグ前半／10〜12週 夏の全国大会／13〜25週 リーグ後半／26週 夏合宿／27〜30週 冬の大会
  // 40週 卒業式。入団の暦は scout.js（25〜27週 内部昇格／1〜27週 スカウト・28週に返事／31〜34週 セレクション）
  YA.SCHED = function (week) {
    if (week <= 9) return { t: 'league', n: week };
    if (week <= 12) return { t: 'cup', cup: 'summer', round: week - 9 };
    if (week <= 25) return { t: 'league', n: week - 3 };
    if (week === 26) return { t: 'camp' };
    if (week >= 27 && week <= 30) return { t: 'cup', cup: 'winter', round: week - 26 };
    if (week === 40) return { t: 'ceremony' };
    return { t: 'none' };
  };
  YA.weekLabel = function (w) {
    const s = YA.SCHED(w.week);
    if (s.t === 'league') return `リーグ第${s.n}節`;
    if (s.t === 'cup') return (s.cup === 'summer' ? '夏の全国大会' : '冬のカップ戦') + ` ${s.round}回戦`;
    const lab = { camp: '夏合宿・遠征', ceremony: '卒業式', none: '' }[s.t];
    if (lab) return lab;
    if (YA.scoutWindow && w.scouting) {
      const wn = YA.scoutWindow(w);
      if (wn.sel) return 'セレクション（1月）';
      if (w.week === YA.SCOUT_RESULT_WEEK) return 'スカウトの返事（12月）';
    }
    return '';
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
  const NICK = ['ブルーウィング', 'シルバーホーク', 'アルバトロス', 'グリーンリーフ', 'ノースウィンド', 'サンライズ', 'レッドフォックス', 'ブラックベアーズ', 'ホワイトタイガース', 'ゴールデンイーグル', 'ミストラル', 'クレセント', 'スターズ', 'ライトニング', 'ドルフィンズ', 'ファルコンズ', 'ブルーオーシャン', 'レッドウルブズ', 'グリーンパンサーズ', 'シルバーレイクス', 'ブレイブハーツ', 'フレイムス', 'サンダーバーズ', 'ホワイトウィングス', 'ネイビーアンカーズ', 'オレンジコメッツ', 'パープルレイン', 'アクアマリン', 'ストームライダーズ', 'ルミナス', 'ヴァイキングス', 'マリンブルー', 'アストラ', 'ブリザーズ', 'ガーネット', 'エメラルド', 'サファイア'];
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
    return [10.9, 9.8, 8.7][level - 1];
  }
  YA.LEVEL_NAMES = ['全国リーグ', '地域リーグ', '県リーグ'];
  YA.LEVEL_EXP = [1, 0.8, 0.6]; // 試合の経験値（決定62：全国＞地域＞県）

  // ---------- プロクラブの表（地域名は実在の町、愛称は固定）。トップチーム・卒業生の移籍先・ユースのリーグの相手に使う ----------
  // [町, 地域, 愛称, はじめの部（1=J1・2=J2・3=J3）]
  YA.REGIONS = ['北海道・東北', '関東', '中部', '関西', '中国・四国', '九州'];
  YA.PRO_CLUBS = [
    ['札幌', 0, 'ボレアス', 1], ['仙台', 0, 'ルーチェ', 2], ['山形', 0, 'モンテ', 2], ['秋田', 0, 'ブルーノ', 3], ['盛岡', 0, 'フェッロ', 3], ['福島', 0, 'ヴィアーレ', 3],
    ['横浜', 1, 'オンダス', 1], ['川崎', 1, 'ヴェローチェ', 1], ['浦和', 1, 'ロッソーネ', 1], ['鹿島', 1, 'アルマーダ', 1], ['柏', 1, 'フォーリア', 1], ['東京', 1, 'カピターレ', 1], ['町田', 1, 'コリーナ', 1],
    ['湘南', 1, 'レガーレ', 2], ['千葉', 1, 'マーレ', 2], ['大宮', 1, 'アルコ', 2], ['水戸', 1, 'ヴィータ', 2], ['甲府', 1, 'ウーヴァ', 2], ['栃木', 1, 'カステロ', 3], ['群馬', 1, 'ヴェント', 3], ['相模原', 1, 'ステッラ', 3],
    ['新潟', 2, 'アルベ', 1], ['清水', 2, 'オーラ', 1], ['名古屋', 2, 'グランデ', 1], ['磐田', 2, 'スピーガ', 2], ['藤枝', 2, 'ラーマ', 2], ['金沢', 2, 'オーロ', 3], ['松本', 2, 'モンターニャ', 3], ['長野', 2, 'ネーヴェ', 3], ['岐阜', 2, 'フィウメ', 3],
    ['大阪', 3, 'ソーレ', 1], ['京都', 3, 'アンティカ', 1], ['神戸', 3, 'ブリッツァ', 1], ['奈良', 3, 'ルーナ', 3], ['滋賀', 3, 'ラーゴ', 3],
    ['岡山', 4, 'ペスカ', 1], ['広島', 4, 'フェニーチェ', 1], ['徳島', 4, 'コルサ', 2], ['愛媛', 4, 'アランチャ', 2], ['山口', 4, 'ローザ', 2], ['今治', 4, 'ナーヴェ', 2], ['高知', 4, 'マレア', 3], ['鳥取', 4, 'ドゥーナ', 3],
    ['福岡', 5, 'ヴェルデ', 1], ['長崎', 5, 'ナーヴィ', 1], ['鳥栖', 5, 'ステラーレ', 2], ['大分', 5, 'フォンテ', 2], ['熊本', 5, 'カステッロ', 2], ['北九州', 5, 'アッチャイオ', 3], ['鹿児島', 5, 'ヴルカーノ', 3], ['宮崎', 5, 'パルマ', 3],
  ].map(([city, region, nick, tier]) => ({ city, region, nick, tier, name: city + ' ' + nick }));
  // 地域ごとの、Jクラブのない町（高校の名前に使う）
  const REGION_TOWNS = [
    ['青森', '八戸', '函館', '旭川', '郡山', 'いわき', '石巻', '酒田'],
    ['船橋', '藤沢', '八王子', '前橋', '宇都宮', '川越', '市原', '平塚', '流山', '越谷'],
    ['富山', '福井', '浜松', '豊田', '四日市', '静岡', '上田', '沼津'],
    ['堺', '西宮', '姫路', '和歌山', '大津', '尼崎', '枚方', '宇治'],
    ['倉敷', '福山', '松江', '下関', '高松', '松山', '呉', '米子'],
    ['佐賀', '久留米', '那覇', '延岡', '佐世保', '日田', '飯塚', '都城'],
  ];
  YA.regionOf = function (clubName) {
    const n = String(clubName || '').replace(/U-18$/, '').trim();
    const c = YA.PRO_CLUBS.find((x) => n === x.name) || YA.PRO_CLUBS.find((x) => n.indexOf(x.city) === 0);
    return c ? c.region : 1;
  };
  YA.proClubOf = function (clubName) {
    const n = String(clubName || '').replace(/U-18$/, '').trim();
    return YA.PRO_CLUBS.find((x) => n === x.name) || null;
  };
  // ユースのリーグの相手：全国＝全地域のJクラブのユースと強豪校、地域・県＝同じ地域のクラブと高校
  const POOLS = {};
  YA.clubPool = function (region) {
    if (POOLS[region]) return POOLS[region];
    const r = YA.rngOf(60601 + region * 97);
    const out = [];
    const used = new Set();
    const add = (name, kind, level) => {
      if (used.has(name)) return;
      used.add(name);
      const style = r.pick(['power', 'tech', 'defend']);
      const ck = r.pick(COACH_KIND);
      out.push({ id: 'R' + region + '-' + out.length, name, kind, style, level, edge: Math.round((r() - 0.5) * 1.6 * 10) / 10, coach: { name: r.pick(COACH_SUR) + ' ' + r.pick(['監督', 'コーチ']), kind: ck[0], note: ck[1] } });
    };
    // 全国（1部）：J1のユース11と、各地の強豪校
    const j1 = YA.PRO_CLUBS.filter((c) => c.tier === 1);
    for (const c of j1.map((c) => ({ c, k: r() })).sort((a, b) => a.k - b.k).slice(0, 12).map((x) => x.c)) add(c.name + 'U-18', 'club', 1);
    while (out.filter((x) => x.level === 1).length < 20) add(r.pick(REGION_TOWNS[r.int(0, 5)]) + r.pick(HS), 'high', 1);
    // 地域（2部）：同じ地域のJクラブのユースと、地域の高校
    const mine = YA.PRO_CLUBS.filter((c) => c.region === region);
    for (const c of mine) add(c.name + 'U-18', 'club', 2);
    let g = 0;
    while (out.filter((x) => x.level === 2).length < 20 && g++ < 200) add(r.pick(REGION_TOWNS[region].concat(mine.map((c) => c.city))) + r.pick(HS), 'high', 2);
    // 県（3部）：地域の高校と、Jクラブの2つ目のチーム
    for (const c of mine.slice(0, 4)) add(c.name + 'U-18 B', 'club', 3);
    g = 0;
    while (out.filter((x) => x.level === 3).length < 20 && g++ < 300) add(r.pick(REGION_TOWNS[region].concat(mine.map((c) => c.city))) + r.pick(HS), 'high', 3);
    POOLS[region] = out;
    return out;
  };
  // 自分のクラブの地域の60クラブ（各部20）。古い名前（CLUB60）は関東の表を指す
  Object.defineProperty(YA, 'CLUB60', { get: () => YA.clubPool(1), configurable: true });
  // チームの短い名前（愛称）
  YA.shortName = (name) => String(name || '').replace(/U-18$/, '').split(' ').pop() || name;

  YA.newLeague = function (w) {
    const r = YA.rngOf(w.seed * 91 + w.year * 313 + (w.level || 2) * 7);
    const level = w.leagueLevel || 2;
    const used = new Set();
    const teams = [];
    // 同じ部の20クラブから11を選ぶ（自分のクラブと同名は除く）。名前の書き換えは w.rename に残る
    const pool = YA.clubPool(YA.regionOf(w.clubName)).filter((c) => c.level === level && c.name !== w.clubName);
    const pick = pool.map((c) => ({ c, k: r() })).sort((a, b) => a.k - b.k).slice(0, 11).map((x) => x.c);
    for (let i = 0; i < 11; i++) {
      const c = pick[i];
      const kind = c.kind;
      const name = (w.rename && w.rename[c.id]) || c.name;
      used.add(name);
      const style = c.style;
      const ck = [c.coach.kind, c.coach.note];
      teams.push({
        id: 't' + i, cid: c.id, name, short: name.length > 9 ? name.slice(0, 9) : name, kind, style,
        lvl: Math.round((levelBase(level) + w.year * 0.36 + c.edge + (r() - 0.5) * 0.8 + (kind === 'club' ? 0.3 : 0)) * 10) / 10,
        formation: r.pick(['4-4-2', '4-3-3', '5-3-2', '4-2-3-1']), tactic: { power: 'ハイプレス', tech: 'ポゼッション', defend: '堅守' }[style],
        color: r.pick(['#c0392b', '#2c3e50', '#7f8c8d', '#8e44ad', '#d35400', '#16a085']),
        coach: { name: c.coach.name, kind: ck[0], note: ck[1] },
      });
    }
    teams.push({ id: 'me', name: w.clubName, short: YA.shortName(w.clubName), me: true });
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
      // 大会は全国から：Jクラブのユースか、各地の高校
      const pool = YA.clubPool(r.int(0, 5));
      const name = r.pick(pool.filter((c) => c.level <= 2 && c.name !== w.clubName)).name;
      const style = r.pick(['power', 'tech', 'defend']);
      return { id: 'c' + i, name, short: name.length > 9 ? name.slice(0, 9) : name, style, lvl: Math.round((base + i * 0.55 + (r() - 0.5)) * 10) / 10, formation: r.pick(['4-4-2', '4-3-3', '5-3-2']), tactic: { power: 'ハイプレス', tech: 'ポゼッション', defend: '堅守' }[style], color: r.pick(['#c0392b', '#2c3e50', '#8e44ad', '#d35400']), coach: { name: r.pick(COACH_SUR) + ' 監督', kind: r.pick(COACH_KIND)[0], note: '' } };
    });
    const base = levelBase(w.leagueLevel || 2) - 0.3 + w.year * 0.36;
    w.cup = { summer: { alive: true, round: 0, opps: mk(3, base), result: null }, winter: { alive: true, round: 0, opps: mk(4, base - 0.2), result: null } };
  };

  // 今週の相手（試合用の定義）
  YA.opponentOf = function (w) {
    const s = YA.matchOf(w);
    if (!s || !w.league) {
      // 旧データの互換：週ごとに作る
      const r = YA.rngOf(w.seed * 31 + w.year * 1000 + w.week * 7);
      const style = r.pick(['power', 'tech', 'defend']);
      return { id: 'o' + w.week, name: r.pick(AREAS) + r.pick(HS), short: '相手', color: '#c0392b', lvl: 10 + w.year * 0.36, formation: '4-4-2', tactic: { power: 'ハイプレス', tech: 'ポゼッション', defend: '堅守' }[style], desc: STYLE_DESC[style], style, home: r.chance(0.5) };
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
        YA.noteTier(w, 2, (s.cup === 'summer' ? '夏の全国大会' : '冬のカップ戦') + `は${s.round}回戦で敗退。`);
      } else if (s.round >= c.opps.length) {
        c.alive = false;
        c.result = '優勝';
        w.trophies = (w.trophies || []).concat([{ year: w.year, name: s.cup === 'summer' ? '夏の全国大会' : '冬のカップ戦', rank: '優勝' }]);
        YA.noteTier(w, 1, (s.cup === 'summer' ? '夏の全国大会' : '冬のカップ戦') + 'で優勝しました！');
        if (w.club) YA.addRep(w, 4);
      } else YA.noteTier(w, 3, (s.cup === 'summer' ? '夏の全国大会' : '冬のカップ戦') + `の${s.round}回戦を突破${pk}`);
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
      for (const p of key) out.push(`要注意：${p.num}番 ${p.name}（${YA.POS_LABEL[p.main] || p.pos}）${p.traits.length ? '特性「' + p.traits.join('・') + '」' : ''}`);
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
