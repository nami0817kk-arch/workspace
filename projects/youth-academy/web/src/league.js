// 日程・リーグ（12チームの総当たり22試合）・夏と冬の大会・順位表・相手の分析。
// 状態は w.league / w.cup / w.h2h に入れ、JSON でそのまま保存できる。
(function () {
  'use strict';
  const YA = (globalThis.YA = globalThis.YA || {});
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

  // ---------- 1年の日程（40週）----------
  // 1〜12週 リーグ前半（4〜7月初め）／13〜15週 日本クラブユース選手権（7〜8月）／16週 夏合宿（8月）／17〜26週 リーグ後半（8〜11月）／27〜30週 冬の大会
  // 40週 卒業式。入団の暦は scout.js（25〜27週 内部昇格／1〜27週 スカウト・28週に返事／31〜34週 セレクション）
  // 2026-11-17：前は夏の大会が6〜7月、夏合宿が26週＝11月になっていた。現実の暦（クラブユース選手権は7月下旬〜8月、合宿は8月）に合わせた
  YA.SUMMER_CUP_WEEKS = [13, 15];
  YA.CAMP_WEEK = 16;
  // 2026-11-17：1〜3月にも試合を置いた（前は9週間試合が無かった）。31週＝プレミアのファイナル／昇格のプレーオフ（出られるときだけ）、
  // 32・33週＝新春フェスティバル（全国のクラブと）、35・36週＝練習試合（遠征）。夏の大会は13〜15週がグループ戦3試合で、
  // 上位2つが決勝トーナメントへ（決勝トーナメントは週が足りないので、グループ戦のあとに結果で決める）
  YA.SCHED = function (week) {
    if (week <= 12) return { t: 'league', n: week };
    if (week <= 15) return { t: 'cup', cup: 'summer', round: week - 12 };
    if (week === 16) return { t: 'camp' };
    if (week <= 26) return { t: 'league', n: week - 4 };
    if (week >= 27 && week <= 30) return { t: 'cup', cup: 'winter', round: week - 26 };
    if (week === 31) return { t: 'cup', cup: 'post', round: 1 };
    if (week === 32 || week === 33) return { t: 'cup', cup: 'fest', round: week - 31 };
    if (week === 35 || week === 36) return { t: 'cup', cup: 'tm', round: week - 34 };
    if (week === 40) return { t: 'ceremony' };
    return { t: 'none' };
  };
  // 大会の週の名前
  YA.cupLabel = function (w, s) {
    const c = w && w.cup && w.cup[s.cup];
    if (s.cup === 'summer') return YA.CUP_NAME.summer + ` グループ戦 第${s.round}戦`;
    if (s.cup === 'post') return c && c.kind === 'final' ? 'プレミアリーグ ファイナル' : c && c.kind === 'playoff' ? '昇格のプレーオフ' : 'プレーオフ・ファイナル';
    if (s.cup === 'fest') return YA.CUP_NAME.fest + ` 第${s.round}戦`;
    if (s.cup === 'tm') return YA.CUP_NAME.tm + ` 第${s.round}戦`;
    const n = c && c.opps ? c.opps.length : 4;
    return YA.CUP_NAME[s.cup] + (s.round === n ? ' 決勝' : s.round === n - 1 ? ' 準決勝' : ` ${s.round}回戦`);
  };
  YA.weekLabel = function (w) {
    const s = YA.SCHED(w.week);
    if (s.t === 'league') return `リーグ第${s.n}節`;
    if (s.t === 'cup') return YA.cupLabel(w, s);
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
  // 今週から n 週のうちに残っているAの試合の数（今週の試合が済んでいれば数えない）。夏の大会のグループ戦・新春フェスティバル・練習試合は必ずある
  YA.aMatchesAhead = function (w, n) {
    let k = 0;
    for (let wk = w.week + (w.matchDone || w.phase === 'after' ? 1 : 0); wk < w.week + n && wk <= YA.WEEKS; wk++) {
      const s = YA.SCHED(wk);
      if (s.t === 'league') k++;
      else if (s.t === 'cup') {
        const c = w.cup && w.cup[s.cup];
        if (c && (c.alive || (c.group && !c.groupDone))) k++;
      }
    }
    return k;
  };

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
    // 決定96 で部の差を詰めた（10.6/9.8/9.0）が、昇格に偏り3部から5年以内にプレミアへ届いていた。2026-11-17 に少し広げた
    return YA.LEVEL_BASE[level - 1];
  }
  YA.LEVEL_BASE = [9.75, 8.75, 7.8]; // 卒業時の平均を90前後に戻したので、相手もそれに合わせた（前は 10.6/9.8/9.0）
  YA.levelBase = levelBase;
  YA.LEVEL_NAMES = ['プレミアリーグ', 'プリンスリーグ', '県リーグ'];
  // プレミアは EAST（北海道・東北／関東／中部）と WEST（関西／中国・四国／九州）に分かれる
  YA.sideOf = (region) => (region <= 2 ? 0 : 1);
  const PRINCE = ['東北', '関東', '東海', '関西', '中国', '九州'];
  YA.levelNames = function (w) {
    const rg = YA.regionOf(w && w.clubName);
    return ['高円宮杯U-18 プレミアリーグ' + (rg <= 2 ? 'EAST' : 'WEST'), 'プリンスリーグ' + PRINCE[rg], '県リーグ1部'];
  };
  // 大会の名前（夏はクラブユース選手権、冬はJユースカップ）
  YA.CUP_NAME = { summer: '日本クラブユース選手権', winter: 'Jユースカップ', post: 'プレーオフ・ファイナル', fest: '新春フェスティバル', tm: '練習試合（遠征）' };
  YA.LEVEL_EXP = [1, 0.8, 0.6]; // 試合の経験値（決定62：全国＞地域＞県）

  // ---------- プロクラブの表（地域名は実在の町、愛称は固定）。トップチーム・卒業生の移籍先・ユースのリーグの相手に使う ----------
  // [町, 地域, 愛称, はじめの部（1=J1・2=J2・3=J3）]
  YA.REGIONS = ['北海道・東北', '関東', '中部', '関西', '中国・四国', '九州'];
  YA.PRO_CLUBS = [
    ['札幌', 0, 'コンサドール', 1], ['仙台', 0, 'ベガルス', 2], ['山形', 0, 'モンテディア', 2], ['秋田', 0, 'ブラウリッツ', 3], ['盛岡', 0, 'グルーナ', 3], ['福島', 0, 'ユナイテッド', 3],
    ['横浜', 1, 'マリーナス', 1], ['川崎', 1, 'フロンティエラ', 1], ['浦和', 1, 'スカーレッツ', 1], ['鹿島', 1, 'ディアーズ', 1], ['柏', 1, 'ソレイユ', 1], ['東京', 1, 'キャピタルズ', 1], ['町田', 1, 'ゼルヴァ', 1],
    ['湘南', 1, 'ベルマリーナ', 2], ['千葉', 1, 'ジェフィーズ', 2], ['大宮', 1, 'アルディーレ', 2], ['水戸', 1, 'ホリーズ', 2], ['甲府', 1, 'ヴァンフォール', 2], ['栃木', 1, 'イエローズ', 3], ['群馬', 1, 'ザスペル', 3], ['相模原', 1, 'グリーンズ', 3],
    ['新潟', 2, 'アルビレオ', 1], ['清水', 2, 'エスパーダ', 1], ['名古屋', 2, 'グランパレス', 1], ['磐田', 2, 'ジュビラーレ', 2], ['藤枝', 2, 'マイフィールド', 2], ['金沢', 2, 'ツヴァイゲン', 3], ['松本', 2, 'アルプス', 3], ['長野', 2, 'パルティーレ', 3], ['岐阜', 2, 'リバーズ', 3],
    ['大阪', 3, 'ガンバーレ', 1], ['京都', 3, 'サンガーレ', 1], ['神戸', 3, 'ヴィッセン', 1], ['奈良', 3, 'シカーズ', 3], ['滋賀', 3, 'レイクス', 3],
    ['岡山', 4, 'ファジアーレ', 1], ['広島', 4, 'サンフレイム', 1], ['徳島', 4, 'ヴォルテクス', 2], ['愛媛', 4, 'オレンジーズ', 2], ['山口', 4, 'レノーヴァ', 2], ['今治', 4, 'シーサイダーズ', 2], ['高知', 4, 'ドルフィンズ', 3], ['鳥取', 4, 'ガイナーラ', 3],
    ['福岡', 5, 'アビスタ', 1], ['長崎', 5, 'ヴィファーレ', 1], ['鳥栖', 5, 'サガーノ', 2], ['大分', 5, 'トリニティ', 2], ['熊本', 5, 'ロッソーナ', 2], ['北九州', 5, 'ギラヴァン', 3], ['鹿児島', 5, 'ボルケーノ', 3], ['宮崎', 5, 'テゲバード', 3],
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
      out.push({ id: 'R' + region + '-' + out.length, name, kind, style, level, edge: Math.round((r() - 0.5) * 2.2 * 10) / 10, coach: { name: r.pick(COACH_SUR) + ' ' + r.pick(['監督', 'コーチ']), kind: ck[0], note: ck[1] } });
    };
    // 全国（1部＝プレミア）：自分と同じ側（EAST／WEST）の J1・J2 のユース10と、同じ側の強豪校（2026-11-17 直し：
    // 前は全国から選んでいて、EAST に福岡・広島が入っていた）
    const side = YA.sideOf(region);
    const top = YA.PRO_CLUBS.filter((c) => YA.sideOf(c.region) === side && c.tier <= 2).sort((a, b) => a.tier - b.tier || r() - 0.5);
    for (const c of top.slice(0, 10)) add(c.name + 'U-18', 'club', 1);
    const towns = REGION_TOWNS.filter((t, i) => YA.sideOf(i) === side).flat();
    let g1 = 0;
    while (out.filter((x) => x.level === 1).length < 20 && g1++ < 300) add(r.pick(towns) + r.pick(HS), 'high', 1);
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

  // 相手の強さは部ごとの幅の中で、世代ごとに入れ替わる（決定105。年とともに強くなり続ける作りはやめた）
  YA.genWave = (w, id) => (YA.rngOf((w.seed | 0) * 7 + YA.hash(String(id)) * 3 + w.year * 131)() - 0.5) * 1.1;
  // 相手が自分を研究してくる分（2026-11-17 直し：相手の強さが固定で、年数がたつとプレミアも大会も楽勝だった）。
  // 評判が高いほど、前の年に同じ部で上位だったほど、少し強く当たってくる（-0.15〜+0.45）
  YA.oppAdj = function (w) {
    const rep = w.club ? w.club.rep : 50;
    const last = (w.leagueHist || [])[(w.leagueHist || []).length - 1];
    const lv = w.leagueLevel || 2;
    const top = last && last.level === lv && last.rank <= 3 ? 0.15 : 0;
    return clamp(((rep - 50) / 50) * 0.3, -0.15, 0.3) + top;
  };
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
        lvl: Math.round((levelBase(level) + c.edge + YA.genWave(w, c.id) + (r() - 0.5) * 0.4 + (kind === 'club' ? 0.3 : 0) + (level === 1 && kind === 'club' ? 0.2 : 0) + YA.oppAdj(w)) * 10) / 10,
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

  // 大会の相手は全国のJクラブのユースだけ（クラブユースの大会に高校は出ない）。強さは自分のリーグの部ではなく全国の水準で、
  // そのクラブのトップの部で決まる（J1 のユースが強い）。2026-11-17 直し：前は自分の部で決まり、3部から18年中8年全国優勝していた
  YA.NAT_CLUB_LVL = { 1: 0.15, 2: -0.4, 3: -0.95 }; // levelBase(1) からの差
  YA.natClubs = function (w) {
    return YA.PRO_CLUBS.filter((c) => c.name + 'U-18' !== w.clubName && c.name !== YA.topName(w)).map((c) => {
      const id = 'N' + c.name;
      return { id, name: c.name + 'U-18', tier: c.tier, kind: 'club', lvl: levelBase(1) + YA.NAT_CLUB_LVL[c.tier] + ((YA.hash(c.name) % 100) / 100 - 0.5) * 0.6 + YA.genWave(w, id) * 0.6 };
    });
  };
  YA.newCup = function (w) {
    const r = YA.rngOf(w.seed * 57 + w.year * 211);
    const used = new Set();
    const nat = YA.natClubs(w);
    const dress = (c, i, pre) => {
      const style = r.pick(['power', 'tech', 'defend']);
      const name = (w.rename && w.rename[c.id]) || c.name;
      return { id: pre + i, cid: c.id, name, short: name.length > 9 ? name.slice(0, 9) : name, kind: 'club', style, lvl: Math.round((c.lvl + YA.oppAdj(w) * 0.5 + (r() - 0.5) * 0.3) * 10) / 10, formation: r.pick(['4-4-2', '4-3-3', '5-3-2', '4-2-3-1']), tactic: { power: 'ハイプレス', tech: 'ポゼッション', defend: '堅守' }[style], color: r.pick(['#c0392b', '#2c3e50', '#8e44ad', '#d35400']), coach: { name: r.pick(COACH_SUR) + ' 監督', kind: r.pick(COACH_KIND)[0], note: '' } };
    };
    // 重み：強いクラブほど勝ち上がってくる（後ろの回ほど強い相手）
    const draw = (n, pre, minLvl) => {
      const out = [];
      for (let i = 0; i < n; i++) {
        const cand = nat.filter((c) => !used.has(c.id) && c.lvl >= (minLvl || 0));
        const c = r.weighted(cand.length ? cand : nat.filter((x) => !used.has(x.id)), (x) => Math.exp((x.lvl - 10) * 1.2));
        used.add(c.id);
        out.push(dress(c, i, pre));
      }
      return out;
    };
    // 夏：グループ戦（4クラブで3試合。上位2つが16の決勝トーナメントへ）
    const gopps = draw(3, 'g');
    const ko = draw(4, 'k').sort((a, b) => a.lvl - b.lvl);
    const winter = draw(4, 'c').sort((a, b) => a.lvl - b.lvl);
    const fest = draw(2, 'f');
    // 練習試合は、同じリーグの部のよそのクラブ（地域の別の相手）
    const reg = YA.clubPool(YA.regionOf(w.clubName)).filter((c) => c.level === (w.leagueLevel || 2) && c.name !== w.clubName && !(w.league && w.league.teams.some((t) => t.cid === c.id)));
    const tm = [0, 1].map((i) => { const c = reg.length ? reg[(YA.hash(w.year + '_' + i + w.seed) % reg.length)] : nat[i]; return Object.assign(dress({ id: c.id, name: c.name, lvl: levelBase(w.leagueLevel || 2) + (c.edge || 0) }, i, 't'), { kind: c.kind || 'club' }); });
    const tbl = { me: { p: 0, w: 0, d: 0, l: 0, gf: 0, ga: 0 } };
    for (const o of gopps) tbl[o.id] = { p: 0, w: 0, d: 0, l: 0, gf: 0, ga: 0 };
    w.cup = {
      summer: { alive: true, round: 0, group: true, gopps, gtable: tbl, gdone: 0, groupDone: false, opps: ko, result: null },
      winter: { alive: true, round: 0, opps: winter, result: null },
      post: { alive: false, round: 0, kind: null, opps: [], result: null },
      fest: { alive: true, round: 0, friendly: true, opps: fest, result: null },
      tm: { alive: true, round: 0, friendly: true, opps: tm, result: null },
    };
  };
  // 自分のAの強さ（相手の lvl と同じ物差し。相手の選手は lvl に位置の能力 +1.5 が乗るので、その分を引く）
  YA.myLvl = function (w) {
    const ps = (w.lineupA || []).map((s) => w.players[s.pid]).filter(Boolean);
    return ps.length ? ps.reduce((a, p) => a + YA.ovr(p), 0) / ps.length - 1.5 : levelBase(w.leagueLevel || 2);
  };
  // 試合をせずに決める1試合（夏の決勝トーナメント）。引き分けはPK
  YA.koWin = function (w, opp, r) {
    const pw = clamp(0.5 + (YA.myLvl(w) - opp.lvl) * 0.32, 0.08, 0.92);
    return r() < pw;
  };
  // 夏のグループ戦が終わったら、順位と決勝トーナメントの結果を決める
  function summerAfterGroup(w) {
    const c = w.cup.summer;
    const r = YA.rngOf(w.seed * 23 + w.year * 97);
    // よその組み合わせ（自分の試合以外の3試合）
    const g = c.gopps;
    for (const [a, b] of [[0, 1], [0, 2], [1, 2]]) addTable(c.gtable, g[a].id, g[b].id, goalsOf(r, g[a].lvl, g[b].lvl, true), goalsOf(r, g[b].lvl, g[a].lvl, false));
    const rows = ['me'].concat(g.map((x) => x.id)).map((id) => Object.assign({ id }, c.gtable[id]));
    rows.forEach((x) => (x.gd = x.gf - x.ga));
    rows.sort((a, b) => b.p - a.p || b.gd - a.gd || b.gf - a.gf);
    const rank = rows.findIndex((x) => x.id === 'me') + 1;
    c.groupDone = true;
    c.grank = rank;
    if (rank > 2) {
      c.alive = false;
      c.result = `グループ${rank}位で敗退`;
      YA.noteTier(w, 2, `${YA.CUP_NAME.summer}はグループ${rank}位で敗退。`);
      return;
    }
    const NAMES = ['ベスト16', 'ベスト8', 'ベスト4', '準優勝'];
    for (let i = 0; i < c.opps.length; i++) {
      c.round = i + 1;
      if (!YA.koWin(w, c.opps[i], r)) {
        c.alive = false;
        c.result = NAMES[i] + `（決勝トーナメントで${c.opps[i].name}に敗れた）`;
        YA.noteTier(w, i >= 2 ? 1 : 2, `${YA.CUP_NAME.summer}はグループ${rank}位で決勝トーナメントへ進み、${NAMES[i]}。${c.opps[i].name}に敗れた`);
        return;
      }
    }
    c.alive = false;
    c.result = '優勝';
    w.trophies = (w.trophies || []).concat([{ year: w.year, name: YA.CUP_NAME.summer, rank: '優勝' }]);
    YA.noteTier(w, 1, `${YA.CUP_NAME.summer}で優勝しました！（グループ${rank}位から決勝トーナメントを4つ勝ち抜いた）`);
    if (w.club) YA.addRep(w, 4);
  }
  YA._summerAfterGroup = summerAfterGroup;

  // 今週の相手（試合用の定義）
  YA.opponentOf = function (w) {
    const s = YA.matchOf(w);
    // Aの試合が無い週（Bだけの試合）：リーグの相手から（前は年とともに強くなる仮の相手だった）
    if (!s && w.league) {
      const t = w.league.teams.filter((x) => !x.me)[(w.week + w.year) % 11];
      return Object.assign({}, t, { id: t.id + '_' + w.year + '_' + w.week, desc: STYLE_DESC[t.style] || '', home: w.week % 2 === 1, kindLabel: '' });
    }
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
      const c = w.cup[s.cup];
      t = c.group ? c.gopps[s.round - 1] : c.opps[Math.min(s.round, c.opps.length) - 1];
      home = s.round % 2 === 1;
    }
    return Object.assign({}, t, { id: t.id + '_' + w.year + '_' + w.week, desc: STYLE_DESC[t.style] + (t.coach && t.coach.note ? '／' + t.coach.name + '：' + t.coach.note : ''), home, kindLabel: s.t === 'league' ? `リーグ第${s.n}節` : YA.cupLabel(w, s) });
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
    else if (w.cup[s.cup].group) {
      // 夏の大会のグループ戦
      const c = w.cup[s.cup];
      if (c.gdone >= s.round) return;
      c.gdone = s.round;
      addTable(c.gtable, 'me', c.gopps[s.round - 1].id, gf, ga);
      YA.noteTier(w, 3, `${YA.CUP_NAME.summer}のグループ戦 第${s.round}戦：${gf}-${ga}`);
      if (s.round >= c.gopps.length) summerAfterGroup(w);
    } else if (w.cup[s.cup].friendly) {
      const c = w.cup[s.cup];
      c.round = s.round;
      (c.rec = c.rec || []).push([gf, ga]);
    } else if (s.cup === 'post') {
      const c = w.cup.post;
      let win = gf > ga;
      let pk = '';
      if (gf === ga) {
        win = YA.rngOf(w.seed * 7 + w.week * 13 + w.year)() < 0.5 + (YA.pkBonus ? YA.pkBonus(w) : 0);
        pk = win ? '（PK戦で勝利）' : '（PK戦で敗戦）';
      }
      c.round = 1;
      c.alive = false;
      if (c.kind === 'playoff') {
        c.result = win ? '昇格' : '昇格ならず';
        if (win) {
          w.nextLevel = w.league.level - 1;
          w.leagueEndMove = -1;
        }
        YA.noteTier(w, 1, win ? `昇格のプレーオフに勝ちました${pk}。来年は一つ上のリーグです` : `昇格のプレーオフに敗れました${pk}。来年も同じリーグです`);
      } else {
        c.result = win ? '優勝' : '準優勝';
        if (win) {
          w.trophies = (w.trophies || []).concat([{ year: w.year, name: 'プレミアリーグ ファイナル', rank: '優勝' }]);
          if (w.club) YA.addRep(w, 4);
        }
        YA.noteTier(w, 1, win ? `プレミアリーグのファイナルに勝ち、日本一になりました${pk}！` : `プレミアリーグのファイナルに敗れ、準優勝でした${pk}`);
      }
    } else {
      const c = w.cup[s.cup];
      let win = gf > ga;
      let pk = '';
      if (gf === ga) {
        const r = YA.rngOf(w.seed * 7 + w.week * 13 + w.year);
        win = r() < 0.5 + (w.rep || 40) / 1000 + (YA.pkBonus ? YA.pkBonus(w) : 0);
        pk = win ? '（PK戦で勝利）' : '（PK戦で敗退）';
      }
      c.round = s.round;
      if (!win) {
        c.alive = false;
        c.result = `${s.round}回戦で敗退${pk}`;
        YA.noteTier(w, 2, YA.CUP_NAME[s.cup] + `は${s.round}回戦で敗退。`);
      } else if (s.round >= c.opps.length) {
        c.alive = false;
        c.result = '優勝';
        w.trophies = (w.trophies || []).concat([{ year: w.year, name: YA.CUP_NAME[s.cup], rank: '優勝' }]);
        YA.noteTier(w, 1, YA.CUP_NAME[s.cup] + 'で優勝しました！');
        if (w.club) YA.addRep(w, 4);
      } else YA.noteTier(w, 3, YA.CUP_NAME[s.cup] + `の${s.round}回戦を突破${pk}`);
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
    // 降格は最下位だけ。昇格は上位2つが31週のプレーオフ（他地域の上位と1試合）に勝ったときだけ。
    // プレミア（1部）の1位は31週に EAST と WEST のファイナル（2026-11-17 直し：前は上位2つがそのまま昇格し、昇格に偏っていた）
    let move = 0;
    if (me.rank >= 12 && L.level < 3) move = 1;
    if (w.cup && w.cup.post) {
      const po = w.cup.post;
      const pr = YA.rngOf(w.seed * 3 + w.year * 211 + 5);
      const rg = YA.regionOf(w.clubName);
      if (me.rank <= 2 && L.level > 1) {
        const pool = YA.clubPool((rg + 1 + pr.int(0, 4)) % 6).filter((c) => c.level === L.level);
        const c = pr.pick(pool);
        po.kind = 'playoff';
        po.alive = true;
        po.opps = [{ id: 'po', cid: c.id, name: c.name, short: c.name.slice(0, 9), kind: c.kind, style: c.style, lvl: Math.round((levelBase(L.level) + 0.45 + YA.oppAdj(w) * 0.5) * 10) / 10, formation: '4-4-2', tactic: { power: 'ハイプレス', tech: 'ポゼッション', defend: '堅守' }[c.style], color: '#2c3e50', coach: c.coach }];
      } else if (me.rank === 1 && L.level === 1) {
        const other = YA.clubPool(YA.sideOf(rg) ? 1 : 3).filter((c) => c.level === 1 && c.kind === 'club');
        const c = pr.pick(other);
        po.kind = 'final';
        po.alive = true;
        po.opps = [{ id: 'pf', cid: c.id, name: c.name, short: c.name.slice(0, 9), kind: c.kind, style: c.style, lvl: Math.round((levelBase(1) + 0.55) * 10) / 10, formation: '4-3-3', tactic: { power: 'ハイプレス', tech: 'ポゼッション', defend: '堅守' }[c.style], color: '#8e44ad', coach: c.coach }];
      }
    }
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

})();
