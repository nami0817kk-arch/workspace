// 選手を構成する要素 段階3「特性」（2026-11-19 ⑤）
// ・特性 70→100（名前と金は data.js、効き目は data.js の YA.TRAIT_X を engine の traitXMod が足す）。ここは覚えやすさ（関わる能力）
// ・悪い癖（YA.HABITS。入団時に約3割が1つ・まれに2つ。練習で直せる）
// ・特性の組み合わせ（YA.TRAIT_COMBO。engine が足す。ここは見せ方）
// ・金までの見せ方（試合で効いた回数と関わる能力）
// ・特性の出どころ（師匠・先輩・憧れの卒業生。教えてくれる人がいると覚えるのが速い）
// ・覚醒の形 20→40・まれに覚醒の特性が2つ（両方残す）
(function () {
  const YA = globalThis.YA;
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const all = (w) => Object.values(w.players || {});
  const rngP = (p, salt) => YA.rngOf(YA.hash(String(p.id) + '|' + p.name + '|' + salt));

  // ---------- 覚えやすさ（関わる能力2つ） ----------
  Object.assign(YA.TRAIT_AFF, {
    ゴール前の落ち着き: ['冷静さ', 'フィニッシュ'], ニアぶち抜き: ['フィニッシュ', '強さ'], ボレーの名手: ['テクニック', 'フィニッシュ'], カウンターの鬼: ['スピード', 'オフザボール'],
    逆足のフィニッシュ: ['逆足の精度', 'フィニッシュ'], 粘り腰のキープ: ['バランス', '強さ'], ラストパスの精度: ['パス', '視野'], 縦パスの差し込み: ['パス', '判断'], ロングフィード: ['パス', 'テクニック'],
    ターンの速さ: ['敏しょう性', 'ファーストタッチ'], エリア内の駆け引き: ['オフザボール', '判断'], 遅れて入る: ['オフザボール', '予測'], 追い越す動き: ['運動量', 'オフザボール'], 数的不利でも運ぶ: ['ドリブル', '強さ'],
    粘り強い寄せ: ['運動量', 'タックル'], パスコースを読む: ['予測', 'ポジショニング'], 落下点の読み: ['ヘディング', 'ポジショニング'], 縦を切る守備: ['マーク', 'ポジショニング'], 体を張る: ['強さ', '集中'],
    集中の切れない守備: ['集中', 'マーク'], ひとりの防波堤: ['判断', 'ポジショニング'], 逆境に強い: ['冷静さ', '集中'], 先制点に強い: ['冷静さ', 'フィニッシュ'], リードを守る: ['集中', '判断'],
    勢いに乗る: ['冷静さ', '判断'], 疲れ知らず: ['スタミナ', '運動量'],
    シュートへの反応: ['反応', '集中'], '1対1の間合い': ['1対1', '飛び出し'], コーチングの声: ['コーチング', 'エリアの支配'], ハイボールの処理: ['空中戦', 'ハンドリング'],
  });

  // ---------- 覚醒の形 20→40 ----------
  const FIELD = ['CB', 'LB', 'RB', 'LWB', 'RWB', 'DM', 'CM', 'LM', 'RM', 'AM', 'LW', 'RW', 'SS', 'ST'];
  YA.AWAKE_FORMS.push(
    { k: 'regista', name: 'レジスタになる', pos: ['DM'], abs: ['パス', '視野', '冷静さ'], trait: '時を操る配球', as: ['ロングフィード', 'サイドチェンジ', '試合を落ち着かせる', '縦パスの差し込み'] },
    { k: 'poacher', name: 'ゴール前の狐になる', pos: ['ST', 'SS'], abs: ['オフザボール', 'フィニッシュ', '予測'], trait: '一瞬の嗅覚', as: ['こぼれ球への嗅覚', 'エリア内の駆け引き', 'ニアへの飛び込み', 'ダイレクトシュート'] },
    { k: 'libero', name: 'リベロになる', pos: ['CB'], abs: ['パス', '判断', 'ポジショニング'], trait: '攻める最終ライン', as: ['ロングフィード', 'ボールを運ぶ', 'カバーリング', '読みのインターセプト'] },
    { k: 'shadow', name: '影の点取り屋になる', pos: ['AM', 'SS', 'CM'], abs: ['オフザボール', 'フィニッシュ', '予測'], trait: '影の侵入者', as: ['遅れて入る', '3人目の動き', 'ダイレクトシュート', 'こぼれ球への嗅覚'] },
    { k: 'inverted', name: '切れ込むウイングになる', pos: ['LW', 'RW'], abs: ['ドリブル', 'フィニッシュ', '逆足の精度'], trait: '切れ込む刃', as: ['カットイン', '巻いて流し込むシュート', '逆足のフィニッシュ', 'シュートフェイント'] },
    { k: 'anchor', name: '中盤の錨になる', pos: ['DM'], abs: ['ポジショニング', 'タックル', '集中'], trait: '動かない錨', as: ['パスコースを読む', 'カバーリング', '体を張る', '試合を落ち着かせる'] },
    { k: 'shotstop', name: 'シュートストッパーになる', pos: ['GK'], abs: ['反応', '集中', 'ハンドリング'], trait: '鉄のカーテン', as: ['シュートへの反応', '至近距離のセーブ', 'ビッグセーブ', 'ミドルに強いGK'] },
    { k: 'skygk', name: '空を制するGKになる', pos: ['GK'], abs: ['空中戦', 'エリアの支配', '飛び出し'], trait: '天空の守護者', as: ['ハイボールの処理', 'クロスへの強さ', 'パンチング', 'コーチングの声'] },
    { k: 'b2b', name: 'ボックス・トゥ・ボックスになる', pos: ['CM', 'DM'], abs: ['運動量', 'スタミナ', 'フィニッシュ'], trait: '両ゴール前の男', as: ['追い越す動き', '疲れ知らず', '弾丸ミドル', '即時奪回'] },
    { k: 'clutch', name: '勝負強さに目覚める', pos: FIELD, abs: ['冷静さ', '集中', '判断'], trait: '決める者', as: ['先制点に強い', '逆境に強い', '終盤に強い', 'ゴール前の落ち着き'] },
    { k: 'arrow', name: 'カウンターの矢になる', pos: ['ST', 'LW', 'RW', 'SS'], abs: ['スピード', '加速', 'オフザボール'], trait: '放たれた矢', as: ['カウンターの鬼', '裏への抜け出し', '縦への突破', 'ゴール前の落ち着き'] },
    { k: 'stopper', name: 'ストッパーになる', pos: ['CB'], abs: ['強さ', 'タックル', 'ヘディング'], trait: '潰し屋', as: ['体を寄せる', '体を張る', '空中戦の競り', '正確なタックル'] },
    { k: 'invfb', name: '中へ入るサイドバックになる', pos: ['LB', 'RB'], abs: ['パス', '判断', 'ポジショニング'], trait: '中へ入る頭脳', as: ['縦パスの差し込み', 'ワンタッチパス', 'パスコースを読む', '試合を落ち着かせる'] },
    { k: 'carrier', name: '運び屋になる', pos: ['CM', 'DM', 'CB'], abs: ['ドリブル', 'バランス', '強さ'], trait: '止まらない運び屋', as: ['ボールを運ぶ', '粘り腰のキープ', '数的不利でも運ぶ', 'ターンの速さ'] },
    { k: 'widepm', name: 'サイドの司令塔になる', pos: ['LM', 'RM', 'LWB', 'RWB'], abs: ['パス', '視野', 'クロス'], trait: 'サイドの指揮者', as: ['ラストパスの精度', 'アーリークロス', 'グラウンダーのクロス', 'サイドチェンジ'] },
    { k: 'volley', name: 'ボレーの名手になる', pos: ['ST', 'SS', 'AM'], abs: ['テクニック', 'フィニッシュ', 'バランス'], trait: '空中の芸術', as: ['ボレーの名手', 'ダイレクトシュート', '高い打点', 'ゴール前の落ち着き'] },
    { k: 'hound', name: '前線の猟犬になる', pos: ['ST', 'SS', 'LW', 'RW'], abs: ['運動量', 'タックル', 'スタミナ'], trait: '前線の狩人', as: ['前線からの守備', 'ハイプレスの先頭', '即時奪回', '疲れ知らず'] },
    { k: 'killer', name: 'エースキラーになる', pos: ['CB', 'DM', 'LB', 'RB'], abs: ['マーク', '集中', '敏しょう性'], trait: 'エース殺し', as: ['マンマーク', '集中の切れない守備', '縦を切る守備', '粘り強い寄せ'] },
    { k: 'fk', name: 'FKの名手になる', pos: ['CM', 'AM', 'SS', 'LW', 'RW'], abs: ['プレースキック', 'テクニック'], trait: '壁を越える軌道', as: ['直接FK', '無回転FK', '低く速いCK', '曲がるCK'] },
    { k: 'pillar', name: 'チームの柱になる', pos: FIELD.concat(['GK']), abs: ['チームワーク', '判断', '冷静さ'], trait: '背中で語る', as: ['声で味方を動かす', '試合を落ち着かせる', 'リードを守る', '逆境に強い'] },
  );
  YA.DEX_REWARD[30] = 1500;
  YA.DEX_REWARD[40] = 2000;
  YA.AWAKE_DOUBLE = 0.08; // 覚醒のとき、まれに形が2つ同時に（特性が2つ）

  // ---------- 悪い癖 ----------
  YA.HABIT_P = 0.3; // 入団時に癖を1つ持つ割合（まれに2つ）
  YA.habitInit = function (p) {
    if (p.hb) return p;
    const r = rngP(p, 'habit');
    const isGK = p.pos === 'GK';
    const pool = Object.keys(YA.HABITS).filter((k) => !!YA.HABITS[k].gk === isGK);
    const n = r() < YA.HABIT_P ? (r() < 0.15 ? 2 : 1) : 0;
    p.habits = [];
    for (let i = 0; i < n; i++) {
      // 関わる能力の低い子ほど持ちやすい
      const h = r.weighted(pool.filter((k) => p.habits.indexOf(k) < 0), (k) => Math.pow(clamp(22 - ((p.ab && p.ab[YA.HABITS[k].ab]) || 10), 2, 20), 2));
      if (h) p.habits.push(h);
    }
    p.hbProg = {};
    p.hb = 1;
    return p;
  };
  // 直す練習：選ぶと特性の練習の代わりに週ごとに進む（プロ意識・本人の関わる能力で速さが変わる）
  YA.habitWeeks = function (p, k) {
    const x = YA.HABITS[k];
    const ab = (p.ab && p.ab[x.ab]) || 10;
    const pro = p.hid ? p.hid['プロ意識'] || 10 : 10;
    return Math.round(clamp(20 - ab * 0.5 - pro * 0.3, 6, 18));
  };
  YA.setHabitFix = function (w, p, k) {
    if (k && (p.habits || []).indexOf(k) < 0) return { ok: false, msg: 'その癖はありません' };
    p.train.habit = k || null;
    if (k) p.train.trait = null;
    return { ok: true, msg: k ? `${p.name}の「${k}」を直す練習を始めました（約${YA.habitWeeks(p, k)}週）` : '癖を直す練習をやめました' };
  };

  // ---------- 生まれ・古い保存 ----------
  YA.ensureTraits2 = function (w) { for (const p of all(w)) { if (!p.hb) YA.habitInit(p); } };
  const gp0 = YA.genPlayer;
  YA.genPlayer = function () { return YA.habitInit(gp0.apply(this, arguments)); };
  const nw0 = YA.newWorld;
  YA.newWorld = function () { const w = nw0.apply(this, arguments); YA.ensureTraits2(w); return w; };

  // ---------- 出どころ（師匠・先輩・憧れの卒業生） ----------
  YA.traitTeacher = function (w, p, t) {
    const mentor = (w.rel || []).find((x) => (x.k === 'mentor' || x.k === 'gk') && x.b === p.id);
    const m = mentor && w.players[mentor.a];
    if (m && (m.traits || []).indexOf(t) >= 0) return { k: 'mentor', name: m.name, t: `師匠の${m.name}から` };
    const sen = all(w).filter((q) => q.id !== p.id && q.grade > p.grade && (q.traits || []).indexOf(t) >= 0).sort((a, b) => b.grade - a.grade)[0];
    if (sen) return { k: 'senior', name: sen.name, t: `先輩の${sen.name}を見て` };
    const idol = (w.alumni || []).filter((a) => a.status === 'pro' && !a.retired && (a.traits || []).indexOf(t) >= 0).sort((a, b) => (b.ovr || 0) - (a.ovr || 0))[0];
    if (idol) return { k: 'idol', name: idol.name, t: `憧れの${idol.name}（${idol.club || 'プロ'}）をまねて` };
    return null;
  };
  YA.TEACH_K = { mentor: 1.35, senior: 1.2, idol: 1.1 };

  // ---------- 毎週：練習のあと（覚える速さ・出どころ・癖を直す） ----------
  const rt0 = YA.runTraining;
  YA.runTraining = function (w) {
    YA.ensureTraits2(w);
    const before = {};
    for (const p of all(w)) before[p.id] = { tr: p.traits.slice(), tp: p.train.trait ? p.tprog[p.train.trait] || 0 : null, t: p.train.trait };
    const res = rt0.apply(this, arguments);
    for (const p of all(w)) {
      const b = before[p.id];
      if (!b) continue;
      // 教えてくれる人がいると速い
      if (b.t && p.train.trait === b.t && b.tp != null) {
        const te = YA.traitTeacher(w, p, b.t);
        const d = (p.tprog[b.t] || 0) - b.tp;
        if (te && d > 0) p.tprog[b.t] = Math.min(99.9, (p.tprog[b.t] || 0) + d * (YA.TEACH_K[te.k] - 1));
      }
      // 新しく覚えた特性の出どころ
      for (const t of p.traits) if (b.tr.indexOf(t) < 0) {
        const te = YA.traitTeacher(w, p, t);
        p.trFrom = p.trFrom || {};
        p.trFrom[t] = te ? te.t : '自分で';
        if (te && te.k !== 'idol' && YA.noteTier) YA.noteTier(w, 3, `${p.name}が「${t}」を身につけた（${te.t}）`, p.id);
      }
      // 癖を直す練習
      const hk = p.train.habit;
      if (hk && (p.habits || []).indexOf(hk) >= 0 && !(p.inj > 0)) {
        p.hbProg = p.hbProg || {};
        p.hbProg[hk] = (p.hbProg[hk] || 0) + 100 / YA.habitWeeks(p, hk);
        if (p.hbProg[hk] >= 100) {
          p.habits = p.habits.filter((x) => x !== hk);
          delete p.hbProg[hk];
          p.train.habit = null;
          if (p.hist) p.hist.unshift({ y: w.year, w: w.week, t: `癖「${hk}」が直った` });
          if (YA.noteTier) YA.noteTier(w, 2, `${p.num}番 ${p.name}の癖「${hk}」が直った`, p.id);
        }
      } else if (hk) p.train.habit = null;
    }
    return res;
  };
  // おまかせ：癖のある子は、特性の練習をしていなければ直す練習へ
  const ap0 = YA.autoPlan;
  YA.autoPlan = function (w) {
    const r = ap0.apply(this, arguments);
    for (const p of all(w)) if ((p.habits || []).length && !p.train.trait && !p.train.habit && !p.star) p.train.habit = p.habits[0];
    return r;
  };

  // ---------- 覚醒：まれに2つ・2回目の覚醒でも前の特性を残す ----------
  const aw0 = YA.awaken;
  YA.awaken = function (w, p, r) {
    const prev = p.aw ? Object.assign({}, p.aw) : null;
    const res = aw0.apply(this, arguments);
    const rr = YA.rngOf((w.seed | 0) * 7 + w.year * 31 + w.week + YA.hash(p.id + 'aw2'));
    if (prev && prev.k !== p.aw.k) p.aw2 = prev; // 2回目の覚醒：前の特性も残す（新しいほうが p.aw）
    else if (!p.aw2 && rr() < YA.AWAKE_DOUBLE) {
      const done = (p.awHist || []).map((x) => x.k);
      const pos = p.best || p.main;
      const c = YA.AWAKE_FORMS.filter((f) => (f.pos.includes(pos) || f.pos.includes(p.main)) && done.indexOf(f.k) < 0);
      if (c.length) {
        const f = rr.weighted(c, (f) => Math.pow(f.abs.reduce((s, a) => s + (p.ab[a] || 6), 0) / f.abs.length, 2));
        p.aw2 = { k: f.k, form: f.name, trait: f.trait, as: f.as.slice(), double: true };
        p.awHist = (p.awHist || []).concat([{ k: f.k, y: w.year, w: w.week, double: true }]);
        if (p.awake) p.awake.double = f.trait;
        YA.dexAdd(w, p, f);
        if (p.hist) p.hist.unshift({ y: w.year, w: w.week, t: `覚醒の特性が2つ：「${p.aw.trait}」と「${f.trait}」` });
        if (YA.noteTier) YA.noteTier(w, 1, `${p.name}に、覚醒の特性がもう一つ目覚めた：「${f.trait}」（${f.name}）`, p.id);
      }
    }
    return res;
  };

  // ---------- 卒業生に残す ----------
  const ae0 = YA.alumniEntry;
  YA.alumniEntry = function (w, p) {
    const a = ae0.apply(this, arguments);
    if (p.aw2) a.aw2 = p.aw2.trait;
    if (p.habits && p.habits.length) a.habits = p.habits.slice();
    return a;
  };

  // ---------- 見せ方 ----------
  // 金までの道のり（試合で効いた回数・関わる能力）
  YA.goldProgress = function (p, t) {
    if (!YA.GOLD[t] || (YA.isGold && YA.isGold(p, t))) return null;
    const used = (p.trUse && p.trUse[t]) || 0;
    const aff = YA.TRAIT_AFF[t] || [];
    const ab = aff.length ? aff.reduce((s, n) => s + ((p.ab && p.ab[n]) || 0), 0) / aff.length : 0;
    return { used: Math.min(used, YA.GOLD_USES), need: YA.GOLD_USES, ab: Math.round(ab * 10) / 10, abNeed: YA.GOLD_AB, name: YA.GOLD[t] };
  };
  YA.comboOf = (p) => (YA.TRAIT_COMBO || []).filter(([a, b]) => {
    const hasT = (t) => (p.traits || []).indexOf(t) >= 0 || (p.aw && p.aw.as && p.aw.as.indexOf(t) >= 0) || (p.aw2 && p.aw2.as && p.aw2.as.indexOf(t) >= 0);
    return hasT(a) && hasT(b);
  });
  const ov0 = YA.playerOverview;
  if (ov0) {
    YA.playerOverview = function (w, p) {
      YA.ensureTraits2(w);
      const el = ov0.apply(this, arguments);
      try {
        const doc = el.ownerDocument;
        const sec = Array.from(el.querySelectorAll('.ovsec')).find((s) => s.querySelector('.ovh') && s.querySelector('.ovh').textContent === '特性');
        if (!sec) return el;
        const chips = sec.querySelector('.ovchips');
        if (p.aw2 && chips) { const s = doc.createElement('span'); s.className = 'chip awk'; s.textContent = '覚醒 ' + p.aw2.trait; chips.prepend(s); }
        // 特性ごとの金までと出どころ（チップの title と、下の小さな行）
        const lines = [];
        for (const t of p.traits || []) {
          const g = YA.goldProgress(p, t);
          const from = p.trFrom && p.trFrom[t];
          const bits = [];
          if (g) bits.push(`金「${g.name}」まで 試合${g.used}/${g.need}回・能力${g.ab}/${g.abNeed}`);
          if (from && from !== '自分で') bits.push(from + '覚えた');
          if (bits.length) lines.push(`${t}：${bits.join('・')}`);
        }
        for (const [a, b, name] of YA.comboOf(p)) lines.push(`組み合わせ「${name}」（${a}＋${b}）`);
        for (const hb of p.habits || []) lines.push(`癖「${hb}」${p.train.habit === hb ? `（直す練習中 ${Math.round((p.hbProg && p.hbProg[hb]) || 0)}%）` : ''}`);
        if (lines.length) {
          const d = doc.createElement('div');
          d.className = 'ovinfo trx';
          d.style.cssText = 'display:flex;flex-direction:column;gap:1px;font-size:11px;line-height:1.4;margin-top:3px';
          for (const t of lines) { const x = doc.createElement('div'); x.textContent = t; if (/^癖/.test(t)) x.style.color = '#8a2a20'; d.append(x); }
          sec.append(d);
        }
        if (chips) for (const hb of p.habits || []) { const s = doc.createElement('span'); s.className = 'chip habit'; s.textContent = '癖 ' + hb; chips.append(s); }
      } catch (e) { /* 形の違う画面 */ }
      return el;
    };
  }
  // 育て方の画面：癖を直す練習
  const px0 = YA.playerExtras;
  YA.playerExtras = function (w, sel) {
    const base = px0 ? px0.apply(this, arguments) : null;
    if (!sel || !(sel.habits || []).length || typeof document === 'undefined') return base;
    const box = document.createElement('div');
    if (base) box.append(base);
    const card = document.createElement('div');
    card.className = 'card habitcard';
    card.setAttribute('data-grp', 'grow');
    card.style.cssText = 'padding:6px 9px;margin:4px 0;background:#fff6f4';
    const hd = document.createElement('div');
    hd.className = 'h';
    hd.textContent = '悪い癖を直す';
    card.append(hd);
    for (const k of sel.habits) {
      const row = document.createElement('div');
      row.className = 'row';
      row.style.cssText = 'gap:6px;margin-top:3px';
      const t = document.createElement('span');
      t.className = 'grow';
      t.style.fontSize = '12px';
      const on = sel.train.habit === k;
      t.textContent = `${k}：${YA.HABITS[k].t.replace(/た$/, 'ことがある')}（約${YA.habitWeeks(sel, k)}週で直る${on ? `・いま${Math.round((sel.hbProg && sel.hbProg[k]) || 0)}%` : ''}）`;
      const b = document.createElement('button');
      b.className = 'btn sm' + (on ? ' on' : '');
      b.textContent = on ? '直す練習をやめる' : '直す練習をする';
      b.onclick = () => { const r = YA.setHabitFix(w, sel, on ? null : k); if (YA.toast) YA.toast(r.msg); if (YA.saveWorld) YA.saveWorld(); if (YA._ui && YA._ui.render) YA._ui.render(); };
      row.append(t, b);
      card.append(row);
    }
    const n = document.createElement('div');
    n.className = 'note';
    n.textContent = '直す練習をしているあいだは、特性の練習はできません。';
    card.append(n);
    box.append(card);
    return box;
  };
})();
