// スカウト・セレクション・内部昇格（U-15）・入団、卒業生の追跡と連帯貢献金、
// 指導者の成長、キャプテン、ポジション変更、選手同士の関係。
(function () {
  'use strict';
  const YA = (globalThis.YA = globalThis.YA || {});
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

  // ---------- 指導者の成長（決定16）----------
  YA.COACH_ABS = [['teach', '教える力', '練習での伸びが大きくなる'], ['eye', '見る目', '候補の中身とポジションの適性が見えやすくなる'], ['talk', '話す力', '面談や声かけへの反応が良くなる'], ['tactic', '戦術', '試合でチームがまとまりやすくなる']];
  YA.newCoach = () => ({ teach: 8, eye: 8, talk: 8, tactic: 8, exp: 0 });
  YA.licenseOf = (w) => ['C', 'B', 'A', 'S'][Math.min(3, Math.floor((w.coach.exp || 0) / 3))] + '級';
  YA.coachMult = (w) => 1 + ((w.coach ? w.coach.teach : 8) - 10) * 0.012;

  // ---------- スカウト ----------
  const POS_ABS = { GK: YA.AB_GK, DF: ['タックル', 'マーク', 'ポジショニング', '予測', 'ヘディング', '強さ'], MF: ['パス', '視野', '判断', 'ドリブル', '運動量', 'テクニック'], FW: ['フィニッシュ', 'ドリブル', 'スピード', 'オフザボール', '加速', 'ヘディング'] };
  YA.ovrAt = (p, pos) => YA.POS_ABS15[pos].reduce((s, n) => s + p.ab[n], 0) / YA.POS_ABS15[pos].length;
  YA.newScouting = () => ({ cands: [], tests: [], testsDone: false, selOpen: false, intOpen: false, nextId: 0, acts: { m: -1, n: 0 }, seq: 0 });
  const eyeOf = (w) => clamp((YA.staffAb(w, 'スカウト') + (w.coach ? w.coach.eye : 8)) / 2, 3, 18);
  YA.eyeLevel = eyeOf;
  const KIND_NAME = { scout: 'スカウト', sel: 'セレクション', int: '内部昇格（U-15）' };
  YA.CAND_KIND = KIND_NAME;

  // ---------- 暦：いつ何を決めるか ----------
  // 内部昇格は11月（25〜27週）／スカウトは4〜11月に月3回まで、返事は12月（28週）／セレクションは1月（31〜34週）に合否が決まる。
  // 初年度も同じ暦で、決めた子は翌年の高1になる
  YA.SCOUT_RESULT_WEEK = 28;
  YA.SCOUT_PER_MONTH = 3;
  YA.INT_CANDS = 20; // 内部昇格の候補（中3）。8人まで決める
  YA.scoutWindow = function (w) {
    const wk = w.week;
    // scout＝声をかけられる（4〜11月）、explore＝スカウトに出られる（返事の届く28週を除く一年中。12月以降に会えた子は来年度の候補）
    return { int: wk >= 25 && wk <= 27, scout: wk <= 27, explore: wk !== YA.SCOUT_RESULT_WEEK, sel: wk >= 31 && wk <= 34 };
  };
  YA.scoutActsLeft = function (w) {
    const a = w.scouting && w.scouting.acts;
    const used = a && a.m === YA.monthIdx(w.week) ? a.n : 0;
    return Math.max(0, YA.SCOUT_PER_MONTH + (w.scoutPlus || 0) - used);
  };
  const useAct = function (w) {
    const S = w.scouting;
    const m = YA.monthIdx(w.week);
    if (!S.acts || S.acts.m !== m) S.acts = { m, n: 0 };
    S.acts.n++;
  };
  // ホームに出す一言（なければ null）
  YA.scoutHint = function (w) {
    if (!w.scouting) return null;
    const wn = YA.scoutWindow(w);
    if (wn.int) return '内部昇格を決める（11月）';
    if (wn.sel) return 'セレクションの合否を決める（1月）';
    if (wn.explore) return YA.scoutActsLeft(w) > 0 ? `スカウトに出る（${wn.scout ? '' : '来年度の下見・'}今月あと${YA.scoutActsLeft(w)}回）` : 'スカウトの報告を見る（今月は出終わり）';
    return null;
  };

  // スカウトの行き先（栄冠ナイン風：行き先を選んで出る。月3回まで）
  YA.DESTS = {
    local: { name: '地元の中学・クラブ', cost: 5, note: '近くを回る。人数は多めでライバルは少ない', q: -0.3, rival: 0.15, foreign: 0.02 },
    strong: { name: '強豪の中学・ユース', cost: 12, note: '粒ぞろいの子に会える。ほかのクラブも狙っている', q: 0.8, rival: 0.65, foreign: 0.04 },
    wide: { name: '全国・海外へ遠征', cost: 20, note: '当たり外れが大きい。外国籍の子に会えることも', q: 0.1, rival: 0.35, foreign: 0.25 },
  };
  const DEST_ORDER = ['local', 'strong', 'wide'];
  YA.DEST_ORDER = DEST_ORDER;

  function genCand(w, rng, kind, dest) {
    const S = w.scouting;
    const D = dest ? YA.DESTS[dest] : null;
    const pos = rng.pick(['GK', 'CB', 'CB', 'LB', 'RB', 'DM', 'CM', 'CM', 'AM', 'LM', 'RM', 'LW', 'RW', 'SS', 'ST', 'ST']);
    const used = new Set(Object.values(w.players).map((p) => p.name));
    // セレクションの応募者は、取りこぼされた子が来る：原石（今は低いが伸びしろが大きい）・低め（今も伸びしろも低い）・位置ちがい（登録が合っていない）
    const prof = kind === 'sel' ? (() => { const x = rng(); return x < 0.4 ? 'raw' : x < 0.7 ? 'low' : 'mis'; })() : null;
    let q = clamp(rng.int(-2, 2) * (dest === 'wide' ? 1.1 : 0.8) + (kind === 'scout' ? (eyeOf(w) - 10) * 0.08 + (D ? D.q : 0) : 0) + (kind === 'int' ? 0.2 : 0), -2, 2.4);
    if (prof === 'raw') q = -2 + rng() * 0.5;
    else if (prof === 'low') q = -1.8 + rng() * 0.8;
    else if (prof === 'mis') q = -0.8 + rng() * 1.2;
    const id = 'c' + ++S.nextId + '_' + w.year;
    const gpos = prof === 'mis' && pos === 'GK' ? 'CM' : pos;
    const p = YA.genPlayer(rng, id, 1, gpos, q, used);
    p.grade = 0;
    if (prof === 'raw') p.pot = YA.abSum(p) + rng.int(150, 220);
    else if (prof === 'low') p.pot = YA.abSum(p) + rng.int(20, 55);
    else if (prof === 'mis') {
      // 実力は十分だが、登録は別の括りのポジション
      const far = YA.POS15.filter((x) => x !== 'GK' && YA.GROUP[x] !== p.pos && p.apt[x] <= p.apt[p.best] - 1).sort((x, y) => p.apt[x] - p.apt[y]);
      if (far.length) {
        p.main = far[rng.int(0, Math.min(2, far.length - 1))];
        p.pos = YA.GROUP[p.main];
      }
    }
    // 外国籍の選手は年に0〜1人（決定53）。海外のスカウトか、まれな応募から
    const FOREIGN = [['ブラジル', ['ルーカス・シウバ', 'カルロス・メンドンサ', 'ガブリエル・ソウザ']], ['韓国', ['キム・ジュノ', 'パク・ソンミン', 'イ・ヒョヌ']], ['ナイジェリア', ['エマニュエル・オコロ', 'ダニエル・アデバヨ']], ['アルゼンチン', ['マテオ・ゴンザレス', 'ニコラス・ペレス']], ['オーストラリア', ['ジャック・ウィルソン', 'ライアン・テイラー']]];
    let foreign = false;
    if (kind !== 'int' && !S.foreignDone && rng() < (kind === 'scout' && D ? D.foreign : 0.07)) {
      const f = rng.pick(FOREIGN);
      p.nation = f[0];
      p.name = rng.pick(f[1]);
      p.ab['スピード'] = clamp(p.ab['スピード'] + 2, 1, 20);
      p.ab['強さ'] = clamp(p.ab['強さ'] + 1, 1, 20);
      p.pot += 15;
      p.fam = p.fam || {};
      foreign = true;
      S.foreignDone = true;
    } else p.nation = '日本';
    const c = { id, p, kind, prof, foreign, seen: kind === 'int' ? 2 : kind === 'scout' ? 1 : 0, status: 'open', rival: kind === 'scout' && rng.chance(D ? D.rival : 0.4), persSeen: kind === 'int', amb: rng.int(0, 10), where: D ? D.name : null };
    S.cands.push(c);
    return c;
  }
  YA._genCand = genCand;
  // スカウトに出る：行き先を選ぶと、数人の候補に出会える。月3回まで・4〜11月・経費がかかる
  YA.scoutOut = function (w, dest) {
    const S = w.scouting;
    const D = YA.DESTS[dest];
    if (!D) return { ok: false, msg: '行き先を選んでください' };
    const wn = YA.scoutWindow(w);
    if (!wn.explore) return { ok: false, msg: '返事が届く週は、スカウトに出られません' };
    if (YA.scoutActsLeft(w) <= 0) return { ok: false, msg: `今月のスカウトは${YA.SCOUT_PER_MONTH}回使いました。来月また出られます` };
    const room = 12 - S.cands.filter((c) => c.kind === 'scout' && c.status === 'open').length;
    if (room <= 0) return { ok: false, msg: '候補がいっぱいです。見送る子を決めてください' };
    if (YA.budget(w).scout - w.club.spent.scout < D.cost) return { ok: false, msg: 'スカウトの配分が足りません' };
    const r = YA.rngOf(w.seed * 29 + w.year * 131 + w.week * 7 + ++S.seq * 977 + YA.hash(dest));
    const eye = eyeOf(w);
    let n = dest === 'local' ? 1 + (r() < 0.5 ? 1 : 0) : dest === 'wide' ? 1 + (r() < 0.4 ? 1 : 0) : 1;
    if (r() < (eye - 8) * 0.05) n++;
    n = Math.min(n, 3, room);
    const found = [];
    for (let i = 0; i < n; i++) {
      const c = genCand(w, r, 'scout', dest);
      if (!wn.scout) c.next = true; // 12月以降に会えた子：来年度の候補（声をかけられるのは4月から）
      found.push(c);
    }
    w.club.spent.scout += D.cost;
    useAct(w);
    return { ok: true, msg: `${D.name}で${n}人の候補に会いました。` + (wn.scout ? '名前は「スカウトの報告」に並んでいます' : '来年度の候補として残り、4月から声をかけられます'), found };
  };
  // 見送る：候補の一覧から外して、枠を空ける
  YA.passCand = function (w, id) {
    const c = w.scouting.cands.find((x) => x.id === id);
    if (!c || c.kind !== 'scout' || c.status !== 'open') return { ok: false, msg: '見送れません' };
    c.status = 'passed';
    return { ok: true, msg: `${c.p.name}は見送りました` };
  };
  YA.openSelection = function (w) {
    const S = w.scouting;
    if (S.selOpen) return;
    S.selOpen = true;
    const r = YA.rngOf(w.seed * 37 + w.year * 17);
    const n = 14 + Math.floor(w.club.rep / 8);
    for (let i = 0; i < n; i++) genCand(w, r, 'sel');
    YA.noteTier(w, 1, `セレクションの応募が${n}人ありました。1月のうちに、テストの内容を決めて入れる子を選んでください（クラブ→スカウト）`);
  };
  // 中3の練習参加（11月の初め・25週）：内部昇格の候補20人がA・Bの練習に混ざる。実際に動きを見られるので見えている度合いが上がる。26週に指導者の申し送りで残りが見える
  YA.openInternal = function (w, junior) {
    const S = w.scouting;
    if (S.intOpen) {
      if (!junior) {
        for (const c of S.cands) if (c.kind === 'int') {
          c.seen = Math.min(3, c.seen + 1);
          c.persSeen = true;
        }
        YA.noteTier(w, 2, 'U-15の指導者から、各候補の申し送り（性格など）が届きました。内部昇格を決めるのは11月のうちです');
      }
      return;
    }
    S.intOpen = true;
    const r = YA.rngOf(w.seed * 41 + w.year * 19);
    for (let i = 0; i < YA.INT_CANDS; i++) genCand(w, r, 'int');
    if (junior) {
      for (const c of S.cands) if (c.kind === 'int') c.seen = Math.min(3, c.seen + 1);
      YA.noteTier(w, 1, '11月です。中3の20人が練習に参加しました。内部昇格の候補として動きを見られます。8人まで決められます（クラブ→スカウト）');
    } else YA.noteTier(w, 1, 'U-15の指導者から、内部昇格の候補20人の申し送りが届きました（クラブ→スカウト）');
  };
  // 11月の終わり：内部昇格が決まる。12月の初め：スカウトの返事。1月の終わり：セレクションの合否が決まる
  YA.closeInternal = function (w) {
    if (!w.scouting.intOpen) return;
    YA.noteTier(w, 1, `内部昇格が決まりました（${YA.signedCount(w, 'int')}人）。来年の高1になります`);
  };
  YA.closeSelection = function (w) {
    if (!w.scouting.selOpen) return;
    YA.noteTier(w, 1, `セレクションの合否が決まりました（${YA.signedCount(w, 'sel')}人合格）。来年の高1になります`);
  };
  YA.testDays = (w) => 2 + (YA.budget(w).scout >= 300 ? 1 : 0);
  YA.TESTS = [['紅白戦', '動きと判断が見える'], ['技術テスト', 'ボールの扱いが見える'], ['体力測定', '足の速さ・体力が見える'], ['面接', '性格と目指すものが見える']];
  YA.runSelection = function (w, tests) {
    const S = w.scouting;
    if (S.testsDone) return;
    S.tests = tests.slice(0, YA.testDays(w));
    for (const c of S.cands) if (c.kind === 'sel') {
      c.seen = Math.min(3, c.seen + (S.tests.length >= 3 ? 2 : 1));
      if (S.tests.indexOf('面接') >= 0) c.persSeen = true;
    }
    S.testsDone = true;
    YA.noteTier(w, 2, `セレクションを実施しました（${S.tests.join('・')}）`);
  };
  YA.scoutVisit = function (w, id) {
    const c = w.scouting.cands.find((x) => x.id === id);
    const b = YA.budget(w);
    if (!c || c.kind !== 'scout' || c.status !== 'open') return { ok: false, msg: '見に行けません' };
    if (!YA.scoutWindow(w).explore) return { ok: false, msg: '返事が届く週は、見に行けません' };
    if (YA.scoutActsLeft(w) <= 0) return { ok: false, msg: `今月のスカウトは${YA.SCOUT_PER_MONTH}回使いました。来月また出られます` };
    if (c.seen >= 3) return { ok: false, msg: 'これ以上は見えません' };
    if (b.scout - w.club.spent.scout < 10) return { ok: false, msg: 'スカウトの配分が足りません' };
    w.club.spent.scout += 10;
    useAct(w);
    c.seen++;
    if (c.seen >= 2) c.persSeen = true;
    return { ok: true, msg: `${c.p.name}を見に行きました（見える範囲が広がった）` };
  };
  const LIMIT = { scout: 3, sel: 3, int: 8 };
  // 決められる期間（内部昇格は11月・スカウトの声かけは4〜11月・セレクションは1月）
  const WHEN = { int: ['int', '内部昇格を決めるのは11月です'], scout: ['scout', 'スカウトの声かけは4月〜11月です（返事は12月）'], sel: ['sel', 'セレクションの合否を決めるのは1月です'] };
  const inWindow = (w, kind) => YA.scoutWindow(w)[WHEN[kind][0]];
  const held = (w, kind) => w.scouting.cands.filter((c) => (c.status === 'signed' || c.status === 'offered') && (!kind || c.kind === kind)).length;
  YA.signedCount = (w, kind) => w.scouting.cands.filter((c) => c.status === 'signed' && (!kind || c.kind === kind)).length;
  YA.signCand = function (w, id) {
    const S = w.scouting;
    const c = S.cands.find((x) => x.id === id);
    if (!c || c.status !== 'open') return { ok: false, msg: 'すでに決まっています' };
    if (!inWindow(w, c.kind)) return { ok: false, msg: WHEN[c.kind][1] };
    if (c.next) return { ok: false, msg: `${c.p.name}は来年度の候補です。声をかけられるのは4月からです` };
    if (held(w) >= 12) return { ok: false, msg: '新入生の枠（12人）がいっぱいです' };
    if (c.foreign) {
      const reg = Object.values(w.players).filter((q) => YA.isForeign(q)).length + S.cands.filter((x) => x.foreign && (x.status === 'signed' || x.status === 'offered')).length;
      if (reg >= 5) return { ok: false, msg: '外国籍の選手の登録は5人までです' };
    }
    const lim = LIMIT[c.kind];
    if (held(w, c.kind) >= lim) return { ok: false, msg: `${KIND_NAME[c.kind]}からは${lim}人までです` };
    if (c.kind === 'scout') {
      c.status = 'offered';
      return { ok: true, msg: `${c.p.name}に声をかけました。返事は12月に届きます` };
    }
    c.status = 'signed';
    return { ok: true, msg: `${c.p.name}の入団が決まりました` };
  };
  YA.unsign = function (w, id) {
    const c = w.scouting.cands.find((x) => x.id === id);
    if (c && (c.status === 'signed' || c.status === 'offered') && inWindow(w, c.kind)) c.status = 'open';
  };
  // 声をかけた子の返事（12月の初め・28週）
  YA.resolveOffers = function (w) {
    const r = YA.rngOf(w.seed * 43 + w.year * 23 + w.week);
    for (const c of w.scouting.cands) if (c.status === 'offered') {
      const pr = clamp(0.5 + (w.club.rep - 50) / 120 - (c.rival && !c.rivalBeat ? 0.18 : 0) + (c.rivalBeat ? 0.06 : 0) - (c.amb - 5) * 0.015, 0.12, 0.92);
      if (r() < pr) {
        if (c.rival) w.rivalLosses = (w.rivalLosses || 0) + 1;
        c.status = 'signed';
        YA.noteTier(w, 1, `${c.p.name}（${c.p.pos}）が入団を決めました！`);
      } else {
        c.status = 'declined';
        if (c.rival) w.rivalWins = (w.rivalWins || 0) + 1;
        YA.noteTier(w, 2, `${c.p.name}は${c.rival ? YA.rivalOf(w).coach + '監督の' + YA.rivalOf(w).club : '別の道'}を選びました`);
      }
    }
  };
  const RANK_BASE = 5;
  const RANK_SPAN = 8;
  // 見える情報（見る目と回数で幅が決まる）
  YA.candView = function (w, c) {
    const p = c.p;
    const eye = eyeOf(w);
    const width = Math.max(0.6, 5.2 - c.seen * 1.4 - (eye - 8) * 0.18);
    let hs = 0;
    for (const ch of c.id) hs = (hs * 31 + ch.charCodeAt(0)) % 997;
    const sh = ((hs % 100) / 100 - 0.5) * width * 0.8;
    const o = YA.ovr(p);
    const lo = o - width / 2 + sh;
    const st = YA.potStars(p);
    const sw = c.seen >= 3 ? 0 : c.seen >= 1 ? 1 : 2;
    // 栄冠ナイン風のランク（見えている範囲の真ん中から。S〜E）。見る回数が増えるほど確かになる
    const score = ((lo + width / 2) - RANK_BASE) / RANK_SPAN * 0.5 + (clamp(st - sw, 0, 5) + clamp(st + sw, 0, 5)) / 2 / 5 * 0.5;
    const rank = score >= 0.78 ? 'S' : score >= 0.64 ? 'A' : score >= 0.5 ? 'B' : score >= 0.36 ? 'C' : score >= 0.22 ? 'D' : 'E';
    return { rank, ovr: [Math.round(lo * 10) / 10, Math.round((lo + width) * 10) / 10], stars: [clamp(st - sw, 0, 5), clamp(st + sw, 0, 5)], traits: c.seen >= 1 ? p.traits : null, pers: c.persSeen ? p.pers : null, height: p.height, pos: p.pos, label: YA.POS_LABEL[p.main], name: p.name, kind: c.kind, nation: p.nation && p.nation !== '日本' ? p.nation : null };
  };

  // 入団（3月）：決まった子を学年1の選手にする。足りない分は一般入団で埋める
  YA.intake = function (w, rng, used) {
    const S = w.scouting || YA.newScouting();
    const signed = S.cands.filter((c) => c.status === 'signed').slice(0, 12);
    const names = new Set(used);
    let n = 0;
    const FN = (YA.IMG && YA.IMG.faces.length) || 1;
    const faces = new Set(Object.values(w.players).map((q) => q.face).filter((f) => f != null).map((f) => f % FN));
    for (const c of signed) {
      const p = c.p;
      // 候補のときの顔が、在籍の子と重なっていたら選び直す
      if (p.face != null && faces.has(p.face % FN)) p.face = null;
      if (p.face != null) faces.add(p.face % FN);
      p.grade = 1;
      p.id = 'p' + ++w.nextId;
      p.team = 'B';
      p.num = 0;
      p.hist = [{ y: w.year, w: 40, t: KIND_NAME[c.kind] + 'で入団' }];
      w.players[p.id] = p;
      names.add(p.name);
      n++;
    }
    // 一般入団（見ていない子）。ポジションが偏らないよう足りない所を補う
    const have = { GK: 0, DF: 0, MF: 0, FW: 0 };
    for (const p of Object.values(w.players)) if (p.grade === 1) have[p.pos]++;
    const want = { GK: 1, DF: 4, MF: 4, FW: 3 };
    // GKが1人もいないと困るので、決まった子を1人外してでも一般入団のGKを入れる
    if (have.GK === 0 && n >= 12) {
      const last = Object.values(w.players).filter((p) => p.grade === 1 && p.pos !== 'GK').pop();
      if (last) { delete w.players[last.id]; n--; have[last.pos]--; }
    }
    for (const pos of ['GK', 'DF', 'MF', 'FW']) {
      while (have[pos] < want[pos] && n < 12) {
        const id = 'p' + ++w.nextId;
        const q = clamp(Math.round((rng() + rng() + rng() - 1.5) * 2), -2, 2);
        const G15 = { GK: ['GK'], DF: ['CB', 'CB', 'LB', 'RB'], MF: ['DM', 'CM', 'CM', 'AM'], FW: ['LW', 'RW', 'ST'] }[pos];
        const p = YA.genPlayer(rng, id, 1, G15[rng.int(0, G15.length - 1)], q, names);
        p.hist = [{ y: w.year, w: 40, t: '一般入団' }];
        w.players[id] = p;
        have[pos]++;
        n++;
      }
    }
    const carry = S.cands.filter((c) => c.kind === 'scout' && c.next && c.status === 'open');
    w.scouting = YA.newScouting();
    for (const c of carry) {
      c.next = false;
      w.scouting.cands.push(c);
    }
    if (carry.length) YA.noteTier(w, 2, `去年の冬に会った${carry.length}人が、今年のスカウトの候補に入っています（クラブ→スカウト）`);
    return n;
  };

  // ---------- 卒業生の追跡・連帯貢献金 ----------
  const UNIV = ['関東の強豪大学', '関西の強豪大学', '東京の大学', '地方の大学'];
  // 卒業後のリーグ。国内は力で J1〜J3、海外は国ごとのリーグ（力が高いと5大リーグへ）
  const ABROAD = [['イングランド', 'プレミアリーグ', 1], ['スペイン', 'ラ・リーガ', 1], ['ドイツ', 'ブンデスリーガ', 1], ['イタリア', 'セリエA', 1], ['フランス', 'リーグ・アン', 1], ['イングランド', 'チャンピオンシップ・イングランド2部', 0], ['スペイン', 'ラ・リーガ2・スペイン2部', 0], ['ドイツ', '2.ブンデスリーガ・ドイツ2部', 0], ['イタリア', 'セリエB・イタリア2部', 0], ['オランダ', 'エールディビジ', 0], ['ポルトガル', 'プリメイラ・リーガ', 0], ['ベルギー', 'ジュピラー・プロ・リーグ', 0], ['トルコ', 'スュペル・リグ', 0], ['スコットランド', 'スコティッシュ・プレミアシップ', 0], ['オーストリア', 'オーストリア・ブンデスリーガ', 0], ['スイス', 'スイス・スーパーリーグ', 0], ['デンマーク', 'デンマーク・スーペルリーガ', 0], ['ギリシャ', 'ギリシャ・スーパーリーグ', 0], ['サウジアラビア', 'サウジ・プロリーグ', 0], ['アメリカ', 'MLS・アメリカ', 0], ['韓国', 'Kリーグ1・韓国', 0], ['オーストラリア', 'Aリーグ・オーストラリア', 0], ['フランス', 'リーグ・ドゥ・フランス2部', 0], ['ブラジル', 'ブラジレイロン・ブラジル', 0], ['アルゼンチン', 'リーガ・プロフェシオナル・アルゼンチン', 0], ['メキシコ', 'リーガMX・メキシコ', 0], ['ノルウェー', 'エリテセリエン・ノルウェー', 0], ['スウェーデン', 'アルスヴェンスカン・スウェーデン', 0], ['ポーランド', 'エクストラクラサ・ポーランド', 0], ['クロアチア', 'HNL・クロアチア', 0], ['チェコ', 'チェコ・リーグ', 0], ['カタール', 'スターズリーグ・カタール', 0], ['アラブ首長国連邦', 'UAEプロリーグ', 0], ['中国', '中国スーパーリーグ', 0], ['タイ', 'タイ・リーグ1', 0]];
  YA.ABROAD_LEAGUES = ABROAD;
  // 海外のクラブ：ひと目で本物のどこかがわかる名前（実在のクラブ名から3〜5字を変えるか、似た言葉に置き換える。
  // 例 レアル→ロイヤル・アル・ヒラル→クレセント）。実在の名前とそっくり同じにはしない（2026-11-15 ユーザー指示）。数は強さ（0〜200）
  const ABROAD_CLUBS = {
    'プレミアリーグ': [['マンチェスター・シティズン', 178], ['リヴァプール・レッズ', 175], ['ロンドン・アーセナルズ', 174], ['チェルシー・ブルーズ', 167], ['マンチェスター・ユニオン', 166], ['トッテナム・スパーズ', 162], ['ニューカッスル・マグパイズ', 161], ['アストン・ヴィランズ', 158], ['ブライトン・シーガルズ', 154], ['ノッティンガム・フォレスターズ', 150], ['クリスタル・キャッスル', 149], ['ボーンマス・チェリーズ', 148], ['ウェストハム・ハマーズ', 147], ['エヴァートン・トフィーズ', 146], ['フラム・コテージャーズ', 145], ['ブレントフォード・ビーズ', 144], ['ウルヴァーハンプトン・ウルフズ', 143], ['レスター・フォクシーズ', 142], ['バーンリー・クラレッツ', 140], ['イプスウィッチ・トラクターズ', 139]],
    'ラ・リーガ': [['ロイヤル・マドリード', 180], ['バルセロナ・カタラン', 176], ['アトレティコ・マドリレーニョ', 168], ['アスレティコ・ビルバイノ', 158], ['ロイヤル・ソシエダ', 157], ['セビリャ・ネルビオン', 156], ['ビジャ・ロイヤル', 155], ['バレンシア・ムルシエラゴ', 152], ['ジローナ・アトレティコ', 151], ['ケルタ・ビーゴ', 150], ['ロイヤル・ベティカ', 149], ['パンプローナ・ロヒージョス', 145], ['マジョルカ・ベルメジョン', 143], ['ラヨ・バジェカス', 142], ['ヘタフェ・アスロネス', 141], ['ペリコ・バルセロナ', 140], ['ビトリア・バベロス', 139], ['パルマス・カナリオス', 138], ['エルチェ・フランハ', 138], ['レバンテ・グラノータ', 138]],
    'ブンデスリーガ': [['バヴァリア・ミュンヘン', 178], ['ヴェルク・レヴァークーゼン', 168], ['プロイセン・ドルトムント', 166], ['レッド・ライプツィヒ', 162], ['アイニヒカイト・フランクフルト', 156], ['シュトゥットガルト・シュヴァーベン', 154], ['ヴォルフスブルク・ヴォルフ', 152], ['ウニオン・ケーペニック', 151], ['フライブルク・ブライスガウ', 150], ['プロイセン・グラートバッハ', 148], ['クライヒガウ・ホッフェン', 147], ['ヴェーザー・ブレーメン', 146], ['マインツ・ヌルフュンファー', 144], ['アウクスブルク・フッガー', 141], ['ハイデンハイム・ブレンツ', 139], ['ザンクト・パウリ・ピラーテン', 139], ['ボーフム・ブラウ', 137], ['キール・シュトルヒェ', 136]],
    'セリエA': [['インテル・ミラネーゼ', 172], ['ユーヴェ・トリノ', 167], ['SSナポリターナ', 166], ['ミラン・ロッソネーリ', 164], ['アタランテ・ベルガモ', 160], ['ASロマーナ', 158], ['SSラツィアーレ', 156], ['フィオーレ・フィレンツェ', 154], ['ボローニャ・ロッソブル', 153], ['トリノ・グラナータ', 148], ['コモ・ラリアーニ', 146], ['ウディネ・フリウラーニ', 145], ['カリアリ・イゾラーニ', 141], ['ヴェローナ・スカリジェリ', 140], ['レッチェ・ジャッロロッシ', 139], ['サッスオーロ・ネロヴェルディ', 140], ['クレモナ・グリジョロッシ', 137], ['ピサ・トッレ', 137], ['エンポリ・アッズーリ', 136], ['モンツァ・ブリアンツァ', 136]],
    'リーグ・アン': [['パリ・サンジェルヴェ', 177], ['ASモナーク', 157], ['オリンポス・マルセイユ', 156], ['リール・ドーグ', 154], ['リヨン・オリンピアン', 153], ['スタッド・レンノワ', 151], ['OGCニソワ', 150], ['ランス・サンエオール', 149], ['ストラスブール・シゴーニュ', 147], ['ナント・カナリ', 144], ['ブレスト・ピラート', 143], ['トゥールーズ・ヴィオレ', 142], ['スタッド・レモワ', 141], ['モンペリエ・パイヤード', 139], ['アーヴル・マリーヌ', 137], ['オセール・ブルゴーニュ', 137], ['アンジェ・ノワール', 136], ['ロリアン・メルル', 136]],
    'チャンピオンシップ・イングランド2部': [['リーズ・ユニオン', 140], ['シェフィールド・ブレイズ', 136], ['サンダーランド・アスレティック', 135], ['ノリッジ・カナリーズ', 133], ['ミドルズブラ・リヴァーサイド', 132], ['コヴェントリー・スカイブルーズ', 131], ['ストーク・ポッターズ', 130], ['カーディフ・ブルーバーズ', 129], ['ブリストル・ロビンズ', 128], ['プリマス・ピルグリムズ', 126], ['サウサンプトン・セインツ', 138], ['ブロムウィッチ・バギーズ', 129], ['ワトフォード・ホーネッツ', 128], ['スウォンジー・スワンズ', 126], ['ハル・タイガース', 125], ['ミルウォール・ライオンズ', 125], ['ブラックバーン・リヴァーズ', 125], ['シェパーズブッシュ・フープス', 124], ['プレストン・リリーホワイツ', 124], ['ダービー・ラムズ', 124], ['レクサム・ドラゴンズ', 124], ['ポーツマス・ポンピー', 123], ['シェフィールド・アウルズ', 122], ['チャールトン・アディックス', 122]],
    'ラ・リーガ2・スペイン2部': [['ロイヤル・サラゴサ', 135], ['UDアルメリエンセ', 133], ['デポル・ガリシア', 132], ['スポルト・ヒホネス', 131], ['カディス・アマリージョ', 130], ['テネリフェ・チチャレロス', 128], ['オビエド・カルバヨネス', 129], ['バリャドリード・ピュセラ', 129], ['ラシン・カンタブリア', 128], ['レガネス・ペピネロス', 128], ['マラガ・ボケロネス', 127], ['グラナダ・ナサリ', 127], ['エイバル・アルメロス', 126], ['ウエスカ・オセンセ', 125], ['ブルゴス・カスティージャ', 124], ['アルバセテ・マンチェゴ', 124], ['コルドバ・カリフ', 124], ['ミランダ・ヘブ', 123], ['カステリョン・アルビネグロ', 123], ['アンドラ・ピリネウ', 122], ['セウタ・カバリャス', 121], ['レオン・クルトゥラル', 121]],
    '2.ブンデスリーガ・ドイツ2部': [['ハンブルク・ロートホーゼン', 136], ['ケルン・ガイスベッケ', 135], ['シャルケ・クナッペン', 134], ['フォルテ・デュッセルドルフ', 132], ['ハノーファー・ローテン', 131], ['カイザースラウテルン・ベッツェ', 129], ['ベルリン・アルテダーメ', 128], ['ニュルンベルク・クルプ', 127], ['カールスルーエ・バーデン', 126], ['ダルムシュタット・リーリエン', 126], ['パーダーボルン・ドムシュタット', 125], ['フュルト・クレーブラット', 124], ['マクデブルク・エルベ', 124], ['ビーレフェルト・アルミン', 124], ['エルファースベルク・ザール', 123], ['ブラウンシュヴァイク・レーヴェン', 123], ['ミュンスター・アードラー', 122], ['ドレスデン・エルプフロレンツ', 122]],
    'セリエB・イタリア2部': [['パルマ・クロチャーティ', 134], ['ジェノヴァ・グリフォーネ', 133], ['ヴェネツィア・ラグーナ', 132], ['パレルモ・ロザネーロ', 131], ['バーリ・ガレッティ', 130], ['サンプ・ブルチェルキアーティ', 128], ['スペツィア・アクイロット', 127], ['フロジノーネ・カナリーニ', 125], ['モデナ・ジャッロブル', 125], ['チェゼーナ・カヴァルッチ', 124], ['カタンザーロ・アクイレ', 124], ['ズュートティロール・アルプス', 122], ['レッジャーナ・エミリア', 122], ['スタビア・ヴェスペ', 122], ['マントヴァ・ヴィルジリアーニ', 122], ['パドヴァ・ビアンコスクデ', 122], ['カッラーラ・マルモ', 121], ['ペスカーラ・デルフィーニ', 121], ['アヴェッリーノ・ルーピ', 121], ['サレルノ・イッポカンピ', 121]],
    'エールディビジ': [['ボーレン・アイントホーフェン', 150], ['アイアス・アムステルダム', 149], ['フェイエン・ロッテルダム', 146], ['アルクマール・カースコッペン', 141], ['トゥエンテ・エンスヘーデ', 138], ['ユトレヒト・ドムステーデ', 133]],
    'プリメイラ・リーガ': [['ベンフィカ・アギアス', 152], ['ポルト・ドラガンイス', 151], ['スポルティング・レオンイス', 150], ['ブラガ・アルセナリスタス', 142], ['ギマランイス・ヴィトリオーゾ', 135], ['ファマリカン・アズイス', 128]],
    'ジュピラー・プロ・リーグ': [['クラブ・ブルッヘン', 147], ['アンデルレヒト・モーヴ', 142], ['ゲンク・スメーデン', 140], ['アントワープ・グレートオールド', 139], ['ヘント・バッファローズ', 138], ['スタンダール・リエジョワ', 134]],
    'スュペル・リグ': [['ガラタ・イスタンブール', 145], ['フェネル・カドゥキョイ', 143], ['ベシク・カラカルタル', 139], ['トラブゾン・フルトゥナ', 133], ['ギョズテペリ・イズミル', 124]],
    'スコティッシュ・プレミアシップ': [['グラスゴー・ケルツ', 140], ['グラスゴー・ガーズ', 136], ['アバディーン・ドンズ', 124], ['ミッドロジアン・ハーツ', 122]],
    'オーストリア・ブンデスリーガ': [['ザルツブルク・ブレンナー', 141], ['シュテルン・グラーツ', 131], ['ラピッド・ヒュッテルドルフ', 128], ['アウストリア・ファヴォリーテン', 126]],
    'スイス・スーパーリーグ': [['バーゼル・ロートブラウ', 133], ['ヤングスターズ・ベルン', 131], ['チューリッヒ・ホッパーズ', 130], ['セルヴェッタ・ジュネーヴ', 125]],
    'デンマーク・スーペルリーガ': [['コペンハーゲン・レーヴェルネ', 132], ['ミッティラン・ウルヴェ', 130], ['オーフスGF', 125], ['ブレンビー・ドレンゲネ', 122]],
    'ギリシャ・スーパーリーグ': [['オリンピアキ・ピレウス', 132], ['パナシナイキ・アテネ', 130], ['テッサロニキ・ディケファロス', 128], ['アテネ・エノシス', 127]],
    'サウジ・プロリーグ': [['リヤド・クレセント', 136], ['リヤド・ヴィクトリー', 135], ['ジッダ・ユニオン', 133], ['ダンマーム・アコード', 124]],
    'MLS・アメリカ': [['マイアミ・インターナショナル', 129], ['ロサンゼルス・ギャラクシアン', 128], ['ニューヨーク・メトロ', 126], ['アトランタ・ユナイト', 125], ['シアトル・サウンズ', 124], ['トロント・レッズ', 122]],
    'Kリーグ1・韓国': [['全北モーターズ', 124], ['蔚山タイガース', 123], ['ソウル・シティ', 120], ['浦項アイアンズ', 120], ['水原ブルーバーズ', 116]],
    'Aリーグ・オーストラリア': [['メルボルン・トライアンフ', 117], ['シドニー・スカイブルーズ', 115], ['ブリスベン・ハウル', 112], ['パース・グローリアス', 110]],
    'リーグ・ドゥ・フランス2部': [['サンテティエンヌ・ヴェール', 132], ['メッス・グルナ', 130], ['カーン・マラン', 128], ['ギャンガン・ブルトン', 127], ['アミアン・リコルヌ', 125], ['バスティア・コルス', 124], ['トロワ・オーボワ', 125], ['クレルモン・オーヴェルニュ', 124], ['グルノーブル・アルプ', 123], ['ダンケルク・マリン', 123], ['ナンシー・ロレーヌ', 123], ['ポー・ベアルン', 122], ['ロデーズ・アヴェロン', 122], ['ラヴァル・タンゴ', 122], ['サントゥアン・エトワール', 122], ['ル・マン・サルト', 122], ['アヌシー・ラック', 121], ['ブローニュ・オパール', 121]],
    'ブラジレイロン・ブラジル': [['フラメンガ・リオ', 148], ['パルメイラ・ヴェルデ', 147], ['ボタ・エストレラ', 143], ['サンパウロ・トリコロール', 142], ['コリンティアス・パウリスタ', 142], ['ガロ・ミネイロ', 141], ['リオ・フルミナンテ', 139], ['インテル・ガウショ', 139], ['ポルトアレグレ・イモルタル', 138], ['サントス・ペイシェ', 135]],
    'リーガ・プロフェシオナル・アルゼンチン': [['リーベル・ミリオナリオス', 145], ['ボカ・ショネス', 144], ['ラシン・アカデミア', 137], ['インデ・ロホ', 135], ['ベレス・フォルティン', 134], ['サン・ロレンツォ・クエルボ', 133]],
    'リーガMX・メキシコ': [['アギラス・メヒコ', 132], ['モンテレイ・ライアス', 131], ['ヌエボレオン・ティグレ', 131], ['グアダラハラ・カブラス', 128], ['トルーカ・ディアブロス', 128], ['クルセロ・アスル', 127]],
    'エリテセリエン・ノルウェー': [['ボードー・グリム', 126], ['モルデ・ローゼ', 122], ['ローゼンバーグ・トロンハイム', 121], ['ベルゲン・ブランデ', 120]],
    'アルスヴェンスカン・スウェーデン': [['マルメ・ヒンメルスブロー', 122], ['ユールゴード・ストックホルム', 119], ['ストックホルム・ソルナ', 118], ['ハンマルビー・ビーン', 118]],
    'エクストラクラサ・ポーランド': [['レギオン・ワルシャワ', 120], ['ポズナン・コレヨジ', 119], ['ラクフ・ステル', 117], ['ビャウィストク・ヤガ', 115]],
    'HNL・クロアチア': [['ザグレブ・モドリ', 127], ['スプリト・ハイドゥチ', 124], ['リエカ・ビイェリ', 120], ['オシエク・ドラヴァ', 116]],
    'チェコ・リーグ': [['スラヴァ・プラハ', 127], ['スパルタン・プラハ', 126], ['プルゼニ・ピルスナー', 122], ['オストラヴァ・ハヴィージ', 116]],
    'スターズリーグ・カタール': [['アル・サディーヤ', 116], ['ドゥハイル・ナイツ', 114], ['ラーヤン・ライオンズ', 112]],
    'UAEプロリーグ': [['アイン・ザイーム', 116], ['ドバイ・ナイツ', 114], ['アブダビ・ユニティ', 113]],
    '中国スーパーリーグ': [['上海ハーバー', 116], ['山東マウンテン', 114], ['上海シェン', 113], ['北京ガーディアン', 111], ['成都ハイビスカス', 110]],
    'タイ・リーグ1': [['ブリーラム・サンダー', 109], ['バンコク・ユニオン', 106], ['クローントゥーイ・ポート', 105]],
  };
  // 前の名前（2026-11-15 までの2通り）→ いまの名前
  YA.CLUB_RENAME = {
    'マンチェスター・レッドデビルズ': 'マンチェスター・ユニオン', 'マンチェスター・シティズンズ': 'マンチェスター・シティズン', 'ロンドン・ガナーズ': 'ロンドン・アーセナルズ', 'ロンドン・ブルーズ': 'チェルシー・ブルーズ', 'ロンドン・スパーズ': 'トッテナム・スパーズ', 'バーミンガム・ヴィランズ': 'アストン・ヴィランズ', 'ロンドン・ビーズ': 'クリスタル・キャッスル', 'マドリード・ブランコス': 'ロイヤル・マドリード', 'マドリード・コルチョネロス': 'アトレティコ・マドリレーニョ', 'バルセロナ・ブラウグラナ': 'バルセロナ・カタラン', 'セビージャ・ネルビオネンセス': 'セビリャ・ネルビオン', 'バレンシア・チェ': 'バレンシア・ムルシエラゴ', 'ビルバオ・レオネス': 'アスレティコ・ビルバイノ', 'サンセバスティアン・チュリウルディン': 'ロイヤル・ソシエダ', 'ビジャレアル・サブマリノス': 'ビジャ・ロイヤル', 'ミュンヘン・ロートス': 'バヴァリア・ミュンヘン', 'ドルトムント・シュヴァルツゲルプ': 'プロイセン・ドルトムント', 'レヴァークーゼン・ヴェルクスエルフ': 'ヴェルク・レヴァークーゼン', 'フランクフルト・アドラー': 'アイニヒカイト・フランクフルト', 'ライプツィヒ・ブレンナー': 'レッド・ライプツィヒ', 'ミラノ・ロッソネーリ': 'ミラン・ロッソネーリ', 'ミラノ・ネラッズーリ': 'インテル・ミラネーゼ', 'トリノ・ビアンコネーリ': 'ユーヴェ・トリノ', 'ローマ・ジャッロロッシ': 'ASロマーナ', 'ナポリ・パルテノペイ': 'SSナポリターナ', 'ベルガモ・デア': 'アタランテ・ベルガモ', 'パリ・ルージュエブルー': 'パリ・サンジェルヴェ', 'マルセイユ・フォセアン': 'オリンポス・マルセイユ', 'リヨン・ゴーン': 'リヨン・オリンピアン', 'モナコ・モネガスク': 'ASモナーク', 'ニース・エグロン': 'OGCニソワ', 'アムステルダム・ゴーデンゾーネン': 'アイアス・アムステルダム', 'ロッテルダム・ステーデリンゲン': 'フェイエン・ロッテルダム', 'アイントホーフェン・ブーレン': 'ボーレン・アイントホーフェン', 'エンスヘーデ・トゥッカーズ': 'トゥエンテ・エンスヘーデ', 'ユトレヒト・ドムステーデリンゲン': 'ユトレヒト・ドムステーデ', 'ブリュッセル・モーヴ': 'アンデルレヒト・モーヴ', 'ブルッヘ・ブラウズワルト': 'クラブ・ブルッヘン', 'ゲント・バッファローズ': 'ヘント・バッファローズ', 'リエージュ・ルーシュ': 'スタンダール・リエジョワ', 'リスボン・アギアス': 'ベンフィカ・アギアス', 'リスボン・レオンイス': 'スポルティング・レオンイス', 'ギマランイス・コンキスタドーレス': 'ギマランイス・ヴィトリオーゾ', 'イスタンブール・ガラタ': 'ガラタ・イスタンブール', 'イスタンブール・カナリア': 'フェネル・カドゥキョイ', 'イスタンブール・カラカルタル': 'ベシク・カラカルタル', 'イズミル・ギョズテペ': 'ギョズテペリ・イズミル', 'グラスゴー・フープス': 'グラスゴー・ケルツ', 'グラスゴー・ジェルズ': 'グラスゴー・ガーズ', 'エディンバラ・ジャンボス': 'ミッドロジアン・ハーツ', 'ザルツブルク・ローテン': 'ザルツブルク・ブレンナー', 'グラーツ・シュヴォーツ': 'シュテルン・グラーツ', 'ウィーン・グリュンヴァイセン': 'ラピッド・ヒュッテルドルフ', 'ウィーン・フェイルヒェン': 'アウストリア・ファヴォリーテン', 'マンチェスター・アスレティック': 'マンチェスター・シティズン', 'リヴァプール・ユナイテッド': 'リヴァプール・レッズ', 'ノース・ロンドンFC': 'ロンドン・アーセナルズ', 'ウェスト・ロンドン・ローヴァーズ': 'チェルシー・ブルーズ', 'マンチェスター・カウンティ': 'マンチェスター・ユニオン', 'イースト・ロンドン・ユナイテッド': 'トッテナム・スパーズ', 'タインサイドFC': 'ニューカッスル・マグパイズ', 'バーミンガム・アスレティック': 'アストン・ヴィランズ', 'ブライトン・ローヴァーズ': 'ブライトン・シーガルズ', 'ノッティンガム・タウン': 'ノッティンガム・フォレスターズ', 'サウス・ロンドンFC': 'クリスタル・キャッスル', 'ボーンマス・アスレティック': 'ボーンマス・チェリーズ', 'マドリードFC': 'ロイヤル・マドリード', 'FCカタルーニャ': 'バルセロナ・カタラン', 'アトレティコ・カスティーリャ': 'アトレティコ・マドリレーニョ', 'アスレティック・ビスカヤ': 'アスレティコ・ビルバイノ', 'レアル・ギプスコア': 'ロイヤル・ソシエダ', 'レアル・セビリャーナ': 'セビリャ・ネルビオン', 'UDビジャ・アマリージャ': 'ビジャ・ロイヤル', 'アトレティコ・バレンシア': 'バレンシア・ムルシエラゴ', 'レアル・ビーゴ': 'ケルタ・ビーゴ', 'FCミュンヘン': 'バヴァリア・ミュンヘン', 'レヴァークーゼンSV': 'ヴェルク・レヴァークーゼン', 'ドルトムントSV': 'プロイセン・ドルトムント', 'ライプツィヒFC': 'レッド・ライプツィヒ', 'フランクフルトSV': 'アイニヒカイト・フランクフルト', 'VfRシュトゥットガルト': 'シュトゥットガルト・シュヴァーベン', 'ヴォルフスブルクFC': 'ヴォルフスブルク・ヴォルフ', 'FCベルリン': 'ウニオン・ケーペニック', 'SVフライブルク': 'フライブルク・ブライスガウ', 'ミラノFC': 'インテル・ミラネーゼ', 'FCピエモンテ': 'ユーヴェ・トリノ', 'SSパルテノペ': 'SSナポリターナ', 'ACロンバルディア': 'ミラン・ロッソネーリ', 'ACベルガモ': 'アタランテ・ベルガモ', 'ローマFC': 'ASロマーナ', 'SSカピトリーナ': 'SSラツィアーレ', 'フィレンツェFC': 'フィオーレ・フィレンツェ', 'ボローニャAC': 'ボローニャ・ロッソブル', 'パリ・オリンピック': 'パリ・サンジェルヴェ', 'モナコFC': 'ASモナーク', 'オリンピック・プロヴァンス': 'オリンポス・マルセイユ', 'リールOSC': 'リール・ドーグ', 'リヨンFC': 'リヨン・オリンピアン', 'スタッド・ブルターニュ': 'スタッド・レンノワ', 'ニースAC': 'OGCニソワ', 'ランスAC': 'ランス・サンエオール', 'リーズ・アスレティック': 'リーズ・ユニオン', 'シェフィールド・ローヴァーズ': 'シェフィールド・ブレイズ', 'ノリッジ・タウン': 'ノリッジ・カナリーズ', 'ミドルズブラ・ユナイテッド': 'ミドルズブラ・リヴァーサイド', 'コヴェントリー・タウン': 'コヴェントリー・スカイブルーズ', 'ストーク・アルビオン': 'ストーク・ポッターズ', 'カーディフ・アスレティック': 'カーディフ・ブルーバーズ', 'ブリストル・アスレティック': 'ブリストル・ロビンズ', 'プリマス・ユナイテッド': 'プリマス・ピルグリムズ', 'サラゴサFC': 'ロイヤル・サラゴサ', 'アルメリアCF': 'UDアルメリエンセ', 'ラ・コルーニャFC': 'デポル・ガリシア', 'ヒホン・アスレティック': 'スポルト・ヒホネス', 'CDカディス': 'カディス・アマリージョ', 'UDテネリフェ': 'テネリフェ・チチャレロス', 'ハンブルクFC': 'ハンブルク・ロートホーゼン', 'ケルンSV': 'ケルン・ガイスベッケ', 'ゲルゼンキルヒェンSV': 'シャルケ・クナッペン', 'デュッセルドルフSV': 'フォルテ・デュッセルドルフ', 'ハノーファーFC': 'ハノーファー・ローテン', 'カイザースラウテルンSV': 'カイザースラウテルン・ベッツェ', 'パルマAC': 'パルマ・クロチャーティ', 'ジェノヴァAC': 'ジェノヴァ・グリフォーネ', 'ヴェネツィアAC': 'ヴェネツィア・ラグーナ', 'パレルモAC': 'パレルモ・ロザネーロ', 'バーリFC': 'バーリ・ガレッティ', 'アイントホーフェンSV': 'ボーレン・アイントホーフェン', 'アムステルダムFC': 'アイアス・アムステルダム', 'ロッテルダムSV': 'フェイエン・ロッテルダム', 'アルクマールFC': 'アルクマール・カースコッペン', 'エンスヘーデFC': 'トゥエンテ・エンスヘーデ', 'ユトレヒトSV': 'ユトレヒト・ドムステーデ', 'SLリスボア': 'ベンフィカ・アギアス', 'ポルトSC': 'ポルト・ドラガンイス', 'スポルト・リスボア': 'スポルティング・レオンイス', 'ブラガFC': 'ブラガ・アルセナリスタス', 'ギマランイスSC': 'ギマランイス・ヴィトリオーゾ', 'ファマリカンFC': 'ファマリカン・アズイス', 'ブルッヘSV': 'クラブ・ブルッヘン', 'RSCブリュッセル': 'アンデルレヒト・モーヴ', 'ゲンクFC': 'ゲンク・スメーデン', 'アントワープSC': 'アントワープ・グレートオールド', 'ゲントFC': 'ヘント・バッファローズ', 'リエージュFC': 'スタンダール・リエジョワ', 'イスタンブールSK': 'ガラタ・イスタンブール', 'カドゥキョイSK': 'フェネル・カドゥキョイ', 'ボスポラスJK': 'ベシク・カラカルタル', 'トラブゾンFK': 'トラブゾン・フルトゥナ', 'イズミルSK': 'ギョズテペリ・イズミル', 'グラスゴー・アスレティック': 'グラスゴー・ケルツ', 'グラスゴー・ユナイテッド': 'グラスゴー・ガーズ', 'アバディーン・アスレティック': 'アバディーン・ドンズ', 'エディンバラFC': 'ミッドロジアン・ハーツ', 'ザルツブルクSV': 'ザルツブルク・ブレンナー', 'SKグラーツ': 'シュテルン・グラーツ', 'ウィーンSC': 'ラピッド・ヒュッテルドルフ', 'FKウィーン': 'アウストリア・ファヴォリーテン', 'バーゼルSV': 'バーゼル・ロートブラウ', 'ベルンFC': 'ヤングスターズ・ベルン', 'チューリッヒSC': 'チューリッヒ・ホッパーズ', 'ジュネーヴFC': 'セルヴェッタ・ジュネーヴ', 'コペンハーゲンBK': 'コペンハーゲン・レーヴェルネ', 'ユトランドFC': 'ミッティラン・ウルヴェ', 'オーフスSF': 'オーフスGF', 'オーデンセFC': 'ブレンビー・ドレンゲネ', 'ピレウスFC': 'オリンピアキ・ピレウス', 'アテネFC': 'パナシナイキ・アテネ', 'テッサロニキAC': 'テッサロニキ・ディケファロス', 'アテナイコスFC': 'アテネ・エノシス', 'リヤドFC': 'リヤド・ヴィクトリー', 'ジッダFC': 'ジッダ・ユニオン', 'ダンマームFC': 'ダンマーム・アコード', 'マイアミ・シティ': 'マイアミ・インターナショナル', 'ロサンゼルス・ユナイテッド': 'ロサンゼルス・ギャラクシアン', 'ニューヨーク・アスレティック': 'ニューヨーク・メトロ', 'アトランタFC': 'アトランタ・ユナイト', 'シアトル・ユナイテッド': 'シアトル・サウンズ', 'トロント・シティ': 'トロント・レッズ', '全州FC': '全北モーターズ', '蔚山シティ': '蔚山タイガース', '浦項ユナイテッド': '浦項アイアンズ', '水原シティ': '水原ブルーバーズ', 'メルボルン・ユナイテッド': 'メルボルン・トライアンフ', 'シドニー・シティ': 'シドニー・スカイブルーズ', 'ブリスベン・アスレティック': 'ブリスベン・ハウル', 'パース・ユナイテッド': 'パース・グローリアス',
  };
  YA.ABROAD_CLUBS = ABROAD_CLUBS;
  // リーグの水準（その中で目立つかの物差し。内部の値）
  const LV = { J1リーグ: 14.6, J2リーグ: 13, J3リーグ: 11.6, 大学リーグ: 11.2, 社会人リーグ: 9.5 };
  for (const lg in ABROAD_CLUBS) LV[lg] = Math.round(YA.unrate(ABROAD_CLUBS[lg].reduce((t, c) => t + c[1], 0) / ABROAD_CLUBS[lg].length) * 10) / 10;
  YA.LEAGUE_LV = LV;
  const domLeague = (o) => (o >= 13.6 ? 'J1リーグ' : o >= 12.2 ? 'J2リーグ' : 'J3リーグ');
  const J_TIER_NAME = { 1: 'J1リーグ', 2: 'J2リーグ', 3: 'J3リーグ' };
  // Jクラブの強さ：部ごとの幅の中で、名前から決まる（J1 128〜150・J2 110〜127・J3 94〜110）
  const J_BAND = { 1: [128, 150], 2: [110, 127], 3: [94, 110] };
  YA.leagueCountry = (lg) => { const x = ABROAD.find((y) => y[1] === lg); return x ? x[0] : '日本'; };
  YA.clubName = (name) => (YA.CLUB_RENAME && YA.CLUB_RENAME[name]) || name;
  // リーグ名の中のかっこをやめた（2026-11-16「パレルモ・ロザネーロ（セリエB（イタリア2部））」と二重になっていた）。古い保存の名前を移す
  YA.LEAGUE_RENAME = { 'チャンピオンシップ（イングランド2部）': 'チャンピオンシップ・イングランド2部', 'ラ・リーガ2（スペイン2部）': 'ラ・リーガ2・スペイン2部', '2.ブンデスリーガ（ドイツ2部）': '2.ブンデスリーガ・ドイツ2部', 'セリエB（イタリア2部）': 'セリエB・イタリア2部', 'リーグ・ドゥ（フランス2部）': 'リーグ・ドゥ・フランス2部', 'MLS（アメリカ）': 'MLS・アメリカ', 'Kリーグ1（韓国）': 'Kリーグ1・韓国', 'Aリーグ（オーストラリア）': 'Aリーグ・オーストラリア', 'ブラジレイロン（ブラジル）': 'ブラジレイロン・ブラジル', 'リーガ・プロフェシオナル（アルゼンチン）': 'リーガ・プロフェシオナル・アルゼンチン', 'リーガMX（メキシコ）': 'リーガMX・メキシコ', 'エリテセリエン（ノルウェー）': 'エリテセリエン・ノルウェー', 'アルスヴェンスカン（スウェーデン）': 'アルスヴェンスカン・スウェーデン', 'エクストラクラサ（ポーランド）': 'エクストラクラサ・ポーランド', 'HNL（クロアチア）': 'HNL・クロアチア', 'スターズリーグ（カタール）': 'スターズリーグ・カタール' };
  YA.leagueName = (lg) => (YA.LEAGUE_RENAME && YA.LEAGUE_RENAME[lg]) || lg;
  // 古い保存の名前を新しい名前へ（年に一度・画面を開いたときに呼ぶ）
  YA.fixClubNames = function (w) {
    if (!w || w.clubNamesV >= 4) return;
    for (const a of w.alumni || []) {
      if (a.club) a.club = YA.clubName(a.club);
      if (a.league) a.league = YA.leagueName(a.league);
      for (const x of a.seasons || []) { if (x.club) x.club = YA.clubName(x.club); if (x.league) x.league = YA.leagueName(x.league); }
      for (const m of a.moves || []) { m.fromLg = YA.leagueName(m.fromLg); m.toLg = YA.leagueName(m.toLg); }
      if (a.club && YA.clubLeague(a.club) && a.abroad) a.league = YA.clubLeague(a.club);
    }
    w.clubNamesV = 4;
  };
  YA.clubStr = function (name, w) {
    name = YA.clubName(name);
    // 自分のクラブのトップは、いまいる部の幅で（昇格・降格で変わる）
    if (w && w.top && name === w.top.name) { const b = J_BAND[w.top.j] || J_BAND[2]; return b[0] + (YA.hash('str' + name) % (b[1] - b[0] + 1)); }
    for (const lg in ABROAD_CLUBS) for (const c of ABROAD_CLUBS[lg]) if (c[0] === name) return c[1];
    const j = (YA.PRO_CLUBS || []).find((c) => c.name === name);
    if (j) { const b = J_BAND[j.tier] || J_BAND[3]; return b[0] + (YA.hash('str' + name) % (b[1] - b[0] + 1)); }
    return null;
  };
  // クラブのリーグ（J は部の表から。海外はリーグの表から）
  YA.clubLeague = function (name) {
    name = YA.clubName(name);
    for (const lg in ABROAD_CLUBS) if (ABROAD_CLUBS[lg].some((c) => c[0] === name)) return lg;
    const j = (YA.PRO_CLUBS || []).find((c) => c.name === name);
    return j ? J_TIER_NAME[j.tier] : null;
  };
  // 力に合うクラブを選ぶ：その子の総合力より少し上（+4）に近いクラブほど選ばれやすい
  function pickFit(r, list, target) {
    const ws = list.map((c) => Math.exp(-Math.abs(c[1] - target) / 7));
    let x = r() * ws.reduce((s, v) => s + v, 0);
    for (let i = 0; i < list.length; i++) { x -= ws[i]; if (x <= 0) return list[i]; }
    return list[list.length - 1];
  }
  const jList = (w) => (YA.PRO_CLUBS || []).filter((c) => !w.top || c.name !== w.top.name).map((c) => [c.name, YA.clubStr(c.name)]);
  function jClub(w, r, league, o) {
    const target = o != null ? YA.rate(o) + 4 : J_BAND[league === 'J1リーグ' ? 1 : league === 'J2リーグ' ? 2 : 3].reduce((a, b) => (a + b) / 2);
    return pickFit(r, jList(w), target)[0];
  }
  // 最初の海外移籍は中堅のリーグから（2026-11-17：Jから直接プレミア15人・セリエA13人、ベルギー0人と現実から遠かった）。
  // 日本の選手の最初の海外は、ベルギー・オランダ・ポルトガル・スコットランド・オーストリア・スイス・デンマーク・ドイツ2部・イングランド2部がほとんど。
  // 5大リーグへ直接行けるのは、とても強い子（総合力165以上）だけ。30歳を過ぎると MLS・中東・アジアへ行きやすい
  const FIRST_ABROAD = ['ジュピラー・プロ・リーグ', 'エールディビジ', 'プリメイラ・リーガ', 'スコティッシュ・プレミアシップ', 'オーストリア・ブンデスリーガ', 'スイス・スーパーリーグ', 'デンマーク・スーペルリーガ', '2.ブンデスリーガ・ドイツ2部', 'チャンピオンシップ・イングランド2部'];
  const VETERAN = ['MLS・アメリカ', 'サウジ・プロリーグ', 'スターズリーグ・カタール', 'UAEプロリーグ', '中国スーパーリーグ', 'タイ・リーグ1', 'Aリーグ・オーストラリア', 'Kリーグ1・韓国'];
  YA.FIRST_ABROAD = FIRST_ABROAD;
  YA.retireWord = (a) => (a && (a.quit || (a.age != null && a.age < 28)) ? 'サッカーをやめた' : '引退');
  function abroadPick(r, o, bigOk, first, age) {
    const list = [];
    const rt = YA.rate(o);
    for (const [, lg, big] of ABROAD) {
      if (first && !(age >= 30)) { if (!(FIRST_ABROAD.indexOf(lg) >= 0 || (big && rt >= 165))) continue; }
      else if (!bigOk && big) continue;
      for (const c of ABROAD_CLUBS[lg]) list.push([c[0], c[1], lg]);
    }
    let target = rt + 4;
    if (first && rt < 165) target = Math.min(target, 150);
    const vet = age != null && age >= 30;
    const c = vet ? pickFit(r, list.filter((x) => VETERAN.indexOf(x[2]) >= 0).concat(list.filter((x) => r() < 0.25)), target) : pickFit(r, list, target);
    return { club: c[0], league: c[2] };
  }
  const abroadClub = (r, league) => r.pick(ABROAD_CLUBS[league] || ABROAD_CLUBS['プレミアリーグ'])[0];
  YA.alumniEntry = function (w, p, note) {
    const o = Math.round(YA.ovr(p) * 10) / 10;
    const r = YA.rngOf(w.seed + p.num * 7 + w.year);
    const status = p._path || (o >= 13.2 ? 'pro' : o >= 10.5 ? 'univ' : 'amateur');
    const abroad = !!(p._sold && o >= 13);
    const ab = abroad ? abroadPick(r, o, false, true, 18) : null;
    // トップ昇格はこのクラブのトップへ。ほかへ売り込んだ子は、力に合う部のクラブへ
    const own = status === 'pro' && !p._sold && w.top && YA.rate(o) >= YA.topCutLine(w);
    const dl = domLeague(o);
    let jc = null;
    return { name: p.name, pos: p.pos, main: p.main, year: w.year, ovr: o, ovr0: o, note, grade: 3, age: 18, status,
      club: status === 'pro' ? (own ? w.top.name : ab ? ab.club : (jc = jClub(w, r, dl, o))) : status === 'univ' ? r.pick(UNIV) : '社会人',
      league: status === 'pro' ? (own ? YA.J_NAME[w.top.j] : ab ? ab.league : YA.clubLeague(jc) || dl) : status === 'univ' ? '大学リーグ' : '社会人リーグ',
      apps: 0, goals: 0, nat: 0, youthCaps: (p.youthCaps || 0) + (p.nat || 0), natGoals: 0, transfers: 0, retired: false, traits: p.traits.slice(), pushed: p._push || null, abroad, seasons: [], titles: [], awards: [] };
  };
  // リーグの1シーズンの試合数（ないものは34）
  const LEAGUE_GAMES = { J1リーグ: 38, J2リーグ: 38, J3リーグ: 38, プレミアリーグ: 38, ラ・リーガ: 38, ブンデスリーガ: 34, セリエA: 38, 'リーグ・アン': 34, 'チャンピオンシップ・イングランド2部': 46, 'ラ・リーガ2・スペイン2部': 42, '2.ブンデスリーガ・ドイツ2部': 34, 'セリエB・イタリア2部': 38, 'リーグ・ドゥ・フランス2部': 34, エールディビジ: 34, プリメイラ・リーガ: 34, 'ジュピラー・プロ・リーグ': 34, 'スュペル・リグ': 36, 'スコティッシュ・プレミアシップ': 38, 'オーストリア・ブンデスリーガ': 32, 'スイス・スーパーリーグ': 36, 'デンマーク・スーペルリーガ': 32, 'ギリシャ・スーパーリーグ': 30, 'サウジ・プロリーグ': 34, 'MLS・アメリカ': 34, 'Kリーグ1・韓国': 38, 'Aリーグ・オーストラリア': 26, 'ブラジレイロン・ブラジル': 38, 'リーガ・プロフェシオナル・アルゼンチン': 27, 'リーガMX・メキシコ': 34, 'エリテセリエン・ノルウェー': 30, 'アルスヴェンスカン・スウェーデン': 30, 'エクストラクラサ・ポーランド': 34, 'HNL・クロアチア': 36, 'チェコ・リーグ': 30, 'スターズリーグ・カタール': 22, 'UAEプロリーグ': 26, '中国スーパーリーグ': 30, 'タイ・リーグ1': 30 };
  YA.LEAGUE_GAMES = LEAGUE_GAMES;
  // 細かい位置ごとの点・アシストの取りやすさ（ST を1として）
  const GOAL_F = { ST: 1, SS: 0.85, LW: 0.7, RW: 0.7, AM: 0.6, LM: 0.4, RM: 0.4, CM: 0.3, DM: 0.12, LWB: 0.12, RWB: 0.12, LB: 0.08, RB: 0.08, CB: 0.1, GK: 0 };
  const AST_F = { ST: 0.45, SS: 0.6, LW: 0.8, RW: 0.8, AM: 1, LM: 0.75, RM: 0.75, CM: 0.6, DM: 0.3, LWB: 0.55, RWB: 0.55, LB: 0.4, RB: 0.4, CB: 0.08, GK: 0 };
  // バロンドールの点：総合力（0〜200）＋その年の数字＋タイトル＋リーグの格。BD_LINE 以上で30人の候補に入る
  const BD_LINE = 178;
  YA.ballonScore = function (a, s, big5, lgR) {
    if (a.status !== 'pro' || !a.abroad || s.apps < 15) return null;
    const isGK = a.pos === 'GK';
    let v = YA.rate(a.ovr) + (isGK ? (s.cleans || 0) * 0.5 : s.goals * 0.45 + (s.assists || 0) * 0.3);
    if (s.titles.some((t) => /チャンピオンズリーグ/.test(t))) v += 9;
    if (s.titles.includes(s.league + '優勝')) v += 4;
    if (s.awards.some((t) => /W杯/.test(t))) v += 3;
    v += big5 ? 4 : lgR >= 140 ? 0 : -8;
    return v >= BD_LINE ? v : null;
  };
  YA.BD_LINE = BD_LINE;
  // 市場価値（万円）：移籍金と同じ物差し（海外は高い）に、年齢の掛け目（若いほど高く、30歳を過ぎると下がる）
  YA.marketValue = function (a) {
    if (a.status !== 'pro' || a.retired) return 0;
    const base = a.abroad ? Math.pow(Math.max(0, a.ovr - 9), 2.2) * 560 : Math.pow(Math.max(0, a.ovr - 9), 2) * 80;
    const ag = a.age <= 21 ? 1.3 : a.age <= 24 ? 1.15 : a.age <= 28 ? 1 : a.age <= 30 ? 0.7 : 0.4;
    return Math.round((base * ag) / 10) * 10;
  };
  // お金の見せ方：1億以上は「X.X億円」
  YA.yen = (m) => (!m ? '0円' : m >= 10000 ? `${(m / 10000).toFixed(m >= 100000 ? 0 : 1).replace(/\.0$/, '')}億円` : `${m}万円`);
  // 成績の1行（GK は完封、ほかは得点とアシスト）。古い保存でアシストが無い年は出さない
  YA.statLine = function (x, gk) {
    if (gk) return `${x.apps || 0}試合` + (x.cleans != null ? `・完封${x.cleans}` : '');
    return `${x.apps || 0}試合${x.goals || 0}得点` + (x.assists != null ? `${x.assists}アシスト` : '');
  };
  // 1年ぶんの経歴：出場・得点・アシスト（GK は完封）・タイトル・個人の賞。卒業生名鑑で年ごとに見られる
  function careerSeason(w, a, r) {
    const lg = a.league || (a.status === 'pro' ? domLeague(a.ovr) : a.status === 'univ' ? '大学リーグ' : '社会人リーグ');
    a.league = lg;
    const cs = a.status === 'pro' ? YA.clubStr(a.club, w) : null;
    const lv = cs != null ? YA.unrate(cs) : LV[lg] || 12;
    const lgR = YA.rate(LV[lg] || 12);
    const rel = a.ovr - lv; // リーグの中での力の差（+なら主力）
    // 点とアシストの取りやすさは細かい位置から（2026-11-15「ゴール数やアシスト、出場数」）。GK は点もアシストも0で、代わりに完封
    const isGK = a.pos === 'GK';
    const fw = isGK ? 0 : GOAL_F[a.main] != null ? GOAL_F[a.main] : a.pos === 'FW' ? 1 : a.pos === 'MF' ? 0.45 : 0.1;
    const af = isGK ? 0 : AST_F[a.main] != null ? AST_F[a.main] : a.pos === 'FW' ? 0.5 : a.pos === 'MF' ? 0.7 : 0.25;
    // リーグごとの試合数（2026-11-17：プロは全部34試合だった。J1〜J3は2024年から38試合）
    const games = a.status === 'pro' ? LEAGUE_GAMES[lg] || 34 : a.status === 'univ' ? 22 : 18;
    const apps = Math.round(clamp(games * (0.55 + rel * 0.18) + r.int(-4, 4), 0, games));
    // 点を取る子は、リーグの中で力が抜けているほど伸びが大きい（得点王が20点前後になるように）
    const goals = isGK || !apps ? 0 : Math.round(clamp(apps * fw * (0.22 + rel * 0.08 + Math.max(0, rel - 1.5) * 0.1 * fw) + r.int(-1, 2), 0, 40));
    const assists = isGK || !apps ? 0 : Math.round(clamp(apps * af * (0.13 + rel * 0.04) + r.int(-1, 2), 0, 24));
    const cleans = isGK && apps ? Math.round(apps * clamp(0.24 + ((cs != null ? cs : lgR) - lgR) * 0.006 + rel * 0.03, 0.06, 0.55)) : 0;
    const s = { y: w.year, age: a.age, club: a.club, league: lg, apps, goals, assists, titles: [], awards: [] };
    if (isGK) s.cleans = cleans;
    const win = (name, p) => { if (r() < p) { s.titles.push(name); a.titles.push({ y: w.year, name }); } };
    const award = (name, p) => { if (r() < p) { s.awards.push(name); a.awards.push({ y: w.year, name }); } };
    // 強いクラブにいるほど優勝しやすい（リーグの水準よりどれだけ強いか）。本人が主力ならもう少し
    const strong = clamp(0.03 + ((cs != null ? cs : lgR) - lgR) * 0.012 + rel * 0.01, 0.005, 0.3);
    if (apps >= 10) {
      win(lg + '優勝', strong);
      if (a.status === 'pro' && !a.abroad) { win('天皇杯優勝', strong * 0.5); if (lg === 'J1リーグ') win('ルヴァンカップ優勝', strong * 0.5); }
      if (a.abroad) win('国内カップ優勝', strong * 0.5);
      if (a.abroad && cs != null && cs >= 150 && a.ovr >= 15) win('チャンピオンズリーグ優勝', clamp(0.01 + (cs - 150) * 0.004 + (a.ovr - 15) * 0.02, 0.01, 0.2));
      if (lg === 'J1リーグ' && a.ovr >= 14) win('ACL優勝', 0.05);
      // 個人の賞
      if (!isGK && goals >= Math.round((a.status === 'pro' ? 18 : 12) * games / 34)) award(lg + ' 得点王', clamp(0.15 + (goals - 18) * 0.04, 0.15, 0.6));
      if (!isGK && assists >= (a.status === 'pro' ? 9 : 7)) award(lg + ' アシスト王', clamp(0.2 + (assists - 9) * 0.06, 0.2, 0.6));
      if (isGK && rel >= 2 && cleans >= (a.status === 'pro' ? 12 : 8)) award(lg + ' 最優秀GK', clamp(0.12 + (rel - 2) * 0.08, 0.12, 0.45));
      if (rel >= 3.2) award(lg + ' ベストイレブン', clamp(0.06 + (rel - 3.2) * 0.08, 0, 0.3));
      if (rel >= 3.8) award(lg + ' 年間MVP', 0.05);
      if (a.status === 'pro' && a.age <= 21 && !a.awards.some((x) => /新人/.test(x.name)) && rel >= 0.5) award(lg + ' 新人王', 0.3);
    }
    if (a.status === 'pro' && a.ovr >= 17.2 && w._asiaY !== w.year && r() < clamp((a.ovr - 17.2) * 0.2 + 0.08, 0.08, 0.4)) { w._asiaY = w.year; s.awards.push('アジア年間最優秀選手'); a.awards.push({ y: w.year, name: 'アジア年間最優秀選手' }); }
    // 世界の賞（2026-11-15「バロンドールとかの要素も入れて」）。どれもその年に1人だけ
    const big5 = a.abroad && ABROAD.some((x) => x[1] === lg && x[2]);
    const once = (key, name) => { if (w[key] === w.year) return false; w[key] = w.year; s.awards.push(name); a.awards.push({ y: w.year, name }); return true; };
    if (a.status === 'pro' && big5 && !isGK && goals >= 24 && r() < clamp(0.25 + (goals - 24) * 0.06, 0.25, 0.8)) once('_shoeY', 'ゴールデンシュー（欧州得点王）');
    if (a.status === 'pro' && a.age <= 21 && a.ovr >= 16.5 && apps >= 20 && r() < clamp(0.05 + (a.ovr - 16.5) * 0.25 + (big5 ? 0.05 : 0), 0.05, 0.5)) once('_kopaY', 'コパ・トロフィー（21歳以下の最優秀）');
    if (a.status === 'pro' && isGK && big5 && a.ovr >= 16.8 && r() < clamp(0.1 + (a.ovr - 16.8) * 0.3, 0.1, 0.6)) once('_yashinY', 'ヤシン・トロフィー（世界最優秀GK）');
    // W杯（4年に1度）：代表に入っている子
    if (a.nat > 0 && w.year % 4 === 2 && a.ovr >= 16.3 && (w._wcY !== w.year || w._wcN < 4) && r() < 0.45) {
      if (w._wcY !== w.year) { w._wcY = w.year; w._wcN = 0; }
      w._wcN++;
      const g = fw >= 0.5 ? r.int(0, a.ovr >= 16 ? 3 : 1) : fw > 0 && r() < fw ? 1 : 0; // GK は0
      s.awards.push('W杯出場' + (g ? `（${g}得点）` : ''));
      a.awards.push({ y: w.year, name: 'W杯出場' });
      a.natGoals = (a.natGoals || 0) + g;
    }
    // バロンドールは30位まで順位が付く。力（総合力）に、その年の数字・タイトル・リーグの格を足した点で決まる
    const bd = YA.ballonScore(a, s, big5, lgR);
    if (bd != null) {
      let rank = clamp(Math.round(31 - (bd - BD_LINE) * 1.1 + r.int(-3, 3)), 1, 30);
      if (rank === 1 && w._bdY === w.year) rank = 2;
      if (rank === 1) w._bdY = w.year;
      const name = rank === 1 ? 'バロンドール' : `バロンドール ${rank}位`;
      s.awards.push(name); a.awards.push({ y: w.year, name });
      s.bd = rank;
      a.bdBest = Math.min(a.bdBest || 99, rank);
    }
    if (a.status === 'pro') { s.value = YA.marketValue(a); a.valueMax = Math.max(a.valueMax || 0, s.value); }
    a.apps += apps;
    a.goals += goals;
    a.assists = (a.assists || 0) + assists;
    if (isGK) a.cleans = (a.cleans || 0) + cleans;
    a.seasons = a.seasons || [];
    a.seasons.push(s);
    // 大きな知らせ
    for (const t of s.titles) YA.noteTier(w, 2, say(w, a, t, [`卒業生の${a.name}（${a.club}）が${t}`, `${a.club}が${t}。卒業生の${a.name}もその中にいた`, `${t}！${a.club}の${a.name}がトロフィーを掲げた`, `${a.name}（${a.club}）、${t}。優勝メダルの写真が送られてきた`]));
    for (const x of s.awards) YA.noteTier(w, /バロンドール$|バロンドール [23]位|W杯|年間最優秀|MVP|ゴールデンシュー|コパ・トロフィー|ヤシン/.test(x) ? 1 : 2, say(w, a, x, [`卒業生の${a.name}が${x}`, `${x}に卒業生の${a.name}！`, `${a.name}（${a.club}）が${x}に。表彰式でユース時代の話をした`]));
    return s;
  }
  // 年度末の知らせの言い回し（2026-11-15「パターンふやして」）。子の名前と年で決まる
  const say = (w, a, k, list) => list[YA.hash(a.name + k + w.year) % list.length];
  YA.alumniTick = function (w) {
    YA.fixClubNames(w);
    const r = YA.rngOf(w.seed * 67 + w.year * 29);
    let contrib = 0;
    for (const a of w.alumni) {
      if (a.retired || a.age == null) continue;
      a.titles = a.titles || [];
      a.awards = a.awards || [];
      let seasonDone = false;
      a.age++;
      if (a.age <= 23) a.ovr = Math.round((a.ovr + r() * (a.ovr >= 17.5 ? 0.08 : a.ovr >= 15.8 ? 0.2 : a.ovr >= 14 ? 0.35 : 0.6)) * 10) / 10; // 上に行くほど伸びは鈍る（200は歴史上No.1）
      else if (a.age >= 30) a.ovr = Math.round((a.ovr - r() * 0.5) * 10) / 10;
      if (a.status === 'univ' && a.age >= 22 && a.ovr >= 12.4 && r() < (a.pushed === 'univ' ? 0.6 : 0.4)) {
        a.status = 'pro';
        a.club = jClub(w, r, domLeague(a.ovr), a.ovr);
        a.league = YA.clubLeague(a.club) || domLeague(a.ovr);
        YA.noteTier(w, 2, say(w, a, 'univ', [`卒業生の${a.name}が大学を経てプロ入りしました（${a.club}・${a.league}）`, `大学で力をつけた${a.name}が、${a.club}（${a.league}）とプロ契約`, `${a.name}、遠回りしてプロへ。大学4年間のあと${a.club}に入る（${a.league}）`, `「大学に行ってよかった」――${a.name}が${a.club}（${a.league}）でプロになります`]));
      }
      if (a.status === 'pro') {
        // 国内は力で昇格・降格のあるリーグへ。このクラブのトップにいる子は、トップの部で出る
        if (w.top && a.club === w.top.name) a.league = YA.J_NAME[w.top.j];
        else a.league = YA.clubLeague(a.club) || (a.abroad ? a.league : domLeague(a.ovr));
        // その年の成績は、いまいるクラブで付けてから移籍を決める（2026-11-16 画面の点検：移籍した年の成績が移籍先のクラブで記録されていた）
        careerSeason(w, a, r);
        seasonDone = true;
        const gap = YA.rate(a.ovr) - (YA.clubStr(a.club, w) || YA.rate(a.ovr));
        // 力のある選手ほど移籍が多く、海外へ出やすい（とても力があれば5大リーグ）
        if (a.age >= 19 && a.age <= 30 && r() < 0.17 + clamp((a.ovr - 15) * 0.06, 0, 0.3) * (a.abroad ? 0.4 : 1) + clamp((gap - 8) * 0.02, 0, 0.3)) {
          const abroad = (a.ovr >= 13.8 && a.age <= 27 && r() < clamp(0.35 + (a.ovr - 15) * 0.12, 0.35, 0.9)) || (a.age >= 30 && a.ovr >= 13 && r() < 0.25);
          // 移籍金（2026-11-17：海外への移籍金が2.3億〜4.3億にほぼ固まっていた）。
          // いまの市場価値に、残りの契約年数の分の掛け目（0.3〜1.6倍）。契約満了なら0円（Jから海外は25%・国内は35%・海外どうしは12%）
          const fromAbroad = !!a.abroad;
          const valNow = YA.marketValue(a);
          const freeP = abroad ? (fromAbroad ? 0.12 : 0.25) : 0.35;
          const mult = 0.3 + r() * 1.3;
          const fee = a.age >= 30 || r() < freeP ? 0 : Math.round((valNow * mult * (abroad && !fromAbroad ? 2.2 : 1)) / 10) * 10;
          const share = Math.round(fee * 0.015);
          const from = a.club, fromLg = a.league;
          a.transfers++;
          if (abroad) {
            const ab = abroadPick(r, a.ovr, a.ovr >= 15.3, !fromAbroad, a.age);
            a.club = ab.club;
            a.league = ab.league;
            a.abroad = true;
          } else {
            if (a.abroad) a.abroad = false; // 国内へ戻る
            a.club = jClub(w, r, domLeague(a.ovr), a.ovr);
            a.league = YA.clubLeague(a.club) || domLeague(a.ovr);
          }
          contrib += share;
          // 移籍の記録（2026-11-15「移籍金とかもみたい」）：年・どこから・どこへ・移籍金・連帯貢献金
          a.moves = a.moves || [];
          a.moves.push({ y: w.year, age: a.age, from, fromLg, to: a.club, toLg: a.league, fee, share, abroad });
          a.feeTotal = (a.feeTotal || 0) + fee;
          YA.noteTier(w, 1, say(w, a, 'move', [`卒業生の${a.name}が${a.club}（${a.league}）へ${abroad ? '海外移籍' : '移籍'}（${fee ? `移籍金およそ${YA.yen(fee)}）。連帯貢献金 +${share}万円が育成基金に入ります` : '契約満了で移籍金なし）'}`, `${a.name}の${abroad ? '海外挑戦' : '移籍'}が決まった。行き先は${a.club}（${a.league}）。${fee ? `移籍金およそ${YA.yen(fee)}のうち、連帯貢献金 +${share}万円が育成基金へ` : '契約満了で、移籍金はなし'}`, `${a.club}（${a.league}）が${a.name}を獲得。${abroad ? '海の向こうへ。' : ''}${fee ? `育てたクラブとして連帯貢献金 +${share}万円が入ります（移籍金およそ${YA.yen(fee)}）` : '契約満了での移籍（移籍金なし）'}`, `${a.name}、${a.club}へ。「${abroad ? '向こうでも、ユースで覚えたことをやるだけ' : '新しい場所で、もう一段上へ'}」${fee ? `。連帯貢献金 +${share}万円（移籍金およそ${YA.yen(fee)}）` : '。契約満了で移籍金はなし'}`]));
        }
        // U-21代表（決定16）：21歳以下で力のある卒業生。のちにフル代表の足がかり
        if (a.age <= 21 && a.ovr >= 13.4 && r() < 0.2) {
          a.u21 = (a.u21 || 0) + 1;
          if (a.u21 === 1) YA.noteTier(w, 1, say(w, a, 'u21', [`卒業生の${a.name}がU-21日本代表に選ばれました`, `U-21日本代表のメンバーに${a.name}の名前がありました`, `${a.name}が初めてU-21代表へ。ユースの後輩たちが発表をスマホで見ていた`]));
        }
        // 日本代表（2026-11-17：1つのユースから年1.25人が代表入りしていた。強いアカデミーでもフル代表は数年に1人ほど）。
        // 線を総合力157（内部16.0）に上げ、初めて選ばれる子は卒業生全体で年1人まで
        const natFirst = !a.nat;
        if (a.ovr >= 16 && (!natFirst || w._natNewY !== w.year) && r() < clamp((a.u21 ? 0.12 : 0.08) + (a.ovr - 16) * 0.3, 0.08, 0.8) * (natFirst ? 0.8 : 1)) {
          if (natFirst) w._natNewY = w.year;
          a.nat = (a.nat || 0) + 1;
          if (a.nat === 1) YA.noteTier(w, 1, say(w, a, 'nat', [`卒業生の${a.name}が日本代表に初めて選ばれました！`, `日本代表のメンバー発表。${a.name}の名前が読み上げられた！`, `${a.name}、ついに日本代表へ。このユースから育った子が、日の丸を背負う`, `「ここまで来られたのは、ユースの3年間があったから」――${a.name}が日本代表に初選出`]));
        }
      }
      if (a.status !== 'left' && !seasonDone) careerSeason(w, a, r);
      if (a.age >= 33 || a.ovr < 9) {
        a.retired = true;
        // 若くてやめる子は「サッカーをやめた」。30歳を過ぎてからの「引退」と分ける（2026-11-17：19歳で「引退」と出ていた）
        a.quit = a.age < 28;
        a.note = a.quit ? 'サッカーをやめた' : '引退';
        a.retY = a.retY || w.year;
      }
    }
    if (contrib) {
      w.club.solidarity = (w.club.solidarity || 0) + contrib;
      w.solidTotal = (w.solidTotal || 0) + contrib;
    }
    return contrib;
  };

  // ---------- キャプテン（決定32）----------
  YA.setCaptain = function (w, pid, kind) {
    const key = kind === 'vice' ? 'vice' : 'captain';
    const old = w[key] && w.players[w[key]];
    if (old && old.id !== pid) {
      old.conf = clamp(old.conf - 8, 0, 100);
      old.unrest += 1;
    }
    w[key] = pid;
    const p = w.players[pid];
    const fragile = p.pers['大舞台'] === 'プレッシャーに弱い' || p.pers['気持ちの強さ'] === '繊細';
    const leader = p.pers['人との関わり'] === 'リーダー気質';
    if (key === 'captain') {
      p.conf = clamp(p.conf + (fragile ? -2 : 5), 0, 100);
      if (leader) p.spurt = Math.max(p.spurt, 3);
    }
    return fragile && key === 'captain' ? `${p.name}は重圧を感じているようだ` : leader ? `${p.name}はリーダー気質で、チームがまとまりそうだ` : `${p.name}を指名しました`;
  };

  // ---------- ポジション変更（決定31）----------
  YA.bestPosOf = (p) => p.best || p.main;
  YA.changePos = function (w, pid, pos) {
    const p = w.players[pid];
    if (p.main === pos) return { ok: false, msg: 'すでにそのポジションです' };
    if (p.pos === 'GK' || pos === 'GK') return { ok: false, msg: 'GKとの行き来は、この版ではできません' };
    const r = YA.rngOf(w.seed + w.week * 3 + p.num + YA.hash(pos));
    const aptTo = p.apt ? p.apt[pos] : 10;
    const stub = (p.pers['教えの受け止め方'] === '頑固' ? 0.55 : p.pers['教えの受け止め方'] === '反骨心' ? 0.35 : 0.08) + (aptTo < 14 ? 0.3 : aptTo < 17 ? 0.08 : 0);
    if (r() < stub) { p.conf = clamp(p.conf - 3, 0, 100); return { ok: false, msg: `${p.name}は納得せず、「今のポジションでやりたい」と断った` }; }
    const best = p.best;
    const L = YA.POS_LABEL;
    p.main = pos;
    p.pos = YA.GROUP[pos];
    p.adapt = 12;
    p.hist.unshift({ y: w.year, w: w.week, t: `ポジション変更（${L[pos]}）` });
    // いまの並びに入っているなら、新しいポジションの役割に直す
    for (const k of ['lineupA', 'lineupB']) w[k].forEach((sl, i) => { if (sl.pid === pid) YA.fixSlotRole(sl, i); });
    if (pos === best) { p.spurt = Math.max(p.spurt, 5); p.bestKnown = true; return { ok: true, msg: `${L[pos]}に変更。しっくりきているようだ（向いていたポジション）。慣れるまで約12週` }; }
    return { ok: true, msg: `${L[pos]}に変更しました。適性は${YA.aptGrade(p.apt[pos])}${Math.round(p.apt[pos])}。慣れるまで約12週は力が落ち、` + (p.apt[pos] < 14 ? '向いていない位置なので、慣れたあとも力は出しきれません' : '慣れると力を出せます') };
  };

  // ---------- 選手同士の関係（決定20）----------
  YA.relations = function (w) {
    const r = YA.rngOf(w.seed * 83 + w.year * 5 + w.week);
    w.rel = (w.rel || []).filter((x) => w.players[x.a] && w.players[x.b]);
    const ps = Object.values(w.players);
    const has = (a, b) => w.rel.some((x) => (x.a === a && x.b === b) || (x.a === b && x.b === a));
    let guard = 0;
    while (w.rel.filter((x) => x.k === 'friend').length < 8 && guard++ < 200) {
      const a = r.pick(ps);
      const b = r.pick(ps);
      if (a === b || has(a.id, b.id) || a.grade !== b.grade) continue;
      w.rel.push({ a: a.id, b: b.id, k: 'friend' });
    }
    guard = 0;
    while (w.rel.filter((x) => x.k === 'rival').length < 6 && guard++ < 300) {
      const a = r.pick(ps);
      const b = r.pick(ps);
      if (a === b || has(a.id, b.id) || a.pos !== b.pos || a.pos === 'GK' || Math.abs(YA.ovr(a) - YA.ovr(b)) > 1.2) continue;
      w.rel.push({ a: a.id, b: b.id, k: 'rival' });
    }
  };
  YA.relOf = function (w, pid) {
    const out = [];
    for (const x of w.rel || []) if (x.a === pid || x.b === pid) out.push({ k: x.k, other: w.players[x.a === pid ? x.b : x.a] });
    return out.filter((x) => x.other);
  };

  // ---------- 毎週の小さな処理 ----------
  YA.weekExtras = function (w) {
    const r = YA.rngOf(w.seed * 53 + w.year * 61 + w.week);
    if (!w.scouting) w.scouting = YA.newScouting(); // 古い保存データ（クラブを移ったあと空になっていた）
    // 古い保存データ：性格は2つまでに減らす
    for (const p of Object.values(w.players)) YA.trimPers(p);
    if (w.scouting) for (const c of w.scouting.cands) YA.trimPers(c.p);
    // 古い保存データ：最初のセレクションの途中だったものは、その状態を閉じる
    if (w.firstSel) {
      w.firstSel = null;
      w.scouting = YA.newScouting();
    }
    // 入団の暦：4月 スカウトが始まる／11月 内部昇格／12月 スカウトの返事／1月 セレクション
    if (w.week === 1) YA.noteTier(w, 2, `新しい入団の季節です。スカウトは月${YA.SCOUT_PER_MONTH}回まで出られ、声をかけられるのは4月〜11月（返事は12月）。内部昇格は11月、セレクションは1月に決めます。決めた子は来年の高1になります`);
    if (w.week === 25) YA.openInternal(w, true);
    if (w.week === 26) YA.openInternal(w);
    if (w.week === YA.SCOUT_RESULT_WEEK) {
      YA.closeInternal(w);
      YA.resolveOffers(w);
    }
    if (w.week === 31) YA.openSelection(w);
    if (w.week === 35) YA.closeSelection(w);
    // 38週：卒業する上位の子から、進路の相談が届く
    if (w.week === 38) {
      // ★の子は全員、★以外は上位1人まで（2026-11-15「★以外のイベントが多発する」）
      const g3 = Object.values(w.players).filter((p) => p.grade === 3 && YA.ovr(p) >= 10.8).sort((a, b) => YA.ovr(b) - YA.ovr(a));
      const sr = g3.filter((p) => p.star).concat(g3.filter((p) => !p.star).slice(0, 1)).slice(0, 4);
      w.forced = (w.forced || []).concat(sr.map((p) => ({ id: 'career', pid: p.id, week: w.week, year: w.year })));
    }
    if (YA.rivalWeek) YA.rivalWeek(w);
    YA.refreshFocus(w);
    YA.checkPromises(w);
    YA.awakeWeek(w);
    // 年代別日本代表：活動の週に、選考ラインを超えた子へ招集
    if (YA.NAT_WEEKS && YA.NAT_WEEKS.indexOf(w.week) >= 0) {
      const picks = YA.natPicks(w);
      if (picks.length) {
        w._natCall = picks.map((p) => p.id);
        w.forced = (w.forced || []).concat([{ id: 'natcall', pid: null, week: w.week, year: w.year }]);
      }
    }
    // トップの打診の線を10以上上回った高1・高2には、打診が来る（1年に1人まで・同じ子には年1回。2026-11-17 直し：前は毎週打診が来て、
    // 年4〜5人がプロに抜けていた）。高3は内定にして卒業まで残す
    if (w.top && YA.earlyProLine) {
      if (YA.naiteiCheck) YA.naiteiCheck(w);
      const line = YA.earlyProLine(w) + 10;
      const hot = YA.earlyCount(w) >= 1 ? null : Object.values(w.players).filter((p) => p.grade <= 2 && YA.rating(p) >= line && p._earlyAsk !== w.year && !(p._earlyNo && w.year * 100 + w.week - p._earlyNo < 10)).sort((a, b) => YA.rating(b) - YA.rating(a))[0];
      if (hot && !(w.forced || []).some((f) => f.id === 'early')) {
        hot._earlyAsk = w.year;
        w.forced = (w.forced || []).concat([{ id: 'early', pid: hot.id, week: w.week, year: w.year }]);
      }
    }
    let noticed = false;
    for (const p of Object.values(w.players)) {
      if (p.away > 0) p.away--;
      if (p.suspend > 0) p.suspend--;
      if (p.adapt > 0) p.adapt--;
      if (p.dorm) p.fat = clamp(p.fat - 2, 0, 100);
      // 本当に向いているポジションに気づく
      if (p.pos !== 'GK' && !p.bestKnown && !noticed && !(w.year === 1 && w.week <= 5) && r() < 0.006 * (w.coach ? w.coach.eye / 10 : 1)) {
        const best = p.best;
        if (best && best !== p.main && p.apt[best] - p.apt[p.main] > 1.0) {
          p.bestKnown = true;
          noticed = true;
          YA.noteTier(w, 1, `${p.num}番 ${p.name} は、${YA.POS_LABEL[best]}のほうが向いているかもしれません（いまは${YA.POS_LABEL[p.main]}。ポジション変更を検討）`, p.id);
        }
      }
    }
    // ライバルに差を付けられた子の不満
    const inA = new Set(w.lineupA.map((x) => x.pid));
    for (const x of w.rel || []) {
      if (x.k !== 'rival') continue;
      const a = w.players[x.a];
      const b = w.players[x.b];
      if (!a || !b) continue;
      const lo = inA.has(a.id) && !inA.has(b.id) ? b : inA.has(b.id) && !inA.has(a.id) ? a : null;
      if (lo) lo.unrest += lo.pers['気持ちの強さ'] === '負けず嫌い' ? 0.2 : 0.08; // 毎週の自然な和らぎ（0.5）より小さく、積み上がらない
    }
    // キャプテンの重圧
    const cap = w.captain && w.players[w.captain];
    if (cap && (cap.pers['大舞台'] === 'プレッシャーに弱い' || cap.pers['気持ちの強さ'] === '繊細') && cap.conf > 20) cap.conf -= 0.6;
    // 規律の自然な減衰
    w.disc = clamp((w.disc == null ? 60 : w.disc) - 0.4, 0, 100);
    // 信頼度のゆるやかな動き
    if (w.week % 8 === 0) {
      const rank = YA.myRank(w);
      YA.addTrust(w, rank <= 4 ? 1 : rank >= 10 ? -1 : 0);
    }
    if (w.club.reqYoung > 0) w.club.reqYoung--;
  };
})();
