// 育成の中身：36人（高1〜高3）・1週の流れ・練習・成長・怪我・出来事・卒業と入学。
// 見せ方には依存しない（試合の engine.js と同じ作り）。状態 w は JSON にそのまま保存できる。
(function () {
  'use strict';
  const YA = (globalThis.YA = globalThis.YA || {});
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

  // ---------- 暦 ----------
  // 1年＝40週（4月第1週〜3月第4週あたり）。1〜30週は毎週試合、31〜39週は大会のない期間、40週は卒業式
  const WEEKS = 40;
  const MONTHS = ['4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月', '1月', '2月', '3月'];
  YA.calendar = function (week) {
    const m = Math.min(11, Math.floor(((week - 1) / WEEKS) * 12));
    const first = Math.ceil((m / 12) * WEEKS) + 1;
    return { month: MONTHS[m], nth: week - first + 1 };
  };
  YA.WEEKS = WEEKS;

  // ---------- 能力の分類・特性の覚えやすさ ----------
  YA.TRAIT_AFF = {
    裏への抜け出し: ['オフザボール', '加速'], カットイン: ['ドリブル', '敏しょう性'], 縦への突破: ['スピード', 'ドリブル'], ワンツー: ['パス', 'チームワーク'], スルーパス: ['パス', '視野'],
    アーリークロス: ['クロス', '視野'], 巻いて流し込むシュート: ['フィニッシュ', 'テクニック'], ループシュート: ['フィニッシュ', '冷静さ'], 弾丸ミドル: ['ロングシュート', '強さ'], ポストプレー: ['強さ', 'ファーストタッチ'],
    ひらめき: ['テクニック', '判断'], 背負ってからのターン: ['バランス', '敏しょう性'], ニアへの飛び込み: ['オフザボール', '予測'], こぼれ球への嗅覚: ['予測', '集中'], ヘディングシュート: ['ヘディング', 'ジャンプ'],
    下がって受ける: ['ファーストタッチ', '視野'], ボールを運ぶ: ['ドリブル', '運動量'], サイドチェンジ: ['パス', '視野'], オーバーラップ: ['スタミナ', '運動量'], タメを作る: ['ファーストタッチ', '冷静さ'],
    前線からの守備: ['運動量', 'チームワーク'], 読みのインターセプト: ['予測', 'ポジショニング'], スライディング: ['タックル', '敏しょう性'], '1対1の粘り': ['タックル', 'マーク'], 空中戦の競り: ['ジャンプ', 'ヘディング'],
    カバーリング: ['ポジショニング', '判断'], ボール奪取: ['タックル', '強さ'], ラインコントロール: ['ポジショニング', '集中'], シュートブロック: ['集中', '強さ'], 即時奪回: ['運動量', '加速'],
    ロングスロー: ['強さ', 'スタミナ'], 直接FK: ['プレースキック', 'テクニック'], 曲がるCK: ['プレースキック', 'クロス'],
    ファウルをもらう: ['バランス', '判断'], 声で味方を動かす: ['視野', 'チームワーク'], 試合を落ち着かせる: ['冷静さ', '集中'],
    前に出るGK: ['飛び出し', '1対1'], PKストップ: ['反応', '1対1'], パンチング: ['ハンドリング', '空中戦'], 速い配球: ['配球', '判断'], 足元のうまいGK: ['ファーストタッチ', '配球'], クロスへの強さ: ['空中戦', 'エリアの支配'],
  };
  const GK_TRAITS = YA.TRAIT_GROUPS.GK;
  const FIELD_TRAITS = YA.TRAITS.filter((t) => GK_TRAITS.indexOf(t) < 0);

  // 練習メニュー12（決定48）。ability → 効き。fat = 疲れの溜まりやすさ（回復は負）
  const M = (ab, fat, note) => ({ ab, fat, note });
  YA.MENUS = {
    ボール回し: M({ パス: 1, ファーストタッチ: 1, テクニック: 0.8, 視野: 0.8, チームワーク: 0.7, 判断: 0.6 }, 1, 'パスと視野'),
    対人: M({ タックル: 1, マーク: 1, ドリブル: 0.8, 敏しょう性: 0.7, 強さ: 0.7 }, 1.3, '1対1の強さ'),
    シュート: M({ フィニッシュ: 1, ロングシュート: 0.8, PK: 0.6, 逆足の精度: 0.7, ヘディング: 0.5 }, 1, '決定力'),
    クロスと合わせ: M({ クロス: 1, ヘディング: 0.9, フィニッシュ: 0.6, オフザボール: 0.7, ジャンプ: 0.6 }, 1, 'サイド攻撃'),
    戦術: M({ 判断: 1, 予測: 1, ポジショニング: 1, チームワーク: 0.8, オフザボール: 0.7 }, 0.7, '頭の力'),
    守備の組織: M({ ポジショニング: 1, マーク: 0.9, 予測: 0.9, 集中: 0.9, チームワーク: 0.7 }, 0.9, '守りの形'),
    紅白戦: M({ 判断: 0.7, 予測: 0.6, ファーストタッチ: 0.6, パス: 0.5, ドリブル: 0.5, 運動量: 0.5, 集中: 0.5 }, 1.4, '総合（試合勘）'),
    フィジカル: M({ スタミナ: 1, 強さ: 1, ジャンプ: 0.8, バランス: 0.8, 運動量: 0.7 }, 1.7, '体づくり'),
    アジリティ: M({ 加速: 1, スピード: 1, 敏しょう性: 1, バランス: 0.6 }, 1.2, '素早さ'),
    セットプレー: M({ プレースキック: 1, クロス: 0.7, ヘディング: 0.6, PK: 0.8 }, 0.6, 'FK・CK'),
    相手の対策: M({ 予測: 0.8, 判断: 0.8, 集中: 0.8, ポジショニング: 0.6 }, 0.6, '次の相手に備える'),
    回復: M({}, -2.2, '疲れを抜く'),
  };
  YA.MENUS['練習試合'] = M({ 判断: 0.7, 予測: 0.6, ファーストタッチ: 0.6, パス: 0.5, ドリブル: 0.5, 運動量: 0.5, 集中: 0.5, フィニッシュ: 0.4 }, 1.5, '出番の少ない子に試合の機会');
  YA.MENU_NAMES = Object.keys(YA.MENUS);
  const GK_TRAIN = { ハンドリング: 0.9, 反応: 0.9, '1対1': 0.8, 飛び出し: 0.8, 空中戦: 0.7, エリアの支配: 0.7, コーチング: 0.5, 配球: 0.6 };
  const INTENS = { light: 0.65, normal: 1, hard: 1.4 };
  YA.INTENS_NAMES = { light: '軽め', normal: '普通', hard: 'きつい' };

  const MENTAL_SET = new Set(YA.AB_MENTAL);

  // ---------- 選手 ----------
  const POS_ABS = {
    GK: YA.AB_GK,
    DF: ['タックル', 'マーク', 'ポジショニング', '予測', 'ヘディング', '強さ'],
    MF: ['パス', '視野', '判断', 'ドリブル', '運動量', 'テクニック'],
    FW: ['フィニッシュ', 'ドリブル', 'スピード', 'オフザボール', '加速', 'ヘディング'],
  };
  YA.ovr = function (p) {
    const a = YA.POS_ABS15[p.main] || POS_ABS[p.pos];
    return a.reduce((s, n) => s + p.ab[n], 0) / a.length;
  };
  const abSum = (p) => (p.pos === 'GK' ? YA.AB_GK : YA.AB_FIELD).reduce((s, n) => s + p.ab[n], 0);
  YA.abSum = abSum;
  const abList = (p) => (p.pos === 'GK' ? YA.AB_GK.concat(YA.AB_MENTAL, YA.AB_PHYS) : YA.AB_FIELD);

  const SUR = ['佐藤', '鈴木', '高橋', '田中', '伊藤', '渡辺', '山本', '中村', '小林', '加藤', '吉田', '山田', '佐々木', '山口', '松本', '井上', '木村', '林', '斎藤', '清水', '山崎', '森', '池田', '橋本', '阿部', '石川', '山下', '中島', '石井', '小川', '前田', '岡田', '長谷川', '藤田', '後藤', '近藤', '村上', '遠藤', '青木', '坂本', '福田', '太田', '西村', '藤井', '金子', '三浦', '岡本', '松田', '中川', '原田', '竹内', '和田', '上田', '柴田', '工藤', '横山', '宮崎', '内田', '高木', '安藤'];
  const GIV = ['蓮', '大翔', '陽翔', '湊', '蒼', '樹', '悠真', '朝陽', '律', '颯太', '龍之介', '海斗', '凛', '奏', '隼人', '拓海', '翔', '航', '陸', '光', '諒', '慎', '健太', '直樹', '康介', '優斗', '駿', '瑛太', '晴', '誠', '大和', '陽太', '悠斗', '碧', '旭', '想', '勇気', '尚', '遼', '怜'];
  const PERS_W = {
    気持ちの強さ: { ふつう: 4, 負けず嫌い: 2, 粘り強い: 2, 楽天家: 1.5, 繊細: 1.5, 完璧主義: 1 },
    感情の波: { ふつう: 4, 気分屋: 1.5, 安定型: 2, 短気: 1.2 },
    大舞台: { ふつう: 4, 大舞台に強い: 1.2, 目立ちたがり: 1, プレッシャーに弱い: 1.2, 慎重: 1.2 },
    人との関わり: { ふつう: 3, リーダー気質: 1, 世話好き: 1, 仲間思い: 1.5, お調子者: 1.2, 一匹狼: 0.8, 人見知り: 1, 寡黙: 1 },
    教えの受け止め方: { ふつう: 2, 素直: 3, 頑固: 1.5, マイペース: 1.5, 構ってほしい: 1.2, 反骨心: 1.2 },
    練習への向き合い: { ふつう: 2, 真面目: 3, 勉強家: 1.5, 練習嫌い: 1.2 },
    目指すもの: { ふつう: 3, 野心家: 1.5, クラブ愛: 1, 家族思い: 1.2, 寂しがり: 1 },
    プレーの気質: { ふつう: 3, 闘争的: 1.3, 勇敢: 1.3, 献身的: 1.3, ずる賢い: 1, 自信家: 1.2 },
  };

  // 学年 g=1,2,3。quality は -2〜+2 の素質
  YA.genPlayer = function (rng, id, grade, pos, quality, used) {
    let name;
    for (;;) {
      name = rng.pick(SUR) + ' ' + rng.pick(GIV);
      if (!used || !used.has(name)) break;
    }
    if (used) used.add(name);
    const lvl = 7.4 + grade * 0.8 + quality * 0.9;
    // pos は15個のうちの1つ。素質は3割で隣のポジション向き（登録とずれている＝あとで気づく）
    const grp = YA.GROUP[pos];
    const NEAR = { CB: ['DM', 'LB'], LB: ['LWB', 'CB'], RB: ['RWB', 'CB'], LWB: ['LB', 'LM'], RWB: ['RB', 'RM'], DM: ['CM', 'CB'], CM: ['DM', 'AM'], LM: ['LW', 'CM'], RM: ['RW', 'CM'], AM: ['CM', 'SS'], LW: ['LM', 'AM'], RW: ['RM', 'AM'], SS: ['AM', 'ST'], ST: ['SS', 'LW'] };
    const trueP = pos === 'GK' ? pos : rng() < 0.35 ? NEAR[pos][rng.int(0, 1)] : pos;
    const shifted = trueP !== pos;
    const focus = YA.POS_ABS15[trueP];
    const boost = {};
    for (let k = 0; k < (shifted ? 4 : 3); k++) boost[rng.pick(focus)] = shifted ? rng.int(2, 5) : rng.int(1, 4);
    for (const n of YA.AB_MENTAL.concat(YA.AB_PHYS, YA.AB_TECH)) if (!boost[n] && rng.chance(0.12)) boost[n] = rng.pick([-2, -1, 1, 2]);
    const weak = rng.pick(YA.AB_FIELD);
    boost[weak] = (boost[weak] || 0) - 2;
    const p = YA.mkPlayer(rng, { id, num: 0, name, pos: grp, main: pos, lvl, boost, traits: [], pers: {}, height: 164 + rng.int(0, 22) + (grp === 'GK' ? 5 : pos === 'CB' ? 3 : 0) });
    // 性格
    for (const g of Object.keys(PERS_W)) {
      const ent = Object.entries(PERS_W[g]);
      p.pers[g] = rng.weighted(ent, (e) => e[1])[0];
    }
    // 特性：能力に合うものを1〜2個（高学年ほど持っている）
    const pool = (pos === 'GK' ? GK_TRAITS : FIELD_TRAITS).filter((t) => t in YA.TRAIT_AFF);
    const nt = grade === 1 ? rng.int(0, 1) : grade === 2 ? rng.int(0, 2) : rng.int(1, 2);
    for (let k = 0; k < nt; k++) {
      const t = rng.weighted(pool, (x) => Math.pow(YA.TRAIT_AFF[x].reduce((s, n) => s + (p.ab[n] || 1), 0) / 2 / 10, 3));
      if (p.traits.indexOf(t) < 0) p.traits.push(t);
    }
    // 隠れた中身：伸びしろ（能力の合計の上限）・伸びる速さ・項目ごとの伸びやすさ
    const room = Math.round((90 + quality * 28 + rng.int(-25, 40)) * (grade === 1 ? 1.25 : grade === 2 ? 1 : 0.75));
    p.pot = abSum(p) + clamp(room, 25, 260);
    p.rate = Math.round((0.75 + rng() * 0.6) * 100) / 100;
    p.aff = {};
    for (const n of abList(p)) p.aff[n] = Math.round((0.75 + rng() * 0.5) * 100) / 100;
    p.grade = grade;
    p.team = 'B';
    p.fat = rng.int(0, 15);
    p.inj = 0;
    p.mins = 0;
    p.prog = {};
    p.train = { focus: null, trait: null };
    p.tprog = {};
    p.rest = null; // null | 'light' | 'rest'
    p.star = false;
    p.spurt = 0; // 成長期の残り週
    p.unrest = 0; // 不満の溜まり
    p.talk = -99; // 最後に面談した週（通し）
    p.gain = {}; // 直近の伸び（表示用）
    p.hist = []; // 履歴（最近の出来事）
    p.stam = 100;
    return p;
  };

  function numbers(w) {
    const used = new Set(Object.values(w.players).map((p) => p.num).filter(Boolean));
    const pref = { GK: [1, 12, 13, 21, 22], DF: [2, 3, 4, 5, 14, 15, 16, 17, 23, 24], MF: [6, 8, 10, 18, 19, 20, 25, 26, 27, 28], FW: [7, 9, 11, 29, 30, 31, 32] };
    const take = (p) => {
      for (const n of pref[p.pos]) if (!used.has(n)) return n;
      for (let n = 2; n < 100; n++) if (!used.has(n)) return n;
    };
    for (const p of Object.values(w.players)) if (!p.num) {
      p.num = take(p);
      used.add(p.num);
    }
  }

  // 1学年12人（GK1・DF4・MF4・FW3）
  function genGrade(rng, w, grade, used) {
    const NEARP = { CB: ['DM', 'LB'], LB: ['LWB', 'CB'], RB: ['RWB', 'CB'], DM: ['CM', 'CB'], CM: ['DM', 'LM'], AM: ['SS', 'RM'], LW: ['LM', 'SS'], RW: ['RM', 'SS'], ST: ['SS', 'LW'] };
    const base15 = ['GK', 'CB', 'CB', 'LB', 'RB', 'DM', 'CM', 'CM', 'AM', 'LW', 'RW', 'ST'];
    const poss = base15.map((q) => (q !== 'GK' && rng.chance(0.3) ? NEARP[q][rng.int(0, 1)] : q));
    for (const pos of poss) {
      const id = 'p' + ++w.nextId;
      const q = clamp(Math.round((rng() + rng() + rng() - 1.5) * 2.2) + (w.tierQ || 0), -2, 2.5);
      w.players[id] = YA.genPlayer(rng, id, grade, pos, q, used);
    }
  }

  YA.newWorld = function (seed, opts) {
    opts = opts || {};
    const rng = YA.rngOf(seed);
    const w = { v: 1, seed, year: 1, week: 1, nextId: 0, players: {}, plan: null, inbox: [], events: [], alumni: [], results: [], rec: { w: 0, d: 0, l: 0, gf: 0, ga: 0 }, phase: 'plan', captain: null, formation: '4-3-3', lineupA: null, benchA: null, lineupB: null, tactic: null, lastWeek: null, season: 1, notes: [], clubName: 'レガーレ湘南U-18', matchDone: false, log: [] };
    w.tierQ = (2 - (opts.tier || 2)) * 0.5; // 上の部のクラブほど、素質のある子が集まる
    const used = new Set();
    for (const g of [1, 2, 3]) genGrade(rng, w, g, used);
    numbers(w);
    autoTeams(w, true);
    w.plan = defaultPlan();
    w.v = 3;
    w.coach = opts.coach ? Object.assign(YA.newCoach(), opts.coach) : YA.newCoach();
    w.coachName = opts.coachName || '監督';
    w.tut = { on: opts.tutorial !== false };
    w.scouting = YA.newScouting();
    w.disc = 60;
    w.rules = [];
    w.trophies = [];
    w.h2h = {};
    w.rel = [];
    YA.newClub(w, opts.tier || 2, opts.clubName || w.clubName);
    w.club.noFire = !!opts.noFire;
    if (opts.repAdj) YA.addRep(w, opts.repAdj);
    YA.relations(w);
    YA.yearStart(w);
    YA.autoPlan(w);
    w.inbox.push({ week: 0, year: 1, tier: 2, text: '指導者として着任しました。高1〜高3の36人を預かります。まずは練習を組んで、週を進めましょう。' });
    return w;
  };

  function defaultPlan() {
    return { days: [{ menu: 'ボール回し', int: 'normal' }, { menu: '対人', int: 'normal' }, { menu: '戦術', int: 'normal' }, { menu: 'シュート', int: 'normal' }, { menu: '回復', int: 'light' }] };
  }
  YA.defaultPlan = defaultPlan;

  // ---------- チーム（A・B）の自動選出 ----------
  const SQUAD = { GK: 2, DF: 7, MF: 7, FW: 4 }; // Aの登録20
  function healthy(p) {
    return p.inj <= 0 && !(p.away > 0) && !(p.suspend > 0);
  }
  function autoTeams(w, init) {
    const all = Object.values(w.players);
    // Aは能力の高い順に位置ごとの枠を埋める（学年は問わない）
    const byPos = {};
    for (const p of all) (byPos[p.pos] = byPos[p.pos] || []).push(p);
    for (const k of Object.keys(byPos)) byPos[k].sort((a, b) => YA.ovr(b) - YA.ovr(a));
    const A = new Set();
    for (const pos of Object.keys(SQUAD)) byPos[pos].slice(0, SQUAD[pos]).forEach((p) => A.add(p.id));
    for (const p of all) p.team = A.has(p.id) ? 'A' : 'B';
    // 布陣4-3-3の11人
    pickLineup(w, 'A', init ? '4-3-3' : w.formation);
    pickLineup(w, 'B', (w.bCtl && w.bCtl.form) || '4-3-3');
  }
  const NEED = { '4-3-3': { GK: 1, DF: 4, MF: 3, FW: 3 }, '4-4-2': { GK: 1, DF: 4, MF: 4, FW: 2 }, '4-2-3-1': { GK: 1, DF: 4, MF: 5, FW: 1 }, '3-5-2': { GK: 1, DF: 3, MF: 5, FW: 2 }, '5-3-2': { GK: 1, DF: 5, MF: 3, FW: 2 } };
  function pickLineup(w, which, formation) {
    if (!YA.FORMATIONS[formation]) formation = '4-3-3';
    const pool = Object.values(w.players).filter((p) => p.team === which);
    // Bの起用方針が「手動」なら、いまの並びを残す（人が変わった・布陣が変わったときだけ組み直す）
    if (which === 'B' && w.bCtl && w.bCtl.policy === 'manual' && w.lineupB && w.benchB && w.lineupB.length === YA.FORMATIONS[formation].length
      && w.lineupB.every((s) => w.players[s.pid] && w.players[s.pid].team === 'B') && w.benchB.every((id) => w.players[id] && w.players[id].team === 'B')
      && w.bCtl.formKept === formation) return;
    const fm = YA.FORMATIONS[formation];
    const need = { GK: 0, DF: 0, MF: 0, FW: 0 };
    fm.forEach((s, i) => need[YA.posOfSlot(s, i)]++);
    const chosen = [];
    for (const pos of ['GK', 'DF', 'MF', 'FW']) {
      // Bチームの起用方針（決定30）：力の順／下級生を優先／疲れの少ない順
      const pol = which === 'B' && w.bCtl ? w.bCtl.policy : 'best';
      const key = (p) => YA.ovr(p) - (p.fat * 0.01) + (pol === 'young' ? (3 - p.grade) * 0.6 : 0) - (pol === 'rest' ? p.fat * 0.04 : 0);
      let c = pool.filter((p) => p.pos === pos && healthy(p)).sort((a, b) => key(b) - key(a));
      if (pos === 'GK' && !c.length) c = pool.filter((p) => p.pos === 'GK').sort((a, b) => YA.ovr(b) - YA.ovr(a));
      chosen.push(...c.slice(0, need[pos]));
    }
    // 足りない位置は他の位置から補う
    if (chosen.length < 11) {
      const rest = pool.filter((p) => healthy(p) && chosen.indexOf(p) < 0 && p.pos !== 'GK').sort((a, b) => YA.ovr(b) - YA.ovr(a));
      chosen.push(...rest.slice(0, 11 - chosen.length));
    }
    // 布陣の各枠へ、位置の近い順に割り当てる
    const slots = fm.map((s, i) => ({ i, s, pos: YA.pos15OfSlot(s, i) }));
    const lineup = new Array(11);
    const left = chosen.slice();
    for (const sl of slots) {
      // その位置の適性が一番高い選手を置く（GKはGKだけ）
      let k = -1;
      let bv = -1e9;
      left.forEach((p, j) => {
        if ((p.pos === 'GK') !== (sl.pos === 'GK')) return;
        const v = (p.apt ? p.apt[sl.pos] : 10) + (p.main === sl.pos ? 0.4 : 0);
        if (v > bv) { bv = v; k = j; }
      });
      if (k < 0) k = 0;
      const p = left.splice(k, 1)[0];
      lineup[sl.i] = { pid: p.id, x: sl.s.x, y: sl.s.y, role: YA.defaultRole(sl.pos) };
      YA.fixSlotRole(lineup[sl.i], sl.i);
    }
    const bench = pool.filter((p) => !lineup.some((l) => l.pid === p.id)).sort((a, b) => YA.ovr(b) - YA.ovr(a)).map((p) => p.id);
    if (which === 'A') {
      w.lineupA = lineup;
      w.benchA = bench.slice(0, 9);
      w.formation = formation;
    } else {
      w.lineupB = lineup;
      w.benchB = bench.slice(0, 9);
    }
  }
  YA.autoTeams = autoTeams;
  YA.pickLineup = pickLineup;

  // 怪我などで抜けた選手を、同じ位置のベンチと入れ替える
  function repairLineup(w, which) {
    const lineup = which === 'A' ? w.lineupA : w.lineupB;
    const bench = which === 'A' ? w.benchA : w.benchB;
    const swaps = [];
    lineup.forEach((s, i) => {
      const p = w.players[s.pid];
      if (p && healthy(p)) return;
      const pos = YA.posOfSlot(s, i);
      let k = bench.findIndex((id) => w.players[id] && healthy(w.players[id]) && (pos === 'GK' ? w.players[id].pos === 'GK' : w.players[id].pos !== 'GK'));
      if (pos !== 'GK') {
        // その位置の適性が一番高いベンチの選手
        const p15 = YA.pos15OfSlot(s, i);
        let k2 = -1;
        let bv2 = -1;
        bench.forEach((id, kk) => {
          const q = w.players[id];
          if (q && healthy(q) && q.pos !== 'GK' && q.apt && q.apt[p15] > bv2) { bv2 = q.apt[p15]; k2 = kk; }
        });
        if (k2 >= 0) k = k2;
      }
      if (k < 0) return;
      const inId = bench[k];
      bench[k] = s.pid;
      s.pid = inId;
      swaps.push([p, w.players[inId]]);
    });
    swaps.push(...limitForeign(w, which));
    return swaps;
  }
  // 外国籍の出場は3人まで（登録は5人まで）。超えたら、同じ括りの日本人のベンチと入れ替える
  function isForeign(p) {
    return !!p && !!p.nation && p.nation !== '日本';
  }
  YA.isForeign = isForeign;
  function limitForeign(w, which) {
    const lineup = which === 'A' ? w.lineupA : w.lineupB;
    const bench = which === 'A' ? w.benchA : w.benchB;
    const swaps = [];
    let guard = 0;
    while (guard++ < 6) {
      const fs = lineup.map((s, i) => ({ s, i, p: w.players[s.pid] })).filter((x) => isForeign(x.p));
      if (fs.length <= 3) break;
      const out = fs.sort((a, b) => YA.ovr(a.p) - YA.ovr(b.p))[0];
      const p15 = YA.pos15OfSlot(out.s, out.i);
      let k = -1;
      let bv = -1;
      bench.forEach((id, kk) => {
        const q = w.players[id];
        if (q && healthy(q) && !isForeign(q) && (q.pos === 'GK') === (out.p.pos === 'GK') && q.apt && q.apt[p15] > bv) { bv = q.apt[p15]; k = kk; }
      });
      if (k < 0) break;
      const inId = bench[k];
      bench[k] = out.s.pid;
      out.s.pid = inId;
      swaps.push([out.p, w.players[inId]]);
    }
    return swaps;
  }
  YA.limitForeign = limitForeign;
  YA.tactRepOf = function (w) {
    const same = w.tactMem && w.tactic && w.tactMem.type === w.tactic.type ? w.tactMem.weeks : 0;
    return Math.round((0.6 + 0.4 * Math.min(1, same / 12)) * 100) / 100;
  };
  YA.repairLineup = repairLineup;

  // 名簿 → 試合用のチーム（engine の Match がそのまま使える形）
  YA.teamFromWorld = function (w, which) {
    const lineup = which === 'A' ? w.lineupA : w.lineupB;
    const bench = which === 'A' ? w.benchA : w.benchB;
    lineup.forEach((s, i) => YA.fixSlotRole(s, i)); // 古い保存データの役割名や、任務のないスロットを直す
    const ids = lineup.map((s) => s.pid).concat(bench);
    const players = {};
    for (const id of ids) {
      const p = w.players[id];
      p._startStam = clamp(100 - p.fat * 0.55, 35, 100);
      p.isCap = w.captain === id;
      p.isVice = w.vice === id;
      p.friends = (w.rel || []).filter((x) => x.k === 'friend' && (x.a === id || x.b === id)).map((x) => (x.a === id ? x.b : x.a));
      players[id] = p;
    }
    return { id: 'me', name: w.clubName + (which === 'B' ? ' B' : ''), short: which === 'B' ? 'レガーレB' : 'レガーレ', color: '#1f6feb', isUser: true, players, lineup: JSON.parse(JSON.stringify(lineup)), bench: bench.slice(), tactic: which === 'B' && w.bCtl && w.bCtl.tactic && YA.TACTICS[w.bCtl.tactic] ? Object.assign({ type: w.bCtl.tactic }, YA.TACTICS[w.bCtl.tactic]) : w.tactic ? JSON.parse(JSON.stringify(w.tactic)) : Object.assign({ type: 'ポゼッション' }, YA.TACTICS['ポゼッション']), instr: {}, subsUsed: 0, windowsUsed: 0, formation: w.formation, prep: YA.analysisLevel ? YA.analysisLevel(w) : 0, coachTactic: w.coach ? w.coach.tactic : 10, disc: w.disc, tactRep: YA.tactRepOf(w) };
  };

  // 相手（週ごとに決まる）。年とともに強くなる
  const AREAS = ['横浜', '川崎', '相模原', '千葉', '埼玉', '東京', '茨城', '静岡', '山梨', '栃木', '群馬', '長野'];
  const NICK = ['ブルーウィング', 'シルバーホーク', 'アルバトロス', 'グリーンリーフ', 'ノースウィンド', 'サンライズ', 'レッドフォックス', 'ブラックベアーズ', 'ホワイトタイガース', 'ゴールデンイーグル'];
  const HS = ['学院高校', '第一高校', '東高校', '南高校', '北高校', '工業高校', '大付属高校'];
  YA.opponentOf = function (w) {
    const r = YA.rngOf(w.seed * 31 + w.year * 1000 + w.week * 7);
    const kind = r.chance(0.55) ? 'club' : 'high';
    const area = r.pick(AREAS);
    const name = kind === 'club' ? area + ' ' + r.pick(NICK) + 'ユース' : area + r.pick(HS);
    const style = r.pick(['power', 'tech', 'defend']);
    const tac = { power: 'ハイプレス', tech: 'ポゼッション', defend: '堅守' }[style];
    const lvl = 9.6 + w.year * 0.35 + r() * 2.2 + (kind === 'club' ? 0.4 : 0);
    const fm = r.pick(['4-4-2', '4-3-3', '5-3-2', '4-2-3-1']);
    return { id: 'o' + w.year + '_' + w.week, name, short: name.length > 9 ? name.slice(0, 9) : name, color: r.pick(['#c0392b', '#2c3e50', '#7f8c8d', '#8e44ad', '#d35400', '#16a085']), lvl, formation: fm, tactic: tac, desc: style === 'power' ? '体が強く、前から奪いにくる' : style === 'tech' ? 'つないで崩す技術派' : '堅守速攻。裏抜けに注意', style, home: r.chance(0.5) };
  };

  // ---------- 1週を進める：練習 → 怪我・疲れ → 出来事 ----------
  function noteTier(w, tier, text, pid) {
    w.inbox.push({ week: w.week, year: w.year, tier, text, pid: pid || null, n: (w.inboxN = (w.inboxN || 0) + 1) });
    if (w.inbox.length > 300) w.inbox.splice(0, w.inbox.length - 300);
  }

  // 背が高いと空中戦・ヘディング・強さが、小柄だと敏しょう性・加速・バランスが伸びやすい
  const TALL_AB = new Set(['ヘディング', 'ジャンプ', '強さ', '空中戦']);
  const SMALL_AB = new Set(['敏しょう性', '加速', 'バランス']);
  function heightK(p, a) {
    const d = p.height - 178;
    if (TALL_AB.has(a)) return clamp(1 + d * 0.012, 0.85, 1.2);
    if (SMALL_AB.has(a)) return clamp(1 - d * 0.01, 0.87, 1.15);
    return 1;
  }
  // 伸び盛り（1.5倍）と壁（0.5倍）。数週間〜数か月続く
  const stateK = (p) => (p.state && p.state.w > 0 ? (p.state.k === 'peak' ? 1.3 : 0.5) : 1);
  YA.runTraining = function (w) {
    const rng = YA.rngOf(w.seed * 13 + w.year * 777 + w.week * 31);
    const plan = w.plan || defaultPlan();
    const hasPractice = plan.days.some((d) => d.menu === '練習試合');
    const all = Object.values(w.players);
    const gains = {};
    const tfx = YA.trainerFx ? YA.trainerFx(w) : { recover: 0, inj: 1 };
    const dscMult = 0.9 + (w.disc == null ? 60 : w.disc) / 500;
    let recoveries = 0;
    for (const d of plan.days) if (d.menu === '回復') recoveries++;
    for (const p of all) {
      p.gain = {};
      const inj = p.inj > 0;
      const rest = p.rest === 'rest' || inj || p.away > 0;
      const light = p.rest === 'light';
      let fatAdd = 0;
      const exp = {};
      if (!rest) {
        for (const d of plan.days) {
          const menu = YA.MENUS[d.menu];
          const k = INTENS[d.int] * (light ? 0.55 : 1);
          fatAdd += menu.fat * (menu.fat > 0 ? k : 1);
          for (const [a, wgt] of Object.entries(menu.ab)) exp[a] = (exp[a] || 0) + (wgt * k) / 5;
          if (p.pos === 'GK' && menu.fat > 0) for (const [a, wgt] of Object.entries(GK_TRAIN)) exp[a] = (exp[a] || 0) + (wgt * k * 0.55) / 5;
        }
        // 重点的に取り組む能力
        const f = p.train.focus;
        if (f && p.ab[f] != null) exp[f] = (exp[f] || 0) + 0.65 * (light ? 0.55 : 1);
      } else {
        fatAdd = -2.0;
      }
      // 試合の経験（頭の能力と自信に上乗せ。出番がなければなし）
      // 練習試合：Bの選手に出番ができて、不満が和らぐ
      if (hasPractice && !rest && p.team === 'B') {
        p._weekMins = (p._weekMins || 0) + 45;
        p.mins += 45;
        p.unrest = Math.max(0, p.unrest - 0.6);
        p.conf = clamp(p.conf + 1, 0, 100);
      }
      const mm = p._weekMins || 0;
      if (mm > 0) {
        const tier = (p.team === 'A' ? 1 : 0.55) * (w.league ? YA.LEVEL_EXP[w.league.level - 1] : 1);
        for (const a of YA.AB_MENTAL) exp[a] = (exp[a] || 0) + (mm / 90) * 0.5 * tier;
      }
      p._weekMins = 0;
      // 疲れ・怪我
      p.fat = clamp(p.fat + fatAdd * 2.4 * (w.campMult > 1 ? 1.15 : 1) - (rest ? 0 : 14 + tfx.recover), 0, 100);
      if (!rest) {
        const risk = (0.003 + Math.max(0, p.fat - 55) / 100 * 0.035 + (p.spurt > 0 ? 0.01 : 0)) * tfx.inj * (w.campMult > 1.5 ? 1.5 : 1);
        if (rng() < risk * (light ? 0.5 : 1)) {
          p.inj = rng.int(1, p.fat > 80 ? 8 : 5);
          p._injLen = p.inj;
          p.hist.unshift({ y: w.year, w: w.week, t: '怪我（' + p.inj + '週）' });
          noteTier(w, 1, p.num + '番 ' + p.name + ' が練習中に怪我。全治' + p.inj + '週', p.id);
        }
      } else if (inj) {
        p.inj = Math.max(0, p.inj - 1);
        if (p.inj === 0) {
          noteTier(w, 2, p.num + '番 ' + p.name + ' が怪我から復帰', p.id);
          // 長い怪我は、体の能力が少し下がる（大怪我は2つ）
          if ((p._injLen || 0) >= 6 && rng() < 0.55) {
            const phys = ['スピード', '加速', 'スタミナ', '敏しょう性', 'バランス', 'ジャンプ', '強さ'];
            const lost = [];
            for (let k = 0; k < ((p._injLen || 0) >= 8 ? 2 : 1); k++) {
              const n1 = rng.pick(phys);
              if (p.ab[n1] > 4 && lost.indexOf(n1) < 0) {
                p.ab[n1]--;
                lost.push(n1);
              }
            }
            if (lost.length) {
              noteTier(w, 2, p.num + '番 ' + p.name + ' は長い怪我の影響で、' + lost.map((x) => '「' + x + '」').join('') + 'の能力が下がった', p.id);
              p.hist.unshift({ y: w.year, w: w.week, t: '長い怪我で能力が下がった（' + lost.join('・') + '）' });
            }
          }
          p._injLen = 0;
        }
      }
      if (p.inj > 0 && !inj) {
        /* 今週発生した怪我 */
      }
      // 成長
      const sum = abSum(p);
      const roomF = clamp((p.pot - sum) / 55, 0, 1);
      const cond = clamp(1.15 - p.fat / 170, 0.3, 1.1) * (p.conf < 35 ? 0.8 : p.conf > 70 ? 1.1 : 1) * (p.unrest > 3 ? 0.85 : 1) * (p.spurt > 0 ? 1.35 : 1) * (p.form > 1 ? 1.1 : 1);
      const diligence = anyP(p, '真面目') ? 1.08 : anyP(p, '練習嫌い') ? 0.9 : 1;
      for (const [a, e] of Object.entries(exp)) {
        const aff = p.aff[a] || 1;
        const g = e * 0.17 * p.rate * aff * roomF * cond * diligence * heightK(p, a) * stateK(p) * (YA.staffMult ? YA.staffMult(w, p, a) * YA.coachMult(w) * (w.campMult || 1) * dscMult : 1) * (p.adapt > 0 ? 0.92 : 1);
        // 高い値ほど伸びにくい
        const hard = clamp(1.25 - p.ab[a] / 22, 0.25, 1);
        p.prog[a] = (p.prog[a] || 0) + g * hard;
        while (p.prog[a] >= 1 && p.ab[a] < 20) {
          p.prog[a] -= 1;
          p.ab[a]++;
          p.gain[a] = (p.gain[a] || 0) + 1;
        }
      }
      // 特性練習
      const tr = p.train.trait;
      if (tr && !rest && p.traits.indexOf(tr) < 0) {
        const aff2 = YA.TRAIT_AFF[tr];
        const q = aff2.reduce((s, n) => s + p.ab[n], 0) / 2;
        const speed = clamp((q / 11) * (q / 11), 0.35, 2.2) * p.rate * (light ? 0.55 : 1) * cond * 2.6;
        p.tprog[tr] = (p.tprog[tr] || 0) + speed;
        if (p.tprog[tr] >= 100) {
          p.tprog[tr] = 0;
          if (p.traits.length < 5) p.traits.push(tr);
          p.train.trait = null;
          p.hist.unshift({ y: w.year, w: w.week, t: '特性「' + tr + '」を習得' });
          noteTier(w, 2, p.num + '番 ' + p.name + ' が特性「' + tr + '」を身につけた', p.id);
        }
      }
      YA.refreshApt(p);
      // 自信・調子は少しずつ戻る
      p.form = Math.round((p.form * 0.6) * 10) / 10;
      p.conf = clamp(p.conf + (p.conf < 55 ? 2.2 : -0.8), 0, 100);
      if (p.spurt > 0) p.spurt--;
      if (p.state && p.state.w > 0) {
        p.state.w--;
        if (p.state.w <= 0) p.state = null;
      }
      p.unrest = Math.max(0, p.unrest - 0.5); // 面談が月1回になったので、自然に和らぐ量を増やした
      for (const a of Object.keys(p.gain)) gains[p.id] = (gains[p.id] || 0) + p.gain[a];
    }
    // 成長期（その子のタイミングで始まる）
    for (const p of all) if (p.spurt <= 0 && rng() < 0.012 * (p.grade === 1 ? 1.4 : 0.8) && p.height < 190) {
      p.spurt = rng.int(6, 12);
      p.height += rng.int(1, 4);
      // 急に伸びたあとは、しばらく敏しょう性とバランスが下がる
      for (const n1 of ['敏しょう性', 'バランス']) if (p.ab[n1] > 3) p.ab[n1]--;
      noteTier(w, 2, p.num + '番 ' + p.name + ' が成長期に入った（伸びやすい時期。体が急に伸びて、敏しょう性とバランスは一時的に下がる）', p.id);
    }
    // 目立つ伸び
    const big = Object.keys(gains).map((id) => [id, gains[id]]).sort((a, b) => b[1] - a[1]).slice(0, 2);
    for (const [id, g] of big) if (g >= 3) noteTier(w, 3, w.players[id].num + '番 ' + w.players[id].name + ' が今週よく伸びた（能力+' + g + '）', id);
    return gains;
  };
  const anyP = (p, v) => Object.values(p.pers).indexOf(v) >= 0;

  // ---------- 出来事（会話の選択肢）----------
  const pname = (p) => p.num + '番 ' + p.name;
  function conf(p, d) {
    p.conf = clamp(p.conf + d, 0, 100);
  }
  const ST = (p, g, v) => p.pers[g] === v;
  // 選んだ言葉×性格で反応が変わる。{msg, d:{...}} を返す。d は画面に小さく出す
  function react(p, kind) {
    // kind: warm（寄り添う）/ firm（厳しく）/ push（背中を押す）/ wait（任せる）
    let c = 0;
    let f = 0;
    let line = '';
    const t = (g, v) => ST(p, g, v);
    if (kind === 'warm') {
      c = 5;
      line = 'ほっとした表情で「ありがとうございます」と言った';
      if (t('教えの受け止め方', '構ってほしい')) { c += 4; line = '目を輝かせて「もっと頑張ります」と言った'; }
      if (t('教えの受け止め方', '反骨心')) { c -= 3; line = '「甘やかさないでください」と少し不満そうだった'; }
      if (t('プレーの気質', '自信家')) { c -= 1; line = '「分かってます」と頷いた'; }
    } else if (kind === 'firm') {
      c = -2;
      line = '黙って受け止めた';
      if (t('教えの受け止め方', '反骨心')) { c = 6; f = 1; line = '「見ていてください」と目の色が変わった'; }
      else if (t('教えの受け止め方', '素直')) { c = 2; line = '「はい」と引き締まった'; }
      else if (t('気持ちの強さ', '繊細')) { c = -8; f = -1; line = '俯いて、しばらく言葉が出なかった'; }
      else if (t('教えの受け止め方', '頑固')) { c = 0; line = '納得していない様子だが、聞いてはいた'; }
      else if (t('感情の波', '短気')) { c = -4; f = -1; line = 'ふてくされて、そっぽを向いた'; }
    } else if (kind === 'push') {
      c = 4;
      f = 0.5;
      line = '「やってやります」と頷いた';
      if (t('気持ちの強さ', '負けず嫌い')) { c += 3; f = 1; line = '闘志に火が付いた'; }
      if (t('大舞台', 'プレッシャーに弱い') || t('気持ちの強さ', '繊細')) { c -= 6; f = -0.5; line = '重圧を感じたのか、表情が固くなった'; }
    } else {
      c = 0;
      line = '少し間をおいて「分かりました」と言った';
      if (t('教えの受け止め方', '構ってほしい')) { c = -4; line = '見放されたように感じたようだ'; }
      if (t('教えの受け止め方', 'マイペース')) { c = 2; line = '自分のペースでやれると安心した'; }
      if (t('気持ちの強さ', '楽天家')) { c = 2; }
    }
    return { c, f, line };
  }
  YA.react = react;
  function apply(p, r) {
    conf(p, r.c);
    p.form = clamp(p.form + r.f, -3, 3);
    const parts = [];
    if (r.c) parts.push('自信 ' + (r.c > 0 ? '+' : '') + Math.round(r.c));
    if (r.f) parts.push('調子 ' + (r.f > 0 ? '+' : '') + r.f);
    return parts.join(' / ');
  }
  const opt = (label, kind, extra) => ({ label, kind, extra });

  const QUIT_OK = { 不満: 0.62, 怪我: 0.72, 能力: 0.42, 家庭: 0.35 };
  const QUIT_NAME = { 不満: '不満', 怪我: '怪我', 能力: '能力的に厳しく', 家庭: '家庭の事情' };
  YA.EVENTS = [
    { id: 'unrest', name: '出番の不満', weight: 1.4,
      pick: (w, r) => { const c = Object.values(w.players).filter((p) => p.team === 'B' && p.mins < 60 && YA.ovr(p) > 8.5 && p.inj <= 0 && w.year * 40 + w.week > 6); return c.length ? r.pick(c) : null; },
      text: (p) => pname(p) + 'が声をかけてきた。「最近、試合に出られていません。何が足りないんでしょうか」',
      opts: [opt('次の機会は必ず作る、と約束する', 'warm', (w, p) => { p.unrest = Math.max(0, p.unrest - 2); }), opt('練習で見せろ、と求める', 'push', (w, p) => { p.train.promise = true; }), opt('今は我慢の時期だと伝える', 'firm', (w, p) => { p.unrest += 2; })] },
    { id: 'lowconf', name: '自信喪失', weight: 2,
      pick: (w, r) => { const c = Object.values(w.players).filter((p) => p.conf < 38 && p.inj <= 0); return c.length ? r.pick(c) : null; },
      text: (p) => pname(p) + 'の表情が暗い。「自分には、無理なんじゃないかと思って…」',
      opts: [opt('ゆっくり話を聞いて励ます', 'warm'), opt('弱点と、できていることを具体的に示す', 'push'), opt('少し休んで気持ちを切り替えさせる', 'wait', (w, p) => { p.rest = 'light'; p.fat = clamp(p.fat - 12, 0, 100); })] },
    { id: 'tired', name: '疲れ・練習のしすぎ', weight: 2,
      pick: (w, r) => { const c = Object.values(w.players).filter((p) => p.fat > 72 && p.inj <= 0); return c.length ? r.pick(c) : null; },
      text: (p) => pname(p) + 'の動きが重い。トレーナーが「疲れが溜まっています」と報告してきた',
      opts: [opt('今週は休ませる', 'warm', (w, p) => { p.rest = 'rest'; }), opt('軽めのメニューに替える', 'wait', (w, p) => { p.rest = 'light'; }), opt('このまま続けさせる', 'firm', (w, p) => { p.fat += 4; })] },
    { id: 'injury', name: '怪我の相談', weight: 1.6,
      pick: (w, r) => { const c = Object.values(w.players).filter((p) => p.inj >= 2); return c.length ? r.pick(c) : null; },
      text: (p) => pname(p) + 'の怪我について、トレーナーが相談してきた。「早く戻すこともできますが、再発の恐れがあります」',
      opts: [opt('慎重に治す', 'warm', (w, p) => { p.inj += 1; }), opt('早く戻す', 'push', (w, p, r) => { p.inj = Math.max(1, p.inj - 1); if (r() < 0.3) { p.inj += 3; noteTier(w, 1, pname(p) + ' が無理をして再発した', p.id); } }), opt('本人に任せる', 'wait')] },
    { id: 'rival', name: '張り合い', weight: 1.3,
      pick: (w, r) => { const A = Object.values(w.players); const c = A.filter((p) => p.pos !== 'GK' && p.team === 'B' && A.some((q) => q.team === 'A' && q.pos === p.pos && Math.abs(YA.ovr(q) - YA.ovr(p)) < 1.4)); return c.length ? r.pick(c) : null; },
      text: (p) => pname(p) + 'は、同じポジションのAチームの選手を強く意識している。練習で張り合う場面が増えた',
      opts: [opt('競わせて伸ばす', 'push'), opt('それぞれ役割を分けて育てる', 'warm'), opt('特に何も言わない', 'wait')] },
    { id: 'senpai', name: '先輩の助言', weight: 1.2,
      pick: (w, r) => { const c = Object.values(w.players).filter((p) => p.grade === 3 && (ST(p, '人との関わり', '世話好き') || ST(p, '人との関わり', 'リーダー気質') || ST(p, '人との関わり', '仲間思い'))); return c.length ? r.pick(c) : null; },
      text: (p) => pname(p) + 'が、後輩にプレーのアドバイスをしている。いい雰囲気だ',
      opts: [opt('後輩を任せて、もっと教えさせる', 'warm', (w, p, r) => { const k = Object.values(w.players).filter((q) => q.grade === 1 && q.pos === p.pos && q.team !== undefined); if (k.length) { const q = r.pick(k); q.prog.判断 = (q.prog.判断 || 0) + 0.8; q.prog.予測 = (q.prog.予測 || 0) + 0.8; } }), opt('見守る', 'wait')] },
    { id: 'family', name: '家庭の事情', weight: 1,
      pick: (w, r) => { const c = Object.values(w.players).filter((p) => ST(p, '目指すもの', '家族思い') || r() < 0.04); return c.length ? r.pick(c) : null; },
      text: (p) => pname(p) + 'の家庭で、遠征費のことが話題になっているという。本人は気にしている様子だ',
      opts: [opt('本人の話を聞く', 'warm'), opt('クラブに相談してみる、と伝える', 'push'), opt('そっとしておく', 'wait')] },
    { id: 'homesick', name: 'ホームシック', weight: 0.9,
      pick: (w, r) => { const c = Object.values(w.players).filter((p) => (ST(p, '目指すもの', '寂しがり') || ST(p, '人との関わり', '人見知り')) && p.dorm !== false); return c.length ? r.pick(c) : null; },
      text: (p) => pname(p) + 'は、チームにまだ馴染みきれていないようだ。一人でいることが多い',
      opts: [opt('仲の良い選手とペアで練習させる', 'warm', (w, p) => { p.unrest = Math.max(0, p.unrest - 1); }), opt('声をかけて背中を押す', 'push'), opt('様子を見る', 'wait')] },
    { id: 'hot', name: '絶好調', weight: 1.3,
      pick: (w, r) => { const c = Object.values(w.players).filter((p) => p.form >= 1 || p.conf > 80); return c.length ? r.pick(c) : null; },
      text: (p) => pname(p) + 'が絶好調だ。練習でも目立っている',
      opts: [opt('褒めて、さらに上を求める', 'push', (w, p) => { p.spurt = Math.max(p.spurt, 3); }), opt('調子に乗らないよう戒める', 'firm'), opt('そのまま伸ばす', 'wait')] },
    { id: 'quit', name: '退団の相談', weight: 0.7,
      pick: (w, r) => {
        const c = Object.values(w.players).filter((p) => (p.unrest >= 4 || (p.conf < 25 && p.mins < 120) || p.inj >= 8 || (p.grade >= 2 && YA.ovr(p) < 9 && p.mins < 150) || (ST(p, '目指すもの', '家族思い') && r() < 0.03)) && Object.keys(w.players).length > 32);
        if (!c.length) return null;
        const p = r.pick(c);
        // 退団の理由は4つ：家庭の事情・怪我・能力的に厳しい・不満（決定29）
        p._qr = p.inj >= 8 ? '怪我' : p.grade >= 2 && YA.ovr(p) < 9 && p.mins < 150 ? '能力' : p.unrest < 4 && ST(p, '目指すもの', '家族思い') ? '家庭' : '不満';
        return p;
      },
      text: (p) => pname(p) + 'が思い詰めた様子で来た。「' + ({ 怪我: '怪我が長引いて、続けられる自信がなくなりました', 能力: 'みんなについていけません。サッカーを続けるのは厳しいと思います', 家庭: '家の事情で、続けるのが難しくなりました', 不満: 'チームを辞めようと思っています。試合に出られず、悔しくて' }[p._qr || '不満']) + '」',
      opts: [
        opt('引き止める（本気で話し合う）', 'warm', (w, p, r) => { if (r() < QUIT_OK[p._qr || '不満']) { p.unrest = 0; conf(p, 8); } else p._leave = true; }),
        opt('本人の意思を尊重して送り出す', 'wait', (w, p) => { p._leave = true; }),
        opt('起用の機会を約束して残ってもらう', 'push', (w, p, r) => { if (r() < QUIT_OK[p._qr || '不満'] * 0.9) { p.unrest = 0; p.train.promise = true; } else p._leave = true; }),
      ] },
    { id: 'change', name: '性格が変わる', weight: 0, pick: () => null, text: () => '', opts: [] },
  ];

  // 今週の出来事を作る（1〜2件。必ず止まる）
  YA.rollEvents = function (w) {
    const r = YA.rngOf(w.seed * 17 + w.year * 555 + w.week * 11);
    const n = r.chance(0.6) ? 1 : r.chance(0.5) ? 2 : 0;
    const out = [];
    for (const f of w.forced || []) out.push(f);
    w.forced = [];
    const used = new Set();
    for (let k = 0; k < n; k++) {
      const defs = YA.EVENTS.filter((e) => e.weight > 0);
      for (let tries = 0; tries < 8; tries++) {
        const ev = r.weighted(defs, (e) => e.weight);
        const p = ev.pick(w, r);
        if (!p || used.has(p.id) || used.has(ev.id)) continue;
        used.add(p.id);
        used.add(ev.id);
        out.push({ id: ev.id, pid: p.id || null, x: p._club != null ? p._club : p._staff, week: w.week, year: w.year });
        break;
      }
    }
    // 一定の確率で、性格が隣へ変わる気づき
    if (r() < 0.04) {
      const p = r.pick(Object.values(w.players));
      const g = r.pick(Object.keys(YA.PERS_GROUPS));
      const list = YA.PERS_GROUPS[g].slice(1);
      const i = list.indexOf(p.pers[g]);
      const next = list[clamp(i + (r.chance(0.5) ? 1 : -1), 0, list.length - 1)];
      if (next && next !== p.pers[g] && i >= 0) {
        const old = p.pers[g];
        p.pers[g] = next;
        p.hist.unshift({ y: w.year, w: w.week, t: '性格が変わった（' + old + ' → ' + next + '）' });
        noteTier(w, 1, p.num + '番 ' + p.name + ' の性格が変わった：' + old + ' → ' + next, p.id);
      }
    }
    return out;
  };

  YA.eventView = function (w, e) {
    const def = YA.EVENTS.find((x) => x.id === e.id);
    const p = e.pid ? w.players[e.pid] : null;
    if (!def || (e.pid && !p)) return null;
    if (e.x != null) {
      w._clubReq = e.x;
      w._staffIdx = Math.min(e.x, (w.club ? w.club.staff.length : 1) - 1);
    }
    return { name: def.name, text: def.text(p, w), p, opts: def.opts.map((o) => o.label) };
  };
  YA.resolveEvent = function (w, e, idx) {
    const def = YA.EVENTS.find((x) => x.id === e.id);
    const p = e.pid ? w.players[e.pid] : null;
    const o = def.opts[idx];
    const r = YA.rngOf(w.seed * 5 + w.year * 99 + w.week * 3 + idx);
    if (e.x != null) {
      w._clubReq = e.x;
      w._staffIdx = Math.min(e.x, w.club.staff.length - 1);
    }
    if (o.run) {
      const rr = o.run(w, p, r);
      return { line: rr.line, small: rr.small || '', leave: '' };
    }
    const res = react(p, o.kind);
    const small = apply(p, res);
    if (o.extra) o.extra(w, p, r);
    p.hist.unshift({ y: w.year, w: w.week, t: def.name + '：' + o.label });
    let leave = '';
    if (p._leave) {
      delete p._leave;
      removePlayer(w, p.id);
      leave = pname(p) + ' はチームを去った。空いた枠は、途中加入で埋まった';
      newcomer(w, r, p.grade);
    }
    return { line: res.line, small, leave };
  };

  function removePlayer(w, id) {
    const p = w.players[id];
    w.alumni.push({ name: p.name, pos: p.pos, year: w.year, ovr: Math.round(YA.ovr(p) * 10) / 10, note: '退団（' + (QUIT_NAME[p._qr] || '不満') + '）', grade: p.grade, age: null, status: 'left', club: '', apps: 0, goals: 0, nat: 0, transfers: 0, retired: false, traits: p.traits.slice() });
    delete w.players[id];
    for (const k of ['lineupA', 'lineupB']) { /* 入れ替えは autoTeams で */ }
    autoTeamsKeep(w);
  }
  // 退団・加入のあと、抜けた分だけ補う（他の人の並びは変えない）
  function autoTeamsKeep(w) {
    const gone = (l) => l.some((s) => !w.players[s.pid]);
    for (const [k, b, which] of [['lineupA', 'benchA', 'A'], ['lineupB', 'benchB', 'B']]) {
      if (!w[k]) continue;
      w[b] = w[b].filter((id) => w.players[id]);
      if (gone(w[k])) {
        w[k].forEach((s, i) => {
          if (w.players[s.pid]) return;
          const pos = YA.posOfSlot(s, i);
          const j = w[b].findIndex((id) => w.players[id].pos === pos);
          const jj = j >= 0 ? j : pos === 'GK' ? w[b].findIndex((id) => w.players[id].pos === 'GK') : w[b].findIndex((id) => w.players[id].pos !== 'GK');
          if (jj < 0) {
            // その位置の控えがいない：GKなら新しく入団させる、それ以外は誰でも
            if (pos === 'GK') {
              const q = newcomer(w, YA.rngOf(w.seed * 7 + w.year * 31 + w.week), 1, 'GK');
              const at = w[b].indexOf(q.id);
              if (at >= 0) w[b].splice(at, 1);
              s.pid = q.id;
            } else if (w[b].length) {
              s.pid = w[b][0];
              w[b].splice(0, 1);
            }
            return;
          }
          if (jj >= 0) {
            s.pid = w[b][jj];
            w[b].splice(jj, 1);
          }
        });
      }
    }
  }
  YA.autoTeamsKeep = autoTeamsKeep;
  function newcomer(w, rng, grade, forcePos) {
    const used = new Set(Object.values(w.players).map((p) => p.name));
    // GKが足りなくなったら、途中加入はGK
    const gkCount = Object.values(w.players).filter((q) => q.pos === 'GK').length;
    const pos = forcePos || (gkCount < 3 ? 'GK' : rng.pick(['CB', 'LB', 'RB', 'DM', 'CM', 'CM', 'AM', 'LW', 'RW', 'ST']));
    const id = 'p' + ++w.nextId;
    const p = YA.genPlayer(rng, id, grade || 1, pos, rng.int(-1, 1), used);
    p.team = 'B';
    w.players[id] = p;
    numbers(w);
    w.benchB = (w.benchB || []).concat([id]).slice(0, 12);
    return p;
  }

  // ---------- 試合の結果を名簿に戻す ----------
  YA.applyMatch = function (w, m, which, opp, scheduled) {
    const team = m.home;
    for (const id of Object.keys(team.players)) {
      const p = w.players[id];
      if (!p) continue;
      const mm = p.st ? p.st.minutes : 0;
      p.mins += mm;
      const s15 = team.startSlot && team.startSlot[id];
      if (s15 && mm > 0) {
        p.fam = p.fam || {};
        p.fam[s15] = Math.min(14, (p.fam[s15] || 0) + 1);
      }
      if (which === 'A') p.minsA = (p.minsA || 0) + mm;
      if (mm > 0) {
        // 役割をこなすうちに戦術の理解が伸びる（合っていると早い）
        const li = team.lineup.findIndex((sl) => sl.pid === id);
        const fit = li >= 0 ? YA.Match.prototype.roleFit.call(null, team, li) : 0;
        p.tu = Math.min(100, (p.tu == null ? 40 : p.tu) + (fit >= 0 ? 2 : 0.5));
      }
      p._weekMins = (p._weekMins || 0) + mm;
      if (mm > 0) {
        // 試合の疲れ
        p.fat = clamp(p.fat + (100 - p.stam) * 0.18 + 1, 0, 100);
        // 試合中の上下は、試合のあとに半分ほど元へ戻る（勝てば少し上がる）
        p.conf = clamp(p.conf + (55 - p.conf) * 0.45 + (m.score.home > m.score.away ? 3 : m.score.home < m.score.away ? -2 : 0), 0, 100);
        if (p.st.rating >= 7.6) conf(p, 2);
        if (p.st.rating <= 5.4) conf(p, -2);
        // 大活躍のあとは伸び盛り、大きな失敗のあとは壁（反骨心の子は、失敗を力に変えて伸び盛り）
        if (!(p.state && p.state.w > 0)) {
          const rr = YA.rngOf(w.seed + w.week * 7 + w.year * 3 + p.num)();
          if (p.st.rating >= 8.4 && rr < 0.5) {
            p.state = { k: 'peak', w: 6 };
            noteTier(w, 2, p.num + '番 ' + p.name + ' が大活躍で伸び盛りに入った', p.id);
          } else if (p.st.rating <= 5.0 && rr < 0.5) {
            if (anyP(p, '反骨心')) {
              p.state = { k: 'peak', w: 5 };
              noteTier(w, 2, p.num + '番 ' + p.name + ' は悔しさをバネに、伸び盛りに入った', p.id);
            } else {
              p.state = { k: 'wall', w: 6 };
              noteTier(w, 2, p.num + '番 ' + p.name + ' が壁に当たっている（しばらく伸びにくい）', p.id);
            }
          }
        }
        if (p.pers && m.discontent && m.discontent[id] > 10) p.unrest += 0.7; // 役割が合わない場面が多い試合だけ、少しずつ
      } else if (which === 'A' && p.team === 'A' && p.mins < 400) {
        // 控えにもならなかった子の小さな不満
        if (ST(p, '気持ちの強さ', '負けず嫌い') || ST(p, '目指すもの', '野心家')) p.unrest += 0.1;
      }
      delete p._startStam;
    }
    const gf = m.score.home;
    const ga = m.score.away;
    if (which === 'A' && scheduled) {
      // 同じ戦い方を続けると、チームに浸透する
      const ty = team.tactic.type;
      w.tactMem = w.tactMem && w.tactMem.type === ty ? { type: ty, weeks: w.tactMem.weeks + 1 } : { type: ty, weeks: 1 };
    }
    if (which === 'A') {
      w.results.push({ year: w.year, week: w.week, opp: opp.name, gf, ga, kind: opp.kindLabel || '' });
      if (scheduled && YA.recordMatch) YA.recordMatch(w, m, opp);
      if (gf > ga) w.rec.w++;
      else if (gf === ga) w.rec.d++;
      else w.rec.l++;
      w.rec.gf += gf;
      w.rec.ga += ga;
    }
  };

  // Bチームの試合は、結果だけ自動で回す
  YA.simulateB = function (w) {
    const rng = YA.rngOf(w.seed * 3 + w.year * 400 + w.week);
    const opp = YA.opponentOf(w);
    const o2 = Object.assign({}, opp, { lvl: opp.lvl - 1.3, id: opp.id + 'B' });
    const home = YA.teamFromWorld(w, 'B');
    const away = YA.makeOpponent(o2, w.seed + w.week * 7);
    const m = new YA.Match({ seed: w.seed * 11 + w.year * 100 + w.week, home, away, settings: { autoStop: false } });
    let g = 0;
    while (!m.finished && g++ < 2000) m.step();
    YA.applyMatch(w, m, 'B', o2, false);
    (w.resultsB = w.resultsB || []).push({ year: w.year, week: w.week, opp: o2.name, gf: m.score.home, ga: m.score.away });
    if (w.resultsB.length > 30) w.resultsB.shift();
    return { gf: m.score.home, ga: m.score.away, opp: o2.name };
  };

  // ---------- 週の締め：出来事の反映・暦を進める・年度替わり ----------
  YA.startWeek = function (w) {
    w.planMonth = w.year * 100 + YA.monthIdx(w.week); // この月の練習は組んだことにする（同じ月の残りの週は1タップで進める）
    // 今週の練習を実行して出来事を作る
    w.campMult = 1;
    if (YA.SCHED(w.week).t === 'camp') YA.applyCamp(w);
    YA.weekExtras(w);
    const gains = YA.runTraining(w);
    w.events = YA.rollEvents(w);
    w.phase = 'event';
    w.matchDone = false;
    return gains;
  };
  // 出来事のあと：欠けた先発を埋め、試合のある週は試合へ
  YA.afterEvents = function (w) {
    w.events = [];
    const swaps = [repairLineup(w, 'A'), repairLineup(w, 'B')];
    for (const s of swaps[0]) noteTier(w, 2, s[0].num + '番 ' + s[0].name + ' が出られないため、' + s[1].num + '番 ' + s[1].name + ' がAチームの先発に入った');
    w.phase = YA.hasMatch(w.week, w) ? 'match' : 'after';
  };
  YA.endWeek = function (w) {
    // Bの試合（自動）
    const sch = YA.SCHED(w.week);
    if (sch.t === 'league' || sch.t === 'cup') {
      const b = YA.simulateB(w);
      w.lastB = b;
    }
    YA.resolveOffers(w);
    if (sch.t === 'league' && sch.n === 22) {
      const le = YA.leagueEnd(w);
      if (le) YA.noteTier(w, 1, `リーグ戦が終わりました。最終順位は${le.rank}位` + (le.move < 0 ? '（上位2位。来年は一つ上のリーグへ昇格）' : le.move > 0 ? '（下位2位。来年は一つ下のリーグへ降格）' : '') );
    }
    // 卒業式（年度末）：評価 → 卒業と入学 → 契約・解任
    let grad = null;
    if (w.week >= WEEKS) {
      const le = YA.leagueEnd(w);
      if (w.nextLevel) w.leagueLevel = w.nextLevel;
      const ev = YA.evaluate(w);
      w.coach.exp++;
      w.pendingCoach = true;
      grad = YA.graduate(w);
      grad.eval = ev.rec;
      if (ev.dismissed) {
        const off = YA.moveOffers(w).sort((a, b) => b.tier - a.tier)[0];
        YA.moveTo(w, off, '成績不振で解任されました。');
        grad.dismissed = off;
      } else if (w.club.contract.left <= 0) w.pendingContract = { offers: YA.moveOffers(w) };
    } else w.week++;
    for (const p of Object.values(w.players)) p.rest = p.rest === 'rest' ? null : p.rest === 'light' ? null : null;
    w.phase = 'plan';
    w.matchDone = false;
    return grad;
  };

  // 3月：高3が卒業して名鑑へ。高2→高3、高1→高2。新しい高1が12人入る
  YA.graduate = function (w) {
    const rng = YA.rngOf(w.seed * 71 + w.year * 12345);
    const out = [];
    const grads = [];
    YA.alumniTick(w);
    // その年の卒業生を力の順に並べ、上位からプロ契約（人数は評判で変わる）。突出して高い子は上限を超えてプロへ
    const seniors = Object.values(w.players).filter((q) => q.grade === 3).sort((a, b) => YA.ovr(b) - YA.ovr(a));
    const K = clamp(Math.round(1.5 + (w.club.rep - 30) / 45 + (rng() - 0.5) * 1.6), 1, 4);
    seniors.forEach((q, i) => {
      const o = YA.ovr(q);
      let path = (i < K && o >= 11.5) || o >= 15.5 ? 'pro' : o >= 10.5 ? 'univ' : 'amateur';
      // 進路の相談（決定15）：推す・大学を勧める・他のクラブへ売り込む
      if (q._push === 'top') {
        if ((o >= 11.5 && i < K + 1) || (o >= 11 && rng() < 0.15)) path = 'pro';
        else {
          path = 'univ';
          q._pushFail = true;
        }
      } else if (q._push === 'univ') path = o >= 10 ? 'univ' : path;
      else if (q._push === 'sell') {
        if (o >= 11 && rng() < 0.6) {
          path = 'pro';
          q._sold = true;
        } else if (path === 'pro') path = 'univ';
      }
      q._path = path;
    });
    for (const p of Object.values(w.players)) {
      if (p.grade === 3) {
        const o = Math.round(YA.ovr(p) * 10) / 10;
        const note = p._path === 'pro' ? 'プロ契約（トップ昇格）' : p._path === 'univ' ? (o >= 12 ? '大学（強豪）へ' : '大学へ') : '社会人・就職へ';
        if (p._pushFail) YA.addTrust(w, -2, p.name + 'のトップ昇格の推薦が通らなかった');
        if (p._sold) YA.addRep(w, 1);
        grads.push([p, note]);
        out.push({ name: p.name, pos: p.pos, ovr: o, note });
        delete w.players[p.id];
      } else {
        p.grade++;
        p.tprog = p.tprog || {};
      }
    }
    // 在籍者の年またぎの調整
    for (const p of Object.values(w.players)) {
      p.fat = Math.max(0, p.fat - 30);
      p.inj = Math.max(0, p.inj - 3);
      p.mins = 0;
      p.unrest = 0;
    }
    for (const [p, note] of grads) w.alumni.push(YA.alumniEntry(w, p, note));
    const used = new Set(Object.values(w.players).map((p) => p.name));
    YA.intake(w, rng, used);
    numbers(w);
    w.year++;
    w.week = 1;
    autoTeams(w, false);
    YA.relations(w);
    YA.yearStart(w);
    noteTier(w, 1, w.year - 1 + '年目が終わりました。' + out.length + '人が卒業し、新しい高1の12人が入団しました');
    return { out, entered: 12, contrib: w.club.solidarityLast || 0 };
  };

  // ---------- 面談 ----------
  YA.TALKS = [
    { k: 'praise', label: '褒める', kind: 'warm' },
    { k: 'issue', label: '課題を伝える', kind: 'firm' },
    { k: 'listen', label: '悩みを聞く', kind: 'warm' },
    { k: 'push', label: '背中を押す', kind: 'push' },
  ];
  // 面談は1人につき月に1回（暦の月で数える）
  YA.monthIdx = (week) => Math.min(11, Math.floor(((week - 1) / WEEKS) * 12));
  YA.talkWeek = (w) => w.year * 100 + YA.monthIdx(w.week);
  YA.canTalk = (w, p) => p.talk !== YA.talkWeek(w);
  YA.talk = function (w, pid, k) {
    const p = w.players[pid];
    const t = YA.TALKS.find((x) => x.k === k);
    if (!YA.canTalk(w, p)) return { ok: false, msg: '1人とは月に1回までです' };
    p.talk = YA.talkWeek(w);
    const res = react(p, t.kind);
    if (res.c > 0 && w.coach) res.c = res.c * (1 + (w.coach.talk - 10) * 0.03);
    // 話題によって少し違う
    let extra = '';
    if (k === 'issue' && p.train) {
      // 課題の面談は、重点にする能力を示す（弱い能力を提案）
      const weak = abList(p).filter((n) => p.ab[n] < 12).sort((a, b) => p.ab[a] - p.ab[b])[0];
      if (weak) extra = '弱点：' + weak + '（' + p.ab[weak] + '）';
      if (res.c >= 0 && weak) p.prog[weak] = (p.prog[weak] || 0) + 0.15;
    }
    if (k === 'listen' && p.unrest > 0) p.unrest = Math.max(0, p.unrest - 1);
    if (k === 'praise' && w.talkCount > 14) res.c -= 1;
    w.talkCount = (w.talkCount || 0) + 1;
    const small = apply(p, res);
    // えこひいき：話す相手が偏ると他の子が感じる（面談が多い子が3人を超える）
    p.talks = (p.talks || 0) + 1;
    return { ok: true, line: res.line, small, extra };
  };

  // ---------- 練習の自動設定 ----------
  YA.autoPlan = function (w) {
    // 弱点を自動で重点に。疲れている子は軽めに
    const plan = defaultPlan();
    const fatigued = Object.values(w.players).filter((p) => p.fat > 65).length;
    if (fatigued > 8) plan.days[4] = { menu: '回復', int: 'normal' };
    for (const p of Object.values(w.players)) {
      const weak = abList(p).filter((n) => p.ab[n] < p.ab && 0).length;
      const cand = (p.pos === 'GK' ? YA.AB_GK : YA.POS_ABS15[p.main]).slice().sort((a, b) => p.ab[a] - p.ab[b]);
      p.train.focus = cand[0];
      // 特性練習は、いちばん早く覚えられるものを（おまかせのとき）
      if (!p.train.trait) {
        const lt = YA.learnable(p)[0];
        if (lt && lt.weeks <= 34) p.train.trait = lt.t;
      }
      p.rest = p.fat > 70 ? 'rest' : p.fat > 55 ? 'light' : null;
    }
    w.plan = plan;
    return plan;
  };
  YA.learnable = function (p) {
    const list = (p.pos === 'GK' ? GK_TRAITS : FIELD_TRAITS).filter((t) => p.traits.indexOf(t) < 0 && t in YA.TRAIT_AFF);
    return list.map((t) => {
      const q = YA.TRAIT_AFF[t].reduce((s, n) => s + p.ab[n], 0) / 2;
      const speed = clamp((q / 11) * (q / 11), 0.35, 2.2) * p.rate * 2.6;
      return { t, weeks: Math.ceil(100 / speed), q };
    }).sort((a, b) => a.weeks - b.weeks);
  };

  YA.starsOf = function (p) {
    // 見える伸びしろは★の幅。実際の余地（pot-合計）を段階に直す
    const room = p.pot - abSum(p);
    const s = clamp(Math.round(room / 45), 0, 5);
    return [clamp(s - 1, 0, 5), clamp(s + 1, 0, 5)];
  };

  YA.summaryOf = function (w) {
    const all = Object.values(w.players);
    return {
      injured: all.filter((p) => p.inj > 0),
      tired: all.filter((p) => p.fat > 70 && p.inj <= 0),
      lowconf: all.filter((p) => p.conf < 35),
      hot: all.filter((p) => p.form >= 1 || p.spurt > 0),
    };
  };
  YA.noteTier = noteTier;
  YA._genGrade = genGrade;
  YA._numbers = numbers;
  YA.applyReact = apply;
  YA.clampV = clamp;
  // ビルド3までの保存データ（育成だけ）を、クラブ運営つきの形に移す
  YA.migrate = function (w) {
    if (w.club && w.v >= 2) return w;
    w.v = 2;
    w.coach = w.coach || YA.newCoach();
    w.scouting = w.scouting || YA.newScouting();
    w.disc = 60;
    w.rules = [];
    w.trophies = [];
    w.h2h = {};
    w.rel = [];
    YA.newClub(w, 2, w.clubName);
    YA.relations(w);
    YA.yearStart(w);
    w.yearIntro = false;
    return w;
  };
})();
